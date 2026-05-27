# Wilson codegen fixes — session note

**Date:** 2026-05-13.
**Scope:** 3 codegen bugs filed by wilson (`inbox/patches/wilson-build-broken-pool-openai-compat.md`,
`inbox/patches/wilson-fn-arena-escapes-on-push.md`). Verified with minimal repros and
a full `~/core/wilson` rebuild from `git checkout main`.

## Summary

| Bug | Status | File:line | Repro |
|-----|--------|-----------|-------|
| A — `float(x)` builtin emitted as `hexa_call1(float, …)` | FIXED in this session | `self/codegen_c2.hexa:3854-3863` | `/tmp/wilson_float_repro.hexa` → `0.7` |
| B — `pool_invoke_propose` etc. undeclared in flattened C | NOT REPRODUCIBLE — current main already handles forward-decl emit | n/a | `/tmp/wilson_forward_ref.hexa` → `42`, full wilson build → `wilson 0.0.1` |
| C — fn-arena escape on `array.push(<struct literal>)` | ALREADY FIXED upstream (runtime promotion via `hexa_val_heapify`) | `self/runtime.c:1855-1864` | `/tmp/wilson-repro13.hexa` → `i=2 role=tool` |

## Bug A — `float()` builtin coercion

### Root cause

`self/codegen_c2.hexa::gen2_expr` had explicit dispatch for `int(x)` (line 3842)
and `str(x)` (3851) builtin coercions but `float(x)` fell through to the user
fn-call path at line ~3884. That path emitted `hexa_call1(float, arg)` — `float`
is a C reserved keyword, so clang rejected the `_Generic` macro expansion.

The interpreter already had `float` as a coercion (matches the `as float` /
`to_float` paths). The C codegen had `hexa_to_float` (used by `to_float(x)` at
line 3334 and `as float` at 3169) but no direct `float(x)` emit.

### Fix

`self/codegen_c2.hexa:3854-3863` — added the missing handler mirroring `str(x)`:

```hexa
if name == "float" {
    return "hexa_to_float(" + gen2_expr(node.args[0]) + ")"
}
```

LOC delta: +10 (including comment header).

### Deploy

- Regenerated `self/native/hexa_cc.c.new` via `hexa cc --regen`.
- Compiled to `/tmp/hexa_v2.new`, copied over `self/native/hexa_v2`.
- `hexa.real` (the dispatcher binary) invokes `hexa_v2` as a subprocess; no
  rebuild needed at the dispatch level.

### Repro

```sh
$ cat > /tmp/wilson_float_repro.hexa <<'EOF'
fn main() -> int {
    let opts = #{"temp": "0.7"}
    let t = float(opts["temp"])
    println(t)
    return 0
}
EOF
$ HEXA_MAC_BUILD_OK=1 hexa build /tmp/wilson_float_repro.hexa -o /tmp/wfr
$ /tmp/wfr
0.7
```

Inspected generated C: `HexaVal t = hexa_to_float(hexa_index_get(opts, __hexa_sl_0));`
— no `hexa_call1(float, …)` anywhere.

## Bug B — pool_invoke_propose / pool_cmd_pool undeclared

### Investigation

Filed symptoms were:
```
build/artifacts/wilson.c:22713:50: error: use of undeclared identifier 'pool_invoke_propose'
build/artifacts/wilson.c:22716:50: error: use of undeclared identifier 'pool_invoke_propose_list'
build/artifacts/wilson.c:23281:50: error: use of undeclared identifier 'pool_cmd_pool'
```

After fixing Bug A and regenerating `hexa_v2`, ran a clean wilson build from
`git checkout main`:

```sh
cd ~/core/wilson
export HEXA_LANG=~/core/hexa-lang HEXA_SHIM_NO_DARWIN_LANDING=1 HEXA_MAC_BUILD_OK=1
hexa build core/main.hexa -o /tmp/wilson_test
```

Result: build succeeded. Inspection of `build/artifacts/wilson.c`:

- Line 935: `HexaVal pool_invoke_propose(HexaVal payload);` — forward decl
- Line 938: `HexaVal pool_invoke_propose_list(HexaVal payload);` — forward decl
- Line 940: `HexaVal pool_cmd_pool(HexaVal payload);` — forward decl
- Line 27288: actual definition of `pool_invoke_propose`
- Line 27405: actual definition of `pool_cmd_pool`

The existing `gen2_fn_forward` pass at `codegen_c2.hexa:824` already emits forward
declarations for every `FnDecl` AST node before any body emission, so single-file
forward refs (whether intra-file or post-flatten cross-file) work. The
`module_loader.hexa` topological-walk flatten correctly carries non-`pub` fns
into the merged source.

Minimal forward-ref repro confirms single-file forward refs work:

```sh
$ cat > /tmp/wilson_forward_ref.hexa <<'EOF'
fn caller() -> int { return callee() }
fn callee() -> int { return 42 }
fn main() -> int { println(caller()); return 0 }
EOF
$ HEXA_MAC_BUILD_OK=1 hexa build /tmp/wilson_forward_ref.hexa -o /tmp/wfr2 && /tmp/wfr2
42
```

### Conclusion

Bug B is **not reproducible on current main**. Likely either:

1. The filing snapshot pre-dated a forward-decl emit fix that has since landed
   (`gen2_fn_forward` pass is well-established).
2. Bug A's `hexa_call1(float, …)` error came first and the wilson session never
   reached the "pool_invoke_propose" stage — clang fails fast and earlier errors
   masked the absence of later ones. After fixing Bug A the build completes
   cleanly.

No fix needed on hexa-lang side. Wilson rebuild is unblocked.

## Bug C — fn-arena escape on array.push

### Status

Already fixed upstream by a prior session (runtime-level promotion option A).
See `self/runtime.c:1855-1864`:

```c
// FIX 2026-05-13 (wilson-fn-arena-escapes-on-push): when pushing into an
// array whose item buffer lives on the heap (cap >= 0), and we're inside a
// live fn-arena scope (mark_top > 0), the item being pushed may have been
// allocated in the *current* fn's arena and will be freed on
// __hexa_fn_arena_return — leaving a dangling handle in the heap array. Run
// heapify on the item so its underlying storage is promoted to the heap
// before insertion.
if (HX_ARR_CAP(arr) >= 0 && __hexa_val_mark_top > 0) {
    item = hexa_val_heapify(item);
}
```

### Verification

The minimal 21-line repro from the patch (`/tmp/wilson-repro13.hexa`) passes
both `hexa run` (interp) AND `hexa build && /tmp/r` (AOT):

```
$ /tmp/r
i=0 role=user
i=1 role=assistant
i=2 role=tool
```

No segfault. Bug C is closed.

## Regression check

| Test | Result |
|------|--------|
| `compiler/atlas/static_index_test.hexa` | PASS (7398 nodes, hash=663698a0…) |
| `compiler/smash/smash_test.hexa` | PASS (6/6) |
| `compiler/honesty/check_test.hexa` | PASS |
| `compiler/drill/drill_test.hexa` | (slow; HEXA_MEM_UNLIMITED required — not awaited) |

3/3 awaited PASS. No regressions from the float-builtin addition (additive
dispatch entry, no removed code paths).

## Wilson rebuild

| Build | Path | Result |
|-------|------|--------|
| In-tree test (`/tmp/wilson_test`) | hexa-lang dir | OK — `wilson 0.0.1`, full bundle visible |
| Wilson's own build (`~/core/wilson/build/Darwin-arm64/wilson`) | wilson dir | OK — built at 16:33, all 26 plugins enumerated |

Wilson is unblocked for E2 (binary rebuild) and E4 (ubu wilson dispatch).

## Hexa-lang LOC delta

- `self/codegen_c2.hexa`: +10 lines (Bug A handler)
- `self/native/hexa_v2`: rebuilt artifact (no source change beyond the +10)
- No changes to `self/runtime.c` (Bug C was already fixed; Bug B no fix needed)

Total: **+10 source LOC, 1 rebuilt binary**.

## Remaining wilson-side issues beyond these 3 patches

None observed in this session — `wilson --version` runs clean, all 26
plugins enumerate including `pool` and `provider-openai-compat`.

## Working tree state (NOT COMMITTED — left for user review)

```
M  self/codegen_c2.hexa          (the +10 LOC Bug A fix)
M  self/native/hexa_v2           (rebuilt binary)
```

Plus pre-existing tree noise (lexer.hexa, tui/input.hexa, etc.) untouched
by this session.
