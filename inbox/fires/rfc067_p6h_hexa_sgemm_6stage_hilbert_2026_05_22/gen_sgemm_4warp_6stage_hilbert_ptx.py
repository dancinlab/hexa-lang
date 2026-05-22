#!/usr/bin/env python3
"""RFC 067 P6H -- COMBINE: N121 6-stage cp.async pipeline + N149 Hilbert CTA-swizzle (2026-05-22).

Hypothesis (combine the two regime winners into one kernel):
  N121 (PZ): 4-warp 64x64 tile + 6-stage cp.async pipeline.
             Small-shape WIN: M=256 ratio 1.1611 (cuBLAS-BEAT). But large M hurts:
             M=1536 -2.32% vs N107 2-stage (shmem 24576 B cuts occupancy 8->4 CTAs/SM).
  N149 (PHILB): 4-warp 64x64 tile + Hilbert-curve d2xy CTA-swizzle (2-stage).
             Large-shape WIN: M=8192 ratio 0.847, M=6144 cliff flattened. Tighter 2D L2
             working set (adjacent CTA IDs -> Manhattan-adjacent tiles).
  P6H (this) = N121 6-stage pipeline body + N149 Hilbert CTA-visitation prologue.
             Question: does combined kernel WIN BOTH regimes?
               * best small-shape latency-hiding (6-stage pipeline) AND
               * best large-shape L2 locality (Hilbert swizzle)?

Construction:
  - Take N121's 6-stage kernel body VERBATIM (consume/produce ring, wait_group 4,
    prologue 5 cp.async groups, 24576 B shmem, 8 mma/warp/K).
  - Replace N121's `mov %r10, ctaid.y; mov %r11, ctaid.x` with N149's Hilbert d2xy
    prologue, which writes sw_y -> %r10 and sw_x -> %r11 (exact same registers N121
    consumes for its A/B/C base addresses). So the pipeline body is byte-untouched;
    only the (ctaid -> tile) mapping changes.
  - Launch grid = p x p, p = next_pow2(side). Padding CTAs (sw_x>=gx || sw_y>=gy)
    early-return via $hilbert_oob_ret. Bijective over the real gx x gy grid -> bit-exact.

Register namespaces are disjoint:
  - N121 body uses %r0..%r74, %rd0..%rd23, preds %p1/%pmore/%pissue.
  - Hilbert prologue uses %r100..%r129 + writes %r10/%r11, preds %prx0/%prx1/%prxr/
    %phlbx/%phlby/%phlb_oob.  No collision.

g3 honest scope:
  - N121's 6-stage 24576 B shmem + Hilbert unrolled-bit-twiddle prologue may COMPOUND
    occupancy + register cost. Measure regs/thd + shmem from cuFuncGetAttribute.
  - If 6-stage at large M still hurts (per N121's M=1536 -2.32%) even with Hilbert
    helping L2, the two optimizations don't compose cleanly -- useful negative.
  - If combined wins BOTH regimes, it's the new canonical best single kernel.
  - bit-exact REQUIRED (both N121 + N149 are semantic-preserving; mma identical).

Falsifier F-RFC067-HEXA-SGEMM-6STAGE-HILBERT:
  - max|delta|=0 vs cuBLAS HGEMM across all sweep shapes (mma identical -- bit-exact)
  - per-shape median TFLOPS over 200 reps (20 warmup), cuEvent sync
  - report ratio vs cuBLAS at every shape
  - SMALL: M=256/384/512 (where N121 6-stage wins; M=256 must stay >= ~1.16)
  - LARGE: M=4096/6144/8192 (where N149 Hilbert wins; M=8192 must stay >= ~0.847)

PTX gotchas (per reference_gpu_fire_infra):
  - Pure ASCII PTX comments only (driver-JIT ptxas rejects non-ASCII).
  - One @predicate guard per instruction; combine with and.pred / selp branchless.
"""

import sys
from pathlib import Path


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
    """Assert filtered Hilbert covers gx x gy exactly once -> bit-exact precondition."""
    seen = set()
    for d in range(p * p):
        x, y = hilbert_d2xy_ref(p, d)
        if x < gx and y < gy:
            assert (x, y) not in seen, f"dup tile ({x},{y}) p={p}"
            seen.add((x, y))
    assert len(seen) == gx * gy, f"cover {len(seen)} != {gx*gy} (p={p})"


def emit_hilbert_prologue(p: int, gx: int, gy: int) -> str:
    """Emit straight-line (unrolled) Hilbert d2xy PTX (N149 PHILB identical).

    Inputs:  ctaid.x, ctaid.y  (grid is p x p)
    Outputs: %r10 = sw_y (= hy),  %r11 = sw_x (= hx)   <- exactly what N121 body reads.
    Early-return predicate %phlb_oob true if (hx>=gx || hy>=gy).

    Registers used (all in the .reg .u32 %r<...> pool, disjoint from N121 body's r0..r74):
      %r100,%r101 = ctaid.x, ctaid.y
      %r120 = d (running index t)
      %r121 = x (hx accumulator)
      %r122 = y (hy accumulator)
      %r123 = rx ; %r124 = ry ; %r126..%r129 = scratch
    Branchless rotate via selp (no per-round branch).
    """
    log2p = p.bit_length() - 1
    lines = []
    lines.append("    // ---- CTA-swizzle: Hilbert-curve d2xy (N149 PHILB) for L2 reuse ----")
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
    assert S >= 96, f"S={S} too small for 5-stage prologue (K_total >= 5 -> K >= 80)"

    # N121 6-stage geometry.
    a_ctay_byte  = 64 * S * 2          # ctaid.y stride: 64 rows * S * 2B
    b_ctax_byte  = 64 * S * 2          # ctaid.x stride: 64 cols * S * 2B
    c_ctay_byte  = 64 * S * 4          # C is f32, 64 rows
    c_warpm_byte = 32 * S * 4          # m_tile * 32 rows of C
    ab_row_b     = S * 2               # one A row / B col stride in B
    SLAB_BYTES   = 2048                # 64 rows * 16 K-elem * 2 B
    STAGES       = 6
    SHMEM_PER_ARRAY = STAGES * SLAB_BYTES  # 12288

    # Hilbert grid params.
    gx = S // 64
    gy = S // 64
    p  = next_pow2(gx)
    verify_bijection(p, gx, gy)
    hilbert = emit_hilbert_prologue(p, gx, gy)

    # N121 prologue stage blocks.
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

    return f"""// RFC 067 P6H perf HGEMM hexa-emit -- 4-WARP 64x64 + 6-STAGE PIPELINE + HILBERT CTA-SWIZZLE -- M=N=K={S}.
//
// COMBINE the two regime winners:
//   N121 (PZ):    6-stage cp.async pipeline -- small-shape WIN (M=256 ratio 1.1611), large M hurts.
//   N149 (PHILB): Hilbert-curve d2xy CTA-swizzle -- large-shape WIN (M=8192 ratio 0.847, cliff flat).
//   P6H (this):   N121 pipeline body + N149 Hilbert visitation. Win both regimes?
//
// CTA-swizzle (N149 PHILB): launch grid = p x p, p = {p} (= next_pow2(gx={gx})).
//   d = ctaid.y*p + ctaid.x;  (sw_x, sw_y) = hilbert_d2xy({p}, d)  -- unrolled {p.bit_length()-1} rounds.
//   drop padding tiles where sw_x >= {gx} or sw_y >= {gy} (early-return; bijective over real grid).
//   Pipeline body byte-identical to N121: only ctaid -> tile mapping changes.
//
// Shared-mem per CTA: 6 stages * 2 arrays * 2048 B = 24576 B (fits sm_90 100 KB cap).

.version 8.0
.target sm_90
.address_size 64

.shared .align 16 .b8 _tg_a[{SHMEM_PER_ARRAY}];
.shared .align 16 .b8 _tg_b[{SHMEM_PER_ARRAY}];

.visible .entry sgemm_4warp_6stage_hilbert_{S}x{S}_grid (
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
    .reg .pred %pissue;
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

{hilbert}

    mov.u32 %r1, %tid.x;
    shr.u32 %r2, %r1, 5;        // warp id in [0, 4)
    shr.u32 %r3, %r2, 1;        // m_tile = warp >> 1  in [0, 2)
    and.b32 %r4, %r2, 1;        // n_tile = warp & 1   in [0, 2)
    and.b32 %r50, %r1, 31;      // lane id

    // Cooperative-load indexing (N121 identical):
    shr.u32 %r13, %r1, 1;       // row in [0, 64)
    and.b32 %r14, %r1, 1;       // col_q in {{0, 1}}
    shl.b32 %r15, %r14, 4;      // col_q * 16  (byte offset within 32-B row)

    // A_cta base = a + sw_y * {a_ctay_byte}   (sw_y in %r10)
    mul.lo.u32 %r5, %r10, {a_ctay_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd0, %rd4;

    // B_cta base = b + sw_x * {b_ctax_byte}   (sw_x in %r11)
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
    mul.lo.u32 %r22, %r3, 1024;         // A_base = m_tile * 1024
    mul.lo.u32 %r24, %r4, 1024;         // B_base = n_tile * 1024

    // ldmatrix per-lane intra-subtile address (16x16 fragment):
    shr.u32 %r51, %r50, 3;
    and.b32 %r52, %r50, 7;
    shr.u32 %r53, %r51, 1;
    shl.b32 %r54, %r53, 3;
    add.u32 %r55, %r54, %r52;            // row_idx
    and.b32 %r56, %r51, 1;
    shl.b32 %r57, %r56, 4;               // col_off
    shl.b32 %r58, %r55, 5;               // row_idx * 32
    add.u32 %r59, %r58, %r57;            // ld_off = row*32 + col_off

    // C base address (sw_y/sw_x swizzled):
    //   C_warp_base = c + sw_y * {c_ctay_byte}
    //                   + m_tile * {c_warpm_byte}
    //                   + sw_x * 256
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
    // PROLOGUE: issue up to 5 cp.async groups (stages 0..4). (N121)
    // ===========================================================
{prologue_text}

    // ===========================================================
    // STEADY-STATE K-LOOP (N121 6-stage):
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

    // Consume slab[%r30]: byte offset = stage * 2048
    shl.b32 %r35, %r30, 11;
    add.u32 %r36, %r18, %r35;
    add.u32 %r36, %r36, %r22;
    add.u32 %r37, %r20, %r35;
    add.u32 %r37, %r37, %r24;

    // 2 ldmatrix.x4 for A.
    add.u32 %r60, %r36, %r59;
    add.u32 %r62, %r60, 512;
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra0, %ra1, %ra2, %ra3}}, [%r60];
    ldmatrix.sync.aligned.m8n8.x4.shared.b16
        {{%ra4, %ra5, %ra6, %ra7}}, [%r62];

    // 2 ldmatrix.x4.trans for B.
    add.u32 %r61, %r37, %r59;
    add.u32 %r63, %r61, 512;
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbl0, %rbl1, %rbl2, %rbl3}}, [%r61];
    ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16
        {{%rbh0, %rbh1, %rbh2, %rbh3}}, [%r63];

    // 8 mma.m16n8k16 per K-step.
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
    // mma.m16n8k16 D-frag store (N121 identical -- single-element f32 stores).
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

    // M0 block (rows 0..15)
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

    // M1 block (rows 16..31)
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
    // padding CTA (sw_x>=gx or sw_y>=gy) -- no output tile, return immediately.
    ret;
}}
"""


# Sweep BOTH regimes:
#   SMALL: 256/384/512 (N121 6-stage wins; M=256 ratio 1.1611)
#   LARGE: 4096/6144/8192 (N149 Hilbert wins; M=8192 ratio 0.847)
SHAPES = [256, 384, 512, 4096, 6144, 8192]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        assert S % 64 == 0, f"S={S} not 64-aligned"
        p = outdir / f"sgemm_4warp_6stage_hilbert_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes (bijection verified per shape)")
