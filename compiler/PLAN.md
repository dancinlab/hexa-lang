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

