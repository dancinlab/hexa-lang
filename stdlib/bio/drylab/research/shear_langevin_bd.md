# Shear-driven Langevin / Brownian-dynamics stress-test — algorithm research

> **drylab simulator #2** · in-silico software research — **NOT wet-lab, NOT clinical**.
> Goal: a CITED, stdlib-only Brownian-dynamics (overdamped Langevin) spec for a
> tethered particle (and a short bead-spring polymer) under wall shear, used to
> *corroborate or refute* the **analytic Bell-model NEGATIVE** result reached for
> hexa-bio LVAD scenario ① (`LVAD/SHEAR_GATED_NANOBOT.tape`).
>
> Governance: `g1_real_limits_first` (real-limit anchored) · `g3` (external
> entities described by their OWN published invariants, NO lattice-fit, NO
> fabrication) · `g8`/`f2` (in-silico simulator-consistency only — NO
> therapeutic / clinical / regulatory / efficacy claim).

---

## §SOTA-landscape

Open / academic Brownian-dynamics (overdamped Langevin) engines and the
polymer-in-shear theory leaders. Each line = the project's OWN stated capability
(no lattice-fit, `g3`):

- **LAMMPS** (`fix brownian` / `fix brownian/sphere` / `fix brownian/asphere`) —
  open-source MD engine; performs overdamped Brownian time integration where
  inertial forces are neglected vs viscous; integrates
  `dr = γ⁻¹ F dt + √(2 k_B T) γ^(−1/2) dW`. Open / academic.
- **HOOMD-blue** (`md.methods.Brownian`) — open-source GPU MD; integrates the
  overdamped Langevin EOM `dr/dt = (F_C + F_R)/γ`, random force from the
  fluctuation–dissipation theorem; velocities decoupled from positions. Open.
- **OpenMM** (`BrownianIntegrator`) — open-source MD; Brownian EOM where the
  position change is force/(friction·mass) plus an uncorrelated Gaussian random
  force, variance `2 k_B T/(m γ)·dt`. Open.
- **ESPResSo** — open-source soft-matter MD with a Brownian-dynamics integrator
  (Langevin/overdamped). Open. *(BD integrator support confirmed by general
  documentation; specific discretized form not fetched — treated as
  capability-level only.)*
- Proprietary engines (e.g. Schrödinger Desmond, BIOVIA) also offer
  Langevin/BD thermostats — **[UNVERIFIED]** for the *overdamped/positional*
  variant specifically; omitted from equation provenance.

**Polymer-in-shear theory leaders** (vWF / collapsed-globule unfolding):
Alexander-Katz, Schneider & Netz, *PRL* **97**, 138101 (2006) — shear-flow-induced
unfolding of polymeric globules (threshold shear rate, hydrodynamic vs
free-draining scaling). Schneider, Nuschele, Wixforth, Gorzelanny,
Alexander-Katz, Netz & Schneider, *PNAS* **104**(19), 7899–7903 (2007) —
microfluidic confirmation of a reversible globule–stretch transition at
γ̇_crit. Alexander-Katz & Netz, *Macromolecules* **41**, 3363–3374 (2008) —
dynamics & instabilities of collapsed polymers in shear (Brownian
hydrodynamics, Rotne–Prager). Radtke, Lippok, Rädler & Netz, *EPJ E* **39**, 32
(2016) — tension distribution along a collapsed polymer in shear and its
connection to **enzymatic (force-dependent) cleavage of vWF**. Springer,
*Blood* **124**(9), 1412–1425 (2014) — biophysical review of vWF flow response
(citation verified; full text paywalled, used only as a review pointer).

---

## §Reverse-engineered-algorithm (cited equations)

### A. Ermak–McCammon Brownian-dynamics propagator

Ermak, D.L. & McCammon, J.A., "Brownian dynamics with hydrodynamic
interactions," *J. Chem. Phys.* **69**(4), 1352–1360 (1978),
doi:10.1063/1.436761. In the **free-draining / no-hydrodynamic-interaction
limit** (the regime we adopt — see honesty caveat), the propagator for the
displacement of particle *i* over a fixed timestep Δt reduces to:

```
r_i(t+Δt) = r_i(t) + (D_i / k_B T) · F_i(t) · Δt + R_i
```

where `D_i` is the bare Stokes–Einstein diffusion coefficient of particle *i*,
`F_i(t)` is the total systematic (potential + tether) force on *i*, and `R_i`
is a Gaussian random displacement with zero mean and covariance

```
⟨R_i⟩ = 0 ,  ⟨R_i ⊗ R_i⟩ = 2 D_i Δt · 𝟙
```

This is exactly the Euler–Maruyama discretization (below) with the
**Einstein/fluctuation–dissipation relation** `D = k_B T / γ` enforced, so the
sampled equilibrium is the correct Boltzmann distribution.

### B. Euler–Maruyama integration of the overdamped Langevin SDE

Higham, D.J., "An algorithmic introduction to numerical simulation of
stochastic differential equations," *SIAM Review* **43**(3), 525–546 (2001),
doi:10.1137/S0036144500378302. The overdamped Langevin SDE (inertia dropped:
valid when `m/γ ≪ Δt`) for a single coordinate *x* is

```
γ dx = F(x) dt + √(2 γ k_B T) dW
```

with `dW` a Wiener increment. Its Euler–Maruyama update with fixed step Δt is

```
x(t+Δt) = x(t) + (F(x,t) / γ) · Δt + √(2 D Δt) · ξ ,   D = k_B T / γ
```

`ξ ~ N(0,1)` i.i.d. per step per coordinate. This is the discrete form used
verbatim by LAMMPS `fix brownian` (`r(t+dt)=r(t)+γ⁻¹F dt+√(2k_BT)γ^(−1/2)ξ`,
displacement variance `= 2 D Δt`) and matches the Ermak–McCammon free-draining
limit in §A.

### C. Tethered bead in simple (linear) wall shear flow

Background flow is the **simple shear field** `v(r) = (γ̇·y, 0, 0)` (x =
flow, y = gradient/wall-normal). The advected bead feels Stokes drag relative to
the local fluid velocity. With Stokes' law `F_drag = 6πηa·(v_fluid − v_bead)`
(Stokes 1851; standard text result), the BD update with shear advection becomes,
per coordinate:

```
x(t+Δt) = x(t) + γ̇·y(t)·Δt + (F_x/γ)·Δt + √(2DΔt)·ξ_x
y(t+Δt) = y(t)            + (F_y/γ)·Δt + √(2DΔt)·ξ_y
```

where `γ = 6πηa` (Stokes friction, sphere radius `a`, viscosity `η`) and
`F` = tether (harmonic) + excluded-volume forces. The tether restrains the
bead near an anchor at the wall; the shear term `γ̇·y·Δt` is the deterministic
advective drift that loads the tether.

### D. Polymer (short bead-spring) tension scaling under shear

For a polymer the relevant load is the **internal tensile force**, peaked near
the chain midpoint/protrusions. Radtke, Lippok, Rädler & Netz, *EPJ E* **39**,
32 (2016) (Brownian hydrodynamic simulations) establish that the tension
distribution along a collapsed polymer in shear is inhomogeneous, develops a
double-peak above a threshold shear rate, and the **maximal tensile force**
scales with shear rate, globule size and cohesive strength. Schneider et al.,
*PNAS* **104**, 7899 (2007) report the threshold scaling

```
γ̇_crit ≈ ΔU² L^(1/3) a^(−10/3) / (η k_B T)
```

(ΔU = monomer cohesion in k_B T, L = polymer length, a = monomer size, η =
viscosity). The simple **drag-tension order-of-magnitude estimate** for an
extended chain of contour length L in shear is the integrated Stokes drag

```
F_tension ~ C · η · γ̇ · L²        (C an O(1) prefactor, model-dependent)
```

— this `η·γ̇·L²` form is the standard scaling; we treat the prefactor `C` as
**fitted/order-of-magnitude, NOT a borrowed exact constant** (no fabricated
prefactor; see honesty caveat). γ̇_crit ≈ 5000 s⁻¹ was the value reported by
Schneider et al. 2007 for vWF; that is a vWF-specific number, not transferable
to a compact synthetic nanobot.

### E. Bell force-dependent opening rate coupled to the BD trajectory

Bell, G.I., "Models for the specific adhesion of cells to cells," *Science*
**200**(4342), 618–627 (1978), doi:10.1126/science.347575. The force-dependent
dissociation / "open" rate is

```
k_off(F) = k_off⁰ · exp( σ·F / (k_B T) )
```

`k_off⁰` = zero-force rate, `σ` = reactive compliance (bond interaction range,
Ångström scale), `F` = instantaneous tensile force, `k_B T` = thermal energy.
(Equational form independently confirmed via Smith, Forsten-Williams &
Lauffenburger usage of the identical Bell expression citing Bell 1978; the Bell
relation is empirical, originally from material-fracture data — Bell 1978
states no first-principles derivation.) Coupling to the BD trajectory is a
**first-passage / Kramers** readout: at each step the instantaneous force `F(t)`
(tether force in §C, or peak internal tension in §D) drives an accumulated
opening hazard

```
P_open(t) = 1 − exp( −∫₀ᵗ k_off(F(t')) dt' )  ≈  1 − exp( −Σ_n k_off(F_n) Δt )
```

The **mean first-passage "open" time** ⟨τ_open⟩ is the trajectory-averaged time
to reach the opening event (Kramers escape under a fluctuating, shear-set
force). This is precisely how Radtke et al. 2016 connect simulated polymer
tension to shear-sensitive enzymatic (ADAMTS13) cleavage of vWF.

---

## §stdlib-implementation-spec

Pure-stdlib (Python `random`, `math`); fixed seed → bitwise determinism.

**State**
- Tethered-bead mode: `(x, y)` position (nm); anchor at `(0,0)` on the wall.
- Polymer mode: list of N bead positions `[(x_i, y_i)]`, harmonic springs
  (FENE-free, linear) between neighbors + soft excluded volume; bead 0 tethered.
- Derived readouts: tether/internal force `F`, accumulated opening hazard `H`.

**Parameters (real-limit anchored, see §real-limit-anchor)**
- `T = 310 K` (body temp, tape §3).
- `η = 1.2e-3 Pa·s` (plasma viscosity, tape §3).
- `a` = bead radius; γ = `6πηa` (Stokes); `D = k_B T / γ` (Einstein).
- `γ̇` swept over **70–150 dyn/cm² → shear rate** via γ̇ = τ/η
  (LVAD impeller, tape §3) and **1–10 dyn/cm²** (venous, tape §3); ratio >10×.
- Bell: `k_off⁰`, `σ` as swept inputs (literature-range, flagged as inputs).
- `Δt` chosen s.t. overdamped validity `m/γ ≪ Δt` AND
  `√(2DΔt) ≪` tether length (CFL-like stability), recorded in the witness row.

**Overdamped Langevin update (explicit, Euler–Maruyama, §C)** — per step,
per bead, fixed-seed `random.Random(seed)`, `ξ = rng.gauss(0,1)`:

```
x ← x + γ̇·y·Δt + (F_x/γ)·Δt + sqrt(2*D*Δt)·ξ_x
y ← y          + (F_y/γ)·Δt + sqrt(2*D*Δt)·ξ_y
```

`F` = Σ harmonic tether + neighbor springs + soft WCA-like excluded volume
(stdlib `math` only). Shear coupling is the single deterministic `γ̇·y·Δt`
drift on the flow (x) coordinate (§C).

**Bell-rate readout (§E)** — each step accumulate
`H += k_off⁰ · exp(σ·F / (k_B T)) · Δt`; the event "open" fires at the first
step where a fixed-seed uniform `u < 1 − exp(−H)` (or, deterministically,
when `H ≥ −ln(0.5)` for the median). Record per-trajectory τ_open; average
over a fixed seed-block for ⟨τ_open⟩(γ̇).

**Determinism**: single seeded RNG, fixed step count, fixed parameter sweep
grid → reproducible witness rows (PASS/SKIP/FAIL of *internal consistency*
only, per `g6`/`g8`).

---

## §corroborate-or-refute-metric

**Chosen metric: mean first-passage "open" time ⟨τ_open⟩ as a function of wall
shear, evaluated at compact-nanobot length scale vs vWF-multimer length scale.**

Procedure:
1. Run the BD sim at the LVAD-impeller shear band (γ̇ from 70–150 dyn/cm²) and
   the venous band (1–10 dyn/cm²), for (i) a **compact bead** (nanobot-scale
   `a`, small drag area) and (ii) a **long bead-spring chain** (vWF-scale
   contour length, large effective drag area `~1e7 nm²` per the §8 analytic
   figure).
2. Compute ⟨τ_open⟩ and the **separation ratio**
   `S = ⟨τ_open⟩_venous / ⟨τ_open⟩_impeller`.
3. **Corroborate** the §8 analytic NEGATIVE iff the compact bead shows
   `S ≈ 1` (no usable gating: opens as readily — or as rarely — at venous as at
   impeller shear, because the Bell exponent `σ·F/k_BT` stays ≪ 1 when drag
   area is small), **while** the long chain shows `S ≫ 1` (sharp gating). That
   is, the *dynamical* model reproduces the Bell-simplification conclusion:
   a compact device cannot achieve spatial shear-gating; only a large
   drag-area (~1e7 nm²) object can.
4. **Refute** iff the compact bead also shows `S ≫ 1` at physically admissible
   `σ`, `k_off⁰` — i.e. thermal-noise-assisted Kramers escape sharpens the
   force response enough that the analytic mean-field Bell estimate was
   pessimistic.

The metric is the **same physical quantity** the §8 analytic argument bounds
(force-gated opening probability), so a dynamical BD trajectory is a direct,
not indirect, cross-check.

---

## §real-limit-anchor

Anchored real limits (`g1` — ≥1 required; all from `SHEAR_GATED_NANOBOT.tape`
§3 and cited physics, NOT the n=6 lattice):

- **LVAD impeller wall shear stress 70–150 dyn/cm²** vs **physiological
  venous/arterial 1–10 dyn/cm²** (>10× separation) — the gating target window.
- **Stokes–Einstein relation** `D = k_B T / (6πηa)` — sets the noise floor;
  the irreducible thermal-fluctuation limit on force discrimination.
- **Bell reactive compliance σ (Å-scale)** — the *physical* floor on how
  sharply an opening rate can depend on force; an Å-scale σ with sub-pN
  forces keeps `σF/k_BT ≪ 1` for compact objects (the crux of the §8 negative).
- **Plasma viscosity η ≈ 1.2 mPa·s, T = 310 K** (tape §3) — fixes γ and D.
- **vWF threshold γ̇_crit ≈ 5000 s⁻¹** (Schneider et al. *PNAS* 2007) — a real,
  cited, length-scale-specific unfolding threshold (used as the large-drag-area
  reference point, NOT transferred to the nanobot).

Honest approximation label: **free-draining (no hydrodynamic interactions),
point-/bead-spring, simple-shear, Euler–Maruyama O(Δt^½ strong) — a
deliberately conservative lower-bound model.**

---

## §honesty-caveat

- `g8`/`f2`: This is **in-silico simulator-consistency research only**. A
  PASS/SKIP/FAIL here verifies the BD simulator's internal numerical
  self-consistency — **NEVER** a therapeutic, clinical, regulatory,
  immunogenic, device-readiness, or efficacy claim. The LVAD shear-gated
  nanobot remains scientifically UNPROVEN at the wet-lab boundary
  (`CLOSURE_RESIDUAL_BACKLOG.md §0`).
- **Free-draining approximation is conservative.** The vWF literature
  (Alexander-Katz 2006; Radtke 2016) shows hydrodynamic interactions (HI,
  Rotne–Prager) *increase* the threshold scaling sensitivity. Omitting HI is an
  honest, stated simplification that biases toward the §8 negative (harder to
  gate), so corroboration of the negative is robust to it; a *refutation* would
  need to survive adding HI and is therefore the weaker claim from this model.
- **Bare Stokes drag underestimates tethered-bead force.** Independent work
  (arXiv:1508.02563, *tethered cells beyond Stokes' drag*) reports the bare
  Stokes estimate underestimates the bond force by ~32–46% near walls. The sim
  must report this as a known systematic bias on `F`, biasing toward the
  negative (real force is larger than modeled).
- **Tension prefactor `C` in `F ~ C·η·γ̇·L²` is order-of-magnitude / fitted,
  NOT a borrowed exact constant.** The exact prefactor in Radtke 2016 / Springer
  2014 was not extractable from open text (paywalled); fabricating it would
  violate `g3`. The corroborate/refute logic uses the *scaling* and the
  *separation ratio S*, which are prefactor-robust.
- **Honest expectation (cited basis):** the literature predicts the BD result
  will **CORROBORATE the §8 Bell negative for a compact nanobot**. Reason: the
  cited scaling `γ̇_crit ∝ a^(−10/3)` (Schneider *PNAS* 2007) and the
  `F ~ η·γ̇·L²` drag-tension form both make the force-gating effect collapse for
  small drag area / short contour length — the same mechanism the analytic Bell
  argument used to require ~1e7 nm². A short, compact object simply cannot
  develop a tensile force large enough to make `σF/k_BT` ≳ 1 in the LVAD shear
  band, so Kramers/Bell opening stays shear-insensitive. A *refutation* is the
  low-probability outcome and, per the HI caveat above, would be the weaker
  claim. (This is a research expectation about a simulator, not a clinical or
  efficacy prediction — `g8`/`f2`.)

---

## §references

All verified by WebSearch/WebFetch during this research; unverifiable items
DROPPED or labelled `[UNVERIFIED]` (`g3`, no fabrication).

1. **Ermak, D.L. & McCammon, J.A.** "Brownian dynamics with hydrodynamic
   interactions." *J. Chem. Phys.* **69**(4), 1352–1360 (1978).
   doi:10.1063/1.436761. — *propagator §A.* Verified (publisher + multiple
   citation indices).
2. **Higham, D.J.** "An algorithmic introduction to numerical simulation of
   stochastic differential equations." *SIAM Review* **43**(3), 525–546 (2001).
   doi:10.1137/S0036144500378302. — *Euler–Maruyama §B.* Verified (SIAM,
   open full text).
3. **Bell, G.I.** "Models for the specific adhesion of cells to cells."
   *Science* **200**(4342), 618–627 (1978). doi:10.1126/science.347575. —
   *force-dependent opening rate §E.* Verified (Science + PubMed PMID 347575).
4. **Alexander-Katz, A., Schneider, M.F., Schneider, S.W., Wixforth, A. &
   Netz, R.R.** "Shear-Flow-Induced Unfolding of Polymeric Globules."
   *Phys. Rev. Lett.* **97**, 138101 (2006).
   doi:10.1103/PhysRevLett.97.138101. — *polymer-in-shear theory §D.*
   Verified (APS; abstract text paywalled — used at scaling/abstract level).
5. **Schneider, S.W., Nuschele, S., Wixforth, A., Gorzelanny, C.,
   Alexander-Katz, A., Netz, R.R. & Schneider, M.F.** "Shear-induced unfolding
   triggers adhesion of von Willebrand factor fibers." *PNAS* **104**(19),
   7899–7903 (2007). doi:10.1073/pnas.0608422104. PMID 17470810. —
   *γ̇_crit ≈ 5000 s⁻¹, threshold scaling §D.* Verified (PNAS + PMC1876544
   full text fetched).
6. **Alexander-Katz, A. & Netz, R.R.** "Dynamics and Instabilities of
   Collapsed Polymers in Shear Flow." *Macromolecules* **41**, 3363–3374
   (2008). doi:10.1021/ma702331d. — *Brownian hydrodynamics / Rotne–Prager
   context §D.* Verified (ACS + Netz group page).
7. **Radtke, M., Lippok, S., Rädler, J.O. & Netz, R.R.** "Internal tension in
   a collapsed polymer under shear flow and the connection to enzymatic
   cleavage of von Willebrand factor." *Eur. Phys. J. E* **39**, 32 (2016).
   doi:10.1140/epje/i2016-16032-7. PMID 26993993. — *tension↔Bell-cleavage
   coupling §D/§E.* Verified (EPJ E + PubMed; full text paywalled — used at
   abstract level).
8. **Springer, T.A.** "von Willebrand factor, Jedi knight of the bloodstream."
   *Blood* **124**(9), 1412–1425 (2014). doi:10.1182/blood-2014-05-378638.
   PMID 24928861. — *vWF flow-response review pointer.* Verified (Blood +
   PubMed; full text paywalled — review pointer only, no equation taken).
9. **LAMMPS** `fix brownian` documentation, docs.lammps.org/fix_brownian.html
   — *discretized BD update §B (engine cross-check).* Verified (fetched).
10. **HOOMD-blue** `md.methods.Brownian`, hoomd-blue.readthedocs.io —
    *overdamped Langevin EOM (engine cross-check).* Verified (search).
11. **OpenMM** `BrownianIntegrator`, docs.openmm.org —
    *Brownian EOM, Gaussian-noise variance (engine cross-check).* Verified
    (search).
12. **(tethered-bead drag bias)** "Tethered cells in fluid flows — beyond the
    Stokes' drag force approach," arXiv:1508.02563 (PMID 26331992). — *~32–46%
    Stokes-drag underestimate honesty caveat.* Verified (arXiv + PubMed).

*Dropped/avoided as unverifiable:* exact tension prefactor `C` (paywalled,
NOT fabricated); proprietary-engine overdamped-BD specifics (`[UNVERIFIED]`,
excluded from equation provenance); ESPResSo discretized form (capability-level
only).
