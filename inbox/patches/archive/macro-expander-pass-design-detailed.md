# macro-expander-pass-design-detailed — concrete blueprint for the expander cycle

**Filed**: 2026-05-23 — follow-up to PR #419 (`MacroCall fail-loud at parse-time`).
**Status**: design-level, expander pass deferred to a future cycle.
**Supersedes**: `inbox/patches/macro-expander-pass-design.md` (97 LoC stub) — keeps the
high-level strategy framing; this doc adds the concrete algorithm, AST shapes,
hygiene strategy, intrinsic table, acceptance criteria, and 4-phase roadmap so
the next implementer has a blueprint instead of starting from scratch.
**Related**: PR #419 (MacroCall fail-loud) · PR #352 (legacy `MacroCall→Call`
desugar, superseded by #419) · PR #381 (`format()` brace-escape unification).

## 1. Problem statement

**Current state (post-PR #419):**

- `self/parser.hexa` `parse_postfix` `Not` arm builds a `MacroCall` AST node
  AND records a parse error: `"macro invocation '<name>!(...)' is not yet
  implemented — file an inbox patch for the expander pass"`. Source location
  is preserved for caret rendering (post-PR #444).
- `self/codegen.hexa` MacroCall arm is a dead-code internal-error guard:
  `eprintln + exit(1)` if reached. Reaching it = compiler contract bug.
- `self/parser.hexa` `parse_macro_def` (L4281) already parses
  `macro! name { (pat) => { body } ... }` declarations into a
  `MacroDef { name, rules: [MacroRule { params, body }] }` AST. Definitions
  parse cleanly today; only invocations are gated.

**Goal:** lift the parse-time gate by adding an `expand_macros` pass that
runs between parse and codegen. Each `MacroCall` node is replaced by the
macro body's AST with caller arguments substituted into formal parameter
positions. The pass runs to a fixed point so macros may invoke macros.

**Non-goals (this cycle):**

- Compile-time function evaluation (Zig `comptime`-style) — see §9.
- Conditional compilation `#[cfg(...)]` — separate feature, separate inbox.
- Full Racket-style syntax-context hygiene tagging — `gensym`-first is enough
  for v1; tagging is a Phase 4+ amendment (see §5).

## 2. Strategy comparison

Three serious candidates for the expander mechanism. PR #419's stub already
sketched (1) vs (2); the table below adds the Zig comptime axis and a
recommendation row.

| approach | pros | cons |
|---|---|---|
| **Token-tree splicing** (Rust `macro_rules!` declarative) | hygienic with `gensym`, well-trodden, fits hexa's AST-first nature, smallest scope | requires token-tree retention through parse (hexa currently keeps tokens in `MacroRule.params` already — half the work is done) |
| **Procedural macros** (Rust `proc_macro` 1.x-style) | maximal flexibility, macros are arbitrary code | requires a compile-time hexa interpreter (huge — couples macros to whatever the runtime-in-the-compiler story becomes); brittle build graph |
| **`comptime fn` invocation** (Zig-style) | reuses hexa eval machinery if/when added, no separate macro language | needs a comptime-fn restriction lint (no I/O, no mutable global state); not yet scaffolded; couples macros to eval |

**Recommendation: token-tree splicing for v1.** Rationale:

- Smallest implementation scope (~200 LoC for the expander + ~50 for the
  intrinsic table — see §8).
- Matches the AST-first nature of hexa (everything else in the compiler is an
  AST pass).
- The hygiene problem is well-understood; `gensym`-first buys ~80% of the
  win and ships in Phase 3 (~80 LoC).
- Path is not foreclosed: a future Phase 5 could layer `comptime fn` macros
  on top by reusing the same `expand_macros` walk with a different rule
  dispatch.

## 3. AST shape

Definition and invocation nodes are already in the parser. Sketched here
for the implementer's reference (see `self/parser.hexa:2921` and
`self/parser.hexa:4281`):

```
MacroDef  = { kind="MacroDef",  name: string, rules: [MacroRule] }
MacroRule = { kind="MacroRule", params: [token], body: BlockExpr }
MacroCall = { kind="MacroCall", left: NameExpr, op: "(" | "[", args: [Expr] }
```

Where **token-tree** = a recursive structure: each tree is either an
**atom** (a single lexer token: ident · literal · operator · keyword) or a
**balanced bracket group** (`()` / `[]` / `{}`) containing zero or more
child trees. Current parser flattens to a `[token]` list inside
`MacroRule.params` — Phase 4 (see §8) re-builds the nested tree to enable
`macro_rules!`-style pattern fragments (`$e:expr`, `$($x:ident),*`).

For v1 (Phase 1 + Phase 2): keep the flat `[token]` representation, treat
each pattern position as a single AST-expr slot (positional).

## 4. Expansion algorithm

```
expand_macros(ast)
  global _macro_table     : #{name -> MacroDef}              // populated parse-pass-2
  global _intrinsic_table : #{name -> fn(args) -> AST}       // hard-coded, see §6
  global _expanding_set   : #{name -> bool}                  // cycle guard
  const MAX_DEPTH = 32
```

Steps:

1. **Index pass.** After parse-pass-2 completes, walk top-level decls. For
   every `MacroDef`, insert into `_macro_table[name] = def`. Duplicate name =
   hard error: `"macro <name> redefined at L:C (previous at L:C)"`.

2. **Walk pass.** New `expand_macros(ast, depth)` recursively walks all AST
   nodes. For each `MacroCall` encountered:

   a. **Intrinsic dispatch.** If `name in _intrinsic_table`, call the intrinsic
      fn with `args`. Replace the `MacroCall` node with the returned AST. Done.

   b. **User-macro dispatch.** Else look up `name` in `_macro_table`. Miss →
      hard error: `"unknown macro '<name>!' at L:C — no MacroDef in scope"`
      (mirror PR #444 caret rendering).

   c. **Cycle guard.** If `_expanding_set[name] == true`, hard error:
      `"recursive macro expansion of '<name>!' at L:C"`. Else mark
      `_expanding_set[name] = true` for the duration of this call.

   d. **Depth guard.** If `depth >= MAX_DEPTH` (32), hard error:
      `"macro expansion depth limit (32) exceeded at L:C — likely infinite
       recursion in '<name>!'"`. This is distinct from (c): mutual
      recursion `a! → b! → a!` is caught by (c); deep linear chains
      `a! → a!` (different name each rule arm) are caught by (d).

   e. **Pattern match.** Walk `def.rules`. For each `MacroRule`, attempt to
      bind `args` against `rule.params` (positional v1: arity must match, no
      pattern fragments). First match wins. No match → hard error:
      `"no macro rule matches <name>!(<arity> args) at L:C"` with the list
      of arities seen in `def.rules`.

   f. **Substitute.** Clone `rule.body` (deep copy — see implementation note
      below). For every `Name` node in the clone whose `name` is one of
      `rule.params`, replace with the corresponding `args[i]` (also a deep
      clone — the same arg may appear multiple times in the body).

   g. **Recursive expand.** Call `expand_macros(expanded, depth + 1)` so the
      result may itself contain `MacroCall` nodes. (This is the fixpoint.)

   h. **Re-parse if needed.** v1 substitutes at AST level, so re-parsing
      is unnecessary. Phase 4 (token-tree pattern fragments) will need a
      mini re-parse step here — out of scope.

   i. **Replace.** Splice the expanded AST in place of the `MacroCall` node.

   j. Clear `_expanding_set[name]`.

3. **Fixed-point.** The walk is single-pass: step (g) handles inner
   MacroCalls during expansion, so a second top-level pass is not needed.

**Implementation note — deep clone.** Naive `dict_copy` is shallow; the
expander needs structural clone so that mutating one expansion does not
mutate the cached `MacroDef.body`. A small `ast_clone(node)` helper
(~30 LoC: recursive walk over the AST shape's known keys) goes in
`self/macro_expander.hexa` alongside the pass.

## 5. Hygiene strategy

**v1 (Phase 2 + Phase 3): `gensym`-first.**

Every binding-introducing node inside a freshly cloned macro body is
rewritten to use a unique suffixed name:

- `let x = ...` → `let __mac_<macroname>_<callid>_x = ...`
- `fn foo(a, b) { ... }` → `fn __mac_<macroname>_<callid>_foo(__mac_..._a,
  __mac_..._b) { ... }` (with corresponding references in the body)
- `match` arms with pattern bindings — same rewrite.

`<callid>` = monotone counter per `expand_macros` invocation. This prevents
the textbook hygiene bug:

```hexa
let x = 1
set!(x)        // expands to: let x = 2; — naively shadows outer x
println(x)     // would print 2 without hygiene
```

With `gensym` the expansion becomes `let __mac_set_7_x = 2; ...`, leaving
the outer `x` untouched. `println(x)` correctly prints `1`.

Limitation: `gensym` does NOT fix **capture in the other direction** —
references inside the macro body to outer names. The macro `print_x!()
{ println(x) }` invoked in a scope where `x` is in scope WILL capture
that `x`. Rust's solution is full syntax-context tagging (Phase 4+
amendment); for v1 this is documented as a known restriction.

**v2 (future, see §9): syntax-context tagging.** Every token in the
expansion carries its source context (macro-def site vs call site).
Resolution rules check context boundaries. This is the Racket / late-rustc
model. Out of scope; ~300+ LoC; needs a name-resolution pass redesign.

## 6. Intrinsic-macro table (first cut, Phase 1)

Even before the user-macro expander lands, a small allowlist of built-in
macros can ship in **Phase 1** as a hardcoded dispatch table. This
unblocks the most common `name!()` ergonomics with the smallest
implementation surface (~50 LoC in `self/codegen.hexa` or a new
`self/macro_intrinsic.hexa`).

| macro | desugars to | notes |
|---|---|---|
| `format!(fmt, ...args)` | `format(fmt, ...args)` | already special-cased — PR #352 (legacy desugar) + PR #381 (brace-escape). Keep the existing path; the new intrinsic table is the canonical home going forward. |
| `vec![a, b, c]` | `[a, b, c]` (array literal) | simple AST swap: `MacroCall{op="["}` → `Array{items=args}`. |
| `assert!(cond)` | `if !(cond) { panic("assert failed at L:C: " + <cond_source>) }` | `<cond_source>` = the raw source text of the condition expr (recoverable from token spans). |
| `dbg!(expr)` | `{ let __dbg = expr; println("[debug] L:C: " + to_string(__dbg)); __dbg }` | block-expr; preserves value. The `__dbg` temp is gensym'd to avoid capture. |
| `println!(fmt, ...args)` | `println(format(fmt, ...args))` | composes `format!` + `println` for Rust-source compatibility. |
| `panic!(msg)` | `panic(msg)` | thin alias; `panic!()` (no args) → `panic("explicit panic")`. |

Each is a hardcoded entry in `_intrinsic_macro_table`. User-defined macros
with the same name are rejected at index time (step 1) with a
`"<name>! is a reserved intrinsic macro"` error.

## 7. Acceptance criteria

The expander cycle is complete when all of the following pass:

1. **User-macro round-trip.** `macro! shout { ($x) => { println(to_string($x)
   .to_upper()) } }` defined; `shout!("hi")` invocation expands and codegens
   to runtime output `HI`.
2. **Intrinsic round-trip.** `assert!(false)` at runtime emits the diagnostic
   `assert failed at <file>:<L:C>` and exits non-zero.
3. **Nested expansion.** Macro inside macro: 2-level fixpoint. E.g.
   `macro! a { () => { b!() } }; macro! b { () => { 42 } }; a!()` evaluates
   to `42`.
4. **Recursive max-depth guard.** `macro! loop { () => { loop!() } }; loop!()`
   hits the depth-32 guard cleanly — diagnostic + exit, **no SEGV**.
5. **Cycle guard.** `macro! a { () => { b!() } }; macro! b { () => { a!() } };
   a!()` hits the `_expanding_set` cycle guard, diagnostic + exit.
6. **Hygiene gensym.** `let x = 1; macro! set { () => { let x = 2 } }; set!();
   println(x)` prints `1`, not `2`.
7. **Diagnostics location.** All macro errors (unknown / arity / cycle /
   depth) include source `L:C` and (post-PR #444) caret rendering of the
   call site.
8. **Regression.** `hexa parse self/parser.hexa` and `hexa parse
   self/codegen.hexa` still clean. `tests/regression/parse_macro_*.hexa`
   (current corpus) all pass.

## 8. Phasing — 4 stacked PRs per g4

Each phase is a separate PR; later phases land on top of earlier ones.

| phase | scope | est. LoC | est. wall | landing target |
|---|---|---|---|---|
| **Phase 1: intrinsic-only** | allowlist (`vec!` · `assert!` · `dbg!` · `println!` · `panic!`); `format!` migrates from PR #352 desugar path to the intrinsic table; user-macros still parse-error per PR #419 | ~50 LoC in `self/macro_intrinsic.hexa` (new) + parser allowlist branch | 1 cycle | unlocks Rust-source compat for the common case |
| **Phase 2: user-macro expander, positional, no hygiene** | `self/macro_expander.hexa` (new, ~200 LoC); `_macro_table` build; positional substitution; cycle + depth guards; arity match; lift PR #419 parse-error to defined-macro check | ~200 LoC new + ~30 LoC parser delta | 1 cycle | user macros work; capture bugs possible |
| **Phase 3: gensym hygiene** | binding-introducer rewrite on cloned body; ~80 LoC delta in `self/macro_expander.hexa`; new test corpus `tests/regression/macro_hygiene_*.hexa` | ~80 LoC | 1 cycle | acceptance #6 passes |
| **Phase 4: `macro_rules!`-style pattern matching** | token-tree fragments (`$e:expr`, `$id:ident`, `$($x:ty),*`); pattern-arm dispatch beyond positional; nested token-tree retention through parse | ~300 LoC | 2 cycles | Rust `macro_rules!` parity |

g4 stacked-PR rule: Phase 2 `--base` Phase 1; Phase 3 `--base` Phase 2; etc.
Each phase ships its own falsifier corpus and updates this inbox doc to
mark the phase delivered.

## 9. Out of scope (file separately later)

- **Proc macros / `comptime fn` macros.** Require a compile-time hexa
  interpreter or a substantial AST-quotation API. File as a separate inbox
  RFC if there is a concrete user demand; until then declarative
  `macro_rules!`-style is enough.
- **`#[cfg(...)]` conditional compilation.** Separate feature with its own
  attribute resolution semantics. Not a macro-expander concern.
- **Hygiene v2 — syntax-context tagging.** Racket / late-rustc model. ~300+
  LoC; needs a name-resolution pass redesign. File as a separate inbox
  amendment once Phase 3 lands and gensym limitations bite a real user.
- **`derive!` macros.** A derive-style macro that synthesizes trait impls
  from a struct decl is a different mechanism (attribute-driven, not call-
  driven). Already partially scaffolded via `@derive(...)` — separate path,
  separate inbox.

## 10. References

- **PR #419** — `MacroCall` parse-time fail-loud + existing stub
  (`inbox/patches/macro-expander-pass-design.md`).
- **PR #352** — legacy `MacroCall → Call` desugar (superseded by #419);
  retained for `format!` until Phase 1 of this RFC migrates it.
- **PR #381** — `format()` brace-escape `{{` / `}}` unification (relevant
  for `format!` intrinsic).
- **PR #444** — parse-error caret rendering (used by all macro diagnostics
  for L:C + source-snippet output).
- **Rust Reference §3.5** — *Macros By Example* (declarative
  `macro_rules!` semantics).
- **Zig comptime** — reference for the comptime-fn alternative considered
  in §2 and rejected for v1.
- **Racket — Macros and Hygiene** — reference for the v2 syntax-context
  tagging path noted in §5 and §9.

---

**Closing note for the implementer.** Start with Phase 1 (intrinsic
allowlist). It is bounded, lifts the `format!` special-case into a
canonical home, and ships immediate user value with zero hygiene risk.
Phase 2 follows on top with the user-macro expander; Phase 3 adds
`gensym`; Phase 4 pursues `macro_rules!` parity. Each phase is a single
PR per g4; this inbox file is updated phase-by-phase and deleted in
Phase 4's closing commit per the standard inbox lifecycle (see PR #419
acceptance §last).
