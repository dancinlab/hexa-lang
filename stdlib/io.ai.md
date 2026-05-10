---
schema: hexa-lang/stdlib/io/1
last_updated: 2026-05-10
status: landed
module: stdlib/io.hexa
---

# stdlib/io — large-content text file I/O

## TL;DR

```hexa
use "stdlib/io"

let content = json.serialize(big_obj)         // 2 MiB+ ok
write_text("/tmp/foo.json", content)          // atomic, no fork
let echo = read_text("/tmp/foo.json")
```

## Why

orpheus-forge / ttr_ranker duckdb migration (2026-05-10) had 10 of 17
chokepoints deferred on **macOS ARG_MAX (~256 KiB)**: dumping 2 MiB+
JSON via the only path then available — `exec("python3 -c '...' > foo")` —
overflowed the shell exec argv limit and the call returned `E2BIG`.

`write_text` rides the interpreter builtin `write_file`, which is a
direct C `fwrite` on a `FILE*` (`self/runtime.c::rt_write_file`). No
subprocess, no argv, no ARG_MAX. Arbitrary size up to available RAM.

## Migration pattern

```hexa
// Before — exec + ARG_MAX block (silently truncates / aborts at ~256 KiB)
exec("python3 -c 'import json; print(json.dumps(...))' > /tmp/foo.json")

// After — no fork, no shell, atomic
let content = json.serialize(big_obj)
write_text("/tmp/foo.json", content)
```

## Surface

| function | signature | notes |
|---|---|---|
| `write_text` | `(path, content) -> bool` | atomic via `.tmp` + `mv` rename |
| `read_text` | `(path) -> string` | "" if missing, mirrors `read_file` |
| `write_text_atomic` | `(path, content) -> bool` | explicit alias of `write_text` |

## Atomic-write contract

1. `write_file(path + ".tmp", content)` — POSIX `fwrite`, full payload.
2. `mv path.tmp path` — invokes `rename(2)` which is atomic on the
   same filesystem.

Crash semantics:

- crash before step 1 finishes ⇒ `path.tmp` is partial or absent;
  `path` retains its previous committed content.
- crash strictly between (1) and (2) ⇒ `path.tmp` orphaned;
  `path` unchanged. Callers SHOULD sweep `*.tmp` on startup.
- crash during step 2 ⇒ atomic — observers see either the old or new
  inode, never a torn write.

## own 4 invariant

`write_text(path, content)` is content-neutral. It receives plaintext
and writes it verbatim. Serialization (json.serialize, yaml.dumps,
…) is the caller's responsibility.

## Caveats

- **NUL bytes**: hexa string semantics are C-string (NUL-terminated)
  at the runtime layer. Embedded `\0` truncates at write time. Use
  `write_file_bytes` (stdlib/bytes) for binary blobs.
- **Same-FS rename**: atomicity holds only when `path` and
  `path + ".tmp"` live on the same filesystem (they do by construction
  here — same parent directory).
- **No throw on failure**: `write_text` returns `false` on a missed
  `file_exists` post-check. The underlying builtin currently cannot
  surface `fwrite` errors short of a throw; downstream callers that
  need errno granularity should call `write_file` + `file_exists`
  directly.

## Cross-links

- self/runtime.c — `rt_write_file`, `rt_read_file`, `rt_file_exists`
- self/hexa_full.hexa — interpreter dispatch for `write_file` / `read_file`
- stdlib/test/test_io.hexa — selftest (1 MiB / 5 MiB / 10 MiB roundtrip,
  BOM, CRLF, atomic crash simulation)
- orpheus-forge ttr_ranker duckdb migration commit `9ed877a` (chokepoint
  ledger; 10 sites unblocked by this module)
