# RFC 029 — `continue` scope inside nested `if` (interp codegen)

- **Status**: draft
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

## Hypothesis

`continue` codegen emits a control-flow target that resolves to the end of the **innermost enclosing `if`** rather than the **innermost enclosing `loop`**. Likely a single mis-set parent pointer or scope ID in HIR→MIR lowering.

Verification step (when patching codegen):
1. Locate `Continue` emitter in `compiler/codegen` (or stage0 interp evaluator)
2. Confirm the loop-target is taken from a `loop_stack` (or equivalent), not from a generic statement-stack
3. Compare with `break` — if `break` also has this bug, the fix is a single shared fix

## Proposal

### Short term (already done — 2026-05-12)
Source workaround landed in:
- `compiler/atlas/parser.hexa` — `c0 != "@"` branch rewritten as `if / else if / else` chain
- `tool/atlas_embed_gen_inline.hexa` — same rewrite (mirror)

Memory: `feedback_hexa_interp_nested_continue.md` — guidance for future hexa code.

### Medium term
Audit codebase for `if { ... if { ... continue } ... continue }` patterns. Grep:
```
grep -rn "continue" compiler/ tool/ self/ std/ stdlib/ | grep -B5 "continue" | ...
```
manual review of nested-branch loops (any while/for with `>1` `continue`).

### Long term — interp/codegen fix
1. Add `loop_stack` discipline to the evaluator: `continue` resolves to the top of the current loop body, `break` to one past the bottom — never bound to surrounding `if`.
2. Stage0 self-host has the same risk surface. Verify after fix by self-rebuilding and re-running atlas embed regen — output must be byte-identical to source-workaround output.
3. Once landed and stage0 re-promoted, the source workarounds in (Short term) can revert to the more readable `if { continue }` form — but defer revert until a deployed-interp version cutover is confirmed (e.g., `HEXA_VERSION` check or test that fails on old binaries).

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
