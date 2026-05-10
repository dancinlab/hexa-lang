# Phase E — KiCad project plan (HEXA-FIRMWARE-PHASE-E-01)

> §A.6.1 Phase E plan.  Real KiCad sources for the 4 board v0 specs.
> Written before any procurement to make funding cost-out auditable;
> no `.kicad_pcb` / Gerber files exist yet.

**Status**: paper plan (2026-05-08) · **Boards in hand**: ✗ · **Funding**: pre-§A.6 step 2

---

## §1 Scope

KiCad 8.0+ project structure for the 4 board v0 designs:

| Project | Source spec | Target board | Estimated SE-h | NRE BOM |
|:--------|:------------|:-------------|:--------------:|:-------:|
| `kicad/pet_cyclotron/` | `firmware/doc/board_v0_pet_cyclotron.md` | STM32H743 single-board | 80 SE-h | $220 × 5 = $1.1k |
| `kicad/tabletop_penning/` | `firmware/doc/board_v0_tabletop_penning.md` | XCZU9EG MPSoC | 280 SE-h | $5.4k × 5 = $27k |
| `kicad/atomic_clock/` | `firmware/doc/board_v0_atomic_clock.md` | XCKU040 + STM32H723 | 220 SE-h | $2.4k × 5 = $12k |
| `kicad/thrust_acquisition/` | `firmware/doc/board_v0_thrust_acquisition.md` | XCVU13P | 480 SE-h | $28k × 3 = $84k |

**Phase E aggregate**: ~1060 SE-h (≈ 6 person-months @ 40 h/wk) + ~$125k procurement (small-batch, 5/3 boards each).

## §2 KiCad project file inventory (per board)

```
kicad/<board>/
├─ project.kicad_pro                  ← KiCad project (S-expression text)
├─ project.kicad_sch                  ← schematic (top + hierarchical sheets)
├─ project.kicad_pcb                  ← PCB layout
├─ project.kicad_dru                  ← DRC rules (controlled-Z, BGA fanout, …)
├─ sym-lib-table                      ← schematic symbol library
├─ fp-lib-table                       ← footprint library
├─ libraries/
│  ├─ <board>_components.kicad_sym    ← per-board symbol additions
│  └─ <board>_footprints.pretty/       ← per-board footprint additions (BGA, LFCSP, etc.)
├─ output/                            ← generated artefacts (gitignored)
│  ├─ gerber/                         ← Gerber X2 + drill files
│  ├─ pdf/                             ← schematic + assembly drawings
│  ├─ bom/                             ← KiCad BOM CSV
│  └─ position/                        ← pick-and-place CSV (CPL)
└─ README.md                          ← project-specific build notes
```

Files are S-expression text → git-trackable, diff-able, CI-checkable.

## §3 Schematic hierarchy — example (tabletop_penning)

```
top.kicad_sch
├─ power.kicad_sch                     ← ATX24 + EPS-12V + LM5170 ×3 + TPS6594
├─ fpga_xczu9eg.kicad_sch              ← FPGA + 4× DDR4 + decoupling sea
│  └─ fpga_decap.kicad_sch (×8)        ← per-bank decoupling sub-sheets
├─ dac_ad9162.kicad_sch                ← DAC + 1.8V/3.3V analog rails
├─ adc_ad9208.kicad_sch                ← ADC + reference + clock recovery
├─ clock_lmk04828.kicad_sch            ← jitter cleaner + Wenzel OCXO interface
├─ rs485_cern_ad.kicad_sch             ← SN65LVDM176 transceiver
├─ ethernet_ksz9031.kicad_sch          ← GbE PHY + magjack
├─ jtag_usb_ft4232.kicad_sch           ← USB→JTAG bridge for Vivado
└─ connectors.kicad_sch                ← all panel-mount connectors
```

Hierarchical schematic supports board-team parallel work; each
sub-sheet maps to one BOM section in `board_v0_tabletop_penning.md §4`.

## §4 PCB layout strategy

| Layer count | Stackup | Use |
|:-----------:|:--------|:----|
| 4-layer | sig / GND / +3.3V / sig | pet_cyclotron (low-density, no BGA) |
| 6-layer | sig / GND / pwr / pwr / GND / sig | atomic_clock (FPGA + DDR3) |
| 8-layer HDI | sig / GND / pwr / GND / pwr / GND / pwr / sig | tabletop_penning (FPGA + DDR4 + LVDS routing) |
| 14-layer HDI + back-drilled | (FPGA fanout) | thrust_acquisition (XCVU13P + JESD204C ×16 + PCIe Gen4 ×16) |

### Routing rules (controlled-Z)

| Net class | Impedance | Differential pair gap | Notes |
|:----------|:----------|:----------------------|:------|
| LVDS | 100 Ω diff | 0.15 mm (4-mil), tight tolerance | DAC/ADC parallel data, GbE |
| PCIe Gen4 | 85 Ω diff | 0.10 mm | thrust_acquisition only |
| JESD204C SerDes | 100 Ω diff | length-matched ±0.5 mm | thrust_acquisition |
| RF (50 Ω SE) | 50 Ω SE | — | RF gate, photodiode, NaI |
| DDR4 | 40 Ω SE / 80 Ω diff | length matched ±2 mm | tabletop, thrust |
| Slow digital (UART/SPI) | (uncontrolled) | — | — |

### Critical layout zones

1. **FPGA BGA fanout** — micro-vias, 0.4 mm pitch (dog-bone or back-drilled).
2. **DAC/ADC analog ground island** — split-plane with cap-coupled ferrite bead.
3. **Cs reference 10 MHz** — 50 Ω microstrip from BNC to FPGA, ferrite-cored cable on entry.
4. **Cryo signal entry** — PT100 + LHe sensor → opto-isolated buffer.
5. **High-current rails** (ATX12V → LM5170) — 4 oz copper, thermal vias array.

## §5 Fabrication vendor matrix

| Vendor | Class | Lead | Cost (proto, 5×) | Strengths |
|:-------|:-----:|:----:|:----------------:|:----------|
| JLCPCB Pro | mid | 7–14 d | $0.5–1.5k (4–6L) / $4–8k (8L HDI) | fastest 4-layer; ENIG cheap |
| PCBWay HDI | high | 14–28 d | $1k–5k (6–8L) / $8–20k (14L HDI) | best HDI/back-drill in 4-week window |
| AT&S | premium | 28–56 d | $20k+ | aerospace-class, only for thrust_acq |
| Kimball Electronics | turnkey | 6–10 wk | $30k+ | full SMT + test, single-PO procurement |

**Default**: JLCPCB Pro for boards 1–3 (pet_cyclotron, atomic_clock, tabletop_penning); PCBWay HDI for thrust_acquisition.  Kimball as turnkey if procurement-team gates fab+assembly under one PO.

## §6 BOM management

Single source-of-truth: `firmware/doc/board_v0_*.md §4`.  KiCad BOM
plug-in (`bom_csv_grouped_extra.py`) generates Mouser/Digi-Key CSV
matching that table.  Reconciliation lint:

```bash
firmware/scripts/bom_lint.sh   # diffs KiCad BOM CSV ↔ board_v0 §4 table
                               # FAILs on: SKU drift, qty mismatch, missing line
```

(Phase E lint script — to be authored when KiCad project exists.)

## §7 Out of scope (deferred to Phase E1+)

- Mechanical CAD (chassis, mounting, thermal) — STEP files via FreeCAD
- Cable assembly drawings (length, connector orientation, label scheme)
- EMI / EMC pre-compliance simulation (HyperLynx / Sigrity)
- Signal integrity post-route analysis at GTYE4 32 Gbps
- Design-for-Manufacturing (DfM) review
- Power Integrity simulation for FPGA core rail (ANSYS PowerSI)
- Failure-mode + reliability analysis (FMEA) per pillar bench

These need either commercial EDA seats or specialist consult time.

## §8 Cross-link

- `firmware/doc/board_v0_*.md`            — pinout + BOM (Phase C.5 paper)
- `firmware/doc/schematic_v0_*.md`        — block schematic (Phase C.5 paper)
- `firmware/hdl/*.xdc`                    — Vivado pin constraints
- `firmware/doc/phase_e_pcb_plan.md`      — PCB layout + fab follow-up
- `firmware/doc/phase_e_procurement.md`   — actual SKU procurement + receiving
- `.roadmap.hexa_antimatter §A.6.1`       — overall hardware path
