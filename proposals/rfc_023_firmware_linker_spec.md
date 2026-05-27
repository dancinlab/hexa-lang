# RFC-023 — firmware linker spec (`.ld` scripts + bare-metal init)

- **Status**: **Spec draft** (proposed, 2026-05-10) — F5 deliverable; no
  implementation in this commit.
- **Author date**: 2026-05-10
- **Predecessors**: RFC-018 (native codegen spec) §10 (linker), RFC-022
  (async model parity, for the `longjmp/setjmp` deferral note).
- **Companion deliverable**: F5 (firmware linker scripts) per
  `doc/firmware_audit_2026_05_10.md` roadmap.
- **Style template**: RFC-022 (numbered sections, divergence/decision
  tables, deferred-items list, decision log).
- **Affected areas (eventual)**: `compiler/link/hexa_ld.hexa` (parser +
  firmware-mode emitter), `firmware/linker_scripts/*.ld` (new tree, per
  `doc/firmware_audit_2026_05_10.md` Tree shape §"firmware/"), `compiler/
  codegen/thumbv7em_eabihf.hexa` (vector-table section attribute), tests
  under `tests/firmware/` (deferred to F5+1, see §8).

---

## 1. Status / motivation

### 1.1 The F5 trigger

F2 + F4 absorbed five firmware boards into `firmware/boards/*/`; cern
and antimatter carry Rust-side `memory.x` scripts driving
`cortex-m-rt`. F3 landed `thumbv7em-none-eabihf` codegen. The missing
piece is a **hexa-native linker** that consumes a board memory layout
and produces a flashable ELF.

`compiler/link/hexa_ld.hexa` v1.2 is **host-targeted**: ELF64 with one
`PT_LOAD` at `0x400000` (Linux), or Mach-O with `__PAGEZERO` +
`LC_LOAD_DYLINKER` + ad-hoc code signature (macOS). Neither shape is
acceptable for an MCU: firmware needs FLASH-based load addresses, no
PIE, no dynamic linker reference, separate `.text/.rodata/.data/.bss`
sections, a Cortex-M vector table at FLASH origin, and explicit
`.data` init + `.bss` zero loops in `_start`.

### 1.2 Goals

1. Define a **GNU-ld-subset** linker-script grammar (`MEMORY` +
   `SECTIONS`) sufficient for STM32F4-class boards today and RISC-V
   (`mtvec`, `.init_array`) tomorrow.
2. Add an `.ld` parser to `hexa_ld` and a `--script=path/to/script.ld`
   flag that switches to **firmware mode**: no PIE, no LC_LOAD_DYLINKER,
   no `__PAGEZERO`, custom section ordering, vector table first.
3. Specify the `_start` thunk that copies `.data` from FLASH (LMA) to
   RAM (VMA) and zeroes `.bss` before transferring control to `main`.
4. Cover Cortex-M (16+ entry vector table, optional VTOR relocation)
   and RISC-V (`mtvec` trap vector, `.init_array`) so both tier-1
   embedded targets share one linker.

### 1.3 Non-goals (this RFC)

- Multiple-input-`.o` handling beyond what hexa_ld v1.x already does
  not support (deferred to v1.3+ per `compiler/link/hexa_ld.hexa:57-65`).
- Full GNU ld grammar (PROVIDE, ASSERT, OVERLAY, NOCROSSREFS,
  ENTRY-with-expression, complex `KEEP`/`SORT` orderings).
- Thread-local storage (TLS) — deferred to v1.1+ (§7).
- Dynamic linking on embedded targets (likely never; see §9 v2.0 row).
- Bootloader-aware layouts (dual-bank / OTA / A-B partitioning).
- Per-region access permissions enforcement (MPU programming) —
  hexa_ld writes the layout; the runtime decides whether to program
  the MPU at boot.

---

## 2. Linker script grammar (GNU ld subset)

### 2.1 Surface

`.ld` files are GNU-ld-compatible so absorbed Rust boards (cern,
antimatter) keep their `memory.x` unchanged on migration. Subset
recognised by hexa_ld v1.0:

```
linker_script   := { directive }
directive       := MEMORY '{' { region } '}'
                 | SECTIONS '{' { section } '}'
                 | ENTRY '(' IDENT ')'
                 | comment

region          := IDENT '(' attrs ')' ':'
                   ORIGIN '=' int_lit ',' LENGTH '=' int_lit_with_unit
attrs           := { 'r' | 'w' | 'x' | '!' }   # rwx + !x deny

section         := IDENT [ '(' 'NOLOAD' ')' ] ':' [ AT '(' int_lit ')' ]
                   '{' { section_body } '}' '>' IDENT [ 'AT>' IDENT ]
section_body    := wildcard            # e.g. *(.text .text.*)
                 | KEEP '(' wildcard ')'
                 | symbol_assign       # e.g. _stack_top = ORIGIN(RAM) + LENGTH(RAM);
                 | '. = ALIGN' '(' int_lit ')' ';'

int_lit_with_unit := int_lit [ 'K' | 'M' ]
```

`wildcard` is the standard ld glob (`*(.text)`, `*(.rodata*)`, etc.),
restricted in v1.0 to a single path component plus `*` suffix.

### 2.2 Memory layout primitives (LMA vs VMA)

| Primitive | Meaning |
|---|---|
| `ORIGIN(R)` / `LENGTH(R)` | start / length of region `R` |
| `LMA` (`AT>`) | load-memory address — where bytes are written |
| `VMA` (`>`) | virtual-memory address — where the program runs |
| `NOLOAD` | consumes VMA, no FLASH bytes (`.bss`, `.ccmram`) |

Key embedded distinction: **`.data` has VMA = RAM, LMA = FLASH**. The
bytes live in FLASH (survive reset) and are copied to RAM by the
startup thunk (§4.4). hexa_ld records both addresses so the thunk
can find them.

### 2.3 Required sections (Cortex-M baseline)

| Section | Region | Notes |
|---|---|---|
| `.vectors` | FLASH at ORIGIN | first 16+ entries (initial SP, Reset, NMI, HardFault, MemManage, BusFault, UsageFault, …, then external IRQs) |
| `.text` | FLASH | code |
| `.rodata` | FLASH | const data |
| `.data` | RAM (LMA=FLASH) | initialised data, copied at boot |
| `.bss` | RAM (NOLOAD) | zeroed at boot |
| `.stack` | RAM | last region; `_stack_top = ORIGIN(RAM) + LENGTH(RAM)` |
| `.heap` | RAM (optional) | between `.bss` end and `.stack` start; sized by script |

### 2.4 Reference: STM32F407 memory map

`firmware/boards/rtsc/firmware/mcu/memory.x` is the canonical example:

```
MEMORY {
    FLASH  (rx)  : ORIGIN = 0x08000000, LENGTH = 1024K
    RAM    (rwx) : ORIGIN = 0x20000000, LENGTH = 112K
    CCMRAM (rwx) : ORIGIN = 0x10000000, LENGTH = 64K
}
```

(Cortex-M4F + 1 MiB FLASH + 112 KiB SRAM + 64 KiB CCM. CCM is
D-bus-only, no DMA — annotated `.ccmram (NOLOAD)` upstream.) hexa_ld
must accept this byte-identical when migrating cern off cortex-m-rt.

---

## 3. `.ld` parser in `hexa_ld`

New module surface in `compiler/link/hexa_ld.hexa`:

```hexa
pub struct MemoryRegion {
    pub name: string
    pub attrs: string          # e.g. "rx", "rwx"
    pub origin: int            # bytes
    pub length: int            # bytes
}

pub struct Section {
    pub name: string           # ".text", ".data", ".vectors", ...
    pub region: string         # MemoryRegion.name
    pub load_region: string    # AT> region.name; "" if same as region
    pub noload: bool
    pub align: int             # 0 if unspecified
    pub patterns: [string]     # wildcard inputs, e.g. ["*(.text)", "*(.text.*)"]
    pub symbols: [SymbolDef]   # _stack_top = ..., etc.
}

pub struct LinkerScript {
    pub memory: [MemoryRegion]
    pub sections: [Section]
    pub entry: string          # "Reset_Handler" / "_start" / ""
}

pub fn parse_ld_script(path: string) -> LinkerScript
```

Hand-written recursive descent over the §2.1 grammar. Errors emit
RFC-019 catalog codes (HX13xx range, to reserve). No external
dependency; reuses `_push_*` / `_read_*` helpers in hexa_ld.

---

## 4. `hexa_ld` extensions (firmware mode)

### 4.1 New flag

`hexa_ld --script=firmware/linker_scripts/stm32f407.ld obj.o -o app.elf`

When `--script` is set, `hexa_ld` enters **firmware mode** and bypasses
the host-targeted ELF/Mach-O writers in §4.2.

### 4.2 ELF firmware mode (vs. host-targeted v1.2)

| Property | Host v1.2 | Firmware mode (this RFC) |
|---|---|---|
| `e_type` | `ET_EXEC` | `ET_EXEC` |
| PIE / `ET_DYN` | not used | **forbidden** |
| `PT_INTERP` | not emitted | **forbidden** |
| `PT_DYNAMIC` | not emitted | **forbidden** |
| Segments | one `PT_LOAD` (R+X) at 0x400000 | one `PT_LOAD` per `MEMORY` region used; addresses from `.ld` |
| Section ordering | `.text` only | per `.ld` `SECTIONS` block (vectors → text → rodata → data → bss → stack) |
| `.bss`/`.data` init | none | `_start` thunk; see §4.4 |
| Mach-O equivalent | `MH_EXECUTE` + `LC_LOAD_DYLINKER` | **N/A** (Mach-O is not used for firmware) |

### 4.3 Section ordering & layout

For each section in script order, hexa_ld: (1) resolves wildcards
against the input `.o` section table; (2) concatenates matching bytes
(preserving per-`.o` order); (3) records VMA = `region.origin +
offset`; (4) records LMA = `load_region.origin + offset` if `AT>`
present, else LMA = VMA; (5) aligns to `align` (default 4 for ARM,
8 if FP single-precision constant present per AAPCS).

### 4.4 `.data` init + `.bss` zero (`_start` thunk)

hexa_ld emits a tiny entrypoint, **before** the user's `Reset_Handler`,
that:

```
_start:
    # copy .data from FLASH (LMA) to RAM (VMA)
    ldr  r0, =_sdata        # VMA start
    ldr  r1, =_edata        # VMA end
    ldr  r2, =_sidata       # LMA start (FLASH copy)
1:  cmp  r0, r1
    bge  2f
    ldr  r3, [r2], #4
    str  r3, [r0], #4
    b    1b

    # zero .bss
2:  ldr  r0, =_sbss
    ldr  r1, =_ebss
    movs r3, #0
3:  cmp  r0, r1
    bge  4f
    str  r3, [r0], #4
    b    3b

4:  bl   Reset_Handler      # or main, per ENTRY()
    b    .                  # spin if main returns
```

The five symbols `_sdata`, `_edata`, `_sidata`, `_sbss`, `_ebss` are
**implicitly defined** by hexa_ld from the `.data` and `.bss` section
records. RISC-V emits the same shape with `lw`/`sw`/`bgeu`. If
`ENTRY()` is set, hexa_ld jumps to that symbol; otherwise falls back
to `Reset_Handler` → `main` → error.

### 4.5 Disabled host features in firmware mode

No `LC_LOAD_DYLINKER`, no code signature blob, no `__PAGEZERO`, no
PIE relocations, no `.note.gnu.build-id`. Mach-O path not taken at
all.

---

## 5. ARM Cortex-M specifics

### 5.1 Vector table format

Cortex-M loads the vector table from FLASH at reset. The first 16+
entries are fixed by the architecture:

| Index | Entry | Notes |
|---|---|---|
| 0  | initial Stack Pointer | = `_stack_top` (script-defined) |
| 1  | Reset_Handler | code address |
| 2  | NMI_Handler | weak default → infinite loop |
| 3  | HardFault_Handler | weak default → infinite loop |
| 4  | MemManage_Handler | M3+ |
| 5  | BusFault_Handler | M3+ |
| 6  | UsageFault_Handler | M3+ |
| 7-10 | reserved | zero |
| 11 | SVCall_Handler | |
| 12 | DebugMon_Handler | M3+ |
| 13 | reserved | zero |
| 14 | PendSV_Handler | |
| 15 | SysTick_Handler | |
| 16+ | external IRQs | per-MCU; STM32F4 has 82 |

### 5.2 Source-side attribute

User code marks the vector table:

```
@section(".vectors")
const VECTOR_TABLE: [u32; 98] = [ _stack_top, Reset_Handler, ... ]
```

Codegen lowers `@section` to an ELF section directive; hexa_ld
matches it against the `.vectors` wildcard. The script places
`*(.vectors)` first in FLASH at `ORIGIN`.

### 5.3 VTOR relocation (optional)

Some bootloaders move the vector table off `0x08000000` to leave room
for a bootloader. The `.ld` may override FLASH `ORIGIN`; code writes
`SCB->VTOR = &VECTOR_TABLE` in `Reset_Handler`. **Runtime
responsibility**, not hexa_ld's — hexa_ld respects script ORIGIN. No
`--vtor=ADDR` flag.

---

## 6. RISC-V specifics

### 6.1 Trap vector

RISC-V uses `mtvec` (machine trap vector base address) instead of a
fixed table. The script names the section `.trap`; code writes
`mtvec = &trap_handler` in `_start`. hexa_ld places `.trap` first in
FLASH, identical in shape to Cortex-M's `.vectors`.

### 6.2 `.init_array` / `.fini_array`

RISC-V toolchains expect `.init_array` / `.fini_array` for
constructor/destructor lists. hexa_ld v1.0 reserves the section names
and emits `__init_array_start` / `__init_array_end` symbols, but
calls **none** of them. The user runtime walks the array if it wants
C++-style static init. (hexa v1 has no static-init feature; shape is
in place for future stdlib hooks.)

### 6.3 Tier ranking

`riscv32imac-unknown-none-elf` is tier-1 per
`doc/firmware_audit_2026_05_10.md`. Linker must be RISC-V-clean from
v1.2 (§9).

---

## 7. ABI corners

### 7.1 Stack size

Script defines stack size via `.stack` section size or `_stack_top`
symbol assignment (cortex-m-rt convention). Default if neither:
**16 KiB** at top of largest RAM region. HX13xx warns if largest RAM
< 32 KiB and no explicit stack set.

### 7.2 Heap region

Optional `.heap`, sized by `_heap_size = N` or `. = . + N;`. The
embedded allocator (`arena_v1` default per SPEC.yaml; `bump`
optional) consumes whatever the linker reserves — distinction is at
allocator level, not linker level.

### 7.3 Thread-local storage (TLS) — deferred to v1.1+

Cortex-M has no MMU / no TPIDR; TLS on bare metal means manually
context-switched per-task storage — runtime concern, not linker.
RISC-V has `tp`, but stage 1 hexa is single-task on embedded. No
`.tdata`/`.tbss` emission today.

### 7.4 ABI interaction

RFC-018 §4 specifies AAPCS64 / SysV for host. For AArch32-T2
(Cortex-M) the ABI is AAPCS-vfp (r0-r3 args, soft-float ABI with
hard-float ops on M4F). hexa_ld respects per-`.o` attributes only —
F3 codegen enforces ABI.

---

## 8. Test strategy

### 8.1 First test (deferred to F5+1)

`tests/firmware/blink_link.hexa` (NEW):
- Compile a minimal LED-blink with F3 codegen → `thumbv7em-none-eabihf`.
- Link with `firmware/linker_scripts/stm32f407.ld` (extracted from
  `firmware/boards/rtsc/firmware/mcu/memory.x` + section boilerplate).
- Verify ELF: `.text` at `0x08000000`; `.data` LMA in FLASH, VMA in
  RAM; `_start` thunk emitted before user `Reset_Handler`; vector
  table at FLASH origin with correct first two entries (`_stack_top`,
  `Reset_Handler`); no `LC_LOAD_DYLINKER`, no PIE.

### 8.2 RISC-V test (deferred)

`tests/firmware/riscv_link.hexa` — `mtvec` placement + `.init_array`
shape per §6.

### 8.3 Audit hook

`verify/firmware_linker_audit.hexa` (new) cross-checks every
`firmware/linker_scripts/*.ld` against §2.1 grammar and against the
board's `firmware/mcu/memory.x`. PASS if byte-identical for `MEMORY`.

---

## 9. Roadmap

| Version | Deliverable |
|---|---|
| v1.0 | `parse_ld_script` + `--script` flag + section ordering per script + ELF firmware mode (no PIE, no dyld) |
| v1.1 | `_start` thunk emission (`.data` copy + `.bss` zero) + Cortex-M vector table placement |
| v1.2 | RISC-V parity (`mtvec` placement, `.init_array` symbols) |
| v1.3 | Multi-input `.o` (links to RFC-018 §10 v1.3+ deferral) + relocation processing |
| v2.0 | TLS, dynamic linking on embedded — **likely never** unless a board grows an MMU |

F5 ships v1.0 only (parser + flag + section ordering — spec-only this
commit). F5+1 lights up v1.1 with the test in §8.1.

---

## 10. Open questions

- **OQ-1**: GNU ld grammar subset boundary. v1.0 cuts `PROVIDE`,
  `ASSERT`, `OVERLAY`, `SORT`, complex `KEEP`. Re-evaluate after cern
  drops `cortex-m-rt`.
- **OQ-2**: Per-board script sharing. rtsc + chip are both STM32F4 —
  share `firmware/linker_scripts/stm32f4xx.ld` and override only
  FLASH/RAM length per board? Defer until chip ships without
  `cortex-m-rt`.
- **OQ-3**: Vendor toolchain compatibility. Should firmware-mode ELF
  round-trip through `arm-none-eabi-{objcopy,gdb}`? At minimum
  `readelf -a`, `objcopy -O binary`, gdb symbol load. Deferred to
  v1.1 testing.
- **OQ-4**: `.ld` parser inline vs. split module. v1.0 inline; split
  to `compiler/link/ld_script.hexa` if past ~600 LOC.
- **OQ-5**: Diagnostic catalog. Claim HX13xx range for link-time, or
  carve HX133x sub-range for `.ld` parser?

---

## 11. Decision log

- **2026-05-10** — RFC drafted. v1.0 scope = parser + flag + section
  ordering. v1.1 = `_start` thunk + vector table. v1.2 = RISC-V
  parity. RFC-023 filed as a **separate RFC**, not an extension of
  RFC-018, because firmware-mode emitter diverges from host emitter
  at segment-layout level — inlining into RFC-018 §10 would make
  that section larger than the rest of RFC-018 combined. (Closes
  `doc/firmware_audit_2026_05_10.md` Open Question §3.)
- **2026-05-10** — Stack size default 16 KiB (matches every absorbed
  Rust board; no contradictions). Heap optional, sized by script.
- **2026-05-10** — TLS deferred to v1.1+. Stage 1 hexa is single-task
  on embedded.
- **2026-05-10** — Mach-O firmware mode **not** in scope (no embedded
  target uses Mach-O; iOS dev kits not a firmware tier).

---

## 12. One-line conclusion

GNU-ld-subset parser + `--script` flag in `hexa_ld` + firmware-mode
emitter (no PIE, no dyld, real `.text/.rodata/.data/.bss/.stack`
sections per script, Cortex-M vector table at FLASH origin or RISC-V
`mtvec` placement, `_start` thunk for `.data` copy + `.bss` zero) —
v1.0 ships parser + flag this RFC, v1.1 lights up `_start` + vectors
in F5+1, RISC-V parity in v1.2, TLS / dynamic deferred (likely
never).
