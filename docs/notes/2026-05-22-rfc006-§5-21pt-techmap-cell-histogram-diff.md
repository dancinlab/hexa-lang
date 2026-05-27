# rfc_006 §5 d4 21pt gap — substrate cell-histogram differential (bg agent ac02f325, 2026-05-22)

**Status**: diagnostic-only · no-commit per g3-honest stop · directs next-cycle scope to `pass_techmap_sky130` cell-coverage expansion

**Predecessor**:
- `057bc8e7` + `2bb05f0c` (agent a45160fd, 2026-05-21): d4 32829→45492 µm² (+38.6%) breakthrough via per-bit connect buffer
- `a9ebfda6` (agent ad30c33d, 2026-05-22): 4 IR refactor iters NULL movement, residual not in IR
- `ac02f325` (this report): falsifies `pass_clean_multidriver` as the 21pt locus; identifies real cell-histogram gap

## TL;DR

d4 §5 area frozen at 45492 µm² (Δ 26.34 % under yosys 0.33 oracle 61763). The 21pt gap is **cell-coverage missing** in `pass_techmap_sky130` + the Liberty subset ABC sees, NOT IR-level bit-blast/SSA.

## Histogram differential (substrate yosys 0.65 vs hexa-native, d4)

| Cell | Substrate count | Hexa count | Δ | Note |
|------|----------------:|-----------:|---|------|
| **edfxtp_1** (DFF+enable) | **1615** | **0** | MISSING | dominant — FIFO storage clocked with `if (enable)` |
| dfxtp_1 | 23 | 0 | MISSING | rr_ptr-style clocked reg |
| mux4_2 | 318 | 0 | MISSING | cross-bar 4-way mux |
| mux2i_1 | 19 | 0 | MISSING | inverted mux |
| a22oi_1 | 126 | 0 | MISSING | AOI22 (priority arbiter inner) |
| nand4_1 | 67 | 0 | MISSING | 4-input nand |
| nand2_1 | 270 | 5 | under-emit | |
| a31oi_1 | 15-24 | 0 | MISSING | AOI31 |
| o22ai_1 | 15-24 | 0 | MISSING | OAI22 |
| xnor2_1 | 15-24 | 0 | MISSING | (uses for compare?) |
| lpflow_isobufsrc_1 | 62 | 0 | MISSING | iso-buffer (likely retention-related) |
| a21oi_1 | 23 | **1280** | over-emit | AOI21 — used as fallback for everything |
| clkinv_1 | 17 | **1299** | over-emit | clock inverter — used as fallback |
| buf_1 | n/a | 320 | over-emit | |

Hexa-native over-emits low-strength inverters/AOIs because ABC has only the bare-minimum library it was told about; substrate ABC sees the full `sky130_fd_sc_hd__tt_025C_1v80.lib` cell set.

## Root cause

`pass_clean_multidriver` is correct — the 5 collapses are 2-driver UNCONDITIONAL collisions (`idx__ssa1..5` SSA pre-loop default-hold clobbered by for-body unguarded write at `comb/rtl/router_d4.v:85`), correctly lowered as Verilog §10.4.2 last-write-wins. Cond-tagged groups never reach `pass_clean_multidriver` — `pass_proc_mux` consumes them all (52 groups visible in d4 trace).

The real layer is **`pass_techmap_sky130` cell-coverage**:

1. **DFF-with-enable inference missing**: substrate yosys infers `$_DFFE_PP_` from the `if (!fifo_full[pp]) ...` enable predicate in router_d4.v L100-115 (FIFO write block). We lower as plain `$dff` + feedback mux. ABC then re-maps via inverter/AOI21 cascade → over-emit of a21oi_1/clkinv_1.

2. **Complex cells missing**: `a22oi_1`, `o22ai_1`, `mux4_2`, `nand4_1` are substrate-canonical for arbiter / cross-bar / priority logic. Our techmap doesn't emit them, so ABC has no way to choose them as mapping targets.

3. **Library subset wrong**: `abc_map.hexa` may be passing only a subset of `sky130_fd_sc_hd` to ABC's `read_lib` call. Verify the `-liberty` argument shape.

## Next-cycle actionable (scope estimates)

1. **`$dffe` inference + techmap → edfxtp_1** (~50-100 LOC)
   - Detect `if (enable_expr) reg <= rhs;` pattern in `_rv_parse_always` (or `_rv_emit_body_v2`)
   - Emit RTLIL `$dffe` cell instead of `$dff` + feedback mux
   - Add `$dffe` lowering in `pass_dfflibmap_sky130` (currently only does plain `$dff` → `dfxtp_1`)
   - Result: ~1615 edfxtp_1 cells emit instead of cascade → est ~16000 µm² area movement on d4

2. **Complex cell techmap** (~150-200 LOC)
   - Add `a22oi_1` / `o22ai_1` / `mux4_2` / `nand4_1` / `a31oi_1` lowering cases in `pass_techmap_sky130`
   - Detect upstream RTLIL patterns: nested $and/$or → AOI/OAI, 4-way $mux → mux4_2

3. **ABC Liberty subset verification** (~10 LOC)
   - Audit `abc_map.hexa` `read_lib` arg to ABC; ensure full sky130_fd_sc_hd cell set is loaded

Sum: 1+2+3 should close the 21pt gap on d4 (probably overshoot toward oracle).

## Cross-link

- `project_rfc006_s5_breakthrough_d4_movement.md` — prior breakthrough
- `project_rfc006_s5_21pt_gap_not_in_iir.md` — IR refactor null movement diagnosis
- `project_rfc006_oracle_substrate_yosys_033.md` — substrate yosys 0.33 oracle = 61847 µm² (yosys 0.65: 79673, +28% drift from edfxtp_1 30 µm² vs dfxtp_1 20 µm²)
