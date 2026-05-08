# stdlib/hal CHANGELOG

## [0.5.0] - 2026-05-08

### Added
- `backend/esp32/{gpio,i2c,spi,uart,adc}.hexa` — third hardware
  vendor backend, paper-skeleton stubs covering the canonical HW-5.
  Targets the Espressif ESP32 dual Xtensa LX6 @ 240 MHz (original).
  Each stub documents the relevant DR_REG_*_BASE (0x3FF range) +
  key register offsets:
  - `esp32/gpio.hexa`  — DR_REG_GPIO_BASE 0x3FF44000 + IO_MUX 0x3FF49000;
                         40-pin envelope (GPIO0..39) with caveats: GPIO34..39
                         input-only, GPIO6..11 reserved for SPI flash;
                         dual-bank registers (OUT/OUT1, IN/IN1) for pins ≤31
                         vs ≥32; W1TS/W1TC atomic helpers (no XOR — sw RMW).
  - `esp32/i2c.hexa`   — I2C0 0x3FF53000 / I2C1 0x3FF67000; programmable
                         16-deep command queue (RSTART/WRITE/READ/STOP/END
                         opcodes) — distinct from DesignWare-class
                         fire-and-forget FIFO; std/fast/fast-plus.
  - `esp32/spi.hexa`   — HSPI 0x3FF64000 (SPI2) + VSPI 0x3FF65000 (SPI3)
                         user-accessible; SPI0/SPI1 reserved for flash;
                         16 × 32-bit shift buffer (W0..W15); max f_spi
                         = APB_CLK = 80 MHz with CLK_EQU_SYSCLK; CPOL/CPHA
                         encoded as CK_OUT_EDGE/CK_I_EDGE per TRM matrix.
  - `esp32/uart.hexa`  — UART0/1/2 (0x3FF40000 / 0x3FF50000 / 0x3FF6E000);
                         IBRD/FBRD-style baud divisor (CLKDIV + CLKDIV_FRAG
                         /16); UART0 boot-console safety note.
  - `esp32/adc.hexa`   — SAR_ADC 0x3FF48800; 9..12-bit programmable; 8-ch
                         ADC1 (GPIO32..39) + 10-ch ADC2 (WiFi-conflicted);
                         per-channel attenuation 0/2.5/6/11 dB.

### Changed
- `numerics_sim_marker_density.hexa` (F-HAL-5 T2) `CANONICAL_VENDORS`
  now `["stm32h7", "rp2040", "esp32"]` (was `["stm32h7", "rp2040"]`).
  Vendor count = 3; expected backend stub file count = 5 × 3 = 15.
- v0.5.0 vendor list: stm32h7 (v0.2.0) + rp2040 (v0.4.0) + esp32 (this).

### Provenance
- ESP32 register addresses pulled from web-search + ESP32 Technical
  Reference Manual cross-reference (per autonomy directive web-search
  mandate). DR_REG_GPIO_BASE = 0x3FF44000 confirmed.
- IP cells: ESP32 has its own GPIO Matrix (no PrimeCell reuse), custom
  command-queue I2C, custom 80-MHz SPI master, and custom UART with
  fractional divisor.
- ESP32-S2/S3 (Xtensa LX7) and ESP32-C3/C6 (RISC-V) variants would be
  separate sub-vendors (esp32s3, esp32c3) — out of v0.5.0 scope.
- No HW physically tested; paper-skeleton parity with stm32h7 + rp2040.

## [0.4.0] - 2026-05-08

### Added
- `backend/rp2040/{gpio,i2c,spi,uart,adc}.hexa` — second hardware
  vendor backend, paper-skeleton stubs covering the canonical HW-5.
  Targets the Raspberry Pi RP2040 dual Cortex-M0+ @ 133 MHz; each
  stub documents the relevant MMIO base address, key register offsets,
  default speed/clock, and `STUB`/`TODO` markers for cross-compile
  follow-on:
  - `rp2040/gpio.hexa`  — SIO 0xD0000000, IO_BANK0 0x40014000,
                          PADS_BANK0 0x4001C000; 30-pin envelope (GP0..GP29);
                          atomic SET/CLR/XOR aliases sketched.
  - `rp2040/i2c.hexa`   — I2C0 0x40044000 / I2C1 0x40048000 (DesignWare-class IP);
                          std/fast/fast-plus speed grades (100k/400k/1M).
  - `rp2040/spi.hexa`   — SPI0 0x4003C000 / SPI1 0x40040000 (PL022 SSP IP);
                          max f_spi ≈ 62.5 MHz @ peri_clk=125 MHz; 4 SPI modes.
  - `rp2040/uart.hexa`  — UART0 0x40034000 / UART1 0x40038000 (PL011 UART IP);
                          baud-divisor formula (IBRD/FBRD); 5..8-bit word length.
  - `rp2040/adc.hexa`   — ADC 0x4004C000; 12-bit, 4 ext channels (AIN0..3
                          on GP26..29) + 1 on-die T sensor (AIN4); max 500 kSPS.

### Changed
- `numerics_sim_marker_density.hexa` (F-HAL-5 T2) made parametric over
  the registered vendor set:
  - `CANONICAL_VENDORS` array (was scalar `CANONICAL_VENDOR`) — vendors
    must appear in this list AND on disk; drift in either direction
    fails T2.
  - `check_canonical_5_per_vendor()` (was `check_canonical_5`) — verifies
    every registered vendor covers the full HW-5; total expected file
    count = 5 × |vendors|.
  - `check_stub_markers()` extended to scan all registered vendors.
  - `check_coverage_ratio()` framed as "per-vendor HW coverage" since the
    sim/HW comparison is per-vendor.

  Result: the F-HAL-5 closure stays at 67% (T1 ✓ + T2 ✓), but the T2 now
  enforces a stricter invariant — every additional vendor must ship the
  HW-5 set, otherwise sim-first is violated by partial coverage.

- v0.4.0 vendor list: stm32h7 (v0.2.0) + rp2040 (this).

### Provenance
- RP2040 register addresses + IP cell info pulled via
  web-search + RP2040 Datasheet (datasheets.raspberrypi.com/rp2040)
  cross-reference (per autonomy directive web-search mandate).
- IP cells reused: PL011 UART (UART0/1), PL022 SSP (SPI0/1),
  Synopsys DesignWare-class I2C (I2C0/1) — all standard ARM PrimeCell
  / DW peripherals; offsets match published RP2040 datasheet §4.2/§4.3/§4.4/§4.9.
- No HW physically tested; this is paper-skeleton parity with stm32h7.

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
