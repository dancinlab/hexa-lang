# codegen: write to a non-`mut` `let` loop counter is silently dropped → infinite loop / hang

- **Source**: anima #1795 (OMEGA-C / HEXAD cross-module forward wiring), filed cross-repo per `a_runpod_inbox`.
- **Toolchain**: `hexa 0.1.0-dispatch`, `hexa run` → `hexat` → clang (compiled codegen path; interp retired).
- **Status**: ✅ RESOLVED (2026-06-04) — fixed by the **HX2006 immutability diagnostic** at S2 (bind), so the previously-SILENT write is now a VISIBLE compile-time diagnostic instead of a silent runtime hang. See "Resolution" below.
- **Severity**: correctness — a loop that should terminate runs forever. No compile-time diagnostic; the failure is silent at runtime.

## Resolution (2026-06-04)

Fixed per **suggested direction #1 (reject at compile time)** — `compiler/check/bind.hexa`
(S2 bind pass) now emits **HX2006 — "cannot assign to immutable binding `x`
(declared without `mut`)"** on a write to a function-local non-`mut` `let`.
This turns the silent runtime hang into a visible compile-time diagnostic. Lands
as the **upstream fix** (self-hosted compiler only; `hexa-cc` untouched, retiring).

- **Where**: `compiler/check/bind.hexa` (`_bind_is_mut` mutability probe + the
  Assign branch in `_bind_walk_expr` + `_emit_hx2006`), the new `HX2006` catalog
  entry in `compiler/diag/catalog.hexa`, regression cases (d)/(e) in
  `compiler/check/bind_test.hexa`. The parser already tracked the `Mut` token
  (`mut:` name prefix); the gap was the unenforced write-side check.
- **Scope finding — PERVASIVE.** An in-tree corpus sweep flagged **~1033**
  pre-existing function-local non-`mut` writes across **76** files (crypto ·
  aws-sigv4 · math · atlas-verifiers) that the silent-drop tolerated *outside*
  loops. Hard-erroring all of them would brick the self-host build before stdlib
  migration. So **HX2006 lands as a WARNING by default** (build-safe, no longer
  silent) and **escalates to a hard Error under `HEXA_STRICT_LET=1`** (same
  opt-in gate the legacy `self/type_checker.hexa` already honours). The full
  stdlib `mut`-migration to flip the default to Error is tracked as follow-up.
- **Two false-positive classes fixed** vs the first WIP cut (10460 → genuine
  1033): (1) the parser synthesises one `X = E` init-assign per top-level `let`
  into the merged `main` body — those target module-frame globals; (2) writes to
  module-level `let mut` globals from a function. Both are module-frame (global
  slot, NOT the miscompiled stack-slot case), so `_bind_is_mut` returns `2` for
  any outermost-frame match and the diagnostic is suppressed there.
- **Verify (verbatim)**: installed `hexa` on the repro → `exit=143` (silent
  HANG); the `let mut` control → `exit=0`. The fixed `bind()` flags the repro
  with `HX2006 @5:5` and the `let mut` control with 0 hits. `bind_test.hexa`
  cases (a)–(e) PASS (`exit=0`), with (d) showing `HX2006 (warning S2)` and (e)
  showing 0.

## Symptom

A loop counter declared with a plain (non-`mut`) `let` is **written inside the loop body** — either by reassignment (`i = i + 1`) or by a fresh `let` rebind (`let i = i + 1`). Under the current 0.1.0-dispatch codegen the write does **not** update the slot the loop condition reads: the counter stays at its initial value, the condition never flips, and the loop spins forever.

The front-end does **not** reject the write to a non-`mut` binding either, so the error is invisible until the binary hangs.

## Affected pattern (anima HEXAD context — #1795)

The #1795 author hit this in two verified `.hexa` cores during HEXAD cross-module forward wiring:

- `s_lib` — `s_perception` / `_s_col_mean` (column-mean reduction over a perception tensor)
- `m_lib` — `m_retrieve_topk` (top-k retrieval scan)

Both advance a scan counter with a non-`mut` `let` idiom. The libs are **mathematically correct** — the bug is purely in how the current codegen lowers a write to a non-`mut` `let` inside a loop. The #1795 author worked around it by reimplementing those two closed-form cores inline with codegen-safe `let mut` counters (identical math) and flagged the toolchain fix as follow-up (this report). The workaround lives in anima and should not be the permanent fix — the verified libs should compile correctly once codegen is fixed.

## Minimal repro

`hexa build` succeeds; running the binary hangs. Confirmed with a 6s `timeout` (exit 124/143).

```hexa
// nonmut_repro.hexa — non-`mut` let loop counter, written inside the loop.
fn main() -> int {
  let n = 3
  let i = 0          // NON-mut binding
  while i < n {
    i = i + 1        // write silently dropped under 0.1.0-dispatch codegen
  }
  return i           // never reached — loop spins forever
}
```

Equivalent hang with a `let` **rebind** (shadow) instead of reassignment:

```hexa
  while i < n {
    let i = i + 1    // also dropped — loop spins forever
  }
```

### Contrast (control) — the canonical `let mut` idiom terminates correctly

```hexa
fn main() -> int {
  let n = 3
  let mut i = 0      // mut binding
  while i < n {
    i = i + 1
  }
  return i           // returns 3, terminates
}
```

Observed (all at `hexa 0.1.0-dispatch`, 6s timeout):

| variant | counter decl | body write | result |
|---|---|---|---|
| A | `let i = 0` | `i = i + 1` | **HANG** (timeout) |
| B | `let i = 0` | `let i = i + 1` (rebind) | **HANG** (timeout) |
| D | `let mut i = 0` | `i = i + 1` | terminates, returns 3 ✓ |

`hexa build` on A/B succeeds with no error — the hang is purely at runtime. The stdlib loop idiom (`stdlib/flame/optim_lib.hexa`, `let mut s = 0; while s < shards { ...; s = s + 1 }`) is exactly variant D, which is why stdlib loops are unaffected.

### Refinement vs the #1795 framing

#1795 framed this as a non-`mut` `let` **rebind** (`let i = i + 1`) issue. Local repro shows it is broader: **any** write to a non-`mut` `let` binding inside a loop is dropped — both reassignment (`i = i + 1`) and `let` rebind (`let i = i + 1`) hang identically. The distinguishing axis is `mut` vs non-`mut`, not reassign-vs-rebind.

## Suggested fix direction

Two acceptable resolutions (either closes the hole; the first is the cleaner invariant):

1. **Reject at compile time.** The front-end should error on a write (reassignment OR `let` rebind that aliases the same name in the same scope) to a non-`mut` `let` binding — `error: cannot assign to immutable binding 'i' (declared without 'mut')`, the same class of diagnostic the language already implies by having `let mut`. This turns a silent runtime hang into a clear compile error and matches the existing `let mut` semantics. Mut-tracking already exists in the front-end (`compiler/check/`, parser tracks the `Mut` token); the gap is that the write-side check is not enforced on the codegen path.

2. **Lower it correctly.** If a non-`mut` `let` rebind inside a loop is intended to be legal (shadow-then-carry), codegen must actually re-assign the induction slot the condition reads, so the loop advances. This is the more permissive option but requires defining the intended semantics of a same-name `let` rebind across loop iterations (carry vs fresh-each-iteration).

The minimum bar is: **no silent infinite loop** — a non-`mut` write in a loop must either be a compile error or be lowered to a real update.

## Repro files

Self-contained; paste either snippet into a `.hexa` file and `timeout 6 hexa run <file>`. No GPU, no deps, $0.
