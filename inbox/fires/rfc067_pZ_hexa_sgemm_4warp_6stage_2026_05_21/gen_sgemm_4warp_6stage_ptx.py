#!/usr/bin/env python3
"""RFC 067 PZ -- STACK: N107 (4-warp 64x64 tile) + N105 (6-stage cp.async pipeline) (2026-05-22).

Stack hypothesis (per N104 recommended stacking order):
  Step 1 = REC 3 (tile 64x64 / 4-warp) -- LANDED in N107 (PY)
            peak 51.65 TFLOPS @ M=1536 ratio 0.777 vs cuBLAS HGEMM
            +0.220 ratio over N93 (0.557 -> 0.777)
  Step 2 = REC 1 (6-stage cp.async pipeline) -- LANDED in N105 (PW) on N93 stack
            +0.044 ratio (0.570 -> 0.614)
  Step 3 = THIS = stack them. If multiplicative compound: 0.777 + 0.044 ~ 0.82 or higher.
  Honest g3: cross-baseline composition is not multiplicative; N105's +0.044 was on
             a 32-warp 1024-thread baseline. On a 4-warp 128-thd CTA the latency-hiding
             benefit may differ. Useful-negative is acceptable per task spec.

PZ design (PY consumer + PW producer):
  Output tile      = 64 x 64 (M x N) per CTA          (from PY)
  Warps / CTA      = 4 (2x2 grid)                      (from PY)
  Threads / CTA    = 128                               (from PY)
  Per-warp output  = 32 M x 32 N                       (from PY)
  mma per K-step   = 8 (2 M sub-tiles x 4 N sub-8)     (from PY)
  Acc f32 / lane   = 32                                (from PY)

  Pipeline stages  = 6                                  (from PW; N93's 2 -> 6)
  In-flight groups = 5                                  (PW; commit_group on issue)
  wait_group N     = 4                                  (PW; consume slot k => wait < N-2 in flight)

Shared-mem budget:
  PY per-slab A = 64 rows x 16 K-elem fp16 = 2048 B
  PY per-slab B = 16 K-elem x 64 cols fp16 = 2048 B    (B is col-major)
  6 stages x 2048 B = 12288 B per array
  Total per CTA = 24576 B   <<  100 KB sm_90 carveout                       (fits 4-5 CTAs/SM)

Cooperative load (vec16 cp.async.cg, 128 thd/CTA):
  tid in [0, 128): each thread issues 1 cp.async for A + 1 cp.async for B,
                   each loading 8 fp16 (16 B). 128 * 16 = 2048 B / array = 1 slab.
  Per-vec arithmetic (PY identical):
    vec_idx = tid             in [0, 128)
    row     = vec_idx >> 1    in [0, 64)
    col_q   = vec_idx & 1     in {0, 1}
    col_b   = col_q * 16      (byte offset within 32-B row)

Prologue:
  Stage 0: unconditional cp.async A + B at slab[0], commit_group
  Stage 1..4: predicated on K_total > stage_idx -- issue cp.async + commit_group
  After prologue: 5 committed groups in flight.

Steady-state loop (k_iter = 0..K_total - 1, consume_stage = k % 6, produce_stage = (k+5) % 6):
  cp.async.wait_group 4         (wait until <=4 in flight; consume_slot ready)
  bar.sync 0
  ldmatrix.x4 (A_lo + A_hi)
  ldmatrix.x4.trans (B_lo + B_hi)
  8x mma.m16n8k16   (PY pattern: 2 M-stacks x 4 N-cols)
  bar.sync 0
  if k + 5 < K_total: issue cp.async into slab[produce_stage]
  cp.async.commit_group         (always commit -- accounting consistent)
  advance consume_stage = (consume_stage + 1) % 6
  advance produce_stage = (produce_stage + 1) % 6

Epilogue (PY identical):
  cp.async.wait_all
  st.global.f32 x 32 (8 sub-tiles x 4 elems/lane)
  -- single-element f32 stores, NOT vec-2: PY's output layout interleaves col groups
     and per-lane (row0/row1) split, which doesn't allow trivially packing adjacent
     f32s into vec-2 pairs. PY shipped single-elem stores -- we keep parity for bit-exact.

Falsifier F-RFC067-HEXA-SGEMM-STACK-6STAGE-4WARP:
  - max|delta|=0 vs cuBLAS HGEMM across all 6 shapes (mma identical -- bit-exact)
  - per-shape median TFLOPS over 200 reps (20 warmup)
  - report ratio vs cuBLAS at every shape
  - compare against PY (51.65 @ M=1536) and PW (40.90 @ M=1536)

PTX gotchas (already encountered in PW):
  - One @predicate guard per instruction; combine with `and.pred`.
  - bra targets are `@%p label`; cannot stack predicates.
  - Pure ASCII PTX comments only (driver-JIT ptxas rejects non-ASCII).
"""

import sys
from pathlib import Path


def gen(S: int) -> str:
    assert S % 64 == 0, f"S={S} must be divisible by 64"
    assert S >= 96, f"S={S} too small for 5-stage prologue (K_total >= 5 -> K >= 80)"

    # CTA tile bytes (M-axis): 64 rows of fp16 of K-stride S
    a_ctay_byte  = 64 * S * 2          # ctaid.y stride: 64 rows * S * 2B
    b_ctax_byte  = 64 * S * 2          # ctaid.x stride: 64 cols * S * 2B
    c_ctay_byte  = 64 * S * 4          # C is f32, 64 rows
    c_warpm_byte = 32 * S * 4          # m_tile * 32 rows of C
    ab_row_b     = S * 2               # one A row / B col stride in B
    SLAB_BYTES   = 2048                # 64 rows * 16 K-elem * 2 B  (= 64 cols * 16 K * 2)
    STAGES       = 6
    SHMEM_PER_ARRAY = STAGES * SLAB_BYTES  # 12288

    # Build prologue stage block. slot_off = stage idx * SLAB_BYTES.
    def prologue_stage(stage_idx, label_suffix, gate_pred):
        slot_off = stage_idx * SLAB_BYTES
        if gate_pred is None:
            issue_pred = None
            setup = ""
        else:
            issue_pred = gate_pred
            setup = ""
        if issue_pred is None:
            issue_prefix = ""
            adv = (
                "    add.u64 %rd14, %rd14, 32;\n"
                "    add.u64 %rd15, %rd15, 32;\n"
            )
        else:
            issue_prefix = f"@{issue_pred} "
            adv = (
                f"    @{issue_pred} add.u64 %rd14, %rd14, 32;\n"
                f"    @{issue_pred} add.u64 %rd15, %rd15, 32;\n"
            )
        block = f"""    // Prologue stage {stage_idx} (slab byte offset {slot_off})
{setup}    add.u32 %r40, %r18, {slot_off};
    add.u32 %r40, %r40, %r17;
    {issue_prefix}cp.async.cg.shared.global [%r40], [%rd14], 16;
    add.u32 %r41, %r20, {slot_off};
    add.u32 %r41, %r41, %r17;
    {issue_prefix}cp.async.cg.shared.global [%r41], [%rd15], 16;
    cp.async.commit_group;
{adv}"""
        return block

    prologue_blocks = []
    prologue_blocks.append(prologue_stage(0, "0", None))
    prologue_blocks.append("    setp.gt.s32 %pissue, %r0, 1;\n" + prologue_stage(1, "1", "%pissue"))
    prologue_blocks.append("    setp.gt.s32 %pissue, %r0, 2;\n" + prologue_stage(2, "2", "%pissue"))
    prologue_blocks.append("    setp.gt.s32 %pissue, %r0, 3;\n" + prologue_stage(3, "3", "%pissue"))
    prologue_blocks.append("    setp.gt.s32 %pissue, %r0, 4;\n" + prologue_stage(4, "4", "%pissue"))
    prologue_text = "\n".join(prologue_blocks)

    return f"""// RFC 067 PZ perf HGEMM hexa-emit -- 4-WARP 64x64 + 6-STAGE PIPELINE -- M=N=K={S}.
//
// Stack:
//   N107 (PY): 4-warp 64x64 tile, 128 thd/CTA, 8 mma/warp/K, 2-slot ring
//              -> 51.65 TFLOPS @ M=1536 ratio 0.777
//   N105 (PW): 32-warp 128x128 tile, 6-stage cp.async pipeline
//              -> 40.90 TFLOPS @ M=1536 ratio 0.614 (+7.6% over N93)
//   PZ (this): N107 consumer + N105 producer = 4-warp 64x64 tile with 6-stage pipeline
//
// Shared-mem per CTA: 6 stages * 2 arrays * 2048 B = 24576 B (fits sm_90 100 KB cap).

.version 8.0
.target sm_90
.address_size 64

.shared .align 16 .b8 _tg_a[{SHMEM_PER_ARRAY}];
.shared .align 16 .b8 _tg_b[{SHMEM_PER_ARRAY}];

.visible .entry sgemm_4warp_6stage_{S}x{S}_grid (
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
    .reg .pred %pissue;
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

    // Cooperative-load indexing (PY identical):
    //   vec_idx = tid                in [0, 128)
    //   row     = vec_idx >> 1       in [0, 64)
    //   col_q   = vec_idx & 1        in {{0, 1}}
    shr.u32 %r13, %r1, 1;       // row in [0, 64)
    and.b32 %r14, %r1, 1;       // col_q in {{0, 1}}
    shl.b32 %r15, %r14, 4;      // col_q * 16  (byte offset within 32-B row)

    // A_cta base = a + ctaid.y * {a_ctay_byte}
    mul.lo.u32 %r5, %r10, {a_ctay_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd0, %rd4;

    // B_cta base = b + ctaid.x * {b_ctax_byte}
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
    //   row * 32 + col_q * 16    (slab is 64 rows of 32 B)
    shl.b32 %r17, %r13, 5;              // row * 32
    add.u32 %r17, %r17, %r15;           // + col_q * 16

    mov.u32 %r18, _tg_a;
    mov.u32 %r20, _tg_b;

    // Per-warp shared-mem READ base offsets:
    //   A read base: m_tile * 32 rows * 32 B/row = m_tile * 1024
    //   B read base: n_tile * 32 cols * 32 B/col = n_tile * 1024
    mul.lo.u32 %r22, %r3, 1024;         // A_base = m_tile * 1024
    mul.lo.u32 %r24, %r4, 1024;         // B_base = n_tile * 1024

    // ldmatrix per-lane intra-subtile address (16x16 fragment):
    //   g = lane >> 3;   r = lane & 7
    //   row_idx = (g >> 1) * 8 + r
    //   col_off = (g & 1) * 16
    //   ld_off  = row_idx * 32 + col_off
    shr.u32 %r51, %r50, 3;
    and.b32 %r52, %r50, 7;
    shr.u32 %r53, %r51, 1;
    shl.b32 %r54, %r53, 3;
    add.u32 %r55, %r54, %r52;            // row_idx
    and.b32 %r56, %r51, 1;
    shl.b32 %r57, %r56, 4;               // col_off
    shl.b32 %r58, %r55, 5;               // row_idx * 32
    add.u32 %r59, %r58, %r57;            // ld_off = row*32 + col_off

    // C base address.
    //   C_warp_base = c + ctaid.y * {c_ctay_byte}
    //                   + m_tile * {c_warpm_byte}
    //                   + ctaid.x * 256
    //                   + n_tile * 128
    mul.lo.u32 %r5, %r10, {c_ctay_byte};
    mul.lo.u32 %r6, %r3, {c_warpm_byte};
    add.u32 %r7, %r5, %r6;
    mul.lo.u32 %r8, %r11, 256;
    add.u32 %r7, %r7, %r8;
    mul.lo.u32 %r8, %r4, 128;
    add.u32 %r7, %r7, %r8;
    cvt.u64.u32 %rd6, %r7;
    add.u64 %rd12, %rd2, %rd6;

    // Init accumulator -- 32 f32.
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

    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    // ===========================================================
    // PROLOGUE: issue up to 5 cp.async groups (stages 0..4).
    // ===========================================================
{prologue_text}

    // ===========================================================
    // STEADY-STATE K-LOOP: k_iter = 0..K_total-1
    //   %r30 = consume stage = k % 6
    //   %r31 = produce stage = (k + 5) % 6
    //   %r34 = K-blocks remaining to issue (= K_total - 5)
    //   %r0  = consume iterations remaining (= K_total - k_iter)
    // ===========================================================

    mov.u32 %r30, 0;
    mov.u32 %r31, 5;
    sub.s32 %r34, %r0, 5;

$kloop:
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $drain_tail;

    cp.async.wait_group 4;
    bar.sync 0;

    // Consume slab[%r30]: byte offset = stage * SLAB_BYTES = stage * 2048
    shl.b32 %r35, %r30, 11;              // stage * 2048
    add.u32 %r36, %r18, %r35;            // A slab base in shmem
    add.u32 %r36, %r36, %r22;            //   + m_tile * 1024  (warp's 32-row band)
    add.u32 %r37, %r20, %r35;            // B slab base in shmem
    add.u32 %r37, %r37, %r24;            //   + n_tile * 1024  (warp's 32-col band)

    // 2 ldmatrix.x4 for A (32M x 16K, 2 stacks of 16M x 16K).
    add.u32 %r60, %r36, %r59;            // ldmatrix.x4 A_lo addr (rows 0..15)
    add.u32 %r62, %r60, 512;             // +16 rows * 32 B/row = 512 B -> A_hi
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra0, %ra1, %ra2, %ra3}}, [%r60];
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra4, %ra5, %ra6, %ra7}}, [%r62];

    // 2 ldmatrix.x4.trans for B (16K x 32N, 2 stacks of 16K x 16N).
    add.u32 %r61, %r37, %r59;            // ldmatrix.x4.trans B_lo addr (cols 0..15)
    add.u32 %r63, %r61, 512;             // +16 cols * 32 B/col -> B_hi
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbl0, %rbl1, %rbl2, %rbl3}}, [%r61];
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbh0, %rbh1, %rbh2, %rbh3}}, [%r63];

    // 8 mma.m16n8k16 per K-step.
    //   M sub 0 (rows  0..15): A frag = {{ra0..ra3}}
    //   M sub 1 (rows 16..31): A frag = {{ra4..ra7}}
    //   N sub 0..3 from rbl0/rbl2, rbl1/rbl3, rbh0/rbh2, rbh1/rbh3
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

    // ---- Issue next-future stage prefetch if K-blocks remain ----
    setp.gt.s32 %pissue, %r34, 0;
    shl.b32 %r39, %r31, 11;              // produce stage * 2048

    add.u32 %r40, %r18, %r39;
    add.u32 %r40, %r40, %r17;
    @%pissue cp.async.cg.shared.global [%r40], [%rd14], 16;

    add.u32 %r41, %r20, %r39;
    add.u32 %r41, %r41, %r17;
    @%pissue cp.async.cg.shared.global [%r41], [%rd15], 16;

    cp.async.commit_group;
    @%pissue add.u64 %rd14, %rd14, 32;
    @%pissue add.u64 %rd15, %rd15, 32;

    // Advance ring buffer indices.
    add.u32 %r30, %r30, 1;
    setp.eq.s32 %p1, %r30, 6;
    @%p1 mov.u32 %r30, 0;

    add.u32 %r31, %r31, 1;
    setp.eq.s32 %p1, %r31, 6;
    @%p1 mov.u32 %r31, 0;

    sub.s32 %r0, %r0, 1;
    sub.s32 %r34, %r34, 1;
    bra $kloop;

$drain_tail:
    cp.async.wait_all;

$epilogue:
    // mma.m16n8k16 D-frag store (PY identical -- single-element f32 stores).
    //   Per lane: group = lane >> 2; col_q = lane & 3
    //     out[row0=group,    col_base+0] = fc[0]
    //     out[row0=group,    col_base+1] = fc[1]
    //     out[row1=group+8,  col_base+0] = fc[2]
    //     out[row1=group+8,  col_base+1] = fc[3]
    //   For 8 mma sub-tiles: (m_off, n_off) = (0,0)(0,8)(0,16)(0,24)
    //                                         (16,0)(16,8)(16,16)(16,24)
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
        p = outdir / f"sgemm_4warp_6stage_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes")
