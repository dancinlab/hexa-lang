# RFC 067 P-nsight-Hilbert -- 3-way locality ladder: no-swizzle -> super-block -> Hilbert

Mechanism diff for the N149 result (Hilbert beats super-block +26-35% at the M>=6144 cliff).
Profiler: Nsight Compute on ubu-2 (RTX 5070 sm_120, driver 580.159.03, 32 MB L2), `sudo ncu`,
same metric + section lists as N157. Kernel body byte-identical across all three variants;
the ONLY changed variable is CTA visitation order (and Hilbert's p x p launch grid + padding
early-return). This isolates L2 reuse as the sole cause of the perf ladder.

Real perf (NOT ncu-replay) -- nsys 20-rep this cycle confirms N149 result.json:
  M=6144: nsys 59.36 TFLOPS vs N149 58.49 (within 1.5%)
  M=8192: nsys 60.55 TFLOPS vs N149 59.48 (within 1.8%)

---

## M = 6144 (working set 144 MB = 4.5x L2)

| metric                          | no-swizzle (N140) | super-block (N157) | Hilbert (this) | ladder |
|---------------------------------|-------------------|--------------------|----------------|--------|
| **L2 hit rate (%)**             | **56.72**         | **86.94**          | **96.81**      | +30.2 -> +9.9 pts |
| ratio vs cuBLAS (real)          | 0.234             | 0.655              | 0.834          | the perf ladder |
| hexa TFLOPS (real)              | 16.55             | 46.37              | 58.49          | +180% -> +26% |
| DRAM bytes / launch (MiB)       | 6470              | 1942               | **548**        | 3.33x -> 3.55x less |
| DRAM throughput (% peak)        | 33.83 (saturated) | 30.04              | **9.06**       | DRAM nearly idle |
| DRAM bandwidth (GB/s)           | 223.9 (saturated) | 198.9              | **59.3**       | un-saturated |
| L2 cache throughput (%)         | 32.83             | 91.06              | **96.07**      | L2 ports near-max |
| eligible warps / scheduler      | 0.10 (starved)    | 0.33               | **0.35**       | 3.5x recovery |
| issue-slot eligible (%)         | 6.52              | 18.47              | 19.61          | scheduler fed |
| warp cycles / issued inst       | 121.94 (3x stall) | 42.83              | **40.33**      | latency floor |
| compute SM throughput (%)       | 14.00 (starved)   | 39.78              | 42.30          | compute fed |
| achieved occupancy (%)          | 66.28             | 65.98              | 65.94          | UNCHANGED (not the lever) |
| inst executed (Minst)           | 839               | 840               | 844            | ~identical (padding CTAs return cheap) |

## M = 8192 (working set 256 MB = 8x L2)

| metric                          | no-swizzle (N140) | super-block (N157) | Hilbert (this) | ladder |
|---------------------------------|-------------------|--------------------|----------------|--------|
| **L2 hit rate (%)**             | **50.44**         | **87.07**          | **96.48**      | +36.6 -> +9.4 pts |
| ratio vs cuBLAS (real)          | 0.304             | 0.624              | 0.847          | the perf ladder |
| hexa TFLOPS (real)              | 13.91             | 44.17              | 59.48          | +218% -> +35% |
| DRAM bytes / launch (MiB)       | 17464             | 4483               | **1355**       | 3.89x -> 3.31x less |
| DRAM throughput (% peak)        | 33.34 (saturated) | 27.59              | **9.52**       | DRAM nearly idle |
| DRAM bandwidth (GB/s)           | 220.7 (saturated) | 182.7             | **63.0**       | un-saturated |
| L2 cache throughput (%)         | 28.52             | 85.38             | **97.47**      | L2 ports near-max |
| eligible warps / scheduler      | 0.10 (starved)    | 0.33              | **0.36**       | 3.6x recovery |
| issue-slot eligible (%)         | 5.63              | 17.38             | 19.88          | scheduler fed |
| warp cycles / issued inst       | 141.53 (3x stall) | 45.67             | **39.95**      | latency floor |
| compute SM throughput (%)       | 12.16 (starved)   | 37.54             | 43.12          | compute fed |
| achieved occupancy (%)          | 66.36             | 66.25             | 66.19          | UNCHANGED (not the lever) |
| inst executed (Minst)           | 1987              | 1988              | 1992           | ~identical |

---

## Verdict

**Hilbert L2 hit EXCEEDS super-block's 87% plateau** -- by ~+9.4-9.9 pts, landing at
**96.5-96.8%**, nearly the M=4096 near-perfect-locality level (98%). The hypothesis is
CONFIRMED: Hilbert's Manhattan-adjacent 2D blob is a tighter concurrent working set than
the super-block's 256x256 row-major strip, so a larger fraction of A/B tile reloads hit L2.

The locality ladder is monotone in every memory metric:
  L2 hit:     56% -> 87% -> 97%   (no-swizzle -> super-block -> Hilbert)
  DRAM bytes: 6470 -> 1942 -> 548 MiB @ M=6144   (11.8x total reduction)
              17464 -> 4483 -> 1355 MiB @ M=8192 (12.9x total reduction)
  elig warps: 0.10 -> 0.33 -> 0.35-0.36
  warp cyc/inst: 122/142 -> 43/46 -> 40

## The +26-35% perf delta is explained by the L2-hit delta -- AND a second effect

The L2 hit gain (87 -> 97%) is the headline, but the DRAM-traffic delta is even larger than
the L2-hit delta alone would predict: Hilbert moves **3.3-3.6x fewer DRAM bytes than the
super-block** (548 vs 1942 MiB; 1355 vs 4483 MiB). DRAM throughput collapses from ~28-30%
(super-block, still meaningful) to ~9% (Hilbert, nearly idle), and DRAM bandwidth from
~183-199 GB/s to ~59-63 GB/s. The kernel is now firmly compute/L2-bound, not DRAM-bound.

So the gain is BOTH predicted-locality (L2 hit > 87%, the tighter 2D blob) AND a sharper-than-
linear DRAM-traffic drop: a higher L2 hit rate at the cliff has super-linear leverage on DRAM
bytes because each avoided miss removes a full sector fetch from a working set that is 4.5-8x
larger than L2. This is the same single causal chain as N157, just pushed further up the
locality curve.

## Honest caveats (`@D g3`)

- ncu kernel-replay wall (0.7-4.6 TFLOPS in the metrics/section runs) is NOT real perf; the
  counters are replay-invariant. Real perf = N149 result.json + this cycle's nsys 20-rep
  (59.4 / 60.5 TFLOPS), which match N149 within <2% -> no replay contamination.
- Occupancy is UNCHANGED across all three variants (~66%, register-limited at 64 regs/thd).
  The cliff and its recovery are a memory-latency / scheduler-feeding story, NOT occupancy.
- L1/TEX hit stays ~1.3-1.8% (L1 bypass) across all three -- unchanged, as expected.
- Hilbert's padding CTAs (7168 of 16384 @ M=6144) early-return cheaply: inst_executed is
  within 0.5% of super-block / no-swizzle, so the p x p launch does not inflate work.
- Cross-host: N157 + this Hilbert run are both on ubu-2; N140 no-swizzle baseline ran on
  ubu-1 (same GPU model + driver). N157 validated the cross-host comparison via the M=4096
  control (L2 within 0.03 pts). The same control logic applies here.
- L2 hit did NOT reach M=4096's 98% -- the full A+B working set (144-256 MB) still exceeds
  the 32 MB L2; Hilbert bounds the CONCURRENT 2D-blob working set tighter than super-block
  but cannot cache the whole matrix. This explains the residual ratio gap to cuBLAS
  (0.834 / 0.847, not ~1.0) and why the ladder plateaus near 97%, not 98%.
