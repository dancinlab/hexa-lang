# `rosettafold/SOURCES.md` — Baker Lab RoseTTAFold + RoseTTAFold All-Atom

> hexa-bio cycle-30++++++++ absorption adapter target: `rosettafold_smoke.py`

---

## System

- **Name**: RoseTTAFold (original) + RoseTTAFold All-Atom (RFAA, 2024)
- **Maintainer**: Baker Lab, University of Washington Institute for Protein Design (IPD)
- **Web**: https://www.bakerlab.org · https://github.com/RosettaCommons/RoseTTAFold · https://github.com/baker-laboratory/RoseTTAFold-All-Atom
- **Scale**: trained on the PDB; RFAA handles proteins + small molecules + nucleic acids + covalent modifications jointly (analog to AF3 for the open ecosystem)

## Authoritative citations

- **Original**: Baek, M. et al. "Accurate prediction of protein structures and interactions using a three-track neural network." **Science** 373, 871-876 (2021). DOI: 10.1126/science.abj8754
- **All-Atom (2024)**: Krishna, R. et al. "Generalized biomolecular modeling and design with RoseTTAFold All-Atom." **Science** 384, eadl2528 (2024). DOI: 10.1126/science.adl2528

## Output schema (this adapter validates)

- `chains[]` — list of polymer chains
- per-residue: `residue_idx`, `name`, `plddt` (0-100), `atom_xyz`
- `global_metrics`: `mean_plddt`, `pae_mean`, `lddt_estimate`
- `citation_original` and/or `citation_rfaa` markers

## License

- **RoseTTAFold (original)**: BSD-3-Clause — commercial use OK
- **RoseTTAFold All-Atom**: Apache-2.0 — commercial use OK
- **Weights**: publicly downloadable from the GitHub releases / IPD pages

> **Distinct from AlphaFold-3**: where AF3 is non-commercial only,
> RoseTTAFold's open BSD/Apache licensing makes it the natural choice
> for commercial pipelines.

## Honest notes

- **Predictions, not measurements** — same caveat as AF3. RoseTTAFold
  predicts; experimental verification still required.
- **No n=6 lattice-fit** applied to RoseTTAFold outputs (C3).
- **Hardware requirements**: live inference requires a CUDA-capable GPU;
  CPU-only inference is impractical at scale.
- **Adapter caching**: bundled fixture `cache/sample_prediction.json`.

## Cross-link

- `_absorption_bridge/rosettafold/rosettafold_smoke.py` — this adapter
- `HEXA-WEAVE.md` / `HEXA-VIROCAPSID.md` / `HEXA-NANOBOT.md` /
  `HEXA-RIBOZYME.md` — "Primary oracle: AlphaFold-class fold inference"
  row (RoseTTAFold qualifies as AlphaFold-class)
