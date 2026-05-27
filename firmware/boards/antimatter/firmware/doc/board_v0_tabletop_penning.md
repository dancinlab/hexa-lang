# board_v0 — tabletop Penning RF controller (HEXA-TABLETOP-FW-01)

> Phase C.5 board-spec doc for **F-AM-2**.  FPGA-class controller for
> 0.29 m³ Penning trap with 48 T solenoid, AD9162 DAC + AD9208 ADC,
> CERN AD beam-injection handshake.

**Status**: paper board v0 (2026-05-08) · **Sim-firmware**: `firmware/sim/penning_rf.hexa` (11/11 PASS) · **PCB**: TBD (Phase D)

---

## §1 Target chip

| Role | Chip | Package | Datasheet | Lead time |
|:-----|:-----|:--------|:----------|:----------|
| FPGA | Xilinx XCZU9EG-FFVC900 (UltraScale+ MPSoC) | FCBGA-900 | UG1085 | 12 wk |
| MCU (PS-side) | (integrated quad Cortex-A53 + dual Cortex-R5) | (in MPSoC) | — | — |
| 16-bit DAC | AD9162 (5 GS/s, RF-DAC) | LFCSP-88 | AD9162 spec | 8 wk |
| 14-bit ADC | AD9208 (3 GS/s, dual) | LFCSP-100 | AD9208 spec | 8 wk |
| Reference clock | TI LMK04828 (jitter cleaner) | NFBGA-64 | LMK04828 | stock |
| Reference oscillator | Wenzel ULN-OCXO 100 MHz | OCXO module | datasheet | 6 wk |
| DDR4 memory | Micron MT40A2G16 (32 Gb, 1.2 V) | FBGA-96 | MT40A | stock |
| Power | TPS6594-Q1 (PMIC) + LM5170-Q1 | (PCB stack) | — | 6 wk |

## §2 Pinout — XCZU9EG (high-speed banks only)

FPGA has 488 user I/O across 28 I/O banks; this section lists the
analog/RF-critical signals.  Full BGA ball-out lives in KiCad source.

| Bank | Ball | Net | Function | Spec |
|:----:|:----:|:----|:---------|:-----|
| 224  | AT5  | DAC_DATA[0]  (LVDS+) | OUT | 5 GS/s diff |
| 224  | AU5  | DAC_DATA[0]  (LVDS-) | OUT | 5 GS/s diff |
| 224  | AT4–AU4 | DAC_DATA[1] LVDS pair | OUT | 5 GS/s diff |
| ⋮    | (16 LVDS pairs) | DAC_DATA[15:0] | OUT | parallel data to AD9162 |
| 224  | AV3  | DAC_CLK_OUT (LVDS+) | OUT | 156.25 MHz ref |
| 224  | AW3  | DAC_CLK_OUT (LVDS-) | OUT | 156.25 MHz ref |
| 225  | AY8  | ADC_DATA[0] (LVDS+) | IN | 3 GS/s diff |
| 225  | BA8  | ADC_DATA[0] (LVDS-) | IN | 3 GS/s diff |
| ⋮    | (14 LVDS pairs) | ADC_DATA[13:0] | IN | parallel from AD9208 |
| 225  | AY11 | ADC_CLK_OUT (LVDS+) | OUT | 156.25 MHz ref |
| 226  | AY18 | TRAP_HV_BIAS_DAC_CS | OUT | SPI to slow-DAC for trap electrodes |
| 226  | AY19 | TRAP_HV_BIAS_DAC_SCK | OUT | SPI |
| 226  | AY20 | TRAP_HV_BIAS_DAC_MOSI | OUT | SPI |
| 227  | AY24 | LHE_LEVEL_SENSE | IN  (single-ended LVCMOS33) | cryo interlock |
| 227  | AY25 | MAGNET_QUENCH_DETECT | IN  (LVCMOS33) | safety EXTI |
| 228  | AY29 | CERN_AD_HANDSHAKE_TX | OUT (RS-485 diff) | beam request |
| 228  | AY30 | CERN_AD_HANDSHAKE_RX | IN  (RS-485 diff) | confirm |
| 229  | BA34 | UART_HOST_TX | OUT | telemetry |
| 229  | BA35 | UART_HOST_RX | IN  | command |
| 230  | BB37 | ETHERNET_PHY_MDIO | I/O | 1 GbE PHY config |
| 230  | BB38 | ETHERNET_PHY_MDC | OUT | 1 GbE clock |

(Full pinout: 488 user I/O — KiCad bus-spec to be generated; Vivado
constraint file `*.xdc` is the canonical source for Phase D.)

## §3 Connectors

| ID | Type | Pins | Use |
|:--:|:----|:-----|:----|
| J1 | ATX 24-pin | 24 | Main power (12 V / 5 V / 3.3 V from PSU) |
| J2 | EPS-12V 8-pin | 8 | Aux power for FPGA core (1.0 V VCCINT) |
| J3 | SMA × 2 (DAC RF out) | 2 | Trap RF drive (50 Ω, differential pair) |
| J4 | SMA × 2 (ADC RF in) | 2 | Density readout (50 Ω, differential) |
| J5 | DB-9 (RS-485) | 9 | CERN AD handshake link |
| J6 | LEMO 00B | 1 | LHe level sensor |
| J7 | LEMO 00B | 1 | Magnet quench detector |
| J8 | RJ45 (1 GbE) | 8 | host telemetry / data dump |
| J9 | USB-C | 24 | console + JTAG (via FT4232H bridge) |
| J10 | 14-pin Xilinx JTAG | 14 | Vivado programming |
| J11 | DB-25 (slow analog) | 25 | trap electrode HV bias DAC out (×8 channels) |
| J12 | OCXO header (ULN) | 4 | Wenzel 100 MHz reference |

## §4 BOM — catalog SKUs

| # | Item | Vendor | SKU | Qty | $/unit | Lead |
|:-:|:-----|:-------|:----|:---:|-------:|:----:|
| 1 | XCZU9EG-1FFVC900E | Xilinx / Avnet | XCZU9EG-1FFVC900E | 1 | $1,640 | 12 wk |
| 2 | AD9162BBCZ | ADI / Mouser | 584-AD9162BBCZ | 1 | $385 | 8 wk |
| 3 | AD9208BBPZ | ADI / Mouser | 584-AD9208BBPZ | 1 | $612 | 8 wk |
| 4 | LMK04828BISQ | TI / Mouser | 595-LMK04828BISQ | 1 | $42 | stock |
| 5 | Wenzel 501-04617 ULN-OCXO 100 MHz | Wenzel direct | 501-04617 | 1 | $1,800 | 6 wk |
| 6 | MT40A2G16RB-062E | Micron / Digi-Key | 557-1893-1-ND | 4 | $14 | stock |
| 7 | TPS6594-Q1 PMIC | TI / Mouser | 595-TPS6594QFNRDQQ1 | 1 | $26 | 6 wk |
| 8 | LM5170-Q1 buck-boost | TI / Mouser | 595-LM5170QFTRRQ1 | 1 | $9 | 6 wk |
| 9 | ICE5LP4K (config FPGA) | Lattice / Digi-Key | 220-2247-ND | 1 | $5 | stock |
| 10 | FT4232HQ (USB-JTAG bridge) | FTDI / Digi-Key | 768-1098-ND | 1 | $7 | stock |
| 11 | OPA2607 (analog buffer × 2) | TI | 595-OPA2607IDR | 4 | $4.20 | stock |
| 12 | SN65LVDM176 (RS-485 transceiver) | TI | 595-SN65LVDM176D | 1 | $3.40 | stock |
| 13 | 1 GbE PHY KSZ9031RNX | Microchip / Digi-Key | KSZ9031RNX-CT | 1 | $4.80 | stock |
| 14 | DDR4 termination resistors (kit) | Bourns | RPACK-1.5K | 32 | $0.20 | stock |
| 15 | 0.5 µF 0805 / 6.3 V (FPGA decap) | Murata | 81-GRM21BR60J474K | 80 | $0.04 | stock |
| 16 | 22 µF / 6.3 V tantalum (bulk) | Kemet | 399-3641-1-ND | 8 | $0.42 | stock |
| 17 | LEMO 00B × 2 | LEMO | EPL.00.250.NTN | 2 | $42 | 4 wk |
| 18 | SMA edge × 4 (50 Ω) | Amphenol | 132134 | 4 | $4.60 | stock |
| 19 | RJ45 magjack | Bel | SI-50140-F | 1 | $4.20 | stock |
| 20 | DB-9 right-angle | TE | 5747842-3 | 1 | $1.40 | stock |
| 21 | DB-25 right-angle | TE | 5747842-9 | 1 | $1.80 | stock |
| 22 | 8-layer PCB (200 × 200 mm, controlled-Z) | JLCPCB or PCBWay HDI | 8L-HDI | 5 | $360 | 18 d |
| 23 | SMT assembly (BGA + LFCSP) | JLCPCB Pro / PCBWay | — | 5 | $1,200 | 21 d |
| **Total (5-piece run)** |   |   |   |   | **~$5,400 / unit** | **18 wk worst-case** |

(Excludes Vivado Design Edition license $2,995/yr.)

## §5 Power budget

| Rail | Source | Sinks (W) | Total |
|:-----|:-------|:----------|:------|
| 12 V | ATX J1 | (input from 600 W PSU) | 600 W max |
| 5 V  | ATX | DDR4 ×4 (3 W), GbE PHY (0.5 W), USB hub | 8 W |
| 3.3 V | ATX | I/O banks (×6 @ 0.5 A), config FPGA (0.2 W) | 12 W |
| 1.8 V | LM5170 | DDR4 VDDIO (5 W) | 6 W |
| 1.2 V | LM5170 | DDR4 VDD (3 W), DAC LVDS, ADC LVDS (4 W) | 8 W |
| 1.0 V (VCCINT) | LM5170 | XCZU9EG core (40 W typical, 60 W peak) | 60 W |
| 0.85 V (VCCBRAM) | TPS6594 | BRAM rails (4 W) | 4 W |
| 0.9 V (MGTAVCC) | TPS6594 | GT transceivers (3 W) | 3 W |
| 1.2 V (MGTAVTT) | TPS6594 | GT transceivers (3 W) | 3 W |
| 12 V (Wenzel OCXO) | filtered | OCXO 0.5 W | 0.5 W |
| **Total board** |   |   | **~105 W steady, 130 W peak** |

PSU: Corsair RM850e (850 W 80+ Gold) — used at ~15% load.

## §6 Mechanical / cable

- **PCB**: 200 × 200 mm 8-layer HDI controlled-impedance (50 Ω LVDS), 1.6 mm.
- **Mounting**: 1U rack mount with 12 cm Noctua NF-A12x25 fan (PWM controlled by FPGA).
- **Cables**:
  - J3 RF DAC out → trap RF feed: 2× SMA semi-rigid (Sucoflex SF104), 1.5 m, low-jitter
  - J4 ADC in → trap density pickup: 2× SMA semi-rigid, 1.5 m
  - J5 RS-485 → CERN AD: shielded twisted-pair (Belden 9842), 30 m to control room
  - J8 GbE: Cat6A, 5 m
  - J11 trap HV bias: 8× SHV jacks via DB-25 break-out box

## §7 Bring-up checklist (Phase D)

| Step | Action | Pass criterion |
|:----:|:------|:---------------|
| 1 | PCB visual + X-ray BGA | no opens / shorts |
| 2 | Power smoke test (sequenced rails) | all rails within ±3% |
| 3 | OCXO 100 MHz sine output | <150 dBc/Hz @ 100 Hz offset |
| 4 | Vivado JTAG chain | XCZU9EG identified |
| 5 | "Hello World" bitstream + LED blink | LED toggles 1 Hz |
| 6 | DDR4 calibration | Vivado IP wizard PASS |
| 7 | DAC LVDS link training | AD9162 NCO 731 MHz tone, scope 50 Ω |
| 8 | ADC LVDS link training | AD9208 capture 731 MHz signal |
| 9 | DAC ↔ ADC loopback (RF cable) | THD < -60 dBc, IMD3 < -55 dBc |
| 10 | Frequency stability vs OCXO | ±0.1% drift over 1 hr |
| 11 | RS-485 echo (J5 loopback) | bit-error-rate 0 over 1 min |
| 12 | LHe sensor / quench detector EXTI | < 10 ms ISR latency |
| 13 | 1 GbE link, 1 GB iperf | sustained > 900 Mbps |
| 14 | Full state machine vs sim | matches `firmware/sim/penning_rf.hexa` |

## §8 Cross-link

- Sim-firmware: `firmware/sim/penning_rf.hexa`
- Phase A BOM: `tabletop/doc/benchtop_v0_design.md`
- Phase D HDL: `firmware/hdl/penning_rf.v`
- Phase D MCU (PS-side): `firmware/mcu/tabletop.rs`
- Falsifier: `.roadmap §A.4 F-AM-2`
- External dep: CERN AD MoU (`.roadmap §A.6 step 1`)
