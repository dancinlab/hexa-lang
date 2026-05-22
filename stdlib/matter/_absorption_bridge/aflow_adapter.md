# `aflow_adapter.md` — AFLOW (Automatic-FLOW for Materials Discovery) absorption adapter

> **Phase G+2 (2026-05-13)** · 13th adapter in `_absorption_bridge/`
> Sister of `materials_project_adapter` / `oqmd_adapter` / `nomad_adapter` / `cod_adapter`.

---

## What it does

`_absorption_bridge/aflow/aflow_search_smoke.py` is the adapter shape that
lets hexa-matter absorb records from the **AFLOW** (Automatic-FLOW for
Materials Discovery) database (Curtarolo group, Duke University). AFLOW is
a 3M+-entry DFT-computed compound database — the largest single computational
materials database as of 2024. Distinct from COD (experimental XRD) and from
Matlantis (commercial NNP).

Two paths:

1. **Offline (`--selftest`)** — load `cache/sample_record.json`, validate
   schema (auid matches `aflow:<16-hex>`, dft_method indicates DFT,
   formation_enthalpy_atom_eV + enthalpy_atom_eV numeric, prototype_label
   present), emit sentinel. Deterministic; offline.
2. **Live (`--auid aflow:HHHHHHHHHHHHHHHH`)** — stdlib `urllib.request`
   fetch of the JSON at `http://aflow.org/API/aflux/?aurl=<auid>`. NOT
   exercised in the selftest (per `NO LIVE API CALLS in selftest` rule).

Selftest sentinel: `__HEXA_MATTER_AFLOW_SEARCH_SMOKE__ PASS`.
Aggregator wrapper sentinel: `__HEXA_MATTER_AFLOW_SMOKE__ PASS`.

## License

- Raw computational data: **CC-BY 4.0** per AFLOW data policy
  (http://aflow.org/aflow-license.html). Citation to Curtarolo 2012 is required.
- Adapter code: MIT (hexa-matter convention).
- **No API key, no signup**. Public AFLUX REST endpoint.

## Citation

- Curtarolo, S. et al. "AFLOW: An automatic framework for high-throughput
  materials discovery." **Comput. Mater. Sci.** 58, 218–226 (2012).
  DOI: 10.1016/j.commatsci.2012.02.005
- Toher, C. et al. "The AFLOW Fleet for Materials Discovery."
  **Mater. Today** 21, 757–765 (2018).
  DOI: 10.1016/j.mattod.2017.11.001
- Rose, F. et al. "AFLUX: The LUX materials search API for the AFLOW data
  repositories." **Comput. Mater. Sci.** 137, 362–370 (2017).
  DOI: 10.1016/j.commatsci.2017.04.036

Version stamped: AFLOW rolling release (no fixed version number; adapters
cache by `auid`).

## Honesty (per bridge rules in AGENTS.md)

- **stdlib fallback**: the adapter is pure stdlib; no optional dep required
  for the offline selftest path. The live path uses `urllib.request` (also
  stdlib). Optional `aflow` PyPI client may be used downstream but is NOT
  required.
- **offline selftest only**: the bundled `cache/sample_record.json` fixture
  carries `__fixture_tag__: SAMPLE FIXTURE — not real data, for selftest
  replay only`. `--selftest` never touches the network.
- **License honesty**: this file + `aflow/SOURCES.md` cite paper + license + DOI.
- **predictions ≠ measurements**: AFLOW records are DFT PREDICTIONS. The
  adapter validator REJECTS any record whose `dft_method` is mis-labelled
  as `experimental` or `measured`. AFLOW does NOT curate synthesis status —
  many entries are prototype-substituted hypothetical compounds that have
  never been synthesized.
  cell volumes, and DFT band gaps belong to the underlying AFLOW Standard
  DFT calculation, with documented per-record numerical-convergence
  parameters (ENCUT, k-point density). The adapter passes them through
  untouched.

## Falsifier-relevance

- **Formation-enthalpy cross-check**: when a hexa-matter spec doc cites a
  thermodynamic ΔHf value (e.g. for a hypothetical phase), the adapter lets
  that claim be cross-validated against the AFLOW-computed ΔHf for the same
  composition + prototype.
- **Cross-DB DFT consistency**: AFLOW vs MP vs OQMD vs OMat24 disagreements
  on the same composition (typically 10–50 meV/atom) flag method-choice
  systematics — these are signal, not noise. AFLOW's huge prototype
  catalog is particularly valuable for spotting prototypes the other DBs
  missed.
- **Synthesis-status honesty floor**: AFLOW's `is_synthesized: unknown`
  marker is structural — any spec doc that quotes an AFLOW entry as
  "synthesized" without independent verification is mis-using the source.

## When this module SKIPs vs FAILs

| Situation | Outcome |
|---|---|
| Fixture present + schema valid | **PASS** (exit 0) |
| Fixture missing | **FAIL** (exit 1) |
| Fixture schema invalid (auid format wrong, mis-labelled as experimental, etc.) | **FAIL** (exit 1) |
| Live REST endpoint unreachable during `--selftest` | N/A — selftest never calls live API |
| `--auid` live call + network down | exit 2 with diagnostic; not a CI gate |

## Wiring

- Adapter: `_absorption_bridge/aflow/aflow_search_smoke.py`
- SOURCES: `_absorption_bridge/aflow/SOURCES.md`
- Fixture: `_absorption_bridge/aflow/cache/sample_record.json`
- Selftest wrapper: `_absorption_bridge/selftest/aflow_smoke.py`
- Aggregator: `selftest/absorption_bridge_smoke.sh` (Phase G aggregator)
- Top-level dedicated gate: `selftest/aflow_adapter_smoke.sh` (Phase G+2)

## Cross-link

- `_absorption_bridge/materials_project/` — DFT-computed sister database (~150k entries)
- `_absorption_bridge/oqmd/` — DFT-computed sister database (~1M entries)
- `_absorption_bridge/nomad/` — FAIR data repository (multi-code DFT archive)
- `_absorption_bridge/cod/` — experimental XRD measurements (CC0)
- `_absorption_bridge/gnome/` — DeepMind GNoME (2.2M predictions, never synthesized)
