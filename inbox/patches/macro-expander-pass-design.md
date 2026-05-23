# macro-expander-pass-design — design proposal for `name!(args)` expansion

**Filed**: 2026-05-23 — PROBE r9 finding #6 follow-up.
**Status**: design-level, deferred.
**Related**: parse-time fail-loud landed in the same PR (see commit).

## Symptom

`name!(args)` (Rust-style macro invocation) parses to a `MacroCall` AST
node, but the language has no expander pass. Historically two failure
modes were observed:

1. **Codegen trap** — early versions hit
   `[codegen] ERROR: unhandled expression kind: MacroCall` and crashed
   after clang had already been invoked.
2. **Silent Call routing** — a subsequent workaround routed `MacroCall`
   through the `Call` path so `format!("...", x)` accidentally resolved
   to the `format(...)` intrinsic. Every other `name!(...)` (`shout!`,
   `vec!`, `println!`, ...) then surfaced as an opaque link-time
   "undefined symbol" deep inside the C toolchain.

Both modes confuse the user — the language advertises a macro syntax
but no invocation actually compiles cleanly.

## Short-term fix (LANDED in this PR — Path A per g11/g21)

- `self/parser.hexa` `parse_postfix` `Not` arm — emit a parse-time
  diagnostic at the `!` token:
  `"macro invocation '<name>!(...)' is not yet implemented — file an
   inbox patch for the expander pass (see this file)"`
- The MacroCall AST node is still synthesized after the error so the
  parser can recover and collect downstream diagnostics in the same
  file.
- `self/codegen.hexa` MacroCall arm — converted to an internal-error
  guard (`exit(1)` with an explicit "compiler bug" message). Reaching
  the branch would mean a parse error was recorded but the file was
  transpiled anyway — that is a contract violation, not user code.

This unblocks the user feedback loop without papering over the gap.

## Long-term design (this proposal)

Two strategies, in rough order of complexity:

### 1. Token-tree splicing (Rust `macro_rules!`-style, declarative)

- `@macro fn name(...) { ... }` (already parsed; see
  `parse_macro_def`) captures a body of HEXA expressions / statements
  templated over parameter names.
- A new `expand_macros` pass runs between parse and codegen:
  - Walks the AST, finds `MacroCall` nodes.
  - Resolves `MacroCall.left` to a definition in the current scope
    (lookup via the existing module/use table).
  - Substitutes formal parameters into a fresh clone of the body AST.
  - Replaces the `MacroCall` node with the expanded sub-tree.
- Pass runs to a fixed point (allow macros to invoke macros), bounded
  by `@depth(N)` (already parsed; see `self/attrs/depth.hexa`).

Open questions:

- **Hygiene** — naively spliced bodies will shadow / be shadowed by
  caller locals. Minimum-viable approach: gensym every `let` /
  parameter introduced by an expansion. Stricter: full Racket-style
  syntax-context tagging (deferred; gensym buys 80% of the win).
- **Reporting** — when expansion fails, the error site should point to
  the call site AND show the expansion frame. Mirror the existing
  `Parse error at L:C: msg` format with an expansion stack trail.
- **Compile-time evaluation** — `format!` and friends in Rust do
  string formatting at expand time. Defer; route the few intrinsic
  macros (`format!`, `println!`, ...) directly to their function
  equivalents in a first pass.

### 2. Procedural / `comptime fn` (Rust `proc_macro`-style, imperative)

- Reuses the `comptime fn` machinery (already partially scaffolded).
- The macro body is a `comptime fn` that receives the AST sub-tree
  (or a token stream) and returns a replacement sub-tree.
- More expressive but couples macros to whatever runtime-in-the-compiler
  story HEXA settles on; not the right first cut.

## Recommendation

Land **(1) token-tree splicing** as a separate cycle once the parser
side is stable. Gate intrinsic macros (`format!`, `println!`, `vec!`,
`dbg!`) on a hand-rolled table inside `expand_macros` for the first
pass — defer hygiene to a follow-up.

## Acceptance for the expander cycle

- `name!(args)` parses cleanly when an `@macro fn name(...) { ... }`
  is in scope, fails with a clear "no such macro" diagnostic
  otherwise.
- `hexa parse` and `hexa run` round-trip a small corpus of macro
  invocations without leaking link-time errors.
- Recursive `@macro fn loop() { loop!() }` is bounded by `@depth`
  (see `self/macro_expand.hexa:56` historical comment).
- This inbox file is deleted in the closing commit.
