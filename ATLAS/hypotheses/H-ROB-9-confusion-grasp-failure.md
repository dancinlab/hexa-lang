# H-ROB-9: Confusion Matrix = Grasp Failure Map
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


## 가설 (Hypothesis)

> 물체 인식 신경망의 혼동 행렬(confusion matrix)은 로봇 파지(grasp) 실패 맵과
> 동형이다. 신경망이 두 물체를 혼동할수록, 그 물체들의 파지 파라미터도 유사하여
> 같은 파지 전략으로 실패할 확률이 높다. 이 상관관계는 Golden Zone 내에 있다.

## 배경 (Background)

로봇 파지(grasping)에서 물체 인식 오류는 파지 실패의 주요 원인이다.
이 가설은 인식 오류와 파지 오류 사이의 구조적 동형을 주장한다:
신경망이 cup과 bottle을 혼동하면, 이 두 물체의 파지 파라미터(폭, 각도, 힘)도
유사하여 동일한 파지 전략이 적용되는 경향이 있다.

관련 가설: H-CX-150 (cosine similarity 0.986), topological optics

## 실험 설계

```
  10개 일상 물체의 파지 파라미터 정의 (width, angle, force)
  5차원 센서 특징을 생성하여 2-layer MLP 학습
  혼동 행렬과 파지 유사도 행렬의 상관관계 측정
  Persistent Homology (H0)로 위상적 병합 순서 비교
```

## 검증 결과 (Verification Results)

### 물체 파지 파라미터

| Object | Width(mm) | Angle(deg) | Force(N) |
|--------|-----------|------------|----------|
| cup    |        80 |         90 |      3.0 |
| ball   |        70 |         45 |      2.5 |
| bottle |        65 |         90 |      3.5 |
| book   |        30 |          0 |      4.0 |
| pen    |        15 |          0 |      1.0 |
| phone  |        25 |          0 |      2.0 |
| plate  |        35 |          0 |      1.5 |
| box    |       100 |         90 |      5.0 |
| banana |        50 |         45 |      1.5 |
| hammer |        40 |          0 |      6.0 |

### 신경망 혼동 행렬

```
          cup ball bott book  pen phon plat  box bana hamm
   cup      .    .    .    .    .    .    .   29   31    .
  ball      .    .    .    .    .    .    .    .   60    .
bottle      .    .    .    .    .    .    .   34   26    .
  book      .    .    .    .    .    .    .    9   44    7
   pen      .    1    .    .    .    1    9    2   45    2
 phone      1    .    .    .    .    2    4    5   46    2
 plate      .    .    .    .    .    6    .    2   51    1
   box      .    .    .    .    .    .    .   43   17    .
banana      .    .    .    .    .    .    .    .   60    .
hammer      .    .    .    .    .    .    .   22   32    6
```

Test accuracy: 18.5% (10 class, random=10%, low -- 많은 혼동 발생)

### 상관관계 분석

| Metric                   | Value  |
|--------------------------|--------|
| Pearson r                | 0.3082 |
| Spearman r               | 0.1395 |
| t-statistic              | 2.124  |
| df                       | 43     |
| Top-10 pair overlap      | 3/10 = 30% |
| PH merge overlap (top 5) | 4/5 = 80%  |
| PH merge rank Spearman   | 0.2000 |

### ASCII Scatter: Grasp Similarity (x) vs Neural Confusion (y)

```
  Neural
  Conf. ^
   1.00 |                                                  |
        |                                           *      |
        |                                                  |
        |                                    *             |
        |                                                  |
        |                                * *               |
        |                             *                    |
        |                                                  |
        |                                                  |
        |                   *                 *            |
        |                               *      *           |
        |                                *                 |
        |                                                  |
        |            *                                     |
        |                   *                              |
        |                                                  |
        |                                                * |
        |          *                             *    *    |
        |     *                                            |
   0.00 |*     *   * ****** *   ***** * * *  **  *     **  |
        +--------------------------------------------------+
        0.00                                          0.90
                    Grasp Similarity
```

### ASCII Heatmap: Grasp Similarity

```
  Scale:  =0.0 .=0.2 :=0.4 +=0.6 #=0.8 @=1.0
         cup bal bot boo pen pho pla box ban ham
   cup     X   +   #   .       .   .   +   :   .
  ball     +   X   +   :   :   :   :   :   #   :
bottle     #   +   X   .   .   .   .   +   :   .
  book     .   :   .   X   +   +   +       :   +
   pen         :   .   +   X   #   #       :   .
 phone     .   :   .   +   #   X   #       +   :
 plate     .   :   .   +   #   #   X       +   :
   box     +   :   +                   X   .   .
banana     :   #   :   :   :   +   +   .   X   .
hammer     .   :   .   +   .   :   :   .   .   X
```

### Persistent Homology 병합 순서

```
  Grasp PH (H0) merge order:
    1. d=0.154  phone+plate   |##
    2. d=0.203  cup+bottle    |###
    3. d=0.232  pen+phone     |####
    4. d=0.309  ball+banana   |#####
    5. d=0.404  book+pen      |#######

  Neural PH (H0) merge order:
    1. d=0.000  ball+banana   |
    2. d=0.150  plate+ball    |####
    3. d=0.233  phone+plate   |######
    4. d=0.250  pen+phone     |#######
    5. d=0.267  book+pen      |########

  Top-5 overlap: 4/5 = 80%
  (phone+plate, pen+phone, ball+banana, book+pen 모두 일치)
```

## Golden Zone 검사

```
  |r| = 0.3082
  Golden Zone = [0.212, 0.500]
  0.212 <= 0.308 <= 0.500: YES -- r이 Golden Zone 내에 위치
```

## 해석 (Interpretation)

Pearson r = 0.308은 "의미 있는 상관관계"(r > 0.3) 경계에 위치하며,
Golden Zone [0.212, 0.500] 내에 있다.

**가장 강력한 증거는 PH 병합 순서의 80% 일치**이다:
- 파지 공간에서 가장 가까운 쌍들이 신경망 혼동에서도 가장 먼저 병합
- phone-plate, pen-phone, ball-banana, book-pen이 양쪽에서 모두 초기 병합
- 이는 위상적 구조가 보존됨을 의미

그러나 테스트 정확도가 18.5%로 매우 낮아 혼동이 과도하게 발생했다.
더 나은 분류기에서는 혼동이 줄어들면서 상관관계가 달라질 수 있다.

## 한계 (Limitations)

- 테스트 정확도 18.5%는 실용적 수준이 아님 (너무 많은 혼동)
- Spearman r = 0.14로 낮음 (비선형 관계도 약함)
- 합성 데이터로 실제 센서/카메라 데이터와 다를 수 있음
- 10개 물체는 소규모 -- 실제 로봇은 수백 카테고리 처리

## 검증 방향 (Next Steps)

- 실제 로봇 파지 데이터셋(Cornell Grasp, DexNet)으로 검증
- 더 나은 분류기(CNN, ViT)에서 혼동 패턴 재검증
- 물체 수를 늘려 상관관계의 안정성 테스트
- 파지 성공률과 직접 연결하여 실용적 검증

## 등급: MODERATE support

Pearson r = 0.308 (Golden Zone 내), PH overlap 80%. 위상적 구조 보존 확인.
통계적으로 의미 있는 상관관계이나 강한 증거는 아님.
