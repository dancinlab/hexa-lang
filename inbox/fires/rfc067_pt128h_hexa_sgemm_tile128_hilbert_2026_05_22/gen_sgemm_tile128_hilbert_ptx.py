#!/usr/bin/env python3
"""RFC 067 PT128H -- 128x128 output tile (N89 PS) + Hilbert-curve CTA-swizzle (N149 PHILB).

Hypothesis (combines two findings):
  - N89 (PS): a 128x128 output tile per CTA gives 4x output/CTA and fewer total CTAs,
    but it collapsed to 1 CTA/SM (47 regs * 1024 thd = 48128 regs/CTA on 64K-reg SMs).
    At the M sweep tested (256..1536) the bigger tile LOST to the 64x64 4-warp baseline
    everywhere except a marginal +2.8% @ M=1536 (peak 37.07 TFLOPS, ratio 0.557). The
    finding: bigger tile is the wrong knob -- it cuts CTA count faster than time/CTA.
  - N149 (PHILB): a Hilbert space-filling-curve CTA-swizzle on the 64x64 tile FLATTENED
    the large-M L2-thrash cliff: ratio held ~0.82-0.85 across M=4096..8192 (M=8192 0.847),
    by mapping adjacent CTA IDs to Manhattan-adjacent output tiles -> tight 2D L2 blob.

PT128H combined hypothesis: at LARGE M (4096..8192), the 128x128 tile's larger working
  set per CTA + Hilbert's L2 locality may push the large-M ratio PAST N149's 0.847:
    * fewer total CTAs (each 128x128 covers 4x the area of a 64x64)
    * each CTA's A-row band (128 rows) and B-col band (128 cols) is L2-resident under
      Hilbert visitation order, so the 1-CTA/SM occupancy collapse that killed N89 at
      small M might be COMPENSATED by L2-resident reuse at large M, where there are far
      more output tiles than SMs anyway (many waves -> the per-CTA cost is what matters).

  HONEST g3 framing (the two-sided test):
    - If 128x128 + Hilbert beats 64x64 + Hilbert at large M -> the L2-locality unlock
      changes the tile-size tradeoff: bigger tile WINS when L2-resident.
    - If 128x128 still loses to 64x64 even WITH Hilbert -> N89's finding holds: the
      occupancy collapse (1 CTA/SM, 67% thread budget, no latency hiding across CTAs)
      dominates, and bigger tile is the wrong knob on RTX 5070 regardless of swizzle.

Geometry (UNCHANGED vs N89 PS body):
  - 128x128 output tile, 32 warps (1024 thd/CTA).
  - Warp grid 8x4: m_tile = warp>>2 in [0,8), n_tile = warp&3 in [0,4).
  - Per warp 16 rows x 32 cols = 4x mma.m16n8k16 per K-step (A frag reused across 2 N sub).
  - 16 f32 acc / lane. Double-buffered 16 KB shared mem.
  - ldmatrix.x4 / ldmatrix.x4.trans, mma.m16n8k16.row.col.f32.f16.f16.f32 -- byte-identical
    MMA math to N89/N77 -> bit-exact preserved.

CTA-swizzle (Hilbert d2xy, ported from N149 PHILB but for a 128-tile grid):
  - side = S // 128  (4096->32, 5120->40, 6144->48, 8192->64)
  - launch grid = p x p, p = next_pow2(side)  (32->32, 40->64, 48->64, 64->64)
  - d = ctaid.y * p + ctaid.x
  - (sw_x, sw_y) = hilbert_d2xy(p, d)  -- unrolled log2(p) rounds, no runtime loop
  - early-return padding CTAs (sw_x>=side || sw_y>=side); bijective over real grid.
  - sw_x replaces ctaid.x (%r11), sw_y replaces ctaid.y (%r10) in all A/B/C base addresses.
    The N89 body already reads ctaid.y/ctaid.x from %r10/%r11, so the only change is
    REPLACING the two mov.u32 %r10,%ctaid.y / %r11,%ctaid.x with the Hilbert prologue.

Pow2 / non-pow2 launch (honest cost, identical mechanism to N149):
  - M=4096  side=32 p=32  -> 1024 launched, 1024 real, 0 padding
  - M=5120  side=40 p=64  -> 4096 launched, 1600 real, 2496 padding-return (61%)
  - M=6144  side=48 p=64  -> 4096 launched, 2304 real, 1792 padding-return (44%)
  - M=8192  side=64 p=64  -> 4096 launched, 4096 real, 0 padding
  Note: with the 128 tile, CTA counts are 4x smaller than N149's 64-tile grid at the same M
  (e.g. M=8192: 4096 CTAs here vs 16384 for N149). This is the central lever being tested.

Falsifier F-RFC067-HEXA-SGEMM-TILE128-HILBERT:
  - Bit-exact PASS at every shape (max_abs = 0.0 vs cuBLAS HGEMM).
  - Per-shape median TFLOPS over 200 reps (20 warmup), cuEvent sync per launch.
  - Headline: does 128x128 + Hilbert beat 64x64 + Hilbert (N149) at M=8192 (0.847)?
"""

import sys
from pathlib import Path


def next_pow2(n: int) -> int:
    p = 1
    while p < n:
        p <<= 1
    return p


def hilbert_d2xy_ref(n: int, d: int):
    """Reference Python d2xy (for generator-side bijection verification)."""
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
    """Assert filtered Hilbert covers gx x gy exactly once."""
    seen = set()
    for d in range(p * p):
        x, y = hilbert_d2xy_ref(p, d)
        if x < gx and y < gy:
            assert (x, y) not in seen, f"dup tile ({x},{y}) p={p}"
            seen.add((x, y))
    assert len(seen) == gx * gy, f"cover {len(seen)} != {gx*gy} (p={p})"


def emit_hilbert_prologue(p: int, gx: int, gy: int) -> str:
    """Emit straight-line (unrolled) Hilbert d2xy PTX.

    Inputs:  ctaid.x, ctaid.y  (grid is p x p)
    Outputs: %r10 = sw_y (= hy),  %r11 = sw_x (= hx)   -- replace N89's ctaid reads.
    Sets predicate %phlb_oob true if (hx>=gx || hy>=gy) -> caller early-returns.

    Registers used (all in the .reg .u32 %r<160> pool, disjoint from N89's %r0..%r96):
      %r100,%r101 = ctaid.x, ctaid.y
      %r120 = d (running index t)
      %r121 = x (hx accumulator)
      %r122 = y (hy accumulator)
      %r123 = rx ; %r124 = ry ; %r126..%r129 = scratch
    """
    log2p = p.bit_length() - 1
    lines = []
    lines.append("    // ---- CTA-swizzle: Hilbert-curve d2xy (N149 PHILB port for 128-tile grid) ----")
    lines.append(f"    //   grid = p x p, p = {p} (next_pow2(side={gx})); d = ctaid.y*p + ctaid.x")
    lines.append(f"    //   (sw_x, sw_y) = hilbert_d2xy({p}, d); drop tiles with x>={gx} or y>={gy}")
    lines.append("    mov.u32 %r100, %ctaid.x;")
    lines.append("    mov.u32 %r101, %ctaid.y;")
    lines.append(f"    mul.lo.u32 %r120, %r101, {p};")
    lines.append("    add.u32    %r120, %r120, %r100;   // %r120 = d (running t)")
    lines.append("    mov.u32 %r121, 0;                 // x")
    lines.append("    mov.u32 %r122, 0;                 // y")
    s = 1
    for it in range(log2p):
        sm1 = s - 1
        lines.append(f"    // --- Hilbert round {it}: s = {s} ---")
        lines.append(f"    shr.u32 %r126, %r120, 1;")
        lines.append(f"    and.b32 %r123, %r126, 1;          // rx")
        lines.append(f"    xor.b32 %r127, %r120, %r123;")
        lines.append(f"    and.b32 %r124, %r127, 1;          // ry")
        lines.append(f"    setp.eq.u32 %prx0, %r124, 0;      // ry==0")
        lines.append(f"    setp.eq.u32 %prx1, %r123, 1;      // rx==1")
        lines.append(f"    and.pred %prxr, %prx0, %prx1;     // need_reflect = ry==0 && rx==1")
        lines.append(f"    sub.u32 %r128, {sm1}, %r121;      // sm1 - x")
        lines.append(f"    sub.u32 %r129, {sm1}, %r122;      // sm1 - y")
        lines.append(f"    selp.b32 %r121, %r128, %r121, %prxr;  // x = reflect ? sm1-x : x")
        lines.append(f"    selp.b32 %r122, %r129, %r122, %prxr;  // y = reflect ? sm1-y : y")
        lines.append(f"    selp.b32 %r128, %r122, %r121, %prx0;  // tmp = ry0 ? y : x")
        lines.append(f"    selp.b32 %r122, %r121, %r122, %prx0;  // y   = ry0 ? x : y")
        lines.append(f"    mov.u32 %r121, %r128;                 // x   = tmp")
        lines.append(f"    mul.lo.u32 %r128, %r123, {s};")
        lines.append(f"    add.u32 %r121, %r121, %r128;          // x += s*rx")
        lines.append(f"    mul.lo.u32 %r129, %r124, {s};")
        lines.append(f"    add.u32 %r122, %r122, %r129;          // y += s*ry")
        if it != log2p - 1:
            lines.append(f"    shr.u32 %r120, %r120, 2;              // t >>= 2")
        s <<= 1
    lines.append("    mov.u32 %r11, %r121;             // sw_x = hx (replaces ctaid.x)")
    lines.append("    mov.u32 %r10, %r122;             // sw_y = hy (replaces ctaid.y)")
    lines.append(f"    setp.ge.u32 %phlbx, %r11, {gx};")
    lines.append(f"    setp.ge.u32 %phlby, %r10, {gy};")
    lines.append("    or.pred %phlb_oob, %phlbx, %phlby;")
    lines.append("    @%phlb_oob bra $hilbert_oob_ret;")
    return "\n".join(lines)


def gen(S: int) -> str:
    assert S % 128 == 0, f"S={S} must be divisible by 128 for tile128"
    a_ctay_byte = 128 * S * 2          # ctaid.y stride: 128 rows * S K-cols * 2 B (A row-major fp16)
    b_ctax_byte = 128 * S * 2          # ctaid.x stride: 128 cols * S K-rows * 2 B (B col-major fp16)
    c_ctay_byte = 128 * S * 4          # C is f32, 128 rows
    c_warpm_byte = 16 * S * 4          # 16 C rows per warp m_tile
    ab_row_b = S * 2                   # one A row / B col stride (fp16 bytes)

    side = S // 128
    p = next_pow2(side)
    verify_bijection(p, side, side)
    hilbert = emit_hilbert_prologue(p, side, side)

    return f"""// RFC 067 PT128H perf HGEMM hexa-emit -- 128x128 output tile (N89 PS) + Hilbert CTA-swizzle (N149 PHILB) -- M=N=K={S}.
//
// Combines two prior findings:
//   N89 (PS):    128x128 output / CTA, 32 warps, 47 regs/thd -> 1 CTA/SM occupancy collapse.
//                Lost to 64x64 4-warp baseline at M<=1536 (peak 37.07 @ M=1536 ratio 0.557).
//   N149 (PHILB): Hilbert d2xy CTA-swizzle on 64x64 tile -> flattened large-M L2 cliff,
//                ratio ~0.82-0.85 across M=4096..8192 (M=8192 0.847).
//
// PT128H: 128x128 tile body (byte-identical MMA to N89) + Hilbert d2xy CTA visitation
//         (ported from N149 for a side=S/128 grid). Tests if bigger tile + L2 locality
//         beats 64x64+Hilbert at large M.
//
// CTA-swizzle: launch p x p (p=next_pow2(side={side})), d=ctaid.y*p+ctaid.x,
//   (sw_x,sw_y)=hilbert_d2xy({p}, d), drop padding (sw_x>={side}||sw_y>={side}).
//   sw_x->%r11 (replaces ctaid.x), sw_y->%r10 (replaces ctaid.y).
//
// Layout:
//   A row-major     [M={S} x K={S}] f16. Row stride = {S} elem = {ab_row_b} B.
//   B col-major     [K={S} x N={S}] f16. Col stride = {S} elem = {ab_row_b} B.
//   C row-major out [M={S} x N={S}] f32. Row stride = {S} elem = {S*4} B.
// CTA tile bytes: sw_y -> 128 M-rows ({a_ctay_byte} B from A base),
//                 sw_x -> 128 N-cols ({b_ctax_byte} B from B base).

.version 8.0
.target sm_90
.address_size 64

.shared .align 16 .b8 _tg_a[8192];
.shared .align 16 .b8 _tg_b[8192];

.visible .entry sgemm_tile128_hilbert_{S}x{S}_grid (
    .param .u64 a,
    .param .u64 b,
    .param .u64 c,
    .param .u64 k_tiles
)
{{
    .reg .u64 %rd<32>;
    .reg .u32 %r<160>;
    .reg .pred %p1;
    .reg .pred %pmore;
    .reg .pred %pload_a;
    .reg .pred %pload_b;
    .reg .pred %prx0;
    .reg .pred %prx1;
    .reg .pred %prxr;
    .reg .pred %phlbx;
    .reg .pred %phlby;
    .reg .pred %phlb_oob;
    .reg .b32 %ra<4>;
    .reg .b32 %rbl<4>;
    .reg .b32 %rbh<4>;
    .reg .f32 %fc<16>;

    ld.param.u64 %rd0, [a];
    ld.param.u64 %rd1, [b];
    ld.param.u64 %rd2, [c];
    ld.param.u64 %rd3, [k_tiles];

{hilbert}

    mov.u32 %r1, %tid.x;
    shr.u32 %r2, %r1, 5;        // warp id in [0, 32)
    shr.u32 %r3, %r2, 2;        // m_tile = warp >> 2  in [0, 8)
    and.b32 %r4, %r2, 3;        // n_tile = warp & 3   in [0, 4)
    and.b32 %r50, %r1, 31;      // lane id

    // Vectorised cooperative-load predicates / indexing.
    setp.lt.u32 %pload_a, %r1, 256;
    setp.lt.u32 %pload_b, %r1, 512;

    and.b32 %r12, %r1, 255;     // vec_idx
    shr.u32 %r13, %r12, 1;      // row in [0, 128)
    and.b32 %r14, %r12, 1;      // col_q in {{0,1}}
    shl.b32 %r15, %r14, 4;      // col_q * 16  (byte offset within 32-B row)

    // A_cta base = a + sw_y * {a_ctay_byte}   (sw_y in %r10)
    mul.lo.u32 %r5, %r10, {a_ctay_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd0, %rd4;

    // B_cta base = b + sw_x * {b_ctax_byte}   (sw_x in %r11)
    mul.lo.u32 %r5, %r11, {b_ctax_byte};
    cvt.u64.u32 %rd5, %r5;
    add.u64 %rd11, %rd1, %rd5;

    // Per-thread global-load offset (excluding k-step advance):
    //   row * {ab_row_b} + col_q * 16
    mul.lo.u32 %r16, %r13, {ab_row_b};
    add.u32 %r16, %r16, %r15;
    cvt.u64.u32 %rd14, %r16;
    add.u64 %rd14, %rd10, %rd14;        // %rd14 = A_cta + row*{ab_row_b} + col_q*16

    cvt.u64.u32 %rd15, %r16;
    add.u64 %rd15, %rd11, %rd15;        // %rd15 = B_cta + row*{ab_row_b} + col_q*16

    // Per-thread intra-slab shared-mem store offset:
    //   row*32 + col_q*16   in {{0..4080}} step 16
    shl.b32 %r17, %r13, 5;              // row * 32
    add.u32 %r17, %r17, %r15;           // + col_q*16

    mov.u32 %r18, _tg_a;
    mov.u32 %r20, _tg_b;

    // Per-warp shared-mem READ base offsets:
    mul.lo.u32 %r22, %r3, 512;          // A_base = m_tile * 512
    mul.lo.u32 %r24, %r4, 1024;         // B_lo_base = n_tile * 1024
    add.u32 %r25, %r24, 512;            // B_hi_base = n_tile * 1024 + 512

    // ldmatrix per-lane intra-subtile address (16x16 fragment):
    shr.u32 %r51, %r50, 3;
    and.b32 %r52, %r50, 7;
    shr.u32 %r53, %r51, 1;
    shl.b32 %r54, %r53, 3;
    add.u32 %r55, %r54, %r52;
    and.b32 %r56, %r51, 1;
    shl.b32 %r57, %r56, 4;
    shl.b32 %r58, %r55, 5;
    add.u32 %r59, %r58, %r57;

    // C base address.
    //   C_warp_base = c + sw_y * {c_ctay_byte}     (128 M-rows per sw_y)
    //                   + m_tile * {c_warpm_byte}   (16 M-rows per m_tile)
    //                   + sw_x * 512                (128 N-cols * 4 B = 512 B per sw_x)
    //                   + n_tile * 128              (32 N-cols * 4 B = 128 B per n_tile)
    mul.lo.u32 %r5, %r10, {c_ctay_byte};
    mul.lo.u32 %r6, %r3, {c_warpm_byte};
    add.u32 %r7, %r5, %r6;
    mul.lo.u32 %r8, %r11, 512;
    add.u32 %r7, %r7, %r8;
    mul.lo.u32 %r8, %r4, 128;
    add.u32 %r7, %r7, %r8;
    cvt.u64.u32 %rd6, %r7;
    add.u64 %rd12, %rd2, %rd6;

    // Init accumulator -- 16 f32 = 4 m16n8k16 calls (2 N sub-tiles * 2 m16n8 halves).
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

    cvt.s32.s64 %r0, %rd3;

    mov.u32 %r30, 0;                     // current slot

    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    // ---- PROLOGUE: issue K=0 prefetch into slot 0 ----
    add.u32 %r40, %r18, %r17;
    @%pload_a cp.async.cg.shared.global [%r40], [%rd14], 16;

    add.u32 %r41, %r20, %r17;
    @%pload_a bra $skip_b_prologue;
    @%pload_b cp.async.cg.shared.global [%r41], [%rd15], 16;
$skip_b_prologue:
    cp.async.commit_group;

    add.u64 %rd14, %rd14, 32;            // advance by K_TILE_BYTES = 16*2 = 32 B
    add.u64 %rd15, %rd15, 32;

$kloop:
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    setp.gt.s32 %pmore, %r0, 1;
    @!%pmore bra $no_prefetch;

    xor.b32 %r31, %r30, 1;
    shl.b32 %r32, %r31, 12;              // next_slot * 4096   (slab size = 4096 B)

    add.u32 %r40, %r18, %r32;
    add.u32 %r40, %r40, %r17;
    @%pload_a cp.async.cg.shared.global [%r40], [%rd14], 16;

    add.u32 %r41, %r20, %r32;
    add.u32 %r41, %r41, %r17;
    @%pload_a bra $skip_b_kick;
    @%pload_b cp.async.cg.shared.global [%r41], [%rd15], 16;
$skip_b_kick:

    cp.async.commit_group;
    cp.async.wait_group 1;
    bra $consume;

$no_prefetch:
    cp.async.wait_all;

$consume:
    bar.sync 0;

    // Slab base + per-warp 16x16 subtile offset.
    shl.b32 %r34, %r30, 12;              // current_slot * 4096
    add.u32 %r35, %r18, %r34;            // A slab base in shmem
    add.u32 %r35, %r35, %r22;            //   + m_tile * 512  (warp's 16-row band)
    add.u32 %r36, %r20, %r34;            // B slab base in shmem
    add.u32 %r37, %r36, %r25;            // B_hi base
    add.u32 %r36, %r36, %r24;            // B_lo base

    add.u32 %r60, %r35, %r59;            // ldmatrix.x4 A addr
    add.u32 %r61, %r36, %r59;            // ldmatrix.x4.trans B_lo addr
    add.u32 %r62, %r37, %r59;            // ldmatrix.x4.trans B_hi addr

    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra0, %ra1, %ra2, %ra3}}, [%r60];

    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbl0, %rbl1, %rbl2, %rbl3}}, [%r61];

    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbh0, %rbh1, %rbh2, %rbh3}}, [%r62];

    // 4x mma.m16n8k16 per K-step.
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

    bar.sync 0;

    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

    xor.b32 %r30, %r30, 1;
    sub.s32 %r0, %r0, 1;
    bra $kloop;

$epilogue:
    // mma.m16n8k16 D-frag store. 4 sub-tiles at N-offsets 0/32/64/96 B.
    shr.u32 %r70, %r50, 2;               // group = lane >> 2  in [0,8)
    and.b32 %r71, %r50, 3;               // col_q = lane & 3   in [0,4)
    mul.lo.u32 %r72, %r70, {S*4};        // group * row_stride_bytes (S * 4 B)
    shl.b32 %r73, %r71, 3;               // col_q * 2 * 4 = col_q * 8
    add.u32 %r74, %r72, %r73;
    cvt.u64.u32 %rd20, %r74;
    add.u64 %rd20, %rd12, %rd20;         // base = C_warp + group*S*4 + col_q*8

    add.u64 %rd21, %rd20, {8*S*4};       // base for row1 (group+8)

    // mma_lo_left (cols 0..7):
    st.global.f32 [%rd20 +     0], %fc0;
    st.global.f32 [%rd20 +     4], %fc1;
    st.global.f32 [%rd21 +     0], %fc2;
    st.global.f32 [%rd21 +     4], %fc3;

    // mma_lo_right (cols 8..15):  +32 B = 8 * 4 B
    st.global.f32 [%rd20 +    32], %fc4;
    st.global.f32 [%rd20 +    36], %fc5;
    st.global.f32 [%rd21 +    32], %fc6;
    st.global.f32 [%rd21 +    36], %fc7;

    // mma_hi_left (cols 16..23): +64 B
    st.global.f32 [%rd20 +    64], %fc8;
    st.global.f32 [%rd20 +    68], %fc9;
    st.global.f32 [%rd21 +    64], %fc10;
    st.global.f32 [%rd21 +    68], %fc11;

    // mma_hi_right (cols 24..31): +96 B
    st.global.f32 [%rd20 +    96], %fc12;
    st.global.f32 [%rd20 +   100], %fc13;
    st.global.f32 [%rd21 +    96], %fc14;
    st.global.f32 [%rd21 +   100], %fc15;

    ret;

$hilbert_oob_ret:
    // padding CTA (sw_x>=side or sw_y>=side) -- no output tile, return immediately.
    ret;
}}
"""


# Large-M cliff regime (same shapes as N149 for direct comparison). All 128-aligned.
SHAPES = [4096, 5120, 6144, 8192]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        assert S % 128 == 0, f"S={S} not 128-aligned"
        p = outdir / f"sgemm_tile128_hilbert_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes (bijection verified per shape)")
