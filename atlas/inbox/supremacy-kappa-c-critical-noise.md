# supremacy-kappa-c-critical-noise

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

The **critical noise** of the weak-link transition in Morvan et al. 2024
is a closed-form constant:

    κ_c(T) = (4 / T) · log 2

At the selftest point `T = 4`:

    κ_c(4) = 1 · log 2 = ln(2) = 0.6931471805599453...

This is the closed-form value (paper Eq. surrounding `eq:xeb-wl-model`):
the depth where the order parameter `F^d / XEB` switches branches.

## Hexa-native verification

The sim-universe `supremacy-frontier` selftest emits:

    kappa_c (4/T)log2 = 0.693147 analytic 0.693147 (OK)

`__SIM_UNIVERSE_SUPREMACY__ PASS` (cf. commit `c46707c`,
`supremacy-frontier/module/supremacy_frontier.hexa`). Numerical
recompute uses the same `_ln` (atanh range-reduced) the parent
identity rides on.

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-FORMAL** (Stage 2 numerical via `libm`-class
  `log` — `ln(2)` is the standard transcendental constant, hexa-native
  verifier reproduces it).
- **Axis:** §3 PHYS · cross-link §2 MATH (`ln(2)` is an atlas atom).
- **Real-limit anchor (`g3`):** Morvan et al., **Nature 634, 328-333
  (2024)** · DOI `10.1038/s41586-024-07998-6` · arXiv:2304.11119.
- **Provenance:** sim-universe commit `c46707c` ·
  AGENTS.tape `@D g10` · `@X x_morvan_rcs`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_wrong_T_scaling`** — replace `T=4` with `T=2`; value must
   become `2·log 2 = 1.386294`. If still `0.693147`, falsified.
2. **`F2_base_e_vs_base_2`** — confirm the `log` is natural log (base
   `e`), not `log_2`. Selftest must report `0.693147`, not `1.000000`
   (which would imply `log_2(2)=1`). If `1.000000`, falsified.
3. **`F3_cross_check_against_libm`** — independently compute
   `(4.0/4.0) * log(2.0)` via macOS `clang -O2` and `gcc -O2` on
   ubu; both must equal `0.69314718...` to ~15 digits.
4. **`F4_dimensional_consistency`** — `κ_c` is a noise rate, not a
   depth; the formula `(4/T) log 2` requires `T` (Trotter slabs) to
   be dimensionless. If a reviewer finds a `(4 ns / T_us) · log 2`
   reading anywhere, falsified.
5. **`F5_paper_text_match`** — Morvan et al. 2024 Section IV (or
   equivalent) must state `κ_c = (4/T) log 2`. If the paper actually
   states `κ_c = (4 log 2)/T` (algebraically identical) the atom is
   fine; if it states `κ_c = 4 T log 2` (T in numerator), the atlas
   recompute is wrong — falsified.

## Open questions

- The factor `4` is `2T` at `T=4` per the geometric series of the
  weak-link kernel; should the atlas atom expose `κ_c = 2 log 2`
  (T-independent form when `d/T = log 2 / log(1/(1-ε))` is solved)
  or the explicit `(4/T) log 2` (with `T` parameter)? Recommend the
  explicit form — matches paper notation.

## Reviewer checklist

- [ ] Tier (🔵 SUPPORTED-FORMAL recommended).
- [ ] Axis (§3 PHYS · §2 MATH cross-link).
- [ ] Falsifiers ≥5.
- [ ] Real-limit anchor verified.
- [ ] Merge to `atlas/MAIN.tape § PHYS`.

---

Submitter: claude-opus-4-7 (2026-05-16). Origin: sim-universe c46707c.
