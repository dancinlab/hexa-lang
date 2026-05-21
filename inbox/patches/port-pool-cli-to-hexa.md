# Port `pool` CLI to hexa

**Source**: dancinlab/pool
**Kind**: patches
**Status**: `resolved-ssot 2026-05-21 — option (a) DOCUMENTED. Canonical
example landed at stdlib/alloc/json_cli_pattern_test.hexa (7 falsifiers
measured PASS on Mac smoke). It exercises every primitive the pool port
needs end-to-end: read_file → json_parse → json_object_get_array →
json_object_set / json_array_push (mutate) → json_dump_pretty → write_file
→ json_parse roundtrip. No new hexa-lang code required for the port —
the stdlib/alloc/json.hexa + stdlib/alloc/json_object.hexa surface is
sufficient. Downstream pool.hexa port mirrors the 6-verb implementations
(pool_list / pool_status / pool_add / pool_set_state / pool_rm) verbatim.
See §Resolution at bottom.`

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

---

## Resolution 2026-05-21

### Closed

- **Option (a) — document the existing surface** chosen (preferred per
  patch). Canonical example landed at `stdlib/alloc/json_cli_pattern_test.hexa`
  (NEW, ~220 LoC). It is both a Mac smoke test (7 falsifiers measured
  PASS) AND an executable documentation of the pattern.
- The example covers ALL six pool verbs (add · list · on · rm · off · status)
  in <100 LoC of pool-specific code on top of the existing stdlib JSON
  surface — confirming the port surface is feature-complete on the
  hexa-lang side.

### Primitives map (patch sketch → actual hexa primitive)

The patch's example sketch used some primitive names that don't quite
match the canonical hexa surface. The actual canonical names:

| Patch sketch                            | Actual hexa primitive                              | Notes |
|-----------------------------------------|----------------------------------------------------|-------|
| `fs_read(path) -> str`                  | `read_file(path) -> string`                        | `self/std_fs.hexa`'s `fs_read` wrapper currently dormant — its `__builtin_fs_*` codegen target doesn't exist. Use `read_file` (canonical, runtime builtin). |
| `fs_write(path, content)`               | `write_file(path, content)`                        | Same as above. |
| `exec_capture(cmd) -> [out,err,exit]`   | `exec_capture(cmd)`                                | Already canonical; see `codegen_c2.hexa:4409`. |
| `argv -> [str]`                         | `args() -> [string]`                               | Canonical. |
| `json_parse(str)`                       | `json_parse(text)`                                 | Runtime builtin (`codegen_c2.hexa:4417`). Returns `map | array | scalar | void`. |
| `json_field(root, "k")`                 | `root["k"]` or `json_object_get(root, "k")`        | Native index OR void-safe variant. |
| `json_array(json_field(root,"hosts"))`  | `json_object_get_array(root, "hosts")`             | Returns `[]` if not array — defensive. |
| `json_pretty(v) -> str`                 | `json_dump_pretty(v, 2)`                           | 2-space indent canonical. |

### Falsifier results (Mac smoke)

```
=== json_cli_pattern_test (pool.hexa canonical reference) ===
  PASS: F-JSON-POOL-PATTERN-PARSE
  list (initial):
    ubu-1  10.0.0.21  [on]
    ubu-2  10.0.0.22  [off]
    mini   10.0.0.30  [on]
  PASS: F-JSON-POOL-PATTERN-LIST (n=3)
  PASS: F-JSON-POOL-PATTERN-ADD (+summer → n=4)
  PASS: F-JSON-POOL-PATTERN-MUTATE (ubu-2 → on)
  PASS: F-JSON-POOL-PATTERN-REMOVE (-mini → n=3)
  status: on=2 off=1 other=0 total=3
  PASS: F-JSON-POOL-PATTERN-ROUNDTRIP (n=3 preserved)
  PASS: F-JSON-POOL-PATTERN-DISKIO (read_file ↔ write_file ↔ json_parse ↔ json_dump_pretty)
=== ALL FALSIFIERS PASS ===
```

### Downstream port instructions (for dancinlab/pool)

The `bin/pool.hexa` port should:
1. `use "stdlib/alloc/json"` + `use "stdlib/alloc/json_object"`
2. Mirror the verb implementations from
   `stdlib/alloc/json_cli_pattern_test.hexa::pool_{list,status,add,set_state,rm}`
   — they ARE the reference implementations
3. Wrap them with an `args()`-driven dispatch loop (see
   `stdlib/cloud/cloud_cli.hexa:main` for the canonical pattern)
4. Load + persist `~/.pool/pool.json` via `read_file` / `write_file`

### Carve-outs

- **`fs_*` aliases**: the `self/std_fs.hexa` wrappers (`fs_read`,
  `fs_write`, etc.) are currently dormant — they target an
  `__builtin_fs_*` codegen layer that doesn't exist. If anima/wilson/
  pool downstream prefer the `fs_*` naming, a follow-up patch can
  wire the wrappers to the existing `read_file` / `write_file`
  builtins (one-line per fn). Not in scope here.
- **Schema validation**: the example does shape-tolerant access
  (`json_object_get_str(host, "addr", "?")` with defaults). If the
  port wants stricter validation (reject pool.json missing required
  fields), it can layer that on top — orthogonal.
- **6-verb scope**: the patch explicitly restricts pool to the 6
  verbs (no autosync / tailnet / workdir / transport). The example
  matches that scope; advanced verbs are out of scope per patch.

