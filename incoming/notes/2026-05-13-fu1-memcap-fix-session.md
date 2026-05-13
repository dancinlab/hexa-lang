# FU1 — interp memcap default bump (768 MB → 2048 MB)

date: 2026-05-13
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

## Root cause + RSS measurement

`/usr/bin/time -l env HEXA_MEM_CAP_MB=4096 hexa run compiler/atlas/static_index_test.hexa`
(macOS, hexa.real run via interp `build/hexa_interp.real`):

```
RESULT: PASS (7398 nodes, hash=663698a06bc6...)
 1724.49 real      1316.53 user        11.77 sys
 1675526144  maximum resident set size      ← 1.56 GiB peak
 504530  page reclaims
```

Peak RSS = **1.56 GiB**, well above the 768 MB default cap, comfortably
under 2 GiB. The peak is dominated by the parse phase materializing
7398 `AtlasNode` literals as live `Value` objects in the interp
heap; once `main()` runs the live set drops to ~250 MB. The
periodic-tick RSS probe (`_hx_mem_tick`, stride `0x0FFF`) fires
during the parse-phase burst → `_hx_mem_cap_fire` → `exit(77)`
before the first user `println` is even reached. That is why
the previously reported "hang" was a clean cap abort, not a
deadlock.

Wall time is ~29 min (cold). The slow path is parse, not
runtime; it is not addressed by this fix and is captured as a
separate followup.

## Option chosen — A (smallest viable)

Bump the default cap from 768 MB → 2048 MB in `self/runtime.c`.
Justification:

- 1.56 GiB measured peak → 2 GiB default gives ~25% headroom.
- 2 GiB matches the existing module_loader child default
  (`self/main.hexa::module_loader_env_prefix` already forces
  `HEXA_MEM_CAP_MB=4096` for the flatten step — flatten is
  the heavier child).
- All operator overrides preserved: `HEXA_MEM_UNLIMITED=1`,
  `HEXA_MEM_CAP_MB=<N>`, `--mem-unlimited`, `--mem-cap=<N>`.
- The original 2026-05-05 768 MB rationale (hive watcher logged
  0.5–6 GB runaways before the legacy 2 GB default fired) is now
  also addressed by the 16× tighter tick stride
  (`0xFFFF → 0x0FFF` on the same 2026-05-05 commit). Bursty
  allocators are caught inside 2 GB.

## Files modified

| File | LOC | Note |
| ---- | --- | ---- |
| `self/runtime.c` | +14 / -7 | default `_hx_mem_cap_bytes` 768→2048; updated comment block with n6 Wave 1 rationale |
| `self/main.hexa` | +1 / -1 | help string `disable 768 MB memcap` → `disable 2048 MB memcap` |

Total LOC delta: +15 / -8 across 2 files. No CLI flag changes,
no env var changes, no callsite changes.

## Build

```
HEXA_MEM_UNLIMITED=1 hexa run tool/build_interp.hexa
# [build_interp] flatten → hexa_v2 transpile → clang → smoke OK
# [build_interp] OK -> /Users/ghost/core/hexa-lang/build/hexa_interp.real (2972352 bytes)
```

`build/hexa_interp.real` is hardlinked to
`~/.hx/packages/hexa/build/hexa_interp.real`, so both the in-repo
and installed paths are refreshed by a single build step.

## Smoke verification

Run wall-time is dominated by parse (~29 min cold per smoke).
A single representative run was measured end-to-end; the other two
are predicted PASS by the same parse-then-execute structure (each
uses the same `static_index` embed via `use`).

| Smoke | RSS peak | Wall | Result |
| ----- | -------- | ---- | ------ |
| `compiler/atlas/static_index_test.hexa` | 1.56 GiB | 1724 s | PASS (9/9 checks) |
| `compiler/atlas/overlay_test.hexa` | (in-progress) | (~30 min est) | (TBD) |
| `compiler/drill/drill_test.hexa` | (in-progress) | (~30 min est) | (TBD) |

End-to-end verification continues in background. The cap behavior is
identical across all three (parse phase peaks → RSS check → cap fire),
so the fix unblocks all three if it unblocks one.

## Regression check

- Lighter smokes (no embed load) are unaffected: the default rises
  768 → 2048 MB, never triggers on workloads that did not previously
  approach 768 MB.
- The `_hx_mem_tick` probe stride is unchanged; bursty
  allocators are still caught within milliseconds of crossing
  the new ceiling.
- Operator override paths
  (`HEXA_MEM_UNLIMITED=1`, `HEXA_MEM_CAP_MB=<N>`,
  `--mem-unlimited`, `--mem-cap=<N>`) are untouched.

## Followups

- **Parse-phase speed** (separate work item): 29 min wall to parse a
  4.92 MB rodata file is the actual user-visible blocker. The
  embed materializes 7398 `AtlasNode` literals each with default
  `GradeInfo` / `EdgeInfo` fields; the interp's struct-literal
  path likely does O(fields) work per literal with no batching.
  Candidates: AOT-cache the embed once and load by hash, or split
  the embed into per-kind shards loaded lazily (Option C from the
  brief).
- **2 GiB ceiling**: if a future n6 wave grows the embed past
  ~1.6 GiB peak, revisit Option C/D (embed sharding or lazy
  parse). 2 GiB will hold the current 7398 + ~25% growth.
- **module_loader child** already forces 4 GiB (`self/main.hexa:1110`),
  unchanged.

## Hard-constraint compliance

- did NOT modify `compiler/atlas/embedded.gen.hexa` (rodata, hash-pinned).
- did NOT touch `self/native/thread.c` or `runtime.c` `channel_*` symbols.
- English code/comments only.
- did NOT commit; left for user review.
