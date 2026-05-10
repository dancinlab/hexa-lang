# HyperLynx PI/SI Input Deck — Phase E iter 4

> Phase E iter 4 paper-tier specification for the HyperLynx Power
> Integrity (PI) and Signal Integrity (SI) sweep input deck across
> the 3 HEXA-CHIP firmware boards. **Status: paper only** —
> HyperLynx licence + 2 engineer-weeks per board still gating
> actual run (G2 close).
>
> Scope: this file documents the deck format, stack-up specs, net
> classes, critical-net catalog, sweep parameters, pass/fail eye/Z
> criteria, and SPICE model imports needed for HyperLynx 2024+
> import. Once licence + engineer time available, the spec here is
> directly translatable to HyperLynx project files.
>
> Cross-link: `POWER_INTEGRITY.md §7` Phase E gates table — G2 row
> upgrades from `pending` to `input-deck spec'd` after this commit.

## 1. Workflow overview

```
1. KiCad schematic capture (G1; per board fw0{1,2,3}.kicad_sch)
2. KiCad PCB layout (G2 part 1; .kicad_pcb file with stack-up)
3. Export from KiCad → HyperLynx:
     - .ses (SES/specctra) for net topology
     - .stk (stack-up file)
     - per-IC SPICE/IBIS models from vendor sites (manual import)
4. HyperLynx PI runs:
     - DC IR drop
     - AC Z-target impedance sweep (1 kHz – 500 MHz)
     - Decoupling effectiveness vs frequency
5. HyperLynx SI runs:
     - PCIe Gen5 lane eye diagram
     - DDR4 byte lane eye + DQS phase
     - HBM4 PHY DQ + DQS eye
     - General-purpose: SPI/I2C/UART
6. Iterate stack-up + decoupling + topology until pass criteria met
```

Tool target: **HyperLynx 2024.1+** (Mentor / Siemens). Per-engineer
licence ~$8 K–12 K/year; 2 engineer-weeks per board for a clean
sweep run.

## 2. Stack-up specifications (per board)

### 2.1 HEXA-CHIP-FW-01 (process corner monitor)

```
Layer  | Type   | Material      | Thickness | Cu weight | Notes
-------|--------|---------------|-----------|-----------|---------------
1      | Sig    | FR-4 IT-180   |   1.4 mil | 1 oz      | top routing
       | Prepreg| FR-4 (2x 7628)|   8 mil   | -         | Tg 180°C
2      | GND    | FR-4 IT-180   |   1.4 mil | 1 oz      | solid GND
       | Core   | FR-4 IT-180   |  47 mil   | -         | Dk=4.4 @1GHz
3      | PWR    | FR-4 IT-180   |   1.4 mil | 1 oz      | 3.3V plane
       | Prepreg| FR-4 (2x 7628)|   8 mil   | -         |
4      | Sig    | FR-4 IT-180   |   1.4 mil | 1 oz      | bottom routing
-------|--------|---------------|-----------|-----------|---------------
Total  |        |               |  ≈ 1.6 mm | -         | 4-layer FR-4
```

Material (HyperLynx import):
- IT-180 Tg = 180 °C
- Df = 0.018 @ 1 GHz
- Dk = 4.4 ± 0.05 @ 1 GHz
- 1 oz copper = 1.4 mil thickness, 0.59 mΩ/sq

### 2.2 HEXA-CHIP-FW-02 (NPU dispatcher)

```
Layer  | Type   | Material      | Thickness | Cu weight | Notes
-------|--------|---------------|-----------|-----------|---------------
1      | Sig    | Megtron 6     |   1.4 mil | 1 oz      | top
       | Prepreg| MEG-6 prepreg |   3 mil   | -         | Df 0.005 @1GHz
2      | GND    | Megtron 6     |   1.4 mil | 1 oz      |
       | Core   | Megtron 6     |   8 mil   | -         | Dk=3.7
3      | Sig    | Megtron 6     |   1.4 mil | 0.5 oz    | inner sig
       | Prepreg| MEG-6 prepreg |   3 mil   | -         |
4      | PWR    | Megtron 6     |   1.4 mil | 1 oz      | +0V85 plane
       | Core   | Megtron 6     |   8 mil   | -         |
5      | PWR    | Megtron 6     |   1.4 mil | 1 oz      | +1V8 plane
       | Prepreg| MEG-6 prepreg |   3 mil   | -         |
6      | Sig    | Megtron 6     |   1.4 mil | 0.5 oz    | inner sig
       | Core   | Megtron 6     |   8 mil   | -         |
7      | GND    | Megtron 6     |   1.4 mil | 1 oz      | solid GND
       | Prepreg| MEG-6 prepreg |   3 mil   | -         |
8      | Sig    | Megtron 6     |   1.4 mil | 1 oz      | bottom
-------|--------|---------------|-----------|-----------|---------------
Total  |        |               |  ≈ 1.6 mm | -         | 8-layer Megtron
```

Megtron 6 spec (HyperLynx import — Panasonic R-5775(N) datasheet):
- Tg = 185 °C
- Df = 0.005 @ 1 GHz / 0.006 @ 10 GHz (low-loss)
- Dk = 3.71 @ 1 GHz / 3.62 @ 10 GHz
- Suitable for PCIe Gen5 (32 GT/s) — Df low enough.

### 2.3 HEXA-CHIP-FW-03 (HBM thermal controller)

```
Layer  | Type   | Material      | Thickness | Cu weight | Notes
-------|--------|---------------|-----------|-----------|---------------
1      | Sig    | Megtron 7     |   1.4 mil | 1 oz      | top routing
       | Prepreg| MEG-7         |   2 mil   | -         | Df 0.002 (HF)
2      | GND    | Megtron 7     |   1.4 mil | 1 oz      |
       | Core   | Megtron 7     |   4 mil   | -         | Dk=3.4
3      | Sig    | Megtron 7     |   1.4 mil | 0.5 oz    | HBM4 fan-out
       | Prepreg| MEG-7         |   2 mil   | -         | buried
4      | PWR    | Megtron 7     |   1.4 mil | 1 oz      | +1V10 (HBM core)
       | Core   | Megtron 7     |   4 mil   | -         |
5      | GND    | Megtron 7     |   1.4 mil | 1 oz      | reference
       | Prepreg| MEG-7         |   2 mil   | -         |
6      | GND    | Megtron 7     |   1.4 mil | 1 oz      | reference
       | Core   | Megtron 7     |   4 mil   | -         |
7      | PWR    | Megtron 7     |   1.4 mil | 1 oz      | +0V40 (DDR I/O)
       | Prepreg| MEG-7         |   2 mil   | -         |
8      | Sig    | Megtron 7     |   1.4 mil | 0.5 oz    | HBM4 fan-out
       | Core   | Megtron 7     |   4 mil   | -         | buried
9      | GND    | Megtron 7     |   1.4 mil | 1 oz      |
       | Prepreg| MEG-7         |   2 mil   | -         |
10     | Sig    | Megtron 7     |   1.4 mil | 1 oz      | bottom routing
-------|--------|---------------|-----------|-----------|---------------
Total  |        |               |  ≈ 1.6 mm | -         | 10-layer HDI
```

HDI features required:
- Buried vias L3↔L8 (HBM4 fan-out beneath stack)
- Blind vias L1↔L2 / L9↔L10 (top-side / bottom-side)
- µvia stacks for Si interposer attach
- 4 mil (≈ 100 µm) min pitch / spacing in HBM region

Megtron 7 (Panasonic R-5785) selected over Megtron 6 for HBM4
2048-bit DQ trace density — Df 0.002 vs 0.005 lowers eye-closure
penalty by ~40 % on 6.4 Gbit/s bus.

## 3. Net classes (HyperLynx import format)

For each board, exported as `<board>.netclass`:

```
[netclass POWER_HiCurrent]
  trace_width_min = 0.5 mm
  trace_width_pref = 0.8 mm
  via_diameter_min = 0.8 mm
  Z_target = 5  ohm    # FW-03 +1V10
  members = +1V10, +0V40

[netclass POWER_LoCurrent]
  trace_width_min = 0.3 mm
  trace_width_pref = 0.5 mm
  via_diameter_min = 0.6 mm
  Z_target = 30 ohm
  members = +3V3, +1V8, +0V85, +5V0, +12V, +24V

[netclass HBM4_PHY]   # FW-03 only
  trace_width = 75 um
  diff_pair_gap = 100 um
  reference_layer = adjacent_GND
  Z_target_diff = 80 ohm
  Z_target_se = 40 ohm
  max_skew_ps = 5
  max_length_mismatch_um = 50

[netclass HBM4_CK]
  trace_width = 100 um
  diff_pair_gap = 150 um
  Z_target_diff = 100 ohm
  max_skew_ps = 2

[netclass DDR4_BL_BG0]   # FW-02 byte lane group 0
  trace_width = 127 um
  diff_pair_gap = 200 um
  Z_target_se = 50 ohm
  max_skew_ps = 5  # within byte lane
  max_byte_lane_skew_ps = 50  # between byte lanes
  members = AXI4_HBM_DQ[7:0]+, +DQS_BL0+

[netclass PCIe_Gen5]   # FW-02 only
  trace_width = 127 um
  diff_pair_gap = 200 um
  Z_target_diff = 85 ohm
  insertion_loss_max_db = 28 @ 16 GHz
  max_via_count = 4 per lane
  members = PCIE_TX_*, PCIE_RX_*, PCIE_REFCLK*

[netclass SPI_HighSpeed]
  trace_width = 200 um
  Z_target_se = 50 ohm
  max_length_mismatch_um = 1000

[netclass I2C_SMBus]
  trace_width = 150 um
  Z_target_se = 50 ohm
  pull_up_value_k = 4.7
```

## 4. Critical net catalog (per board)

### 4.1 FW-01 critical nets
- `+5V0`, `+3V3`, `+1V8`, `+1V2` (PI sweep)
- `SPI1_*` (3.3V LVCMOS, 25 MHz; SI sweep low-priority)
- `DAC_OUT[15:0]` (analog 0-5V; coupling/crosstalk to ADC inputs)
- `ADC_IN[7:0]` (differential ±2.5V; coupling-sensitive)
- `THERMAL_TRIP` (async; routing-only, no PI/SI)

### 4.2 FW-02 critical nets
**PI:**
- `+0V85` (Zynq core; tightest Z-target ≤ 10 mΩ DC-200 MHz)
- `+1V8` (DDR4 VDDQ; ≤ 25 mΩ)
- `+0V40` (HBM4-emu I/O; ≤ 15 mΩ)
- `+12V` (input rail; ≤ 100 mΩ DC)

**SI:**
- `PCIE_TX[3:0]+/-`, `PCIE_RX[3:0]+/-` (Gen5 32 GT/s; eye margin
  ≥ 30 mV / ≥ 0.4 UI)
- `PCIE_REFCLK+/-` (HCSL diff; jitter < 1 ps RMS)
- `AXI4_HBM_DQ[7:0]` × 32 byte lanes (DDR4 1600 MHz; eye margin
  ≥ 0.4 UI)
- `AXI4_HBM_DQS_BL[3:0]+/-` (write strobes; phase ± 15° to DQ)

### 4.3 FW-03 critical nets
**PI (highest density):**
- `+1V10` (HBM4 DRAM core; ≤ 5 mΩ DC-500 MHz — TIGHTEST)
- `+0V85` (HBM4 LBD logic; ≤ 12 mΩ DC-500 MHz)
- `+0V40` (HBM4 DDR I/O; ≤ 8 mΩ DC-500 MHz)

**SI (HBM4 wide bus):**
- `HBM4_DQ[2047:0]` × 32 byte groups × 64-bit (per group) (3.2 GBit/s)
  - Per byte group: ≤ 5 ps skew
  - All groups: ≤ 50 ps inter-group skew
  - Reference layer: adjacent GND (no PWR-PWR-Sig sandwich)
- `HBM4_DQS[31:0]+/-` (per byte-group strobe; phase ± 15°)
- `HBM4_CK[15:0]+/-` (per pseudo-channel clock; jitter < 5 ps RMS)

## 5. Sweep parameters

### 5.1 PI sweep (per power rail, per board)

```
[pi_sweep
   rail = <name>
   freq_lo = 1 kHz
   freq_hi = 500 MHz   # HBM4 NQR
   points  = 200       # logarithmic spacing
   z_target_curve = <imported from §3 netclass>
   decap_models = <imported per IC; .lib SPICE>
   plane_meshing = adaptive 0.5 mm
   solver = AC linear via FastHenry / FastCap
]
```

Pass criteria:
1. Z(f) ≤ Z_target across full sweep band
2. Resonance peaks (ZpZ) damped — no peaks > 2× Z_target
3. DC IR drop ≤ 5 % per regulator
4. Decoupling effectiveness: > 80 % of decap caps within 5 mm of
   the load IC

### 5.2 SI sweep (per critical net group)

**PCIe Gen5:**
```
freq_target = 16 GHz (Nyquist of 32 GT/s)
eye_open_min_v = 30 mV (per Gen5 spec § BASE Section 8.2)
eye_open_min_ui = 0.4
ber_target = 1e-12
crosstalk_max = -25 dB at 16 GHz
```

**DDR4 byte lane (1600 MHz / 3.2 Gbit/s):**
```
freq_target = 1.6 GHz
eye_open_min_ui = 0.4 (DDR4 spec § JESD79-4C)
write_dqs_phase_deg = 90 ± 15
read_dqs_phase_deg = 0 ± 15
inter_byte_skew_ps_max = 100
```

**HBM4 PHY (3.2 Gbit/s on DQ; HBM4 spec):**
```
freq_target = 1.6 GHz
eye_open_min_ui = 0.35
intra_byte_skew_ps_max = 5
inter_byte_skew_ps_max = 50
ck_to_dqs_skew_ps_max = 30
```

## 6. SPICE / IBIS model imports needed

### 6.1 FW-01
- ECP5 LFE5UM-85F: IBIS from Lattice Semi (filename `ECP5UM_v3.0.ibs`)
- TI ADS131M08: IBIS from TI (`ads131m08_*.ibs`)
- AD5676R: IBIS from Analog Devices
- STM32G474: IBIS subset from ST (only SPI pins for FW-01)
- Power regulators (LMR16030, TPS62082): SPICE `.lib` from TI
  Webench Power Designer
- LDOs (LM317, LP3878): SPICE `.lib` from TI

### 6.2 FW-02
- Zynq XCZU7EV: IBIS-AMI from Xilinx Power Estimator + IBIS-AMI
  models for PCIe transmit/receive (`zynq_us_pcie_*.ibs`)
- DDR4 SODIMM: IBIS from Micron / SK Hynix sample SPDs
- PEX8732: IBIS from Microchip
- LMZ31707, LMZ31506, LTM4638, LTM4624: SPICE `.lib` from TI/ADI
  Webench tools
- TPS65094 PMIC: SPICE `.lib` from TI

### 6.3 FW-03
- HBM4 12-Hi: NDA model (request from SK Hynix / Samsung as part
  of MOU). Placeholder: HBM3 12-Hi `hbm3_phy.ibs` with manual
  3.2 Gbit/s scale-up.
- ECP5 LFE5UM-25F: IBIS from Lattice
- STM32H7: IBIS from ST
- ADS1115: IBIS from TI
- TLV3702: SPICE from TI Webench
- RAA489204 PMU: SPICE `.lib` from Renesas (request from sales)
- TPS3823: IBIS from TI

## 7. Mesh / solver settings

```
[hyperlynx_global
   plane_mesh_size_min_mm = 0.25  # for HBM4 region; 0.5 elsewhere
   adaptive_refinement = on
   field_solver = FastHenry + FastCap
   convergence_threshold = 1e-4
   max_iterations = 500
   ground_loop_handling = auto-tie
   thermal_coupling = off  # SI/PI only; thermal in separate run
]
```

## 8. Estimated runtime per board

| board   | net count est. | PI sweeps | SI sweeps | wall time est. |
|:--------|:---------------|:----------|:----------|:----------------|
| FW-01   | ~150           | 4         | 1 (SPI)   | 2-4 hours       |
| FW-02   | ~600           | 4         | 8 (PCIe + DDR4) | 12-24 hours |
| FW-03   | ~2400 (HBM4)   | 5         | 32 (HBM4 byte groups) | 48-96 hours |

Total wall-clock for all 3: ≈ 1 week with one engineer. Iterative
re-runs after stack-up/topology fixes typically 2-3× this baseline.

## 9. Pass/fail report template

For each (board, sweep) pair, HyperLynx exports:
- `<board>_<sweep>_pi_z.csv` — Z(f) curve per rail
- `<board>_<sweep>_pi_ir.png` — DC IR drop heatmap
- `<board>_<sweep>_si_eye.png` — eye diagram per net group
- `<board>_<sweep>_si_jitter.csv` — total / random / deterministic
- `<board>_<sweep>_violations.txt` — DRC + impedance violations

Pass = all sweeps' violation files empty AND Z_target met AND eye
margin ≥ spec minima. Fail → re-fix layer count / decap placement /
reference-plane integrity / via stub / fanout topology, re-run.

## 10. Cross-references

- Schematic (paper): `fw0{1,2,3}/schematic_paper.md`
- KiCad project (skeleton): `fw0{1,2,3}/<id>.kicad_pro`
- Power-chain detail: `fw0{1,2,3}/power_chain.md`
- Aggregate PI: `POWER_INTEGRITY.md`
- Phase E gates: `README.md` § Phase E gates (G1–G5)

## 11. Status / G2 gate

- **G2 (PCB layout placeholder + PI/SI sweep)** — moves from
  `pending` (v1.0.0) to **`input-deck spec'd`** (this commit).
- G2 close requires:
  1. KiCad `.kicad_pcb` files (G1 schematic land first)
  2. HyperLynx 2024+ licence (~$8 K-12 K/eng-year)
  3. 2 engineer-weeks per board (~1 month total for 3 boards)
  4. Vendor-NDA SPICE/IBIS model collection (HBM4 esp. blocks G2 close)
- Until G2 closes, this deck stays paper-tier — input-spec only.

## 12. Provenance

- Stack-up specs cross-referenced with Panasonic R-5775(N) /
  R-5785 datasheets (Megtron 6 / Megtron 7).
- HBM4 PHY parameters per JEDEC HBM4 spec preview (Q4 2024
  draft cross-checked with canon `~/core/canon/domains/compute/chip-hbm/chip-hbm.md`).
- PCIe Gen5 eye criteria per PCI-SIG PCIe Gen5 BASE Specification §8.
- DDR4 timing per JESD79-4C.
- Iter authored 2026-05-08 (Phase E iter 4); paper-tier; no
  HyperLynx run yet performed.
