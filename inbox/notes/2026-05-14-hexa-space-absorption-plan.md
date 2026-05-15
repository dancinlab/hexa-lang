# hexa-space → hexa-lang absorption plan (research only)

**Date:** 2026-05-14
**Source repo:** `~/core/hexa-space/` (Space Toolkit v1.0.0/v1.1.0-pre, MIT, ~6.5 MB)
**Target repo:** `~/core/hexa-lang/`
**Status:** RESEARCH — no code modified. Implementation gated on user approval.
**Precedent template:** `inbox/notes/2026-05-13-n6-absorption-plan.md`

## 0. TL;DR

- `hexa-space` is the **standalone Space Toolkit** under the HEXA family — a spec-first single-source-of-truth substrate covering 27 verbs across 5 groups (core·engineering·observation·life·operations) anchored on the same n=6 invariant lattice (σ=12, τ=4, φ=2, J₂=24) that hexa-lang already uses for atlas grade indexing.
- The repo is **47 `.hexa` files / 5,105 LOC of hexa source** + 12 large `.md` domain specs + 4 Verilog HDL skeletons + 4 KiCad procurement bundles + 19 root markdown docs. RSC saturated 2026-05-08; 4/4 falsifiers at 67% closure (T1 algebraic + T2 numerical ✓; T3 hardware funding-gated).
- License: **MIT** — friction-light verbatim port permitted with attribution header.
- The **highest-value absorption surface is the RSC verifier toolkit** under `verify/` — 12 cross-cutter scripts (lattice/lint/falsifier/saturation/numerics_*) that codify a reusable "Runnable Surface Closure" recipe. hexa-lang's `compiler/falsifiers/` and `compiler/atlas/audit.hexa` cover adjacent terrain but **none of the saturation-loop bookkeeping** (sat-1 ∧ sat-2 closure-pct tracking, T1+T2+T3 ladder per falsifier, on-disk numerics-script inventory invariants).
- The **27 domain pillar specs** (`AEROSPACE.md` 5361 LOC, `SPACE-ENGINEERING.md` 2796 LOC, `HEXA-STARSHIP.md` 1263 LOC, etc.) and `aerospace_transport/spacex_intel_2026.md` are tech-data SSOT candidates per Doctrine v2 Rule 1, but they target a **different axis from atlas** (space-domain entity registry vs primitive/constant/law/edge corpus). Direct absorption into atlas rodata is **not the right shape**; consider a separate `compiler/space_registry/` SSOT if a port is ever scoped.
- The **firmware/ tree (Phase C/D/E)** is hexa-space-specific (Stage-1 controller designs targeting STM32H7 / Zynq US+ / Kintex US). It is a **closure path for the F-SPACE-* falsifier ladder**, not a hexa-lang concern. Skip in entirety.
- Recommended scope: absorb the **RSC verifier recipe** (Wave 1) as `tool/rsc/` reusable substrate + adapt the **falsifier closure-progress tracker** as a `tool/falsifier_audit.hexa` for hexa-lang's own falsifier corpus. Estimated ~600 LOC source + ~200 LOC tests.

## 1. Inventory

Audited files under `~/core/hexa-space/` (47 `.hexa` files / 5,105 LOC of hexa source + 19 root MD docs + firmware/sim/hdl/board + 5 test harnesses + papers/).

### 1.1 Identity / metadata (top-level)

| File | LOC | Purpose |
|---|---:|---|
| `README.md` | 397 | 27-verb 5-group survey + closure ladder + CLI surface |
| `AGENTS.md` | 53 | dancinlab-wide LATTICE_POLICY pointer + commit conventions |
| `LATTICE_POLICY.md` | 242 | Real-limits-first verification policy (dancinlab-wide; same file deployed across projects) |
| `LIMIT_BREAKTHROUGH.md` | 112 | Project-specific HARD/SOFT/BREAKABLE wall audit |
| `TAPE-AUDIT.md` | 29 | tape adoption audit (state/markers + per-vehicle analyses) |
| `IMPORTED_FROM_CANON.md` | 12 | Provenance: papers/ moved from canon@a86ca143 |
| `CHANGELOG.md` | (21 KB) | Release history |
| `hexa.toml` | (5 KB) | Package manifest — 27 modules + 5 tests + install hook |
| `install.hexa` | 62 | `hx install` post-hook (selftest only; no build deps) |
| `.roadmap.hexa_space` | (6 KB) | Falsifier preregister + Stage-1+ closure path + cycle history |
| `CITATION.cff` | (790 B) | Zenodo DOI metadata |

### 1.2 Domain SSOT docs (root MD, 12 large pillar specs)

| File | LOC | Group | Purpose |
|---|---:|---|---|
| `AEROSPACE.md` | 5361 | engineering | atmospheric/orbital systems master spec |
| `SPACE-ENGINEERING.md` | 2796 | engineering | space-engineering primitives |
| `HEXA-STARSHIP.md` | 1263 | core | deep-space crewed vessel |
| `OBSERVATIONAL-ASTRONOMY.md` | 821 | observation | observational pipelines |
| `HEXA-COSMIC.md` | 806 | core | early-universe observation mesh |
| `AEROSPACE-TRANSPORT.md` | 802 | engineering | launch/re-entry transport |
| `ASTRONOMY.md` | 799 | observation | stellar/galactic survey |
| `SPACE-SYSTEMS.md` | 750 | engineering | space-systems integration |
| `ASTRODYNAMICS.md` | 62 | observation | orbital mechanics (Kepler n=6) — short |
| `ASTROBIOLOGY.md` | 59 | life | astrobiology (short) |
| `SPACE-MEDICINE.md` | 45 | life | ISS health (short) |
| `aerospace_transport/spacex_intel_2026.md` | 243 | engineering | 23-program SpaceX 2026 intel snapshot |

### 1.3 RSC verify/ — cross-cutter inventory (12 scripts + run_all)

| File | LOC | Role |
|---|---:|---|
| `verify/lattice_check.hexa` | 301 | n=6 master closure across 27 verbs (24/24) |
| `verify/cross_doc_audit.hexa` | 276 | Anchor consistency across docs (18/18) — provenance + falsifier-ID + sister-cite |
| `verify/run_all.hexa` | 122 | Orchestrator — 16/16 bookkeeping closure across `verify/*.hexa` + `firmware/sim/*.hexa` |
| `verify/numerics_falcon.hexa` | 136 | F-SPACE-2 T2 — octaweb + Tsiolkovsky |
| `verify/falsifier_check.hexa` | 136 | F-SPACE-* closure-pct tracker (0/33/67/100 ladder) |
| `verify/lint_numerics.hexa` | 127 | recipe §4 5-invariant lint on numerics_*.hexa |
| `verify/board_audit.hexa` | 116 | Phase E doc-bundle presence audit (SCHEMATIC/BOM/PCB/COMMISSIONING/kicad_sch × 4) |
| `verify/numerics_kepler.hexa` | 114 | F-SPACE-1 T2 — Kepler 3rd law + period ratio |
| `verify/numerics_cross_pillar.hexa` | 111 | T2 cross-pillar anchor agreement |
| `verify/saturation_check.hexa` | 105 | RSC self-stop probe (sat-1 + sat-2) |
| `verify/numerics_lattice_arithmetic.hexa` | 102 | math_pure float ↔ int floor |
| `verify/numerics_bone_loss.hexa` | 97 | F-SPACE-3 T2 — exp-decay + half-life |
| `verify/numerics_starship.hexa` | 94 | F-SPACE-4 T2 — 33-Raptor + Δv |

### 1.4 Pillar verify_*.hexa scripts (one per verb, 20 verbs)

All are **n=6 algebraic bookkeeping calculators** with the same shape: `let n=6 sigma=12 tau=4 phi=2 j2=24 → assert closure → assert verb-specific identity (e.g. F9 octaweb = σ−n+3 = 9; Starship Raptor cluster = σ·n/φ−3 = 33)`. Typical size **47–105 LOC** each.

| Group | Verbs | Count | LOC range |
|---|---|---:|---|
| operations (16) | spaceship/satellite/space_center/space_ai_center/space_datacenter/falcon/dragon/recovery/orbital_depot/hls/starlink/rideshare/station/mars_base/direct_to_cell/mondaloy | 16 | 47–59 |
| engineering (3 wired) | aerospace, engineering, aerospace_transport (×3 scripts) | 3+3 | 59–254 |
| observation (1 wired) | astrodynamics | 1 | 101 |
| life (1 wired) | medicine | 1 | 99 |

### 1.5 CLI + tests + firmware

| File | LOC | Role |
|---|---:|---|
| `cli/hexa-space.hexa` | 686 | Unified dispatcher (status/group/ops/verify/spacex) |
| `tests/test_spacex.hexa` | 117 | SpaceX track — 5/5 harness |
| `tests/test_ops.hexa` | 103 | 16-verb ops sweep |
| `tests/test_lattice.hexa` | 76 | 11-cross-cutter sweep |
| `tests/test_selftest.hexa` | 37 | 11-verb canonical presence |
| `tests/test_firmware.hexa` | 40 | 4 Phase C sim sentinels |
| `aerospace_transport/analyze_spacex.hexa` | 254 | Static SpaceX program registry analyzer (23 programs) |
| `aerospace_transport/verify_mk_ladder.hexa` | 161 | Falcon/Starship/Starlink Mk-rung lattice projection |
| `aerospace_transport/verify_spacex.hexa` | 105 | SpaceX 2026 program counts vs n=6 |
| `firmware/sim/orbit_pipeline.hexa` | 126 | HEXA-ORBIT-01 sim-firmware (F-SPACE-1) |
| `firmware/sim/raptor_cluster.hexa` | 102 | HEXA-RAPTOR-01 sim-firmware (F-SPACE-4) |
| `firmware/sim/launch_telemetry.hexa` | 99 | HEXA-LAUNCH-01 sim-firmware (F-SPACE-2) |
| `firmware/sim/dxa_pipeline.hexa` | 97 | HEXA-DXA-01 sim-firmware (F-SPACE-3) |
| `firmware/hdl/*.v` | (4 files) | Vivado-synthesizable Verilog skeletons (not flashable) |
| `firmware/board/*/` | (4 dirs) | Phase E procurement bundles — SCHEMATIC + BOM + PCB + COMMISSIONING + .kicad_sch |
| `papers/*.md` | 3 files | n6-hexa-starship-integrated-paper, n6-space-systems-paper, embody-p12-1-probe-mk1-design |

**Total:** 47 hexa files / 5,105 LOC + ~14,652 LOC across 18 large MD docs + 4 Verilog + 4 KiCad bundles.

## 2. Atlas-relevant content

The hexa-lang absorption framing rests on:
- **Atlas rodata** (P/C/L/E + soon F/R/S/X/?) — primitives, constants, laws, edges.
- **Tech-data SSOTs** (9 already absorbed; e.g. `tech/embed_pkdb.hexa`, `tech/embed_isotopes.hexa`).
- **Algorithm modules** (38+; falsifiers/hexad/honesty/lens_taxonomy/discover/etc.).
- **Doctrine v2 5 rules**:
  1. tech content → rodata
  2. algorithms → code
  3. metadata → frozen archive
  4. try-CLI-or-fallback (δ pattern)
  5. rodata seed + overlay flush

### 2.1 Does hexa-space ship atlas-shaped content?

**No corpus of primitives/constants/laws/edges in atlas form.** The repo's epistemic surface is:
- domain **prose specs** (.md, narrative + tables, not `@P/@C/@L/@E` headers);
- n=6 **algebraic identities** (sigma·phi=24, octaweb=σ−n+3, Raptor cluster=σ·n/φ−3) embedded as **inline assertions** inside `verify_*.hexa` scripts — not data, code;
- a **23-program SpaceX 2026 registry** (`spacex_intel_2026.md` + `analyze_spacex.hexa`) — could be re-shaped into atlas `@E` entries (engine bus / experiment record) but the grain is "program slug + status + group + NET date", which is **operational metadata**, not a constant/law.

### 2.2 Does hexa-space ship algorithms hexa-lang lacks?

**Yes — the RSC saturation-loop bookkeeping is novel.** Concretely:
- `verify/falsifier_check.hexa` — per-falsifier T1+T2+T3 closure-pct ladder (0/33/67/100).
- `verify/saturation_check.hexa` — sat-1 ∧ sat-2 stop trigger + STOP sentinel.
- `verify/lint_numerics.hexa` — 5-invariant lint on a numerics_*.hexa convention.
- `verify/run_all.hexa` — orchestrator pattern (bookkeeping closure across N subscripts → single PASS sentinel).
- `verify/lattice_check.hexa` — declared-vs-asserted n=6 invariant audit across cross-doc anchors.

hexa-lang has `compiler/falsifiers/` and `compiler/atlas/audit.hexa`, but **neither** encodes the closure-pct ladder, the inventory-lint, or the saturation stop-trigger. These are **recipe substrate**, not domain code, and they generalize: every hexa-family project (hexa-fusion, hexa-rtsc, hexa-cern, hexa-antimatter — all named in `run_all.hexa` comments) uses the same shape.

### 2.3 Naming drift — `n=6`

- hexa-space uses **`n=6` (perfect-number invariant lattice)** in the project-specific sense (σ(6)·φ(6) = n·τ(6) = J₂(6) = 24).
- hexa-lang `compiler/atlas/` uses **`n6` (NEXUS-6)** as the atlas grammar identifier (`@P @C @L @E ...` header-sigil parser; `663698a0` rodata).
- These are **unrelated**. The `n6` token collision is incidental — n6 (the grammar/corpus) is named after Blade Runner's Nexus-6 replicant model, while hexa-space's `n=6` is the perfect-number lattice. Plan must keep the namespaces distinct.

## 3. Candidates by Doctrine v2 rule

### Rule 1 (tech content → rodata)

| Candidate | Source | Priority | Notes |
|---|---|:-:|---|
| SpaceX 2026 program registry (23 programs) | `aerospace_transport/spacex_intel_2026.md` + `analyze_spacex.hexa` | **low** | Not atlas-shaped (operational status/NET dates, not constants/laws). Would only fit if hexa-lang ever scopes a `compiler/space_registry/` SSOT — not on current roadmap. **Skip for atlas absorption.** |
| Falcon Mk-ladder rung table | `aerospace_transport/verify_mk_ladder.hexa` | low | Same shape — operational ladder, not constant. **Skip.** |
| LATTICE_POLICY.md dancinlab-wide policy | `LATTICE_POLICY.md` | medium | This file already exists outside hexa-space (deployed 2026-05-12 to all dancinlab projects). hexa-lang may **mirror** it under `doc/policy/` if not already present. Verify before duplicating. |
| LIMIT_BREAKTHROUGH.md project-specific limits | `LIMIT_BREAKTHROUGH.md` | n/a | Project-specific to hexa-space (NASA HRP, Falcon thrust limits, etc.). **Skip — wrong domain.** |
| Pillar domain specs (AEROSPACE/STARSHIP/COSMIC/etc.) | 12 root MDs (~13.4K LOC) | **low** | Massive volume; narrative prose; not in P/C/L/E atlas shape. **Skip** unless hexa-lang opens a space-domain corpus track. |

### Rule 2 (algorithms → code)

| Candidate | Source | LOC | Priority | Target |
|---|---|---:|:-:|---|
| RSC saturation probe | `verify/saturation_check.hexa` | 105 | **high** | `tool/rsc/saturation_check.hexa` — generic across hexa-lang's own falsifier list |
| Closure-pct ladder tracker | `verify/falsifier_check.hexa` | 136 | **high** | `tool/rsc/falsifier_audit.hexa` — adapted to hexa-lang's `compiler/falsifiers/` registry |
| numerics_*.hexa 5-invariant lint | `verify/lint_numerics.hexa` | 127 | **high** | `tool/rsc/lint_numerics.hexa` — applies to any project adopting the recipe |
| run_all orchestrator pattern | `verify/run_all.hexa` | 122 | medium | hexa-lang has its own runners; useful as a **reference**, not a verbatim port. Document the pattern instead. |
| n=6 lattice cross-doc audit | `verify/lattice_check.hexa` | 301 | low | hexa-space-specific (27-verb pillar list, README anchors). The **pattern** is generic but the **content** is not. Skip verbatim port. |
| Cross-pillar numerical anchor agreement | `verify/numerics_cross_pillar.hexa` | 111 | low | Domain-coupled (F9/Kepler/ISS). Pattern, not port. |
| Per-domain T2 numerics (Kepler, Falcon, Starship, bone-loss) | `verify/numerics_*.hexa` (×4) | 441 total | skip | F-SPACE-* are hexa-space's own falsifiers, not hexa-lang's. |
| n=6 pillar verifier shape | 20 `verify_<verb>.hexa` | ~1100 total | skip | Tied to hexa-space's 27-verb roster. Pattern (declarative lattice assertion) is already trivially expressible in hexa-lang — no port required. |
| firmware/sim/*.hexa Phase C controllers | 4 files × ~100 LOC | 424 | skip | Stage-1 closure-path bookkeeping; targets specific FPGAs (Zynq US+, Kintex US, STM32H7). Out of scope for the language. |
| `cli/hexa-space.hexa` dispatcher | 686 LOC | 686 | skip | hexa-lang has `compiler/main.hexa` + `bin/`. Different surface. |
| `install.hexa` hx hook | 62 LOC | 62 | skip | hexa-lang ships its own install path; nothing to absorb. |
| `analyze_spacex.hexa` registry analyzer | 254 LOC | 254 | skip | Domain-specific to hexa-space. |

### Rule 3 (metadata → frozen archive)

| Candidate | Source | Priority | Notes |
|---|---|:-:|---|
| `IMPORTED_FROM_CANON.md` | provenance ledger | low | hexa-lang has its own provenance docs; this is project-internal. Skip. |
| `TAPE-AUDIT.md` | tape adoption audit | low | Project-internal. Skip. |
| `state/markers/*.marker` | 543 housekeeping + payload-analysis markers | skip | Per-run probes; not historical record worth absorbing. |
| `CHANGELOG.md` (21 KB) | release history | skip | Project-internal. |
| `papers/*.md` (3 files) | n6 papers (re-homed from canon) | low | These are research artefacts about n6 + space; provenance is canon, not hexa-space. If hexa-lang ever scopes a papers corpus, source from canon directly. |

### Rule 4 (try-CLI-or-fallback / δ pattern)

| Candidate | Source | Priority |
|---|---|:-:|
| `exec()`-shelled invocations in `falsifier_check` / `saturation_check` | hexa-space uses `exec("hexa run ...")` to invoke subscripts | n/a — the pattern itself is the δ-adapter shape, but hexa-space scripts don't use a try-CLI-or-fallback gate (no CLI version detection / fallback). **Nothing to absorb** under Rule 4. |

### Rule 5 (rodata seed + overlay flush)

Nothing in hexa-space writes to atlas overlay or seeds rodata. **Not applicable.**

## 4. Top-3 high-priority candidates

### 4.1 RSC verifier recipe → `tool/rsc/`

**Single most valuable absorption.** The three scripts that together codify the Runnable Surface Closure recipe:

1. `verify/falsifier_check.hexa` (136 LOC) — per-falsifier closure-pct ladder.
2. `verify/saturation_check.hexa` (105 LOC) — sat-1 ∧ sat-2 stop trigger.
3. `verify/lint_numerics.hexa` (127 LOC) — 5-invariant lint on numerics scripts.

These are **project-agnostic substrate** (the same shape is named in `run_all.hexa` for hexa-fusion / hexa-rtsc / hexa-cern / hexa-antimatter). hexa-lang has `compiler/falsifiers/` and `compiler/atlas/audit.hexa` but no recipe-level harness.

**Target:** `tool/rsc/{falsifier_audit,saturation_check,lint_numerics}.hexa` parameterized over a hexa-lang-side falsifier registry (e.g. `compiler/falsifiers/registry.hexa`). Estimated ~400 LOC after dropping hexa-space-specific globs (numerics_kepler/falcon/starship/bone_loss) and parameterizing the inventory list.

**Value:** lets hexa-lang's own falsifier corpus declare a closure-pct ladder + run the saturation probe. Wires into a new `hexa rsc audit` subcommand.

### 4.2 Falsifier closure-progress doctrine note → `doc/rsc/closure_ladder.md`

The **doctrine** (recipe §3 closure_pct ladder, T1/T2/T3 tier semantics, sat-1 ∧ sat-2 saturation criterion) currently exists only as inline comments in hexa-space scripts (+ external `bedrock/docs/runnable_surface_recipe.md` which is outside hexa-space).

**Target:** distill into `doc/rsc/closure_ladder.md` (~80 LOC) — describing the 0/33/67/100% ladder, T-tier definitions, sat-1/sat-2 criteria, the orchestrator pattern, and how it pairs with Doctrine v2 (Rule 2 algorithms are the T1+T2 surface; Rule 5 overlay/rodata seed is the saturation evidence).

**Value:** establishes hexa-lang's official posture on closure progress beyond pass/fail; gives `compiler/falsifiers/` a tier vocabulary it currently lacks.

### 4.3 Mirror `LATTICE_POLICY.md` under `doc/policy/` (if not already present)

The dancinlab-wide real-limits-first verification policy is deployed across all dancinlab projects (per AGENTS.md preamble). **Verify** whether hexa-lang carries it; if not, mirror under `doc/policy/lattice_policy.md`.

**Target:** verbatim copy (~242 LOC) + provenance header. Zero code change.

**Value:** consistency across HEXA family; gives hexa-lang's atlas grade-marker work a top-level policy anchor.

## 5. Absorption waves

### Wave 1 — RSC verifier recipe (priority high)

**1.1 — falsifier closure-pct tracker → `tool/rsc/falsifier_audit.hexa`**
- Source: `~/core/hexa-space/verify/falsifier_check.hexa` (136 LOC).
- Adapt: parameterize over hexa-lang's falsifier registry. hexa-lang's falsifiers live under `compiler/falsifiers/` (per `compiler/falsifiers/` dir + `inbox/notes/2026-05-13-phase2-verifiers-session.md`). Build a small `tool/rsc/registry.hexa` that enumerates `(name, t1_path, t2_paths[])` tuples sourced from the existing falsifier modules.
- Target LOC: ~150 (after dropping `F1_T1..F4_T2` hard-coded refs and adding generic registry walker).
- Wire to: `tool/rsc_cli.hexa` (new) → `hexa rsc falsifier`.

**1.2 — saturation probe → `tool/rsc/saturation_check.hexa`**
- Source: `~/core/hexa-space/verify/saturation_check.hexa` (105 LOC).
- Adapt: same parameterization. Keep the three-condition gate (lint passes ∧ inventory ≥ floor ∧ min T2 stack ≥ 1). Replace the `__HEXA_SPACE_RSC_SATURATED__` sentinel with `__HEXA_LANG_RSC_SATURATED__`. Floor becomes a registry-derived constant, not the 4-or-9 hard-code.
- Target LOC: ~120.
- Wire to: `hexa rsc saturation`.

**1.3 — numerics lint → `tool/rsc/lint_numerics.hexa`**
- Source: `~/core/hexa-space/verify/lint_numerics.hexa` (127 LOC).
- Adapt: replace `NUMERICS_SCRIPTS` glob (hexa-space-specific) with a glob over hexa-lang's own numerics-tier verifier convention. Keep the 5 invariants (math_pure import / sentinel prefix / FALSIFIERS array / exit(0) / RUN+FAIL counters) — they generalize.
- Target LOC: ~140.
- Wire to: `hexa rsc lint`.

**Wave 1 total:** ~410 LOC source + ~150 LOC tests.

### Wave 2 — RSC orchestrator + doctrine doc (priority medium)

**2.1 — `tool/rsc/run_all.hexa` orchestrator**
- Source: `~/core/hexa-space/verify/run_all.hexa` (122 LOC) — reference, not verbatim port.
- Adapt: walks `tool/rsc/registry.hexa` + invokes each script + aggregates pass/fail + emits `__HEXA_LANG_RSC_RUN_ALL__ PASS`.
- Target LOC: ~130.

**2.2 — `doc/rsc/closure_ladder.md` doctrine**
- Distill from comments in hexa-space scripts + recipe references. Pairs with Doctrine v2 Rule 2 (algorithms → code).
- Target LOC: ~80 prose.

**2.3 — Mirror `LATTICE_POLICY.md` (gated)**
- First check whether hexa-lang already carries it. If not, copy verbatim under `doc/policy/lattice_policy.md` with provenance header.

**Wave 2 total:** ~130 LOC source + ~80 LOC docs.

### Wave 3 — examples / test fixtures (priority low)

**3.1 — hexa-space verify scripts as compile-test fixtures**
- Drop `verify/numerics_kepler.hexa` / `numerics_falcon.hexa` / `numerics_starship.hexa` / `numerics_bone_loss.hexa` (~441 LOC total) into `test/fixtures/rsc/numerics/` as **read-only fixtures** for the lint_numerics target to validate against.
- They give the lint a concrete corpus to certify (5/5 invariants × 4 scripts).
- Target LOC: ~0 source change; pure data drop.

**Wave 3 total:** ~0 LOC source + ~80 LOC test driver.

## 6. Skip list

| Item | Reason |
|---|---|
| 12 large pillar MDs (AEROSPACE/STARSHIP/etc., ~13.4K LOC) | Narrative prose, not atlas-shaped, wrong domain axis for hexa-lang |
| 20 per-verb `verify_<verb>.hexa` (~1.1K LOC) | Hexa-space-specific n=6 algebraic identities; nothing transferable beyond the recipe shape |
| `cli/hexa-space.hexa` (686 LOC) | Hexa-space-specific dispatcher; hexa-lang has its own |
| `install.hexa` | Hexa-space hx hook; not a hexa-lang concern |
| `aerospace_transport/*.hexa` (520 LOC) | SpaceX program registry + Mk-ladder; operational metadata, not atlas content |
| `firmware/sim/*.hexa` (424 LOC) | Stage-1 sim-controllers targeting specific FPGAs; closure-path bookkeeping for F-SPACE-* |
| `firmware/hdl/*.v` (4 Verilog files) | FPGA synthesis target; out of scope |
| `firmware/board/*/` (4 procurement bundles + KiCad files) | Phase E procurement docs; out of scope |
| `tests/test_*.hexa` (5 files, 373 LOC) | Hexa-space-internal regression harnesses |
| `state/markers/*.marker` (543 markers) | Per-run probe markers; not historical record |
| `papers/*.md` (3 files) | Research papers; if absorbed, source from canon directly (per IMPORTED_FROM_CANON.md) |
| `CHANGELOG.md` (21 KB) | Project-internal release log |
| `LIMIT_BREAKTHROUGH.md` (112 LOC) | Project-specific to hexa-space limits |
| `TAPE-AUDIT.md` (29 LOC) | Project-internal tape adoption audit |
| `CITATION.cff` + Zenodo DOI | Project-specific citation metadata |
| `spacex_intel_2026.md` (243 LOC) | Operational snapshot; staleness-sensitive; wrong shape for atlas |

## 7. Coordination notes

**License:** MIT — copy with attribution header. Recommend `// absorbed from ~/core/hexa-space/<path> (MIT)` one-liner.

**No n=6 lattice import.** hexa-lang's atlas uses the n6 *grammar* (NEXUS-6 replicant naming). hexa-space's `n=6` is the perfect-number invariant lattice. **Do not** cross-pollinate vocabulary: any port should rename hexa-space's σ/τ/φ/J₂ symbols to neutral identifiers if they ever land in hexa-lang source.

**Falsifier registry needs to exist first.** Wave 1 depends on a `tool/rsc/registry.hexa` shape that enumerates hexa-lang's own falsifiers. Today `compiler/falsifiers/` modules exist but there's no single registry — verify before scheduling Wave 1.

**No double-port checks:**
- hexa-lang `compiler/atlas/audit.hexa` (already ported from n6) is **adjacent** to `lint_numerics` but covers a different surface (atlas corpus health, not numerics-script lint). No overlap.
- hexa-lang's `inbox/notes/2026-05-13-n6-absorption-plan.md` covers the **n6 grammar/corpus** absorption — unrelated to hexa-space.
- hexa-fusion / hexa-rtsc / hexa-cern / hexa-antimatter (all sister projects named in hexa-space `run_all.hexa`) **also use the RSC recipe** — Wave 1's `tool/rsc/` target should be designed to serve them too, not just hexa-lang.

**Saturation sentinel cross-family namespace.** Each project owns its sentinel string (`__HEXA_SPACE_RSC_SATURATED__`, `__HEXA_FUSION_RSC_SATURATED__`, etc.). Hexa-lang's would be `__HEXA_LANG_RSC_SATURATED__`. Document this naming convention in the doctrine doc (Wave 2.2).

**Recipe authority.** The recipe itself (`bedrock/docs/runnable_surface_recipe.md`) is referenced but not shipped in hexa-space. If Wave 2.2 distills doctrine, decide whether hexa-lang's doc is **the** canonical recipe ref or just a per-project digest.

## 8. Scope estimate

Recommended scope (Wave 1 + Wave 2 + Wave 3):

| Wave | Files | Source LOC | Doc LOC | Test LOC |
|---|---:|---:|---:|---:|
| 1 — verifier recipe core | 3 new (`falsifier_audit`/`saturation_check`/`lint_numerics`) + 1 registry | ~410 | — | ~150 |
| 2 — orchestrator + doctrine | 1 source + 1 doc (+ optional 1 doc mirror) | ~130 | ~80 (+~242 mirror) | — |
| 3 — fixtures | 0 source / 4 fixture files | 0 | — | ~80 |
| **Total** | ~6 new files | **~540 LOC** | **~80 LOC (excl. policy mirror)** | **~230 LOC** |

Excludes the optional `LATTICE_POLICY.md` mirror (242 LOC verbatim copy; gated on whether hexa-lang already carries it).

## 9. Bottom line

`hexa-space` is **not an atlas-content donor.** No P/C/L/E corpus; no constant/law primitives; the 13K+ LOC of MD docs are narrative space-domain specs targeting a different epistemic axis from atlas.

`hexa-space` **is a recipe-substrate donor.** The 3-script RSC verifier core (`falsifier_check` + `saturation_check` + `lint_numerics`, totalling 368 LOC) encodes a closure-pct ladder + saturation stop trigger that **no other dancinlab repo ships in absorbable form** and that hexa-lang's own falsifier infrastructure currently lacks. The recipe pattern is named in hexa-space's `run_all.hexa` comments as shared across hexa-fusion / hexa-rtsc / hexa-cern / hexa-antimatter — hexa-lang absorbing it positions it as the canonical reusable substrate for the family.

**Recommended action:** schedule Wave 1 (RSC verifier recipe core, ~410 LOC + ~150 LOC tests) gated on a `tool/rsc/registry.hexa` shape that enumerates hexa-lang falsifiers. Defer Wave 2.3 (`LATTICE_POLICY.md` mirror) until verifying hexa-lang doesn't already carry it. Skip everything else.
