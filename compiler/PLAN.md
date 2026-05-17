# compiler/PLAN.md — 컴파일 파이프라인 진행 로그 (SSOT)

> 본 파일은 hexa-lang **컴파일 관련** cycle 진행 로그의 단일 SSOT 다.
> 거버넌스 `@D g_plan_consolidation` (AGENTS.tape §3) 에 의해 모든
> 신규 cycle entry 는 본 `## 진행 로그` 섹션 append-only 로 land 한다.
> 별도 `PLAN-*.md` 신규 작성 금지 (문서분산 방지).
>
> **범위 (compile 관련 모두)**:
>   - `compiler/` (lexer · parser · check · codegen · lower · ir · atlas)
>   - `self/` (hexa_v2 부트스트랩 transpiler · runtime.c)
>   - `tools/` 빌드 스크립트 · 부트스트랩 재빌드
>   - test/ smoke sweep 측정
>   - aprime_cc-direct path (R3-R7)
>   - hexa-build / hexa-run-native 3-tier wrapper
>   - interp 폐기 작업 (R3-R7)
>
> **범위 밖 (별도 SSOT)**:
>   - `stdlib/flame/PLAN.md` — NN training stdlib
>   - `self/forge/PLAN.md` — GPU compute substrate (RFC 040/041/049)
>   - `inbox/rfc_drafts_*` — RFC drafts
>   - 기존 `PLAN-interp-retirement.md` · `PLAN-stage3-*.md` — closure 까지 유지, 신규 entry 만 본 파일로 redirect

## 0. 현재 상태 (2026-05-17)

**interp-retirement R3-R6 substantially LANDED** (PLAN-interp-retirement.md 가 1차 SSOT, 본 파일이 신규 cycle log SSOT).

- aprime_cc-direct path: 60-broad sweep **27/60 (45%)** byte-identical
- hexa-build path (tier-2, hexa_v2 → C → clang): **38/60 (63%)** baseline → 활성화 후 ~53-54/60 예상 (재측정 펜딩)
- 3-tier wrapper: `bin/hexa-run-native` 가 tier 1 aprime_cc / tier 2 hexa build / tier 3 interp (HEXA_APRIME_CC opt-in)
- 부트스트랩 hexa_v2 binary: **1,487,744 B** (H17 + fn-dedup + empty-{} + Field-rooted nested-index lvalue 활성화 완료)

**다음 진행 candidates**:
- #5 atlas SIGSEGV (≥17 nested-struct UB · runtime shallow-clone aliasing)
- #9 aprime_cc tier-1 `nil` → const_void codegen
- #13 aprime_cc DWARF `.loc` emission
- #18 aprime_cc self-host (hexa_v2 의존 끊기)
- ~170 unmapped runtime builtins (per-symbol triage)

## 진행 로그

(append-only)

### 2026-05-17 — wilson downstream P0+P1 triage (struct-field LHS confirmed + 12 interp-regen protos + PATCHES.yaml chr update)
Wilson agent (downstream consumer) flagged 3 items needing closure for plugin selftest unblock + atlas absorption Phase 4-8.

**P0 #1 — struct-field map LHS index-assign**: ✅ ALREADY FIXED in `4de4cd2f` (Field-rooted nested-index lvalue commit). Wilson repro pattern `h.scripted[target + "|" + op] = result` (FakeHost test_fixture.hexa:44-45) verified to PASS end-to-end against rebuilt hexa_v2 — transpile emits `h = hexa_map_set(h, "scripted", hexa_index_set(...))`, run produces `map / v1 / 42` (rc=0). Wilson + anima HEXAD both unblocked once user pulls main.

**P0 #2 — build/hexa_interp.real stale (May 14)**: partially advanced via `c9b5c12c`. Added 12 forward-decls (hexa_array_truncate, hexa_bin, hexa_hex, hexa_str_bytes, hexa_valstruct_new_v 12-arg, rt_write_bytes, hexa_ceil, hexa_floor, hexa_math_isnan/isinf/isfinite, hexa_str_parse_float) — these close the `call to undeclared function` cluster blocking the interp regen at clang. **Remaining 2 blockers**:
  - `bit_or` identifier used as fn-pointer (`hexa_call2(bit_or, x, y)` at hexa_full_regen.c:38470) — only `bit_or_pure` is exported, not `bit_or`. interp source uses `bit_or` directly as function reference.
  - `farr_*` helpers (`farr_pauli_exp_inplace`, `farr_vec_blend`, `farr_vertex_copy`, `farr_simplex_centroid` etc.) are `static inline` in runtime.c (line 7146+) — file-scope only, linker invisible across the runtime.o TU boundary. Either de-staticize OR switch build to `#include "runtime.c"` inline. Separate runtime.c cycle.

**P1 #3 — inbox/PATCHES.yaml chr entry**: ✅ updated on rfc043-hexa-torch (commit `f07a2f6b`). source_commit `pending` → `53190b26`. Note appended documenting which prototype gaps closed and which remain.

### 2026-05-17 — Field-rooted nested-index lvalue fix (`obj.field[i] = v`)
**Bug**: `_gen2_nested_index_assign_stmt` (self/codegen_c2.hexa:2187) 에서 Index spine root 가 Field 노드일 때 `root_c = expr` 를 그대로 emit → `hexa_map_get_ic(obj, "field", &ic) = hexa_index_set(...)` → C "expression is not assignable" (함수 반환값에 assign 불가).

**Repro**: `cs.clusters[i] = Cluster { ... }` (`compiler/atlas/symbolic/convergence_cluster.hexa:78`). FAIL_BUILD 으로 `convergence_cluster_smoke` + `calc_cli_smoke` 차단.

**Fix** (commit `4de4cd2f`): root 가 Field 노드일 때 plain Field-AssignStmt 분기 (line ~2279) 의 `obj = hexa_map_set(obj, "field", new_value)` 패턴 mirror. 4-line conditional branch.

**Validation** (재빌드 hexa_v2 1,487,744 B):
- `convergence_cluster_smoke`: PASS=15 / FAIL=0  `__CVC_SMOKE__ PASS` ✅
- `calc_cli_smoke`: PASS=35 / FAIL=0  `__CALC_CLI_SMOKE__ PASS` ✅

**60-sweep 진척**: 잔여 FAIL_BUILD/RUN 에서 2 추가 close (lvalue cluster 종결). 다음 재측정 시 ~55/60 예상.

### 2026-05-17 — interp-retirement cycle: hexa_v2 부트스트랩 활성화 + 13 commits (compiler/PLAN.md consolidation start)
사용자 directive 2026-05-17:
- "PLAN 은 \[compile 관련 폴더\]/PLAN.md 파일을 업데이트해나가면되"
- "AGENTS.tape 에도 기록해놔줘 문서분산 방지"
→ 본 entry 가 `compiler/PLAN.md` 단일 SSOT 진행 로그 시작점. governance rule `@D g_plan_consolidation` (AGENTS.tape §3) 동시 land. 별도 `PLAN-interp-retirement.md` 는 closure 까지 유지하되 신규 cycle log 는 본 위치로 redirect.

**Cycle deliverable** (main 13 commits, `d179f4a1` → `0f0940fd`):

| commit | scope | net effect |
|--------|-------|-----------|
| `d179f4a1` | parser empty `{}` | `let mut d = {}` 가 TAG_INT 0 대신 `hexa_map_new()` 로 lowering. `regress_dict_keys_let_bind` fn-main 4/4 PASS (aprime_cc-direct + hexa-build 양쪽) |
| `17de2f4b` | codegen_c2 fn-param shadow | `_known_int/float_set` 모듈전역 set 이 fn 파라미터로 shadow 됨. `binary_value(a:float, b:float, op:int)` 가 `hexa_int(HX_INT(a) + HX_INT(b))` 로 잘못 unbox 되던 버그 fix. SSOT only (binary 활성화는 40c64a9e). |
| `232b924d` | PLAN log | D / H / C-sweep 결과 PLAN-interp-retirement.md 에 기록 (legacy 위치) |
| `a8bf90d8` | test trio | `t_macro_depth_default/override/valid` trailing `main()` 제거 (auto-invoke conflict, Class 1 silent-failure audit) |
| `13b5741f` | test 6 추가 | `t_ffi_marshal_skeleton`, `t_parser_select_attr`, `t_select_dispatch_parse`, `t_typealias_occurs_check`, `t37_attr_pub_fn`, `t_range_precedence` 동일 패턴 청소 (5/6 PASS, t_range_precedence 는 별도 `hexa_range_array` symbol 갭) |
| `4e2869c6` | codegen_c2 fn-dedup primary | gen2_module 메인 loop 의 FnDecl/PureFnDecl/AsyncFnDecl first-wins dedup. `euler_phi` 중복 정의 클리어 (stdlib/core/math.hexa vs compiler/atlas/symbolic/congruence_chain_engine.hexa). SSOT only. |
| `0c9f0f04` | runtime.h fwd-decls 5 | `hexa_setenv`, `hexa_cstring`, `hexa_ptr_write`, `hexa_range_array`, `hexa_str_index_of_from` — clang ISO C99 strict "call to undeclared function" fix |
| `0febd20d` | runtime.h fwd-decls 8 추가 | `hexa_ptr_read`, `hexa_array_reverse/sort`, `hexa_exec_capture`, `hexa_from_cstring`, `hexa_to_float`, `hexa_utc_compact_now/iso_now`, `hexa_null_coal` |
| `40c64a9e` | hexa_v2 부트스트랩 재빌드 | `self/native/hexa_v2` 1,445,544 → 1,470,968 B. `hexa cc --regen` with `HEXA_LANG=/tmp/wt-h17`. H17 + empty-{} + primary fn-dedup 활성화. |
| `1de82e78` | fn-dedup secondary + `hexa_math_lgamma` | codegen_c2 mirror loop (line ~6883) 에도 first-wins dedup 적용 + 부트스트랩 재빌드 2회차. `atlas_tecsl_verify_smoke` PASS 확인. hexa_v2 1,470,968 → 1,487,616 B. |
| `0f0940fd` | PLAN bootstrap milestone | PLAN-interp-retirement.md 에 활성화 milestone 기록 |

**End-to-end 활성화 검증** (재빌드 hexa_v2 binary 기준):
- `perfect_number_engine_smoke`: 11/19 (interp 19/19 대비 8개 DIFF) → **19/19 PASS** ✅ H17 활성화
- `atlas_tecsl_verify_smoke`: redefinition err → **__TECSL_SMOKE__ PASS** ✅ fn-dedup mirror loop
- `atlas_cycle_append_smoke`: redefinition err → **rc=0** ✅
- `regress_dict_keys_let_bind` (fn-main form): all 4 PASS ✅ empty-{}
- `bv_flat.hexa` synth helpers (float param after int let): `hexa_add`/`hexa_sub`/`hexa_mul` 정상 dispatch ✅

**60-smoke hexa-build sweep**: baseline 38/60 (63%) — auto-invoke 9 + fn-dedup 3-4 + fwd-decl 4 추가 활성화 후 53-54/60 (~90%) 예상 (sweep TaskStop, 다음 cycle 에서 재측정).

**Cross-track impact**: 부트스트랩 활성화는 모든 후속 `hexa build` 결과의 안정성 향상 — flame/forge 작업도 동일 binary 사용.

**잔여 (다음 cycle)**: #5 atlas SIGSEGV (≥17 nested-struct UB) · #9 aprime_cc tier-1 nil → const_void · #13 DWARF `.loc` · #18 aprime_cc self-host · 1 codegen lvalue (`calc_cli_smoke` "expression is not assignable").
