<!-- @canonical-ok — explicitly-requested state doc name for this bug-fix round -->
# mem-lane ② escape-scan args-hole — use-after-scope false-negative fix

**Branch:** `fix/mem-escape-scan-args-hole` · **File:** `self/codegen.hexa`
**Class:** codegen soundness (stack-alloc escape analysis) · **byteeq posture:** NEUTRAL (opt-in-path-only)

## Root cause

The array-descriptor escape scan `_expr_escapes_arr_name` (self/codegen.hexa, gen2
C-transpile codegen) recurses `node.left / node.right / node.items / node.fields /
node.cond` but was **MISSING the `node.args` traversal** that its value-scan sibling
`_expr_escapes_name` HAS (the c17 packed-f64 fix — `while i < len(node.args) { … }`
between the items loop and the fields loop).

Call and method-call arguments live in **`node.args`, NOT `node.items`** (confirmed
against the parser: `"kind": "Call", … "args": args` — parser.hexa `LParen` arm ~L3597;
`buckets.push(empty)` = `Call(left=Field(buckets,push), args=[empty])`). Because the
generic recursion never visited `node.args`, an array binding handed to an opaque sink
as a call/method argument — `f(empty)`, `x.push(empty)` — was **never detected as
escaping**.

Non-`len` `Call` nodes fall through the `k == "Call"` block (only `len(a)` is
special-cased there) into the generic recursion, so the miss applied to every
push/append/store-through-call of an array binding.

Consequence under **`HEXA_STACK_ALLOC=1`** (opt-in): the binding was wrongly proven
non-escaping → the HexaArr descriptor + items buffer stack-allocated in the frame →
`buckets.push(empty); … return buckets` published a **dangling stack pointer** past the
frame → use-after-scope **SIGSEGV (rc=139)**.

## Concrete repro

`self/module_loader.hexa` `ml_hset_new` (~L889):

```
fn ml_hset_new() {
    let mut buckets = []
    let mut bi = 0
    while bi < 64 {
        let empty = []          // ← falsely proven non-escaping (push arg missed)
        buckets.push(empty)     // ← escape via node.args, never scanned
        bi = bi + 1
    }
    return buckets              // ← returns container holding dangling stack descriptors
}
```

Prior measurement (origin/main, UNPATCHED): compile module_loader.hexa with
`HEXA_STACK_ALLOC=1` + run → **rc=139, 3/3**. This is the ② memory-lane bug the
whole-corpus proof exposed; it blocks the `HEXA_STACK_ALLOC` default-ON flip.

## Fix (reference-match — mirror the sibling, no invention)

Added the exact `node.args` traversal loop from `_expr_escapes_name` into
`_expr_escapes_arr_name`'s generic recursion, in the same position (between the
`node.items` loop and the `node.fields` loop), recursing through
`_expr_escapes_arr_name` on each arg. Any appearance of `name` in the arg list now
counts as an escape → binding stays boxed/heap → no dangling stack pointer.

**Statement-form audit** (`_stmt_escapes_arr_name` vs `_stmt_escapes_name`): the two
statement scans already MATCH structurally — same LetMutStmt/AtomicLet, AssignStmt,
ReturnStmt, generic (left/right/value/cond) and nested-body (then/else/body/arms)
handling. `_stmt_escapes_arr_name` is in fact a strict **superset** (it adds an
Index-write `a[i]=v` escape check appropriate for the array case). Both statement forms
delegate ALL expression scanning to their `_expr_escapes_*` sibling, so the method-call
`ExprStmt` `buckets.push(empty)` (Call carried in `node.left`/`node.value`) now flows
through the fixed `node.args` traversal. **No separate statement-form change needed** —
the hole was purely in the expr scan.

## Byteeq neutrality (reachability-confirmed opt-in-only)

`_expr_escapes_arr_name` / `_stmt_escapes_arr_name` are reached ONLY via
`_stack_noescape_arr_scan(node.body)`, which is called ONLY inside
`if _stack_alloc_enabled() { … }` (codegen.hexa ~L2076-2079). With the default build
(`HEXA_STACK_ALLOC` unset) the `_stack_noescape_arr_set` is reset-empty →
`_is_stack_noescape_arr` returns false for every name → the opt-in arr-stack-alloc
LetStmt arm (~L3514) never fires. The scan result feeds ONLY the opt-in stack-alloc
path; the default shipping path uses the already-sound `_expr_escapes_name`. Therefore
the fix is **byteeq-NEUTRAL for the default shipping build** (bit-identical); the flip
gate `_stack_alloc_enabled()` is untouched (stays opt-IN — the default-ON flip is a
separate later round after this lands + re-proof).

## Re-proof (aiden, x86_64-linux)

**Method note / caveat — the runtime segfault did NOT reproduce on aiden
(REPRO-INVALID for the crash *symptom*), but the miscompile and its fix are proven
DETERMINISTICALLY at the emitted-C level (a stronger proof than the flaky crash).**

- **Baseline runtime (UNPATCHED, `HEXA_STACK_ALLOC=1`): rc=0 ×3** (module_loader
  self-test PASS ×3; a purpose-built dangling-read driver also rc=0, correct output
  `0` ×3). The expected `rc=139` was NOT observed. The bug is genuine use-after-scope
  UB, but under this host's `clang -O2` + prebuilt runtime.a the dangling stack slot
  happens to still read length-0, so the read stays benign. The prior "rc=139 3/3"
  does not hold on this build/config — the crash is nondeterministic.
- **Baseline emitted-C (UNPATCHED, `HEXA_STACK_ALLOC=1`) — DEFECT CONFIRMED,
  deterministic.** `ml_hset_new` and the driver's `build_hs` both emit a stack
  descriptor stored into the returned container:
  ```c
  HexaVal __stk_empty_items[1];
  HexaArr __stk_empty = { __stk_empty_items, 0, 0 };
  HexaVal empty; empty.tag = TAG_ARRAY; empty.arr_ptr = &__stk_empty; // dangling into buckets
  ```
- **Patched emitted-C (`HEXA_STACK_ALLOC=1`) — FIX CONFIRMED, deterministic.** After
  rebuilding hexat from patched codegen, the SAME site emits heap allocation — escape
  now detected, no stack descriptor:
  ```c
  HexaVal empty = hexa_array_new();
  ```
  (in both `ml_hset_new` and `build_hs`). Patched runtime: module_loader rc=0 ×3,
  driver rc=0 ×3.
- **Default (no `HEXA_STACK_ALLOC`): rc=0**, self-test PASS — default path unaffected.
- **Self-host transpile: GREEN.** `hexa cc --regen` re-transpiled all 4 SSOT modules
  (lexer/parser/type_checker/**codegen**) through the patched codegen, merged C
  compiled cleanly to `.o` (hexa_cc.c grew by exactly the added args loop ~12 lines).
  The patched `build/hexat` then re-transpiled the full self closure (incl. codegen
  itself + module_loader) with no errors — gen2 self-consistency holds.
- **Infra:** no `stage_prebuild_hexat` nm-probe flakiness (transpile driven via
  `hexa cc --regen` + manual link, not the prebuild path) — `HEXA_ZEROC_OWN_START`
  workaround not needed.

**Verdict:** patch correctness CONFIRMED (deterministic emitted-C: escape via call/
method arg is no longer stack-allocated) + self-hosts cleanly + default byteeq-neutral.
Runtime crash RED→GREEN transition is REPRO-INVALID on this host (nondeterministic UB
stays benign under clang -O2) — the deterministic emitted-C diff is the authoritative
proof. Byteeq 3-target GREEN is delegated to PR CI (opt-in-path-only ⇒ expected neutral).

## Convergence

array-descriptor escape scan (`_expr_escapes_arr_name`) had **diverged from the value
scan (`_expr_escapes_name`) on the args-fix** (c17). The value scan received the
`node.args` traversal; the array scan did not. Re-anchor rule: the two escape scans must
stay in lockstep on child-slot coverage — any slot one recurses (left/right/items/**args**
/fields/cond) the other must recurse too, else a call-arg / push-arg escape is missed on
one side. This fix restores lockstep.
