# `arr.shift()` — CODEGEN ERROR (unknown builtin method)

**Filed by:** wilson. ROI audit 2026-05-14 (f3 forbidden pattern in `dancinlab/wilson` AGENTS.tape).

**Date:** 2026-05-14.
**Severity:** ergonomic; minor — only one or two known callsites in wilson (harness-cli input buffer). Filing for completeness.

## Reproducer (compiled mode)

```hexa
fn main() {
    let mut xs: [int] = [1, 2, 3, 4]
    let first = xs.shift()
    println("first=" + str(first) + " rest=" + str(xs))
}
```

```
$ hexa build /tmp/test_shift.hexa -o ./test_shift && ./test_shift
CODEGEN ERROR: unknown builtin method: shift
```

The transpile succeeds (parser accepts `.shift()`) but `codegen_c2.hexa`'s `gen2_method_builtin` has no arm for `shift`, so it falls through to the `unknown builtin method` error path at runtime via the `(fprintf(stderr, "CODEGEN ERROR: unknown method"), exit(1), hexa_void())` shim at `codegen_c2.hexa:4551`.

## Symmetry note

`arr.pop()` exists (`hexa_array_pop`); `arr.shift()` is the obvious mirror (remove from front instead of back).

## Fix

Add a codegen arm next to `pop` (`codegen_c2.hexa:2570` and the second site `:4489`):
```hexa
if method == "shift" {
    return "hexa_array_shift(" + obj_expr + ")"
}
```

And a runtime impl in `self/runtime.c` next to `hexa_array_pop`:
```c
HexaVal hexa_array_shift(HexaVal arr) {
    if (!HX_IS_ARRAY(arr) || HX_ARR_LEN(arr) == 0) return hexa_void();
    HexaVal first = HX_ARR_ITEMS(arr)[0];
    // shift items left, decrement length (mirror hexa_array_pop's in-place semantic)
    for (int i = 0; i < HX_ARR_LEN(arr) - 1; i++) {
        HX_ARR_ITEMS(arr)[i] = HX_ARR_ITEMS(arr)[i + 1];
    }
    HX_SET_ARR_LEN(arr, HX_ARR_LEN(arr) - 1);
    return first;
}
```

Stability matters: like `pop`, `shift` should mutate in place AND return the removed element (so callers can chain).

## Test

```hexa
let mut xs: [int] = [10, 20, 30]
let a = xs.shift()       // a == 10
assert(len(xs) == 2)
assert(xs[0] == 20)
let b = xs.shift()       // b == 20
assert(len(xs) == 1)
let c = xs.shift()       // c == 30
assert(len(xs) == 0)
let d = xs.shift()       // d == void (empty)
```

## Related

- AGENTS.tape (wilson) f3 — still active as of 2026-05-14.
- `~/core/wilson/plugins/harness-cli/` — likely the main wilson site that would use it once available.
