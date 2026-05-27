# schematic_v0 — atomic clock counter (HEXA-FACTORY-FW-01)

> Phase C.5 schematic block-spec for **F-AM-3**.  CPT bench precision
> ν_c counter — XCKU040 FPGA + STM32H723 companion + TDC7201 1-ps TDC
> + LTC2387 24-bit ADC + ADF4356 LO + Cs 5071A 10 MHz reference.
> Companion to `board_v0_atomic_clock.md`.

**Status**: paper schematic v0 (2026-05-08) · **Sim**: atomic_clock_counter.hexa (11/11 PASS) · **HDL**: atomic_clock.v + atomic_clock.xdc · **MCU**: cpt_bench.rs · **PCB**: TBD

---

## §1 Block diagram

```
                  ┌───────────────────────────────┐
                  │   Cs 5071A → 10 MHz BNC IN    │  J3
                  └────────────┬──────────────────┘
                               │
                  ┌────────────▼─────────┐
                  │  AD9528 clock dist + │
                  │   ADF4356 LO synth   │  → 731.4 MHz LO out (J4)
                  └────────────┬─────────┘
                               │ 250 MHz, 1 GHz internal
                  ┌────────────▼─────────────────┐
                  │  XCKU040-FFVA1156-1          │
                  │  ┌────────────────────────┐  │
                  │  │  TDC7201 driver + DDS  │  │
                  │  │  + JESD204C link to    │  │
                  │  │  LTC2387 ADC           │  │
                  │  └────────────────────────┘  │
                  └────┬──────────┬──────────────┘
                       │SPI/UART  │EXTI
                       │          │
              ┌────────▼──┐    ┌──▼───────────────────┐
              │ STM32H723 │    │ TDC7201              │ ◄─  TDC_START / STOP1 / STOP2 (LEMO 00B ×3)
              │ companion │    │ 1 ps timing chip     │     J5–J7
              │ (PI servo,│    └──────────────────────┘
              │  host UART│
              │ /telemetry)│   ┌──────────────────────┐
              └────┬──────┘    │ LTC2387 24-bit ADC   │ ◄─  Photodiode IN (J8, SMA)
                   │           └──────────────────────┘
                   │
                   │           ┌──────────────────────┐
                   └──────────►│ AD5781 20-bit DAC    │ ◄─  Laser-lock feedback OUT (J9)
                               │ (laser piezo control)│
                               └──────────────────────┘

   Photodiode pulse (1S-2S fluorescence): J10 (LEMO) → discriminator
   AD831 → XCKU040 EXTI for photon counting.
```

## §2 Power tree

| Rail | Source | Current | Decoupling | Notes |
|:-----|:-------|--------:|:-----------|:------|
| 12 V | J1 (DC) | 4 A | 4× 470 µF | FPGA bank pre-regulator |
| 5 V | TPS54620 | 2 A | 4× 22 µF | analog board (low-noise LDO downstream) |
| 3.3 V | LMR33630 | 1.5 A | 6× 22 µF | digital I/O |
| 1.8 V | TPS7A47 (LDO, ultra-low-noise) | 600 mA | 12× 22 µF | analog VDDA for ADC + DAC + TDC |
| 1.0 V | LTM4644 | 5 A | 16× 22 µF + 8× 100 µF AlPo | XCKU040 VCCINT |
| 1.2 V | LTM4644 | 2 A | 6× 22 µF | XCKU040 VCCBRAM |

## §3 Net list

| Net | Source | Destination | Length | Impedance | Layer |
|:----|:-------|:------------|------:|:----------|:------|
| 10 MHz_REF | J3 (BNC) → AD9528 IN | < 50 mm | 50 Ω SE | top, length-matched to ±1 mm with internal copy |
| TDC_START | XCKU040 BA15 → J5 (LEMO 00B) | < 30 mm | 50 Ω SE (LVDS pair to off-board converter) | top |
| TDC_STOP1/2 | J6/J7 → XCKU040 BA16/17 | < 30 mm | 50 Ω SE | top |
| ADC_SDO | LTC2387 OUT → XCKU040 BB18 | < 50 mm | 100 Ω diff (LVDS) | inner stripline |
| ADC_CNV | XCKU040 BB20 → LTC2387 | < 50 mm | 50 Ω SE | inner |
| DAC_SDI/SCK/CS | STM32 → AD5781 SPI | < 80 mm | 50 Ω SE | inner |
| LASER_PIEZO_OUT | AD5781 OUT → J9 (BNC) | < 40 mm | 50 Ω SE post-buffer | top |
| PHOTODIODE_PULSE | J10 → AD831 → XCKU040 BB33 | < 40 mm | 50 Ω SE | top, EMI-shielded |
| ADF4356_DATA | XCKU040 → ADF4356 SPI | < 80 mm | 50 Ω SE | inner |
| LO_OUT | ADF4356 → balun → J4 | < 30 mm | 50 Ω SE | top, gold-flash |

## §4 KiCad library map

| Component | Library | Symbol | Footprint |
|:----------|:--------|:-------|:----------|
| XCKU040 | FPGA_Xilinx_Kintex_UltraScale_Plus | XCKU040-FFVA1156 | Package_BGA:BGA-1156_35x35mm_P1.0mm |
| STM32H723VGT6 | MCU_ST_STM32H7 | STM32H723VGT | Package_QFP:LQFP-100 |
| TDC7201 | Analog_TDC | TDC7201 | Package_DFN_QFN:VQFN-32_4x4mm_P0.4mm |
| LTC2387-24 | Analog_ADC | LTC2387-IDE | Package_DFN_QFN:DFN-16_3x4mm_P0.5mm |
| AD5781 | Analog_DAC | AD5781BRUZ | Package_SO:TSSOP-20 |
| ADF4356 | Analog_PLL | ADF4356BCPZ | Package_DFN_QFN:LFCSP-32_5x5mm_P0.5mm |
| AD9528 | Analog_Clock | AD9528BCPZ | Package_DFN_QFN:LFCSP-72 |
| AD831 | Analog_Mixer | AD831APZ | Package_DIP:DIP-20 |
| TPS7A47 | Power_Management | TPS7A4700 | Package_DFN_QFN:VQFN-20_4x4mm |

## §5 PCB stackup + layout

- **10 layers**:
  - top, GND, sig1, GND, sig2 (analog), PWR (split 1.8 V analog vs digital), GND, sig3, GND, bottom
  - Hard split between analog (TDC, ADC, DAC, photodiode) and digital (FPGA digital I/O) sections
- **Outline**: 200 × 150 mm
- **Min trace/space**: 0.1/0.1 mm (4 mil) under FPGA breakout
- **Reference plane**: solid GND under all timing-critical traces (TDC, 10 MHz, ADC clock)

## §6 EMI / low-noise practices

- **TDC zone**: shielded top-side can with separate ground island; vias around perimeter every 1 mm
- **10 MHz reference**: gold-flash SMA + 50 Ω SE trace + impedance-controlled connector; stripline to DDS
- **ADC reference**: separate AD7961 onboard 4.096 V reference, ferrite bead from 1.8 V analog rail
- **Laser piezo output**: separate ground return path from photodiode input (avoid PSU ground loops)
- **Cs ref input** (10 MHz): impedance-matched 50 Ω with passive 1:1 isolation transformer for ground-loop break

## §7 Bring-up checklist

1. Bare board continuity, isolation R > 100 MΩ.
2. Power sequence: 12 V → 5 V → 3.3 V → 1.8 V → 1.2 V → 1.0 V (FPGA PG order).
3. JTAG/SWD on XCKU040 + STM32H723.
4. AD9528 + ADF4356 PLL lock detect (LED + scope at LO_OUT for 731.4 MHz).
5. TDC7201 SPI → request linearity test.
6. LTC2387 ADC: known DC input → expect ±2 LSB precision at 24-bit.
7. AD5781 DAC: full-scale ramp → expect ≤ 100 µV step at 20 bits.
8. Photodiode → AD831 discriminator → confirm pulse height and EXTI rate match.
9. Cs 5071A 10 MHz input → DDS 1 GHz internal lock → verified by spectrum analyzer at LO_OUT.
10. Run `atomic_clock_counter.hexa` reference → compare TDC counts.

## §8 Acceptance gates

- All 11 sim invariants reproducible
- TDC resolution ≤ 1 ps at 1 σ (cross-correlation method)
- ADC ENOB ≥ 22 (sub-shot noise at 50 Hz BW)
- DAC INL ≤ 1 LSB at 20 bits
- 10 MHz Cs ref → DDS phase noise ≤ –120 dBc/Hz at 1 kHz offset

## §9 Forward path

| Step | Artefact | Gating |
|:-----|:---------|:-------|
| 1 | KiCad library entries (esp. XCKU040 BGA-1156) | requires Xilinx PinPlanner export |
| 2 | Schematic (.kicad_sch) | from §1 + §3 |
| 3 | PCB HDI layout | requires impedance-controlled mfr |
| 4 | Vivado synth + bitstream | requires `atomic_clock.xdc` (in repo) |
| 5 | Fab + assembly | post-funding |
