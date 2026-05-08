# `stdlib/hal` — n=6 Hardware Abstraction Layer

> Modular embedded peripheral library for `.hexa`. Separate-import
> convention: `use "stdlib/hal/<peripheral>"`. 12 σ-slot modules
> aligned to the n=6 lattice (σ=12, τ=4, φ=2, J₂=24).
>
> "HAL" mirrors Rust `embedded-hal` / ARM CMSIS / ST HAL convention —
> same crate-name in the embedded ecosystem.

## Quick start

```hexa
// blink LED
use "stdlib/hal/gpio"
use "stdlib/hal/core"

fn main() {
    let pin = gpio_open(13, MODE_OUTPUT)
    let mut i = 0
    while i < 10 {
        gpio_write(pin, true)
        sleep_ms(500)
        gpio_write(pin, false)
        sleep_ms(500)
        i = i + 1
    }
    gpio_report(pin)
}
```

```hexa
// umbrella import (bench / sim / test)
use "stdlib/hal/prelude"

fn main() {
    println(prelude_summary())
}
```

## Module map (12 σ-slots)

| σ | module | import path             | φ      |
|:-:|:-------|:------------------------|:-------|
| 0 | core   | stdlib/hal/core         | digital|
| 1 | gpio   | stdlib/hal/gpio         | digital|
| 2 | i2c    | stdlib/hal/i2c          | digital|
| 3 | spi    | stdlib/hal/spi          | digital|
| 4 | uart   | stdlib/hal/uart         | digital|
| 5 | adc    | stdlib/hal/adc          | analog |
| 6 | dac    | stdlib/hal/dac          | analog |
| 7 | pwm    | stdlib/hal/pwm          | digital|
| 8 | timer  | stdlib/hal/timer        | digital|
| 9 | intr   | stdlib/hal/intr         | digital|
|10 | dma    | stdlib/hal/dma          | digital|
|11 | rtc    | stdlib/hal/rtc          | digital|

10 digital + 2 analog = 12 = σ(6). σ·φ = n·τ = J₂ = 24.

## Lifecycle (τ=4 stages)

Every peripheral handle exposes:

```
configure → start → serve → report
```

mirrors embedded-hal `setup → enable → transfer → release`.

## Handle pool (J₂=24)

≤ J₂/n = 4 concurrent handles per module by default. `intr` and `dma`
extend up to J₂=24 handles (NVIC vector count + DMA channel count).

## Sim-first

Every module ships sim backend before any hardware backend. Hardware
backends (`stm32h7`, `rp2040`, `esp32`, etc.) plug in as `cfg`-flag
modules in v0.2.0+.

## Falsifier preregister

| id      | claim                                                       |
|:--------|:------------------------------------------------------------|
| F-HAL-1 | 12 modules == σ(6)                                          |
| F-HAL-2 | 4-stage τ-lifecycle per peripheral                          |
| F-HAL-3 | exact 10 digital + 2 analog = φ=2 dichotomy                 |
| F-HAL-4 | ≤ J₂/n = 4 concurrent handles per module (intr/dma extend)  |
| F-HAL-5 | sim backend before any HW backend                           |

T2 (numerical) progression — at v0.3.0 every F-HAL falsifier has a T2
script and is at 67% closure (T1 ✓ + T2 ✓):

| id      | T1                            | T2                                       | closure |
|:--------|:------------------------------|:-----------------------------------------|:-------:|
| F-HAL-1 | calc_peripherals.hexa         | numerics_module_topology.hexa            | 67%     |
| F-HAL-2 | calc_lifecycle.hexa           | numerics_lifecycle_dispatch.hexa         | 67%     |
| F-HAL-3 | calc_peripherals.hexa         | numerics_phi_dichotomy.hexa              | 67%     |
| F-HAL-4 | calc_handle_pool.hexa         | numerics_handle_dispatch.hexa            | 67%     |
| F-HAL-5 | calc_sim_first.hexa           | numerics_sim_marker_density.hexa         | 67%     |

Saturation signals: **sat-1 ✓** (every falsifier ≥ 67%), **sat-2 ✓**
(every falsifier has ≥ 1 T1 script). T3 (HW-bench) tier opens with
v0.4.0+ second hardware backend (rp2040 or esp32).

## Tests

- `stdlib/hal/lattice_test.hexa` — F-HAL-1/3 invariants
- `stdlib/hal/selftest_test.hexa` — module file presence

## Hardware backends

Per-vendor HW impls live under `stdlib/hal/backend/<vendor>/`. v0.0.1
ships sim backend only (per F-HAL-5 invariant — sim before HW).
Subsequent versions add paper-skeleton stubs for the canonical HW-5
(gpio/i2c/spi/uart/adc — every vendor must cover all 5):

- `backend/stm32h7/<peripheral>.hexa` — ST STM32H7 Cortex-M7 @ 480 MHz
  (v0.1.0–v0.2.0 — paper skeleton; real MMIO TBD).
- `backend/rp2040/<peripheral>.hexa` — Raspberry Pi RP2040 dual
  Cortex-M0+ @ 133 MHz (v0.4.0 — paper skeleton; SIO/IO_BANK0/
  PADS_BANK0 + PL011 UART + PL022 SSP + DesignWare I2C + 12-bit ADC).
- `backend/esp32/<peripheral>.hexa` — Espressif ESP32 dual Xtensa LX6
  @ 240 MHz (v0.5.0 — paper skeleton; DR_REG_*_BASE in 0x3FF range +
  GPIO Matrix + command-queue I2C + 80 MHz SPI + 9..12-bit SAR ADC).
- `backend/esp32c3/<peripheral>.hexa` — Espressif ESP32-C3 single-core
  RV32IMC RISC-V @ 160 MHz (v0.6.0 — paper skeleton; DR_REG_*_BASE in
  0x6000 range + 22-pin single-bank GPIO + same command-queue I2C +
  same SPI/UART IP as ESP32 + 12-bit fixed SAR ADC). **First RISC-V
  vendor** — validates multi-ISA-family cfg-flag dispatch.

cfg-flag dispatch in each top-level module (gpio.hexa etc.) selects
the correct backend at compile time. Sim backend is always-available
fallback. The `numerics_sim_marker_density.hexa` (F-HAL-5 T2) numerical
script enforces vendor parity: every registered vendor MUST cover the
full HW-5, otherwise T2 fails.

## Provenance

- Born from hexa-chip Phase C.5 pivot (2026-05-08).
- Design rationale: `~/core/hexa-chip/.roadmap.hexa_chip §A.6.2`.
- Recipe alignment: `~/core/bedrock/docs/runnable_surface_recipe.md`.
- First downstream consumer: `hexa-chip` Phase D MCU controllers.
