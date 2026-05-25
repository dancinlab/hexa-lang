# TECS-L 축 B MR3 — abundancy σ(P)=2P 닫힌형 도출

> Euclid–Euler 짝완전수 `P = 2^{p-1}·M_p` (단, `M_p = 2^p − 1` 메르센 소수) 에 대해
> `σ(P) = 2P` 가 성립함을 4단 초등 정수론 논증으로 닫힌형 도출하고, 이미 🔵
> 처리된 7개 완전수 `σ(P_k)=2P_k` 원자(atom)를 한 표로 anchor 한다.
>
> **method = synthesis / reasoned** — 새 산술 verify 는 추가하지 않는다
> (MR2·축 0 M6 가 이미 산출한 🔵 원자만 인용). 도출은 그 원자들이 닫힌형의
> 인스턴스임을 명시적으로 결합한다.

---

## 1. 명제 (Statement)

소수 `p` 에 대해 `M_p = 2^p − 1` 이 메르센 소수일 때
`P = 2^{p-1} · M_p` (Euclid–Euler 짝완전수) 의 약수합은

```
σ(P) = 2P,   즉 abundancy(P) = σ(P)/P = 2.
```

이것이 곧 "P 가 완전수" 의 정의이다.

---

## 2. 도출 (Derivation, 4 단계 초등 논증)

### S1 — σ 의 multiplicative 성질

`σ` (약수합) 은 multiplicative arithmetic function 이다.
즉 `gcd(a, b) = 1 ⟹ σ(a·b) = σ(a)·σ(b)` (Hardy & Wright, Thm 273
등 표준 결과).

### S2 — `gcd(2^{p-1}, M_p) = 1`

- `2^{p-1}` 은 순수 2-멱.
- `M_p = 2^p − 1` 은 짝수에서 1을 뺀 값이므로 홀수.
- 따라서 공통 약수는 1뿐 → 서로소.

이로써 S1 이 `a = 2^{p-1}`, `b = M_p` 에 적용 가능하다.

### S3 — 소수 멱의 σ

```
σ(q^k) = (q^{k+1} − 1) / (q − 1)   (q 소수)
```

`q = 2`, `k = p−1` 을 대입:

```
σ(2^{p-1}) = (2^p − 1) / (2 − 1) = 2^p − 1 = M_p.
```

### S4 — 소수의 σ

```
σ(r) = r + 1   (r 소수)
```

가정상 `M_p` 가 메르센 소수이므로:

```
σ(M_p) = M_p + 1 = (2^p − 1) + 1 = 2^p.
```

### 종합

S1 (서로소 곱) + S2 (서로소 검증) + S3·S4 (각 인자의 σ) 결합:

```
σ(P) = σ(2^{p-1} · M_p)
     = σ(2^{p-1}) · σ(M_p)          [S1, S2]
     = M_p · 2^p                    [S3, S4]
     = (2^p − 1) · 2^p
     = 2 · ( 2^{p-1} · (2^p − 1) )
     = 2 · 2^{p-1} · M_p
     = 2P.                                                ∎
```

따라서 `abundancy(P) = σ(P) / P = 2`, 즉 `P` 는 완전수이다.

---

## 3. 7 완전수 anchor 표 (P₁..P₇)

아래 모든 `σ(P_k)` 값은 이미 `hexa verify --expr sigma <P> <2P>` 가
실측해서 raw verdict 로 영구화한 🔵 SUPPORTED-FORMAL 원자이다. MR3 는
이 원자들이 §2 닫힌형의 인스턴스임을 명시하는 reasoned synthesis 일 뿐
**새 산술 verify 는 추가하지 않는다**.

| p   | M_p     | P_k = 2^{p-1}·M_p | σ(P_k) = 2·P_k | verdict 경로                                                          | 출처     |
| --- | ------- | ----------------- | -------------- | --------------------------------------------------------------------- | -------- |
| 2   | 3       | 6                 | 12             | `.verdicts/tecs-l-hypotheses/abundancy_sigma6.txt`                    | 축 0 M6 |
| 3   | 7       | 28                | 56             | `.verdicts/tecs-l-hypotheses/abundancy_sigma28.txt`                   | 축 0 M6 |
| 5   | 31      | 496               | 992            | `.verdicts/tecs-l-hypotheses/abundancy_sigma496.txt`                  | 축 0 M6 |
| 7   | 127     | 8128              | 16256          | `.verdicts/tecs-l-hypotheses/abundancy_sigma8128.txt`                 | 축 0 M6 |
| 13  | 8191    | 33 550 336        | 67 100 672     | `.verdicts/tecs-l-hypotheses/abundancy_sigma33m.txt`                  | 축 0 M6 |
| 17  | 131 071 | 8 589 869 056     | 17 179 738 112 | `.verdicts/tecs-l-mersenne-perfect/sigma_p6.txt`                      | 축 B MR2 |
| 19  | 524 287 | 137 438 691 328   | 274 877 382 656| `.verdicts/tecs-l-mersenne-perfect/sigma_p7.txt`                      | 축 B MR2 |

각 행에 닫힌형 `(2^p − 1) · 2^p` 을 대입해 보면 정확히 표의 `σ(P_k)` 칸과
일치한다 (verdict artifact `.verdicts/tecs-l-mersenne-abundancy-closed/
abundancy_closed_form.txt` 에 검산표 동봉).

---

## 4. 정직한 범위 (Honest scope)

- 본 도출은 **짝(even) 완전수** 만 다룬다 (Euclid–Euler form `2^{p-1}·M_p`).
- Euler (1747) 는 그 역 — *모든 짝 완전수는 이 형태* — 도 증명했다. 따라서
  §2 와 Euler 의 정리를 합치면 짝 완전수는 완전 분류된다.
- **홀(odd) 완전수** 의 존재 여부는 **미해결 open problem** 이다. 발견된
  바도, 불가능성도 증명된 바 없다. MR3 는 이에 대해 어떤 주장도 하지
  않는다 — 별도 마일스톤 **축 B MR7** 에서 🟠 INSUFFICIENT/DEFERRED 로
  정직하게 fence.

---

## 5. 축 cross-reference

- **축 0 M5/M6** — 첫 5 완전수 (6·28·496·8128·33550336) 의 abundancy=2
  원자 (표의 1–5 행).
- **축 B MR2** (slug `tecs-l-mersenne-perfect`) — 6·7 번째 완전수
  (P₆·P₇) 로 확장: `is_perfect(P_k)=1` + `σ(P_k)=2P_k` 두 양식 모두
  🔵 (표의 6–7 행).
- **축 B MR5** (slug `tecs-l-mersenne-tau-2p`) — 같은 7 완전수에 대한
  자매 닫힌형 `τ(P) = 2p` (약수 개수 도출, `2^a · M_p^b` factor 격자
  `a∈[0,p-1], b∈{0,1} ⟹ p·2 = 2p`). σ 닫힌형 (이 문서) 과 자연
  대칭쌍을 이룬다.
- **축 B MR6** (slug `tecs-l-mersenne-composite`) — 반례 `M_11 = 2047
  = 23·89` 가 `p 소수 ⟹ M_p 소수` 명제를 부정 (Euclid–Euler 역명제
  실패). 이는 §2 도출이 *`M_p` 가 실제로 소수임* 을 가설로 요구하는
  이유 — 모든 소수 지수 `p` 가 완전수를 낳지는 않음 — 을 정직하게
  설명한다.

---

## 6. Status

🟢 **reasoned** — 도출은 초등 정수론 (σ multiplicativity + `gcd(2^{p-1},
M_p) = 1` + 소수 멱·소수 σ 공식) 만 사용. 7 numerical 인스턴스는 모두
이미 🔵 영구화된 원자. 본 문서 + verdict artifact 는 그 원자들을 닫힌형
에 묶는 synthesis 기록이다 — **새 verify 명령은 없다**.

CLAIMS slug = `tecs-l-mersenne-abundancy-closed` · 1 entry
verdict path = `.verdicts/tecs-l-mersenne-abundancy-closed/abundancy_closed_form.txt`
