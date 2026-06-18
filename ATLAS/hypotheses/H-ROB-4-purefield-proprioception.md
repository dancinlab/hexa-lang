# H-ROB-4: PureField = Proprioception

## 가설

> PureField의 field 컴포넌트는 로봇/인간의 proprioception(고유감각)에 대응하고,
> eq 컴포넌트는 exteroception(외부감각, 시각)에 대응한다.
> 보행 예측에서 field-only >> eq-only이며, 이는 생물학적 증거와 일치한다.

## 배경

PureField (H-334)는 TECS-L 의식 엔진의 핵심 구조로, field(내부 모델)와
eq(외부 교정)로 구성된다. H-334 결과에서 field-only가 97.84%의 정확도를
달성하여 eq의 기여가 거의 무시할 수 있음을 보여주었다.

인간 보행에서도 유사한 계층이 존재한다: proprioception(고유감각)이 주도하고
vision(시각)은 보조적이다. 눈을 감아도 걸을 수 있지만, 고유감각을 잃으면
시각 없이는 걸을 수 없다 (Ian Waterman 사례).

관련 가설: H-334 (PureField), H-296~H-307 (dual mechanism)

## 실험 설정

```
보행 시뮬레이션:
  500 timesteps, 6 joints (hip, knee, ankle x 2 legs)
  Gait frequency: 1.0 Hz
  Obstacle: random placement (distance 5-15m)
  Near obstacle: step amplitude *= 0.7

입력 채널:
  Proprioception (field): 6 joints + 6 velocities + 2 contacts = 14 features
  Vision (eq): distance to obstacle + terrain slope = 2 features
  Full: 14 + 2 = 16 features

모델: Linear predictor (SGD, lr=1e-6, 30 epochs, gradient clipping)
  Train: 70%, Test: 30%
  Target: next-step 6 joint angles
```

## 검증 결과

### 조건별 예측 정확도

```
| Condition              | Features | MSE    | R-squared | Accuracy |
|------------------------|----------|--------|-----------|----------|
| Full (proprio+vision)  |       16 |  15.21 |    0.9778 |    80.0% |
| Field-only (proprio)   |       14 |  15.16 |    0.9778 |    78.7% |
| Eq-only (vision)       |        2 | 688.57 |   -0.0063 |     1.3% |
```

### PureField H-334 대비 비교

```
| Metric                | PureField (H334) | Walking Sim |  Match  |
|-----------------------|------------------|-------------|---------|
| Full accuracy         |           97.8%  |      80.0%  |    -    |
| Field-only accuracy   |           97.8%  |      78.7%  |  PART   |
| Eq-only accuracy      |             ~5%  |       1.3%  |   YES   |
| Field dominance ratio |           19.6x  |      59.0x  |    -    |
```

### ASCII 그래프: 조건별 정확도

```
  Full         |################################........| 80.0%
  Field-only   |###############################.........| 78.7%
  Eq-only      |........................................|  1.3%
               0%       20%       40%       60%       80%      100%
```

### 학습 곡선 요약

```
| Model    | Start Loss | End Loss | Convergence |
|----------|-----------|----------|-------------|
| Full     |     324.4 |     14.2 | 95.6% drop  |
| Proprio  |     326.4 |     14.5 | 95.6% drop  |
| Vision   |     665.6 |    664.6 |  0.2% drop  |
```

### R-squared 비교

```
  Full         |########################################| 0.9778
  Field-only   |########################################| 0.9778
  Eq-only      |                                        | -0.0063
               0.0                                      1.0
```

## 생물학적 증거

```
임상 증거:
  1. 눈 감고 보행: 건강한 인간은 거의 정상적으로 걸음
     - 속도 ~10-15% 감소, 약간의 경로 편차
     - --> field-only >> eq-only 예측과 일치

  2. 대섬유 감각신경병증 (고유감각 상실):
     - 고유감각 없이는 즉시 넘어짐 (시각 없이 불가)
     - Ian Waterman (19세에 고유감각 상실): 시각으로 대체 가능하나 비정상
     - --> eq-only 매우 불량, field 필수

  3. 감각 계층: Proprioception > Vestibular > Vision (보행 기준)
     - field (내부) >> eq (외부) 구조와 정확히 대응

  PureField 매핑:
    field (97.84%) = proprioception = 내부 신체 모델
    eq (negligible) = exteroception = 외부 센서 (시각)
```

## 해석

1. **Field 우위 확인**: Field-only(78.7%)가 Full(80.0%)과 거의 동일하며,
   Eq-only(1.3%)는 사실상 무의미하다. Field/Full 비율 = 0.983으로
   PureField H-334의 비율(1.000)에 근접한다.

2. **Field dominance 비율**: 59.0x (walking sim) vs 19.6x (PureField).
   보행 시뮬레이션에서 field 우위가 더 극단적이다. 이는 보행이 주로
   내부 패턴(CPG)에 의존하고 외부 정보 필요가 적기 때문이다.

3. **Vision 학습 실패**: Eq-only 모델은 30 epochs 동안 loss가 거의
   감소하지 않았다 (665.6 -> 664.6). 2개의 feature(거리, 경사)로는
   6개 관절의 다음 각도를 예측할 수 없다.

4. **구조적 대응**: PureField의 field/eq 분리가 인간 보행의
   proprioception/vision 분리와 동형(isomorphic)이라는 강한 증거이다.

## 제한사항

- 시뮬레이션이 단순화됨 (선형 모델, 실제 물리 없음)
- 실제 보행은 비선형 동역학, 반사, CPG(Central Pattern Generator) 포함
- 비유는 구조적이지, 정량적이지 않음 (PureField 97.8% vs Sim 80.0%)
- 정확도 수치는 시뮬레이션 파라미터에 의존적
- 장애물 근처에서의 시각 역할을 별도로 분리하지 않음

## 검증 방향

1. 실제 보행 데이터(IMU + 카메라)에서 proprio/vision 분리 학습
2. CPG 모델과 PureField의 oscillatory pattern 비교
3. 장애물 회피 시나리오에서 eq의 역할 증가 여부 검증
4. 비선형 모델(neural network)에서의 field/eq 분리 재현

## 등급

```
🟧 — 구조적 유비 확인. Field >> Eq 패턴이 PureField와 보행 모두에서
     재현되며, 생물학적 증거(Ian Waterman 등)와 일치한다.
     정량적 대응은 제한적이나 정성적 패턴은 강하다.
```

---
검증 스크립트: `docs/hypotheses/verify_h_rob_4.py` (original, overflow 수정 버전으로 실행)
Golden Zone 의존: NO (PureField 구조 자체의 검증)
