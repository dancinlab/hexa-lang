# H-402: Golden MoE PH-Guided Routing
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


> **Hypothesis:** Augmenting Golden MoE's gating mechanism with Persistent Homology (PH)
> of input representations — as topological signatures per expert — will improve routing
> precision beyond pure gate-score thresholding, yielding higher accuracy, more balanced
> expert utilization, and a principled trigger for automatic expert mitosis.
> The routing formula becomes:
> `effective_score_i(x) = gate_i(x) × PH_match_i(x)`
> where PH_match_i measures Wasserstein distance between input topology and expert signature.

---

## Background

### Golden MoE Baseline

Golden MoE replaces Top-K expert selection with Golden Zone-based Boltzmann gating.
The key insight is that the optimal inhibition threshold maps to I ≈ 1/e ≈ 0.368,
the center of the Golden Zone [1/2 - ln(4/3), 1/2] ≈ [0.212, 0.500].

Empirical results (existing, verified):

| Dataset   | Top-K MoE | Golden MoE | Delta     |
|-----------|-----------|------------|-----------|
| MNIST     | 97.1%     | 97.7%      | +0.6%     |
| CIFAR-10  | 48.2%     | 53.0%      | +4.8%     |
| Scale gap |           |            | grows ~8x |

Current routing pipeline:

```
  input x
    |
    v
  W_g × x  (gating projection)
    |
    v
  softmax → gate_scores [g_1, g_2, ..., g_k]
    |
    v
  select {expert_i : g_i > I_threshold}   where I_threshold ≈ 1/e
    |
    v
  weighted expert combination
```

This selects experts based on WHAT the input activates in the gating projection.
It has no information about HOW the input is internally structured.

### The Gap: Structure-Blind Routing

Two inputs can produce identical gate scores while having completely different
topological structure. Example:

- Input A: "The dog ran fast." — simple chain topology, one concept cluster
- Input B: "If speed implies energy and energy implies heat, then speed implies heat."
           — transitive chain topology, three linked clusters

If W_g × A ≈ W_g × B (similar gating projections), both route to the same expert.
But they require fundamentally different processing (syntax vs. logical inference).

PH captures this structural difference where gate scores cannot.

---

## Core Hypothesis: PH-Weighted Gating

### Modified Routing Formula

```
  Standard:  effective_score_i(x) = gate_i(x)
  Proposed:  effective_score_i(x) = gate_i(x) × PH_match_i(x)
```

Where:

```
  PH_match_i(x) = 1 - d_W(barcode(x), signature_i)
                       ---------------------------------
                             max_distance
```

- `barcode(x)` = PH barcode of x's hidden representation at the routing layer
- `signature_i` = stored topological signature of expert i (built during training)
- `d_W` = Wasserstein-1 distance between barcodes
- Normalized so PH_match_i ∈ [0, 1]

Expert i activates when: `gate_i(x) × PH_match_i(x) > I_threshold`

Golden Zone dependency note:
- The I_threshold ≈ 1/e gating is **Golden Zone dependent** (unverified model)
- The PH computation and Wasserstein matching are **GZ-independent** (pure topology)
- This hypothesis can be tested with fixed I_threshold = 0.368 as a constant

---

## Architecture Diagram

```
  ┌─────────────────────────────────────────────────────────────┐
  │                  PH-Enhanced Golden MoE Router               │
  └─────────────────────────────────────────────────────────────┘

  Input x (token embedding or hidden state)
       │
       ├──────────────────────┬──────────────────────────┐
       │                      │                          │
       v                      v                          v
  ┌─────────┐          ┌──────────────┐          ┌───────────────┐
  │ Gating  │          │ PH Extractor │          │ Expert Sigs   │
  │  W_g×x  │          │  (Ripser)    │          │ (stored)      │
  │softmax  │          │              │          │ sig_1,sig_2,  │
  └────┬────┘          └──────┬───────┘          │ sig_3,...     │
       │                      │                  └───────┬───────┘
       │               barcode(x)                        │
       │                      │                          │
       │               ┌──────v──────────────────────────v───┐
       │               │   Wasserstein Distance Computation   │
       │               │   PH_match_i = 1 - d_W(barcode(x),  │
       │               │               signature_i) / max_d  │
       │               └──────────────────┬──────────────────┘
       │                                  │ [ph_1, ph_2, ph_3, ...]
       │                                  │
       v                                  v
  [g_1, g_2, g_3, ...]          ─────────────────────
        │                       effective_score_i =
        └───────── × ────────── gate_i × PH_match_i
                                ─────────────────────
                                         │
                                         v
                              ┌──────────────────────┐
                              │ Threshold: I ≈ 1/e   │
                              │  (Golden Zone center) │
                              │  or dynamic I(x)      │
                              └──────────┬───────────┘
                                         │
                              select active experts
                                         │
                              ┌──────────v───────────┐
                              │ Expert 1  Expert 2   │
                              │ Expert 3  ...        │
                              └──────────────────────┘
```

---

## Expert Topological Signatures

### Training Phase: Building Signatures

During training, for each expert i, track PH barcodes of its best-routed inputs:

```
  For each training batch:
    For each expert i:
      inputs_i = {x : gate_i(x) > I_threshold}  (inputs routed to expert i)
      top_inputs_i = top-k(inputs_i, by loss improvement)
      barcodes_i += [PH(x) for x in top_inputs_i]

  After training:
    signature_i = Frechet_mean(barcodes_i)  (or centroid barcode)
```

### Example Topological Signatures by Expert Type

```
  Expert 1 — Syntax Specialist
  Barcode: many short H0 bars, few H1 bars
  ─ H0: ████████████████████  (many components, quick merges)
  ─ H0: ██████████
  ─ H0: ████
  ─ H1: ─  (no loops)
  → Inputs: simple sequential text, single-clause sentences

  Expert 2 — Logic/Inference Specialist
  Barcode: moderate H0, significant H1 chains
  ─ H0: ████████████████████
  ─ H0: ████████████████
  ─ H1: ████████████  (loops = cyclic dependencies)
  ─ H1: ████████
  → Inputs: if-then chains, proofs, recursive definitions

  Expert 3 — Metaphor/Cross-domain Specialist
  Barcode: few persistent H0, long H1 bridges
  ─ H0: ████████████████████
  ─ H1: ████████████████████  (long = cross-domain bridges)
  ─ H1: ████████████
  → Inputs: analogies, cross-domain references, similes
```

---

## Routing Comparison: 3 Example Inputs

```
  Input A: "The cat sat on the mat."
  ─────────────────────────────────
  Gate scores:    [0.42, 0.38, 0.35, 0.31]
  PH_match:       [0.91, 0.34, 0.21, 0.55]
  Effective:      [0.38, 0.13, 0.07, 0.17]
  Standard route: {Expert 1, Expert 2}    (both above I=0.368)
  PH route:       {Expert 1}              (only Expert 1 above threshold)
  Topology:       Simple syntax → syntax expert only  CORRECT

  Input B: "If A implies B and B implies C, then A implies C."
  ──────────────────────────────────────────────────────────
  Gate scores:    [0.41, 0.39, 0.36, 0.33]
  PH_match:       [0.35, 0.92, 0.28, 0.48]
  Effective:      [0.14, 0.36, 0.10, 0.16]
  Standard route: {Expert 1, Expert 2}    (similar to Input A, WRONG)
  PH route:       {Expert 2}              (logic expert only)  CORRECT
  Topology:       Chain reasoning → logic expert  CORRECT

  Input C: "Love is like a red, red rose."
  ────────────────────────────────────────
  Gate scores:    [0.40, 0.37, 0.38, 0.34]
  PH_match:       [0.28, 0.31, 0.88, 0.52]
  Effective:      [0.11, 0.11, 0.33, 0.18]
  Standard route: {Expert 1, Expert 2, Expert 3}  (all near-tied, WASTES experts)
  PH route:       {}  (none above 0.368 — signals ambiguity, fallback to lower I)
  Topology:       Cross-domain → metaphor expert needed, triggers I reduction
```

The PH routing correctly separates inputs that gate scores treat as equivalent.

---

## Dynamic I Threshold: Confusion-Aware Routing

From H-CX-76 (PH confusion classifier) and H-CX-82 (epoch 1 confusion map):

```
  PH_clarity(x) = 1 / H0_total_persistence(x)
               (fewer/shorter H0 bars = clearer single concept)

  I(x) = I_base + gamma × PH_clarity(x)
        where I_base ≈ 1/e ≈ 0.368
        and   gamma ∈ [0.05, 0.15]
```

Effect on routing:

```
  PH_clarity axis:
  Low clarity                              High clarity
  (confusing input)                        (clear input)
  |<─────────────────────────────────────────────────>|
  0.0                                               1.0

  I threshold:
  I_base=0.368                                  I_max~0.48
  |░░░░░░░░░░░░│████████████████████████████████████│
               I_base                             I_max

  Low clarity → I stays near 0.368 → MORE experts activate → thorough
  High clarity → I rises toward 0.48 → FEWER experts activate → efficient

  System self-regulates:
  - Confusing input: activates 3-4 experts (cross-check)
  - Clear input:     activates 1-2 experts (efficient)
```

Dynamic I threshold diagram:

```
  I(x)
  0.50 │                                      ●●●●●●●
  0.46 │                             ●●●●●●●●●
  0.42 │                    ●●●●●●●●●
  0.38 │●●●●●●●●●●●●●●●●●●●●  ← I_base = 1/e
  0.34 │
       └────────────────────────────────────────────
       0.0    0.2    0.4    0.6    0.8    1.0
                     PH_clarity(x)
```

---

## Mitosis Trigger via PH Variance

Connection to H-376 (Structural growth via mitosis):

```
  For expert i, compute PH variance across routed inputs:

  PH_var_i = mean_x [ d_W(barcode(x), signature_i)^2 ]

  If PH_var_i > tau_split:
    TRIGGER MITOSIS:
    1. Cluster inputs routed to expert i by PH similarity
    2. Create two child experts: expert_i_A and expert_i_B
    3. Assign inputs to child experts by cluster
    4. Retrain child experts from parent weights
    5. Update router to treat parent as two specialists
```

This gives a CONCRETE implementation mechanism for H-376:

```
  Before mitosis:
  Expert 2 handles: logic chains + recursive definitions + set theory
  PH_var_2 = 0.73  (HIGH — too broad)

  After mitosis:
  Expert 2A handles: logic chains + transitive reasoning
                     PH_var_2A = 0.21  (low — specialized)
  Expert 2B handles: recursive definitions + self-reference
                     PH_var_2B = 0.19  (low — specialized)
```

Mitosis threshold tau_split is a hyperparameter; starting value tau_split = 0.5
to be tuned empirically.

---

## Predicted Improvements

Based on Golden MoE baseline and PH utility demonstrated in H-CX-58~82:

| Metric              | Golden MoE (current) | + PH Routing (predicted) | Change         |
|---------------------|----------------------|--------------------------|----------------|
| MNIST accuracy      | 97.7%                | 98.2 - 98.5%             | +0.5 - 0.8%    |
| CIFAR-10 accuracy   | 53.0%                | 56 - 60%                 | +3 - 7%        |
| Expert utilization  | ~35% active          | ~40-45% active           | +5-10%         |
| Routing entropy     | low (clustered)      | higher (balanced)        | better coverage|
| Hallucination rate  | baseline             | -15 - 25%                | significant     |
| Routing overhead    | 0 ms (pure gate)     | +10 - 20% (PH compute)   | acceptable      |
| Mitosis events      | manual/none          | automatic                | structural      |

CIFAR improvement predicted larger because:
- CIFAR-10 has structurally diverse inputs (10 classes with distinct topology)
- Gate scores alone conflate structurally different but semantically adjacent classes
  (e.g., automobile vs. truck: similar gate scores, different spatial topology)
- MNIST is near ceiling (97.7%), limited room for improvement

---

## Implementation Plan

### Phase 1 — PH extraction layer (no routing change)
- Add PH computation to `golden_moe_torch.py` at the routing layer
- Use `ph_module.py` (Ripser wrapper) for lightweight barcode computation
- Log barcodes per expert during training (do not yet modify routing)
- Measure computational overhead

### Phase 2 — PH-weighted routing
- Implement `PH_match_i(x)` using stored per-expert signatures
- Multiply gate scores: `effective_score_i = gate_i × PH_match_i`
- Compare MNIST and CIFAR accuracy vs. baseline Golden MoE
- Ablation: gate-only vs. PH-only vs. combined

### Phase 3 — Dynamic I threshold
- Implement `PH_clarity(x)` computation
- Implement `I(x) = I_base + gamma × PH_clarity(x)`
- Grid search: gamma ∈ {0.05, 0.08, 0.10, 0.12, 0.15}
- Measure accuracy vs. expert activation rate tradeoff

### Phase 4 — Mitosis trigger
- Implement PH variance tracking per expert
- Set initial tau_split = 0.5
- Start with 2 experts, allow system to grow to optimal count
- Measure final expert count vs. accuracy

---

## Connection to Existing Framework

| Hypothesis | Connection |
|------------|------------|
| H-019      | Golden MoE performance baseline to beat |
| H-CX-58~69 | PH precognition: topology predicts convergence, here topology guides routing |
| H-CX-76    | PH confusion classifier: confused inputs need more experts |
| H-CX-82    | Epoch 1 confusion map: confusion structure is topologically stable |
| H-327      | Golden MoE tension-PPL: tension predicts PPL; PH refines prediction |
| H-376      | Structural growth via mitosis: PH variance triggers expert splitting |
| H-341      | Tension final theory: PH-match acts as structural tension signal |

---

## Limitations

1. **PH computation cost**: Ripser is fast for small representations (d ≤ 512),
   but at token level for large LLMs this adds 10-30% overhead. Approximations
   (subsampling, dimension reduction) will reduce quality of signatures.

2. **Signature quality depends on training distribution**: If training inputs are
   not topologically diverse, expert signatures will cluster together and PH_match
   will not discriminate. Requires diverse training corpus.

3. **Golden Zone dependency**: The I_threshold ≈ 1/e is GZ-dependent (unverified model).
   The PH computation itself is GZ-independent. Testing with fixed I=0.368 avoids
   this dependency, but the theoretical justification for the threshold remains
   model-level.

4. **Wasserstein distance is not differentiable**: Cannot backpropagate through
   PH_match directly. The PH signatures must be updated by tracking (not gradient).
   Sliced Wasserstein or topological loss approximations exist but add complexity.

5. **Expert signature drift**: As model trains, the effective topological space of
   each expert shifts. Signatures must be periodically recomputed (e.g., every epoch),
   adding training complexity.

6. **Mitosis instability**: Splitting experts mid-training can destabilize the router
   if both child experts begin with identical weights. Requires careful initialization
   (e.g., adding noise in opposite PH directions).

---

## Verification Direction

1. Run baseline Golden MoE on CIFAR-10, record per-class accuracy
2. Add PH barcode logging (Phase 1), measure overhead
3. Implement PH_match, compare routing decisions on held-out examples
4. Run Phase 2 experiment: does combined routing beat gate-only?
5. Key check: do different expert pairs specialize to topologically distinct input clusters?
6. If Phase 2 confirms, proceed to dynamic I (Phase 3)
7. Final: mitosis experiment — start 2 experts, measure grown structure

**Primary metric**: CIFAR-10 accuracy vs. Golden MoE baseline (53.0%)
**Secondary metric**: Expert utilization entropy (higher = more balanced)
**Tertiary metric**: Routing overhead (must be < 30% additional latency)

---

## GZ Dependency Summary

| Component                    | GZ Dependent? | Notes                               |
|------------------------------|---------------|-------------------------------------|
| PH barcode extraction        | No            | Pure topology, GZ-independent       |
| Wasserstein distance         | No            | Standard metric geometry            |
| PH_match_i computation       | No            | GZ-independent                      |
| I_threshold = 1/e            | Yes           | GZ model (unverified)               |
| Dynamic I(x) base value      | Yes           | Inherits GZ dependency              |
| Mitosis trigger (PH var)     | No            | Threshold tau_split is empirical    |
| Expert signature learning    | No            | Data-driven, GZ-independent         |

PH routing is largely GZ-independent and can be tested as a standalone improvement
to any MoE system, not just Golden MoE. The GZ dependency enters only through
the choice of I_threshold, which can be treated as a tunable hyperparameter.
