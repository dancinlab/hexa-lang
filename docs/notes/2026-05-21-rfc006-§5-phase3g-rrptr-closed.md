# RFC 073 Phase 3g — `rr_ptr__d` cross-iteration comb-loop CLOSED (rfc_006 §5 Tier-1 (d))

**Status**: resolved-ssot (2026-05-21)
**Layer**: hexa-native `stdlib/kernels/logic_synth/read_verilog.hexa` SSA pre-loop redirect
**Predecessor**: PR #247 (Phase 3f intra-iter SSA), PR #250 (T74 minimum-shape falsifier),
  archive/patches/yosys-rr-ptr-cross-iteration-comb-loop.md (commit `f4283ac2`)

## Outcome

ABC `NetworkCheck` no longer rejects router_d4 / router_d6 with
the `rr_ptr__d` combinational-loop error. Both `abc_map` stages
report `ok=0 → ok` (exit code 0). The pipeline now reaches the
area-oracle stage for BOTH designs.

```
[gate] router_d4 — abc_map: ok        (was: ABC NetworkCheck FAIL)
[gate] router_d6 — abc_map: ok        (was: ABC NetworkCheck FAIL)

post-fix area measurement (probe via probe-script, sec5_probe.hexa):
  d4: cells=63,  area=559.286   µm²,  oracle=61762.99  µm²,  Δ ≈ 99.1 %
  d6: cells=87,  area=771.99    µm²,  oracle=93608.53  µm²,  Δ ≈ 99.2 %
  ratio=1.380×  vs  oracle ratio=1.5156×
```

§5 ABSORPTION GATE remains OPEN — areas are 99 % UNDER oracle.
The new blocker layer is Tier-1 (e) `fifo_mem` 2-D packed-array
memwr emit (see `docs/notes/2026-05-20-rfc006-§5-tier1-e-fifo-mem-2d-memwr.md`)
plus the crossbar-output array writes. Comb-loop class is closed;
memory-cell emission is the next blocker.

## RCA — why Phase 3f missed `rr_ptr`

`rr_ptr` was never in Phase 3f's tracked set: it is a clocked
register (`always @(posedge clk) rr_ptr <= ...;` in router_d4.v
L98-123), not a blocking-LHS inside the combinational arbiter
block (L80-94). Phase 3f's filter (`_rv_collect_blocking_lhs` +
`_rv_signal_is_read_in_body`) correctly excluded it.

The cycle ABC flagged terminated at `rr_ptr__d` (the D-input of
the `$dff` for `rr_ptr`) because that's the chain's downstream
CO. The actual loop body lived inside the COMB always-block on
`any_grant`, `grant_in`, `grant_out`, `idx` — Phase 3f's tracked
set. Phase 3f emitted:

  - per-iter SSA wires `{any_grant,grant_in,grant_out,idx}__ssa<k>`
  - pre-loop alias  `connect(s__ssa0, s)`
  - post-loop publish `connect(s, s__ssa<P>)`

The HONEST GAP that survived: the pre-loop direct writes
(`any_grant = 1'b0 ;`, `grant_in = 3'd0 ;`, `grant_out = 3'd0 ;`)
remained as `connect(s, $const_0)`. Combined with the post-loop
`connect(s, s__ssa<P>)` this multi-drove `s` →
`pass_clean_multidriver` collapsed to `s__ssa<P>` (last-wins) →
`connect(s__ssa0, s)` alias chained
`s__ssa0 ← s ← s__ssa<P>` → ABC saw a self-loop via the
SSA chain, terminating at the downstream CO `rr_ptr__d`.

## Fix (surgical to read_verilog.hexa)

1. Added `_rv_ssa_rewrite_preloop_for(m, s, snapshot) -> RvSsaRewrite1`
   helper (L2429+ in read_verilog.hexa). Walks `m.connect_lhs[0:
   snapshot]` and rewrites each unconditional `connect(s, X)` to
   `connect(s__ssa0, X)`. Returns the rewritten Module + a count.

2. At the SSA fire site (L4255+, `_rv_parse_always` for-handler),
   snapshot `len(m.connect_lhs)` BEFORE the pre-loop alias loop.
   For each tracked `s`, call `_rv_ssa_rewrite_preloop_for`. If
   ≥1 row was rewritten, SUPPRESS the alias emit (`connect(s__ssa0,
   s)`) — the rewritten init now drives `s__ssa0` directly. If 0
   rows rewritten, keep the alias (signals with no pre-loop direct
   write retain the legacy semantics).

3. Updated T74 (Phase 3f selftest) — the old assertion T74c
   (`connect(v__ssa0, v)` alias present) is now T74c (entry
   driver present on `v__ssa0`) + T74d (legacy alias absent).

4. Added T75 (Phase 3g falsifier) — minimum-shape
   `rr = rr_q ; for ... rr = rr + 1'b1` pattern asserting:
   - T75a: 4 SSA versions wires exist (rr__ssa0..3)
   - T75b: legacy alias `connect(rr__ssa0, rr)` ABSENT
   - T75c: redirected init `connect(rr__ssa0, rr_q)` present
   - T75d: post-publish `connect(rr, rr__ssa3)` present
   - T75e: exactly 1 unconditional driver of `rr` (single-driven)

@cite IEEE 1364-2005 §9.1.1.2 (blocking assignment ordering),
§10.4.2 (procedural assign final value), Yosys
passes/proc/proc_mux.cc (last-wins multi-driver collapse
reference). Surgical to `read_verilog.hexa` only — `passes.hexa`,
`abc_map.hexa`, `gate_record.hexa` untouched.

## Measurements

```
read_verilog selftest: 78/78 PASS   (was 77/77; +T75)
passes        selftest: 35/35 PASS  (no regression)
abc_map       selftest:  7/7  PASS  (no regression)
rtlil         selftest: 11/11 PASS  (no regression)
liberty       selftest:  8/8  PASS  (no regression)

§5 oracle pipeline (gate_record.hexa --lib sky130_fd_sc_hd):
  d4 abc_map: ok  (was: ABC NetworkCheck FAIL — comb loop on n272 → CO rr_ptr__d)
  d6 abc_map: ok  (was: ABC NetworkCheck FAIL — comb loop on n372 → CO rr_ptr__d)
  d4 area = 559.286 µm²   (oracle 61762.99 µm² — Δ ≈ 99.1 % UNDER)
  d6 area = 771.99  µm²   (oracle 93608.53 µm² — Δ ≈ 99.2 % UNDER)
```

## §5 absorption-gate verdict (g3 honest)

**OPEN** — comb-loop class closed (Phase 3g), area-oracle gate
remains OPEN. The new blocker is Tier-1 (e) `fifo_mem` 2-D
packed-array memwr emit (40 non-driven nets in router_d4 per
ABC's `Constant-0 drivers added` warning, ~80 in router_d6).
Without `$memwr` cells the FIFO / crossbar storage stays empty
→ ~99 % area UNDER. NO `Yosys absorbed=true` claim.

## Cross-link

- archive/patches/yosys-rr-ptr-cross-iteration-comb-loop.md (commit `f4283ac2`) —
  the investigation note that named this blocker; this PR resolves it.
- docs/notes/2026-05-20-rfc006-§5-tier1-e-fifo-mem-2d-memwr.md — the new
  blocker layer for area-oracle closure.
- PR #247 (`cdfa8d46`) — Phase 3f intra-iter SSA fix this builds on.
- PR #250 (`d698e61a`) — Phase 3f T74 minimum-shape falsifier (now T74c/d
  asserts the Phase 3g redirect).
- ~/core/demiurge/YOSYS.md Tier-1 closure path (d).

## g3 honest scope

This PR closes the Tier-1 (d) `rr_ptr__d` cross-iteration comb-loop
class. It does NOT close §5 (areas ~99 % UNDER oracle). It does
NOT touch memory-cell emission, multi-dimensional packed-array
indexing, or the crossbar output path (Tier-1 (e), (f) territory).
No `Yosys absorbed` claim is made.
