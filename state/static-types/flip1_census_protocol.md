# FLIP-1 census 프로토콜 + GO/NO-GO 판정 기준 (설계)

먼저 설계를 접지시킨 실측 사실(이 세션에서 코드로 확인)과, 그 위에 세운 프로토콜을 순서대로 준다.

## 0. 실측 전제 — 코드에서 확인한 것 / 불확실한 것

**확인됨** (`feat/static-types-f0f4-flip-prep` @ 7f77f1b99 기준):

- 게이트는 단일 hoist로 이미 통합돼 있다: `_types_static_on`(types.hexa:1217), `_types_static_flags_hoist()`(:1230–1241)에서 1회 세팅, `_types_array_lower_on = _types_static_on || env(ARRAY_LOWER)` 폴드(F0) 포함. **FLIP-1 패치는 :1231 한 줄의 default 극성 변경으로 국한 가능**하다.
- warn-band 배선: `_emit_hx3011`/`_emit_hx3014`(코드 HX3016 발행)는 `_types_strict`일 때만 Error, 아니면 `diag_emit_sev(b, Severity::Warning)`. HX3017은 무조건 Warning. STRICT 승격은 f5-prep 브랜치(69f8e50ef)에 별도 존재.
- **Warning이 빌드를 못 죽이는 확증점**: `main.hexa:202–208` `_is_error_severity`가 Warning→false, `:225` `_has_errors`, `:724` pre-codegen abort 게이트. Warning은 `_render_all`(:217)로 **stderr 렌더만** 된다.
- 선행 이력: F1 census 워크플로(`static-types-corpus.yml`)가 이미 main에 있다(#4508). 1차 실런은 corpus verdict 없이 **하네스 버그로 크래시**(clean 파일에서 grep rc=1 × `set -e`+`pipefail` — `state/static-types/f1_first_run.md`), 수정 커밋 87bd65358 랜딩. 단 현 워크플로 corpus는 `-maxdepth 1` **69파일 대표본**뿐이다.
- corpus 실측 규모: compiler 389 · stdlib 2,249 · self 1,167 = **3,805 .hexa**.
- 스펙 SSOT: `state/static-types/wall_a_endgame.md` §B.3 F0–F5 — 이 설계는 그 F1/F2/F3/F5를 FLIP-1용으로 구체화한 것이다.

**불확실 — requester가 census 전 확인할 3건** (프리플라이트에 포함):
1. F4 warn-band + r11(HX3017)이 census 시점의 origin/main에 실제 머지됐는지 (이 워크트리 `fix/install-bare-cuda-pip`에는 없다). 확인법: `grep -c _types_static_flags_hoist compiler/check/types.hexa && grep -c HX3017 compiler/check/types.hexa` 둘 다 >0.
2. 87bd65358 수정 후 census job이 재run되어 실데이터를 이미 뽑았는지 (있으면 LANE B의 선행 데이터로 흡수).
3. r9b element-literal coercion arm이 census ref에 있는지 — flip-prep의 `_types_assignable`(:2111~)에 ArrayLit per-element 코멘트가 보이므로 있는 걸로 추정하나, canary로 실증하라(아래 §5).

핵심 설계 판단 하나를 먼저: **census는 flip 패치 없이 현 warn-band HEAD에서 `HEXA_STATIC_TYPES=1`로 돌리면 flip-후 default-ON과 발화가 정의상 동일하다** (flip = 게이트 default만 변경이므로). 그래서 census(LANE A–D)를 flip 패치와 분리하고, flip 패치가 나오면 등가성만 별도 differential(LANE E)로 증명한다. census가 flip 구현을 기다릴 필요가 없다.

## 1. Census 측정 프로토콜 (pool 실행형)

실행 형태: summer 또는 aiden에 **직접 ssh + nohup** (sidecar pool on은 120s 타임아웃 — 메모리 룰), 스크립트와 로그는 `state/static-types/f2_census/` 아래 박제. mini는 git/gh만.

### 프리플라이트 (1회)
- 위 불확실 3건 presence-probe.
- STRICT 잔류 env 스캔: `grep -rn HEXA_STATIC_TYPES_STRICT .github/ tool/` + pool 호스트 셸 프로파일. **default-ON이 되는 순간 STRICT=1 잔류만으로 fatal이 되므로**, 발견 시 제거가 선행.
- 빌드: 두 프론트엔드 다 준비 — `tool/build_aprime.sh`로 aprime_cc + release_build 경로의 gen2 C-transpile. **aprime만 돌리면 FALSE-green** (메모리 룰: verify BOTH backends).

### LANE A — 실빌드-표면 census (primary 신호)
per-file이 아니라 **whole-program closure**가 진짜 유저-facing 표면이다. 엔트리: (1) stage-1 self-compile(`compiler/main.hexa` closure — compiler/** 전체 + 딸려오는 stdlib를 실제 import 그래프대로 typecheck), (2) stdlib selftest/@ci_gate cohort 엔트리, (3) self/ 시드 빌드, (4) shipping smoke/examples.

```bash
export HEXA_STATIC_TYPES=1   # flip-후 default-ON과 발화 동일 (게이트 정의상)
for entry in "${ENTRIES[@]}"; do
  timeout 900 ./build/aprime_cc _drv.hexa --emit=asm --error-format=short \
      -o /tmp/scratch.s "$entry" > "logs/aprime/$(basename $entry).log" 2>&1 || true
  # gen2 프론트엔드로 같은 엔트리 반복 → logs/gen2/
done
grep -hoE '^[^ ]*HX301[167][^ ]*' logs/aprime/*.log   # 실제 short 포맷 확인 후 조정
```

**집계 3종**: ① raw emission count(코드별 HX3011/3016/3017 분포) ② **unique site** = `file:line:col:code`를 `sort -u`한 것 — closure 간 중복 typecheck로 raw는 뻥튀기되므로 **판정은 unique site 기준** ③ per-file top-N. 판정 기준(§2)은 전부 unique site에 건다.

### LANE B — per-file 전수 sweep (coverage 보조, advisory)
기존 워크플로 방식을 3,805파일 전체로 확장: `git ls-files 'compiler/**/*.hexa' 'stdlib/**/*.hexa' 'self/**/*.hexa'` → `xargs -P $(nproc)` per-file front-end, 60s/file 타임아웃, 파일별 카운트. 주의 두 개:
- **undercount 방향 편향**: standalone-불가 파일은 resolve에서 죽어 type_check에 못 간다(false-clean). 또 import 미해석 시 r5 registry가 모르는 struct는 계약상 침묵 → 역시 undercount. **FP를 만들진 않는다.** 그래서 LANE B는 GO를 막는 lane이 아니라 LANE A가 못 덮는 dead/test 파일 커버리지용.
- 기존 워크플로의 grep-pipefail 함정(87bd65358)을 스크립트에 그대로 반영(`|| true` 가드 + summary-블록-후-exit).

### LANE C — emit-neutrality probe (byteeq-neutral 직접 실증)
표본 K(≥20)파일을 `HEXA_STATIC_TYPES=1` vs unset으로 각각 `--emit=obj` 컴파일, `cmp`로 바이트 비교. **동일 cwd에서**(DWARF 경로 아티팩트 함정 — 메모리). 핵심: **표본에 dirty 파일(warn이 실제 발화하는 파일)을 반드시 포함** — 발화 없는 파일의 byte-eq는 증명이 아니다. diff 1건 = 즉시 FLIP-blocking(warn 경로가 emit을 건드린다는 뜻).

### LANE D — dual-frontend diag parity
LANE A/B 로그에서 normalized site-set을 추출해 gen2 vs aprime **set-diff = ∅** 요구. 렌더 포맷 차이는 무시하고 `(file, line, col, code)` 튜플만 비교. 두-백엔드 path-mismatch는 알려진 실패양식이다.

### LANE E — flip-equivalence differential (flip 패치 후, flip PR 안에서)
1. flipped 빌드(env unset) vs unflipped(env=1): 동일 표본 diag 스트림 byte-diff = 0 — flip 패치가 "게이트 default 변경 그 이상 아무것도 아님"의 증명.
2. flipped + `HEXA_STATIC_TYPES=0` vs unflipped(unset): 둘 다 완전 침묵, diff = 0 — opt-OUT 완전성.
3. flipped + `=1`: 기존 스크립트 무변경 동작.

flip 게이트 semantics 권고: `_types_static_on = (env("HEXA_STATIC_TYPES") != "0")` — unset→ON, "1"→ON(기존 CI/스크립트 호환), "0"→OFF, 기타값→ON. STRICT는 `=="1"` opt-in 유지.

### TP/FP 판별법
판별 기준을 사람 감이 아니라 **checker의 문서화된 계약**에 건다:

- **FP** = conservative-skip/unknown-tolerance 계약 위반 발화: unknown 타입에 발화 · literal-coercion 갭(`let xs:[f32]=[0.0]` 류) · registry가 모르는 struct에 HX3016/17 · HexaVal wildcard 위반. → checker 결함, FLIP-blocking.
- **TP** = expected/actual 둘 다 known이고 소스를 열어 수동 도출해도 진짜 불일치. → corpus 버그, 고칠 가치 증명.
- **제3클래스** = checker는 계약대로 맞게 쐈지만 코드가 의도된 dynamic/HexaVal 관용구. FP도 TP도 아닌 정책 판단 대상 — 아래 §2에 별도 임계.

절차: unique site마다 ① 소스에서 declared T vs RHS 타입 수동 도출 ② 계약 위반 여부로 3분류 ③ **~10줄 standalone .hexa로 미니마이즈해 두 프론트엔드에서 재발화 확인**(진단 재현성 + 양파서 교차검증을 공짜로 얻는다). 규모 대응: unique ≤ 40이면 전수 분류; > 40이면 code×디렉토리 층화 표본 25+로 FP율 추정하되 — **표본에서 FP 1건이라도 확인되면 추정이고 뭐고 NO-GO**.

## 2. GO/NO-GO 판정 기준 (정량)

| # | 게이트 | 측정 | 기준 |
|---|---|---|---|
| G1 | corpus warn | LANE A unique site 수 | 0 → GO 자격. >0 → G2/G3으로 |
| G2 | **FP = 0 (절대)** | 분류 결과 | FP ≥ 1 → **NO-GO**, 개수 불문 |
| G3 | TP 처리 | 분류 결과 | TP ≥ 1 → **fix-first 후 re-census = 0**에서 GO |
| G4 | 제3클래스 | 분류 결과 | unique ≤ 20 → 건별 정책(스킵 확장 or 코드 수정). **> 20 → NO-GO** — 관용구가 만연하다는 건 스킵 경계 오설계 신호, checker 쪽을 고친다 |
| G5 | emit-neutrality | LANE C, dirty 파일 포함 | byte-diff = 0 |
| G6 | frontend parity | LANE D site-set diff | ∅ |
| G7 | perf | stage-1 self-compile wall, flipped(default-ON) vs opt-OUT(=0), **median-of-5, isolated(백투백 금지), summer 고정** | Δ ≤ 2% (스펙 F3 budget; F3 env-hoist는 이미 랜딩됐지만 default-ON은 check 본체가 매 컴파일 실행되므로 재실측 필수) |
| G8 | flip PR 게이트 | byteeq gen3≡gen4 + 3-target + faithful + install smoke | 전부 GREEN, x86-only green 금지, revert-on-RED |

FP가 왜 개수 불문 blocking인가: warn-only라 빌드는 안 죽지만, default-ON 오탐은 **모든 다운스트림 컴파일 stderr를 오염**시키고(로그-diff 민감 하네스 false-fail 위험), FLIP-2(fatal)를 영구 차단하며, 진단 신뢰를 침식한다. FP 발견 시 다음 행동 = 그 오탐 **클래스**를 conservative-skip 경계 재작도 rung으로 수정 → re-census. 개별 사이트 무마 금지.

LANE B(per-file sweep)의 warn은 GO를 막지 않는다(dead/test 파일 포함이므로) — 단 **LANE B에서라도 FP로 분류되는 발화가 나오면 동일하게 NO-GO**다. checker 결함은 어디서 발견되든 결함이다.

## 3. 마이그레이션 순서

**fix-first, flip 동시 금지.** warn>0 & 전부 TP인 경우:

1. TP fix PR들 — 영역별 소분할 2LANE PR, 각 PR에 해당 사이트의 census before/after delta 캡처 박제(이것이 flip의 가치 증명 = captured numbers of real bugs caught). 주의: 컴파일러/런타임 소스의 타입버그 수정은 **자기 자신의 emit을 바꿀 수 있다** — 각 fix PR이 정상 CI(byteeq 포함)를 개별 통과하는 것으로 흡수되고, 그래서 flip과 분리해야 한다.
2. re-census → LANE A unique = 0 확인.
3. flip PR — 내용물 최소화: 게이트 default 극성 1줄 + catalog/`hexa --help` lockstep + census 워크플로 갱신(env export 제거, 또는 default-ON lane + `=0` 대조 lane 2줄 구성) + LANE E differential 캡처 첨부. **G8 게이트에 hold, 머지 후 pool hosts sync.**

flip과 동시에 고치지 않는 근거 3개: (a) day-0 default-ON 경험이 침묵이어야 stderr 로그-diff 민감 게이트가 안전, (b) FLIP-2 soak의 zero-baseline이 필요, (c) revert-on-RED 시 corpus fix까지 같이 굴러떨어지면 안 된다.

**byteeq 게이트 타이밍은 2회**: census 단계의 LANE C(표본 실증, 싸고 빠른 조기 킬) + flip PR의 정식 3-target byteeq/faithful(G8).

## 4. FLIP-1 → FLIP-2 (STRICT default-ON = fatal) 게이트

- **soak 정의는 측정형으로** (calendar-only 금지): FLIP-1 머지 후 main census(이젠 env 불요) **연속 0 유지** AND `.hexa`-touching 머지 PR **≥ 30개** AND **≥ 14일**, 신규 warn 유입 0. 두 조건 AND — PR이 안 흐른 2주는 soak가 아니다.
- soak 개시와 함께 census 워크플로를 advisory → **required-with-0-threshold 승격** (warn=0 상시 강제 = 사실상 pre-STRICT 상태를 만든 뒤 severity만 뒤집는 구도).
- STRICT=1 full-corpus 프리플라이트: 두 프론트엔드 에러 0 실측 (warn 0이면 자명하지만, 자명함을 실측으로 확인하는 것이 이 리포 규율).
- **escape 설계 선행**: opt-out env(`HEXA_STATIC_TYPES=0`) 유지 + 서드파티/생성 코드용 per-site waiver(`@grace` 스타일 — HX8004 선례). REJECT flip은 env 토글만으론 부족하다는 게 스펙 B.1의 결론.
- FLIP-2 PR은 별도 PR(F5: Warning→Error escalation follow-on 분리), G8 동일 게이트.

## 5. 리스크 census

- **byteeq-neutral 확증 3점**: ① types.hexa emission 헬퍼들은 diags 배열 push 외 무변형 — `type_check(module)`(main.hexa:689)의 산출은 diags뿐이고 HIR 타입은 `lower/ast_to_hir` 자체 경로로 붙는다(메모리: ast_to_hir:144 폴백). flip PR 리뷰 시 warn 발화 경로에 AST/module 쓰기가 없는지 grep으로 재확증. ② main.hexa:202–208/:225/:724 — Warning 비집계 abort 게이트. ③ LANE C 실증 + G8. **추가 주의 하나**: FLIP으로 `_types_array_lower_on`도 default-true가 된다 — 이 구조적 Type lowering의 소비자가 check/ 밖에 없는지 flip PR에서 확인 필요(현재는 types.hexa 내부로 보이나 미확증).
- **conservative-skip FP 의심 클래스 canary** — census 본런 전에 클래스당 1개씩 표적 .hexa로 선행 프로브(발화하면 3,805파일 돌리기 전에 FP 확정, 싸게 죽인다): element-literal coercion(`let xs:[f32]=[0.0]`, `fn f()->[f32]{return [0.0]}`) · nested field read(`s.inner.x` 침묵 유지) · int-literal 기본폭(i64 리터럴→i32 슬롯) · Map/generic string-sentinel 퇴화 · HexaVal wildcard 수용 · closure C1 bare-fn.
- **양파서/두 백엔드**: gen2 vs aprime 진단 스트림 불일치는 알려진 실패양식 — LANE D가 유일한 방어. aprime-only 측정은 FALSE-green.
- **stderr 오염**: warn>0 상태로 flip하면 모든 컴파일 로그에 노이즈 — fix-first가 방어. flip 전에 컴파일러 stderr를 diff/카운트하는 게이트가 있는지 1회 스캔 권고(`grep -rl "2>" .github/workflows/ tool/` 류).
- **STRICT 잔류 env**: 프리플라이트에 포함(위).
- **per-file sweep의 false-clean 편향**: LANE A primary가 방어 — per-file 수치만으로 "clean" 선언 금지.

불확실 요약(정직 표기): corpus warn 실측치는 미지(그걸 뽑는 게 이 프로토콜) · F4 main-머지 여부와 r9b 존재는 presence-probe 대상 · aprime의 short 포맷 정확한 라인 레이아웃은 첫 dirty 로그에서 확인 후 파서 확정 · G7 perf는 F3 hoist가 이미 흡수했을 가능성이 높지만 default-ON은 check 본체 실행이라 재실측 없이 "이미 냈다"고 가정하지 말 것.
---

## 실측 census 결과 (CI에서 이미 계산됨 · 2026-07-04)

`static-types-corpus.yml` F1 census, run 28715550983 (H0 브랜치 #4559 head · origin/main warn-band 등가):
```
════ static-types corpus census ════
files checked : 69
dirty files   : 0
HX3011/HX3016 : 0
notice: CLEAN — 0 HX3011/HX3016 over 69 files with HEXA_STATIC_TYPES=1 (+ARRAY_LOWER)
```
**판정**: 69파일 대표본(compiler/check/*.hexa + stdlib top-level) = **CLEAN** → FLIP-1 부분 GO 신호.

**갭(전체 GO 전 필요)**:
1. 표본이 -maxdepth1 69파일뿐 → Fable LANE B(전체 3805파일 xargs -P) 확장 필요. workflow 확장이 naive면 러너 타임아웃(69파일 6m43s×55) → per-file 60s 타임아웃+병렬 필수.
2. 집계가 HX3011/3016만 → **HX3017 미포함**. Fable 프로토콜은 3011/3016/3017 전부. 워크플로 census 스크립트에 HX3017 grep 추가 필요.
3. LANE A(whole-program closure 실빌드-표면)·LANE C(emit-neutrality cmp)·LANE D(dual-frontend parity) = pool 실행분(summer/aiden ssh+nohup).

**다음 액션**: 워크플로 census 스크립트를 (전체 corpus + HX3017 집계)로 확장 = mini-doable byteeq-neutral CI-only PR. 그 후 pool LANE A/C/D. GO시 flip 패치=types.hexa:1231 default 극성 1줄.
