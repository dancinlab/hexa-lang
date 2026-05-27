#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
case_studies/landscape/landscape_generator.py — modality landscape cross-tab
generator for hexa-bio case-study portfolios.

WHAT THIS IS
------------
A deterministic stdlib-only REPORTER that discovers every case-study portfolio
on disk, runs each runner as a subprocess, parses the witness JSON, and
projects the union onto a CROSS-TAB:

  rows = diseases discovered on disk (sorted by portfolio directory name)
  cols = the 24-axis surface from AXIS/HIERARCHY.tape (5 core + 4 expansion
         -main + 15 sub-axes), in stable curator order

Each cell answers ONE question: for this disease, what status does this axis
carry? Four cell glyphs, no ranking, no combination:

  '✓ <drug>'        — FDA-approved IN-SCOPE drug mapped onto this axis
                       (drug from the witness's in_scope_drugs[].drug or
                        in_scope_drugs[].drug_name field — never fabricated).
                       'approved' status only; 'clinical_stage' downgrades
                       to '🔬 research'.
  '🔬 research'     — research-stage candidate listed in the witness's
                       research_stage_negatives[] with axis_in_repo set.
                       Also: bcl2 navitoclax (clinical-stage, not FDA-approved).
  '⚠ UNPLACED'     — recorded in the witness as not_in_scope_drugs[] or as
                       a research_stage_negatives[] row with fda_center_if_filed
                       set to 'CBER'/'CDRH' AND axis_in_repo=null. NEVER
                       attached to a specific axis column (no fake coverage
                       of CBER scope); reported per-disease only.
  '·'                — no candidate / not applicable (honest empty)

REPORTER ≠ RANKER
-----------------
This is a CROSS-TAB, not a ranking. The landscape is HONESTLY SPARSE — most
cells are '·' (empty), and that is the truth. The generator never:
  * computes a compound score or 'best disease' / 'best axis',
  * compares diseases or axes to each other,
  * fabricates a drug or an axis mapping not present in the witness JSON.

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first — every cell value is read from a portfolio runner's
     own witness JSON; no synthetic field is invented.
  g3 honesty-obligation-external — modalities described only by their own
     drug precedent (the witness already carries those); never lattice-fit.
  g7 skip-is-honest — if a runner fails / times out / emits no parseable
     witness, that row is included with a SKIP marker; the gate still PASSes
     if at least one portfolio was discovered AND scored. SKIP if zero.
  g8 in-silico-only — the landscape characterizes the repo's IN-SILICO
     portfolio-cohort shape ONLY. NOT a therapeutic / clinical / regulatory
     / efficacy / portfolio-recommendation claim.
  f_lattice_fit — cell counts and axis ordering are NOT derived from the
     n=6 lattice; they come from AXIS/HIERARCHY.tape curator order.

OUTPUTS
-------
  case_studies/landscape/LANDSCAPE.md — overwritten on each run. Carries the
     auto-generated fence at the top; same honesty preamble as the README.
     Section §1 holds the cross-tab table; §2/§3 the per-disease /
     per-axis totals; §4 the honest empty-cell discussion.

Run:
    python3 case_studies/landscape/landscape_generator.py
    # exit 0  → '__LANDSCAPE_GENERATOR__ PASS' (at least one portfolio
    #            discovered AND its witness scored)
    # exit 0  → '__LANDSCAPE_GENERATOR__ SKIP' (no portfolios discovered;
    #            g7 honest)
    # exit 1  → '__LANDSCAPE_GENERATOR__ FAIL' (a discovered runner exited
    #            0 but emitted no parseable witness — hard contract break;
    #            same fence as portfolio_fitness_function.py)
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone

# ── repo layout ─────────────────────────────────────────────────────────
HERE = os.path.dirname(os.path.abspath(__file__))
CASE_STUDIES_DIR = os.path.dirname(HERE)
REPO_ROOT = os.path.dirname(CASE_STUDIES_DIR)
LANDSCAPE_MD = os.path.join(HERE, "LANDSCAPE.md")

# Per-runner subprocess timeout (seconds). Same budget as the portfolio
# fitness-function gate (stdlib-only runners; 30 s is generous).
RUNNER_TIMEOUT_S = 30

# ── verdict tokens ──────────────────────────────────────────────────────
PASS = "PASS"
SKIP = "SKIP"
FAIL = "FAIL"

# ── 24-axis surface (AXIS/HIERARCHY.tape curator order) ─────────────────
# Core-5 (AXIS.tape) · expansion-main (HIERARCHY.tape §1) · sub-axes
# (HIERARCHY.tape §2). The list is the authoritative column order of the
# cross-tab; it is NOT derived from the n=6 lattice (f_lattice_fit).
CORE_AXES = [
    "QUANTUM", "WEAVE", "NANOBOT", "RIBOZYME", "VIROCAPSID",
]
EXPANSION_MAIN_AXES = [
    "COVALENT", "BIFUNCTIONAL", "METALLODRUG", "OLIGONUCLEOTIDE",
]
SUB_AXES = [
    # under BIFUNCTIONAL (6)
    "PROTAC", "LYTAC", "AUTAC", "RIBOTAC",
    "COVALENT-DEGRADER", "MOLECULAR-GLUE",
    # under QUANTUM (3)
    "ALLOSTERIC", "CRYPTIC-POCKET", "PPI",
    # under WEAVE (2)
    "PEPTIDE", "MACROCYCLE",
    # under COVALENT (1)
    "REVERSIBLE-COVALENT",
    # under RIBOZYME (2)
    "RNA-TARGETING-SMALL-MOLECULE", "APTAMER",
    # under VIROCAPSID (1)
    "CAPSID-ASSEMBLY-MODULATOR",
]
ALL_AXES = CORE_AXES + EXPANSION_MAIN_AXES + SUB_AXES
AXIS_LAYER = {a: "core-5" for a in CORE_AXES}
AXIS_LAYER.update({a: "expansion-main" for a in EXPANSION_MAIN_AXES})
AXIS_LAYER.update({a: "expansion-sub" for a in SUB_AXES})
AXIS_INDEX = {a: i for i, a in enumerate(ALL_AXES)}

# Cell glyphs
CELL_EMPTY = "·"
CELL_FDA_PREFIX = "✓"        # IN-SCOPE FDA-approved drug
CELL_RESEARCH = "🔬 research" # research-stage on this axis
CELL_UNPLACED = "⚠ UNPLACED"  # CBER / scope-disqualified (disease-level only)


# ── discovery ───────────────────────────────────────────────────────────
def discover_portfolios():
    """Find every `case_studies/<name>_portfolio/<name>_portfolio_runner.py`.

    Returns a sorted list of {name, dir, runner} dicts. Sorted order is the
    portfolio directory's basename — deterministic across re-runs.
    """
    found = []
    if not os.path.isdir(CASE_STUDIES_DIR):
        return found
    for entry in sorted(os.listdir(CASE_STUDIES_DIR)):
        sub = os.path.join(CASE_STUDIES_DIR, entry)
        if not os.path.isdir(sub):
            continue
        if not entry.endswith("_portfolio"):
            continue
        name = entry[: -len("_portfolio")]
        runner = os.path.join(sub, f"{name}_portfolio_runner.py")
        if not os.path.isfile(runner):
            continue
        found.append({"name": name, "dir": sub, "runner": runner})
    return found


# ── runner execution ─────────────────────────────────────────────────────
def run_runner(runner_path):
    """Execute a portfolio runner under a 30-s timeout.

    Returns a dict {ran, exit_code, stdout, stderr, error}.
    """
    try:
        proc = subprocess.run(
            [sys.executable, runner_path],
            capture_output=True,
            text=True,
            timeout=RUNNER_TIMEOUT_S,
            cwd=REPO_ROOT,
        )
    except subprocess.TimeoutExpired:
        return {
            "ran": False, "exit_code": None, "stdout": "", "stderr": "",
            "error": f"timeout after {RUNNER_TIMEOUT_S} s",
        }
    except OSError as exc:
        return {
            "ran": False, "exit_code": None, "stdout": "", "stderr": "",
            "error": f"OSError: {exc}",
        }
    return {
        "ran": True, "exit_code": proc.returncode,
        "stdout": proc.stdout, "stderr": proc.stderr, "error": None,
    }


# ── witness JSON extraction ─────────────────────────────────────────────
def extract_witness_json(stdout):
    """Pull the witness JSON object out of a runner's stdout.

    Strategy mirrors selftest/portfolio_fitness_function.py: scan every '{'
    candidate, attempt a balanced-brace slice + json.loads, return the
    first slice that loads AND contains schema_version + in_scope_drugs.
    """
    if not isinstance(stdout, str) or "{" not in stdout:
        return None
    n = len(stdout)
    i = 0
    while i < n:
        if stdout[i] != "{":
            i += 1
            continue
        depth = 0
        j = i
        in_str = False
        esc = False
        while j < n:
            ch = stdout[j]
            if in_str:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    in_str = False
            else:
                if ch == '"':
                    in_str = True
                elif ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        candidate = stdout[i:j + 1]
                        try:
                            obj = json.loads(candidate)
                        except json.JSONDecodeError:
                            obj = None
                        if (isinstance(obj, dict)
                                and "schema_version" in obj
                                and "in_scope_drugs" in obj):
                            return obj
                        break
            j += 1
        i += 1
    return None


# ── per-drug axis extraction ────────────────────────────────────────────
def _drug_name(d):
    """Read the drug display name from either schema shape (HIV-1/Mpro/
    KRAS/BCL2: 'drug'; SMA: 'drug_name'). Brand falls back if neither set."""
    for k in ("drug", "drug_name", "brand"):
        v = d.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return "?"


def _drug_axes(d):
    """Return the list of axes a single in_scope_drug binds to.

    Two schema shapes are present in case_studies/:
      * SMA flat shape: drug['axis'] is a top-level string.
      * HIV-1 / Mpro / KRAS / BCL2 nested shape: drug['axis_mapping']['axis']
        is the primary axis; drug['axis_mapping']['cryptic_touch_axis']
        is an optional secondary axis (KRAS-G12C uses this to record the
        COVALENT × CRYPTIC-POCKET dual mapping honestly).

    Returns a list (possibly empty) of axis-name strings. Filters to the
    24-axis surface so an off-list label cannot pollute the column space.
    """
    axes = []
    am = d.get("axis_mapping")
    if isinstance(am, dict):
        a = am.get("axis")
        if isinstance(a, str) and a.strip():
            axes.append(a.strip())
        # Optional secondary mapping (KRAS-G12C schema).
        a2 = am.get("cryptic_touch_axis")
        if isinstance(a2, str) and a2.strip():
            axes.append(a2.strip())
    a_flat = d.get("axis")
    if isinstance(a_flat, str) and a_flat.strip():
        axes.append(a_flat.strip())
    # Deduplicate preserving order; keep only known 24-axis labels.
    seen = []
    for a in axes:
        if a in AXIS_INDEX and a not in seen:
            seen.append(a)
    return seen


def _is_fda_approved(d):
    """Honest FDA-approval check for an in_scope_drug row.

    BCL-2 schema introduces fda_approval_status ∈ {'approved',
    'clinical_stage'} explicitly: navitoclax is in_scope (the parent PPI
    sim cites both BH3-mimetics by name) but is NOT FDA-approved. We
    honor that distinction:
      * fda_approval_status='clinical_stage' → research-stage cell, NOT
        an FDA cell (no fabricated approval).
      * other schemas have no such field; fda_year + fda_center='CDER'
        is the convention. Treat presence of both as approved.
    """
    status = d.get("fda_approval_status")
    if isinstance(status, str):
        return status == "approved"
    # Fallback: a CDER center + a fda_year is the schema's structural
    # approval signature.
    center = d.get("fda_center")
    year = d.get("fda_year")
    return (isinstance(center, str) and center == "CDER"
            and isinstance(year, int))


def _parse_axis_from_in_repo_label(label):
    """research_stage_negatives[].axis_in_repo strings carry a parenthetic
    suffix, e.g. 'OLIGONUCLEOTIDE (expansion-main)' or 'BIFUNCTIONAL (
    expansion-main)'. Some entries describe TWO axes in one string. Match
    each known axis-token within the label; return the list of canonical
    labels that appear. Anchored on token boundaries so 'COVALENT' does
    not falsely match 'COVALENT-DEGRADER' (longer tokens are matched first
    via length-descending order, then we strip overlaps)."""
    if not isinstance(label, str) or not label.strip():
        return []
    matches = []
    # Longest-token-first to give 'COVALENT-DEGRADER' / 'REVERSIBLE-COVALENT'
    # / 'CAPSID-ASSEMBLY-MODULATOR' / 'RNA-TARGETING-SMALL-MOLECULE' a
    # chance to win against 'COVALENT' / 'RIBOZYME' / 'VIROCAPSID' /
    # 'RIBOZYME'. After a longer token claims a span, mask it so its
    # substring tokens cannot re-match.
    s = label
    masked = list(s)
    for axis in sorted(AXIS_INDEX, key=len, reverse=True):
        start = 0
        while True:
            idx = "".join(masked).find(axis, start)
            if idx < 0:
                break
            # token-boundary check: left/right must NOT be a word-char or '-'
            left_ok = idx == 0 or not (masked[idx - 1].isalnum()
                                       or masked[idx - 1] == "-")
            end = idx + len(axis)
            right_ok = end >= len(masked) or not (masked[end].isalnum()
                                                   or masked[end] == "-")
            if left_ok and right_ok:
                if axis not in matches:
                    matches.append(axis)
                # mask the matched span so substrings cannot re-match
                for k in range(idx, end):
                    masked[k] = " "
                start = end
            else:
                start = idx + 1
    return matches


# ── build the cross-tab grid ────────────────────────────────────────────
def build_grid(rows):
    """Project per-portfolio rows onto the 24-axis surface.

    Each portfolio contributes:
      * 0+ FDA cells (in_scope_drugs whose _is_fda_approved → True);
      * 0+ research-stage cells (research_stage_negatives with a
        recognised axis_in_repo label; also in_scope_drugs flagged
        'clinical_stage' downgrade);
      * disease-level UNPLACED notes (not_in_scope_drugs + research-
        stage negatives with fda_center_if_filed='CBER'/'CDRH' AND
        axis_in_repo=null).

    Returns:
      grid:           dict[disease] -> list of 24 cell-strings
      disease_meta:   dict[disease] -> {abbreviation, full_name, name,
                                          fda_count, research_count,
                                          unplaced_count, unplaced_notes,
                                          portfolio, verdict, reason}
      axis_totals:    dict[axis]    -> {fda, research}
      diseases_order: list[str]      — deterministic display order
    """
    grid = {}
    disease_meta = {}
    diseases_order = []
    axis_totals = {a: {"fda": 0, "research": 0} for a in ALL_AXES}

    for r in rows:
        # Disease label: prefer abbreviation; fall back to portfolio name.
        if r["verdict"] != PASS or r.get("witness") is None:
            label = r["name"]  # use portfolio basename if witness absent
            full_name = "—"
            cells = [CELL_EMPTY] * len(ALL_AXES)
            disease_meta[label] = {
                "abbreviation": label,
                "full_name": full_name,
                "fda_count": 0,
                "research_count": 0,
                "unplaced_count": 0,
                "unplaced_notes": [],
                "portfolio": r["name"],
                "verdict": r["verdict"],
                "reason": r.get("reason", ""),
            }
            grid[label] = cells
            diseases_order.append(label)
            continue

        witness = r["witness"]
        d_obj = witness.get("disease") or {}
        if isinstance(d_obj, dict):
            label = (d_obj.get("abbreviation") or d_obj.get("name")
                     or r["name"])
            full_name = d_obj.get("name") or label
        else:
            label = r["name"]
            full_name = "—"

        cells = [CELL_EMPTY] * len(ALL_AXES)
        fda_count = 0
        research_count = 0
        unplaced_notes = []

        # ── in_scope_drugs → '✓ <drug>' (FDA) OR '🔬 research' (clinical-stage)
        for d in witness.get("in_scope_drugs") or []:
            if not isinstance(d, dict):
                continue
            name = _drug_name(d)
            axes = _drug_axes(d)
            approved = _is_fda_approved(d)
            for ax in axes:
                idx = AXIS_INDEX[ax]
                if approved:
                    # Concatenate if the cell already holds another FDA
                    # drug for this (disease, axis) — keep order honest.
                    incumbent = cells[idx]
                    if incumbent == CELL_EMPTY:
                        cells[idx] = f"{CELL_FDA_PREFIX} {name}"
                    elif incumbent.startswith(CELL_FDA_PREFIX):
                        # 'sotorasib + adagrasib' on COVALENT for KRAS-G12C
                        cells[idx] = incumbent + " + " + name
                    else:
                        cells[idx] = f"{CELL_FDA_PREFIX} {name}"
                    fda_count += 1
                    axis_totals[ax]["fda"] += 1
                else:
                    # clinical-stage drug listed in_scope (bcl2 navitoclax).
                    # Demote to research-stage cell on this axis if no
                    # FDA drug already claims it.
                    if not cells[idx].startswith(CELL_FDA_PREFIX):
                        cells[idx] = CELL_RESEARCH
                        axis_totals[ax]["research"] += 1
                    research_count += 1

        # ── research_stage_negatives → '🔬 research' on each parsed axis;
        #     CBER/CDRH ones with null axis → disease-level UNPLACED note.
        for n in witness.get("research_stage_negatives") or []:
            if not isinstance(n, dict):
                continue
            axis_label = n.get("axis_in_repo")
            center = n.get("fda_center_if_filed") or ""
            cls = n.get("candidate_class") or "research-stage"
            parsed = _parse_axis_from_in_repo_label(axis_label)
            if parsed:
                for ax in parsed:
                    idx = AXIS_INDEX[ax]
                    if not cells[idx].startswith(CELL_FDA_PREFIX):
                        if cells[idx] != CELL_RESEARCH:
                            cells[idx] = CELL_RESEARCH
                            axis_totals[ax]["research"] += 1
                    research_count += 1
            else:
                # axis_in_repo is null OR not a recognised label.
                # If the FDA center is CBER/CDRH, this is a scope-
                # disqualified UNPLACED note for the disease (no axis
                # column, by design — no fake CBER coverage).
                if center in ("CBER", "CDRH"):
                    unplaced_notes.append(
                        f"{cls} (CBER scope-disqualified)"
                    )
                else:
                    # Generic research-stage with no axis mapping; record
                    # at the disease level only (honestly off-grid).
                    research_count += 1

        # ── not_in_scope_drugs (SMA Zolgensma pattern) → UNPLACED note
        for n in witness.get("not_in_scope_drugs") or []:
            if not isinstance(n, dict):
                continue
            nm = n.get("drug_name") or n.get("brand") or "UNPLACED"
            center = n.get("fda_center") or ""
            ax = n.get("axis")
            if ax is None and center in ("CBER", "CDRH"):
                unplaced_notes.append(f"{nm} ({center})")
            else:
                # Defensive: if a future portfolio places an UNPLACED on
                # an axis, surface it as a UNPLACED cell on that axis.
                if isinstance(ax, str) and ax in AXIS_INDEX:
                    idx = AXIS_INDEX[ax]
                    if cells[idx] == CELL_EMPTY:
                        cells[idx] = CELL_UNPLACED
                unplaced_notes.append(f"{nm} ({center or '—'})")

        disease_meta[label] = {
            "abbreviation": label,
            "full_name": full_name,
            "fda_count": fda_count,
            "research_count": research_count,
            "unplaced_count": len(unplaced_notes),
            "unplaced_notes": unplaced_notes,
            "portfolio": r["name"],
            "verdict": r["verdict"],
            "reason": "",
        }
        grid[label] = cells
        diseases_order.append(label)

    return grid, disease_meta, axis_totals, diseases_order


# ── markdown table rendering ────────────────────────────────────────────
def _render_table(grid, diseases_order):
    """Render the cross-tab as a markdown table. Axes are columns; the
    first column is the disease label. Wrapped in fenced code-block-like
    pipes; markdown will render it as a real table."""
    # Header row: 'disease' + every axis label
    header = ["disease"] + ALL_AXES
    align = [":---"] + [":---"] * len(ALL_AXES)
    lines = []
    lines.append("| " + " | ".join(header) + " |")
    lines.append("|" + "|".join(align) + "|")
    for d in diseases_order:
        row = [d] + grid[d]
        # Escape '|' inside cell content (none expected, but be safe)
        row = [c.replace("|", "\\|") for c in row]
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def _render_per_disease_totals(disease_meta, diseases_order):
    lines = []
    lines.append("| disease | FDA in-scope | research-stage | UNPLACED (CBER/CDRH) | portfolio | verdict |")
    lines.append("|:---|:---|:---|:---|:---|:---|")
    for d in diseases_order:
        m = disease_meta[d]
        lines.append(
            f"| {d} | {m['fda_count']} | {m['research_count']} | "
            f"{m['unplaced_count']} | `{m['portfolio']}_portfolio` | "
            f"{m['verdict']} |"
        )
    return "\n".join(lines)


def _render_per_axis_totals(axis_totals):
    lines = []
    lines.append("| axis | layer | FDA-cell count | research-cell count |")
    lines.append("|:---|:---|:---|:---|")
    for a in ALL_AXES:
        t = axis_totals[a]
        lines.append(
            f"| {a} | {AXIS_LAYER[a]} | {t['fda']} | {t['research']} |"
        )
    return "\n".join(lines)


def _render_unplaced_notes(disease_meta, diseases_order):
    """Disease-level UNPLACED (CBER scope-disqualified) notes — these do
    NOT appear in any axis column by design (no fake CBER coverage).
    Reporting them at the disease level keeps the cohort honest."""
    rows = []
    for d in diseases_order:
        notes = disease_meta[d]["unplaced_notes"]
        if not notes:
            continue
        for n in notes:
            rows.append(f"- **{d}** — {n}")
    if not rows:
        return "_(no UNPLACED rows in the discovered cohort)_"
    return "\n".join(rows)


def _density_stats(grid, disease_meta, diseases_order):
    """Honest empty-cell discussion stats."""
    total = len(diseases_order) * len(ALL_AXES)
    fda_cells = 0
    research_cells = 0
    empty_cells = 0
    for d in diseases_order:
        for c in grid[d]:
            if c == CELL_EMPTY:
                empty_cells += 1
            elif c.startswith(CELL_FDA_PREFIX):
                fda_cells += 1
            elif c == CELL_RESEARCH:
                research_cells += 1
            else:
                # UNPLACED-on-axis (defensive); count as research-bucket
                research_cells += 1
    return {
        "total": total,
        "fda": fda_cells,
        "research": research_cells,
        "empty": empty_cells,
    }


# ── full markdown landscape document ────────────────────────────────────
HONESTY_HEADER = (
    "> **Status**: auto-generated by "
    "`case_studies/landscape/landscape_generator.py`. "
    "Hand-edits will be overwritten on the next run.\n>\n"
    "> **Scope** (g8 / f2 in-silico-only): this is a CROSS-TAB of the\n"
    "> case-study portfolio cohort currently on disk against the 24-axis\n"
    "> surface from `AXIS/HIERARCHY.tape`. It is a project-state REPORT,\n"
    "> NOT a portfolio recommendation, ranking, clinical, regulatory,\n"
    "> therapeutic, or efficacy claim. Each cell is read from a runner's\n"
    "> own witness JSON (g1); modalities are described by their own drug\n"
    "> precedent only (g3 / f1). The landscape is HONESTLY SPARSE — most\n"
    "> disease × axis cells are empty, and that is the truth. Not the\n"
    "> deferred 200-disease re-mapping (a multi-disease pilot only)."
)


def render_markdown(grid, disease_meta, axis_totals, diseases_order, stats):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    parts = []
    parts.append("# Modality landscape — case-study cross-tab\n")
    parts.append(HONESTY_HEADER + "\n")
    parts.append(f"_Generated: {ts}_\n")
    parts.append(
        f"_Diseases discovered: {len(diseases_order)} · axes (cols): "
        f"{len(ALL_AXES)} (5 core + 4 expansion-main + 15 sub)_\n"
    )

    # §0 honesty fence
    parts.append("## §0 Honest scope fence\n")
    parts.append(
        "This is a multi-disease pilot CROSS-TAB. The 200-disease re-mapping\n"
        "the `AXIS/HIERARCHY.tape` Log flags as deferred work remains\n"
        "deferred — these cells are read from the small cohort of\n"
        "case-study portfolios actually present in `case_studies/`. Every\n"
        "cell that holds an FDA drug name was read from the originating\n"
        "portfolio runner's own witness JSON (`in_scope_drugs[].drug` or\n"
        "`drug_name`). No drug is invented; no axis mapping is invented.\n"
        "The cell glyph legend is:\n\n"
        "- **`✓ <drug-name>`** — IN-SCOPE FDA-approved drug on this axis.\n"
        "- **`🔬 research`** — research-stage candidate listed on this axis\n"
        "  in a portfolio's `research_stage_negatives[]` (or a\n"
        "  clinical-stage drug in `in_scope_drugs[]` flagged\n"
        "  `fda_approval_status='clinical_stage'`).\n"
        "- **`⚠ UNPLACED`** — a CBER / CDRH scope-disqualified row from a\n"
        "  portfolio's `not_in_scope_drugs[]` (or a research-stage\n"
        "  negative with `fda_center_if_filed='CBER'/'CDRH'` and a null\n"
        "  `axis_in_repo`). These do NOT bind to a specific axis column\n"
        "  by design — listing them at the disease level keeps the\n"
        "  honesty discipline of criterion #4 (drug-only / CDER scope).\n"
        "- **`·`** — no candidate / not applicable (honest empty cell).\n"
    )

    # §1 the cross-tab
    parts.append("## §1 Cross-tab — diseases × axes\n")
    parts.append(_render_table(grid, diseases_order) + "\n")

    # §2 per-disease totals
    parts.append("## §2 Per-disease totals\n")
    parts.append(
        "`FDA in-scope` = number of FDA-approved drugs listed in this\n"
        "portfolio's `in_scope_drugs[]` (NOT distinct axes — a portfolio\n"
        "may map two drugs onto one axis, e.g. KRAS-G12C maps both\n"
        "sotorasib and adagrasib to COVALENT). `research-stage` =\n"
        "research-stage cells contributed by this portfolio.\n"
        "`UNPLACED (CBER/CDRH)` = disease-level honesty rows that do NOT\n"
        "bind to any axis column.\n\n"
    )
    parts.append(_render_per_disease_totals(disease_meta, diseases_order)
                 + "\n")

    # §3 per-axis totals
    parts.append("## §3 Per-axis totals\n")
    parts.append(
        "`FDA-cell count` = how many disease × axis cells in the cohort\n"
        "carry at least one FDA-approved drug on this axis. The vast\n"
        "majority of axes have zero — this is the truth (most\n"
        "disease × axis combinations have no FDA precedent in this\n"
        "small cohort, and the deferred 200-disease re-mapping is\n"
        "exactly what would change that).\n\n"
    )
    parts.append(_render_per_axis_totals(axis_totals) + "\n")

    # §4 honest empty-cell discussion + UNPLACED notes
    parts.append("## §4 Honest empty-cell discussion\n")
    parts.append(
        f"Cohort size: {stats['total']} cells "
        f"({len(diseases_order)} diseases × {len(ALL_AXES)} axes).\n\n"
        f"- **FDA-occupied cells**: {stats['fda']} "
        f"({(100.0 * stats['fda'] / stats['total']):.1f}% of cohort)\n"
        f"- **Research-stage cells**: {stats['research']} "
        f"({(100.0 * stats['research'] / stats['total']):.1f}% of cohort)\n"
        f"- **Honest empty `·` cells**: {stats['empty']} "
        f"({(100.0 * stats['empty'] / stats['total']):.1f}% of cohort)\n\n"
        "The empty-cell majority is **not a gap** — it is the honest state\n"
        "of the per-disease evidence base. A landscape that puts something\n"
        "into every cell would have to fabricate drug-precedent or\n"
        "research-precedent that does not actually exist. The empty `·`\n"
        "glyph is the truth-telling cell.\n\n"
        "Disease-level UNPLACED (CBER / CDRH) notes — these do NOT appear\n"
        "in any axis column by design (no fake CBER coverage of axes that\n"
        "are by-definition CDER-only):\n\n"
    )
    parts.append(_render_unplaced_notes(disease_meta, diseases_order)
                 + "\n")

    # §5 cross-link
    parts.append("## §5 Cross-links\n")
    parts.append(
        "- Per-disease writeups live under each portfolio's own README:\n"
    )
    for d in diseases_order:
        m = disease_meta[d]
        parts.append(
            f"  - **{d}** — `case_studies/{m['portfolio']}_portfolio/README.md`\n"
        )
    parts.append(
        "- Axis truth: `AXIS/HIERARCHY.tape` (core-5 in `AXIS.tape`,\n"
        "  expansion-main + sub-axes in `AXIS/HIERARCHY.tape`).\n"
        "- Reporter pattern echo: "
        "`selftest/portfolio_fitness_function.py`\n"
        "  (per-portfolio three-independent-metric reporter — same\n"
        "  honesty fence: REPORTER ≠ RANKER).\n"
        "- Governance: `AGENTS.tape` g1 / g3 / g7 / g8 / f1 /\n"
        "  f_lattice_fit / f2.\n"
    )
    return "\n".join(parts) + "\n"


# ── per-portfolio driver ────────────────────────────────────────────────
def process_portfolio(p):
    name = p["name"]
    out = run_runner(p["runner"])
    if not out["ran"]:
        return {
            "name": name, "verdict": SKIP, "witness": None,
            "reason": out["error"] or "runner did not execute",
        }
    if out["exit_code"] != 0:
        return {
            "name": name, "verdict": SKIP, "witness": None,
            "reason": (f"runner exited non-zero (code={out['exit_code']}) "
                       "— g7 skip-is-honest"),
        }
    witness = extract_witness_json(out["stdout"])
    if witness is None:
        return {
            "name": name, "verdict": FAIL, "witness": None,
            "reason": ("runner exited 0 but emitted no parseable witness "
                       "JSON containing schema_version + in_scope_drugs"),
        }
    return {"name": name, "verdict": PASS, "witness": witness, "reason": ""}


# ── main ────────────────────────────────────────────────────────────────
def main():
    print("landscape_generator — case-study modality cross-tab")
    print("  CROSS-TAB, not a ranking. The 24-axis surface is fixed from")
    print("  AXIS/HIERARCHY.tape (core-5 + expansion-main + sub-axes).")
    print("  governance: g1 · g3 · g7 · g8 · f1 · f_lattice_fit · f2\n")

    portfolios = discover_portfolios()
    if not portfolios:
        # g7 honest SKIP — no portfolios at all to cross-tab.
        print("  [SKIP] no '*_portfolio/*_portfolio_runner.py' found under "
              f"{os.path.relpath(CASE_STUDIES_DIR, REPO_ROOT)}/")
        print("         — g7 skip-is-honest (no portfolios != FAIL)\n")
        print("__LANDSCAPE_GENERATOR__ SKIP")
        return 0

    print(f"  discovered {len(portfolios)} portfolio runner(s): "
          + ", ".join(p["name"] for p in portfolios))
    print()

    rows = []
    n_pass = n_skip = n_fail = 0
    for p in portfolios:
        print(f"── running {p['name']}_portfolio_runner.py …")
        r = process_portfolio(p)
        if r["verdict"] == PASS:
            n_pass += 1
            w = r["witness"]
            in_scope = w.get("in_scope_drugs") or []
            rsn = w.get("research_stage_negatives") or []
            nis = w.get("not_in_scope_drugs") or []
            print(f"  [PASS] {r['name']}: in_scope={len(in_scope)}, "
                  f"research_stage={len(rsn)}, not_in_scope={len(nis)}")
        elif r["verdict"] == SKIP:
            n_skip += 1
            print(f"  [SKIP] {r['name']}: {r['reason']}")
        else:
            n_fail += 1
            print(f"  [FAIL] {r['name']}: {r['reason']}")
        rows.append(r)
    print()

    grid, disease_meta, axis_totals, diseases_order = build_grid(rows)
    stats = _density_stats(grid, disease_meta, diseases_order)

    md = render_markdown(grid, disease_meta, axis_totals, diseases_order,
                         stats)
    # Atomic-ish write: write to a tmp then replace.
    tmp = LANDSCAPE_MD + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(md)
    os.replace(tmp, LANDSCAPE_MD)
    print(f"  wrote {os.path.relpath(LANDSCAPE_MD, REPO_ROOT)} "
          f"({len(md)} bytes)\n")

    print("── summary " + "─" * 60)
    print(f"  cohort dimensions      : "
          f"{len(diseases_order)} diseases × {len(ALL_AXES)} axes "
          f"= {stats['total']} cells")
    print(f"  cells FDA              : {stats['fda']} "
          f"({(100.0 * stats['fda'] / stats['total']):.1f}%)")
    print(f"  cells research-stage   : {stats['research']} "
          f"({(100.0 * stats['research'] / stats['total']):.1f}%)")
    print(f"  cells honestly empty   : {stats['empty']} "
          f"({(100.0 * stats['empty'] / stats['total']):.1f}%)")
    print(f"  portfolio runners      : "
          f"{n_pass} PASS · {n_skip} SKIP · {n_fail} FAIL\n")

    print("  HONESTY: this is a CROSS-TAB, not a ranking. Most cells are")
    print("  honestly empty — the landscape is sparse, and that is the")
    print("  truth. UNPLACED rows (CBER/CDRH scope-disqualified) do NOT")
    print("  bind to any axis column (no fake CBER coverage). The deferred")
    print("  200-disease re-mapping remains DEFERRED.\n")

    # Sentinel logic mirrors portfolio_fitness_function.py:
    #   PASS iff at least one portfolio was discovered AND scored, AND
    #   no FAIL occurred. Pure SKIPs (no PASS at all) → SKIP.
    if n_fail > 0:
        print("__LANDSCAPE_GENERATOR__ FAIL")
        return 1
    if n_pass == 0:
        # discovered runners but every one was SKIP'd
        print("__LANDSCAPE_GENERATOR__ SKIP")
        return 0
    print("__LANDSCAPE_GENERATOR__ PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
