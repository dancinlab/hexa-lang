# RFC 063 — S7 native assembler + linker (drop `as` / `ld` / `clang`)

> Status: **DRAFT** (2026-05-20)
> Authority: COMPILER.md S7, AGENTS.tape `@D g5` hexa-native-only,
> `HEXA-NATIVE-ONLY.md`
> Prereq: S1 ✅ + S2 ✅ + S3 ✅ (self-host fixpoint, gen1.s ≡ gen2.s)
> + S4 ✅ wiring (build_hexac.hexa) + S5 ✅ wiring (HEXA_BACKEND=native)

## Background

After S1-S5 the hexa-lang compiler self-hosts (S3 fixpoint proven 2026-05-
20, md5 `29426b801cb072b2861bd608e884b20b`). The `hexa_v2` C transpiler is
removed from the compiler's own build path (S4, `tool/build_hexac.hexa`).
The C path remains as the documented portability fallback only.

`compiler/main.hexa:2,806` already marks `as` / `ld` / `xcrun` as **"L1
keepers — replaced when self-as lands"**. The `compiler/intrinsics/
intrinsics.hexa` module declares the L0..L3 migration ladder:

```
L0 — exec("as ..."), exec("ld ..."), exec("clang ...") scattered.
L1 — call sites use the intrinsics; bodies still fork (today).
L2 — bodies replaced with FFI to libc / direct invocation.
L3 — bodies replaced with raw syscalls / native code; zero fork.
```

S7 lands L2/L3 for the assemble + link path. Per S5's finding,
`aprime_cc --emit=exec` already runs the internal assemble + link logic
but shells `as`/`ld`; native bodies turn those forks into hexa-internal
code paths.

`tool/hexa_link.hexa` (117 LoC) is **NOT** a from-scratch linker — its
own header declares itself a *"Thin clang wrapper. Takes N .c files ...
clang handles C-level symbol resolution."* It is a C-path artifact and
is not reused.

## Goal

Drop the last external toolchain dependencies from the compiler's
native build path: emit Mach-O / ELF object code directly from LIR,
link it natively, no `as` / `ld` / `clang` involvement.

When S7 lands and is flipped to default, `hexa build` (with
`HEXA_BACKEND=native`, S5) and `tool/build_hexac.hexa` (S4) both
produce executables with **zero external toolchain processes
forked** — verifiable by `dtruss` / `strace` on the build.

## Non-goals

- **Cross-compilation in S7 itself.** `--target=linux-x86_64` etc.
  remain on the `zig cc` path (`compiler/main.hexa:1933`) until P2 of
  this RFC delivers ELF support.
- **An optimizing assembler.** S7's assembler does encoding only — no
  peephole, no scheduling. Optimizations stay in the LIR / MIR layers
  (S6, `compiler/optimize/`).
- **A general-purpose linker.** S7's linker handles exactly the cases
  the compiler produces: one or two `.o` files (app + runtime), Mach-O
  arm64 / ELF x86_64, static link only. Dynamic linking / `.dylib` /
  `.so` are out of scope; the runtime is statically linked.
- **The C path.** The C path (`hexa_v2 → C → clang`) is retained as
  documented portability fallback (`@F f2`). S7 does not touch it.

## Design

S7 ships as four phases. Each phase is independently testable with
a falsifier that the previous toolchain (`as`/`ld`) provides as
oracle.

### P0 — Mach-O arm64 object emitter (`compiler/emit/macho_arm64.hexa`)

LIR → Mach-O arm64 `.o` bytes, **without** the intermediate `.s` text
that `compiler/emit/asm.hexa` produces today.

Inputs:
- `LModule` (from `compiler/codegen/arm64_darwin.hexa`) — already
  contains LIR instructions with operands resolved post-regalloc.
- Symbol table (function labels, `.loc` debug entries — already
  threaded through to `emit_asm`).

Outputs:
- Mach-O 64-bit arm64 relocatable object (`MH_OBJECT`, cputype
  `CPU_TYPE_ARM64`, cpusubtype `CPU_SUBTYPE_ARM64_ALL`):
  - Header + load commands: `LC_SEGMENT_64` (`__TEXT`), `LC_SYMTAB`,
    `LC_DYSYMTAB`, optionally `LC_DATA_IN_CODE`, `LC_BUILD_VERSION`
    (macos 11.0+).
  - Sections: `__TEXT,__text` (code), `__DATA,__data` (constants),
    optional `__DWARF,__debug_line` (DWARF v5 line tables — already
    emitted in asm form by `compiler/emit/asm.hexa`).
  - Relocations (`ARM64_RELOC_PAGE21` / `ARM64_RELOC_PAGEOFF12` for
    `ADRP`/`ADD` symbol pairs; `ARM64_RELOC_BRANCH26` for `BL`).

Implementation strategy:
- LIR instruction → opcode bytes table. arm64 is a fixed 32-bit ISA
  per instruction — encoding is mechanical (4 bytes per insn). The
  existing `compiler/codegen/arm64_darwin.hexa` already chose
  instructions + registers; this phase only needs the **encoding
  table** (instruction syntax → 32-bit word). ~150-200 encoding
  rules cover the LIR subset (no SIMD/FP yet — those follow when
  the codegen lowers to them).
- Relocation records emitted alongside.
- Symbol table built from `LModule.funcs` + extern references.

Falsifier **F-P0-OBJEQ**:
```
For test program T in {trivial, fib, while, if, compiler_self}:
    s = aprime_cc --emit=asm T  → T.s
    o_ref = clang -c -arch arm64 T.s -o T.ref.o    (oracle)
    o_ours = aprime_cc --emit=obj T  → T.ours.o    (new path)
    diff <(strip-nondet o_ref) <(strip-nondet o_ours)  # equal
```
`strip-nondet` removes timestamps, file paths in `LC_BUILD_VERSION`,
empty `LC_UUID`, and the load-command order (Mach-O permits reordering).
If the code-section bytes + relocations + symbol entries match, P0 is
correct.

### P1 — Mach-O arm64 native linker (`tool/hexa_ld.hexa`, rewrite)

Replaces `tool/hexa_link.hexa` (clang wrapper) with a real linker.

Inputs:
- N input `.o` files (typically: app.o + runtime.o + optional shim.o).
- Output path.

Outputs:
- Mach-O 64-bit arm64 executable (`MH_EXECUTE`, `MH_PIE`):
  - `__PAGEZERO` (4 GB null page).
  - `__TEXT` segment: `__text` (linked code), `__stubs`,
    `__stub_helper`, `__cstring`.
  - `__DATA` segment: `__data`, `__bss`, `__got`.
  - `__LINKEDIT` segment: symbol table, indirect symbol table,
    string table.
  - `LC_MAIN` (entry point — runtime `_main`).
  - `LC_LOAD_DYLINKER` (`/usr/lib/dyld`) — Note: required for any
    macOS executable; even static-binary look-alikes need dyld. This
    is the one remaining OS-mandated dependency, not a toolchain
    dependency.
  - `LC_LOAD_DYLIB` for `/usr/lib/libSystem.B.dylib` (libc, libm; the
    runtime calls `malloc`, `printf`, etc. through libSystem).
  - `LC_CODE_SIGNATURE` (ad-hoc, post-link `codesign -s -` invocation
    — that fork stays as the macOS Gatekeeper requirement, an OS
    interaction not a toolchain step. Documented honestly.).

Linking work:
- Symbol resolution across input `.o`s.
- Section concatenation with alignment.
- Relocation fixups (apply offsets per the type — ARM64_RELOC_PAGE21
  patches the `ADRP` immediate, etc.).
- PIE base address handling (Mach-O `MH_PIE` flag → addresses are
  relative).

Falsifier **F-P1-RUNEQ**:
```
For corpus C in {smoke (exit 42), fib, compiler_self (hexac)}:
    exe_ref = clang ... T.o runtime.o -o T.ref    (oracle, system ld)
    exe_ours = hexa_ld T.o runtime.o -o T.ours   (new linker)
    diff <(exe_ref input) <(exe_ours input)       # same stdout / exit code
```
We do NOT require Mach-O byte-eq (system `ld64` and ours differ on
non-functional ordering / padding). We require **runtime equivalence**:
identical stdout / exit code on the corpus. That is the functional
contract.

### P2 — ELF x86_64 emitter + linker

Extend P0 + P1 to ELF format for linux-x86_64. Same shape:
- `compiler/emit/elf_x86_64.hexa` (encoding tables, relocation types
  `R_X86_64_PC32`, `R_X86_64_PLT32`, `R_X86_64_64`, etc.).
- `tool/hexa_ld.hexa` gains an ELF code path (or
  `tool/hexa_ld_elf.hexa` if the file gets too large).

x86_64 ELF is in some ways simpler than Mach-O — no dyld, no code
signing, the `LC_LOAD_DYLIB`-equivalent is just `DT_NEEDED libc.so.6`.
But x86_64 instruction encoding is variable-length (1-15 bytes), so
the encoding table is larger and the operand size / prefix logic is
non-trivial.

Falsifier mirrors P0/P1.

### P3 — flip the default

Once P0-P2 land and corpus passes:
- `tool/build_hexac.hexa` stage 4 (clang assemble + link) swaps to
  `aprime_cc --emit=obj` + `hexa_ld` — the script's clang invocation
  is removed.
- `cmd_build` (`self/main.hexa:1710`) flips the default to native
  for `HEXA_BACKEND` unset (the C path remains opt-in via
  `HEXA_BACKEND=c` for portability fallback).
- The L1 markers in `compiler/main.hexa:2,806` are updated to L3
  ("retired: as/ld are no longer forked").

Falsifier **F-P3-ZERO-EXTERN**:
```
dtruss -f -t posix_spawn,execve -p $(hexa build trivial.hexa -o /tmp/t) 2>&1 | \
    grep -E "(clang|/as$|/ld$|/ld64$)"  # empty — no external toolchain forks
```
The only fork allowed is `codesign -s -` for the ad-hoc signature
(macOS Gatekeeper requirement, not a toolchain step). Linux: zero
forks allowed.

## Phasing schedule (estimate, multi-cycle)

| Phase | Scope | Effort | Cumulative state |
|-------|-------|--------|------------------|
| P0 | Mach-O arm64 obj emitter + F-P0-OBJEQ corpus pass | ~3-5 cycles | `aprime_cc --emit=obj` works; `as` no longer forked. |
| P1 | Mach-O arm64 linker + F-P1-RUNEQ corpus pass | ~3-5 cycles | `hexa_ld` works on arm64-Mac; `ld` no longer forked. |
| P2 | ELF x86_64 emitter + linker + F-P0/P1 on linux | ~5-7 cycles | linux-x86_64 native path works. |
| P3 | flip default + L3 marker update + F-P3 corpus pass | ~1 cycle | "완전한 hexa-native" achieved; clang no longer forked except by C-path fallback. |

Total: **~12-18 cycles**. Each cycle is a worktree sub-agent
dispatch with falsifier verification.

## Risks

- **arm64 encoding edge cases.** Symbol-relative loads need ADRP/LDR
  or ADRP/ADD pairs with linker-aware relocations; PC-relative
  branches >128MB need stubs. Each edge case is one or two encoding
  rules — tedious but mechanical.
- **Mach-O ad-hoc code-sign.** macOS Sonoma+ rejects unsigned native
  executables. We keep the `codesign -s -` fork (OS requirement, not
  a toolchain dependency) and document the exception.
- **runtime.o supply.** P0 produces app.o; the runtime (`self/runtime
  .c`, currently ~9.5k LoC of C) needs to be available as a `.o` to
  link against. Two options: (a) ship a precompiled `self/runtime.o`
  artifact with the toolchain (clang -c at toolchain-build time, once)
  — pragmatic. (b) port runtime.c to hexa over time, compile via S7's
  own path — long-horizon, HEXA-NATIVE-ONLY G-ladder territory.
  P0/P1 adopt option (a); option (b) is a separate runtime-purge RFC.
- **Concurrent campaign drift.** The compiler-native-codegen branch
  accumulates work; merging to main is a separate consolidation
  step. RFC 063 does not address that.

## Cross-references

- `COMPILER.md` — campaign SSOT, S7 line + Step detail.
- `compiler/PLAN.md` #18 — self-host plan (S1-S4 closed by this
  session's work).
- `HEXA-NATIVE-ONLY.md` — broader native-only policy + the G-ladder
  (S6 territory, orthogonal to S7).
- `compiler/intrinsics/intrinsics.hexa` — L0..L3 migration ladder.
- `compiler/main.hexa:2,806` — existing L1 markers for `as`/`ld`.
- `tool/hexa_link.hexa` — clang wrapper to be retired by P1.
- `tool/build_hexac.hexa` — S4 native-path build script (gets its
  clang stage replaced by P3).

## Open questions

- Should the encoding tables for arm64 / x86_64 be generated from a
  spec file (e.g. a `.tape` ISA definition) or hand-written? Code-gen
  from spec is more maintainable but adds a build dependency.
- DWARF debug info: `compiler/emit/asm.hexa` already emits `.loc`
  directives. P0 needs to encode those into `__debug_line` sections.
  Pre-existing logic in `compiler/emit/asm.hexa` for line-table
  building can be largely reused.
- Should the linker be a separate binary (`hexa_ld`) or absorbed into
  `hexac` (`aprime_cc`) as `--emit=exec` self-link? S5 found
  `--emit=exec` currently does NOT self-link due to missing runtime;
  P1 of this RFC could implement that internal path instead of a
  separate `hexa_ld` binary. Open — both shapes work; the integrated
  approach has fewer binaries to ship.

---

**Status note**: this is a DRAFT RFC, no implementation yet. The
campaign goal "완전한 hexa-native" requires P0-P3 to land and the
F-P3 corpus to PASS. Multi-cycle, multi-week work. This RFC is the
design contract that future S7-implementation sub-agents work from.
