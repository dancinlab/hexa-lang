# Firmware Audit — hexa-lang Integration Plan

> Background agent #83, captured 2026-05-10. Five `~/core/hexa-*`
> firmware repos surveyed. Decision: **Option C — `stdlib/core` +
> `stdlib/alloc` + `firmware/` separation** (Rust `core` model).

## Discovery

| # | Repo | LOC | Phase | Tests | Current hexa-lang link |
|---|---|---|---|---|---|
| 1 | **hexa-rtsc** | 4k | **D+ verified** | **70/70 PASS** | reference impl |
| 2 | hexa-cern | 3k | D2/3 → E | partial | Rust + hexa hybrid |
| 3 | hexa-chip | 2k | D iter 5 | partial | `stdlib/hal` consumer ✓ |
| 4 | hexa-antimatter | 2k | D workspace | partial | multi-vendor |
| 5 | hexa-space | 1k | E hardware | KiCad-first | deferred |

`hexa-etsc` does not exist; `hexa-rtsc` is authoritative (likely user typo).

## Repo classification (per Option C)

| Repo | Strategy |
|---|---|
| hexa-rtsc | **reference** — pin its hal patterns into firmware/ skeleton |
| hexa-chip | absorb into `firmware/boards/chip/` + share hal via `stdlib/hal` |
| hexa-cern | migrate Rust → hexa during Phase E; absorb to `firmware/boards/cern/` |
| hexa-antimatter | `firmware/boards/antimatter/` + multi-vendor hal in stdlib |
| hexa-space | `firmware/boards/space/` once Phase E hardware lands |

## Tree shape (Option C — finalized)

```
stdlib/
├── core/                   # target-agnostic (no alloc, no syscall)
│   ├── int.hexa, slice.hexa, string_view.hexa
│   ├── result.hexa, option.hexa
│   └── math.hexa
├── alloc/                  # heap + arena (RFC-018 §5)
│   ├── vec.hexa, string.hexa, hashmap.hexa
│   └── arena.hexa
├── hal/                    # hardware abstraction (target-gated)
│   ├── spi.hexa, i2c.hexa, uart.hexa, gpio.hexa
│   ├── rf/                 # LoRa, BLE, WiFi
│   ├── sensor/             # ADC, IMU, env
│   └── power/              # thermal, watchdog
├── embedded/               # bare-metal: panic, WFI, intr vectors
├── mcu/                    # MCU-specific
│   ├── cortex_m/, riscv/, avr/, esp32/
└── (host: net, http, fs, process, json, ...)

firmware/
├── boards/
│   ├── chip/               # absorbed hexa-chip
│   ├── cern/               # absorbed hexa-cern (Phase E migration)
│   ├── rtsc/               # absorbed hexa-rtsc (reference)
│   ├── antimatter/         # absorbed hexa-antimatter
│   └── space/              # absorbed hexa-space (deferred)
├── bsp/                    # board-support package per board
└── linker_scripts/         # *.ld for each MCU
```

## Dependency direction

| Edge | Allowed? |
|---|---|
| `firmware/* → stdlib/core` | ✅ |
| `firmware/* → stdlib/alloc` (with embedded allocator) | ✅ |
| `firmware/* → stdlib/hal` | ✅ |
| `firmware/* → stdlib/mcu` | ✅ |
| `firmware/* → stdlib/embedded` | ✅ |
| `firmware/* → stdlib/{net,http,fs,process,...}` (host) | ❌ |
| `compiler/* → stdlib/core` | ✅ (cross-compile path) |
| `compiler/* → stdlib/alloc` | ✅ |
| `stdlib/* → compiler/*` | ❌ (already enforced) |

## New target triples

Add to `targets.tier_1_followup` and `tier_2_later`:

| Triple | Tier | Use case |
|---|---|---|
| `thumbv7em-none-eabihf` | tier_1 | Cortex-M4F (hexa-rtsc, hexa-chip) |
| `thumbv6m-none-eabi` | tier_2 | Cortex-M0/M0+ |
| `thumbv7m-none-eabi` | tier_2 | Cortex-M3 |
| `riscv32imac-unknown-none-elf` | tier_1 | RISC-V 32-bit |
| `xtensa-esp32-none-elf` | tier_2 | ESP32 (hexa-antimatter) |

## SPEC.yaml additions (5 decisions)

1. **stdlib_core_split**: `stdlib/core` (no alloc) + `stdlib/alloc` (heap)
   + current host modules. Compiler may depend on core only when
   cross-compiling to embedded.
2. **firmware_evolution**: `firmware/` separate root tree; per-board
   absorption from existing hexa-* repos.
3. **target_gate_check**: compiler rejects host-stdlib imports when
   `--target=*-none-*` is set (compile-time, not runtime).
4. **embedded_allocator**: arena-only by default (Decision 6 v1);
   optional bump allocator for tight-RAM MCUs.
5. **firmware_linker_scripts**: per-MCU `.ld` files in `firmware/linker_scripts/`;
   `hexa_ld` reads them for memory layout.

## Roadmap

| Phase | Status | Deliverables |
|---|---|---|
| F0 | this commit | SPEC.yaml decisions + `firmware/` skeleton |
| F1 | next | `stdlib/core/` extraction (split from current stdlib) |
| F2 | next | `firmware/boards/rtsc/` reference port (use hexa-rtsc patterns) |
| F3 | follow-up | `thumbv7em-none-eabihf` target in compiler/codegen |
| F4 | follow-up | `firmware/boards/{chip,cern,antimatter,space}/` absorptions |
| F5 | follow-up | RFC-023 firmware linker spec (linker scripts + `.bss/.data` init) |

## Open questions

1. `stdlib/core` extraction: which current host modules are actually
   target-agnostic and can move? (math, slice, result, option seem clear;
   string is borderline due to alloc dependency)
2. `firmware/` absorption: in-place via git submodules, or full copy
   into `firmware/boards/*`? Submodule keeps repos independent;
   copy makes everything self-contained.
3. RFC-023 firmware linker spec: separate RFC or extend RFC-018?
4. CI: cross-compile to MCU targets requires `qemu-system-arm` for
   smoke; do we add that to CI image, or use a vendored qemu in
   `tools/`?

## Biggest unknown

**hexa → ARM Cortex-M native codegen timeline**. RFC-022 (async) is
spec only; native codegen for ARM Thumb-2 is not yet started. Without
F3 landing, `firmware/` stays Rust-gated for hexa-cern/antimatter
until Phase E migration completes.

Mitigation: parallel Rust path keeps Phase D extending; Phase E
hardware commission unblocks once `stdlib/hal v1.0.0` lands (HW-12).
