# hexa-forge-util-fix — forge cuBLAS conv dispatch left the H100 at 0% util

**Status:** fix landed (PR to hexa-lang); util re-check on real H100 — see "Before/after util" below.
**Owner:** anima Lane G (F-RFC046 host-backward bottleneck).
**Repo:** hexa-lang. **Branch:** `feat/hexa-forge-util-fix`.

## Symptom (Lane G, real H100)

A `clm_prod` / dojo `job.hexa` (forge=cuBLAS, d768/12L) training run left the H100 at
**0% GPU utilization** — 1335 nvidia-smi samples, **PEAK=0% MEAN=0.00%** — while CE still
descended 4.90 → 0.98. The trainer learned **entirely on host-side scalar work**; the GPU
contributed nothing. This is worse than the prior F-RFC046 "util 1-4% RED".

## Root cause (pinned)

The forge conv path is already wired to GEMM:

- `stdlib/flame/clm_conv_gpu.hexa` (and the dojo `job.hexa` copy):
  - `conv1d_via_forge` (fwd) — im2col, then `forge_dispatch_matmul(xcol, T, Kdim, Wt, Cout)`.
  - `conv1d_bwd_via_forge` (bwd) — two GEMMs `forge_dispatch_matmul(...)` for dW and dX, then col2im.

Both route through `forge_dispatch_matmul` → `hexa_forge_dispatch_matmul` (codegen
`self/codegen.hexa:7438`) → `forge_tier_dispatch_v1` → **`_forge_dispatch_matmul_fp64`**
(`self/forge/forge_tier_v1_emit.hexa`, the SSOT that emits the gitignored
`self/forge/forge_tier_v1.c` that `runtime.c` `#include`s).

`_forge_dispatch_matmul_fp64` delegated the live FP64 GEMM to **`hexa_farr_matmul`** — the
**RFC 032 CPU-only baseline**. The cuBLAS Dgemm path (`_hx_cuda_farr_matmul_gpu`,
`self/cuda/runtime_cuda_emit.hexa:611`, `cublasDgemm` at line 661) is **only reachable
through `hexa_farr_matmul_gpu`** (RFC 040). So every conv→GEMM — forward AND backward —
ran on the CPU even on a CUDA host. Result: GPU idle (0% util), host does all the FLOPs,
CE still descends because the CPU FP64 path is numerically correct.

This is NOT primarily tiny-GEMM under-saturation: at d768 the conv GEMM is
`[24, 2304] @ [2304, 768]` (embed/trunk/experts) — a substantial Dgemm. The dominant
cause is the dispatch target: CPU baseline instead of the cuBLAS wrapper. (At the
`clm_prod.hexa` toy default d=8 the GEMM is genuinely tiny `[24,24]@[24,8]` and would not
saturate even on cuBLAS — but the d768 fire is the throughput-gating case.)

## Fix

`self/forge/forge_tier_v1_emit.hexa`, `_forge_dispatch_matmul_fp64`: route the live FP64
MATMUL to **`hexa_farr_matmul_gpu`** instead of `hexa_farr_matmul`.

- On a CUDA host, `hexa_farr_matmul_gpu` runs cuBLAS Dgemm (`_hx_cuda_farr_matmul_gpu`).
- On a no-CUDA host, it falls back to the byte-identical RFC 032 CPU `farr_matmul`
  (RFC 040 Phase A contract) — Mac/dev behavior unchanged.
- Defensive CPU fallback if the GPU handle is negative (RFC 050 §6.6 no-crash mandate).

Both `conv1d_via_forge` (fwd) and `conv1d_bwd_via_forge` (bwd) ride this one FP64 MATMUL
dispatch, so a single fix moves both onto cuBLAS. FP64 Dgemm is the same math as the CPU
FP64 reference (within the flame 1e-9 conv tol), so #2352 (fwd) / #2383 (bwd grad-exact)
byte-eq are preserved.

## Deploy note

`self/forge/forge_tier_v1.c` is a **gitignored generated artifact** (regen via
`tool/regen_dispatch_c_artifacts.hexa` from the emit `.hexa`). The released
`install.sh` tarball bakes the OLD dispatch into the prebuilt binary; to get the fix live
on a pod you must **rebuild hexa from this branch** (regen the dispatch `.c` from the emit,
then `hexa cc`), not just `install.sh` the prebuilt tarball. See
`tool/forge_util_fix_remote.sh` for the A/B profiling + rebuild recipe.

## Before/after util (real H100, nvidia-smi verbatim)

<!-- FILLED FROM THE LIVE PROFILE RUN -->
- BASELINE (released binary, CPU dispatch): _pending_
- FIXED (from-branch rebuild, cuBLAS dispatch): _pending_
- byte-eq re-check (conv fwd+bwd selftest): _pending_

## hexa verify / parse

- `hexa parse self/forge/forge_tier_v1_emit.hexa` → `OK: ... parses cleanly`.
- Emitted `forge_tier_v1.c` compiles (`clang -fsyntax-only`).
