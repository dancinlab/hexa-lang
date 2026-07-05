# R1 — binop operand literal-aware coercion (HX3001 false-positive removal)

Lane: static-types · label **(ak)** · branch `fix/st-binop-literal-coerce` · **no new HX code**

## Problem
`_types_check_binop` rejected a build-legal line `a_i32 + 1` with **HX3001** (an
unbanded Error → build brick class). The literal `1` infers `i64` (universal
int-literal), so the bare `_types_equal(lt, rt)` check saw `i32 ≠ i64` and
mis-rejected. Rust E0308 (rustc_hir_typeck coerce/demand_coerce) instead
**unifies an untyped int/float literal with the typed operand** — that is the
contract this rung restores.

## Change (emit condition only — return values unchanged)
Both binop reject sites swapped from bare `_types_equal` to a **bidirectional
`_types_assignable`** check. `_types_assignable(expected, actual, src)` already
encodes the literal-coercion arm keyed on `src.kind` (the operand-producing
Expr's literal kind), so the literal can sit on **either** side:

- **arith numeric branch** (`compiler/check/types.hexa` ~:3479):
  ```
  if !_types_assignable(lt, rt, e.children[1]) && !_types_assignable(rt, lt, e.children[0]) && !mixed_int_float {
      _emit_hx3001(lt, rt, e.span, out)
  }
  ```
- **compare branch** (~:3516): same swap; the existing `unit` permissive guard
  is **retained** (assignable still rejects `unit`, and the guard covers the
  unannotated-fn `unit` placeholder case).

`_types_assignable ⊇ _types_equal` (equal ⇒ assignable), so the new emit-set is
a strict subset of the old → **strictly loosening → byteeq-neutral** (removes
false-positive emits only, never adds one). Byproduct: HexaVal-wildcard
tolerance is inherited (aligns with HX3003 #4603 policy).

## What still rejects (Rust-parity preserved)
- `a_i32 + b_i64` — typed **ident pair**, neither side a literal → HX3001 stays.
- `a - "s"` — non-numeric operand → reaches the mismatch branch unchanged → HX3001 stays.

## Residual limits (next rungs)
- Binop **result type** is unchanged, so the existing asymmetry (`1 + a_i32`
  propagating as i64) remains — a follow-on rung.
- `1 + 2.5` (literal on both sides) is already handled by the `mixed_int_float` arm.

## Test — types_test.hexa case (ak)
`_build_case_binop_literal_coerce()`:
```
fn f(a: i32, b: i64) {
    let x = a + 1     // int-lit coerces to i32 → clean
    let c = a < 2     // int-lit coerces to i32 → clean
    let y = a - "s"   // non-numeric string operand → HX3001
    let w = a + b     // i32 × i64 ident pair → HX3001
}
```
Expect **exactly 2 HX3001** (error band). Pre-fix would be 4. Placed after (aj);
(ak) confirmed next-free label.

## Verification
`types_test.hexa` is **NON-CI** → pool (summer/aiden) bare-run
`hexa run compiler/check/types_test.hexa` required before merge (#4606 precedent),
verified on **both backends** (aprime-only = FALSE-green). byteeq 3-target GREEN
gates the compiler diff.
