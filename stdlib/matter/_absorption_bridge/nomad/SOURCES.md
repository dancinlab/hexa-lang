# `nomad/SOURCES.md` — NOMAD (NOvel MAterials Discovery)

> Phase G+2 adapter target: `nomad_search_smoke.py` (offline schema replay; real fetch via the public NOMAD REST V1 API endpoint)

---

## System

- **Name**: NOMAD — NOvel MAterials Discovery
- **Maintainer**: FAIR-DI / Humboldt-Universität zu Berlin (Draxl group) + Max Planck Society FHI (Scheffler group); EU consortium
- **Web**: https://nomad-lab.eu/
- **API V1**: https://nomad-lab.eu/prod/v1/api/v1/entries/<entry_id>
- **Search**: https://nomad-lab.eu/prod/v1/api/v1/entries/query
- **Python client (optional)**: `nomad-lab` (PyPI), not required by this adapter
- **Scale (as of 2024)**: > 19,000,000 DFT calculations aggregated from VASP / Quantum ESPRESSO / FHI-aims / ABINIT / CP2K / GPAW / SIESTA / Exciting / WIEN2k / CASTEP / many more

## Authoritative citations

- Draxl, C. & Scheffler, M. "NOMAD: The FAIR concept for big data-driven materials science." **MRS Bull.** 43, 676–682 (2018). DOI: 10.1557/mrs.2018.208
- Draxl, C. & Scheffler, M. "The NOMAD laboratory: from data sharing to artificial intelligence." **J. Phys. Mater.** 2, 036001 (2019). DOI: 10.1088/2515-7639/ab13bb
- Scheidgen, M. et al. "NOMAD: A distributed web-based platform for managing materials science research data." **J. Open Source Softw.** 8, 5388 (2023). DOI: 10.21105/joss.05388

## REST endpoint shape

- Entry fetch: `https://nomad-lab.eu/prod/v1/api/v1/entries/<entry_id>`
- Query: `POST https://nomad-lab.eu/prod/v1/api/v1/entries/query` (JSON body)
- Archive download: `https://nomad-lab.eu/prod/v1/api/v1/entries/<entry_id>/archive`
- No API key for read access; uploads require an account (out-of-scope here).
- Polite cadence recommended; respects upstream rate limits.

## License

- **Raw computational data: CC-BY 4.0** per NOMAD data policy
  (https://nomad-lab.eu/nomad-lab/services-uploads.html). Citation to
  Draxl & Scheffler 2018 is required by the license.
- Some uploaded datasets carry additional restrictions specified per-entry
  (rare; visible in the `published_with_embargo` field). The adapter does
  NOT bypass embargo flags.

## Schema (per record, abbreviated — NOMAD V1 shape)

| Field | Type | Note |
|---|---|---|
| `entry_id` | str | NOMAD-internal unique identifier |
| `upload_id` | str | NOMAD upload group identifier |
| `mainfile` | str | originating input/output filename (e.g. `vasprun.xml`) |
| `parser_name` | str | parser used (e.g. `parsers/vasp`) |
| `results.material.chemical_formula_reduced` | str | reduced formula |
| `results.material.symmetry.space_group_number` | int | IT number |
| `results.method.simulation.program_name` | str | DFT code (VASP / Quantum ESPRESSO / FHI-aims / …) |
| `results.method.simulation.dft.xc_functional_names` | list[str] | LibXC identifiers (e.g. GGA_X_PBE) |
| `results.properties.energies.total` | float | total electronic energy (eV) |
| `results.properties.structure.lattice_parameters_A` | list[float] | lattice |
| `is_measurement` | bool | False for computational entries (most of NOMAD) |
| `publication` | dict | Draxl & Scheffler 2018 + Scheidgen 2023 |

## Honest notes

- NOMAD records are **predictions** — aggregated DFT calculations from many
  different codes. Distinct from COD (experimental XRD) and from Matlantis
  (commercial NNP).
- **Multi-code provenance**: unlike MP / OQMD / AFLOW (which standardize on
  VASP), NOMAD preserves the originating DFT code. The same composition
  appearing across VASP / FHI-aims / Quantum ESPRESSO entries will show
  small numerical differences from basis-set / pseudopotential choices;
  these are real, not noise.
  functional + basis-set metadata are the authoritative provenance.
- **Not synthesis-curated**: NOMAD's `is_measurement` field is structural
  (computational vs experimental upload type); it does NOT indicate whether
  a computed composition has been synthesized. Any spec doc quoting a NOMAD
  entry as "synthesized" without independent verification is mis-using
  the source.
- **NOMAD-Oasis experimental extension**: a separate NOMAD-Oasis platform
  hosts experimental data uploads; this adapter does NOT aggregate those
  (would conflate measurement vs prediction).
- The adapter's selftest is **offline fixture replay only**. Live REST hits
  are gated behind explicit `--entry-id` runtime use.

## Cross-link

- `_absorption_bridge/materials_project/SOURCES.md` — DFT-computed sister db (LBNL/Berkeley; VASP-only; ~150k entries)
- `_absorption_bridge/oqmd/SOURCES.md` — DFT-computed sister db (Wolverton; VASP-only; ~1M entries)
- `_absorption_bridge/aflow/SOURCES.md` — DFT-computed sister db (Curtarolo; VASP-only; 3M+ entries)
- `_absorption_bridge/cod/SOURCES.md` — experimental XRD measurements (CC0)
- `_absorption_bridge/gnome/SOURCES.md` — DeepMind GNoME (purely predicted, 2.2M)
- `_python_bridge/module/pymatgen_structure_io.py` — pymatgen can consume NOMAD-archive CIFs downstream

