# RFC 067 PPSH — Persistent CTA + Split-K + Hilbert visitation (2026-05-22, ubu-1)

## Headline

**Useful NEGATIVE.** PPSH (persistent P=48 + split-K G=4 + Hilbert) regresses
catastrophically from N149 PHILB (Hilbert-only) at every shape, with the gap
widening as M grows:

| Shape | N149 PHILB ratio | **PPSH ratio (kernel-only)** | Δ ratio | %Δ TFLOPS |
|------:|-----------------:|-----------------------------:|--------:|----------:|
| 4096  | 0.821            | **0.510**                    | −0.32   | **−38.0%** |
| 6144  | 0.834            | **0.321**                    | −0.52   | **−61.9%** |
| 8192  | 0.847            | **0.136**                    | −0.71   | **−84.1%** |

Peak TFLOPS reached: 35.37 (M=4096, kernel-only) — versus N149 PHILB 59.48 at
M=8192. PPSH at M=8192 collapses to 9.5 TFLOPS / 115 ms (vs cuBLAS 15.7 ms /
70 TFLOPS, vs N149 PHILB 18.5 ms / 59.5 TFLOPS).

Hypothesis FALSIFIED at every shape: persistent + split-K + Hilbert does **not**
compound at large M — atomic-add traffic dominates, and losing 8 CTAs/SM
(192 vs 16384 CTAs in N149) starves the SM scheduler.

## Numeric verification

- `hexa_vs_cublas_maxabs = 0.0`, `maxrel = 0.0`, `ulp_relative = 0.0` at every shape.
- Split-K atomic-add is technically non-deterministic but the test data
  `A_ij in {-0.25..0.1875}` (step 1/16) and `B_ij in {-0.25..0.25}` (step 1/8)
  yields per-K-group partial sums of magnitude ≤128 at K=8192, well within
  fp32 mantissa precision (23 bits). All 4 partial sums add to the cuBLAS
  reference value with zero rounding error.
- F-RFC067-HEXA-PERSIST-SPLITK-HILBERT **PASS** (numeric, by 4-ULP gate; bit-exact
  even though tolerance allowed up to ULP-relative 256).

## Why it failed — diagnosis

1. **Lost SM occupancy.** N149 PHILB launches 16384 CTAs / 48 SMs = 341 CTAs
   queued per SM, with 8 resident concurrently (PHILB regs/thd=64, 4 warps/CTA
   → 8 CTAs/SM upper bound on RTX 5070). PPSH launches just 48 × 4 = 192
   CTAs, which fits in just 4 concurrent CTAs/SM (since G=4 partitions take
   their own CTA each). Per-SM occupancy drops by 2×, eliminating the
   latency-hiding pool that N149 PHILB relied on between mma.m16n8k16 stalls.

2. **Atomic-add traffic per output element scales with G=4.** Each output
   element now sees 4 atomic-add bursts (one per K-group) instead of 1
   ordinary store. At M=8192, that is 4 × 8192² = 268 M atomic ops, all
   contending on the L2 coherent path. The contention model is per-line
   (32 B), so 16384 tiles × G=4 = 65536 in-flight reduction bursts pound
   the same per-tile cache lines from 4 different CTAs at staggered times.

3. **Hilbert locality argument inverts.** N149's Hilbert win was that 8
   concurrently-resident CTAs per SM walked Manhattan-adjacent tiles,
   pooling their A/B working set in L2. PPSH's persistent CTA owns its
   own contiguous Hilbert range (good for cache LOCALLY) but at G=4 there
   are 4 CTAs per SM, all from different K-groups, all hitting completely
   different A/B regions of memory (each K-group touches A[k_slice], B[k_slice]
   — disjoint K-slices). So the L2 working set per SM 4×-balloons.

4. **Inner K-loop is 4× shorter (K_TILES_PER_GROUP = K/64 instead of K/16).**
   At K=8192, k_tiles_per_group = 128 vs N149 K_TILES_TOTAL = 512. Each
   tile's MMA time scales with K-tile count; shorter K-loop means less
   amortisation of the per-tile epilogue (32 atomic-adds + memset cost).

5. **M=8192 collapse is bandwidth-bound, not compute-bound.** The
   `hexa_ppsh_kernel_only_median_ms = 115.6 ms` vs cuBLAS 15.7 ms (7.4× slower)
   indicates we have spent all our time waiting for the 268 M atomic-add
   serialised LD/ST through L2. Memset overhead is only 0.33% (M=8192 has
   the smallest relative memset cost because the kernel-only timing is so long).

## Persistent CTA count, K-split count

- `persistent_slots P = 48` (kernel-baked NUM_PERSISTENT; matches RTX 5070 SM count)
- `split_k_groups G = 4`
- `grid_x_launched = 192` (P × G)
- `tiles_per_cta`: M=4096 → 86, M=6144 → 192, M=8192 → 342 (Hilbert p×p / P)
- `k_tiles_per_group`: M=4096 → 64, M=6144 → 96, M=8192 → 128 (K/(16·G))

## Atomic-add overhead estimate

For M=8192:
- 4 K-groups × 48 persistent CTAs × 342 tiles_per_cta × 32 atomic adds ≈ 2.1 M atomic ops
- Per-tile epilogue: 32 atomic-add lat ~ 100 ns each (sm_120 L2 RT) × overlap
  → effective per-tile atomic cost ≈ 1 µs amortised
- 192 CTAs × 342 tiles = 65664 tile-iterations / 48 SMs ≈ 1368 tiles/SM
- 1368 × 1 µs / SM = 1.4 ms (best case, perfect interleaving)
- Actual measured kernel = 115.6 ms → atomic-add is being SERIALISED per cache
  line (each 32-B line touched by 4 K-groups serially)
- Memset overhead = 0.33% (negligible compared to atomic-add traffic)

## What this confirms (cite N94 / N130)

N94 (persistent-only): -0.39% on small-M square shapes; *predicted* persistent
might win at "M ≥ 768" — but only because at small M the GPU was already
under-saturated. PPSH extends N94's negative to LARGE M with split-K compounding
the cost: at M=8192 with G=4 split-K, the atomic-add ceiling is so high that
even Hilbert locality cannot save it.

The N130 cliff (at M=6144) for naive 4-warp WAS solved by N134 super-block then
N149 Hilbert — but **adding** split-K to Hilbert breaks the win because it
multiplies the atomic-add path that Hilbert was never optimised for.

## g3 honest scope

- **No kernel bug claimed.** Reg/thd=64 matches N149 exactly. Compile clean.
  ptxas info identical to N149 except grid size. Numeric PASS bit-exact.
- **PTX pure-ASCII verified locally** before scp (LC_ALL=C grep -P [^\x20-\x7e] = 0).
- **Pool routing avoided** — plain `ssh ubu-1`; HOST contention with N196 on
  same host was sequential (this fire after N196 completed).
- **Useful negative.** Now we know: at this substrate (RTX 5070, 32 MB L2,
  48 SMs), the GPU grid scheduler + 8 CTAs/SM + Hilbert visitation is *already
  near optimal*; adding persistent CTAs sacrifices SM occupancy, and adding
  split-K multiplies atomic-add traffic by G. Neither helps; combined they
  catastrophically regress.
- **Not falsified at all M.** It is possible split-K helps when K >> M (skinny
  GEMM, K = 32k+ with M = 1024). That regime is not tested here. The
  hypothesis "persistent + split-K + Hilbert helps SQUARE large M" is FALSIFIED.

## What to try next (out of scope of this fire)

1. **Persistent + Hilbert WITHOUT split-K** (G=1). Drop the atomic-add and
   keep just the persistent-walks-Hilbert idea. If still regresses → SM-occupancy
   loss is the dominant cost; conclude N149 PHILB is the local optimum.
2. **Persistent without Hilbert + 2-CTA shadowing.** Use 96 persistent CTAs
   (= 2× SMs) so 4 CTAs/SM (matching N149's effective occupancy) and walk
   tile_idx in linear order. Tests scheduler-amortisation hypothesis cleanly.
3. **Split-K with reduction kernel (not atomic-add).** G partial sums written
   to G separate C-buffers; second small kernel sums them. Avoids L2 atomic
   contention — but adds a launch + memcpy round-trip; probably also a loss
   at large M.

## Artifact contents

```
gen_sgemm_ppersist_splitk_hilbert_ptx.py   # PTX generator (G=4, P=48 baked)
host.c                                     # cuBLAS HGEMM ref + 2 timing variants
measure.sh                                 # rsync + nvcc + fire on ubu-1
sgemm_ppsh_4096x4096_grid.ptx              # generated PTX, pure-ASCII
sgemm_ppsh_6144x6144_grid.ptx
sgemm_ppsh_8192x8192_grid.ptx
compile.log                                # nvcc output (clean)
fire.log                                   # ./host run output
ptxas_info.log                             # cuFuncGetAttribute per shape
result.json                                # structured measurements (200 reps each)
notes.md                                   # this file
```

Headline single line for parent: **PPSH FAILS at every shape; collapse worsens
with M (84% TFLOPS regression @ M=8192). Useful negative — confirms persistent +
split-K + Hilbert combination cannot beat N149 Hilbert-only on square large M.
F-RFC067-HEXA-PERSIST-SPLITK-HILBERT PASS (numeric bit-exact; perf negative).**
