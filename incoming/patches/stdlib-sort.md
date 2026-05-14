# Stdlib gap: `sort_by` missing; `arr.sort()` is numeric-only

**Filed by:** wilson. ROI audit 2026-05-14 found stable-sort-by-key is the only genuine hexa-lang gap among the three originally flagged (the map.remove and nested-mutation findings turned out to be stale docs — compiled runtime is fine).

**Date:** 2026-05-14.
**Severity:** ergonomic + small perf. Forces hand-rolled insertion sort in plugin code; downgraded from "S-tier" after measurement (wilson event_bus sorts ~5-10 element subscriber lists, so O(n²) is fine in absolute terms — call this "A-tier polish").

## Current state

`arr.sort()` exists (`self/runtime.c:3901` `hexa_array_sort`, qsort-based) but the comparator at `self/runtime.c:3894` only handles int/float:

```c
static int hexa_sort_cmp(const void* a, const void* b) {
    HexaVal va = *(const HexaVal*)a, vb = *(const HexaVal*)b;
    if (HX_IS_INT(va) && HX_IS_INT(vb)) return HX_INT(va) < HX_INT(vb) ? -1 : HX_INT(va) > HX_INT(vb) ? 1 : 0;
    if (HX_IS_FLOAT(va) && HX_IS_FLOAT(vb)) return HX_FLOAT(va) < HX_FLOAT(vb) ? -1 : HX_FLOAT(va) > HX_FLOAT(vb) ? 1 : 0;
    return 0;   // strings, structs, maps — all sort to identity, silently
}
```

Verified: `[3,1,2].sort() == [1,2,3]` ✓ but `["c","a","b"].sort() == ["c","a","b"]` ✗ (silently unsorted).

`sort_by(arr, key_fn)` doesn't exist in stdlib. `arr.sort_by(fn)` method form isn't codegen'd either (no entry in `codegen_c2.hexa` near line 2579 nor in `codegen_c2_v2.c`).

## Where wilson hand-rolls it

`~/core/wilson/core/event_bus.hexa:135` `_sort_by_priority_desc()` — stable insertion sort over `[Sub]` by `.priority` (descending). Called from `eb_on()`; ~50 calls during session boot with n ≤ ~10. Real cost is modest (~50ms session boot in worst case, often less).

Likely future call sites once stdlib lands:
- ordering registered tools by registration time
- ranking endpoint try[] fallback chain
- governance principle priority resolution

## Fix options

**A. Extend `hexa_sort_cmp` + add `arr.sort_by(fn)` method.** Two-part:

1. Make the comparator handle strings (lexicographic via `strcmp`) and probably structs (by first comparable field — or just return 0 / leave it to `sort_by`).
2. Add `hexa_array_sort_by(HexaVal arr, HexaVal key_fn)` in `runtime.c` + codegen entry near the existing `sort` arm in `codegen_c2.hexa:2579` and `codegen_c2_v2.c`. Pattern matches `hexa_array_map(arr, fn)` (already plumbed via `hexa_call1`).

   The qsort approach doesn't compose well with a closure (qsort comparator can't capture state cleanly across Mac/Linux without `qsort_r`'s portability dance). Cleanest impl: precompute keys via `hexa_call1(key_fn, item)` for each element, then run a stable in-place merge sort over an `(item, key)` parallel array.

3. Stability matters: wilson event_bus relies on stable equal-priority order. Document that `sort_by` is stable; `sort` (qsort) is not.

**B. Just add `sort_by` (ignore the int/string bug for now).** Cheaper if (A.1) is contentious. Wilson's main pain is `sort_by`.

**C. Ship as pure-hexa stdlib (`stdlib/sort.hexa`).** No runtime/codegen change; write merge sort in hexa-lang. Slower than C qsort but available immediately. Wilson `use`s it.

Wilson preference: **A** for the right long-term fix, but **C** is a fine 1-day stopgap if **A** needs scheduling.

## Test that should pass after fix

```hexa
struct Item { name: string, prio: int }
let xs: [Item] = [
    Item{name:"a", prio:1},
    Item{name:"b", prio:3},
    Item{name:"c", prio:1},   // ties "a"; must come AFTER "a"
    Item{name:"d", prio:3},   // ties "b"; must come AFTER "b"
]
let sorted = xs.sort_by(fn(it: Item) -> int { return -it.prio })  // descending
assert(sorted[0].name == "b")
assert(sorted[1].name == "d")    // stable
assert(sorted[2].name == "a")
assert(sorted[3].name == "c")    // stable
```

Plus: `["c","a","b"].sort() == ["a","b","c"]` (after fixing the cmp).

## Related

- [[interp-map-remove-noop.md]] — same audit session; the only other real finding.
- `~/core/wilson/core/event_bus.hexa:132-149` — current insertion-sort impl + stability comment.
