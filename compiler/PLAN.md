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

- aprime_cc-direct path: 60-broad sweep **34/60 (57%)** byte-identical (재측정 2026-05-17, atlas SIGSEGV + CGFAIL fix 반영)
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
