# board_v0 — PET cyclotron controller (HEXA-PET-FW-01)

> Phase C.5 board-spec doc for **F-AM-1**.  Bridges Phase A BOM
> (`pet_cyclotron/doc/benchtop_v0_design.md`) and Phase D HDL/MCU
> skeletons (`firmware/{hdl,mcu}/`).  Paper specification only;
> no PCB exists.

**Status**: paper board v0 (2026-05-08) · **Sim-firmware**: `firmware/sim/cyclotron_trigger.hexa` (13/13 PASS) · **PCB**: TBD (Phase D)

---

## §1 Target chip

| Role | Chip | Package | Datasheet | Lead time |
|:-----|:-----|:--------|:----------|:----------|
| Main MCU | STM32H743VIT6 (Cortex-M7 @ 480 MHz) | LQFP-100 | ST RM0433 | stock |
| 16-bit DAC | LTC2641-16 | MS-10 | LT3989 | 4 wk |
| 16-bit ADC | LTC2378-16 | MSOP-16 | LT4378 | 4 wk |
| Power management | TPS65987DDH | VQFN-32 | TI SLVSDP9 | 6 wk |
| Isolated USB | ADuM4160 | SOIC-16 | ADI ADuM | stock |
| Crystal | NX3225GB-16M (16.0 MHz, ±10 ppm) | SMD-3225 | NDK | stock |

## §2 Pinout — STM32H743 (LQFP-100)

| Pin | Net | Function | Direction | Voltage | Connector |
|:---:|:----|:---------|:---------:|:--------|:----------|
| 1   | VBAT  | Backup battery | IN | 3.0 V | (none) |
| 2   | PC13  | INTERLOCK_FAULT (cyclotron→MCU) | IN  (EXTI13, NVIC pri 0) | 3.3 V | J2.1 |
| 3   | PC14  | OSC32_IN (32.768 kHz) | IN | — | XO2 |
| 4   | PC15  | OSC32_OUT | OUT | — | XO2 |
| 5   | PH0   | OSC_IN (16 MHz HSE) | IN | — | XO1 |
| 6   | PH1   | OSC_OUT | OUT | — | XO1 |
| 7   | NRST  | NRST | IN | — | SW1 / SWD |
| 14  | PA0   | RF_GATE_OUT (TTL → cyclotron RF) | OUT | 3.3 V | J3.1 (SMA) |
| 15  | PA1   | TARGET_SHUTTER (servo PWM) | OUT (TIM2_CH2) | 3.3 V | J3.2 |
| 16  | PA2   | NaI_GAMMA_PULSE (event in) | IN (EXTI2) | 3.3 V | J4.1 |
| 17  | PA3   | DOOR_INTERLOCK | IN (EXTI3) | 3.3 V | J2.2 |
| 23  | PA4   | DAC_CS_N (LTC2641) | OUT (SPI1_NSS) | 3.3 V | J5.1 |
| 24  | PA5   | DAC_SCK | OUT (SPI1_SCK) | 3.3 V | J5.2 |
| 25  | PA6   | ADC_MISO (LTC2378) | IN  (SPI1_MISO) | 3.3 V | J6.2 |
| 26  | PA7   | DAC_MOSI | OUT (SPI1_MOSI) | 3.3 V | J5.3 |
| 30  | PB0   | LED_STATUS_R | OUT | 3.3 V | LED1 |
| 31  | PB1   | LED_STATUS_G | OUT | 3.3 V | LED2 |
| 35  | PB10  | UART_TX (host telemetry) | OUT (USART3_TX) | 3.3 V | J7.2 |
| 36  | PB11  | UART_RX | IN  (USART3_RX) | 3.3 V | J7.3 |
| 51  | PA8   | ADC_CS_N (LTC2378) | OUT | 3.3 V | J6.1 |
| 52  | PA9   | USB_VBUS | IN | 5 V | J8 (USB-CDC) |
| 53  | PA10  | USB_ID | IN | 3.3 V | J8 |
| 54  | PA11  | USB_DM | I/O | 3.3 V | J8.D- |
| 55  | PA12  | USB_DP | I/O | 3.3 V | J8.D+ |
| 72  | PE2   | SD_DETECT | IN | 3.3 V | J9 (SD card) |
| 73  | PE3   | SD_CLK | OUT (SDIO) | 3.3 V | J9 |
| 74  | PE4   | SD_CMD | I/O | 3.3 V | J9 |
| 75–78 | PE5–PE8 | SD_D[3:0] | I/O | 3.3 V | J9 |
| 95  | BOOT0 | BOOT0 | IN | — | SW2 |

(53 of 100 pins specified; remaining are GND, VDD, NC, debug, or unused.)

## §3 Connectors

| ID | Type | Pins | Use |
|:--:|:----|:-----|:----|
| J1 | DC barrel 5.5×2.1 mm | 2 | 12 V supply |
| J2 | Phoenix 2-pin TB | 2 | Safety interlock (door + cyclotron fault) |
| J3 | SMA × 2 | 2 | RF_GATE_OUT (50 Ω) + TARGET_SHUTTER |
| J4 | LEMO 00B | 1 | NaI γ-pulse input |
| J5 | 2.54 mm 4-pin header | 4 | DAC SPI breakout |
| J6 | 2.54 mm 4-pin header | 4 | ADC SPI breakout |
| J7 | 2.54 mm 4-pin header (UART) | 4 | host telemetry (USB-CDC primary) |
| J8 | USB-C | 24 | host link / firmware update |
| J9 | microSD socket (push-push) | 11 | data log |
| J10 | 10-pin Cortex SWD | 10 | debug + flash (ARM-Cortex Debug) |

## §4 BOM — catalog SKUs

| # | Item | Vendor | SKU | Qty | $/unit | Lead |
|:-:|:-----|:-------|:----|:---:|-------:|:----:|
| 1 | STM32H743VIT6 | ST / Mouser | 511-STM32H743VIT6 | 1 | $19.20 | stock |
| 2 | LTC2641-16 | ADI / Digi-Key | LTC2641ACMS-16#PBF-ND | 1 | $14.30 | 4 wk |
| 3 | LTC2378-16 | ADI / Digi-Key | LTC2378IMS-16#PBF-ND | 1 | $24.10 | 4 wk |
| 4 | TPS65987DDH | TI / Mouser | 595-TPS65987DDHRSHR | 1 | $8.40 | 6 wk |
| 5 | ADuM4160 | ADI / Digi-Key | ADUM4160BRWZ-RL-ND | 1 | $11.10 | stock |
| 6 | NX3225GB-16M | NDK / Digi-Key | 644-1167-1-ND | 1 | $1.20 | stock |
| 7 | NX3225GB-32.768K | NDK / Digi-Key | 644-1041-1-ND | 1 | $1.10 | stock |
| 8 | TXS0108E (level shifter, 8-bit) | TI / Digi-Key | 296-21929-1-ND | 1 | $1.40 | stock |
| 9 | LM2596-3.3 (DC-DC) | TI / Mouser | 595-LM2596S-3.3 | 1 | $2.10 | stock |
| 10 | LM2596-5 (DC-DC) | TI / Mouser | 595-LM2596S-5 | 1 | $2.10 | stock |
| 11 | LD1117V33 (LDO) | ST / Mouser | 511-LD1117V33 | 2 | $0.80 | stock |
| 12 | Tantalum cap 47 µF / 16 V | Kemet / Digi-Key | 399-3578-1-ND | 6 | $0.60 | stock |
| 13 | MLCC 100 nF / 50 V (decoupling) | Murata / Mouser | 81-GRM188R71H104K | 60 | $0.04 | stock |
| 14 | MLCC 10 µF / 25 V (bulk) | Murata / Mouser | 81-GRM21BR61E106K | 12 | $0.20 | stock |
| 15 | LED 0805 red / green / blue | Lite-On / Digi-Key | 160-1830-1-ND ×3 | 6 | $0.10 | stock |
| 16 | Tactile switch SPST 6×6 mm | E-Switch / Digi-Key | EG2552-ND | 2 | $0.40 | stock |
| 17 | microSD socket push-push | Hirose / Digi-Key | H11665CT-ND | 1 | $1.80 | stock |
| 18 | USB-C 24-pin SMT | Amphenol / Digi-Key | 12401872E412A-ND | 1 | $1.50 | stock |
| 19 | LEMO 00B PCB jack | LEMO | EPL.00.250.NTN | 1 | $42.00 | 4 wk |
| 20 | SMA edge-launch (50 Ω) | Amphenol / Mouser | 132134 | 2 | $4.60 | stock |
| 21 | Phoenix MC 1.5/2-G-3.5 | Phoenix / Digi-Key | 277-1664-ND | 1 | $1.10 | stock |
| 22 | DC barrel jack 5.5×2.1 | CUI / Digi-Key | CP-024A-ND | 1 | $0.60 | stock |
| 23 | 4-layer PCB (100 × 80 mm) | JLCPCB | 4-layer ENIG | 5 | $4.80 | 7 d |
| 24 | SMT assembly (one-sided) | JLCPCB SMT | — | 5 | $24.00 | 10 d |
| **Total (5-piece run)** |   |   |   |   | **~$220 / unit** | **6 wk worst-case** |

(Excludes mechanical case + cabling; see §6.)

## §5 Power budget

| Rail | Source | Sinks (mA) | Margin | Total |
|:-----|:-------|:-----------|:------:|:-----:|
| 12 V | DC barrel J1 | (input) | — | 1.5 A max |
| 5 V  | LM2596-5 step-down | LED back-light, USB host (if powered) | 50% | 200 mA |
| 3.3 V (digital) | LM2596-3.3 step-down | STM32 (250 mA), LTC2641 (3 mA), LTC2378 (3 mA), TXS0108E (10 mA), microSD (50 mA peak), LEDs (60 mA) | 30% | 380 mA |
| 3.3 V (analog) | LD1117V33 from 5 V | LTC2378 ref (3 mA), DAC ref (3 mA), shielded analog | 30% | 8 mA |
| -3.3 V (NaI bias) | (off-board PMT HV) | (none on PCB) | — | — |
| **Total 12 V draw** | | | | **~340 mA** ≈ 4 W |

PSU: 12 V / 1.5 A wall adapter (CUI VEH50US12) — 18 W, ample headroom.

## §6 Mechanical / cable

- **PCB**: 100 × 80 mm 4-layer (1.6 mm) — fits Hammond 1455-T1601BK extruded enclosure (160 × 84 × 28 mm).
- **Mounting**: 4× M3 standoffs (5 mm) + brass female-female 11 mm spacers.
- **Cables** (off-board, lab-side):
  - J3 RF_GATE: SMA → SMA (Pasternack PE3SP202-12), 3 m, 50 Ω, low-loss
  - J4 NaI: LEMO 00B → BNC adapter (LEMO FFA.00 + Pomona 5697), 1 m
  - J7 host: USB-C → USB-A (Anker), 1.5 m
  - J2 interlock: 2× shielded 22 AWG twisted (Belden 8451)

## §7 Bring-up checklist (Phase D, board arrival to first sim parity)

| Step | Action | Tool | Pass criterion |
|:----:|:------|:-----|:---------------|
| 1 | Visual inspection (solder joints) | microscope | no shorts/cold joints |
| 2 | Power-on smoke test (12 V, no load) | DMM | input current < 50 mA idle |
| 3 | 5 V / 3.3 V rail measurement | DMM | rails within ±5% |
| 4 | SWD connectivity (ST-LINK V3) | STM32CubeIDE | DAP_OK |
| 5 | Flash blink program | ST-LINK | LED1/LED2 toggle |
| 6 | Crystal check (16 MHz HSE) | scope on PH0 | clean 16 MHz sine ±10 ppm |
| 7 | DAC loopback (DAC_OUT → ADC_IN, on-board solder bridge SB1) | logic analyzer | DAC code 0x8000 reads back 16384 |
| 8 | Interlock GPIO test (force PC13/PA3) | tactile switch | EXTI fires < 10 ms |
| 9 | NaI input test (signal generator → J4) | scope + counter | event count matches gen rate |
| 10 | RF_GATE TTL test | scope on J3.1 | high during BEAM_ON state |
| 11 | microSD write test | hand-coded `fwrite` | 100 MB at ≥ 5 MB/s |
| 12 | USB-CDC enumeration | host `lsusb` | STM32 STMicroelectronics |
| 13 | Full state-machine sim parity | host harness | matches `firmware/sim/cyclotron_trigger.hexa` |

If all 13 pass → board v0 ready for cyclotron-coupling tests (§A.6 step 4).

## §8 Cross-link

- Sim-firmware: `firmware/sim/cyclotron_trigger.hexa`
- Phase A BOM (abstract): `pet_cyclotron/doc/benchtop_v0_design.md`
- Phase D HDL: `firmware/hdl/cyclotron_trigger.v`
- Phase D MCU: `firmware/mcu/pet_cyclotron.rs`
- Falsifier: `.roadmap.hexa_antimatter §A.4 F-AM-1`
- Roadmap step: §A.6 step 4 (Stage-2/3 실제 빌드)
