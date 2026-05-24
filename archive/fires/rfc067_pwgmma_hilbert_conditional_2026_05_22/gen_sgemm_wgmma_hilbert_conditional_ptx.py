#!/usr/bin/env python3
"""RFC 067 PWGMMA-HILBERT-CONDITIONAL (N199) -- 4-WARP warpgroup wgmma.mma_async
m64n64k16 + Hilbert CTA-swizzle + identity-at-small-M conditional dispatch.

This combines three orthogonal wins into a single canonical production kernel:

  1. N172 tile-shrink: 64x64 output tile (4 warps of 32 lanes = 128 threads).
  2. N149 PHILB:        Hilbert d2xy CTA-swizzle (best L2 locality, M=8192 ratio 0.847).
  3. N171 PCOND:        conditional identity-at-small-M dispatch (matches small-M cuBLAS,
                        e.g. M=256 ratio 1.066, M=384 0.868).
  4. NEW (this kernel): wgmma.mma_async.sync.aligned.m64n64k16.f32.f16.f16 replaces
                        N171's 8x mma.sync.aligned.m16n8k16 per K-step.

wgmma vs mma.sync (per NVIDIA PTX ISA 8.3+, Hopper-only sm_90a):
  * Warpgroup-level instruction: 1 wgmma issued by 4 warps == 4 warps' worth of mma in
    one issue -> fewer instruction issues, less issue-bandwidth pressure.
  * Shared-mem descriptor-based source operands (no ldmatrix needed) -> fewer
    instructions in the inner loop; tensor cores pull A/B directly from shmem.
  * Async semantics: wgmma.commit_group + wgmma.wait_group separate issue from completion;
    pipelines naturally with cp.async global->shmem loads.

================================================================================
HONEST SCOPE (@D g3) -- HARDWARE BLOCKER (silicon-fire-impossible on ubu-2):
================================================================================

  This kernel REQUIRES sm_90a (Hopper) hardware. wgmma.mma_async, wgmma.fence,
  wgmma.commit_group, wgmma.wait_group are Hopper-only PTX instructions; ptxas
  CUDA 12.9 V12.9.86 explicitly REJECTS them for sm_120a (RTX 5070 Blackwell
  consumer, the only GPU available on ubu-2):

    ptxas error : Instruction 'wgmma.fence' cannot be compiled for architecture 'sm_120a'
    ptxas error : Instruction 'wgmma.mma_async with floating point types' cannot
                  be compiled for architecture 'sm_120a'
    ptxas error : Instruction 'wgmma.commit_group' cannot be compiled for arch 'sm_120a'
    ptxas error : Instruction 'wgmma.wait_group' cannot be compiled for arch 'sm_120a'

  N195 (concurrent wgmma scaffold cycle) already landed
  ("N195 wgmma.async STRUCTURAL IMPOSSIBILITY on RTX 5070 sm_120") with this same
  finding for the minimal m64n16k16 scaffold. N199 (the full-kernel variant with
  m64n64k16 + Hilbert + conditional) reproduces the same rejection: the kernel is
  architecturally well-formed PTX (ptxas-PASS on sm_90a, all 8 shapes; 58 regs/thd,
  8192 B shmem, 0 spills) but the silicon class boundary blocks the fire on ubu-2.

  Conclusion (mirrors N195 verdict):
    - SCAFFOLD ARTIFACT: this generator emits canonical wgmma PTX for all 8 shapes,
      and standalone CUDA-12.9 ptxas --gpu-name=sm_90a accepts every shape (F-PASS at
      the PTX-level on Hopper ISA -- ptxas verification done in measure.sh).
    - SILICON FIRE: BLOCKED. The kernel cannot load on RTX 5070 (cuModuleLoadDataEx
      would return CUDA_ERROR_INVALID_PTX with the same four errors). No measurement
      run; no result.json shape rows with hexa_tflops != null are claimed.
    - The kernel is READY for fire on a Hopper machine (H100, H200, GH200) at which
      point the same PTX files would load, and measure.sh would record HGEMM TFLOPS
      + ratio vs cuBLAS HGEMM at each shape.

================================================================================

Kernel architecture summary (per shape, S = M = N = K):
  * Launch grid:
        - identity regime (gx*gy <= THRESHOLD 4096): side x side  CTAs = S/64 each
        - hilbert  regime: p x p, p = next_pow2(S/64). Hilbert d2xy unrolled, pad-CTA
          early-return.
  * Block: 1 warpgroup = 4 warps = 128 threads.
  * Per CTA: 64x64 output tile in f32 accumulator distributed per-thread (32 f32/thd
    on the wgmma m64n64k16.f32 result vector = 64*64 / 128 = 32 f32/thd, exactly).
  * Inner K-loop per K-step (16 K-lanes per step):
        - cp.async.cg.shared.global per-thread vec-16 loads for A and B (double-buffer)
        - wgmma.fence.sync.aligned
        - wgmma.mma_async.sync.aligned.m64n64k16.f32.f16.f16  (replaces 8x mma.sync!)
        - wgmma.commit_group.sync.aligned
        - wgmma.wait_group.sync.aligned 0  (synchronous wait; future work: pipelined)
  * Shared mem: 2 slabs of 4 KB (A) + 4 KB (B) for double-buffer = 8 KB total / CTA.
"""

import sys
from pathlib import Path


THRESHOLD_CTAS = 4096  # same as N171 PCOND


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
            assert (x, y) not in seen, f"dup tile ({x},{y}) p={p}"
            seen.add((x, y))
    assert len(seen) == gx * gy, f"cover {len(seen)} != {gx*gy} (p={p})"


def emit_hilbert_prologue(p: int, gx: int, gy: int) -> str:
    """Byte-identical to N149/N171 Hilbert d2xy unrolled. Outputs sw_x in %r11, sw_y in %r10."""
    log2p = p.bit_length() - 1
    lines = []
    lines.append("    // ---- CONDITIONAL Hilbert path: d2xy(p, ctaid.y*p+ctaid.x) ----")
    lines.append(f"    //   grid = p x p, p = {p} (next_pow2(gx={gx})); d = ctaid.y*p + ctaid.x")
    lines.append("    mov.u32 %r100, %ctaid.x;")
    lines.append("    mov.u32 %r101, %ctaid.y;")
    lines.append(f"    mul.lo.u32 %r120, %r101, {p};")
    lines.append("    add.u32    %r120, %r120, %r100;")
    lines.append("    mov.u32 %r121, 0;")
    lines.append("    mov.u32 %r122, 0;")
    s = 1
    for it in range(log2p):
        sm1 = s - 1
        lines.append(f"    // --- Hilbert round {it}: s = {s} ---")
        lines.append(f"    shr.u32 %r126, %r120, 1;")
        lines.append(f"    and.b32 %r123, %r126, 1;")
        lines.append(f"    xor.b32 %r127, %r120, %r123;")
        lines.append(f"    and.b32 %r124, %r127, 1;")
        lines.append(f"    setp.eq.u32 %prx0, %r124, 0;")
        lines.append(f"    setp.eq.u32 %prx1, %r123, 1;")
        lines.append(f"    and.pred %prxr, %prx0, %prx1;")
        lines.append(f"    sub.u32 %r128, {sm1}, %r121;")
        lines.append(f"    sub.u32 %r129, {sm1}, %r122;")
        lines.append(f"    selp.b32 %r121, %r128, %r121, %prxr;")
        lines.append(f"    selp.b32 %r122, %r129, %r122, %prxr;")
        lines.append(f"    selp.b32 %r128, %r122, %r121, %prx0;")
        lines.append(f"    selp.b32 %r122, %r121, %r122, %prx0;")
        lines.append(f"    mov.u32 %r121, %r128;")
        lines.append(f"    mul.lo.u32 %r128, %r123, {s};")
        lines.append(f"    add.u32 %r121, %r121, %r128;")
        lines.append(f"    mul.lo.u32 %r129, %r124, {s};")
        lines.append(f"    add.u32 %r122, %r122, %r129;")
        if it != log2p - 1:
            lines.append(f"    shr.u32 %r120, %r120, 2;")
        s <<= 1
    lines.append("    mov.u32 %r11, %r121;")
    lines.append("    mov.u32 %r10, %r122;")
    lines.append(f"    setp.ge.u32 %phlbx, %r11, {gx};")
    lines.append(f"    setp.ge.u32 %phlby, %r10, {gy};")
    lines.append("    or.pred %phlb_oob, %phlbx, %phlby;")
    lines.append("    @%phlb_oob bra $hilbert_oob_ret;")
    return "\n".join(lines)


def emit_acc_init() -> str:
    """32 f32 accumulators per thread (wgmma m64n64k16 D vector = 32 f32/thd)."""
    return "\n".join(f"    mov.f32 %fc{i}, 0f00000000;" for i in range(32))


def emit_acc_list() -> str:
    """{ %fc0, %fc1, ..., %fc31 } for wgmma D operand."""
    inner = ", ".join(f"%fc{i}" for i in range(32))
    return "{" + inner + "}"


def emit_epilogue_st(S: int) -> str:
    """Store 32 f32 per thread back to global C (row-major).

    wgmma m64n64k16 f32 D-vector layout (per PTX ISA 8.5, Table 47):
      thread (warp_id w in [0,4), lane l in [0,32)):
        base_row = w*16 + l//4
        base_col = (l%4)*2
      32 f32 = 4 N-groups (col offset g*16) x 4 sub-cells (drow,dcol in {0,8}x{0,8})
      x 2 f32 per sub-cell (col +{0,1})
    """
    L = []
    L.append("    shr.u32 %r70, %r1, 5;            // warp_id w in [0,4)")
    L.append("    and.b32 %r71, %r1, 31;           // lane in [0,32)")
    L.append("    shl.b32 %r72, %r70, 4;           // w * 16")
    L.append("    shr.u32 %r73, %r71, 2;           // lane >> 2")
    L.append("    add.u32 %r74, %r72, %r73;        // base_row")
    L.append("    and.b32 %r75, %r71, 3;")
    L.append("    shl.b32 %r76, %r75, 1;           // base_col = (lane&3)*2")
    L.append(f"    mul.lo.u32 %r77, %r74, {S*4};")
    L.append(f"    shl.b32 %r78, %r76, 2;")
    L.append("    add.u32 %r79, %r77, %r78;")
    L.append("    cvt.u64.u32 %rd20, %r79;")
    L.append("    add.u64 %rd20, %rd12, %rd20;")
    L.append(f"    add.u64 %rd21, %rd20, {8*S*4};")
    for g in range(4):
        col_off_grp = g * 16
        for sub in range(4):
            drow = 8 * ((sub >> 1) & 1)
            dcol = 8 * (sub & 1)
            for bit in range(2):
                acc_idx = g * 8 + sub * 2 + bit
                col_off = col_off_grp + dcol + bit
                base_reg = "%rd20" if drow == 0 else "%rd21"
                byte = col_off * 4
                L.append(f"    st.global.f32 [{base_reg} + {byte:5d}], %fc{acc_idx};")
    return "\n".join(L)


def encode_smem_desc_runtime() -> str:
    """Build wgmma shmem descriptor at runtime (per PTX ISA 8.5 sec 9.7.13.4):
      bits[13:0]  addr>>4
      bits[29:16] lead_div_16 = 2  (32B / 16)
      bits[45:32] strd_div_16 = 64 (1024B / 16)
      bits[51:49] base offset (0)
      bits[63:62] swizzle (0 = no swizzle)
    """
    L = []
    L.append("    // ==== build A descriptor (64-bit shmem matrix descriptor) ====")
    L.append("    cvt.u64.u32 %rd28, %r170;            // %r170 = A_slab_smem_addr")
    L.append("    shr.b64 %rd28, %rd28, 4;")
    L.append("    and.b64 %rd28, %rd28, 16383;")
    L.append("    mov.u64 %rd29, 2;")
    L.append("    shl.b64 %rd29, %rd29, 16;")
    L.append("    or.b64  %rd30, %rd28, %rd29;")
    L.append("    mov.u64 %rd29, 64;")
    L.append("    shl.b64 %rd29, %rd29, 32;")
    L.append("    or.b64  %rd30, %rd30, %rd29;         // %rd30 = A descriptor")
    L.append("")
    L.append("    // ==== build B descriptor ====")
    L.append("    cvt.u64.u32 %rd28, %r171;            // %r171 = B_slab_smem_addr")
    L.append("    shr.b64 %rd28, %rd28, 4;")
    L.append("    and.b64 %rd28, %rd28, 16383;")
    L.append("    mov.u64 %rd29, 2;")
    L.append("    shl.b64 %rd29, %rd29, 16;")
    L.append("    or.b64  %rd31, %rd28, %rd29;")
    L.append("    mov.u64 %rd29, 64;")
    L.append("    shl.b64 %rd29, %rd29, 32;")
    L.append("    or.b64  %rd31, %rd31, %rd29;         // %rd31 = B descriptor")
    return "\n".join(L)


def gen(S: int) -> str:
    assert S % 64 == 0, f"S={S} must be divisible by 64"

    a_ctay_byte  = 64 * S * 2
    b_ctax_byte  = 64 * S * 2
    c_ctay_byte  = 64 * S * 4
    ab_row_b     = S * 2

    gx = S // 64
    gy = S // 64
    p  = next_pow2(gx)
    verify_bijection(p, gx, gy)
    hilbert = emit_hilbert_prologue(p, gx, gy)
    desc_build = encode_smem_desc_runtime()
    acc_init   = emit_acc_init()
    acc_list   = emit_acc_list()
    epi_st     = emit_epilogue_st(S)

    regime = "identity" if (gx * gy <= THRESHOLD_CTAS) else "hilbert"

    return f"""// RFC 067 PWGMMA-HILBERT-CONDITIONAL (N199) hexa-emit -- M=N=K={S}.
//
// 4-WARP warpgroup wgmma.mma_async.sync.aligned.m64n64k16.f32.f16.f16
//   + Hilbert d2xy CTA-swizzle (N149) + identity-at-small-M conditional dispatch (N171).
//
// THIS PTX REQUIRES sm_90a (Hopper). On sm_120 (Blackwell consumer / RTX 5070) the
// driver rejects wgmma with CUDA_ERROR_INVALID_PTX (see notes.md for the four
// specific ptxas errors). For silicon fire, run on an H100/H200/GH200 host.
//
// Layout:
//   A row-major     [M={S} x K={S}] f16. Row stride = {ab_row_b} B.
//   B col-major     [K={S} x N={S}] f16. Col stride = {ab_row_b} B.
//   C row-major out [M={S} x N={S}] f32. Row stride = {S*4} B.
//
// Per-CTA: 1 warpgroup = 4 warps = 128 threads. Output tile: 64x64 f32 (32 f32 / thd).
// For THIS shape S={S}: gx*gy = {gx*gy}, p = {p} -> regime-at-launch = {regime}.

.version 8.5
.target sm_90a
.address_size 64

.shared .align 16 .b8 _tg_a[4096];
.shared .align 16 .b8 _tg_b[4096];

.visible .entry sgemm_wgmma_cond_{S}x{S}_grid (
    .param .u64 a,
    .param .u64 b,
    .param .u64 c,
    .param .u64 k_tiles
)
{{
    .reg .u64 %rd<40>;
    .reg .u32 %r<200>;
    .reg .pred %p1;
    .reg .pred %pmore;
    .reg .pred %pcond;
    .reg .pred %prx0;
    .reg .pred %prx1;
    .reg .pred %prxr;
    .reg .pred %phlbx;
    .reg .pred %phlby;
    .reg .pred %phlb_oob;
    .reg .f32 %fc<32>;

    ld.param.u64 %rd0, [a];
    ld.param.u64 %rd1, [b];
    ld.param.u64 %rd2, [c];
    ld.param.u64 %rd3, [k_tiles];

    // ---- CONDITIONAL CTA-swizzle gate (uniform, predicated once, no divergence) ----
    mov.u32 %r140, %nctaid.x;
    mov.u32 %r141, %nctaid.y;
    mul.lo.u32 %r142, %r140, %r141;
    setp.le.u32 %pcond, %r142, {THRESHOLD_CTAS};
    @%pcond bra $identity_map;

    // === HILBERT PATH ===
{hilbert}
    bra $swizzle_done;

$identity_map:
    // === IDENTITY PATH (small M, no Hilbert prologue overhead) ===
    mov.u32 %r10, %ctaid.y;
    mov.u32 %r11, %ctaid.x;

$swizzle_done:
    // ---- steady-state body uses (sw_x in %r11, sw_y in %r10) ----

    mov.u32 %r1, %tid.x;          // thread id in [0, 128)
    shr.u32 %r2, %r1, 5;          // warp id in [0, 4)
    and.b32 %r50, %r1, 31;        // lane id

    // Cooperative load indexing: each tid in [0, 128) issues 1 vec16 A + 1 vec16 B.
    shr.u32 %r13, %r1, 1;         // row in [0, 64)
    and.b32 %r14, %r1, 1;         // col_q in {{0, 1}}
    shl.b32 %r15, %r14, 4;        // col_q * 16

    // A_cta base = a + sw_y * {a_ctay_byte}   (sw_y in %r10)
    mul.lo.u32 %r5, %r10, {a_ctay_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd0, %rd4;

    // B_cta base = b + sw_x * {b_ctax_byte}   (sw_x in %r11)
    mul.lo.u32 %r5, %r11, {b_ctax_byte};
    cvt.u64.u32 %rd5, %r5;
    add.u64 %rd11, %rd1, %rd5;

    // Per-thread global-load offset (excluding k-step advance):
    mul.lo.u32 %r16, %r13, {ab_row_b};
    add.u32 %r16, %r16, %r15;
    cvt.u64.u32 %rd14, %r16;
    add.u64 %rd14, %rd10, %rd14;

    cvt.u64.u32 %rd15, %r16;
    add.u64 %rd15, %rd11, %rd15;

    // Per-thread intra-slab shared-mem store offset:
    shl.b32 %r17, %r13, 5;        // row * 32

    mov.u32 %r18, _tg_a;          // base of A shmem buffer
    mov.u32 %r20, _tg_b;          // base of B shmem buffer

    // C base address.
    mul.lo.u32 %r5, %r10, {c_ctay_byte};
    mul.lo.u32 %r8, %r11, 256;
    add.u32 %r7, %r5, %r8;
    cvt.u64.u32 %rd6, %r7;
    add.u64 %rd12, %rd2, %rd6;

    // Init 32 f32 accumulators per thread (wgmma m64n64k16.f32 D vector).
{acc_init}

    cvt.s32.s64 %r0, %rd3;

    mov.u32 %r30, 0;              // current slot (0 or 1)

    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    // ---- PROLOGUE: issue K=0 prefetch into slot 0 ----
    add.u32 %r40, %r18, %r17;
    cp.async.cg.shared.global [%r40], [%rd14], 16;

    add.u32 %r41, %r20, %r17;
    cp.async.cg.shared.global [%r41], [%rd15], 16;

    cp.async.commit_group;

    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

$kloop:
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    setp.gt.s32 %pmore, %r0, 1;
    @!%pmore bra $no_prefetch;

    xor.b32 %r31, %r30, 1;
    shl.b32 %r32, %r31, 11;       // next_slot * 2048

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

    // current slot base addrs for A and B shmem
    shl.b32 %r34, %r30, 11;       // current_slot * 2048
    add.u32 %r170, %r18, %r34;    // A_slab_addr
    add.u32 %r171, %r20, %r34;    // B_slab_addr

{desc_build}

    // ---- wgmma.mma_async (warpgroup-level, m64n64k16, f32 acc, fp16 A * fp16 B) ----
    wgmma.fence.sync.aligned;
    wgmma.mma_async.sync.aligned.m64n64k16.f32.f16.f16
        {acc_list},
        %rd30, %rd31,
        1, 1, 1, 0, 0;
    wgmma.commit_group.sync.aligned;
    wgmma.wait_group.sync.aligned 0;

    bar.sync 0;

    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

    xor.b32 %r30, %r30, 1;
    sub.s32 %r0, %r0, 1;
    bra $kloop;

$epilogue:
{epi_st}

    ret;

$hilbert_oob_ret:
    ret;
}}
"""


SHAPES = [256, 384, 512, 1024, 2048, 4096, 6144, 8192]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        assert S % 64 == 0, f"S={S} not 64-aligned"
        p = outdir / f"sgemm_wgmma_cond_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        side = S // 64
        regime = "identity" if (side * side <= THRESHOLD_CTAS) else "hilbert"
        print(f"wrote {p.name} ({len(p.read_text())} bytes) regime={regime} grid_ctas={side*side}")
    print(f"total {len(SHAPES)} shapes; THRESHOLD_CTAS={THRESHOLD_CTAS}")
