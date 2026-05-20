# rfc_006 §5 — Phase 3d RE-LAND tail: T69 cross-verifier (§5 OPEN, NOT YET CLOSED)

**Date** : 2026-05-20
**Branch / commit** : `rfc-073-phase-3d-relanded` (rebase of closed PR #229 `7f13cedb`
on current `main` after PR #233 `5a0327bb` already landed PIECE 1)
**Status** : `OPEN` — Phase 3d PIECE 1 (bare clocked dyn-LHS demux) +
T67/T68 landed by PR #233 ahead of this re-land. This commit carries
only the missing falsifier — **T69**, the multi-LHS dyn-idx LHS
P=3 cross-verifier — and the honest §5 oracle re-measurement.

## What this commit adds (delta vs. current `main`)

Only one new falsifier:

- **T69 — F-RFC-RV-DYN-LHS-MULTI-LHS-IF (P=3 cross-verifier).**
  `always @(posedge clk) if (en) begin y[k] <= a; z[k] <= b; end`
  with two output arrays of bound 3 and a runtime index `k`. Expected
  per IEEE 1364-2005 §9.5 + §10.4.2: per-element `$eq + $and + $mux +
  $dff` chain × 2 statements × P=3 = **$eq=6, $and=6, $mux=6, $dff=6**.
  T52 (already on `main` via `7575a79d`) verifies the same shape at
  P=4. T69 cross-verifies at P=3.

selftest count : **71/71 → 72/72 PASS** on current `main`. Zero
regression in T1..T68.

## Why the original PR #229 closed unmerged

PR #229 (commit `7f13cedb`) bundled three deliverables:

1. **PIECE 1** — bare clocked dyn-LHS demux at `_rv_parse_always`
   top-level fall-through. → **Landed via PR #233 `5a0327bb` on
   2026-05-20** (parallel-session work).

2. **PIECE 2** — multi-LHS no-else cond-mux with dyn-idx LHS
   (deferred-flag style: `dyn_emit` / `dyn_idx_toks` / `dyn_bound2`).
   → **Landed via PR #216-era commit `7575a79d` on 2026-05-20**
   (different style: inline emit with `ri_start = -1` skip-marker).

3. **T67 / T68 / T69 selftest triplet.** → T67 + T68 landed with
   PR #233; T69 NOT included. This commit adds T69.

The PR #229 close was correct: PIECE 1 (now on `main` via PR #233)
and PIECE 2 (now on `main` via `7575a79d`) are both already present.
Only T69 — the multi-LHS dyn-idx LHS P=3 falsifier — was orphaned.

## §5 oracle outcome (re-measured on current `main` + T69)

```
[gate] router_d4 area=0.0 µm² oracle=61763 µm²   Δ=100.0%  FAIL (±5%)
[gate] router_d6 area=0.0 µm² oracle=93608.5 µm² Δ=100.0%  FAIL (±5%)
```

Identical to pre-Phase-3d baseline. Phase 3d alone (PIECE 1 + PIECE 2)
does NOT close §5. **§5 verdict — OPEN.**

The §5 router_d{4,6} RTL fires neither Phase 3d path because the
critical dyn-LHS writes (`out_data[grant_out] <= …`) are buried two
structural levels deeper than what Phase 3d covers — inside an
outer `if (rst) ... else begin <for>; <for>; if (any_grant) ...
end` whose with-else handler bails on mismatched arm shapes.

## The NEW (post-Phase-3d) §5 blocker layer

Per the original 7f13cedb status note (re-confirmed by today's
re-measure):

1. **F-RFC-RV-CLOCKED-FOR-INDEXED-LHS** — `for (i=0; i<P; i=i+1)
   name[i] <= rhs(i);` inside posedge-always. `_rv_emit_for_if_stmts`
   rejects indexed-LHS statements; needs per-stmt classifier
   extension + loop unroll + per-iteration `$dff` emit.

2. **F-RFC-RV-WITH-ELSE-NONMATCHING-BODIES** — `if (rst) <reset>
   else <run>` with structurally-different arms. Current handler
   matches LHS sequences positionally; drops BOTH arms on mismatch.
   Fix: single-arm cond-mux decomposition + shared recursion helper.

3. **F-RFC-RV-NESTED-IF-INSIDE-ELSE-BODY** — `if (rst) ... else
   begin <for>; <for>; if (any_grant) <dyn-LHS> end`. Phase-3d-T69-
   shaped but must be REACHED via #2 first.

4. **F-RFC-RV-2D-DYN-LHS** — `fifo_mem[pp][k] <= data;`. NOT on §5
   area critical path (fifo_mem internal). Defer.

§5 closure path = land #1 + #2 + #3 together (shared single-arm
cond-mux helper). Est. ~150 LoC in `_rv_parse_always` +
`_rv_emit_for_if_stmts`. No changes needed to `passes.hexa` /
`abc_map.hexa` / `gate_record.hexa` for §5 closure.

## Numbers (g3-honest)

- read_verilog selftests : **71/71 → 72/72 PASS** (+1 falsifier-anchored
  test, no regression in T1..T68).
- §5 oracle areas : **0.0 µm² → 0.0 µm²** (NO change vs. main).
- §5 router area Δ from oracle : router_d4 **−100.0%** · router_d6
  **−100.0%** (vs. ±5% gate).
- LoC delta : **+40** in `read_verilog.hexa` (just T69).

## Citations

- IEEE Standard 1364-2005 (Verilog HDL) §9.5 — Sequential block
- IEEE Standard 1364-2005 (Verilog HDL) §10.4.2 — Procedural assign
- Yosys `passes/proc/proc_mux.cc` — `$mux` feedback-hold demux

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
