# canonical-deviation audit — post-merge tail status

**Status**: audit-report-archived-2026-05-25 — meta audit report (not a single fix). Items already absorbed via subsequent canonical-audit rounds + individual PRs.
**Status:** 🟠 FILED / OPEN (2026-05-23)
**Reporter:** anima session — hexa canonical-deviation audit, post-round-4
**Severity:** mixed — none are silent miscompiles in the codegen class
(those landed in rounds 3-4); each remaining item is a meaningful
canonical gap that didn't fit the session's surgical pass.

This session shipped **22 surgical fix PRs** and 5 inbox patches across 4
audit rounds. After the maintainer merged ~24 of those PRs to main, the
items below are what's still tail-shaped — each is concrete and
PR-eligible.  Two earlier inboxes cover the broader design surface
(#354 round-3 · #358 round-4 · #357 decl-debt class · #347 binding/match
· #349 closure capture).

## Codegen / parser / runtime — surgical-eligible

| # | name | site | scope | notes |
|---|---|---|---|---|
| 1 | `DestructLetStmt` codegen | `self/codegen_c2.hexa` gen2_stmt | medium | parser builds the node from `let [a, b] = arr`; codegen drops → hits the fail-loud branch from #369.  Emit per-index `hexa_index_get(__d, i)` bindings; rest-binder via `hexa_array_slice`. |
| 2 | `MapDestructLetStmt` codegen | same area | small | `let { x, y } = obj` — emit `hexa_field_get`/`hexa_map_get` per name. |
| 3 | `gen2_match_cond` Tuple case | `self/codegen_c2.hexa` | medium | `match (1, b) => b` is currently a **silent miscompile** — paren-expr falls through and emits `hexa_eq(scrut, [1, b])` referencing the free ident `b` → clang `undeclared identifier`. Add Tuple/TupleLit case with per-position type-check + arm-body binder. |
| 4 | bare-block `{ ... }` stmt | `self/parser.hexa` parse_stmt + codegen | small | Rust/Swift/C# accept as explicit-scope stmt. hexa parse_stmt has no LBrace branch. Codegen would emit a C `{ … }` containing each stmt (no real scope isolation until #347's flat-hoist redesign). |
| 5 | `?.` optional chaining wiring | parser postfix + codegen | medium | lexer emits `QuestionDot` ✓; parser has the `OptField` AST kind ✓; the postfix parse path doesn't wire it to consume QuestionDot, and codegen has no `OptField` handler. |
| 6 | struct method dot-call disambiguation | `self/codegen_c2.hexa` | medium | `Type.method(x)` codegen passes the type-token as `self` → C "too many arguments". Look up the fn signature; if first param ≠ self, drop the synthetic receiver. |
| 7 | `Self`-as-path (`Self::other_method`) | codegen | small | Parallel to the `Self {…}` ctor fix [#370]; resolve `Self::name` to `<impl-target>__name`. |
| 8 | Float `1.0/0.0` IEEE compliance | `runtime_core.c:6887` / `codegen_c2.hexa:3959` | small-medium | Literal float div-by-zero throws instead of returning `±inf`/`nan`. Extend FloatLit fold to `UnaryMinus(FloatLit)` operand; remove the float-zero throw in `hexa_div`. |
| 9 | Float `println` vs `to_string` format consistency | `runtime_core.c:5222` + 4 callers | medium | `println(0.0)` → `0`, `to_string(0.0)` → `"0.0"`. Pick a canonical (Rust/Go/JS pair = bare; Python/Swift pair = `.0`) and unify. |
| 10 | String OOB on read → throw | `runtime_core.c:4562` | small | `"hello"[10]` silently returns `""`. Mirror `hexa_array_get` OOB throw for symmetry. |
| 11 | `.step_by(n)` runtime + codegen alias | `runtime_core.c` new fn + `codegen_c2.hexa:3386` | small-medium | Add `hexa_array_step_by(arr, n)` + alias as a sibling of `.rev()` [#351]. |
| 12 | `rt_str_chars` pure-hexa fallback codepoint walk | `self/rt/string.hexa:32` | small | Compiled `hexa_str_chars` walks codepoints; the pure-hexa fallback walks bytes. Build-flag (`HEXA_HAS_HEXA_RT_STDLIB`) parity gap. |
| 13 | `nil` / `null` ident | lexer keyword OR parser | small | `nil` silently → `void` (free ident); `null` undeclared. Decide: reserve / alias / diagnose. |
| 14 | enum `to_string` returns tag, not `"Type::Variant"` | runtime + codegen | medium | `test_compact_enum.hexa` documents 14 FAILs on this. Thread enum-tag→name table into the runtime to_string path. |

## Soundness highlight (high-priority HOLD)

| # | name | severity |
|---|---|---|
| H1 | fn-param narrow-type UB | 🚨 **soundness**: `fn f(x:i32) -> i32 { x+1 }` called with `"hi"` returns non-deterministic ~4-billion int (reads pointer/tag as int).  Round-4 numeric agent's headline finding.  See #358 § numeric. |

## Design-level (already filed; cross-ref)

The bigger items already have inbox patches:

- `let` immutability + match exhaustiveness — [#347]
- closure mutable-capture by-value — [#349]
- round-3 design batch (Option/Result · string interp · unicode · array
  index neg-wrap · enum design surface · range repr · float
  literals/keywords/casing) — [#354]
- runtime.h decl debt — [#357] (102 codegen-called closed by #360, 64 non-
  codegen-called remain; recommend automation per option (1))
- round-4 design batch (modules visibility/from-loader/circular · pub
  AST wire · destructuring tuple type · struct impl semantics · numeric
  narrow enforcement · async/spawn/select/atomic/channel) — [#358]

## This session's surgical landings (cross-ref)

```
fix (22 PR):
  CLI      #342 cmd_parse · #362 from-loader gate
  lexer    #371 0o/0b reject · #372 5i32 suffix reject
  parser   #345 match `=>` · #364 &self · #366 enum multi-arg · #373 pub-everywhere
  codegen  #344 as-cast · #346 fn-value · #351 .rev · #352 format!
           #367 Type::method · #369 fail-loud · #370 Self {…}
  decl     #348 hexa_is_type · #350 hexa_array_shift · #356 hexa_await_unwrap
           #360 mass-decl 102
  runtime  #353 chr(0) NUL · #355 idx err msgs

inbox (6 PR including this one):
  #347 let immutability + match exhaustiveness
  #349 closure mut-capture
  #354 round-3 design batch
  #357 decl-debt class (166 / 102 codegen-called)
  #358 round-4 design batch
  THIS post-merge tail
```

## Out of session

#348 / #350 closed as superseded by #360 (which declared the same fns
plus 100 more in one block).  #373 (`pub` parsing) blocked on a
base-branch policy requiring non-pusher review.
