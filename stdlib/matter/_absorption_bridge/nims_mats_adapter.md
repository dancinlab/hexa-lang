# `nims_mats_adapter.md` — NIMS Materials Database (MatNavi / MITS) absorption adapter

> **Phase J.3 (2026-05-13)** · 15th adapter in `_absorption_bridge/`
> Sister of `cod_adapter` / `oqmd_adapter` / `aflow_adapter` / `nomad_adapter` / `catalysis_hub_adapter`.

---

## What it does

`_absorption_bridge/nims_mats/nims_mats_search_smoke.py` is the adapter shape
that lets hexa-matter absorb records from the **NIMS Materials Database**
(National Institute for Materials Science, Tsukuba, Japan — MatNavi / MITS
portal family). NIMS MatNavi aggregates ~50,000 records across metals,
alloys, ceramics, polymers, composites, plus the multi-decade NIMS Creep /
Fatigue / Corrosion Data Sheet series.

NIMS MatNavi is unique among the 16 absorption-bridge sources: it carries
**BOTH experimental and computed** records. Distinct from:

- COD (experimental crystal structures only, CC0)
- MP / OMat24 / OQMD / AFLOW / NOMAD / GNoME (DFT predictions only)
- Catalysis-Hub (DFT surface-reaction predictions only)

The adapter validator REQUIRES the `record_type` tag to start with
`experimental_` or `computed_`, so a downstream consumer cannot silently
treat a DFT prediction as a measurement (or vice versa).

Two paths:

1. **Offline (`--selftest`)** — load `cache/sample_record.json`, validate
   schema (nims_id non-empty, composition sums ~100 %, `record_type` tag
   present and indicates measurement OR prediction unambiguously), emit
   sentinel. Deterministic; offline.
2. **Live (`--query "..."`)** — stdlib `urllib.request` fetch of the MatNavi
   landing page HTML at `https://mits.nims.go.jp/`. NOT exercised in the
   selftest (per `NO LIVE API CALLS in selftest` rule). MatNavi has **no
   public REST/JSON API**; the real workflow is web-search → per-record
   HTML/PDF (often NIMS-account-gated).

Selftest sentinel: `__HEXA_MATTER_NIMS_MATS_SEARCH_SMOKE__ PASS`.
Aggregator wrapper sentinel: `__HEXA_MATTER_NIMS_MATS_SMOKE__ PASS`.

## License

- **NIMS open-data subsets: CC-BY 4.0** per the NIMS open-data portal
  (https://www.nims.go.jp/eng/publicity/digital/open_data/index.html).
  Citation to NIMS MatNavi 2024 release is required.
- Account-gated subsets (full Creep / Fatigue Data Sheet series) retain
  their separate access terms; the adapter does NOT redistribute them. The
  fixture bundled here is a SAMPLE schema only.
- Adapter code: MIT (hexa-matter convention).

## Citation

- NIMS Materials Database (MatNavi) 2024 release. National Institute for
  Materials Science, Tsukuba, Japan. https://mits.nims.go.jp/
- Xu, Y. et al. "NIMS materials database, MatNavi — a comprehensive
  Japanese material database for industrial use." **Procedia Engineering**
  10, 1869–1873 (2011). DOI: 10.1016/j.proeng.2011.04.311
- Demura, M., Tanaka, H. et al. "Open Innovation Platform for Materials
  Science: MI²I, MatNavi and the NIMS Data Platform." **Sci. Technol. Adv.
  Mater.** 20, 1–10 (2019). DOI: 10.1080/14686996.2019.1576123
- NIMS Structural Materials Datasheet series (Creep Data Sheet 1–60+ ·
  Fatigue Data Sheet 1–100+).

Version stamped: MatNavi 2024 release (rolling; the multi-decade Creep /
Fatigue series accumulate continuously).

## Honesty (per bridge rules in AGENTS.md)

- **stdlib fallback**: the adapter is pure stdlib; no optional dep required
  for the offline selftest path. The live path uses `urllib.request` (also
  stdlib).
- **offline selftest only**: the bundled `cache/sample_record.json` fixture
  carries `__fixture_tag__: SAMPLE FIXTURE — not real data, for selftest
  replay only`. `--selftest` never touches the network.
- **License honesty**: this file + `nims_mats/SOURCES.md` cite paper +
  license + DOI + version.
- **predictions ≠ measurements** (DUAL-MODE distinguisher): NIMS MatNavi
  is the only source in the bridge that carries BOTH. The validator
  REQUIRES `record_type` to start with `experimental_` or `computed_`, AND
  requires `record_type_note` to mention `measure(d)/experimental` for the
  experimental case or `predict/DFT/CALPHAD/comput*` for the computed case.
  Mis-labelled records FAIL the schema.
  uncertainties (mill-certificate ± 5–10 % on mechanical properties;
  documented statistics on long-term creep-rupture series) are the
  authoritative bars. The adapter passes them through untouched.

## Falsifier-relevance

- **Vendor-vs-NIMS mechanical baseline**: when a hexa-matter spec doc
  (e.g. `metallurgy/metallurgy.md` for SS304 / SUS304) cites a yield-
  strength baseline `σ_y ≈ 215 MPa @ 25 °C`, the adapter lets that be
  cross-validated against the NIMS MatNavi MITS-METAL-SS304-MECH-25C
  record (representative ASTM A240 / JIS G4304 nominal values).
- **Creep-rupture long-tail anchor**: the NIMS Creep Data Sheet series
  carries some of the longest continuous creep-rupture test programs in
  the world (≥ 30 years on selected austenitic steels and Ni superalloys);
  this is a real industrial source not redundant with US/EU databases.
  `superalloy/superalloy.md` IN718 + Cr-Ni austenitic creep claims map
  cleanly here.
- **Japan-specific industrial coverage**: SUS / JIS-graded metals + JIS
  polymer industrial data + alloy phase-diagram archive — not redundant
  with MP / OQMD / AFLOW / NOMAD (USA / EU computational).

## When this module SKIPs vs FAILs

| Situation | Outcome |
|---|---|
| Fixture present + schema valid | **PASS** (exit 0) |
| Fixture missing | **FAIL** (exit 1) |
| Fixture schema invalid (missing field, composition off, mis-tagged record_type, etc.) | **FAIL** (exit 1) |
| Live web search unreachable during `--selftest` | N/A — selftest never calls live API |
| `--query` live call + network down | exit 2 with diagnostic; not a CI gate |

## Wiring

- Adapter: `_absorption_bridge/nims_mats/nims_mats_search_smoke.py`
- SOURCES: `_absorption_bridge/nims_mats/SOURCES.md`
- Fixture: `_absorption_bridge/nims_mats/cache/sample_record.json`
- Selftest wrapper: `_absorption_bridge/selftest/nims_mats_smoke.py`
- Aggregator: `selftest/absorption_bridge_smoke.sh` (Phase G aggregator)
- Top-level dedicated gate: `selftest/nims_mats_adapter_smoke.sh` (Phase J.3)

## Cross-link

- `_absorption_bridge/cod/` — experimental crystal structures (CC0; inverse distinguisher)
- `_absorption_bridge/materials_project/` — DFT computational sister (USA, LBNL)
- `_absorption_bridge/oqmd/` — DFT computational sister (USA, Northwestern)
- `_absorption_bridge/aflow/` — DFT computational sister (USA, Duke)
- `_absorption_bridge/nomad/` — FAIR multi-code DFT (EU)
- `_absorption_bridge/catalysis_hub/` — DFT surface-reaction sister (NTNU/SUNCAT; Phase J.3 sister)
- `metallurgy/metallurgy.md` — SS304 mechanical baseline cross-cited against NIMS MatNavi
- `superalloy/superalloy.md` — IN718 creep-rupture cross-cited against NIMS Creep Data Sheet series
