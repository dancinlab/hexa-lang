# `materials_project/SOURCES.md` — Materials Project (Berkeley/LBNL)

> Phase G adapter target: `mp_api_smoke.py` (smoke; real fetch needs `mp-api` SDK + free API key)

---

## System

- **Name**: Materials Project
- **Maintainer**: Lawrence Berkeley National Laboratory / UC Berkeley
- **Web**: https://materialsproject.org
- **API docs**: https://api.materialsproject.org
- **Scale (as of 2024)**: ~154,000 inorganic crystal structures + DFT-computed properties (band gap, formation energy, elastic tensor, band structure, ...)

## Authoritative citation

- Persson, K. A. et al. "Commentary: The Materials Project: A materials genome approach to accelerating materials innovation." **APL Materials** 1, 011002 (2013). DOI: 10.1063/1.4812323

## API endpoint + auth

- Base URL: `https://api.materialsproject.org`
- Auth: free API key required (sign up at https://next-gen.materialsproject.org/api); passed as `X-API-KEY` header
- Python SDK: `pip install mp-api` (optional) — see https://github.com/materialsproject/api
- **stdlib fallback**: `mp_api_smoke.py` does NOT require the SDK. If `mp-api` /
  `MPRester` is unimportable, the adapter queries the `materials/summary`
  REST endpoint directly via stdlib `urllib` (bridge rule g5.1). Both
  `--mp-id` and `--formula` paths work on stock Python 3.9+.
- Rate limits: anonymous / lightly-throttled per key; bulk downloads through Zenodo snapshots
- Identifier scheme: `mp-XXXXX` (e.g. `mp-149` = Si, `mp-1062` = Cu, `mp-30` = AlNi)

## License

- Data: CC-BY 4.0 (Materials Project Terms of Use)
- Citation discipline: each adapter caches the `material_id` + accessed-on timestamp; downstream hexa-matter docs cite `material_id` not raw numeric values

## Honest notes

- **Not a measurement** — Materials Project DFT values are *computed*, not lab-measured. They are first-principles predictions whose error bars vary by property (band gap GGA-PBE typically underestimates by ~50%).
- **Adapter caching**: `cache/<md5-stamp>.json` per request; bundled fixture is `cache/sample_response.json` for selftest replay.
- **SDK dependency conflict (observed 2026-05-17)**: `mp-api` 0.45.9 pulls `emmet-core` 0.84.6rc4, which imports `SymmetryUndeterminedError` from `pymatgen.symmetry.analyzer` — a symbol absent in `pymatgen` 2024.8.9 (the last Python-3.9-compatible release). On such environments the SDK path raises at import time; `mp_api_smoke.py` detects this via `_mp_api_usable()` and transparently uses the stdlib-`urllib` REST fallback. The `--selftest` path is unaffected (offline fixture only).

## Cross-link

- `_python_bridge/module/pymatgen_structure_io.py` — pymatgen `mp-XXX` ID regex validator (Phase E)
- `_absorption_bridge/materials_project/mp_api_smoke.py` — this phase's adapter
- `silicon/silicon.md` — Si-related MP records cited via `mp-149`
