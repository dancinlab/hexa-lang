# schematic_v0 — tabletop Penning RF (HEXA-TABLETOP-FW-01)

> Phase C.5 schematic block-spec for **F-AM-2**.  XCZU9EG MPSoC + AD9162
> DAC + AD9208 ADC + AD9528 clock + RS-485 CERN AD handshake + cryo
> safety chain.  Companion to `board_v0_tabletop_penning.md`.

**Status**: paper schematic v0 (2026-05-08) · **Sim**: penning_rf.hexa (11/11 PASS) · **HDL**: penning_rf.v + penning_rf.xdc · **MCU**: tabletop.rs · **PCB**: TBD

---

## §1 Block diagram

```
   ┌────────────────────────────────────────────────────────────────┐
   │   ATX 24-pin (J1) + 12 V EPS aux (J2)                          │
   └─┬─────┬─────┬─────┬─────┬─────────────────────────────────────┘
     │5V   │12V  │3.3V │1.2V │ 0.85V (FPGA core)
     │     │     │     │     │
   ┌─▼─────▼─────▼─────▼─────▼──────────┐
   │  TI TPS54620 + LTM4644 PMIC stack  │
   └─┬───────────────────────────────┬─┘
     │                               │
     │      ┌────────────────────────▼─────────────────┐
     │      │  XCZU9EG-FFVC900-1                       │
     │      │  ┌────────────┐    ┌──────────────────┐  │
     │      │  │ PS (4×A53) │◄──►│ PL (UltraScale+) │  │
     │      │  └─────┬──────┘    └──────┬───────────┘  │
     │      │        │ (PS-PL bridge)   │              │
     │      └────────┼──────────────────┼──────────────┘
     │               │                  │
     │               │           ┌──────▼─────────┐
     │               │           │  AD9162 DAC    │ ─►  RF DRIVE OUT (731.4 MHz)
     │               │           │  16 LVDS pairs │     SMA (J5)
     │               │           └────────────────┘
     │               │           ┌────────────────┐
     │               │           │  AD9208 ADC    │ ◄─  PICKUP IN (image current)
     │               │           │  14 LVDS pairs │     SMA (J6)
     │               │           └────────────────┘
     │               │
     │               │           ┌────────────────┐
     │               └──────────►│  AD9528 clock  │ ◄─  100 MHz Wenzel OCXO IN
     │                           │  generator     │     BNC (J3)
     │                           └────────────────┘
     │
     │      ┌──────────────────────────────────────────┐
     ├─────►│  ADM4168E RS-485 transceiver (CERN AD)   │ ◄─►  J7 (DB-9 to AD timing trunk)
     │      └──────────────────────────────────────────┘
     │
     │      ┌──────────────────────────────────────────┐
     │      │  LHe level sensor + magnet-quench        │
     │      │  detector (interlock chain, opto-iso)    │
     └─────►│  6N137 ×2 → FPGA EXTI (LVCMOS33)         │ ◄─  J8 (Phoenix 4-pin)
            └──────────────────────────────────────────┘

   FPGA → trap HV bias DAC (LTC2641 ×8 channels): SPI bus over isolation
   barrier (ADuM4128) → external HV switch crate.
```

## §2 Power tree

| Rail | Source | Current | Decoupling | Notes |
|:-----|:-------|--------:|:-----------|:------|
| 12 V | J2 EPS | 12 A | 6× 470 µF AlPo | FPGA VCCINT path |
| 5 V | ATX | 8 A | 4× 220 µF | PMIC input |
| 3.3 V | TPS54620 | 4 A | 8× 22 µF X7R | I/O bank VCC |
| 1.8 V | LTM4644-A | 3 A | 6× 22 µF | DAC/ADC VDDA |
| 1.2 V | LTM4644-B | 6 A | 12× 22 µF | FPGA VCCAUX + VCCBRAM |
| 0.85 V | LTM4644-C | 12 A | 24× 22 µF + 16× 100 µF AlPo | FPGA VCCINT (core) |

## §3 Net list (highlights)

| Net | Source | Destination | Length | Impedance | Layer |
|:----|:-------|:------------|------:|:----------|:------|
| DAC_DATA[15:0] | XCZU9EG bank 224 | AD9162 LVDS in | < 70 mm | 100 Ω diff | inner stripline (length-matched ±0.5 mm across 16 pairs) |
| DAC_CLK | XCZU9EG | AD9162 CLK in | < 70 mm | 100 Ω diff | inner |
| ADC_DATA[13:0] | AD9208 LVDS out | XCZU9EG bank 225 | < 70 mm | 100 Ω diff | inner (length-matched) |
| RF_DRIVE_OUT | AD9162 OUT_P/N | balun → SMA J5 | < 30 mm | 50 Ω SE post-balun | top, gold-flash |
| PICKUP_IN | SMA J6 → balun → AD9208 | < 30 mm | 50 Ω SE | top |
| 100 MHz REF | BNC J3 → AD9528 | < 50 mm | 50 Ω SE | top |
| AD_HANDSHAKE_TX | XCZU9EG → ADM4168E | < 100 mm | 100 Ω diff | inner |
| AD_HANDSHAKE_RX | ADM4168E → XCZU9EG | < 100 mm | 100 Ω diff | inner |
| LHE_LEVEL_SENSE | J8.1 → 6N137 → XCZU9EG bank 227 | — | LVCMOS33 | top + opto-isolation barrier |
| MAGNET_QUENCH | J8.2 → 6N137 → XCZU9EG | — | LVCMOS33 | top |

## §4 KiCad library map

| Component | Library | Symbol | Footprint |
|:----------|:--------|:-------|:----------|
| XCZU9EG | FPGA_Xilinx_Zynq | XCZU9EG-FFVC900 | Package_BGA:BGA-900_31x31mm_P1.0mm |
| AD9162 | Analog_DAC | AD9162BBPF | Package_BGA:BGA-152 |
| AD9208 | Analog_ADC | AD9208BBPZ | Package_BGA:BGA-196 |
| AD9528 | Analog_Clock | AD9528BCPZ | Package_DFN_QFN:LFCSP-72_10x10mm_P0.5mm |
| LTM4644 | Power_Management | LTM4644EY | Package_BGA:BGA-77_15x9mm |
| ADM4168E | Interface_RS485 | ADM4168E | Package_SO:SOIC-8 |
| 6N137 | Interface_Optoisolator | 6N137SDM | Package_DIP:DIP-8 |

## §5 PCB stackup + layout

- **14 layers** (HDI required for BGA breakout):
  - top, GND, sig1, GND, sig2, PWR1, GND, sig3, GND, PWR2, sig4, GND, sig5, bottom
  - Microvias for XCZU9EG breakout (≥ 0.1 mm)
- **Outline**: 220 × 200 mm (full Eurocard)
- **Min trace/space**: 0.075/0.075 mm (3 mil) under BGA
- **Diff pair impedance**: 100 Ω (DAC/ADC LVDS), length-matched across all 16 pairs to ±0.5 mm
- **Power planes**: separate 0.85 V plane for FPGA core; isolated analog 1.8 V plane under DAC/ADC

## §6 EMI / shielding / cryo isolation

- **DAC/ADC zone**: top-side TI shield can (40 × 50 mm) with copper paste seal
- **Cryo wires** (LHe sense, magnet quench): opto-isolated through 6N137 with separate primary/secondary GND
- **HV bias path**: ADuM4128 SPI isolation (5 kV barrier)
- **RS-485 (CERN AD)**: TVS clamp ±15 V + ground-loop choke
- **PCIe / USB out** (host link): EMI gasket on chassis exit

## §7 Bring-up checklist

1. Bare-board: continuity + insulation resistance.
2. Power sequence: 12 V → 5 V → 3.3 V → 1.8 V → 1.2 V → 0.85 V (must satisfy XCZU9EG PG sequencing).
3. PMIC fault-detection LEDs.
4. XCZU9EG PROG_B / DONE / INIT_B handshake on JTAG.
5. Vivado bitstream upload (penning_rf.bit).
6. AD9528 PLL lock detect — measure 156.25 MHz at JESD204C ref out.
7. AD9162 + AD9208 link bring-up over JESD204C — link train + scrambling.
8. RS-485 loopback at 115 200 baud (CERN AD trunk).
9. Cryo sense path: short J8.1 → confirm FPGA EXTI fires within 10 ms.
10. RF drive output: program 731.4 MHz tone → spectrum analyzer + power meter.

## §8 Acceptance gates

- All 11 sim invariants reproducible
- DAC SFDR ≥ 60 dBc at 731 MHz drive
- ADC SFDR ≥ 65 dBc at 240 MHz pickup
- AD handshake round-trip ≤ 100 ms
- Magnet-quench → state IDLE in ≤ 10 ms (oscilloscope-measured)

## §9 Forward path

| Step | Artefact | Gating |
|:-----|:---------|:-------|
| 1 | KiCad symbol/footprint for XCZU9EG | requires Xilinx PinPlanner export |
| 2 | KiCad schematic (.kicad_sch) | from §1 + §3 |
| 3 | KiCad PCB layout (HDI) | requires manufacturer prequal |
| 4 | Gerber + drill | from layout |
| 5 | Fab + assembly | post-funding (~$15-20K board, JLCPCB HDI capable) |
| 6 | Vivado synth/place/route | requires `penning_rf.xdc` (already in repo) |
| 7 | Bitstream + JTAG flash | post-board |
