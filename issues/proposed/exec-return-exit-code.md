# runtime: `exec()` must surface the subprocess exit code (+ stderr), not just stdout

## Summary

`exec()` currently yields only the subprocess's **stdout**. A caller that
needs to branch on whether the subprocess *succeeded* — a probe, a
capability check, a connectivity test — has no way to read the exit
status. Add an `exec` form that returns the exit code (and stderr):

```hexa
fn exec_full(cmd: string) -> map   // { "rc": int, "stdout": string, "stderr": string }
```

**Provenance**: downstream handoff — `inbox/notes/2026-05-23-sidecar-pool-route-hexa-port-requirements.md`, gap **G3**.
**Signal kind**: runtime-builtin-gap.
**Severity to request**: blocker — the only outstanding gap with **no
workaround**. A whole correctness-bearing branch class is unrepresentable
in `.hexa` today.

## Motivation

Observed surface (sidecar `hooks/pool-route/bin/_pool_route.hexa` 0.3.0):
the only `exec` idiom is `to_string(exec("cat"))` — stdout, coerced to a
string. The subprocess exit status is discarded; there is no `exec`
variant that returns it.

That is fine for "run a command and read its output". It is **wrong** for
the large class of subprocess calls whose *output is the exit code*:

- `ssh <host> test -d <dir>` — does the directory exist on the remote?
- `tailscale status` — is the tailscale daemon up?
- `git diff --quiet` — is there a staged change?
- any `… && echo ok` dance is a stringly-typed workaround for a missing
  integer return.

The concrete driver is the sidecar `pool-route` `.hexa` port (restoring
the `wilson-pool` `_route.py` auto-router). Its **preflight** step runs
`ssh <host> test -d <workdir>` and must distinguish **three** outcomes,
each with a different routing decision:

| exit code | meaning | action |
|-----------|---------|--------|
| `0` | workdir present | route the command to the host |
| `1` | ssh connected, workdir absent | run locally; cache "missing" |
| `255` | ssh transport failure (host asleep / network blip) | skip routing once; do **NOT** cache — a transient failure must not silently bench the host for the session |

`stdout` is empty for all three. With stdout-only `exec()` the port can
only guess — and a wrong guess means a heavy build silently runs on the
wrong machine or a good host gets dropped. There is no string-level
workaround: the distinction *is* the exit code.

## Repro

Forward-looking blocker, not an existing failing call site — the sidecar
`pool-route` port has not been started *because* of this gap. To see it:

1. Try to express, in `.hexa`, "run `ssh h test -d /x`; if rc==0 do A, if
   rc==1 do B, if rc==255 do C".
2. There is no API that returns rc. `exec()` returns stdout (empty here).
3. The three branches collapse into one — the port stalls.

## Proposed signature

```hexa
// Run `cmd` via the shell; return its result. `rc` is the process exit
// status (conventionally 127 = not-found, 255 = ssh/transport failure).
fn exec_full(cmd: string) -> map   // keys: "rc" (int), "stdout" (string), "stderr" (string)
```

Minimal subset, if a full struct is too much for one change — a code-only
form covers the pool-route preflight need on its own:

```hexa
fn exec_rc(cmd: string) -> int     // just the exit status
```

Existing `exec()` stays as-is (stdout-returning) for source compatibility;
`exec_full` / `exec_rc` are additive.

## Migration

- The `… && echo ok` / `… ; echo $?` stringly-typed probes across the
  ecosystem collapse to a direct `exec_full(cmd)["rc"]` integer test.
- The sidecar `pool-route` port (handoff note G3) unblocks: preflight,
  transport detection, and any future host probe become expressible.

## Out of scope (follow-ups)

- Streaming / long-running process control (`spawn` / `wait` / pipes) —
  separate concern; the one-shot `exec_full` covers the probe class.
- A typed result struct instead of a `map` — nice, but a `map` matches
  the existing `json_parse` return shape and needs no new type surface.

## Evidence anchors

- `inbox/notes/2026-05-23-sidecar-pool-route-hexa-port-requirements.md` — gap G3, the full downstream spec.
- `_route.py` preflight logic — `git show ca62ff4:plugins/wilson-pool/bin/_route.py` in the `sidecar` repo (`preflight_ok`, the rc 0 / 1 / 255 handling).
- Current stdout-only idiom — `sidecar` `hooks/pool-route/bin/_pool_route.hexa` (`to_string(exec("cat"))`).
