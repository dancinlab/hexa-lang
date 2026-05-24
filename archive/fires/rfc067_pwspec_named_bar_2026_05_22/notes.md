# RFC 067 P-Wspec NAMED-BAR -- 4P+4C asymmetric bar.arrive/bar.sync

## Context

N127 (rfc067_pZspec_hexa_sgemm_warp_spec_2026_05_22) tried 2P+2C warp
specialization with full-CTA `bar.sync 0`. Result: -6.8% vs N107 at M=1024
(ratio 0.686). Root cause identified: full-CTA bar.sync serializes producer
slot reuse with consumer mma chain.

N127 cited mechanism #2: "cuBLAS canonical avoids this via named barriers
(bar.arrive + named bar.sync with asymmetric arrival counts) -- out of
single-session reach without TMA/cp.async.bulk primitives".

This cycle (N196): attempt **named barriers** with **4P+4C** (8 warps,
256 thd/CTA) and rotating per-slot barrier indices. Asymmetric
arrive/sync split: producer issues `bar.arrive` (non-blocking) for
"slot ready" and "slot consumed" check; consumer issues `bar.sync`
(blocking) for "slot ready"; consumer issues `bar.arrive` (non-blocking)
for "slot consumed". Producer's only blocking sync is on
`Bconsumed[slot]` BEFORE reusing a slot two iters back.

## Design

| Aspect | N127 | N196 (this) |
|---|---|---|
| Warps total | 4 | 8 |
| Threads / CTA | 128 | 256 |
| Producer warps | 2 | 4 |
| Consumer warps | 2 | 4 |
| Per-consumer output | 32M x 64N | 16M x 64N |
| Mma / cons / kstep | 16 | 8 |
| Acc f32 / lane | 64 | 32 |
| Bar protocol | `bar.sync 0` (full CTA, blocking both sides) | named bars 1..4, asymmetric `bar.arrive` / `bar.sync` (count=256) |
| Pipeline stages | 2 | 2 (rotating) |
| shmem / CTA | 8192 B | 8192 B (unchanged) |
| Regs / thd reported | 94 | 56 |

Named-bar mapping:
- bar 1: slot 0 ready    (prod arrives, cons syncs)
- bar 2: slot 0 consumed (cons arrives, prod syncs)
- bar 3: slot 1 ready    (prod arrives, cons syncs)
- bar 4: slot 1 consumed (cons arrives, prod syncs)

All bars use count=256 (full-CTA arrival). The "asymmetry" is purely in
which side blocks (sync) vs races ahead (arrive); the count is symmetric.

## Verification

- **PTX assembled clean** by ptxas 12.0 standalone (`ptxas -arch=sm_90`).
- **Driver-JIT load OK** on sm_120 (RTX 5070, driver 13000).
- **Bit-exact PASS**: max|delta| = 0.0 for all 4 shapes (1024/2048/4096/8192).
- regs/thd = 56 (well below N127's 94 -- 16M consumer + smaller acc set).

F-RFC067-HEXA-WARP-SPEC-NAMED-BAR: **PASS** (asymmetric named barriers
land correctly, bit-exact output).

## Measured perf (RTX 5070 sm_120, 200 reps, cudaEvent sync)

| M | cuBLAS TFLOPS | hexa N196 TFLOPS | ratio | N127 ratio | N149 ratio | pct over N127 / N149 |
|---|---|---|---|---|---|---|
| 1024 | 53.11 | 24.56 | 0.462 | 0.686 | n/a | **-34.1% vs N127** |
| 2048 | 66.97 | 28.38 | 0.424 | n/a | n/a | n/a |
| 4096 | 70.04 | 20.70 | 0.296 | n/a | 0.821 | **-63.7% vs N149** |
| 8192 | 70.80 |  9.64 | 0.136 | n/a | 0.847 | **-83.8% vs N149** |

## Honest analysis (g3-compliant, no claim inflation)

The named-bar variant is **bit-exact correct** but **substantially slower**
than both N127 (the failed predecessor) and N149 (current best). Several
mechanisms appear to compound:

1. **256 thd/CTA with 4096-byte shmem slabs is occupancy-hostile on sm_120.**
   RTX 5070 has 1536 thd/SM max for compute; 256 thd/CTA -> max 6 CTAs/SM
   theoretically, but our 8192-B shmem at 8192 B isn't the bottleneck.
   The likely cap: 56 regs/thd * 256 thd = 14336 regs/CTA; with 65536
   regs/SM that's 4 CTAs/SM. N107's 128 thd/CTA * 32 regs/thd is similar
   register-budget but with 12 CTAs/SM (max-CTAs-cap). Lower CTA count
   per SM directly hurts latency hiding.

2. **`cp.async.wait_all` per K-step kills overlap.** I used `wait_all`
   after the prefetch each iter, which globally blocks the producer
   warp until that prefetch lands -- which means the producer cannot
   queue the NEXT iter's cp.async during consumer's mma. The named-bar
   `bar.arrive` saved time on the producer-consumer boundary, but the
   wait_all undid that savings inside the producer. Should have been
   `cp.async.wait_group N-1` with N-stage pipeline (so wait waits for
   PREVIOUS group while CURRENT group races).

3. **4 consumer warps producing only 8 mma / K-step has poor mma
   throughput density.** mma.m16n8k16 instruction latency is hidden by
   the next mma. With only 8 mma per consumer per K-step, the inter-mma
   dependency through accumulators (fc[0..3] read-modify-write) is a
   tight chain. N107/N149's 4 warps with 8 mma each have the same chain
   length but spread across MORE warps -> better warp-level parallelism
   for the same SM. Here, 4 consumers + 4 idle-after-arrive producers
   means only 4 active mma-issuing warps on the SM (same as N107 in
   ABSOLUTE terms but at 2x the thread count -> half occupancy).

4. **Larger-M perf collapses 0.30 -> 0.14 from M=4096 to M=8192**
   suggesting the design also lost the L2-reuse advantage that N149's
   Hilbert swizzle preserved. With no swizzle here (raw row-major CTA
   ID), L2 thrash kicks in hard at M=8192 (cf. N130 cliff at M>=6144).

## Did named-bar unlock perf?

**No.** The hypothesis "named barriers + asymmetric arrive/sync close
the N127 -> N149 gap" is **falsified** for this implementation variant.

The mechanism #2 citation from N127 was correct in pointing at named
barriers as the producer-consumer decoupling primitive, but the missing
piece is **multi-stage (3+ slot) pipeline + cp.async.wait_group N-1**.
Without that, the named bars only buy you milliseconds on the bar
boundary while wait_all gives back the savings on the cp.async side.

cuBLAS canonical also pairs warp spec with **wgmma + TMA + register
fragments preserved across K-iters**, not just bar tricks. Named bars
in isolation are necessary but **not sufficient**.

## Useful negative result

Per `@D g3` honest scope: this fire **confirms** that a 4P+4C named-bar
swap WITHOUT (a) multi-stage cp.async pipelining and (b) Hilbert/super-
block L2 swizzle is strictly worse than the simpler 4-warp design.
The "headline TFLOPS" can drop by 6x vs N149 if you change too many
axes at once without re-tuning the pipeline depth.

The negative also clarifies that **single-session reach** without TMA /
cp.async.bulk / wgmma is at the N149 ceiling (0.847 @ M=8192); the
next ~0.15 gap to cuBLAS likely requires hardware primitives only
available on sm_90+ via async.bulk + wgmma + mbarrier (multi-session
campaign).

## Artifact integrity

- gen_sgemm_pwspec_named_bar_ptx.py: 4 shapes, pure-ASCII PTX
- host.c: nvcc -O2 -arch=sm_90, 256 thd/block, cuLaunchKernel via driver API
- measure.sh: plain `ssh ubu-2`, no SIDECAR_NO_POOL
- 4 .ptx files (1024..8192), driver-JIT loaded on sm_120
- result.json: bit-exact + perf measurements
- fire.log: stdout from ubu-2 run
- ptxas_info.log: cuFuncGetAttribute output
- compile.log: empty (ptxas 12.0 standalone + nvcc both silent on success)
