# stdlib/hal — T3 (HW-bench) tier scaffold

> Paper-tier scaffold for the F-HAL T3 (HW-bench) closure tier.
> v1.2.0 lays the groundwork; actual Renode-run log capture is
> deferred to a future iter (when arm-none-eabi-gcc + Renode are
> available in the dev env).

## Why a separate t3/ directory?

T1 (algebraic) and T2 (numerical / on-disk fixture) are pure-source
tiers — they verify invariants from `.hexa` source code reads. T3
(HW-bench) requires actually **running** code — either on real
hardware OR in an emulator that exercises the MMIO accesses the
backend stubs document.

stdlib/hal v1.0.0 reached **67% × 5** F-HAL closure (T1 ✓ + T2 ✓ ×
all 5 falsifiers; sat-1 ✓). Lifting closure to 100% × 5 requires
T3 — **execute the cfg-flag-dispatched HW backend in a target
environment and assert the documented MMIO behavior matches
reality**.

## Vendor target for v1.2.0

**rp2040** is the chosen first vendor for T3 because:

1. **Open toolchain** — `arm-none-eabi-gcc` (free, no licence).
2. **No NDA / no PDK** — datasheet + Pico SDK are public-domain.
3. **Renode supports rp2040** — full SoC platform model ships
   in upstream Renode releases since 2024.
4. **Cortex-M0+ is the simplest core** of the 5 vendors (no
   cache / no FPU / no MPU) — minimal harness scaffolding.

Other vendors will follow:
- v1.3.0+: stm32h7 (also arm-none-eabi-gcc; STM32CubeMX scaffolding).
- v1.4.0+: esp32 family (xtensa-esp-elf-gcc + ESP-IDF + QEMU).

## Files in this directory (rp2040 path)

```
stdlib/hal/t3/
├── README.md                        # this file
├── Makefile.rp2040                  # arm-none-eabi-gcc build recipe
├── linker_rp2040.ld                 # minimal linker script
├── boot_rp2040.s                    # ARMv6-M vector table + reset
├── harness_main.c                   # T3 harness — exercises GPIO + UART
├── renode_rp2040.resc               # Renode platform + log capture
└── numerics_t3_rp2040_scaffold.hexa # T3 scaffold-presence check
```

## T3 closure roadmap (per recipe §3 closure-pct)

T3 itself splits into 2 sub-tiers (declared here for future RSC iters):

- **T3a (scaffold-tier, paper):** the build recipe + harness sources +
  Renode platform spec exist on disk. PASSes from v1.2.0 onward via
  `numerics_t3_rp2040_scaffold.hexa`.
- **T3b (run-tier, HW-bench):** Renode actually runs the binary and
  the captured UART log contains the expected sentinel pattern (e.g.
  `[t3_rp2040 PASS] gpio_toggle_5x_observed`). FAILs in v1.2.0 (no
  Renode run logged); ticks ✓ once the run is captured.

The `falsifier_check.hexa` script does NOT lift `F<n>_T3 ✓` to 100%
based on scaffold-tier alone — only run-tier verification counts.
v1.2.0 is "T3 scaffold complete; T3 run pending".

## Build flow (paper-tier; not yet executed)

```bash
# 1. cross-compile harness (host needs arm-none-eabi-gcc)
make -f Makefile.rp2040 t3_harness.elf

# 2. run in Renode emulator
renode -e "include @t3/renode_rp2040.resc; start" \
       --console-log t3_rp2040_run.log

# 3. verify log sentinel
grep -E "__T3_RP2040__ PASS" t3_rp2040_run.log
```

## Cross-references

- F-HAL falsifier table: `stdlib/hal/README.md` § Falsifier preregister.
- Closure formula: `~/core/bedrock/docs/runnable_surface_recipe.md` §3.
- T2 sibling: `stdlib/hal/numerics_*.hexa` (5 numerical scripts).
- Sim backend: `stdlib/hal/<peripheral>.hexa` (12 modules).
- HW backend (target): `stdlib/hal/backend/rp2040/<peripheral>.hexa`.

## Provenance

- v1.2.0 — scaffold landed (this commit).
- v1.3.0+ — Renode run + log capture (HW-bench T3b activation).
