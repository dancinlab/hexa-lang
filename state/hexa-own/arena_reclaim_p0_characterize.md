# mem-lane ② arena loop-body RECLAIM — P0 CHARACTERIZE (report-only, widened)

**Status:** ✅ landed as a REPORT-ONLY characterization rung extending the #4700
detector to the rung-1 WIDENED bar. NO emit, NO codegen change, byteeq-neutral by
construction. **Decision gate ANSWERED — see the go/no-go below.**

Branch `feat/mem-arena-reclaim-p0-characterize` (off origin/main @ #4700, includes
#4697/#4700). Built + measured on **aiden** (x86_64-linux, clang-18).

Full design (workflow SSOT, verdict = CHARACTERIZE-MORE-FIRST):
`scratchpad/arena_reclaim_design.md` — soundness_rule (whole-region Tofte–Talpin
predicate), rung1 scope (R1/R2/R3 self-grow whitelist + C4 structured + C5 leaf),
wire points, P0–P5 phasing.

## What P0 does (report-only widening of #4700)

`self/codegen.hexa`: beside the #4700 strict detector (`_arena_detect_loop_safe`
:2156), a WIDENED classifier `_arena_reclaim_loop_safe` + helper trio, gated on
the SAME env `HEXA_ARENA_DETECT` (FIRST `&&` operand at the `gen2_fn_decl` call
site). Emits NOTHING to codegen — eprintln fire-rate line only. The widened bar,
beyond #4700's immutable-container-literal transient:
- **W1 mut-grow cand** — admits `let mut x=[lit]` (strict admitted only `let x=[lit]`),
  grown IN-ITERATION by the reclaim-variant escape scan (`_arena_reclaim_stmt_escapes`):
  R1 `x = x.push(e)` / `x = [lit]` (self-reassign / fresh literal), R2 `x[i]=v`
  (index-write not an escape of x), R3 `x.push/append(e)` receiver + `x.len()`/`x[i]`
  reads local. return / global-store / outer-store / alias (`let s=x`) / call-arg /
  container-set / slice ALL stay ESCAPE (default-escape closure, FP=0 target).
- **C4 structured** (`_arena_reclaim_structured`) — no break/continue/return/defer/
  spawn in the body (break/continue inside a NESTED loop are that loop's, allowed).
- **C5 leaf** (`_arena_reclaim_stmts_leaf`) — no nested USER-fn call; nested LOOPS +
  retain-free builtins (len/print/println/to_string) + push/append/len methods OK.

The per-fn stderr line now reports strict + widened + the failure breakdown:
`[arena-detect] fn X: strict s/t widened w/t reclaim-safe [cand=C nonleaf=NL nonstruct=NS escape=E outerwrite=OW]`.
Failure tallies are independent (a loop can fail multiple gates) so P0 can measure
WHY cand-bearing loops miss the widened bar — the non-leaf count is the go/no-go.

## Byteeq-neutral (confirmed empirically, aiden)

Report-only: eprintln only, no `chunks.push`, env-gated. Emitted C byte-identical
flag-ON vs flag-OFF — `cmp` IDENTICAL on the widened positive-control repro
(3379 B) AND the whole flattened compiler `build/lx8664/cc-flat.hexa`
(**4,233,991 B**, same as #4700). Bit-changing gate does not apply.

## Soundness oracle (aiden, `HEXA_ARENA_DETECT=1`)

`.verdicts/d8-arena-pushleak/repros/` (5 d8 + 2 positive controls + 1 NEW adversarial):

| repro | strict | widened | verdict |
|---|---|---|---|
| loop_body_transient_safe (immutable pos ctrl) | 1/1 | 1/1 | ✓ fires |
| **loop_body_mut_transient_safe** (NEW widened pos ctrl) | 0/3 | **1/3** | ✓ **widening fires on the mut-grow shape strict excludes** |
| escape_return `make_arr` (return escape) | 0/1 | **0/1** | ✓ REJECTED |
| global_store_escape `stash` | 0/1 | 0/1 | ✓ (no body-local cand; G=xs post-loop) |
| global_arena_slice_escape `stash` | — | — | ✓ (no loop cand; slice→global) |
| **aba_snapshot_escape** `churn_alias` (NEW adversarial ABA/alias) | 0/2 | **0/2 escape=1** | ✓ REJECTED — `let s=t`→`G=s` alias caught |
| mem_transient `build_transient` | 0/2 | 0/2 | xs declared OUTSIDE loop → not a body-local cand |

Note on `churn` (present in all 3 escaping repros): widened **1/2** (strict 0/2).
This is CORRECT precise widening, NOT a false-safe — churn's `let mut t=[]` is a
genuinely non-escaping body-local transient (grown by push, read via `t[49]`, dies
at iteration end). The ESCAPING binding in those repros is `xs`/slice in
`make_arr`/`stash`, which is correctly rejected. The soundness invariant (the
escaping binding is NEVER flagged reclaim-safe) HOLDS on every case; the new
adversarial ABA repro actively fences the alias channel.

## ★ Corpus fire-rate (whole flattened compiler, cc-flat.hexa)

914 loops / 560 loop-bearing fns:
- **strict safe: 1** (= #4700's 1/914 exactly — widening preserved the strict count)
- **widened safe: 2** (2/914 ≈ 0.22%; +1 = `_nvptx_unroll_contains_inner_loop`)
- cand loops: 36 · fail **nonleaf 24** · escape 32 · nonstruct 0 · outerwrite 13

## ★★ THE DECISION MEASUREMENT — real churn corpus (decode + QFORGE)

`self/ml/*decode*` + `batch_inference` + `continuous_batching` + `stdlib/qforge/*` +
`stdlib/cloud/qforge*` — **1755 loops / 597 loop-bearing fns**:
- **widened safe: 1** — `_phased_vnl` ONLY (an incidental helper, NOT a churn hot loop)
- cand loops: 96 · **fail nonleaf 77 (80%)** · escape 87 · nonstruct 0 · outerwrite 23
- EVERY real hot loop is non-leaf AND escaping:
  `qforge_assemble_h_multi` 0/10, `qforge_elph_g2` 0/17, `dv_run` 0/13,
  `infer_batch_shared_prefix` 0/4, `qforge_dvnl_du_block` 0/8, `jacobi_step` 0/3,
  `fc_scf_response` 0/12 … all `nonleaf>=1 escape>=1`.
- **CONCRETE decode loop** (`batch_inference.hexa:485`, the shared-prefill decode):
  body calls `load_embedding(model,tok)` + `transformer_forward(model,emb,pos,…)` —
  both USER fns (non-leaf) — and `sys_kv_keys = result[1]` reassigns an OUTER
  accumulator (escape). The 22.7GB-class churn lives INSIDE `transformer_forward`
  (the GEMM/attention kernels), *behind* the call — rung-1 (leaf-only) cannot see it.
- 2 files (`davidson_block_e2e_bench`, `sternheimer_block_e2e_bench`) SEGV in the
  seed transpiler; confirmed **detector-independent** (SEGV with the flag OFF too) —
  pre-existing, excluded from the tally.

The named bytegpt-decode 22.7GB entry point (`_bg_rd_farr_at`, per MEMORY) is a
runtime-emitter symbol; the decode DRIVER lives outside this repo (anima). The
in-repo decode + QFORGE corpus is the best-available real alloc-heavy target and
its verdict is unambiguous.

## GO / NO-GO = **PIVOT-TO-RUNG2-CALLEE-SUMMARIES**

Rung-1 EMIT (leaf+structured only) fires on **1 incidental helper across 1755 real
churn loops** and delivers **NO measurable memory win on the real target** — the
reclaimable churn is behind USER-fn calls (`transformer_forward`, qforge kernel
assembly) that rung-1 rejects as non-leaf (77/96 cand loops), and the surviving
transients mostly escape (87/96). This EMPIRICALLY confirms the design's prediction.

**Do NOT build the rung-1 EMIT** (P1). It is mechanically sound and would ship
byteeq-neutral default-OFF, but it reclaims only synthetic fn-local shapes. Jump to
**rung-2: bottom-up callee no-escape summaries** (design P5) — the only lever that
unlocks the real decode/qforge churn (reclaim across/inside `transformer_forward`).
Each new non-escape summary rule needs its own escaping counter-repro (FP=0) before
any default-ON flip.

## Build/measure recipe (aiden)

```
# ~/hexa-arenadetect has the #4700 build seeds (build/hexat, build/runtime.a)
W=~/arenap0_work
HEXA_V2=build/hexat OUT=$W/mine_cc.c sh tool/regen_cc_manual        # regen w/ widened codegen.hexa
clang -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -fbracket-depth=4096 -nostartfiles \
      -I self -I . $W/mine_cc.c build/runtime.a -o $W/hexat_mine -lm -ldl
HEXA_ARENA_DETECT=1 $W/hexat_mine <src.hexa> $W/out.c 2>&1 | grep arena-detect
```
```
