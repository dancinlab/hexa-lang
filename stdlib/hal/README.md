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

## Tests

- `stdlib/hal/lattice_test.hexa` — F-HAL-1/3 invariants
- `stdlib/hal/selftest_test.hexa` — module file presence

## Provenance

- Born from hexa-chip Phase C.5 pivot (2026-05-08).
- Design rationale: `~/core/hexa-chip/.roadmap.hexa_chip §A.6.2`.
- Recipe alignment: `~/core/bedrock/docs/runnable_surface_recipe.md`.
- First downstream consumer: `hexa-chip` Phase D MCU controllers.
