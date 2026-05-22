#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
aav_cargo_capacity_check.py — pure-stdlib deterministic AAV cargo-capacity gate.

Anchors LVAD scenario AAV_BTR_GENE_THERAPY §3 real-limit #1: the AAV
single-stranded packaging wall ~4.7 kb (between the two ITRs).

Real-limit anchor (g1):
  AAV genome length (ITR-to-ITR, ssDNA) tolerated by AAV9 capsid is bounded
  near 4.7 kb. Cargos exceeding this either fail to package, package
  truncated, or accumulate heterogeneous fragments. The wall is empirical
  (capsid interior volume + ssDNA persistence length + ITR-replication
  fidelity) — not a hard mathematical theorem, but the working ceiling
  cited across the AAV literature.

  Primary citations:
    * Wu Z., Yang H., Colosi P. (2010). Effect of genome size on AAV vector
      packaging. Molecular Therapy 18(1):80-86.
      DOI: 10.1038/mt.2009.255
      → showed 5.0 kb is the inflection, drop-off accelerates past 4.7 kb.
    * Wang D., Tai P.W.L., Gao G. (2019). Adeno-associated virus vector as
      a platform for gene therapy delivery. Nature Reviews Drug Discovery
      18(5):358-378. DOI: 10.1038/s41573-019-0012-9
      → review treats 4.7 kb as the working cargo cap for single-AAV
      delivery; longer cargos require dual-AAV / trans-splicing / overlap
      strategies.

ITR length anchor:
  AAV2-derived ITRs (the pseudotype-2 ITRs used in nearly all rAAV
  vectors, including AAV9-pseudotyped) are 145 bp each (Wang 2019,
  Naso M.F. et al. 2017 BioDrugs 31:317). Two ITRs = 290 bp of the
  ~4700 bp budget → 4410 bp left for promoter+CDS+polyA.

Verdict semantics:
  PASS      headroom_bp >= 0
            (cargo fits inside the engineering margin under the 4.7 kb wall;
            single-AAV packaging predicted feasible)
  FAIL      headroom_bp <  0  AND  total_bp <= 2 * HARD_WALL_BP
            (over the engineering margin / hard wall but still within range
            recoverable by dual-AAV / overlap / split-intein strategies)
  OVERFLOW  total_bp >  2 * HARD_WALL_BP
            (beyond what dual-AAV can rescue; large-cargo therapeutic
            strategies — full-length dystrophin, etc. — fall here)

  The 2× hard-wall cutoff for OVERFLOW is the dual-AAV ceiling: two AAV
  cassettes spanning ≤ 4.7 kb each via intein-mediated reconstitution or
  trans-splicing overlap (Carvalho et al. 2017 Hum Gene Ther 28(11):1067).
  Cargos larger than 2×4.7 kb need triple-AAV or alternative vectors.

Determinism: pure stdlib (no numpy / biopython / random / network / time).
Re-running the selftest on the same constants returns byte-identical output.

Honest scope (g8 / f2):
  This module checks IN-SILICO whether a designed cargo fits the AAV9
  single-stranded packaging budget. PASS here is a packaging-feasibility
  filter only — it is NOT a therapeutic claim, NOT an expression-level
  prediction, NOT an in-vivo efficacy claim. Cardiac transduction
  efficiency, anti-AAV9 immunity, ribozyme in-vivo activity, and BTR
  explant feasibility remain wet-lab gated.

License: Apache-2.0 (hexa-bio core).
"""

from __future__ import annotations

import json
import sys
from typing import Dict

# ── Constants (real-limit anchors) ──
HARD_WALL_BP = 4700      # AAV9 ssDNA packaging ceiling (Wu/Yang/Colosi 2010; Wang/Tai/Gao 2019)
DEFAULT_ITR_BP = 145     # AAV2-pseudotype-2 ITR (used in AAV9 vectors); Naso et al. 2017; Wang 2019
DEFAULT_SAFETY_MARGIN_BP = 50  # engineering margin under HARD_WALL_BP

# ── Verdict labels ──
VERDICT_PASS = "PASS"
VERDICT_FAIL = "FAIL"
VERDICT_OVERFLOW = "OVERFLOW"

# Token printed on all-pass selftest (matches existing module convention
# e.g. __VIROCAPSID_PDB_AUDIT__ PASS in virocapsid_pdb_corpus.py).
PASS_TOKEN = "__AAV_CARGO_CAPACITY__"


def check_cargo(
    itr_5p_bp: int,
    promoter_bp: int,
    cds_bp: int,
    polyA_bp: int,
    itr_3p_bp: int,
    safety_margin_bp: int = DEFAULT_SAFETY_MARGIN_BP,
) -> Dict[str, object]:
    """Check whether a designed AAV cargo fits the AAV9 ssDNA packaging budget.

    Args:
        itr_5p_bp:        5' ITR length in bp (typically 145).
        promoter_bp:      promoter cassette length in bp (incl. enhancer if any).
        cds_bp:           coding sequence length in bp (start → stop).
        polyA_bp:         polyA signal length in bp.
        itr_3p_bp:        3' ITR length in bp (typically 145).
        safety_margin_bp: engineering margin under HARD_WALL_BP (default 50).

    Returns:
        dict with keys:
            total_bp          : sum of the five components
            hard_wall_bp      : 4700 (AAV9 ssDNA hard wall)
            effective_cap_bp  : hard_wall_bp - safety_margin_bp
            headroom_bp       : effective_cap_bp - total_bp  (>=0 = PASS)
            verdict           : PASS | FAIL | OVERFLOW
            (plus structural fields for downstream witness emission)
    """
    for name, v in (
        ("itr_5p_bp", itr_5p_bp), ("promoter_bp", promoter_bp), ("cds_bp", cds_bp),
        ("polyA_bp", polyA_bp), ("itr_3p_bp", itr_3p_bp), ("safety_margin_bp", safety_margin_bp),
    ):
        if not isinstance(v, int) or v < 0:
            raise ValueError(f"{name} must be a non-negative int, got {v!r}")

    total_bp = itr_5p_bp + promoter_bp + cds_bp + polyA_bp + itr_3p_bp
    effective_cap_bp = HARD_WALL_BP - safety_margin_bp
    headroom_bp = effective_cap_bp - total_bp
    dual_aav_ceiling_bp = 2 * HARD_WALL_BP  # Carvalho et al. 2017 Hum Gene Ther 28(11):1067

    if total_bp > dual_aav_ceiling_bp:
        verdict = VERDICT_OVERFLOW
    elif headroom_bp < 0:
        verdict = VERDICT_FAIL
    else:
        verdict = VERDICT_PASS

    return {
        "schema": "aav_cargo_capacity_check_v1",
        "components_bp": {
            "itr_5p": itr_5p_bp,
            "promoter": promoter_bp,
            "cds": cds_bp,
            "polyA": polyA_bp,
            "itr_3p": itr_3p_bp,
        },
        "total_bp": total_bp,
        "hard_wall_bp": HARD_WALL_BP,
        "safety_margin_bp": safety_margin_bp,
        "effective_cap_bp": effective_cap_bp,
        "headroom_bp": headroom_bp,
        "dual_aav_ceiling_bp": dual_aav_ceiling_bp,
        "verdict": verdict,
        "real_limit_citation": (
            "Wu Z., Yang H., Colosi P. 2010 Mol Ther 18(1):80-86; "
            "Wang D., Tai P.W.L., Gao G. 2019 Nat Rev Drug Discov 18(5):358-378"
        ),
        "honest_scope": (
            "in-silico packaging-feasibility filter only; NOT a therapeutic/clinical/"
            "expression/efficacy claim (AGENTS.tape g8 / f2)"
        ),
    }


# ── Selftest F-AAV-CARGO-1 ──

def _case(label: str, kwargs: dict, expected_verdict: str) -> Dict[str, object]:
    """Run one named test case and return (label, result, expected, pass)."""
    res = check_cargo(**kwargs)
    return {
        "label": label,
        "kwargs": kwargs,
        "result": res,
        "expected_verdict": expected_verdict,
        "case_pass": res["verdict"] == expected_verdict,
    }


def selftest_F_AAV_CARGO_1() -> Dict[str, object]:
    """F-AAV-CARGO-1 selftest: 6 fixed cases anchored to real LVAD-BTR cargos.

    Reference cargo sizes (for case construction):
        SERCA2a (ATP2A2)   CDS ~3000 bp    (997 aa × 3 = 2991, +stop)
        MYBPC3             CDS ~3825 bp    (1274 aa × 3 = 3822, +stop)
        dystrophin (DMD)   CDS ~11000 bp   (3685 aa × 3 = 11055, +stop)
        CMV promoter       ~650 bp
        bGH polyA          ~225 bp
        cTnT cardiac-restricted promoter   ~250 bp (compressed)
        WPRE post-regulatory element       ~600 bp
        trans-splicing ribozyme construct  ~600 bp
        AAV2 ITR                           145 bp each
    """
    cases = [
        _case(
            "C1_empty_just_itrs",
            dict(itr_5p_bp=145, promoter_bp=0, cds_bp=0, polyA_bp=0, itr_3p_bp=145),
            VERDICT_PASS,
        ),
        _case(
            "C2_serca2a_cmv_bghpa",
            dict(itr_5p_bp=145, promoter_bp=650, cds_bp=3000, polyA_bp=225, itr_3p_bp=145),
            VERDICT_PASS,
        ),
        _case(
            "C3_mybpc3_cmv_bghpa",
            dict(itr_5p_bp=145, promoter_bp=650, cds_bp=3825, polyA_bp=225, itr_3p_bp=145),
            VERDICT_FAIL,
        ),
        _case(
            "C4_dystrophin_full_length",
            dict(itr_5p_bp=145, promoter_bp=650, cds_bp=11000, polyA_bp=225, itr_3p_bp=145),
            VERDICT_OVERFLOW,
        ),
        _case(
            "C5_trans_splicing_ribozyme_ctnt_wpre",
            dict(itr_5p_bp=145, promoter_bp=250, cds_bp=600, polyA_bp=600, itr_3p_bp=145),
            VERDICT_PASS,
        ),
        # C6: boundary case — total_bp == effective_cap_bp (4650) exactly.
        # Choose components so they sum to 4650 with default ITRs (145+145=290):
        #   promoter=650, cds=3585, polyA=125, ITRs=290 → total=4650, headroom=0
        _case(
            "C6_boundary_exact_4650",
            dict(itr_5p_bp=145, promoter_bp=650, cds_bp=3585, polyA_bp=125, itr_3p_bp=145),
            VERDICT_PASS,
        ),
    ]
    n_pass = sum(1 for c in cases if c["case_pass"])
    overall_pass = n_pass == len(cases)
    return {
        "schema": "aav_cargo_capacity_selftest_v1",
        "selftest_id": "F-AAV-CARGO-1",
        "n_cases": len(cases),
        "n_pass": n_pass,
        "overall_pass": overall_pass,
        "cases": cases,
        "real_limit_anchored": "AAV9 ssDNA packaging hard wall ~4.7 kb (Wu 2010; Wang 2019)",
        "honest_scope": (
            "F-AAV-CARGO-1 verifies the cargo-fit arithmetic against curated case "
            "sizes; it does NOT verify packaging efficiency in vitro, expression "
            "level, transduction, or any clinical endpoint. See AGENTS.tape g8 / f2."
        ),
    }


def main() -> int:
    print("aav_cargo_capacity_check — AAV9 ssDNA cargo-fit gate (F-AAV-CARGO-1)\n", flush=True)
    print(f"  hard wall            = {HARD_WALL_BP} bp   (Wu 2010; Wang 2019)")
    print(f"  default safety margin = {DEFAULT_SAFETY_MARGIN_BP} bp")
    print(f"  effective cap        = {HARD_WALL_BP - DEFAULT_SAFETY_MARGIN_BP} bp")
    print(f"  default ITR length   = {DEFAULT_ITR_BP} bp each (AAV2-pseudotype; Wang 2019)")
    print()

    report = selftest_F_AAV_CARGO_1()
    for c in report["cases"]:
        r = c["result"]
        mark = "PASS" if c["case_pass"] else "FAIL"
        print(
            f"  [{mark}] {c['label']:<38}  total={r['total_bp']:>6} bp  "
            f"headroom={r['headroom_bp']:>+6} bp  verdict={r['verdict']:<8}  "
            f"(expected {c['expected_verdict']})"
        )

    print(f"\n  --- F-AAV-CARGO-1: {report['n_pass']}/{report['n_cases']}  "
          f"→ overall_pass = {report['overall_pass']} ---\n")

    print("## selftest witness JSON")
    print(json.dumps(report, indent=2, ensure_ascii=False, sort_keys=False))

    ok = bool(report["overall_pass"])
    print(f"\n{PASS_TOKEN} {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
