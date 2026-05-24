# Diff: N140 no-swizzle baseline vs N134 4x4 CTA-swizzle (ncu, RTX 5070 sm_120)

Same kernel body (N107 PY 4-warp 64x64 HGEMM), same launch grid `(M/64, M/64)` x 128 threads,
same metric list, same host (`host_one.c`). The ONLY codegen difference is the swizzle PTX's
`(ctaid.x, ctaid.y) -> (sw_x, sw_y)` remap (1 div.u32 + 1 rem.u32 per CTA at entry).

Baseline measured on ubu-1 (N140); swizzle measured on ubu-2 (this cycle). Same RTX 5070
(GB205, 32 MB L2). M=4096 = control (working set < L2 either way -> should not move).

| metric | M | no-swizzle (N140) | swizzle (N134) | delta |
|---|---|---|---|---|
| **L2 hit rate** (lts__t_sector_hit_rate) | 4096 | 98.07% | 98.04% | -0.03 pts (control flat) |
| | **6144** | **56.72%** | **86.94%** | **+30.22 pts** |
| | **8192** | **50.44%** | **87.07%** | **+36.63 pts** |
| **DRAM bytes / launch** (dram__bytes.sum) | 4096 | 127 MB | 123 MB | ~flat |
| | **6144** | **6470 MB** | **1944 MB** | **3.33x less** |
| | **8192** | **17464 MB** | **4486 MB** | **3.89x less** |
| **DRAM bandwidth** | 6144 | 223.9 GB/s (saturated) | 198.9 GB/s | no longer pinned |
| | 8192 | 220.7 GB/s (saturated) | 182.7 GB/s | no longer pinned |
| **DRAM throughput %peak** | 6144 | 33.83% | 30.04% | falls off saturation |
| | 8192 | 33.34% | 27.59% | falls off saturation |
| **Eligible warps / scheduler** | 4096 | 0.33 | 0.34 | control flat |
| | **6144** | **0.10** | **0.33** | **3.3x (back to M=4096 level)** |
| | **8192** | **0.10** | **0.33** | **3.3x (back to M=4096 level)** |
| One/More Eligible (issue-slot %) | 6144 | 6.52% | 18.47% | +11.95 pts |
| | 8192 | 5.63% | 17.38% | +11.75 pts |
| **Warp cycles / issued inst** | 4096 | 41.18 | 40.18 | flat |
| | **6144** | **121.94** | **42.83** | **2.85x less latency** |
| | **8192** | **141.53** | **45.67** | **3.10x less latency** |
| Compute (SM) throughput | 6144 | 14.00% | 39.78% | +25.78 pts (un-starved) |
| | 8192 | 12.16% | 37.54% | +25.38 pts (un-starved) |
| L2 cache throughput (port busy) | 6144 | 32.83% | 91.06% | +58 pts (reuse traffic) |
| | 8192 | 28.52% | 85.38% | +57 pts (reuse traffic) |
| Achieved occupancy | all | 64.9-66.4% | 64.8-66.3% | unchanged (NOT the lever) |
| Inst executed (total) | 8192 | 1987 Minst | 1988 Minst | +0.05% (the div+rem/CTA) |
| GPC cycles elapsed | 6144 | 67.26 Mcyc | 23.82 Mcyc | 2.82x fewer |
| | 8192 | 184.03 Mcyc | 59.78 Mcyc | 3.08x fewer |

## Causal chain (read top-down)

```
4x4 super-block CTA-swizzle
  -> concurrent CTAs share 256x256 output tiles
     -> per-super-block A/B working set ~6 MB << 32 MB L2
        -> L2 HIT RATE   56.72% -> 86.94% @ M=6144   (+30 pts)   [PRIMARY MECHANISM]
           -> DRAM BYTES  6470  -> 1944 MB            (3.33x less)
              -> DRAM un-saturates (223.9 -> 198.9 GB/s, drops below peak)
                 -> memory latency per access drops
                    -> WARP CYCLES/INST  121.9 -> 42.8 cyc   (2.85x)
                       -> ELIGIBLE WARPS  0.10 -> 0.33/sched  (3.3x, = M=4096 healthy level)
                          -> COMPUTE SM   14.0% -> 39.8%      (un-starved)
                             -> GPC CYCLES 67.3 -> 23.8 Mcyc  (2.82x fewer)
                                == real throughput +180% @ M=6144 (N134 result.json)
```

`gpc_cycles` reduction (2.82x @ 6144, 3.08x @ 8192) tracks the N134 end-to-end
throughput recovery (+180% = 2.80x, +218% = 3.18x) almost exactly -- the ncu cycle
count and the wall-clock perf agree.

Occupancy is constant across all shapes/variants (~65%, register-limited to 32/48 warps).
The cliff and its recovery are NOT an occupancy story -- they are a memory-latency /
scheduler-starvation story driven entirely by L2 reuse.
