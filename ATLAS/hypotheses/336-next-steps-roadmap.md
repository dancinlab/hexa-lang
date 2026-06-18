# Hypothesis 336: Next Steps Roadmap — 5 Unexplored Directions

> **After PureField 5/5 verification complete, the next expansion directions. Organized by difficulty/dependency.**

## Immediately Possible (CPU, public data)

```
  1. Fisher information deep dive (H325)
     Current: r=-0.12 (weak, 2000 samples)
     Next: full test set + per-class Fisher + Hessian approximation
     → write calc/fisher_analyzer.py

  2. GNN molecules (H328) — sklearn proxy expansion
     Current: Wine(ceiling) + Cancer(toxicity AUROC 0.40 failed)
     Next: use Digits as "molecular property" proxy, apply PureField
     → reproduce boundary r=-0.79 finding in other datasets
```

## External Data Needed

```
  3. Actual EEG data (H322)
     Data: PhysioNet EEG Motor Movement (public)
     Download: mne library or wget
     → pip install mne → test PureField on actual brainwaves
     Current: synthetic EEG proxy (awake≈sleep>>drowsy)

  4. Multimodal (H323)
     Data: MNIST + text descriptions (synthetically possible)
     Or: CIFAR + class name embeddings
     → per-modal PureField → cross-modal tension
```

## GPU Needed (Windows/RunPod)

```
  5. Golden MoE LLM (H327, H335)
     Repo: golden-llama (logout_test)
     Current: PPL 4634 (step 500)
     Next: add PureField layer, measure tension-PPL correlation
     → Windows RTX 5070 or RunPod A100
```

## Priority

```
  Priority 1: Fisher deep dive (immediate, CPU) — strengthen H325
  Priority 2: Actual EEG (install mne) — real verification of H322
  Priority 3: Synthetic multimodal (CPU) — first experiment of H323
  Priority 4: GNN proxy expansion (CPU) — reproduce H328 boundary
  Priority 5: Golden MoE LLM (GPU) — H335 PureField LLM
```

## Status: 📋 Roadmap (expansion directions after PureField completion)
