# vWF Multimer-Size Population-Balance under Shear — Reverse-Engineered Kinetics

Reverse-engineering research for `hexa-bio` `drylab/` simulator **#5**.

**Scope (g8 / f2):** This is an *in-silico algorithm specification* for a reduced
multimer-size population-balance simulator. It is software research. It is NOT
wet-lab, NOT clinical, NOT a therapeutic / efficacy / immunogenicity claim. A
reduced population-balance is a *model-dependent* caricature of vWF size
homeostasis; any size distribution it emits is a hypothesis generator that must
be validated against multimer-gel / single-molecule measurement before any
biological conclusion.

**Why this exists.** `LVAD/A2_STABILIZER.tape` §3 limit **#4** —
*"vWF multimer MW range 500 kDa – 20 MDa · HMW = >10 MDa lost first"* — was
treated as a *descriptive constant with no in-substrate consistency relation*.
That is a **false boundary**. Zhang X et al. 2009 (the scenario's OWN cited
primary) explicitly derive a *dynamical* size-regulation relation: tensile
force at the middle of a vWF multimer scales with the **square of multimer
length**, so the **per-multimer A2-unfolding (hence ADAMTS13-cleavage) rate is
size-dependent**, which yields a shear-dependent **steady-state size
distribution** and explains the in-vivo upper size limit. A reduced
population-balance steady-state of that size-dependent scission IS a dynamical
model and *does* anchor #4. This document specifies it; the numbers are the
Zhang-2009-corrected set already used by
`_python_bridge/module/a2_shear_unfolding_anchor.py` (k_cat 0.14 /s,
ΔG 3.9 kcal/mol — NOT the retracted tape values 2.5 /s, 7–10 kcal/mol).

---

## §SOTA-landscape

Each tool/model described by *its own* documented capability — no lattice-fit,
no cross-comparison ranking (g3). One honest line each.

- **Zhang X et al. 2009, *Science* 324:1330 (mechanoenzymatic model).** The
  governing single-molecule + hydrodynamic model: A2 unfolds under tension,
  only unfolded A2 is cleaved by ADAMTS13, tension at the middle of an
  *N*-monomer multimer ∝ *N²*, and this size-dependence reproduces the observed
  ~200-monomer in-vivo upper size limit. [verified verbatim — PMC2753189]
- **Crawley JTB et al. 2011, *Blood* 118:3212 (mechanism review).** The
  multistep exosite mechanism: elevated rheologic shear elongates vWF, uncouples
  the A domains, extracts the Cys1669–Cys1670 vicinal disulfide plug, unravels
  A2, exposing the Tyr1605–Met1606 scissile bond and cryptic exosites; larger
  multimers are more hemostatically active. [verified verbatim — PMID 21715306]
- **Springer TA 2014, *Blood* 124:1412 (biophysics review).** "peak internal
  tension scales with the square of concatemer length"; unfolding of A2 is
  required for ADAMTS13 cleavage; larger multimers experience preferentially
  higher tension; multimers reach 40–200 monomers / 3–15 µm thread length.
  [verified verbatim — PMC4148764]
- **Population-balance / scission modelling (general method, not a single
  fetched primary).** Size-resolved scission of an elongated chain population
  under a size-dependent break rate is a classical population-balance / coagulation–
  fragmentation construction (Smoluchowski-type birth–death on a size index).
  The *method* (birth–death balance on a discretised size axis) is standard; it
  is implemented here in its simplest valid reduction (linear scission only, no
  re-multimerisation) and is **labelled an approximation** — see
  §honesty-caveat. No specific polymer-scission PDE paper is cited verbatim
  because none was fetched in this pass; the construction is presented as a
  generic discretised birth–death balance, not attributed to an unverified
  source (g3).

---

## §Reverse-engineered-kinetics (cited)

All constants below were verified **verbatim** from a fetched primary page in
this research pass. Unverifiable items were dropped (g3, no fabrication).

### A. Size-dependent tension (Zhang 2009 — verbatim)

> "force on a VWF multimer goes up with the square of multimer length and is
> highest at the middle, providing an efficient mechanism for homeostatic
> regulation in vivo of the size distribution of VWF multimers"
> — Zhang X et al. 2009, *Science* 324:1330 (PMC2753189)

> "force at the middle of the multimer is proportional to N²" (N = number of
> monomers); "The tensile force is estimated … to reach 10 pN on the middle of
> a VWF 200-mer at the maximal shear stress of 100 dyn/cm²." — *ibid.*

This is the **dynamical anchor**: the mid-multimer tension is

```
F_mid(N, τ)  =  C_T · τ · L(N)²        with  L(N) = ℓ_mono · N
```

— the same `F_mid ∝ C_T·τ·L²` stress form already used in
`_python_bridge/module/a2_shear_unfolding_anchor.py` (Alexander-Katz 2006
*PRL* 97:138101 scaling form), here written as a function of monomer count *N*
via a per-monomer contour length `ℓ_mono`. Zhang's own quantified point
(`F_mid ≈ 10 pN` at `N = 200`, `τ = 100 dyn/cm²`) is used to **fix the lumped
prefactor `C_T·ℓ_mono²` by a single literature calibration point** (a cited
anchor, NOT a fit to a desired output distribution — see §honesty-caveat / g1).

### B. A2 mechano-unfolding kinetics (Zhang 2009 — verbatim)

| Quantity | Verbatim value | Source |
|---|---|---|
| Unfolding rate, zero force `k_u0` | "0.0007 s⁻¹ (confidence band 0.0002 – 0.003 s⁻¹)" | Zhang 2009, PMC2753189 |
| Force scale `f_β` (`k_u = k_u0·exp(f/f_β)`) | "1.1 ± 0.2 pN" | *ibid.* |
| Most-probable unfolding force | "about 11 pN" at loading rate 25 pN/s | *ibid.* |
| A2 unfolding ΔG | "6.6 ± 1.5 k_BT (3.9 ± 0.9 kcal/mol)" | *ibid.* |
| Unfolded-state lifetime, zero force | "1.9 s in absence of force" | *ibid.* |
| Unfolded contour length | "57 nm ± 5 nm" | *ibid.* |
| Persistence length | "1.1 nm ± 0.4 nm" | *ibid.* |
| A2 domain size | "predicted 177-residue A2 domain" | *ibid.* |

The Bell-type force-accelerated unfolding rate `k_u(F) = k_u0·exp(F/f_β)` is
quoted **verbatim** from Zhang 2009 and is the per-multimer scission-rate
kernel (the unfolded A2 is then cleaved; see C).

### C. ADAMTS13 cleavage of unfolded A2 (Zhang 2009 — verbatim)

> single-molecule "k_cat" = "0.14 s⁻¹"; "K_M" = "0.16 μM" ("lower than previous
> estimates of 1.7 and 1.6 μM … A2 unfolded by force is the physiologic
> substrate"). — Zhang X et al. 2009, *Science* 324:1330 (PMC2753189)

Mechanism (Crawley 2011, verbatim): "elevated shear forces on VWF cause
uncoupling of the A domains, extraction of the Cys1669-Cys1670 vicinal
disulphide plug, and unraveling of the A2 domain", exposing the scissile bond
and exosites. Cleavage requires the *unfolded* state; with the unfolded
lifetime (1.9 s) and `k_cat` (0.14 s⁻¹ ⇒ `1/k_cat ≈ 7.1 s`), the **enzymatic
step is rate-limiting** (cleavage-limited regime). The per-multimer scission
rate is therefore governed by how often / how long A2 is force-unfolded, i.e.
by `k_u(F_mid(N,τ))`, gated by the slower ADAMTS13 turnover.

### D. Multimer molecular-weight axis (#4 range — verified)

Mature vWF subunit ≈ 220–250 kDa; smallest plasma form is the dimer
(≈ 500 kDa); largest multimers exceed 20,000 kDa (≈ 20 MDa)
([PMC3969155](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3969155/),
verified). This anchors `A2_STABILIZER.tape` §3 #4's stated "500 kDa – 20 MDa"
range: MW ≈ (subunit mass) · (monomer count *N*), so the size axis used by the
simulator is *N* (monomer count) and MW is a derived report.

### Dropped / not cited verbatim

- A closed-form polymer-scission PDE / coagulation–fragmentation primary (not
  fetched this pass) — the population balance is presented as a generic
  discretised birth–death construction, not attributed to an unverified source.
- Any clinical aVWS prevalence / device-shear statistic — out of scope (g8/f2)
  and not needed for the simulator-consistency claim.

---

## §stdlib-implementation-spec

Pure-stdlib (Python `math` only — deterministic, no PRNG needed: the
steady-state balance is solved analytically per size bin).

**Size axis.** Discrete monomer count `N ∈ {1 … N_MAX}` (default
`N_MAX = 250`, straddling Zhang's ~200-mer upper limit). MW(N) = subunit_kDa · N
(report-only).

**Tension kernel.**
`F_mid(N, τ) = K_TENSION · τ · N²`, where the lumped prefactor `K_TENSION`
(= `C_T·ℓ_mono²` in the F_mid∝C_T·τ·L² form) is fixed by Zhang's single cited
calibration point `F_mid(200, 100 dyn/cm²) = 10 pN` ⇒
`K_TENSION = 10 / (100 · 200²)` pN per (dyn/cm²·monomer²). Documented as a
literature-anchored constant, NOT a free fit parameter (g1).

**Scission rate (Zhang Bell kernel + cleavage gate).**
```
k_u(N, τ)        = k_u0 · exp( F_mid(N, τ) / f_β )          # Zhang 2009
p_unfolded(N, τ) = k_u / (k_u + k_refold)                   # 2-state occupancy
k_scission(N, τ) = min(k_u, k_cat) · p_unfolded(N, τ)       # cleavage-limited
```
`k_refold = 1 / 1.9 s` (Zhang unfolded-state lifetime → refold rate, zero-force
upper bound). `min(k_u, k_cat)` enforces the honest cleavage-limited regime
(§C): a multimer cannot be scissioned faster than ADAMTS13 turns over even when
unfolding is fast. Each scission of an `N`-mer is modelled as a single cut at
the (highest-tension) middle → two `N/2`-mers (integer split; odd `N` → ⌊N/2⌋
and ⌈N/2⌉).

**Steady-state population balance.** Birth–death on the size index with a
constant secretion source `S` at the largest size `N_MAX` (ultralarge vWF is
secreted, then trimmed — Crawley 2011), linear scission as the only loss/birth
process, and a slow clearance `k_clear` on all sizes (so total mass is
conserved as a *flux* steady state: source = clearance + … ). The discrete
steady-state equations are solved by a single deterministic top-down sweep
(largest → smallest), because scission only moves mass *downward* in size:
```
for N from N_MAX down to 1:
    inflow[N]   = S·δ(N,N_MAX) + Σ_{M>N} (scission flux from M landing on N)
    n[N]        = inflow[N] / (k_scission(N,τ) + k_clear)      # steady state
    distribute  k_scission(N,τ)·n[N] mass to ⌊N/2⌋, ⌈N/2⌉
```
No iteration / no PRNG ⇒ exactly deterministic; identical inputs ⇒ bitwise
identical distribution.

**Outputs.**
1. Steady-state count distribution `n[N]` and mass distribution `N·n[N]` per
   shear `τ`.
2. Mean / HMW-fraction observables: number-average monomer count `⟨N⟩`,
   mass-average, the literal-#4 **HMW mass fraction** (MW > 10 MDa), and the
   **ultralarge mass fraction** (N > 200, Zhang's cited in-vivo upper limit).
   The ultralarge band is the *discriminating* "HMW lost first" observable:
   the single-midpoint-scission cascade concentrates mass below N≈125 quickly,
   so a fixed >10 MDa (N>40) cutoff is a weak discriminator, whereas the
   N>200 band (the truly ultralarge species the `exp(∝N²)` kernel attacks
   first) collapses sharply with shear. Both are reported; the acceptance
   gate is on the *direction and ordering* (ultralarge lost more than the
   >10 MDa band), not on absolute values.
3. Witness row: τ grid, K_TENSION (with its Zhang calibration point), k_u0,
   f_β, k_cat, k_refold, ⟨N⟩(τ), HMW-fraction(τ), mass-conservation residual.

---

## §anchors-§3#4

`LVAD/A2_STABILIZER.tape` §3 limit **#4** —
*"vWF multimer MW range 500 kDa – 20 MDa · HMW = >10 MDa lost first"* — is
anchored, NOT as a static constant, but as the **steady state of a
size-dependent scission balance**:

| #4 sub-claim | Anchored by |
|---|---|
| MW range 500 kDa – 20 MDa | size axis `N·subunit_kDa`, `N∈{2…~200}`; verified PMC3969155 (dimer ≈ 500 kDa, largest > 20 MDa) |
| HMW = >10 MDa **lost first** | `k_scission(N,τ) ∝ exp(K_TENSION·τ·N²/f_β)` — strongly super-linear in `N`, so the largest multimers are scissioned first; both the literal >10 MDa fraction *and* (far more sharply) the ultralarge N>200 fraction *decrease* monotonically with τ — the ultralarge band collapses ~10²× over 0→70 dyn/cm² |
| (implicit) homeostatic upper size limit | Zhang 2009: the *N²* tension law "successfully predicts the observed upper size limit … ∼200 monomers" — reproduced as the steady-state cutoff |

The simulator therefore converts #4 from "descriptive constant, no
in-substrate relation" into a verifiable dynamical-consistency gate.

---

## §real-limit-anchor

Verification-anchored to **real biophysical limits** (g1), all verbatim from
primary literature — NOT the n=6 lattice:

| Real limit | Value | Primary source |
|---|---|---|
| Mid-multimer tension scaling | ∝ N² ("square of multimer length", highest at middle) | Zhang X 2009 *Science* 324:1330 (PMC2753189) |
| Tension calibration point | ≈ 10 pN at N=200, τ=100 dyn/cm² | *ibid.* |
| A2 unfolding rate, zero force `k_u0` | 0.0007 s⁻¹ (band 0.0002–0.003) | *ibid.* |
| A2 Bell force scale `f_β` | 1.1 ± 0.2 pN | *ibid.* |
| A2 unfolding ΔG | 6.6 ± 1.5 k_BT = **3.9 ± 0.9 kcal/mol** | *ibid.* |
| A2 unfolded-state lifetime (0 force) | 1.9 s | *ibid.* |
| ADAMTS13 single-molecule `k_cat` (unfolded A2) | **0.14 s⁻¹** | *ibid.* |
| ADAMTS13 single-molecule `K_M` | 0.16 µM | *ibid.* |
| Upper multimer size limit in vivo | ≈ 200 monomers | *ibid.* |
| vWF subunit / dimer / max-multimer mass | ≈ 220–250 kDa / ≈ 500 kDa / > 20 MDa | PMC3969155 |
| Scissile bond / unfolding-exposure mechanism | Tyr1605–Met1606; shear → A2 unravel → exosite/scissile exposure | Crawley 2011 *Blood* 118:3212 (PMID 21715306); Springer 2014 *Blood* 124:1412 (PMC4148764) |

**Acceptance gate (6 deductive checks).** D1 Zhang calibration round-trips
(F_mid(200,100)=10 pN); D2 mid-tension ∝ N² (4× for 2× N); D3 monomer-mass
conservation (secreted flux = cleared flux, residual < 1e-9); D4 determinism
(no PRNG, bitwise-identical re-run); D5 number-average `⟨N⟩` decreases
monotonically with shear; D6 the §3#4 aVWS signature — both the literal
>10 MDa and the ultralarge N>200 mass-fractions decrease monotonically, and
the ultralarge band loses a *greater* fraction than the >10 MDa band ("lost
FIRST"). All as emergent consequences of the cited N² kernel with the
prefactor fixed by Zhang's single calibration point (not tuned to produce the
result). Sentinel: `__DRYLAB_VWF_MULTIMER_KINETICS__ PASS/FAIL`.

---

## §honesty-caveat

- **Reduced population-balance — NOT a full polymer-scission PDE.** This is a
  *discretised birth–death balance with single mid-chain scission and no
  re-multimerisation*. It omits: (a) bond-position–resolved scission profiles
  (only the highest-tension midpoint cut is modelled, an idealisation of the
  "force highest at the middle" statement); (b) vWF self-association /
  re-multimerisation and tubular-storage size effects; (c) collagen/platelet
  binding modulation of effective tension; (d) the spatial flow field /
  globule-stretch transition (only the elongated-state `∝τ·N²` scaling is
  used). It is a *hypothesis generator* for the *direction and ordering* of
  size loss, not a quantitative size-distribution predictor.
- **Dyadic-cascade artefact (disclosed).** Because every scission is a single
  midpoint cut, the steady-state distribution is *spiky* (mass piles at
  N ≈ N_MAX, N_MAX/2, N_MAX/4 …), not smooth. A real bond-position-resolved
  model would smear these. Consequence: a fixed MW cutoff (e.g. >10 MDa)
  understates the loss because mass falls *through* the band in big jumps.
  The model's honest, robust signal is therefore the **mean/mass-average
  size collapse** and the **N>200 ultralarge-band depletion** (~10²× over
  0→70 dyn/cm²), reported instead of relying on the literal >10 MDa fraction
  alone. This is disclosed, not hidden.
- **Prefactor is a single cited calibration, not a fit.** `K_TENSION` is fixed
  by ONE Zhang-2009 literature point (10 pN @ N=200, τ=100). The output HMW-vs-
  shear trend is **not** tuned to a desired distribution; it emerges from the
  cited `exp(∝N²)` kernel. No fit-to-convenient-number (g1).
- **Zhang-corrected numbers only.** k_cat = **0.14 s⁻¹**, ΔG =
  **3.9 ± 0.9 kcal/mol** — the retracted tape values (k_cat 2.5 /s,
  ΔG 7–10 kcal/mol) are NOT used (g3).
- **g8 / f2.** A PASS verifies in-silico simulator + metadata internal
  consistency and consistency with the cited real limits ONLY. It is NOT a
  therapeutic, clinical, regulatory, immunogenicity, or efficacy claim. aVWS in
  LVAD patients is established clinical biology cited as the *direction* the
  model must reproduce — the model neither validates a device nor advances the
  A2-stabilizer drug (white-space, 0 approved A2 stabilizers, unchanged).

---

## §references

Every reference was reached via a fetched page in this research pass. Items
that could not be verified verbatim were dropped (g3, no fabrication).

1. **Zhang X, Halvorsen K, Zhang C-Z, Wong WP, Springer TA.** "Mechanoenzymatic
   cleavage of the ultralarge vascular protein von Willebrand factor."
   *Science* **324**, 1330–1334 (2009). PMID 19498171. — *k_cat 0.14 s⁻¹,
   K_M 0.16 µM, ΔG 6.6±1.5 k_BT (3.9±0.9 kcal/mol), unfolding force ≈ 11 pN
   @ 25 pN/s, k_u0 0.0007 s⁻¹, f_β 1.1±0.2 pN, unfolded-state lifetime 1.9 s,
   contour 57±5 nm, persistence 1.1±0.4 nm, 177-residue A2, mid-multimer
   tension ∝ N² highest at middle (10 pN @ 200-mer, 100 dyn/cm²), predicts
   ~200-monomer upper size limit; verified verbatim via fetched PMC2753189.*
2. **Crawley JTB, de Groot R, Xiang Y, Luken BM, Lane DA.** "Unraveling the
   scissile bond: how ADAMTS13 recognizes and cleaves von Willebrand factor."
   *Blood* **118**(12), 3212–3221 (2011). PMID 21715306. — *mechanism: elevated
   shear uncouples A domains, extracts Cys1669–Cys1670 vicinal disulfide plug,
   unravels A2, exposes Tyr1605–Met1606 scissile bond + cryptic exosites;
   multistep exosite-driven binding; larger multimers more hemostatically
   active; verified verbatim via fetched PubMed 21715306.*
3. **Springer TA.** "von Willebrand factor, Jedi knight of the bloodstream."
   *Blood* **124**(9), 1412–1425 (2014). doi:10.1182/blood-2014-05-378638. —
   *"peak internal tension scales with the square of concatemer length";
   unfolding of A2 required for ADAMTS13 cleavage; larger multimers
   preferentially higher tension; 40–200 monomers / 3–15 µm thread; verified
   verbatim via fetched PMC4148764.*
4. **Sadler JE; Bryckaert M et al. (review hub).** "Update on von Willebrand
   factor multimers: focus on high-molecular-weight multimers and their role in
   hemostasis." *Blood Transfus.* (2014); PMC3969155. — *vWF subunit ≈
   220–250 kDa, smallest plasma form dimer ≈ 500 kDa, largest multimers
   > 20,000 kDa (≈ 20 MDa); used to anchor §3 #4 MW range; verified via fetched
   PMC3969155.* (Used for the MW-range anchor only; not a kinetics source.)

Cross-referenced sibling artefact (same Zhang-corrected constant set):
`drylab/research/a2_cg_unfolding.md`;
`_python_bridge/module/a2_shear_unfolding_anchor.py` (F_mid ∝ C_T·τ·L²,
k_cat 0.14 /s, ΔG 3.9 kcal/mol).

Background/cross-check (not primary kinetics): Alexander-Katz et al. 2006
*PRL* 97:138101 (shear-stretch tension scaling form, cited in the sibling
anchor module).
