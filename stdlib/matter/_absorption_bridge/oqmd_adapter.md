# `oqmd_adapter.md` — Open Quantum Materials Database (OQMD) absorption adapter

> **Phase G+2 (2026-05-13)** · 12th adapter in `_absorption_bridge/`
> Sister of `materials_project_adapter` / `aflow_adapter` / `nomad_adapter` / `cod_adapter`.

---

## What it does

`_absorption_bridge/oqmd/oqmd_search_smoke.py` is the adapter shape that lets
hexa-matter absorb records from the **Open Quantum Materials Database** (OQMD,
Wolverton group, Northwestern University). OQMD is a 1M+-entry DFT-PBE
calculation database of inorganic crystal structures — formation energies,
stability (energy above hull), band gaps. Distinct from COD (experimental
XRD) and from Matlantis (commercial NNP).

Two paths:

1. **Offline (`--selftest`)** — load `cache/sample_record.json`, validate
   schema (entry_id integer, prediction_method indicates DFT, formation /
   stability energies numeric), emit sentinel. Deterministic; offline.
2. **Live (`--entry-id NNNNNN`)** — stdlib `urllib.request` fetch of the JSON
   at `http://oqmd.org/oqmdapi/formationenergy?filter=entry_id=NNNNNN`. NOT
   exercised in the selftest (per `NO LIVE API CALLS in selftest` rule).

Selftest sentinel: `__HEXA_MATTER_OQMD_SEARCH_SMOKE__ PASS`.
Aggregator wrapper sentinel: `__HEXA_MATTER_OQMD_SMOKE__ PASS`.

## License

- Raw computational data: **CC-BY 4.0** per OQMD data policy
  (http://oqmd.org/about). Citation to Saal 2013 + Kirklin 2015 is required.
- Adapter code: MIT (hexa-matter convention).
- **No API key, no signup**. Public REST endpoint.

## Citation

- Saal, J. E. et al. "Materials Design and Discovery with High-Throughput
  Density Functional Theory: The Open Quantum Materials Database (OQMD)."
  **JOM** 65, 1501–1509 (2013). DOI: 10.1007/s11837-013-0755-4
- Kirklin, S. et al. "The Open Quantum Materials Database (OQMD): assessing
  the accuracy of DFT formation energies." **npj Comput. Mater.** 1, 15010
  (2015). DOI: 10.1038/npjcompumats.2015.10

Version stamped: OQMD rolling release (no fixed version number; adapters
cache by `entry_id`).

## Honesty (per bridge rules in AGENTS.md)

- **stdlib fallback**: the adapter is pure stdlib; no optional dep required
  for the offline selftest path. The live path uses `urllib.request` (also
  stdlib). Optional `qmpy_rester` PyPI client may be used downstream but
  is NOT required.
- **offline selftest only**: the bundled `cache/sample_record.json` fixture
  carries `__fixture_tag__: SAMPLE FIXTURE — not real data, for selftest
  replay only`. `--selftest` never touches the network.
- **License honesty**: this file + `oqmd/SOURCES.md` cite paper + license + DOI.
- **predictions ≠ measurements**: OQMD records are DFT-PBE PREDICTIONS. The
  adapter validator REJECTS any record whose `prediction_method` is mis-labelled
  as `experimental` or `measured`. This is a structural distinguisher from
  the COD adapter (which is the inverse — it rejects predictions labelled as
  measurements).
  + cell volumes belong to the underlying DFT-PBE calculation, with the
  Kirklin 2015 systematic-error bars (MAE ~50–100 meV/atom on ΔHf). The
  adapter passes them through untouched.

## Falsifier-relevance

- **Formation-energy cross-check**: when a hexa-matter spec doc cites a
  thermodynamic ΔHf value (e.g. `ceramics/ceramics.md` for Al₂O₃, SiC,
  Si₃N₄), the adapter lets that claim be cross-validated against the
  OQMD-computed ΔHf for the same composition.
- **Cross-DB DFT consistency**: OQMD vs MP vs AFLOW vs OMat24 disagreements
  on the same composition (typically 10–50 meV/atom) flag method-choice
  systematics — these are signal, not noise.
- **Band-gap honesty floor**: OQMD PBE band gaps under-predict by 30–50%.
  Specs that quote OQMD band gaps as measurements would be wrong; the
  adapter exposes the `band_gap_PBE_eV` field so downstream consumers
  can apply scissor corrections if needed (but the bridge does NOT apply
  numbers).

## When this module SKIPs vs FAILs

| Situation | Outcome |
|---|---|
| Fixture present + schema valid | **PASS** (exit 0) |
| Fixture missing | **FAIL** (exit 1) |
| Fixture schema invalid (missing field, mis-labelled as experimental, etc.) | **FAIL** (exit 1) |
| Live REST endpoint unreachable during `--selftest` | N/A — selftest never calls live API |
| `--entry-id` live call + network down | exit 2 with diagnostic; not a CI gate |

## Wiring

- Adapter: `_absorption_bridge/oqmd/oqmd_search_smoke.py`
- SOURCES: `_absorption_bridge/oqmd/SOURCES.md`
- Fixture: `_absorption_bridge/oqmd/cache/sample_record.json`
- Selftest wrapper: `_absorption_bridge/selftest/oqmd_smoke.py`
- Aggregator: `selftest/absorption_bridge_smoke.sh` (Phase G aggregator)
- Top-level dedicated gate: `selftest/oqmd_adapter_smoke.sh` (Phase G+2)

## Cross-link

- `_absorption_bridge/materials_project/` — DFT-computed sister database (~150k entries, LBNL/Berkeley)
- `_absorption_bridge/aflow/` — DFT-computed sister database (3M+ entries, Curtarolo)
- `_absorption_bridge/nomad/` — FAIR data repository (multi-code DFT archive)
- `_absorption_bridge/cod/` — experimental XRD measurements (CC0)
- `_absorption_bridge/gnome/` — DeepMind GNoME (2.2M predictions, never synthesized)
