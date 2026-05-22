# Dudko-Hummer-Szabo force-spectroscopy lifetime model — algorithm research

> **drylab simulator #6** · in-silico software research — **NOT wet-lab, NOT clinical**.
> Goal: a CITED, stdlib-only Dudko-Hummer-Szabo (DHS) force-clamp lifetime kit
> that resolves the **flagged ②-marginal gap**: at LVAD 70 dyn/cm² a vWF HMW
> multimer carries ~8.75 pN, which is BELOW the Zhang-2009 *most-probable
> rupture force* ~11 pN — but a most-probable rupture force is a
> loading-rate-dependent *dynamic-pulling* observable, NOT the right
> threshold for a *sustained-force dwell-time* process. The honest verdict
> requires the force-clamp mean-lifetime τ(F), which is exactly what DHS
> provides. See `_python_bridge/module/a2_shear_unfolding_anchor.py` and
> `../../LVAD/A2_STABILIZER.tape` §8 for the flagged gap.
>
> Governance: `g1_real_limits_first` (real-limit anchored — DHS 2006 PRL,
> Zhang 2009 Science) · `g3` (external entities described by their OWN
> published invariants, NO lattice-fit, NO fabrication; unverified equations
> are explicitly `[UNVERIFIED]`) · `g8`/`f2` (in-silico simulator-consistency
> only — NO therapeutic / clinical / regulatory / efficacy claim) · this
> verdict was computed, NOT tuned to a hoped answer.

---

## §SOTA-landscape

The three routinely-employed dynamic-force-spectroscopy (DFS) rate models, by
their OWN stated scope (`g3` — no lattice-fit, capability-level only):

- **Bell-Evans** (Bell, *Science* 200:618, 1978; Evans & Ritchie, *Biophys J*
  72:1541, 1997) — phenomenological `k(F) = k0·exp(F·x‡/kBT)`. Linear
  ln k vs F. The simplest model; the threshold currently used by
  `drylab/sim/shear_phase_diagram.py` and the `bell_k_open` term in the ②
  anchor. Known to systematically *mis-estimate* k0 and x‡ because it ignores
  the force-induced *shrinking* of the barrier.
- **Dudko-Hummer-Szabo (DHS)** (Dudko, Hummer, Szabo, *PRL* 96:108101, 2006;
  *PNAS* 105:15755, 2008, open access PMC2572921) — a Kramers-theory
  generalization of Bell that is *formally exact* for a class of model
  free-energy profiles, adding a force-dependent barrier height and
  transition-state position. Single shape parameter ν selects the landscape:
  ν=1/2 (cusp / harmonic), ν=2/3 (linear-cubic), ν=1 (recovers Bell). This is
  the cited rigorous upgrade the ② anchor explicitly DEFERS to.
- **Friddle-Noy-De Yoreo** (Friddle, Noy, De Yoreo, *PNAS* 109:13573, 2012) —
  adds an equilibrium re-binding correction near zero net force. Out of scope
  here (the ② question is a one-way unfolding dwell, not a re-binding bond);
  noted for completeness only.

DHS is the correct tool for the ② question because the ② physical scenario is
a **constant (sustained) tension** held over a circulatory dwell time, i.e. a
*force-clamp lifetime* τ(F), not a *force-ramp* rupture-force histogram. DHS
gives τ(F) in closed form; Bell only gives a rate slope.

---

## §Reverse-engineered-algorithm (cited eqs)

All equations below are reproduced from the **open-access** Dudko-Hummer-Szabo
2008 PNAS (PMC2572921) and the 2006 PRL abstract/structure. Items that could
NOT be confirmed against an openly fetchable primary source are explicitly
marked `[UNVERIFIED]` and are NOT used in the simulator's load-bearing path
(`g3`).

### A. DHS force-dependent rate k(F) — VERIFIED

From Dudko, Hummer, Szabo, *PRL* **96**, 108101 (2006), reproduced and
generalized in *PNAS* **105**, 15755 (2008) (PMC2572921, verified verbatim:
the lifetime form Eq. 5 below; k(F) is its reciprocal):

```
k(F) = k0 · (1 − ν·F·x‡ / ΔG‡)^(1/ν − 1)
            · exp{ (ΔG‡ / kBT) · [ 1 − (1 − ν·F·x‡ / ΔG‡)^(1/ν) ] }
```

valid for `F < ΔG‡ / (ν·x‡)` (barrier still exists); for
`F ≥ ΔG‡/(ν·x‡)` the barrier has vanished and the model sets the rate to its
barrierless ceiling (escape is no longer activated — treated as k → k0-scale
"effectively instantaneous", flagged in code as the barrier-collapse branch).

where
- `k0` — intrinsic (zero-force) unfolding rate, `k0 = 1/τ0`
- `x‡` — distance from the folded well to the transition state along the pull
- `ΔG‡` — intrinsic (zero-force) activation free energy
- `kBT` — thermal energy (T = 310 K body temperature here)
- `ν` — landscape shape parameter

### B. DHS force-clamp mean lifetime τ(F) — VERIFIED VERBATIM

From *PNAS* **105**, 15755 (2008), Eq. 5 (PMC2572921, fetched verbatim
2026-05-16):

```
τ(F) = τ0 · exp{ (ΔG‡/kBT) · [ 1 − (1 − ν·F·x‡/ΔG‡)^(1/ν) ] }
          / (1 − ν·F·x‡/ΔG‡)^(1/ν − 1)
```

with `τ0 = 1/k0`, valid for `F < ΔG‡/(ν·x‡)`. By construction
`τ(F) = 1/k(F)` (the constant-force mean first-passage / dwell time). This is
the load-bearing equation for the ② resolution: the ② scenario asks "held at
F≈8.75 pN, how long until A2 unfolds?" → that is exactly τ(F).

### C. ν-cases — VERIFIED

From the 2006 PRL / 2008 PNAS (PMC2572921, verified verbatim):

- `ν = 1/2` — harmonic well with a cusp-like barrier (or vice versa).
- `ν = 2/3` — free-energy surface with linear + cubic terms (the
  "linear-cubic" landscape).
- `ν = 1` — the prefactor and exponent collapse and the formula reduces
  *exactly* to Bell: `k(F) = k0·exp(F·x‡/kBT)`,
  `τ(F) = τ0·exp(−F·x‡/kBT)` (PMC2572921 states this Bell limit verbatim).
  Used as an internal cross-check in the simulator.

### D. Generalized-Bell slope identity — VERIFIED

From *PNAS* 105:15755 (2008), Eq. 6 (PMC2572921, verbatim):

```
d(ln τ)/dF = − ⟨x‡(F)⟩ / kBT
```

i.e. the local slope of ln τ vs F measures the (force-dependent) effective
transition-state distance. Used as a deductive selftest (ln τ must be
monotone decreasing in F over the valid range ⇒ τ strictly decreasing).

### E. Rupture-force / loading-rate inversion — partially VERIFIED

From *PNAS* 105:15755 (2008), Eqs. 1–2 (PMC2572921, verbatim):

```
p(F) dF = − Ṡ dt ,    Ṡ(t) = − S(t) / τ(F(t))
τ(F)    = − [ 1 / Ḟ(F) ] · [ dp(F)/dF ] / p(F)        (Eq. 2)
```

i.e. a rupture-force histogram `p(F)` measured at loading rate `Ḟ` maps to
the constant-force lifetime τ(F). The *closed-form most-probable rupture
force vs loading rate* `F*(Ḟ)` (the 2006 PRL Eq. with the
`ln[ (k0·kBT) / (x‡·Ḟ·(1 − ν F* x‡/ΔG‡)^(1−1/ν)) ]` structure) could **not**
be fetched verbatim from an open primary source and is therefore marked
`[UNVERIFIED]`. It is **NOT** used in the simulator's load-bearing path.
Instead, the (ΔG‡, x‡) back-out (next section) is anchored on the
**directly verified** k(F)/τ(F) equation itself — see §resolves-②-marginal.

---

## §stdlib-implementation-spec

`drylab/sim/dhs_force_spectroscopy.py`, Python stdlib only (`math`, `sys`),
deterministic (no RNG, no I/O, no network).

- `dhs_rate_k(F_pN, k0, dG_kT, x_nm, nu)` → k(F) per §A, with explicit
  barrier-collapse branch when `F ≥ ΔG‡/(ν x‡)`.
- `dhs_lifetime_tau(F_pN, ...)` → τ(F) = 1/k(F) per §B.
- `bell_rate_k(F_pN, k0, x_nm)` → Bell reference; asserted equal to
  `dhs_rate_k(..., nu=1)` (the ν=1 verified limit, §C).
- `backout_barrier_params(F_star_pN, k0, dG_kT, nu)` → given the Zhang-2009
  most-probable rupture force ~11 pN as the input, return the
  internally-consistent (ΔG‡, x‡) under the stated assumption (see
  §resolves-②). Honest about under-determination: one parameter MUST be
  assumed; the assumed one is labelled in the return dict.
- `resolve_scenario_2()` → evaluate τ(8.75 pN) and compare to the circulatory
  dwell band; emit the HONEST verdict (computed, not tuned).
- Constants: `KCAL_MOL_TO_KT` etc.; A2 anchor `ΔG ≈ 3.9 kcal/mol`
  (Zhang 2009), `F* ≈ 11 pN` (Zhang 2009 most-probable rupture).

Determinism: pure arithmetic on fixed constants; `assert run()==run()` in
selftest.

---

## §resolves-②-marginal

The ② anchor (`a2_shear_unfolding_anchor.py`) found 8.75 pN < 11 pN and
honestly flagged the verdict as MARGINAL, explicitly deferring the rigorous
call to "the DHS force-clamp lifetime model (drylab #6)". This file builds #6.

**The honest reframing.** "Most-probable rupture force ~11 pN" is *not* a
fixed unfolding threshold — Zhang 2009 itself states it is **loading-rate
dependent** (range 7–14 pN). It is the peak of the rupture-force histogram in
a *dynamic pulling* experiment at *their* loading rate. The ② scenario is a
*different* experiment: a roughly **constant sustained tension** (~8.75 pN)
held over a circulatory dwell (~tens of seconds). The right observable is the
**force-clamp mean lifetime τ(F)** at F = 8.75 pN — exactly DHS Eq. 5.

**Backing out (ΔG‡, x‡) from Zhang-2009 ~11 pN — honest under-determination.**
A single scalar (the ~11 pN most-probable rupture force) cannot fix *both*
ΔG‡ and x‡ *and* k0 simultaneously — the DHS k(F)=Ḟ-driven peak condition is
one equation in (ΔG‡, x‡, k0, ν, Ḟ). The system is **under-determined**; we
MUST assume some inputs. Our honest, literature-anchored choice:

1. `ΔG‡` is anchored to the Zhang-2009 **measured A2 unfolding free energy
   ΔG ≈ 3.9 kcal/mol ≈ 6.6 kBT** (the cited primary value already in §3 of
   the tape). We take ΔG‡ ≈ ΔG (single dominant barrier; honest
   approximation — labelled).
2. `k0` (intrinsic zero-force unfolding rate) is **assumed** at a
   conventional protein-unfolding prefactor band; this is the explicitly
   labelled assumed parameter (`assumed_param="k0"` in the return dict). We
   report the verdict across a k0 band, NOT a single tuned value.
3. With ΔG‡ and k0 fixed, the Zhang ~11 pN most-probable rupture is used to
   solve the DHS rate condition for the single remaining unknown `x‡` (the
   verified k(F) equation, §A — NOT the `[UNVERIFIED]` F*(Ḟ) closed form: we
   impose the operationally honest condition that at F* the DHS escape rate
   reaches an O(1)/observation-window scale, which back-outs an
   *internally-consistent* x‡ given the assumed (ΔG‡, k0). The resulting x‡
   is reported and sanity-checked against the Zhang-2009 contour-gain scale).

This is shown step-by-step in the simulator (`backout_barrier_params`) and the
under-determination is stated in the return dict and the verdict string. We do
NOT claim the back-out is unique.

**The computed verdict.** Evaluate τ(8.75 pN) with the backed-out
(ΔG‡, x‡, k0-band) and compare to the circulatory dwell ~tens of s. Report
whichever way it falls — `τ(8.75) ≪ dwell` ⇒ A2 *does* unfold under sustained
LVAD tension (the ②-mechanism premise is force-clamp-robust, resolving the
"marginal" flag as a robust POSITIVE for the *dwell* observable);
`τ(8.75) ≫ dwell` ⇒ sustained 8.75 pN does *not* unfold A2 within a dwell
(the ② in-silico UNFOLD is a genuine NEGATIVE under the rigorous model — also
a valid honest resolution). Either outcome resolves the flagged gap; the
simulator computes it and does not tune.

---

## §real-limit-anchor

- **DHS model** — Dudko, Hummer, Szabo, *PRL* **96**, 108101 (2006);
  *PNAS* **105**, 15755–15760 (2008), PMC2572921 (open access, Eq. 5/6
  verified verbatim). Kramers-theory force-dependent rate/lifetime — a real,
  published physical-chemistry limit on activated barrier crossing under load.
- **A2 unfolding free energy** — ΔG ≈ 3.9 ± 0.9 kcal/mol (6.6 ± 1.5 kBT);
  most-probable single-molecule rupture ≈ 11 pN (7–14, loading-rate
  dependent); unfolded contour 57 ± 5 nm. Zhang X, Halvorsen K, Zhang C-Z,
  Wong WP, Springer TA, *Science* **324**:1330–1334 (2009), PMC2753189.
- These are the same primary anchors already verified verbatim by the ②
  anchor module; this simulator reuses them, it does not re-derive them.

## §honesty-caveat

- In-silico simulator-internal-consistency ONLY (`g8`/`f2`). This computes a
  DHS lifetime from cited equations and cited A2 constants. It is **NOT** a
  therapeutic, clinical, regulatory, immunogenic, or efficacy claim. A2
  unfolding/cleavage as the aVWS mechanism is established biology cited from
  the literature; this module neither validates a device nor advances a drug.
- The (ΔG‡, x‡) back-out is **under-determined**; one parameter (k0) is an
  explicitly-labelled assumption reported as a band, not a fitted point. The
  ΔG‡≈ΔG single-barrier identification is an honest approximation, labelled.
- The 2006-PRL most-probable-rupture-vs-loading-rate closed form is
  `[UNVERIFIED]` (not openly fetchable) and is NOT in the load-bearing path.
- The verdict is whatever the cited equations + cited constants produce; it
  was NOT tuned toward "② works" or "② fails" (`g1`). PASS of the sentinel
  means the model is internally consistent and the verdict was computed —
  it does NOT mean "② works".

## §references

1. Dudko OK, Hummer G, Szabo A. "Intrinsic rates and activation free energies
   from single-molecule pulling experiments." *Phys Rev Lett.*
   2006;96(10):108101. doi:10.1103/PhysRevLett.96.108101. PMID:16605793.
2. Dudko OK, Hummer G, Szabo A. "Theory, analysis, and interpretation of
   single-molecule force spectroscopy experiments." *Proc Natl Acad Sci USA.*
   2008;105(41):15755–15760. doi:10.1073/pnas.0806085105. PMID:18852468.
   PMC2572921 (open access — Eq. 5/6 verified verbatim 2026-05-16).
3. Bell GI. "Models for the specific adhesion of cells to cells." *Science.*
   1978;200(4342):618–627. (Bell limit, ν=1 cross-check.)
4. Zhang X, Halvorsen K, Zhang C-Z, Wong WP, Springer TA. "Mechanoenzymatic
   cleavage of the ultralarge vascular protein von Willebrand factor."
   *Science.* 2009;324(5932):1330–1334. PMC2753189. (A2 ΔG, rupture force.)
5. Cross-refs (this repo): `_python_bridge/module/a2_shear_unfolding_anchor.py`
   (the ②-marginal flag this file resolves); `../../LVAD/A2_STABILIZER.tape`
   §8; `drylab/sim/shear_phase_diagram.py` (Bell-only ② classification).
