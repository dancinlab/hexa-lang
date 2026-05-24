# 2026-05-13 — Phase 3 foundation session (loader hardening + overlay surface)

Pre-drill plumbing for the Phase 3 absorption surface. Two independent
landings:

1. **Module loader hardening** — `use "compiler/<x>/static_index"`
   resolves from arbitrary cwd, no `HEXA_LANG` required.
2. **Atlas overlay infrastructure** — rodata seed + runtime overlay
   (~/.hx/data/atlas.overlay.n6, append-only) per absorption doctrine
   v2 rule 5 (model b).

A5 smash mini-mirror (Phase 2 BG-A5 workaround) retired in this pass:
`compiler/smash/phases.hexa` now imports the real
`compiler/hexad/static_index` instead of the inlined 6-entry table.

---

## Task 1 — module loader hardening

### Root cause

Two cooperating bugs surface together when a smoke harness runs
`hexa run compiler/<x>/static_index_test.hexa` from a cwd other than
the repo root (or via `hexa.real`'s TCP-offload path):

1. **`self/module_loader.hexa::ml_resolve_project_root`** only consulted
   `HEXA_LANG`. When `HEXA_LANG` is unset (cron / launchd / subagent /
   fresh shell) the project-root probe always returned `""`, and
   `compiler/<x>/...` resolution failed with the `FATAL module not
   found` diagnostic. Stdlib paths had an
   install-relative fallback chain via `ml_resolve_stdlib_install_relative`
   — repo-root paths did not.

2. **`self/module_loader.hexa::env_hexa_install_dir`** trusted the
   `HEXA_INSTALL_DIR` env var unconditionally. `hexa.real` (when routed
   through the TCP compute shim) execs the interp from
   `/var/folders/.../T/hexa_interp`, so `main.hexa`'s
   `install_dir_from_argv0()` derives `/var/folders/.../T` and passes
   that bogus value down. Module loader believed it, never fell back
   to `ml_self_install_dir()` (derived from `args()[1]` =
   `module_loader.hexa` path = real repo).

3. **`build/hexa_interp` wrapper** only checked `^use "` for multi-file
   detection. Multi-file scripts that used `import "./..."` (the
   sibling form — every `compiler/<x>/<x>_test.hexa` smoke does this)
   silently routed to the TCP path that strips imports.

### Fix

Three coordinated changes:

- **`self/module_loader.hexa`** (~25 LOC delta):
  - `env_hexa_install_dir` now validates the env value before
    trusting it: must hold one of `self/module_loader.hexa` /
    `compiler/` / `stdlib/`. Stale `/var/folders/.../T` values fail
    validation → fall through to `ml_self_install_dir` which is
    always correct (derived from `args()[1]`).
  - `ml_resolve_project_root` adds an install-relative probe: when
    `HEXA_LANG` is empty, try `<env_hexa_install_dir>/<imp>` before
    falling back to bare-cwd-relative. Mirrors the existing stdlib
    fallback in `ml_resolve_stdlib_install_relative`.

- **`build/hexa_interp`** (1 LOC delta, regex widened):
  - Multi-file fence now matches `^(use|import|from) "` instead of
    just `^use "`. Drives any source with `import "./..."` to the
    local REAL interp where module_loader can walk siblings.

### Verification

```
# Repro before fix (from any cwd, including repo root):
$ hexa run compiler/smash/smash_test.hexa
[module_loader] FATAL module not found: compiler/hexad/static_index ...

# After fix — from /tmp, ~, /Users/ghost/core, repo root:
$ hexa run compiler/smash/smash_test.hexa
... 6/6 PASS, RESULT: PASS
```

A5 smash mini-mirror cleanup:

- `compiler/smash/phases.hexa` mini-mirror (`_hexad_seed_names` /
  `_hexad_seed_values` static 6-entry table) removed.
- Replaced with `use "compiler/hexad/static_index"` + a thin
  `_hexad_pick(group, key)` wrapper that pulls real f64/i64 values
  from `HEXAD_CONSTANTS` (D2 wave-1, hash `6c6c8e9a89...`).
- Smoke: 6/6 PASS, `perfect_number_6` (depth=3) now yields 414
  candidates (was 368 with synthetic mini-mirror values), all 7
  ctypes still represented, grade `"10*"` still present.

Files touched: 3 (module_loader.hexa, hexa_interp shim, phases.hexa).

---

## Task 2 — overlay infrastructure

### File: `compiler/atlas/overlay.hexa` (new, ~180 LOC)

Public surface:

```hexa
pub struct OverlayMeta { file_path; entry_count; last_size; loaded }

pub fn overlay_path() -> string                   // ~/.hx/data/atlas.overlay.n6
pub fn overlay_ensure_dir() -> void               // mkdir -p ~/.hx/data
pub fn overlay_load() -> [AtlasNode]              // parse-from-disk, no cache
pub fn overlay_load_cached() -> [AtlasNode]       // size-invalidated cache
pub fn overlay_find_by_id(nodes, id) -> AtlasNode // linear scan, sentinel on miss
pub fn overlay_append(node) -> void               // single record
pub fn overlay_append_lines(lines) -> void        // batch raw .n6 lines
pub fn overlay_note_conflict(kind, id, src)       // once-per-process stderr warn
pub fn overlay_reset_cache() -> void              // test-only
```

### Modified: `compiler/atlas/static_index.hexa`

Adds 4 merged-view variants (rodata-first, overlay-fallback):

```hexa
pub fn atlas_lookup(id) -> AtlasNode            // rodata-only convenience
pub fn atlas_lookup_merged(id) -> AtlasNode     // rodata-first + overlay fallback
pub fn atlas_list() -> [AtlasNode]              // flat P+C+L+E
pub fn atlas_list_merged() -> [AtlasNode]       // + overlay (de-dup, rodata wins)
```

Pre-existing `static_atlas()` / `lookup_static(kind, id)` left
untouched — hot paths that need the hash-pinned rodata-only view
continue to call them.

### Conflict policy

**RODATA WINS.** Overlay can ADD only. On `(kind, id)` collision the
overlay entry is dropped at lookup; the first such conflict per
process logs once on stderr via `overlay_note_conflict` (the cache is
keyed on a boolean — subsequent conflicts stay silent so high-volume
drill runs don't flood stderr).

### Cache invalidation

`overlay_load_cached` invalidates on `file_size` delta. The overlay
is append-only by API contract, so size changes monotonically and
size delta is a sound (and cheap) staleness signal. `file_mtime` is
not yet a builtin; falling back to size avoids needing one.

### File location

`<HOME>/.hx/data/atlas.overlay.n6`. Same `.n6` line syntax as the
rodata seed so the existing `parse_atlas_file` does double duty —
nothing format-specific.

### Smoke: `compiler/atlas/overlay_test.hexa` (new)

3 scenarios, **9/9 PASS**:

1. Append 3 fresh entries (P + C + L) → all three reachable via
   `atlas_lookup_merged`; `atlas_list_merged` grows by 3.
2. Append an entry whose id matches rodata `P:n` → `atlas_lookup_merged("n")`
   still returns the rodata node (`source_file == "atlas.n6"`);
   `atlas_list_merged` contains exactly one `P:n` (no dup);
   `overlay_note_conflict` fires once on stderr.
3. Batch append via `overlay_append_lines` → both entries reachable.

Hermetic — relocates `HOME` to `/tmp/atlas_overlay_test_smoke/` via
`setenv` before each run so the smoke is replayable.

---

## Phase 2 regression check

Sample 3 algorithm tests, all run from `/tmp` after fixes:

- `compiler/smash/smash_test.hexa` — **6/6 PASS** (with real
  `compiler/hexad/static_index` import).
- `compiler/atlas/static_index_test.hexa` — **9/9 PASS** (hash
  `663698a06bc6...`, 7398 nodes).
- `compiler/hexad/static_index_test.hexa` — **8/8 PASS** (hash
  `6c6c8e9a89a1...`, 29 entries).
- `compiler/falsifiers/static_index_test.hexa` — **8/8 PASS** (hash
  `e786698f1424...`, 168 entries).
- `compiler/lens_taxonomy/static_index_test.hexa` — **8/8 PASS**
  (hash `f3c7b2509ce9...`, 4000 entries).

No regression.

---

## Files

| change | path                                              | LOC  |
|--------|---------------------------------------------------|------|
| edit   | `self/module_loader.hexa`                         | +25  |
| edit   | `build/hexa_interp`                               | +1   |
| edit   | `compiler/smash/phases.hexa`                      | +9 / −13 (mini-mirror retired) |
| edit   | `compiler/atlas/static_index.hexa`                | +75  |
| new    | `compiler/atlas/overlay.hexa`                     | 188  |
| new    | `compiler/atlas/overlay_test.hexa`                | 195  |

Total LOC: ~493 add / ~13 retire.

---

## Deferred / blockers for Phase 3 drill chain

- **None blocking.** The drill chain can now `use
  "compiler/atlas/overlay"` and emit discoveries via `overlay_append`
  / `overlay_append_lines`; lookups go through `atlas_lookup_merged`
  / `atlas_list_merged`. Rodata-wins guarantees seed determinism is
  preserved across overlay writes.

- **Nice-to-have (not blocking):** `file_mtime` builtin would let
  `overlay_load_cached` survive concurrent rewrites; today the
  append-only contract suffices because size is monotonic.

- **Nice-to-have:** overlay rotation. The file grows without bound.
  Phase 4 rotation policy = `mv atlas.overlay.n6 atlas.overlay.<ts>.n6
  && touch atlas.overlay.n6` once a discovery is promoted into rodata
  via `tool/atlas_embed_gen`.

- **Long-term:** `atlas_list_merged` is O(rodata × overlay) due to
  linear dup scan. For large overlays (>1k entries) a per-kind hashset
  pre-pass would help. Today rodata = 7398 and a reasonable overlay
  upper bound is hundreds, so the linear path is fine.
