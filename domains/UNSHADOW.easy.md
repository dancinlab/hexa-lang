# 🪆 UNSHADOW — perf·자원·속도 ROI 인벤토리 (브레인스토밍 고갈본)

> C/Rust 그림자를 벗은 hexa-only 스택에서 따낼 수 있는 개선 전수 목록.
> 브레인스토밍 8라운드 → 고갈 (R7부터 재조합만). 29개 → ROI(임팩트/노력, low-risk) 정렬.

🪆 **UNSHADOW** — "남의 엔진 떼기"

- 하는 일: 남이 만든 엔진(C/Rust)을 떼고 hexa 가 바닥까지 소유 → 막혔던 최적화를 직접 튜닝
- 비유: 남의 변속기 얹은 차 → **변속기까지 직접 설계** = 기어비를 내 엔진에 맞춤

```
지금(그림자):  hexa code ─[C-ABI 벽]─ clang -O2 runtime   ← 최적화기가 벽 너머 못 봄
목표(졸업후):  hexa code ──────────── hexa-native runtime  ← 벽 제거 = 통째 최적화
```

- 비교: vs Rust/C = 안전·이식성 주고 **최적화 주권** 가져감 · vs UNSHADOW = 주권 회복(단 LLVM 급은 재구현)

---

## ⚠ 정직한 분류 — 이득의 2종류

| 종류 | 의미 | 예 |
|---|---|---|
| 🟢 **OWNERSHIP-UNLOCK** | C-ABI 벽이 막던 것 → 졸업으로 *새로* 가능 (진짜 공짜 이득) | cross-layer 인라인 · 전용 allocator · atlas-fold |
| 🟡 **LLVM-REIMPL** | LLVM 이 거저 주던 것 → 직접 재구현해야 본전 (이득 아닌 "안 지기") | loop-unroll · reg-alloc · SIMD |

> roofline 원칙(메모리): 스칼라/벡터 raw 천장 = 이미 LLVM 근처. 증거 PTX-diff — vec-add 동일(bandwidth-bound), GEMM nvcc 2~4×(loop-unroll/ILP). **이득은 🟢에서, 🟡은 따라잡기.**

---

## 🥇 Tier-1 — 최고 ROI (high impact · low-med effort · 🟢 ownership-unlock)

| # | 항목 | 축 | 임팩트 | 노력 | 종류 | 메모 |
|---|---|---|---|---|---|---|
| 1 | **HexaVal 언박싱/레지스터-팩** | 성능 | H | M | 🟢 | 태그드 유니온을 값-전달 시 레지스터에 패킹, small-int/bool 힙 없이 인라인. 산술 hot-path 직격 |
| 2 | **cross-layer 인라인** (런타임 prim → 유저 hot code) | 성능 | H | M | 🟢 | rt_str_*·HexaVal ctor 를 호출지에 인라인 → call 오버헤드 제거 + const-fold 전파. **가장 유망** |
| 3 | **arena reclaim wiring 튜닝** | 자원 | M-H | L | 🟢 | `HEXA_VAL_ARENA` 이미 default ON — region 크기·reclaim opt-in 배선만 (메모리: reclaim 별도 env). 거의 공짜 |
| 4 | **atlas-guided const fold** | 속도/성능 | M | L-M | 🟢 | 검증식(atlas)을 codegen 이 직접 상수로 fold. hexa 고유 — 남이 못 함 |
| 5 | **comptime-fold 확장** | 성능 | M | L | 🟢 | 소유한 런타임 너머로 const 전파 확대 (shadow 버그 family 주의 — invalidate 순서) |

## 🥈 Tier-2 — 높은 ROI (자원 위주 · low effort)

| # | 항목 | 축 | 임팩트 | 노력 | 종류 | 메모 |
|---|---|---|---|---|---|---|
| 6 | **escape analysis → stack-alloc** | 자원 | H | M | 🟢 | 비-escape HexaVal 은 arena도 건너뛰고 스택. alloc 0 |
| 7 | **SSO (small-string opt)** | 자원 | M | L-M | 🟢 | 짧은 문자열 HexaVal 내부 인라인 → 힙 없음 |
| 8 | **DCE / link tree-shake** | 자원 | M | L | 🟢 | 죽은 코드 제거 → 작은 바이너리 (libc 미링크와 시너지) |
| 9 | **AOT atlas 바이너리 파싱** | 속도(startup) | M | L | 🟢 | 현 TEXT-parse(`HEXA_ATLAS_EMBED`) → 바이너리. 시작 지연↓ |
| 10 | **libc 미링크 + 전용 syscall** | 자원 | M | M | 🟢 | F3 self-emit 의 연장 — libc 의존 제거 → 바이너리·RSS↓ |

## 🥉 Tier-3 — 중 ROI (🟡 LLVM 재구현 — "안 지기" 영역, effort 큼)

| # | 항목 | 축 | 임팩트 | 노력 | 종류 | 메모 |
|---|---|---|---|---|---|---|
| 11 | **loop unroll / ILP** | 성능 | H | H | 🟡 | GEMM nvcc 2~4× 격차의 원인. 재구현해야 본전 |
| 12 | **register allocation 개선** | 성능 | H | H | 🟡 | naive stack-based 면 큰 이득, 단 구현 무거움 |
| 13 | **SIMD 벡터화** (NEON/AVX) | 성능 | H | H | 🟡 | element-wise·reduce 자동 벡터화 |
| 14 | **instruction scheduling** | 성능 | M | M-H | 🟡 | 파이프라인 stall 감소 (F3 cset/svc 는 이미 수동 튜닝됨) |
| 15 | **tail-call 최적화** | 성능/자원 | M | M | 🟢 | 재귀 → 루프, 스택 절약 |
| 16 | **COW 배열/문자열** | 자원 | M | M | 🟢 | struct_pack shallow-clone aliasing(메모리) 정리와 연계 |

## 🏅 Tier-4 — 속도(컴파일·throughput) 축

| # | 항목 | 축 | 임팩트 | 노력 | 종류 | 메모 |
|---|---|---|---|---|---|---|
| 17 | **병렬 codegen** (multi-core) | 속도(compile) | M | M | 🟢 | 파일/함수 단위 병렬 emit |
| 18 | **incremental compile cache** | 속도(compile) | M | M | 🟢 | 변경분만 재emit |
| 19 | **lazy module loading** | 속도(startup) | L-M | M | 🟢 | use 모듈 지연 로드 |
| 20 | **prebuilt runtime.a 링크** | 속도(link) | L-M | — | 🟢 | **이미 Phase-1 #2019/#2020 랜딩** — link 시간 부수익 |

## 🔬 Tier-5 — frontier / 고노력 (장기)

| # | 항목 | 축 | 종류 | 메모 |
|---|---|---|---|---|
| 21 | atlas-backed PGO (profile = atlas) | 성능 | 🟢 | hexa 고유 — 검증 저장소를 프로파일로 |
| 22 | verified strength-reduction | 성능 | 🟢 | 비싼 op → 검증-동등 싼 op |
| 23 | 순수함수 memoization (atlas) | 성능 | 🟢 | atlas 캐시 백엔드 |
| 24 | generational/region GC | 자원 | 🟡 | 소유하니 가능, 구현 큼 |
| 25 | custom calling-convention | 성능 | 🟢 | 내부 호출 caller-saved 세금↓ |
| 26 | GPU ILP (PTX GEMM 격차) | 성능 | 🟡 | flame 도메인 일부 중첩 |
| 27 | fused kernels (element-wise) | 성능 | 🟡 | flame 와 중첩 |
| 28 | hot/cold layout split | 성능 | 🟡 | PGO 의존 |
| 29 | string interning | 자원 | 🟢 | 반복 리터럴 1회 |

---

## 🎯 권장 진입 순서 (ROI 내림차순 · low-risk first)

```
1) #1 HexaVal 언박싱   ─┐ 산술/스칼라 hot-path
2) #2 cross-layer 인라인 ┼─ 🟢 가장 큰 ownership-unlock 묶음
3) #3 arena reclaim     ─┘ (거의 공짜)
4) #6 escape→stack       자원 H
5) #4 atlas-fold         hexa 고유 차별화
─────────────────────── 여기까지 = 측정 harness(#M1)로 Δ 실증 가능
그 후) #11~13 LLVM-reimpl 은 "측정으로 격차 확인된 곳만" 선별 투입
```

## 측정 원칙 (g5 · roofline · instrument-first)

- 모든 항목은 **micro-bench harness(milestone M1)로 Δ 실측** 후에만 "이득" 주장. LLM 자가판정 금지.
- 승부는 **roofline %** — "C보다 빠르다"가 아니라 "벽이 막던 걸 열어 roofline 에 더 붙었다".
- 🟡 항목은 *측정으로 격차가 확인된 지점*만 투입 (LLVM 전면 재구현은 ROI 음수 위험).

---

_브레인스토밍 고갈: 8 rounds · 29 ideas · R7+ 재조합만 → depleted. ROI 정렬 완료._
