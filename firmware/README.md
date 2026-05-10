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
| F0 | SPEC decisions + `firmware/` skeleton | this commit |
| F1 | `stdlib/core/` extraction from current stdlib | next |
| F2 | `firmware/boards/rtsc/` reference port | next |
| F3 | `thumbv7em-none-eabihf` target in compiler/codegen | follow-up |
| F4 | `firmware/boards/{chip,cern,antimatter,space}/` absorptions | follow-up |
| F5 | RFC-023 firmware linker spec | follow-up |

## Reference impl

`firmware/boards/rtsc/` will be the pattern reference — hexa-rtsc has
the highest completion (Phase D+ verified, 70/70 tests PASS). Other
boards follow its hal usage conventions.

## Absorption mechanics

Each `firmware/boards/<repo>/` is a full copy from `~/core/hexa-<repo>/`
during F2/F4. The original repo stays standalone for upstream work;
this tree is the "consumed-by-hexa-lang" view. Open question: switch
to git submodules later? See SPEC.yaml `firmware_evolution.open_questions`.
