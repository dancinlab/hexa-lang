# firmware/eda/ — Phase E1+ KiCad schematic skeleton + EDA BOM + PCB stackup

> **Status (2026-05-08)**: Phase E1+ — 4 board schematics + power-tree
> subsheet + 1 PCB skeleton (board outline + 4-layer stackup). Phase
> E2 (full PCB layout placement + routing + Gerber) deferred per
> `.roadmap §A.6 Step 2` (~$1k pilot fab, 2 mo, funding-gated).

Per `.roadmap.hexa_rtsc §A.6.1` extension beyond Phase D+, this directory
adds the **schematic + EDA BOM + PCB stackup + Gerber-build script**
layer: the natural bridge from `firmware/hdl/constraints.xdc` (FPGA pin
assignments) and `firmware/mcu/chamber_drv.rs` (MCU pinout) to actual
PCB fabrication.

## Files

### Schematics (KiCad 7+ S-expression text format)

| File | Bench | Purpose |
|:----|:----|:--------|
| `quench_detect.kicad_sch`     | 48 T REBCO coil       | Quench-detect FPGA: XC7A35T + 2× LTC2378-20 + 2× AD8429 + 2× ISO224 + TLP358 |
| `synthesis_chamber.kicad_sch` | Synthesis chamber     | Chamber MCU: STM32F407VGT6 + DRV2700 PWM + 2× Pt100 RTD bridges |
| `calorimetry_rig.kicad_sch`   | Calorimetry rig       | Calorimetry MCU: STM32F407VGT6 + AD5660 DAC + LTC2400 ΣΔ ADC + Cernox sensor |
| `squid_host_adapter.kicad_sch`| SQUID DAQ pipeline    | USB-to-GPIB bridge: FT232H + NAT9914 + 24-pin GPIB IEEE-488 |
| `power_tree.kicad_sch`        | shared (subsheet)     | Power topology: 24V hot-swap → TPS7A4901 +3V3/+5V + TPS7A30 +15V + TPS7A33 -15V |

### Project + BOM + build

| File | Type | Purpose |
|:----|:----|:--------|
| `quench_detect.kicad_pro`     | KiCad project file    | Net classes (Default/POWER/DIFF_LVDS), ERC severity rules |
| `quench_detect.kicad_pcb`     | KiCad PCB skeleton    | 100 × 80 mm board outline, 4-layer ENIG stackup, 4 corner M3 mounts (placement TBD Phase E2) |
| `bom_kicad.csv`               | EDA-format BOM        | 24 part rows + PCB/PCBA targets, Mfr+MPN+Vendor PN+Datasheet |
| `build_kicad.py`              | Python 3.10+ wrapper  | Multi-target ERC + netlist + BOM + Gerber via `kicad-cli`. Skip-clean when KiCad not installed. |

## Phase E sub-stages

```
Phase E1   (commit 8f74f28)     : KiCad schematic skeleton (1 board) + EDA BOM
                                  + build script.  $0, runs today w/ kicad-cli.
Phase E1+  (this commit)        : 4 board schematics + power-tree subsheet
                                  + PCB skeleton (board outline + stackup)
                                  + multi-target build_kicad.py.  $0.
Phase E2   (~2026-Q4)           : Full PCB layout placement + routing + Gerber
                                  + DRC.  Requires schematic finalization.
                                  $1k PCB pilot, $400 PCBA, 2 mo lead.
Phase E3   (= §A.6 Step 4)      : Bring-up + cold-test on real REBCO + Cernox.
                                  Step 4 hardware procurement complete.
                                  Out of code-layer scope, $25k+, 4 mo.
```

## Build (when KiCad installed)

```bash
brew install --cask kicad           # macOS
# OR: apt install kicad             # Linux

cd firmware/eda
python3 build_kicad.py erc          # ERC report on ALL 5 schematics
python3 build_kicad.py netlist      # netlist for ALL 5 schematics
python3 build_kicad.py bom          # auto-BOM CSV per schematic
python3 build_kicad.py gerber       # Gerbers for quench_detect.kicad_pcb (Phase E2 expansion)
python3 build_kicad.py all          # all of the above
```

When KiCad is **not** installed, `build_kicad.py` exits cleanly with a
SKIP message — Phase E1+ contract is "skeleton-checked-into-repo,
verified-parse-when-toolchain-available". Output directory `build/`
is created on demand and gitignored.

## Coverage matrix (4 benches × 5 layers)

| Bench               | Stage A spec                                      | Sim          | HDL              | MCU             | Chip design | EDA schematic                  |
|:--------------------|:--------------------------------------------------|:------------:|:----------------:|:---------------:|:-----------:|:------------------------------:|
| Synthesis chamber   | `doc/synthesis_bench_v0.md`                       | ✓ 7/7        | —                | ✓ 5/5           | ✓           | `synthesis_chamber.kicad_sch` ✓|
| 48 T REBCO coil     | `doc/48t_rebco_coil_v0.md`                        | ✓ 15/15      | ✓ + tb 12/12     | —               | ✓           | `quench_detect.kicad_sch` ✓   |
| Calorimetry rig     | `doc/calorimetry_rig_v0.md`                       | ✓ 12/12      | ✓ parses         | ✓ 6/6           | ✓           | `calorimetry_rig.kicad_sch` ✓ |
| SQUID DAQ pipeline  | `doc/synthesis_bench_v0.md §6`                    | ✓ 9/9        | (host-only)      | (host-only)     | ✓           | `squid_host_adapter.kicad_sch` ✓ |
| Power tree (shared) | `firmware/doc/chip_design.md §6`                  | —            | —                | —               | ✓           | `power_tree.kicad_sch` ✓     |

**5/5 coverage** at the EDA-schematic layer.

## Spec traceability

Every component in `bom_kicad.csv` traces back to:

1. `firmware/doc/chip_design.md` §1 silicon inventory (11 ICs)
2. `firmware/doc/pinout_summary.md` datasheet-link table
3. `firmware/hdl/constraints.xdc` pin assignments (FPGA side)
4. `firmware/mcu/chamber_drv.rs` + `calorimetry_drv.rs` pin maps (MCU side)
5. `doc/{synthesis_bench,48t_rebco_coil,calorimetry_rig}_v0.md` Stage A BOMs

## PCB skeleton highlights (`quench_detect.kicad_pcb`)

- **4-layer ENIG stackup**: F.Cu / GND plane / PWR plane (split: +3V3 / +5V / +15V / -15V) / B.Cu
- **Board outline**: 100 × 80 mm (fits Eurocard half-3U)
- **4 corner M3 mounting holes** (3.2 mm)
- **Silkscreen**: title block + sentinel `__HEXA_RTSC_PCB_QUENCH_DETECT__ SKELETON`
- **ENIG copper finish**: cryogenic thermal-cycling robustness
- **Phase E2 to add**: component footprint placement (24 parts), trace
  routing (50 Ω SE / 100 Ω LVDS-diff for ADC), power plane splits, Gerber output

## Honesty contract

Phase E1+ ships:

- **5 schematic skeletons** in KiCad 7+ S-expression format. Inspectable
  via text editor; KiCad required for graphical view + DRC.
- **EDA-format BOM** with full Mfr + MPN + Vendor + Datasheet columns
  (24 rows + PCB/PCBA targets).
- **PCB skeleton** with 4-layer stackup + board outline + mounting
  holes. Component placement + routing TBD Phase E2.
- **Multi-target Python wrapper** for `kicad-cli` ERC + netlist + BOM
  + Gerber.

Phase E1+ does **NOT** ship:

- Component footprint placement on PCB (Phase E2)
- Trace routing or power plane splits (Phase E2)
- Generated Gerber files (Phase E2 — until PCB is laid out)
- Physical board (Phase E3 = `.roadmap §A.6` Step 4)
- Functional verification (Phase E3 cold-test on real REBCO + Cernox)

## Reproducibility

```bash
git clone https://github.com/dancinlab/hexa-rtsc
cd hexa-rtsc/firmware/eda

# Optional toolchain install (~5 min):
brew install --cask kicad       # macOS
# OR: apt install kicad         # Linux Ubuntu/Debian

python3 build_kicad.py all      # → ERC + netlist + BOM × 5 schematics
                                # OR clean SKIP (when kicad-cli absent)

# Manual inspection (no KiCad needed):
ls *.kicad_sch                  # text-format S-expression files
cat bom_kicad.csv               # EDA-format BOM
```

## Cross-references

- `firmware/doc/chip_design.md` — silicon inventory + pin assignments + ASCII schematic
- `firmware/hdl/constraints.xdc` — FPGA-side pin map (Vivado XDC)
- `firmware/mcu/{chamber_drv,calorimetry_drv}.rs` — MCU-side pin maps
- `firmware/build/bom.csv` — master system BOM (cryostat + NHMFL Bitter + SQUID + this PCB)
- `doc/{synthesis_bench,48t_rebco_coil,calorimetry_rig}_v0.md` — Stage A specs
- `.roadmap.hexa_rtsc §A.6 Step 2` — funding round (PCB pilot tier $1k)
- `.roadmap.hexa_rtsc §A.6 Step 4` — Stage 2/3 actual board cold-test
