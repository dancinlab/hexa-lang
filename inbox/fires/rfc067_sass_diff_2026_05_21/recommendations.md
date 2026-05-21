# RFC 067 hexa N89 -- top 3 actionable micro-optimisations vs cuBLAS

Source: SASS diff in `diff_analysis.md`. All recommendations stay within mma.sync semantics
(no wgmma sm_90+, no tcgen05 sm_100+). Each is a single-PR-sized port: hexa already has the
primitives.

## Recommendation 1: 6-stage software pipeline (estimate: +0.20-0.30 ratio)

**What cuBLAS does, hexa doesn't.** cuBLAS issues `cp.async.commit_group` 5 times in a prologue
loop **before** the steady-state K-loop starts, then uses `cp.async.wait_group(4)` inside the
K-loop -- meaning "wait until at least 4 cp.async groups are still in flight, then proceed".
This keeps the LDGSTS pipeline 5-deep at all times, so each K-step's gmem load latency is
amortized across 5 K-step compute windows.

**What hexa N89 does.** Inside the K-loop, every iteration:
1. `cp.async.commit_group` (issue current K-tile load)
2. `cp.async.wait_all`
3. `__syncthreads`
4. mma loop
5. `__syncthreads`

This serializes load and compute. Each cp.async issued cannot overlap with anything because the
very next instruction is wait_all.

**Hexa-side change (PTX edit in `gen_sgemm_tile128_ptx.py`).** Replace the K-loop body with:
- Prologue: emit `cp.async.commit_group` 5 times for K-tiles 0..4 (load into smem stages 0..4),
  no wait between them.
- Main loop body for K-step i in [0, K/16-1]:
  - `cp.async.wait_group 4` (only wait for the oldest stage)
  - `__syncthreads`
  - mma over stage (i mod 6)
  - If i+5 < K/16: emit cp.async.commit_group for stage ((i+5) mod 6)
- Epilogue: drain remaining cp.async.wait_all.

**Required shmem budget**: 6 * (128*16 + 16*128) * 2 = 24 KB per CTA. Current hexa N89 uses
16 KB; moving to 24 KB stays well under sm_90's 100 KB/CTA carveout and keeps occupancy at
2 CTAs/SM (now 1, was 1 due to 32-warp register pressure too -- pipeline change does not
worsen occupancy).

**Falsifier**: at M=1536, expect hexa median 195us -> 130-140us, TFLOPS 37 -> 53-57.

## Recommendation 2: K-tile 16 -> 32, doubling per-K-step compute (estimate: +0.05-0.10 ratio)

**What cuBLAS does, hexa doesn't.** cuBLAS K-tile is 32, meaning each warp executes 2 mma.m16n8k16
per K-step (consuming 32 K-elements: K=16 from chunk 0, K=16 from chunk 1, accumulating into the
same C fragment). This halves the absolute count of `cp.async.commit_group` boundaries.

**What hexa N89 does.** K-tile is 16. K-loop iterates 96 times (K=1536/16). Each iter has fixed
overhead: 2 BAR.SYNC, 1 LDGDEPBAR, 1 DEPBAR (count from SASS). 96 * 4 = 384 sync instructions
just for K-loop coordination.

**Hexa-side change.** Modify the inner K-loop in `gen_sgemm_tile128_ptx.py` to load 32 K-elements
per K-tile (LDGSTS.E.BYPASS.128 loads 8 elements per thread; for K=32 each warp needs 16 LDGSTS
to fill 128*32 A + 32*128 B; 16 LDGSTS per warp * 32 warps / 128 = 4 LDGSTS per CTA per K-step,
emit 2x more LDSM per K-step, run inner-k unroll 2x mma).

**Required smem per stage**: doubles from 8 KB (128*16*2 + 16*128*2) to 16 KB per stage. With
6 stages that is 96 KB/CTA -- exceeds 100 KB carveout when combined with shared metadata, so
this rec is only compatible with 4-stage pipeline (or 3-stage with K=64). Trade off in same PR.

**Falsifier**: independent of rec 1, expect ~5-7 TFLOPS gain from halved sync count. Combined
with rec 1, expect 60-65 TFLOPS.

## Recommendation 3: tile 128x128 -> 64x64 and warps 32 -> 4 (estimate: +0.05-0.10 ratio, or large for small M)

**What cuBLAS does, hexa doesn't.** cuBLAS picks a 64x64 tile with 4 warps (128 thd). At M=1536
this yields 576 CTAs (vs hexa's 144), giving 13.7 CTAs/SM (vs hexa's 3.4) and dramatically more
inter-CTA latency overlap.

**What hexa N89 does.** 128x128 tile with 32 warps (1024 thd) = 4x fewer CTAs. The choice
was made in PR Step pS specifically because at large M it amortizes shared-tile load cost;
but it sacrifices CTA-level parallelism, which is the dominant latency-hider on smaller M
shapes (see result.json: at M=256 hexa is ratio 0.44, at M=384 0.33 -- worse than at M=1536).

**Hexa-side change.** Drop tile back to 64x64 / 4 warps (this is the N77 PP variant which was
hexa-tile-baseline before pS). Combine with rec 1's 6-stage pipeline + rec 2's K=32 to recover
the per-CTA arithmetic intensity that was lost.

**Required register budget**: 4 warps * 32 m * 32 n = 32 regs/warp accumulator. Plus 16 regs
fragment + 16 regs address-gen = ~64 regs/thread, fitting in 255-reg/thread budget. Occupancy:
4 warps * 128 thd / CTA = 128 thd, can have 12 CTAs/SM (limited by 64 KB shmem per SM / 6 stages
shmem). vs hexa N89's current ~1 CTA/SM with 32 warps.

**Falsifier**: combined with rec 1 + rec 2, expect hexa to reach 60-65 TFLOPS at M=1536 (ratio
0.90-0.97). Without rec 1 it is a regression (back to N77's 36 TFLOPS).

## Stacking order

Apply in this order (each falsifiable independently):
1. **Rec 3 first** (revert tile to 64x64 / 4 warps): isolates the CTA-count gain. Expect 37 -> 40 TFLOPS
   (per-CTA arith intensity drop offset by CTA-count gain). This is the N77-PP variant -- already measured 36.06,
   so applying rec 3 alone is a wash; the gain only materializes with rec 1.
2. **Rec 1** (6-stage pipeline on top of rec 3): expect 40 -> 55-60 TFLOPS.
3. **Rec 2** (K-tile 32 on top of rec 1+3): expect 60 -> 62-65 TFLOPS.

## What we are NOT recommending

- **wgmma.async / sm_90 hopper-native**: out of scope. RTX 5070 supports wgmma but the cuBLAS
  kernel is sm_80-vintage CUTLASS, so this would be racing past cuBLAS into newer ISA. Multi-session
  effort and falls outside the "match cuBLAS micro-opts" framing.
- **TMA (cp.async.bulk.tensor)**: same reasoning -- sm_90+ primitive.
- **Persistent kernel / stream-K**: structural change to the kernel boundary, not a micro-op.
  Worth doing as a separate PR after rec 1-3 are landed and measured.
- **shmem swizzle (XOR-style)**: hexa N89 already swizzles per the N77 stack (XOR-swizzle is from
  pN). Verified in PTX. No diff vs cuBLAS here.
