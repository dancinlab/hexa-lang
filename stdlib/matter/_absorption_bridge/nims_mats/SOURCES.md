# `nims_mats/SOURCES.md` — NIMS Materials Database (MatNavi / MITS, Japan)

> Phase J.3 adapter target: `nims_mats_search_smoke.py` (offline schema replay; real fetch via NIMS MatNavi / MITS web search — no public REST API; per-record HTML/PDF download with NIMS account)

---

## System

- **Name**: NIMS Materials Database (MatNavi · MITS · NIMS Structural Materials Datasheet portal)
- **Maintainer**: National Institute for Materials Science (NIMS), Tsukuba, Japan
- **Web (English landing)**: https://mits.nims.go.jp/
- **MatNavi (multi-DB hub)**: https://mat-navi.nims.go.jp/
- **Open-data portal**: https://www.nims.go.jp/eng/publicity/digital/open_data/index.html
- **Scale (as of 2024)**: ≈ 50,000 records covering metals + alloys + ceramics + polymers + composites + creep-rupture series + corrosion + thermophysical / mechanical / electrochemical properties

## Authoritative citations

- NIMS Materials Database (MatNavi) 2024 release. National Institute for Materials Science, Tsukuba, Japan. https://mits.nims.go.jp/
- NIMS Structural Materials Datasheet series (Creep Data Sheet 1–60+; Fatigue Data Sheet 1–100+) — multi-volume, NIMS Tsukuba. Long-term creep-rupture testing program (some series > 30 years of continuous data accumulation).
- Xu, Y. et al. "NIMS materials database, MatNavi — a comprehensive Japanese material database for industrial use." **Procedia Engineering** 10, 1869–1873 (2011). DOI: 10.1016/j.proeng.2011.04.311
- Demura, M., Tanaka, H. et al. "Open Innovation Platform for Materials Science: MI²I, MatNavi and the NIMS Data Platform." **Sci. Technol. Adv. Mater.** 20, 1–10 (2019). DOI: 10.1080/14686996.2019.1576123

## REST endpoint shape (current reality)

- **No public REST/JSON API**. MatNavi is web-search + per-record HTML/PDF; many DBs require a NIMS-issued account for download (free for academic users; commercial license separate).
- Search entry point: `https://mits.nims.go.jp/index_en.html` → "Search" → DB selector (Metals · Polymers · Ceramics · Composites · Creep · Fatigue · Thermal · Corrosion · …)
- Per-record landing pages carry HTML metadata + downloadable PDF data sheet.
- Bulk export is available for some Open-Data subsets (CSV/Excel) under the NIMS open-data portal.
- Adapter pattern: **offline fixture replay**. The `--live` runtime path (when implemented downstream) would politely scrape the per-record HTML with a User-Agent + ≥ 3 s cadence. Not exercised in `--selftest`.

## License

- **NIMS open-data subsets: CC-BY 4.0** per the NIMS open-data portal
  (https://www.nims.go.jp/eng/publicity/digital/open_data/index.html).
  Citation to NIMS MatNavi 2024 release is required.
- Account-gated subsets (full Creep / Fatigue Data Sheet series) retain their
  separate access terms; the adapter does NOT redistribute them. The fixture
  bundled here is a SAMPLE schema only (SS304 nominal values from the public
  open-data layer + ASTM/JIS).
- Adapter code: MIT (hexa-matter convention).

## Schema (per record, abbreviated)

| Field | Type | Note |
|---|---|---|
| `nims_id` | str | NIMS internal identifier (db-prefix-class-condition tag) |
| `material_class` | str | e.g. `metal_alloy_austenitic_stainless_steel` |
| `designation` | str | SUS304 / SS304 / AISI 304 / JIS G4304-SUS304 |
| `standard_refs` | list[str] | ASTM / JIS / EN / DIN cross-references |
| `composition_wt_pct` | dict | element → wt% |
| `test_condition` | dict | temperature_C, atmosphere, geometry, heat_treatment |
| `mechanical_properties` | dict | yield_MPa, UTS_MPa, elongation_pct, E_GPa, ν, HV |
| `record_type` | str | `experimental_mechanical` / `experimental_creep` / `experimental_corrosion` / `experimental_polymer` / `computed_dft` / `computed_calphad` etc. |
| `record_type_note` | str | distinguisher between MEASUREMENT and PREDICTION |
| `publication` | dict | NIMS data sheet ref + MatNavi URL |
| `license` | str | CC-BY 4.0 for open-data subset |

## Honest notes

- NIMS MatNavi carries **BOTH experimental and computed** records — a unique
  property among the 16 absorption-bridge sources. Distinct from:
  - COD (experimental crystal structures only, CC0)
  - MP / OMat24 / OQMD / AFLOW / NOMAD / GNoME (DFT predictions only)
  - Catalysis-Hub (DFT surface-reaction predictions only)
- The adapter validator REQUIRES the `record_type` tag and the
  `record_type_note` string to clearly indicate MEASUREMENT vs PREDICTION,
  so the two flavours cannot be conflated silently — preserves bridge rule
  #4 (predictions ≠ measurements).
- **Japan-specific industrial coverage**: SUS / JIS-graded metals + creep-
  rupture series for power-plant / aerospace alloys (multi-decade NIMS test
  programs) + Japanese polymer industrial data + alloy phase-diagram archive.
  Not redundant with US/EU databases.
  (mill-certificate scatter ± 5–10 % on mechanical properties; longer-term
  creep-rupture series with documented statistics) are the authoritative bars.
- **Account gating**: full Creep Data Sheet / Fatigue Data Sheet PDFs require
  a NIMS account (free for academic). The adapter is NOT a republisher; the
  fixture here is open-data-subset shape only.
- The adapter's selftest is **offline fixture replay only**. Live web search
  is gated behind explicit runtime use (downstream) and observes a polite
  cadence + identifies itself with a User-Agent.

## Cross-link

- `_absorption_bridge/cod/SOURCES.md` — experimental XRD crystal structures (CC0; predictions vs measurements distinguisher inverse)
- `_absorption_bridge/materials_project/SOURCES.md` — DFT-computed sister database (USA, LBNL)
- `_absorption_bridge/aflow/SOURCES.md` — DFT-computed sister database (USA, Duke)
- `_absorption_bridge/oqmd/SOURCES.md` — DFT-computed sister database (USA, Northwestern)
- `_absorption_bridge/nomad/SOURCES.md` — FAIR data repository (EU; multi-code DFT archive)
- `_absorption_bridge/catalysis_hub/SOURCES.md` — surface reactions DFT (NTNU/SUNCAT; Phase J.3 sister)
- `superalloy/superalloy.md` — IN718 creep-rupture cross-cited against NIMS Creep Data Sheet series
- `metallurgy/metallurgy.md` — SS304 mechanical baseline cross-cited against NIMS MatNavi
