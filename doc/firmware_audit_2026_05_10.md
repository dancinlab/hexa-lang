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
| F0 | done | SPEC.yaml decisions + `firmware/` skeleton |
| F1 | next | `stdlib/core/` extraction (split from current stdlib) |
| F2 | this commit | `firmware/boards/rtsc/` reference port (absorbed 2026-05-10, Option A full copy, 112 files, 4 sim suites PASS post-absorb) |
| F3 | follow-up | `thumbv7em-none-eabihf` target in compiler/codegen |
| F4 | this commit | `firmware/boards/{chip,cern,antimatter,space}/` absorptions (batch 2026-05-10, Option A full copy, 641 files combined, falsifier_check PASS for all 4) |
| F5 | follow-up | RFC-023 firmware linker spec (linker scripts + `.bss/.data` init) |

## F2 absorption record (2026-05-10)

- **Source:** `~/core/hexa-rtsc` (upstream retained; not modified)
- **Dest:** `firmware/boards/rtsc/`
- **Mechanic:** Option A — full copy via rsync (no submodule)
- **Files moved:** 112 (excludes `.git/`, `build/`, `firmware/mcu/target/`,
  `firmware/state/markers/` ~1200 markers, `state/markers/`, `state/*.log`,
  `.DS_Store`, `*.swp`, `*~`, `.claude/`)
- **LOC moved:** ~18k total (firmware/ subtree ≈ 4k LOC excluding artifacts)
- **License/Citation:** MIT LICENSE + CITATION.cff verified byte-identical
- **Selftest delta:**
  - Pre-absorb upstream: 70/70 PASS (sim 4 + iverilog 12 + cargo 15 + lint 113 / falsifier 43 — per upstream README)
  - Post-absorb (`hexa_interp` from `firmware/boards/rtsc/`):
    - `firmware/sim/{synthesis_ctrl,quench_logic,calorimetry_ctrl,squid_daq}.hexa` — **4/4 PASS** (43 internal checks)
    - `verify/lattice_check.hexa` — **10/10 PASS**
    - `verify/falsifier_check.hexa` — **49/49 PASS**
    - `verify/cross_doc_audit.hexa` — 7/8 (pre-existing upstream `own_3` code-scope FAIL flagging `firmware/sim/*.hexa`; **NOT** an absorb regression — verified by running same script against upstream tree)
    - `firmware/hdl/` (iverilog) and `firmware/mcu/` (cargo) layers deferred — toolchain gated; sources copied byte-identical to upstream Phase D+ verified state, so 12/12 + 15/15 expected to hold
- **Key HAL patterns discovered for later reuse (F4 / `stdlib/hal`):**
  - `use "self/runtime/math_pure"` → resolves against hexa-lang's own
    `self/runtime/` after absorb (no path rewrite needed)
  - PID + 6-interlock state machine (`firmware/sim/synthesis_ctrl.hexa`)
  - 1-of-4 quench-detection logic (`firmware/sim/quench_logic.hexa`)
  - Bachmann-1972 relaxation calorimetry controller (`firmware/sim/calorimetry_ctrl.hexa`)
  - GPIB/SQUID DAQ pipeline + Tc extraction (`firmware/sim/squid_daq.hexa`)
  - Rust no_std dual-mode (`#[cfg_attr(target_os="none", no_std)]`) bridge in `firmware/mcu/lib.rs`
  - STM32F407VGT6 linker (`firmware/mcu/memory.x` — 1 MiB FLASH, 192 KiB SRAM)
  - Verilog 2001 quench detect + iverilog testbench (`firmware/hdl/`)
- **Deferred to F3/F4/F5:**
  - HDL/MCU re-execution (toolchain gated — iverilog + cargo)
  - Promotion of common patterns (PID, interlock, GPIB shim, no_std panic handler) into `stdlib/hal/` and `stdlib/embedded/`
  - `thumbv7em-none-eabihf` native codegen (F3) so MCU layer doesn't need cargo
  - `firmware/linker_scripts/stm32f407.ld` extraction from `firmware/mcu/memory.x` (F5 / RFC-023)
  - `firmware/bsp/stm32f4/` board-support shim (F4)

## F4 absorption record (2026-05-10, batch)

Single-batch absorption of the remaining four firmware repos following
the F2 (`rtsc`) pattern. One commit covers all four boards. Upstream
repos (`~/core/hexa-{chip,cern,antimatter,space}`) were not modified.

**Mechanic:** Option A full-copy via rsync. Excludes (matching F2):
`.git/`, `build/`, `target/`, `*.o`, `*.elf`, `*.bin`, `state/markers/`,
`state/*.log`, `.DS_Store`, `*.swp`, `*~`, `.claude/`.

**Aggregate:** 641 files / ~10.2 MB across the four boards. `cern`
shrank from 547 MB upstream to 1.8 MB absorbed (cargo `target/` =
532 MB filtered out — biggest single-board savings).

### F4.chip — `firmware/boards/chip/`

- **Source:** `~/core/hexa-chip` (Phase D iter 5, `stdlib/hal` consumer)
- **Files moved:** 274 (size 6.2 MB) — largest of the four
- **LOC moved:** ~107k total (incl. CHANGELOG/README); ~24k `.hexa` +
  ~2.2k Verilog; no Rust upstream
- **License/Citation:** MIT LICENSE + CITATION.cff verified byte-identical
- **Banner:** prepended (F4 batch tag) to `README.md`
- **Selftest delta:** `verify/falsifier_check.hexa` — **PASS**
  (4/4 falsifiers F-CHIP-1..4, sat-1/sat-2/sat-3 all met,
  31 verify/*.hexa scripts on disk vs floor of 16)
- **HAL patterns flagged for stdlib/hal promotion:**
  - HBM thermal controller (`firmware/sim/hbm_thermal_controller.hexa`)
    — thermal coordination loop reusable via `stdlib/hal/power/`
  - NPU dispatcher (`firmware/sim/npu_dispatcher.hexa`) — dataflow
    queue arbitration; candidate for `stdlib/hal/sensor/` companion
  - Process corner monitor (`firmware/sim/process_corner_monitor.hexa`)
    — voltage/temp/freq corner sweep, candidate `stdlib/hal/power/`
  - AI-native host bridge (`firmware/mcu/ai_native_host.hexa`) — only
    pure-hexa MCU host in the four boards (no Rust); reference impl
    for `stdlib/mcu/cortex_m/` once F3 lands
  - Photonic + PIM hosts (`firmware/mcu/{photonic,pim}_host.hexa`) —
    novel target shapes, postpone to stdlib/hal v1.1
- **Caveats:** None — fully hexa-native firmware tree (no cargo);
  cleanest of the four absorbs. Pre-existing rich CHANGELOG/CHANGE
  history dominates LOC count.

### F4.cern — `firmware/boards/cern/`

- **Source:** `~/core/hexa-cern` (Phase D2/3 → E, Rust + hexa hybrid)
- **Files moved:** 125 (size 1.8 MB after excludes; upstream 547 MB
  with `firmware/mcu/target/` cargo cache — 532 MB filtered out)
- **LOC moved:** ~31k total; ~9.5k `.hexa` + ~1.2k Verilog + ~430 Rust
- **License/Citation:** MIT LICENSE + CITATION.cff verified byte-identical
- **Banner:** prepended (F4 batch tag) to `README.md`
- **Selftest delta:** `verify/falsifier_check.hexa` — **PASS**
  (3/3 preregistered, 21/21 checks, 100% T1+T2+T3 closure)
- **HAL patterns flagged for stdlib/hal promotion:**
  - ADC + DAC chain pair (`firmware/sim/{adc,dac}_chain.hexa`) —
    paired analog frontend; promote to `stdlib/hal/sensor/adc.hexa`
    and `stdlib/hal/sensor/dac.hexa`
  - Control loop (`firmware/sim/control_loop.hexa`) — generic PID
    counterpart to rtsc's; merge into `stdlib/hal/control.hexa`
  - Timing chain (`firmware/sim/timing_chain.hexa`) — beam-trigger
    sequencer; candidate for `stdlib/hal/timing.hexa`
  - Verilog timing controller + register file
    (`firmware/hdl/timing_ctrl{,_top,_regs}.v`) — accelerator
    bus-interface pattern; HDL stays in firmware/, but the regfile
    layout suggests `stdlib/hal/regfile.hexa` describing
    memory-mapped register conventions
- **Caveats:** **Rust hybrid** — `firmware/mcu/Cargo.{toml,lock}`,
  `memory.x`, `src/` retained. `target/` excluded as planned;
  cargo cache is the 532 MB → 1.8 MB compaction. Phase E plan is
  to migrate Rust → hexa once `thumbv7em` codegen (F3) lands.

### F4.antimatter — `firmware/boards/antimatter/`

- **Source:** `~/core/hexa-antimatter` (Phase D workspace, multi-vendor)
- **Files moved:** 129 (size 1.1 MB)
- **LOC moved:** ~18k total; ~11k `.hexa` + ~360 Verilog + ~440 Rust +
  KiCad assets
- **License/Citation:** MIT LICENSE + CITATION.cff verified byte-identical
- **Banner:** prepended (F4 batch tag) to `README.md`
- **Selftest delta:** `verify/falsifier_check.hexa` — **PASS**
  (4/4 preregistered, 28/28 checks, 4/4 at 100% T1+T2+T3 proxy
  closure). `selftest/selftest.hexa` requires `HEXA_ANTIMATTER_ROOT`
  + sub-shell `hexa run`; deferred (env-driven harness, not an
  absorb regression).
- **HAL patterns flagged for stdlib/hal promotion:**
  - Atomic clock counter (`firmware/sim/atomic_clock_counter.hexa`) —
    high-precision timebase; candidate `stdlib/hal/timing.hexa`
  - Cyclotron trigger (`firmware/sim/cyclotron_trigger.hexa`) —
    pulsed-RF gating; reuses control_loop pattern from cern
  - Multi-vendor KiCad workflow (`firmware/kicad/{atomic_clock,
    pet_cyclotron, tabletop_penning, thrust_acquisition}/`) — first
    real KiCad multi-board layout in the absorbed tree (rtsc had
    one); informs `firmware/eda/` BOM conventions
  - Rust dual-mode (`firmware/mcu/{cpt_bench,pet_cyclotron,tabletop,
    thrust_bench}.rs`) — same `cfg_attr(no_std)` shape as rtsc
- **Caveats:** Multi-vendor firmware — KiCad + Verilog + Rust + hexa
  all coexist. LOC sits between cern and space. Same Rust → hexa
  Phase E migration applies.

### F4.space — `firmware/boards/space/`

- **Source:** `~/core/hexa-space` (Phase E hardware, KiCad-first)
- **Files moved:** 113 (size 1.1 MB) — smallest of the four
- **LOC moved:** ~18k total; ~5k `.hexa` + ~390 Verilog; no Rust upstream
- **License/Citation:** MIT LICENSE + CITATION.cff verified byte-identical
- **Banner:** prepended (F4 batch tag) to `README.md`
- **Selftest delta:** `verify/falsifier_check.hexa` — **PASS**
  (4/4 falsifiers F-SPACE-1..4 each at 67% sat-1 floor)
- **HAL patterns flagged for stdlib/hal promotion:**
  - Launch telemetry pipeline (`firmware/sim/launch_telemetry.hexa`) —
    high-rate streaming sensor capture; candidate `stdlib/hal/sensor/
    telemetry.hexa`
  - Orbit pipeline (`firmware/sim/orbit_pipeline.hexa`) — Kalman /
    state-estimator skeleton; promotes to `stdlib/hal/control.hexa`
  - Raptor cluster + DXA pipeline (`firmware/sim/{raptor_cluster,
    dxa_pipeline}.hexa`) — multi-engine fan-out; informs
    `stdlib/hal/timing.hexa` multi-channel pattern
  - Verilog mirrors (`firmware/hdl/{launch_telemetry,orbit_pipeline,
    raptor_cluster,dxa_pipeline}.v`) — clean 1:1 sim/HDL
    correspondence (cleanest of the four)
- **Caveats:** **KiCad-first** is reflected upstream in the
  top-level `pcb/` and `engineering/` trees, but the `firmware/`
  subtree itself is KiCad-light (no `firmware/kicad/` directory —
  hardware drawings live above the firmware tier). Phase E hardware
  commission still gates HDL-to-silicon; sim layer is fully
  exercisable today.

### F4 aggregate selftest delta

| Board       | Test invoked                | Result | Notes                              |
|-------------|-----------------------------|--------|------------------------------------|
| chip        | verify/falsifier_check.hexa | PASS   | sat-1+sat-2+sat-3 all met, 31 scripts |
| cern        | verify/falsifier_check.hexa | PASS   | 21/21, 100% T1+T2+T3 closure       |
| antimatter  | verify/falsifier_check.hexa | PASS   | 28/28, 4/4 100%                    |
| space       | verify/falsifier_check.hexa | PASS   | 4/4 falsifiers ≥ 67% (sat-1 floor) |

HDL (iverilog) + MCU (cargo) layers deferred per F2 convention —
toolchain-gated; sources copied byte-identical to upstream verified
state, so prior pass matrices are preserved.

### F4 stdlib/hal promotion shortlist (consolidated)

Promote in F4+ small commits, not this batch:

1. `stdlib/hal/control.hexa` — PID / Kalman / state-estimator
   (consolidates rtsc synthesis_ctrl + cern control_loop +
   space orbit_pipeline)
2. `stdlib/hal/sensor/{adc,dac,telemetry}.hexa` — analog frontend +
   high-rate streaming (consolidates cern adc_chain/dac_chain +
   space launch_telemetry)
3. `stdlib/hal/timing.hexa` — multi-channel time base / pulsed gating
   (consolidates antimatter atomic_clock_counter + cern timing_chain
   + space raptor_cluster fan-out)
4. `stdlib/hal/power/{thermal,corner}.hexa` — thermal + process-corner
   monitoring (consolidates rtsc calorimetry + chip hbm_thermal +
   chip process_corner_monitor)
5. `stdlib/hal/regfile.hexa` — memory-mapped regfile conventions
   (informed by cern timing_ctrl_regs.v register layout)

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
