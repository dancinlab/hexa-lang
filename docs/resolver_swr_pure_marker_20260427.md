# Resolver SWR + Pure-Marker Carve-Out — 2026-04-27 (hook policy)

## Trigger
`hive --dev` startup measured at 5502ms cold. `HIVE_TIMING=1
HIVE_STARTUP_BENCHMARK=1` localized 5017ms to `await changelogPromise` in
`InteractiveMode.init()` → `parseChangelogViaHexa()` →
`spawnSync("hexa", ["tool/changelog_parse.hexa", "CHANGELOG.md"], ..., timeout: 5000)`.
The 5s ceiling is the spawn timeout; the actual call was hitting the
resolver's blocking SSH connectivity probe (3s) plus tail latency on cold
caches.

## Root cause (two layers)
1. **Resolver blocking probe on cache miss.** `_probe_connectivity` at
   `~/.hx/bin/hexa` blocks up to ~3s when `CONN_CACHE` is missing or
   stale (>30s). Even with `HEXA_RESOLVER_NO_REROUTE=1` set by the
   caller, callers that *don't* set it pay the full miss cost — and any
   shell-level `hexa` invocation falls into this on stale state.
2. **`@omega-saturation-exempt` keyword set was darwin-native only.**
   The bypass at `_darwin_bypass_check` matched only
   `chflags|launchctl|sandbox-exec|DYLD|SBPL|plutil|codesign` — Linux
   container can't reproduce these. Pure text→struct extraction tools
   (changelog parse, manifest scan, lint families) are equally
   container-unsuitable but on a *different* axis: they don't need
   container semantics at all because they don't mutate anything. They
   were forced through the routing chain anyway.

## Fix (additive — no semantic regression on existing paths)

### F4. Stale-while-revalidate connectivity probe
- `_probe_connectivity` now returns the cached value *immediately* even
  when the file is past `CONN_TTL`, and spawns a disowned background SSH
  probe to refresh the cache for the next call.
- Only the first-ever invocation (no cache file) blocks on the probe.
- Opt-out: `HEXA_RESOLVER_SWR=0` falls back to the prior probe-on-miss.

### F5. `@resolver-pure` and operational-utility carve-out
- `_darwin_bypass_check` now accepts two new bypass signals:
  - `@resolver-pure(reason="…")` — explicit declarative marker; same
    bypass tier as `@resolver-bypass`. Documents intent ("this tool is
    non-mutating") separately from the darwin-native rationale.
  - `@omega-saturation-exempt(…)` whose reason text matches
    `(operational utility|pure[- ]text|single-pass|pure parse|read-only)`.
    Lets existing tools opt in without an extra annotation.
- Single `head -n 100` per script (was 2× before); 4 marker checks.

## Verification

### Startup (cold = all resolver caches cleared)
| Scenario               | Before  | After  | Δ      |
|---                     |---      |---     |---     |
| hive --dev (warm)      | 502ms   | 502ms  | —      |
| hive --dev (cold)      | 5502ms  | 635ms  | **8.7×** |
| HEXA_RESOLVER_FORCE_DOWN=1 | multi-sec | 654ms | unblocked |

### SWR sanity
- Stale cache, foreground call: returns immediately (~0.25s).
- Background `ssh hetzner true` runs disowned, updates `CONN_CACHE`
  ~3-12s later (depending on hetzner reachability).
- Verified: cache mtime updates after parent exit; bg ssh process
  visible in `ps` after parent returns.

### Bypass marker
- `tool/changelog_parse.hexa` carries
  `@omega-saturation-exempt("operational utility — single-pass execution; …")`.
- Routing trace: `route=darwin-bypass reason=darwin-native marker present`
  (matches the new operational-utility carve-out).
- Same script under `HEXA_RESOLVER_NO_REROUTE=1` already short-circuited
  at line 76 — F5 closes the gap for callers that don't set the env.

### Backward compat
- `--version`, `--help`, `lsp` still hit the darwin-bypass-marker path.
- `HEXA_RESOLVER_NO_REROUTE=1` short-circuit unchanged.
- Negative cache (60s, darwin-resolver-bypass) preserved.
- HEXA_PREFER_LOCAL_ON_HEXA preserved.
- Routing cache (5s positive TTL) preserved — F4 sits on the
  *connectivity* probe layer, not the routing layer.

## Out-of-scope findings (documented, not patched)
- `hexa` Mach-O dispatcher vs `hexa.real`: 0.43s vs 1.39s on the same
  script. The dispatcher uses `.hexa-cache/<hash>/exe` AOT cache;
  hexa.real is the raw interp. The wrapper already always routes to the
  dispatcher; hexa.real is fallback only. No fix needed.
- `.hexa-cache` cold (post-install or after aggressive `hexa gc`):
  changelog_parse.hexa cold compile = 3.76s. Pre-warming on install
  would help first-run latency but is a separate workstream.
- `/tmp/.hexa-runtime/hexa_expanded.*.tmp.hexa`: per-call preprocessed
  source, not a cache. The AOT cache absorbs the actual transpile cost,
  so additional caching here is low-ROI.

## Patch sites
- `/Users/ghost/.hx/bin/hexa` — in-place edit (per the
  resolver_routing_fix_20260427 pattern)
- Backup: `/Users/ghost/.hx/bin/hexa.bak_pre_swr_pure_20260427`
