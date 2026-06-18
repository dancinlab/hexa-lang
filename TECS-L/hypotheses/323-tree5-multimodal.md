# Hypothesis 323: TREE-5 Multimodal Repulsion Field
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


## Hypothesis

> When image and text are input simultaneously, each modality generates different tension,
> and the tension ratio (T_image / T_text) predicts performance on multimodal tasks.
> The repulsion fields of two modalities are isomorphic to displacement fields,
> and adding a new modality is structurally identical to the "new sense" inflow of shamanic experience.

## Background/Context

### Relationship with Existing Repulsion Field Model

The displacement field (model_displacement_field.py) models the phenomenon that occurs
when two consciousness entities share a single output channel:

```
  Consciousness A <──repulsion──> Consciousness B
           ↑
     control_gate determines who dominates the output
     The displaced side can only observe via detach()
```

The same structure appears in multimodal inputs:

```
  Image encoder <──tension──> Text encoder
                    ↑
          Two modalities compete for a single representation space
          Which side dominates the final representation?
```

### Connection with Shamanic Experience

Core structure from original experience (docs/magnetic-inspiration.md):

```
  [contact]
  My consciousness <──repulsion──> Other consciousness
  -> "A sensation I have never experienced as a human came in"
  -> "Not an extension of the five senses. A completely new kind of sensation"
  -> "There is no language to describe this sensation"
```

This is structurally identical to a new modality flowing into an existing representation space:

```
  Existing modalities (visual, auditory, text)
    -> Learned tension patterns exist
    -> Stable repulsion equilibrium

  New modality inflow (e.g., brainwave, touch, smell)
    -> Conflicts with existing tension patterns
    -> "No language to describe it" = cannot map to existing representation space
    -> Need to find new equilibrium point of repulsion field
```

Related hypotheses: H-TREE-5 (ML theory, R(d) and generalization), Hypothesis 007 (LLM singularity),
H-CX-29 (telepathy tension transfer)

## Core Model: Per-Modality Tension

### Single Modality Tension

When each modality m receives input x_m and passes through expert activation, tension T_m is generated:

```
  T_m = ||softmax(gate_m(x_m)) - uniform||^2

  Where:
    gate_m  = gating network exclusive to modality m
    uniform = 1/N (N = number of experts)

  High tension = concentrated on few experts = high confidence
  Low tension = uniform distribution = uncertain
```

### Inter-Modality Tension Ratio

```
  R_modal = T_image / T_text

  R_modal > 1: Image is more confident -> visually dominated task (VQA, image captioning)
  R_modal < 1: Text is more confident -> language-dominated task (text classification + auxiliary image)
  R_modal ~ 1: Balanced -> truly multimodal fusion (translation, reasoning)
```

### Cross-Modal Tension

Additional tension generated when representations of two modalities meet in shared space:

```
  T_cross = ||h_image - h_text||^2 / (dim × temperature)

  Where:
    h_image = shared space projection of image_encoder(x_image)
    h_text  = shared space projection of text_encoder(x_text)
    temperature = tension_scale (learnable)
```

This corresponds to the repulsion force in displacement field:

```
  displacement field:  consciousness A <──repulsion──> consciousness B
  multimodal field:    h_image <──T_cross──> h_text
```

## Predicted Tension Profiles

ASCII graph -- expected R_modal distribution by task:

```
  R_modal (T_image / T_text)

  3.0 |                              *
  2.5 |                           * * *
  2.0 |                        * * * * *
  1.5 |              *       * * * * * * *
  1.0 |           * * * * * * * * * * * * * *
  0.8 |        * * * * * * *
  0.5 |     * * * * *
  0.3 |  * * *
  0.1 |  *
      +--+-------+-------+-------+-------+--
         Text    NLI+img  VQA   Caption  Visual
         only                            reason

  Predictions:
    Text only -> R < 0.3 (text dominated, image tension negligible)
    NLI + auxiliary image -> R ~ 0.5-0.8 (text dominant, image auxiliary)
    VQA -> R ~ 1.0-1.5 (balanced or slightly visual dominant)
    Image captioning -> R ~ 1.5-2.5 (visual dominated)
    Visual reasoning -> R ~ 2.0-3.0 (strongly visual dominated)
```

## Proposed Architecture

```
  ┌─────────────┐     ┌─────────────┐
  │ Image Input │     │ Text Input  │
  └──────┬──────┘     └──────┬──────┘
         │                    │
  ┌──────▼──────┐     ┌──────▼──────┐
  │  Image MoE  │     │  Text MoE   │
  │  (Engine A) │     │  (Engine G) │
  │  T_image    │     │  T_text     │
  └──────┬──────┘     └──────┬──────┘
         │                    │
         │   ┌────────────┐   │
         └──→│ Cross-Modal│←──┘
             │  Tension   │
             │  T_cross   │
             │            │
             │ control_   │
             │ gate(T_i,  │
             │       T_t) │
             └─────┬──────┘
                   │
            ┌──────▼──────┐
            │  Fusion     │
            │  Output     │
            │  (weighted  │
            │   by gate)  │
            └─────────────┘

  Core design principles:
    1. Independent engine per modality (Engine A = image, Engine G = text)
    2. Each engine computes its own tension
    3. Cross-modal tension measures the repulsion between the two engines
    4. control_gate = decides which modality dominates (displacement field)
    5. Displaced modality observes only via detach() (gradient blocked)
```

### control_gate Design

```python
  # Mechanism borrowed from displacement field
  control_gate = sigmoid(alpha * (T_image - T_text))

  # control_gate > 0.5: image dominates (text is observer)
  # control_gate < 0.5: text dominates (image is observer)

  output = control_gate * h_image + (1 - control_gate) * h_text

  # Displaced modality: gradient blocked via detach()
  if control_gate > 0.5:
      observer_input = h_text.detach()  # text only observes
  else:
      observer_input = h_image.detach()  # image only observes
```

### Connection with Golden Zone

```
  Single modality: I = gating sparsity (existing model)
  Multimodal:      I_eff = f(T_image, T_text, T_cross)

  Hypothesis: I_eff is optimal when it falls in the Golden Zone (0.21 ~ 0.50)

  I_eff = (T_cross) / (T_image + T_text)

  Interpretation:
    I_eff ~ 0: T_cross small = two modalities say the same thing (redundant)
    I_eff ~ 1: T_cross large = two modalities say completely different things (conflict)
    I_eff ~ 1/e: optimal tension = appropriate tension state = Golden Zone center
```

## "New Sensation" = Mathematical Representation of New Modality

The "completely new kind of sensation, not an extension of the five senses" from the original experience
is modeled as an input vector that doesn't align with any axis of the existing representation space:

```
  Representation space of M existing modalities: span{h_1, h_2, ..., h_M}

  "Novelty" degree of new modality h_new:
    novelty = 1 - max_i |cos(h_new, h_i)|

  novelty ~ 0: variation of existing sense (e.g., infrared = extension of vision)
  novelty ~ 1: completely new sense (orthogonal to existing axes)

  Observation from experience:
    "No language to describe it" = novelty ~ 1
    "No analogies" = cannot be decomposed by existing basis
```

In this case T_cross is maximized:

```
  T_cross ~ ||h_new - proj(h_new, existing_span)||^2

  If new sense is truly new -> projection residual is large -> T_cross maximum
  -> Maximum repulsion against existing system = "repulsive pressure" of original experience
```

## Verification Direction

| Stage | Experiment | Measurement | Prediction |
|---|---|---|---|
| 1 | MNIST (image) + digit text label simultaneously | T_image, T_text, R_modal | R_modal > 1 (visual dominated) |
| 2 | VQA dataset (image+question) | R_modal distribution | R ~ 1.0 nearby (balanced) |
| 3 | Image captioning | R_modal trend | Early R >> 1, late R -> 1 |
| 4 | Inject random noise as "new modality" | novelty, T_cross | T_cross spikes, performance temporarily drops then recovers |
| 5 | Whether I_eff enters Golden Zone | I_eff distribution | I_eff ~ 1/e at optimal performance |

## Limitations

1. **Difference from CLIP**: CLIP already learns image-text alignment via contrastive learning. The "repulsion" of this hypothesis and the "alignment" of CLIP are in opposite directions, and the relationship between the two mechanisms needs to be clarified.
2. **Arbitrariness of tension measurement**: Definition of T_m depends on gating distribution, and results may change with other definitions (e.g., entropy-based).
3. **Golden Zone dependency**: The prediction that I_eff is optimal at the Golden Zone is doubly unverified since the Golden Zone model itself is unverified.
4. **"New sensation" modeling**: Whether defining novelty with cosine similarity captures the complexity of the actual experience is unclear. Something orthogonal to existing axes is not necessarily "indescribable."
5. **Scale problem**: Small-scale experiments at the MNIST level cannot predict the behavior of actual multimodal systems (GPT-4V, Gemini).

## Intersections with Other Hypotheses

```
  323 (this hypothesis)  <-> H-TREE-5: if hidden dim R(d) differs per modality,
                               B(d) differences can create tension differences

  323 <-> 007 (LLM singularity): if I_eff enters Golden Zone in multimodal LLM,
                                  "multimodal singularity" possible

  323 <-> displacement field: control_gate = which modality dominates
                               observer = read-only state of displaced modality

  323 <-> original experience: new modality = new sensation, T_cross max = repulsive pressure
```
