# hexa-rtsc v1.1.0 — RSC code-layer FINAL + Phase A → D+ COMPLETE

**Release date**: 2026-05-08
**Closure verdict**: **100 % bookkeeping closure** (6/6 falsifiers; archival T3 proxy)
**Code-layer status**: **FINAL** — all 4 §A.6.1 phases (A → B → C → D + D+ extension) shipped.
**Empirical claim**: **NOT verified.** RT-SC physics still unsettled. Real-data
T3 (synthesis bench / 48 T REBCO coil / calorimetry rig) deferred to §A.6 Step 4
(~$225k + 14-20 mo from funding release).

This release closes the runnable-surface recipe loop (`runnable_surface_recipe.md`)
beyond strict saturation (`sat-1` + `sat-2`) by implementing the archival-API T3
pattern (hexa-cern v1.1.0 sister) and extending into hardware-prototype layer
(firmware/ Phase A → D+).

## Highlights

- **100 % bookkeeping closure**: all 6 preregistered falsifiers
  (F-RTSC-{1,2,3} + F-SC-{1,2,3}) at T1 + T2 ×3 + T3-archival ×1.
- **33 verify scripts**: T1 ×6 algebra + T2 ×16 numerical (4 ×3 stack +
  3 sim-parity + lattice_arithmetic) + T3 ×6 archival + meta ×2 +
  run_all + cross-cutters.
- **3 Stage A hardware specs** (~$6.7M / 6 mo to first raw data):
  `doc/synthesis_bench_v0.md` ($2.6M), `doc/48t_rebco_coil_v0.md`
  ($3.3M), `doc/calorimetry_rig_v0.md` ($0.8M).
- **firmware/ verified-build (70/70 PASS)**: 4 sim-firmware (43 checks) +
  iverilog testbench (12) + cargo unit tests (15).
- **Chip design + ASCII schematics + pinout**: 11-IC silicon BOM,
  STM32F407VGT6 + Artix-7 XC7A35T pin assignments, 7.6 W power budget.
- **Master Makefile + BOM CSV + verification matrix**: single-command
  rebuild, ~$7.2M total master BOM.

## What's new since v1.0.0

### 19 RSC iterations (1 → 19) closed the recipe loop:

| Iter | Chunk |
|:----:|:------|
| 1–8  | Cycle 1: T1 algebra + T2 numerical + parity (4 pillars) |
| 9–13 | T2 ×2 stack-deepening + lattice_arithmetic cross-cutter |
| 14   | `lint_numerics.hexa` (slot #15 meta) — 16-script standard COMPLETE |
| 15   | `numerics_bcs_solver.hexa` — F-SC-{1,2,3} → T2 ×3 |
| 16   | `numerics_mcmillan_solver.hexa` — F-RTSC-2 → T2 ×3 |
| 17   | `numerics_hc2_48t_solver.hexa` — F-RTSC-3 → T2 ×3 |
| 18   | `numerics_lk99_solver.hexa` — F-RTSC-1 → T2 ×3 (sat-1 + sat-2) |
| 19   | 6 `empirical_*_arxiv.hexa` scripts — 100 % closure |

### §A.6.1 Phase A → E1+ extension (post-saturation, user-overridden):

| Phase | Commits | Deliverable |
|:------|:-------|:------------|
| A     | 702ad75 | 3 hardware design docs (BOM + schematics + safety) |
| B     | e983f10 | 3 sim-parity scripts (DFT / TDGL / WHH) |
| C     | 89c031f | 2 sim-firmware (synthesis_ctrl, quench_logic) |
| D     | 71c3202 | HDL + MCU skeletons (quench_detect.v, chamber_drv.rs) |
| D+ HDL| 35f0ebb | testbench + 2nd module + Vivado tcl + xdc + Makefile |
| D+ MCU| bbb00b0 | Cargo workspace + lib + 2nd binary (calorimetry_drv) |
| D+ doc| 2e53cdd | chip design + ASCII schematics + pinout summary |
| D+ sim| c39a8e2 | calorimetry_ctrl + squid_daq |
| D+ build | b2584e9 | master Makefile + BOM csv + verification matrix |
| D+ md | fe7e021 | comprehensive .md update across CHANGELOG + 3 READMEs |
| D+ release | d5af939 | RELEASE_NOTES_v1.1.0.md + verification_matrix refresh |
| E1    | 8f74f28 | KiCad schematic (1 board) + EDA BOM + kicad-cli wrapper |
| E1+   | (this commit) | 4 schematics + power-tree subsheet + PCB skel + multi-target build |

## Falsifier closure table (post-v1.1.0)

| Falsifier | T1 | T2 | T3 | closure | Status |
|:----------|:--:|:--:|:--:|:-------:|:------:|
| F-RTSC-1 (LK-99 reproduction) | 1 | 3 | 1 | **100%** | OPEN |
| F-RTSC-2 (McMillan ceiling)   | 1 | 3 | 1 | **100%** | OPEN |
| F-RTSC-3 (48 T SC coil)       | 1 | 3 | 1 | **100%** | OPEN |
| F-SC-1 (Cooper pair φ=2)      | 1 | 3 | 1 | **100%** | OPEN |
| F-SC-2 (Abrikosov CN=6)       | 1 | 3 | 1 | **100%** | OPEN |
| F-SC-3 (BCS specific-heat)    | 1 | 3 | 1 | **100%** | OPEN |

All 6 retain `OPEN` status — closure is **bookkeeping** (evidence written
to disk + regression-locked), not empirical (RT-SC physics still unsettled).

## Test summary

| Layer | Component | Tests |
|:------|:----------|:------:|
| verify (T1 + T2 + T3 + meta) | `lint_numerics.hexa` | 113/113 PASS |
| verify (meta) | `falsifier_check.hexa` | 43/43 PASS |
| firmware/sim/ | `synthesis_ctrl.hexa` | 7/7 PASS |
| firmware/sim/ | `quench_logic.hexa` | 15/15 PASS |
| firmware/sim/ | `calorimetry_ctrl.hexa` | 12/12 PASS |
| firmware/sim/ | `squid_daq.hexa` | 9/9 PASS |
| firmware/hdl/ | `tb_quench_detect.v` (iverilog 11.0) | 12/12 PASS |
| firmware/mcu/ | `lib.rs` (cargo) | 4/4 PASS |
| firmware/mcu/ | `chamber_drv.rs` (cargo) | 5/5 PASS |
| firmware/mcu/ | `calorimetry_drv.rs` (cargo) | 6/6 PASS |
| **TOTAL** | **10 components** | **226/226 PASS** |

## Toolchains used

| Tool | Version | Status | Used for |
|:----|:--------|:-------|:--------|
| hexa runtime | 0.x | ✓ host today | sim-firmware + verify/* |
| iverilog | 11.0 | ✓ homebrew today | HDL testbench |
| cargo + rustc | 1.94 | ✓ host today | MCU host + tests |
| rustup target add thumbv7em-none-eabihf | available | ✓ via rustup | MCU embedded cross-compile |
| Vivado | 2024.2 | ✗ not installed | HDL synth + impl + bitstream |
| OpenOCD / probe-rs | latest | ✗ not installed | flash (no board) |

## Honesty contract (recipe §9)

100% closure means **archival-API + verified-build + sim-PASS**:

- The empirical territory is real (arXiv corpus indexes ≥ 100 papers per topic)
- The closed-form derivations are numerically reproducible (16 numerics scripts pass)
- The hardware-prototype code compiles + simulates (70/70 firmware tests pass)

100% closure does **NOT** mean:

- LK-99 has been reproduced (it has not)
- McMillan ceiling has been measured at high-Tc bench (it has not at our hands)
- 48 T REBCO coil exists (it has not been built)
- ΔC/γTc has been measured below Tc on s-wave SC at our calorimetry rig (no rig)

Strict raw-data T3 closure → **§A.6 Step 4** (Stage-2/3 build),
~$225k + 14-20 mo from funding release.

## Next steps (out of code-layer scope)

Per `.roadmap.hexa_rtsc §A.6`:

1. **Step 1** (2026-Q3): External collab decision — synthesis lab
   (NIMS / Argonne MSD / 大阪大 / KIAS / SNU CMR) + high-field magnet
   lab (NHMFL / Dresden HZDR / Kyoto-RIKEN). Out of `.hexa` scope.
2. **Step 2** (2026-Q4): Funding round — high-pressure synthesis
   chamber + 48 T REBCO test rig + UPS/STM/INS suite. Out of `.hexa` scope.
3. **Step 3** (~2026-12): Stage-1 simulation parity (DFT/QSGW for
   LK-99 candidates · TDGL vortex solver · WHH full integral) —
   **partial-RSC** (.hexa T2 boost, code-layer reachable).
4. **Step 4** (~2027-Q1+): Stage-2/3 actual synthesis + measurement —
   firmware flash + cold-test + raw-data ingest. Years out, not in
   code-layer scope.

## Reproducibility

```bash
git clone https://github.com/dancinlab/hexa-rtsc
cd hexa-rtsc

# Verify layer (33 scripts):
hexa run cli/hexa-rtsc.hexa verify    # all-in-one
# OR individually:
hexa run verify/lattice_check.hexa
hexa run verify/lint_numerics.hexa     # → 113/113 PASS
hexa run verify/falsifier_check.hexa   # → 43/43 PASS

# Firmware layer (70/70):
brew install icarus-verilog            # iverilog 11.0+ for HDL testbench
cd firmware && make test               # → sim 4 + HDL 12 + MCU 15 = 31 host-runnable
                                        # (full 70/70 includes per-test counts)
```

## Cross-references

- `.roadmap.hexa_rtsc` §A.2 release cadence (v1.1.0 RSC code-layer FINAL)
- `.roadmap.hexa_rtsc` §A.6 Stage-1+ hardware path (Step 1/2/3/4)
- `.roadmap.hexa_rtsc` §A.6.1 recommended A → B → C → D order
- `~/core/bedrock/docs/runnable_surface_recipe.md` — recipe SSOT
- `firmware/build/verification_matrix.md` — single-page status board
- Sister projects: `~/core/hexa-cern` (analogous Phase A→D pattern,
  reached saturation 2026-05-07)

---

This release marks the **last code-layer milestone**. v1.2.0 will polish
sim parity (B-stage extensions per §A.6 Step 3); v2.0.0 ASPIRATIONAL
requires Stage-1+ benchtop raw-data fit (`.roadmap §A.6 Step 4`).
