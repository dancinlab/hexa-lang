# MR1 — Euclid–Euler 대응 (짝완전수 ⟺ 2^{p−1}·M_p)

**축 B · MERSENNE · MR1 (synthesis 마일스톤)**
2026-05-25 closure

---

## 1 · 정리 (statement)

> **Euclid–Euler 정리**: 짝수 자연수 n 이 완전수(σ(n) = 2n) 일 필요충분조건은
> n 이 다음 형태를 가지는 것이다.
>
> $$
>   n \;=\; 2^{p-1}\,(2^{p} - 1), \quad \text{단, } M_p := 2^{p}-1 \text{ 는 메르센 소수.}
> $$

- **충분성** (Euclid, *원론* IX.36, 기원전 c. 300년): 2^p − 1 이 소수이면
  2^{p−1}·(2^p − 1) 은 완전수.
- **필요성** (Euler, 1849 유고 *De numeris amicabilibus*): 모든 *짝* 완전수는
  위 형태로 유일 분해된다.
- **홀수 완전수**의 존재 여부는 **미해결**(open). 알려진 모든 search 는 < 10^{1500}
  영역에서 부재(Ochem–Rao 2012). 본 MR1 범위 밖 → TECS-L 축 B **MR7** 로 이월
  (🟠 deferred · honest scope).

본 마일스톤은 **새 산술 verify 를 도입하지 않는다.** 첫 7 개 완전수에 대한
모든 atom (`is_perfect`·`sigma`·`tau`·Lucas–Lehmer)이 축 0 (M5, M6) 과 축 B
(MR2, MR4, MR5, MR6) 에서 이미 🔵 SUPPORTED-FORMAL 로 영속화돼 있으므로,
MR1 은 그 atom 들을 **하나의 통합 statement + cross-reference 표** 로
synthesize 하는 닫힘 마일스톤이다 (M10 닫힌형 증명 패턴과 동일).

---

## 2 · 첫 7 짝완전수 대응 표

| k | p  | M_p = 2^p − 1 | P_k = 2^{p−1}·M_p | τ(P_k) = 2p |
|---|----|---------------|-------------------|-------------|
| 1 |  2 | 3             | 6                 | 4           |
| 2 |  3 | 7             | 28                | 6           |
| 3 |  5 | 31            | 496               | 10          |
| 4 |  7 | 127           | 8128              | 14          |
| 5 | 13 | 8191          | 33550336          | 26          |
| 6 | 17 | 131071        | 8589869056        | 34          |
| 7 | 19 | 524287        | 137438691328      | 38          |

> 다음 메르센 지수는 p=31 → P_8 = 2305843008139952128. 본 MR1 의 재계산 범위 밖.

---

## 3 · g5 anchor 교차참조 (per-P_k atom slugs)

각 P_k 의 세 가지 핵심 성질 (`is_perfect`·`σ = 2n`·`τ = 2p`) 이 어느 slug 의
어느 verdict 파일에서 🔵 로 영속화돼 있는지 1:1 로 표기. (Lucas–Lehmer 는
M_p 의 소수성 자체에 대응되며, p ∈ {3,5,7,13} 에 대해 MR4 에서 영속화됨.)

| P_k | `is_perfect` | `σ=2n` (abundancy) | `τ=2p` | Lucas–Lehmer |
|-----|--------------|---------------------|--------|---------------|
| **P_1 = 6**            | M4 `tecs-l-n6-characterizations/n6_is_perfect.txt` | M6 `tecs-l-hypotheses/hyp_abundancy_6.txt` | MR5 `tecs-l-mersenne-tau-2p/tau_p1.txt` | (p=2; LL trivial) |
| **P_2 = 28**           | M1 `tecs-l-n6-identity/n28_isperfect.txt`         | M6 `tecs-l-hypotheses/hyp_abundancy_28.txt` | MR5 `tecs-l-mersenne-tau-2p/tau_p2.txt` | (p=3 → MR4 `ll_p3_is_perfect.txt`) |
| **P_3 = 496**          | M5 `tecs-l-physics-constants/perfect_496.txt`     | M6 `tecs-l-hypotheses/hyp_abundancy_496.txt` | MR5 `tecs-l-mersenne-tau-2p/tau_p3.txt` | p=5 → MR4 `ll_p5_is_perfect.txt` |
| **P_4 = 8128**         | M5 `tecs-l-physics-constants/perfect_8128.txt`    | M6 `tecs-l-hypotheses/hyp_abundancy_8128.txt` | MR5 `tecs-l-mersenne-tau-2p/tau_p4.txt` | p=7 → MR4 `ll_p7_is_perfect.txt` |
| **P_5 = 33550336**     | M5 `tecs-l-physics-constants/perfect_33m.txt`     | M6 `tecs-l-hypotheses/hyp_abundancy_33m.txt`  | MR5 `tecs-l-mersenne-tau-2p/tau_p5.txt` | p=13 → MR4 `ll_p13_is_perfect.txt` |
| **P_6 = 8589869056**   | MR2 `tecs-l-mersenne-perfect/is_perfect_p6.txt`   | MR2 `tecs-l-mersenne-perfect/sigma_p6.txt`    | MR5 `tecs-l-mersenne-tau-2p/tau_p6.txt` | (p=17; LL 미수행 — 정수론 인용) |
| **P_7 = 137438691328** | MR2 `tecs-l-mersenne-perfect/is_perfect_p7.txt`   | MR2 `tecs-l-mersenne-perfect/sigma_p7.txt`    | MR5 `tecs-l-mersenne-tau-2p/tau_p7.txt` | (p=19; LL 미수행 — 정수론 인용) |

**M_p 의 약수 구조** (`τ = 2p` 닫힌형의 근거):
짝완전수 P_k = 2^{p−1}·M_p (M_p 소수) 의 약수는 2^a · M_p^b
(0 ≤ a ≤ p−1, b ∈ {0,1}) 형태로 정확히 (p) × (2) = 2p 개. MR5 의 닫힌형 framing
은 이 사실의 형식화이며, 첫 7 개 P_k 에 대해 τ(P_k) = 4, 6, 10, 14, 26, 34, 38
이 측정과 일치 (🔵 7/7).

---

## 4 · 역명제는 거짓 — p 소수 ⇏ M_p 소수

Euclid–Euler 의 **양방향 동치**는 짝완전수 ↔ (2^{p−1}·M_p with **M_p prime**)
이지, *모든 소수 p* 가 완전수를 생성한다는 것이 아니다. 첫 반례:

- **M_11 = 2047 = 23 · 89** (composite, σ=2160 ≠ 2048, τ=4 ≠ 2)
- M_23 = 8388607 = 47 · 178481 (τ=4)
- M_29 = 536870911 = 233·1103·2089 (τ=8)

→ 모두 **MR6** slug `tecs-l-mersenne-composite` 에서 🔵 영속화. 이로써
"p prime ⇒ M_p prime" 은 닫힌 거짓 — Lucas–Lehmer (MR4) 같은 별도 소수성
판정이 필수임이 정리에 의해 강제된다.

---

## 5 · 정직한 범위 (honest scope) · 잔여

- 본 MR1 의 표는 **첫 7 개 짝완전수**에 한정 — 더 큰 M_p (p=31, 61, 89, …)
  는 정수론적으로 알려져 있으나 본 시점 hexa-native recompute 범위 밖. 추후
  MR-N 라운드에서 atlas fold + verify 확장 가능 (영구 축의 특성).
- **홀수 완전수**: 존재 여부 미해결 (open since Euclid). 알려진 부재 한계
  10^{1500} (Ochem–Rao 2012). 정직한 🟠 deferred → **MR7** 마일스톤으로
  분리 보존 (over-claim 금지, `@D paper_significance` 준수).
- **finite enumeration ≠ 전칭 증명**: 본 MR1 은 첫 7 P_k 의 명시적 표 와
  정리의 statement 를 통합하는 reasoned-synthesis 닫힘이다. Euclid–Euler
  자체의 형식 증명 (Euler 1849 의 elementary divisor 논증) 은 표준 정수론
  교과서를 인용 — hexa atlas 의 다음 라운드에서 atom fold 후보.

---

## 6 · synthesis verdict

- **Tier** = 🟢 SUPPORTED-NUMERICAL (synthesis · cross-reference)
- **Method** = 기존 🔵 atom 들 위의 reasoned synthesis (신규 산술 verify 없음)
- **Artifact** = `.verdicts/tecs-l-mersenne-euclid-euler/euclid_euler_statement.txt`
- **CLAIMS** = 1 @C entry under `[slug=tecs-l-mersenne-euclid-euler group=TECS-L]`
- **paper-eligible** = 후속 MR8 paper 승격 시 본 MR1 표가 §statement + §finding
  핵심 표로 그대로 재사용 가능 (M7 closed-negative 패턴과 동일).
