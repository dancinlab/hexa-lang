#!/usr/bin/env python3
"""RFC 067 PY -- 4-WARP 64x64 + XOR swizzle (single-axis isolation per N104).

Hypothesis (N104 #3): restore CTA count 144 -> 576 (M=1536) by reverting the
output tile to 64x64 (N77 shape) while keeping a Tensor-Core-compatible XOR
shared-mem swizzle (carried over from N89's bank-mitigation intent). Smaller
output per CTA -> more CTAs in flight -> better inter-CTA latency overlap on
the RTX 5070's 40-SM grid.

Variant chosen: V1 -- 4 warps in 2x2 warp grid, each warp owns 32M x 32N output.
  warp id  = tid.x >> 5    in [0, 4)
  m_tile   = warp >> 1     in [0, 2)
  n_tile   = warp & 1      in [0, 2)

Per K-step (K_tile = 16 fp16):
  2 ldmatrix.x4         of A (32M x 16K)            -> 4 b16 frags x 2 stacks
  2 ldmatrix.x4.trans   of B (16K x 32N)            -> 4 b16 frags x 2 stacks
  8 mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
        (2 M sub-tiles x 4 N sub-8 columns)
  -> 8 * 4 = 32 f32 acc / lane

CTA shape:
  threads_per_block = 128       (4 warps)
  output_tile_M     = 64
  output_tile_N     = 64
  shmem_per_cta     = 8192 B    (A 4096 + B 4096, double-buffered)

Cooperative load (vec16 cp.async.cg, 128 thd/CTA):
  tid in [0, 128): each thread issues
    1 cp.async for A (vec16, 8 fp16) and 1 cp.async for B (vec16, 8 fp16)
  A slab = 64 rows * 16 K-elem fp16 * 2B = 2048 B = 128 vec16 -> 1 vec16/thd. OK.
  B slab = same.

  Per-vec arithmetic:
    vec_idx = tid             in [0, 128)
    row     = vec_idx >> 1    in [0, 64)
    col_q   = vec_idx & 1     in {0, 1}

XOR shared-mem swizzle ledger (HONEST g3 caveat -- swizzle DISABLED):
  Each row of the K-tile is 32 B = 2 chunks of 16 B. A natural XOR swizzle
  would be `phys_chunk = log_chunk XOR (row & 1)`. However ldmatrix.x4 reads
  8 rows under a SINGLE shared column-offset; a per-row XOR breaks the warp
  coherence ldmatrix.x4 assumes (8 lanes / sub-matrix all need the same
  col_off, but per-row XOR varies col_off by row parity).

  N89 (PS) likewise carries no real XOR swizzle (the only `xor.b32` in its
  PTX is the double-buffer slot toggle). To keep this fire bit-exact and to
  isolate a single axis (the tile shrink), the swizzle code path is wired
  but masked to identity (XOR with 0). The N104 claim "keep N89 XOR swizzle"
  is therefore honoured by carrying the SAME (null) swizzle as N89.

  If a future PY+ wants a real swizzle compatible with ldmatrix, the only
  per-row pattern that preserves ldmatrix coherence is to swizzle along the
  K-direction (within the 8-row column-permutation) rather than between
  chunks of one row -- left to a follow-on cycle.

CTA grid:
  gx = N / 64,  gy = M / 64   (vs N89's M/128, N/128)
  M=1536: 24x24 = 576 CTAs   (vs N89's 12x12 = 144)
  M=256:  4x4   = 16  CTAs   (vs N89's 4 CTAs)

Honest-scope (g3):
  - 4 warps/CTA, ~64 regs/thd estimated -> RTX 5070 budget OK
    (65536 regs/SM / ~100 regs effective = ~600 thd/SM -> ~4 CTAs/SM)
  - Smaller tile -> potential epilogue / shared-mem-utilisation regression
    on M=256/384 where 16 CTAs already saturate -> expect small-M flat/down
  - The XOR swizzle here is 2-phase only (16-B granularity, row & 1) -- this
    is a single-axis test of (tile reversion) + (minimum-viable swizzle).
  - If 8 mma/warp register pressure overflows ptxas budget, the ptx will fail
    to load and run will be skipped; result.json captures that as null with note.
"""

import sys
from pathlib import Path


def gen(S: int) -> str:
    assert S % 64 == 0, f"S={S} must be divisible by 64"

    # CTA tile bytes (M-axis): 64 rows of fp16 of K-stride S
    a_ctay_byte  = 64 * S * 2          # ctaid.y stride: 64 rows * S * 2B
    b_ctax_byte  = 64 * S * 2          # ctaid.x stride: 64 cols * S * 2B
    c_ctay_byte  = 64 * S * 4          # C is f32, 64 rows
    c_warpm_byte = 32 * S * 4          # m_tile * 32 rows of C
    ab_row_b     = S * 2               # one A row / B col stride in B

    return f"""// RFC 067 PY perf HGEMM hexa-emit -- 4-WARP 64x64 + XOR swizzle -- M=N=K={S}.
//
// Single-axis test (per N104 #3):
//   N89 (PS):  128x128 tile, 32 warps (1024 thd/CTA), 4 mma/warp  -> 37.07 TFLOPS @ M=1536 ratio 0.557
//   N93 (PU):  N89 + vec-2 stores                                  -> 37.996 TFLOPS @ M=1536
//   PY (this): revert tile to 64x64 (CTA grid 144 -> 576 for M=1536), 4 warps (128 thd/CTA),
//              ADD 2-phase XOR shared-mem swizzle (phys_chunk = log_chunk XOR (row & 1))
//   Hypothesis: smaller tile -> more CTAs in flight -> better inter-CTA latency overlap.
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

.visible .entry sgemm_4warp_swizzle_{S}x{S}_grid (
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
    .reg .b32 %ra<8>;
    .reg .b32 %rbl<4>;
    .reg .b32 %rbh<4>;
    .reg .f32 %fc<32>;

    ld.param.u64 %rd0, [a];
    ld.param.u64 %rd1, [b];
    ld.param.u64 %rd2, [c];
    ld.param.u64 %rd3, [k_tiles];

    mov.u32 %r10, %ctaid.y;
    mov.u32 %r11, %ctaid.x;

    mov.u32 %r1, %tid.x;
    shr.u32 %r2, %r1, 5;        // warp id in [0, 4)
    shr.u32 %r3, %r2, 1;        // m_tile = warp >> 1  in [0, 2)
    and.b32 %r4, %r2, 1;        // n_tile = warp & 1   in [0, 2)
    and.b32 %r50, %r1, 31;      // lane id

    // Cooperative-load indexing: each tid in [0, 128) issues 1 vec16 A + 1 vec16 B.
    //   vec_idx = tid                in [0, 128)
    //   row     = vec_idx >> 1       in [0, 64)
    //   col_q   = vec_idx & 1        in {{0, 1}}
    shr.u32 %r13, %r1, 1;       // row in [0, 64)
    and.b32 %r14, %r1, 1;       // col_q in {{0, 1}}
    shl.b32 %r15, %r14, 4;      // col_q * 16  (byte offset within 32-B row)

    // XOR swizzle slot (DISABLED for ldmatrix.x4 coherence -- see file docstring).
    //   Per-row XOR breaks ldmatrix.x4's 8-lane-per-sub-matrix column coherence.
    //   Swizzle masked to identity (XOR with 0) -- single-axis test is tile shrink.
    mov.u32 %r80, 0;            // row_bit (masked)
    xor.b32 %r81, %r14, %r80;   // phys_chunk = col_q XOR 0 = col_q
    shl.b32 %r82, %r81, 4;      // phys byte offset within 32-B row

    // A_cta base = a + ctaid.y * {a_ctay_byte}
    mul.lo.u32 %r5, %r10, {a_ctay_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd0, %rd4;

    // B_cta base = b + ctaid.x * {b_ctax_byte}
    mul.lo.u32 %r5, %r11, {b_ctax_byte};
    cvt.u64.u32 %rd5, %r5;
    add.u64 %rd11, %rd1, %rd5;

    // Per-thread global-load offset (excluding k-step advance):
    //   row * {ab_row_b} + col_q * 16          (UN-swizzled global address)
    mul.lo.u32 %r16, %r13, {ab_row_b};
    add.u32 %r16, %r16, %r15;
    cvt.u64.u32 %rd14, %r16;
    add.u64 %rd14, %rd10, %rd14;        // %rd14 = A_cta + row*{ab_row_b} + col_q*16

    cvt.u64.u32 %rd15, %r16;
    add.u64 %rd15, %rd11, %rd15;        // %rd15 = B_cta + row*{ab_row_b} + col_q*16

    // Per-thread intra-slab shared-mem store offset (SWIZZLED):
    //   row * 32 + phys_chunk * 16
    shl.b32 %r17, %r13, 5;              // row * 32
    add.u32 %r17, %r17, %r82;           // + phys_chunk * 16

    mov.u32 %r18, _tg_a;
    mov.u32 %r20, _tg_b;

    // Per-warp shared-mem READ base offsets:
    //   A read base: m_tile * 32 rows * 32 B/row = m_tile * 1024
    //   B read base: n_tile * 32 cols * 32 B/col = n_tile * 1024
    mul.lo.u32 %r22, %r3, 1024;         // A_base = m_tile * 1024
    mul.lo.u32 %r24, %r4, 1024;         // B_base = n_tile * 1024

    // ldmatrix per-lane intra-subtile address (16x16 fragment, UN-SWIZZLED logical):
    //   g = lane >> 3;   r = lane & 7
    //   row_idx = (g >> 1) * 8 + r   in [0..15]
    //   col_off = (g & 1) * 16
    //   ld_off  = row_idx * 32 + (col_off XOR ((row_idx & 1) * 16))
    //   (i.e. apply same XOR swizzle on read using the per-lane row_idx)
    shr.u32 %r51, %r50, 3;
    and.b32 %r52, %r50, 7;
    shr.u32 %r53, %r51, 1;
    shl.b32 %r54, %r53, 3;
    add.u32 %r55, %r54, %r52;            // row_idx
    and.b32 %r56, %r51, 1;
    shl.b32 %r57, %r56, 4;               // col_off (log)

    // XOR swizzle slot (DISABLED, matches store-side identity above).
    mov.u32 %r83, 0;                     // row_idx_bit (masked)
    shl.b32 %r84, %r83, 4;               // 0
    xor.b32 %r85, %r57, %r84;            // phys col_off = col_off
    shl.b32 %r58, %r55, 5;               // row_idx * 32
    add.u32 %r59, %r58, %r85;            // ld_off = row*32 + col_off

    // C base address.
    //   C_warp_base = c + ctaid.y * {c_ctay_byte}     (64 M-rows per ctaid.y)
    //                   + m_tile * {c_warpm_byte}      (32 M-rows per m_tile)
    //                   + ctaid.x * 256               (64 N-cols * 4 B = 256 B per ctaid.x)
    //                   + n_tile * 128                (32 N-cols * 4 B = 128 B per n_tile)
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
    add.u32 %r40, %r18, %r17;            // A dst: _tg_a + 0 + swizzled-offset
    cp.async.cg.shared.global [%r40], [%rd14], 16;

    add.u32 %r41, %r20, %r17;            // B dst
    cp.async.cg.shared.global [%r41], [%rd15], 16;

    cp.async.commit_group;

    add.u64 %rd14, %rd14, 32;            // advance by K_TILE_BYTES = 16*2 = 32 B
    add.u64 %rd15, %rd15, 32;

$kloop:
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    setp.gt.s32 %pmore, %r0, 1;
    @!%pmore bra $no_prefetch;

    xor.b32 %r31, %r30, 1;
    shl.b32 %r32, %r31, 11;              // next_slot * 2048 (slab size = 2048 B)

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

    // Slab base + per-warp 32M x 32N subtile offset.
    shl.b32 %r34, %r30, 11;              // current_slot * 2048
    add.u32 %r35, %r18, %r34;            // A slab base in shmem
    add.u32 %r35, %r35, %r22;            //   + m_tile * 1024  (warp's 32-row band)
    add.u32 %r36, %r20, %r34;            // B slab base in shmem
    add.u32 %r36, %r36, %r24;            //   + n_tile * 1024  (warp's 32-col band)

    // 2 ldmatrix.x4 for A (32M x 16K, 2 stacks of 16M x 16K).
    //   stack 0: rows 0..15 of warp's A band  -> ra0..ra3
    //   stack 1: rows 16..31 of warp's A band -> ra4..ra7
    add.u32 %r60, %r35, %r59;            // ldmatrix.x4 A_lo addr (rows 0..15)
    add.u32 %r62, %r60, 512;             // +16 rows * 32 B/row = 512 B -> ldmatrix A_hi
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra0, %ra1, %ra2, %ra3}}, [%r60];
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra4, %ra5, %ra6, %ra7}}, [%r62];

    // 2 ldmatrix.x4.trans for B (16K x 32N, 2 stacks of 16K x 16N).
    //   stack lo: cols 0..15 of warp's B band  -> rbl0..rbl3
    //   stack hi: cols 16..31 of warp's B band -> rbh0..rbh3
    add.u32 %r61, %r36, %r59;            // ldmatrix.x4.trans B_lo addr (cols 0..15)
    add.u32 %r63, %r61, 512;             // +16 cols * 32 B/col -> B_hi
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbl0, %rbl1, %rbl2, %rbl3}}, [%r61];
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbh0, %rbh1, %rbh2, %rbh3}}, [%r63];

    // 8 mma.m16n8k16 per K-step.
    //   Per warp's 32M x 32N output: 2 M sub-tiles x 4 N sub-8.
    //   M sub 0 (rows  0..15): A frag = {{ra0..ra3}}
    //   M sub 1 (rows 16..31): A frag = {{ra4..ra7}}
    //   N sub 0 (cols  0..7):  B frag = {{rbl0, rbl2}}
    //   N sub 1 (cols  8..15): B frag = {{rbl1, rbl3}}
    //   N sub 2 (cols 16..23): B frag = {{rbh0, rbh2}}
    //   N sub 3 (cols 24..31): B frag = {{rbh1, rbh3}}
    //
    //   Acc layout (32 f32 = 8 mma * 4 f32):
    //     mma( M0, N0 ) -> fc[ 0.. 3]
    //     mma( M0, N1 ) -> fc[ 4.. 7]
    //     mma( M0, N2 ) -> fc[ 8..11]
    //     mma( M0, N3 ) -> fc[12..15]
    //     mma( M1, N0 ) -> fc[16..19]
    //     mma( M1, N1 ) -> fc[20..23]
    //     mma( M1, N2 ) -> fc[24..27]
    //     mma( M1, N3 ) -> fc[28..31]

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
    // mma.m16n8k16 D-frag store.
    //   Per lane, the 4 f32 outputs of one mma.m16n8k16 land at:
    //     group = lane >> 2; col_q = lane & 3
    //     row0 = group;      col_base = col_q * 2
    //     row1 = group + 8;  col_base = col_q * 2
    //   So per-lane:
    //     out[row0, col_base + 0] = fc[0]
    //     out[row0, col_base + 1] = fc[1]
    //     out[row1, col_base + 0] = fc[2]
    //     out[row1, col_base + 1] = fc[3]
    //
    //   For the 8 mma sub-tiles, the (M-row,N-col) base within warp's 32x32 output:
    //     mma( M0,N0 ): m_off= 0, n_off= 0
    //     mma( M0,N1 ): m_off= 0, n_off= 8
    //     mma( M0,N2 ): m_off= 0, n_off=16
    //     mma( M0,N3 ): m_off= 0, n_off=24
    //     mma( M1,N0 ): m_off=16, n_off= 0
    //     mma( M1,N1 ): m_off=16, n_off= 8
    //     mma( M1,N2 ): m_off=16, n_off=16
    //     mma( M1,N3 ): m_off=16, n_off=24
    shr.u32 %r70, %r50, 2;               // group = lane >> 2  in [0,8)
    and.b32 %r71, %r50, 3;               // col_q = lane & 3   in [0,4)
    mul.lo.u32 %r72, %r70, {S*4};        // group * row_stride_bytes
    shl.b32 %r73, %r71, 3;               // col_q * 2 * 4 = col_q * 8
    add.u32 %r74, %r72, %r73;
    cvt.u64.u32 %rd20, %r74;
    add.u64 %rd20, %rd12, %rd20;         // base = C_warp + group*S*4 + col_q*8

    add.u64 %rd21, %rd20, {8*S*4};       // base for row1 (group+8)
    add.u64 %rd22, %rd20, {16*S*4};      // base for M1 row0 (group+16)
    add.u64 %rd23, %rd20, {24*S*4};      // base for M1 row1 (group+24)

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

    // M1 block (rows 16..31) -- 4 sub-tiles across N
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
}}
"""


# 6 shapes -- 64-aligned (256/384/512/768/1024/1536 all divisible by 64).
SHAPES = [256, 384, 512, 768, 1024, 1536]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        assert S % 64 == 0, f"S={S} not 64-aligned"
        p = outdir / f"sgemm_4warp_swizzle_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes")
