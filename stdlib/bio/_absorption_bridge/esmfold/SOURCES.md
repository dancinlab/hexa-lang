# `esmfold/SOURCES.md` — Meta ESMFold

> hexa-bio cycle-30++++++++ absorption adapter target: `esmfold_smoke.py`

---

## System

- **Name**: ESMFold (uses ESM-2 protein language model directly)
- **Maintainer**: Meta AI / Fundamental AI Research (FAIR) — originally; weights publicly released
- **Web**: https://esmatlas.com (ESM Metagenomic Atlas of >617M predicted structures)
- **HuggingFace mirror**: `facebook/esmfold_v1`
- **GitHub**: https://github.com/facebookresearch/esm (release versions still publicly available; note: Meta de-emphasized the project in 2024 but the released weights remain accessible)

## Authoritative citation

- Lin, Z. et al. "Evolutionary-scale prediction of atomic-level protein structure." **Science** 379, 1123-1130 (2023). DOI: 10.1126/science.ade2574

## Output schema (this adapter validates)

- `chains[]` — list of polymer chains
- per-residue: `residue_idx`, `name`, `plddt` (0-100), `atom_xyz`
- `global_metrics`: `mean_plddt`, `ptm`
- `language_model`: ESM-2 series (ESM-2-650M, ESM-2-3B, ESM-2-15B)
- **`msa_used: false`** — ESMFold is single-sequence by design (no MSA)

## License

- **MIT** (Meta AI Research). Weights publicly released; commercial use OK.
- HuggingFace `facebook/esmfold_v1` model card carries the same MIT terms.

## Honest notes

- **Predictions, not measurements** — same caveat as the other folders.
- **No n=6 lattice-fit** applied to ESMFold outputs (C3).
- **MSA-free is a feature, not a bug** — ESMFold trades some accuracy
  on hard targets (where MSAs provide co-evolution signal) for 60x
  speedup vs AF2/MSA pipelines. The fixture preserves `msa_used: false`
  to make this explicit.
- **Hardware**: live inference fits on a single GPU for proteins up
  to ~3000 residues with the ESMFold-v1 weights.
- **Adapter caching**: bundled fixture `cache/sample_prediction.json`.

## Cross-link

- `_absorption_bridge/esmfold/esmfold_smoke.py` — this adapter
- `_absorption_bridge/alphafold3/SOURCES.md` — sibling AF3 SOURCES
- `HEXA-WEAVE.md` / `HEXA-VIROCAPSID.md` etc. — "Primary oracle:
  AlphaFold-class fold inference" row (ESMFold is AlphaFold-class)
