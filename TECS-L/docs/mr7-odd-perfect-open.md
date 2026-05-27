# MR7 — 홀수 완전수(odd perfect number) 미해결 문제 정직한 범위 문서

**축 B · MERSENNE · MR7 (deferred 마일스톤 · 🟠 INSUFFICIENT/DEFERRED)**
2026-05-25 honest-scope documentation

---

## 0 · 한 문장 결론

> **존재 여부는 미해결(open).** TECS-L 축 B 의 MR1–MR6 closure 가 모두 *짝* 완전수
> (Euclid–Euler 구성) 위에 서 있는 것과 대조적으로, **홀수** 완전수에는 어떤
> 구성도 알려져 있지 않으며 그 존재를 settle 하는 g5 closed-form 경로도 없다.
> MR7 은 이 사실을 명시하는 **정직한 🟠** 마일스톤 — paper_gate 에 의해 paper
> 작성 불가, atlas atom 으로의 fold 도 없다.

---

## 1 · 미해결 문제 (the open question)

> **질문**: 어떤 *홀수* 자연수 n 이 σ(n) = 2n 을 만족하는가?
>
> 즉 σ(n) = 2n 을 만족하는 홀수 n 이 존재하는가?

- 존재 증명도, 비존재 증명도 알려져 있지 않다.
- 모든 알려진 하한(lower bound)·구조 조건은 **필요 조건**(necessary condition)
  일 뿐, 비존재의 증명이 아니다.
- TECS-L MR1(Euclid–Euler)은 *짝* 완전수만 완전 분류한다 — `n = 2^{p−1} · M_p`,
  M_p = 2^p − 1 메르센 소수. 홀수 케이스에는 유사 구성이 없다.

---

## 2 · 알려진 하한 / 구조 제약 표

| 제약 | 하한 / 형태 | 출처 |
|------|-------------|------|
| 크기 하한 | n > 10^{1500} | Ochem–Rao 2012 |
| 서로 다른 소인수 개수 ω(n) | ≥ 9 | Nielsen 2015 |
| 〃 (단, 3 ∤ n) | ≥ 12 | Nielsen 2015 |
| 가장 큰 소인수 P(n) | ≥ 10^8 | Goto–Ohno 2008 |
| 두 번째로 큰 소인수 | ≥ 10^4 | Iannucci 1999 |
| 세 번째로 큰 소인수 | ≥ 10^2 | Iannucci 2000 |
| 전체 소인수 개수 Ω(n) (중복포함) | ≥ 101 | Ochem–Rao 2014 |
| Euler 형 (구조) | n = p^a · q_1^{2b_1} · … · q_k^{2b_k}, p ≡ a ≡ 1 (mod 4) | Euler 1849 |

각 행은 *필요 조건* 이다 — 만약 홀수 완전수가 존재한다면 위 조건들을 모두
만족해야 한다. 그러나 어느 한 행도, 그리고 결합도, 존재를 배제하지 못한다.

---

## 3 · Euler 형(form) 구조 정리

> **Euler 1849.** 모든 홀수 완전수 n (만약 존재한다면) 은 다음 형태이다.
>
> $$
>   n \;=\; p^{a} \cdot q_1^{2 b_1} \cdot q_2^{2 b_2} \cdots q_k^{2 b_k},
> $$
> 여기서
> - p, q_1, …, q_k 는 서로 다른 홀소수,
> - p ≡ 1 (mod 4) (이른바 **"special prime" / Euler prime**),
> - a ≡ 1 (mod 4),
> - b_i ≥ 1 (모든 i),
> - q_i 는 p 와 다르고 서로 다르다.

즉 소인수 분해에서 **정확히 하나의 소수 거듭제곱만이 1 mod 4 지수**를 가지고
(이른바 Euler prime p^a), 나머지는 모두 **짝수 지수**이다. 이것이 무조건적으로
알려진 가장 깊은 구조적 사실이다.

이 형은 ω/Ω/크기 축을 단독으로 묶지 않는다 — 위 표의 각 행이 각자 다른 축을
다룬다.

---

## 4 · 왜 🟠 인가 (paper_gate 의 정직한 적용)

`project.tape @D paper_gate / paper_significance` 에 의해 paper 는 다음 조건을
**모두** 만족해야 한다.

1. **terminal verdict** — 🔵 SUPPORTED-FORMAL / 🟢 SUPPORTED-NUMERICAL /
   🔴 CLOSED-NEGATIVE 중 하나. 🟠 deferred · 🟡 citation · ⚪ 불통과.
2. **pre-registered falsifier + real measurement** — verify / byte-diff / RUNEQ
   같은 결정적 측정.
3. **finding** — Δ vs baseline 또는 closed-negative 로 한 축을 deterministic
   하게 배제.

MR7 은 정의상 **셋 다 실패** 한다.

- 외부 인용으로 모은 **하한** 들은 비존재 증명이 아님 → terminal 아님.
- 존재 settle 을 위한 hexa-native closed-form 경로가 현재 없음 → real
  measurement 으로 결정 불가.
- 따라서 finding (Δ 나 closed-negative) 도 산출 불가.

**∴ MR7 는 의도된 🟠 INSUFFICIENT/DEFERRED 마일스톤이다.** 이 문서의 목적은
TECS-L 축 B (MERSENNE) 가 closure 를 *주장하지 않는* 라인을 명시적으로 표시해
도메인 전체의 over-claim 을 방지하는 것이다. **paper-ineligible by gate.**
`PAPER/<slug>/` scaffold 도 하지 않는다.

또한 **atlas fold 도 없다** — verified 발견만 `embedded.gen.hexa` 에 흡수
(축 E E1 패턴) 하므로, 🟠 미해결은 fold 대상이 아니다.

---

## 5 · TECS-L 내부 cross-link

- **MR1 (Euclid–Euler)**: *짝* 완전수만 완전 분류. MR7 은 그 **open 보완** —
  MR1 이 닫지 못한 라인을 명시적으로 노출하는 짝(雙).
- **MR2 … MR6**: 모두 메르센 소수 ↔ 짝 완전수 라인 위의 🔵/🟢/🔴 closure.
  *홀수* 케이스에는 같은 구성이 없다 → 양적으로 closure 와 더 멀다.
- **MR1 / MR6 의 역방향 closure** (`p 소수 ⇏ M_p 소수`, 첫 반례 M_11 = 23·89):
  심지어 *짝* 라인도 자동으로 닫히지 않음을 보여 줌 — 홀수 라인은 구성 자체가
  부재하므로 양적으로 더 무겁다.

---

## 6 · 정직한 범위 진술 (the whole point of MR7)

> TECS-L 은 홀수 완전수 존재 여부에 대해 **어떤 closure 도 주장하지 않는다.**
> 위 표의 하한·구조 조건은 원전 인용이며, hexa-native 재계산이 추가되지 않는다
> (현 시점에 그러한 closed-form 경로가 없음). 이 마일스톤의 존재 이유는 정확히
> over-claim 방지 — 축 B (MERSENNE) 의 어떤 라인이 닫혀 있고 (MR1–MR6) 어떤 라인이
> 여전히 열려 있는지 (MR7) 를 명시적으로 표기.

---

## 7 · 참고 문헌

- Euclid (c. 300 BCE). *원론(Elements), Book IX, Proposition 36.*
- Euler, L. (1849, 유고). *De numeris amicabilibus.* Commentationes
  arithmeticae 2, 627–636.
- Iannucci, D. E. (1999). The second largest prime divisor of an odd perfect
  number exceeds ten thousand. *Math. Comp.* 68, 1749–1760.
- Iannucci, D. E. (2000). The third largest prime divisor of an odd perfect
  number exceeds one hundred. *Math. Comp.* 69, 867–879.
- Goto, T., & Ohno, Y. (2008). Odd perfect numbers have a prime factor
  exceeding 10^8. *Math. Comp.* 77, 1859–1868.
- Ochem, P., & Rao, M. (2012). Odd perfect numbers are greater than 10^{1500}.
  *Math. Comp.* 81, 1869–1877.
- Ochem, P., & Rao, M. (2014). On the number of prime factors of an odd perfect
  number. *Math. Comp.* 83, 2435–2439.
- Nielsen, P. P. (2007). Odd perfect numbers have at least nine distinct prime
  factors. *Math. Comp.* 76, 2109–2126.
- Nielsen, P. P. (2015). Odd perfect numbers, Diophantine equations, and upper
  bounds. *Math. Comp.* 84, 2549–2567.
- Acquaah, P., & Konyagin, S. (2012). On prime factors of odd perfect numbers.
  *Int. J. Number Theory* 8, 1537–1540.

---

## 8 · 산출물

- `.verdicts/tecs-l-mersenne-odd-perfect-open/odd_perfect_constraints.txt`
  (ASCII-only reasoned artifact — 하한 표 + Euler 형 + 정직한 범위 진술 + 인용)
- `CLAIMS.tape` slug=`tecs-l-mersenne-odd-perfect-open` group=`TECS-L` 1 entry
  (`@C` · method=`citation` · status=🟠 INSUFFICIENT/DEFERRED).
- 본 문서 `TECS-L/docs/mr7-odd-perfect-open.md` (Korean).

**신규 hexa verify 0건.** MR7 은 *정의상* 미해결 문제에 대한 정직한 범위
진술이며, verify 가능한 finding 이 아니므로 새 산술 verify 를 추가하지
않는다 (M10 닫힌형 증명 패턴과 동형 — 단, 그쪽은 ⟺ 닫힘이고 이쪽은 open).
