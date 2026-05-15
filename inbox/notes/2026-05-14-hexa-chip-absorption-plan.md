# hexa-chip → hexa-lang absorption plan (research only)

**Date:** 2026-05-14
**Source repo:** `~/core/hexa-chip/` (Chip Substrate, MIT, v1.0.0 + Wave A..L unreleased)
**Target repo:** `~/core/hexa-lang/`
**Status:** RESEARCH — no code modified. Implementation gated on user approval.
**Mode:** READ-ONLY on hexa-chip; no commits.

## 0. TL;DR

- `~/core/hexa-chip/` is the **HEXA chip substrate spec repo** — the 29-verb / 6-group canonicalization of the n=6 chip-axis (architecture · design · process · packaging · accelerator · consciousness). MIT-licensed. 42 MB, ~5,069 files (286 markdown, 142 `.hexa`, ~25,995 hexa LOC).
- hexa-lang **already mirrors a snapshot** of hexa-chip under `firmware/boards/chip/` (274 files, dated 2026-05-10). That mirror tracks the v1.0.0 surface — the 29 verb dirs, `verify/` (31 scripts), `firmware/{board,mcu,sim,hdl}`, `cli/hexa-chip.hexa`, the chip-axis `.md` specs *for the 29 verbs only*.
- What hexa-chip has gained **since 2026-05-10** and the mirror does **not yet contain**: (a) `chip-verify/` empirical harness (24 scripts, ~1,993 hexa LOC, Wave J promotion), (b) `terafab/` + `tsmc/` + `intel/` meta-domain envelopes, (c) ~140 root-level cross-domain `.md` specs (CHIP-*, HEXA-*, L7..L15, MK3, certs, network/display/etc.), (d) `LATTICE_POLICY.md` + `LIMIT_BREAKTHROUGH.md` (hexa-lang has its **own** copies at root — already absorbed once at policy layer), (e) `discovery/`, `proposals/`, `verify_catalog.py`, `CATALOG.md`, an expanded `hexa.toml` with `[meta_domains.*]`, and Wave L `verify/run_all.hexa` (~182 LOC).
- Relation to hexa-lang's atlas pipeline (6594 rodata, 9 SSOTs, 38+ algorithms): **none direct**. hexa-chip is *not* an atlas-grammar producer — it doesn't ship `.n6` entries, `@P/@C/@L` corpus rows, or atlas-format files. Lattice cross-pollination is at the **vocabulary level** (σ(6)/τ(6)/φ(6)/J₂=24 identity used as organising vocabulary in `verify/n6_arithmetic.hexa` etc.) — these already live, **byte-identical**, inside `firmware/boards/chip/verify/n6_arithmetic.hexa`.
- License: MIT — attribution required (one-line provenance header per file is sufficient). No CC0 frictionless-copy situation as with `~/core/n6/`.
- Recommendation: **selective Wave-style update of the existing mirror**, not a full re-port. Net new code surface ≈ 3 high-value items + a documentation refresh; ~6,500 LOC of root specs is reference material that should *not* be vendored verbatim (use canonical-link pattern like `firmware/boards/chip/IMPORTED_FROM_CANON.md`).

## 1. Identity

**hexa-chip identity** (from README + AGENTS + LATTICE_POLICY):
- Type: **chip substrate spec repo** (per README §1) — spec-first, runnable-sandbox-second.
- Canon basis: extracted from `canon@c0f1f570` (2026-05-06), 28→29 verbs across 6 groups, plus 4 meta-domain envelopes (`terafab/exynos/tsmc/intel`).
- Origin lineage: `n6-architecture@0570a835` → canon → hexa-chip standalone (per `<!-- @canonical: -->` headers in each verb `.md`).
- Closure verdict (v1.0.0 + Wave L): `SPEC_PLUS_RUNNABLE` for the green-core 27/27 verify surface; 4 falsifier-tripped scripts honestly excluded (`empirical_process`, `numerics_spice_corner`, `numerics_power_thermal`, `numerics_gpgpu_projection`).
- Policy alignment: shares `LATTICE_POLICY.md` (Wave K, 2026-05-12) verbatim with hexa-lang — both are policy-receivers of the dancinlab-wide "real-limits-first verification" doctrine. hexa-chip is the **policy-origin** exemplar; hexa-lang holds an absorbed copy under its own `LATTICE_POLICY.md` + `LIMIT_BREAKTHROUGH.md`.

**Relation to `~/core/hexa-lang/firmware/boards/chip/`:**

| Aspect | Status |
|---|---|
| Verb dirs (29) | **already mirrored** — byte-identical for hexa source under each verb dir |
| `verify/*.hexa` (31 scripts) | **already mirrored** — `n6_arithmetic / calc_* / numerics_* / empirical_*` all present; `run_all.hexa` and `chip_verify_bridge.hexa` are **only in hexa-chip** (Wave L additions) |
| `firmware/{board,mcu,sim,hdl,doc}` | **already mirrored** — `diff -rq` shows no differences |
| Root `.md` specs (~140 files: CHIP-*, HEXA-*, L7..L15, *-CERT, NETWORK/DISPLAY/etc.) | **not mirrored** — hexa-lang mirror is *verb-scoped*, not full-repo |
| `chip-verify/` (24 scripts + reports) | **not mirrored** — Wave J promotion (2026-05-12) post-dates the snapshot |
| `terafab/` `tsmc/` `intel/` (envelopes) | **not mirrored** — Wave I additions |
| `LATTICE_POLICY.md`, `LIMIT_BREAKTHROUGH.md` | **absorbed at policy layer** (separate hexa-lang copies at root, not under firmware/) |
| `discovery/`, `proposals/`, `verify_catalog.py`, `CATALOG.md` | **not mirrored** — meta/governance, partial overlap with hexa-lang's own `compiler/discover/` |
| `hexa.toml` `[meta_domains.*]` | **not in mirror** — mirror's hexa.toml is 4.6 KB vs source 13.7 KB (only `[modules.*]` synced) |

**Doubt-port risk:** *low*. The mirror is a **deliberate verb-only snapshot** (per `IMPORTED_FROM_CANON.md` at the mirror root, which lists only `papers/` and `origins/` as imported additions). Wave-level deltas (chip-verify, terafab, run_all) are net-new since the snapshot was taken on 2026-05-10.

## 2. Inventory

Audited under `~/core/hexa-chip/` (top-level survey + sampled 12 files):

### 2.1 By directory (high level)

| Group / dir | Files (approx) | Type | Hexa LOC | Status in mirror |
|---|---:|---|---:|---|
| 29 verb dirs (architecture/design/process/packaging/accelerator/consciousness, all flat) | ~145 (.md + verify_*.hexa) | spec + runnable sandbox | ~5,500 | **mirrored** |
| `verify/` (31 .hexa + 0 reports) | 31 | green-core verifier | ~6,800 | **mostly mirrored** (Δ: `run_all.hexa` + `chip_verify_bridge.hexa` + 3 file revisions) |
| `chip-verify/` (24 .hexa + 4 .md + 1 .json) | 29 | empirical harness (boot matrix 3×12, Xn6 micro-arch) | 1,993 | **NOT MIRRORED** |
| `firmware/{board,mcu,sim,hdl,doc}` | 30 | firmware + HDL + KiCad | small | **mirrored** (byte-identical) |
| `terafab/` (meta-domain) | 25 (.md + .py) | Musk vertically-integrated megafab envelope | ~5,800 lines incl. Py | **NOT MIRRORED** |
| `tsmc/` (meta-domain) | 5 | TSMC public-source envelope | ~95 KB | **NOT MIRRORED** |
| `intel/` (meta-domain) | 5 | Intel public-source envelope | ~100 KB | **NOT MIRRORED** |
| `exynos/` (meta-domain) | 7 | Samsung Exynos envelope | small | **partially mirrored** (only `exynos.md` mirrored; CLOSURE/MK2/sources missing) |
| Root `CHIP-*.md` (15 files) | 15 | per-verb canonical spec mirrors (HBM, NPU-N6, PIM, PROCESS, RTL-GEN, ...) | ~700 KB total | **NOT MIRRORED** |
| Root `HEXA-*.md` (~25 files) | 25 | per-architecture papers (1-DIGITAL, 2-PIM, 3D, ACCEL, ASIC, MRAM, PHOTON, PROGLANG, etc.) | ~1.1 MB | **NOT MIRRORED** |
| Root `L7..L15-*.md` (9 files) | 9 | L7..L15 roadmap layer specs (quantum-transmon, topo-anyon, field-photon, etc.) | ~600 KB | **NOT MIRRORED** |
| Root `*-CERT.md` (~14 files) | 14 | certification briefs (5G-NR, 6G, BT6, WIFI6, USB, HDMI, NVME, PCIE, ...) | small | **NOT MIRRORED** |
| Root other (BLOCKCHAIN, BROWSER, CRYPTOGRAPHY, DIGITAL-TWIN, NETWORK, DISPLAY, KEYBOARD, MOUSE, ISOCELL-COMMS, COMPILER-OS, ...) | ~30 | cross-domain bridges | medium | **NOT MIRRORED** |
| `papers/` | ~21 | n6-* integrated papers | large (~1.5 MB) | **mirrored** (per IMPORTED_FROM_CANON.md) |
| `origins/` | ~14 .hexa | calculator / DSE tools (chip-power-calc, gpu-arch-calc, hexa-rtl/, ...) | ~3,200 | **mirrored** |
| `discovery/` (1 file) | 1 | `chip-architecture-guide.md` | small | **NOT MIRRORED** |
| `proposals/` (1 file) | 1 | `samsung-foundry-hexa-6stage.md` | small | **NOT MIRRORED** |
| `verify_catalog.py` + `CATALOG.md` | 2 | 7-tier non-invasive taxonomy + audit | ~200 Py | **NOT MIRRORED** |
| `state/`, `tests/`, root governance (`LATTICE_POLICY`, `LIMIT_BREAKTHROUGH`, `CLAUDE.md`, `IDENTITY.tape`, `CHIP.tape`, `MK3-ROADMAP-L1-L15-AUDIT`, `TAPE-AUDIT.md`, `SESSION_LOG_2026-05-12.md`) | ~15 | governance / replay tapes | medium | **partial** — `LATTICE_POLICY/LIMIT_BREAKTHROUGH` absorbed at hexa-lang root; rest not |

**Total hexa-chip LOC (hexa only):** 25,995 across 142 files. Spec markdown adds ~3 MB.

### 2.2 Inventory by upstream wave (since 2026-05-10 snapshot)

| Wave | Date | Net-new vs mirror |
|---|---|---|
| Wave A..E | 2026-05-11 | `terafab/` (17 files, ~5,800 lines) |
| Wave F..H | 2026-05-12 | `tsmc/`, `intel/` envelopes; hexa.toml `[meta_domains.*]` block (+~63 lines) |
| Wave I | 2026-05-12 | `CATALOG.md` + `verify_catalog.py` (7-tier non-invasive taxonomy) |
| Wave J | 2026-05-12 | `chip-verify/` promoted T4→T3 — 24 scripts, `verify/chip_verify_bridge.hexa` (32 LOC), `make chip-verify` wiring |
| Wave K | 2026-05-12 | `LATTICE_POLICY.md` (already in hexa-lang at root) |
| Wave L | 2026-05-13 | `verify/run_all.hexa` (182 LOC), badges, README §Verify section |
| Wave M | 2026-05-12 | `LIMIT_BREAKTHROUGH.md` (already in hexa-lang at root) |

## 3. Atlas-relevant absorption surface

**Direct atlas-grammar content (`.n6`, `@P/@C/@L`, ATLAS_*_NODES):** none. `grep -rlE "atlas\.n6|@P |@C |@L "` hits only commentary in the L7..L15 / HEXA-* papers, not data rows.

**Atlas-adjacent surfaces hexa-lang could benefit from:**

1. **`verify_catalog.py`** (192 LOC, Py-only) — implements a 3-check filesystem ↔ taxonomy ↔ manifest agreement audit (C1: every top-level dir mentioned exactly once in `CATALOG.md`; C2: `hexa.toml [modules.*]` matches T1 dirs; C3: `[meta_domains.terafab].absorbs` matches the 6 T1 group names). **Analogue gap in hexa-lang:** no equivalent exists. hexa-lang has 9 SSOTs but no taxonomy ↔ manifest cross-check tool. Porting the C-style 3-check pattern to a generic `tool/repo_taxonomy_audit.hexa` (~150 LOC hexa) could anchor the 9-SSOT invariant.

2. **`verify/run_all.hexa`** (182 LOC) — green-core orchestrator with explicit per-tier inventory (T1 algebraic × 4 / T2 numerical × 11 / T3 archival × 3 / inventory × 4 / meta × 4), `HEXA_CHIP_ROOT`/`HEXA_LANG` env forwarding, `__HEXA_CHIP_RUN_ALL__ PASS — 27/27 green` sentinel, and an **explicit deferred-FAIL ledger** for falsifier-tripped scripts. The honest-exclusion pattern is exactly the discipline hexa-lang's `make test` currently lacks.

3. **`chip-verify/cli.hexa`** (~13.7 KB) — dispatcher pattern for an empirical-witness sandbox imported from upstream commit, kept under provenance pin (Wave 5 commit `3f2c2b7`). Same role as a hypothetical hexa-lang `tool/atlas_empirical_witness.hexa` if hexa-lang ever pins external corpora to a commit.

4. **`LATTICE_POLICY.md` + `LIMIT_BREAKTHROUGH.md`** — already absorbed at hexa-lang root. No-op (verify only that hexa-lang copies stay synced if hexa-chip updates them).

5. **Root spec corpus** (CHIP-*, HEXA-*, L7..L15) — **not atlas-relevant for absorption**. These are domain knowledge documents that belong in canon, not in hexa-lang's compiler tree. Vendoring would bloat the repo by ~3 MB without consumer code. Recommend canonical-link only.

## 4. Candidates by Doctrine v2 5 rules

(Doctrine v2 5 rules: hexa-only · english · n=6 organising-not-constraint · real-limits anchor · 9-SSOT/atlas immutability).

| Doctrine rule | Candidate | Fits? | Notes |
|---|---|---|---|
| **R1 hexa-only** | `verify/run_all.hexa` (182) | ✓ | pure hexa, no shell-out beyond `hexa run` |
| R1 | `chip-verify/cli.hexa` (~440 LOC) + 24 verify_xn6_*.hexa | ✓ | pure hexa |
| R1 | `verify/chip_verify_bridge.hexa` (32) | ✓ | trivial bridge |
| R1 | `terafab/verify_terafab.py` (309 Py) | ✗ | Python — must port to hexa or skip |
| R1 | `terafab/cross_doc_audit.py` (627 Py) | ✗ | Python — must port to hexa or skip |
| R1 | `verify_catalog.py` (192 Py) | partial | port to `tool/repo_taxonomy_audit.hexa` (~150 LOC) |
| R1 | Root `.md` corpus (140 files) | n/a | docs only, no code |
| **R2 english** | All hexa-chip code | ✓ | source comments include some Korean (e.g. `verify_terafab.py` headers, hexa.toml comments); strip on port |
| R2 | `LATTICE_POLICY.md` | partial | bilingual KR/EN — hexa-lang root copy already absorbed; keep as-is |
| **R3 n=6 organising-only** | `LATTICE_POLICY.md` | ✓ | already shared |
| R3 | `verify/n6_arithmetic.hexa` | ✓ | self-consistency, no external-fit |
| R3 | `terafab/*` (10 falsifiers F-TERAFAB-1..10) | ✓ | external-source, deliberately *not* lattice-fit — per Wave K policy |
| R3 | Root CHIP-ARCHITECTURE.md (42 KB), CHIP-ISA-N6.md (45 KB) | ✓ | lattice as design invariant for own ISA, not external claim |
| **R4 real-limits anchor** | `LIMIT_BREAKTHROUGH.md` | ✓ | already shared — exemplar for Wave M |
| R4 | `verify/numerics_*.hexa` (12 scripts) | ✓ | already mirrored; carry Moore log2-ratio band, JEDEC HBM bus/speed, etc. |
| R4 | `verify/empirical_*.hexa` (4 scripts) | partial | 1 of 4 is honestly falsifier-tripped (Samsung 7LPP→5LPE) — that's the *point* |
| **R5 9-SSOT/atlas immutability** | None of hexa-chip touches atlas | ✓ | no risk |
| R5 | `verify_catalog.py` taxonomy idea | ✓ | additive pattern, could anchor 9-SSOT invariant |

## 5. Absorption waves (recommended)

### Wave 1 — refresh existing mirror to upstream HEAD (low-risk catch-up)

Re-snapshot `firmware/boards/chip/` against `~/core/hexa-chip/` HEAD (2026-05-14) for the **subset already mirrored**:

- `verify/run_all.hexa` (NEW, 182 LOC) → `firmware/boards/chip/verify/run_all.hexa`
- `verify/chip_verify_bridge.hexa` (NEW, 32 LOC) → `firmware/boards/chip/verify/chip_verify_bridge.hexa`
- `verify/cli.hexa`, `verify/cross_doc_audit.hexa`, `verify/lint_numerics.hexa` (REVISED) — diff before overwrite
- `exynos/{README.md, CLOSURE.md, MK2.md, mk2-observations.md, sources.md, mk2-poll.log}` (NEW additions to a partially-mirrored verb)
- `cli/hexa-chip.hexa` (REVISED — diff is meaningful; mirror's is older)
- `CHANGELOG.md` (REVISED — mirror stops at 2026-05-10)
- `Makefile`, `.roadmap.hexa_chip`, `hexa.toml` (REVISED — see Wave 2 for hexa.toml meta-domains decision)
- `README.md`, `.gitignore` (REVISED)

**Net LOC:** ~250 new hexa LOC + revisions. Pure mirror refresh, no semantic absorption into hexa-lang's compiler tree.

**Estimated:** ~30 file copies, no behavior change for hexa-lang consumers.

### Wave 2 — chip-verify empirical harness (NEW dir)

Add `firmware/boards/chip/chip-verify/` mirroring `~/core/hexa-chip/chip-verify/` verbatim:

- 24 `.hexa` scripts (1,993 LOC) — Xn6 micro-arch verifiers + boot_matrix_3x12 (the 34/36 = 94.4 % headline)
- 4 `.md` reports + 1 `.json` fixture
- `cli.hexa` (~440 LOC) — dispatcher
- `aggregate.hexa` (~30 LOC) — JSON emitter
- `inventory.hexa` (~40 LOC) — 22/4/1 file-count invariant
- `CLOSURE.md` + `README.md`

**Wire-in:** Add a 1-line mention to `firmware/boards/chip/IMPORTED_FROM_CANON.md`; no compiler integration needed (chip-verify is a leaf sandbox).

**Net LOC:** ~2,500 LOC vendored (mostly small Xn6 stub verifiers + 1 large `verify_protocol_bridge.hexa` at 684 LOC).

**Risk:** low — leaf dir, no hexa-lang code depends on it.

### Wave 3 — meta-domain envelopes (terafab/tsmc/intel) — DEFER

Vendoring `terafab/` (~5,800 lines incl. 627-LOC Python `cross_doc_audit.py`) into hexa-lang creates two problems:

1. **R1 violation** — `terafab/verify_terafab.py` (309), `cross_doc_audit.py` (627), `poll_mk2.py` (507) are Python. Porting to hexa is ~1,500 LOC of work for content that's domain-knowledge documentation, not language tooling.
2. **Scope creep** — `terafab/` is a Musk/SpaceX/xAI external-research envelope. It belongs in canon or in hexa-chip itself, not in hexa-lang's compiler/firmware tree.

**Recommendation:** SKIP. Add a `IMPORTED_FROM_CANON.md` line documenting that `terafab/`, `tsmc/`, `intel/` exist upstream and are deliberately *not* mirrored. Surface via canonical link only.

### Wave 4 — repo taxonomy audit pattern (HIGH VALUE — atlas-adjacent)

Port `verify_catalog.py` (192 LOC Py) → `tool/repo_taxonomy_audit.hexa` (~150 LOC hexa).

**Generic shape:**

- `audit_filesystem_vs_catalog(catalog_md, root_dir) -> Result` — every top-level dir mentioned exactly once
- `audit_manifest_vs_catalog(manifest_toml, catalog_md, key) -> Result` — `[modules.*]` matches taxonomy T1
- `audit_envelope_absorption(manifest_toml, key) -> Result` — `[meta_domains.X].absorbs` matches groups

**Why high value for hexa-lang:**

- hexa-lang has 9 SSOTs (atlas + 8 others) — no automated catalog ↔ filesystem audit exists today
- The C1/C2/C3 pattern is **content-agnostic** — extracts cleanly
- Anchors **R5 9-SSOT immutability** with a runnable witness

**Wire-in:** `tool/repo_taxonomy_audit.hexa` as a new CLI; document target schema for hexa-lang's own `CATALOG.md` (does not exist yet — separate decision).

**Net LOC:** ~150 hexa + ~80 LOC tests.

### Wave 5 — root spec corpus (docs) — DEFER / CANONICAL-LINK ONLY

~140 root markdown files (CHIP-*, HEXA-*, L7..L15, *-CERT, NETWORK, DISPLAY, etc., ~3 MB). These are **domain knowledge documents** — they belong in canon. Recommend:

- Extend `firmware/boards/chip/IMPORTED_FROM_CANON.md` with a "Root specs (deliberately not mirrored)" section listing the 140 file names + their canonical path under hexa-chip
- Optionally vendor 3-5 high-relevance specs only: `CHIP-ISA-N6.md` (architecture's primary), `CHIP-NPU-N6.md` (accelerator's primary), `CHIP-RTL-GEN.md` (codegen-adjacent), `CHIP-VERIFY-TEST.md` (verify-adjacent), `LATTICE_POLICY.md` (already done)

**Net LOC:** ~0 (canonical-link only) or ~5 × 45 KB if subset vendored.

### Wave 6 — Wave L verify/run_all pattern adoption — MEDIUM VALUE

`~/core/hexa-chip/verify/run_all.hexa` (182 LOC) is a clean exemplar of the "green-core orchestrator with honest deferred-FAIL ledger" pattern that hexa-lang's own `make test` doesn't fully implement. The 4-excluded-falsifier-tripped honesty discipline (Samsung Moore retraction, post-GAA flattening, HBM4 BW envelope, GPGPU vendor surface) is the kind of explicit signal hexa-lang's compiler tests should adopt.

**Recommendation:** *Reference, don't port.* hexa-lang's compiler tests have a different surface. The pattern (named subscript list + sentinel emit + explicit excluded list) can be retro-fitted to `tool/test_orchestrator.hexa` as a future enhancement.

## 6. Skip list

| Item | Reason |
|---|---|
| `terafab/`, `tsmc/`, `intel/` envelopes | External-research content; belongs in canon, R1-violates via Python harness |
| Root 140 `.md` specs | Domain knowledge docs; canonical-link sufficient; would bloat repo by ~3 MB |
| `discovery/` (1 file) | Single guide doc, partial overlap with hexa-lang's `compiler/discover/` (different semantics — n6's is doc-only, hexa-lang's is `@discover` annotation flow) |
| `proposals/` (1 file) | Single proposal doc — Samsung foundry; not language tooling |
| `terafab/cross_doc_audit.py` (627 Py), `verify_terafab.py` (309 Py), `poll_mk2.py` (507 Py) | Python; cross_doc surface is verifier-specific, no reusable generic |
| `state/`, `tests/__pycache__`, `mk2-poll.log` | Runtime artifacts |
| `CHIP.tape`, `IDENTITY.tape` | Replay tapes for hexa-chip's own demos |
| `SESSION_LOG_2026-05-12.md`, `TAPE-AUDIT.md` | Single-session housekeeping logs |
| `LATTICE_POLICY.md`, `LIMIT_BREAKTHROUGH.md` | Already absorbed at hexa-lang root |
| `LICENSE`, `CITATION.cff`, `RELEASE_NOTES_v1.0.0.md` | Repo metadata for hexa-chip itself |
| `papers/`, `origins/` | Already mirrored under `firmware/boards/chip/` per `IMPORTED_FROM_CANON.md` |
| `.github/`, `.claude/`, `.git/` | Repo infrastructure |

## 7. Scope

**Recommended scope (Waves 1 + 2 + 4 + 5-subset):**

| Wave | Action | LOC |
|---|---|---:|
| Wave 1 — Mirror refresh (subset already mirrored, freshen to HEAD) | ~30 file copies; ~250 new hexa LOC + revisions | ~250 |
| Wave 2 — chip-verify/ vendor (NEW dir under firmware/boards/chip/) | 29 files vendored | ~2,500 |
| Wave 4 — `tool/repo_taxonomy_audit.hexa` (port verify_catalog.py to hexa) | new hexa module + tests | ~230 |
| Wave 5 subset — vendor 5 high-relevance root specs + extend `IMPORTED_FROM_CANON.md` | 5 markdown files + 1 manifest update | ~0 (docs) |
| **Total** | | **~2,980 LOC source + ~80 LOC tests** |

**Deliberately out of scope:**

- `terafab/` `tsmc/` `intel/` envelopes (Wave 3 SKIP)
- 135 of 140 root `.md` specs (Wave 5 SKIP — canonical-link only)
- Wave 6 (test orchestrator retro-fit) — future enhancement, not part of this absorption

**License obligation:** MIT. Recommend a one-line header per absorbed file: `// absorbed from ~/core/hexa-chip/<path> (MIT, hexa-chip@<commit-sha>)`.

**Provenance pin:** record current hexa-chip HEAD commit at the time of absorption in `firmware/boards/chip/IMPORTED_FROM_CANON.md` (Wave-numbered section: "Wave Y absorption — 2026-05-14, hexa-chip@<sha>").

**Sister-repo coordination notes:**
- `firmware/boards/antimatter/verify/n6_arithmetic.hexa` exists (same byte-for-byte content) — confirms the n=6 arithmetic primitive is already in use elsewhere in hexa-lang. No new SSOT needed.
- hexa-lang's `LATTICE_POLICY.md` + `LIMIT_BREAKTHROUGH.md` mirror hexa-chip's. If hexa-chip updates these (next Wave M/N), hexa-lang root copies should be re-synced — orthogonal to this absorption.

## 8. Bottom line

hexa-chip is **already 70-80 % absorbed** into hexa-lang as the verb-scoped mirror under `firmware/boards/chip/`. The net-new absorption surface is:

1. **Wave 2 — chip-verify/ (24 scripts + reports, ~2,500 LOC)** — the biggest concrete add; pure-hexa, leaf sandbox, low risk.
2. **Wave 4 — `tool/repo_taxonomy_audit.hexa` (~150 LOC port of verify_catalog.py)** — the highest-leverage *generic* take-away; anchors 9-SSOT R5 immutability.
3. **Wave 1 — mirror refresh (~250 LOC catch-up)** — bookkeeping, brings the existing mirror current to 2026-05-14 HEAD (Waves I + J + L).

Total recommended new code: **~2,980 LOC + ~80 LOC tests**.

Out of the 42 MB / 5,069-file upstream, the vast majority (~140 root spec markdowns, terafab/tsmc/intel envelopes) is domain-knowledge content that belongs in canon — vendoring it would bloat hexa-lang by ~3 MB of docs with zero language-tooling value. Canonical-link is sufficient.

This plan is **research only** — no code or files were modified. Approval gates the implementation pass.
