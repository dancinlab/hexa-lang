#!/usr/bin/env python3
"""RFC 067 PW -- 6-STAGE cp.async SOFTWARE PIPELINE on top of N93/PU baseline (2026-05-22).

Starting baseline: N93/PU = PS tile128 + vec2 epilogue
                   peak 37.996 TFLOPS @ M=1536, ratio 0.5705 vs cuBLAS HGEMM 66.60.

Source 2 from N104 SASS-diff:
  cuBLAS s16816gemm_64x64_32x6 ('_x6' suffix = 6-stage pipeline).
  hexa N93 uses cp.async.commit_group + cp.async.wait_group 1 with 2-slot ring (double-buffer).
  Net effect: at most 1 load in-flight per CTA, no inter-K latency overlap.

PW change (CUTLASS-style multi-stage software pipeline):
  STAGES = 6 (5 in-flight + 1 compute).
  Shared-mem: 6 slabs * 4096 B per array (A, B) = 24576 B per array = 49152 B per CTA
              (under 100 KB sm_90 carveout).

Prologue:
  for s in 0..STAGES-2 (= 0..4):
    issue cp.async for K-block s into slab s
    cp.async.commit_group
  -> 5 committed groups in flight (predicated on K_total > s for K-tiles tail).

Main K-loop body for k in 0..K_total-1:
  cp.async.wait_group 4   # wait until <=4 still in flight; stage (k%6) is done
  bar.sync 0
  ldmatrix.x4 + 4x mma on slab (k%6)
  bar.sync 0
  if k + 5 < K_total:
    issue cp.async into slab ((k+5)%6)
  cp.async.commit_group   # always commit so wait_group accounting stays consistent

Epilogue:
  cp.async.wait_all
  st.global.v2.f32 x 8 per warp (vec-2 stores, inherited from PU)

Falsifier F-RFC067-HEXA-SGEMM-6STAGE-PIPELINE:
  - max|delta|=0 vs cuBLAS HGEMM (mma path identical = bit-exact)
  - per-shape median TFLOPS over 200 reps (20 warmup)
  - peak TFLOPS @ M=1536 expected 53-57 (vs N93 37.996), ratio 0.78-0.85 vs cuBLAS

PTX gotchas:
  - PTX allows only ONE @predicate guard per instruction; combine with `and.pred`.
  - bra targets must be `@%p label` form; cannot stack predicates.
"""

import sys
from pathlib import Path


def gen(S: int) -> str:
    assert S % 128 == 0, f"S={S} must be divisible by 128 for tile128"
    assert S >= 80, f"S={S} too small for 5-stage prologue (K_total >= 5 required)"
    a_ctay_byte = 128 * S * 2
    b_ctax_byte = 128 * S * 2
    c_ctay_byte = 128 * S * 4
    c_warpm_byte = 16 * S * 4
    ab_row_b = S * 2
    SLAB_BYTES = 4096
    STAGES = 6
    SHMEM_PER_ARRAY = STAGES * SLAB_BYTES  # 24576

    # Build prologue stage block. slot_off = stage index * 4096.
    # For stage 0 we are unconditional (K_total > 0 was checked above).
    # For stages 1..4 we need to predicate the cp.async issues on K_total > stage_idx.
    def prologue_stage(stage_idx, label_suffix, gate_pred):
        slot_off = stage_idx * SLAB_BYTES
        # Combined predicates: pa = pload_a & gate; pb = pload_b & gate.
        if gate_pred is None:
            a_pred = "%pload_a"
            b_pred = "%pload_b"
            issue_pred = None
            setup = ""
        else:
            a_pred = "%pa_eff"
            b_pred = "%pb_eff"
            issue_pred = gate_pred
            setup = (
                f"    and.pred %pa_eff, %pload_a, {gate_pred};\n"
                f"    and.pred %pb_eff, %pload_b, {gate_pred};\n"
            )
        # Address-advance is gated on the issue_pred (for stage 0, always advance).
        if issue_pred is None:
            adv = (
                "    add.u64 %rd14, %rd14, 32;\n"
                "    add.u64 %rd15, %rd15, 32;\n"
            )
        else:
            adv = (
                f"    @{issue_pred} add.u64 %rd14, %rd14, 32;\n"
                f"    @{issue_pred} add.u64 %rd15, %rd15, 32;\n"
            )
        block = f"""    // Prologue stage {stage_idx} (slab offset {slot_off})
{setup}    add.u32 %r40, %r18, {slot_off};
    add.u32 %r40, %r40, %r17;
    @{a_pred} cp.async.cg.shared.global [%r40], [%rd14], 16;
    add.u32 %r41, %r20, {slot_off};
    add.u32 %r41, %r41, %r17;
    @%pload_a bra $skip_b_pro{label_suffix};
    @{b_pred} cp.async.cg.shared.global [%r41], [%rd15], 16;
$skip_b_pro{label_suffix}:
    cp.async.commit_group;
{adv}"""
        return block

    prologue_blocks = []
    # Stage 0: K_total >= 1 (checked by branch to $epilogue above).
    prologue_blocks.append(prologue_stage(0, "0", None))
    # Stage 1: only if K_total > 1.
    prologue_blocks.append("    setp.gt.s32 %pissue, %r0, 1;\n" + prologue_stage(1, "1", "%pissue"))
    prologue_blocks.append("    setp.gt.s32 %pissue, %r0, 2;\n" + prologue_stage(2, "2", "%pissue"))
    prologue_blocks.append("    setp.gt.s32 %pissue, %r0, 3;\n" + prologue_stage(3, "3", "%pissue"))
    prologue_blocks.append("    setp.gt.s32 %pissue, %r0, 4;\n" + prologue_stage(4, "4", "%pissue"))
    prologue_text = "\n".join(prologue_blocks)

    return f"""// RFC 067 PW perf HGEMM hexa-emit -- 6-STAGE PIPELINE -- M=N=K={S}.
//
// On top of N93/PU stack:
//   N93/PU: 128x128 tile, 32 warps, 2-slot pipeline (cp.async.commit_group + wait_group 1)
//           peak 37.996 TFLOPS @ M=1536 ratio 0.5705 vs cuBLAS HGEMM 66.60.
//   PW:     identical kernel except 6-slot software pipeline (5 in-flight + 1 compute)
//           via prologue + steady-state wait_group(4).

.version 8.0
.target sm_90
.address_size 64

.shared .align 16 .b8 _tg_a[{SHMEM_PER_ARRAY}];
.shared .align 16 .b8 _tg_b[{SHMEM_PER_ARRAY}];

.visible .entry sgemm_6stage_{S}x{S}_grid (
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
    .reg .pred %pload_a;
    .reg .pred %pload_b;
    .reg .pred %pissue;
    .reg .pred %pa_eff;
    .reg .pred %pb_eff;
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
    shr.u32 %r2, %r1, 5;
    shr.u32 %r3, %r2, 2;
    and.b32 %r4, %r2, 3;
    and.b32 %r50, %r1, 31;

    setp.lt.u32 %pload_a, %r1, 256;
    setp.lt.u32 %pload_b, %r1, 512;

    and.b32 %r12, %r1, 255;
    shr.u32 %r13, %r12, 1;
    and.b32 %r14, %r12, 1;
    shl.b32 %r15, %r14, 4;

    mul.lo.u32 %r5, %r10, {a_ctay_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd0, %rd4;

    mul.lo.u32 %r5, %r11, {b_ctax_byte};
    cvt.u64.u32 %rd5, %r5;
    add.u64 %rd11, %rd1, %rd5;

    mul.lo.u32 %r16, %r13, {ab_row_b};
    add.u32 %r16, %r16, %r15;
    cvt.u64.u32 %rd14, %r16;
    add.u64 %rd14, %rd10, %rd14;

    cvt.u64.u32 %rd15, %r16;
    add.u64 %rd15, %rd11, %rd15;

    shl.b32 %r17, %r13, 5;
    add.u32 %r17, %r17, %r15;

    mov.u32 %r18, _tg_a;
    mov.u32 %r20, _tg_b;

    mul.lo.u32 %r22, %r3, 512;
    mul.lo.u32 %r24, %r4, 1024;
    add.u32 %r25, %r24, 512;

    shr.u32 %r51, %r50, 3;
    and.b32 %r52, %r50, 7;
    shr.u32 %r53, %r51, 1;
    shl.b32 %r54, %r53, 3;
    add.u32 %r55, %r54, %r52;
    and.b32 %r56, %r51, 1;
    shl.b32 %r57, %r56, 4;
    shl.b32 %r58, %r55, 5;
    add.u32 %r59, %r58, %r57;

    mul.lo.u32 %r5, %r10, {c_ctay_byte};
    mul.lo.u32 %r6, %r3, {c_warpm_byte};
    add.u32 %r7, %r5, %r6;
    mul.lo.u32 %r8, %r11, 512;
    add.u32 %r7, %r7, %r8;
    mul.lo.u32 %r8, %r4, 128;
    add.u32 %r7, %r7, %r8;
    cvt.u64.u32 %rd6, %r7;
    add.u64 %rd12, %rd2, %rd6;

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

    shl.b32 %r35, %r30, 12;
    add.u32 %r36, %r18, %r35;
    add.u32 %r36, %r36, %r22;
    add.u32 %r37, %r20, %r35;
    add.u32 %r38, %r37, %r25;
    add.u32 %r37, %r37, %r24;

    add.u32 %r60, %r36, %r59;
    add.u32 %r61, %r37, %r59;
    add.u32 %r62, %r38, %r59;

    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra0, %ra1, %ra2, %ra3}}, [%r60];

    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbl0, %rbl1, %rbl2, %rbl3}}, [%r61];

    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbh0, %rbh1, %rbh2, %rbh3}}, [%r62];

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

    // ---- Issue next-future stage prefetch if K-blocks remain ----
    setp.gt.s32 %pissue, %r34, 0;
    and.pred %pa_eff, %pload_a, %pissue;
    and.pred %pb_eff, %pload_b, %pissue;
    shl.b32 %r39, %r31, 12;

    add.u32 %r40, %r18, %r39;
    add.u32 %r40, %r40, %r17;
    @%pa_eff cp.async.cg.shared.global [%r40], [%rd14], 16;

    add.u32 %r41, %r20, %r39;
    add.u32 %r41, %r41, %r17;
    @%pload_a bra $skip_b_steady;
    @%pb_eff cp.async.cg.shared.global [%r41], [%rd15], 16;
$skip_b_steady:
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
    shr.u32 %r70, %r50, 2;
    and.b32 %r71, %r50, 3;
    mul.lo.u32 %r72, %r70, {S*4};
    shl.b32 %r73, %r71, 3;
    add.u32 %r74, %r72, %r73;
    cvt.u64.u32 %rd20, %r74;
    add.u64 %rd20, %rd12, %rd20;
    add.u64 %rd21, %rd20, {8*S*4};

    st.global.v2.f32 [%rd20 +     0], {{%fc0, %fc1}};
    st.global.v2.f32 [%rd21 +     0], {{%fc2, %fc3}};
    st.global.v2.f32 [%rd20 +    32], {{%fc4, %fc5}};
    st.global.v2.f32 [%rd21 +    32], {{%fc6, %fc7}};
    st.global.v2.f32 [%rd20 +    64], {{%fc8, %fc9}};
    st.global.v2.f32 [%rd21 +    64], {{%fc10, %fc11}};
    st.global.v2.f32 [%rd20 +    96], {{%fc12, %fc13}};
    st.global.v2.f32 [%rd21 +    96], {{%fc14, %fc15}};

    ret;
}}
"""


SHAPES = [256, 384, 512, 768, 1024, 1536]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        assert S % 128 == 0, f"S={S} not 128-aligned"
        p = outdir / f"sgemm_6stage_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes")
