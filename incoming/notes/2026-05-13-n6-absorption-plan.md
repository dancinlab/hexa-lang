# n6 → hexa-lang absorption plan (research only)

**Date:** 2026-05-13
**Source repo:** `~/core/n6/` (NEXUS-6 Knowledge Atlas grammar v1, CC0-1.0)
**Target repo:** `~/core/hexa-lang/`
**Status:** RESEARCH — no code modified. Implementation gated on user approval.

## 0. TL;DR

- hexa-lang has already absorbed the `.n6` **rodata corpus** (6201 C + 567 P + 620 L + 10 E nodes, sha256 `663698a0…`, `ATLAS_SOURCE_COUNT = 410`, generated 2026-05-12T06:00:19Z) into `compiler/atlas/embedded.gen.hexa` plus a minimal P/C/L/E parser + first-wins merger + runtime overlay.
- hexa-lang has **not** absorbed the n6 **grammar** (F/R/S/X/?/section-markers/grade-markers/edge operators are dropped on parse), the **TextMate syntax**, the **examples**, the **omega-closure doc**, or any of the **12 operational algorithms** (bloom, query, health, mmap, hot_shard, predict_cache, bootstrap, deg_rebuild, scan_opt, map_export, health_export, absorb).
- The n6 algorithms are mostly **shell-orchestrators** (awk/stat/chflags wrappers, /tmp state) — porting verbatim would import an external-process posture that conflicts with hexa-lang's pure-stdlib direction. Several algorithms (bloom, mmap, hot_shard, predict_cache) are **performance optimizations against on-disk atlas.n6**; hexa-lang loads atlas as rodata so they have no analog need.
- High-value absorptions: (1) extend `compiler/atlas/parser.hexa` to surface F/R/S/X/? as first-class kinds (currently dropped); (2) port `atlas_health.hexa` as a pure-hexa overlay+rodata audit (most useful for `hexa atlas stats`); (3) port the TextMate grammar as a static asset for editor integrations.
- License: CC0-1.0 — no attribution / dual-license friction.

## 1. Inventory

Audited files under `~/core/n6/` (28 files, ~6.3K LOC total):

| File | Type | LOC | One-line purpose |
|---|---|---:|---|
| `README.md` | doc | 132 | Identity + 9 type alphabet + omega-closure summary |
| `AGENTS.md` | doc | 0 | Empty placeholder (CLAUDE.md is a symlink) |
| `LICENSE` | doc | 121 | CC0-1.0 public-domain dedication |
| `spec/n6.md` | spec | 162 | Canonical v1 grammar (header, type alphabet, grade alphabet, edge ops, streaming invariants, omega closure) |
| `syntaxes/n6.tmLanguage.json` | grammar | 106 | TextMate token rules for `.n6` |
| `syntaxes/README.md` | doc | 55 | VS Code / Sublime install guide |
| `algorithms/README.md` | doc | 38 | Catalog of 12 modules |
| `algorithms/atlas_absorb.hexa` | algo | 192 | Guarded unlock-append-relock cycle for chflags-locked atlas.n6 |
| `algorithms/atlas_bloom.hexa` | algo | 741 | Domain-prefix bloom filter (111K bits, 7-hash) for O(1) miss-reject |
| `algorithms/atlas_bootstrap.hexa` | algo | 893 | Topology self-analysis → sparse-region detection → candidate generation |
| `algorithms/atlas_deg_rebuild.hexa` | algo | 167 | mtime-based degree-sidecar (`atlas.n6.deg`) rebuilder |
| `algorithms/atlas_health.hexa` | algo | 443 | Orphan-refs / dup / malformed / grade-dist audit (read-only) |
| `algorithms/atlas_health_export.hexa` | algo | 180 | JSON export of health metrics for dashboards |
| `algorithms/atlas_hot_shard.hexa` | algo | 682 | Access-heatmap → top-K RAM promotion (process-local) |
| `algorithms/atlas_map_export.hexa` | algo | 53 | atlas → docs JSON exporter (currently `panic` stub — Python delegation blocked) |
| `algorithms/atlas_mmap.hexa` | algo | 262 | Page-cache friendly awk/dd streaming (avoids in-heap split) |
| `algorithms/atlas_predict_cache.hexa` | algo | 836 | 1st-order Markov bucket-prefetch with self-disable below 20% hit |
| `algorithms/atlas_query.hexa` | algo | 314 | 3-stage prefix query: bloom → predict-warm → cold-awk |
| `algorithms/atlas_scan_opt.hexa` | algo | 453 | Domain-prefix bucket index (line indices, /tmp JSON persist) |
| `examples/01_primitives.n6` | example | 31 | `@P` entries with `<-` `->` `==` `\|>` edges + section dividers |
| `examples/02_relations.n6` | example | 46 | `@C` `@F` `@R` `@L` mix — constants, formulas, relations, qualitative laws |
| `examples/03_crossings.n6` | example | 49 | `@X` crossings + `@?` hypotheses + `~>` convergence + `!!` breakthrough + `@S` |
| `examples/README.md` | doc | 32 | Example index + grep cookbook |
| `docs/INDEX.md` | doc | 43 | Doc index |
| `docs/omega_closure.md` | doc | 106 | Abstraction-exhaustion target spec (a)+(b)+(c)+(d) ceiling |
| `scripts/render_preview.mjs` | tool | 63 | shiki-based HTML preview generator (Node.js) |
| `scripts/render_svg.mjs` | tool | 102 | shiki-based theme-aware SVG generator (Node.js) |
| `scripts/README.md` | doc | 27 | Script regen instructions |
| `tool/README.md` | doc | 12 | Planned (not-yet-implemented) lint/pilot/omega-audit dispatchers |

**Total:** 28 files, 6,259 LOC (n6 algorithms = ~5,225 LOC of which ~5,170 LOC is hexa-lang source).

## 2. Grammar comparison

n6 spec defines **9 entry types** (`@P @C @L @F @R @S @X @? @E`) plus **7 edge operators** (`<-` `->` `=>` `==` `~>` `\|>` `!!`).

hexa-lang's `compiler/atlas/parser.hexa` recognizes header sigils for **all** 9 types (per `_is_header_sigil`) but **only emits AtlasNodes** for the 4 kinds the S1 resolve pass needs: `P / C / L / E`. The other 5 types (`F / R / S / X / ?`) and section markers (`@END @shard @META @D @H @M @T @N`) are parsed for **termination correctness** but **silently dropped**.

Edge continuation lines (`<-` `->` etc.) are not parsed structurally — they are simply concatenated into `AtlasNode.raw`. The grade marker (`[N*]` / `[N!]` / `[N?]` / `[d.r]`) and `:: domain` tag are likewise unstructured tail text inside `raw`.

### Per-type coverage

| n6 type | grade-marker semantics | hexa-lang status | gap |
|---|---|---|---|
| `@P` primitive | irreducible foundational value | covered (`ATLAS_P_NODES`, 567 nodes) | edges + grade unparsed (lives in `.raw` only) |
| `@C` constant | computed from primitives | covered (`ATLAS_C_NODES`, 6201 nodes) | as above |
| `@L` law | qualitative invariant | covered (`ATLAS_L_NODES`, 620 nodes) | as above |
| `@F` formula | explicit functional form | **dropped at parse** | header sigil recognized for termination but kind="" → not emitted |
| `@R` relation | equality / structural identity | **dropped at parse** | same |
| `@S` symmetry | topological / group-theoretic | **dropped at parse** | same |
| `@X` crossing | bridge between domains | **dropped at parse** | same |
| `@?` open hypothesis | falsifier-blocked | **dropped at parse** | same |
| `@E` edge / cross-engine bus | live-system bridge | covered (`ATLAS_E_NODES`, 10 nodes) | n6 spec calls this "experiment"; hexa-lang treats it as the cross-engine edge — semantic drift, see §8 |

**Coverage:** 4 / 9 types emit nodes; 5 / 9 types are parse-terminated but discarded.

### Edge operators (provenance)

| Operator | Name | hexa-lang status |
|---|---|---|
| `<-` | depends_on | concatenated into `.raw`, not structured |
| `->` | derives | as above |
| `=>` | application (prose) | as above |
| `==` | equivalent (symbolic) | as above |
| `~>` | converges_to (numeric) | as above |
| `\|>` | verified_by (script ref) | as above |
| `!!` | breakthrough (citation) | as above |

**Gap:** **all 7 provenance edges are unstructured.** Queries like "what derives X" or "show me every `[10!]` breakthrough" require regex against `.raw`, not field access. The existing parser only sets `kind / id / raw / source_file / source_line`.

### Grade markers

n6 specifies `[N]` / `[N*]` / `[N!]` / `[N?]` / `[10*!]` / `[11*]` / `[d.r]` (alien-index). hexa-lang **does not parse the grade** — the trailing `[...]` lives inside `.raw` as text. There is no `AtlasNode.grade` field, no `verified` boolean, no breakthrough flag.

## 3. Algorithm comparison

| Algorithm | n6 LOC | hexa-lang equivalent | classification | priority |
|---|---:|---|---|---|
| `atlas_absorb.hexa` | 192 | `compiler/atlas/overlay.hexa::overlay_append_lines` (logical equivalent: append-only flush; n6 version adds chflags/archive/idempotency) | **partial** | medium — overlay covers the runtime case; n6 staging-flush patterns are interesting for CI bulk imports |
| `atlas_bloom.hexa` | 741 | (none) | **new** | low — hexa-lang loads atlas as rodata; bloom filter targets disk-backed atlas.n6 |
| `atlas_bootstrap.hexa` | 893 | (none — partial overlap with `compiler/discover/`) | **partial** | low-medium — topology self-analysis is interesting; `compiler/discover/` already covers @discover annotation flow |
| `atlas_deg_rebuild.hexa` | 167 | (none) | **new** | low — edge sidecar regen; only relevant if we ever derive degree stats from atlas |
| `atlas_health.hexa` | 443 | (none) | **new** | **high** — orphan/dup/malformed audit + grade distribution is exactly the surface `hexa atlas stats` should expose against rodata + overlay |
| `atlas_health_export.hexa` | 180 | (none) | **new** | medium — JSON dump for CI dashboards; trivial atop a ported `atlas_health` |
| `atlas_hot_shard.hexa` | 682 | (none) | **new** | skip — process-local RAM cache for disk-backed atlas; rodata already in RAM |
| `atlas_map_export.hexa` | 53 | (none) | **new** | skip — n6 version is a `panic` stub blocked on Python delegation |
| `atlas_mmap.hexa` | 262 | (none) | **new** | skip — same reason as hot_shard; mitigates problem hexa-lang doesn't have |
| `atlas_predict_cache.hexa` | 836 | (none) | **new** | skip — Markov prefetch only helps disk-backed access patterns |
| `atlas_query.hexa` | 314 | `compiler/atlas/static_index.hexa::atlas_lookup_merged` | **covered** | low — n6 surface is prefix-range; hexa-lang surface is id-equality. n6's prefix layer would be a feature add (see §7 Wave 3) but not a port |
| `atlas_scan_opt.hexa` | 453 | (none — `lookup` in `merger.hexa` is linear scan) | **partial** | low — prefix bucket index; rodata is small enough that linear scan is fine. Would matter only at 10× corpus size |

### Per-algorithm absorption strategy

**`atlas_absorb.hexa`** (192 LOC)
- Header: "atlas auto-absorption module — centralized unlock-append-relock cycle for chflags-locked atlas.n6".
- Surface: `run_absorb()` — `chflags nouchg <atlas>` → append shard files with `# .. <basename> ..` separators → optional archive to `_absorbed/<ts>/` → `chflags uchg <atlas>`.
- Dependencies: `exec()` (chflags / cat / wc / date / mkdir / mv), darwin-only chflags path (Linux falls through with explicit message).
- Strategy: **port-with-adapt**. The chflags machinery is darwin-specific and doesn't apply to hexa-lang's `~/.hx/data/atlas.overlay.n6` model. The valuable idea is **idempotent staging-shard flush with separator markers** — already partially covered by `overlay_append_lines`. Adapt only if we add a `tool/atlas_bulk_absorb.hexa` for CI bulk imports from a staging directory.

**`atlas_bloom.hexa`** (741 LOC)
- Header: "domain-prefix bloom filter (111K bits, 7 hash) for O(1) miss-reject ahead of bucket index".
- Surface: `build` / `check` / `verify` / `stats`. Hexa-lang lacks bitops (XOR/AND missing) → hashing/bitmap built externally via awk; hexa side reads binary + meta JSON.
- Dependencies: awk, xxd, stat. Binary sidecar at `/tmp/atlas_bloom.bin`.
- Strategy: **skip**. The bloom filter exists to avoid reading a 1.5 MB atlas.n6 file from disk on cold-CLI invocation. hexa-lang has the atlas as compile-time rodata — the bloom layer protects against a problem we don't have. Revisit only if overlay grows past ~10K nodes AND lookup latency becomes measurable.

**`atlas_bootstrap.hexa`** (893 LOC)
- Header: "ATLAS-P9-1 Mk.III self-bootstrap engine — topology self-analysis → sparse region detection → candidate generation → guarded append → stats update".
- Surface: `scan / bootstrap / hubs / status / growth-points / recommend`.
- Dependencies: hard-coded `_NEXUS = $HOME/Dev/nexus`; degree sidecar (`atlas.n6.deg`), stats sidecar (`atlas.n6.stats`).
- Strategy: **partial — extract pieces**. The "scan sparse regions / recommend leaf edges" surface partially overlaps with `compiler/discover/` (already in hexa-lang). The degree-centrality hub classifier is unique and could land as `compiler/atlas/topology.hexa` — but only after the parser emits structured edges (§7 Wave 1). Without edges, "degree" is unparseable. **Gate this on Wave 1.**

**`atlas_deg_rebuild.hexa`** (167 LOC)
- Header: "atlas.n6.deg mtime-based auto-rebuild — degree sidecar regen".
- Surface: `--check` (stale-only exit code) / `--rebuild` (default).
- Strategy: **skip for now**. Tied to atlas_bootstrap; sidecar pattern doesn't apply to rodata embed. If bootstrap is ported, derive degree at embed time inside `tool/atlas_embed_gen.hexa`.

**`atlas_health.hexa`** (443 LOC)
- Header: "atlas.n6 무결성 헬스체크 — orphan refs / 중복 / 깨진 라인 / grade 분포 감지 (readonly)".
- Surface: positional `[path] [--verbose] [--lock]` → prints entry count, grade distribution, dedup, type histogram, orphan-ref count.
- Dependencies: stat (BSD+GNU), grep/awk for type counts, sidecar `atlas.n6.stats` for mtime-cache.
- Strategy: **port-with-adapt — high priority**. The natural target is `compiler/atlas/audit.hexa` exposing `audit_rodata() / audit_overlay() / audit_merged()` returning a struct with `{entry_count, p/c/l/e/f/r/s/x/?_count, grade_histogram, dup_count, orphan_refs, malformed_lines}`. The `--lock` / mtime-cache pieces are darwin-FS specific and drop. Wire to `hexa atlas stats` via `tool/atlas_cli.hexa`.

**`atlas_health_export.hexa`** (180 LOC)
- Header: "JSON export of health metrics for dashboards".
- Strategy: **port — trivial atop atlas_health**. Add `--format=json` flag to the ported audit module.

**`atlas_hot_shard.hexa`** (682 LOC)
- **Skip.** Process-local RAM promote for disk-backed atlas. Hexa-lang has the rodata in process memory already.

**`atlas_map_export.hexa`** (53 LOC)
- **Skip.** Source is a `panic()` stub blocked on Python delegation.

**`atlas_mmap.hexa`** (262 LOC)
- **Skip.** Awk/dd streaming wrapper for disk-backed atlas — irrelevant to rodata.

**`atlas_predict_cache.hexa`** (836 LOC)
- **Skip.** Markov prefetch only buys latency on disk-backed cold-CLI; rodata is in-RAM.

**`atlas_query.hexa`** (314 LOC)
- Header: "unified atlas prefix-query wrapper — bloom → predict → cold-mmap 3-stage".
- Strategy: **covered for id-equality**. hexa-lang `atlas_lookup_merged` is the equivalent for exact-id lookup. The **prefix-range** surface (e.g. `query math_`) is a feature gap that could land as `atlas_prefix(prefix) -> [AtlasNode]` against the in-memory arrays. Useful enough to add (low-effort) but not blocking.

**`atlas_scan_opt.hexa`** (453 LOC)
- Header: "domain-prefix bucket index — O(N) → O(1+k)".
- Strategy: **partial — useful as in-memory layer**. The bucket index could be built once at static-init by grouping `ATLAS_*_NODES` by domain prefix. If we add prefix queries (above), this is the natural index. ~50 LOC port (ignore the JSON-persist machinery — we live in-memory).

## 4. Syntax integration

**Current state:** hexa-lang has no `.n6` syntax surface. The LSP (`self/lsp.hexa`) tokenizes hexa source, not `.n6`. The parser (`compiler/atlas/parser.hexa`) does its own line-oriented tokenization for the 4 emitted kinds.

**n6 ships** `syntaxes/n6.tmLanguage.json` — 106-line TextMate grammar with scopes for entry-header, edge-line, grade markers, section dividers, prose strings. Used by shiki (Node.js scripts) to generate the README's SVG previews.

**Options:**
1. **Bundle as static asset** under `compiler/atlas/n6.tmLanguage.json`. Pros: editor integrations (VS Code extension publishing) can reference it. Cons: doesn't help the hexa-lang LSP itself (which doesn't serve `.n6`).
2. **Add `.n6` recognition to hexa-lang LSP**. Larger lift — `self/lsp.hexa` would need a multi-language dispatch, and we'd need an actual structured n6 lexer (the TextMate file is regex-only, not enough for diagnostics). Defer unless we publish a VS Code extension.
3. **Skip — n6 has its own editor support**. Recommended for now.

**Recommendation:** option 3 (skip) until there's a concrete VS Code extension target. Revisit when publishing.

## 5. Examples as test fixtures

n6 ships 3 minimal examples (`01_primitives.n6` / `02_relations.n6` / `03_crossings.n6`, 31+46+49 LOC). They exercise every type (P/C/L/F/R/S/X/?) and every edge (`<-` `->` `=>` `==` `~>` `\|>` `!!`).

These are **ideal parser regression fixtures**. Proposed location: `test/fixtures/n6/`. Each example loads via `parse_atlas_file()` and the test asserts:
- header count (Wave-1-dependent — currently only P/C/L/E are counted)
- post-Wave-1: structured edge surfaces (`node.edges_depend_on`, `.edges_derives`, etc.)
- post-Wave-1: parsed grade marker (`node.grade_value: i64`, `.grade_verified: bool`, `.grade_breakthrough: bool`, `.grade_hypothesis: bool`)

CC0-1.0 licensing makes verbatim copy frictionless. Add a header comment pointing to upstream provenance per `incoming/notes/2026-05-12-atlas-n6-absorption-session.md` precedent.

## 6. Docs to consider

**`docs/omega_closure.md`** (106 LOC) — defines "abstraction-exhaustion" as the conjunction of (a) all-`[10*]+`, (b) `@?=0`, (c) all-`@X`-verified, (d) composite≥0.9. References a 2026-04-25 reference-corpus snapshot (66.2% at `[10*]+`, gap 0.066 to 0.9 target).

This is doctrine-adjacent — it tells the hexa-lang atlas roadmap what "done" looks like for the embedded corpus. Worth **mirroring** into `doc/atlas/omega_closure.md` (verbatim copy + light header preface "absorbed from n6 on 2026-05-13"). Even if hexa-lang doesn't track composite metrics, sub-conditions (a) and (b) are testable today via the audit module (Wave 2). No code dependency.

**`docs/INDEX.md`** (43 LOC) — already covered by hexa-lang's own doc index. Skip.

## 7. Absorption plan (waves)

### Wave 1 — grammar parser extension (foundation, blocking for any structured query work)

Extend `compiler/atlas/parser.hexa` to (a) emit nodes for `@F / @R / @S / @X / @?` and (b) parse the grade marker + edge continuation lines into structured fields.

**Files affected:**
- `compiler/atlas/parser.hexa` — add F/R/S/X/?/@ to `_kind_of`; add `parse_grade(marker) -> (value, verified, breakthrough, hypothesis)`; add `parse_edge_lines(raw) -> {depends_on, derives, applications, equivalents, converges, verified_by, breakthroughs}`. Extend `AtlasNode` struct with new fields (or introduce `AtlasNodeFull` to preserve binary compatibility).
- `compiler/atlas/merger.hexa::AtlasIndex` — add `f_nodes / r_nodes / s_nodes / x_nodes / q_nodes` per-kind arrays.
- `compiler/atlas/embed.hexa` — emit the new arrays in `embedded.gen.hexa`.
- `tool/atlas_embed_gen.hexa` — print new per-kind counts in the summary.
- Regenerate `compiler/atlas/embedded.gen.hexa` against the live n6 corpus (this will inflate from ~7.4K nodes total to ~10K+ given the 9624-entry reference corpus). File size today: 3.27 MB → expect ~4-5 MB.

**Estimated LOC:** parser +150, merger +80, embed +60, drift in `embedded.gen.hexa` is generated. Tests +200.

**Risk:**
- `embedded.gen.hexa` expansion: 7.4K → ~10K nodes increases interp startup parse time. The existing `@phase("parse_only")` annotation should still amortize, but worth measuring.
- AtlasNode field additions ripple to every consumer (currently 4: `parser`, `merger`, `static_index`, `overlay`). Doable but requires careful staging — consider parallel `AtlasNodeFull` until consumers migrate.

### Wave 2 — algorithm absorption (priority high, depends on Wave 1)

**2.1 — `atlas_health` port → `compiler/atlas/audit.hexa`**
- Source: `~/core/n6/algorithms/atlas_health.hexa` (443 LOC).
- Target: `compiler/atlas/audit.hexa` (~250 LOC after dropping mtime-cache + chflags-lock + shell-out paths).
- Surface: `audit_rodata() / audit_overlay() / audit_merged() -> AuditReport { entry_count, kind_counts, grade_histogram, dup_count, orphan_refs, malformed_lines, breakthrough_count }`.
- Wire to: `tool/atlas_cli.hexa` (`hexa atlas stats`).

**2.2 — `atlas_health_export` port → JSON output flag on `audit`**
- Source: `~/core/n6/algorithms/atlas_health_export.hexa` (180 LOC).
- Target: extension to `compiler/atlas/audit.hexa` (~80 LOC) — `audit_to_json(report) -> string`.
- Wire to: `hexa atlas stats --format=json`.

**2.3 — `atlas_query` prefix surface → `atlas_prefix` in `static_index.hexa`**
- Source: lightweight derivation of `~/core/n6/algorithms/atlas_query.hexa` (314 LOC) — drop bloom + predict + cold-mmap stages; keep the prefix-match contract.
- Target: ~40 LOC addition to `compiler/atlas/static_index.hexa` — `atlas_prefix(prefix: string) -> [AtlasNode]`.
- Wire to: `hexa atlas lookup --prefix=<prefix>`.

**2.4 — `atlas_scan_opt` in-memory bucket index → `compiler/atlas/prefix_index.hexa`**
- Source: bucket-index core of `~/core/n6/algorithms/atlas_scan_opt.hexa` (453 LOC); drop JSON-persist + mtime-staleness + stats logic.
- Target: ~60 LOC in `compiler/atlas/prefix_index.hexa` — `build_prefix_index(idx: AtlasIndex) -> map<string, [i64]>` (line-index lists per domain prefix).
- Optional — only land if `atlas_prefix` measurement shows linear-scan latency matters.

**Wave 2 LOC estimate:** ~430 new LOC + ~200 LOC of tests.

### Wave 3 — algorithm absorption (priority medium)

**3.1 — `atlas_absorb` adaptation → `tool/atlas_bulk_absorb.hexa`**
- Source: `~/core/n6/algorithms/atlas_absorb.hexa` (192 LOC).
- Target: ~120 LOC; drop chflags machinery, keep staging-shard discovery + idempotent flush + separator markers. Calls into `overlay_append_lines`.
- Use case: CI bulk-import of community-contributed `.n6` shards.

**3.2 — `atlas_bootstrap` topology pieces → `compiler/atlas/topology.hexa`**
- Source: degree-centrality + hub-classifier slices of `~/core/n6/algorithms/atlas_bootstrap.hexa` (893 LOC).
- Target: ~200 LOC after stripping CLI / sidecar I/O / nexus-specific paths.
- **Depends on Wave 1** (needs structured edges to compute degree).

### Wave 4 — syntax + examples + docs

**4.1 — Examples as test fixtures**
- Copy `~/core/n6/examples/{01,02,03}.n6` → `test/fixtures/n6/`.
- Add parser regression test asserting type counts + grade distribution.
- ~80 LOC test driver.

**4.2 — Bundle TextMate grammar as static asset** (optional)
- Copy `~/core/n6/syntaxes/n6.tmLanguage.json` → `compiler/atlas/n6.tmLanguage.json`.
- ~0 LOC code change; only relevant if hexa-lang ships an editor extension.

**4.3 — Mirror omega-closure doc**
- Copy `~/core/n6/docs/omega_closure.md` → `doc/atlas/omega_closure.md`.
- Add header preface noting absorption date + upstream provenance.

### Skip list

| Item | Reason |
|---|---|
| `atlas_bloom.hexa` | Optimizes disk-backed atlas; hexa-lang loads as rodata |
| `atlas_mmap.hexa` | Same — page-cache wrapper for problem we don't have |
| `atlas_hot_shard.hexa` | Process-local RAM promote — rodata is already in RAM |
| `atlas_predict_cache.hexa` | Markov prefetch — irrelevant for in-memory atlas |
| `atlas_map_export.hexa` | Source is a `panic` stub (Python delegation blocked) |
| `atlas_deg_rebuild.hexa` | Sidecar regen — derive at embed time if topology lands |
| `scripts/render_*.mjs` | Node.js preview generators for n6's own README; not a hexa-lang concern |
| `tool/` placeholders | Empty — n6's planned lint/pilot doesn't exist yet upstream |

## 8. Coordination notes

**License:** CC0-1.0 — full public domain. Copy verbatim, no attribution friction. Recommend a one-line header comment on absorbed files: `// absorbed from ~/core/n6/<path> (CC0-1.0)`.

**Sister projects:**
- `hxc` (byte-canonical wire/storage) — separate absorption decision. n6 README references it but no code dependency.
- `n12` (12-axis sparse cube) — listed as private. No public dependency to absorb today.

**Naming drift — `@E` semantic:**
- n6 spec §Type alphabet: `@E` = "Experiment — empirical measurement record" (7 / 9624 in corpus).
- hexa-lang `compiler/atlas/parser.hexa` line 23: `@E (cross-engine bus / bridge)`.

These are **incompatible semantics**. The hexa-lang rodata corpus has 10 `@E` nodes; verify they match either definition. Recommend documenting the drift in `compiler/atlas/parser.hexa` and explicitly aligning with n6 spec **or** introducing a separate `@B` kind for bridges. Resolution required before Wave 1 ships.

**Prior absorption work (no double-port):**
- `compiler/falsifiers/`, `compiler/hexad/`, `compiler/honesty/`, `compiler/lens_taxonomy/` — sourced from `~/core/nexus/` (not n6). No overlap.
- `compiler/discover/` — sourced from hexa-lang's own RFC-017 / @discover annotation; overlaps **conceptually** with `atlas_bootstrap.hexa::recommend` but not in source. Wave 3.2 should cross-reference.
- `incoming/notes/2026-05-12-atlas-n6-absorption-session.md` — prior absorption of the corpus itself (rodata). This plan continues from there.

**Compiler interp drift risk:**
- The 2026-05-12 session log records that regenerating `embedded.gen.hexa` required `LC_ALL=C` + a `stat -f %z → stat --printf '%s'` shim on Linux. Wave 1 will trigger another regen — bundle these workarounds in the driver before scheduling.

## 9. Bottom line

The 12 n6 algorithms represent ~5,170 LOC of operational hexa code, of which ~6 modules (3,569 LOC) target performance problems hexa-lang doesn't have (disk-backed atlas access). The high-value surface is:

1. **Grammar coverage** — parser dropping 5/9 types is the single largest gap and blocks every structured query downstream.
2. **`atlas_health` port** — closest fit to user-facing `hexa atlas stats`.
3. **Examples as fixtures** — cheap, exercises grammar coverage gains.

Total new-code estimate for the recommended scope (Waves 1+2+4.1+4.3, excluding optional Wave 3 and Wave 4.2): **~870 LOC source + ~480 LOC tests** plus a one-time `embedded.gen.hexa` regen.
