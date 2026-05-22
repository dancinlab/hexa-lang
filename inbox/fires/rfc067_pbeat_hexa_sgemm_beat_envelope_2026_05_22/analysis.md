# RFC 067 PBEAT -- cuBLAS-BEAT envelope boundary determination

**Date:** 2026-05-22  **Host:** ubu-2 (RTX 5070, sm_120, driver 580.159.03 / CUDA driver=13000, runtime=12000)
**Falsifier:** F-RFC067-CUBLAS-BEAT-ENVELOPE
**Protocol:** 20 warmup + 200 timed reps, `cudaEventRecord` per-launch with sync each iter, median TFLOPS.
Run **3x** (r1/r2/r3) to capture small-M cuBLAS launch-bound variance. Both variants share the
exact N121/N107 kernel body (PTX bodies verified byte-identical to source artifacts for the
shared 256/384/512 shapes; only header comments differ).

## Question

N121 (4-warp 64x64 + 6-stage) earlier found M=256 BEAT (ratio 1.1611) but M=512 not (0.877).
Where exactly does the BEAT envelope end? Sweep M = 192/256/320/384/448/512 (all 64-aligned)
on BOTH the N121 (6-stage) and N107 (2-stage swizzle) kernels.

## Per-shape table (median of 3 runs; min/max in parens)

| M   | CTAs | cuBLAS TFLOPS | N121 ratio (min,max)      | N107 ratio (min,max)      | best (variant)         | BEAT |
|-----|------|---------------|---------------------------|---------------------------|------------------------|------|
| 192 |   9  |   3.030       | 0.906 (0.893, 0.910)      | 0.890 (0.879, 0.915)      | 0.906 (N121)           | no   |
| 256 |  16  |   4.993       | **1.085** (1.083, 1.151)  | **1.085** (1.058, 1.088)  | **1.085** (N121)       | YES  |
| 320 |  25  |   9.776       | **1.042** (1.037, 1.042)  | 0.938 (0.925, 0.998)      | **1.042** (N121)       | YES  |
| 384 |  36  |  16.852       | 0.952 (0.938, 1.027)      | 0.838 (0.822, 0.868)      | 0.952 (N121)           | no*  |
| 448 |  49  |  16.701       | **1.017** (0.983, 1.018)  | **1.017** (1.015, 1.024)  | **1.017** (N121=N107)  | YES  |
| 512 |  64  |  24.818       | 0.911 (0.888, 0.911)      | 0.911 (0.908, 0.914)      | 0.911                  | no   |

\* M=384 median 0.952 (below 1.0) but N121 crossed 1.027 in one of three runs (r3) -- a genuine
straddle of the 1.0 line; it is launch-noise-borderline, not a clean BEAT.

Bit-exact: **maxabs = 0.0000 for ALL shapes, BOTH variants, ALL 3 runs** -> F-RFC067-CUBLAS-BEAT-ENVELOPE numeric PASS.

## BEAT boundary

**Last M with median best-ratio > 1.0 = M = 448** (consistent across all 3 runs:
each individual run also reported beat_boundary_M = 448).

But the envelope is **NON-CONTIGUOUS / non-monotonic**, which is the headline finding:

- 192: lose (0.91)
- 256: **BEAT** (1.085)
- 320: **BEAT, N121 only** (1.042; N107 dips to 0.938)
- 384: lose (0.952 median; N121 straddles 1.0)
- 448: **BEAT again** (1.017, both variants)
- 512: lose (0.911)

So the contiguous "small-shape win zone" is **M in {256, 320}** (N121 wins both, N107 wins
only 256). The M=448 BEAT is a SEPARATE, RE-OPENED window.

## Why the envelope is non-monotonic (the under-subscribed-grid story)

This is a cuBLAS-overhead-bound regime, NOT a hexa compute-bound signal. The cuBLAS HGEMM
TFLOPS column shows the mechanism directly:

- cuBLAS at M=384 hits **16.85 TFLOPS** but at M=448 DROPS to **16.70 TFLOPS** -- absolute
  throughput goes DOWN as the problem gets bigger. cuBLAS heuristically picks a
  launch-light kernel here that under-utilizes the 40-SM RTX 5070 grid. cuBLAS median ms is
  actually flat at ~0.0067 ms for M=256/320/384 and only jumps to ~0.0108 ms at M=448/512:
  cuBLAS is paying a near-constant launch/dispatch floor across 256-384, so its measured
  TFLOPS rises purely because the FLOP count grows under a fixed wall-time floor.
- hexa's 64x64-tile kernels scale their grid smoothly (CTAs = (M/64)^2: 9/16/25/36/49/64).
  Where cuBLAS's launch heuristic leaves SMs idle (M=256, 320, and again 448), the
  smaller-tile hexa kernel's denser grid wins. At M=512 cuBLAS finally engages a
  compute-bound kernel (24.8 TFLOPS, +49% over M=448) and hexa loses cleanly.

The M=448 re-cross is therefore a real, reproducible artifact of cuBLAS's kernel-selection
heuristic, not measurement noise (all 3 runs agree N107 1.015-1.024, N121 0.983-1.018).

## Best-variant-per-shape

- N121 (6-stage) is the better hexa variant at M=256, 320, 384, and ties at 448/512.
- N107 (swizzle) only matches/edges N121 at M=256 and M=448; it is notably worse at
  320 (0.94 vs 1.04) and 384 (0.84 vs 0.95). The 6-stage pipeline's deeper latency
  hiding helps in the small-grid regime where occupancy is low.
- Net: **N121 (6-stage) is the recommended kernel across the whole envelope.**

## Honest scope (@D g3)

- These BEAT shapes are NOT compute-bound wins. They map WHERE cuBLAS leaves the RTX 5070
  grid under-subscribed; the relevance is small-shape inference (M <= ~320 GEMM, e.g. small
  batch / single-token decode projections), where hexa's denser small-tile grid wins.
- Small-M cuBLAS timing is launch-bound and noisy: M=256 N121 ratio ranged 1.083-1.151
  across the 3 runs. The median (1.085) is the honest point estimate.
- The envelope's contiguous win zone is M in [256, 320]. The M=448 BEAT is a separate
  re-opened window caused by a cuBLAS heuristic dip and should be reported as such, not as
  "hexa beats cuBLAS up to 448" without the non-monotonicity caveat.
- Compute-bound boundary (where cuBLAS decisively wins) starts at M=512 and widens with M
  (prior N121 large-shape data: M=768 ratio 0.84, M=1536 ratio 0.76).

## Verification summary

- Bit-exact PASS all 6 shapes x 2 variants x 3 runs (max_abs = 0).
- F-RFC067-CUBLAS-BEAT-ENVELOPE PASS.
- BEAT boundary identified: **last M with ratio > 1.0 is M=448** (envelope non-contiguous;
  contiguous win zone M in {256, 320}).
- Per-shape table above: M / cuBLAS / N121 / N107 / best ratio.

## Infra note

ubu-2 had a transient NVIDIA driver/library version mismatch at fire start (loaded kmod
580.126.09 vs userspace libcuda 580.159.03 -> cuInit FAIL). Resolved by reloading the
NVIDIA kernel modules (rmmod + modprobe to the on-disk DKMS 580.159.03) -- no reboot, no
GPU processes were holding the modules. GPU healthy after reload.
