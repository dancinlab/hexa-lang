# 2026-05-13 — Data-embed Wave 1 absorption session (D1-D9)

Phase 1 of the nexus → hexa-lang absorption surface. Nine read-only data
sets are baked into the compiler binary as `pub let` constants with
hash-pinned source provenance. Same pattern as the atlas embed
(`compiler/atlas/embedded.gen.hexa`): generator emits to `*.gen.hexa`,
static index facade does linear lookups, smoke test verifies hash/count
contract.

## Per-data-set results

| #  | name                  | src                                                       | sha256       | N entries | embed size |
|----|-----------------------|-----------------------------------------------------------|--------------|-----------|------------|
| D1 | falsifiers            | `nexus/design/hexa_sim/falsifiers.jsonl`                  | `e786698f14` | 168       | 194 474 B  |
| D2 | hexad CDESM constants | `nexus/config/hexad_constants.json`                       | `6c6c8e9a89` | 29        |   4 249 B  |
| D3 | calculators           | `nexus/config/calculators.json`                           | `05239ec750` | 328       |  71 196 B  |
| D4 | absolute_rules        | `nexus/config/absolute_rules.json`                        | `deea18757b` | 67        |  31 484 B  |
| D5 | grade_rubric          | `nexus/config/grade_rubric.json`                          | `fbfc9d11cd` | 13 (+10kv)|   3 513 B  |
| D6 | completion criterion  | `nexus/config/projects.json` → `_meta.universal_completion_criterion` | `035174ac34` | 1 | 1 693 B |
| D7 | engine_registry       | `nexus/engine/engine_registry.jsonl`                      | `cab04e0a5d` | 3         |   1 348 B  |
| D8 | drill DoD             | `nexus/roadmaps/drill_dod.json`                           | `74c2ced29c` | 3         |   1 862 B  |
| D9 | lens taxonomy         | `nexus/config/lens_registry.json`                         | `f3c7b2509c` | 4000      | 908 740 B  |

All 9 smoke tests: PASS.

## D1 status

Already complete from previous BG agent. Verified intact:
`compiler/falsifiers/{embed,embedded.gen,static_index,static_index_test}.hexa`
and `tool/falsifiers_embed_gen.hexa`. Smoke re-run = 168/168 PASS.
No re-emit.

## Per-data-set notes

- **D2 hexad** — JSON is a nested fixed-shape tree, not a list. Flattened
  to one `HexadConstantEntry` per leaf with a `kind` discriminator
  (`i64` / `f64` / `string_list`). `channels.names` is the sole list-typed
  leaf. `_meta` skipped. 29 leaves.

- **D3 calculators** — top-level map of projects to calculator lists.
  Empty projects (TECS-L, anima) contribute zero rows; SEDI = 93, CANON =
  235. Flattened with project tag, 328 total.

- **D4 absolute_rules** — two-section structure: `common[]` + per-project
  arrays under `projects.<name>[]`. Tagged with `section` = "common" or
  project key. Optional fields (`applies_to`, `sub_rules`, `except`,
  `see_also`, `promoted_from`) default to empty. 67 total rules across
  the 9 sections.

- **D5 grade_rubric** — split into two arrays: primary `GRADE_RUBRIC`
  (13 grades) + `GRADE_RUBRIC_KV` (10 auxiliary rows = 4 verify_mapping
  ints + 4 promotion strings + 2 demotion strings). Smoke verifies the
  EXACT → 10 mapping and the 9_to_10 promotion rule.

- **D6 completion criterion** — extracted ONLY the
  `_meta.universal_completion_criterion` sub-object as instructed. Hash
  is over the full `projects.json` source (so drift in either the
  criterion or the surrounding `_meta` triggers regen). Single-record
  embed (not a list); `pub let COMPLETION_CRITERION: CompletionCriterion`.
  `breakthrough_threshold = 10`, name = "closed_form".

- **D7 engine_registry** — 3-line JSONL; same line-by-line parse as D1.
  Fields: ts/name/score/auto_spawned/bt_parent/attack_angle/path. Bool
  field (auto_spawned) emitted as literal `true`/`false`.

- **D8 drill DoD** — source found at `~/core/nexus/roadmaps/drill_dod.json`
  (NOT `shared/roadmaps/...` as initially expected; the `.claude/worktrees/`
  copies are agent worktree dupes — used the canonical path). Tiers map
  (`scaffold_done`, `wired_done`, `serving_done`) flattened to 3 rows.
  Top-level scalars (`track`, `description`, `updated`) exposed as
  separate `pub let` constants alongside the entry list.

- **D9 lens taxonomy** — 4000 lenses, 14 distinct fields in the source.
  Per the "tight types" mandate, embedded only the universally-present
  4 (name/file/category/status) + the two near-universal ones
  (description, derived_from). Dropped audit-only fields (`bt`,
  `hexa_engine`, `impl`, `implemented_date`, `implemented`, `features`).
  Output 908 KB — well under the 2 MB ceiling. Generator streams in
  256-entry chunks via `append_file` to keep peak RSS bounded.

## Parser / runtime issues encountered

- **`impl` is a reserved keyword.** First version of the D9 smoke test
  declared `let impl = lenses_by_status("implemented")` which the parser
  rejects with `FIX-6: reserved keyword 'impl' cannot be used as
  let-binding name`. Renamed to `implemented`. Worth flagging — any
  embedded entry with a JSON key literally named `impl` would NOT be
  affected (it's a string field name, not a binding), but any consumer
  writing `let impl = ...` will hit this.

- **D9 hits the 768 MB runtime memcap by default.** Two compounding
  causes: (1) the 1 MB source JSON parses into a deep AST plus per-entry
  dicts; (2) accumulating 4000-entry render in a single string-array
  before flush. Mitigations applied:
  1. Chunk-flush via `append_file` (256 entries per chunk; header
     and trailing `]` separate).
  2. Generator must run with `HEXA_MEM_UNLIMITED=1` (or
     `HEXA_MEM_CAP_MB=4096`). Single source for the regen recipe:
     `RESOURCE_LOCAL_HEXA=1 HEXA_MEM_UNLIMITED=1 hexa run
     tool/lens_taxonomy_embed_gen.hexa`
  3. **Note on env propagation**: the Claude Code Bash sandbox strips
     HEXA_* env vars by default. Running with `dangerouslyDisableSandbox`
     (or via a non-sandbox shell) propagates them. The other 8 generators
     do not need either flag.

- **`type_of` taxonomy**: confirmed `int` / `float` / `string` / `array`
  / `map` / `bool` / `void`. There is no `"i64"` or `"f64"` returned at
  the value-typing layer — those are the embed-side widths. Both `int`
  and `float` from `json_parse` are accepted.

- **Locale**: `LC_ALL=C` prefix on `date` and `shasum` calls in all 8
  new generators, identical to the D1 driver.

## Deferred / out-of-scope

- No D10+ — Phase 1 closes at D9 per task brief.
- Atlas / falsifiers untouched (D1 done; atlas is the precedent embed).
- No commit, per hard constraint.
- The `engine_registry_lookup` linear scan is acceptable at N=3 today;
  if the registry grows past ~100 entries a packed lookup makes sense.
- D9 linear scans over 4000 entries: same story as the atlas. Profile
  before optimizing.

## Verification (post-write)

```
git diff -- self/main.hexa            → empty
git status compiler/atlas/            → clean (untouched)
git status compiler/falsifiers/       → untracked but unmodified (D1 intact)
hexa run compiler/<each>/static_index_test.hexa  → PASS for all 9
```

## LOC added (D2-D9)

| component                       | LOC   |
|---------------------------------|-------|
| 8 × `compiler/<set>/embed.hexa`           |   248 |
| 8 × `compiler/<set>/static_index.hexa`    |   356 |
| 8 × `compiler/<set>/static_index_test.hexa` | 553 |
| 8 × `compiler/<set>/embedded.gen.hexa` (generated) | 4610 |
| 8 × `tool/<set>_embed_gen.hexa`            | 1517 |
| **total (incl. generated)**     | **7284** |
| **total (hand-written, excl. .gen.hexa)** | **2674** |

Phase 1 progress: **9/9 complete**.
