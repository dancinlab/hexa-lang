# `colabfold/SOURCES.md` — ColabFold (Steinegger lab)

> hexa-bio cycle-30++++++++ absorption adapter target: `colabfold_smoke.py`

---

## System

- **Name**: ColabFold (AlphaFold-2 + MMseqs2 fast MSA pipeline)
- **Maintainer**: Martin Steinegger lab, Seoul National University + Sergey Ovchinnikov + Milot Mirdita
- **Web / Code**: https://github.com/sokrypton/ColabFold
- **localcolabfold**: https://github.com/YoshitakaMo/localcolabfold (local install w/o Colab)
- **Distinguishing feature**: swaps AF2's slow JackHMMER MSA for MMseqs2 — 10-100x faster wall-clock

## Authoritative citation

- Mirdita, M. et al. "ColabFold: making protein folding accessible to all." **Nature Methods** 19, 679-682 (2022). DOI: 10.1038/s41592-022-01488-1

## Output schema (this adapter validates)

- `chains[]`, per-residue `residue_idx` + `plddt` + `atom_xyz`
- `global_metrics`: `mean_plddt`, `ptm`, `iptm`
- `underlying_model: AlphaFold-2-multimer` (or AF2 mono)
- `msa_engine: MMseqs2` (defining feature)
- `msa_depth` — observed MSA depth

## License

- **MIT** — commercial use OK
- Underlying AF2 weights: AF2 release license (broadly open)
- Underlying MMseqs2: GPLv3 — note that consuming MMseqs2 search hits in
  a commercial pipeline is fine (data is not a derivative work); shipping
  the MMseqs2 binary in a closed product would invoke GPLv3 obligations.

## Honest notes

- **Predictions, not measurements** — same caveat.
- **No n=6 lattice-fit** applied (C3).
- **MSA-depth** is preserved in the fixture — small MSAs degrade AF2
  accuracy; the adapter does not hide this.
- **Adapter caching**: bundled fixture `cache/sample_prediction.json`.

## Cross-link

- `_absorption_bridge/colabfold/colabfold_smoke.py` — this adapter
- `_absorption_bridge/mmseqs/SOURCES.md` — underlying MSA engine
- `HEXA-WEAVE.md` etc. — "Primary oracle: AlphaFold-class fold inference"
