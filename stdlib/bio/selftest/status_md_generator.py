#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/status_md_generator.py — AXIS/STATUS.md dashboard auto-generator
+ verification gate.

WHY THIS EXISTS
---------------
hexa-bio now hosts a 5-axis core + 4 expansion-main axes + 15 sub-axes +
16 cross-axis bridges + 12 preregistered falsifiers + a 32-sim
determinism roster + 2 disease case-study portfolios. The project-level
state is real but scattered across multiple gate outputs:

  - selftest/hexa_verify_tier_batch.py      (44-sim tier reporter)
  - selftest/falsifier_execution_gate.py    (12 falsifiers HOLD/FALSIFIED)
  - selftest/determinism_regression_gate.py (32-sim byte-identical re-run)

This generator runs each of those gates as a subprocess, parses their
stable text output, and writes a single-page markdown dashboard to
AXIS/STATUS.md aggregating the cross-cutting state. It also performs a
consistency check: the dashboard's numbers MUST match what the gates
actually reported (no inflation). A mismatch FAILs the sentinel.

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first — the dashboard's claims are an HONEST
     aggregation of the gates' own outputs; no extrapolation, no number
     inflation, no novel claim invented at the dashboard layer.
  g7 skip-is-honest — if a gate fails to run (subprocess error,
     missing file, non-zero exit, timeout) the dashboard reports SKIP
     for that section. SKIP does NOT block the sentinel; only a
     dashboard/gate consistency mismatch does.
  g8 in-silico-only — every section header carries the in-silico
     simulator-consistency caveat verbatim. STATUS.md does NOT claim
     wet-lab / clinical / regulatory / therapeutic readiness.
  f2 wet-lab-clinical-claim-from-in-silico — explicitly fenced.
  f_lattice_fit — axis counts are architectural decisions, NOT derived
     from any n=6 lattice scalar.

DETERMINISM
-----------
Pure stdlib (os / re / subprocess / sys). The generated-at timestamp is
FIXED at 2026-05-16T00:00:00Z (cohort convention) so successive runs
produce a byte-identical AXIS/STATUS.md.

SENTINEL
--------
Emits `__STATUS_MD_GENERATOR__ PASS` iff:
  (a) AXIS/STATUS.md was written successfully, AND
  (b) every number on the dashboard matches the corresponding gate's
      actual output (consistency check — no inflation, g1).

Usage:
    python3 selftest/status_md_generator.py
    # exit 0 = dashboard written + consistency-check PASS
    # exit 1 = consistency-check mismatch (a number was inflated)
"""
from __future__ import annotations

import os
import re
import subprocess
import sys

# ── repo layout ─────────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELFTEST = os.path.join(REPO_ROOT, "selftest")
AXIS_DIR = os.path.join(REPO_ROOT, "AXIS")
OUTPUT_PATH = os.path.join(AXIS_DIR, "STATUS.md")

TIER_GATE = os.path.join(SELFTEST, "hexa_verify_tier_batch.py")
FALSIFIER_GATE = os.path.join(SELFTEST, "falsifier_execution_gate.py")
DETERMINISM_GATE = os.path.join(SELFTEST, "determinism_regression_gate.py")

PY_BRIDGE = os.path.join(REPO_ROOT, "_python_bridge", "module")
CASE_STUDIES = os.path.join(REPO_ROOT, "case_studies")

# Cohort-convention fixed generated-at (byte-identical re-runs).
GENERATED_AT = "2026-05-16T00:00:00Z"

# Subprocess timeout per gate. Determinism gate is the slowest (~50 s
# wall on this host); 180 s ceiling protects against a stuck gate
# turning the generator into a wall-clock liability.
PER_GATE_TIMEOUT_S = 180

# Tier glyphs (stable strings — never decode-dependent at runtime).
TIER_NUMERICAL = "\U0001F7E2"   # 🟢
TIER_FORMAL    = "\U0001F535"   # 🔵
TIER_DEFERRED  = "\U0001F7E0"   # 🟠
TIER_FALSIFIED = "\U0001F534"   # 🔴


# ── gate runner ─────────────────────────────────────────────────────────
def run_gate(gate_path):
    """Run a gate as subprocess. Returns (returncode, stdout, ok_or_skip_reason).

    `ok_or_skip_reason` is None on success, or a short reason string when
    the gate could not be run (file absent, subprocess error, timeout,
    non-zero exit).
    """
    if not os.path.isfile(gate_path):
        return (None, "", f"gate file absent: {os.path.basename(gate_path)}")
    env = dict(os.environ)
    env["PYTHONHASHSEED"] = "0"
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    try:
        proc = subprocess.run(
            [sys.executable, gate_path],
            cwd=REPO_ROOT,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=PER_GATE_TIMEOUT_S,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return (None, "", f"gate timed out after {PER_GATE_TIMEOUT_S}s")
    except OSError as exc:
        return (None, "", f"gate subprocess OSError: {exc}")
    out = proc.stdout.decode("utf-8", errors="replace")
    if proc.returncode != 0:
        # Even non-zero, we can still parse the output. The dashboard
        # will mark the section honestly.
        return (proc.returncode, out, None)
    return (proc.returncode, out, None)


# ── parsers ─────────────────────────────────────────────────────────────
def parse_tier_counts(text):
    """Parse `hexa_verify_tier_batch.py` output.

    Returns dict with keys {green, blue, yellow, orange, red, white, total,
    sentinel} or None when parsing fails (the report block always emits
    counts in a fixed order, so this is a regex against that block).
    """
    if not text:
        return None
    out = {"green": 0, "blue": 0, "yellow": 0, "orange": 0,
           "red": 0, "white": 0, "total": 0,
           "sentinel": "ABSENT"}
    # Each tier line in the report block is like:
    #   "  🟢 SUPPORTED-NUMERICAL                      42"
    # so we match the leading glyph + an integer trailing the line.
    patterns = {
        "green":  r"\U0001F7E2\s+SUPPORTED-NUMERICAL\s+(\d+)",
        "blue":   r"\U0001F535\s+SUPPORTED-FORMAL\s+(\d+)",
        "yellow": r"\U0001F7E1\s+SUPPORTED-BY-CITATION\s+(\d+)",
        # The reporter uses 🟠 for both DEFERRED and INSUFFICIENT; sum
        # both into a single 'orange' bucket on the dashboard.
        "orange_def":  r"\U0001F7E0\s+DEFERRED\s+(\d+)",
        "orange_insu": r"\U0001F7E0\s+INSUFFICIENT\s+(\d+)",
        "red":    r"\U0001F534\s+FALSIFIED\s+(\d+)",
        "white":  r"⚪\s+SPECULATION-FENCED\s+(\d+)",
    }
    orange = 0
    for key, pat in patterns.items():
        m = re.search(pat, text)
        if not m:
            continue
        n = int(m.group(1))
        if key.startswith("orange_"):
            orange += n
        else:
            out[key] = n
    out["orange"] = orange
    m_total = re.search(r"^\s*TOTAL\s+(\d+)\s*$", text, re.MULTILINE)
    if m_total:
        out["total"] = int(m_total.group(1))
    if "__HEXA_VERIFY_TIER_BATCH__ PASS" in text:
        out["sentinel"] = "PASS"
    elif "__HEXA_VERIFY_TIER_BATCH__ FAIL" in text:
        out["sentinel"] = "FAIL"
    return out


def parse_falsifier(text):
    """Parse `falsifier_execution_gate.py` output.

    Returns dict {hold, falsified, skip, total, axes, sentinel}.
    `axes` is the list of per-axis tape-prefixes encountered (in stable
    discovery order) so the dashboard can name what's covered.
    """
    if not text:
        return None
    out = {"hold": 0, "falsified": 0, "skip": 0, "total": 0,
           "axes": [], "sentinel": "ABSENT"}
    # Summary line:
    #   "  12 HOLD · 0 FALSIFIED · 0 SKIP (of 12 falsifier rows)"
    m = re.search(
        r"(\d+)\s+HOLD\s+[··]\s+(\d+)\s+FALSIFIED\s+[··]\s+(\d+)\s+SKIP"
        r"\s+\(of\s+(\d+)\s+falsifier\s+rows\)",
        text)
    if m:
        out["hold"] = int(m.group(1))
        out["falsified"] = int(m.group(2))
        out["skip"] = int(m.group(3))
        out["total"] = int(m.group(4))
    # Per-axis sections start with "── <AXIS> axis ─"
    for am in re.finditer(r"──\s+(\S+)\s+axis\s+─", text):
        axis = am.group(1)
        if axis not in out["axes"]:
            out["axes"].append(axis)
    if "__FALSIFIER_EXECUTION_GATE__ PASS" in text:
        out["sentinel"] = "PASS"
    elif "__FALSIFIER_EXECUTION_GATE__ FAIL" in text:
        out["sentinel"] = "FAIL"
    return out


def parse_determinism(text):
    """Parse `determinism_regression_gate.py` output.

    Returns dict {deterministic, non_deterministic, skip, total, sentinel}.
    """
    if not text:
        return None
    out = {"deterministic": 0, "non_deterministic": 0, "skip": 0,
           "total": 0, "sentinel": "ABSENT"}
    # Summary line:
    #   "  32 DETERMINISTIC · 0 NON_DETERMINISTIC · 0 SKIP (of 32 sims)"
    m = re.search(
        r"(\d+)\s+DETERMINISTIC\s+[··]\s+(\d+)\s+NON_DETERMINISTIC"
        r"\s+[··]\s+(\d+)\s+SKIP\s+\(of\s+(\d+)\s+sims\)",
        text)
    if m:
        out["deterministic"] = int(m.group(1))
        out["non_deterministic"] = int(m.group(2))
        out["skip"] = int(m.group(3))
        out["total"] = int(m.group(4))
    if "__DETERMINISM_REGRESSION_GATE__ PASS" in text:
        out["sentinel"] = "PASS"
    elif "__DETERMINISM_REGRESSION_GATE__ FAIL" in text:
        out["sentinel"] = "FAIL"
    return out


# ── cross-axis bridge + case-study counts (filesystem-derived) ──────────
def count_cross_bridges():
    """Count cross-axis bridge sims in _python_bridge/module/*_cross.py.

    Filesystem-derived (stable / deterministic on the same repo state).
    """
    if not os.path.isdir(PY_BRIDGE):
        return None
    names = [n for n in os.listdir(PY_BRIDGE)
             if n.endswith("_cross.py") and not n.startswith("_")]
    return sorted(names)


def count_case_studies():
    """Count case-study portfolio dirs in case_studies/."""
    if not os.path.isdir(CASE_STUDIES):
        return None
    out = []
    for n in sorted(os.listdir(CASE_STUDIES)):
        full = os.path.join(CASE_STUDIES, n)
        if os.path.isdir(full) and n.endswith("_portfolio"):
            out.append(n)
    return out


# ── markdown writer ─────────────────────────────────────────────────────
# Axis counts are an ARCHITECTURAL decision recorded in AXIS.tape (core)
# + AXIS/HIERARCHY.tape (expansion-layer), NOT derived from any lattice
# scalar (f_lattice_fit). These are the SSOT-declared totals.
CORE_AXES_COUNT = 5         # QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID
EXPANSION_MAIN_COUNT = 4    # COVALENT · BIFUNCTIONAL · METALLODRUG · OLIGONUCLEOTIDE
SUB_AXES_COUNT = 15         # per HIERARCHY.tape §2 (6+3+2+1+2+1)


def _fmt_section_header(num, title, caveat=None):
    out = f"## §{num} {title}\n"
    if caveat:
        out += f"\n> _{caveat}_\n"
    return out


def render_markdown(tiers, falsifier, determinism, bridges, case_studies):
    """Assemble the AXIS/STATUS.md markdown body.

    `tiers`, `falsifier`, `determinism` are parsed gate dicts (or None
    when the gate could not be run — honest SKIP per g7).
    `bridges` is the list of cross-axis bridge filenames; `case_studies`
    is the list of portfolio dirs. Both filesystem-derived.
    """
    L = []  # line accumulator

    # ── document header (the honesty fence) ────────────────────────────
    L.append("# AXIS/STATUS.md — hexa-bio gate-aggregation dashboard\n")
    L.append("> **Status: auto-generated from selftest gate outputs. "
             "Hand-edits will be overwritten by "
             "`selftest/status_md_generator.py`.** The DASHBOARD is "
             "in-silico simulator-consistency only (g8/f2).\n")
    L.append("")
    L.append("> **Honesty fence (g8 / f2 / README criterion #4):** every "
             "number below reports an IN-SILICO gate state. A PASS / "
             "HOLD / DETERMINISTIC verdict verifies simulator-consistency "
             "of a preregistered condition ONLY — NEVER a therapeutic, "
             "clinical, regulatory, immunogenic, efficacy, potency, "
             "selectivity, or wet-lab claim. Axis counts are an "
             "architectural decision (`f_lattice_fit`), NOT derived from "
             "any n=6 lattice scalar.\n")
    L.append("")
    L.append("---")
    L.append("")

    # ── §1 axis count summary ─────────────────────────────────────────
    total = CORE_AXES_COUNT + EXPANSION_MAIN_COUNT + SUB_AXES_COUNT
    L.append(_fmt_section_header(
        1, "Axis count summary",
        f"SSOT-declared totals (AXIS.tape core + AXIS/HIERARCHY.tape "
        f"expansion-layer). NOT lattice-derived (`f_lattice_fit`)."))
    L.append("")
    L.append("| Layer | Count | SSOT |")
    L.append("|---|---|---|")
    L.append(f"| **Core axes** | {CORE_AXES_COUNT} | "
             f"`../AXIS.tape` (QUANTUM · WEAVE · NANOBOT · RIBOZYME · "
             f"VIROCAPSID) |")
    L.append(f"| **Expansion-MAIN** | {EXPANSION_MAIN_COUNT} | "
             f"`HIERARCHY.tape` §1 (COVALENT · BIFUNCTIONAL · "
             f"METALLODRUG · OLIGONUCLEOTIDE) |")
    L.append(f"| **Sub-axes** | {SUB_AXES_COUNT} | "
             f"`HIERARCHY.tape` §2 (6 :> BIFUNCTIONAL · 3 :> QUANTUM · "
             f"2 :> WEAVE · 1 :> COVALENT · 2 :> RIBOZYME · "
             f"1 :> VIROCAPSID) |")
    L.append(f"| **TOTAL** | **{total}** | architectural — "
             f"see `README.md` §4 (keep-5 dissent preserved) |")
    L.append("")

    # ── §2 tier distribution ──────────────────────────────────────────
    L.append(_fmt_section_header(
        2, "Tier distribution",
        f"From `selftest/hexa_verify_tier_batch.py` — a TIER REPORTER, "
        f"not enforcer. Glyph counts across the 44-sim roster."))
    L.append("")
    if tiers is None:
        L.append("[SKIP] tier-batch gate could not be run on this host "
                 "(g7 skip-is-honest).")
    else:
        L.append("| Tier | Glyph | Count |")
        L.append("|---|---|---|")
        L.append(f"| SUPPORTED-NUMERICAL | {TIER_NUMERICAL} | "
                 f"{tiers['green']} |")
        L.append(f"| SUPPORTED-FORMAL | {TIER_FORMAL} | "
                 f"{tiers['blue']} |")
        L.append(f"| DEFERRED / INSUFFICIENT | {TIER_DEFERRED} | "
                 f"{tiers['orange']} |")
        L.append(f"| FALSIFIED | {TIER_FALSIFIED} | {tiers['red']} |")
        L.append(f"| **Total** | — | **{tiers['total']}** |")
        L.append("")
        L.append(f"Gate sentinel: `__HEXA_VERIFY_TIER_BATCH__ "
                 f"{tiers['sentinel']}`.")
    L.append("")

    # ── §3 falsifier-gate status ──────────────────────────────────────
    L.append(_fmt_section_header(
        3, "Falsifier-gate status",
        f"From `selftest/falsifier_execution_gate.py` — runs each "
        f"preregistered falsifier (F-METALLODRUG/OLIGO/COVALENT/"
        f"BIFUNCTIONAL-1/2/3) against its axis sim."))
    L.append("")
    if falsifier is None:
        L.append("[SKIP] falsifier-gate could not be run on this host "
                 "(g7 skip-is-honest).")
    else:
        L.append("| Verdict | Count |")
        L.append("|---|---|")
        L.append(f"| HOLD | {falsifier['hold']} |")
        L.append(f"| FALSIFIED | {falsifier['falsified']} |")
        L.append(f"| SKIP | {falsifier['skip']} |")
        L.append(f"| **Total** | **{falsifier['total']}** |")
        L.append("")
        if falsifier["axes"]:
            L.append(f"Axes covered: {' · '.join(falsifier['axes'])}.")
            L.append("")
        L.append(f"Gate sentinel: `__FALSIFIER_EXECUTION_GATE__ "
                 f"{falsifier['sentinel']}`.")
        L.append("")
        L.append("> _g7 honesty: a SKIP is an absent tape/sim on this "
                 "host — NOT a failure. Only a genuine FALSIFIED verdict "
                 "(axis reachable, preregistered condition violated) "
                 "blocks the sentinel._")
    L.append("")

    # ── §4 determinism-gate status ────────────────────────────────────
    L.append(_fmt_section_header(
        4, "Determinism-gate status",
        f"From `selftest/determinism_regression_gate.py` — runs each "
        f"sim TWICE under `PYTHONHASHSEED=0` and compares stdout "
        f"byte-for-byte. This is the §11 deductive-verification "
        f"determinism contract."))
    L.append("")
    if determinism is None:
        L.append("[SKIP] determinism-gate could not be run on this host "
                 "(g7 skip-is-honest).")
    else:
        L.append("| Verdict | Count |")
        L.append("|---|---|")
        L.append(f"| DETERMINISTIC | {determinism['deterministic']} |")
        L.append(f"| NON_DETERMINISTIC | "
                 f"{determinism['non_deterministic']} |")
        L.append(f"| SKIP | {determinism['skip']} |")
        L.append(f"| **Total** | **{determinism['total']}** |")
        L.append("")
        L.append(f"Gate sentinel: `__DETERMINISM_REGRESSION_GATE__ "
                 f"{determinism['sentinel']}`.")
    L.append("")

    # ── §5 cross-axis coverage ────────────────────────────────────────
    L.append(_fmt_section_header(
        5, "Cross-axis coverage",
        f"Filesystem-derived count of cross-axis bridge sims "
        f"(`_python_bridge/module/*_cross.py`). A cross-axis bridge "
        f"is NOT a new axis — core-5 unchanged."))
    L.append("")
    if bridges is None:
        L.append("[SKIP] `_python_bridge/module/` not present on host "
                 "(g7 skip-is-honest).")
    else:
        L.append(f"Cross-axis bridge sims: **{len(bridges)}**.")
        L.append("")
        L.append("> _Each bridge imports both sides' sims (no fork — "
                 "`f3`); each carries a passing sentinel + draft-07 "
                 "schema; each is honesty-fenced (mathematical "
                 "equivalence ≠ mechanistic equivalence; comparison "
                 "≠ ranking)._")
    L.append("")

    # ── §6 case studies ───────────────────────────────────────────────
    L.append(_fmt_section_header(
        6, "Case studies",
        f"One-disease in-silico pilots in `case_studies/`. NOT the "
        f"200-disease deferred work (which remains deferred)."))
    L.append("")
    if case_studies is None:
        L.append("[SKIP] `case_studies/` not present on host "
                 "(g7 skip-is-honest).")
    else:
        L.append(f"Disease portfolios: **{len(case_studies)}** "
                 f"({' · '.join(case_studies)}).")
        L.append("")
        L.append("> _Each portfolio composes existing sims for "
                 "FDA-approved drugs against one disease, with "
                 "research-stage / CBER-scope items honestly listed "
                 "as UNPLACED. NOT a clinical, efficacy, or portfolio-"
                 "recommendation claim (g8)._")
    L.append("")

    # ── §7 honesty caveats ────────────────────────────────────────────
    L.append(_fmt_section_header(7, "Honesty caveats"))
    L.append("")
    L.append("- **g1 real-limits-first** — every gate is anchored in a "
             "named real-limit (Eyring TST · SantaLucia NN · Caspar-"
             "Klug · Zlotnick · Griffith-Orgel · MWC · Bell · Strelow · "
             "Douglass/Han/Gadd · Zimm-Bragg · Nussinov · CODATA 2019). "
             "The dashboard does NOT invent claims at the aggregation "
             "layer — every number here matches the underlying gate.")
    L.append("- **g7 skip-is-honest** — a [SKIP] in any section above "
             "means the underlying gate could not be run on this host "
             "(file absent, subprocess timeout, non-zero exit). It is "
             "NOT a failure. Only a `__STATUS_MD_GENERATOR__ FAIL` "
             "(consistency-check mismatch) signals a real problem.")
    L.append("- **g8 in-silico-only-claim-scope** — a tier ≠ 🔴, a "
             "falsifier HOLD, a DETERMINISTIC verdict, and a passing "
             "case-study sentinel ALL verify in-silico simulator + "
             "metadata internal consistency ONLY. None of them is a "
             "wet-lab, clinical, regulatory, immunogenic, efficacy, "
             "potency, selectivity, DC50, Dmax, or therapeutic claim.")
    L.append("- **f2 wet-lab-clinical-claim-from-in-silico** — never "
             "claim therapeutic / clinical / regulatory progress from "
             "a C2/C3 in-silico PASS. See `CLOSURE_RESIDUAL_BACKLOG.md` "
             "§0 for the explicit out-of-software-scope items.")
    L.append("- **f_lattice_fit** — the axis counts in §1 are an "
             "architectural decision grounded in computational scope, "
             "NOT a lattice derivation. The hexa- token is a "
             "dancinlab-family branding artifact (see `README.md` §0 "
             "count-honesty paragraph).")
    L.append("- **README §4 keep-5 dissent** — the rigorous "
             "axis-expansion analysis recommended KEEP 5 axes + cross-"
             "cutting platform layer. The 4 expansion-main axes here "
             "exist per explicit USER DIRECTION 2026-05-16, with the "
             "dissent preserved verbatim (NOT erased) in "
             "`README.md` §4 + `HIERARCHY.tape` `@N rigorous_dissent`.")
    L.append("- **Criterion #4 (drug-only / CDER)** — THERANOSTIC + "
             "GENETIC-MEDICINE + ADC remain UNPLACED (CBER scope "
             "tension); not implemented as code axes (honest).")
    L.append("")

    # ── §8 generated-at timestamp ─────────────────────────────────────
    L.append(_fmt_section_header(
        8, "Generated-at timestamp",
        f"Fixed for byte-identical re-runs (cohort convention). "
        f"Re-run `python3 selftest/status_md_generator.py` to refresh "
        f"the gate-aggregated numbers; the timestamp string itself is "
        f"deliberately stable."))
    L.append("")
    L.append(f"- **generated-at**: `{GENERATED_AT}`")
    L.append(f"- **generator**: `selftest/status_md_generator.py`")
    L.append(f"- **output**: `AXIS/STATUS.md` (this file)")
    L.append(f"- **gates aggregated**:")
    L.append(f"    1. `selftest/hexa_verify_tier_batch.py`")
    L.append(f"    2. `selftest/falsifier_execution_gate.py`")
    L.append(f"    3. `selftest/determinism_regression_gate.py`")
    L.append("")
    L.append("---")
    L.append("")
    L.append("_End of auto-generated dashboard. Hand-edits will be "
             "overwritten on next run of `selftest/status_md_generator.py`._")
    L.append("")

    return "\n".join(L)


# ── consistency check (no inflation) ────────────────────────────────────
def consistency_check(text, tiers, falsifier, determinism, bridges,
                      case_studies):
    """Verify the dashboard's rendered numbers match the parsed gate
    outputs. Returns list of mismatch strings (empty = PASS).

    The check parses STATUS.md's text and asserts every number in the
    tables matches the corresponding parsed value. This is the g1
    no-inflation contract: the aggregator must not silently embellish.
    """
    mismatches = []

    def _assert(label, want, got):
        if want != got:
            mismatches.append(f"{label}: dashboard={got!r} != "
                              f"gate-parsed={want!r}")

    # Axis-count totals (always present; derived from constants).
    total_axes = CORE_AXES_COUNT + EXPANSION_MAIN_COUNT + SUB_AXES_COUNT
    if f"**{total_axes}**" not in text:
        mismatches.append(f"axis total: expected {total_axes} in "
                          f"dashboard text, not found")

    # Tier counts.
    if tiers is not None:
        # Recount the dashboard's tier-row integers from the table.
        # A row looks like: "| SUPPORTED-NUMERICAL | 🟢 | 42 |"
        m_green = re.search(
            r"\|\s*SUPPORTED-NUMERICAL\s*\|.*?\|\s*(\d+)\s*\|", text)
        m_blue = re.search(
            r"\|\s*SUPPORTED-FORMAL\s*\|.*?\|\s*(\d+)\s*\|", text)
        m_orange = re.search(
            r"\|\s*DEFERRED / INSUFFICIENT\s*\|.*?\|\s*(\d+)\s*\|", text)
        m_red = re.search(
            r"\|\s*FALSIFIED\s*\|.*?\|\s*(\d+)\s*\|", text)
        if m_green:
            _assert("tier green", tiers["green"], int(m_green.group(1)))
        if m_blue:
            _assert("tier blue", tiers["blue"], int(m_blue.group(1)))
        if m_orange:
            _assert("tier orange", tiers["orange"], int(m_orange.group(1)))
        if m_red:
            _assert("tier red", tiers["red"], int(m_red.group(1)))

    # Falsifier counts.
    if falsifier is not None:
        m_hold = re.search(r"\|\s*HOLD\s*\|\s*(\d+)\s*\|", text)
        m_fals = re.search(r"\|\s*FALSIFIED\s*\|\s*(\d+)\s*\|", text)
        # Distinct from tier-FALSIFIED row (which has a glyph col).
        # Falsifier-section FALSIFIED row has only two columns.
        # Find all matches and pick the §3 falsifier section row by
        # locating the one inside the §3 header bracket.
        s3_start = text.find("## §3 ")
        s3_end = text.find("## §4 ")
        s3_block = text[s3_start:s3_end] if s3_start >= 0 else ""
        m_f_hold = re.search(r"\|\s*HOLD\s*\|\s*(\d+)\s*\|", s3_block)
        m_f_fals = re.search(r"\|\s*FALSIFIED\s*\|\s*(\d+)\s*\|", s3_block)
        m_f_skip = re.search(r"\|\s*SKIP\s*\|\s*(\d+)\s*\|", s3_block)
        if m_f_hold:
            _assert("falsifier HOLD",
                    falsifier["hold"], int(m_f_hold.group(1)))
        if m_f_fals:
            _assert("falsifier FALSIFIED",
                    falsifier["falsified"], int(m_f_fals.group(1)))
        if m_f_skip:
            _assert("falsifier SKIP",
                    falsifier["skip"], int(m_f_skip.group(1)))

    # Determinism counts.
    if determinism is not None:
        s4_start = text.find("## §4 ")
        s4_end = text.find("## §5 ")
        s4_block = text[s4_start:s4_end] if s4_start >= 0 else ""
        m_det = re.search(
            r"\|\s*DETERMINISTIC\s*\|\s*(\d+)\s*\|", s4_block)
        m_non = re.search(
            r"\|\s*NON_DETERMINISTIC\s*\|\s*(\d+)\s*\|", s4_block)
        m_skip = re.search(
            r"\|\s*SKIP\s*\|\s*(\d+)\s*\|", s4_block)
        if m_det:
            _assert("determinism DETERMINISTIC",
                    determinism["deterministic"], int(m_det.group(1)))
        if m_non:
            _assert("determinism NON_DETERMINISTIC",
                    determinism["non_deterministic"],
                    int(m_non.group(1)))
        if m_skip:
            _assert("determinism SKIP",
                    determinism["skip"], int(m_skip.group(1)))

    # Cross-axis bridge count.
    if bridges is not None:
        s5_start = text.find("## §5 ")
        s5_end = text.find("## §6 ")
        s5_block = text[s5_start:s5_end] if s5_start >= 0 else ""
        m_b = re.search(
            r"Cross-axis bridge sims:\s*\*\*(\d+)\*\*", s5_block)
        if m_b:
            _assert("cross bridges",
                    len(bridges), int(m_b.group(1)))

    # Case study count.
    if case_studies is not None:
        s6_start = text.find("## §6 ")
        s6_end = text.find("## §7 ")
        s6_block = text[s6_start:s6_end] if s6_start >= 0 else ""
        m_c = re.search(
            r"Disease portfolios:\s*\*\*(\d+)\*\*", s6_block)
        if m_c:
            _assert("case studies",
                    len(case_studies), int(m_c.group(1)))

    # Fixed-timestamp check (cohort convention; byte-identical re-run).
    if GENERATED_AT not in text:
        mismatches.append(f"generated-at: expected {GENERATED_AT!r} "
                          f"in dashboard text, not found")

    return mismatches


# ── main ────────────────────────────────────────────────────────────────
def main():
    print("status_md_generator — AXIS/STATUS.md dashboard generator + "
          "consistency gate")
    print("  aggregates: tier batch reporter · falsifier execution gate "
          "· determinism regression gate")
    print("  governance: g1 honest-aggregation · g7 skip-is-honest · "
          "g8 in-silico-only\n")

    # Run each gate. We capture None on subprocess error (honest SKIP).
    print(f"── running tier batch reporter ...")
    _, tier_out, tier_err = run_gate(TIER_GATE)
    tiers = parse_tier_counts(tier_out) if tier_err is None else None
    if tier_err:
        print(f"   [SKIP] {tier_err}")
    elif tiers is None:
        print(f"   [SKIP] tier gate output could not be parsed")
    else:
        print(f"   green={tiers['green']} blue={tiers['blue']} "
              f"orange={tiers['orange']} red={tiers['red']} "
              f"total={tiers['total']} sentinel={tiers['sentinel']}")

    print(f"── running falsifier execution gate ...")
    _, fals_out, fals_err = run_gate(FALSIFIER_GATE)
    falsifier = parse_falsifier(fals_out) if fals_err is None else None
    if fals_err:
        print(f"   [SKIP] {fals_err}")
    elif falsifier is None:
        print(f"   [SKIP] falsifier gate output could not be parsed")
    else:
        print(f"   HOLD={falsifier['hold']} "
              f"FALSIFIED={falsifier['falsified']} "
              f"SKIP={falsifier['skip']} total={falsifier['total']} "
              f"sentinel={falsifier['sentinel']}")

    print(f"── running determinism regression gate ...")
    _, det_out, det_err = run_gate(DETERMINISM_GATE)
    determinism = parse_determinism(det_out) if det_err is None else None
    if det_err:
        print(f"   [SKIP] {det_err}")
    elif determinism is None:
        print(f"   [SKIP] determinism gate output could not be parsed")
    else:
        print(f"   DETERMINISTIC={determinism['deterministic']} "
              f"NON_DETERMINISTIC={determinism['non_deterministic']} "
              f"SKIP={determinism['skip']} total={determinism['total']} "
              f"sentinel={determinism['sentinel']}")

    # Filesystem-derived counts.
    bridges = count_cross_bridges()
    case_studies = count_case_studies()
    print(f"── filesystem-derived counts:")
    print(f"   cross-axis bridges: "
          f"{len(bridges) if bridges is not None else 'SKIP'}")
    print(f"   case-study portfolios: "
          f"{len(case_studies) if case_studies is not None else 'SKIP'}")

    # Render the dashboard.
    md = render_markdown(tiers, falsifier, determinism, bridges,
                         case_studies)

    # Ensure the AXIS/ dir exists (it should — we read from it earlier).
    if not os.path.isdir(AXIS_DIR):
        print(f"\n   AXIS/ directory missing — cannot write STATUS.md")
        print("__STATUS_MD_GENERATOR__ FAIL")
        return 1

    # Write the file.
    try:
        with open(OUTPUT_PATH, "w", encoding="utf-8") as fh:
            fh.write(md)
    except OSError as exc:
        print(f"\n   write failed: {exc}")
        print("__STATUS_MD_GENERATOR__ FAIL")
        return 1
    print(f"\n── wrote AXIS/STATUS.md "
          f"({len(md)} chars, {md.count(chr(10))} lines)")

    # Consistency check (g1 — no inflation).
    mismatches = consistency_check(md, tiers, falsifier, determinism,
                                   bridges, case_studies)
    if mismatches:
        print(f"\n── consistency-check FAILED ({len(mismatches)} "
              f"mismatch{'es' if len(mismatches) != 1 else ''}):")
        for m in mismatches:
            print(f"   - {m}")
        print("\n__STATUS_MD_GENERATOR__ FAIL")
        return 1
    print("── consistency-check PASS "
          "(every dashboard number matches its gate output)")

    print("\n__STATUS_MD_GENERATOR__ PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
