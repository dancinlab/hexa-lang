<!-- @canonical-ok — task-specified doc name for the escape-scan TryCatch-arm fix -->
# mem-lane ② escape-scan TryCatch-arm fix — 2nd hole (after #4690 node.args)

Status: **FIXED + re-proven on aiden (x86_64-linux, clang-18).** Root-cause bug fix,
reference-matched to the sibling scans. Branch `fix/mem-escape-scan-trycatch-arm` off
`origin/main` @ `a3f0efd5e` (includes #4690 args-hole fix + #4691 blocker 박제).

This unblocks the HEXA_STACK_ALLOC default-ON flip 3rd re-attempt.

## Root cause — TryCatch statement-lists mis-dispatched to the EXPRESSION scan
A `TryCatch` node (`self/parser.hexa` parse_try_catch, ~L4433-4434) stores **try_body in
`node.left`** and **catch_body in `node.right`** — both are STATEMENT LISTS. A `RecoverStmt`
(~L4481) stores its body in `node.left` (statement list). Both escape scans in
`self/codegen.hexa` had NO `TryCatch`/`RecoverStmt` arm, so a TryCatch node fell through to the
generic tail:
```
if type_of(node.left) != "string" { if _expr_escapes_*(node.left, name) ... }
if type_of(node.right) != "string" { if _expr_escapes_*(node.right, name) ... }
```
A statement-list is an array → `type_of != "string"` passes → the statement-list was routed
through the EXPRESSION scan (`_expr_escapes_arr_name` / `_expr_escapes_name`), which does
`let k = node.kind` on the array (no `kind` key) → **`map key 'kind'/'left' not found`** flood
(~314k) + runaway malformed recursion over statement subtrees → **compiler SIGSEGV during
transpile**. The candidate-gate only invokes the scan when a bounded-array binding exists, so the
crash needs BOTH a `let a=[…]` AND a `try/catch` in the same fn.

2nd hole in the array-scan/value-scan divergence family, after #4690 (`node.args` call-arg hole).

## The fix (reference-matched — mirror then_body/body statement-list handling)
Added a `TryCatch`/`RecoverStmt` arm to BOTH scans in `self/codegen.hexa`, placed after the
`ReturnStmt` arm and BEFORE the generic expression tail, routing `node.left`/`node.right` through
the STATEMENT-list scan (the same `_stmts_escape_*` used by then_body/body), then `return false`:

- `_stmt_escapes_arr_name` (~L13352) → `_stmts_escape_arr_name(node.left/right, name)`
  (GATED path — HEXA_STACK_ALLOC, via `_stack_noescape_arr_scan`).
- `_stmt_escapes_name` (~L12885) → `_stmts_escape_name(node.left/right, name)`
  (DEFAULT-ON path — via `_native_arr_noescape_scan`, ungated).

Go's escape analysis walks defer/recover bodies with a dedicated statement visitor — never
dispatches a statement list through the expression walker. This is exactly the missing
statement-vs-expression dispatch on try/catch bodies.

## ★ default_path_touched = YES — and it fixes a real DEFAULT-build crash
`_stmt_escapes_name` feeds the DEFAULT-ON `_native_arr_noescape_scan` (self/codegen.hexa L2096,
ungated), which runs for **int/float-literal-array** bindings. So the hole is NOT merely latent:
a function with an **int/float-literal array + try/catch** SIGSEGVs the **DEFAULT build** too
(measured: baseline rc=139, ~314k map-key errors — see reproof). The shipping default build is
green today only because no current-corpus fn combines an int/float-literal array with try/catch
(law_io.hexa's `safe_exec` has a STRING array + try/catch → only the gated arr-scan path).

Byte-identity: for all code WITHOUT the combo, default emit is byte-identical (measured IDENTICAL
on the string-array repro, baseline-OFF == fixed-OFF). For the combo, baseline CRASHED (no valid
output); fixed produces valid output — so it is not "byte-changing valid output", it is
crash→correct. Since the shipping corpus has no such combo, the self-host byteeq gen3≡gen4 is
byte-identical. **byteeq 3-target on PR-CI is the release gate (confirms all 3 targets).**

## Minimal repro (crashes baseline; clean fixed)
`self/stdlib/law_io.hexa` `safe_exec` is the in-tree isolated repro (string array `bad` +
try/catch). Minimal standalone (remove EITHER the array or the try/catch → clean):
```hexa
fn chk_int(p) {
    let nums = [1, 2, 3]                       // int-literal array → DEFAULT-ON scan
    let mut i = 0
    while i < len(nums) { if p == nums[i] { return 1 } i = i + 1 }
    try { let _t = 42 } catch e { return 2 }   // co-occurring try/catch = trigger
    return 0
}
```
Committed as regression fixture `self/test/miscompile_zero/c14_array_trycatch.hexa` (covers both
the int-array default-path and string-array gated-path holes).

## Re-proof on aiden (verify-done · captured)
Build: regen `self/native/hexa_cc.c` from the SSOT modules (`hexa cc --regen`, HEXA_LANG pinned to
the worktree), compile → .o, link vs a fresh `build/runtime.a` (stage_resolve_runtime_a) + `-lm`.
Two hexats built from identical inputs except `self/codegen.hexa` (baseline vs +patch).

| test (HEXA_STACK_ALLOC) | BASELINE | FIXED |
|---|---|---|
| minimal repro, flag ON | rc=139, 314,091 map-key err (SIGSEGV) | **rc=0, 0 err** |
| `self/stdlib/law_io.hexa`, flag ON | rc=139, 314,091 err (SIGSEGV) | **rc=0, 0 err** |
| c14 fixture, flag ON | rc=139, 313,995 err | **rc=0, 0 err** |
| c14 fixture, DEFAULT (no flag) | rc=139, 314,115 err (SIGSEGV) | **rc=0, 0 err** |
| string-array repro DEFAULT emit | (baseline-OFF) | fixed-OFF **byte-IDENTICAL** |
| large modules flag ON (codegen/main/parser/module_loader) | — | **all rc=0, 0 err, valid C** |

- Functional: fixed stack-ON emit compiles + runs → correct output (`chk_int:0 chk_str:0`; minimal
  repro → `0`). Stack-alloc lever engages correctly: `bad` →
  `/* [escape→stack] no-escape bounded array bad → stack (no malloc) */` `HexaVal __stk_bad_items[…]`.
- Sanity: trivial file + repro-without-flag transpile clean on both hexats (crash is isolated to
  the array+try/catch combo, not a general breakage).
- self/codegen.hexa (1.3 MB emitted C), main, parser, module_loader all transpile clean with the
  flag ON → full-self-host-transpile-completes proxy. `hexa cc --regen` cg=ok for all SSOT modules.

## Next (after this lands)
HEXA_STACK_ALLOC default-ON flip 3rd re-attempt: corpus zero-crash + zero-false-neg + RSS win
(census: 25M allocs→0, RSS 997MB→5.5MB, byte-identical) + byteeq 3-target GREEN. See
`state/hexa-own/stack_alloc_default_on.md`.
