# comb/rtl PDK-mapped synthesis — measured area across real cell libraries

> 2026-05-18 · Two independent real-PDK synthesis flows for cross-check.
> Generic synth gave 1.80× (combinational explosion); real PDK mapping
> drops to **1.37-1.41×** because hex's 3-axis route compare and 7-input
> arbiter pack efficiently into LUT6 / LUT4 cells.

## Real-PDK results

### Xilinx Artix-7 (`synth_xilinx -family xc7`)

| metric          | router_d4 | router_d6 | ratio  |
|-----------------|----------:|----------:|-------:|
| total cells     |    21,522 |    28,882 | 1.34×  |
| Logic Cells (LCs)|   11,651 |    15,968 | **1.37×** |
| FDRE (flops)    |     1,647 |     2,295 | 1.39×  |
| LUT6            |     4,645 |     6,474 | 1.39×  |
| LUT5            |     2,289 |     3,199 | 1.40×  |
| LUT3            |     4,012 |     5,594 | 1.39×  |
| CARRY4          |     3,889 |     5,251 | 1.35×  |

### Lattice ECP5 (`synth_lattice -family ecp5`)

| metric          | router_d4 | router_d6 | ratio  |
|-----------------|----------:|----------:|-------:|
| total submodules|     6,216 |     8,743 | **1.41×** |
| LUT4            |     2,988 |     4,432 | 1.48×  |
| TRELLIS_FF      |     1,638 |     2,295 | 1.40×  |
| L6MUX21         |       395 |       437 | 1.11×  |
| PFUMX           |     1,175 |     1,371 | 1.17×  |
| CCU2C (carry)   |        20 |       208 | 10.4×† |

† small absolute counts; ratio inflated by base of 20.

### Cross-PDK agreement

| flow                              | area ratio (d6/d4) |
|-----------------------------------|-------------------:|
| generic synth                     | 1.80× (no PDK)    |
| Xilinx Artix-7                    | **1.37×** (FPGA)  |
| Lattice ECP5                      | **1.41×** (FPGA)  |
| **SKY130 ASIC (`sky130_fd_sc_hd`, tt corner)** | **1.516×** 🎉 |

**SKY130 ASIC area (μm²)**:

| metric           |   router_d4 |   router_d6 | ratio |
|------------------|------------:|------------:|------:|
| **chip area**    | **61,762.99** | **93,608.53** | **1.516×** |
| sequential       | 48,956.95 (79%) | 68,485.68 (73%) | 1.399× |
| combinational    | 12,806.03 | 25,122.85 | 1.962× |

Real ASIC area in μm² mapped to SKY130 `sky130_fd_sc_hd` cells via
`yosys synth + dfflibmap + abc`. d4 = 0.062 mm², d6 = 0.094 mm². The
1.52× ASIC ratio sits between generic (1.80×) and FPGA (1.37-1.41×):
ASIC's wide std-cell library packs combinational logic more compactly
than generic but less than FPGA LUT6.

Note: ASIC ratio decomposes as 1.40× sequential (flops scale with port
count) and 1.96× combinational (hex's 3-axis route compare + 7-input
arbiter is genuinely more logic). FPGA hides much of the combinational
gap inside LUT6/CARRY; ASIC reveals it.

## F1 verdict with measured SKY130 ASIC 1.52×

Using `t_router_d6 = 152` (the actual SKY130-measured area ratio) in
the f1_parametric model:

```
N=1024, uniform/broadcast/hotspot (3*avgH_mesh=64, 3*avgH_hex=34):
  lat_hex = 34 × (152 + 100) = 8568    lat_mesh = 64 × 200 = 12800
  e_hex   = 34 × (152+100+152+130)/2 = 34 × 267 = 9078
  e_mesh  = 64 × 200 = 12800

ratios: lat_hex/lat_mesh = 0.669  (hex 33% faster)
        e_hex/e_mesh    = 0.709  (hex 29% lower energy)
```

**F1 verdict survives under measured SKY130 ASIC area cost.** Hex 1/√3
hop reduction dominates the measured 1.52× area cost. Cross-over:
`t_r6_crit ≈ 276` → ~1.8× safety margin (was 2.0× with FPGA 1.37×).

Compare verdict robustness across PDK flows:

| flow            | t_r6 | lat_hex/lat_mesh | e_hex/e_mesh |
|-----------------|-----:|-----------------:|-------------:|
| 1.50× assumed   |  150 | 0.664 (33% win)  | 0.664 (33% win) |
| FPGA Xilinx 1.37× | 137 | 0.629 (37% win)  | 0.669 (33% win) |
| **SKY130 ASIC 1.52×** | **152** | **0.669 (33% win)** | **0.709 (29% win)** |
| generic 1.80×   |  180 | 0.744 (26% win)  | 0.784 (22% win) |

stencil (1-hop) still loses for hex across all flows — workload-
dependent verdict unchanged.

## What's still missing for **strict tapeout-ready ASIC**

- ~~**SKY130 std-cell `.lib`**~~ ✅ **OBTAINED** via `git clone
  efabless/skywater-pdk-libs-sky130_fd_sc_hd` (the original
  `google/skywater-pdk-libs-sky130_fd_sc_hd` returns 404 — repo moved
  to efabless mirror). `.lib` = 12.8 MB at `/tmp/sky130/.../timing/
  sky130_fd_sc_hd__tt_025C_1v80.lib`. Used in this commit.
- **OpenSTA** — timing signoff: brew has no formula; needs source build
  (CMake + dependencies). Pending. Without STA we have *area* but not
  *fmax* / setup/hold margin.
- **OpenROAD** — place & route: heavy install, not in brew. P&R gives
  real wire lengths + congestion + die size.
- **KLayout/Magic DRC** — physical signoff.

Of the originally-listed blockers, **SKY130 lib is no longer a blocker**;
OpenSTA + OpenROAD + DRC remain as tool-install gates (substantial but
in principle doable). These plus T3 GDSII delivery sit on the
`~/core/hexa-arch[chip]` absorption-track per its `design.md` D1-D5.

## Reproducibility

```
brew install yosys sv2v    # one-time
sv2v comb/rtl/router_d6.v > build/artifacts/router_d6.v2k
yosys -p "read_verilog build/artifacts/router_d6.v2k; synth_xilinx -family xc7 -top router_d6"
yosys -p "read_verilog build/artifacts/router_d6.v2k; synth_lattice -family ecp5 -top router_d6"
```

Outputs in `comb/rtl/router_d{4,6}.{xilinx,ecp5}.out` (raw stats).
