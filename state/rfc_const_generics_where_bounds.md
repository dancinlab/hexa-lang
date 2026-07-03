# RFC — const generics + where-clause / trait-bound enforcement (opt-in, check-only)

Status: **R1 reference slice landed** (executable check algorithm + tests, byteeq-neutral).
Production wiring into `compiler/check/` = **walled** on parser generic-param capture (next round).

Lane ① `const-generics`. Reference: rustc (min_const_generics RFC 2000 + trait selection).

---

## 1. Goal

Add to hexa's typecheck, **opt-in / default-OFF**:

1. **Const generics** — `struct Buf<const N> { … }`. A const generic param is
   instantiated with a *value*, not a *type*. Validate the value-vs-type kind at
   instantiation (rustc: `Buf<int>` → "expected a const but found a type";
   `Box<5>` → the inverse).
2. **where-clause / trait-bound enforcement** — `fn f<T>(…) where T: Ord` (≡
   `fn f<T: Ord>(…)`). At every instantiation with a concrete type, prove the
   bound against the in-scope impls; on violation emit a **non-fatal warning**
   (default, mirrors HX4001 severity), promoted to a **fatal error** under the
   opt-in `HEXA_STRICT_BOUNDS=1`.

Emit must not change → **byteeq-irrelevant** (检查만). DEFAULT compile path stays
byte-identical on the 3 byteeq targets.

## 2. Reference-match (cites, file:concept)

- **Const generics** — rustc `min_const_generics` (RFC 2000). A `const N: usize`
  param occupies a *value* slot; the compiler rejects a type in that slot and a
  value in a type slot. We reproduce the two-way kind check.
- **Trait bounds / where-clauses** — `where T: Ord` desugars to the inline bound
  `<T: Ord>` (The Rust Reference §"Where clauses"). rustc proves the obligation
  per instantiation via `rustc_trait_selection`; the diagnostic is "the trait
  `Ord` is not implemented for `f64`". **f64 implements `PartialOrd` but NOT
  `Ord`** (NaN total-order hole) — our builtin impl registry reproduces this
  exactly (int/bool/String are `Ord`; f64 is only `PartialOrd`).
- **Polarity** — native-canonical-default: the *default* path is unchecked
  (today's erased generics), enforcement is the opt-in *constraint*
  (`HEXA_STRICT_BOUNDS`), matching the [native-canonical-default] guardrail
  (flag name turns ON a constraint).

## 3. R1 — what landed (this PR)

The check **algorithm** is implemented and locally verified in the standalone
generics-typechecker prototype `self/test_generics_typecheck.hexa` (a
self-contained interpreter-runnable typechecker, not in the compile path — so
**byteeq-neutral by construction**). New surface:

- `tc_register_impl` / `tc_register_builtin_impls` / `tc_type_implements` — the
  trait-impl registry (rustc-faithful builtin impls).
- `tc_check_bound_satisfied(owner, pos, type, bound)` — proves one bound
  (multi-trait `Ord+Num` split on `+`), warn-or-error per `tc_strict_bounds`.
- `tc_merge_where(tparams, wheres)` — where-clause → inline-bound desugaring,
  accumulating multiple clauses on one param.
- Const generics in `tc_validate_type_args` — value-vs-type slot validation,
  using the `"const"` sentinel stored in the existing per-param bound slot (no
  new parallel arrays ripple through the `type_check()` reset).
- AST builders `const_param_node` / `const_arg_node` / `where_node` /
  `struct_decl_where` / `fn_decl_generic_where`.

Tests T35–T46 (24 new assertions), **70/70 GREEN** on the local interpreter:
const-param registration · `Buf<8>` accept · `Buf<int>` reject · `Box<5>` reject
· satisfied/violated bounds · f64-not-Ord · strict-mode escalation · where-clause
merge · multi-bound accumulation · mixed type+const params · inline-bound
regression.

## 4. Wall — why production wiring is deferred

To enforce bounds inside the **real** `compiler/check/types.hexa` pipeline the
checker must read declared generic params + bounds + where-clauses from the AST.
Today it cannot:

- The native parser **ERASES** generics — `parse_struct_item`
  (`compiler/parse/parser.hexa:1868`) and `parse_fn_item` (`:1779`) consume and
  **discard** the `<…>` token run (a hang-guard), capturing nothing.
- `where` is **not a token** (`compiler/lex/` has no `KwWhere`); a `where` clause
  between `>` and `{` currently mis-parses, so no shipping source uses one.
- Capturing generic params + bounds into `ast.hexa::Item` requires a **new
  field**, which "would ripple through every Item literal in the tree" (the
  parser's own note on `let_item`), and downstream annotation/S4/S8 handling of
  any new carrier is **unverifiable on `mini` (git/gh-only, no build)**.

Per release-integrity-first + "frozen/design-scale 벽이면 RFC + first byteeq-safe
slice", the production AST-capture slice is the **next round** (build host
required for byteeq proof). This RFC's R1 is the byteeq-safe first slice: the
exact check algorithm, executable and green, ready to port verbatim.

## 5. R2 plan — production wiring (build-host gated)

1. **Parser capture (byteeq-safe by additivity):** in `parse_struct_item` /
   `parse_fn_item`, instead of pure-discard, collect the `<…>` param run (name +
   optional `const` prefix via the existing `KwConst`/`const`-ident + optional
   `: Bound`) and an optional trailing `where ID : Bound (, …)*` (additive — was
   broken before, so no existing source regresses) into a **side carrier**. No
   new `@attr` keyword (frozen blob 151c52c8 would break) — reuse the existing
   `annotations: [Annotation]` slot with a programmatically-built `Annotation`
   (name `__generics`, args encode params/bounds), constructed in the parser at
   runtime (not `@`-syntax). Cursor behavior unchanged → land on `{`/`(`.
2. **Tolerate the carrier everywhere:** verify S4/S8/citation passes ignore an
   `__generics` annotation (must measure on a build host — the unverifiable step).
3. **Port the R1 algorithm** into a new `compiler/check/bounds.hexa` pass
   (registry + `check_bound_satisfied` + `merge_where` + const kind-check),
   reading the carrier, gated `env("HEXA_STRICT_BOUNDS")=="1"` for fatal vs warn.
4. **byteeq proof:** DEFAULT (flag-unset, no generic carrier) asm byte-identical
   on x86_64-linux · arm64-linux · darwin-arm64; run on aiden/summer.

## 6. hexa-beyond-parity lever

Once captured, const generics feed the **monomorphization** pass
(`compiler/optimize/monomorphize.hexa`, `HEXA_MONOMORPHIZE=1`): a proven
`Buf<N>` const arg can specialize array sizes into the native emit (no LLVM
boundary) — a beyond-rust lever since hexa's codegen shapes the kernel directly
(byte-eq deterministic `$N`-suffixed instances). Tracked separately.
