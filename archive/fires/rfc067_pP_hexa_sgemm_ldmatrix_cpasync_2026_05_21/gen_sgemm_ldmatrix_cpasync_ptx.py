#!/usr/bin/env python3
"""RFC 067 PP -- STACK N76 (ldmatrix.x4 + mma.m16n8k16) + N74 (cp.async.cg size=16).

Hypothesis: two single-axis wins compound multiplicatively.
  N76 baseline: 31.28 TFLOPS @ M=1536, ratio 0.462 vs cuBLAS HGEMM 67.65
  N74 result:   +14.2% on SGEMM by switching cp.async per-fp32 (size=4) to
                vectorised cp.async.cg size=16 (4 fp32 per instr).
  HGEMM packs 8 fp16 per size=16 cp.async, so the per-K-step instruction count
  drops 8x (vs N76's per-fp16 size=2). Expected stacked ratio ~0.55+ (~37 TFLOPS).

What changes vs N76 (PATH-B HGEMM, ldmatrix.x4 + mma.m16n8k16):
  Cooperative load:
    N76: 512 threads x cp.async.ca.shared.global size=2  (1 fp16/instr) -> 1024 instr/K-step
    PP:  256 active threads x cp.async.cg.shared.global size=16 (8 fp16/instr) -> 256 instr/K-step  (4x reduction)

Everything else preserved EXACTLY (consumer path is identical):
  - 16 warps in 4x4 layout -> 64x64 output tile per CTA
  - Shared layout: A row-major _tg_a[slot][row][k] byte = slot*2048 + row*32 + k*2  (rows of 16 fp16)
  - Shared layout: B col-major _tg_b[slot][col][k] byte = slot*2048 + col*32 + k*2
  - ldmatrix.x4 (A row-layout) + ldmatrix.x4.trans (B col-layout)
  - 2x mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 per K-step

Shared-mem (DOUBLE-BUFFERED -- unchanged):
  _tg_a[4096] = 2 slabs * 64 rows * 16 K-elem fp16 * 2 B = 2 * 2048 B
  _tg_b[4096] = 2 slabs * 64 cols * 16 K-elem fp16 * 2 B = 2 * 2048 B

Cooperative load (NEW -- vectorised cp.async.cg size=16):
  Per K-step: A slab = 64 rows * 16 K-elem fp16 = 2048 B = 128 vec16 loads.
  B slab same = 128 vec16 loads. Total = 256 vec16 / K-step (vs N76's 1024 scalar).

  Thread mapping:
    tid in [0,   128): load A   vec_idx = tid
    tid in [128, 256): load B   vec_idx = tid - 128
    tid in [256, 512): idle for cp.async; participate in ldmatrix+mma+bar.sync

  Per-vec (for active tid):
    vec_idx = tid & 127            in [0, 128)
    row     = vec_idx >> 1         in [0, 64)
    col_q   = vec_idx & 1          in {0,1}  (which 8-fp16 chunk in the 16-wide row)
    intra-slab byte offset = row*32 + col_q*16

  Per-thread per-K-step global address (k = current K-step in [0, K/16)):
    g_off = row * (K * 2) + k * 32 + col_q * 16
    g_addr_A = A_cta + g_off
    g_addr_B = B_cta + g_off    (B is col-major with col-stride = K*2 B, same arithmetic shape)

  Alignment proof (S = M = N = K, S divisible by 64):
    A_cta base offset = ctaid.y * 64 * S * 2 = ctaid.y * 128*S B; S>=256 -> 16-aligned.
    row * (S*2) -- S*2 is multiple of 512 (since S>=256), so 16-aligned.
    k * 32 -- 16-aligned.
    col_q * 16 -- 16-aligned.
    Shared dst: row*32 + col_q*16 -- 16-aligned, slab is .align 16.
    Both global src and shared dst meet cp.async.cg 16-byte alignment requirement.

Honest-scope guards:
  - cp.async.cg requires size=16; we've proven src/dst are 16-aligned by construction.
  - Threads in [256, 512) issue NO cp.async; they still hit bar.sync and the ldmatrix
    consumer (every warp owns its 16x16 sub-tile).
  - mma path / ldmatrix path identical to N76 -> bit-exact match expected vs N76's
    output (and same f16-mul-f32-acc-vs-cuBLAS tolerance behavior as PO).
"""

import sys
from pathlib import Path


def gen(S: int) -> str:
    assert S % 64 == 0, f"S={S} must be divisible by 64"
    a_byte = 64 * S * 2            # ctaid stride: 64 rows * S cols * 2 B  (fp16)
    am_byte = 16 * S * 2           # m_tile stride
    c_byte = 64 * S * 4            # C is f32
    cm_byte = 16 * S * 4           # 16 C rows
    ab_row_b = S * 2               # one A row / B col stride (fp16)

    return f"""// RFC 067 PP perf HGEMM hexa-emit -- STACK ldmatrix.x4 + cp.async.cg vec16 -- M=N=K={S}.
//
// Stack of two single-axis wins:
//   N76 (PO):  Path B FP16 HGEMM + ldmatrix.x4 + mma.m16n8k16   -> 31.28 TFLOPS @ M=1536 ratio 0.462
//   N74 (PM):  TF32 SGEMM + cp.async.cg vec16 (4 fp32/instr)     -> +14.2% over N66
//
// PP applies N74's vec16 vector-cp.async to N76's HGEMM. With FP16, size=16 packs
// 8 fp16/instr (vs N76's per-fp16 size=2). Per-K-step cp.async instruction count:
//   N76: 1024  ->  PP: 256  (4x reduction in async-issue bandwidth).
//
// Consumer (ldmatrix.x4 + 2x mma.m16n8k16) identical to N76 -> bit-exact.
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

.visible .entry sgemm_ldmatrix_cpasync_{S}x{S}_grid (
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

    // Vectorised cooperative-load predicates / indexing (NEW vs N76).
    //   load_a active for tid in [0, 128)
    //   load_b active for tid in [128, 256)  -- in code we gate via pload_a + pload_b
    //   In either case: vec_idx = tid & 127  (0..127)
    //                   row     = vec_idx >> 1     in [0, 64)
    //                   col_q   = vec_idx & 1      in {{0,1}}
    setp.lt.u32 %pload_a, %r1, 128;
    setp.lt.u32 %pload_b, %r1, 256;

    and.b32 %r12, %r1, 127;     // vec_idx
    shr.u32 %r13, %r12, 1;      // row in [0, 64)
    and.b32 %r14, %r12, 1;      // col_q in {{0,1}}
    shl.b32 %r15, %r14, 4;      // col_q * 16  (byte offset within 32-B row)

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
    //   row*32 + col_q*16   in {{0..2032}} step 16
    shl.b32 %r17, %r13, 5;              // row * 32
    add.u32 %r17, %r17, %r15;           // + col_q*16

    mov.u32 %r18, _tg_a;
    mov.u32 %r20, _tg_b;

    // Per-warp shared-mem READ base offsets (unchanged from N76):
    //   m_tile * 16 rows * 32 B/row = m_tile * 512
    mul.lo.u32 %r22, %r3, 512;
    mul.lo.u32 %r24, %r4, 512;

    // ldmatrix per-lane intra-subtile address (unchanged from N76):
    //   g = lane >> 3;   r = lane & 7
    //   row_idx = (g >> 1) * 8 + r   in [0..15]
    //   col_off = (g & 1) * 16
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

    // C base address (unchanged from N76).
    mul.lo.u32 %r5, %r10, {c_byte};
    mul.lo.u32 %r6, %r3, {cm_byte};
    add.u32 %r7, %r5, %r6;
    mul.lo.u32 %r8, %r11, 256;
    add.u32 %r7, %r7, %r8;
    mul.lo.u32 %r8, %r4, 64;
    add.u32 %r7, %r7, %r8;
    cvt.u64.u32 %rd6, %r7;
    add.u64 %rd12, %rd2, %rd6;

    // Init accumulator (8 f32 = 2 m16n8k16 calls)
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

    // ---- PROLOGUE: issue K=0 prefetch into slot 0 (NEW: vec16 cp.async.cg) ----
    // A dst = _tg_a + 0 + %r17
    add.u32 %r40, %r18, %r17;
    @%pload_a cp.async.cg.shared.global [%r40], [%rd14], 16;

    // B dst = _tg_b + 0 + %r17 ; tid in [128, 256) only.
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
    shl.b32 %r32, %r31, 11;              // next_slot * 2048

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

    // Slab base + per-warp 16x16 subtile offset (unchanged from N76).
    shl.b32 %r34, %r30, 11;
    add.u32 %r35, %r18, %r34;
    add.u32 %r35, %r35, %r22;
    add.u32 %r36, %r20, %r34;
    add.u32 %r36, %r36, %r24;

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

    bar.sync 0;

    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

    xor.b32 %r30, %r30, 1;
    sub.s32 %r0, %r0, 1;
    bra $kloop;

$epilogue:
    // mma.m16n8k16 D-frag store (unchanged from N76).
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


# Same 6 shapes as N76 / N74 for direct comparison.
SHAPES = [256, 384, 512, 768, 1024, 1536]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        p = outdir / f"sgemm_ldmatrix_cpasync_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes")
