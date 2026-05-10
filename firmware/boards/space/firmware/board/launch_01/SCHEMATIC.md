<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# HEXA-LAUNCH-01 — board-level schematic (F-SPACE-2)

> Xilinx Zynq UltraScale+ XCZU7EV (ZCU104 dev-kit derivative) + HDMI
> 1080p60 capture + 16-bit ADC HDMI sync backchannel + DDR4-2400 32-bit.

---

## §1 Block diagram

```
                         ┌──────────────────────────────────┐
                         │  XCZU7EV-2FFVC1156I               │
                         │  ─ APU 4× Cortex-A53 1.5 GHz      │
                         │  ─ RPU 2× Cortex-R5 600 MHz       │
                         │  ─ PL 504K LUT, 38 Mb BRAM        │
                         │  ─ 16× GTH 16.3 Gbps              │
                         └──────────────────────────────────┘
   200 MHz Wenzel OCXO Y1                │ JTAG / SWD / BOOT
        ┌──┘                             │
   ┌────┴───┐  ┌───────┐  ┌─────────┐  ┌────────┐
   │HDMI in │  │HDMI out│  │DDR4-2400│  │SD-card │
   │TMDS    │  │ (HPD/  │  │×32-bit  │  │boot    │
   │U2 PI3HD│  │ SCDC)  │  │U4 ×4    │  │J5      │
   └───┬────┘  └───┬────┘  └──┬──────┘  └────────┘
       │           │          │
       └───────────┴──────────┘
                  │
          U5 16-bit ADC AD9265 (HDMI sync analog backchannel)
```

## §2 Net list (key nets)

| Net | From → To | Notes |
|:----|:----------|:------|
| `+12V_BARREL` | J1 → U6 (LM5118 buck) → +5V0, +3V3, +1V8, +1V0_VCCINT, +0V85_VCCAUX | barrel jack 12V/5A |
| `+1V0_VCCINT` | U6c → FPGA.VCCINT (~5A typ) | core supply, decap 22µF×8 + 100nF×40 |
| `+1V8_VCCAUX` | U6d → FPGA.VCCAUX | aux supply |
| `+0V85_VCCBRAM` | U6e → FPGA.VCCBRAM | block-RAM supply |
| `OSC_200M_P/N` | Y1 → FPGA.MGTREFCLK0 (bank 224) | 200 MHz LVDS ref |
| `HDMI_RX_TMDS_CLK_P/N` | J2.1/3 → U2.IN_CLK → FPGA.IO bank 65 | TMDS clock |
| `HDMI_RX_DATA[2:0]_P/N` | J2.4-9 → U2.IN_DATA → FPGA.IO | TMDS data 2/1/0 |
| `HDMI_RX_HPD` | FPGA.PL → J2.19 (hot-plug detect) | active-high |
| `HDMI_RX_DDC_SCL/SDA` | FPGA.IIC1 → J2.15/16 | EDID exchange |
| `HDMI_TX_*` | FPGA.MGTH bank 226 → J3 | optional preview output |
| `DDR4_DQ[31:0]` | U4(×4 8-bit DDR4) ↔ FPGA.HP bank 504/505 | 2400 MT/s |
| `DDR4_CK_P/N` | FPGA.HP → U4.CK | 1.2 GHz DDR clock |
| `SD_CMD/CLK/DATA[3:0]` | FPGA.PS_SDIO0 → J5 | boot |
| `JTAG_TCK/TMS/TDI/TDO` | J6 → FPGA.PS_JTAG | digilent SMT2 compatible |
| `ADC_CLK` | FPGA.PL → U5.CLK (105 MHz) | 16-bit ADC sample clock |
| `ADC_DATA[15:0]` | U5.D[15:0] → FPGA.IO bank 66 | parallel 16-b at 105 MSPS |

## §3 Power tree

```
12 V barrel (5 A spec)
  ├─ TVS D1 (SMBJ12A)
  ├─→ U6 multi-rail buck (LM5118 + Tx ICs)
  │     ├─→ +5V0  (1A)  → HDMI hot-plug, USB host
  │     ├─→ +3V3  (3A)  → FPGA banks, peripherals
  │     ├─→ +1V8  (5A)  → VCCAUX + HP banks
  │     ├─→ +1V0  (8A)  → VCCINT (FPGA core, max ~6A loaded)
  │     └─→ +0V85 (3A)  → VCCBRAM
  └─→ Y1 OCXO 200 MHz on +5V0_isolated (LDO U7)
```

## §4 Decoupling strategy

- VCCINT: 22 µF X5R 1210 ×8 + 100 nF X7R 0402 ×40 (pin-fanout) +
  4.7 µF 0805 ×4 spread across BGA underside.
- VCCAUX/BRAM: 22 µF ×4 + 100 nF ×20 each.
- DDR4 banks: VTT termination via discrete TPS51200, 100 nF per ODT pin.
- HDMI clock isolation: π-filter (BLM18 + 100 pF + 100 pF).

## §5 Connector pinout

- **J1** 12 V DC barrel (5.5/2.1 mm, center-positive)
- **J2** HDMI Type-A (input from SpaceX webcast capture)
- **J3** HDMI Type-A (output preview to HDMI monitor)
- **J4** RJ45 Gigabit Ethernet (FPGA PS GEM3)
- **J5** Micro-SD card slot (boot from SD)
- **J6** JTAG 14-pin Xilinx (digilent SMT2 compatible)
- **J7** USB-A host (FPGA PS USB0)
- **J8** SMA pair (200 MHz ref out, optional GPSDO sync)

## §6 Compliance / safety

- TVS D1 + 5 A polyfuse — DC input ESD/surge protection.
- HDMI HPD level shifters via U8 (TXS0108E) — protects FPGA from
  cable-side 5 V transients.
- Master closure register `HEXA_REG_ID = 0x060C0402` written to FPGA
  configuration BBRAM at first programming (MCS file injects via Vivado).

— provenance: drafted 2026-05-08, RSC iter 18.  Spec source `firmware/sim/launch_telemetry.hexa` (11/11 PASS).
