# Hypothesis 300: Hierarchical Mitosis Anomaly Detection — Mitosis Tree Classifies Anomaly "Types"
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


> **Multi-level mitosis (parent→2→4→8) reflects the hierarchical structure of anomalies. First-generation inter-child tension detects "broad classification" (normal vs anomaly), second-generation detects "middle classification" (anomaly type A vs B), third-generation detects "fine classification". Mitosis tree = anomaly classification tree.**

## Concept

```
  Mitosis Tree:
           parent
          /      \
      child_a   child_b          <- Generation 1: broad detection
      /   \     /   \
    c_aa c_ab c_ba c_bb          <- Generation 2: fine detection
    / \  / \  / \  / \
   ...                           <- Generation 3: micro detection

  Anomaly Detection Mechanism:
    Generation 1 tension: |child_a(x) - child_b(x)|² -> "is it an anomaly?"
    Generation 2 tension:
      |c_aa(x) - c_ab(x)|² -> "is it anomaly type A?"
      |c_ba(x) - c_bb(x)|² -> "is it anomaly type B?"
    Generation 3: even finer distinction

  Analogy: Doctor's diagnostic process
    Step 1: "Not normal" (abnormal blood test)
    Step 2: "Infection vs autoimmune" (CRP, ESR)
    Step 3: "Bacterial vs viral" (culture, PCR)
```

## Verification Experiment

```
  Data: Multiple anomaly types
    Normal: digit 0
    Anomaly A: digit 1 (straight line, very different from normal)
    Anomaly B: digit 6 (curved, similar to normal)
    Anomaly C: digit 8 (double curve, intermediate)

  Experiment:
    1. Train parent (digit 0 only)
    2. 2nd-generation mitosis (4 children)
    3. Test:
       a) Generation 1 tension: distinguish digit 0 vs rest -> AUROC_1
       b) Generation 2 tension: distinguish anomaly types (1 vs 6 vs 8) -> AUROC_2
    4. Compare:
       Single engine: can it distinguish anomaly types?
       Mitosis tree: can it distinguish anomaly types too?

  Key question: Does mitosis depth determine anomaly classification resolution?
```

## Mathematical Structure

```
  Mitosis Tree <-> Binary Tree Classifier
    Depth d -> 2^d leaves -> 2^d different anomaly types distinguishable
    Information: d × ln(2) bits

  H-CX-1 connection:
    e^(6H) = 432 = σ³/τ
    6H = ln(432) ≈ 6.07
    -> H ≈ 1.01 nats ≈ 1.46 bits

  Mitosis depth and entropy:
    Depth 1: 1 bit (normal vs anomaly)
    Depth 2: 2 bits (4 types)
    Optimal depth d*: H / ln(2) ≈ 1.46 -> about 1.5 generations?
    -> 2-generation mitosis is optimal?
```

## ASCII Hierarchy

```
  depth 0: [parent]
             │
  depth 1: [A]───[B]          T_AB = "is it an anomaly?"
            │     │
  depth 2: [aa][ab][ba][bb]   T_pairs = "what kind of anomaly?"
            │              │
  depth 3: (16 leaves)       T_fine = "what variant?"

  AUROC vs depth:
    depth 0: 0.50 (random)
    depth 1: 0.80 (H296 measured)
    depth 2: 0.90? (predicted)
    depth 3: 0.95? (predicted, saturation starts)
```

## Related Hypotheses

```
  296: Inter-mitosis AUROC 0.805
  297: Number of mitoses -> AUROC increases
  298: Optimal differentiation on time axis
  292: Consciousness tree expansion
  291: Data type tree
```

## Status: 🟨 Untested
