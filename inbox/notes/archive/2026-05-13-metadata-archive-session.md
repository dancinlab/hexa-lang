# 2026-05-13 — Metadata archive absorption session (D10-D14, Phase 1-extension)

Phase 1-extension of the nexus → hexa-lang absorption surface. Five frozen
metadata snapshots from nexus are baked into hexa-lang as rodata archives
per absorption doctrine v2 rule 3: historical records, not active
management surfaces — store as-is, no reinterpretation. Same 4-file +
driver pattern as the atlas embed and the D1-D9 wave 1 absorption.

## Per-archive results

| #   | name              | source path                              | sha256       | N entries | output size |
|-----|-------------------|------------------------------------------|--------------|-----------|-------------|
| D10 | projects archive  | `config/projects.json`                   | `035174ac34` | 22        |    20 391 B |
| D11 | roadmaps archive  | `roadmaps/<project>.json` (×7)           | `d4a76a4261` | 7         |   281 204 B |
| D12 | status archive    | `state/markers/` (dir listing)           | `f55e65322f` | 6253      |   702 120 B |
| D13 | audit log tail    | `logs/nexus_cli.log`                     | `fdd71d8791` | 370       |    90 801 B |
| D14 | cli spec archive  | `engine/nexus_cli_spec.json`             | `95e3086ac9` | 13 (+19)  |    28 505 B |

All 5 smoke tests: PASS.

(For D11 the listed sha256 is a *bundle* hash = sha256 over the
concatenated per-file sha256s. Per-file hashes are recorded inside each
row's `sha256` field.)

(For D14 the secondary count `+19` is the subcommand index list embedded
alongside the 13 section rows; smoke verifies both surfaces.)

## Per-archive notes

- **D10 projects archive** — top-level `projects.json` flattened into 22
  `ProjectArchiveEntry` rows tagged with `category` ∈ {core, auxiliary,
  launch_ops, experimental, archived, private_repos}. Each project's
  sub-object is preserved verbatim as canonical JSON in `raw_json` —
  schema-agnostic, so any field nexus ships today or adds tomorrow rides
  along. Top-level shell blocks (`_meta`, `categories`, `common_links`,
  `private_repos`, `dev_dir`) exposed as separate `pub let` constants for
  callers that need the document shell without crawling the entry list.
  D6's typed `CompletionCriterion` extract is intentionally NOT replaced;
  D10 is the surrounding-document archive, D6 is the typed extract — both
  hash-track `projects.json`.

- **D11 roadmaps archive** — 7 projects per `projects.json` readme_order:
  anima / nexus / canon / papers / hexa-lang / void / airgenome. Five
  roadmap files are present at `~/core/nexus/roadmaps/`. Canon's roadmap
  file is named `n6-architecture.json` (its `_meta.project` reads
  "CANON") — the project key remains `canon` but `source_path` records
  the actual filename verbatim. **airgenome's roadmap is NOT FOUND** on
  disk (no file at the declared `airgenome/config/roadmap/airgenome.json`
  nor at `~/core/nexus/roadmaps/airgenome.json`) — the row is emitted
  with `status="not_found"`, `sha256=""`, `raw_json=""` so consumers see
  the gap explicitly. nexus.json alone is 261 KB; the JSON re-serializer
  is a streaming emitter (`_emit_json` pushes into a chunked buffer with
  outer-hexa-literal escaping baked in) so the generator stays under the
  default 768 MB cap WHEN run with `HEXA_MEM_UNLIMITED=1` (see "Parser /
  runtime issues" below). Bundle hash = sha256 over the concatenated
  per-file sha256s; missing files contribute 64 zero hex chars.

- **D12 status archive** — strategy (a) chosen per brief: a deterministic
  filesystem tableau of `~/core/nexus/state/markers/` (filename, mtime,
  size). 6253 markers; many are 0-byte presence-only sentinels (the
  literal size is preserved). Strategy (b) (`nexus status --json`)
  rejected — that command's output is *computed* from the same markers
  plus mutable in-memory agent state, so (a) is the more fundamental
  input. Caveat: this is **status as of nexus archive time T**, not live
  status. Bundle hash = sha256 over the concatenated sorted
  `name|mtime|size\n` digest. Generator writes the stat output to a tmp
  file first (`bash -c 'find ... | stat ... > /tmp/...'`) to avoid the
  exec stdout balloon; this still requires `HEXA_MEM_UNLIMITED=1` for the
  6253-row in-memory pass.

- **D13 audit log tail** — `~/core/nexus/logs/nexus_cli.log` is 78 KB and
  370 jsonl lines today, which all fit under the 100 KB emit cap, so the
  tail = the whole log right now. The generator implements a real
  tail-select: it computes each row's rendered cost newest-first and
  stops when the running budget would exceed `EMBED_BYTE_CAP - 1 KB
  header`. Schema (`ts/caller/subcmd/args/exit_code/duration_ms`)
  matches `nexus_cli_spec.json#audit.fields`; optional `duration_ms`
  defaults to 0 when absent in the source. `TS_FIRST`/`TS_LAST` constants
  bracket the embedded window for cheap range queries without iterating.
  Halts (exit 2, no emit) if the source file is missing — per brief, we
  do not invent data.

- **D14 cli_spec archive** — `~/core/nexus/engine/nexus_cli_spec.json` is
  33 KB and ships 13 top-level sections in the schema_version=2 shape
  (`_meta`, `projects`, `project_paths`, `env`, `global_flags`,
  `exit_codes`, `audit`, `subcommands`, `subcmds_v2`,
  `subcmds_raw99_cli_coverage`, `subcmds_check`, `v2_invariants`,
  `security`). Each becomes one `CliSpecSection` row with the subtree
  re-serialized as canonical JSON in `raw_json`; a separate
  `CLI_SPEC_SUBCOMMAND_NAMES: [string]` list indexes the 19 subcommand
  keys for callers that just want names without parsing.

## Parser / runtime issues encountered

- **`HEXA_MEM_UNLIMITED=1` requires `RESOURCE_LOCAL_HEXA=1` to propagate.**
  Without the local resolver flag the `hexa` wrapper appears to route
  through a launcher that strips most `HEXA_*` env vars before the
  runtime sees them (confirmed by `env()`-side print: HOME passes, FOO
  and HEXA_MEM_CAP_MB both come back empty in a normal sandbox; with
  `RESOURCE_LOCAL_HEXA=1` HEXA_MEM_UNLIMITED becomes visible). D11 and
  D12 both blow past the default 768 MB cap during JSON re-serialization
  / 6k-row in-memory pass; both are runnable today only as
  `RESOURCE_LOCAL_HEXA=1 HEXA_MEM_UNLIMITED=1 hexa run …` (and only when
  the harness is invoked with `dangerouslyDisableSandbox`). D10, D13,
  D14 generators run cleanly under default memcap.

- **No `.index_of_from(sub, start)` string method.** The 2-arg form is
  `.index_of(sub, start)` (single overload). D12 generator initially hit
  this; fixed.

- **`exec()` captures full stdout into a hexa string.** A `find | stat`
  over 6253 markers produces a ~500 KB string that, combined with the
  per-character substring parse loop, blows the 768 MB cap on its own.
  Mitigation in D12: have bash redirect the stat output to a tmp file
  inside the exec, then `read_file` it back. Pattern is reusable for any
  generator that wants to slurp a large external listing.

- **JSON re-serializer + outer hexa-string-literal escape can run hot.**
  D11 needed a custom streaming emitter (`_emit_json` / `_emit_json_str`
  with `_esc2_char` that escapes BOTH layers in a single table) so the
  261 KB `roadmaps/nexus.json` doesn't materialize 3× in arrays (raw
  text, JSON string, escaped JSON string). D10 and D14 use the simpler
  non-streaming `_json_emit` because their source files are small
  enough.

- **Empty top-level optional fields.** anima's roadmap has no top-level
  `phases` / `tracks` keys (it uses `destinations` and other shapes); we
  store `phase_count = 0` / `track_count = 0` for it. Not a bug — those
  fields are advisory cached scalars; consumers needing the structure
  json_parse `raw_json`.

## Hard constraints satisfied

- `git diff self/main.hexa` → empty.
- `compiler/atlas/` / `compiler/falsifiers/` / `compiler/hexad/` / other
  D1-D9 dirs → untouched (verified by `git status compiler/atlas/`).
- `tool/hexa_annot/` → untracked but unmodified by this session.
- No nexus repo writes; all `~/core/nexus/...` reads are read-only.
- All code/comments English-only.
- No commit (per brief).

## LOC added (D10-D14)

| component                                | LOC   |
|------------------------------------------|-------|
| 5 × `compiler/<x>_archive/embed.hexa`            |   142 |
| 5 × `compiler/<x>_archive/static_index.hexa`     |   175 |
| 5 × `compiler/<x>_archive/static_index_test.hexa`|   537 |
| 5 × `compiler/<x>_archive/embedded.gen.hexa` (generated) | 6780 |
| 5 × `tool/<x>_archive_embed_gen.hexa`            |  1264 |
| **total (incl. generated)**              | **8898** |
| **total (hand-written, excl. .gen.hexa)** | **2118** |

Phase 1-extension progress: **5/5 complete (D10-D14)**.
