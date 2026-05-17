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
- #18 aprime_cc self-host (hexa_v2 의존 끊기)
- ~170 unmapped runtime builtins (per-symbol triage)
- 60-smoke 재측정 (activated binary lift 확인 — auto-invoke + fn-dedup + lvalue + nil 누계)
- 통계적-statement-level DWARF `.loc` (Stmt/LInstr line threading — #13 follow-up)

## 진행 로그

(append-only)

### 2026-05-17 — 배포: main→rfc043 머지 + interp 바이너리 refresh (wilson P0#2 deployment)
Wilson 다운스트림 배포 요청 2건 처리.

**Action 1 — `origin/main` → `rfc043-hexa-torch` 머지** (commit `170d64d7`):
interp-retirement cycle 21 commits (d179f4a1 → 1ce840ec) 를 active flame/forge 브랜치에 들임. 충돌 해소: runtime.h union (rfc043 `hexa_chr_byte` + main R5 sweep), hexa_cc.c/hexa_v2 generated artifact → 머지 후 재생성. codegen_c2.hexa/hexa_full.hexa/AGENTS.tape auto-merge clean. 머지 후 hexa_v2 1,491,008 B 재생성 (empty-{} 등 cycle fix 전부 active).

**Action 2 — 배포 interp 바이너리 refresh**:
`~/.hx/packages/hexa/build/hexa_interp.real` May 14 stale (chr 8-byte codepoint) → origin/main build 로 교체 (3,170,304 B, codesigned). 검증: `hexa run` 으로 `ord(chr(240))` = 240, `len(chr(159))` = 1 (byte-level). 이전 바이너리 `.bak-may14` 백업.

**⚠️ Caveat — merged-rfc043 interp 빌드 차단 (forge-domain)**:
머지된 rfc043 트리에서 interp 직접 빌드 시 10개 RFC 040 GPU builtin 에서 실패 — `hexa_call0(hexa_cuda_available)` 등이 fn-pointer carrier 를 기대하지만 hexa_cuda_available 등은 plain C function. hexa_v2 transpiler 의 direct-call 인식 갭 (rfc043 commit 54d56e4a 가 GPU interp dispatch 를 wire 했으나 interp 재빌드 미검증). **forge-domain 별도 작업** — 배포 interp 는 origin/main 빌드로 대체 (chr+atlas fix 포함, RFC 040 GPU interp dispatch 미포함 — GPU 는 어차피 Mac 불가).

**다운스트림 후속**: wilson 측에서 배포 완료 신호 수신 후 PATCHES.yaml chr 엔트리 `partial`→`applied` flip + chr-prefix split 코멘트 정리.

### 2026-05-17 — #13 DWARF `.loc` — aprime_cc 소스 매핑 directive emit (`76c12a45`)
aprime_cc-direct codegen 이 DWARF `.file` + function-level `.loc` directive emit — lldb/gdb 가 machine code → .hexa source line 매핑 가능.

**구현** (function-granular line threading, 14 files):
- `compiler/ir/mir.hexa` MFunc + `compiler/ir/lir.hexa` LFunc 에 `def_line: i64` 필드 추가.
- `_lower_fn` 이 `HItem.span.line` 에서 MFunc.def_line 설정. 3 opt pass (inline/dce/const_fold) + 3 codegen backend (arm64/x86/thumb) 가 def_line pass-through.
- `compiler/emit/asm.hexa` — header 에 `.file 1 "<source>"`, `_emit_func` 가 fn label 뒤 `.loc 1 <def_line> 0` emit. `compiler/codegen/stream.hexa` streaming path 도 동일 `.file`.

**Validation** (재빌드 aprime_cc 2,050,376 B): `fn maybe()` line 1 / `fn main()` line 4 → asm `.loc 1 1 0` / `.loc 1 4 0`. `clang -g -c` → `dwarfdump --debug-line`: 유효 DWARF32 v5 line table (0x0→line 1, 0x18→line 4, end_sequence). asm 정상 assemble+run.

**Scope**: function-level (fn 당 1 `.loc`, 정의 line). statement-level `.loc` 는 Stmt/LInstr line 필드 threading 필요 — finer source-stepping 시 별도 follow-up.

### 2026-05-17 — #9 nil tier-1 codegen — aprime_cc `nil` → TAG_VOID (`14267c08`)
aprime_cc-direct (tier-1) 에서 `return nil` 이 TAG_INT 0 으로 emit 되던 문제 종결. `type_of(maybe())` 가 "int" 반환 (정상 "void").

**Root cause**: `nil` 은 bind list (compiler/check/bind.hexa:780) 에 known name 으로 등록되지만, HIR→MIR 의 `_lower_hexpr` ident 분기에서 `_mir_lookup`/`_mir_lookup_global` 둘 다 miss → `_emit_hx1101` (non-fatal) + `_no_value(ctx)` → `_const_int_op(0)` fallback.

**3-part fix** (commit `14267c08`):
1. `compiler/lower/hir_to_mir.hexa` — 새 `_const_void_op()` operand constructor (kind="const_void").
2. `compiler/lower/hir_to_mir.hexa` — `_lower_hexpr` ident 분기에서 `_mir_lookup` 전에 `e.text == "nil"` 감지 → `_const_void_op()` emit. hexa_v2 codegen_c2 fast-path (`self/codegen_c2.hexa:3262`) mirror.
3. `compiler/codegen/arm64_darwin.hexa` — `_hv_load` 에 `const_void` 분기 추가 (`movz lo,#4` TAG_VOID + `movz hi,#0`).

**Validation** (재빌드 aprime_cc 2,049,688 B): `fn maybe() { return nil }` → asm `movz x0, #4 ; hv const_void: TAG_VOID`, run `type_of` → "void". tier-2 hexa_v2 는 이미 정상이었음 — tier-1 갭만 종결.

### 2026-05-17 — wilson P0 #2 CLOSURE — interp binary rebuilds + chr-byte 활성화 (`ead812d9`)
이전 turn 의 P0 #2 잔여 (bit_or fn-pointer + farr_* static-inline 가시성) 종결. `build/hexa_interp.real` 3,170,304 B 로 재빌드 성공 (May 17). chr(240) 호출이 1-byte `0xF0` 산출 — 기존 2-byte UTF-8 codepoint `0xC3 0xB0` 잔여 행동 종결.

**4-part fix** (commit `ead812d9`):
1. **self/runtime.c** — 14개 helper `static [inline]` 자격 제거 (bit_or · farr_simplex_centroid/get/shrink/sort · farr_vec_reflect/blend · farr_vertex_copy · farr_simplex_set · farr_pauli_exp_inplace/expectation · ham_free · ansatz_free · farr_uccsd_apply · ham_pack · ansatz_pack · farr_parameter_shift_grad). 원래 file-scope 만 가능했던 helper 들이 user.c TU 에서 link 가능.
2. **self/runtime.h** — 14 wrapper + 10 hx_* TAG_FN carrier (hx_pipe_spawn / send_line / recv_line / close / alive · hx_exec_argv / argv_with_status · hx_sha256 · hx_setenv · hx_exec_capture) + 누락 hexa_farr_int_* / hexa_farr_pauli_expectation_batch 전체 forward-decl.
3. **self/hexa_full.hexa** — interp chr handler 가 `from_char_code(N)` → `bytes_to_str_raw([N & 0xFF])` 로 변경. rfc043-hexa-torch commit 53190b26 의 chr-byte 의미를 main 에 cherry-pick (5-file cherry-pick 충돌 → semantic 만 manual apply).
4. **tool/build_interp.hexa** — transpile 후 `#include "runtime.h"` → `#include "runtime.c"` sed step 추가. PHASE 1.2 분리(5780ef97, 2026-05-15)가 AOT compile-speed 위해 runtime.h 별도 도입했지만, interp 의 ~33 KLoC 가 cross-TU static-inline 사용. runtime.c inline 으로 단일 TU 내 모든 helper 가시.

**Validation**: 
- `echo 'println(chr(240))' | build/hexa_interp.real` → `f00a` (1 byte + LF) ✅
- interp build 성공 (clang `__hexa_fn_arena_*` 모든 helper resolve)

**다운스트림 영향**: wilson 의 plugins/guard-readme-format/test_*.hexa 가 `hexa run` 으로 다시 정상 (chr-prefix split-synthesis 우회 더 이상 불필요). atlas n6 absorption Phase 4-8 의 multi-line shard parser drift 도 동시 종결 (interp drift note 의 root cause).

**다음 step (downstream)**: wilson 측에서 rfc043-hexa-torch 에 main merge 후 inbox/PATCHES.yaml chr-byte-vs-codepoint-asymmetry status `partial` → `applied` flip.

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
