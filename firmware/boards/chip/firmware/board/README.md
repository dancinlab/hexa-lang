# Phase E paper-tier hardware artifacts

> Phase E paper-tier hardware design artifacts for the 3 HEXA-CHIP firmware
> boards. **No physical hardware exists.** No Gerbers, no fab quotes, no SPICE
> netlists at this stage — only "design-on-paper" representations that
> precede physical PCB fabrication.
>
> Status: paper only (2026-05-08). Phase E iter 2.
> Roadmap: `.roadmap.hexa_chip §A.6` (Stage-1+ hardware path).

## Layout

```
firmware/board/
├── README.md                       # this file
├── bom_master.csv                  # aggregated BOM across all 3 boards
├── POWER_INTEGRITY.md              # cross-board PI summary (iter 2)
├── fw01_corner/
│   ├── schematic_paper.md          # ASCII block-level schematic
│   ├── power_chain.md              # detailed PI design (iter 2)
│   ├── kicad_project.txt           # KiCad project intent stub (iter 1)
│   └── fw01_corner.kicad_pro       # KiCad 8 project skeleton (iter 2)
├── fw02_npu/
│   ├── schematic_paper.md
│   ├── power_chain.md              # iter 2
│   ├── kicad_project.txt
│   └── fw02_npu.kicad_pro          # iter 2
└── fw03_hbm/
    ├── schematic_paper.md
    ├── power_chain.md              # iter 2
    ├── kicad_project.txt
    └── fw03_hbm.kicad_pro          # iter 2
```

## Boards

| board ID         | falsifier | dir            | per-board cost | layers | size (mm)  |
|:-----------------|:----------|:---------------|:---------------|:-------|:-----------|
| HEXA-CHIP-FW-01  | F-CHIP-1  | `fw01_corner/` | ~$155          | 4      | 100×80     |
| HEXA-CHIP-FW-02  | F-CHIP-2  | `fw02_npu/`    | ~$345          | 8      | 160×120    |
| HEXA-CHIP-FW-03  | F-CHIP-3  | `fw03_hbm/`    | ~$1870         | 10 HDI | 200×160    |

Grand total per single-set run: **~$2370**.

## Cross-link to Phase D HDL + MCU

| board           | Verilog top                              | MCU host                              |
|:----------------|:-----------------------------------------|:--------------------------------------|
| HEXA-CHIP-FW-01 | `firmware/hdl/process_corner_top.v`      | `firmware/mcu/corner_seq.hexa`        |
| HEXA-CHIP-FW-02 | `firmware/hdl/isa_n6_top.v`              | `firmware/mcu/npu_host.hexa`          |
| HEXA-CHIP-FW-03 | `firmware/hdl/hbm_thermal_top.v`         | `firmware/mcu/thermal_coord.hexa`     |

Paper board spec (pinmap + power + bringup): `firmware/doc/board_v0_spec.md`.

## Phase E gates (G1 → G5)

| gate | deliverable                                    | needs                       | status     |
|:-----|:-----------------------------------------------|:----------------------------|:-----------|
| G1   | KiCad schematic (paper → `.kicad_sch`)         | engineer-week per board     | started (iter 2 — `.kicad_pro` skeleton landed) |
| G2   | PCB layout placeholder (`.kicad_pcb`) + PI/SI sweep | layout tool licence + HyperLynx | input-deck spec'd (iter 4 — `HYPERLYNX_PI_DECK.md` landed) |
| G3   | Fab quote (Gerber → JLCPCB / Eurocircuits)     | finalized BOM + Gerbers     | pending    |
| G4   | BOM finalization (vendor lock + lifecycle)     | NDA close (Samsung+SK Hynix)| pending    |
| G5   | Physical procurement + pilot run (qty 10)      | ~$25 K funding + lab space  | pending    |

Gate G1 is paper-tier and partially unblocked (iter 2): KiCad 8
`.kicad_pro` project files now exist with netclasses + design rules per
board. G1 fully clears once schematic capture (`.kicad_sch`) is drawn —
engineer-week per board. G2–G5 require funding (~$25 K) plus foundry MOU
(Samsung Foundry + SK Hynix).

## Phase E iteration log

- **Iter 1 (commit 1322c97):** paper schematics (`schematic_paper.md` × 3),
  KiCad intent stubs (`kicad_project.txt` × 3), aggregated `bom_master.csv`.
- **Iter 2 (commit 47ef9ac):** real KiCad 8 project skeletons
  (`<id>.kicad_pro` × 3) with netclasses + design rules + text variables;
  per-board detailed power-chain spec (`power_chain.md` × 3) covering rail
  tree, decoupling network, sequencer timing, FMEA-lite, PI verification
  path; cross-board rollup `POWER_INTEGRITY.md`.
- **Iter 4 (this commit):** `HYPERLYNX_PI_DECK.md` — paper-tier
  HyperLynx PI/SI input deck spec covering all 3 boards: per-board
  stack-up (4-layer FR-4 / 8-layer Megtron 6 / 10-layer HDI Megtron 7);
  HyperLynx netclass definitions; critical-net catalog (PCIe Gen5,
  DDR4 byte lanes, HBM4 PHY 2048-bit DQ + 32-strobe); PI sweep
  parameters (Z_target curves 1 kHz – 500 MHz); SI eye/jitter pass
  criteria per spec (PCIe Gen5 BASE §8, DDR4 JESD79-4C, HBM4 spec);
  vendor SPICE/IBIS model imports needed; mesh/solver settings;
  estimated runtime per board. G2 gate moves from `pending` to
  `input-deck spec'd`.

(Phase E iter 3 — `.kicad_sch` schematic capture — remains pending;
gated on engineer-week per board.)

## Constraints (paper-tier)

- KiCad project FILES (`.kicad_pro` / `.kicad_sch` / `.kicad_pcb`) are
  intentionally **absent**. The `kicad_project.txt` stubs are intent markers
  reserving filenames; actual KiCad artifacts land at G1.
- All schematics are ASCII block-level only — see `schematic_paper.md` per
  board. No real net-level CAD.
- BOM (`bom_master.csv`) is the aggregated, cross-board candidate-part list
  pulled from `firmware/doc/board_v0_spec.md` §1.2 / §2.2 / §3.2.
- HBM4 16-Hi sample part is vendor-NDA (SK Hynix); Si interposer is foundry
  MOU (Samsung CoWoS-class partner). These line items have no public price.

## Phase chain

```
Phase A datasheets   →  <verb>/doc/datasheet_*.md
Phase B numerics     →  verify/numerics_*.hexa
Phase C sim-firmware →  firmware/sim/*.hexa
Phase D HDL + MCU    →  firmware/{hdl,mcu}/
Phase E paper board  →  firmware/board/             ← THIS
Phase E.1 KiCad real →  firmware/board/*.kicad_*    ← G1+ (deferred)
Phase F fab + bringup→  physical hardware           ← G5+ (deferred)
```

v0.1 freeze: 2026-05-08. v0.2 after Phase E G1 (KiCad schematic land).
