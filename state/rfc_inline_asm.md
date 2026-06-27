# RFC — inline assembly for `.hexa` (native-emit)

status: rfc + first byteeq-safe slice (`__hx_asm_nop`)
slug: inline-asm
lane: inline-asm (design-first)
reference: Rust `core::arch::asm!` / `core::hint::spin_loop`, Zig `asm volatile`, GCC `__asm__ volatile`

---

## 0. one-line

Give `.hexa` a release-safe inline-assembly surface by **extending the existing
native raw-instruction-emit path** (`__hx_syscall0` / `__hx_syscall6`, which already
emit `syscall` / `svc` bytes) with a **named-opcode intrinsic family** `__hx_asm_<mnemonic>`.
No new keyword, no new `@attr`, default path byte-identical, opt-in per call-site.

## 1. what already exists (measured, file:line)

There are **three** pre-existing asm-adjacent surfaces; this RFC unifies the story
and picks the only release-safe extension point.

1. **`@asm` attribute — ALREADY in the frozen parser.**
   `self/parser.hexa:332` -> `if name == "asm" { return true }` (attribute name
   whitelist). So `@asm(...)` parses today on the frozen blob `151c52c8`. But:
   - C-transpile codegen treats it as a **no-op comment**:
     `self/codegen.hexa:2053-2054` -> `/* FIRMWARE.md @target/@mmio/@interrupt/@asm —
     codegen lowering pending RFC 063/064 (treated as no-op on this lane) */`.
   - The library helper `stdlib/firmware/asm.hexa` only **produces a GCC `__asm__`
     C-fragment string** (`asm_emit_block`) for cortex-M — a C-transpile firmware
     feature, **not** a native-emit surface, capped at <=5 sites (anti-balloon).
   - There is **no native lowering** of `@asm` to machine bytes.

2. **`__hx_syscall0(num)` / `__hx_syscall6(num,a0..a5)` — native raw-instruction emit.**
   The proven mechanism this RFC extends:
   - bind whitelist: `compiler/check/bind.hexa:1244` (`_bind_builtin_names`).
   - x86_64: `compiler/codegen/x86_64_linux.hexa:2430` -> `_x86_instr0("syscall", …)`
     (emitter encodes `SYSCALL` = `0f 05` at `compiler/emit/elf_x86_64.hexa:338`).
   - arm64: `compiler/codegen/arm64_darwin.hexa:2190` -> `svc #0x80` (darwin) / `svc #0`
     (linux), per-target number register `x16`/`x8` (encoder
     `compiler/emit/macho_arm64.hexa:746`, shared by the arm64-linux ELF backend via
     `encode_arm64_insn`).
   - C-transpile mirror: `self/codegen.hexa:6316` (`__asm__ volatile("syscall"…)`).
   A source-level call `__hx_syscall0(n)` becomes a MIR `_STMT_CALL` with `s.op ==
   "__hx_syscall0"`; the backend special-cases the op-name and emits the trap inline.

3. **`__hx_payload_*` family** (add/sub/mul/div/fadd/…): the same op-name-dispatch
   pattern already emits raw x86/arm64 ALU/SSE instructions inline. This is the exact
   shape an inline-asm intrinsic follows.

### why this matters

The compiler **already has a per-target, op-name-dispatched, raw-instruction emitter**.
"Inline asm" for `.hexa` does **not** need a new parser construct or a text assembler
for the useful 80% — it needs the **named-opcode intrinsic family** wired through the
same four sites the syscall intrinsic uses.

## 2. design — `__hx_asm_<mnemonic>` named-opcode intrinsics

### 2.1 surface

Each supported instruction is exposed as a **builtin-named free call**, parsed as an
ordinary call (frozen-parser-safe — the parser already accepts any `ident(args)`):

```hexa
__hx_asm_nop()        // alignment / timing padding
__hx_asm_pause()      // x86 PAUSE / arm64 YIELD — spin-loop hint
__hx_asm_fence()      // x86 MFENCE / arm64 DMB ish — full memory barrier
__hx_asm_rdtsc()      // x86 RDTSC -> cycle counter (arm64: MRS CNTVCT_EL0)
```

reference-match:
- Rust exposes these as `core::hint::spin_loop()` (-> `pause`/`yield`),
  `core::sync::atomic::fence`, `core::arch::x86_64::_rdtsc()` — *named* intrinsics, not
  raw `asm!` text, for the portable subset. We mirror that taxonomy.
- Zig: `@fence`, `asm volatile ("pause")`. GCC: `__builtin_ia32_pause`, `__atomic_*`.

### 2.2 lowering (per intrinsic, mirrors `__hx_syscall0`)

For each `__hx_asm_<m>` the backend special-cases `s.op` in `_STMT_CALL`:
- emit the literal instruction (`_x86_instr0` / `_arm64_instr0`);
- materialise an `int` HexaVal result (`{TAG_INT, payload}`) so the call composes as a
  normal expression — `nop`/`pause`/`fence` -> payload `0`; `rdtsc` -> the 64-bit
  counter.

This is **default-OFF for the whole compiler closure**: the compiler's own source
never calls `__hx_asm_*`, so `gen3 ≡ gen4` and every DEFAULT user program emit
byte-identical (the new branch is dead unless a program opts in by calling the
intrinsic). Same byteeq argument the `__hx_syscall0` land used.

### 2.3 four-site wiring (the ladder rung)

| site | file | role |
|------|------|------|
| bind whitelist | `compiler/check/bind.hexa` `_bind_builtin_names` | resolve the name (no HX2001) |
| x86_64 emit | `compiler/codegen/x86_64_linux.hexa` `_STMT_CALL` | raw-instruction inline |
| arm64 emit | `compiler/codegen/arm64_darwin.hexa` `_STMT_CALL` | raw-instruction inline (darwin + arm64-linux) |
| C-transpile mirror | `self/codegen.hexa` | `__asm__ volatile("<mnem>")` (gen2 / `hexa run`) |
| (new mnemonic only) emitter byte-table | `compiler/emit/elf_x86_64.hexa` + `compiler/emit/macho_arm64.hexa` | encode the opcode if not already present |

A mnemonic is cheap to add **iff** the LIR->byte emitter already encodes it. Current
coverage:
- `nop`: x86 `0x90` (`elf_x86_64.hexa:525`) ok, arm64 — **needs** `0xd503201f` added.
- `pause` (`f3 90`), `mfence` (`0f ae f0`), `rdtsc` (`0f 31`): **need** emitter
  additions (zero-operand opcodes, additive/dead-by-default -> byteeq-safe).

## 3. the wall — true `asm!{ "text" }` block

A full Rust/Zig `asm!{ "mov {0}, {1}", … }` string-template block is a **frozen-parser
+ assembler wall**, deliberately out of this slice:

1. **parser**: an `asm` *block* with a string-template body + `in/out/clobber` operand
   clauses is **new block/statement syntax** the frozen blob `151c52c8` does not parse
   -> faithful build-break. (The `@asm` *attribute* parses, but an attribute cannot
   carry an instruction-sequence body with operand binding.) Introducing it requires a
   parser change to the frozen seed — forbidden under release-integrity until a seed
   reflow.
2. **assembler**: a free-text instruction body needs a **mnemonic->bytes assembler**
   inside `compiler/emit/` (the current emitter is an op-name table, not a parser of
   arbitrary asm text). That is a large, separable subsystem.
3. **operand/constraint model**: register-class constraints (`reg`, `"={rax}"`,
   `in("rdi")`), clobber lists, and `volatile` semantics — reference Rust's `asm!`
   operand grammar and Zig's `: [ret] "={x0}" (-> usize)` — require a register-
   allocator interface for asm operands.

So the **release-safe path is the named-opcode intrinsic family** (section 2). The
text-block form is recorded here as the long-horizon design; it is gated on a
frozen-seed reflow and an in-tree assembler, neither of which may land behind
release-integrity today.

## 4. ladder

- **rung 0 (shipped)**: `__hx_syscall0/6` — raw `syscall`/`svc`.
- **rung 1 (this PR)**: `__hx_asm_nop` end-to-end (bind + x86 + arm64 + C-transpile +
  arm64 NOP byte-encoding) + stdlib `asm.hexa` native-intrinsic-name registry
  (interpreter-tested) — the first byteeq-safe inline-asm intrinsic.
- **rung 2**: `__hx_asm_pause` / `__hx_asm_fence` (+ emitter `pause`/`mfence`/`dmb`
  encodings). spin-loop + barrier — the highest-value portable subset.
- **rung 3**: `__hx_asm_rdtsc` / arm64 `mrs cntvct_el0` — cycle counter (one-output).
- **rung 4 (wall)**: general `@asm` native lowering with operand binding; then the
  `asm!{"text"}` block — gated on frozen-seed reflow + in-tree assembler.

## 5. hexa-specific strength (beyond reference-parity)

Because hexa emits native objects directly (no LLVM) and is a **byte-identical
self-host fixpoint**, an `__hx_asm_*` intrinsic is *deterministically* placed in the
instruction stream — the same intrinsic call yields the same bytes across gen3≡gen4,
so an inline-asm-bearing runtime primitive can be byteeq-gated like any other leaf
(no opaque LLVM `MachineInstr` between source and bytes). The syscall-floor campaign
already exploits this; inline-asm intrinsics inherit it for free.

## 6. release-safety invariants (must hold for every rung)

- new builtin names are **ADD-only** to `_bind_builtin_names`; the compiler closure
  never calls them -> DEFAULT emit byte-identical, `gen3 ≡ gen4` preserved.
- no new keyword / no new `@attr` (frozen parser `151c52c8` untouched).
- emitter byte-table additions are zero-operand opcodes, dead unless a program opts in.
- byteeq proof is **CI** (x86_64-linux · arm64-linux · darwin-arm64), not local (mini =
  git/gh only). Each rung's PR must show 3-target byteeq GREEN before merge.
