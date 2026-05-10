# firmware/ — embedded-target absorption tree

> SPEC: SPEC.yaml `firmware_evolution` (Option C, decision 2026-05-10).
> Audit: doc/firmware_audit_2026_05_10.md

This tree absorbs per-board code from `~/core/hexa-*` firmware repos
(hexa-rtsc, hexa-chip, hexa-cern, hexa-antimatter, hexa-space) under
the Option C model:

```
stdlib/                 # shared (core / alloc / hal / embedded / mcu / host)
firmware/               # this tree — board-specific only
├── boards/             # one dir per absorbed repo
│   ├── rtsc/           # hexa-rtsc — Phase D+ verified, 70/70 tests, REFERENCE
│   ├── chip/           # hexa-chip — Phase D iter 5, stdlib/hal consumer
│   ├── cern/           # hexa-cern — Phase D2/3 -> E, Rust to hexa migrate
│   ├── antimatter/     # hexa-antimatter — multi-vendor
│   └── space/          # hexa-space — Phase E hardware, KiCad-first
├── bsp/                # board-support packages (vendor SDK shims)
└── linker_scripts/     # *.ld per MCU; consumed by hexa_ld
```

## Dependency direction

`firmware/*` may import from:
- `stdlib/core/`  — target-agnostic, no alloc, no syscall
- `stdlib/alloc/` — heap + arena (with embedded allocator)
- `stdlib/hal/`   — hardware abstraction (target-gated)
- `stdlib/mcu/`   — MCU-specific (cortex_m, riscv, avr, esp32)
- `stdlib/embedded/` — bare-metal: panic, WFI, intr vectors

`firmware/*` may NOT import:
- `stdlib/net/`, `stdlib/http/`, `stdlib/fs/`, `stdlib/process/` — host-only

The compiler enforces this at compile time via target-gate check
(`--target=*-none-*` rejects host-stdlib imports).

## Roadmap

| Phase | Deliverable | Status |
|---|---|---|
| F0 | SPEC decisions + `firmware/` skeleton | done |
| F1 | `stdlib/core/` extraction from current stdlib | next |
| F2 | `firmware/boards/rtsc/` reference port | this commit |
| F3 | `thumbv7em-none-eabihf` target in compiler/codegen | follow-up |
| F4 | `firmware/boards/{chip,cern,antimatter,space}/` absorptions | follow-up |
| F5 | RFC-023 firmware linker spec | follow-up |

## Reference impl

`firmware/boards/rtsc/` (absorbed 2026-05-10, F2) is the pattern
reference — hexa-rtsc shipped Phase D+ verified at 70/70 tests PASS.
Other boards (chip / cern / antimatter / space) follow its hal usage
conventions during F4.

Absorbed contents include:
- `firmware/sim/*.hexa` — 4 sim controllers (synthesis_ctrl,
  quench_logic, calorimetry_ctrl, squid_daq), each runs under the
  hexa runtime via `use "self/runtime/math_pure"` (resolves against
  hexa-lang's own `self/runtime/`).
- `firmware/hdl/*.v` — Verilog 2001 sources + iverilog testbench
  (12/12 PASS upstream).
- `firmware/mcu/*.rs` — Rust no_std dual-mode drivers
  (`thumbv7em-none-eabihf`, STM32F407VGT6, 1 MiB FLASH / 192 KiB SRAM,
  15/15 cargo tests upstream).
- `firmware/eda/*.kicad_*` — KiCad schematics + BOM.
- `firmware/doc/`, `verify/`, `tests/`, `cli/`, `rtsc/`, `sc/`,
  `LICENSE` (MIT), `CITATION.cff` — preserved verbatim.

Selftest delta post-absorb (2026-05-10):
- `firmware/sim/*` (4 scripts): **4/4 PASS** (43 internal checks)
  via `hexa_interp` from the absorbed location.
- `verify/lattice_check.hexa`: **10/10 PASS**.
- `verify/falsifier_check.hexa`: **49/49 PASS**.
- `verify/cross_doc_audit.hexa`: 7/8 (pre-existing upstream — flags
  `firmware/sim/*.hexa` as rogue per upstream `own 3` code-scope rule;
  NOT a regression from absorb).
- HDL (12/12 iverilog) + MCU (15/15 cargo) layers require iverilog +
  cargo toolchains; not re-run during absorb. Upstream Phase D+
  matrix still holds — absorbed sources are byte-identical to upstream.

## Absorption mechanics

Each `firmware/boards/<repo>/` is a full copy (Option A, decided
2026-05-10) from `~/core/hexa-<repo>/` during F2/F4. The original
repo stays standalone for upstream work; this tree is the
"consumed-by-hexa-lang" view.

Excluded during absorb (build artifacts / runtime markers, all
gitignored upstream):
- `.git/`, `build/`, `firmware/mcu/target/` (cargo)
- `firmware/state/markers/` (~1200 .marker files), `state/markers/`,
  `state/*.log`
- `.DS_Store`, `*.swp`, `*~`, `.claude/`

LICENSE + CITATION.cff are preserved verbatim and verified
byte-identical against upstream during absorb.

Open question: switch to git submodules later? Decided against for
v0 — full copy is simpler, self-contained, and avoids version-skew
risk for downstream consumers. See SPEC.yaml
`firmware_evolution.open_questions`.
