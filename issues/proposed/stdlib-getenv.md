# stdlib: `getenv(name) -> string` for environment-variable access

## Summary

hexa has no native way to read an environment variable. A caller that
needs one must shell out — `exec("printenv NAME")` — a fork+exec for a
value the process already holds in its own environment. Add:

```hexa
fn getenv(name: string) -> string   // value, or "" when unset
```

**Provenance**: downstream handoff — `inbox/notes/2026-05-23-sidecar-pool-route-hexa-port-requirements.md`, gap **G2**.
**Signal kind**: stdlib-gap.
**Severity to request**: high — blocks a clean sidecar `pool-route` port;
the `exec("printenv")` workaround is a fork+exec per variable and (absent
the sibling `exec-return-exit-code` fix) cannot even tell "unset" from
"the printenv call failed".

## Motivation

A `.hexa` program runs inside an environment the harness populated, but it
cannot read it. Any hook or tool that must locate harness-provided state
needs at least one env var:

- `CLAUDE_PLUGIN_DATA` — where a plugin's data (config, caches) lives.
- `CLAUDE_PLUGIN_ROOT`, `HOME`, `PATH` — standard path resolution.

The only route today is `exec("printenv NAME")`:

```hexa
let data_dir = to_string(exec("printenv CLAUDE_PLUGIN_DATA"))
// fork + exec + a shell, per variable; trailing newline to trim;
// an unset var and a failed call both yield "" — indistinguishable.
```

The concrete driver is the sidecar `pool-route` `.hexa` port: it must read
`$CLAUDE_PLUGIN_DATA` to find `pool.json` (the host roster) and the `.rr`
round-robin counter. Routing every Bash command through a `printenv`
subprocess first — just to learn one path — is the wrong shape.

## Repro

Forward-looking blocker — the sidecar `pool-route` port has not started.
To see the gap: try to read `CLAUDE_PLUGIN_DATA` in `.hexa`. There is no
`getenv`; the only expression is `exec("printenv CLAUDE_PLUGIN_DATA")`,
which is a subprocess hop and conflates unset-vs-error.

## Proposed signature

```hexa
// Returns the value of environment variable `name`, or "" if unset.
fn getenv(name: string) -> string

// Optional convenience — saves the `== "" ? default : v` dance.
fn getenv_or(name: string, fallback: string) -> string
```

Backed by `getenv(3)` in the runtime layer. No shell, no fork.

## Migration

- `exec("printenv X")` call sites collapse to `getenv("X")` — no
  subprocess, no newline-trim, and unset is unambiguously `""`.
- The sidecar `pool-route` port (handoff note G2) unblocks.

## Out of scope (follow-ups)

- `setenv` / a full environment map — not needed for the read case;
  separate proposal if a writer ever wants it.

## Evidence anchors

- `inbox/notes/2026-05-23-sidecar-pool-route-hexa-port-requirements.md` — gap G2, the full downstream spec.
- Sibling issue — `issues/proposed/exec-return-exit-code.md` (G3); together they unblock the port.
- `_route.py` env reads — `git show ca62ff4:plugins/wilson-pool/bin/_route.py` in the `sidecar` repo (`CLAUDE_PLUGIN_DATA` lookup).
