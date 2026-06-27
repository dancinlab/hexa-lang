# RFC — Type aliases (`type Name = Underlying`) · native path

Status: **IMPLEMENTED** (transparent alias; `newtype` nominal distinction = R2 gap).
Lane: `type-alias` (Go/Rust language-surface parity census, ARCHITECTURE.json
`#language-surface` Tier-1).

## Goal

Add `type MyInt = Int` / `type Celsius = f64` aliases to the .hexa language on
the **native** compiler path (`compiler/`), with Rust/Go transparent-alias
semantics: the alias name is interchangeable with its underlying type for
type-checking, and the declaration emits nothing. Release-integrity first:
**byte-identical** emit for any program that declares no aliases, on all three
byteeq targets (x86_64-linux · arm64-linux · darwin-arm64).

## Reference

- The Rust Reference §"Type aliases" — `type Kilometers = i32;` (transparent;
  `Kilometers` and `i32` are the same type, NOT a new nominal type — that is
  `struct Kilometers(i32)`).
- The Go Programming Language Specification §"Alias declarations" —
  `type byte = uint8`, `type nodeList = []*Node` (the `=` form is a true alias;
  the no-`=` form `type T U` is a *defined* type = nominal, the newtype case).

hexa-specific lever (beyond parity): the alias resolves through the same
deterministic `_types_lower_type_ref` surface the rest of the byteeq fixpoint
rests on, so `gen3 ≡ gen4` is unaffected and the feature is provably
byte-neutral by construction (empty substitution table → identity lowering).

## The frozen-parser wall, and the escape

A new `type` **keyword token** (`KwType` in `compiler/lex/tokens.hexa`) or a new
`ItemKind::TypeAlias` variant would be the obvious encoding, but:

1. `type` is **not** a keyword in the native lexer (`compiler/lex/lexer.hexa::
   keyword_kind` maps it to `Ident`); the bootstrap (`self/`) lexer *does*
   reserve it, so `type` is already unusable as an identifier — no source
   regresses by treating an item-leader `type` specially.
2. A new `ItemKind` variant would ripple through ~6 exhaustive
   `match ItemKind` sites (parser, types, ast_to_hir, …) — churn + risk.

**Escape (frozen-safe, mirrors `extern fn`):** detect `type` as an `Ident`
leader at item position via `_peek_is_type_kw` (cf. `_peek_is_extern_kw`), and
carry the alias as an existing `ItemKind::Let` tagged with a bare
`__type_alias` annotation marker + `@phase("parse_only")`. No new
keyword/token/`@attr`/`ItemKind` is introduced, so the frozen bootstrap parser
(blob 151c52c8) compiles the changed compiler source unchanged.

## Design

| Stage | Change | File |
|-------|--------|------|
| Parse | `_peek_is_type_kw` + `parse_type_alias_item` (consumes `type Name`, optional `<T>` generics discard like struct, `= Underlying`); dispatch in `parse_item` + the module-scope decl-leader guard | `compiler/parse/parser.hexa` |
| AST   | `item_is_type_alias(it)` helper (checks `__type_alias` marker) | `compiler/parse/ast.hexa` |
| Types | `_types_register_aliases` builds the alias→underlying table up front in `type_check`; `_types_lower_type_ref` resolves the name (bounded 16-hop chain, cycle-safe) before the primitive table; carrier skipped in `_collect_item_types` (no value binding) | `compiler/check/types.hexa` |
| Lower | carrier dropped in the ast_to_hir module loop (no scope define, no HItem → emits nothing) | `compiler/lower/ast_to_hir.hexa` |

Carrier shape: `Item{ kind: Let, name: "<alias>", return_type: <underlying TypeRef>,
body: empty_expr(), annotations: [@phase("parse_only"), __type_alias] }`.
`@phase("parse_only")` makes resolve/bind/type-check **body** passes skip it
(reusing the existing embedded-atlas-node mechanism, `item_is_parse_only`); the
`__type_alias` marker drives the two narrow type-alias-specific hooks (alias
registration + lowering drop).

## Byte-neutrality argument

- **Parser:** `_peek_is_type_kw()` is false for any program with no item-leader
  `type`; the added dispatch arms short-circuit → identical AST → identical
  emit.
- **Types:** the alias table is empty for alias-free programs, so
  `_types_resolve_alias_name` returns its input unchanged on the first inner
  loop (0 iterations) — `_types_lower_type_ref` behaves byte-identically.
- **Lower:** the `item_is_type_alias` guard is never taken without a carrier.
- **self-host:** compiler source uses no `type` aliases (`ast.hexa` already
  reserves `type`, code uses `typ`), so the new compiler compiles the compiler
  identically → `gen3 ≡ gen4` holds.

frozen 151c52c8 ∅ · new keyword/builtin/`@attr` 0 · deletions 0.

## Tests

`compiler/parse/parser_test.hexa::case_type_alias` — `type MyInt = i64`,
`pub type Celsius = f64`, generic `type Box<T> = i64`, chain `type Temp = Celsius`,
plus a fn signature using the aliases with arithmetic. Expect items=6,
alias_count=4, every alias `parse_only=true`, parse_diags=0.

Local interpreter (`~/.hx/bin/hexa run`, mini = git/gh only, no native build):
- `compiler/parse/parser_test.hexa` → **PASS** (case_type_alias: alias_count=4,
  0 diags, alias-typed fn signatures parse clean).
- `compiler/check/types.hexa` regression via `types_test.hexa` → **PASS**
  ("all type-check cases match contract") with the alias registry wired.
- `compiler/lower/ast_to_hir.hexa` test is blocked locally by a *pre-existing*
  interpreter module-flatten collision (`_empty_atlas_ref` redefinition,
  unrelated to this change) — covered by CI native build instead.

byteeq 3-target DEFAULT byte-invariance + native build of the alias test =
**delegated to PR CI / pool** (mini cannot build).

## R2 gap (honest)

True `newtype` — a *nominal* distinct type that is **not** interchangeable with
its base (Rust tuple-struct `struct Meters(f64)`, Go defined-type `type T U`) —
is NOT implemented; `type` here is a transparent alias only. A nominal newtype
needs a distinct `Type` identity that the typecheck unify path rejects against
the base, which is a larger surface (and the current stage0 typecheck is
permissive/loose). Deferred.
