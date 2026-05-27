# rfc_006 §5 — pass_cut_and_remap O(n³) perf bug + d6 substrate reference (bg agent a60b3d77, 2026-05-22)

**Status**: diagnostic-only · no source edit · two next-cycle dispatch targets identified

## 1. Substrate yosys 0.33 d6 reference (ubu-2, reproducible)

Recipe `read_verilog -sv → hierarchy → proc → memory → flatten → opt → techmap → dfflibmap → abc → stat` on `comb/rtl/flat_v2k/router_d6.v` (sv2v-flattened packed RTL), W=64, sky130_fd_sc_hd OpenROAD lib:

| design | cells | chip area µm² | reproducible |
|--------|------:|--------------:|:------------:|
| router_d6 | 10677 | **98247.98** | yes (2× identical) |
| router_d4 | 6695  | 64295.41 | yes |

d6/d4 ratio = **1.528** (cited oracle ratio 1.5156, +0.8%). Absolute differs from prior cited (d6 93608/95897) due to RTL-packing + abc-script recipe variance; the d4+d6 SAME-recipe pair gives the trustworthy *relative* measure. NOTE: original `router_d6.v` (unpacked-array ports `in_data [0:6]`) does NOT parse in yosys 0.33 — must use `comb/rtl/flat_v2k/` sv2v-flattened version.

## 2. mini d6 hang — root cause = pass_cut_and_remap O(n³)

NOT `_passes_fuse_complex_cells` (doesn't exist in current code). The culprit:

`stdlib/kernels/logic_synth/passes.hexa::pass_cut_and_remap` (L3709, wired at `gate_record.hexa:117`):
- Outer `while k < n` over ALL cells; for every `mux2_1` / `inv_1` root → `_passes_enumerate_cuts(cells, k, 6)`
- `_passes_enumerate_cuts` BFS frontier loop calls:
  - `_passes_find_producer` (L2060) — **O(n) scan** per call
  - `_passes_net_fanout` (L2039) — **O(n×conns) scan** per call
- Net: **O(n³)** with string compares + hexa `array.push()` realloc (each push copies the growing `new_cells`/`in_cut`/`frontier`)
- d6 post-techmap n ≈ 1.5× d4 → ~3.5× the cube term → past mini's ~19 GB / time wall

**Next-cycle fix (high leverage)**: precompute a net→producer hashmap + net→fanout-count map ONCE per module (O(n)) instead of re-scanning all cells per cut. Plus an iteration/size guard: skip cut_and_remap when `n > threshold` so large-P designs degrade gracefully to the un-fused netlist.

## 3. d6 datapath-collapse (separate bug)

mini-generated `d6_in.blif` (pre-ABC) shows only **132 mux2 / 189 and2** vs d4's **1369 mux2 / 255 and2** — d6 is the LARGER design yet has FEWER combinational gates. An upstream pass (likely `pass_proc_mux` / `pass_clean_multidriver` at P=7) is dropping the crossbar datapath. The mini d6/d4 `_out.blif` are degenerate (exclude flops; d4_out shows 1536 buf / 6738 µm² ≠ the validated d4 Δ 10.07% / 55545.8 µm² number from agent ab24b934's fresh measurement).

The 03:17 mini BLIF artifacts B1 pulled PREDATE the ab44097d fixes — they are NOT the current pipeline state. The d4 Δ 10.07% measurement (commit ab44097d) stands; B1's "degenerate" observation is on stale artifacts.

## 4. Recommendation for reliable d6 §5 measurement

1. **Measure on ubu-2, not mini** (30 GB, x86, no jetsam). Substrate baseline already reliable there.
2. **Fix pass_cut_and_remap O(n³)** → net→producer/fanout hashmap (separate dispatch).
3. **Add size guard** for large-P graceful degradation.
4. **Investigate P=7 datapath-collapse** (pass_proc_mux/clean_multidriver crossbar drop) — separate dispatch.

## Cross-link

- `project_rfc006_oracle_substrate_yosys_033.md` — original substrate measurement (d4 61847, d6 95897 via hand-packed RTL)
- `project_rfc006_s5_d4_final_route_xy_blocker.md` — d4 Δ 10.07% final state + route_xy blocker
- `pass_cut_and_remap` landed in commit `5c48be32` (Agent C, Piece 3)
