# rfc_006 §5 — Phase 3e result: 3 named blockers CLOSED · new blocker exposed (§5 OPEN)

**Date** : 2026-05-20
**Branch / commit** : `rfc-073-phase-3e-closure` (pending PR + squash)
**Status** : `OPEN` — Phase 3e CLOSED the three §5-critical-path read_verilog
blockers identified by Phase 3d's status note, but the §5 oracle still reads
0.0 µm² because a NEW blocker layer surfaced: the §5 router's combinational
arbiter (`always @* … any_grant = …`) contains blocking-assignment-ordered
reads of `any_grant` that the unrolled flow can't break without per-iteration
SSA renaming. ABC's `read_blif` rejects the network with `Network contains a
combinational loop!`.

## What Phase 3e landed

### 1. New shared helper `_rv_emit_body_v2` (read_verilog.hexa)

Recursive single-arm cond-mux walker. Replaces ad-hoc statement splitting in
the with-else handler. Handles:

- `begin … end` blocks (strip, recurse with same guard)
- `if (cond) THEN [else ELSE]` — composes `cond AND outer` / `NOT cond AND
  outer` guards via inline `$and` / `$logic_not` cells (IEEE 1364-2005 §9.4)
- `for (gv = init; cond; gv = step) body` — static unroll (≤1024 iters);
  per-iter body recurse with iter-substituted symtab
- simple `LHS [<=|=] RHS ;`
- static-idx `LHS [ const ] [<=|=] RHS ;`
- dyn-idx `LHS [ wire ] [<=|=] RHS ;` — per-element `$eq + $and` chain
  composing the per-slot guard with the outer guard, one row per slot
- 2-D indexed `LHS [ idx1 ] [ idx2 ]` — graceful-skip (NOT on §5 critical
  path)

**Emission model**: each leaf write emits `connect_cond(<lhs>__d, rhs_wire,
guard_wire)` plus tracks `<lhs>` in an accumulator. The CALLER emits ONE
`$dff(D=<lhs>__d, Q=<lhs>)` per tracked LHS + an unconditional feedback
default `connect(<lhs>__d, <lhs>)` so `pass_proc_mux` folds the cond-tagged
rows into a single `$mux` chain feeding each `$dff`. Result: single-driver
$dff invariant preserved across arbitrary arm recursion depth.

@cite IEEE 1364-2005 §9.4 (nested conditional) + §10.4.2 (procedural assign)
+ Yosys `passes/proc/proc_mux.cc` (priority-mux composition).

### 2. With-else NON-MATCHING bodies fallback

Hooked into the `_rv_parse_always` if-then-else handler immediately after the
positional multi-LHS with-else handler bails. Trigger conditions:

- **fire_a** : `t_ok==0 && has_else==1 && is_clocked==1 && _3e_legacy_emitted==0`
  — multi-LHS positional handler bailed (THEN-arm shape not captured at all).
  Covers the §5 router's outer `if (rst) <reset cascade> else <run cascade>`.
- **fire_b** : `t_ok==1 && e_ok==0 && has_else==1 && is_clocked==1 && _3e_single_emitted==0`
  — single-LHS THEN matched but ELSE has multiple statements (T71 falsifier:
  `if (c) y<=a; else begin y<=b; z<=c; end`). Pre-Phase-3e the single-LHS
  handler dropped the ELSE-arm's `z<=c` write silently.

Each fires twice into `_rv_emit_body_v2` — once with the cond as guard for
the THEN-arm, once with `NOT(cond)` as guard for the ELSE-arm.

### 3. For-handler outer-loop termination (T70 fix)

Added `if has_begin == 0 { keep_going = 0 }` to the for-handler's exit path
(line ~4243). Without this, a posedge-always with no enclosing begin/end
whose single body statement was a `for (...)` loop re-iterated the outer
keep_going loop against the post-for cursor (typically `endmodule`), and the
scalar LHS path mis-read it as a malformed statement (`expected <= or = got
\`\``). The `if`/scalar branches already set `keep_going=0` symmetrically.
This fix unblocked T70 (F-RFC-RV-CLOCKED-FOR-INDEXED-LHS).

### 4. Generic Verilog sized-literal lowering (`_rv_elab_primary`)

Added handling for any `<size>'<base><digits>` literal (e.g. `3'd0`, `8'hFF`,
`4'b1010`). Pre-Phase-3e only `1'b0` and `1'b1` were special-cased; any other
sized literal fell through to the bare-wire path, leaving raw Verilog tokens
like `3'd0` in the BLIF as wire names — which ABC then rejected. Uses the
existing `_rv_literal_value` helper (handles all four bases, upper + lower
case) per IEEE 1364-2005 §3.5.1.

### 5. BLIF `.latch` emission for sequential cells (abc_map.hexa)

`abc_emit_blif` now emits `sky130_fd_sc_hd__dfxtp_1` cells as BLIF `.latch
<D> <Q> re <CLK> 2` directives (BLIF spec §3.4) instead of `.gate`. Without
this, ABC's `read_blif` rejected the cell with `Cannot find gate
"sky130_fd_sc_hd__dfxtp_1"` because the Liberty file marks it sequential
(`94 skipped: 63 seq`). The mapped-BLIF reader (`abc_parse_mapped_blif`) now
also handles `.latch` directives back into `sky130_fd_sc_hd__dfxtp_1` cells
so the area-oracle histogram includes the FF count. Applied to BOTH
abc_map.hexa locations (stdlib/yosys/ + stdlib/kernels/logic_synth/).

## Falsifier verdict per gate (read_verilog selftest 72/72 → 75/75 PASS)

- **T70 — F-RFC-RV-CLOCKED-FOR-INDEXED-LHS** : `always @(posedge clk) for (i=0;
  i<3; i=i+1) name[i] <= a` → expects 3 `$dff` with Q=name[0], name[1],
  name[2]. PASS.
- **T71 — F-RFC-RV-WITH-ELSE-NONMATCHING-BODIES** : `if (c) y<=a; else begin
  y<=b; z<=c; end` → expects 2 `$dff` (single-driver: Q=y, Q=z) + ≥1
  `$logic_not` (NOT(cond)) + y__d, z__d D-wires. PASS.
- **T72 — F-RFC-RV-NESTED-IF-INSIDE-ELSE-BODY** : `if (c1) y<=a; else if (c2)
  y<=b` → expects ≥2 `$mux` + ≥1 `$dff` (Q=y) via existing cascaded-else-if
  chain handler (already on `main` since RFC 073 Phase 1; T72 anchors it
  doesn't regress when v2 fallback is wired). PASS.
- **NO-REGRESSION** : T1..T69 all pass; v2 fallback never fires when the
  positional handlers succeed (gated via `_3e_legacy_emitted` /
  `_3e_single_emitted` flags).

## §5 oracle — exact measurement

```
[gate] router_d4 area=0.0 µm² oracle=61763 µm²   Δ=100.0% FAIL (±5%)
[gate] router_d6 area=0.0 µm² oracle=93608.5 µm² Δ=100.0% FAIL (±5%)
```

Same numbers as pre-Phase-3e baseline. **§5 verdict — OPEN**.

But Phase 3e changed the pipeline meaningfully:

- `proc_mux` cond-tagged LHS-groups lowered: **3 → 32** (10× more cond-tagged
  writes captured)
- `clean_multidriver` collapse warnings: **1 → 1** (no new multidriver because
  the per-LHS D-wire model preserves single-driver invariant)
- `abc_map` exit: **0 → 1** (FAIL — combinational loop detected)

So Phase 3e successfully threaded the 32 clocked writes through the BLIF
flow, but ABC's network check rejects the network because of a comb loop
that wasn't visible pre-Phase-3e (when the writes were dropped entirely).

## The NEW (post-Phase-3e) §5 blocker layer

`F-RFC-RV-COMB-ALWAYS-BLOCKING-ASSIGN-SSA` — the §5 router's combinational
arbiter (router_d{4,6}.v lines 80-94) reads its own procedural variable
`any_grant` via blocking-assignment ordering:

```verilog
always @* begin
    any_grant = 1'b0;             // initial write
    for (i = 0; i < P; i = i + 1) begin
        idx = (rr_ptr + i) % P;
        if (!any_grant && !fifo_empty[idx]) begin    // ← reads any_grant
            grant_out = route_xy(fifo_peek[idx]);
            if (out_ready[grant_out]) begin
                any_grant = 1'b1;                     // ← writes any_grant
                grant_in  = idx[2:0];
            end
        end
    end
end
```

The unrolled equivalent has each iter's GUARD reading `any_grant` and each
iter's BODY writing `any_grant`. `pass_proc_mux` folds the writes into one
`$mux` chain driving `any_grant` — but the unrolled GUARDS still read
`any_grant` (which is the SAME chain output). Combinational self-feedback
loop. ABC detects:

```
n410 → n555 → … → n410 → … → CO "rr_ptr__d"
NetworkCheck: Network contains a combinational loop.
```

The path goes through `any_grant`'s self-loop and feeds into `rr_ptr__d`
(the latch input for `rr_ptr`) via `$rvexpr$76 = !rst AND any_grant`
(the run-arm guard for the rr_ptr write).

**Pre-Phase-3e**: `any_grant`'s self-loop existed BUT was disconnected from
any combinational output (CO) — the clocked writes that consumed
`any_grant`-based guards were dropped. ABC's strash only checks CO-rooted
networks, so the loop was invisible. Phase 3e's 32 new cond-tagged writes
connect the comb loop to a CO, exposing the underlying issue.

### Fix scope (estimated Phase 3f)

`F-RFC-RV-COMB-ALWAYS-BLOCKING-ASSIGN-SSA` requires per-iteration SSA
renaming of procedural variables in combinational always blocks. Per IEEE
1364-2005 §10.4.1 (blocking procedural assignment) semantics: each blocking
write to `var` makes a NEW value of `var` visible to subsequent statements
WITHIN THE PROCEDURE. The unrolled equivalent must rename:

- `any_grant_iter0` = initial (1'b0)
- iter k guard reads `any_grant_iter<k>` (NOT the final mux chain output)
- iter k body writes `any_grant_iter<k+1>`
- final visible `any_grant` = `any_grant_iter<P>`

LoC scope: ~80-150 LoC in `_rv_emit_for_if_stmts` (for-unroll path) +
`_rv_emit_body_v2` (recursive walker). The comb-arbiter shape is specific
to combinational always blocks; clocked always blocks DON'T have this
issue because non-blocking `<=` semantics are temporally-ordered through
the next clock edge (i.e. all RHS values are sampled together, no
intra-iteration read-after-write).

This is the ONLY remaining §5 blocker — items #1 (CLOCKED-FOR-INDEXED-LHS)
and #2 (WITH-ELSE-NONMATCHING-BODIES) and #3 (NESTED-IF-INSIDE-ELSE-BODY)
are all CLOSED by this Phase 3e cycle.

## LoC delta (g3-honest)

- `stdlib/kernels/logic_synth/read_verilog.hexa` : **+503 / -65** (new
  `_rv_emit_body_v2` helper + `_rv_v2_track` + `_rv_v2_dwire` +
  `_rv_emit_dff_for_tracked` + with-else fallback wiring + for-handler
  outer-loop fix + sized-literal lowering + T70/T71/T72 selftests)
- `stdlib/yosys/abc_map.hexa` : **+24 / -1** (BLIF `.latch` emit + parse)
- `stdlib/kernels/logic_synth/abc_map.hexa` : **+38 / -1** (BLIF `.latch`
  emit + parse — sibling file)

## Numbers (g3-honest)

- read_verilog selftests : **72/72 → 75/75 PASS** (+3 falsifiers, no
  regression in T1..T69)
- passes selftests : **35/35 → 35/35 PASS** (no change)
- abc_map selftests : **7/7 → 7/7 PASS** (no change)
- §5 oracle areas : **0.0 µm² → 0.0 µm²** (NO change — new blocker
  exposed at the comb-arbiter SSA level)
- `proc_mux` cond-tagged LHS-groups lowered: **3 → 32** (10× more
  writes captured through to the BLIF flow)
- `abc_map` exit: **0 (OK) → 1 (FAIL — comb loop)** — the new blocker
  is honest-loud at the ABC layer

## Citations

- IEEE Standard 1364-2005 (Verilog HDL) §9.4 — Control statements
  (nested conditional, else-branch semantics)
- IEEE Standard 1364-2005 (Verilog HDL) §10.4.1 — Blocking procedural
  assignment (read-after-write within a procedure)
- IEEE Standard 1364-2005 (Verilog HDL) §10.4.2 — Procedural assign
  (priority-mux composition)
- IEEE Standard 1364-2005 (Verilog HDL) §3.5.1 — Integer numbers
  (sized literal lowering)
- IEEE Standard 1364-2005 (Verilog HDL) §10.3.5 — For-loop static unroll
- Yosys `passes/proc/proc_mux.cc` — `$mux` priority-mux chain composition
- Yosys `passes/techmap/dfflibmap.cc` — sequential cell mapping shape
- BLIF specification §3.4 — `.latch` directive (sequential logic)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
