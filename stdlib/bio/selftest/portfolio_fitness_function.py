#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/portfolio_fitness_function.py — portfolio FITNESS REPORTER for the
hexa-bio case-study portfolios (case_studies/<name>_portfolio/).

WHAT THIS IS
------------
A deterministic, stdlib-only REPORTER that scores each case-study portfolio
along THREE INDEPENDENT axes — separately, never combined:

  (1) drug_existence_score   — count of FDA-approved IN-SCOPE drugs the
                                portfolio actually maps onto an in-repo axis
                                (i.e. len(in_scope_drugs)).
  (2) axis_coverage_score    — count of DISTINCT in-repo axes used by those
                                in-scope drugs (e.g. CAPSID-ASSEMBLY-MODULATOR
                                + ALLOSTERIC = 2). Each portfolio's own
                                schema-shape is honoured: the HIV-1 schema
                                nests the axis under `axis_mapping.axis`; the
                                SMA schema exposes a flat `axis` field. Both
                                shapes are read.
  (3) honesty_completeness_score — count of NEGATIVES explicitly recorded:
                                   research-stage entries (HIV-1 schema's
                                   `research_stage_negatives`) AND honestly-
                                   UNPLACED entries (SMA schema's
                                   `not_in_scope_drugs` with `axis=null`).

REPORTER ≠ RANKER
-----------------
This gate is a REPORTER + DIAGNOSTIC, NEVER a ranker. It does NOT:
  * compute a compound / weighted / aggregate score,
  * declare any portfolio "best" / "winner" / "superior",
  * compare portfolios to each other,
  * recommend one portfolio over another.

A portfolio with 1 IN-SCOPE drug + 5 honest negatives is MORE HONEST than one
with 3 IN-SCOPE drugs + 0 negatives. The output is structured per-portfolio
rows; no cross-portfolio judgement is rendered.

This is the SAME pattern that already governs comparable cross modules in the
repo: `_python_bridge/module/peptide_macrocycle_cross.py` (G4) emits the
schema const `comparison_is_ranking=false` and the SMA portfolio's witness
emits `not_an_efficacy_ranking=true`. Both fence the comparison off from any
ranking interpretation; this gate echoes the same fence at the portfolio
fitness layer.

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first — the three metrics are HONEST counts on each
     portfolio's own data structure. They do not invent a synthetic
     "fitness" scalar; they do not derive anything from the n=6 lattice.
  g3 honesty-obligation-external — no winner is declared; the report
     fences the comparison off from ranking in plain text.
  g7 skip-is-honest — SKIP if no portfolios exist; SKIP a runner that fails
     to execute (timeout / non-zero exit / malformed JSON), continue with
     the rest; the gate's overall PASS depends only on portfolios that
     DID run cleanly.
  g8 in-silico-only — counts characterize the portfolios' in-silico shapes
     ONLY; they are NOT therapeutic / clinical / regulatory / efficacy
     claims, and they are NOT a portfolio recommendation.

DETERMINISM
-----------
Pure stdlib. Per-runner subprocess timeout 30 s. Discovery is sorted; runner
output is parsed by a stdlib JSON-object scanner that pulls the first
balanced top-level object containing `schema_version` and `in_scope_drugs`.

Usage:
    python3 selftest/portfolio_fitness_function.py
    # exit 0 = every discovered runner exited 0 and parsed cleanly
    #           (or honest SKIP — no portfolios discovered)
    # exit 1 = at least one runner exited 0 but emitted unparseable output
    #          (a hard contract break, distinct from runner non-zero exit
    #           which is honest SKIP per g7)
"""
from __future__ import annotations

import json
import os
import subprocess
import sys

# ── repo layout ─────────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CASE_STUDIES_DIR = os.path.join(REPO_ROOT, "case_studies")

# Per-runner subprocess timeout (seconds). All known runners are pure
# stdlib + import two existing sims; 30 s is generous.
RUNNER_TIMEOUT_S = 30

# verdict tokens
PASS = "PASS"
SKIP = "SKIP"
FAIL = "FAIL"


# ── discovery ────────────────────────────────────────────────────────────
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
        # convention: <name>_portfolio/<name>_portfolio_runner.py
        # where <name> is the prefix before the "_portfolio" suffix.
        name = entry[: -len("_portfolio")]
        runner = os.path.join(sub, f"{name}_portfolio_runner.py")
        if not os.path.isfile(runner):
            continue
        found.append({"name": name, "dir": sub, "runner": runner})
    return found


# ── runner execution ─────────────────────────────────────────────────────
def run_runner(runner_path):
    """Execute a portfolio runner under a 30-s timeout.

    Returns a dict {ran, exit_code, stdout, stderr, error}. `ran` is True iff
    the runner executed (regardless of exit code); `error` describes a
    timeout / OSError / Python-not-found-style failure.
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
            "ran": False,
            "exit_code": None,
            "stdout": "",
            "stderr": "",
            "error": f"timeout after {RUNNER_TIMEOUT_S} s",
        }
    except OSError as exc:
        return {
            "ran": False,
            "exit_code": None,
            "stdout": "",
            "stderr": "",
            "error": f"OSError: {exc}",
        }
    return {
        "ran": True,
        "exit_code": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
        "error": None,
    }


# ── witness JSON extraction ──────────────────────────────────────────────
def extract_witness_json(stdout):
    """Pull the witness JSON object out of a runner's stdout.

    Both known runners (HIV-1, SMA) print their witness JSON to stdout
    interleaved with header / acceptance text. The witness is a single
    balanced JSON OBJECT containing at minimum `schema_version` and
    `in_scope_drugs`. Strategy: scan for every `{` candidate, attempt a
    balanced-brace slice + json.loads, return the first slice that loads
    AND contains both required keys. Returns the parsed dict or None.

    This is stdlib-only and tolerates the runners' surrounding prose
    without requiring a sentinel-delimited fence — neither runner emits
    such a fence today.
    """
    if not isinstance(stdout, str) or "{" not in stdout:
        return None
    n = len(stdout)
    i = 0
    while i < n:
        if stdout[i] != "{":
            i += 1
            continue
        # walk forward, balancing braces while respecting quoted strings.
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
                        # not the witness — advance past this `{` and keep
                        # scanning for the next outer object.
                        break
            j += 1
        i += 1
    return None


# ── scoring (three INDEPENDENT axes — no compound score) ─────────────────
def score_witness(witness):
    """Compute the three independent fitness metrics on a parsed witness.

    Returns a dict:
      drug_existence_score        int  — # in_scope_drugs
      axis_coverage_score         int  — # distinct axes mapped by those drugs
      honesty_completeness_score  int  — # explicit negatives recorded
      axes                        list — sorted distinct axes (for the report)
      negatives_breakdown         dict — per-source counts (which field
                                          contributed which count)

    The metrics are NEVER combined into a compound score.
    """
    in_scope = witness.get("in_scope_drugs") or []
    if not isinstance(in_scope, list):
        in_scope = []

    # (1) drug_existence_score = len(in_scope_drugs)
    drug_existence_score = len(in_scope)

    # (2) axis_coverage_score = # distinct axes mapped by in_scope_drugs.
    # Handle both schema shapes seen in case_studies/:
    #   HIV-1 schema → drug["axis_mapping"]["axis"]
    #   SMA   schema → drug["axis"]
    axes = []
    for d in in_scope:
        if not isinstance(d, dict):
            continue
        axis = None
        am = d.get("axis_mapping")
        if isinstance(am, dict) and isinstance(am.get("axis"), str) \
                and am["axis"].strip():
            axis = am["axis"].strip()
        elif isinstance(d.get("axis"), str) and d["axis"].strip():
            axis = d["axis"].strip()
        if axis:
            axes.append(axis)
    distinct_axes = sorted(set(axes))
    axis_coverage_score = len(distinct_axes)

    # (3) honesty_completeness_score = # negatives explicitly recorded.
    # Two schema-distinct slots seen in case_studies/:
    #   HIV-1 → research_stage_negatives[]    (research-stage modalities)
    #   SMA   → not_in_scope_drugs[]          (axis=null UNPLACED rows)
    # Both are HONEST negatives — count them together.
    rsn = witness.get("research_stage_negatives") or []
    nis = witness.get("not_in_scope_drugs") or []
    if not isinstance(rsn, list):
        rsn = []
    if not isinstance(nis, list):
        nis = []
    honesty_completeness_score = len(rsn) + len(nis)

    return {
        "drug_existence_score": drug_existence_score,
        "axis_coverage_score": axis_coverage_score,
        "honesty_completeness_score": honesty_completeness_score,
        "axes": distinct_axes,
        "negatives_breakdown": {
            "research_stage_negatives": len(rsn),
            "not_in_scope_drugs_unplaced": len(nis),
        },
    }


# ── honesty notes extraction ─────────────────────────────────────────────
def collect_honesty_notes(witness):
    """Pull out the textual honesty notes — UNPLACED reasons + research-
    stage reasons — for the report. Returns a list of {kind, label, note}
    rows. Descriptive only; never a score.
    """
    notes = []
    for n in witness.get("research_stage_negatives") or []:
        if not isinstance(n, dict):
            continue
        label = str(n.get("candidate_class") or "research-stage").strip()
        reason = str(n.get("reason") or "").strip()
        status = str(n.get("status") or "").strip()
        notes.append({
            "kind": "research_stage",
            "label": label,
            "status": status,
            "note": reason,
        })
    for n in witness.get("not_in_scope_drugs") or []:
        if not isinstance(n, dict):
            continue
        label = str(n.get("drug_name") or n.get("brand") or "UNPLACED").strip()
        reason = str(n.get("reason") or "").strip()
        center = str(n.get("fda_center") or "").strip()
        notes.append({
            "kind": "unplaced",
            "label": label,
            "fda_center": center,
            "note": reason,
        })
    return notes


# ── per-portfolio driver ─────────────────────────────────────────────────
def process_portfolio(p):
    """Execute one portfolio runner; parse + score its witness.

    Returns a dict that always carries the portfolio name + verdict
    (PASS / SKIP / FAIL). On PASS the scoring fields are populated; on
    SKIP/FAIL the `reason` field explains why.
    """
    name = p["name"]
    runner_rel = os.path.relpath(p["runner"], REPO_ROOT)
    out = run_runner(p["runner"])

    if not out["ran"]:
        return {
            "name": name,
            "runner": runner_rel,
            "verdict": SKIP,
            "reason": (out["error"] or "runner did not execute"),
        }
    if out["exit_code"] != 0:
        return {
            "name": name,
            "runner": runner_rel,
            "verdict": SKIP,
            "reason": (f"runner exited non-zero (code={out['exit_code']}) "
                       "— g7 skip-is-honest, do not block sentinel"),
            "exit_code": out["exit_code"],
        }

    witness = extract_witness_json(out["stdout"])
    if witness is None:
        # ran clean (exit 0) but no parseable witness JSON found — this IS
        # a hard contract break (the runner promised a witness, did not
        # emit one), so this counts as a genuine FAIL of the gate, not a
        # SKIP. (g7 SKIP is reserved for "runner unreachable / runner
        # itself failed"; here the runner ran fine.)
        return {
            "name": name,
            "runner": runner_rel,
            "verdict": FAIL,
            "reason": ("runner exited 0 but emitted no parseable witness "
                       "JSON containing schema_version + in_scope_drugs"),
        }

    metrics = score_witness(witness)
    honesty_notes = collect_honesty_notes(witness)
    disease = witness.get("disease") or {}
    if isinstance(disease, dict):
        disease_label = (disease.get("abbreviation")
                         or disease.get("name") or "—")
    else:
        disease_label = "—"

    return {
        "name": name,
        "runner": runner_rel,
        "verdict": PASS,
        "schema_version": witness.get("schema_version"),
        "case_study_id": witness.get("case_study_id"),
        "disease": disease_label,
        "metrics": metrics,
        "honesty_notes": honesty_notes,
        "runner_sentinel": str(witness.get("sentinel") or "").strip(),
    }


# ── reporting ────────────────────────────────────────────────────────────
def _fmt_int(v):
    """Right-justify a small int into a 3-wide cell, "—" when N/A."""
    if isinstance(v, int):
        return f"{v:>3d}"
    return "  —"


def print_per_portfolio_table(rows):
    """Print the per-portfolio table — three independent metric columns +
    a disease + a verdict column. Stable column widths; no aggregate."""
    header = ("portfolio", "disease", "drug_existence",
              "axis_coverage", "honesty_completeness", "verdict")
    name_w = max(len(header[0]), max((len(r["name"]) for r in rows), default=0))
    name_w = max(name_w, 12)
    dis_w = max(len(header[1]),
                max((len(str(r.get("disease", "—"))) for r in rows), default=0))
    dis_w = max(dis_w, 8)

    print("── per-portfolio fitness table " + "─" * 30)
    print(
        f"  {header[0]:<{name_w}}  {header[1]:<{dis_w}}  "
        f"{header[2]:>14}  {header[3]:>13}  {header[4]:>20}  "
        f"{header[5]:>7}"
    )
    print(
        f"  {'-' * name_w}  {'-' * dis_w}  "
        f"{'-' * 14}  {'-' * 13}  {'-' * 20}  {'-' * 7}"
    )
    for r in rows:
        m = r.get("metrics") or {}
        de = m.get("drug_existence_score")
        ac = m.get("axis_coverage_score")
        hc = m.get("honesty_completeness_score")
        disease = str(r.get("disease", "—"))
        print(
            f"  {r['name']:<{name_w}}  {disease:<{dis_w}}  "
            f"{_fmt_int(de):>14}  {_fmt_int(ac):>13}  "
            f"{_fmt_int(hc):>20}  {r['verdict']:>7}"
        )
    print()


def print_axes_and_notes(rows):
    """Per-portfolio: the distinct axes counted + the honesty notes
    (UNPLACED + research-stage). Descriptive — never ranked."""
    print("── per-portfolio detail (axes + honesty notes) " + "─" * 16)
    for r in rows:
        print(f"  ▸ {r['name']}  [{r['verdict']}]")
        if r["verdict"] != PASS:
            reason = r.get("reason", "")
            print(f"      reason: {reason}")
            print()
            continue
        m = r.get("metrics") or {}
        axes = m.get("axes") or []
        nb = m.get("negatives_breakdown") or {}
        print(f"      runner sentinel    : {r.get('runner_sentinel', '')}")
        print(f"      schema_version     : {r.get('schema_version', '')}")
        if axes:
            print(f"      distinct axes ({len(axes)}): "
                  + ", ".join(axes))
        else:
            print("      distinct axes (0): —")
        print(
            f"      negatives by source: "
            f"research_stage_negatives={nb.get('research_stage_negatives', 0)}, "
            f"not_in_scope_drugs_unplaced="
            f"{nb.get('not_in_scope_drugs_unplaced', 0)}"
        )
        notes = r.get("honesty_notes") or []
        if notes:
            print("      honesty notes:")
            for nt in notes:
                kind = nt.get("kind", "?")
                label = nt.get("label", "—")
                if kind == "research_stage":
                    status = nt.get("status", "")
                    print(f"        - [research-stage] {label}"
                          + (f"  ({status})" if status else ""))
                elif kind == "unplaced":
                    center = nt.get("fda_center", "")
                    print(f"        - [UNPLACED] {label}"
                          + (f"  ({center})" if center else ""))
                else:
                    print(f"        - [{kind}] {label}")
                note_txt = nt.get("note", "")
                if note_txt:
                    # one-line wrap for readability — no truncation of meaning
                    print(f"            {note_txt}")
        else:
            print("      honesty notes: (none recorded)")
        print()


# ── main ─────────────────────────────────────────────────────────────────
def main():
    print("portfolio_fitness_function — hexa-bio case-study portfolios")
    print("  REPORTER + DIAGNOSTIC — never a ranker. The three metrics")
    print("  (drug_existence · axis_coverage · honesty_completeness) are")
    print("  reported PER PORTFOLIO and ARE NOT combined into a compound")
    print("  score. No portfolio is declared 'best'. comparison_is_ranking")
    print("  = false (same fence pattern as the G4 PEPTIDE×MACROCYCLE")
    print("  cross). A portfolio with 1 in-scope drug + 5 honest negatives")
    print("  may be MORE HONEST than one with 3 in-scope drugs + 0")
    print("  negatives — honesty is not a ranking dimension.")
    print("  governance: g1 real-limits-first · g3 honesty-external ·")
    print("              g7 skip-is-honest · g8 in-silico-only\n")

    portfolios = discover_portfolios()
    if not portfolios:
        # honest SKIP (g7): no case-study portfolios discovered.
        print(f"  [SKIP] no '*_portfolio/*_portfolio_runner.py' found under "
              f"{os.path.relpath(CASE_STUDIES_DIR, REPO_ROOT)}/")
        print("         — g7 skip-is-honest (no portfolios != FAIL)\n")
        print("__PORTFOLIO_FITNESS_FUNCTION__ PASS")
        return 0

    print(f"  discovered {len(portfolios)} portfolio runner(s): "
          + ", ".join(p["name"] for p in portfolios))
    print()

    rows = []
    for p in portfolios:
        print(f"── running {p['name']}_portfolio_runner.py …")
        r = process_portfolio(p)
        tag = {PASS: "PASS", SKIP: "SKIP", FAIL: "FAIL"}[r["verdict"]]
        if r["verdict"] == PASS:
            m = r["metrics"]
            print(f"  [{tag}] {r['name']}: "
                  f"drug_existence={m['drug_existence_score']}, "
                  f"axis_coverage={m['axis_coverage_score']}, "
                  f"honesty_completeness={m['honesty_completeness_score']}")
        else:
            print(f"  [{tag}] {r['name']}: {r.get('reason', '')}")
        rows.append(r)
    print()

    print_per_portfolio_table(rows)
    print_axes_and_notes(rows)

    # tally
    n_pass = sum(1 for r in rows if r["verdict"] == PASS)
    n_skip = sum(1 for r in rows if r["verdict"] == SKIP)
    n_fail = sum(1 for r in rows if r["verdict"] == FAIL)

    print("── summary " + "─" * 60)
    for r in rows:
        m = r.get("metrics") or {}
        if r["verdict"] == PASS:
            print(f"  {r['verdict']:<6} {r['name']:<20} "
                  f"de={_fmt_int(m.get('drug_existence_score'))}  "
                  f"ac={_fmt_int(m.get('axis_coverage_score'))}  "
                  f"hc={_fmt_int(m.get('honesty_completeness_score'))}")
        else:
            print(f"  {r['verdict']:<6} {r['name']:<20} "
                  f"({r.get('reason', '')})")
    print(f"\n  {n_pass} PASS · {n_skip} SKIP · {n_fail} FAIL  "
          f"(of {len(rows)} portfolio(s))")

    # honesty fences (printed every run — never let the table imply ranking)
    print()
    print("  HONESTY (reporter ≠ ranker): comparison_is_ranking = false.")
    print("  The three metrics are INDEPENDENT axes — there is no compound")
    print("  score and no 'best portfolio'. A portfolio with fewer in-scope")
    print("  drugs but more honestly-recorded negatives is NOT 'worse' —")
    print("  honesty_completeness rewards explicit acknowledgement of what")
    print("  the portfolio does NOT model (research-stage modalities; CBER /")
    print("  UNPLACED rows). This is a feature, not a gap (same pattern as")
    print("  the SMA portfolio's `not_an_efficacy_ranking=true` and the G4")
    print("  PEPTIDE × MACROCYCLE cross's `comparison_is_ranking=false`).")
    print("  HONESTY (g7): a SKIP is an absent runner / a runner that itself")
    print("  exited non-zero on this host — it does NOT block the sentinel.")
    print("  HONESTY (g8 in-silico-only): the metrics characterize each")
    print("  portfolio's in-silico shape ONLY — they are NOT therapeutic,")
    print("  clinical, regulatory, efficacy, or portfolio-recommendation")
    print("  claims, and they are NOT derived from the n=6 lattice.\n")

    # sentinel: PASS iff every discovered runner that we considered for
    # scoring exited 0 AND its witness parsed. SKIPs do NOT block.
    ok = n_fail == 0
    if ok:
        print("__PORTFOLIO_FITNESS_FUNCTION__ PASS")
        return 0
    print("__PORTFOLIO_FITNESS_FUNCTION__ FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
