# incoming patch: stdlib-subsecond-sleep

> **id**: `stdlib-subsecond-sleep` · **opened**: 2026-05-11 · **status**: `applied` (2026-05-12)
> **trees**: `self/runtime.c`, `self/hexa_full.hexa`, `self/codegen_c2.hexa`, `self/native/{hexa_cc.c,hexa_v2}` (regen) — no stdlib `.hexa` change needed; the primitive is a runtime builtin.
> **why**: sub-second throttle in poll loops currently shells out (`exec("sleep 0.1")` — fork `/bin/sh` → `exec /bin/sleep` → `waitpid`, ~5-8 ms overhead per tick). wilson's `provider-claude-cli` poll loop at a 50 ms interval measured this fork churn at **~16 % of a core**. Need a no-fork sub-second sleep primitive.
> **reporter**: wilson (`provider-claude-cli` poll loop).

---

## Observed state (pre-patch)

- `sleep(n)` is integer-seconds (it accepts a float in `runtime.c`, but the interp dispatch in `self/hexa_full.hexa` truncates via `args[0].int_val` — so callers think "whole seconds only", and codegen had no sub-second helper exposed to throttle loops).
- `sleep_s(n)` exists (`hexa_sleep_s`, nanosleep-backed float seconds, 2026-04-19) — but it's float-seconds; the headline ask from wilson was a millisecond-int API for the common `sleep_ms(50)` / `sleep_ms(100)` throttle pattern.
- A `sleep 0.1` style sub-second wait therefore had to go through `exec(...)` (shell fork) — the thing this patch removes.

## Ask

1. Add a `sleep_ms(ms: int)` primitive backed by `nanosleep(2)` — no fork. `nanosleep` with `{ms/1000, (ms%1000)*1_000_000}`; negatives clamp to 0 (return immediately); loop on `EINTR` resuming with the remaining time.
2. (Optional, cheap) also add `sleep_ns(ns: int)` — same shape, nanosecond granularity.
3. Keep `sleep(n)` 100 % backward-compatible — don't touch its signature/behavior.
4. Wire it through all three surfaces: `self/runtime.c` (the C builtin), `self/hexa_full.hexa` (interp dispatch — `hexa run` uses the interpreter), `self/codegen_c2.hexa` (the `cg` builtin dispatch → `hexa_sleep_ms` / `hexa_sleep_ns` + the builtin-name recognition list). Regen `self/native/hexa_cc.c` + `hexa_v2` so the deployed/repo compiler emits the calls.
5. Test on both paths (interp + codegen/AOT); register; commit; push.

## Resolution (2026-05-12)

**Status**: `applied`.

- **API**:
  - `sleep_ms(ms: int)` — sleep `ms` milliseconds. `nanosleep` with `{ms/1000, (ms%1000)*1_000_000 ns}`. `ms <= 0` → returns immediately. Loops on `EINTR`, resuming with the remaining time so signal delivery doesn't shorten the sleep. Returns void. No fork.
  - `sleep_ns(ns: int)` — sleep `ns` nanoseconds. `nanosleep` with `{ns/1e9, ns%1e9}`. Same `EINTR`-resume + clamp-negatives semantics. Returns void. No fork.
- **Backing call**: `nanosleep(2)` (POSIX). Zero process creation — replaces the `exec("sleep 0.1")` fork (`/bin/sh` → `/bin/sleep` → `waitpid`, ~5-8 ms/tick) wilson's `provider-claude-cli` poll loop was paying at a 50 ms interval (~16 % of a core).
- **Files touched**:
  - `self/runtime.c` — `hexa_sleep_ms(HexaVal ms)` / `hexa_sleep_ns(HexaVal ns)` next to `hexa_sleep_s`.
  - `self/hexa_full.hexa` — interp dispatch for `sleep_ms` / `sleep_ns` next to `sleep_s` (mirrors how `sleep` / `sleep_s` are dispatched).
  - `self/codegen_c2.hexa` — `gen2_expr` 1-arg builtin dispatch (`sleep_ms` → `hexa_sleep_ms`, `sleep_ns` → `hexa_sleep_ns`), plus the `_is_builtin_name` recognition list (mirrors `sleep_s`).
  - `self/native/hexa_cc.c` + `self/native/hexa_v2` — regenerated via `hexa cc --regen` from the SSOT modules.
  - `self/test_sleep_ms.hexa` — new regression test (timing windows for `sleep_ms(120)` / `sleep_ns(50_000_000)` + `sleep_ms(0)` immediate + `sleep_ms(-5)` clamp + `sleep(0)` backward-compat). 5/5 PASS on both backends.
  - `incoming/PATCHES.yaml` — this entry.
- **`sleep(n)` untouched** — signature + behavior preserved.

## Once done — what unblocks (wilson side, not yours)

- wilson `provider-claude-cli` (and any other poll/throttle loop) swaps `exec("sleep 0.1")` → `sleep_ms(100)` (or whatever interval) — no fork per tick. ~16 %-of-a-core saving on the measured 50 ms loop.
- `~/.hx/bin/hexa_real` re-promote recommended so deployed-binary interp callers (`hexa run`) get `sleep_ms` immediately; `hexa build` consumers already get it via the repo's regenerated `hexa_v2` + `self/runtime.c`.
