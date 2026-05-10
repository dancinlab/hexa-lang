# hexa-cern v1.0.0 — initial extraction 💫

**Released:** 2026-05-06
**Provenance:** `dancinlab/canon@c0f1f570` → `dancinlab/hexa-cern@v1.0.0`
**Sister extraction:** `dancinlab/lumiere` (peer)
**License:** MIT
**Verdict:** SPECS_ONLY (3/3 pillar specs imported; .hexa CLI TBD)

---

## What ships

A petite, peer-of-Lumière standalone bundle distilling the canon **accelerator** axis into a single MIT-licensed repo.

### 3 pillars (specs only)

| pillar       | source (canon@c0f1f570)                                                       | role                                              |
|:-------------|:----------------------------------------------------------------------------------------|:--------------------------------------------------|
| `mini`       | `domains/physics/mini-accelerator/mini-accelerator.md`                                  | benchtop laser-plasma 100 MeV / 1 GeV/m           |
| `parent`     | `domains/physics/particle-accelerator/particle-accelerator.md`                          | integrated parent particle accelerator            |
| `classical`  | `domains/physics/classical-mechanics-accelerator/classical-mechanics-accelerator.md`    | classical-mechanics baseline reference            |

### Tooling

- `cli/hexa-cern.hexa` — placeholder dispatcher (`mini` / `parent` / `classical` each prints `spec-only — TBD`).
- `hexa.toml` — MIT package manifest (entry `cli/hexa-cern.hexa`).
- `install.hexa` — hx package-manager hook (post-install warn-only selftest).
- `tests/test_selftest.hexa` — 3-pillar verb-count smoke check.
- `docs/cern_baseline.md` — LHC 7 TeV/27 km vs DESY 1 GeV/m vs HEXA σ-φ=10 GeV/m comparison.

---

## Honesty (raw#10 C3)

> **specs only, .hexa CLI TBD.** Empirical wiring deferred to Stage-1+ benchtop builds.

- σ-cascade 6-order claim (precision ×10, throughput ×144, energy ÷12, size ÷10, error ÷144, lifetime ×48) is a **design-target ceiling**, not a measurement.
- Comparison vs LHC 7 TeV/27 km + DESY 1 GeV/m baseline is paper-only.
- n=6 invariant (σ(6)=12, τ(6)=4, φ(6)=2) threads the design but is not independently verified per pillar.

---

## Cross-link

- SC magnet substrate → [`dancinlab/hexa-rtsc`](https://github.com/dancinlab/hexa-rtsc)
- Cousin (PET cyclotron / antimatter factory) → [`dancinlab/hexa-antimatter`](https://github.com/dancinlab/hexa-antimatter)
- Stage-3 propulsion dependent → [`dancinlab/hexa-ufo`](https://github.com/dancinlab/hexa-ufo)

---

## What's next (post-v1.0.0)

- `.hexa` CLI dispatchers wired per pillar (`mini` first; laser-plasma sandbox).
- F-gate empirical validation roadmap (paired with sister `lumiere` 2026-08-30 / 2026-09-30 cadence).
- HEXA-RTSC SC-magnet bridge for `mini` pillar.

— dancinlab (박민우 <nerve011235@gmail.com>)
