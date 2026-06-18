# H-CX-443: Small World Coefficient in Golden Zone
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


**Golden Zone Dependency: YES** (interpretation depends on Golden Zone model)

## Hypothesis

> Neural network weight graphs exhibit small-world properties, and the small-world coefficient
> sigma_SW lands in the Golden Zone [0.212, 0.500]. More specifically, the clustering ratio
> C/C_rand converges to 1/e and the path length ratio L/L_rand converges to sigma_{-1}(6) = 2.

## Background

Small-world networks (Watts-Strogatz, 1998) are characterized by high clustering and short
path lengths. The small-world coefficient sigma_SW = (C/C_rand) / (L/L_rand) measures
how "small-world" a network is. If trained neural networks develop small-world structure,
and that structure lands in the Golden Zone, it would connect network topology to the
TECS-L constant system.

Related hypotheses:
- H-066: topology of meta-learning
- H-139: Golden Zone = edge of chaos (Langton lambda_c = 0.27)

## Method

1. Train 5 MLPClassifiers on sklearn digits (hidden sizes: 32, 64, 128, 256, 512)
2. Construct weight graph: nodes = neurons, edges = weights above threshold (mean + std)
3. Compute clustering coefficient C, average path length L
4. Compare with Erdos-Renyi random graphs (5 samples per network)
5. sigma_SW = (C/C_rand) / (L/L_rand)
6. Compare trained vs untrained (random initialization) networks

## Key Finding: Bipartite Structure Invalidates sigma_SW

Weight graphs of feedforward networks are **bipartite** (input-layer nodes connect only to
hidden-layer nodes). Bipartite graphs have **zero clustering coefficient** (no triangles
possible), which makes the small-world coefficient sigma_SW = 0 for all networks.

```
  Neural Network Weight Graph Structure:

  Input Layer (64 nodes)    Hidden Layer (h nodes)
       o ─────────────────── o
       o ────────────╲╱───── o
       o ────────────╱╲───── o
       o ─────────────────── o

  Bipartite: no edges within layers -> C = 0 always
```

## Verification Results

| Hidden | Accuracy | sigma_SW | C/C_rand | L/L_rand | In GZ? |
|--------|----------|----------|----------|----------|--------|
|     32 |   0.975  |   0.000  |   0.000  |   1.109  |   no   |
|     64 |   0.978  |   0.000  |   0.000  |   1.094  |   no   |
|    128 |   0.981  |   0.000  |   0.000  |   1.093  |   no   |
|    256 |   0.986  |   0.000  |   0.000  |   1.034  |   no   |
|    512 |   0.975  |   0.000  |   0.000  |   0.938  |   no   |

## Path Length Ratio is Informative

While C=0 invalidates sigma_SW, the path length ratio L/L_rand shows structure:

```
  L/L_rand vs Network Size

  1.12 |*
  1.10 | *
  1.08 |  *
  1.06 |
  1.04 |   *
  1.02 |
  1.00 |....................... L/L_rand = 1 (random baseline)
  0.98 |
  0.96 |
  0.94 |    *
       +---+---+---+---+---+
        32  64  128 256 512
                Hidden size
```

- 작은 네트워크(32-128): L/L_rand > 1 (랜덤보다 긴 경로)
- 큰 네트워크(512): L/L_rand < 1 (랜덤보다 짧은 경로, 효율적)
- 전환점이 약 256-512 사이에 존재

## Salvageable Direction: Multi-Layer Projected Graphs

Bipartite 문제를 해결하려면 weight graph를 **projection**해야 함:
- 두 input node가 같은 hidden node에 강하게 연결되면 projected edge 생성
- 이렇게 하면 clustering coefficient가 0이 아닌 값을 가짐
- 또는 multi-layer 네트워크의 activation correlation graph 사용

```
  Projection method:

  Input space projection:
    node_i --- node_j  if  sum_k(W_ik * W_jk) > threshold

  This creates non-bipartite graph with meaningful clustering
```

## 해석 (Interpretation)

가설은 **기각(refuted)**되었으나 흥미로운 구조적 이유가 있음:

1. **Feedforward 네트워크의 weight graph는 본질적으로 bipartite** - 이 사실 자체가 중요한 관찰
2. **L/L_rand는 네트워크 크기에 따라 체계적으로 변화** - 1.0 근처를 통과하는 전환점 존재
3. **RNN이나 Transformer의 attention graph에서는 non-bipartite** - 이 경우 sigma_SW 측정 가능

## Limitations

- Feedforward 네트워크만 테스트 (bipartite structure가 불가피)
- Threshold 선택이 결과에 영향 (mean + std 사용)
- sklearn digits는 작은 데이터셋 (1797 samples)
- Projected graph에서의 재검증 미수행

## Verification Direction

1. **Weight projection graph**에서 sigma_SW 재측정 (bipartite 해결)
2. **RNN/Transformer attention graph**에서 small-world 검증
3. **Activation correlation graph** (functional connectivity) 분석
4. **Convolutional network**의 filter correlation graph 분석
5. L/L_rand의 전환점이 Golden Zone width와 관련있는지 확인

## Grade: Refuted (bipartite structure)

sigma_SW = 0 for all tested networks due to inherent bipartite structure
of feedforward weight graphs. Hypothesis needs reformulation for projected
or functional connectivity graphs.

---

*Verified: 2026-03-26 | Script: docs/hypotheses/verify_443.py*
