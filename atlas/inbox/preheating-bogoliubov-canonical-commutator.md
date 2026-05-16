# preheating-bogoliubov-canonical-commutator

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the Gondret et al. 2025 cold-atom analog of cosmological
preheating (arXiv:2506.22024 / Phys. Rev. Lett. **135**, 240603
(2025)), the time-dependent Bogoliubov-de-Gennes (BdG) mode
equation for the canonical-transformation coefficients
`(u_k(t), v_k(t))`

    du_k/dt = −i ω_k(t) u_k − i g_k(t) v_k*
    dv_k/dt = +i ω_k(t) v_k + i g_k(t) u_k*

(with `ω_k(t) = ω_{k,0}(1 + ε cos Ω t)`, `g_k(t) = (ε/2) ω_{k,0}
cos Ω t`, all real-valued) — written in the SSOT module's
canonical-commutator-preserving **real 4-vector** form
(`preheating-analog/module/preheating.hexa::_bdg_rhs`, sign
derivation verbatim in that file's comment block):

    dur/dt =  ω·ui + g·vi
    dui/dt = −ω·ur − g·vr
    dvr/dt = −ω·vi − g·ui
    dvi/dt =  ω·vr + g·ur

**preserves the canonical-commutator (Wronskian) invariant
exactly**:

    W(t) := |u_k(t)|² − |v_k(t)|² = 1   for all t.

This is the bosonic-Bogoliubov canonical commutator
`[â_+(t), â_+†(t)] = 1` re-expressed for the transformation
`â_+(t) = u_k â_+(0) + v_k* â_-†(0)`. It is a **conserved quantity
of the linear ODE**, provable by differentiating the real form:

    dW/dt = 2(ur·dur/dt + ui·dui/dt) − 2(vr·dvr/dt + vi·dvi/dt)
          = 2[ur(ωui+gvi) + ui(−ωur−gvr)]
            − 2[vr(−ωvi−gui) + vi(ωvr+gur)]
          = 2g(ur·vi − ui·vr) + 2g(vr·ui − vi·ur)
          = 0.

(The `ω`-terms cancel pairwise by inspection; the two `g`-coupling
terms are `+2g(ur·vi − ui·vr)` and `−2g(ur·vi − ui·vr)`, summing to
zero — full expansion verbatim in the module comment block.) Hence
`d/dt(|u_k|² − |v_k|²) = 0` **identically** — the Wronskian is a
first integral of the Heisenberg flow, the linear-Bogoliubov
analog of Liouville/symplectic-area conservation. Vacuum-seeded
initial condition `u_k(0)=1, v_k(0)=0` ⇒ `W ≡ 1`.

## Hexa-native verification

The sim-universe `preheating-analog/module/preheating.hexa`
(compiled native to `state/preheating_bin`) selftest emits the
invariant directly:

    canonical commutator : |u|²−|v|² drift = 0.000000 (OK, both resonant & off-resonant)

with sentinel:

    __SIM_UNIVERSE_PREHEATING__ PASS mode=selftest nk=0.391 r=...
        EN=... norm_drift=0.000000

Build + run command (ubu build, mirrors `fvd`/`stark`/`qdarwin`):

    bash state/ubu-build.sh \
        preheating-analog/module/preheating.hexa \
        preheating_bin --selftest

over `T = 12/ω_⊥` (~3000 RK4 steps), drift = `0.000000` to 6
decimals on BOTH the resonant (`ω_{k,0}=1.0`) and off-resonant
(`ω_{k,0}=0.5`) modes.

The atlas-side verifier closes this **two ways**: (a) the
**symbolic Wronskian-conservation identity** — evaluate
`dW/dt = 2(ur·u̇r+ui·u̇i) − 2(vr·v̇r+vi·v̇i)` from the SSOT module
RHS sign convention at a sample state and confirm it is `0` to
machine precision (the algebraic cancellation above,
libm-arithmetic); and (b) a **tiny embedded 4-component RK4
integration** of the BdG ODE (400 steps, `dt = 0.005`) and a check
that `|W − 1| < 1e-6` — the module's own `_commutator_drift`
acceptance band (RK4 conserves the quadratic first integral to
`O(dt⁵)`; the conservation survives the discrete flow, not just the
continuous identity).

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (Stage 2 — the Wronskian
  conservation is an exact first integral of a linear ODE; the
  hexa-native verifier confirms both the algebraic
  `dW/dt = 0` identity at a sample point (`< 1e-12`) AND the
  RK4-discrete-flow drift `< 1e-6` (module acceptance band) over
  400 sample steps, libm-precision).
- **Axis:** §3 PHYS (Bogoliubov / parametric-resonance pair
  production) · cross-link §2 MATH (Wronskian / first integral of a
  linear ODE) · §6 COSMO (cosmological-preheating analog).
- **Real-limit anchor (`g3`):**
  - **Gondret et al.**, *Observation of entanglement in a cold atom
    analog of cosmological preheating*, **Phys. Rev. Lett. 135,
    240603 (2025)** / arXiv:2506.22024, two-mode-squeezing model
    eq:tmsth + the time-dependent BdG derivation
    (Martin:2021znx, busch.2014.quantum, robertson.2017.controlling).
  - **Bogoliubov 1947 / canonical commutator [â,â†]=1** — the
    bosonic-Bogoliubov transformation must preserve
    `[â,â†]=|u|²−|v|²=1` (symplectic / Wronskian invariant); this is
    the unitarity of the squeezing transformation.
  - [compiler invariant — RK4 conserves a quadratic first integral
    of a linear ODE to `O(dt⁵)` local truncation; drift `→ 0` as a
    deterministic numerical fact, not a fitted constant].
- **Provenance:** sim-universe commit (preheating-analog landing) ·
  `preheating-analog/module/preheating.hexa::_bdg_rhs` · AGENTS.tape
  `@D g14` preheating-analog-honest-scope · `@X x_gondret_preheating`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_wrong_sign_in_rhs`** — the conservation requires the
   SPECIFIC SSOT real sign structure `dvr/dt = −ωvi − gui`,
   `dvi/dt = +ωvr + gur` (the dual / annihilation-operator side).
   If the `v`-equation sign is flipped to the naive
   `dvr/dt = +ωvi + gui` form (which conserves `|u|²+|v|²`, NOT
   `|u|²−|v|²`), the `g`-coupling terms in `dW/dt` no longer
   cancel — `dW/dt ≠ 0` and the drift FIRES. Verifier evaluates
   `dW/dt` algebraically at a non-trivial sample
   `(u,v)=(0.8+0.3i, 0.2−0.1i)` and asserts `|dW/dt| < 1e-12`.
2. **`F2_omega_term_not_cancelling`** — the `ω`-contributions
   vanish from `dW/dt` only because `ur(ωui) + ui(−ωur) = 0` and
   the matching `v`-pair cancels too. If `ω_k(t)` were given an
   imaginary part (erroneous damping), the `ω`-pairs no longer
   cancel and `W` would drift. Verifier asserts `ω_k(t)` real for
   the paper drive `ω_{k,0}(1+ε cos Ωt)`; complex `ω` FIRES.
3. **`F3_rk4_blowup`** — if the RK4 step `dt` is too large
   (`dt ≳ 1/Ω`), the discrete flow no longer conserves `W` to the
   `1e-6` module band (numerical instability). Verifier uses the
   module default `dt = 0.005/ω_⊥` (~100 steps/drive cycle) and
   asserts `|W − 1| < 1e-6` over the 400 sample steps; a coarse
   `dt` that breaks conservation FIRES.
4. **`F4_seed_not_vacuum`** — vacuum seed `u(0)=1, v(0)=0` ⇒
   `W(0)=1`. If the verifier mis-seeds `u(0)=0, v(0)=1`,
   `W(0) = 0 − 1 = −1` (still conserved, but the wrong constant —
   not the canonical `+1`). Verifier asserts `W(0)=+1` for the
   vacuum seed; `W(0) ≠ +1` FIRES.
5. **`F5_norm_confusion`** — `W = |u|² − |v|²` is the canonical
   commutator, NOT the L2 norm `|u|² + |v|²` (which is NOT
   conserved — it grows as pairs are produced, `n_k = |v|²`
   increases). If the verifier checks `|u|²+|v|² = 1`, it would
   FALSELY fail on a resonant mode (where `|v|² > 0`). Verifier
   uses the `−` sign; using `+` FIRES (the resonant mode has
   `|u|²+|v|² = 1+2|v|² > 1`).
6. **`F6_off_resonant_not_conserved`** — the conservation is
   `ω_{k,0}`-independent (it is a structural property of the linear
   BdG flow). If the verifier finds `W` conserved for the resonant
   mode but drifting for the off-resonant mode (or vice-versa), the
   conservation is being accidentally satisfied by a mode-specific
   coincidence, not the structural identity — FIRES. Selftest
   confirms drift `= 0` on BOTH `ω_{k,0}=1.0` (resonant) and
   `ω_{k,0}=0.5` (off-resonant).

## Honest C3

This atom is **specifically** the *linear-Bogoliubov canonical
commutator conservation* `|u_k|²−|v_k|²=1`. It is exact ONLY within
the linear-BdG (Gaussian / quadratic-Hamiltonian) regime. The
paper's **late-time nonlinear regime** (Fig. 3, hold time
`t > 3 ms` — condensate depletion, mode-mode coupling, decoherence)
is OUTSIDE this linear theory by construction; the atom does NOT
claim conservation there, and the module explicitly does not
reproduce that regime (per `@D g14` honest scope; `@F f1`
cosmological framing is *analog* — no space-expansion). The atom
absorbs the conserved Wronskian of the linear ODE only, not the
full nonlinear BEC physics.

## Provenance

Submitter: claude-opus-4-7 (sim-universe absorption cycle,
2026-05-16). Origin: sim-universe `preheating-analog/` (Tier-A2).
Paper: Gondret et al., Phys. Rev. Lett. 135, 240603 (2025) /
arXiv:2506.22024. AGENTS.tape `@D g14` / `@X x_gondret_preheating`.
