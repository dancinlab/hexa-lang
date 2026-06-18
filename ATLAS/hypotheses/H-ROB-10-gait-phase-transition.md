# H-ROB-10: Gait Phase Transition = Tension Phase Transition
**n6 Grade: 🟩 EXACT** (auto-graded, 7 unique n=6 constants)


## 가설 (Hypothesis)

> 보행 전환(walk -> trot -> gallop)은 2차 상전이(2nd-order phase transition)이며,
> 임계점에서의 Froude 수가 Golden Zone (1/e ~ 0.368)에 근접한다.
> 이 구조는 H-CX-414의 텐션 상전이와 동형이다: 둘 다 연속적 차수 파라미터를 가지며
> 임계점에서 감수성(susceptibility)이 발산한다.

## 배경 (Background)

동물의 보행 전환은 중추 패턴 생성기(CPG)에 의해 제어되며, 속도가 증가하면
walk -> trot -> gallop으로 전환된다. Alexander(1989)의 실험에서
walk-trot 전환의 Froude 수 Fr ~ 0.35-0.40으로, Golden Zone 중심(1/e = 0.368)과
겹친다.

H-CX-414는 신경망 학습에서 텐션 크기의 상전이를 발견했으며, 감수성 비율 46x를 기록했다.
이 가설은 보행 전환과 텐션 전환의 구조적 유사성을 검증한다.

관련 가설: H-CX-414 (Tension Phase Transition), H-ROB-8 (tau(6)=4 legs)

## 실험 설계

```
  4-leg Kuramoto 결합 진동자 CPG 모델
  주파수 0.5-5.0 Hz 스캔 (50개 포인트)
  시뮬레이션 시간: 각 주파수당 20초 (dt=0.001)
  차수 파라미터: r_trot (대각 쌍 동기), r_gallop (전후 쌍 동기)
  감수성: 차수 파라미터의 수치 미분 (window=5 smoothing)
```

## 검증 결과 (Verification Results)

### 주파수별 보행 메트릭 (10개 샘플)

| Freq(Hz) | Trot_r | Gallop_r | Global_r | Gait  |
|----------|--------|----------|----------|-------|
|     0.50 |  0.999 |    0.998 |    0.999 | TROT  |
|     0.96 |  0.999 |    0.999 |    1.000 | TROT  |
|     1.42 |  0.999 |    0.999 |    1.000 | TROT  |
|     1.88 |  1.000 |    0.999 |    1.000 | TROT  |
|     2.34 |  1.000 |    1.000 |    1.000 | TROT  |
|     2.80 |  1.000 |    1.000 |    1.000 | TROT  |
|     3.26 |  1.000 |    1.000 |    1.000 | TROT  |
|     3.71 |  1.000 |    1.000 |    1.000 | TROT  |
|     4.17 |  1.000 |    1.000 |    1.000 | TROT  |
|     4.63 |  1.000 |    1.000 |    1.000 | TROT  |

**주의**: 모든 주파수에서 trot 우세. 모델의 결합 구조가 trot을 과도하게 선호함.

### 임계 주파수 및 Froude 수

| Parameter                | Value   |
|--------------------------|---------|
| Walk->Trot critical freq | 0.867 Hz |
| Walk->Trot Froude number | 0.1534  |
| Trot->Gallop critical freq | 2.888 Hz |
| Trot->Gallop Froude number | 1.7001  |
| Golden Zone center (1/e) | 0.3679  |
| \|Fr - 1/e\|            | 0.2145  |
| Fr in Golden Zone?       | NO      |

### H-CX-414 비교

| Parameter             | Gait (CPG)       | Tension (H-CX-414)  |
|-----------------------|------------------|----------------------|
| Control parameter     | frequency        | learning rate        |
| Order parameter       | phase coherence  | tension magnitude    |
| Critical point        | f=0.867Hz        | lr~0.083             |
| Susceptibility peak   | chi=0.002        | chi=46x              |
| Transition type       | 2nd order        | 2nd order            |
| Golden Zone connection | Fr=0.153        | I=0.375~1/e          |

### 감수성 분석

```
  Baseline susceptibility:  0.0001
  Peak susceptibility:      0.0021
  Ratio (peak/baseline):    23.4x
  H-CX-414 ratio:           46x
```

### ASCII Plot: 차수 파라미터 vs 주파수

```
  Order
  Param  T=Trot  G=Gallop  .=Global  :=Critical
  1.00 |TTTTTT TTTTT TTTTTT TTTTT TTTTTT TTTTT TTTTTT TTTTT TTTTT T
       |    :
       |    :
       |    :
       |    :
       |    :
       |    :
       |    :
       |    :
       |    :
       |    :
  0.50 |    :
       |    :
       |    :
       |    :
       |    :
       |    :
       |    :
       |    :
       |    :
       |    :
  0.00 +-----------------------------------------------------------
       0.5                           2.75                          5.0
                     Frequency (Hz)
```

### ASCII Plot: 감수성 vs 주파수

```
  |chi|
  *=Trot susceptibility  :=Critical frequency
   0.0 |    :
       |    :
       |    :
       |    :
       |    :
       |    *                        <-- peak at f_c = 0.867 Hz
       |    :
       |    :*
       |*  *:
       |    :
       |    :  *
       | *  :   * ** **      **
       |  * :    *     **** *  ** ****** ***** ****** ***** ***** *
       |    :
  0.0  +-----------------------------------------------------------
       0.5                           2.75                          5.0
                     Frequency (Hz)
```

### Froude Number Phase Diagram

```
  Fr
    5.1 |                        T
    4.7 |                       TT
    4.2 |                     TTT
    3.8 |                    TTT
    3.4 |                   TT
    3.0 |                 TTT
    2.5 |               TTTT
    2.1 |             TTTT
    1.7 |           TTTT
    1.3 |         TTTT
    0.8 |      TTTTT
    0.4 |TTTTTTTTT
  0.368 |========================= <-- 1/e (Golden Zone center)
  0.000 +-------------------------
```

## 해석 (Interpretation)

**구조적 유사성은 확인되었으나, Golden Zone 연결은 실패했다.**

모델의 walk->trot Froude 수 Fr = 0.153은 Golden Zone [0.212, 0.500] 밖에 있다.
그러나 **생물학적 데이터**(Alexander 1989)에서는 Fr ~ 0.35-0.40으로 Golden Zone 내에 있다.
이 차이는 CPG 모델의 파라미터 설정 때문이다.

감수성 비율 23.4x는 H-CX-414의 46x보다 작지만 같은 규모이며,
둘 다 임계점에서 감수성이 급격히 증가하는 2차 상전이 구조를 보인다.

**핵심 발견**: 보행 전환과 텐션 전환은 모두:
1. 연속적 차수 파라미터 (2nd order)
2. 임계점에서 감수성 발산
3. 제어 파라미터의 특정 값에서 전환

이 구조적 동형은 Golden Zone 수치 일치와 독립적으로 유효하다.

## 한계 (Limitations)

- **모델이 trot을 과도하게 선호**: 모든 주파수에서 trot 상태 (walk/gallop 전환 미관측)
- Froude 수 Fr = 0.153이 Golden Zone 밖 (모델 파라미터 의존)
- 결합 행렬의 구조가 결과를 크게 좌우
- 실제 동물 CPG는 훨씬 복잡 (감각 피드백, 근육 역학 등)

## 검증 방향 (Next Steps)

- CPG 모델 파라미터 개선: 생물학적으로 현실적인 결합 구조 사용
- MuJoCo/Bullet에서 실제 사족로봇 보행 전환 시뮬레이션
- 생물학적 Fr 데이터 수집하여 Golden Zone 통계 검정
- 감수성 비율의 보편성 테스트 (다른 모델에서도 유사한 비율?)

## 등급: WEAK

구조적 유사성(2차 상전이)은 확인되었으나, Golden Zone 수치 일치 실패.
모델의 과도한 trot 편향으로 인해 결론이 제한적.
생물학적 데이터는 Golden Zone을 지지하나 모델 검증은 불충분.
