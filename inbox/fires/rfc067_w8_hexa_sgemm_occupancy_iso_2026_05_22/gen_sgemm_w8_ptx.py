#!/usr/bin/env python3
"""RFC 067 PY-w8 -- 8-WARP 64x64 occupancy-isolation variant.

Goal: isolate occupancy contribution from CTA-count contribution in N107's win.

N107 (PY) = 4 warps, 64x64 tile, 8 mma/K-step -- 51.65 TFLOPS ratio 0.777 @ M=1536
N89  (PS) = 32 warps, 128x128 tile, 4 mma/K-step -- 37.07 TFLOPS ratio 0.557
PY-w8     = 8 warps, 64x64 tile, 4 mma/K-step    -- isolation cell

Axes (N107 vs N89):
  (1) tile size:   64x64  vs 128x128 -> 4x CTA count
  (2) warps/CTA:    4    vs  32     -> 8x occupancy lift (CTA count budget per SM)
  (3) work/warp:    8    vs   4     -> 2x mma issue density (compound w/ tile)

PY-w8 isolates axis (2) at fixed tile = 64x64 (axis 1 = N107) and at fixed
warp-level mma-density = 4 mma/K-step (axis 3 = N89 value).
  => warps:   4 -> 8   (move 1/8 of the way toward N89's 32)
  => CTAs:   same 576 @ M=1536 (axis 1 held constant w/ N107)
  => work/warp: 8 -> 4 mma (matches N89 value)

The trio is a 3-DOF mesh; PY-w8 sits on the (tile=N107) face exactly at axis
(2)+axis (3) midpoint between N107 and N89:
  | variant | tile     | warps | mma/warp | CTA grid | shmem | thd/CTA |
  |---------|----------|-------|----------|----------|-------|---------|
  | N89  PS | 128x128  |  32   |    4     |  144     | 32KB  |  1024   |
  | N107 PY |  64x 64  |   4   |    8     |  576     |  8KB  |   128   |
  | PY-w8   |  64x 64  |   8   |    4     |  576     |  8KB  |   256   |

What the comparison tells us:
  - PY-w8 ratio approx N107 -> warp count (axis 2) didn't matter; tile shrink
    + CTA explosion (axis 1) was the real lever.
  - PY-w8 ratio << N107 -> halving per-warp mma density costs; axis (3) helps.
  - PY-w8 ratio > N107 -> 8 warps/CTA finds a sweeter occupancy spot than 4.

CTA shape:
  threads_per_block = 256       (8 warps)
  output_tile_M     = 64
  output_tile_N     = 64
  shmem_per_cta     = 8192 B    (A 4096 + B 4096, double-buffered)

Warp layout (4M x 2N grid -> 8 warps cover 4*16M x 2*32N = 64x64):
  warp id  = tid.x >> 5    in [0, 8)
  m_tile   = warp >> 1     in [0, 4)
  n_tile   = warp & 1      in [0, 2)
  each warp owns 16M x 32N output = 1 M sub-tile x 4 N sub-8 columns = 4 mma

Per K-step (K_tile = 16 fp16):
  1 ldmatrix.x4         of A (16M x 16K)            -> 4 b16 frags
  2 ldmatrix.x4.trans   of B (16K x 32N)            -> 4 b16 frags x 2 stacks
  4 mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
        (1 M sub-tile x 4 N sub-8 columns)
  -> 4 * 4 = 16 f32 acc / lane

Cooperative load (vec16 cp.async.cg, 256 thd/CTA, only first 128 used):
  A slab = 64 rows * 16 K-elem fp16 * 2B = 2048 B = 128 vec16
  B slab = same.
  tid in [0, 128): 1 vec16 A + 1 vec16 B per thd.
  tid in [128, 256): idle on load (predicated off).
  (Same pattern as N107, just under-utilising the extra 4 warps on the load.
   This is the honest cost of doubling warps at fixed shmem traffic.)

Swizzle: identity / masked (same as N107 PY).

CTA grid:
  gx = N / 64,  gy = M / 64   (identical to N107)
  M=1536: 24x24 = 576 CTAs
  M=256:  4x4   = 16  CTAs

Honest-scope (g3):
  - Register estimate: 4 mma per warp -> ~16 f32 acc + ~24 scratch ~ 50 regs/thd.
    256 thd/CTA * ~50 regs = ~12800 regs/CTA -> ~5 CTAs/SM by register budget
    (65536 / 12800 = 5.12).  vs N107's 8 CTAs/SM.
  - Thread budget: 256 * 5 = 1280 thd/SM vs sm_120 1536/SM cap (occupancy 83%).
    N107: 128 * 8 = 1024 thd/SM (67%). So PY-w8 actually has *higher* thread
    occupancy than N107 even at lower CTA count.
  - Mma issue density per CTA: 8 warps * 4 mma = 32 mma/K-step (vs N107: 4 * 8 = 32).
    Total CTA mma throughput identical.  Difference = per-warp ILP halved.
  - At small M (M=256, 16 CTAs), 8-warp variant likely takes a hit if CTAs/SM cap
    drops below 5 (16 CTAs / 40 SMs = 0.4 -> almost certainly 1 CTA/SM).
"""

import sys
from pathlib import Path


def gen(S: int) -> str:
    assert S % 64 == 0, f"S={S} must be divisible by 64"

    # CTA tile bytes (M-axis): 64 rows of fp16 of K-stride S
    a_ctay_byte  = 64 * S * 2          # ctaid.y stride: 64 rows * S * 2B
    b_ctax_byte  = 64 * S * 2          # ctaid.x stride: 64 cols * S * 2B
    c_ctay_byte  = 64 * S * 4          # C is f32, 64 rows
    c_warpm_byte = 16 * S * 4          # m_tile * 16 rows of C
    ab_row_b     = S * 2               # one A row / B col stride in B

    return f"""// RFC 067 PY-w8 perf HGEMM hexa-emit -- 8-WARP 64x64 occupancy-isolation -- M=N=K={S}.
//
// Isolation cell:
//   N107 PY: 4 warps,  64x64 tile, 8 mma/warp/K-step  -> 51.65 TFLOPS @ M=1536 ratio 0.777
//   N89  PS: 32 warps, 128x128 tile, 4 mma/warp/K-step -> 37.07 TFLOPS @ M=1536 ratio 0.557
//   PY-w8 :  8 warps, 64x64 tile, 4 mma/warp/K-step  -> THIS FIRE
//
// Layout:
//   A row-major     [M={S} x K={S}] f16. Row stride = {ab_row_b} B.
//   B col-major     [K={S} x N={S}] f16. Col stride = {ab_row_b} B.
//   C row-major out [M={S} x N={S}] f32. Row stride = {S*4} B.
//
// CTA tile bytes: ctaid.y -> 64 M-rows ({a_ctay_byte} B from A base),
//                 ctaid.x -> 64 N-cols ({b_ctax_byte} B from B base).
// Grid: gx = N/64, gy = M/64.

.version 8.0
.target sm_90
.address_size 64

.shared .align 16 .b8 _tg_a[4096];
.shared .align 16 .b8 _tg_b[4096];

.visible .entry sgemm_w8_{S}x{S}_grid (
    .param .u64 a,
    .param .u64 b,
    .param .u64 c,
    .param .u64 k_tiles
)
{{
    .reg .u64 %rd<32>;
    .reg .u32 %r<128>;
    .reg .pred %p1;
    .reg .pred %pmore;
    .reg .pred %pload;
    .reg .b32 %ra<4>;
    .reg .b32 %rbl<4>;
    .reg .b32 %rbh<4>;
    .reg .f32 %fc<16>;

    ld.param.u64 %rd0, [a];
    ld.param.u64 %rd1, [b];
    ld.param.u64 %rd2, [c];
    ld.param.u64 %rd3, [k_tiles];

    mov.u32 %r10, %ctaid.y;
    mov.u32 %r11, %ctaid.x;

    mov.u32 %r1, %tid.x;
    shr.u32 %r2, %r1, 5;        // warp id in [0, 8)
    shr.u32 %r3, %r2, 1;        // m_tile = warp >> 1  in [0, 4)
    and.b32 %r4, %r2, 1;        // n_tile = warp & 1   in [0, 2)
    and.b32 %r50, %r1, 31;      // lane id

    // Cooperative-load indexing: only first 128 threads load (predicated).
    //   vec_idx = tid                in [0, 128)
    //   row     = vec_idx >> 1       in [0, 64)
    //   col_q   = vec_idx & 1        in {{0, 1}}
    setp.lt.u32 %pload, %r1, 128;       // pload = (tid < 128)
    shr.u32 %r13, %r1, 1;       // row in [0, 64)  (only valid if pload)
    and.b32 %r14, %r1, 1;       // col_q in {{0, 1}}
    shl.b32 %r15, %r14, 4;      // col_q * 16  (byte offset within 32-B row)

    // XOR swizzle slot (DISABLED -- ldmatrix.x4 coherence; matches N107 PY).
    mov.u32 %r80, 0;            // row_bit (masked)
    xor.b32 %r81, %r14, %r80;
    shl.b32 %r82, %r81, 4;

    // A_cta base = a + ctaid.y * {a_ctay_byte}
    mul.lo.u32 %r5, %r10, {a_ctay_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd0, %rd4;

    // B_cta base = b + ctaid.x * {b_ctax_byte}
    mul.lo.u32 %r5, %r11, {b_ctax_byte};
    cvt.u64.u32 %rd5, %r5;
    add.u64 %rd11, %rd1, %rd5;

    // Per-thread global-load offset (only valid for tid<128):
    //   row * {ab_row_b} + col_q * 16
    mul.lo.u32 %r16, %r13, {ab_row_b};
    add.u32 %r16, %r16, %r15;
    cvt.u64.u32 %rd14, %r16;
    add.u64 %rd14, %rd10, %rd14;

    cvt.u64.u32 %rd15, %r16;
    add.u64 %rd15, %rd11, %rd15;

    // Per-thread intra-slab shared-mem store offset:
    //   row * 32 + phys_chunk * 16
    shl.b32 %r17, %r13, 5;
    add.u32 %r17, %r17, %r82;

    mov.u32 %r18, _tg_a;
    mov.u32 %r20, _tg_b;

    // Per-warp shared-mem READ base offsets:
    //   A read base: m_tile * 16 rows * 32 B/row = m_tile * 512
    //   B read base: n_tile * 32 cols * 32 B/col = n_tile * 1024
    mul.lo.u32 %r22, %r3, 512;          // A_base = m_tile * 512
    mul.lo.u32 %r24, %r4, 1024;         // B_base = n_tile * 1024

    // ldmatrix per-lane intra-subtile address (16x16 fragment).
    //   g = lane >> 3;   r = lane & 7
    //   row_idx = (g >> 1) * 8 + r   in [0..15]
    //   col_off = (g & 1) * 16
    //   ld_off  = row_idx * 32 + col_off (swizzle masked)
    shr.u32 %r51, %r50, 3;
    and.b32 %r52, %r50, 7;
    shr.u32 %r53, %r51, 1;
    shl.b32 %r54, %r53, 3;
    add.u32 %r55, %r54, %r52;            // row_idx
    and.b32 %r56, %r51, 1;
    shl.b32 %r57, %r56, 4;               // col_off

    mov.u32 %r83, 0;
    shl.b32 %r84, %r83, 4;
    xor.b32 %r85, %r57, %r84;            // phys col_off = col_off
    shl.b32 %r58, %r55, 5;
    add.u32 %r59, %r58, %r85;            // ld_off = row*32 + col_off

    // C base address.
    //   C_warp_base = c + ctaid.y * {c_ctay_byte}     (64 M-rows per ctaid.y)
    //                   + m_tile * {c_warpm_byte}      (16 M-rows per m_tile)
    //                   + ctaid.x * 256               (64 N-cols * 4 B per ctaid.x)
    //                   + n_tile * 128                (32 N-cols * 4 B per n_tile)
    mul.lo.u32 %r5, %r10, {c_ctay_byte};
    mul.lo.u32 %r6, %r3, {c_warpm_byte};
    add.u32 %r7, %r5, %r6;
    mul.lo.u32 %r8, %r11, 256;
    add.u32 %r7, %r7, %r8;
    mul.lo.u32 %r8, %r4, 128;
    add.u32 %r7, %r7, %r8;
    cvt.u64.u32 %rd6, %r7;
    add.u64 %rd12, %rd2, %rd6;

    // Init accumulator -- 16 f32 = 4 mma.m16n8k16 (1 M sub * 4 N sub-8).
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

    // ---- PROLOGUE: issue K=0 prefetch into slot 0 (tid<128 only) ----
    add.u32 %r40, %r18, %r17;            // A dst: _tg_a + 0 + swizzled-offset
    @%pload cp.async.cg.shared.global [%r40], [%rd14], 16;

    add.u32 %r41, %r20, %r17;            // B dst
    @%pload cp.async.cg.shared.global [%r41], [%rd15], 16;

    cp.async.commit_group;

    add.u64 %rd14, %rd14, 32;            // advance by K_TILE_BYTES = 16*2 = 32 B
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
    @%pload cp.async.cg.shared.global [%r40], [%rd14], 16;

    add.u32 %r41, %r20, %r32;
    add.u32 %r41, %r41, %r17;
    @%pload cp.async.cg.shared.global [%r41], [%rd15], 16;

    cp.async.commit_group;
    cp.async.wait_group 1;
    bra $consume;

$no_prefetch:
    cp.async.wait_all;

$consume:
    bar.sync 0;

    // Slab base + per-warp 16M x 32N subtile offset.
    shl.b32 %r34, %r30, 11;              // current_slot * 2048
    add.u32 %r35, %r18, %r34;            // A slab base in shmem
    add.u32 %r35, %r35, %r22;            //   + m_tile * 512  (warp's 16-row band)
    add.u32 %r36, %r20, %r34;            // B slab base in shmem
    add.u32 %r36, %r36, %r24;            //   + n_tile * 1024 (warp's 32-col band)

    // 1 ldmatrix.x4 for A (16M x 16K).
    add.u32 %r60, %r35, %r59;            // ldmatrix.x4 A addr
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra0, %ra1, %ra2, %ra3}}, [%r60];

    // 2 ldmatrix.x4.trans for B (16K x 32N, 2 stacks of 16K x 16N).
    //   stack lo: cols 0..15 of warp's B band  -> rbl0..rbl3
    //   stack hi: cols 16..31 of warp's B band -> rbh0..rbh3
    add.u32 %r61, %r36, %r59;            // ldmatrix.x4.trans B_lo addr
    add.u32 %r63, %r61, 512;             // +16 cols * 32 B/col -> B_hi
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbl0, %rbl1, %rbl2, %rbl3}}, [%r61];
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbh0, %rbh1, %rbh2, %rbh3}}, [%r63];

    // 4 mma.m16n8k16 per K-step.
    //   Per warp's 16M x 32N output: 1 M sub-tile x 4 N sub-8.
    //   M sub 0 (rows  0..15): A frag = {{ra0..ra3}}
    //   N sub 0 (cols  0..7):  B frag = {{rbl0, rbl2}}
    //   N sub 1 (cols  8..15): B frag = {{rbl1, rbl3}}
    //   N sub 2 (cols 16..23): B frag = {{rbh0, rbh2}}
    //   N sub 3 (cols 24..31): B frag = {{rbh1, rbh3}}
    //
    //   Acc layout (16 f32 = 4 mma * 4 f32):
    //     mma( M0, N0 ) -> fc[ 0.. 3]
    //     mma( M0, N1 ) -> fc[ 4.. 7]
    //     mma( M0, N2 ) -> fc[ 8..11]
    //     mma( M0, N3 ) -> fc[12..15]

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
    // mma.m16n8k16 D-frag store.
    //   Per lane, the 4 f32 outputs of one mma.m16n8k16 land at:
    //     group = lane >> 2; col_q = lane & 3
    //     row0 = group;      col_base = col_q * 2
    //     row1 = group + 8;  col_base = col_q * 2
    //
    //   For the 4 mma sub-tiles, the (M-row,N-col) base within warp's 16x32 output:
    //     mma( M0,N0 ): m_off= 0, n_off= 0
    //     mma( M0,N1 ): m_off= 0, n_off= 8
    //     mma( M0,N2 ): m_off= 0, n_off=16
    //     mma( M0,N3 ): m_off= 0, n_off=24
    shr.u32 %r70, %r50, 2;               // group = lane >> 2  in [0,8)
    and.b32 %r71, %r50, 3;               // col_q = lane & 3   in [0,4)
    mul.lo.u32 %r72, %r70, {S*4};        // group * row_stride_bytes
    shl.b32 %r73, %r71, 3;               // col_q * 2 * 4 = col_q * 8
    add.u32 %r74, %r72, %r73;
    cvt.u64.u32 %rd20, %r74;
    add.u64 %rd20, %rd12, %rd20;         // base = C_warp + group*S*4 + col_q*8

    add.u64 %rd21, %rd20, {8*S*4};       // base for row1 (group+8)

    // M0 block (rows 0..15) -- 4 sub-tiles across N
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

    ret;
}}
"""


# 6 shapes -- 64-aligned (256/384/512/768/1024/1536 all divisible by 64).
SHAPES = [256, 384, 512, 768, 1024, 1536]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        assert S % 64 == 0, f"S={S} not 64-aligned"
        p = outdir / f"sgemm_w8_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes")
