# `hexa run` (interpreter) hangs indefinitely on this Mac

**From:** wilson (downstream) — 2026-05-13. Filed because it blocked runtime-testing this
session's hexa-lang work (`hexa atlas promote` in `tool/atlas_cli.hexa`, the `*_smoke.hexa` /
`test_*.hexa` selftests). `hexa parse` and `hexa build` are unaffected and work fine.

## Symptom

`~/.hx/bin/hexa run <anything.hexa>` blocks forever. Even a trivial script:

```hexa
fn main() -> int { println("HEXA_RUN_OK 42"); return 0 }
```

```
$ timeout 15 ~/core/hexa-lang/hexa.real run /tmp/ht.hexa
$ echo $?
124        # ← timed out, no stdout/stderr emitted
```

Earlier in the same session, running a non-trivial wilson selftest produced this traceback
instead of hanging:

```
File "/Users/ghost/core/resource/tcp/run_remote.py", line 23, in request
    with connect(host, port) as sock:
ConnectionRefusedError: [Errno 61] Connection refused
```

…so two failure modes: hang on simple scripts, `ConnectionRefused` to a resource-TCP server
on scripts that hit certain imports/intrinsics. (The resource server **is** running —
`lsof -nP -iTCP:5555 -sTCP:LISTEN` shows `python ... 127.0.0.1:5555 (LISTEN)`. So whatever
`hexa run` actually wants either is on a different port or expects a worker pool that's down.)

## What I could see

- `~/.hx/bin/hexa` is a 1-line bash shim: `exec "$HOME/core/hexa-lang/hexa.real" "$@"`.
- `hexa.real` strings show it execs `$HEXA_LANG/build/hexa_interp` (also looks at `$HEXA_INTERP`,
  `./build/hexa_interp`, `/usr/local/bin/build/hexa_interp`). So `hexa run` ⇒ shell out to
  `build/hexa_interp <file>`.
- **No strings in `hexa.real` mention `run_remote` / `hexa-tcp` / `resource/tcp`.** So `hexa.real`
  itself doesn't offload — the offload must be coming from a `.hexa`-side intrinsic (or from
  `build/hexa_interp` itself).
- `hexa-tcp /tmp/ht.hexa` (the explicit resource-TCP wrapper) returns exit 0 but with no
  captured stdout (probably emits to the worker's stdout, not the caller's).
- This Mac's `~/core/hexa-lang/build/hexa_interp` may be stale relative to the current source
  tree (post-2026-05-11 toolchain promotion).

## Asks

1. **Diagnose the hang.** Is `hexa run` expected to exec `build/hexa_interp` directly, or to
   offload via `run_remote.py`? If the latter, why does the trivial script case hang silently
   (no `ConnectionRefused`) — read/write deadlock on the worker socket?
2. **A way to force the in-process path.** An env var (e.g. `HEXA_RUN_LOCAL=1`) or a flag
   (`hexa run --local <file>`) that bypasses any offload / always uses `build/hexa_interp`
   directly. Right now there's no documented escape hatch.
3. **A reliable `hexa cc` / `hexa build-interp` to rebuild `build/hexa_interp` from source** if
   that's the actual stale-binary fix. (Surface it in `hexa --help` if so.)
4. **Surface this in `hexa doctor`** (if there's a doctor) — "interpreter binary present /
   freshness / reachable" check.

## Impact

- `tool/atlas_cli.hexa` (incl. the new `hexa atlas promote`) is parse-clean but can't be runtime-
  tested here — `hexa atlas <anything>` runs via `hexa run`.
- All hexa-lang `*_smoke.hexa` / `test_*.hexa` selftests are blocked.
- Downstream `wilson` 's own selftests (`plugins/<id>/test_<id>.hexa`) are blocked.
- Compiled paths (`hexa build`, the built `wilson` binary itself) are fine — that's the canonical
  runtime, so wilson's own development isn't blocked. But anything interpreter-mediated is.

No wilson-side change; filing per the AGENTS.md hexa-lang handoff protocol.

## Update (later in the same session)

After re-checking the install:

- `~/core/hexa-lang/build/hexa_interp` is **not** a native binary — it's a
  shell shim (`build/hexa_interp` v5, 2026-05-12) that routes to either
  `$HOME/.hx/packages/hexa/build/hexa_interp.real` (the actual interp
  binary) or `$HOME/core/resource/bin/hexa-r ubu-1 run …` (resource-TCP
  offload). The hang was happening on the **offload path**.
- **The escape hatch already exists** — `RESOURCE_LOCAL_HEXA=1` makes the
  shim `exec "$REAL" "$@"` directly. Confirmed:
  ```
  $ RESOURCE_LOCAL_HEXA=1 ~/core/hexa-lang/hexa.real run /tmp/ht.hexa
  HEXA_RUN_OK 42
  ```
  So ask #2 is "document this, not invent it."
- The original hang turned out to be **transient** — on a later retry the
  resource-router path worked fine end-to-end (`hexa.real run /tmp/ht.hexa`
  → `HEXA_RUN_OK 42`, rc=0). Best guess: a stuck ssh socket / resource-r
  pool state cleared after a few minutes.

So the still-live asks are #3 (a `hexa build-interp` to reliably rebuild
`hexa_interp.real`) and #4 (`hexa doctor` should report interpreter
path / freshness / which routing arm is live). #1 (the hang) is "the
resource-router offload path is fragile under intermittent ssh failure;
a libtimeout + auto-fallback-to-local would close it." #2 has an answer
(`RESOURCE_LOCAL_HEXA=1`) — just needs to surface in `hexa --help` and
`hexa doctor`.
