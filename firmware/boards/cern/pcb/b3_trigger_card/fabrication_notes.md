# B3 trigger card — fabrication notes

> §A.6.1 step E2.1 — fab + assembly + test plan, transcribable to a
> KiCad project once §A.6 step 2 funds an EE engineer.

## §1 PCB stack-up

4-layer FR-4, 1.6 mm finished thickness, 1 oz copper external,
0.5 oz internal. Hard gold finish on USB-C contacts; ENIG everywhere
else for SAC305 reflow.

## §2 Manufacturing class

- **IPC Class 2** (industrial general-purpose). Class 3 (high-rel)
  not required because:
  - Operating temp range 0..50 °C (lab environment)
  - No mission-critical life-safety requirement at this layer
  - 1× spare card kept on shelf (4-stage cascade redundancy)

## §3 Fab specs (for PCB house quote)

| parameter             | spec                              |
|:----------------------|:----------------------------------|
| Board outline         | 100 × 80 mm, rectangular, 4× M3 mounting holes |
| Layer count           | 4                                 |
| Material              | FR-4 standard Tg 150 °C            |
| Min trace/space       | 0.10 / 0.10 mm (4 mil)             |
| Min via               | 0.20 mm drill / 0.45 mm pad        |
| Min annular ring       | 0.10 mm                           |
| Surface finish         | ENIG + selective hard gold (USB-C) |
| Solder mask            | Green LPI                         |
| Silkscreen             | white, both sides                 |
| Impedance control      | 50 Ω SE / 100 Ω LVDS, ±10%         |
| Test                   | 100% E-test                       |

Estimated quote (5 prototype boards, JLCPCB / PCBWay):
- bare PCB:  ~$80 / 5 boards
- assembly: ~$420 / 5 boards (3.5 hours SMT setup amortized)
- BOM (per `BOM.csv`):  ~$310 / board
- shipping:  ~$60
- **total prototype: ~$2.4k for 5 boards**

## §4 Assembly notes

- All 0402+ SMD parts: SMT line, IPC-7351B nominal pads.
- U1 (LQFP-144): hand-solder OR SMT line — pin pitch 0.5 mm.
- U2 (FBGA-484): MUST SMT line with x-ray inspection. Hand-solder
  not feasible. Recommend reputable EMS (e.g., MacroFab, Saline
  Lectronics) over hobbyist board houses.
- LTC6655 (U5): MSOP-8 — manual placement OK if SMT line not
  available, but heat-soak window tight.
- OCXO (U7): metal-can, cannot wave-solder. Hand-solder after
  reflow of all SMD parts.

## §5 Bring-up procedure (post-assembly)

| step | action                                                | pass criterion                   |
|:----:|:------------------------------------------------------|:----------------------------------|
| 1    | Visual inspection (under microscope)                   | no shorts; solder joints clean    |
| 2    | Power-on without load (only U8 buck)                   | +5V0 ramps clean; no smoke         |
| 3    | Verify LDO outputs                                     | +3V3 / +1V8 / +1V0 / +2V5_REF in spec ±2% |
| 4    | Sequence verification on scope                          | 1V0 first, 1V8 second, 3V3 last (per power_tree.md §3) |
| 5    | Connect SWD probe (J4) — read STM32 device ID           | DBGMCU_IDC = 0x10006450           |
| 6    | Flash hexa-cern-laser-mcu firmware                     | firmware/mcu/target/.../hexa-cern-laser-mcu loads |
| 7    | LED1 toggles at ~1 Hz                                  | RTIC idle task running            |
| 8    | Probe interlock GPIOs PD0..PD3 with logic analyzer      | each rises to +3V3 with R_PULL via J3 |
| 9    | Probe DAC SPI bus on scope                              | SPI1 SCK at 25 MHz, MOSI valid    |
| 10   | Send DAC code 0x8000 → expect 0 V on U3 OUT0            | ±2 LSB tolerance (mid-scale)      |
| 11   | Send DAC code 0xFFFF → +9.997 V                         | ±0.5%                              |
| 12   | Trigger SMA outputs with `force_tick` register write    | TICK + TRIGGER + GATE pulse on scope, 1 µs delay between TICK and TRIGGER, 200 ns gate width |

## §6 Test fixtures

- Logic analyzer (Saleae Pro 16+ or Sigrok-compatible)
- Oscilloscope ≥ 500 MHz BW (for SMA trigger validation)
- BNC scope probes ×3 for trigger SMAs
- USB-C cable (for boot/log link)
- DC bench supply 12 V / 2 A
- Multimeter (4½ digit minimum for LDO outputs)
- DUT mounting fixture (3D-printed PLA; STL available post-Phase E)

## §7 Failure-mode FMEA (high-priority entries)

| failure                              | severity | mitigation                                |
|:-------------------------------------|:--------:|:------------------------------------------|
| 12V input reverse polarity            | HIGH     | TVS1 (SMBJ12CA) clamps; F1 polyfuse blows |
| Static discharge on interlock GPIO    | MED      | TVS array on J3 (post-Phase E if needed)   |
| LDO oscillation on output             | LOW      | C_DEC2 100 nF placement enforced; ESR pad |
| FPGA over-temperature                 | MED      | passive 1 K/W heatsink on U2; firmware reads internal temp via XADC and trips interlock at 85 °C |
| OCXO drift outside ±1 ppm             | LOW      | annual recalibration (lab procedure)      |

## §8 Compliance pre-check

- **FCC Part 15 Class A**: pre-compliance scan deferred to ngspice in
  §A.6.1 step E5.3. Buck spread-spectrum + bulk decoupling expected
  to give ≥ 6 dB margin on all bands.
- **CE EMC (EN 55032 Class A)**: same pre-compliance pathway.
- **RoHS**: all parts in `BOM.csv` are RoHS-compliant (no leaded SMT).
- **REACH**: no SVHC (Substances of Very High Concern) above 0.1%
  threshold per current SVHC list (2025-Q4).

## §9 Cross-references

- `pcb/b3_trigger_card/schematic_spec.md` — full netlist
- `pcb/b3_trigger_card/BOM.csv` — Digi-Key sortable BOM
- `pcb/b3_trigger_card/io_map.md` — STM32 pinout
- `pcb/b3_trigger_card/power_tree.md` — supply analysis
