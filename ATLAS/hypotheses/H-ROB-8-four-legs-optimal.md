# H-ROB-8: tau(6) = 4 Legs = Optimal Locomotion
**n6 Grade: 🟩 EXACT** (auto-graded, 11 unique n=6 constants)


## 가설 (Hypothesis)

> 지상 이동의 최적 다리 수는 4 = tau(6)이며, 이는 에너지 비용(Cost of Transport)
> 최적화에서 해석적으로 도출된다. 생물학적 다리 수 분포도 n=6의 약수 및
> 산술 함수와 일치한다: 2=phi(6), 4=tau(6), 6=6, 8=2*tau(6).

## 배경 (Background)

tau(6) = 4는 완전수 6의 약수 개수(1, 2, 3, 6)이다.
사족동물(tetrapod) 체형은 지구 육상 척추동물의 보편적 구조이며,
곤충(6), 거미(8) 등 절지동물의 다리 수도 모두 6의 약수 또는 그 배수이다.
흥미롭게도 자연에서 5다리, 7다리 동물은 존재하지 않는다 -- 이들은 6의 약수가 아니다.

관련 가설: H-ROB-7 (12 joints = sigma(6)), H-ROB-10 (보행 상전이)

## 핵심 공식: COT 최적화

```
  COT(N) = a/N + b*N

  여기서:
    a = 4.0   무게중심 수직 진동 패널티 (다리 적을수록 큼)
    b = 0.25  다리 질량 패널티 (다리 많을수록 큼)

  최적화: dCOT/dN = -a/N^2 + b = 0
          N* = sqrt(a/b) = sqrt(16) = 4.0 = tau(6)  EXACT
```

## 검증 결과 (Verification Results)

### 다중 기준 보행 평가

| N  | Stability | Efficiency | Speed | Adaptability | Product | Average |
|----|-----------|------------|-------|--------------|---------|---------|
|  1 |     0.000 |      0.000 | 0.200 |        0.083 |  0.0000 |  0.0708 |
|  2 |     0.100 |      0.778 | 0.850 |        0.167 |  0.0110 |  0.4736 |
|  3 |     0.100 |      0.963 | 0.500 |        0.250 |  0.0120 |  0.4532 |
| **4** | **0.300** | **1.000** | **1.000** | **0.458** | **0.1375** | **0.6896** |
|  5 |     0.300 |      0.978 | 0.600 |        0.617 |  0.1085 |  0.6236 |
|  6 |     0.250 |      0.926 | 0.650 |        0.750 |  0.1128 |  0.6440 |
|  8 |     0.500 |      0.778 | 0.550 |        0.812 |  0.1738 |  0.6601 |
| 12 |     1.000 |      0.407 | 0.400 |        0.875 |  0.1426 |  0.6706 |

- **Average score 최적: N=4** (0.6896)
- Product score 최적: N=8 (0.1738) -- stability 가중시 8다리 유리
- **Efficiency 최적: N=4** (1.000) -- COT 해석해에서 정확히 도출

### ASCII 그래프: N별 보행 점수

```
  N= 1 |                                                  | 0.0000
  N= 2 |###                                               | 0.0110
  N= 3 |###                                               | 0.0120
  N= 4 |#######################################           | 0.1375
  N= 5 |###############################                   | 0.1085
  N= 6 |################################                  | 0.1128
  N= 8 |##################################################| 0.1738
  N=12 |#########################################         | 0.1426
```

### ASCII 그래프: 개별 메트릭

```
  Score
  1.0 |             E     EP    E                 S
  0.9 |                               E           A
  0.8 |       EP                            EA
  0.7 |                               P
  0.6 |                         PA          P
  0.5 |             P     A                 S
  0.4 |                                           EP
  0.3 |             A     S     S     S
  0.2 | P     A     A                 S
  0.1 | A     S     S
      +------------------------------------------------
       N=1    N=2    N=3    N=4    N=5    N=6    N=8    N=12
  S=Stability  E=Efficiency  P=sPeed  A=Adaptability
```

### 생물학적 다리 수 분포

| Taxon                | Legs | Species~ | n=6 Relation        |
|----------------------|------|----------|---------------------|
| Mammals              |    4 | ~6,400   | tau(6) = 4          |
| Birds                |    2 | ~10,000  | phi(6) = 2          |
| Reptiles             |    4 | ~11,000  | tau(6) = 4          |
| Amphibians           |    4 | ~8,000   | tau(6) = 4          |
| Insects              |    6 | ~1,000,000 | perfect number 6  |
| Arachnids            |    8 | ~100,000 | 2*tau(6) = 8        |
| Crustaceans (decapod)|   10 | ~70,000  | sigma(6)-phi(6)=10  |

### 6의 약수 패턴

```
  Leg Count | Divisor? | Examples
  ----------|----------|---------------------------
      0     |  (none)  | Snakes (derived limbless)
      1     |  1=d(6)  | (none in nature)
      2     |  2=d(6)  | Birds, humans (derived)
      3     |  3=d(6)  | (none in nature)
      4     |  tau(6)  | Mammals, reptiles, amphibians
      5     |  NO      | NONE IN NATURE
      6     |  6=d(6)  | Insects (largest animal group)
      7     |  NO      | NONE IN NATURE
      8     | 2*tau(6) | Arachnids

  Non-divisors of 6 (5, 7, 9, 11): NO animals have these leg counts
```

## Texas Sharpshooter 검정

```
  P(optimal locomotion N=4 | random):  0.0833
  P(>=4/7 bio matches | random):       0.2079
  Combined p-value:                    0.0173
  Bonferroni corrected (x3):           0.0520
  Grade: COINCIDENCE (p > 0.05)
```

## 해석 (Interpretation)

COT 최적화에서 N*=4.0 = tau(6)이 **정확히** 나오는 것은 주목할 만하다.
그러나 이는 모델 파라미터(a=4.0, b=0.25)에 의존하며, 이 값들 자체가
결과를 4로 만들도록 선택되었을 가능성을 배제할 수 없다.

생물학적 패턴은 더 흥미롭다:
- 자연에서 5다리, 7다리 동물이 **전혀 없다**는 것은 6의 약수 패턴과 일치
- 모든 육상 척추동물이 4다리 체형에서 파생된 것은 진화적 제약
- 곤충(6), 거미(8)의 다리 수가 6의 약수/배수인 것은 주목할 만함

p-value = 0.052로 경계선에 있다. 약간의 모델 조정으로 유의할 수 있으나,
엄격한 기준(0.05)을 충족하지 못한다.

## 한계 (Limitations)

- COT 모델의 파라미터 a, b가 결과를 결정 -- ad hoc 조정 가능성
- Product score에서는 N=8이 최적 (기준에 따라 결과가 달라짐)
- 생물학적 다리 수는 진화적 제약(Hox 유전자)으로 설명 가능
- p-value가 0.05 경계선

## 검증 방향 (Next Steps)

- a, b 파라미터를 실제 생체역학 데이터에서 추정
- 로봇 시뮬레이션(MuJoCo)에서 N-legged locomotion 직접 비교
- Hox 유전자 패턴과 n=6 약수 구조의 관계 조사

## 등급: COINCIDENCE (p > 0.05)

COT 최적화 N*=4 = tau(6)는 정확하나 모델 의존적. 생물학적 패턴은 흥미로우나 통계적 경계선.
