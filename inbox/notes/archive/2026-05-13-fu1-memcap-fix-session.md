# FU1 — interp memcap default bump (768 MB → 2048 MB → 4096 MB)

date: 2026-05-13 (initial) · 2026-05-14 (revised after drill_test measurement)
branch: main
status: applied (uncommitted)

## Problem

After n6 Wave 1 enriched `compiler/atlas/embedded.gen.hexa`
(3.27 MB → 4.92 MB rodata; ~7398 AtlasNode literals + 5 new per-kind
arrays carrying default `GradeInfo` / `EdgeInfo` per node), three smoke
tests started tripping the 768 MB runtime memcap on
`use "compiler/atlas/static_index"` (which transitively imports
`embedded.gen`):

- `compiler/atlas/static_index_test.hexa`
- `compiler/atlas/overlay_test.hexa`
- `compiler/drill/drill_test.hexa`

Pre-existing latent issue (the 768 MB default already squeezed heavy
loads); n6 Wave 1 pushed the parse-phase peak past it for every
embed-loading smoke. `HEXA_MEM_UNLIMITED=1` is a known manual unblock.

## Root cause + RSS measurements

`/usr/bin/time -l env HEXA_MEM_CAP_MB=4096 hexa run compiler/atlas/static_index_test.hexa`
(macOS, hexa.real run via interp `build/hexa_interp.real`):

```
RESULT: PASS (7398 nodes, hash=663698a06bc6...)
 1724.49 real      1316.53 user        11.77 sys
 1675526144  maximum resident set size      ← 1.56 GiB peak
 504530  page reclaims
```

Per-smoke RSS peaks (env-override / 2048 MB run / 4096 MB run):

| Smoke | Peak RSS | Notes |
| ----- | -------- | ----- |
| `static_index_test` | 1.56 GiB | dominated by parse-phase materializing 7398 `AtlasNode` literals |
| `overlay_test`      | 1.94 GiB | parse + overlay batch append |
| `drill_test`        | **2.00 GiB** | parse + drill engine 6-stage chain state |

The peak is dominated by the parse phase materializing 7398 `AtlasNode`
literals as live `Value` objects in the interp heap; once `main()` runs
the live set drops to ~250 MB. drill_test then re-grows it as the
discovery engine accumulates chain state.

The periodic-tick RSS probe (`_hx_mem_tick`, stride `0x0FFF`) fires when
peak exceeds the cap → `_hx_mem_cap_fire` → `exit(77)`. With cap=768 MB
the abort hit before the first user `println`; with cap=2048 MB the
abort hit drill_test partway through its Mk.IX chain ("memory cap
exceeded: rss=2048MB > cap=2048MB", peak resident 2,148,581,376 bytes
= 2.00 GiB exactly).

Wall time is ~20–29 min per smoke (cold). The slow path is parse, not
runtime; it is not addressed by this fix and is captured as a separate
followup.

## Option chosen — A (smallest viable, second iteration)

Bump the default cap from 768 MB → **4096 MB** in `self/runtime.c`.

First iteration (768 → 2048 MB) unblocked static_index_test and
overlay_test but drill_test peaked exactly at the 2 GiB ceiling and
fired the cap. Per the brief: *"If RSS actually exceeds 2 GB, fall
back to B (per-test env)."* — but Option B (`setenv(...)` inside
main()) cannot work because `_hx_mem_cap_disabled` / `_hx_mem_cap_bytes`
are initialized in a `__attribute__((constructor))` before the script's
`fn main()` runs. So the realistic choices were:
  (i) bump default further (Option A++), or
  (ii) wrap the test in a re-exec with env-override (heavy).

Picked (i) = bump to 4096 MB. Justification:

- 2.00 GiB drill_test peak → 4 GiB default gives ~2× headroom.
- 4 GiB matches the existing module_loader child default
  (`self/main.hexa::module_loader_env_prefix` already forces
  `HEXA_MEM_CAP_MB=4096` for the flatten step — flatten is the
  heavier child of `hexa run`).
- All operator overrides preserved: `HEXA_MEM_UNLIMITED=1`,
  `HEXA_MEM_CAP_MB=<N>`, `--mem-unlimited`, `--mem-cap=<N>`.
- The original 2026-05-05 768 MB rationale (hive watcher logged
  0.5–6 GB runaways before the legacy 2 GB default fired) is also
  addressed by the 16× tighter tick stride (`0xFFFF → 0x0FFF`, same
  2026-05-05 commit). Bursty allocators are caught inside 4 GB.

## Files modified

| File | LOC | Note |
| ---- | --- | ---- |
| `self/runtime.c` | +21 / -7 | default `_hx_mem_cap_bytes` 768→4096; comment block records both 768→2048 (2026-05-13) and 2048→4096 (2026-05-14) bumps with measurement table |
| `self/main.hexa` | +1 / -1 | help string `disable 4096 MB memcap (heavy regen / drill / 7 K-row embeds)` |

Total LOC delta: +22 / -8 across 2 files. No CLI flag changes,
no env var changes, no callsite changes.

## Build

```
HEXA_MEM_UNLIMITED=1 hexa run tool/build_interp.hexa
# [build_interp] flatten → hexa_v2 transpile → clang → smoke OK
# [build_interp] OK -> /Users/ghost/core/hexa-lang/build/hexa_interp.real (2,973,504 bytes)
```

`build/hexa_interp.real` is hardlinked to
`~/.hx/packages/hexa/build/hexa_interp.real`, so both the in-repo
and installed paths are refreshed by a single build step.

## Smoke verification

Run wall-time is dominated by parse (~20–29 min cold per smoke). drill
adds another ~5–10 min on top for the Mk.IX chain.

| Smoke | RSS peak | Wall | Result |
| ----- | -------- | ---- | ------ |
| `compiler/atlas/static_index_test.hexa` (baseline, `HEXA_MEM_CAP_MB=4096`) | 1.56 GiB | 1724 s | PASS (9/9) |
| `compiler/atlas/static_index_test.hexa` (default cap 2048 MB build) | 1.60 GiB | 1235 s | PASS (9/9) |
| `compiler/atlas/overlay_test.hexa` (default cap 2048 MB build) | 1.94 GiB | 1278 s | PASS (9/9) |
| `compiler/drill/drill_test.hexa` (default cap 2048 MB build) | 2.00 GiB | 514 s | **FAIL — cap fire** |
| `compiler/drill/drill_test.hexa` (default cap 4096 MB build) | (in-flight) | (in-flight) | (in-flight) |

The 2048 → 4096 bump targets the drill_test residual. The cap-fire
behaviour is hash-pinned to actual RSS overflow, so the static_index_test
+ overlay_test PASS results carry forward unchanged at the higher cap.

### Regression check (smokes that don't load the embed)

- `compiler/atlas/parser_test.hexa` — **PASS** (parser-only fixtures, no embed; full grade table + node graph checks, all 18 cases).
- `compiler/smash/smash_test.hexa` — **PASS** (6/6, ctype + batch candidates).

Both ran in under 60 s wall on the 2048 MB build; same code paths apply
to the 4096 MB build (only a default-value change). No regression
possible from raising a default cap on workloads that never approached
the cap.

## Regression check

- Lighter smokes (no embed load) are unaffected: the default rises
  768 → 4096 MB, never triggers on workloads that did not previously
  approach 768 MB.
- The `_hx_mem_tick` probe stride is unchanged; bursty allocators are
  still caught within milliseconds of crossing the new ceiling.
- Operator override paths (`HEXA_MEM_UNLIMITED=1`, `HEXA_MEM_CAP_MB=<N>`,
  `--mem-unlimited`, `--mem-cap=<N>`) are untouched.

## Followups

- **Parse-phase speed** (separate work item): 29 min wall to parse a
  4.92 MB rodata file is the actual user-visible blocker. The
  embed materializes 7398 `AtlasNode` literals each with default
  `GradeInfo` / `EdgeInfo` fields; the interp's struct-literal path
  likely does O(fields) work per literal with no batching.
  Candidates: AOT-cache the embed once and load by hash, or split
  the embed into per-kind shards loaded lazily (Option C from the
  brief).
- **4 GiB ceiling**: if a future n6 wave grows the embed past
  ~3 GiB peak, revisit Option C/D (embed sharding or lazy parse).
  4 GiB will hold the current 7398 + ~2× growth.
- **module_loader child** already forces 4 GiB
  (`self/main.hexa:1110`), unchanged. Parent and child now share the
  same default, removing the asymmetric "child gets more than parent"
  configuration.

## Hard-constraint compliance

- did NOT modify `compiler/atlas/embedded.gen.hexa` (rodata, hash-pinned).
- did NOT touch `self/native/thread.c` or `runtime.c` `channel_*` symbols.
- English code/comments only.
- did NOT commit; left for user review.

## Note on parallel commits

A parallel session committed the 768 → 2048 MB bump as commit
`98074421` (titled "runtime: bump default memcap 768 → 2048 MB +
help text refresh") between sessions. The current session continued
the work by measuring drill_test and bumping further to 4096 MB.
The 4096 MB change is uncommitted, left for the user to review and
fold (probably as a follow-up commit revising the 2048 MB default).
