# `nomad_adapter.md` — NOMAD (NOvel MAterials Discovery) absorption adapter

> **Phase G+2 (2026-05-13)** · 14th adapter in `_absorption_bridge/`
> Sister of `materials_project_adapter` / `oqmd_adapter` / `aflow_adapter` / `cod_adapter`.

---

## What it does

`_absorption_bridge/nomad/nomad_search_smoke.py` is the adapter shape that
lets hexa-matter absorb records from **NOMAD** (NOvel MAterials Discovery,
nomad-lab.eu) — a FAIR-data repository aggregating 19M+ DFT calculations
from many DFT codes (VASP / Quantum ESPRESSO / FHI-aims / ABINIT / CP2K /
GPAW / SIESTA / Exciting / WIEN2k / CASTEP / …). Unlike MP / OQMD / AFLOW
(which all standardize on VASP), NOMAD's distinguishing feature is its
multi-code provenance preservation.

Two paths:

1. **Offline (`--selftest`)** — load `cache/sample_record.json`, validate
   NOMAD-V1 schema (entry_id + upload_id strings, results.material present,
   results.method.simulation.program_name a known DFT code,
   results.properties.energies.total numeric), emit sentinel.
   Deterministic; offline.
2. **Live (`--entry-id <id>`)** — stdlib `urllib.request` fetch of the JSON
   at `https://nomad-lab.eu/prod/v1/api/v1/entries/<entry_id>`. NOT
   exercised in the selftest (per `NO LIVE API CALLS in selftest` rule).

Selftest sentinel: `__HEXA_MATTER_NOMAD_SEARCH_SMOKE__ PASS`.
Aggregator wrapper sentinel: `__HEXA_MATTER_NOMAD_SMOKE__ PASS`.

## License

- Raw computational data: **CC-BY 4.0** per NOMAD data policy
  (https://nomad-lab.eu/nomad-lab/services-uploads.html). Citation to
  Draxl & Scheffler 2018 is required.
- Some uploaded datasets carry additional restrictions (rare, embargo-flagged).
- Adapter code: MIT (hexa-matter convention).
- **No API key for read access**. Public REST V1 endpoint.

## Citation

- Draxl, C. & Scheffler, M. "NOMAD: The FAIR concept for big data-driven
  materials science." **MRS Bull.** 43, 676–682 (2018).
  DOI: 10.1557/mrs.2018.208
- Draxl, C. & Scheffler, M. "The NOMAD laboratory: from data sharing to
  artificial intelligence." **J. Phys. Mater.** 2, 036001 (2019).
  DOI: 10.1088/2515-7639/ab13bb
- Scheidgen, M. et al. "NOMAD: A distributed web-based platform for managing
  materials science research data." **J. Open Source Softw.** 8, 5388 (2023).
  DOI: 10.21105/joss.05388

Version stamped: NOMAD V1 API (prod). Underlying corpus is rolling — adapters
cache by `entry_id`.

## Honesty (per bridge rules in AGENTS.md)

- **stdlib fallback**: the adapter is pure stdlib; no optional dep required
  for the offline selftest path. The live path uses `urllib.request` (also
  stdlib). Optional `nomad-lab` PyPI client may be used downstream but is
  NOT required.
- **offline selftest only**: the bundled `cache/sample_record.json` fixture
  carries `__fixture_tag__: SAMPLE FIXTURE — not real data, for selftest
  replay only`. `--selftest` never touches the network.
- **License honesty**: this file + `nomad/SOURCES.md` cite paper + license + DOI.
- **predictions ≠ measurements**: NOMAD records are computational. The adapter
  validator REJECTS any record whose `is_measurement` field is True, and
  REJECTS any record whose `program_name` is not a known DFT code
  (preventing accidental ingestion of non-DFT entries through the DFT
  adapter shape).
- **Multi-code provenance preservation**: unlike MP / OQMD / AFLOW (VASP-only),
  NOMAD aggregates many DFT codes. The adapter surfaces `program_name` in
  its selftest output so the provenance is visible to consumers.
  lattice parameters, and functional + basis-set metadata belong to the
  originating DFT calculation. The adapter passes them through untouched.

## Falsifier-relevance

- **Cross-code DFT consistency**: NOMAD's distinguishing value is that the
  same composition can appear from VASP / FHI-aims / Quantum ESPRESSO
  calculations side-by-side. Per-code differences (typically a few meV/atom
  on total-energy differences) flag basis-set / pseudopotential systematics
  that MP / OQMD / AFLOW (VASP-only) cannot expose.
- **FAIR-data trace**: NOMAD's `upload_id` + `mainfile` + `parser_name`
  chain enables full provenance audit of any quoted number — if a hexa-matter
  spec cites a NOMAD entry, that entry traces back to the original
  uploader's exact input file.
- **Synthesis-status honesty floor**: NOMAD does NOT curate synthesis. Spec
  docs that quote NOMAD entries must NOT claim "synthesized" without an
  independent experimental source (COD / vendor datasheet / etc.).

## When this module SKIPs vs FAILs

| Situation | Outcome |
|---|---|
| Fixture present + schema valid | **PASS** (exit 0) |
| Fixture missing | **FAIL** (exit 1) |
| Fixture schema invalid (unknown program_name, missing required field, is_measurement=True, etc.) | **FAIL** (exit 1) |
| Live REST endpoint unreachable during `--selftest` | N/A — selftest never calls live API |
| `--entry-id` live call + network down | exit 2 with diagnostic; not a CI gate |

## Wiring

- Adapter: `_absorption_bridge/nomad/nomad_search_smoke.py`
- SOURCES: `_absorption_bridge/nomad/SOURCES.md`
- Fixture: `_absorption_bridge/nomad/cache/sample_record.json`
- Selftest wrapper: `_absorption_bridge/selftest/nomad_smoke.py`
- Aggregator: `selftest/absorption_bridge_smoke.sh` (Phase G aggregator)
- Top-level dedicated gate: `selftest/nomad_adapter_smoke.sh` (Phase G+2)

## Cross-link

- `_absorption_bridge/materials_project/` — DFT-computed sister database (VASP-only; ~150k entries)
- `_absorption_bridge/oqmd/` — DFT-computed sister database (VASP-only; ~1M entries)
- `_absorption_bridge/aflow/` — DFT-computed sister database (VASP-only; 3M+ entries)
- `_absorption_bridge/cod/` — experimental XRD measurements (CC0)
- `_absorption_bridge/gnome/` — DeepMind GNoME (2.2M predictions, never synthesized)
