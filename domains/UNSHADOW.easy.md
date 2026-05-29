# 🪆 UNSHADOW — perf·자원·속도 ROI 인벤토리 (v2 · hexa-arch 추월 재프레임)

> C/Rust 그림자를 벗은 hexa-only 스택에서 따낼 개선 전수 목록.
> **v2 재프레임**: 🟡 "LLVM 따라잡기"는 함정. 진짜 ROI = 🔵 "hexa-arch 추월"
> (LLVM 에 *애초에 없는* 종목). 브레인스토밍 2차 8라운드 → ~40 아이디어, R8 재조합 → 고갈.

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
