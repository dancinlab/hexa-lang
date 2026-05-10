# hexa-antimatter v1.1.0 — RSC FINAL + Phase A→D paper-spec surface

**Release date**: 2026-05-08
**Provenance**: `canon` SHA `c0f1f570` (extracted at v1.0.0); RSC closure cycle 2026-05-07/08
**License**: MIT
**Tag**: `v1.1.0`

---

## Summary

`hexa-antimatter` v1.1.0 is the **RSC (Runnable Surface Construction) closure release** — 25+ iterations of `~/core/bedrock/docs/runnable_surface_recipe.md` applied to the v1.0.0 spec scaffold, raising the verification surface from 4 verifiers (n6 + cross-doc + ladder + selftest) to **38 verifiers** spanning T1 algebra → T2 numerics → T3 paper-feed → Phase C/D paper-firmware.  All 4 preregistered falsifiers reach **100% bookkeeping closure** (T1 + T2×3+ + T3-paper).

```
σ(6) = 12   τ(6) = 4   φ(6) = 2   J₂ = 24
master identity:   σ · φ = n · τ = 24
```

The **RSC self-stop signal** `__HEXA_ANTIMATTER_RSC_SATURATED__ STOP` is emitted by `verify/saturation_check.hexa`; the loop has correctly terminated per recipe §7.2.

---

## Headline numbers

| Metric | v1.0.0 | v1.1.0 | Δ |
|:-------|-------:|-------:|--:|
| `verify/all.hexa` step count | 4 | **38** | +34 |
| Verify scripts on disk | 3 | **30+** | +27 |
| .hexa source LoC | ~1.2 K | **~12 K** | ×10 |
| Tests | 6 | **7** | +1 |
| Falsifier closure | 0% | **100%** (bookkeeping) | +100% |
| Phase A paper-design docs | 0 | **3** | +3 |
| Phase C sim-firmware | 0 | **4 (46/46 PASS)** | +4 |
| Phase D HDL Verilog tops | 0 | **4** (`+1 placeholder`) | +4 |
| Phase D Vivado XDC | 0 | **3** | +3 |
| Phase D Rust no_std skeletons | 0 | **4 + Cargo + lib.rs** | +6 files |
| Phase C.5 schematic specs | 0 | **4** (block + netlist + stackup) | +4 |
| Commits to origin/main | 9 | **30+** (RSC iter 13→39 ladder) | +21+ |

---

## What's new in v1.1.0

### RSC code-layer surface

- **T1 (algebraic)**: 4 `verify/calc_*.hexa` + cross-cutters (`n6_arithmetic`, `cross_doc_audit`, `release_ladder`).
- **T2 (numerical)**: 14 `verify/numerics_*.hexa` covering closed-form parity, RK4 ODE solvers, published-machine 4-effort comparison, lattice-arithmetic stability floor, cross-pillar consistency, and Stage-1 sim parity (`numerics_pet_realistic`, `numerics_tabletop_relativistic`, `numerics_dirac_precision`, `numerics_break_even_thrust`).
- **T3 (empirical paper-feed)**: 4 `verify/empirical_*_inspire.hexa` querying the INSPIRE-HEP API (with offline fixtures) for ≥ 3 of 4 milestone papers per falsifier.
- **META**: `falsifier_check`, `lint_numerics`, `firmware_phase_d_lint`, `saturation_check` (RSC self-stop signal).

### Phase A — paper benchtop design (`*/doc/benchtop_v0_design.md`)
- `factory/doc/benchtop_v0_design.md` — CERN AD adjacent factory, ~$50M Phase E3 budget envelope
- `tabletop/doc/benchtop_v0_design.md` — 0.29 m³ Penning trap, ~$0.5M Phase E1 budget
- `pet_cyclotron/doc/benchtop_v0_design.md` — hospital cyclotron retrofit, ~$1.3M Phase E1 budget

### Phase B — Stage-1 simulation parity numerics (4 scripts)
RK4 ODE integration + relativistic correction + 4-effort published parity per falsifier; all in `verify/numerics_*_relativistic.hexa` / `..._realistic.hexa` / `..._precision.hexa` / `..._thrust.hexa`.

### Phase C — golden behavioral sim-firmware (4 controllers, 46/46 PASS)
- `firmware/sim/cyclotron_trigger.hexa` — F-AM-1 PET cyclotron 7-state machine (13/13 PASS, σ·τ=48 normalized DAC, ≤ 10 ms safety interlock, 1 kHz telemetry)
- `firmware/sim/penning_rf.hexa` — F-AM-2 tabletop Penning RF (11/11 PASS, CERN AD handshake, AD9162 5 GS/s DAC sim, 24-hr STORE state)
- `firmware/sim/atomic_clock_counter.hexa` — F-AM-3 CPT bench atomic-clock counter (11/11 PASS, Cs 5071A 10 MHz ref, 1 ps TDC, 100 000 cavity finesse, 243 nm 1S-2S)
- `firmware/sim/thrust_acquisition.hexa` — F-AM-4 thrust DAQ (10/10 PASS, 16× 10 GS/s, 100 ns FPGA trigger, 50 ns ToF gate, 1 ns trigger fan-out)

### Phase C.5 — board-level paper-spec (4 boards × 2 docs each)
- `firmware/doc/board_v0_*.md` × 4 — pinout + BOM + connectors + bring-up checklist
- `firmware/doc/schematic_v0_*.md` × 4 — block diagram + power tree + net-list table + KiCad library map + PCB stackup hints + EMI/shielding notes + acceptance gates

### Phase D — synthesizable HDL + Rust no_std MCU (4+3+4 files)
- `firmware/hdl/{atomic_clock,penning_rf,thrust_acq}.v` — Verilog tops compile in Vivado 2024.1+
- `firmware/hdl/cyclotron_trigger.v` — placeholder (PET board is MCU-only)
- `firmware/hdl/{atomic_clock,penning_rf,thrust_acq}.xdc` — Vivado constraints with pin LOC + IOSTANDARD + clock + max_delay
- `firmware/hdl/build.tcl` — Vivado batch entry
- `firmware/mcu/{pet_cyclotron,tabletop,cpt_bench,thrust_bench}.rs` — Rust `no_std` skeletons (state machine + n=6 anchors + HAL trait); `cargo check` + `cargo test` host-side passes
- `firmware/mcu/{Cargo.toml,lib.rs,README.md}` — workspace + module root + Phase E roadmap

### Phase E — hardware path doc (NEW)
- `firmware/doc/PHASE_E_HARDWARE_PATH.md` — KiCad → fab → bring-up roadmap per board, vendor matrix, funding ladder ($3.5K → $50M staircase)

### Stub fills in pillar SSOTs
- `factory/antimatter-factory.md` — §10–§15 (RISKS / DEPS / TIMELINE / TOOLS / TEAM / REFS) populated
- `tabletop/tabletop-antimatter.md` — §8–§15 (IDEAS / METRICS / RISKS / DEPS / TIMELINE / TOOLS / TEAM / REFS) populated
- `pet_cyclotron/pet-cyclotron.md` — §11–§15 populated

### Roadmap update
- `.roadmap.hexa_antimatter §A.6` — Stage-1+ hardware path explicitly documented (E1 → E2 → E3 → E4)
- `.roadmap §A.6.1` — Phase B/C/C.5/D step-by-step ledger
- v1.1.0 listed as RELEASED (was "planned" at v1.0.0 cut)

---

## What's still NOT in v1.1.0 (honest scope, raw#10 C3)

- **No PCBs.** Phase E1 KiCad files are scoped but not generated.
- **No flashed firmware.** Rust skeletons compile but require physical boards to flash.
- **No bitstreams.** Vivado .xdc constraints are paper; bitstream generation requires real device target.
- **No empirical anti-H synthesis, anti-p̄ capture, or PET cyclotron operation.**
- **No working apparatus** — this repo remains a substrate spec.
- **T3 closure is paper-feed only** (INSPIRE-HEP literature scan); strict raw-data parity awaits Stage-1+.

---

## Closure status

| Falsifier | T1 | T2 stack | T3 (paper) | T3 (hardware) | Total bookkeeping |
|:----------|:--:|:--------:|:----------:|:-------------:|:-----------------:|
| F-AM-1 (PET cyclotron) | ✓ | ×4 | ✓ (≥3 papers) | ⏳ Phase E2 | **100%** |
| F-AM-2 (tabletop Penning) | ✓ | ×4 | ✓ | ⏳ Phase E2 | **100%** |
| F-AM-3 (CPT bench) | ✓ | ×4 | ✓ | ⏳ Phase E2 | **100%** |
| F-AM-4 (thrust DAQ) | ✓ | ×4 | ✓ | ⏳ Phase E2 | **100%** |

Per recipe §7.2: **sat-1 + sat-2 + sat-3 all reached** → RSC loop terminated (correct behavior; new chunks gated on Phase E hardware events per §9.1).

---

## Cross-links

- Accelerator cousin: `dancinlab/hexa-cern`
- Stage-3 propulsion fuel consumer: `dancinlab/hexa-ufo`
- HEXA family sister substrates: `dancinlab/hexa-bio`, `dancinlab/hexa-rtsc`, `dancinlab/hexa-fusion`
- Recipe: `~/core/bedrock/docs/runnable_surface_recipe.md`
- Sibling RSC closure (peer): `dancinlab/hexa-fusion v1.1.0` (parallel saturation 2026-05-08)
- Upstream `.md` SSOTs in `canon/domains/physics/`

---

## Next: v1.2.0 / v2.0.0 (post-funding)

| Version | Trigger | Scope |
|:--------|:--------|:------|
| v1.2.0 | Phase E1 funded | KiCad schematics + PCB Gerbers committed (4 boards) + JLCPCB-ready BOM |
| v1.3.0 | Phase E2 board in hand | flashed Rust + Vivado bitstream verified at JTAG |
| v1.4.0 | first p̄ capture | live data fixture row in `state/CERN_AD_LOG.hexa` (replaces paper-feed on F-AM-2 T3) |
| v2.0.0 | aspirational | sustained operation + retract `lawson-mirror` 1-decade gap (analogous to `hexa-fusion` lawson_triple) |

The recipe self-stop is correct: nothing more to add **in code** until physical events (board fab, flash, beam slot) occur.