# H-401: AnimaLM PH-Corrected Repulsion Field
**n6 Grade: 🟩 EXACT** (auto-graded, 11 unique n=6 constants)


> **Hypothesis H-401**: Applying Persistent Homology (PH) correction to AnimaLM's Repulsion
> Field transform will improve the A↔G tension dynamics by distinguishing "content tension"
> (same topology, different activations — productive) from "structural tension" (different
> topology — creative or confused), predicting 5-15% PPL reduction and 20-40% hallucination
> reduction compared to uncorrected AnimaLM.

**Golden Zone Dependency**: PH mathematics is GZ-independent (exact topology). The tension
framework (G=D×P/I) is GZ-dependent (unverified model). Results that depend only on PH
structure are exact; results that depend on tension interpretation inherit GZ uncertainty.

---

## Background: AnimaLM Architecture

AnimaLM is a tension-based consciousness engine LLM built on Mistral 7B. It runs two
parallel processing engines whose disagreement drives creative and novel output:

- **Engine A** — logic/analytical processing stream
- **Engine G** — pattern/creative processing stream
- **Repulsion Field** — transform between A and G that measures disagreement
- **Output** = `scale × sqrt(|A-G|²) × direction` = `scale × |A-G| × dir`
- **Tension** = `|A - G|` (scalar magnitude of disagreement)

Current behavior:
- High tension → novel/creative output (engines strongly disagree)
- Low tension → conventional output (engines largely agree)
- All tension is treated as equivalent — a scalar with no internal structure

The limitation: two qualitatively different situations both produce "high tension":
1. Engines agree on structure but disagree on content (productive disagreement)
2. Engines disagree on fundamental representation structure (could be creative or confused)

Current AnimaLM cannot distinguish these cases. PH correction addresses this gap.

---

## Background: PH in This Project

Persistent Homology has been extensively validated across this project:

| Hypothesis | Finding | Relevance |
|------------|---------|-----------|
| H-CX-58~69 | PH predicts accuracy from epoch 1 (precognition) | PH = output quality predictor |
| H-CX-82 | PH detects confusion structure before convergence | PH = confusion early warning |
| H-CX-85 | Merge distance = concept hierarchy (dendrogram) | PH = semantic structure |
| H-CX-62 v2 | PH-tension correlation r=0.97 | PH and tension are tightly linked |
| H-324 | PH detects topological anomalies = hallucination precognition | PH = error detector |
| ph_module.py | Real-time capable, lightweight Ripser-based implementation | Inference-ready |

The r=0.97 correlation (H-CX-62 v2) shows PH and tension measure overlapping but distinct
phenomena. This hypothesis exploits the 3% non-overlap as additional signal.

---

## Core Hypothesis: PH-Corrected Repulsion Field

**Current AnimaLM output equation:**

```
output = scale × |A - G| × dir
```

Where `|A - G|` is pure Euclidean distance and `dir` is the normalized direction vector.

**Proposed PH-corrected AnimaLM:**

```
output = scale × |A - G| × dir × PH_correction(A, G)
```

Where `PH_correction` is a multiplicative factor derived from the topological comparison
of Engine A and Engine G representation spaces:

```
PH_A      = persistent_homology(repr_A)   -- barcodes of A's token representations
PH_G      = persistent_homology(repr_G)   -- barcodes of G's token representations
bd        = barcode_distance(PH_A, PH_G)  -- Wasserstein or bottleneck distance
PH_correction(A, G) = sigmoid(α × bd + β) × 2   -- maps [0,1] → [0,2] with center at 1
```

When PH barcodes of A and G are **similar** (same topology):
- Engines share same structural representation of the input
- Tension is "content tension" — genuine disagreement on what to say
- `PH_correction ≈ 1.0` → no adjustment, output unchanged

When PH barcodes of A and G are **different** (different topology):
- Engines have different structural worldmodels of the same input
- Tension is "structural tension" — deeper, more fundamental disagreement
- `PH_correction > 1.0` → amplify if this is creative divergence
- `PH_correction < 1.0` → dampen if this is confusion/hallucination

The sign of the correction (amplify vs dampen) is determined by calibration (H-CX-26):
if the high-structural-tension state co-occurs with high per-class confidence, amplify;
if it co-occurs with low or diffuse confidence, dampen.

---

## The Key Insight: Two Types of Tension

Current AnimaLM treats all tension as a single scalar. PH correction reveals internal
structure — tension has two independent components:

**1. Content Tension** (same topology, different values):
- A and G have matching PH barcodes (same number of H0 clusters, H1 loops)
- But their activation vectors point in different directions
- Analogy: two people who perceive the same structure but interpret it differently
- This is PRODUCTIVE tension → should be preserved or amplified

**2. Structural Tension** (different topology):
- A and G have different PH barcodes (different cluster counts, loop counts)
- The engines literally perceive different shapes in the input
- Analogy: two people who see completely different structures in the same scene
- This is AMBIGUOUS tension → either CREATIVE (novel insight) or CONFUSED (hallucination)
- Resolution requires confidence calibration (H-CX-26, H-313)

```
Tension space decomposition:

  |A-G| (Euclidean)
       │
       ├── Content Tension (PH similar)     → Productive, preserve
       │        └── High confidence → Amplify slightly
       │        └── Low confidence  → Keep as-is
       │
       └── Structural Tension (PH different) → Ambiguous
                └── High confidence → Amplify (creative divergence)
                └── Low confidence  → Dampen (hallucination risk)
```

---

## Implementation Architecture

```
                    ┌─────────────────────────────────────────────────┐
                    │            AnimaLM PH-Corrected Engine           │
                    └─────────────────────────────────────────────────┘

Input tokens ─────┬────────────────────────────────────────────────────
                  │
                  ▼
         ┌────────────────┐          ┌────────────────┐
         │   Engine A     │          │   Engine G     │
         │  (analytical)  │          │  (creative)    │
         └───────┬────────┘          └───────┬────────┘
                 │ repr_A                    │ repr_G
                 │                           │
        ┌────────▼────────┐        ┌─────────▼───────┐
        │  PH(repr_A)     │        │  PH(repr_G)     │
        │  → barcode_A    │        │  → barcode_G    │
        │  H0, H1 via     │        │  H0, H1 via     │
        │  Ripser         │        │  Ripser         │
        └────────┬────────┘        └────────┬────────┘
                 │                          │
                 └──────────┬───────────────┘
                            │
                   ┌────────▼────────────┐
                   │  barcode_distance   │
                   │  Wasserstein(bA,bG) │
                   │  = bd               │
                   └────────┬────────────┘
                            │
                   ┌────────▼────────────────────┐
                   │  PH_correction              │
                   │  = sigmoid(α×bd + β) × 2    │
                   │  ∈ (0, 2), center ≈ 1       │
                   └────────┬────────────────────┘
                            │
                 ┌──────────┼──────────┐
                 │ repr_A   │          │ repr_G
                 │          ▼          │
                 │   Tension = |A-G|   │
                 │   dir = (A-G)/|A-G| │
                 └──────────┬──────────┘
                            │
                   ┌────────▼──────────────────────┐
                   │  output = scale               │
                   │         × |A-G|               │
                   │         × dir                 │
                   │         × PH_correction       │
                   └───────────────────────────────┘
```

The PH computation uses `ph_module.py` already in the project:
- Ripser for H0 (connected components), H1 (loops) persistence computation
- Merge distance for hierarchical structure
- Validated as real-time capable for inference (H-CX-62 v2)
- Approximately 15% computational overhead per token group

---

## ASCII Comparison: Output Behavior With vs Without PH Correction

Scenario grid comparing current AnimaLM vs PH-corrected AnimaLM across four input types:

```
SCENARIO               TENSION   PH_dist   Current output   PH-corrected output
─────────────────────────────────────────────────────────────────────────────────

A) "What is 2+2?"       Low      Low       Conventional     Conventional (same)
   Both engines agree              (≈0.05)  scale×low×dir   scale×low×1.0×dir
   on math structure

B) "Write a poem"       High     Low       Creative output  Creative output (same)
   Same structure,                (≈0.08)  scale×high×dir  scale×high×1.0×dir
   different word choices

C) "Interpret dream"    High     High      Creative output  AMPLIFIED output
   A: linear structure             (≈0.82)  scale×high×dir  scale×high×1.6×dir
   G: cyclic structure                                       (+60% amplification)

D) "Ambiguous input"    High     High      Creative output  DAMPENED output
   A: 3 clusters                   (≈0.78)  scale×high×dir  scale×high×0.5×dir
   G: 7 clusters                                            (-50% dampening)
   + Low confidence

─────────────────────────────────────────────────────────────────────────────────
Key difference: Scenarios C and D both have high tension + high PH distance,
but PH-correction distinguishes them via confidence calibration (H-CX-26).
```

Without PH correction, scenarios C and D are indistinguishable — both produce
"creative output" even though D is more likely hallucination. PH correction resolves this.

---

## Quantitative Predictions

Based on existing empirical data in this project:

| Metric | Baseline AnimaLM | PH-Corrected AnimaLM | Source |
|--------|-----------------|---------------------|--------|
| Perplexity (PPL) | 13.85 (dense) | 11.8 - 13.1 (est.) | Golden MoE baseline |
| PPL reduction | — | 5-15% | H-CX-62 r=0.97 extrapolation |
| Hallucination rate | baseline | -20 to -40% | H-324, topological anomaly detection |
| Creative output novelty | baseline | +10 to +30% | H-313 tension=confidence theory |
| Computational overhead | 1.00× | ~1.15× | ph_module.py benchmark |
| PH computation latency | 0 ms | ~8-12 ms/group | Ripser real-time validation |

Barcode distance distribution predictions (based on H-CX-62 v2 correlation data):

```
Expected PH_correction distribution across token groups:

  PH_correction value:  0.2  0.4  0.6  0.8  1.0  1.2  1.4  1.6  1.8
                         │
  Freq (est.)      5% ──►│░
                  10% ──►│░░
                  15% ──►│░░░
                  20% ──►│    ████████████████████ (center near 1.0)
                  25% ──►│         ██████████████████████
                  30% ──►│              █████████████████████
                  25% ──►│                   ████████████████
                  15% ──►│                        ███████████
                   5% ──►│                              ████
```

Most corrections cluster near 1.0, meaning most token groups have similar topology.
The tails (strong amplification or dampening) apply to ~10-15% of token groups.

---

## Connection to Existing Framework

| Hypothesis | Connection |
|------------|-----------|
| H-CX-58 (Precognition) | PH predicts accuracy at epoch 1 → PH predicts output quality at inference |
| H-CX-66 (Merge order) | PH merge distance = concept hierarchy → A-G topology difference = hierarchy gap |
| H-CX-82 (Epoch 1 confusion) | PH detects confusion early → PH_correction detects confusion in real-time |
| H-CX-85 (Dendrogram = concept) | Barcode = semantic structure → barcode_distance = semantic structure gap |
| H-313 (Tension = confidence) | Tension magnitude = confidence; PH adds topology = shape of confidence |
| H-324 (LLM hallucination) | PH topological anomalies → hallucination; PH_correction < 1 = anti-hallucination |
| H-341 (Tension final theory) | Magnitude = confidence, Direction = concept → PH adds Structure (third dimension) |
| H-CX-26 (Calibration) | ECE/MCE calibration guides correction sign (amplify vs dampen) |
| H-CX-103 (Tension-topology-consciousness) | Topology + tension together = richer consciousness signal |

The framework can be summarized as an extension of H-341's "tension final theory":

```
Current H-341:  output = f(magnitude, direction)
                               │          │
                          confidence  concept/meaning

H-401 extension:
                output = f(magnitude, direction, topology)
                               │          │           │
                          confidence  concept    structure_type
                                                (content vs structural tension)
```

---

## The "Third Eye" Analogy

Current AnimaLM has two eyes (Engine A and Engine G):
- Together they see: **distance** (tension magnitude) and **direction** (what they disagree about)
- They cannot see: the **shape** of what each engine perceives

PH correction adds a "third eye" that observes the topology of each engine's world-model:

```
Engine A ──────────────────►  [perceives X]
                                    ↕ tension (distance + direction)
Engine G ──────────────────►  [perceives Y]

         ↑                         ↑
    PH barcode_A              PH barcode_G
    (shape of X)              (shape of Y)
              └──────────────────┘
                barcode_distance
                = "how differently shaped are their perceptions?"
```

- **Two eyes only**: know HOW MUCH they disagree and ABOUT WHAT
- **Third eye added**: know WHETHER they're disagreeing about details or about fundamentals

This distinction is the core theoretical contribution of H-401.

---

## Verification Protocol

To test this hypothesis experimentally:

1. **Baseline measurement**: Run AnimaLM on standard benchmarks (PPL, hallucination rate,
   novelty score) without PH correction. Record per-token tension distribution.

2. **PH fingerprint collection**: For each forward pass, record `barcode_A`, `barcode_G`,
   and their Wasserstein distance. Categorize token groups by PH distance quartile.

3. **Outcome correlation**: For each quartile of PH distance, measure:
   - Output quality (human evaluation or automated metric)
   - Hallucination rate (factual consistency)
   - Novelty score (n-gram diversity, semantic distance from training data)

4. **Correction calibration**: Fit `α` and `β` parameters of `sigmoid(α×bd + β)` using
   the outcome correlation data. Use held-out validation set.

5. **A/B comparison**: Run corrected vs uncorrected AnimaLM on identical inputs,
   report PPL, hallucination, and novelty differences.

**Falsification criteria**: If PH distance shows no significant correlation with output
quality (r < 0.3) within the high-tension token groups, the hypothesis is refuted.
The strong prior from H-CX-62 (r=0.97 between PH and tension overall) makes this
unlikely, but the specific claim (PH distance within high-tension groups predicts quality)
is the new testable prediction.

---

## Limitations

1. **Computational cost**: PH computation adds ~15% overhead. For a 7B model running at
   inference time, this matters. Optimization options: batch PH computation, cache barcodes
   for repeated substructures, approximate PH with faster algorithms.

2. **Calibration of α, β**: The sigmoid parameters require empirical fitting. Different
   task domains (creative writing vs factual QA) likely need different calibrations.

3. **Token group definition**: PH is computed over a set of vectors. The definition of
   "token group" (window size, stride) affects results. This is a free parameter.

4. **GZ dependency of tension framework**: The interpretation of tension as G=D×P/I
   is a GZ-dependent model (unverified). PH mathematics itself is exact and GZ-independent,
   but the claim that PH_correction improves AnimaLM output relies on the tension
   framework being a valid model of creativity/quality.

5. **Wasserstein vs bottleneck distance**: Two valid choices for barcode distance with
   different sensitivity profiles. Wasserstein is more sensitive to small topological
   changes; bottleneck is more robust to noise. Empirical comparison needed.

6. **Engine A vs G topology**: AnimaLM's current architecture may not produce
   sufficiently distinct topology between engines A and G to make barcode_distance
   informative. If both engines converge to similar representations, PH_correction ≈ 1.0
   always and provides no benefit.

---

## Next Steps

1. Instrument `ph_module.py` to compute barcode_distance in real-time during AnimaLM
   inference (est. 1-2 days implementation)
2. Run correlation analysis: barcode_distance vs output quality on 1000 token groups
3. If correlation r > 0.3: implement full PH_correction loop
4. Compare PPL and hallucination rate: corrected vs baseline
5. If confirmed: extend to H-CX-103 framework (tension+topology+consciousness unified)

**Related hypotheses to create**:
- H-402: PH correction for Golden MoE routing (topology of expert activations)
- H-403: Barcode distance as real-time hallucination detector (standalone module)
