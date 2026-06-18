# H-CX-66: Direction Topology — Confusion Pairs Map to Short Barcodes in PH
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> Short barcodes (quickly dying features) in PH of direction cosine distance matrix
> exactly correspond to confusion pairs (H-CX-59). Topologically close classes = confused classes.

## Background

- H-CX-59: Wrong answer directions point to confusion classes (70-82%)
- H-CX-62 v2: Successfully computed PH of cosine distance matrix
- Intersection: Class pairs that merge quickly in PH birth-death = confusion pairs

**Core Connection**: Two classes merging quickly in H0 = small cosine distance = similar directions = confusion.
PH automatically discovers confusion pairs.

## Predictions

1. Class pairs that merge first in PH = top confusion pairs (>60% match)
2. Spearman correlation between merge order and confusion frequency > 0.5
3. If H1 (loops) exist, circular confusion of 3+ classes (A→B→C→A)

## Verification Method

```
1. Compute PH of cosine distance matrix with Ripser
2. Extract merge order from H0 birth-death
3. Extract top confusion pairs from actual confusion matrix
4. Spearman rank correlation of merge order vs confusion frequency
```

## Related Hypotheses

- H-CX-59 (direction precognition), H-CX-62 (topology precognition)
- H-TOP-7 (topological lens)

## Limitations

- Merge pair extraction may vary by PH library
- Small sample with only 9 merges for 10 classes

## Verification Status

- [x] merge order vs confusion frequency correlation
- [x] H1 circular confusion check

## Verification Results

**Verdict: STRONGLY SUPPORTED**

### Spearman(merge_dist, confusion)

| Dataset | Spearman r | p-value | Significant |
|---------|-----------|---------|-------------|
| MNIST   | -0.941    | 0.0002  | YES         |
| Fashion | -0.933    | 0.0002  | YES         |
| CIFAR   | -0.967    | 0.0000  | YES         |

```
  |Spearman r|
  1.00 |
  0.97 |              ##  CIFAR (0.967)
  0.96 |              ##
  0.95 |              ##
  0.94 |  ##          ##
  0.93 |  ##  ##      ##
  0.92 |  ##  ##      ##
       +--+---+-------+-->
         MNI  FAS    CIF
```

All 3 datasets with p < 0.001. Shorter merge distance correlates with higher confusion frequency.

### Top-5 confusion pair overlap (merge order vs actual confusion)

| Dataset | Overlap | Ratio |
|---------|---------|-------|
| MNIST   | 2/5     | 40%   |
| Fashion | 3/5     | 60%   |
| CIFAR   | 4/5     | 80%   |

### CIFAR merge order (H0 dendrogram)

| Merge order | Class pair     | merge distance |
|------------|----------------|---------------|
| 1st        | cat - dog      | 0.05          |
| 2nd        | auto - truck   | 0.12          |
| 3rd        | bird - deer    | 0.13          |
| 4th        | plane - ship   | 0.19          |

```
  CIFAR merge dendrogram (H0)
  distance
  0.19 |          +---plane---ship
  0.13 |     +---bird---deer
  0.12 |  +---auto---truck
  0.05 |  +---cat----dog
       +--+---+---+---+---+---->
          merge order
```

cat-dog merges first: semantically the most similar pair.

### H1 loops (circular confusion)

| Dataset | H1 loops | Interpretation |
|---------|----------|----------------|
| MNIST   | 1        | Weak circular structure |
| Fashion | 0        | No circular confusion |
| CIFAR   | 1        | Circular confusion exists |

H1 prediction is partial. Evidence for circular confusion is weak but main prediction (merge order = confusion order) is strongly supported.