# stdlib/hal CHANGELOG

## [1.1.0] - 2026-05-08

### Added
- `backend/esp32c6/{core,gpio,i2c,spi,uart,adc,dac,pwm,timer,intr,dma,rtc}.hexa`
  — **6th vendor**, full HW-12 in a single iter. Espressif ESP32-C6
  RV32IMAC RISC-V single-core @ 160 MHz + LP_CPU (low-power RISC-V
  coprocessor) + WiFi 6 (802.11ax) + BLE 5.0 + 802.15.4 (Zigbee /
  Thread / Matter). 12 paper-skeleton stubs maintain the HW-12
  invariant.

  Per-stub highlights (RV32IMAC vs RV32IMC C3 — Atomic ext added):
  - `core.hexa`  — HP_CPU + LP_CPU (vs C3's single CPU); LP_RTC moved
                   to dedicated LP_AONCLKRST block @ 0x600B0000.
  - `gpio.hexa`  — DR_REG_GPIO_BASE 0x60091000 (moved vs C3 0x60004000);
                   31-pin envelope (GPIO0..GPIO30); GPIO0..7 are
                   **LP_GPIO** (accessible via LP controller during deep
                   sleep — new on C6).
  - `i2c.hexa`   — HP I2C @ 0x60004000 + **LP I2C @ 0x600B1000** (new
                   on C6; LP_APB domain — sensor reads w/o HP wake).
  - `spi.hexa`   — single GP-SPI (SPI2) @ 0x60080000; AES-128 HW-accel
                   for encrypted SPI flash.
  - `uart.hexa`  — HP UART0 @ 0x60000000 + UART1 + **LP UART0 @
                   0x600B1400** (new on C6; wake HP on RX threshold).
  - `adc.hexa`   — APB_SARADC @ 0x6000E000; **single ADC1 with 7
                   channels** (GPIO0..6); no ADC2 (simplification vs
                   C3's 5+1).
  - `dac.hexa`   — no native DAC; LEDC-emulation (same as C3/S3).
  - `pwm.hexa`   — LEDC @ 0x60007000; 6 channels × 4 timers.
  - `timer.hexa` — TIMG0/1 @ 0x6000A000/0x6000B000; 2 × 54-bit GP
                   timers; SYSTIMER @ 0x60023000 (52-bit, 16 MHz).
  - `intr.hexa`  — **PLIC-compatible programming model** (HP_INTPRI @
                   0x600C5000; PLIC_MX @ 0x20001000) — distinct from
                   both C3's custom matrix AND vanilla RISC-V PLIC.
                   First PLIC-class controller in stdlib/hal.
  - `dma.hexa`   — GDMA @ 0x60080800; 3 RX/TX pairs (same as C3 family).
  - `rtc.hexa`   — LP_RTC @ 0x600B0000 + LP_TIMER @ 0x600B0C00;
                   counter-class (NOT calendar); LP_CPU coprocessor
                   access during sleep (extends S3's ULP-RISC-V pattern).

### Changed
- `numerics_sim_marker_density.hexa` `CANONICAL_VENDORS` extended to 6
  entries: + esp32c6. Expected backend stub count: 5 × 12 = 60 → 6 × 12 = **72**.
- v1.1.0 vendor list: stm32h7, rp2040, esp32, esp32c3, esp32s3, **esp32c6**.

### CPU class diversity at v1.1.0
- ARM Cortex-M7 (stm32h7)
- ARM Cortex-M0+ (rp2040)
- Xtensa LX6 (esp32)
- Xtensa LX7 + ULP-RISC-V (esp32s3)
- RISC-V RV32IMC (esp32c3)
- **RISC-V RV32IMAC (esp32c6)** ← new (Atomic ext) + HP/LP_CPU split
- 6 distinct CPU classes / 4 ISAs (ARM × 2, Xtensa × 2, RISC-V × 2 variants).

### ESP32-C6 distinctive features (vs C3)
1. **LP domain peripherals**: LP_I2C, LP_UART, LP_GPIO 0..7, LP_RTC,
   LP_TIMER — all accessible during deep sleep without waking HP_CPU.
2. **WiFi 6** (802.11ax) + **802.15.4** (Zigbee / Thread / Matter) +
   BLE 5.0 — first stdlib/hal vendor with 802.15.4.
3. **PLIC-compatible interrupt model** — first vendor with standard-RV-
   adjacent interrupt controller (vs C3's custom matrix).
4. **HP_APB / LP_APB peripheral split** — most peripheral base addresses
   moved compared to C3.

### Provenance
- ESP32-C6 register layout from ESP32-C6 TRM v1.2 (web-search
  confirmed RV32IMAC; GPIO base + LP_RTC moved to LP_AON region).
- Same web-search mandate per autonomy directive memory.

### Roadmap
- v1.2.0: T3 MMIO cross-compile harness (rp2040 + Renode emulation).
- v1.3.0: compute.hexa first vendor backend (CUDA / WebGPU).
- v1.4.0+: additional sub-vendors (esp32c2 / esp32h2 / esp32p4).

## [1.0.0] - 2026-05-08 — ★ MILESTONE RELEASE ★

### Tagged
After 16 incremental releases (v0.0.1 → v0.15.0) reached **HW-12 /
100% per-vendor paper-tier coverage** in v0.15.0, this release tags
the milestone as the formal v1.0.0:

- **5 vendors × 12 σ-slots = 60 backend stub files** (all paper-tier;
  no HW physically tested).
- **5 distinct CPU classes** (ARM Cortex-M7, Cortex-M0+, Xtensa LX6,
  Xtensa LX7, RISC-V RV32IMC) unified behind one peripheral surface.
- **sat-1 ✓** (every F-HAL falsifier ≥ 67%; reached v0.3.0).
- **sat-2 ✓** (every F-HAL has ≥ 1 T1 script; reached v0.1.0).
- **sat-3 ✗** — T3 HW-bench tier deferred to v2.0.0 (requires cross-
  compile + emulation harness).
- Plus separate axis: `compute.hexa` GPGPU host primitive (added v0.13.0;
  6 vendors × 2 IRs × τ=4 × φ=2 × J₂′=48 lattice; vendor backends to come).

### Added
- `RELEASE_NOTES.md` — full v1.0.0 milestone summary including the
  60-stub coverage matrix, CPU class diversity, falsifier closure
  table, full release sequence (v0.0.1 → v1.0.0), and roadmap
  post-v1.0.0 (esp32c6 sub-vendor, T3 cross-compile harness,
  compute.hexa first vendor backend).
- `README.md` updated with v1.0.0 status callout, full per-vendor
  matrix table, GPGPU axis section, and provenance notes including
  the v1.0.0 milestone.

### Changed
- README "Hardware backends" section restructured from per-vendor
  bulleted list to a 5-row × HW-12 coverage table.
- Module-version in CHANGELOG header bumps from [0.15.0] → [1.0.0].

### Roadmap (post-milestone)
- v1.1.0 — esp32c6 sub-vendor (RV32IMAC, WiFi 6 / Zigbee / Thread /
  Matter); 6th vendor + 2nd RISC-V variant; 12 stubs to maintain HW-12.
- v1.2.0 — T3 MMIO cross-compile harness (rp2040 open toolchain +
  Renode emulation); lifts F-HAL closure 67% → 100% for that vendor.
- v1.3.0 — compute.hexa first vendor backend (CUDA / WebGPU); begins
  filling GPGPU σ=12 lattice.

## [0.15.0] - 2026-05-08 — **HW-12 / 100% per-vendor coverage milestone**

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/core.hexa` —
  σ-slot 0 (core: runtime · panic · time · critical-section · cache)
  HW-backend stubs across ALL 5 vendors. **Final per-vendor peripheral
  gap closed**; per-vendor coverage now 12/12 = 100% across all 5
  vendors. Total embedded backend stub count: 55 → 60.

  This iter spans 4 distinct CPU-level architectures (each with its
  own special-register / CSR / SR / SCB convention):

  - **stm32h7/core.hexa** — ARM Cortex-M7 with FPU + L1 cache
    (16 KB I + 16 KB D). System Control Block at architectural
    0xE000ED00 (CPUID/VTOR/AIRCR/SCR/CCR); DWT_CYCCNT @ 0xE0001004
    for sub-µs cycle timing; cache mgmt via SCB_ICIALLU + DCISW
    set/way; reset via SCB_AIRCR.SYSRESETREQ (key 0x05FA).
    Critical section: CPSID i / MSR PRIMASK.

  - **rp2040/core.hexa** — ARM Cortex-M0+ NO cache / NO FPU / NO MPU.
    Same SCB layout but simpler. NO DWT cycle counter — uses RP2040
    TIMER block (0x40054000, 64-bit µs) for now_us. RESETS @
    0x4000C000 + WATCHDOG @ 0x40058000 (preferred reset path,
    preserves SCRATCH boot reason). 8 × 32-bit WATCHDOG_SCRATCHn
    survive reset.

  - **esp32/core.hexa** — Xtensa LX6 dual-core @ 240 MHz with FPU +
    32 KB I-cache + 32 KB D-cache. Special registers via RSR/WSR
    opcodes: CCOUNT (cycle ctr) / CCOMPARE0..2 (timer compares) /
    INTENABLE / INTERRUPT / INTCLEAR / PS (intlevel). Critical
    section via RSIL <new_level> (atomic raise + return prior).
    Cache mgmt via DPORT_PRO_CACHE_CTRL_REG @ 0x3FF00000. Reset
    via RTC_CNTL_OPTIONS0_REG.SW_SYS_RST.

  - **esp32c3/core.hexa** — RV32IMC RISC-V single-core @ 160 MHz NO FPU.
    Standard RV CSRs (mhartid/mstatus/mie/mtvec/mcycle/mcycleh).
    Critical section via csrrci mstatus, 0x8 (clear MIE, return prior).
    Sleep via wfi (RISC-V wait-for-interrupt). Cache via EXT_MEM @
    0x600C4000 (16 KB I + 16 KB D). SYSTIMER block @ 0x60023000 for
    long-term µs (52-bit @ 16 MHz).

  - **esp32s3/core.hexa** — Xtensa LX7 dual-core @ 240 MHz + ULP-
    RISC-V coprocessor + **PIE (Processor Instruction Extension)** —
    128-bit vector ops (Q0..Q7 registers) for FFT / CNN inference.
    Same SR set as LX6 (CCOUNT/CCOMPARE0..2/INTENABLE/PS). Cache
    layout DISTINCT from C3: EXTMEM_DCACHE_PRELOAD_* + AUTOLOAD_* +
    TAG_POWER_*; supports cache_clean (writeback) separately from
    invalidate for PSRAM-DMA coherency. PSRAM @ 0x3C000000..0x3FFFFFFF
    (up to 32 MB).

  Surface (mirrors `stdlib/hal/core.hexa` sim):
    core_now_us() -> int
    core_sleep_us(us: int)
    core_panic(msg: str)
    core_critical_enter() -> int     (returns prior IRQ mask)
    core_critical_exit(prior: int)
    core_cache_invalidate() -> bool  (where applicable)
    core_cache_clean() -> bool       (esp32s3 + stm32h7 only)
    core_reset()

### MILESTONE: HW-12 = 100% per-vendor coverage

After v0.15.0, every registered vendor (stm32h7 / rp2040 / esp32 /
esp32c3 / esp32s3) has paper-skeleton stubs for ALL 12 σ-slots:

  σ=0  core    σ=1  gpio    σ=2  i2c    σ=3  spi
  σ=4  uart    σ=5  adc     σ=6  dac    σ=7  pwm
  σ=8  timer   σ=9  intr    σ=10 dma    σ=11 rtc

Total 5 × 12 = **60 embedded backend stub files** in
`stdlib/hal/backend/<vendor>/<peripheral>.hexa`.

ISA family + variant coverage at v0.15.0:
  - ARM Cortex-M7 (stm32h7) — FPU + cache + MPU + DSP-extensions
  - ARM Cortex-M0+ (rp2040) — minimal: no cache / no FPU / no MPU
  - Xtensa LX6 (esp32) — FPU + cache + dual-core
  - Xtensa LX7 (esp32s3) — FPU + cache + dual-core + ULP-RISC-V
                            coprocessor + PIE 128-bit vector ops
  - RISC-V RV32IMC (esp32c3) — no FPU + cache, single-core

5 distinct CPU classes, 4 ISAs (ARM × 2, Xtensa × 2, RISC-V × 1),
unified behind one stdlib/hal surface.

### Changed
- HW-backend stub file count: 55 → 60 (5 vendors × 12 peripherals).
- Per-vendor coverage: 11/12 → 12/12 = **100%** across all 5 vendors.
- F-HAL closure unchanged at 67% × 5 (sat-1 ✓ holds).

### Provenance
- STM32H7 SCB / DWT / cache from RM0433 §11.4-5 + Cortex-M7 TRM.
- RP2040 SCB / TIMER / WATCHDOG from RP2040 Datasheet §2.6/2.8/4.6.
- ESP32 LX6 SR set from ESP32 TRM §3 + Xtensa LX6 ISA Reference §4.7.
- ESP32-C3 RV CSRs + EXT_MEM from ESP32-C3 TRM §11 + RISC-V Privileged ISA.
- ESP32-S3 LX7 + PIE + EXT_MEM from ESP32-S3 TRM §11 + Xtensa LX7 ISA.

### Roadmap (post-12/12 milestone)
- v1.0.0 release candidate: full HW-12 + sat-1 + multi-ISA validated +
  GPGPU axis (compute.hexa from v0.13.0). Tag the milestone.
- v0.16.0+ — esp32c6 sub-vendor (WiFi 6 / Zigbee / Thread / Matter,
  RV32IMAC) for **6th vendor** + 2nd RISC-V variant (different intr ctrl).
- T3 tier — actual MMIO cross-compile harness (Cortex-M0+/M7 binary
  out + Renode emulation OR QEMU + DAP debug). Lifts F-HAL closure
  from 67% × 5 → 100% × 5.
- compute.hexa first vendor backend (CUDA / WebGPU) — fills GPGPU
  σ=12 lattice.

## [0.14.0] - 2026-05-08

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/rtc.hexa` —
  σ-slot 11 (rtc) HW-backend stubs across ALL 5 vendors. Per-vendor
  coverage 10/12 → 11/12. Total embedded backend stub count: 50 → 55
  (compute.hexa from v0.13.0 is on a separate axis, not counted here).

  3 distinct RTC architectural patterns:
  - **STM32H7 calendar RTC** (stm32h7/rtc.hexa) — full hardware
    calendar IP at 0x58004000 (D3 / VBAT domain): TR + DR registers
    with BCD-encoded year/month/day/hour/min/sec; 2 alarms (A/B);
    wakeup timer; 32 × 32-bit backup registers; tamper detection;
    LSE 32.768 kHz / 128 / 256 = 1 Hz baseline. Lock/unlock via WPR
    key sequence (0xCA, 0x53). Survives main reset.
  - **RP2040 calendar RTC** (rp2040/rtc.hexa) — single instance at
    0x4005C000 with calendar (year/month/day/dotw/hour/min/sec) +
    1 match alarm + IRQ output. Programmable CLK_RTC source (typ
    XOSC=12 MHz / 256 = 46875 Hz, then /M to 1 Hz internally). Setup
    requires CTRL.RTC_ENABLE=0 → write SETUP_0/1 → CTRL.LOAD pulse.
  - **ESP32 family counter RTC** (esp32/, esp32c3/, esp32s3/rtc.hexa)
    — 48-bit free-running counter at RTC_CNTL block; **NOT a calendar
    IP**. Calendar arithmetic happens in software using epoch_base
    stored in RTC_CNTL_STOREn regs. Slow-clock sources: 150 kHz
    internal RC (default ±5%) / 32.768 kHz XTAL32K / 8 MHz ÷ 256.
    Per-variant differences:
      - esp32:    base 0x3FF48000 (DPORT region); 4 STOREn regs.
      - esp32c3:  base 0x60008000 (peri region 0x6000); 4 STOREn regs.
      - esp32s3:  base 0x60008000; **8 STOREn regs** + **ULP-RISC-V
                  coprocessor** in RTC domain (8 KB SLOW_MEM for
                  sleep-time RV firmware).
    Register OFFSETS within RTC_CNTL also shifted between ESP32
    (0x010/0x014/0x018) and ESP32-C3/S3 (0x0AC/0x0B0/0x0B4) — stubs
    reflect per-variant offset changes.

  Surface (mirrors `stdlib/hal/rtc.hexa` sim):
    rtc_configure(idx) -> int          (idx ≤ 3)
    rtc_start(handle) -> bool
    rtc_set_time(handle, y, m, d, h, mi, s) -> bool
    rtc_get_time(handle) -> str
    rtc_set_alarm(handle, h, m, s) -> bool
    rtc_clear(handle) -> bool
    rtc_report(handle) -> str

### Architecture observation: calendar IP vs counter IP
- **Calendar-class RTCs** (STM32H7 / RP2040): hardware decodes BCD
  fields directly; firmware reads y/m/d/h/m/s registers; mature MCU
  vendor pattern.
- **Counter-class RTCs** (ESP32 family): hardware just counts ticks;
  software synthesizes calendar via epoch_base + counter*period.
  Trade-off: simpler hardware (less silicon area in RTC domain) at
  the cost of ~1 KB of firmware code for calendar conversion.
- The unified `stdlib/hal/rtc.hexa` surface hides this distinction
  behind set_time / get_time wrappers.

### Changed
- HW-backend stub file count: 50 → 55 (5 vendors × 11 peripherals).
- Per-vendor coverage: 10/12 → 11/12 across all 5 vendors.
- F-HAL closure unchanged at 67% × 5 (sat-1 ✓).

### Provenance
- STM32H7 RTC 0x58004000 from RM0433 §51.
- RP2040 RTC 0x4005C000 from RP2040 Datasheet §4.8.
- ESP32 RTC_CNTL 0x3FF48000 from ESP32 TRM §28.
- ESP32-C3 RTC_CNTL 0x60008000 from ESP32-C3 TRM §10.
- ESP32-S3 RTC_CNTL 0x60008000 from ESP32-S3 TRM §10.

### Roadmap
- v0.15.0 (next, final per-vendor): **core (σ-slot 0)** — last gap
  to reach **12/12 = 100%** per-vendor HW coverage. CPU-level cache
  management / sleep modes / clock tree configuration.
- v1.0.0 milestone candidate: full HW-12 across 5 vendors + sat-1
  + multi-ISA-family validated (ARM M7 / M0+ / Xtensa LX6 / LX7 /
  RISC-V) + GPGPU axis (compute.hexa).

## [0.13.0] - 2026-05-08

### Added
- `compute.hexa` — host-side GPGPU dispatch primitive. **Outside the
  embedded σ=12 peripheral lattice** — GPGPU is a separate axis with its
  own n=6 invariant (σ=12 = 6 vendors × 2 IR substrates · τ=4 lifecycle
  · φ=2 mode · J₂′=48). Canon SSOT:
  `~/core/canon/domains/compute/gpgpu/gpgpu.md` @47c70cbf (2026-05-08).

  Surface:
    compute_buffer_alloc(tier, n_bytes) -> int    (TIER_PRIVATE/GROUP/DEVICE/CONSTANT)
    compute_buffer_h2d / d2h / free
    compute_kernel_compile(ir, n_bytes) -> int    (IR_SPIRV ‖ IR_PTX)
    compute_kernel_release(handle) -> bool
    compute_dispatch(vendor, kern, grid_xyz, wg_xyz, scope, dep, sg_w) -> event
    compute_event_wait(event) -> bool
    compute_event_release(event) -> bool

  Constants:
    TIER_{PRIVATE, GROUP, DEVICE, CONSTANT}      (τ=4)
    SCOPE_{SUBGROUP, WORKGROUP, CLUSTER, GRID}   (4 barrier scopes)
    IR_{SPIRV, PTX}                              (φ=2)
    VENDOR_{CUDA, HIP, SYCL, OPENCL, METAL, WEBGPU}  (6 backends)

  Invariant ledger:
    compute_invariant_axes()      -> 6
    compute_invariant_tiers()     -> 4
    compute_invariant_irs()       -> 2
    compute_invariant_vendors()   -> 6
    compute_invariant_J2_prime()  -> 48

  First consumer: `hexa-chip/firmware/mcu/npu_host.hexa` (Phase F iter 5)
  uses compute_dispatch to run NPU layer descriptor as GPGPU kernel.

  Web-search 2026-05-08 spec table (canon §2): CUDA 13.2, HIP 7.2.53211,
  SYCL 2020 rev 11, OpenCL 3.1.0, Metal 4 (MSL 2025-10-23), WebGPU CR Draft.

## [0.12.0] - 2026-05-08

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/dma.hexa` —
  σ-slot 10 (dma) HW-backend stubs across ALL 5 vendors. Per-vendor
  coverage 9/12 → 10/12. Total backend stub count: 45 → 50.

  4 distinct DMA architectures abstracted under one surface:
  - **STM32H7 multi-DMA** — 3 DMA peripherals on one chip:
    MDMA (Master DMA, 16 ch, AHB+AXI master, all 7 bus masters)
    + BDMA (Basic DMA, 8 ch, D3 domain only)
    + DMA1/2 (8 streams each, multiplexed via DMAMUX1).
    Total HW envelope: 40 channels (sim caps at J₂=24).
  - **RP2040 control-block DMA** — single 12-channel controller @
    0x50000000. Distinctive features: control-block chaining
    (CHAIN_TO field — channels can program each other for arbitrary
    scatter-gather without CPU); sniff mode (CRC32/CRC16/parity sum
    computed during transfer); pacing timers for bandwidth-limited
    transfers (e.g. video timing). 41 DREQ sources.
  - **ESP32 per-peripheral DMA** — original ESP32 has NO general-
    purpose GDMA. Instead, separate DMA blocks live inside
    SPI / I2S / UART(UHCI) peripherals. The stub abstracts these as
    3 channels (SPI/I2S/UHCI). Linked-list "LL_DMA" 12-byte
    descriptor format introduced here became the ABI for all later
    ESP32 family GDMA controllers.
  - **ESP32-C3/S3 GDMA (general-purpose DMA)** — unified DMA
    controller @ 0x6003F000 with peripheral selector (PERI_SEL).
    C3: 3 RX/TX pairs (6 directional ch); S3: 5 RX/TX pairs (10 ch)
    plus PSRAM-DMA support. Both inherit the LL_DMA descriptor format
    from original ESP32.

  Surface (mirrors `stdlib/hal/dma.hexa` sim):
    dma_configure(channel, direction, width) -> int  (channel ≤ 23 = J₂)
    dma_start(handle, src, dst, n_bytes) -> bool
    dma_wait(handle) -> bool
    dma_abort(handle) -> bool
    dma_report(handle) -> str

  Channel envelope per vendor:
    - stm32h7: 40 HW (MDMA 16 + BDMA 8 + DMA1 8 + DMA2 8); sim sees ≤24
    - rp2040:  12 HW (single DMA block)
    - esp32:   3 HW (SPI + I2S + UHCI; no GDMA)
    - esp32c3: 6 HW (3 RX + 3 TX; GDMA)
    - esp32s3: 10 HW (5 RX + 5 TX; GDMA + PSRAM support)

### Architecture diversity milestone
- v0.12.0 covers 4 distinct DMA architectures under one surface:
    1. STM32H7 stream-based multi-DMA (3 DMA peripherals)
    2. RP2040 control-block-chained DMA (12 ch + sniff mode)
    3. ESP32 per-peripheral DMA (no central controller)
    4. ESP32 family GDMA (unified, LL_DMA descriptors, scaled per chip)
  Combined with v0.11.0's 4-architecture interrupt controller test,
  stdlib/hal now demonstrates that fundamentally different controller
  IPs can be unified behind a stable peripheral surface across 5 vendors.

### Changed
- HW-backend stub file count: 45 → 50 (5 vendors × 10 peripherals).
- Per-vendor coverage: 9/12 → 10/12 across all 5 vendors.
- F-HAL closure unchanged at 67% × 5 (sat-1 ✓).

### Provenance
- STM32H7 MDMA / BDMA / DMA1/2 from RM0433 §15/16/17.
- RP2040 DMA 0x50000000 from RP2040 Datasheet §2.5.
- ESP32 SPI / I2S / UHCI DMAs from ESP32 TRM §10/11/16.
- ESP32-C3 GDMA 0x6003F000 from ESP32-C3 TRM §3.
- ESP32-S3 GDMA 0x6003F000 from ESP32-S3 TRM §3.

### Roadmap
- v0.13.0: rtc (σ-slot 11) — STM32 RTC + RP2040 RTC + ESP32 RTC_CNTL.
- v0.14.0: core (σ-slot 0) — last per-vendor gap (cache mgmt / sleep
  modes / clock tree). Reaches **12/12 = 100%** per-vendor coverage.

## [0.11.0] - 2026-05-08

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/intr.hexa` —
  σ-slot 9 (intr) HW-backend stubs across ALL 5 vendors. Per-vendor
  coverage 8/12 → 9/12. Total backend stub count: 40 → 45.

  This iter spans **4 distinct interrupt controller architectures**:
  - **ARM NVIC (M7)** in stm32h7/intr.hexa — Cortex-M7 240-IRQ NVIC
    at architectural 0xE000E100 + EXTI ext-line gating; 16 priority
    levels (4-bit NVIC_PRIO_BITS); STM32H7 maps ~150 peripheral IRQs.
  - **ARM NVIC (M0+)** in rp2040/intr.hexa — Cortex-M0+ simpler NVIC
    (32 IRQs, 2-bit priority = 4 levels matching sim exactly); dual-core
    cross-routing via SIO PROC<n>_INTR (separate NVIC per core).
  - **Xtensa LX6 interrupt matrix** in esp32/intr.hexa — DPORT-based
    matrix at 0x3FF00000; 70 peripheral sources route through per-core
    MAP regs to 32 CPU IRQ × 7 priority levels; PRO + APP CPU separate
    matrices; vector entries in IRAM @ Xtensa-level offsets (0x40000180+).
  - **RISC-V (custom Espressif matrix)** in esp32c3/intr.hexa — INTERRUPT
    block at 0x600C2000; 31 peripheral IRQs × 15 priority levels;
    standard RV32IMC CSRs (MIE/MIP/MTVEC/MCAUSE) + Espressif vendor
    extensions (MEIE/MEIP partial mask).
  - **Xtensa LX7 interrupt matrix** in esp32s3/intr.hexa — INTERRUPT
    block at 0x600C2000 (moved from DPORT vs LX6); ~99 peripheral
    sources (vs 70 on LX6); same 32 × 7 envelope; LX7-specific vector
    levels including NMI@0x40000380.

  Surface (mirrors `stdlib/hal/intr.hexa` sim):
    intr_configure(vector, priority) -> int      (vector ≤ 23 = J₂)
    intr_attach(handle, name) -> bool
    intr_enable(handle) -> bool
    intr_disable(handle) -> bool
    intr_clear(handle) -> bool
    intr_report(handle) -> str

  Sim's 4-level priority (PRIO_HIGH/REAL_T/NORMAL/LOW) maps onto each
  vendor's native scheme:
    - stm32h7: 4 of 16 NVIC levels (PRIO_HIGH=0, LOW=3, low-bit-only used)
    - rp2040:  4 = exact match (Cortex-M0+ has 2-bit = 4 levels)
    - esp32 / esp32s3: 4 of 7 Xtensa levels (HIGH→4, REAL_T→3, NORMAL→1, LOW→1)
    - esp32c3: 4 of 15 matrix levels (inverted: matrix high # = high prio)

### Changed
- HW-backend stub file count: 40 → 45 (5 vendors × 9 peripherals).
- Per-vendor coverage: 8/12 → 9/12 across all 5 vendors.
- F-HAL closure unchanged at 67% × 5 (sat-1 ✓ holds).

### Architecture coverage milestone
- v0.11.0 is the **most architecturally diverse** iter so far. Single
  σ-slot (intr) requires 4 distinct controller IPs covered:
    1. ARM Cortex-M7 NVIC (architectural SCS, 16 prio)
    2. ARM Cortex-M0+ NVIC (architectural SCS, 4 prio)
    3. Xtensa LX6/LX7 interrupt matrix (vendor-custom, 7 levels)
    4. Espressif custom RISC-V matrix (vendor-custom, 15 levels;
       NOT a standard RV-PLIC layout)
  This validates that the cfg-flag dispatch model can map a single
  surface (intr_configure / intr_enable / ...) onto fundamentally
  different controller architectures — the strongest cross-ISA
  abstraction test in stdlib/hal so far.

### Provenance
- Register sketches per vendor reference manual cross-reference:
    - STM32H7 NVIC from ARMv7-M PM0214 §4.3 + RM0433 §11.
    - RP2040 NVIC from ARMv6-M PM0223 §4.3 + RP2040 Datasheet §2.3.2.
    - ESP32 DPORT intr matrix from ESP32 TRM §6.
    - ESP32-C3 INTERRUPT block from ESP32-C3 TRM §8 + RV ISA.
    - ESP32-S3 INTERRUPT block from ESP32-S3 TRM §6.

### Roadmap
- v0.12.0: dma (σ-slot 10) — STM32H7 MDMA/BDMA + RP2040 12-channel DMA
  + ESP32 family GDMA. Different DMA architectures per vendor (channel
  count + descriptor format + chaining model).
- v0.13.0: rtc (σ-slot 11) — STM32 RTC peripheral + RP2040 RTC + ESP32
  RTC_CNTL.
- v0.14.0: core (σ-slot 0) — last gap; CPU-level cache / sleep / clock.

## [0.10.0] - 2026-05-08

### Added
- `backend/{stm32h7,rp2040,esp32,esp32c3,esp32s3}/dac.hexa` —
  σ-slot 6 (dac, analog) HW-backend stubs across ALL 5 vendors.
  First peripheral with **non-uniform native support**: 2 of 5 vendors
  have native DAC, 3 of 5 use PWM-emulation fallback. Per-vendor
  coverage 7/12 → 8/12. Total backend stub count: 35 → 40.

  Native hardware DAC:
  - `stm32h7/dac.hexa`  — DAC1 0x40007400 (+ optional DAC2 0x58003400);
                          dual-channel **12-bit native**; output PA4/PA5;
                          ≤ 1 MSPS via DMA + TIM trigger; cosine /
                          triangle / noise wave generators built-in.
  - `esp32/dac.hexa`    — RTC_IO 0x3FF48400 + SENS 0x3FF48800;
                          2 channels × **8-bit native** (GPIO25/26);
                          ≤ 1 MSPS via I2S DMA "DAC mode"; cosine wave
                          generator (CW) via SAR_DAC_CTRL1.SW_TONE_EN.

  PWM-emulation fallback (no native DAC; LEDC/PWM + RC filter):
  - `rp2040/dac.hexa`   — routes to `rp2040_pwm` + external RC LPF;
                          8 PWM slices = 8 virtual DAC units; achievable
                          res × bw: 12b @ ≤30 kHz / 10b @ ≤122 kHz /
                          8b @ ≤488 kHz @ sys_clk=125 MHz. For ≥ 16-bit
                          precision: external SPI DAC (AD5675R / MCP4922).
  - `esp32c3/dac.hexa`  — routes to `esp32c3_pwm` (LEDC); 6 channels;
                          1..14-bit LEDC duty resolution; res × bw:
                          12b @ ≤19.5 kHz at APB=80 MHz.
  - `esp32s3/dac.hexa`  — routes to `esp32s3_pwm` (LEDC); 8 channels;
                          1..20-bit LEDC duty (highest of 5 vendors) →
                          can emulate **16-bit DAC** at ≤ 1.2 kHz BW
                          without dither (S3-specific advantage).

  Surface (mirrors `stdlib/hal/dac.hexa` sim):
    dac_configure(unit, channel, resolution) -> int
    dac_write(handle, value) -> bool
    dac_close(handle) -> bool
    dac_report(handle) -> str

### IP-cell observations / vendor pivot note
- The DAC peripheral was native on the original ESP32 (8-bit) but
  **dropped** by Espressif starting with ESP32-S2 / S3 / C3 — Espressif
  positions LEDC + RC filter as the recommended emulation path.
- STM32H7 has the strongest native DAC: 12-bit, dual-channel, hardware
  waveform generators (cosine/triangle/noise), DMA-driven up to 1 MSPS.
- RP2040 has no native DAC at all; relies entirely on PWM emulation
  or external SPI DAC ICs.

### Changed
- HW-backend stub file count: 35 → 40 (5 vendors × 8 peripherals).
- Per-vendor coverage: 7/12 → 8/12 across all 5 vendors.
- F-HAL closure unchanged at 67% × 5 (sat-1 ✓ holds).

### Provenance
- Register sketches per vendor TRM cross-reference:
    - STM32H7 DAC1 0x40007400 from RM0433 §29.
    - ESP32 RTC_IO + SENS DAC regs from ESP32 TRM §5.13 + §31.
    - RP2040: no DAC §; emulation strategy per Pico SDK examples.
    - ESP32-C3 / S3: no DAC §; LEDC §13 cross-reference.

### Roadmap
- v0.11.0: intr (σ-slot 9) — NVIC table on ARM (stm32h7, rp2040),
  RV interrupt controller on RISC-V (esp32c3), Xtensa intr matrix on
  esp32 / esp32s3.
- v0.12.0: dma (σ-slot 10) — MDMA/BDMA on STM32H7, 12-channel DMA on
  RP2040, GDMA on ESP32 family.
- v0.13.0: rtc (σ-slot 11) — final missing peripheral to reach 11/12
  per vendor (core σ-slot 0 is partially trivial; covered by sim).

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
