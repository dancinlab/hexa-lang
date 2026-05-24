# PROBE r15-D17 — `{}` block does NOT create new lexical scope (silent correctness)

**Filed:** 2026-05-24 · session `inbox/websocat-tool-discovery-2026-05-23`
**Severity:** CRITICAL — silent miscompilation, no diagnostic, no error
**Status:** INVESTIGATED → BLOCKED (architectural; not 40 LoC; ≥150 LoC + risk surface)

## Repro

```hexa
fn main() {
    let x = 1
    println("outer: " + to_string(x))
    {
        let x = 2
        println("inner: " + to_string(x))
    }
    println("outer again: " + to_string(x))
}
```

Canonical (Rust/Swift): `outer: 1` / `inner: 2` / `outer again: 1`.
Hexa (compiled, `hexa build`):
```
outer: 1
inner: 1
outer again: 1
```

Inner `let x = 2` is silently no-op (parser accepts, codegen flat-hoists). All
three probes in `/tmp/probe-r15/shadowing/` (block-scope · same-scope shadow ·
for-loop shadow) FAIL with the same root cause.

## Root cause (located, verified)

`self/codegen.hexa` flat-hoists every `let` in a function to function scope via
`_gen2_collect_lets_stmt` (L2449). The brace-group emission for `BlockStmt`
itself is correct (L2669 emits `{ … }` in C), but the inner `let x` is hoisted
to the same `HexaVal x` declaration as the outer one — both bindings alias the
same C variable, so the second `let` becomes a re-assignment of the outer.

The parser file even has a comment acknowledging this (L1429-1434):
> NOTE on scope: hexa codegen flat-hoists every `let` per function
> (`_gen2_collect_lets` — see PROBE.log r3 #6). So `let` inside the
> bare-block does NOT introduce a fresh lexical scope today; the
> outer-leak behavior is unchanged. This PR ships only the PARSE
> acceptance — lexical-scope correctness is a separate codegen RFC
> (the same RFC that fixes match-arm `let` leak).

## Why not a surgical 40-LoC fix

The task estimated ~40 LoC in a resolver. There is no separate resolver pass —
codegen does both binding-hoist AND ident-resolution inline. A correct fix
must:

1. AST pre-pass detecting `let X` inside nested `BlockStmt` whose `X` is also
   bound in an enclosing scope.
2. Rename the inner binding (e.g. `X` → `X__blk<N>`) at the `let` site.
3. Rewrite **all subsequent** `Ident("X")` references **within that block's
   tail** (but not before the `let`, and not outside the block) to the new
   name.
4. Handle nested `BlockStmt` inside `IfExpr.then_body` / `else_body`,
   `WhileStmt.body`, `ForStmt.body`, `MatchArm.body`, `LoopStmt.body`, lambda
   bodies, and `MatchExpr` arms — each has its own brace-group at C codegen
   time but no scope-aware ident resolution.
5. Preserve closure mut-capture box semantics (`_gen2_compute_boxed_cells`)
   under the renamed names.
6. Not regress `_known_int_add` / `_known_float_add` / `_register_comptime_const`
   tables keyed by original name.
7. Same fix family applies to:
   - probe_2 (`let x = "1"; let x = 1` shadow in same scope — type change)
   - probe_3 (for-loop var shadowing outer ident)
   - match-arm `let` leak (called out in the parser comment above)

Realistic LoC: 150-300 plus a regression-test pass over the existing self-host
build (`gen1.s ≡ gen2.s` byte-eq fixpoint per `project_compiler_native_self_host_fixpoint`).

## Suggested approach (next-cycle)

Stage as a dedicated RFC (e.g. `rfc_LEX_SCOPE_2026_05_24`) with phases:

- **P0** — AST walker `_lex_scope_rewrite(ast)` running before
  `_gen2_collect_lets`. Walks every `FnDecl.body`, maintains a `[[name]]`
  scope stack, descends into `BlockStmt` / `IfExpr.*_body` / loop bodies /
  match arms / lambda bodies, renames on collision.
- **P1** — Mirror `_gen2_collect_lets_stmt` traversal exactly so no node
  shape is missed.
- **P2** — Falsifier probes: the 3 in `/tmp/probe-r15/shadowing/` + a
  match-arm `let` leak probe + a self-host fixpoint regression (gen1.s ≡
  gen2.s after the change).
- **P3** — Tape governance entry under `@D lex_scope` (parser comment ↔
  codegen behaviour must stay in sync, no silent "parses but no-ops" again).

## Files touched (read-only investigation)

- `self/parser.hexa:1422-1444` — `BlockStmt` emission (parse-only, no rename)
- `self/codegen.hexa:2449-2517` — `_gen2_collect_lets_stmt` / `_gen2_collect_lets`
- `self/codegen.hexa:2669-2679` — `BlockStmt` codegen (brace-group only)
- `self/codegen.hexa:1685-1720` — fn-decl hoist driver (calls
  `_gen2_collect_lets` and emits dedup'd `HexaVal X;` per name)

## Probes (kept on disk)

- `/tmp/probe-r15/shadowing/probe_1.hexa` — `{}` block scope (Rust shadow)
- `/tmp/probe-r15/shadowing/probe_2.hexa` — same-scope shadow w/ type change
- `/tmp/probe-r15/shadowing/probe_3.hexa` — for-loop var shadowing

All three currently FAIL with outer-leak behavior. Re-run after the RFC
lands to validate.

## Cross-refs

- `project_compiler_native_self_host_fixpoint` — fixpoint at risk if rename
  is non-deterministic
- `feedback_no_interp_use_compiled` — probes verified via compiled binary,
  not interp
- Parser self-acknowledgement at `self/parser.hexa:1429-1434` — the
  "separate codegen RFC" referenced there IS this file.

— Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
