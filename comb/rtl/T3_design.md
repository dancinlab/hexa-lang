# comb T3 — physical-realization design (placed/routed)

> Status: **TEMPLATE — awaiting ORFS bkml0mjdh completion on ubu-2.**
> Numbers below = placeholders. Fill from `~/comb_pnr_out2/{results,reports,
> logs}_d6/` once the detached docker run lands.
> Once filled, this is the T3 deliverable per RFC 057 §6 (design-only, not fab).

---

## 1. Pipeline (what produced this)

```
RTL              comb/rtl/router_d6.v  (SystemVerilog source)
  ↓ sv2v
flat Verilog     comb/rtl/orfs/sky130hd/router_d6/router_d6.v  (V2005)
  ↓ ORFS yosys (synth_xilinx-style for sky130)
gate netlist     ORFS results 1_synth.v  (SKY130 sky130_fd_sc_hd cells)
  ↓ OpenROAD floorplan + place_pins + global/detailed placement
placed DEF       ORFS results 3_5_place_dp.odb / .def
  ↓ OpenROAD CTS (clock-tree synthesis)
post-CTS         ORFS results 4_cts.odb
  ↓ OpenROAD global+detailed route
routed DEF       ORFS results 5_route.odb / .def
  ↓ klayout def→gds (or OpenROAD write_gds)
GDSII            ORFS results 6_final.gds.gz                  ← T3 endpoint
```

## 2. Headline numbers (TBD — fill from reports)

### Area

| metric                          | router_d6 | router_d4 | ratio |
|---------------------------------|----------:|----------:|------:|
| die area (μm²)                  |       TBD |       TBD |   TBD |
| core area (μm²)                 |       TBD |       TBD |   TBD |
| std-cell area (μm²)             |       TBD |       TBD |   TBD |
| placement utilization (%)       |       TBD |       TBD |     — |

> Cross-check: yosys+abc synth-only SKY130 area gave d4=61,762.99 μm² /
> d6=93,608.53 μm² (ratio 1.516×). Post-P&R numbers will include routing
> overhead — expect slightly higher.

### Timing (STA, sky130_fd_sc_hd tt corner, target 200 MHz / 5.0 ns)

| metric              | router_d6 | router_d4 |
|---------------------|----------:|----------:|
| WNS setup (ns)      |       TBD |       TBD |
| TNS setup (ns)      |       TBD |       TBD |
| WNS hold (ns)       |       TBD |       TBD |
| TNS hold (ns)       |       TBD |       TBD |
| achievable fmax     |       TBD |       TBD |

### Power (post-route SP&R estimate)

| metric              | router_d6 | router_d4 |
|---------------------|----------:|----------:|
| total power (mW)    |       TBD |       TBD |
| internal / switching/ leakage | TBD/TBD/TBD | TBD/TBD/TBD |

### Routing

| metric              | router_d6 | router_d4 |
|---------------------|----------:|----------:|
| total wire length (μm) | TBD |       TBD |
| DRC violations      |       TBD |       TBD |

## 3. F1 verdict — post-P&R update

Place-holder. F1 win inequality §3 RHS gets concrete from the post-route
STA + wire-length numbers. Pre-route prediction (from `T1A_analytical.md
§3` + synth area 1.516×): hex wins lat ~33%, energy ~29% at non-contention
lower bound. Post-route may shift due to:
- detailed-route wire-length variability (hex's diagonal routes may pay
  more in actual M2/M3 routing)
- CTS skew (hex's denser logic may complicate clock tree)
- power may diverge from area-proportional simple model

Fill: ratios from §2 → recompute §3 → final verdict.

## 4. DRC / signoff status

| check          | router_d6 | router_d4 | note |
|----------------|-----------|-----------|------|
| ORFS detail-route open count   | TBD | TBD | ORFS-internal |
| KLayout sky130 DRC             | TBD | TBD | run after GDS |
| LVS                            | n/a | n/a | requires schematic source — not produced by ORFS without extra setup |

DRC clean → T3 strict "tapeout-ready" status. DRC violations → diagnose + iter.

## 5. Artifact paths (post-run)

- ubu-2 (run dir): `~/comb_pnr_out2/results_d6/router_d6/base/`
  - `1_synth.v` — gate netlist
  - `5_route.odb` — routed design (binary)
  - `6_final.gds.gz` — GDSII
  - `6_final.sdc` — final SDC
- reports: `~/comb_pnr_out2/reports_d6/router_d6/base/`
  - `synth_stat.txt`, `2_floorplan_final.rpt`, `3_*.rpt`, `4_*.rpt`,
    `5_*.rpt`, `6_finish.rpt`
- logs: `~/comb_pnr_out2/logs_d6/router_d6/base/`

Pull to local for archival via `scp -r summer@ubu-2:~/comb_pnr_out2/
{results,reports}_d6 .` after run completes.

## 5b. Pre-result analytical predictions (model-based, NOT measurement)

> Labeled **predicted**. When `extract_pnr_metrics.sh` lands real values
> from ORFS bkml0mjdh, replace and compute predicted-vs-measured Δ.
> Predictions provide a falsifier for the model itself, not a substitute
> for the measurement (g3 no-over-claim · `T1A_analytical.md §5 caveat`).

### Area prediction (from synth-only SKY130 + standard P&R overhead)

| metric | predicted (d6) | predicted (d4) | basis |
|---|---:|---:|---|
| std-cell area | ~94,000 μm² | ~62,000 μm² | yosys+abc synth (1.516× ratio, already measured) |
| utilization target | 25% | 25% | `config.mk PLACE_DENSITY` |
| min die (util-limited) | ~376,000 μm² | ~248,000 μm² | std_cell / util |
| min die (pin-limited) | ~1,270,000 μm² | ~810,000 μm² | ~900 pins × pin-pitch / 4 sides |
| **expected die ≈** | **~1.27 mm²** | **~0.81 mm²** | pin-limited dominates (config.mk DIE=1×1 mm² may bump for d6) |

Note: d6 die may exceed the 1 mm² config — ORFS will either auto-bump
die or fail on pin congestion. If ORFS bumped die, area ratio ≈ same
1.5× shape; if it failed, refine config.mk and re-run.

### Timing prediction (SKY130 hd, tt corner, 200 MHz target = 5 ns)

| metric | predicted (d6) | predicted (d4) | basis |
|---|---:|---:|---|
| critical path | 7-input arbiter + axial route | 5-input arbiter + XY route | combinational depth |
| typical fmax  | 150-300 MHz | 200-400 MHz | sky130 hd empirical for similar NoC routers |
| WNS @ 200 MHz | -0.5 to +2 ns | +1 to +3 ns | d4 has shorter combinational path |
| TNS  | small (single-cycle FIFO) | small | both single-issue |

→ d6 may have tighter setup slack but should still close at 200 MHz.
   If d6 WNS < 0 → period must relax (e.g. 6 ns / 167 MHz) and re-route.

### Power prediction (SP&R estimate, 200 MHz, 50% activity)

Roughly area-proportional + clock-tree overhead:
| metric | predicted (d6) | predicted (d4) | basis |
|---|---:|---:|---|
| total power | ~2-4 mW | ~1.3-2.6 mW | sky130 hd flop ~1 μW/MHz, scaled |
| ratio (d6/d4) | ≈ 1.5× | — | tracks area ratio if activity equal |

### F1 (operative under measured area/timing)

If WNS_d6 > 0 AND area_d6/area_d4 < 2.0 → F1 holds at this design point.
If WNS_d6 < 0 → period must relax → d6's fmax_max < d4's fmax_max → F1
falsified at fmax-limited workload (but PASS at hop-limited workload).

This is the *operative F1 verdict* from comb-side P&R. Note: still
NOT the authoritative F1 for RFC 057 §5 — that's hexa-arch[chip]'s
typed-interface measurement_gate (rfc_002 §8). comb-side P&R =
corroboration only.

## 5c. Final disposition rubric (when bkml0mjdh data lands)

For each measured number:
1. Replace TBD in §2 / §3 / §4 with measured value.
2. Compute predicted - measured Δ; if |Δ| > 30% → model needs revision
   (note in §5b honesty ledger).
3. Re-evaluate F1: substitute measured t_router_d6 (= area_d6/area_d4
   normalized) into `T1A_analytical.md §3` win inequality.
4. DRC result → §4: clean → T3 strict tapeout-ready status (subject to
   §6 caveats); violations → diagnose + iter.
5. Status: T3 deliverable complete; falsifier F1 (RFC 057 §5) remains
   OPEN at the authoritative level (hexa-arch gate, item 4 of inbox).
6. Commit GDS + reports under `comb/rtl/t3_results/` (or large-file
   archive depending on size — GDS may be MB-scale).

## 6. Honest scope

- This is **design-only**, no fab/FPGA per RFC 057 §3 (T3 = 설계만).
- Numbers come from a **single design point** (200 MHz target, sky130hd,
  tt corner, no SI/EM analysis). Production tape-out needs slow/fast
  corners, multi-mode, EM/IR-drop sign-off — out of scope.
- F1/F2 falsifier RFC 057 §5 status stays **OPEN** until hexa-arch[chip]
  measurement_gate closes (rfc_002 §4 + §8) per comb_ultimate.decouple —
  these P&R numbers are *comb-internal* corroboration, not the
  authoritative F1/F2 verdict.
