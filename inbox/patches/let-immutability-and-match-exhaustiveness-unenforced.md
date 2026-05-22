# `let` immutability + match exhaustiveness — unenforced (canonical gap)

**Status:** 🟠 FILED / OPEN (2026-05-23)
**Reporter:** anima session — hexa canonical-deviation audit
**Severity:** medium — silent acceptance of patterns the Rust model rejects
at compile time; not a miscompile, but two safety nets are absent.

Two places where hexa silently permits what its apparent (Rust-shaped)
model rejects. Both fixes are breaking / design-level — hence filed, not
patched in-session.

## 1. `let` (non-`mut`) is freely reassignable — `mut` is decorative

```hexa
let x = 5
x = 6        // accepted — Rust: `error: cannot assign twice to immutable
             //                   variable` (needs `let mut`)
```

hexa has `let mut` syntax, which implies the Rust binding model
(`let` = immutable, `let mut` = mutable). But a plain `let` is freely
reassignable, so `mut` carries no semantics — it is a no-op marker.

Either path is canonical; the current middle state is not:
- **(a) Rust model** — make non-`mut` reassignment a compile error.
  Requires a codebase-wide migration first (stdlib + the self-hosted
  compiler hold thousands of reassigned plain `let`s; the compiler must
  still compile itself). Large coordinated change.
- **(b) JS model** — `let` is mutable; then drop `mut` as meaningless,
  or repurpose it. Smaller, but loses the immutability guarantee.

## 2. Non-exhaustive `match` expression yields `void` silently

```hexa
let m = match v {
    1 => "one"
    2 => "two"
}            // v = 9 → m == void  (no arm, no `_`)
```

A `match` used in expression position with no matching arm and no `_`
silently produces `void`. Rust rejects a non-exhaustive `match` at
compile time. A non-breaking step: emit a **warning** for a
non-exhaustive `match` in expression position (statement-position
`match` legitimately need not be exhaustive).

## Not a deviation (checked, canonical)

Integer arithmetic (truncating `/`, sign-follows-dividend `%`),
int/float promotion, bitwise + compound-assign operators, string
methods, collections, `i64` overflow wrap — all match the Go/Rust
model. The two items above are the audit's only binding/control-flow
findings.

## Cross-refs

Session also landed: `=>` match arrow (canonical, PR #345), named-fn
first-class value (PR #346), numeric `as`-cast codegen (PR #344),
`cmd_parse` shell-injection (PR #342).
