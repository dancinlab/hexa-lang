# module/firmware — STM32F429 reference (CMSIS-only)

> Reference implementation of `module/engineering_pack/README.md` §5
> (firmware) and `core/sscb/domain.md` §13 — same code, English-named
> identifiers. CMSIS-Core register-direct access only; no STM32 HAL/LL,
> no vendor SDK redistribution.

## What this is, and what it is not

| Verified here | Not verified here |
|---|---|
| Source-level integrity: every `engineering_pack` §5 function, struct, and macro is present and self-consistent | On-target behavior: 600 ns trip latency, T-1..T-9 acceptance |
| **ARM cross-compile to `build/firmware.elf`** (verified 2026-05-06: 1996 B text, 3096 B BSS, ~5 KB total) | Hardware bring-up: requires STM32F429ZIT6 board + ST-Link |
| Memory map within stm32f429zi (`linker/stm32f429zi.ld`) | Closed-loop response: requires Pearson 110A + Tektronix MSO64 |
| Identifier sync with `engineering_pack` §5 / domain.md §13 | UL 489B short-circuit interrupt: requires 5 kA pulsed source jig |

CI in this repo can verify the first column. The second column is the
acceptance scope of `tests/test_acceptance.py` T-1..T-10 (all skipped for
the bench-only reason).

## Layout

```
module/firmware/
├── README.md                    ← this file
├── Makefile                     ← arm-none-eabi-gcc cross-compile
├── include/
│   ├── sscb.h                   ← state struct + macros from engpack §5.2
│   └── stm32f4xx_min.h          ← minimal CMSIS-style register stub
│                                  (NOT a redistribution of ST's SDK; only
│                                   the registers this scaffold touches)
├── src/
│   ├── main.c                   ← engpack §5.1 main + main_loop
│   ├── fault_handler.c          ← engpack §5.2 verbatim (TIM1_BRK / DMA2_S2)
│   ├── system_init.c            ← engpack §5.3 clock tree (HSE 8→180 MHz)
│   ├── adc_dma.c                ← SPI1 + DMA2_Stream2 (Σ-Δ consumer)
│   └── gate_driver.c            ← TIM1 PWM 30 MHz + dead-time + COMP1→BRK
├── linker/
│   └── stm32f429zi.ld           ← 2 MB Flash + 256 KB SRAM + 64 KB CCM
└── startup/
    └── startup_stm32f429.s      ← CMSIS minimal vector table + Reset_Handler
```

## Build

```bash
brew install arm-none-eabi-gcc arm-none-eabi-binutils     # macOS (Apple Silicon / Intel)
# or: sudo apt install gcc-arm-none-eabi                  # Debian/Ubuntu

make -C module/firmware check    # toolchain check
make -C module/firmware all      # → build/firmware.elf, .bin, .hex
make -C module/firmware size     # arm-none-eabi-size summary
make -C module/firmware clean
```

Targets `build/firmware.elf` etc. are `.gitignore`'d.

**Bare-metal toolchain note:** brew's `arm-none-eabi-gcc` ships without
newlib/picolibc, so the build uses `-ffreestanding` plus a minimal
[`include/freestanding/stdint.h`](include/freestanding/stdint.h) shim
that supplies just the fixed-width int typedefs ISO C99 requires.
Linkage pulls compiler runtime helpers from `libgcc.a` (e.g.
`__aeabi_uldivmod` for the 64-bit RMS divide). If you swap to a
toolchain that bundles newlib (Arm's official one, or
gcc-arm-none-eabi from apt), the shim becomes unnecessary — delete
`include/freestanding/` and remove the `-isystem` line from the Makefile.

## Sync policy with engineering_pack §5

`engineering_pack/README.md` §5 is the authoritative spec; this directory is
the materialization. When §5 changes:

1. Update `engineering_pack/README.md` §5.x.
2. Mirror the change here in the matching `src/*.c` file.
3. Run `python3 verify/cross_doc_audit.py` — currently audits only the .md
   surfaces. Identifier-level drift between §5 and `src/` is caught at
   compile time, not at audit time.

If §5 introduces a new macro / struct member, it must appear in `include/sscb.h`
**before** the C source uses it. Don't extend `include/sscb.h` with
identifiers that have no source in §5 — that's silent firmware drift.

## Authority

Code-permitted location declared by `.own` own 3
(`hexa-sscb-doc-first-code-scope`). New `.c` files outside `src/` are
prohibited without first updating own 3's `decl 허용 위치 4` clause.
