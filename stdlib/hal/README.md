# `stdlib/hal` — n=6 Hardware Abstraction Layer

> Modular embedded peripheral library for `.hexa`. Separate-import
> convention: `use "stdlib/hal/<peripheral>"`. 12 σ-slot modules
> aligned to the n=6 lattice (σ=12, τ=4, φ=2, J₂=24).
>
> "HAL" mirrors Rust `embedded-hal` / ARM CMSIS / ST HAL convention —
> same crate-name in the embedded ecosystem.
>
> **Status: v1.0.0** (2026-05-08) — HW-12 / 100% per-vendor paper-tier
> coverage milestone. 5 vendors × 12 σ-slots = 60 backend stubs;
> 5 distinct CPU classes (ARM Cortex-M7 / Cortex-M0+ / Xtensa LX6 / LX7 /
> RISC-V RV32IMC) unified behind one peripheral surface. See
> [`RELEASE_NOTES.md`](RELEASE_NOTES.md).

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
ships sim backend only (per F-HAL-5 invariant — sim before HW). v1.0.0
reaches **HW-12 / 100% per-vendor coverage** — all 5 registered vendors
have paper-skeleton stubs for ALL 12 σ-slots:

| vendor   | CPU                              | clock     | HW-12 | first cut | notes                                 |
|:---------|:---------------------------------|:----------|:------|:----------|:--------------------------------------|
| stm32h7  | ARM Cortex-M7 + FPU + L1 cache   | 480 MHz   | ✓     | v0.1.0    | DSP-ext; MPU; TIM-PWM via OCxM        |
| rp2040   | ARM Cortex-M0+ × 2               | 133 MHz   | ✓     | v0.4.0    | no cache / no FPU / no MPU; PIO blocks|
| esp32    | Xtensa LX6 × 2 + FPU + cache     | 240 MHz   | ✓     | v0.5.0    | command-queue I2C; LEDC PWM; native DAC|
| esp32c3  | RV32IMC (RISC-V)                 | 160 MHz   | ✓     | v0.6.0    | first RISC-V vendor; standard CSRs    |
| esp32s3  | Xtensa LX7 + ULP-RISC-V + PIE    | 240 MHz   | ✓     | v0.7.0    | 128-bit vector ops; PSRAM ≤ 32 MB     |

5 × 12 = **60 backend stubs**. cfg-flag dispatch in each top-level
module (gpio.hexa etc.) selects the correct backend at compile time;
sim backend is always-available fallback.

Per-σ-slot release sequence:
- v0.1.0 → v0.7.0 — vendor axis (stm32h7 → rp2040 → esp32 → esp32c3 → esp32s3)
- v0.8.0 — peripheral axis open: timer (σ=8) across all 5 vendors
- v0.9.0 — pwm (σ=7); v0.10.0 — dac (σ=6, 2 native + 3 PWM-emul);
- v0.11.0 — intr (σ=9); v0.12.0 — dma (σ=10); v0.14.0 — rtc (σ=11);
- v0.15.0 — core (σ=0) → **HW-12 milestone** ✓

The `numerics_sim_marker_density.hexa` (F-HAL-5 T2) numerical script
enforces vendor parity: every registered vendor MUST cover the canonical
HW-5 (gpio/i2c/spi/uart/adc), otherwise T2 fails. The full HW-12
coverage is documentation-tier (additive beyond F-HAL-5's strict floor).

## GPGPU axis (separate from σ=12 peripheral lattice)

`stdlib/hal/compute.hexa` (added v0.13.0) — host-side GPGPU dispatch
primitive on a **separate axis** with its own n=6 invariant:

```
σ=12 = 6 vendors × 2 IR substrates · τ=4 lifecycle · φ=2 mode · J₂′=48
```

- `VENDOR_{CUDA, HIP, SYCL, OPENCL, METAL, WEBGPU}` (6 backends)
- `IR_{SPIRV, PTX}` (φ=2 IR substrates)
- `TIER_{PRIVATE, GROUP, DEVICE, CONSTANT}` (τ=4 memory tiers)
- `SCOPE_{SUBGROUP, WORKGROUP, CLUSTER, GRID}` (4 barrier scopes)

First consumer: `hexa-chip/firmware/mcu/npu_host.hexa` (Phase F iter 5).

## Provenance

- Born from hexa-chip Phase C.5 pivot (2026-05-08).
- Design rationale: `~/core/hexa-chip/.roadmap.hexa_chip §A.6.2`.
- Recipe alignment: `~/core/bedrock/docs/runnable_surface_recipe.md`.
- First downstream consumer: `hexa-chip` Phase D MCU controllers.
- v1.0.0 milestone: HW-12 / 100% paper-tier coverage achieved 2026-05-08.
