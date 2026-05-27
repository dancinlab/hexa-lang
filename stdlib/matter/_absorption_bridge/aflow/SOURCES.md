# `aflow/SOURCES.md` — AFLOW (Automatic-FLOW for Materials Discovery)

> Phase G+2 adapter target: `aflow_search_smoke.py` (offline schema replay; real fetch via the public AFLOW REST/AFLUX API endpoint)

---

## System

- **Name**: AFLOW — Automatic-FLOW for Materials Discovery
- **Maintainer**: Curtarolo group, Duke University (Center for Materials Genomics)
- **Web**: http://aflow.org/
- **API**: AFLUX (`http://aflow.org/API/aflux/?aurl=...`) — RESTful query language over the AFLOW database
- **Python client (optional)**: `aflow` (PyPI), not required by this adapter
- **Scale (as of 2024)**: > 3,500,000 DFT-computed compounds (largest single computational materials database)

## Authoritative citations

- Curtarolo, S. et al. "AFLOW: An automatic framework for high-throughput materials discovery." **Comput. Mater. Sci.** 58, 218–226 (2012). DOI: 10.1016/j.commatsci.2012.02.005
- Toher, C. et al. "The AFLOW Fleet for Materials Discovery." **Mater. Today** 21, 757–765 (2018). DOI: 10.1016/j.mattod.2017.11.001
- Rose, F. et al. "AFLUX: The LUX materials search API for the AFLOW data repositories." **Comput. Mater. Sci.** 137, 362–370 (2017). DOI: 10.1016/j.commatsci.2017.04.036
- Isayev, O. et al. "Universal fragment descriptors for predicting properties of inorganic crystals." **Nat. Commun.** 8, 15679 (2017). DOI: 10.1038/ncomms15679

## REST endpoint shape

- AFLUX query: `http://aflow.org/API/aflux/?aurl=<auid>&format=json`
- Example by composition: `http://aflow.org/API/aflux/?species(Si):catalog(ICSD)`
- Example by prototype: `http://aflow.org/API/aflux/?Bravais_lattice_relax(cubic)`
- No API key, no auth. Polite cadence recommended.
- Bulk REST: AFLUX docs at http://aflow.org/API/aflux/

## License

- **Raw computational data: CC-BY 4.0** per the AFLOW data policy
  (http://aflow.org/aflow-license.html). Citation to Curtarolo 2012 is
  REQUIRED by the license.
- This adapter passes records through AS-IS; no re-licensing of the raw
  formation enthalpies or DFT energies is implied.

## Schema (per record, abbreviated)

| Field | Type | Note |
|---|---|---|
| `auid` | str | AFLOW unique ID: `aflow:<16-hex>` |
| `compound` | str | compound formula (e.g. `Si2`) |
| `prototype_label` | str | AFLOW prototype encoding |
| `spacegroup_relax` | str | post-relaxation space group (Hermann-Mauguin) |
| `spacegroup_it` | int | International Tables number |
| `natoms` | int | atoms in primitive cell |
| `formation_enthalpy_atom_eV` | float | ΔHf per atom (eV) |
| `enthalpy_atom_eV` | float | total enthalpy per atom (eV) |
| `egap_eV` | float | DFT band gap (PBE — under-predicts) |
| `volume_atom_A3` | float | volume per atom (Å³) |
| `density_g_cm3` | float | bulk density |
| `dft_method` | str | typically `DFT-PBE (VASP PAW, AFLOW Standard parameters)` |
| `is_synthesized` | str | typically `unknown` — AFLOW does not curate synthesis |
| `publication` | dict | Curtarolo 2012 + Toher 2018 + Rose 2017 + Isayev 2017 |

## Honest notes

- AFLOW records are **predictions** (DFT-PBE primarily; some PBEsol / SCAN
  entries exist). Distinct from COD (experimental XRD) and from Matlantis
  (commercial NNP). Many AFLOW entries are prototype substitutions —
  hypothetical compounds whose elemental decoration was swapped onto a
  known crystal prototype, then relaxed. Most have NEVER been synthesized.
  parameters (ENCUT, k-point density, smearing) are documented per-record
  in the entry metadata; those are the authoritative numerical-convergence
  bars.
- **Cross-DB systematic differences**: AFLOW vs MP vs OQMD typically agree
  on formation energies to within 10–50 meV/atom for the same composition.
  Disagreements reflect different relaxation protocols, pseudopotential
  choices, and DFT-functional choices — they are signal, not noise.
- **PBE band gaps under-predict by 30–50%**. The `egap_eV` field is exposed
  but the bridge does NOT apply scissor corrections (that would violate
- The adapter's selftest is **offline fixture replay only**. Live REST hits
  are gated behind explicit `--auid` runtime use.

## Cross-link

- `_absorption_bridge/materials_project/SOURCES.md` — DFT-computed sister db (LBNL/Berkeley; ~150k entries)
- `_absorption_bridge/oqmd/SOURCES.md` — DFT-computed sister db (Wolverton; ~1M entries)
- `_absorption_bridge/nomad/SOURCES.md` — FAIR data repository (multi-code DFT archive)
- `_absorption_bridge/cod/SOURCES.md` — experimental XRD measurements (CC0)
- `_absorption_bridge/gnome/SOURCES.md` — DeepMind GNoME (purely predicted, 2.2M)

