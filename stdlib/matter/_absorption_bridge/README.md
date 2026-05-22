# `_absorption_bridge/` — hexa-matter external-system absorption layer

> **Created**: 2026-05-13 (Phase G) · **Updated**: 2026-05-13 (Phase G+1: COD; Phase G+2: OQMD + AFLOW + NOMAD; Phase J.3: NIMS-MatNavi + Catalysis-Hub) · **Status**: 16 adapters (11 external systems + 5 universal force-field models)
> **Pattern reference**: `_python_bridge/module/` (Phase E discipline)
> **Selftest wiring**: `selftest/absorption_bridge_smoke.sh` → `selftest/run_all.sh`
> **User directive**: "알파폴드 처럼 흡수할 시스템도 흡수" (absorb systems-that-absorb, AlphaFold-class)

---

## Purpose

`_absorption_bridge/` is hexa-matter's analog to AlphaFold ingestion: a thin,
honest adapter layer that lets the substrate **absorb** external materials-
discovery systems' outputs without lattice-fitting them. Each adapter is a
standalone Python script with a `--selftest` mode that replays a tiny bundled
fixture **offline**; nothing makes a live API call inside the selftest. When
the optional external dep is missing, the adapter SKIPs cleanly (exit 0,
counted PASS) per the `NO MOCKED FUNCTIONALITY` rule from `INIT.md`.

The eleven external systems plus five universal force fields cover the major
materials-AI absorption surface as of 2026-05:

| Bucket | Systems |
|---|---|
| Database / API (computed bulk) | Materials Project (Berkeley/LBNL) · GNoME (DeepMind) · Matlantis (Preferred Networks) · OMat24 (Meta AI) · OQMD (Wolverton/Northwestern) · AFLOW (Curtarolo/Duke) · NOMAD (Draxl & Scheffler, EU FAIR-data) |
| Database / API (computed surface reactions) | Catalysis-Hub (NTNU + Stanford SUNCAT, Winther 2019) — Phase J.3 |
| Database / API (experimental) | COD (Crystallography Open Database, Gražulis et al. 2009/2012) |
| Database / API (experimental + computed dual-mode) | NIMS MatNavi / MITS (Japan, ~50k records: alloy + creep + polymer + JIS industrial) — Phase J.3 |
| Universal force fields | SchNet · MACE · ALIGNN · CHGNet · M3GNet |

This bridge is the materials-substrate analog to AlphaFold absorption in
`hexa-bio` — we do NOT redo what these systems do; we expose adapter shapes
that let hexa-matter ingest their published metrics honestly.

---

## Layout

```
_absorption_bridge/
  README.md                                # this file
  pyproject.toml                           # optional deps (mp-api / matminer / mace-torch / schnetpack / ase)
  materials_project/
    mp_api_smoke.py                        # Materials Project API adapter (smoke, offline)
    SOURCES.md                             # API endpoint + auth + rate-limit + license
    cache/
      sample_response.json                 # SAMPLE FIXTURE: Si record (mp-149)
  gnome/
    gnome_dataset_smoke.py                 # DeepMind GNoME dataset adapter (2.2M predicted stable crystals)
    SOURCES.md                             # Zenodo DOI + license + honest "predicted not synthesized" note
    cache/
      sample_record.json                   # SAMPLE FIXTURE: one GNoME record schema
  matlantis/
    matlantis_call_smoke.py                # Preferred Networks Matlantis universal NNP adapter (smoke)
    SOURCES.md                             # commercial API note (UNVERIFIED at hexa-matter scale)
    cache/
      sample_response.json                 # SAMPLE FIXTURE: structure → energy record
  omat24/
    omat24_dataset_smoke.py                # Meta AI OMat24 dataset adapter (110M structures + MACE-OMat NNP)
    SOURCES.md                             # HuggingFace dataset + checkpoint + license
    cache/
      sample_record.json                   # SAMPLE FIXTURE: OMat24 record schema
  cod/                                     # Phase G+1 (2026-05-13)
    cod_search_smoke.py                    # Crystallography Open Database adapter (EXPERIMENTAL measurements, CC0 raw data)
    SOURCES.md                             # COD REST endpoint + Gražulis 2009/2012 citation + CC0 license
    cache/
      sample_record.json                   # SAMPLE FIXTURE: COD entry 9008565 (Si) schema
  cod_adapter.md                           # short doc for the COD adapter (Phase G+1)
  oqmd/                                    # Phase G+2 (2026-05-13)
    oqmd_search_smoke.py                   # Open Quantum Materials Database adapter (Wolverton, DFT-PBE, 1M+ entries)
    SOURCES.md                             # OQMD REST endpoint + Saal 2013 / Kirklin 2015 citation + CC-BY 4.0
    cache/
      sample_record.json                   # SAMPLE FIXTURE: OQMD entry 645928 (Si) schema
  oqmd_adapter.md                          # short doc for the OQMD adapter (Phase G+2)
  aflow/                                   # Phase G+2 (2026-05-13)
    aflow_search_smoke.py                  # AFLOW (Automatic-FLOW) adapter (Curtarolo/Duke, DFT, 3M+ compounds)
    SOURCES.md                             # AFLUX REST endpoint + Curtarolo 2012 / Toher 2018 citation + CC-BY 4.0
    cache/
      sample_record.json                   # SAMPLE FIXTURE: AFLOW aflow:<16-hex> entry schema
  aflow_adapter.md                         # short doc for the AFLOW adapter (Phase G+2)
  nomad/                                   # Phase G+2 (2026-05-13)
    nomad_search_smoke.py                  # NOMAD (NOvel MAterials Discovery) adapter (Draxl & Scheffler, FAIR-data, multi-code DFT, 19M+ entries)
    SOURCES.md                             # NOMAD V1 REST endpoint + Draxl & Scheffler 2018 citation + CC-BY 4.0
    cache/
      sample_record.json                   # SAMPLE FIXTURE: NOMAD V1 entry schema (Si via VASP-PBE)
  nomad_adapter.md                         # short doc for the NOMAD adapter (Phase G+2)
  nims_mats/                               # Phase J.3 (2026-05-13)
    nims_mats_search_smoke.py              # NIMS Materials Database (MatNavi/MITS) adapter (Japan; ~50k records; BOTH experimental AND computed)
    SOURCES.md                             # MatNavi web-search shape + Xu 2011 / Demura 2019 citation + CC-BY 4.0 (open-data subset)
    cache/
      sample_record.json                   # SAMPLE FIXTURE: SUS304 / SS304 austenitic stainless steel mechanical record (ASTM A240 / JIS G4304)
  nims_mats_adapter.md                     # short doc for the NIMS-MatNavi adapter (Phase J.3)
  catalysis_hub/                           # Phase J.3 (2026-05-13)
    catalysis_hub_search_smoke.py          # Catalysis-Hub (NTNU + Stanford SUNCAT) adapter (>100k surface reactions; DFT BEEF-vdW + GPAW/VASP)
    SOURCES.md                             # Catalysis-Hub GraphQL endpoint + Winther 2019 / Schlexer Lamoureux 2019 citation + CC-BY 4.0
    cache/
      sample_record.json                   # SAMPLE FIXTURE: CO2 → CO adsorption-energy record on Cu(111) (BEEF-vdW + GPAW)
  catalysis_hub_adapter.md                 # short doc for the Catalysis-Hub adapter (Phase J.3)
  universal_ff/
    schnet_call.py                         # SchNet adapter (Schütt et al. 2017)
    mace_call.py                           # MACE adapter (Batatia et al. 2022)
    alignn_call.py                         # ALIGNN adapter (Choudhary & DeCost 2021)
    chgnet_call.py                         # CHGNet adapter (Deng et al. 2023)
    m3gnet_call.py                         # M3GNet adapter (Chen & Ong 2022)
    SOURCES.md                             # aggregate citation/license table for the 5 FFs
    cache/
      sample_structure.json                # SAMPLE FIXTURE: input crystal structure
  selftest/
    materials_project_smoke.py             # offline fixture replay
    gnome_smoke.py                         # offline fixture replay
    matlantis_smoke.py                     # offline fixture replay
    omat24_smoke.py                        # offline fixture replay
    cod_smoke.py                           # offline fixture replay (Phase G+1)
    oqmd_smoke.py                          # offline fixture replay (Phase G+2)
    aflow_smoke.py                         # offline fixture replay (Phase G+2)
    nomad_smoke.py                         # offline fixture replay (Phase G+2)
    nims_mats_smoke.py                     # offline fixture replay (Phase J.3)
    catalysis_hub_smoke.py                 # offline fixture replay (Phase J.3)
    universal_ff_smoke.py                  # offline fixture replay (all 5 FF adapters)
    sources_audit.py                       # all SOURCES.md present + non-empty + license stated
```

---

## `--selftest` convention

Every adapter accepts `--selftest` and emits a fixed sentinel:

```
__HEXA_MATTER_<MODULE_UPPER>__ PASS
```

or, on missing optional dep:

```
__HEXA_MATTER_<MODULE_UPPER>__ PASS (SKIP mode)
```

The aggregator (`selftest/absorption_bridge_smoke.sh`) emits:

```
__HEXA_MATTER_ABSORPTION_BRIDGE__ PASS  (N/N modules, M skipped)
```

Selftests are offline / deterministic / tiny. Live network calls during
`--selftest` are FORBIDDEN — they would break determinism and risk hitting
external rate limits during CI.

---

## Honesty (per `INIT.md` hard rules)

This bridge must NOT:

   Materials Project DFT outputs, GNoME predictions, Matlantis NNP outputs,
   OMat24 records, and universal-FF energies all carry their OWN published
   invariants. The bridge passes them through untouched.

2. **Claim measurements the repo does not own** (`SPEC_FIRST`). Adapters
   surface external system records as-is; hexa-matter spec docs may
   reference them but do not re-derive them.

3. **Disguise mock data as real**. The bundled `cache/sample_*.json`
   fixtures are explicitly tagged `// SAMPLE FIXTURE — not real data,
   for selftest replay only` in their header field.

4. **Make live API calls during selftest**. Every selftest reads from
   the bundled cache fixture. Real adapter use against the live API is
   a runtime concern, not a CI concern.

5. **Misrepresent UNPROVEN status**. GNoME records are *predictions, not
   synthesized*. OMat24 structures are computational. The adapters
   preserve those markers verbatim in their docstrings.

6. **Pretend Matlantis is free**. It is a commercial Preferred Networks
   product. The adapter SKIPs by default and `matlantis/SOURCES.md`
   states "COMMERCIAL — UNVERIFIED at hexa-matter scale economics".

---

## License honesty matrix

| System | License | Cost | Honest note |
|---|---|---|---|
| Materials Project | CC-BY 4.0 (data); API requires free key | $0 with key | Berkeley/LBNL, Persson et al. 2013 |
| GNoME (DeepMind) | CC-BY 4.0 (Zenodo DOI 10.5281/zenodo.10371563) | $0 download | Merchant et al. 2023 Nature; **predicted, NOT synthesized** |
| Matlantis (Preferred Networks) | Commercial closed | $$$ (UNVERIFIED at scale) | Takamoto et al. 2022 Nat. Comm. (PFP universal NNP) |
| OMat24 (Meta AI) | CC-BY 4.0 (HuggingFace dataset + checkpoint) | $0 download | Barroso-Luque et al. 2024 (110M structures + MACE-OMat) |
| COD (Crystallography Open Database) | CC0 / public-domain raw data; no API key | $0 | Gražulis et al. 2009 J. Appl. Crystallogr. + 2012 Nucleic Acids Res.; **EXPERIMENTAL measurements, not predictions** |
| OQMD (Open Quantum Materials Database) | CC-BY 4.0 (data); no API key | $0 | Saal et al. 2013 JOM + Kirklin et al. 2015 npj Comput. Mater.; Wolverton/Northwestern; **DFT-PBE predictions** (~1M entries) |
| AFLOW (Automatic-FLOW) | CC-BY 4.0 (data); no API key | $0 | Curtarolo et al. 2012 + Toher et al. 2018 + Rose et al. 2017 AFLUX; Duke; **DFT predictions** (3M+ compounds, many prototype-substituted) |
| NOMAD (NOvel MAterials Discovery) | CC-BY 4.0 (data); no API key for read | $0 | Draxl & Scheffler 2018 MRS Bull. + 2019 J. Phys. Mater.; FAIR-data repository; **multi-code DFT** (VASP/QE/FHI-aims/ABINIT/CP2K/GPAW/…, 19M+ entries) |
| NIMS MatNavi / MITS (Phase J.3) | CC-BY 4.0 (open-data subset); account-gated subsets retain separate terms | $0 (open-data) | Xu et al. 2011 Procedia Eng. + Demura et al. 2019 Sci. Technol. Adv. Mater.; National Institute for Materials Science, Tsukuba, Japan; **BOTH experimental AND computed** (~50k records; metals/alloys/polymers/ceramics + multi-decade Creep/Fatigue Data Sheet series) |
| Catalysis-Hub (Phase J.3) | CC-BY 4.0 (data); no API key for read | $0 | Winther et al. 2019 Sci. Data + Schlexer Lamoureux et al. 2019 ChemCatChem; NTNU + Stanford SUNCAT; **DFT surface-reaction PREDICTIONS** (>100k reactions, BEEF-vdW + GPAW/VASP) |
| SchNet | MIT (schnetpack) | $0 | Schütt et al. 2017 J. Chem. Phys. |
| MACE | MIT (mace-torch) | $0 | Batatia et al. 2022 NeurIPS |
| ALIGNN | MIT (NIST jarvis-tools / alignn) | $0 | Choudhary & DeCost 2021 npj Comput. Mater. |
| CHGNet | BSD-3-Clause | $0 | Deng et al. 2023 Nat. Mach. Intell. |
| M3GNet | BSD-3-Clause (matgl) | $0 | Chen & Ong 2022 Nat. Comput. Sci. |

---

## When modules SKIP vs FAIL

| Situation | Outcome |
|---|---|
| Optional dep missing (mp-api / mace-torch / schnetpack / matgl / alignn / chgnet) | **SKIP** (exit 0, counted PASS) |
| Optional dep present + fixture replay fails | **FAIL** (exit 1) |
| Fixture replay succeeds | **PASS** (exit 0) |
| Live API attempted inside `--selftest` | **FORBIDDEN** (would violate offline determinism) |

---

## Install (optional deps)

Stdlib-only fallback works out of the box on Python 3.9+; adapters SKIP
their compute path when the optional dep is missing.

```bash
# all optional deps
pip install -e "_absorption_bridge[all]"

# per-system
pip install -e "_absorption_bridge[materials_project]"   # mp-api
pip install -e "_absorption_bridge[universal_ff]"        # schnetpack, mace-torch, matgl, alignn, chgnet
pip install -e "_absorption_bridge[meta_omat24]"         # mace-torch + huggingface_hub
```

---

## Wiring

`selftest/absorption_bridge_smoke.sh` (in the top-level `selftest/` dir,
Phase B's selftest infrastructure) invokes every
`_absorption_bridge/selftest/*.py --selftest` and aggregates PASS/FAIL/SKIP.
The aggregator becomes selftest gate **23** in `selftest/run_all.sh`
(gate 22 is reserved for Phase F's `_research_bridge/`).

Phase G+1 (2026-05-13) adds a dedicated COD-only gate at
`selftest/cod_adapter_smoke.sh` (gate **24**) that runs the COD adapter
directly so a COD regression is identifiable without rerunning the full
absorption aggregator.

Phase G+2 (2026-05-13) adds three more dedicated adapter gates:
`selftest/oqmd_adapter_smoke.sh` (gate **25**, OQMD),
`selftest/aflow_adapter_smoke.sh` (gate **26**, AFLOW), and
`selftest/nomad_adapter_smoke.sh` (gate **27**, NOMAD). Scoreboard at
Phase G+2 close: **27/27 PASS**.

Phase J.3 (2026-05-13) adds two more dedicated adapter gates for the
15th and 16th adapters: `selftest/nims_mats_adapter_smoke.sh` (NIMS
MatNavi, Japan) and `selftest/catalysis_hub_adapter_smoke.sh`
(Catalysis-Hub, NTNU + Stanford SUNCAT). Gate numbers track the merge
order of the J.1/J.2/J.3 closure-deepening branches into main —
defensively claimed as the next available slots after the existing
30-gate scoreboard.

---

## Cross-link

- `INIT.md` §"Phase G" — phase scope + commit log
- `V1_2_0_HANDOFF.md` §6 — Phase G absorption-target shopping list
- `AXIS_CLOSURE_PLAN.md` — per-group closure roadmap
- `LATTICE_POLICY.md` §1.2 + §1.3 — real-limits-first + lattice auxiliary
- `LIMIT_BREAKTHROUGH.md` — HARD / SOFT wall classification

---

*Document authored 2026-05-13 by 박민우 <nerve011235@gmail.com> as Phase G elevation.*
