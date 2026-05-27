# `stdlib/firmware/` — hexa-native firmware lane (FIRMWARE.md G-F0..G-F4)

> **Status: SCAFFOLD-ONLY (2026-05-20) — `.hexa.stub` skeletons.** No
> body returns a useful artifact yet. The codegen support for
> `@target(firmware, ...)` lowering is the subject of RFC 063
> (`docs/rfc/rfc_drafts_2026_05_20/rfc_063_target_firmware_codegen.md`);
> until that lands, every stub here documents the eventual capability
> shape only.

This module is the hexa-source authoring surface for bare-metal device
code (Cortex-M, RISC-V, Xtensa, ...). It replaces hand-authored `.c` /
`.h` / `.s` under repo-root `firmware/boards/*` and elsewhere — per
[`../../FIRMWARE.md`](../../FIRMWARE.md) §1 those classes are forbidden
as authored source. The toolchain still receives C as input, but the C
is **codegen output** under `build/firmware/<target>/`, not a sibling
authored file.

## Module index (FIRMWARE.md §4 G-F0..G-F4)

| file | purpose | FIRMWARE.md gate |
|---|---|---|
| `target.hexa.stub`     | `@target(firmware, arch=<cortex-m0/m4/m33, riscv32, xtensa, ...>)` annotation surface + `link.ld` template emission | G-F0 |
| `startup.hexa.stub`    | startup vector / reset handler / `.bss` zero / `.data` copy emit (replaces hand `.s` startup files) | G-F1 |
| `mmio.hexa.stub`       | `@mmio` annotation (`volatile`-equivalent, ordering-preserving load/store) | G-F2 |
| `interrupt.hexa.stub`  | `@interrupt(handler=...)` annotation + vector-table injection | G-F3 |
| `asm.hexa.stub`        | `@asm(arch=..., clobbers=...)` escape hatch (irreducible per-CPU peaks; bounded use per FIRMWARE.md §5 anti-pattern) | G-F4 |
| `test/blinky.hexa`     | reference fixture — Cortex-M0 GPIO blinky; the G-F0 exit criterion (.elf .text md5 stable across rebuilds) | G-F0 |

## Exit fixtures (FIRMWARE.md §6 verification anchors)

- **G-F0** — `stdlib/firmware/test/blinky.hexa` builds with
  `arm-none-eabi-gcc` (codegen output) and produces a `.elf` whose
  `.text` md5 is byte-stable across two clean rebuilds.
- **G-F1** — the `.elf` from G-F0 boots in `qemu-system-arm` and reaches
  `main()`.
- **G-F2** — UART-echo demo on `qemu-system-arm` using only `.hexa`
  MMIO accesses.
- **G-F3** — SysTick-tick demo, hexa-only.
- **G-F4** — at least one ISR fast-path uses `@asm`; total `@asm`
  occurrences across this module stay ≤ 5 (anti-balloon check, §5).

## Provenance

This directory is the **upstream** of the future
`firmware/boards/<board>/firmware/hdl/...` hexa source tree. Existing
`firmware/boards/**.v` (RTL) and `firmware/boards/**.c` (legacy C) are
tracked by `tool/audit_forbidden_exts.hexa` (G-T0) under the ABSORBED
category — they migrate to `@target(firmware)` / `@target(rtl)` form
as each board's owner-cycle re-authors them.

## How `@target(firmware)` lowers (sketch — see RFC 063 for the full spec)

```
file.hexa  ──┐
             │   `@target(firmware, arch=cortex-m0)`
             │   on a `fn main()` / module-level annotation
             ▼
hexa AOT codegen
             │   emits:
             ▼
build/firmware/cortex-m0/<file>.c   (C source, codegen output)
build/firmware/cortex-m0/link.ld     (linker script template)
             │
             │   handed to arm-none-eabi-gcc by the project's
             │   build driver — same toolchain as today, the only
             │   change is who **authors** the C
             ▼
build/firmware/cortex-m0/<file>.elf  (deliverable)
```

The `.c` under `build/firmware/` is identical in role to the `.c`
that hexa AOT already emits for general code. The new piece is the
target-specific lowering: no `libc`, freestanding ABI, MMIO ordering
preserved, vector table emitted, etc.
