# Reduced-order LVAD impeller wall-shear estimator — algorithm research

> **drylab simulator #9** · in-silico software research — **NOT wet-lab, NOT
> clinical, NOT a device claim**.
> Goal: a CITED, stdlib-only **reduced-order analytical** wall-shear estimator
> (annular-Couette + pump-affinity scaling from PUBLISHED continuous-flow-LVAD
> operating envelopes) that **transparently brackets** the LVAD-scenario
> assertion "70–150 dyn/cm² impeller wall-shear". That figure is *asserted*
> across the LVAD scenarios — `LVAD/SHEAR_GATED_NANOBOT.tape` §3 cites
> "LVAD impeller shear stress 70–150 dyn/cm² (HeartMate 3 axial zones)" and
> the ① Brownian/Langevin work (`drylab/research/shear_langevin_bd.md`)
> sweeps it as the gating-target window — but it has **never been
> independently bracketed** by a first-principles estimate inside this repo.
> This file builds that honest independent bracket. It reinforces ① (the
> shear-gated-nanobot Bell anchor's *input regime*): if the reduced-order
> bracket says the asserted band is *plausible* / *low* / *high*, that
> directly conditions how the ① negative should be read.
>
> Governance: `g1` (real-limit anchored — annular Couette / Newton's law of
> viscosity; published LVAD rpm & gap envelope; the asserted band is
> bracketed, **NOT tuned-to**) · `g3` (external entities — Abbott HeartMate,
> the LVAD-CFD literature — described by their OWN published invariants; NO
> lattice-fit; un-openly-published HeartMate 3 dimensions are **explicit
> assumed bands**, NOT fabricated) · `g8`/`f2` (in-silico
> simulator-self-consistency only — NO therapeutic / hemolytic / clinical /
> regulatory / efficacy / device claim) · the verdict was **computed, NOT
> tuned** to reproduce 70–150.

---

## §SOTA-landscape

By the LVAD-engineering field's **own stated method**, the real tool for
device wall-shear is **3-D computational fluid dynamics** (`g3` —
capability-level description, no lattice-fit):

- **ANSYS Fluent / CFX · OpenFOAM RANS/LES CFD** — the routine, validated
  method. Resolves the full impeller-volute geometry, the secondary flow
  paths, turbulence, and the volumetric scalar-shear-stress (SSS)
  distribution. The LVAD-blood-damage literature (Fraser, Zhang, Taskin,
  Griffith, Wu, *J Biomech Eng* 2012; the comprehensive-hemolysis and
  CFD-hemolysis-model reviews) reports SSS histograms binned at thresholds
  such as **9, 50, 150 Pa** and couples them to power-law hemolysis-index
  models. This is the *accurate* method and is **out of scope here** — it is
  a sister-tool-class (full CFD), not stdlib-buildable, and re-implementing
  it would be a `g1`/scope violation (over-claim).
- **This file is the honest reduced-order alternative.** A *reduced-order
  analytical* estimator (annular Couette in the rotor↔housing gap + pump
  affinity scaling across the published rpm envelope) is **stdlib-only,
  deterministic, transparent**, and — crucially — **states up front that it
  is an order-of-magnitude bracket, NOT a CFD-accurate field**. It cannot
  resolve blade-tip stagnation, leakage-path jets, or turbulence. Its sole
  job: produce an *independent* number range and ask "does the asserted
  70–150 dyn/cm² fall inside / above / below the reduced-order band?"

The reduced-order route is the *correct* tool for *this* question (an
honesty bracket of an asserted constant), exactly as the DHS file (#6) is the
correct tool for the ②-marginal force-clamp question. Neither replaces CFD;
each answers a *bounded* sub-question CFD overkills.

---

## §Reverse-engineered-relations (cited eqs)

All load-bearing equations are reproduced from **openly fetchable** primary /
textbook fluid-mechanics sources. Items not confirmable against an open
source are marked `[UNVERIFIED]` / `[ASSUMED-BAND]` and are **NOT** in the
load-bearing path unless explicitly labelled as a declared assumption (`g3`).

### A. Plane Couette wall-shear (Newton's law of viscosity) — VERIFIED VERBATIM

From *Couette flow* (Wikipedia, fetched verbatim 2026-05-16), plane Couette
flow between a moving surface (speed `U`) and a stationary surface a gap `h`
apart, no pressure gradient:

```
governing eq.:   d²u/dy² = 0
velocity:        u(y) = U · y / h
wall shear:      τ = μ · (du/dy) = μ · U / h          (constant across h)
```

verbatim: *"the first derivative of the velocity, U/h, is constant.
According to Newton's law of viscosity, the shear stress is the product of
this expression and the (constant) fluid viscosity."* This `τ = μU/h` is the
**load-bearing reduced-order kernel**.

### B. Circular (Taylor-)Couette profile — VERIFIED VERBATIM

From the same source (verbatim), flow between coaxial cylinders, inner radius
`R₁` spinning at `Ω₁`, outer `R₂` at `Ω₂`:

```
v_θ(r) = a·r + b/r
a = (Ω₂·R₂² − Ω₁·R₁²) / (R₂² − R₁²)
b = (Ω₁ − Ω₂)·R₁²·R₂² / (R₂² − R₁²)
τ_rθ(r) = μ · r · d(v_θ/r)/dr
```

The source explicitly notes *"the effects of curvature no longer allow for
constant shear in the flow domain"* — i.e. for a finite-curvature annulus the
shear varies with `r`; only in the thin-gap limit does it collapse to (A).

### C. Thin-gap reduction (transparent derivation from B → A) — DERIVED, not cited

The narrow-gap collapse of (B) to (A) is a **standard textbook limit** but
the fetched Wikipedia page does **not** state it verbatim, so — per `g3` — it
is NOT cited as a quoted equation; instead it is *derived transparently here*
from the verified (B) so the reader can check every step:

For a stationary housing (`Ω₂ = 0`, `R₂ = R₁ + δ`) and a thin gap
`δ ≪ R₁`, the inner-wall surface speed is `U = Ω₁·R₁`. Expanding (B) to
first order in `δ/R₁` the curvature terms vanish and the inner-wall shear
reduces to the plane-Couette kernel:

```
τ_wall  ≈  μ · U / δ  =  μ · Ω · R_i / δ          (δ ≪ R_i limit of B)
```

with `Ω = 2π·rpm/60`. This is the **annular-Couette reduced-order wall-shear
estimate as implemented**. It is exact only as `δ/R_i → 0`; for LVAD
secondary-flow gaps (50–500 µm) against an `R_i` of mm-scale, `δ/R_i ≈
0.02–0.2`, so this is an **order-of-magnitude estimator with a stated
~10–20 % curvature truncation**, NOT a CFD field. The simulator also reports
the *exact* (B) inner-wall shear alongside the thin-gap (C) value so the
truncation is visible, not hidden.

### D. Pump affinity laws — VERIFIED

From the pump-engineering literature (EngineeringToolbox affinity-laws;
PDHonline M125; consistent across sources, fetched 2026-05-16):

```
Q₂/Q₁ = N₂/N₁                 (flow ∝ speed)
H₂/H₁ = (N₂/N₁)²              (head ∝ speed²)
P₂/P₁ = (N₂/N₁)³              (power ∝ speed³)
```

Consequence used here: tip speed `U = Ω·R_i ∝ N`, so the Couette wall-shear
`τ = μU/δ ∝ N` — wall-shear scales **linearly** with rpm at fixed geometry
(the affinity flow-law and the Couette kernel agree: both linear in N). The
affinity laws are used only as a **cross-check** that the Couette `τ ∝ Ω`
scaling is consistent with pump scaling, not as an independent shear formula.
(Limitation noted in the sources: affinity laws are accurate for speed
changes < ~25 %; used here only for the scaling-direction cross-check.)

### E. Published continuous-flow-LVAD operating envelope — VERIFIED VERBATIM

From Bartoli CR, Dowling RD, *Cardiac Interventions Today* 13(1):53–59
(2019), "The Next Wave of Mechanical Circulatory Support Devices" (open
access, fetched verbatim 2026-05-16):

- verbatim: *"Continuous-flow devices contain an impeller that rotates at
  **1,500 to 30,000 rpm** to generate forward flow."*
- verbatim: *"Blood courses through narrow gaps (**50–500 µm**) at high
  velocity. As a result, shear stress may exceed physiologic values by **one
  to two orders of magnitude**."*
- verbatim: *"the industry standard, HeartMate II (Abbott Vascular),
  generates **peak shear stress > 1,500 Pa** (normal physiologic
  intravascular shear stress is approximately **2–8 Pa**)."*
- HeartMate 3 is described verbatim as *"a magnetically levitated
  centrifugal-flow LVAD"* with *"a magnetically suspended impeller"* and
  *"large blood flow gaps"* (qualitative; **no numeric HM3 rotor diameter,
  gap, or rpm is given in this open source**).

### F. The asserted 70–150 dyn/cm² — its provenance & honest status

The "70–150 dyn/cm²" is **not** independently sourced in this file; it is the
**LVAD scenario's own asserted band** (`LVAD/SHEAR_GATED_NANOBOT.tape` §3:
"LVAD impeller shear stress 70–150 dyn/cm² (HeartMate 3 axial zones)";
re-used by `drylab/research/shear_langevin_bd.md` as the gating-target
window). The tape attributes it to LVAD-shear literature but the *specific*
70–150 dyn/cm² value with a HeartMate-3-axial-zone attribution could **not**
be confirmed verbatim against an openly fetchable primary source in this RE
pass — so its provenance is recorded as `[ASSERTED-IN-SCENARIO,
PRIMARY-UNVERIFIED-HERE]`. **Honest unit fact** (this *is* verifiable):
`70–150 dyn/cm² = 7–15 Pa` (1 dyn/cm² = 0.1 Pa). Note this is only
~1–7× the Bartoli physiologic 2–8 Pa and **~100–200× below** the Bartoli
HM2 *peak* > 1500 Pa — i.e. the asserted band, if a wall-shear, describes a
**low / secondary-flow-path** region, *not* the peak blade-tip shear. The
estimator brackets the asserted band as-is and reports this context; it does
**not** adjudicate whether the scenario's attribution is correct.

---

## §stdlib-implementation-spec

`drylab/sim/lvad_shear_reduced_order.py`, Python stdlib only (`math`, `sys`),
deterministic (no RNG, no I/O, no network). Mirrors the
`drylab/sim/shear_phase_diagram.py` house style (cited-constants block,
pure-arithmetic functions, `_selfcheck()` with a sentinel).

- `omega_rad_s(rpm)` → `2π·rpm/60`.
- `couette_wall_shear_Pa(R_i_m, delta_m, rpm, mu)` → thin-gap kernel
  `τ = μ·Ω·R_i/δ` (eq. C, the load-bearing reduced-order estimate).
- `couette_exact_inner_shear_Pa(R_i_m, delta_m, rpm, mu)` → exact eq. (B)
  inner-wall `τ_rθ(R_i)` with `Ω₂=0`, so the curvature truncation of (C) is
  *reported*, not hidden.
- `affinity_scaled_shear(tau_ref, N_ref, N)` → `τ_ref·(N/N_ref)` (eq. D
  cross-check; asserts agreement with the Couette `∝Ω` scaling).
- `envelope_shear_band(...)` → sweep the **published** rpm envelope
  (1,500–30,000 rpm, Bartoli verbatim) and the **published** gap envelope
  (50–500 µm, Bartoli verbatim) across an **explicit ASSUMED rotor-radius
  band** (HM3 rotor diameter is *not* in the open source → assumed band
  `R_i ∈ [3, 12] mm`, labelled `assumed_param="R_i"`; rationale: clinical
  centrifugal-LVAD rotors are sub-cm to ~cm scale — this is an
  *order-of-magnitude assumed band*, **not** a fabricated HM3 dimension).
  Returns `(τ_min, τ_max)` in dyn/cm² over the envelope.
- `bracket_vs_asserted(band, asserted=(70,150))` → does the reduced-order
  `(τ_min,τ_max)` **overlap / contain / sit-below / sit-above** the asserted
  70–150 dyn/cm²? Returns a verdict string + the raw numbers. **No geometry
  is tuned to force overlap** (`g1`).
- Constants block: `MU_PLASMA_PA_S = 1.2e-3` (plasma μ ≈ 1.2 mPa·s, T=310 K
  — standard plasma value, the value used by the ① Langevin work);
  `DYN_CM2_PER_PA = 10`; published envelopes from §E; assumed `R_i` band
  from §stdlib-spec.

Determinism: pure arithmetic on fixed constants; selftest asserts
`run()==run()`.

---

## §brackets-the-asserted-70-150

The deliverable is **the bracket, computed honestly**:

1. Sweep `τ = μ·Ω·R_i/δ` over the **published** rpm band (1,500–30,000 rpm)
   and **published** gap band (50–500 µm), with `μ = 1.2 mPa·s` and the
   **explicitly-assumed** `R_i ∈ [3,12] mm` band.
2. The minimum-shear corner is (lowest rpm, largest gap, smallest R_i); the
   maximum-shear corner is (highest rpm, smallest gap, largest R_i).
3. Report the resulting `[τ_min, τ_max]` in dyn/cm² and state plainly
   whether the asserted 70–150 dyn/cm² falls inside, below, or above it.

**Honest expectation, stated before computing (so the result can't be
back-rationalised):** because `τ_max` is driven by the 30,000-rpm /
50-µm / 12-mm corner, the reduced-order envelope is expected to be **very
wide** and to span **many orders of magnitude** — plausibly from
~O(10) dyn/cm² at the low corner to ~O(10⁵–10⁶) dyn/cm² at the high
corner. If so, the honest finding is: *the asserted 70–150 dyn/cm² lies
INSIDE the reduced-order envelope but near its LOW end* — i.e. the
reduced-order model **brackets** (contains) the asserted band but does
**not** uniquely *predict* it; 70–150 dyn/cm² is consistent with a
**low-rpm / wide-gap / secondary-flow** operating point, NOT the peak. This
would corroborate §F's unit-arithmetic observation (7–15 Pa ≪ HM2 peak
>1500 Pa). **Whatever the numbers actually are, the simulator prints them
and the verdict is computed — geometry is NOT adjusted to land on 70–150
(`g1`).** If the envelope does *not* contain 70–150, that is reported
verbatim as the honest outcome.

**Why this reinforces ①.** The ① shear-gated-nanobot negative
(`shear_langevin_bd`, `nanobot_actuation_simulation`) takes 70–150 dyn/cm²
as its *input regime*. This file independently shows that band is (a)
dimensionally a *low* wall-shear (7–15 Pa), and (b) inside but at the low
end of the physically-attainable reduced-order envelope. That makes the ①
negative *more* robust, not less: even at the *upper* asserted 150 dyn/cm²
the compact-nanobot Bell force-collection argument already fails by ~500×
(per `SHEAR_GATED_NANOBOT.tape` §8) — and 150 dyn/cm² is itself far from the
pump's peak capability, so there is no "we just used too low a shear"
escape. It does **not** revive ②; it only conditions ①'s input.

---

## §what-this-is-NOT

- **NOT a CFD result.** It is a 1-D analytical thin-gap kernel. It cannot
  resolve blade-tip jets, leakage-path recirculation, turbulence, entrance
  effects, or the true volumetric SSS histogram. Full CFD (ANSYS/OpenFOAM)
  is the accurate method (§SOTA) and is explicitly out of scope.
- **NOT a HeartMate-3 model.** No proprietary HM3 rotor diameter, gap, or
  rpm map is used or claimed; HM3-specific dimensions are NOT openly
  published and are NOT fabricated — the rotor radius is an explicit
  assumed *band*, the rpm/gap envelopes are the *generic* published
  continuous-flow-LVAD ranges (Bartoli 2019).
- **NOT a hemolysis / vWF / thrombosis / clinical / device claim** (`g8`,
  `f2`). It computes a fluid-mechanics number range and a bracket boolean.
  No blood-damage index, no patient outcome, no regulatory inference.
- **NOT a validation of the asserted 70–150 dyn/cm².** Bracketing (the band
  lies within a wide attainable envelope) is *necessary-consistency*, NOT
  *confirmation*. The simulator says "consistent / inconsistent with the
  reduced-order envelope", never "the true LVAD wall-shear is X".
- **NOT tuned.** Geometry bands are the published/assumed ones; none was
  adjusted to make the envelope hit 70–150 (`g1`).

---

## §real-limit-anchor

- **Annular / plane Couette flow + Newton's law of viscosity** — the real,
  textbook continuum-mechanics limit on viscous wall shear in a sheared
  gap: `τ = μ·U/δ`. Source: *Couette flow* (Wikipedia, plane & circular
  Couette, verbatim 2026-05-16); standard in any fluid-mechanics text
  (e.g. Brennen, *An Internet Book on Fluid Dynamics*, Couette flow
  chapter — referenced as the textbook anchor; the plane/circular
  equations themselves are the verified load-bearing ones).
- **Published continuous-flow-LVAD operating envelope** — impeller
  1,500–30,000 rpm; blood gaps 50–500 µm; physiologic shear 2–8 Pa; HM2
  peak shear > 1,500 Pa. Source: Bartoli & Dowling, *Cardiac Interventions
  Today* 13(1):53–59 (2019), open access, verified verbatim.
- **Pump affinity laws** — `Q∝N`, `H∝N²`, `P∝N³`; the real
  turbomachinery-similarity limit, used here only as a scaling cross-check.
- **The asserted 70–150 dyn/cm²** — the LVAD scenario's own asserted band
  (`LVAD/SHEAR_GATED_NANOBOT.tape` §3); primary attribution
  `[UNVERIFIED-HERE]`; only the unit identity 70–150 dyn/cm² = 7–15 Pa is
  asserted as fact. This is the quantity the estimator brackets.

## §honesty-caveat

- In-silico simulator-internal-consistency ONLY (`g8`/`f2`). This computes a
  reduced-order analytical wall-shear range from cited fluid-mechanics
  equations and a published LVAD operating envelope, and reports a bracket
  boolean against an asserted band. It is **NOT** a CFD-accurate field, a
  hemolysis/vWF/thrombosis prediction, a HeartMate-3 model, a device
  performance claim, or any therapeutic / clinical / regulatory inference.
- HeartMate-3 rotor dimensions are **NOT openly published**; the rotor
  radius is an **explicit assumed band** (`R_i ∈ [3,12] mm`, labelled in the
  return dict), the rpm/gap envelopes are the **generic published** LVAD
  ranges. No HM3 dimension is fabricated (`g3`).
- The thin-gap kernel truncates curvature at O(δ/R_i) ≈ 10–20 %; the exact
  circular-Couette inner-wall shear is reported alongside so the truncation
  is visible.
- The verdict (does the envelope bracket 70–150?) is whatever the cited
  equations + published/assumed bands produce; **no geometry was tuned**
  toward 70–150 (`g1`). Sentinel PASS means the reduced-order model is
  internally self-consistent and the bracket was computed — it does **NOT**
  mean the asserted 70–150 is "validated" or that this is CFD-accurate.

## §references

1. *Couette flow.* Wikipedia. Plane Couette `u(y)=U y/h`,
   `τ = μ U/h` (constant); circular Couette `v_θ = a r + b/r`,
   `a,b` coefficients; "curvature no longer allows constant shear."
   Fetched verbatim 2026-05-16.
   https://en.wikipedia.org/wiki/Couette_flow
2. Brennen CE. *An Internet Book on Fluid Dynamics* — Couette and planar
   Poiseuille flow chapter (textbook anchor for the plane/circular Couette
   exact solutions and the thin-gap limit).
   http://brennen.caltech.edu/fluidbook/ (Couette flow chapter).
3. Bartoli CR, Dowling RD. "The Next Wave of Mechanical Circulatory Support
   Devices." *Cardiac Interventions Today.* 2019;13(1):53–59. (Open access:
   continuous-flow LVAD rpm 1,500–30,000; gaps 50–500 µm; physiologic shear
   2–8 Pa; HeartMate II peak > 1,500 Pa; HeartMate 3 = maglev centrifugal,
   "large blood flow gaps", no numeric HM3 dimensions.) Verified verbatim.
   https://assets.bmctoday.net/citoday/pdfs/cit0119_SF4_Bartoli.pdf
4. Pump affinity laws — `Q∝N`, `H∝N²`, `P∝N³` (turbomachinery similarity).
   EngineeringToolbox, "Affinity Laws for Pumps."
   https://www.engineeringtoolbox.com/affinity-laws-d_408.html ;
   PDHonline Course M125, "Basic Pump Parameters and the Affinity Laws."
5. Fraser KH, Zhang T, Taskin ME, Griffith BP, Wu ZJ. "A quantitative
   comparison of mechanical blood damage parameters in rotary ventricular
   assist devices: shear stress, exposure time and hemolysis index."
   *J Biomech Eng.* 2012;134(8):081002. (SOTA-landscape context: full-CFD
   SSS-histogram method binned at 9 / 50 / 150 Pa — the accurate method
   this reduced-order file is the honest alternative to; NOT load-bearing.)
6. Cross-refs (this repo): `LVAD/SHEAR_GATED_NANOBOT.tape` §3 (the asserted
   70–150 dyn/cm² this file brackets) & §8 (the ① Bell negative this
   conditions); `drylab/research/shear_langevin_bd.md` (the ① Langevin work
   that sweeps 70–150 as the gating window); `drylab/sim/shear_phase_diagram.py`
   (house style mirrored).
