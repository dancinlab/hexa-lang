# comb/rtl synthesis comparison — measured cell-count ratio

> 2026-05-18 · yosys 0.65 generic synthesis (no PDK mapping yet).
> Source RTL: `router_d4.v` (126 lines) + `router_d6.v` (137 lines).
> Translation: sv2v 0.0.13 (SystemVerilog array ports → flat Verilog 2005).
> Raw stat: `router_d4.synth.out`, `router_d6.synth.out`.

## Measured ratios (post-synthesis, generic tech)

| metric        | router_d4 | router_d6 | ratio (d6/d4) |
|---------------|----------:|----------:|--------------:|
| total cells   |    12,105 |    21,790 |  **1.80×**    |
| `$_DFFE_PP_`  |     1,624 |     2,264 |     1.39×     |
| `$_MUX_`      |     7,379 |    12,181 |     1.65×     |
| `$_AND_`      |     1,530 |     3,482 |     2.28×     |
| `$_OR_`       |     1,129 |     2,458 |     2.18×     |
| `$_NOT_`      |       222 |       569 |     2.56×     |
| `$_XOR_`      |       198 |       805 |     4.07×     |
| port bits     |       670 |       938 |     1.40×     |
| wires         |     2,259 |     4,772 |     2.11×     |
| wire bits     |    37,541 |    53,482 |     1.42×     |

### Honest reading

- **Cells +80%, ports +40%**. Both larger than the simple "port count
  scales d-linearly (1.5×)" assumption used in `f1_parametric.hexa`.
- Driver: hex needs 7-input arbiter + 3-axis route compare vs mesh's
  5-input arbiter + 2-axis compare. More combinational logic → bigger
  cell count beyond just port-count scaling.
- Flop count grows ~1.4× (linear with port count) — FIFO storage scales
  cleanly. The combinational explosion drives the 1.8× total.

## Back-substitute into F1 (workload_f1 cost model)

Re-run with measured `t_router_d6 = 180` (1.8× cycles, assuming cycle ∝
gate-depth ∝ cells^x for some x ≤ 1) and `e_router_d6 = 180` (energy ∝
cells × activity):

```
N=1024, uniform/broadcast/hotspot: avg_hops_hex_x3 = 34, mesh_x3 = 64
  lat_hex  = 34 × (180 + 100) =  9520    lat_mesh  = 64 × 200 = 12800
  e_hex    = 34 × ((180+100+180+130)/2) = 34 × 295 = 10030
  e_mesh   = 64 × (100 + 100) = 12800

ratios:  lat_hex/lat_mesh = 9520/12800 = 0.744  (hex 25% faster)
         e_hex/e_mesh     = 10030/12800 = 0.784 (hex 22% lower)
```

**F1 verdict survives measured synthesis cost**: degree-6 still wins on
uniform/broadcast/hotspot workloads even with the worse-than-assumed
1.8× cell ratio. Stencil still loses (1-hop tradeoff unchanged).

cross-over (where hex stops winning lat):
```
hex_hops × (t_r6 + 100) = mesh_hops × 200
34 × (t_r6 + 100) = 64 × 200 = 12800
t_r6 + 100 = 12800 / 34 = 376
t_r6_crit  = 276
```

t_r6 = 180 is well below 276 → comfortable margin (~50% safety).

## What's still missing for **tapeout-ready** signoff

| step | tool | status |
|---|---|---|
| RTL synthesis | yosys generic | ✅ done (this commit) |
| PDK mapping (cells → SKY130 std cells) | yosys + sky130 lib | ⏳ next |
| static timing analysis | OpenSTA | ⏳ pending |
| place & route | OpenROAD | ⏳ hexa-arch[chip] |
| design-rule check | KLayout / Magic | ⏳ hexa-arch[chip] |
| LVS / DRC signoff | full PDK flow | ⏳ hexa-arch[chip] |

Cell counts here are **generic**, not mapped to SKY130. Real area in
mm² requires PDK std-cell library mapping (`yosys -p "abc -liberty
sky130_fd_sc_hd__tt_025C_1v80.lib"`). That's the next step toward
strict tapeout-ready.

## Source pointer

- RTL: `comb/rtl/router_d{4,6}.v`
- Translated for yosys: `build/artifacts/router_d{4,6}.v2k` (sv2v output)
- Stat output: `comb/rtl/router_d{4,6}.synth.out`
- F1 cost model: `comb/sim/f1_parametric.hexa` + `workload_f1.hexa`
- T1-A analytical anchor: `comb/T1A_analytical.md`
