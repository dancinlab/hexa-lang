# rfc_006 §5 — multi-bit width truncation in BLIF emit (post-Option-A residual)

**Status**: filed 2026-05-21 (post Option A landing, commit `c4b35b13`)
**Layer**: `stdlib/kernels/logic_synth/abc_map.hexa::abc_emit_blif` (`.latch` emit) + `stdlib/kernels/logic_synth/read_verilog.hexa` width-aware combinational emit
**Predecessor**: `inbox/patches/yosys-fifo-mem-2d-array-memwr-emit.md` (Option A landed)

## TL;DR

Option A (commit `c4b35b13`) closes the 2-D LHS honest-skip and produces `area > 0` measurable output:
- d4: 1207.41 µm² (was 559.286, **+2.16×**) — oracle 61762.99 µm² (~98 % under)
- d6: 1677.86 µm² (was 771.99, **+2.17×**) — oracle 93608.53 µm² (~98 % under)

ABC accepts both designs (`abc_map: ok`, no `Constant-0 drivers added` warnings). The residual ~98 % area gap has been bisected to **two distinct width-truncation sources** in the read_verilog → RTLIL → BLIF pipeline.

## Bisection (cheap-first oracle)

Post-Option-A BLIF inspection (`/tmp/_hexa_yosys_gate_d4_in.blif`):

```
$ grep -cE "^\.latch" /tmp/_hexa_yosys_gate_d4_in.blif
41
```

But router_d4.v's parameter expansion expects (bit-level):

| reg             | shape         | total bits |
|-----------------|---------------|-----------:|
| `fifo_mem`      | W=64, P=5×D=4 |       1280 |
| `out_data`      | W=64, P=5     |        320 |
| `fifo_head/tail`| 3 bits, P=5   |         30 |
| `out_valid`     | 1 bit, P=5    |          5 |
| `rr_ptr`        | 3 bits        |          3 |
| `grant_in/out`  | 3 bits        |          6 |
| `any_grant`     | 1 bit         |          1 |
| **TOTAL**       |               | **1645**   |

Expected latches at 20.02 µm²/latch (sky130_fd_sc_hd__dfxtp_1): ~32 925 µm² just for storage. Plus combinational ~5 000 µm² = ~38 000 µm². Even bit-expansion only closes to ~60 % of the 61 763 µm² oracle.

## Root causes (two distinct)

### Source 1 — BLIF `.latch` emit collapses to 1 per RTLIL `$dff`

`abc_map.hexa::abc_emit_blif` L290-307:
```hexa
while ci < len(m.cells) {
    let c = m.cells[ci]
    if c.cell_type == "sky130_fd_sc_hd__dfxtp_1" {
        let mut d_net = "" ; let mut q_net = "" ; let mut clk_net = ""
        … // collect D/Q/CLK pin nets
        buf = buf + ".latch " + d_net + " " + q_net + " re " + clk_net + " 2\n"
        …
    }
}
```

One `.latch` line per RTLIL `$dff` cell, regardless of the connected wire's width. The BLIF format itself supports only 1-bit `.latch`. So a 64-bit `$dff` cell with `D=fifo_mem[0][0]` (width=64) emits a single `.latch fifo_mem[0][0] … re clk 2` — collapsing 64 bits to 1.

### Source 2 — `_rv_parse_port_decl` creates a single wire per slot, hiding bit-level identity

`read_verilog.hexa::_rv_parse_port_decl` L688-720 (and the 2-D extension landed in `c4b35b13`):
```hexa
m = rtlil_module_add_wire(m, rtlil_wire(wn, width, dir_kind, pid))
```

Stores width as a wire attribute, but downstream the 2-D LHS emit (`_rv_emit_body_v2` L2920+ and `_rv_parse_always` bare-path L5060+) creates exactly ONE `$dff`/`$mux` per slot, never expanding per-bit. Combinational `$xor` / `$and` / `$mux` cells emitted by `_rv_elab_expr` similarly assume 1-bit operands (per the L739 comment "Wire widths are recorded as 1 here — a follow-up pass elaborates real widths; the generic cells are width-tolerant").

So the bit-expansion has never landed for the seq-storage path either.

## Three scope options (ranked surgical → ambitious)

### Option I: BLIF emitter expands per-bit at the very end

In `abc_emit_blif`, before emitting `.latch`, look up the D-wire's width and emit N parallel `.latch` lines. Mirror in the `read_blif` parser (read_mapped_blif at L411-423): coalesce N consecutive latches that share a CLK + sequential pin-name pattern back into one width-N `$dff`.

- ~80-120 lines of new logic
- Doesn't change RTLIL semantics (good — minimal regression risk)
- Adds approximately P×D×(W-1) extra latches per 2-D array
- **Bit-expansion alone gets to ~60 % of oracle**: still leaves the combinational gap (Source 2 layer)
- DOES NOT change cell-level synthesis quality (still naive flat $dff)

### Option II: read_verilog emits per-bit cells from the start

Refactor `_rv_parse_port_decl` to emit P × D × W 1-bit wires named like `base[i][j][k]`, and rewrite the LHS emit + RHS elab path to operate per-bit. This is a substantial overhaul of read_verilog's wire model.

- ~300-500 lines of overhauled emit
- Lower BLIF emit becomes trivial (1 wire = 1 latch)
- Closes Source 1 AND Source 2 together
- Likely matches Option B's substrate match cost; probably worse engineering ROI than Option B

### Option III: Option B (substrate-canonical `$mem` cells)

Per the original patch body: emit RTLIL `$memrd` / `$memwr` cells + a single `$mem` cell per 2-D array. Then a downstream `synth_memory_dff` pass consolidates to substrate cell shape.

- ~400-700 lines
- ±5 % gate achievable per the patch body's claim
- Matches Yosys substrate (single-source compatibility win)
- Deepest engineering investment

## Recommendation

For incremental progress on §5: **Option I** (BLIF emit per-bit expansion) gives a measurable bump cheaply, but cannot close ±5 % alone. For closure: **Option III** is the right architectural match.

## Cross-link

- `inbox/patches/yosys-fifo-mem-2d-array-memwr-emit.md` (Option A landed `c4b35b13`)
- `~/core/demiurge/YOSYS.md` Tier-1 closure path
- BLIF spec §3.4 (latch primitive — `.latch <in> <out> <type> [<clk>] [<init>]`, only 1-bit signals)

## g3 honest scope

No `Yosys absorbed=true` claim. The two width-truncation sources are HONEST bisection findings — they explain why Option A's `area > 0` measurement is real but ~98 % under the substrate oracle. Either source alone is multi-cycle work; Option III closes both architecturally.
