<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# HEXA-DXA-01 — board-level schematic (F-SPACE-3)

> STM32H743ZI + USB host port for DXA scanner ingest + 16-bit DAC for
> bench display + microSD logger.  Same MCU family as ORBIT-01 → shared
> tooling + PCB process.

---

## §1 Block diagram

```
                          ┌──────────────────────────────┐
                          │  STM32H743ZIT6  TQFP-144      │
                          │  ─ SYSCLK 480 MHz             │
                          │  ─ USB OTG-HS host (480 Mbps) │
                          └──────────────────────────────┘
       25 MHz Y1                  │
        ───┘                      │ SWD
                                  │
   ┌─────────┐  ┌──────┐  ┌──────────┐  ┌──────┐
   │USB-A    │  │16-b  │  │microSD   │  │LCD   │
   │HOST J3  │  │DAC U3│  │SLOT J5   │  │TFT J6│
   └────┬────┘  └──┬───┘  └────┬─────┘  └──┬───┘
        │          │            │            │
        └──────────┴────────────┴────────────┘
                          │
                  USB-C power J1 → U6/U7 LDOs (same as ORBIT-01)
```

## §2 Net list (key nets)

| Net | From → To | Notes |
|:----|:----------|:------|
| `+5V_USB` | J1.VBUS → U6.IN, U7.IN | identical to ORBIT-01 |
| `+3V3` | U6 → MCU.VDD, U3.VCC, J3.VBUS_HOST (host-power 5V via boost) | digital |
| `+1V2_CORE` | U7 → MCU.VDD_CORE | core |
| `OSC_25M` | Y1 → MCU.PH0/PH1 | HSE |
| `USB_HOST_DP/DM` | J3.D+/D− ↔ MCU.PA12/PA11 (USB_OTG_HS) | host port |
| `USB_HOST_VBUS_EN` | MCU.PC0 → U8 (TPS2051 power switch) → J3.VBUS | power-only-on-attach |
| `USB_HOST_OC_n` | U8.OC → MCU.PC1 (EXTI1) | over-current sense |
| `DAC_DATA[15:0]` | MCU.PE[7:0]+PD[7:0] → U3.D[15:0] | 16-bit parallel |
| `DAC_STROBE` | MCU.PB11 → U3.LDAC | latch |
| `SD_CMD/CLK/DATA[3:0]` | MCU.PC8-12, PD2 → J5 | SDMMC1 |
| `LCD_RGB[23:0]` | MCU.PB0-1, PA1-6, PG6-12, PJ0-15 → J6 | 24-b RGB565 → 24b stripe |
| `LCD_HSYNC/VSYNC/DE/CLK` | MCU.LTDC pins → J6 | LTDC controller |
| `SWD_CLK/IO/nRST` | J2 ↔ MCU debug | identical to ORBIT-01 |

## §3 Power tree

Same as ORBIT-01 §3 — TLV75733 3V3 LDO + TPS62740 1V2 buck.  Plus:
- `+5V_HOST` (via U8 TPS2051 power switch, 500 mA limit, OC reporting)
  → J3.VBUS for USB host downstream device.

## §4 Decoupling strategy

Same as ORBIT-01 §4.  Plus 10 µF + 100 nF on `+5V_HOST` near U8 output.

## §5 Connector pinout

- **J1** USB-C (board power input)
- **J2** ARM Cortex SWD 10-pin
- **J3** USB-A host (DXA scanner ingest)
- **J5** microSD card (logger)
- **J6** TFT LCD 40-pin FFC 0.5 mm pitch (e.g. 5" 800×480 RGB)
- **J7** UART debug 4-pin (3V3 / TX / RX / GND)

## §6 Compliance / safety

- USB host overcurrent: U8 (TPS2051) limits 500 mA, asserts OC GPIO on fault.
- TVS D1 + 1 A polyfuse on USB-C VBUS (same as ORBIT-01).
- Master closure register `HEXA_REG_ID = 0x060C0402` written to MCU
  option-byte at first boot.

— provenance: drafted 2026-05-08, RSC iter 18.  Spec source `firmware/sim/dxa_pipeline.hexa` (11/11 PASS).
