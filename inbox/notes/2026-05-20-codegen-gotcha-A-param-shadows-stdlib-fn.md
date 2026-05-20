# Codegen Gotcha A — function parameter shadowed by stdlib fn-global

**Status:** FIXED (this branch)
**Discovery:** orbital Kepler pilot agent `a586b01f` · commit `2ffe3620`
**Severity:** silent codegen → broken C → clang error (compile-time, not runtime)
**Affected:** `self/codegen_c2.hexa` — 5 auto-wrap sites

## Symptom

User writes a `pub fn foo(e: float) -> float { ... double_it(e) ... }`.
Stdlib `stdlib/core/math/float.hexa` exports `pub fn e() -> float`.
Codegen emits:

```c
HexaVal foo(HexaVal e) {
    return double_it(hexa_fn_new((void*)e, 0));
    //                            ^^^^^^^^^^^^
    //                            wraps the local HexaVal as a fn-ref
}
```

clang rejects: "operand of type 'HexaVal' where arithmetic or pointer type is required".

Repro: `inbox/repros/2026-05-20-param-shadows-stdlib-fn-e.hexa`.

## Cause

Five sites in `self/codegen_c2.hexa` auto-wrap a bare `Ident` arg as
`hexa_fn_new((void*)<name>, 0)` whenever `_is_known_fn_global(name)`
returns true. The predicate scans **only** the module-global fn-name
set; it does NOT consult the per-function local scope
(`_gen2_current_fn_params`, `_gen2_current_fn_lets`). Any param/let
whose name collides with an exported stdlib top-level fn gets
incorrectly promoted to a fn-reference.

Sites (pre-fix line numbers):
- `:3389` — method `sort_by` arg (via `gen2_method_builtin`)
- `:4106` — struct-literal field value
- `:4844` — user-fn call argument
- `:5537` — method `sort_by` arg (inline path)
- `:5608` — indirect call (`hexa_callN`) argument

The contrasting site at `:3873` (bare-Ident `gen2_expr` arm) ALREADY
gates the fn-ref thunk on `!_gen2_name_in_cur_lets(name)` — that's
the pattern the 5 broken sites were missing.

## Fix

New helper `_gen2_should_autowrap_fnref(name)` centralizes the
predicate: returns true iff the name is a known fn-global AND not
shadowed by a current-fn param or let. The five auto-wrap sites
now call this helper instead of `_is_known_fn_global` directly.

```hexa
fn _gen2_should_autowrap_fnref(name) {
    if !_is_known_fn_global(name) { return false }
    if _gen2_name_in_cur_params(name) { return false }
    if _gen2_name_in_cur_lets(name) { return false }
    return true
}
```

## Verification

Pre-fix:
```
$ hexa_v2 repro.hexa /tmp/out.c
$ clang /tmp/out.c -> error: operand of type 'HexaVal' ...
```

Post-fix (after `hexa cc --regen` + rebuild):
```
$ hexa_v2 repro.hexa /tmp/out.c
$ clang /tmp/out.c -o /tmp/out
$ /tmp/out
1.8
```

Round-trip determinism preserved (`hexa_v2.new` produces byte-stable
output across runs). Self-host second-stage compile succeeded
(regen-of-regen reaches `compiled=yes`).

## Downstream consequence

The orbital Kepler kernel's `ecc:` parameter naming (chosen as a
workaround) is now legacy-stable rather than load-bearing — see
`stdlib/kernels/orbital/kepler_2body_kernel.hexa` comment update.

## Related

- Reconcile note: hexa-lang `inbox/notes/hexa-native-port-pattern-pilot.md` §5b
- Sibling fix (Gotcha B): `stdlib/core/math/wrap_pi.hexa` (new primitive)
