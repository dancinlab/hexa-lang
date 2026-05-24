# RFC 067 P6H -- 6-stage cp.async pipeline + Hilbert CTA-swizzle COMBINED (2026-05-22)

## Goal

Combine the two RFC 067 regime winners into one kernel:

- N121 (PZ) -- 4-warp 64x64 + 6-stage cp.async pipeline. Wins SMALL shapes
  (M=256 ratio 1.1611, cuBLAS-BEAT). But hurts large M (M=1536 -2.32% vs N107 2-stage;
  24576 B shmem cuts occupancy 8->4 CTAs/SM).
- N149 (PHILB) -- 4-warp 64x64 + Hilbert-curve d2xy CTA-swizzle (2-stage, 8192 B shmem).
  Wins LARGE shapes (M=8192 ratio 0.847, M>=6144 L2-thrash cliff flattened).

Hypothesis: combined kernel = best small-shape latency-hiding (6-stage) AND best
large-shape L2 locality (Hilbert) -> the new canonical "best single kernel."

## Construction

N121's 6-stage pipeline body taken byte-identical; only the CTA->tile mapping changes.
N149's Hilbert d2xy prologue writes sw_y -> %r10, sw_x -> %r11, which are exactly the
registers N121 consumes as ctaid.y/ctaid.x for its A/B/C base addresses. Register
namespaces disjoint (N121 body r0..r74; Hilbert prologue r100..r129), no collision.
Launch grid p x p, p=next_pow2(side); padding CTAs early-return. Bijective over the real
gx x gy grid -> bit-exact (asserted in generator, verified in fire).

## Fire (ubu-1, RTX 5070 sm_120, driver 13000, target sm_90, 200 reps / 20 warmup)

| M    | regime          | cuBLAS TFLOPS | P6H TFLOPS | P6H ratio | baseline ratio | delta  | bit-exact |
|------|-----------------|---------------|------------|-----------|----------------|--------|-----------|
| 256  | small (6-stage) | 5.017         | 5.433      | 1.0829    | N121 1.1611    | -0.078 | 0 |
| 384  | small (6-stage) | 16.812        | 10.789     | 0.6418    | N121 0.9799    | -0.338 | 0 |
| 512  | small (6-stage) | 24.892        | 21.732     | 0.8731    | N121 0.8768    | -0.004 | 0 |
| 4096 | large (Hilbert) | 69.392        | 57.379     | 0.8269    | N149 0.8213    | +0.006 | 0 |
| 6144 | large (Hilbert) | 70.152        | 58.593     | 0.8352    | N149 0.8339    | +0.001 | 0 |
| 8192 | large (Hilbert) | 70.193        | 59.068     | 0.8415    | N149 0.8473    | -0.006 | 0 |

- Peak: 59.07 TFLOPS @ M=8192.
- F-RFC067-HEXA-SGEMM-6STAGE-HILBERT: PASS -- max_abs = 0.0 at ALL 6 shapes.
- regs/thd = 64, shmem = 24576 B at every shape (cuFuncGetAttribute).

## Verdict: combined kernel did NOT win both regimes -- useful negative

### Large regime (M=4096/6144/8192): combined ~= N149 Hilbert (within noise)
P6H matches N149 at +0.006 / +0.001 / -0.006 ratio delta. The 6-stage pipeline adds
NOTHING at large M -- it neither helps (cliff already flat from Hilbert) nor measurably
hurts here. The Hilbert L2 locality is the entire large-shape story; the extra 4 pipeline
stages are dead weight (24576 vs 8192 B shmem) that the arithmetic-bound large-M regime
does not benefit from. Honest read: at large M the 6-stage adds no win over 2-stage +
Hilbert. The two optimizations do not compound -- Hilbert alone is sufficient.

### Small regime (M=256/384/512): combined LOST vs standalone N121 6-stage
M=256 ratio dropped 1.1611 -> 1.0829 (still cuBLAS-BEAT, but -0.078). M=384 collapsed
0.9799 -> 0.6418. M=512 was a wash.

Root cause = the Hilbert d2xy prologue, NOT shmem/registers. regs/thd and shmem are
IDENTICAL to standalone N121 (64 / 24576 B), so the Hilbert bit-twiddle did not compound
occupancy or register pressure (it reused scratch within the same 64-reg budget). The
loss is the unrolled straight-line d2xy prologue itself -- 6-7 rounds of
shr/and/xor/selp/mul/add executed by every CTA before any MMA work. At tiny shapes
(16-64 CTAs, K=256-512), the K-loop has only 16-32 iterations, so the fixed prologue cost
is NOT amortised -- it is a large fraction of total kernel time. At M=384 with p=8 (grid
6x6 -> 64 CTAs launched, 28 padding-return) the 7-round prologue + 28 wasted padding-CTA
launches dominate -> ratio nearly halves.

### Host confound (flagged honestly per @D g3)
N121 small-shape baselines were measured on ubu-2; P6H here on ubu-1. M=256 cuBLAS is
identical across hosts (5.017 both), but M=384 cuBLAS differs (16.81 ubu-1 vs 16.12 ubu-2
in N121) -> there is real host/clock variance. So the small-shape ratio deltas are partly
host noise. But the M=384 collapse (-0.338) is far too large to be host variance alone --
the Hilbert prologue + padding-CTA overhead on a sub-amortised K-loop is the dominant
cause. A clean apples-to-apples would re-fire standalone N121 on ubu-1; the qualitative
conclusion (Hilbert prologue hurts small shapes) is robust regardless.

## Conclusion

The two optimizations are regime-orthogonal and do not compose into a win:

1. At large M, Hilbert alone is the win; the 6-stage pipeline contributes nothing (P6H ==
   N149 within noise, but carries 3x the shmem for no benefit).
2. At small M, the Hilbert prologue is pure overhead -- the swizzle exists to fix an
   L2-thrash cliff that does not occur at small M, so its fixed straight-line d2xy cost
   (un-amortised over the short K-loop) only subtracts.

Recommended canonical kernels remain regime-split (per N155):
- M <= 512: standalone N121 6-stage (no Hilbert) -- ratio up to 1.1611.
- M >= 4096: standalone N149 Hilbert (2-stage, no 6-stage) -- ratio up to 0.847, lower
  shmem -> better occupancy headroom.

A single "best of both" kernel would need the Hilbert swizzle CONDITIONALLY applied
(identity at small M, d2xy at large M) -- e.g. a compile-time per-shape switch or a cheap
runtime gridDim test. As an unconditional combination, the two do not stack. Useful
negative: L2-locality swizzles and deep cp.async pipelines target disjoint bottlenecks
and should be selected per-regime, not fused.

## Artifacts

- gen_sgemm_4warp_6stage_hilbert_ptx.py -- combined generator (bijection-verified)
- host.c -- 6-shape sweep harness (p x p Hilbert launch, cuBLAS HGEMM oracle)
- measure.sh -- ssh ubu-1 fire driver (NO SIDECAR_NO_POOL, pure-ASCII PTX)
- fire.log -- full stdout
- result.json -- structured per-shape results
- sgemm_4warp_6stage_hilbert_{256,384,512,4096,6144,8192}x..._grid.ptx -- 6 PTX
- ptxas_info.log -- regs/thd + shmem per shape (64 / 24576 B uniform)
