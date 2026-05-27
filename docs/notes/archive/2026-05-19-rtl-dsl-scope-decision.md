# 2026-05-19 — RTL DSL scope decision: NOT a hexa-lang feature

> Status: **resolved-ssot** (Option B selected, deprecation marker landed)
> Source: residual #5 from session 2026-05-19 (parser surfaced `rtl module ...`)
> Authority: @I id001 (hexa-lang = "native compiler with atlas-bound theorems"),
>            @F f2 (no third-party-codegen backend), @D g7 (downstream owns its own).

## Trigger

Parsing `firmware/boards/chip/origins/hexa-rtl/rtl/hexa_edge_top.hexa` with
`hexa parse` fails on line 29:

```
rtl module hexa_edge_top {
    input clk: bit
    ...
}
```

The parser does not recognize `rtl` as a keyword; it falls back to lexing
`rtl module hexa_edge_top` as a label (`d1085` from line 27's
`10'd1085` Verilog literal is also a label-parse miss) and rejects every
subsequent `input`, `output`, `wire`, `reg`, `always_ff`, `instance` decl.

## Affected files (mirror, not master)

All inside the hexa-lang tree are under
`firmware/boards/chip/origins/hexa-rtl/` (a 2026-05-10 Option-A absorption
snapshot from `~/core/hexa-chip/origins/hexa-rtl/`):

| File | LoC | Construct |
|---|---|---|
| `rtl/hexa_edge_top.hexa`     | 347 | top SoC |
| `rtl/riscv_n6_core.hexa`     | 591 | CPU |
| `rtl/egyptian_mem_ctrl.hexa` | 182 | mem ctrl |
| `rtl/hexalang_decoder.hexa`  | 199 | keyword CAM |
| `rtl/snn_izhikevich.hexa`    | 236 | SNN |
| `rtl/egyptian_moe.hexa`      | 203 | MoE router |
| `sim/tb_hexa_edge.hexa`      | 445 | testbench |
| **Total**                    | 2203 | — |

The same content is present at `~/core/hexa-chip/origins/hexa-rtl/` verbatim
(checked 2026-05-19: identical file list, same `rtl module` constructs).

## Key observation — these are Verilog/SystemVerilog sources with `.hexa` extension

The Makefile next to them (`firmware/boards/chip/origins/hexa-rtl/Makefile`)
feeds the files directly to **Icarus Verilog** and **Yosys**:

```make
$(IVERILOG) $(IV_FLAGS) -o $(SIM_OUT) $(TB_SRC) $(RTL_SRCS)   # *.hexa → iverilog
$(YOSYS) -p "read_verilog $(RTL_SRCS:.hexa=.v); ..."          # rename .hexa→.v
```

`IV_FLAGS := -g2005-sv -Wall` — Verilog-2005 / SystemVerilog. The `.hexa`
extension is misleading: the **content** is Verilog DSL (`always_ff`,
`always_comb`, `input/output/wire/reg`, `posedge`, `instance ...`, `10'd1085`
sized literals). No `.hexa → .v` transpiler exists anywhere in either tree.
The Makefile presupposes one, but it is unimplemented.

Inside the hexa-lang compiler / stdlib / self trees the construct `rtl module`
appears **nowhere**. Only `rtl_generator.hexa` references it by string,
and that file is real hexa-lang code that emits Verilog into `*.v` outputs.

## Three options considered

- **A. Implement an RTL DSL in hexa-lang.** Full Verilog-like sub-grammar
  (`rtl module`, `input/output/wire/reg`, `always_ff`/`always_comb`,
  `instance ... {}`, sized literals like `10'd1085`, `posedge`, `<=`
  non-blocking assignment) + a `.hexa → .v` backend. This violates @I id001
  ("native compiler with atlas-bound theorems" — RTL is not in scope) and
  @F f2 (no third-party-codegen backend). It is also a multi-cycle PR by
  itself, not a residual.
- **B. Move RTL ownership to `~/core/hexa-chip`.** ★ selected.
  RTL hardware-description is a chip-design domain. `~/core/hexa-chip` is
  the canonical downstream that already holds an identical
  `origins/hexa-rtl/` subtree. hexa-lang's `firmware/boards/chip/origins/`
  is an absorption mirror, not the authority. Mark it so future parse-gate
  sweeps don't trip on Verilog content masquerading as `.hexa`.
- **C. Stub-parse `rtl module ... { ... }` as an opaque block.** Token-swallow
  from `LBrace` to matching `RBrace`. parse-gate passes but the compiler
  does nothing semantically — silent no-op. g3 (real-limits-first, no
  over-claim) makes this dishonest: a passing parse-gate would imply
  hexa-lang accepts RTL, when in fact it ignores it.

**Adopted: B.** No parser change. The `firmware/boards/chip/origins/hexa-rtl/`
subtree is left in place (it's a frozen absorption snapshot) but tagged as
**external Verilog DSL · not hexa-lang source** via a `RTL_DSL_NOT_HEXA.md`
marker in the directory, and the parent `firmware/README.md` is annotated
to call out the convention exception for `origins/hexa-rtl/*.hexa`.

## Recommendation to a future hexa-chip session

If hexa-chip wants real `.hexa`-native hardware description, the work
belongs there, not in hexa-lang. Two paths:

- **Long-form**: file an upstream patch at `~/core/hexa-lang/inbox/patches/`
  proposing an RTL DSL RFC (probably never approved — see @F f2 + @I id001).
- **Short-form (recommended)**: rename `*.hexa` to `*.v` in the
  `origins/hexa-rtl/rtl/` subtree of hexa-chip (and let the absorption
  snapshot here follow on the next refresh). The Makefile already
  assumes a `.hexa → .v` transpilation step that doesn't exist; renaming
  removes the lie and the parse-gate trip simultaneously. Owner: hexa-chip.

This note is the upstream-side closure of residual #5. It is **not** a
patch to be applied — it documents that the issue was investigated, the
correct home identified, and the deprecation marker installed.

## Cross-refs

- `firmware/README.md` — annotated to call out `origins/hexa-rtl/*.hexa`
  as external Verilog DSL, not hexa-lang.
- `firmware/boards/chip/origins/hexa-rtl/RTL_DSL_NOT_HEXA.md` — new
  in-place marker so anyone re-parsing the subtree gets the same answer.
- `compiler/PLAN.md` — single-line cycle log entry.
- @I id002 (upstream-position) — hexa-chip is downstream; this note flows
  hexa-chip-ward, not the inverse.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
