# firmware/asic/ — SkyWater 130nm tape-out flow

> §A.6.1 step E4 — ASIC implementation flow stub for the timing
> controller, targeting Google + SkyWater open SKY130 PDK.
>
> **Status**: paper-only flow stub (2026-05-08). Real synthesis +
> place-and-route + GDS generation requires:
> - OpenLane (Yosys + OpenROAD + Magic + KLayout) installation
> - SKY130 PDK download (~6 GB)
> - 8+ CPU hours per run
> - Multi-project shuttle slot at Efabless / OpenMPW (~6 month cadence)
>
> **Cost estimate** (post-§A.6 step 2 funding):
> - SKY130 shuttle slot: free (Google-sponsored OpenMPW for open-source
>   projects)
> - OpenLane compute: ~$0 on local server / ~$10 cloud per run
> - Wafer-scale tape-out (private):  ~$10k for SKY130, ~$300k+ for TSMC 28nm

## Scope (in-repo)

What this directory delivers:

| file                                  | purpose                                |
|:--------------------------------------|:---------------------------------------|
| `timing_ctrl_sky130/config.tcl`       | OpenLane configuration                 |
| `timing_ctrl_sky130/Makefile`         | flow harness (prints status if no toolchain) |
| `timing_ctrl_sky130/pin_order.cfg`    | I/O pad ordering                       |
| `timing_ctrl_sky130/sky130_top.v`     | top-level wrapper for SKY130 IO pads   |
| `timing_ctrl_sky130/synth_check.sv`   | SystemVerilog synth-friendliness check |
| `README.md`                            | this file                              |

What this directory does NOT deliver:

| missing                              | reason                                 |
|:-------------------------------------|:--------------------------------------|
| GDS file                             | requires OpenROAD installation         |
| LEF / DEF                             | same                                   |
| Synthesised gate netlist              | requires Yosys                         |
| Timing report (STA)                   | requires OpenSTA                       |
| DRC / LVS clean                       | requires Magic + KLayout               |
| Tape-out submission                    | requires Efabless OpenMPW slot          |

## Why ASIC at all?

For a benchtop one-off, FPGA is the right answer. ASIC enters the
conversation only when:

1. Volume > 10k boards (highly unlikely for a research instrument)
2. Very-low-jitter clocking requires custom analog (out-of-scope for
   SKY130; Skywater 130nm is digital + mixed-signal limited)
3. Radiation-hardened version needed (SkyWater isn't rad-hard; would
   need TSMC 90nm rad-hard cells)

Practical path: **stay FPGA** through Phase E. ASIC is
"future-when-funding" deferred to v3.0.0+.

## Path to GDS (when funded)

```
Stage 1: Synthesis
  yosys -p "synth -top timing_ctrl_top" -o synth.v *.v

Stage 2: Floor-plan
  openroad -script floorplan.tcl

Stage 3: Place + route
  openroad -script place_route.tcl

Stage 4: Sign-off
  openroad -script sta.tcl
  magic -dnull -noconsole drc.tcl
  netgen -batch lvs

Stage 5: GDS export
  klayout -batch -r gds_export.py
```

Each stage produces an artifact that lands in `target/sky130/`
(gitignored). Open the resulting GDS in KLayout for visual verify.

## Cross-references

- `firmware/hdl/timing_ctrl.v` — RTL source
- `firmware/hdl/timing_ctrl_top.v` — wrapper this maps to ASIC
- `firmware/hdl/testbench/timing_ctrl_top_tb.v` — regression baseline
- SKY130 PDK: https://github.com/google/skywater-pdk
- OpenLane:    https://github.com/The-OpenROAD-Project/OpenLane
- Efabless OpenMPW: https://efabless.com/open_shuttle_program
