# rfc_006 §5 — Phase 3d RE-LANDED (T67/T68/T69 PASS · §5 still OPEN)

**Date** : 2026-05-20
**Branch / commit** : `rfc-073-phase-3d-relanded` (rebase of closed PR #229 `7f13cedb`)
**Status** : `OPEN` — Phase 3d functionally re-landed against current `main`;
§5 oracle remains 0.0 µm² because Phase 3d alone closes only TWO of
the four §5-critical-path blockers (and not the ones that fire in
router_d4 / router_d6).

## Why a re-land was needed

PR #229 closed `2026-05-20` after parallel sessions (commits `7575a79d`
"#4h-b multi-LHS body dyn-idx LHS + T52", `7f97aaab` "#4h-a multi-LHS
body static-idx LHS + T51", and the ALWAYS-body collapse around it)
landed an equivalent — but stylistically different — implementation
of PIECE 2 (multi-LHS no-else cond-mux with dyn-idx LHS) inline in
the `_rv_parse_always` multi-LHS handler. The 7f13cedb commit used a
deferred-flag approach (`dyn_emit` / `dyn_idx_toks` / `dyn_bound2`
captured then emitted later); the parallel-session shape did the
emit inline with `ri_start = -1` skip-marker.

Functionally identical, but the conflict block was non-trivial to
auto-merge. PR #229 closed unmerged. This re-land carries only the
piece that was NOT yet covered:

- **PIECE 1** — bare clocked dyn-LHS demux in
  `_rv_parse_always` top-level statement fall-through (the single-
  statement, no outer `if` case). That site on current `main` still
  emitted a single `$dff(Q=name)` (no index) when `_rv_eval_expr`
  failed to const-fold the LHS index. T67 (P=3 scalar) / T68 (P=4
  begin/end) exercise this directly.

- **T67 / T68 / T69 selftests** — the falsifier triplet from the
  original 7f13cedb commit. T69 verifies the multi-LHS dyn-idx LHS
  (PIECE 2) which `7575a79d` already implemented but did not ship
  its own dedicated 6/6/6/6 falsifier (T52 covers a 4/4/4/4 shape).

## What this commit lands

`stdlib/kernels/logic_synth/read_verilog.hexa`:

1. **Bare clocked dyn-LHS demux** at `_rv_parse_always` line ~3728+
   (after parallel-session insertions shifted the canonical line
   from 3667 → 3728). Tracks `had_brack` + `idx_folded` +
   `idx_toks_saved` through the optional `[ <expr> ]` LHS parser,
   then — when the bracket was present AND the index didn't const-
   fold AND `_rv_array_bound(m, q_base) > 0` — emits a per-element
   `$eq + $mux + $dff` chain × P and `continue`s. Falls through to
   the legacy single-cell emit on unknown bound (diagnostic-blame
   stays on the array decl rather than the write site).

2. **T67 / T68 / T69 selftests** in `main()` after T66 — three
   falsifier-anchored shape tests.

selftest count : **69/69 → 72/72 PASS** on current `main`. No
regression in T1..T66.

@cite IEEE 1364-2005 §9.5 sequential block + §10.4.2 procedural
assign + Yosys `passes/proc/proc_mux.cc` demux shape.

## §5 oracle outcome (re-measured)

```
[gate] router_d4 area=0.0 µm² oracle=61763 µm²   Δ=100.0%  FAIL (±5%)
[gate] router_d6 area=0.0 µm² oracle=93608.5 µm² Δ=100.0%  FAIL (±5%)
```

Identical to the pre-Phase-3d baseline. The mapped BLIF still
contains 0 `$dff` cells. ABC ties every `out_data[i]` / `out_valid[i]`
to `_const0_`.

## g3-honest: §5 is OPEN — Phase 3d is NOT the closure layer

The same finding the original 7f13cedb commit reported. Re-measured
against current main with the bare-clocked PIECE 1 now firing:
the §5 RTL still doesn't hit either Phase 3d path because the
critical writes are buried two structural levels deeper than what
Phase 3d covers:

```verilog
always @(posedge clk) begin
    if (rst) begin
        rr_ptr <= 3'd0;
        for (pp = 0; pp < P; pp = pp + 1) begin
            fifo_head[pp] <= 0;
            fifo_tail[pp] <= 0;
            out_valid[pp] <= 1'b0;
        end
    end else begin
        for (pp = 0; pp < P; pp = pp + 1) begin
            if (in_valid[pp] && !fifo_full[pp]) begin
                fifo_mem[pp][fifo_tail[pp][FIFO_LD-1:0]] <= in_data[pp]; // 2-D dyn
                fifo_tail[pp] <= fifo_tail[pp] + 1;
            end
        end
        for (pp = 0; pp < P; pp = pp + 1) out_valid[pp] <= 1'b0;
        if (any_grant) begin
            out_data [grant_out] <= fifo_peek[grant_in];  // 1-D dyn ← THE KEY
            out_valid[grant_out] <= 1'b1;
            fifo_head[grant_in]  <= fifo_head[grant_in] + 1;
            rr_ptr               <= (grant_in + 1) % P;
        end
    end
end
```

The outer `if (rst) ... else begin <for>; <for>; if (any_grant) ... end`
is a with-else, mismatched-arm-shape if. The with-else handler at
`read_verilog.hexa:3131` requires both branches to be parallel
`simple-name <= rhs` sequences. Mismatched here → handler bails →
both arms drop. The inner `if (any_grant) begin out_data[grant_out]
<= … end` IS Phase 3d-T69-shaped, but it never reaches the multi-
LHS extension because the enclosing with-else has already consumed
its tokens.

## The NEW (post-Phase-3d) §5 blocker layer

Items #1, #2, #4 from the original 7f13cedb status note remain the
critical path. Re-named here for `rfc006-§5-PHASE-3e-OPENER`:

1. **F-RFC-RV-CLOCKED-FOR-INDEXED-LHS** —
   `for (i=0; i<P; i=i+1) name[i] <= rhs(i);` inside posedge-always.
   `_rv_emit_for_if_stmts` (read_verilog.hexa:1947 era) rejects every
   statement whose `stmt[1] != "<="` or `"="`, i.e. every indexed-LHS
   write. Fix: extend per-stmt classifier to detect `name [ … ]` LHS,
   unroll the loop, emit one `$dff(Q=name[k])` per iteration with
   `k = init + step*i`. Selftest P=3 → 3 $dff with Q=name[0..2].

2. **F-RFC-RV-WITH-ELSE-NONMATCHING-BODIES** — `if (rst) <reset shape>
   else <run shape>` where arms are structurally different (one has
   a for-loop, the other has nested ifs). Fix: when LHS sequences
   don't match, decompose into single-arm cond-muxes — `if (cond) <reset
   body>` + `if (!cond) <run body>` — and recurse on each arm via a
   shared single-arm helper. Each arm re-enters if/for/multi-LHS
   dispatch at the same outer always level.

3. **F-RFC-RV-2D-DYN-LHS** — `fifo_mem[pp][k] <= data;`. Phase 3d's
   1-D demux does not recurse into the inner `[k]` once outer `[pp]`
   is unrolled. Functional but NOT on the §5 area critical path.

4. **F-RFC-RV-NESTED-IF-INSIDE-ELSE-BODY** — `if (rst) ... else begin
   <for>; <for>; if (any_grant) begin <dyn-LHS> end end`. The inner
   `if (any_grant)` is Phase-3d-T69-shaped but must be REACHED via
   #2 first.

§5 closure path = land #1 + #2 + #4 together (shared helper). #3 is
deferred (fifo_mem is internal, not directly probed by §5 oracle).

## Numbers (g3-honest)

- read_verilog selftests : **69/69 → 72/72 PASS** (+3 falsifier-anchored
  tests, no regression in T1..T66).
- §5 oracle areas : **0.0 µm² → 0.0 µm²** (NO change vs. main).
- §5 router area Δ from oracle : router_d4 **−100.0%** · router_d6
  **−100.0%** (vs. ±5% gate).
- LoC delta : **+131** in `read_verilog.hexa` (one bare-path demux
  block + three selftests). PIECE 2 from 7f13cedb skipped — already
  on main via `7575a79d` with stylistic divergence; functionally
  equivalent.

## Conflict resolution recap

Original 7f13cedb modified one region (the multi-LHS no-else cond-mux
fall-through near line 3078) AND a separate region (the bare always
body near line 3667). Parallel-session work on main (`7575a79d` and
predecessors) overwrote the multi-LHS region with a different
implementation of the SAME behavior. Resolution:

- **Multi-LHS region** : keep `main`'s version (newer, fully inline).
  T52 already on main; T69 in this commit cross-verifies it under a
  larger array bound.
- **Bare always region** : apply the original `had_brack` / `idx_folded`
  / demux block from 7f13cedb verbatim. This region was unmodified
  by parallel sessions.

`hexa-parse` + selftest runs are the gate (compiled path, `g_interp_deprecated`).

## Citations

- IEEE Standard 1364-2005 (Verilog HDL) §9.5 — Sequential block
- IEEE Standard 1364-2005 (Verilog HDL) §10.4.2 — Procedural assign
- Yosys `passes/proc/proc_mux.cc` — `$mux` feedback-hold demux

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
