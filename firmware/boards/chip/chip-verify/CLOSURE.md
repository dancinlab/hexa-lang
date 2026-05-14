<!-- @absorbed: 2026-05-12 -->
<!-- @parent: chip-verify/ (Wave 5 import 2026-04-14, hexa-chip commit 3f2c2b7) -->
<!-- @scope: closure declaration for the chip-verify empirical harness promotion (Wave J) -->
<!-- @sister: terafab/CLOSURE.md + exynos/CLOSURE.md — same closure grammar, different scope -->
---
type: closure-declaration
parent: chip-verify/
verdict: SPEC_PLUS_RUNNABLE
component: chip-verify-empirical-harness
scripts_total: 22
reports_total: 4
fixtures_total: 1
aggregate_pass_rate: 0.944
nda_content: false
date: 2026-05-12
commit_basis: Wave J (chip-verify T4 KNOWLEDGE -> T3 RUNTIME promotion)
verb_surface_unchanged: true
---

# chip-verify — Closure Declaration (Wave J)

> **Closure scope**: this document declares closure for the
> **chip-verify empirical harness** only. chip-verify is **NOT a verb**
> and **NOT a meta-domain envelope** — it is an empirical sandbox
> imported at Wave 5 (2026-04-14, commit `3f2c2b7`) for chip-architecture
> / NoC / SoC integration experiments. Verb-level closure for hexa-chip's
> 29-verb / 6-group surface is governed by the separate `[closure]` block
> in `hexa.toml` and is unchanged by this declaration.

## §1 Closure verdict

**`verdict = SPEC_PLUS_RUNNABLE`**

The chip-verify harness ships with (a) the original Wave-5 corpus of
22 `.hexa` scripts + 4 `.md` reports + 1 `.json` fixture (provenance-pinned;
not rewritten by Wave J), and (b) a Wave-J runnable dispatcher
(`chip-verify/cli.hexa`) plus aggregate and inventory wrappers that wire
the corpus into the unified `verify/cli.hexa` + `make ci` chain via
`verify/chip_verify_bridge.hexa`.

Mirrors `hexa.toml` `[chip_verify_closure].verdict = "SPEC_PLUS_RUNNABLE"`
(single source of truth — re-derive at any time with the §6 recipe).

**This closure is parallel to** the `[meta_domain_closure]`
(terafab + exynos envelopes). chip-verify is **not** a meta-domain
envelope — it has no falsifier register, no 15-section spec doc, and
does not wrap the 6 hexa-chip groups. It is an *empirical witness layer*
sitting alongside (not above) the canonical verify surface.

## §2 Closure inventory

| File | Lines | Role | Tier |
|---|---:|---|---|
| **Imported corpus (Wave 5, 2026-04-14, commit `3f2c2b7`)** | | | |
| `boot_matrix_3x12.hexa`                       | 195 | CHIP-P3-3 3 chips x 12 protocols boot matrix (34/36 = 94.4%) | RUNNABLE_LEGACY |
| `boot_matrix_3x12.json`                       |   ~ | JSON fixture for the boot matrix | FIXTURE |
| `boot_matrix_report.md`                       | 118 | CHIP-P3-3 report (the 94.4% headline source) | REPORT |
| `sim_noc_bott8_1Mcycle.hexa`                  | 113 | CHIP-P2-2 HEXA-TOPO Bott-8 NoC 1M cycle simulation | RUNNABLE |
| `verify_chip-3d.hexa`                         |  58 | 3D-stacked chip n=6 alignment (5-axis EXACT) | RUNNABLE_LEGACY |
| `verify_dse_cache_6level.hexa`                |  47 | DSE 6-level cache hierarchy | RUNNABLE |
| `verify_npu_systolic_6x6.hexa`                |  49 | NPU 6x6 systolic array | RUNNABLE |
| `verify_protocol_bridge.hexa`                 | 684 | Protocol bridge interface count | RUNNABLE_LEGACY |
| `verify_rtl_6stage_pipeline.hexa`             |  46 | RTL 6-stage pipeline | RUNNABLE |
| `verify_xn6_branch_predictor.hexa`            |  53 | Xn6 branch predictor | RUNNABLE |
| `verify_xn6_dma_6channel.hexa`                |  13 | Xn6 DMA 6-channel (stub) | STUB |
| `verify_xn6_fpu_6lane.hexa`                   |  13 | Xn6 FPU 6-lane FMA (stub) | STUB |
| `verify_xn6_hls_6stage.hexa`                  |  13 | Xn6 HLS 6-stage synthesis (stub) | STUB |
| `verify_xn6_interconnect_6port.hexa`          |  41 | Xn6 interconnect 6-port | RUNNABLE |
| `verify_xn6_io_6pcie.hexa`                    |  13 | Xn6 I/O 6-lane PCIe (stub) | STUB |
| `verify_xn6_isa_24ops.hexa`                   |  39 | Xn6 ISA J2 = sigma*phi = 24 ops completeness | RUNNABLE |
| `verify_xn6_issue_width_6.hexa`               |  43 | Xn6 issue-width 6 | RUNNABLE |
| `verify_xn6_mesh_6x6.hexa`                    |  13 | Xn6 mesh 6x6 = 36 tiles (stub) | STUB |
| `verify_xn6_power_gating_6.hexa`              |  52 | Xn6 power-gating 6-state (currently FAIL 2/3) | RUNNABLE |
| `verify_xn6_regfile_24_entries.hexa`          |  46 | Xn6 register file 24 entries | RUNNABLE |
| `verify_xn6_simd_6way.hexa`                   |  13 | Xn6 SIMD 6-way (stub) | STUB |
| `verify_xn6_thermal_6zone.hexa`               |  13 | Xn6 thermal 6-zone (stub) | STUB |
| `verify_xn6_tlb_64entries.hexa`               |  13 | Xn6 TLB 64 entries (stub) | STUB |
| `verify_xn6_vector_width.hexa`                |  48 | Xn6 vector width | RUNNABLE |
| `soc_bench_promotion_report.md`               |  82 | CHIP-P5-2 N6-SPEAK SoC integration benchmark 56/56 PASS [10*] | REPORT |
| `stage0_rerun_report.md`                      | 208 | stage0 live-run re-verification report — 13 .hexa files | REPORT |
| `verify_chain.md`                             |  81 | Verification chain: chip-3d -> smr-datacenter -> digital-twin | REPORT |
| **Wave-J harness (added 2026-05-12)** | | | |
| `cli.hexa`                                    | ~325 | Wave-J dispatcher (list / run / all / report / inventory) | RUNNABLE |
| `inventory.hexa`                              |  ~22 | 22/4/1 file-count invariant guard | RUNNABLE |
| `aggregate.hexa`                              |  ~18 | JSON aggregate emitter | RUNNABLE |
| `CLOSURE.md`                                  | this | Closure declaration (this document) | SPEC |
| `README.md`                                   | new  | Navigation index with status badges + 22-script family grouping | SPEC |

**Tier legend**:
- `RUNNABLE` — exits 0 with a `[상태] pass` (or `[status] pass`) marker
- `RUNNABLE_LEGACY` — uses the stage0 double-main convention (`fn main()` + explicit `main()` call at file foot); under the current hexa-strict auto-invoke they exit non-zero. Preserved per the no-rewrite rule.
- `STUB` — stub script that prints `[상태] pending`; placeholder for future per-domain experiments
- `REPORT` — markdown report (provenance-pinned to Wave 5)
- `FIXTURE` — JSON data (deterministic seed=42 LCG)
- `SPEC` — declarative document (this CLOSURE.md, README.md)

## §3 Closure invariants asserted

The chip-verify harness holds the following invariants. Each is exercised
by `chip-verify/cli.hexa` and/or the verify dispatcher bridge:

1. **22 imported .hexa scripts present.** Asserted by
   `chip-verify/cli.hexa inventory`; mirrored in
   `hexa.toml [chip_verify_closure].scripts_total = 22`. Drift fails the
   inventory check.
2. **4 .md reports present.** boot_matrix_report.md +
   soc_bench_promotion_report.md + stage0_rerun_report.md +
   verify_chain.md. Mirrored in `[chip_verify_closure].reports_total = 4`.
3. **1 .json fixture present.** boot_matrix_3x12.json. Mirrored in
   `[chip_verify_closure].fixtures_total = 1`.
4. **Boot-matrix headline 34/36 = 94.4%.** Per `boot_matrix_report.md`
   §1. Mirrored in `[chip_verify_closure].aggregate_pass_rate = 0.944`.
   **Not** 100% — the 2/36 failure cells (HEXA-TOPO × Starlink,
   HEXA-TOPO × LoRaWAN) are real and documented.
5. **29-verb / 6-group surface unchanged.**
   `hexa.toml [closure].verbs_total = 29` and `groups_total = 6` are
   not bumped; `[chip_verify_closure].verb_surface_unchanged = true`
   asserts the contract.
6. **0 NDA content.** Every chip-verify script computes from n=6
   primitives (sigma=12, tau=4, phi=2, sopfr=5, J2=24) and the
   LCG seed=42 PRNG. No vendor PDK, no proprietary process kit, no
   Samsung/SK·Hynix/TSMC/Intel internal data.
7. **Deterministic reproducibility (seed=42 LCG).** Every script that
   uses randomness pins the LCG seed; output is byte-identical across
   runs. The boot_matrix_3x12.json fixture is the captured ground truth.

## §4 Closure caveats (raw#10 honest C3)

Honest readings of what this closure does NOT yet prove:

- **chip-verify is NOT the 30th verb.** The verb surface stays at 29;
  chip-verify is empirical witness, not a canonical sandbox. Promoting
  any chip-verify experiment to a verb requires the 9-step T5 release
  checklist in `CATALOG.md`.
- **chip-verify does NOT validate the 29-verb canonical closure.** That
  is `verify/cli.hexa`'s job (27 checks, 26 PASS at Wave J). The
  chip-verify aggregate is supplementary.
- **The 94.4% is the boot-matrix headline, not the harness aggregate.**
  The 22-script harness aggregate is mixed:
  - 10 PASS (RUNNABLE scripts emit `[상태] pass`)
  - 8 PENDING (STUB scripts emit `[상태] pending`)
  - 1 FAIL (`verify_xn6_power_gating_6` 2/3)
  - 3 ERROR (`boot_matrix_3x12`, `verify_chip-3d`, `verify_protocol_bridge`
    — stage0 double-main provenance)
  This breakdown is surfaced by `chip-verify/cli.hexa report --json`.
- **3 ERROR scripts use the legacy stage0 double-main convention.** They
  define `fn main()` AND append an explicit `main()` call at file foot;
  under current hexa-strict auto-invoke this errors. Per the no-rewrite
  rule, the files are preserved verbatim from Wave 5. They are honestly
  reported as ERROR by the dispatcher.
- **8 STUB scripts only emit a pending marker.** They are placeholder
  experiment skeletons (verify_xn6_dma_6channel, _fpu_6lane, _hls_6stage,
  _io_6pcie, _mesh_6x6, _simd_6way, _thermal_6zone, _tlb_64entries) for
  domains where the empirical Wave-5 experiment was not yet authored.
  Promoting any of them to RUNNABLE is a separate event.
- **The boot-matrix 34/36 is heuristic simulation, not hardware boot.**
  Per `boot_matrix_report.md` §1: "No actual hardware boot — heuristic
  simulation only." The 94.4% is the simulator's verdict on a
  reproducible LCG-seeded scenario.
- **Closure is for the chip-verify HARNESS only.** Verb-level closure
  for the 29-verb / 6-group surface is governed by `hexa.toml [closure]`
  and is unchanged by this declaration.

## §5 What this closure does NOT claim

Negative declarations to keep the harness honest:

- Does **NOT** add a 30th verb — surface stays at 29.
- Does **NOT** add a 3rd meta-domain envelope — chip-verify is not
  parallel to terafab/exynos.
- Does **NOT** validate any vendor boot stack — the 12 protocols
  (6G/5G/WiFi6/Starlink/LoRaWAN/BT6.0/PCIe/USB/NVMe/Ethernet/DP/HDMI)
  are simulated against n=6 arithmetic targets, not against actual
  silicon or vendor SDKs.
- Does **NOT** claim 100% pass — explicitly registers the 2/36 cell
  failure (HEXA-TOPO x {Starlink, LoRaWAN}) per the boot_matrix_report
  honesty audit.
- Does **NOT** include NDA / proprietary / vendor-internal data —
  every numeric trace to n=6 primitives + LCG seed=42.
- Does **NOT** rewrite the Wave-5 imported corpus — the 22 .hexa files,
  4 .md reports, and 1 .json fixture remain byte-identical to commit
  `3f2c2b7`.

## §6 Re-verification recipe

Three commands to re-verify closure at any time. All stdlib-only via
the hexa-stage0 interpreter; no external Python / Node required.

```
HEXA_CHIP_ROOT=$PWD hexa run chip-verify/cli.hexa inventory   # 22/4/1 invariant
HEXA_CHIP_ROOT=$PWD hexa run chip-verify/cli.hexa report      # human-readable aggregate
HEXA_CHIP_ROOT=$PWD hexa run chip-verify/cli.hexa report --json   # machine-readable
```

Or via the Makefile aggregator:

```
make chip-verify              # human aggregate
make chip-verify-inventory    # 22/4/1 invariant only
make chip-verify-json         # JSON
make ci                       # full chain incl. chip-verify
```

Expected sentinels (must appear):

- `cli.hexa inventory` -> `[PASS] 22 imported .hexa + 4 .md + 1 .json - chip-verify inventory locked`
- `cli.hexa report --json` -> JSON with `"total":22, "boot_matrix_headline":"34/36 = 94.4%", "verb_surface_unchanged":true`
- `verify/cli.hexa chip-verify` -> `[PASS] chip-verify` (bridge passes when inventory holds; aggregate counters are informational)

A complementary audit covers cross-doc agreement:

```
python3 terafab/cross_doc_audit.py           # extended at Wave J to audit [chip_verify_closure]
python3 verify_catalog.py                    # extended to move chip-verify to T3 RUNTIME
```

## §7 Sign-off

Empirical harness permanent runtime integration complete.

- **Date**: 2026-05-12
- **Wave**: J (chip-verify T4 KNOWLEDGE -> T3 RUNTIME promotion)
- **Commit basis**: Wave J integration commit (this commit; see git log).
  Previous chip-verify content was imported at Wave 5 (2026-04-14, commit
  `3f2c2b7`) and is preserved verbatim.
- **Author**: 박민우 <nerve011235@gmail.com>
- **License**: MIT (inherits from repository)
- **Provenance**: original to hexa-chip (Wave 5 import 2026-04-14); zero
  NDA / proprietary / vendor-internal content; every numeric traces to
  n=6 primitives + LCG seed=42.

---

**Closure verdict re-asserted**: `verdict = SPEC_PLUS_RUNNABLE`
(also recorded in `hexa.toml [chip_verify_closure].verdict` — single
source of truth; re-verify any time with the §6 recipe).
