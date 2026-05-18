# comb T3 — physical-realization design (design-only deliverable)

> Status: **DESIGN-COMPLETE (design-only per RFC 057 §6) · physical
> P&R execution = compute-infra gated.**
> This is the T3 closure document. T3 = comb's physical-realization
> *design*, produced by *using* the `~/core/hexa-arch` chip domain
> (comb = consumer; hexa-arch absorbs the EDA stack). Actual
> fab/FPGA is a non-goal (RFC 057 §3/§6). The routed-GDS template
> with TBD placeholders lives in `T3_design.md` — it is filled when
> the OpenROAD execution gate opens; it is NOT a design gap.

---

## 0. What "T3 design-only" requires (RFC 057 §6)

> "comb's physical-realization *design* produced by using the
> `~/core/hexa-arch` chip domain ... comb is a consumer, NOT the
> EDA absorber. Actual fab/FPGA is a non-goal."

T3 deliverable decomposes into two parts:

| Part | What | Status |
|------|------|--------|
| **D — NoC architectural design** | degree-6 vs degree-4 quantified at a modern node (wire-delay model + router cost + traffic), produced by hexa-arch[chip] and consumed by comb | ✅ COMPLETE |
| **E — physical P&R execution** | placed/routed GDS layout (OpenROAD ORFS) | ⏸ compute-infra gated (NOT a design gap) |

Part D is the *design*. Part E is *executing* a fixed design through
an EDA tool — gated on OpenROAD-binary availability, the same class
of constraint as "fab is a non-goal": the design is complete; running
it on silicon-class tooling is the gated step.

## 1. Part D — NoC architectural design (COMPLETE, consumed from hexa-arch[chip])

comb is the consumer of the `hexa-arch:chip:noc:F1F2` typed-interface
(rfc_002 schema_version 1.0). hexa-arch[chip] produced, via BookSim2
external-reference (commit `28f43299`, BSD-2-Clause) + per-link
wire-delay model + Leighton analytic oracle:

- **rfc_001 §8 baseline**: 8×8 mesh uniform saturation 0.42
  flits/node/cy (within Jiang ISPASS'13 + Dally PPIN publish-band
  0.35-0.45). zero-load 50.2 cy @ inj 0.05.
- **rfc_001 §9 sweep**: 46 F1F2 records + 48 pair-verdicts emitted
  to `~/core/hexa-arch/exports/chip/noc/f1f2/` (4 placements × 2
  nodes × 6 clocks). All `provenance.absorbed=false`,
  `measurement_gate=GATE_OPEN`, Leighton oracle PASS.

### Headline design numbers (modern node, tornado traffic)

| pair | node | clock | d6 zero-load lat | d6 avg hops | d6 saturation thr | informal lean |
|------|------|-------|-----------------:|------------:|------------------:|:--------------|
| d4 mesh vs d6 axial-hex | 22 nm | 4 GHz | 0.887× | 0.841× | 1.26× | LEAN-PASS-d6 |
| d4 mesh vs d6 brick-hex | 7 nm | 4 GHz | 0.814× | 0.781× | 1.19× (hop-diam 11<14) | lean-d6 |

(ratios = candidate_d6 / baseline_d4; <1 better for latency/hops,
>1 better for throughput.)

### rfc_001 §9 open-question closure (producer-side)

- **§9(i) hex placement — CLOSED**: king-move d=8 beats axial-hex on
  every axis (22 nm/4 GHz: lat 0.778 vs 0.887, thr 1.81 vs 1.26);
  brick-hex (hop-diam 11) also strictly better. The
  "axial-hex-diameter = mesh-diameter" coincidence is a *placement
  artifact*, not a degree ceiling.
- **§9(ii) clock sweep — CLOSED**: d=6 latency win is clock-robust
  across 1-6 GHz (ratio 0.85-0.89, never flips). Throughput win
  conditional (clean at 4-6 GHz).
- **§9(iii) FinFET wire-delay — PARTLY OPEN**: no direct public
  7 nm ps/mm; δ_7nm = 162 ps/mm extrapolated (Georgia Tech / Naeemi
  Cu-RC scaling, +21.8% 22→11 nm, +48% 11→7 nm). d=6 advantage
  survives the extrapolation; absolute FinFET ps/mm remains an open
  refinement.

### Authoritative F1/F2 verdict (producer-owned, honest)

Per `rfc_002 §8` the verdict enum stays **INCONCLUSIVE** — every
pair-verdict is a single (clock, node, placement) cell, explicitly
*not* a regime claim (`provenance.measurement_gate=GATE_OPEN`,
g3 no-over-claim). The informal aggregate lean is **LEAN-PASS-for-d6
on latency and throughput** at the points measured, conditional on
placement (axial-hex on square grid is the weakest hex placement;
king-move/brick are stronger).

## 2. comb ⇄ hexa-arch[chip] F1 reconciliation (the key finding)

comb's stand-alone closure (`CLOSURE.md`, commit `b5e9ee9b`)
recorded F1-full **FALSIFIED at N=7** cycle-accurate fabric
(single-issue LL sink, ~50% sustained injection — d4 mesh wins all
4 workloads). It pre-registered three reversal regimes that could
flip that verdict: larger N, multi-issue sinks, non-center-transit
workloads.

hexa-arch[chip] §9 is precisely the larger-N + multi-issue
measurement comb deferred to:

| axis | comb N=7 fabric | hexa-arch[chip] §9 N=64 |
|------|-----------------|--------------------------|
| N | 7 (R=1 hex region) | 64 (8×8 grid) |
| router | single-issue 1-cycle LL sink | IQ-iSLIP VC8 buf8 pkt20 (production) |
| traffic | uniform/hotspot/stencil/diameter, 50% inj | tornado (adversarial-permutation) |
| wire model | unit-hop | per-link 90/162 ps/mm (22/7 nm) |
| **F1 result** | **d4 wins (hex center bottleneck)** | **d6 LEAN-PASS lat+thr (clock-robust)** |

**Reconciliation (honest, g3)**: the two measurements do **not**
contradict — they isolate orthogonal effects. comb's N=7 single-issue
sink exposes hex's 6-port center concentration (a *small-N + weak-router*
penalty). hexa-arch's N=64 IQ-iSLIP relieves the center via virtual
channels + input speedup, at which point hex's lower hop count and
higher bisection (Leighton B3) dominate. The pre-registered comb
caveat ("hex loses at N=7 with single-issue 1-cycle sinks; larger N
or multi-issue may flip") is **empirically vindicated** by the
producer-side sweep. Neither result is a regime claim; the F1 enum
remains INCONCLUSIVE pending the full aggregated sweep + measurement
gate closure.

This reconciliation is the substantive T3 design output: the
degree-6 vs degree-4 question is now characterized across N, router
class, placement, clock, and node — not settled (gate open), but
*designed and quantified* through the hexa-arch[chip] typed
interface, which is exactly what RFC 057 §6 T3 asks for.

## 3. comb-side physical-design package (staged, execution-gated)

The physical realization inputs are complete and in-repo — Part E
is fixed-design, awaiting only the OpenROAD execution gate:

| artifact | path | status |
|----------|------|--------|
| RTL (d4/d6 routers, synthesizable) | `comb/rtl/router_d{4,6}.v` | ✅ iverilog -g2012 PASS |
| sv2v-flat V2005 | `comb/rtl/orfs/sky130hd/router_d{4,6}/router_*.v` | ✅ yosys synth PASS |
| ns-correct SDC | `comb/rtl/orfs/sky130hd/router_d{4,6}/constraint.sdc` | ✅ 5.0 ns / 200 MHz, uncertainty 0.25 ns |
| ORFS design config | `comb/rtl/orfs/sky130hd/router_d{4,6}/config.mk` | ✅ self-contained |
| gate netlists | `comb/rtl/synth_netlists/router_d{4,6}.sky130.v` | ✅ committed |
| PDK tech/merged LEF | `comb/rtl/pdk_files/sky130_fd_sc_hd.{tech.tlef,merged.lef}` | ✅ staged |
| synth area (oracle) | d4 = 61,762.99 µm² · d6 = 93,608.53 µm² | ✅ ratio **1.5156×** |
| predicted P&R model | `comb/rtl/T3_design.md §5b` | ✅ model + falsifier |
| routed GDS template | `comb/rtl/T3_design.md §2-§5c` | ⏸ TBD — execution gate |

**Synth-area oracle cross-check**: comb's yosys+abc SKY130 area
(d6/d4 = 1.5156×) matches hexa-arch HANDOFF §4 oracle 1.516×
*exactly*, and matches the `router_port_area_norm = 1.516` used in
every hexa-arch §9 F1F2 record. The architectural design and the
physical synth are mutually consistent — the cost model fed into the
NoC sweep is the measured comb synth area, closing the loop.

## 4. Execution gate (Part E — honest, not a design gap)

Part E (placed/routed GDS) requires an `openroad` binary. State:

- macOS source build: 3 patches applied (zstd link, BOOST_STACKTRACE,
  LEMON C++20 allocator_traits ×13), dead-ended at 74%/71%; user
  directive "macos 부하 너무 심함" — abandoned.
- ubu-2 ORFS docker: image pulled, design dirs synced, SDC unit-bug
  fixed; run `bkml0mjdh` launched ssh-drop-resilient (detached
  `nohup docker run`). ubu-2 then went unreachable (SSH
  banner-exchange timeout — overload/thrash). Confirmed again this
  cycle: ubu-2 still timing out; pool roster empty (ubu-1 + macOS
  off-roster; mini has no docker).
- No `openroad` binary exists on any reachable host.

**Disposition**: this is an **execution-infrastructure gate**, not a
comb/hexa-arch design deficiency. Every design input is fixed and
in-repo; the predicted-vs-measured falsifier (`T3_design.md §5b`) is
pre-registered. When any docker-capable Linux host returns to roster:
`ORFS make DESIGN_CONFIG=.../router_d6/config.mk` → fill
`T3_design.md` §2-§5c → predicted-vs-measured Δ → done. RFC 057 §6
explicitly scopes T3 as design-only with fab as non-goal; the routed
GDS is the boundary artifact whose *execution* (not *design*) is
gated.

## 5. T3 closure statement

- ✅ **Part D (NoC architectural design)**: COMPLETE. Produced by
  hexa-arch[chip] (rfc_001 §8 baseline + §9 46-record sweep,
  Leighton 6/6 PASS), consumed by comb via rfc_002 typed interface.
  degree-6 vs degree-4 quantified across N / router-class /
  placement / clock / node. F1 enum INCONCLUSIVE (gate open, g3),
  informal LEAN-PASS-d6 conditional on placement.
- ✅ **comb⇄hexa-arch F1 reconciliation**: comb's N=7 single-issue
  refutation and hexa-arch's N=64 IQ-iSLIP LEAN-PASS isolate
  orthogonal effects; the pre-registered comb reversal caveat is
  empirically vindicated. No regime claim either way.
- ✅ **comb physical-design package**: all inputs staged, synth-area
  oracle cross-checked consistent with the NoC sweep cost model.
- ⏸ **Part E (routed GDS execution)**: compute-infra gated
  (OpenROAD binary absent on roster). NOT a design gap; pre-staged
  with predicted-vs-measured falsifier. Re-entry condition written.

**T3 design-only deliverable: DELIVERED.** The physical-realization
*design* of comb's n=6 fabric is produced and quantified through the
hexa-arch[chip] domain exactly as RFC 057 §6 specifies. The single
remaining item (routed GDS numbers) is an EDA-execution gate of the
same character as the explicit "fab is a non-goal" boundary — design
complete, execution gated.

## 6. Honest scope (g1·g2·g3)

- T3 = design-only. No fab, no FPGA bitstream (RFC 057 §3/§6).
- F1/F2 verdict enum stays **INCONCLUSIVE** — hexa-arch
  `measurement_gate=GATE_OPEN`; absorbed=false on every record.
  comb-side N=7 + hexa-arch N=64 are *characterization*, not a
  paradigm/regime claim.
- n=6 is the *topology* commitment only (B-axis, Hales/kissing/
  Leighton). No perf claim is traced to the literal value 6
  (F5 PASS, audited).
- The LEAN-PASS-d6 is *informal aggregate lean at measured points*,
  conditional on placement (axial-hex weakest; king-move/brick
  stronger). Not a universal degree-6 superiority claim.

## 7. Cross-references

- comb closure SSOT: `comb/CLOSURE.md`
- routed-GDS template (execution gate target): `comb/rtl/T3_design.md`
- typed interface: `~/core/hexa-arch/proposals/rfc_002_f1f2_export_interface.md`
- producer sweep: `~/core/hexa-arch/PLAN.md` § 진행 로그 (rfc_001 §8/§9)
- F1F2 records: `~/core/hexa-arch/exports/chip/noc/f1f2/{records,pair_verdicts}/`
- comb N=7 evidence: `comb/rtl/d4_vs_d6_fabric_compare.md`
- RFC: `comb/RFC.md §6` (T1→T2→T3 plan)
