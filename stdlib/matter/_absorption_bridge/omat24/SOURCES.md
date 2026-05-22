# `omat24/SOURCES.md` — Meta AI OMat24

> Phase G adapter target: `omat24_dataset_smoke.py` (offline schema replay; real fetch via HuggingFace datasets)

---

## System

- **Name**: OMat24 — Open Materials 2024
- **Maintainer**: Meta AI / Fundamental AI Research (FAIR)
- **Scale**: ~110 million DFT-computed structures (Barroso-Luque et al. 2024)
- **Web**: https://huggingface.co/datasets/fairchem/OMAT24

## Authoritative citation

- Barroso-Luque, L. et al. "Open Materials 2024 (OMat24) inorganic materials dataset and models." **arXiv** 2410.12771 (2024).

## Dataset + checkpoints

- **HuggingFace dataset**: `fairchem/OMAT24` — 110M DFT records
- **HuggingFace checkpoint**: `fairchem/MACE-OMat-2024` (MACE NNP trained on OMat24)
- **Size**: dataset ~hundreds of GB; checkpoint ~hundreds of MB
- **License**: CC-BY 4.0 (data + model)

## Schema (per record, abbreviated)

| Field | Type | Note |
|---|---|---|
| `omat24_id` | str | OMat24 internal id |
| `formula` | str | reduced formula |
| `dft_total_energy_eV` | float | full-cell DFT-PBE energy |
| `dft_energy_per_atom_eV` | float | normalized |
| `max_force_eV_per_A` | float | residual force (relaxed structures ~0.0) |
| `structure` (lattice + sites) | dict | space group + lattice + atomic positions |

## Honest notes

- OMat24 records are *computed*, not measured. DFT-PBE; same caveats as
  Materials Project.
- 110M figure is the *generation count*, not unique-composition count.
  Many records are perturbed structures of the same composition for force
  training. Cite carefully.
- MACE-OMat checkpoint is one of several universal NNPs that consumed
  OMat24; it is NOT the only model.
  DFT error bars.

## Cross-link

- `_absorption_bridge/omat24/omat24_dataset_smoke.py` — this phase's adapter
- `_absorption_bridge/universal_ff/mace_call.py` — MACE-OMat checkpoint
  consumer
- `_absorption_bridge/gnome/SOURCES.md` — GNoME (the other big 2023-24
  predicted-stable-crystal release)
