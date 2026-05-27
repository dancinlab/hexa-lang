# B3 trigger card — schematic / PCB engineering pack

> §A.6.1 step E2 — board-level engineering deliverables for the
> §benchtop_v0_design.md B3 (trigger / timing controller) block.
> **Status**: schematic netlist + BOM + IO map (transcribable to KiCad);
> raw `.kicad_sch` / `.kicad_pcb` files NOT committed because there is
> no in-repo KiCad validation toolchain.
>
> **Fab readiness**: ~80% — the schematic logic + BOM + power tree are
> complete and a funded engineer with KiCad can transcribe to a fab-
> ready set in ~1–2 days. Final 20% (length matching, EMC clean-up,
> stack-up validation) lands in §A.6 Phase E procurement.

## Contents

| file              | content                                     | format |
|:------------------|:--------------------------------------------|:-------|
| `schematic_spec.md` | Block diagram + net list + component placement | Markdown |
| `BOM.csv`            | Bill of materials — Digi-Key sortable        | CSV     |
| `io_map.md`          | STM32H743 → board IO pin-by-pin assignment   | Markdown |
| `power_tree.md`     | 12 V → 5 V → 3.3 V / 1.8 V / 1.0 V regulators | Markdown |
| `fabrication_notes.md` | Stack-up + impedance + assembly notes      | Markdown |

## Why no raw KiCad files?

KiCad's `.kicad_sch` / `.kicad_pcb` formats are S-expression text but
have many implicit conventions (UUIDs, hierarchical sheet refs,
footprint library paths). Producing them without GUI validation risks
shipping files that:

- silently corrupt their library references on first save
- pass file-format-syntax check but fail electrical-rules check (ERC)
- have miswired hidden net-tie / power-flag symbols
- assume non-default symbol libraries that the fab engineer doesn't have

Producing KiCad files in this state would create false confidence: a
"complete-looking" schematic that breaks the moment an engineer opens
it. The transcribable specs in this directory are the better
engineering hand-off:

1. The CSV BOM is **canonical** — no transcription error.
2. The netlist is **explicit** — no hidden labels or invisible nets.
3. The IO map is **pin-precise** — STM32 alt-function table maps
   directly to KiCad pin properties.
4. The power-tree spec drives **regulator selection** without the
   engineer needing to second-guess decoupling-cap values.

When §A.6 Phase E lands a funded EE, the path is:
1. Open KiCad → New Project from `pcb/b3_trigger_card/`
2. Add components per `BOM.csv`
3. Wire nets per `schematic_spec.md`
4. Run ERC + DRC + length-match
5. Generate Gerbers + drill files

## Cross-references

- `mini/doc/benchtop_v0_design.md §2 B3` — block diagram
- `mini/doc/benchtop_v0_design.md §3 F1+F2` — BOM source line items
- `mini/doc/benchtop_v0_design.md §4 #1..#4` — interface table
- `firmware/hdl/timing_ctrl_top.v` — RTL the FPGA implements
- `firmware/mcu/src/main.rs` — MCU GPIO/SPI assignments
- `docs/safety/laser_iec60825.md §3` — interlock chain
- `docs/safety/radiation_shielding.md §6` — beam-current monitor wiring
