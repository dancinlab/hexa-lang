# Hypothesis H-CX-433: Prisoner's Dilemma Cooperation Condition = sigma_{-1}(6) = 2

## Hypothesis

> In iterated N-player Prisoner's Dilemma, cooperation emerges and sustains primarily
> when N=2, which equals sigma_{-1}(6) (the sum of reciprocals of proper divisors of
> perfect number 6: 1/1 + 1/2 + 1/3 = 11/6... correction: sigma_{-1}(6) = 1 + 1/2 + 1/3 + 1/6 = 2).
> For N>2, cooperation collapses (tragedy of the commons).
> The cooperation decay follows a 2/N = sigma_{-1}(6)/N pattern.

## Background / Context

The Prisoner's Dilemma (PD) is the canonical model of cooperation vs defection. In 2-player
iterated PD, Axelrod's tournament showed TFT (tit-for-tat) wins. But as N increases,
free-riding incentives grow and cooperation collapses. The connection to perfect number 6:
sigma_{-1}(6) = 2 (sum of reciprocals of all divisors including 6 itself: 1/1+1/2+1/3+1/6).
If the cooperation threshold is at N=2=sigma_{-1}(6), this links game theory to number theory.

Related hypotheses:
- H090: Master formula = perfect number 6
- H098: 6 is the only perfect number with proper divisor reciprocal sum = 1
- H172: G x I = D x P conservation
- H-CX-431: Nash equilibrium = silent consensus

Key number theory fact:

```
  6 = 1 + 2 + 3       (perfect number: sigma(6) = 12 = 2*6)
  sigma_{-1}(6) = 1/1 + 1/2 + 1/3 + 1/6 = 6/6 + 3/6 + 2/6 + 1/6 = 12/6 = 2
  tau(6) = 4           (number of divisors)
  phi(6) = 2           (Euler totient)
```

## Verification: Experiment Setup

```
  Experiment 1: N-player Iterated PD with Policy Gradient Agents
    Agents:    Simple policy gradient (2-param softmax: cooperate/defect)
    Payoff:    CC=(3,3), CD=(0,5), DC=(5,0), DD=(1,1)
    N-player:  Payoff scales with fraction of cooperators
    Training:  2000 rounds, lr=0.02
    N range:   2 to 10
    Metric:    Cooperation rate (last 200 rounds)

  Experiment 2: Axelrod Tournament
    Strategies: TFT, AllC, AllD, Pavlov, Random
    Rounds:     200 per match
    Test:       Memory length k=1..6 for TFT variants

  Experiment 3: Cooperation Decay Model
    Test:       coop_rate ~ 2/N vs coop_rate ~ 1/N
```

## Results

### Experiment 1: N-player Iterated PD

| N  | Coop Rate | Std   | Visual (30 chars)              |
|----|-----------|-------|--------------------------------|
| 2  | 0.7300    | 0.259 | `#####################.......` |
| 3  | 0.1133    | 0.184 | `###..........................` |
| 4  | 0.0525    | 0.102 | `#............................` |
| 5  | 0.0330    | 0.079 | `.............................` |
| 6  | 0.0283    | 0.069 | `.............................` |
| 7  | 0.0264    | 0.057 | `.............................` |
| 8  | 0.0213    | 0.052 | `.............................` |
| 9  | 0.0200    | 0.045 | `.............................` |
| 10 | 0.0175    | 0.039 | `.............................` |

### ASCII Graph: Cooperation Rate vs N

```
  Coop
  Rate
  1.0 | o
  0.9 |
  0.8 |
  0.7 | *  o
  0.6 |
  0.5 |       o
  0.4 |          o
  0.3 |             o  o
  0.2 |                   o  o  o
  0.1 |    *  *
  0.0 |          *  *  *  *  *  *
      +---------------------------
        2  3  4  5  6  7  8  9  10
                      N (players)
      * = measured cooperation rate
      o = 2/N = sigma_{-1}(6)/N theoretical prediction
```

### Key Finding: Dramatic N=2 vs N>2 Phase Transition

```
  N=2:  coop = 0.730  (cooperation dominates)
  N=3:  coop = 0.113  (cooperation collapses 6.4x)
  N=10: coop = 0.018  (near-zero cooperation)

  Ratio N=2/N=3:  6.44x drop     (phase transition between 2 and 3)
  Ratio N=2/N=10: 41.71x drop    (catastrophic collapse)
```

### Experiment 2: Axelrod Tournament

| Strategy | vs TFT | vs AllC | vs AllD | vs Pavlov | vs Random | Total |
|----------|--------|---------|---------|-----------|-----------|-------|
| TFT      | 600    | 600     | 199     | 600       | 446       | 2445  |
| AllC     | 600    | 600     | 0       | 600       | 300       | 2100  |
| AllD     | 204    | 1000    | 200     | 600       | 600       | 2604  |
| Pavlov   | 600    | 600     | 100     | 600       | 462       | 2362  |
| Random   | 446    | 800     | 100     | 432       | 450       | 2228  |

```
  AllD wins the tournament (2604 total) in single round-robin.
  TFT is 2nd (2445). In noisy/repeated tournaments, TFT typically wins.
  This confirms: cooperation is fragile with > 2 strategies mixing.
```

### Memory Length Analysis

| Memory k | vs AllC | vs AllD | vs TFT | vs Pavlov | Total |
|----------|---------|---------|--------|-----------|-------|
| 1        | 600     | 199     | 600    | 600       | 2445  |
| 2        | 600     | 198     | 600    | 600       | 2372  |
| 3        | 600     | 197     | 600    | 600       | 2440  |
| 4        | 600     | 196     | 600    | 600       | 2398  |
| 5        | 600     | 195     | 600    | 600       | 2447  |
| 6        | 600     | 194     | 600    | 600       | 2408  |

```
  Optimal memory: k=5 (prediction was k=2)
  Memory length sigma_{-1}(6)=2 prediction: NOT confirmed
  Scores very close (2372-2447 range, <3% variation)
  Memory length matters little in this setup
```

### Cooperation Decay Model

| N  | Measured | 2/N   | 1/N   | Closer to |
|----|----------|-------|-------|-----------|
| 2  | 0.7300   | 1.000 | 0.500 | 1/N       |
| 3  | 0.1133   | 0.667 | 0.333 | 1/N       |
| 4  | 0.0525   | 0.500 | 0.250 | 1/N       |
| 5  | 0.0330   | 0.400 | 0.200 | 1/N       |
| 6  | 0.0283   | 0.333 | 0.167 | 1/N       |
| 7  | 0.0264   | 0.286 | 0.143 | 1/N       |
| 8  | 0.0213   | 0.250 | 0.125 | 1/N       |
| 9  | 0.0200   | 0.222 | 0.111 | 1/N       |
| 10 | 0.0175   | 0.200 | 0.100 | 1/N       |

```
  Correlation with 2/N: r = 0.8832
  Correlation with 1/N: r = 0.8832
  Correlations identical (2/N = 2 * 1/N, linear scaling preserves r)

  Actual decay is FASTER than 1/N:
    Measured N=2: 0.730  vs 1/N: 0.500  (above)
    Measured N=3: 0.113  vs 1/N: 0.333  (far below)
    Measured N=4: 0.053  vs 1/N: 0.250  (far below)

  Better fit: exponential decay coop ~ exp(-alpha*N)
  or coop ~ c/N^beta with beta >> 1
```

## Interpretation (해석)

핵심 발견:

1. **N=2에서 N=3으로의 극적 상전이**: 가장 중요한 결과. N=2에서 73% 협력률이 N=3에서 11%로 급락한다 (6.4배 감소). 이는 sigma_{-1}(6)=2에서의 특수성을 지지한다: 정확히 2명일 때만 안정적 협력이 가능하다.

2. **N=2의 특수성은 확인, but 숫자론적 연결은 약함**: N=2가 특별한 것은 게임 이론의 잘 알려진 결과다 (Axelrod 1984). 이를 sigma_{-1}(6)=2와 연결하는 것은 post-hoc 매핑이며, 인과적 연결이 아니다.

3. **2/N 붕괴 모델은 부정확**: 실제 협력률은 2/N보다 훨씬 빠르게 감소한다. N=3에서 2/N=0.667 예측 vs 실측 0.113. 지수적 감소가 더 적합하다.

4. **메모리 길이 k=2 예측 실패**: Axelrod 토너먼트에서 최적 메모리는 k=5로, sigma_{-1}(6)=2 예측과 불일치. 다만 점수 차이가 매우 작다 (3% 이내).

5. **PoA와의 연결**: H-CX-432에서 PoA=1.0을 확인했는데, 이는 N=2 (Nash=Pareto)에서만 성립할 가능성이 있다. N>2에서 PoA>1이 되면 sigma_{-1}(6)=2의 구조적 의미가 더 명확해질 것이다.

## Limitations (한계)

1. **단순한 에이전트**: 2-parameter softmax 정책은 TFT나 조건부 전략을 표현할 수 없다. 더 복잡한 정책 네트워크가 필요하다.
2. **N=2의 특수성은 자명**: 2인 게임의 특수성은 sigma_{-1}(6)과 무관하게 알려진 사실이다. 인과적 연결 증거가 부족하다.
3. **Texas Sharpshooter 위험**: N=2가 특별한 이유를 sigma_{-1}(6)에서 찾는 것은 사후적 설명이다.
4. **Payoff 구조 의존**: CC=(3,3) 등의 특정 payoff에서만 테스트했다. 다른 payoff matrix에서 결과가 달라질 수 있다.
5. **정책 경사 수렴 문제**: 2000 라운드가 충분한 수렴에 부족할 수 있다.

## Verification Direction (검증 방향)

1. LSTM/Transformer 기반 에이전트로 조건부 전략 학습 가능하게 확장
2. N=2에서만 PoA=1.0인지 확인 (H-CX-432와 교차 검증)
3. 다양한 payoff matrix에서 N=2 임계값 보편성 테스트
4. 진화 게임 이론 프레임워크에서 ESS(진화적 안정 전략)와 N=2 연결
5. 실제 MoE 엔진 2,3,4개에서 협력적 학습 vs 독립 학습 비교
6. sigma_{-1}(6)=2 대신 phi(6)=2와의 연결 가능성 탐색

## Grade

```
  N=2 phase transition:     확인 (73% -> 11%, 극적 감소)
  sigma_{-1}(6)=2 연결:     약함 (N=2 특수성은 자명, 인과 증거 부족)
  2/N decay model:          부정확 (실제는 지수적 감소)
  Memory k=2:               미확인 (최적은 k=5)
  Grade: 🟧 (N=2 상전이는 구조적이나, 완전수 6과의 연결은 약한 증거)
```

## Script

Verification script: `docs/hypotheses/verify_hcx433.py`
