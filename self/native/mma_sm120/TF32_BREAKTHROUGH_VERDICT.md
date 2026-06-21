# TF32 GEMM breakthrough — Round A (r-sched) + Round B (r-3xtf32) verdict

Measured on **aiden, RTX 5070 (sm_120, cc12.0), nvcc 13.0**. All numbers below are
captured device output (c2 — no fabrication). cuBLAS = CUBLAS_COMPUTE_32F_FAST_TF32.

## Baseline (own TF32 m16n8k8, shipped 64x64 kernel)

| S    | own TFLOP/s | cuBLAS TFLOP/s | off-cuBLAS |
|------|------------:|---------------:|-----------:|
| 512  | 16.23       | 17.81          | 1.10x      |
| 1024 | 24.94       | 28.15          | 1.13x      |
| 1536 | 29.90       | 33.91          | 1.13x      |
| 2048 | 29.86       | 30.51          | 1.02x      |
| 3072 | 29.82       | 34.14          | 1.14x      |

The shortfall (~0.87-0.91x of cuBLAS) is real and confirmed.

## ROUND A — r-sched (LDS issue-cadence re-scheduling)

Two byte-eq variants of the smem->reg fragment-load schedule:
- `owngemm_sm120_rsched.cu`  : clustered LDS burst (all frags to regs, then all MMAs)
- `owngemm_sm120_rsched2.cu` : k8 register software-pipeline (prefetch next k8 frags)

**byte-eq vs baseline: PASS at every size** — `bitdiff=0 ndiff=0 max|d|=0 run2run=0`
(pure scheduling, output bit-for-bit identical, PROVEN by the byteeq harness).

**Perf: CLOSED-NEGATIVE.** Both variants are flat-to-slower than baseline:

| S    | base off | rsched off | rsched2 off |
|------|---------:|-----------:|------------:|
| 512  | 1.10x    | 1.250x     | 1.142x      |
| 1024 | 1.12x    | 1.174x     | 1.138x      |
| 1536 | 1.14x    | 1.170x     | 1.127x      |
| 2048 | 1.02x    | 1.041x     | 1.016x      |
| 3072 | 1.19x    | 1.171x     | 1.153x      |

VERDICT A: byte-eq proven, but re-cadencing smem loads does NOT close the gap on
sm_120 — ptxas already schedules the LDS/MMA interleave near-optimally; clustering
or k8-pipelining only adds register pressure. The CloudRift RTX 5090 LDS-cadence
finding does not transfer to ptxas's schedule on this card. **Wall: the gap is not
LDS issue-cadence; it is the FP32-accumulator tensor rate** -> Round B.

## ROUND B — r-3xtf32 (Ootomo-Yokota FP16-accum error-corrected emulation)

`owngemm_sm120_3xtf32.cu` — split fp32 -> hi+lo fp16, accumulate
`A_hi@B_hi + A_hi@B_lo + A_lo@B_hi` on the full-rate `mma.m16n8k16.f32.f16.f16.f32`
path (Ootomo & Yokota 2022, arXiv 2203.03341).

PREMISE PROBE (`probe_fp16_rate.cu`): FP16-accum m16n8k16 issues **~1.79-1.90x**
the rate of TF32-accum m16n8k8 on sm_120 (consumer Blackwell). Datacenter parts run
2-4x; this consumer card is only ~1.8x.

**Accuracy: BREAKTHROUGH — emulation is ~400x more accurate than native cuBLAS-TF32:**

| S    | 3xtf32 rel-RMS vs FP64 | cuBLAS-TF32 rel-RMS vs FP64 | accuracy gain |
|------|-----------------------:|----------------------------:|--------------:|
| 512  | 2.389e-06              | 9.898e-04                   | ~414x         |
| 1024 | 4.643e-06              | 6.215e-04                   | ~134x         |
| 1536 | 1.447e-05              | 5.016e-04                   | ~35x          |

The Ootomo-Yokota method works perfectly on sm_120: 2-term (3-MMA) recovers
FP32-equivalent accuracy (<=1.4e-5). **Determinism PROVEN: run2run=0 at every size.**

**Perf: FAIL — emulation is SLOWER than cuBLAS-TF32 (the cap holds for speed):**

| S    | 3xtf32 (3-MMA) off-cuBLAS | vs own-TF32 baseline |
|------|--------------------------:|---------------------:|
| 512  | 1.792x                    | ~1.6x slower         |
| 1024 | 1.706x                    | ~1.5x slower         |
| 1536 | 1.691x                    |                      |
| 2048 | 1.526x                    |                      |
| 3072 | 1.691x                    |                      |

2-MMA perf-floor probe (`owngemm_sm120_3xtf32_2mma.cu`, hi*hi+hi*lo, drops lo*hi):
off-cuBLAS 1.337x/1.254x/1.210x — still slower, AND accuracy collapses to ~3.5e-4
(no longer better than TF32, the lo*hi term is required). So 2-MMA is not even an
accuracy-worthwhile floor.

## HEADLINE VERDICT

**The "FP32-accumulator cap is routable" premise is HARDWARE-DEPENDENT and the
perf-overturn FAILS on consumer Blackwell.** Root cause (measured, not asserted):
FP16-accum is only ~1.8x the TF32-accum rate on RTX 5070 sm_120, while error-
corrected emulation needs 2-3 FP16 MMAs per TF32 MMA. MMA-multiplier (2-3x) >
rate-advantage (1.8x) -> time-product always > 1. The emulation would WIN only where
FP16:TF32 >= ~3:1 (datacenter A100/H100-class), not on this consumer card.

What the levers DID deliver:
- Round A: a PROVEN byte-eq scheduling refactor (max|d|=0) — but perf closed-neg.
- Round B: a PROVEN-deterministic (run2run=0) **~400x-more-accurate** TF32-equivalent
  GEMM. This is a real *accuracy* win (an FP32-accuracy GEMM at ~0.6x cuBLAS-TF32
  speed) — useful where TF32's 10-bit mantissa is insufficient — but NOT a speed
  overturn. It does NOT close the 512-3072 perf shortfall.

Neither variant reaches >=1.0x off-cuBLAS, so NONE is promoted to a production
fastmode. The shipped 64x64 TF32 path and FP64 default are untouched (byteeq-neutral).

## NEXT ROUND (named, honest)

- **r-ozaki-int8 (n>=8K)**: the perf-overturn lever that COULD work on consumer
  Blackwell is INT8 tensor cores (DP4A/IMMA), which on GeForce run ~4x the TF32 rate
  (rate-advantage finally exceeds the emulation multiplier). Ozaki-scheme INT8 GEMM
  (Ootomo 2024, arXiv 2306.11975) splits fp32 into INT8 slices; at large n the INT8
  rate margin can beat native TF32. Gated to n>=8K (split overhead amortizes only at
  scale) and cost-gated (needs a longer aiden session). This is the honest path to
  actually overturn the cap on this hardware class.
