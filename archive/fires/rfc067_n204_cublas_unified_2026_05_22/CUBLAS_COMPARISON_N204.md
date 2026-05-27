# N204 SWIZZLE_128B — unified cuBLAS comparison on RTX 5070 sm_120 (2026-05-22)

Single ubu-2 session, full M=512..8192, **N204 production kernel** (TMA + mma.sync + SWIZZLE_128B + matched ldmatrix). Bit-exact every shape (maxabs=0).

| M | hexa TFLOPS | cuBLAS TFLOPS | ratio | regs | shmem |
|------|-------------|---------------|-------|------|-------|
|  512 | 23.24       | 23.24         | **1.0000** ← PARITY | 66 | 16400 B |
| 1024 | 48.42       | 53.35         | 0.9076 | 66 | 16400 B |
| 2048 | 63.73       | 66.77         | 0.9545 | 66 | 16400 B |
| 4096 | 68.04       | 70.02         | **0.9717** | 66 | 16400 B |
| 6144 | 68.83       | 70.78         | **0.9725** | 66 | 16400 B |
| 8192 | 69.24       | 70.81         | **0.9778** | 66 | 16400 B |

## Comparison vs prior canonical kernels

| Kernel | M=8192 ratio | Notes |
|---|---|---|
| N38 baseline (mma.sync naive) | 0.263 | starting point |
| N149 Hilbert (cp.async + 4-warp + Hilbert) | 0.847 | previous best, cliff-flattened |
| N171 conditional (production single kernel) | 0.844 | identity small-M + Hilbert large-M |
| N200-full (TMA + mma SWIZZLE_NONE) | 0.819 | TMA sidesteps L2 cliff |
| N203 (TMA multi-stage + mma) | 0.8434 | DMA pipelining marginal |
| N205 (TMA + producer/consumer warp-spec) | 0.8381 | decoupling compensates occupancy |
| **N204 (TMA + SWIZZLE_128B + matched ldmatrix)** | **0.9778** | **🛸🛸🛸🛸🛸 cuBLAS PARITY** |

## Cumulative single-session progression
0.263 → 0.30 → 0.46 → 0.78 → 0.847 → 0.819 → 0.844 → 0.8434 → 0.8381 → **0.9778 at M=8192**
**+71.5 pp in single session, all bit-exact, hexa-native PTX.**

## Recipe (consumer Blackwell sm_120 cuBLAS catch-up)
- mma.sync.aligned.row.col.m16n8k16.f32.f16 (Ampere mma — wgmma impossible on sm_120 per N195)
- TMA `cp.async.bulk.tensor.2d` with `CU_TENSOR_MAP_SWIZZLE_128B`
- Matched ldmatrix swizzled addressing: `byte_offset = m*128 + (atom_k XOR (m & 7)) * 16 + (k_fp16 % 8) * 2` (CUTLASS Sw<3,4,3>)
- K_TILE_INNER=64 (128B box innermost, required by SWIZZLE_128B)
- Mbarrier parity-tracked per K-iter (and.b32 %parity, %k_iter, 1)
- 4-warp 64×64 tile, 8 mma.m16n8k16/warp/K-step
- Hilbert d2xy CTA-swizzle (unchanged from N149)
- `.target sm_120a` + `.version 8.7` (forward-compat from sm_90a does NOT work per N196)
- PTX pure-ASCII (driver-JIT requirement)

## Honest scope (`@D g3`)
- M=512 PARITY (1.0000) is run-to-run noise on this fire (small-shape launch-bound); N204 first fire was 0.992; cuBLAS itself fluctuates ±0.5% at small M
- 0.9778 at M=8192 = honest large-M catch-up
- N204 commit confound: SWIZZLE_128B requires K_TILE 16→64 widening (both bank-conflict elimination + TMA setup amortization contribute). Cleanly decomposing needs intermediate SWIZZLE_NONE+wide-box measurement.
- cuBLAS uses Ampere mma.sync on sm_120 (per N104 SASS-diff), NOT wgmma. Same instruction class as hexa.
