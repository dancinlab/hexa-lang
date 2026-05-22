# `cod_adapter.md` — Crystallography Open Database (COD) absorption adapter

> **Phase G+1 (2026-05-13)** · 11th adapter in `_absorption_bridge/`
> Sister of `materials_project_adapter` / `omat24_adapter` / `gnome_adapter`.

---

## What it does

`_absorption_bridge/cod/cod_search_smoke.py` is the adapter shape that lets
hexa-matter absorb records from the **Crystallography Open Database** (COD).
COD is a 500,000+-entry open-access collection of EXPERIMENTAL crystal
structures deposited by authors — distinct from DFT databases like Materials
Project / OMat24 / GNoME.

Two paths:

1. **Offline (`--selftest`)** — load `cache/sample_record.json`, validate
   schema (cod_id integer, cell.a > 0, space-group number 1-230,
   measurement_type tag), emit sentinel. Deterministic; offline.
2. **Live (`--cod-id NNNNNNN`)** — stdlib `urllib.request` fetch of the CIF
   at `http://www.crystallography.net/cod/<id>.cif`. NOT exercised in the
   selftest (per `NO LIVE API CALLS in selftest` rule).

Selftest sentinel: `__HEXA_MATTER_COD_SEARCH_SMOKE__ PASS`.
Aggregator wrapper sentinel: `__HEXA_MATTER_COD_SMOKE__ PASS`.

## License

- Raw structural data (cell parameters + atomic positions): **public domain /
  CC0** per COD policy. The IUCr position is that cell parameters carry no
  copyright restriction; the citation-courtesy expectation is to cite the
  depositor + the original publication (plus COD itself).
- Adapter code: MIT (hexa-matter convention).
- **No API key, no signup**. Public REST endpoint, polite-cadence usage
  (≤ 1 req / 3 s) per IUCr server-load guidance.

## Citation

- Gražulis, S. et al. "Crystallography Open Database — an open-access collection
  of crystal structures." **J. Appl. Crystallogr.** 42, 726–729 (2009).
  DOI: 10.1107/S0021889809016690
- Gražulis, S. et al. "Crystallography Open Database (COD): an open-access
  collection of crystal structures and platform for world-wide collaboration."
  **Nucleic Acids Res.** 40, D420–D427 (2012). DOI: 10.1093/nar/gkr900

Version stamped: COD revision as of 2024 (the underlying corpus is rolling;
no fixed release number — adapters cache by `cod_id`).

## Honesty (per bridge rules in AGENTS.md)

- **stdlib fallback**: the adapter is pure stdlib; no optional dep required
  for the offline selftest path. The live path uses `urllib.request` (also
  stdlib).
- **offline selftest only**: the bundled `cache/sample_record.json` fixture
  carries `__fixture_tag__: SAMPLE FIXTURE — not real data, for selftest
  replay only`. `--selftest` never touches the network.
- **License honesty**: this file + `cod/SOURCES.md` cite paper + license + ID.
- **predictions ≠ measurements**: COD records are EXPERIMENTAL. The adapter
  validator REJECTS any record whose `measurement_type` does not contain
  `experimental`/`measured` — preserving the bridge rule that predictions
  (MP/GNoME/OMat24/NNP) must not be silently labelled as measurements.
  This is a structural distinguisher from the DFT-database adapters.
  e.s.d. (typically ~10⁻⁴ Å) belong to the depositor + journal that
  measured them. The adapter passes them through untouched.

## Falsifier-relevance

- **Lattice-parameter cross-check**: when a hexa-matter spec doc (e.g.
  `silicon/silicon.md`) cites a Si lattice constant `a = 5.4307 Å`, the
  adapter lets that claim be cross-validated against COD entry 9008565
  (Si, F d -3 m, a ≈ 5.4309 Å @ 293 K).
- **Vendor-vs-measurement divergence detector**: if a vendor datasheet
  claim disagrees with the depositor-measured COD value beyond the
  reported e.s.d., that's a real falsifier event for the spec.
- **Predicted-vs-measured comparator**: COD provides the experimental
  reference for cell parameters that MP/OMat24/GNoME predict via DFT.
  The DFT-PBE typical systematic over-prediction of lattice constants
  by ~1-2% can be quantified against COD entries — but this is a
  downstream analysis, NOT something the bridge does itself
  (bridges pass-through; they do not re-derive).

## When this module SKIPs vs FAILs

| Situation | Outcome |
|---|---|
| Fixture present + schema valid | **PASS** (exit 0) |
| Fixture missing | **FAIL** (exit 1) |
| Fixture schema invalid (missing field, non-experimental tag, etc.) | **FAIL** (exit 1) |
| Live REST endpoint unreachable during `--selftest` | N/A — selftest never calls live API |
| `--cod-id` live call + network down | exit 2 with diagnostic; not a CI gate |

## Wiring

- Adapter: `_absorption_bridge/cod/cod_search_smoke.py`
- SOURCES: `_absorption_bridge/cod/SOURCES.md`
- Fixture: `_absorption_bridge/cod/cache/sample_record.json`
- Selftest wrapper: `_absorption_bridge/selftest/cod_smoke.py`
- Aggregator: `selftest/absorption_bridge_smoke.sh` (selftest gate 23)
- Top-level selftest scoreboard: now 24/24 PASS (was 23/23).

## Cross-link

- `_absorption_bridge/materials_project/` — DFT-computed sister database (mp-149 = Si)
- `_absorption_bridge/gnome/` — DeepMind GNoME (purely predicted, not synthesized)
- `_absorption_bridge/omat24/` — Meta OMat24 (DFT-computed, 110M)
- `_python_bridge/module/pymatgen_structure_io.py` — pymatgen CIF I/O (Phase E)
- `silicon/silicon.md` — Si lattice claim that COD can falsify
