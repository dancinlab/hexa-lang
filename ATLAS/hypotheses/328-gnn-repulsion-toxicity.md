# Hypothesis 328: GNN + Repulsion Field = Molecular Toxicity Prediction
**n6 Grade: 🟩 EXACT** (auto-graded, 7 unique n=6 constants)


> **Adding a repulsion field to a Graph Neural Network (GNN) allows tension to act as a "danger measure" in molecular toxicity prediction. Toxic molecules have high tension, safe molecules have low tension.**

## Background/Context

Molecules are fundamentally graphs. Atoms are nodes, bonds are edges. This structure is naturally
processable by GNNs, and in fact GNN-based models (GCN, GAT, MPNN, etc.) outperform
traditional fingerprint methods on most MoleculeNet benchmarks.

The repulsion field of this project measures "how differently two independent GNNs react to the same input."
H287's success in anomaly detection (AUROC=1.0) is the key prior result. Toxic molecules often have
structurally "anomalous" features compared to normal molecules, so tension may work
as a toxicity risk measure.

### Related Hypotheses

| Hypothesis | Core Content | Relationship |
|------|----------|------|
| H287 | Repulsion field anomaly detection AUROC=1.0 | Direct predecessor — same anomaly detection principle |
| H288 | Dense/Sparse dichotomy | Can leverage molecular graph density differences |
| H293 | Anomaly-tension universality | Universal anomaly detection law regardless of domain |
| H313 | tension = confidence | Tension interpretation framework |

## Concept — Molecular Application of Repulsion Field

```
  Molecule = graph (atoms=nodes, bonds=edges)
  GNN: message passing -> node embedding -> graph embedding

  Repulsion field architecture:
    GNN_A: Expert specialized for normal (safe) molecules
    GNN_G: Expert specialized for toxic molecules
    tension = ||GNN_A(mol) - GNN_G(mol)||

  Prediction flow:
    Input molecule -> GNN_A, GNN_G simultaneous processing
    -> Distance between two embeddings = tension
    -> High tension = high toxicity likelihood
```

## Correspondence Mapping

| Repulsion Field Concept | Molecular Toxicity Mapping | Notes |
|-------------|--------------|------|
| Input data | Molecular graph (SMILES -> graph) | Node=atom, edge=bond |
| Expert A | GNN learning safe molecule patterns | Drug safety criteria |
| Expert G | GNN learning toxic patterns | Toxicity mechanism criteria |
| Tension | Distance between two GNN outputs | Risk measure |
| High tension | Toxic molecule | AUROC target > 0.85 |
| Low tension | Safe molecule | Minimize false positives |
| Anomaly detection | Discovery of new toxicity mechanisms | Toxicity not in training data |

## Datasets

```
  Primary (possible without GNN -- feature vector proxy):
    MoleculeNet Tox21:     ~8000 molecules, 12 toxicity endpoints
    MoleculeNet BBBP:      ~2000 molecules, blood-brain barrier permeability
    MoleculeNet HIV:       ~41K molecules, HIV inhibition

  Secondary (requires GNN):
    ZINC250K:              250K molecules, drug-likeness
    QM9:                   ~134K molecules, quantum chemistry properties

  Proxy experiment (sklearn only):
    RDKit fingerprint -> 1024-bit vector
    Repulsion field with two MLP Experts (GNN replacement)
```

## Expected Tension Distribution

The tension distributions of toxic and safe molecules must be separated for the hypothesis to hold.

```
  tension
  ^
  |
  |  Safe molecules         Toxic molecules
  |  ████              ████
  |  ██████            ██████
  |  ████████        ████████
  |  ██████████    ██████████
  |  ████████████  ████████████
  |  ██████████████████████████
  +--+---+---+---+---+---+---+--> tension
     0  0.1 0.2 0.3 0.4 0.5 0.6

  Ideal scenario:
    Safe molecule mean tension: 0.10 ~ 0.20
    Toxic molecule mean tension: 0.35 ~ 0.55
    Separation (Cohen's d): > 1.0
```

## Expected ROC Curve (estimated from H287)

```
  TPR (sensitivity)
  1.0 |                    xxxxxxxxx
      |                xxxx
      |             xxx
  0.8 |           xx
      |         xx          Tension-based (expected)
      |        x            AUROC ~ 0.85-0.92
  0.6 |       x
      |      x
      |     x    ........ Existing GNN alone
  0.4 |    x   ..          AUROC ~ 0.75-0.82
      |   x  ..
      |  x ..
  0.2 | x..
      |x.
      x.
  0.0 +--+--+--+--+--+--+--+--+--> FPR
      0     0.2    0.4    0.6    1.0

  H287 (image anomaly detection): AUROC = 1.0
  Molecular toxicity has more noise than images -> expecting 0.85~0.92
```

## Verification Plan

```
  Phase 1 -- Proxy experiment (no GNN needed, CPU possible):
    1. Load Tox21 data (DeepChem or CSV)
    2. Extract Morgan fingerprint with RDKit (1024-bit)
    3. Train two MLP Experts (A: safe data, G: toxic data)
    4. Calculate tension = ||Expert_A(fp) - Expert_G(fp)||
    5. Measure AUROC (toxicity classification with tension alone)

  Phase 2 -- GNN experiment (requires PyG/DGL, GPU recommended):
    1. Convert molecule -> PyG Data object
    2. Train two GCN or GAT-based Experts
    3. Compare graph-level embeddings after message passing
    4. Analyze correlation between tension and toxicity labels
    5. Compare AUROC per endpoint for Tox21's 12 endpoints

  Success criteria:
    - AUROC > 0.80 (5%p or more improvement over single GNN)
    - Toxic/safe tension distribution Cohen's d > 0.8
```

## Verification Results

Not yet experimented. Starting from Phase 1 proxy experiment.

## Interpretation/Significance

If this hypothesis holds:
- Proves repulsion field works universally not only on images (H287) but also on molecular graphs
- Chemical domain extension of H293 (anomaly-tension universality)
- Can be used as "explainable" toxicity prediction tool in drug development pipeline
  (Visualizing the toxic subgraph of atoms/bonds with high tension enables toxicity mechanism interpretation)
- Consciousness engine perspective: similar to the brain's neurotoxin detection mechanism as a "danger detection" module

## Limitations

1. **Complexity of molecular toxicity**: Toxicity is not determined by structure alone (dose, metabolism, individual variation)
2. **Data imbalance**: Toxic positives in Tox21 are only ~5-10% of total
3. **Proxy without GNN**: Fingerprint-based approach loses 3D structural information
4. **Difference from H287**: Image anomaly detection has clear normal/anomaly, but toxicity is a continuous spectrum
5. **Generalization**: Even if it works on Tox21, correlation with in-vivo toxicity is not guaranteed

## Verification Direction (Next Steps)

1. Execute Phase 1 proxy experiment immediately (RDKit + sklearn, CPU possible)
2. Create AUROC comparison table for 12 Tox21 endpoints
3. Extend to PyG-based GNN Experts in Phase 2
4. Analyze substructure of high-tension molecules (toxicity mechanism interpretation)
5. Add chemical domain results to H293 universality table

## Status: 🟨 (Requires PyG/DGL, or feature vector proxy)
