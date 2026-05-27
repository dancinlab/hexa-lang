> **ABSORBED VIEW** — Absorbed from `~/core/hexa-antimatter` on 2026-05-10.
> Upstream repo retained for development; this tree is the
> consumed-by-hexa-lang view per `SPEC.yaml firmware_evolution`
> (Option C, Decision 2026-05-10). See `doc/firmware_audit_2026_05_10.md`
> and `firmware/README.md` for absorption mechanics. F4 batch.
>
> Build artifacts excluded during absorb: `build/`, `target/`,
> `state/markers/`, `.git/`, `*.o/.elf/.bin`.
> LICENSE / CITATION.cff preserved verbatim.

---

# ☄️ hexa-antimatter

> 반물질 substrate — antimatter-factory + tabletop + PET cyclotron. n=6 Dirac-mirror lattice.

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20077465.svg)](https://doi.org/10.5281/zenodo.20077465)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.1.0--RSC--FINAL-informational.svg)](CHANGELOG.md)
[![Verbs: 3/3 wired](https://img.shields.io/badge/verbs-3%2F3_wired_(computational)-brightgreen.svg)](#verbs)
[![Verify: 38/38 PASS](https://img.shields.io/badge/verify-38%2F38_PASS-brightgreen.svg)](#build--verify)
[![Closure: 100%](https://img.shields.io/badge/F--AM--1%2F2%2F3%2F4-100%25_closure-brightgreen.svg)](#closure-progress)
[![n=6 Dirac-mirror](https://img.shields.io/badge/n%3D6-σ%3D12_τ%3D4_φ%3D2_J₂%3D24-purple.svg)](#why)
[![Status: RSC SATURATED](https://img.shields.io/badge/status-RSC__SATURATED__STOP-blue.svg)](#status)

---

## § Why (n=6 Dirac-mirror lattice)

Antimatter is the Dirac-mirror partner of ordinary matter — every fermion has a CPT-conjugate. The n=6 invariant lattice anchors three independent antimatter axes (factory / tabletop / PET-cyclotron) onto a single algebraic substrate:

```
σ(6) = 12        Dirac-mirror cycle states (hypothesized)
τ(6) = 4         4-stage ladder (production / capture / storage / regeneration)
φ(6) = 2         binary dichotomy (matter vs antimatter)
J₂   = 24        octahedral O ⊂ icosahedral I subgroup

master identity:   σ · φ = n · τ = 12 · 2 = 6 · 4 = 24
```

The lattice serves as an organizing scaffold for the three verbs; its empirical verification for any antimatter axis is **not** claimed at v1.0.0.

---

## § Verbs (3-verb)

| Verb            | Status              | Source                              | n=6 lattice projection                          | Headline candidate                  |
|-----------------|---------------------|-------------------------------------|--------------------------------------------------|--------------------------------------|
| `factory`       | WIRED v1.0.0        | canon/antimatter-factory  | σ·τ=48 T, σ²=144 SM, n/φ=3 vote, σ-φ=10× gain   | 1e12 p-bar/hr, 24-month storage     |
| `tabletop`      | WIRED v1.0.0        | canon/tabletop-antimatter | σ³=1728× prod, σ⁶ cost reduction, σ·τ²=192 mo  | 0.29 m³, 1.7e12 p-bar/s, $2.1e4/mg  |
| `pet_cyclotron` | WIRED v1.0.0        | canon/pet-cyclotron       | R=σ-φ=10 cm, B=σ·τ=48 T, σ·τ=48 mg/season ¹⁸F   | 48 mg ¹⁸F/season, 2e9 e⁺/s/mg       |

The three verbs form a **triangle** within the HEXA family substrate registry:

```
                    ┌─────────────────────┐
                    │      factory        │
                    │  (CERN-scale 200 m³)│
                    │       [WIRED]        │
                    └──────────┬──────────┘
                               │
                ┌──────────────┴──────────────┐
                │                             │
       ┌────────▼─────────┐         ┌─────────▼────────┐
       │     tabletop     │         │   pet_cyclotron  │
       │ (desktop 0.29 m³)│         │ (¹⁸F β⁺ on-site) │
       │      [WIRED]     │         │      [WIRED]     │
       └──────────────────┘         └──────────────────┘
```

---

## § Repository layout

```
hexa-antimatter/
├── README.md / CHANGELOG.md / LICENSE / hexa.toml      ← project meta
├── .roadmap.hexa_antimatter                             ← §A.1–§A.6.1 (release + falsifiers + hardware path)
│
├── factory/        ← F-AM-3 (Dirac mirror n=6)
│   ├── antimatter-factory.md              (declarative SSOT)
│   ├── factory.hexa                       (n=6 derived numbers)
│   └── doc/benchtop_v0_design.md          (Phase A: $4.2M CPT bench BOM)
├── tabletop/       ← F-AM-2 (σ·J₂=288 density)
│   ├── tabletop-antimatter.md
│   ├── tabletop.hexa
│   └── doc/benchtop_v0_design.md          (Phase A: $3.5M Penning trap BOM)
├── pet_cyclotron/  ← F-AM-1 (¹⁸F β⁺ regen)
│   ├── pet-cyclotron.md
│   ├── pet_cyclotron.hexa
│   └── doc/benchtop_v0_design.md          (Phase A: ~$1.3M cyclotron BOM)
│
├── cli/hexa-antimatter.hexa               ← 3-verb router + 30+ verify sub-targets
│
├── verify/                                ← 25 .hexa scripts (T1+T2+T3+meta)
│   ├── n6_arithmetic.hexa                 ← σ·φ = n·τ = J₂ = 24 algebraic
│   ├── cross_doc_audit.hexa               ← SSOT lattice alignment
│   ├── release_ladder.hexa                ← v1.0 → v2.0 cadence
│   ├── calc_{factory,tabletop,pet_cyclotron,break_even}.hexa  ← T1 algebra ×4
│   ├── numerics_{...}.hexa                ← T2 numerical ×14 (basic + parity + solver + Stage-1 sim parity)
│   ├── empirical_*_inspire.hexa           ← T3 paper-feed proxy ×4 (Inspire-HEP)
│   ├── falsifier_check.hexa               ← 4/4 F-AM closure tracker
│   ├── lint_numerics.hexa                 ← 5-invariant grep-lint
│   ├── firmware_phase_d_lint.hexa         ← Phase D paper-spec drift catcher
│   ├── saturation_check.hexa              ← RSC self-stop signal (sat-1+sat-2+sat-3)
│   ├── all.hexa                           ← 38-step aggregator
│   └── fixtures/                          ← 16 cached Inspire-HEP JSON
│
├── firmware/                              ← Phase C / C.5 / D scaffolding
│   ├── doc/README.md                       (Phase C/C.5/D file-layout map)
│   ├── doc/board_v0_*.md            ×4    (Phase C.5: pinout + catalog SKUs + bring-up)
│   ├── doc/schematic_v0_*.md        ×4    (Phase C.5: block schematic + net list)
│   ├── sim/*.hexa                   ×4    (Phase C: golden behavioral sim)
│   ├── hdl/{*.v, *.xdc, build.tcl}        (Phase D: Vivado-synthesizable Verilog)
│   └── mcu/{*.rs, Cargo.toml, lib.rs}     (Phase D: Rust no_std skeletons)
│
├── selftest/selftest.hexa                 ← 3-verb sentinel sweep
└── tests/test_*.hexa (7)                  ← regression harness
```

---

## § Status

**v1.1.0 RSC code-layer FINAL.  3-verb substrate.  `RSC_SATURATED__ STOP` + 4/4 falsifier 100% bookkeeping closure.  No working apparatus (honest C3).**

- **3/3 verbs wired computationally** — each verb derives candidate numbers from the n=6 lattice (`σ·τ=48`, `σ²=144`, `σ-φ=10`, `σ³=1728`, `σ⁶≈3×10⁶`) at runtime.  `0/3 wired empirically`.
- `.hexa` CLI now dispatches 30+ `verify` sub-targets across **25 verify scripts** (4 cross-cutter + 4 calc T1 + 14 numerics T2 + 4 empirical T3 + 3 meta).  `verify all` runs the 38-step aggregator.
- **All 4 falsifiers (F-AM-1/2/3/4)** carry T1 algebra + T2 ×4 numerics (incl. Stage-1 sim parity) + T3 paper-existence (Inspire-HEP, ≥3 of 4 milestones per falsifier).  → 100% bookkeeping closure.  Strict raw-data fit awaits Stage-1+ hardware (.roadmap §A.6, v2.0.0 ASPIRATIONAL).
- `verify/saturation_check.hexa` emits `__HEXA_ANTIMATTER_RSC_SATURATED__ STOP` + `__RSC_FULL_CLOSURE__ 100%` — RSC closure-depth-accumulation loop properly terminates.
- Phase A → B → C → C.5 → D paper specifications **all landed** (BOM → numerics → sim → board pinout → HDL/MCU skeletons).  No PCBs / no flashed firmware exist; § A.6.1 step 4 awaits funding.

---

## § Build & verify

```bash
# unified verifier sweep (38 steps: cross-cutter + T1 + T2 + T3 + meta + sim-firmware + saturation)
hexa run verify/all.hexa                                  # → 38/38 verifiers PASS

# Phase A — abstract BOM (docs)
ls {factory,tabletop,pet_cyclotron}/doc/benchtop_v0_design.md

# Phase B — Stage-1 simulation parity
hexa run verify/numerics_pet_realistic.hexa               # F-AM-1 T2×4
hexa run verify/numerics_tabletop_relativistic.hexa       # F-AM-2 T2×4
hexa run verify/numerics_dirac_precision.hexa             # F-AM-3 T2×4
hexa run verify/numerics_break_even_thrust.hexa           # F-AM-4 T2×4

# Phase C — golden behavioral sim
hexa run firmware/sim/cyclotron_trigger.hexa              # 13/13 PASS
hexa run firmware/sim/penning_rf.hexa                     # 11/11 PASS
hexa run firmware/sim/atomic_clock_counter.hexa           # 11/11 PASS
hexa run firmware/sim/thrust_acquisition.hexa             # 10/10 PASS

# T3 paper-existence (Inspire-HEP API + fixture fallback)
hexa run verify/empirical_pet_inspire.hexa                # F-AM-1 T3
hexa run verify/empirical_tabletop_inspire.hexa           # F-AM-2 T3
hexa run verify/empirical_dirac_inspire.hexa              # F-AM-3 T3
hexa run verify/empirical_break_even_inspire.hexa         # F-AM-4 T3
HEXA_ANTIMATTER_OFFLINE=1 hexa run verify/empirical_*_inspire.hexa  # offline (fixture only)

# meta — closure tracker + lint + saturation
hexa run verify/falsifier_check.hexa                      # 4/4 F-AM at 100%
hexa run verify/lint_numerics.hexa                        # 18 numerics conform
hexa run verify/firmware_phase_d_lint.hexa                # Phase D paper-spec drift
hexa run verify/saturation_check.hexa                     # → __RSC_SATURATED__ STOP

# CLI dispatch (30+ sub-targets)
hexa run cli/hexa-antimatter.hexa status
hexa run cli/hexa-antimatter.hexa verify [target]         # target = all|n6|docs|...|empirical-pet|firmware-thrust|saturation
hexa run cli/hexa-antimatter.hexa compute n6
hexa run cli/hexa-antimatter.hexa selftest

# regression: 7 .hexa test harnesses
for t in tests/test_*.hexa; do hexa run "$t"; done        # → 7/7 PASS
```

### Closure progress — 2026-05-08

| F-AM | Pillar | T1 (algebra) | T2 (numerical, ×4) | T3 (paper proxy) | Closure |
|:-----|:-------|:------------:|:-------------------|:----------------:|:-------:|
| F-AM-1 | PET ¹⁸F regen | calc_pet_cyclotron | numerics ×4 (basic + parity + solver + realistic) | empirical_pet_inspire | **100% 🎯** |
| F-AM-2 | tabletop σ·J₂=288 | calc_tabletop | numerics ×4 (basic + parity + 2-DOF + relativistic) | empirical_tabletop_inspire | **100% 🎯** |
| F-AM-3 | Dirac mirror | calc_factory | numerics ×4 (basic + parity + Verlet + precision) | empirical_dirac_inspire | **100% 🎯** |
| F-AM-4 | Stage-3 break-even | calc_break_even | numerics ×4 (basic + parity + Tsiolkovsky + thrust) | empirical_break_even_inspire | **100% 🎯** |

Re-run after any SSOT edit. Verifiers exit non-zero on drift. RSC saturation_check passes only when all 4 falsifiers carry T1+T2≥3+T3≥1 simultaneously.

---

## § Install

### Via `hx` from local path (verified 2026-05-07)

```bash
hx install /path/to/hexa-antimatter   # auto-detects [package].entry from hexa.toml
hexa-antimatter --version             # → 1.0.0
```

The build hook (`install.hexa`) runs the 3-verb selftest and reports `selftest PASS — 3/3 sentinels present`. `hx` symlinks the package into `~/.hx/packages/hexa-antimatter` and writes a wrapper shim at `~/.hx/bin/hexa-antimatter`.

### Via `hx` from registry (when published)

```bash
hx install hexa-antimatter            # global, pulls latest from registry
hx install hexa-antimatter@1.0.0      # pin specific version
hexa-antimatter --version             # → 1.0.0
```

### Via git clone (raw fallback)

```bash
git clone https://github.com/dancinlab/hexa-antimatter.git ~/.hexa-antimatter
export HEXA_ANTIMATTER_ROOT=~/.hexa-antimatter
export PATH="$HEXA_ANTIMATTER_ROOT/cli:$PATH"

# Run any subcommand:
hexa run $HEXA_ANTIMATTER_ROOT/cli/hexa-antimatter.hexa selftest
```

### Quick Start

```bash
hexa-antimatter status                  # 3/3 wired status table + caveats
hexa-antimatter selftest                # 3-verb sentinel sweep
hexa-antimatter verify                  # 4-step orchestrator (n6 + docs + ladder + selftest)
hexa-antimatter verify n6               # algebraic identity 12/12 PASS
hexa-antimatter verify docs             # cross-document n=6 invariant audit
hexa-antimatter verify ladder           # v1.0.0 → v2.0.0 release cadence
hexa-antimatter compute n6              # derived numbers from n=6 lattice
hexa-antimatter factory                 # σ·τ=48 T, σ²=144 SM, σ-φ=10× gain
hexa-antimatter tabletop                # σ³=1728× prod, σ⁶ cost reduction
hexa-antimatter pet_cyclotron           # R=σ-φ=10 cm, B=σ·τ=48 T, ¹⁸F stock
```

---

## § Cross-link

- **`dancinlab/hexa-cern`** — accelerator cousin (compact-accelerator substrate)
- **`dancinlab/hexa-ufo`** — Stage-3 propulsion fuel dependency (UFO substrate sources its antimatter fuel from this repo)
- Sister substrate: [`dancinlab/hexa-bio`](https://github.com/dancinlab/hexa-bio) (molecular toolkit, HEXA family)
- Upstream concept SSOTs (declarative):
  - `canon/domains/physics/antimatter-factory/antimatter-factory.md`
  - `canon/domains/physics/tabletop-antimatter/tabletop-antimatter.md`
  - `canon/domains/physics/pet-cyclotron/pet-cyclotron.md`
- Provenance commit: `canon` SHA `c0f1f570`

---

## § License

MIT. See [LICENSE](LICENSE).
