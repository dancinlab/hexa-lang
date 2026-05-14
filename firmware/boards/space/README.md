> **ABSORBED VIEW** — Absorbed from `~/core/hexa-space` on 2026-05-10.
> Upstream repo retained for development; this tree is the
> consumed-by-hexa-lang view per `SPEC.yaml firmware_evolution`
> (Option C, Decision 2026-05-10). See `doc/firmware_audit_2026_05_10.md`
> and `firmware/README.md` for absorption mechanics. F4 batch.
>
> Build artifacts excluded during absorb: `build/`, `target/`,
> `state/markers/`, `.git/`, `*.o/.elf/.bin`.
> LICENSE / CITATION.cff preserved verbatim.

---

# 🚀 hexa-space — Space Toolkit (HEXA family)

> **27-verb space substrate** in **5 groups** + **runnable surface**
> (RSC saturated 2026-05-08) + **Stage-1 procurement-prep**:
>
> - **core** (cosmic, starship)
> - **engineering** (aerospace, aerospace_transport, engineering, systems)
> - **observation** (astrodynamics, astronomy, obs_astronomy)
> - **life** (astrobiology, medicine)
> - **operations** (ext, 16 — see [§operations](#operations-ext-16--drafted-from-spacex-intel-2026-05-07))
>
> Per `bedrock/docs/runnable_surface_recipe.md` (RSC) — all 4
> preregistered falsifiers `F-SPACE-{1,2,3,4}` reach **67 % closure**
> (T1 algebraic ✓ + T2 numerical ✓; T3 hardware-only awaits Phase F
> funding). `verify/` ships 12 cross-cutter scripts (`lattice_check`,
> `cross_doc_audit`, 6× `numerics_*`, `falsifier_check`, `lint_numerics`,
> `saturation_check`, `board_audit`) + 4 Stage-1 `firmware/sim/*.hexa`
> sim-firmware (Phase C) + 4 `firmware/hdl/*.v` Vivado-synth Verilog
> skeletons (Phase D) + 4 `firmware/board/*/` per-board procurement
> bundles (Phase E — schematic + BOM + PCB stack-up + commissioning
> checklist + KiCad-readable `.kicad_sch`).

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20102622.svg)](https://doi.org/10.5281/zenodo.20102622)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.1.0--pre-informational.svg)](CHANGELOG.md)
[![Manifest](https://img.shields.io/badge/manifest-hexa.toml-lightgrey.svg)](hexa.toml)
[![Verbs: 27](https://img.shields.io/badge/verbs-27_(11_canonical_+_16_ops)-blue.svg)](#verbs)
[![Wired: 16/27](https://img.shields.io/badge/wired-16%2F27_(16%2F16_ops_+_0%2F11_canonical)-green.svg)](#verbs)
[![Groups: 5](https://img.shields.io/badge/groups-core_·_engineering_·_observation_·_life_·_operations-purple.svg)](#verbs)
[![Provenance: n6@c0f1f570](https://img.shields.io/badge/provenance-n6--architecture@c0f1f570-blue.svg)](https://github.com/dancinlab/echoes)
[![Tests: 5 harnesses](https://img.shields.io/badge/tests-5_harnesses_PASS-success.svg)](#verifying)
[![RSC: saturated](https://img.shields.io/badge/RSC-saturated_2026--05--08-success.svg)](.roadmap.hexa_space)
[![Falsifiers: 4/4 @ 67%](https://img.shields.io/badge/F--SPACE--*-4%2F4_@_67%25-success.svg)](verify/falsifier_check.hexa)
[![Phase: A→E ✓ · F gated](https://img.shields.io/badge/phase-A→E_✓_·_F_gated-yellow.svg)](firmware/board/README.md)

---

## Why

`hexa-space` is the **standalone Space Toolkit** in the HEXA family — a
spec-first single-source-of-truth substrate that:

1. pulls every space domain registered under
   `canon/domains/space/` (canonical 11 verbs) into one
   organized CLI surface, and
2. **extends** that core with a 16-verb `operations` group that
   *interprets* SpaceX-domain entities (Starship · Falcon · Dragon ·
   Starlink · DTC · Mars roadmap · MondAloy alloy · …) onto the n=6
   invariant lattice.

It is the n=6 substrate's empirical companion for the **space axis**
(sister of `hexa-bio` for biology and `hexa-cosmos` for theoretical
cosmology).

```
                            ┌──────────────────────┐
                            │       hexa-space     │
                            │       (n=6 axis)     │
                            └──────────┬───────────┘
                                       │
        ┌────────────┬─────────────┬───┴─────────┬───────────┬──────────────┐
        │            │             │             │           │              │
   ┌────▼────┐  ┌────▼────┐  ┌─────▼─────┐  ┌────▼────┐  ┌───▼──────────┐
   │  core   │  │engineer-│  │observation│  │  life   │  │  operations  │
   │  (2)    │  │ ing (4) │  │   (3)     │  │   (2)   │  │ (16, ext)    │
   └─────────┘  └─────────┘  └───────────┘  └─────────┘  └──────────────┘
                                                              ▲
                                                              │
                                                    drafted from SpaceX
                                                    intel 2026-05-07
                                                    (pending-upstream)
```

The lattice anchors every verb in a single algebraic identity:

```
σ(6) = 12        12 frequency channels / 12 vertices
τ(6) = 4         4 regimes / phase ladder
φ(6) = 2         binary observation dichotomy
J₂   = 24        octahedral rotation group order
sopfr(6) = 5     2 + 3 = 5 (sum of prime factors)

master identity:   σ · φ = n · τ = 12 · 2 = 6 · 4 = 24
```

For ops verbs the lattice closes empirically against the SpaceX 2026
snapshot — e.g. `sopfr⁴ · J₂ = 15,000` (DTC FCC filing exact),
`σ·sopfr²/φ = 150` (DTC throughput target Mbps),
`σ·n/φ − 3 = 33` (Super Heavy Raptor count).

---

## Directory layout

```
hexa-space/
├── cli/
│   └── hexa-space.hexa          ← unified dispatcher (status/group/ops/verify/spacex)
├── verify/                       ← RSC §1 cross-cutter inventory (12 scripts)
│   ├── lattice_check.hexa        n=6 master closure across 27 verbs   24/24
│   ├── cross_doc_audit.hexa      anchor consistency across docs       18/18
│   ├── numerics_kepler.hexa      F-SPACE-1 T2 (Kepler 3rd, math_pure)  6/6
│   ├── numerics_falcon.hexa      F-SPACE-2 T2 (octaweb + Tsiolkovsky)  9/9
│   ├── numerics_starship.hexa    F-SPACE-4 T2 (33-Raptor + Δv)         9/9
│   ├── numerics_bone_loss.hexa   F-SPACE-3 T2 (exp-decay + half-life)  8/8
│   ├── numerics_lattice_arithmetic.hexa  math_pure float ↔ int      12/12
│   ├── numerics_cross_pillar.hexa        anchor agreement              8/8
│   ├── falsifier_check.hexa      F-SPACE-* closure-pct tracker         4/4
│   ├── lint_numerics.hexa        recipe §4 5-invariant lint           31/31
│   ├── saturation_check.hexa     RSC self-stop probe (STOP triggered)
│   └── board_audit.hexa          Phase E doc audit                   32/32
├── firmware/                     ← Stage-1+ T3 closure path (.roadmap §A.6)
│   ├── doc/README.md             Phase C/D/E scope + Phase F readiness
│   ├── sim/                      Phase C — sim-firmware (.hexa, runs under hexa)
│   │   ├── orbit_pipeline.hexa            HEXA-ORBIT-01  (F-SPACE-1)  13/13
│   │   ├── launch_telemetry.hexa          HEXA-LAUNCH-01 (F-SPACE-2)  11/11
│   │   ├── dxa_pipeline.hexa              HEXA-DXA-01    (F-SPACE-3)  11/11
│   │   └── raptor_cluster.hexa            HEXA-RAPTOR-01 (F-SPACE-4)  11/11
│   ├── hdl/                      Phase D — Vivado-synth Verilog skeletons
│   │   ├── orbit_pipeline.v               xc7z020 / STM32H7 HLS shim
│   │   ├── launch_telemetry.v             xczu7ev (Zynq US+ ZCU104)
│   │   ├── dxa_pipeline.v                 xc7z020 / STM32H7 HLS shim
│   │   └── raptor_cluster.v               xcku040 (Kintex US KCU105)
│   └── board/                    Phase E — per-board procurement prep
│       ├── README.md                       4-board catalog + KiCad workflow
│       ├── orbit_01/  launch_01/  dxa_01/  raptor_01/
│       │   ├── SCHEMATIC.md      block diagram + net list + power tree
│       │   ├── BOM.csv           line-item BOM with Digi-Key MPNs + prices
│       │   ├── PCB.md            stack-up + outline + routing rules + EMC
│       │   ├── COMMISSIONING.md  Phase F bring-up + closure-event gate
│       │   └── <slug>.kicad_sch  KiCad 7+ root sheet skeleton
│       └── orbit_01/orbit_01.kicad_pro  full KiCad project file
├── tests/                        ← regression harnesses (5 in hexa.toml [test])
│   ├── test_selftest.hexa        11/11 canonical verb-spec sweep
│   ├── test_spacex.hexa          5/5 spacex-track
│   ├── test_ops.hexa             16/16 ops verb sweep
│   ├── test_lattice.hexa         11/11 cross-cutter (verify/) sweep
│   └── test_firmware.hexa        4/4 Phase C sim-firmware sweep
├── cosmic/  starship/                                   ← core (2)
├── aerospace/  aerospace_transport/  engineering/  systems/   ← engineering (4)
├── astrodynamics/  astronomy/  obs_astronomy/                 ← observation (3)
├── astrobiology/  medicine/                                   ← life (2)
├── spaceship/  satellite/  space_center/  space_ai_center/    ← operations (16, ext)
├── space_datacenter/  falcon/  dragon/  recovery/
├── orbital_depot/  hls/  starlink/  rideshare/
├── station/  mars_base/  direct_to_cell/  mondaloy/
├── aerospace_transport/spacex_intel_2026.md             ← ops data feed (web sweep 2026-05-07)
├── hexa.toml                    ← manifest (27 modules + 5 tests)
├── install.hexa                 ← hx install hook
├── CHANGELOG.md  README.md  RELEASE_NOTES_v1.0.0.md  LICENSE
└── .roadmap.hexa_space          ← terminal goal + falsifiers + §A.6 Stage-1+ closure path
```

Quick links:
[`cli/`](cli/) ·
[`verify/`](verify/) ·
[`firmware/`](firmware/) ·
[`tests/`](tests/) ·
[`hexa.toml`](hexa.toml) ·
[`install.hexa`](install.hexa) ·
[`CHANGELOG.md`](CHANGELOG.md) ·
[`LICENSE`](LICENSE) ·
[`.roadmap.hexa_space`](.roadmap.hexa_space)

---

## Closure status (RSC §3 ladder)

Per [`bedrock/docs/runnable_surface_recipe.md`](https://github.com/dancinlab/bedrock) — closure ladder
`0 % → 33 % → 67 % → 100 %` per falsifier.

### Falsifier preregister + tier closure

| Falsifier | Domain anchor | T1 (algebraic) | T2 (numerical) | T3 (hardware) | % |
|:----------|:--------------|:--------------:|:--------------:|:--------------:|:-:|
| F-SPACE-1 | Kepler 3rd law n=6 corrections (Mercury 43″/century baseline) | [`astrodynamics/verify_*`](astrodynamics/verify_astrodynamics.hexa) ✓ | [`numerics_kepler`](verify/numerics_kepler.hexa) ✓ | Phase F+G+H | **67 %** |
| F-SPACE-2 | Falcon 9 9-engine octaweb (3·3 grid = σ−φ+1) | [`falcon/verify_*`](falcon/verify_falcon.hexa) ✓ | [`numerics_falcon`](verify/numerics_falcon.hexa) ✓ | Phase F+G+H | **67 %** |
| F-SPACE-3 | ISS bone-loss τ=4 phase recovery (NASA Twin Study) | [`medicine/verify_*`](medicine/verify_space-medicine.hexa) ✓ | [`numerics_bone_loss`](verify/numerics_bone_loss.hexa) ✓ | Phase F+G+H | **67 %** |
| F-SPACE-4 | Starship 33-Raptor cluster (σ·n/φ−3) | [`spaceship/verify_*`](spaceship/verify_spaceship.hexa) ✓ | [`numerics_starship`](verify/numerics_starship.hexa) ✓ | Phase F+G+H | **67 %** |

`hexa run verify/falsifier_check.hexa` → `__HEXA_SPACE_FALSIFIER_CHECK__ PASS  4/4 ≥ 67%`.
`hexa run verify/saturation_check.hexa` → `__HEXA_SPACE_RSC_SATURATED__ STOP`.

### Phase ladder (closure path)

| Phase | Layer | Status | Artefact |
|:------|:------|:------:|:---------|
| **A** | Recipe baseline (RSC §1 12-cross-cutter inventory) | ✅ | `verify/` |
| **B** | Per-falsifier T1 algebraic + T2 numerical | ✅ | pillar `verify_*` + `verify/numerics_*` |
| **C** | Sim-firmware (state-machine + DAC/ADC pipeline) | ✅ 46/46 PASS | `firmware/sim/*.hexa` |
| **D** | HDL skeleton (Vivado 2024.1+ synthesizable) | ✅ 4/4 boards | `firmware/hdl/*.v` |
| **E** | Procurement prep (schematic + BOM + PCB + commissioning + KiCad) | ✅ 32/32 audit PASS | `firmware/board/*/` |
| **F** | Physical board procurement | ❌ **funding gate ~$26 k** (Stage-1 program) | (external — JLCPCB / PCBWay) |
| **G** | Bench commissioning (per `COMMISSIONING.md` checklists) | ❌ requires F | (external bench) |
| **H** | F-SPACE-N T3 closure event (flips falsifier_check to 100 %) | ❌ requires G | updates `falsifier_check.hexa` F<N>_T3 anchor |

**Stage-1 program cost** (qty 5 each + Vivado license shared) ≈ **$26 k** within `.roadmap §A.6` ~$25 k envelope.

---

## Verbs

27 verbs / 5 groups. Canonical 11 are `.md` design docs cp -R'd from
`canon/domains/space/` (sha `c0f1f570`). Operations 16 are
locally drafted; spec MD + `verify_*.hexa` lattice script per verb.

### core (2)

| Verb       | Source dir (n6)         | Spec file              |
|------------|-------------------------|------------------------|
| `cosmic`   | `space/hexa-cosmic/`    | [`cosmic/hexa-cosmic.md`](cosmic/hexa-cosmic.md) |
| `starship` | `space/hexa-starship/`  | [`starship/hexa-starship.md`](starship/hexa-starship.md) |

### engineering (4)

| Verb                  | Source dir (n6)                  | Spec file                                   |
|-----------------------|----------------------------------|---------------------------------------------|
| `aerospace`           | `space/aerospace/`               | [`aerospace/aerospace.md`](aerospace/aerospace.md) |
| `aerospace_transport` | `space/aerospace-transport/`     | [`aerospace_transport/aerospace-transport.md`](aerospace_transport/aerospace-transport.md) |
| `engineering`         | `space/space-engineering/`       | [`engineering/space-engineering.md`](engineering/space-engineering.md) |
| `systems`             | `space/space-systems/`           | [`systems/space-systems.md`](systems/space-systems.md) |

> The `aerospace_transport` verb additionally hosts the SpaceX intel
> data feed: [`aerospace_transport/spacex_intel_2026.md`](aerospace_transport/spacex_intel_2026.md)
> (source of truth for the operations group below) + three companion
> `.hexa` scripts:
> [`verify_spacex.hexa`](aerospace_transport/verify_spacex.hexa)
> (n=6 calculator),
> [`verify_mk_ladder.hexa`](aerospace_transport/verify_mk_ladder.hexa)
> (24-rung future projection through 2050),
> [`analyze_spacex.hexa`](aerospace_transport/analyze_spacex.hexa)
> (23-program registry analyzer).

### observation (3)

| Verb            | Source dir (n6)                     | Spec file                                       |
|-----------------|-------------------------------------|-------------------------------------------------|
| `astrodynamics` | `space/astrodynamics/`              | [`astrodynamics/astrodynamics.md`](astrodynamics/astrodynamics.md) |
| `astronomy`     | `space/astronomy/`                  | [`astronomy/astronomy.md`](astronomy/astronomy.md) |
| `obs_astronomy` | `space/observational-astronomy/`    | [`obs_astronomy/observational-astronomy.md`](obs_astronomy/observational-astronomy.md) |

### life (2)

| Verb           | Source dir (n6)         | Spec file                          |
|----------------|-------------------------|------------------------------------|
| `astrobiology` | `space/astrobiology/`   | [`astrobiology/astrobiology.md`](astrobiology/astrobiology.md) |
| `medicine`     | `space/space-medicine/` | [`medicine/space-medicine.md`](medicine/space-medicine.md) |

### operations (ext, 16) — drafted from SpaceX intel 2026-05-07

Pending upstream landing in `canon/domains/space/`. Each verb
ships a spec MD + `verify_<verb>.hexa` lattice-closure script and is
runnable via `hexa run cli/hexa-space.hexa verify <verb>`.

| Verb               | Spec file                                                                                  | Verify script                                                                                          | Domain anchor / signature identity                       |
|--------------------|--------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|----------------------------------------------------------|
| `spaceship`        | [`spaceship/spaceship.md`](spaceship/spaceship.md)                                         | [`verify_spaceship.hexa`](spaceship/verify_spaceship.hexa)                                             | Starship vehicle · `σ·n/φ − 3 = 33` Raptors              |
| `satellite`        | [`satellite/satellite.md`](satellite/satellite.md)                                         | [`verify_satellite.hexa`](satellite/verify_satellite.hexa)                                             | Starlink + Dragon · `sopfr⁴·J₂ = 15,000` (FCC)           |
| `space_center`     | [`space_center/space_center.md`](space_center/space_center.md)                             | [`verify_space_center.hexa`](space_center/verify_space_center.hexa)                                    | Starbase + Cape · `sopfr = 5` active pads                |
| `space_ai_center`  | [`space_ai_center/space_ai_center.md`](space_ai_center/space_ai_center.md)                 | [`verify_space_ai_center.hexa`](space_ai_center/verify_space_ai_center.hexa)                           | autonomy + Optimus · `n·σ·τ = J₂·σ = 288` ctrl-bits      |
| `space_datacenter` | [`space_datacenter/space_datacenter.md`](space_datacenter/space_datacenter.md)             | [`verify_space_datacenter.hexa`](space_datacenter/verify_space_datacenter.hexa)                        | orbital edge compute · `σ = 12` GPU-eq cores/sat         |
| `falcon`           | [`falcon/falcon.md`](falcon/falcon.md)                                                     | [`verify_falcon.hexa`](falcon/verify_falcon.hexa)                                                      | F9 + FH · `J₂ + σ + φ + 2 = 40` reuse cert               |
| `dragon`           | [`dragon/dragon.md`](dragon/dragon.md)                                                     | [`verify_dragon.hexa`](dragon/verify_dragon.hexa)                                                      | Crew + Cargo Dragon · `σ + τ = 16` Dracos                |
| `recovery`         | [`recovery/recovery.md`](recovery/recovery.md)                                             | [`verify_recovery.hexa`](recovery/verify_recovery.hexa)                                                | drone-ship + chopstick · `J₂ − τ = 20` HDA               |
| `orbital_depot`    | [`orbital_depot/orbital_depot.md`](orbital_depot/orbital_depot.md)                         | [`verify_orbital_depot.hexa`](orbital_depot/verify_orbital_depot.hexa)                                 | propellant transfer · `σ = 12` tanker ceiling            |
| `hls`              | [`hls/hls.md`](hls/hls.md)                                                                 | [`verify_hls.hexa`](hls/verify_hls.hexa)                                                               | Artemis HLS Starship · `J₂ = 24` t to surface            |
| `starlink`         | [`starlink/starlink.md`](starlink/starlink.md)                                             | [`verify_starlink.hexa`](starlink/verify_starlink.hexa)                                                | constellation · `sopfr⁴·J₂ = 15,000` DTC sats            |
| `rideshare`        | [`rideshare/rideshare.md`](rideshare/rideshare.md)                                         | [`verify_rideshare.hexa`](rideshare/verify_rideshare.hexa)                                             | Transporter + Bandwagon · `σ² − n·τ − 1 = 119` payloads  |
| `station`          | [`station/station.md`](station/station.md)                                                 | [`verify_station.hexa`](station/verify_station.hexa)                                                   | Vast Haven-1 + Axiom · `τ·τ·n = J₂` mission-days/life    |
| `mars_base`        | [`mars_base/mars_base.md`](mars_base/mars_base.md)                                         | [`verify_mars_base.hexa`](mars_base/verify_mars_base.hexa)                                             | Mars settlement · `sopfr = 5` ships (2026 wave)          |
| `direct_to_cell`   | [`direct_to_cell/direct_to_cell.md`](direct_to_cell/direct_to_cell.md)                     | [`verify_direct_to_cell.hexa`](direct_to_cell/verify_direct_to_cell.hexa)                              | DTC 5G NR · `σ·sopfr²/φ = 150` Mbps target               |
| `mondaloy`         | [`mondaloy/mondaloy.md`](mondaloy/mondaloy.md)                                             | [`verify_mondaloy.hexa`](mondaloy/verify_mondaloy.hexa)                                                | Ni-base superalloy (Raptor 3) · `n·τ·σ = 288` cycle      |

---

## Verifying

Five test harnesses live in [`tests/`](tests/) and are wired into
[`hexa.toml`](hexa.toml) `[test]`:

| Harness                                                | Scope                                                                          | Result          |
|--------------------------------------------------------|--------------------------------------------------------------------------------|-----------------|
| [`tests/test_selftest.hexa`](tests/test_selftest.hexa) | 11 canonical verb-spec presence sweep                                          | **11/11 PASS**  |
| [`tests/test_spacex.hexa`](tests/test_spacex.hexa)     | spacex track: verify + mk_ladder + analyzer + cli proxy + selftest regression | **5/5 PASS**    |
| [`tests/test_ops.hexa`](tests/test_ops.hexa)           | 16 ops verb sweep + cli `ops verify-all` proxy                                | **16/16 PASS**  |
| [`tests/test_lattice.hexa`](tests/test_lattice.hexa)   | 11 RSC cross-cutter (verify/) sweep — direct + cli-proxy each                 | **11/11 PASS**  |
| [`tests/test_firmware.hexa`](tests/test_firmware.hexa) | 4 Phase C sim-firmware sentinel sweep (HEXA-{ORBIT,LAUNCH,DXA,RAPTOR}-01)     | **4/4 PASS**    |

Run them all:

```bash
for t in tests/test_selftest.hexa tests/test_spacex.hexa tests/test_ops.hexa \
         tests/test_lattice.hexa tests/test_firmware.hexa; do
    HEXA_SPACE_ROOT=$PWD hexa run "$t" | tail -3
done
```

Or run any single cross-cutter / firmware sim via the CLI proxy:

```bash
hexa run cli/hexa-space.hexa verify lattice            # 24/24 EXACT
hexa run cli/hexa-space.hexa verify falsifier          # 4/4 ≥ 67%
hexa run cli/hexa-space.hexa verify saturation         # __HEXA_SPACE_RSC_SATURATED__ STOP
hexa run cli/hexa-space.hexa verify board-audit        # 32/32 Phase E doc audit
hexa run cli/hexa-space.hexa verify fw-orbit           # 13/13 sim-firmware
hexa run cli/hexa-space.hexa verify numerics-kepler    # 6/6 Kepler T2
```

---

## CLI (unified `hexa-space` dispatcher)

Entry: [`cli/hexa-space.hexa`](cli/hexa-space.hexa).

```bash
hexa run cli/hexa-space.hexa <subcmd> [args]
```

| Subcmd                  | Description |
|-------------------------|-------------|
| `status`                | 27-verb status table + caveats |
| `selftest`              | canonical-verb presence sweep (11/11 expected) |
| `group <name>`          | list verbs in `core` / `engineering` / `observation` / `life` / `operations` |
| `ops [list\|verify-all]` | operations registry / 16-verb verify sweep |
| `verify <verb>`         | run `verify_<verb>.hexa` for any registered verb |
| `verify-all`            | run every available `verify_*.hexa` across all 5 groups |
| `verify <cross-cutter>` | run any RSC cross-cutter — see table below |
| `spacex <subcmd>`       | SpaceX 2026 program registry (intel/list/active/upcoming/group/show/counts/verify/mk) |
| `--version`             | print version |

### RSC cross-cutter aliases (`verify <name>`)

| Alias | Script | Sentinel | Use |
|:------|:-------|:---------|:----|
| `lattice`                       | `verify/lattice_check.hexa`                  | `__HEXA_SPACE_LATTICE__ PASS`                       | n=6 master closure across 27 verbs (24/24) |
| `cross-doc`                     | `verify/cross_doc_audit.hexa`                | `__HEXA_SPACE_CROSSDOC__ PASS`                      | anchor consistency across docs (18/18) |
| `numerics-kepler`               | `verify/numerics_kepler.hexa`                | `__HEXA_SPACE_NUMERICS_KEPLER__ PASS`               | F-SPACE-1 T2 |
| `numerics-falcon`               | `verify/numerics_falcon.hexa`                | `__HEXA_SPACE_NUMERICS_FALCON__ PASS`               | F-SPACE-2 T2 |
| `numerics-starship`             | `verify/numerics_starship.hexa`              | `__HEXA_SPACE_NUMERICS_STARSHIP__ PASS`             | F-SPACE-4 T2 |
| `numerics-bone-loss`            | `verify/numerics_bone_loss.hexa`             | `__HEXA_SPACE_NUMERICS_BONE_LOSS__ PASS`            | F-SPACE-3 T2 |
| `numerics-lattice-arithmetic`   | `verify/numerics_lattice_arithmetic.hexa`    | `__HEXA_SPACE_NUMERICS_LATTICE_ARITHMETIC__ PASS`   | math_pure float ↔ int floor |
| `numerics-cross-pillar`         | `verify/numerics_cross_pillar.hexa`          | `__HEXA_SPACE_NUMERICS_CROSS_PILLAR__ PASS`         | cross-pillar T2 anchor agreement |
| `falsifier`                     | `verify/falsifier_check.hexa`                | `__HEXA_SPACE_FALSIFIER_CHECK__ PASS`               | F-SPACE-* closure-pct tracker |
| `lint-numerics`                 | `verify/lint_numerics.hexa`                  | `__HEXA_SPACE_LINT_NUMERICS__ PASS`                 | recipe §4 5-invariant lint |
| `saturation`                    | `verify/saturation_check.hexa`               | `__HEXA_SPACE_SATURATION_CHECK__ PASS` + `STOP` signal | RSC self-stop probe |
| `board-audit`                   | `verify/board_audit.hexa`                    | `__HEXA_SPACE_BOARD_AUDIT__ PASS`                   | Phase E doc audit (32/32) |
| `fw-orbit`                      | `firmware/sim/orbit_pipeline.hexa`           | `__HEXA_SPACE_FW_ORBIT_01__ PASS`                   | Phase C sim — HEXA-ORBIT-01 |
| `fw-launch`                     | `firmware/sim/launch_telemetry.hexa`         | `__HEXA_SPACE_FW_LAUNCH_01__ PASS`                  | Phase C sim — HEXA-LAUNCH-01 |
| `fw-dxa`                        | `firmware/sim/dxa_pipeline.hexa`             | `__HEXA_SPACE_FW_DXA_01__ PASS`                     | Phase C sim — HEXA-DXA-01 |
| `fw-raptor`                     | `firmware/sim/raptor_cluster.hexa`           | `__HEXA_SPACE_FW_RAPTOR_01__ PASS`                  | Phase C sim — HEXA-RAPTOR-01 |

Examples:

```bash
hexa run cli/hexa-space.hexa status
hexa run cli/hexa-space.hexa ops verify-all       # 16/16 ops PASS
hexa run cli/hexa-space.hexa verify mondaloy      # 9/9 EXACT
hexa run cli/hexa-space.hexa verify lattice       # n=6 closure 24/24
hexa run cli/hexa-space.hexa verify falsifier     # 4/4 ≥ 67% closure
hexa run cli/hexa-space.hexa verify saturation    # __HEXA_SPACE_RSC_SATURATED__ STOP
hexa run cli/hexa-space.hexa verify fw-orbit      # 13/13 Phase C HEXA-ORBIT-01
hexa run cli/hexa-space.hexa verify board-audit   # 32/32 Phase E docs
hexa run cli/hexa-space.hexa verify-all           # all 5 groups (canonical pillars)
hexa run cli/hexa-space.hexa spacex intel         # SpaceX 2026 snapshot path
hexa run cli/hexa-space.hexa spacex active        # active programs only
hexa run cli/hexa-space.hexa spacex group starship
```

---

## Status

**27-verb 통합 substrate · RSC saturated (sat-1 ✓ + sat-2 ✓ at 2026-05-08) ·
4/4 falsifiers @ 67 % closure · Phase A-E ✓ · Phase F funding-gated.**

### Honest closure C3 (raw#10)

- 11 canonical verbs at v1.0.0 ship as **spec-only** (`.md` design docs).
- **20 pillar `verify_<verb>.hexa` scripts** test n=6 **bookkeeping closure**
  against domain anchors (16 ops verbs + aerospace + aerospace_transport
  + engineering + astrodynamics + medicine).  They verify that the
  count-lattice math is internally consistent, **NOT** that physics
  obeys σ=12 / τ=4 / J₂=24.
- **12 cross-cutter `verify/*.hexa` scripts** (RSC §1) close the recipe
  inventory: lattice + cross-doc + 6 numerics + 4 meta (falsifier,
  lint, saturation, board-audit).
- **4 Phase C sim-firmware** scripts model Stage-1 controllers with
  state machines + DAC/ADC pipelines + safety-interlock logic
  (`__HEXA_SPACE_FW_*__ PASS` × 4, 46/46 individual checks).
- **4 Phase D HDL skeletons** (.v Verilog) compile in Vivado 2024.1+
  but are **not flashable** until Phase F boards arrive.
- **4 Phase E procurement-prep bundles** (schematic + BOM + PCB +
  commissioning + KiCad-readable .kicad_sch) document the path to
  ~$26 k Stage-1 board procurement.
- The n=6 invariant lattice (σ=12, τ=4, φ=2, J₂=24, sopfr(6)=5) is
  *hypothesized* for canonical verbs and *operationally fitted* for
  ops verbs against documented SpaceX numbers.  T3 closure event
  (Phase F+G+H) will test whether real silicon agrees with the
  closed-form derivations within recipe-stated tolerances.
- Verdict: **`SPEC_PLUS_OPS_LATTICE_RSC_SATURATED`** (27/27 spec;
  16/27 wired pillar; 12/12 RSC cross-cutter; Phase A-E ✓; F-SPACE-1/2/3/4
  all 67 %; T3 awaits Phase F).

---

## Install

### Via `hx` (recommended, after registry registration)

```bash
hx install hexa-space          # global, pulls latest from registry
hx install hexa-space@1.0.0    # pin specific version
hexa-space --version           # → 1.0.0
```

`hx install hexa-space` pulls all 27 verbs (canonical 11 + operations
16) plus the SpaceX intel data feed (registered in
`hexa.toml [modules].hexa`).

### Via git clone (works today)

```bash
git clone https://github.com/dancinlab/hexa-space.git ~/.hexa-space
export HEXA_SPACE_ROOT=~/.hexa-space
export PATH="$HEXA_SPACE_ROOT/cli:$PATH"

# Verify canonical 11 verb-specs present:
hexa run $HEXA_SPACE_ROOT/cli/hexa-space.hexa selftest

# Verify all 16 operations verbs (lattice closure):
hexa run $HEXA_SPACE_ROOT/cli/hexa-space.hexa ops verify-all

# Browse a group:
hexa run $HEXA_SPACE_ROOT/cli/hexa-space.hexa group operations
```

The repo is **dependency-free** (no Python, no native build). All 27
verb spec files are pure markdown. The 16 ops `verify_*.hexa`
scripts are pure hexa-lang (raw#9 STRICT — no Python).

---

## Cross-link

- **Sister theory-side substrate**: [`dancinlab/hexa-cosmos`](https://github.com/dancinlab/hexa-cosmos) — cosmology + particle + cosmic-observatory (theory companion to this engineering / observation / life axis).
- **Sister starship axis**: [`dancinlab/hexa-ufo`](https://github.com/dancinlab/hexa-ufo) — extends the `starship` verb with anomaly-vehicle modeling.
- **Sister biology axis**: [`dancinlab/hexa-bio`](https://github.com/dancinlab/hexa-bio) — molecular toolkit (weave/nanobot/ribozyme/virocapsid).
- **Upstream SSOT (canonical specs)**: `canon/domains/space/` (sha [`c0f1f570`](https://github.com/dancinlab/echoes/commit/c0f1f570)).
- **Operations data feed**: [`aerospace_transport/spacex_intel_2026.md`](aerospace_transport/spacex_intel_2026.md) — SpaceX 2026 active+upcoming program registry (web sweep 2026-05-07; 30+ sources cited in §5 of that file).

---

## License

MIT. See [LICENSE](LICENSE).
