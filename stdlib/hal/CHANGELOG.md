# stdlib/hal CHANGELOG

## [0.3.0] - 2026-05-08

### Added
- `numerics_phi_dichotomy.hexa` — T2 for F-HAL-3 (φ=2 dichotomy).
  Reads each `<module>.hexa`, extracts the `let PHI_KIND` literal,
  verifies 10 digital + 2 analog with analog set == {adc, dac}.
- `numerics_handle_dispatch.hexa` — T2 for F-HAL-4 (J₂/n handle dispatch).
  Reads each module's `<m>_module_meta()` 4th field, verifies per-module
  ceilings (10×4 + 2×24), Σ = 88, envelope J₂·τ = 96 ≥ 88, default
  floor 4·σ = 48 = 2·J₂, extension factor J₂/(J₂/n) = n = 6, and
  default:extended partition isomorphism with the φ-dichotomy.
- `numerics_sim_marker_density.hexa` — T2 for F-HAL-5 (sim-first).
  Strict 12/12 sim marker check (no exemption — tighter than T1's
  ≥11/12), no backend imports in peripheral surface, exactly 1 vendor
  (stm32h7) in `backend/`, canonical HW-5 (gpio/i2c/spi/uart/adc) stubs
  with stub markers, sim ≥ HW coverage ratio, sim-marker density floor
  ≥ σ = 12 occurrences across 12 modules.

### Changed
- F-HAL-3 closure: 33% → **67%** (T1 ✓ + T2 ✓).
- F-HAL-4 closure: 33% → **67%** (T1 ✓ + T2 ✓).
- F-HAL-5 closure: 33% → **67%** (T1 ✓ + T2 ✓).
- **sat-1 milestone reached**: all 5 F-HAL falsifiers now ≥ 67% closure
  (F-HAL-1/2/3/4/5 = 67% × 5). Phase 1 RSC saturation signals on the
  HAL substrate: sat-1 ✓ + sat-2 ✓.
- `falsifier_check.hexa` registry updated: F3_T2 / F4_T2 / F5_T2
  pointed at the 3 new scripts; status block updated to v0.3.0.
- `README.md` (separate update) reflects v0.3.0 status.

### Provenance
- All 3 new scripts mirror the `numerics_module_topology.hexa` and
  `numerics_lifecycle_dispatch.hexa` (v0.2.0) pattern: hard-coded
  n=6 lattice constants + module roster + on-disk file reads + per-
  identity `_check()` calls + sentinel-suffixed verdict.
- No HW changes; the `backend/stm32h7/` tree is unchanged from v0.2.0
  (5 stubs). v0.4.0 will add a second vendor (rp2040 or esp32).

## [0.2.0] - 2026-05-08

### Added
- `numerics_module_topology.hexa` — T2 for F-HAL-1 (σ=12 geometry).
- `numerics_lifecycle_dispatch.hexa` — T2 for F-HAL-2 (τ=4 lifecycle).
- `backend/stm32h7/{i2c,spi,uart,adc}.hexa` — 4 more stm32h7 stubs (matching gpio.hexa pattern).
- README.md notes T2 progression for F-HAL-1/2.

### Changed
- F-HAL-1 closure: 33% → **67%** (T1 ✓ + T2 ✓).
- F-HAL-2 closure: 33% → **67%** (T1 ✓ + T2 ✓).
- F-HAL-3/4/5 still 33% (no T2 yet — v0.3.0+).
- sat-1 milestone partially advanced — needs F-HAL-3/4/5 T2 to fully satisfy.

## [0.1.0] - 2026-05-08

### Added
- `calc_handle_pool.hexa` — F-HAL-4 T1 (J₂/n handle ceiling).
- `calc_sim_first.hexa` — F-HAL-5 T1 (sim-before-HW invariant).
- `backend/stm32h7/gpio.hexa` — first hardware backend skeleton stub.
- README.md "Hardware backends" section.

### Changed
- F-HAL-4/5 closure: 0% → 33% (T1 ✓).
- All 5 falsifiers now register at least 1 T1 script (sat-2 satisfied).

## [0.0.1] - 2026-05-08
- Initial brainstorm scaffold.
