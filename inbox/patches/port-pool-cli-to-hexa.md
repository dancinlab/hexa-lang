# Port `pool` CLI to hexa

**Source**: dancinlab/pool
**Kind**: patches
**Status**: filed

## Context

`pool` (https://github.com/dancinlab/pool) is a minimal host roster + remote-exec CLI shipped as a Python single-file (~140 lines, zero deps) at `bin/pool`. It is consumed via `hx install pool`. The Python is a deliberate prototype — the target is a hexa-native single-file at `bin/pool.hexa`, built with `hexa build` and installed as the `pool` shim.

## What's needed from hexa-lang

The port blocks on the stdlib JSON read+write surface. A survey of what `bin/pool.hexa` will need from hexa stdlib:

| primitive | stdlib path | status |
|---|---|---|
| `fs_read(path) -> str` | `self/std_fs.hexa` | ✅ available |
| `fs_write(path, content)` | `self/std_fs.hexa` | ✅ available |
| `exec_capture(cmd) -> [stdout, stderr, exit]` | `stdlib/cloud/cloud.hexa` pattern | ✅ available |
| `argv -> [str]` (`sys.argv` style) | `self/std_*.hexa` | ✅ available |
| JSON parse `str -> JsonValue` | `stdlib/alloc/json.hexa` | 🟡 public API surface needs to be documented (single-step example: parse pool.json into a hosts array) |
| JSON emit `JsonValue -> str` (pretty) | `stdlib/alloc/json.hexa` | 🟡 same |

## Ask

Document or add a thin convenience wrapper for the two JSON ops the pool port needs:

```hexa
// rough sketch
let txt: str = fs_read("/path/to/pool.json")
let root: JsonValue = json_parse(txt)
let hosts: [JsonValue] = json_array(json_field(root, "hosts"))
// ... mutate ...
fs_write("/path/to/pool.json", json_pretty(root) + "\n")
```

Either:
- (a) Document the existing `stdlib/alloc/json.hexa` surface (smallest delta) — preferred.
- (b) Add a thin `stdlib/json_io.hexa` wrapper that pairs `fs_read` + parse and emit + `fs_write` into two convenience functions.

## Acceptance

A 1-file `pool.hexa` (`hexa build bin/pool.hexa -o bin/pool`) reproducing the Python prototype's six verbs (add · list · on · rm · off · status) end-to-end against the same `~/.pool/pool.json` schema lands at https://github.com/dancinlab/pool .

## Out of scope

- pool's PreToolUse / SessionStart Claude-Code hooks (these live in `dancinlab/sidecar` as a separate plugin, future work).
- pool's advanced verbs (autosync / tailnet / workdir / transport) — pool stays at 6 verbs.

## Related

- https://github.com/dancinlab/pool/blob/main/TODO.md (port tracker)
- `stdlib/cloud/cloud_cli.hexa` (~620 lines, lands the structured-argv dispatch pattern in hexa — closest existing reference for a single-file hexa CLI).
