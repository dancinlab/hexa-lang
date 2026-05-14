> **ABSORBED VIEW** — Absorbed from `~/core/hexa-cern` on 2026-05-10.
> Upstream repo retained for development; this tree is the
> consumed-by-hexa-lang view per `SPEC.yaml firmware_evolution`
> (Option C, Decision 2026-05-10). See `doc/firmware_audit_2026_05_10.md`
> and `firmware/README.md` for absorption mechanics. F4 batch.
>
> Build artifacts excluded during absorb: `build/`, `target/`,
> `state/markers/`, `.git/`, `*.o/.elf/.bin`.
> LICENSE / CITATION.cff preserved verbatim.

---

# 💫 hexa-cern

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20102596.svg)](https://doi.org/10.5281/zenodo.20102596)

> hexa-cern — n=6 sigma-cascade 6-order benchtop accelerator (100 MeV / 1 GeV/m, mini + parent + classical 3-pillar).

A petite, peer-of-Lumière standalone repo from the `dancinlab` org. Where Lumière takes the camera/character axes, **hexa-cern** takes the *accelerator* axis: three pillars distilled from the canon physics domain into a single MIT-licensed bundle.

---

## § Why — benchtop CERN

LHC fills a 27 km tunnel for 7 TeV. DESY runs a 1 GeV/m laser-plasma prototype on a research-lab footprint. **hexa-cern's design target is a benchtop σ-φ=10 GeV/m continuous-mode accelerator at 100 MeV total**, threaded by the n=6 perfect-number lattice (σ(6)=12, τ(6)=4, φ(6)=2).

The design ceiling — what the spec claims if Stage-1+ empirical builds confirm the σ-cascade — is **6 orders of practical change** vs current tech:

| effect              | LHC/DESY current        | hexa-cern design ceiling   |
|---------------------|-------------------------|------------------------------|
| precision           | 1.0 unit                | **σ-φ = 10× gain**           |
| throughput          | 1.0×                    | **σ² = 144×**                |
| energy cost         | 100%                    | **1/σ ≈ 8.3%**               |
| equipment size      | 1.0 L (or 27 km)        | **1/(σ-φ) = 0.1 L benchtop** |
| error rate          | 1%                      | **1/σ² ≈ 0.7%**              |
| lifetime            | 1 year                  | **σ·τ = 48 months**          |

This is the **why**: a CERN you can put on a bench, drawn from the same n=6 invariant that threads the rest of the HEXA family.

---

## § Verbs — 3 pillars

```
hexa-cern <pillar>            description                                  status
─────────────────────────────────────────────────────────────────────────────────────
hexa-cern mini                HEXA-MINI-ACCEL                              SPEC-ONLY
                                benchtop laser-plasma 100 MeV / 1 GeV/m
hexa-cern parent              HEXA-PACCEL                                  SPEC-ONLY
                                integrated parent particle accelerator
hexa-cern classical           HEXA-CLASSIC-ACCEL                           SPEC-ONLY
                                classical-mechanics baseline reference
```

Plus utility subcmds:

```
hexa-cern status              0/3-wired pillar table + verdict + caveats
hexa-cern selftest            3-pillar sentinel sweep
hexa-cern verify [<sub>]      n=6 invariant + per-pillar calculator audits
                                sub: all (default) | lattice | cross-doc
                                   | wakefield | sigma | classical | falsifier
hexa-cern --version           print version
hexa-cern --help              full usage
```

Pillar specs live under `<pillar>/doc/`:

- [`mini/doc/mini-accelerator.md`](mini/doc/mini-accelerator.md)
- [`parent/doc/particle-accelerator.md`](parent/doc/particle-accelerator.md)
- [`classical/doc/classical-mechanics-accelerator.md`](classical/doc/classical-mechanics-accelerator.md)

---

## § Verification + Status

### Status

> **v1.0.0 specs frozen + v1.1.0-pre `.hexa` runnable surface on `main`.**
> 3-pillar bundle: HEXA-MINI-ACCEL (벤치톱 100 MeV / 1 GeV/m laser-plasma)
> + HEXA-PACCEL (integrated parent) + HEXA-CLASSIC-ACCEL. LHC 7 TeV/27km
> & DESY 1 GeV/m 기준선에 대한 n=6 σ-cascade 6-order 비교가 paper-only로
> 명시. 실증은 F-PCERN-1/2/3 falsifier가 닫힐 때까지 UNVERIFIED.

v1.0.0 ships (frozen 2026-05-06):

- 3 pillar specs (`.md`, extracted from `canon@c0f1f570`)
- a `cli/hexa-cern.hexa` dispatcher with 3 pillar verbs + status / selftest

v1.1.0-pre adds (on `main`, 2026-05-07):

- `verify/` — 12 `.hexa` scripts auditing n=6 lattice + per-pillar derivations + numerical solvers
- `build/` — pandoc + xelatex Makefile that regenerates 3 pillar PDFs (clean)
- `tests/` — 4 `.hexa` test cases (+ `test_all.hexa` aggregator); 4/4 PASS
- `cli/hexa-cern.hexa verify [<sub>]` — 6-runner aggregator subcommand
- `hexa.toml` v1.1.0-pre [closure] block: `verify_pass: 6/6`, `tests: 4/4`

**Zero `.py` was added** — the runnable surface is 100% `.hexa`. This is
deliberate: hexa-cern is a hexa-family member, and the migration target
across `dancinlab` repos is .hexa-native tooling.

What it does **not** ship: actual particle acceleration, Geant4/MAD-X bridge, real-time beam diagnostics, LHC/DESY data ingestion. The σ-cascade 6-order claim is a **design-target ceiling**, not a measurement.

### Verification

The `verify/` surface (all `.hexa`) audits n=6 closure + per-pillar derivations:

| script | check | result |
|---|---|---|
| `verify/lattice_check.hexa`        | σ(6)·φ(6) = n·τ(6) = J₂ = 24 across roadmap + 3 pillars | 23/23 PASS |
| `verify/cross_doc_audit.hexa`      | LHC / DESY / OEIS / BT cross-link consistency           | 11/11 PASS |
| `verify/calc_wakefield.hexa`       | mini — E_peak = σ·(σ-φ) = 120 GV/m, a₀ = n = 6, R = 10 cm | 6/6 PASS |
| `verify/numerics_wakefield.hexa`   | mini — closed-form plasma numerics (n_e, L_d via math_pure) | 4/4 PASS |
| `verify/calc_sigma_cascade.hexa`   | parent — E_0..E_6 chain (10 MeV → 100 TeV)               | 8/8 PASS |
| `verify/numerics_sigma_cascade.hexa` | parent — relativistic γ progression numerics (γ_6/γ_2 ≈ 10⁵, ultrarel) | 10/10 PASS |
| `verify/calc_classical.hexa`       | classical — DOF = n = 6, phase-space dim = σ = 12        | 11/11 PASS |
| `verify/numerics_classical.hexa`   | classical — symplectic leapfrog (τ=4 quadrants, 1-DOF, |Δstate| ≈ 10⁻⁵) | 9/9 PASS |
| `verify/numerics_cross_pillar.hexa` | cross-pillar numerical consistency (mini ↔ parent ↔ classical, λ_p / λ_laser, γ@100 MeV) | 8/8 PASS |
| `verify/numerics_lhc_parity.hexa`  | F-PCERN-1 collider parity (LEP/Tevatron/LHC/FCC vs σ-cascade) | 10/10 PASS |
| `verify/numerics_lwfa_parity.hexa` | F-PCERN-3 LWFA parity (BELLA/FACET/ATHENA/FLASHFwd vs hexa-cern design point) | 7/7 PASS |
| `verify/falsifier_check.hexa`      | F-PCERN-1/2/3 preregister checklist                       | 3/3 registered (UNVERIFIED v1.0) |

Run them all with the unified CLI subcommand:

```bash
hexa-cern verify all      # 12/12 PASS expected
```

Or build the 3 pillar PDFs:

```bash
make -C build check       # verify pandoc + xelatex + hexa available
make -C build all         # rebuild all 3 pillar PDFs into build/out/
```

Empirical wiring (laser-plasma sandbox, parent integration, classical
baseline solver) is deferred to Stage-1+ benchtop builds. See
[`docs/cern_baseline.md`](docs/cern_baseline.md) for the LHC 7 TeV/27 km
vs DESY 1 GeV/m vs HEXA σ-φ=10 GeV/m comparison table, and
[`docs/numerics_methodology.md`](docs/numerics_methodology.md) for how
the verify surface is structured (3-tier evidence ladder, F-PCERN
closure pct, math_pure conventions, recipe for adding new numerics).

---

## § Install

```bash
# package manager (recommended)
hx install hexa-cern

# or clone directly:
git clone https://github.com/dancinlab/hexa-cern
cd hexa-cern
hexa run cli/hexa-cern.hexa status
hexa run cli/hexa-cern.hexa verify all   # 12/12 PASS expected
```

After `hx install hexa-cern`, the shim lands at `~/.hx/bin/hexa-cern`.
Run `hexa-cern verify all` from anywhere — the CLI auto-resolves
`PETITE_CERN_ROOT` from `~/.hx/packages/hexa-cern`.

Cost (Mac local): **$0** — verify scripts are pure `.hexa` (file reads + arithmetic).

---

## § Repository layout

```
hexa-cern/
├── README.md                     ← this file
├── LICENSE                       ← MIT
├── hexa.toml                     ← package manifest (hx install hexa-cern)
├── install.hexa                  ← hx install hook (post-install selftest)
├── .roadmap.hexa_cern            ← cross-cutting state (lattice / cycles / falsifiers)
├── CHANGELOG.md                  ← release history
├── RELEASE_NOTES_v1.0.0.md       ← v1.0.0 cut notes
│
├── mini/doc/mini-accelerator.md                            ← pillar 1 (47 KB)
├── parent/doc/particle-accelerator.md                      ← pillar 2 (14 KB)
├── classical/doc/classical-mechanics-accelerator.md        ← pillar 3 (47 KB)
│
├── cli/
│   └── hexa-cern.hexa            ← CLI router (status/selftest/verify/mini/parent/classical)
├── verify/                       ← v1.1.0-pre — n=6 audit surface (.hexa)
│   ├── lattice_check.hexa            ← σ·φ = n·τ = J₂ = 24 closure   (23/23)
│   ├── cross_doc_audit.hexa          ← LHC/DESY/OEIS/BT cross-pillar (11/11)
│   ├── calc_wakefield.hexa           ← mini — laser-wakefield n=6   ( 6/ 6)
│   ├── numerics_wakefield.hexa       ← mini — closed-form n_e/L_d   ( 4/ 4)
│   ├── numerics_lwfa_parity.hexa     ← mini — vs DESY/SLAC LWFA refs ( 7/ 7)
│   ├── calc_sigma_cascade.hexa       ← parent — E_0..E_6 chain      ( 8/ 8)
│   ├── numerics_sigma_cascade.hexa   ← parent — relativistic γ      (10/10)
│   ├── numerics_lhc_parity.hexa      ← parent — vs LEP/Tev/LHC/FCC  (10/10)
│   ├── calc_classical.hexa           ← classical — Lagrange/Hamilton(11/11)
│   ├── numerics_classical.hexa       ← classical — symplectic leap. ( 9/ 9)
│   ├── numerics_cross_pillar.hexa    ← mini ↔ parent ↔ classical    ( 8/ 8)
│   └── falsifier_check.hexa          ← F-PCERN-1/2/3 + closure %    (11/11)
├── build/
│   ├── Makefile                  ← pandoc + xelatex 3-PDF rebuild
│   ├── header.tex                ← LaTeX include (CJK + monospace; soft-guarded)
│   └── out/*.pdf                 ← generated, .gitignore'd
├── tests/                        ← v1.1.0-pre — regression suite (.hexa)
│   ├── test_selftest.hexa
│   ├── test_lattice.hexa
│   ├── test_calculators.hexa
│   ├── test_cli_verify.hexa
│   └── test_all.hexa             ← runs everything above (4/4 PASS)
└── docs/cern_baseline.md         ← LHC vs DESY vs hexa-cern comparison
```

The `verify/ + build/ + tests/` triad is the canonical runnable
surface for hexa-cern: every audit + every PDF + every test is `.hexa`
end-to-end (no Python, no shell-only logic).

---

## § Cross-link

| dependency / cousin                  | repo                                                  | role                                |
|-------------------------------------:|:------------------------------------------------------|:------------------------------------|
| SC magnet substrate                  | [`dancinlab/hexa-rtsc`](https://github.com/dancinlab/hexa-rtsc)             | superconducting magnet primitive    |
| cousin (PET cyclotron, antimatter)   | [`dancinlab/hexa-antimatter`](https://github.com/dancinlab/hexa-antimatter) | parallel acceleration use case      |
| Stage-3 propulsion dependent         | [`dancinlab/hexa-ufo`](https://github.com/dancinlab/hexa-ufo)               | downstream propulsion consumer      |

Provenance: extracted from [`canon`](https://github.com/dancinlab/echoes) at SHA `c0f1f570` on 2026-05-06.

Sister repo (peer extraction): [`dancinlab/lumiere`](https://github.com/dancinlab/lumiere) — camera-filter + hexa-main-character apps-axis.

---

## § License

MIT — see [`LICENSE`](LICENSE).

Copyright (c) 2026 dancinlab (박민우 <nerve011235@gmail.com>)
