#!/usr/bin/env python3
"""RFC 067 PCOND -- 4-WARP 64x64 + CONDITIONAL CTA-swizzle (identity small-M, Hilbert large-M).

Follow-on to N168, which found swizzle+pipeline regime-orthogonal:
    N107 PY (identity CTA map): small-M strong (M=256 ratio 1.061, M=384 0.868,
        M=512 0.911), but M>=6144 falls off an L2-thrash cliff (M=6144 0.234 in N130).
    N149 PHILB (Hilbert d2xy CTA map): recovers the cliff (M=4096 0.821, M=5120 0.827,
        M=6144 0.834, M=8192 0.847), BUT the unrolled-Hilbert prologue HURTS small M
        because it is not amortised over the short K-loop (N168: M=384 0.98 -> 0.64).

N168 conclusion (verbatim intent): "true best single kernel needs swizzle applied
CONDITIONALLY (identity at small M, d2xy at large M)".

This kernel does exactly that. At kernel ENTRY it branches on the launch grid size
(grid CTA count = gridDim.x * gridDim.y), which is a UNIFORM, grid-constant value
identical for every CTA -> NO warp divergence, predicated once:

    if (gridDim.x * gridDim.y <= THRESHOLD):
        # identity path: sw_x = ctaid.x, sw_y = ctaid.y. NO Hilbert d2xy prologue.
        # (launch grid = gx x gy = side x side, no padding CTAs)
    else:
        # Hilbert path: (sw_x, sw_y) = hilbert_d2xy(p, ctaid.y*p + ctaid.x);
        # early-return padding CTAs (sw_x>=gx || sw_y>=gy).
        # (launch grid = p x p, p = next_pow2(side))

THRESHOLD choice (g3 honest, mapped to a CTA-count cutoff -> M boundary):
  - Identity path launches gx x gy = side x side CTAs (side = M/64).
        M=256  ->  4x4    =    16 CTAs
        M=384  ->  6x6    =    36 CTAs
        M=512  ->  8x8    =    64 CTAs
        M=1024 -> 16x16   =   256 CTAs
        M=2048 -> 32x32   =  1024 CTAs
        M=4096 -> 64x64   =  4096 CTAs
  - Hilbert path launches p x p (p = next_pow2(side)) CTAs:
        M=5120 (side 80)  -> p=128 -> 128x128 = 16384 CTAs
        M=6144 (side 96)  -> p=128 -> 128x128 = 16384 CTAs
        M=8192 (side 128) -> p=128 -> 128x128 = 16384 CTAs
  - Per N167/N130/N134: M<=4096 fits L2 at ~98% (no thrash, identity is best);
    M>=5120 (side 80) begins L2 thrash (recovered by Hilbert). So the M boundary is
    between M=4096 and M=5120.
  - The two paths use DIFFERENT launch grids (side x side vs p x p). The cleanest
    grid-count cutoff that separates them is:
        THRESHOLD = 4096    (M=4096 identity grid = 4096 CTAs <= 4096 -> identity;
                             M=5120 Hilbert grid = 16384 CTAs  > 4096 -> Hilbert)
  - This is robust: every identity-regime shape (M<=4096) has gx*gy <= 4096, and
    every Hilbert-regime shape (M>=5120) launches p*p = 16384 > 4096. The host picks
    the matching launch grid; the in-kernel branch resolves to the same decision.

Bit-exactness: both paths are semantic-preserving (only CTA->tile visitation order
differs). Identity is the natural map; Hilbert is bijective over the real gx x gy grid
(verified in the generator). max_abs MUST be 0.0 vs cuBLAS HGEMM at every shape.

Honest scope (@D g3):
  - The branch adds ~5 instructions at kernel entry (one mul + one setp on gridDim,
    one predicated bra). It is uniform across all CTAs (grid-size constant) -> no warp
    divergence; ptxas predicates it once. Negligible vs the K-loop work.
  - The identity path is BYTE-IDENTICAL to N107 PY in the steady-state K-loop (same
    ldmatrix / mma / cp.async / epilogue). The Hilbert path is BYTE-IDENTICAL to N149
    PHILB. The only addition is the entry branch + a second base-address computation
    block selected by the branch.
  - Both base-address blocks are emitted; the taken branch skips the other. The
    register pool is shared; Hilbert scratch (%r100..%r129) is only live on the
    Hilbert path, identity path uses ctaid directly.
  - Each shape's PTX bakes its own gx, gy, p, and the threshold-compare. The same PTX
    file works whether launched as side x side (small) or p x p (large) because the
    entry branch reads the actual gridDim.
"""

import sys
from pathlib import Path


# CTA-count cutoff. Identity-regime shapes (M<=4096) launch side x side CTAs with
# gx*gy <= 4096; Hilbert-regime shapes (M>=5120) launch p x p = 16384 > 4096.
THRESHOLD_CTAS = 4096


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
    """Emit straight-line (unrolled) Hilbert d2xy PTX (Pattern B, byte-identical to N149).

    Inputs:  ctaid.x, ctaid.y  (grid is p x p)
    Outputs: %r10 = sw_y (= hy),  %r11 = sw_x (= hx)
    Predicate %phlb_oob true if (hx>=gx || hy>=gy) -> caller early-returns.
    Registers: %r100..%r129 scratch (live only on Hilbert path).
    """
    log2p = p.bit_length() - 1
    lines = []
    lines.append("    // ---- CONDITIONAL Hilbert path: d2xy(p, ctaid.y*p+ctaid.x) ----")
    lines.append(f"    //   grid = p x p, p = {p} (next_pow2(gx={gx})); d = ctaid.y*p + ctaid.x")
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
    assert S % 64 == 0, f"S={S} must be divisible by 64"

    a_ctay_byte  = 64 * S * 2          # ctaid.y stride: 64 rows * S * 2B
    b_ctax_byte  = 64 * S * 2          # ctaid.x stride: 64 cols * S * 2B
    c_ctay_byte  = 64 * S * 4          # C is f32, 64 rows
    c_warpm_byte = 32 * S * 4          # m_tile * 32 rows of C
    ab_row_b     = S * 2               # one A row / B col stride in B

    gx = S // 64
    gy = S // 64
    p  = next_pow2(gx)

    # Hilbert is bijective over the real grid -- verify regardless of regime.
    verify_bijection(p, gx, gy)
    hilbert = emit_hilbert_prologue(p, gx, gy)

    regime = "identity" if (gx * gy <= THRESHOLD_CTAS) else "hilbert"

    return f"""// RFC 067 PCOND perf HGEMM hexa-emit -- 4-WARP 64x64 + CONDITIONAL CTA-swizzle -- M=N=K={S}.
//
// Conditional CTA-swizzle (identity at small M, Hilbert d2xy at large M):
//   At kernel entry, branch on grid CTA count (gridDim.x * gridDim.y), a UNIFORM
//   grid-constant -> NO warp divergence, predicated once:
//     if (gridDim.x * gridDim.y <= {THRESHOLD_CTAS})  -> identity (sw=ctaid), NO Hilbert prologue
//     else                                          -> Hilbert d2xy + padding early-return
//   THRESHOLD_CTAS={THRESHOLD_CTAS}: M<=4096 launch side x side (gx*gy<=4096 -> identity);
//   M>=5120 launch p x p = 16384 > 4096 -> Hilbert. (per N167: M<=4096 fits L2 ~98%,
//   M>=5120 thrashes -> Hilbert recovers the cliff; N168 found Hilbert prologue hurts small M.)
//   For THIS shape S={S}: gx*gy = {gx*gy}, p = {p} -> regime-at-launch = {regime}.
//
// Layout:
//   A row-major     [M={S} x K={S}] f16. Row stride = {ab_row_b} B.
//   B col-major     [K={S} x N={S}] f16. Col stride = {ab_row_b} B.
//   C row-major out [M={S} x N={S}] f32. Row stride = {S*4} B.
//
// Identity-path K-loop is byte-identical to N107 PY; Hilbert-path is byte-identical to N149 PHILB.

.version 8.0
.target sm_90
.address_size 64

.shared .align 16 .b8 _tg_a[4096];
.shared .align 16 .b8 _tg_b[4096];

.visible .entry sgemm_4warp_cond_{S}x{S}_grid (
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
    .reg .pred %pcond;
    .reg .pred %prx0;
    .reg .pred %prx1;
    .reg .pred %prxr;
    .reg .pred %phlbx;
    .reg .pred %phlby;
    .reg .pred %phlb_oob;
    .reg .b32 %ra<8>;
    .reg .b32 %rbl<4>;
    .reg .b32 %rbh<4>;
    .reg .f32 %fc<32>;

    ld.param.u64 %rd0, [a];
    ld.param.u64 %rd1, [b];
    ld.param.u64 %rd2, [c];
    ld.param.u64 %rd3, [k_tiles];

    // ---- CONDITIONAL CTA-swizzle gate (uniform, predicated once, no divergence) ----
    //   grid_ctas = gridDim.x * gridDim.y ; if grid_ctas <= THRESHOLD -> identity.
    mov.u32 %r140, %nctaid.x;
    mov.u32 %r141, %nctaid.y;
    mul.lo.u32 %r142, %r140, %r141;       // grid_ctas = gridDim.x * gridDim.y
    setp.le.u32 %pcond, %r142, {THRESHOLD_CTAS};
    @%pcond bra $identity_map;

    // === HILBERT PATH (large M, L2-reuse) ===
{hilbert}
    bra $swizzle_done;

$identity_map:
    // === IDENTITY PATH (small M, no Hilbert prologue overhead) ===
    mov.u32 %r10, %ctaid.y;          // sw_y = ctaid.y
    mov.u32 %r11, %ctaid.x;          // sw_x = ctaid.x

$swizzle_done:
    // ---- steady-state body uses (sw_x in %r11, sw_y in %r10); byte-identical to N107/N149 ----

    mov.u32 %r1, %tid.x;
    shr.u32 %r2, %r1, 5;        // warp id in [0, 4)
    shr.u32 %r3, %r2, 1;        // m_tile = warp >> 1  in [0, 2)
    and.b32 %r4, %r2, 1;        // n_tile = warp & 1   in [0, 2)
    and.b32 %r50, %r1, 31;      // lane id

    // Cooperative-load indexing: each tid in [0, 128) issues 1 vec16 A + 1 vec16 B.
    shr.u32 %r13, %r1, 1;       // row in [0, 64)
    and.b32 %r14, %r1, 1;       // col_q in {{0, 1}}
    shl.b32 %r15, %r14, 4;      // col_q * 16  (byte offset within 32-B row)

    // XOR swizzle slot (DISABLED -- matches N107/N149 identity; isolates CTA swizzle).
    mov.u32 %r80, 0;
    xor.b32 %r81, %r14, %r80;
    shl.b32 %r82, %r81, 4;

    // A_cta base = a + sw_y * {a_ctay_byte}   (sw_y in %r10)
    mul.lo.u32 %r5, %r10, {a_ctay_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd0, %rd4;

    // B_cta base = b + sw_x * {b_ctax_byte}   (sw_x in %r11)
    mul.lo.u32 %r5, %r11, {b_ctax_byte};
    cvt.u64.u32 %rd5, %r5;
    add.u64 %rd11, %rd1, %rd5;

    // Per-thread global-load offset (excluding k-step advance):
    mul.lo.u32 %r16, %r13, {ab_row_b};
    add.u32 %r16, %r16, %r15;
    cvt.u64.u32 %rd14, %r16;
    add.u64 %rd14, %rd10, %rd14;        // %rd14 = A_cta + row*{ab_row_b} + col_q*16

    cvt.u64.u32 %rd15, %r16;
    add.u64 %rd15, %rd11, %rd15;        // %rd15 = B_cta + row*{ab_row_b} + col_q*16

    // Per-thread intra-slab shared-mem store offset (SWIZZLED):
    shl.b32 %r17, %r13, 5;              // row * 32
    add.u32 %r17, %r17, %r82;           // + phys_chunk * 16

    mov.u32 %r18, _tg_a;
    mov.u32 %r20, _tg_b;

    // Per-warp shared-mem READ base offsets:
    mul.lo.u32 %r22, %r3, 1024;         // A_base = m_tile * 1024
    mul.lo.u32 %r24, %r4, 1024;         // B_base = n_tile * 1024

    // ldmatrix per-lane intra-subtile address (16x16 fragment, UN-SWIZZLED logical):
    shr.u32 %r51, %r50, 3;
    and.b32 %r52, %r50, 7;
    shr.u32 %r53, %r51, 1;
    shl.b32 %r54, %r53, 3;
    add.u32 %r55, %r54, %r52;            // row_idx
    and.b32 %r56, %r51, 1;
    shl.b32 %r57, %r56, 4;               // col_off (log)

    // XOR swizzle read-side (DISABLED, identity).
    mov.u32 %r83, 0;
    shl.b32 %r84, %r83, 4;
    xor.b32 %r85, %r57, %r84;
    shl.b32 %r58, %r55, 5;
    add.u32 %r59, %r58, %r85;

    // C base address.
    mul.lo.u32 %r5, %r10, {c_ctay_byte};
    mul.lo.u32 %r6, %r3, {c_warpm_byte};
    add.u32 %r7, %r5, %r6;
    mul.lo.u32 %r8, %r11, 256;
    add.u32 %r7, %r7, %r8;
    mul.lo.u32 %r8, %r4, 128;
    add.u32 %r7, %r7, %r8;
    cvt.u64.u32 %rd6, %r7;
    add.u64 %rd12, %rd2, %rd6;

    // Init accumulator -- 32 f32 = 8 mma.m16n8k16 (2 M sub * 4 N sub-8).
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

    cvt.s32.s64 %r0, %rd3;

    mov.u32 %r30, 0;                     // current slot

    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    // ---- PROLOGUE: issue K=0 prefetch into slot 0 ----
    add.u32 %r40, %r18, %r17;
    cp.async.cg.shared.global [%r40], [%rd14], 16;

    add.u32 %r41, %r20, %r17;
    cp.async.cg.shared.global [%r41], [%rd15], 16;

    cp.async.commit_group;

    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

$kloop:
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    setp.gt.s32 %pmore, %r0, 1;
    @!%pmore bra $no_prefetch;

    xor.b32 %r31, %r30, 1;
    shl.b32 %r32, %r31, 11;              // next_slot * 2048

    add.u32 %r40, %r18, %r32;
    add.u32 %r40, %r40, %r17;
    cp.async.cg.shared.global [%r40], [%rd14], 16;

    add.u32 %r41, %r20, %r32;
    add.u32 %r41, %r41, %r17;
    cp.async.cg.shared.global [%r41], [%rd15], 16;

    cp.async.commit_group;
    cp.async.wait_group 1;
    bra $consume;

$no_prefetch:
    cp.async.wait_all;

$consume:
    bar.sync 0;

    shl.b32 %r34, %r30, 11;              // current_slot * 2048
    add.u32 %r35, %r18, %r34;
    add.u32 %r35, %r35, %r22;
    add.u32 %r36, %r20, %r34;
    add.u32 %r36, %r36, %r24;

    add.u32 %r60, %r35, %r59;
    add.u32 %r62, %r60, 512;
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra0, %ra1, %ra2, %ra3}}, [%r60];
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra4, %ra5, %ra6, %ra7}}, [%r62];

    add.u32 %r61, %r36, %r59;
    add.u32 %r63, %r61, 512;
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbl0, %rbl1, %rbl2, %rbl3}}, [%r61];
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbh0, %rbh1, %rbh2, %rbh3}}, [%r63];

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

    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

    xor.b32 %r30, %r30, 1;
    sub.s32 %r0, %r0, 1;
    bra $kloop;

$epilogue:
    shr.u32 %r70, %r50, 2;               // group = lane >> 2
    and.b32 %r71, %r50, 3;               // col_q = lane & 3
    mul.lo.u32 %r72, %r70, {S*4};
    shl.b32 %r73, %r71, 3;
    add.u32 %r74, %r72, %r73;
    cvt.u64.u32 %rd20, %r74;
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
    // padding CTA (sw_x>=gx or sw_y>=gy) on the Hilbert path -- no output tile.
    ret;
}}
"""


# Full-range sweep -- spans both regimes (identity small-M + Hilbert large-M).
SHAPES = [256, 384, 512, 1024, 2048, 4096, 6144, 8192]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        assert S % 64 == 0, f"S={S} not 64-aligned"
        p = outdir / f"sgemm_4warp_cond_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        side = S // 64
        regime = "identity" if (side * side <= THRESHOLD_CTAS) else "hilbert"
        print(f"wrote {p.name} ({len(p.read_text())} bytes) regime={regime} grid_ctas={side*side}")
    print(f"total {len(SHAPES)} shapes (Hilbert bijection verified per shape), THRESHOLD_CTAS={THRESHOLD_CTAS}")
