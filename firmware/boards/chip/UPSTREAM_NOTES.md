# UPSTREAM_NOTES.md — hexa-lang upstream issues encountered

> Tracking issues found while wiring the hexa-chip runnable surface
> (verify/ + tests/ + per-verb sandboxes) on **hexa.real @ 2026-05-07**.
> Each entry has a minimal reproducer, observed behavior, and the
> work-around used inside this repo. Upstream fix-target: `hexa-lang`
> (`/Users/ghost/core/hexa-lang/`, packaged at `~/.hx/packages/hexa/hexa.real`).

---

## U-1 — `phi(n)` builtin returns `0.0`, not `φ(n)` (Euler totient)

**Severity**: high — silently returns wrong value, breaks any code using
the documented n=6 master identity `σ·φ = n·τ`.

**Repro**:
```hexa
fn main() {
    println(phi(6))   // expected: 2 (Euler totient at n=6)
    println(phi(1))
    println(phi(7))
}
```

**Observed**:
```
0.0
0.0
0.0
```

**Expected**:
```
2     // φ(6) = |{1,5}| = 2
1     // φ(1) = 1
6     // φ(7) = 6 (7 prime)
```

**Hypothesis**: parser binds `phi` to the math constant `phi = (1+√5)/2`
(golden ratio) and treats `phi(6)` as `phi * (6) = 1.618... * 6 = 9.7…`,
but the implementation appears to silently coerce/truncate to `0.0` —
either way the numeric value is wrong.

**Workaround in this repo**: re-implement Euler totient via `_gcd` loop
in user code; do not call the builtin. See
`verify/n6_arithmetic.hexa` `euler_phi()`.

**Patch direction**: add a proper `euler_phi(n: int) -> int` builtin
sourced from a divisor-loop, and either rename or remove the conflicting
`phi` (math-constant) name. `sigma(n)` and `tau(n)` work correctly so
the divisor-sum / divisor-count primitives are already solid; mirror
that for totient.

---

## U-2 — `#` line comments are leaky

**Severity**: medium — pre-existing legacy files using `#` comments
generate parse-error spew on stderr and occasional runtime errors when
comment text contains `=` / `:` / `/` punctuation.

**Repro**:
```hexa
fn main() {
    # Egyptian fraction: 1/2 + 1/3 + 1/6 = 1
    println("hi")
}
```

**Observed**: parse errors at the `:` and `=` columns, plus a runtime
`modulo by zero` in some cases (the parser appears to retry interpreting
the comment as an expression).

**Expected**: `#` comments should be lexed as a line comment up to `\n`,
the same way `//` is.

**Workaround**: migrated the affected files in this repo to `//`
comments (see `conscious_chip/verify_consciousness-chip.hexa` migration
note dated 2026-05-07).

**Patch direction**: in the lexer, treat a leading `#` (when not inside
`#!hexa strict` shebang) as a `//` line-comment start.

---

## U-3 — Dictionary literal `{key: value, ...}` not parseable

**Severity**: medium — forces users to model maps as parallel `[str]`
+ `[int]` arrays or hand-wired functions.

**Repro**:
```hexa
fn main() {
    let mp = {"V_bus": 48, "I_nom": 100}
    println(mp["V_bus"])
}
```

**Observed**: `Parse error … unexpected token LBrace ('{')` etc.

**Expected**: dict literal accepted; `mp["V_bus"]` returns `48`.

**Workaround**: 2D array of `[key, value]` pairs + linear lookup; e.g.
`verify/inventory_check.hexa` `GROUPS = [["architecture", "architecture"], ...]`.

**Patch direction**: parser accepts JSON-style object-literal in
expression position; semantics map to existing internal `Map<str, T>`.

---

## U-4 — `args()` returns full argv including `hexa run <file>` prefix

**Severity**: low — every script that takes user args has to scan for
the `.hexa` filename and slice past it.

**Repro**:
```bash
hexa run my.hexa one two
```
```hexa
fn main() { for a in args() { println(a) } }
```

**Observed**: prints `hexa`, `run`, `my.hexa`, `one`, `two` (plus
runtime injection of `hexa_chip_cli` etc. depending on dispatcher).

**Expected**: the user's args (`one`, `two`) only.

**Workaround**: every script in `verify/` defines a private
`_user_args()` that walks `args()`, finds the `.hexa` filename, and
returns the slice past it.

**Patch direction**: introduce `argv()` that returns only user args
(post-script), keep `args()` for raw access. Or document the slicing
convention in stdlib docs.

---

## U-5 — `if` expression vs `if` statement ambiguous in builder paths

**Severity**: low — required experimentation to find that

```hexa
let mark = if ok { "PASS" } else { "FAIL" }
```

works, while sometimes the compiler needs the `if` on the line before.

**Repro / workaround**: documented in user-style guide; not a parser
blocker. Files in this repo all use the inline-`if`-expression form.

**Patch direction**: either a `match` form (Rust-style) or doc the
exact contexts that allow `if`-expression vs only `if`-statement.

---

## Summary

| ID  | Severity | Status   | File touched                                       |
|-----|----------|----------|----------------------------------------------------|
| U-1 | high     | open     | `verify/n6_arithmetic.hexa` (workaround)           |
| U-2 | medium   | open     | `conscious_chip/verify_consciousness-chip.hexa` (migrated) |
| U-3 | medium   | open     | `verify/inventory_check.hexa` (workaround)         |
| U-4 | low      | open     | every `verify/*.hexa` (workaround helper)          |
| U-5 | low      | doc-only | n/a                                                |

When you patch upstream, please remove the corresponding workarounds
and bump `hexa.toml` `dependencies.hexa-lang` to the fix version.
