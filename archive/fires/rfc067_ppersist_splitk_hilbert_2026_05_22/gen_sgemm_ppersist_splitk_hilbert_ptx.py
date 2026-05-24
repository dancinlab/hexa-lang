#!/usr/bin/env python3
"""RFC 067 PPSH -- Persistent CTA + Split-K + Hilbert visitation on large M (4096/6144/8192).

Stack:
  N149 (PHILB) Hilbert 4-warp 64x64 -- M=8192 ratio 0.847 (best @ cliff).
  N94  (PV)    persistent CTA over N77 body -- failed -0.39% on square shapes
               (per-tile work dwarfs scheduler dispatch overhead at small M).

Hypothesis for this fire:
  At LARGE M (4096+) two effects swap:
    (a) Per-tile MMA work is huge; scheduler-dispatch overhead is amortised.
    (b) L2 working set spans 32 MB and pressure dominates.
  PHILB already covers (b) via Hilbert visitation order.
  Persistent CTA (1 CTA/SM) **further** improves L2 locality because each CTA
  walks a contiguous block of Hilbert indices -- the SM resident cache is
  warm across the entire run of tiles owned by that CTA, instead of churning
  between adjacent groups of CTAs scheduled together by the GPU grid scheduler.
  Plus, Split-K provides parallel-reduction over K -- when total_tiles >= num_SMs
  the grid is already saturated, so the only way to get MORE parallel work is
  to split K and do an atomic-add reduce. For very large K (=M=8192) this can
  push us past the K-loop serialisation bottleneck.

Design:
  G = NUM_K_SPLITS = 4 (configurable -- chosen so K/G = 1024/2048 K-elements/group)
  P = NUM_PERSISTENT = num_SMs (measured at host; we hardcode 48 for RTX 5070)
  Launch grid = (P * G, 1, 1) = 192 CTAs total.
    -- ctaid.x in [0, P*G).
    -- k_group   = ctaid.x / P  in [0, G)         -- which K-slice does this CTA handle?
    -- cta_in_g  = ctaid.x % P  in [0, P)         -- which persistent slot in the K-slice?

  Hilbert visitation:
    Total output tiles = side*side where side = M/64.
    Hilbert curve covers a p x p square where p = next_pow2(side).
    For each k_group, the P persistent CTAs cover all real tiles by walking the
    Hilbert curve. CTA cta_in_g handles a CONTIGUOUS run of Hilbert indices:
        d_start = cta_in_g * ceil(p*p / P)
        d_end   = min(d_start + ceil(p*p / P), p*p)
    Walking contiguous Hilbert IDs preserves the L2-locality argument from N149.
    Padding tiles (sw_x>=side || sw_y>=side) skipped within the walk.

  Split-K reduction:
    Group g operates on K-slice [g*K_g, (g+1)*K_g) where K_g = K / G.
    K-step count per CTA: K_g / 16  (each mma.m16n8k16 consumes 16 K-elements).
    A_g = a + g*K_g*2 bytes (A is row-major K-stride 1)
    B_g = b + g*K_g*2 bytes (B is col-major K-stride 1)
    Output: atom.global.add.f32 [C_addr], %fc_i  for each of the 32 accumulator regs.
    Host pre-zeros C to ensure correctness.

Body (per-tile):
  Identical to N149 PHILB kernel: 4-warp 64x64 output tile, ldmatrix.x4 +
  2x mma.m16n8k16 + cp.async.cg vec16, 32 f32 accumulators, 8 mma per K-step.
  Only differences:
    - K-step count is K_g/16 (not K/16) -- shorter inner loop.
    - K-base pointer offset added to A/B base.
    - Epilogue uses atom.global.add.f32 instead of st.global.f32.

Falsifier F-RFC067-HEXA-PERSIST-SPLITK-HILBERT:
  - Numeric: per-element maxabs vs cuBLAS HGEMM.
    SPLIT-K atomic-add changes accumulation ORDER -> NOT bit-exact.
    Tolerance: max_abs <= 4 ULP of float32 around the magnitude of cuBLAS values.
    Since A_ij in {-0.25..0.25} (step 1/16) and B_ij in {-0.25..0.25} (step 1/8),
    expected C_ij has magnitude up to ~K * 0.0625 = K * 1/16. At K=8192 -> max 512.
    4 ULP at magnitude 512 = 4 * 6.1e-5 ~ 2.4e-4. We accept max_abs <= 2.5e-4.
    (Recorded as "split_k_atomic_add: max_abs ULP-relative" in result.json.)
  - Per-shape median TFLOPS over 200 reps (20 warmup), cuEvent sync.
  - Headline: per-shape ratio vs cuBLAS HGEMM; vs N149 PHILB; vs cuBLAS.

g3 honest scope:
  - Atomic-add ordering non-deterministic -- ULP-relative tolerance asserted.
  - Persistent CTA = P CTAs/grid (1 per SM); compared to 16384 in N149 PHILB,
    we LOSE the GPU scheduler's built-in latency-hiding via 8 CTAs/SM. If this
    matters more than L2 locality + amortised dispatch + parallel K, regress.
  - Atomic-add over 32 f32 regs per CTA per tile is a real cost; report
    estimated overhead = 32 * tiles_per_cta * P * G atomic ops per call.
  - Useful negative possible: if persistent + split-K REGRESSES vs N149, then
    the GPU scheduler + Hilbert was already near-optimal on this substrate.
"""

import sys
from pathlib import Path


# --- Tunables (compile-time constants baked into PTX) ---
NUM_K_SPLITS    = 4    # G -- number of split-K groups
NUM_PERSISTENT  = 48   # P -- num_SMs on RTX 5070 (matches N94 measurement)


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
            assert (x, y) not in seen, f"dup ({x},{y}) p={p}"
            seen.add((x, y))
    assert len(seen) == gx * gy, f"cover {len(seen)} != {gx*gy}"


def emit_hilbert_round(it: int, s: int) -> str:
    """One unrolled Hilbert round; reads/writes %r120 (d), %r121 (x), %r122 (y)."""
    sm1 = s - 1
    L = []
    L.append(f"    // -- Hilbert round {it}: s = {s} --")
    L.append("    shr.u32 %r126, %r120, 1;")
    L.append("    and.b32 %r123, %r126, 1;          // rx")
    L.append("    xor.b32 %r127, %r120, %r123;")
    L.append("    and.b32 %r124, %r127, 1;          // ry")
    L.append("    setp.eq.u32 %prx0, %r124, 0;      // ry==0")
    L.append("    setp.eq.u32 %prx1, %r123, 1;      // rx==1")
    L.append("    and.pred %prxr, %prx0, %prx1;     // need_reflect")
    L.append(f"    sub.u32 %r128, {sm1}, %r121;")
    L.append(f"    sub.u32 %r129, {sm1}, %r122;")
    L.append("    selp.b32 %r121, %r128, %r121, %prxr;")
    L.append("    selp.b32 %r122, %r129, %r122, %prxr;")
    L.append("    selp.b32 %r128, %r122, %r121, %prx0;")
    L.append("    selp.b32 %r122, %r121, %r122, %prx0;")
    L.append("    mov.u32 %r121, %r128;")
    L.append(f"    mul.lo.u32 %r128, %r123, {s};")
    L.append("    add.u32 %r121, %r121, %r128;")
    L.append(f"    mul.lo.u32 %r129, %r124, {s};")
    L.append("    add.u32 %r122, %r122, %r129;")
    return "\n".join(L)


def emit_hilbert_unroll(p: int) -> str:
    """Emit unrolled Hilbert d2xy body that reads %r120 (d in) and writes %r121 (x), %r122 (y)."""
    log2p = p.bit_length() - 1
    L = []
    L.append("    mov.u32 %r121, 0;                 // x")
    L.append("    mov.u32 %r122, 0;                 // y")
    s = 1
    for it in range(log2p):
        L.append(emit_hilbert_round(it, s))
        if it != log2p - 1:
            L.append("    shr.u32 %r120, %r120, 2;     // t >>= 2")
        s <<= 1
    return "\n".join(L)


def gen(S: int) -> str:
    """Generate PTX for square M=N=K=S, persistent + split-K + Hilbert visitation."""
    assert S % 64 == 0, f"S={S} must be /64"
    assert S % 16 == 0, f"S={S} must be /16 (K-step granularity)"

    G = NUM_K_SPLITS
    P = NUM_PERSISTENT

    K_TILES_TOTAL = S // 16
    assert K_TILES_TOTAL % G == 0, f"K_TILES_TOTAL={K_TILES_TOTAL} not divisible by G={G}"
    K_TILES_PER_GROUP = K_TILES_TOTAL // G
    K_BYTES_PER_GROUP = K_TILES_PER_GROUP * 16 * 2  # 2 B per fp16

    a_ctay_byte  = 64 * S * 2       # 64 rows * S * 2B
    b_ctax_byte  = 64 * S * 2       # 64 cols * S * 2B
    c_ctay_byte  = 64 * S * 4       # 64 rows * S * 4B (f32 atomic)
    c_warpm_byte = 32 * S * 4       # 32 m-rows * S * 4B
    ab_row_b     = S * 2

    gx = S // 64
    gy = S // 64
    p  = next_pow2(gx)

    verify_bijection(p, gx, gy)

    # CTA's contiguous Hilbert range: [d_start, d_end). Computed in kernel from cta_in_g.
    # tiles_per_cta = ceil((p*p) / P)
    tiles_per_cta_pp = (p * p + P - 1) // P

    hilbert_body = emit_hilbert_unroll(p)
    log2p = p.bit_length() - 1

    return f"""// RFC 067 PPSH hexa-emit -- Persistent CTA (P={P}) + Split-K (G={G}) + Hilbert visitation. M=N=K={S}.
//
//   Grid    = ({P*G},1,1)  -- P*G CTAs, 1 per (k_group, cta_in_g).
//   k_group  = ctaid.x / P  in [0, G); cta_in_g = ctaid.x % P in [0, P).
//   Each CTA walks a contiguous Hilbert range of {tiles_per_cta_pp} tiles
//   (skipping padding sw_x>={gx} || sw_y>={gy}). Inner K-loop = {K_TILES_PER_GROUP} steps.
//   Output: atom.global.add.f32 (split-K reduction).
//
// Layout (per shape M=N=K={S}):
//   p = {p}  (= next_pow2(side {gx}))  -- Hilbert log2p = {log2p} rounds
//   total real tiles = {gx*gx}; tiles_per_cta = {tiles_per_cta_pp} (last CTA may run fewer)
//   k_per_group = {K_TILES_PER_GROUP * 16} K-elements; K_TILES_PER_GROUP = {K_TILES_PER_GROUP} mma steps

.version 8.0
.target sm_90
.address_size 64

.shared .align 16 .b8 _tg_a[4096];
.shared .align 16 .b8 _tg_b[4096];

.visible .entry sgemm_ppsh_{S}x{S}_grid (
    .param .u64 a,
    .param .u64 b,
    .param .u64 c,
    .param .u64 k_tiles_per_group
)
{{
    .reg .u64 %rd<32>;
    .reg .u32 %r<200>;
    .reg .pred %p1;
    .reg .pred %pmore;
    .reg .pred %ptile_done;
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
    .reg .f32 %ftmp;

    ld.param.u64 %rd0, [a];
    ld.param.u64 %rd1, [b];
    ld.param.u64 %rd2, [c];
    ld.param.u64 %rd3, [k_tiles_per_group];

    // ---- Persistent slot decode ----
    mov.u32 %r150, %ctaid.x;                         // raw CTA id
    // k_group = ctaid.x / P; cta_in_g = ctaid.x mod P.
    div.u32 %r151, %r150, {P};                       // %r151 = k_group
    rem.u32 %r152, %r150, {P};                       // %r152 = cta_in_g

    // ---- K-base offsets per group ----
    //   A_g_base = a + k_group * {K_BYTES_PER_GROUP}
    //   B_g_base = b + k_group * {K_BYTES_PER_GROUP}
    mul.lo.u32 %r153, %r151, {K_BYTES_PER_GROUP};
    cvt.u64.u32 %rd16, %r153;
    add.u64 %rd17, %rd0, %rd16;                      // %rd17 = A_g base
    add.u64 %rd18, %rd1, %rd16;                      // %rd18 = B_g base

    // ---- Persistent CTA's Hilbert range [d_start, d_end) ----
    //   d_start = cta_in_g * {tiles_per_cta_pp}; d_end = min(d_start + tile_per_cta, {p*p}).
    mul.lo.u32 %r154, %r152, {tiles_per_cta_pp};     // d_start
    add.u32 %r155, %r154, {tiles_per_cta_pp};        // d_start + per_cta
    min.u32 %r156, %r155, {p*p};                     // d_end

    // ---- Thread-local indices (invariant over the tile loop) ----
    mov.u32 %r1, %tid.x;
    shr.u32 %r2, %r1, 5;        // warp id [0,4)
    shr.u32 %r3, %r2, 1;        // m_tile = warp >> 1 [0,2)
    and.b32 %r4, %r2, 1;        // n_tile = warp & 1 [0,2)
    and.b32 %r50, %r1, 31;      // lane id

    // Cooperative load indexing (vec16 per thread, 128 threads -> 64 rows * 2 col_q).
    shr.u32 %r13, %r1, 1;       // row
    and.b32 %r14, %r1, 1;       // col_q
    shl.b32 %r15, %r14, 4;      // col_q * 16

    shl.b32 %r17, %r13, 5;
    add.u32 %r17, %r17, %r15;   // intra-slab shared store offset

    mov.u32 %r18, _tg_a;
    mov.u32 %r20, _tg_b;

    // Per-warp shared-mem READ base offsets:
    mul.lo.u32 %r22, %r3, 1024;
    mul.lo.u32 %r24, %r4, 1024;

    // ldmatrix per-lane intra-subtile address:
    shr.u32 %r51, %r50, 3;
    and.b32 %r52, %r50, 7;
    shr.u32 %r53, %r51, 1;
    shl.b32 %r54, %r53, 3;
    add.u32 %r55, %r54, %r52;
    and.b32 %r56, %r51, 1;
    shl.b32 %r57, %r56, 4;
    shl.b32 %r58, %r55, 5;
    add.u32 %r59, %r58, %r57;

    // Per-thread invariant global-load offset (excluding k-step advance):
    mul.lo.u32 %r16, %r13, {ab_row_b};
    add.u32 %r16, %r16, %r15;                        // row*{ab_row_b} + col_q*16

    // Save the cta_in_g K-step counter (k_tiles_per_group as int32).
    cvt.s32.s64 %r170, %rd3;

    // Persistent Hilbert d-counter starts at d_start.
    mov.u32 %r120, %r154;       // current d

$tileloop:
    setp.ge.u32 %ptile_done, %r120, %r156;
    @%ptile_done bra $tile_exit;

    // ---- Hilbert d2xy on current %r120 (also: we will increment %r120 at tile end).
    // The unrolled rounds DESTRUCTIVELY shift %r120; preserve a copy.
    mov.u32 %r160, %r120;                            // save d for later inc
{hilbert_body}
    // %r121 = sw_x, %r122 = sw_y
    mov.u32 %r11, %r121;
    mov.u32 %r10, %r122;
    mov.u32 %r120, %r160;                            // restore d

    setp.ge.u32 %phlbx, %r11, {gx};
    setp.ge.u32 %phlby, %r10, {gy};
    or.pred %phlb_oob, %phlbx, %phlby;
    @%phlb_oob bra $tile_advance;

    // ---- Compute A/B/C base pointers for this (m_tile=sw_y, n_tile=sw_x) and k_group ----
    // A_cta = A_g + sw_y * 64 * S * 2
    mul.lo.u32 %r5, %r10, {a_ctay_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd17, %rd4;

    // B_cta = B_g + sw_x * 64 * S * 2
    mul.lo.u32 %r5, %r11, {b_ctax_byte};
    cvt.u64.u32 %rd5, %r5;
    add.u64 %rd11, %rd18, %rd5;

    cvt.u64.u32 %rd14, %r16;
    add.u64 %rd14, %rd10, %rd14;
    cvt.u64.u32 %rd15, %r16;
    add.u64 %rd15, %rd11, %rd15;

    // C base (full C, not group-split -- atomic-add target across all groups)
    //   C = c_param + sw_y * (64*S*4) + m_tile_intra * (32*S*4) + sw_x * 256 + n_tile_intra * 128
    mul.lo.u32 %r5, %r10, {c_ctay_byte};
    mul.lo.u32 %r6, %r3, {c_warpm_byte};
    add.u32 %r7, %r5, %r6;
    mul.lo.u32 %r8, %r11, 256;
    add.u32 %r7, %r7, %r8;
    mul.lo.u32 %r8, %r4, 128;
    add.u32 %r7, %r7, %r8;
    cvt.u64.u32 %rd6, %r7;
    add.u64 %rd12, %rd2, %rd6;

    // ---- Zero accumulator (32 regs) ----
    mov.f32 %fc0,  0f00000000; mov.f32 %fc1,  0f00000000;
    mov.f32 %fc2,  0f00000000; mov.f32 %fc3,  0f00000000;
    mov.f32 %fc4,  0f00000000; mov.f32 %fc5,  0f00000000;
    mov.f32 %fc6,  0f00000000; mov.f32 %fc7,  0f00000000;
    mov.f32 %fc8,  0f00000000; mov.f32 %fc9,  0f00000000;
    mov.f32 %fc10, 0f00000000; mov.f32 %fc11, 0f00000000;
    mov.f32 %fc12, 0f00000000; mov.f32 %fc13, 0f00000000;
    mov.f32 %fc14, 0f00000000; mov.f32 %fc15, 0f00000000;
    mov.f32 %fc16, 0f00000000; mov.f32 %fc17, 0f00000000;
    mov.f32 %fc18, 0f00000000; mov.f32 %fc19, 0f00000000;
    mov.f32 %fc20, 0f00000000; mov.f32 %fc21, 0f00000000;
    mov.f32 %fc22, 0f00000000; mov.f32 %fc23, 0f00000000;
    mov.f32 %fc24, 0f00000000; mov.f32 %fc25, 0f00000000;
    mov.f32 %fc26, 0f00000000; mov.f32 %fc27, 0f00000000;
    mov.f32 %fc28, 0f00000000; mov.f32 %fc29, 0f00000000;
    mov.f32 %fc30, 0f00000000; mov.f32 %fc31, 0f00000000;

    // ---- K-loop counter (per group) ----
    mov.u32 %r0, %r170;
    mov.u32 %r30, 0;       // current shared slot

    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $tile_epilogue;

    // ---- PROLOGUE: prefetch K=0 into slot 0 ----
    add.u32 %r40, %r18, %r17;
    cp.async.cg.shared.global [%r40], [%rd14], 16;
    add.u32 %r41, %r20, %r17;
    cp.async.cg.shared.global [%r41], [%rd15], 16;
    cp.async.commit_group;

    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

$kloop:
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $tile_epilogue;

    setp.gt.s32 %pmore, %r0, 1;
    @!%pmore bra $no_prefetch;

    xor.b32 %r31, %r30, 1;
    shl.b32 %r32, %r31, 11;

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

    shl.b32 %r34, %r30, 11;
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

$tile_epilogue:
    shr.u32 %r70, %r50, 2;
    and.b32 %r71, %r50, 3;
    mul.lo.u32 %r72, %r70, {S*4};
    shl.b32 %r73, %r71, 3;
    add.u32 %r74, %r72, %r73;
    cvt.u64.u32 %rd20, %r74;
    add.u64 %rd20, %rd12, %rd20;

    add.u64 %rd21, %rd20, {8*S*4};
    add.u64 %rd22, %rd20, {16*S*4};
    add.u64 %rd23, %rd20, {24*S*4};

    // ---- Split-K reduction: atom.global.add.f32 for all 32 acc regs ----
    atom.global.add.f32 %ftmp, [%rd20 +     0], %fc0;
    atom.global.add.f32 %ftmp, [%rd20 +     4], %fc1;
    atom.global.add.f32 %ftmp, [%rd21 +     0], %fc2;
    atom.global.add.f32 %ftmp, [%rd21 +     4], %fc3;
    atom.global.add.f32 %ftmp, [%rd20 +    32], %fc4;
    atom.global.add.f32 %ftmp, [%rd20 +    36], %fc5;
    atom.global.add.f32 %ftmp, [%rd21 +    32], %fc6;
    atom.global.add.f32 %ftmp, [%rd21 +    36], %fc7;
    atom.global.add.f32 %ftmp, [%rd20 +    64], %fc8;
    atom.global.add.f32 %ftmp, [%rd20 +    68], %fc9;
    atom.global.add.f32 %ftmp, [%rd21 +    64], %fc10;
    atom.global.add.f32 %ftmp, [%rd21 +    68], %fc11;
    atom.global.add.f32 %ftmp, [%rd20 +    96], %fc12;
    atom.global.add.f32 %ftmp, [%rd20 +   100], %fc13;
    atom.global.add.f32 %ftmp, [%rd21 +    96], %fc14;
    atom.global.add.f32 %ftmp, [%rd21 +   100], %fc15;

    atom.global.add.f32 %ftmp, [%rd22 +     0], %fc16;
    atom.global.add.f32 %ftmp, [%rd22 +     4], %fc17;
    atom.global.add.f32 %ftmp, [%rd23 +     0], %fc18;
    atom.global.add.f32 %ftmp, [%rd23 +     4], %fc19;
    atom.global.add.f32 %ftmp, [%rd22 +    32], %fc20;
    atom.global.add.f32 %ftmp, [%rd22 +    36], %fc21;
    atom.global.add.f32 %ftmp, [%rd23 +    32], %fc22;
    atom.global.add.f32 %ftmp, [%rd23 +    36], %fc23;
    atom.global.add.f32 %ftmp, [%rd22 +    64], %fc24;
    atom.global.add.f32 %ftmp, [%rd22 +    68], %fc25;
    atom.global.add.f32 %ftmp, [%rd23 +    64], %fc26;
    atom.global.add.f32 %ftmp, [%rd23 +    68], %fc27;
    atom.global.add.f32 %ftmp, [%rd22 +    96], %fc28;
    atom.global.add.f32 %ftmp, [%rd22 +   100], %fc29;
    atom.global.add.f32 %ftmp, [%rd23 +    96], %fc30;
    atom.global.add.f32 %ftmp, [%rd23 +   100], %fc31;

$tile_advance:
    add.u32 %r120, %r120, 1;
    bra $tileloop;

$tile_exit:
    ret;
}}
"""


SHAPES = [4096, 6144, 8192]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        p_path = outdir / f"sgemm_ppsh_{S}x{S}_grid.ptx"
        p_path.write_text(gen(S))
        print(f"wrote {p_path.name} ({len(p_path.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes (bijection verified per shape, G={NUM_K_SPLITS}, P={NUM_PERSISTENT})")
