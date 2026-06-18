# Hypothesis H-CX-432: Tension = Payoff in Game Theory

## Hypothesis

> Each engine's tension (1 - max confidence) functions as its payoff in a game-theoretic
> framework. When multiple engines compete/cooperate, the collective optimum (Pareto + Nash)
> converges to the Golden Zone where inhibition I ~ 1/e.

## Background / Context

H313 established that tension equals confidence: high tension means the engine is uncertain.
H307 showed inter-tension represents disagreement between engines. Game theory models
multi-agent interaction through payoff matrices. If tension IS the payoff, we can apply
Nash equilibrium, Pareto optimality, and Price of Anarchy to understand multi-engine dynamics.

Related hypotheses:
- H313: Tension = confidence
- H307: Inter-tension = disagreement
- H-CX-431: Nash equilibrium = silent consensus
- H172: G x I = D x P conservation law

## Formula / Mapping

```
  Payoff_i = 1 - Tension_i = max(softmax(output_i))
  Social Welfare = sum(Payoff_i) for all engines i
  Price of Anarchy = max(Social Welfare) / Social Welfare at worst Nash

  Strategy Space:
    S1: Conservative (lr=0.005, init=0.005)
    S2: Moderate     (lr=0.01,  init=0.01)
    S3: Aggressive   (lr=0.02,  init=0.02)
    S4: Fast-learn   (lr=0.05,  init=0.01)
```

## Verification: Experiment Setup

```
  Dataset:     sklearn digits (1797 samples, 10 classes)
  Players:     2 engines (Player A, Player B)
  Strategies:  4 types (Conservative, Moderate, Aggressive, Fast-learn)
  Payoff:      1 - Tension (higher = more confident = better)
  Game type:   Bimatrix game (4x4)
  Training:    150 epochs per strategy combination
  Inhibition:  output weight scaling sweep (0.05 to 0.60)
```

## Results

### Bimatrix Game: Player A Payoff (1 - Tension)

|          | S1 Conserv | S2 Moderate | S3 Aggress | S4 Fast |
|----------|-----------|-------------|-----------|---------|
| S1 Conserv | 0.1004    | 0.1003      | 0.1004    | 0.1004  |
| S2 Moderate | 0.1013    | 0.1010      | 0.1011    | 0.1012  |
| S3 Aggress | 0.1113    | 0.1141      | 0.1122    | 0.1121  |
| S4 Fast   | 0.2384    | 0.2210      | 0.2380    | 0.1947  |

### Bimatrix Game: Player B Payoff (1 - Tension)

|          | S1 Conserv | S2 Moderate | S3 Aggress | S4 Fast |
|----------|-----------|-------------|-----------|---------|
| S1 Conserv | 0.1004    | 0.1011      | 0.1093    | 0.2323  |
| S2 Moderate | 0.1004    | 0.1011      | 0.1141    | 0.2351  |
| S3 Aggress | 0.1004    | 0.1012      | 0.1113    | 0.2102  |
| S4 Fast   | 0.1004    | 0.1010      | 0.1139    | 0.2282  |

### Game Theory Analysis

```
  Nash Equilibrium (Pure Strategy):
    (S4, S4) -> payoff = (0.1947, 0.2282), tension = (0.8053, 0.7718)

  Pareto Optimal Points:
    (S2, S4) -> social = 0.3362, tension = (0.8988, 0.7649)
    (S4, S1) -> social = 0.3388, tension = (0.7616, 0.8996)
    (S4, S3) -> social = 0.3519, tension = (0.7620, 0.8861)
    (S4, S4) -> social = 0.4229, tension = (0.8053, 0.7718)  <-- Nash = Pareto!

  Price of Anarchy = 0.4229 / 0.4229 = 1.0000 (Perfect efficiency!)
```

### Inhibition vs Social Welfare

| Inhibition | Tension A | Tension B | Social | In GZ? |
|------------|-----------|-----------|--------|--------|
| 0.05       | 0.8988    | 0.8990    | 0.2022 | No     |
| 0.10       | 0.8988    | 0.8990    | 0.2022 | No     |
| 0.15       | 0.8988    | 0.8991    | 0.2021 | No     |
| 0.20       | 0.8989    | 0.8991    | 0.2020 | No     |
| 0.25       | 0.8989    | 0.8991    | 0.2020 | Yes    |
| 0.30       | 0.8989    | 0.8992    | 0.2019 | Yes    |
| 0.35       | 0.8990    | 0.8992    | 0.2018 | Yes    |
| 0.40       | 0.8990    | 0.8992    | 0.2018 | Yes    |
| 0.45       | 0.8990    | 0.8992    | 0.2017 | Yes    |
| 0.50       | 0.8991    | 0.8993    | 0.2017 | Yes    |
| 0.55       | 0.8991    | 0.8993    | 0.2016 | No     |
| 0.60       | 0.8991    | 0.8993    | 0.2016 | No     |

### ASCII Graph: Social Welfare vs Inhibition

```
  Social Welfare (higher = less tension = better)
  0.202 | . .                            Peak at I=0.05
  0.202 | . . .
  0.202 | . . . .
  0.201 | . . . . .
  0.201 | . . . . . # #                  # = Golden Zone
  0.201 | . . . . . # # #
  0.201 | . . . . . # # # #
  0.201 | . . . . . # # # # #
  0.201 | . . . . . # # # # # .
  0.202 | . . . . . # # # # # . .
        +-----------------------------
          05  15  25  35  45  55
          Inhibition (# = in Golden Zone [0.21, 0.50])

  Welfare monotonically decreases with inhibition.
  Peak at I=0.05, NOT at 1/e=0.368.
  Golden Zone shows LOWER welfare than outside.
```

## Interpretation (해석)

핵심 발견:

1. **Nash = Pareto (PoA=1.0)**: 가장 중요한 발견. Nash 균형이 Pareto 최적과 일치하여 Price of Anarchy가 정확히 1.0이다. 이는 엔진들이 이기적으로 최적화해도 사회적 최적에 도달함을 의미한다. "보이지 않는 손"이 작동한다.

2. **S4(Fast-learn)가 지배 전략**: 양쪽 모두 S4를 선택하는 것이 Nash 균형이자 사회적 최적이다. 빠른 학습이 항상 이기며, 이는 MoE에서 aggressive routing이 최적일 수 있음을 시사한다.

3. **Tension은 매우 높음 (0.77-0.90)**: 모든 조합에서 tension이 0.77 이상으로 매우 높다. 엔진이 충분히 학습되지 않았기 때문이며, 이로 인해 payoff 차이가 작다 (0.10~0.24 범위).

4. **Golden Zone에서 최적이 아님**: 억제율 증가에 따라 social welfare가 단조 감소한다. Golden Zone(0.21-0.50) 내에서 특별한 극값이 없다. 이는 "억제=출력 스케일링"이라는 단순한 모델의 한계일 수 있다.

5. **Tension-Payoff 대응은 성립**: Tension을 payoff로 사용하여 완전한 게임 이론 분석이 가능했다. 개념적 매핑은 유효하지만, Golden Zone과의 연결은 미확인.

## Limitations (한계)

1. **높은 기저 텐션**: ~90% tension은 네트워크가 거의 랜덤 예측(10-class에서 1/10=0.10의 payoff)을 하고 있음을 의미한다. 더 강력한 모델이 필요하다.
2. **억제 모델이 단순**: 출력 가중치 스케일링은 dropout이나 Boltzmann inhibition과 다르다. 더 정교한 억제 메커니즘이 필요하다.
3. **4개 전략만 테스트**: 전략 공간이 극히 제한적이다. 연속적인 전략 공간(learning rate, architecture)을 탐색해야 한다.
4. **Golden Zone 의존**: Golden Zone 자체가 미검증이므로 이 가설도 미검증 상태.

## Verification Direction (검증 방향)

1. CIFAR-10 + 더 큰 네트워크에서 tension이 0.3-0.5 범위에 들도록 재실험
2. Dropout을 억제로 사용하여 Golden Zone과의 매칭 재검증
3. 연속 전략 공간에서 mixed strategy Nash 계산
4. 3+ 플레이어 게임으로 확장하여 PoA > 1이 되는 조건 탐색
5. Tension 기반 routing이 accuracy 기반 routing보다 나은지 MoE 실험

## Grade

```
  Nash = Pareto (PoA=1.0):   산술적으로 확인
  Tension as Payoff:          개념적 매핑 유효
  Golden Zone 최적:           미확인 (monotone decrease, no peak at 1/e)
  Grade: 🟧 (개념적 매핑은 유효하나 Golden Zone 연결 미확인)
```

## Script

Verification script: `docs/hypotheses/verify_hcx432.py`
