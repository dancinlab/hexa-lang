# `hx` bootstrap + registry fetch 404 on `pkg/` path · `pool` unregistered in SSOT

**Status**: fixed — `tool/pkg/hx:10` REGISTRY_REMOTE and
`tool/pkg/install.hexa:6` hx_url both repointed to `main/tool/pkg/…`
(curl verified 200). `pool 0.5.0` and `wisp 0.1.0` rows added to
`tool/pkg/registry.tsv`.

**Severity**: high (fresh-machine `hx` install is broken — both the
bootstrap `curl` URL and the registry fetch URL 404; any new user
running the documented one-liner gets a 0-byte `hx` binary and no
package index).

**Reporter**: sidecar / pool (dancinlab/sidecar · dancinlab/pool —
downstream consumers, do not edit hexa-lang source).

## Symptoms

Two distinct gaps, surfaced together while shipping `pool 0.5.0`
(`hx install pool` → registry shows `0.4.0`):

| # | gap | impact |
|---|---|---|
| 1 | `tool/pkg/hx:10` — `REGISTRY_REMOTE="…/main/pkg/registry.tsv"` 404s; actual file is at `tool/pkg/registry.tsv` | fresh machine with no local `~/.hx/bin/registry.tsv` falls through to remote → empty registry → `hx install <anything>` fails |
| 2 | `tool/pkg/install.hexa:6` — `hx_url = "…/main/pkg/hx"` 404s; actual file is at `tool/pkg/hx` | the documented one-liner `curl -sL <url> \| bash` writes a 0-byte `hx` binary; bootstrap silently fails |
| 3 | `tool/pkg/registry.tsv` — no `pool` row (also no `wisp` row) | pool's own manifest claims `ssot = "github.com/dancinlab/pool (\`hx install pool\`)"` but the canonical registry doesn't list it |

Both URL bugs share the same root cause: the `pkg/` → `tool/pkg/`
path migration left stale hard-coded URLs in two places.

## Repro

```
$ curl -sL -o /dev/null -w "%{http_code}\n" \
    https://raw.githubusercontent.com/dancinlab/hexa-lang/main/pkg/registry.tsv
404
$ curl -sL -o /dev/null -w "%{http_code}\n" \
    https://raw.githubusercontent.com/dancinlab/hexa-lang/main/pkg/hx
404
$ curl -sL -o /dev/null -w "%{http_code}\n" \
    https://raw.githubusercontent.com/dancinlab/hexa-lang/main/tool/pkg/registry.tsv
200
$ curl -sL -o /dev/null -w "%{http_code}\n" \
    https://raw.githubusercontent.com/dancinlab/hexa-lang/main/tool/pkg/hx
200
```

## Proposed fix (one `chore(registry)` commit)

| file | line | change |
|---|---|---|
| `tool/pkg/hx` | 10 | `…/main/pkg/registry.tsv` → `…/main/tool/pkg/registry.tsv` |
| `tool/pkg/install.hexa` | 6 | `…/main/pkg/hx` → `…/main/tool/pkg/hx` |
| `tool/pkg/registry.tsv` | append | `pool\t0.5.0\tbin/pool\thttps://github.com/dancinlab/pool\t\tminimal host roster + remote exec · pool init bootstrap · pool clean two-tier disk-cleanup` |

(Optional companion: register `wisp` the same way — same SSOT absence
pattern.)

After the fix: re-bootstrap with the documented one-liner; verify
`hx install pool` lands `0.5.0` from a freshly-cleared
`~/.hx/bin/registry.tsv`.

## Why an inbox patch (not a direct commit)

`main` ↔ active feature branch `cloud-dir-fetch-2026-05-23` is +42
commits with uncommitted compiler-internals work (`self/codegen_c2`,
`self/parser`, `self/runtime.h`, `self/native/hexa_v2`); a registry
chore branched off main from this state would either rebase across
that WIP or pollute the feature branch. Filing here so the fix can
land cleanly when the in-flight work is at a natural cut-point.

## Anchors

- `tool/pkg/hx:10` (REGISTRY_REMOTE)
- `tool/pkg/install.hexa:6` (hx_url)
- `tool/pkg/registry.tsv` (SSOT — wilson · sidecar add pattern in git log: `0955eda5`, `9047de50`)
- `github.com/dancinlab/pool@0.5.0` (shipped 2026-05-23, commit `cfd00b2`)
