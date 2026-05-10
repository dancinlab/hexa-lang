# runnable surface recipe — hexa-* 프로젝트 공통

> hexa-cern 에서 13 iteration 동안 검증된 패턴. 다른 hexa-* 프로젝트
> (`hexa-bio`, `hexa-rtsc`, `hexa-fusion`, `hexa-antimatter`,
> `hexa-ufo`, `hexa-chip`, `hexa-codex` …) 에 그대로 적용 가능.

본 문서가 정의하는 작업의 정식 명칭:

**Runnable Surface Construction** (RSC) — 또는 **봉쇄 심화 (closure-depth accumulation)**

설명:
- 새 verify/build/tests 코드를 하나씩 추가하며,
- 사전 등록된 falsifier 의 closure 를 T1 (algebraic) → T2 (numerical) →
  T3 (empirical) 사다리로 깊게 만든다.
- T3 (실험 하드웨어) 는 미루고, T2 를 **수평으로** 누적해 닫힌-form 의
  교차 검증 깊이를 쌓는다.

---

## §0 전제 조건 (대상 프로젝트가 갖춰야 하는 것)

대상 프로젝트가 **이미 가지고 있어야** 본 레시피가 즉시 적용 가능:

1. `hexa.toml` ([package].entry, [test], [closure] 섹션 포함)
2. `.roadmap.<project>` (§A.1 invariant lattice + §A.4 falsifier preregister)
3. `cli/<project>.hexa` 플레이스홀더 dispatcher (3+ pillar verb)
4. `<pillar>/doc/*.md` spec 문서 (n=6 lattice 명시)
5. `tests/test_selftest.hexa` 정도 한 개

이 5개가 안 갖춰져 있으면 먼저 그것부터 만들어야 한다.
hexa-sscb 와 hexa-cern 은 둘 다 갖춰져 있고, 본 레시피는 이런
"specs-only v1.0.0" 상태에서 시작한다고 가정한다.

---

## §1 산출물 — verify/ 디렉토리 16-script 표준 인벤토리

각 hexa-* 프로젝트는 본 16-script 골격을 자신의 도메인에 맞게 채운다.

### Algebraic tier (T1) — 4 scripts

| # | 파일                          | 역할 |
|:--|:-----------------------------|:-----|
| 1 | `lattice_check.hexa`         | n=6 closure (σ·φ = n·τ = J₂ = 24) across roadmap + 모든 pillar |
| 2 | `cross_doc_audit.hexa`       | pillar 간 anchor (baseline collider/실험명, OEIS, BT-link) 일치 |
| 3 | `calc_<pillar1>.hexa`        | pillar 1 의 n=6 derivation (정수 산술) |
| 4 | `calc_<pillar2>.hexa`        | pillar 2 의 n=6 derivation |
|   | …                            | pillar 갯수만큼 calc_*.hexa |

### Numerical tier (T2) — 9 scripts (대표)

| # | 파일                                  | 역할 |
|:--|:-------------------------------------|:-----|
| 5 | `numerics_<pillar1>.hexa`            | pillar 1 closed-form 을 math_pure 로 재유도 |
| 6 | `numerics_<pillar1>_parity.hexa`     | pillar 1 vs published 실험 비교 (e.g., 콜라이더 4종, LWFA 4종) |
| 7 | `numerics_<pillar1>_solver.hexa`     | pillar 1 의 미니 ODE solver (Verlet/leapfrog) |
| 8 | `numerics_<pillar2>.hexa`            | pillar 2 numerics |
| 9 | `numerics_<pillar2>_parity.hexa`     | pillar 2 published-ref parity |
|10 | `numerics_<pillar3>.hexa`            | pillar 3 numerics (e.g., symplectic) |
|11 | `numerics_<pillar3>_<X>.hexa`        | pillar 3 second T2 (e.g., Liouville volume) |
|12 | `numerics_cross_pillar.hexa`         | pillar 간 numerical anchor 일치 |
|13 | `numerics_lattice_arithmetic.hexa`   | n=6 lattice 의 float ↔ int 정밀도 cross-check |

### Meta tier — 2 scripts

| #  | 파일                          | 역할 |
|:---|:-----------------------------|:-----|
| 14 | `falsifier_check.hexa`       | F-<PROJECT>-1/2/3 closure-progress tracker (3-tier ladder, %) |
| 15 | `lint_numerics.hexa`         | 모든 `numerics_*.hexa` 가 5 invariant 따르는지 grep-lint |

### Build + Tests

| 위치                                  | 역할 |
|:-------------------------------------|:-----|
| `build/Makefile` + `build/header.tex` | pandoc + xelatex 로 모든 pillar PDF rebuild |
| `tests/test_lattice.hexa`             | verify/lattice_check 회귀 |
| `tests/test_calculators.hexa`         | 모든 numerics_* + calc_* 회귀 |
| `tests/test_cli_verify.hexa`          | `<project> verify all` aggregate 회귀 |
| `tests/test_all.hexa`                 | 위 4개 + selftest aggregator |

### CLI 확장

`cli/<project>.hexa` 에 `verify [<sub>]` 서브커맨드 추가:

```
<project> verify all       # 모든 verify/* 일괄 실행, exit 코드 합산
<project> verify lattice
<project> verify cross-doc
<project> verify <pillar1>
<project> verify numerics-<pillar1>
<project> verify numerics-<pillar1>-parity
<project> verify numerics-<pillar1>-solver
<project> verify <pillar2>
…
<project> verify falsifier
<project> verify lint-numerics
```

---

## §2 한 iteration 의 7-step 사이클

각 commit/push 사이클은 다음 7단계:

1. **Chunk 선택** — 위 인벤토리에서 아직 미작성된 슬롯 1개, 또는 기존
   파일 중 보강 가치 있는 1곳. (한 commit = 한 chunk = 한 PR 단위.)
2. **Write** — `.hexa` 파일 작성 (math_pure import + RUN/FAIL counters
   + FALSIFIERS list + `__HEXA_<PROJECT>_<NAME>__ PASS` sentinel +
   `exit(0)`). lint_numerics 가 enforced.
3. **Run** — `hexa run verify/<new>.hexa` 로 단독 실행, n/n PASS 확인.
4. **Wire** — `cli/<project>.hexa` `VERIFY_SUBS` + dispatcher + help 갱신.
   `tests/test_calculators.hexa` 에 (filename, sentinel) 한 줄 추가.
   `tests/test_cli_verify.hexa` 의 expected aggregate count bump.
   필요시 `verify/falsifier_check.hexa` `Fk_T2_SCRIPTS` 배열 + `verify/lint_numerics.hexa` `NUMERICS_SCRIPTS` 배열 갱신.
5. **Regression** — `<project> verify all` (모두 N+1/N+1 PASS),
   `hexa run tests/test_all.hexa` (4/4 PASS) 둘 다 실행.
6. **Doc** — `CHANGELOG.md` 에 `### Added (날짜 — Nth iteration)` 블록.
   필요시 `README.md` verify 표 + 인벤토리 트리 갱신.
7. **Commit + push** — 단일 commit, descriptive message, origin/main push.

이 7 step 을 한 chunk 당 반복.

---

## §3 closure pct 계산 (falsifier_check 의 sentinel)

각 falsifier 는 3-tier ladder 로 closure 를 추적:

```
closure_pct(t1_ok, t2_ok, t3_ok):
  n = sum(t1_ok, t2_ok, t3_ok)
  if n == 0: return 0
  if n == 1: return 33
  if n == 2: return 67
  if n == 3: return 100
```

- T1: `verify/calc_*.hexa` (algebraic) 가 disk 에 존재
- T2: `verify/numerics_*.hexa` (numerical) 모든 항목이 disk 에 존재
- T3: 실험 하드웨어 / 라이브 데이터 피드 — 항상 ✗ (Stage-1+ 후 닫힘)

T2 는 **배열** 로 저장 — 한 falsifier 가 여러 numerics 스크립트로 검증 가능.
hexa-cern 의 F-PCERN-3 는 numerics_wakefield + numerics_lwfa_parity + numerics_lwfa_solver = 3 T2 stack.

---

## §4 5 invariants enforced by lint_numerics.hexa

모든 `verify/numerics_*.hexa` 가 만족해야:

1. `use "self/runtime/math_pure"` import (raw float math 사용 금지)
2. `__HEXA_<PROJECT>_<NAME>__` sentinel prefix + `__ PASS` suffix
3. `FALSIFIERS` 배열 선언
4. `exit(0)` on PASS path
5. `let mut RUN = 0` + `let mut FAIL = 0` 카운터

추가: `NUMERICS_SCRIPTS` 인벤토리 배열 항목 수 == `verify/numerics_*.hexa`
on-disk glob count.

---

## §5 한 세션에서 진행한 결과 (hexa-cern v1.1.0-pre 사례)

- **15 iterations**, 16 commits
- **16 verify scripts** (4 algebraic + 9 numerical + 3 meta)
- **4 tests**, 3 PDFs
- **5500+ 라인 추가**, 0 .py
- F-PCERN-1/2/3 모두 67% closure (T1 ✓ + T2 ×2~3 ✓, T3 TBD)

각 iteration 은 ~30 분 (chunk 작성 + 회귀 + commit + push) 정도 소요.

---

## §6 다른 hexa-* 프로젝트로 옮길 때 주의점

1. `n=6 lattice` 는 모든 hexa-* 가 공유 (σ(6)=12, τ(6)=4, φ(6)=2, J₂=24).
   대상 프로젝트의 `.roadmap.<project> §A.1` 에 등재되어 있어야 함.
2. **falsifier 명칭 prefix** 는 프로젝트 별로 다름:
   - hexa-cern: `F-PCERN-*`
   - hexa-bio:  `F-BIO-*`
   - hexa-rtsc: `F-RTSC-*`
   - 등등. `.roadmap.<project> §A.4` 가 SSOT.
3. **published reference points** 도 프로젝트별:
   - hexa-cern: LEP / Tevatron / LHC / FCC + BELLA / FACET / ATHENA / FLASHFwd
   - hexa-bio: 알맞은 bio 실험 (CRISPR / MEA / fMRI / 등)
   - hexa-rtsc: MgB₂ / Nb₃Sn / NbTi / YBCO 등 SC 데이터
   - 각 도메인의 4-machine 류 비교 셋을 numerics_*_parity.hexa 가 사용.
4. **sentinel namespace** 는 `__HEXA_<PROJECT>_*__` 로 통일.
   hexa-cern 은 `__HEXA_CERN_*__`, hexa-bio 는 `__HEXA_BIO_*__` 등.
5. **numerics_lattice_arithmetic** 는 모든 프로젝트가 공유 — math_pure
   stability floor 는 도메인 무관.

---

## §7 연속 반복 (closure-depth accumulation 무한 루프)

본 레시피의 핵심 동작 모드. **한 chunk 끝나면 자동으로 다음 chunk** 로
넘어가, 봉쇄 심화 사다리를 계속 내려가는 자가-pacing 사이클.

### §7.1 한 사이클 = 한 commit

위 §2 의 7-step 을 한 단위로:

```
chunk 선택 → write → run → wire → regression → doc → commit+push
```

이걸 끝내면 즉시 **다음 chunk** 를 §7.4 우선순위 표에서 선택하고 다시 §2 로.

### §7.2 stop 조건 (= 사이클 정지점)

다음 셋 중 하나라도 만족하면 루프 종료:

| stop trigger | 의미 |
|:-------------|:-----|
| `sat-1` saturation | 모든 falsifier 가 67% closure 도달 + 각 T2 가 ×3 이상 |
| `sat-2` recipe exhausted | §1 16-script 인벤토리 전부 작성됨 + meta-lint 통과 |
| `user-stop` | 사용자가 `loop end` / `stop` / cancel 입력 |
| `regression-fail` | 어떤 iteration 의 verify-all 또는 test_all 실패 + 한 번 안에 못 고침 |

`sat-1` + `sat-2` 둘 다 만족 → **T3 empirical 만 남음** (하드웨어 필요, 새 세션 chunk 가능 영역 아님). 즉시 정지.

### §7.3 saturation 감지 로직 (자동 stop)

각 iteration 끝에 다음을 체크해 saturation 여부 판정:

```hexa
// pseudo-check
let lint_pass = exec("hexa run verify/lint_numerics.hexa").exit == 0
let inv_count = ls("verify/numerics_*.hexa").len()
let tier_min  = min(F1.T2.len(), F2.T2.len(), F3.T2.len())

if lint_pass && inv_count >= 9 && tier_min >= 3 {
    println("__HEXA_<PROJECT>_RSC_SATURATED__ STOP")
    exit(0)   // 루프 자기-종료 신호
}
```

(이 검사를 `verify/lint_numerics.hexa` 에 추가하거나 별도 `verify/saturation_check.hexa` 로 분리. hexa-cern 사례는 후자.)

### §7.4 다음 chunk 우선순위 (saturation 까지의 default 진행 순서)

이미 있는 슬롯은 건너뛰고 위에서 아래로 채움:

| 우선순위 | 슬롯 | 닫는 falsifier T2 |
|:--------:|:-----|:------------------|
| 1 | `lattice_check.hexa`            | (cross-cutter, 필수 시작) |
| 2 | `cross_doc_audit.hexa`          | (cross-cutter, 필수 시작) |
| 3 | `calc_<pillar>.hexa` × N        | T1 ×N |
| 4 | `numerics_<pillar>.hexa` × N    | T2 ×N (각 falsifier 첫 T2) |
| 5 | `numerics_<pillar>_parity.hexa` × N | T2 ×N (published-ref 비교) |
| 6 | `numerics_<pillar>_solver.hexa` × N | T2 ×N (Verlet/leapfrog ODE) |
| 7 | `numerics_cross_pillar.hexa`    | (cross-cutter T2) |
| 8 | `numerics_lattice_arithmetic.hexa` | (math_pure stability floor) |
| 9 | `falsifier_check.hexa` (closure tracker) | (meta) |
|10 | `lint_numerics.hexa`            | (meta) |
|11 | `tests/test_*.hexa` 보강        | regression |
|12 | `build/Makefile` + `header.tex` | PDF rebuild |
|13 | `docs/numerics_methodology.md`  | narrative |
|14 | (선택) 두 번째 T2 stack 보강    | 각 falsifier T2 ×2~3 |
|15 | (선택) saturation_check.hexa    | self-stop signal |

### §7.5 트리거 메커니즘 옵션

루프를 돌리는 방식 (세션 운영자 선택):

| 메커니즘 | 명령 | 특성 |
|:---------|:-----|:-----|
| 5분 cron | `/loop 5m keep going cycle` | 일정 간격, 사용자 수동 입력 시 stack 가능 |
| dynamic | `/loop continue <project> .hexa porting` | 각 iter 끝에 ScheduleWakeup, 자가-pacing |
| 수동 | 사용자가 매번 `keep going cycle` 입력 | 가장 보수적, 페이스 완전 제어 |

dynamic 모드 권장 — 5분 cron 은 chunk 작성 시간 (≈30 분) 보다 짧아 stack 누적 위험.

### §7.6 한 iteration 평균 budget

hexa-cern 측정값 (15 iterations 기준):

| 단계 | 시간 | 메모 |
|:-----|:-----|:-----|
| chunk 선택 + write | 5–10 min | 새 .hexa 작성 |
| run + 디버그 | 2–5 min | 첫 PASS 까지 |
| wire (CLI/tests/falsifier/lint) | 5 min | 5–7 군데 갱신 |
| regression | 1–2 min | verify all + test_all |
| doc + commit + push | 3 min | CHANGELOG + 메시지 작성 |
| **총** | **~20–30 min** | |

5분 cron 은 이 budget 보다 짧음 → 권장 안 됨. 적정 cadence 는 **20–30 분
heartbeat** (dynamic ScheduleWakeup 1500–1800s 와 일치).

### §7.7 ⚠ no-ask 규칙 (에이전트가 iter 사이에 묻지 않음)

**RSC 루프 모드에서 에이전트는 iteration 사이에 사용자 confirm 을
요청하지 않는다.** "다음: iter N+1 (chunk_X.hexa). 진행할까요?" 형태의
출력은 **위반** — 루프의 self-driving 전제를 깬다.

iter N 의 commit + push 가 끝나면 에이전트는:

1. §7.2 의 4 stop 조건 중 하나가 만족되는지 자동 검사
2. 모두 미만족 → **즉시** §7.4 우선순위 표에서 다음 chunk 선택 →
   §2 7-step 재시작 (사용자 입력 대기 없음)
3. 한 stop 조건 만족 → 종료 (loop end / saturation / regression-fail
   메시지 emit)

#### 위반 phrasing (사용 금지)

- ✗ "다음 chunk: numerics_X.hexa. 진행할까요?"
- ✗ "iter N 완료. 사용자 confirm 후 iter N+1 진행"
- ✗ "다음 후보 [목록]. 어느 것으로?" + AskUserQuestion
- ✗ "계속 할까요?" / "shall I proceed?"
- ✗ (saturation 후) "할 게 없으니 .github/workflows/X.yml 추가" — **over-saturation 강제 chunk 금지**

#### 합법 phrasing

- ✓ "iter N 완료 (commit XXX). iter N+1 시작 — chunk: numerics_X.hexa"
  바로 다음 줄에 파일 작성 시작
- ✓ "saturation reached (sat-1 + sat-2) — RSC loop end"  (오직 stop 시)
- ✓ "regression-fail in iter N — rolling back chunk + retrying with Y"  (regression 처리)

#### 예외 (한 번의 AskUserQuestion 허용)

다음 셋 중 하나라도 해당하면 한 번의 AskUserQuestion 가능:

- §7.4 우선순위 표 모든 슬롯이 채워졌고 (sat-2 직전), 비-recipe 영역
  chunk 후보가 여러 개 있음 (사용자 의도 필요)
- regression-fail 이 일어났는데 roll-back vs fix-forward 결정이
  사용자 정책에 달림
- 사용자가 명시적으로 "ask before next" 라고 지시했음

위 셋 외에는 **무조건 자동 진행**.

---

## §8 새 hexa-* 세션 kickoff (paste-ready)

새 세션에 다음을 입력하면 본 레시피로 즉시 시작 + **자동 반복까지 포함**:

```
hexa-<프로젝트> 의 runnable surface 를
~/core/bedrock/docs/runnable_surface_recipe.md 패턴대로 .hexa 로 구축한다.

작업 모드: closure-depth accumulation 무한 루프 (recipe §7).

⚠ NO-ASK 규칙 (recipe §7.7): 에이전트는 iter 사이에 절대 confirm 을
   요청하지 않는다. "진행할까요?" / "다음 chunk 어떻게?" 류 질문 금지.
   §7.2 stop 조건 만족 시까지 자동 진행. 예외는 §7.7 의 3 항목만.

1. 현재 verify/build/tests 인벤토리 점검 (이미 있는 것 확인)
2. recipe §7.4 우선순위 표에서 미작성 슬롯 한 개를 7-step 사이클로
   추가 (1 chunk = 1 commit)
3. 각 iter 끝에 verify all + test_all 회귀 실행 + origin/main push
4. CHANGELOG iteration 항목 + falsifier_check closure pct 추적
5. iter 끝에서 §7.2 stop 조건 체크:
   - saturation (sat-1 + sat-2) 도달 → 루프 종료
   - regression-fail 발생 → 해당 chunk roll-back 후 다음 chunk
   - 사용자 stop 입력 → 즉시 종료
6. 위 조건 미충족 시 **즉시 iter N+1 시작** (사용자 입력 대기 없음).
   필요시 ScheduleWakeup 1500–1800s 로 cache-warm 다음 iter 예약.

목표: F-<PROJECT>-1/2/3 모두 67% closure (T1 + T2 ×3 stack 권장).
참고 SSOT: .roadmap.<project> §A.4 falsifier preregister.
참고 recipe: ~/core/bedrock/docs/runnable_surface_recipe.md
참고 worked example: ~/core/hexa-cern (15 iterations 적용 사례)

iter 1 시작.
```

마지막 줄 `iter 1 시작.` 이 새 세션 에이전트가 즉시 §2 의 7-step 을 1번 실행하라는 신호. iter 1 이 끝나면 위 6번 흐름에 따라 iter 2 가 자동으로 이어진다 — 추가 사용자 입력 없이.

---

## §9 saturation 도달 시 다음 단계

`sat-1` + `sat-2` 모두 만족 → T3 empirical 만 남은 상태:

| Stage | 설명 | 본 recipe 범위? |
|:------|:-----|:--------------:|
| Stage-1 | 벤치톱 prototype 빌드 (실제 하드웨어) | ✗ 아님 |
| Stage-2 | 실험 데이터 수집 + 라이브 피드 통합 | ✗ 아님 |
| Stage-3 | 외부 collab (DESY / SLAC / 등) 검증 | ✗ 아님 |

이 단계는 코드 layer 가 아니라 hardware/ops layer. **새 .hexa 추가로
닫을 수 없음** — saturation 시 루프 자가 종료가 정답.

루프 종료 시 마지막 commit 메시지에:
```
v1.1.0 RSC saturated — T1+T2 closure complete, T3 awaits Stage-1+ build
```

### §9.1 saturation 후에도 cron/loop 가 계속 firing 하면?

**health-check 만 돌리고 끝.** 새 chunk 강제로 만들지 않음.

Cron 이 살아있어도 saturation 이후 firing 의 적절한 동작:

```
on cron-fire (post-saturation):
  run verify/saturation_check.hexa     # 14/14 PASS expected
  print "RSC still saturated · no chunk needed"
  return                               # 새 chunk 금지
```

**위반 예 (절대 하지 말 것):**

- ✗ saturation 후 "할 게 없으니 `.github/workflows/verify.yml` 추가"
- ✗ saturation 후 "4th T2 추가" / "코드 정리 chunk"
- ✗ saturation 후 README/CHANGELOG 단순 polish 를 chunk 로 위장

**합법적 예외 (post-saturation 에 chunk 추가가 정당한 경우):**

1. saturation_check 가 PASS → FAIL 로 떨어짐 (실제 regression)
2. 사용자가 명시적으로 새 작업 지시 ("CI workflow 만들어", "README 다듬어")
3. T3 (Stage-1+) 가 진짜로 시작됨 — 새 .roadmap 항목 추가됨

이 셋 외에는 **절대로** chunk 자동 추가 금지. 디폴트는 health-check
1번 + 종료. cron 이 5분 마다 firing 해도 매번 "saturation 유지" 보고
1줄로 끝.

---

— 본 레시피는 hexa-cern v1.1.0-pre 에서 검증됨.
   `git log --oneline` 0a74c21..main 의 16 commit 이 한 적용 사례.
   사례별 iteration 로그는 `hexa-cern/CHANGELOG.md` 에 보존.
