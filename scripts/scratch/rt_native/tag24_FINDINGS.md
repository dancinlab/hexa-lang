# tag24 dispatch-runtime UAF - Lane B findings (rebuilt 2026-06-17, post-/tmp-wipe)

## Symptom
hexa run CORE/engine_cli_smoke.hexa (anima) aborts after case_10, in the
working-memory case-11 setup (first wm_buffer_gate_in -> _cos), with:
  cannot multiply non-numeric operand (tag 24 * tag 24)   RC=1

## Classification (decisive)
- TAG enum max = 11 (INT0..VALSTRUCT10, ENUM11). tag 24 = INVALID GARBAGE
  -> use-after-free / dangling handle, NOT a mistag, NOT a drop-to-0.
- A drop-to-0 would be TAG_INT(0) -> hexa_mul ACCEPTS it (never throws). The throw
  fires only for a non-INT/non-FLOAT operand. So the operand is genuinely garbage.
- DISTINCT from Lane A: Lane A arena-off does NOT fix Lane A (i64-array accessor
  mis-tag -> 0); arena-off (HEXA_STR_ARENA=0) also does NOT fix this. Separate fixes.

## The crashing C (smoke emit)
  _cos: hexa_mul(hexa_index_get(a,i), hexa_index_get(b,i))   a = keys[i]
  wm_buffer_gate_in (under __hexa_fn_arena_enter):
    keys = hexa_add(keys, hexa_array_push(hexa_array_new(), tok));  nested grow
    return __hexa_fn_arena_return(WorkMemBuffer(keys, act, ...));    map-struct ctor
  Instrumented hexa_array_get (tag>11 trace) did NOT fire -> corrupt value is not
  produced by array_get return; the dangling element predates the read.

## Active runtime path
  runtime.a has NO rt_mul T-symbol -> HEXA_HAS_HEXA_RT_STDLIB undefined ->
  ACTIVE hexa_mul is the #else C body (self/runtime_core.c ~L7710; SSOT
  self/runtime_core_emit.hexa). Patch target = fn-arena heapify in the EMITTER.

## Toolchain (NOT ~/.hx/bin/hexa.real)
  wrapper ~/.local/bin/hexa -> exec ~/.local/bin/hexa.edgebin,
  exports HEXA_PREBUILT_RUNTIME=~/core/hexa-lang/build/runtime.a (prebuilt 6/2).

## FRESH-BUILD stdlib resolution - SOLVED
  Fresh build FATALs on stdlib/consciousness/iit4_bounded.hexa unless HEXA_LANG
  points at a tree with stdlib/. WORKING: HEXA_LANG=$HOME/.hx/src (verified imp_ok).
  Recipe:
    HEXA_LANG=$HOME/.hx/src HEXA_PREBUILT_RUNTIME=$HOME/rt_instr/build/runtime.a \
    HEXA_TAG24_TRACE=1 hexa run CORE/engine_cli_smoke.hexa

## Isolated instrumented runtime (re-runnable, NON-/tmp)
  scripts/scratch/rt_native/build_instrumented_rt.sh -> ~/rt_instr/build/runtime.a
  Shared tree UNTOUCHED (self/runtime_core.c pristine 8082L, 0 TAG24).

## STATE (honest)
  a) backtrace: NOT yet captured (env+SSH churn; capture run in flight).
  b) heapify patch: NOT yet written/applied.
  c) smoke RC: no VALID fresh result yet. One case_109/TAG24-MUL=0 reading was a
     STALE CACHED binary - explicitly NOT counted as a pass (c9).

## Proposed patch (when backtrace confirms site)
  self/runtime_core_emit.hexa: make hexa_val_heapify / __hexa_fn_arena_return
  RECURSIVELY deep-heapify nested array/map/string elements on fn-return.
  Then regen runtime_core.c -> rebuild runtime.a -> repoint edgebin -> retest
  smoke RC=0 + brain_smoke RC=0.

## Courtesy note for Lane A sibling PR (do NOT fix here)
  i64-array accessor: hexa_arr_i64 read path in self/runtime_core_emit.hexa
  (search hexa_arr_i64 / arr_i64). Will pin exact line when editing heapify nearby.


## UPDATE r4 reconciliation 2026-06-17 [aiden flaky, PARKED]
PROVENANCE: the 152-PASS run is FRESH [cold ~/.hexa-cache] + MY instrumented
runtime.a built from CURRENT ~/core/hexa-lang source [build_instrumented_rt.sh].
Same edgebin compiler everywhere; only the linked runtime.a varied.

FORK = a, PROVEN by the contrastive A/B:
- B [current-source runtime.a]: FRESH build, sails through case_11 AND case_16
  [the exact tag24 crash points] with TAG24-MUL trace NEVER firing. tag24=0.
- A [default 6/2 prebuilt build/runtime.a]: FRESH build FAILS TO LINK ->
  undefined reference to forge_dispatch_groupnorm_gelu [A_RC=1]. The prebuilt
  6/2 runtime.a is STALE: missing symbols the current edgebin emits calls for;
  cannot even build the current smoke. The ORIGINAL tag24 reproductions were the
  WARM-CACHE binary built long ago against that stale runtime.

DELIVERABLE [no new patch needed for tag24]: REBUILD/SHIP runtime.a from current
source [tool/stage_resolve_runtime_a -> build/runtime.a, or build_instrumented_rt.sh
minus instrumentation]. tag24 UAF already fixed in current runtime source; the
shipped/prebuilt 6/2 runtime.a is the stale artifact. Heapify source patch NOT required.

REMAINING OPEN [needs a STABLE host]:
- B does NOT reach RC=0: stops at case_131 [compose_oracle_ceiling] with NO error /
  NO summary / NO RC; process simply gone. Cause undetermined: host OOM/kill under
  aiden churn OR a genuine post-tag24 wall. Smoke = 165 cases through case_159;
  RC=0 needs L1970 summary + n_fail=0. SEPARATE from tag24.

STATE: PARKED. tag24 root-cause + fix-path are clean handoff-ready. End-to-end
RC=0 blocked by host instability + the open case_131 question.
