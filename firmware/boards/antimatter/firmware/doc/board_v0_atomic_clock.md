# board_v0 — atomic clock counter (HEXA-FACTORY-FW-01, CPT bench)

> Phase C.5 board-spec doc for **F-AM-3**.  Precision ν_c counter +
> 1S-2S laser lock + Cs reference disciplining.  Sub-ppb timing.

**Status**: paper board v0 (2026-05-08) · **Sim-firmware**: `firmware/sim/atomic_clock_counter.hexa` (11/11 PASS) · **PCB**: TBD (Phase D)

---

## §1 Target chip

| Role | Chip | Package | Datasheet | Lead time |
|:-----|:-----|:--------|:----------|:----------|
| FPGA | Xilinx XCKU040-FFVA1156 (Kintex UltraScale, sweet-spot for TDC) | FCBGA-1156 | UG574 | 12 wk |
| TDC | TI TDC7201 (55 ps RMS, dual-stop) | TQFN-32 | SBAS790 | stock |
| 24-bit ADC | LTC2387-24 (15 MSPS) | LFCSP-32 | LT4480 | 6 wk |
| Cs reference input cond. | OPA827 (low-noise opamp) | SOIC-8 | TI SBOS396 | stock |
| LO synth | ADF4356 (PLL + VCO 6.8 GHz) | LFCSP-32 | ADF4356 | stock |
| Reference oscillator | Cs 5071A (rear panel 10 MHz BNC) | (off-board) | datasheet | 10 wk |
| Optical sensor | Hamamatsu G10899 photodiode (243 nm UV-sensitive) | TO-46 | G10899 | 8 wk |
| MCU companion | STM32H723VGT6 (Cortex-M7 @ 550 MHz, slower variant of H7) | LQFP-100 | RM0468 | stock |

## §2 Pinout — XCKU040 (timing-critical signals)

| Bank | Ball | Net | Function | Spec |
|:----:|:----:|:----|:---------|:-----|
| 64 | AT7 | CS_REF_10MHZ_IN_P (LVDS) | IN | 10 MHz Cs reference |
| 64 | AU7 | CS_REF_10MHZ_IN_N (LVDS) | IN | 10 MHz Cs reference |
| 64 | AV7 | OCXO_DDS_PHASE_OUT | OUT | TDC reference for ν_c counting |
| 65 | AY9 | TDC7201_CSB | OUT (SPI) | TDC chip select |
| 65 | AY10 | TDC7201_SCLK | OUT (SPI) | TDC clock |
| 65 | AY11 | TDC7201_DIN | OUT | TDC config |
| 65 | AY12 | TDC7201_DOUT | IN | TDC result |
| 65 | AY13 | TDC7201_INT | IN (EXTI) | TDC done |
| 66 | BA15 | TDC_START | OUT (LVDS, low-skew) | start pulse |
| 66 | BA16 | TDC_STOP1 | IN  (LVDS) | stop 1 (ν_c phase) |
| 66 | BA17 | TDC_STOP2 | IN  (LVDS) | stop 2 (Cs reference cycle) |
| 67 | BB18 | LTC2387_SDO_P (LVDS) | IN | 24-bit ADC serial data |
| 67 | BB19 | LTC2387_SDO_N | IN | LVDS pair |
| 67 | BB20 | LTC2387_CNV | OUT | start conversion |
| 67 | BB21 | LTC2387_CLKOUT | IN  | data clock 30 MHz |
| 68 | AY24 | ADF4356_CE | OUT | LO synth chip enable |
| 68 | AY25 | ADF4356_DATA | OUT (SPI) | LO config |
| 68 | AY26 | ADF4356_LE | OUT | LO latch |
| 68 | AY27 | ADF4356_MUXOUT | IN  | LO lock detect |
| 69 | BA30 | LASER_LOCK_ERROR_DAC_CS | OUT (SPI) | feedback DAC for cavity lock |
| 69 | BA31 | LASER_LOCK_ERROR_DAC_SCK | OUT | SPI |
| 69 | BA32 | LASER_LOCK_ERROR_DAC_MOSI | OUT | SPI |
| 70 | BB33 | PHOTODIODE_PULSE | IN  (EXTI) | 1S-2S fluorescence event |
| 70 | BB34 | UART_HOST_TX | OUT | telemetry |
| 70 | BB35 | UART_HOST_RX | IN  | command |

## §3 Connectors

| ID | Type | Use |
|:--:|:----|:----|
| J1 | ATX 24-pin | main power |
| J2 | EPS-12V 4-pin | aux for FPGA core (1.0 V) |
| J3 | BNC | 10 MHz Cs reference IN (50 Ω) |
| J4 | SMA | 1 PPS Cs reference IN |
| J5 | SMA × 2 | TDC START + STOP test ports |
| J6 | LEMO 00B | photodiode pulse IN |
| J7 | DB-15 | laser lock error monitor (5 channels) |
| J8 | RJ45 (1 GbE) | host telemetry |
| J9 | USB-C | console |
| J10 | 14-pin Xilinx JTAG | Vivado |
| J11 | 10-pin Cortex SWD | STM32 debug |
| J12 | 4-pin (Cortex SWD breakout for STM32) | secondary debug |

## §4 BOM — catalog SKUs

| # | Item | Vendor | SKU | Qty | $/unit | Lead |
|:-:|:-----|:-------|:----|:---:|-------:|:----:|
| 1 | XCKU040-1FFVA1156I | Xilinx / Avnet | XCKU040-1FFVA1156I | 1 | $920 | 12 wk |
| 2 | TDC7201PWR | TI / Mouser | 595-TDC7201PWR | 1 | $7.20 | stock |
| 3 | LTC2387ILX-24 | ADI / Digi-Key | LTC2387ILX-24 | 1 | $52 | 6 wk |
| 4 | ADF4356BCPZ | ADI / Digi-Key | ADF4356BCPZ | 1 | $19 | stock |
| 5 | OPA827AID | TI / Mouser | 595-OPA827AID | 2 | $5.60 | stock |
| 6 | STM32H723VGT6 | ST / Mouser | 511-STM32H723VGT6 | 1 | $14.40 | stock |
| 7 | G10899-32 photodiode | Hamamatsu direct | G10899-32 | 1 | $185 | 8 wk |
| 8 | KSZ9031RNX (1 GbE PHY) | Microchip | KSZ9031RNX-CT | 1 | $4.80 | stock |
| 9 | TPS6594-Q1 PMIC | TI | 595-TPS6594QFNRDQQ1 | 1 | $26 | 6 wk |
| 10 | LM5170-Q1 buck-boost | TI | 595-LM5170QFTRRQ1 | 1 | $9 | 6 wk |
| 11 | FT4232HQ JTAG bridge | FTDI | 768-1098-ND | 1 | $7 | stock |
| 12 | DDR3 (2 Gb, 800 MT/s) | Micron | MT41K128M16JT-125 | 2 | $4.40 | stock |
| 13 | DC-coupled BNC bulkhead 50 Ω | Pomona | 5697 | 4 | $14.20 | stock |
| 14 | LEMO 00B | LEMO | EPL.00.250.NTN | 1 | $42 | 4 wk |
| 15 | SMA edge | Amphenol | 132134 | 4 | $4.60 | stock |
| 16 | RJ45 magjack | Bel | SI-50140-F | 1 | $4.20 | stock |
| 17 | DB-15 right-angle | TE | 5747842-4 | 1 | $1.60 | stock |
| 18 | 6-layer PCB (180 × 180 mm, controlled-Z) | PCBWay | 6L-controlled | 5 | $190 | 14 d |
| 19 | SMT assembly | PCBWay | — | 5 | $620 | 18 d |
| **Total (5-piece run)** |   |   |   |   | **~$2,400 / unit** | **14 wk worst-case** |

## §5 Power budget

| Rail | Sinks | Total |
|:-----|:------|:-----:|
| 12 V (ATX) | board input | 250 W max |
| 5 V | misc, USB, GbE PHY | 5 W |
| 3.3 V | I/O banks, STM32, GbE | 8 W |
| 1.8 V | DDR3 VDDIO | 3 W |
| 1.5 V | DDR3 VDD | 2 W |
| 1.0 V (VCCINT) | XCKU040 core | 25 W |
| 0.95 V (MGTAVCC) | GT transceivers | 1 W |
| ±5 V (analog) | OPA827, photodiode bias | 1.5 W |
| **Total** |   | **~50 W steady** |

PSU: 250 W ATX (Corsair CV450) — light load.

## §6 Mechanical / cable

- **PCB**: 180 × 180 mm 6-layer controlled-Z (50 Ω LVDS, 100 Ω diff CML).
- **Enclosure**: Hammond 1455-T2201BK 1U rack, 200 × 250 × 50 mm.
- **Cables**:
  - J3 Cs ref: BNC ↔ Cs 5071A rear-panel — 50 Ω, 2 m, ferrite-cored
  - J6 photodiode: LEMO 00B → CPT-bench photodiode head, 1.5 m
  - J7 laser lock: DB-15 → cavity-lock breakout box (Toptica DLC pro)
  - J8 GbE: Cat6A 3 m

## §7 Bring-up checklist

| Step | Action | Pass criterion |
|:----:|:------|:---------------|
| 1 | PCB visual + X-ray BGA + DDR3 | no opens/shorts |
| 2 | Power smoke (rail sequence) | within ±3% |
| 3 | Cs ref 10 MHz buffered out | jitter < 1 ps RMS at 10 MHz |
| 4 | Vivado JTAG chain | XCKU040 + STM32 both ID'd |
| 5 | TDC7201 self-cal | INL/DNL within spec |
| 6 | TDC measure 1 PPS interval | 999,999,999 ± 100 ns vs Cs |
| 7 | LTC2387 read DC reference | 24-bit code matches input |
| 8 | ADF4356 PLL lock at 6.8 GHz | MUXOUT high |
| 9 | Photodiode dark count | < 10 cps (room temp) |
| 10 | Photodiode pulse → EXTI | < 100 ns latency |
| 11 | Laser lock error DAC sweep | smooth output 0–5 V |
| 12 | 1 PPS counting over 1000 s | matches Cs σ_y(1000s) ≤ 1e-15 |
| 13 | Full sim parity | matches `firmware/sim/atomic_clock_counter.hexa` |

## §8 Cross-link

- Sim-firmware: `firmware/sim/atomic_clock_counter.hexa`
- Phase A BOM: `factory/doc/benchtop_v0_design.md` (CPT bench section)
- Phase D HDL: `firmware/hdl/atomic_clock.v`
- Phase D MCU: `firmware/mcu/cpt_bench.rs`
- Falsifier: `.roadmap §A.4 F-AM-3`
