# Step 3 cycle 76 — codegen typed-param + typed-source cast unlock

**Status**: codegen_c2.hexa edits LANDED in this commit; hexa_v2 binary
NOT YET rebuilt — fix is queued. Activation requires regenerating
`self/native/hexa_cc.c` (the pre-transpiled C source for hexa_v2) and
re-clanging the binary.

## What's queued

Three edits in `self/codegen_c2.hexa`:

1. **`_gen2_current_fn_param_types`** — new parallel array (next to
   `_gen2_current_fn_params`) holding each fn-param's declared type
   annotation. Populated at fn entry via `node.params[i].value` (the
   type-string field, same one read by `gen2_has_float_param`).

2. **`_gen2_param_type(name)` + `_gen2_param_is_int/_is_float(name)`**
   helpers. Returns the declared type or empty string.

3. **`_is_known_int_name` / `_is_known_float_name`** — extended to
   PROMOTE typed fn params instead of unconditionally bailing under
   the H17 fix. Now: typed-int param → known-int (unlocks
   `hexa_int(HX_INT(l) op HX_INT(r))` fast paths at L3934-3947);
   typed-float param → known-float symmetrically.

4. **`as` cast handler** — typed-source direct cast. `v as int` where
   `v` is known-float emits `hexa_int((int64_t)HX_FLOAT(v))`, where
   `v` is known-int emits no-op. Symmetric for `as float`. Closes
   the recursion trap that blocks porting `hexa_to_int`/`hexa_to_float`.

## What this unlocks

- **Hot-path arithmetic ports**: `hexa_cmp_lt/gt/le/ge`, `hexa_add/
  sub/mul/div`, `hexa_mod`, `hexa_eq` can now be ported as
  `pub fn rt_cmp_lt_int(a: int, b: int) -> bool { return a < b }` —
  codegen will emit direct `hexa_bool(HX_INT(a) < HX_INT(b))` instead
  of recursing through `hexa_cmp_lt`.

- **Polymorphic `to_int`/`to_float` ports**: `v as int` where v is
  typed-float now emits direct cast — no `hexa_to_int` recursion.

## Activation path

Needs `self/native/hexa_cc.c` regen via:
```
hexa_v2 self/main.hexa self/native/hexa_cc.c
```

The flatten step OOMs on macOS (~31GB target). **Recommended**:
ubu-2 fresh clone + transpile with `dist/linux-x86_64/hexa_v2`,
then `clang` per `tool/build_hexa_v2_linux.hexa` recipe.

After regen, `tool/build_aprime.sh` smoke + cycle 76+ ports of
hexa_cmp_lt etc. become possible.

## Verification once activated

```hexa
pub fn rt_cmp_lt_int(a: int, b: int) -> bool {
    return a < b
}
```

Expected generated C:
```c
HexaVal rt_cmp_lt_int(HexaVal a, HexaVal b) {
    return hexa_bool(HX_INT(a) < HX_INT(b));  // direct, no hexa_cmp_lt call
}
```

(Before the fix: `return hexa_cmp_lt(a, b);` — recursion.)

## Risk

Touches a load-bearing path in the compiler. Worst case if fix is
miscalibrated: typed-int param's `<` against a known-float operand
might emit `HX_INT(l) < HX_INT(r)` instead of going through
`hexa_cmp_lt` — would silently truncate the float operand. Mitigated
by the existing `_li && _ri` AND-check at L3934 (only when BOTH sides
are known-int does the fast path fire).

Symmetric for known-float fast path at L3954-3960.

## Cycle catalog

- c74: in-place mutation builtin unlock (`arr.truncate`/`arr[i]=v`)
- c75: type_of dispatch unlock (`type_of(v) == "T"`)
- **c76**: codegen typed-param + `as` cast unlock (THIS — queued)

Closes the 4 "real blockers" enumerated at cycle 72 wrap-up.
