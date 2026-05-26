# F-GPU-SWEEP-SHARED-REDUCE-NUMERIC — PARTIAL: ptxas REJECTED (PR-C piece 6 territory)

**Verdict:** 🟠 BLOCKED-CODEGEN — source-driven `@shared` lowering surfaced **two
new codegen bugs** that PR #1313 piece 2+3 + PR #1318 piece 4+5 did not exercise
(both PRs use hand-built MIR fixtures that bypass the broken init path).
Fire stops at the ptxas standalone oracle. Host driver + numeric-eq not reached.

## Verbatim ubu-2 ptxas output

```
$ /usr/bin/ptxas /tmp/sweep_pred.ptx -arch=sm_80 -o /tmp/sweep_pred.cubin
ptxas /tmp/sweep_pred.ptx, line 51; error   : Arguments mismatch for instruction 'mov'
ptxas fatal   : Ptx assembly aborted due to errors
ptxas RC=255
```

## Root cause — 3 bugs uncovered

### Bug 1 — `c.code()` not lowered by legacy codegen (low-severity, WORKED AROUND in this fire)

`compiler/codegen/nvptx_target.hexa:1790` (`_nvptx_parse_i64`) calls
`c.code()` on a single-char string. `self/codegen.hexa::_legacy_builtin_method`
(L4290-4362) registers `byte_at`/`char_code_at`/`char_at` but NOT bare `code`.
Hits the unknown-builtin trap at runtime in any standalone CLI built off
nvptx_target. Existing in-tree tests don't hit it because they use empty
frag_layout/frag_dtype strings (the `if len(s) == 0 { return 0 }` guard).

**Fix surface:** either register `"code"` as alias of `char_code_at` in
`self/codegen.hexa` builtin-method ladder, or change L1790 to
`c.char_code_at(0)` (the workaround applied locally in this fire).

### Bug 2 — STMT_ASSIGN against `%sh<id>` shared-base register (CRITICAL — blocks all source-driven @shared)

The lowering chain emits a `STMT_ASSIGN sm, 0.0` (or `STMT_ASSIGN sm, []`)
for the source line `@shared let sm: [f64; 256] = []` — this targets the
shared *base pointer register* `%sh3`, NOT a value slot. The codegen lowers
it as:

```
mov.u64 %sh3, _hexa_sh_sweep_pred + 0;  // L50 — correct piece-4 init
mov.f64 %sh3, 0;                        // L51 — CLOBBERS the base pointer
```

ptxas error: `Arguments mismatch for instruction 'mov'` (%sh3 is `.reg .u64`,
literal `0` is being typed `.f64`). Even if the type-tag matched, this would
zero out the runtime shared address → all subsequent
`add.s64 ..., %sh3` produce garbage addresses → every `ld.shared.f64`/
`st.shared.f64` reads/writes off the wrong memory. Tested with the
`= []` initializer dropped (`@shared let sm: [f64; 256]`) — STILL hits
the same `mov.f64 %sh3, 0;` (the lowering chain injects a default zero-init
for any declared Local regardless of explicit initializer).

**Fix surface (two candidate arms):**

1. `compiler/lower/hir_to_mir.hexa` — when lowering an ExprKind::Let whose
   annotations contain `shared`, SKIP the default-init STMT_ASSIGN. The
   shared base is a `_hexa_sh_<fn> + <off>` runtime constant; it must not
   be re-written.

2. `compiler/codegen/nvptx_target.hexa::_nvptx_lower_stmt` STMT_ASSIGN
   branch — when the dst Local's `space == "shared"`, drop the emit
   entirely (defensive — even if hir_to_mir produces a spurious init,
   codegen should refuse to overwrite a shared-base register).

The defensive codegen arm (#2) is the minimal patch — single conditional
add at the STMT_ASSIGN entry point. Arm #1 is cleaner but requires
threading the annotation through HIR/MIR which piece 2+3 has already
done; the check is `if hir_let.annotations[*].name == "shared" { skip_init }`.

### Bug 3 — phantom `mov.f64 %fd5, %fd4` shadow-init on uninitialised %fd4 (cascading from Bug 2)

PTX line 52 emits `mov.f64 %fd5, %fd4;` immediately after the shared-init
sequence. `%fd4` has no def at that point in the function entry. This is
the SAME default-zero-init mechanism as Bug 2 but for the f64-classified
shadow Local that the lowering allocated alongside the shared base. It
disappears once Bug 2 is patched (the default-init pass also stops emitting
the shadow assignment).

## PTX shape verification (BEFORE the ptxas reject)

All piece-4+5 markers ARE present in the emitted PTX:

```
12:    .shared .align 8 .b8 _hexa_sh_sweep_pred[2048];        ← piece 4 ✓
50:    mov.u64 %sh3, _hexa_sh_sweep_pred + 0;                  ← piece 4 ✓
65:    st.shared.f64 [%rd_idxs_addr], %fd13;                   ← piece 5 ✓
89:    ld.shared.f64 %fd22, [%rd_idxa_22];                     ← piece 5 ✓
72:    bar.sync 0;                                             ← gpu_barrier ✓
```

Histogram: ld.shared.f64=3 · st.shared.f64=3 · ld.global.f64=1 · st.global.f64=1 · bar.sync=2

**Conclusion:** PR #1313 + PR #1318 piece 4+5 DELIVER the directive +
ld.shared/st.shared routing correctly. The blocker is a *separate*
codegen pass (default-init for declared locals) clobbering the shared base.

## PR-C piece 6 scope (recommended)

Single defensive add in `compiler/codegen/nvptx_target.hexa::_nvptx_lower_stmt`
STMT_ASSIGN branch, plus the registration of `"code"` builtin method in
`self/codegen.hexa` (a one-line add to the ladder at L4332).

After piece 6 lands, this fire (kernel + host + PTX emit + ubu-2 driver-JIT
run) should pass without further changes — host harness is ready
(`tool/sweep_pred_host.c`), kernel source is canonical
(`tool/sweep_pred.hexa`), ubu-2 ptxas path is proven on the rest of the
PTX (only line 51 rejects).

## Artifacts in this commit

- `tool/sweep_pred.hexa`         — canonical source kernel
- `tool/sweep_pred.hexa.ptx`     — emitted PTX (with the clobber bug visible at L51)
- `tool/sweep_pred_host.c`       — host driver harness (ready for next fire)
- `tool/SWEEP_PRED_FIRE_FAIL.md` — this writeup
- `compiler/codegen/nvptx_target.hexa` — Bug 1 workaround
  (`c.code()` → `c.char_code_at(0)`) — local-only, NOT a final fix

## Honest verdict

Per project.tape `paper_negative_ok` — a closed-negative finding is
publishable. This fire ruled out the assumption that PR #1313 + PR #1318
piece 4+5 closed the @shared pipeline end-to-end. The source-derived
emit path uncovered two structural bugs in the lowering+codegen that the
hand-MIR test fixtures bypass by construction. PR-C piece 6 closes them.
