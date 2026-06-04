# H1-RECON — anima Lane G forge 3B/7B util-unblock vs LANDED HEXA-FUSION work

Reconciliation of anima→hexa-lang handoff **80d47ccc** against HEXA-FUSION work landed on
`origin/main` (verdicts in `.verdicts/hexa-fusion/`, kit at `~/hexa-fusion-cuda-kit/`).

g5-HONEST: every number below is cited verbatim from a named verdict. Where the handoff
context or the H1c job brief asserted a figure that **no verdict backs**, that is flagged
explicitly as UNVERIFIED rather than repeated as fact.

---

## 0. Handoff 80d47ccc — what anima asked for

> "anima Lane G forge 3B/7B util-blocked by clm_prod kernel-DAG ceiling. Whole-step
> CUDA-graph capture FALSIFIED (util MEAN 13.54% < 20%, eager 14.87%, fwd/bwd 13.19%,
> CE byte-eq) — serial fine-grained kernel DAG is the ceiling, NOT host-launch. Needs
> HEXA-FUSION kernel-fusion past L3-b (measure L3-c/L3-d/P2a) OR option-B device-resident
> CUDA-C full-step rewrite. anima has NO own forge driver (invokes clm_prod), no
> anima-side workaround."

The handoff's own baseline numbers are confirmed verbatim in
`~/hexa-fusion-cuda-kit/F-FUSION-GRAPH-WHOLESTEP-AB.txt`:
`g0 eager MEAN=14.87%`, `g1 fwd/bwd MEAN=13.19%`, `g1ws whole-step MEAN=13.54%`,
median 2% across all three, CE bit-identical (4.46624→3.64669). The host-removal axis is
**CLOSED-NEGATIVE** there: "The binding constraint is the SERIAL, FINE-GRAINED kernel DAG
at this problem size, not host launch overhead."

The handoff named **three** forward paths: (A) measure L3-c/L3-d/P2a fusion;
(B) option-B device-resident CUDA-C full-step rewrite (megakernel); plus the implicit
prerequisite (C) a cuBLAS-free own-GEMM so the megakernel is even reachable.

---

## 1. ASK → LANDED-STATUS table

| # | Handoff ASK | Status | Verdict (verbatim) |
|---|-------------|--------|--------------------|
| A1 | Fusion past L3-b — **L3-a** measured | DONE | `F-FUSION-L3A-GN-GELU-AB`: 🟢 byte-eq, util MEAN **+3.26pp (10.31%→13.57%)**, PEAK 62→100%, CE bit-identical |
| A2 | Fusion past L3-b — **L3-b** measured | DONE | `F-FUSION-L3B-GELU2-AB`: 🟢 byte-eq, **+1.01pp** stacked (base 7.53→l3a 9.20→l3a+b 10.21% MEAN, run-drifted baseline), CE bit-identical |
| A3 | **L3-c** (residual_add / pack-unpack) measured | **PARTIAL — BUILT, NOT MEASURED** | `F-FUSION-MEGAKERNEL-DESIGN`: "block-1 = L3-c"; runtime.c present at `~/hexa-fusion-cuda-kit/l3c-build/`. **No L3-c AB util verdict exists** on main or in kit. |
| A4 | **L3-d** (gelu2+pack2+router) measured | **PARTIAL — BUILT, NOT MEASURED** | `F-FUSION-MEGAKERNEL-DESIGN`: "Built as L3-d ... **(L3-d, UNMEASURED)**". runtime.c at `~/hexa-fusion-cuda-kit/l3d-build/`. No L3-d AB util verdict exists. |
| A5 | **P2a / further fusion** | PARTIAL | block-2 GN#2 residual: "needs a cooperative/persistent kernel ... **deferred**" (`F-FUSION-MEGAKERNEL-DESIGN`). `F-FUSION-GN-COOP-KERNEL-CLOSED-NEG` exists (cooperative GN closed-neg). |
| B  | option-B device-resident full-step **megakernel** | PARTIAL (design + prereq only) | `F-FUSION-MEGAKERNEL-DESIGN`: glue-block megakernel "realized except the 2 GN reductions (both grid-sync-walled)". No full-step megakernel measured. |
| C1 | cuBLAS-free **own-GEMM correctness** (megakernel prereq) | DONE | `F-FUSION-P1-OWN-GEMM-CORRECTNESS`: own-GEMM CORRECT, trains clm+llm cuBLAS-free (on main #2697). `F-FUSION-CUTLASS-GRADE-WMMA`: CORRECT, 1.13× of cuBLAS. |
| C2 | own-GEMM **performance / thru-parity** | DONE (named residual) | `F-FUSION-THRU-PARITY`: 2.24×→1.67× (46% of gap). `F-FUSION-SPLITK-SKINNY`: 🟢 1.67×→**1.24×** slower (combined ~80% of original gap closed; honest residual ~1.20–1.24× remains). |
| C3 | own-GEMM **util = cuBLAS-class** on a GEMM-bound load | DONE | `F-FUSION-OWN-GEMM-UTIL`: B200 sustained 2048³ — WMMA2 own **MEAN 89.9% PEAK 100%** ≈ cuBLAS 88.5%. |
| D  | (new) reframe: is util-low a code defect or workload-size? | DONE | `F-FUSION-D2-RIGHTSIZED`: 🟢 falsifier survived. SAME D1536 own-GEMM step → **98.00% MEAN on RTX 5070** vs **~13% on idle H100**. util is a WORKLOAD-SIZE property, not a code defect. |

**Counts:** DONE = 6 (A1, A2, C1, C2, C3, D) · PARTIAL = 4 (A3, A4, A5, B) · REMAINING(unstarted) = 0.

---

## 2. Key questions — honest answers

### Q1. Does landed L3-c/d "18.33% util" supersede the handoff's 13.54%?

**NO — and the 18.33% figure is UNVERIFIED.** This is the single most important honesty
correction in this recon.

- The H1c job brief states "L3-c + L3-d MEASURED GREEN 18.33% util (#2697,
  F-FUSION-L3C/L3D)". **No such verdict file exists** — neither
  `F-FUSION-L3C-GN-GELU-RESID-AB` nor `F-FUSION-L3D-MOE-BLOCK2-AB` is on `origin/main` or
  in `~/hexa-fusion-cuda-kit/`, and the string **"18.33"** appears in **zero** files under
  `.verdicts/` or the kit. `git show` of #2697 touched `F-FUSION-OWN-GEMM-UTIL` and
  `F-FUSION-P1B3-WMMA-GEMM`, not any L3-c/d AB.
- What #2697 *actually* landed: own-GEMM correctness (C1), CUTLASS-grade WMMA util (C3),
  and the L3-c/d **kernels** (`F-FUSION-P1-OWN-GEMM-CORRECTNESS` line 37: "+ the L3-c/d
  kernels; 55 launchers"). The kernels were BUILT into the runtime; their **incremental
  util-Δ was never A/B-measured**. `F-FUSION-MEGAKERNEL-DESIGN` says L3-d is "UNMEASURED"
  in plain text.
- The only MEASURED L3 fusion util numbers are L3-a (+3.26pp → 13.57% MEAN) and L3-b
  (+1.01pp, cumulative 10.21% MEAN on a run-drifted 7.53% baseline). Both sit **at or
  below** the handoff's 13.54% whole-step figure. So even the verified fusion does **not**
  clear the handoff's 20% gate, and there is **no measured 18.33%** to supersede it.

**Verdict on Q1:** the handoff's 13.54% is NOT superseded by a measured L3-c/d number,
because that measurement does not exist yet. L3-c/d are built-and-ready but UNMEASURED.

### Q2. Does D2's workload-size finding REFRAME the 3B/7B block?

**YES, it reframes the *root cause* — but it does NOT yet prove the 3B/7B *fix*, and there
is a real counter-signal.**

- `F-FUSION-D2-RIGHTSIZED` deterministically rules out "util-low = codegen defect": the
  byte-identical D1536 step that under-fills an idle H100 to ~13% MEAN (median 2%)
  **saturates an RTX 5070 to 98% MEAN** (every sample 98%, SM 98%, compute-bound), and
  2048³ gives 99%. So the kernel saturates a correctly-sized device. The H100's ~13% is
  "the H100 being too big for the D1536 model."
- This strongly supports the intuition that a **bigger model → bigger GEMMs → higher util
  on the same H100**. But the published evidence for "bigger D raises util on the H100" is
  **negative at the scales tested**: `F-FUSION-OCCUPANCY-WALL` line 8 measured
  `GRAPH=1 util-vs-D: 11.94% (D1536) → 10.39% (D2560)` — util **DROPPED** going D1536→D2560
  on the H100. The D2 win came from a *smaller GPU*, not a *bigger model on the same GPU*.
- 3B/7B is far larger than D2560, so the GEMM-saturation argument plausibly reverses the
  D2560 dip — but **that has not been measured.** Per the job brief, the 3B/7B-specific
  util measurement is **H1a's job and is in flight**, not landed.

**Verdict on Q2:** D2 reframes the block from "clm_prod kernel-DAG is broken" to "util is
workload/GPU-relative; right-size the GPU or the GEMM." It makes 3B/7B-util-unblock
*plausible by larger GEMMs*, but the on-H100 D-sweep counter-signal (util fell to D2560)
means the 3B/7B claim is **NOT yet demonstrated**. H1a must measure it.

### Q3. Is the megakernel (option-B) still genuinely needed?

**Not proven necessary, not proven sufficient-to-skip — it is now a SECOND-CHOICE lever,
not the only path.** The landed work moved option-B from "required" to "contingent":

- The handoff framed (A) fusion and (B) megakernel as the two ways past the kernel-DAG
  ceiling. The landed own-GEMM (C1/C2/C3) + D2 reframe open a **third** route the handoff
  did not have: **right-sizing** (GPU-relative util) and **own-GEMM saturation** (89.9% on
  a large sustained GEMM). If 3B/7B GEMMs are large enough to saturate the H100 (H1a),
  neither deep fusion nor the full megakernel is needed for util.
- The megakernel itself is **not blocked** anymore: `F-FUSION-OWN-GEMM-UTIL` says own-GEMM
  "unblocks megakernel" (the cuBLAS-free prereq C1 is met). But it remains **walled** at
  the 2 GroupNorm full-y reductions, which need cooperative/grid-sync kernels
  (`F-FUSION-MEGAKERNEL-DESIGN`; cooperative GN is closed-negative in
  `F-FUSION-GN-COOP-KERNEL-CLOSED-NEG`). So even if pursued, option-B has a known residual.

**Verdict on Q3:** the megakernel is *no longer the mandatory path* — fusion + own-GEMM +
right-sizing may suffice — but whether it is *needed* hinges entirely on the unmeasured
3B/7B util (H1a). If 3B/7B GEMMs saturate the H100, option-B is unnecessary; if they don't,
option-B (with its GN grid-sync wall) is back on the table.

---

## 3. Overall verdict

**anima Lane G forge 3B/7B util-unblock = PARTIALLY RESOLVED (root-cause re-characterized,
3B/7B-specific fix NOT yet measured).**

What the landed work genuinely resolved:
- The **root-cause framing is corrected**: util-low is a WORKLOAD-SIZE / GPU-relative
  property, NOT a clm_prod codegen defect (`F-FUSION-D2-RIGHTSIZED`, deterministic
  closed-negative on the "code defect" axis). This is a stronger and more useful finding
  than the handoff's "kernel-DAG is the ceiling."
- The **own-GEMM prerequisite is fully met**: cuBLAS-free correct (C1), util cuBLAS-class
  on a saturated GEMM (89.9%, C3), thru-parity to ~1.24× (C2). This unblocks the
  megakernel and proves the kernel is not the bottleneck on a right-sized load.

What genuinely REMAINS for anima Lane G:
1. **The 3B/7B-specific util is UNMEASURED** (H1a, in flight). Until a 3B/7B forge step is
   run on the H100 and util sampled, the unblock is *predicted*, not *demonstrated*. The
   on-H100 D-sweep (11.94%→10.39%, D1536→D2560) is a live counter-signal that must be
   overturned at 3B/7B scale.
2. **L3-c and L3-d are BUILT but UNMEASURED.** There is no "18.33%" verdict; the job
   brief's figure is unverified. A clean L3-c/d A/B util run (kernels already in
   `~/hexa-fusion-cuda-kit/l3{c,d}-build/runtime.c`) is the cheapest next measurement.
3. **option-B megakernel** is unblocked-but-walled at the 2 GroupNorm grid-sync reductions;
   only needed if H1a shows 3B/7B still under-fills the H100.

**Bottom line:** NOT "resolved-by-landed-work" and NOT "still-needs-megakernel" as a
certainty. It is **PARTIALLY resolved**: the landed work re-characterized the problem and
removed the cuBLAS-free blocker, but the decisive 3B/7B util number — the one that would
say whether right-sizing/larger-GEMMs already unblocks anima, or whether deeper
fusion/megakernel is required — has not been measured. H1a owns that measurement.

---

## 4. Verdict provenance (files cited)

- `~/hexa-fusion-cuda-kit/F-FUSION-GRAPH-WHOLESTEP-AB.txt` — handoff 13.54% baseline (CLOSED-NEG host-removal)
- `.verdicts/hexa-fusion/F-FUSION-L3A-GN-GELU-AB.txt` — L3-a +3.26pp
- `.verdicts/hexa-fusion/F-FUSION-L3B-GELU2-AB.txt` — L3-b +1.01pp (cum 10.21%)
- `.verdicts/hexa-fusion/F-FUSION-MEGAKERNEL-DESIGN.txt` — L3-c/L3-d built; L3-d "UNMEASURED"; GN grid-sync wall
- `.verdicts/hexa-fusion/F-FUSION-P1-OWN-GEMM-CORRECTNESS.txt` — own-GEMM correct, L3-c/d kernels in build
- `.verdicts/hexa-fusion/F-FUSION-CUTLASS-GRADE-WMMA.txt` — own-GEMM 1.13× of cuBLAS
- `.verdicts/hexa-fusion/F-FUSION-OWN-GEMM-UTIL.txt` — WMMA2 89.9% util ≈ cuBLAS; "unblocks megakernel"
- `.verdicts/hexa-fusion/F-FUSION-THRU-PARITY.txt` — 2.24×→1.67×
- `.verdicts/hexa-fusion/F-FUSION-SPLITK-SKINNY.txt` — 1.67×→1.24×
- `.verdicts/hexa-fusion/F-FUSION-D2-RIGHTSIZED.txt` — 98% (RTX 5070) vs ~13% (H100), same D1536 step
- `.verdicts/hexa-fusion/F-FUSION-OCCUPANCY-WALL.txt` — util-vs-D: 11.94%→10.39% (D1536→D2560) on H100
- `.verdicts/hexa-fusion/F-FUSION-GN-COOP-KERNEL-CLOSED-NEG.txt` — cooperative GN closed-negative

NOTE (honesty): the strings `F-FUSION-L3C-GN-GELU-RESID-AB`, `F-FUSION-L3D-MOE-BLOCK2-AB`,
and the figure `18.33%` named in the H1c brief do NOT exist in this repo or kit as of
`origin/main` HEAD. They are recorded here as UNVERIFIED, not as findings.
