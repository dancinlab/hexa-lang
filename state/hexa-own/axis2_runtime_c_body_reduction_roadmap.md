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

**Remaining ship-wiring (byteeq-gated, pool — Fable Deliverable 3):**
1. `self/runtime_core_emit.hexa:4434` (contains_key `#if`): `HEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE` →
   `HEXA_RT_CORE_MAP_QUERY_CONTAINS_NATIVE` (so DISPATCH externs only the 8; contains_key stays inline).
2. `tool/build_aprime.sh:630`: `RTCORE_MAP_QUERY_DISPATCH_DEF` also sets `..._CONTAINS_NATIVE=1`.
3. `tool/stage_resolve_runtime_a` new `resolve_native_map_query_seed()` (mirror `resolve_native_map_core_seed`
   :418): B3-A0 own-obj first (`--emit=obj -o build/map_query_native.o`, nm-gate 8/8 `T hexa_map_*`, no
   --keep-global/--isolate needed = zero sibling globals) + `.s`-seed fallback; consumption
   `-DHEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE=1` + `extra_obj += build/map_query_native.o`. Default-OFF byte-neutral.
4. `_Static_assert(offsetof(HexaMapTable,len)==40)` layout tripwire near the struct.
Byteeq: guard-OFF 3-target bit-identical (merge gate) + guard-ON RUN-parity corpus (populated/empty/non-map/
void-pred/real-pred/closure) + 3-target GREEN before flip. Then Tier-1 #2 (valop eqtruthy) + #3 (array typed-leaf).

Full census/synthesis: Workflow journal `subagents/workflows/wf_aa30b431-930/journal.jsonl`;
Fable design `scratchpad/map_query_result.md`.
