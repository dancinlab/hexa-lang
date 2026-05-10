# Origin & lineage

This repository was extracted from the **canon** monorepo on
**2026-05-06** (SHA `c0f1f570`). This document records the exact upstream
paths each file was pulled from, so that any change in this repo can be
traced back to (or propagated upstream to) the source-of-truth.

> **2026-05-07 (post-pattern-alignment)**: structural pattern aligned to
> `hexa-sscb` mk2 own_v1 — `.own` + `README.ai.md` + `verify/` +
> `doc/lineage/` landing. v1.0.0 directory layout (`rtsc/` + `sc/` flat)
> preserved for additive compatibility; v1.1.0 will move `rtsc/` →
> `core/rtsc/` + `module/applications/` per the sscb pattern.

## Upstream

- Repo: `canon` (local working copy at `~/core/canon`)
- Branch: `main`
- Extraction date: 2026-05-06
- Extraction SHA: `c0f1f570`
- Extractor: sister-of-substrates extraction following the `hexa-bio`
  v1.0.0 template (`dancinlab/hexa-bio` 2026-05-04).

## File-by-file provenance

| This repo | Upstream path | Notes |
|---|---|---|
| `rtsc/room-temp-sc.md` | `domains/energy/room-temp-sc/room-temp-sc.md` | RT-SC spec — n=6 closed-form candidate (Tc=300K, σ·τ=48T, Cooper φ=2). |
| `rtsc/agi-architecture-verify.hexa` | `domains/energy/room-temp-sc/agi-architecture-verify.py` | STUB — Python original, .hexa port pending nexus verify --hexa cycle. |
| `rtsc/helium-free-mri-verify.hexa` | `domains/energy/room-temp-sc/helium-free-mri-verify.py` | STUB — Python original. |
| `rtsc/lossless-power-grid-verify.hexa` | `domains/energy/room-temp-sc/lossless-power-grid-verify.py` | STUB. |
| `rtsc/rt-ev-motor-verify.hexa` | `domains/energy/room-temp-sc/rt-ev-motor-verify.py` | STUB. |
| `rtsc/rt-maglev-transport-verify.hexa` | `domains/energy/room-temp-sc/rt-maglev-transport-verify.py` | STUB. |
| `rtsc/rt-quantum-computer-verify.hexa` | `domains/energy/room-temp-sc/rt-quantum-computer-verify.py` | STUB. |
| `rtsc/rt-smes-verify.hexa` | `domains/energy/room-temp-sc/rt-smes-verify.py` | STUB. |
| `rtsc/space-colonization-verify.hexa` | `domains/energy/room-temp-sc/space-colonization-verify.py` | STUB. |
| `rtsc/superconducting-cpu-verify.hexa` | `domains/energy/room-temp-sc/superconducting-cpu-verify.py` | STUB. |
| `rtsc/tabletop-fusion-verify.hexa` | `domains/energy/room-temp-sc/tabletop-fusion-verify.py` | STUB. |
| `rtsc/arxiv-metadata.json` | `domains/energy/room-temp-sc/arxiv-metadata.json` | Submission metadata stub. |
| `rtsc/osf-metadata.json` | `domains/energy/room-temp-sc/osf-metadata.json` | OSF preregister metadata stub. |
| `sc/superconductor.md` | `domains/energy/superconductor/superconductor.md` | SC spec — BCS / Abrikosov n=6 projection. |
| `cli/hexa-rtsc.hexa` | _created fresh_ during extraction (2026-05-06) | Placeholder router; v1.0.x improvements add `verify` + `lattice` subcommands. |
| `tests/test_selftest.hexa` | _created fresh_ during extraction (2026-05-06) | Sentinel test harness. |
| `install.hexa` | _created fresh_ during extraction (2026-05-06) | Mirrors `hexa-bio/install.hexa` pattern. |
| `hexa.toml` | _created fresh_ during extraction (2026-05-06) | Package manifest for `hx install hexa-rtsc`. |
| `.roadmap.hexa_rtsc` | _created fresh_ during extraction (2026-05-06) | Cross-cutting tracker — invariant lattice + release cadence + falsifier preregister. |
| `.own` | _created fresh_ 2026-05-07 | Project-local SSOT (mk2 own_v1). Pattern-aligned to hexa-sscb. |
| `README.ai.md` | _created fresh_ 2026-05-07 | AI-native handoff (raw 271 mandate). |
| `doc/lineage/origin.md` | _created fresh_ 2026-05-07 | This file. |
| `verify/*.hexa` | _created fresh_ 2026-05-07 | Runnable invariant audit landing. |

## Sister-of-substrates extraction template

The extraction template was inherited from sibling `hexa-bio` v1.0.0
(2026-05-04, `dancinlab/hexa-bio`):

| Sibling | Axis | Extracted | Verbs |
|---|---|---|---|
| `hexa-bio` | molecular toolkit | 2026-05-04 | 6/6 wired |
| `hexa-rtsc` | energy / superconductor | 2026-05-06 | 0/2 wired (SPEC_ONLY) |
| `hexa-sscb` | compute / DC breaker | 2026-05-06 | n/a — doc-first repo |

`hexa-sscb` is the structural pattern reference (own_v1 schema +
`core/<feature>/` + `module/<feature>/` + `verify/` + `tests/` + `build/`
+ `doc/lineage/` triplet). hexa-rtsc adopts the additive subset on
2026-05-07 (`.own` + `README.ai.md` + `verify/` + `doc/lineage/`); the
`core/<feature>/` + `module/<feature>/` directory split is reserved for
v1.1.0.

## Re-derivation policy

If you change a file in `rtsc/` or `sc/` here and want to push it upstream:

1. Reproduce the change in `canon/domains/energy/{room-temp-sc,superconductor}/`.
2. If the change touches the n=6 lattice (σ/τ/φ/Hc2), also update
   `.roadmap.hexa_rtsc` §A.1 and re-run `verify/lattice_check.hexa`.
3. If the change touches a falsifier (F-RTSC-{1,2,3} or F-SC-{1,2,3}),
   also update `.roadmap.hexa_rtsc` §A.4 and `.own` own 2 decl rows
   simultaneously — never split.

## Empirical SSOT — UNPROVEN

Per `.own` own 2 (`hexa-rtsc-empirical-unproven-contractual`): RT-SC is
academically **unproven** as of 2026-05. LK-99 (2023) and subsequent
room-temp candidates have not been independently replicated. This
repository ships a **closed-form candidate spec + falsifier preregister**,
not an empirical claim of working RT-SC. Synthesis-side validation is
out-of-repo (would require materials lab).

If you change `cli/hexa-rtsc.hexa` to remove the "sentinel only — does
NOT validate empirical claim" caveat from any verb output: **stop** —
that's a raw 91 honest C3 violation and a direct own 2 breach.
