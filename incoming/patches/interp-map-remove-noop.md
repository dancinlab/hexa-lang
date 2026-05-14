# Interpreter (`hexa run`) — `map.remove(k)` is a silent no-op

**Filed by:** wilson. Discovered while verifying wilson `ROI.tape` finding s2 on 2026-05-14 — turned out the doc was stale; compiled mode works, only the interpreter has the bug.

**Date:** 2026-05-14.
**Severity:** correctness divergence between interpreter and compiled binary.

## Reproducer

```hexa
fn main() {
    let mut m: any = #{ "a": 1, "b": 2, "c": 3 }
    println("before: len=" + str(len(m)) + " has_b=" + str(has_key(m, "b")))
    m.remove("b")
    println("after:  len=" + str(len(m)) + " has_b=" + str(has_key(m, "b")))
}
```

### `hexa run` (interpreter)
```
before: len=3 has_b=true
after:  len=3 has_b=true     ← BUG: remove did nothing
```

### `hexa build -o foo && ./foo` (compiled C)
```
before: len=3 has_b=true
after:  len=2 has_b=false    ← correct
```

## Why compiled works

`self/runtime.c:2597` `hexa_map_remove(HexaVal m, const char* key)` is a real Robin-Hood deletion (carries the `ROI-24` comment about cached `order_idx` for O(1) locate). The compiled path goes through `codegen_c2.hexa:2562` / `codegen_c2_v2.c:752`, which emits `hexa_map_remove(obj, key.s)` — both correct.

## Why interpreter is broken (guess)

The interpreter's method dispatch for `remove` on a map likely either (a) hits a no-op stub, (b) returns a new map but discards it (no in-place semantic), or (c) never gets routed at all. Need to grep `self/hexa_full.hexa` for the `remove` method handler to confirm.

## Downstream effect

CLAUDE.md / AGENTS.tape in `dancinlab/wilson` previously documented this as a generic hexa-lang pitfall ("f1") and led to 1 production workaround (`map_remove_safe` in `plugins/provider-anthropic/main.hexa`, since deleted in the 2026-05-14 cleanup). Other projects relying on `hexa run` for scripts may have similar workarounds.

## Fix options

**A. Implement `remove` in the interpreter method-dispatch path** (preferred). Match the compiled semantics exactly: remove the key, return `bool` (or the map — whatever compiled returns).

**B. Hard-fail in the interpreter.** Emit a runtime error pointing to the bug rather than silently failing. Cheaper if (A) is non-trivial.

**C. Document the divergence loudly.** Add a section to hexa-lang docs listing all interpreter-vs-compiled known-divergences. (`docs/PORT_PITFALLS.md` was referenced by wilson but doesn't actually exist in the repo; create it.)

Wilson preference: **A**.

## Test that should pass after fix

The reproducer above, run via `hexa run`, should print `has_b=false`.

## Related

- [[stdlib-sort.md]] — same kind of "compiled has it, interpreter doesn't" might be lurking; full audit suggested.
- wilson `ROI.tape` §s2 (now resolved as stale-doc cleanup, this filing is the residue).
