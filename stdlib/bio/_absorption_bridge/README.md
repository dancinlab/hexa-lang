# `_absorption_bridge/` — hexa-bio external-system absorption layer

> **Created**: 2026-05-13 (cycle-30++++++++ backport) · **Status**: 9 adapters across 9 protein-structure / sequence external systems
> **Pattern reference**: hexa-matter Phase G `_absorption_bridge/` (commit e712068, 2026-05-13)
> **Selftest wiring**: `_absorption_bridge/selftest/run_all.sh` → `selftest/run_all.sh` (gate 35)
> **User directive**: hexa-bio audit revealed AlphaFold/RoseTTAFold/ESMFold cited in 50 files as "Primary oracle" with NO absorption bridge — backport hexa-matter's pattern to make those citations concrete

---

## Purpose

`_absorption_bridge/` is hexa-bio's analog to hexa-matter's materials-AI
absorption: a thin, honest adapter layer that lets the substrate **absorb**
external protein-structure ML systems' outputs without n=6-lattice-fitting
them. Each adapter is a standalone Python script with a `--selftest` mode
that replays a tiny bundled fixture **offline**; nothing makes a live API
call inside the selftest. When the optional external dep is missing, the
adapter SKIPs cleanly (exit 0, counted PASS) per the `NO MOCKED
FUNCTIONALITY` rule from `INIT.md` / `AGENTS.md`.

The nine external systems cover the major protein-structure-AI + sequence
absorption surface as of 2026-05:

| Bucket | Systems |
|---|---|
| Structure prediction (deep-learning) | AlphaFold-3 (DeepMind) · RoseTTAFold + RFAA (Baker Lab) · ESMFold (Meta) · OpenFold (Columbia) · ColabFold (Steinegger lab) |
| Search (structural / sequence) | Foldseek (Steinegger lab) · MMseqs2 (Steinegger & Söding) |
| Reference databases | UniProt (EMBL-EBI) · PDB (RCSB) |

This bridge is the protein-substrate counterpart to hexa-matter's
`_absorption_bridge/` (Materials Project / GNoME / Matlantis / OMat24 /
SchNet-MACE-ALIGNN-CHGNet-M3GNet). We do NOT redo what these systems do; we
expose adapter shapes that let hexa-bio ingest their published outputs
honestly.

HEXA-WEAVE's "Primary oracle: AlphaFold-class fold inference" claim (and
the same row in HEXA-VIROCAPSID / HEXA-NANOBOT / HEXA-RIBOZYME) now links
to concrete adapters under this tree — making the citation concrete
instead of dangling.

---

## Layout

```
_absorption_bridge/
  README.md                                # this file
  pyproject.toml                           # optional deps (requests / biopython / mdanalysis / torch)
  alphafold3/
    af3_smoke.py                           # DeepMind AlphaFold-3 adapter (smoke, offline replay)
    SOURCES.md                             # citation + LICENSE (NON-COMMERCIAL RESEARCH ONLY)
    cache/
      sample_prediction.json               # SAMPLE FIXTURE: AF3 prediction schema
  rosettafold/
    rosettafold_smoke.py                   # Baker Lab RoseTTAFold + RFAA adapter
    SOURCES.md
    cache/
      sample_prediction.json               # SAMPLE FIXTURE
  esmfold/
    esmfold_smoke.py                       # Meta ESMFold adapter (uses ESM-2 LM, no MSA)
    SOURCES.md
    cache/
      sample_prediction.json               # SAMPLE FIXTURE
  openfold/
    openfold_smoke.py                      # OpenFold (Columbia consortium AF2 reimpl, trainable)
    SOURCES.md
    cache/
      sample_prediction.json               # SAMPLE FIXTURE
  colabfold/
    colabfold_smoke.py                     # ColabFold (AF2 + MMseqs2 MSA)
    SOURCES.md
    cache/
      sample_prediction.json               # SAMPLE FIXTURE
  foldseek/
    foldseek_smoke.py                      # Structural search adapter (3Di alphabet)
    SOURCES.md
    cache/
      sample_alignment.json                # SAMPLE FIXTURE: foldseek M8-style alignment
  mmseqs/
    mmseqs_smoke.py                        # MMseqs2 sequence search/clustering adapter
    SOURCES.md
    cache/
      sample_alignment.json                # SAMPLE FIXTURE: MMseqs2 M8-style alignment
  uniprot/
    uniprot_api_smoke.py                   # UniProt REST API adapter
    SOURCES.md
    cache/
      sample_entry.json                    # SAMPLE FIXTURE: P0DTC2 schema (SARS-CoV-2 spike)
  pdb/
    pdb_api_smoke.py                       # RCSB PDB REST adapter
    SOURCES.md
    cache/
      sample_entry.json                    # SAMPLE FIXTURE: 7C2L schema
  selftest/
    run_all.sh                             # aggregator — emits __HEXA_BIO_ABSORPTION_BRIDGE__ PASS
    alphafold3_smoke.py
    rosettafold_smoke.py
    esmfold_smoke.py
    openfold_smoke.py
    colabfold_smoke.py
    foldseek_smoke.py
    mmseqs_smoke.py
    uniprot_smoke.py
    pdb_smoke.py
    sources_audit.py
```

---

## `--selftest` convention

Every adapter accepts `--selftest` and emits a fixed sentinel:

```
__HEXA_BIO_<MODULE_UPPER>__ PASS
```

or, on missing optional dep:

```
__HEXA_BIO_<MODULE_UPPER>__ PASS (SKIP mode)
```

The aggregator (`_absorption_bridge/selftest/run_all.sh`) emits:

```
__HEXA_BIO_ABSORPTION_BRIDGE__ PASS  (N/N modules, M skipped)
```

Selftests are offline / deterministic / tiny. Live network calls during
`--selftest` are FORBIDDEN — they would break determinism and risk hitting
external rate limits during CI.

---

## Honesty (per `AGENTS.md` / `LATTICE_POLICY.md` hard rules)

This bridge must NOT:

1. **Apply n=6 lattice formulas to external system data** (`C3`).
   AlphaFold-3 / RoseTTAFold / ESMFold / OpenFold / ColabFold predictions,
   Foldseek / MMseqs2 alignments, UniProt / PDB records all carry their
   OWN published metrics (pLDDT, pAE, TM-score, RMSD, E-value, ...). The
   bridge passes them through untouched. NO σ(6)=12 / τ(6)=4 / φ(6)=2 /
   J₂=24 audit is applied to fold predictions or sequence alignments.

2. **Confuse predictions with measurements** (`SPEC_FIRST`). AlphaFold-3
   *predicts*, it does not *measure*. Every adapter preserves this
   distinction in its docstring and in `SOURCES.md`.

3. **Disguise mock data as real**. The bundled `cache/sample_*.json`
   fixtures are explicitly tagged `// SAMPLE FIXTURE — not real data,
   for selftest replay only` in their header field.

4. **Make live API calls during selftest**. Every selftest reads from
   the bundled cache fixture. Real adapter use against the live API or
   weights is a runtime concern, not a CI concern.

5. **Misrepresent UNPROVEN status**. AlphaFold-3 predictions on novel
   folds remain `UNVERIFIED` until experimental verification (X-ray,
   cryo-EM, NMR). The adapters preserve those markers verbatim.

6. **Pretend AlphaFold-3 is commercially free**. AF3 weights are released
   for **non-commercial research only** (2024-11). Commercial use
   requires a separate Isomorphic Labs license. `alphafold3/SOURCES.md`
   states this loudly.

7. **Offer medical or clinical advice**. Fold predictions inform
   research only — they are NOT therapeutic, diagnostic, regulatory, or
   clinical claims.

---

## License honesty matrix

| System | License | Cost | Honest note |
|---|---|---|---|
| AlphaFold-3 (DeepMind) | **Non-commercial research only** (2024-11 weights release; commercial via Isomorphic Labs) | $0 academic, $$$ commercial | Abramson et al. 2024 Nature 630:493; **PREDICTIONS, not measurements**; novel-fold predictions are UNVERIFIED |
| RoseTTAFold (Baker Lab) | BSD-3-Clause (original); RoseTTAFold All-Atom Apache 2.0 | $0 | Baek et al. 2021 Science 373:871; Krishna et al. 2024 Science (RFAA); commercial OK |
| ESMFold / ESM-2 (Meta) | MIT (weights publicly released; some HuggingFace mirrors) | $0 | Lin et al. 2023 Science 379:1123; single-sequence (no MSA) |
| OpenFold (Columbia consortium) | Apache 2.0 | $0 | Ahdritz et al. 2024 Nat Methods 21:1514; trainable open AF2 reimplementation |
| ColabFold (Steinegger lab) | MIT | $0 | Mirdita et al. 2022 Nat Methods 19:679; AF2 + fast MMseqs2 MSA |
| Foldseek (Steinegger lab) | GPLv3 | $0 | van Kempen et al. 2024 Nat Biotech 42:243; 3Di-alphabet structural search |
| MMseqs2 (Steinegger & Söding) | GPLv3 | $0 | Steinegger & Söding 2017 Nat Biotech 35:1026 |
| UniProt (EMBL-EBI / SIB / PIR) | CC-BY 4.0 (data); API free | $0 | UniProt Consortium 2023 Nucleic Acids Res 51:D523 |
| PDB (RCSB / wwPDB) | CC0 / Public Domain (data); API free | $0 | Burley et al. 2023 Nucleic Acids Res 51:D488 |

> **Critical**: AlphaFold-3's non-commercial restriction is novel and
> distinct from AlphaFold-2's CC-BY-4.0 weights. Any commercial
> downstream that absorbs AF3 outputs must obtain the Isomorphic Labs
> license separately. This bridge does not waive that requirement; it
> only validates that schema replay is honest in selftest.

---

## When modules SKIP vs FAIL

| Situation | Outcome |
|---|---|
| Optional dep missing (`requests` / `biopython` / `mdanalysis` / `torch`) | **SKIP** (exit 0, counted PASS) |
| Optional dep present + fixture replay succeeds | **PASS** (exit 0) |
| Fixture replay fails (schema check) | **FAIL** (exit 1) |
| Live API attempted inside `--selftest` | **FORBIDDEN** (would violate offline determinism) |

---

## Install (optional deps)

Stdlib-only fallback works out of the box on Python 3.9+; adapters SKIP
their live path when the optional dep is missing.

```bash
# all optional deps
pip install -e "_absorption_bridge[all]"

# per-bucket
pip install -e "_absorption_bridge[rest_api]"      # requests (UniProt + PDB live paths)
pip install -e "_absorption_bridge[bio_io]"        # biopython + mdanalysis (PDB / mmCIF I/O)
pip install -e "_absorption_bridge[fold_runtime]"  # torch + transformers (ESMFold runtime, OpenFold)
```

---

## Wiring

`_absorption_bridge/selftest/run_all.sh` invokes every
`_absorption_bridge/selftest/*.py --selftest` and aggregates PASS/FAIL/SKIP.
The aggregator is invoked from the top-level `selftest/run_all.sh` as a new
gate `absorption_bridge_smoke` (gate 35 — was 34/34 PASS prior to this
backport, becomes 35/35 PASS after).

---

## Cross-link

- `HEXA-WEAVE.md` §1 — "Primary oracle: AlphaFold-class fold inference" row
- `HEXA-VIROCAPSID.md` §1 — same row, four-sister axis
- `HEXA-NANOBOT.md` / `HEXA-RIBOZYME.md` — same row
- `LATTICE_POLICY.md` §1.2 + §1.3 — real-limits-first + lattice auxiliary
- `LIMIT_BREAKTHROUGH.md` — HARD / SOFT wall classification
- `AXIS_CLOSURE_PLAN.md` — per-axis closure roadmap (cycle-30++++++++)
- hexa-matter `_absorption_bridge/README.md` — pattern reference (commit e712068)

---

*Document authored 2026-05-13 by 박민우 <nerve011235@gmail.com> as cycle-30++++++++ backport of hexa-matter Phase G pattern.*
