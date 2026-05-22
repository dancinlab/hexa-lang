# `openfold/SOURCES.md` — OpenFold (Columbia consortium AF2 reimpl)

> hexa-bio cycle-30++++++++ absorption adapter target: `openfold_smoke.py`

---

## System

- **Name**: OpenFold (open-source, trainable PyTorch reimplementation of AlphaFold-2)
- **Maintainer**: AlQuraishi Lab, Columbia University Systems Biology + the OpenFold consortium
- **Web / Code**: https://github.com/aqlaboratory/openfold
- **Distinguishing feature**: trainability — unlike DeepMind's AF2 inference release, OpenFold can be retrained / fine-tuned on custom data

## Authoritative citation

- Ahdritz, G. et al. "OpenFold: retraining AlphaFold2 yields new insights into its learning mechanisms and capacity for generalization." **Nature Methods** 21, 1514-1524 (2024). DOI: 10.1038/s41592-024-02272-z

## Output schema (this adapter validates)

- `chains[]` — list of polymer chains
- per-residue: `residue_idx`, `name`, `plddt` (0-100), `atom_xyz`
- `global_metrics`: `mean_plddt`, `ptm`
- `trainable: true` (defining feature)

## License

- **Apache-2.0** — commercial use OK; trainable; weights publicly downloadable
- A natural commercial-OK substitute when AF3's non-commercial license
  is a blocker.

## Honest notes

- **Predictions, not measurements** — same caveat.
- **No n=6 lattice-fit** applied to OpenFold outputs (C3).
- **Trainability** is the key value-add: hexa-bio can in principle
  fine-tune OpenFold on internal structures — but that is out-of-scope
  for this absorption-bridge (which only validates schema replay).
- **Adapter caching**: bundled fixture `cache/sample_prediction.json`.

## Cross-link

- `_absorption_bridge/openfold/openfold_smoke.py` — this adapter
- `_absorption_bridge/alphafold3/SOURCES.md` — AF3 sibling
- `HEXA-WEAVE.md` etc. — "Primary oracle: AlphaFold-class fold inference"
