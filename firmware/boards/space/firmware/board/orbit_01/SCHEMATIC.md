<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# HEXA-ORBIT-01 — board-level schematic (F-SPACE-1)

> STM32H743ZI (Nucleo-H743ZI2 derivative) + GPS NMEA + 12-bit ADC sensor
> board + 16-bit DAC telemetry + RS-485 backplane.  Phase E procurement-prep
> reference (commissioning script in `COMMISSIONING.md`).

---

## §1 Block diagram

```
                          ┌──────────────────────────────┐
                          │  STM32H743ZIT6  TQFP-144      │
                          │  ─ SYSCLK 480 MHz             │
                          │  ─ HSE 25 MHz crystal Y1      │
                          │  ─ 2 MB flash · 1 MB SRAM     │
                          └──────────────────────────────┘
       25 MHz  Y1                │
        OSC ───┘                 │ SWD (debug)
                                 │
   ┌─────┐  ┌─────┐  ┌─────┐  ┌──────┐
   │GPS  │  │12-b │  │16-b │  │RS-485│
   │NMEA │  │ADC  │  │DAC  │  │XCVR  │
   │U2   │  │U3   │  │U4   │  │U5    │
   └──┬──┘  └──┬──┘  └──┬──┘  └──┬───┘
      │        │        │        │
   J1 (USB-C power) ──→ U6 LDO 3.3 V (1A) ──→ VDD rail
                    └→ U7 LDO 1.2 V (500 mA) ──→ VDD_CORE
```

## §2 Net list (key nets)

| Net          | From → To                              | Notes |
|:-------------|:---------------------------------------|:------|
| `+5V_USB`    | J1.VBUS → U6.IN, U7.IN, fuse F1 (1A)  | input from USB-C |
| `+3V3`       | U6.OUT → MCU.VDD, U2.VCC, U3.VCC      | digital rail |
| `+3V3_A`     | U6.OUT → ferrite L1 → U3.AVDD          | analog supply (separate ferrite) |
| `+1V2_CORE`  | U7.OUT → MCU.VDD_CORE                 | core supply |
| `OSC_25M`    | Y1 ↔ MCU.PH0/PH1 (HSE_IN/OUT)         | 25 MHz crystal, 2× 18 pF C1/C2 |
| `GPS_TX`     | U2.TX → MCU.PA10 (USART1_RX)          | 9600 baud NMEA |
| `GPS_RX`     | MCU.PA9 (USART1_TX) → U2.RX           | optional ublox commands |
| `GPS_PPS`    | U2.PPS → MCU.PA0 (TIM2_CH1_ETR)       | 1 PPS time-pulse capture |
| `ADC_DATA[11:0]` | U3.D[11:0] → MCU.PA[7:0], PB[3:0] | 12-bit parallel |
| `ADC_RDY`    | U3.RDY → MCU.PB10 (EXTI10)            | rising-edge IRQ |
| `DAC_DATA[15:0]` | MCU.PE[7:0], PD[7:0] → U4.D[15:0] | 16-bit parallel |
| `DAC_STROBE` | MCU.PB11 → U4.LDAC                    | latch on rising edge |
| `RS485_DE`   | MCU.PD3 → U5.DE/RE                    | driver enable |
| `RS485_TX`   | MCU.PD5 (USART2_TX) → U5.D            | transmit |
| `RS485_RX`   | U5.R → MCU.PD6 (USART2_RX)            | receive |
| `SWD_CLK`    | J2.4 → MCU.PA14 (SWCLK)               | ST-Link debug |
| `SWD_IO`     | J2.2 ↔ MCU.PA13 (SWDIO)               | bidirectional |
| `nRST`       | J2.10 → MCU.NRST                      | reset (also SW1) |

## §3 Power tree

```
USB-C VBUS (5 V, 3 A spec)
  ├─ F1 polyfuse 1 A (de-rated)
  ├─ TVS D1 (SMAJ5.0A) ESD/surge
  ├─→ U6 (TLV75733PDBVR  3.3 V LDO, 1 A, NR pin to GND via 10 nF)
  │     ├─→ +3V3 (digital): MCU.VDD ×8, U2/U5 VCC, decap 100 nF/pin + bulk 10 µF
  │     └─→ ferrite L1 (BLM18PG471SN1D) → +3V3_A: U3.AVDD, decap 100 nF + 10 µF
  └─→ U7 (TPS62740DSST 1.2 V buck, 300 mA) → +1V2_CORE: MCU.VDD_CORE ×4, decap 100 nF + 10 µF

VBAT: CR2032 J3 → MCU.VBAT (RTC backup, 3 µA quiescent)
```

## §4 Decoupling strategy

- Per-pin 100 nF X7R 0402 within 5 mm of every VDD pin (8× MCU + 2× per peripheral).
- Bulk 10 µF X5R 0805 at each rail entry to MCU power island.
- Crystal: 18 pF C0G 0402 ×2, parasitic stray budget ≤ 5 pF.
- Star ground at MCU.VSSA pin; analog return only joins digital at this point.

## §5 Connector pinout

- **J1** USB-C (power + virtual COM via ST-Link bridge)
- **J2** ARM Cortex 10-pin SWD (Tag-Connect TC2030 also acceptable)
- **J3** CR2032 holder (RTC backup)
- **J4** 6-pin GPS UART (RX / TX / PPS / 3V3 / GND / NC)
- **J5** 26-pin sensor parallel (12-b ADC + IRQ + power)
- **J6** 24-pin DAC + RS-485 backplane

## §6 Compliance / safety

- USB-C BC1.2 detection via U2 (TPS25821) — auto 1.5 A negotiation.
- TVS D1 + 1 A polyfuse F1 — ESD HBM 8 kV, EFT 1 kV (IEC 61000-4-2/4).
- MCU VBAT diode prevents back-feed during USB power loss.
- Master closure register `HEXA_REG_ID = 0x060C0402` written to MCU
  option-byte at first boot (n·σ·τ·φ identity per `firmware/sim/orbit_pipeline.hexa`).

— provenance: drafted 2026-05-08, RSC iter 18.  Spec source `firmware/sim/orbit_pipeline.hexa` (13/13 PASS).
