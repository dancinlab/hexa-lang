# comb → hexa-arch[chip] — handoff (2026-05-18)

> From: hexa-lang `comb` session (RFC 057, n=6 fabric, consumer).
> To:   `~/core/hexa-arch` chip-domain session (EDA absorber, producer).
> Why:  comb did a large chunk of EDA-stack legwork this session that
>       hexa-arch[chip] should **reuse, not redo**. Also: schema asks.

---

## 1. OpenROAD toolchain — comb already installed it (reuse the patches)

comb installed the full RTL→GDSII stack locally (macOS arm64) and hit
3 macOS-compat build issues. hexa-arch[chip] is the canonical EDA
absorber — here is the exact recipe so you skip the trial-and-error:

**Installed (this machine, reversible):**
- yosys 0.65, sv2v 0.0.13 (brew) — synthesis + SV→V2k translation
- klayout (brew cask) — DRC/layout viewer
- OpenROAD deps (brew): bison, lemon(parser), spdlog, or-tools, swig,
  flex, googletest, yaml-cpp, libffi, libomp, zstd, cmake, boost, eigen
- **source-built** (brew has neither correctly):
  - COIN-OR LEMON graph 1.3.1 → `/opt/homebrew/opt/coin-lemon`
  - CUDD 3.0.0 (github ivmai/cudd) → `/opt/homebrew/opt/cudd`

**3 macOS-arm64 patches OpenROAD needs (Linux build needs none):**
1. zstd: `-DCMAKE_EXE_LINKER_FLAGS="-L/opt/homebrew/opt/zstd/lib"` +
   `-DBUILD_TESTING=OFF` (test targets link-fail on zstd).
2. Boost.Stacktrace: `-DCMAKE_CXX_FLAGS="-DBOOST_STACKTRACE_GNU_SOURCE_NOT_REQUIRED"`.
3. LEMON 1.3.1 is **C++20-incompatible** — `std::allocator::construct/
   destroy` removed. Patch `array_map.h`: route via
   `std::allocator_traits<Allocator>::construct/destroy` (13 sites).
   `comb` already patched the local copy.

**Recommendation:** if hexa-arch[chip] absorbs OpenROAD on **Linux
(ubu-1/ubu-2)** — its officially-supported platform — *none of these 3
patches apply*; it builds clean. Prefer Linux. The macOS recipe above
is the fallback if you must.

## 2. comb already produced the RTL + synth + PDK artifacts

Do **not** re-synthesize. comb's outputs (in `hexa-lang/comb/rtl/`):
- `router_d4.v` · `router_d6.v` — synthesizable RTL, `iverilog -g2012`
  PASS, cycle-accurate functional verify 4/4 (`router_d6_tb.v`).
- `synth_netlists/router_d{4,6}.sky130.v` — SKY130 `sky130_fd_sc_hd`
  gate-level netlists (yosys synth + dfflibmap + abc).
- `pdk_files/sky130_fd_sc_hd.{tech.tlef, merged.lef}` — staged SKY130
  LEF (tech + 437 merged cell LEFs).
- `router_d{4,6}.sdc` — 1 GHz constraints.
- `pnr_run.tcl` — OpenROAD floorplan→place→STA flow, ready to run.
- `fabric_2x2_tb.v` — 4-router mesh fabric cycle-accurate sim (PASS).

hexa-arch[chip]'s P&R step can consume `synth_netlists/*.sky130.v` +
`pdk_files/*` + `*.sdc` directly via `pnr_run.tcl`.

## 3. Schema ask — rfc_002 must deliver comb's consumed fields

comb consumes the F1/F2 export per the typed contract you authored
(`~/core/hexa-arch/proposals/rfc_002_f1f2_export_interface.md`). comb's
`T1A_analytical.md §8` pins the exact §3-RHS → schema-field mapping.
Please ensure rfc_002 schema v1.0 keeps these fields:
- `router_cost.{port_area_norm, port_energy_norm}` (normalized to d=4)
- `wire_delay_model.{ps_per_mm, cycle_period_ps, rc_exponent, links[]}`
- `verdict.{f1, f2}` ∈ {PASS, FAIL, INCONCLUSIVE} + `verdict.rationale`
- `leighton_oracle.{status, bisection_*, diameter_*}`
- `provenance.consumer_target == "hexa-lang:comb:RFC_057:F1F2"`
comb pins to schema MAJOR; keep the 2-MAJOR compatibility window.

## 4. comb's measured numbers = oracle your sim must reproduce

hexa-arch[chip]'s NoC sim / P&R should land near these (else flag drift):
- **SKY130 ASIC area ratio (d6/d4) = 1.516×** — comb measured via yosys
  +abc (d4 = 61,763 μm², d6 = 93,608 μm²). Your P&R area should be
  in this neighbourhood (+routing overhead).
- **Graph metrics (T1-A, Leighton oracle)**: D_hex/D_mesh = 1/√3 ≈
  0.577, hop reduction ≈ 0.845√N. Your `leighton_oracle.*` fields must
  reproduce these — they are the rfc_001 §7.3 PASS gate.
- **F1 non-contention verdict (lower bound)**: degree-6 wins uniform/
  broadcast/hotspot, **loses stencil** (1-hop). Your contention sim
  must show the same verdict *sign* at low injection rate (non-
  contention is the asymptotic low-load limit). A flip at low load =
  bug in the sim.

## 5. Status snapshot (what comb is waiting on)

- comb T1-A ✅ · T1-B-oracle ✅ · T2 RTL synth+PDK ✅ (~95%) · T2 sim
  F1 non-contention + cycle-accurate router/fabric ✅ (~75%).
- comb is **blocked on hexa-arch[chip]** for: T1-B-full (contention +
  modern-node wire model F1/F2 records) and T3 (P&R → GDSII design).
- comb's `pnr_run.tcl` can run T3 itself once an `openroad` binary
  exists — comb is mid-build (macOS, see §1). If hexa-arch[chip]
  delivers a Linux `openroad` + the ORFS flow first, comb will consume
  that instead. **Coordinate: whoever lands `openroad` first tells the
  other.**

---

> Carrier note: per `AGENTS.tape @D g_hxc`, machine-readable exports
> should be HXC v2; this handoff is human-prose markdown (architecture/
> why surface — markdown is correct here).
