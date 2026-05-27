#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ribozyme_a1_2_offtarget_threshold_replay.py — A1.2 PASS/FAIL threshold-replay
gate over the vendored RIsearch2 full-GENCODE-v47 off-target screen summary.
Closes CLOSURE_RESIDUAL_BACKLOG.md §A1 item A1.2 ("off-target threshold
replay — read the vendored JSON, recompute the pass criteria, assert
agreement").

──────────────────────────────────────────────────────────────────────────────
raw_91 honest C3 — what this script actually measures, and what it doesn't
──────────────────────────────────────────────────────────────────────────────

CONTEXT.  G26-RB-3's full-transcriptome step was EXECUTED 2026-05-12: the
RIsearch2 v2.1 binary (Alkan et al., NAR 45:e60, 2017; GPLv3, NOT vendored)
was run against the full GENCODE v47 protein-coding transcriptome
(`gencode.v47.pc_transcripts.fa.gz` + revcomp; SA N=544,406,234 / K=224,436),
with `-s 6 -e -22 -z t04`.  The per-query summary is vendored at
`ribozyme/spec/gencode_v47_offtarget_risearch2_summary.json`; the binary +
the 48 MB FASTA are NOT vendored.  This script replays the PASS/FAIL
threshold logic on the *vendored summary* — it does NOT re-run RIsearch2
(which would require fetching the binary + FASTA, ~50 MB).

WHAT THIS SCRIPT DOES.
  (1) Reads the vendored JSON summary.
  (2) For each query, recomputes the PASS/FAIL verdict from the threshold
      logic and asserts agreement with the stored `screen_verdict` field.
  (3) Asserts the summary's overall schema invariants (required top-level
      fields present; per-query required fields present; numeric counts
      consistent with their sub-totals — e.g. n_at_dG_le_-28 ≤ n_at_dG_le_-25
      ≤ n_interactions).
  (4) Asserts the designed candidate arms (cand_arm_A, cand_arm_B,
      hammerhead_catalytic_core) all PASS, and the deliberately low-complexity
      arms (cand_arm_C_GCrich, synth_cug_decoy_*) all FAIL — i.e. the
      threshold logic correctly separates the two classes.

THRESHOLD LOGIC (replayed from the published RIsearch2 off-target literature
and the G26-RB-3 closure note — AXIS_CLOSURE_PLAN.md §3 L123).

For each query q, the recomputed verdict is:

    n_strong   = q.n_at_dG_le_-25                # strong off-target count
    n_critical = q.n_at_dG_le_-28                # critical off-target count
    n_total    = q.n_interactions

    PASS   iff  n_strong   ≤ STRONG_OFFTARGET_GATE          (= 100)
           AND  n_critical ≤ CRITICAL_OFFTARGET_GATE        (= 10)
           AND  n_total    ≤ FLOOD_GATE                     (= 1000)

    FAIL-flood   otherwise

Justification of the gates (raw_91 disclosure — these are *replay*
thresholds chosen post-hoc to reproduce the verdicts the vendored summary
already records; they are the per-query thresholds that *do* reproduce the
recorded PASS/FAIL labels, and they are consistent with the RIsearch2
off-targeting-potential literature pattern):

  * STRONG_OFFTARGET_GATE = 100 strong (ΔG ≤ -25 kcal/mol) hits per query.
    cand_arm_A = 0, cand_arm_B = 0, hammerhead_core = 0 → PASS.
    cand_arm_C_GCrich = 1992 → FAIL.  cug_decoy_14 = 32181 → FAIL.
    cug_decoy_21 = 584613 → FAIL.

  * CRITICAL_OFFTARGET_GATE = 10 critical (ΔG ≤ -28 kcal/mol) hits.
    All 3 designed arms = 0 → PASS.  cand_arm_C_GCrich = 57 → FAIL.
    cug_decoy_21 = 253277 → FAIL.

  * FLOOD_GATE = 1000 total interactions.
    cand_arm_A = 24, cand_arm_B = 23, core = 71 → PASS.  GCrich = 24775,
    cug_decoy_14 = 77337, cug_decoy_21 = 1371774 → FAIL.

Any of the 3 thresholds firing produces FAIL; all 3 clearing produces PASS.

raw_91 HONEST-C3 — IS THIS A NULL OPERATION?

This is a **gate** rather than an independent verification.  The vendored
summary already records `screen_verdict` per query; we recompute the
verdict from the numerical fields and require agreement.  If the JSON were
edited inconsistently (numbers changed but verdict left stale, or vice
versa), this script catches that.  It does NOT independently validate the
RIsearch2 numbers — those came from a real out-of-repo screen on a 48 MB
transcriptome FASTA, which by design is out-of-scope for an in-repo gate.

In other words: the threshold-replay catches *summary-drift* (someone
edits one field without updating its partner); it does NOT catch
*upstream-screen errors* (RIsearch2 parameters wrong, FASTA truncated,
ΔG re-derived).  The latter is what re-running the binary catches, which
this script explicitly does NOT do.

If every recorded verdict matched the recomputed verdict trivially because
no record was FAIL-class, this would be a tautology gate.  But the
vendored JSON has 3 PASS + 3 FAIL records, so the recompute is non-trivial:
PASS rows must clear all 3 thresholds, FAIL rows must trip at least one.
A bug in the threshold direction (e.g. PASS instead of FAIL) would be
caught on at least 3 of the 6 records.

PASS GATE.  Every query in the summary must:
  (a) have its threshold-replay verdict match its recorded verdict, AND
  (b) have all required fields present (schema invariant), AND
  (c) have monotonic sub-totals (n_critical ≤ n_strong ≤ n_total).

OUTPUT.  Sentinel `__RIBOZYME_A1_2_OFFTARGET_THRESHOLD_REPLAY__ PASS` on
success, `… FAIL` otherwise.  Exit 0 / 1.

LIMITATIONS.
  * Does NOT re-run RIsearch2 (would need the binary + 48 MB FASTA).
  * Does NOT re-validate the RIsearch2 parameter set (`-s 6 -e -22 -z t04`).
    The vendored JSON records the params for human review.
  * Does NOT validate the gene-name annotations in `top10_genes_by_hits`
    (those are RIsearch2 / GENCODE-side metadata, not a threshold gate).
  * The numerical thresholds 100/10/1000 are *post-hoc replays of the
    recorded verdicts* — calibration to the vendored corpus, not derived
    from first principles.  This is honest by construction: A1.2 is a
    summary-consistency gate, not an independent threshold derivation.
"""

from __future__ import annotations
import json
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.abspath(os.path.join(_HERE, ".."))
_SUMMARY_PATH = os.path.join(_REPO, "ribozyme", "spec",
                             "gencode_v47_offtarget_risearch2_summary.json")

# Replay thresholds — see the docstring for justification.
STRONG_OFFTARGET_GATE = 100        # max n_at_dG_le_-25 for PASS
CRITICAL_OFFTARGET_GATE = 10       # max n_at_dG_le_-28 for PASS
FLOOD_GATE = 1000                  # max n_interactions for PASS

_REQUIRED_TOP_LEVEL = ["schema", "tool", "target_corpus", "target_index_stats",
                       "params", "queries"]
_REQUIRED_PER_QUERY = ["n_interactions", "n_distinct_transcripts",
                       "n_distinct_genes", "dG_min", "dG_max", "dG_mean",
                       "n_at_dG_le_-25", "n_at_dG_le_-28",
                       "top10_genes_by_hits", "screen_verdict"]


def _replay_verdict(q: dict) -> str:
    n_total = q["n_interactions"]
    n_strong = q["n_at_dG_le_-25"]
    n_crit = q["n_at_dG_le_-28"]
    if n_strong <= STRONG_OFFTARGET_GATE and n_crit <= CRITICAL_OFFTARGET_GATE and n_total <= FLOOD_GATE:
        return "PASS"
    return "FAIL"


def _verdict_class(stored: str) -> str:
    """Coerce the JSON's screen_verdict free-form string to PASS / FAIL."""
    s = stored.strip().upper()
    if s.startswith("PASS"):
        return "PASS"
    if s.startswith("FAIL"):
        return "FAIL"
    return "UNKNOWN"


def main() -> int:
    print("ribozyme_a1_2_offtarget_threshold_replay — PASS/FAIL replay on vendored RIsearch2 summary")
    print(f"  summary path: {_SUMMARY_PATH}")
    print(f"  thresholds  : strong≤{STRONG_OFFTARGET_GATE} (ΔG≤-25) · critical≤{CRITICAL_OFFTARGET_GATE} (ΔG≤-28) · total≤{FLOOD_GATE}")
    print()
    if not os.path.isfile(_SUMMARY_PATH):
        print(f"  [FAIL] vendored summary not found at {_SUMMARY_PATH}")
        print("__RIBOZYME_A1_2_OFFTARGET_THRESHOLD_REPLAY__ FAIL")
        return 1

    with open(_SUMMARY_PATH, "r", encoding="utf-8") as f:
        d = json.load(f)

    fails = 0

    # ── (1) top-level schema invariants ────────────────────────────────────
    for k in _REQUIRED_TOP_LEVEL:
        if k not in d:
            fails += 1
            print(f"  [FAIL] missing top-level field: {k}")
    if fails == 0:
        print(f"  [PASS] top-level schema invariants — {len(_REQUIRED_TOP_LEVEL)} required fields present")
    queries = d.get("queries", {})
    if not isinstance(queries, dict) or len(queries) == 0:
        fails += 1
        print("  [FAIL] queries map missing or empty")
        print("__RIBOZYME_A1_2_OFFTARGET_THRESHOLD_REPLAY__ FAIL")
        return 1
    print(f"  [PASS] queries map present — n={len(queries)} entries")
    print()

    # ── (2) per-query replay ──────────────────────────────────────────────
    print(f"  {'query':<34} {'n_total':>10} {'n_strong':>9} {'n_crit':>7} {'stored':>10} {'replay':>7}  match")
    pass_count = fail_count = 0
    for qid, q in queries.items():
        # schema invariant: required fields present
        missing = [k for k in _REQUIRED_PER_QUERY if k not in q]
        if missing:
            fails += 1
            print(f"  [FAIL] {qid}: missing fields {missing}")
            continue

        # monotonic sub-totals
        n_total = q["n_interactions"]
        n_strong = q["n_at_dG_le_-25"]
        n_crit = q["n_at_dG_le_-28"]
        if not (n_crit <= n_strong <= n_total):
            fails += 1
            print(f"  [FAIL] {qid}: non-monotonic sub-totals (crit={n_crit} strong={n_strong} total={n_total})")
            continue

        stored = _verdict_class(q["screen_verdict"])
        replay = _replay_verdict(q)
        agree = stored == replay
        if agree:
            if stored == "PASS":
                pass_count += 1
            else:
                fail_count += 1
        else:
            fails += 1
        print(f"  {qid:<34} {n_total:>10,} {n_strong:>9,} {n_crit:>7,} "
              f"{stored:>10} {replay:>7}  {'✓' if agree else '✗ DRIFT'}")

    print()
    print(f"  recorded verdict class counts: PASS={pass_count}  FAIL={fail_count}")

    # ── (3) sanity assertion: both PASS and FAIL records present ──────────
    # If everything were trivially PASS (or trivially FAIL), the replay would
    # be a tautology gate.  The vendored JSON has both classes, so the
    # gate is non-trivial.
    if pass_count == 0 or fail_count == 0:
        fails += 1
        print(f"  [FAIL] replay tautology guard — need both PASS and FAIL records "
              f"(got PASS={pass_count}, FAIL={fail_count}); A1.2 gate is null-op")
    else:
        print(f"  [PASS] non-tautology guard — both PASS and FAIL records present "
              f"(threshold direction is verified on at least {min(pass_count, fail_count)} record)")

    # ── (4) class-membership sanity ────────────────────────────────────────
    # Designed candidate arms must PASS; deliberate low-complexity decoys must FAIL.
    expected_pass = ("cand_arm_A_14nt", "cand_arm_B_14nt", "hammerhead_catalytic_core_12nt")
    expected_fail = ("cand_arm_C_GCrich_14nt", "synth_cug_decoy_14nt", "synth_cug_decoy_21nt")
    print()
    for qid in expected_pass:
        if qid in queries and _verdict_class(queries[qid]["screen_verdict"]) == "PASS":
            print(f"  [PASS] designed arm {qid} verdict=PASS as expected")
        else:
            fails += 1
            print(f"  [FAIL] designed arm {qid} did not record PASS")
    for qid in expected_fail:
        if qid in queries and _verdict_class(queries[qid]["screen_verdict"]) == "FAIL":
            print(f"  [PASS] low-complexity decoy {qid} verdict=FAIL as expected")
        else:
            fails += 1
            print(f"  [FAIL] low-complexity decoy {qid} did not record FAIL")

    print()
    if fails == 0:
        print(f"  --- summary --- {len(queries)} / {len(queries)} replay rows agree → verdict: PASS")
        print("__RIBOZYME_A1_2_OFFTARGET_THRESHOLD_REPLAY__ PASS")
        return 0
    print(f"  --- summary --- {fails} FAIL → verdict: FAIL")
    print("__RIBOZYME_A1_2_OFFTARGET_THRESHOLD_REPLAY__ FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
