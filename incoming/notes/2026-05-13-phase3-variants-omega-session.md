# Phase 3 drill variants — omega-axis session (A10-A13)

**Date:** 2026-05-13
**Branch:** main (working dir only — no commit)
**Scope:** A10 omega, A11 surge, A12 dream, A13 swarm

## Summary

Ported the four omega-axis drill variants from `~/core/nexus/cli/run.hexa`
into `compiler/omega/`, `compiler/surge/`, `compiler/dream/`, `compiler/swarm/`.

Each variant exposes a single public entry point that returns a typed
result struct (so smoke tests can assert behaviour without parsing
stdout) plus the upstream helper surface (caps, seed/engine parsing,
signal extraction, breeding, top-k selection, etc.).

## Per-variant ledger

| ID  | Variant | Source LOC (run.hexa) | Ported LOC (main+test) | Smoke result          | Deferred items                            |
|-----|---------|-----------------------|------------------------|-----------------------|-------------------------------------------|
| A10 | omega   | ~115 (4063-4176)      | 268 + 110 = 378        | 5/5 PASS              | drill_run shim, chain shim, debate shim   |
| A11 | surge   | ~200 (4176-4373)      | 237 + 105 = 342        | 5/5 PASS              | drill_run shim, chain shim                |
| A12 | dream   | ~92  (4373-4465)      | 299 + 124 = 423        | 7/7 PASS              | drill_run capture shim (signal scrape)    |
| A13 | swarm   | ~170 (4593-4762)      | 330 + 134 = 464        | 8/8 PASS              | drill_run capture shim                    |

**Total new LOC:** 1607 (4 main files: 1134, 4 smokes: 473).

## drill_run integration

All four variants currently use a **local shim** for the inner drill
round — `drill_run_shim(...)` (omega/surge) and `drill_run_shim_capture(...)`
(dream/swarm). The shims are deterministic, emit a recognizable stderr
line for traceability, and produce the minimal stdout proxy that the
signal extractors need.

When the parallel drill BG lands `compiler/drill/drill::drill_run(...)`,
each variant becomes a one-line swap. The `TODO(drill-bg-completion)`
marker is placed at every shim call site:

```
compiler/omega/omega.hexa  : drill_run_shim, chain_run_shim
compiler/surge/surge.hexa  : drill_run_shim, chain_run_shim
compiler/dream/dream.hexa  : drill_run_shim_capture
compiler/swarm/swarm.hexa  : drill_run_shim_capture
```

The shim surface mirrors the expected drill export shape
`drill_run(seed, rounds, depth, speculate) -> rc` (omega/surge) and
`drill_run_capture(seed, rounds, depth, speculate) -> stdout_string`
(dream/swarm). Once drill lands, swap body to `use "compiler/drill/drill"`
and forward.

## Coordination

- `self/main.hexa` untouched (verified via `git diff --name-only self/main.hexa`)
- No edits to existing `compiler/<x>/` modules
- No edits to parallel-BG dirs (drill, chain, reign, molt, wake, forge,
  canon, debate, revive) — only `compiler/atlas/overlay` and `compiler/dream/dream`
  imported (the latter for `dream_extract_signal` reuse from swarm)
- Nexus repo read-only (verified `git status` in `~/core/nexus` untouched)

## Internal cross-dep

`compiler/swarm/swarm.hexa` imports `compiler/dream/dream` to reuse the
`dream_extract_signal` parser (mirrors upstream `_dream_extract_signal`
shared by both `cmd_dream` and `cmd_swarm`). Both modules live in the
A10-A13 BG, so no inter-BG coordination needed.

## Cap policy normalisation

Each variant honours both `HEXA_*_MAX` (canonical) and `NEXUS_*_MAX`
(legacy) env vars, with HEXA winning on conflict. Defaults match
upstream:

- `HEXA_SURGE_MAX` / `NEXUS_SURGE_MAX` → 12
- `HEXA_DREAM_MAX` / `NEXUS_DREAM_MAX` → 3 (ceiling 10)
- `HEXA_SWARM_MAX` / `NEXUS_SWARM_MAX` → 12
- `HEXA_SEED_CAP`  / `NEXUS_SEED_CAP`  → 280 (clamped [30, 1000])

## Verification

```
$ for v in omega surge dream swarm; do
    hexa run compiler/$v/${v}_test.hexa 2>&1 | grep -E "^RESULT:|^[0-9]+/"
  done

5/5 PASS    omega    RESULT: PASS (omega A10 — dispatch matrix)
5/5 PASS    surge    RESULT: PASS (surge A11 — Cartesian fan-out + cap)
7/7 PASS    dream    RESULT: PASS (dream A12 — self-seed orchestrator)
8/8 PASS    swarm    RESULT: PASS (swarm A13 — population evolutionary)
```

Total: **25/25 PASS** across the 4 variants.
