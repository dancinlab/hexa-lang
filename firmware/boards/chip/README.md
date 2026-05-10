> **ABSORBED VIEW** — Absorbed from `~/core/hexa-chip` on 2026-05-10.
> Upstream repo retained for development; this tree is the
> consumed-by-hexa-lang view per `SPEC.yaml firmware_evolution`
> (Option C, Decision 2026-05-10). See `doc/firmware_audit_2026_05_10.md`
> and `firmware/README.md` for absorption mechanics. F4 batch.
>
> Build artifacts excluded during absorb: `build/`, `target/`,
> `state/markers/`, `.git/`, `*.o/.elf/.bin`.
> LICENSE / CITATION.cff preserved verbatim.

---

# 🔲 hexa-chip — Chip Substrate (HEXA family)

> **Chip substrate — 28-verb semiconductor stack** (architecture / design /
> EDA / process / packaging / NPU / PIM / 3D / photonic / RTL-gen / yield /
> consciousness-chip).
> Spec-first standalone extraction of the `compute/` chip-axis from
> `canon@c0f1f570` (2026-05-06), organised into **7 sister groups**
> mirroring the Korean fab heritage stack (Samsung·SK·Hynix·DRAM/HBM lineage).

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20102598.svg)](https://doi.org/10.5281/zenodo.20102598)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-informational.svg)](CHANGELOG.md)
[![Verbs: 28 / 7 groups](https://img.shields.io/badge/verbs-28%20%2F%207%20groups-blue.svg)](#verbs)
[![Status: spec-first](https://img.shields.io/badge/status-spec--first-orange.svg)](#status)
[![Provenance](https://img.shields.io/badge/from-n6--arch%40c0f1f570-purple.svg)](https://github.com/need-singularity/canon)
[![Verify: 5/5](https://img.shields.io/badge/verify-5%2F5-brightgreen.svg)](#verify)
[![Sandboxes: 29/29](https://img.shields.io/badge/sandboxes-29%2F29-brightgreen.svg)](#verify)
[![Tests: 4/4](https://img.shields.io/badge/tests-4%2F4-brightgreen.svg)](#verify)

> **Status (2026-05-07)**: v1.0.x runnable-surface buildout landed. The
> 29 verb directories are all wired with `.hexa` working sandboxes
> (`verify_<verb>.hexa` per dir), a 5-check `verify/cli.hexa` unified
> verifier mirrors hexa-sscb's `verify/cli.py` pattern, and `tests/`
> aggregates four invariant tests. `make ci` reports
> `5/5 verify · 29/29 sandboxes · 4/4 tests` PASS.
>
> v1.0.0 initial extraction (2026-05-06): 29 verb spec directories
> landed across 6 groups; per-verb sandboxes were TBD at that time.
> Wired in 2026-05-07 — see "Build & verify" below.

> **Distribution**: GitHub canonical at
> <https://github.com/need-singularity/hexa-chip>. CLI tooling — installed
> via `hx install hexa-chip` from the hexa-lang registry, or `git clone`
> directly.

---

## Why

The `canon/domains/compute/` tree had grown to 28 distinct
chip-axis modules organised by physical / functional layer. As `hexa-chip`
this becomes a **standalone substrate**: one repo, seven sister groups,
spec-first vocabulary that downstream consumers (`hexa-rtsc`, `hexa-codex`,
`anima`) can pin without dragging the full architecture monorepo.

The 7-group decomposition tracks the actual semiconductor industry stack —
from RTL down through fab process, then back up through advanced packaging
into accelerator IP and finally into the consciousness-chip experimental
axis:

```
                    ┌─────────────────────────────────┐
                    │  architecture group  (3 verbs)  │   "what to build"
                    │   architecture · isa_n6 · hexa1 │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │     design group  (5 verbs)     │   "how to draw it"
                    │ design · dse · rtl_gen · eda ·  │
                    │             verify_test         │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │    process group  (5 verbs)     │   "how to print it"
                    │ process · materials · wafer ·   │
                    │     yield · thermal_power       │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │   packaging group  (6 verbs)    │   "how to assemble it"
                    │ packaging · advanced_packaging ·│
                    │ chip_3d · hbm · interconnect ·  │
                    │              sc                 │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  accelerator group  (8 verbs)   │   "what it accelerates"
                    │ npu_n6 · pim · photonic · accel │
                    │ asic · hexa_pim · hexa_3d ·     │
                    │           hexa_wafer            │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │ consciousness group  (2 verbs)  │   "the experimental axis"
                    │ conscious_chip · conscious_soc  │
                    └─────────────────────────────────┘
```

n=6 invariant lattice (`σ(6)=12, τ(6)=4, φ(6)=2, J₂=24`) is referenced by
the ISA / architecture verbs (`isa_n6`, `hexa1`) only; the other 5 groups
inherit it as an organising convention without independent invariant-fit
verification (see Status §caveats).

---

## Verbs

28 verbs / 7 groups. Each verb maps one-to-one to a `canon/
domains/compute/<canonical-name>/` source tree extracted at SHA `c0f1f570`.

### Group A — architecture (3)

| Verb           | Source (n6-arch)                | Scope                                              |
|----------------|---------------------------------|----------------------------------------------------|
| `architecture` | `compute/chip-architecture/`    | Top-level chip architecture spec                   |
| `isa_n6`       | `compute/chip-isa-n6/`          | n=6-invariant ISA: σ=12 opcode classes / τ=4 modes |
| `hexa1`        | `compute/chip-hexa1/`           | Reference hexagonal chip-1 floorplan + tiling      |

### Group B — design (5)

| Verb           | Source (n6-arch)                | Scope                                              |
|----------------|---------------------------------|----------------------------------------------------|
| `design`       | `compute/chip-design/`          | RTL-down design methodology spec                   |
| `dse_pipeline` | `compute/chip-dse-pipeline/`    | Design-space exploration pipeline                  |
| `rtl_gen`      | `compute/chip-rtl-gen/`         | RTL generation (LLM-assisted Verilog/Chisel)       |
| `eda`          | `compute/chip-eda/`             | EDA flow integration (Cadence/Synopsys/Mentor)     |
| `verify_test`  | `compute/chip-verify-test/`     | Verification + DFT + post-Si test methodology      |

### Group C — process (5)

| Verb            | Source (n6-arch)                | Scope                                             |
|-----------------|---------------------------------|---------------------------------------------------|
| `process`       | `compute/chip-process/`         | Front-end process spec (FEOL / lithography)       |
| `materials`     | `compute/chip-materials/`       | Substrate / dielectric / metal materials          |
| `wafer`         | `compute/chip-wafer/`           | Wafer-level handling, defect density, scribe      |
| `yield`         | `compute/chip-yield/`           | Yield ramp / binning / defect Pareto              |
| `thermal_power` | `compute/chip-thermal-power/`   | Thermal envelope + power delivery network         |

### Group D — packaging (6)

| Verb                  | Source (n6-arch)                | Scope                                       |
|-----------------------|---------------------------------|---------------------------------------------|
| `packaging`           | `compute/chip-packaging/`       | Conventional packaging (FCBGA / wirebond)   |
| `advanced_packaging`  | `compute/advanced-packaging/`   | CoWoS / FOPLP / chiplet integration         |
| `chip_3d`             | `compute/chip-3d/`              | 3D-IC stacking (TSV / hybrid bonding)       |
| `hbm`                 | `compute/chip-hbm/`             | HBM stack spec (HBM3 / HBM4 / HBM-PIM)      |
| `interconnect`        | `compute/chip-interconnect/`    | On-package + off-package interconnect       |
| `sc`                  | `compute/chip-sc/`              | SC-chip substrate (depended on by hexa-rtsc)|

### Group E — accelerator (8)

| Verb          | Source (n6-arch)                | Scope                                            |
|---------------|---------------------------------|--------------------------------------------------|
| `npu_n6`      | `compute/chip-npu-n6/`          | n=6 NPU IP (σ=12 systolic lanes / τ=4 dataflow)  |
| `pim`         | `compute/chip-pim/`             | Processing-in-memory (DRAM-PIM / SRAM-PIM)       |
| `photonic`    | `compute/chip-photonic/`        | Silicon photonic / co-packaged optics            |
| `accel`       | `compute/hexa-accel/`           | Generic hexa-accelerator IP framework            |
| `asic`        | `compute/hexa-asic/`            | Hexa-ASIC tape-out reference flow                |
| `hexa_pim`    | `compute/hexa-pim/`             | Hexa-PIM (n=6 organised PIM macros)              |
| `hexa_3d`     | `compute/hexa-3d/`              | Hexa-3D stacking convention                      |
| `hexa_wafer`  | `compute/hexa-wafer/`           | Hexa-wafer-level integration                     |

### Group F — consciousness (2)

| Verb              | Source (n6-arch)                  | Scope                                            |
|-------------------|-----------------------------------|--------------------------------------------------|
| `conscious_chip`  | `compute/consciousness-chip/`     | Consciousness-chip experimental axis             |
| `conscious_soc`   | `compute/consciousness-soc/`      | Consciousness-SoC integration spec               |

---

## Status

**v1.0.0 closure verdict: SPEC_FIRST.**

28-verb 통합 chip substrate (7 그룹: architecture + design + process +
packaging + accelerator + consciousness). Spec-first (per-verb working
`.hexa` CLI sandboxes TBD). 한국 반도체 산업 헤리티지(Samsung·SK·Hynix)
톤을 유지하되 어떤 proprietary 자료, NDA 콘텐츠, trade-secret 도 포함하지
않는다.

Working `cli/hexa-chip.hexa` is a placeholder dispatcher with three
subcommands:

- `hexa-chip status` — group + verb count table
- `hexa-chip show <verb>` — echo spec path for a single verb
- `hexa-chip selftest` — verify all 28 verb directories present

### Caveats (raw#10 honest C3)

1. **28/28 verbs are spec-only at v1.0.0.** Each verb is a directory
   tree extracted from `canon/domains/compute/<name>/` at
   SHA `c0f1f570`. Per-verb working `.hexa` CLI sandboxes (with
   simulators / falsifier preregisters / honesty audits) are deferred
   to post-v1.0 cycles.
2. **n=6 invariant lattice claim is partial.** Only `isa_n6` and
   `hexa1` are explicitly designed against the n=6 lattice
   (`σ(6)=12, τ(6)=4, φ(6)=2, J₂=24`); the other 26 verbs inherit
   the lattice as organising convention only — no independent
   empirical fit at this release.
3. **No tape-out / GDSII / PDK content vendored.** Foundry process
   kits stay proprietary; this repo ships specs + organising
   vocabulary only. EDA tools (Cadence/Synopsys/Mentor) remain the
   canonical implementation surface.
4. **Cross-link consumers (`hexa-rtsc` / `hexa-codex` / `anima`)** reference
   individual verb specs; bidirectional propagation is manual (no
   cross-repo CI).
5. **Korea-fab heritage tone is editorial framing.** Samsung / SK·Hynix /
   DRAM / HBM lineage is invoked for organising vocabulary only — no
   proprietary data, NDA content, or trade-secret material is included.

---

## Install

### Via `hx` (recommended)

```bash
hx install hexa-chip                          # global, pulls latest from registry
hx install /path/to/hexa-chip --as hexa-chip  # local checkout (symlink)
hexa-chip status                              # → 29-verb / 6-group table
```

### Via git clone (works today)

```bash
git clone https://github.com/need-singularity/hexa-chip.git ~/.hexa-chip
export HEXA_CHIP_ROOT=~/.hexa-chip
export PATH="$HEXA_CHIP_ROOT/cli:$PATH"

# Run any subcommand:
hexa run "$HEXA_CHIP_ROOT/cli/hexa-chip.hexa" status
hexa run "$HEXA_CHIP_ROOT/cli/hexa-chip.hexa" selftest
hexa run "$HEXA_CHIP_ROOT/cli/hexa-chip.hexa" show npu_n6
```

---

## Build & verify

A doc-first repo with a thin runnable surface — `verify/` + `tests/`
+ per-verb `verify_*.hexa` sandboxes — modeled after the
hexa-sscb pattern.

```bash
make verify        # 5 verify/*.hexa unified checks (n6 / inventory / cross-doc / release / falsifiers)
make verbs         # 29 per-verb sandboxes — verify_*.hexa under each verb dir
make tests         # 4 tests/test_*.hexa invariants
make selftest      # CLI dispatcher 29-verb sweep + sentinel
make ci            # all of the above
make list          # registered checks + tests
make install       # hx install symlink → /Users/ghost/.hx/bin/hexa-chip
```

### Last validation sweep — 2026-05-07

| Check | Result | Detail |
|---|---|---|
| `verify/cli.hexa` (5 checks) | ✅ 5/5 PASS | n6 master-identity / 29-verb inventory / cross-doc agreement / release cadence / falsifier register |
| `verify/verb_runner.hexa` (29 verbs) | ✅ 29/29 PASS | every verb dir has a runnable `verify_*.hexa`; 0 skipped |
| `tests/run_tests.hexa` (4 tests) | ✅ 4/4 PASS | `test_n6_lattice` / `test_29_verb_inventory` / `test_selftest` / `test_verify_runner` |
| `cli/hexa-chip.hexa selftest` | ✅ PASS | `__HEXA_CHIP_SELFTEST__ PASS` sentinel + 29/29 dirs |
| `hx install` | ✅ links + shim works | `~/.hx/bin/hexa-chip status` produces full 29-verb table |

Re-run the sweep after any verb-dir or doc edit. `make ci` exits
non-zero on first FAIL.

### Verify checks (5)

| Name | What it asserts | File |
|---|---|---|
| `n6` | σ(6)=12, τ(6)=4, φ(6)=2, σ·φ = n·τ = 24 | `verify/n6_arithmetic.hexa` |
| `inventory` | 29 verb dirs + 1 .md per verb + group totals | `verify/inventory_check.hexa` |
| `cross-doc` | hexa.toml + README + .roadmap + CLI agree on 29-verb / n=6 | `verify/cross_doc_audit.hexa` |
| `release` | §A.2 release cadence (v1.0→v2.0) + §A.4 falsifiers present | `verify/release_cadence.hexa` |
| `falsifiers` | F-CHIP-1..F-CHIP-4 register dump | `verify/falsifier_check.hexa` |

### Per-verb sandboxes (29)

Each verb directory carries a `verify_<verb>.hexa` (or `chip_<verb>.hexa`
for the ISA driver) sandbox. Each:

1. Asserts the n=6 lattice projection for the verb's domain
   (e.g. σ(6)=12 process nodes, τ(6)=4 EDA stages, J₂=24 layer ceiling).
2. Provides at least one falsifiable claim (`F-CHIP-<verb>-N`).
3. Exits 0 = invariant holds, 1 = drift detected.

Run all 29 with `make verbs` (or filter: `hexa run verify/verb_runner.hexa --group accelerator`).

### Caveats (raw#10 honest C3) — runnable surface scope

- The 29 sandboxes assert **lattice arithmetic and presence claims only** —
  none of them performs vendor-data-fit verification. The 4 falsifiers
  in `.roadmap §A.4` (Samsung 2nm/3nm fit, Exynos NPU stage count,
  HBM4 stack height, IIT Φ measurement) remain **bench-only**.
- `verify/cli.hexa` "all" runs in <2 s on a Mac — every check is a
  filesystem walk + arithmetic; no compute is invoked.
- See `UPSTREAM_NOTES.md` for hexa-lang issues encountered (and
  filed at `/Users/ghost/core/hexa-lang/issues/proposed/`).

---

## Cross-link

- **`need-singularity/hexa-rtsc`** — SC-chip dependency (this repo's
  `sc/` verb is the upstream substrate that hexa-rtsc consumes).
- **`need-singularity/hexa-codex`** — NPU / AI-chip ↔ AI substrate
  (this repo's `npu_n6/` + `accel/` + `pim/` verbs feed hexa-codex
  inference IP).
- **`need-singularity/anima`** — `conscious_chip/` + `conscious_soc/`
  ↔ anima's consciousness substrate; experimental axis with no
  empirical claim at v1.0.0.

Upstream SSOT: `canon/domains/compute/` (commit `c0f1f570`,
2026-05-06 extraction snapshot).

---

## License

MIT — see [LICENSE](LICENSE).

Copyright (c) 2026 need-singularity (박민우 <nerve011235@gmail.com>).
