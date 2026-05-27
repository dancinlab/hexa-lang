<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# 🔌 hexa-space firmware/board — Phase E procurement-prep

> Per-board schematic + BOM + PCB stack-up + commissioning checklist
> for the four Stage-1 controllers (.roadmap §A.6.1).  KiCad-readable
> skeletons (`.kicad_sch` + `.kicad_pro`) included for first-open;
> populate from `SCHEMATIC.md` net list + BOM footprints.

---

## §1 Catalog

| Board | Falsifier | Files | Phase D HDL | Phase C sim |
|:------|:---------:|:-----:|:-----------:|:-----------:|
| [orbit_01](orbit_01/)   | F-SPACE-1 | SCHEMATIC.md · BOM.csv · PCB.md · COMMISSIONING.md · `.kicad_pro` · `.kicad_sch` | [`hdl/orbit_pipeline.v`](../hdl/orbit_pipeline.v)   | [`sim/orbit_pipeline.hexa`](../sim/orbit_pipeline.hexa) |
| [launch_01](launch_01/) | F-SPACE-2 | SCHEMATIC.md · BOM.csv · PCB.md · COMMISSIONING.md · `.kicad_sch` | [`hdl/launch_telemetry.v`](../hdl/launch_telemetry.v) | [`sim/launch_telemetry.hexa`](../sim/launch_telemetry.hexa) |
| [dxa_01](dxa_01/)       | F-SPACE-3 | SCHEMATIC.md · BOM.csv · PCB.md · COMMISSIONING.md · `.kicad_sch` | [`hdl/dxa_pipeline.v`](../hdl/dxa_pipeline.v)         | [`sim/dxa_pipeline.hexa`](../sim/dxa_pipeline.hexa) |
| [raptor_01](raptor_01/) | F-SPACE-4 | SCHEMATIC.md · BOM.csv · PCB.md · COMMISSIONING.md · `.kicad_sch` | [`hdl/raptor_cluster.v`](../hdl/raptor_cluster.v)   | [`sim/raptor_cluster.hexa`](../sim/raptor_cluster.hexa) |

## §2 Cost summary

| Board | Prototype (1×) | Volume (5×) | F-SPACE-N closure event |
|:------|----:|----:|:------|
| orbit_01  | $132   | $99 ea  | Mercury 43″/century within ±0.1 % |
| launch_01 | $2,464 | $1,849  | Falcon 9 Δv reconstruction within ±5 % |
| dxa_01    | $178   | $134 ea | NASA Twin Study t½ ∈ [5.4, 6.6] mo |
| raptor_01 | $1,949 | $1,462  | Starship 33-engine cluster ±5 % thrust |

**Stage-1 program total (5× each + tools)** ≈ **$26 k** (within .roadmap §A.6 ~$25 k envelope).

## §3 KiCad workflow

1. Open `<board>/<board>.kicad_pro` in KiCad 7+ (creates `.kicad_pro`
   and `.kicad_sch` on first launch if not present).
2. Populate root schematic from `<board>/SCHEMATIC.md §2` net list:
   - Add MCU/FPGA symbol from official Xilinx/ST KiCad library.
   - Place each U/J/Y/D/F reference per BOM.csv.
   - Wire nets per §2 table.
3. Assign footprints (CvPcb) — KiCad standard libraries cover all 0402/0805/SMT.
4. Run ERC; resolve any warnings.
5. Export netlist; switch to PCB.
6. Set design rules per `<board>/PCB.md §3`.
7. Place + route (Freerouting auto-route covers ~80 %; manual touch-up
   for impedance-controlled traces).
8. DRC; fix; export Gerbers + drill files.
9. Submit Gerbers + BOM + CPL to JLCPCB / PCBWay.

## §4 Closure path summary

```
Phase A — Recipe baseline      ✓ (RSC saturated 2026-05-08)
Phase B — Per-falsifier T1+T2  ✓ (4/4 falsifiers @ 67%)
Phase C — Sim-firmware         ✓ (4/4 controllers — sim/*.hexa)
Phase D — HDL skeleton         ✓ (4/4 controllers — hdl/*.v)
Phase E — Procurement prep     ✓ (4/4 — board/*/SCHEMATIC|BOM|PCB|COMMISSIONING)
Phase F — Physical board       ✗ funding gate (~$26 k)
Phase G — Bench validation     ✗ requires Phase F
Phase H — F-SPACE-* T3 closure ✗ requires Phase G — flips falsifier_check to 100%
```

`verify/falsifier_check.hexa` keeps T3 ✗ until Phase H closure event
proven on at least one F-SPACE-N (then update F<N>_T3 anchor).

— provenance: drafted 2026-05-08, RSC iter 18 (Phase E doc bundle).
