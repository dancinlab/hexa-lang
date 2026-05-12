# RFC 029 — `continue` scope inside nested `if` (interp codegen)

- **Status**: FIXED 2026-05-12 (`self/hexa_full.hexa::eval_body`)
- **Date**: 2026-05-12
- **Severity**: BLOCKER (atlas pipeline, any nested-branch loop)
- **Priority**: P0
- **Source convergence**: atlas embed corruption — odd-dup of every continuation line in `compiler/atlas/embedded.gen.hexa`
- **Source session**: 2026-05-12 atlas-absorption Phase 8 unblock

## Problem

In stage0 `hexa_interp` (Mac `~/.hx/packages/hexa/build/hexa_interp.real`, May 12 2026), a `continue` statement **inside a nested `if`** only short-circuits the inner `if`, not the enclosing `while` body. Subsequent statements in the **outer** `if` still execute.

### Minimal repro

```hexa
let mut chunks = []
let mut i = 0
while i < 2 {
  let line = if i == 0 { "@H" } else { "  cont1" }
  let c0 = line.substring(0, 1)
  if c0 != "@" {                  // outer if
    if c0 == " " {                // nested if
      chunks.push(line)
      i = i + 1
      continue                    // ← only breaks the inner if
    }
    chunks.push(line)             // ← STILL EXECUTES when c0 == " "
    i = i + 1
    continue
  }
  i = i + 1
}
println("chunks=" + str(len(chunks)))   // expect 1, observed 2
```

Observed: `chunks=2`, both elements `"  cont1"`. `i` increments twice, so loop ends without processing iter 2 — control-flow drift.

### Where it broke production

`compiler/atlas/parser.hexa` had the exact pattern in its `c0 != "@"` branch. Every continuation line under `@P/@C/@L/@E` got pushed twice, corrupting `AtlasNode.raw`. Downstream:
- `compiler/atlas/embedded.gen.hexa` — all `raw` fields show `\n  -> X\n  -> X\n  => Y\n  => Y` patterns
- atlas Phase 8 (n6 retirement) blocked because the embed is the only source of truth once n6 is deleted
- root cause was misdiagnosed for two sessions as a `use "..."` module-loader drift / parser parity bug

### Outer-only `continue` works

```hexa
while i < 3 {
  if i == 1 {
    chunks.push("A")
    i = i + 1
    continue          // works correctly — skips rest of while body
  }
  chunks.push("B")
  i = i + 1
}
// chunks = ["B", "A", "B"]  — correct
```

So the bug is **specifically about `continue` nested under more than one `if`**.

## Falsifier

- F-029-1: above minimal repro produces `chunks=1` after fix
- F-029-2: atlas embed regenerated from clean n6 source has no duplicate continuation lines
- F-029-3: existing source-side workarounds in `compiler/atlas/parser.hexa` and `tool/atlas_embed_gen_inline.hexa` can be reverted to `if { continue }` form and still produce correct output

## Root cause (confirmed)

Stage0 hexa interpreter is **flag-based** (tree-walking, not bytecode). `ContinueStmt`/`BreakStmt` set `continue_flag` / `break_flag` and rely on outer loop bodies to observe the flag and short-circuit. `WhileStmt` (and `ForStmt`/`ForRangeStmt`) check all four flags (`return_flag || break_flag || continue_flag || throw_flag`) at every iteration of their body stmt-loop and correctly reset on exit.

The bug: `eval_body(stmts)` (which evaluates the body of an `IfStmt`, `IfExpr`, `MatchExpr` arm, etc.) only checked `return_flag || throw_flag` between statements:

```hexa
fn eval_body(stmts) {
    let mut result = val_void()
    let mut _bi = 0
    while _bi < len(stmts) {
        if return_flag || throw_flag { return result }  // ← missed break/continue
        result = exec_stmt_at(stmts, _bi)
        _bi = _bi + 1
    }
    return result
}
```

When an inner `if`-body executed `continue`, the flag was set, but the **outer if-body's `eval_body`** kept iterating its remaining statements (push, assign, the outer `continue`), producing the double-side-effect symptom.

`break` and match arms share the same `eval_body`, so this fix addresses H1 (match-arm continue) and H2 (nested-if break) in one line.

## Fix

`self/hexa_full.hexa` line 9440 — add `|| break_flag || continue_flag` to the gate. One-line change. Verified empirically with three minimal repros (parent continue, match-arm continue, nested-if break) all producing correct output after rebuild.

## Proposal — all complete

### Phase 1: Source workarounds (done 2026-05-12, commit d2c5af7b + c713c9e4)
- `compiler/atlas/parser.hexa` — `c0 != "@"` branch rewritten as `if / else if / else` chain
- `tool/atlas_embed_gen_inline.hexa` — same rewrite (mirror)
- 5 additional audit sites (commit `c713c9e4`): `compiler/check/annotations.hexa`, `compiler/check/types.hexa`, `self/test_tokenizer.hexa`, `tool/ext_lint.hexa`, `tool/runaway_pattern_lint.hexa`

Memory: `feedback_hexa_interp_nested_continue.md` — guidance for future hexa code.

### Phase 2: Interp fix (done 2026-05-12)
One-line patch to `self/hexa_full.hexa::eval_body`. Rebuilt stage0 interp via `tool/build_interp.hexa` pipeline (flatten → hexa_v2 transpile → clang). Promoted to both `build/hexa_interp.real` and `~/.hx/packages/hexa/build/hexa_interp.real`. Backups kept as `.bak.pre-rfc029`.

Verification:
- Parent repro `/tmp/_bug_repro.hexa` → `chunks=1` (correct)
- H1 (match arm continue) `/tmp/_match_arm_continue.hexa` → 2 distinct chunks (correct)
- H2 (nested-if break) `/tmp/_nested_if_break.hexa` → break correctly stops loop (correct)
- `compiler/atlas/static_index_test.hexa` → 9/9 PASS
- `self/test_tokenizer.hexa` → 66/66 PASS
- `self/_bug2_continue.hexa` → correct output

### Phase 3: Workaround revert (optional, deferred)
Source workarounds can revert to the more readable `if { continue }` form once the new interp is stable. Defer until a tag/version cutover is in place — for now, the workarounds are harmless and defensive against older deployed interp binaries.

`tool/atlas_embed_gen_inline.hexa` can be retired (replaced by `tool/atlas_embed_gen.hexa` which uses `use`-based imports) once the workarounds are removed.

## Rollout

- Phase 1 (done): source workaround in parser + inline gen
- Phase 2: clean atlas embed regen → commit → unblock Phase 8 of atlas n6 retirement
- Phase 3: codegen audit — list of any other nested-continue sites
- Phase 4: interp codegen patch + stage0 rebuild + re-promote
- Phase 5: optional revert of workarounds once Phase 4 binary is canonical

## References

- [[feedback_hexa_interp_nested_continue]] — memory entry with the rule of thumb
- `doc/atlas_n6_retirement_plan.md` §0c — original (incorrect) parser-drift diagnosis
- `tool/atlas_embed_gen_inline.hexa` — workaround that bypassed `use` (turns out `use` was innocent)
