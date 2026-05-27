# `universal_ff/SOURCES.md` — Universal force-field adapters

> Phase G adapter targets: `schnet_call.py`, `mace_call.py`, `alignn_call.py`, `chgnet_call.py`, `m3gnet_call.py`

Five open-source universal NNPs for crystal-structure energy / force / property
prediction. Each adapter wraps the model invocation and SKIPs cleanly when
its optional dep is missing.

---

## Aggregate license / citation table

| Adapter | Model | License | Citation | PyPI package |
|---|---|---|---|---|
| `schnet_call.py` | SchNet | MIT | Schütt, K. T. et al. "SchNet — A deep learning architecture for molecules and materials." **J. Chem. Phys.** 148, 241722 (2018). DOI: 10.1063/1.5019779 | `schnetpack` |
| `mace_call.py` | MACE | MIT | Batatia, I., Kovács, D. P., Simm, G. N. C., Ortner, C., & Csányi, G. "MACE: Higher Order Equivariant Message Passing Neural Networks for Fast and Accurate Force Fields." **NeurIPS 2022**. arXiv:2206.07697 | `mace-torch` |
| `alignn_call.py` | ALIGNN | NIST Open Source / MIT-compatible | Choudhary, K. & DeCost, B. "Atomistic Line Graph Neural Network for improved materials property predictions." **npj Comput. Mater.** 7, 185 (2021). DOI: 10.1038/s41524-021-00650-1 | `alignn` |
| `chgnet_call.py` | CHGNet | BSD-3-Clause | Deng, B. et al. "CHGNet as a pretrained universal neural network potential for charge-informed atomistic modelling." **Nat. Mach. Intell.** 5, 1031–1041 (2023). DOI: 10.1038/s42256-023-00716-3 | `chgnet` |
| `m3gnet_call.py` | M3GNet (via MatGL) | BSD-3-Clause | Chen, C. & Ong, S. P. "A universal graph deep learning interatomic potential for the periodic table." **Nat. Comput. Sci.** 2, 718–728 (2022). DOI: 10.1038/s43588-022-00349-3 | `matgl` (M3GNet successor library) |

---


- **No n=6 lattice-fit** applied to any FF output. These NNPs carry their
  OWN published error bars (typical force MAE 20–60 meV/Å on MPtrj /
  MPF.2021.2.8 / OMat24 splits).
- **Universal ≠ universally accurate**: each NNP has elemental + chemistry
  coverage limits. SchNet is older (~2017); MACE / CHGNet / M3GNet are 2022–23
  state-of-the-art for inorganic crystals; ALIGNN excels at property regression
  (band gap, formation energy) more than dynamics.
- **Training data overlap matters**: MACE-OMat, CHGNet (MPtrj), M3GNet
  (MPF.2021.2.8), ALIGNN (JARVIS-DFT) all use DFT-computed labels. They
  predict DFT, not experiment. Cite the model not the experiment when
  hexa-matter spec docs reference these.
- **Energetic basis differs**: PBE / PBE+U / r2SCAN — the energetic basis
  per-model differs. Direct cross-comparison of energy values across two
  NNPs without aligning the DFT basis is misleading.
- **CHGNet uniquely includes magnetic moment** (charge / spin awareness);
  the others are charge-neutral by default.

---

## Cache fixture

`cache/sample_structure.json` — Si diamond-cubic 2-atom primitive cell
(SAMPLE FIXTURE — illustrative input only).

---

## Cross-link

- `_absorption_bridge/omat24/SOURCES.md` — OMat24 dataset (training data for
  MACE-OMat)
- `_absorption_bridge/materials_project/SOURCES.md` — MPtrj (training data
  for CHGNet)
- `LATTICE_POLICY.md` §1.3 — n=6 lattice is auxiliary; no fit on FF data
- `LIMIT_BREAKTHROUGH.md` — bond-energy / force / energy walls
