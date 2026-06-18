# H-ROB-2: Tension = Torque Optimization

## 가설

> 신경망의 tension (내부 활성화 불확실성)은 로봇 관절의 물리적 torque와
> 상관관계를 가진다. 높은 tension = 높은 torque 요구 영역이며,
> tension 최적화가 곧 torque 최적화의 프록시가 될 수 있다.

## 배경

TECS-L에서 tension은 신경망 내부의 "긴장" 상태를 측정하는 지표로,
예측 불확실성이나 학습 난이도를 반영한다. 로봇공학에서 torque는
관절이 물리적으로 버텨야 하는 힘이며, 에너지 효율과 직결된다.

이 가설은 tension(소프트웨어)과 torque(하드웨어) 사이의 대응 관계를
2-DOF 평면 로봇 시뮬레이션으로 검증한다.

관련 가설: H-172 (G*I=D*P 보존법칙), Tension calculator (calc/tension_calculator.py)

## 실험 설정

```
로봇: 2-DOF planar arm
  Link 1: L1 = 1.0 m, mass = 1.0 kg
  Link 2: L2 = 0.8 m, mass = 0.8 kg
  Workspace: annulus r_min=0.2, r_max=1.8

신경망: 2 -> 64 -> 32 -> 2 (ReLU, SGD)
  입력: end-effector (x, y)
  출력: joint angles (theta1, theta2)
  학습 데이터: 2000 samples (1600 train, 400 test)
  Epochs: 500, LR: 0.005

Tension 정의:
  0.3 * sparsity(h1) + 0.3 * sparsity(h2)
  + 0.2 * normalized_var(h1) + 0.2 * normalized_var(h2)
```

## 검증 결과

### 상관관계 매트릭스

```
                 Tension     Torque     Manip.   Distance
    Tension       1.000    -0.2232     0.1907     0.6259
     Torque      -0.2232    1.000     0.1006     0.2801
Manipulability    0.1907    0.1006     1.000        --
```

### Torque Quintile별 Tension 분석

```
  Quintile     Torque Range   Mean Torque  Mean Tension  Tension Std
  Q1 (low)    [0.94, 5.04]       3.694        0.4869       0.1213
  Q2          [5.06, 7.96]       6.539        0.4892       0.1077
  Q3          [7.98, 10.24]      9.166        0.4443       0.1167
  Q4          [10.32, 12.34]    11.360        0.4331       0.0947
  Q5 (high)   [12.39, 15.45]    13.603        0.4323       0.0690
```

### 통계적 유의성 (순열 검정)

```
|corr(tension, torque)| = 0.2232
  Permutation test (n=10,000): p = 0.0000 --> Significant (alpha=0.05)

|corr(tension, manipulability)| = 0.1907
  Permutation test: p = 0.0001 --> Significant
```

### 작업공간 Tension Heatmap (ASCII)

```
Tension (darker = higher):        Torque (darker = higher):
+--------------------+            +--------------------+
|                    |            |                    |
|       @@@@###      |            |           ..       |
|     @@@@#####+     |            |     .    ..##@     |
|    @@####+++++=    |            |    #+   ..##@@     |
|   #####++++..+=    |            |   @#+   .##@@@!    |
|  ###+++....     +  |            |  @@#+   .##@@!!!   |
| ++++++.........+.. |            | !@#+    .#@@@@!!!! |
| .........      ... |            | !@@+    .#@@@@@!!! |
| ...              . |            | !!@#+   .#@@@@@!!! |
| ..               . |            | !!@@#+   +++##@@!! |
| ..               . |            | !!@@#+++  ...##@!! |
| ....             . |            | !!!@@@@#+   .##@!! |
| ............ ...   |            | !!!@@@@#+   ..#@@! |
| +++++++............|            | !!!!@@@@#+   .##@! |
|  ###+++.........   |            |  !!!@@@##+   .##@  |
|  #####++++...+..   |            |  !!@@##+++   .##@  |
|   @@#####+++++=    |            |   @@###++..   .#   |
|     @@@#####+      |            |     @##++    .     |
|       @@@####      |            |       ..           |
|                    |            |                    |
+--------------------+            +--------------------+
```

### 학습 곡선

```
  Epoch |       Loss | Graph
  ------+------------+--------------------------------------------------
      0 |   0.998731 | ##################################################
     50 |   0.965902 | ################################################
    100 |   0.931782 | ##############################################
    200 |   0.835931 | #########################################
    300 |   0.708169 | ###################################
    400 |   0.600792 | ##############################
    499 |   0.537786 | ##########################
```

### Golden Zone 연결

```
Golden Zone: [0.2123, 0.5000]
Rescaled tension 중 Golden Zone 비율: 49.1% (기대값 28.8%)
비율: 1.71x (Golden Zone에 tension이 집중)

최대 manipulability 지점: Tension = 0.3487, Torque = 12.150 Nm
최소 manipulability 지점: Tension = 0.3228, Torque = 8.331 Nm
```

## 해석

1. **Tension-Torque 상관**: corr = -0.2232 (p < 0.001). 방향이 **음**이다.
   높은 torque 영역에서 tension이 오히려 낮아진다. 이는 고torque 영역이
   기하학적으로 단순(arm이 뻗은 상태)하여 신경망이 쉽게 학습하기 때문이다.

2. **Tension-Distance 상관**: corr = +0.6259로 가장 강하다. Tension은
   torque보다 end-effector 거리에 더 강하게 반응한다. 즉 tension은
   물리적 힘이 아닌 기하학적 복잡성을 반영한다.

3. **Manipulability와의 관계**: corr = +0.1907 (양의 상관, 예상과 반대).
   Singularity 근처에서 tension이 높을 것으로 예상했으나, 실제로는
   manipulability가 높은 곳에서 tension이 높다.

4. **Golden Zone 집중**: Rescaled tension의 49.1%가 Golden Zone에 있어
   기대값 28.8%의 1.71배이다. Tension이 Golden Zone에 자연스럽게 집중되는
   현상은 구조적일 수 있으나, 정규화 방법에 의존적이다.

## 제한사항

- 2-DOF 평면 로봇은 실제 6-DOF 로봇과 차이가 큼
- Tension 정의가 ad-hoc (sparsity + variance 조합)
- 단순한 3-layer 네트워크로 학습이 불완전 (test loss = 0.51)
- 음의 상관관계는 가설의 직관과 반대
- Gravity torque만 고려, 동적 torque 미포함

## 검증 방향

1. 학습된 tension (learnable tension parameter)으로 재검증
2. 6-DOF 로봇에서 inverse dynamics torque와 비교
3. 더 깊은 네트워크에서 tension-torque 관계 변화 관찰
4. 동적 궤적(trajectory tracking)에서의 tension-torque 관계

## 등급

```
🟧 — 약한 증거. 통계적으로 유의한 상관(p < 0.001)이 존재하나,
     방향이 예상과 반대(음의 상관)이고 크기가 작다(r = -0.22).
     Tension은 torque보다 기하학적 거리에 더 강하게 반응한다.
```

---
검증 스크립트: `scripts/verify_h_rob_2.py`
Golden Zone 의존: 부분적 (Golden Zone 집중 분석만 해당)
