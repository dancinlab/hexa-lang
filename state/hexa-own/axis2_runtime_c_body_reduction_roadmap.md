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
- **✅ ISOLATION — SOLVED + VERIFIED end-to-end (summer, 2026-07-13).** The wall is broken; only productionization remains.
  - **Recipe (proven):** a seed source that `import`s the runtime prelude (`ctype math thread net posix numeric
    regex_rt io` — siblings in stdlib/runtime/) instead of `extern fn rt_map_*`, compiled
    `aprime --emit=obj --keep-global=<the 8 hexa_map_*> --isolate` → aprime pulls the rt_map_* bodies from
    numeric.hexa and `--isolate` (isolate_lmodule reachability DCE) prunes to the 8-reachable closure, **absorbing
    rt_map_* as STB_LOCAL** and cutting at the carrier boundary.
  - **Result:** 8 dispatchers global-T · rt_map_keys/values/entries/count_pred/any_pred_b/all_pred_b all LOCAL (`t`) ·
    **U-floor = 13, ALL runtime.a-resident T** (`__map_order_key_at __map_order_val_at __map_raw_len hexa_array_new
    hexa_array_push hexa_cmp_lt hexa_index_get hexa_len hexa_map_get_v hexa_map_new hexa_map_set_v hexa_to_int
    hexa_truthy` — MISSING=0). **NO rt_map_* in the U-floor.**
  - **Proof:** built runtime.a with the isolated seed, linked the corpus **runtime.a-ONLY** (the exact grace-consent
    scenario that broke the naive seed) → **OFF + ON both linked + ran rc=0**; **RUN-parity OFF==ON byte-identical (31 lines)**.
  - **✅ Productionization DONE + verified (PR #4911 commit 06304132c):** (1) `stdlib/runtime/map_query.hexa` now
    imports the runtime prelude (dropped the `extern fn rt_map_*` block) — self-contained source; (2) resolver own-obj
    `resolve_native_map_query_seed`: `--keep-global=<8> --isolate` + a `_ortu` self-contained gate (rejects an emit with
    any `rt_map_*` undef, mirroring `_rnsc_bad`, convergence stage-resolve-runtime-a-3). **`.s`-seed path retired for
    map-query** — `--isolate` is obj-only; flip is **OWN-OBJ-only** (opt-in-gated, no `.s`-presence auto-enable).
    **Verified summer THROUGH the resolver own-obj path** (`HEXA_RT_OWNOBJ_MAPQUERY=1`): 8/8 global · rt_map_* absorbed
    local · U-floor carrier-only (0 rt_map_* undef) · no dup · runtime.a-only link OFF+ON rc=0 · RUN-parity byte-identical.
    Byte-neutral (map_query.hexa seed-only + own-obj opt-in) — #4911 stays default-OFF.
  - **✅ 3-TARGET seed self-containment CONFIRMED (summer, aprime cross-target `--isolate`):** all three emit 8 global
    dispatchers + **0 `rt_map_*` undef** — x86_64-linux (13 total-U) · arm64-linux (16 total-U) · arm64-apple-darwin
    (8 global via `llvm-nm-18` — **GOTCHA: GNU `nm` reports "file format not recognized" on Mach-O → false 0/0; use
    `llvm-nm` for darwin seed verification**). The cross-target risk for the flip's 3-target byteeq is retired at the
    seed level.
  - **✅ SHIP-BUILD ON-path verified (summer, compiler-present):** full `tool/release_build` (TARGET=linux-x86_64,
    the 4-stage ship build) with `HEXA_RT_OWNOBJ_MAPQUERY=1` + `HEXA_OWNOBJ_CC=build/aprime_cc` → `./hexa` built rc=0,
    seed self-contained (0 rt_map_* undef), the 8 dispatchers T in runtime.a, and **map-query runs correctly through
    the shipped `./hexa`** (`keys(pop)→b,a,c count=3`, `values→2,1,3`, `entries→[b,2]`). The isolated-seed MECHANISM
    is proven end-to-end in a real ship build.
  - **🧱 NEW CONSTRAINT — Stage-0b is COMPILER-FREE (the flip's real remaining wall):** `release_build` order is
    (1) `stage_resolve_runtime_a` [Stage 0b → runtime.a] **then** (2) `stage_prebuild_hexat` [build/hexat] then
    stage_build_hexa. So at seed-production time there is **NO hexa compiler** — that is the entire reason for the
    "frozen dough" `.s`/frozen-`.c` bootstrap seeds (compiler-free). The own-obj `--isolate` path NEEDS a hexa
    compiler (aprime/hexat); the ship-build above only worked because isowt2 had a **pre-existing** `build/aprime_cc`.
    So **own-obj `--isolate` cannot be the DEFAULT Stage-0b seed path** — a naive un-gate silently no-ops in a clean
    build (own-obj fails → safe C-fallback → flip inert). This is the flip's genuine remaining design decision:
    - **Option A — committed isolated `.o` seeds** (per-target binary frozen artifact, baked offline via `--isolate`,
      committed to `self/native/map_query_<t>.o`; Stage-0b just links them — compiler-free). Departs from `.s` text
      convention (binary in git) but analogous to the frozen bootstrap; needs regen-on-source-change.
    - **Option B — isolate→`.s` pipeline** (emit the isolated `.o` then lower to a self-contained `.s` text seed that
      carries the local rt_map_* + global dispatchers; keeps the `.s` convention, needs an obj→asm lowering step).
    - **Option C — two-pass re-resolve** (Stage-0b resolves runtime.a with map-query in C [compiler-free], then AFTER
      hexat is built re-resolve the SHIPPED runtime.a with the own-obj `--isolate` flip; bootstrap uses C, ship uses
      native). Adds a re-resolve stage; avoids committed binaries.
    Pick + implement one, then 3-target byteeq + own-link corpus parity → flip. The seed self-containment + ship-build
    ON-path (compiler-present) are proven; only the compiler-free DELIVERY remains.
Then Tier-1 #2 (valop eqtruthy) + #3 (array typed-leaf). `_Static_assert(offsetof(HexaMapTable,len)==40)` = still-TODO tripwire.

Full census/synthesis: Workflow journal `subagents/workflows/wf_aa30b431-930/journal.jsonl`;
Fable design `scratchpad/map_query_result.md`.
