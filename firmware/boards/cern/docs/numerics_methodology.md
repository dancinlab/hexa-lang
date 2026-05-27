# numerics methodology — hexa-cern v1.1.0-pre

> How the `verify/numerics_*.hexa` surface is structured, what each tier
> means, and what the closure pct in `verify/falsifier_check.hexa`
> actually claims.

This document captures the convention behind the 16-script `verify/`
runnable surface as it stood after 13 build iterations on 2026-05-07.
It is **descriptive**, not prescriptive — the canonical invariants live
in the scripts themselves.

---

## § Why a methodology doc

The runnable surface grew organically across 13 iterations from 6 to 16
scripts. Each new script was bounded (one chunk per iteration, one PR)
but the **pattern** that emerged across them is non-trivial:

- `verify/calc_*.hexa`     — algebraic n=6 closure, integer arithmetic
- `verify/numerics_*.hexa` — numerical solvers via `self/runtime/math_pure`
- `verify/lint_*.hexa`     — meta-checks on the methodology itself
- `verify/cross_doc_audit.hexa` + `verify/falsifier_check.hexa` — the
  cross-cutters

A reader landing on the repo for the first time should be able to
understand "why are there 16 verify scripts and what do they
collectively claim?" without reading 16 file headers. This doc is that
reader's map.

---

## § The 3-tier evidence ladder

Every preregistered falsifier (F-PCERN-1/2/3, declared in
`.roadmap.hexa_cern §A.4`) closes over three tiers of evidence:

| tier | name        | representative scripts                          | what it shows |
|:-----|:------------|:------------------------------------------------|:--------------|
| T1   | algebraic   | `calc_*.hexa`                                   | n=6 closed-form derivation holds (integer arithmetic, no floats) |
| T2   | numerical   | `numerics_*.hexa`                               | floating-point solver via `math_pure` agrees with closed-form within tolerance |
| T3   | empirical   | (TBD — Stage-1+ benchtop / live data feed)      | real bench / collider data within order of magnitude of prediction |

**Closure %** in `verify/falsifier_check.hexa` is `tiers_complete / 3`,
rounded up:

| tiers complete | closure pct | label                            |
|:---------------|:-----------:|:---------------------------------|
| 0              | 0%          | UNVERIFIED                       |
| 1              | 33%         | EARLY (algebra only)             |
| 2              | 67%         | PARTIAL (algebra + numerics)     |
| 3              | 100%        | EMPIRICAL (full closure)         |

At v1.1.0-pre **all three falsifiers stand at 67% PARTIAL**. T3 closure
requires hardware that isn't built yet.

---

## § Per-falsifier T2 stacks (as of iter 13)

Each falsifier has been backed by **multiple** T2 scripts where physics
admits independent re-derivation. F-PCERN-3 has the deepest stack:

### F-PCERN-1 — σ-cascade 6-order LHC parity claim

| script                              | T1/T2 | what it adds |
|:------------------------------------|:-----:|:-------------|
| `calc_sigma_cascade.hexa`           | T1    | E_0..E_6 chain monotone, σ³=1728 envelope |
| `numerics_sigma_cascade.hexa`       | T2    | relativistic γ = 1 + E/m_e c², γ_6/γ_2 ≈ 10⁵ ultrarel |
| `numerics_lhc_parity.hexa`          | T2    | LEP/Tevatron/LHC/FCC published values vs E_k buckets |

### F-PCERN-2 — classical Hamiltonian τ=4 phase mode

| script                              | T1/T2 | what it adds |
|:------------------------------------|:-----:|:-------------|
| `calc_classical.hexa`               | T1    | DOF=n=6, dim(q,p)=σ=12, conserved=sopfr+φ=7 |
| `numerics_classical.hexa`           | T2    | symplectic leapfrog, energy drift ≈ 9·10⁻⁶ over τ=4 |
| `numerics_liouville.hexa`           | T2    | Jacobian det(J) = 1 across τ=4 (volume preservation) |

### F-PCERN-3 — 1 GeV/m laser-plasma wakefield

| script                              | T1/T2 | what it adds |
|:------------------------------------|:-----:|:-------------|
| `calc_wakefield.hexa`               | T1    | E_peak = σ·(σ-φ) = 120 GV/m, R = σ-φ = 10 cm |
| `numerics_wakefield.hexa`           | T2    | n_e = 1.56·10¹⁸ cm⁻³, L_d ≈ 1.5 cm closed-form |
| `numerics_lwfa_parity.hexa`         | T2    | BELLA/FACET/ATHENA/FLASHFwd published vs hexa design |
| `numerics_lwfa_solver.hexa`         | T2    | Verlet ODE solver: electron in sinusoidal wakefield |

The redundancy is **deliberate** — each T2 script gives a fresh angle
on the same closed-form. λ_p drops out three times (numerics_wakefield,
numerics_lwfa_parity, numerics_lwfa_solver) and lands on the same
26.76 µm value each time. That cross-check is exactly the kind of
silent regression a single T2 wouldn't catch.

---

## § Cross-cutting + meta scripts

| script                              | role |
|:------------------------------------|:-----|
| `lattice_check.hexa`                | n=6 closure (σ·φ = n·τ = J₂ = 24) across roadmap + 3 pillars |
| `numerics_lattice_arithmetic.hexa`  | float/int parity check on the n=6 anchors via math_pure |
| `cross_doc_audit.hexa`              | LHC/DESY/OEIS/BT cross-pillar consistency |
| `numerics_cross_pillar.hexa`        | numerical anchors agree across mini ↔ parent ↔ classical |
| `falsifier_check.hexa`              | per-falsifier closure pct + T1/T2 script presence audit |
| `lint_numerics.hexa`                | every `numerics_*.hexa` follows 5 regression-discipline invariants |

---

## § The math_pure dependency

Every `numerics_*.hexa` imports the same stdlib:

```hexa
use "self/runtime/math_pure"
```

Routines in use: `sqrt_pure`, `pow_pure`, `log10_pure`, `log_pure`,
`exp_pure`, `sin_pure`, `cos_pure`, `pi_pure`. No raw floating-point
math primitives. No `exec()` shelling out for math.

The `lint_numerics.hexa` meta-check enforces this — if a future
`numerics_foo.hexa` lands without the import, lint fails.

`numerics_lattice_arithmetic.hexa` provides the **stability floor** —
it checks math_pure agrees with the integer-arithmetic anchors to
1e-9 relative error on every routine the rest of the surface uses.
If math_pure ever regresses, this script catches it before downstream
numerics inherit the bug silently.

---

## § Aggregate state at v1.1.0-pre

```
hexa-cern verify all
  → 16/16 PASS  (algebraic 4 + numerical 9 + meta 3)
hexa run tests/test_all.hexa
  → 4/4 PASS  (selftest + lattice + calculators + cli_verify)
make -C build all
  → 3 PDFs built clean (mini 145K + parent 94K + classical 143K)
```

Every script writes a unique sentinel `__HEXA_CERN_<NAME>__ PASS`
that the tests parse. CI parsing is grep-line; no JSON dependency.

---

## § What's intentionally NOT here yet

Per `.roadmap.hexa_cern §A.2` the v1.1.0 / v1.2.0 targets are:

| target          | when     | what |
|:----------------|:---------|:-----|
| v1.1.0          | 2026-08  | full mini wiring (relativistic LWFA solver beyond v1.1.0-pre's non-rel stub) |
| v1.2.0          | 2026-10  | parent σ-cascade integrator + classical full SE(3) 6-DOF symplectic |
| v2.0.0          | 2027-Q1  | Stage-1+ benchtop empirical T3 closure (1 GeV/m DESY collab) |

What's missing in v1.1.0-pre but *implicit* in the closure pct:

- **T3 (empirical) is 0/3** — no live LHC feed, no LWFA bench feed,
  no symplectic-integrator-on-real-accelerator demo. Falsifiers
  cannot resolve to FAIL until T3 instruments exist.
- **numerics_lwfa_solver is non-relativistic** — at γ → 200 (the
  100 MeV design target) relativistic effects dominate. The stub
  is honest about its bounds; a full integrator is v1.2.0+.
- **classical numerics use 1-DOF** — full SE(3) 6-DOF symplectic
  is v1.2.0+.

These three gaps are explicit in each script's `// Note:` block;
they are not bugs but scope.

---

## § How to add a new numerics script (recipe)

1. Create `verify/numerics_<topic>.hexa` with:
   - `#!hexa strict` shebang
   - `use "self/runtime/math_pure"`
   - `let mut RUN = 0` and `let mut FAIL = 0` accounting
   - A `_check(ok, label, detail)` helper
   - A `FALSIFIERS` list (named retract conditions)
   - `__HEXA_CERN_<TOPIC>__ PASS` sentinel + `exit(0)` on success
2. Add the script name to `verify/lint_numerics.hexa` `NUMERICS_SCRIPTS`.
3. Add the case to `cli/hexa-cern.hexa` `VERIFY_SUBS` + `_verify_script`.
4. Add the `(filename, sentinel)` row to `tests/test_calculators.hexa`.
5. Bump `tests/test_cli_verify.hexa`'s `PASS:  N/N` expectation.
6. If the script closes a falsifier tier, append it to the relevant
   `F<n>_T2_SCRIPTS` (or `T1`) array in `verify/falsifier_check.hexa`.
7. Add a `### Added` line to `CHANGELOG.md`.
8. Run `hexa-cern verify all` and `hexa run tests/test_all.hexa`.
   Both should be green before commit.

`lint_numerics.hexa` will surface step 2 if you forget it.

---

— see `CHANGELOG.md` for the per-iteration log of how each script landed.
