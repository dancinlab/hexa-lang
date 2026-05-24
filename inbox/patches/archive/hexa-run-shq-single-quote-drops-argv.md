# `hexa run` silently drops any argv entry containing a single quote

**Status**: fixed — `self/main.hexa::shq` now POSIX-escapes via
`"'" + s.replace("'", "'\\''") + "'"` (Option 1, design's recommended
root fix). Verified: argv now reads `[-m, it's broken, after]`; 3 edge
cases (`a'b'c`, `'lead`, `trail'`) pass.

**Severity**: high (silent argv corruption — wrong data, no crash; any
`hexa run <script> <args…>` where an arg contains `'` is affected)

**Affected**: `self/main.hexa` — `fn shq()` (line ~1003) and every
`hexa run` dispatch path that quotes extra args through it: `cmd_run`
(line ~2717-2723), the build-then-exec path (~2642-2646), and the
bash/shim exec paths (~1165-1219). `hexa build` + direct binary exec
not affected (no `shq` round-trip).

**Reporter**: sidecar (dancinlab/sidecar — downstream consumer, does
not edit hexa-lang source)

## Repro

```hexa
// probe.hexa
fn main() {
    let a = argv()
    let mut i = 0
    while i < len(a) { println(to_string(i) + ": [" + a[i] + "]"); i = i + 1 }
}
```

```
$ hexa run probe.hexa -m "it's broken" after
error: shq arg contains single quote (unsupported)
0: [/Users/…/.hexa-cache/hexa_run.1779480795489513000]
1: [-m]
2: [after]
```

Expected `argv[2] = it's broken`, `argv[3] = after`. Actual: the
single-quote arg is **gone** and `after` shifted into `argv[2]`. The
process still exits 0 — the corruption is silent past the one stderr
line.

## Root cause

`shq()` is single-quote *wrap* only, and on encountering a `'` it
prints an error and `return ""`:

```hexa
fn shq(s) {
    let mut i = 0
    while i < len(s) {
        if s.substring(i, i + 1) == "'" {
            println("error: shq arg contains single quote (unsupported)")
            return ""
        }
        i = i + 1
    }
    return "'" + s + "'"
}
```

The `hexa run` dispatch concatenates that return value straight into
the command string:

```hexa
let mut cmd = shq(tmpbin)
while ai < len(extra_args) {
    cmd = cmd + " " + shq(extra_args[ai])   // shq → "" for the bad arg
    ai = ai + 1
}
let out = exec(cmd + " 2>&1; echo \"__HEXA_SHIM_RC__=$?\"")
```

A `""` from `shq` collapses `… + " " + "" + …` to a bare space, so the
argument vanishes from the command line entirely; the shell then
re-tokenizes with one fewer argv entry. `return ""` makes a malformed
input *silently corrupt the run* instead of aborting it.

## Impact

Hit in production: sidecar's `/ship -m "<commit message>"` wraps
`hexa run …/_ship.hexa -m "<msg>" <paths…>`. A commit message with an
apostrophe (`doesn't`, `don't`, `it's`) is dropped from argv, so the
first file path slides into the `-m` slot — producing a commit whose
message is a file path and whose file set is missing one file.

## Suggested fix (design only — sidecar does not edit hexa-lang)

1. **Proper POSIX escaping** (root fix) — replace the `shq` body so a
   `'` is escaped, not rejected: wrap in `'…'` and rewrite each `'` as
   `'\''`. Reference implementation already exists downstream —
   `dancinlab/sidecar` `skills/ship/bin/_ship.hexa` `fn _shq()` does
   exactly this and is correct; hexa-lang's `shq` can adopt it
   verbatim.
2. **Minimum viable** — if escaping is deferred, `shq` must fail loud:
   `exit(1)` (or propagate an error) instead of `return ""`, so a bad
   arg aborts the run rather than silently corrupting argv.
3. **Deepest fix** — give `exec`/the `hexa run` dispatch an
   argv-array exec form (no shell round-trip), so argv forwarding
   needs no shell quoting at all. The `2>&1` + `__HEXA_SHIM_RC__=$?`
   capture would need a non-shell equivalent.

Option 1 is the clean root-cause fix and is low-risk (the escaping
idiom is well-known and already battle-tested in `_ship.hexa`).

## honest C3

- Downstream operational report; the root cause is traced to
  `main.hexa:1003` + the `cmd_run` concatenation, but the maintainer
  should confirm the bash/shim exec paths (~1165-1219) share the same
  `shq` surface before fixing — they call `shq` identically.
- The `return ""` → silent-drop is the dangerous part; even without
  full escaping, switching to a hard abort removes the silent-
  corruption class.
- sidecar never edits hexa-lang source — this file lives at
  `~/core/hexa-lang/inbox/patches/` per the upstream-downstream
  invariant (commons `@D g11` — file the gap, fix at source).

## Cross-link

- `dancinlab/sidecar` `skills/ship/bin/_ship.hexa` — the `/ship`
  mechanical tail that surfaced the bug; its `fn _shq()` is the
  correct reference escaping
- `dancinlab/sidecar` `CHANGELOG.md` 2026-05-23 — inject 0.1.2 ship,
  during which the malformed-commit symptom was first observed
