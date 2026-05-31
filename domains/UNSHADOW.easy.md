# 🪆 UNSHADOW — perf·자원·속도 ROI 인벤토리 (v2 · hexa-arch 추월 재프레임)

> C/Rust 그림자를 벗은 hexa-only 스택에서 따낼 개선 전수 목록.
> **v2 재프레임**: 🟡 "LLVM 따라잡기"는 함정. 진짜 ROI = 🔵 "hexa-arch 추월"
> (LLVM 에 *애초에 없는* 종목). 브레인스토밍 2차 8라운드 → ~40 아이디어, R8 재조합 → 고갈.

---

# 🪆 일반인용 요약 — "무엇이 좋아졌나" (LIVE 실측 · 2026-05-31)

> 숫자는 전부 이 머신(mini · Apple M4)에서 **실제로 돌려 잰 값**(`UNSHADOW.bench.md §live-sweep`).
> 26개 마일스톤 100% 종료. 결과는 byte 단위로 동일(g5 IDENTICAL) — 속도·메모리만 향상.

## 🪆 UNSHADOW — "남의 엔진 떼기"

- **하는 일**: 우리 언어(hexa)가 남의 엔진(C·LLVM) 위에 얹혀서 못 하던 최적화를,
  엔진을 소유한 뒤 하나씩 붙여서 "실제로 빨라졌나"를 잰다.
- **비유**: 셋방살이 → **내 집 독립**. 셋방(C 엔진)에선 벽을 못 뚫어 못 하던 공사
  (최적화)가, 내 집이 되니 가능해진다.
- **한 줄**: "졸업하면 자동으로 빨라진다"가 아니라 **"졸업해야 막혔던 최적화를
  할 수 있다"**.

```
셋방 (남의 엔진)            내 집 (hexa 소유)
─────────────             ─────────────
 벽 못 뚫음 (C-ABI 벽)  →   벽 뚫음 → 최적화 가능
 박스 포장째 운반        →   알맹이만 직접 운반
 매번 malloc(주문배달)   →   스택(집밥) — 주문 0번
```

## 핵심 비유: "박스 포장 vs 알맹이"

hexa 의 모든 값은 원래 **택배 박스(HexaVal, 16바이트)** 에 담겨 다닌다 — 숫자 하나도
박스에 넣고 꺼낼 때 푼다. 안전하지만 느리다. UNSHADOW = **"안 풀어도 되는 건 알맹이째"**.

```
전 (박스 포장)                후 (알맹이 직접)
───────────────             ───────────────
 [📦3][📦1][📦4][📦1]    →    3  1  4  1
 16칸씩 띄엄띄엄 (못 묶음)      8칸 촘촘 (한 번에 묶어 처리)
 CPU가 1개씩 끙끙             CPU가 4개씩 한 번에 (SIMD)
```

## 무엇이 좋아졌나 (실측 · 전 → 후)

```
종목                    전 (박스)    후 (알맹이)    배수      체감
────────────────────────────────────────────────────────────
🏗️ 구조체 필드 읽기      6.76초       0.05초        135×    "주소록 vs 손가락"
📐 배열 경계검사 생략    1.93초       0.56초        3.45×   "매번 줄자 vs 한 번만"
🔢 실수 배열 합(F64)     1.50초       0.43초        3.48×   "C와 동급 도달"
➕ 정수 누적            1.74초       1.15초        1.51×   "박스 안 풀고 더하기"
💾 메모리(임시객체)      124 MB       1.9 MB        66× 절감 "택배 vs 집밥"
```

### 가장 큰 성과 🏆 — 실수 배열 (F64)

```
       남의 엔진 한계선 (C로 짠 것 = 0.40초)
            │
박스 1.50초 █████████████████████████  (느림)
알맹이 0.43초 ███▏  ◄── 거의 C 와 동급! (천장의 96%까지 따라잡음)
C    0.40초 ██▉
```

박스 때문에 CPU가 숫자를 띄엄띄엄(16칸) 못 묶던 걸, 알맹이(8칸 촘촘)로 바꾸니
**C로 직접 짠 것과 거의 같은 속도** — 같은 결과인데 속도만 4배 가까이.

## 다른 언어와 비교 — 무엇이 다르고 왜 좋은가

```
            Python/JS      Go/Java        C/Rust       hexa (UNSHADOW)
            (인터프리터)    (GC 런타임)     (수동)        (증명 기반)
─────────────────────────────────────────────────────────────────────
빠르기       느림           중간           매우 빠름     C와 동급(따라잡음)
안전장치     자동(느림)      자동(GC)        없음(위험)    자동인데 빠름 ★
경계검사     매번 검사       매번 검사       안 함         "증명되면 생략" ★
메모리      자동(느슨)      GC(지연)        손수(실수↑)   "안 새면 스택" ★
```

★ = hexa 만의 차별점. 핵심은 **"증명해서 공짜로 빼는 것"**:

- **vs Python/JS**: 걔넨 안전하지만 매번 박스를 풀고 검사해 느리다. hexa 는 "이 값은
  항상 정수다 / 이 인덱스는 항상 범위 안이다"가 **컴파일 때 증명**되면 검사를 통째로
  빼서 C 속도로 간다.
- **vs Go/Java**: 걔넨 쓰레기 수거(GC)가 나중에 메모리를 치워 잠깐씩 멈칫. hexa 는
  "이 임시객체는 함수 밖으로 안 샌다"가 증명되면 아예 **스택(집밥)** 에 둬서 치울
  쓰레기 자체가 안 생긴다 (임시객체 2천만 개 → **0개**).
- **vs C/Rust**: 걔넨 빠르지만 경계검사·메모리를 사람이 직접 챙겨 위험. hexa 는
  **검사는 그대로 두되 증명된 곳만 자동 생략** → 안전하면서 빠름.

```
        일반 언어                     hexa
   ┌─────────────────┐        ┌─────────────────┐
   │ 매번 검사·포장   │        │ 컴파일러가 증명  │
   │ (안전하지만 느림)│   →    │      ↓          │
   │                 │        │ 증명된 건 검사   │
   │                 │        │ 통째로 생략(빠름)│
   └─────────────────┘        │ 못한 건 그대로   │
                              │  검사(안전 유지) │
                              └─────────────────┘
```

## 안 된 것도 정직하게 (막다른 길)

- **NaN-boxing(박스를 더 작게)**: 한 종목(랜덤 접근)만 조금 빠르고 주력 종목은 오히려
  2.5~2.8배 **느려져서** 폐기. "작은 박스가 항상 답"이 아님을 실측으로 확인.
- **정수 누적 더 짜내기**: C 컴파일러(clang)가 **이미** 알아서 최적화 중이라 더 뺄 게
  없었다 — "이미 공짜"라 그대로 둠.

> "안 되는 길"을 숫자로 막아두는 게 더 중요 — 다음에 같은 헛수고를 안 한다.

### 아직 안 잰 것 (정직)
위 숫자는 **레버 하나씩** 따로 잰 값이다. **전부 한꺼번에 켜고 통째로 빌드한** 최종
속도는 아직 못 쟀다(빌드 벽 `B9`). 그 한 숫자만 추정으로 남아 있다.

---

> 아래는 기술팀용 ROI 전략 인벤토리(원본 v2). 위 일반인 요약과 같은 도메인의 상세판.

---

🔵 **HEXA-ARCH-NATIVE** — "베끼지 말고 추월"

- 하는 일: LLVM 이 하는 걸 따라 만들지 말고, LLVM 이 **구조적으로 못 하는** 최적화를 hexa 아키텍처로
- 비유: 남의 엔진 똑같이 만들기 vs **연료가 다른 엔진**(이론·증명을 연료로) — 경주 종목이 다름

```
LLVM:  소스 → [저수준 IR = 고수준 의미 소실] → 보수적 (오컴파일 0 최우선이라 과감 못 함)
hexa:  소스 → [고수준 의미 + atlas 이론 + 검증 유지] → 증명-허가 (proven-safe면 과감)
              ▲ LLVM 이 버린 것을 codegen 까지 들고 감 = 다른 altitude = 다른 최적화 공간
```

- 비교: vs LLVM = 보수·저수준·이론無 · vs hexa = 검증허가·고수준·atlas보유 → **비교 대상 없는 이득**

---

## 🏗️ HEXA-STACK — 남의 엔진 위에 내 터보

- 아이콘: 🏗️
- 이름: **HEXA-STACK** (적층 전략)
- 별칭: "남의 엔진 위에 내 터보 얹기" · floor+ceiling stack · "올라타기, 싸우지 않기"
- 한 줄: 🟡(LLVM/C/Rust 동등 raw parity)와 🔵(hexa 고유 우위)를 **동시에** 만족하는 방법 — LLVM 을 재구현(M1: native-asm 가 clang -O2 에 5/5 패배)하지 말고, clang -O2 를 **floor 로 상속**한 위에 🔵 우위를 **ceiling 으로 적층**한다.
- 비유: 검증된 명품 엔진(clang -O2)을 굳이 다시 깎지 말고 **그대로 차에 얹고**(floor 상속, 재구현 0), 그 위에 hexa 만의 터보·니트로(🔵 인라인·atlas-fold·proof-carrying·check-elision)를 **덧붙인다**(ceiling). 엔진을 이기려 새로 깎는 건 함정.

```
        ┌─────────────────────────────────────────────┐
🔵      │  CEILING  =  hexa 고유 우위 (적층)            │
ceiling │  인라인 · atlas-fold · proof-carrying ·       │  ← LLVM 에 없는 종목
        │  check-elision  (이론·증명·전스택의미·comptime)│     = "안 돌기"
        ├───────────────  ⛔ runtime.o C-ABI 벽  ───────┤  ← 블로커: 경계 너머
        │   (#2-ext rt_str · C tag-elision 둘 다 여기서 막힘)│     clang·🔵 둘다 불가
        │   🔑 LTO / same-TU = .c=0 졸업 = 벽 제거 열쇠   │  ← 열면 둘 다 win
        ├─────────────────────────────────────────────┤
🟡      │  FLOOR  =  clang -O2 (상속, 재구현 0)          │
floor   │  loop-unroll · reg-alloc · SIMD · sched       │  ← C-emit 경로가 이미 통과
        └─────────────────────────────────────────────┘
```

| | 🏗️ HEXA-STACK (이 전략) | 함정: native-asm 으로 LLVM 이기기 |
|---|---|---|
| 🟡 floor | clang -O2 **상속** (재구현 0) | 직접 재구현 → M1 에서 5/5 패배 |
| 🔵 ceiling | floor 위에 적층 (LLVM 불가 종목) | floor 못 깔아 ceiling 도 못 쌓음 |
| 블로커 | `runtime.o` C-ABI 벽 (경계 너머 둘 다 불가) | 〃 (게다가 floor 마저 손실) |
| 열쇠 | LTO/same-TU = `.c=0` 졸업 → 벽 제거 시 #2-ext·C 가 🔴→win | 없음 (싸움 자체가 음수 ROI) |

> **핵심 4가지**: floor 는 **상속**한다(안 짠다) · ceiling 은 **적층**한다(쌓는다) · `runtime.o` ABI 벽이 **블로커**다(경계 너머 clang·🔵 둘 다 막힘) · LTO/same-TU `.c=0` 졸업이 **열쇠**다(벽 제거 → 두 tier 동시 개방).

### 측정 증거 (이번 캠페인 누적 · 전부 g5 byte-diff IDENTICAL · mini macOS arm64)

> 원칙은 말이 아니라 **실측**으로 뒷받침된다. 각 🔵 ceiling 기법 = 측정된 win, 각 🟡/벽 한계 = 정직한 finding. 상세 = `UNSHADOW.bench.md` + milestone 줄.

| layer | 기법 (milestone) | 측정 | verdict |
|---|---|---|---|
| 🟡 floor | clang -O2 **부분 상속** (parity §parity-attest) | emit-C @-O0→@-O2 = **1.19×~1.78×** · hot-fn instr **−44%** | 🟢 상속 참 (rides clang -O2) |
| 🔵 ceiling | #2 cross-layer 인라인 — `hexa_int` 정수리터럴 박스 (runtime.h-가시) | hot-loop 1.83→1.31s = **~28%** · `bl` 13→5 | 🟢 WIN (layout-only, 경계 안) |
| 🔵 ceiling | A atlas-guided const-fold — 검증식 → 직접 `hexa_int(11)` emit | hot-loop 0.26→0.09s = **~65%** | 🟢 WIN ("안 돌기") |
| 🔵 ceiling | B proof-carrying — 검증 identity license 로 opaque call 치환 | hot-loop 0.36→0.19s = **~47%** · call 소거 | 🟢 WIN (#2 layout 결합) |
| 🟢 자원 | arena reclaim 배선 (기존 opt-in 측정) | peak RSS **−40%** · wall **−26%** (N=400k) | 🟢 WIN (constant-factor, bound 아님) |
| ⛔ 벽 | C refinement tag-elision (#2-EXT 와 수렴) | base/new asm IDENTICAL — clang -O2 가 이미 dead-elim | 🔴 CLOSED-NEG (벽 안=중복·벽 밖=opaque) |
| 🔑 열쇠 | LTO/same-TU unwall — #2-ext rt_str (벽 제거) | `-flto` 불충분(컴파일-타임 실패) · **same-TU FLIP 🔴→WIN** 0.36→0.25s = **−31%** | 🟢→🔵 unwall 입증 |
| 🔑 열쇠 | 〃 — C bounds/null elision (벽 제거) | 벽 제거+본문 가시에도 clang 이 opaque bounds 안 elide (Δ 0) | 🔴 NULL — proof-carrying codegen 필요 (별 axis) |

> **요약 한 줄**: 🔵 ceiling 3종(#2 28% · A 65% · B 47%)이 floor(상속 1.19~1.78×) 위에서 실측 win 을 따냈고, 자원축도 −40% RSS. 한계도 정직 — C tag-elision 은 🔴(벽), same-TU 는 벽을 깨 **−31% FLIP**(단 `-flto` 불충분), bounds-null 은 벽 제거만으론 🔴 NULL(증명 codegen 필요).
>
> **아직 안 잰 최대 레버** = 🟢 **HexaVal 언박싱** (open milestone). parity §parity-attest 가 raw 7.9×~1263× 갭의 주범으로 **HexaVal 박싱**을 지목 — known-int/bool/float 값전달을 박싱 없이 레지스터 패킹하면 이 갭의 대부분을 닫을 잠재력. 측정 전이므로 **예측 레버**로만 표기(아직 win 주장 금지).

---

## 분류 3종 (altitude 기준)

| 등급 | 의미 | ROI 위치 |
|---|---|---|
| 🔵 **HEXA-ARCH-NATIVE** | LLVM 에 없는 종목 — 추월 (이론·증명·전스택의미·comptime) | **최우선** |
| 🟢 **OWNERSHIP-UNLOCK** | C-ABI 벽이 막던 것 → 졸업으로 열림 | 높음 |
| 🟡 **LLVM-REIMPL** | 따라잡기 — 잘해야 동점 | **후순위** (🔵🟢 못 닿는 곳만) |

> roofline 원칙(g5·메모리): raw 스칼라/벡터 천장은 LLVM 과 비김(PTX-diff: vec-add 동일·GEMM nvcc 2~4×).
> **하지만** 🔵는 raw 벤치 종목이 아님 — "루프를 빨리 돌기"(🟡) vs "루프를 안 돌기"(🔵, 검증된 closed-form 치환).

---

## 🔵 Tier — hexa-arch 추월 (7 families · 최고 ROI)

### A. atlas 이론-구동 재작성 (theorem-driven rewriting)
LLVM 엔 정리(theorem) DB 자체가 없음 → 이 클래스 전체가 LLVM 불가.

| 항목 | 효과 | 예 |
|---|---|---|
| 루프→closed-form **제거** | O(n)→O(1) | `for i: s+=i` → `n(n+1)/2` (atlas Faulhaber) |
| 검증 대수 단순화 | 식 축소 (LLVM 패턴셋 너머) | 삼각·행렬·환/체 항등식 |
| 검증 strength-reduction | 비싼 op→싼 op | 모듈러·GF 항등식 (비자명) |
| 항등 죽은계산 제거 | f(x)=x 증명 시 f 소멸 | 도메인-한정 identity |

### B. 증명-허가 최적화 (proof-carrying · 검증을 license 로)
LLVM 은 로컬-보수적(일반 안전만). hexa 는 `hexa verify` 로 "여기선 안전" 증명 후 과감.

| 항목 | 효과 |
|---|---|
| proven-safe 공격적 재작성 | LLVM 이 겁내는 변환을 증명 후 적용 |
| 오차범위-증명 float 재결합 | LLVM 은 float reassoc 거부(결과변동) → atlas 오차한계 증명 시 허용 |
| UB-free 가정 (증명판) | LLVM=가정(미스컴파일 위험) · hexa=**증명** 후 최적화 |
| speculative + 검증 fallback | 빠른 경로 + atlas 동등성 증명 |
| self-verifying pass | 각 pass 가 증명 의무 emit→verify (comptime-fold shadow 버그류 차단) |

### C. 전-스택 의미 보존 (LLVM 이 IR 낮출 때 버린 정보)
HexaVal 타입·효과·정제(refinement)를 codegen 까지 → 재추론 0.

| 항목 | 효과 |
|---|---|
| refinement-type bounds-check 제거 | `0≤i<n` 타입 → 경계검사 삭제 (LLVM range분석 자주 실패) |
| nullability null-check 제거 | non-null 타입 → 검사 삭제 |
| 효과-타입 reorder/병렬 | purity/effect → 독립영역 자동병렬 (LLVM IR 레벨 alias 증명 불가) |
| linearity in-place 변이 | unique-ref 증명 → COW 없이 제자리 (struct_pack aliasing 해소) |
| HexaVal tag-elision | 1-variant 좁힘 시 tag검사·dispatch 삭제 |

### D. comptime 부분평가 (LLVM 엔 언어 comptime 단계 없음)
| 항목 | 효과 |
|---|---|
| whole-program 부분평가 | generic 인터프리터 루프→직선코드 (Futamura · self-host 와 자연 결합) |
| comptime codegen 특수화 | call-site shape 별 맞춤 emit |
| const-table precompute | atlas/comptime 가 LUT 컴파일타임 산출 |
| staged 컴파일 | 감지된 workload 별 특수 바이너리 |

### E. 데이터 표현 자유 (C ABI 가 레이아웃 고정 → LLVM 손 못 댐)
| 항목 | 효과 |
|---|---|
| AoS↔SoA 자동전환 | 접근패턴 분석 → 캐시·coalescing 개선 |
| per-program NaN-box/ptr-tag | 고정 ABI 아닌 프로그램별 표현 선택 |
| region/arena 추론 | lifetime 타입 → proven-region 은 GC 0 |
| per-site GC 전략 | escape+lifetime 타입별 |
| zero-copy 슬라이스 | linearity 증명 기반 |

### F. CPU/GPU 통합 (한 IR 에서 PTX+ARM64 — C 는 CUDA 별도 툴체인)
| 항목 | 효과 |
|---|---|
| 자동 CPU↔GPU 분할 | 한 IR 에서 배치 결정 |
| cross-kernel fusion | IR 레벨 융합(소스 아님 · flame 연계) |
| 검증 커널 치환 | naive GEMM→검증된 blocked |
| 정밀도 자동선택 | fp32/fp16 atlas 오차증명 |

### G. 자기개선 컴파일러 (hexa 고유 — kick/drill 루프)
| 항목 | 효과 |
|---|---|
| 발견→rewrite-rule 피드백 | `hexa kick/drill` 발견 항등식이 새 최적화 규칙으로 |
| 도메인 atlas slice | signal/math/crypto 별 도메인-튜닝 codegen |
| atlas-as-PGO | 검증 hot-path 속성으로 layout/특수화 |
| 검증 memoization | atlas 가 pure+idempotent 증명 → 캐시 |

---

## 🟢 Tier — ownership-unlock (C-ABI 벽 제거 · 졸업으로 열림)

| 항목 | 축 | 메모 |
|---|---|---|
| HexaVal 언박싱/레지스터-팩 | 성능 | small-int/bool 힙없이 인라인 |
| cross-layer 인라인 (런타임 prim) | 성능 | call 오버헤드 제거 + const-fold 전파 (B proof-carrying 과 결합 강력) |
| escape→stack-alloc | 자원 | 비-escape HexaVal 스택 |
| arena reclaim 튜닝 | 자원 | `HEXA_VAL_ARENA` 이미 ON — 배선만 |
| SSO 짧은문자열 | 자원 | 힙 0 |
| DCE/link tree-shake + libc 미링크 | 자원 | 작은 바이너리·RSS↓ |
| AOT atlas 바이너리파싱 | 속도(startup) | TEXT-parse → 바이너리 |
| 병렬 codegen · incremental cache | 속도(compile) | — |
| prebuilt runtime.a | 속도(link) | **이미 #2019/#2020 랜딩** |

---

## 🟡 Tier — LLVM 따라잡기 (강등 · 🔵🟢 못 닿는 곳만)

> 전면 재구현 ROI 음수 위험. **측정으로 격차 확인된 지점만** 선별 투입.

loop-unroll/ILP · register allocation · SIMD 벡터화 · instruction scheduling · TCO · COW
→ 단, 다수는 🔵 로 우회 가능: unroll→A(루프제거) · SIMD→B(검증 reassoc 벡터화) · reg-alloc→C(타입정보 활용).

---

## 🪆 채굴된 새 광맥 — 거울방 mining (2026-05-30)

> 닫힌 14개를 거꾸로 캐보니(/mining + 거울방), 모든 closed-negative 가 한 곳을
> 가리켰다 — **"느린 진짜 원인은 codegen 군더더기가 아니라 데이터 표현(박싱)"**.
> 거기서 새 광맥 3 family · milestone 5개. SSOT = `UNSHADOW.MINING.md`.

```
🛠️ HEXA-MINE — "닫힌 갱도 보고 광맥 찾기"

- 하는 일: 끝낸 작업들의 공통 실패/성공 패턴을 역추적 → 다음 캘 자리(milestone) 표시
- 비유: 광부가 캔 자리를 지도에 찍어 "광맥이 이쪽으로 흐르네" 추적
```

ASCII (거울방 되먹임):

```
닫힌 14개 ──[거울]──▶ 공통 광맥        ┌──────────────┐
   measured            "박싱이 벽"  ──▶│ 발산 24 후보  │
      ▲                                │ 수렴 3 family │
      └──── 새 milestone ◀── 등록 ◀────│ ROI 랭킹      │
                                       └──────────────┘
```

- 비교: 일반 백로그 = 사람이 다음 할 일 나열 / HEXA-MINE = **측정된 닫힘에서 패러다임을 역도출** (추측 아닌 증거 기반)

### 🪆 F1 — 데이터-표현 주권 ("박스 벗기기")

- **하는 일**: 모든 값을 24바이트 태그박스(HexaVal)에 싸던 걸, 타입 아는 곳은 native 표현으로
- **비유**: 택배를 매번 뽁뽁이로 싸 선반에 두던 걸 → 알맹이만 빼곡히 (그제야 캐시·SIMD가 먹음)
- **HEADLINE**: native `HexaArrI64/F64` 저장 — `[📦][📦][📦]`(16B-stride, clang SIMD 불가) → `[8 8 8 8]`(연속, 자동 벡터화). 멤버: NaN-boxing(24B→8B)
- **비교**: clang은 박스 못 벗김(고정 ABI) / hexa는 표현을 소유 → 프로그램별 선택 (🔵 LLVM 불가)

### 📐 F2 — 미채굴 perf 축 ("시간 말고 공간")

- **하는 일**: 닫힌 14개가 전부 *시간*축 — *공간·시작·링크*축은 텅 빔
- **비유**: 100m 기록만 재다가 "근데 짐 무게(메모리)는?" 처음 물어봄
- 멤버: escape→stack-alloc(안 새는 값은 스택에, 힙 0) · region/gen-GC · AOT-atlas 파싱(시작 속도)
- **비교**: vs 시간축 일변도 → 자원·startup 새 측정 차원 개방

### ♾️ F3 — atlas-as-perf-asset ("내 정리노트로 나를 최적화")

- **하는 일**: hexa의 검증 저장소(atlas)를 *성능 자산*으로 — 검증된 순수함수는 캐시·PGO에 활용
- **비유**: 풀어둔 문제집 답안을 다음 시험에 재활용 (다시 안 풀어도 됨)
- 멤버: 검증 memoization(순수+멱등 증명 → 호출 캐시) · atlas-guided PGO(검증된 hot-path로 레이아웃)
- **비교**: clang엔 theorem DB 없음 → 구조적 불가 (🔵 hexa 고유 · 거울방 = 자기 자신을 재료로)

---

## 🎯 권장 진입 순서 (ROI 내림차순 · low-risk first)

```
1) 🟢 HexaVal 언박싱 + cross-layer 인라인       ─ 측정 harness(M1) 깔며 즉효
2) 🔵 A 루프→closed-form (atlas 1건)            ─ hexa 고유 · "안 돌기" 실증
3) 🔵 C bounds/null/tag-elision                  ─ 타입정보 = 공짜 license
4) 🔵 B proof-carrying 1건 (cross-layer 결합)    ─ 증명-허가 regime 개시
5) 🔵 E AoS↔SoA  OR  F CPU/GPU fusion            ─ 도메인 따라 택1
─────────────────────────────────────────────── 여기까지 = 🔵 추월 5종 실증
그 후) 🟡 는 측정으로 격차 확인된 곳만
```

## 측정 원칙 (g5 · roofline · instrument-first)

- 모든 항목 **micro-bench harness(M1)로 Δ 실측** 후에만 이득 주장. LLM 자가판정 금지.
- 🔵 는 atlas 등록(`hexa verify`→fold)으로 **정확성 먼저 증명**, 그 다음 perf Δ.
- 승부 = roofline % (🟢🟡) + **LLVM-불가 이득 존재 증명** (🔵 — 비교대상 없음).

---

_v2 재프레임: 🔵 HEXA-ARCH-NATIVE 7 families 신설 · 🟡 강등. 2차 브레인스토밍 8 rounds · ~40 ideas · R8 재조합 → depleted._
