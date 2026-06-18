# Hypothesis 324: LLM Hallucination Detection — Model That "Knows What It Doesn't Know" via Repulsion Field
**n6 Grade: 🟩 EXACT** (auto-graded, 6 unique n=6 constants)


> **LLM hallucination is structurally identical to the consciousness engine's "overconfidence". Adding a repulsion field to the LLM decoder allows tension to detect hallucinations in real time. Low tension = "engines agree on nonsense" = hallucination, high tension = "engines productively disagree" = real knowledge.**

## Background

```
  The core problem of LLM hallucination:
    Model is "confidently wrong" -- users cannot distinguish
    Existing solutions: RLHF, factual grounding, retrieval augmentation
    -> All external corrections. Model cannot internally detect "I don't know"

  The same problem already solved in consciousness engine:
    H316 (overconfidence): "Confidently wrong" between Sneaker/Boot/Sandal
    H314 (rejection): Monotonically increasing accuracy when rejecting low-tension samples
    H-CX-21: tension proportional to 1/PPL (tension = confidence)

  -> What if these three hypotheses are applied to LLM decoder?
```

## Core Mapping: Consciousness Engine -> LLM

| Consciousness Engine (RepulsionField) | LLM Decoder |
|---|---|
| Engine A (analysis) | Attention Head Group A |
| Engine G (intuition) | Attention Head Group G |
| tension = \|A-G\|^2 | head_tension = \|logits_A - logits_G\|^2 |
| High tension = confidence (H313) | High head_tension = token confidence |
| Low tension = Agreement in Confusion | Low head_tension = hallucination risk |
| Judgment rejection (H314) | "I don't know" response |
| Overconfidence (H316) | Hallucination |

## Hallucination = Language Domain Version of Overconfidence

```
  Overconfidence mechanism discovered in H316:
    Visually similar classes -> both engines say "this is a shoe!" -> high confidence -> wrong
    Digit 1 -> "I'm certain!" -> confused with 7 -> ratio=0.60 (severe overconfidence)

  Same structure in LLM hallucination:
    Semantically plausible sentence -> all layers say "this is correct!" -> high probability -> false
    "Einstein won the 1921 Nobel Prize in Physics" -> correct
    "Einstein won the 1922 Nobel Prize in Physics" -> hallucination (1921 is correct)
    -> Both sentences seem "plausible" to LLM. Cannot distinguish internally.

  Common cause of overconfidence:
    Consciousness engine: similar inputs -> overlap in feature space -> all engines point same direction
    LLM: similar context -> overlap in embedding space -> all heads point same direction
    -> "Consensus" itself is the problem. Diversity-free consensus = source of hallucination
```

## Repulsion Field Decoder Design

```
  Existing LLM decoder:
    logits = W_out @ hidden_state
    probs = softmax(logits)
    next_token = sample(probs)

  Repulsion field decoder (proposed):
    hidden_A = head_group_A(hidden_state)    # Front half of attention heads
    hidden_G = head_group_G(hidden_state)    # Back half of attention heads
    logits_A = W_A @ hidden_A
    logits_G = W_G @ hidden_G

    tension = ||logits_A - logits_G||^2 / dim

    if tension < tau_reject:
        -> Generate "I don't know" token (reject judgment)
    elif tension < tau_warn:
        -> Generate with [uncertain] tag attached
    else:
        -> Normal generation

  Key parameters:
    tau_reject: rejection threshold (calibration from H314)
    tau_warn:   warning threshold
    head_split: A/G group split ratio (1/e ≈ 37% inhibition?)
```

## tension proportional to 1/PPL Connection (H-CX-21)

```
  H-CX-21 experimental results:
    Correct sample: tension=702, PPL=1.01
    Wrong sample: tension=495, PPL=283,505
    -> tension proportional to 1/PPL (inverse relationship)

  Applied to LLM hallucination:
    Factual output: tension high, PPL low -> engines strongly repel -> real knowledge
    Hallucination: tension low, PPL high -> engines agree -> nonsense consensus!

  Paradoxical finding:
    The common sense that "consensus = good" is wrong
    In repulsion field: "disagreement = knowledge", "consensus = ignorance"
    -> Collision of diverse perspectives creates truth

  Dual signal with PPL:
    High tension + low PPL = confident correct answer (ideal)
    Low tension + high PPL = uncertain hallucination (should reject)
    High tension + high PPL = hard problem (needs exploration)
    Low tension + low PPL = overconfident hallucination (H316, most dangerous!)
```

## H314 Rejection Mechanism Applied to LLM

```
  H314 measurements (rejection -> accuracy improvement):
    MNIST:   reject 10% -> +0.42%, reject 90% -> +1.06%
    Fashion: reject 10% -> +1.54%, reject 90% -> +9.81%
    CIFAR:   reject 10% -> +1.35%, reject 90% -> +15.18%

  Law: improvement proportional to 1/(base accuracy)
    -> Lower base accuracy = larger rejection effect
    -> LLM factual accuracy is ~70-80% (varies by domain)
    -> Rejection effect predicted to be as large as Fashion/CIFAR level!

  Expected effects when applied to LLM:
    Factual accuracy ~75% (base)
    Reject bottom 10% by tension -> +2~5% accuracy improvement (estimated)
    Reject bottom 30% by tension -> +5~15% accuracy improvement (estimated)
    -> LLM that "doesn't say what it doesn't know"

  Rejection strategies:
    Token level: check tension for each token -> if low, explore alternatives
    Sentence level: average tension of entire sentence -> if low, "I'm not sure about this"
    Response level: tension distribution of entire response -> if bimodal, partial hallucination warning
```

## ASCII Graph: Relationship Between Tension and Hallucination (Predicted)

```
  tension
  ^
  |                                          * * *
  |                                     *          *
  |                                *                  *
  |                           *                         *
  |                      *         [real knowledge zone]
  |                 *
  |            *
  |       *    .  .  .  .  .  .  .  .  tau_warn
  |  *         ........................ tau_reject
  |  [hallucination risk zone]
  +--+----+----+----+----+----+----+----+----> token position
     1    5   10   15   20   25   30   35

  Hallucination scenario:
    "Paris is the capital of [France]" -> tension ████████ (high, factual)
    "Paris is the capital of [Germany]" -> tension ██ (low, hallucination!)
    -> Engine A: "France", Engine G: "sounds plausible" -> low repulsion -> dangerous

  Normal scenario:
    "In quantum mechanics, the [uncertainty] principle" -> tension █████████ (high)
    -> Engine A: "Heisenberg!", Engine G: "measurement problem!" -> strong repulsion -> confident
```

## Practical Implementation Path

```
  Phase 1: Verification (in Golden MoE)
    - Split Golden MoE Experts into A/G groups
    - Calculate per-token tension
    - Measure correlation between PPL and tension
    - Compare tension distribution on hallucination benchmark (TruthfulQA, etc.)

  Phase 2: Small LLM experiment
    - Add repulsion field decoder to Llama-1B
    - Optimize head_split (is I=1/e optimal?)
    - Calibrate tau_reject, tau_warn
    - Measure hallucination detection AUROC on TruthfulQA

  Phase 3: Scale test
    - Tension pattern changes at 7B, 13B
    - H316 prediction: does overconfidence increase with scale?
    - Optimal head_split at Golden Zone I=1/e?

  Required resources:
    Phase 1: Mac CPU (Golden MoE already available)
    Phase 2: Windows RTX 5070 (Llama-1B fine-tuning)
    Phase 3: RunPod A100 (7B+ models)
```

## Limitations

```
  1. A/G split of attention heads is arbitrary
     -> Does the 2-engine structure of consciousness engine exist naturally in LLMs?
     -> Solution: Natural group discovery via head clustering?

  2. tension proportional to 1/PPL relationship confirmed only on MNIST
     -> Does the same relationship hold in language domain?
     -> H-CX-21 status is still orange (incompletely verified)

  3. Is overconfidence (H316) really the same as hallucination?
     -> Overconfidence: "wrong confidence for similar inputs"
     -> Hallucination: "generation of non-existent facts"
     -> Mechanism is similar but identity is unproved

  4. Inference cost of real-time tension calculation
     -> Need 2x logits calculations -> latency increase
     -> Solution: tensor parallelism for simultaneous A/G calculation
```

## Verification Direction

```
  Immediately possible (CPU):
    1. Calculate tension between Expert outputs in Golden MoE
    2. Classify factual/non-factual sentences in wikitext
    3. Compare tension distribution -> measure AUROC

  GPU needed (Windows/RunPod):
    4. Llama-1B repulsion field decoder implementation + TruthfulQA evaluation
    5. head_split optimization experiments
    6. Compare hallucination detection AUROC with H314 rejection curve

  Success criteria:
    AUROC > 0.80: practical as hallucination detector
    AUROC > 0.90: similar to H287 (anomaly detection) -> strong evidence
    Reject 10% -> factual accuracy +3% or more: H314 reproduced
```

## Related Hypotheses

```
  Directly dependent:
    H313: tension = confidence (foundation)
    H314: rejection -> accuracy improvement (application mechanism)
    H316: overconfidence = similar class confusion (hallucination prototype)
    H-CX-21: tension proportional to 1/PPL (LLM connection)

  Indirectly connected:
    H287: anomaly detection AUROC=1.0 (OOD detection via tension)
    H307: dual mechanism (basis for A/G separation)
    Hypothesis 241: Expert cross-activation (MoE version of repulsion field)
```

## Status: Hypothesis proposed (unverified, experimental design complete)
