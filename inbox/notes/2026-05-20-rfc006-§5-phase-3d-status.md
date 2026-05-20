# rfc_006 §5 — Phase 3d landing status (NOT YET CLOSED)

**Date** : 2026-05-20
**Branch / commit** : `rfc-073-phase-3d-clocked-array` (pending PR + squash)
**Author** : Phase 3d sub-agent (Opus 4.7 / 1M context)
**Status** : `OPEN` — Phase 3d delivered the one remaining clocked-LHS
dyn-idx demux drop-site that wasn't covered by the parallel-landed
PR #220 (sub-step #4h-b / T52, commit 7575a79d). §5 remains BLOCKED on
deeper structural read_verilog gaps that are out of Phase 3d scope.

## Concurrent landing acknowledged

While Phase 3d was being worked, commit `7575a79d` (PR #220) landed
`#4h-b multi-LHS body dyn-idx LHS + T52` on origin/main — an
essentially-identical extension to the multi-LHS no-else cond-mux
handler at `read_verilog.hexa:3001`. Phase 3d's original "piece #2"
was a duplicate of that work and has been dropped on rebase. The
bare-path fix (piece #1) is unique to Phase 3d.

## What Phase 3d landed (reconciled scope)

`stdlib/kernels/logic_synth/read_verilog.hexa` — **one** surgical
extension to the clocked-LHS path:

**Bare clocked dyn-LHS demux** (`_rv_parse_always` body fall-through,
lines ~3728-3791 on origin/main pre-fix). Pre-fix: when the LHS had
an indexed form `name [ K ]` with `K` a runtime wire that did NOT
const-fold, the code set `q = q_base` (no index) and emitted a single
`$dff(Q=name)` — silently dropping every per-cycle write to the
indexed slot. Post-fix: per-element `$eq(A=K, B=i, Y=eq_y_i) +
$mux(A=name[i], B=rhs, S=eq_y_i, Y=mux_y_i) + $dff(CLK=clk,
D=mux_y_i, Q=name[i])` chain × P where `P = _rv_array_bound(m, name)`.

This is the **demux complement** of the array-READ `$eq/$mux/$dff`
chain at `read_verilog.hexa:2933` (PR #174), now lowered into the
always-body top-level fall-through site. The site fires when the
dyn-LHS write is NOT inside any `if` guard — i.e. unguarded
sequential write, which is rare in practice but the canonical
"bare" Phase 3d shape.

Covered by **T67** (scalar elements, P=3, single statement, no
`begin`/`end`) and **T68** (begin/end wrapping, P=4). Both PASS;
no regression in T1..T66 (origin/main was 69/69 PASS pre-Phase-3d,
now 71/71 PASS).

@cite IEEE 1364-2005 §9.5 sequential block + §10.4.2 procedural
assign + Yosys `passes/proc/proc_mux.cc` demux.

## What Phase 3d did NOT close — §5 oracle still reads 0.0 µm²

`hexa-run stdlib/yosys/gate_record.hexa` after Phase 3d (and after
PR #220's #4h-b T52):

```
[gate] router_d4 area=0.0 µm² oracle=61763 µm² Δ=100.0% FAIL (±5%)
[gate] router_d6 area=0.0 µm² oracle=93608.5 µm² Δ=100.0% FAIL (±5%)
```

Identical to the pre-Phase-3d baseline. The §5 mapped BLIF still
contains 0 `$dff` cells; ABC ties all `out_data[i]` / `out_valid[i]`
to `_const0_` because every clocked write to them remains dropped.

**g3 honesty**: §5 is OPEN, NOT CLOSED. Neither the Phase 3d
bare-path fix NOR the PR #220 multi-LHS #4h-b extension is fired by
the actual router_d{4,6} RTL, because the dyn-LHS writes are buried
two structural levels deeper:

```verilog
always @(posedge clk) begin
    if (rst) begin
        rr_ptr <= 3'd0;
        for (pp = 0; pp < P; pp = pp + 1) begin
            fifo_head[pp] <= 0;       // static-idx in for-body
            fifo_tail[pp] <= 0;       // static-idx in for-body
            out_valid[pp] <= 1'b0;    // static-idx in for-body
        end
    end else begin
        for (pp = 0; pp < P; pp = pp + 1) begin
            if (in_valid[pp] && !fifo_full[pp]) begin
                fifo_mem[pp][fifo_tail[pp][FIFO_LD-1:0]] <= in_data[pp];  // 2-D dyn
                fifo_tail[pp] <= fifo_tail[pp] + 1;                       // static-idx
            end
        end
        for (pp = 0; pp < P; pp = pp + 1) out_valid[pp] <= 1'b0;
        if (any_grant) begin
            out_data [grant_out] <= fifo_peek[grant_in];   // 1-D dyn (T52 shape, but...
            out_valid[grant_out] <= 1'b1;                  //         ...gated by outer
            fifo_head[grant_in]  <= fifo_head[grant_in] + 1; //       with-else)
            rr_ptr               <= (grant_in + 1) % P;
        end
    end
end
```

The outer `if (rst) ... else begin ... end` is a **with-else** multi-
statement if. Its handler at `read_verilog.hexa:3131` requires both
branches to be parallel sequences of `simple-name <= rhs` statements
— mismatched here (THEN has a for-loop; ELSE has two for-loops + a
nested `if (any_grant)`). The handler bails silently, dropping both
arms entirely.

The inner `if (any_grant) begin out_data[grant_out] <= …; … end` is
exactly the shape PR #220's T52 (#4h-b multi-LHS dyn-idx) covers —
but it never reaches that handler because the enclosing with-else
handler already consumed it as opaque tokens before bailing.

## Remaining §5 blockers (must land for §5 closure)

Each item ships with a falsifier in `read_verilog.hexa`'s selftest
catalogue under the convention used by T57..T68.

1. **F-RFC-RV-CLOCKED-FOR-INDEXED-LHS** — `for (i=0; i<P; i=i+1)
   name[i] <= rhs(i);` inside a posedge-always. `_rv_emit_for_if_stmts`
   (`read_verilog.hexa:1947`) rejects every statement whose `stmt[1]
   != "<="` or `"="` — i.e. every indexed-LHS write. Fix scope: extend
   the per-statement classifier to detect `name [ … ]` LHS and unroll
   the loop iteration, emitting one `$dff(Q=name[k])` per iteration
   with `k = init + step*i`. Selftest: P=3 expected 3 $dff with
   Q=name[0], name[1], name[2].

2. **F-RFC-RV-WITH-ELSE-NONMATCHING-BODIES** — `if (rst) begin <reset
   shape> end else begin <run shape> end` where the two arms are
   structurally different (one has a for-loop, the other has nested
   ifs). Currently the with-else handler at `read_verilog.hexa:3131`
   matches LHS sequences positionally; on mismatch it silently drops
   BOTH bodies. Fix scope: when bodies don't match, decompose into
   `<reset arm>: if (cond) <reset body>` + `<run arm>: if (!cond)
   <run body>` and recurse on each arm via a single-arm cond-mux
   helper. Each arm then re-enters the if/for/multi-LHS dispatch
   tree at the same outer always level.

3. **F-RFC-RV-NESTED-IF-INSIDE-ELSE-BODY** — `if (rst) ... else begin
   <for-loop>; <for-loop>; if (any_grant) begin <dyn-LHS writes> end
   end`. The inner `if (any_grant)` is exactly what PR #220's #4h-b
   T52 covers, but it must be REACHED first by a fix that lets
   `_rv_emit_for_if_stmts` (or an equivalent multi-stmt walker)
   recurse into the else-body of the outer if, not bail at its top.

4. **F-RFC-RV-2D-DYN-LHS** — `fifo_mem[pp][k] <= data;` two-level
   array indexing on the LHS. Neither Phase 3d's bare-path fix nor
   PR #220's multi-LHS extension recurses into the inner `[k]` once
   the outer `[pp]` is resolved by a hypothetical fix #1. Fix scope:
   after outer-static unroll resolve `fifo_mem[pp]` to `fifo_mem_pp`
   (or per-port wires already declared in the array decl), then
   re-apply the 1-D demux to the inner index.

Items 1, 2, 3 are the §5 critical path. Item 4 is needed for the
fifo_mem write, which is functional but not on the §5 area critical
path (writes to fifo_mem aren't directly probed; their effects flow
through fifo_peek, which IS probed via the `assign` chain — already
working pre-Phase-3d, see `in_ready[N]` buf chain in the BLIF).

## Recommended next cycle (Phase 3e)

Land **#1 (for-loop indexed-LHS unroll) and #2 (with-else
non-matching bodies)** together. They share a common helper —
single-arm cond-mux that recurses into a body — and together they
unblock items #3 + #4. Estimated SSOT delta: ~150 LoC inside
`read_verilog.hexa`'s `_rv_parse_always` + `_rv_emit_for_if_stmts`.
No changes to `passes.hexa`, `abc_map.hexa`, or `gate_record.hexa`
needed for §5 to close.

## Numbers (g3-honest)

- read_verilog selftests: **69/69 → 71/71 PASS** (+T67/T68, no regression).
- §5 oracle areas: **0.0 µm² → 0.0 µm²** (NO change).
- BLIF cell count: **99 → 99 gates** (NO new $dff for the §5 router).
- LoC delta: **+105** in `read_verilog.hexa` (one bare-path block,
  two selftests).

## Citations

- IEEE Standard 1364-2005 (Verilog HDL) §9.5 — Sequential block
- IEEE Standard 1364-2005 (Verilog HDL) §10.4.2 — Procedural assign
- Yosys `passes/proc/proc_mux.cc` — `$mux` feedback-hold demux shape
  (also @cite'd at `read_verilog.hexa:2935` for the array-READ chain)

## Lessons (inbox dup-race precheck — feedback memory)

Per the `inbox_dup_race_precheck` feedback note (2026-05-19), I
SHOULD have grep-gated for active concurrent work on the multi-LHS
dyn-idx path before producing the (now-dropped) duplicate piece #2.
Cost of the dup: ~one revision cycle on the rebase. Cost of NOT
gating: would have shipped two near-identical implementations.
Outcome: clean reconciliation; future cycles should `git log
--oneline origin/main -10 -- <file>` before starting work on a
high-traffic file.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
