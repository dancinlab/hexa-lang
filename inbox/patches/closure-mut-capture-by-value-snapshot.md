# closure mutable capture is by-value (snapshot) — mutation lost

**Status:** 🟠 FILED / OPEN (2026-05-23)
**Reporter:** anima session — hexa canonical-deviation audit (closure batch)
**Severity:** medium — read-capture works canonically; mutation through a
closure silently fails to propagate, with no syntax to opt in.

## Symptom

```hexa
let mut counter = 0
let inc = |x| { counter = counter + x; return counter }
println(to_string(inc(3)))   // 3   ✓
println(to_string(inc(4)))   // 4   ✗  Rust / JS / Python: 7
```

Each call resets `counter` to its captured snapshot (0) instead of
threading through the outer binding. Read-only capture is fine
(`let base = 10; |n| n + base` → 15 ✓); only mutation is lost.

## Canonical model

Three reference languages all capture mutable outer bindings by
**reference to the binding cell**:

| lang | semantics |
|---|---|
| Rust | `FnMut` borrows `counter` mutably; `inc(3); inc(4)` → 3, 7 |
| JS   | closures capture variable bindings; same |
| Python | closures see the cell; `nonlocal counter` for assignment |

hexa snapshots the value at closure creation. There is no opt-in
(`move`, `[&]`, `nonlocal`, …) for reference capture, so mutation
through a closure is currently inexpressible.

## Suggested resolution paths

- **(a) Default by-reference for mutable outer bindings** — match
  Rust / JS / Python. The lambda codegen needs to box captured outer
  vars whose binding is `let mut` into a reference cell shared with
  the closure. Behavior change for code that intentionally relied on
  snapshot semantics (likely rare).
- **(b) Keep snapshot, add a `move` or `ref` opt-in** — closer to
  C++ `[&]` / Rust `move`. Less breaking; expressivity gap closed
  explicitly.
- **(c) Document snapshot as design** — close the expectation gap by
  noting the deviation, and add a lint when a closure body assigns
  to a captured binding (warning the mutation is lost).

## Not a deviation (checked, canonical)

Read capture · iterators (`for i in 0..N`, `.map`, `.fold`) · generics
(`fn id<T>(x: T) -> T`) · struct field access · trait/impl dispatch
(after the `hexa_is_type` header fix, sibling PR) — all match the
Rust/Go model.

## Cross-refs

- Sibling inbox patch: `let-immutability-and-match-exhaustiveness-unenforced.md`
- Session fix PRs: `=>` match arrow, named-fn first-class value,
  numeric `as`-cast codegen, `cmd_parse` shell-injection, `hexa_is_type`
  decl.
