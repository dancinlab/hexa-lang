# stdlib/hal CHANGELOG

## [0.9.0] - 2026-05-08

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/pwm.hexa` —
  σ-slot 7 (pwm) HW-backend stubs added for ALL 5 vendors. Per-vendor
  coverage moves from 6/12 → 7/12. Total backend stub count: 30 → 35.
  - `stm32h7/pwm.hexa`  — TIM-PWM via TIM1/8 advanced (complementary +
                          dead-time + break) and TIM2/3 GP; PWM mode 1/2
                          via CCMRn.OCxM; freq = TIMCLK/((PSC+1)·(ARR+1));
                          duty = CCRn / (ARR+1).
  - `rp2040/pwm.hexa`   — dedicated PWM block at 0x40050000; 8 slices ×
                          2 channels (A/B) = 16 PWM outputs; 8.4-bit
                          fractional divider; freq range ~7 Hz .. ~10 MHz.
  - `esp32/pwm.hexa`    — LEDC at 0x3FF59000; 16 channels (8 HS + 8 LS) ×
                          8 timers (4 HS + 4 LS); 1..20-bit duty; MCPWM
                          motor-control out of scope.
  - `esp32c3/pwm.hexa`  — LEDC at 0x60019000; 6 channels × 4 timers
                          (smaller than ESP32; no HS/LS split); 1..14-bit duty.
  - `esp32s3/pwm.hexa`  — LEDC at 0x60019000; 8 channels × 4 timers;
                          1..20-bit duty.

  Surface (mirrors `stdlib/hal/pwm.hexa` sim):
    pwm_configure(gen, channel, freq_hz) -> int
    pwm_start(handle) / pwm_stop(handle) -> bool
    pwm_set_duty(handle, duty_x100) -> bool   (0..10000 = 0..100.00%)
    pwm_set_freq(handle, freq_hz) -> bool
    pwm_report(handle) -> str

  Each stub correctly maps the σ-slot 7 sim handle calculation
  (gen × 12 + channel) to vendor-specific channel limits:
    - stm32h7: 4 generators (TIM1/8/2/3) × 4 channels = 16 outputs.
    - rp2040:  8 slices × 2 (A/B)        = 16 outputs.
    - esp32:   8 HS channels × 1         = 8  (with 8 more LS available).
    - esp32c3: 6 channels  × 1           = 6.
    - esp32s3: 8 channels  × 1           = 8.

### Changed
- HW-backend stub file count: 30 → 35 (5 vendors × 7 peripherals).
- Per-vendor peripheral coverage: 6/12 → 7/12 across all 5 vendors.
- F-HAL closure unchanged at 67% × 5 (sat-1 ✓ holds).

### IP-cell observations
- STM32H7: PWM is a TIM mode (no separate IP) — same register cluster
  as timer.hexa backend, different OCxM bit-pattern.
- RP2040: dedicated PWM block (separate from TIMER block); cleaner
  decoupling but consumes its own MMIO region.
- ESP32 family: LEDC (LED PWM Controller) + MCPWM (Motor Control PWM)
  are 2 distinct IPs; this stub covers LEDC only — MCPWM would be a
  separate σ-slot extension if added.

### Provenance
- Register sketches from each vendor's reference manual via web-search
  + training data cross-reference (per autonomy directive web-search
  mandate). Base addresses confirmed:
    - STM32H7 TIM1/8/2/3 from RM0433 §39/40.
    - RP2040 PWM 0x40050000 from RP2040 Datasheet §4.5.
    - ESP32 LEDC 0x3FF59000 from ESP32 TRM §13.
    - ESP32-C3 LEDC 0x60019000 from ESP32-C3 TRM §13.
    - ESP32-S3 LEDC 0x60019000 from ESP32-S3 TRM §13.

### Roadmap
- v0.10.0 candidate: dac (σ-slot 6) — STM32H7 + ESP32 have native
  hardware DAC; rp2040 + ESP32-C3 + ESP32-S3 use PWM + RC filter
  emulation. Stubs will document the fallback path.
- v0.11.0 candidate: intr (σ-slot 9), dma (σ-slot 10), rtc (σ-slot 11)
  — last 3 missing peripherals to reach 12/12 per vendor.
- v0.12.0 candidate: esp32c6 sub-vendor (WiFi 6 / Zigbee / Thread, RV32IMAC).

## [0.8.0] - 2026-05-08

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/timer.hexa` —
  σ-slot 8 (timer) HW-backend stubs added for ALL 5 registered
  vendors simultaneously. First **peripheral-axis expansion** in
  the backend tree (prior iters expanded the vendor axis); per-vendor
  coverage moves from 5/12 (HW-5 only) to 6/12 across all 5 vendors.
  - `stm32h7/timer.hexa` — TIM2 0x40000000 + TIM3 0x40000400 + TIM6
                            0x40001000 + TIM1 0x40010000 (selected
                            representatives from 16 timers in H7).
                            APB_TIM=200 MHz; period = (PSC+1)·(ARR+1)/200.
  - `rp2040/timer.hexa`  — TIMER 0x40054000 (single instance, 4 alarms,
                            64-bit µs counter; tick = 1 µs; never wraps
                            in realistic time).
  - `esp32/timer.hexa`   — TIMG0 0x3FF5F000 + TIMG1 0x3FF60000
                            (4 × 64-bit GP timers across 2 groups).
  - `esp32c3/timer.hexa` — TIMG0 0x6001F000 + TIMG1 0x60020000
                            (2 × 54-bit GP timers; smaller than ESP32).
  - `esp32s3/timer.hexa` — TIMG0 0x6001F000 + TIMG1 0x60020000
                            (4 × 54-bit GP timers; same family as ESP32-C3).

  Surface (mirrors `stdlib/hal/timer.hexa` sim):
    timer_configure(idx, mode, period_us) -> int
    timer_start(handle) -> bool
    timer_stop(handle)  -> bool
    timer_now_ticks(handle) -> int
    timer_set_callback(handle, period_us) -> bool
    timer_clear(handle) -> bool
    timer_report(handle) -> str

  4 modes per sim convention: ONESHOT / PERIODIC / CAPTURE / PWM.
  ≤ 4 timer handles per process (matches J₂/n = 4 default ceiling).

### Changed
- HW-backend stub file count: 25 (5 vendors × HW-5) → 30 (5 × 6 stubs).
- Per-vendor peripheral coverage: 5/12 → 6/12 across all 5 vendors.
- The numerics_sim_marker_density.hexa F-HAL-5 T2 ENFORCES that every
  registered vendor covers the canonical HW-5; timer is **outside**
  the canonical HW-5 set, so the stubs are documentation-tier
  additions that expand the per-vendor footprint without changing
  the falsifier-bound invariant. F-HAL closure unchanged at 67% × 5.

### ISA / vendor coverage retained
- All 5 vendors (stm32h7, rp2040, esp32, esp32c3, esp32s3) covered
  uniformly. The 4 distinct CPU classes (ARM Cortex-M7, ARM Cortex-M0+,
  Xtensa LX6, Xtensa LX7+ULP-RISC-V, RISC-V RV32IMC) all gain timer
  support in this iter.

### Provenance
- Register sketches pulled from each vendor's reference manual /
  datasheet via web-search + training data cross-reference (per
  autonomy directive web-search mandate). Base addresses confirmed:
    - STM32H7 TIM2/3/6/1 from RM0433 §39/40/43.
    - RP2040 TIMER 0x40054000 from RP2040 Datasheet §4.6.
    - ESP32 TIMG0/1 0x3FF5F000/0x3FF60000 from ESP32 TRM §17.
    - ESP32-C3 TIMG0/1 0x6001F000/0x60020000 from ESP32-C3 TRM §15.
    - ESP32-S3 TIMG0/1 0x6001F000/0x60020000 from ESP32-S3 TRM §15.
- IP cells: STM32H7 has the most varied (TIM advanced/general/basic);
  RP2040 has a single distinctive 64-bit-counter+4-alarm IP; the
  3 ESP32 family chips share the same Timer Group IP cell scaled per
  variant (4 × 64-bit on ESP32, 2 × 54-bit on C3, 4 × 54-bit on S3).

### Roadmap
- v0.9.0 candidate: extend to dac/pwm/intr/dma/rtc — picking 1 peripheral
  per iter × 5 vendors. Next likely target: pwm (motor / LED control,
  universally supported).
- v1.0.0 candidate: complete per-vendor HW-12 coverage AND first T3-tier
  cross-compile (Cortex-M0+ binary for rp2040 with Renode emulation).

## [0.7.0] - 2026-05-08

### Added
- `backend/esp32s3/{gpio,i2c,spi,uart,adc}.hexa` — fifth hardware
  vendor backend. Espressif ESP32-S3 Xtensa LX7 dual-core @ 240 MHz +
  ULP-RISC-V coprocessor + AI vector accelerator + USB-OTG.
  Peripheral region 0x6000xxxx (same family as C3; not the 0x3FF
  range of original ESP32).
  - `esp32s3/gpio.hexa`  — DR_REG_GPIO_BASE 0x60004000 + IO_MUX 0x60009000;
                           45-pin envelope (GPIO0..21 + GPIO26..48; gap at
                           22..25 reserved for flash/PSRAM); dual-bank
                           (OUT/OUT1, IN/IN1, ENABLE/ENABLE1); GPIO19/20
                           = USB-OTG D-/D+.
  - `esp32s3/i2c.hexa`   — I2C0 0x60013000 / I2C1 0x60027000; same
                           command-queue architecture as ESP32 / C3.
  - `esp32s3/spi.hexa`   — SPI2 0x60024000 / SPI3 0x60025000 (both
                           user-accessible; SPI0/1 reserved for flash+PSRAM);
                           same 16 × 32-bit shift buffer; max 80 MHz.
  - `esp32s3/uart.hexa`  — UART0/1/2 (0x60000000 / 0x60010000 / 0x6002E000);
                           same fractional divisor as ESP32 family;
                           built-in USB-Serial-JTAG on GPIO19/20.
  - `esp32s3/adc.hexa`   — APB_SARADC 0x60040000; 12-bit fixed; ADC1
                           10-ch (GPIO1..10) + ADC2 10-ch (GPIO11..20);
                           **no WiFi conflict on S3** (improvement vs ESP32).

### Changed
- `numerics_sim_marker_density.hexa` `CANONICAL_VENDORS` now 5 entries
  (stm32h7, rp2040, esp32, esp32c3, esp32s3). Expected backend stub
  count = 5 × 5 = 25.
- v0.7.0 vendor list: + esp32s3 (this).

### ISA family + variant coverage milestone
- v0.7.0 introduces the **second Xtensa variant** (LX7 vs LX6). Vendors
  now span 4 distinct CPU classes:
    - ARM Cortex-M7 (stm32h7)
    - ARM Cortex-M0+ (rp2040)
    - Xtensa LX6 (esp32)
    - Xtensa LX7 + ULP-RISC-V (esp32s3) ← new
    - RISC-V RV32IMC (esp32c3)
  ESP32-S3 is notable as the first vendor with a **secondary ULP
  coprocessor** (ULP-RISC-V) — opens a v1.0+ design question of
  whether ULP-class peripherals deserve their own σ-slot extension.

### Provenance
- ESP32-S3 register addresses confirmed via web-search + ESP32-S3 TRM.
  GPIO_BASE = 0x60004000 (matches C3 — same peri region; offsets
  differ per peripheral type/count).
- Pin envelope: 45 pins (GPIO0..21 + GPIO26..48, gap at 22..25).
- IP cells: GPIO Matrix S3-specific (45 pins, dual-bank); I2C / SPI /
  UART / SAR ADC IP cells reused from ESP32 family with bus / ch
  count adjustments.
- ULP-RISC-V coprocessor + AI accelerator + USB-OTG noted but their
  HW backends are out of v0.7.0 scope (would extend σ-slot table).

## [0.6.0] - 2026-05-08

### Added
- `backend/esp32c3/{gpio,i2c,spi,uart,adc}.hexa` — fourth hardware
  vendor backend; **first RISC-V** target in stdlib/hal (earlier
  vendors were all Xtensa LX6 or ARM Cortex-M). Espressif ESP32-C3
  RV32IMC single-core @ 160 MHz; peripheral region 0x6000xxxx
  (vs ESP32 Xtensa's 0x3FFxxxxx range — distinct memory map).
  - `esp32c3/gpio.hexa`  — DR_REG_GPIO_BASE 0x60004000 + IO_MUX 0x60009000;
                           22-pin envelope (single bank, no dual-bank
                           split; vs ESP32 40-pin); GPIO0..5=ADC1,
                           GPIO12..17=flash reserved, GPIO18..19=USB-JTAG.
  - `esp32c3/i2c.hexa`   — single I2C0 0x60013000 (vs ESP32 dual);
                           same command-queue architecture (16-deep);
                           FIFO depth 32.
  - `esp32c3/spi.hexa`   — single GP-SPI (SPI2) 0x60024000 (vs ESP32
                           dual HSPI/VSPI); same 16×32-bit shift buffer;
                           max 80 MHz with CLK_EQU_SYSCLK.
  - `esp32c3/uart.hexa`  — UART0/1 (0x60000000 / 0x60010000); same
                           CLKDIV+CLKDIV_FRAG fractional divisor as ESP32;
                           UART0 boot console; built-in USB-Serial-JTAG
                           bridge on GPIO18/19 (separate IP, out of scope).
  - `esp32c3/adc.hexa`   — APB_SARADC 0x60040000; 12-bit fixed (vs ESP32
                           9..12-bit programmable); ADC1 5-ch (GPIO0..4)
                           + ADC2 1-ch (GPIO5); **no WiFi conflict on C3**
                           (unlike ESP32's ADC2).

### Changed
- `numerics_sim_marker_density.hexa` (F-HAL-5 T2) `CANONICAL_VENDORS`
  now `["stm32h7", "rp2040", "esp32", "esp32c3"]` (was 3 vendors).
  Vendor count = 4; expected backend stub file count = 5 × 4 = 20.
- v0.6.0 vendor list: stm32h7 (v0.2.0) + rp2040 (v0.4.0) + esp32
  (v0.5.0) + esp32c3 (this).

### ISA family coverage milestone
- v0.6.0 is the **first multi-ISA-family** release of stdlib/hal.
  Vendors now span:
    - ARM Cortex-M7 (stm32h7)
    - ARM Cortex-M0+ (rp2040)
    - Xtensa LX6 (esp32)
    - **RISC-V RV32IMC (esp32c3)** ← new
  This validates the cfg-flag dispatch model across CPU ISAs, not just
  vendors — a peripheral surface (e.g. `gpio_write(pin, val)`) now
  resolves to ARM, Xtensa, OR RISC-V backend at compile time without
  any change to the consumer code.

### Provenance
- ESP32-C3 register addresses + memory map confirmed via
  ESP32-C3 Technical Reference Manual cross-reference (per autonomy
  directive web-search mandate). DR_REG_GPIO_BASE = 0x60004000.
- IP cells: GPIO Matrix is C3-specific (smaller pin count → single bank);
  I2C / SPI / UART / SAR ADC IP cells are reused from ESP32 family with
  smaller bus / peripheral counts.
- Future ESP32 sub-vendors (esp32s2, esp32s3, esp32c6, esp32h2) would
  follow the same naming convention — out of v0.6.0 scope.

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
