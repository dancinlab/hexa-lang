# hexa-chip v1.0.0 — Chip Substrate (HEXA family) 🔲

**Release date**: 2026-05-06
**Closure verdict**: **SPEC_FIRST** (28/28 verbs land as spec directories
across 7 groups; per-verb working `.hexa` CLI sandboxes TBD)
**Provenance**: extracted 2026-05-06 from `canon/domains/compute/`
at SHA `c0f1f570`. Sister-extraction of `hexa-bio` (molecular toolkit, 4
verbs), `hexa-rtsc`, `hexa-codex`, and the wider `dancinlab` family
(`hexa-{antimatter, bot, brain, cosmos, earth, energy, fantasy, fusion,
lang, millennium, os, pet, space, sscb, time, ufo}`).

This is the **initial standalone release** of `hexa-chip`, the chip
substrate of the HEXA family — a 28-verb / 7-group semiconductor stack
extracted as one repository so downstream consumers (`hexa-rtsc`,
`hexa-codex`, `anima`) can pin chip-axis vocabulary without dragging the
full `canon` monorepo.

## Highlights

- **28-verb / 7-group decomposition** mirroring the Korean fab heritage
  stack (Samsung·SK·Hynix·DRAM/HBM lineage), organised top-down:
  architecture → design → process → packaging → accelerator →
  consciousness.
- **Spec-first** distribution. Each verb is a `cp -R`'d directory tree
  from `canon/domains/compute/<canonical-name>/`; per-verb
  working `.hexa` CLI sandboxes (with simulators, falsifier preregisters,
  honesty audits) are deferred to post-v1.0 cycles.
- **Placeholder CLI dispatcher** (`cli/hexa-chip.hexa`) — three
  subcommands (`status`, `show <verb>`, `selftest`) plus `--version` /
  `help`. Selftest verifies the 28-dir invariant and prints the
  `__HEXA_CHIP_SELFTEST__ PASS` sentinel.
- **MIT license** — pure permissive. No proprietary fab content, no
  NDA material, no trade-secret data.
- **GitHub-only distribution** — canonical at
  <https://github.com/dancinlab/hexa-chip>.

## Installation

```bash
# Recommended (post-hx install registration):
hx install hexa-chip@1.0.0
hexa-chip --version           # → 1.0.0

# Or git clone (works today):
git clone https://github.com/dancinlab/hexa-chip.git ~/.hexa-chip
export HEXA_CHIP_ROOT=~/.hexa-chip
export PATH="$HEXA_CHIP_ROOT/cli:$PATH"
hexa run "$HEXA_CHIP_ROOT/cli/hexa-chip.hexa" selftest
```

## Quickstart

```bash
hexa-chip status                   # 7-group + 28-verb table
hexa-chip selftest                 # verify all 28 verb dirs present
hexa-chip show npu_n6              # echo spec path for a single verb
hexa-chip show conscious_chip
ls $HEXA_CHIP_ROOT/architecture/   # browse verb spec directly
```

## 7-group / 28-verb breakdown

| Group           | # | Verbs                                                              |
|-----------------|--:|--------------------------------------------------------------------|
| architecture    | 3 | architecture · isa_n6 · hexa1                                      |
| design          | 5 | design · dse_pipeline · rtl_gen · eda · verify_test                |
| process         | 5 | process · materials · wafer · yield · thermal_power                |
| packaging       | 6 | packaging · advanced_packaging · chip_3d · hbm · interconnect · sc |
| accelerator     | 8 | npu_n6 · pim · photonic · accel · asic · hexa_pim · hexa_3d · hexa_wafer |
| consciousness   | 2 | conscious_chip · conscious_soc                                     |
| **total**       |**28**|                                                                |

## Honest C3 caveats (raw#10)

1. **0/28 verbs empirically wired.** All 28 verbs are spec-only
   directory trees at v1.0.0. The CLI dispatcher is a placeholder that
   lists groups, echoes spec paths, and verifies the 28-dir invariant —
   no per-verb simulator or audit runs.
2. **n=6 invariant lattice claim is partial.** Only `isa_n6` and
   `hexa1` are explicitly designed against the lattice; the other 26
   verbs inherit it as organising convention with no independent fit.
3. **No tape-out content.** Foundry PDKs / GDSII / mask sets stay
   proprietary; this repo ships specs only.
4. **Cross-link manual.** `hexa-rtsc` / `hexa-codex` / `anima` consumers
   reference verb specs by path; no cross-repo CI at this release.
5. **Korea-fab heritage tone is editorial framing.** No proprietary
   data, NDA content, or trade-secret material is included.

## Cross-link

- **`dancinlab/hexa-rtsc`** — depends on this repo's `sc/` verb
  (SC-chip substrate).
- **`dancinlab/hexa-codex`** — depends on this repo's `npu_n6/` +
  `accel/` + `pim/` verbs (NPU / AI-chip IP).
- **`dancinlab/anima`** — depends on this repo's `conscious_chip/`
  + `conscious_soc/` verbs (consciousness substrate).

## Provenance

- Extracted from `canon/domains/compute/` at SHA `c0f1f570`
  (commit `proposal(infra): reframe critical-mineral-arbitration kick-spec
  to peaceful-only scope`, 2026-05-06).
- Verb naming: `chip-<x>` / `advanced-<x>` / `hexa-<x>` / `consciousness-<x>`
  source dirs renamed to snake_case (`chip-architecture` → `architecture`,
  `chip-isa-n6` → `isa_n6`, `advanced-packaging` → `advanced_packaging`,
  `consciousness-chip` → `conscious_chip`, etc).
- Sister extractions: `hexa-bio` v1.1.0+ (molecular toolkit), `hexa-rtsc`,
  `hexa-codex`, `anima`, plus the wider `dancinlab` family.

## License

MIT — see [LICENSE](LICENSE).

Copyright (c) 2026 dancinlab (박민우 <nerve011235@gmail.com>).
