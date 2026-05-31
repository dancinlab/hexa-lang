@title: 🌳 HEXA-SELFHOST+ — "C 목발 떼고 자립"
@goal: hexa 가 C 중간물(.c·.o·.a)·hand-asm 0 으로 자기 자신을 빌드한다 — self-host 졸업. 메타도메인(`+`): 세 자식 도메인(BUILDFLOOR 빌드레시피 · RUNTIME 런타임 .hexa화 · CC-NATIVE C 중간물 제거)을 한 북극성 아래 묶어 진행도를 롤업하고, "셋 중 가장 막힌 칸"을 next-list 로 제시한다. 자식 진행도는 각 도메인 SSOT 에서 derived — 이 파일은 합성/조율만.

# HEXA-SELFHOST+ — current state

세 도메인이 전부 한 문장으로 수렴한다 — **"hexa 가 C 없이 자기를 빌드한다"**. 의존
흐름은 아래→위: 빌드 레시피(BUILDFLOOR)가 깔려야 그 위에 런타임을 .hexa 로 깎고
(RUNTIME), 그 결과물이 C 한 줄 없이 자기를 다시 빌드한다(CC-NATIVE). HEXA-CC-ZERO
(✅ 100%, 커밋된 .c=0 warm-seed)의 자매 — CC-ZERO 가 "커밋된 .c=0" 이면 이 메타는
"빌드 산출 .c=0" 으로 한 단계 더 간다.

```
[ BUILDFLOOR ] ──▶ [ RUNTIME ] ──▶ [ CC-NATIVE ]
  어떻게 빌드        무엇을 빌드      무엇으로 빌드
  (레시피 0%)        (런타임 80%)     (컴파일러 12%)
       └──────── 공통 적: hand C/asm · 외부 툴체인 ────────┘
```

## progress

- [ ] 🧱 BUILDFLOOR — 멀티모듈 `.hexa` → 단일 canonical 빌드 레시피 (Go/Rust 식). 현 0% — 미시작 바닥 인프라. SSOT=`HEXA-BUILDFLOOR.md`
- [ ] 🛸 RUNTIME — `.hexa`-only self-host · 548-fn C floor → hexa-native. 현 80% (146/182). 잔여 = 순수-fn 포팅(A) · 잔여 17 syscall(B) · phase-H backend flip. SSOT=`RUNTIME.md`
- [ ] 🌱 CC-NATIVE — 빌드 산출 `.c·.o·.a` = 0 으로 self-compile. 현 12% — 진행 중(sibling 에이전트 활발). SSOT=`HEXA-CC-NATIVE.md`
- [ ] 🔗 META — 세 자식 진행도 주간 롤업 + cross-domain 차단/의존 추적 (이 파일이 조율 SSOT · 자식 수치는 derived, 여기에 복제 금지)

## milestones

> 메타도메인 규약: 실제 작업·체크박스 flip 은 자식 도메인 SSOT 에서 일어난다. 이
> 파일의 milestone 은 cross-domain **조율/차단/의존**만 추적한다 (자식 진행도 복제 X).

- [ ] 의존 순서 박제 — BUILDFLOOR(레시피) → RUNTIME(런타임) → CC-NATIVE(컴파일러) 선후를 cross-domain 계약으로 명시. 한 도메인의 frontier 가 다른 도메인 선결을 요구하면 여기에 기록.
- [ ] 공통-벽 카탈로그 — 세 도메인이 공유하는 차단 요인 추적: (1) codegen type-erasure(HexaVal tagged-union → HX_TAG macro 가 codegen-only) (2) cc --regen sign/pool 의존 (3) stale-seed byte-eq 오염(HEXA-CC-ZERO P1). 어느 자식이든 이 벽에 막히면 여기에 누적 → 한 번에 풀 레버 식별.
- [~] 다음-칸 셀렉터 — 매 라운드 "셋 중 가장 grounded·codegen-벽 없는 칸" 1개를 next-list 로 제시. 자식이 honest-STOP 으로 막히면 다음 자식으로 회전. **회전 이력(2026-05-31)**: RUNTIME A(순수-fn) → codegen type-erasure 벽 honest-STOP · GPU 1b-cons(N-consumer) → 동 벽 · CC-NATIVE native-print(#2270) → IO-floor codegen 벽 honest-STOP. **셋 다 codegen emit 벽으로 수렴** → 현재 칸 = **BUILDFLOOR M1**(.sh 빌드레시피 fix, codegen 벽 無 = 유일 grounded, 진행 중 agent). CC-NATIVE 작업은 이 세션(메타)으로 일원화(drafts/SESSION-HANDOFF-hexa-cc-native.md 흡수) — 타세션 중복 진행 중단됨.
- [ ] 졸업 게이트 정의 — 메타 100% = 세 자식 모두 100% AND `ls self/*.c self/*.s` 빈 출력 AND 빌드 파이프라인에 cc/as 단계 0 AND gen1≡gen2 fixpoint(RUNTIME.md Final acceptance 3조건 + BUILDFLOOR·CC-NATIVE 졸업). 이 게이트가 참일 때만 메타 flip.
