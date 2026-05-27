# r15-D20 `(start..end).rev()` iterator — ARCHIVED not-reproducible (2026-05-24)

**Status**: ARCHIVED — not-reproducible on current `origin/main`
**Reporter**: PROBE r15 cycle 2 (D20 surgical assignment)
**Severity reported**: medium (range iterator semantics)
**Surface**: hexa compiler · codegen · `.rev()` Rust-canonical alias for ranges

## Original claim

PROBE r15-D20 reported that `(0..5).rev()` yielded only `0` instead of the
expected reverse sequence `4, 3, 2, 1, 0`. Forward `0..5` and inclusive
`0..=5` were noted as PASS.

## Repro attempt

Built `probe_rev.hexa` at `/tmp/probe-r15/range/probe_rev.hexa`:

```hexa
fn main() {
    for x in (0..5).rev() {
        println(x)
    }
}
```

Build via `HEXA_LANG=<repo> hexa build probe_rev.hexa -o probe_rev` on
`origin/main` @ `cab38f6e`. Actual output:

```
4
3
2
1
0
```

Forward regression (`probe_fwd.hexa` — `for x in 0..5 { s = s + x.to_string() + "," }`)
emits `0,1,2,3,4,` as expected — no regression.

## Root analysis — already fixed upstream

`self/codegen.hexa:3735-3740` (and sibling at `6649-6653`):

```hexa
// Rust canonical alias — `.rev()` on an iterator/range produces reversed
// iteration. Range values materialize to arrays in hexa, so it routes
// through the same array-reverse runtime.
if method == "rev" {
    return "hexa_array_reverse(" + obj_expr + ")"
}
```

Generated C (from `build/artifacts/probe_rev.c:12`):

```c
HexaVal __iter_arr = hexa_array_reverse(hexa_range_array(hexa_int(0), hexa_int(5), hexa_void(), 0));
```

`hexa_range_array` materializes `[0,1,2,3,4]`; `hexa_array_reverse`
(`self/runtime_core.c:4976`) reverses to `[4,3,2,1,0]`; the for-in
iterator walks the array → emits `4 3 2 1 0`.

The fix landed in **PR #351** (`dcb5c9b4 fix(codegen): .rev() — Rust
canonical alias for .reverse()`), pre-dating the r15-D20 PROBE assignment.
Both method-dispatch sites in `codegen.hexa` already handle `rev`.

## Conclusion

No fix required. The r15-D20 PROBE report is stale — it describes the
pre-PR-#351 state, not current `origin/main` (`cab38f6e`). Filing as
inbox archive note rather than a code patch so the PROBE log can close
this deviation.

## Sibling

`inbox/patches/hexa-return-void-mistranslate-2026-05-24.md` (B14 saga —
also resolved-already, archived 2026-05-24 PR #733).
