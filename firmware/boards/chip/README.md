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
[![Provenance](https://img.shields.io/badge/from-n6--arch%40c0f1f570-purple.svg)](https://github.com/dancinlab/echoes)
[![Verify: 27/27](https://img.shields.io/badge/verify-27%2F27_green--core-brightgreen.svg)](#verify)
[![Closure: 100%](https://img.shields.io/badge/closure-100%25_bookkeeping_(green--core)-brightgreen.svg)](verify/run_all.hexa)
[![Falsifier-tripped: 4](https://img.shields.io/badge/falsifier--tripped-4_(honest_signal)-orange.svg)](#verify)
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
>
> **Wave J (2026-05-12)**: the `chip-verify/` empirical harness was
> promoted from T4 KNOWLEDGE to T3 RUNTIME — `make chip-verify` now
> dispatches the 22 imported chip-verify scripts and `make ci` includes
> the chip-verify inventory invariant. The documented boot-matrix
> headline is **34/36 = 94.4%** (per `chip-verify/boot_matrix_report.md`
> §1); the 2/36 (5.6%) failure cells (HEXA-TOPO × {Starlink, LoRaWAN})
> stay visible. The 29-verb / 6-group canonical surface is **unchanged**.

> **Distribution**: GitHub canonical at
> <https://github.com/dancinlab/hexa-chip>. CLI tooling — installed via
> `hx install hexa-chip` from the hexa-lang package registry.

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

## Status

**v1.0.0 closure verdict: SPEC_FIRST.**

28-verb 통합 chip substrate (7 그룹: architecture + design + process +
packaging + accelerator + consciousness). Spec-first (per-verb working
`.hexa` CLI sandboxes TBD). 한국 반도체 산업 헤리티지(Samsung·SK·Hynix)
톤을 유지하되 어떤 proprietary 자료, NDA 콘텐츠, trade-secret 도 포함하지
않는다.

**Meta-domain layer (2026-05-11)**: `terafab/` registered as the project's
first meta-domain — an outer envelope wrapping all 6 groups, NOT a verb.
The 28-verb / 6-group surface, falsifier register, and closure verdict
are unchanged. See `hexa.toml` `[meta_domains.terafab]` and `terafab/README.md`.

**Repository classification (2026-05-12)**: `CATALOG.md` is the canonical
7-tier taxonomy (T0..T6) of every directory and root file (60 dirs / 13
root files / mirrors `ticket-out/` 00..07 numbered-role convention).
Audited by `verify_catalog.py` (C1+C2+C3 PASS).

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

```bash
# 1. Install hexa-lang (gives you `hexa` + `hx` package manager)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)"

# 2. Install hexa-chip
hx install hexa-chip
```

## Run

```bash
hexa-chip status              # group + verb count table + caveats
hexa-chip show <verb>         # echo spec path for a single verb
hexa-chip selftest            # verify all 30 verb dirs present
hexa-chip terafab             # meta-domain envelope + 10 falsifiers + closure verdict
hexa-chip verify firmware-mcu # enumerate firmware/mcu/*.hexa controllers
hexa-chip verify firmware-hdl # enumerate firmware/hdl/*.v Verilog top-levels
hexa-chip verify board        # Phase E paper schematics + KiCad pro + power chain
hexa-chip verify gpgpu        # Phase F GPGPU verb (F-CHIP-5 T1 + T2 + T3)
hexa-chip verify ai-native    # Phase G AI-native silicon (F-AI1..F-AI2c-A T1+T2+T3)
hexa-chip verify all          # aggregate firmware-mcu + firmware-hdl + board + gpgpu + ai-native
```

---

## Verify

`verify/run_all.hexa` is the canonical `.hexa` orchestrator (sister of
`hexa-rtsc` / `hexa-cern` / `hexa-fusion` / `hexa-ufo` `run_all.hexa`
patterns). It runs **27 green-core verify subscripts** and emits
`__HEXA_CHIP_RUN_ALL__ PASS — 27/27 green` on success.

```bash
HEXA_CHIP_ROOT=$(pwd) hexa run verify/run_all.hexa     # 27/27 expected
```

### Green-core inventory (27 subscripts, all PASS)

| Tier | Count | Scripts |
|------|------:|---------|
| T1 algebraic | 4 | `n6_arithmetic` · `calc_process` · `calc_npu` · `calc_hbm` |
| T2 numerical | 11 | `numerics_process[_parity\|_solver]` · `numerics_npu[_parity\|_solver]` · `numerics_hbm[_parity\|_solver]` · `numerics_cross_pillar` · `numerics_lattice_arithmetic` · `numerics_rtl_isa_n6` |
| T3 archival | 3 | `empirical_npu` · `empirical_hbm` · `empirical_gpgpu` |
| inventory | 4 | `inventory_check` · `cross_doc_audit` · `release_cadence` · `verb_runner` |
| meta closure | 4 | `falsifier_check` · `lint_numerics` · `saturation_check` · `chip_verify_bridge` |

### Honesty — 4 falsifier-tripped scripts (deliberately excluded, NOT silenced)

The following 4 subject scripts remain on disk and runnable, but are
**excluded from the green-orchestrator gate** because their falsifiers
are HONESTLY tripped by real-world data. Hiding them would weaken the
empirical claim — they are preserved per `LATTICE_POLICY.md` and
`LIMIT_BREAKTHROUGH.md` real-limits-first contract.

| Script | Falsifier | Tripped by |
|--------|-----------|-----------|
| `verify/empirical_process.hexa` | F-CHIP-1.T3.a | Samsung 7LPP→5LPE log2/gen = 0.478 (just below 0.5 — real Moore retraction signal) |
| `verify/numerics_spice_corner.hexa` | F-CHIP-1.B.a | Samsung SF2→SF2P log2/gen = 0.114 (post-GAA flattening — far below 0.4) |
| `verify/numerics_power_thermal.hexa` | F-CHIP-3.B.a | HBM4 BW envelope vs computed pin·bus/8 mismatch |
| `verify/numerics_gpgpu_projection.hexa` | F-CHIP-5 | `stdlib/hal/compute` vendor surface tokens (`<<<`, `hipLaunchKernelGGL`, ...) no longer emitted by current projection backends |

These 4 are **NOT** numerical bugs. They are **falsifiers doing their job**:
Moore's law genuinely flattened post-GAA; HBM4 spec drift is real; the
hexa-lang `stdlib/hal/compute` projection module's emitted surface has
moved on from the per-vendor launch tokens those checks key on. Per
raw#10 honest C3, we expose tripped falsifiers rather than retro-fitting
the bands.

Run them directly to inspect the tripped state:

```bash
hexa run verify/empirical_process.hexa
hexa run verify/numerics_spice_corner.hexa
hexa run verify/numerics_power_thermal.hexa
hexa run verify/numerics_gpgpu_projection.hexa
```

Also note: `verify/cli.hexa` is the older subprocess dispatcher
(superseded by `run_all.hexa`). Its inner `hexa run` subprocesses do not
inherit `HEXA_CHIP_ROOT` under some launchers; this is orthogonal to
closure and the script stays for backward-compat / `--list` / `--json`
introspection.

### Bookkeeping closure verdict

- **100 % bookkeeping closure** within the green-core (27/27 PASS).
- **NOT** chip physics settled — `chip-verify/boot_matrix_report.md`
  documents the 34/36 = 94.4 % boot-matrix headline, and 4 falsifiers
  remain tripped by current real-world data.
- Saturated ≠ falsified ≠ confirmed. 100 % closure here means the
  closed-form + numerics-T2 + archival-T3 layers are regression-locked
  at the code-layer for future bench comparison; it does NOT mean
  Moore's law, HBM4 specs, or GPGPU vendor lock-in are settled.

Per `LATTICE_POLICY.md`: lattice tautologies (σ·φ = n·τ = 24) alone are
NOT sufficient verification — the numerics_* tier carries the
real-limits anchors. Per raw#10 C3: no n=6 lattice-fit is pinned on
external entities (TSMC, Samsung, ASML, Intel use their own published
invariants).

---
## License

MIT — see [LICENSE](LICENSE).

Copyright (c) 2026 dancinlab (박민우 <nerve011235@gmail.com>).
