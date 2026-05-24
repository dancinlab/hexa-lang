# RFC 063 — `@target(firmware, ...)` codegen lane

- status: DRAFT (scaffolded, codegen pending)
- created: 2026-05-20
- authority: `FIRMWARE.md` §4 gates G-F0..G-F4 + `@D g5 hexa-native-only`
- consumer: `stdlib/firmware/{target,mmio,interrupt,asm,startup}.hexa.stub`
- consumer fixture: `stdlib/firmware/test/blinky.hexa`
- sibling RFC: 064 (`@target(rtl)` codegen lane)
- supersedes / reconciles: `self/native/gpu_codegen_stub.c` (rt#45 GPU
  codegen skeleton) — the same annotation shape applies to the device-
  codegen seam, so RFC 063 + RFC 055 (hexa-NVPTX) jointly define the
  `@target(...)` family.

---

## §1 Problem

Today there is no way to express bare-metal firmware in `.hexa`. Every
firmware-class deliverable in the repo is authored as `.c`/`.h`/`.s`
under `firmware/boards/<board>/firmware/{hdl,src}/...`. FIRMWARE.md §1
forbids that pattern going forward; this RFC is the codegen-side
capability that makes the ban implementable.

The forbidden source classes in §1 of FIRMWARE.md (`.c`/`.h`/`.cpp`/
`.s` etc.) are forbidden as **authored** source. The toolchain
(arm-none-eabi-gcc, riscv64-elf-gcc, ...) still wants C as input —
that input must come from hexa AOT, not a human. The current AOT
lane (`self/codegen_c2.hexa`) emits hosted C (uses libc, malloc,
printf). Firmware needs a **freestanding** lowering plus a handful of
target-specific annotations (`@target`, `@mmio`, `@interrupt`, `@asm`).

## §2 Goals (FIRMWARE.md G-F0..G-F4)

- **G-F0** — `@target(firmware, arch=<...>, core=<...>)` parses on a
  `fn main()` or module-scope; codegen emits a freestanding `.c` under
  `build/firmware/<arch>/<file>.c` + a `link.ld` template.
  - Exit fixture: `stdlib/firmware/test/blinky.hexa` builds with
    `arm-none-eabi-gcc` and produces a `.elf` whose `.text` md5 is
    byte-stable across two clean rebuilds.
- **G-F1** — startup vector + reset handler + `.bss` zero + `.data`
  copy emit (`stdlib/firmware/startup.hexa`). Replaces hand `crt0.s`.
  - Exit fixture: G-F0 `.elf` boots in `qemu-system-arm` and reaches
    `main()`.
- **G-F2** — `@mmio(addr=..., width=..., ordering=preserve)` annotation
  + codegen-side ordering pin (no LICM hoist, no DCE, no merge).
  - Exit fixture: UART-echo demo on `qemu-system-arm` using only
    `.hexa` MMIO accesses.
- **G-F3** — `@interrupt(vector=..., number=...)` annotation + vector-
  table injection.
  - Exit fixture: SysTick-tick demo, hexa-only.
- **G-F4** — `@asm(arch=..., clobbers=...)` escape hatch.
  - Exit fixture: one ISR fast-path that uses `wfi` writes through
    `@asm`. Anti-balloon discipline: total `@asm` sites in
    `stdlib/firmware/` stay ≤ 5 (FIRMWARE.md §5).

## §3 Non-goals

- **Not a kernel.** No scheduler, no syscall layer, no userspace/kernel
  split. Firmware here = bare-metal `fn main()` plus interrupt handlers.
- **Not a RTOS.** Tasking lives in a future stdlib (`stdlib/rtos/`?), not
  in this RFC.
- **Not a HAL.** Board-specific peripheral drivers (UART, SPI, I²C, ...)
  are downstream consumers (`stdlib/hal/<board>/`); they call into
  `stdlib/firmware/{mmio,interrupt}` but live in their own modules.
- **Not LLVM.** Codegen continues to emit C through the existing AOT
  lane (`self/codegen_c2.hexa`) — `@target(firmware)` is a *profile*
  on that lane (freestanding, no libc, no malloc, no FP unless opted
  in), not a new backend.

## §4 Surface (hexa-side)

### Annotation grammar

```
@target(firmware,
        arch   = "cortex-m0" | "cortex-m4" | "cortex-m33" | "riscv32" | "xtensa" | <new>,
        core   = "armv6-m"    | "armv7e-m"  | "armv8-m.main" | "rv32imac" | <new>,
        layout = <symbol>?,                  // optional — picks a per-board memory map
        float  = "soft" | "softfp" | "hard"  // default "soft"
)
fn ... { ... }

@mmio(addr    = <integer literal>,
      width   = 8 | 16 | 32 | 64,
      ordering = "preserve"                  // only value accepted in v1
)
let <name>: <uXX> = <init>

@interrupt(vector = <string literal>,        // human-readable name for diagnostics
           number = <integer literal>        // IRQn (per-arch, e.g. 15 for SysTick on Cortex-M)
)
fn ... { ... }

@asm(arch     = <string literal>,
     clobbers = [<string literal>, ...]
)
fn ... { """ ... """ }                       // triple-quoted body = asm text
```

### Toolchain dispatch

`hexa build --target=firmware,arch=<arch>,core=<core>` resolves to:
- codegen lane: `self/codegen_c2.hexa` with **freestanding profile** on;
- C emit dir: `build/firmware/<arch>/`;
- linker invocation: `<toolchain>-ld -T build/firmware/<arch>/link.ld
  -nostdlib -o <out>.elf <out>.o ...`;
- the toolchain string is resolved per-arch (cortex-m* → arm-none-
  eabi, riscv32* → riscv64-unknown-elf, ...).

## §5 Codegen contract (where the work actually lives)

The hexa-side surface is small. The substantive work is on the codegen
side. Sketch (full implementation lives in
`self/codegen_c2.hexa` once this RFC is accepted):

1. **freestanding profile** — when the function carries
   `@target(firmware, ...)`, the emitter:
   - drops the implicit `#include <stdlib.h>` / `<stdio.h>`;
   - rewrites `println` / `print` to a target-provided shim
     (`hexa_fw_putc` etc.; resolved at link time);
   - refuses to emit any `malloc`/`free` (or any allocator call)
     unless the target descriptor opts in.
2. **`@mmio` lowering** — emit the `volatile` qualifier on the access
   path; add `__asm__ volatile("" : : "memory" : "memory")` barriers
   before/after to lock ordering against the AOT optimiser; mark the
   address as a `volatile uintXX_t *` cast at the use site.
3. **`@interrupt` lowering** — emit the function with the per-arch IRQ
   attribute (`__attribute__((interrupt))` on Cortex-M, `__attribute__
   ((interrupt))` on RISC-V, ...). Inject the symbol into the vector-
   table struct in `vectors.c` at slot `number`.
4. **`@asm` lowering** — inline body verbatim into a `__asm__
   volatile ("...")` block with the clobber list translated to GCC
   form.
5. **`link.ld` emit** — small per-arch template selected by
   `target_describe(arch)`; layout overridden by `layout=` kw when
   present.

## §6 Phasing

Each gate is a separate PR with its own exit fixture. The order is
G-F0 → G-F1 → G-F2 → G-F3 → G-F4 (matches FIRMWARE.md §4 critical
path). G-F2/G-F3 can land in either order after G-F1.

## §7 Falsifier

- A `.elf` whose `.text` md5 varies across two clean rebuilds
  falsifies G-F0 (the codegen determinism claim).
- A qemu UART demo where the second `@mmio` write to the same address
  is elided by the optimiser falsifies G-F2 (ordering preservation).
- A SysTick handler whose entry/exit pushes registers via `bl
  __aeabi_*` rather than the per-arch IRQ ABI falsifies G-F3.

## §8 References

- FIRMWARE.md §4 G-F0..G-F4
- HEXA-NATIVE-ONLY.md §4 G-0..G-11 (sibling ML lane — shares axes
  A1/A2/A5/A6 with this RFC)
- AGENTS.tape `@D g5 hexa-native-only` · `@D g_atlas_binary_builtin`
- `self/native/gpu_codegen_stub.c` (`@N native_dir` — rt#45 — same
  annotation shape, reconciled by RFC 055 + this RFC)
- ARM Cortex-M0 Devices Generic User Guide (vector table + EXC_RETURN)
- RISC-V Volume I: Unprivileged ISA (IRQ ABI)
