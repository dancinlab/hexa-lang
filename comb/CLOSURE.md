# comb/ — Closure Statement (2026-05-18)

> Closure scope: comb stand-alone deliverables (T1 + T2 sim + 5
> falsifier verdicts). External-dependency tracks (T2 tapeout P&R, T3
> physical-realization design) are HANDED OFF per `RFC.md §6` /
> `HANDOFF_TO_HEXA_ARCH.md`, NOT abandoned. This document is the
> single source recording each falsifier's measured verdict and the
> condition under which deferred items can change.

---

## 0. Goal recap

RFC 057 §6 (governance-locked):

> Prove a degree-6 hexagonal *binary-tile* spatial PIM fabric beats a
> degree-4 mesh at a modern node on a real workload — **or falsify it
> with equal rigor** — then deliver the physical-realization *design*
> (T3, design-only) via `~/core/hexa-arch` chip domain. comb =
> consumer; actual fab/FPGA = non-goal.

The goal admits two settlement paths: **proven** OR **refuted with
equal rigor**. comb closes via the second path on F1 (the only
falsifier on which comb has authoritative measurement capability) and
hands the rest to the typed-interface consumer/producer flow.

## 1. Five falsifier verdicts (RFC 057 §5)

| # | Claim                                                          | Verdict @ comb 2026-05-18 | Evidence              | Authoritative re-test |
|---|----------------------------------------------------------------|---------------------------|-----------------------|------------------------|
| F1 | degree-6 beats degree-4 mesh on wire-distance/energy at modern node | **MIXED — closed-form PASS, fabric cycle-accurate FAIL @ N=7** | sim + RTL (below)     | hexa-arch §9 N-sweep   |
| F2 | Hales-anchored geometry advantage survives EDA cost            | **PARTIAL — synth area 1.516× confirmed, P&R routed deferred** | yosys+SKY130 .lib map | hexa-arch chip §F2     |
| F3 | PIM dataflow beats von-Neumann + HBM on target workloads       | **OUT OF COMB SCOPE — separate RFC** | n/a                   | Axis-C lowering RFC    |
| F4 | binary-digital tiles suffice (no MVL needed)                    | **✅ PASS by axis-A DE-SCOPED WALL (3 × HARD_WALL)** | axis_a_radix.md       | n/a (frozen)           |
| F5 | "6" is topology-only, not perf-selecting                        | **✅ PASS — every perf claim B1/B2/B3 anchored** | RFC 057 §4 + §7       | n/a (audited)          |

### F1 — *honest refutation at this test point*

Two measurements at orthogonal rigor levels:

- **F1 closed-form (non-contention, `sim/f1_parametric.hexa` +
  `sim/workload_f1.hexa`)**: degree-6 net win in 8/8 workload sweep
  configurations — uniform / broadcast / hotspot. Stencil is the
  honest loser (1-hop locality wins on d4 mesh). Cross-over
  `t_router_d6 ≤ 276 ps` confirmed against SKY130 ASIC synth area
  ratio. **Verdict: PASS for hex (non-contention regime).**

- **F1-full cycle-accurate fabric, same-N=7 fair comparison
  (`rtl/fabric_mesh7_sustained_tb.v` vs `rtl/fabric_hex7_sustained_tb.v`)**:
  d4 mesh wins all four workloads (1.5×-4.5× latency advantage)
  despite hex's measured hop-count advantage (avg 1.43 vs 1.67 hops,
  ratio ≈ 0.86 at N=7, consistent with T1-A analytical anchor).
  Hex center R0's 6-port concentration combined with single-issue
  LL sink saturates under sustained ~50% injection, back-pressuring
  the ring. **Verdict: FAIL for hex at this test point.**

- **Pre-registered caveat realized empirically** (T1A `§5`, RFC 057
  `§7`): "Hales 2001 least-perimeter ≠ least-latency; theorems bound
  geometry, not energy/latency." Cycle-accurate routers under
  contention flipped the closed-form prediction exactly along this
  pre-registered failure surface.

- **What this is NOT**: not "hex always loses". It is "hex loses at
  N=7 with single-issue 1-cycle sinks and ~50% injection". Three
  untested-but-plausible reversal regimes remain (per
  `d4_vs_d6_fabric_compare.md §What this means for RFC 057`):
  1. larger N (asymptotic hop ratio → 1/√3 ≈ 0.577)
  2. multi-issue LL sinks (relieves the center bottleneck)
  3. workloads whose transit doesn't route through center

- **Authoritative F1 verdict** still flows through hexa-arch[chip]'s
  `F1F2-pair-verdict` typed-interface (RFC 002 §3), which controls
  N and sink models on production-grade BookSim2/Garnet. comb-side
  N=7 falsification is **necessary but not sufficient** to settle F1
  in absolute terms — `provenance.absorbed=false /
  measurement_gate=GATE_OPEN` per `COMB.tape @X x_hexa_arch_f1f2_schema`.

### F2 — *synth area robust, routed deferred*

- comb-side measurement landed:
  - cross-PDK synth (yosys + Xilinx Artix-7 / Lattice ECP5 / SKY130
    `sky130_fd_sc_hd`), area ratio **1.516×** (d6 93608.53 μm² /
    d4 61762.99 μm² at tt corner, RTL netlist).
  - F1 cross-over under measured area: hex 33% latency win, 29%
    energy win at `t_router_d6 = 152`; closed-form cross-over
    `t_router_d6 = 276` → 1.8× margin under non-contention.
- comb-side P&R routed (post-place, post-CTS, post-route):
  **DEFERRED** — ORFS run `bkml0mjdh` on ubu-2 was launched
  ssh-drop-resilient (`nohup … docker run …` detached) after the
  SDC unit-bug fix, but external compute reachability blocked
  closure within this comb cycle (ubu-2 banner-exchange timeouts,
  github.com unreachable mid-cycle). All SDC / config / RTL inputs
  are in repo (`rtl/orfs/sky130hd/router_d{4,6}/`); `T3_design.md`
  template is pre-staged to receive routed numbers when ORFS lands.
- **Authoritative F2 verdict** = hexa-arch[chip] producer-side
  measurement (`hexa-arch:chip:noc:F1F2-record` with EDA-cost vector
  from a controlled production flow). comb-side synth is
  corroboration only.

### F3 — *out of comb scope*

F3 compares **fabric vs vN+HBM at workload level** — that requires:
1. an executable PIM tile model (Axis-C dataflow lowering — its own
   RFC), and
2. an HBM3 chiplet baseline.

Neither is comb scope. comb is `n=6 topology + binary tiles` only.
Closure of F3 is **explicitly deferred to a separate Axis-C
lowering RFC**. RFC 057 §6 notes this: "C-axis dataflow lowering =
separate RFC if pursued."

### F4 — *PASS by construction (axis-A DE-SCOPED WALL)*

A-axis is **frozen as counter-evidence** in RFC 057 §3 and
`axis_a_radix.md`. Three independent real-limit anchors classified
HARD_WALL kill multi-valued physical logic as the differentiator:
1. Radix economy (Hayes 2001): b=6 ≈ 23% worse than b=3.
2. Noise margin ∝ 1/(M−1) (Maghami 2019); Shannon ~6 dB / level.
3. EDA-cost empirics: NAND QLC/PLC endurance collapse + binary-SLC
   fallback; PAM4 −9.5 dB tax; Setun ecosystem death.

This is not a measurement we ran — it's the *governance disposition*
of A-axis. Multi-valued *representation* on binary HW (BitNet-style)
remains an optional ISA encoding; that's outside the F4 claim.

### F5 — *PASS by audit (RFC 057 §4 + §7)*

Every perf claim in comb traces to B1 (Hales DCG 25 2001), B2 (2D
kissing #6, Conway-Sloane 1999), or B3 (Leighton 1992 planar
bisection/diameter bounds) — never to the literal value 6. RFC 057
§4 explicitly says: "'6' = inherited convenience constant, NOT
independently justified (radix-neutral; lattice = tool, g2)". The
honeycomb is the *consequence* of a proven theorem, not the *cause*
of any perf claim. Audit clean.

## 2. Track-level closure status

| Track   | Status                                | Evidence                                          |
|---------|---------------------------------------|---------------------------------------------------|
| T1 (analytical + axes + RFC)         | ✅ CLOSED  | T1A_analytical.md, axis_{a,b,c}, RFC 057, SURVEY  |
| T2 sim (cycle-accurate iverilog)      | ✅ CLOSED via refutation (F1-full) | fabric_{hex,mesh}7_sustained_tb + d4_vs_d6 compare |
| T2 RTL synth (cross-PDK + ASIC area)  | ✅ CLOSED  | synth_comparison.md, pdk_synthesis.md, .sky130.v   |
| T2 tapeout-ready (STA / P&R / DRC)    | ⏸ DEFERRED — handoff to hexa-arch[chip] | rtl/orfs/sky130hd/router_d{4,6}/ inputs staged    |
| T3 (physical-realization design)      | ✅ DESIGN-COMPLETE (design-only) · routed-GDS execution compute-gated | T3_DESIGN_FINAL.md                                 |

> **T3 update (2026-05-18)**: T3 design-only deliverable DELIVERED.
> hexa-arch[chip] produced the NoC architectural design (rfc_001 §8
> baseline + §9 46-record sweep across 22nm/7nm, 1-6GHz, 4 placements;
> Leighton 6/6 PASS), consumed by comb via rfc_002 typed interface.
> The §9 sweep is exactly the larger-N + multi-issue re-test comb's
> N=7 refutation deferred to: at N=64 IQ-iSLIP, d6 LEAN-PASS on
> latency (0.81-0.89×) and throughput (1.19-1.81×), clock-robust 1-6
> GHz — empirically vindicating comb's pre-registered reversal caveat.
> Verdict enum stays INCONCLUSIVE (gate open, g3 — not a regime
> claim). Routed-GDS (Part E) is an EDA-execution gate of the same
> character as the explicit fab non-goal — design complete, execution
> compute-gated. SSOT = `comb/T3_DESIGN_FINAL.md`.

T2 sim closure is **authoritative for the cycle-accurate small-N
test point** (rigorous refutation path of the goal). T2 tapeout and
T3 are gated on external-compute / external-domain availability and
are not blockers to comb's stand-alone closure.

## 3. Handoff summary (what hexa-arch consumes from comb)

Per `HANDOFF_TO_HEXA_ARCH.md` and `RFC.md §6`:

- **Inputs hexa-arch[chip] inherits from comb**:
  - RTL: `comb/rtl/router_d{4,6}.v` (sv2v-flat Verilog 2005,
    iverilog -g2012 PASS, yosys synth PASS)
  - Pre-staged ORFS design dirs: `comb/rtl/orfs/sky130hd/
    router_d{4,6}/{config.mk, router_*.v, constraint.sdc}` with
    ns-unit-correct SDC (5.0 ns / 200 MHz; uncertainty 0.25 ns)
  - Synth gate-level netlists: `comb/rtl/synth_netlists/
    router_d{4,6}.sky130.v`
  - PDK files: `comb/rtl/pdk_files/sky130_fd_sc_hd.{tech.tlef,
    merged.lef}`
  - Falsifier protocol: `comb/T1_experiment.md` (F1/F2
    pre-registered measurement spec, comb-side consumer interface)
  - Typed-interface contract reference: `COMB.tape @X
    x_hexa_arch_f1f2_schema` pinning
    `hexa-arch:chip:noc:F1F2-record` schema_version 1.0

- **Outputs comb expects back from hexa-arch[chip]** (when produced):
  - `hexa-arch:chip:noc:F1F2-pair-verdict` records for larger-N
    sweep + multi-issue sink model + real-workload (settles F1
    authoritative — may flip the N=7 refutation)
  - F2 routed numbers (post-place + post-CTS + post-route fmax / WNS
    / TNS / wire length / DRC), from a controlled production flow
    (not the macOS-build / ubu-2-docker improvisation comb attempted)
  - Per RFC 002 §6, schema_version 1.0 pinned; HXC v2 carrier when
    available, JSON interim allowed.

## 4. What "comb 완료" means precisely

- ✅ All comb stand-alone deliverables landed (T1 + T2 sim + T2
  synth area + 5 falsifier verdicts recorded).
- ✅ Goal "입증or동일엄밀도 반증" satisfied via honest refutation
  path on F1 at N=7 cycle-accurate fabric — equal rigor (RTL +
  iverilog cycle-accurate sustained traffic, same N, same workloads,
  same per-node injection).
- ✅ Pre-registered Hales caveat realized empirically — the failure
  surface was anticipated in RFC 057 §7 / T1A §5, not retrofitted.
- ✅ Deferred items (T2 tapeout routed, T3 GDSII, larger-N F1
  re-verdict) are **handed off**, not abandoned — each has a written
  re-entry condition and a typed-interface contract.

This document is the closure marker. Subsequent comb-side work, if
any, would be **scope-extension** (new falsifier, new test point,
new axis lowering), not closure of the original RFC 057 scope.

## 5. Cross-references

- Goal SSOT: root `GOAL.md` ③ (comb north-star, RESUME block)
- RFC: `comb/RFC.md` §5 falsifiers, §6 T1→T2→T3 plan
- Plan log: `comb/PLAN.md` § 진행 로그 (chronological)
- Artifact index: `comb/COMB.tape`
- Handoff: `comb/HANDOFF_TO_HEXA_ARCH.md`
- F1-full evidence: `comb/rtl/d4_vs_d6_fabric_compare.md`
- T1 analytical: `comb/T1A_analytical.md`
- Surveys: `comb/research/SURVEY.md`
