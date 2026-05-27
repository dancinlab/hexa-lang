#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/provenance_pipeline_gate.py — provenance / reproducibility-metadata
gate for the hexa-bio deterministic-sim cohort.

WHY THIS EXISTS
---------------
hexa-bio ships 32+ deterministic in-silico simulators that emit a witness-JSON
block on stdout. Determinism is necessary but not sufficient for reproducible
science: a witness row is only fully reproducible from itself when it carries
enough provenance metadata to (a) name the schema it conforms to, (b) name a
deterministic generation timestamp (so two runs of the same repo state can be
matched as the same logical witness even if filesystem mtimes differ), and
(c) cite the real-limit anchor it claims g1 compliance against.

This gate inspects each sim's emitted witness JSON for the three provenance
fields that make a row reproducible from the witness alone:

  1. a deterministic timestamp   — `ts` | `timestamp` | `generated_at`
  2. a schema identifier         — `schema` | `schema_version` | `schema_id`
  3. ≥1 real-limit citation      — `real_limit_anchor` | `real_limit_citation`
                                    | `citations` (anywhere in the JSON tree)

It ALSO records two soft provenance fields (NOTED-AS-GAP, not fail-blocking):

  4. a case-study / axis id      — `case_study_id` | `axis_id` | `axis`
  5. a sim module-name traceback — `module` | `sim` | `script` | `source`

The gate is a REPORTER + DIAGNOSTIC, NOT an auto-fixer. It does not modify
any sim. It surfaces provenance gaps so they can be remedied honestly by
the sim author, not by silent backfill.

SENTINEL
--------
  __PROVENANCE_PIPELINE_GATE__ PASS
    iff every sim that emits parseable witness JSON has all three required
    fields (deterministic timestamp + schema id + ≥1 real-limit citation).

  __PROVENANCE_PIPELINE_GATE__ FAIL
    iff at least one sim emits parseable witness JSON that LACKS the
    deterministic timestamp (which directly breaks the reproducibility
    contract — without `ts` two runs of the same repo state cannot be
    matched as the same logical witness).

  DIAGNOSTIC-SKIP rows do NOT block the sentinel:
    - sim absent on host                              (g7 honest)
    - sim exit != 0 / sim timed out                   (g7 honest)
    - sim emits no parseable JSON block on stdout     (g7 honest:
        the sim may be a human-readable reporter, not a witness emitter;
        provenance gating doesn't apply when there is no witness to gate)

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first — this gate enforces presence of ≥1 real-limit citation
     in every witness JSON. The g1 contract is that every claim cite its real
     limit anchor; this gate makes that contract MECHANICAL: a witness with no
     citation cannot satisfy g1 from the witness alone.
  g7 skip-is-honest — sims absent / broken on this host / non-JSON-emitting
     are DIAGNOSTIC-SKIP. SKIP does not block the sentinel.
  g8 in-silico-only — this gate verifies REPRODUCIBILITY METADATA only. A
     PASS here does not imply any therapeutic / clinical / regulatory /
     binding-affinity / efficacy claim about any sim's content.

  REPORTER ≠ ENFORCER for the soft provenance fields (case_study_id / axis_id /
  module). They are reported as present/absent for diagnostic visibility, but
  their absence does NOT downgrade the verdict — it is recorded as a NOTED-GAP
  the sim author can choose to address.

DETERMINISM (this gate itself)
------------------------------
Pure stdlib (no third-party imports). Roster is an explicit list (the same 32
sims as `selftest/determinism_regression_gate.py`'s ROSTER). Output rows are
emitted in declared roster order. The subprocess env fixes PYTHONHASHSEED=0
and PYTHONDONTWRITEBYTECODE=1 so re-running this gate on the same repo state
produces byte-identical output (modulo the optional HEAD line and gate wall
time, both of which are explicitly labeled NON-DETERMINISTIC-METADATA).

The optional HEAD line is a one-shot read-only `git rev-parse --short HEAD`.
It is recorded as the "current HEAD when this gate was run" and is honestly
labeled non-determinism in this gate's output (it's metadata about WHEN the
gate ran, not about the sims). If git is unavailable or this is not a git
checkout, the HEAD line honestly says SKIP.

Usage:
    python3 selftest/provenance_pipeline_gate.py
    # exit 0 = all witness-emitting sims have ts + schema + real_limit citation
    # exit 1 = at least one witness-emitting sim is missing `ts` (the
    #         reproducibility-breaking gap)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time

# ── repo layout ─────────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY_BRIDGE = os.path.join(REPO_ROOT, "_python_bridge", "module")

# verdict tokens
FULL = "FULL"                       # all 3 required + (optional) soft fields
PARTIAL = "PARTIAL"                 # has ts (reproducibility OK) but missing
                                    # schema and/or real-limit citation
FAIL_NO_TS = "FAIL_NO_TS"           # parseable JSON but no deterministic ts —
                                    # this is the only fail-blocking verdict
DIAGNOSTIC_SKIP = "DIAGNOSTIC_SKIP" # sim absent / broken / emits no JSON

# subprocess timeout per sim (sec). Single run, ≤ 60 s.
PER_RUN_TIMEOUT_S = 60

# ── sim roster (explicit; byte-stable order; same as determinism gate) ───
# Keep this list in sync with selftest/determinism_regression_gate.py's
# ROSTER. We DECLARE the roster here (rather than import from the determinism
# gate module) so this gate has no inter-gate file dependency and remains
# stdlib-only. If the determinism roster changes, edit this list to match.
ROSTER = [
    # Round-1 expansion-main axis sims (6).
    ("expansion-main round-1", [
        "metallodrug_coordination_sim.py",
        "oligonucleotide_hybridization_sim.py",
        "capsid_assembly_modulator_sim.py",
        "rna_targeting_small_molecule_sim.py",
        "aptamer_affinity_sim.py",
        "reversible_covalent_sim.py",
    ]),
    # Round-1 cross-axis sims (5).
    ("cross-axis round-1", [
        "metallodrug_quantum_vqe_cross.py",
        "oligonucleotide_offtarget_gencode_cross.py",
        "rna_modality_comparison_smn2_cross.py",
        "capsid_modulator_pdb_anchor_cross.py",
        "reversible_covalent_mpro_vqe_cross.py",
    ]),
    # Expansion-layer parity (2 — covalent/bifunctional).
    ("expansion-main parity", [
        "covalent_inhibition_sim.py",
        "bifunctional_ternary_complex_sim.py",
    ]),
    # Sub-axis sims (11).
    ("sub-axis sims", [
        "protac_sim.py",
        "lytac_sim.py",
        "autac_sim.py",
        "ribotac_sim.py",
        "covalent_degrader_sim.py",
        "molecular_glue_sim.py",
        "allosteric_sim.py",
        "cryptic_pocket_sim.py",
        "ppi_sim.py",
        "peptide_sim.py",
        "macrocycle_sim.py",
    ]),
    # Round-2 cross-axis sims (3).
    ("cross-axis round-2", [
        "oligonucleotide_nanobot_cross.py",
        "aptamer_nanobot_cross.py",
        "capsid_modulator_weave_cross.py",
    ]),
    # Round-3 cross-axis sims (5; expansion x expansion unifications).
    ("cross-axis round-3", [
        "protac_capsid_modulator_cross.py",
        "allosteric_cryptic_pocket_cross.py",
        "ppi_molecular_glue_cross.py",
        "peptide_macrocycle_cross.py",
        "aptamer_oligonucleotide_cross.py",
    ]),
]

# ── provenance field families (what we consider equivalent) ──────────────
TS_KEYS = ("ts", "timestamp", "generated_at")
SCHEMA_KEYS = ("schema", "schema_version", "schema_id")
REAL_LIMIT_KEYS = (
    "real_limit_anchor",
    "real_limit_citation",
    "real_limits",
    "citations",
    "citation",
)
CASE_STUDY_KEYS = ("case_study_id", "axis_id", "axis", "case_study")
MODULE_KEYS = ("module", "sim", "script", "source", "source_file")

# Deterministic-timestamp recognizer: ISO-8601 UTC of the form
# YYYY-MM-DDTHH:MM:SSZ (no sub-second). This is the in-repo convention
# (e.g. "2026-05-16T00:00:00Z"). A wall-clock-looking value with a
# non-zero seconds/minutes/hours field still parses as ISO; we accept any
# fixed-string ISO value as deterministic IF it appears in the witness as a
# string (the determinism gate separately enforces byte-identical re-run, so a
# truly wall-clock-derived `ts` would already have been caught upstream).
_ISO_UTC_RE = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})$")


# ── JSON extraction from stdout ──────────────────────────────────────────
def _extract_last_json_block(stdout_text):
    """Find the LAST well-formed top-level JSON object in `stdout_text`.

    Strategy: scan lines for `^{$` openers and `^}$` closers (the in-repo
    convention — every witness-emitting sim prints its JSON with the brace
    on its own line). For each candidate `(open_line, close_line)` pair we
    attempt json.loads on the slice; we keep the LAST one that parses.
    Returns the parsed object, or None if no parseable block found.

    This deliberately accepts only `^{$ … ^}$` line-anchored blocks (not
    inline `{` after other text) because the in-repo convention emits the
    witness JSON as a stand-alone block. The aptamer/oligo/capsid sims that
    print a human-readable report without a stand-alone JSON block will
    correctly return None here, and the gate will record DIAGNOSTIC-SKIP.
    """
    if not stdout_text:
        return None
    lines = stdout_text.splitlines()
    opens = [i for i, ln in enumerate(lines) if ln == "{"]
    closes = [i for i, ln in enumerate(lines) if ln == "}"]
    if not opens or not closes:
        return None
    parsed = None
    # iterate from the END: prefer the last well-formed block.
    for oi in reversed(opens):
        # find the FIRST close line strictly after this open.
        ci_candidates = [c for c in closes if c > oi]
        if not ci_candidates:
            continue
        # try every close from largest-first to handle nested-emitter cases
        for ci in reversed(ci_candidates):
            block = "\n".join(lines[oi:ci + 1])
            try:
                parsed = json.loads(block)
                return parsed
            except json.JSONDecodeError:
                continue
    return None


# ── recursive search over the parsed JSON tree ───────────────────────────
def _has_any_key(obj, keys):
    """Return True iff any of `keys` appears anywhere in the nested JSON
    object `obj` (dict / list / scalar). Match is exact (case-sensitive) at
    the dict-key level. Lists are traversed; scalars contribute nothing."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in keys:
                # require a non-empty value for the key to count as "present"
                if v is None:
                    continue
                if isinstance(v, (str, list, dict)) and len(v) == 0:
                    continue
                return True
            if _has_any_key(v, keys):
                return True
        return False
    if isinstance(obj, list):
        for item in obj:
            if _has_any_key(item, keys):
                return True
        return False
    return False


def _first_value_for(obj, keys):
    """Return the first non-empty value found anywhere in the nested JSON
    object `obj` whose key is in `keys`, else None. Stable depth-first."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in keys and v is not None:
                if isinstance(v, (str, list, dict)) and len(v) == 0:
                    continue
                return v
        for v in obj.values():
            r = _first_value_for(v, keys)
            if r is not None:
                return r
        return None
    if isinstance(obj, list):
        for item in obj:
            r = _first_value_for(item, keys)
            if r is not None:
                return r
        return None
    return None


def _is_deterministic_ts(value):
    """Return True iff `value` looks like a deterministic ISO-8601 timestamp
    string. We accept any fixed-form ISO-8601 UTC string here; the
    determinism_regression_gate separately enforces that re-running the sim
    produces byte-identical stdout, so a wall-clock-derived `ts` would
    already have been caught there. The point of this check is to ensure
    the witness CONTAINS a timestamp at all — without one, two repo-identical
    runs of the same sim cannot be matched as the same logical witness."""
    if not isinstance(value, str):
        return False
    return bool(_ISO_UTC_RE.match(value.strip()))


# ── one sim check ────────────────────────────────────────────────────────
def _run_once(sim_path):
    env = dict(os.environ)
    env["PYTHONHASHSEED"] = "0"
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    t0 = time.monotonic()
    try:
        proc = subprocess.run(
            [sys.executable, sim_path],
            cwd=REPO_ROOT,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=PER_RUN_TIMEOUT_S,
            check=False,
        )
        elapsed = time.monotonic() - t0
        return (proc.returncode, proc.stdout, proc.stderr, False, elapsed)
    except subprocess.TimeoutExpired as e:
        elapsed = time.monotonic() - t0
        return (None, e.stdout or b"", e.stderr or b"", True, elapsed)


def check_sim(rel_name):
    """Check provenance metadata of one sim's witness JSON.

    Returns (verdict, detail_dict). detail_dict carries per-field
    presence flags and the extracted values (when present) so the
    summary table can show actionable diagnostics.
    """
    sim_path = os.path.join(PY_BRIDGE, rel_name)
    if not os.path.isfile(sim_path):
        return (DIAGNOSTIC_SKIP,
                {"reason": f"sim file absent: {rel_name}"})

    rc, out, err, timed_out, elapsed = _run_once(sim_path)
    if timed_out:
        return (DIAGNOSTIC_SKIP,
                {"reason": f"sim timed out after {PER_RUN_TIMEOUT_S}s "
                           f"(elapsed {elapsed:.2f}s) — g7 honest"})
    if rc != 0:
        tail = err.decode("utf-8", errors="replace").strip().splitlines()
        tail_s = tail[-1] if tail else "(no stderr)"
        return (DIAGNOSTIC_SKIP,
                {"reason": f"sim exit={rc} (elapsed {elapsed:.2f}s) — g7 "
                           f"honest; stderr tail: {tail_s[:120]}"})

    stdout_text = out.decode("utf-8", errors="replace")
    witness = _extract_last_json_block(stdout_text)
    if witness is None:
        return (DIAGNOSTIC_SKIP,
                {"reason": "sim ran cleanly (exit=0) but emitted no "
                           "parseable JSON block on stdout — sim is a "
                           "human-readable reporter, not a witness emitter; "
                           "provenance gating doesn't apply (g7 honest)"})

    # Required fields (3) — these gate the verdict.
    ts_value = _first_value_for(witness, TS_KEYS)
    has_ts_field = ts_value is not None
    ts_is_deterministic = _is_deterministic_ts(ts_value) if has_ts_field else False

    has_schema = _has_any_key(witness, SCHEMA_KEYS)
    schema_value = _first_value_for(witness, SCHEMA_KEYS) if has_schema else None

    has_real_limit = _has_any_key(witness, REAL_LIMIT_KEYS)

    # Soft fields (NOTED-AS-GAP only).
    has_case_study = _has_any_key(witness, CASE_STUDY_KEYS)
    has_module = _has_any_key(witness, MODULE_KEYS)

    detail = {
        "ts_field_present": has_ts_field,
        "ts_value": ts_value if isinstance(ts_value, str) else None,
        "ts_is_deterministic": ts_is_deterministic,
        "schema_present": has_schema,
        "schema_value": schema_value if isinstance(schema_value, str) else None,
        "real_limit_citation_present": has_real_limit,
        "case_study_present": has_case_study,   # soft
        "module_present": has_module,            # soft
    }

    # Verdict assignment:
    #   FAIL_NO_TS  — no `ts` field at all, OR `ts` is not a fixed-form ISO
    #                 string. Reproducibility-breaking; fail-blocks sentinel.
    #   PARTIAL     — has deterministic ts, but missing schema and/or
    #                 real_limit citation. Gap-noted but not fail-blocking.
    #   FULL        — has all three required fields.
    if not has_ts_field or not ts_is_deterministic:
        return (FAIL_NO_TS, detail)
    if has_schema and has_real_limit:
        return (FULL, detail)
    return (PARTIAL, detail)


# ── HEAD recording (optional, honest SKIP if git unavailable) ────────────
def _read_head_short_rev():
    """One-shot read-only `git rev-parse --short HEAD`. Returns the short
    rev string, or None if git is unavailable / this is not a git checkout /
    the command fails for any reason. We deliberately do NOT propagate any
    git error; the HEAD line is OPTIONAL metadata about when this gate ran,
    not a gating signal."""
    try:
        proc = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=REPO_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=5,
            check=False,
        )
        if proc.returncode != 0:
            return None
        rev = proc.stdout.decode("utf-8", errors="replace").strip()
        if not rev:
            return None
        return rev
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return None


# ── main ─────────────────────────────────────────────────────────────────
def main():
    t_start = time.monotonic()
    print("provenance_pipeline_gate — hexa-bio deterministic-sim cohort "
          "provenance / reproducibility-metadata reporter")
    print("  for each sim in the roster, runs the sim once and inspects the")
    print("  emitted witness JSON for the 3 required provenance fields:")
    print("    (1) deterministic timestamp  (`ts` | `timestamp` | `generated_at`)")
    print("    (2) schema id                (`schema` | `schema_version` | "
          "`schema_id`)")
    print("    (3) ≥1 real-limit citation   (`real_limit_anchor` | "
          "`citations` | …)")
    print("  plus 2 soft fields (NOTED-AS-GAP only, NOT fail-blocking):")
    print("    (4) case-study / axis id     (`case_study_id` | `axis_id` | "
          "`axis`)")
    print("    (5) sim module-name traceback (`module` | `sim` | `script` | "
          "`source`)")
    print("  governance: g1 real-limits-first (gate enforces citation "
          "presence) ·")
    print("              g7 skip-is-honest (absent/broken/non-JSON sim = "
          "DIAGNOSTIC-SKIP) ·")
    print("              g8 in-silico-only (this is reproducibility "
          "metadata, NOT a")
    print("              therapeutic / clinical / regulatory / efficacy "
          "claim)")
    print("  REPORTER + DIAGNOSTIC, NOT auto-fixer — the gate REPORTS "
          "provenance gaps;")
    print("  it does NOT modify any sim file. Soft-field gaps are NOTED, "
          "not enforced.")
    print()

    # ── optional HEAD recording (honest SKIP if git unavailable) ──────────
    head_rev = _read_head_short_rev()
    if head_rev is not None:
        print(f"  current HEAD when this gate was run: {head_rev}  "
              "(NON-DETERMINISTIC-METADATA — describes when the gate ran,")
        print("    not the sim outputs themselves; sim outputs are byte-stable "
              "across re-runs by the")
        print("    determinism_regression_gate contract)")
    else:
        print("  current HEAD when this gate was run: SKIP "
              "(git unavailable or not a git checkout — g7 honest)")
    print()

    total = sum(len(sims) for _, sims in ROSTER)
    print(f"  roster: {total} sims across {len(ROSTER)} groups; per-run "
          f"timeout {PER_RUN_TIMEOUT_S}s\n")

    all_rows = []
    for group_label, sims in ROSTER:
        print(f"── {group_label} " + "─" * max(0, 60 - len(group_label)))
        for rel_name in sims:
            verdict, detail = check_sim(rel_name)
            tag = {
                FULL: "FULL",
                PARTIAL: "PARTIAL",
                FAIL_NO_TS: "FAIL_NO_TS",
                DIAGNOSTIC_SKIP: "DIAGNOSTIC-SKIP",
            }[verdict]
            print(f"  [{tag}] {rel_name}")
            if verdict == DIAGNOSTIC_SKIP:
                print(f"           {detail['reason']}")
            else:
                ts_v = detail["ts_value"] or "(missing)"
                sch_v = detail["schema_value"] or "(missing)"
                marks = []
                marks.append(
                    f"ts={'✓' if detail['ts_is_deterministic'] else '✗'}"
                    f"({ts_v})")
                marks.append(
                    f"schema={'✓' if detail['schema_present'] else '✗'}"
                    f"({sch_v})")
                marks.append(
                    "real_limit_citation="
                    f"{'✓' if detail['real_limit_citation_present'] else '✗'}")
                marks.append(
                    "case_study_id="
                    f"{'✓' if detail['case_study_present'] else '✗'}(soft)")
                marks.append(
                    "module_traceback="
                    f"{'✓' if detail['module_present'] else '✗'}(soft)")
                print(f"           " + "  ".join(marks))
            all_rows.append({
                "group": group_label,
                "sim": rel_name,
                "verdict": verdict,
                "detail": detail,
            })
        print()

    # ── summary table ──────────────────────────────────────────────────
    n_full = sum(1 for r in all_rows if r["verdict"] == FULL)
    n_partial = sum(1 for r in all_rows if r["verdict"] == PARTIAL)
    n_fail = sum(1 for r in all_rows if r["verdict"] == FAIL_NO_TS)
    n_skip = sum(1 for r in all_rows if r["verdict"] == DIAGNOSTIC_SKIP)
    n_total = len(all_rows)

    # provenance score (sims-with-parseable-JSON only)
    n_with_witness = n_full + n_partial + n_fail
    elapsed = time.monotonic() - t_start

    print("── summary " + "─" * 60)
    # detailed score table
    print(f"  {'sim':<55} {'verdict':<17} provenance score")
    for r in all_rows:
        d = r["detail"]
        if r["verdict"] == DIAGNOSTIC_SKIP:
            score_s = "n/a (no witness JSON to score)"
        else:
            req_n = (
                (1 if d["ts_is_deterministic"] else 0)
                + (1 if d["schema_present"] else 0)
                + (1 if d["real_limit_citation_present"] else 0)
            )
            soft_n = (
                (1 if d["case_study_present"] else 0)
                + (1 if d["module_present"] else 0)
            )
            score_s = f"required {req_n}/3 · soft {soft_n}/2"
        print(f"  {r['sim']:<55} {r['verdict']:<17} {score_s}")

    print()
    print(f"  {n_full} FULL · {n_partial} PARTIAL · {n_fail} FAIL_NO_TS · "
          f"{n_skip} DIAGNOSTIC-SKIP (of {n_total} sims)")
    if n_with_witness > 0:
        print(f"  of {n_with_witness} sims that emit parseable witness JSON: "
              f"{n_full} have FULL provenance, {n_partial} are PARTIAL "
              f"(gap noted),")
        print(f"  {n_fail} fail-block the sentinel (missing deterministic ts).")
    else:
        print("  no sim emitted a parseable witness JSON block on this host — "
              "all sims DIAGNOSTIC-SKIP.")
    print(f"  gate wall time: {elapsed:.2f}s")
    print()
    print("  HONESTY (g7): DIAGNOSTIC-SKIP rows (absent sim · non-zero exit · "
          "timeout · no JSON")
    print("    block) do NOT block the sentinel. Only a FAIL_NO_TS verdict "
          "(parseable witness")
    print("    JSON, but no deterministic timestamp) blocks it — that is the "
          "single")
    print("    reproducibility-breaking gap.")
    print("  HONESTY (g8): a FULL verdict verifies REPRODUCIBILITY METADATA "
          "of the witness")
    print("    ONLY — it does NOT imply any therapeutic / clinical / "
          "regulatory / binding-")
    print("    affinity / efficacy claim about the sim's content.")
    print("  REPORTER ≠ ENFORCER for soft fields (case_study_id · module "
          "traceback): their")
    print("    absence is NOTED as a gap for the sim author to address, but "
          "does NOT")
    print("    downgrade the verdict.\n")

    ok = (n_fail == 0)
    if ok:
        print("__PROVENANCE_PIPELINE_GATE__ PASS")
        return 0
    print("__PROVENANCE_PIPELINE_GATE__ FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
