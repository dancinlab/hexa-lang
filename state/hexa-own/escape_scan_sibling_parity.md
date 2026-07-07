<!-- @canonical-ok — task-specified doc name for the escape-scan sibling-parity divergence-family audit -->
# mem-lane ② escape-scan sibling-parity — divergence-family close-out audit

Status: **FAMILY CLOSED (source). No arms added.** Structural sibling-parity audit +
empirical re-proof of the two scan pairs in `self/codegen.hexa`. Branch
`fix/mem-escape-scan-sibling-parity` off `origin/main` @ `8b1eb0e45` (= current HEAD,
includes #4690 `node.args` + #4691 박제 + #4693 TryCatch-arm). Doc-only — no code change.

Closes the arr-scan / value-scan divergence family behind #4690 + #4693: a rigorous
per-arm field-set diff proves the array-descriptor scan is now a **complete superset** of
the value scan (modulo the two intentional by-design semantic asymmetries), so the
whack-a-mole is over — there is **no third latent hole** for the HEXA_STACK_ALLOC flip to hit.

---

## The family — two scan pairs that must stay in lockstep
- `_expr_escapes_name` (value, L12790) ↔ `_expr_escapes_arr_name` (array-descriptor, L13248)
- `_stmt_escapes_name` (value, L12863) ↔ `_stmt_escapes_arr_name` (array-descriptor, L13340)
  (+ the `_stmts_escape_*` list wrappers, trivially symmetric)

The value scan is the reference (feeds the DEFAULT-ON `_native_arr_noescape_scan`, L13136,
for int/float-literal arrays). The arr-scan (HEXA_STACK_ALLOC-gated via `_stack_noescape_arr_scan`,
L13478→2078) is the one that historically diverged (written later, arm-by-arm).

## Arm-inventory diff (programmatic field/kind extraction over each fn body)

### EXPR pair
| | `_expr_escapes_name` (value) | `_expr_escapes_arr_name` (arr) |
|---|---|---|
| recursed child-fields | left, right, items, **args**, fields[].left, cond | left, right, items, **args**, fields[].left, cond |
| special-case kinds | `Field` (allow `p.field` receiver) | `Index` (allow `a[i]` read) · `Call`/`len` (allow `len(a)`) |

- **fields: value − arr = ∅ · arr − value = ∅** (identical recursed field set).
- kind asymmetry {Field} vs {Index,len,Call} = intentional consumption model (values by field,
  arrays by index/len); both route the generic tail through the SAME field set. Not a hole.
- `node.args` present in BOTH (arr got it via #4690, mirroring the value-scan c17 fix).

### STMT pair
| | `_stmt_escapes_name` (value) | `_stmt_escapes_arr_name` (arr) |
|---|---|---|
| stmt kinds handled | LetMutStmt, AtomicLet, AssignStmt, ReturnStmt, **TryCatch, RecoverStmt** | LetMutStmt, AtomicLet, AssignStmt (+**Index-write escape**), ReturnStmt, **TryCatch, RecoverStmt** |
| expr slots | left, right, value, cond | left, right, value, cond |
| nested stmt-lists | then_body, else_body, body, arms[].body, **TryCatch/Recover left/right** | then_body, else_body, body, arms[].body, **TryCatch/Recover left/right** |

- **fields: value − arr = ∅** (arr covers every field the value scan visits; the lone `args`
  token flagged in the arr fn is a #4690 *comment reference*, not a field access).
- kind asymmetry: arr-only `Index`-write → escape (mutation voids the bounded read-only proof).
  Intentional. Not a hole.
- `TryCatch || RecoverStmt` arm present in BOTH (added by #4693 to value @L12891 and arr @L13376),
  routing try_body/catch_body statement-lists through `_stmts_escape_*` (statement scan), matching
  #4691's prescribed fix exactly.

### Verdict: **no remaining divergence.** Deltas (value visits / arr does not) = **NONE** in both
pairs. `arms_added = none — family closed`. #4690 (args) + #4693 (TryCatch/RecoverStmt) are the
complete closure. The value scan is the reference and the arr-scan mirrors it 1:1 for every
recursed field/arm.

---

## Empirical re-proof (aiden x86_64-linux, clang-18 · captured)

★ MANDATORY re-proof caveat: a clean from-source build of *current main* was **blocked by the
runtime-coherence + own-start infra wall** (`hxlcl_getenv` UND · `runtime.a` `_start`/CRT
multiple-definition) — quarantined as infra per the known `stage_prebuild_hexat` / coherent-
runtime.a class. The evidence below rests on the static audit + #4693's own captured re-proof
(c14 rc=0 from source) + the release-timeline reconciliation.

1. **Corpus transpile with the flag ON — ZERO crash.** `HEXA_STACK_ALLOC=1 hexa cc --regen`
   transpiled all four SSOT modules: `lexer=ok parser=ok tc=ok cg=ok` (codegen → 22,016 lines C).
   The compiler modules themselves don't hit the literal-array+try/catch trigger shape, so the
   flag is emit-safe over the corpus.
2. **Flag-OFF vs flag-ON regen = identical** transpile-OK + identical Phase-3 link UND
   (`rt_str_trim`, `rt_map_get_native`, `floor`). The link UND is **flag-independent stale-runtime
   infra** (present flag-OFF too), not a scan effect.
3. **c14/try_arr crash reproduced ONLY on the shipped release binary — which is PRE-#4693.**
   Trigger (fully bisected): a `let a = [int/float-LITERAL array]` binding + a `try`/`catch` in the
   same fn (variable-element array → no trigger; `if`/`else` or plain-return → no trigger). Backtrace:
   runaway `_expr_escapes_name` recursion (the value scan) via the DEFAULT-ON `_native_arr_noescape_scan`
   → `hexa_map_get` → ~196k `map key 'kind'/'left' not found` → SIGSEGV (rc=139). This is exactly the
   #4691-박제'd "pre-existing try/catch+array codegen crash," which #4693 fixes in source.

### Why the shipped binary still crashes — release LAG, not a source hole
| artifact | c14 transpile | note |
|---|---|---|
| **current main source** (8b1eb0e45) | fixed at source | both fix arms present (12836/12891 value · 13313/13376 arr); #4693 captured rc=0 from source |
| v0.577.0 released binary | rc=0 (compiles) | predates the regression entirely |
| **v0.691.1 (Latest) released binary** | **rc=139 (SIGSEGV)** | **created 2026-07-07 08:55:26Z — 1 s BEFORE #4693 merged (08:55:27Z)** → built from PRE-#4693 commit |
| v0.691.0 released binary | rc=139 | created 08:49:38Z — pre-#4693 |

The fix is on main but **not yet in any published release binary** — the newest release was cut
~1 second before #4693 merged. Consumers installing today (`install.sh` → `releases/latest`) still
get the crashing pre-fix compiler.

---

## Verdict
- **Sibling-parity divergence family: CLOSED (source).** No third hole; the arr-scan is a complete
  superset of the value scan. `arms_added = none`.
- **HEXA_STACK_ALLOC flip — source-unblocked**: the #4691-documented try/catch+array crash is fixed
  by #4693 in current main; the escape-scan machinery has no remaining sibling-parity divergence.
- **BUT flip re-attempt requires a post-#4693 release**: cut + verify a new release binary (confirm
  c14 → rc=0 on the *shipped* hexat) before the default-ON campaign, since the current Latest release
  still carries the crash. This is a release-freshness gap, not a source defect.

## Recommendations (follow-on lanes)
1. **Cut a post-#4693 release** and re-verify c14/try_arr → rc=0 on the shipped `install.sh` binary.
2. **Extend the miscompile-zero gate to the C-transpile path.** It currently exercises native
   `--emit=obj` (arm64-darwin, `miscompile-zero-gate.yml`); the crash lives on the `hexat` / `hexa run`
   C-transpile path. A pre-#4693 binary passes the native-emit gate while crashing on transpile —
   c14 only truly guards the shipped path once the transpile path is gated too.
3. Fix the coherent-runtime / own-start infra wall so from-source current-main re-proofs
   (`hexa cc --regen` → linkable hexat) are runnable on the pool without the `hxlcl_getenv` /
   `runtime.a` `_start` conflict.

## Repro fixtures (in-tree, from #4690/#4691/#4693)
`self/test/miscompile_zero/c14_array_trycatch.hexa` already covers both the int-array default-ON
path (`chk_int`) and the string-array gated path (`chk_str`). Minimal standalone:
```hexa
fn f() { let a = [1, 2, 3]           // int/float-LITERAL array → DEFAULT-ON value scan
         try { return 9 } catch e { return 0 } }   // co-occurring try/catch = trigger
fn main() { print(f()) }
```
No new fixture added (family closed; c14 already gates the class once the transpile-path gate lands).
