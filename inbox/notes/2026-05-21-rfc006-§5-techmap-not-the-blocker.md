# rfc_006 §5 — techmap is NOT the closure blocker (verdict, 2026-05-21)

**Status**: dead-end-avoidance note. No code change landed by this cycle.
**Layer**: closure-cycle premise check.
**Cross-link**: `2026-05-21-rfc006-§5-multibit-width-truncation.md` (the canonical bisection).

## TL;DR

A closure cycle was framed as "the 1638 `_const0_` cells in the mapped BLIF
are missing-techmap placeholders; extend `pass_techmap_sky130` to cover
`$add` / `$sub` / `$mux` / `$eq` / etc." That framing is **falsified by the
input BLIF cell histogram**. The techmap is already complete for every
cell type the input contains. The 1638 `_const0_` rows are ABC's
**constant-folding response to dangling latch D-input nets** caused by
Source 2 (combinational 1-bit-tolerance in `read_verilog::_rv_elab_expr`),
not by a missing cell-type lowering.

## Evidence

Mini (arm64 Mac) measurement, 2026-05-21 19:58 (commits at `5facfedc`):

```
$ ssh mini grep -E "^.gate" /tmp/_hexa_yosys_gate_d4_in.blif | awk '{print $2}' | sort | uniq -c | sort -rn
    83 sky130_fd_sc_hd__buf_1
    77 sky130_fd_sc_hd__mux2_1
    67 sky130_fd_sc_hd__and2_1
    45 sky130_fd_sc_hd__xnor2_1
    27 sky130_fd_sc_hd__inv_1
    12 sky130_fd_sc_hd__fa_1
     5 sky130_fd_sc_hd__xor2_1
   ─── total 316 cells, ALL prefixed sky130_fd_sc_hd__ ───
```

```
$ ssh mini grep -E "^.gate" /tmp/_hexa_yosys_gate_d4_out.blif | awk '{print $2}' | sort | uniq -c | sort -rn
  1638 _const0_
     5 sky130_fd_sc_hd__nor2_1
     5 sky130_fd_sc_hd__nand2_1
     5 _const1_
```

Zero `$<cell_type>` references in the input. `pass_techmap_sky130` has
nothing left to map. The 1638 `_const0_` outputs are ABC's
constant-folding response, one per `.latch` row, because the latch's
**D-input net has no driver in the input BLIF**.

Spot-check (`rr_ptr__d__b0`):

- Latch (in the input BLIF after Option I expansion):
  `.latch rr_ptr__d__b0 rr_ptr__b0 re clk 2`
- Searching `X=rr_ptr__d__b0` (i.e., who drives that D-input): **no result**.
- Only driver of `rr_ptr__d` (1-bit scalar) is:
  `.gate sky130_fd_sc_hd__buf_1 A=$procmux_y$rr_ptr__d$0 X=rr_ptr__d`

The combinational fan-out that should split the 3-bit `rr_ptr__d` into
`__b0/__b1/__b2` per-bit drivers is missing. So the latch reads from
nowhere; ABC ties it to `_const0_` and propagates the constant.

Aggregate: 150 distinct `$rvexpr$N` nets are **referenced** in the input
BLIF, but only **71 have drivers** (`X=$rvexpr$N`). 79 dangling nets are
the population from which the 1638 `_const0_` rows are generated after
register-bit expansion.

## Why this is exactly Source 2 from the prior note

`inbox/notes/2026-05-21-rfc006-§5-multibit-width-truncation.md`:

> ### Source 2 — `_rv_parse_port_decl` creates a single wire per slot,
> hiding bit-level identity
>
> Stores width as a wire attribute, but downstream the 2-D LHS emit
> (`_rv_emit_body_v2`) and `_rv_parse_always` bare-path create exactly
> ONE `$dff`/`$mux` per slot, never expanding per-bit. Combinational
> `$xor` / `$and` / `$mux` cells emitted by `_rv_elab_expr` similarly
> assume 1-bit operands (per the L739 comment "Wire widths are recorded
> as 1 here — a follow-up pass elaborates real widths; the generic cells
> are width-tolerant").

Option I (commit `df4ff3f7`) expanded **only the latch side** (Q-side, 1-bit
`.latch` BLIF requirement). The D-side combinational fan-in still emits
1-bit-tolerant cells. So every multi-bit register has W parallel
`.latch` rows that share a SINGLE undriven D-net per bit.

## Hazard for the next cycle

A naïve "fix" — emit `W-1` extra `buf_1` cells that fan the scalar D-net
to each `__b<k>` slot — would inflate the cell count and area histogram
toward the oracle, but the design is **semantically wrong**: every bit
of the multi-bit register receives the SAME 1-bit value, not the real
per-bit fan-out. Modern ABC will collapse the bufs to identity and the
area lift would be a g3 over-claim. Do not land that.

Equally, "add `$add` / `$sub` / `$mux` to `pass_techmap_sky130`" is a
no-op because the input BLIF does not contain those cell types (they
were lowered upstream already).

## Real closure path

Per the canonical bisection note: **Option II or Option III**.

- **Option II** — `read_verilog._rv_parse_port_decl` + `_rv_elab_expr` +
  `_rv_emit_body_v2` + `_rv_parse_always` refactored to be width-aware
  (emit P × D × W 1-bit wires + W cells per multi-bit expression).
  ~300-500 LOC. Closes Source 1 and Source 2 together.
- **Option III** — emit RTLIL `$mem` / `$memrd` / `$memwr` cells per the
  patch body in `inbox/patches/yosys-fifo-mem-2d-array-memwr-emit.md`,
  then a `synth_memory_dff` pass consolidates to substrate shape. The
  ±5 % gate is achievable per the patch body's claim. ~400-700 LOC.

Either is multi-cycle. Single-cycle ±5 % closure is **not on the table**
without a g3 over-claim.

## Status at handoff

- Pre-fix d4: 32829 µm², 1638 `_const0_`, 15 real sky130 cells.
- Pre-fix d6: 45937 µm², 2292 `_const0_`.
- Oracle: d4=61763 µm² ±5% [58754, 64939]; d6=93609 µm² ±5% [91102, 100692].
- Source 1 closure (Option I, `df4ff3f7`): landed.
- Source 2 closure (Option II or III): not yet landed; gates remain at
  53.2 % (d4) and 49.1 % (d6) of oracle.

g3: honest closure > over-claimed closure. This cycle's deliverable
is the verdict, not a fake area lift.
