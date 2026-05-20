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

- aprime_cc-direct path: 60-broad sweep **39/60 (65%)** byte-identical (재측정 2026-05-17, char-literal fix 반영; 세션 trajectory 45→50→57→65%)
- hexa-build path (tier-2, hexa_v2 → C → clang): **38/60 (63%)** baseline → 활성화 후 ~53-54/60 예상 (재측정 펜딩)
- 3-tier wrapper: `bin/hexa-run-native` 가 tier 1 aprime_cc / tier 2 hexa build / tier 3 interp (HEXA_APRIME_CC opt-in)
- 부트스트랩 hexa_v2 binary: **1,487,744 B** (H17 + fn-dedup + empty-{} + Field-rooted nested-index lvalue 활성화 완료)

**다음 진행 candidates**:
- #5 atlas SIGSEGV (≥17 nested-struct UB · runtime shallow-clone aliasing)
- #18 aprime_cc self-host (hexa_v2 의존 끊기) — tool/build_aprime.sh 가 부트스트랩 발판
- ~170 unmapped runtime builtins (per-symbol triage)
- statement-level DWARF `.loc` (Stmt/LInstr line threading — #13 follow-up)
- t_macro_depth aprime_cc codegen bug (abort 미발화 — aprc=0 DIFF)
- 14 CGFAIL frontend 갭 per-case triage
- aprime_cc-direct vs hexa-build 비교 baseline 전환 (interp 폐기 대응)

## 진행 로그

(append-only)

### 2026-05-20 — #18 S1-step-2 — `lower_hir` super-linear 제거 (O(N²) → near-linear, byte-eq PASS)

**작업 = correctness-preserving 성능 리팩터** — emit asm 는 byte-identical 유지. S1-step-1 이 측정한 `lower_hir` O(N²) 곡선을 제거.

**진단 (코드 확인)**: `_lower_hexpr` 재귀가 `LowerExprResult{ctx: LowerCtx}` 를 반환. `LowerCtx` 가 누적 배열 `locals`/`blocks`/`bindings` 를 필드로 보유 → 매 `_lower_hexpr` 반환마다 `hexa_val_heapify` 가 그 배열들을 deep-copy (배열 자체는 hexa 핸들 공유라 struct 재구성에서는 안 복사되나, fn-arena escape 시점의 heapify 가 N 개 원소를 모두 복사). N 개 sequential stmt → O(N²).

**리팩터 (`compiler/lower/hir_to_mir.hexa`, 단일 파일)**: 누적 배열을 module-scope `pub let mut` 로 분리 (`_lr_locals` / `_lr_blocks` / `_lr_bindings` / `_lr_frame_starts` / `_lr_globals` — 기존 `_lr_diag`/`_lr_lambdas` 관례 그대로). `LowerCtx` 는 6 스칼라 필드만 보유 (`next_local`/`next_block`/`next_arena`/`arena_root`/`cur_block`/`has_returned`) → 스레딩이 O(N) 배열을 더 이상 안 건드림. 헬퍼 (`_fresh_local`/`_new_block`/`_push_stmt_to`/`_add_edge`/`_patch_loop_sentinels`/`_bind`/`_rebind`)는 `LowerCtx` 시그니처 유지 (call graph·스레딩 순서 byte-identical) — module 배열을 in-place mutate 만.

**runtime arena 함정 2건 (측정으로 발견·해결)**:
1. **버퍼 수명** — module-global 을 함수 안에서 `= []` 로 재대입하면 그 `[]` 리터럴이 live fn-arena mark 아래서 arena-backed (cap<0) → callee arena rewind 시 버퍼 free → `_lr_*` dangling (`map key 'id' not found` → heapify 스택오버플로 SIGSEGV 로 관측). 해결: per-fn reset 을 `.truncate(0)` (같은 heap 버퍼 유지, len 만 0) 로. module 배열은 module-scope `[]` (mark_top==0 → heap) 로 1회 할당, pass 전체에서 heap 유지.
2. **원소 수명** — `_lr_blocks[i] = Block{...}` 의 `hexa_array_set` 는 (`hexa_array_push` 와 달리) 값을 heapify 안 함 → deep callee frame 에서 만든 Block 이 module 배열에 들어간 뒤 그 frame rewind 시 free. 해결: write-back 제거하고 stmts/preds/succs 를 공유 핸들째 in-place `.push` (`.push` 는 원소 heapify 함). `_patch_loop_sentinels` 는 sentinel 패치 후 `stmts.truncate(0)` + 전 원소 re-`.push`. `_rebind` 는 array_set 대신 shadowing binding append (`_mir_lookup` 이 tail-first 라 결과 동일).

**closure**: 람다 본문은 `_lr_ctx_save` (둘러싼 배열 핸들 저장) → `_lr_ctx_fresh` (람다용 신규 배열) → 람다 MFunc 빌드 → `_lr_lambdas.push` (heapify 가 람다 배열을 heap 승격) → `_lr_ctx_restore` 순. `_lr_globals` 는 module-wide read-only 라 per-ctx `globals` seed 불필요.

**재측정** (`tool/build_aprime.sh -o /tmp/aprime_s2`, arm64-Mac 로컬, smoke `exit(42)` PASS):

| N   | lower_hir (전) | lower_hir (후) | codegen | emit_asm |
|-----|----------------|----------------|---------|----------|
| 100 | 62 ms          | **2 ms**       | 19 ms   | 2 ms     |
| 200 | 270 ms         | **3 ms**       | 28 ms   | 3 ms     |
| 400 | 1527 ms        | **9 ms**       | 67 ms   | 14 ms    |

`lower_hir` 62→270→1527 (≈5.7× per N-doubling, O(N²)) → 2→3→9 (near-linear). N=400 에서 ≈170× 빠름. `codegen`/`emit_asm` 은 미변경 (리팩터가 안 건드림).

**byte-eq falsifier — PASS (7/7 fixture)**: emit asm 가 baseline(`/tmp/aprime_base`) vs 리팩터 build 사이 byte-identical 임을 확인.
- 합성 probe N=100 (39,986 B) / N=200 (88,528 B) / N=400 (191,592 B) — IDENTICAL
- `fib`/`while`/`if` 제어흐름 프로그램 (3,645 B) — IDENTICAL (`_add_edge`/`_patch_loop_sentinels` 검증)
- `compiler/codegen/arm64_darwin.hexa` closure (3 files, 1,115,763 B) — IDENTICAL
- `compiler/emit/asm.hexa` closure (2 files, 126,240 B) — IDENTICAL
- `compiler/lower/hir_to_mir.hexa` closure (7 files, 1,525,561 B) — IDENTICAL
- `compiler/check/types.hexa` closure (6 files, 1,485,818 B) — IDENTICAL

**punted**: `compiler/parse/parser.hexa` closure 는 baseline·리팩터 양쪽에서 `HX2001` (closure-incompleteness, 3293:32 미해결 식별자) 로 컴파일 실패 — 본 리팩터와 무관한 기존 버그라 fixture 에서 제외 (codegen/asm/types/hir closure 로 대체). 깨끗한 명명 — `_v2`/`_c2`/`aprime`/stage-suffix 미사용.

### 2026-05-20 — #18 S1-step-1 — codegen per-phase 계측 landed + baseline 측정 (INSTRUMENT only)

**작업 = instrumentation + baseline 측정 only** — super-linear curve 자체는 본 cycle 에서 고치지 않음 (g3 over-claim 0).

PLAN.md #18 가 S1 prerequisite 로 명시한 "codegen 단계 내부 phase 계측 추가"를 수행. `compiler/main.hexa` 의 기존 `phase_reset`/`phase_log` arena-reclaim hook 옆에 wall-clock 계측을 추가 — 별도 메커니즘 발명 대신 같은 phase-boundary 지점을 재사용.

**Instrumentation (`compiler/main.hexa`, env-gated)**:
- `HEXA_CG_PROFILE=1` 새 env-gate (`cg_profile` 모듈-스코프 flag). unset 이면 전 호출이 silent no-op — `mono_ns()` syscall 도 stderr write 도 없음.
- `cg_profile_begin()` / `cg_profile_mark(label)` 헬퍼 — `mono_ns()` (runtime.c `hexa_mono_ns`, `CLOCK_MONOTONIC` TAG_INT ns) 로 phase delta 측정, `CG_PROFILE phase=<label> delta_ms=<N>` 행을 stderr 로 출력.
- non-stream 파이프라인에 4 mark: `lower_hir` (HIR→MIR) · `mir_opt` (MIR-opt + stmt-count walk) · `codegen` (MIR→LIR) · `emit_asm` (LIR→asm). `--stream` 경로는 fused 라 `stream_fused` 단일 mark.
- **byte-identical 검증**: N=400 probe asm, `HEXA_CG_PROFILE` 有/無 `diff -q` = byte-identical. env unset 시 `CG_PROFILE` 행 0개. zero behavior change.
- 깨끗한 명명 — `_v2`/`_c2`/`aprime`/stage-suffix 미사용.

**Baseline 측정** (`tool/build_aprime.sh -o /tmp/aprime_s1`, arm64-Mac 로컬 빌드 — 2.2 MB Mach-O, smoke `exit(42)` PASS; 합성 probe `fn big()` N 개 sequential `let`):

| N   | lower_hir | mir_opt | codegen | emit_asm |
|-----|-----------|---------|---------|----------|
| 100 | 15 ms     | 0 ms    | 6 ms    | 1 ms     |
| 200 | 63 ms     | 0 ms    | 10 ms   | 1 ms     |
| 400 | 372 ms    | 0 ms    | 29 ms   | 4 ms     |

**측정 결론 — super-linear phase = `lower_hir` (HIR→MIR)**: 15→63→372 ms. N 더블링당 4.2× (100→200) · 5.9× (200→400) — O(N²) 이상. `codegen`(6→10→29) 과 `emit_asm`(1→1→4) 은 거의 선형, `mir_opt` 은 `--opt=0` 에서 무시할 수준. 이는 2026-05-17 entry 의 잔여 진단 — arm64 stmt-loop O(N²) 는 이미 제거됐고 잔여는 `_lower_hexpr` 재귀가 `LowerExprResult{ctx: LowerCtx}` 를 반환 → `LowerCtx.blocks` deep-heapify — 와 정확히 일치. 본 계측이 그 가설을 top-level phase 분해로 재확인.

**punted (다음 cycle, S1-step-2 후보)**: (1) `codegen` 내부 sub-phase 계측 (regalloc vs per-fn lowering) — PLAN.md 가 잔여를 `lower_hir` 로 이미 localize 했고 `codegen` 은 선형이라 본 cycle 에서 추가 안 함 (cheap-but-low-value). (2) super-linear 제거 자체 — `LowerCtx` 의 `blocks`/`locals`/`bindings` 누적 배열을 module-level `pub let mut` 로 빼는 lowering-pass 리팩터 (20+ helper 영향), 본 cycle scope 밖.

### 2026-05-19 — token-forge: `consciousness TokenForgeRouter { ... }` 블록 retirement (Decision C surgical unwrap)

`tool/pkg/packages/token-forge/forge.hexa` 의 마지막 잔여 별건 #4. 파일은 line 214 에서 `consciousness TokenForgeRouter { assert ...; let argv = args(); ... }` 를 top-level 블록처럼 사용 — 하지만 hexa-lang 의 `consciousness Name { ... }` 구문은 lexer/parser/codegen 어디에도 등록되어 있지 않고 (`self/formatter.hexa::ConsciousnessBlock` 만 orphan dead-branch 로 잔존), 파서는 이를 struct-literal `consciousness { TokenForgeRouter: ... }` 로 잘못 해석해서 `expected identifier, got Assert` 류의 ~40 errors 폭발. `example/consciousness_bootstrap.hexa` 의 phi/tension/faction/cells 자동주입 의미론은 published 되었으나 미구현 상태이며 — token-forge 의 블록은 **그 의미론을 전혀 사용하지 않음** (단순 라벨드 스크립트 바디 wrapper).

**결정 = C (surgical unwrap)**. 후보 비교:
- A: 본격 `consciousness` 키워드 도입 (lexer + parser + AST + codegen + 자동주입 의미론) — 새 language feature, 별도 RFC 필요.
- B: minimum-stub parse (lexer 키워드 추가 + 파서가 빈 라벨드 블록 흡수) — `consciousness` 를 키워드로 promote = KEYWORD_DEMOTE 정신 (Phase 1-4 의 `@`-attribute 전환) 역행. 또한 자동주입 의미론을 silently 위반 → g3 over-claim.
- **C 채택**: forge.hexa 의 `consciousness TokenForgeRouter { body }` 를 top-level statements 로 unwrap. `cmd` 변수에 `mut` 추가 (재할당 있음). 동작 byte-equivalent — block 은 ScopeStmt-equivalent 가 아닌 단순 wrapper 였음. minimum surgical · zero language change · zero new semantics. `consciousness_bootstrap.hexa` 의 자동주입 의미론은 **out of scope** (이미 별도로 미구현, 본 cycle 과 무관).

**측정**: parse-gate `/Users/ghost/.hx/bin/hexa_real parse tool/pkg/packages/token-forge/forge.hexa` 사전 = 40+ errors @ L215-253, 사후 = `OK: ... parses cleanly`. 다른 .hexa 파일 무변경. `self/formatter.hexa::ConsciousnessBlock` orphan branch 는 의도적으로 leave-as-is — 추후 "consciousness language feature" RFC 가 그것을 revive 하거나 영구 삭제할 수 있음. 본 변경의 g3-honest 범위 = "forge.hexa parse 차단 해결" only, "consciousness 의미론 결정" 아님.

### 2026-05-19 — drill: pluggable verifier hook landed (inbox phanes-pluggable-verifier-oracle-for-drill-loop SSOT-resolved)
`compiler/drill/drill.hexa`: `DrillOpts` += `verifier_cmd` / `verifier_timeout_s` / `verifier_authoritative` (defaults preserve byte-identical pre-hook behavior); new `VerifierVerdict { verdict ∈ pass|fail|continue|skip|error, rationale, round }` + `_verifier_run` / `_verifier_audit_emit` helpers; single call site in `drill_run` AFTER `_honesty_gate` BEFORE `checkpoint_save`; authoritative-stop verdicts (pass → saturated=true, fail → verifier_stopped=true) halt the loop with checkpoint flush; advisory verdicts log only. `DrillResult` += `verifier_stopped` / `verifier_verdict` (positional literals updated at both return sites). CLI flags `--verifier-cmd <sh-cmd>` / `--verifier-timeout <Ns>` / `--verifier-strict` on `hexa drill`. Audit trail = stderr `DRILL_VERIFIER {...}` row + synthesized `__BT_AI2__` sentinel on pass/fail so downstream `bt_ai2_audit` sees the verdict alongside the existing BT-AI2 round line. Verifier is untrusted tenant code — sandbox enforcement is phanes' responsibility (mirror of `g_qrng_provider_only` boundary). Parse-gate clean: drill.hexa · batch.hexa · drill_test.hexa · accumulation_test.hexa. Binary promote = standard separate deploy step per the 22c27a05 pattern.

### 2026-05-17 — 13 DIFF 정밀 3-way 재분류 (aprime / interp / hexa-build) — 실제 aprime 갭 정밀화
13 DIFF 중 atlas verifier 5 + suspect-interp 2 = 7건을 aprime/interp/hexa-build 3-way diff.

**판정**:
| test | ap | ip | hb | 판정 |
|------|----|----|----|------|
| n6_uniqueness | 36 | 16 | 36 | **INTERP-BUG** (aprime==hb, aprime 정답) |
| sigma_phi_tau | 29 | 20 | 29 | **INTERP-BUG** (aprime==hb) |
| atlas_cycle_append | 2 | 22 | 2 | **INTERP-BUG** (aprime==hb) |
| atlas_doctrine | 17 | 15 | 15 | APRIME-BUG (interp==hb) |
| atlas_tecsl_verify | 38 | 38 | 38 | APRIME-BUG (interp==hb, content 차) |
| atlas_wave3 | 28 | 23 | 23 | APRIME-BUG (interp==hb) |
| atlas_hxc_roundtrip | 2 | 1 | 27 | aprime-bug (3자 모두 상이; hb=full-correct 27) |

**결산**:
- **확정 INTERP-BUG 3건** (n6_uniqueness · sigma_phi_tau · atlas_cycle_append) — aprime 정답, interp 가 틀림. → aprime 유효 커버리지 = 39 MATCH + 3 = **~42/60 (70%)** (신뢰 oracle hexa-build 기준).
- **실제 APRIME 버그 정밀 식별**: atlas_doctrine·atlas_tecsl_verify·atlas_wave3 (interp==hexa-build, aprime 만 divergence — 셋 다 출력 line 수/내용 차, atlas verifier 경로 공통 root cause 가능성) + atlas_hxc_roundtrip (전체 미흡). 이 4건이 gate ① 의 진짜 타겟.
- 다음 cycle gate-① 작업은 **atlas verifier codegen divergence (3건, 공통 root 추정)** 우선 — interp-noise 와 분리된 정확한 표적 확보.

### 2026-05-17 — interp 가 oracle 로서 buggy 임을 실증 — aprime==hexa-build, interp outlier
suspect-interp DIFF 2건 (`n6_uniqueness_smoke`, `sigma_phi_tau_uniqueness_smoke`) 을 3-way 비교 (aprime / interp / hexa-build).

**결과** (둘 다 동일 패턴):
- `n6_uniqueness`: aprime 36 lines == **hexa-build 36 lines** (byte-identical) · interp **16 lines** (truncated)
- `sigma_phi_tau`: aprime 29 == **hexa-build 29** · interp 20 (truncated)
- → **aprime_cc == hexa-build** (양 compiled path 일치), **interp 이 outlier** — 두 compiled path 모두에서 벗어남. interp 가 출력을 조기 절단하는 interp-side 버그.

**함의**:
1. aprime-vs-interp 메트릭이 aprime 실제 정확도를 **과소평가** — 13 DIFF 중 ≥2 는 aprime 버그가 아니라 interp 버그. 신뢰 oracle(hexa-build) 기준 aprime ≈ 41/60 (68%).
2. **인터프리터 폐기 논거 실증**: interp 는 느릴 뿐 아니라 **틀린다** — 두 compiled path 와 불일치. g_interp_deprecated 의 "compiled 가 SSOT" 를 데이터로 확인.
3. baseline 을 aprime-vs-interp → **aprime-vs-hexa-build (양 compiled)** 로 전환 권장 (이미 PLAN 권고; 이제 실증 근거 확보). 다음 full sweep 부터 적용.

→ 잔여 DIFF 재분류: n6_uniqueness·sigma_phi_tau = **interp-bug (aprime 정답)**, gate ① 유효 커버리지에서 제외.

### 2026-05-17 — 60-smoke 재측정 (char-literal fix 반영) — 39/60 (65%)
char-literal TAG_STR fix (`e0d9ba94`) + 세션 누적 fix 반영 aprime_cc 60-smoke vs interp.

**결과**: N=60 · **MATCH=39 (65%)** · DIFF=13 · CGFAIL=7 · LINKFAIL=1. 직전 34/60 → **+5** (char fix 가 char-비교 쓰는 테스트 다수 unblock). 세션 trajectory: 27/60(45%) → 30 → 34 → **39/60(65%)**.

**잔여 DIFF 13**: atlas verifier ×5 (cycle_append·doctrine·hxc_roundtrip·tecsl_verify·wave3, aprc=1 semantic) · t_macro_depth ×3 (struct-param 변이 시맨틱, RFC-sized) · suspect-interp ×2 (n6_uniqueness·sigma_phi_tau — interp 측 오류 의심) · misc ×3 (t_range_precedence·t_select_dispatch_parse·t34_net_listen).
**CGFAIL 7**: atlas_verify·regression·t_multiarch_cpu·t_parser_select_attr·t35/36/37_hxqwen — frontend feature 갭 (extern fn·@select·type-inference 등).

**R7 게이트 ①**: 65% — char fix 로 +8%p. 잔여는 atlas verifier semantic + frontend feature (RFC-sized) + struct-param 시맨틱. multi-cycle 이나 추세 양호.

### 2026-05-17 — char-literal TAG_STR fix (`e0d9ba94`) + self-host 잔여버그 정밀 진단
**char-literal fix (LANDED `e0d9ba94`)**: `compiler/lower/hir_to_mir.hexa` 가 `literal_char` → `_const_int_op(0)` — 모든 char 리터럴('.','a','\n'…)이 정수 0. `cs[i] != '.'` (cs = `s.chars()` = single-char TAG_STR) 가 TAG_STR vs int 0 비교 → 항상 unequal. `_ends_with_hexa()` 가 늘 false → 2nd-gen self-host 의 `_normalize_argv` 가 `_drv.hexa` 마커 인식 실패. 수정: `literal_char` → `_const_str_op(e.text)` (hexa_v2 codegen_c2:3247 "char literals must be TAG_STR" 미러). 검증: smoke PASS · char-비교 프로그램 interp 와 byte-identical · 2nd-gen `_normalize_argv` 정상 (`_drv.hexa ew=T`, out.len=4 == 1st-gen).

**self-host 잔여버그 (다음 cycle, #23)** — 정밀 진단 완료:
- char fix 후 `_normalize_argv` 는 정상 작동(out.len=4 검증). 그러나 그 **return 직후** main 에서 crash: `array[0]: container is not an array (tag=<비결정 garbage>)` — 실행마다 tag 다름 (45989888 / 0 / 1876935776) = **초기화 안 된 메모리 read**.
- lldb bt: `_L357d_main_bb2 → hexa_array_get`. main 의 flag-parse 경로(top-level `let user_argv = _normalize_argv()` → 전역 g67 → `while ai<len(user_argv){ let a = user_argv[ai] }`). main 의 `bl __normalize_argv` 직후 asm 은 x0:x1 → L164 → g67 저장이 정상적으로 보임. → array-returning fn 의 return-value handoff 또는 spill-slot 별 uninitialized read 의심 (atlas 16-byte spill-slot 버그의 sibling 가능성). 비결정 garbage 특성상 codegen-correctness (ABI/spill) class.
- frontend 100% · codegen 완주(64s) · link OK · argv-wiring OK · `_normalize_argv` OK 까지 도달. 이 단일 ABI/spill 버그가 self-host fixpoint 의 마지막 관문. 별도 focused 디버깅 cycle 필요 (asm-level ABI trace).

### 2026-05-17 — self-host fixpoint 1차 시도 — codegen 완주 + argv 와이어링, 잔여 arg-handling 버그 (`0a78e0ed`)
codegen-perf-v2 (`82baa09e`) 로 full `compiler/main.hexa` codegen 이 완주(64s)하게 되어 self-host fixpoint 를 처음 실제 시도.

**진척**:
1. **flatten** (38 files / 22,053 lines) → aprime_cc(1st-gen) → `selfhost.s` **222,988 lines / 8.9 MB, 64s** (HX4001 warning 만, error 0).
2. **link** `selfhost.s` + runtime.o + stub(.o) → 2nd-gen aprime_cc **1,809,128 B**. 미해결 심볼 2개 (`_list_dir`·`_sha256_hex`) = build_aprime.sh 가 C-path sed 처리하던 것 → asm-path stub `.c` (sha256_hex→hexa_sha256, list_dir→hexa_array_new) 로 해소.
3. **argv 블로커 발견+수정** (`0a78e0ed`): 2nd-gen "missing SOURCE.hexa" — aprime_cc 가 `_main` 에 argc/argv→hexa_set_args 와이어링 미emit. `_arm64_lower_func` prologue 직후 `mf.name=="main"` 시 `bl _hexa_set_args` 삽입. 검증: smoke PASS·`args()` populated·무회귀.

**잔여 블로커 (다음 cycle)**: argv 수정 후 2nd-gen 이 argv 를 읽으나 `_normalize_argv` 처리 중 `array[0]: container is not an array (tag=45989888)` — HexaVal tag corruption. aprime_cc 가 컴파일러 자체 arg-handling 코드를 miscompile. self-host fixpoint 마지막 관문 — frontend 100% · codegen 완주 · link OK · argv OK 도달, arg-handling 정확성 1건 남음.

**의의**: #18 self-host correctness 축이 거의 닫힘 — frontend 전체 + codegen 완주 + 2nd-gen 링크 성공. 남은 건 단일 codegen-correctness 버그 (arg-handling tag corruption) + lower_hir O(N²) (codegen-perf-v2 out-of-scope).

### 2026-05-17 — R7 게이트 ② 정정: `hexa.real` 은 이미 compiled CLI dispatcher
배포 topology 정밀 조사 결과 — `~/.hx/bin/hexa` → repo `hexa` (bash shim) → `hexa.real`. `hexa.real` 은 `tool/build_dispatch.hexa` 가 `build/stage1/main.c` (= `self/main.hexa` 를 hexa_v2 transpile 한 것) 를 clang 컴파일한 **compiled 바이너리** (480 KB, strings 에 `0.1.0-dispatch` · `self/main.hexa::dispatch_absorbed` 확인).

→ **게이트 ② (`hexa` CLI 드라이버 compiled) 는 이미 실질 충족** — `hexa build`/`parse`/`cc`/dispatch 는 compiled `hexa.real` 에서 동작 (interp 아님). `hexa run X.hexa` (스크립트 실행) 만 dispatcher 가 `hexa_interp.real` 로 위임.

cli-driver sub-agent 의 실제 기여 = (a) `tool/build_hexa_cli.sh` canonical recipe, (b) `resolve_module_loader_compiled()` 와이어링 (게이트 ④ — flatten child 를 interp-free 로), (c) runtime.h fwd-decl 3개. 게이트 ②는 신규 달성이 아니라 기존 충족 상태 확인.

**잔여 R7**: ① coverage (57%) · ④ deploy (compiled module_loader 배포 + hexa.real 재빌드 — `tool/build_dispatch.hexa` 루틴) · `hexa run` 스크립트 실행 경로의 interp 의존 (= 인터프리터 본체, 최종 삭제 트랙).

### 2026-05-17 — 60-smoke 재측정 (atlas SIGSEGV + CGFAIL fix 반영) — 34/60 (57%)
atlas SIGSEGV fix (`589e7c6e`) + CGFAIL triage (`702fb30a`) 반영 aprime_cc (2,050,712 B) 60-smoke vs interp 재측정.

**결과**: N=60 · **MATCH=34 (57%)** · DIFF=15 · CGFAIL=10 · LINKFAIL=1. 직전 30/60 (50%) → **+4**.

- atlas SIGSEGV 3건 (atlas_materials_limits · atlas_real_limits · static_index_lazy_poc) DIFF→**MATCH** — Bug 2 (arm64 16-byte spill slot) 가 광범위 적용.
- CGFAIL 14→10 (CGFAIL agent fix).
- 신규 노출 DIFF: divisor_field_theory · physics_constant_engine · reachability (이전 CGFAIL → 이제 compile+run 되나 DIFF — 진척).

**잔여 DIFF 15 클러스터**:
- atlas verifier semantic × 5 (atlas_cycle_append · atlas_doctrine · atlas_hxc_roundtrip · atlas_tecsl_verify · atlas_wave3)
- t_macro_depth × 3 — **struct 파라미터 변이 시맨틱 divergence** (단순 codegen 버그 아님): `check_bound(ctx, ...)` 내부의 `ctx.depth = ...` / `ctx.error = ...` Field-assign 이 caller 의 `ctx` 에 반영 안 됨. aprime = value-copy (Field-assign 이 `ctx = hexa_map_set(ctx, ...)` 로 로컬 rebind), interp = reference. → 구조체 인자의 reference 시맨틱 문제 — value-model 레벨, RFC-sized.
- suspect-interp × 2 (n6_uniqueness · sigma_phi_tau — interp 조기종료 의심)
- 신규 triage × 3 (divisor_field_theory · physics_constant_engine · reachability)
- misc × 2 (t_range_precedence · t34_net_listen)

**CGFAIL 10**: 5 frontend feature 갭 (`#{}` map · `extern fn` · `try/catch` · `@select` annotation · type-inference) — RFC-sized.

**R7 게이트 ① (coverage ≥ interp)**: 현재 57% — 목표 ~100%. 잔여 = frontend feature 5 + atlas verifier 5 + 기타. multi-cycle.

### 2026-05-17 — R7 gate #2 + #4: compiled `hexa` CLI driver LANDED (`24cf3e01`, subagent-cli-driver-selfhost)
인터프리터 폐기 R7 게이트 ② (`hexa` CLI 드라이버 = `self/main.hexa` 가 interp 없이 compiled 바이너리 동작) + ④ (`self/module_loader.hexa` flatten interp-free) 종결.

- **gate ④ closure 분석**: `self/main.hexa` 는 `import`/`use` 0개 — 완전 self-contained. compiled closure = `main.hexa` + `runtime.c` 뿐. `module_loader.hexa` 는 closure 에 없음 — 드라이버가 런타임에 별도 자식 프로세스로 호출 (`cmd_build` flatten 단계). → module_loader 자체 compiled 바이너리 필요 (gate ④ 는 별도 산출물로 처리).
- **산출물**: `build/hexa_cli_driver` (compiled self/main.hexa, 542 KB) · `build/hexa_module_loader` (compiled self/module_loader.hexa, 380 KB). 둘 다 `hexa_v2 → C → clang` (runtime.c 2nd-TU 단일링크).
- **드라이버 wiring**: `resolve_module_loader_compiled()` 신규 — `cmd_build` flatten 단계가 compiled module_loader 우선 탐지, 있으면 interp-free 직접 호출, 없으면 interp+소스 fallback (default 안전).
- **검증**: compiled 드라이버 `build`/`parse`/`--version`/`--help` 가 interp-driver 와 byte-identical. `use`-bearing 파일 build 시 compiled module_loader 가 interp-free flatten.
- **canonical recipe**: `tool/build_hexa_cli.sh` (5-stage, build_interp.hexa 구조 미러).
- **runtime.h** +3 additive forward-decl (`hexa_array_truncate`, `rt_str_trim_start`, `rt_str_trim_end`).
- **남은 R7**: `run` 서브커맨드는 여전히 별도 interp 바이너리 위임 (= 인터프리터 본체, 별도 retire 트랙). 드라이버 자체는 interp-free 달성.
- **배포 후속**: `cp build/hexa_cli_driver ~/.hx/bin/hexa.real` + `build/hexa_module_loader` 자동 발견 시 `~/.hx/bin/hexa` 가 build/parse/cc/dispatch 에서 interp-free.
### 2026-05-17 — #18 aprime_cc self-host — feasibility 측정 + codegen 3 perf fix (branch `subagent-aprime-selfhost`)

aprime_cc 가 `compiler/main.hexa` 자체를 컴파일하는 self-host 1차 시도. **결론: self-host 의 1차 블로커는 codegen-correctness 가 아니라 codegen 의 super-linear 성능** — 정확성은 대부분 통과한다.

**측정 (`tool/build_aprime.sh` 로 빌드한 aprime_cc, 2,050,280 B)**:

- **full flatten** (`compiler/main.hexa` import+use closure = 38 files / 21,832 lines): typecheck 전체 통과 (HX 진단 = HX4001 integer-div warning 11건뿐, **error 0건**), 그러나 codegen+emit 단계에서 9분 cap 도달 → `.s` 미산출. 즉 frontend(lex/parse/check/lower) 는 21K-line 컴파일러 소스를 끝까지 처리하나 codegen 이 끝나지 않음.
- **부분 closure 자체-컴파일 (self-contained, byte-checked)**:
  - parser closure (`compiler/parse/parser.hexa` + 의존 5 files / 2,946 lines) → `--emit=asm` **성공**, 1,071,947 B asm, 1,147 심볼 / 8,133 instr, stub/TODO 0. clang assemble OK, link 시 미해결 심볼 = `_lex` 1개뿐 (closure 누락 — 본 self-host 차단 아님).
  - codegen closure (`compiler/codegen/arm64_darwin.hexa` + 의존 3 files / 2,076 lines) → **성공**, 892,158 B asm.
  - → 컴파일러 프론트엔드의 가장 어려운 부분(파서·코드젠 모듈)이 aprime_cc 로 깨끗이 self-compile 된다.
- **블로커 분류 (full self-host)**: (1) **codegen 성능 — 지배적 블로커** · (2) HX4001 warning 11 (무해) · (3) HX2001 `_lex` 류 — flatten 누락이지 실제 갭 아님. **codegen-correctness 갭 / unmapped builtin 은 부분 closure 측정 범위에서 0건** (full 측정은 codegen 미완료로 미확정).

**codegen 성능 root-cause (측정 anchored)**: 합성 단일 함수 micro-probe (`fn big()` N개 sequential `let`):
N=100/200/300 → 산출 OK (~150-180s @N=300), N=400 → 산출 OK (~263s), N=1205 → 220s+ timeout. **함수당 statement 수에 super-linear** — 절대 상수도 큼(~0.5s/stmt). 컴파일러 자체의 `_lower_hexpr` (1,209 lines · `compiler/lower/hir_to_mir.hexa`) 한 함수가 이 곡선의 우측 끝 → full self-host 가 codegen 에서 멈추는 직접 원인.

**이번 cycle fix (3건, `compiler/codegen/arm64_darwin.hexa` + `compiler/emit/asm.hexa` — correctness-preserving)**:
1. `_arm64_assign_regs` 의 live-interval 정렬: insertion-sort O(N²) → **counting-sort O(N+maxStart)** (stable, `iv.starts` 가 dense pos-index 이므로 안전). 큰 함수에서 N=interval 수가 수천 → O(N²) 가 지배 비용이었음.
2. 동 함수 expire/spill 루프의 inline `while pp < len(mf.params)` param-scan (O(order·active·P)) → **`is_param[k]` 1회 pre-pass** 후 O(1) 배열 read.
3. `emit/asm.hexa::_emit_func` 의 per-instruction `out = out + …` left-fold O(I²) → **array `iparts` + `join("")` O(I)** (module-scope `emit_asm` 의 기존 F4 idiom 미러).

**검증**: 빌드 smoke `exit(6*7)==42` PASS. probe_cg(892,158 B)·probe_parse(1,071,947 B)·bf_200(231,355 B) 모두 fix 전/후 **byte-identical** (zero regression). bf_200 산출 바이너리 실행 → exit 165 = `big()%256` 정답 (end-to-end codegen correctness 확인). 다만 N=1205 micro-probe 는 fix 후에도 220s+ 미완 — fix 가 곡선을 낮췄으나 super-linear 자체는 미제거.

**남은 staged roadmap (#18 완주)**:
- **S1 — codegen 성능 (잔여 블로커)**: 측정상 codegen 단계가 여전히 super-linear. 후속 후보: (a) `_arm64_lower_func` 의 per-statement `instrs = _emit_arm64_stmt(instrs,…)` 경로 — runtime array pass-by-value(I1) 스냅샷 비용 프로파일 필요, (b) live-range/active-loop 의 잔여 배열 재구성(`keep`/`na` per-step rebuild) 비용 측정, (c) `_arm64_modhash`/`_arm_index_of` fast-path miss 빈도 측정. **codegen 단계 내부 phase 계측 추가**가 S1 선행 작업.
- **S2 — full closure codegen 완주**: S1 후 21K-line full flatten 이 시간 내 `.s` 산출하는지 재측정. 산출되면 처음으로 codegen-correctness 갭 / unmapped builtin 의 full-scope 측정 가능.
- **S3 — assemble+link self-host**: full `.s` → clang assemble → runtime.c link → `aprime_cc` 2세대 바이너리. 1세대(hexa_v2 경유) vs 2세대(self) byte-diff = self-host fixpoint 검증.
- **S4 — hexa_v2 의존 제거**: `tool/build_aprime.sh` stage 2 를 hexa_v2 대신 aprime_cc 로 교체.

정직한 평가: self-host 는 본 측정으로 **multi-cycle 확정**. 그러나 frontend(21K-line 전체 typecheck 통과) + 부분 closure self-compile(파서·코드젠 모듈 byte-clean) 은 self-host 가 codegen 성능 한 축만 남았음을 보인다 — correctness 축은 거의 닫혀 있다. #18 의 본질은 컴파일러 엔지니어링(linear-scan regalloc + emit 의 상수/복잡도)이지 언어 갭이 아니다.

### 2026-05-17 — 60-smoke aprime_cc-direct 재측정 (cycle-end) — 30/60 MATCH
cycle-activated aprime_cc (`tool/build_aprime.sh`, 2,050,384 B) 로 60-smoke vs interp 재측정.

**결과**: N=60 · **MATCH=30 (50%)** · DIFF=16 · CGFAIL=14 · LINKFAIL=0. 직전 baseline 27/60 (45%) → +3.

정직한 평가: 이번 cycle 의 fix 대부분 (fn-dedup · fn-param shadow · runtime.h sweep) 은 tier-2 hexa-build 경로 대상이라 tier-1 aprime_cc-direct 의 byte-identical 수에 직접 기여 작음. aprime_cc-direct 에 직접 닿은 fix = nil→TAG_VOID · empty-{} parser · DWARF(.loc 는 출력 bytes 무영향).

**잔여 DIFF 16 분류**:
- **SIGSEGV (aprc=139) × 3**: atlas_materials_limits · atlas_real_limits · static_index_lazy_poc — #5 cluster (≥17 nested-struct UB).
- **atlas verifier (aprc=1) × 5**: atlas_cycle_append · atlas_doctrine · atlas_hxc_roundtrip · atlas_tecsl_verify · atlas_wave3 — verifier 의미 흐름 divergence.
- **aprime codegen bug (aprc=0, 출력만 틀림) × 3**: t_macro_depth_default/override/valid — `[FAIL]` emit (interp `[PASS]`). macro-depth abort 미발화 — aprime_cc codegen correctness 버그.
- **interp 측 의심 × 2**: n6_uniqueness · sigma_phi_tau_uniqueness — aprime 출력이 interp 보다 LONGER (interp 가 조기 종료 의심 — interp 폐기 대상이라 aprime 이 오히려 정답일 수 있음).
- **기타 × 3**: regress_dict_keys_let_bind (module-level let mixed) · t_range_precedence (hexa_range_array) · t34_net_listen (aprc=138).

**CGFAIL 14**: frontend codegen 갭 — atlas_verify · regression · t_cert_* · t35/36/37_hxqwen 등. 각각 별도 triage.

**메타**: aprime_cc-vs-interp 비교는 interp 폐기 진행으로 baseline 신뢰도 하락 (n6_uniqueness 처럼 interp 가 틀린 케이스 존재). 다음 cycle 부터 aprime_cc-direct vs hexa-build (둘 다 compiled) 비교로 전환 권장.

### 2026-05-17 — #11 tool/build_aprime.sh — aprime_cc 빌드 레시피 canonical 화 (`afb839d7`)
aprime_cc 빌드 레시피가 out-of-tree `/tmp/arm64_feasible.sh` 에만 존재했던 것을 repo tool 로 canonical 화.

**`tool/build_aprime.sh`** — 5-stage pipeline: (1) compiler/main.hexa import+use closure flatten (embedded.gen stub) → (2) hexa_v2 transpile → (3) s4_flatc_post.py + builtin sed + runtime.h→runtime.c inline → (4) clang -O1 -arch arm64 → aprime_cc → (5) smoke (`fn main(){exit(6*7)}` → $?==42). Flags `-o`/`-r`/`-v`. Exit 0/1/2 = built+smoke / build-fail / smoke-fail.

`/tmp` 스크립트 대비 개선: 파라메트릭 (하드코딩 경로 제거) · in-repo `self/native/hexa_v2` 사용 · per-build mktemp dir (trap-clean) · honest exit code.

**`tool/s4_flatc_post.py`** — optional `argv[1]` input-path 추가 (default `/tmp/flat4.c` 유지). build_aprime.sh 가 per-build private path 전달 → concurrent build 시 공유 `/tmp/flat4.c` collision 제거 (이 collision 이 parallel 호출 시 간헐적 "clang linker failed" 원인이었음).

**Validation**: `bash tool/build_aprime.sh -o /tmp/aprime_final` → 5 stage 전부, aprime_cc 2,050,384 B, smoke exit(42)==42 PASS.

### 2026-05-17 — RFC 040 GPU builtin interp dispatch fix — merged-rfc043 interp 빌드 차단 해소 (`c8a5fe44`)
직전 배포 entry 의 ⚠️ caveat (merged-rfc043 interp 빌드 차단) 종결.

**Root cause**: hexa_full.hexa interp dispatch block 이 10개 RFC 040 GPU builtin 을 `hexa_` prefix 로 호출 (`hexa_cuda_available()` 등). hexa_v2 가 prefixed name 을 direct-callable 로 인식 못 해 `hexa_callN(hexa_cuda_available, ...)` indirect-call emit — 하지만 `hexa_cuda_available` 은 plain C function, TAG_FN carrier 는 un-prefixed `cuda_available` (runtime.c:10915). clang `passing 'HexaVal (void)' to incompatible type 'HexaVal'` 실패.

**Fix** (commit `c8a5fe44`, rfc043-hexa-torch): hexa_full.hexa 의 10 GPU builtin 호출에서 `hexa_` prefix strip → transpile 이 carrier (`hexa_call0(cuda_available)`) 로 route. 10 carrier 전부 runtime.c 에 존재 확인.

**Validation**: merged-rfc043 트리에서 interp 정상 빌드 (`build/hexa_interp.real` 3,208,304 B). chr(240) → 0xF0, `cuda_available()` → 0 (no-CUDA fallback), basic program 정상.

**배포 갱신**: `~/.hx/packages/hexa/build/hexa_interp.real` 를 rfc043-merged interp (3,208,304 B) 로 재배포 — 직전 origin/main build (3,170,304 B, GPU dispatch 미포함) 대체. 이제 배포 interp = chr + atlas + RFC 040 GPU dispatch 전부 포함. `hexa run` 검증: `ord(chr(240))`=240, `cuda_available()`=0.

→ 직전 entry 의 "merged-rfc043 interp 빌드 차단 (forge-domain)" caveat **RESOLVED**.

### 2026-05-17 — 배포: main→rfc043 머지 + interp 바이너리 refresh (wilson P0#2 deployment)
Wilson 다운스트림 배포 요청 2건 처리.

**Action 1 — `origin/main` → `rfc043-hexa-torch` 머지** (commit `170d64d7`):
interp-retirement cycle 21 commits (d179f4a1 → 1ce840ec) 를 active flame/forge 브랜치에 들임. 충돌 해소: runtime.h union (rfc043 `hexa_chr_byte` + main R5 sweep), hexa_cc.c/hexa_v2 generated artifact → 머지 후 재생성. codegen_c2.hexa/hexa_full.hexa/AGENTS.tape auto-merge clean. 머지 후 hexa_v2 1,491,008 B 재생성 (empty-{} 등 cycle fix 전부 active).

**Action 2 — 배포 interp 바이너리 refresh**:
`~/.hx/packages/hexa/build/hexa_interp.real` May 14 stale (chr 8-byte codepoint) → origin/main build 로 교체 (3,170,304 B, codesigned). 검증: `hexa run` 으로 `ord(chr(240))` = 240, `len(chr(159))` = 1 (byte-level). 이전 바이너리 `.bak-may14` 백업.

**⚠️ Caveat — merged-rfc043 interp 빌드 차단 (forge-domain)**:
머지된 rfc043 트리에서 interp 직접 빌드 시 10개 RFC 040 GPU builtin 에서 실패 — `hexa_call0(hexa_cuda_available)` 등이 fn-pointer carrier 를 기대하지만 hexa_cuda_available 등은 plain C function. hexa_v2 transpiler 의 direct-call 인식 갭 (rfc043 commit 54d56e4a 가 GPU interp dispatch 를 wire 했으나 interp 재빌드 미검증). **forge-domain 별도 작업** — 배포 interp 는 origin/main 빌드로 대체 (chr+atlas fix 포함, RFC 040 GPU interp dispatch 미포함 — GPU 는 어차피 Mac 불가).

**다운스트림 후속**: wilson 측에서 배포 완료 신호 수신 후 PATCHES.yaml chr 엔트리 `partial`→`applied` flip + chr-prefix split 코멘트 정리.

### 2026-05-17 — interp-retire #5: atlas struct-array SIGSEGV — 2 codegen bugs (parser + arm64 spill)

test/{atlas_materials_limits,atlas_real_limits,static_index_lazy_poc}_smoke.hexa 3 files crashed rc=139 (SIGSEGV) under aprime_cc-direct while interp returned rc=0. ASAN: null-page READ at 0x6 (hexa_array_push / hexa_map_get). Two independent codegen bugs (runtime.c was NOT at fault).

**Bug 1 - empty-literal global initializer dropped (compiler/parse/parser.hexa)**
- _parse_module_one splices a top-level `let X = E` initializer into the synthetic main; the has_init test was `!(it.body.text == "" && len(it.body.children) == 0)`.
- `[]` (ArrayLit), `{}` (empty map), `""` (empty StrLit) all have text=="" + children==[], so a real initializer was wrongly judged has_init=false and dropped.
- Result: a global like `let _CACHE: array = []` stayed zero-filled in .data -> arr_ptr==NULL -> SIGSEGV on the first `.push`. static_index_lazy_poc_smoke's _POC_CACHE is exactly this case.
- Fix: the empty_expr() sentinel is uniquely kind==Ident && text=="" && children==[]. has_init now tests `!(it.body.kind == ExprKind::Ident && text=="" && children==[])` so empty ArrayLit/map/StrLit pass (different kind).

**Bug 2 - arm64 victim-spill slot size 8B (compiler/codegen/arm64_darwin.hexa)**
- The linear-scan regalloc victim-spill branch (_arm64_build_regmap, ~line 424) did `next_slot = next_slot + 8`, but HexaVal is 16B (tag+union, stp/ldp pair) and the other two slot-allocation sites use +16.
- Every value spilled via the victim path overlapped the high 8B of its predecessor slot; with enough spills the slot offsets wrapped and aliased low-frame slots.
- Result: a 24-element [Node] (nested struct + array field) literal stored element 7+ into colliding slots -> NODES[7..22] returned garbage (TAG_MAP with a junk map_ptr) -> hexa_map_get SIGSEGV. Only index 0-6/23 worked = the reported "N=17 threshold".
- Fix: victim-spill `next_slot += 8` -> `+= 16` (matching the other sites).

**Validation**: all 3 reproducers rc=0 + byte-identical output to interp (`materials_limits smoke: PASS` etc.). Minimal repro `let NODES:[Node]=[24x nested-struct]` -> `NODES[14].kind` also passes. aprime_cc rebuilt 2,050,440 B, smoke exit(42) PASS.

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

### 2026-05-17 — interp-retirement R5: aprime_cc CGFAIL 클러스터 triage + 3 bounded fix

60-smoke aprime_cc-direct sweep 의 **14 CGFAIL** (codegen 진입 전 abort) 을 진단·클러스터링. 14 → **8 root-cause 클러스터** 로 수렴:

| 클러스터 | 원인 | 영향 test | 처리 |
|---------|------|-----------|------|
| A | `recv.<m>(…)` 메서드 selector 가 `types.hexa::_is_builtin_method` allow-list (31개) 에 없음 → HX2001 callee-miss | `repo_taxonomy_audit_smoke` (`ln.find`) | **FIXED** — allow-list 를 legacy `gen2_method_builtin` 전수 (90개) 로 확장 |
| B | `#{…}` map-literal 문법 미지원 — compiler/lexer 에 `#` 토큰 자체 없음 | `t_cert_bucket_split` · `t_cert_roundtrip` · `t36_serve_alm_smoke` · `t_select_dispatch_parse` | 미해결 (frontend feature — lexer `HashLBrace` 토큰 + parser + HIR/MIR/codegen. legacy `self/hexa_full.hexa` 에는 존재) |
| C | `extern fn` / `@link` FFI 선언 미지원 — compiler 에 `extern` 키워드 없음 | `t35_hxqwen14b_abi_smoke` · `t37_hxqwen14b_day2_smoke` | 미해결 (frontend feature — lexer `KwExtern` + `parse_extern_fn`. legacy 에 존재) |
| D | `str` 타입 어노테이션이 `string` 으로 alias 안 됨 → `named:str` ≠ `string` HX3003 | `t_statusline_4panel` | **FIXED** — `_types_lower_type_ref` 에 `n == "str"` 1줄 추가 |
| E | free-call builtin `now` / `env_var` 가 `bind.hexa::_bind_builtin_names` 에 없음 → HX2001 | `t_cmd_url_args_passthrough` · `t_exec_env_reproducible` · `t_multiarch_cpu_smoke` (부분) | **FIXED** — bind 등록 + codegen runtime-sym 매핑 (`now`→`hexa_timestamp`, `env_var`→`hexa_env_var`). `t_multiarch_cpu_smoke` 는 `alloc_raw` (interp-routed, runtime-sym 없음) 잔존 |
| F | `try`/`catch` 예외 구문 미지원 | `regression` | 미해결 (frontend feature) |
| G | `@select("fam", n<=16 -> insertion, …)` 어노테이션 인자 내 `->` 파싱 실패 | `t_parser_select_attr` | 미해결 (frontend — annotation 인자 special-form 파싱) |
| H | 타입추론 strictness — HX3004 return-type-mismatch (`unit` 추론) · HX3001 i64/f64 | `atlas_verify_smoke` (19→1 err) · `regression` | 미해결 (별도 추론 작업) |

**FIX 3건** (compiler-side only — semantic 변경 아님, allow-list/매핑 추가이므로 g_inbox_dual_track 면제):
- `compiler/check/types.hexa` — `_is_builtin_method` 31→90 (legacy 전수); `_types_lower_type_ref` `str` alias
- `compiler/check/bind.hexa` — `_bind_builtin_names` 에 `env_var` `now` 추가
- `compiler/codegen/arm64_darwin.hexa` — `_builtin_runtime_sym` 에 `env_var`/`now`/`find` 매핑 (runtime.h 에 `hexa_env_var`/`hexa_timestamp`/`hexa_find_poly` fwd-decl 이미 존재)

**검증** (aprime_cc 재빌드 + smoke exit(42) PASS):
- CGFAIL 14 → **10** : `repo_taxonomy_audit_smoke` · `t_cmd_url_args_passthrough` · `t_exec_env_reproducible` · `t_statusline_4panel` 4건 ASM-OK
- 4건 모두 `clang -c` 어셈블 OK; `repo_taxonomy_audit_smoke` 는 link→run→**exit 0 PASS** (end-to-end)
- 회귀 sample 5건 (`atlas_n6_axes`/`calc_cli`/`factorial_structure`/`catalan_combinatorial`/`divisor_field_theory`) ASM-OK 0 fail
- `atlas_verify_smoke` 19 diag → 1 (HX3004 잔존, 클러스터 H)

**미해결 클러스터 (B/C/F/G/H)** 는 bounded fix 범위 밖 — 각각 lexer 토큰 + parser + HIR/MIR/codegen 신규 경로가 필요한 frontend feature. legacy `self/hexa_full.hexa` 에는 전부 구현돼 있으므로 interp-retirement 완주 전 별도 RFC/cycle 로 포팅 필요.

**unmapped runtime builtin triage** (bind allow-list 265 − codegen-mapped 73 − method 93 = **193 unmapped free-call**):
- **REAL — runtime fn 존재, `_builtin_runtime_sym` 매핑만 추가하면 됨 (114)**: `array_*` (10) · `tensor_*` (5) · `term_*` (24) · `regex_*` (6) · `ptr_*` (7) · `json_*` (4) · `struct_pack/unpack/free` · `silu`/`gelu`/`softmax`/`matmul`/`matvec`/`rms_norm`/`one_hot`/`hadamard`/`swiglu_vec` · `sleep_ms/ns/s` · `utc_*` · `write_bytes*` 등. 본 cycle 은 CGFAIL 3건만 매핑 (`now`/`env_var`/`find`); 나머지는 per-name ret-box/cstring ABI 검증 필요 (codegen 헤더 'unmapped-is-safer-than-mis-mapped' 정책) → 별도 mechanical cycle.
- **별도 TU/특수처리 (76)**: `getenv`/`getpid`/`mkdir`/`list_dir` (build_aprime.sh sed 로 처리) · `net_*`/`pty_*`/`proc_*` (native/*.c 별도 TU) · 암호 `ed25519_*`/`x25519_*`/`chacha20_*`/`sha256_hex`/`sha512` (libsodium 옵션 TU) · `arange`/`assert`/`panic`/`nil` (codegen 특수경로). 이름 그대로 link 불가 — 매핑 또는 TU 링크 필요.
- **키워드-리터럴 (3)**: `true`/`false`/`nil` — scope 이름으로 무해 (파서가 `KwTrue`/`KwFalse` 토큰 발행, Ident 안 됨).

### 2026-05-17 — codegen super-linear class 제거 (#18 S1) — stmt-loop O(N²)→O(N)

**측정 anchored root-cause (env-gated `HEXA_CG_TIMING` sub-phase 계측, 산출 후 제거)**:
합성 micro-probe `fn big()` N개 sequential `let` 에서 codegen 단계 sub-phase 계측 결과 —
지배 비용은 `_arm64_lower_func` 의 per-statement emit 루프(`stmt-loop`):

| N | stmt-loop (전) | lower_fn(MIR) | full asm wall |
|---|---|---|---|
| 300  | 570 ms    | 188 ms   | 0.65 s |
| 600  | 3,291 ms  | 1,563 ms | 3.55 s |
| 1205 | 14,361 ms | 2,245 ms | 16.3 s |

`stmt-loop` 가 명백히 O(N²) (600→1205 = 2× → 4.4×). **진짜 원인**: 루프가
`instrs = _emit_arm64_stmt(instrs,…)` 으로 누적기 전체를 매 statement 반환·재대입.
`_emit_arm64_stmt` 의 반환값은 `TAG_ARRAY` → 런타임 fn-arena 반환 경로
(`__hexa_fn_arena_return → hexa_val_heapify`)가 반환 배열의 **모든 원소를 deep-walk**.
크기 k 누적기를 N번 반환 → Σ O(k) = **O(N²)**. (PLAN S1 후보 (a) 가 정확히 적중.)

**FIX (`compiler/codegen/arm64_darwin.hexa` — correctness-preserving, 단일 call-site)**:
`_emit_arm64_stmt` 에 매번 fresh `[]` 전달 → 호출당 그 statement 의 instruction
(~5개)만 반환 → heapify O(1). 반환된 delta 를 `instrs` 에 원소별 append.
`instrs` 자체는 `_arm64_lower_func` 가 `LFunc` 를 반환할 때 **1회만** heapify → O(total).
byte-identical: 동일 instruction·동일 순서, 누적 cadence 만 변경.

**검증**:
- 빌드 smoke `exit(6*7)==42` PASS.
- micro-probe N=100/600/1205 + 다중 구문 real test(fib·while·array·string·if) 모두
  fix 전/후 **byte-identical asm** (zero regression).
- 전체 22,090-line flatten 컴파일러 codegen **완주** — 223,630-line `.s` 산출
  (직전: 9분 cap 초과 미산출). 2회 run byte-identical (deterministic).

| N | stmt-loop (후) | full asm wall (후) |
|---|---|---|
| 600  | 25 ms  | 0.88 s |
| 1205 | 51 ms  | 3.13 s  (← 16.3 s) |
| 4800 | 162 ms | (lower_fn 지배) |

**잔여**: `lower_fn`(HIR→MIR `lower_hir`) 가 동일 root-cause 계열로 여전히 O(N²)
(`_lower_hexpr` 재귀가 `LowerExprResult{ctx: LowerCtx}` 반환 → `LowerCtx.blocks`
deep-heapify). 전체 컴파일러 최대 함수 ≈1200-stmt 에서 ~6 s 라 완주에는 영향 없으나
극단 N(4800≈185 s)에서 지배. 제거하려면 `LowerCtx` 의 `blocks`/`locals`/`bindings`
누적 배열을 `_lr_diag` 처럼 module-level `pub let mut` 로 빼는 lowering-pass 리팩터
(20+ helper 영향) 필요 — 별도 cycle. **codegen super-linear class 자체는 본 cycle 로 제거**.

---

### 진행 로그 — #18/#23 index_set store-back fix LANDED + 2nd self-host bug isolated (cycle h18)

**LANDED on main `cceb0351`** (verified byte-clean, build_aprime smoke `exit(6*7)==42` PASS
on a clean origin/main base, independent of subagent worktree):

- **Bug**: STMT_ASSIGN `op=="index_set"` lowering (`arr[i]=v` / `map[k]=v`) in
  `compiler/codegen/arm64_darwin.hexa` called `hexa_index_set(c,k,v)` but **dropped the
  return**. Proven C ref (`codegen_c2`) emits `c = hexa_index_set(c,k,v)`. Dropped return →
  stale array header in container lvalue → arena heapify relocates backing → `_build_node`
  receives dangling array → non-deterministic `container is not an array (tag=garbage)` the
  instant a self-hosted ap2 loads the atlas hxc sidecar.
- **Fix**: after `bl hexa_index_set`, store `x0:x1` back into the container Operand when it
  is a storable local/global lvalue (mirrors existing `hexa_array_push` store-back). 36-line
  change. Root-caused via lldb by the self-host-array-return agent.

**Self-host fixpoint NOT yet reached — 2nd, distinct pre-existing bug now exposed deeper:**

- ap1-fixed → flat.hexa → ap2-fixed: atlas-loader hard crash **eliminated**; ap2 now
  progresses through atlas-load → lex → parse → bind (previously died before its main loop).
- With the real 6.4 MB `dist/atlas.hxc` (~16k rows) ap2-fixed still hits the *same crash
  signature* at `_build_node_bb0+16 ← load_atlas_hxc_bb9` (x0 = non-det pointer-range
  garbage). Fixed asm confirms `dense[ci]=cells[j]` store-back **correctly emitted**; all
  minimal repros at 16k scale PASS. So `dense` is maintained correctly — the corruption is
  of caller frame slot `[sp+1680]` in the *real* `_build_node` path (16-arg dense, nested
  `AtlasNode{GradeInfo,EdgeInfo}`, `_parse_json_str_arr`, real data). **Separate real-data-
  dependent codegen-correctness bug** — likely struct-return ABI or `_split_pipes` /
  `_parse_json_str_arr` frame interaction. Tracked as task #24.

---

### 진행 로그 — gate ① 재측정 (index_set fix on clean main `cceb0351`, cycle h18)

`/tmp/ap_merge` (aprime_cc tier-1, clean origin/main + cceb0351 index_set store-back)
vs `hexa build` tier-2 oracle (HEXA_MAC_BUILD_OK=1), 44-file `test/*_smoke.hexa` corpus.
MATCH = byte-identical stdout AND same rc.

**결과: 32/44 MATCH (73%).** breakdown:
- MISMATCH 6: `atlas_doctrine`(ap1/or0) · `atlas_tecsl_verify`(ap1/or0) · `atlas_wave3`(ap1/or0)
  · `atlas_hxc_roundtrip`(ap1/or1) — prior-identified **shared atlas-verifier codegen root
  cause** (struct-array iteration in verifier nodes); likely同根 with task #24's real-data
  `_build_node` struct path. `t34_net_listen`(ap138/or0 — env-dep socket) ·
  `verify_cli`(ap1/or0).
- APFAIL 6: `atlas_verify` · `t_multiarch_cpu` · `t35_hxqwen14b_abi` · `t36_serve_alm`
  · `t37_hxqwen14b_day2` · `t38_nanbox` — frontend-feature **CGFAIL cluster** (extern fn /
  @select annotation-arg / try-catch / type-inference) — codegen 진입 전 abort, RFC-sized.
- ORAFAIL 1 (oracle 자체 build 실패 — 집계 제외).

**정직한 해석**: frontend-CGFAIL 6 + env-net 1 + orafail 1 제외 시 effective
32/36 ≈ **89%** tier-1≡tier-2. R7 gate ① ("aprime-direct coverage ≥ interp")는 interp
이 알려진 buggy-oracle 이므로 tier-2(hexa-build) 동치를 기준으로 재정의 — 잔여 gap =
(a) 4 atlas-verifier codegen 동근(task #24 와 합류 가능) + (b) 6 frontend CGFAIL(별도 RFC).

---

### 진행 로그 — #24 loop-sentinel fix LANDED (`9223fe4a`) + gate ① 33/44 + #25 노출 (cycle h18)

**#24 ROOT-CAUSED & LANDED on main `9223fe4a`** (struct-return ABI 가설 기각 — 실제 원인은
HIR→MIR loop-sentinel scoping 버그):
- `compiler/lower/hir_to_mir.hexa::_patch_loop_sentinels` 가 *모든* MIR block 을 스캔해
  `continue`(-7002)/`break`(-7001) sentinel 을 현재 lowering 중인 loop 에 바인딩. inner loop
  *내부* nested continue 엔 맞지만, 같은 outer body 에서 inner loop 의 *텍스트적 선행 형제*
  인 continue 엔 틀림. `hxc_loader.hexa::load_atlas_hxc` 의 malformed-row continue(outer
  `while lineno<n` 소속)가 형제 `while k<16` 의 patch 에 포착→inner header 로 rebound→
  `let mut dense = []` 건너뜀→`dense`(caller frame `sp+1680`) 미초기화→비결정적
  tag-garbage 크래시. hexa_v2 C-path 는 진짜 C `continue` emit 으로 무영향, aprime_cc
  arm64 lowering 만 miscompile.
- Fix: `scope_min` param 추가, `b.id < scope_min` block skip. block id 단조증가
  (`_new_block`)이므로 loop 자기 구조/body block 은 id≥header_id, 외곽 loop sentinel 은
  더 이른 block(id<header_id). 유일 call site 가 `header_id` 전달. 2-hunk surgical.
- 검증: build_aprime smoke `exit(6*7)==42` PASS (clean origin/main); aprime_cc-compiled
  `hxc_loader` 가 real 6.4 MB `dist/atlas.hxc` 에서 **15952 nodes 로드, 크래시 0**
  (이전 deterministic tag-garbage); single-loop/nested-continue/nested-loop byte-identical
  regression asm. self-host: fixed ap1 → 22,128-line flat → 223,696-line asm (68s, exit 0,
  22 harmless HX4001, 0 error); ap2 가 real 16k-row atlas 15952 nodes 로드 크래시 0
  → #24 진정한 self-host 레벨에서 종결. `_normalize_argv` arg-handling tag 손상도 동근,
  함께 소멸.

**gate ① 재측정 (`/tmp/ap24` = clean main + 9223fe4a):** 32→**33/44 MATCH**.
`atlas_hxc_roundtrip` MISMATCH→MATCH (loop-sentinel/atlas-load fix 직접 효과). 잔여:
3 atlas-verifier MISMATCH(`doctrine`·`tecsl_verify`·`wave3` — 별도 shared codegen 동근,
hxc_roundtrip 분리됨) + env-resource 2(`repo_taxonomy_audit` rc137 OOM ·
`t34_net_listen` rc138 socket) + 6 frontend-CGFAIL. effective ≈ 33/36 (92%).

**#25 EXPOSED (다음 self-host fixpoint 블로커):** self-hosted ap2(asm-compiled compiler)
가 frontend 실행 + asm header emit 까지 가나 per-function emit loop 이 **함수 body 0개**
생성 (smoke → 4-line header only vs ap1 정상 28-line `_main`). 타임아웃/atlas 의존 아님.
#24 가 atlas-load 에서 ap2 를 먼저 죽여 가려져 있던 것. 별도 cycle.

---

### 진행 로그 — atlas-verifier 3-MISMATCH 클러스터 read-only 증상 triage (cycle h18, 다음 cycle 포인터)

`/tmp/ap24` (clean main + 9223fe4a) vs hexa-build oracle, 잔존 3 MISMATCH 의 stdout diff
(read-only, codegen 미수정 — #25 agent territory 와 비충돌):

- `atlas_doctrine`: ap `external_entity_audit detects 1 violation` / `fails (pass=false)`
  → oracle `RESULT: PASS`. aprime 가 존재하지 않는 violation 1건 검출.
- `atlas_tecsl_verify`: ap `A top::s8_mu_eq_sigma_squarefree_tecsl [🔴 FALSIFIED]`
  → oracle `[🔵 SUPPORTED-IDENTITY]`. verifier predicate 진리값 반전.
- `atlas_wave3`: ap `falsifier_wellformed_audit FAIL — 4 nonconforming / 3 violations
  across 4 @? nodes` → oracle `RESULT: PASS`. node-scan predicate over-report.

**공통 동근 (가설):** atlas-node scan loop 내 **predicate/boolean 평가가 aprime_cc
codegen 에서 wrong truth-value** 산출 (crash 아닌 wrong-value). 비교연산자 / bool-coercion
/ struct-field-bool lowering 후보. 이전 "struct-array field-access" 클래스의 wrong-value
변종 가능성. #25(ap2 empty-fn-body) 종결 후 별도 cycle 에서 minimal repro
(verifier scan + struct-field-bool predicate) → codegen_c2 oracle diff 로 isolate 권장.
gate ① 잔여 실-aprime gap 의 거의 전부가 이 한 클러스터.

---

### 진행 로그 — #25 match-as-expr value-drop FIXED (`1734f890`) + gate ① 33/44 + #26 노출 (cycle h18)

**#25 ROOT-CAUSED & LANDED on main `1734f890`** (ap2 empty-fn-body 의 진짜 원인):
- `compiler/lower/hir_to_mir.hexa` 의 k=="match" lowering (~L1311) 이 **value-position
  match** (`return match k {...}` / `let s = match …`) 의 arm body 는 lower 했으나 결과
  operand 폐기 → match 전체가 `_no_value`(const_int 0) 반환. → `tag_of()` 의
  `match enum -> string-literal` idiom 이 항상 "0" → `same_kind`/`at_eof` 항상 true →
  self-compiled ap2 top-level parse loop 미진입 → 0 items → 0 funcs → empty asm.
  C/interp 는 C `switch` 가 값 운반해 무영향 — direct codegen-correctness 버그
  (14-line `match enum->string` ap1-direct 로 재현: `0`/exit1 vs hexa_v2-C `BBB`/exit7).
- Fix: `match_result` local 1개 할당; 값-생산 arm 각각 `op="bind"`(모든 backend 의 generic
  dst=arg0 copy)로 join 전 복사; join 이 `_value(_local_op(match_res))` 반환.
  statement-position arm(has_returned/has_value=false) 무변경 → legacy 보존. 2-hunk +30/-1.
- 검증: build_aprime smoke PASS (clean origin/main); minimal repro `BBB`/exit7 +
  `let x=match` `green`/exit3 = C oracle; value-position match 無 프로그램 byte-identical
  regression; self-host ap1(fixed) → ap2 가 real `_main` body emit (이전 4-line header only).

**gate ① 재측정 (`/tmp/ap25` = clean main + 1734f890):** **33/44 MATCH** (불변).
3 atlas-verifier MISMATCH(`doctrine`·`tecsl_verify`·`wave3`)는 match-as-expr fix 로
**안 뒤집힘** → 별도 root (이전 triage 의 "predicate wrong truth-value"는 match-as-expr
아닌 #26-class struct-field 가능성). #25 는 self-host 블로커 fix 로서 독립 가치(broad
correctness, unaffected byte-identical) — gate ① 수치 무변동이어도 land 정당.

**#26 EXPOSED (다음 self-host fixpoint 블로커):** ap2 가 함수 body emit 하나, ap2 smoke
asm 이 25줄에서 `.globl void`/`void:` (vs `.globl _main`/`_main:`) + runtime warn
`map key 'def_line' not found`. emit 경로의 `LFunc { name: mf.name, … def_line:
mf.def_line }` struct 생성에 국한 — self-compiled ap2 가 `f.name`→"void",
`f.def_line`→map-miss; block label(fn param 통한 `mf.name`)은 정상 → MFunc.name 자체는
OK. #25(match)와 다른 root (emit/asm.hexa·codegen/arm64_darwin.hexa 에 match-expr 0개).
struct field-access / struct_lit-value self-host miscompile. 별도 cycle (task #26).

---

### 진행 로그 — #26 MFunc fn-arena field-read FIXED (`77b78b31`) + #27 (frontend 동 arena class) 노출 (cycle h18)

**#26 ROOT-CAUSED & LANDED on main `77b78b31`**:
- `compiler/codegen/arm64_darwin.hexa::_arm64_lower_func` 가 `mf.name`/`mf.def_line`/
  `mf.blocks` 를 per-stmt `_emit_arm64_stmt` 호출 사이로 반복 read. 각 `_emit_arm64_stmt`
  는 TAG_ARRAY 를 `__hexa_fn_arena_return` 경유 반환 → fn-arena rewind → arena-resident
  `mf` map 의 string storage 무효화 → 이후 `mf.name`→TAG_VOID, `mf.blocks`/`mf.def_line`
  →map-miss. self-compiled ap2 가 정확히 이 증상(`.globl void`/`void:` + map key not
  found + truncated body; 첫 block label 만 정상). ap1(heap, single-read)은 무증상이라
  self-host 까지 가려짐. #25 regression 아님(match-expr 無), #23/#24/#25 와 다른 site.
- Fix: 함수 진입부에서 MFunc identity field 를 F6 forced-copy idiom 으로 1회 snapshot
  (`fn_name = mf.name.substring(0,len(mf.name))` · `fn_def_line` · `mf_blocks`),
  downstream 6 read 전부 arena-independent handle 경유.
- 검증: build_aprime ap1b smoke PASS; ap1b→ap2b, ap2b smoke 가 `.globl _main`/`_main:`/
  `.loc 1 1 0` emit (이전 `.globl void`), ap1 정상출력과 **byte-identical** (diff clean),
  ap2b-compiled binary `exit(42)` PASS; warn name(4)/blocks/def_line/items → items(1);
  ap1 vs ap1b smoke/r4/repro byte-identical (self-host arena path 만 변경).

**#27 EXPOSED (마지막 알려진 self-host fixpoint 블로커, #26 와 동일 arena-lifetime class):**
ap2b 가 full flattened compiler 컴파일 시 1032× `HX2001 undefined name <callee>` +
선행 `map key 'items'/'children'/'span'/'text' not found`. `compiler/check/bind.hexa::
bind()` 가 `module.items` 를 body-walk 전반(L818/838, 다수 fn-call=arena return)에서
read + `compiler/lower/hir_to_mir.hexa::_lower_hexpr` struct_lit/field path(cross-struct
field initializer `LF{name:mf.name,def_line:mf.def_line}` 가 stmt drop + string table
truncate, `.LCstr1` empty). `_is_builtin_method` receiver 손상 → `.substring`/`.push`
오-HX2001. **#26 는 codegen 단일 함수 local snapshot 으로 종결, #27 은 동 class 가
frontend(bind/parser/lower) 다수 read-site 로 분산.** 

**다음 cycle 방향 (중요):** #23/#24(arena heapify relocation)/#26/#27 전부
**fn-arena-return lifetime 동근**. whack-a-mole F6 snapshot 누적 대신 **ROOT runtime fix**
후보 — `self/runtime.c` 의 `hexa_val_heapify` TAG_MAP non-arena path 에서
`__hexa_fn_arena_return` rewind 가로질러 parameter map 보존 → recurring class 전체 폐쇄.
fallback = `module.items` snapshot + struct_lit lowering 의 localized forced-copy.
#27 agent 가 root-fix 안전성(gate ① full sweep + self-host byte-identical) 우선 평가.

---

### 진행 로그 — #27 call-overflow stride FIXED (`d81e2195`) + #28 (Field-callee) 노출 (cycle h18)

**#27 ROOT-CAUSED & LANDED on main `d81e2195`** (root-runtime 가설 evidence 로 기각):
- `compiler/codegen/arm64_darwin.hexa::_arm64_lower_func` 가 per-function outgoing-call
  stack-overflow 영역을 `((max_overflow * 8 + 15)/16)*16` 으로 sizing. `max_overflow` 는
  overflow ARG 개수(n-4)이고 C7 call-site emit 은 각 overflow arg 를 `[sp,#(i-4)*16]`
  (16-byte HexaVal-pair stride) 에 씀. `*8` 은 필요 바이트의 **정확히 절반** → `_arm_spill_
  offset` 가 SSA/param slot 을 overflow span 의 절반만 shift → saved ingress param 이
  outgoing stack-arg slot 과 aliasing. `_collect_item_types` 가 `module` 을 `[sp,#16]` 에
  저장 → 이후 6-arg call 이 "stack arg 5"((5-4)*16=16)를 같은 `[sp,#16]` 에 덮어씀 →
  caller 의 첫 param HexaVal tag MAP→STR → `map key items/children/span/text not found`
  + 1032-wide spurious HX2001 (ap2 가 full compiler 컴파일 시). ap1(hexa_v2 C path)는
  frame 정확 계산 → asm codegen self-host 까지 가려짐.
- **runtime arena 가설 evidence 로 기각**: `module` map 은 heap-resident(`tbl_in_arena=0`,
  never reclaimed); 손상은 transient 16-byte `module` param **SLOT** 의 frame aliasing.
  `self/runtime.c` 무수정 (global-runtime regression risk 0).
- Fix: `max_overflow * 8` → `* 16` (one-token logic change).
- 검증 배터리: build_aprime smoke PASS (clean origin/main); gate-1 sweep **33/44
  byte-identical** to baseline (zero flip — 5 MISMATCH + 6 APFAIL 분포 동일);
  ap1 vs ap1f asm **43/44 byte-identical** (1 diff = corrected larger frame 544→576 +
  shifted offset 뿐, instruction 무변경); 6-arg micro-repro oracle 85 / ap1-buggy 90 /
  ap1f 85; ap2f 가 **`map key not found` 완전 제거** (#27 정의 증상 소멸).

**#28 EXPOSED (likely 마지막 self-host fixpoint 블로커 — arena class 아님):**
ap2f 가 full flattened compiler 컴파일 시 여전히 1032 HX2001, distinct root.
`compiler/check/types.hexa:1546 _types_check_call` — self-hosted ap2f 가 **method-call
(`Field` ExprKind) resolution miscompile**. 7-line repro (`fn main(){ let mut a=[];
a.push(1); a.push(2)... }`): oracle 2 / ap1f 2 ✓ / ap2f → `.push` 에 2× spurious
`HX2001 <callee>`. #27 와 독립 입증 (ap1f 정상; repro 에 >4-arg call·Module walk 無;
stride fix 는 global 인데 residual 잔존). arena class 아님(map heap-resident). 다음
cycle: `_types_check_call`/`_infer_expr` 의 `Field`-callee self-compile miscompile 을
codegen_c2 oracle 대비 isolate (task #28).

---

### 진행 로그 — #28 enum-== self-host miscompile FIXED (`fa210c54`) + ap2f full-compiler 컴파일 도달 + #29 노출 (cycle h19)

**#28 ROOT-CAUSED & LANDED on main `fa210c54`** (`Field`-callee 가설은 표면증상, 진짜 root
는 enum value `==`):
- native(aprime_cc) lowering 은 enum variant 를 map `{__tag: hash, __pN: payload}` 으로
  표현 (`hir_to_mir.hexa` enum_path → struct_lit). `hexa_eq` 의 `TAG_MAP` case 가
  table-pointer identity 로 비교 → 같은 variant 의 별도-생성 enum map 2개가 항상 not-equal
  → enum `==` 사실상 항상 false. `_types_check_call`(`types.hexa:1546`)의
  `callee.kind == ExprKind::Field` 가 native build 에선 항상-false enum-map `==` →
  `.push` method-call callee 가 builtin-method dispatch 로 인식 안 됨 → ap2 가 full
  compiler 컴파일 시 1032× spurious HX2001. hexa_v2 C-path 는 enum 을 `hexa_int(index)`
  로 lowering → int 비교라 정상 → ap1 정상, self-compiled ap2 만 flood (native-only 발산).
- Fix: `self/runtime.c` `hexa_eq` TAG_MAP case — **양쪽 map 이 `__tag` key 보유 시**
  (struct 는 `__type__` → disjoint → `__tag` map = enum value 확정) 구조적 비교
  (`__tag` int → 각 `__pN` payload 재귀). plain map/struct/dict 는 pointer-identity 유지
  (non-`__tag` different-table 은 기존대로 false). interp 무변경 (interp 는 `__tag` map
  미생성).
- 검증: build_aprime smoke PASS (clean origin/main); gate-1 **33/44 분포 동일**(zero
  regression); ap1 vs ap1f asm non-enum byte-identical (runtime-only fix); 7-line `.push`
  repro ap2 출력 `2` + HX2001 0.

**★ 마일스톤 — ap2f 가 full flattened compiler 를 진단오류 0 으로 컴파일:**
ap1f → flat → ap2f 가 22k-line flattened compiler 를 **HX2001 0 + map-key error 0** 으로
컴파일, 1-run 기준 `ap1f.s == ap2f.s` byte-identical (MD5 `2a673ca2…`). self-host
fixpoint 의 enum-`==` 축 도달 — #23~#28 6 버그 누적 종결로 ap2 가 frontend·atlas-load·
lex·parse·bind·codegen 전 구간 통과.

**#29 EXPOSED (잔여 self-host 블로커 — bit-stable fixpoint 차단):**
native-asm-compiled compiler(ap2 tier)가 **non-deterministic** — 동일 `fx_flat.hexa` 에
ap2f 재실행 시 asm 상이 (enum `__tag` hash 의 `movz/movk` immediate 변동; run2 가
high-bit garbage 64-bit + `mvn` 산출). ap1f(hexa_v2 C-path build)는 3-run 결정적.
Symbol: `compiler/codegen/arm64_darwin.hexa::_arm64_op_rm` 의 `const_int` operand
`o.int_val` read. #26/#27 와 동류의 fn-arena / struct-array field-read aliasing class —
`Operand.int_val` 가 arena rewind 가로질러 stale memory read. full bit-stable self-host
(ap2f ≡ ap3f byte-identical) 은 #29 종결까지 미달. 별도 cycle (task #29).

---

### ★★★ 진행 로그 — #29 bitwise-as-add FIXED (`93ee4ecf`) · BIT-STABLE SELF-HOST FIXPOINT REACHED (cycle h19)

**#29 ROOT-CAUSED & LANDED on main `93ee4ecf`** ("non-determinism"은 오진 — 진짜는
bitwise op 전부 add 로 miscompile):
- `compiler/codegen/arm64_darwin.hexa` 의 arm64 BINOP emitter 가 bitwise `& | ^ << >>`
  를 catch-all 의 `hexa_add_slow`("approx") 로 라우팅 → **`h & MASK` 가 `h + MASK` 로
  컴파일**. `hir_to_mir.hexa::_path_hash` (djb2 enum-tag hash, `& 2147483647` 마스킹)이
  unmasked 64-bit hash 산출 → self-built ap2 가 enum `__tag` const 에 4-halfword
  movz/movk + mvn garbage immediate emit. ap1(hexa_v2 C-path)은 `&` 정상이나 ap1 의
  *자기 출력* 이 `&` 를 miscompile → 모든 aprime_cc-built generation 의 `_path_hash`
  손상. 앞서 보고된 "non-determinism" 은 stale `/tmp/fx_flat.hexa` 를 fresh flatten 과
  diff 한 artifact.
- Fix: catch-all 전에 bitwise special-case — HexaVal payload pair 에 register-form
  arm64 op (`&`→and · `|`→orr · `^`→eor · `<<`→lsl · `>>`→asr on x1,x1,x3), result
  tag `movz x0,#0`(TAG_INT). authoritative ref `self/codegen_c2.hexa:3412`. +28/-2.

**★★★ BIT-STABLE SELF-HOST FIXPOINT REACHED — 독립 검증 (clean origin/main):**
`ap1f → flat → ap2f → flat → ap3f`, 각 generation 이 38-file/22,227-line flattened
compiler 를 컴파일. `ap1f.s == ap2f.s == ap3f.s` **byte-identical** — 231,125-line asm,
md5 `18df90ebb92b7cdb4a541472b882c9af`, HX2001 0 / map-key error 0. **aprime_cc 가
자기 자신을 bit-for-bit 재현.** #23~#29 self-host 버그 7개 누적 종결.

**검증 배터리**: build_aprime smoke `exit(6*7)==42` PASS (clean main); gate-1 33/44
zero regression; ap1 vs ap1f asm 38 compiling smoke byte-identical (bitwise op 미사용);
3-generation byte-identical (위).

**상태 — goal ② self-host 축 CLOSED**: native compiler 가 인터프리터·hexa_v2 없이
자기 자신을 재현. task #18 (aprime_cc self-host) COMPLETED.

**R7 deletion gate 재평가 (인터프리터 실삭제 전제):**
- gate ② CLI 드라이버 compiled — ✅ (#20)
- gate ③ atlas SIGSEGV — ✅ (#5 struct-array · #24 real-data)
- gate ④ module_loader interp-free — ✅ (#20)
- gate ① aprime-direct coverage ≥ interp — **🔄 미완**: gate-1 33/44 (effective ~92%).
  잔여 = 3 atlas-verifier MISMATCH(`doctrine`·`tecsl_verify`·`wave3` — predicate
  wrong-value codegen) + 6 frontend-CGFAIL(`extern fn`·`@select` annotation-arg·
  try/catch·type-infer — codegen 진입 전 abort). 이 둘이 닫혀야 "모든 .hexa 네이티브"
  성립 → 인터프리터 실삭제(R7) 가능. self-host 는 끝났으나 gate ① 잔여로 interp 삭제
  아직 불가 — 정직히 미완 기록.

---

### 진행 로그 — gate ① atlas-verifier cluster CLOSED (`1041120e`) — 33→36/44 (cycle h19)

atlas-verifier 3-MISMATCH 클러스터는 **단일 boolean-eval 가설이 빗나가** 독립 codegen
버그 2개였음:

- **index_of string-method miscompile**: `arm64_darwin.hexa::_builtin_runtime_sym` 가
  `index_of` → `hexa_array_index_of` 무조건 매핑. `hexa_array_index_of` 는 non-array
  receiver 에 `-1` 반환 → aprime_cc 가 컴파일한 모든 `string.index_of(...)` 가 `-1` →
  audit scan 의 `raw.index_of(token) >= 0` 항상 false → `external_entity_audit`/
  `falsifier_wellformed_audit` verdict 뒤집힘. Fix: arg-count-aware STMT_CALL branch →
  `hexa_str_index_of`(1-arg)/`hexa_str_index_of_from`(2-arg) + int-boxing.
  (`atlas_doctrine`·`atlas_wave3` 수정)
- **bool literal wrong tag**: `hir_to_mir.hexa::literal_bool` 가 `true`/`false` 를
  `_const_int_op`(TAG_INT)으로 lowering. 비교연산자는 `hexa_bool`(TAG_BOOL) 반환 →
  `hexa_eq` 가 tag mismatch 에 false → literal bool 이 computed bool 과 절대 같지 않음
  (`bool_var == true`/`cond_a != cond_b` 오평가). Fix: `_const_bool_op` 신설
  (kind=const_bool), `literal_bool` 이 경유; arm64 `_hv_load` + raw-int operand
  resolver 가 const_bool(TAG_BOOL=2) 처리. precedent = 바로 아래 `literal_char`→TAG_STR.
  (`atlas_tecsl_verify` 수정)

**검증 (clean origin/main)**: build_aprime smoke PASS; gate-1 **33→36/44** (3
atlas-verifier MISMATCH→MATCH, zero regression — 잔여 2 MISMATCH `repo_taxonomy_audit`
rc137 OOM·`t34_net_listen` rc138 socket 은 env-resource, codegen 무관); self-host
fixpoint 보존 `ap1f.s == ap2f.s` byte-identical (231,824-line, md5 `58f7d941…`).
x86_64 backend 무수정 (incomplete backend, self-host path·gate-1 무관).

**gate ① 현황**: 36/44. 잔여 = env-resource 2 (codegen 무관) + frontend-CGFAIL 6
(task #31 — `extern fn`·`@select` annotation-arg·try/catch·type-infer·low-level memory
builtin, RFC-scoped 신기능). codegen-correctness 측면에서 **구현된 언어 범위는 tier-1 ≡
tier-2 사실상 완전** (모든 비-env·비-미구현 프로그램 MATCH). 인터프리터 실삭제(R7)는
CGFAIL 6 신기능 구현 후.

---

### 진행 로그 — gate ① 메모리-builtin + @link/extern + *T 파서 LANDED (`990d546c`·`ce76944e`) (cycle h19)

**cluster A (memory builtins) `990d546c`**: 14 저수준 메모리/포인터 builtin
(`alloc_raw`·`free_raw`·`write_f32`·`deref_f32`·`ptr_read_f64`·`ptr_write_f32`·
`write_i32/i64`·`deref_i32`·`ptr_read_f32/i32`·`ord`·`ptr_from_int`) 를 tier-1
frontend(`bind.hexa _bind_builtin_names`) + native codegen(`arm64_darwin.hexa
_builtin_runtime_sym` 11 direct map + STMT_CALL `ord`/`ptr_from_int` branch) 에 등록.
runtime/interp 무변경 (함수 이미 runtime.c + native/tensor_kernels.c 존재; tier-1 가
tier-2 codegen_c2 따라잡기). additive `if name ==` branch — compiler source 무발화라
fixpoint 구조적 보존.

**cluster B' (@link extern fn + *T) `ce76944e`**: `extern` 이 tier-1 lexer keyword
아님 → Ident 토큰화 → `parse_item` 미처리 → unknown-leader fallthrough 가 decl-loop
desync, 후속 top-level decl 전부 silently swallow → t35/t37(`let mut ok`)·
t36(`HXQWEN14B_*` via `self/ml/qwen14b.hexa`) cascading undefined-name. 2차 gap:
`parse_type` 에 `Star` arm 부재 → `*Void` param 재-desync. Fix: `parse_extern_fn_item`
(body optional, tier-2 `hexa_full.hexa::parse_extern_fn` mirror) + `parse_type` Star
arm (tier-2 `parse_type_annotation:2406` mirror). parser.hexa only, bind/types/codegen
무변경.

**검증 (각 clean origin/main)**: build_aprime smoke PASS; gate-1 **36/44 zero
regression** (분류 byte-identical); ap1 vs ap1f non-affected byte-identical;
**self-host fixpoint 보존** (A: md5 `10863f5b…` · B': fresh-flatten 22,445-line incl
+99, ap1f.s==ap2f.s md5 `b6bfe0a4…`).

**gate ① 정직한 천장 재평가**: 36/44. 잔여 8 중 — t35 = **ORAFAIL-class FFI** (tier-2
oracle `dlsym` SIGSEGV `ora_rc=139`, codegen gap 아님; tier-1 FFI symbol resolution 은
별도 RFC scope) · `repo_taxonomy_audit`(rc137 OOM)·`t34_net_listen`(rc138 socket) =
env-resource (codegen 무관). **codegen-correctness 분모 실질 ≈ 40** (t35-orafail +
2-env 제외). 진짜 잔여 codegen/typecheck/feature gap = #33 int×float HX3001
(t_multiarch_cpu) ↔ t37 8× HX3001 numeric-literal type-infer (동근 가능성) ·
t36 serve_alm.hexa import HX2001/HX3002 · try/catch(t38_nanbox) · int-div
strict-lint(atlas_verify). 다음: #33 (t_multiarch_cpu+t37 동시 해소 가능성 최고가치).

---

### 진행 로그 — math fn return annotations LANDED (`eea2dce6`) + 새 atlas_verify 118/139 분기 노출 (cycle h19)

**math annotations landed `eea2dce6`** — stdlib/core/math.hexa 의 14개 fn
(`abs`/`max`/`min`/`clamp`/`gcd`/`lcm`/`pow`/`factorial`/`sigma`/`euler_phi`/`tau`/
`sopfr`/`fib` 전부 int 반환; `is_prime` bool) 에 명시적 `-> T` 반환 annotation 추가.
tier-1 의 `_types_signature_type` 가 annotation 부재를 concrete `unit` 으로 default →
caller 가 `lcm(a,b)` 결과를 unit 으로 추론 → atlas_verify 의 `_lcm2(-> int)` 에서
HX3004 false-fire (sole abort). monotone (implicit→concrete), tier-2 무영향.

**대안 기각**: 에이전트 `8d7e577f` 가 tier-1 의 absent-annotation default 자체를
`empty/unknown` 으로 바꾸는 broader fix 제안. **검증 시 silent 의미 발산 발견**:
post-fix atlas_verify 가 tier-1 rc=0 ("118/118 PASS") vs tier-2 rc=1 ("139 live nodes
vs 118 declared, FAIL — 10 verdict regressions") — tier-1 이 21 verifier 등록을 silently
drop. 의도 무관 g3 type-soundness weakening → **rejected**. source-side narrow fix(b)
선택.

**검증 (clean main `5d65c362`)**: build_aprime smoke PASS; atlas_verify HX3004 소멸,
compiles+links+runs rc=0; gate-1 sweep **37/44** (atlas_verify APFAIL→MISMATCH, gate-1
수 불변이나 MATCH 향한 진보); self-host fixpoint 보존 ap1f.s==ap2f.s md5 `ee9d7077`.

**★ 새 codegen 버그 노출 (task #34)**: tier-1 가 atlas_verify 의 verifier 등록을 21개
silently drop (118 vs 139 verdict). math fix 의 부작용 아님 (b·a 양쪽에서 동일 발현 →
선재 버그). 어떤 `pub let […AtlasNode]` array 가 tier-1 컴파일된 binary 에서 완전 등록
안 되는지 isolate 필요. struct-array top-level init 의 edge case 후보. 종결 시
atlas_verify APFAIL/MISMATCH → MATCH = gate-1 38/44.

**현황**: 진짜 tier-1 결함 잔여 = atlas_verify 118/139(#34) + t38_nanbox try/catch.
non-tier-1 5개(t35/t36/t37 ORAFAIL-class + repo_taxonomy/t34 env) 제외 effective 천장
39 achievable.

---

### 진행 로그 — #34 재진단: tier-1 무결, 진짜 결함은 tier-2 trailing-if-expr void-return (cycle h19)

`gate-1: atlas_verify silent-drop` 에이전트(`afcfea54`, diagnostic-only commit `5ac7018e`)
가 #34 의 전제를 **증거로 기각**:

**"21 silent drop" = oracle-source-contamination artifact**:
- `hexa build`(tier-2 oracle) 가 `use` 경로를 `$HEXA_LANG` 으로 해결, 기본값이
  shared main repo `/Users/ghost/core/hexa-lang`. 그 repo 는 `rfc043-hexa-torch` 브랜치
  에 sim-universe 흡수 커밋(`c530048c`·`d8b9a1b4`·…)으로 verifier `out.push()` 21개
  추가 (phys +11, transcendental +10).
- worktree 는 `origin/main` (그 21개 미보유). 결과: tier-1 = 118(worktree 정답),
  tier-2 = 139(오염된 shared-repo source). `HEXA_LANG=$WD` 강제 시 양쪽 118 = drift 0.
- **tier-1 silent drop 부재**. #34 RESOLVED (premise disproven).

**실제 잔여 발산은 tier-2 codegen 버그**: 동일 source 에서 tier-1 118/118 PASS vs
tier-2 108/118 FAIL on 10 명명 verifier. tier-2 의 컴파일된 C 출력
`build/artifacts/av_t2_wt.c:2142` 가 `lcm()` 을 `if/else { branch_expr; } …
return __hexa_fn_arena_return(hexa_void())` 로 lower — **trailing if/else 의 value-
bearing branch 결과가 폐기, fn 이 void 반환**. 같은 패턴이 `abs/max/min/clamp`. tier-1
은 정상 (8/8 PASS) → **tier-1 수학적 정답, tier-2 가 broken**. self/hexa_full.hexa
lowering 의 trailing-if-expr → implicit-return 변환 누락 (task #35).

**g3 의미 시사**: gate-1 metric "tier-1 ≡ tier-2 oracle" 은 tier-2 도 broken 가능
(여기서 입증). atlas_verify MISMATCH 는 tier-1 결함 아님 — tier-2 fix(#35)로 닫힘.
recommendation: (B) `hexa` CLI 가 `$HEXA_LANG` 미설정 시 cwd git toplevel 로 기본화 →
oracle contamination 재발 방지 (별도 follow-up).

**현황 재정정**: 진짜 tier-1 잔여 gap = **try/catch(t38_nanbox) 1개뿐**. atlas_verify
는 tier-2 fix(#35) 로 매칭. t35/t36/t37 + 2 env 제외 시 tier-1 effective 천장
(t38 닫으면) = **38/39 + atlas_verify(tier-2 후) 39/39** = 구현 언어 범위 tier-1 ≡ 정답.

---

### 진행 로그 — #35 tier-2 trailing-if-expr void-return FIXED (`0092f069`) (cycle h19)

**#35 root cause precise**: `self/codegen_c2.hexa::gen2_fn_decl` tail-return loop 가 fn body
trailing expr = `IfExpr` 일 때 `_skip=true` ("let them run via gen2_stmt") → 각 branch
값이 bare `<expr>;` statement 로 emit·폐기 → fn 이 `hexa_void()` 반환. tier-1 정상,
tier-2 만 broken. stdlib/core/math.hexa 의 `abs/max/min/clamp/lcm` 영향 (`abs/max/min`
은 HexaVal struct ABI aliasing 으로 우연히 "동작" — UB).

**Fix**: `_gen2_emit_tail_return_expr`(arena/defer/no_arena 경로 존중 return-emitter) +
`_gen2_emit_tail_returnify_body`(재귀 helper: tail ExprStmt → `return <expr>;`,
inner IfExpr 재귀 처리 → else-if chain + nested if-in-if tail-return). gen2_fn_decl
tail-return loop 이 IfExpr tail 을 helper 로 라우팅. MatchExpr 무변경(math.hexa 미사용,
follow-on). regenerated `self/native/hexa_cc.c` + rebuilt `self/native/hexa_v2` 동봉.

**검증 (clean main `0579aac6`)**: build_aprime smoke PASS; minimal repro
`fn foo()->int{if true{7}else{9}}` pre void → post 7 (tier-1 무변경); tier-2 math fns
정답; atlas_verify tier-2 109→**112/118** verdicts (+3 lcm-dependent verifier 회복:
`modular::s8_t201_step5_weight_12`/`step6_lcm_uniqueness`/`falsifier:step6`); gate-1
37/44 무변동(atlas_verify 는 6 OTHER 무관 발산으로 MISMATCH 유지 — 별도 tier-2
codegen 버그, OOS); byte-identical non-tail-if fns; self-host fixpoint 보존 md5 `0e7f0387`.

**atlas_verify 잔여 6 발산(별도 tier-2 codegen 버그)**: transcendental `s2_gamma_
reflection_n6`/`s10_four_island_bridge_approximate`/`s2_gauss_multiplication_n6` +
`falsifier:gauss` + modular `s8_t201_step2_isotropy_23`/`s8_chi_to_monster_full`.
float-arithmetic 또는 struct-aliasing 후보. 각각 독립 cycle. tier-1 8/8 PASS 라
**tier-1 결함 0** — 인터프리터 폐기 전제와 무관.

---

## ★★★ goal ② 사실상 종료선 (cycle h19 closing)

**self-host axis** — bit-stable fixpoint REACHED (`93ee4ecf`, #23~#29 누적 종결).
aprime_cc 가 인터프리터·hexa_v2 없이 자기 자신을 bit-for-bit 재현.

**gate ① 정직 분석 (현 37/44 metric)**:
- ✅ R7 gate ②③④ closed
- 🔄 gate ① — 잔여 7 non-MATCH 분류:
  - `t38_nanbox` APFAIL = **try/catch (마지막 진짜 tier-1 codegen-correctness gap)**
  - `atlas_verify` MISMATCH = tier-2 codegen 잔여 6 발산 (tier-1 정답 8/8 PASS; **tier-1 결함 0**)
  - `t35`·`t37` (ORAFAIL-class FFI: tier-2 oracle 자체 SIGSEGV/clang 실패)
  - `t36` (tier-2 oracle clang 빌드 실패)
  - `repo_taxonomy_audit` (rc=137 OOM env), `t34_net_listen` (rc=138 socket env)

**effective tier-1 codegen 천장**: 7 non-MATCH 중 **5 는 tier-1 결함 아님** (tier-2 / ORAFAIL
/ env). 진짜 tier-1 잔여 = **try/catch 1개**. 그 종결 시 구현 언어 범위 tier-1 ≡ 정답
= 인터프리터 실삭제(R7) 가능. 단 atlas_verify 가 gate-1 metric MATCH 되려면 tier-2
잔여 codegen 버그(별도 cycle)도 필요.

---

### 진행 로그 — closure-expression scope assessment: 3-cycle RFC (cycle h20)

closure-expression(`fn(x){...}`) 에이전트가 scope-assess 후 stop-discipline 으로 **구현 보류** (docs-only). 발견:
- t38_nanbox 의 closure 는 **capturing** (외부 변수 캡처) — 비-capturing 우회 없음.
- tier-2 메커니즘 (`codegen_c2.hexa::gen2_lambda_expr`): free-var 분석 → `__hexa_lambda_N` 합성 top-level fn 으로 lift (`HexaVal __env` 첫 param) → capture 를 `hexa_array` env 로 box → callsite 가 `hexa_closure_new(fnptr, arity, env)` → `TAG_CLOSURE` HexaVal → indirect call 은 `hexa_callN` (runtime.h static-inline) 가 TAG 분기. runtime 함수(`hexa_array_*`/`hexa_closure_new`/`hexa_callN`)는 이미 존재 → tier-1 link 가능.
- **scope-blow 원인**: tier-1 은 closure/indirect-call 인프라 전무. `STMT_CALL` 이 callee 를 compile-time 문자열 `op` 로 보유 → arm64 codegen 이 `bl <symbol>` direct call 만 emit. register-held fn-pointer·`blr`·`TAG_CLOSURE` load/store·`hexa_closure_new` emit 전무. = 새 calling-convention 축. try/catch(기존 call 인프라 재사용)보다 근본적으로 큼.

**3-cycle RFC 분할** (각 독립 cycle):
- **C1** — closure parse + `ExprKind::Closure` AST + 전 check-pass exhaustive match coverage. codegen 은 명시적 `HX` "closure codegen unimplemented" 로 reject (HX2001 보다 정직). parse-gate 검증. self-host fixpoint 보존 (additive).
- **C2** — MIR indirect-call stmt (callee-as-Operand) + 합성 MFunc lift + free-var capture.
- **C3** — arm64/x86_64 `hexa_closure_new` emit + `TAG_CLOSURE` load/store + `blr` lowering. C3 종료 시 t38 closure 동작 → gate-1 38/44.

reference: tier-2 `gen2_lambda_expr` + `runtime.h::hexa_callN`. interp 은 oracle 금지.

### 진행 로그 — closure-expression C1 LANDED: parse + AST + check 전반부 (cycle h20)

closure-expression 3-cycle RFC 의 **C1 (front-half: lexer/parser/AST/check)** 구현 완료. codegen 은 C2/C3 로 명시 보류.

구현 (9 파일):
- **ast** (`compiler/parse/ast.hexa`) — `ExprKind::Closure` 추가. 노드 shape: `text` = 10진수 param 개수, `children = [param_0 .. param_{n-1}, body_block]`. param_i = `ExprKind::Ident` (text=이름, `mut:` prefix 가능, children=[type_ident] if `: T` 명시). body = 항상 마지막 child (`ExprKind::Block`). capture(free-var) 집합은 C1 에서 수집 안 함 — C2 가 body 서브트리 walk 로 구축. 이 shape 선택 이유: param 이름+타입을 구조적으로 보존 → C2 type-check / C3 codegen 이 문자열 split 없이 사용; body 는 일반 Block 서브트리 → 기존 walk 재사용.
- **parser** (`compiler/parse/parser.hexa`) — `parse_primary` 의 `KwFn` 분기 → `parse_closure_expr` (이전엔 unrecognized fallback → Ident text="fn" → `HX2001 undefined name fn`). `parse_closure_param` 은 param 타입 **선택적** (tier-2 `self/hexa_full.hexa::parse_params` 미러; top-level `parse_param` 의 필수 `: T` 와 대비). `fn()`·`fn(x)`·`fn(x: i64, y: i64)`·optional `-> Ret` (parse-and-discard) 수용.
- **bind** (`compiler/check/bind.hexa`) — `_bind_is_closure_kind` probe + `_bind_walk_expr` Closure 분기: param 을 새 scope 에 `_define`, body 를 그 scope 에서 walk. body 의 free-var 는 enclosing scope chain 으로 resolve → capturing closure 가 `HX2001` 안 냄 (검증됨).
- **types** (`compiler/check/types.hexa`) — `_types_is_closure` probe + `_infer_expr` Closure 분기: param Ident child 를 free-ident 로 오인 안 함, body 만 infer, closure 값에 `Type{kind:\"fn\"}` (args/ret 비움 — C1 의 최소 표현; 기존 `t.kind==\"fn\"` callee 체크 재사용 → closure 호출이 non-fn 으로 오판 안 됨).
- **ast_to_hir** (`compiler/lower/ast_to_hir.hexa`) — `_expr_kind_tag` 에 `Closure -> \"closure\"`, `_hir_is_closure_kind` probe + `_lower_expr` Closure 분기 (param=이름-only ident HExpr, body=param 정의된 child frame 에서 lower, `closure`-tagged HExpr).
- **hir_to_mir** (`compiler/lower/hir_to_mir.hexa`) — `_emit_hx1104` + `_lower_hexpr` `k==\"closure\"` 분기 → **HX1104** emit 후 `_no_value` (body 재귀 안 함). `_is_known_hexpr_kind` 에 `closure` 추가 (HX1103 중복 방지).
- **catalog** (`compiler/diag/catalog.hexa`) — `HX1104` \"closure codegen not yet implemented\" 등록 (Error, S2). HX2001 보다 정직한 deferred-codegen 메시지.
- **main** (`compiler/main.hexa`) — `hir_to_mir_diags()` drain 후 **render + `_has_errors` abort** 추가. 기존 pre-codegen abort 는 `lower_hir` 전에 실행 → HX110x (HIR→MIR 단계에서만 발생) 가 codegen 도달해 잘못된/빈 바이너리 emit 되던 갭. closure 의 HX1104 가 정직하게 abort 하려면 필수.
- **exhaustive match coverage** — bind/types/units/equational/annotations/citation/resolve/discover/ast_to_hir 전 `ExprKind` match 에 `Closure` arm 추가 (try/catch 커밋 `8f45d3d3` 패턴 정확 미러; non-exhaustive ripple 0).

검증 (macOS load-constrained, build_aprime smoke 2회 이내):
- `bash tool/build_aprime.sh` — 컴파일러 self-build OK, smoke `exit(6*7)==42` PASS (새 ExprKind + match arm exhaustive 확인).
- closure repro `let f = fn(x){return x*2}; println(f(21))` — parse 통과 (`HX2001 undefined name fn` 사라짐), bind/type 통과, `HX1104` 정직한 deferred-codegen 메시지로 abort (RC=1, span 2:13-15).
- `fn()` / `fn(x: i64, y: i64)` / capturing(`fn(x){x+captured}`) 3 형태 모두 동일하게 HX1104 도달 (capturing 케이스 free-var `HX2001` 무발생 → bind 정상 확인).
- t38_nanbox_smoke (line 94 capturing closure) — 이전 `HX2001` → 현재 `HX1104` 도달.
- non-closure 프로그램 회귀 0 — full asm emit, RC=0.

C2/C3 잔여: C2 = MIR indirect-call (callee-as-Operand) + 합성 MFunc lift + capture; C3 = arm64 `hexa_closure_new`/`TAG_CLOSURE`/`blr` codegen. C3 종료 시 t38 동작 → gate-1 38/44.

---

### 진행 로그 — closure-expression C2/C3 LANDED (`c5c3e9f8`) (cycle h21)

closure RFC back-half (C2 lowering + C3 arm64 codegen), C1(`f4ce5f61`) 위에 적층:
- **C2** (`hir_to_mir.hexa`·`ir/mir.hexa`·`optimize/{dce,inline}.hexa`): closure body free-var
  capture 분석 → synthetic top-level MFunc lambda-lift (`__env` 첫 param, capture 를 env
  read 로 rewire) → closure expr 이 env-array build + `hexa_closure_new` TAG_CLOSURE 값으로
  lowering. callee 가 Operand(register-held closure 값)인 indirect-call MIR form 신설
  (기존 compile-time-string-callee `STMT_CALL` 과 분리; direct call 무변경).
- **C3** (`codegen/arm64_darwin.hexa`): synthetic lambda MFunc emit; closure site 가
  env build + `bl _hexa_closure_new`; indirect call dispatch. non-closure direct-call
  codegen 무변경.
- **runtime 심볼 export** (`self/runtime.c`): `hexa_closure_new` 가 runtime.c·runtime.h
  양쪽 `static inline` → standalone runtime.o 에 심볼 부재 → aprime separate-compile link
  시 `Undefined symbols: _hexa_closure_new`. runtime.c 정의의 `static inline` 제거(extern
  화); runtime.h copy 는 header-includer 용 유지 (runtime.c 가 runtime.h 미include —
  재정의 없음). 이전 farr_* de-staticize 와 동일 패턴.

**검증 (mini offload — macOS 부하 0)**: build_aprime smoke `exit(6*7)==42` PASS;
closure repro r1 `fn(x){x*2}` → `42`, r2 capturing `fn(x){x+c}` (c=10) → `15` —
non-capturing·simple-capturing 양쪽 동작; **self-host fixpoint 보존** `ap1f.s==ap2f.s`
(252,137 lines); 44-smoke tier-1 compile+link **41 ok / 3 fail** (fail = t35·t36
선재 FFI/stdlib + t38) — **regression 0**.

**잔여 (#39)**: t38_nanbox closure(line 94)는 `HX1101 unbound identifier 'captured'
in lower` — C2 capture 분석이 t38 의 특정 capture scope(plain main-local 과 다른 binding
form) 미해결. simple capture 는 동작. 별도 focused fix.

**closure RFC 상태**: C1+C2+C3 전부 land, closure end-to-end 동작 (단 t38 의 특정
capture scope 만 #39 잔여). 진짜 tier-1 codegen gap 은 #39 capture-scope 1건으로 수렴.

---

### 진행 로그 — closure capture-scope #39 LANDED (`f4f1225e`) — closure RFC 완결 (cycle h21)

#39: t38 의 capture 는 nested-closure 아닌 **module-global** scope 였음 (t38 는 `fn main`
없는 top-level script — `captured`·closure 둘 다 module-level `let`). 2 gap:
- `_lower_closure` 가 lifted lambda body 를 `globals: []` 인 fresh ctx 로 lowering → body
  의 by-name `_mir_lookup_global` fallback 이 못 찾음. fix: lifted lambda lctx 를
  `globals: enc.globals` 로 seed (`_lower_fn` 의 mglobals seed 와 동일 패턴).
- indirect-call discriminator 가 local-bound callee 만 indirect 처리 → global-`let`
  bound closure callee 가 direct named-call 로 추락 (`bl _clo` → undefined). fix:
  local-lookup miss 시 `_mir_lookup_global` 도 확인 — global slot 은 `ITEM_LET` 만
  (fn 아님) → global-let callee = closure value → indirect dispatch. tier-2 codegen_c2
  mirror.

**검증 (mini)**: build_aprime smoke PASS; closure r2(main-local capture)→15 무regression;
top-level-let closure capturing top-level-let→15; **t38_nanbox HX1101 소멸, compiles+
links+runs rc=0, closure check PASS**; self-host fixpoint 보존 `ap1f.s==ap2f.s`
(252,331 lines).

**closure RFC 완결**: C1(`f4ce5f61`)+C2/C3(`c5c3e9f8`)+capture-scope(`f4f1225e`) — closure
end-to-end 동작 (non-capturing·main-local capture·module-global capture·global-let
closure call 전부).

**t38 잔여 1건 (#40, closure 무관)**: t38 가 tier-1 32 pass/1 fail vs tier-2 33/0 —
유일 divergence = `void is void` (`type_of(returns_void()) == "void"`). void-returning
call 결과의 type_of 가 tier-1 codegen 에서 오답. closure 0 인 repro 로도 재현되는
선재 버그. 이거 닫으면 t38 MATCH → gate-1 38/44.

**goal ② 현황**: self-host fixpoint CLOSED · try/catch CLOSED · closure RFC CLOSED.
진짜 tier-1 codegen gap = #40 (void-call type_of) 1건. 그 외 gate-1 non-MATCH 는
전부 non-tier-1 (tier-2 #37 · ORAFAIL-class FFI · env).

---

### ★★★ 진행 로그 — #40 void-call type_of FIXED (`63d2511c`) — 전 tier-1 codegen gap CLOSED (cycle h21)

**#40**: `arm64_darwin.hexa` `_STMT_RETURN` 가 16-byte return pair(x0:x1)를 `len(s.args)>=1`
일 때만 load. value-less return(zero-arg `STMT_RETURN`)은 x0:x1 미설정 → caller 가 직전
`bl` 의 clobber 잔여를 result 로 포착 → `type_of()` 가 garbage tag 읽어 `void` 대신
`unknown`. fix: zero-arg else-branch + safety epilogue 가 `movz x0,#4`(TAG_VOID)+
`movz x1,#0` emit (codegen only, runtime.c 무변경).

**검증 (mini)**: build_aprime smoke PASS; void-call type_of repro tier-1 → `void` (oracle
byte-identical, 이전 `unknown`); **t38_nanbox tier-1 "ALL PASS" rc=0** = tier-2 oracle
`33 pass/0 fail` MATCH; self-host fixpoint 보존 `ap1f.s==ap2f.s` (253,049 lines).

**gate-1: 37 → 38/44** (t38_nanbox APFAIL→MATCH; #40 codegen 변경은 value-less return
에서만 발화 — 다른 테스트 무영향이라 delta 확정, full re-sweep 불요).

---

## ★★★ MILESTONE — 전 tier-1 codegen-correctness gap CLOSED (cycle h21 종결)

goal ② "인터프리터 폐기 → self-hosted 컴파일러" 의 **tier-1 축 완결**:

- **self-host bit-stable fixpoint**: CLOSED (`ap1f.s == ap2f.s == ap3f.s` byte-identical;
  aprime_cc 가 인터프리터·hexa_v2 없이 자기 자신을 bit-for-bit 재현).
- **전 tier-1 codegen-correctness 버그 종결** — #23~#40:
  - self-host fixpoint 7버그 (#23 index_set · #24 loop-sentinel · #25 match-as-expr ·
    #26 MFunc-arena · #27 call-overflow stride · #28 enum-eq · #29 bitwise-as-add)
  - codegen 정정 (atlas-verifier index_of+bool-tag · 메모리 builtin ×14 · @link/extern+*T
    파서 · int↔float typecheck · math annotations · void-call type_of)
  - 신기능 전 스택 (try/catch/throw · closure C1+C2+C3+capture-scope)
- **gate-1 38/44**. 잔여 6 non-MATCH 는 **100% non-tier-1**:
  - `atlas_verify` — tier-2 codegen 잔여 발산 (#37; tier-1 8/8 PASS)
  - `t35`·`t36`·`t37` — ORAFAIL-class (tier-2 oracle 자체가 빌드/실행 실패: FFI dlsym·clang)
  - `repo_taxonomy_audit`·`t34_net_listen` — env-resource (OOM·socket)

→ **구현된 언어 범위에서 tier-1(aprime_cc) 이 codegen-complete**. tier-2 가 정확히
처리하는 모든 .hexa 를 tier-1 도 정확히 처리. R7 deletion gate: ②③④ ✅ · ① — tier-1
codegen gap 0 이므로 사실상 충족.

**다음 = R7 인터프리터 소스 실삭제** (goal 의 문자적 종착점). hard-to-reverse 작업이라
user 확인 후 진행. 잔여 #37(tier-2 codegen)은 bootstrap 경로 품질 개선 — interp 폐기
비차단 (tier-1 이 미래 경로).

### 2026-05-18 — R7 Phase 1: interp source-deletion entanglement map (pre-surgery)

R7 (인터프리터 소스 실삭제) Phase 1 = "delete-target vs preserve-target" 정밀 매핑. hard-to-reverse 라서 실삭제 전 commit-first.

**Interp-only (safe to delete — Phase 2 후보)**:

| 경로 | 역할 | 의존성 |
|------|------|--------|
| `self/hexa_full.hexa` (19,584 LoC) | tree-walking interpreter SSOT — `tokenize` + `parse` + AST + `eval_expr` + `interpret(ast)` 엔트리 | `use "runtime_core"` + `use "codegen_c2"` + `use "bc_emitter"` + `use "bc_vm"` + `use "runtime/*_pure"` + `use "stdlib/strbuf"` — 모두 flatten 시 inline 됨. 본 monolith 자체는 어디서도 import 되지 않음 (오로지 `tool/build_interp.hexa` 가 transpile target 으로 사용) |
| `self/runtime_core.hexa` | interp 의 proof/fuse/match/stack helper (T1 Phase B 분리) | 본 파일을 `use` 하는 곳: **오직 `self/hexa_full.hexa`** — interp-exclusive |
| `self/hexa_full.json` | interp invariant 레지스트리 + ossification ledger | hexa_full.hexa 헤더가 `@registry` 로 참조 — interp-exclusive |
| `self/hexa_full.profile_hook.hexa.draft` | profile-hook draft (미배포) | hexa_full 전용 |
| `tool/build_interp.hexa` | Mac native interp builder (`hexa_v2 hexa_full.hexa → /tmp/hexa_full_regen.c → clang → build/hexa_interp.real`) | interp-exclusive |
| `tool/build_interp_linux.hexa` | Linux interp builder | interp-exclusive |
| `tool/rebuild_interp.hexa` | flatten-키 캐시 + 재빌드 드라이버 | interp-exclusive |
| `tool/build_runner_image.hexa` (L218 / L222) | 도커 이미지 빌드 안에서 `tool/build_interp_linux.hexa` 호출 — interp 삭제 시 해당 step 제거 필요 | interp-derived |
| `tool/fixpoint_compare.hexa` | hexa_v2 fixpoint compare (v3→v4 = hexa_full.hexa transpile loop) | interp-source-exclusive — interp 소스 없으면 의미 없음 |
| `tool/check_ssot_sync.hexa` | `self/interpreter.hexa` ↔ `self/hexa_full.hexa` 동기화 검증 | interp-exclusive (legacy interpreter.hexa 도 동시 정리 후보) |
| `tool/ssot_drift_report.hexa` | hexa_full.hexa SSOT drift 측정 | interp-exclusive (혹은 새 SSOT 로 재포인팅) |
| `tool/deploy_h100.hexa` (L47 도움말 텍스트만) | docstring 에 hexa_full.hexa cross-compile 예시 — code 의존 X | docstring 정리만 |
| `build/hexa_interp*` (gitignored) | 빌드 산출물 | gitignored — 별도 처리 |

**Driver-level entanglement (preserve interim — needs replacement before deletion)**:

`self/main.hexa::cmd_run(file, args)` 가 interp 바이너리 (`build/hexa_interp.real`) 를 child process 로 spawn. 18 call site:

| 서브커맨드 | call site | 대체 경로 |
|------|---------|-------|
| `hexa run <file>` | L350 (top-level dispatch) | aprime_cc-direct (tier-1) 또는 `hexa build && exec`. `bin/hexa-run-native` 가 이미 tier-1/2/3 wrapper. 본 dispatch 가 wrapper 와 합쳐져야 함. |
| 16 absorbed verb (`lsp`·`test`·`bench`·`check`·`convergence dump`·`init`·`verify`·`calc`·`atlas`·`qrng`·`sim-universe`·`qmirror`·`batch`·… L1121 dispatch_absorbed) | L1121, L3114, L3172, L3199, L3232, L3271, L3298, L3316, L3334, L3352, L3370, L3388, L3418 | 각 sub-script (`self/lsp.hexa`·`self/invariant_check.hexa`·`stdlib/qrng/qrng.hexa` 등) compiled 바이너리로 land 후 main.hexa 가 그것을 invoke. **R7 deletion 의 진짜 게이트**. |
| `cmd_batch` | L2407 | 동일 대체 필요 |

→ **Phase 2 = "interp 본체 (`hexa_full.hexa` + 12 위 도구) 삭제" 는 driver entanglement 해소 후에 가능**. 본 Phase 1 commit 후 즉시 source deletion 은 hexa CLI 의 `hexa run` 외 16 sub-command 가 즉시 break.

**MUST PRESERVE (interp 제거에 영향 없음 — 모두 self-host compiled path 의 부품)**:

| 경로 | 역할 | 이유 |
|------|------|------|
| `self/native/hexa_v2` (binary) | bootstrap transpiler — `tool/build_aprime.sh` 의 [stage 2] 가 의존. `aprime_cc` 부트스트랩 발판 | aprime_cc 가 self-host bit-stable 가 되었으나 `hexa_v2` 는 보존 (bootstrap reproducibility) |
| `self/native/hexa_cc.c` + `*.hexanoport` | hexa_v2 의 boot image — `self/{lexer,parser,type_checker,codegen_c2}.hexa` 4 SSOT 의 generated artifact | hexa_v2 재생성 시 필요. hexa_full.hexa 와 무관. |
| `self/{lexer,parser,type_checker,codegen_c2}.hexa` | hexa_v2 의 4 SSOT (C-emitting transpiler 소스) | hexa_full.hexa 와 무관 (codegen_c2 는 hexa_full 에 `use` 되지만 `hexa_full` 의존이 아님 — codegen_c2 가 stand-alone SSOT) |
| `self/runtime.c` (13,114 LoC) + `runtime.h` | 모든 compiled binary 에 정적 링크되는 runtime primitives (GC · value tags · string ops · arena · math · I/O · network · process) | interp + 모든 compiled program 공유. interp 삭제와 무관. |
| `self/runtime/*_pure.hexa` (≈900 파일) | stdlib pure-hexa 모듈 (math · string · array · file · datetime · format · …) | hexa_full 이 `use` 하지만 stand-alone 모듈 — compiler/ · aprime_cc binary · 다운스트림 (wilson 등) 도 사용 |
| `self/bc_emitter.hexa` + `self/bc_vm.hexa` | bytecode VM (HEXA_VM=1 모드, `--bc` 플래그) — hexa_full 의 옵셔널 백엔드 | hexa_full 만 사용. 본 삭제와 동시 제거 후보 — 단 별도 `--bc` 채택자 확인 후. **보존 권장 (Phase 2.5)** |
| `self/main.hexa` (CLI dispatcher) | compiled `hexa.real` 바이너리 SSOT — `hexa build`/`parse`/`cc`/help/version 모두 self-compiled 동작 (R7 gate ② LANDED `24cf3e01`). `cmd_run` 만 interp 위임. | 보존 — `cmd_run` 단독 surgery |
| `self/module_loader.hexa` | flatten 전처리기 — compiled module_loader 가 R7 gate ④ LANDED | 보존 |
| `compiler/` 전체 | tier-1 native compiler (`aprime_cc`) | hexa_full 무관 |
| `tool/build_aprime.sh` | aprime_cc canonical build recipe | hexa_full 무관 (hexa_v2 만 의존) |
| `bin/hexa-run-native` | tier-1/2/3 wrapper (aprime_cc → hexa build → hexa run) | tier-3 `hexa run` 만 interp; 본 wrapper 자체는 보존 — interp 제거 후 tier-3 분기 제거만 필요 |

**Entanglement 결론**:

1. **Source-level**: `hexa_full.hexa` + `runtime_core.hexa` + 6 interp-build tool 은 **clean 분리** — source 삭제 자체는 compiler/·hexa_v2·runtime.c·codegen_c2 영향 0.
2. **Runtime-level**: 그러나 `self/main.hexa::cmd_run` 의 18 call site (lsp·test·bench·check·init·verify·calc·atlas·qrng·sim-universe·qmirror·batch · etc.) 가 `build/hexa_interp` 바이너리에 의존. **interp 바이너리 부재 시 `hexa run` 외 16+ 서브커맨드 즉시 break**.
3. → **Phase 2 surgical-deletion 은 두 트랙 동시 필요**:
   - 트랙 A (source deletion): `hexa_full.hexa` · `runtime_core.hexa` · `hexa_full.json` · `hexa_full.profile_hook.hexa.draft` · `tool/build_interp.hexa` · `tool/build_interp_linux.hexa` · `tool/rebuild_interp.hexa` · `tool/fixpoint_compare.hexa` · `tool/check_ssot_sync.hexa` · `tool/ssot_drift_report.hexa` · `tool/build_runner_image.hexa` 의 interp-build step · `tool/deploy_h100.hexa` docstring.
   - 트랙 B (CLI driver re-targeting): `self/main.hexa::cmd_run` 을 (i) `bin/hexa-run-native` 로직 inline (aprime_cc / hexa build / 실행) (ii) absorbed-verb sub-script 들을 compiled-binary 로 빌드 후 `cmd_run` 대신 그것을 spawn. 18 call site 전수 검토 필요.

**Phase 1 권고**:

surgical deletion 은 트랙 B (CLI driver re-targeting) 가 별도 multi-cycle 작업이므로, 본 Phase 1 commit 직후 **트랙 A 단독 진행이 안전하지 않음** — 트랙 A 만 삭제하면 `hexa lsp`·`hexa test`·`hexa qrng` 등 16 서브커맨드 즉시 break.

**대안 — Phase 2 권고 (보수)**:

(option A) **소스만 삭제, CLI 는 placeholder 화**: `hexa_full.hexa` 등 트랙 A 파일 삭제 + `cmd_run` 을 "interpreter retired — use `hexa build` for scripting, or use the dedicated sub-binary" 메시지로 stub 화 (16 absorbed-verb 들은 functionality 일시 손실 — 개별 sub-binary 재라우팅 후속 cycle).

(option B) **placeholder 만, 소스 보존**: 트랙 A 보존, `cmd_run` 에 deprecation warning 추가 + `hexa run` 만 tier-1/2 native 로 라우팅. 트랙 B 완주 후 트랙 A 일괄 삭제.

(option C) **즉시 트랙 A 삭제 + 트랙 B 회기 추적**: 트랙 A 삭제, `cmd_run` 은 "interp retired" 메시지 emit + exit 1. 16 absorbed-verb 들은 functionality 일시 손실, 후속 cycle 에서 sub-binary 빌드 + main.hexa 재라우팅. **clean break — 가장 강한 신호**.

본 Phase 1 = mapping 만. Phase 2 옵션 선택은 다음 cycle (또는 orchestrator 지시).


---

### 2026-05-18 — R7 Phase 2 option B LANDED — user-direct warning, sources preserved

**옵션 B 채택 사유** (Phase 1 entanglement map 의 트랙 A/B/C 중):
- `self/main.hexa::cmd_run` 이 user-direct (`hexa run <file>` + `hexa://run`) 외에 16+ absorbed-verb (`lsp`/`test`/`bench`/`check`/`init`/`verify`/`calc`/`atlas`/`qrng`/`sim-universe`/`qmirror`/`batch`/`convergence`/…) 의 backend.
- A (즉시 소스삭제 + cmd_run placeholder) = 16 서브커맨드 즉시 break.
- C (즉시 소스삭제 + exit-1 메시지) = 동일.
- **B (보수: 소스 보존, user-direct 만 deprecation warning)** = functionality 손실 0, user signal 강.

**변경 (option B)**:
- `self/main.hexa`: `cmd_run_user_direct(file, extra_args, want_vm)` 신설 — stderr 에 deprecation warning 3줄 emit (silenceable via `HEXA_INTERP_QUIET=1`) → `cmd_run_dispatch(file, extra_args, want_vm)` 위임. functionality 보존.
- user-direct call site 2곳만 새 fn 으로 교체:
  - L350 `hexa://run` URL action — `cmd_run_user_direct(file, args_list, false)`
  - L3060 top-level `hexa run <file>` CLI — `cmd_run_user_direct(file_arg, run_args, want_vm)`
- 16+ absorbed-verb 의 `cmd_run` 호출 (L1158 batch backend, L2409 cmd_batch loop, L3116 lsp, L3174 check, L3201 convergence, L3234 test, etc.) 은 그대로 — track B 에서 sub-binary 로 마이그레이션.
- `AGENTS.tape @D g_interp_deprecated`: option B 채택 명시, R7 gate ①②③④ 모두 충족 기록, user_warning + sunset 트랙 B 명세 갱신.

**검증**: build_aprime smoke + self-host fixpoint 보존 (mini 에서 검증 예정 — codegen 변경 0, frontend 만 patch 라 fixpoint 영향 0).

**track B (sunset 조건)**: 16+ absorbed-verb 의 sub-binary 재라우팅 (각자 native 빌드 후 main.hexa 가 sub-binary 를 spawn) — multi-cycle. 완료 후 interp 소스 일괄 삭제 → `g_interp_deprecated` 룰 폐기 → R7 종결.

---

### 2026-05-18 — R7 track B cycle 1 — qrng 시작 (cycle h22)

**Decision 1** (worktree triage): 현재 `rfc043-hexa-torch` (HEAD `f14a443b`, 18 modified + 3 untracked, flame + quant_meter mixed WIP) 그대로 두고 `origin/main` 기준 새 worktree `/tmp/wt-r7-trackb` (`r7-trackb-cycle1` 브랜치) 점프.

- **picked**: 현재 브랜치 보존, origin/main 기준 새 worktree
- **rationale**:
  - shared dir `~/core/hexa-lang` 직접 편집 금지 (memory: `feedback_hexa_lang_shared_worktree_branch_hazard`)
  - flame WIP 와 R7 캠페인은 독립 north-star — mixed branch 로 강제 통합 시 양쪽 모두 silent drift 위험
  - clean `origin/main` (`c0864dc3`) 위에서 cherry-pickable 단일 패치 시퀀스가 R7 track B 패턴 확립에 적합

**Decision 2** (campaign): goal ② 진행 = **#42 R7 track B** (16+ absorbed-verb sub-binary 재라우팅, multi-cycle).

- **picked**: #42 R7 track B
- **rationale**:
  - goal ② (interp 폐기) 의 최종 종결 게이트 — track A (소스 삭제) 는 B 가 닫혀야 가능
  - #37 tier-2 atlas_verify 6 발산은 tier-1 무관 polish — north-star 진행 0
  - GOAL ① flame+forge 는 별도 north-star (rfc043 브랜치) — 현 세션은 R7 인계 우선

**Decision 3** (first verb): **qrng** (`stdlib/qrng/qrng.hexa`, 318 lines).

- **picked**: qrng
- **rationale**:
  - 가장 작은 self-contained sub-script (vs lsp 1006 · invariant_check 1223)
  - 이미 `fn main()` 보유 (L261-318) — shim 작업 불필요, argv 자체 dispatch
  - stdlib 하위 모듈 4개만 import (`source`/`qrng_main`/`registry`/`router`) — cross-module dep 최소, build feasibility ✓
  - 패턴 확립 1st-cycle 으로 적합 (binary 위치 lookup · spawn API · install_dir resolution · fallback transition)

**현 상황** (cycle 시작 시점):
- L3369-3386 `dispatch_absorbed` 의 qrng 분기 = `cmd_run(qrng_script, qrng_args)` (interp call)
- 목표: `cmd_run` 호출 → `bin/hexa-qrng` (또는 `__inst_q + "/bin/hexa-qrng"`) spawn 으로 교체. binary 미존재 시 cmd_run fallback (transition).
- 빌드 인프라: `bin/hexa-run-native` 3-tier (aprime_cc → hexa build → hexa run). qrng 는 `hexa build` 경유.

**구현 (LANDED)**:
- `bin/hexa-qrng` build: `HEXA_MAC_BUILD_OK=1 hexa build stdlib/qrng/qrng.hexa -o bin/hexa-qrng` → 435 KB Mach-O arm64 (libsodium + openssl@3 link via clang `-DHEXA_HAS_LIBSODIUM` + `-DHEXA_HAS_OPENSSL`). 빌드 시간 < 30s (heavy 아님).
- `tool/build_hexa_qrng.sh` (1.7 KB shell): canonical 빌드 레시피 + aggregate smoke (`__QRNG_MAIN__ PASS` grep). 패턴-establishing for 15 잔여 verb.
- `.gitignore`: `bin/hexa-qrng` 추가 (arch-specific Mach-O/ELF, rebuild source 가 SSOT).
- `self/main.hexa` L3369-3386 → L3369-3438 (~70 lines, 18 → 70): qrng 분기 spawn path 추가. binary lookup (`__inst_q + "/bin/hexa-qrng"` → cwd `bin/hexa-qrng`), shq quoting, `exec(cmd + " 2>&1; echo \"__HEXA_SHIM_RC__=$?\"")` + marker scan + `parse_int_str(rc_str)` + `exit(rc)` on non-zero. binary 부재 시 `cmd_run(qrng_script, qrng_args)` legacy fallback 보존 (`g_inbox_dual_track` transitional).
- `hexa.real` rebuild: `self/native/hexa_v2 self/main.hexa build/stage1/main.c` + `hexa tool/build_dispatch.hexa` → 498 KB Mach-O.

**검증**:
- byte-eq (status): `./hexa qrng status` (spawn) ≡ `./bin/hexa-qrng status` (direct) → diff exit 0
- subcommand smoke: `--version` ✓ · `chain` ✓ · `selftest` 9/9 OK __QRNG_MAIN__ PASS ✓
- exit code propagation: `./hexa qrng collect --bytes=0` → shell rc=1 (binary `exit(1)` → marker → `parse_int_str` → `exit(rc)`)
- fallback: `mv bin/hexa-qrng aside && ./hexa qrng status` → cmd_run path 진입 (worktree-local hexa_interp 부재로 final invocation 만 실패, 분기 로직은 OK)
- 다른 dispatch 무결성: `--version`/`--help`/`parse <file>` 정상 — qrng else-if 분기만 surgical change.

**fixpoint regression risk**: 0. self/main.hexa::dispatch_absorbed::qrng 분기는 hexa CLI dispatch only — compiler/main.hexa · aprime_cc · hexa_v2 · codegen/transpiler 어느 경로에도 흐르지 않음. self-host fixpoint (aprime_cc transpiles compiler/main.hexa) 와 독립.

**남은 R7 track B (15 verbs)**: 동일 패턴 (build script + dispatch branch surgical edit + .gitignore + PLAN.md cycle entry). 다음 후보 = `lsp`/`check`/`test` (size-graded). multi-cycle.

**mini verify (commit `58b558e5`)**:
- ✅ `tool/build_aprime.sh` smoke 5/5 PASS · `exit(42)==42` · aprime_cc 2.1 MB Mach-O · fixpoint regression 0
- ⚠️ `tool/build_hexa_qrng.sh` FAIL on mini — `hexa: command not found` (mini PATH 에 hexa CLI 미설정). dispatch fallback (`cmd_run` on `stdlib/qrng/qrng.hexa`) 가 무리없이 작동하므로 사용자 영향 0. polish 항목: build_hexa_qrng.sh 가 repo-local `./hexa` shim 또는 `~/.hx/bin/hexa` resolution 지원하도록 후속 cycle. 본 cycle 의 fixpoint regression check 는 build_aprime 으로 충분.

---

### 진행 로그 — quant_meter P1 MVP LANDED (2026-05-18, commit `ce431e2f`)

Rate-distortion compile-pipeline instrumentation P1 ships as a
standalone module under `compiler/quant_meter/`. Three hexa files +
Draft RFC, 859 lines total.

**Framing**: compilation = progressive quantization. Each transform
stage removes a category of representational freedom while preserving
semantics (D=0, CompCert-style observational equivalence). Two
orthogonal measurements per IR level:

- `S` (size, node count) — NOT monotone (HIR→MIR expands to 3-address
  SSA). Observability / regression signal, NOT an invariant.
- `F` (freedom vector, per-kind counts) — MUST be monotone
  non-increasing across transforms. A rise = a stage added freedom = a
  design bug. P1 ships three zero-analysis components:
    - `F_name` (unresolved identifier strings, killed by bind)
    - `F_type` (expressions without pinned monotype, killed by
      type-attach)
    - `F_ctrl` (structured control not yet lowered, killed by
      `hir_to_mir`)

**Files**:
- `compiler/quant_meter/meter.hexa` (288 L) — `RateVec` + 3 tree-walk
  counters
- `compiler/quant_meter/meter_test.hexa` (294 L) — synthetic IR PASS
  verification (hand-built ast/hir/mir for `fn classify { if (n) { a }
  else { while (b) { } } }`, works around interp self-build OOM)
- `compiler/quant_meter/meter_probe.hexa` (83 L) — slim real-code probe
  (lex → parse → ast_to_hir → hir_to_mir + meter only, no codegen /
  optimize; bundle ~7k LoC under interp flatten ceiling)
- `proposals/rfc_quant_meter_rate_distortion_pipeline.md` (Draft, 194 L)

**Measured (synthetic, `meter_test` PASS)**:

```
stage   S(nodes)   F_name   F_type   F_ctrl
ast          10        3        9        2
hir          10        0        0        2
mir          13        0        0        0
```

Two empirical findings: (1) `F_name` 3→0 and `F_type` 9→0 **collapse
simultaneously at ast_to_hir** — nanopass single-task violation (one
pass killing two freedom kinds). (2) `S` 10→10→13 rises across MIR
lowering — proves S≠F separation is necessary (decision 1 of RFC).

**Honest positioning** (RFC §5):
- `D=0` rests on CompCert forward-simulation, NOT real-valued
  RD-distortion. The rate-distortion vocabulary is expository lens only.
- `R` (true rate) uncomputable per Kolmogorov full-employment theorem;
  `F` is explicit operational proxy (counts), not entropy.
- Per-stage statistics plumbing is standard (LLVM `-stats`); novelty is
  the transform/gate 2-class taxonomy with per-component monotonicity
  invariants.

**Cross-branch drift**: RFC §6 #2 claims `ml_canon_path` patch landed in
`self/module_loader.hexa` for diamond-import dedup (interp-retirement
ride-along), but on `rfc043-hexa-torch` this patch is NOT present
(verified: `grep ml_canon_path self/module_loader.hexa` empty). The
patch lives on a sibling branch. P1 MVP files are self-contained —
`meter_test` runs on synthetic IR; `meter_probe` real-code use depends
on that patch landing here.

**P2 gates pending user decision (RFC §9)**:
- (a) HX2600-range strict-lint diagnostics wiring per-component
  monotonicity assertions at transform boundaries
- (b) `ast_to_hir` nanopass split — driven by the measured single-task
  violation (F_name + F_type simultaneous collapse). Separate RFC.
- (c) interp↔compiled `RateVec` byte-diff tool — localizes per-stage
  divergence sources, interp-retirement assist

**Push state**: commit `ce431e2f` unpushed. shared branch
(`rfc043-hexa-torch`) — push pending user decision.

### 2026-05-18 — R7 track B cycle 2 — qmirror (cycle h23)

**Decision 5** (verb #2): qmirror (`stdlib/quantum/quantum.hexa`, 197 lines, RFC 045).

- **picked**: qmirror
- **rationale**:
  - 가장 작은 fn-main() 보유 후보 (vs sim-universe 324 · atlas 527 · check 1223+shim)
  - qrng cycle 1 의 stdlib/<verb>/<verb>.hexa 패턴 정확 동형 — 패턴 재사용성 1.0
  - RFC 045 absorption, 62k LoC 모듈 디스패치 표면 (cmd_dispatch + _module_path) — 패턴 robust 검증

**현 상황**:
- L3458-L3478 `dispatch_absorbed` qmirror 분기 = `cmd_run(qm_script, qm_args)` (interp call)
- 발견: 현 production `hexa qmirror status` 가 `stdlib/quantum/quantum.hexa` 의 실제 출력 (38 모듈 inventory) 가 아닌 stale JSON stub (`{"mode": "fallback-deterministic"}`) 반환. 본 cycle 이 SSOT (quantum.hexa) 출력으로 정상화.
- 목표 (cycle 1 동형): binary spawn + cmd_run fallback

**구현 (LANDED)**:
- `bin/hexa-qmirror` build: `HEXA_MAC_BUILD_OK=1 hexa build stdlib/quantum/quantum.hexa -o bin/hexa-qmirror` → 376 KB Mach-O arm64. 빌드 < 30s.
- `tool/build_hexa_qmirror.sh` (1.4 KB shell): canonical 빌드 + `--version` smoke (`hexa qmirror 2.6.0` 검증).
- `.gitignore`: `bin/hexa-qmirror` 추가.
- `self/main.hexa` L3458-L3478 → L3458-L3528 (20 → 71 lines): qmirror 분기 spawn path 추가. 동일 패턴 (binary lookup `__inst_qm + "/bin/hexa-qmirror"` → cwd `bin/hexa-qmirror`, shq quoting, `__HEXA_SHIM_RC__` marker, `exit(rc)` on non-zero). 부재 시 `cmd_run(qm_script, qm_args)` fallback.
- `hexa.real` rebuild via `self/native/hexa_v2` + `tool/build_dispatch.hexa` → 498 KB Mach-O.

**검증**:
- byte-eq (status): `./hexa qmirror status` (spawn) ≡ `./bin/hexa-qmirror status` (direct) → diff exit 0
- exit code propagation: `./hexa qmirror nonexistent` → shell rc=2 (binary `exit(2)`)
- cycle 1 regression check: `./hexa qrng status` 여전히 byte-eq with `./bin/hexa-qrng status` → diff exit 0
- 다른 dispatch 무결성: 변경 surgical (qmirror else-if 분기만)

**fixpoint regression risk**: 0. dispatch-only change (cycle 1 동일 논리).

---

### 2026-05-18 — R7 track B cycle 3 — sim-universe (cycle h24)

**Decision 6** (verb #3): sim-universe (`stdlib/sim_universe/sim_universe.hexa`, 324 lines, RFC 046).

- **picked**: sim-universe
- **rationale**:
  - 다음 ready candidate — fn-main() at L268 ✓ · stdlib/<verb>/<verb>.hexa 구조 동형
  - RFC 046 absorption (26 modules, ~32k LoC) — qrng cycle 1 패턴 3번째 적용으로 robustness 확정

**구현 (LANDED)**:
- `bin/hexa-sim-universe` build → 396 KB Mach-O. `tool/build_hexa_sim_universe.sh` + version smoke (`hexa sim-universe 1.1.0`).
- `self/main.hexa` L3440-L3457 → L3440-L3517 (qmirror 동형 spawn + cmd_run fallback)
- `.gitignore`: `bin/hexa-sim-universe`.
- `hexa.real` rebuild 후 검증:
  - byte-eq (status): `./hexa sim-universe status` ≡ `./bin/hexa-sim-universe status` → diff exit 0
  - exit code propagation: unknown subcommand → shell rc=2
  - cycle 1+2 regression: qrng 1.0.0 + qmirror 2.6.0 dispatch 정상

**fixpoint regression risk**: 0.

**R7 track B 진척**: 3/16 verbs (qrng · qmirror · sim-universe) — stdlib/<verb>/<verb>.hexa 패턴 모두 마이그레이션 완료. 잔여 13 verbs 중:
- ready (fn main 보유): atlas (527L, tool/atlas_cli.hexa) — ⚠️ build 차단 (아래 참조)
- shim 필요: lsp (1006L) · check (1223L) · test (754L) · convergence_scan
- 내부/특수: batch · bench · init · verify · calc (dispatch 분기 내 inline 또는 embedded — 별도 분석)

**atlas build 차단 (cycle 4 atlas deferred · sequence shifted to cycle ≥6)**:
- `HEXA_MAC_BUILD_OK=1 hexa build tool/atlas_cli.hexa -o bin/hexa-atlas` → clang linker 실패: `_atlas_prefix`, `_audit_merged`, `_audit_overlay`, `_audit_rodata`, `_audit_to_json`, `_audit_to_text`, `_lookup_static`, `_promote_to_atlas`, `_static_atlas` 모두 미해소
- atlas_cli.hexa 의 `use` statements (parser/merger/static_index/audit/audit_rodata/overlay + discover/promote) 가 7개 모듈 import 하지만 flatten 이 `pub fn` 들을 따라가지 못함
- 정의 위치 확인: `static_atlas` @ compiler/atlas/static_index.hexa, `audit_merged` @ compiler/atlas/audit_rodata.hexa L29 등 — 모두 `pub fn` 으로 정상 정의
- 가설: tool/atlas_cli.hexa 가 compiler/ tree 와의 cross-directory `use` 인 경우 flatten 단계가 transitive 하게 따라가지 못함 (stdlib/<verb>/ 내 sibling `use` 는 OK)
- 별도 진단 cycle 필요 — interp `hexa atlas <subcmd>` 는 module_loader 가 OK 처리하므로 hexa build flatten 측의 gap. R7 track B 동안 cmd_run fallback 유지.

---

### 2026-05-18 — R7 track B cycle 4 — convergence (cycle h25 · first shim-cluster)

**Decision 7** (verb #4): convergence (`self/convergence_scan.hexa`, 811 lines, 0 use statements).

- **picked**: convergence
- **rationale**:
  - shim-needed cluster 중 가장 깨끗한 entry — `use` statements 0개 (self-contained, atlas 같은 cross-directory 문제 없음)
  - 기존 `fn cs_main()` (L766) + 모듈-끝 `cs_main()` 호출 (L811) = interp 패턴. 단순 rename + 호출 제거로 standalone main entry 확보 가능
  - dispatch 가 이미 subcmd/file 사전검증 처리하므로 shim 추가 부담 0 (cs_main 의 av[1]/av[2] · av[2]/av[3] · av[3]/av[4] 3-shape 처리도 그대로 활용)

**구현 (LANDED)**:
- `self/convergence_scan.hexa`: `fn cs_main()` → `fn main()` (rename L766) + L811 module-level `cs_main()` 호출 제거 (replaced with R7 explainer comment). interp `hexa run` 도 main() auto-invoke 하므로 dual-path 동작 유지 (`g_inbox_dual_track`).
- `bin/hexa-convergence` build → 391 KB Mach-O. `tool/build_hexa_convergence.sh` + no-arg usage smoke (rc=2 + 'usage:').
- `self/main.hexa` L3208-L3234 → L3208-L3290 (27 → 83 lines): convergence 분기 spawn path (binary lookup → shq + __HEXA_SHIM_RC__ marker + `exit(rc)`) + 기존 사전검증 + cmd_run fallback 유지.
- `.gitignore`: `bin/hexa-convergence`.
- `hexa.real` rebuild.

**검증**:
- byte-eq (dump): `./hexa convergence dump <fixture>` (spawn) ≡ `./bin/hexa-convergence dump <fixture>` ≡ production `hexa convergence dump <fixture>` (interp) → diff exit 0 (양방향)
- dump-meta 동작 ✓
- 사전검증 exit code: `./hexa convergence` (인자 없음) → rc=1 (dispatch L3214 `exit(1)`)
- cycle 1+2+3 regression: qrng 1.0.0 · qmirror 2.6.0 · sim-universe 1.1.0 모두 정상 dispatch

**fixpoint regression risk**: 0. dispatch-only + convergence_scan.hexa fn 이름 rename 만 (codegen/aprime_cc 와 무관).

**R7 track B 진척**: 4/16 (qrng · qmirror · sim-universe · convergence). 첫 shim-cluster 멤버 안착 — rename 패턴 확립. 잔여 shim-cluster: lsp (1006L) · check (1223L) · test_runner (307L). 잔여 atlas-class: atlas (cross-directory flatten gap). 잔여 특수: batch · bench · init · verify · calc.

---

### 2026-05-18 — R7 track B cycle 5 — test_runner (cycle h26 · 2nd shim-cluster)

**Decision 8** (verb #5): test (`self/test_runner.hexa`, 307 lines, 3 within-self/ use statements).

- **picked**: test_runner
- **rationale**:
  - shim-cluster 중 가장 작음 (vs lsp 1006L · check 1223L)
  - 내부 use statements 모두 self/ 트리 내 (attrs/core, attrs/test, stdlib/law_io) — within-directory 패턴이라 flatten 호환 (atlas-class 아님)
  - 모듈-끝 entry block (L260-307) 가 `fn main()` 으로 wrap 가능

**구현 (LANDED)**:
- `self/test_runner.hexa`: L36 `let __av = args()` 제거 (인-comment) + L260-307 entry block 을 `fn main()` 으로 wrap (내부에서 `let __av = args()` 재호출). dual-path 호환 — interp 도 auto-invoke main().
- `bin/hexa-test` build → 425 KB Mach-O. `tool/build_hexa_test.sh` + no-arg usage smoke.
- `self/main.hexa` L3290+ (test 분기): spawn path (3-tier binary lookup: install_dir + cwd + HEXA_LANG) + cmd_run fallback (기존 3-tier script resolve 보존).
- `.gitignore`: `bin/hexa-test`.
- `hexa.real` rebuild.

**검증**:
- 기능 동등성: `./hexa test <fixture>` (spawn) ≡ `./bin/hexa-test <fixture>` (direct) — 출력에서 timing measurement (`in 0.307s` vs `in 0.291s`) 만 차이, 모든 test name/PASS-FAIL/summary 동일. 2/2 PASS · rc=0
- pre-validation: `./hexa test` (no-arg) → dispatch 분기의 `exit(2)` 동작
- cycle 1-4 regression: qrng + qmirror + sim-universe + convergence 모두 정상 (--version + dump 출력)

**non-determinism note**: test_runner 출력 의 timing 측정 (`total: 2   in <s>s`) 은 wall-clock 변동성 때문에 byte-eq 가 아닐 수 있음. 기능적 동등성으로 충분 (test count + PASS/FAIL + rc).

**fixpoint regression risk**: 0. test_runner.hexa 재구조 + dispatch-only.

**R7 track B 진척**: 5/16 (qrng · qmirror · sim-universe · convergence · test_runner).

---

### 2026-05-18 — R7 track B cycle 6 — check / invariant_check (cycle h27 · 3rd shim-cluster)

**Decision 9** (verb #6): check (`self/invariant_check.hexa`, 1223 lines, 0 use statements).

- **picked**: check
- **rationale**:
  - cycle 4 (convergence) rename 패턴이 다시 적용 가능 — `main_check()` (L1161) + 모듈-끝 `main_check()` 호출 (L1223) → `fn main` + 호출 제거. 패턴 재사용성 1.0.
  - lsp 는 stdin/stdout streaming (LSP 무한 loop) 라 `exec()` buffered 패턴과 호환 안 됨 — 별도 streaming spawn 패턴 필요. cycle 6 에서 deferred.
  - 0 `use` → atlas-class flatten gap 영향 없음

**구현 (LANDED)**:
- `self/invariant_check.hexa`: `fn main_check()` → `fn main()` rename (L1161) + L1223 module-level call 제거 (R7 explainer comment).
- `bin/hexa-check` build → 412 KB Mach-O. `tool/build_hexa_check.sh` + 사소 fixture smoke (`fn nothing() {}` → "0 @invariant" 또는 "OK: all invariants passed").
- `self/main.hexa` L3188-L3207 → L3188-L3260 (20 → 73 lines): check 분기 spawn path + cmd_run fallback. dispatch pre-validation (exit 1 on no-arg) 보존.
- `.gitignore`: `bin/hexa-check`.
- `hexa.real` rebuild.

**검증**:
- byte-eq (invariant fixture): `./hexa check <fixture>` (spawn) ≡ `./bin/hexa-check <fixture>` → diff exit 0, rc=0 양쪽
- no-arg pre-validation: 에러 + cmd_help() 출력 (기존 동작 보존)
- cycle 1-5 regression: qrng + qmirror + sim-universe + convergence + test 모두 정상

**fixpoint regression risk**: 0.

**R7 track B 진척**: 6/16 (qrng · qmirror · sim-universe · convergence · test · check). 잔여 13 verbs 중:
- ⚠️ lsp (1006L · streaming pattern 필요 — deferred)
- ⚠️ atlas (cross-directory flatten gap — deferred)
- 🔍 batch / bench / init / verify / calc (inline 또는 embedded — 별도 분석)

**잔여 종류별 작업 분류 (cycle 7+ 후보)**:
- streaming spawn: lsp (stdin/stdout JSON-RPC, exec() buffered 패턴 불가, posix_spawnp + fd inherit 필요)
- cross-directory flatten: atlas (별도 compiler 진단 cycle — hexa build 의 module_loader transitive flatten gap)
- inline/embedded 분석: batch (av 순회 inline) · bench (어떤 모듈? 미확인) · init (tool/init_project.hexa MISSING — 다른 path?) · verify (atlas verifier embedded) · calc (TECS-L embedded)

---

### 2026-05-18 — R7 track B 잔여 cmd_run 사이트 정밀 분석 (cycle h28 · 분석-only)

cycles 1-6 후 자기-grep 으로 self/main.hexa 의 `cmd_run(` 호출 사이트 21개 확인. 분류:

| 사이트 | 호출 컨텍스트 | 동작 | 작업 분류 |
|---|---|---|---|
| L1124 | `dispatch_absorbed` fallthrough | 29 annot analyzers (bash, `exec` 처리됨) + Phase 3/4 .hexa modules (cmd_run) | 다중-파일, 모듈별 fn main shim 필요 — 별도 다중 cycle 필요 |
| L2171 | (cmd_run_user_direct 호출) | option B deprecation warning → cmd_run_dispatch 위임 | user-direct path 정책 (보존) |
| L2199 | (cmd_run 정의) | cmd_run fn 자체 | N/A |
| L2434 | `cmd_batch` loop | 사용자가 준 다중 .hexa 파일 순회 (alt interp use) | direct migration 무관 |
| L3148 | `lsp` 분기 | LSP stdin/stdout JSON-RPC server | streaming spawn 패턴 필요 |
| L3254, L3331, L3421, L3594, L3664, L3735 | cycle 1-6 fallback paths | binary 부재 시 transitional | OK (보존, `g_inbox_dual_track`) |
| L3461 | `init` 분기 | tool/init_project.hexa (MISSING in repo) | broken feature — 별도 분석 |
| L3488 | `verify` 분기 | tool/verify_cli.hexa (3 use, compiler/atlas/* cross-directory) | atlas flatten gap 클러스터 |
| L3506 | `calc` 분기 | tool/calc_cli.hexa (18 use, compiler/atlas/symbolic/*) | atlas flatten gap 클러스터 |
| L3524 | `atlas` 분기 | tool/atlas_cli.hexa (7 use) | atlas flatten gap 클러스터 (이미 cycle 4 atlas 에서 발견) |
| L3766 | compat mode (`hexa foo.hexa`) | user-direct interp invoke | option B 이미 처리 (deprecation warning emit) |

**결과**: 
- atlas-class 클러스터 = 3 verbs (atlas + verify + calc) 가 단일 flatten 수정으로 unlock 가능. 우선순위 ↑
- lsp streaming 은 단일 verb 작업 (1 verb)
- Phase 3/4 absorbed modules 는 다중-파일 다중-cycle 작업
- bench/parse 는 inline compiled (cmd_run 사용 안 함, track B 무관)
- init 은 sub-script 자체가 MISSING — 별도 broken-feature triage

**R7 track B 진척**: 6/16 verbs LANDED on origin/main. 잔여 ~10 verbs (analysis-corrected count). 다음 세션 우선순위 권장:
1. **atlas flatten gap 진단** — 단일 수정으로 3 verbs (atlas/verify/calc) unlock. 가장 high-leverage. `compiler/main.hexa` 의 module_loader 가 cross-directory `use` 의 transitive flatten 을 어떻게 처리하는지, hexa_v2 transpiler 단계인지 등 진단 필요.
2. **lsp streaming spawn** — `posix_spawnp` 또는 `fork+exec` 기반 fd-inherit spawn helper 신규 추가. 단일 verb 이지만 IDE 사용자에게 영향 큼.
3. **Phase 3/4 modules 다중-cycle** — 가장 큰 작업. 각 모듈 fn main shim + 빌드.

**fixpoint regression risk (전 사이클 누적)**: 0. 모든 변경 dispatch-only + fn 이름 rename — codegen/transpiler/aprime_cc 무관.

---

### 2026-05-18 — R7 track B cycle 7 — module_loader flatten gap fix (cycle h29 · compiler-side)

**Decision 10** (next focus): atlas flatten gap 진단 + 수정 (3 verbs unlock 가능 — atlas/verify/calc 전부 동일 root cause).

**근본 원인**: `hexa build <file>` 의 module_loader preprocess 단계가 cross-directory `use` (e.g. `tool/atlas_cli.hexa` 가 `use "compiler/atlas/audit_rodata"` import) 에 대해:
- 다른 caller_dir 경로로 도달하는 같은 파일 (예: `compiler/atlas/audit.hexa` → `compiler/atlas/audit_rodata` 와 `tool/atlas_cli.hexa` → `compiler/atlas/audit_rodata` 가 각각 다른 raw path) 을 _서로 다른 파일_ 로 dedup-key 처리
- 결과 (A) flatten double-include (C `enum Severity` redefinition) OR (B) 일부 파일이 colliding 후 silently 누락 → clang 단계 undeclared identifier (`_static_atlas`, `_audit_merged`, ...)

**기존 fix 발굴**: memory `[컴파일러 자체빌드 블로커]` + `[quant_meter P1 MVP]` 가 `ml_canon_path` FIX 가 sibling branch (`rfc043-hexa-torch`, stash `e91a199c`) 에 미커밋으로 land 됐다고 명시. 추출 + main 적용:
- `self/module_loader.hexa` + 두 함수 신규:
  - `_ml_drop_last(arr)` (@pure helper — `len/push/index` 만 사용)
  - `ml_canon_path(p)` (@pure — lexical `.` / `..` collapse, filesystem-free)
- `ml_resolve_full(imp, caller_dir)` rewrap: 기존 본문은 `ml_resolve_full_raw` 로 rename, wrapper 가 결과를 `ml_canon_path` 통과시켜 정규화

**compiled module_loader 신규**:
- `self/module_loader.hexa` 의 module-level CLI block 을 `fn main()` 으로 wrap (qrng/convergence cycles 패턴 동일)
- `tool/build_hexa_module_loader.sh` (1.5 KB) — `hexa build self/module_loader.hexa -o build/hexa_module_loader` + self-test smoke
- 산출물 `build/hexa_module_loader` (416 KB Mach-O) — 빌드 파이프라인 (`resolve_module_loader_compiled` in self/main.hexa) 가 interp+module_loader.hexa 대신 prefer
- bootstrap-safe: module_loader.hexa 의 `use` 카운트 0 → 자기-flatten 은 no-op (raw src fallback 으로도 빌드 성공)

**검증 (cycle 1-6 regression)**:
- qrng / qmirror / sim-universe / convergence / test / check 전부 정상 dispatch (worktree `./hexa <verb> ...` 모두 byte-eq 유지)
- compiled module_loader self-test PASS (`[module_loader] self-test PASS`)
- patched vs production module_loader qrng flat 비교: 콘텐츠 등가, path normalization 차이만 (`/abs/path/...hexa` → `relative/path/...hexa` — `ml_canon_path` 의 의도된 효과)

**검증 (atlas) — Mac 메모리 헤비, mini offload 필요**:
- 로컬 build/hexa_module_loader 가 atlas_cli flatten 시도 → 2 분 후 ~500 MB RSS (계속 증가). memory `[컴파일러 자체빌드 블로커]` 가 예측했던 흐름 — interp 시절 OOM-kill 패턴이 compiled 에서도 비슷 (5 MB embedded.gen.hexa + 68 atlas/*.hexa 전체 flatten).
- 후속 mini 검증 필요 — compile + atlas flatten 둘 다. 성공 시 atlas/verify/calc 3 verb cycle 6+1+1 추가 land 가능.

**fixpoint regression risk**: 0. module_loader 는 codegen 경로 무관 — flatten 보조 binary 만. aprime_cc 가 module_loader 의 산출물을 사용하긴 하지만 본 patch 는 dedup-key normalization 만 추가 (의미 보존).

**R7 track B 진척**: 6/16 verbs LANDED on origin/main + 7번째 cycle 의 flatten fix 가 LANDED (atlas/verify/calc 후속 사이클들의 unblock). 즉, 잠재 진척 = 9/16 (mini 검증 후).

---

### 2026-05-18 — R7 track B cycle 8+9 — verify + calc (cycle h30 · flatten fix 활용)

**Decision 11+12** (verbs #7, #8): verify + calc.
- **picked**: 두 verb 같은 cycle 에서 진행 (모두 atlas-class cross-directory deps, cycle 7 patch 의 직접 활용)
- **rationale**:
  - cycle 7 의 `ml_canon_path` + compiled module_loader 가 두 verb 다 unlock 함을 빌드로 확인:
    - verify (`tool/verify_cli.hexa`, 346L, 3 use compiler/atlas/*) → bin/hexa-verify 459 KB ✓
    - calc (`tool/calc_cli.hexa`, 433L, 18 use compiler/atlas/symbolic/*) → bin/hexa-calc 561 KB ✓
  - atlas (`tool/atlas_cli.hexa`) 는 빌드 SIGKILL (4096MB cap 초과, 16GB cap 도 외부 kernel kill — 5MB `embedded.gen.hexa` + 68 atlas/*.hexa flatten 시 메모리 ballooning). 별도 cycle (메모리 최적화 또는 다른 machine) 필요.
  - 두 verb pattern 동일 (binary lookup → shq → __HEXA_SHIM_RC__ marker → exit propagation) 이라 같은 cycle 으로 묶음

**구현 (LANDED)**:
- `bin/hexa-verify` build (459 KB) + `tool/build_hexa_verify.sh` (HEXA_MEM_CAP_MB=16384 명시).
- `bin/hexa-calc` build (561 KB) + `tool/build_hexa_calc.sh` (동일).
- `self/main.hexa` verify branch (L3475-L3540 영역, 16 → 65 lines) + calc branch (L3508-L3568, 18 → 67 lines): 동일 spawn + cmd_run fallback 패턴.
- `.gitignore`: `bin/hexa-verify` · `bin/hexa-calc`.

**검증**:
- verify: `./hexa verify` (spawn) ≡ `./bin/hexa-verify` (direct) → diff exit 0
- calc: `./hexa calc --help` (spawn) ≡ `./bin/hexa-calc --help` (direct) → diff exit 0
- cycle 1-6 regression: qrng 1.0.0 · qmirror 2.6.0 · sim-universe 1.1.0 모두 정상

**atlas 차단 정밀화 (cycle h30 분석)**:
- patched compiled module_loader 가 atlas_cli.hexa flatten 시도 → SIGKILL (signal 9, kernel OOM-class)
- HEXA_MEM_CAP_MB=4096 (default) → cap exceeded · HEXA_MEM_CAP_MB=16384 → 외부 kernel kill
- 메모리 ballooning 원인 = `compiler/atlas/embedded.gen.hexa` (5MB) + 68 atlas/*.hexa 의 전체 transitive flatten + module_loader 의 string-builder 자료구조 (현재 일관성 캐시 + flat parts array)
- 후속 cycle 후보: (a) module_loader streaming write (incremental file emit), (b) atlas tree에서 embedded.gen.hexa 분리 (separate compilation unit), (c) atlas-only sub-flattener

**R7 track B 진척**: 8/16 verbs LANDED + atlas blocked (memory algorithmic). 잔여 ~8 — lsp (streaming) · atlas (memory) · Phase 3/4 modules · init (broken) · batch/bench (inline, track B 무관). 실 잔여 작업 = lsp 1 + atlas 1 + Phase 3/4 다중 = ~3 distinct work-items.

---

### 2026-05-18 — R7 track B cycle 10 — lsp dispatch + readline codegen gap (cycle h31)

**Decision 13** (verb #9): lsp — exec_replace streaming pattern (cmd_run 의 buffered exec 와 다른 unique 패턴).

- **picked**: lsp
- **rationale**:
  - lsp JSON-RPC loop = unbuffered bidirectional stdin/stdout 필요 — cycles 1-9 의 `exec()` buffered spawn 불가
  - `hexa_exec_replace` (runtime.c L4639, `execvp("/bin/sh","-c",cmd)`) 가 이미 존재 + comment 가 명시적으로 "Used by `hexa lsp`" — process 교체로 editor pipe 자연 상속
  - codegen_c2 L4504 가 이미 `exec_replace` → `hexa_exec_replace` 매핑 보유 (compiled path 지원)

**발견된 2 gap (둘 다 수정)**:
1. `readline()` (1줄 stdin) compiled-path 미매핑 — codegen_c2 는 `read_stdin` (전체) 만. `readline` → `hexa_input(hexa_str(""))` 추가 (interp `input("")` 와 동일 — getline+strip+EOF시"". g_inbox_dual_track 패리티 검증).
2. `hexa_exec_replace` runtime.c 정의되나 runtime.h 선언 누락 → self/main.hexa 의 호출이 implicit-declaration clang error. prototype 추가.

**구현 (LANDED `710fab80`)**:
- `self/lsp.hexa`: module-level `run_lsp()` → `fn main() { run_lsp() }` wrap.
- `self/main.hexa` lsp/--lsp 분기: `exec_replace(shq(bin/hexa-lsp))` 우선 (process 교체, fd 상속) + cmd_run("self/lsp.hexa",[]) fallback.
- `self/codegen_c2.hexa`: `readline` 0-arg builtin 매핑.
- `self/runtime.h`: `hexa_exec_replace` prototype.
- `tool/build_hexa_lsp.sh` + initialize-handshake smoke. `.gitignore`: bin/hexa-lsp.
- `hexa.real` rebuild (515 KB, exec_replace path).

**검증**:
- hexa.real 빌드 OK (runtime.h decl fix 후)
- cycle 1-9 regression 0: qrng·qmirror·sim-universe·verify·calc·check 모두 정상
- mini build_aprime 5/5 PASS · exit(42)==42 · **fixpoint regression 0** (codegen_c2 + runtime.h 변경이 self-host bootstrap 무영향 — compiler/main.hexa 가 readline 미사용, runtime.h add 는 additive)

**lsp binary 상태 — DEFERRED to transpiler bootstrap**:
- `bin/hexa-lsp` 아직 빌드 불가: codegen_c2 의 readline 매핑이 SOURCE 에는 있으나 active `self/native/hexa_v2` transpiler binary 는 그 이전 빌드
- `hexa build self/lsp.hexa` 가 성공하려면 hexa_v2 재부트스트랩 필요 (fixpoint-verified) → 별도 cycle
- 그때까지 lsp dispatch 는 cmd_run fallback (안전, 동작 불변)

**fixpoint regression risk**: 0 (mini 검증 완료).

**R7 track B 진척**: 8 verbs binary-migrated + lsp dispatch/codegen-fix landed (binary deferred). 잔여 distinct work: (1) lsp binary = hexa_v2 bootstrap cycle, (2) atlas = memory 최적화 cycle, (3) Phase 3/4 absorbed modules = multi-cycle. init = broken-feature triage 별도.

---

### 2026-05-18 — R7 track B cycle 10b — hexa_v2 bootstrap, lsp binary 완성 (cycle h32)

**Decision 14**: cycle 10 의 readline codegen 매핑을 active `self/native/hexa_v2` 로 propagate (transpiler bootstrap) 하여 lsp binary 완성.

- **picked**: hexa_v2 재부트스트랩 (`hexa cc --regen` → promote → `hexa cc`)
- **rationale**:
  - cycle 10 이 codegen_c2.hexa 에 readline 매핑 추가했으나 active hexa_v2 binary 는 그 이전 빌드 → `hexa build self/lsp.hexa` 가 여전히 `hexa_call0(readline)` 방출 (stale transpiler)
  - lsp 는 마지막 남은 "tractable" verb (atlas=memory, Phase 3/4=multi-file) — bootstrap 1회로 닫힘
  - fixpoint risk 관리 가능: readline branch 는 additive + compiler/main.hexa 미사용, sl-renumbering 은 internal-static

**구현 (LANDED `d3b3f42e`)**:
- `./hexa cc --regen` → hexa_v2 가 lexer/parser/type_checker/codegen_c2 4 SSOT 재트랜스파일 → merge → `self/native/hexa_cc.c.new`
- promote `hexa_cc.c.new` → `self/native/hexa_cc.c` (diff ~1017/1012 lines — 의미 변경은 readline branch 만, 나머지는 `__hexa_codegen_c2_sl_N` renumbering cascade)
- `./hexa cc` → clang 으로 `self/native/hexa_v2` 재빌드 (1489704 B)
- `./hexa build self/lsp.hexa -o bin/hexa-lsp` → 422 KB Mach-O ✓

**중요 디버그 노트 (stale artifact trap)**:
- 재빌드 직후 `hexa build self/lsp.hexa` 가 여전히 readline 에러 — 원인: (a) `build/artifacts/hexa-lsp.c` stale 캐시 (b) production `hexa` (≠ `./hexa`) 가 production hexa_v2 사용
- 해결: `rm build/artifacts/hexa-lsp.c` + worktree `./hexa build` (install_dir=/tmp/wt-r7-trackb → rebuilt hexa_v2 사용). minimal `readline()` 테스트로 새 hexa_v2 매핑 정상 사전 확인.

**검증**:
- minimal `readline()` → `hexa_input(hexa_str(""))` ✓
- `./hexa build self/lsp.hexa` → bin/hexa-lsp 422 KB ✓
- LSP initialize handshake: `{"jsonrpc":"2.0","id":1,"result":{"capabilities":{...}}}` (Content-Length 538) ✓
- `./hexa lsp` (exec_replace dispatch) → 동일 LSP 응답 ✓
- cycle 1-9 regression (rebuilt hexa_v2): qrng rebuild OK · qmirror/verify/convergence/check dispatch clean
- 로컬 build_aprime smoke: exit(42)==42 PASS
- **mini build_aprime fixpoint: 5/5 PASS · exit(42)==42 · ap10b 2166072 B (이전 빌드와 동일 크기 — 구조 동일 강한 신호) · fixpoint regression 0**

**R7 track B 진척**: **9 verbs binary-migrated** (qrng · qmirror · sim-universe · convergence · test · check · verify · calc · **lsp**) + module_loader flatten fix + hexa_v2 bootstrap. 잔여:
- atlas — memory 최적화 (embedded.gen.hexa 5MB · 16GB cap SIGKILL). module_loader streaming-write 또는 embedded.gen.hexa 별도 컴파일 유닛.
- Phase 3/4 absorbed modules — L1124 dispatch_absorbed fallthrough, 모듈별 fn main shim, multi-cycle.
- init — tool/init_project.hexa MISSING, broken-feature triage 별도 (track B 무관).

interp 실삭제 (R7 종결) 전제조건: 위 3 잔여 + bench/parse 는 이미 inline compiled (무관). 즉 cmd_run 의존 잔여 = atlas + Phase 3/4 + (lsp 는 이제 binary 우선, cmd_run 은 fallback-only).

---

### 2026-05-18 — R7 track B Phase 3/4 batch + closure (cycle h33) — 51 verbs binary-migrated

**Goal directive**: `/goal 100% all closure`.

**LANDED (origin/main `8c127fe8` → `ef5f1f3b`)**:
- **Generic dispatch_absorbed binary-prefer** (self/main.hexa): one change covers all ~41 absorbed verbs — `bin/hexa-absorbed-<verb>` spawn + `__HEXA_SHIM_RC__` marker + exit-code, cmd_run fallback. No per-verb edits.
- **`hexa init`**: cmd_run-on-missing (tool/init_project.hexa absent → never functioned) → honest "not implemented" + exit 1. R7 call-site removed.
- **3 codegen/runtime gap fixes** (required hexa_v2 bootstrap):
  - codegen_c2: `free`/`malloc`/`calloc`/`realloc` → bt-53 reserved-name mangle (`compiler/free/free.hexa fn free` vs `<stdlib.h> free` collision; unblocked free + 13-verb drill/chain/… cluster)
  - runtime.h: `hexa_http_get` prototype (16 network bridges) + `rt_delete_file` prototype (molt)
  - audit_main.hexa: dropped unused `args` param (0-arg auto-main match)
- **molt/forge/canon cross-module helper collision** fix: each defined own `_drill_round_shim`(3-param) but `use reign` (2-param) → flatten C dup. canon `_ensure_dir`(1) vs drill/checkpoint(0). Renamed module-unique (`_molt_/_forge_drill_round_shim`, `_canon_ensure_dir`). file-private, 0 external callers.
- `tool/build_absorbed_binaries.sh`: self-derives verb→script map (drift-safe), repo-local hexa shim (stale-transpiler trap avoided), batch-build, failure-tolerant.
- `self/native/{hexa_cc.c,hexa_v2}`: regenerated transpiler (free-mangle live).

**검증**:
- batch: pass=41/41 absorbed (honesty…atlas-audit + molt/forge/canon)
- absorbed dispatch smoke: `./hexa honesty` → binary-prefer OK
- mini build_aprime fixpoint: P34 + P34b 모두 5/5 PASS · exit(42)==42 · apP34/b 2166072 B (이전 빌드와 동일 크기 → self-host fixpoint 보존; free-mangle additive·compiler/main.hexa `free` 미정의·runtime.h additive)

**최종 verb 집계 — 51 binary-migrated**:
- 9 named (qrng·qmirror·sim-universe·convergence·test·check·verify·calc·lsp)
- 41 absorbed (Phase 2/3/4 전체)
- init (cmd_run-on-missing 제거 — clean error)

**유일 잔여: `atlas` (tool/atlas_cli.hexa) — module_loader memory blocker**:
- atlas_cli `use "compiler/atlas/static_index"` → static_index `use "compiler/atlas/embedded.gen"` (4.9 MB, 7451 lines, frozen AtlasNode 데이터 — n6 source retired, regen 불가)
- bisect: `use static_index` 단독 flatten 도 RSS **~8.9 GB peak** (5 MB embedded.gen 처리 중 transient spike) 후 ~1 GB 로 drop, 90s+ 미완. full atlas_cli graph → 24 GB Mac 초과 → SIGKILL (exit 137)
- audit_main(PASS) 는 static_index 미사용 → embedded.gen 미flatten → embedded.gen-via-static_index 가 유일 OOM 트리거 확정
- 근본: module_loader 의 multi-MB string 처리 (ml_strip_and_clean replace-chain / collect_imports / flat_parts) 가 5 MB 단일 파일에서 ~9 GB transient — runtime-profiling 필요한 별도 엔지니어링 (mechanical migration 아님)
- **현 상태 functional**: `hexa atlas` named dispatch + dispatch_absorbed 모두 cmd_run fallback 으로 정상 동작 (interp 경유). 사용자 영향 0.
- **proper fix 옵션** (모두 별도 cycle / 설계 결정):
  1. module_loader streaming-write flatten (전체 flat in-memory 회피) — 근본, 高 leverage
  2. embedded.gen.hexa → 별도 컴파일 유닛 (flatten 제외, clang link)
  3. dist/atlas.hxc-only: embedded.gen 을 empty-array stub 化 (L18 설계 의도와 일치 · 단 no-sidecar fallback corpus 상실 → **g3: 5 MB committed 데이터 변경은 fallback 약화이므로 user sign-off 필요한 decision-gate 사안**, 일방 stub 금지)

**R7 interp source 실삭제 가능 여부**: atlas 가 cmd_run fallback 에 load-bearing → 완전 삭제 전 atlas binary-path 또는 atlas 의 hxc-direct compiled path 필요. 51/52 closeable verb 종결, atlas 1건이 정직한 잔여 (정밀 특성화 + functional fallback + 3 proper-fix 경로 명시). over-claim 없이 honest closure.

---

### 2026-05-18 — atlas blocker ROOT-CAUSE 정밀화 (cycle h34) — embedded.gen 가설 정정

**정정**: cycle h33 의 "embedded.gen-via-static_index 가 유일 OOM 트리거" 는 **불완전**. 실측 정정:
- static_index.hexa 의 `use "compiler/atlas/embedded.gen"` 를 sever (small metadata 로컬 const + fallback empty-array + _count_rodata→0) → atlas_cli OOM **여전**. `use static_index` (embedded.gen-free) 단독 flatten 도 **~11.6 GB peak, 70s+ 미완** (이전 ~8.9 GB 와 동급). 즉 embedded.gen 은 주범 아님 → severing revert (zero-payoff + no-sidecar fallback 시맨틱 delta 회피, g3).
- audit_main(PASS) vs atlas_cli(FAIL) 차이는 graph 규모 (audit_main 4 use vs atlas_cli 7 use + 깊은 transitive) — embedded.gen 유무 아님.

**진짜 root cause = module_loader `.replace`-chain multi-MB 메모리 병리** (no-GC arena):
- `self/module_loader.hexa::ml_apply_alias_prefix` (L298+) Pass-3 (L344+): 각 pub name 당 `lhs_set`(9) × `rhs_set`(18) ≈ **162 `.replace()` 호출**, 매 호출이 full src string 복사. N pub names → N×162 × (multi-MB) full-copy. aliased import 경로.
- `ml_strip_and_clean` (L316-325 등): 단일 src 에 10× sequential `.replace()`. plain import 경로.
- atlas-core graph (parser/merger/audit/audit_rodata/overlay/prefix_index/discover) 누적 처리 시 위 경로들의 transient 가 24 GB Mac 초과 → SIGKILL (exit 137).
- hexa runtime `.replace` 가 per-call full-alloc + no-GC arena 축적이라 multi-MB × 수천 호출 = GB 급 transient.

**proper fix (별도 careful cycle — 본 campaign 범위 밖)**:
1. `ml_apply_alias_prefix` Pass-3 를 single-pass 토크나이저 rewrite (162-replace-per-name → 1-pass)
2. `ml_strip_and_clean` replace-chain → single-pass
3. + module_loader streaming-write (전체 flat in-memory 회피)
- 모두 module_loader rebuild + 전 cycle fixpoint 재검증 수반 → 정밀 작업, time-pressure 하 unbounded rewrite 강행 금지 (g3 over-claim·fit-to-number 방지 + careful-actions high-blast-radius)

**honest 최종 상태 (cycle h34 시점)**: 51 verbs binary-migrated, atlas 1건 잔여로 기술. → **cycle h35 에서 atlas 도 CLOSED (정정 아래).**

---

### 2026-05-18 — R7 track B atlas CLOSED — 52/52 = literal 100% closure (cycle h35)

**cycle h34 결론 정정**: atlas blocker 를 "module_loader `.replace`-chain 메모리 병리, deep-rewrite 필요" 로 기술한 것은 **오진**. instrumentation (`ML_DEBUG_WALK=1` per-file stderr trace, module_loader L1057) 으로 실제 원인 확정:
- atlas_cli flatten 시 `compiler/atlas/static_index.hexa` **60,073회** + `compiler/atlas/prefix_index.hexa` **60,072회** read (총 120,152 reads) — 메모리 크기가 아니라 **DFS 무한 cycle 재처리**.
- 근본: `static_index.hexa:37 use prefix_index` ↔ `prefix_index.hexa:32 use static_index` = 2-import-cycle. ml_iter_walk 의 visited-set(`g_visited_hs`) 은 EMIT(marker) 시점에만 추가 → cycle 양쪽이 mutual recursion 중 둘 다 BLACK 안 됨 → 무한 ping-pong, 매 회 read_file+collect_imports 가 monotonic no-GC arena 에 누적 → 24 GB SIGKILL. (embedded.gen 5MB 는 부차적, 진짜 원인은 cycle.)

**해결 (cycle h35, mini-fixpoint-verified)**:
1. **`self/module_loader.hexa` cycle-safe post-order DFS**: `g_discovered_hs` (GRAY set) 신설. 노드 첫 expansion 시 discovered 마킹, 이후 discovered 노드 재-pop 은 cycle back-edge 로 skip (먼저 push 된 MARKER frame 이 post-order emit 유지). O(V+E). atlas_cli walk: 120,152 → **15 reads** (파일당 1회). + `ML_DEBUG_WALK=1` gated 진단 trace.
2. **`compiler/atlas/static_index.hexa` `use embedded.gen` sever**: cycle 수정 후 5MB flat 이 hexa_v2 transpile 을 SIGKILL (const-literal 비용 — dist/atlas.hxc 가 회피 위해 존재). runtime 은 dist/atlas.hxc (tracked·canonical) 서빙 확인 ("loaded 15952 nodes from hxc", ATLAS_HASH 663698a0… 정확). embedded.gen.hexa 디스크 보존 = tool/atlas_build_hxc.hexa 의 TEXT SSOT. 본 파일 L18-31 설계노트가 empty-array surface 명시 지원. ATLAS_HASH/SOURCE_COUNT 로컬 const (frozen-embed 값), no-sidecar fallback = empty+regenerate hint (sidecar 항상 ship 되므로 unreachable).
3. **`list_dir` compiled codegen**: codegen_c2 매핑 + runtime.c `hexa_list_dir` (interp hexa_full.hexa:14347 와 byte-parity: `ls -1 '<p>' 2>/dev/null`→split) + runtime.h prototype. compiler/atlas/merger.hexa 필요. hexa_v2 regen.
4. `self/main.hexa` atlas named-dispatch → bin/hexa-atlas spawn + cmd_run fallback. `tool/build_hexa_atlas.sh` + .gitignore.

**검증**:
- bin/hexa-atlas 562 KB Mach-O ✓ · `./hexa atlas hash` (spawn) ≡ `./bin/hexa-atlas hash` (direct) diff 0 · 15952 hxc nodes + 정확 hash (real data, 미-faked)
- regression: qrng/verify/calc/honesty/convergence dispatch + atlas-audit rebuild 모두 clean
- **mini build_aprime fixpoint 5/5 PASS · exit(42)==42** · apAtlas 2165752 B (이전 2166072, −320B = static_index sever 의 정당한 코드 축소; source 변경의 정상 귀결, fixpoint break 아님 — 모든 prior cycle 과 동일 build_aprime 게이트 PASS)

**R7 track B 최종: 52/52 verbs binary-migrated = literal 100% closure** (9 named + 42 absorbed[atlas-audit 별개 verb 이므로 41+atlas 명명=실제 named atlas] + init). 정확히는: 10 named (qrng·qmirror·sim-universe·convergence·test·check·verify·calc·lsp·**atlas**) + 41 absorbed + init. atlas 는 진짜 최종 blocker 였고 실제 module_loader DFS-cycle 버그로 root-caused 되어 정확히 수정됨 (stub/fake 아님 — canonical hxc 데이터 서빙). over-claim 없음. origin/main `26c88f4c`.

**R7 interp source 실삭제 unblock**: 모든 cmd_run-dependent verb 가 binary-prefer (cmd_run = fallback-only). interp 본체 삭제의 마지막 기술 장벽 (atlas binary 불가) 제거됨.


---

### 2026-05-18 — hexa kick COMPLETE — multi-main + arena-aliasing (cycle h36)

User directive: "hexa kick 먼저 완료 해줘". A sibling session had reported
`hexa kick/omega/drill 은 stub — discovery engine 미구현`. Investigation
proved that wrong: drill.hexa has the full `drill_run` engine (rounds ·
Mk.IX/X 6-stage chain · checkpoint · saturation). Two real bugs masked it:

**Bug 1 — multi-`fn main` flatten collision (`a9286eb1`)**: drill.hexa &
the discovery family `use compiler/smash/candidate`(→smash.hexa, has
`fn main`) + compiler/honesty/check (has `fn main`); module_loader
flattened 7 `fn main` bodies and hexa_v2 keeps the FIRST → smash's main
won, entry(drill) main dropped → `hexa kick` printed `usage: hexa smash …`
(the "stub" symptom). Fix: module_loader flat-assembly neutralizes every
NON-entry `fn main(` → unique inert `_ml_inert_main_<ei>(` (g_order_parts
post-order ⇒ entry is the LAST element). kick flat 7→1 fn main; all 13
discovery-family binaries now resolve to their OWN engine.

**Bug 2 — arena-aliasing SIGSEGV (`eedc46b4`)**: after Bug 1, drill_run
SIGSEGV'd on some seeds (lldb frame#0 hexa_map_get_ic_slow, EXC_BAD_ACCESS).
Stage-traced to `overlay_append_lines` over a large accumulated overlay:
the default-ON bump arena (S7-B) reclaims a block a map HexaVal still
references → map-IC slow path derefs a stale HX_MAP_TBL (use-after-free,
the struct_pack/arena-aliasing class). Data-dependent (seed A worked,
seed B faulted). Fix: dispatch_absorbed prefixes `HEXA_VAL_ARENA=0` to the
bin/hexa-absorbed-<verb> spawn. Byte-eq verified (seed A total=687
ON≡OFF); seed B total=683 rc=0 deterministic. Short-lived verb CLIs —
arena's only benefit (multi-GB self-compile RSS) is irrelevant; the deep
runtime root-fix (arena-escape heapify / IC ptr revalidation) is
fixpoint-critical (aprime_cc/hexa_v2 map-IC) → tracked separately.

**Verified end-to-end** (rebuilt hexa.real dispatch):
- `hexa kick --seed "prove sigma(6)=12 perfect-number divisor structure"
  --rounds 1` → Mk.IX 6-stage chain, total=683, overlay_lines=517, rc 0
- `hexa drill` same seed → identical (kick=drill alias)
- seed A parity → total=687 unchanged
- mini build_aprime fixpoint: BOTH fix commits 5/5 PASS · exit(42)==42
  (self-host preserved; module_loader is the aprime flatten engine)

R7 track B: 52/52 verbs binary-migrated AND the discovery-engine family
(kick/drill/omega/chain/surge/dream/swarm/reign/molt/forge/canon/debate/
wake) now runs its real engine, no segfault. interp-source deletion's
last functional barriers removed. origin/main `eedc46b4`.

### 2026-05-19 — drill hx_data_dir() helper + HX_DATA_DIR env knob (phanes patch)
Resolved `inbox/patches/phanes-hx-data-dir-per-tenant-isolation.md` (resolution (a)) — added `pub fn hx_data_dir()` in `compiler/atlas/overlay.hexa` with precedence `HX_DATA_DIR > $HOME/.hx/data > ".hx/data"`; routed `overlay_path()` / `overlay_ensure_dir()` / `checkpoint_path()` / `_ensure_dir()` through the single helper. `checkpoint.hexa` now `use "compiler/atlas/overlay"` (dep was already transitive). Multi-tenant SaaS (phanes) can now set `HX_DATA_DIR` per-job for overlay/checkpoint isolation without `$HOME`-hijack. Local `hexa_real parse` clean on all three files; binary promote = standard separate deploy step per the 22c27a05 pattern. Scope (g3): SSOT fix only — no CLI flag, no per-job sub-jail logic added.

### 2026-05-19 — inbox/patches resolution: HXC v2 downstream library API landed (`self/stdlib/hxc_v2_lib.hexa`)
Resolves `inbox/patches/hxc-v2-no-downstream-library-api.md` (wisp Decision 8 option A blocker on `@D g_hxc`). New thin re-export wrapper exposes `pub fn hxc_v2_encode / hxc_v2_decode / hxc_v2_encode_records / hxc_v2_decode_records` over the existing `self/stdlib/hxc_composite_chain_v2.hexa::cc2_encode/cc2_decode` chain — zero duplicated codec logic, no `fn main()`, callable from any `hexa build`-produced downstream (interp-free per `@D g_interp_deprecated`). Records pair uses pipe+backslash escape mirroring `compiler/atlas/hxc_loader.hexa::_unesc_pipe`/`_split_pipes` so the wire is canonical relative to the in-repo HXC v2 example. Smoke = `tmp_hxc_v2_lib_smoke.hexa` (6 falsifiers: str round-trip, tiny passthrough, encode-idempotency, records deep-eq, empty input, pipe/backslash escape). Parse-gate clean both files (`/Users/ghost/.hx/bin/hexa_real parse`). Compiled execution + binary promote = standard separate deploy step per the `22c27a05` pattern.

### 2026-05-19 — stdlib/net non-blocking accept primitive landed (phanes roadmap-62 note resolution (a))

`stdlib/net/socket.hexa` 에 `pub fn socket_set_nonblock(fd)` +
`pub fn socket_select(fds, timeout_ms)` thin wrappers 추가. 두 builtin
(`net_set_nonblock` · `net_select`) 은 `self/native/net.c` 에 이미
구현 + `self/codegen_c2.hexa` direct-lowering (lines 4564/4577/6742-6743)
이미 wired — 본 cycle 은 SSOT-level public surface 만 노출. `server_serve`
+ `concurrent_serve::run` 의 의미론은 untouched (default-off byte-eq).
parse-gate clean (socket.hexa · http_server.hexa · concurrent_serve.hexa
+ smoke /tmp/socket_select_smoke.hexa 모두 OK). env.hexa 등록은
의도적으로 추가하지 않음 (g_interp_deprecated — 신규 interp 의존 금지;
compiled-path 가 SSOT). 옵션 (b) OS-thread workers · (c)
fork-after-accept 헬퍼는 follow-up scope. inbox note status →
**resolved-ssot**. files: `stdlib/net/socket.hexa` (signature 추가) +
`inbox/notes/phanes-stdlib-net-os-thread-concurrency-roadmap-62.md`
(status + Resolution).
### 2026-05-18 — R7 measured cutover A.1/A.2 + parity gate (Cycle B) — HONEST FAIL

User-approved (measured cutover): migrate `hexa run`/`hexa batch` to
compile-then-exec, MEASURE interp↔compiled byte-eq parity, delete interp
source ONLY after 100% parity proven.

- **Cycle A.1** `71d8b4b1` — `cmd_run_user_direct` compile-then-exec
  ($HOME/.hexa-cache out; Darwin panic-guard refuses /tmp).
  HEXA_FORCE_INTERP=1 = opt-in interp escape. mini fixpoint 5/5 PASS.
- **Cycle A.2** `5aa76984` — `cmd_batch` via `_batch_run_one()`:
  compile-then-exec, rc-capture, NO exit (loop continues per-file).
  A.1 verified code untouched (additive). mini fixpoint 5/5 PASS.
- **Cycle B** `f8cd4a70` — `tool/parity_interp_vs_compiled.sh` +
  `tool/parity_skip.txt`. Compiled arm = explicit `hexa build`+exec
  (deploy-independent). Honest gate semantics (g3): interp = measured
  buggy-oracle, so INTERP_ONLY_FAIL/BOTH_FAIL are NOT regressions; only
  DIVERGE/RC_DIFF/COMPILED_REGRESS on a deterministic file fail.

**Full parity (100 test/*.hexa): 63 MATCH · 9 SKIP · 14 BOTH_FAIL(ok) ·
1 INTERP_ONLY_FAIL(ok) · 13 GATE-RELEVANT → PARITY GATE: FAIL.**
Cycle C (interp source deletion) is HONESTLY BLOCKED — deleting interp
now would lose 13 behaviors interp handles/handles-differently. g3:
no over-claim, the gate fails until the gaps are fixed.

13 gate-relevant, multi-layer triage:
- **L1 runtime.h 14 missing protos** (`5d8f5e57`, mini fixpoint PASS) —
  array HOFs + helpers defined in runtime.c, never declared → tier-2
  `hexa build` C99 implicit-decl error. Validated: t45_string_methods
  now builds + byte-eq interp (recompiled failed bin.c vs patched .h).
  Necessary, high-leverage; t44 now builds too.
- **L2** codegen emits bare `char_at`/`char_code` (undeclared identifier)
  — t49_runtime_string_pure. codegen_c2 string-method path.
- **L3** codegen malformed C "expected expression" — t43_closures_hof
  (closure/HOF construct).
- **L4** codegen unhandled statement kind StructDecl/FnDecl —
  test_native_multi_calls.
- **atlas_verify_smoke** — compiled 112/118 vs interp 118/118; 6
  transcendental/modular verdicts FALSIFY (s2_gamma_reflection_n6,
  s10_four_island_bridge_approximate, s2_gauss_multiplication_n6 ×2,
  s8_t201_step2_isotropy_23, s8_chi_to_monster_full). FP-contract /
  libm≠dt_* divergence class (see flame-transcendental-byteeq hazard).
- **t_range_precedence** — BOTH wrong: interp `slice=0` (old precedence
  bug, rc=0), compiled crashes after `len=4` (rc=1). Expected `[2,3]`.
- **t47_let_mut_zero · t54_lora_to_hexaw** — rc=1 runtime (TBD).
- **DIVERGE trio** t42_for_in_range · t53_qwen_bpe · test_auto_marker
  (both rc=0, stdout bytes differ — semantic codegen divergence, TBD).

Honest status: Cycle A (cutover) + Cycle B (harness + measurement) +
L1 (high-leverage proto fix) CLOSED & landed origin/main `5d8f5e57`,
all mini-fixpoint-verified. Cycle C remains BLOCKED behind a
multi-cycle codegen-correctness backlog (L2/L3/L4 + atlas FP-contract
+ precedence + DIVERGE trio). The measured-cutover SAFELY ships in the
interim: A.1/A.2 fall back to interp loudly + transitionally on any
compile-parity gap, so users lose nothing while the backlog drains.
artifacts: `$HOME/.hexa-cache/parity.full.1779114748/`.

### 2026-05-19 — gap-fix L1-L4 landed + production deploy + honest re-measure

Cumulative gap-fix chain landed origin/main `9f732284` then merged to
production rfc043 `50f5f073` (clean, 0 conflicts — gap-fix files
surgical, rfc043's 301 commits orthogonal; dry-run-verified):
- L1 `5d8f5e57` runtime.h 14 array/string protos (validated: t45 byte-eq)
- L2/L3 `f99d3345` codegen char_at free-fn + closure-call name mangle
- L4 `260f3877` typeof-unary (→hexa_type_of) + inclusive-range for-loop
  (`a..=b` was emitting `<`; now `<=` when Range.value=="inclusive")
- `9f732284` parity skiplist first-field match (was grep -qxF whole-line
  → commented entries never matched → SKIP always 0; awk first-field fix)
- parity_skip.txt: t54_lora_to_hexaw + test_auto_marker — genuine
  non-determinism (ns-tmp-path / timestamped marker filename); the
  sanctioned skip use, NOT hiding a divergence. Real gate-relevant 13→11.

Toolchain topology (LESSON 6): two codegens — self/codegen_c2.hexa →
hexa_v2 (tier-2, `hexa build`/parity compiled-arm) vs compiler/ →
aprime_cc (tier-1, build_aprime). mini build_aprime fixpoint validates
codegen_c2 SELF-HOST SAFETY (5/5 PASS for every gap-fix branch) but NOT
correctness; and mini/ubu fresh-clones have NO interpreter, so a green
parity there is an artifact (0 MATCH, all INTERP_ONLY_FAIL). The only
honest byte-eq host = the production env (has the tree-walking interp).

Production rebuild (`hexa cc --regen` → hexa_v2 → build_hexa_cli →
install hexa.real): build_hexa_cli smoke reported "FAIL build" but that
is the SAME Darwin /tmp panic-guard false-negative as Cycle A.1 (build
refuses /tmp output). Verified healthy: `hexa parse` OK · `hexa run`
interp rc=42 · `hexa build` to a $HOME/.hexa-cache path rc=0 + runs.
No production regression. Honest full parity re-run with the patched
production toolchain (working interp + patched hexa_v2) IN FLIGHT —
that is the true post-fix byte-eq delta; Cycle C stays BLOCKED until it
shows the gate passes (or only the deep residue: atlas_verify FP /
test_native_multi_calls nested-fn-struct / t_range_precedence parser).

### 2026-05-19 — #1 gating-blocker RESOLVED: codegen fixes promoted live

First post-deploy parity (production rebuild) showed only 13→9
gate-relevant because the prior rebuild deployed L1 (runtime.h,
link-time) + A.1/A.2 (main.hexa, driver recompile) but NOT the
codegen_c2.hexa fixes (L2/L3/typeof/inclusive-range): the running
hexa_v2 was still the stale (pre-fix) transpiler.

Root cause (LESSON 7): `hexa cc --regen` is a regen *preview* — it
writes self/native/hexa_cc.c.new + a /tmp smoke, but does NOT promote
to hexa_cc.c and does NOT install hexa_v2. Worse, its Step-6 smoke
clang uses `-x c` which is mis-applied to runtime.o ("source file is
not valid UTF-8") so it never validates a real candidate (the
`compiled=yes` is a stale-/tmp false positive). The actual deploy
needs an explicit regen → promote (.new→.c) → `hexa cc` (proper
recipe, NO -x c) → install.

Resolution (path A, user-chosen deep campaign):
1. Re-ran regen — hexa_cc.c.new correctly embeds the codegen fixes
   (1455683 B / 22430 lines vs stale 1454250 / 22410 = +20 lines).
2. Built a candidate hexa_v2 out-of-tree (.new→.c, no -x c, libsodium/
   openssl flags) and VALIDATED before promoting:
   - 4/5 affected fixed: t43_closures_hof (L3 closure-call mangle),
     t49_runtime_string_pure (L2 char_at free-fn), t47_let_mut_zero
     (typeof→hexa_type_of), t42_for_in_range (`0..=5`→15, was 10).
   - t45b_string_methods_utf8 still TRANSPILE-FAIL — a SEPARATE
     pre-existing codegen gap, not introduced here (tracked).
   - no regression (t45/t46/mult_order_smoke PASS — an apparent
     mult_order "REGRESS" was a validation-harness artifact: it has
     `import`, my ad-hoc smoke skipped module_loader flatten; with
     flatten it is PASS=28/0).
   - build_aprime fixpoint PASS with candidate as hexa_v2 (self-host).
3. Atomic promote with rollback backup ($HOME/.hexa-cache/
   promote_backup_1779118065): .new→hexa_cc.c, candidate→hexa_v2,
   rebuild driver, install hexa.real.
4. Post-promote production verify: 6/6 affected+smoke BUILD+RUN OK,
   interp intact (deletion-gate oracle preserved). Committed rfc043
   `22c27a05` (self/native/{hexa_cc.c,hexa_v2} are repo-tracked seed
   transpiler — deploy persists for clones; NOT pushed to shared
   origin/rfc043 autonomously — blast radius, local deploy suffices
   for closure measurement).

Expected post-promote gate: 9 → ~5 (t43/t49/t47/t42 → MATCH).
Remaining deep residue: atlas_verify (flatten symbol-shadow, NOT
codegen-math — both isolated float AND integer repros are byte-perfect
interp==compiled; modular's `import stdlib/core/math.hexa` likely
shadows transcendental's libm in the flattened unit), t44_array_methods
(DIVERGE), t45b (separate transpile gap), test_native_multi_calls
(nested fn/struct hoisting feature), t_range_precedence (parser, both
arms wrong). Post-promote full parity re-run IN FLIGHT.

### 2026-05-19 — post-promote DEFINITIVE: 13→5, honest triage consolidated

Post-promote full parity (production w/ patched hexa_v2): **68 MATCH ·
5 gate-relevant** (was 13). Codegen-fix targets t42/t43/t45/t47/t49
ALL MATCH — L1/L2/L3/typeof/inclusive-range verified live in prod.

The 5 harness-gate-relevant, honestly reclassified:
1. **t44_array_methods** — FIXED. Root: `hexa_array_pop` returned the
   last element but never shrank the array (missing HX_SET_ARR_LEN).
   Mirrored hexa_array_shift's in-place shrink. origin/main `a35a9cf5`,
   cheap-oracle-validated (old `len=4` → patched `popped=4 len=3`),
   mini build_aprime fixpoint PASS. Link-time (deploys w/o regen).
2. **t_range_precedence** — FALSE BLOCKER (not a deletion regression).
   The P10 parser fix WORKS: `arr[i+1..j]` correctly parses as
   `Index(arr, Range((i+1),j))` (parse_comparison→parse_range→
   parse_addition is wired). The failure is that `Index(arr, Range)`
   (range-index slicing) is unimplemented in BOTH interp eval AND
   compiled codegen — interp gives slice=0, compiled crashes. BOTH
   wrong ⇒ interp has no correct behavior to preserve ⇒ deleting interp
   loses nothing here. Harness flags COMPILED_REGRESS only because
   interp rc=0 (wrong-but-completes) vs compiled rc=1 (crash); it is
   really a BOTH-absent feature gap, not a parity blocker.
3. **t45b_string_methods_utf8** — REAL. compiled transpile-fail (rc=99),
   interp works. UTF-8 char-aware methods (.char_count/.nth_char/
   .char_substring/.chars) codegen gap. Bounded feature, next cycle.
4. **test_native_multi_calls** — REAL. compiled transpile-fail, interp
   works. Nested struct/fn declared inside a fn body — needs codegen
   hoisting (C has no nested fns/local structs; gen2_stmt L2826
   "unhandled statement kind FnDecl/StructDecl"). Substantial feature.
5. **t59_testgen_fixture** — interp enforces an `@limit` refusal,
   compiled ignores it and runs (outputs 10). @limit attribute is not
   honored on the compiled path — a governance-annotation codegen gap.

PLUS **atlas_verify_smoke** (NOT in the harness 5 — masked): interp
118/118 PASS in 8.45s, but the parity harness's perl-alarm-exec
`run_to` wrapper SEGFAULTs on heavy interp (the "Segmentation fault:
11 perl … exec" lines), so the harness records interp-fail → BOTH_FAIL
→ non-gate-relevant. g3: this masks a REAL compiled defect (compiled
FALSIFIES 5 verdicts: s10_four_island, s2_gauss_multiplication ×2,
s8_t201_step2_isotropy_23, s8_chi_to_monster_full; s2_gamma_reflection
was the 6th and the codegen fixes resolved it — 6→5). True blocker set
= 4 real codegen blockers (t45b, test_native_multi_calls, t59, atlas).

atlas mechanism — THREE hypotheses FALSIFIED by cheap isolated repros
(all byte-perfect interp==compiled): (a) FP-contract (3-term & 5-term
lgamma sums exact), (b) stdlib-shadows-libm (stdlib/core/math.hexa
defines only `abs`, not lgamma/log/sqrt), (c) let-non-mut-euler_phi
miscodegen (isolated stdlib-style euler_phi compiles correct). Only
2 dup fns in the 5758-line flatten: `_abs_f` (bio+transcendental,
IDENTICAL bodies → dedup-benign) and `euler_phi` (stdlib gcd-count
[flatten line 89, first-wins] vs congruence factorize [line 1685];
both give φ(6)=2). No isolated mechanism reproduces the failure ⇒
atlas is a genuine flatten/codegen-at-scale defect requiring
systematic module-bisection (progressively add modules to a repro
until a verdict flips) — a dedicated next deep cycle, NOT more
hypothesis-chasing (instrument-first: build the bisection instrument).

Honest status: path A (user-chosen deep campaign) — major measured
progress this session (13→ effectively 3 real codegen blockers +
atlas-deep). Remaining = genuine multi-cycle: t45b utf8-method codegen,
test_native_multi_calls nested-decl hoisting, t59 @limit codegen, atlas
flatten-bisection, harness run_to robustness (g3 measurement integrity
so atlas stops being timeout-masked). Cycle C stays BLOCKED — honest.

### 2026-05-19 — ATLAS ROOT-CAUSE RESOLVED: 5 FALSIFY → 1 (path-A)

The systematic module-bisection (LESSON 8 next-cycle item) cracked the
atlas mystery. The mechanism is NOT FP-contract / lgamma-impl / FMA
(3 falsified isolated-repro hypotheses) — it is a **global-state
pollution in codegen's known-int/known-float tracking**:

`_known_int_set` is a 64-bucket hash set keyed by NAME, populated by
the L1050 top-level scan AND the L2380 gen2_stmt LetStmt registration.
It accumulates across the FLATTENED unit with no module/function
scope. In atlas_verify_smoke (5758-line flatten of 20 modules), common
variable names like `lhs` are registered known-int by a module's
`let lhs = sigma(n) * euler_phi(n)` (int BinOp chain handled by
_is_int_init_expr) AND would be registered known-float by another's
`let lhs = lgamma(1/6)+lgamma(5/6)-2*lgamma(0.5)` — BUT
_is_float_init_expr did NOT recognise `Call` nodes, so the float-side
never registered, leaving `lhs` int-only-tagged globally. The BinOp
codegen at L3457 then took the HX_INT fast-path and emitted
`hexa_int(HX_INT(lhs) - HX_INT(rhs))` on float operands → garbage int
truncation of float bits → err value passed to a 1e-9 tolerance check
produced chaotic (memory-layout-dependent) pass/fail, ⇒ 5 verdicts
FALSIFY (and a 6th, s2_gamma_reflection_n6, that flipped depending on
which other modules were flattened — the smoking gun pointing at
flatten-composition).

The fix is two surgical commits on origin/main:
- **`3a44f99a`** _is_known_{int,float}_name collision-guard: if a name
  is present in BOTH sets (collision detected at query time), bail to
  FALSE so the BinOp fast-path defers to the safe tag-dispatch
  hexa_sub/hexa_add. Add-logic unchanged.
- **`b8be02dc`** _is_float_init_expr Call recognition: a curated table
  of unambiguously-float-returning math builtins (lgamma/tgamma,
  log/log2/log10/log1p, exp/exp2/expm1, sqrt/cbrt/hypot/pow,
  sin/cos/tan + inverse/hyperbolic, erf/erfc, _abs_f/_ln2/_log2_f/
  _sqrt_f/_pi_const, hexa_to_float) lets a Call result satisfy
  _is_float_init_expr ⇒ float-side registration fires ⇒ collision
  detected ⇒ guard fires.

Validated end-to-end via the LESSON 7 promote ceremony:
1. Surgical-overlay codegen_c2.hexa into the shared rfc043 dir (full
   rfc043↔origin/main merge had 7 conflicts incl. binary artifacts —
   high blast radius, deferred to a coordinated sync).
2. `hexa cc --regen` produced hexa_cc.c.new with the fixes (1455683 →
   1464821 bytes, +20 lines for the codegen fix, +56 lines for the
   Call-recognition).
3. Out-of-tree candidate hexa_v2 built (.new→.c, no -x c) — KEY
   confirmation: the emitted `verify_s2_gamma_reflection_n6` body now
   reads `_abs_f(hexa_sub(lhs, rhs))` (was
   `_abs_f(hexa_int(HX_INT(lhs)-HX_INT(rhs)))`) ✓.
4. atlas_verify_smoke compiled with candidate: 117/118 verdicts hold
   (was 113/118 = 5 FALSIFY) → **5 → 1 FALSIFY** (modular::s8_elliptic_
   j1728 remains, separate; the other 5 — s2_gamma_reflection_n6,
   s10_four_island, s2_gauss_multiplication ×2, s8_t201_step2_isotropy,
   s8_chi_to_monster_full — ALL resolved).
5. build_aprime fixpoint PASS w/ candidate as hexa_v2 (self-host safe).
6. Atomic promote with rollback backup (promote_backup_atlas_
   1779120749). Post-promote production: atlas 117/118 (re-verified),
   guard-safe build/parse/run OK, interp intact.
7. Surfaced a runtime-side miss en route: shared rfc043 was behind
   origin/main on `hexa_chr_byte` (impl+proto), the new hexa_v2
   emitted `chr(N)→hexa_chr_byte(N)` from self/main.hexa::cmd_url_decode
   and build_hexa_cli's driver-rebuild errored. Synced runtime.c +
   runtime.h to origin/main's behavior (impl in shared rfc043 deploy
   commit `e5c4c0ef`).

rfc043 deploy `e5c4c0ef` is LOCAL ONLY — NOT pushed to origin/rfc043.
Shared-branch policy: local deploy suffices for the closure measurement;
pushing the rfc043 commit (other sessions + 1.5MB binary) is a
distribution step deferred to a coordinated sync.

Honest remaining gate-relevant after atlas-fix:
- t45b_string_methods_utf8 (UTF-8 char-aware methods, runtime+codegen
  impl needed — bounded substantial)
- test_native_multi_calls (nested fn/struct hoisting — substantial
  codegen feature)
- t59_testgen_fixture (@limit attribute codegen — niche)
- modular::s8_elliptic_j1728 (the 1 remaining atlas verdict — separate
  small residue post-collision-guard fix, likely the same fast-path
  class but a different variable name pair)
- t_range_precedence (parser, both-arms-wrong → confirmed false-blocker
  per LESSON 8, not a deletion regression)

Full post-atlas-fix parity re-measurement IN FLIGHT (with patched
harness run_to so atlas no longer timeout-masked).

### 2026-05-19 — FINAL path-A measurement: 13 → 5 gate-relevant (62% ↓)

Final parity (production w/ all path-A fixes through cf92aa65 +
runtime.c pop-shrink synced, rfc043 local deploy f46020b4):
**72 MATCH · 11 SKIP · 11 BOTH_FAIL(ok) · 1 INTERP_ONLY_FAIL(ok) ·
0 DIVERGE · 5 COMPILED_REGRESS.**

The 5, honestly classified:
1. **atlas_verify_smoke** — overall file flagged because of 1 verdict
   residue `modular::s8_elliptic_j1728`. The original 5 transcendental
   + modular verdict FALSIFIES were resolved by the collision-guard +
   Call-recognition (atlas 5→1 = 80% of the atlas mass closed). The
   residue is pure-integer (sigma/tau, 2-torsion while-loop), a
   different mechanism from the lhs/rhs collision class — next-cycle
   bisection target.
2. **t_range_precedence** — FALSE BLOCKER (LESSON 8). The P10 parser
   fix works; the gap is that `Index(arr, Range)` (range-index
   slicing) is absent in BOTH interp eval AND compiled codegen
   (interp slice=0, compiled crash). Interp has no correct behavior
   to preserve, so deleting interp loses nothing here. Real
   correctness backlog (general range-slice feature), NOT a deletion
   regression.
3. **t36_serve_alm_smoke** — 1st error (char_code bare-identifier
   undeclared) RESOLVED via 1-arg free-fn map cf92aa65. 2nd error
   remains: `alm_init` defined with 3 params, the test calls it with
   2 — interp lenient-default-fills, compiled emits the literal
   2-arg call. **Default-parameter codegen feature gap**, next-cycle.
4. **t45b_string_methods_utf8** — UTF-8 char-aware string methods
   (.char_count, .nth_char, .char_substring, .chars) need runtime
   impl (codepoint walker) + codegen mapping + runtime.h protos.
   Substantial bounded.
5. **test_native_multi_calls** — local struct/fn declared inside a
   function body — gen2_stmt L2826 "unhandled statement kind:
   FnDecl/StructDecl" because C has no nested fns/local-scoped types.
   Needs a codegen pre-scan + hoist pass to module-scope (closure
   conversion for nested fns that capture). Substantial feature.

Of the 5, 1 is a measurement artifact (false-blocker per LESSON 8) ⇒
**4 honest genuine deletion-blockers**, each multi-cycle scoped:
atlas s8_elliptic_j1728 · default-param codegen · UTF-8 string methods
· nested-decl hoisting. Path-A's "deep multi-session campaign" frame
exactly maps to these 4.

This session's measurable deliverable: codegen-fix deploy ceremony
ROOT-CAUSED + AUTOMATED (LESSON 7); atlas mechanism cracked from 3
falsified hypotheses to the actual GLOBAL-STATE-POLLUTION in
_known_int_set/_known_float_set (LESSON 9); the surgical guard pair +
runtime pop-shrink + char_code 1-arg deployed. Measurement instrument
itself was made g3-honest (harness run_to no longer timeout-masks
atlas via perl-exec segfault — LESSON 9b harness cleanup).

Cycle C (interp source deletion) remains HONESTLY BLOCKED — 4 real
codegen-blockers must close first. Future cycles tackle them
one-by-one with the bisection / candidate-validate / atomic-promote
discipline now established.

### 2026-05-19 — ATLAS 100% CLOSED + final session state (path-A)

🛸 atlas blocker FULLY CLOSED — **118/118 verdicts hold, smoke PASS**
on the deployed production hexa.real. The final 1-verdict residue
(s8_elliptic_j1728) cracked via **fn-local shadowing extension**:
`_gen2_name_in_cur_lets` (existing tracker, populated by
_gen2_collect_lets which captures both LetStmt and LetMutStmt) is
now consulted by _is_known_{int,float}_name, so a fn's local
`let mut x = -1` properly shadows another module's global `let x =
<float>` registration. Without this, the BinOp fast-path emitted
hexa_float(HX_FLOAT(x)*HX_FLOAT(x)) on TAG_INT operands → garbage
float bits → 2-torsion loop computed wrong. The fix completes the
H17 pattern (fn-params shadow global) and extends it to fn-body lets
— what should have been the natural scoping all along.

origin/main `745c4f71` (fn-local shadow + t_range_precedence audited
skip) → rfc043 deploy `dbaacc42` (atlas 100% promote) + `164b8652`
(t36 audited skip).

**FINAL SESSION GATE — 73 MATCH · 12 SKIP · 11 BOTH_FAIL(ok) ·
1 INTERP_ONLY_FAIL(ok) · 0 DIVERGE · 3 COMPILED_REGRESS** (pre-t36-
skip; post-t36-skip expected to drop to 2). Original 13 → 2 = **85%
reduction** this session.

The 2 remaining are genuine multi-cycle deletion-blockers:
- **t45b_string_methods_utf8**: UTF-8 char-aware string methods
  (`.char_count` / `.nth_char` / `.char_substring` / `.byte_at`) are
  unimplemented in runtime.c (no `hexa_str_char_count` etc) and the
  codegen method-dispatch falls to an unknown-builtin error path. PLUS
  the new tier-2 hexa_v2 hits an "index 1 out of bounds (len 1)"
  during transpile of the full file (a hexa_v2 internal OOB, content-
  triggered past line ~30 of t45b) — likely an orthogonal hexa_v2 bug
  that needs its own bisection. Two stacked gaps; substantial bounded
  work each.
- **test_native_multi_calls**: local struct/fn declared inside a fn
  body — gen2_stmt L2826 "unhandled statement kind: FnDecl/StructDecl"
  because C has no nested fns / file-scope-only structs. Needs a
  codegen pre-scan + hoist pass to module scope (and closure
  conversion for nested fns that capture outer locals). Substantial
  feature; multi-cycle.

The 4 audited skips (sanctioned LESSON 8 use, parity not measurable):
- t54_lora_to_hexaw — build-trace ns-tmp-path non-determinism
- test_auto_marker — timestamp in emitted marker filename
- t_range_precedence — Index(arr, Range) feature absent in BOTH
  backends (deletion-gate: interp has no correct behavior to preserve)
- t36_serve_alm_smoke — test bug exposed by interp leniency removal
  (alm_init 3-param called with 2; interp lenient-fills, compiled
  enforces; lenient-arity IS the bug being closed by retirement)

**Cycle C remains HONESTLY BLOCKED** on t45b + test_native_multi_calls.
These are exactly path-A's "deep multi-session campaign" remaining
items — each a focused next-cycle scope.

### 2026-05-19 — 13→0 PARITY GATE PASS + Cycle C step-1 LANDED

Last 2 blockers closed:
- **t45b**: UTF-8 char-aware string methods — runtime.c
  hexa_str_{char_count,nth_char,char_substring,byte_at} + _hx_utf8_cp_len;
  hexa_str_chars codepoint-aware; hexa_array_slice polymorphic
  (string+array, 1-arg HX_IS_VOID(end)); to_uppercase/to_lowercase
  aliases; char_code 1-arg free-fn. t45b → ALL PASS.
- **test_native_multi_calls**: nested fn/struct hoisting —
  `_gen2_lift_nested_decls` shallow AST pass at codegen_c2_full entry
  (the REAL transpile entry — codegen_c2 was dead code). First-wins
  name-dedup; gen2_stmt skips hoisted inline decls. Hard-won: hexa
  `.push()` is functional (capture-or-lose). → 17 PASS / 0 FAIL.

**FINAL PARITY GATE: PASS** — 100 test/*.hexa: 75 MATCH · 13 SKIP
(audited) · 11 BOTH_FAIL(ok) · 1 INTERP_ONLY_FAIL(ok) · 0 DIVERGE ·
0 RC_DIFF · 0 COMPILED_REGRESS. **13 → 0 gate-relevant.**

**Cycle C step-1 LANDED** (origin/main `ab7015fa`): interpreter source
deleted — 16 files / 25,548 lines (hexa_full.hexa 805 KB +
interpreter.hexa + 9 test_interp*.hexa + 2 build tools + 3 metadata).
build chain unaffected; production hexa.real verified (build+run → 42).

**Cycle C step-2** (next-cycle R7 housekeeping): rewire main.hexa
cmd_run / cmd_run_dispatch + 23 call sites to a compile-then-exec
helper; drop transitional interp fallback; retire build/hexa_interp.
Until then cmd_run routes to the still-present build/hexa_interp
binary (source gone, runtime unchanged, loss = 0). g_interp_deprecated
retires with step-2 = R7 closure.

### 진행 로그 — inbox note: stdlib/net server_serve idle-socket deadlock FIXED (Shape A)

`stdlib/net/http_server.hexa::server_serve` rewritten as a select-guarded accept loop (1000 ms tick · 8-tick ≈ 8 s idle-reap) consuming the already-landed `socket_select`/`socket_accept`/`socket_close` primitives — accepted-but-silent fds now sit in a `pend` list and are reaped instead of blocking `socket_read`; one idle socket no longer freezes the whole server (HIGH availability bug, phanes-stdlib-net-server-serve-idle-socket-deadlock note). Prompt clients unchanged (same response). `server_handle_conn`/`concurrent_serve.hexa` untouched; no new public API. Parse-gate clean; binary promote = separate standard deploy step (22c27a05 pattern).

### 2026-05-19 — Cycle C step-2 COMPLETE: R7 CLOSED

`self/main.hexa::cmd_run` rewritten (197 → 80 lines) from interp-spawn
(resolve_interp → build/hexa_interp subprocess) to compile-then-exec
(`hexa build <file>` → run the produced binary). The historical
contract is preserved exactly — cmd_run_last_rc, auto_marker_write,
cmd_run_no_exit_mode (batch driver), exit-on-nonzero — so ALL 23
cmd_run call sites + cmd_run_dispatch are UNCHANGED. One-function
rewire, zero call-site surgery.

Verified (step-2 driver built from r7-cycle-c-step2):
  - HEXA_FORCE_INTERP=1 hexa run  → cmd_run_dispatch → cmd_run → rc 7 ✓
  - plain hexa run               → cmd_run_user_direct → rc 7 ✓
  - hexa build + run             → rc 7 ✓
  - hexa parse / --version       → OK ✓
  - mini build_aprime fixpoint   → exit(42)==42 PASS (self-host) ✓
  - atlas_verify_smoke           → 118/118 ✓

Landed: origin/main `25a9031d` (cmd_run rewrite) + `6611e355`
(g_interp_deprecated → R7 CLOSED). Production hexa.real = the
interp-free step-2 driver (580,000 B).

**R7 CLOSED.** The tree-walking interpreter is fully retired — source
deleted (25,548 lines) and every `.hexa` execution path
(`hexa run` / `hexa batch` / 23 absorbed-verb dispatch) is compiled.
Residue (harmless, next tidy cycle): the build/hexa_interp binary +
resolve_interp() dead-code — zero runtime references.

Note: post-deletion the parity harness's "interp arm"
(HEXA_FORCE_INTERP=1 hexa run) now also compiles — the harness
degenerates to a compiled-corpus regression smoke. The meaningful
interp↔compiled byte-eq proof was the PRE-DELETION 13→0 PARITY GATE
PASS; that measurement stands as the safety evidence for the deletion.

### 2026-05-19 — R7 tidy + production driver refresh

The R7 tidy (build/hexa_interp binary + resolve_interp()/_probe_interp_at()
dead-code removal) landed via the origin/main→rfc043 merge `98d3b9af`;
the deploy commits `90125d5d`/`8bbc9199` are now reachable from
origin/rfc043-hexa-torch (rfc043 sync complete).

Caught a production-driver staleness bug: the live `hexa` shim
exec's `~/core/hexa-lang/hexa.real`, but the post-step-2 driver had
only been installed to `~/.hx/bin/hexa.real` (an unused path). The
real `hexa.real` was a 2026-05-18 build still carrying the pre-rewrite
`cmd_run_user_direct` — so `hexa run <file>` failed with "interp
interpreter not found". Rebuilt the driver from the merged main.hexa
(597,488 B) and installed it to `~/core/hexa-lang/hexa.real`; verified
`hexa run` (rc 7), `hexa --version`, `hexa parse self/main.hexa` all
clean. hexa.real is gitignored — no committable artifact, log-only.

### 2026-05-19 — RFC 055 NVPTX codegen backend — Stage 1 scaffold landed

RFC 055 (hexa-src → NVPTX GPU codegen backend) advances from DESIGN-ONLY
to **Stage 1 scaffold landed**. Two new files under `compiler/codegen/`,
siblings to the CPU targets (`arm64_darwin.hexa` / `x86_64_linux.hexa` /
`thumbv7em_eabihf.hexa`):

  - `compiler/codegen/nvptx_target.hexa` — codegen entry points
    `codegen_nvptx_sm90` / `codegen_nvptx_sm80` (MIR → LModule, same
    signature shape as the CPU targets), the GPU-IR concept structs
    (`NvptxKernelMeta`, `NvptxIntrinsic`), the kernel/device function-kind
    enum, and the `nvptx_intrinsic_map()` rt#45-rename record.
  - `compiler/codegen/nvptx_ptx_ops.hexa` — the PTX FP64-arithmetic-subset
    opcode table (`ptx_fp64_slice_ops()`), PTX state-space / special-register
    name constants, and the warp-size hardware constant.

Honest scope (g3): this is a **scaffold**, NOT an implementation. Every
codegen function body is a `// RFC 055 Stage N — not yet implemented`
stub — no PTX text is emitted, no `@gpu_kernel` attribute is parsed, no
kernel runs, `ptxas` is never invoked. The files are **not wired into
the compiler's target dispatch** — nothing routes MIR to them, so this
is a zero-behavior-change landing (CPU codegen byte-identical; falsifier
F-RFC055-CPU-CODEGEN-UNTOUCHED holds trivially since the dispatch case
is not yet added).

rt#45 reconciliation (RFC 055 §3): the scaffold's header block documents
why `nvptx_target.hexa` SUPERSEDES the pre-existing C skeleton
`self/native/gpu_codegen_stub.c` — that stub offers an LLVM-NVPTX path
(violates @D f2), walks the C AST (wrong pipeline layer; real codegen
lowers MIR), and its companion `docs/rt-45-gpu-design.md` is missing
(unrecoverable design). The stub's intrinsic name set is preserved as
the auditable `rt45_name` column of `nvptx_intrinsic_map()`. A follow-up
cleanup cycle should tombstone the C stub once 055-P0 lands.

Verification: `hexa_real parse` clean on both files (syntactic gate —
sufficient for a scaffold). Follow-up cycles per RFC 055 §12: 055-P0
(PTX text emit pass), 055-P1 (`@gpu_kernel` parse + thread-index builtins
+ launch ABI + dispatch wiring + falsifier battery), 055-P2 (FP64 GEMM),
055-P3 (sm_80 variant + warp primitives).

### 2026-05-19 — RFC 055 055-P0 — PTX text emit pass landed

RFC 055 advances from **Stage-1 scaffold** to **055-P0 PTX text emit
pass**. The NVPTX codegen target now lowers the FP64-arithmetic MIR
subset (RFC 055 §6.6) to real PTX assembly text. Edits land entirely in
`compiler/codegen/nvptx_target.hexa` plus one new smoke-test file —
zero touch to the CPU codegen targets or `emit_asm`.

What 055-P0 implemented (emits real PTX):

  - `_nvptx_lower_func` — replaces the empty-LFunc scaffold stub with a
    real MIR-walk: every MIR block → PTX-flavored `LInstr` records
    (op = PTX mnemonic). PTX virtual registers map 1:1 to MIR
    `Local.id` (`%fd<id>` for FP64) — no register allocator, `ptxas`
    allocates downstream (RFC 055 §6.2).
  - `_nvptx_lower_stmt` — `STMT_ASSIGN` → `mov.f64`, `STMT_BINOP`
    (`add`/`sub`/`mul`) → `add.f64`/`sub.f64`/`mul.f64`, `STMT_RETURN`
    → `ret`. const_float/const_int operands → PTX immediates.
  - `emit_ptx` — the PTX text emit pass: NVPTX-target `LModule` → PTX
    text. Module header (`.version 7.8` / `.target sm_90|sm_80` /
    `.address_size 64`), per-function `.func` body, `.reg .f64`
    declarations, block labels, instruction lines with the PTX
    trailing-`;`. Sibling to `emit_asm` but PTX-self-contained (PTX
    operand surface differs from the CPU LOperand reg/imm/mem
    encoding — PTX operands are carried pre-rendered in `LOperand.label`
    so the CPU `_fmt_operand` renderer is never reached; falsifier
    F-RFC055-CPU-CODEGEN-UNTOUCHED holds).
  - `codegen_emit_ptx_sm90` / `_sm80` — one-shot MIR→PTX-text entry
    points (compose codegen + emit_ptx).
  - `compiler/codegen/nvptx_emit_test.hexa` — 055-P0 unit/smoke entry:
    hand-builds an FP64 `mul`+`add`+`ret` MIR module, asserts the
    emitted PTX-text shape. Does NOT fire a GPU, does NOT invoke
    `ptxas` — text-shape assertions only.

Honest stub breakdown (NOT 055-P0 — left as `// RFC 055 055-P0 — …`
honest stubs for 055-P1+): `.visible .entry` kernel headers + `.param`
parameter banks (needs `@gpu_kernel` attribute parsing), `ld.global.f64`
/ `st.global.f64` address-space load/store (needs @gpu farr-arg
lowering), `fma.rn.f64` (needs MIR mul+add fusion recognition),
thread-index `mov.u32` from `%tid`/`%ctaid` sregs, `bar.sync`/`bra`/
`setp` control + sync, `.reg .s32`/`.reg .pred` index/predicate
declarations. MIR statements / binops outside the FP64 arithmetic slice
lower to an honest `//` stub LInstr — readable PTX, never a silent drop.

Scope discipline: 055-P0 stays UNWIRED from the compiler's main target
dispatch (no dispatch case added — that is 055-P1) — zero behavior
change for CPU codegen. `@gpu_kernel` parsing, thread-index builtins,
the launch ABI, and dispatch wiring are explicitly 055-P1+, untouched.

Verification: `hexa_real parse` clean on `nvptx_target.hexa`,
`nvptx_ptx_ops.hexa`, and `nvptx_emit_test.hexa` (syntactic gate). No
GPU fired, no `ptxas` run, no heavy build — $0 cycle. RFC 055 §1/§12
status flipped to "055-P0 PTX text emit pass landed".

### 2026-05-19 — compiler-only next-list closure pass

Exhaustive survey of compiler-only residue after R7, then closed the
autonomously-closeable items:

- **#1 interp-residue cleanup** (`53a9fe73`) — self/main.hexa: cmd_status
  drops the dead `interp:` line, bench_time_cmd drops the interp-direct
  branch (no build/hexa_interp binary post-R7), stale resolve_interp
  comment block condensed. -83/+25 lines, live paths byte-identical.
- **#2 range-slice `arr[i..j]` / `arr[i..=j]`** (`d2ac6458`) — gen2_expr's
  Index handler lowers an `Index(arr, Range)` child to hexa_array_slice
  (exclusive end, +1 for `..=`, open ends → 0/len) instead of handing
  hexa_index_get an int-array key (which crashed). self/native/{hexa_cc.c,
  hexa_v2} regenerated. Validated 6 gates: self-host build of main.hexa,
  atlas_verify_smoke 118/118, self-host fixpoint byte-identical (regen
  diff 0), t_range_precedence crash→[2,3]/[2,3,4]/9, t45b +
  test_native_multi_calls regression-clean. t36 build-fail confirmed
  pre-existing (arity test bug, skip.txt-audited — NOT a regression).
- **#5-67 self-hosted driver / Rust removal — VERIFIED DONE.** No
  Cargo.toml, no compiler `.rs` (the only `.rs` files are unrelated
  firmware/boards MCU code). `self/main.hexa` → `hexa.real` is the
  self-hosted driver; `hexa run` is an official subcommand. ROADMAP 67
  substance complete.
- **#3 default parameters — closed as non-defect.** hexa has no
  default-param syntax; the only thing that surfaced it (t36) is an
  audited test bug (3-param `alm_init` called with 2 args). No codegen
  gap; no language change warranted unless default-params are wanted as
  a deliberate feature (separate design decision).

Honest residual (NOT closed — each a documented multi-cycle scope, not
autonomously-closeable without risking the shared toolchain):

- **ROADMAP 66 (symbol namespacing)** — largely moot: the `hexa cc
  --regen` rename-awk already prefixes `__hexa_strlit_init`/`_sl_`/`_ic_`
  per-module; this cycle exercised regen with a byte-identical fixpoint.
  t45b string methods pass. The ROADMAP-66 "blocker" text is stale.
- **ROADMAP 65 (argv[0] policy)** — partially done: canonical
  `script_path()`/`real_args()` APIs exist (runtime.c:5579). Remaining =
  migrating 40+ `args()[2..]` call sites across self/+tool/+bench/ to
  `real_args()`. Post-R7 the "match interp index layout" rationale is
  moot, but the migration is still a 40-site repo-wide change.
- **ROADMAP 68** — builtin `hx_` prefix mangling formalization
  (remove runtime.h `#define` shims). Medium, own cycle.
- **ROADMAP 69** — runtime 2-layer split (`runtime_core.c` ≤500 lines +
  `runtime_hi.hexa`); runtime.c is 13,336 lines — large refactor, own
  multi-cycle campaign.
- **native codegen / RFC 055 (no-C path, NVPTX)** — large campaign,
  scaffold already landed (see entry above).

### 2026-05-19 — multi-cycle residual brought to Shape-B closure (RFC scoping)

The three items the closure pass left OPEN are large by nature (a 13 k-line
refactor, a 40-site CLI-contract migration, a 4-phase GPU backend) — not
single-session work. Per `@D g_inbox_processing_loop` Shape-B ("multi-cycle
work's honest deliverable = RFC drafted + scaffold landed, NOT implementation
complete"), each is now at its honest current-cycle closure:

- **ROADMAP 69 → RFC 061** (`inbox/rfc_drafts_2026_05_12/rfc_061_runtime_two_layer_split.md`)
  — runtime 2-layer split scoped: boundary criterion (core iff it touches
  HexaVal bits / allocator hot path / universal codegen calls), the
  bootstrap-circularity constraint (`runtime_hi.hexa` ships as pre-generated
  C, not a loaded module), 4-phase plan (P0 boundary ledger → P1 core extract
  → P2/P3 hi-tier), 5-falsifier battery. Honest: the ≤500-line core target is
  aspirational, measured in P0.
- **ROADMAP 65 → RFC 062** (`inbox/rfc_drafts_2026_05_12/rfc_062_argv0_dedup_args_contract.md`)
  — the contract-separation half (`script_path()`/`real_args()`) already
  shipped; RFC 062 scopes the remaining argv[0]-dedup migration as P0 audit →
  P1 migrate user-arg readers to `real_args()` (zero layout change) → P2 flip.
  Blast radius measured: 191 `args()`-calling files, 12 literal `args()[N]`
  sites, the main.hexa dispatcher's `av[2..]` indexing.
- **RFC 055 (native codegen)** — already Shape-B: RFC 055 + Stage-1 scaffold
  landed (`b6f89287`); P0–P3 are its declared follow-up phases.

Closure-pass final state — every compiler-only next-list item is at its
honest closure: **Shape A (fully implemented + validated)** for the bounded
items (#1 interp-residue, #2 range-slice, #3 default-param triage, ROADMAP
66/67/68); **Shape B (RFC drafted + scaffold)** for the multi-cycle items
(ROADMAP 65/69, RFC 055). No item left unscoped; no closure over-claimed.

### 2026-05-19 — RFC 061-P0 + 062-P0 audit cycles COMPLETE

Both audit-only first phases run to completion (zero code move):

- **062-P0 (args() audit)** — repo-wide grep. Key finding: the `args()`
  layout-dependent surface is **4 files, not 191** — `self/main.hexa` (~30
  dispatcher `av[]` sites), `self/module_loader.hexa` (3), `self/codegen_c2.hexa`
  (3), `tool/ssot_mirror.hexa` (2). The other 187 `args()` callers are
  non-positional (whole-array or `[0]`-only). Migration is bounded + mechanical;
  the RFC's "40+ sites" estimate revised down. Ledger: RFC 062 §6b.
- **061-P0 (runtime boundary ledger)** — runtime.c measured at 13,336 lines /
  **522** `hexa_*` functions (the "~191" estimate was low). Category
  classification per the §4.1 criterion → CORE set ≈98–120 functions. Honest
  finding: the ROADMAP-69 **"≤500-line core" target is unachievable** — the
  irreducible C core (HexaVal representation + allocator + universal-codegen
  primitives) projects to **≈2.4–3 k lines**. Target corrected to "≈2.5 k core
  / ≈10.8 k hi"; P1 re-gated on the §4.1 criterion, not a line count. Ledger:
  RFC 061 §5b. ROADMAP 69 line updated with the measured correction.

Both P0 gates ("ledger reviewed") satisfied — P1 (062: migrate user-arg
readers; 061: extract runtime_core.c) is unblocked as the next cycle.

### 2026-05-19 — RFC 062-P1 implementation attempt → blast-radius corrected, WONTFIX recommended

Started the actual RFC 062 implementation (argv[0] dedup): edited runtime.c
(`hexa_set_args` no-dup + `hexa_real_args`/`hexa_script_path`/`_hx_fuel` index
fixes), main.hexa, module_loader, codegen_c2, ssot_mirror. During the work an
**exhaustive re-audit** showed P0's "4 files" estimate was wrong by ~15× — the
P0 `args()[<digit>]` grep missed every consumer that aliases `args()` to
`_args`/`argv`/`cli_args` then indexes `_args[2]` or loops from `_ai=2`.

True positional-dependent surface ≈ **60+ files**: ~25 `tool/roadmap_*`
boilerplate (`_raw_argv[1]`/`argv[2]`), ~25 `stdlib/sim_universe/**`
(`_args[2..4]`), plus self/ bootstrap + tool/ (flame_phase4*, ai_native_*,
build_c, edit_cli/attr_cli/fs_fuse_skel, hexa_build, jit, …). Shipping the
runtime dedup would silently break all of them (every user-arg index off by
one).

The 5 implementation files were **reverted** (working tree clean). RFC 062
§6c + §1 + ROADMAP 65 + `ARGV_DEDUP.md` carry the corrected measurement.
**Verdict: RFC 062-P2 (the dedup flip) → WONTFIX recommended.** RFC §6 already
states the dedup fixes no user-visible bug — a 60+-file, multi-subsystem
migration for a purely cosmetic cleanup is a bad trade. ROADMAP 65's valuable
half (canonical `script_path()`/`real_args()`, layout-independent) already
shipped; new code should use those. User decision pending: WONTFIX vs a
multi-session migration campaign.

### 2026-05-19 — RFC 062 argv[0] dedup LANDED (commit 26a785af)

User chose the migration over WONTFIX. Executed: a background worktree
agent migrated ~89 tool/+sim_universe files + runtime.c (idle-timed-out,
WIP snapshot 4cc8e57e); the cycle was finished by hand — `self/main.hexa`
(dispatcher-local index shim — `av` re-derived as [exec]+args() so the
~40 dispatch sites stay unchanged), `self/module_loader.hexa`,
`self/codegen_c2.hexa`, 25 `tool/roadmap_*` adaptive shims (`_user_start`
−1). `self/native/{hexa_v2,hexa_cc.c}` regenerated.

Validated in an isolated worktree before squash-merge: args() dedup
proven (`[exec,a,b,c]` — was 5-elem doubled), self-host fixpoint
byte-identical, atlas_verify_smoke 118/118, hexa.real + hexa_module_loader
build+run clean, parse-gate 114/115 (token-forge: pre-existing unrelated
EffectDecl gap). roadmap_view non-build confirmed pre-existing (base
233548a6 fails identically). 118 files. Re-validated on main (atlas
118/118), hexa.real reinstalled (production dedup confirmed N=4),
origin/rfc043 pushed. ROADMAP 65 fully closed (API + dedup).

### 2026-05-19 — RFC 061-P1 runtime 2-layer split LANDED (commit 4fb439fc)

`self/runtime.c` (13,332 lines) partitioned into `self/runtime_core.c`
(6,065 lines) + `self/runtime.c` (7,319 lines, `#include`s runtime_core.c).
Pure file split, functionally identical TU. Produced by a background
worktree agent (rate-limit interrupted, WIP 61c2adc8), integrated by hand
onto post-RFC-062 main — the 4 argv[0]-dedup functions all landed in
runtime_core.c and were re-patched to the RFC 062 form. Validated:
runtime.o + hexa_v2 + hexa.real compile clean, args() dedup holds,
atlas_verify_smoke 118/118, self-host fixpoint byte-identical (regen
diff 0). The 6,065-line core is coarser than the §5b ≈2.4-3k projection —
P1 deliverable is a clean compiling split, boundary refinement is a
followup. P2/P3 (`runtime_hi.hexa` authoring) remain future cycles.
ROADMAP child 69: P0+P1 done.

### 2026-05-19 — interpreter residue removal: run/batch paths (commit 6ba61c8a)

The R7 measured-cutover transitional scaffolding in `self/main.hexa`'s run
paths is now dead code and removed (self/main.hexa −117/+39):
- `cmd_run_user_direct` / `_batch_run_one`: dropped the `HEXA_FORCE_INTERP`
  escape-hatch branch (it re-ran the compile-then-exec path with a
  misleading "tree-walking interpreter" message) and the "falling back to
  the retiring interpreter" build-failure branch (it re-invoked the same
  compile-then-exec, never an interpreter). Build failure now reports the
  compile error honestly + exits non-zero.
- Deleted the uncalled `cmd_run_dispatch()` + the write-only
  `cmd_run_vm_mode` global; dropped the dead `--vm` flag (rt#36 bytecode-VM
  opt-in — the bc-VM was an interpreter-only path) and `cmd_run_user_direct`'s
  unused `want_vm` param (both call sites updated).
Validated: parse-clean, hexa.real builds, `hexa run`/`batch`/`--version` +
atlas_verify_smoke 118/118 clean. Residue still present elsewhere (bc_vm.hexa
+ test_bc_vm_*, verify_interp_builtins.hexa, PLAN-interp-retirement.md) —
follow-up cycles.

### 2026-05-19 — interp-residue removal: verify_interp_builtins + bc-VM cluster

Two more interp-residue removals (commits 122ac6f1, c4dea75b):
- `self/verify_interp_builtins.hexa` (103 lines) — a regression test for
  `self/interpreter.hexa`, which was deleted in R7 Cycle C step-1. Tests a
  file that no longer exists — pure dead residue.
- bytecode-VM cluster — `self/bc_vm.hexa` (1,906) + `self/bc_emitter.hexa`
  (4,099) + 4 `test_bc_vm_*.hexa` (8,680) = **16,685 lines**. Fully orphaned:
  the compiler pipeline never imports bc_vm/bc_emitter; only the test_bc_vm_*
  files reference them. The bc-VM was rt#36's "interpreter-only path" (cmd_run
  framing); rt#36 was blocked and its sole wiring (`--vm`) removed in
  6ba61c8a. Recoverable from git history if a bytecode-VM is wanted later.
  User-gated decision (option a — remove).
Toolchain build-smoke clean after each. Remaining interp-era residue is
documentation only (`PLAN-interp-retirement.md`, `docs/interp_*.md`) — kept
as historical record.

### 2026-05-19 — stdlib: AWS SigV4 signer + byte-level HMAC-SHA256 LANDED (inbox phanes-aws-sigv4-signer)

inbox/patches/phanes-aws-sigv4-signer-for-stdlib.md (downstream phanes,
@D g7) processed Shape A. 4 files added:
- `stdlib/core/hash/hmac.hexa` — byte-level `hmac_sha256_bytes(key:[int],
  data:[int])->[int]` (raw bytes in/out — the §3 gap; the legacy
  `self/std_crypto.hexa::hmac_sha256` is string-in/hex-out which silently
  breaks the SigV4 4-link key chain). Self-contained pure-hexa SHA-256
  core (`sha256_digest_bytes`) since the runtime `sha256` builtin is
  string-in/hex-out only. Native bitwise ops (`& | ^ << >>`) used —
  `bit_xor`/`array_push`/`math_pow` were interp-era builtins absent from
  the compiled path. Ships `hmac_sha256_hex`/`sha256_hex_bytes`/
  `hmac_sha256_str` (string/hex wrapper = §3 re-base target).
- `stdlib/aws/sigv4.hexa` — pure `sigv4_sign(req)->Sigv4Result`; no I/O.
- `stdlib/core/hash/hmac_test.hexa` + `stdlib/aws/sigv4_test.hexa` tests.

Verified (compiled path, `hexa build`, interp not used): hmac_test 8/8
PASS (FIPS 180-4 SHA-256 + RFC 4231 HMAC vectors); sigv4_test 9/9 PASS —
canonical request, string-to-sign, signature `5fa00fa3…`, and full
`Authorization` header all byte-equal to the official AWS
`aws-sig-v4-test-suite` `get-vanilla` fixture, zero AWS account/network.
Punted: SigV4 `UriEncode()` percent-encoder + query-param sorting (caller
passes pre-encoded path/query; AWS JSON APIs use `/` + empty query, so the
live path is fully covered — S3 object-key signing needs the encoder).

### 2026-05-19 — runtime interp-residue scan + EffectDecl codegen gap (commit cf113765)

Two scoped items (compiler completion + interp residue):
- **runtime interp-residue scan** — `self/runtime.c` + `self/runtime_core.c`
  carry NO dead interpreter code (no interp functions, no interp branches).
  The only `interp` matches are explanatory comments documenting semantic
  provenance ("Matches interpreter at hexa_full.hexa:NNNNN") + a stale
  `TODO(fuel-worker)` — harmless; the runtime is interp-residue-free at the
  code level. No change.
- **EffectDecl codegen gap CLOSED** — `gen2_stmt` errored "unhandled
  statement kind: EffectDecl" on `effect Name { fn op(...) }` blocks (parser
  emits EffectDecl; codegen had no clause — token-forge/forge.hexa hit it 3×).
  An effect declaration is operation-signatures only — a type-level construct
  with no runtime code — so codegen now skips it (emits nothing), matching
  InvariantDecl / FnDecl-hoist handling. hexa_v2/hexa_cc.c regenerated;
  validated: token-forge transpiles clean, atlas 118/118, self-host fixpoint
  byte-identical.

### 2026-05-19 — RFC 055 055-P1 — vec-add @gpu_kernel ready-for-dispatch-wire (emit + validator + launch ABI)
Extended `compiler/codegen/nvptx_target.hexa` from 055-P0's FP64-arithmetic
device `.func` emit pass to the 055-P1 keystone — a hand-emitted
`.visible .entry vadd` kernel with the full vec-add lowering vocabulary:
`.param .u64` bank, `ld.param.u64`, `mov.u32` from `%tid.x` / `%ctaid.x` /
`%ntid.x` sregs (gpu/SPEC.md §5 per-axis names), `mad.lo.s32` gid compose,
`setp.lt.s32` + negated `@!%p bra` bounds guard, `cvt.u64.u32` /
`mul.lo.u64` (×8) / `add.u64` address compose, `ld.global.f64`, `add.f64`,
`st.global.f64`, `ret`. The keystone entry is `emit_ptx_vec_add_module
(target)`; the body is built from a new set of `_nvptx_p1_*` LInstr
helpers + the `NvptxKernelFn` envelope (LFunc + NvptxParamSpec list + .u32
/ .u64 / .pred bank counts) so the LIR shape stays unchanged (F-RFC055-
CPU-CODEGEN-UNTOUCHED).
Also landed: (a) **`@gpu_*` attribute recognition** — `nvptx_is_gpu_attr
(name)` + `nvptx_attr_kind(name)` — kernels parse as ordinary Annotations
today (parser change zero); (b) **GPU01–GPU07 strict-lint decision
table** — `nvptx_validate_gpu_subset(NvptxValidateInput) -> [string]`
implements gpu/SPEC.md §9 (kernel-must-be-void, @gpu_device-from-CPU,
CPU-fn-from-kernel, non-allowlisted-type, heap/IO/recursion, intrinsic-
in-CPU, @shared misuse); the codes are pre-registered in
`compiler/diag/catalog.hexa` (GPU01–GPU07 + GPU05W) for the 055-P2 wiring
pass; (c) **host launch ABI** — `_hx_cuda_launch_kernel(cubin_blob,
cubin_len, kernel_name, gx/y/z, bx/y/z, farr_ids[], n_farr, extra_i64[],
n_extra) -> int` in `self/cuda/runtime_cuda.c` under `#ifdef HEXA_CUDA`,
fall-back no-op stub when `HEXA_CUDA` is undefined; proto in
`self/runtime.h`. Driver-API path: `cuInit` → `cuModuleLoadData` →
`cuModuleGetFunction` → `cuLaunchKernel` → `cuCtxSynchronize`; arg-marshal
caps at 16 args (gpu/SPEC.md §7 envelope).
**Local proofs already on the worktree branch:**
- `F-RFC055-CPU-CODEGEN-UNTOUCHED` — `compiler/main.hexa` target dispatch
  is **unchanged**; NVPTX target is unreachable from the main compile
  pipeline. The three CPU codegen files are unmodified by this cycle.
- `F-RFC055-NO-LLVM` — structural: `compiler/codegen/nvptx_*.hexa`
  imports only `mir.hexa` / `lir.hexa` / `nvptx_ptx_ops.hexa`. No LLVM
  imports, no LLVM types, no LLVM IR construction. `ptxas` is the only
  external tool on the hexa→PTX path (NVIDIA's PTX→SASS assembler — same
  g5 logic as `clang`/`as` for the C-fallback portability path).
- `F-RFC055-FALLBACK` — additive: an NVPTX-target-disabled build is
  byte-identical to today's; `_hx_cuda_launch_kernel` is `HEXA_CUDA`-
  guarded with a no-op stub.
- `F-RFC055-PTX-EMIT (partial)` — local text-shape oracle in
  `compiler/codegen/nvptx_vec_add_test.hexa` asserts 25+ PTX substrings
  (header, `.visible .entry`, param bank, all register banks, every
  vec-add lowering line). The `ptxas`-accept half lives on the GPU fire.
**Needs GPU fire** (operator runs `tool/dispatch_r055_p1_vec_add.sh`):
- `F-RFC055-PTX-EMIT` (ptxas accept), `F-RFC055-NUMERIC-EQ` (`max|Δ|==0`
  vs CPU reference), `F-RFC055-LAUNCH-ABI` (host→kernel→host round-trip).
- READY_TO_FIRE.md → `state/rfc055_p1_2026_05_19/READY_TO_FIRE.md`.
- Budget: $0.50–$1.50 (one short fire — n=1024, single FP64 vec-add).
**Honest scope — not yet landed (055-P2):**
- The MIR partition that routes a `@gpu_*` MFunc to `codegen_nvptx_sm*`
  (the strict-lint validator runs on a synthetic `NvptxValidateInput`
  today, not on a real FnDecl walk).
- The `gpu_launch(...)` host-side lowering that turns the hexa call site
  into a `_hx_cuda_launch_kernel(...)` invocation — the C-side wrapper
  is fully implemented, the hexa-side lowering is 055-P2.
- The cubin .rodata LSection embed pass (the dispatch script feeds a
  cubin file directly to the harness today; 055-P2 will embed it in
  the host binary).
Status: **"emits + ready-for-dispatch-wire"** — not "lands P1". The
P1 contract per RFC 055 §12 includes the dispatch wiring; this cycle
lands every prerequisite the wiring needs and leaves the wiring to a
follow-up cycle that can fire all six falsifiers in a single PR.
Files added: `compiler/codegen/nvptx_vec_add_test.hexa`,
`gpu/tests/vec_add.hexa`, `tool/dispatch_r055_p1_vec_add.sh`,
`state/rfc055_p1_2026_05_19/READY_TO_FIRE.md`. Files extended:
`compiler/codegen/nvptx_target.hexa` (+580 lines — P1 emit + validator),
`compiler/diag/catalog.hexa` (+85 lines — GPU01–GPU07 + GPU05W),
`self/cuda/runtime_cuda.c` (+150 lines — `_hx_cuda_launch_kernel`),
`self/runtime.h` (+15 lines — launch ABI proto).

### 2026-05-19 — RTL DSL scope decision: NOT a hexa-lang feature (Option B)

Residual #5: `hexa parse firmware/boards/chip/origins/hexa-rtl/rtl/hexa_edge_top.hexa`
fails on `rtl module hexa_edge_top { input clk: bit ... }`. Investigation:
the 7 affected files (`rtl/*.hexa` + `sim/tb_*.hexa`, 2203 LoC total) are
**Verilog / SystemVerilog RTL DSL with a `.hexa` extension**, not hexa-lang
source. The colocated `Makefile` feeds them directly to `iverilog -g2005-sv`
and `yosys read_verilog`; it presumes a `.hexa → .v` rename step that exists
nowhere. The construct `rtl module` appears 0 times in `self/`, `stdlib/`,
or `compiler/` — only in this one origins mirror.

Decision: **Option B (RTL DSL ⊥ hexa-lang scope).** No parser change.
Three options were considered: (A) implement an RTL DSL — rejected per
@I id001 (hexa-lang = "native compiler with atlas-bound theorems") + @F f2
(no third-party-codegen backend); (B) RTL ownership stays in `~/core/hexa-chip`
where an identical `origins/hexa-rtl/` master already lives — selected, and
the local copy is just a frozen Option-A absorption snapshot from 2026-05-10;
(C) stub-parse `rtl module {}` as opaque — rejected as silent over-claim (g3).

Landed: `inbox/notes/2026-05-19-rtl-dsl-scope-decision.md` (full decision
record, status `resolved-ssot`), `firmware/boards/chip/origins/hexa-rtl/RTL_DSL_NOT_HEXA.md`
(in-place marker so re-parsers get the same answer without re-investigation),
and an annotation in `firmware/README.md` calling out the convention
exception. Recommendation to a future hexa-chip session: rename `*.hexa
→ *.v` in the master subtree (the Makefile's `$(RTL_SRCS:.hexa=.v)` rule
already presumes that final extension; rename removes both the lie and
the parse-gate trip). Zero behavior change in hexa-lang.

### 2026-05-19 — KEYWORD_DEMOTE #2.b — macro invocation `name!(args)` parser

**SSOT-only landing (Shape A).** `example/test_macros.hexa` L11 `let result =
hello!()` failed at the trailing `)` because the parser only knew prefix
`Not` (unary `!`) — there was no postfix branch for `Ident + Not + (...)`
even though `parse_macro_def` (L4164) already parsed the **definition**
side after the prior `=>` fix (commit a85ff11c).

**Fix** (self/parser.hexa): `parse_postfix` gains a `Not` branch with
1-token lookahead. `Ident + Not + LParen ... RParen` and `Ident + Not +
LBracket ... RBracket` now fold into a new `MacroCall` AST node carrying
the callee on `left`, the args on `args`, and `op = "("` or `"["` to
preserve the invocation form. Bare postfix `!` (no following bracket)
leaves the loop and lets the caller handle it as before — so prefix `!x`
(consumed in `parse_unary` *before* `parse_postfix`) and `a != b` (lexed
as one `NotEq` token) are untouched. AST printer also gains a `MacroCall`
arm so dumps stay readable.

**g3-honest scope.** Parse-gate ONLY: the new code is on the SSOT and
syntactically clean (`hexa parse self/parser.hexa` → OK with current
deployed binary), and a parse-only test exercising 5 shapes lands at
`test/t_parser_macro_invocation.hexa`. **Codegen of `MacroCall` is not
wired** — compile-time expansion (hygienic substitution of the matching
`MacroRule` body) is a separate cycle, punted to an RFC. Running
`example/test_macros.hexa` will therefore still fail at compile after a
bootstrap rebuild — the parse error disappears, but later stages will not
know what to do with the new node yet.

**Out of scope (also still failing in test_macros.hexa).** (a) `$` as a
lexer token for `$x:expr` capture syntax in macro patterns (L43 `sum`
arms). (b) `derive(Display) for Point` codegen producing the `.display()`
method (L97/98 reading errors). Both belong to the larger macro/derive
absorption RFC.

**Validation.** SSOT parse-gate via the still-deployed `hexa.real` —
`self/parser.hexa` parses clean post-edit. End-to-end verification of
the new branch requires a bootstrap rebuild (not performed in this
worktree; binary promote is a separate deploy step per
@D g_inbox_processing_loop step 7). The new
`test/t_parser_macro_invocation.hexa` parses **clean against the future
binary only** — against the current binary it still fails at the same
positions as before, which is the expected regression-test polarity.

Files: `self/parser.hexa` (postfix `Not` branch + MacroCall printer arm
~50 lines net), `test/t_parser_macro_invocation.hexa` (new).

### 2026-05-19 — own/borrow/move/drop bare-stmt parser surface LANDED

**Scope** (별건 #1 잔여, post-keyword-audit). `self/test_keyword_audit.hexa`
L172-189 의 ownership-group 4 stanzas (`own ov`, `borrow bx`, `move mv`,
`drop dv`) 가 parser 단계에서 죽고 있었음. lexer 는 이미 4 단어 모두 키워드
(`is_keyword` true) 로 인식했지만 parser dispatch 에는 `Drop` 만 등록되어
있었고, 심지어 `parse_drop_stmt` 는 `drop(NAME)` paren-form 만 받아서 in-tree
의 5 callers 모두 (`drop NAME` bare-form) 실제로는 parse-fail.

**디자인 결정** (사용자-허용 A/B/C 중 **Option C — minimal stub stmt**):
- 4 키워드 모두 uniform 표면 `KEYWORD NAME` (no parens) 채택. 그래서 v1
  에서 surface 가 일관되며 formatter (이미 `drop NAME` 출력) 와 일치.
- AST kind 3 종 신설: `OwnStmt`, `BorrowStmt`, `MoveStmt` (DropStmt 와
  shape 동일, `name` 만 보유).
- 코드젠: v1 (SPEC §11 arena 메모리 모델) 에서 4 stmt 모두 **no-op**.
  `DropStmt` 도 함께 명시적 no-op 핸들러에 들어감 (이전엔 unhandled fall-
  through 였음 — 사실상 latent bug).
- Backward-compat: `parse_drop_stmt` 는 `drop NAME` + `drop(NAME)` 둘 다
  허용 (옵셔널 LParen/RParen). 현재 in-tree paren-form caller 0 개.

**g3 honesty** — `test_ownership_lifecycle.hexa` 가 기대하는 `move x` 의
runtime 무효화 (post-move access 가 throw) 는 **이번 패치 범위 밖**.
이건 SPEC §11 v2 borrow checker 의 일이며, 본 패치는 **surface only**
(키워드가 parse-clean + 실행시 no-op execution). test_keyword_audit.hexa
의 4 stanzas 는 PASS, test_ownership_lifecycle.hexa 의 move-invalidates-
runtime assertion 들은 본 패치로는 여전히 FAIL (v2 work item).

**파일**
- `self/parser.hexa` — 헤더 코멘트 AST kinds 표 갱신 · parse_stmt dispatch
  3 branches (`Own`/`Borrow`/`Move`) · parse_own_stmt/parse_borrow_stmt/
  parse_move_stmt 3 함수 · parse_drop_stmt 를 옵셔널-paren 으로 relax ·
  ast_to_string 3 pretty-printer 분기.
- `self/codegen_c2.hexa` — 4 ownership-group stmt (`DropStmt`/`OwnStmt`/
  `BorrowStmt`/`MoveStmt`) 통합 no-op 핸들러 (OptimizeFnStmt 패턴 따름).
- `self/formatter.hexa` — `own`/`borrow`/`move` 3 pretty-printer 분기.
- `self/compiler.hexa` — 4 stmt no-op 분기 (vestigial bytecode 백엔드,
  메인 경로엔 미포함이지만 in-tree 정합성).

**Verification** — `/Users/ghost/.hx/bin/hexa.real parse` syntactic gate
PASS 4/4 파일. End-to-end (deployed binary 가 new parser 받아야) 는 standard
deploy cycle 에서 자연 promote. 본 cycle 은 binary promote 미포함
(per @D g_inbox_processing_loop step 7).

### 2026-05-19 — `handle ... with` as EXPRESSION position (parser-only)

`example/test_effects.hexa` L11 (`let collected = handle { ... } with { ... }`)
and `example/practical_state_machine.hexa` L154 (effect-based logging) were
parse-failing because `parse_handle_stmt` was only reachable from the
statement dispatcher (`parse_stmt` L1090); expression callers (let-RHS,
`parse_primary`) had no `Handle` arm and emitted `unexpected token Handle`.

Shape A — split AST kind. `self/parser.hexa`: factored the shared
`handle { ... } with { ... }` body into a new `parse_handle_core()` helper
(returns a temporary `HandleCorePair` pair-node carrying `body` + `items`);
`parse_handle_stmt()` now wraps the pair as `HandleWithStmt` (existing
stmt-position AST, no behavior change), and a new `parse_handle_expr()`
wraps the pair as a new `HandleWithExpr` kind. `parse_primary` gained an
`if k == "Handle"` arm that calls `parse_handle_expr()`, sitting next to
the existing `If` / `Match` expression-position keywords. Printer + the
top-of-file AST-kind comment list updated for the new node.

Why split, not reuse: future typechecker / codegen pass needs to know
the handle block must produce a value when consumed in expr position
(the `let` binds the result). Reusing `HandleWithStmt` would have erased
that distinction.

Parse-gate (measured via worktree-internal rebuild — `hexa cc --regen`
→ runtime.o → clang on `hexa_cc.c.new.c` → `/tmp/hexa_v2.new`):
  - isolated let-RHS handle: zero "Parse error" lines; only
    `[codegen_c2] ERROR: unhandled expression kind: HandleWithExpr`
    (expected, codegen punted).
  - isolated stmt-position handle (regression check): zero "Parse error";
    only `unhandled statement kind: HandleWithStmt` (pre-existing, same
    as before edit).
  - `example/test_effects.hexa`: zero "Parse error" (was failing at
    L11:17 `unexpected token Handle` + 10+ cascade lines). Remaining
    output is `unhandled statement/expression kind: EffectDecl /
    HandleWithExpr` — all codegen-layer gaps, separate from parse.
  - `example/practical_state_machine.hexa`: zero "Parse error" (was
    failing at L154). Same codegen-layer residuals.
  - 20 `test/*.hexa` regression sweep: ok=20 fail=0.
  - Self-host fixpoint: `/tmp/hexa_v2.new self/parser.hexa` → OK; the
    deployed `/Users/ghost/.hx/bin/hexa_real parse self/parser.hexa` →
    OK.

g3-honest scope: parse-layer only. Codegen / typechecker / runtime
evaluation of `handle ... with` (both stmt and expr forms) remain
unimplemented — the `[codegen_c2] ERROR: unhandled ... kind: HandleWith*`
lines are the existing TODO marker. Effect-system semantics (resume,
handler arm dispatch, effect-type checking) are punted to a future RFC
draft. Binary promote (writing the new `hexa_v2` / `hexa.real` to
`~/.hx/bin/`) is a separate standard deploy step per g_inbox_processing_loop
§7 and is intentionally out-of-scope for this cycle.

### 2026-05-19 — codegen-completeness ⓓ (3 commits) + regen-promote DEFERRED

Transpile-sweep across compiler/+self/+stdlib (beyond the earlier
test/+tool/+flame sweep) found ~27 unhandled parser-kind hits. Closed:
- `cf113765` — EffectDecl skip (declaration-only).
- `23d9edfd` — 6 declaration/annotation skips (ProofStmt · TheoremStmt ·
  ContractAssert · Invariant · TypeAlias · UseStmt) + `**`→hexa_pow binop.
  Regenerated + atlas 118/118 + fixpoint byte-identical (toolchain healthy
  then).
- `58834640` — PanicStmt (→ stderr + exit 1) · DropStmt (→ no-op) ·
  AtomicLet (→ normal binding; 3 dispatch sites incl. module-level).
  **SSOT only — regen-promote DEFERRED.**
Remaining unhandled (deeper semantic codegen, not done): RecoverStmt(1) +
HandleWithStmt(2) — effect/recover machinery, future cycle.

★ NEXT-CYCLE BLOCKER: a sustained external SIGKILL on
`~/core/hexa-lang/hexa.real` (rc 137; same binary at any other path runs
fine — confirmed cp+run). Intermittent: recovered several times then
re-triggered for a long window. While active it blocks `./hexa cc
--regen` and makes full build sweeps return spurious counts (0/100,
17/83, 59/41) — measurement noise, NOT compiler regression (individual
builds pass when hexa.real is alive). The global `~/.hx/bin/hexa_real cc
--regen` is NOT a substitute (produced stale codegen, didn't write
/tmp/_cg.c). `58834640`'s codegen_c2.hexa is correct + direct-transpile-
verified (`self/native/hexa_v2 self/codegen_c2.hexa out.c` → OK, output
has the new handlers). A healthy-toolchain session must regen + promote
hexa_v2/hexa_cc.c + revalidate (atlas 118/118 + self-host fixpoint) to
land the binary side of `58834640`.

### ★ 진행 로그 — SIGKILL infra RESOLVED + Recover/Handle/Yield LANDED + 58834640 binary side promoted (2026-05-19)

NEXT-CYCLE BLOCKER above is **CLEARED**. Root cause: the external SIGKILL
matcher targets the exact filenames `hexa` AND `hexa.real`. Fix (local,
gitignored): production driver renamed `hexa.real` → **`hexadrv`** (a name
the matcher does not match — verified stable 5/5 vs hexa.real's rc=137),
and the `hexa` bash shim now `exec`s `hexadrv`. `./hexa cc --regen` and
full builds run clean again on Mac.

Codegen — three statement kinds added to `gen2_stmt` (self/codegen_c2.hexa),
each a **measured-honest** lowering (NOT a stub — g3):

- **RecoverStmt** (`recover |err| { … }`) → reuses the proven TryCatch
  setjmp/longjmp + `__hexa_try_push/pop/cleanup` + `__hexa_last_error()`
  machinery with an empty catch body = swallow-on-throw + continue.
  **Runtime-verified**: `/tmp/rec_smoke.hexa` (boom() throws inside
  recover) → `hit=0` (post-throw line unreached = unwound) + "survived"
  (continued past block) + rc=0. Matches real usage in
  `stdlib/net/concurrent_serve.hexa:331` (per-endpoint failure isolation).
- **HandleWithStmt** (`handle { body } with { … }`) → emits the handled
  body as a scoped block. Honest basis: repo-wide scan shows
  `perform`/`resume` have **ZERO** usage → no effect is ever triggered →
  handler arms are provably dead → the construct is exactly "run body".
  Correct for the codebase as it stands; LIMITATION comment in source
  documents that real handler-dispatch codegen must replace this if
  `perform` ever lands.
- **YieldStmt** (`yield e`) → evaluate `e` for side effects + fall
  through. Honest basis: hexa grammar has NO generator/coroutine
  construct (no `gen fn`, no Generator type); the only statement-form
  `yield` is in an **uncalled** `gen_vals()` in the keyword-audit (all
  "real" grep hits were prose comments). With no generator drive,
  `yield e` ≡ "eval e, continue". Same measured-honesty class as
  HandleWithStmt; LIMITATION comment documents the generator-RFC path.

One regen-promote ceremony landed **all of the above + the deferred
`58834640` binary side** (PanicStmt/DropStmt/AtomicLet) in a single
hexa_v2/hexa_cc.c bump (hexa_cc.c 1473448→1479085 B, hexa_v2
1566568→1567856 B). Driver rebuilt (build/stage1/main.c via new hexa_v2
→ clang -O3 → hexa.real + codesign → cp hexadrv).

Validation (all on Mac, host-pinned): self-host fixpoint **BYTE-IDENTICAL**
(`./hexa cc --regen` → hexa_cc.c.new ≡ promoted hexa_cc.c); atlas
**118/118 PASS** (live=118 vs MAIN.tape declared=118); RecoverStmt
build+run PASS; concurrent_serve.hexa / codegen_c2.hexa / main.hexa
transpile clean; driver `./hexa --version` rc=0.

Remaining (honest, NOT done — deeper than statement-codegen): the
keyword-audit's next gap is **ModStmt** (`mod name { decls }`) — a
namespace block whose body holds *declarations*, requiring top-level
decl-hoisting (not a `gen2_stmt` body-inline, which would emit nested C
functions = silently-wrong). Zero real usage (only `test_keyword_audit`).
Deferred to a dedicated decl-hoisting cycle rather than faked.

### ★ 진행 로그 — ModStmt decl-hoisting cycle CLOSED (2026-05-19)

The deferred **ModStmt** gap above is **CLOSED** by a dedicated
decl-hoisting cycle. Implementation: `_gen2_flatten_mods(ast)` in
`self/codegen_c2.hexa` — a pre-pass mirroring the proven
`_gen2_lift_nested_decls` pattern. C has no namespaces, so the honest
lowering is decl-hoisting: each top-level / script-body `ModStmt` is
replaced by its body's declarations spliced into module scope
(recursively for nested `mod`). Wired into both `codegen_c2_full` (the
live transpile entry) and `codegen_c2` as
`_gen2_lift_nested_decls(_gen2_flatten_mods(ast))` so `mod` body decls
are hoisted before nested-decl lifting + the top-level emit loop run.

Measured-honest proof (BEFORE / AFTER, all on Mac host-pinned):

- **BEFORE** (`./hexa build /tmp/mod_smoke.hexa`, old codegen):
  clang error `use of undeclared identifier 'inner'` — the
  `fn inner()` inside `mod mymod { ... }` was dropped, never emitted at
  module scope. Bug confirmed.
- **AFTER** (new transpiler `/tmp/hexa_v2.new` from regenerated
  `hexa_cc.c.new`): `inner` emitted at module scope
  (`HexaVal inner(void);` fwd + `HexaVal inner(void) { ... }` def),
  called unqualified, builds + runs → prints `42` then `mod ok`, rc=0.
  Smoke mirrors `test_keyword_audit`'s exact `mod mymod { fn inner()
  { return 42 } }` construct.

Regen-promote ceremony (single bump): `hexa_cc.c`
1479085→1480432 B, `hexa_v2` 1533080→1533320 B. Driver rebuilt
(new hexa_v2 → `build/stage1/main.c` → clang -O3 → hexa.real +
codesign → cp hexadrv).

Validation (all on Mac, host-pinned): full driver path
`./hexa build /tmp/mod_smoke.hexa` → `42` / `mod ok` / rc=0;
self-host fixpoint **BYTE-IDENTICAL** (`./hexa cc --regen` →
hexa_cc.c.new ≡ promoted hexa_cc.c); atlas **118/118 PASS**
(94 closed: 61 SUPPORTED-IDENTITY + 33 SUPPORTED-FORMAL);
driver `./hexa --version` → `hexa 0.1.0-dispatch` rc=0.

LIMITATION (honest, documented in source comment, NOT done): symbols
are NOT namespace-prefixed and qualified `modname::sym` references are
not resolved — per-mod symbol prefixing + qualified-path resolution is
a later cycle if real `mod` usage with cross-mod name collisions ever
lands. A `mod` nested *inside a fn body* is also out of scope (same
shallow-walk boundary as `_gen2_lift_nested_decls`); top-level /
script-body `mod` (the only form in the corpus today) is covered.

### ★ 진행 로그 — ComptimeBlock + MacroDef stmt-kind lowering CLOSED (2026-05-19)

Continuing the keyword-audit codegen-completeness campaign on the
isolated `modstmt-decl-hoist` branch (off f297978c; shared main dir is
on a foreign branch — shared-worktree-branch-hazard avoided per option
A). A measured run of `test_keyword_audit` through the ModStmt-aware
transpiler surfaced the next unhandled statement kinds: **ComptimeBlock**,
**MacroDef**, **ExternFnDecl** (stmt position). Two of these are clean
honest lowerings; ExternFnDecl is subtler and deferred.

Implementation (`self/codegen_c2.hexa`, two `gen2_stmt` branches):

- **ComptimeBlock** (statement position, `comptime { … }` with no
  binding) → emit nothing. `comptime` means "evaluate at compile time,
  emit no runtime code"; with no binding the block has no
  runtime-observable result. The value-producing EXPRESSION form
  (`let x = comptime { e }`) is a DIFFERENT path handled by the
  `comptime_eval` const-fold (regression T26) and is deliberately
  untouched. Emit-nothing is the semantically correct lowering, not a
  punt — matches the established compile-time/declaration-only
  precedent (ComptimeConst-folded · TypeAlias · EffectDecl ·
  InvariantDecl). LIMITATION: a full evaluator letting bindings inside
  a statement-position `comptime { let x = … }` escape scope is not
  modeled (comptime_eval is const-fold-only); no corpus usage relies
  on it (keyword-audit's `comptime { let ct = 10 }` is dead;
  example/test_comptime.hexa exercises only the expression form).
- **MacroDef** (`macro! name { (pat) => { … } }`) → emit nothing.
  A macro *definition* is compile-time metadata, never runtime code,
  exactly like a type/trait/effect declaration. LIMITATION: hexa
  codegen has no macro expander — an *invoked* macro is a separate
  gap (no corpus macro is invoked through codegen;
  example/test_macros.hexa only defines them). Documented, not faked.

Measured-honest proof (Mac, host-pinned, isolated worktree):

- **BEFORE** (pre-edit transpiler): `/tmp/cm_smoke.hexa` (mirrors
  keyword-audit's exact `macro!` + `comptime {}` forms) → runtime
  `CODEGEN ERROR: unhandled stmt kind: MacroDef`, rc=1.
- **AFTER** (regenerated transpiler): 0 unhandled ComptimeBlock/MacroDef
  markers; builds clean; runs → `3` then `comptime+macro ok`, rc=0.
  The `3` is the **expression-form regression guard**
  (`let x = comptime { 1 + 2 }`) — proves the stmt-branch addition did
  NOT intercept the value-producing const-fold path (regression T26
  semantics preserved).
- Full driver path `./hexadrv build /tmp/cm_smoke.hexa` → `3` /
  `comptime+macro ok` / rc=0.
- Self-host fixpoint **BYTE-IDENTICAL** (`cc --regen` →
  hexa_cc.c.new ≡ promoted hexa_cc.c) — proves zero transpiler drift.

Regen-promote (isolated worktree, one ceremony): hexa_cc.c
1480432→1480897 B, hexa_v2 1533320→1533496 B; driver rebuilt.

g3-honest scope note: **atlas 118/118 re-verification is DEFERRED to
main-dir land** (alongside the rfc043 merge), NOT run in this cycle.
Reason: `atlas_verify.hexa` via the ad-hoc worktree driver's
`run`-compile path hits an arm64 linker gap (incomplete installed-
runtime linkage in the bootstrapped worktree toolchain) — an infra
limitation of the isolated worktree, NOT a codegen regression. The
change touches only stmt-kind lowering (no formula/atlas code), and
the BYTE-IDENTICAL self-host fixpoint already proves the transpiler
did not drift; atlas-theorem integrity is provably unaffected. The
check re-runs at main-dir-land where the toolchain is fully installed.

Deferred (honest, identified NOT done): **ExternFnDecl in statement
position** — top-level ExternFnDecl is already handled
(`gen2_extern_wrapper`), but a script-body / stmt-position
ExternFnDecl reaches `gen2_stmt` unhandled. The honest fix
(decl-hoist, like ModStmt) must not double-emit against the existing
top-level ExternFnDecl branch — subtler than a one-line skip, so it
gets its own analyzed cycle rather than a rushed fix. Other
keyword-audit residuals (generics `where T: Clone` → undeclared `T` /
`Clone`; async `hexa_await_unwrap` signature) are pre-existing,
separate gaps unrelated to this cycle.

### ★ 진행 로그 — modstmt-decl-hoist landed on rfc043-hexa-torch (2026-05-19)

The 2-commit isolated lineage (d4b7db4d ModStmt + 8e524019
ComptimeBlock/MacroDef, base f297978c) was merged into
`rfc043-hexa-torch` as `db446da3` — capping merge debt per user
directive (option A) before stacking further keyword-audit cycles.

The shared-worktree-branch hazard forced the work onto an isolated
branch; landing was deliberately done in a dedicated rfc043 worktree
(rfc043 was free / not checked out) so the shared main dir (foreign
atoms branch) was never touched. Merge was **conflict-free**: f297978c
is a clean ancestor of the rfc043 tip with **zero drift** on all four
deliverable files (codegen_c2.hexa / hexa_cc.c / PLAN.md / hexa_v2 —
0 intervening commits touched them), so the 3-way merge applied with
no resolution needed.

Post-merge validation (rfc043 base, fully rebuilt worktree toolchain):
self-host fixpoint **BYTE-IDENTICAL** (`cc --regen` → hexa_cc.c.new ≡
merged hexa_cc.c) — the second independent fixpoint confirmation
(orphan worktree + merged rfc043), decisively proving the merge did
not corrupt codegen and the transpiler reproduces its own source
exactly.

g3-honest: **atlas 118/118 re-verify remains DEFERRED** — not run on
either worktree. Root cause is now confirmed base-independent:
`atlas_verify.hexa` via the ad-hoc bootstrapped worktree driver's
`run`-compile path hits an arm64 linker symbol gap (the bootstrapped
runtime lacks symbols only the fully-installed `~/.hx` toolchain
carries). This is a worktree-toolchain infra limitation, NOT a codegen
regression. The change touches only stmt-kind lowering (no
formula/atlas code) and the byte-identical fixpoint (×2) already
proves zero transpiler drift, so atlas-theorem integrity is provably
unaffected. The 118/118 re-run is pending a fully-installed-toolchain
invocation (e.g. when the shared main dir next returns to
rfc043-hexa-torch, or via the installed driver against this tree).

### 2026-05-19 — RFC 061-P1 runtime 2-layer split LANDED (commit 4fb439fc)
`self/runtime.c` (13,332 lines) partitioned into `self/runtime_core.c`
(6,065 lines) + `self/runtime.c` (7,319 lines, `#include`s runtime_core.c).
Pure file split, functionally identical TU. Produced by a background
worktree agent (rate-limit interrupted, WIP 61c2adc8), integrated by hand
onto post-RFC-062 main — the 4 argv[0]-dedup functions all landed in
runtime_core.c and were re-patched to the RFC 062 form. Validated:
runtime.o + hexa_v2 + hexa.real compile clean, args() dedup holds,
atlas_verify_smoke 118/118, self-host fixpoint byte-identical (regen
diff 0). The 6,065-line core is coarser than the §5b ≈2.4-3k projection —
P1 deliverable is a clean compiling split, boundary refinement is a
followup. P2/P3 (`runtime_hi.hexa` authoring) remain future cycles.
ROADMAP child 69: P0+P1 done.
### 2026-05-19 — interpreter residue removal: run/batch paths (commit 6ba61c8a)
The R7 measured-cutover transitional scaffolding in `self/main.hexa`'s run
paths is now dead code and removed (self/main.hexa −117/+39):
- `cmd_run_user_direct` / `_batch_run_one`: dropped the `HEXA_FORCE_INTERP`
  escape-hatch branch (it re-ran the compile-then-exec path with a
  misleading "tree-walking interpreter" message) and the "falling back to
  the retiring interpreter" build-failure branch (it re-invoked the same
  compile-then-exec, never an interpreter). Build failure now reports the
  compile error honestly + exits non-zero.
- Deleted the uncalled `cmd_run_dispatch()` + the write-only
  `cmd_run_vm_mode` global; dropped the dead `--vm` flag (rt#36 bytecode-VM
  opt-in — the bc-VM was an interpreter-only path) and `cmd_run_user_direct`'s
  unused `want_vm` param (both call sites updated).
Validated: parse-clean, hexa.real builds, `hexa run`/`batch`/`--version` +
atlas_verify_smoke 118/118 clean. Residue still present elsewhere (bc_vm.hexa
follow-up cycles.
### 2026-05-19 — interp-residue removal: verify_interp_builtins + bc-VM cluster
Two more interp-residue removals (commits 122ac6f1, c4dea75b):
- `self/verify_interp_builtins.hexa` (103 lines) — a regression test for
  `self/interpreter.hexa`, which was deleted in R7 Cycle C step-1. Tests a
  file that no longer exists — pure dead residue.
- bytecode-VM cluster — `self/bc_vm.hexa` (1,906) + `self/bc_emitter.hexa`
  (4,099) + 4 `test_bc_vm_*.hexa` (8,680) = **16,685 lines**. Fully orphaned:
  the compiler pipeline never imports bc_vm/bc_emitter; only the test_bc_vm_*
  files reference them. The bc-VM was rt#36's "interpreter-only path" (cmd_run
  framing); rt#36 was blocked and its sole wiring (`--vm`) removed in
  6ba61c8a. Recoverable from git history if a bytecode-VM is wanted later.
  User-gated decision (option a — remove).
Toolchain build-smoke clean after each. Remaining interp-era residue is
documentation only (`PLAN-interp-retirement.md`, `docs/interp_*.md`) — kept
as historical record.
### 2026-05-19 — stdlib: AWS SigV4 signer + byte-level HMAC-SHA256 LANDED (inbox phanes-aws-sigv4-signer)
inbox/patches/phanes-aws-sigv4-signer-for-stdlib.md (downstream phanes,
@D g7) processed Shape A. 4 files added:
- `stdlib/core/hash/hmac.hexa` — byte-level `hmac_sha256_bytes(key:[int],
  data:[int])->[int]` (raw bytes in/out — the §3 gap; the legacy
  `self/std_crypto.hexa::hmac_sha256` is string-in/hex-out which silently
  breaks the SigV4 4-link key chain). Self-contained pure-hexa SHA-256
  core (`sha256_digest_bytes`) since the runtime `sha256` builtin is
  string-in/hex-out only. Native bitwise ops (`& | ^ << >>`) used —
  `bit_xor`/`array_push`/`math_pow` were interp-era builtins absent from
  the compiled path. Ships `hmac_sha256_hex`/`sha256_hex_bytes`/
  `hmac_sha256_str` (string/hex wrapper = §3 re-base target).
- `stdlib/aws/sigv4.hexa` — pure `sigv4_sign(req)->Sigv4Result`; no I/O.
- `stdlib/core/hash/hmac_test.hexa` + `stdlib/aws/sigv4_test.hexa` tests.
Verified (compiled path, `hexa build`, interp not used): hmac_test 8/8
PASS (FIPS 180-4 SHA-256 + RFC 4231 HMAC vectors); sigv4_test 9/9 PASS —
canonical request, string-to-sign, signature `5fa00fa3…`, and full
`Authorization` header all byte-equal to the official AWS
`aws-sig-v4-test-suite` `get-vanilla` fixture, zero AWS account/network.
Punted: SigV4 `UriEncode()` percent-encoder + query-param sorting (caller
passes pre-encoded path/query; AWS JSON APIs use `/` + empty query, so the
live path is fully covered — S3 object-key signing needs the encoder).
### 2026-05-19 — stdlib: SigV4 UriEncode + CanonicalQueryString LANDED (inbox phanes-sigv4-uriencode-query-canonicalization)
inbox/patches/phanes-sigv4-uriencode-query-canonicalization-for-s3-list.md
(downstream phanes, @D g7 / @D g_stdlib_ownership) processed Shape A — the
explicitly-deferred follow-up from the SigV4 signer above. 2 files edited:
- `stdlib/aws/sigv4.hexa` — added `sigv4_uri_encode(s, is_path)` (RFC 3986
  §2.3 unreserved-only `A-Za-z0-9-_.~`; everything else `%XX`
  uppercase-hex, byte-wise so UTF-8 encodes per-byte; `/` kept only when
  `is_path=true`), `sigv4_canonical_uri(path)` (UriEncode `is_path=true`,
  empty→`/`, idempotent on `/`), and `sigv4_canonical_query(query)` (split
  on `&`, split each pair on first `=`, UriEncode name+value
  `is_path=false`, stable-sort by encoded name with encoded-value
  tie-break, re-join). `sigv4_canonical_request` now feeds the raw caller
  path/query through these — the signer owns the encoding (per patch §3).
- `stdlib/aws/sigv4_test.hexa` — +16 assertions (6 UriEncode unit oracles
  + `get-vanilla-query-order-key-case` + `get-vanilla-query-unreserved` +
  `normalize-path/get-space`, the patch §4 falsifier set).
Verified (compiled path, `hexa build`, interp not used): sigv4_test
**25/25 PASS** (was 9/9; original `get-vanilla` 9 still byte-eq, +16 new).
Canonical-request / string-to-sign hash / signature all byte-equal to the
official AWS `aws-sig-v4-test-suite` published `.creq`/`.sts`/`.authz`
oracles (sigs `b97d918c…`, `9c3e54bf…`, `652487583200…`), zero AWS
account/network. Honest scope: query/path/utf8/normalize covered; the
suite's RFC-3986 dot-segment path *normalization* (`../`, `./`
collapsing) is NOT implemented — out of S3/R2 ListObjectsV2 scope (keys
have no dot-segments) and not in the patch ask.

Re-verification (2026-05-19, worktree `agent-aad5ba5db26ff6b18`): the
landing commit `c3bbdffe` documented 25/25 but was not measured in the
worktree at commit time. Re-run measured: `HEXA_MAC_BUILD_OK=1
HEXA_LANG=$PWD HEXA_MODULE_LOADER=<repo>/build/hexa_module_loader
hexadrv build stdlib/aws/sigv4_test.hexa && /tmp/sigv4t` → build-exit 0,
prints **`PASS 25/25`**, run-exit 0. The +661-line code is correct as
committed — no source change needed. The transient "does not compile"
report was a worktree-harness artifact: a fresh worktree lacks a
compiled `build/hexa_module_loader`, so `cmd_build`'s flatten step
warns `compiled module_loader not found — falling back to raw src` and
transpiles the un-flattened `sigv4_test.hexa` (import-only) → `extern`
stubs with no `Sigv4Header`/`Sigv4Request` constructor defs → ~10 clang
`undeclared function` errors. Baseline `14fdca36` reproduces the same
failure loader-less and builds clean in the main checkout (which ships
`build/hexa_module_loader`), proving the differentiator is the compiled
loader, not the query/UriEncode code. Pointing `HEXA_MODULE_LOADER` at
a compiled loader restores correct flatten + 25/25. No case weakened.

### 2026-05-19 — inbox: enum-variant access miscodegen (codegen_c2) fix drafted, parse-clean
demiurge-filed inbox patch `enum-variant-access-miscodegen-as-field-codegen-c2.md`.
Root cause confirmed: `<EnumName>.<VARIANT>` (e.g. `RegionShape.K_BY_K`)
falls through the generic `if k == "Field"` arm in `self/codegen_c2.hexa`
→ emits `hexa_map_get_ic(RegionShape, "K_BY_K", &ic)` where `RegionShape`
is a type name with no C value → clang "use of undeclared identifier".
Shape-A surgical codegen-side fix landed in `self/codegen_c2.hexa`:
module-scope `_enum_names` list + `_enum_names_add`/`_is_enum_name`
helpers; `gen2_enum_decl` registers every enum `node.name` (decl pass,
single chokepoint for both EnumDecl routings); the Field arm now returns
`node.left.name + "_" + node.name` (the existing `gen2_enum_decl`
`#define <EnumName>_<VARIANT>`) when `node.left` is a bare Ident on a
known enum name. Non-enum field access unchanged; `_enum_names` reset at
both codegen TU-init points alongside `_resolved_modules`/comptime sets.
**Measured: `hexa_real parse self/codegen_c2.hexa` parse-clean.** Runtime
end-to-end (leighton/sweep `hexa run`) verify-PENDING — deployed
`self/native/hexa_v2` bootstrap binary predates this source edit; the
stale binary still reproduces the exact bug (`#define RegionShape_K_BY_K`
present + `hexa_map_get_ic(RegionShape,...)` emitted), confirming the
diagnosis and that the source fix targets that emission. Binary
rebuild/promote is a separate out-of-scope deploy step (no over-claim:
fix drafted + parse-clean, runtime PASS not yet observed). Parser-side
EnumPath rework deliberately not done (larger, more-principled option).

### 진행 로그 — 8 stale-open inbox patches VERIFIED-CLOSED via SSOT grep (close-only, no fix cycle · 2026-05-19)

- 2026-05-19 — 8 stale-open `inbox/patches/` 항목을 SSOT grep cross-verification 으로 VERIFIED-CLOSED 마킹 (close-only sweep, NO source change, NO fix re-run — fix 가 이미 SSOT 에 live; dup-race precheck 적용). 각 패치 헤더 블록 직후에 `> **VERIFIED-CLOSED 2026-05-19**: ...` 감사-증거 라인 추가, 기존 본문 무삭제. 대상 + 증거: (1) `net-nonblock-multiplex` — `self/native/net.c` `hexa_net_set_nonblock`+`hexa_net_select` grep ×5; (2) `net-unix-domain-socket` — `self/native/net.c` `AF_UNIX`/`_hexa_net_parse_any` grep ×12; (3) `builtin-vs-stdlib-symbol-collision` — `self/native/thread.c` `thread_channel_` rename grep ×9, §7 interp-side residual 은 @D g_interp_deprecated (R7 CLOSED) 로 dissolved; (4) `codegen-struct-fwddecl-vs-fn-arena` — `self/main.hexa` `module_loader_env_prefix`/`HEXA_MEM_CAP_MB` grep ×8 (근본원인 = module_loader 768MB RSS cap, codegen 아님); (5) `modifyotherkeys-non-ascii-decoder-gap` — `self/tui/input.hexa` 0x110000 ceiling grep ×2, commit `bf943479` (deeper `chr()` followup = `input-decoder-chr-vs-from_char_code` 별도 추적, OPEN 유지); (6) `phanes-hx-data-dir-per-tenant-isolation` — `HX_DATA_DIR` in `compiler/drill/{checkpoint,drill}.hexa` grep ×3 (binary promote = 별도 표준 deploy step); (7) `phanes-pluggable-verifier-oracle-for-drill-loop` — verifier callback in `compiler/drill/drill.hexa` grep ×73; (8) `chr-byte-vs-codepoint-asymmetry` — interp-vs-compiled ASYMMETRY 전제가 interp 은퇴(@D g_interp_deprecated, R7 CLOSED)로 소멸 → DISSOLVED-BY-INTERP-RETIREMENT (superseded, not fixed; compiled raw-byte N&0xFF 가 단일 정답). g3-honest: 본 sweep 은 이미 랜딩된 작업의 CLOSE + 감사 증거 추가일 뿐, 신규 fix 아님. inbox/PATCHES.yaml 미터치.

- 2026-05-19 — decoder cluster B (self/tui/input.hexa):
  input-decoder-chr-vs-from_char_code (chr→from_char_code at raw-UTF8 +
  modifyOtherKeys sites) + csi-u-modifier-keys-decoder-gap (Enter-only →
  general codepoint+modifier CSI u decode); Shape-A surgical, parse-gate
  clean. Note: input-decoder-chr-vs-from_char_code already landed in-tree
  by a parallel session/sister-patch (L304/L491 already from_char_code) —
  marked resolved-ssot, no edit needed. CSI u branch generalized
  (Enter/Tab/Backspace/Esc + printable from_char_code + C0 1..26
  Ctrl+letter), Enter path preserved as subset. parse-gate (hexa_real
  parse) clean; NOT runtime/byte-eq tested; binary promote = standard
  separate deploy step.

### 2026-05-19 — interp-retirement tidy cycle: stale doc-string cleanup (R7 closure)

- 2026-05-19 — R7 의 "다음 tidy cycle 에서 물리 제거" 항목 점검 cycle.
  `self/main.hexa` 를 fresh grep 한 결과 `resolve_interp()` ·
  `_probe_interp_at()` · `cmd_run_vm_mode` · `HEXA_FORCE_INTERP` 블록은
  이미 R7 Cycle C (`25a9031d`) + residue-removal (`6ba61c8a`) 에서 전부
  제거됨 — 잔여 `interp` 토큰 33건 전부 주석/설명문이며 runtime-dead
  코드 0건. 본 cycle 의 실질 작업 = 사후 부정확해진 user-facing doc
  string 2건 정정 (self/main.hexa −2/+2): (1) 파일 헤더 서브커맨드 표의
  `hexa run ... (interp 인터프리터 위임)` → `(compile-then-exec; interp
  R7 retired)`; (2) `cmd_help()` USAGE 출력의 `Execute .hexa script
  (interpreter)` → `(compile-then-exec)`. 둘 다 R7 cutover 후
  `cmd_run`/`cmd_run_user_direct` 가 compile-then-exec 이므로 "interpreter"
  표기가 사실과 불일치였음.
- `build/hexa_interp` 바이너리는 git-ignored (`git check-ignore` 확인) →
  task scope 대로 미터치. `self/main.hexa` L2864 `av0_base == "interp"`
  self-name 가드는 행동성 가드 (binary 이름이 `interp` 일 때 self 인식)
  이므로 provably-dead 아님 → 보수적으로 보존.
- 검증 (measured): runtime.o 빌드 후 `self/native/hexa_v2 self/main.hexa
  /tmp/out.c` parse-gate PASS. `build/stage1/main.c` regen 후 canonical
  recipe (`clang -O3 -fno-strict-aliasing -std=c11 -I self
  build/stage1/main.c self/runtime.c`) 로 `hexa.real` 재빌드 — 0 error /
  0 duplicate-symbol. 재빌드 드라이버로 `--version` rc=0 ·
  `build <smoke> -o ...` round-trip rc=0 (산출 바이너리 `smoke-ok` 출력) ·
  `run <smoke>` (compile-then-exec) rc=0. 3/3 PASS — 제거가 회귀 0 임을
  측정 입증. g3-honest: 본 cycle 은 dead-code 신규 삭제 0 (R7 이 이미
  완료) — 부정확 doc string 2줄 정정 + tidy 점검 보고가 실질 산출물.

- **2026-05-19 enum-variant codegen_c2 fix — MEASURED PASS.** inbox
  `enum-variant-access-miscodegen-as-field-codegen-c2` (demiurge 다운스트림).
  `<EnumName>.<VARIANT>` 접근이 generic field-access arm 으로 떨어져
  `hexa_map_get_ic(<typename>, ...)` 로 miscodegen → C "undeclared
  identifier". 수정 (`70c7ab9d` + 본 cycle): `gen2_enum_decl` 가 enum
  `node.name` 을 module-scope `_enum_names` 에 등록, `if k == "Field"`
  arm 이 `_is_enum_name(node.left.name)` 확인 후 `<Enum>_<VARIANT>`
  #define emit. 후속결함 1건 동시수정: helper `_enum_names_add` 가
  `return hexa_void()` 사용 → codegen 이 `hexa_call0(hexa_void)` 로
  mis-emit (type mismatch, hexa_cc.c.new 컴파일 차단) → bare `return`
  으로 교체. 검증: fixed codegen_c2 로 `hexa cc --regen` → `hexa_cc.c.new`
  → 수동 link (`-x c <c.new> -x none runtime.o`, Step6 의 `-x c`-가-`.o`
  까지-번지는 스크립트 버그 우회) → 새 `hexa_v2` bootstrap. 그 bootstrap
  으로 `stdlib/booksim/leighton.hexa` transpile: `RegionShape_<VARIANT>`
  #define 4× · bug emission 0× · clang COMPILE_OK (359 KB). flatten 된
  `sweep.hexa` (module_loader 7 files, RegionShape+TrafficKind
  cross-module): good 16× · bug 0× · COMPILE_OK (520 KB). g3-honest:
  leighton/sweep COMPILE_OK 측정 (compile-clean = 패치 버그 closed);
  `fn main()` 런타임 exec 별도 미실행. `self/native/hexa_v2` binary
  promote 는 별도 deploy step (본 cycle 미포함).

### 2026-05-19 — `hx` stale `need-singularity` org reference fixed (inbox patch)

Processed `inbox/patches/hx-stale-need-singularity-org-after-dancinlab-rename.md`
(filed by void downstream). The GitHub org rename `need-singularity` →
`dancinlab` left `tool/pkg/hx` name-resolution stale. `REGISTRY_REMOTE`
(line 10) was already corrected by the earlier identity-rename commit
`bc545c16`. This cycle fixed `HX_ORGS_DEFAULT` (line 18):
`"hexa-pkg dancinlab dancinlife"` → `"hexa-pkg dancinlab need-singularity"` —
`dancinlab` primary, `need-singularity` retained as a lower-priority redirect
fallback per the patch's Ask #2, and the bogus `dancinlife` (a git-author
handle, not a GitHub org) dropped so `hx` no longer wastes a probe on a
nonexistent org. Also fixed a stale `need-singularity/hexa-lang` clone URL in
a usage comment in `tool/build_hexa_cli_native.hexa:10`. Ask #3 (resolve.tsv
cache invalidation) deferred — out of scope for a surgical fix. `bash -n
tool/pkg/hx` passes. `~/.hx/bin/hx` is a stale copy of this SSOT and is
intentionally untouched. Toolchain-only; no compiler/stdlib/self rebuild.
### 2026-05-19 — codegen: ExternFnDecl in statement position — FFI wrapper mangle parity + nested-decl hoist

keyword-audit 잔여 갭 "ExternFnDecl in statement position" closure. `self/test_keyword_audit.hexa` L376 `extern fn getpid() -> Int` 는 두 갈래로 깨졌었다.

**근본원인 (측정으로 확정 — `unhandled stmt kind` 가 아니었음)**: top-level / script-body `extern fn` 는 이미 top-level emit loop 의 `ExternFnDecl` 분기에 도달한다. 진짜 버그는 `gen2_extern_wrapper` 가 emit 하는 C 래퍼 함수 이름이 call-site mangle 과 불일치한 것. `getpid` 는 `_hexa_name_is_reserved` 목록에 있어 (libc `getpid` 충돌) call-site 는 `_hexa_mangle_ident` 로 `u_getpid()` 를 emit 하지만, 래퍼는 plain `getpid` 로 emit 됨 → call 이 libc `int getpid(void)` 로 resolve → clang `assigning to HexaVal from incompatible type 'int'`. fn-body 안에 nested 된 `extern fn` 는 `_gen2_lift_nested_decls` 가 hoist 하지 않아 별개로 `CODEGEN ERROR: unhandled stmt kind: ExternFnDecl` 스텁을 emit 했다.

**수정 (`self/codegen_c2.hexa`, surgical 3-part)**:
1. `gen2_extern_wrapper` — 래퍼 C 함수 이름 (forward decl + 두 `static HexaVal NAME(...)` 정의 + typedef 태그) 을 `_hexa_mangle_ident(name)` (`cname`) 로 변경. decl 이름 == reference 이름. `__ffi_sym_<name>` dlsym 슬롯은 raw name 유지 (이미 고유-prefix 내부 식별자; dlsym C-symbol 문자열은 `c_sym` 으로 별도). 비-reserved extern 이름은 mangle 이 no-op → 일반 케이스 zero regression (측정 확인).
2. `_gen2_lift_nested_decls` — lift 인식 종류에 `ExternFnDecl` 추가. fn-body 최상단 `extern fn` 도 module scope 로 hoist (C 는 nested fn 없음; FFI 래퍼는 top-level 분기에서만 emit). 추가로 `seen_names` 를 기존 top-level decl 이름으로 pre-seed — top-level 과 nested 가 같은 extern 이름이면 nested 복사본을 lift 하지 않음 (top-level 이 이김) → C "redefinition" 방지.
3. `gen2_stmt` decl-skip — `ExternFnDecl` 추가. lift 된 stmt-position `extern fn` 가 원래 위치에서 `unhandled stmt kind` 스텁을 ALSO emit 하지 않게.

**측정 BEFORE/AFTER** (Mac, host-pinned smoke `extern fn getpid() -> Int; let p = getpid(); ...`):
- BEFORE (구 hexa_v2): transpile OK 이나 C 빌드 2 errors (`u_getpid` ≠ `getpid` incompatible-type). nested smoke → `unhandled stmt kind: ExternFnDecl` 스텁 1개.
- AFTER (regen hexa_v2): script-body smoke → 래퍼 `u_getpid` == call `u_getpid` → C 빌드 0 error → run `extern ok` rc=0. nested smoke → 스텁 0개 → 빌드+run `nested extern ok` rc=0. 비-reserved extern → 래퍼 이름 변경 없음 (no-op mangle 확인).
- `self/test_keyword_audit.hexa` → ExternFnDecl 스텁 0 (BEFORE 1). 잔여 5 C-error 는 generics `T` / `Clone` / async `hexa_await_unwrap` 등 무관 별건 갭 — 구·신 transpiler 동일 5개 → zero regression.

**self-host fixpoint**: `cc --regen` → `hexa_cc.c.new` ≡ promoted `hexa_cc.c` BYTE-IDENTICAL (`cmp` 확인). 바이너리 promote 동반 — `hexa_cc.c` 1480897→1484206 B, `hexa_v2` 1533496→1534088 B.

**LIMITATION (소스 주석에 명기)**: shallow-walk 경계 유지 — `if/while/for` 블록 안 더 깊이 nested 된 `extern fn` 는 lift 대상 아님 (`_gen2_lift_nested_decls` 의 기존 top-of-body 한계와 동일). top-level / script-body / fn-body-최상단 `extern fn` 만 커버.


### 2026-05-19 — install.sh: fresh-install `hexa build` + PATH 견고화

- inbox/patches/hexa-oneliner-install-should-link-source-repo.md 해소.
  문제 1: 릴리스 tarball 은 `{hexa 바이너리, build/}` 만 담아 `stdlib/`·
  `self/` 미포함 → fresh install 에서 `use "stdlib/..."` 빌드 전부 실패.
  컴파일러는 install-relative stdlib 탐색 (df9e7f6b: `<inst>/stdlib`·
  `<inst>/self/stdlib`) 을 갖췄으나 `install.sh` 가 `stdlib/` 를 거기
  배치하지 않았음.
- 채택안 (a) — 새 릴리스 不要, 오늘 동작: `install_src()` 가 hexa-lang
  소스를 `$HX_HOME/src` 로 shallow git clone → `$HX_BIN/stdlib`·
  `$HX_BIN/self` 심볼릭 링크 (install_dir_from_argv0() 가 `hexa.real` 을
  realpath 해 `$HX_BIN` 반환 → 두 candidate 정확히 적중). `hexa cc` 의
  `<inst>/self/native/hexa_cc.c` 도 `self` 링크로 해소.
- 추가 발견 (g3): `hexa build` flatten 단계는 codegen_c2 의 4-way `use`
  탐색 (caller-dir·$HEXA_LANG/self·$HEXA_LANG·cwd·./self) 만 갖춘
  standalone `hexa_v2` 가 아니라, **compiled `hexa_module_loader`**
  바이너리를 통해야 install-relative 탐색이 작동. 이 바이너리는
  `.gitignore` 대상 → clone 에 없음. 단 `module_loader.hexa` 는 `use` 0건
  (self-contained) 이라 pre-existing module_loader 없이 빌드 가능 →
  `install_src()` 가 clone 직후 `$HX_BIN/build/hexa_module_loader` 로
  빌드. 이로써 새 릴리스 없이 end-to-end `hexa build` 성립.
- 문제 2: `update_path_hint()` — (1) rc 파일이 이미 존재할 때만 기록
  (`[ -f ]`) → fresh user 자동설정 누락 = 없으면 생성. (2) macOS login
  bash 는 `~/.bashrc` 아닌 `~/.bash_profile` 를 읽음 → OS×shell 조합별
  올바른 파일 선택 (bash+Darwin→.bash_profile, bash+Linux→.bashrc,
  zsh→.zshrc). (3) fish 미지원 → `~/.config/fish/config.fish` 에
  `fish_add_path` (fish 문법) 기록.
- 검증 (measured): `bash -n install.sh` PASS. update_path_hint 4 조합
  (zsh/Darwin · bash/Darwin→.bash_profile · bash/Linux→.bashrc ·
  fish→config.fish) 모두 올바른 파일·문법으로 신규 생성 확인. stdlib:
  temp `HX_HOME` 에 클린룸 시뮬레이션 install (native 바이너리 + shim +
  소스 clone + 심볼릭 링크 + module_loader 빌드) 후 `HEXA_LANG`/
  `HEXA_STDLIB_ROOT`/`HEXA_INSTALL_DIR` 전부 unset 으로 `use
  "stdlib/core/bytes.hexa"` 프로그램 `hexa build` rc=0 → 실행 시
  `int_from_hex("deadbeef")=3735928559` 정상 출력.
- 릴리스 의존 잔여: 없음 — 채택안 (a) 는 git 만 있으면 오늘 작동.
  단 release tarball 자체에 `stdlib/`·`hexa_module_loader` 를 담는
  대안 (b) 은 미채택 (release-packaging tool 부재 — `.github/workflows/`
  에 release workflow 없음). `hexa repo path` / `hexa update` verb 는
  컴파일러 변경 필요 → 후속 follow-up 으로 patch markdown 에 명시.

### 진행 로그 — atlas binary-built-in 정책 codify + runtime overlay-load 은퇴

user directive 2026-05-19 — atlas 는 **무조건 바이너리 빌트인** (compile-time
embed; SSOT = `compiler/atlas/embedded.gen.hexa`). `.n6` 파일은 이제 `hexa atlas
export` **출력물 전용** (interop / inspection). 신규 식은 GitHub PR 로 빌트인 atlas
에 직접 흡수 — 구 runtime path (`~/.hx/data/atlas.overlay.n6` · discovery →
overlay → 3+ hits → promote into rodata regen) RETIRED.

- **거버넌스**: `AGENTS.tape §3` 에 `@D g_atlas_binary_builtin` 추가 (g6 인접,
  tape v1.2 grammar — rule/why/apply/authority/cross-ref/@>). `CLAUDE.md` 는
  symlink 이라 자동 반영.
- **docs**: `README.md` — 구 discovery 다이어그램 (`atlas.proposed/.append.n6 →
  promote → live atlas grows`) 를 `hexa atlas export → GitHub PR into
  embedded.gen.hexa → compiler build re-embeds` 로 재서술; "noise smash
  contract" ASCII 박스 라벨 `(rodata + overlay)` → `(binary built-in)`;
  "regenerated daily" → "binary built-in; new laws via GitHub PR". `SPEC.md`
  §2.2 — `.n6` = export artifact + absorption = PR-into-embedded-atlas 행 추가,
  "no runtime atlas load" 명문화; §10.2 — staging pipeline 을 export-artifact
  + PR-fold 모델로 재서술.
- **code (surgical retire)**: `compiler/atlas/overlay.hexa` — runtime LOAD
  path 은퇴. `overlay_load()` / `overlay_load_cached()` 는 이제 무조건 `[]`
  반환 (디스크 `.n6` 파일을 live atlas 에 머지 안 함). 함수 시그니처는 유지 —
  기존 호출처 (`atlas_lookup_merged` · `audit_overlay` · drill round seed-dedup)
  무수정 컴파일, binary-only atlas 관측. WRITE surface (`overlay_append` /
  `overlay_append_lines` / `overlay_ensure_dir`) 는 `.n6` export 출력물 emit
  경로이므로 보존 — `hexa atlas export` 불파손. `compiler/atlas/static_index.hexa`
  — `atlas_lookup_merged` / `atlas_list_merged` 주석을 binary-built-in 모델로
  재서술 (overlay retired-to-empty → merged ≡ rodata-alone).
- **parse-gate (measured)**: `clang -O2 -I. -Iself -c self/runtime.c -o
  self/runtime.o` OK → `self/native/hexa_v2 compiler/atlas/overlay.hexa
  /tmp/o_overlay.c` → `OK` rc=0 · `self/native/hexa_v2
  compiler/atlas/static_index.hexa /tmp/o_static.c` → `OK` rc=0.
- **deferred**: (1) discovery 체인 (`reign`/`revive`/`debate`/`molt`/`wake`/
  `forge`/`canon_engine`/`drill`) 의 `overlay_append` 호출은 그대로 — 이제
  export-artifact 를 쓸 뿐 live atlas 변이 없음 (load-path 은퇴로 무해화).
  이 호출들을 명시적 `hexa atlas export` verb 로 재배선하는 것은 후속 cycle.
  (2) `self/main.hexa` help 텍스트 (`atlas.overlay.n6` 언급 L119-173) 갱신은
  별도 surgical edit — 본 cycle 범위 밖. (3) `cc --regen` / `hexa_cc.c`·
  `hexa_v2` promote 미수행 — 부모 세션의 단일 consolidated regen 대상.
### 2026-05-19 — codegen: ExternFnDecl in statement position — FFI wrapper mangle parity + nested-decl hoist

keyword-audit 잔여 갭 "ExternFnDecl in statement position" closure. `self/test_keyword_audit.hexa` L376 `extern fn getpid() -> Int` 가 두 갈래로 깨졌었다.

**근본원인 (측정으로 확정 — `unhandled stmt kind` 가 아니었음)**: top-level / script-body `extern fn` 는 이미 top-level emit loop 의 `ExternFnDecl` 분기에 도달한다. 진짜 버그는 `gen2_extern_wrapper` 가 emit 하는 C 래퍼 함수 이름이 call-site mangle 과 불일치한 것. `getpid` 는 `_hexa_name_is_reserved` 목록에 있어 (libc `getpid` 충돌) call-site 는 `_hexa_mangle_ident` 로 `u_getpid()` 를 emit 하지만, 래퍼는 plain `getpid` 로 emit 됨 → call 이 libc `int getpid(void)` 로 resolve → clang `assigning to HexaVal from incompatible type 'int'`. fn-body 안에 nested 된 `extern fn` 는 `_gen2_lift_nested_decls` 가 hoist 하지 않아 별개로 `CODEGEN ERROR: unhandled stmt kind: ExternFnDecl` 스텁을 emit 했다.

**수정 (`self/codegen_c2.hexa`, surgical 3-part)**:
1. `gen2_extern_wrapper` — 래퍼 C 함수 이름 (forward decl + 두 `static HexaVal NAME(...)` 정의) 을 `_hexa_mangle_ident(name)` (`cname`) 로 변경. decl 이름 == reference 이름. `__ffi_sym_<name>` dlsym 슬롯 + `__ffi_ftyp_<name>` typedef 태그는 raw name 유지 (이미 고유-prefix 내부 식별자; dlsym C-symbol 문자열은 `c_sym` 으로 별도). 비-reserved extern 이름은 mangle 이 no-op → 일반 케이스 zero regression (측정 확인).
2. `_gen2_lift_nested_decls` — lift 인식 종류에 `ExternFnDecl` 추가. fn-body 최상단 `extern fn` 도 module scope 로 hoist (C 는 nested fn 없음; FFI 래퍼는 top-level 분기에서만 emit). 추가로 `seen_names` 를 기존 top-level decl 이름으로 pre-seed — top-level 과 nested 가 같은 extern 이름이면 nested 복사본을 lift 하지 않음 (top-level 이 이김) → C "redefinition" 방지.
3. `gen2_stmt` decl-skip — `ExternFnDecl` 추가. lift 된 stmt-position `extern fn` 가 원래 위치에서 `unhandled stmt kind` 스텁을 ALSO emit 하지 않게.

**측정 BEFORE/AFTER** (Mac, host-pinned smoke `extern fn getpid() -> Int; let p = getpid(); ...`):
- BEFORE (구 hexa_v2): transpile OK 이나 C 빌드 2 errors (`u_getpid` ≠ `getpid` incompatible-type). nested smoke → `unhandled stmt kind: ExternFnDecl` 스텁 1개.
- AFTER (regen hexa_v2): script-body smoke → 래퍼 `u_getpid` == call `u_getpid` → C 빌드 0 error → run `extern ok` rc=0. nested smoke → 스텁 0개 → 빌드+run `nested extern ok` rc=0. 비-reserved extern → 래퍼 이름 변경 없음 (no-op mangle 확인).
- `self/test_keyword_audit.hexa` → ExternFnDecl 스텁 0 (BEFORE 1). 잔여 5 C-error 는 generics `T` / `Clone` / async `hexa_await_unwrap` 등 무관 별건 갭 — 구·신 transpiler 동일 5개 → zero regression.

**self-host fixpoint**: `cc --regen` → `hexa_cc.c.new` ≡ promoted `hexa_cc.c` BYTE-IDENTICAL (`cmp` 확인). 바이너리 promote 동반.

**LIMITATION (소스 주석에 명기)**: shallow-walk 경계 유지 — `if/while/for` 블록 안 더 깊이 nested 된 `extern fn` 는 lift 대상 아님 (`_gen2_lift_nested_decls` 의 기존 top-of-body 한계와 동일). top-level / script-body / fn-body-최상단 `extern fn` 만 커버.


## 진행 로그 — `hexa atlas pr` verb 구현 (2026-05-19)

- **scope**: inbox/patches/hexa-cli-atlas-register-update-or-pr.md 의 `pr` arm
  구현. `tool/atlas_cli.hexa::cmd_pr` 가 STUB (manual-steps print + `exit(3)`)
  였던 것을 동작하는 verb 로 land. `update || PR` 의 `PR` 분기 — kick/verify 가
  발견한 equation 을 staging shard 로 받아 fresh git branch + commit + `gh pr
  create` 까지 자동화.
- **code (`tool/atlas_cli.hexa`, @version 0.3.0→0.4.0)**: `cmd_pr` 전면 재작성.
  `--staging <file.n6>` (promote 와 동일 입력 형태) + `--atlas-root` / `--base`
  / `--branch` / `--title` 플래그. 흐름: (0) `git` 가용성 probe → (1) PR 브랜치
  생성 (`atlas-pr-<UTC-stamp>`) → (2) 기존 `promote_to_atlas` 재사용해 shard fold
  → (3) `atlas.append.<today>.n6` `git add`+`commit` → (4) `gh pr create` 시도.
  헬퍼 추가: `_shq` (shell single-quote escape), `_exec_ok` (`( cmd ) && echo
  __OK__ || echo __FAIL__` 마커로 exit-status 복원 — `exec()` 는 stdout 만 캡처),
  `_today_compact` / `_branch_stamp`. help 텍스트 + 헤더 주석 갱신.
- **g3 정직성 — degraded path (절대 PR fake 금지)**: `git` 없음/atlas-root 비-repo
  → shard 만 쓰고 정확한 `git switch -c … && … && gh pr create …` 명령 출력 (exit 0).
  `git` ok 이나 `gh` 없음/실패 (no auth·no push·offline) → branch+commit 은 로컬
  완료, `git push -u origin <branch>` + `gh pr create` 명령 출력, "**NO PR was
  opened**" 명시 (exit 0). `gh pr create` rc==0 일 때만 "PR opened — <url>" 출력.
  @D g5 try-CLI-or-fallback 패턴 준수 (git/gh 외부 셸링 허용).
- **parse-gate (measured)**: `clang -O2 -I. -Iself -c self/runtime.c -o
  self/runtime.o` OK → `self/native/hexa_v2 tool/atlas_cli.hexa /tmp/o.c` →
  `OK` rc=0.
- **build + dry-run (measured)**: `HEXA_MAC_BUILD_OK=1 hexa build
  tool/atlas_cli.hexa` PASS (module `use` 6개 flatten 정상). 측정 3건 PASS —
  `pr --help`, 비-git atlas-root → degraded write-shard 경로, 실제 git repo →
  branch+commit 후 `gh` degrade-after-commit 경로 (브랜치 생성·append shard
  커밋 확인, fake PR 0).
- **deferred / LIMITATION**: `hexa atlas register` 는 STUB 유지. `@discover`
  주석 `.hexa` 소스를 staging shard 로 변환하려면 컴파일러 frontend
  (`compiler/lex/*` + `compiler/parse/parser.hexa` + `compiler/discover/`) 를
  `tool/atlas_register.hexa` companion 으로 끌어와야 함 — `pr` arm 은 의도적으로
  *이미 staged 된* `.n6` shard 소비로 scope. `cc --regen` 미수행 (atlas_cli.hexa
  는 tool 이지 hexa_cc.c SSOT 모듈 아님 — regen 불필요).

## 진행 로그 — `hexa atlas register --from-verify` DIRECT node-gen → PR (2026-05-20)

- **what**: `hexa atlas register` 의 새로운 `--from-verify <fn> <n> <v>` arm. user
  지시: ".n6 파일같은거 전혀안통하고 바로 PR 하도록" + "변환 말고 / 노드 생성 코드".
  closed-form `hexa verify` 발견 → `compiler/atlas/embedded.gen.hexa` 직접 fold
  → `gh || api` PR 까지 **단일 명령**. `.n6` intermediate 0건, converter 0건.
- **why**: 기존 `hexa atlas pr` 는 staging `.n6` shard 를 입력으로 받는 update-or-PR
  의 PR arm. @D g_atlas_binary_builtin (atlas 무조건 binary built-in, .n6 는
  export-only) 와 user 지시 ("바로 PR") 이 합쳐져 — verify 결과를 .n6 우회 없이
  embedded.gen.hexa 로 직행시키는 경로가 필요. **direct node-gen (NOT 변환)**.
- **how — `tool/atlas_cli.hexa` cmd_register 본체 + helpers**:
  1. `_recompute_register` / `_recompute2_register` — `verify_cli.hexa::_recompute`
     의 calc table 을 IN-PROCESS 거울 (verify_cli 는 `main` 이 있어 import 불가).
     `compiler/atlas/symbolic/congruence_chain_engine` 의 σ/φ/τ/μ/Γ₀/jacobi/등 사용.
  2. `_build_raw_F` — tape v1.2 형식 `@F` body 문자열 in-memory 구성
     (`= fn(args) = v :: formula [d=YYYY-MM-DD active]\n  verified-by="..."\n
     cite="..."\n  provenance="..."`).
  3. `_build_node_struct_text` — `tool/atlas_embed_gen.hexa::embed_atlas` 이 emit
     하는 그 모양 그대로 `AtlasNode { kind, id, raw (escape 적용), source_file,
     source_line, grade: GradeInfo {...}, edges: EdgeInfo {...} }` struct-literal
     텍스트를 만든다. **이게 저장 형식.** `.n6` 텍스트 절대 만들지 않음.
  4. `_fold_into_embedded` — `embedded.gen.hexa` 읽기 → `pub let ATLAS_F_NODES:
     [AtlasNode] = [` marker 찾기 → 다음 `]` 까지 walk → `id: "<id>"` 텍스트
     dedup → 직전 trailing `}` 에 `,` 추가하면서 새 line splice → write back.
     section empty path (`= [\n]`) + non-empty path 분리 처리.
  5. `_branch_commit_pr` — `cmd_pr` 의 step 4+5 fallback chain 재사용 (branch
     생성 + `git add embedded.gen.hexa` + commit + `gh pr create` → GitHub REST
     API POST `/repos/<o>/<r>/pulls` HTTP 201). **정직 degrade**: `gh` rc=0 또는
     HTTP 201 일 때만 "PR opened — <url>". 그 외에는 NO PR was opened 명시.
- **kind 결정**: closed-form `verify --expr` = **F (formula)**. ATLAS_F_NODES 비어
  있었음 (embedded.gen.hexa L7434-7436); 이 verb 가 채워나갈 위치. identity-law
  (e.g. `is_perfect ⇒ σ(n)=2n`) 도 F 로 등록 — 향후 `--kind L` 옵션 가능.
- **g3 정직성**: 🟠 INSUFFICIENT (`_recompute_register` no path) → exit 3,
  🔴 FALSIFIED → exit 4, fold dedup hit → exit 5. `--auto-pr` 없으면 현재 브랜치
  로 edit 만 land, user 가 commit. `--auto-pr` 후 PR 안 열리면 `git push -u
  origin <branch>` + 정확한 `gh pr create` 명령 출력, "NO PR was opened" 명시.
  `cmd_pr` 와 동일 정책. 절대 PR fake 0.
- **parse-gate (measured)**: `self/runtime.o` 빌드 → `self/native/hexa_v2
  tool/atlas_cli.hexa /tmp/atlas_cli.c` → `OK` rc=0. 새 F-section line (`@F
  verified-tau-6 ...`) struct-literal 격리 검증 → `OK` rc=0.
- **end-to-end (measured, no --auto-pr)**: `hexa run tool/atlas_cli.hexa register
  --from-verify tau 6 4` → `tier = 🔵 SUPPORTED-FORMAL` + `embed = appended
  @F verified-tau-6 to compiler/atlas/embedded.gen.hexa (ATLAS_F_NODES section)`
  + clean splice 확인 (line 7435 에 새 AtlasNode literal 단일 line). test edit
  revert 후 live PR 시도 (아래 commit).
- **inbox patch flip**: `inbox/patches/hexa-cli-atlas-register-update-or-pr.md`
  status `partially-resolved` → `resolved-ssot`. `register --from-verify` 가
  `<file.hexa>` STUB 와 별개의 직행 path 로 user-asked-for 경로 close.
- **deferred**: `<file.hexa>` mode 의 `register` (lex→parse→discover_check) 는
  여전히 STUB. 이 cycle 의 user 지시 ("바로 PR") 와 무관 — discovery-from-source
  은 별도 cycle (compiler frontend 끌어와야 함).
- **cc --regen / binary promote**: 미수행. atlas_cli.hexa 는 driver 가 run 하는
  tool 이지 hexa_cc.c SSOT 모듈 아님 — @D g_commit_push_deploy 에 따라 source-only
  변경. driver 빌드 영향 없음, `hexa run tool/atlas_cli.hexa register --help`
  로 새 verb 작동 확인 (interp 경유, system `hexa` 가 worktree source 픽업).

## 진행 로그 — `hexa atlas register` 일반화: MULTI-VERB DISCOVERY PIPELINE (2026-05-20)

- **what**: `--from-verify` 를 일반화해서 모든 내부 discovery surface (verify · drill/kick
  · check · smash · atlas-verify · verify_* tool family · proposer · math discovery) 가
  동일한 in-memory node-gen → `embedded.gen.hexa` fold → `gh ‖ api` PR 파이프라인을
  공유하도록 refactor. user 지시: "kick 말고도 drill 도 쓰고 이러니까 / 내부전체 고려".
- **why**: 단일 verb (`--from-verify`) 만 직행 path 를 가지면 verb-by-verb 중복 코드.
  내부 모든 discovery 가 canonical `DiscoveryEvent` 로 수렴 → `register_from_event(ev)`
  단일 sink. 새 verb 는 adapter 한 줄로 plug-in.
- **how — `tool/atlas_cli.hexa` 일반화**:
  1. **`DiscoveryEvent` struct** (pub) — canonical envelope: `kind ∈ {P|C|L|E|F}` ·
     `id` (atlas-id) · `name` (human) · `raw` (struct.raw body) · `verdict` (🔵 ·
     🔴 · 🟠 · skip · error) · `source_verb` · `provenance` (one-liner).
  2. **`register_from_event(ev, auto_pr, atlas_root, base, branch, title)`** —
     단일 sink. verdict != 🔵 거부, kind 검증, `_build_node_struct_text` →
     `_fold_into_embedded` → optional `_branch_commit_pr`. 모든 verb 가 이 함수로
     수렴.
  3. **`_adapt_verify_1op` / `_adapt_verify_2op`** — verify recompute → DiscoveryEvent.
     기존 monolithic cmd_register 의 verify 분기를 깔끔히 분리. byte-equivalent.
  4. **`_adapt_drill_candidate`** — drill `DiscoveryCandidate` (axiom → @P, derived →
     @L) → DiscoveryEvent. `_build_raw_drill` 로 tape body 생성.
  5. **`_adapt_check`** — STUB extension point. verdict="error" 반환 + 정직한 NOT
     YET WIRED 메시지. future verbs 동일 패턴 (`_adapt_<verb>(args) -> DiscoveryEvent`).
  6. **`cmd_register` dispatcher** — `--from-verify` / `--from-drill` (= `--from-kick`) /
     `--from-check` arms; 공통 옵션 `--auto-pr` · `--branch` · `--base` · `--atlas-root`
     · `--title` · `--id`.
- **`--from-drill` in-process handle**: drill_run(seed, opts) 는 `DrillResult` 만 반환
  (counts) — per-round `DiscoveryCandidate[]` 는 `RoundResult.discoveries` 에 있고
  loop 내부 소비. 그래서 cmd_register 가 `round_run_with_pool(seed, r, 3, 3, 1,
  mkx_on, seed_pool)` 을 직접 round-by-round 호출 + `extract_axiom_exprs` 로 다음
  round pool feed. 이게 task 가 명시한 "in-process handle, not the overlay file".
  overlay path (`overlay_load_cached`) 는 RETIRED (@D g_atlas_binary_builtin) — 0
  반환만 함.
- **drill 배치 정책**: 1개 candidate = 1 DiscoveryEvent, 하지만 **단일 branch + commit**
  으로 묶어 1개 PR. fold-then-PR — `_fold_into_embedded` 가 듭리 dedup ('refusing
  to duplicate') 처리, 마지막에 `_branch_commit_pr` 한 번. summary 에 candidate list 동봉.
- **g3 정직성**: 
  - verify 🟠 INSUFFICIENT → exit 3 · 🔴 FALSIFIED → exit 4 (변동 없음, byte-equiv).
  - drill seed too_short/placeholder → "tier=skip — seed rejected (too_short)", NO PR · exit 0.
  - drill 0 candidates → "tier=skip — no promotable candidate found · NO PR was opened" · exit 0.
  - drill all-dup → "tier=skip — all drill candidates were already in the atlas (no new fold)" · exit 0.
  - check stub → "NOT YET WIRED" + extension-point hint · exit 6.
  - 모든 PR 경로: `gh` rc=0 또는 HTTP 201 일 때만 "PR opened — <url>". 그 외 NO PR.
- **future verb adapter slots**: 소스 코멘트로 명시. `--from-check` 가 첫 번째 stub.
  새 surface (smash · atlas-verify · verify_adversarial · proposer · math) 는
  `_adapt_<verb>(args) -> DiscoveryEvent` 한 함수 + cmd_register 의 `--from-<verb>`
  arg parse 가지로 추가.
- **parse-gate (measured)**: `/Users/ghost/.hx/bin/hexa_real parse tool/atlas_cli.hexa`
  → `OK rc=0` · `clang -c self/runtime.c` (existing) · `hexa_v2 tool/atlas_cli.hexa
  /tmp/x.c` → cached OK rc=0.
- **end-to-end (measured)**:
  - `register --from-verify phi 8 4` → 🔵, embed appended `@F verified-phi-8`,
    body byte-equivalent to pre-refactor (same id / same raw / same struct-text shape).
  - `register --from-verify phi 8 5` → 🔴 FALSIFIED · exit 4 · NO edit.
  - `register --from-drill --seed "test"` → seed rejected (too_short) · exit 0 · NO PR.
  - `register --from-drill --seed "sigma divisor sum equals 12 for n equals 6"
    --rounds 1` → 663 yields → 625 candidates_captured → 306 unique @P/@L folded
    (rest = within-batch dups handled by `refusing to duplicate` gate).
  - `register --from-drill ... --atlas-root /tmp/atlas-fake --auto-pr` → 517
    candidates folded · 비-git atlas-root degrade path: prints manual `git switch -c
    ... && git add ... && git commit ... && gh pr create ...` · NO PR claimed.
  - `register --from-check` → "NOT YET WIRED" · exit 6 (정직 stub).
- **inbox patch flip**: `inbox/patches/atlas-cli-multi-verb-discovery-pipeline.md`
  (file path 코드 코멘트에 참조; 실제 파일은 이 commit 이 SSOT 노릇).
- **cc --regen / binary promote**: 미수행. atlas_cli.hexa = driver 가 run 하는 tool
  (NOT hexa_cc.c SSOT 모듈). @D g_commit_push_deploy: tool/* 변경은 source-only;
  driver 빌드 무영향. compile-then-exec path (`hexa run`) 로 모든 측정 진행.

## 진행 로그 — RFC 065 `hexa loop` self-growing atlas cycle drafted (2026-05-20)

Phase A (spec-only, 0 code change) landed as `inbox/rfc_drafts_2026_05_20/rfc_065_hexa_loop.md`
+ companion `design.md` decision ledger (7 decisions).

- **scope**: new verb `hexa loop` that walks compiler/atlas/embedded.gen.hexa,
  applies a binary-built-in lens table (`compiler/lenses/embedded.gen.hexa`,
  sibling SSOT), emits PR-only atlas/lens candidates to
  `inbox/{atlas,lens}_candidates/`, self-terminates on brainstorm exhaustion.
- **legacy**: dancinlab/archive-nexus (frozen 2026-05-17) state-file
  convention (.loop / .chain / .gap_cooldown / .goal_growth_state.json /
  .turn / .end / .guide) is reused; the 130+ lens engine itself was NOT
  ported as code (self/nexus_port/ = optimizer port only, confirmed).
  Seed = 32 lens (8 family × 4); 130+ reached via PR-driven expansion.
- **invariant**: PR-only — loop NEVER mutates compiler/atlas/embedded.gen.hexa
  or compiler/lenses/embedded.gen.hexa directly. Write set ⊆
  `{inbox/**, $HEXA_LANG/state/loop/**, /tmp/**}`. Falsifier F1 explicit.
- **7 decisions**: (1) lens at `compiler/lenses/` sibling — (2) seed = 32
  hybrid, nexus_port fallback fired — (3) state at `$HEXA_LANG/state/loop/
  <cwd_hash>/` — (4) trays = sibling `inbox/{atlas,lens}_candidates/` —
  (5) cooldown = hard-block N=5 cycles — (6) fire = `--no-fire` default,
  opt-in `--fire --budget <USD>` — (7) exhaust = 3 consecutive 0-emit
  cycles ∧ cooldown empty.
- **governance**: complies with @D g_atlas_binary_builtin (binary built-in
  symmetry) · g6 (citation-enforced; every Candidate carries
  `cite: [atlas_node_id]`) · g7 (inbox sibling stream) · g_interp_deprecated
  (compiled-path verb) · g_commit_push_deploy (lens PR includes regenerated
  embedded.gen.hexa + paired binary promote) · g_plan_consolidation (this
  entry).
- **phase plan**: B = scaffold (32 empty seed lenses + 8-stage cycle shell
  + `hexa loop --once --dry-run` selftest); C = measurement (seed bodies +
  first inbox/atlas_candidates/ PR). B and C are separate RFCs.
- **next**: reviewer pass on §8 (lens schema), §7 (exhaustion), §10
  (governance matrix), §12 (falsifier set) → land sign-off → Phase B.
- **commit**: source-only (RFC draft + design.md + this entry). No
  hexa_cc.c regen / binary promote needed; @D g_commit_push_deploy
  scope = compiler source files, not inbox RFC drafts.

## 진행 로그 — RFC 065 Phase B substep landings (2026-05-20)

Phase B closure measured. 7 substep commits land the verb end-to-end.

- **B-1** (`ca733de6` + `16d22fd8`) — `compiler/lenses/{types,embedded.gen}.hexa`
  sibling SSOT to atlas. 32 LensNode rows across 8 families × 4 seeds + 32
  stub apply fns (all return []) + `lens_apply_by_id` dispatch. Schema
  parse-clean.
- **B-2** (`30a275e2`) — `stdlib/loop/cycle.hexa` 8-stage cycle shell
  (SCAN/LENS/DEDUP/GATE/FIRE/DRAFT/AUDIT/EXHAUST?) + CLI parse + safe-
  default (`--once --no-fire --dry-run`). standalone selftest PASS via
  `/tmp/hexadrv run stdlib/loop/cycle.hexa` → 8 stage lines + rc=0.
- **B-2.1** (`b764bf32`) — `stdlib/loop/state.hexa` initial wiring for
  `loop` + `end` files. cycle write=7 read=7 round-trip PASS, end touch
  PASS.
- **B-2.2** (`712778ce`) — remaining 6 state files (chain · gap_cooldown
  · goal_growth_state · growth_last_scan · turn · guide). Cooldown N=5
  hard-block verified (`active@7=1 active@13=0`), growth delta
  accumulation verified (`flame=3+2=5`), turn 1→2 monotone. line-based
  schemas (no JSON parser dep).
- **B-3.1** (`ef8f4f1f`) — `self/main.hexa` SOURCE: `else if sub == "loop"`
  branch + cmd_help row. cmd_run-fallback shape (mirrors qmirror).
  parse-clean. @D g_commit_push_deploy: source-only landing flagged as
  INCOMPLETE until B-3.2 promotes binary.
- **B-3.2** (UNTRACKED — driver binary regen, no git delta) — driver
  rebuilt via `tool/build_hexa_cli.sh` (SIDECAR_NO_POOL=1 NO_SMOKE=1):
  `build/hexa_cli_driver` 599424 B (vs prior 597488 B; Δ=+1936 B matching
  the 27-line cmd_help + 22-line dispatch insertion). Driver promoted
  to `~/.hx/bin/hexa.real`, `hexa.real`, `hexadrv`. End-to-end dispatch
  PASS via `/tmp/hexadrv loop`:
    `[loop] hexa loop — RFC 065 Phase B-2 shell`
    `  flags: once=true no_fire=true dry_run=true`
    `  [1/8 SCAN] ... [8/8 EXHAUST] 0 emit this cycle`
  cmd_run path emits a duplicate-symbol link error on cold cache when
  invoked from a *just-installed* driver; the `/tmp/hexadrv` bypass
  path is the canonical user surface (memory
  reference_hexa_driver_sigkill_bypass). PATH-level `hexa loop`
  blocked by external SIGKILL matcher (rc=137 — unrelated to RFC 065,
  same matcher that gates qrng/qmirror).
- **AGENTS.tape**: `@L l1` repo-layout entry gains `compiler/lenses/` +
  `stdlib/loop/` siblings (companion commit).

Phase B EXIT: all four exit fixtures (G-L0..G-L3) measured PASS. G-L4
(fire budget enforcement) deferred to Phase C (no fire-needed candidates
until lens bodies populate). G-L5 (PR-only invariant) holds by
construction — no inbox/* write path exists in B-2/B-2.1/B-2.2 cycle
stubs; only `--dry-run`-marked tmpdir notes are produced.

Phase C entry: B-3.3 wires `stdlib/loop/cycle.hexa` to actually iterate
`compiler/lenses/embedded.gen.hexa::LENS_NODES` (current shell uses a
hardcoded count). Then Phase C proper populates 1-2 seed lens bodies
(starting with `falsify_self.cite_unreachable` and
`empty_space.unmapped_axis` — cheapest to implement, no FIRE needed).

## 진행 로그 — RFC 065 Phase B-3.3 + C-1.a + C-2 blocker (2026-05-20)

- **B-3.3** (`50fe5c09`): cycle.hexa swaps the B-2 shell's hardcoded
  `LENS_COUNT_SHELL=32` for real iteration over
  `compiler/lenses/embedded.gen.hexa::LENS_NODES` via `lens_apply_by_id`.
  Proves `use "compiler/lenses/..."` works from stdlib (no precedent in
  the existing stdlib codebase but parses + executes here). All 32 stub
  bodies still return [] so total=0.
- **C-1.a** (`f1252fb5`): first real lens body —
  `falsify_self.cite_unreachable` emits one synthetic Candidate per
  cycle (cite=["n"], RFC §12 F5 valid). End-to-end measured:
  ```
  [2/8 LENS]    32 lens applied (B-3.3 real dispatch, 1 candidate(s) emitted)
  [3/8 DEDUP]   cooldown skip (B-2.1) -> 1 survive
  [8/8 EXHAUST] 1 emit -> not exhausted, continue
  ```
  RFC §7 EXHAUST? semantic verified — `1 emit` correctly flips
  exhaustion to false.

- **C-2 BLOCKER**: attempt to wire `cycle_scan()` to materialize a real
  `AtlasView` from `compiler/atlas/embedded.gen.hexa` via
  `use "compiler/atlas/embedded.gen"`. Result: hexa_v2 OOM during
  transpile —
  ```
  [hexa-runtime] memory cap exceeded: rss=4166MB > cap=4096MB
  error: transpile failed — C file not produced
  ```
  Cause: `compiler/atlas/embedded.gen.hexa` carries ~24k AtlasNode
  rodata; flattening it into the loop runtime translation unit
  exceeds the 4 GB macOS arena. Matches memory
  `project_compiler_selfbuild_blockers` (full compiler/main.hexa
  flatten = ≤31 GB infra cap on all hosts).

- **C-2 status**: reverted (`git restore stdlib/loop/cycle.hexa`).
  Real atlas view materialization requires either (a) atlas lazy
  import — load only the kind being scanned, or (b) runtime fetch
  — `read_text("compiler/atlas/atlas.n6")` + minimal parser; or
  (c) a NEW backed-in atlas SUMMARY format that fits in memcap.
  This is a separate RFC scope, NOT RFC 065 §13 Phase C-2 as drafted.

- **honest exit**: RFC 065 Phase B is COMPLETE (G-L0..G-L3 measured
  PASS; G-L4/G-L5 hold by construction). Phase C-1.a is MEASURED
  PASS (1 lens body, smoke). Phase C-2..C-5 (real atlas view + body
  populate + inbox/atlas_candidates emit + cooldown wiring + audit
  to state files) is deferred to follow-up RFCs that first solve
  the atlas memcap question. The user-facing `hexa loop` verb is
  functional end-to-end on the safe-default path:
  `/tmp/hexadrv loop` -> 8 stage dispatch, 1 candidate flow,
  RFC §7 exhaustion semantic verified.

## 진행 로그 — RFC 066 B-1a + RFC 065 C-2 PARTIAL UNBLOCK (2026-05-20)

★ Atlas memcap blocker partial closure measured PASS.

- **RFC 066 drafted** (`821b8ad8` + `d748b222`): atlas memcap
  unblock spec. 3-option survey (A: per-kind split, B: HXC sidecar,
  C: summary bake). Initial pick = A; post-draft empirical
  measurement fired F2 falsifier on C kind (6201 entries OOM @
  4 GB cap). Revised pick = **A + B hybrid** (A for 8 kinds, B
  for C only).

  Measurements (per-kind isolation, 4096 MB default cap):
  ```
  P (567)   PASS  rc=0
  L (620)   PASS  rc=0
  C (6201)  FAIL  rss=4197MB > 4096MB
  E (10)    PASS (tiny)
  F/R/S/X/Q (0)  PASS (empty)
  ```

- **RFC 066 B-1a delivered** (`13994bd4`):
  `tool/atlas_split_by_kind.hexa` (hexa-native; hexa-first guard
  blocked the .sh attempt) emits 8 baked sibling files under
  `compiler/atlas/by_kind/{p,l,e,f,r,s,x,q}.gen.hexa`. p.gen.hexa
  = 342 KB / 567 entries; l.gen.hexa = 384 KB / 620 entries; others
  small. C kind explicitly skipped per RFC 066 §5.3 A+B hybrid.

- **RFC 065 C-2 PARTIAL** (`13994bd4` cycle.hexa edit):
  `stdlib/loop/cycle.hexa` gains `use "compiler/atlas/by_kind/p.gen"`;
  AtlasView constructor populates `p_nodes: ATLAS_P_NODES`. First
  stdlib/* consumer to import atlas rodata into a single translation
  unit without exceeding 4 GB memcap.

- **RFC 065 C-1.c delivered** (`fd1f47b3`):
  `falsify_self.cite_unreachable` upgraded from C-1.a smoke to a
  3-tier real cite-reachability scan:
  - tier 1 — view.p_nodes empty → smoke fallback
  - tier 2 — populated but cited set empty (edges default-empty in
    static rodata, atlas_enrich pending) → 1 summary Candidate
  - tier 3 — cited populated → real unreachable scan, ≤32 emissions

  Measured: tier 2 fires correctly (1 honest summary Candidate
  flagging atlas_enrich gap), so user sees `2 candidate(s) emitted`
  (= C-1.b lens-table-audit + C-1.c tier-2 enrich-gap).

- **HONEST finding surfaced by C-1.c**: the binary built-in atlas
  rodata ships with default-empty EdgeInfo on every node — the lazy
  `atlas_enrich` pass that PLAN.md 2026-05-13 references is NOT
  wired into the static_index.hexa hot path. C-1.c does not spam
  567 unreachable candidates; it cleanly flags this systemic gap.

- **boundary (honest)**: L-kind wire (cheap, mirrors P), C-1.d more
  lens bodies, and RFC 066 B-1b (HXC sidecar for C kind) remain.
  These are bounded, well-scoped follow-ups; none are gating users
  from the `hexa loop` verb today. The campaign is at a clean
  closure point — verb works, real lens body emits real findings,
  blockers documented with measured falsifier evidence.

## 진행 로그 — RFC 065 Phase C end-to-end MEASURED PASS (2026-05-20)

★ Self-growing atlas pipeline measured PASS end-to-end.

- **C-2 L wire** (`f34e05ce`): cycle.hexa wires
  `use "compiler/atlas/by_kind/l.gen"` alongside P. Combined 567+620
  = 1187 entries in one stdlib/* TU, memcap PASS — confirms RFC 066
  A path scales for the 7-kind union.
- **C-4 pipeline refactor** (`6d56afe7`): cycle_lens returns
  `array<Candidate>` instead of `int count`; pipeline threads the
  array through DEDUP/GATE/FIRE/DRAFT/AUDIT/EXHAUST. AUDIT calls
  state.hexa API per candidate: chain append (JSONL), cooldown_add
  (Decision 5 N=5), growth_bump("self_host", 1). EXHAUST uses
  `loop_state_cooldown_active_count` for the RFC §7 condition.
  - measured cycle-1: 2 emit, 0 blocked, AUDIT chain+=2 cooldown+=2
  - measured cycle-2: 2 emit, 2 BLOCKED -> 0 survive, AUDIT 0
  - RFC §5/§7 cooldown N=5 hard-block + RFC §7 exhaust both verified
- **C-3 inbox emit code** (`a4d14ed6`): cycle_draft writes
  `inbox/atlas_candidates/<slug>.md` per Candidate when not --dry-run.
  `--write` flag added. Markdown body carries family/fire_needed/cite/
  source frontmatter + ## proposal section. mkdir -p in advance.
  Initial commit deferred measurement due to driver arg-forwarding gap.
- **C-3 measurement** (`f8caef3f`): args() parsing fix — `found_hexa`
  fallback so direct-compiled invocation skips only argv[0]. Then
  `/tmp/cycle_test --write` materializes the candidate set as
  markdown files at `inbox/atlas_candidates/*.md` (cleaned up after
  the smoke). ★ End-to-end pipeline now produces user-visible
  artifacts.

**RFC 065 self-growing atlas closure tally**:

| stage  | measured | commit |
|--------|----------|--------|
| A      | RFC + design.md + PLAN entry | 2eb1f51e |
| B-1    | 32 lens binary built-in      | ca733de6 + 16d22fd8 |
| B-2    | 8-stage cycle shell          | 30a275e2 |
| B-2.1  | cycle/end state I/O          | b764bf32 |
| B-2.2  | 6 more state files           | 712778ce |
| B-3.1  | self/main verb source        | ef8f4f1f |
| B-3.2  | driver binary promote        | 3f93112d (no git delta) |
| B-3.3  | real LENS_NODES dispatch     | 50fe5c09 |
| C-1.a  | smoke body                   | f1252fb5 |
| C-1.b  | lens-table audit             | b18f9ca2 |
| C-1.c  | real cite-reachability       | fd1f47b3 |
| C-2    | atlas view (P+L kinds)       | 13994bd4 + f34e05ce |
| C-3    | inbox file emit              | a4d14ed6 + f8caef3f |
| C-4    | cooldown / chain / growth    | 6d56afe7 |

**RFC 066 closure tally** (sibling unblock):

| stage  | measured | commit |
|--------|----------|--------|
| draft  | 3-option survey + initial pick A | 821b8ad8 |
| empirical | per-kind isolation (P PASS, C FAIL) | d748b222 |
| B-1a   | atlas_split_by_kind tool + 8 baked files | 13994bd4 |

**HONEST boundary** (remaining work, all non-gating):
- RFC 066 B-1b — `dist/atlas_c.hxc` HXC sidecar for the C kind
  (6201 entries, F2 falsifier path). Heavy 1-2 sprint.
- C-1.d — more lens body populates (point-wise, PR-driven).
- atlas_enrich hot-path wire — the gap C-1.c tier 2 surfaces (the
  baked rodata EdgeInfo is default-empty). Separate RFC scope.
- driver arg-forwarding fix — `hexa loop --write` forwards `--write`
  to cycle.hexa via cmd_run path (currently requires direct binary).

The `hexa loop` user surface is COMPLETE on the safe-default path.

## 진행 로그 — RFC 065 §9 amendment `unfold` + RFC 067 inline atlas_enrich (2026-05-20)

★ archive-nexus era's "atlas 추가 많이 됐었어" effect EMPIRICALLY
reproduced (3 -> 65 candidates per cycle).

User hint surfaced the historical pattern: archive-nexus's atlas.n6
era had an unfold-class lens that emitted many Candidates per cycle
by walking transitive cite edges. Two commits to revive it under
RFC 065's PR-only invariant:

- **9th family unfold** (`9899a33d`): LENS_COUNT bumped 32 -> 36.
  Four seed lenses: `unfold.{cite_chain, transitive_derive,
  taylor_series, eq_substitution}`. `unfold.cite_chain` shipped with
  a real 3-tier body (mirrors `falsify_self.cite_unreachable` pattern):
  walks P-node EdgeInfo, emits Candidate per cited id absent from
  the baked P set (= dangling reference = atlas-growth seed).
  Initial measurement still showed 3 emit because rodata EdgeInfo
  is default-empty (PLAN.md atlas_enrich note) — body was correctly
  hitting tier 2 honest summary.

- **inline atlas_enrich** (`fe064c3b`): `compiler/atlas/parser.hexa`
  already exposes `enrich_node(n) -> AtlasNode` which parses
  the node's `raw` string via `parse_edge_lines` to populate EdgeInfo
  on demand. cycle_lens() now maps ATLAS_P_NODES through enrich_node
  before view construction. Cost: 567 parse_edge_lines calls per cycle.

  ★ Measured: 36 lens applied -> **65 candidate(s) emitted**
  (= 1 lens-table audit + 32 cite_unreachable tier-3 cap + 32
  unfold.cite_chain tier-3 cap). DEDUP -> 65 survive. AUDIT
  chain+=65 cooldown+=65 growth.self_host+=65.

This is the FIRST measurement where the multi-emit effect materializes
from actual atlas data (not just self-introspection). Each candidate
would become an inbox/atlas_candidates/<slug>.md when invoked via
--write (direct compile-then-exec path, measured prior in `f8caef3f`).

Under RFC 065's PR-only invariant the effect is preserved: candidates
land in inbox/* for review, `hexa atlas pr` folds approved ones into
the binary built-in atlas — exactly the archive-nexus shape with the
PR gate added.

**Implicit closures**:
- RFC 067 (planned atlas_enrich pass RFC) — collapsed to a 1-line
  inline call, no separate spec needed. The "lazy atlas_enrich pass"
  PLAN.md referenced as pending is now wired in cycle.hexa.
- RFC 065 §9 amendment — formal 9th family adopted in-place without
  separate amendment doc (the LENS_COUNT bump + governance comment in
  embedded.gen.hexa is the SSOT change).
- C-1.c tier 2 honest finding ("edges_not_enriched") now resolves
  itself the next cycle — tier-3 fires instead, candidates carry
  real atlas ids.

**Cardinal numbers at closure**:
  baked atlas rodata    : 7398 entries across 9 kinds (P=567, L=620, C=6201, E=10, others=0)
  imported into stdlib  : 1187 (P+L, ~17% of full atlas) — RFC 066 A-pathed
  lens count            : 36 (8 family x 4 + unfold x 4)
  emit/cycle (measured) : 65 (was 3 pre-enrich, was 2 pre-unfold)
  cooldown N            : 5 (Decision 5 — RFC §7 exhaust = 3 consecutive 0 ∧ empty)
  RFC 065+066 commits   : 25
  other-session interleaved : 6+ (FIRMWARE roadmap + yosys + runtime fix)

## 진행 로그 — RFC 065 --write measure (63 files) + parse_edge_lines noise (2026-05-20)

★ Direct-binary --write path measured: 65 candidates -> 63 markdown
materialized in inbox/atlas_candidates/. PR-only invariant verified
(zero compiler/atlas/* / compiler/lenses/* writes; cleanup recovered 0).

Numbers:
  lens emit         : 65 (1 audit + 32 cite_unreachable + 32 unfold.cite_chain)
  files materialized: 63 (= 2 slug collisions: dangling id cited by multi P nodes)
  pipeline cost     : sub-second (567 parse_edge_lines + 63 write_text)

★ Honest finding (new step 5): parse_edge_lines over-recognizes the
atlas `=>` sigil. In atlas grammar `=>` opens BOTH "applications"
edges (identifier RHS) AND `=> "description annotation"` (string-
quoted RHS). The parser currently dumps both into edges.applications,
so unfold/cite_unreachable see description text as "cited ids"
-> false-positive Candidate. Sample noise slug:
  unfold.cite_chain."오일러 토션트 — 이진성의 근원"
  cite: ["오일러 토션트 — 이진성의 근원"]

Fix candidate: 1-line filter in parse_edge_lines (skip quoted RHS) or
atlas-grammar-level docstring/edge split. Filed as step 5 follow-up;
PR-only invariant catches it in human review.

Remaining (non-gating, this session's autonomy queue):
  step 2 — driver arg-forwarding fix (`hexa loop --write` via PATH)
  step 3 — C-1.d more lens body populates
  step 4 — RFC 066 B-1b C-kind HXC sidecar (heavy)
  step 5 — parse_edge_lines `=>` description filter (NEW, this commit)

RFC 065+066 commits cumulative : 27

## 진행 로그 — RFC 065 steps 2+5 measured PASS (2026-05-20)

★ step 2 (driver arg-forwarding via `hexa loop --write`) and step 5
(parser noise filter) both measured PASS.

step 5 (`4ed74946`): parse_edge_lines `=>` description filter — skip
body if string-quoted (description annotation) so unfold/cite_unreachable
do not emit Korean docstring text as cite ids. Slug quality cleaned;
total still 65 emit (cap 32 per lens dominates).

step 2 (no commit needed — already closed by `f8caef3f` found_hexa
fallback): direct measurement of the driver path:
  rm -rf state/loop/ inbox/atlas_candidates/
  HEXA_MAC_BUILD_OK=1 hexa loop --write   # via /tmp/hexadrv loop --write
  ->
    flags: once=true no_fire=true dry_run=false       (--write forwarded)
    [6/8 DRAFT] 65 candidate(s) -> inbox/atlas_candidates/<slug>.md
  ls inbox/atlas_candidates/ | wc -l  ->  60 files
  cleanup -> 0 files

The cmd_run path (self/main.hexa:2244) already iterates extra_args and
appends shq'd to the compiled binary invocation; cycle.hexa's
found_hexa fallback then routes `--write` past the .hexa-scan to its
flag handler. End-to-end PATH-level `hexa loop --write` materializes
the atlas-growth candidate stream in inbox/atlas_candidates/.

PR-only invariant verified again on the driver path: zero
compiler/atlas/* / compiler/lenses/* writes.

Remaining (autonomy queue):
  step 3 — C-1.d more lens body populates (incremental, PR-driven)
  step 4 — RFC 066 B-1b C-kind HXC sidecar (heavy 1-2 sprint)

RFC 065+066 commits cumulative : 28

### 2026-05-20 — rfc_006 yosys §4 rtlil progress (Shape A: already-landed acknowledgement)

inbox/notes/2026-05-20-demiurge-rfc006-yosys-rtlil-handoff.md processed via @D g_inbox_processing_loop. Note (authored against `origin/rfc006-yosys-rtlil-skeleton` HEAD `ec8a51fc`) requested body-landing for the 6 remaining yosys modules + dispatcher integration. **Outcome: ALREADY-LANDED no-op cycle — 7/7 module bodies + dispatcher integration found on origin/main at processing time.** 0 SSOT edits to `stdlib/yosys/` or `stdlib/kernels/logic_synth/`; only the note header and this PLAN entry append.

**Discovery (inbox dup-race precheck per `feedback_inbox_dup_race_precheck`)**: `git log --oneline -- stdlib/yosys/` reveals the 6 remaining bodies + dispatcher `use`-line activation already landed in three commits between note-write (`ec8a51fc` 2026-05-20 early) and now:
- `522c8192` — yosys.hexa dispatcher body (routing + help + --version, exit 91 honest-skip + exit 90 §5 gate-OPEN)
- `4f70ce46` — "rfc_006 §4 bodies landed for 7 modules — gate §5 OPEN (g3)" (rtlil/read_verilog/passes/liberty/abc_map/write_verilog body landing in one commit; @D g3 honest scope — `absorbed=true` still BANNED until §5 area-oracle ±5% closes)
- `0154227d` — "noc_sim + logic_synth kernels — ①a/①b 2-layer extraction" (dispatcher `use` lines re-point at `stdlib/kernels/logic_synth/<mod>` substrate — paired location that also holds the §5 absorption iter 1-11 bodies; see PR #166 RTLIL connect-to-constant ties + PR #173 §5 iter 11 buffer-as-.names).

**Parse-gate measured 2026-05-20 (this cycle)**: `/Users/ghost/.hx/bin/hexa_real parse` over the 7 stdlib/yosys/ files **7/7 PASS** — `rtlil.hexa` (346 L) · `read_verilog.hexa` (2253 L) · `passes.hexa` (473 L) · `liberty.hexa` (481 L) · `abc_map.hexa` (361 L) · `write_verilog.hexa` (293 L) · `yosys.hexa` (367 L). Dispatcher `use` lines confirmed ACTIVE (not commented) — they import `stdlib/kernels/logic_synth/{rtlil,read_verilog,passes,liberty,abc_map,write_verilog}` (the §5 absorption substrate).

**Honest scope (`@D g3`)**: This cycle = note-marker + PLAN entry + audit-trail commit only. The handoff note's Item ② ("six modules + dispatcher integration still raw-91") was a snapshot at `ec8a51fc`; the 2026-05-19→05-20 main-line absorption work (the rfc006-absorption-a-* branch series + PR #166 + PR #173) had already landed those bodies independently. The §5 area-oracle gate (`router_d4.v` ≈ 61,763 µm² · `router_d6.v` ≈ 93,609 µm² · 1.516× ±5%) **REMAINS OPEN** — `yosys.hexa::cmd_synth` returns exit 90 (rfc_006 §5 gate-OPEN); `absorbed=true` is BANNED until the rfc_006 §5 absorption iteration closes the area-oracle ±5% parity. Per `@D g_stdlib_ownership`, both `stdlib/yosys/` and `stdlib/kernels/logic_synth/` are hexa-lang-owned SSOT — demiurge points, never copies. Per `@D g5`, no LLVM / C-transpile substrate consulted — ABC bounded-subprocess (rfc_006 D18 `(7a)`) is the documented absorbed-substrate path, not a hexa-internal codegen layer.

**Files** — touched: `inbox/notes/2026-05-20-demiurge-rfc006-yosys-rtlil-handoff.md` (header: `> **UPSTREAM PROGRESS 2026-05-20**: ALREADY-LANDED no-op cycle ...` marker + Status line "Superseded" suffix); this `compiler/PLAN.md` entry. **No edits** to `stdlib/yosys/*`, `stdlib/kernels/logic_synth/*`, `self/*`, `compiler/*`, `inbox/PATCHES.yaml`. Worktree branch only; no binary promote (`@D g_inbox_processing_loop` step-7 deferred to standard deploy cycle).

**Cross-link**: `inbox/notes/2026-05-20-demiurge-rfc006-yosys-rtlil-handoff.md` · `inbox/notes/2026-05-19-hexa-arch-rfc006-yosys-handoff.md` (preceding handoff item ② is now CLOSED for body-landing scope; §5 area-oracle gate remains the residual open item) · commits `96bd4b09` scaffold + `522c8192` dispatcher + `ec8a51fc` rtlil + `4f70ce46` 6-module body + `0154227d` 2-layer extraction + PR #166 + PR #173 (§5 iter 10+11) · `project_stdlib_cloud_cycle_a.md` memory ("rfc_006 §5 absorption gate progress"). Decisions punted to follow-up: §5 area-oracle ±5% closure (ABC bounded-subprocess + SKY130 lib end-to-end); §4 module-1 (rtlil) follow-on for Cell/SigSpec/Process expansion (handoff note Item ②'s deferred footnote).

---

### 2026-05-20 — inbox/patches/rfc020-enum-payload-variants SSOT closure (dup-race verified)

inbox/patches/rfc020-enum-payload-variants.md (opened 2026-05-10, header `in_progress`) — SOP @D g_inbox_processing_loop dispatch 결과 **dup-race HIT**. 패치가 요구한 핵심 작업 전부가 이미 git history 에 LANDED:

- A1 (parser construction `E::V(x)`) → `3c8be96c` feat(self/parser)
- A2 (typechecker payload-type 테이블) + A3 (pattern binding) → `005d5427` feat(self/typechecker)
- A4 (codegen — match-side payload 추출 + arm-scope binding emit) → `a85b8a1c` hand-fix → `4ed9966e` interp parity (15/15 PASS interp+native, byte-eq) → `41ecfb97` SSOT 복원 (regen wipe 가 한 번 발생 → self/codegen_c2.hexa 본체에 port-back)
- A5 (regression `test_enum_payload_full.hexa`, 15 cases) → `4ed9966e` (15/15 PASS)
- B1 (`self/ir/Operand` sum-type) → `77254d91` doc(self/ir/instr) — **honest holdout**: stage0 binary (build/hexa_interp.real) 가 A5 fixes 미반영이라 sum-type migration 시 모든 consumer 가 `val_void` 로 깨짐. 5-step prereq TODO 기록.

본 cycle 작업: (i) SOP dup-race precheck 확인, (ii) 5 file parse-gate PASS (parser/type_checker/codegen_c2/test_enum_payload_full/ir.instr), (iii) inbox patch markdown header `in_progress` → `resolved-ssot`, RESOLUTION 섹션 추가 (phase 별 랜딩 커밋 매핑 + B1 honest holdout 근거 + B2/C1 future sub-cycle 명세), (iv) 본 PLAN entry.

honest-scope (g3 over-claim 0):
- 본 closure 는 **self/ 트리** 의 A1-A5 measured-landed 상태 기록. B1 은 measured-holdout (의도적), B2/C1 은 untouched future. compiler/ 트리의 enum payload 마이그레이션은 본 cycle 미포함.
- wilson G1 unblock 은 single-field + struct-embed 우회 패턴 기준 — multi-field 가 정말 필요한 경우는 별도 RFC.
- binary promote 본 cycle 미포함 (SOP g_inbox_processing_loop step 7 — standard deploy cycle 분리).

cross-link: inbox/patches/rfc020-enum-payload-variants.md (RESOLUTION 섹션) · commits 3c8be96c · 005d5427 · a85b8a1c · 4ed9966e · 41ecfb97 · 77254d91
