# mem-lane ② tier-2 — loop-body region-no-escape RECLAIM DETECTOR (report-only)

**Status:** ✅ landed as a REPORT-ONLY characterization + soundness-oracle rung.
NO emit, NO codegen change, byteeq-neutral by construction. The reclaim EMIT
(sub-arena rewind at iteration end) is the **deferred, soundness-critical large
campaign** — this rung is its safe predecessor (the analogue of #4697's
stack-alloc escape scan WITHOUT any alloca/arena mutation).

Branch `feat/mem-loop-arena-reclaim-detector` (off origin/main @ #4698, includes
#4697). Built + measured on **aiden** (x86_64-linux).

## Why (the memory ceiling after stack-alloc #4697)

Arena reclamation is the real memory ceiling. Measured (`.verdicts/d8-arena-pushleak`):
- push-array hot loops leak **~32 KB/iter** (per-grow realloc buffers, `hxlcl_free`
  is a no-op bump allocator) — peak RSS scales LINEARLY (20k→1.28 GB, 100k→6.4 GB).
- a d8 combo (libc-routed alloc + free-on-scope-pop) FLATTENS to 3.8 MB —
  **~849× headroom** (3.2 GB→3.8 MB) IF a loop body could rewind its arena at
  iteration end.
- BUT free-on-scope-pop **CORRUPTS** escapes: global-store escape prints empty,
  arena-slice global escape SEGVs (exit 139). An unsound rewind frees a still-live
  escaping value = use-after-free miscompile. So the reclaim EMIT is soundness-
  critical and deferred; the FIRST rung is this detector.

## The scan rule (conservative, sound; mirrors #4697)

In `self/codegen.hexa` `gen2_fn_decl` pre-scan, beside `_stack_noescape_scan`
(#4697) / `_native_arr_noescape_scan`. Driver `_gen2_arena_detect_scan` →
`_arena_detect_walk` (finds every While/For/Loop) → `_arena_detect_loop_safe`.
Gated behind env `HEXA_ARENA_DETECT` (FIRST `&&` operand at the call site) —
stderr-only fire-rate line, never `chunks.push`.

A loop body is a **reclaim-safe candidate** ONLY IF:
1. it declares ≥1 body-local **immutable `let`** whose initializer is a fresh
   **container literal** (Array/Tuple/TupleLit/MapLit) — the reclaim-beneficial
   transient. `let mut` is EXCLUDED (a later reassignment voids the proof;
   reassignment = escape) → **mutable push-GROWN transients (the d8 churn 849×
   shape) are NOT counted by this rung** — they need the refined
   in-iteration-reassignment-vs-cross-iteration-liveness analysis that is the
   deferred reclaim EMIT's job.
2. EVERY such binding is proven non-escaping over the whole loop body via the
   SOUND **array-descriptor** escape scan `_stmt_escapes_arr_name` /
   `_stmts_escape_arr_name` / `_expr_escapes_arr_name` (the array sibling of the
   stack-alloc value scan, with the same **#4690** node.args + **#4693**
   TryCatch/RecoverStmt soundness fixes). Correct lifetime model for ARRAY
   reclaim: `a[i]` index-READ + `len(a)` are in-iteration LOCAL uses;
   reassignment / index-WRITE / return / call-arg / global-store / container-set /
   bare-operand ALL = escape. (The value scan `_stmt_escapes_name` treats `a[i]`
   as escape — right for structs whose only local use is `p.field`, wrong for
   arrays read by index — so reclaim uses the array scan.)
3. NO assignment in the loop body writes an allocating RHS to a name declared
   OUTSIDE the loop body (`_arena_detect_outer_heapwrite_list`) — cross-iteration
   container liveness (e.g. `xs = xs.push()` grow-across-iterations). Scalar
   reassignments to outer names (counters/accumulators, paired with unbox) are OK.

## d8 5-case + positive-control oracle (aiden, `HEXA_ARENA_DETECT=1`)

`.verdicts/d8-arena-pushleak/run_detector_oracle.sh` over `repros/`:

| repro | verdict | note |
|---|---|---|
| escape_return | make_arr 0/1 · churn 0/2 · main 0/2 | return-escape NOT flagged ✓ |
| **global_store_escape** | stash 0/1 · churn 0/2 · main 0/2 | **combo-corruption case → ESCAPING (REJECTED) ✓** |
| **global_arena_slice_escape** | churn 0/2 · main 0/1 | **combo-corruption case → ESCAPING (REJECTED) ✓** |
| mem_transient | build_transient 0/2 · main 0/1 | mutable push-grown → conservative 0 |
| param_grow_escape | main 0/2 | return-escape NOT flagged ✓ |
| **loop_body_transient_safe** (positive control) | main **1/1** | **read-only literal transient → reclaim-safe (DISCRIMINATION) ✓** |

**Soundness verdict: PASS.** Both combo-corruption cases classified ESCAPING (0
reclaim-safe loops); the escaping binding is never flagged safe. Positive control
fires (1/1) → the detector is not vacuously rejecting. Synthetic cross-check:
`f` (container literal + `.push`/`.join` receiver) = 0/1 (receiver escape caught),
`g` (read-only index reads) = 1/1.

## Corpus fire-rate

`hexat_mine` (regen hexa_cc.c from this branch's codegen.hexa + runtime.a) over the
flattened whole compiler `build/lx8664/cc-flat.hexa` (64,474 lines):
- loop-bearing fns: **560** · total loops: **914** · reclaim-safe: **1**
  (`compiler/discover/tombstone.hexa _extract_l_block_from_file`, 1/2).
- `self/codegen.hexa` standalone: 199 loops, **0** reclaim-safe.

**Fire-rate ≈ 1/914 (~0.1%).** Honest finding: under the strict-but-sound bar
(immutable container-literal transient, read-only within the iteration, no
cross-iteration/escape), almost no shipping loop qualifies. The bulk of
reclaimable memory (the d8 churn 849× win) lives in **mutable push-grown**
transients, which this conservative rung deliberately excludes — those are the
deferred reclaim EMIT campaign's target.

## Byteeq-neutral (confirmed empirically)

Report-only: eprintln fire-rate line only, no `chunks.push`, env-gated. Emitted C
is byte-identical flag-OFF vs flag-ON — verified: positive-control emit
(3281 B, `cmp` identical) AND the whole-compiler emit (4,233,991 B, `cmp`
identical). Changes NO codegen output → `.text` byte-identical. The bit-changing
gate does not apply (nothing is bit-changing); regular-CI byteeq stays GREEN.

## Deferred: the reclaim EMIT (soundness-critical large campaign)

The next rung inserts `__HEXA_ARENA_PUSH__`/`__POP__` around a reclaim-safe loop
body to rewind the arena at iteration end. It is soundness-critical (unsound
rewind = use-after-free) and needs: (a) a refined analysis admitting
mutable-but-iteration-local transients (in-iteration reassignment ≠ escape) to
capture the churn 849× shape, (b) escape barriers at every non-return store per
the d8 FINDINGS, (c) byteeq 3-target gen3≡gen4 + shipping smoke behind an opt-in
toggle. Literature: **Tofte–Talpin region inference** (region-polymorphic arena
stack, deallocate-at-region-exit), **Go escape analysis** (stack vs heap by proven
escape), **Rust drop-at-scope** (RAII ownership-scoped deallocation). The loop
body = the innermost reclaimable region scope.

## Build/measure recipe (aiden)

```
# worktree of the branch; restore seeds; build/hexat + build/runtime.a present
HEXA_V2=build/hexat OUT=$W/mine_cc.c sh tool/regen_cc_manual          # regen with this codegen.hexa
gcc -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -nostartfiles \
    -I self -I . $W/mine_cc.c build/runtime.a -o $W/hexat_mine -lm -ldl  # -nostartfiles: runtime.a own _start (#29)
HEXA_ARENA_DETECT=1 $W/hexat_mine <src.hexa> $W/out.c 2>&1 | grep arena-detect
```
(`_gen2_arena_detect_scan` runs from `codegen_full`→`gen2_fn_decl`; the native
`compiler/main.hexa` pipeline `cc_native` does NOT use `self/codegen.hexa`, so the
self-host C-transpiler is the vehicle.)
