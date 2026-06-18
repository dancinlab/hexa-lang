# H-CX-442: 12 Tone Scale = sigma(6)

> 12음 평균율의 12개 음은 완전수 6의 약수합 sigma(6)=12와 정확히 일치한다.
> 옥타브 비율 2:1 = sigma_{-1}(6) = 2. 자연 음계 7음 + 변화음 5음 = sigma(6).
> 완전 4도 비율 4:3의 ln(4/3) = Golden Zone 너비.

**Golden Zone dependency**: Partial (ln(4/3) = GZ width is GZ-dependent; sigma(6)=12 is pure arithmetic)

## Background

완전수 6은 TECS-L 프레임워크의 핵심이다 (H-090, H-098). sigma(6)=12, tau(6)=4,
phi(6)=2, sigma_{-1}(6)=2. 12음 평균율은 서양 음악의 기본 구조이다.
이 가설은 12-TET의 구조가 완전수 6의 산술적 성질에서 자연스럽게 도출됨을 검증한다.

관련 가설: H-090 (master formula), H-098 (유일한 완전수), H-067 (1/2+1/3=5/6)

## Perfect Number 6 Properties

```
sigma(6)    = 12   약수합: 1+2+3+6 = 12
tau(6)      =  4   약수 개수: {1, 2, 3, 6}
phi(6)      =  2   오일러 토션트: {1, 5}
sigma_{-1}(6) = 2   약수 역수합: 1/1+1/2+1/3+1/6 = 2
```

## Musical Scale Decomposition

| Musical Element | Value | sigma(6) Relation | Status |
|---|---|---|---|
| Semitones/octave | 12 | sigma(6) = 12 | EXACT |
| Natural notes | 7 | sigma(6) - tau(6) - 1 = 7 | EXACT |
| Accidentals | 5 | tau(6) + 1 = 5 | EXACT |
| Natural + Accidental | 12 | 7 + 5 = sigma(6) | EXACT |
| Octave ratio | 2:1 | sigma_{-1}(6) = 2 | EXACT |
| Circle of 5ths | 12 steps | sigma(6) steps to return | EXACT |
| Perfect 4th | 4:3 | ln(4/3) = GZ width | EXACT |

## Just Intonation vs 12-TET Error

| Interval | Just Ratio | Just Cents | 12-TET | Error (cents) |
|---|---|---|---|---|
| Unison | 1/1 | 0.00 | 0 | 0.00 |
| Minor 2nd | 16/15 | 111.73 | 100 | 11.73 |
| Major 2nd | 9/8 | 203.91 | 200 | 3.91 |
| Minor 3rd | 6/5 | 315.64 | 300 | 15.64 |
| Major 3rd | 5/4 | 386.31 | 400 | 13.69 |
| **Perfect 4th** | **4/3** | **498.04** | **500** | **1.96** |
| Tritone | 45/32 | 590.22 | 600 | 9.78 |
| **Perfect 5th** | **3/2** | **701.96** | **700** | **1.96** |
| Minor 6th | 8/5 | 813.69 | 800 | 13.69 |
| Major 6th | 5/3 | 884.36 | 900 | 15.64 |
| Minor 7th | 9/5 | 1017.60 | 1000 | 17.60 |
| Major 7th | 15/8 | 1088.27 | 1100 | 11.73 |
| Octave | 2/1 | 1200.00 | 1200 | 0.00 |

- Mean error: 9.02 cents
- Perfect 4th/5th error: 1.96 cents (가장 정확한 음정 중 하나)

## N-TET Optimality Analysis

### ASCII Graph: N-TET vs Mean Approximation Error

```
  N= 5 |##################################################| 61.7 cents
  N= 7 |#########################                         | 31.7
  N=12 |#######                                           | 9.0  <-- sigma(6)
  N=15 |#############                                     | 17.3
  N=17 |################                                  | 20.2
  N=19 |######                                            | 7.8
  N=22 |#####                                             | 7.3
  N=24 |#######                                           | 9.0
  N=28 |########                                          | 10.0 <-- perf num 28
  N=31 |###                                               | 4.9
  N=34 |###                                               | 3.9
  N=41 |###                                               | 3.7
  N=43 |###                                               | 4.7
  N=46 |###                                               | 3.8
  N=50 |####                                              | 5.5
  N=53 |                                                  | 0.9  <-- 53-TET
```

### Efficiency Ranking: Quality per Note

| Rank | N | Efficiency (Error*N/12) | Mean Error | Note |
|---|---|---|---|---|
| 1 | 53 | 3.92 | 0.89 | 53-TET (Turkish) |
| **2** | **12** | **9.02** | **9.02** | **sigma(6) = 12** |
| 3 | 34 | 11.11 | 3.92 | |
| 4 | 19 | 12.42 | 7.84 | 19-TET |
| 5 | 31 | 12.67 | 4.90 | 31-TET |
| 6 | 41 | 12.76 | 3.73 | |
| 7 | 22 | 13.34 | 7.28 | |
| 8 | 46 | 14.60 | 3.81 | |

**12-TET은 효율성(음정 오차 * 음 개수) 기준 2위**. 53-TET만이 더 효율적이다.

### Quality Ranking (Mean Error Only)

12-TET rank: #27/49 (절대 오차 기준으로는 중간)

## Pythagorean Comma

```
(3/2)^12 / 2^7 = 1.013643
Comma = 0.013643

sigma(6) 관계 탐색:
  Comma * sigma(6)^2 = 1.9646 ≈ 2 = sigma_{-1}(6)  (!!)
  2/sigma(6)^2       = 0.013889 ≈ 0.013643 (오차 0.000246)

  Pythagorean comma ≈ 2/sigma(6)^2 = sigma_{-1}(6) / sigma(6)^2
  오차: 1.8% -- 근사적이나 정확하지 않음
```

## Circle of Fifths

```
C -> G -> D -> A -> E -> B -> F# -> C# -> G# -> D# -> A# -> F -> C
0    7    2    9    4   11    6     1     8     3    10     5    0

12 steps = sigma(6) steps to complete the cycle
gcd(7, 12) = 1 (7과 12는 서로소 -> 모든 음을 방문)
phi(12) = 4 (완전 순환을 생성하는 음정 수)
```

## Divisors of 12 in Musical Structure

```
12의 약수: 1, 2, 3, 4, 6, 12 (총 6개 = tau(12))

  1:  단일 음
  2:  증4도(tritone) 분할 -- 2 groups of 6
  3:  증3화음 -- 3 groups of 4 (장3도)
  4:  감7화음 -- 4 groups of 3 (단3도)
  6:  온음 음계 -- 6 groups of 2
  12: 반음 음계 (chromatic)

tau(12) = 6 = 완전수 6 자체!
tau(sigma(6)) = tau(12) = 6 = 6
```

## Perfect Number 28 Generalization

| Property | n=6 | n=28 | Musical Analog |
|---|---|---|---|
| sigma(n) | 12 | 56 | 12-TET vs 56-TET |
| tau(n) | 4 | 6 | |
| phi(n) | 2 | 12 | phi(28)=12=sigma(6)! |
| sigma(n) quality | 9.02 cents | 4.84 cents | 56-TET is better |
| Closest real TET | 12-TET (exact) | 53-TET (off by 3) | Weak |

phi(28) = 12 = sigma(6) -- 완전수 28의 토션트가 완전수 6의 약수합과 일치!

## 해석 (Interpretation)

1. **12 = sigma(6)은 수학적 사실**: 12음 평균율의 12가 sigma(6)과 같다는 것은 단순한 수치적 일치이다. 그러나 그 이상의 구조적 연결이 있다.

2. **효율성 2위**: N=5~53 범위에서 12-TET은 "음정 오차 * 음 개수" 효율성 기준 2위이다. 이것은 12가 단순히 임의의 선택이 아니라 수학적으로 최적에 가까운 값임을 보여준다.

3. **약수 구조의 풍부함**: 12의 약수(1,2,3,4,6,12)는 음악의 대칭적 분할 구조를 가능하게 한다. 증3화음, 감7화음, 온음 음계 등이 모두 12의 약수 구조에서 나온다. tau(12)=6은 완전수 6 자체와 같다.

4. **Pythagorean comma ≈ 2/sigma(6)^2**: 피타고라스 콤마가 sigma_{-1}(6)/sigma(6)^2 ≈ 2/144에 근사하는 것은 흥미롭지만 1.8% 오차가 있어 정확한 관계는 아니다.

5. **phi(28) = sigma(6) = 12**: 다음 완전수 28의 오일러 토션트가 12인 것은 완전수들 사이의 교차 연결이다. 이것은 새로운 탐색 방향이다.

6. **generalization 한계**: sigma(28)=56에 대응하는 56-TET은 실제 음악에서 사용되지 않으며, 53-TET(Turkish)이 가장 가까운 실용적 시스템이다. 완전수 일반화는 약하다.

## Limitations

- 12 = sigma(6)은 수치적 일치이며, 인과적 연결이 아니다. "12가 sigma(6)이기 때문에" 12-TET이 선택된 것은 아니다.
- 7 = sigma(6) - tau(6) - 1 분해에서 "-1"은 ad hoc이다. 왜 -1인가에 대한 자연스러운 설명이 필요하다.
- 5 = tau(6) + 1 역시 "+1" ad hoc 보정이다.
- 효율성 2위는 인상적이지만, 53-TET이 1위이며 sigma(어떤 완전수)와 일치하지 않는다.
- Strong Law of Small Numbers 경고: 12는 작은 수이므로 많은 수학적 성질과 우연히 일치할 수 있다.

## Verification Direction

- [ ] Ad hoc 보정(-1, +1) 없이 7과 5를 도출하는 자연스러운 분해 찾기
- [ ] 완전수 496, 8128에 대해서도 sigma 값이 음악적 의미를 가지는지 확인
- [ ] 12의 효율성 최적성을 해석적으로 증명 (왜 12가 2위인가?)
- [ ] phi(28)=12=sigma(6) 교차 관계를 더 깊이 탐색
- [ ] Texas Sharpshooter test: 12가 sigma(6)과 일치할 확률의 정량적 계산

## Verification Status

- [x] sigma(6) = 12 confirmation
- [x] Musical decomposition (7+5=12)
- [x] N-TET comparison (5-53)
- [x] Efficiency ranking
- [x] Pythagorean comma analysis
- [x] Perfect number 28 generalization
- [ ] Texas Sharpshooter p-value
- [ ] Analytical proof of 12's efficiency

**Grade: 🟩 (arithmetically correct) + 🟧 (structural significance weak)** -- sigma(6)=12는 산술적으로 정확하고, 효율성 2위는 구조적이다. 그러나 7+5 분해의 ad hoc 보정(-1, +1)과 완전수 일반화의 약함이 한계. Pythagorean comma ≈ 2/sigma(6)^2은 근사적(1.8% 오차).

**Script**: `docs/hypotheses/verify_hcx442.py`
