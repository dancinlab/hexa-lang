# patch: hexa cloud — `cloud_cli.hexa` build false-fails on mac via shared-cache GC race

> Source: PWFORGE M6 (CaH6 NC-vs-NC cross-validation), 2026-06-01, driven from `mini`
> (sole management host). Per d8: a `hexa cloud`-discovered build/dispatch gap absorbed
> upstream instead of papered over in the campaign.

## Symptom

EVERY `hexa cloud <verb>` (pods · preflight · dispatch · run ...) fails before doing any
cloud work, because the dispatch first rebuilds the heavy `cloud_cli.hexa` and that build
reports a phantom failure:

```
error: `hexa build /Users/mini/.hx/bin/stdlib/cloud/cloud_cli.hexa` failed (compile error).
  [1/2] hexat ... → app.c   OK
  [2/2] clang -O2 ... -o '.../hexa_run.<sha>.tmp.NNNN'   (no diagnostic emitted)
error: clang compile failed — binary not produced: .../hexa_run.<sha>.tmp.NNNN
```

The cloud_cli source and its generated C are FINE: hexat emits `app.c` cleanly (`OK`),
and running the EXACT `[2/2]` clang line by hand on that same `app.c` succeeds in ~2.2 s
(exit 0, binary produced, 0 errors). Only the in-wrapper build reports "binary not produced".

## Root cause

`self/main.hexa::_hexa_clang_capped(cmd)` runs clang via `exec(cmd)` into a temp path under
`$HOME/.hexa-cache/`, then verifies success with `test -x '<tmp>'`. The same `.hexa-cache`
dir has an automatic GC (main.hexa ~L3261 "~/.hexa-cache automatic GC") that other concurrent
`hexa build` invocations trigger. When ≥1 other agent builds at the same moment (this host runs
several concurrent Claude/anima sessions), the GC prunes the just-written `<tmp>` binary in the
window between clang finishing and the `test -x` running → false "binary not produced".

`cloud_cli.hexa` is hit ~deterministically because its C is large (733 KB → ~2.2 s clang), giving
the widest race window; small modules (`hexa qforge --help`) usually win the race and pass.

Confirmed NOT the cause: (a) clang itself — manual compile of the identical app.c succeeds;
(b) the clang concurrency semaphore `/tmp/.hexa_clang_caps` — clearing a stale slot-0 token did
not fix it; (c) a code/version skew — 0 clang errors on the generated C.

Mac-specific aggravators found while probing:
- `HOME=/tmp/...` (isolated cache) → a DIFFERENT hard refusal: "hexa build REFUSED on Darwin
  — output under /tmp (panic trigger path)" (post-2026-04-20 kernel-panic guard). So /tmp is not
  a viable cache isolation on mac.
- `HEXA_MAC_BUILD_OK=1` bypass still false-fails via the same shared-cache GC race.

## Impact

On a multi-agent mac host, `hexa cloud` is effectively unusable for campaign dispatch — it cannot
even reach a read-only `pods` list. The documented fix ("build cloud_cli on a Linux pool host") is
unavailable when the pool hosts are down (summer/aiden: preflight rc=255 "workdir missing").

## Proposed fix (pick one; (1) is smallest)

1. **Make the post-clang check race-proof.** In `_hexa_clang_capped` (or the caller at
   main.hexa ~L3038), if `test -x <tmp>` fails, RE-CHECK once after re-running clang into a
   PID-unique path NOT subject to GC during the check (e.g. mktemp outside `.hexa-cache`, then
   atomically `mv` into the cache AFTER the existence check). Removes the GC window entirely.
2. **Exempt in-flight tmp outputs from the cache GC.** Have the GC skip any `hexa_run.*.tmp.*`
   younger than N seconds (it is an active build output, not a stale cached binary).
3. **Per-build private cache subdir.** Build into `$HOME/.hexa-cache/build-<pid>/` (GC-exempt),
   promote to the shared cache only on success — concurrent builds stop clobbering each other.

## Repro

```
# with ≥1 other `hexa build` running concurrently on the same host:
hexa cloud pods          # → "compile error / binary not produced"
# meanwhile, manually:
hexa build stdlib/cloud/cloud_cli.hexa >/dev/null 2>&1   # writes build/artifacts/app.c
clang -O2 -DHEXA_HAS_LIBSODIUM -I/opt/homebrew/include -DHEXA_HAS_OPENSSL \
  -I/opt/homebrew/opt/openssl@3/include -Wno-trigraphs -fbracket-depth=4096 \
  -I "$HOME/.hx/bin/self" build/artifacts/app.c \
  "$HOME/.hexa-cache/runtime.<sha>.o" -o /tmp/app_ok \
  -lpthread -L/opt/homebrew/lib -lsodium -L/opt/homebrew/opt/openssl@3/lib -lcrypto
# → exit 0, /tmp/app_ok produced. The wrapper's only difference is the GC-raced cache path.
```
