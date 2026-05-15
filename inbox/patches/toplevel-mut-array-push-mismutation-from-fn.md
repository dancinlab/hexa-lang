# `.push()` on a top-level `let mut <array>` mis-mutates when called from inside a fn

**Layer:** language semantics / codegen (array intrinsic)
**Related:** existing workaround at `self/tui/input.hexa:113-116`

## Symptom

When a module-level `let mut <array>` (the canonical "global state" pattern wilson
+ self/tui both use) is mutated via `.push(...)` from inside a `fn`, the second
push to a fresh new element doesn't always create a new array slot — instead it
appears to concatenate to the LAST existing element of the array.

The existing workaround in `self/tui/input.hexa` describes it as a **silent crash
trigger** related to closure-capture. In wilson's harness-cli we observed a
different but probably-related variant: **silent corruption** rather than crash.

## Repro (wilson production case)

```hexa
let mut harness_cli_QUEUE: [string] = []

fn handle_pump_ev(...) -> bool {
    ...
    if cp == -1 {                                  // Enter mid-turn
        let q = harness_cli_trim(harness_cli_PENDING)
        harness_cli_PENDING = "" ; harness_cli_PENDING_CUR = 0
        if q != "" {
            harness_cli_QUEUE.push(q)              // <- THIS
        }
        ...
    }
}
```

User types `test2<Enter>`, then `test3<Enter>` mid-turn. Expected:
`QUEUE = ["test2", "test3"]`. Observed: `QUEUE = ["test2", "test3"]` on the
**first** time, then a **second** push of `"test3"` later (`test3<Enter>` again)
produces `QUEUE = ["test2", "test3test3"]` — the new element got concatenated
onto the previous element instead of appended as a new slot.

Visible downstream: wilson's queue-row UI renders the array as one row per
entry. With the corruption, two consecutive `test3` queue submissions show up
as a single row `▸ test3test3` instead of two rows `▸ test3` / `▸ test3`.

## Workaround (wilson `plugins/harness-cli/main.hexa::handle_pump_ev`, commit `7c45546`)

Rebuild-and-reassign — same pattern `self/tui/input.hexa:113-116` already documents:

```hexa
let mut new_q: [string] = []
let mut qi = 0
while qi < len(harness_cli_QUEUE) {
    new_q.push(str(harness_cli_QUEUE[qi]))
    qi = qi + 1
}
new_q.push(q)
harness_cli_QUEUE = new_q
```

`.push()` on the fresh local `new_q` works correctly — it's only the top-level
`let mut` binding that misbehaves. Once we reassign the whole binding, the next
read sees the rebuilt array.

## Other call sites in wilson that also went through the rebuild form
(historical workaround for the same class of bug):

- `self/tui/input.hexa:113-130` — `_pending_bytes` injection
- `plugins/harness-cli/main.hexa` — `_echo_parts` walk + scrollback pops use rebuild forms

## Required upstream fix

`.push()` on a top-level `let mut <array>` from inside any function should be
equivalent to:

```hexa
arr = arr.concat([val])    // append-and-reassign
```

i.e. it should **always** append a new element, never mutate the last element.

Best guess at root cause (per the input.hexa comment): the codegen captures the
top-level mut binding's underlying array buffer pointer in a closure-style cell,
but the buffer growth path (when capacity is exhausted) allocates a new buffer
and re-points the binding without updating the in-fn-captured reference. The
in-fn handle then writes to the old buffer in a position that overlaps the
LAST element of the new buffer (because both buffers shared the same first N
elements via the realloc copy).

A targeted reproducer that exercises the buffer-growth path explicitly:

```hexa
let mut g: [string] = ["a", "b"]     // cap likely 2

fn dopush(s: string) -> void {
    g.push(s)                          // first push triggers grow
}

dopush("c")    // triggers buffer realloc
dopush("d")    // expected: g == ["a", "b", "c", "d"]
               // observed (wilson production):
               //   varies — sometimes corrupted last element,
               //   sometimes correct; depends on toolchain version

println(str(len(g)))                   // not 4 in the broken case
let mut i = 0
while i < len(g) { println(g[i]) ; i = i + 1 }
```

A controlled bench in `self/test_array_push_from_fn.hexa` exercising several
capacity-doubling thresholds (1→2, 2→4, 4→8, 8→16) would catch this for the
runtime + codegen + interp paths in one harness.

## Severity

**Indeterminate — see "Could not reproduce in isolation" below.** The wilson
production symptom is real (user-confirmed `▸ test3test3` on screen). The
workaround (rebuild-and-reassign in `plugins/harness-cli/main.hexa` commit
`7c45546`) made the symptom go away. But the simple cases below all PASS on
the current toolchain — so the bug may be sensitive to context that simple
reproducers don't replicate, or the visible "test3test3" symptom may have a
non-`.push()` root cause that the rebuild also coincidentally fixed.

## Could not reproduce in isolation

Tried multiple variants — all return the correct array:

1. `dopush("a"/"b"/"c"/"d")` four pushes through a fn → 4 distinct slots ✓
2. Indirect call chain (top-level fn → type_char → flush → push) → ✓
3. Arena-heavy context (nested maps + valstructs + reassignments) → ✓
4. Drain-then-refill (`g = drop_front(g)` between pushes) → ✓
5. Two pushes of the identical string value → ✓

Each variant exercises capacity growth (1→2→4→8 thresholds), heap promotion,
and fn-arena interactions. Combined with the 2026-05-13 `hexa_array_push`
heapify-on-push fix already in `runtime.c:1879-1889`
(`wilson-fn-arena-escapes-on-push`), the bug class the input.hexa comment
described seems to be ALREADY FIXED on the current main.

## Recommendation

1. **No targeted code fix** — without a reliable reproducer, any change to
   `hexa_array_push` / codegen would be speculative.
2. **Add a regression test** at `self/test_array_push_from_fn.hexa` covering:
   - module-level `let mut <array>` + push from fn
   - capacity-doubling thresholds
   - mixed arena / heap items
   - drain-then-refill sequences
   So if the bug returns, CI catches it.
3. **Treat `self/tui/input.hexa:113-116`'s comment as historical** — note in
   the comment that the workaround is no longer mechanically required, but
   keep it as defense-in-depth.
4. **Downstream advice**: when in doubt, the rebuild-and-reassign workaround
   is O(N+M) per push and safe across toolchain versions. For hot paths
   (large arrays / frequent push), use a fn-local mut array + reassign at
   end.
