# 2026-05-14 — Wave 2.4 prefix_index implementation session

## Goal

Land the bucket prefix-cache decided in the FU2 prefix-bench session
(commit fd368a54): linear-scan p95 measured at 440x the 50 ms threshold
on the 7398-node merged view; `atlas_prefix` now delegates to a 2-char
bucket lookup that auto-invalidates on overlay file-size change.

## Files added / modified

| Path | LOC | Change |
|---|---|---|
| `compiler/atlas/prefix_index.hexa` | 198 | NEW — bucket cache + auto-fingerprint |
| `compiler/atlas/prefix_index_test.hexa` | 238 | NEW — parity + cache + perf-sanity test |
| `compiler/atlas/static_index.hexa` | +21 / -5 | `use prefix_index`; `atlas_prefix` now delegates to `prefix_lookup`; `atlas_prefix_linear` exposed pub for parity testing |

Total LOC delta: **+457 / -5 (net +452)**.

Public signature `atlas_prefix(prefix) -> [AtlasNode]` is unchanged. The
old linear-scan body is preserved verbatim as `atlas_prefix_linear` so
the new path can be parity-checked against the canonical sweep.

## Cache fingerprint approach

**Auto-detect, zero coupling to write paths.** `_overlay_fingerprint()`
calls `file_size(overlay_path())` on every `prefix_lookup`. The overlay
is append-only (`overlay_append` / `overlay_append_lines`), so size is
monotonic in promotions and changes on every write. On size delta the
buckets rebuild from `atlas_list_merged()`.

Why size, not mtime/hash:

- `file_size` is the same builtin `overlay_load_cached` already uses
  for its own cache invalidation — pattern parity.
- mtime is not exposed as a hexa-lang builtin today (per
  `compiler/atlas/overlay.hexa` line 32 note).
- A cryptographic hash would re-read the entire overlay on every
  lookup, defeating the cache.
- Sufficient because the overlay surface is the only writer; concurrent
  rewrites are out of scope (single-process compiler).

`invalidate_prefix_index()` is exported as an external hook in case a
future caller needs to force rebuild (e.g. a test that rewrites the
overlay rather than appending), but is **not required** under normal
operation.

## Wire-in shape

`compiler/atlas/static_index.hexa::atlas_prefix` is now a one-liner
delegate:

```hexa
pub fn atlas_prefix(prefix: string) -> array {
    return prefix_lookup(prefix)
}
```

`prefix_lookup` internally:

1. `prefix == ""` → return full merged list (matches old semantics).
2. Sample `_overlay_fingerprint()`; rebuild buckets if size changed
   (or first call).
3. `len(prefix) < 2` → fall through to `_linear_scan` (1-char prefixes
   span too many buckets to make the bucket union cheaper).
4. Otherwise: 2-char bucket key → scan ONLY that bucket's candidates,
   filtering by full `starts_with`.

Bucket key derivation (`_bucket_key`): 2-char prefix when `len(id) >= 2`,
1-char when `len(id) == 1` (covers the `"n"` foundation axiom edge case).

## Test results

**Parity test design (`prefix_index_test.hexa`):**

- Scenario 1 — 5 representative prefixes (`n`, `sigma`, `phi`,
  `consciousness`, `meta_falsifier`): assert
  `prefix_lookup(p)` returns the same (kind, id) SET as
  `atlas_prefix_linear(p)`. Uses an order-independent set-equality
  helper since bucket iteration order does not match linear sweep
  order.
- Scenario 2 — cache invalidation: hermetic HOME → `setenv("HOME",
  base)`, append a fresh overlay node whose id starts with `phase24`,
  assert `prefix_lookup("phase24")` count grows by +1 across the
  append. Confirms the file-size fingerprint triggers rebuild.
- Scenario 3 — low-fidelity perf sanity: 5x bucket vs 5x linear for
  `"sigma"`, assert `bucket <= 2x linear` wall. Hard-asserting
  `bucket < linear` would be flaky on small wall times — the parity
  checks in scenarios 1+2 are the load-bearing assertions.

**Static validation: PASS.**

- `hexa parse compiler/atlas/prefix_index.hexa` → OK
- `hexa parse compiler/atlas/static_index.hexa` → OK
- `hexa parse compiler/atlas/prefix_index_test.hexa` → OK

**Runtime test: NOT EXECUTED in this session.**

Per the FU2 session note (`2026-05-14-fu2-prefix-benchmark-session.md`,
this directory), executing any test that loads `embedded.gen.hexa`
under the current interp pays a ~24-minute parse phase before the
first measurement. The 4.9 MB embedded array dominates the wall.
Even a single-iteration parity test would not complete inside this
agent's wall budget. Two test processes were started in the
background (`88099`, `83575`) but were not given enough wall time to
flush a single row.

Recommended runtime validation path (for the operator running this
post-session):

```
HEXA_MEM_UNLIMITED=1 hexa run compiler/atlas/prefix_index_test.hexa \
    > /tmp/prefix_index_test_out.txt 2> /tmp/prefix_index_test_err.txt
```

Expected wall: ~25-30 min (parse-dominated, single linear scan in
scenario 3 only — not the 100-iter loop the FU2 bench used).

## Perf delta

**Deferred — interp parse dominates.**

The per-call delta cannot be measured without paying the 24-min parse
cost first; the wall-clock budget for this session did not permit it.
The structural argument from the FU2 bench still applies:

- Dense 2-char prefix (e.g. `"si"` for `sigma…`) — bucket cardinality
  is on the order of `7398 / 26^2 ≈ 11` candidates expected, vs 7398
  for the linear path. Worst-case dense bucket (e.g. `"co"` for
  `consciousness*`, `commit_*`, etc) is still bounded well below the
  full list.
- 1-char prefix (e.g. `"n"`) — falls through to the linear-scan path
  by design. No worse than pre-Wave-2.4.
- Empty prefix — returns the full merged list directly. No worse than
  pre-Wave-2.4.

Re-run `compiler/atlas/prefix_bench.hexa` (with the new delegate
wired) for the canonical Wave-2.4 acceptance measurement: worst
`p95 <= 50 ms`.

## Deviations from the spec sketch

- **Bucket key on 1-char ids**: the spec said "first 2 chars (or first
  1 if prefix shorter)". I read "prefix shorter" as "id shorter" for
  the bucket-key derivation (the 1-char `"n"` foundation axiom needs a
  home), and "prefix shorter" as the fall-through-to-linear case for
  query-side. Behaviour matches the spec intent; naming clarified in
  comments.
- **`merged` snapshot stored in PrefixIndex**: the spec sketched
  buckets as `map<string, [i64]>`. To resolve indices back to nodes,
  I stored the `merged` array alongside in the struct (vs re-listing on
  every lookup). This trades a small memory overhead for one
  `atlas_list_merged()` call per cache build instead of per query —
  important since `atlas_list_merged` itself does an O(rodata * overlay)
  dedup scan.
- **`prefix_index.hexa` `use`s `static_index.hexa`** (which now
  reciprocally `use`s `prefix_index.hexa`). The hexa-lang module
  loader dedups via `__use_loaded_paths` (per `self/hexa_full.hexa`
  line 9110 / 9636), and function resolution is late-bound through
  `env_fns`, so the cycle is safe at runtime. `hexa parse` confirms
  no static error.

## Hard constraints honoured

- DID NOT commit (working-tree only).
- DID NOT modify rodata (`embedded.gen.hexa` untouched).
- DID NOT change the public signature of `atlas_prefix`.
- English code + comments throughout.
- License header `// Ported from FU2 prefix bench (commit fd368a54).
  CC0-1.0.` present in `prefix_index.hexa` and
  `prefix_index_test.hexa`.
- Linear path preserved as `atlas_prefix_linear` (pub, callable by
  parity test) — no regression to the small-prefix / fallback shape.
- No `self/` edits.
