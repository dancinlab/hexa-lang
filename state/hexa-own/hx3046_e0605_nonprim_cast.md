# HX3046 — E0605 non-primitive `as`-cast REJECT (2-lane N3 · TERMINAL low-cost rung)

## What
Rust **E0605** parity (`non-primitive cast: X as Y` where Y is a struct/enum;
rustc_hir_typeck `cast.rs` `CastError::NonScalar`). An `expr as T` whose target
`T` resolves to a **registered struct or enum** is statically REJECTED. `as` is a
primitive numeric/bool coercion only — a struct/enum target is never a valid `as`.

## Wire point (re-anchored on origin/main HEAD b8ad43200)
- **`compiler/check/types.hexa:3924`** — the `if op == "as"` arm of
  `_types_check_binop`. Today it UNCONDITIONALLY `return`s
  `_types_lower_type_ref(...)` (the type of `x as T` is T). The registry gate is
  inserted BEFORE that return; **the original return stays VERBATIM** so
  downstream typing + emitted bytes are unchanged.
- Gate: `_types_resolve_alias_name(target)` **FIRST** (so `type MyInt=i64; x as
  MyInt` collapses to `i64` → unregistered → SILENT), then fire iff
  `_types_struct_registry_has(target) || _types_enum_registry_has(target)`.
- New **`_emit_hx3046`** (next to `_emit_hx3044` :2123) — exact mirror: FLIP-3
  band via `_types_strict_for` (real source → Error, `*_test.hexa` /
  `compiler/test/` fixtures → Warning).
- Catalog: **`compiler/diag/catalog.hexa`** — HX3046 DiagSpec inserted after
  HX3045, before HX4001. `Severity::Error`, stage `S3`, template
  `` non-primitive cast: `{target}` is not a primitive numeric/bool type ``,
  explain cites E0605, `fix_it_kind: FixItKind::None`.
  Parity: **89 → 90** (`DiagSpec {` == `fix_it_kind:` == 90).

## FP=0 boundary
Primitives (int/float/string/i64/f64/i32/bool/char) are in **neither** registry →
SILENT. `array` is NOT a registered struct/enum → SILENT. alias-to-primitive
collapses before the check → SILENT. undeclared name (`x as Foobar`) → SILENT.
**Only** a target resolving to a REGISTERED struct/enum fires.

## Regression-guard (N4)
`(v + 0.5) as int` still types as `int` and emits **no HX3046** — the as-arm
returns the target type verbatim without inferring the `v+0.5` operand (the
original `rt_round` fix is untouched). Test (cb) asserts 0 HX3046 **and** 0 HX3011
(an `int` sink vs an `f64` RHS would fire HX3011 if the preserved path regressed).

## Corpus-0 audit (RE-VERIFIED this session)
Collected all **1486** declared `struct`/`enum` names across
`compiler/`+`stdlib/`+`self/`; grepped each for a non-comment `as <Name>` cast →
**0 real hits**. Every struct-shaped `as X` occurrence in the tree is comment
prose or string-literal content; real code casts are exclusively primitives
(int/float/string/array/i64/f64/…), none in the struct/enum registry. Registry
gate fires on ZERO shipping source.

## byteeq-neutral
Types erase at MIR and the original `_types_lower_type_ref` return is preserved
verbatim → codegen `.text` byte-identical. Same neutrality class as HX3044.
PR-CI byteeq 3-target is the proof (pool-light, gates-summary merge).

## Tests (types_test.hexa, labels bv–cd — self-contained balanced blocks)
- (bv) struct `3 as Point` → 1 HX3046 Error
- (bw) enum `3 as Color` → 1 HX3046 Error
- (bx) alias `type P2=Point; 3 as P2` → 1 HX3046 Error (alias-resolve-FIRST)
- (by) `3.5 as int` → 0 (primitive)
- (bz) `x as string` → 0 (primitive)
- (ca) `x as array` → 0 (`array` not registered — FP boundary)
- (cb) ★ `let r:int = (v+0.5) as int` → 0 HX3046 + 0 HX3011 (regression-guard)
- (cc) `type MyInt=i64; x as MyInt` → 0 (alias-to-primitive)
- (cd) `x as Foobar` → 0 (undeclared)

## ★ TERMINUS
After HX3046, the low-cost **① static-types + opt-in-borrowck** frontier is
**EXHAUSTED**. Next altitude requires a genuine new capability (not a pool-light /
byteeq-neutral reuse rung):
- **array-repr default-ON** (type the still-empty monomorphic builtin returns
  split/lines/bytes/chars; needs `_types_assignable` element-type comparison for
  method-call sources + its own byteeq campaign) — highest value, do first.
- generics / trait / Option / tuple-arity — new type-repr axes.
- unsigned width-types u8/u16/u32/u64 — new BACKEND repr, not a check rung.
- borrowck new-axis: E0716 temporary-lifetime, E0509 Drop-glue, closure-region
  E0501/E0373 — each needs a new dataflow/region axis (documented non-viable as a
  reuse rung).
Recommendation: declare the pool-light 2-lane REJECT-rung campaign CLOSED; open a
scoped array-repr-default-ON ticket rather than another pool-light round.
