# R2 — binop result-type propagation symmetry (2 Error false-positive removal)

Lane: static-types · label **(an)** (next-free after (am); orchestrator renumbers
to (ao) if round4 R1 lands its (an) first) · branch
`fix/st-binop-result-type-symmetry` · **no new HX code**

Closes the residual R1 (`r1_binop_literal_coerce_design.md` §"Residual limits")
named explicitly: *"Binop result type is unchanged, so the existing asymmetry
(`1 + a_i32` propagating as i64) remains — a follow-on rung."*

## Problem
The arith numeric branch of `_types_check_binop` returns the **LHS** type via its
`return lt` tail (`compiler/check/types.hexa`:3544). So:

- `a_i32 + 1` → `lt` = i32 (the typed operand sits on the left) → already correct.
- `1 + a_i32` → `lt` = i64 (the *literal* `1` infers the universal int-literal
  i64) → **wrong**: the BinOp's inferred type is i64 rather than i32.

R1 fixed the binop's *own* HX3001 emit (the lit-coerce arm at :2281 keys on a bare
literal operand), but it did **not** touch the propagated result type. So whenever
the BinOp's inferred type flows onward — into a **call-arg** or an **assign** whose
operand is the BinOp *node* (not a bare literal, so :2281 never applies) — the i64
mistype false-fired:

- `take32(1 + a_i32)` → arg inferred i64 vs param i32 → **HX3003** (false).
- `let mut x: i32 = 0; x = 1 + x` → RHS inferred i64 vs lhs i32 → **HX3011** (false).

Rust E0308 (rustc_hir_typeck coerce/demand_coerce) unifies an untyped literal to
the typed operand **regardless of operand order**, so `1 + a_i32` is i32.

## Change (result type only — emit conditions unchanged)
Inserted just before the `return lt` tail of the arith numeric arm
(`types.hexa`:3544), reusing the exact predicates from `_types_assignable`'s lit
arm (:2281) — no new helpers:
```
if _types_is_lit_int(e.children[0].kind) && _is_integer_kind(lt) && _is_integer_kind(rt) { return rt }
if _types_is_lit_float(e.children[0].kind) && _is_float_kind(lt) && _is_float_kind(rt) { return rt }
return lt
```
When the LHS is an untyped int/float literal and both operands share the numeric
kind, return the RHS (typed) type. `a_i32 + 1` is untouched (LHS is the typed
side). `mixed_int_float` (int OP float → f64) already returned above, so it is
unaffected.

## Faithfulness — NOT loosening-only
This removes 2 real Error false-positives **and** adds one *correct* fire:

- `take64(1 + a_i32)` → the BinOp now correctly infers i32, so the arg i32 ≠ i64
  param → **HX3003 fires** (Rust E0308 parity). The i64-default previously
  **masked** this genuine mismatch. Pinned as the expected value.

Byteeq is preserved **structurally, not by the change being neutral**: `type_check`
(main.hexa:689) is a diagnostic-only pass — its output is the diag array, and
`lower(module, atlas)` (main.hexa:742) restarts codegen from the **raw AST**. Types
erase at MIR, so a changed inferred type never reaches emitted bytes. The proof is
a **corpus-clean PR CI** build (the byteeq 3-target gate over the shipping corpus).

## What still rejects / fires (Rust-parity preserved)
- `a_i32 + b_i64` — typed **ident pair**, neither a literal → HX3001 stays
  (order-swap positive control).
- `take64(1 + a_i32)` — the new faithful HX3003 (see above).

## Rider — comment refresh (comment-only)
The r9c literal-pattern comment (`types.hexa`:3794–3811) claimed *"ENTIRELY
flag-gated (env check is the FIRST `&&` operand)"*, stale since FLIP-3 flagless
(:1206) removed the `HEXA_STATIC_TYPES` env gate. Refreshed to the accurate model:
fires unconditionally, real source = Error / byte-eq fixtures = Warning via
`_types_strict_for`, byteeq preserved structurally (types erase at MIR).

## Test — types_test.hexa case (an)
`_build_case_binop_result_symmetry()`:
```
fn take32(p: i32) -> i64 { return 0 }
fn take64(p: i64) -> i64 { return 0 }
fn f(a: i32, b: i64) -> i64 {
    take32(1 + a)      // (1+a)=i32 → fits i32 → 0 HX3003 (pre-fix 1)
    take64(1 + a)      // (1+a)=i32 → i32≠i64  → 1 HX3003 (NEW faithful fire)
    let y = a + b      // ident pair            → 1 HX3001 (positive keep)
    let mut x: i32 = 0
    x = 1 + x          // (1+x)=i32 → fits i32 → 0 HX3011 (pre-fix 1)
    return 0
}
```
Contract across the module: **HX3003 = 1** (take64 only), **HX3001 = 1** (a+b),
**HX3011 = 0**. Real-source path (not `*_test.hexa`) → fires are ERROR-band.

## Verification
`types_test.hexa` is **NON-CI** → pool (aiden) bare-run
`hexa run compiler/check/types_test.hexa`, verified on **both backends**
(`HEXA_BACKEND=system` C-transpile AND `HEXA_BACKEND=native` aprime; aprime-only =
FALSE-green). Both GREEN — `(an)` ok + `PASS: all type-check cases match
contract.` byteeq 3-target GREEN on PR CI gates the compiler diff.
