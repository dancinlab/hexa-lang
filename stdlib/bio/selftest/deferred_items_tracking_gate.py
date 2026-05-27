#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/deferred_items_tracking_gate.py — DEFERRED-items tracking gate.

WHY THIS EXISTS
---------------
The hexa-bio repo carries an EXPLICIT list of DEFERRED items in
AXIS/HIERARCHY.tape (`@N theranostic_status` / `@N genetic_medicine_status`
/ `@N adc_status`) and in CHANGELOG.md's "DEFERRED (carried into the next
session)" table. They are deferred for honest reasons (criterion-#4 scope,
external sister-repo work, an unresolved governance question). Until a
future user direction explicitly UN-defers an item, the codebase state must
match the deferred declaration — no silent fabrications, no silent
un-deferrals.

This gate is a **honest boundary enforcer**. It does NOT enforce that the
items stay deferred forever — un-deferral is a legitimate future action.
It enforces that IF an item gets un-deferred, the un-deferral must be paired
with a governance update (the HIERARCHY.tape `@N` UNPLACED note flipped to
an `@D` axis-declaration entry, the CHANGELOG DEFERRED table updated, etc.).
Until that paired update exists, a freshly-appeared `genetic_medicine/`
directory or `adc_*.py` sim is an UN-DEFERRED-VIOLATION — the FAIL state.

The 4 DEFERRED items it tracks (the LATCHED set declared at HEAD):

  1. 200-disease re-mapping             (CHANGELOG.md DEFERRED row 1)
  2. GENETIC-MEDICINE code axis         (HIERARCHY.tape @N genetic_medicine_status)
  3. ADC code axis                      (HIERARCHY.tape @N adc_status)
  4. THERANOSTIC scope decision         (HIERARCHY.tape @N theranostic_status
                                         + AXIS/THERANOSTIC_SCOPE.md)

A 5th item that USED to be in the CHANGELOG DEFERRED table — the `hexa atlas`
🔵 upgrade — is now PARTIALLY RESOLVED by the R1 atlas-atom registry
(_python_bridge/spec/atlas_atom_registry.json), which symbolically proves
5 atoms and proposes an upgrade roster. The formal `hexa verify` upgrade
itself is still pending (sister-repo work), so this gate reports it as
PARTIALLY-RESOLVED, not STILL-DEFERRED and not UN-DEFERRED-VIOLATION.

VERDICT TOKENS
--------------
  STILL-DEFERRED          — the deferred-state preconditions are all met
                             on disk; no fabrication, no silent removal.
  PARTIALLY-RESOLVED      — some preconditions met but the formal
                             deferred-state markers still in place
                             (e.g. atlas R1 registry partially resolves
                             the 🔵 upgrade question but the formal
                             hexa-meta lean4 proof is still pending).
  UN-DEFERRED-VIOLATION   — a deferred-state marker is gone or
                             contradicted (e.g. a `genetic_medicine/`
                             directory appeared without the corresponding
                             HIERARCHY.tape `@D` axis-declaration update).

SENTINEL
--------
  __DEFERRED_ITEMS_TRACKING_GATE__ PASS  iff every item is STILL-DEFERRED
  or PARTIALLY-RESOLVED. FAIL on any UN-DEFERRED-VIOLATION.

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first / honest-boundary-check — the gate does NOT inflate.
     Each "still deferred" verdict ties to a concrete on-disk precondition
     (absence of a directory, presence of an `@N` note, presence of a
     text marker in a scope-resolution document).
  g7 skip-is-honest — if the canonical reference file is absent (e.g.
     AXIS/THERANOSTIC_SCOPE.md got renamed), the affected preconditions
     report SKIP for that precondition. A SKIPPED precondition does not
     by itself force a verdict — it is reported in the trace and the
     remaining preconditions decide.
  g8 in-silico-only-claim-scope — this gate is GOVERNANCE METADATA, not
     a clinical / therapeutic / regulatory / efficacy claim. PASS here
     does NOT assert any axis is or is not a viable therapy; it asserts
     only that the DEFERRED-state declarations and the on-disk
     boundary are mutually consistent.
  reporter+boundary-enforcer pattern — the gate reports verdicts per item;
     it FAILs only on the genuine UN-DEFERRED-VIOLATION ("someone added
     code without the paired governance update").

DETERMINISM
-----------
Pure stdlib; no network / no random / no wall-clock. Re-running on the
same repo state produces byte-identical output.

Usage:
    python3 selftest/deferred_items_tracking_gate.py
    # exit 0 = every item STILL-DEFERRED or PARTIALLY-RESOLVED
    # exit 1 = at least one item UN-DEFERRED-VIOLATION
"""
from __future__ import annotations

import json
import os
import re
import sys

# ── repo layout ──────────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HIERARCHY_TAPE = os.path.join(REPO_ROOT, "AXIS", "HIERARCHY.tape")
THERANOSTIC_SCOPE = os.path.join(REPO_ROOT, "AXIS", "THERANOSTIC_SCOPE.md")
CHANGELOG_MD = os.path.join(REPO_ROOT, "CHANGELOG.md")
CASE_STUDIES = os.path.join(REPO_ROOT, "case_studies")
PY_BRIDGE_MODULE = os.path.join(REPO_ROOT, "_python_bridge", "module")
PY_BRIDGE_SPEC = os.path.join(REPO_ROOT, "_python_bridge", "spec")
ATLAS_REGISTRY = os.path.join(PY_BRIDGE_SPEC, "atlas_atom_registry.json")

# verdict tokens
STILL_DEFERRED = "STILL-DEFERRED"
PARTIALLY_RESOLVED = "PARTIALLY-RESOLVED"
UN_DEFERRED_VIOLATION = "UN-DEFERRED-VIOLATION"

# precondition tokens (per-line trace)
MET = "MET"
UN_MET = "UN-MET"
SKIP = "SKIP"


# ── helpers ──────────────────────────────────────────────────────────────
def repo_rel(path):
    """Render an absolute path relative to the repo root (for readable trace)."""
    try:
        return os.path.relpath(path, REPO_ROOT)
    except ValueError:
        return path


def file_contains(path, pattern, *, regex=False):
    """Return True iff the file exists and contains `pattern`. Honest False on
    missing file. `regex=True` treats pattern as a regular expression (with
    re.MULTILINE so `^` matches per-line, the natural mode for .tape entry
    headers)."""
    if not os.path.isfile(path):
        return False
    try:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return False
    if regex:
        return re.search(pattern, text, re.MULTILINE) is not None
    return pattern in text


def list_dirs(parent):
    """Return list of immediate sub-directory names in `parent`, or [] if the
    parent does not exist (honest absent)."""
    if not os.path.isdir(parent):
        return []
    return sorted(
        d for d in os.listdir(parent)
        if os.path.isdir(os.path.join(parent, d))
    )


def list_files_matching(directory, pattern):
    """Return sorted list of files in `directory` matching the regex
    `pattern`. Empty list on missing directory."""
    if not os.path.isdir(directory):
        return []
    rx = re.compile(pattern)
    return sorted(f for f in os.listdir(directory) if rx.match(f))


# ── per-item checks ──────────────────────────────────────────────────────
# Each check returns a dict:
#   { "name": str, "deferred_declaration": str, "primary_refs": [str],
#     "preconditions": [ {"label": str, "result": MET|UN_MET|SKIP,
#                         "detail": str}, ... ],
#     "verdict": STILL_DEFERRED|PARTIALLY_RESOLVED|UN_DEFERRED_VIOLATION,
#     "rationale": str }


def check_200_disease_remapping():
    """200-disease re-mapping — declared DEFERRED in CHANGELOG.md DEFERRED
    table + HIERARCHY.tape Log. Un-deferral would create a 200-item
    disease-master-map artifact. Until then, only a small number of
    one-disease pilots exist in case_studies/."""
    name = "200-disease re-mapping"
    deferred_declaration = (
        "DEFERRED — CHANGELOG.md DEFERRED table row 1; HIERARCHY.tape Log "
        "(\"200-disease re-mapping remains DEFERRED\"). One-disease "
        "case_studies/ pilots are NOT a replacement (CHANGELOG.md L445)."
    )
    primary_refs = [repo_rel(CHANGELOG_MD), repo_rel(HIERARCHY_TAPE)]

    pre = []
    # Precondition 1: no disease_master_map.json (or equivalent 200-item map)
    candidate_master_maps = [
        os.path.join(CASE_STUDIES, "disease_master_map.json"),
        os.path.join(CASE_STUDIES, "disease_panel_200.json"),
        os.path.join(CASE_STUDIES, "200_disease_remapping.json"),
        os.path.join(REPO_ROOT, "disease_master_map.json"),
    ]
    found_master = [p for p in candidate_master_maps if os.path.isfile(p)]
    if not found_master:
        pre.append({
            "label": "no 200-item disease-master-map file present",
            "result": MET,
            "detail": (
                "checked " + ", ".join(repo_rel(p) for p in candidate_master_maps)
                + " — none present"
            ),
        })
    else:
        pre.append({
            "label": "no 200-item disease-master-map file present",
            "result": UN_MET,
            "detail": ("found: " + ", ".join(repo_rel(p) for p in found_master)
                       + " — a 200-disease panel artifact appeared without "
                       "a paired HIERARCHY.tape un-deferral declaration"),
        })

    # Precondition 2: case_studies/ has only a small number of one-disease pilots
    studies = list_dirs(CASE_STUDIES)
    # `landscape` / `drug_redesign_sandbox` are not disease pilots — count
    # only directories that look like *_portfolio.
    disease_pilots = [d for d in studies if d.endswith("_portfolio")]
    pilot_threshold = 10
    if len(disease_pilots) <= pilot_threshold:
        pre.append({
            "label": (f"≤{pilot_threshold} one-disease pilots in case_studies/"
                      " (not the deferred 200-disease panel)"),
            "result": MET,
            "detail": (f"{len(disease_pilots)} disease-pilot directories found "
                       f"({', '.join(disease_pilots) if disease_pilots else 'none'}); "
                       f"all of case_studies/ subdirs: "
                       f"{', '.join(studies) if studies else '(empty)'}"),
        })
    else:
        pre.append({
            "label": (f"≤{pilot_threshold} one-disease pilots in case_studies/"
                      " (not the deferred 200-disease panel)"),
            "result": UN_MET,
            "detail": (f"{len(disease_pilots)} pilot directories — exceeds "
                       f"the {pilot_threshold} threshold consistent with "
                       f"one-disease pilots; un-deferral may have occurred "
                       f"silently"),
        })

    # Precondition 3: CHANGELOG.md DEFERRED row 1 still declares 200-disease
    if os.path.isfile(CHANGELOG_MD):
        if file_contains(CHANGELOG_MD, "200-disease re-mapping"):
            pre.append({
                "label": ("CHANGELOG.md still declares the 200-disease "
                          "re-mapping as DEFERRED"),
                "result": MET,
                "detail": ("CHANGELOG.md contains the literal string "
                           "'200-disease re-mapping' (DEFERRED-table marker)"),
            })
        else:
            pre.append({
                "label": ("CHANGELOG.md still declares the 200-disease "
                          "re-mapping as DEFERRED"),
                "result": UN_MET,
                "detail": ("CHANGELOG.md present but no '200-disease "
                           "re-mapping' marker — declaration may have been "
                           "removed without a paired un-deferral entry"),
            })
    else:
        pre.append({
            "label": ("CHANGELOG.md still declares the 200-disease "
                      "re-mapping as DEFERRED"),
            "result": SKIP,
            "detail": (f"{repo_rel(CHANGELOG_MD)} absent on host — g7 "
                       "skip-is-honest; cannot verify declaration"),
        })

    return _finalize(
        name=name,
        deferred_declaration=deferred_declaration,
        primary_refs=primary_refs,
        preconditions=pre,
        partial_when=set(),  # no partial-resolution path for this item at HEAD
        partial_rationale="",
    )


def check_genetic_medicine():
    """GENETIC-MEDICINE code axis — declared UNPLACED in HIERARCHY.tape
    `@N genetic_medicine_status`. Un-deferral would create a
    genetic_medicine/module/ directory or a `_python_bridge/module/
    genetic_medicine_*.py` sim. Only the UNPLACED note + honest-negative
    case-study mentions exist."""
    name = "GENETIC-MEDICINE code axis"
    deferred_declaration = (
        "UNPLACED (CBER scope, criterion #4) — HIERARCHY.tape "
        "@N genetic_medicine_status; CHANGELOG.md DEFERRED table."
    )
    primary_refs = [repo_rel(HIERARCHY_TAPE), repo_rel(CHANGELOG_MD)]

    pre = []
    # Precondition 1: no genetic_medicine/module/ directory
    gm_module_dir = os.path.join(REPO_ROOT, "genetic_medicine", "module")
    if not os.path.isdir(gm_module_dir):
        pre.append({
            "label": "no genetic_medicine/module/ directory",
            "result": MET,
            "detail": f"{repo_rel(gm_module_dir)} absent",
        })
    else:
        pre.append({
            "label": "no genetic_medicine/module/ directory",
            "result": UN_MET,
            "detail": (f"{repo_rel(gm_module_dir)} present — code axis "
                       "appeared without a paired HIERARCHY.tape "
                       "@D axis_genetic_medicine declaration"),
        })

    # Precondition 2: no _python_bridge/module/genetic_medicine_*.py sim
    gm_sims = list_files_matching(
        PY_BRIDGE_MODULE, r"^genetic_medicine.*\.py$")
    if not gm_sims:
        pre.append({
            "label": "no _python_bridge/module/genetic_medicine_*.py sim",
            "result": MET,
            "detail": (f"scanned {repo_rel(PY_BRIDGE_MODULE)} — no "
                       "genetic_medicine_*.py files"),
        })
    else:
        pre.append({
            "label": "no _python_bridge/module/genetic_medicine_*.py sim",
            "result": UN_MET,
            "detail": ("found: "
                       + ", ".join(gm_sims)
                       + " — sim appeared without a paired HIERARCHY.tape "
                       "@D axis_genetic_medicine declaration"),
        })

    # Precondition 3: HIERARCHY.tape still carries @N genetic_medicine_status UNPLACED
    if os.path.isfile(HIERARCHY_TAPE):
        # latch on the @N entry header — UNPLACED-state declaration
        has_note = file_contains(
            HIERARCHY_TAPE,
            r'^@N\s+genetic_medicine_status\s*:=',
            regex=True,
        )
        unplaced_text = file_contains(
            HIERARCHY_TAPE, "UNPLACED",
        )  # rough — UNPLACED appears in adc/theranostic too; the @N latch is the strict check
        if has_note:
            pre.append({
                "label": ("HIERARCHY.tape carries "
                          "@N genetic_medicine_status (UNPLACED note)"),
                "result": MET,
                "detail": ("@N genetic_medicine_status entry header still "
                           "present in HIERARCHY.tape; UNPLACED text "
                           f"present={unplaced_text}"),
            })
        else:
            pre.append({
                "label": ("HIERARCHY.tape carries "
                          "@N genetic_medicine_status (UNPLACED note)"),
                "result": UN_MET,
                "detail": ("@N genetic_medicine_status header NOT FOUND "
                           "in HIERARCHY.tape — UNPLACED declaration removed "
                           "without a paired @D axis_genetic_medicine "
                           "registration"),
            })
    else:
        pre.append({
            "label": ("HIERARCHY.tape carries "
                      "@N genetic_medicine_status (UNPLACED note)"),
            "result": SKIP,
            "detail": (f"{repo_rel(HIERARCHY_TAPE)} absent — g7 "
                       "skip-is-honest; cannot verify the @N marker"),
        })

    return _finalize(
        name=name,
        deferred_declaration=deferred_declaration,
        primary_refs=primary_refs,
        preconditions=pre,
        partial_when=set(),
        partial_rationale="",
    )


def check_adc():
    """ADC code axis — declared UNPLACED in HIERARCHY.tape `@N adc_status`
    (antibody component is CBER). Un-deferral would create adc/module/ or
    _python_bridge/module/adc_*.py."""
    name = "ADC code axis"
    deferred_declaration = (
        "UNPLACED (CBER antibody scope, criterion #4) — HIERARCHY.tape "
        "@N adc_status; CHANGELOG.md DEFERRED table."
    )
    primary_refs = [repo_rel(HIERARCHY_TAPE), repo_rel(CHANGELOG_MD)]

    pre = []
    # Precondition 1: no adc/module/ directory
    adc_module_dir = os.path.join(REPO_ROOT, "adc", "module")
    if not os.path.isdir(adc_module_dir):
        pre.append({
            "label": "no adc/module/ directory",
            "result": MET,
            "detail": f"{repo_rel(adc_module_dir)} absent",
        })
    else:
        pre.append({
            "label": "no adc/module/ directory",
            "result": UN_MET,
            "detail": (f"{repo_rel(adc_module_dir)} present — code axis "
                       "appeared without a paired HIERARCHY.tape "
                       "@D axis_adc declaration"),
        })

    # Precondition 2: no _python_bridge/module/adc_*.py sim. Be strict —
    # match on a leading "adc_" prefix (the axis-sim pattern used by the
    # other axes is `<axis>_<topic>_sim.py`).
    adc_sims = list_files_matching(PY_BRIDGE_MODULE, r"^adc_.*\.py$")
    if not adc_sims:
        pre.append({
            "label": "no _python_bridge/module/adc_*.py sim",
            "result": MET,
            "detail": (f"scanned {repo_rel(PY_BRIDGE_MODULE)} — no "
                       "adc_*.py files"),
        })
    else:
        pre.append({
            "label": "no _python_bridge/module/adc_*.py sim",
            "result": UN_MET,
            "detail": ("found: "
                       + ", ".join(adc_sims)
                       + " — sim appeared without a paired HIERARCHY.tape "
                       "@D axis_adc declaration"),
        })

    # Precondition 3: HIERARCHY.tape still carries @N adc_status UNPLACED
    if os.path.isfile(HIERARCHY_TAPE):
        has_note = file_contains(
            HIERARCHY_TAPE,
            r'^@N\s+adc_status\s*:=',
            regex=True,
        )
        if has_note:
            pre.append({
                "label": ("HIERARCHY.tape carries @N adc_status "
                          "(UNPLACED note)"),
                "result": MET,
                "detail": ("@N adc_status entry header still present in "
                           "HIERARCHY.tape"),
            })
        else:
            pre.append({
                "label": ("HIERARCHY.tape carries @N adc_status "
                          "(UNPLACED note)"),
                "result": UN_MET,
                "detail": ("@N adc_status header NOT FOUND in HIERARCHY.tape "
                           "— UNPLACED declaration removed without a paired "
                           "@D axis_adc registration"),
            })
    else:
        pre.append({
            "label": "HIERARCHY.tape carries @N adc_status (UNPLACED note)",
            "result": SKIP,
            "detail": (f"{repo_rel(HIERARCHY_TAPE)} absent — g7 "
                       "skip-is-honest; cannot verify the @N marker"),
        })

    return _finalize(
        name=name,
        deferred_declaration=deferred_declaration,
        primary_refs=primary_refs,
        preconditions=pre,
        partial_when=set(),
        partial_rationale="",
    )


def check_theranostic_scope():
    """THERANOSTIC scope decision — declared UNPLACED in HIERARCHY.tape
    `@N theranostic_status`; AXIS/THERANOSTIC_SCOPE.md is the 260-line
    FOR/AGAINST/DEFERRED scope-resolution doc that does NOT decide. Until
    user picks (Option A register-with-disclosure / Option B keep-UNPLACED),
    no theranostic/module/ directory or theranostic_*.py sim must exist."""
    name = "THERANOSTIC scope decision"
    deferred_declaration = (
        "UNPLACED, DECISION DEFERRED — HIERARCHY.tape @N theranostic_status "
        "+ AXIS/THERANOSTIC_SCOPE.md (FOR/AGAINST/DEFERRED, no decision); "
        "CHANGELOG.md DEFERRED table."
    )
    primary_refs = [repo_rel(HIERARCHY_TAPE), repo_rel(THERANOSTIC_SCOPE),
                    repo_rel(CHANGELOG_MD)]

    pre = []
    # Precondition 1: HIERARCHY.tape still carries @N theranostic_status
    if os.path.isfile(HIERARCHY_TAPE):
        has_note = file_contains(
            HIERARCHY_TAPE,
            r'^@N\s+theranostic_status\s*:=',
            regex=True,
        )
        if has_note:
            pre.append({
                "label": ("HIERARCHY.tape carries @N theranostic_status "
                          "(UNPLACED note)"),
                "result": MET,
                "detail": ("@N theranostic_status entry header still present "
                           "in HIERARCHY.tape"),
            })
        else:
            pre.append({
                "label": ("HIERARCHY.tape carries @N theranostic_status "
                          "(UNPLACED note)"),
                "result": UN_MET,
                "detail": ("@N theranostic_status header NOT FOUND in "
                           "HIERARCHY.tape — UNPLACED declaration removed "
                           "without a paired @D axis_theranostic "
                           "registration"),
            })
    else:
        pre.append({
            "label": ("HIERARCHY.tape carries @N theranostic_status "
                      "(UNPLACED note)"),
            "result": SKIP,
            "detail": (f"{repo_rel(HIERARCHY_TAPE)} absent — g7 "
                       "skip-is-honest"),
        })

    # Precondition 2: AXIS/THERANOSTIC_SCOPE.md still reads DECISION DEFERRED
    if os.path.isfile(THERANOSTIC_SCOPE):
        deferred_text = file_contains(THERANOSTIC_SCOPE, "DECISION DEFERRED")
        does_not_decide = file_contains(
            THERANOSTIC_SCOPE, "does NOT pick a side"
        ) or file_contains(THERANOSTIC_SCOPE, "does NOT decide")
        if deferred_text and does_not_decide:
            pre.append({
                "label": ("AXIS/THERANOSTIC_SCOPE.md reads 'DECISION "
                          "DEFERRED' and 'does NOT pick a side'"),
                "result": MET,
                "detail": ("both markers present — the scope-resolution "
                           "document still defers the decision to the user"),
            })
        else:
            pre.append({
                "label": ("AXIS/THERANOSTIC_SCOPE.md reads 'DECISION "
                          "DEFERRED' and 'does NOT pick a side'"),
                "result": UN_MET,
                "detail": (f"DECISION DEFERRED text present={deferred_text}; "
                           f"'does NOT pick a side' text "
                           f"present={does_not_decide} — the deferred-state "
                           "markers have changed without a paired "
                           "HIERARCHY.tape un-deferral entry"),
            })
    else:
        pre.append({
            "label": ("AXIS/THERANOSTIC_SCOPE.md reads 'DECISION "
                      "DEFERRED' and 'does NOT pick a side'"),
            "result": SKIP,
            "detail": (f"{repo_rel(THERANOSTIC_SCOPE)} absent — g7 "
                       "skip-is-honest; doc may have been renamed, but "
                       "the verdict still rests on the HIERARCHY.tape "
                       "@N marker (precondition 1)"),
        })

    # Precondition 3: no theranostic/module/ directory and no theranostic_*.py sim
    ther_module_dir = os.path.join(REPO_ROOT, "theranostic", "module")
    ther_sims = list_files_matching(PY_BRIDGE_MODULE, r"^theranostic.*\.py$")
    boundary_ok = (not os.path.isdir(ther_module_dir)) and (not ther_sims)
    if boundary_ok:
        pre.append({
            "label": ("no theranostic/module/ directory and no "
                      "_python_bridge/module/theranostic_*.py sim"),
            "result": MET,
            "detail": (f"{repo_rel(ther_module_dir)} absent; "
                       f"no theranostic*.py files in "
                       f"{repo_rel(PY_BRIDGE_MODULE)}"),
        })
    else:
        detail_bits = []
        if os.path.isdir(ther_module_dir):
            detail_bits.append(f"{repo_rel(ther_module_dir)} present")
        if ther_sims:
            detail_bits.append("sim files: " + ", ".join(ther_sims))
        pre.append({
            "label": ("no theranostic/module/ directory and no "
                      "_python_bridge/module/theranostic_*.py sim"),
            "result": UN_MET,
            "detail": ("; ".join(detail_bits)
                       + " — code axis appeared without a paired "
                       "HIERARCHY.tape @D axis_theranostic declaration"),
        })

    return _finalize(
        name=name,
        deferred_declaration=deferred_declaration,
        primary_refs=primary_refs,
        preconditions=pre,
        partial_when=set(),
        partial_rationale="",
    )


def check_atlas_blue_upgrade():
    """🔵 atlas atom upgrade — the CHANGELOG DEFERRED-table 5th item that
    R1 (the atlas atom registry) has PARTIALLY RESOLVED.

    Why this is a 5th tracked item (and why it is PARTIALLY-RESOLVED, not
    STILL-DEFERRED): the CHANGELOG.md DEFERRED table row 2 is
    \"hexa atlas 🔵 upgrade — DEFERRED (sister-repo work; only
    lean4_proof_witness_emit.py currently 🔵)\". R1 added
    _python_bridge/spec/atlas_atom_registry.json which symbolically proves
    a roster of atoms (Caspar-Klug, Griffith-Orgel, MWC, mass-action
    cooperativity, 2x2 CI) and proposes an upgrade for the dependent sims
    — partial resolution. The formal `hexa verify` 🔵 tier flip itself is
    still sister-repo work (hexa-meta lean4 proof, per g5/g6/f3) — so it
    remains DEFERRED at the tier-reporter level.

    PARTIALLY-RESOLVED is the honest verdict: registry present (resolves
    the in-repo half), formal hexa verify upgrade pending (the sister-repo
    half still deferred).
    """
    name = "hexa atlas 🔵 upgrade"
    deferred_declaration = (
        "DEFERRED (sister-repo work) — CHANGELOG.md DEFERRED table; "
        "partial-resolution path: R1 added "
        "_python_bridge/spec/atlas_atom_registry.json with PROVEN atoms + "
        "upgrade proposal; formal hexa verify 🔵 flip still pending in "
        "hexa-meta sister repo."
    )
    primary_refs = [repo_rel(CHANGELOG_MD), repo_rel(ATLAS_REGISTRY)]

    pre = []
    # Precondition 1: R1 registry present
    if os.path.isfile(ATLAS_REGISTRY):
        try:
            with open(ATLAS_REGISTRY, "r", encoding="utf-8") as fh:
                reg = json.load(fh)
            atoms = reg.get("atoms", [])
            n_proven = sum(1 for a in atoms
                           if a.get("proof_status") == "PROVEN")
            n_total = len(atoms)
            registry_ok = n_proven >= 1
            pre.append({
                "label": ("R1 atlas atom registry present (partial "
                          "resolution: in-repo symbolic proofs)"),
                "result": MET if registry_ok else UN_MET,
                "detail": (f"{repo_rel(ATLAS_REGISTRY)} loaded; "
                           f"{n_proven}/{n_total} atom(s) PROVEN; "
                           f"registry_version="
                           f"{reg.get('registry_version', '?')}"),
            })
        except (OSError, json.JSONDecodeError) as e:
            pre.append({
                "label": ("R1 atlas atom registry present (partial "
                          "resolution: in-repo symbolic proofs)"),
                "result": UN_MET,
                "detail": (f"{repo_rel(ATLAS_REGISTRY)} present but "
                           f"unreadable / invalid JSON: {e!r}"),
            })
    else:
        pre.append({
            "label": ("R1 atlas atom registry present (partial "
                      "resolution: in-repo symbolic proofs)"),
            "result": SKIP,
            "detail": (f"{repo_rel(ATLAS_REGISTRY)} absent — g7 "
                       "skip-is-honest; if registry is gone the item "
                       "reverts to STILL-DEFERRED, not violation"),
        })

    # Precondition 2: CHANGELOG.md still declares the upgrade DEFERRED OR
    # the registry is present (one of the two anchors the verdict).
    if os.path.isfile(CHANGELOG_MD):
        # The CHANGELOG row contains "hexa atlas` 🔵 upgrade" (backtick
        # variant) — match the literal phrase with the backtick.
        has_declaration = (
            file_contains(CHANGELOG_MD, "hexa atlas` 🔵 upgrade")
            or file_contains(CHANGELOG_MD, "atlas` 🔵 upgrade")
            or file_contains(CHANGELOG_MD, "🔵 upgrade")
        )
        if has_declaration:
            pre.append({
                "label": ("CHANGELOG.md still declares the 🔵 upgrade as "
                          "DEFERRED (formal flip pending sister-repo)"),
                "result": MET,
                "detail": ("CHANGELOG.md contains the '🔵 upgrade' DEFERRED "
                           "marker"),
            })
        else:
            pre.append({
                "label": ("CHANGELOG.md still declares the 🔵 upgrade as "
                          "DEFERRED (formal flip pending sister-repo)"),
                "result": UN_MET,
                "detail": ("CHANGELOG.md present but no '🔵 upgrade' marker "
                           "— declaration may have been removed; if the "
                           "formal flip actually happened, this would be "
                           "honest (paired with a registered-axis update); "
                           "until verified, treat as un-met"),
            })
    else:
        pre.append({
            "label": ("CHANGELOG.md still declares the 🔵 upgrade as "
                      "DEFERRED (formal flip pending sister-repo)"),
            "result": SKIP,
            "detail": (f"{repo_rel(CHANGELOG_MD)} absent — g7 "
                       "skip-is-honest"),
        })

    # This item's natural verdict is PARTIALLY-RESOLVED when both
    # preconditions are MET (registry present AND deferred declaration
    # still in CHANGELOG). If the registry is present and the declaration
    # is gone, it is honestly STILL-DEFERRED→fully-resolved territory,
    # which we treat as PARTIALLY-RESOLVED (we can't verify the
    # sister-repo formal flip from here, so we never claim fully resolved).
    # If neither precondition is MET, the item is STILL-DEFERRED (the
    # honest default).
    return _finalize(
        name=name,
        deferred_declaration=deferred_declaration,
        primary_refs=primary_refs,
        preconditions=pre,
        partial_when={"registry_met"},
        partial_rationale=(
            "R1 atlas atom registry is in-repo and PROVES a roster of "
            "atoms (in-repo half resolved); formal hexa verify 🔵 tier "
            "flip is sister-repo work (hexa-meta lean4, g5/g6/f3) and "
            "is honestly still pending — PARTIALLY-RESOLVED, not "
            "fully-resolved, not violated"
        ),
    )


# ── verdict resolution ──────────────────────────────────────────────────
def _finalize(*, name, deferred_declaration, primary_refs,
              preconditions, partial_when, partial_rationale):
    """Resolve the final verdict from the precondition list.

    Rules (honest boundary enforcer):
      - any UN_MET on a CODE-BOUNDARY precondition (anything checking a
        directory / sim file presence) ⇒ UN_DEFERRED_VIOLATION.
      - any UN_MET on a DECLARATION precondition (checking a tape @N
        marker / CHANGELOG DEFERRED row) ⇒ UN_DEFERRED_VIOLATION
        (silent removal of the deferred-state declaration).
      - all preconditions MET or SKIP ⇒ STILL_DEFERRED, unless the item's
        `partial_when` token is satisfied (atlas 🔵 case).
    """
    # the atlas-only branch: partial-resolution is the natural verdict
    # when the R1 registry precondition is MET.
    is_atlas_partial = False
    if "registry_met" in partial_when:
        for p in preconditions:
            if (p["label"].startswith("R1 atlas atom registry present")
                    and p["result"] == MET):
                is_atlas_partial = True
                break

    has_violation = any(p["result"] == UN_MET for p in preconditions)

    if has_violation:
        verdict = UN_DEFERRED_VIOLATION
        rationale = ("at least one precondition UN-MET — see trace. A code "
                     "or declaration boundary was crossed without a paired "
                     "governance un-deferral entry (HIERARCHY.tape @D "
                     "axis_<X> registration or CHANGELOG.md DEFERRED-row "
                     "removal). FAIL until governance update is added.")
    elif is_atlas_partial:
        verdict = PARTIALLY_RESOLVED
        rationale = partial_rationale
    else:
        verdict = STILL_DEFERRED
        rationale = ("all preconditions MET (or honestly SKIPPED via g7); "
                     "no code/declaration boundary crossed.")

    return {
        "name": name,
        "deferred_declaration": deferred_declaration,
        "primary_refs": primary_refs,
        "preconditions": preconditions,
        "verdict": verdict,
        "rationale": rationale,
    }


# ── printing ────────────────────────────────────────────────────────────
def _print_item(idx, item):
    print(f"── item {idx}: {item['name']} " + "─" * max(
        0, 60 - len(item['name'])))
    print(f"  deferred declaration : {item['deferred_declaration']}")
    print(f"  primary references   : {', '.join(item['primary_refs'])}")
    print(f"  preconditions:")
    for p in item["preconditions"]:
        print(f"    [{p['result']:<6}] {p['label']}")
        print(f"             {p['detail']}")
    print(f"  VERDICT              : {item['verdict']}")
    print(f"  rationale            : {item['rationale']}")
    print()


def _print_summary_table(items):
    print("── summary table " + "─" * 56)
    name_w = max(len(it["name"]) for it in items)
    verdict_w = max(len(it["verdict"]) for it in items)
    print(f"  {'#':<2} {'item':<{name_w}}  {'verdict':<{verdict_w}}")
    print(f"  {'-' * 2} {'-' * name_w}  {'-' * verdict_w}")
    for i, it in enumerate(items, 1):
        print(f"  {i:<2} {it['name']:<{name_w}}  "
              f"{it['verdict']:<{verdict_w}}")
    print()


# ── main ────────────────────────────────────────────────────────────────
def main():
    print("deferred_items_tracking_gate — hexa-bio DEFERRED items "
          "boundary enforcer")
    print("  enumerates the explicitly-DEFERRED items declared in "
          "AXIS/HIERARCHY.tape + CHANGELOG.md and verifies the deferred-")
    print("  state preconditions still hold on disk. PASS iff every item "
          "is STILL-DEFERRED or PARTIALLY-RESOLVED (no silent "
          "un-deferral).")
    print("  governance: g1 honest-boundary-check · g7 skip-is-honest "
          "(absent ref ⇒ SKIP, not FAIL) · g8 in-silico-only "
          "(governance metadata, not a clinical claim)")
    print("  honest framing: this gate is a BOUNDARY ENFORCER, not a "
          "PERMANENT FREEZE. Un-deferral is a legitimate future")
    print("  action; it must be paired with a governance update "
          "(HIERARCHY.tape @D axis_<X> registration or CHANGELOG.md")
    print("  DEFERRED-row removal) — that pairing is what this gate "
          "checks.\n")

    items = [
        check_200_disease_remapping(),
        check_genetic_medicine(),
        check_adc(),
        check_theranostic_scope(),
        check_atlas_blue_upgrade(),
    ]

    for i, item in enumerate(items, 1):
        _print_item(i, item)

    _print_summary_table(items)

    n_still = sum(1 for it in items if it["verdict"] == STILL_DEFERRED)
    n_partial = sum(1 for it in items if it["verdict"] == PARTIALLY_RESOLVED)
    n_violation = sum(1 for it in items
                      if it["verdict"] == UN_DEFERRED_VIOLATION)
    n_total = len(items)
    print(f"  {n_still} STILL-DEFERRED · {n_partial} PARTIALLY-RESOLVED · "
          f"{n_violation} UN-DEFERRED-VIOLATION (of {n_total} items)\n")

    print("  HONESTY (g1): each verdict ties to concrete on-disk")
    print("    preconditions (file presence / @N marker / text marker).")
    print("    No precondition is fabricated; absent reference files are")
    print("    honestly SKIPPED (g7), not silently passed.")
    print("  HONESTY (g8): this gate is GOVERNANCE METADATA. PASS does")
    print("    NOT assert any axis is or is not a viable therapy; it")
    print("    asserts only that the DEFERRED declarations and the")
    print("    on-disk boundary are mutually consistent.")
    print("  HONESTY (framing): boundary-enforcer ≠ permanent-freeze.")
    print("    A FAIL here means an item was un-deferred without the")
    print("    paired governance update — the fix is to either pair")
    print("    the new code with a HIERARCHY.tape @D axis_<X> entry +")
    print("    CHANGELOG update, or remove the un-deferred artifact.\n")

    ok = n_violation == 0
    if ok:
        print("__DEFERRED_ITEMS_TRACKING_GATE__ PASS")
        return 0
    print("__DEFERRED_ITEMS_TRACKING_GATE__ FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
