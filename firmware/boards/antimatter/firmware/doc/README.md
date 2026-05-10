# `firmware/` — sim + board specs + Phase D scaffolding + Phase E plans

> §A.6.1 Phase C + C.5 + D + E scope.  Five layers:
>   · `sim/`  — Phase C behavioral sim (golden spec, 4 boards)
>   · `doc/board_v0_*.md` + `doc/schematic_v0_*.md` — Phase C.5 board-spec (pinout + BOM + power + bring-up + block schematic)
>   · `hdl/` + `mcu/` — Phase D synthesizable / cross-compilable skeletons
>   · `doc/PHASE_E_HARDWARE_PATH.md` — single consolidated Phase E roadmap
>     (KiCad / PCB / procurement / vendor matrix / funding ladder / bring-up)

**Status**: paper firmware (2026-05-08) · **HW-in-the-loop**: ✗ (no boards) · **Compiles + tests**: ✓ via `hexa run`

---

## §1 Scope

Each `firmware/sim/*.hexa` models the controller logic of one benchtop:
trigger sequencer, DAC/ADC pipeline, safety interlock, telemetry log.
Pure-software sim — no FPGA bitstream, no MCU flash image, no real
hardware bus.  Hardware-in-the-loop integration deferred to Phase D
(post-§A.6 step 2 funding).

## §2 Inventory (Phase C + C.5 + D)

| Pillar | F-AM | Phase C sim (golden) | Phase C.5 board doc | Phase D HDL | Phase D MCU |
|:-------|:----:|:---------------------|:--------------------|:------------|:------------|
| pet_cyclotron | F-AM-1 | `sim/cyclotron_trigger.hexa` | `doc/board_v0_pet_cyclotron.md` | `hdl/cyclotron_trigger.v` (placeholder) | `mcu/pet_cyclotron.rs` |
| tabletop | F-AM-2 | `sim/penning_rf.hexa` | `doc/board_v0_tabletop_penning.md` | `hdl/penning_rf.v` | `mcu/tabletop.rs` |
| factory CPT | F-AM-3 | `sim/atomic_clock_counter.hexa` | `doc/board_v0_atomic_clock.md` | `hdl/atomic_clock.v` | `mcu/cpt_bench.rs` |
| propulsion | F-AM-4 | `sim/thrust_acquisition.hexa` | `doc/board_v0_thrust_acquisition.md` | `hdl/thrust_acq.v` | `mcu/thrust_bench.rs` |

(`cyclotron_trigger.v` is a placeholder — board is MCU-only; logic
lives in `mcu/pet_cyclotron.rs`.)

### Layer-by-layer scope

- **Phase C** (`sim/*.hexa`) — pure-software state-machine + DAC/ADC
  pipeline + safety verification.  PASS criterion for Phase D bring-up.
- **Phase C.5** (`doc/board_v0_*.md`) — paper PCB spec: pinout, catalog
  SKUs (Digi-Key/Mouser/Avnet), power budget, bring-up checklist.
  Direct input for KiCad / PCB CAM.
- **Phase D — HDL** (`hdl/*.v` + `build.tcl`) — Vivado-synthesizable
  Verilog top-level modules.  Compiles, but bitstream requires
  board-specific `.xdc` constraints (Phase D when boards arrive).
- **Phase D — MCU** (`mcu/*.rs` + `Cargo.toml`) — `no_std` Rust
  skeletons with `#[cfg(test)]` host-side tests covering sim parity.

## §3 Pattern

Each sim follows hexa-antimatter convention:
- `use "self/runtime/math_pure"`
- `let mut RUN = 0` / `let mut FAIL = 0` counters
- `__HEXA_ANTIMATTER_FIRMWARE_<NAME>__ PASS` sentinel
- `FALSIFIERS` list (firmware-class retract conditions)
- `exit(0)` on PASS

The simulator runs the controller's state machine in-process and
asserts:
1. Timing invariants (e.g., RF burst gate precedes target shutter open)
2. ADC-loop stability (no over/under-flow in nominal envelope)
3. Safety interlock fires within budget (e.g., < 10 ms abort path)
4. Telemetry log integrity (no dropped frames at nominal rate)
5. n=6 anchor preserved through DAC scaling (σ·τ = 48 normalized)

## §4 Phase D readiness

When boards arrive (post-§A.6 step 2):
- Cyclotron trigger → STM32H7 firmware (Cortex-M7, 480 MHz)
  → expand `mcu/pet_cyclotron.rs` skeleton with `stm32h7xx-hal` HAL init
- Penning RF → Xilinx UltraScale+ FPGA + AD9162/AD9208
  → fill `hdl/penning_rf.v` JESD204C IP + DDR4 + RS-485 from `doc/board_v0_tabletop_penning.md` constraints
- Atomic clock counter → UltraScale+ + dedicated TDC
  → fill `hdl/atomic_clock.v` TDC SPI controller + ADF4356 init
- Thrust acquisition → UltraScale+ + 16× ADC + NIM/CAMAC trigger
  → fill `hdl/thrust_acq.v` JESD204C ×8 + DDR4 burst + PCIe Gen4 ×16 XDMA

Each `sim/*.hexa` is the **PASS criterion** for the corresponding HDL
or MCU bring-up (board test step 14–15 per `doc/board_v0_*.md §7`).

## §5 Out of scope

- HDL synthesis (Verilog → bitstream) — Phase D
- MCU cross-compilation (Rust embedded / C bare-metal) — Phase D
- Hardware-in-the-loop with real boards — Phase D + funding
- Real-time scheduling guarantees — Phase D + RTOS layer

## §6 File layout

```
firmware/
├─ doc/
│  ├─ README.md                          (this file)
│  ├─ board_v0_<board>.md           ×4   (Phase C.5: pinout + BOM + power + bring-up)
│  ├─ schematic_v0_<board>.md       ×4   (Phase C.5: block schematic + net list)
│  └─ PHASE_E_HARDWARE_PATH.md           (Phase E roadmap: KiCad → fab → bring-up
│                                        + vendor matrix + funding ladder + entry criteria)
├─ sim/                                   (Phase C: golden behavioral)
│  ├─ cyclotron_trigger.hexa
│  ├─ penning_rf.hexa
│  ├─ atomic_clock_counter.hexa
│  └─ thrust_acquisition.hexa
├─ hdl/                                   (Phase D: Verilog skeletons)
│  ├─ README.md
│  ├─ build.tcl                           (Vivado batch)
│  ├─ <board>.v                           (top + spec + 7-state FSM stub)
│  └─ <board>.xdc                    ×3   (Vivado pin constraints)
├─ mcu/                                   (Phase D: Rust no_std)
│  ├─ README.md · Cargo.toml · lib.rs
│  ├─ pet_cyclotron.rs                    (STM32H743 cortex-m7)
│  ├─ tabletop.rs                         (MPSoC PS cortex-a53)
│  ├─ cpt_bench.rs                        (STM32H723 + XCKU040)
│  └─ thrust_bench.rs                     (STM32H743 + XCVU13P)
└─ (Phase E artefacts — created when funding lands; see
   firmware/doc/PHASE_E_HARDWARE_PATH.md §7 for target paths:
   pcb/<board>/{*.kicad_sch,*.kicad_pcb,gerbers/,BOM.csv} ×4 +
   state/<live>_LOG.hexa ×4 + firmware/build/{*.elf,*.bit})
```

## §7 Cross-link

- `verify/numerics_*_{realistic,relativistic,precision,thrust}.hexa` — Phase B sim parity (T2×4)
- `verify/firmware_phase_d_lint.hexa` — Phase D paper-spec drift catcher
- `{factory,tabletop,pet_cyclotron}/doc/benchtop_v0_design.md` — Phase A abstract BOM
- `.roadmap.hexa_antimatter §A.6 + §A.6.1` — overall hardware path
- `firmware/kicad/README.md` — Phase E KiCad source skeleton entry
