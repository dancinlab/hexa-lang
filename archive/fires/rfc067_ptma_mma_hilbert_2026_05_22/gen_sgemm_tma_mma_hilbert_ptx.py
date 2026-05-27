#!/usr/bin/env python3
"""RFC 067 N200-full -- TMA + mma.sync.m16n8k16 + Hilbert d2xy CTA-swizzle (cuBLAS catch-up attempt).

Stacks:
  - N149  (rfc067_philb): 4-warp 64x64 + Hilbert + cp.async.cg, ratio 0.847 @ M=8192.
  - N196  (TMA descriptor probe): proves TMA descriptor passing on sm_120 works.
  - N197  (named mbarrier): proves mbarrier.arrive.expect_tx + try_wait.parity works on sm_120.
  - N200 SMOKE (rfc067_ptma_named_bar_hilbert): integrates above into smoke kernel (M=64,
    write-A-back-to-C). PASSed mismatch=0/256 on RTX 5070 sm_120.

This generator replaces SMOKE's "write smem_a to C" with the full N149 mma.sync chain,
scales to M=N=K in {512, 1024, 2048, 4096, 6144, 8192}, and re-adds Hilbert d2xy CTA-swizzle.

Layout (matches N149 byte-for-byte except cp.async -> TMA bulk-tensor):
  - A row-major [M, K] f16. Row stride K*2 B.
  - B col-major [K, N] f16. Col stride K*2 B.    (N149 convention)
    -> stored in global as if it were a [N, K] row-major matrix; b[k, n] at byte
       n*K*2 + k*2. Innermost dim for TMA = K.
  - C row-major [M, N] f32. Row stride N*4 B.

Per CTA: 64x64 output tile.
  4 warps in 2x2 (warp = wid; m_tile = wid>>1, n_tile = wid&1).
  Each warp owns 32x32 of output = 8 mma.m16n8k16 (2 M sub * 4 N sub-8) = 32 acc f32.

TMA descriptors:
  - tmap_a: rank-2 fp16 [M, K]. globalDim=[K, M] (innermost K). boxDim=[K_TILE=16, 64].
            Per CTA: load 64x16 tile at (col=k_off, row=ctaid_m*64).
  - tmap_b: rank-2 fp16 [N, K] (b col-major as above). globalDim=[K, N] (innermost K).
            boxDim=[K_TILE=16, 64]. Per CTA: load tile at (col=k_off, row=ctaid_n*64).
            (Same shape descriptor as A; just a different base ptr and different ctaid_n slicing.)

K-loop (K_TILES = K/16 iterations):
  - thread 0: cp.async.bulk.tensor.2d {smem_a}, {tmap_a, [k_off, m_off]}, mbar
              cp.async.bulk.tensor.2d {smem_b}, {tmap_b, [k_off, n_off]}, mbar
              mbarrier.arrive.expect_tx 4096 (= 2x 64x16x2B)
  - all threads: try_wait.parity %parity (alternates per K-iter)
  - all threads: ldmatrix A frag (2x m8n8.x4 = 8 b32) + B frag (2x m8n8.x4.trans = 8 b32)
  - all threads: 8 mma.sync.aligned.row.col.m16n8k16.f32.f16.f16.f32
  - bar.sync 0

Epilogue: st.global.f32 of 32 acc registers per warp at the warp's C base.

Hilbert d2xy: byte-identical to N149 prologue (replaces ctaid_m/ctaid_n with d2xy(p, ctaid.y*p + ctaid.x)).

ASCII-only PTX. .target sm_120a + .version 8.7 (N196 finding).
"""

import sys
from pathlib import Path

# ---- helpers ----
def next_pow2(n: int) -> int:
    p = 1
    while p < n:
        p <<= 1
    return p


def hilbert_d2xy_ref(n: int, d: int):
    x = y = 0
    t = d
    s = 1
    while s < n:
        rx = 1 & (t >> 1)
        ry = 1 & (t ^ rx)
        if ry == 0:
            if rx == 1:
                x = s - 1 - x
                y = s - 1 - y
            x, y = y, x
        x += s * rx
        y += s * ry
        t >>= 2
        s <<= 1
    return x, y


def verify_bijection(p: int, gx: int, gy: int):
    seen = set()
    for d in range(p * p):
        x, y = hilbert_d2xy_ref(p, d)
        if x < gx and y < gy:
            assert (x, y) not in seen, f"dup tile ({x},{y}) p={p}"
            seen.add((x, y))
    assert len(seen) == gx * gy, f"cover {len(seen)} != {gx*gy} (p={p})"


def emit_hilbert_prologue(p: int, gx: int, gy: int) -> str:
    """Same as N149 PHILB emit_hilbert_prologue. Outputs %r11=sw_x %r10=sw_y."""
    log2p = p.bit_length() - 1
    lines = []
    lines.append("    // ---- Hilbert d2xy CTA-swizzle (N149 PHILB pattern, byte-identical) ----")
    lines.append(f"    //   grid = p x p, p = {p} (next_pow2(gx={gx})); d = ctaid.y*p + ctaid.x")
    lines.append(f"    //   (sw_x, sw_y) = hilbert_d2xy({p}, d); drop tiles with x>={gx} or y>={gy}")
    lines.append("    mov.u32 %r100, %ctaid.x;")
    lines.append("    mov.u32 %r101, %ctaid.y;")
    lines.append(f"    mul.lo.u32 %r120, %r101, {p};")
    lines.append("    add.u32    %r120, %r120, %r100;")
    lines.append("    mov.u32 %r121, 0;")
    lines.append("    mov.u32 %r122, 0;")
    s = 1
    for it in range(log2p):
        sm1 = s - 1
        lines.append(f"    // -- Hilbert round {it}: s = {s} --")
        lines.append(f"    shr.u32 %r126, %r120, 1;")
        lines.append(f"    and.b32 %r123, %r126, 1;")
        lines.append(f"    xor.b32 %r127, %r120, %r123;")
        lines.append(f"    and.b32 %r124, %r127, 1;")
        lines.append(f"    setp.eq.u32 %prx0, %r124, 0;")
        lines.append(f"    setp.eq.u32 %prx1, %r123, 1;")
        lines.append(f"    and.pred %prxr, %prx0, %prx1;")
        lines.append(f"    sub.u32 %r128, {sm1}, %r121;")
        lines.append(f"    sub.u32 %r129, {sm1}, %r122;")
        lines.append(f"    selp.b32 %r121, %r128, %r121, %prxr;")
        lines.append(f"    selp.b32 %r122, %r129, %r122, %prxr;")
        lines.append(f"    selp.b32 %r128, %r122, %r121, %prx0;")
        lines.append(f"    selp.b32 %r122, %r121, %r122, %prx0;")
        lines.append(f"    mov.u32 %r121, %r128;")
        lines.append(f"    mul.lo.u32 %r128, %r123, {s};")
        lines.append(f"    add.u32 %r121, %r121, %r128;")
        lines.append(f"    mul.lo.u32 %r129, %r124, {s};")
        lines.append(f"    add.u32 %r122, %r122, %r129;")
        if it != log2p - 1:
            lines.append(f"    shr.u32 %r120, %r120, 2;")
        s <<= 1
    lines.append("    mov.u32 %r11, %r121;             // sw_x")
    lines.append("    mov.u32 %r10, %r122;             // sw_y")
    lines.append(f"    setp.ge.u32 %phlbx, %r11, {gx};")
    lines.append(f"    setp.ge.u32 %phlby, %r10, {gy};")
    lines.append("    or.pred %phlb_oob, %phlbx, %phlby;")
    lines.append("    @%phlb_oob bra $hilbert_oob_ret;")
    return "\n".join(lines)


# ---- main kernel emitter ----
def gen(S: int) -> str:
    """Generate PTX for M=N=K=S using TMA + mma.sync + Hilbert.

    Tile/warp structure (matches N149 PHILB):
      Each CTA computes one 64x64 output tile.
      4 warps in 2x2 (m_tile=warp>>1, n_tile=warp&1), each warp owns 32x32.
      K-loop = S / 16 iterations.

    smem layout (single-buffer, no software pipeline -- TMA does the prefetch implicitly
    via the bulk-tensor descriptor + mbarrier handshake; we measure if single-buffer is
    enough or if double-buffer is needed in follow-up):
      _tg_a: 2048 B (64 rows x 32 B each = 64 rows x 16 fp16, K_TILE wide)
      _tg_b: 2048 B (same shape; B col-major in global -> innermost K)
      _tg_mbar: 16 B (1 mbarrier .u64 + 8 B pad)

    Global addressing under Hilbert:
      ctaid_m  = sw_y    (replaces ctaid.y)
      ctaid_n  = sw_x    (replaces ctaid.x)
      A_cta_base = a + sw_y * 64 * K * 2
      B_cta_base = b + sw_x * 64 * K * 2     (B is col-major; sw_x picks the N column-block)

    Per K-iter:
      k_off = k_iter * 16   (column in A, column-in-stored-layout for B since B[k,n]
                              lives at row=n, col=k in storage)
      TMA-load A tile [64 rows x 16 cols] from (col=k_off, row=sw_y*64) using tmap_a
      TMA-load B tile [64 rows x 16 cols] from (col=k_off, row=sw_x*64) using tmap_b
        (B storage is col-major -> stored as if [N, K] row-major -> innermost=K, same as A)
      mbarrier.arrive.expect_tx 4096
      try_wait.parity %parity (parity = k_iter & 1)
      bar.sync 0
      ldmatrix A (8 b32) + B trans (8 b32)
      8 mma.m16n8k16
      bar.sync 0
    """
    assert S % 64 == 0
    K = S
    K_TILES = K // 16

    a_ctay_byte = 64 * K * 2          # sw_y * 64 rows * K cols * 2 B = bytes per ctay-step
    b_ctax_byte = 64 * K * 2          # sw_x * 64 N-cols (stored as rows in col-major) * K cols * 2 B
    c_ctay_byte = 64 * S * 4
    c_warpm_byte = 32 * S * 4
    c_ctax_byte = 64 * 4              # sw_x * 64 N-cols (in C row-major) * 4 B per f32
    c_warpn_byte = 32 * 4

    gx = S // 64
    gy = S // 64
    p = next_pow2(gx)
    verify_bijection(p, gx, gy)
    hilbert = emit_hilbert_prologue(p, gx, gy)

    return f"""//
// RFC 067 N200-full -- TMA + mma.sync.m16n8k16 + Hilbert d2xy CTA-swizzle.
// M=N=K={S}. Per-CTA 64x64 tile, 4-warp 2x2, K_TILES={K_TILES}, K_TILE=16.
// Hilbert: p={p} (next_pow2(gx={gx})), d2xy unrolled {p.bit_length()-1} rounds.
// TMA: 2 descriptors (A [M, K] innermost K, B [N, K] col-major innermost K),
//      box [K_TILE=16, 64], expect_tx 4096 per K-iter (2048 A + 2048 B).
// ASCII-only PTX. .target sm_120a, .version 8.7 (N196 finding for sm_120).
//

.version 8.7
.target sm_120a
.address_size 64

.shared .align 16 .b8 _tg_a[2048];
.shared .align 16 .b8 _tg_b[2048];
.shared .align 8  .b8 _tg_mbar[16];

.visible .entry sgemm_tma_mma_hilbert_{S}x{S}_grid (
    .param .align 64 .b8 tmap_a_param[128],
    .param .align 64 .b8 tmap_b_param[128],
    .param .u64 c_ptr_param,
    .param .u64 k_tiles_param
)
{{
    .reg .u64 %rd<32>;
    .reg .u32 %r<160>;
    .reg .pred %p1;
    .reg .pred %pwait;
    .reg .pred %prx0;
    .reg .pred %prx1;
    .reg .pred %prxr;
    .reg .pred %phlbx;
    .reg .pred %phlby;
    .reg .pred %phlb_oob;
    .reg .pred %pt0;
    .reg .b32 %ra<8>;
    .reg .b32 %rbl<4>;
    .reg .b32 %rbh<4>;
    .reg .f32 %fc<32>;
    .reg .b64 %tok;
    .reg .b32 %parity;
    .reg .b32 %k_iter;
    .reg .b32 %k_off;
    .reg .b32 %tx_count;
    .reg .b32 %arr_count;
    .reg .b32 %x0, %y0, %x1, %y1;
    .reg .b32 %smem_a_lo, %smem_b_lo, %smem_mbar_lo;
    .reg .b64 %tmap_a_pp, %tmap_b_pp, %tmap_a_addr, %tmap_b_addr;
    .reg .b64 %c_addr;

    // ---- TMA descriptor + C ptr loads (param-space) ----
    mov.b64 %tmap_a_pp, tmap_a_param;
    cvta.param.u64 %tmap_a_addr, %tmap_a_pp;
    mov.b64 %tmap_b_pp, tmap_b_param;
    cvta.param.u64 %tmap_b_addr, %tmap_b_pp;
    ld.param.u64 %c_addr, [c_ptr_param];
    ld.param.u64 %rd3, [k_tiles_param];

{hilbert}

    // ---- thread/warp ids ----
    mov.u32 %r1, %tid.x;
    shr.u32 %r2, %r1, 5;        // warp id in [0, 4)
    shr.u32 %r3, %r2, 1;        // m_tile = warp >> 1  in [0, 2)
    and.b32 %r4, %r2, 1;        // n_tile = warp & 1   in [0, 2)
    and.b32 %r50, %r1, 31;      // lane id

    // shared-mem base addresses (cvt to .u32)
    mov.u32 %smem_a_lo, _tg_a;
    mov.u32 %smem_b_lo, _tg_b;
    mov.u32 %smem_mbar_lo, _tg_mbar;

    // ---- mbarrier init (thread 0 only) ----
    setp.eq.s32 %pt0, %r1, 0;
    @!%pt0 bra $L_init_done;
    mov.u32 %arr_count, 1;
    mbarrier.init.shared.b64 [%smem_mbar_lo], %arr_count;
    fence.proxy.async.shared::cta;
$L_init_done:
    bar.sync 0;

    // ---- per-warp ldmatrix base offsets (matches N149) ----
    // A read base in smem = m_tile * 1024 (32 rows * 32 B/row)
    mul.lo.u32 %r22, %r3, 1024;
    // B read base in smem = n_tile * 1024
    mul.lo.u32 %r24, %r4, 1024;

    // ldmatrix per-lane intra-subtile address (16x16 logical -> 4 b32 per lane)
    // Matches N149 byte-identical: row * 32 + col_off (where col_off = (lane>>3 & 1) << 4)
    shr.u32 %r51, %r50, 3;
    and.b32 %r52, %r50, 7;
    shr.u32 %r53, %r51, 1;
    shl.b32 %r54, %r53, 3;
    add.u32 %r55, %r54, %r52;            // row_idx
    and.b32 %r56, %r51, 1;
    shl.b32 %r57, %r56, 4;               // col_off
    shl.b32 %r58, %r55, 5;               // row * 32
    add.u32 %r59, %r58, %r57;            // intra-subtile lane addr

    // C base address (under Hilbert swizzle):
    //   C_warp_base = c + sw_y * 64 * S * 4
    //                   + m_tile * 32 * S * 4
    //                   + sw_x * 64 * 4
    //                   + n_tile * 32 * 4
    mul.lo.u32 %r5, %r10, {c_ctay_byte};
    mul.lo.u32 %r6, %r3, {c_warpm_byte};
    add.u32 %r7, %r5, %r6;
    mul.lo.u32 %r8, %r11, {c_ctax_byte};
    add.u32 %r7, %r7, %r8;
    mul.lo.u32 %r8, %r4, {c_warpn_byte};
    add.u32 %r7, %r7, %r8;
    cvt.u64.u32 %rd6, %r7;
    add.u64 %rd12, %c_addr, %rd6;

    // ---- init 32 f32 accumulators ----
    mov.f32 %fc0,  0f00000000;
    mov.f32 %fc1,  0f00000000;
    mov.f32 %fc2,  0f00000000;
    mov.f32 %fc3,  0f00000000;
    mov.f32 %fc4,  0f00000000;
    mov.f32 %fc5,  0f00000000;
    mov.f32 %fc6,  0f00000000;
    mov.f32 %fc7,  0f00000000;
    mov.f32 %fc8,  0f00000000;
    mov.f32 %fc9,  0f00000000;
    mov.f32 %fc10, 0f00000000;
    mov.f32 %fc11, 0f00000000;
    mov.f32 %fc12, 0f00000000;
    mov.f32 %fc13, 0f00000000;
    mov.f32 %fc14, 0f00000000;
    mov.f32 %fc15, 0f00000000;
    mov.f32 %fc16, 0f00000000;
    mov.f32 %fc17, 0f00000000;
    mov.f32 %fc18, 0f00000000;
    mov.f32 %fc19, 0f00000000;
    mov.f32 %fc20, 0f00000000;
    mov.f32 %fc21, 0f00000000;
    mov.f32 %fc22, 0f00000000;
    mov.f32 %fc23, 0f00000000;
    mov.f32 %fc24, 0f00000000;
    mov.f32 %fc25, 0f00000000;
    mov.f32 %fc26, 0f00000000;
    mov.f32 %fc27, 0f00000000;
    mov.f32 %fc28, 0f00000000;
    mov.f32 %fc29, 0f00000000;
    mov.f32 %fc30, 0f00000000;
    mov.f32 %fc31, 0f00000000;

    // ---- K-loop ----
    // m_off (in A box rows) = sw_y * 64
    // n_off (in B box rows -- B is col-major in global, stored as if [N, K]) = sw_x * 64
    mul.lo.u32 %r70, %r10, 64;          // %r70 = sw_y * 64 = A box y0
    mul.lo.u32 %r71, %r11, 64;          // %r71 = sw_x * 64 = B box y0

    mov.u32 %k_iter, 0;
$L_kloop:
    mul.lo.s32 %k_off, %k_iter, 16;     // k-block start (innermost dim for both A and B)

    // -- thread 0 issues 2 TMA loads + arrive.expect_tx --
    setp.eq.s32 %pt0, %r1, 0;
    @!%pt0 bra $L_skip_issue;
    mov.u32 %x0, %k_off;
    mov.u32 %y0, %r70;
    cp.async.bulk.tensor.2d.shared::cluster.global.tile.mbarrier::complete_tx::bytes
        [%smem_a_lo], [%tmap_a_addr, {{%x0, %y0}}], [%smem_mbar_lo];
    mov.u32 %x1, %k_off;
    mov.u32 %y1, %r71;
    cp.async.bulk.tensor.2d.shared::cluster.global.tile.mbarrier::complete_tx::bytes
        [%smem_b_lo], [%tmap_b_addr, {{%x1, %y1}}], [%smem_mbar_lo];
    mov.u32 %tx_count, 4096;
    mbarrier.arrive.expect_tx.release.cta.shared::cta.b64
        %tok, [%smem_mbar_lo], %tx_count;
$L_skip_issue:

    // -- all threads: wait on mbarrier (parity alternates per K-iter) --
    and.b32 %parity, %k_iter, 1;
$L_wait:
    mbarrier.try_wait.parity.shared::cta.b64 %pwait, [%smem_mbar_lo], %parity;
    @!%pwait bra $L_wait;
    bar.sync 0;

    // -- ldmatrix A (2x m8n8.x4 = 8 b32 per lane) --
    //    A frag covers warp's 32x16 sub-tile (m_tile selects top/bot half)
    add.u32 %r60, %smem_a_lo, %r22;     // A_warp_base = _tg_a + m_tile*1024
    add.u32 %r60, %r60, %r59;            // + intra-subtile lane addr
    add.u32 %r62, %r60, 512;             // bottom half of warp's 32 rows
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra0, %ra1, %ra2, %ra3}}, [%r60];
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra4, %ra5, %ra6, %ra7}}, [%r62];

    // -- ldmatrix B trans (2x m8n8.x4.trans = 8 b32 per lane) --
    //    B frag covers warp's 16x32 sub-tile (n_tile selects left/right half)
    add.u32 %r61, %smem_b_lo, %r24;
    add.u32 %r61, %r61, %r59;
    add.u32 %r63, %r61, 512;
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbl0, %rbl1, %rbl2, %rbl3}}, [%r61];
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbh0, %rbh1, %rbh2, %rbh3}}, [%r63];

    // -- 8 mma.m16n8k16 (covers 32x32 per warp; identical to N149) --
    mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
        {{%fc0, %fc1, %fc2, %fc3}},
        {{%ra0, %ra1, %ra2, %ra3}},
        {{%rbl0, %rbl2}},
        {{%fc0, %fc1, %fc2, %fc3}};
    mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
        {{%fc4, %fc5, %fc6, %fc7}},
        {{%ra0, %ra1, %ra2, %ra3}},
        {{%rbl1, %rbl3}},
        {{%fc4, %fc5, %fc6, %fc7}};
    mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
        {{%fc8, %fc9, %fc10, %fc11}},
        {{%ra0, %ra1, %ra2, %ra3}},
        {{%rbh0, %rbh2}},
        {{%fc8, %fc9, %fc10, %fc11}};
    mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
        {{%fc12, %fc13, %fc14, %fc15}},
        {{%ra0, %ra1, %ra2, %ra3}},
        {{%rbh1, %rbh3}},
        {{%fc12, %fc13, %fc14, %fc15}};
    mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
        {{%fc16, %fc17, %fc18, %fc19}},
        {{%ra4, %ra5, %ra6, %ra7}},
        {{%rbl0, %rbl2}},
        {{%fc16, %fc17, %fc18, %fc19}};
    mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
        {{%fc20, %fc21, %fc22, %fc23}},
        {{%ra4, %ra5, %ra6, %ra7}},
        {{%rbl1, %rbl3}},
        {{%fc20, %fc21, %fc22, %fc23}};
    mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
        {{%fc24, %fc25, %fc26, %fc27}},
        {{%ra4, %ra5, %ra6, %ra7}},
        {{%rbh0, %rbh2}},
        {{%fc24, %fc25, %fc26, %fc27}};
    mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
        {{%fc28, %fc29, %fc30, %fc31}},
        {{%ra4, %ra5, %ra6, %ra7}},
        {{%rbh1, %rbh3}},
        {{%fc28, %fc29, %fc30, %fc31}};

    bar.sync 0;

    add.s32 %k_iter, %k_iter, 1;
    setp.lt.s32 %p1, %k_iter, {K_TILES};
    @%p1 bra $L_kloop;

    // ---- epilogue: store 32 acc registers to C ----
    // Lane mapping for m16n8 f32 output (row-major fragment, matches N149):
    //   group = lane >> 2 (0..7)   -> row stride 1 in M direction
    //   col_q = lane & 3            -> 2 f32 per lane, stride 4 in N (8 B per col_q)
    //   so within a 16x8 fragment, lane (g, c) stores 2 f32 at (row=g, col=2*c) and (row=g, col=2*c+1)
    shr.u32 %r80, %r50, 2;               // group
    and.b32 %r81, %r50, 3;               // col_q
    mul.lo.u32 %r82, %r80, {S*4};
    shl.b32 %r83, %r81, 3;
    add.u32 %r84, %r82, %r83;
    cvt.u64.u32 %rd20, %r84;
    add.u64 %rd20, %rd12, %rd20;

    add.u64 %rd21, %rd20, {8*S*4};
    add.u64 %rd22, %rd20, {16*S*4};
    add.u64 %rd23, %rd20, {24*S*4};

    st.global.f32 [%rd20 +     0], %fc0;
    st.global.f32 [%rd20 +     4], %fc1;
    st.global.f32 [%rd21 +     0], %fc2;
    st.global.f32 [%rd21 +     4], %fc3;
    st.global.f32 [%rd20 +    32], %fc4;
    st.global.f32 [%rd20 +    36], %fc5;
    st.global.f32 [%rd21 +    32], %fc6;
    st.global.f32 [%rd21 +    36], %fc7;
    st.global.f32 [%rd20 +    64], %fc8;
    st.global.f32 [%rd20 +    68], %fc9;
    st.global.f32 [%rd21 +    64], %fc10;
    st.global.f32 [%rd21 +    68], %fc11;
    st.global.f32 [%rd20 +    96], %fc12;
    st.global.f32 [%rd20 +   100], %fc13;
    st.global.f32 [%rd21 +    96], %fc14;
    st.global.f32 [%rd21 +   100], %fc15;

    st.global.f32 [%rd22 +     0], %fc16;
    st.global.f32 [%rd22 +     4], %fc17;
    st.global.f32 [%rd23 +     0], %fc18;
    st.global.f32 [%rd23 +     4], %fc19;
    st.global.f32 [%rd22 +    32], %fc20;
    st.global.f32 [%rd22 +    36], %fc21;
    st.global.f32 [%rd23 +    32], %fc22;
    st.global.f32 [%rd23 +    36], %fc23;
    st.global.f32 [%rd22 +    64], %fc24;
    st.global.f32 [%rd22 +    68], %fc25;
    st.global.f32 [%rd23 +    64], %fc26;
    st.global.f32 [%rd23 +    68], %fc27;
    st.global.f32 [%rd22 +    96], %fc28;
    st.global.f32 [%rd22 +   100], %fc29;
    st.global.f32 [%rd23 +    96], %fc30;
    st.global.f32 [%rd23 +   100], %fc31;

    ret;

$hilbert_oob_ret:
    ret;
}}
"""


SHAPES = [512, 1024, 2048, 4096, 6144, 8192]


if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        p = outdir / f"sgemm_tma_mma_hilbert_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes (bijection verified per shape)")
