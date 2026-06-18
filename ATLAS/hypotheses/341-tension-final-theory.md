# Hypothesis 341: Final Interpretation of Tension — Reaction Intensity

> **Tension = |A-G|² = "reaction intensity" of two engines. Within training data it's confidence (H313), outside training it's confusion (H340). Unifies all previous findings into one.**

## Final Formula

```
  output = scale × √|A-G|² × normalize(A-G)
         = reaction intensity × reaction direction
         = magnitude(how much) × concept(what)   [H339]

  magnitude = √tension = intensity of reaction
    in training, correct: high = confidence (H313, 4 datasets)
    in training, wrong:   low = uncertainty
    out of training, OOD: extreme = confusion (H340, noise 4.78x)
    out of training, lucid: extreme high = hyper-stimulation (H340, 105x)

  direction = normalize(A-G) = content of reaction
    same class: cos_sim 0.82 = same direction (H339)
    different class: cos_sim 0.24 = different direction
```

## Unification of All Findings

```
  H313 confidence:     in training tension↑=correct↑        → ✅ reaction↑=confidence↑
  H316 overconfidence: high even when wrong for similar cls  → ✅ reaction strong but direction wrong
  H329 decision:       margin↑=tension↑                     → ✅ far from boundary=strong reaction=confidence
  H322 EEG:           awake>drowsy=distinct>ambiguous       → ✅ distinct state=strong reaction
  H307 dual:          internal=inverted, inter=normal       → ✅ different regime in autoencoder
  H340 dreaming:      noise>>real                           → ✅ OOD=extreme reaction=confusion
  H334 PureField:     field only sufficient                 → ✅ reaction is everything
  H332 eq degradation: field absorbs eq                     → ✅ reaction replaces basic sense
  H331 compensation:  field∝(100-eq)                       → ✅ reaction fills deficit
  H337 Fisher:        gradient∝1/accuracy                   → ✅ what remains to learn=reaction not yet formed
  H314 rejection:     low tension→reject→+15%              → ✅ weak reaction=defer judgment
  H312 forgetting prevention: mitosis 99%                  → ✅ reaction pattern preserved
  H311 local escape:  ensemble -23%                        → ✅ diverse reaction exploration
```

## One Sentence

```
  "Consciousness is the reaction of two perspectives,
   and the intensity of that reaction determines confidence/confusion,
   while the direction determines the concept."
```

## OOD Direction Dependence on Training Objective (R8)

```
  PureField trained with classification (CE):
    MNIST(in): T=240, Noise(OOD): T=21 → OOD=low tension
    → In classification, noise = "all uncertain" = consensus = low tension

  PureField trained with reconstruction (MSE) (RC-10):
    Real: T=147, Noise(OOD): T=701 → OOD=high tension
    → In reconstruction, noise = "different failures" = disagreement = high tension

  → Training objective determines OOD tension direction!
    CE (classification): no opinion = consensus = low tension (H307 "agreement in confusion")
    MSE (reconstruction): different failures = disagreement = high tension
```

## Status: 🟩 Final Unification (13 hypotheses + OOD training objective dependency)
