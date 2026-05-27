# `firmware/kicad/` — Phase E KiCad source skeleton

> §A.6.1 Phase E scope.  Per-board KiCad 8.0+ project structure.
> **Empty trees** (no `.kicad_sch` / `.kicad_pcb` files) — Phase E
> is a funding-gated step (~$225k for 4-board prototype run).

**Status**: skeleton dirs only (2026-05-08) · **Boards in hand**: ✗

---

## §1 Per-board project tree (planned)

```
firmware/kicad/
├─ README.md                          (this file)
├─ pet_cyclotron/
│  ├─ project.kicad_pro
│  ├─ project.kicad_sch                  ← top schematic
│  ├─ project.kicad_pcb                  ← layout
│  ├─ libraries/
│  ├─ output/                            (gitignored: gerber/pdf/bom)
│  └─ README.md
├─ tabletop_penning/
│  └─ ⋮ (8-layer HDI variant)
├─ atomic_clock/
│  └─ ⋮ (6-layer variant)
└─ thrust_acquisition/
   └─ ⋮ (14-layer HDI variant)
```

## §2 Why empty?

KiCad files are S-expression text but generating board-correct
schematics + layout demands ~1060 SE-h of work + $125k procurement
(see `firmware/doc/phase_e_kicad_plan.md` and `phase_e_pcb_plan.md`).
This is **not** a docs-layer task — committing template stubs without
real schematic content would mislead anyone parsing the tree.

When Phase E starts:
1. KiCad project initialized per `phase_e_kicad_plan.md §2`
2. Schematic captured per `firmware/doc/schematic_v0_*.md`
3. Pinout transcribed from `firmware/doc/board_v0_*.md §2` to `*.kicad_sch`
4. PCB layout per `phase_e_pcb_plan.md §2 stackup` + `§3 critical signals`
5. Gerber export → fab vendor (see `phase_e_pcb_plan.md §5`)
6. Receiving + bring-up logged in `phase_e_procurement.md` + per-board `phase_e_test_report_*.md`

## §3 Substitute — what to read instead

Until Phase E starts, use the **paper spec** as if it were KiCad:

| Need | Read |
|:-----|:-----|
| Pin list | `firmware/doc/board_v0_<board>.md §2` |
| BOM (catalog SKUs) | `firmware/doc/board_v0_<board>.md §4` |
| Block schematic | `firmware/doc/schematic_v0_<board>.md` |
| Vivado constraints (FPGA pins) | `firmware/hdl/<board>.xdc` |
| Power budget | `firmware/doc/board_v0_<board>.md §5` |
| Mechanical | `firmware/doc/board_v0_<board>.md §6` |
| Bring-up checklist | `firmware/doc/board_v0_<board>.md §7` |

These are sufficient for KiCad capture once funding lands; no
additional design upstream is required.

## §4 Cross-link

- `firmware/doc/phase_e_kicad_plan.md`
- `firmware/doc/phase_e_pcb_plan.md`
- `firmware/doc/phase_e_procurement.md`
- `firmware/doc/phase_e_test_report_template.md`
- `.roadmap.hexa_antimatter §A.6.1` row E
