# `_python_bridge/` — hexa-matter scientific compute bridge

> **Created**: 2026-05-13 (Phase E) · **Status**: 12 modules, RDKit/ASE/pymatgen + stdlib
> **Pattern reference**: `hexa-bio/_python_bridge/module/`
> **Selftest wiring**: `selftest/pyproject_smoke.sh` → `selftest/run_all.sh`

---

## Purpose

This directory provides **runnable scientific compute** that backs the
hexa-matter spec corpus. Each module is a standalone Python script with a
`--selftest` mode; modules either do **real compute** (when optional deps are
installed) or **SKIP cleanly** (stdlib-only fallback) when an optional dep is
missing. Nothing is mocked or disguised — a module that cannot do its real
job announces the SKIP reason and exits 0.

This mirrors `hexa-bio/_python_bridge/module/` — that bridge provides
ribozyme MFE (Nussinov), off-target Hamming screen, nanobot actuation
simulation, etc. The hexa-matter bridge is the materials analog.

---

## Layout

```
_python_bridge/
  README.md                                # this file
  pyproject.toml                           # optional deps (RDKit / ASE / pymatgen)
  module/
    rdkit_smiles_audit.py                  # SMILES validity + canonicalization (RDKit)
    rdkit_descriptor_calc.py               # MolWt / LogP / TPSA / HBA / HBD (RDKit)
    ase_atoms_construct.py                 # Si crystal / NdFeB unit cell (ASE)
    ase_relaxation_check.py                # tiny relax smoke (ASE + EMT/LJ)
    pymatgen_structure_io.py               # CIF parse/write + MP-ID resolve (pymatgen)
    pymatgen_phasediagram_smoke.py         # binary phase diagram construction (pymatgen)
    silicon_purity_compute.py              # 9N → ppba atomic-fraction (stdlib)
    polymer_mw_distribution.py             # PDI from Mn/Mw (stdlib)
    metallurgy_alloy_composition.py        # wt-% ↔ at-% conversion (stdlib)
    carbon_form_factor_classifier.py       # SMILES/structure → activated/graphite/CNT/diamond (stdlib + optional RDKit)
    cross_doc_consistency_compute.py       # README ↔ AXIS.md ↔ hexa.toml count check (stdlib)
    nist_anchor_resolver.py                # parse "NIST WebBook X" refs + URL pattern verify (stdlib, offline)
```

### Module status taxonomy

| Tag | Meaning |
|---|---|
| **FUNCTIONAL** | Module does its job end-to-end on the in-repo test fixture in `--selftest`. |
| **PARTIAL** | Module does the easy half (e.g. parsing) but the hard half (e.g. external API call) is intentionally not exercised in `--selftest` to keep determinism. |
| **SKELETON** | Module shape is in place + selftest passes, but the compute path is a stub that only validates inputs. Reserved for Phase F/G upgrade. |

---

## Install (optional deps)

Stdlib-only modules (`silicon_purity_compute.py`, `polymer_mw_distribution.py`,
`metallurgy_alloy_composition.py`, `cross_doc_consistency_compute.py`,
`nist_anchor_resolver.py`) work out of the box on a stock Python 3.9+ install.

For the chemistry / atomistic / materials stacks:

```bash
# all optional deps
pip install -e "_python_bridge[all]"

# or per-stack
pip install -e "_python_bridge[chem]"        # RDKit only
pip install -e "_python_bridge[atomic]"      # ASE only
pip install -e "_python_bridge[materials]"   # pymatgen only
```

If a module's optional dep is missing, it prints:

```
SKIP: rdkit not installed (install via `pip install rdkit-pypi`)
__HEXA_MATTER_RDKIT_SMILES_AUDIT__ PASS (SKIP mode)
```

and exits 0. The harness counts SKIP as PASS — this is the deliberate
"NO MOCKED FUNCTIONALITY" rule from `INIT.md` §"Hard constraints".

---

## `--selftest` convention

Every module accepts `--selftest` and emits a fixed sentinel:

```
__HEXA_MATTER_<MODULE_UPPER>__ PASS
```

or

```
__HEXA_MATTER_<MODULE_UPPER>__ FAIL  (<reason>)
```

Selftests are:
- **Offline** — no network calls, no API hits.
- **Deterministic** — same inputs → byte-identical output.
- **Tiny** — runs in well under a second on stock Python.
- **Self-contained** — fixtures are literals embedded in each module.

---

## When modules SKIP vs FAIL

| Situation | Outcome |
|---|---|
| Optional dep missing (RDKit / ASE / pymatgen) | **SKIP** (exit 0, counted PASS) |
| Optional dep present but compute fails on the in-repo fixture | **FAIL** (exit 1) |
| Stdlib-only fixture passes | **PASS** (exit 0) |
| Stdlib-only fixture fails (genuine regression) | **FAIL** (exit 1) |
| External API call attempted in --selftest | **FORBIDDEN** (would violate offline determinism) |

---

## Hard constraints (per `INIT.md`)

Modules in this bridge **must NOT**:

1. Compute n=6 lattice properties on vendor / NIST / external data
2. Claim measurements the repo does not own (`SPEC_FIRST` verdict).
3. Disguise mocked compute as real (`NO MOCKED FUNCTIONALITY` rule).
4. Make network calls during `--selftest` (offline / sandboxed).

Modules **may**:
- Compute spec internal consistency (e.g. atomic-fraction arithmetic).
- Validate inputs (SMILES syntax, CIF structure parseability).
- Cross-reference spec docs programmatically (README ↔ AXIS.md ↔ hexa.toml).
- Call optional scientific libraries (RDKit / ASE / pymatgen) for compute,
  on inputs that are NOT vendor data (e.g. canonicalize a SMILES literal).

---

## Wiring

`selftest/pyproject_smoke.sh` invokes every `module/*.py --selftest` and
aggregates the PASS / FAIL / SKIP counts. The aggregator emits:

```
__HEXA_MATTER_PYTHON_BRIDGE__ PASS (12/12 modules, M skipped)
```

`selftest/run_all.sh` runs `pyproject_smoke.sh` as a real gate (one of 22
after Phase E). It is no longer a stub.

---

## Cross-link

- `INIT.md` §"Phase E" — phase scope + commit log
- `V1_2_0_HANDOFF.md` §4 — Phase E original target list
- `AXIS_CLOSURE_PLAN.md` — per-group closure roadmap
- `LATTICE_POLICY.md` §1.2 + §1.3 — real-limits-first + lattice auxiliary
- `LIMIT_BREAKTHROUGH.md` — HARD / SOFT wall classification

---

*Document authored 2026-05-13 by 박민우 <nerve011235@gmail.com> as Phase E elevation.*
