# axis-② runtime.c-body reduction roadmap — ②-terminal (runtime.c→0) decomposition

★ SSOT for the ②-terminal (the multi-session mass beyond A0/A1). Produced by Workflow `wl0ajr8se`
(4-family parallel census of the actual emitters + synthesis, 2026-07-13). A0 (10 seed families) + A1
(24 members) are already own-obj wired + ship-verified — this is the **runtime.c BODY** beyond them.

## The shape (measured, not stale docs)

The runtime.c body emitters are **C-TEXT CARRIERS** (`buf = buf + "...c-source..."`), NOT own-emit:
`self/runtime_core_emit.hexa` (11,310 lines · 657 C fn-sigs · 355 hexa_* syms · 1131 HexaVal touches) +
`self/runtime_emit_full.hexa` (16,836 lines, canonical runtime.c). The HexaVal 16B `{tag; union payload}`
ABI (SSOT `self/runtime_hexaval_abi.h`) + the C `#else` no-seed fallback + syscall-emit leaves = the
**hard floor**. ~92 on-path HexaVal fns are still C-text carrier (no stdlib/runtime .hexa source).

**syscall family: @asm-svc front is EXHAUSTED** on x86_64-linux — every wrapper is raw-svc (direct
`syscall` insn via `_hxlcl_lx_sc0..5`), 0 remaining libc syscall calls (darwin else-legs are sanctioned).

## #1 NON-BLOCKED unit — RESOLVED (map-query dispatch cluster)

**Author `stdlib/runtime/map_query.hexa` = 9 thin NULL-guard dispatchers over already-native bodies.**
The census contradiction (Family-1 "author full logic" vs Family-4 "already seeded") is resolved by
reading the actual carrier: `hexa_map_keys/values/entries/contains_key/map_values/filter_keys/count/
any/all` are **thin C dispatchers that only NULL-table-guard then delegate to the rt_map_* hexa-source
bodies** — `rt_map_keys/values/entries/contains_key_b/map_values/filter_keys/count_pred/any_pred_b/
all_pred_b`, **all 9 VERIFIED present in `stdlib/runtime/numeric.hexa:993-1437`**. So the logic is already
native; only the thin dispatchers are C-carrier.

- **Guards pre-scaffolded**: `HEXA_RT_CORE_MAP_QUERY_{FOLD,DISPATCH}_NATIVE` (14 refs in runtime_core_emit.hexa).
- **Carrier**: `self/native/rtcore_map-query-dispatch_emit.hexa` (14 fns) + `rtcore_map-query-fold_emit.hexa`.
- **Port shape**: author the dispatchers in `stdlib/runtime/map_query.hexa` (NULL-guard + delegate to the
  rt_map_* body, using the map_core.hexa `__hx_payload_add`/`__hx_ptr_load64` idiom) → `aprime_cc
  --emit=asm` → `self/native/map_query_{x86_64,arm64,arm64-linux}.s` seed → flip the pre-scaffolded
  guards to extern-away + link the seed.
- **Byteeq-safe verify**: (a) guard-OFF bit-identical to baseline; (b) guard-ON per-fn RUN-parity vs the
  C body over a fuzzed HexaMap corpus; (c) byteeq 3-target GREEN + smoke; merge default-OFF, flip ON on 3/3.
- **PREREQ**: regen the seed with an E4-merged aprime (E4 in main now; isolation ships on #4907) so
  --keep-global/--isolate available if the dispatchers need contract-scoping.

## Ranked reduction sequence (Workflow synthesis)

- **Tier 0 (zero-authoring flag-flip)**: gated on the A0 `:-0`→`:-auto` flip — retire A0-twin S2 `#else`
  C arms (VALOP_DISPATCH↔valop_core, ARRAY_TYPED_LEAF↔array_core, MAP_QUERY_*↔map_core, MATH↔math.hexa).
  Collapses ~4 of 19 S2 clusters.
- **Tier 1 (pure-HexaVal read/compute, no floor, template-proven)**:
  1. map-query dispatch (~9-16) — **the #1 unit above**
  2. eqtruthy + valop scalar-coercion arms (`hexa_eq/ne/truthy`, `to_int/to_float/abs/null_coal` scalar)
     — register-only; extend `stdlib/runtime/valop_core.hexa` + `tool/regen_valop_core_native_s.sh`,
     retire `rtcore_eqtruthy_emit.hexa`, fold into `HEXA_RT_VALOP_NATIVE`
  3. array-typed-leaf push (`hexa_arr_i64_push/f64_push`) — arena-alloc via `array_core.hexa`
     `rt_array_arena_alloc_desc_native`; flip `HEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE`
- **Tier 2 (syscall own-.s leaves, no own-obj emitter yet)**: `hxlcl_clock_gettime/pipe/fork/setpgid/
  setsid/open_sys/flock` — raw-svc-C leaves; own-.s port mirrors `test/native_build/emit_hxlcl_close_o.hexa`.
- **Tier 3+ (the mass, multi-session)**: collection-mutate (25) · runtime-misc (19) · the HexaVal m3
  all-or-nothing TU-drop (runtime_core.c → runtime.c → shim + sysheaders delete = ② literal DONE).

## Hard floor (named, not laundered)
HexaVal 16B ABI + HexaTag enum + HX_* macros (binary type-ABI contract codegen bakes into every call;
own-emit must reproduce the pair-ABI — x86_64 Route C proven, arm64 fp-ABI a FALSIFIED wall) · the C
`#else` per-cluster fallback (dropped all-or-nothing at HEXA_ZEROC_DROP_RTCORE) · syscall-emit atoms ·
vendor tier E1-gated (`__hx_cabi_call`) · CUDA runtime_cuda.c (nvcc) · ffi_dyn if E1-frozen-unsafe.

## #1 unit — AUTHORED + emit-VERIFIED (2026-07-13, PR feat/axis2-runtimec-map-query)

`stdlib/runtime/map_query.hexa` authored (Fable byte-parity design) + summer emit-verified:
**8/8 `T hexa_map_*` globals** (keys/values/entries/map_values/filter_keys/count/any/all), U = only the
10 externs (8 rt_map_* delegates + hexa_array_new/hexa_map_new ctors), **ZERO libc UND**. Each body =
`HX_MAP_TBL` null-guard (`__hx_tag(m)!=6 || load64(payload,0)==0`) + delegate to the already-hexa-source
`rt_map_*` (numeric.hexa). Pair-model ABI = SysV for the HexaVal-uniform sigs → the emitted-runtime C
call sites link unchanged. `tool/regen_map_query_native_s.sh` authored (mirror valop + 8-globl assert +
U-floor check). **`hexa_map_contains_key` stays C-carrier** — its mixed `(HexaVal, const char*) -> int`
ABI fits neither pair-model nor Route C all-raw; the named next wall = a per-param C-ABI codegen annotation.

**Ship-wiring — DONE + verified (2026-07-13, PR #4911 commit 2a0d901a5):**
1. ✅ `self/runtime_core_emit.hexa:4434` contains_key `#if` split to `..._CONTAINS_NATIVE` (DISPATCH externs only the 8).
2. ✅ `tool/build_aprime.sh:630` `RTCORE_MAP_QUERY_DISPATCH_DEF` also sets `..._CONTAINS_NATIVE=1`.
3. ✅ `tool/stage_resolve_runtime_a` `resolve_native_map_query_seed()`: own-obj first + `.s`-seed fallback; consumption
   `$rt_mapq_def` on the runtime_core.o compile + `extra_obj += map_query_native.o`. Default-OFF byte-neutral.
4. `.s` seeds baked (3-target, x86_64 cross-assemble-verified 8/8 T) but **REVERTED, not committed** — see wall below.

**Two REAL bugs caught + fixed via ship-shape verification (the convergence-warned false-green class):**
- `.s`-seed assemble referenced `$_mo_archflag` (unbound outside the MULTIOBJ block → `set -u` abort). Dropped it
  to match every sibling seed-assemble (`$CC -c`).
- **single-TU multidef**: the single-TU amalgam (3995) + CUDA-host (4003) `#include` runtime_core.c WITHOUT
  `$rt_mapq_def` → with the flag ON they re-define the 8 → duplicate-symbol with the ar'd seed. Added `$rt_mapq_def`
  to both. MULTIOBJ S2/S3 were already correct (via `-DHEXA_ZEROC_DROP_RTCORE_INCLUDE`).
- **Verified summer, BOTH shapes** (single-TU + MULTIOBJ ship): each of the 8 `hexa_map_*` defined **exactly once**
  (seed only, dropped from runtime_core.c), contains_key stays inline (1 T), **NO dup / no multidef**.

**🧱 FLIP WALL — seed is NOT isolated (delegate-availability) + seed-presence auto-enables (2026-07-13, CI-measured):**
- **Committing the `.s` seeds is NOT byte-neutral.** `resolve_native_map_query_seed` treats seed-file PRESENCE as
  auto-enable (`[ "${HEXA_RT_MAP_QUERY_NATIVE:-x}" = "0" ]` → unset PROCEEDS → assembles seed → exports `=1`), same
  as every shipped family. So committing the seeds flipped the feature ON in every CI job (selfhost-codegen-guard,
  miscompile-zero, grace-consent all logged `HEXA_RT_MAP_QUERY_NATIVE=1; ar'ing map_query_native.o`).
- **And the flip is broken:** the seed's 8 `rt_map_*` delegates are program-side stdlib (`numeric.hexa`) symbols —
  `U` in runtime.a, **not `T`**. Any **runtime.a-ONLY link** (the grace-consent checker binary; any minimal consumer
  that isn't a full stdlib program) fails: `build/runtime.a(map_query_native.o): undefined reference to rt_map_keys`.
  The C bodies had the SAME `extern rt_map_*` refs, but in the C build those live in the big runtime_core.o TU whose
  own stdlib-carrier resolves them; the standalone seed .o has no such carrier. My earlier "U-floor clean (10 externs)"
  was WRONG to call ship-ready — those 10 externs BREAK the ship link, they don't pass it.
- **FIX (named next round):** the seed must be **isolated to zero non-libc undefined externals** — i.e. compile
  map_query.hexa **together with** its `rt_map_*` delegate bodies (numeric.hexa) into ONE self-contained seed .o,
  exactly as the shipped string/mem seeds were isolated via `tool/isolate_native_seed.py` (convergence
  `stage-resolve-runtime-a-3`: isolated seed = ZERO undefined externals, cross-target-clean). Then re-bake 3-target,
  gate on `nm seed.o | grep ' U ' == libc-carrier-only`, re-commit, verify byteeq 3-target + `own-link corpus parity`
  GREEN → flip. Until then the seeds stay OUT of tree (they auto-enable a broken flip).
- STRUCTURAL drop + no-multidef (both single-TU + MULTIOBJ shapes) remains PROVEN; that half is done. The wall is
  seed self-sufficiency, not the drop mechanism.
- **ISOLATION FEASIBILITY — SCOUTED (summer, runtime.a nm):** most transitive deps of the rt_map_* delegates are
  already `T` in runtime.a → an isolated seed (map_query.hexa + rt_map_* bodies compiled together) would resolve
  in a runtime.a-only link. Confirmed resident: `hexa_array_new`, `hexa_map_new`, `__map_order_key_at`,
  `__map_raw_len`, `__map_order_val_at`, `hexa_array_push`, `hexa_truthy`. **Tail to resolve** (T=0 in the scout,
  need residency or inclusion): `__map_val_at`, `rt_arr_push`, and the closure-invocation path `pred(…)` →
  `hexa_call_fn_*` (the count/any/all/filter/map_values predicate calls). So the isolation round = (1) combined-compile
  map_query.hexa + the numeric.hexa rt_map_* cluster into ONE seed .o, (2) `nm seed.o | grep ' U '` must be
  runtime.a-resident-only — iterate on any non-resident tail dep (likely fold the closure-invocation helper in too),
  (3) re-bake 3-target + re-add the auto-enable seeds, (4) byteeq 3-target + own-link corpus parity GREEN → flip.
Then Tier-1 #2 (valop eqtruthy) + #3 (array typed-leaf). `_Static_assert(offsetof(HexaMapTable,len)==40)` = still-TODO tripwire.

Full census/synthesis: Workflow journal `subagents/workflows/wf_aa30b431-930/journal.jsonl`;
Fable design `scratchpad/map_query_result.md`.
