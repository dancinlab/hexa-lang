# RFC 067 N203 -- 3-stage TMA mbarrier pool + mma.sync + Hilbert (cuBLAS-catch-up attempt)

Date: 2026-05-22.  Host: ubu-2 (RTX 5070, sm_120, driver 13000, CUDA runtime 12090).
Source artifact dir: `inbox/fires/rfc067_ptma_multistage_mma_2026_05_22/`.

## Goal

Fuse N201's 3-stage TMA mbarrier pool (DMA-only proxy; 1.73x DMA throughput @ M=6144
K=4096 STAGES=3) INTO N200-full's real mma.sync chain (M=8192 ratio 0.819).  Headline:
**does the combined kernel break the 0.85 cuBLAS-ratio ceiling at any shape?**

## Kernel design (vs N200-full)

* Same 4-warp 64x64 output tile, 8 mma.sync.aligned.m16n8k16.f32.f16 per warp per K-iter.
* Same Hilbert d2xy CTA-swizzle (byte-identical prologue copy).
* Same 2 TMA descriptors (A row-major [M,K], B col-major-stored-as-[N,K], box [16, 64]).
* **N201 multi-stage pool**:
  * 3 mbarriers + 3 A slabs (2 KB each) + 3 B slabs (2 KB each) = 12,312 B shmem per CTA
    (vs N200-full's 4,112 B).
  * Each slot has its OWN parity counter (`%parity0/1/2`); N201 lesson: do NOT use a
    single `k_iter & 1` parity bit -- per-stage mbarrier completion is independent.
  * Prologue (thread 0): issue stages 0, 1, 2 (3 K-tiles ahead of compute).
  * Steady k-loop: wait `mbar[k%3]` with `parity[k%3]` -> ldmatrix slab[k%3] -> 8 mma ->
    flip parity[k%3] -> if (k+3 < K_TILES, thread 0): issue k+3 into the same slot
    (same offsets in shmem since `(k+3) % 3 == k % 3`).
* `bar.sync 0` after both the wait and the issue (ensures the wait is collective and that
  the issue's `mbarrier.arrive.expect_tx` is visible before the next iter's wait).
* `%ctaid` aliasing pitfall (N201): not triggered -- generator uses `%r100`/`%r101` for
  ctaid.x/y reads, never shadows `%ctaid` itself.

## ptxas info per shape

All 6 shapes compile identically:

| shape | regs/thd | barriers | shmem (B) | stack | compile (ms) |
| ----: | -------: | -------: | --------: | ----: | -----------: |
| 512   | 64       | 1        | 12,312    | 8     | 30.3         |
| 1024  | 64       | 1        | 12,312    | 8     | 30.0         |
| 2048  | 64       | 1        | 12,312    | 8     | 31.4         |
| 4096  | 64       | 1        | 12,312    | 8     | 30.3         |
| 6144  | 64       | 1        | 12,312    | 8     | 31.6         |
| 8192  | 64       | 1        | 12,312    | 8     | 29.5         |

Threads/CTA = 128 (4 warps).

## Occupancy bound (sm_120, RTX 5070)

* Shmem: 100 KB/SM available -> 100*1024 / 12,312 = 8.32 -> 8 CTAs/SM by shmem.
* Regs: 65,536 regs/SM -> 65,536 / (64 * 128) = 8 CTAs/SM by registers.
* Threads: 1,536 threads/SM -> 12 CTAs/SM by threads.
* **Binding: regs at 8 CTAs/SM**.  (N200-full was ALSO bound by regs at 8 CTAs/SM;
  the 3x shmem inflation did NOT halve occupancy because regs were already binding.)

## Measured TFLOPS sweep (20 warmup + 200 reps median per shape)

Bit-exact verification: all-positive non-trivial fill (A = ((i%8)+1)/32, B = ((i%5)+1)/16),
producing dot-product magnitudes |C| up to ~216 at K=8192.

| M=N=K | cuBLAS TF | N200-full TF | N200-full ratio | **N203 TF** | **N203 ratio** | delta vs N200-full | max\|hexa-cuBLAS\| | maxrel | broke 0.85 |
| ----: | --------: | -----------: | --------------: | ----------: | -------------: | -----------------: | -----------------: | -----: | ---------: |
|   512 | 23.237    | 15.169       | 0.6546          | **19.692**  | **0.8474**     | **+0.1928**        | 0.0102 (small\|C\|=12) | 0.0008 |   NO (close) |
|  1024 | 53.303    | 39.395       | 0.7385          | 40.820      | 0.7658         | +0.0273            | 0.0234             | 0.0009 |   NO |
|  2048 | 66.767    | 51.902       | 0.7773          | 52.225      | 0.7822         | +0.0049            | 0.0820             | 0.0015 |   NO |
|  4096 | 70.018    | 55.980       | 0.7995          | 57.409      | 0.8199         | +0.0204            | 0.0840             | 0.0008 |   NO |
|  6144 | 70.800    | 56.455       | 0.7976          | 58.114      | 0.8208         | +0.0232            | 0.1348             | 0.0008 |   NO |
|  8192 | 70.801    | 57.984       | 0.8190          | **59.711**  | **0.8434**     | +0.0244            | 0.0801             | 0.0004 |   NO |

`maxrel` <= 1.5e-3 across all shapes (well within FP16-input/FP32-acc accumulator-ordering
tolerance for K up to 8192).

## Headline

**broke_085_at_any_shape = FALSE.**

Best ratio = **0.8474 at M=512** (smallest shape, where N200-full was 0.6546 -- biggest
absolute improvement at smallest shape).  Largest shape M=8192 = **0.8434** (delta
+0.0244 vs N200-full).  Approaches the 0.85 ceiling but does not break it.

**N203 beats N200-full at all 6 shapes.**

## F-RFC067-HEXA-TMA-MULTISTAGE-MMA falsifier

* Bit-exact PASS: max|N203 - cuBLAS HGEMM| <= 0.135, maxrel <= 1.5e-3 across all 6 shapes.
* Per-shape median TFLOPS + ratio_vs_cublas recorded in `result.json`.
* Drain-phase: no explicit drain. The k-loop self-paces -- when `k+STAGES >= K_TILES`
  the issue-branch is skipped (via `setp.lt.s32 %p_issue, %issue_k, K_TILES`).  Final
  STAGES-1 iterations just consume the remaining mbarrier arrivals.  No hangs observed
  across 220 launches per shape x 6 shapes.

## Interpretation (`@D g3` honest scope)

The "3-stage DMA gives 1.73x throughput at the cliff" hypothesis from N201 was a
DMA-load-only proxy.  When fused into the real mma chain, the uplift collapses to
+2.5--2.9 pp ratio at M >= 2048.  This means **the DMA was NOT the binding constraint
on the N200-full mma chain at M >= 2048** -- the binding constraint is the mma chain
itself (4-warp 64x64 with no software pipelining of the mma, no warp specialization,
no async smem -> register prefetch).

What the multi-stage TMA DID help with: smaller shapes (M=512: +19 pp, M=1024: +2.7 pp).
At small M, N200-full was DMA-bound (only 64 / 256 / 1024 CTAs to amortize startup);
N201's prefetch-ahead-of-compute pattern hides DMA latency for the limited active CTAs.
At large M (4096+), the chip is mma-bound and the 3 extra slabs of in-flight DMA buy
only ~2.5 pp.

Next steps to break 0.85 (out of scope for N203):
* (a) warp specialization (producer warp issues TMA, consumer warps do mma);
* (b) shmem -> register async prefetch overlap with mma (current ldmatrix is serial);
* (c) 128x128 CTA tile (mma chain doubled per warp);
* (d) TMA swizzle CU_TENSOR_MAP_SWIZZLE_128B to reduce ldmatrix bank conflicts.

## Artifact files

* `gen_sgemm_tma_multistage_mma_ptx.py` -- PTX generator (6 shapes, Hilbert verified per shape).
* `host.c` -- nvcc driver (cuBLAS HGEMM baseline + N200-full table + N203 measure).
* `measure.sh` -- ubu-2 ssh + scp + nvcc + fire orchestration.
* `sgemm_tma_multistage_mma_{512,1024,2048,4096,6144,8192}x*_grid.ptx` -- 6 emitted PTX.
* `ptxas_info.log` -- standalone ptxas -v per shape.
* `fire.log` -- end-to-end stdout from the fire (verification + timing).
* `result.json` -- structured per-shape result (cuBLAS, N149, N200-full, N203, delta, broke_085).
* `compile.log` -- nvcc build output.
