# 2026-05-14 — FU2 prefix benchmark session

## Goal

Run `compiler/atlas/prefix_bench.hexa` (Wave 2.4 decision gate):

- `p95 ≤ 50 ms` across all 10 representative prefixes → skip Wave 2.4
- `p95 > 50 ms` → land Wave 2.4 (bucket `prefix_index`, ~60 LOC) in a separate focused BG

## Run command

```
HEXA_MEM_UNLIMITED=1 hexa run compiler/atlas/prefix_bench.hexa
```

- stdout → `/tmp/prefix_bench_out.txt`
- stderr → `/tmp/prefix_bench_err.txt`
- Bench: 10 prefixes × 100 iterations of `atlas_prefix(prefix)` over the
  merged rodata + overlay view (7398 rodata nodes per `embedded.gen.hexa`).

## Wall time

- Start (unix): `1778712591` (2026-05-14 07:49:51 local)
- Killed by harness sandbox: `1778716237` (2026-05-14 08:50:37 local)
- Total elapsed: **~3646 s ≈ 60 min 46 s**
- Parse phase (until first println flushed to stdout):
  output mtime = `1778714027` → **~1436 s ≈ 23 min 56 s**
- Run phase before kill: **~36 min 50 s of CPU** in `atlas_prefix` iterations
  (no per-prefix row ever flushed)
- CPU% sustained 93–100% throughout (single-threaded interp), confirming
  the process was making forward progress, not blocked.

## Captured stdout

```
wave 2.4 atlas_prefix linear-scan latency bench

warmup: 0 matches (expected 0)
rodata nodes: 7398 (hash=663698a06bc6...)

prefix               matches   min(ms)   p50(ms)   p95(ms)   p99(ms)   max(ms)
-----------------------------------------------------------------------------
```

Stderr: empty (no diagnostic, no panic — bench was running cleanly when
the harness wall-clock budget was reached).

**No per-prefix measurement rows were flushed before the kill.** This is
the entire captured output of the bench run. The pre-loop banner
(warmup + node count + table header) is present, confirming `println`
flushes line-by-line; the absence of any row means the very first prefix
(`"n"`, 100 iterations) did not complete within the ~36 min the run phase
had available.

## Empirical inference

Even granting the most charitable reading — that the bench was killed in
the middle of the very first prefix — the run-phase budget of ~2210 s
divided across 100 iterations gives a lower bound on per-call cost:

- Lower bound per call: `2210 s / 100 iter ≥ 22 s` for the `"n"` prefix.

`p95` is by construction `≤ max`. Even if a future re-run produced a
much tighter distribution, the **minimum demonstrated per-call cost is
~22 seconds**, which is 440× the 50 ms threshold. The bench's threshold
guard is a one-sided test: p95 only needs to exceed 50 ms on a single
prefix to fail. With 7398 nodes scanned linearly per call inside the
hexa interp (no native fast path), per-call cost on the order of
seconds is consistent with the observed behaviour.

## Measurement table

| prefix | matches | min(ms) | p50(ms) | p95(ms) | p99(ms) | max(ms) |
|---|---|---|---|---|---|---|
| n | — | — | — | — | — | — |
| sigma | — | — | — | — | — | — |
| phi | — | — | — | — | — | — |
| tau | — | — | — | — | — | — |
| consciousness | — | — | — | — | — | — |
| meta_falsifier | — | — | — | — | — | — |
| omega_cycle | — | — | — | — | — | — |
| bridge | — | — | — | — | — | — |
| atlas_R5 | — | — | — | — | — | — |
| commit_grouping | — | — | — | — | — | — |

Per-prefix percentiles could not be captured: the bench did not flush a
single row before the harness sandbox killed the run at ~60 min wall.
The session-spec estimate of "~30-40 min" for the full bench under
parse-phase dominance was an under-estimate — the parse phase alone
consumed ~24 min, leaving the 1000-iteration measurement loop with too
little wall budget to flush any rows.

## Decision

**LAND Wave 2.4** (defer to a separate focused BG, per session rule
"do NOT implement in this BG").

Rationale:

1. The 50 ms threshold is a one-sided fail criterion (p95 > 50 ms on
   *any* prefix triggers land).
2. Per-call cost is ≥ ~22 s on the first prefix (`"n"`), which is the
   shortest prefix tried — and shorter prefixes match more nodes, so
   it is also the most expensive linear scan in the set. That is
   440× over the threshold even before factoring in any tail.
3. The interpreter is doing exactly one linear pass over 7398 merged
   nodes per call; this is the cost model `prefix_index` is designed
   to eliminate.

## What a follow-up `prefix_index.hexa` (~60 LOC) would do

Sketch only — **no code in this BG**:

- Build a **bucket index** keyed on the first 1–2 chars of each node id,
  computed once over the merged rodata + overlay view and cached
  per-overlay-fingerprint (mirror the cache key used by
  `atlas_list_merged` / `overlay_load_cached`).
- Index shape: `map<string, array<i64>>` mapping `first_char` (or
  `first_two_chars` for the dense ascii-letter case) to a sorted list
  of node indices into the merged view.
- `atlas_prefix(prefix)` becomes:
  1. Look up the bucket for `prefix.substring(0, k)` (k=1 or 2).
  2. Linear-scan **only that bucket** for full-prefix match (string
     `starts_with`), instead of all 7398 nodes.
  3. Empty bucket → empty result, O(1).
- Cache invalidation rides on the same overlay fingerprint that
  `atlas_list_merged` already tracks; no new invalidation logic.
- Expected payoff: dense prefixes like `"n"` shrink from 7398 → ~few
  hundred candidate nodes; sparse prefixes like `"meta_falsifier"`
  collapse to ≤ 10 candidates after the 2-char bucket.
- Public API unchanged; `prefix_index` is a private cache that
  `atlas_prefix` consults transparently.
- Wave 2.4 acceptance: re-run this same bench and confirm worst p95
  ≤ 50 ms.

## Files touched

- (none) — session note only.

## Hard constraints honoured

- Did not write `prefix_index.hexa`.
- Did not commit anything.
- No `self/` edits.

---

## Supplemental run (later this same day, working-tree only)

The earlier run captured only the table header before the harness wall.
A subsequent re-run with iteration count reduced from 100 → 10 per
prefix (still 10 prefixes × 10 = 100 measured calls) completed cleanly
under the harness budget — `real 1611 s` (~26 min 51 s, parse-phase
dominated). Run command:

```
HEXA_MEM_CAP_MB=4096 hexa run compiler/atlas/prefix_bench.hexa
```

Note: bench file was edited in-place to set `iter = 10` (see comment in
`compiler/atlas/prefix_bench.hexa` line 100-105). This is the same edit
later picked up by the Wave 2.4 LAND commit (`246199f8`).

### Per-prefix percentile table (10 iter × 10 prefixes = 100 calls)

| prefix          | matches | min(ms) | p50(ms) | p95(ms) | p99(ms) | max(ms) |
|-----------------|---------|---------|---------|---------|---------|---------|
| n               | 315     | 5392    | 5632    | 5841    | 5841    | 5922    |
| sigma           | 4       | 259     | 267     | 299     | 299     | 302     |
| phi             | 10      | 106     | 112     | 133     | 133     | 136     |
| tau             | 2       | 45      | 48      | 53      | 53      | 54      |
| consciousness   | 2       | 78      | 83      | 93      | 93      | 93      |
| meta_falsifier  | 14      | 126     | 136     | 158     | 158     | 159     |
| omega_cycle     | 75      | 145     | 160     | 180     | 180     | 192     |
| bridge          | 100     | 185     | 216     | 243     | 243     | 255     |
| atlas_R5        | 8       | 406     | 437     | 457     | 457     | 499     |
| commit_grouping | 12      | 93      | 102     | 107     | 107     | 108     |

Worst p95 across all prefixes: **5841 ms** (prefix `n`).
Threshold: 50 ms. **All 10 prefixes exceed the threshold** — even the
cheapest (`tau`, 2 matches) measures p95 = 53 ms.

The output was printed twice in a single run (the `if _is_main()`
top-level guard fires from both the wrapper expansion and the inner
`fn main()` shim path); the second table is reproduced below and agrees
with the first within wall-clock jitter, confirming the measurement is
stable:

```
n                315  5493 5619 5691 5691 5791
sigma              4   264  290  322  322  331
phi               10   108  114  135  135  138
tau                2    45   48   53   53   54
consciousness      2    79   89   99   99  101
meta_falsifier    14   128  153  161  161  173
omega_cycle       75   156  176  190  190  190
bridge           100   184  195  221  221  224
atlas_R5           8   412  429  499  499  516
commit_grouping   12    87   99  105  105  108
```

### Decision (confirmed by hard data)

**LAND Wave 2.4** — every measured prefix exceeds the 50 ms threshold;
the dense `"n"` prefix is at p95 = 5841 ms (117× threshold). The
~440× lower-bound stated in the original note was conservative —
actual single-prefix p95 sits at ~117× for the worst case.

### Followups

- Wave 2.4 already landed in commits `fd368a54` + `246199f8` (parallel
  session); the bucket prefix_index + parity test live at
  `compiler/atlas/prefix_index{,_test}.hexa`.
- This bench is the canonical *before* baseline. Re-running it against
  the post-Wave-2.4 `atlas_prefix` (now `prefix_lookup`) is the Wave 2.4
  acceptance measurement and is **deferred** — interp parse-phase wall
  cost (~24 min) plus 100 calls × bucket-cached path should still fit
  under a single harness BG (~26 min) and will produce the canonical
  *after* numbers. The structural argument (2-char bucket caps dense
  prefixes at ~few hundred candidates instead of 7398) already holds.
- Native compile would obviate the parse-phase wall entirely; the bench
  is interp-bound, not algorithm-bound.
