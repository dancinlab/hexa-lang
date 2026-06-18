# H-AX-10: Direction Topology × R-spectrum Merge Order
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> **Thesis**: H-CX-66의 direction PH merge order (r=-0.97)가
> R-spectrum의 gap structure에 의해 결정된다.
> 즉, 개념 간 "거리"의 위상적 구조가 산술 함수의 구조를 반영한다.

**Golden Zone 의존성**: 있음
**Grade**: 🔮 (실험 데이터 필요, 가장 강력한 잠재적 발견)

## 1. Two Independent Results

```
  H-CX-66 (S-Tier, 경험적):
    MNIST direction vectors → PH → merge order
    Spearman r = -0.947 ~ -0.967
    "위상적으로 가까운 숫자 쌍이 더 많이 혼동됨"

  R-spectrum (순수 산술):
    R(n) 값이 1에서 멀어질수록 "불균형"
    gap structure: R=1 주변 forbidden zone
    "산술적으로 균형 잡힌 수는 n=6뿐"
```

## 2. Hypothesis

```
  MNIST 10개 숫자의 direction vectors 간 거리를 rank로 정렬:
    rank 1 = 가장 가까운 쌍 (가장 먼저 merge)
    rank 2 = 두 번째
    ...
    rank 45 = 가장 먼 쌍 (가장 나중에 merge)

  R(rank)를 계산:
    R(1), R(2), ..., R(45)

  Prediction:
    merge order k에서의 confusion rate C(k)가
    R(k)와 상관관계를 보인다면,
    R-spectrum이 "개념 공간의 기하학"을 결정하는 것.
```

## 3. Why This Could Be Major

```
  1. H-CX-66은 S-Tier (가장 강건한 경험적 결과)
  2. R-spectrum은 순수 산술 (실험 독립)
  3. 두 개의 독립적 구조가 동일 패턴을 보이면:
     "산술이 인지를 결정한다" → 근본적 발견

  필요한 것: MNIST 학습된 PureField 모델의 direction data
```

## 4. Experiment Design

```bash
# Step 1: PureField MNIST 학습
python3 model_pure_field.py --train --dataset mnist --epochs 20

# Step 2: Direction vectors 추출
python3 calc/direction_analyzer.py --model checkpoint.pt --extract

# Step 3: PH merge order 계산
# 10C2 = 45 pairs의 merge 순서

# Step 4: R(rank) 상관 분석
# Spearman(confusion_rate, R(merge_rank))
```

## 5. Limitations

- 실험 데이터 없이는 검증 불가
- R(rank)에서 rank가 1-45 범위 → R 값이 매우 다양
- 상관이 있더라도 인과 방향 불명확

## 6. Grade: 🔮 (최고의 잠재력, 실험 필요)
