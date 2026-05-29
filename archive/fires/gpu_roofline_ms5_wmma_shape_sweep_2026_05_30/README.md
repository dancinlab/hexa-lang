# GPU-ROOFLINE MS#5 — forge/hexa WMMA variable-shape roofline sweep

ubu-2 RTX 5070 sm_120 (driver 580.159.03 / 13000, CUDA runtime 12000), 2026-05-30, $0 LAN fire.

## What

Shape sweep M=N=K ∈ {128, 256, 512, 1024} of the hexa-emit WMMA HGEMM kernel vs
cuBLAS GemmEx (f16 in, f32 accumulate, tensor-op) at the **same** shape, with a
per-shape **byte-eq numeric check** (hexa WMMA output vs CPU FP64 reference,
`max|Δ|`). Median of 200 timed launches (20 warmup, `cudaEventRecord` per-launch sync).

## Kernels

- `wmma_256x256_grid` — **compiler-emitted** (PR #214, RFC 067 P-perf). 256×256
  shape-locked. This is the only shape the hexa compiler (`nvptx_target.hexa`) emits;
  variable-shape emission is MS#1 (multi-session codegen).
- `wmma_512x512_grid`, `wmma_1024x1024_grid` — **hand-emit shape-ports** (pD, N4 fire
  2026-05-21). Same per-warp WMMA microcode as the 256 kernel; only address-arithmetic
  constants + stride operands scale with S. Numeric correctness inherits from the
  256 microcode (and is re-confirmed here: max|Δ|=0).
- `wmma_128x128_grid` — **hand-emit shape-port** (this fire, same method). 2×2 grid of
  64×64-output blocks, 16 warps/block, k_tiles=8.

## Verbatim result (`ms5_fire.log`)

```
[S=128]  cuBLAS 0.7756 TF | hexa 0.7710 TF | ratio=0.9941 | max|d|=0
[S=256]  cuBLAS 4.4620 TF | hexa 3.5069 TF | ratio=0.7860 | max|d|=0
[S=512]  cuBLAS 23.0456 TF| hexa 10.3308 TF| ratio=0.4483 | max|d|=0
[S=1024] cuBLAS 53.2610 TF| hexa 15.5561 TF| ratio=0.2921 | max|d|=0  (corner 64x64 CPU-ref)
```

## Finding

**ratio 0.767 is strongly shape-dependent** — monotonic degradation
0.994 → 0.786 → 0.448 → 0.292 as M grows. At M=128 hexa is at parity with cuBLAS
(both launch-bound on a tiny problem); the SMEM-tile-absent naive K-loop loses ground
as the problem becomes compute/bandwidth-bound at larger M (matches N4 curve
0.767/0.417/0.287 within run-to-run drift). Adds the **byte-eq numeric gate** the
timing-only N4 fire lacked: **max|Δ|=0 at every shape**.

Honest scope: only M=256 is compiler-emitted (256-locked, MS#1 dependency); the other
three shapes are hand-emit ports of the identical WMMA microcode. cuBLAS scales with M
while the single-buffered hexa kernel does not — "못 이김 ≠ 실패", the gap is the
documented SMEM-operand-tiling absence (MS#6 CLOSED-NEGATIVE forge-lane).
