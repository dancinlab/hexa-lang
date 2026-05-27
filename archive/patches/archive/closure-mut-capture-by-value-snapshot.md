# closure mutable capture is by-value (snapshot) — mutation lost

**Status:** 🟢 RESOLVED via path (a) — by-reference for closure-mutated
`let mut` (2026-05-23). Codegen source landed in `self/codegen.hexa`;
activation is regen-gated (maintainer rebuilds `hexa_v2`). Verified locally
via regen+transpile+run (see Resolution).
**Reporter:** anima session — hexa canonical-deviation audit (closure batch)
**Severity:** medium — read-capture works canonically; mutation through a
closure silently fails to propagate, with no syntax to opt in.

## Resolution (2026-05-23, path a)

Function-LOCAL `let mut X` bindings that a closure both **captures** and
**assigns to** are now boxed into a shared 1-element array "cell". The
cell's backing buffer is shared by reference when the `HexaVal` is copied
(struct copy shares `arr_ptr`), and `hexa_array_set(cell, 0, v)` mutates in
place — so writes through the closure persist across calls (Rust `FnMut` /
JS / Python `nonlocal`). Codegen contract for a boxed `X`:

```
let:    HexaVal X = hexa_array_push(hexa_array_new(), <init>);
read:   hexa_array_get(X, 0)
assign: X = hexa_array_set(X, 0, <rhs>);   // returns the same cell
capture: env push of X pushes the cell verbatim (shared arr_ptr); the
         lambda's env-unpack rebinds X to the cell, so the same read/write
         rules deref it identically inside the closure body.
```

**Detection** is a pre-scan in `gen2_fn_decl`: a name is boxed iff it is
declared `let mut` in the fn AND appears as a captured free var that is
assigned inside some closure body. Read-only captures (e.g. `|n| n + base`)
and `let mut` captured-but-not-mutated keep the existing by-value snapshot
path (no behavior change, no perf cost). Pure-local `let mut` (no closure)
stays a plain `HexaVal` — never boxed.

**Verified** (local regen → transpile → run):
- repro `inc(3); inc(4)` → `3` then `7` (was `3` then `4`).
- read-only `|n| n + base` → `15` (unchanged).
- compound-assign `total += y` through a closure threads correctly.
- 40/40 sampled source files transpile byte-identically (surgical).
- existing closure suite: no new failures (the 3-level deep-nested-mutation
  cases were already failing in baseline — out of scope; see Boundary).

**Boundary:** scoped to function-local `let mut` (the common, repro'd case).
Module-scope `let mut` already worked canonically (the closure references
the C global directly — no env snapshot) and is intentionally never boxed.
Deep (≥3-level) nested-closure mutation threading remains a pre-existing
gap (a single boxed cell threads one level cleanly; multi-hop re-capture of
the cell through intermediate closures is a follow-up).

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
  → **CHOSEN & LANDED** (2026-05-23, see Resolution above). Scoped to
  closure-mutated bindings only, so the snapshot behavior is preserved
  for every read-only capture (no observable change there).
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
