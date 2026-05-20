# RFC 073 — read_verilog procedural-mux scope expansion (rfc_006 §5 absorption-gate closure path)

- status: **OPENER — RFC DRAFT + SCAFFOLD ONLY** (no behavior change this cycle)
- created: 2026-05-20
- authority:
  - iter 13 verdict: PR #183 squash `9ea50568`
    ("cell-chain Shape-A pattern (iters 1-13) is COMPLETE … Structural
    Shape-B (read_verilog procedural-mux scope) remains and is
    multi-cycle.")
  - iter 12 (a): PR #180 squash `11078398` — `pass_clean_multidriver`
    is the iter-12 mechanism that today collapses condition-guarded
    writes to last-wins (the surface this RFC must displace for
    structural correctness on router_d{4,6}).
- consumer: `stdlib/yosys/gate_record.hexa` §5 absorption-gate
  (router_d4 / router_d6 area oracles, currently OPEN)
- shape: **B** per `@D g_inbox_processing_loop` (multi-cycle work; this
  dispatch ships RFC + scaffold + phasing + falsifiers — NOT
  implementation)

---

## §1 Problem — where the §5 oracle bleeds

After 13 cell-chain / connect-row iters (PRs #130-#183), the §5
absorption pipeline accepts router_d{4,6} all the way through ABC
`read_blif; strash; map`. The ABC-rejection layer is closed.

What remains open is the **§5 area oracle**:

```
router_d4 area=0.0 µm²  oracle=61763 µm²  Δ=100.0%  FAIL (±5%)
router_d6 area=0.0 µm²  oracle=…          Δ=100.0%  FAIL (±5%)
```

The 0.0 µm² result is honest, not a regression: ABC mapped the design's
outputs to `_const0_` / `_const1_` zero-area cells because by the time
RTLIL reaches ABC the design outputs no longer have live combinational
drivers. The drivers are dropped *upstream* — in `read_verilog.hexa` —
because the procedural-statement scope is too narrow to elaborate the
shapes that the synthesizable router body uses:

- `always @(*)` blocks with `if`/`else` chains and `case` statements
  driving combinational outputs;
- **Condition-guarded multi-driver** writes that today are collapsed
  by `pass_clean_multidriver` to last-wins (correct for true conflicts;
  *incorrect* for `if (cond) y = a; else y = b;` which is a `$mux`, not
  a conflict);
- **Array-indexed assignments** of the form `grant[i] = …` inside a
  `for (i = 0; i < N; i = i + 1)` loop — today these need either
  static unrolling with constant `i` (already supported via
  generate-for) or per-index gated writes (not supported), so the
  router's grant generation lowers to nothing.

The iter-13 verdict named the three blockers verbatim; this RFC
operationalises them.

## §2 Goals

- **G-073-0** — `always @(*)` blocks elaborate into RTLIL `$mux` cells
  for the *combinational-procedural* shape (if/else chains, case
  statements), without crossing into latch / clock-gating territory.
- **G-073-1** — Condition-guarded multi-driver writes flow through a
  new `pass_proc_mux` pass that converts the per-driver `(condition,
  rhs)` set into a `$mux` tree **before** `pass_clean_multidriver`
  collapses them, so the lowered RTLIL preserves the if/else
  semantics instead of last-wins.
- **G-073-2** — Array-indexed assignment `mem[K] = expr` is lowered
  to a per-index `$eq`/`$mux` selector chain for runtime-K and to a
  direct `connect mem[K], expr` for constant-K (the latter already
  works today via generate-for unroll; this RFC just makes the
  runtime-K path correct).
- **G-073-3** — On router_d{4,6}, §5 area oracle measures within
  ±5 % of 61 763 µm² (d4) and the d6 sibling, OR an honest mismatch
  report names the next blocker layer. This RFC **does not prejudge
  closure** — it only commits to firing the gate after each phase
  and reporting g3-honestly.
- **G-073-4** — Zero behavior change on the existing self-tests
  T1-T34+ in `read_verilog.hexa` self-test main (the current passing
  shapes — single-statement always, generate-for, indexed-LHS with
  const idx — keep passing byte-for-byte).

## §3 Atlas-citable references (@D g6)

The implementation is clean-room (no source copy from upstream); the
following anchor the design:

- **IEEE Std 1364-2005 §9.2** — procedural assignments (blocking vs
  non-blocking; intra-assignment delay; LHS forms). Defines the
  semantic equivalence of `if (c) y = a; else y = b;` to a 2-arm mux
  when both arms cover the LHS unconditionally.
- **IEEE Std 1364-2005 §9.5** — `case` / `casez` / `casex` statements
  (parallel vs priority case; full / parallel pragmas). The parallel
  case form maps directly to a one-hot mux; the priority case maps to
  a chained mux.
- **IEEE Std 1800-2017 §10.4.2** — `always_comb`, `always_latch`,
  `always_ff` discrimination. The phase-1 implementation targets the
  combinational subset (`always @(*)` + `always_comb`); latch
  inference and clock-gating are out of scope.
- **Yosys Manual Ch. 5 §5.41** — `proc_mux` pass reference (synthesis
  reference: described behaviour only, not source). Names the canonical
  output: each procedural LHS gets one `$mux` tree per always-block,
  with sensitivity gating handled separately by `proc_clean`/`proc_dff`.
- **Yosys upstream src** `passes/proc/proc_mux.cc` — used as
  *implementation reference* for the lowering algorithm (case/if
  unification → branched assignment graph → `$mux` tree).
  **Clean-room translation, not source copy.** This RFC re-derives the
  algorithm from the IEEE spec and the documented behaviour; the
  upstream file is named here only so future readers can compare the
  *behaviour* (the ISC-licensed source is not copied into the repo).

## §4 Three phases (multi-cycle; one PR per phase, each gated)

### Phase 1 — `pass_proc_mux` skeleton for if/else chains

**Scope:**
- Walk every `Module` in the design; for each, walk procedural
  records (collected during `_rv_parse_always` with sensitivity `*`).
- For each LHS appearing under one or more `if/else` arms, emit a
  `$mux` cell with `S = cond_wire`, `A = else_rhs`, `B = then_rhs`,
  `Y = lhs`. Multi-arm `if/else if/else` cascades into a left-deep
  `$mux` tree.
- **Replace** today's `pass_clean_multidriver` short-circuit for the
  condition-guarded case: when both writes of an LHS have a guarding
  `if` condition, route through `pass_proc_mux` first; only true
  unguarded multi-drivers (a genuine conflict — same LHS written by
  two unconditional assigns in different always-blocks) still flow
  into `pass_clean_multidriver`.
- Validation fixture: a 6-line minimal Verilog
  (`tests/fixtures/proc_mux/if_else_2arm.v`) — **NOT router_d4** for
  phase 1. router_d{4,6} is the phase-3 fixture.

**Falsifiers fired this phase:**
- `F-RFC-RV-PROC-MUX-IF-ELSE` (mandatory)
- `F-RFC-RV-PROC-MUX-NESTED` (mandatory)

**Non-goals (phase 1):**
- `case` statements (phase-1.5 follow-on within the same RFC).
- Array-indexed writes (phase 2).
- `always_ff` / clocked always (already partially supported, untouched).

### Phase 1.5 — `case` statement lowering (parallel + priority)

Same `pass_proc_mux` infrastructure, extended to absorb `case`
statements as one-hot or priority `$mux` trees per IEEE 1364-2005
§9.5. May land within the same PR as phase 1 if review remains small,
otherwise as a follow-up cycle. Phase 1.5 gates on
`F-RFC-RV-PROC-MUX-CASE`.

### Phase 2 — array-indexed assignment lowering

**Scope:**
- `mem[K] = expr` where `K` is a runtime expression (not const-foldable):
  emit a per-index chain
  ```
  for i in 0..N:
      sel_i  = $eq(K, i)
      next_i = $mux(S=sel_i, A=mem[i], B=expr)
      mem[i] = next_i      // always-block re-assign per-index
  ```
  Total cell cost = N `$eq` + N `$mux` per write site.
- `mem[K] = expr` where `K` is const-foldable: route to today's path
  (single `connect mem[K], expr`); no regression.

**Falsifier fired this phase:** `F-RFC-RV-ARRAY-INDEX`.

**Non-goals:** packed-array slicing `mem[hi:lo]`, struct field
writes (those would need rfc_006 §4 phase-c which is separately
scheduled).

### Phase 3 — re-target router_d{4,6} + §5 oracle measurement

**Scope:**
- Run the §5 absorption-gate (`gate_record.hexa --lib …sky130…`)
  end-to-end on router_d4 and router_d6.
- Compare measured area to the iter-13 oracle constants (61 763 µm²
  d4; d6 sibling).
- **CLOSED** if both deltas are within ±5 %.
- **HONEST MISMATCH** if either delta is outside ±5 %: name the next
  blocker layer (cells dropped, wires undriven, etc.) and either
  open phase 4 or hand off back to user.

**Falsifier fired this phase:** `F-RFC-RV-§5-CLOSURE` (the only one
that can declare §5 closed — failure here ≠ phase-1/2 falsifier
failure; it's a measurement layer).

**Non-goals (phase 3):** standard-cell library tuning, ABC `map`
target switching, or any change to `abc_map.hexa` / `passes.hexa` /
`liberty.hexa`. The §5 closure is *one* outcome, not the only RFC
acceptance criterion: a g3-honest mismatch report also closes the
RFC by surfacing the next layer.

## §5 Falsifier battery

| ID                              | Phase | What it measures                                                                                       |
| ------------------------------- | ----- | ------------------------------------------------------------------------------------------------------ |
| `F-RFC-RV-PROC-MUX-IF-ELSE`     | 1     | 2-arm `if (c) y=a; else y=b;` lowers to **exactly one** `$mux` cell with S=c, A=b, B=a, Y=y           |
| `F-RFC-RV-PROC-MUX-NESTED`      | 1     | Nested `if (c1) if (c2) y=a; else y=b; else y=d;` lowers to a 2-level `$mux` tree (3 mux cells)        |
| `F-RFC-RV-PROC-MUX-CASE`        | 1.5   | 4-arm `case (sel) 2'b00:…; 2'b01:…; 2'b10:…; default:…; endcase` lowers to a balanced 3-mux tree       |
| `F-RFC-RV-ARRAY-INDEX-CONST`    | 2     | `mem[3] = expr` with const-K stays a single `connect mem[3], expr` (no mux chain)                      |
| `F-RFC-RV-ARRAY-INDEX-RUNTIME`  | 2     | `mem[K] = expr` with runtime-K emits N×`$eq` + N×`$mux` per write site, N = array width                |
| `F-RFC-RV-§5-CLOSURE`           | 3     | router_d4 area ∈ [61 763 ± 5 %] µm² **AND** router_d6 area ∈ [oracle ± 5 %] µm² — OR honest mismatch   |
| `F-RFC-RV-NO-REGRESSION`        | all   | All current T1-T34+ self-tests in `read_verilog.hexa::main` keep passing (byte-eq stdout)              |

Falsifier execution rules:
- Each falsifier is implemented as a self-test row added to
  `read_verilog.hexa::main` (per the rfc_003 idiom already used for
  T1-T34+).
- Phase-N PR lands **only if** that phase's falsifier(s) PASS plus
  `F-RFC-RV-NO-REGRESSION`.
- `F-RFC-RV-§5-CLOSURE` is the gate; "closed" requires PASS, "honest
  mismatch" requires FAIL with a named next-blocker. Either outcome
  closes the RFC.

## §6 Scaffold landed this cycle (zero behavior change)

This RFC opener lands the markers and a no-op stub so phase-1
implementation has a known insertion point and doesn't need to
re-discover the file structure:

1. `stdlib/kernels/logic_synth/read_verilog.hexa` — added file-header
   note pointing here (under existing SCOPE block).
2. `stdlib/kernels/logic_synth/read_verilog.hexa::_rv_parse_always`
   — added `// RFC 073 SCAFFOLD: pass_proc_mux site` comment marker at
   the if/else cond-mux detection block.
3. `stdlib/kernels/logic_synth/read_verilog.hexa::_rv_parse_assign`
   — added `// RFC 073 SCAFFOLD: array-indexed assign` comment marker
   at the LHS-`[…]` parse site.
4. `stdlib/kernels/logic_synth/read_verilog.hexa` — added a
   `pass_proc_mux(d: Design) -> Design` no-op stub (returns input
   unchanged) so phase-1 has a typed function symbol to fill in.

All four landings are pure documentation / no-op insertion. The
parse-gate (`hexa_real parse stdlib/kernels/logic_synth/read_verilog.hexa`)
passes before and after; the byte-eq guarantee for the self-test
stdout is preserved (no new test rows added by the opener).

## §7 Honest scope (@D g3)

- This RFC is the **OPENER**, not the implementation. Closing the
  §5 oracle gate is *one possible outcome* across 2-4 cycles; the
  RFC commits to *firing the falsifiers* and reporting g3-honestly,
  not to a guaranteed closure.
- Cell-chain Shape-A pattern (iters 1-13) is closed; this RFC
  acknowledges the next layer is structural and re-derives the
  upstream proc-pass behaviour clean-room.
- The implementation reference to `passes/proc/proc_mux.cc` names
  the upstream file for behavioural comparison only; no source is
  copied. The clean-room provenance block at the top of
  `read_verilog.hexa` already records this idiom (lines 11-28); this
  RFC extends the same idiom to the proc_mux scope.
- The phase boundaries are deliberately small (one falsifier per
  phase) so each PR is reviewable in isolation. If phase 1 surfaces
  that the if/else infrastructure already in `_rv_parse_always`
  (lines 1914+ — cond-mux detection) is sufficient and only the
  multi-driver collapse needs displacement, phase 1 may land as a
  surgical edit instead of a new pass; the RFC accommodates that
  outcome.

## §8 Sign-off

- **OPENER LANDED** 2026-05-20 — RFC + scaffold + phasing + falsifier
  battery filed. Branch: `rfc-read-verilog-proc-mux-shape-b`. PR #188
  squash `c1f078f3`.
- **PHASE 1 LANDED** 2026-05-20 — branch `rfc-073-phase-1-proc-mux`.
  `pass_proc_mux` real implementation in
  `stdlib/kernels/logic_synth/passes.hexa` (was no-op stub in
  read_verilog.hexa); `Module` gains parallel `connect_cond` array
  (`stdlib/kernels/logic_synth/rtlil.hexa`); nested else-if chain
  inline handler in `_rv_parse_always`. Falsifiers
  `F-RFC-RV-PROC-MUX-IF-ELSE`, `F-RFC-RV-PROC-MUX-NESTED`,
  `F-RFC-RV-NO-REGRESSION` all PASS (passes.hexa T33/T34/T35 +
  read_verilog.hexa T55/T56 + rtlil.hexa T11). Self-tests:
  rtlil 10/10→11/11, passes 32/32→35/35, read_verilog 54/54→56/56.
- **PHASE 1.5**: not yet landed.
- **PHASE 2**: not yet landed.
- **PHASE 3**: not yet landed.
- **§5 absorption-gate**: **STILL OPEN** — Phase 1 did NOT close §5.
  Post-Phase-1 oracle re-run shows router_d4 area=0.0 µm² (Δ=100%)
  and router_d6 area=0.0 µm² (Δ=100%). Next blocker surfaced (per
  g3-honest report in compiler/PLAN.md): runtime-K array-indexed
  assignment in the router's `idx` grant generation (Phase 2 target,
  `F-RFC-RV-ARRAY-INDEX-RUNTIME`). Phase 1 ships the proc-mux
  primitive ($mux emission for condition-guarded writes + nested
  if-else-if-else chains), not the §5 closure.
