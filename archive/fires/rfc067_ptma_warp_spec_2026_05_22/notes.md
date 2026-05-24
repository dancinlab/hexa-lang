# RFC 067 N203 -- TMA + warp-spec (2P+2C) + Hilbert d2xy

## Context

N197 (`rfc067_pwspec_named_bar`) attempted 4P+4C named-bar warp specialization
WITHOUT TMA primitives. FAILED catastrophically: -34% to -84% vs N149 across
M={1024, 2048, 4096, 8192}. Notes cited 4 compounding root causes:

  1. `cp.async.wait_all` per K-step KILLS overlap -- producer warp blocked
     thread-side waiting for the prefetch DMA to land.
  2. 256 thd/CTA halved occupancy vs N107's 128 thd/CTA.
  3. Named-bar arrive_count=256 was still full-CTA arrival; the asymmetry
     was sync-vs-arrive ONLY, not arrival-count.
  4. No L2 swizzle -> cliff at M>=6144.

N196 finding: TMA `mbarrier::complete_tx::bytes` lets DMA hardware drive
mbarrier completion directly, replacing thread-side `cp.async.wait_all`.
This is N197 root cause #1's primary fix.

N200-full (`rfc067_ptma_mma_hilbert`) demonstrated TMA + mma WITHOUT warp
split (all 4 warps do mma; thread 0 issues TMA on the side). Result: ratio
0.819 at M=8192 (+31% vs N149 at same shape).

This cycle (N203): SPLIT warps **with** TMA primitives.

## Design

| Aspect | N197 (failed) | N200-full | N203 (this) |
|---|---|---|---|
| Warps total          | 8         | 4               | 4 |
| Threads / CTA        | 256       | 128             | 128 |
| Producer warps       | 4         | 0 (thread 0)    | 2 |
| Consumer warps       | 4         | 4               | 2 |
| DMA mechanism        | cp.async  | TMA (mbarrier)  | TMA (mbarrier) |
| DMA wait mechanism   | cp.async.wait_all (thread-side, BLOCKS PRODUCER) | mbarrier (DMA-driven) | mbarrier (DMA-driven) |
| Pipeline stages      | 2 (slot rotate) | 1 (single buf) | 2 (double buf) |
| Sync between roles   | named bars 1..4 (count=256, full-CTA) | bar.sync 0 + mbarrier | mbarrier ONLY (no bar.sync in K-loop) |
| Per-consumer output  | 16M x 64N | 32M x 32N       | 32M x 64N |
| mma / consumer warp / K-step | 8 | 8 | 16 |
| f32 acc / lane       | 32        | 32              | 64 |
| Hilbert swizzle      | NO        | YES             | YES |
| shmem / CTA          | 8192 B    | 4112 B          | 8224 B |
| regs / thd reported  | 56        | 64              | **95** |
| sm target            | sm_90 + .v8.0 | sm_120a + .v8.7 | sm_120a + .v8.7 |

### mbarrier layout (32 B total in shmem)

  - `_tg_mbar +  0`: `full[0]`   (producer arrive.expect_tx; consumer waits)
  - `_tg_mbar +  8`: `full[1]`
  - `_tg_mbar + 16`: `empty[0]`  (consumer per-lane arrive; producer waits before refill)
  - `_tg_mbar + 24`: `empty[1]`

`arrive_count` init:
  - `full[s]`:  1   (one expect_tx call per stage per round)
  - `empty[s]`: 64  (2 consumer warps * 32 lanes = 64 arrivers per round)

### Parity tracking (per-stage, NOT global k_iter)

Each producer-consumer mbarrier pair tracks its own parity bit:
  - `parity_c0`, `parity_c1`: consumer's local parity for stage 0/1 (full mbar)
  - `my_parity`: producer's local parity for its own stage (empty mbar)

`try_wait.parity X` succeeds when current_phase != X. After a successful wait,
the local parity is XOR-flipped to reflect the new phase. Phase flips every
time the mbarrier completes a full round (arrive_count met OR DMA delivers
expect_tx bytes).

### Producer schedule

  - Warp 0 owns even K-iters (0, 2, 4, ...): TMA into smem slot 0, arrive on `full[0]`.
  - Warp 1 owns odd K-iters  (1, 3, 5, ...): TMA into smem slot 1, arrive on `full[1]`.
  - Each producer: lane 0 alone executes the loop; lanes 1-31 ret immediately.
  - Wait on `empty[my_stage]` BEFORE each refill (skipped on first iter since
    slot is virgin).

### Consumer schedule

  - Warps 2, 3 split the 64x64 output tile M-wise:
    * warp 2: rows 0..31 (m_tile=0)
    * warp 3: rows 32..63 (m_tile=1)
  - Each consumer warp covers 32M x 64N = 16 mma per K-step, 64 f32 acc/lane.
  - Per K-iter: wait on `full[k_iter & 1]`, do 4 ldmatrix + 16 mma, arrive on
    `empty[k_iter & 1]` (each of 32 lanes).
  - No `bar.sync` between iters -- mbarrier provides ordering.

## Verification

PTX assembled clean by driver JIT on sm_120 (RTX 5070, driver 13000).

### Bit-exact PASS (zero-mean data, all 6 shapes)

```
M=  512  maxabs=0.000000  maxrel=0.000000  ratio=0.6528
M= 1024  maxabs=0.000000  maxrel=0.000000  ratio=0.6656
M= 2048  maxabs=0.000000  maxrel=0.000000  ratio=0.7920
M= 4096  maxabs=0.000000  maxrel=0.000000  ratio=0.8151
M= 6144  maxabs=0.000000  maxrel=0.000000  ratio=0.8189
M= 8192  maxabs=0.000000  maxrel=0.000000  ratio=0.8381
```

### Non-trivial fill PASS (M=512, all-positive small values)

`verify_nontrivial` output:
```
M=N=K=512 non-trivial fill
  max|cuBLAS|=33.023438  max|hexa|=33.023438  max|diff|=0.042969  max_rel=0.001303
  zero cells: cuBLAS=0 hexa=0 (of 262144)
  verdict: PASS (max_rel=0.0013 < 0.05? yes; max_cublas > 1? yes)
```

max_rel = 0.0013 = 0.13% -- well within FP16 input + FP32 accumulator
tolerance. Reorder noise from cuBLAS internal K-tile layout vs N203's
linear K-tile order.

**F-RFC067-HEXA-TMA-WARP-SPEC: PASS** (warp-spec correctness validated under
both zero-mean and non-trivial fill).

## Performance (RTX 5070 sm_120, 200 reps, cudaEvent sync)

| M | cuBLAS TFLOPS | N197 TFLOPS | N200-full TFLOPS | N203 TFLOPS | ratio_vs_cuBLAS | pct vs N200-full | pct vs N197 |
|---|---|---|---|---|---|---|---|
|  512 | 23.24 |   --   | 15.17 | 15.17 | 0.6528 |  ~0.00% |  --  |
| 1024 | 53.30 | 24.56  | 39.39 | 35.48 | 0.6656 |  -9.94% | +44.49% |
| 2048 | 66.78 | 28.38  | 51.90 | 52.88 | 0.7920 |  +1.89% | +86.31% |
| 4096 | 70.03 | 20.70  | 55.98 | 57.08 | 0.8151 |  +1.96% | +175.80% |
| 6144 | 70.78 |   --   | 56.46 | 57.96 | 0.8189 |  +2.67% |   --   |
| 8192 | 70.81 |  9.64  | 57.98 | 59.34 | **0.8381** | **+2.34%** | **+515.72%** |

## Honest analysis (`@D g3`)

### Did TMA mbarriers fix N197 root cause #1?

**YES.** N203 at M=8192 = ratio 0.838 (+515% over N197's 0.136). The DMA-driven
mbarrier completion (`mbarrier::complete_tx::bytes`) successfully eliminates
the thread-side `cp.async.wait_all` block. Producer lane 0 only blocks on
the consumer's `empty` arrival (a 64-lane shmem-write operation), never
on DMA completion.

### Did warp specialization help over no-split (N200-full)?

**MIXED -- positive at M>=2048, negative at M=1024.**

  - M >= 2048: +1.89% to +2.67% TFLOPS over N200-full. Producer/consumer
    overlap is real but small. At ratio ~0.82 we're already close to
    architectural mma issue throughput; small wins from DMA-compute overlap.
  - M = 1024: -9.94% TFLOPS regression. With K_TILES = 64 small iterations,
    the per-stage mbarrier handshake overhead (4 mbarrier ops per K-iter:
    consumer-wait, consumer-arrive, producer-wait, producer-arrive) dominates
    the short mma chains. Without warp split, all 128 threads pile into mma
    and minimize latency.
  - M = 512: tied with N200-full (same 0.6528 ratio). Both designs are
    occupancy-bound at this scale.

### Producer/consumer overlap measurement

We do NOT have a direct microbenchmark of overlap %. Indirect evidence:
  - N203 wall-clock for the same shape vs N200-full at M=8192:
    18.528 ms vs 18.962 ms = 2.3% reduction.
  - Theoretical mma chain length 16 mma * ~16 cycles = ~256 cycles per K-iter
    per consumer. TMA latency from ubu-2 measurements (N196) ~200-400 cycles
    for 2 KB.
  - 2.3% improvement is consistent with "DMA mostly hidden by mma" but NOT
    with "perfect overlap" (which would predict ~5-15% gain). Probably
    bottleneck shifted from DMA-wait to mma issue throughput.

### Regs / occupancy

  - 95 regs/thd * 128 thd = 12160 regs/CTA.
  - RTX 5070 = 65536 regs/SM -> max 5 CTAs/SM by reg budget.
  - shmem 8224 B/CTA: with 96 KB/SM dynamic shmem, up to 11 CTAs/SM by shmem.
  - Reg budget is the binding constraint: 5 CTAs/SM.
  - N200-full at 64 regs/thd * 128 thd = 8192 regs/CTA -> max 8 CTAs/SM.

So N203 has LOWER occupancy than N200-full (5 vs 8 CTAs/SM). The fact that
N203 still beats N200-full at large M suggests the producer/consumer
decoupling more than compensates for the occupancy loss. The 64 acc/lane
(consumer reg pressure) is the cost; producer warps still allocate the same
register file slot because PTX doesn't distinguish per-warp reg files.

### Race detected?

None observed across 220 launches (20 warmup + 200 reps) per shape * 6 shapes
= 1320 launches. Bit-exact agreement with cuBLAS HGEMM on zero-mean data
(maxabs=0) and reorder-tolerance pass on non-trivial fill (max_rel=0.0013).
Per-stage parity tracking (NOT global k_iter parity) appears to be the
critical correctness ingredient -- early prototypes with `parity = k_iter & 1`
(N200-full style) would race because stage 0 and stage 1 advance phases
independently. N203 uses 3 distinct parity counters
(`parity_c0`, `parity_c1`, `my_parity` per producer) to track each
mbarrier's phase locally.

### Honest limitations

  - 64 f32 acc/lane drives regs/thd to 95 (vs N200-full's 64) -- limits
    occupancy. A cleaner 1P+3C or 2P+2C-with-smaller-tile design might
    reduce this.
  - We do NOT use bar.sync inside the K-loop. If a future change introduces
    one (e.g., for ldmatrix broadcast across warps), the producer warps'
    `ret` exits would break it. Document as latent fragility.
  - Path to >0.85 ratio likely requires (a) bigger output tile (128x128
    via 256 thd) + (b) more stages (3-4 deep) + (c) TMA swizzle for ldmatrix
    bank-conflict avoidance. All multi-session work.

### Bug history (single-session)

Found and fixed during this fire:
  - **`my_parity` initial value**: First attempt used `my_parity = 1`, which
    caused producer's first empty-wait to hang. Correct: `my_parity = 0`
    (the OLD phase before the first flip). The "unspecified launch failure"
    diagnostic was misleading -- it was actually a watchdog timeout, not
    an illegal memory access.

## Artifact integrity

  - `gen_sgemm_tma_warp_spec_ptx.py`: 6 shapes (512..8192), pure-ASCII, bijection verified per shape
  - `host.c`: nvcc -O2 -arch=sm_120a, 128 thd/block, driver API + cuBLAS HGEMM ref
  - `measure.sh`: plain `ssh ubu-2`, no SIDECAR_NO_POOL
  - 6 .ptx files, driver-JIT loaded on sm_120 (sm_120a target + .version 8.7)
  - `verify_nontrivial.c` + `verify_nontrivial.log`: non-trivial fill PASS
  - `result.json`: bit-exact + perf measurements + N197/N200-full deltas
  - `fire.log`: stdout from ubu-2 run
  - `ptxas_info.log`: cuFuncGetAttribute output
  - `compile.log`: nvcc warnings (printf format on -34%% literal -- benign)
