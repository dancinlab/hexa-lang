# schematic_v0 — PET cyclotron controller (HEXA-PET-FW-01)

> Phase C.5 schematic block-spec for **F-AM-1**.  Companion to
> `board_v0_pet_cyclotron.md` (BOM + pinout); this file specifies the
> KiCad-ready block diagram, net topology, power tree, and PCB layout
> hints.  No `.kicad_sch` file yet — this MD is the canonical source
> from which Phase D will generate one.

**Status**: paper schematic v0 (2026-05-08) · **Sim**: cyclotron_trigger.hexa (13/13 PASS) · **MCU**: pet_cyclotron.rs (Phase D skeleton) · **HDL**: cyclotron_trigger.v (placeholder, no FPGA on this board) · **PCB**: TBD

---

## §1 Block diagram (ASCII)

```
                      ┌─────────────────────────┐
                      │   12 V DC barrel (J1)   │
                      └────────────┬────────────┘
                                   │
                  ┌────────────────┴─────────────────┐
                  │  TPS65987DDH PMIC (3.3V/1.2V/5V) │
                  └─┬─────┬─────┬─────────┬──────────┘
                    │3.3V │1.2V │5V       │
                    │     │     │         │
            ┌───────┼─────┼─────┼─────────┼──────────┐
            │       │     │     │         │          │
   ┌────────▼────┐ ┌▼─────▼─────▼─────────▼─┐   ┌────▼─────┐
   │ STM32H743   │ │ LTC2641 DAC + LTC2378  │   │ ADuM4160 │
   │ Cortex-M7   │◄┤ ADC (SPI1, shared bus) │   │  USB iso │
   │ @ 480 MHz   │ └────────────────────────┘   └────┬─────┘
   └─┬───┬───┬───┘                                   │
     │   │   │                                       │ USB-C
     │   │   │                                  ┌────▼─────┐
     │   │   │                                  │  USB-C   │
     │   │   │                                  │  J8      │
     │   │   │                                  └──────────┘
     │   │   └─── PA0 (TTL) ──────────────► RF GATE OUT (J3.1, SMA)
     │   │   └─── PA1 (PWM) ──────────────► TARGET SHUTTER (J3.2, SMA)
     │   ├─── PA2 (EXTI) ◄────────────────── NaI γ-PULSE (J4, LEMO 00B)
     │   ├─── PC13 (EXTI) ◄───────────────── CYCLOTRON_FAULT (J2.1)
     │   └─── PA3  (EXTI) ◄───────────────── DOOR_INTERLOCK (J2.2)
     │
     ├─── PB10/11 (USART3) ────────────────► UART_HOST (J7)
     └─── PE2..PE8 (SDIO)  ────────────────► microSD (J9)
```

Cortex SWD debug port (J10) connects to PA13/PA14 via the Cortex-Debug 10-pin header (default).

## §2 Power tree

| Rail | Source | Current budget | Decoupling | Notes |
|:-----|:-------|---------------:|:-----------|:------|
| 12 V | J1 (DC barrel) | 1.0 A | 470 µF AlPo + 10 µF X7R | Reverse-protect diode SS210 |
| 5 V | TPS65987DDH (LDO 1) | 200 mA | 22 µF X7R | feeds USB-C VBUS only |
| 3.3 V | TPS65987DDH (buck 1) | 600 mA | 4× 10 µF X7R | MCU VDD + I/O |
| 1.2 V | TPS65987DDH (buck 2) | 350 mA | 4× 22 µF X7R | MCU VCORE |
| 1.8 V | TPS65987DDH (LDO 2) | 50 mA | 22 µF X7R | analog VREF for ADC |

## §3 Net list (signal-level)

| Net | Source pin | Destination | Length budget | Impedance | Layer |
|:----|:-----------|:------------|--------------:|:----------|:------|
| RF_GATE_OUT | STM32 PA0 | J3.1 (SMA) | < 50 mm | 50 Ω SE | top, ground-flooded |
| TARGET_SHUTTER | STM32 PA1 | J3.2 (SMA) | < 50 mm | 50 Ω SE | top |
| NaI_GAMMA_PULSE | J4 (LEMO 00B) | STM32 PA2 | < 30 mm | 50 Ω SE | top, EMI-guarded |
| INTERLOCK_FAULT | J2.1 | STM32 PC13 | < 30 mm | — | top |
| DOOR_INTERLOCK | J2.2 | STM32 PA3 | < 30 mm | — | top |
| DAC_SCK | STM32 PA5 | LTC2641 SCK + LTC2378 SCK | < 100 mm | 50 Ω SE | inner stripline |
| DAC_MOSI | STM32 PA7 | LTC2641 SDI | < 100 mm | 50 Ω SE | inner |
| ADC_MISO | LTC2378 SDO | STM32 PA6 | < 100 mm | 50 Ω SE | inner |
| DAC_CS_N | STM32 PA4 | LTC2641 CS_N | < 100 mm | — | inner |
| ADC_CS_N | STM32 PA8 | LTC2378 CS_N | < 100 mm | — | inner |
| USB_DM/DP | STM32 PA11/PA12 | ADuM4160 → USB-C | < 80 mm | 90 Ω diff pair | top |
| UART_TX/RX | STM32 PB10/PB11 | J7 | < 200 mm | — | top |
| SD_CLK/CMD/D[3:0] | STM32 PE3..PE8 | microSD socket | < 100 mm | 50 Ω SE | inner stripline |

## §4 KiCad library map

| Component | Library | Symbol | Footprint |
|:----------|:--------|:-------|:----------|
| STM32H743VIT6 | MCU_ST_STM32H7 | STM32H743VIT | Package_QFP:LQFP-100_14x14mm_P0.5mm |
| LTC2641-16 | Analog_DAC | LTC2641-AMS | Package_SO:MSOP-10_3x3mm_P0.5mm |
| LTC2378-16 | Analog_ADC | LTC2378-IMS | Package_SO:MSOP-16_3x4.9mm_P0.5mm |
| TPS65987DDH | Power_Management | TPS65987DDH | Package_DFN_QFN:VQFN-32_4x4mm_P0.4mm |
| ADuM4160 | Interface_USB | ADuM4160ARWZ | Package_SO:SOIC-16_7.5x10.3mm_P1.27mm |
| Crystal NX3225GB-16M | Device | Crystal_GND24 | Crystal:Crystal_SMD_3225-4Pin_3.2x2.5mm |

## §5 PCB stackup + layout hints

- **6 layers**: top + GND1 + sig1 + power + GND2 + bottom
  - top: components + RF/IO/USB diff pairs
  - GND1: solid copper pour, **no splits** under USB or NaI input
  - sig1: SPI + UART + SDIO (50 Ω stripline)
  - power: 3.3 V + 1.2 V + 1.8 V poured polygons
  - GND2: solid copper pour
  - bottom: low-speed signals + test points
- **Outline**: 100 × 80 mm (Eurocard half-rack)
- **Min trace/space**: 0.15/0.15 mm (6 mil)
- **Differential impedance**: 90 Ω for USB; controlled-impedance manufacturer required
- **Crystal placement**: NX3225GB-16M ≤ 5 mm from STM32 PH0/PH1 with guard ring
- **Decoupling**: 100 nF + 1 nF X7R on every VDD pin (12 caps total for STM32)
- **GND vias**: stitching every 5 mm under high-speed traces

## §6 EMI / shielding

- USB-C cage shield → chassis ground via 4 spring fingers
- NaI input: SMA → 50 Ω trace → 100 Ω termination at MCU; ferrite bead on power feed to shape rise
- RF_GATE_OUT: 50 Ω termination at cyclotron-side (off-board); guard trace 0.5 mm to GND on each side
- Magnet quench / interlock lines: opto-isolated via 6N137 (off-board side); add TVS clamp 5 V on board side

## §7 Bring-up checklist

1. Power-on test (12 V applied, no load) — measure 3.3 V, 1.2 V, 5 V rails ±5 %.
2. JTAG/SWD detection via ST-LINK V3.
3. Crystal oscillation (PH0/PH1 — scope at C9 with 1× probe + 10 pF tip).
4. Flash test firmware (`cargo embed --bin pet_cyclotron`).
5. UART loop-back at 115200 baud.
6. SPI shake-out: drive DAC code 0x8000 → measure ~ V_REF/2 at LTC2641 OUT.
7. NaI input — feed pulse generator 100 ns 1 V pulses → confirm EXTI rate matches.
8. Safety interlock latency — toggle DOOR pin → measure RF_GATE_OUT drop time on scope (must < 10 ms).
9. End-to-end: run `cyclotron_trigger.hexa` reference scenario, compare GPIO trace to sim output.

## §8 Acceptance gates (from sim)

- All 13 sim invariants reproducible on real board
- σ·τ = 48 normalized DAC scaling preserved (verifiable via ADC readback of DAC OUT)
- Safety interlock < 10 ms (oscilloscope-measured)
- NaI count rate within 5 % of nominal at known γ source

## §9 Forward path (Phase D)

| Step | Artefact | Gating |
|:-----|:---------|:-------|
| 1 | KiCad symbols + footprints | requires this doc + libraries |
| 2 | KiCad schematic (.kicad_sch) | from §1 + §3 |
| 3 | KiCad PCB layout | from §5 + §6 + footprint placement |
| 4 | Gerber + drill files | from layout |
| 5 | PCB fab + assembly (JLCPCB / OSH Stencils) | post-funding |
| 6 | Bring-up per §7 | board in hand |
