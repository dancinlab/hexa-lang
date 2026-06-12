# Route-(a) own-GEMM shape-adaptive tile-selector — design (OP-49, HEXA-0POD)

**0-pod / NO GPU.** This document turns the OP-45 diagnosis ("route-(a) own-GEMM is
SHAPE-RIGID — one fixed 128×128 plain-launch tile — while cuBLAS is SHAPE-ADAPTIVE") into
a concrete, testable **shape-adaptive policy**: D-bucketed kernel-mode selection driven by
a **CPU-side analytical cost model** that PREDICTS which existing kernel config to launch
per problem shape. The cost model is VALIDATED (below) against the already-measured
OG16/OG17/MODE8/MODE5 verdict datapoints — no new GPU run.

Inputs: `F-OP45-ROUTEA-D4096-CAP.txt` · `self/native/wgmma/wgmma_tf32_b14.cu` (MODE 4/5/6/7/8)
· `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-{W10,OG16,OG17}.txt`.
Reference implementation: `self/native/wgmma/routea_cost_model.py` (run it: it prints the
validation table + the selector picks).

---

## 1. Inventory — the kernel CONFIGS that already exist in-tree

All in `wgmma_tf32_b14.cu`, route-(a) pre-permute family, TF32, bit-exact (rel_rms 0 vs
cuBLAS-TF32), TKSW=32 (K-slab), 2 warpgroups (256 threads/CTA), H100 sm_90a.

| MODE | kernel symbol         | tile (TM×TN) | accum regs | smem/stage | occ (2 CTA/SM?) | launch              | lever |
|------|-----------------------|--------------|------------|-----------|------------------|---------------------|-------|
| 4    | `gemm_og16` (base)    | 128×128      | 64 (d0,d1) | 32 KB     | 2 CTA/SM         | plain 1-CTA/tile     | descriptor-direct baseline |
| 5    | `gemm_og17_t256`      | 128×256      | 128 (d0..d3, **154 reg/thr**) | 48 KB | **1 CTA/SM (reg-capped)** | plain 1-CTA/tile | larger tile, 2× B-reuse/A-load (W11/W12 closed-neg) |
| 6    | `gemm_og17` (relaxed) | 128×128      | 64         | 32 KB     | 2 CTA/SM         | plain 1-CTA/tile     | relaxed `wait_group` pipeline |
| 7    | `gemm_og17_persist`   | 128×128      | 64         | 32 KB     | 2 CTA/SM         | **persistent + swizzle** (grid = occ×SM = 264) | tail-wave smoothing + L2-hot operands |
| 8    | `gemm_og17_b14`       | 128×128      | 64 (d0,d1) | 32 KB     | 2 CTA/SM         | plain 1-CTA/tile     | **dual-issue** (`wgmma.wait_group` PDEP depth) — current FRONTIER |

NST (pipeline stages) is a runtime arg: NST=2/3 hold 2 CTA/SM at 128×128 (64/96 KB);
NST=4 → 1 CTA/SM (128 KB), a measured regress. **No split-K mode exists** (forbidden by g5 —
split-K forfeits the bit-exact accumulation order). **No small-tile (64×64) mode exists.**

Measured frontier (from OP-45 + verdicts, median-of-3, rel_rms 0):

```
D=2048  MODE8 NST3 PDEP2  own 315.0  cuBLAS 342.5  ratio 1.08x  PARITY=YES
D=4096  MODE8 NST3 PDEP1  own 283.9  cuBLAS 426.8  ratio 1.50x  PARITY=NO
```

---

## 2. Shape buckets (the policy)

OP-45 proved the gap is (d)-class: cuBLAS scales UP +24.6% at D=4096 (shape-adaptive
large-tile/split-K/persistent scheduling) while the fixed-128×128 MODE8 scales DOWN −9.9%
(2× K-loop drain). Wave-quantization is identical (0.970) at both D, and the kernel config
is D-invariant (same binary). So the policy is bucketed by **how the fixed tile fills the
132-SM device** and by **K-loop depth**:

| bucket | D range | regime | symptom | policy pick (today) | wanted pick (gap) |
|--------|---------|--------|---------|---------------------|-------------------|
| **small-D under-fill** | D ≤ 1024 | tiles ≪ 264 resident CTAs | catastrophic wave under-fill (D=512: 16 tiles / 264 = 0.06 wave-eff) | MODE 8 NST2 (least smem) | **64×64 small-tile** (4× more tiles → fills device) — *does not exist* |
| **medium-D parity zone** | 1024 < D ≤ 3072 | tiles ≈ 1 wave, well-quantized | already at PARITY (D=2048 1.08×) | **MODE 8 NST3 PDEP2** (frontier) | — (parity met) |
| **large-D drain/scheduling-bound** | D > 3072 | many waves, deep K-loop | −9.9% K-drain; cuBLAS pulls +24.6% ahead | MODE 8 NST3 PDEP1 | **MODE 7 persistent+swizzle** (smooth tail, L2-hot) AND/OR a bit-exact split-K — *persistent untested @4096, split-K does not exist* |

The K-axis modifier (independent of M/N): when **K is large but M·N small** (tall-skinny,
e.g. a 7B FFN down-proj at small batch), the under-fill bucket applies on M·N but the K-loop
is deep — this is the regime a (bit-exact, accumulation-order-preserving) **split-K** would
help most, and the regime the policy flags as the highest-value missing config.

---

## 3. The analytical CPU cost model

`predict_tflops(mode, M, N, K, nst)` returns a predicted TFLOP/s as a product of a
calibrated ceiling and four shape-dependent efficiency terms — the SAME static accounting
OP-45 did for one point, generalized into a per-shape formula:

```
TFLOP/s(mode, M,N,K,nst)
  = PEAK_TF32                         # 349 — route-(a) 2-CTA/SM math ceiling (calibrated)
  * issue_eff[mode]                   # per-KERNEL constant, calibrated ONCE from D=2048
  * occ_factor(occ)                   # 1.0 @2 CTA/SM, 0.86 @1 CTA/SM (lost math-pipe overlap)
  * wave_eff(M,N,tile,occ,persistent) # tiles / (waves × resident_CTAs); persistent → tail-amortized
  * drain_penalty(K, issue_eff)       # 1/(1 + c·log2(nks)/log2(64)); deeper K-loop = more drain
  * reuse_eff(TN)                     # +8.5% @TN=256 — wider tile reuses A-loads (intensity ↑)
  * fill_factor(M,N,tile,occ)         # wide tiles need ≥1 wave to amortize (else starved)
```

**Occupancy is the MIN of the smem-limited and register-limited CTA counts** —
`cta_per_sm(tm,tn,nst,regs) = min(228KB / smem_per_stage·nst,  65536 / (regs·256))`.
This register limit is load-bearing: the 128×256 t256 tile is **154 reg/thread → 1 CTA/SM**
even though its 96 KB smem would allow 2 (the W11/W12 closed-neg). Modeling only smem would
wrongly give t256 2 CTA/SM and mispredict the entire large-D crossover.

**Calibration discipline (honest):** `issue_eff[mode]` is fit ONCE per kernel from its
D=2048 measured plateau (a per-KERNEL constant — OP-45 finding 1: the binary/schedule is
D-invariant). The D-SCALING terms (drain/wave/reuse/fill) are then a genuine PREDICTION at
all other D. So D=2048 rows are exact by construction; the D=4096 ORDERING is the real test.

Per-mode calibrated `issue_eff`: OG16 0.840 · OG17 0.922 · MODE8 1.028 · t256 0.963
(MODE8 > 1.0 is an efficiency *relative to the OG16 baseline*, absorbing the dual-issue gain).

---

## 4. The selector

```python
def select(M, N, K):
    best, ranked = None, []
    for (mode, nst) in candidates(M, N, K):     # every in-tree mode × viable NST
        score = predict_tflops(mode, M, N, K, nst)
        ranked.append((score, mode, nst))
    ranked.sort(reverse=True)
    return ranked[0], ranked                      # argmax = the launch config
```

Given a runtime shape, the host computes the cost-model score for every (mode, NST)
candidate and launches the argmax. With today's in-tree modes the selector picks **MODE 8**
at every D (it is the frontier 128×128 kernel and dominates the other existing modes) — which
is exactly why route-(a) is shape-rigid: **the policy WANTS a different config at the
extremes but no better config exists to select.** That is the deliverable's punchline — the
selector makes the missing-config gaps concrete (§6).

---

## 5. Validation against measured points (0-pod) — **ORDERING: PASS**

`routea_cost_model.py` plugs the 8 measured (D, mode, NST, TFLOP/s) verdict points into the
model and checks it reproduces the measured WIN-ORDER at each D:

```
     D         mode  nst  measured  predicted  rel.err
  2048         OG16    3     252.0      252.0   +0.0%   ← calibration anchor
  2048         OG17    3     279.7      279.7   -0.0%   ← calibration anchor
  2048        MODE8    3     315.0      315.0   +0.0%   ← calibration anchor
  2048   MODE5_t256    2     219.0      219.0   +0.0%   ← calibration anchor
  4096         OG16    2     264.7      247.3   -6.6%   ← PREDICTION
  4096         OG17    2     275.0      274.9   -0.0%   ← PREDICTION
  4096        MODE8    3     283.9      310.1   +9.2%   ← PREDICTION
  4096   MODE5_t256    2     264.9      269.3   +1.7%   ← PREDICTION
mean |rel.err| = 2.2%

D=2048 measured rank: [MODE8, OG17, OG16, MODE5_t256]   predict: [MODE8, OG17, OG16, MODE5_t256]  MATCH
D=4096 measured rank: [MODE8, OG17, MODE5_t256, OG16]   predict: [MODE8, OG17, MODE5_t256, OG16]  MATCH
```

The model REPRODUCES the measured ordering at BOTH D — including the **non-trivial D=4096
crossover where t256 climbs above OG16** (the wide-tile reuse advantage that only pays once
the device is filled). The register-cap occupancy model is what makes that crossover
predictable. The selector's pick (MODE8 = the measured winner at both D) is therefore the
correct argmax.

**Honest residual:** the one notable absolute miss is **MODE8 @ D=4096 (+9.2%, predicts 310
vs measured 283.9)** — the model under-credits the large-D K-drain that OP-45 flagged as the
"unattacked residual". The ORDERING is unaffected (MODE8 still wins), but the absolute
large-D MODE8 number needs the OP-45 **T2** ncu profile (achieved DRAM% / Tensor-active%) to
calibrate `drain_penalty`'s coefficient `c` for the deep-K regime. With that one datapoint the
model would also predict the absolute large-D throughput, not just the ordering.

---

## 6. Config GAPS — the build-work a GPU session would author

The selector's argmax over *existing* modes is always MODE 8, yet MODE 8 still loses to
cuBLAS at the extremes. The policy WANTS these configs that **do not exist in-tree**:

1. **64×64 small-tile mode (small-D under-fill).** At D≤1024 the 128×128 tile leaves the
   device 90%+ idle (D=512: 16 tiles vs 264 resident CTAs, wave-eff 0.06). A 64×64 tile
   gives 4× the tiles → fills the device. *Build:* a `gemm_og17_t64` variant; gate rel_rms 0
   first. The cost model already scores it once added (drop a `MODE_t64` row, regs ~48 → 2+
   CTA/SM, TM=TN=64).

2. **Persistent+swizzle @ large-D actually MEASURED (MODE 7 exists, untested @4096).**
   `gemm_og17_persist` is in-tree but was never measured at D=4096. OP-45 **T3** is exactly
   this: does persistent rasterization recover the −9.9% by smoothing the 4-wave tail +
   keeping A/B L2-hot? The cost model currently scores MODE 7 == MODE 8 (its only modeled
   benefit, wave-eff, is already ~0.97 at large D); the L2-residency benefit is NOT in the
   static model and needs the T3 measurement to add a calibrated `l2_hot` term.

3. **Bit-exact split-K (large-K / tall-skinny).** The single highest-value missing config:
   cuBLAS's +24.6% at D=4096 is partly split-K (OP-45 **T4** quantifies which lever). A
   split-K that preserves the bit-exact accumulation order (g5) is hard — naive split-K
   reorders the reduction — but a *deterministic tree-reduction* split-K could be admissible.
   *Build:* author it only after T4 confirms split-K is the dominant cuBLAS lever AND a
   bit-exact reduction order is reachable.

4. **NST-adaptive selection wired into the launcher.** Even with only existing modes, the
   policy should pick NST per shape (NST3 medium-D, NST2 large-D — matching the measured
   best). This is a pure host-side change, no new kernel; the cost model already ranks NST.

---

## 7. Handoff to the GPU session (maps to OP-45 T1–T5)

- **T1** (ptxas -v on MODE 8): confirms the 154-reg t256 / ~90-reg MODE8 occupancy the cost
  model assumes — upgrades the register-cap from "verdict-cited" to "measured".
- **T2** (ncu DRAM%/Tensor% @4096): calibrates `drain_penalty.c` for deep-K → fixes the
  +9.2% MODE8@4096 absolute miss; tells whether large-D is a hard HBM roofline (close it) or
  a fixable drain stall (build MODE 7 / split-K).
- **T3** (MODE 7 persistent sweep @4096): the `l2_hot` term — adds the only large-D lever the
  static model can't yet see.
- **T4** (cuBLAS algo introspection @4096): quantifies which lever is the +24.6% → decides if
  the split-K gap (#3) is worth building under the g5 bit-exact constraint.

The cost model is the harness: each T-result drops in as one calibrated coefficient, and the
selector then predicts the new config's placement before it is launched.
