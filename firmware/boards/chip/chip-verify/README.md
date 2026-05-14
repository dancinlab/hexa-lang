<!-- @absorbed: 2026-05-12 -->
<!-- @parent: chip-verify/ (Wave 5 import 2026-04-14, hexa-chip commit 3f2c2b7) -->
<!-- @scope: navigation index for the chip-verify empirical harness -->
<!-- @sister: terafab/README.md + exynos/README.md — same README grammar -->

# chip-verify — Empirical chip verification harness

> **Status (Wave J, 2026-05-12)**: T3 RUNTIME — permanent runtime
> integration. 22 imported .hexa scripts + 4 .md reports + 1 .json
> fixture, dispatchable via `chip-verify/cli.hexa` and wired into
> `make ci` via `verify/chip_verify_bridge.hexa`.
>
> **The 29-verb / 6-group canonical surface is NOT affected by this
> directory.** chip-verify is an *empirical sandbox*, not a verb.
> The boot-matrix headline 34/36 (94.4%) is the documented aggregate;
> the 2/36 (5.6%) failure cells (HEXA-TOPO × {Starlink, LoRaWAN}) are
> real and stay visible.

## Status badges

- **Closure**: `SPEC_PLUS_RUNNABLE` (see [CLOSURE.md](./CLOSURE.md))
- **Inventory**: 22 .hexa / 4 .md / 1 .json — locked by `cli.hexa inventory`
- **Boot-matrix headline**: 34/36 = 94.4% (per `boot_matrix_report.md` §1)
- **NDA content**: zero
- **Verb-surface impact**: zero (29-verb / 6-group counts unchanged)
- **Provenance**: Wave 5 import (2026-04-14, hexa-chip commit `3f2c2b7`)
- **Determinism**: LCG seed=42 reproducible

## Quick start

```
# from repo root
make chip-verify                     # 22-script aggregate (human-readable)
make chip-verify-list                # enumerate the 22 scripts
make chip-verify-inventory           # 22/4/1 file-count invariant
make chip-verify-json                # machine-readable JSON aggregate

# direct dispatcher
HEXA_CHIP_ROOT=$PWD hexa run chip-verify/cli.hexa report
HEXA_CHIP_ROOT=$PWD hexa run chip-verify/cli.hexa run boot_matrix_3x12

# bridged into the unified verifier
HEXA_CHIP_ROOT=$PWD hexa run verify/cli.hexa chip-verify
```

## Files

### Wave-J harness (added 2026-05-12)

| File | Role |
|---|---|
| [`cli.hexa`](./cli.hexa) | Dispatcher: `list` / `run <name>` / `all` / `report` / `inventory` |
| [`inventory.hexa`](./inventory.hexa) | 22/4/1 file-count invariant guard |
| [`aggregate.hexa`](./aggregate.hexa) | JSON aggregate emitter |
| [`CLOSURE.md`](./CLOSURE.md) | 7-section closure declaration (this Wave J promotion) |
| [`README.md`](./README.md) | this file |

### Imported corpus (Wave 5, 2026-04-14, commit `3f2c2b7`)

Reports (4):
- [`boot_matrix_report.md`](./boot_matrix_report.md) — CHIP-P3-3 3 chips × 12 protocols boot matrix (the 94.4% headline source)
- [`soc_bench_promotion_report.md`](./soc_bench_promotion_report.md) — CHIP-P5-2 N6-SPEAK SoC integration bench 56/56 PASS [10*]
- [`stage0_rerun_report.md`](./stage0_rerun_report.md) — stage0 live-run re-verification report (13 .hexa files)
- [`verify_chain.md`](./verify_chain.md) — Verification chain: chip-3d → smr-datacenter → digital-twin

Fixture (1):
- [`boot_matrix_3x12.json`](./boot_matrix_3x12.json) — JSON ground-truth for the boot matrix (seed=42 LCG)

Scripts (22), grouped by experiment family:

**Family A — CHIP-P3-3 / P2-2 headline experiments (2 scripts)**
- [`boot_matrix_3x12.hexa`](./boot_matrix_3x12.hexa) — 3 chips × 12 protocols boot matrix (34/36 = 94.4%)
- [`sim_noc_bott8_1Mcycle.hexa`](./sim_noc_bott8_1Mcycle.hexa) — HEXA-TOPO Bott-8 NoC 1M cycle simulation

**Family B — Multi-domain n=6 alignment (5 scripts)**
- [`verify_chip-3d.hexa`](./verify_chip-3d.hexa) — 3D-stacked chip n=6 alignment (5-axis EXACT)
- [`verify_dse_cache_6level.hexa`](./verify_dse_cache_6level.hexa) — DSE 6-level cache hierarchy
- [`verify_npu_systolic_6x6.hexa`](./verify_npu_systolic_6x6.hexa) — NPU 6×6 systolic array
- [`verify_protocol_bridge.hexa`](./verify_protocol_bridge.hexa) — Protocol bridge interface count
- [`verify_rtl_6stage_pipeline.hexa`](./verify_rtl_6stage_pipeline.hexa) — RTL 6-stage pipeline

**Family C — Xn6 microarchitecture leaves (15 scripts)**
- [`verify_xn6_branch_predictor.hexa`](./verify_xn6_branch_predictor.hexa) — branch predictor
- [`verify_xn6_dma_6channel.hexa`](./verify_xn6_dma_6channel.hexa) — DMA 6-channel (stub)
- [`verify_xn6_fpu_6lane.hexa`](./verify_xn6_fpu_6lane.hexa) — FPU 6-lane FMA (stub)
- [`verify_xn6_hls_6stage.hexa`](./verify_xn6_hls_6stage.hexa) — HLS 6-stage synthesis (stub)
- [`verify_xn6_interconnect_6port.hexa`](./verify_xn6_interconnect_6port.hexa) — interconnect 6-port
- [`verify_xn6_io_6pcie.hexa`](./verify_xn6_io_6pcie.hexa) — I/O 6-lane PCIe (stub)
- [`verify_xn6_isa_24ops.hexa`](./verify_xn6_isa_24ops.hexa) — ISA J₂ = σ·φ = 24 ops completeness
- [`verify_xn6_issue_width_6.hexa`](./verify_xn6_issue_width_6.hexa) — issue-width 6
- [`verify_xn6_mesh_6x6.hexa`](./verify_xn6_mesh_6x6.hexa) — mesh 6×6 = 36 tiles (stub)
- [`verify_xn6_power_gating_6.hexa`](./verify_xn6_power_gating_6.hexa) — power-gating 6-state (currently FAIL 2/3)
- [`verify_xn6_regfile_24_entries.hexa`](./verify_xn6_regfile_24_entries.hexa) — register file 24 entries
- [`verify_xn6_simd_6way.hexa`](./verify_xn6_simd_6way.hexa) — SIMD 6-way (stub)
- [`verify_xn6_thermal_6zone.hexa`](./verify_xn6_thermal_6zone.hexa) — thermal 6-zone (stub)
- [`verify_xn6_tlb_64entries.hexa`](./verify_xn6_tlb_64entries.hexa) — TLB 64 entries = φⁿ (stub)
- [`verify_xn6_vector_width.hexa`](./verify_xn6_vector_width.hexa) — vector width

## Aggregate verdict distribution (observed at Wave J promotion)

| Verdict | Count | Note |
|---|---:|---|
| PASS    | 10 | RUNNABLE scripts emitting `[상태] pass` |
| PENDING |  8 | STUB scripts emitting `[상태] pending` |
| FAIL    |  1 | `verify_xn6_power_gating_6` (2/3 internal threshold) |
| ERROR   |  3 | stage0 double-main provenance — see CLOSURE.md §4 |
| **Total** | **22** | |

The aggregate verdict is **informational**, not gating. The `make ci`
chain gates only on the inventory invariant (22/4/1 file counts), not on
the per-script PASS/FAIL distribution. The 3 ERROR scripts (`boot_matrix_3x12`,
`verify_chip-3d`, `verify_protocol_bridge`) use the legacy stage0 double-main
convention and are preserved verbatim per the no-rewrite rule.

## Quick-recall facts

| Fact | Value |
|---|---|
| Imported .hexa scripts | 22 |
| .md reports | 4 |
| .json fixtures | 1 |
| Wave-J harness files | 5 (cli.hexa + inventory.hexa + aggregate.hexa + CLOSURE.md + README.md) |
| Boot-matrix headline | 34/36 = 94.4% |
| Boot-matrix failure cells | 2/36 = 5.6% (HEXA-TOPO × {Starlink, LoRaWAN}) |
| LCG seed | 42 (Numerical Recipes 1664525/1013904223/2147483647) |
| Closure verdict | SPEC_PLUS_RUNNABLE |
| Verb-surface impact | none (29-verb / 6-group unchanged) |
| NDA content | none |
| Provenance | hexa-chip Wave 5 (commit `3f2c2b7`, 2026-04-14) |
| Promoted at | Wave J (2026-05-12, T4 KNOWLEDGE → T3 RUNTIME) |

## Cross-link

- [`CLOSURE.md`](./CLOSURE.md) — 7-section closure declaration for chip-verify
- [`../hexa.toml`](../hexa.toml) `[chip_verify_closure]` — authoritative numbers
- [`../verify/cli.hexa`](../verify/cli.hexa) — unified verifier (registers `chip-verify` as one of the checks via `chip_verify_bridge.hexa`)
- [`../verify/chip_verify_bridge.hexa`](../verify/chip_verify_bridge.hexa) — Wave J bridge between verify/cli.hexa and chip-verify/cli.hexa
- [`../CATALOG.md`](../CATALOG.md) — repo taxonomy (chip-verify moved from T4 KNOWLEDGE to T3 RUNTIME at Wave J)
- [`../CHANGELOG.md`](../CHANGELOG.md) — Wave J entry documenting the promotion
- [`../terafab/CLOSURE.md`](../terafab/CLOSURE.md) and [`../exynos/CLOSURE.md`](../exynos/CLOSURE.md) — sister closure declarations (different scopes; meta-domain envelopes vs empirical harness)

---

**End of chip-verify README** — empirical sandbox; 34/36 = 94.4% is the
documented number; the 5.6% failure rate stays visible.
