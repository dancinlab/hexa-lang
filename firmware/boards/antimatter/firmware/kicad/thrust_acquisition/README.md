# `firmware/kicad/thrust_acquisition/` — Phase E project (HEXA-PROPULSION-FW-01)

> KiCad 8.0+ project for board v0 of `thrust_acquisition`.  **Empty** —
> Phase E is funding-gated.  See `../README.md` for context.

**Status**: empty (2026-05-08) · **Funding gate**: §A.6 step 2 · **Phase E sub-stage**: E3 (highest complexity, last in sequence)

---

## §1 Spec inputs

| Read | What you'll find |
|:-----|:-----------------|
| `firmware/doc/board_v0_thrust_acquisition.md §1` | Target chip table (XCVU13P Virtex UltraScale+ + 8× ADC32RF45 dual-3GS/s 12-bit + LTC2387-24 Watt + STM32H743 companion + LMK01000 zero-delay clock buffer + DDR4 ×8) |
| `firmware/doc/board_v0_thrust_acquisition.md §2` | Bank 224–232 high-speed pinout (16 channels via JESD204C × 4 lanes/ADC + PCIe Gen4 ×16 + DDR4 128-bit + NIM/CAMAC × 8) |
| `firmware/doc/board_v0_thrust_acquisition.md §3` | 13 connectors (ATX, EPS-12V × 2, BNC Cs ref, LEMO 00B × 16 ADC + × 8 NIM, SMA × 2 trigger out, PCIe edge, RJ45, USB, JTAG ×2, DB-9, OCXO header) |
| `firmware/doc/board_v0_thrust_acquisition.md §4` | 21-line BOM (~$28k/unit @ 3-piece, 20 wk worst-case) |
| `firmware/doc/board_v0_thrust_acquisition.md §5` | Power budget (~310 W steady, 400 W peak — Corsair RM1000x at ~30% load) |
| `firmware/doc/board_v0_thrust_acquisition.md §6` | Mechanical (Schroff 24555-150 3U EATX rack, 300×250 mm 14L HDI back-drilled, ×3 Noctua NF-A12x25 PWM cooling, Wakefield TF-W120 FPGA heatsink) |
| `firmware/doc/board_v0_thrust_acquisition.md §7` | 15-step bring-up (X-ray, FPGA T_j thermal, JESD204C link train ×8, ADC noise floor < 1 LSB RMS, PCIe Gen4 ×16 link, NIM/CAMAC trigger latency, BGO+ToF coincidence sub-ns) |
| `firmware/doc/schematic_v0_thrust_acquisition.md` | Block schematic + net list |
| `firmware/sim/thrust_acquisition.hexa` | Golden behavioral sim |
| `firmware/hdl/thrust_acq.v` + `thrust_acq.xdc` | Vivado top + constraints (16-ch JESD204C + PCIe XDMA) |
| `firmware/mcu/thrust_bench.rs` | STM32H743 companion + XCVU13P PS-glue Rust skeleton |

## §2 Phase E execution outline

1. KiCad project init (per `phase_e_kicad_plan.md §2`, deepest hierarchy)
2. Schematic capture (top + power × 2 + Virtex + 8× ADC32RF45 + Watt + LMK01000 + DDR4 × 8 + PCIe × 16 + NIM + STM32 + JTAG ×2)
3. PCB layout: 14-layer HDI back-drilled (50 Ω LVDS + 85 Ω PCIe diff + 100 Ω JESD204C diff CML, length-matched ±0.25 mm)
4. Gerber export → PCBWay HDI or AT&S ($1,400/spin baseline; AT&S premium for first-pass success)
5. SMT assembly (BGA × 9, AT&S/Kimball, $4,800 × 3)
6. Bring-up per board_v0 §7 — critical: thermal, JESD204C link train, ADC noise, PCIe link, sub-ns coincidence
7. Sim parity vs `firmware/sim/thrust_acquisition.hexa`

## §3 Phase E budget (this board only)

| Item | Cost | Lead |
|:-----|-----:|:----:|
| KiCad design (paper) | $0 (in-house, ~480 SE-h) | — |
| 3 × bare PCB (14L HDI back-drill) | $4,200 | 28 d |
| 3 × SMT assembly (BGA × 9) | $14,400 | 35 d |
| BOM (3 sets, XCVU13P × 3 = ~$30k of total) | $84,000 | 20 wk worst-case |
| First-spin fab + SMT | ~$102,600 total | ~28 wk |
| 2nd-spin (DfM revision) | ~$25,000 | 8 wk |
| 3rd-spin (timing closure tweaks) | ~$15,000 | 6 wk |
| **Phase E3 sub-total (this board)** | **~$143,000** | **~42 wk** |

Highest-risk board.  3-spin budget reflects high-density routing
(PCIe Gen4 + 32 Gbps GTYE4 + DDR4 + JESD204C) being unforgiving.

## §4 Cross-board dependencies

- Cs 5071A reference (off-board) — daisy-chain BNC from `atomic_clock` board (J3) via passive splitter.
- Wenzel ULN-OCXO 100 MHz — optional aux ref via J13 OCXO header.
- AT&S/Kimball turnkey option — single PO for fab + SMT + thermal management; recommended for thrust given complexity.
- Vivado Design Edition seat — minimum; Premium ($30k/yr) recommended for XCVU13P timing closure tools.

## §5 Why this is Phase E3 (last)

XCVU13P + 8× ADC32RF45 + 14-layer HDI back-drilled is the highest-risk
combo in the inventory:
1. Routing density (450+ HS signals) requires ANSYS PowerSI or HyperLynx pre-route SI sim
2. PCIe Gen4 ×16 + JESD204C 32 Gbps share GT lanes — careful bank planning
3. DDR4 fly-by topology at 1200 MHz needs IBIS-AMI sim
4. Watt-balance LTC2387 is a precision analog island in a high-EMI environment

Build E1 (pet_cyclotron) + E2 (atomic_clock) + E2.5 (tabletop_penning)
first to retire risk before committing to E3 fab.
