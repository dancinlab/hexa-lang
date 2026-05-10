# firmware/doc/ — Phase D+ chip design + schematics + pinout

> §A.6.1 Phase D+ deliverable per `.roadmap.hexa_rtsc`. Paper design
> only. Skeleton-traceable to Stage A specs and Phase C/D code.

## Files

| File | Purpose |
|:----|:--------|
| `chip_design.md` | Silicon inventory, pin assignments, ASCII schematics, power budget, PCB stackup |
| `pinout_summary.md` | Quick-ref pinout for STM32F4 + Artix-7, datasheet links, spec traceability |

## Layered relationship

```
                .roadmap §A.6.1
                       │
         ┌─────────────┼─────────────┬─────────────┬─────────────┐
         ▼             ▼             ▼             ▼             ▼
       Stage A     Stage B       Stage C       Stage D       Stage D+
       paper      sim parity    sim-firmware   skeleton      verified
       design     (.hexa)       (.hexa)        (HDL/MCU)     (this dir)
       (3 docs)   (3 scripts)   (2 scripts)    (2 files)     (3 docs +
                                                              tb + builds)
```

## Phase D+ status (2026-05-08)

| Component | Skeleton | Verified-compile | Tested |
|:---------|:--------:|:----------------:|:------:|
| chamber_drv (Rust)   | ✓ | ✓ host + cross | 5/5 host tests PASS |
| calorimetry_drv      | ✓ | ✓ host + cross | 6/6 host tests PASS |
| lib (shared)         | ✓ | ✓ host + cross | 4/4 host tests PASS |
| quench_detect (V)    | ✓ | ✓ iverilog     | 12/12 testbench PASS |
| tb_quench_detect (V) | ✓ | ✓ iverilog     | (testbench itself) |
| calorimetry_daq (V)  | ✓ | ✓ iverilog parse | (no testbench yet) |
| build.tcl + .xdc     | ✓ | (Vivado required) | — |
| **Total**            | 9 | 9 | **27/27 PASS** |

## Bridge to physical hardware (§A.6 Step 4)

| Phase | What needs to happen | Cost (cum.) | Time |
|:-----:|:--------------------|:-----------:|:----:|
| D+    | This work — done    | $0          | 1 d ✓ |
| Step 1| Collab decision (NIMS / NHMFL / Lake Shore co-dev)        | $20k pre-dev | 2–4 mo |
| Step 2| Funding round + PCB pilot run (5 boards, 3 designs)       | +$15k        | 2 mo |
| Step 2.5| Procurement (silicon + Cs ref + PSU)                    | +$140k       | 6 mo |
| Step 4| PCBA + bring-up + cold test                                | +$50k        | 4 mo |
| **Total to first flashed firmware**                              | **~$225k**   | **14–20 mo** |

## Honesty contract

This entire `firmware/doc/` directory is **spec-only**. It documents
what hardware would look like if procured. The pin assignments and
schematic topology are validated by:

- Compatibility with chosen silicon datasheets (cross-referenced)
- Cross-check against `firmware/hdl/constraints.xdc` (Vivado-parseable)
- Matching `firmware/sim/*.hexa` test scenarios

But no PCB exists. No board can be flashed. Real-hardware closure
requires §A.6 Step 4 deliverables (years out, ~$225k).
