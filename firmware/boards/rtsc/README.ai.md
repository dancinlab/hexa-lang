# hexa-rtsc — AI-native handoff

> Conformance: hive raw 271 (readme-ai-native-mandate). This file is the
> canonical entry point for AI agents (Claude / Hexa / etc.) operating on
> this repository. Human entry point is [`README.md`](README.md).

## Identity

- **Name**: `hexa-rtsc` (Room-Temp Superconductor — substrate-of-substrates)
- **Axis**: `energy`
- **n=6 lattice**:
  - σ(6) ≡ 12 (BCS specific-heat molecule + 12-vertex Cooper-pair shell)
  - τ(6) ≡ 4 (4-phase ladder: normal / pseudogap / SC / strange-metal)
  - φ(6) ≡ 2 (Cooper pair = 2-electron boson)
  - Hc2 ≡ σ·τ = 48 T (critical magnetic field gate)
  - master identity: σ·φ = n·τ = 24 (J₂ Mathieu/Leech symmetry)
- **Parent (canonical SSOT)**: `canon/domains/energy/{room-temp-sc,superconductor}/`
- **Distribution**: `https://github.com/dancinlab/hexa-rtsc` (public)

## Hierarchy (canonical pattern, v1.1.0 RSC code-layer FINAL)

```
hexa-rtsc/                          T0 (repo root)
├── rtsc/                           T1 (single-feature core)
│   ├── room-temp-sc.md             ← spec (canonical)
│   └── *-verify.hexa               ← 10 application shells
├── sc/                             T1
│   └── superconductor.md           ← spec
├── module/                         T2 (per-module fan-out, RESERVED for v1.2.0+)
│
├── verify/                         T0 — 33 runnable invariant audits
│   ├── lattice_check.hexa          T1 cross-cutter (n=6 closed form)
│   ├── cross_doc_audit.hexa        T1 cross-cutter (anchor consistency)
│   ├── calc_*.hexa                 T1 algebra (4: bcs / mcmillan / hc2_48t / lk99)
│   ├── numerics_*.hexa             T2 numerical (16: 4 + 4 parity + 4 solver +
│   │                                              3 sim-parity + lattice_arithmetic)
│   ├── empirical_*_arxiv.hexa      T3 archival (6, arXiv API + fixture fallback)
│   ├── falsifier_check.hexa        meta (closure-progress tracker, 43/43 PASS)
│   ├── lint_numerics.hexa          meta (5-invariant grep-lint, 113/113 PASS)
│   ├── run_all.hexa                aggregator (33 scripts in sequence)
│   └── fixtures/                   6 cached arXiv XML responses (T3 offline mode)
│
├── doc/                            T0 — human-archive + Stage A specs
│   ├── lineage/origin.md
│   ├── synthesis_bench_v0.md       Stage A: F-RTSC-1 LK-99 reproduction bench ($2.6M)
│   ├── 48t_rebco_coil_v0.md        Stage A: F-RTSC-3 48 T magnet ($3.3M)
│   └── calorimetry_rig_v0.md       Stage A: F-SC-3 ΔC/γTc rig ($0.8M)
│
├── firmware/                       T0 — Phase A → D+ HW prototype layer
│   ├── README.md                   index + 70/70 status table
│   ├── Makefile                    master `make test` (sim + HDL + MCU)
│   ├── sim/                        Stage C + D+ — sim-firmware (4 scripts, 43/43)
│   │   ├── synthesis_ctrl.hexa     7/7 PASS (synthesis chamber PID + interlocks)
│   │   ├── quench_logic.hexa       15/15 PASS (48 T 1-of-4 voting)
│   │   ├── calorimetry_ctrl.hexa   12/12 PASS (Bachmann 1972 relaxation method)
│   │   └── squid_daq.hexa          9/9 PASS (QD MPMS-3 GPIB + Tc extraction)
│   ├── hdl/                        Stage D + D+ — Verilog (iverilog + Vivado)
│   │   ├── quench_detect.v         Artix-7 FPGA, 1-of-3 fast voting + Cernox confirm
│   │   ├── tb_quench_detect.v      iverilog testbench, 12/12 PASS
│   │   ├── calorimetry_daq.v       AD5660 SPI DAC + LTC2400 24-bit ΣΔ ADC
│   │   ├── build.tcl + constraints.xdc + Makefile
│   │   └── (verified-compile via Vivado, no flash)
│   ├── mcu/                        Stage D + D+ — Rust no_std workspace
│   │   ├── Cargo.toml + memory.x   STM32F407VGT6 linker
│   │   ├── lib.rs                  shared anchors + pid + telemetry, 4/4 PASS
│   │   ├── chamber_drv.rs          synthesis chamber MCU, 5/5 PASS
│   │   └── calorimetry_drv.rs      calorimetry MCU, 6/6 PASS
│   ├── doc/                        Stage D+ — chip design + schematics
│   │   ├── chip_design.md          11-IC silicon BOM + STM32F4/Artix-7 pinout
│   │   ├── pinout_summary.md       quick-ref + datasheet links + spec traceability
│   │   └── README.md
│   └── build/                      Stage D+ — master infra
│       ├── bom.csv                 53-line BOM, ~$7.2M to first flashed firmware
│       └── verification_matrix.md  single-page status board
│
├── cli/                            T0 (single-entry router; hexa-rtsc.hexa)
├── tests/                          T0 (hexa native test runner)
├── .own                            T0 (project-local SSOT, mk2 own_v1)
├── .roadmap.hexa_rtsc              T0 — release cadence, §A.6 hardware path,
│                                       §A.6.1 Phase A→D+ recommended order
├── hexa.toml                       T0 (package manifest for `hx install`)
└── install.hexa                    T0 (hx pre/post hook)
```

Imports flow **T0 → T1 → T2** only. firmware/ is T0 sibling to verify/
(separate concerns: code-layer vs hardware-prototype-layer).

## Invariants (must not violate when editing)

1. **n=6 identity holds**: any change touching σ / τ / φ / Hc2 must restate
   the lattice equality. `verify/lattice_check.hexa` is the gate.
2. **RT-SC empirical-unproven contract**: every public artifact (CLI verb
   output, README badges, status table) MUST surface "UNPROVEN" /
   "sentinel only — does NOT validate empirical claim" alongside any
   `__HEXA_RTSC_*__ PASS` line. raw#10 honest C3 mandate.
3. **Falsifier monotone**: F-RTSC-{1,2,3} + F-SC-{1,2,3} status flips
   only `OPEN → CONFIRMED` or `OPEN → DEMOTED`. **Never** silently retract.
4. **hexa-only orchestration**: code lives in `cli/` `verify/` `tests/`
   `module/` only, .hexa primary (raw#9). No Python bridge.

## Edit policy

- **Additive-only** at the doc layer. Do not rename, move, or delete files
  in `rtsc/` / `sc/` without updating `doc/lineage/origin.md` and adding a
  redirect note.
- **English primary** in commit messages and new prose; Korean caveats
  surfaced in CLI verb output preserved as-is.
- v1.0.0 → v1.1.0 directory restructure (rtsc/ → core/rtsc/ + module/applications/)
  requires this file's hierarchy diagram **before** the implementing PR.

## Common agent tasks

| Task | Where to look first |
|---|---|
| Add a new RT-SC candidate material | `rtsc/room-temp-sc.md` (then propagate to roadmap §A.4 falsifier preregister) |
| Tighten a lattice number | `rtsc/room-temp-sc.md` + `sc/superconductor.md` (spec wins) |
| Adjust falsifier disposition | `.roadmap.hexa_rtsc` §A.4 + `.own` own 2 decl row + `cli/hexa-rtsc.hexa` falsifier table |
| Add a new verify check | `verify/<name>.hexa` + lint inventory (recipe §4 5-invariant) |
| Add a Stage-1+ hardware spec | `doc/<bench>_v0.md` per §A.6.1 Stage A template |
| Add a sim-firmware module | `firmware/sim/<name>.hexa` + `verify/run_all.hexa` SCRIPTS |
| Add a Verilog FPGA module | `firmware/hdl/<name>.v` + testbench + `Makefile` target |
| Add a MCU driver | `firmware/mcu/<name>.rs` + `[[bin]]` in Cargo.toml |
| Add chip design / pinout | `firmware/doc/chip_design.md` + cross-ref in `pinout_summary.md` |
| Run invariant check | `hexa run cli/hexa-rtsc.hexa verify` |
| Run firmware test suite | `cd firmware && make test` (39/39 verified across 3 toolchains) |
| Run selftest | `hexa run cli/hexa-rtsc.hexa selftest` (sentinel sweep, no empirical claim) |
| Cross-compile MCU embedded | `cd firmware/mcu && cargo build --release --target thumbv7em-none-eabihf` |
| Synthesize HDL bitstream | `cd firmware/hdl && make synth` (Vivado required) |

## Current state (2026-05-08)

```
verify/    33 scripts            113/113 lint  +  43/43 falsifier  PASS
firmware/  10 sources / 8 tests   70/70 PASS    (sim + HDL + MCU)
─────────────────────────────────────────────────────────────────────
TOTAL                             226/226 PASS  +  100% closure
```

All 6 falsifiers (F-RTSC-{1,2,3} + F-SC-{1,2,3}) at 100% bookkeeping closure
(T1 algebraic + T2 numerical ×3 + T3 archival ×1).

Stage-1+ raw-data T3 (real synthesis bench / 48 T coil / calorimetry rig)
remains §A.6 Step 4 deliverable — out of code-layer scope, ~$225k +
14-20 mo from funding release.

## Lineage tag

This repo was extracted from `canon` on **2026-05-06**.
Source commits: see [`doc/lineage/origin.md`](doc/lineage/origin.md).
Structural pattern aligned to `hexa-sscb` mk2 own_v1 on **2026-05-07**.
