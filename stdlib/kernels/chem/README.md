# kernels/chem/ — chem domain substrate seed (scaffolding stub)

Substrate landing surface for the demiurge **chem** domain (D81 신규).
Closes the G-report `chem : NOT YET` gap (`demiurge` e451037d,
2026-05-20) by establishing the `stdlib/kernels/chem/` subtree with
one minimal kernel + 1-test scaffold — the universal-recognition
entry point for chemical kinetics.

This is **scaffolding**, NOT a D80 g_hexa_only pilot: no Python
parity oracle, no Cantera reference run, no measured-data
verification. Promotes to stage-2 once a parity reference lands.

| file | role |
|---|---|
| `arrhenius_kernel.hexa` | Arrhenius rate equation `k = A·exp(-Ea/(R·T))` (1889 textbook closed form). 2 pub fns: `r_gas_const()` (CODATA 2018 exact 8.314462618) + `arrhenius_k(a, ea, t)`. Pure, no I/O. |
| `arrhenius_kernel_test.hexa` | 6 closed-form assertions: R constant, room-temp 50 kJ/mol reference, high-T limit `k → A`, zero-Ea collapse, `T ≤ 0` guard returns 0. Run: `hexa run stdlib/kernels/chem/arrhenius_kernel_test.hexa`. |

## Why Arrhenius (and not something fancier)

Every textbook, every reactor model, every catalyst comparison
reduces back to Arrhenius. It is the 1-line equation every
chemist recognizes on sight. Picking it as the seed dodges three
scope traps simultaneously:

- No reaction catalog needed (just abstract `A, Ea, T`)
- No solvent / phase model needed (gas-phase implicit)
- No transition-state theory commitment (modified-Arrhenius and
  Eyring are kept as future kernels — `arrhenius_modified_kernel`,
  `eyring_kernel` — without forcing a choice today)

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. Pure `(A, Ea, T) → k`.
- **①b adapter** — not yet written. Future
  `stdlib/chem/kinetics.hexa` or sibling-repo `~/core/hexa-chem/`
  would carry reaction catalogs, fitted parameter tables, solvent
  models.

## Promotion path

| stage | what's needed | status |
|---|---|---|
| stage-0 scaffolding | dir + 1 kernel + 1 test PASS | DONE |
| stage-2 substrate parity | port a Cantera or RDKit kinetics reference + parity test ≤0.1 % | TODO |
| stage-3 ①b adapter | reaction catalog + fitted constants | TODO |
| D80 g_hexa_only pilot | `absorbed=true` flip at the demiurge record layer | TODO |

## Sibling sub-domains (planned)

Per chem.md §1 the larger chem substrate ultimately lives in a
sibling `~/core/hexa-chem/` repo (D17 precedent — molecular-scale
substrates too large for one stdlib subtree). This `stdlib/kernels/chem/`
subtree is the **shared kernels** layer that bio + matter can also
import once a 2nd consumer appears (D72 promotion rule).
