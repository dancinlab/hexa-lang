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

## Resume — next concrete step
Author `stdlib/runtime/map_query.hexa` (9 dispatchers per the resolved shape above), once the cascade
merges land (#4907 ships the isolation aprime). Full census/synthesis in the Workflow journal
`subagents/workflows/wf_aa30b431-930/journal.jsonl`.
