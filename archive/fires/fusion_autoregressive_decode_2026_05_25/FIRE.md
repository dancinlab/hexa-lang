# F-FUSION-AUTOREGRESSIVE-DECODE — axis E round 8

**Date:** 2026-05-25
**Host:** ubu-2 RTX 5070 (sm_120, driver 580), CUDA 12.0 ptxas
**Verdict:** 🔵 SUPPORTED-FORMAL (structural-formal + projection; timed wall deferred to round 9)

## Workload

Per-token autoregressive decode of one transformer-decoder layer (batch=1,
post-first-token). Shape: GPT-2-small **d=768 · n_heads=12 · head_dim=64 ·
kv_cache_len L=512**.

## Falsifier

`F-FUSION-AUTOREGRESSIVE-DECODE`: a fused hexa-emitted kernel uses
**structurally fewer launches** than PyTorch eager's ≥17 per-token
launches AND projects launch-bound wall reduction ≥30%.

Round 8 = codegen + ptxas-clean + $0 structural oracle; timed silicon
DEFERRED to round 9 (per the axis-E spec).

## Files

- `fused_decode.ptx` — 2 mega-kernels: `decode_attn_fused` + `decode_ffn_fused`.
- `eager_decode.ptx` — 17 per-op kernels modelling PyTorch eager
  (k1 RMSNorm + k2/3/4 Q/K/V proj + k5/6 KV-append + k7 QK + k8 scale +
   k9 softmax + k10 PV + k11 O-proj + k12 residual + k13 RMSNorm +
   k14 FFN-up + k15 SiLU + k16 FFN-down + k17 residual).
- `oracle.hexa` — $0 deterministic structural oracle (compiled hexa, exit 0
  on PASS). Reproduces the launch-count + temp-HBM + closed-form wall
  projection in pure hexa, ☞ 🔵 SUPPORTED-FORMAL anchor.
- `oracle_output.txt` — verbatim stdout from oracle run.
- `ptxas_clean.log` — ptxas RC=0 trace on sm_80 + sm_90; sm_120 via
  driver-JIT (forward-compat, per prior fires).

## Key numbers

| metric | fused | eager | ratio |
|---|---|---|---|
| launches/layer/token | **2** | **17** | 8.5× fewer |
| temp-HBM bytes/layer/token | **0** | **112 656** | 100% eliminated |
| projected launch-bound wall reduction | — | — | **70.6%** |
| compute-saturated floor | — | — | **≥30%** unconditional |
| 12-layer total launches/token | **24** | **204** | 8.5× fewer |
| 12-layer total temp-HBM/token | **0** | **~1.35 MiB** | 100% eliminated |

## ptxas (RC=0)

- `fused.decode_attn_fused`: 32 regs · 40 960 B smem · 0 spill (sm_80/sm_90)
- `fused.decode_ffn_fused` : 27/28 regs · 16 384 B smem · 0 spill (sm_80/sm_90)
- `eager.k1..k17`: 8–26 regs each · 0 smem · 0 spill · all 17 RC=0

Smem 40 960 B fits the sm_80/sm_90 49 152 B per-block envelope; the FFN
mega-kernel fits comfortably. sm_120 (RTX 5070 Blackwell) reached via
`cuModuleLoadDataEx` driver-JIT (same path as `F-FUSION-LAUNCH-AMORT` and
`F-FUSION-ATTN-WMMA` on this host).

## Verdict (g3 dual-axis)

🔵 **SUPPORTED-FORMAL** — structural launch + temp-HBM ratios proven
closed-form via compiled-hexa oracle (exit 0); ptxas-clean on sm_80/sm_90;
closed-form launch-bound projection from MEASURED L=1 µs/launch warm
overhead (`F-RFC067-PB-TIMING`) gives 70.6% wall reduction.

**Verdict framing:**

> "structural launches per token per layer: hexa **2** vs eager **17** —
> vLLM / PyTorch API per-call structure forbids the fusion (every aten op
> is a separate kernel launch); projected launch-bound wall ≥ **70%** above
> eager per-token (round-9 timed silicon will confirm)."

## Round-9 plan

1. Host harness: driver-API `cuLaunchKernel`; warmup 20 + timed 200;
   cudaEvent median + std; GPU-uncontended pre-fire (0% util, no compute
   procs).
2. Numeric: f64 CPU reference; per-row-scaled RMS rel-err ≤ 1e-2 (honest
   metric, avoids the round-3 near-zero false-FAIL artifact).
3. Sweep L ∈ {64, 256, 512, 1024, 2048} on ubu-2 RTX 5070 sm_120; map
   launch-bound → compute-bound transition.
4. Expected wall reduction in [30%, 70%] across L; sharp launch-bound
   regime at small L (~70%), compute floor at large L (≥30%).

## §10

GPU.md §10 adds a new closure row:

> **Axis E — autoregressive single-token fusion (LLM decode) vs PyTorch
> eager** — structural 8.5× fewer launches/layer/token + 100% temp-HBM
> elimination; projected launch-bound wall reduction ≥70%. `[ ]` pending
> round-9 timed silicon confirmation.

Closure scoreboard unchanged at **8/8 ✅** (axis-E adds a new lane, not a
new scoreboard slot).
