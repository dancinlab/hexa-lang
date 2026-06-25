# region-returns (F6 option A / A3) byteeq+perf verdict

**Date:** 2026-06-25
**Task:** Verify whether the in-tree `__hexa_val_region_returns_enabled` (region-promote on
fn-return) is a sound + faster alternate to `hexa_val_heapify` for the O(n²)-heapify Build wall.
**Host plan:** aiden BUSY (`build_aprime` pid 3989842 running) → summer. **No build was run** —
see verdict below (structural negative; a build would only reproduce a no-op toggle and burn the
shared pool 22+ min).

## VERDICT: UNSOUND-AS-A-TOGGLE / NOT-APPLICABLE on the production (x86_64-linux batch) emit path → REJECT for this purpose

The region-returns mechanism is **structurally unreachable** on the `--target=x86_64-linux-gnu`
native self-emit (the path that pays the 94.79% `hexa_val_heapify` self-time). It is NOT a process
env-var toggle on that path, so the "build once, run emit twice with env on/off" experiment cannot
produce a difference — sha(on) would byte-equal sha(off) and wall(on)≈wall(off) only because the
toggle **never fires**, not because the promote is byte-neutral. Escape-analysis remains the only
remaining major lever.

## Why (measured from source, file:line)

### The env var
- Toggle string: `__HEXA_ARENA_RETURN_REGION_ON__` / `__HEXA_ARENA_RETURN_REGION_OFF__`.
- **It is NOT a `getenv`/`hxlcl_getenv`.** It is the `env()` *builtin side-channel*: calling
  `env("__HEXA_ARENA_RETURN_REGION_ON__")` from hexa code is intercepted by
  `hexa_env_var()` (`self/runtime.c:11628`, prefix match `__HEXA_ARENA_` at :11634), op
  `RETURN_REGION_ON__` (:11657) sets `__hexa_val_region_returns_enabled = 1`. Setting it as a shell
  env var does nothing — no code reads it via getenv.

### Region-promote body exists (step 1 confirm)
- `HexaVal hexa_val_arena_heapify_to_parent(HexaVal v)` — `self/runtime_core.c:4566` (real body).
- `__hexa_fn_arena_return(HexaVal ret)` — `self/runtime_core.c:4605`; at :4622 it branches
  `if (__hexa_val_region_returns_enabled) return hexa_val_arena_heapify_to_parent(ret);` else the
  default `hexa_val_heapify` (malloc escape). Mechanism is genuinely compiled into every build
  (`static int __hexa_val_region_returns_enabled = 0`, runtime_core.c:3809).

### The ONLY activation site is darwin-stream-only
- The only hexa-side callers of the toggle are 4 lines in `compiler/codegen/stream.hexa`
  (:90 / :95 / :99 / :111), all gated behind `_stream_reclaim`.
- `_stream_reclaim` (stream.hexa:79) = `(env("HEXA_STREAM_RECLAIM")=="1") && (env("__HEXA_ARENA_ENABLED__")=="1")`.
- `stream.hexa::codegen_emit_streaming` is invoked by `compiler/main.hexa:759` **only when
  `stream_mode && target == "arm64-apple-darwin"`**. `stream_mode` is set solely by `HEXA_STREAM=1`
  or `--stream` (main.hexa:366-368, :456).
- The x86_64-linux self-emit (`tool/build_native_linux_x86_64:182-183`) passes
  `--target=x86_64-linux-gnu` with **no `--stream`**, so BOTH gates fail → the `else` *batch* branch
  (`lower_hir` + MIR optimizer, main.hexa:770+) always runs, and that branch never calls the region
  toggles. `__hexa_val_region_returns_enabled` stays 0 regardless of any env var.

### Doubly-blocked
1. Target gate excludes linux (`== "arm64-apple-darwin"` required).
2. `--stream`/`HEXA_STREAM=1` not passed by the build harness (and the streaming path also *skips
   the MIR optimizer*, so it is a different pipeline, not byte-identical to the release batch emit).

## Numbers
- env var used: `env("__HEXA_ARENA_RETURN_REGION_ON__")` builtin side-channel (NOT a shell env var;
  not engageable on x86_64-linux batch path).
- sha256(off) 16hex: n/a (build not run — toggle is a structural no-op on this path)
- sha256(on) 16hex: n/a (would byte-equal off only because toggle never fires)
- wall off→on %: n/a (would be ~0% by construction, not by soundness)
- peak RSS: n/a
- crash y/n: n/a (no build run)
- toggle engaged on production path: **NO — by construction.** This is the "if identical sha AND
  identical wall, the toggle may not have engaged — investigate the env name" outcome flagged in the
  task; investigation done: the toggle cannot engage on the x86_64-linux batch emit.

## One-line VERDICT
**REJECT** — region-returns is a darwin-`--stream`-only mechanism, structurally unreachable on the
x86_64-linux batch self-emit that owns the 94.79% heapify wall; it is not a drop-in env toggle there
and cannot be the O(n²) win. Escape-analysis (don't deep-copy values that provably don't escape the
callee) is the only remaining major lever — same conclusion as the #3939 frame-clean-skip
falsification, now with the alternate mechanism ruled out by construction rather than by SIGSEGV.

## Honest note / possible next round
If someone wants to *measure* the promote's soundness+perf on its native turf, it must be done on
**darwin-arm64** with `--stream HEXA_STREAM_RECLAIM=1 HEXA_VAL_ARENA=1`, comparing `--stream` reclaim
ON vs OFF — but note (a) that is a different (MIR-optimizer-skipping) pipeline, so it is not directly
comparable to the release batch emit, and (b) it does not touch the x86_64-linux Build wall this task
targets. Not pursued here (out of scope: linux host, batch path).
