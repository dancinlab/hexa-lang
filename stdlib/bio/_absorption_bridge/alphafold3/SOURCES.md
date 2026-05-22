# `alphafold3/SOURCES.md` — DeepMind AlphaFold-3

> hexa-bio cycle-30++++++++ absorption adapter target: `af3_smoke.py`
> (offline schema replay; live use requires gated weights download from DeepMind)

---

## System

- **Name**: AlphaFold-3
- **Maintainer**: Google DeepMind + Isomorphic Labs
- **Web**: https://deepmind.google/discover/blog/alphafold-3-predicts-the-structure-and-interactions-of-all-of-lifes-molecules/
- **Server (academic)**: https://golgi.sandbox.google.com (AlphaFold Server, free for non-commercial research; rate-limited)
- **Reference code**: https://github.com/google-deepmind/alphafold3 (released 2024-11)
- **Scale**: extends AlphaFold-2 from single-protein folds to protein-protein, protein-ligand, protein-nucleic-acid, protein-ion complexes; covers all major bio-molecule types in one model

## Authoritative citation

- Abramson, J. et al. "Accurate structure prediction of biomolecular interactions with AlphaFold 3." **Nature** 630, 493-500 (2024). DOI: 10.1038/s41586-024-07487-w

## Output schema (this adapter validates)

- `chains[]` — list of polymer chains (polypeptide / RNA / DNA)
- per-residue: `residue_idx`, residue `name` (3-letter), `pLDDT` (0-100), `atom_xyz`
- `global_metrics`: `pTM`, `ipTM` (interface, for multi-chain), `mean_pLDDT`
- `pAE_matrix_shape` + `pAE_summary` (predicted aligned error, Å)

## License (CRITICAL HONESTY)

- **AlphaFold-3 weights**: released 2024-11 under DeepMind's
  **NON-COMMERCIAL RESEARCH ONLY** license. This is distinct from
  AlphaFold-2's broader CC-BY-4.0 release.
- **Commercial use**: requires a separate license from **Isomorphic Labs**
  (DeepMind's drug-discovery spin-out). hexa-bio does not waive this.
- **Reference code**: Apache-2.0 (the code is OSS; the weights are gated)
- **AlphaFold Server access**: free for non-commercial research; subject
  to DeepMind's terms of use, with daily query rate limits

## Honest notes

- **Predictions, not measurements** — AF3 outputs are computational
  predictions. Per-residue confidence is encoded in `pLDDT`; interface
  confidence in `ipTM`. Novel folds remain UNVERIFIED until experimental
  confirmation (X-ray crystallography, cryo-EM, NMR).
- **No n=6 lattice-fit** applied to AF3 outputs (C3). AF3 carries
  its OWN published metrics — pLDDT is calibrated against per-atom RMSD
  against the deposited PDB structure, not against σ(6)=12.
- **Limitations** documented in Abramson et al. 2024: lower accuracy on
  unstructured / disordered regions, on entries not represented in the
  training distribution, and on cases requiring induced fit; AF3's
  hallucination rate on novel targets is non-zero.
- **Adapter caching**: bundled fixture `cache/sample_prediction.json` for
  selftest replay; real predictions cached at `cache/<md5-stamp>.json`
  when produced via the live server / weights path.

## Cross-link

- `_absorption_bridge/alphafold3/af3_smoke.py` — this adapter
- `HEXA-WEAVE.md` §1 — "Primary oracle: AlphaFold-class fold inference"
- `HEXA-VIROCAPSID.md` §1 — same row in four-sister axis comparison
- `HEXA-NANOBOT.md` / `HEXA-RIBOZYME.md` — same row
- hexa-matter `_absorption_bridge/` — Phase G pattern reference

## Provenance discipline

- Cite predictions by `target_id` + AF3 version (`af3-202411` for the
  2024-11 weights release) + `mean_pLDDT` band, not by raw atom coords.
- Bookkeep license restriction at every downstream consumption: any
  hexa-bio doc that re-uses an AF3 prediction must carry the
  "non-commercial research only" marker.
