#!/usr/bin/env python3
"""RFC 067 PO -- hand-emit hexa HGEMM PTX with ldmatrix.x4 + mma.m16n8k16.

PK (N66, TF32 + 2-stage cp.async multistage) peaked at 13.35 TFLOPS @ M=1536
ratio 0.406 on RTX 5070 sm_120. N71 instrumented analysis identified
"ldmatrix for shared->register transfer" as one of 3 unfalsified
memory-subsystem candidates with +15-30% predicted upside.

PATH CHOSEN: B (FP16 HGEMM with mma.sync.m16n8k16)
  - ldmatrix is natively b16; FP16 path lets us use it directly.
  - To pair with ldmatrix.x4 (4 b32/thread), we use the modern
    mma.sync.m16n8k16.f32.f16.f16.f32 (A: 4 b32, B: 2 b32, D: 4 f32)
    rather than wmma.m16n16k16 (which needs 8 b32 A frag).
  - Per warp's 16x16 output tile = 2 mma.m16n8k16 calls (n=0..7, n=8..15).
  - Comparator: cuBLAS HGEMM (CUBLAS_TENSOR_OP_MATH, fp16 inputs).

Geometry:
  - 16 warps in 4x4 layout -> 64x64 output tile per CTA
  - Each warp owns one 16x16 sub-tile via 2x mma.m16n8k16
  - K-loop: S/16 iterations (mma K = 16)
  - 512 threads per block

Shared-mem (DOUBLE-BUFFERED):
  _tg_a[4096] = 2 slabs * (64 rows x 16 K-elem) * 2 B = 2 * 2048 B
  _tg_b[4096] = 2 slabs * (64 cols x 16 K-elem) * 2 B = 2 * 2048 B
  Total shared = 8192 B

Cooperative load (per K-step k, slot = k & 1):
  thread t = tid.x in [0, 512):
    row    = t >> 3   in [0, 64)
    col2   = t & 7    in [0, 8)
    A_g = A_cta + row * S * 2 + (k*16 + col2*2) * 2 bytes
    cp.async.ca.shared.global [_tg_a + slot*2048 + row*32 + col2*4], [A_g], 4

Shared-mem in-slab layout per slab (2048 B):
  A: row-major  -- A_sub[row][k] at byte (row * 32 + k * 2) for k in [0..15]
  B: col-major  -- B_sub[col][k] at byte (col * 32 + k * 2) for k in [0..15]
  (Both stride 32 B between row/col, so cooperative load uses identical
   per-thread address arithmetic.)

ldmatrix dispatch per warp (after barrier):
  A 16x16 (m=16, k=16, row layout) -- ONE ldmatrix.x4.b16
    Each lane L (0..31) provides addr = subtile_A_base + ld_off(L) where
       g = L>>3 (0..3), r = L&7 (0..7)
       row_idx = (g>>1)*8 + r    in [0..15]
       col_off = (g&1) * 16       (0 or 16 bytes into the row's 32 B)
       ld_off = row_idx*32 + col_off
    Output: 4 b32/lane = 8 fp16/lane covering 16x16 A in mma-frag layout.
    Reg use: {ra0, ra1, ra2, ra3}.

  B 16x16 (k=16, n=16, col layout in shared with stride 32 B/col)
    Need 2x B fragment for mma.m16n8k16 (each B-frag = k16 x n8 = 2 b32/lane).
    Approach: ONE ldmatrix.x4.trans loading the FULL 16x16 B sub-tile
      transposed -> 4 b32/lane = 8 fp16/lane.
    The four matrices are (k_rows 0..7, n_cols 0..7),
                          (k_rows 0..7, n_cols 8..15),
                          (k_rows 8..15, n_cols 0..7),
                          (k_rows 8..15, n_cols 8..15).
    For mma B-frag (m16n8k16 col), the four 8x8 blocks pack into two
    column-halves of n=8 each, k=0..15. So:
       B-frag n=0..7  -> b32 regs {ra(mat0), ra(mat2)} = halves of cols 0..7
       B-frag n=8..15 -> b32 regs {ra(mat1), ra(mat3)} = halves of cols 8..15
    Reg use: {rb0,rb1,rb2,rb3}; split as ({rb0,rb2}, {rb1,rb3}).

mma per warp:
  mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
    {fc0,fc1,fc2,fc3}, {ra0,ra1,ra2,ra3}, {rb0,rb2}, {fc0,fc1,fc2,fc3};
  mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
    {fc4,fc5,fc6,fc7}, {ra0,ra1,ra2,ra3}, {rb1,rb3}, {fc4,fc5,fc6,fc7};

Output store: each warp has 8 f32 accumulator regs (4 per n-half).
  mma.m16n8k16 D layout (per PTX 8.0 9.7.13.5.6):
    each lane holds 4 f32 forming a 2x2 pattern in the 16x8 sub-tile.
    lane_id = L; groupID = L >> 2 (0..7); threadID_in_group = L & 3 (0..3)
    elements (r, c): r0 = groupID, r1 = groupID + 8
                     c0 = 2*threadID_in_group, c1 = c0 + 1
    Output regs: d0 -> (r0,c0), d1 -> (r0,c1), d2 -> (r1,c0), d3 -> (r1,c1)
  We emit 8 explicit st.global.f32 per warp (4 per n-half x 2 halves).

Honest-scope guards:
  - ldmatrix sm_75+, mma.m16n8k16.f32.f16 sm_80+. Driver JIT against sm_80 PTX
    accepts on RTX 5070 (sm_120 via forward-compat).
  - Numeric: cuBLAS HGEMM uses different tile + accumulation order; we
    tolerance check maxabs <= K*scale*1e-2 (per N38 PG f16-mul-f32-acc).
"""

import sys
from pathlib import Path


def gen(S: int) -> str:
    assert S % 64 == 0, f"S={S} must be divisible by 64"
    a_byte = 64 * S * 2            # ctaid stride: 64 rows * S cols * 2 B
    am_byte = 16 * S * 2           # m_tile stride
    c_byte = 64 * S * 4            # C is f32
    cm_byte = 16 * S * 4           # 16 C rows
    ab_row_b = S * 2               # one A row / B col stride (fp16)

    return f"""// RFC 067 PO perf HGEMM hexa-emit + cp.async pipeline + ldmatrix.x4 + mma.m16n8k16 -- M=N=K={S}.
//
// Path B (FP16): switched from PK's TF32+wmma.load.shared to FP16+ldmatrix.x4
// for shared->frag transfer, paired with the modern mma.sync.m16n8k16 (which
// has matching 4-b32-A / 2-b32-B fragment shape -- ideal ldmatrix companion).
//
// Layout:
//   A row-major     [M={S} x K={S}] f16. Row stride = {S} elem = {ab_row_b} B.
//   B col-major     [K={S} x N={S}] f16. Col stride = {S} elem = {ab_row_b} B.
//   C row-major out [M={S} x N={S}] f32. Row stride = {S} elem = {S*4} B.

.version 8.0
.target sm_90
.address_size 64

.shared .align 16 .b8 _tg_a[4096];
.shared .align 16 .b8 _tg_b[4096];

.visible .entry sgemm_ldmatrix_{S}x{S}_grid (
    .param .u64 a,
    .param .u64 b,
    .param .u64 c,
    .param .u64 k_tiles
)
{{
    .reg .u64 %rd<32>;
    .reg .u32 %r<80>;
    .reg .pred %p1;
    .reg .pred %pmore;
    .reg .b32 %ra<4>;
    .reg .b32 %rb<4>;
    .reg .f32 %fc<8>;

    ld.param.u64 %rd0, [a];
    ld.param.u64 %rd1, [b];
    ld.param.u64 %rd2, [c];
    ld.param.u64 %rd3, [k_tiles];

    mov.u32 %r10, %ctaid.y;
    mov.u32 %r11, %ctaid.x;

    mov.u32 %r1, %tid.x;
    shr.u32 %r2, %r1, 5;        // warp id
    shr.u32 %r3, %r2, 2;        // m_tile = warp >> 2
    and.b32 %r4, %r2, 3;        // n_tile = warp & 3
    and.b32 %r50, %r1, 31;      // lane id

    shr.u32 %r12, %r1, 3;       // row_load
    and.b32 %r13, %r1, 7;       // col2

    // A_cta base = a + ctaid.y * {a_byte}
    mul.lo.u32 %r5, %r10, {a_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd0, %rd4;

    // B_cta base = b + ctaid.x * {a_byte}
    mul.lo.u32 %r5, %r11, {a_byte};
    cvt.u64.u32 %rd5, %r5;
    add.u64 %rd11, %rd1, %rd5;

    // A load-offset = row * {ab_row_b} + col2 * 4
    mul.lo.u32 %r14, %r12, {ab_row_b};
    mul.lo.u32 %r15, %r13, 4;
    add.u32 %r14, %r14, %r15;
    cvt.u64.u32 %rd14, %r14;
    add.u64 %rd14, %rd10, %rd14;

    cvt.u64.u32 %rd15, %r14;
    add.u64 %rd15, %rd11, %rd15;

    // Intra-slab smem store offset = row * 32 + col2 * 4
    shl.b32 %r16, %r12, 5;
    mul.lo.u32 %r17, %r13, 4;
    add.u32 %r16, %r16, %r17;

    mov.u32 %r18, _tg_a;
    mov.u32 %r20, _tg_b;

    // Per-warp shared-mem READ base offsets: m_tile * 512 / n_tile * 512
    mul.lo.u32 %r22, %r3, 512;
    mul.lo.u32 %r24, %r4, 512;

    // ldmatrix per-lane intra-subtile address:
    //   g = lane >> 3; r = lane & 7
    //   row_idx = (g >> 1) * 8 + r   in [0..15]
    //   col_off = (g & 1) * 16       (0 or 16)
    //   ld_off  = row_idx * 32 + col_off
    shr.u32 %r51, %r50, 3;
    and.b32 %r52, %r50, 7;
    shr.u32 %r53, %r51, 1;
    shl.b32 %r54, %r53, 3;
    add.u32 %r55, %r54, %r52;
    and.b32 %r56, %r51, 1;
    shl.b32 %r57, %r56, 4;
    shl.b32 %r58, %r55, 5;
    add.u32 %r59, %r58, %r57;

    // C base address calculation for this warp's 16x16 output tile.
    //   C_warp = c + ctaid.y * {c_byte} + m_tile * {cm_byte} + ctaid.x * 256 + n_tile * 64
    mul.lo.u32 %r5, %r10, {c_byte};
    mul.lo.u32 %r6, %r3, {cm_byte};
    add.u32 %r7, %r5, %r6;
    mul.lo.u32 %r8, %r11, 256;
    add.u32 %r7, %r7, %r8;
    mul.lo.u32 %r8, %r4, 64;
    add.u32 %r7, %r7, %r8;
    cvt.u64.u32 %rd6, %r7;
    add.u64 %rd12, %rd2, %rd6;     // %rd12 = C_warp_base (top-left of warp's 16x16)

    // Init accumulator (8 f32 = 2 m16n8 calls' worth)
    mov.f32 %fc0, 0f00000000;
    mov.f32 %fc1, 0f00000000;
    mov.f32 %fc2, 0f00000000;
    mov.f32 %fc3, 0f00000000;
    mov.f32 %fc4, 0f00000000;
    mov.f32 %fc5, 0f00000000;
    mov.f32 %fc6, 0f00000000;
    mov.f32 %fc7, 0f00000000;

    cvt.s32.s64 %r0, %rd3;

    // Pipeline state:
    mov.u32 %r30, 0;             // current slot

    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    // ---- PROLOGUE: issue K=0 prefetch into slot 0 ----
    add.u32 %r40, %r18, %r16;
    cp.async.ca.shared.global [%r40], [%rd14], 4;
    add.u32 %r41, %r20, %r16;
    cp.async.ca.shared.global [%r41], [%rd15], 4;
    cp.async.commit_group;

    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

$kloop:
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    setp.gt.s32 %pmore, %r0, 1;
    @!%pmore bra $no_prefetch;

    xor.b32 %r31, %r30, 1;
    shl.b32 %r32, %r31, 11;

    add.u32 %r40, %r18, %r32;
    add.u32 %r40, %r40, %r16;
    cp.async.ca.shared.global [%r40], [%rd14], 4;

    add.u32 %r41, %r20, %r32;
    add.u32 %r41, %r41, %r16;
    cp.async.ca.shared.global [%r41], [%rd15], 4;

    cp.async.commit_group;
    cp.async.wait_group 1;
    bra $consume;

$no_prefetch:
    cp.async.wait_all;

$consume:
    bar.sync 0;

    // Slab base + per-warp 16x16 subtile offset.
    shl.b32 %r34, %r30, 11;
    add.u32 %r35, %r18, %r34;
    add.u32 %r35, %r35, %r22;
    add.u32 %r36, %r20, %r34;
    add.u32 %r36, %r36, %r24;

    add.u32 %r60, %r35, %r59;
    add.u32 %r61, %r36, %r59;

    // ldmatrix.x4 A row-layout (4 b32/lane = 16x16 A frag).
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra0, %ra1, %ra2, %ra3}}, [%r60];

    // ldmatrix.x4.trans B (col-layout in shared, transposed for col B-frag).
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rb0, %rb1, %rb2, %rb3}}, [%r61];

    // 2x mma.m16n8k16 covering 16x16 warp output.
    // n=0..7 half:  uses A frag full + B frag halves rb0,rb2
    // n=8..15 half: uses A frag full + B frag halves rb1,rb3
    mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
        {{%fc0, %fc1, %fc2, %fc3}},
        {{%ra0, %ra1, %ra2, %ra3}},
        {{%rb0, %rb2}},
        {{%fc0, %fc1, %fc2, %fc3}};

    mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
        {{%fc4, %fc5, %fc6, %fc7}},
        {{%ra0, %ra1, %ra2, %ra3}},
        {{%rb1, %rb3}},
        {{%fc4, %fc5, %fc6, %fc7}};

    bar.sync 0;

    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

    xor.b32 %r30, %r30, 1;
    sub.s32 %r0, %r0, 1;
    bra $kloop;

$epilogue:
    // mma.m16n8k16 D layout (per lane L):
    //   group = L >> 2 (0..7); tig = L & 3 (0..3)
    //   d0 -> (row=group,     col=2*tig + 0)
    //   d1 -> (row=group,     col=2*tig + 1)
    //   d2 -> (row=group + 8, col=2*tig + 0)
    //   d3 -> (row=group + 8, col=2*tig + 1)
    // Output stride per row = {S*4} bytes (full N stride).
    //
    // Compute lane-specific store base.
    shr.u32 %r62, %r50, 2;       // group = lane >> 2
    and.b32 %r63, %r50, 3;       // tig   = lane & 3
    // row_a = group;  row_b = group + 8;  col_pair = 2*tig
    mul.lo.u32 %r64, %r62, {S*4};   // row_a stride in C
    shl.b32 %r65, %r63, 3;          // 2*tig * 4 B = 8*tig
    add.u32 %r66, %r64, %r65;       // row_a base byte offset
    cvt.u64.u32 %rd20, %r66;
    add.u64 %rd20, %rd12, %rd20;    // lane store addr (row=group, col=2*tig)

    // For row_b = group + 8 add 8 * {S*4} bytes
    add.u64 %rd21, %rd20, {8*S*4};

    // First mma's D (fc0..fc3): n=0..7 half. cols in [0..7] -> 2*tig in [0..7]. OK.
    st.global.f32 [%rd20 +     0], %fc0;
    st.global.f32 [%rd20 +     4], %fc1;
    st.global.f32 [%rd21 +     0], %fc2;
    st.global.f32 [%rd21 +     4], %fc3;

    // Second mma's D (fc4..fc7): n=8..15 half. cols in [8..15] -> +32 B offset.
    st.global.f32 [%rd20 +    32], %fc4;
    st.global.f32 [%rd20 +    36], %fc5;
    st.global.f32 [%rd21 +    32], %fc6;
    st.global.f32 [%rd21 +    36], %fc7;

    ret;
}}
"""


# Same 6 shapes as PK for direct comparison.
SHAPES = [256, 384, 512, 768, 1024, 1536]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        p = outdir / f"sgemm_ldmatrix_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes")
