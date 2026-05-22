# `gnome/SOURCES.md` — DeepMind GNoME

> Phase G adapter target: `gnome_dataset_smoke.py` (offline schema replay; real fetch via Zenodo download)

---

## System

- **Name**: GNoME — Graph Networks for Materials Exploration
- **Maintainer**: Google DeepMind
- **Scale**: ~2.2 million predicted stable inorganic crystals (Merchant et al. 2023)
- **Web**: https://github.com/google-deepmind/materials_discovery

## Authoritative citation

- Merchant, A., Batzner, S., Schoenholz, S. S., Aykol, M., Cheon, G., & Cubuk, E. D. "Scaling deep learning for materials discovery." **Nature** 624, 80–85 (2023). DOI: 10.1038/s41586-023-06735-9

## Dataset

- **Zenodo DOI**: 10.5281/zenodo.10371563 (GNoME release dataset)
- **Format**: structured tabular + CIF per record
- **Size**: tens of GB (full release); per-record JSON is ~kB scale
- **License**: CC-BY 4.0

## Schema (per record, abbreviated)

| Field | Type | Note |
|---|---|---|
| `gnome_id` | str | GNoME internal id |
| `composition` | str | reduced formula |
| `predicted_formation_energy_per_atom` | float (eV/atom) | DFT-PBE proxy |
| `predicted_energy_above_hull` | float (eV/atom) | 0.0 ↔ predicted-stable |
| `structure` (lattice + sites) | dict | space group + lattice + atomic positions |
| `is_synthesized` | bool | almost always `false` — predictions |

## Honest notes (per `INIT.md` hard rule 5)

- **PREDICTED, NOT SYNTHESIZED**: every GNoME record is a DFT prediction.
  No experimental verification implied. Hexa-matter spec docs MUST preserve
  this UNPROVEN marker when citing GNoME.
- **2.2M figure is published claim**, not independently verified. Subsequent
  re-analysis (Cheetham & Seshadri, *Chem. Mater.* 2024, etc.) flagged that
  a meaningful fraction of GNoME "stable" predictions are minor variants or
  already-known compositions. Cite the Nature paper but note the discourse.
  its OWN published error bars (formation-energy MAE ~20 meV/atom on their
  test split).

## Cross-link

- `_absorption_bridge/gnome/gnome_dataset_smoke.py` — this phase's adapter
- `INIT.md` §"Hard constraints" rule 5 — UNPROVEN preservation
- `LIMIT_BREAKTHROUGH.md` — hard / soft wall classification for predicted materials
