# `catalysis_hub/SOURCES.md` — Catalysis-Hub (NTNU + Stanford SUNCAT)

> Phase J.3 adapter target: `catalysis_hub_search_smoke.py` (offline schema replay; real fetch via the public Catalysis-Hub GraphQL API endpoint)

---

## System

- **Name**: Catalysis-Hub.org (open electronic-structure database for surface reactions)
- **Maintainer**: NTNU (Norwegian University of Science and Technology) + SUNCAT Center for Interface Science and Catalysis (Stanford / SLAC)
- **Web**: https://www.catalysis-hub.org/
- **GraphQL API**: https://api.catalysis-hub.org/graphql
- **Browse endpoints**: `Reactions` · `Publications` · `Systems` · `Materials`
- **Scale (as of 2024)**: > 100,000 surface reactions / adsorption energies; > 10⁶ underlying DFT calculations
- **DFT codes used**: GPAW (default) + VASP (heavy share)
- **Default xc-functional**: BEEF-vdW (for adsorption energies and reaction energies); some sub-collections use PBE / RPBE / SCAN

## Authoritative citations

- Winther, K. T., Hoffmann, M. J., Boes, J. R., Mamun, O., Bajdich, M., Bligaard, T. "Catalysis-Hub.org, an open electronic structure database for surface reactions of solid materials." **Sci. Data** 6, 75 (2019). DOI: 10.1038/s41597-019-0081-y
- Schlexer Lamoureux, P., Winther, K. T., Garrido Torres, J. A., Streibel, V., Zhao, M., Bajdich, M., Abild-Pedersen, F., Bligaard, T. "Machine Learning for Computational Heterogeneous Catalysis." **ChemCatChem** 11, 3833–3855 (2019). DOI: 10.1002/cctc.201900595
- Mamun, O., Winther, K. T., Boes, J. R., Bligaard, T. "High-throughput calculations of catalytic properties of bimetallic alloy surfaces." **Sci. Data** 6, 76 (2019). DOI: 10.1038/s41597-019-0080-z

## REST / GraphQL endpoint shape

- Reactions list: GraphQL query `query { reactions(first: 10) { edges { node { id reactants products reactionEnergy activationEnergy chemicalComposition facet } } } }` against https://api.catalysis-hub.org/graphql
- Per-reaction details: filter by `id` or `reactionEnergy` or `facet` or `chemicalComposition`
- Publications: `query { publications { edges { node { doi title authors } } } }`
- No API key, no auth for read. Polite cadence (≤ 1 req / 3 s) recommended for bulk pulls.
- Python client (optional): `catalysis-hub` PyPI wrapper (NOT required by this adapter).

## License

- **Raw computational data: CC-BY 4.0** per Catalysis-Hub data policy
  (https://www.catalysis-hub.org/about). Citation to Winther 2019 + Schlexer
  Lamoureux 2019 required.
- This adapter passes records through AS-IS; no re-licensing of the raw
  adsorption / reaction energies is implied.
- Adapter code: MIT (hexa-matter convention).

## Schema (per record, abbreviated)

| Field | Type | Note |
|---|---|---|
| `reaction_id` | int | Catalysis-Hub numeric identifier |
| `reaction_label` | str | human-readable reaction string |
| `reactants` | str | reactant species, `+` separated, `star` = surface site |
| `products` | str | product species (often `Xstar` = X adsorbed) |
| `surface_facet` | str | e.g. `Cu(111)`, `Pt(211)` |
| `surface_composition` | str | element / alloy of the slab |
| `facet_miller` | str | Miller indices `(h k l)` |
| `adsorption_site` | str | top / bridge / hcp / fcc / hollow |
| `reaction_energy_eV` | float | ΔE_rxn |
| `activation_energy_eV` | float | E_a (when computed; -1 sentinel if N/A) |
| `xc_functional` | str | BEEF-vdW default; PBE/RPBE/SCAN sub-collections |
| `dft_code` | str | GPAW (default) or VASP |
| `k_points` | str | Monkhorst-Pack sampling |
| `vacuum_A` | float | slab vacuum thickness in Å |
| `prediction_method` | str | must indicate DFT (validator enforces) |
| `is_synthesized` | str | typically `N/A` — computational adsorption-energy DB; surface model only |
| `publication` | dict | Winther 2019 + Schlexer Lamoureux 2019 |

## Honest notes

- Catalysis-Hub records are **predictions** (DFT, mostly BEEF-vdW + GPAW),
  not measurements. Distinct from:
  - COD (experimental crystal structures, CC0)
  - NIMS MatNavi (BOTH experimental and computed; dual-mode distinguisher)
  - MP / OQMD / AFLOW / NOMAD / OMat24 / GNoME (bulk DFT, not surface
    reactions)
- The adapter validator REJECTS any record whose `prediction_method` is
  mis-labelled as experimental — Catalysis-Hub is DFT-ONLY by construction.
- **Surface-reaction adsorption-energy MAE**: BEEF-vdW reaction-energy
  agreement vs experiment is typically ~0.1–0.2 eV when good calorimetry
  data exists; PBE looser. The Winther 2019 paper documents the
  cross-functional spread. The adapter does NOT apply scissor corrections
  or re-scaling — it passes the underlying DFT number through.
  per-functional-class error bars (BEEF-vdW Bayesian error estimates
  available where the workflow stored them; PBE typical scatter
  documented per dataset) are the authoritative bars.
- **Sister DB to OMat24**: OMat24 carries the bulk-property DFT trajectory
  data; Catalysis-Hub carries the surface-reaction product. Both Meta-
  funded (SUNCAT historical SLAC-DOE funding; OMat24 Meta AI).
- The adapter's selftest is **offline fixture replay only**. Live GraphQL
  hits are gated behind explicit runtime use and identify themselves with
  a User-Agent.

## Cross-link

- `_absorption_bridge/materials_project/SOURCES.md` — bulk DFT sister (LBNL; not surface reactions)
- `_absorption_bridge/oqmd/SOURCES.md` — bulk DFT sister (Northwestern; not surface reactions)
- `_absorption_bridge/aflow/SOURCES.md` — bulk DFT sister (Duke; not surface reactions)
- `_absorption_bridge/nomad/SOURCES.md` — FAIR archive (EU; can host surface-reaction data too)
- `_absorption_bridge/omat24/SOURCES.md` — bulk-property DFT trajectories sister (Meta AI)
- `_absorption_bridge/nims_mats/SOURCES.md` — Japan-focused experimental + computed (Phase J.3 sister)
- `_absorption_bridge/cod/SOURCES.md` — experimental XRD (CC0; predictions vs measurements distinguisher inverse)
- `mof/mof.md` — MOF-DAC adsorbent claims that surface-reaction DFT may inform (but does NOT validate at synthesis scale — DAC economics remain UNPROVEN per §INIT.md)
