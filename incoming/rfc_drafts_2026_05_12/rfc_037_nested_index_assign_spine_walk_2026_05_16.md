# RFC 037 — nested mixed-key index-assign spine-walk (3-level `p[s][i][s]=v` early-stop)

> Status: **FILED (named-item, non-urgent)** · d=2026-05-16 · filed-from: anima HEXAD
> Trigger pattern: PR #80 RFC-trigger-spec. Downstream (anima) is **unblocked via
> a no-risk workaround** (`mitosis_hook_lib.hexa::_mit_pool_set_cell_field` +
> anima-side flat rewrites) ⟹ this RFC is **NON-URGENT**: hexa-lang's own cycle.

## 1. Summary

Compiled (AOT) lowering of a **≥3-level nested index-assignment with mixed key
kinds** — e.g. `Ident[strlit][int][strlit] = v` — walks the `Index` spine and
**stops one level early**, emitting an assignment whose LHS is a
`hexa_index_get(...)` call (a C **rvalue**, not an lvalue) → clang
`error: expression is not assignable`. The interpreter handles the same source
correctly, so this is an **AOT-codegen-only** defect (interp ≠ compiled).

## 2. Minimal reproduction

```hexa
fn go() {
    let mut p = #{ "cells": [ #{ "h": [1,2] } ] }
    p["cells"][0]["h"] = [9, 9]            // Ident[strlit][int][strlit]  (3-level, mixed-key)
    println(to_string(p["cells"][0]["h"]))
}
fn main() { go() }
```

- `hexa run <repro>`  → **OK** prints `[9, 9]`.
- `hexa build <repro>` → generated C: `... = hexa_index_set(...)` where the LHS
  is `hexa_index_get(p_cells, ...)` (non-lvalue) → clang
  **`error: expression is not assignable`**. No binary produced.

Confirmed in-the-wild this session (anima): `HEXAD/CHAT/chat_lib.hexa` (cell-pool
deep mutation) + `HEXAD/integ_train_smoke.hexa` (`tool/hexa_native/
mitosis_hook_lib.hexa` cell_pool nested field set) — same 4× `expression is not
assignable` signature, same root.

## 3. Root cause (code-cited)

`self/codegen_c2.hexa::_gen2_nested_index_assign_stmt` (≈L2132) — spine walk:

```hexa
let mut cur = lhs
while type_of(cur) != "string" && cur.kind == "Index" {
    keys_rev.push(gen2_expr(cur.right))
    cur = cur.left
}
let root_c = gen2_expr(cur)   // expected: the ROOT lvalue (Ident/Field)
```

The walk terminates as soon as `cur.kind != "Index"`. For the mixed-key
3-level LHS, the AST handed to `_gen2_nested_index_assign_stmt` is **not a
uniform `Index` spine all the way to the root** — the `IndexAssign` Node
constructed in `self/build_c.hexa` (≈L1345/L1353, the `Node { kind:
"IndexAssign", ... left: lhs.left, right: lhs.right ... }` rewrites) pre-splits
part of the spine, so by the time codegen_c2 walks it the loop hits a
non-`Index` node **one level too early**. Result: an inner `hexa_index_get`
subtree is mis-identified as `root_c` and emitted as the assignment target →
non-lvalue C. This is a **dual-backend** invariant: `build_c.hexa` IndexAssign
construction and `codegen_c2.hexa` spine-walk must agree on the *full* spine
decomposition (root + ordered keys k0..kN) for arbitrary N and arbitrary key
kinds (strlit / int / expr), interleaved.

## 4. Fix spec (for hexa-lang's cycle — not implemented here)

1. **codegen_c2.hexa `_gen2_nested_index_assign_stmt`**: make the spine-walk
   robust to the actual `IndexAssign` Node shape produced by `build_c.hexa` —
   collect ALL keys down to the genuine root lvalue (Ident/Field/…), not until
   the first non-`Index` kind. Equivalently: `build_c.hexa` should hand a
   canonical full `Index` spine (or an explicit `(root, [k0..kN])` tuple) so
   the two backends share one decomposition.
2. **build_c.hexa IndexAssign (≈L1345/1353, the L2720 area the field-rewrite
   path lives in)**: ensure the `left`/`right` split preserves the entire
   chain for N≥3 + mixed key kinds (do not collapse an interior `Index` into
   a value-bearing node before codegen sees it).
3. **Regression (MANDATORY — byte-identical 1/2-level)**: 1-level
   `a[i]=v` and 2-level `a[i][j]=v` generated-C must stay **byte-identical**
   to pre-fix output (these currently work — `_gen2_nested_index_assign_stmt`
   already handles depth ≤2; the fix must not perturb them). Add to the
   hexa-lang test suite: N∈{1,2,3,4} × key-kind matrices {strlit, int, expr}
   interleaved (incl. the §2 repro), each asserting compiled binary == interp
   output. PR should land with these green.

## 5. Acceptance criteria

- §2 repro: `hexa build` → 0 errors, binary, output `[9, 9]` == `hexa run`.
- N∈{1,2,3,4} mixed-key nested index-assign: compiled binary byte-equals
  interpreter for all combinations in the new suite.
- 1-/2-level generated C **byte-identical** to pre-fix (no regression).
- Full existing compiled-native suite stays green.

## 6. Priority / dependency

**NON-URGENT.** anima (the only known consumer hitting this) is fully
unblocked via a no-risk anima-side workaround (flat field-set helper +
avoiding the 3-level mixed nested-assign in hot paths). No anima deliverable
blocks on this. File → hexa-lang's own scheduling. No downstream gate.

## 7. Provenance

- Filed from anima HEXAD session 2026-05-16 (R2 saga + Phase 6 integ wiring
  surfaced it; anima `g_fire_autonomous` governance — this is the lone
  non-fire residual, recorded as a named-item per the user directive).
- Repro: `/tmp/nidx_repro.hexa` (inlined §2).
- Code anchors: `self/codegen_c2.hexa` L2132 (`_gen2_nested_index_assign_stmt`)
  + L2221 (call site) ; `self/build_c.hexa` L1345/L1353 (IndexAssign Node).
