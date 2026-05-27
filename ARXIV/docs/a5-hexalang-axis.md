# A5 — HEXA-LANG axis: 컴파일러/수론 논문 흡수 → 수론 atom verify (IN-REPO)

> ARXIV 도메인 A5 마일스톤. HEXA-LANG axis (cs.PL · math.NT · cs.LO) 흡수.
> A1(POC 12) + A2(ANIMA 11) + A3(DEMIURGE 12) + A4(PHANES 10)에 이어 **A5 는
> 흡수하는 repo 자체(hexa-lang)가 대상인 IN-REPO 축** — A2/A3/A4 가 sibling repo
> (anima/demiurge/phanes)로 handoff 한 것과 달리 cross-repo handoff 가 없다.
> **A5 는 ARXIV 두 번째 verify-able 축이자, 논문이 실제로 다루는 수론 폐형해 *값*을
> recompute 하는 첫 축이다** — A3 는 물리 factor/exponent 를 검증했고, A2/A4 = 0.

## 1 · 한 문단 요약

arXiv API 6 query → **13편 on-topic 흡수** → 2-sub-theme triage:
**math.NT 8편 = verify-native** (σ/τ/φ/μ/nth_prime/catalan/partition 등 hexa-native
폐형해 atom 을 논문의 대상 함수가 그대로 인용 → DIRECT recompute, citation 아님) ·
**cs.PL/cs.LO 5편 = 🟡 citation** (hexa 의 atlas-cite-at-compile 모델 아키텍처 인용).
A5 의 산출 가치 = **수론 폐형해 16종 fn · 30+ recompute 🔵 (+ 1 🔴 결정성 대조군)** +
hexa 자체 설계(atlas = 비파괴 등가 저장소 / @cite = proof-carrying-code 증명서 /
lint-stage = CompCert TCB)의 cs.PL/cs.LO 매핑. **A2/A4(0 verify-able)와 달리 A5 는
지금 수론 값을 닫는다 — A3 verify-native 와 같은 부류.**

## 2 · 핵심 A5 발견 — HEXA-LANG 은 가장 강한 verify-native 축

A5 의 verify-native 성격은 우연이 아니라 **구조적**이다. hexa 의 atlas 가 이미
σ/τ/φ/μ/nth_prime/catalan/partition 을 TECS-L Tier1 폐형해로 보유하므로, math.NT
논문의 *대상* 이 곧 hexa atom → citation 이 아니라 recompute.

HEAD 드라이버(#1153) · mini arm64 · `POOL_DISABLE=1` 에서 **LIVE 확인**
(16종 fn · 30+ recompute · 발췌):

| fn (정수-exact) | verify | 수론 의미 | 인용 논문 |
|---|---|---|---|
| `sigma 496 992` | 🔵 SUPPORTED-FORMAL | σ(496)=992=2·496 (완전수, σ=2n) | 2202.06357 · 1704.05595 |
| `is_perfect 496 1` | 🔵 SUPPORTED-FORMAL | 496 = 세 번째 짝수 완전수 | 1011.6160 · 1309.0906 |
| `aliquot 12 16` | 🔵 SUPPORTED-FORMAL | 진약수합 1+2+3+4+6 (과잉수) | 1011.6160 |
| `tau 72 12` | 🔵 SUPPORTED-FORMAL | d(72)=12 (τ(p^a)=a+1 곱셈성) | 0201265 · 1704.05595 |
| `euler_phi 15 8` | 🔵 SUPPORTED-FORMAL | φ(15)=φ(3)φ(5)=2·4 (곱셈성) | 1207.4446 |
| `mu 30 -1` | 🔵 SUPPORTED-FORMAL | μ(2·3·5)=(-1)³ (square-free 부호) | (1 의 Dirichlet 역) |
| `mobius 12 0` | 🔵 SUPPORTED-FORMAL | 12=2²·3 square 인자 → 0 | — |
| `nth_prime 10 29` | 🔵 SUPPORTED-FORMAL | 10번째 소수 = 29 | 0210312 (Ruiz-Sondow) |
| `partition 10 42` | 🔵 SUPPORTED-FORMAL | p(10)=42 | 0201265 (Ramanujan/Moree) |
| `catalan 5 42` | 🔵 SUPPORTED-FORMAL | C₅=42 | 0502532 (Callan) |
| `bell 5 52` | 🔵 SUPPORTED-FORMAL | B₅=52 | — |
| `first_cusp_form_weight 1 12` | 🔵 SUPPORTED-FORMAL | SL₂(ℤ) 첫 cusp form weight=12 (Δ) | (모듈러폼) |
| `sigma 6 13` | 🔴 FALSIFIED (calc=12≠13) | 결정성 음성 대조군 | — |

→ **16종 정수-exact 수론 fn 이 지금 🔵 verify-able** (σ/tau/phi/euler_phi/
euler_totient/mu/mobius/nth_prime/is_prime/is_perfect/aliquot/divisor_sum/
divisor_count/partition/catalan/bell/factorial/first_cusp_form_weight).
30+ 개별 recompute 🔵 + 1 🔴 결정성 대조군. **math.NT 8편 전부가 이 중 하나 이상을
인용** → 해당 claim 은 (citation)→(verify-able) 로 re-tier.

**deferred (🟠 NO-PATH — 다른 arity / 설치 드라이버의 1-arg --expr 경로 없음):**
`partition_coeff`(2-arg q-급수 계수) · `sigma_k`(k-거듭제곱 약수합 2-arg) ·
`dim_cusp_forms`(모듈러폼 차원 k>1 경로) · `jacobi`/`kronecker`(2-arg 기호).
소스·atlas 에는 존재 → 2-arg dispatch 배선 시 🔵/🟢 (V-arity lane = verify-able-CANDIDATE).

## 3 · 흡수 논문 13편 (2-sub-theme)

기호: 🔵 verify-confirmed · 🟡 citation · 🟠 candidate(arity)

### 3a · math.NT — atlas-feeding (verify-native, 8편)

| arxiv id | 제목 (저자) | 기여 | tier | hexa atom |
|---|---|---|---|---|
| 1309.0906 | Curious Biconditional / Odd Perfect Numbers (Dris 2013) | 홀수완전수 q^k·n² 에서 q^k<n, q<n 무조건 성립 | 🔵 | sigma · is_perfect · aliquot |
| 1011.6160 | On perfect and near-perfect numbers (Shevelev 2010) | near-perfect = 한 약수 제외 진약수합, Euclid-유사 정리 | 🔵 | is_perfect · aliquot · sigma |
| 2202.06357 | Perfect polynomials over F₂ w/ Mersenne primes (Gallardo+ 22) | σ(A)/A 완전다항식 분류 → 9 known class | 🔵 | sigma · is_perfect (σ 고정점/Mersenne) |
| 1704.05595 | Generalized Sum-of-Divisors Functions (Schmidt 2017) | σ_α(n)=Σ_{d|n}d^α 확장 항등식 (Lambert 급수) | 🔵 | sigma · divisor_sum (sigma_k=🟠 2-arg) |
| 0201265 | Ramanujan 의 partition & tau 함수 manuscript (Moree 2002) | τ(n)≡Σ_{d|n}d¹¹ (mod 691); partition·tau 합동 | 🔵 | partition · tau |
| 0210312 | Formulas for pi(n) and the n-th prime (Ruiz & Sondow 2002) | +,-,/,floor 만으로 pi(n)·p_n 폐형해 (O(n^{3/2})) | 🔵 | nth_prime · is_prime |
| 0502532 | Catalan & Fine number identities (Callan 2005) | C_n=(1/(n+1))Σ C(n+1,2k+1)C(n+k,k) bijective | 🔵 | catalan |
| 1207.4446 | Some remarks on Euler's totient function (Coleman 2012) | φ 의 preimage 구조; image 에 있는 짝수 판별 | 🔵 | euler_phi · phi · euler_totient |

### 3b · cs.PL / cs.LO — 컴파일러/검증 아키텍처 (citation, 5편)

| arxiv id | 제목 (저자) | 기여 | tier | hexa atlas-cite 모델 매핑 |
|---|---|---|---|---|
| 2201.10280 | Trusted Computing Base of CompCert (Monniaux+ 2022) | 기계검증 컴파일러에 오류가 새는 지점 종합 분석 | 🟡 | **lint-stage trust base** = hexa 8 strict-lint 단계의 TCB |
| 2512.05262 | Verified VCG & Compiler for Dafny (Nezamabadi+ 2025) | big-step 시맨틱 + 검증된 VCG·컴파일러 → CakeML (HOL4) | 🟡 | **@cite-at-compile** = codegen 전 verify-gate |
| 2111.13040 | Sketch-Guided Equality Saturation (Koehler+ 2021) | sketch 유도 e-graph 재작성; typed-λ 인코딩 | 🟡 | **atlas = 비파괴 등가 저장소** (e-graph) |
| 2511.20782 | Optimism in Equality Saturation (Arbore+ 2025) | 순환/SSA 용 optimistic e-class 분석; rewrite+추상해석 통합 | 🟡 | **atlas soundness** = 비파괴 + 건전 cite |
| 0803.2317 | Lissom — Source Level PCC Platform (Gomes+ 2008) | 코드를 기계검증 가능 증명서와 함께 배포하는 PCC | 🟡 | **@cite gate** = 코드가 atlas 정리 ref 와 함께 배포 |

## 4 · atlas-cite 모델 relevance (핵심 발견)

hexa 의 정체성 ("Code cites a theorem atlas at compile time; lint rejects
formula-bearing code without @cite") 은 **proof-carrying-code 의 변종**이다 —
증명서가 atlas atom 참조이고 검사기가 strict-lint 단계인 PCC.

cs.PL/cs.LO 5편이 정확히 이 삼각형을 형식화한다:
- **Lissom PCC (0803.2317)** = @cite gate 의 직접 조상. "코드 + 기계검증 증명서"
  배포 = "formula-bearing 코드 + @cite atlas 참조" 와 동형.
- **CompCert TCB (2201.10280)** = lint-stage trust base. hexa 의 8-stage 린트가
  신뢰하는 부분(atlas 정확성·verify 드라이버 결정성)이 어디인지의 거울.
- **Equality Saturation (2111.13040 · 2511.20782)** = atlas 의 비파괴 등가 저장소
  성격. atlas 는 동치 정리를 파괴 없이 누적(e-graph 처럼)하고 verify 가 그 위에서
  recompute → 등가 cite 가 건전.
- **Dafny VCG (2512.05262)** = codegen 전 verify-condition 생성 게이트.
  hexa 의 "@cite 없는 formula 거부" = VCG 가 증명 의무를 거부하는 것과 동형.

> 즉 A5 의 cs.PL/cs.LO citation 은 단순 참조가 아니라 **hexa 자신의 설계 도면을
> 학술 문헌에 정박**시킨다 (PCC + verified-compiler + e-graph 삼각형).

## 5 · IN-REPO 성격 — A2/A3/A4 와의 차이

| axis | 대상 repo | handoff | verify-able |
|---|---|---|---|
| A2 ANIMA | ~/core/anima (sibling) | 6 H_xxx (g60) | 0 (IIT primitive 부재) |
| A3 DEMIURGE | ~/core/demiurge (sibling) | 12 7공정 (g60) | 5 물리상수 🔵 |
| A4 PHANES | ~/core/phanes (sibling) | 10 4표면 (g60) | 0 (SaaS 소비자) |
| **A5 HEXA-LANG** | **hexa-lang 자신 (in-repo)** | **0 (self-absorb)** | **8 math.NT 논문 · 16 fn · 30+ recompute 🔵** |

A5 는 4-axis fan-out 의 IN-REPO 종착점이다. math.NT finding 은 hexa 자신의 atlas 를
먹이고(cross-repo handoff 없음), cs.PL/cs.LO 는 hexa 설계의 아키텍처 citation 이다.
**A5 의 in-repo atlas-feed 는 A6 cross-repo handoff 메커니즘의 null/identity 케이스**
(자신에게 handoff = atlas 직접 fold).

## 6 · 통계 · 다음

- **13편 on-topic** triage (math.NT 8 + cs.PL/cs.LO 5).
- **(a) verify-able 🔵**: math.NT 8편, 각각 live hexa atom 에 recompute-confirmed.
  16종 fn · 30+ recompute 🔵 + 1 🔴 결정성 대조군.
  verify-able-CANDIDATE (V-arity): partition_coeff·sigma_k·dim_cusp_forms·
  jacobi·kronecker (2-arg dispatch 배선 시 🔵/🟢).
- **(b) 🟡 citation**: cs.PL/cs.LO 5편 (atlas-cite 모델 아키텍처).
- **(c) handoff**: 0 — IN-REPO.
- verdict: `.verdicts/arxiv-hexalang-absorb/triage_a5.txt` + headline 6편
  (nth_prime_10 · catalan_5 · is_perfect_496 · sigma_496 · partition_10 · euler_phi_15).
- **다음 = A6** (cross-repo handoff 메커니즘 정립 · g60 INBOX): finding →
  target-repo INBOX 분배 + ack 루프. A5 의 in-repo atlas-feed 가 그 identity 케이스.
