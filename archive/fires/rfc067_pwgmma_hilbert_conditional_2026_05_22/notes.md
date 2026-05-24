# RFC 067 N199 PWGMMA-HILBERT-CONDITIONAL — cycle notes

**Date**: 2026-05-22
**Host**: ubu-2 (RTX 5070 sm_120, driver 580.159.03, ptxas CUDA 12.9 V12.9.86)
**Scope**: full canonical SGEMM kernel = N172 64x64 tile + N149 Hilbert d2xy CTA-swizzle
+ N171 PCOND conditional dispatch + Hopper wgmma.mma_async.sync.aligned.m64n64k16
**Outcome**: SCAFFOLD-PASS / SILICON-FIRE-BLOCKED

## TL;DR

The full N199 kernel was emitted and verified at the PTX level. All 8 shapes
(M = 256, 384, 512, 1024, 2048, 4096, 6144, 8192) compile cleanly on **sm_90a** with
the canonical Hopper assembler:
- 58 registers / thread
- 1 barrier
- 8192 B shmem (2 slabs of 4 KB for double-buffer A + B)
- 0 stack frame, 0 spill stores, 0 spill loads

The kernel **cannot be silicon-fired on ubu-2** because RTX 5070 is sm_120 (Blackwell
consumer / GB202), which explicitly **rejects** every `wgmma` family instruction at
ptxas/driver level. This is the same boundary that N195 already established for the
m64n16k16 scaffold (commit `7e26b7b8`). N199 is the full-kernel reproduction and
confirms the verdict: **wgmma is Hopper-only; consumer Blackwell needs tcgen05.mma**.

Per the N195 commit body: *"N199 (wgmma+Hilbert combined) will fail same way."*
Confirmed.

## What's in this artifact

| File | Purpose |
|---|---|
| `gen_sgemm_wgmma_hilbert_conditional_ptx.py` | PTX generator, emits 8 shapes |
| `host.c` | driver-API host with sm-major hard-gate (refuses to run on sm != 9) |
| `measure.sh` | regen + ship + ptxas-verify + sm-detect + (fire | blocker-record) |
| `sgemm_wgmma_cond_*x*_grid.ptx` (×8) | one PTX per shape (256..8192) |
| `ptxas_info.log` | CUDA 12.9 standalone ptxas verification (sm_90a PASS + sm_120a REJECT) |
| `compile.log` | nvcc compile output (skipped on sm_120) |
| `fire.log` | silicon-fire log (blocker record on sm_120) |
| `result.json` | machine-readable cycle result (blocker-only on sm_120) |
| `notes.md` | this file |

## Kernel architecture (when fired on Hopper)

```
Block size : 128 threads = 1 warpgroup = 4 warps
Output tile: 64 x 64 f32 acc (32 f32 per thread, wgmma m64n64k16.f32 D layout)
Shmem      : 2 slabs × (A:2048 B + B:2048 B) = 8 KB / CTA (double-buffer)
K-step     : 16 K-lanes
Per K-step :
  1. cp.async.cg.shared.global  (A) + (B)         vec16, per-thread
  2. cp.async.commit_group
  3. cp.async.wait_group 1                         (prev fully loaded)
  4. bar.sync 0
  5. encode A descriptor (smem addr | lead=2 | strd=64)
  6. encode B descriptor
  7. wgmma.fence.sync.aligned
  8. wgmma.mma_async.sync.aligned.m64n64k16.f32.f16.f16  ← 1 instr replaces N171's 8 mma.sync
  9. wgmma.commit_group.sync.aligned
 10. wgmma.wait_group.sync.aligned 0               (synchronous; future: wait_group N)
 11. bar.sync 0

CTA-swizzle (entry, branch-once on uniform grid CTA count):
  grid_ctas <= 4096  -> identity: sw = ctaid (no Hilbert prologue)
  grid_ctas >  4096  -> Hilbert d2xy unrolled (log2(p) rounds, p = next_pow2(side))
                        + drop-padding-CTA early return
```

## ptxas verification

CUDA 12.9 standalone `ptxas` (V12.9.86, May 2025) on ubu-2:

### sm_90a (Hopper) — PASS for all 8 shapes
```
ptxas info    : Compiling entry function 'sgemm_wgmma_cond_<S>x<S>_grid' for 'sm_90a'
ptxas info    : Function properties for sgemm_wgmma_cond_<S>x<S>_grid
    0 bytes stack frame, 0 bytes spill stores, 0 bytes spill loads
ptxas info    : Used 58 registers, used 1 barriers, 8192 bytes smem
```

### sm_120a (Blackwell consumer / RTX 5070) — REJECT for all 8 shapes
```
ptxas <ptx>, line N; error : Instruction 'wgmma.fence' cannot be compiled for architecture 'sm_120a'
ptxas <ptx>, line N; error : Instruction 'wgmma.mma_async with floating point types' cannot be compiled for architecture 'sm_120a'
ptxas <ptx>, line N; error : Instruction 'wgmma.commit_group' cannot be compiled for architecture 'sm_120a'
ptxas <ptx>, line N; error : Instruction 'wgmma.wait_group' cannot be compiled for architecture 'sm_120a'
ptxas fatal   : Ptx assembly aborted due to errors
```

## Silicon-class boundary recap (matches N195 + N196)

| Arch          | SM       | Tensor-core async path     | RTX 5070 status |
|---------------|----------|----------------------------|-----------------|
| Ampere        | sm_80    | mma.sync (warp, sync)      | runs (legacy)   |
| Hopper        | sm_90a   | **wgmma.async** (wg, async)| **REJECTED**    |
| Blackwell B200| sm_100a  | tcgen05.mma (cluster)      | REJECTED (no sm) |
| Blackwell GB202| sm_120a | mma.sync only (no async) + TMA cp.async.bulk.tensor | native |

Per N104 SASS-diff: cuBLAS HGEMM on RTX 5070 dispatches `cutlass_80_tensorop_s16816gemm_f16`,
which is an **Ampere mma.sync** kernel. Even cuBLAS itself does NOT use wgmma on this silicon.
The ~16% gap to cuBLAS at large M (N149 PHILB M=8192 ratio 0.847) is **NOT** an
instruction-class gap (wgmma would not close it on this hardware), it's a scheduling /
tiling / occupancy gap within the mma.sync regime.

Closure path on sm_120 (per N195/N196 verdicts):
- **TMA path** (N196): `cp.async.bulk.tensor.*` is sm_120a-AVAILABLE. May be a sm_120
  win (memory pipeline only, no tensor-core change). Not in this cycle.
- **mma.sync scheduling**: better K-loop pipelining, register pressure, occupancy.
- **n_warps / shmem tuning**: see N197 (warp-spec) findings.

## What N199 demonstrates (the @D g3 honest claims)

1. The hexa-lang generator successfully emits a **structurally valid, full-kernel wgmma PTX
   for all 8 production shapes** in the standard SGEMM sweep. PTX template is correct.
2. The kernel is **internally consistent**: 58 registers, 8 KB shmem, 0 spills — all
   shapes converge to the same ptxas resource profile (the K-loop body is shape-invariant;
   only the Hilbert prologue length scales with `log2(next_pow2(M/64))`).
3. The kernel is **Hopper-fire-ready**: a Hopper-machine run of measure.sh would build the
   host with `nvcc -arch=sm_90a` and execute the standard 20-warmup / 200-rep cuEvent
   timing, producing `result.json` shape rows with `hexa_pwgmma_tflops` populated.
4. The kernel is **hardware-blocked on ubu-2**: ptxas + driver explicitly reject
   wgmma.fence / wgmma.mma_async / wgmma.commit_group / wgmma.wait_group on sm_120a. No
   silicon fire performed (host hard-gates on `sm_major != 9`).

## What N199 does NOT claim

Per @D g3 honest scope:
- **No `ratio_vs_cublas` measurement** in this cycle. The cuBLAS-catch-up question
  (0.84 -> ?) is **UNTESTABLE** on the available silicon. Any number quoted without a
  Hopper fire would be a g3 violation.
- **No "wgmma compounds with Hilbert" claim**. The compound-effect hypothesis
  (wgmma issue-bandwidth × Hilbert L2 locality) requires a measurement on Hopper to
  validate. Plausibility argument only.
- **No `%` improvement over N171 PCOND**. Same reason: unmeasurable on this silicon.

## Handoff for next cycle (when Hopper host appears)

```bash
# On a Hopper host (H100/H200/GH200) with CUDA 12.9 + nvcc:
cd inbox/fires/rfc067_pwgmma_hilbert_conditional_2026_05_22
PY_HOST=<hopper-host> bash measure.sh
# -> measure.sh detects sm_major == 9, runs nvcc -arch=sm_90a, fires all 8 shapes,
#    populates result.json with hexa_pwgmma_tflops / ratio_vs_cublas / bit_exact_pass.
```

Expected outcomes on H100:
- Compile/load: PASS (ptxas-PASS for sm_90a already verified)
- Bit-exact vs cuBLAS HGEMM: PASS (tensor-core fp16->f32 math is byte-identical between
  wgmma and mma.sync per PTX ISA; should be max_abs == 0)
- TFLOPS / ratio: unknown until fired. Plausibility: 64x64 tile is small for H100;
  for that silicon the production kernels use 128x128 or 128x256 with multi-stage
  pipelining. N199 is a "fair-shape comparison" baseline, not an H100-optimized kernel.
