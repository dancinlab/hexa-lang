# ssh-topology-winding-integer-sign-w-minus-v

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the Su–Schrieffer–Heeger chain (Su, Schrieffer, Heeger,
*Phys. Rev. Lett.* **42**, 1698 (1979); Asbóth-Oroszlány-Pályi,
*Springer LNP* **919** (2016), Ch.1 §1.3), the off-diagonal Bloch
vector

    d(k) = (v + w cos k,  w sin k)

traces a circle of radius `w` centred at `(v, 0)` as `k` sweeps the
Brillouin zone. The **topological winding number** of `d(k)` about
the origin is the chiral-symmetry-protected invariant, and it takes
the **closed-form integer value**

    W = 1   if w > v   (origin enclosed)  →  TOPOLOGICAL
    W = 0   if w < v   (origin outside)   →  TRIVIAL
      = (1 + sign(w − v)) / 2     (closed form, integer-valued)

equivalently `W = 1` iff `w > v`, `0` iff `w < v`. The Zak phase is
`γ_Zak = π W ∈ {0, π} (mod 2π)`. This is a **quantized integer**
fixed purely by the sign of `w − v` — an exact ℤ identity, with no
transcendental evaluation: the discretized King-Smith–Vanderbilt
Berry/Zak loop (unwrapped winding of `arg h(k)` around the BZ)
returns the *same* integer as the closed form `sign(w−v)`.

## Hexa-native verification

The sim-universe `ssh-topology/module/ssh_topo.hexa` selftest emits
the invariant directly (`v=0.4`, `w=1.0` topological;
`v=1.0`, `w=0.4` trivial):

    (c) winding : topo W_cf=1.0 W_disc=1.0 |
                  trivial W_cf=0.0 W_disc=0.0 (OK)

with sentinel:

    __SIM_UNIVERSE_SSHTOPO__ PASS N=48 v=0.4 w=1.0 mode=selftest
        nzero=2 winding=1.0

Build + run command:

    bash state/ubu-build.sh \
        ssh-topology/module/ssh_topo.hexa ssh_bin --winding

The atlas-side verifier closes this as the **closed-form integer
identity**: for a sweep of integer `(v, w)` pairs it asserts
`W_cf = (1 + sign(w−v))/2 ∈ {0, 1}`, that `W_cf = 1 ⟺ w > v`, and
the **bulk-boundary correspondence count** `n_zero = 2·W` (the
topological phase has exactly 2 protected zero-energy edge modes,
the trivial phase 0) — a pure ℤ check, no floating point.

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (Stage 1 — `W = (1+sign(w−v))/2`
  is an exact integer-valued closed form; the quantization to
  `{0,1}` and the `n_zero = 2W` bulk-boundary count are ℤ-exact, no
  tolerance).
- **Axis:** §3 PHYS (band-structure topology) · cross-link §8 TOP
  (winding number / Zak phase, a homotopy invariant) · §2 MATH
  (integer-valued step function `sign`).
- **Real-limit anchor (`g3`):**
  - **Su, Schrieffer, Heeger**, *Phys. Rev. Lett.* **42**, 1698
    (1979), DOI `10.1103/PhysRevLett.42.1698` — the topological
    soliton / domain-wall midgap state of the dimerized chain.
  - **Asbóth-Oroszlány-Pályi**, *Springer LNP* **919** (2016),
    Ch.1 §1.3–1.5 — winding number, Zak phase `γ = πW`, and the
    bulk-boundary correspondence (`W` protected zero-energy edge
    modes per end).
  - **Zak 1989**, *Phys. Rev. Lett.* **62**, 2747 — the Berry/Zak
    phase of Bloch bands quantized by symmetry.
  - [compiler invariant — `sign(w−v) ∈ {−1,0,+1}` and
    `(1+sign)/2 ∈ {0,1}` are exact integer quantities; the
    invariant is closed in ℤ, no floating-point tolerance].
- **Provenance:** sim-universe `ssh-topology/` (Tier-A2) ·
  `ssh-topology/module/ssh_topo.hexa` (`_winding_closed`,
  `_zak_winding`, `_count_zero_modes`) · AGENTS.tape `@D g17` ·
  `@X x_ssh_1979` / `@X x_asboth_tinotes`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_not_quantized`** — `W` must be **exactly** an integer in
   `{0, 1}`, never a fractional value. If the verifier reports
   `W = 0.5` or any non-integer (a sign that the chiral symmetry
   is broken / the loop is mis-discretized), FIRES. Verifier
   asserts `W ∈ {0, 1}` exactly for every `(v, w)`.
2. **`F2_wrong_phase_assignment`** — topological is `w > v`
   (`W = 1`), trivial is `w < v` (`W = 0`). If the verifier
   swaps the assignment (claims `v > w` is topological), the
   bulk-boundary correspondence fails — FIRES. Verifier asserts
   `W = 1 ⟺ w > v` (bidirectional) and `n_zero(W=1) = 2`,
   `n_zero(W=0) = 0`.
3. **`F3_disc_neq_closed`** — the discretized King-Smith–
   Vanderbilt Zak loop `W_disc` must equal the closed-form
   `W_cf = (1+sign(w−v))/2` for every `(v,w)`. If `W_disc ≠ W_cf`
   (the analytic and numerical invariants disagree), the loop is
   wrong — FIRES. Verifier asserts `W_disc == W_cf` (the module's
   own (c) cross-check).
4. **`F4_boundary_v_eq_w`** — at `v = w` the gap closes
   (`Δ = 2|v−w| = 0`, sibling atom) and the winding is **ill-
   defined** (the circle `d(k)` passes through the origin). If
   the verifier reports a definite `W` at `v = w` instead of
   flagging the gap-closing transition, FIRES. Verifier excludes
   `v = w` and asserts the gap-closure coupling to the sibling
   `ssh-topology-bulk-gap` atom.
5. **`F5_count_not_2W`** — the bulk-boundary correspondence is
   `n_zero = 2 · W` (two ends, one protected mode per end in the
   topological phase). If the verifier reports `n_zero = 1` or
   `n_zero = W` (single-end / wrong multiplicity), FIRES.
   Verifier asserts `n_zero = 2·W` exactly.
6. **`F6_not_exact_integer`** — `sign(w−v)` and the derived
   `W = (1+sign)/2` are exact integers for integer/rational
   `(v,w)`; the identity holds with **zero** tolerance. If the
   verifier needs a floating-point epsilon to round `W` to
   `{0,1}` (suggesting it integrates `arg h` numerically and
   accumulates error rather than using the exact `sign`), the
   closed-form claim is undermined — FIRES. Verifier asserts the
   integer equality with zero tolerance.

## Honest C3

This atom is the **closed-form quantized winding integer**
`W = (1+sign(w−v))/2 ∈ {0,1}` of the **idealized** single-particle
SSH model, plus its bulk-boundary correspondence `n_zero = 2W` on a
finite open chain. The winding is ill-defined exactly at `v = w`
(gap closure). The finite-`N` zero-energy edge modes hybridize with
an exponentially small but **nonzero** splitting `∼(v/w)^L`
(`@D g17` honest scope) — the *count* `n_zero` is exact (the modes
are still distinguishable from the bulk), but their energies are
not literally zero at finite `N`; this is stated, not faked. NOT a
claim about interacting / many-body SSH, real polyacetylene, or the
cold-atom / photonic experimental realizations. The atom absorbs
the exact integer topological invariant only.

## Provenance

Submitter: claude-opus-4-7 (sim-universe absorption cycle,
2026-05-16). Origin: sim-universe `ssh-topology/` (Tier-A2).
Papers: Su, Schrieffer, Heeger, *Phys. Rev. Lett.* **42**, 1698
(1979); Asbóth-Oroszlány-Pályi, *Springer LNP* **919** (2016);
Zak, *Phys. Rev. Lett.* **62**, 2747 (1989). AGENTS.tape `@D g17` /
`@X x_ssh_1979` / `@X x_asboth_tinotes`.
