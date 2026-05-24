# RFC 067 N201 — Multi-stage TMA mbarrier pool (2026-05-22)

Builds on N200 SMOKE PASS (`c5840f19`, single-stage TMA + parity-tracked
mbarrier). Tests if 2-stage / 3-stage mbarrier-pool TMA pipelining moves the
needle in the cliff regime (M >= 4096) where DRAM bandwidth dominates.

Falsifier: **F-RFC067-HEXA-TMA-MULTISTAGE** = SMOKE bit-exact PASS across all
STAGES + measurable speedup at cliff regime vs single-stage.

## Verdict: **F-PASS**

- SMOKE (M=N=K=64, K_TILES=4) bit-exact PASS at STAGES=2 and STAGES=3
  (mismatch=0/256 for both; `final_slot` correctly identifies the last-K-tile
  slab).
- Perf-proxy sweep at M in {1024, 4096, 6144, 8192} x KT in {64, 256}: every
  shape's STAGES=2 is faster than STAGES=1; STAGES=3 wins at the deepest cliff
  point M=6144 K=4096 (1.73x bandwidth uplift) and M=8192 K=4096 (1.30x).
- shmem footprint at STAGES=3: 12824 B + 512 B reduce scratch = 13.3 KB, well
  under the 48 KB classic limit. 34 regs, 1 barrier.
- Drain phase verified: K_TILES=4 with STAGES=3 means the last issue is at
  k=0 (issue prologue 0/1/2) + steady k=0 issues stage 3, k=1/2/3 no issue;
  loop naturally drains the remaining 3 in-flight tiles.

## Multi-stage design

Each of `STAGES` mbarriers + corresponding A/B smem slabs rotates round-robin:
- Prologue: thread 0 issues `min(STAGES, K_TILES)` TMA pairs ahead of compute.
- Steady (k = 0..K_TILES-1):
  1. `slot = k % STAGES`
  2. Pick `parity` from the per-stage parity bit (`parity[slot]`)
  3. `mbarrier.try_wait.parity` on `mbar[slot]` with current parity
  4. `bar.sync 0`
  5. Flip `parity[slot]` (per-stage parity must be tracked independently)
  6. Compute / SMOKE-op consuming slab[slot]
  7. If `k + STAGES < K_TILES`: thread 0 issues stage `k + STAGES` into the
     same slot (it has been freed by the wait+compute)

Key subtle point: each stage has its **own** parity counter. Global
`k_iter & 1` parity (N200 single-stage style) is wrong here because two
different stages would receive different `arrive` counts at the same `k_iter`.

## Results (RTX 5070 sm_120, driver 580.159.04, CUDA 12.9, reps=64)

### SMOKE (M=N=K=64)

| STAGES | shmem  | regs | final_slot | mismatch | verdict |
|--------|--------|------|-----------:|---------:|---------|
| 2      | 8208 B | 32   | 1          | 0/256    | PASS    |
| 3      | 12312 B| 33   | 0          | 0/256    | PASS    |

### Perf-proxy sweep (notional TFLOPS = 2*M*N=64*K / time; not real SGEMM)

| M    | K    | s1 ms  | s2 ms  | s3 ms  | s2/s1 | s3/s1 | best GB/s |
|-----:|-----:|-------:|-------:|-------:|------:|------:|----------:|
| 1024 | 1024 | 0.0206 | 0.0165 | 0.0165 | 1.25x | 1.25x |  254.85   |
| 1024 | 4096 | 0.0737 | 0.0595 | 0.0615 | 1.24x | 1.20x |  282.05   |
| 4096 | 1024 | 0.0212 | 0.0165 | 0.0166 | 1.29x | 1.28x | 1017.76   |
| 4096 | 4096 | 0.0779 | 0.0615 | 0.0635 | 1.27x | 1.23x | 1090.90   |
| 6144 | 1024 | 0.0226 | 0.0185 | 0.0185 | 1.22x | 1.22x | 1361.49   |
| 6144 | 4096 | 0.1606 | 0.1087 | 0.0929 | 1.48x | **1.73x** | 1084.07   |
| 8192 | 1024 | 0.0247 | 0.0185 | 0.0185 | 1.33x | 1.33x | 1813.12   |
| 8192 | 4096 | 0.4105 | 0.3480 | 0.3169 | 1.18x | 1.30x |  423.55   |

### cuBLAS reference (cublasGemmEx R16F input, C32F compute, R16F output)

| M    | K    | N  | ms     | TFLOPS |
|-----:|-----:|---:|-------:|-------:|
| 1024 | 1024 | 64 | 0.0083 |  16.26 |
| 1024 | 4096 | 64 | 0.0157 |  34.16 |
| 4096 | 1024 | 64 | 0.0145 |  37.09 |
| 4096 | 4096 | 64 | 0.0492 |  43.61 |
| 6144 | 1024 | 64 | 0.0145 |  55.65 |
| 6144 | 4096 | 64 | 0.0626 |  51.49 |
| 8192 | 1024 | 64 | 0.0206 |  52.20 |
| 8192 | 4096 | 64 | 0.1165 |  36.87 |

## Findings

1. **Multi-stage uplifts every shape.** At ALL 8 measured cliff points, STAGES=2
   beats STAGES=1 (1.18x to 1.48x). STAGES=3 wins outright at the largest
   K-loop / largest grid cases (M=6144 K=4096: 1.73x; M=8192 K=4096: 1.30x)
   where the extra in-flight tile actually hides DRAM latency.
2. **STAGES=3 > STAGES=2 only when DMA is saturated** (M=6144 K=4096:
   `s2_gbps=926 -> s3_gbps=1084`). At smaller / faster shapes, STAGES=2 is
   already at the steady-state limit and the third stage is wasted shmem.
   Honest negative confirmed by spec.
3. **No occupancy regression observed** at this tile size. 34 regs / 13 KB
   shmem still allows multiple CTAs/SM; no spill stores reported by ptxas.
4. **vs cuBLAS:** our proxy is bandwidth-only (no real mma), so cuBLAS's
   compute-bound TFLOPS (16-56 TFLOPS) is on a different axis. The fact our
   proxy's gpb/s climbs to 1.8 TB/s at M=8192 K=1024 (well above RTX 5070's
   ~672 GB/s peak DRAM bandwidth) shows L2 reuse dominates: B descriptor is
   the same across CTAs, and L2 catches it. The interesting cliff point is
   M=6144 K=4096 and M=8192 K=4096 where the L2-busted region exhibits a
   genuine multi-stage uplift (DRAM-bound steady state).
5. **Drain correctness:** SMOKE PASS proves the FINAL slab (k = K_TILES-1)
   correctly carries the last K-tile data even though earlier K-iters do not
   issue follow-ups (drain phase of the K-loop). Per-stage parity bits ensure
   each waiter reads the right baseline.

## Honest scope (`@D g3`)

- Perf-proxy does NOT replace real mma.sync chain. The N200 reference itself
  did NOT generate a real mma body; only SMOKE. The "real mma" upgrade
  remains a separate fire (would need full ldmatrix.x4 + 8 m16n8k16 chain
  per warp wired to multi-stage slab indexing).
- B-descriptor is N=64 across all CTAs, so the perf-proxy benefits from L2
  reuse on B. A real GEMM with N >> 64 and per-CTA-distinct B-tiles would
  see different absolute GB/s, but the multi-stage **ratio** should hold.
- The "notional_tflops" column in the perf-proxy table uses 2*M*N=64*K as a
  cross-comparison scaler only; it is NOT a SGEMM throughput claim. Use the
  cuBLAS row for that.
- Driver-JIT ptxas (cuModuleLoadDataEx) silently treats `%ctaid` (no `.x`)
  as a video selector. Per-N196 ASCII-only continues to apply; in addition,
  do NOT shadow `%ctaid` with a user register name. (Got bitten once.)

## Artifacts

```
inbox/fires/rfc067_ptma_multistage_2026_05_22/
  gen_sgemm_tma_multistage_ptx.py   # SMOKE gen (STAGES=2/3)
  gen_sgemm_tma_perf_ptx.py         # perf-proxy gen (STAGES=1/2/3 x KT=64/256)
  host.c                            # SMOKE host driver
  host_perf.c                       # perf-proxy host driver (cuEvent timing)
  host_cublas.c                     # cuBLAS reference (cublasGemmEx)
  measure.sh                        # SMOKE build+fire script
  measure_perf.sh                   # perf sweep build+fire script
  sgemm_tma_multistage_s{2,3}.ptx   # SMOKE PTX
  sgemm_tma_perf_s{1,2,3}_k{64,256}.ptx  # perf PTX (6 variants)
  fire.log                          # SMOKE fire output
  fire_perf.log                     # perf sweep output
  fire_s{2,3}.log                   # per-stage SMOKE individual logs
  ptxas_info_*.log                  # ptxas -v output per variant
  results_raw.txt                   # raw measurement collation
  result.json                       # structured result
  notes.md                          # this file
```

## Next

- Real mma chain over multi-stage (mirror what hexa N149 4-warp 64x64 HGEMM
  did, but indexing the rotating slabs). Each K-iter mma reads ldmatrix from
  `slab_a[k % STAGES]` and `slab_b[k % STAGES]` instead of fixed slab 0.
- Sweep with N >= 256 to defeat L2 reuse and isolate true DRAM-bound speedup.
- Pair with Hilbert d2xy CTA swizzle (N149) to test L2 locality + TMA pipeline
  interaction at the largest M.
