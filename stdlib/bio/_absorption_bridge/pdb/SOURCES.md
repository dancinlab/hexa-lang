# `pdb/SOURCES.md` — RCSB Protein Data Bank

> hexa-bio cycle-30++++++++ absorption adapter target: `pdb_api_smoke.py`

---

## System

- **Name**: RCSB PDB (US arm of wwPDB — worldwide Protein Data Bank consortium)
- **Maintainer**: Research Collaboratory for Structural Bioinformatics (Rutgers + UCSD)
- **Web**: https://www.rcsb.org
- **REST API**: https://data.rcsb.org/rest/v1/core/entry
- **Scale (2024)**: ~225k experimentally-determined structures (X-ray, cryo-EM, NMR, neutron)

## Authoritative citation

- Burley, S.K. et al. "RCSB Protein Data Bank (RCSB.org): delivery of experimentally-determined PDB structures alongside one million computed structure models of proteins from artificial intelligence/machine learning." **Nucleic Acids Research** 51(D1), D488-D508 (2023). DOI: 10.1093/nar/gkac1077

## API endpoint + auth

- Base URL: `https://data.rcsb.org/rest/v1/core/entry/{pdb_id}`
- Auth: none (free public API)
- Rate limits: anonymous; documented at https://data.rcsb.org/
- PDB id scheme: 4 alphanumeric chars (`7C2L`, `6VXX`, ...)

## Output schema (this adapter validates)

- `entry.id` — 4-char PDB identifier
- `struct.title` — descriptive title
- `exptl[].method` — experimental method (X-RAY DIFFRACTION, ELECTRON
  MICROSCOPY, SOLUTION NMR, ...)
- `rcsb_entry_info`: `polymer_entity_count_protein`, `polymer_composition`,
  `resolution_combined`, `deposited_atom_count`, `deposited_residue_count`
- `rcsb_accession_info`: `deposit_date`, `initial_release_date`,
  `revision_date`
- `rcsb_primary_citation`: title + journal + year + PubMed id

## License

- **Data: CC0 / Public Domain** (RCSB PDB / wwPDB policy)
- API: free; citation recommended

## Honest notes

- **Experimental data, NOT predictions** — unlike AF3 / RoseTTAFold /
  ESMFold / OpenFold / ColabFold, PDB entries are experimentally
  determined. Resolution and R-factor encode experimental quality.
- **No n=6 lattice-fit** applied to PDB records (C3).
- **Complementary to** `_python_bridge/module/virocapsid_pdb_corpus.py`
  (which handles VIPERdb-curated capsid corpus); this adapter is the
  generic single-entry REST counterpart.
- **Adapter caching**: bundled fixture `cache/sample_entry.json` (7C2L
  cryo-EM spike trimer shape).

## Cross-link

- `_absorption_bridge/pdb/pdb_api_smoke.py` — this adapter
- `_python_bridge/module/virocapsid_pdb_corpus.py` — VIPERdb capsid corpus
- `_absorption_bridge/uniprot/SOURCES.md` — sibling reference DB adapter
