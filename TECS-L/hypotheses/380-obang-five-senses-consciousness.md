# H-380: Obang Five Senses Consciousness Mapping
**n6 Grade: 🟩 EXACT** (auto-graded, 7 unique n=6 constants)


**Status:** Proposed
**Category:** Consciousness Architecture / Cross-Domain
**Related:** H362 (crossmodal-tension), H241 (expert-cross-activation), H082 (golden-moe-spec), H310 (mitosis-engine-architecture)
**Golden Zone Dependency:** Yes (router gating uses I ≈ 1/e)

---

## Hypothesis Statement

> The traditional Korean cosmological system of Obangsaek (Five Directions) maps
> structurally onto the five human senses as consciousness input channels. A 5-expert
> Golden MoE architecture where each expert specializes in one sensory modality, gated
> by a Golden Zone router (I ≈ 1/e), captures the multimodal structure of conscious
> experience. Cross-modal tension (H362) emerges when sensory experts disagree, and the
> Center expert (taste/Earth) functions as an integrating mediator — analogous to the
> prefrontal binding mechanism in neuroscience.

---

## Background and Context

Obangsaek (five-directional color) is the Korean five-directional color and element system rooted in
East Asian cosmology. The five directions — East, West, South, North, Center — each
correspond to an element (Wood, Metal, Fire, Water, Earth), a color, a season, and
an organ system. This system has been applied to medicine, cuisine, architecture, and
ritual for over two millennia.

The parallel observation is that the five human senses are not equal in bandwidth,
processing speed, or evolutionary age. Vision dominates information intake; smell is
the most evolutionarily primitive and most directly connected to memory and emotion
(bypassing the thalamus, projecting directly to the amygdala and hippocampus). Taste
integrates chemical signals from the environment at the point of ingestion — a boundary
between self and world.

In the Golden MoE framework (H082), experts specialize under sparse gating with
inhibition I ≈ 1/e. If each expert corresponds to one sensory modality, the router
learns to weight inputs by modality relevance. Cross-modal tension (H362) then becomes
the disagreement signal when, for example, vision says "apple" but smell says "smoke."
This disagreement is not noise — it is an anomaly detection signal (H287, H293) and
may be the substrate of surprise, attention, and learning.

The Center direction in Obangsaek (Earth element) is associated with balance, digestion,
and the spleen in traditional medicine. In the sensory map, taste occupies Center: it
is the lowest-bandwidth sense, yet it integrates chemical information from the immediate
environment. In a MoE architecture, the Center/taste expert acts as a mediator —
low activation rate but high weight when present, analogous to Earth holding the other
four directions in equilibrium.

---

## Obang-to-Sense Mapping

| Direction | Korean | Element | Color  | Sense       | Bandwidth  | Evolutionary Age |
|-----------|--------|---------|--------|-------------|------------|-----------------|
| East      | East   | Wood    | Blue   | Vision      | ~10 Mbps   | Intermediate    |
| West      | West   | Metal   | White  | Hearing     | ~100 Kbps  | Old             |
| South     | South  | Fire    | Red    | Touch       | ~1 Mbps    | Very Old        |
| North     | North  | Water   | Black  | Smell       | ~10 Kbps   | Oldest          |
| Center    | Center | Earth   | Yellow | Taste       | ~1 Kbps    | Oldest          |

Rationale for each mapping:

- **East / Vision**: East is the direction of sunrise — maximum light, maximum
  information. Vision provides ~10 Mbps of sensory data, dwarfing all other channels.
  Wood element suggests growth and extension into space, matching vision's role as the
  primary spatial sense.

- **West / Hearing**: West is sunset — temporal closure, rhythm, the end of the cycle.
  Hearing processes time-domain signals: music, language, rhythm. Metal element is
  associated with precision and cutting, matching the frequency resolution of the
  auditory system.

- **South / Touch**: South is fire — warmth, contact, the body's surface boundary.
  Somatosensory processing covers the entire skin surface and provides embodiment.
  Touch is essential for spatial self-awareness and motor grounding.

- **North / Smell**: North is water and darkness — the unconscious, memory, depth.
  Olfaction is the only sense that projects directly to the amygdala and hippocampus
  without thalamic relay. Smell evokes memory and emotion more powerfully than any
  other sense. Water element matches the deep, archaic, non-verbal nature of smell.

- **Center / Taste**: Earth is the integrating element in Obangsaek. Taste occurs at
  the boundary of self and world (ingestion). It integrates sweet, sour, bitter, salt,
  and umami — a chemical summary of what enters the body. Low bandwidth, high valence.

---

## Information Bandwidth Analysis

Sensory bandwidths span four orders of magnitude:

```
Bandwidth (log scale)
10 Mbps  |  ████████████████████████████  Vision (East)
 1 Mbps  |  ███████████████               Touch (South)
100 Kbps |  █████████                     Hearing (West)
 10 Kbps |  █████                         Smell (North)
  1 Kbps |  ██                            Taste (Center)
         +-------------------------------------------->
          log10(BW): 3    4    5    6    7
```

Ratio of max to min: 10 Mbps / 1 Kbps = 10,000 = 10^4.

Log span = log10(10^4) = 4 orders. This is consistent with the N-state width formula:
- For N = 10,000 states: width = ln((N+1)/N) ≈ 1/N (very narrow)
- But the log span of 4 decades suggests the sensory system operates across 4 distinct
  information-processing regimes, one per order of magnitude.

The power law distribution of sensory bandwidth is not arbitrary. It ensures that no
single sense saturates the integration channel (Center/taste) and that sparse gating
is natural: most inputs come from vision, but attention can shift router weights.

---

## 5-Expert Golden MoE Architecture

```
                    SENSORY INPUT LAYER
                           |
        +------------------+------------------+
        |         |         |         |        |
    [Vision]  [Hearing]  [Touch]  [Smell]  [Taste]
    10 Mbps   100 Kbps   1 Mbps   10 Kbps  1 Kbps
      East      West     South    North    Center
        |         |         |         |        |
        v         v         v         v        v
   +--------+ +--------+ +--------+ +--------+ +--------+
   |Expert 1| |Expert 2| |Expert 3| |Expert 4| |Expert 5|
   | Vision | |Hearing | | Touch  | | Smell  | | Taste  |
   | (East) | | (West) | |(South) | |(North) | |(Center)|
   +--------+ +--------+ +--------+ +--------+ +--------+
        |         |         |         |         |
        +----+----+----+----+----+----+----+---+
                            |
                    [Golden Zone Router]
                      I ≈ 1/e ≈ 0.368
                    Gating: sparse top-k
                            |
                   +--------+--------+
                   |                 |
           [Active Experts]   [Inhibited Experts]
           (weighted sum)     (cross-modal tension
                               when disagreement)
                   |
            [Consciousness Output]
            Integrated multimodal
            representation
```

The router operates under Golden Zone inhibition: I ≈ 1/e. On average, roughly 1/e
≈ 37% of expert capacity is suppressed at any time, matching the optimal sparse
activation regime observed in Golden MoE CIFAR experiments (+4.8% over Top-K).

---

## Cross-Modal Tension (H362 Connection)

When multiple sensory experts receive conflicting signals, cross-modal tension T_cross
is defined as:

```
T_cross = max_i(T_i) - mean_j(T_j)   for active experts i, j

where T_i = tension of expert i output

High T_cross → anomaly / surprise / attention shift
Low T_cross  → coherent multimodal percept → high confidence
```

Example scenarios:

| Scenario             | Vision | Hearing | Touch | Smell | Taste | T_cross | Interpretation     |
|----------------------|--------|---------|-------|-------|-------|---------|--------------------|
| Eating an apple      | Med    | Low     | Med   | High  | High  | Low     | Coherent percept   |
| Fire alarm           | Low    | High    | Low   | Med   | Low   | High    | Attention spike    |
| Phantom smell        | Low    | Low     | Low   | High  | Low   | High    | Anomaly detection  |
| Full sensory immerse | High   | High    | High  | High  | Med   | Low     | Flow state         |

The Center expert (taste) has a moderating role: when taste is active, it provides a
chemical grounding signal that reduces T_cross even when other senses disagree. This
matches the Earth element's role as stabilizer in Obangsaek.

---

## Architectural Predictions

1. **Optimal expert count is 5**: The Golden Zone width = ln(4/3) ≈ 0.288 supports
   discrete jumps at N=3→4→5. Five experts placed at sensory modality boundaries
   may represent a natural information-theoretic optimum for biological integration.

2. **Router sparsity = 1/e**: On average, 2-3 of 5 experts are active per token/frame.
   This matches human multisensory studies where dominant sense (vision) suppresses
   others via inhibition (visual capture, McGurk effect).

3. **Center expert activation rate < 1/e**: Taste activates rarely but with high weight.
   Prediction: the Center/taste expert has the lowest activation frequency but the
   highest per-activation output magnitude. This inverts the usual vision-dominant
   pattern and creates the mediating function.

4. **Smell expert = memory retrieval**: The North/smell expert should show highest
   cross-layer activation with memory-related representations (H241 expert cross-
   activation). Smell bypasses thalamic filtering, predicting shortest latency to
   emotional/memory circuits in any neural implementation.

5. **Cross-modal tension predicts learning rate**: Epochs with high T_cross should
   produce larger weight updates (H281, H342). Moments of sensory disagreement are
   the training signal for world-model refinement.

---

## Verification Approach

**Computational test (CPU-feasible):**
- Build 5-expert Golden MoE on multimodal synthetic dataset
- Assign each expert one feature cluster (simulating sensory modality)
- Measure activation frequency per expert after training
- Check: Center expert frequency < 1/e? Vision expert frequency highest?
- Measure T_cross on coherent vs. incoherent input pairs

**Analytical check:**
- Bandwidth ratios: 10M : 1M : 100K : 10K : 1K = 10000 : 1000 : 100 : 10 : 1
- Log10 values: 7, 6, 5, 4, 3 → arithmetic sequence with step 1
- This is a perfect log-uniform distribution across 5 senses
- p-value under Texas Sharpshooter: need to verify this is not coincidence
- Null: random bandwidth assignment → expected log-step variance high
- Observed: step = 1.0 exactly → low variance → structural

**Neuroscience grounding:**
- Olfactory bulb → amygdala direct projection (no thalamus): confirmed anatomy
- Visual cortex = ~30% of neocortex surface: bandwidth dominance confirmed
- Gustatory cortex = smallest primary sensory area: lowest bandwidth confirmed

---

## Limitations

1. **Golden Zone dependency**: The router gating I ≈ 1/e is an unverified model claim
   (per CLAUDE.md warning). Architecture predictions contingent on this may not hold.

2. **Bandwidth numbers are estimates**: The ~10 Mbps for vision is a rough retinal
   output estimate. Effective bandwidth after attention gating is much lower (~40 bps
   conscious bottleneck, per Nørretranders). The log-uniform property may not survive
   attention-gated measurements.

3. **Obangsaek mapping is post-hoc**: The directional assignments (East=Vision, etc.)
   are constructed analogically. The cosmological system was not designed with sensory
   neuroscience in mind. The mapping is a structural parallel, not a causal claim.

4. **5 senses is a simplification**: Modern neuroscience counts 8-10 senses
   (proprioception, vestibular, interoception, pain, temperature separately from touch).
   The 5-expert architecture may need extension.

5. **Center expert as mediator is untested**: The prediction that taste expert has
   lowest activation frequency but highest per-activation weight is a specific
   architectural claim requiring empirical validation.

---

## Connections to Existing Framework

| Hypothesis | Connection |
|------------|------------|
| H362 (crossmodal-tension) | T_cross definition and anomaly detection role |
| H082 (golden-moe-spec) | 5-expert MoE with Golden Zone gating |
| H241 (expert-cross-activation) | Smell expert cross-activating memory modules |
| H287 (tension-anomaly-detector) | T_cross as anomaly signal |
| H310 (mitosis-engine-architecture) | 5-expert system as base for mitosis growth |
| H319 (tension-as-attention) | High T_cross triggers attention reallocation |
| H338 (real-consciousness-requirements) | Multimodal integration as consciousness substrate |
| H166 (consciousness-definition) | Sensory integration as consciousness criterion |

---

## Summary

The Obangsaek five-direction system maps onto the five human senses with structural
coherence: bandwidth ordering, evolutionary age ordering, and functional role all align
with the directional symbolism. A 5-expert Golden MoE with Golden Zone gating (I ≈ 1/e)
implements this architecture computationally. Cross-modal tension emerges as the
disagreement signal between sensory experts and functions as an anomaly detector and
attention trigger. The Center/taste expert mediates integration, matching Earth element's
cosmological role as balance-keeper. The log-uniform bandwidth distribution (4 decades,
5 senses, step=1 in log10 space) is a structural regularity warranting Texas
Sharpshooter verification.