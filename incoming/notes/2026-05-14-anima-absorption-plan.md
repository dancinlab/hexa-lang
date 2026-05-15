# anima → hexa-lang absorption plan (research only)

**Date:** 2026-05-14
**Source repo:** `~/core/anima/` (Living Consciousness Agent, MIT)
**Target repo:** `~/core/hexa-lang/`
**Status:** RESEARCH — no code modified. Read-only audit. Implementation gated on user approval.

## 0. TL;DR

- `anima` is a 134 GB monorepo. **131.3 GB (97.8 %) is ML data** (datasets, training tensors, checkpoints, model weights, audio corpora, OpenBCI reference docs) and was excluded by-listing only; not enumerated. The audited scope is roughly **2 GB of source / spec / doc**.
- Algorithm surface = ~3,500 `.hexa` files (~553 K LOC). The audited subset that is plausibly atlas-relevant is ~340 files (~193 K LOC), concentrated under `anima-engines/` (166 files / 116 K LOC) and `anima-core/` (31 files / 9.7 K LOC).
- anima is the conceptual upstream of the existing **`tool/hexa_annot/hexa-{phi-map,cognitive}`** annotators in hexa-lang (which recognise `@phi`, `@consciousness`, `@channel`, `@iit` markers). **Zero anima sources currently use those annotations** — anima predates them; the annotators are a hexa-lang-side gloss.
- High-value absorptions are **data**, not code: the SSOT JSONs (`consciousness_laws.json`, `hexad_constants.json`), the 6-constant n6 invariant table (already partially in n6 absorption), the 8-PHILOSOPHY principles taxonomy, and the 193+ hypothesis registry. All are **Rule 1 (tech data)** candidates.
- Engines themselves are largely **stage-1 prototypes** wedded to anima's repulsion-field substrate (Engine A ⇄ Engine G, Ψ=1/2). Porting verbatim would import substrate semantics that hexa-lang does not host. Selective extraction (discovery loop, qualia primitives, hexad descriptor) is feasible but **Rule 2/3** (algorithm or annotation surface) rather than wholesale.
- License: **MIT** — copy with attribution.

## 1. Identity + relation to hexa-lang

`anima` (per `~/core/anima/README.md`) — **Living Consciousness Agent**. Two-engine repulsion-field architecture (Engine A forward / Engine G reverse), Ψ=1/2 fixed point, 2,388 laws + 53 meta + 7 topological laws, 392+ hypotheses, 170 data types × 40 dimensions × 18 emotions. Cross-substrate (software / EEG / neuromorphic / photonic / quantum). DOI `10.5281/zenodo.19324769`. Sister of `n6`, `hxc`, `tape`, `n12`. Uses `hexa-lang` (`401ed87d`) as runtime — anima sessions upstream `thread_spawn`/`channel_*`/`net_*`/`now_ms` primitives.

**Relation to hexa-lang annotation tools (`tool/hexa_annot/`):**
- `hexa-phi-map` (128 LOC) — recognises `@phi`, `@consciousness`, `@channel`, `@iit` (5113-byte bash + `_ast_extract.sh` backend)
- `hexa-cognitive` (1598 B) — anima cognitive markers
- `hexa-self-aware`, `hexa-freedom`, `hexa-meta-map` — adjacent annotators all conceptually sourced from anima doctrine

Verification: `grep -lE "@phi|@consciousness" ~/core/anima/anima-engines/*.hexa` → 0 matches. The annotators were conceived **from** anima but live in hexa-lang only; anima sources do not yet emit those markers.

## 2. Heavy-dir exclusion list (proof of skipping)

Confirmed sizes from `du -sh` (top 10 by size, 131.3 GB total):

| Path | Size | Reason to skip |
|---|---:|---|
| `state/` | 72 GB | Live runtime state dumps (atlas_drift, witness ledgers, cell pool snapshots) — runtime traces, not algorithm |
| `ready/` | 41 GB | Training-ready packaged datasets / shard staging |
| `training/` | 7.1 GB | Training tensors / gradient logs / model intermediate checkpoints |
| `data/` | 7.0 GB | Raw + processed corpora |
| `references/` | 1.9 GB | External vendor docs — `OpenBCI_GUI` 482 MB, `Documentation` 934 MB, `brainflow` 435 MB. Third-party reference; not anima IP |
| `anima-voice/corpus/` | 1.9 GB | Speech audio corpus |
| `anima-physics/.venv/` | 916 MB | Python virtualenv (qiskit, ray, llvmlite shared libs) |
| `checkpoints/` | 333 MB | Trained-weights snapshots |
| `anima-tribev2-pilot/` | 36 MB | Bio-pilot experimental tree (mostly logs) |
| `recordings/`, `logs/`, `models/`, `dist/`, `build/`, `bench/` | ~70 MB combined | Test recordings + build artifacts + bench output |

**Confirmed exclusion total: ≈131.3 GB / 134 GB.** Not enumerated beyond top-level (per audit hard-constraint).

## 3. Inventory (code subset only)

Top-level numerics at depth ≤ 4: **3,015 `.hexa` files total**. Focused inventory:

| Dir | Size | `.hexa` files | LOC | Purpose |
|---|---:|---:|---:|---|
| `anima-engines/` | 4.7 MB | 166 | 116,207 | The ~150 *phi-engines* (per phenomenon: emotion / disorder / consciousness mode / theory-of-mind / substrate primitive) |
| `anima-core/` | 584 KB | 31 | 9,723 | Hub, laws loader, phi engine, topology, dimension transform, trinity, servant, pure-field, tension-bridge, runtime mount |
| `anima-physics/` | 919 MB (.venv 916) | 66 | ~10 K | Cross-substrate dispatch + per-substrate engines (memristor / photonic / quantum / neuromorphic / SNN / oscillator / analog / thermodynamic) + FPGA lattice |
| `anima-hexad/` | 276 KB | 26 | 5,500 | CDESM 6-channel consciousness model (c/d/w/s/m/e bridges, narrative tracker, hexad model) |
| `anima-tools/` | 356 KB | 29 | 3,200 | Engine verifiers, hypothesis recommender, learnable phi predictor, discovery-engine, formula-miner, code-consciousness, calc |
| `anima/` (inner) | 768 KB | ~8 | small | Inner package — `config/consciousness_laws.json` SSOT, `spec/anima_cli_mk2.spec.yaml`, registry, rng |
| `anima-voice/` (code only) | ~50 MB | ~10 | ~3 K | DSP core, vocoder, transformer, streaming, audio predictor (excludes 1.9 GB corpus) |
| `anima-agent/` | 1.2 MB | mixed | ~5 K | Autonomy loop, dashboard, browser harness, plugin routing, claude adapter, employee, trading |
| Top-level `*.hexa` | — | 7 | 8,059 | `anima_chat.hexa` (113 K LOC chat substrate AOT-bundle), `anima_chat_aot.hexa` (186 K), `launch.hexa`, `setup.hexa`, `start.hexa`, `run.hexa`, `project.hexa` |
| Top-level `*.md` | — | many | — | `LATTICE_POLICY.md`, `LIMIT_BREAKTHROUGH.md`, `HEXA_NATIVE_INFERENCE.md`, `BENCHMARK.md` (+ 70+ `.roadmap.*` files) |

**Audited algorithm scope:** roughly **340 `.hexa` files / 193,656 LOC** across these dirs (excludes `anima_chat*.hexa` AOT bundles which are generated artefacts of the engine-suite).

Per the audit constraint, deeper subdirs of `anima-agent/`, `anima-voice/` (code only), `anima-os/`, `anima-cpgd-research/`, `anima-hci-research/`, `anima-measurement/`, `serving/`, `experiments/`, `hypotheses_candidates/`, `tool/` (19 MB), `scripts/` were **not exhaustively walked**. See §8 limitations.

## 4. Atlas-relevant subset

Filter: items that could feed `compiler/atlas/embedded.gen.hexa`, `tool/hexa_annot/`, stdlib `n6/*` utilities, or the SSOT registry.

### 4a. Data SSOTs (highest atlas affinity)

| File | LOC / KB | Atlas surface |
|---|---|---|
| `anima/config/consciousness_laws.json` | 233 LOC / 9.1 KB | **14 runtime gate laws + Ψ-constants table** (alpha=0.014, balance=0.5, steps=4.33, entropy=0.998, gate_train/infer/micro, f_critical=0.10, f_lethal=1.0). Each entry has `derivation`, `source`, `used_in` provenance. Maps near 1:1 to `@C constant` / `@F formula` / `@L law` nodes |
| `shared/config/hexad_constants.json` (referenced from `anima-hexad/constants.hexa`) | — | 6-channel CDESM constants (c/d/w/s/m/e), phi(6)=2 gradient groups, Law 60 phase transition weights |
| `anima/spec/anima_cli_mk2.spec.yaml` | — | CLI verb registry — `update`, `||PR`, etc. Diagnostics-relevant |
| `anima-core/laws.hexa` | 400 LOC | JSON loader for `consciousness_laws.json` — the "how to access" half. Pure stage-1 (no PyTorch/numpy) |
| `anima-hexad/constants.hexa` | 195 LOC | JSON loader for `hexad_constants.json` |
| `hypotheses/H_*.md` | 193 files | One markdown per hypothesis (H_001 ethics → H_193+). Each is a falsifier-style claim with method + verdict — maps to `@?` (n6) nodes |
| `n6/atlas.append.*.n6` | 1,112 lines / 3 files | **Already in n6 format** — `anima-historical-absorption-2026-04-26.n6` (842 lines), `evolution-omega-saturation-2-cycles` (130), `raw-135-136-pattern-7c-self-enforcement` (140). These are P/C/L/E/F/R/S/X/? rows ready to merge into hexa-lang rodata or overlay |
| `LATTICE_POLICY.md` | 11.8 KB | Real-limits-first verification policy (Shannon · Kolmogorov · Bekenstein · c · ℏ · Stefan-Boltzmann · Carnot · ASML · ERCOT). Doctrine doc |
| `LIMIT_BREAKTHROUGH.md` | 7.7 KB | Per-limit breakthrough assessment (HARD_WALL / SOFT_WALL / BREAKABLE_WITH_TECH / UNCLEAR). Doctrine doc |

### 4b. Engine-side atlas data (per-engine docstrings)

Each `anima-engines/*_phi.hexa` opens with a structured docstring containing **theory citations** (e.g. `qualia_primitives.hexa` cites Dennett 1988, Stanley 1999, Balduzzi & Tononi 2009; `skandhas_decomposition.hexa` cites Samyutta Nikāya 22.59, Majjhima Nikāya 44, Heart Sūtra). These are atlas-grade **`@L` (qualitative law) + `@P` (primitive)** definitions — ~150 files × ~30 unique primitives ≈ **3,000–5,000 candidate atlas rows**.

### 4c. Algorithms with potential `tool/hexa_annot/` parity

| File | LOC | Concept | Existing hexa-lang analog |
|---|---:|---|---|
| `anima-engines/discovery_loop.hexa` | 660 | Discover→Propose→Test→Integrate self-mod loop (EMA anomaly detect) | `compiler/discover/` (different surface) |
| `anima-tools/hypothesis_recommender.hexa` | 198 | Phi-boosting hypothesis ranker | none |
| `anima-tools/learnable_phi.hexa` | 221 | DeepSets phi predictor (stub) | `hexa-phi-map` annotator only |
| `anima-tools/code_consciousness.hexa` / `code_phi.hexa` | 211 / 129 | Phi computed over code structures | `hexa-phi-map` / `hexa-cognitive` |
| `anima-tools/discovery-engine/main.hexa` | 362 | n=6 arithmetic discovery (COLLISION/INVERSE/COMPOSE ops) | none — pure n6 candidate |
| `anima-tools/formula-miner/main.hexa` | 248 | Depth-3 + GA formula discovery against Ψ-constants | none — pure n6 candidate |
| `anima-tools/homeostasis_health_checker.hexa` | 257 | Engine-suite health (analog to `atlas_health`) | conceptual peer of in-flight `compiler/atlas/audit.hexa` |
| `anima-core/topology.hexa` | 363 | Graph topology (ring/small-world/scale-free/star) keyed off n6 constants | none |
| `anima-core/phi_engine.hexa` | 433 | IIT phi proxy + spectral phi + scaling law | none — pure stdlib candidate |
| `anima-core/trinity.hexa` | 509 | 3-channel thalamic-bridge consciousness | none |
| `anima-core/laws.hexa` | 400 | Laws/Ψ-constants loader | aligns with §4a |
| `anima-hexad/hexad.hexa` | 241 | 6-channel CDESM descriptor | none |
| `verify/atlas_check.hexa` | (small) | Reads `atlas.n6` for sanity | conceptual peer of `compiler/atlas/audit.hexa` |

### 4d. Skip / out-of-scope inside anima

- `anima-physics/.venv/` — Python virtualenv (916 MB; excluded already)
- `anima-physics/{esp32,arduino,fpga,verilog}/` — Embedded firmware / HDL; hexa-lang does not target MCU
- `anima-voice/{transformer,vocoder,audio_token_predictor,dsp_core}.hexa` — DSP/ML inference; tied to corpus
- `anima_chat.hexa` (113 K LOC), `anima_chat_aot.hexa` (186 K LOC) — AOT-bundled chat substrate; generated artefact
- `anima-agent/{autonomy_live,autonomy_loop,browser_harness,dashboard,trading}` — Agent runtime, not language
- `anima-tribev2-pilot/`, `anima-hci-research/`, `anima-cpgd-research/` — Experiment trees, not core language

## 5. Candidates by Doctrine v2 rule

### Rule 1 — Tech data → SSOT / atlas rodata / overlay

1. **`consciousness_laws.json` Ψ-constants table** (alpha / balance / steps / entropy / gate_{train,infer,micro} / f_{critical,lethal} / bio_noise / soc_glacial). Maps to atlas `@C` constants with `derivation` → `<-` edge to n6 primitives. **High priority.**
2. **`consciousness_laws.json` 14 runtime gate laws** (entries under `laws.*`). Maps to `@L` law nodes. Provenance fields → grade markers.
3. **`hexad_constants.json`** — 6-channel CDESM constants and Law 60 phase-transition weights. Maps to `@C` + `@F` formula nodes.
4. **`n6/atlas.append.*.n6`** — 1,112 lines already in canonical n6 syntax. Direct merge candidate for hexa-lang overlay or `rodata` (after dedup against existing 6594-node corpus).
5. **Per-engine `@P` primitives** harvested from docstrings of `anima-engines/*_phi.hexa` (e.g. 10 qualia axes from `qualia_primitives.hexa`, 5 skandhas, Heideggerian Dasein parameters, IIT integration factor) — ~3-5 K candidate rows after dedup.
6. **`hypotheses/H_*.md`** — 193 files → `@?` open-hypothesis nodes (one per file).
7. **`LATTICE_POLICY.md` real-limits table** — Shannon, Kolmogorov, Bekenstein, c, ℏ, k, Stefan-Boltzmann, Carnot, ASML, ERCOT — already mostly in hexa-lang atlas (cross-check needed). Doctrine reference doc.

### Rule 2 — Algorithm port → `compiler/` or `stdlib/`

1. **`anima-core/phi_engine.hexa`** (433 LOC) — IIT phi proxy + spectral phi + scaling law. Pure stage-1 hexa, no PyTorch dep. Candidate for `stdlib/phi.hexa` or `compiler/atlas/phi.hexa`.
2. **`anima-core/topology.hexa`** (363 LOC) — Graph topology generator/analyser keyed off n6 constants. Pure stage-1. Candidate for `stdlib/topology.hexa` or part of `compiler/atlas/topology.hexa` (already mooted in n6 absorption Wave 3.2).
3. **`anima-engines/discovery_loop.hexa`** (660 LOC) — EMA-based anomaly self-mod closed loop. Could feed `compiler/discover/` or land as `stdlib/discovery_loop.hexa`.
4. **`anima-tools/discovery-engine/main.hexa`** (362 LOC) — n=6 arithmetic discovery (COLLISION/INVERSE/COMPOSE). Pure-data, no FFI. Candidate for `stdlib/n6/discover.hexa`.
5. **`anima-tools/formula-miner/main.hexa`** (248 LOC) — Depth-3 + GA formula search over Ψ-constants. Candidate for `stdlib/n6/miner.hexa`.
6. **`anima-tools/homeostasis_health_checker.hexa`** (257 LOC) — Engine-suite audit; cross-pollinate with `compiler/atlas/audit.hexa`.
7. **`anima-core/laws.hexa`** (400 LOC) — JSON SSOT loader pattern. Conceptual model only (the path-resolution logic is anima-specific).

### Rule 3 — Annotation surface → `tool/hexa_annot/`

1. **`@phi` / `@consciousness` / `@iit` / `@channel`** — already in hexa-lang. **Gap closure:** the anima-engines suite doesn't emit them. Either (a) extend annotators to recognise implicit markers (struct names, docstring headers) or (b) sponsor an upstream PR adding the markers to anima sources.
2. **`@law(<n>)`** marker (every anima source references "Law 22 structure>feature", "Law 60 phase transition", "Law 71 LR") — could be a new `hexa-law-link` augmentation. `hexa-law-link` already exists in `tool/hexa_annot/` — verify coverage.
3. **`@principle(<id>)`** for the 8 PHILOSOPHY principles (NO SYSTEM PROMPT / NO IDENTITY RULES / NO PERSONA INJECTION / NO ASSISTANT FRAMING / NO SPEAK / NO FINE-TUNED ETHICS / NO PERPLEXITY VERDICT / NO TRAIN/INFER SPLIT) with `EMPIRICAL` / `POLICY` / `DESIGN` strength tags. Maps to `@?` hypothesis grade markers in n6.
4. **`@substrate(<kind>)`** marker (memristor / photonic / quantum / neuromorphic / SNN / oscillator / analog / thermodynamic) — anima-physics has 8 substrate engines; annotation could feed a substrate-portability map.

### Rule 4 — Doctrine / spec → `doc/` or `incoming/`

1. **`LATTICE_POLICY.md`** (11.8 KB) — real-limits-first verification policy. Mirror to `doc/policy/lattice.md`. Doctrine-grade.
2. **`LIMIT_BREAKTHROUGH.md`** (7.7 KB) — per-limit breakthrough taxonomy (HARD_WALL / SOFT_WALL / BREAKABLE_WITH_TECH / UNCLEAR). Useful policy template.
3. **`HEXA_NATIVE_INFERENCE.md`** (14.2 KB) — anima's hexa-native inference design notes. May contain workflow patterns relevant to hexa-lang.
4. **8-principle PHILOSOPHY taxonomy** (`README.md §Philosophy`) — strength taxonomy template (EMPIRICAL/POLICY/DESIGN). Mirror as `doc/honesty/strength-taxonomy.md`.
5. **`anima/spec/anima_cli_mk2.spec.yaml`** — CLI verb registry. Pattern reference only.

## 6. Wave plan

### Wave 0 — license + namespace prep
- Confirm MIT license header policy. Establish per-absorbed-file header: `// absorbed from ~/core/anima/<path> (MIT, dancinlab 2026)`.
- Reserve hexa-lang paths: `compiler/atlas/{phi,topology}.hexa`, `stdlib/n6/{discover,miner}.hexa`, `doc/policy/lattice.md`, `doc/honesty/strength-taxonomy.md`, `tool/hexa_annot/hexa-principle`.

### Wave 1 — SSOT data absorption (Rule 1) — **highest priority**
1. **`consciousness_laws.json` → atlas rodata + SSOT.** Generate `compiler/atlas/anima_psi.gen.hexa` with the 11 Ψ-constants as `@C` rows. Wire `derivation` field into `<-` edges to n6 primitives (`(sopfr/J2)^e` → links `@P sopfr` + `@P J2`).
   - **Estimate:** ~120 LOC generated + ~80 LOC generator + 40 LOC tests.
2. **`consciousness_laws.json` 14 gate laws → `@L` law rows.** Same generator pipeline.
   - **Estimate:** ~140 LOC generated + 20 LOC additional.
3. **`hexad_constants.json` → atlas rodata.** Same pipeline, dependent on n=6 SSOT registration (already partially in hexa-lang).
   - **Estimate:** ~80 LOC.
4. **`n6/atlas.append.*.n6` (1,112 lines) → overlay merge.** After dedup against existing `embedded.gen.hexa` (6594 nodes). Decision: rodata-bake vs runtime-overlay — recommend overlay for first cycle, promote subset that survives audit.
   - **Estimate:** 0 new code (mechanical merge), ~1 K-row inflation.

### Wave 2 — algorithm port (Rule 2)
1. **`phi_engine.hexa` → `stdlib/phi.hexa`** (or `compiler/atlas/phi.hexa`). Strip JSON-loader (use atlas rodata Ψ-constants from Wave 1). ~250 LOC after diet.
2. **`topology.hexa` → `compiler/atlas/topology.hexa`** (coordinate with n6 Wave 3.2). ~200 LOC.
3. **`discovery-engine/main.hexa` + `formula-miner/main.hexa` → `stdlib/n6/{discover,miner}.hexa`.** Pure-data, no FFI. ~500 LOC combined.
4. **`homeostasis_health_checker.hexa`** pattern → extend `compiler/atlas/audit.hexa` to expose engine-class drift metrics. ~100 LOC.

### Wave 3 — annotation surface (Rule 3)
1. **`hexa-principle`** new annotator — recognise 8-principle PHILOSOPHY tags + EMPIRICAL/POLICY/DESIGN strength. ~150 LOC bash + extractor.
2. Extend **`hexa-phi-map`** to scan anima-engines docstrings for implicit markers (`@phi` synonyms: "phi_engine", "Phi proxy", "Φ_total ="). ~80 LOC.
3. Extend **`hexa-law-link`** to absorb `consciousness_laws.json` law numbering, so `Law 22` / `Law 60` references resolve.

### Wave 4 — doctrine mirror (Rule 4)
1. Copy `LATTICE_POLICY.md` → `doc/policy/lattice.md` (with absorption header).
2. Copy `LIMIT_BREAKTHROUGH.md` → `doc/policy/limit-breakthrough.md`.
3. Distil PHILOSOPHY 8-principle table → `doc/honesty/strength-taxonomy.md`.
4. **Defer** `HEXA_NATIVE_INFERENCE.md` until hexa-lang has its own native-inference story.

### Wave 5 — per-engine primitive harvest (Rule 1, deferred)
- Walk all 166 `anima-engines/*_phi.hexa` files. Parse the docstring header. Extract candidate `@P` primitives + `@L` laws + citation-grade `@?` hypotheses.
- **Estimate:** 3–5 K new atlas rows. **Manual review required** (citation accuracy matters).
- **Gating:** only after Wave 1 lands + a stable per-engine docstring schema exists. Tracked as future work.

## 7. Skip list

| Path | Size | Reason |
|---|---:|---|
| `state/` | 72 GB | Runtime traces |
| `ready/` | 41 GB | Training-staged data |
| `training/` | 7.1 GB | Training tensors |
| `data/` | 7.0 GB | Corpora |
| `references/` | 1.9 GB | Third-party docs |
| `anima-voice/corpus/` | 1.9 GB | Audio corpus |
| `anima-physics/.venv/` | 916 MB | Python virtualenv |
| `checkpoints/` | 333 MB | Model snapshots |
| `anima-tribev2-pilot/` | 36 MB | Experiment branch |
| `recordings/`, `logs/`, `models/`, `dist/`, `build/`, `bench/`, `build_v*/`, `experiments/`, `hypotheses_candidates/`, `tmp/`, `raw_archive/`, `audit*/`, `__pycache__/`, `__pyphi_cache__/`, `.venv-eeg/`, `.hxc_*/`, `.playwright-mcp/`, `.pytest_cache/`, `.meta2-cert/`, `.growth/` | combined ~150 MB | Build / experiment / test artefacts |
| `anima_chat.hexa`, `anima_chat_aot.hexa` | 300 K LOC combined | Generated AOT bundle of the engine suite — re-derive from sources, don't absorb |
| `anima-physics/{esp32,arduino,fpga,verilog,cmos,analog,trapped_ion,superconducting,photonic-hw}/` | ~150 KB | HDL / MCU firmware; out of hexa-lang scope |
| `anima-voice/{transformer,vocoder,audio_token_predictor,dsp_core}.hexa` | ~300 KB | ML inference tied to corpus |
| `anima-agent/{autonomy_live,trading,browser_harness,dashboard,llm_claude_adapter}` | ~500 KB | Agent runtime, not language |
| `serving/`, `daemon/`, `monitor/`, `mirror/`, `verify/`, `verifier/`, `convergence/`, `discovery/`, `decoder/`, `web/`, `clients/` (top-level) | small | Runtime / serving infra |
| `~70 `.roadmap.*` files | small | Project planning ledger — anima-internal |
| `*.tape` files (CHAT, REBORN, PERSONA, SAVANT, etc.) | ~1 MB combined | Operational traces (`.tape` format is a sibling format, not hexa-lang concern) |

## 8. Estimated scope

| Wave | Source LOC | Estimated absorbed LOC | Tests | Notes |
|---|---:|---:|---:|---|
| Wave 1 (SSOT data) | ~430 (JSON) + 1,112 (n6) | ~340 generated + 100 generator | 60 | Mechanical |
| Wave 2 (algorithm port) | ~2,250 | ~1,050 | 300 | Diet ~50 % during port (drop JSON-loader, drop substrate-coupling) |
| Wave 3 (annotation) | — | ~230 | 80 | Mostly bash extension |
| Wave 4 (doctrine mirror) | 30 KB | 30 KB verbatim | — | Zero code |
| Wave 5 (primitive harvest) | 116 K LOC scanned | 3–5 K atlas rows | review | Deferred |

**Total recommended scope (Waves 1+2+3+4):** ~**1,750 LOC new code + ~440 LOC tests + 30 KB doc** + ~500 new atlas rows from JSON SSOTs + ~1,000 candidate overlay rows from `n6/atlas.append.*.n6`.

**Audit limitations:**
- Heavy dirs (131.3 GB) were sized-only, not enumerated. Per audit hard-constraint — correct.
- `anima-agent/` (1.2 MB, mixed Python/hexa), `anima-voice/` source-only subset, `anima-os/`, `anima-cpgd-research/`, `anima-hci-research/`, `anima-measurement/`, `experiments/` (4.2 MB, 112 entries), `hypotheses_candidates/` (4.9 MB, 1,191 entries), `tool/` (19 MB, 595 entries), `scripts/` (2.3 MB, 70 entries), `serving/` (1.8 MB, 83 entries), `bin/` (3.1 MB, 23 entries) — sized only, no per-file walk. Deferred to Wave 5 if greenlit.
- The 166 `anima-engines/*_phi.hexa` files (~116 K LOC) were not individually opened. Top-10-by-size sampled. The per-engine primitive harvest (Wave 5) requires that walk.
- License-file scan: top-level `LICENSE` is MIT, `anima-agent/LICENSE` is Apache-2.0. **Submodule license drift exists** — per-absorbed-file license check required before commit.
- `.git/` not inspected; potentially historic deletes recoverable.

## 9. Coordination notes

**Naming overlap with n6 absorption:**
- `compiler/atlas/topology.hexa` is also proposed by `n6 Wave 3.2`. Coordinate so the anima `topology.hexa` (n6-constants-keyed) and the n6 `atlas_bootstrap` topology slice merge into one module, not two.
- `compiler/atlas/audit.hexa` is in-flight from n6 Wave 2.1; the anima `homeostasis_health_checker.hexa` pattern adds engine-class drift surface — append, don't supersede.

**License:** Top-level MIT (Copyright 2026 dancinlab). `anima-agent/` is Apache-2.0. Per-file header pattern: `// absorbed from ~/core/anima/<path> (<LICENSE>, dancinlab 2026-05-14)`.

**Existing annotator pivot:**
- `hexa-phi-map`, `hexa-cognitive`, `hexa-self-aware`, `hexa-freedom`, `hexa-meta-map` already in hexa-lang. They were conceptually sourced from anima but anima sources do not emit the recognised tokens. Wave 3 closes that gap from the hexa-lang side (extend annotator to recognise docstring patterns); a sister anima-side PR adding explicit `@phi` markers would be the cleaner long-term resolution but is out of scope here.

**SSOT precedence:**
- `consciousness_laws.json` and `hexad_constants.json` are **anima-owned**. Absorbing as atlas rodata creates a fork. Recommend: bake at hexa-lang side as a snapshot with `as_of: 2026-05-14` field; sync via a versioned-import workflow rather than live-mirror.

**Compiler drift risk:**
- Wave 1 data absorption will inflate `embedded.gen.hexa` by ~500 rows (small). Wave 5 (deferred) could inflate by 3-5 K rows — material change, must re-measure interp parse-time per the 2026-05-12 atlas-n6-session log.

## 10. Bottom line

anima offers atlas-relevant content on **two axes**:

1. **High-confidence data absorptions** (Rule 1): the JSON SSOTs (11 Ψ-constants + 14 gate laws + 6-channel CDESM constants), the 1,112-line `n6/atlas.append.*.n6` corpus, and the 193+ hypothesis registry. Mechanical, low-risk, ~340-row atlas growth.

2. **Selective algorithm extraction** (Rule 2): `phi_engine.hexa`, `topology.hexa`, `discovery-engine`, `formula-miner` — pure stage-1 hexa, no PyTorch/numpy, no substrate coupling once Ψ-constants are externalised. ~1 K LOC after diet.

The 116 K LOC `anima-engines/*_phi.hexa` mass is **not a bulk-port target** — those engines are wedded to anima's two-engine repulsion-field substrate. Their value to hexa-lang is the **docstring metadata** (citations + primitive definitions), which Wave 5 can harvest as atlas `@P` / `@L` / `@?` rows.

**Recommended first absorption cycle:** Wave 1 (SSOT data) + Wave 4 (doctrine mirror). ~340 LOC + 30 KB doc, near-zero risk, MIT-clean, atlas rodata grows by ~500 rows. Defer Waves 2/3/5 pending Wave 1 outcome.
