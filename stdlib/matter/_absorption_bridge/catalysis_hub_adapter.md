# `catalysis_hub_adapter.md` — Catalysis-Hub (NTNU + Stanford SUNCAT) absorption adapter

> **Phase J.3 (2026-05-13)** · 16th adapter in `_absorption_bridge/`
> Sister of `materials_project_adapter` / `oqmd_adapter` / `aflow_adapter` / `nomad_adapter` / `omat24_adapter` / `nims_mats_adapter`.

---

## What it does

`_absorption_bridge/catalysis_hub/catalysis_hub_search_smoke.py` is the
adapter shape that lets hexa-matter absorb records from **Catalysis-Hub.org**
(NTNU + Stanford SUNCAT). Catalysis-Hub is an open electronic-structure
database of > 100,000 surface reactions / adsorption energies, computed
with DFT (GPAW default + VASP; mostly BEEF-vdW exchange-correlation
functional).

Catalysis-Hub fills a gap among the absorption-bridge sources: surface
reactions on heterogeneous-catalyst slabs. Distinct from:

- COD (experimental crystal structures, CC0)
- MP / OQMD / AFLOW / NOMAD / OMat24 / GNoME (bulk-property DFT, not
  surface reactions)
- NIMS MatNavi (both experimental + computed, but Japan-industrial bulk
  properties — not surface reactions)
- Matlantis (commercial NNP; not surface-reaction-specialised database)

Two paths:

1. **Offline (`--selftest`)** — load `cache/sample_record.json`, validate
   schema (reaction_id positive int, surface_facet non-empty,
   reaction_energy_eV numeric, prediction_method indicates DFT,
   xc_functional present, dft_code in recognised set), emit sentinel.
   Deterministic; offline.
2. **Live (`--reaction-id NNNN`)** — stdlib `urllib.request` POST of a small
   GraphQL query to `https://api.catalysis-hub.org/graphql`. NOT exercised
   in the selftest (per `NO LIVE API CALLS in selftest` rule).

Selftest sentinel: `__HEXA_MATTER_CATALYSIS_HUB_SEARCH_SMOKE__ PASS`.
Aggregator wrapper sentinel: `__HEXA_MATTER_CATALYSIS_HUB_SMOKE__ PASS`.

## License

- **Raw computational data: CC-BY 4.0** per Catalysis-Hub data policy
  (https://www.catalysis-hub.org/about). Citation to Winther 2019 +
  Schlexer Lamoureux 2019 required.
- Adapter code: MIT (hexa-matter convention).
- **No API key, no signup** for read access.

## Citation

- Winther, K. T., Hoffmann, M. J., Boes, J. R., Mamun, O., Bajdich, M.,
  Bligaard, T. "Catalysis-Hub.org, an open electronic structure database
  for surface reactions of solid materials." **Sci. Data** 6, 75 (2019).
  DOI: 10.1038/s41597-019-0081-y
- Schlexer Lamoureux, P., Winther, K. T., Garrido Torres, J. A., Streibel,
  V., Zhao, M., Bajdich, M., Abild-Pedersen, F., Bligaard, T. "Machine
  Learning for Computational Heterogeneous Catalysis." **ChemCatChem** 11,
  3833–3855 (2019). DOI: 10.1002/cctc.201900595

Version stamped: Catalysis-Hub rolling release (no fixed version number;
adapters cache by `reaction_id`).

## Honesty (per bridge rules in AGENTS.md)

- **stdlib fallback**: the adapter is pure stdlib; no optional dep required
  for the offline selftest path. The live path uses `urllib.request` (also
  stdlib). Optional `catalysis-hub` PyPI wrapper may be used downstream but
  is NOT required.
- **offline selftest only**: the bundled `cache/sample_record.json` fixture
  carries `__fixture_tag__: SAMPLE FIXTURE — not real data, for selftest
  replay only`. `--selftest` never touches the network.
- **License honesty**: this file + `catalysis_hub/SOURCES.md` cite paper +
  license + DOI + version.
- **predictions ≠ measurements**: Catalysis-Hub records are DFT PREDICTIONS
  ONLY (by construction of the database). The adapter validator REJECTS
  any record whose `prediction_method` is mis-labelled as `experimental`
  or `measured`. This is the inverse-discipline mirror of the COD adapter
  and the strict-prediction sister of the NIMS MatNavi adapter's dual-mode
  tag.
  activation-energy values are DFT predictions with their own published
  error bars (BEEF-vdW adsorption-energy MAE ~0.1–0.2 eV vs experiment per
  Winther 2019; PBE looser). The adapter passes them through untouched.

## Falsifier-relevance

- **Surface-reaction energy cross-check**: when a hexa-matter spec doc
  cites an adsorption energy or a reaction step ΔE for a CO₂-reduction /
  N₂-fixation / OER / ORR pathway, the adapter lets that claim be cross-
  validated against the corresponding Catalysis-Hub reaction record (e.g.
  CO₂ → CO adsorption on Cu(111) for CO₂-reduction electrocatalyst
  candidates).
- **MOF / electrode-material adsorption claims**: `mof/mof.md` MOF-DAC
  adsorbent claims and `electrode-material/electrode-material.md` ORR /
  OER electrocatalyst claims can be cross-anchored to surface-reaction
  DFT data. NOTE: surface-reaction DFT does NOT close DAC ECONOMICS (the
  magic-MOF $100/t claim remains UNPROVEN per INIT.md hard rules) — it
  only anchors the energy-step physics.
- **Predicted-vs-experiment gap**: BEEF-vdW typical adsorption-energy MAE
  ~0.1–0.2 eV vs experiment; the adapter exposes the `xc_functional` field
  so downstream consumers can apply functional-specific corrections — but
  re-deriving the entity's numbers).

## When this module SKIPs vs FAILs

| Situation | Outcome |
|---|---|
| Fixture present + schema valid | **PASS** (exit 0) |
| Fixture missing | **FAIL** (exit 1) |
| Fixture schema invalid (missing field, mis-labelled as experimental, unrecognised DFT code, etc.) | **FAIL** (exit 1) |
| Live GraphQL endpoint unreachable during `--selftest` | N/A — selftest never calls live API |
| `--reaction-id` live call + network down | exit 2 with diagnostic; not a CI gate |

## Wiring

- Adapter: `_absorption_bridge/catalysis_hub/catalysis_hub_search_smoke.py`
- SOURCES: `_absorption_bridge/catalysis_hub/SOURCES.md`
- Fixture: `_absorption_bridge/catalysis_hub/cache/sample_record.json`
- Selftest wrapper: `_absorption_bridge/selftest/catalysis_hub_smoke.py`
- Aggregator: `selftest/absorption_bridge_smoke.sh` (Phase G aggregator)
- Top-level dedicated gate: `selftest/catalysis_hub_adapter_smoke.sh` (Phase J.3)

## Cross-link

- `_absorption_bridge/materials_project/` — bulk DFT sister (LBNL; not surface reactions)
- `_absorption_bridge/oqmd/` — bulk DFT sister (Northwestern; not surface reactions)
- `_absorption_bridge/aflow/` — bulk DFT sister (Duke; not surface reactions)
- `_absorption_bridge/nomad/` — FAIR archive (EU; can host surface-reaction data too)
- `_absorption_bridge/omat24/` — bulk-property DFT trajectories sister (Meta AI)
- `_absorption_bridge/nims_mats/` — Japan-focused experimental + computed (Phase J.3 sister)
- `_absorption_bridge/cod/` — experimental XRD (CC0; inverse distinguisher)
- `mof/mof.md` — adsorbent claims that surface-reaction DFT may inform (DAC economics remain UNPROVEN)
- `electrode-material/electrode-material.md` — ORR / OER electrocatalyst claims that Catalysis-Hub anchors
