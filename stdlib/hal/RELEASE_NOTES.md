# stdlib/hal v1.0.0 — Release Notes

**Release date:** 2026-05-08
**Latest commit at release:** see CHANGELOG `[1.0.0]` section
**Previous version:** v0.15.0 (HW-12 milestone reached)
**Repo path:** `~/core/hexa-lang/stdlib/hal/`

---

## ★ Milestone — HW-12 / 100% per-vendor paper-tier coverage ★

After 16 incremental releases (v0.0.1 → v0.15.0) on a single date,
stdlib/hal reaches its first major milestone: **every registered
vendor has a paper-skeleton HW backend stub for every σ-slot in the
n=6 lattice**.

### Coverage matrix

|  σ  | peripheral | stm32h7 | rp2040 | esp32 | esp32c3 | esp32s3 |
|:---:|:-----------|:-------:|:------:|:-----:|:-------:|:-------:|
|  0  | core       | ✓       | ✓      | ✓     | ✓       | ✓       |
|  1  | gpio       | ✓       | ✓      | ✓     | ✓       | ✓       |
|  2  | i2c        | ✓       | ✓      | ✓     | ✓       | ✓       |
|  3  | spi        | ✓       | ✓      | ✓     | ✓       | ✓       |
|  4  | uart       | ✓       | ✓      | ✓     | ✓       | ✓       |
|  5  | adc        | ✓       | ✓      | ✓     | ✓       | ✓       |
|  6  | dac        | ✓ (12b) | ⚙ (PWM)| ✓ (8b)| ⚙ (LEDC)| ⚙ (LEDC)|
|  7  | pwm        | ✓       | ✓      | ✓     | ✓       | ✓       |
|  8  | timer      | ✓       | ✓      | ✓     | ✓       | ✓       |
|  9  | intr       | ✓       | ✓      | ✓     | ✓       | ✓       |
| 10  | dma        | ✓       | ✓      | ✓     | ✓       | ✓       |
| 11  | rtc        | ✓       | ✓      | ✓     | ✓       | ✓       |

✓ = native HW backend stub. ⚙ = emulation-fallback note (PWM + RC
filter or LEDC + RC; firmware indistinguishable from native via
unified surface).

**Total: 60 backend stub files.**

### CPU class diversity

5 distinct CPU classes / 4 ISAs / 1 stdlib/hal surface:

- **ARM Cortex-M7** (stm32h7) — FPU + cache (16 KB I + 16 KB D) + MPU + DSP-ext
- **ARM Cortex-M0+** (rp2040)  — minimal: no cache, no FPU, no MPU; dual-core
- **Xtensa LX6**     (esp32)    — FPU + cache (32 KB I + 32 KB D); dual-core
- **Xtensa LX7**     (esp32s3)  — + ULP-RISC-V coprocessor + PIE 128-bit vector
- **RISC-V RV32IMC** (esp32c3)  — no FPU + cache (16 KB I + 16 KB D); single-core

### Architecture diversity at peripheral level

Two iters in a row (v0.11.0 intr + v0.12.0 dma) demonstrated 4 distinct
controller IP families per σ-slot, all unified behind a single
surface:

- **intr** (v0.11.0): ARM NVIC (M7) / ARM NVIC (M0+) / Xtensa LX6+LX7 matrix /
  Espressif RISC-V matrix
- **dma**  (v0.12.0): STM32 multi-DMA (40 ch across 3 IPs) / RP2040 control-block
  (12 ch + sniff) / ESP32 per-peripheral / ESP32 family GDMA

Plus DAC (v0.10.0) demonstrated unified handling of native vs
emulation-fallback — sim → firmware code is identical.

---

## Falsifier closure at v1.0.0

| F-HAL | claim                                                | T1 | T2 | T3 | closure |
|:------|:-----------------------------------------------------|:--:|:--:|:--:|:-------:|
| 1     | 12 modules == σ(6)                                   | ✓  | ✓  | ✗  | 67%     |
| 2     | 4-stage τ-lifecycle per peripheral                   | ✓  | ✓  | ✗  | 67%     |
| 3     | exact 10 digital + 2 analog = φ=2 dichotomy          | ✓  | ✓  | ✗  | 67%     |
| 4     | ≤ J₂/n = 4 concurrent handles (intr/dma extend)      | ✓  | ✓  | ✗  | 67%     |
| 5     | sim backend before any HW backend                    | ✓  | ✓  | ✗  | 67%     |

**Saturation signals:**
- **sat-1** (every falsifier ≥ 67%) ✓ — reached at v0.3.0 (commit `fc2eeb2f`)
- **sat-2** (every falsifier has ≥ 1 T1 script) ✓ — reached at v0.1.0
- **sat-3** (T3 HW-bench tier) ✗ — out of v1.0.0 scope; needs cross-compile
  + emulation harness

T3 (HW-bench) tier intentionally deferred to v2.0.0+:
- Requires actual cross-compile (Cortex-M0+/M7 binary out + Renode
  emulation OR QEMU + DAP debug)
- Lifts F-HAL closure 67% × 5 → 100% × 5
- Out-of-scope for paper-tier v1.0 release

---

## Separate axis at v1.0.0 — GPGPU host primitive

`stdlib/hal/compute.hexa` (added v0.13.0) — host-side GPGPU dispatch
on a separate axis with its own n=6 invariant:

```
σ=12 = 6 vendors × 2 IR substrates  ·  τ=4 lifecycle  ·  φ=2 mode  ·  J₂′=48
```

- `VENDOR_{CUDA, HIP, SYCL, OPENCL, METAL, WEBGPU}` (6 backends)
- `IR_{SPIRV, PTX}` (2 IR substrates)
- `TIER_{PRIVATE, GROUP, DEVICE, CONSTANT}` (4 memory tiers, τ=4)
- `SCOPE_{SUBGROUP, WORKGROUP, CLUSTER, GRID}` (4 barrier scopes)

First consumer: `hexa-chip/firmware/mcu/npu_host.hexa` (Phase F iter 5).
Vendor backends (cuda/hip/sycl/opencl/metal/webgpu) deferred — fills
GPGPU σ=12 lattice in v1.1.0+.

---

## Release sequence (v0.0.1 → v1.0.0, 2026-05-08)

| version  | commit       | content                                                     |
|:---------|:-------------|:------------------------------------------------------------|
| v0.0.1   | `5c39418e`   | 12 module skeletons + prelude + 2 tests + README            |
| v0.1.0   | `58b83d1c`   | calc_handle_pool + calc_sim_first + stm32h7 gpio stub       |
| v0.2.0   | `b115d3a4`   | numerics_module_topology + lifecycle_dispatch + 4 stm32h7   |
| v0.3.0   | `fc2eeb2f`   | F-HAL-3/4/5 T2 numerics → **sat-1 reached**                 |
| v0.4.0   | `87eed3d2`   | rp2040 second HW backend (5 stubs)                          |
| v0.5.0   | `651f8d63`   | esp32 third HW backend (5 stubs)                            |
| v0.6.0   | `777f9827`   | esp32c3 fourth HW backend — **first RISC-V vendor**         |
| v0.7.0   | `c0109d49`   | esp32s3 fifth HW backend (Xtensa LX7 + ULP-RISC-V + PIE)    |
| v0.8.0   | `93ac6a6f`   | timer (σ-slot 8) — **first peripheral-axis expansion**      |
| v0.9.0   | `2da1da75`   | pwm (σ-slot 7) across 5 vendors                             |
| v0.10.0  | `ef992c84`   | dac (σ-slot 6) — first non-uniform native HW peripheral     |
| v0.11.0  | `56b5f003`   | intr (σ-slot 9) — most architecturally diverse iter (4 IPs) |
| v0.12.0  | `6c25d420`   | dma (σ-slot 10) — 4 distinct DMA architectures              |
| v0.13.0  | `ba859275`   | compute.hexa GPGPU host primitive (separate axis)           |
| v0.14.0  | `bc010243`   | rtc (σ-slot 11) — calendar-IP vs counter-IP split           |
| v0.15.0  | `a7993e77`   | core (σ-slot 0) — **HW-12 milestone** ★                     |
| **v1.0.0**| (this release) | **★ MILESTONE: 60 stubs, 5 CPU classes, 4 ISAs**          |

---

## Roadmap post-v1.0.0

1. **v1.1.0** — esp32c6 sub-vendor (RV32IMAC, WiFi 6 + Zigbee + Thread + Matter).
   6th vendor + 2nd RISC-V variant. Will need 12 stubs to maintain HW-12.

2. **v1.2.0** — T3-tier MMIO cross-compile harness for one vendor (likely
   rp2040 — open toolchain via arm-none-eabi-gcc + Renode emulation). Lifts
   F-HAL closure for that vendor 67% → 100%.

3. **v1.3.0** — compute.hexa first vendor backend (CUDA via NVRTC stub OR
   WebGPU via wgpu-native). Begins filling GPGPU σ=12 lattice.

4. **v1.4.0+** — additional sub-vendors (esp32c2 / esp32h2 / nrf52 / kendryte k210).

5. **v2.0.0** (aspirational) — actual MMIO real-hardware verification (real
   STM32H7 board / Pico board / ESP32 dev board). Lifts sat-3 to ✓.

---

## Provenance

- Born from `hexa-chip` Phase C.5 pivot (2026-05-08).
- Design rationale: `~/core/hexa-chip/.roadmap.hexa_chip §A.6.2`.
- Recipe alignment: `~/core/bedrock/docs/runnable_surface_recipe.md`.
- All register addresses + IP cell info pulled via web-search +
  vendor TRM cross-reference (per autonomy directive web-search mandate
  in agent memory).
- All 60 backend stub files are paper-tier — no HW physically tested
  at v1.0.0.

## License

Same as the parent `hexa-lang` repository.
