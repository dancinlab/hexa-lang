# ssh-topology-bulk-gap-2-abs-v-minus-w

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the Su–Schrieffer–Heeger (SSH) dimerized 1D tight-binding chain
(Su, Schrieffer, Heeger, *Phys. Rev. Lett.* **42**, 1698 (1979);
pedagogical anchor Asbóth-Oroszlány-Pályi, *Springer LNP* **919**
(2016), Ch.1), the bulk Bloch Hamiltonian is

    H(k) = [ 0       h(k) ] ,   h(k) = v + w e^{−ik}
           [ h*(k)   0    ]
    E(k)  = ± |h(k)| = ± √( v² + w² + 2 v w cos k )

The **direct band gap** is the minimum of `2|E(k)|` over the
Brillouin zone, attained at `k = π` (`cos k = −1`):

    Δ = 2 · min_k |E(k)| = 2 |E(π)| = 2 √(v² + w² − 2vw)
      = 2 √((v − w)²) = **2 |v − w|**     (closed form)

The gap **closes exactly at `v = w`** — the topological phase
transition point. This is an exact algebraic identity at integer /
rational `v, w`: `√((v−w)²) = |v−w|` requires no transcendental
evaluation, so `Δ = 2|v−w|` is closed in ℚ.

## Hexa-native verification

The sim-universe `ssh-topology/module/ssh_topo.hexa` selftest emits
the invariant directly (`L = 24` cells, `N = 48` sites, `v=0.4`,
`w=1.0`):

    (a) bulk gap   : Δ_cf=1.200000  |2|E(π)|−Δ|=0.000000 (OK)

with sentinel:

    __SIM_UNIVERSE_SSHTOPO__ PASS N=48 v=0.4 w=1.0 mode=selftest
        nzero=2 winding=1.0

Build + run command:

    bash state/ubu-build.sh \
        ssh-topology/module/ssh_topo.hexa ssh_bin --selftest

The atlas-side verifier closes this as the **closed-form rational
identity**: over a sweep of integer `(v, w)` pairs it asserts
`(2·min_k|E(k)|)² == (2|v−w|)²` (both sides integer — `min |E|` is at
`k=π` so `|E(π)|² = (v−w)²` exactly), and that the value is exactly
`0` iff `v == w` (gap closure at the phase transition).

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (Stage 1 — `√((v−w)²) = |v−w|`
  is an exact ℤ/ℚ identity at the band-edge momentum `k=π`; no
  transcendental needed, no floating-point tolerance).
- **Axis:** §3 PHYS (band-structure topology / tight-binding) ·
  cross-link §8 TOP (the gap protects the Zak/winding invariant) ·
  §2 MATH (`√(x²)=|x|` algebraic identity).
- **Real-limit anchor (`g3`):**
  - **Su, Schrieffer, Heeger**, *Phys. Rev. Lett.* **42**, 1698
    (1979), DOI `10.1103/PhysRevLett.42.1698` — the original
    dimerized-chain bulk band `E(k) = ±|v + w e^{−ik}|`.
  - **Asbóth-Oroszlány-Pályi**, *Springer LNP* **919** (2016),
    Ch.1 Eq. 1.16 — modern statement of the bulk band and the
    `Δ = 2|v−w|` gap closing at `v = w`.
  - [compiler invariant — `|v−w|` is an exact ℤ/ℚ quantity for
    integer/rational hops; the identity is closed in ℚ via
    `(v−w)² ≥ 0`, no floating-point tolerance].
- **Provenance:** sim-universe `ssh-topology/` (Tier-A2) ·
  `ssh-topology/module/ssh_topo.hexa` (`_bulk_gap`, `_bulk_E`) ·
  AGENTS.tape `@D g17` · `@X x_ssh_1979` / `@X x_asboth_tinotes`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_not_at_k_pi`** — the gap minimum is at `k = π`
   (`cos k = −1`). If the verifier evaluates `|E|` at `k = 0`
   (`cos k = +1`, giving the band *maximum* `v+w`, NOT the gap)
   and still claims `2|v−w|`, the band-edge momentum is wrong —
   FIRES. Verifier asserts `min_k |E(k)|² = (v−w)²` is attained
   at `cos k = −1`, and that `cos k = +1` gives `(v+w)²` instead.
2. **`F2_sign_dropped`** — `Δ = 2|v−w|`, NOT `2(v−w)`. For
   `v > w` the unsigned `2(v−w) > 0` coincidentally matches, but
   for `v < w` the bare `2(v−w) < 0` is unphysical (a gap is
   non-negative). If the verifier omits the absolute value and
   reports a negative gap for `v < w`, FIRES. Verifier sweeps
   both `v < w` and `v > w` and asserts `Δ ≥ 0` with
   `Δ² = 4(v−w)²` in every case.
3. **`F3_no_gap_closure`** — the gap must vanish **exactly** at
   `v = w` (the topological phase transition). If the verifier
   reports `Δ > 0` at `v = w` (e.g. a spurious additive constant),
   the phase-transition point is wrong — FIRES. Verifier asserts
   `Δ = 0 ⟺ v = w` (bidirectional).
4. **`F4_wrong_prefactor`** — the gap is `2|v−w|`, not `|v−w|`
   (the factor 2 is `E_+ − E_- = 2|E|`). If the verifier drops
   the factor 2 and reports `|v−w|`, FIRES. Verifier asserts the
   full conduction-to-valence splitting `E_+(π) − E_-(π) = 2|E(π)|
   = 2|v−w|`.
5. **`F5_periodic_vs_open_confusion`** — `Δ = 2|v−w|` is the
   **bulk** (periodic-chain) gap. The finite open chain in the
   topological phase has in-gap edge modes near `E ≈ 0` — that is
   a *different* spectrum and does NOT contradict the bulk gap. If
   the verifier conflates the open-chain edge-mode splitting with
   the bulk gap, FIRES. Verifier closes the periodic-chain bulk
   identity ONLY and states the open-chain edge modes are the
   separate `ssh-topology` invariant.
6. **`F6_not_exact_rational`** — for integer `(v, w)`, `(v−w)²`
   and `4(v−w)²` are exact integers; `Δ² = 4(v−w)²` holds with
   **zero** tolerance. If the verifier needs a floating-point
   epsilon to pass (suggesting it is computing `√` then squaring,
   accumulating error rather than using the exact rational
   identity), the closed-form claim is undermined — FIRES.
   Verifier asserts the integer equality `Δ² == 4(v−w)²` exactly.

## Honest C3

This atom is the **bulk** (periodic-chain) closed-form gap
`Δ = 2|v−w|` of the **idealized** single-particle SSH model ONLY.
It is NOT a claim about the finite open chain (whose topological
edge modes hybridize with an exponentially small but nonzero
splitting `∼(v/w)^L` — the separate `ssh-topology` invariant), NOT
about interacting / many-body SSH, NOT about real polyacetylene or
the cold-atom / photonic experimental realizations (no disorder,
phonons, e-e interaction, temperature — `@D g17` honest scope). The
atom absorbs the exact algebraic band-gap identity only.

## Provenance

Submitter: claude-opus-4-7 (sim-universe absorption cycle,
2026-05-16). Origin: sim-universe `ssh-topology/` (Tier-A2).
Papers: Su, Schrieffer, Heeger, *Phys. Rev. Lett.* **42**, 1698
(1979); Asbóth-Oroszlány-Pályi, *Springer LNP* **919** (2016).
AGENTS.tape `@D g17` / `@X x_ssh_1979` / `@X x_asboth_tinotes`.
