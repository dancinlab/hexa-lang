<!-- @canonical: hexa-space@local-draft (Stage-1+ T3 closure path) -->
<!-- @origin:    .roadmap.hexa_space §A.6 (post-RSC saturation 2026-05-08) -->

# 🚀 hexa-space firmware — Stage-1+ T3 closure controllers

> Phase C (sim-firmware) + Phase D (HDL skeletons) + **Phase E
> (procurement-prep docs)** for the four preregistered F-SPACE-*
> falsifiers per [`.roadmap.hexa_space §A.6`](../../.roadmap.hexa_space).
>
> Phase E lives in [`firmware/board/`](../board/) — schematic + BOM +
> PCB + commissioning + KiCad skeletons per board.
>
> **Phase F** (physical board procurement) gates closure event;
> Stage-1 program ≈ $26 k (qty 5 each + Vivado license shared).

---

## §1 Closure tier map

| Falsifier | Stage-1 controller | Phase C sim | Phase D HDL | Phase E docs | Phase F board |
|:----------|:-------------------|:-----------:|:-----------:|:------------:|:-------------:|
| F-SPACE-1 | HEXA-ORBIT-01  (STM32H7)         | ✓ `sim/orbit_pipeline.hexa` (13/13)   | ✓ `hdl/orbit_pipeline.v`   | ✓ `board/orbit_01/` (5 docs)  | ✗ funding |
| F-SPACE-2 | HEXA-LAUNCH-01 (Zynq US+ XCZU7EV)| ✓ `sim/launch_telemetry.hexa` (11/11) | ✓ `hdl/launch_telemetry.v` | ✓ `board/launch_01/` (5 docs) | ✗ funding |
| F-SPACE-3 | HEXA-DXA-01    (STM32H7)         | ✓ `sim/dxa_pipeline.hexa` (11/11)     | ✓ `hdl/dxa_pipeline.v`     | ✓ `board/dxa_01/` (5 docs)    | ✗ funding |
| F-SPACE-4 | HEXA-RAPTOR-01 (Kintex US XCKU040)| ✓ `sim/raptor_cluster.hexa` (11/11)  | ✓ `hdl/raptor_cluster.v`   | ✓ `board/raptor_01/` (5 docs) | ✗ funding |

All Phase C sims emit `__HEXA_SPACE_FW_<NAME>__ PASS` and follow recipe §4
5-invariant template (math_pure import / sentinel / FALSIFIERS array /
exit(0) / RUN-FAIL counters).

## §2 Phase scope

**Phase C — sim-firmware** (`firmware/sim/<name>.hexa`)
- Pure-software state-machine model + DAC/ADC pipeline budget +
  safety-interlock latency check.
- No real silicon; runs entirely under `hexa run` interpreter.
- n=6 lattice anchors verified at every check (master closure σ·φ = n·τ
  = J₂ + per-domain identities).

**Phase D — HDL skeleton** (`firmware/hdl/<name>.v`)
- Synthesizable Verilog top-level module, Vivado 2024.1+ (`xc7z020`,
  `xczu7ev`, `xcku040`) or Cube.ai HLS shim for STM32H7.
- **Compiles** but **not flashable** until Phase E boards arrive.
- Encodes the same n=6 lattice values as the sim (`HEXA_REG_ID =
  32'h060C_0402` packing n·σ·τ·φ).

**Phase E — procurement-prep docs** (`firmware/board/<slug>/`)
- Per-board SCHEMATIC.md + BOM.csv + PCB.md + COMMISSIONING.md +
  KiCad-readable `.kicad_sch` skeleton.
- 32/32 doc-presence audit via `verify/board_audit.hexa`.
- Stage-1 program total ≈ $26 k (qty 5 each, within .roadmap §A.6
  ~$25 k envelope).

**Phase F — physical board** (out-of-scope until funded)
- Procure custom hexa-space PCBs from JLCPCB / PCBWay per BOM.csv +
  Gerbers (Gerbers generated from KiCad once schematic + PCB layout
  populated — Phase F deliverable, not in repo yet).
- Bench: solder / connector qualification / FCC pre-scan.
- Validate: each board's bitstream against its sim sentinel — if a
  Phase D bitstream's behavioural sim diverges from the corresponding
  `firmware/sim/*.hexa`, the falsifier T3 tier is failed.

**Phase G/H — bench commissioning + closure event** (per board's
`COMMISSIONING.md`) — flips F-SPACE-N from 67 % → 100 % on PASS.

## §3 Files

```
firmware/
├── doc/
│   └── README.md                       (this file)
├── sim/                                (Phase C — runs under hexa)
│   ├── orbit_pipeline.hexa             F-SPACE-1   13/13 PASS
│   ├── launch_telemetry.hexa           F-SPACE-2   11/11 PASS
│   ├── dxa_pipeline.hexa               F-SPACE-3   11/11 PASS
│   └── raptor_cluster.hexa             F-SPACE-4   11/11 PASS
├── hdl/                                (Phase D — Vivado-compileable Verilog)
│   ├── orbit_pipeline.v                xc7z020 / STM32H7 HLS shim
│   ├── launch_telemetry.v              xczu7ev (Zynq US+ ZCU104)
│   ├── dxa_pipeline.v                  xc7z020 / STM32H7 HLS shim
│   └── raptor_cluster.v                xcku040 (Kintex US KCU105)
└── board/                              (Phase E — procurement prep docs)
    ├── README.md                       4-board catalog + KiCad workflow
    ├── orbit_01/                       HEXA-ORBIT-01  ~$99 ea (qty 5)
    ├── launch_01/                      HEXA-LAUNCH-01 ~$1,849 ea
    ├── dxa_01/                         HEXA-DXA-01    ~$134 ea
    └── raptor_01/                      HEXA-RAPTOR-01 ~$1,462 ea
        Each contains:
          SCHEMATIC.md     — block diagram + net list + power tree
          BOM.csv          — line-item BOM with Digi-Key MPNs + prices
          PCB.md           — stack-up + outline + routing rules + EMC
          COMMISSIONING.md — Phase F bring-up + closure-event gate
          <slug>.kicad_sch — KiCad 7+ S-expression root sheet
```

## §4 Run all Phase C sims

```sh
for f in firmware/sim/*.hexa; do
    HEXA_SPACE_ROOT="$(pwd)" hexa run "$f" | tail -3
done
```

Expected: 4/4 emit `__HEXA_SPACE_FW_*__ PASS` (46/46 individual checks).

## §5 Phase F readiness path

The agent **does not** simulate Phase F (no model can substitute for real
silicon).  Phase F enters scope only when:

1. Funding is committed (`~$26 k` capex per .roadmap §A.6).
2. Each board's KiCad project is fully populated from the
   `firmware/board/<slug>/SCHEMATIC.md` net list + BOM footprints,
   then Gerbers + drill files exported.
3. Board procurement order placed at JLCPCB / PCBWay (5× per board).
4. As-built measurements logged against Phase C sim sentinels +
   each board's `COMMISSIONING.md` PASS/FAIL gates (Phase G).
5. F-SPACE-N closure event captured (Phase H) — flips T3 ✗ → ✓ in
   `verify/falsifier_check.hexa` F<N>_T3 anchor.

Until then this directory + `firmware/board/` documents the **closure
path** but not the closure event.  T3 stays ✗ in
`verify/falsifier_check.hexa`.

— provenance: Phase C+D drafted 2026-05-08, RSC iter 14–17; Phase E
docs drafted 2026-05-08, RSC iter 18; Stage-1 board catalog inspired
by `hexa-antimatter` Phase C/D/E template (HEXA-PET-01 etc).
