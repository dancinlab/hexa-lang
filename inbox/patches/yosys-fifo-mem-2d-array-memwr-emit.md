# `stdlib/kernels/logic_synth/read_verilog.hexa` — 2-D packed-array LHS writes silently dropped (`fifo_mem[*]` undriven)

**Severity**: high (blocks rfc_006 §5 area-oracle parity for
  router_d4/d6 — half of the "no `Yosys absorbed=true` claim valid"
  story, the other half being the cross-iter comb-loop in
  `yosys-rr-ptr-cross-iteration-comb-loop.md`)

**Layer**: hexa-native read_verilog frontend / 2-D unpacked-array
  LHS emit path

**Reporter**: rfc_006 §5 measurement audit 2026-05-21 KST
  (`~/core/demiurge/YOSYS.md` Tier-1 item (e), reframed from Tier-2).
  Discovered while manually invoking substrate `abc -c` after the
  PR #247 SSA fix + abc_map script reorder landed.

**Status**: investigated, implementation deferred (2026-05-21) —
  surface analysis confirms the patch's diagnosis: `read_verilog.hexa`
  L2828 `if has_idx2 == 1 { continue }` is the single skip point.
  Adjacent emit infrastructure (`_rv_emit_body_v2` at L2502, the v2
  super-set helper, plus the existing dyn-idx emit path at L3310+
  that captures `idx2_toks`) gives concrete entry hooks. Option A
  (per-element flat $dff) is the recommended first cut per the patch
  body. Real implementation is multi-cycle (T76 falsifier + Wxslot
  $dff emit + per-slot $eq decode + per-slot $and guard + per-slot
  $mux write-mux + downstream multi-driver reconciliation through
  the existing connect_cond/__d/$dff pipeline at L2199-2211); not
  attempted in this cycle. Mac arm64 build blocker now resolved
  (see `runtime-duplicate-symbols-stdlib-port-collision.md`
  resolved-ssot via tool/build_hexa_cli.sh step 4b), so measurement
  infrastructure is unblocked when this work lands.

## Symptom

```
$ abc -c "read_lib <SKY130.lib> ; read_blif /tmp/_hexa_yosys_gate_d4_in.blif"
Warning: Constant-0 drivers added to 40 non-driven nets in network "router_d4":
fifo_mem[0], fifo_mem[1], fifo_mem[2], fifo_mem[3], …
```

40 undriven nets for d4 (P=5 × DEPTH=4 × W=2 = 40 — packed-array
storage cells), 52 for d6 (P=7 × DEPTH×W). All `fifo_mem[*]`
positions are auto-tied to const-0 because no `.gate` line ever
drives them.

## Source pattern that triggers it

`comb/rtl/router_d4.v` L41 + L98-113:

```verilog
reg [W-1:0] fifo_mem [0:P-1][0:DEPTH-1];   // 2-D unpacked array

always @(posedge clk) begin
    if (rst) begin … end
    else begin
        for (pp = 0; pp < P; pp = pp + 1) begin
            if (in_valid[pp] && !fifo_full[pp]) begin
                fifo_mem[pp][fifo_tail[pp][FIFO_LD-1:0]] <= in_data[pp];
                fifo_tail[pp] <= fifo_tail[pp] + 1;
            end
        end
    end
end
```

The LHS is **`fifo_mem[pp][fifo_tail[pp][FIFO_LD-1:0]]`** — a 2-D
index, with the OUTER index `pp` const-foldable (per-iteration in
the unroll) and the INNER index `fifo_tail[pp][...]` dynamic.

## Root cause (in source)

`stdlib/kernels/logic_synth/read_verilog.hexa` L2756:

```hexa
if has_idx2 == 1 { continue }              // 2-D — honest skip
```

The 2-D LHS path is an explicit `continue` (honest skip — no emit).
The comment at L2196 frames this as "(NOT on §5 area critical
path)" — a scope deferral from earlier work. The 2026-05-21 audit
flipped this from Tier-2 to Tier-1 because area > 0 on
router_d{4,6} cannot land without this work.

## Scope options (ranked, surgical → ambitious)

### Option A: per-element flat unpacked-array $dff flops

Lower `fifo_mem[pp][addr]` to P×DEPTH separate $dff cells (one per
slot), keyed by `fifo_mem__p<pp>__a<addr>`. The dynamic inner index
becomes a P-way demux on the write side (one $mux per slot
choosing between "old value" and "new value depending on `addr ==
this_slot`"). Inner-index dynamic mux is already supported per PR
#220 (`#4h-b multi-LHS body dyn-idx LHS`).

- **emit cell count**: P × DEPTH × W = (for d4) 5 × 4 × 64 = 1,280
  $dff cells + 5 × 4 = 20 address-decode $eq cells + 5 × 4 = 20
  guard-AND cells + 5 × 4 = 20 write-mux cells = ~1,340 cells per
  router. Way above oracle's `synth_memory_dff`-consolidated count
  (~50-100 mem cells), but **finite + correct + measurable**.
- **measurement implication**: §5 ±5% gate cannot pass with this
  approach — area will be 10x+ above oracle. But this unblocks the
  GATE PROBE (area > 0), and clarifies whether `rr_ptr__d` comb-
  loop (Tier-1 (d)) is independent of memory-cell presence.
- **selftest**: T76 — 2-D `reg [W-1:0] m [0:N-1][0:M-1] ; always
  @(posedge clk) m[i][j] <= d ;` round-trip emits N×M×W flops +
  N×M decode cells.
- **scope**: ~150-250 lines of new logic_synth code in
  `_rv_emit_for_if_stmts` + `_rv_emit_body_v2`'s 2-D branch.

### Option B: RTLIL `$memrd` / `$memwr` + module-level `$mem` cell

Match what substrate Yosys does. One `$mem` cell per RTLIL Module
with parameters `WIDTH=W`, `SIZE=P*DEPTH`. Per-write: emit a
`$memwr` cell with `DATA`, `ADDR`, `CLK_EN`. Per-read: emit a
`$memrd` cell (or `$memrd_v2` for clocked reads). Substrate
`memory_dff` pass consolidates these into flop arrays for
synthesis or keeps them as bRAM hints.

- **emit cell count**: 1 `$mem` + 4-5 `$memwr`/`$memrd` per router
  → tens of cells. **Plausibly within ±5% of oracle.**
- **complexity**: needs RTLIL `Memory` struct (separate from
  `Module.cells`), parameter handling, port-list emit (`READ_PORTS`/
  `WRITE_PORTS` count, INIT bit-blob, etc.) — significantly bigger
  than Option A.
- **write_verilog**: needs $memrd/$memwr → behavioural `always`-
  block synth on the back end. Not trivial — depends on whether
  the round-trip target (substrate `read_verilog`) can re-consume
  $memrd/$memwr or if we have to emit Verilog `array_reg` form
  directly.
- **selftest**: T76a (memwr cell emit) + T76b ($mem cell + port
  count) + T76c (round-trip to substrate `synth` macro produces
  memory_dff cells).
- **scope**: ~400-700 lines + a new rtlil_memory.hexa file or
  rtlil.hexa extension. 3-5 sessions.

### Option C: substrate-as-tail-pass (defer 2-D unrolling)

Hexa-native frontend keeps the 2-D LHS as a single `connect` row
with a special `$mem_lhs` marker; the gate_record chain hands the
RTLIL off to substrate `yosys -p "synth"` for the final pass and
ABC mapping. This bridges share/freduce parity AND fifo_mem auto,
but defeats the purpose of hexa-native absorption (would mark
rfc_006 §4 as "absorbed via tail-substrate", not "absorbed via
hexa-native synth").

- **measurement implication**: oracle would match exactly (since
  it IS the oracle pipeline)
- **absorption claim**: rfc_006 §5 closure would need a different
  framing — "front-end absorbed, back-end remains substrate".
  Likely a g3 honesty issue per `~/.wilson/identity.tape`
  principle 2 (hexa-first).

## Recommended path

**Option A** for §5 closure (area > 0 + measurable), then
**Option B** when the team has bandwidth for proper RTLIL Memory.

Option C is rejected on g3-honesty grounds — accepting it would
mean the §178 ABSORPTION.md row should read "absorbed-via-tail-
substrate" not "absorbed".

## Tier-1 dependency context

This note's work is gated by:
- (0) ✓ exec runtime restore (cycle 66 / PR #251 MERGED)
- mac hexa.real binary rebuild — needed before any iteration

This note's work blocks:
- (f) re-measure + ±5% gate flip

It is INDEPENDENT of (d) (`rr_ptr__d` cross-iter comb-loop) in
implementation, but BOTH must land for area > 0 on router_d{4,6}.

## Suggested next concrete step (when binary lands)

1. Re-measure with abc_map honesty PR #255 + cleared `_out.blif`.
   Confirm `combinational loop` + `Constant-0 drivers added to N
   non-driven nets: fifo_mem[*]` BOTH present in gate log → both
   blockers are real.
2. Extend `read_verilog.hexa` L2776+ to handle `has_idx1 == 1 &&
   has_idx2 == 1` per Option A (per-element flat $dff array).
   Adapt PR #220 `#4h-b dyn-idx LHS` pattern to the inner index.
3. Add T76 selftest with minimum-shape 2-D LHS falsifier
   (`reg [3:0] m [0:1][0:1] ; always @(posedge clk) m[i][j] <= d ;`
   → 4 $dff + 4 $eq + 4 $mux cells).
4. Re-run gate_record — if Constant-0 fifo_mem warning vanishes
   AND (d) is fixed, area > 0 on both d4 and d6.

## Cross-link

- `~/core/demiurge/YOSYS.md` Tier-1 closure path (e)
- `inbox/patches/yosys-rr-ptr-cross-iteration-comb-loop.md` —
  sibling Tier-1 blocker; both prerequisites for area > 0
- PR #220 (`#4h-b dyn-idx LHS`) — pattern to reuse for inner index
- PR #245 RFC 073 Phase 3e — per-LHS D-wire model this builds on

## Honest C3 / scope

1. Mac hexa.real binary release is the prerequisite — without a
   working `hexa run`, none of this is testable.
2. Option A is "naive but correct" and will fail ±5% gate. That's
   honest — area > 0 is the immediate unblock; ±5% match needs
   Option B (proper $mem) OR a future hexa-native memory_dff-like
   consolidation pass. The §5 measurement record stays honest
   throughout: "area > 0 measured, ±5% gate FAIL — needs share/
   freduce + memory consolidation passes."
3. The Verilog round-trip for $memrd/$memwr cells (write_verilog
   side) is its own multi-session work — Option B isn't a single
   PR.
