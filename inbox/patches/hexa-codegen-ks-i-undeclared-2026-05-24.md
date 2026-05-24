---
slug: hexa-codegen-ks-i-undeclared-2026-05-24
status: resolved
severity: P1
discovered: 2026-05-24
discoverer: claude/anima (HEXAD/PURE Phase D v3 fire unblock)
filed_from: anima (dancinlab/anima · HEXAD/PURE/launchers/dispatch_p21h_v3.hexa)
related: PR #380 (anima dispatcher smoke), PR #728 class (return-void mistranslate), B14 agent note (pre-existing dispatch compiler regression)
---

**Status (2026-05-24)**: RESOLVED — `self/codegen.hexa` `gen2_stmt` ReturnStmt
now short-circuits bare reserved `return void` / `return none` / `return nil`
to emit the void literal directly (`bt-void-return` guard), instead of routing
the reserved Ident through `gen2_expr` (which could return a value-arena string
whose backing buffer was reclaimed from a prior fn's index-tail expression,
leaking `hexa_index_get(ks, i)` with `ks`/`i` undeclared in the current C scope).

**Verification** (measured, this session):

| step | pre-fix compiler | fixed compiler |
|---|---|---|
| `void_return` emit C | `return __hexa_fn_arena_return(hexa_index_get(ks, hexa_int(0)))` | `return __hexa_fn_arena_return(hexa_void())` |
| `index_tail` emit C | correct | correct (no regression) |
| clang the emitted C | `error: use of undeclared identifier 'ks'` | object built ✅ |

Repro `/tmp/voidret_repro.hexa` (the 12-line standalone below) reproduces on the
pre-fix `self/native/hexa_v2` and lowers correctly after the fix. stdlib
`stdlib/alloc/json_object.hexa` (`json_object_get`/`json_object_get_path` — five
`if … { return void }` sites priming off `json_object_entries`'s `ks[i]`) uses the
identical ReturnStmt form the guard covers, so the anima Phase D v3 fire unblocks.

# codegen: `return void` mistranslated to leaked `hexa_index_get(<prev-fn-var>, ...)` — clang `use of undeclared identifier`

## Summary

`return void` inside a function is codegen'd to the **previous function's
cached index-get expression** instead of `hexa_void()`. The leaked C
references variables (`ks`, `i`) that are not in scope in the consuming
function → clang fails with `use of undeclared identifier 'ks' / 'i'`.

Blocks every `hexa run` / `hexa build` of any program whose flat bundle
contains `stdlib/alloc/json_object.hexa` (its `json_object_get` /
`json_object_get_path` use `return void`, and `json_object_entries`
earlier in the same file primes the cached `ks[i]` expression).

Concretely this blocks `HEXAD/PURE/launchers/dispatch_p21h_v3.hexa`
(anima Phase D v3 fire) — confirmed reproduces on unmodified main worktree.

## Minimal repro (12 lines, no imports, standalone)

```hexa
fn index_tail(obj) {
    let ks = dict_keys(obj)
    let i = 0
    let k = ks[i]          // primes codegen's cached index expr
    return k
}
fn void_return(x) {
    if x { return void }   // ← mistranslated
    return 1
}
fn main() { println("ok") }
```

`hexa run` →

```
error: use of undeclared identifier 'ks'
   return __hexa_fn_arena_return(hexa_index_get(ks, hexa_int(0)));
error: use of undeclared identifier 'i'
```

The two functions need NOT be adjacent — an intervening function with a
normal `return 42` does NOT clear the cached expression; the leak persists
until the next `return void` consumes it. Systemic, not localized.

## Generated C (verbatim)

`index_tail` is correct:

```c
HexaVal index_tail(HexaVal obj) {
    __hexa_fn_arena_enter();
    HexaVal ks = hexa_dict_keys(obj);
    HexaVal i = hexa_int(0);
    HexaVal k = hexa_index_get(ks, hexa_int(0));
    return __hexa_fn_arena_return(k);
    return __hexa_fn_arena_return(hexa_void());
}
```

`void_return` is corrupted — `return void` became the prior fn's index expr:

```c
HexaVal void_return(HexaVal x) {
    __hexa_fn_arena_enter();
    if (hexa_truthy(x)) {
        return __hexa_fn_arena_return(hexa_index_get(ks, hexa_int(0)));  // WRONG
    }
    return __hexa_fn_arena_return(hexa_int(1));
    return __hexa_fn_arena_return(hexa_void());
}
```

Expected: `return __hexa_fn_arena_return(hexa_void());`.

## Root cause (suspected)

The "trailing-if-expr void-return fix" tail-returnify path
(`self/codegen.hexa` ~L1530-1625 `_gen2_emit_tail_return_expr` /
`_gen2_emit_tail_returnify_body`, mirrored in `self/native/hexa_cc.c`)
appears to cache the last-emitted index/tail expression in a code-generator
field that is **not reset per-function**. A `return void` (an IfExpr/branch
tail whose value is `void`) then re-uses the cached expression instead of
emitting `hexa_void()`.

Same class as the cited PR #728 `return void` mistranslate.

## Trigger conditions (measured)

- A function whose body has an index-get expression (`xs[i]`, `ks[i]`,
  nested `pairs[i][0]`) — even as a non-final `let`-binding — primes the leak.
- A LATER function containing `return void` (bare or inside `if {}`)
  consumes the cached expression.
- `let i = 0` (immutable) → `i` constant-folds to `hexa_int(0)` but `ks`
  still leaks; `let mut i` → both `ks` and `i` leak.

## Why no sister-side (anima) workaround

The corrupted functions are stdlib `json_object_get` / `json_object_get_path`
(correct hexa source — `return void` is idiomatic). anima cannot:
1. edit stdlib (= hexa-lang change),
2. drop the import (dispatcher needs `HEXAD/CHAT/spontaneous_lib.hexa`),
3. avoid `return void` in stdlib.

The fire (`HEXA_LANG=$repo hexa run dispatch_p21h_v3.hexa`) stays blocked
until the codegen tail-return cache is reset per-function.

## Suggested fix direction

Reset the cached tail/index expression at function-decl entry in the
tail-returnify path, OR make the `return void` (void-valued IfExpr tail)
case emit `hexa_void()` unconditionally rather than falling through to the
cached-expression branch. Add the 12-line repro above as a codegen
regression fixture.
