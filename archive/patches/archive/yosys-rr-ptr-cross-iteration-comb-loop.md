# `stdlib/kernels/logic_synth/read_verilog.hexa` — `rr_ptr__d` cross-iteration combinational loop survives PR #247

**Severity**: high (blocks rfc_006 §5 area-oracle parity gate for
  router_d4 + router_d6 — `Yosys absorbed=true` cannot be claimed)

**Layer**: hexa-native read_verilog frontend / RTLIL unroll +
  proc_mux fold path

**Reporter**: rfc_006 §5 measurement audit 2026-05-21 KST
  (`~/core/demiurge/YOSYS.md` Tier-1 item (d)). Discovered while
  manually invoking substrate `abc -c "read_lib SKY130 ; read_blif
  <hexa-emit>"` after the abc_map.hexa script-order fix + ABC
  binary detection fix landed in PR #247 (`cdfa8d46`).

**Status**: resolved-ssot (2026-05-21) — RFC 073 Phase 3g · `_rv_ssa_rewrite_preloop_for` in stdlib/kernels/logic_synth/read_verilog.hexa rewrites pre-loop direct writes from `connect(s, X)` to `connect(s__ssa0, X)`, suppresses the alias when ≥1 rewrite happened. ABC `NetworkCheck` no longer flags `rr_ptr__d` comb-loop for router_d{4,6} (both `abc_map: ok`, exit 0). §5 area-oracle remains OPEN (~99 % UNDER) — new blocker is Tier-1 (e) `fifo_mem` 2-D memwr. T75 falsifier landed; T74 updated to assert Phase 3g semantics. See inbox/notes/2026-05-21-rfc006-§5-phase3g-rrptr-closed.md.

## Symptom

After PR #247's intra-iteration SSA fix closed the blocking-LHS
chain comb-loop class (`idx__ssa1..5`, `any_grant__ssa5`,
`grant_out__ssa5` chains visible in `clean_multidriver` log), ABC's
`read_blif` + `NetworkCheck` still rejects both router_d4 and
router_d6 with:

```
$ abc -c "read_lib <SKY130.lib> ; read_blif /tmp/_hexa_yosys_gate_d4_in.blif"
Library "sky130_fd_sc_hd__tt_025C_1v80" from "…" has 334 cells
Warning: Detected 9 multi-output cells (for example, "sky130_fd_sc_hd__fa_1").
Warning: Constant-0 drivers added to 40 non-driven nets in network "router_d4":
fifo_mem[0], fifo_mem[1], fifo_mem[2], fifo_mem[3] ...
Network "router_d4" contains combinational loop!
Node "n272" is encountered twice on the following path to the COs:
 n272 -> n608 -> n277 -> n246 -> n225 -> n591 -> n251 -> n602
       -> n260 -> n604 -> n266 -> n606 -> n272 -> n448 -> n452
       -> n454 -> n592 -> n594 -> n596 -> n598 -> n600 -> n254
       -> n585 -> n587 -> n609 -> n611 -> CO "rr_ptr__d"
NetworkCheck: Network contains a combinational loop.
Io_ReadBlifMv: The network check has failed for model router_d4.
Reading network from file has failed.
```

d6 has the same shape with `n372 -> ... -> n372 -> ... -> CO
"rr_ptr__d"` (~30 hops vs d4's ~15).

The cycle terminates at the **D-input of the round-robin pointer
flop** (`rr_ptr__d`), and goes through anonymous BLIF gate nodes
(`n272`, `n608`, ...) that are post-ABC `strash`/`map`-renamed
versions of our hexa-native emit-side wires.

## Source pattern that triggers it

`comb/rtl/router_d4.v` L72-94 + L96-123. Two `always` blocks:

```verilog
reg [2:0] rr_ptr;
integer i, idx;
reg [2:0] grant_in;
reg [2:0] grant_out;
reg       any_grant;

always @* begin                           // combinational arbiter
    any_grant = 1'b0;
    grant_in  = 3'd0;
    grant_out = 3'd0;
    for (i = 0; i < P; i = i + 1) begin   // P=5; unroll target
        idx = (rr_ptr + i) % P;           // reads rr_ptr (flop Q)
        if (!any_grant && !fifo_empty[idx]) begin
            grant_out = route_xy(fifo_peek[idx]);
            if (out_ready[grant_out]) begin
                any_grant = 1'b1;
                grant_in  = idx[2:0];
            end
        end
    end
end

always @(posedge clk) begin               // sequential
    if (rst) rr_ptr <= 3'd0;
    else if (any_grant)
        rr_ptr <= (grant_in + 1) % P;     // writes rr_ptr (flop D)
end
```

Logically:
  `rr_ptr_Q` → `idx[i]` → `grant_out[i]` → `grant_in[final]`
              → `rr_ptr_D` (inside flop ← broken by $dff)

No combinational cycle should exist — the $dff between Q and D
breaks any feedback. So ABC's report points at an *emit-side*
artifact: somewhere in our RTLIL unroll, the Q net and the D net
(or some intermediate) end up connected combinationally without
the $dff in the middle.

## Hypotheses (ranked by likelihood)

1. **Per-LHS D-wire feedback default vs. SSA-renamed body**: per
   `read_verilog.hexa` L2206 + L2859, the emit pattern is `connect
   (lhs__d, lhs)` as the unconditional hold-default that
   `pass_proc_mux` folds into the mux chain. If `lhs` here is the
   *original* `rr_ptr` Q wire AND the cond-tagged rows reference
   `rr_ptr` reads via SSA-versioned mirror wires (e.g.
   `rr_ptr__ssa0`, `rr_ptr__ssa1`, …) that are then `connect`-tied
   back to `rr_ptr`, a cycle can form: rr_ptr → idx_via_rr_ptr_ssaN
   → ... → rr_ptr__d ← feedback connect ← rr_ptr.
   - check: dump the RTLIL and look for `connect rr_ptr$something
     rr_ptr` rows; check if `rr_ptr` appears as both a write target
     and a re-read source inside the unrolled body.

2. **`grant_in` multi-driver collapse via last-wins → loses
   condition info**: `grant_in = idx[2:0]` is written in 5 unrolled
   iterations, each guarded by `(!any_grant_iterN && !fifo_empty
   [idx_iterN] && out_ready[grant_out_iterN])`. PR #247's SSA fix
   filtered to read-then-write LHS only — `grant_in` is write-only
   inside the body, so it didn't get renamed. The 5 multi-drivers
   go through `clean_multidriver` last-write-wins collapse (the log
   should show this — VERIFY by re-running the chain post-cycle-66).
   If the kept-driver is iteration-5's guarded `grant_in`, but the
   guard for iter-5 reads `any_grant__ssa5` which transitively
   reads `idx__ssa1..5` which read `rr_ptr`, then the path
   `rr_ptr → idx_ssaN → any_grant_ssaN → guard → grant_in →
   rr_ptr__d` is unbroken combinatorially.
   - check: the cycle in ABC's error report has ~15 hops for d4
     (P=5 unroll). 5 iterations × 3 cells/iter (idx, mux, guard)
     ≈ 15 hops. This roughly matches.
   - speculative fix: SSA-rename `grant_in` similarly (`grant_in
     __ssa1..5`) even though it's write-only in body — the rename
     would isolate each iteration's `grant_in` so the multi-driver
     collapse picks the conditionally-correct one without
     transitively threading the loop-carried dependency.

3. **`fifo_empty[idx_ssaN]` array indexing introduces extra path**:
   `fifo_empty[i]` is `assign`-driven (L50: `(fifo_head[p] ==
   fifo_tail[p])`), so `fifo_empty[idx_ssaN]` selects a
   combinationally-computed signal via a dynamic-index mux. The mux
   address is `idx_ssaN`, which reads `rr_ptr`. If `fifo_empty`'s
   driver in turn reaches back to `rr_ptr` through (unlikely but
   possible) path, that closes the loop.
   - check: trace `fifo_empty[*]` drivers in the emitted RTLIL.
     They should be a pure function of `fifo_head`/`fifo_tail` (other
     flops), not `rr_ptr`. If yes, this hypothesis is killed.

## Suggested investigation (in order)

1. **Re-measure with abc_map honesty PR #255** (post-cycle-66 mac
   binary release): run `HEXA_EXEC_NO_SHELL=1 hexa run stdlib/yosys
   /gate_record.hexa` after clearing stale `_out.blif` — expect
   either area > 0 (loop somehow vanished — unlikely but possible
   with combined fixes), or fail-loud with the same combinational-
   loop pattern emitted to the gate log. The latter validates this
   note's premise.
2. **Dump the post-clean_multidriver RTLIL**: add a hexa-native pass
   that walks `Module.cells` after `clean_multidriver` and prints
   `(cell_type, port_A, port_B, port_Y)` triples — grep for any
   path `rr_ptr → ... → rr_ptr__d` that's not gated by a `$dff`.
3. **If hypothesis 1**: factor the feedback-default emit at L2859
   to use a *fresh* wire name (`rr_ptr__d_default` or
   `rr_ptr__hold`) and add an explicit `$mux` cell instead of
   relying on `pass_proc_mux` to fold a non-orthogonal default.
4. **If hypothesis 2**: extend `_rv_signal_is_read_in_body`'s SSA
   target filter to include LHS that are read *outside* the body
   (sequential block, function args, downstream comb). The current
   filter is too narrow — it misses `grant_in` because the read
   site is `rr_ptr <= (grant_in + 1) % P` (in a different `always`
   block). Selftest scope: T75 with `always @* begin … grant_in =
   ..._cond_on_lhs ; end ; always @(posedge clk) rr_ptr <= grant_in
   + 1;` — minimum-shape cross-block falsifier.
5. **If hypothesis 3**: emit `assign`-driven wires from `generate`
   blocks should be split per-iteration as well; trace the
   `fifo_empty[idx_ssaN]` lowering and check if there's a
   transitive `rr_ptr` read.

## Tier-1 dependency context

This note's work is gated by:
- (0) ✓ exec runtime restore (cycle 66 / PR #251 MERGED)
- (a) ✓ PR #247 SSA fix
- (b) ☐ PR #255 abc_map honesty merge — gives us fail-loud signal
  during investigation
- mac hexa.real binary rebuild — needed before any iteration

This note's work blocks:
- (e) `fifo_mem[*]` RTLIL Memory cells — independent in scope but
  (d) + (e) are both prerequisite for area > 0
- (f) re-measure + ±5% gate flip — depends on (d) AND (e)

## Cross-link

- `~/core/demiurge/YOSYS.md` Tier-1 closure path (d)
- `inbox/patches/yosys-exec-runtime-regression-cycles-61-64.md`
  (related — same audit cycle)
- PR #247 (`cdfa8d46`) — the SSA fix this builds on
- PR #245 (`66a39a31`, RFC 073 Phase 3e) — `_rv_emit_body_v2`
  per-LHS D-wire pattern this builds on

## Honest C3 / scope

1. Without a working mac hexa.real (cycle 66 binary release), this
   note is documentation-only. Once the binary is available, step 1
   of "Suggested investigation" should be the first verification.
2. The three hypotheses are not mutually exclusive — the loop ABC
   reports may have multiple root causes that all need fixing.
3. T75 (or wherever the next selftest slot is) needs a minimum-shape
   falsifier ABC can reject on stub-PDK fixtures, not just the full
   router. RFC 073 Phase 3f's T74 (in PR #250) may be a starting
   point — borrow its falsifier shape.
