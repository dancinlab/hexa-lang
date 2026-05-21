#!/usr/bin/env python3
"""RFC 067 PR -- STACK N77 (ldmatrix.x4 + cp.async.cg vec16) + K-loop UNROLL factor 2.

Parent: N77 (PP) at rfc067_pP_hexa_sgemm_ldmatrix_cpasync_2026_05_21
  peak 36.06 TFLOPS @ M=1536, ratio 0.533 vs cuBLAS HGEMM 67.65.

N79 (PQ) honest scope quote: SW-pipeline was refuted (ptxas auto-reorders),
K-loop unroll identified as remaining unfalsified candidate.
N48 (Apple M3) measured K-unroll 2x = +2.4% over baseline.

PR change vs N77:
  - K-block doubled from 16 K-elements per K-step to 32 K-elements.
  - Per K-step now: cp.async wait + bar.sync + 2x ldmatrix(A_k0, B_k0) + 2x ldmatrix(A_k1, B_k1) + 4x mma.sync
  - Halves bar.sync count, halves cp.async commit_group count.
  - 4 mma per K-step (same total mma count overall: K/32 * 4 = K/16 * 2).

What changes vs N77:
  Shared slab:
    N77: 64 rows * 16 K-elem fp16 * 2B = 2048B per slab; 2 slabs = 4096B per array.
    PR:  64 rows * 32 K-elem fp16 * 2B = 4096B per slab; 2 slabs = 8192B per array.
    Total smem: 2 * 8192 = 16384B (was 8192B in N77, well within sm_90/sm_120 budget).

  Cooperative load (per K-step):
    N77: 128 vec16 loads / slab for A (rows*col_q), 128 for B. Threads in [0,128) load A, [128,256) load B.
    PR:  256 vec16 loads / slab for A (rows*col_quad), 256 for B. Threads in [0,256) load A, [256,512) load B.
         All 512 threads now do cooperative load (vs 256 active in N77).
         vec_idx = tid & 255  (0..255)
         row     = vec_idx >> 2  in [0, 64)
         col_q   = vec_idx & 3   in {0,1,2,3}  (4 chunks of 16B in a 64B row of 32 fp16)
         intra-slab byte offset = row*64 + col_q*16

  Consumer (each K-step):
    Two sequential ldmatrix sets reading first 16 K-elements then next 16 K-elements:
      ldmatrix A[k0:k0+16] -> ra0..ra3
      ldmatrix B[k0:k0+16] -> rb0..rb3
      mma m16n8k16 (ra, rb_low) -> fc[0..3]
      mma m16n8k16 (ra, rb_high) -> fc[4..7]
      ldmatrix A[k0+16:k0+32] -> ra0..ra3   (reuse same register set, dependency chain)
      ldmatrix B[k0+16:k0+32] -> rb0..rb3
      mma m16n8k16 (ra, rb_low) -> fc[0..3]
      mma m16n8k16 (ra, rb_high) -> fc[4..7]

  K-loop count:
    N77: K_TILES_TOTAL = K / 16   (e.g. K=1536 -> 96 iters)
    PR:  K_TILES_TOTAL = K / 32   (e.g. K=1536 -> 48 iters)

  Address advance per K-step (global): += 64 B (was 32 B).

Honest-scope:
  - Register pressure: same 8 fc f32 + 4 ra + 4 rb (registers reused per half-step).
    Expected ptxas register count similar to N77 (~38-42 reg/thread).
  - If unroll 2x exceeds budget (occupancy collapse), result will show flat or regression.
  - If improvement < 5%, mma is already throughput-saturated (useful negative).
  - PTX pure-ASCII.
"""

import sys
from pathlib import Path


def gen(S: int) -> str:
    assert S % 64 == 0, f"S={S} must be divisible by 64"
    a_byte = 64 * S * 2            # ctaid stride: 64 rows * S cols * 2 B  (fp16)
    c_byte = 64 * S * 4            # C is f32
    cm_byte = 16 * S * 4           # 16 C rows
    ab_row_b = S * 2               # one A row / B col stride (fp16)

    # K-unroll factor 2: each K-step processes 32 K-elements.
    # Shared slab byte size per slab: 64 rows * 32 K-elem * 2B = 4096 B
    # Two slabs = 8192 B per shared array.

    return f"""// RFC 067 PR perf HGEMM hexa-emit -- STACK ldmatrix.x4 + cp.async.cg vec16 + K-UNROLL 2x -- M=N=K={S}.
//
// Parent N77 (PP): 36.06 TFLOPS @ M=1536 ratio 0.533 vs cuBLAS HGEMM 67.65.
// PR change: K-block 16 -> 32 (unroll 2x), 2x ldmatrix + 4x mma per K-step, halved bar.sync.
//
// Layout (unchanged consumer):
//   A row-major     [M={S} x K={S}] f16. Row stride = {S} elem = {ab_row_b} B.
//   B col-major     [K={S} x N={S}] f16. Col stride = {S} elem = {ab_row_b} B.
//   C row-major out [M={S} x N={S}] f32. Row stride = {S} elem = {S*4} B.

.version 8.0
.target sm_90
.address_size 64

.shared .align 16 .b8 _tg_a[8192];
.shared .align 16 .b8 _tg_b[8192];

.visible .entry sgemm_kunroll_{S}x{S}_grid (
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
    .reg .pred %pload_a;
    .reg .pred %pload_b;
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

    // Vectorised cooperative-load predicates / indexing for K-UNROLL 2x.
    //   K-step block = 32 K-elem = 64 B per row. 256 vec16 / slab (A or B).
    //   load_a active for tid in [0, 256)    -> 256 vec16 loads for A
    //   load_b active for tid in [256, 512)  -> 256 vec16 loads for B
    //   vec_idx = tid & 255  (0..255)
    //   row     = vec_idx >> 2     in [0, 64)
    //   col_q   = vec_idx & 3      in {{0,1,2,3}}
    setp.lt.u32 %pload_a, %r1, 256;
    // %pload_b is active for tid in [256, 512). All 512 threads participate.

    and.b32 %r12, %r1, 255;     // vec_idx
    shr.u32 %r13, %r12, 2;      // row in [0, 64)
    and.b32 %r14, %r12, 3;      // col_q in {{0,1,2,3}}
    shl.b32 %r15, %r14, 4;      // col_q * 16  (byte offset within 64-B row of 32 fp16)

    // A_cta base = a + ctaid.y * {a_byte}
    mul.lo.u32 %r5, %r10, {a_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd0, %rd4;

    // B_cta base = b + ctaid.x * {a_byte}
    mul.lo.u32 %r5, %r11, {a_byte};
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

    // Per-thread intra-slab shared-mem store offset (UNROLL 2x):
    //   row*64 + col_q*16   in {{0..4080}} step 16
    shl.b32 %r17, %r13, 6;              // row * 64
    add.u32 %r17, %r17, %r15;           // + col_q*16

    mov.u32 %r18, _tg_a;
    mov.u32 %r20, _tg_b;

    // Per-warp shared-mem READ base offsets:
    //   m_tile * 16 rows * 64 B/row = m_tile * 1024
    mul.lo.u32 %r22, %r3, 1024;
    mul.lo.u32 %r24, %r4, 1024;

    // ldmatrix per-lane intra-subtile address.
    // Each ldmatrix.x4 reads 16x16 fp16 (32B per row, 16 rows).
    // In the K-UNROLL 2x slab, the row stride is 64B (32 fp16/row).
    // First ldmatrix reads K-elem [0:16], second reads K-elem [16:32] (offset +32 B).
    //   g = lane >> 3;   r = lane & 7
    //   row_idx = (g >> 1) * 8 + r   in [0..15]
    //   col_off = (g & 1) * 16
    //   ld_off  = row_idx * 64 + col_off       (row stride 64 B in K-unroll layout)
    shr.u32 %r51, %r50, 3;
    and.b32 %r52, %r50, 7;
    shr.u32 %r53, %r51, 1;
    shl.b32 %r54, %r53, 3;
    add.u32 %r55, %r54, %r52;
    and.b32 %r56, %r51, 1;
    shl.b32 %r57, %r56, 4;
    shl.b32 %r58, %r55, 6;              // row_idx * 64
    add.u32 %r59, %r58, %r57;           // + col_off

    // C base address.
    mul.lo.u32 %r5, %r10, {c_byte};
    mul.lo.u32 %r6, %r3, {cm_byte};
    add.u32 %r7, %r5, %r6;
    mul.lo.u32 %r8, %r11, 256;
    add.u32 %r7, %r7, %r8;
    mul.lo.u32 %r8, %r4, 64;
    add.u32 %r7, %r7, %r8;
    cvt.u64.u32 %rd6, %r7;
    add.u64 %rd12, %rd2, %rd6;

    // Init accumulator (8 f32 = 2 m16n8k16 calls per ldmatrix-set, accumulated across K-steps)
    mov.f32 %fc0, 0f00000000;
    mov.f32 %fc1, 0f00000000;
    mov.f32 %fc2, 0f00000000;
    mov.f32 %fc3, 0f00000000;
    mov.f32 %fc4, 0f00000000;
    mov.f32 %fc5, 0f00000000;
    mov.f32 %fc6, 0f00000000;
    mov.f32 %fc7, 0f00000000;

    cvt.s32.s64 %r0, %rd3;

    mov.u32 %r30, 0;                     // current slot

    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    // ---- PROLOGUE: issue K=0 prefetch into slot 0 ----
    // A dst = _tg_a + 0 + %r17  (predicated on pload_a, tid in [0,256))
    add.u32 %r40, %r18, %r17;
    @%pload_a cp.async.cg.shared.global [%r40], [%rd14], 16;

    // B dst = _tg_b + 0 + %r17 ; tid in [256, 512) only -- inverse of pload_a.
    add.u32 %r41, %r20, %r17;
    @%pload_a bra $skip_b_prologue;
    cp.async.cg.shared.global [%r41], [%rd15], 16;
$skip_b_prologue:
    cp.async.commit_group;

    add.u64 %rd14, %rd14, 64;            // K-UNROLL 2x: advance by K_TILE_BYTES = 32*2 = 64 B
    add.u64 %rd15, %rd15, 64;

$kloop:
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    setp.gt.s32 %pmore, %r0, 1;
    @!%pmore bra $no_prefetch;

    xor.b32 %r31, %r30, 1;
    shl.b32 %r32, %r31, 12;              // next_slot * 4096  (slab byte size for unroll 2x)

    add.u32 %r40, %r18, %r32;
    add.u32 %r40, %r40, %r17;
    @%pload_a cp.async.cg.shared.global [%r40], [%rd14], 16;

    add.u32 %r41, %r20, %r32;
    add.u32 %r41, %r41, %r17;
    @%pload_a bra $skip_b_kick;
    cp.async.cg.shared.global [%r41], [%rd15], 16;
$skip_b_kick:

    cp.async.commit_group;
    cp.async.wait_group 1;
    bra $consume;

$no_prefetch:
    cp.async.wait_all;

$consume:
    bar.sync 0;

    // Slab base + per-warp 16x16 subtile offset.
    // slot_byte = slot * 4096   (4096 B = 64 rows * 64 B/row, slab for unroll 2x)
    shl.b32 %r34, %r30, 12;
    add.u32 %r35, %r18, %r34;
    add.u32 %r35, %r35, %r22;
    add.u32 %r36, %r20, %r34;
    add.u32 %r36, %r36, %r24;

    // ---- K-UNROLL HALF 0: K-elem [0..16] within this K-step ----
    add.u32 %r60, %r35, %r59;
    add.u32 %r61, %r36, %r59;

    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra0, %ra1, %ra2, %ra3}}, [%r60];

    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rb0, %rb1, %rb2, %rb3}}, [%r61];

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

    // ---- K-UNROLL HALF 1: K-elem [16..32] within this K-step ----
    // ldmatrix reads from same slab base but offset +32 B in K direction.
    add.u32 %r62, %r60, 32;
    add.u32 %r63, %r61, 32;

    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra0, %ra1, %ra2, %ra3}}, [%r62];

    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rb0, %rb1, %rb2, %rb3}}, [%r63];

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

    add.u64 %rd14, %rd14, 64;            // K-UNROLL 2x: advance by 64 B
    add.u64 %rd15, %rd15, 64;

    xor.b32 %r30, %r30, 1;
    sub.s32 %r0, %r0, 1;
    bra $kloop;

$epilogue:
    // mma.m16n8k16 D-frag store (unchanged from N77).
    shr.u32 %r62, %r50, 2;
    and.b32 %r63, %r50, 3;
    mul.lo.u32 %r64, %r62, {S*4};
    shl.b32 %r65, %r63, 3;
    add.u32 %r66, %r64, %r65;
    cvt.u64.u32 %rd20, %r66;
    add.u64 %rd20, %rd12, %rd20;

    add.u64 %rd21, %rd20, {8*S*4};

    st.global.f32 [%rd20 +     0], %fc0;
    st.global.f32 [%rd20 +     4], %fc1;
    st.global.f32 [%rd21 +     0], %fc2;
    st.global.f32 [%rd21 +     4], %fc3;

    st.global.f32 [%rd20 +    32], %fc4;
    st.global.f32 [%rd20 +    36], %fc5;
    st.global.f32 [%rd21 +    32], %fc6;
    st.global.f32 [%rd21 +    36], %fc7;

    ret;
}}
"""


# Same 6 shapes as N77 for direct comparison.
SHAPES = [256, 384, 512, 768, 1024, 1536]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        p = outdir / f"sgemm_kunroll_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes")
