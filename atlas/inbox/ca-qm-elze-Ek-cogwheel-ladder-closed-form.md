# ca-qm-elze-Ek-cogwheel-ladder-closed-form

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For Elze's classical Ising-permutation **ontological** cellular automaton
(arXiv:2401.08253), viewed in the *quantum-formalism* mode, the induced
Hamiltonian `Ĥ` has the closed-form **cogwheel ladder** spectrum
(paper Eq. `HamiltonianFin`):

    E_k = 2π · k / (2S · T)         k = 0, 1, ..., 2S − 1

where `T` is the unit time step of one CA application of `Û`. This is
't Hooft's "cogwheel" idea (Nucl. Phys. B 342, 471, 1990): a finite-
period classical orbit `Û` of length `P` produces a quantum spectrum
of evenly-spaced rungs `E_k = 2πk / (P·T)`. For the Elze chain at
`2S` spins, `P = 2S` (one full revolution = one orbit length).

## Hexa-native verification

`ca-qm/module/ca_qm.hexa` implements `_induced_h_ladder(S, T)` which
returns the closed-form list `[2πk/(2S·T) for k in 0..2S-1]` — the
diagonalising basis is unused (no `2^{2S}×2^{2S}` matrix built), per
the design recommendation "prefer the closed form, fall back to the
matrix only if the diagonalizing basis is wanted" (`MODULE/ca-qm.md §D9`).

Mode `--spectrum` (clamped to `2S ≤ 16` so the cheap output isn't a
matrix-path artifact). At `2S=16, T=1`:

    E_0 = 0,    E_1 = π/8,    E_2 = π/4,  ..., E_15 = 15π/8

Hexa-native recompute matches the closed form to floating-point
precision (Stage 2 numerical via builtin `π`).

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-FORMAL** — closed-form spectrum (Stage 1
  symbolic for the `2πk/(2S·T)` structure; Stage 2 numerical for the
  evaluation). Distinct from the integer-equality invariant
  `revival-period == perm-order` (separate atom): this atom is the
  **continuous-spectrum analytic statement** of the cogwheel ladder.
- **Axis:** §3 PHYS · cross-link §1 N6-FOUNDATION (the cogwheel idea
  is a fundamental lattice-as-tool primitive).
- **Real-limit anchor (`g3`):**
  - Elze, **IJQI 22, 2450013 (2024)** · DOI
    `10.1142/S0219749924500138` · arXiv:2401.08253 · Eq. `HamiltonianFin`.
  - 't Hooft, *Quantization of point particles in (2+1)-dimensional
    gravity and the cogwheel idea*, **Nucl. Phys. B 342, 471 (1990)**
    (the cogwheel origin).
- **Provenance:** sim-universe c46707c · `ca-qm/module/ca_qm.hexa`
  `_induced_h_ladder` · AGENTS.tape `@D g9` · `@X x_elze_caqm`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_wrong_period_factor`** — replace `(2S · T)` with `(S · T)`
   in the formula; spectrum spacing doubles, `E_1 = π/(S·T) = π/8`
   becomes `2π/8 = π/4`. Selftest must change. The `2S` factor (full
   chain length = orbit period) is essential.
2. **`F2_k_range_off_by_one`** — replace `k = 0..2S-1` with
   `k = 1..2S`; the lowest energy `E_0=0` drops out, the spectrum
   shifts up. Atom must reject this.
3. **`F3_period_not_2S`** — if the underlying permutation has a
   shorter orbit (e.g., for an even-only sub-lattice the orbit
   length is `S` not `2S`), the cogwheel formula should use that
   actual orbit length. The atom assumes the FULL-chain permutation
   on the open chain, where the orbit length is `2S`. A reviewer
   applying it to a sublattice CA must falsify the atom there.
4. **`F4_continuum_limit_matches_weyl`** — taking `2S → ∞, T → 0`
   with `(2S · T) = L` fixed, the spectrum density `dE/dk = 2π/L`
   reproduces the free-Weyl dispersion `E = p` (with `p = 2πk/L`).
   This is the continuum-limit consistency check (Elze §3.5
   / Eqs. `LWeyl`/`RWeyl`). A formula that does NOT reduce to
   `E = p` in the continuum limit is falsified.
5. **`F5_t_hooft_cogwheel_consistency`** — 't Hooft's original
   cogwheel for a period-`P` orbit gives `E_k = 2πk/(P·T)`. Elze's
   formula is the special case `P = 2S` (open Ising chain). If a
   reviewer asserts the atom for a `P ≠ 2S` system without changing
   the formula, falsified.
6. **`F6_quantum_formalism_only`** — the atom is the spectrum of the
   **induced quantum Hamiltonian** (a derived view), NOT a property
   of the classical CA itself. The classical CA has no
   "Hamiltonian"; it has an orbit. Conflating the two would be a
   category error — and the @D g9 STRICTER caveat exists precisely
   to flag that. Atom is in the quantum-formalism domain only.

## Open questions

- Should the `T` (time step) be normalised to `1` in the atlas atom?
  Recommend `T = 1` as the canonical evaluation (the spectrum scale
  is set by `T`; only `(2S·T)` enters as a dimensional combo).
- The Elze model has an additional **mass term** in the 2025
  companion (Necklace-of-Necklaces, arXiv:2504.06883, *Entropy*
  **27**, 395, 2025) that turns the Weyl continuum into Dirac. The
  mass spectrum atom is separate (`s_phys_caqm_elze_dirac_mass_term`,
  stretch goal #6, UN-implemented).

## Reviewer checklist

- [ ] Tier (🔵 SUPPORTED-FORMAL recommended).
- [ ] Axis (§3 PHYS; §1 N6-FOUNDATION cross-link).
- [ ] Falsifiers ≥5.
- [ ] Real-limit anchor (g3) verified — Elze 2024 + 't Hooft 1990.
- [ ] Merge to `atlas/MAIN.tape § PHYS`.

---

Submitter: claude-opus-4-7 (2026-05-16). Origin: sim-universe c46707c.
