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

| flow              | area ratio (d6/d4) |
|-------------------|-------------------:|
| generic synth     | 1.80× (no PDK)    |
| Xilinx Artix-7    | **1.37×** (FPGA)  |
| Lattice ECP5      | **1.41×** (FPGA)  |
| ASIC (SKY130/gf180mcu) | pending — .lib not fetched (GitHub repo path) |

Real-PDK ratios converge at **1.37-1.41×** (±3%). Two independent flows.

## F1 verdict with measured 1.37×

Using `t_router_d6 = 137` (1.37× baseline) in the f1_parametric model:

```
N=1024, uniform/broadcast/hotspot (3*avgH_mesh=64, 3*avgH_hex=34):
  lat_hex = 34 × (137 + 100) = 8058    lat_mesh = 64 × 200 = 12800
  e_hex   = 34 × (137+100+137+130)/2 = 34 × 252 = 8568
  e_mesh  = 64 × 200 = 12800

ratios: lat_hex/lat_mesh = 0.629  (hex 37% faster)
        e_hex/e_mesh    = 0.669  (hex 33% lower)
```

**F1 verdict survives — and is stronger** than with the 1.50× assumption.
The hex 1/√3 hop reduction comfortably dominates the measured 1.37× area
cost. Cross-over: `t_r6_crit ≈ 276` → 2.0× safety margin (vs 1.84× with
1.50× model).

stencil (1-hop) still loses for hex — workload-dependent verdict
unchanged.

## What's still missing for **strict tapeout-ready ASIC**

- **SKY130 std-cell `.lib`** — direct GitHub fetch returned 404 (repo
  structure moved); `volare enable --pdk sky130` needs commit metadata.
  Try `pip install ciel-cli` (newer manager) or clone `open_pdks` repo.
- **gf180mcu** (GlobalFoundries 180nm open PDK) — alternative open ASIC.
- **OpenSTA** — timing signoff against the mapped library.
- **OpenROAD** — place & route with the chosen PDK.
- **KLayout/Magic DRC** — physical signoff.

These remain `~/core/hexa-arch[chip]` absorption-track items per
`design.md` D1-D5 (the chip-domain owner pulls these tools in).

## Reproducibility

```
brew install yosys sv2v    # one-time
sv2v comb/rtl/router_d6.v > build/artifacts/router_d6.v2k
yosys -p "read_verilog build/artifacts/router_d6.v2k; synth_xilinx -family xc7 -top router_d6"
yosys -p "read_verilog build/artifacts/router_d6.v2k; synth_lattice -family ecp5 -top router_d6"
```

Outputs in `comb/rtl/router_d{4,6}.{xilinx,ecp5}.out` (raw stats).
