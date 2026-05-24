#!/usr/bin/env python3
"""RFC 067 PT -- N77 (ldmatrix.x4 + mma.m16n8k16 + cp.async.cg vec16) UPGRADED
to mma.sync.aligned.m16n8k32.f32.f16.f16.f32.

Hypothesis: doubling K per mma issue (K=32 vs K=16) halves the number of mma
instructions per K-loop while keeping ldmatrix/cp.async fixed-cost per K-byte.
Tensor-core throughput is the same FMA/cycle either way, so the gain comes from
issue-bandwidth and loop-overhead amortisation.

  N77 (PP): 36.06 TFLOPS @ M=1536, ratio 0.533 vs cuBLAS HGEMM 67.65
  PT (this): mma.m16n8k32 -> ~50% fewer mma issues per K-loop.

What changes vs N77:
  K_PER_TILE: 16 -> 32  (each K-step processes 32 elements of K instead of 16)
  Shared:    _tg_a slab = 64 rows * 32 fp16 = 4096 B (was 2048).  Double-buffered = 8192 B.
             _tg_b slab = 64 cols * 32 fp16 = 4096 B (was 2048).  Double-buffered = 8192 B.
  Producer:  cp.async.cg.shared.global vec16 (still 8 fp16/instr) but now 4 vec16
             per row instead of 2.  256 vec16 total per slab per K-step (was 128).
             Thread mapping: tid in [0, 256) load A; tid in [256, 512) load B.
             Each active thread does exactly ONE vec16/K-step (512 threads / 512 vec16).
  Consumer:  2x ldmatrix.x4.shared.b16     -> A 16x32 (2 K-halves)  = 8 b32/lane
             2x ldmatrix.x4.trans.shared.b16 -> B 32x16 (2 K-halves) = 8 b32/lane
             2x mma.sync.aligned.m16n8k32.row.col.f32.f16.f16.f32 (one per N-half)

Shared layout (NEW slab stride = 64 B/row instead of 32 B):
  A row-major _tg_a[slot][row][k] byte = slot*4096 + row*64 + k*2  (rows of 32 fp16)
  B col-major _tg_b[slot][col][k] byte = slot*4096 + col*64 + k*2

Cooperative load mapping (256 active per slab):
  vec_idx in [0, 256), row = vec_idx >> 2 in [0, 64), col_q = vec_idx & 3 in {0,1,2,3}
  intra-slab byte offset = row * 64 + col_q * 16
  global byte offset      = row * (S*2) + k * 64 + col_q * 16     (k = current K-step)

Alignment (S divisible by 64):
  row*(S*2) is multiple of 128 -> 16-aligned (S even is enough).
  k*64 -> 16-aligned.  col_q*16 -> 16-aligned.  Shared slab is .align 16.

ldmatrix pattern per warp (consumer of full 16K x 16N output tile in 2 K-halves):

  A 16x32: 2x ldmatrix.x4.shared.b16
    .x4 group i = 4 8x8 matrices arranged as 16 rows x 16 cols
    Pass 1 (K=0..15):   base = warp_a + lane_off
    Pass 2 (K=16..31):  base = warp_a + lane_off + 32   (advance 16 fp16 K cols)
    Output: ra0..ra3 (K-half 0)  +  ra4..ra7 (K-half 1)

  B 32x16: 2x ldmatrix.x4.trans.shared.b16
    Pass 1 (K=0..15, N=0..15):  base = warp_b + lane_off
    Pass 2 (K=16..31):          base = warp_b + lane_off + 32
    Output: rb0..rb3 (K-half 0) + rb4..rb7 (K-half 1)
    Within each .x4.trans: rb_even = N=0..7 cols, rb_odd = N=8..15 cols.

  2x mma.m16n8k32:
    mma #1 N=0..7 :  A={ra0,ra1,ra2,ra3,ra4,ra5,ra6,ra7}, B={rb0,rb2,rb4,rb6}, D=C={fc0,fc1,fc2,fc3}
    mma #2 N=8..15: A={ra0..ra7}, B={rb1,rb3,rb5,rb7}, D=C={fc4,fc5,fc6,fc7}

ldmatrix lane->address (re-derived for 32-element row stride 64 B):
  lane g = lane>>3, r = lane&7
  row_idx = (g>>1)*8 + r in [0..15]
  col_off = (g&1)*16 (byte offset; 8 fp16 cols within the 16 K-elements of this pass)
  ld_off  = row_idx * 64 + col_off
  Pass 2 advances ld_off by 32 (16 fp16 = 32 B).

Honest-scope guards:
  - mma.m16n8k32 requires sm_80+.  We target sm_90 (RTX 5070 sm_120 supports).
  - Register pressure: ra0..7 + rb0..7 + 8 fp32 acc + addr regs ~104 b32/lane.
    Should fit in 128-reg cap; if ptxas spills, fall back is documented.
  - Bit-exact match expected vs cuBLAS HGEMM (same f16-mul-f32-acc math).
"""

import sys
from pathlib import Path


def gen(S: int) -> str:
    assert S % 64 == 0, f"S={S} must be divisible by 64"
    a_byte = 64 * S * 2            # ctaid stride: 64 rows * S cols * 2 B (fp16)
    am_byte = 16 * S * 2           # m_tile stride (warp m_tile = 16 rows)
    c_byte = 64 * S * 4            # C is f32
    cm_byte = 16 * S * 4
    ab_row_b = S * 2               # one A row / B col stride in bytes (fp16)
    K_TILE_BYTES = 64              # 32 fp16 per K-step = 64 B

    return f"""// RFC 067 PT perf HGEMM hexa-emit -- ldmatrix.x4 + cp.async.cg vec16 + mma.m16n8k32 -- M=N=K={S}.
//
// Upgrade of N77 (PP):
//   N77: 2x mma.m16n8k16 per K-step (K-step = 16, K-loop = K/16)
//   PT : 2x mma.m16n8k32 per K-step (K-step = 32, K-loop = K/32, half the iterations)
//
// Producer/consumer roles otherwise identical to N77 (vec16 cp.async.cg producer,
// ldmatrix.x4 consumer).  PTX text is PURE ASCII for driver-JIT compatibility.
//
// Layout:
//   A row-major     [M={S} x K={S}] f16. Row stride = {S} elem = {ab_row_b} B.
//   B col-major     [K={S} x N={S}] f16. Col stride = {S} elem = {ab_row_b} B.
//   C row-major out [M={S} x N={S}] f32. Row stride = {S} elem = {S*4} B.

.version 8.0
.target sm_90
.address_size 64

.shared .align 16 .b8 _tg_a[8192];
.shared .align 16 .b8 _tg_b[8192];

.visible .entry sgemm_m16n8k32_{S}x{S}_grid (
    .param .u64 a,
    .param .u64 b,
    .param .u64 c,
    .param .u64 k_tiles
)
{{
    .reg .u64 %rd<32>;
    .reg .u32 %r<96>;
    .reg .pred %p1;
    .reg .pred %pmore;
    .reg .pred %pload_a;
    .reg .pred %pload_b;
    .reg .b32 %ra<8>;
    .reg .b32 %rb<8>;
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

    // Vectorised cooperative-load predicates:
    //   load_a active for tid in [0,   256)   (256 vec16 per A-slab per K-step)
    //   load_b active for tid in [256, 512)   (256 vec16 per B-slab per K-step)
    //   vec_idx = tid & 255   in [0, 256)
    //   row     = vec_idx >> 2 in [0, 64)
    //   col_q   = vec_idx & 3  in {{0,1,2,3}}  -> col_q*16 byte offset (4 chunks of 8 fp16)
    setp.lt.u32 %pload_a, %r1, 256;
    setp.lt.u32 %pload_b, %r1, 512;

    and.b32 %r12, %r1, 255;     // vec_idx
    shr.u32 %r13, %r12, 2;      // row in [0, 64)
    and.b32 %r14, %r12, 3;      // col_q in {{0,1,2,3}}
    shl.b32 %r15, %r14, 4;      // col_q * 16

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

    // Per-thread intra-slab shared-mem store offset:
    //   row*64 + col_q*16   in {{0..4080}} step 16
    shl.b32 %r17, %r13, 6;              // row * 64
    add.u32 %r17, %r17, %r15;           // + col_q*16

    mov.u32 %r18, _tg_a;
    mov.u32 %r20, _tg_b;

    // Per-warp shared-mem READ base offsets:
    //   m_tile * 16 rows * 64 B/row = m_tile * 1024
    mul.lo.u32 %r22, %r3, 1024;
    mul.lo.u32 %r24, %r4, 1024;

    // ldmatrix per-lane intra-subtile address:
    //   g = lane >> 3;   r = lane & 7
    //   row_idx = (g >> 1) * 8 + r   in [0..15]
    //   col_off = (g & 1) * 16        (byte offset within 32-fp16 row = 64 B)
    //   ld_off  = row_idx * 64 + col_off
    shr.u32 %r51, %r50, 3;
    and.b32 %r52, %r50, 7;
    shr.u32 %r53, %r51, 1;
    shl.b32 %r54, %r53, 3;
    add.u32 %r55, %r54, %r52;
    and.b32 %r56, %r51, 1;
    shl.b32 %r57, %r56, 4;
    shl.b32 %r58, %r55, 6;              // row_idx * 64
    add.u32 %r59, %r58, %r57;

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

    // Init accumulator (8 f32 = 2 m16n8k32 calls)
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
    add.u32 %r40, %r18, %r17;
    @%pload_a cp.async.cg.shared.global [%r40], [%rd14], 16;

    add.u32 %r41, %r20, %r17;
    @%pload_a bra $skip_b_prologue;
    @%pload_b cp.async.cg.shared.global [%r41], [%rd15], 16;
$skip_b_prologue:
    cp.async.commit_group;

    add.u64 %rd14, %rd14, {K_TILE_BYTES};
    add.u64 %rd15, %rd15, {K_TILE_BYTES};

$kloop:
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    setp.gt.s32 %pmore, %r0, 1;
    @!%pmore bra $no_prefetch;

    xor.b32 %r31, %r30, 1;
    shl.b32 %r32, %r31, 12;              // next_slot * 4096

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

    // Slab base + per-warp 16x32 subtile offset.
    shl.b32 %r34, %r30, 12;              // current_slot * 4096
    add.u32 %r35, %r18, %r34;
    add.u32 %r35, %r35, %r22;            // warp's A 16x32 base
    add.u32 %r36, %r20, %r34;
    add.u32 %r36, %r36, %r24;            // warp's B 32x16 base (32 cols laid as 16 fp16-rows per "col")

    add.u32 %r60, %r35, %r59;            // lane base for A K-half 0
    add.u32 %r61, %r36, %r59;            // lane base for B K-half 0

    // K-half 0 (K=0..15)
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra0, %ra1, %ra2, %ra3}}, [%r60];

    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rb0, %rb1, %rb2, %rb3}}, [%r61];

    // K-half 1 (K=16..31) -- advance by 16 fp16 = 32 B within the 64-B row stride.
    add.u32 %r62, %r60, 32;
    add.u32 %r63, %r61, 32;

    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra4, %ra5, %ra6, %ra7}}, [%r62];

    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rb4, %rb5, %rb6, %rb7}}, [%r63];

    // 2x mma.m16n8k32 -- one per N-half.
    //   B-half partition (from .x4.trans loading 16x16):
    //     rb0 = K=0..7  N=0..7,    rb1 = K=0..7  N=8..15
    //     rb2 = K=8..15 N=0..7,    rb3 = K=8..15 N=8..15
    //     rb4 = K=16..23 N=0..7,   rb5 = K=16..23 N=8..15
    //     rb6 = K=24..31 N=0..7,   rb7 = K=24..31 N=8..15
    //   So N=0..7 picks rb0/rb2/rb4/rb6 ; N=8..15 picks rb1/rb3/rb5/rb7.

    mma.sync.aligned.m16n8k32.row.col.f32.f16.f16.f32
        {{%fc0, %fc1, %fc2, %fc3}},
        {{%ra0, %ra1, %ra2, %ra3, %ra4, %ra5, %ra6, %ra7}},
        {{%rb0, %rb2, %rb4, %rb6}},
        {{%fc0, %fc1, %fc2, %fc3}};

    mma.sync.aligned.m16n8k32.row.col.f32.f16.f16.f32
        {{%fc4, %fc5, %fc6, %fc7}},
        {{%ra0, %ra1, %ra2, %ra3, %ra4, %ra5, %ra6, %ra7}},
        {{%rb1, %rb3, %rb5, %rb7}},
        {{%fc4, %fc5, %fc6, %fc7}};

    bar.sync 0;

    add.u64 %rd14, %rd14, {K_TILE_BYTES};
    add.u64 %rd15, %rd15, {K_TILE_BYTES};

    xor.b32 %r30, %r30, 1;
    sub.s32 %r0, %r0, 1;
    bra $kloop;

$epilogue:
    // mma.m16n8k32 D-frag store layout (same as m16n8k16: D=4 f32 per lane per 16x8 tile).
    shr.u32 %r70, %r50, 2;
    and.b32 %r71, %r50, 3;
    mul.lo.u32 %r72, %r70, {S*4};
    shl.b32 %r73, %r71, 3;
    add.u32 %r74, %r72, %r73;
    cvt.u64.u32 %rd20, %r74;
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
        p = outdir / f"sgemm_m16n8k32_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes")
