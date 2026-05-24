# origins/hexa-rtl — NOT hexa-lang source

> **Files in this subtree carry a `.hexa` extension but are Verilog /
> SystemVerilog RTL DSL, not hexa-lang.** Do not feed them to
> `hexa parse` / `hexa build` / `hexa run` — those will fail by design.

## What's actually here

The `rtl/*.hexa` and `sim/tb_*.hexa` files in this directory use:

- `rtl module NAME { ... }` — Verilog module declaration
- `input / output / inout / wire / reg : bit / bits(N)` — port + net decls
- `always_ff @(posedge clk) { ... }` — clocked process
- `always_comb { ... }` — combinational process
- `<=` non-blocking assignment
- `instance NAME: MOD { .port(sig), ... }` — module instantiation
- Sized literals: `10'd1085`, `24'h0`, `6'b000000`
- `posedge` / `negedge` edge specifiers

None of these are hexa-lang constructs. The `Makefile` next to this
README confirms the intent: the files are fed to **Icarus Verilog**
(`iverilog -g2005-sv`) and **Yosys** (`read_verilog`). The Makefile
assumes a `.hexa → .v` transpilation step that does not currently
exist in either hexa-lang or hexa-chip.

## Why is this in hexa-lang then?

This subtree is an Option-A absorption snapshot from 2026-05-10
(see `firmware/README.md` §F4 batch absorb), pulled from
`~/core/hexa-chip/origins/hexa-rtl/` (the master). The hexa-lang
copy is **a frozen mirror**, retained so the `firmware/boards/chip/`
view of the chip board is self-contained. It is not consumed by the
hexa-lang compiler or any other in-tree tool.

## Scope decision (2026-05-19)

Per @I id001 (hexa-lang = "native compiler with atlas-bound theorems"),
@F f2 (no third-party-codegen backend), and @D g7 (downstream owns its
own domain), **RTL DSL is not a hexa-lang feature and will not become
one**. Three options were considered (`docs/notes/2026-05-19-rtl-dsl-scope-decision.md`):

| Option | Verdict |
|---|---|
| A. Implement RTL DSL in hexa-lang | rejected — out of scope per id001 + f2 |
| B. Move RTL ownership to ~/core/hexa-chip | ★ selected (already there; this dir = mirror) |
| C. Stub-parse `rtl module {}` as opaque | rejected — silent no-op would over-claim |

## What this means in practice

- **Parse-gate sweeps**: skip `firmware/boards/chip/origins/hexa-rtl/{rtl,sim}/*.hexa`.
  These files are external Verilog DSL by construction.
- **Editing**: the canonical SSOT is `~/core/hexa-chip/origins/hexa-rtl/`.
  Do not edit this mirror; let it follow the next absorption refresh.
- **Future cleanup (recommended for hexa-chip session)**: rename
  `*.hexa → *.v` in the master tree. The Makefile's
  `$(RTL_SRCS:.hexa=.v)` rule already presumes that final extension;
  the rename removes the lie and the parse-gate trip together.

## Cross-refs

- `docs/notes/2026-05-19-rtl-dsl-scope-decision.md` — full decision record
- `compiler/PLAN.md` — single-line cycle log entry
- `~/core/hexa-chip/origins/hexa-rtl/` — canonical upstream of this content
