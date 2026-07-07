# HEXA_STACK_ALLOC default-ON flip — re-attempt on the #4690-fixed scan

Status: **NOT FLIPPED — measured wall (pre-existing compiler crash).** `_stack_alloc_enabled()`
stays opt-IN (`env("HEXA_STACK_ALLOC") != ""`).

Branch `feat/mem-stack-alloc-default-on`, off `origin/main` @ `748c33977` (INCLUDES the
escape-scan args-hole fix #4690). Build/prove host: aiden (x86_64-linux, clang-18).
Bit-changing codegen → the release gate is byteeq 3-target `gen3≡gen4` on PR-CI (not run: flip aborted).

## #4690 fix — VERIFIED CORRECT (the args-hole is closed)
- `_expr_escapes_arr_name` has the `node.args` loop (self/codegen.hexa ~L13302-13308), mirroring
  the c17 value-scan fix. Confirmed present in source AND baked into the rebuilt hexa_cc.c/hexat
  (`hexa_map_get_ic(node,"args",…)` while-loop in the transpiled `_expr_escapes_arr_name`).
- Authoritative emitted-C check at `self/module_loader.hexa` `ml_hset_new` (fixed hexa + stack ON):
  `empty` → `hexa_array_new()` (HEAP), zero `__stk_empty`. The prior dangling-stack-descriptor
  false-negative is GONE.
- Discriminating control: a fn with a non-escaping `let a=[1,2,3]` (→ `__stk_a` stack) AND a
  push-arg escape `let e=[4,5]; box.push(e)` (→ `hexa_array_new()` heap) — both classified
  correctly. Lever engages; escape caught. Binary runs, byte-identical ON vs OFF.

## Real-workload win — REAL and large (measured)
alloc-heavy: 5M-iter loop, each iter a non-escaping `let tri=[i,i+1,i+2]` (read-only).
Emitted C confirms `tri` → `__stk_tri` stack under ON.

| config | array_new | push | grow | Max RSS | output |
|--------|-----------|------|------|---------|--------|
| OFF    | 5,000,000 | 15,000,000 | 5,000,000 | 1,021,196 KB (~997 MB) | 37500007500000 |
| ON     | **0** | **0** | **0** | **5,612 KB (~5.5 MB)** | 37500007500000 |

25M allocations → 0; RSS ~182× lower; output byte-identical. Matches/exceeds the census
magnitude (20M→0 mallocs, 127MB→1.9MB). The lever is worth shipping — once the wall below is fixed.

## ★ THE WALL — pre-existing stack-alloc codegen crash (BLOCKS default-ON)
Building `self/test/test_module_gate.hexa` (via its `use "self/stdlib/law_io"`) with
HEXA_STACK_ALLOC=1 SEGFAULTS the compiler during transpile: a flood of
`map key 'left' not found` / `map key 'kind' not found` (313k+ lines) then `Segmentation fault`.
Not a false-negative — a codegen-time crash.

Minimal repro (crashes; remove EITHER the array or the try/catch and it is clean):
```hexa
fn chk(p, c) {
    let bad = [".rs", ".py"]                 // stack-eligible bounded non-escaping array
    let mut i = 0
    while i < len(bad) { if p == bad[i] { return 1 } i = i + 1 }
    try { write_file(p, c) } catch e { return 2 }   // ← co-occurring try/catch = trigger
    return 0
}
fn main() { println(to_string(chk("a", "b"))) }
```

### Root cause
The `TryCatch` node (self/parser.hexa:4433-4434) stores `try_body` in **`node.left`** and
`catch_body` in **`node.right`** — both are STATEMENT LISTS. The array escape scan
`_stmt_escapes_arr_name` has NO `TryCatch`/`RecoverStmt` arm, so it falls through to its generic
tail (self/codegen.hexa ~L13353-13357) which routes `node.left`/`node.right` through
`_expr_escapes_arr_name` — the EXPRESSION scan. The expression scan does `let k = node.kind` and
descends `node.left/right/items/args` on what is actually a statement-list → `map key 'kind'/'left'
not found` + runaway/explosive recursion over statement subtrees → stack exhaustion → SIGSEGV.

The candidate-gate (`_stack_noescape_arr_scan`) only calls the scan when a bounded-array candidate
exists, which is why the crash needs BOTH a `let a=[…]` and a `try/catch` in the same fn.

### Attribution — NOT introduced by #4690
Reverting only the #4690 `node.args` loop and rebuilding: the crash STILL fires. The
pre-#4690 release (hexa v0.577.0) does NOT crash on the file → the defect was introduced by some
commit between v0.577.0 and 748c33977, independent of the args-hole fix. #4690 is orthogonal
and correct.

### The exact next fix
Add a `TryCatch` (and `RecoverStmt`) arm to `_stmt_escapes_arr_name` BEFORE the generic
expression tail: route `node.left` (try_body) and `node.right` (catch_body) through
`_stmts_escape_arr_name` (the STATEMENT scan), then `return`. Same divergence class as #4690
(the array scan diverging from the sibling value scan). NOTE: the value scan `_stmt_escapes_name`
(self/codegen.hexa ~L12886-12890) has the IDENTICAL latent hole (no TryCatch arm; left/right →
`_expr_escapes_name`) — it only escapes notice because flat-struct candidates co-occurring with
try/catch are rarer. Fix BOTH scans and add the minimal repro above as a regression gate.

## Go-escape reference
Go's escape analysis (`cmd/compile/internal/escape`) walks the full statement tree including
`OFOR`/`ORANGE`/defer/recover bodies with a dedicated statement visitor — never dispatches a
statement list through the expression walker. The hexa hole is exactly that missing statement-vs-
expression dispatch on try/catch bodies.

## Corpus sweep (fixed scan, stack ON vs OFF)
15 programs built+run both ways: 0 segfaults in the built binaries, output byte-identical
(the one "mismatch" was a shared output-path race, not a miscompile). Stack sites engaged
correctly (compiler corpus: 1 site `sections`; per-program `hdr_u32`/`tri`/`a` etc. all
non-escaping reads). The full self-host build COMPLETES with stack ON and the resulting compiler
runs correctly. The ONLY failure is the try/catch+array crash above.
