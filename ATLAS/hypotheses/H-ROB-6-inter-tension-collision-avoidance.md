# H-ROB-6: Inter-Tension = Collision Avoidance

## 가설

> TECS-L의 inter-tension (엔진 간 긴장)은 로봇 간 충돌 회피 메커니즘에
> 대응한다. Inter-tension threshold가 Golden Zone [0.212, 0.500]에 있을 때
> 최적의 충돌 회피-경로 효율 트레이드오프를 달성한다.

## 배경

TECS-L에서 inter-tension은 두 엔진 사이의 "긴장"으로, 엔진이 가까워지면
증가하고 충돌(간섭)을 방지하는 역할을 한다. 이는 로봇공학의 충돌 회피
(collision avoidance)와 직접적으로 대응될 수 있다.

전통적인 로봇 충돌 회피는 Artificial Potential Field (APF)를 사용하나,
local minima 문제가 있다. Inter-tension 기반 접근은 threshold를 조절하여
"얼마나 가까워지면 회피 행동을 시작할지"를 결정한다.

관련 가설: H-296~H-307 (dual mechanism), H-172 (G*I=D*P)

## 실험 설정

```
Arena: 50 x 50
Steps: 300
Robot speed: 0.5/step
Collision distance: 2.0 (이 이내면 충돌)
Scenarios: 50 (무작위 교차 경로)
Dodge strength: 2.0 (회피 이동 강도)

Inter-tension 정의: T_ab = 1/distance^2
Threshold scan: [0.01, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35,
                 0.40, 0.45, 0.50, 0.60, 0.80, 1.00]

비교 대상:
  1. No avoidance (baseline)
  2. Artificial Potential Field (APF, standard robotics)
  3. Tension-based avoidance (threshold scan)
```

## 검증 결과

### 세 방법 비교

```
|               Method | Collisions | Avg/Scen | Distance | Reached |
|----------------------|------------|----------|----------|---------|
|         No Avoidance |         53 |     1.06 |     81.9 |  50/ 50 |
|      Potential Field |          0 |     0.00 |    299.4 |  50/ 50 |
|     Tension (T=0.10) |          0 |     0.00 |     83.6 |  50/ 50 |
```

### Threshold 스캔 결과

```
| Threshold | Collisions | Avg/Scen | Distance | Reached | Avoids |
|-----------|------------|----------|----------|---------|--------|
|      0.01 |          0 |     0.00 |     90.1 |  50/ 50 |    3.5 |
|      0.05 |          0 |     0.00 |     84.8 |  50/ 50 |    1.1 |
|      0.10 |          0 |     0.00 |     83.6 |  50/ 50 |    0.6 |
|      0.15 |          1 |     0.02 |     83.2 |  50/ 50 |    0.4 |
|      0.20 |         12 |     0.24 |     83.2 |  50/ 50 |    0.4 |
|      0.25 |         14 |     0.28 |     82.8 |  50/ 50 |    0.3 |
|      0.30 |         23 |     0.46 |     83.0 |  50/ 50 |    0.3 |
|      0.40 |         30 |     0.60 |     82.6 |  50/ 50 |    0.2 |
|      0.50 |         30 |     0.60 |     82.4 |  50/ 50 |    0.2 |
|      0.80 |         33 |     0.66 |     82.3 |  50/ 50 |    0.2 |
|      1.00 |         39 |     0.78 |     82.3 |  50/ 50 |    0.1 |
```

### ASCII 그래프 1: Threshold vs Avg Collisions

```
    T=0.01 |                                   | 0.00
    T=0.05 |                                   | 0.00
    T=0.10 |                                   | 0.00  <<< OPTIMAL
    T=0.15 |                                   | 0.02
    T=0.20 |##########                         | 0.24
  * T=0.25 |############                       | 0.28
  * T=0.30 |####################               | 0.46
  * T=0.35 |####################               | 0.46
  * T=0.40 |##########################         | 0.60
  * T=0.45 |##########################         | 0.60
  * T=0.50 |##########################         | 0.60
    T=0.60 |##########################         | 0.58
    T=0.80 |#############################      | 0.66
    T=1.00 |###################################| 0.78
  (* = inside Golden Zone)
```

### ASCII 그래프 2: Threshold vs Avoidance Maneuvers

```
    T=0.01 |###################################| 3.5
    T=0.05 |##########                         | 1.1
    T=0.10 |#####                              | 0.6
    T=0.15 |####                               | 0.4
    T=0.20 |###                                | 0.4
  * T=0.25 |##                                 | 0.3
  * T=0.30 |###                                | 0.3
  * T=0.35 |##                                 | 0.3
  * T=0.40 |##                                 | 0.2
  * T=0.45 |##                                 | 0.2
  * T=0.50 |#                                  | 0.2
    T=0.60 |#                                  | 0.1
    T=0.80 |#                                  | 0.2
    T=1.00 |#                                  | 0.1
```

### Example Trajectory (Scenario 0, T=0.10)

```
  A=start, a=goal | B=start, b=goal
  .=A trajectory   +=B trajectory
  +-------------------------+
  |              B          |
  |                         |
  |              +          |
  |                         |
  |              +          |
  |                         |
  |               +         |
  |                         |
  |                .  .a    |
  |          .   .          |
  |   A  .         +        |
  |                         |
  |                +        |
  |                         |
  |               b         |
  +-------------------------+
```

### 충돌 감소율

```
Tension-based (T=0.10) vs baseline: +100.0% reduction (53 -> 0)
Potential Field vs baseline:        +100.0% reduction (53 -> 0)

BUT: Distance comparison:
  No avoidance:    81.9 (shortest)
  Tension (T=0.10): 83.6 (+2.1% detour)
  Potential Field: 299.4 (+265.5% detour!)
```

## 해석

1. **Tension이 APF보다 효율적**: 두 방법 모두 충돌을 0으로 줄이지만,
   tension 기반(83.6)은 APF(299.4)보다 경로 효율이 **3.6배** 좋다.
   APF는 repulsive force가 과도하여 큰 우회를 유발하는 반면,
   tension은 threshold 이상일 때만 회피하여 최소한의 개입으로 충돌을 방지한다.

2. **최적 Threshold = 0.10 (Golden Zone 밖)**: 최적 threshold는 0.10으로
   Golden Zone [0.212, 0.500] 밖에 위치한다. GZ 내 threshold(0.25~0.50)에서는
   충돌이 12~30개로 증가한다. **Golden Zone 매핑은 확인되지 않음**.

3. **Phase transition at T~0.15**: T=0.10에서 0으로, T=0.15에서 1개,
   T=0.20에서 12개로 급증. 이 전이점(~0.15)은 GZ_lower(0.212)보다
   약간 낮다. "충돌 시작 임계점"이 GZ 근처에 있다는 해석은 가능하나 부정확.

4. **Tension의 장점**: Minimal intervention 원칙. 낮은 threshold(높은 민감도)에서
   약간의 detour(+2.1%)만으로 완전한 충돌 방지를 달성한다.
   이는 TECS-L의 inter-tension이 "적절한 반응성"을 제공한다는 가설을 지지한다.

## 제한사항

- 2-robot 시나리오는 다중 로봇 환경과 다름
- Inter-tension = 1/d^2는 ad-hoc 정의
- APF 파라미터(gain, distance)가 최적화되지 않음 (불공정 비교 가능)
- Perpendicular dodge는 단순한 회피 전략
- 최적 threshold가 Golden Zone 밖이므로 GZ 매핑 불일치
- 50 scenarios는 통계적으로 제한적

## 검증 방향

1. 다중 로봇 (3+)에서 inter-tension 기반 회피 확장
2. APF 파라미터 최적화 후 공정 비교
3. Learned tension threshold (강화학습으로 최적 threshold 탐색)
4. 동적 환경(이동 장애물)에서의 tension 반응성
5. Inter-tension 정의를 학습 가능하게 변경 (1/d^2 -> learnable)

## 등급

```
🟧 — Tension 기반 충돌 회피가 APF보다 경로 효율에서 우수함을 확인.
     그러나 Golden Zone 매핑은 불일치 (최적 T=0.10, GZ=[0.212, 0.500]).
     Inter-tension의 실용성은 확인되나, GZ와의 구조적 연결은 약하다.
```

---
검증 스크립트: `sim_h_rob_6.py`
Golden Zone 의존: YES (가설이 GZ 매핑을 주장하나, 결과는 불일치)
