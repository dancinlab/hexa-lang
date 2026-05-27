# `oqmd/SOURCES.md` — Open Quantum Materials Database (OQMD)

> Phase G+2 adapter target: `oqmd_search_smoke.py` (offline schema replay; real fetch via the public OQMD REST API endpoint)

---

## System

- **Name**: Open Quantum Materials Database (OQMD)
- **Maintainer**: Wolverton group, Northwestern University
- **Web**: http://oqmd.org/
- **API**: http://oqmd.org/oqmdapi/ (RESTful, JSON)
- **Search**: http://oqmd.org/oqmdapi/formationenergy?filter=...
- **Python client (optional)**: `qmpy_rester` (PyPI)
- **Scale (as of 2024)**: > 1,000,000 DFT-PBE calculations of inorganic crystal structures

## Authoritative citations

- Saal, J. E., Kirklin, S., Aykol, M., Meredig, B., Wolverton, C. "Materials Design and Discovery with High-Throughput Density Functional Theory: The Open Quantum Materials Database (OQMD)." **JOM** 65, 1501–1509 (2013). DOI: 10.1007/s11837-013-0755-4
- Kirklin, S. et al. "The Open Quantum Materials Database (OQMD): assessing the accuracy of DFT formation energies." **npj Comput. Mater.** 1, 15010 (2015). DOI: 10.1038/npjcompumats.2015.10

## REST endpoint shape

- Formation-energy query: `http://oqmd.org/oqmdapi/formationenergy?filter=entry_id=NNNNNN&format=json`
- Composition filter: `http://oqmd.org/oqmdapi/formationenergy?filter=composition=Fe2O3`
- Stability filter: `?filter=stability=0`  (returns convex-hull-stable entries)
- No API key, no auth. Polite cadence (≤ 1 req / 3 s) recommended.
- Python client: `pip install qmpy_rester` (not required by this adapter).

## License

- **Raw computational data: CC-BY 4.0** per the OQMD data policy
  (http://oqmd.org/about). Citation to Saal 2013 + Kirklin 2015 is REQUIRED
  by the license.
- This adapter passes records through AS-IS; no re-licensing of the raw
  formation energies is implied.

## Schema (per record, abbreviated)

| Field | Type | Note |
|---|---|---|
| `entry_id` | int | OQMD numeric identifier |
| `formula` | str | reduced formula |
| `composition` | dict | element → stoichiometric count |
| `natoms` | int | atoms per unit cell |
| `spacegroup` | str | Hermann-Mauguin |
| `spacegroup_it` | int | International Tables number |
| `formation_energy_per_atom_eV` | float | ΔHf per atom (eV) |
| `stability_eV_per_atom` | float | energy above hull (eV/atom) |
| `band_gap_PBE_eV` | float | DFT-PBE band gap (under-predicts) |
| `volume_per_atom_A3` | float | cell volume / natoms |
| `prediction_method` | str | typically `DFT-PBE (VASP, OQMD standard pseudopotentials)` |
| `is_synthesized` | str | typically `unknown` — OQMD does not curate synthesis status |
| `publication` | dict | Saal 2013 + Kirklin 2015 |

## Honest notes

- OQMD records are **predictions** (DFT-PBE), not measurements. Distinct from
  COD (which is experimental XRD). Formation energies typically agree with
  experiment within MAE ~50–100 meV/atom; PBE band gaps typically under-predict
  by 30–50%.
  DFT uncertainties (typically reported in Kirklin 2015) are the authoritative
  error bars.
- **Not a measurement source**: OQMD records do not carry experimental anchors.
  Use COD for cell parameters from XRD, MP for cross-validated DFT, or vendor
  datasheets for properties. The adapter's `prediction_method` enforcement
  prevents accidental mis-labelling.
- The adapter's selftest is **offline fixture replay only**. Live REST hits
  are gated behind explicit `--entry-id` runtime use and identify themselves
  with a User-Agent.
- **Cross-DB consistency**: OQMD, Materials Project, and AFLOW all do DFT-PBE
  on similar pseudopotential sets but use different relaxation protocols.
  Disagreements among them (typically 10–50 meV/atom on formation energies)
  are not noise; they represent real method-choice systematics.

## Cross-link

- `_absorption_bridge/materials_project/SOURCES.md` — DFT-computed sister db (LBNL/Berkeley; ~150k entries)
- `_absorption_bridge/aflow/SOURCES.md` — DFT-computed sister db (Curtarolo; 3M+ entries)
- `_absorption_bridge/cod/SOURCES.md` — experimental XRD measurements (CC0)
- `_absorption_bridge/gnome/SOURCES.md` — DeepMind GNoME (purely predicted, 2.2M)
- `silicon/silicon.md` — Si formation energy cross-checked against OQMD entry 645928

