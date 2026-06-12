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

## 0. Perf boundary / honest scope — what own-GEMM IS and ISN'T

> **Read this before treating "beat cuBLAS" as a goal.** This is the hard-won, measured
> boundary of the route-(a) own-GEMM. It is settled; do not re-litigate it. Every number
> below traces to a verdict (cited inline).

**What it IS** — `route-(a)` pre-permute own-GEMM (gmma-INTER global pre-lay + no-swizzle TMA +
descriptor-direct, no in-kernel decode band) is a **bit-exact, device-resident, no-LLVM /
no-cuBLAS-call** TF32 GEMM:

- **Bit-exact**: `rel_rms 0.000e+00` (dev-vs-dev, f32-accum order) at **every** config across the
  entire PDEP/NST sweep — not a tolerance, an equality. This is the gate the in-place-descriptor
  route-(b)/w16 *failed* (floored at `rel_rms 1.107`, FALSIFIED).
- **At cuBLAS-TF32 PARITY @D=2048**: the frontier kernel (b14 MODE 8, NST=3, PDEP=2) measures
  **own ≈ 315 TFLOP/s, ratio 1.08×, PARITY=YES** — i.e. **~93% of the cuBLAS-TF32 roofline**,
  bit-exact, with no vendor call. (`F-GPU-ROUTEA-KEEPBAND-MEASURE.txt`, #3094, fresh H100 sm_90a,
  median of 3 reps.)

**What it ISN'T — NOT a cuBLAS BEAT.** cuBLAS-TF32 is the **roofline**; 1.08× is parity-seeking,
*not* superiority. And parity does **not** hold at all shapes:

- **@D=4096 it falls to ~1.50× slower** (own ≈ 284 TFLOP/s vs cuBLAS ≈ 427, PARITY=NO). The cause
  is **shape-rigidity**: route-(a) is **one fixed 128×128 plain-launch tile** at every D, while
  cuBLAS is **shape-adaptive** — at D=4096 cuBLAS scales UP +24.6% (larger tiles / split-K /
  persistent rasterization tuned to 132 SMs) while the fixed MODE 8 scales DOWN −9.9% (2× K-loop
  drain). Register-spill, occupancy-drop, and a D-independent ptxas ceiling are all **statically
  EXCLUDED** as the cause; the surviving classification is (d) large-D scheduling roofline =
  *shape-rigid vs shape-adaptive*. (`F-OP45-ROUTEA-D4096-CAP.txt`, #3096.)
  **GPU-RESOLVED (OP-45-GPU, real H100, `F-OP45GPU-OCCUPANCY-SWEEP.txt`):** the (d) sub-split is a
  **FIXABLE SCHEDULING STALL, NOT a hard HBM-bandwidth roofline.** T1 measured-confirmed 90 regs /
  0 spill / 96 KB/CTA / 2 CTA/SM (D-invariant → (a)/(b) measured-excluded). The D=4096 own kernel
  runs at only **~12–40 % of HBM3 peak** (arithmetic intensity 682 FLOP/byte ≫ the 104 FLOP/byte
  compute-bound threshold), so it is **compute/scheduling-bound** — there is bandwidth headroom, not
  a memory wall. (ncu HW-counters were infra-blocked by `RmProfilingAdminOnly=1`; the split was
  resolved by a g5-legal analytical roofline from the measured kernel wall-time.) MODE 7 persistent
  +swizzle measured @4096 for the first time does **NOT** recover the −9.9 % (~273 vs 284 TFLOP/s —
  a slight regress; closed-negative), so the fixable lever is **not** tile-rasterization. cuBLAS's
  +24.6 % large-D lever is a **better single-pass tile + CTA-swizzle, NOT split-K** (its top D=4096
  algo is `split_k=1` / `reduction=0`) — i.e. **reachable without forfeiting the bit-exact
  accumulation order**. Net: a beat path exists in principle (a better single-pass per-CTA tile/
  schedule, bit-exact-legal), but it is a genuine build, not a memory roofline to close.
  **OP-52 (real H100, `F-OP52-TF32-GAP-CLOSE.txt`) BUILT and MEASURED the CTA-swizzle half of that
  lever in ISOLATION** — a new MODE 9 (`gemm_og17_b14_swz`) = b14 MODE 8 math VERBATIM + a
  NON-persistent CTA-swizzle (1-CTA/tile grid, only the CTA→tile assignment order changed), which
  strips away MODE 7's persistent-loop confound. **Result: CTA-swizzle does NOT close the gap — it
  REGRESSES.** Best bit-exact swizzled @D=4096 = 280.5 TFLOP/s (vs the SWZ=0/MODE 8 baseline 285.1,
  −1.6 %; ratio 1.50× → 1.53×); every group-width SWZ∈{2,4,6,8,12,16} × PDEP∈{1,2} regressed, all at
  `rel_rms 0.000e+00`. This isolates OP-45-GPU T3 (MODE 7's @4096 regress was the **swizzle itself**,
  not the persistent loop) and matches T2's physics (compute-bound ⇒ an L2-locality CTA order cannot
  help). The in-tree "better single-pass tile" option (MODE 5 t256, 128×256) is **already measured
  closed-neg** @4096 (264.9 < 283.9, register-capped to 1 CTA/SM). So the surviving lever is a
  genuinely NEW bit-exact single-pass per-CTA tile/schedule (a kernel rewrite preserving 2 CTA/SM),
  **not** a launcher/index swizzle and **not** split-K — recorded as the OP-52 follow-up.
- The **FP16/BF16 W14 line is ~11.5× off** cuBLAS-FP16 (PARITY=NO; cuBLAS-FP16 roofline doubled to
  ~827 TFLOP/s). The **W10 composed-swizzle-decode summit is 70.7 TFLOP/s, 6.09× off** cuBLAS-TF32
  (the bit-exact pre-route-(a) frontier). Neither is a beat. (`.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W10.txt`,
  `F-FUSION-W14-*`.)

**The VALUE proposition** (mirrors the flame-side framing in
`project_flame_h100_h200_closeout`): own-GEMM's worth is **bit-exactness + device-residency +
no-LLVM compile-theorem** — a device GEMM we can call in-line where a persistent megakernel can
*never* call cuBLAS (a host API), end-to-end, with no vendor call and a bit-exact gate. It is
**NOT raw TFLOP/s-vs-cuBLAS**. Do not pursue "beat cuBLAS" as a forge goal; pursue completeness
(a path cuBLAS structurally cannot take), bit-exactness, and no-vendor-dependency.

**The path forward — IF a beat is ever pursued** (not a standing goal): the shape-adaptive
selector design below (§2–§6) + its CPU cost model + the **4 concrete config gaps** (64×64
small-tile for small-D under-fill · MODE 7 persistent measured @4096 · bit-exact split-K · NST-
adaptive launcher) are the levers. None exist in-tree today; each maps to a gated GPU-session
build mapped to OP-45 T1–T5 (§7). Until then, the boundary stands: **bit-exact parity @D=2048,
not a beat, shape-rigid @D=4096.**

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
| **large-D drain/scheduling-bound** | D > 3072 | many waves, deep K-loop | −9.9% K-drain; cuBLAS pulls +24.6% ahead | MODE 8 NST3 PDEP1 | a **NEW bit-exact single-pass per-CTA tile/schedule** (2 CTA/SM, deeper-K) — *MODE 7 persistent (T3) AND MODE 9 non-persistent CTA-swizzle (OP-52) both measured closed-neg @4096; split-K forbidden by g5* |

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

## 7. Handoff to the GPU session (maps to OP-45 T1–T5) — **RESOLVED on a real H100 (OP-45-GPU)**

All five tests ran on one H100 sm_90a (`F-OP45GPU-OCCUPANCY-SWEEP.txt`, ~$0.96, leak-0):

- **T1** (ptxas -v on MODE 8): **DONE** — 90 registers, **0 spill**, 96 KB/CTA → 2 CTA/SM,
  D-invariant. The (a) register-spill and (b) occupancy-drop exclusions are now **measured**, not
  just statically argued. MODE 5 t256 = 154 regs (the reg-cap, as assumed).
- **T2** (DRAM%/Tensor% @4096): **ncu INFRA-BLOCKED** (`RmProfilingAdminOnly=1`, a host kernel-
  module param a vast renter can't change). Resolved by a g5-legal **analytical roofline** from the
  measured kernel wall-time: D=4096 runs at **~12–40 % of HBM3 peak**, AI 682 ≫ 104 threshold →
  **compute/scheduling-bound, NOT a hard HBM roofline → FIXABLE stall.** The `drain_penalty` is
  recalibrated (anchored steeper K-drain, `c` 0.115→0.109): MODE8@4096 over-prediction **+9.2 % →
  +1.0 %**, ordering still PASS (honest residual: the drain is non-uniform across modes → a per-mode
  coefficient is the next 0-pod refinement).
- **T3** (MODE 7 persistent sweep @4096): **DONE — closed-negative.** Best persistent ~273 TFLOP/s
  vs MODE 8 284 (a slight regress); the hypothesized `l2_hot` benefit is **absent** (consistent with
  T2 compute-bound). GAP #2 is measured and does NOT pay; the fixable lever is not rasterization.
- **T4** (cuBLAS algo introspection @4096): **DONE** — cuBLAS's +24.6 % lever = better single-pass
  tile + CTA-swizzle, **`split_k=1` (NOT split-K)**. So the lever is **reachable bit-exact** (no
  reordering split-K needed); GAP #3 (split-K) is **not** the path — a better single-pass per-CTA
  tile/schedule is.
- **OP-52** (build + measure the T4 CTA-swizzle half, isolated): **DONE — closed-negative**
  (`F-OP52-TF32-GAP-CLOSE.txt`, real H100, ~$0.70, leak-0). New MODE 9 (`gemm_og17_b14_swz`) = b14
  MODE 8 VERBATIM + a NON-persistent CTA-swizzle (1-CTA/tile grid; only the CTA→tile order changed;
  SWZ=0 ≡ MODE 8 exactly). **CTA-swizzle does NOT close the @D=4096 gap — it REGRESSES**: best
  bit-exact swizzled 280.5 TFLOP/s (vs 285.1 SWZ=0, −1.6 %; ratio 1.50× → 1.53×), every SWZ × PDEP
  worse, all `rel_rms 0`. This **isolates T3** (the regress was the swizzle, not MODE 7's persistent
  loop) and matches T2 (compute-bound ⇒ L2-locality reorder can't help). MODE 5 t256 (the only
  in-tree larger single-pass tile) is already closed-neg @4096. **The surviving lever is a NEW
  bit-exact single-pass per-CTA tile/schedule (a 2-CTA/SM-preserving kernel rewrite)** — the OP-52
  follow-up; NOT a launcher swizzle and NOT split-K.

The cost model remains the harness: T2's drain recalibration dropped in as one coefficient; the
selector's argmax (MODE 8 at both D) is unchanged and still matches measurement. OP-52 confirms the
selector should NOT add a swizzled mode at D=4096 (it would never be the argmax — swizzle regresses).

---

## 8. Consumer-card sibling — the sm_120 OWN120 own-GEMM (a DIFFERENT kernel, different roofline)

> **Scope boundary.** §0–§7 are the **route-(a) Hopper sm_90a wgmma** own-GEMM (`wgmma.mma_async`,
> the 128×128 descriptor-direct kernel). The **consumer RTX 5070 (sm_120)** ISA does **not** carry
> wgmma (ptxas rejects it). The consumer card runs a **separate kernel** — **OWN120**
> (`self/native/mma_sm120/owngemm_sm120.cu`, `gemm_sm120`) built on the portable Ampere+
> **`mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32`** warp-MMA, 64×64 / BK=16 tiling +
> cp.async double-buffer + .v4 loads + .v2 epilogue (the OP-1/OP-1b tuning). Treat the two as
> distinct rooflines: the §0–§7 numbers are **Hopper H100**, the row below is **consumer 5070**.

**Consumer sm_120 datapoint (HEXA-0POD OP-54, `F-OP54-SUMMER-OWNGEMM-TF32.txt`, FREE pool RTX 5070
`summer`, CUDA 12.9, $0, bit-exact-tolerant gate PASS at every shape, rel-RMS ~1.3e-5..3.0e-5 vs
cuBLAS-TF32):**

| D (square) | OWN120 off-cuBLAS-TF32 (median ratio) | note |
|------------|---------------------------------------|------|
| 512  | 1.15× | small-D, NOT the closest |
| 768  | **0.95× ← CLOSEST** | own EDGES cuBLAS (24.5/23.3 TFLOP/s, stable every rep) |
| 1024 | 1.47× (noisiest) | 64×64-tile under-fill soft spot, contention-amplified |
| 1536 | 1.20× | mild K-drain |
| 2048 | 0.96× | near-parity (runner-up to D=768) |

- **The tuned OWN120 has CLOSED the original F-BENCH-5 gap.** F-BENCH-5's *raw* OWN120 baseline was
  **3.16×–6.85× off** cuBLAS-TF32 (S=768..4096). The OP-1/OP-1b tuning (cp.async double-buffer + .v4
  vectorized loads + .v2 epilogue, all bit-exact-preserving) brought it to **~0.95×–1.47×** off
  cuBLAS-TF32 — **reproduced on a second free consumer card** (summer) by OP-54.
- **No small-D-closer monotone trend on the consumer card.** The closest shape is the **mid** D=768
  (0.95×), NOT the smallest D=512 (1.15×); D=1024 is the WORST (under-fill + contention). The "simpler
  kernel loses less at small D" intuition does **not** hold here — the 64×64-tile OWN120's sweet spot
  is mid-D where the tiles fill the 50-SM RTX 5070 without smem/occupancy pressure (1024) or deep
  K-drain (1536).
- **Honest caveat:** summer was at **98% foreign contention** (a sibling job, untouched per g9) during
  the sweep, so the **absolute** TFLOP/s of both kernels are suppressed; the **off-cuBLAS ratio**
  (own÷cuBLAS, same loaded card, back-to-back) is the contention-robust metric. The gate is the
  same-dtype TF32-tolerant check (rel-RMS vs cuBLAS-TF32), NOT rel-RMS 0 dev-vs-dev — cuBLAS-TF32 does
  not expose its accumulation order. **Value = bit-exactness + device-residency + no-vendor-call on the
  FREE consumer card**, same framing as §0 — parity-seeking, not a beat.
