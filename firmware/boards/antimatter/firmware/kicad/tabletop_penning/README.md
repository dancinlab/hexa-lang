# `firmware/kicad/tabletop_penning/` — Phase E project (HEXA-TABLETOP-FW-01)

> KiCad 8.0+ project for board v0 of `tabletop_penning`.  **Empty** —
> Phase E is funding-gated.  See `../README.md` for context.

**Status**: empty (2026-05-08) · **Funding gate**: §A.6 step 2 · **Phase E sub-stage**: E2 (mid-complexity)

---

## §1 Spec inputs

| Read | What you'll find |
|:-----|:-----------------|
| `firmware/doc/board_v0_tabletop_penning.md §1` | Target chip table (XCZU9EG MPSoC + AD9162 5GS/s DAC + AD9208 3GS/s ADC + LMK04828 jitter cleaner + Wenzel ULN-OCXO + DDR4 ×4) |
| `firmware/doc/board_v0_tabletop_penning.md §2` | Bank 224–230 LVDS pinout (16 DAC pairs, 14 ADC pairs, RS-485, GbE, OCXO ref) |
| `firmware/doc/board_v0_tabletop_penning.md §3` | 12 connectors (ATX 24, EPS-12V, SMA × 4 RF, DB-9 RS-485, LEMO LHe + quench, RJ45 GbE, JTAG, …) |
| `firmware/doc/board_v0_tabletop_penning.md §4` | 23-line BOM (~$5,400/unit @ 5-piece, 18 wk worst-case lead) |
| `firmware/doc/board_v0_tabletop_penning.md §5` | 11-rail power budget (~105 W steady, 130 W peak — Corsair RM850e 80+ Gold) |
| `firmware/doc/board_v0_tabletop_penning.md §6` | Mechanical (1U rack, Noctua NF-A12x25 PWM, 200×200 mm 8L HDI controlled-Z) |
| `firmware/doc/board_v0_tabletop_penning.md §7` | 14-step bring-up checklist |
| `firmware/doc/schematic_v0_tabletop_penning.md` | Hierarchical schematic (top + power + fpga + dac + adc + clock + rs485 + ethernet + jtag + connectors) |
| `firmware/sim/penning_rf.hexa` | Golden behavioral sim |
| `firmware/hdl/penning_rf.v` + `penning_rf.xdc` | Vivado-synth Verilog top + Vivado pin constraints |
| `firmware/mcu/tabletop.rs` | MPSoC PS-side Rust skeleton (cargo-test) |

## §2 Phase E execution outline

1. KiCad project init (per `phase_e_kicad_plan.md §3`, hierarchical schematic)
2. Schematic capture (10 sub-sheets per Phase A BOM categories)
3. PCB layout: 8-layer HDI controlled-Z (100 Ω LVDS diff, 50 Ω SE) — PCBWay HDI ($1.8k/spin)
4. Vivado synth + .xdc check (no real bitstream until bring-up)
5. SMT assembly (BGA fanout: PCBWay Pro w/ X-ray, ~$2.5k × 5)
6. Bring-up per board_v0 §7 (14 steps including OCXO jitter, JESD204C link train, RS-485 echo, 1 GbE iperf)
7. Sim parity vs `firmware/sim/penning_rf.hexa`

## §3 Phase E budget (this board only)

| Item | Cost | Lead |
|:-----|-----:|:----:|
| KiCad design (paper) | $0 (in-house, ~280 SE-h) | — |
| 5 × bare PCB (8L HDI) | $1,800 | 18 d |
| 5 × SMT assembly | $2,500 | 21 d |
| BOM (5 sets, incl. Wenzel + AD9162/AD9208 + DDR4) | $27,000 | 18 wk worst-case |
| First-spin fab + SMT | ~$31,300 total | ~22 wk |
| 2nd-spin (DfM revision) | ~$5,000 | 6 wk |
| **Phase E2 sub-total (this board)** | **~$36,000** | **~28 wk** |

Mid-complexity: requires CERN AD MoU + LHe supply contract before E2 starts.

## §4 External dependencies

- **CERN Antiproton Decelerator MoU** — RS-485 handshake protocol must be agreed in writing before fab.
- **LHe supply contract** — 100 L/mo from local cryogen supplier.
- **Vivado Design Edition seat** — $2,995/yr for XCZU9EG synth.
