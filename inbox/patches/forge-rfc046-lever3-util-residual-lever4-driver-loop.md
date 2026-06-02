# F-RFC046 util-RED residual after lever-3 — the per-step DRIVER LOOP, not the GEMM feed

substrate = GPU · Lane-G (a_lane_akida_gpu_split — NEVER merged with AKIDA) ·
FORGE-UTILGREEN · a_runpod_inbox.

## measurement (g5 verbatim, H100 sm_90, pod vast 39126604, 2026-06-02)

lever-3 (batched transpose-aware GEMM-feed, `cublasDgemmStridedBatched`
`CUBLAS_OP_T`, drop the dominant 65% batched-expert host repack) on the canonical
`stdlib/flame/clm_prod.hexa` trainer, `CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1`,
d=1536 / T=512, c4 5-lang corpus (402270 B, V=256, 32 windows × 2 epochs):

```
F-CLM-PROD-DESCENT = 1   PASS   CE 4.05535 → 3.45564     (🟢 descent GREEN)
F-RFC046-GPU-UTILIZATION  🔴 RED  PEAK=35% MEAN=0.4879% n=6868 busy_mean=5.3445% pct_ge20=0.1019%
byte-eq ALL max|Δ|=0.0  (F-RFC046-GEMMFEED-EQ · F-RFC046-BATCHED-GEMMFEED-EQ · F-CLM-DEVFEED-* · F-CLM-CONV2-BATCHED-*)
3-gate PASS  (CUDA link ENGAGED=1 · nvcc -x cu EXIT 0 660KB obj · clm_prod ldd 4 cuda libs incl libcuda.so.1)
```

## lever-chain progression (forge PROVABLY on GPU each rung: 115W vs 70W idle)

```
lever-1 (im2col→device)    MEAN 0.811%   PEAK  6%
lever-2 (bt/atb GEMM)       MEAN 0.4999%  PEAK 19%
lever-3 (batched bt/atb)    MEAN 0.4879%  PEAK 35%   ← MEAN flat, PEAK up
```

## CLOSED-NEGATIVE diagnosis

The device-feed lever chain (a + b + 2 + 3) is **necessary but insufficient** for
util-GREEN. The 65% batched repack + 31% un-batched repack are now BOTH on device,
byte-eq, and the GPU bursts higher (PEAK 19→35%) — but the MEAN is unchanged
(0.4999→0.4879%). RULED OUT (all closed): CUDA link · kernel · emit · scale · GEMM
host-repack feed.

The util-RED residual is the **interpreted per-step DRIVER LOOP** in `clm_prod`'s
`main`: the `while step <= steps` host loop drives, per step, ~30 host↔device
boundary crossings — the `clm_prod_fwd`/`clm_prod_bwd` host orchestration + the
**20× separate `_adam(...)` calls** (each a host→device→host AdamW round-trip) +
the per-window token gather + the host CE-loss glue. At d=1536 each forge GEMM is
a sub-ms cuBLAS call, so the interpreter's host-side per-step orchestration (one
CPU core, ~tens of ms/step) dominates the wall and SM-starves the GPU between
bursts. busy_mean=5.34% (util WHEN nonzero) confirms the GPU is genuinely idle
~95% of the wall.

## lever-4 (next, the real unblock) — fused on-device per-step driver

Collapse the per-step host orchestration into ONE device-resident step kernel:
- fuse the 20× separate AdamW into ONE batched on-device AdamW over all param
  tensors (single `forge_dispatch_adamw_batched` over a concatenated param/grad/
  m/v view) — drop 20 host round-trips → 1.
- keep fwd/bwd activations device-resident across the step (no per-sublayer D2H/
  H2D); the host loop only advances `step` + feeds the next token window.
- target ~30 → ~2 host↔device boundary crossings/step.
- oracle: `F-RFC046-FUSED-STEP-EQ` max|Δ|=0.0 vs the current per-step path.

Until lever-4, Lane-G stays descent-GREEN / util-RED — NOT PUBLIC-grade,
NOT 3B-throughput-justified. The `.clm` is PRIVATE
(`dancinlab/clm-v1-dev-d1536-lever3-util-probe`).
