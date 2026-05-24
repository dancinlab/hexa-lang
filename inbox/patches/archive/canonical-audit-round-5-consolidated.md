# canonical-deviation audit round 5 — consolidated (6 axes)

> **Status update (2026-05-23):** the 3 HIGH match-pattern silent-miscompiles are **FIXED + deployed** — guard incorporation (#379), OR/Range pattern lowering (#380), and bare-Ident binding-pattern + guard (#412), all activated by the hexa_v2 regen (#413). Verified e2e through the deployed toolchain: `n if n>100 -> "big"` → big/medium/small; `1|2|3 -> "x"` dispatches; `0..10` / `10..=20` range arms dispatch (inclusive boundary correct). Remaining items (operator-overload bypass, generic-bounds non-enforcement, Option/Result lane) are **design-level** language surfaces — tracked, not silent-miscompile bugs.

**Status:** 🟠 design-level remainder (match miscompiles closed)
**Reporter:** anima session — round 5 parallel probe fanout
**Severity:** mixed — **3 silent miscompiles** in match patterns (HIGH),
plus large design surfaces (operator overload bypass, generic bounds
non-enforcement) and many parser/codegen gaps.

Round 5 fanned out 6 parallel probes: iterator · pattern guards/ranges
· string-format spec · generic bounds · const/static · operator
overloading.  All probes ran against a local-checkout binary that
**predated #360** (mass-decl) — the iterator probe's "missing decl"
findings re-checked against #360's actual diff confirm 18/18 are
covered.  This patch filters that noise and reports the true-positive
deviations.

## 🚨 Critical — match pattern silent miscompiles (re-verified post-#360)

| name | repro | want | hexa | site |
|---|---|---|---|---|
| **guard silently dropped** | `match 5 { 5 if false => "wrong" _ => "right" }` | `"right"` | `"wrong"` — guard ignored, arm fires anyway | codegen omits `&& hexa_truthy(guard)` from arm condition |
| **OR-pattern bitwise collapse** | `match 1 { 1 \| 2 \| 3 => "small" _ => "big" }` | `"small"` | `"big"` — `1\|2\|3` parsed as bitwise OR `=3`, only `v==3` matches | parser treats `\|` in pattern position as expression operator |
| **range pattern as expression** | `match 5 { 0..10 => "small" _ => "big" }` | `"small"` | `"big"` — `0..10` becomes a range-array value compared via `hexa_eq` | pattern-position context not differentiated from expression-position |

All three are **Class-1 silent-failure** per hexa's own
silent-failure-enforcement framework — the wrong arm executes silently,
no warning, no diagnostic.  Root cause is one systemic deviation:
**pattern grammar reuses the expression parser**.  Five sibling
parser-side bugs surface from the same root: simple binder `n => …`
(codegen treats `n` as ref-to-undeclared), struct-pattern shorthand
`{x, y}`, struct-pattern field-literal narrowing `{x: 0, y}`, nested
`Some(Point{x,y})`, `@`-binding `name @ pat`.

## Operator overloading (a9892f59) — design RFC

**Total bypass** of user impls: `+`/`-`/`*`/`/`/`==`/`<`/`+=`/`-`/`!`/`[]`/`for` /
`d(7)` (Fn) / `Display` (println auto-fmt) / `.into()` / `.clone()` /
`Drop` — every operator and every standard-library-style trait method
routes through the runtime builtin path, **never consulting the impl
table**.  `a + b` on two structs returns the **concatenation of their
stringified map dumps** because `hexa_add` falls back to string-concat
of `__repr__`.

Most-severe sub-findings:

- `Display`/`fmt`/`to_string`/println-auto-fmt — `println(p)` prints
  the raw `{__type__: P, x:3}` map dump regardless of any impl.
- `Index` — `c[0]` on a struct emits `"container is not an array (tag=6)"`.
- `for x in StructWithIter` — iterates struct **field-name keys**
  (`"__type__"`, `"n"`) ignoring any `Iterator` impl.
- `clone`/`into` — codegen builtin-method denylist preempts user impl.
- `Drop` — `drop` is reserved as a keyword; `impl Drop for R` doesn't
  parse.
- `impl X for Y` discards the trait name `X` at binding time → the
  trait is decoration; no vtable, no coherence.

Surgical sub-items extractable:

| name | repro | classification | proposed action |
|---|---|---|---|
| `clone` builtin clash | `a.clone()` when user `impl Clone for R` | fix-surgical | drop `clone` from builtin denylist when user impl exists |
| `into` builtin clash | `.into()` blocked by denylist | fix-surgical | same as above |
| `Drop` keyword collision | `impl Drop for R` parse error | fix-surgical | unreserve `drop` in identifier context |
| `Type::method` mangle call-site (re-flag) | `Meters::new(5)` emits `Meters_new` (PR #367 attempted) | fix-surgical | PR #367 audit — codegen still emits `hexa_array_push(arr, Meters_new)` per probe; double-check the fix actually reaches all dispatch paths |

The remaining design lane = trait-dispatch table for BinOp / UnOp /
Comparison / Index / Call / Assign-op — **`compiler/parse/parser.hexa`**
emits `BinOp` with `text=op` only, never rewrites to a trait-method
call.  Mirrors Rust's operator-trait coherence (Add/Sub/Mul/Div/Rem/
Neg/Not/Eq/PartialOrd/AddAssign/Index/Fn) at the bind phase.

## Generic bounds (ae466b15) — 7 parser gaps + 1 silent semantic

Top-level `fn id<T>` and `struct Pair<A,B>` work canonically.
**Every composition step** fails:

| feature | repro | error |
|---|---|---|
| generic struct as type in signature | `fn unbox<T>(b: Box<T>) -> T` | parse error — `Box<T>` not recognized in type position |
| generic enum | `enum Option<T> { Some(T), None }` | parse error at `<` |
| single trait bound (enforce) | `fn pick<T: Ord>(…)` called with non-`Ord` value | **silently accepts** — bound parsed but never enforced |
| multiple bounds | `fn f<T: Show + Clone>(…)` | parse error at `+` |
| where clause | `fn f<T>(…) where T: Show` | parse error at `where` |
| generic impl | `impl<T: Show> C<T>` | parse error at `<` |
| method-level generic | `impl P { fn pair<U>(self, other: U) }` | parse error at `<` |

The **bound non-enforcement** is the Class-1 silent failure: hexa's own
silent-failure-enforcement audit flags this category.  Lifetime params
`<'a>` are out of scope — hexa has no borrow checker; document as
non-goal.

## String format spec (a93bf91b) — 16 broken specs

`format("…{}…", x)` (PR #352) works; the spec surface inside `{}` is
mostly absent.  Two of these are **silent corruption**:

| failure mode | examples |
|---|---|
| silent fallthrough (numeric/spec entirely dropped) | `{:x}` `{:X}` `{:o}` `{:b}` `{:#x}` `{:+}` `{:e}` `{:E}` `{:0>5}` `{:*<5}` `{:_>5}` `{1} {0}` (positional) `{name}` |
| partial (width works, precision lost) | `{:8.2}` — width 8 applied, `.2` dropped |
| **silent corruption** | excess args (`format("{}", 1, 2, 3)` → `"1"`) · missing args (`format("{} {}", 1)` → `"1 {}"`, raw `{}` in output) |
| **brace escape broken** | `{{}}` not escaped — emits literally `{{}}` instead of `{}` |
| parser block | `{name=…}` named args — hexa has no kwargs syntax |

Stacked PR sequence: brace-escape (lexer-only) · radix family + `#`
alt-form · fill+align two-char prefix · sign flag · width+precision
combination · positional `{N}` · arg-count diagnostic · scientific
`{:e}`.

## Const / static (a3fd0015) — 6 surgical bugs + 1 spec gap

| name | site | classification |
|---|---|---|
| `StaticStmt` codegen missing dispatch | `self/codegen_c2.hexa` gen2_stmt | fix-surgical (re-confirms round-4) |
| `VarStmt` module-top dropped (same family) | sibling site | fix-surgical |
| local-scope `const` mutation silently accepted | `type_checker_v2.c` | **soundness** — track const-bind flag in local symtab |
| top-level `const` mutation leaks to clang | same | fix-surgical — emit `cannot assign to const X` at frontend |
| duplicate const decl silently accepted (incl. type-mismatch) | top-level symbol table | fix-surgical — dedupe pass |
| forward const-ref → clang `undeclared` | codegen emission order | fix-surgical — topo-sort ConstStmt emission |
| `const` accepts runtime-fn initializer (Swift `let`-style) | semantic | RFC — pick "Rust-strict compile-time" vs "Swift-permissive immutable" |

## Iterator (a8a53dc) — design + 6 codegen gaps

Most "missing decl" findings in the raw report were false positives
(#360 already covers `hexa_count_poly`/`hexa_array_min/max/zip/take/
drop/product/mean/chunk/window/unique/rotate/partition/interleave/
scan/for_each/find/flat_map`).  Real gaps:

| name | repro | classification | proposed action |
|---|---|---|---|
| `.iter()` / `.collect()` absent | `[1,2,3].iter().collect()` | inbox-design | design RFC — eager vs lazy semantics |
| `.first` / `.last` / `.nth` codegen alias | `[10,20,30].first()` | fix-surgical | add `if method == "first" { return "hexa_array_get(... ,0)" }` near `codegen_c2.hexa:3490` |
| `.skip(n)` asymmetric vs `.drop(n)` | `arr.skip(2)` rejected; `.drop` works | fix-surgical | one-line alias |
| `.reduce` / `.chain` / `.take_while` / `.skip_while` | iterator combinators | fix-surgical | small codegen + runtime fns |
| iterator protocol trait absent | `trait Iterator { fn next(self) -> Option<T> }` | inbox-design | extensible iterator design |

## Stale-binary noise

The probes ran against a binary that predated #360 (mass-decl).  The
iterator probe's 18 "missing decl" entries were re-verified against
the merged #360 diff and confirmed covered.  Future round probes
should run after `hexa cc --regen` against current main.

## Cross-refs

Sibling inboxes: #347 binding · #349 closure · #354 round-3 · #357
decl-debt class · #358 round-4 · #374 post-merge tail · #375
fork-storm source-block.
