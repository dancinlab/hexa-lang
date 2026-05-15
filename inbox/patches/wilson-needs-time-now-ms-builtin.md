# Stdlib gap: expose `time_now_ms` builtin so user-side hexa can read ms-precision time

**Filed by:** wilson. Discovered while trying to bump the spinner from 1 Hz to
5 Hz (200 ms cell). Sister gap to the bidi-stdio patch (`wilson-mcp-needs-
bidi-stdio.md`); both fall in the same category — runtime has the C primitive,
the public hexa surface doesn't.

**Date:** 2026-05-13.
**Severity:** small (cosmetic — spinner stays at 1 Hz which is fine), but the
primitive is general-purpose. Anything that wants sub-second timing (animation,
throttling, latency measurement, debounce) needs it.

## What we have

- `timestamp()` — whole-second precision (`hexa_timestamp` C impl).
- `self/std_time.hexa` declares `time_now_ms()` but references
  `__builtin_time_now_ms` which **doesn't exist in self/runtime.c**:

```
build/artifacts/wilson.c:12363:46: error: use of undeclared identifier '__builtin_time_now_ms'
```

The runtime DOES have `hexa_time_ms` (self/runtime.c:8759) — it's just not
wired to the `__builtin_time_now_ms` symbol that std_time.hexa expects.

## What's needed

One of:

**A. Wire the existing `hexa_time_ms` to the builtin name.** In the codegen
table (wherever `__builtin_timestamp` etc. land), add `__builtin_time_now_ms`
→ `hexa_time_ms`. Probably one line.

**B. Expose `time_ms` (the existing C symbol) in the stdlib whitelist** and
have std_time.hexa call `hexa_time_ms()` directly (drop the `__builtin_` prefix).

**C. Add a `timestamp_ms()` parallel to `timestamp()` directly in the
implicit stdlib** — what wilson's `core/portability.hexa` calls for `timestamp`,
`spawn_bg`, `exec_with_status`, etc.

Either way, the result is: hexa user code can call `time_now_ms()` (or
`timestamp_ms()`) and get a monotonic-or-wall-clock integer in milliseconds.

## Use cases

- Wilson harness-cli: 200 ms-cell spinner animation (5 Hz cycle for `· ✢ ✳ ✶ ✻ ✽`)
- Cooperative yield throttling that's more precise than `sleep_ms(50)` polling
- Performance measurement / benchmarks
- Token-counter smooth easing (Claude Code does this at 50 ms tick)
- Rate-limit clients (anything that needs "calls per second" pacing)

## Workaround (in place)

Wilson currently uses `timestamp()` for the spinner tick. 1 Hz cycle = visibly
animated but slower than Claude Code's 20 fps. Acceptable for v1.

## Status — APPLIED (2026-05-13)

Fix landed in `self/codegen_c2.hexa` ~ line 3937 — extended the existing
builtin-name intercept that already maps `timestamp` / `now` / `time_now` to
`hexa_timestamp()`. New entries:

```hexa
if name == "timestamp" || name == "now" || name == "time_now" || name == "__builtin_time_now" { return "hexa_timestamp()" }
if name == "time_now_ms" || name == "now_ms" || name == "timestamp_ms" || name == "__builtin_time_now_ms" { return "hexa_time_ms()" }
```

So user-side `time_now_ms()`, `now_ms()`, `timestamp_ms()`, AND the wrapper
in `self/std_time.hexa` (which calls `__builtin_time_now_ms`) all resolve
to the existing `hexa_time_ms` C function. No runtime.c change needed.

**Requires hexa_v2 rebuild** to take effect (codegen change). Once deployed,
wilson can switch the spinner from 1 Hz `timestamp()/secs` to 5 Hz
`time_now_ms()/200`-cell — one-line change in wilson harness-cli.

## Wilson commit that hit this

`wilson f6...` (sprint 3) — tried to import `self/std_time`, compile failed
with the undeclared `__builtin_time_now_ms`. Reverted to `timestamp()` and
filed this.

넣었다.
