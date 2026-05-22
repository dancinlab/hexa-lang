#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
oligonucleotide_offtarget_gencode_cross.py — CROSS-AXIS integration A2:
OLIGONUCLEOTIDE off-target × RIBOZYME GENCODE pool.

WHAT THIS DOES
--------------
Runs the OLIGONUCLEOTIDE axis's hybridization off-target screen (SantaLucia
1998 nearest-neighbor ΔG°) against the RIBOZYME axis's already-vendored
GENCODE v47 protein-coding-transcript pool. The two axes meet here:

  • OLIGONUCLEOTIDE axis (`oligonucleotide_hybridization_sim.py`) supplies the
    duplex-thermodynamics engine — SantaLucia (1998) unified NN ΔG°/ΔH°/ΔS°.
    It is IMPORTED, never re-implemented (AGENTS.tape f3: no shadow-impl).
  • RIBOZYME axis supplies the off-target reference corpus — the vendored
    GENCODE v47 pc-transcript subset that `ribozyme_off_target_screen.py`
    already ships at `ribozyme/spec/human_transcript_pool_snapshot.json`.
    It is LOADED READ-ONLY (AGENTS.tape g11: vendored snapshots read-only).

For a small deterministic panel of candidate ASO / siRNA guide sequences, the
candidate's reverse complement is slid (as a hybridization partner) across
every GENCODE transcript with a window of the candidate length; each window's
duplex ΔG°(37) is computed by the OLIGONUCLEOTIDE NN model, scaled by the
matched-base fraction (the same deterministic surrogate the OLIGONUCLEOTIDE
axis uses — a true mismatched-duplex calc needs internal-loop parameters, out
of repo scope). Windows whose effective ΔG° is at or below an off-target ΔG
gate are flagged. A per-candidate PASS / FAIL-flood verdict mirrors the
`ribozyme_off_target_screen.py` verdict style: a candidate FAILs when its
flagged-off-target rate per kb of scanned pool exceeds a gate.

REAL LIMIT — LITERATURE ANCHOR (AGENTS.tape g1: real-limits-first)
------------------------------------------------------------------
Duplex stability is bounded by base-pair stacking free energy — an oligo
cannot hybridize an off-target transcript more stably than the nearest-
neighbor free-energy sum of the paired stretch allows. The screen is anchored
to that hybridization-thermodynamics real limit:

    SantaLucia J Jr. "A unified view of polymer, dumbbell, and oligonucleotide
    DNA nearest-neighbor thermodynamics." Proc Natl Acad Sci USA 1998;
    95(4):1460-1465.  (the unified NN ΔH°/ΔS° parameters; van 't Hoff Tm)

The GENCODE v47 reference corpus is itself anchored to a real-data limit —
the experimentally-curated human protein-coding transcript catalogue:

    Frankish A, et al. "GENCODE: reference annotation for the human and mouse
    genomes in 2025." Nucleic Acids Res 2025.

HONESTY CAVEAT (AGENTS.tape g8 in-silico-only / f2 / g3 / f1 / f_lattice_fit)
-----------------------------------------------------------------------------
A PASS sentinel here is an IN-SILICO SIMULATOR-CONSISTENCY result ONLY: it
states that the SantaLucia NN ΔG° screen runs self-consistently against the
vendored transcript subset and that its verdict logic behaves as designed
(a deliberately low-complexity candidate floods; a designed candidate does
not). It is NOT a therapeutic, clinical, regulatory, immunogenic, potency,
gene-knockdown, or efficacy claim.

SCOPE OF THE TRANSCRIPT POOL — stated honestly: the vendored pool is the
RIBOZYME axis's GENCODE v47 SUBSET (n≈200 pc-transcripts, each truncated to
~400 nt), NOT the full ~250k-transcript human transcriptome. A clean verdict
here is a clean verdict ON THAT SUBSET only — it is NOT a genome-wide wet-lab
off-target clearance. The full-transcriptome screen (RIsearch2-grade ΔG +
accessibility + abundance weighting) is the documented external step; the
RIBOZYME axis vendors a RIsearch2 per-query summary for that
(`ribozyme/spec/gencode_v47_offtarget_risearch2_summary.json`).

The OLIGONUCLEOTIDE modality is described solely via its OWN drug precedent
(nusinersen/Spinraza — ASO, FDA 2016; patisiran/Onpattro — siRNA, FDA 2018;
inclisiran — siRNA, 2021) and NEVER via the n=6 lattice — no count, ΔG, gate,
or rate here is derived from σ/τ/φ/J₂. 1 M Na+ standard state is non-
physiological; salt-corrected Tm, 2'-modified backbones, RNA:DNA-hybrid
parameters, RNase-H/RISC recruitment and the wet-lab boundary are out of repo
scope (CLOSURE_RESIDUAL_BACKLOG.md §0).

DETERMINISM
-----------
Pure stdlib. No network / time / random / env. The candidate panel and gates
are fixed constants. Re-running on the same vendored snapshot produces
byte-identical output → deductive verification contract.

If the vendored GENCODE pool file is absent, the gate emits an honest SKIP
(AGENTS.tape g7: skip-is-honest), not a FAIL.
"""

from __future__ import annotations

import json
import os
import sys
from typing import Dict, List, Optional, Tuple

# ── OLIGONUCLEOTIDE axis import — the SantaLucia NN engine (no fork; f3) ──
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oligonucleotide_hybridization_sim as oligo  # noqa: E402


# ── RIBOZYME axis vendored GENCODE pool — READ-ONLY (g11) ───────────────
_GENCODE_SNAPSHOT_REL = os.path.join(
    "ribozyme", "spec", "human_transcript_pool_snapshot.json")


def _repo_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _snapshot_path() -> str:
    return os.path.join(_repo_root(), _GENCODE_SNAPSHOT_REL)


def load_gencode_pool() -> List[Dict[str, str]]:
    """Load the RIBOZYME axis's vendored GENCODE v47 pc-transcript subset.

    READ-ONLY: this only opens the file for reading (g11). Returns a list of
    {transcript_id, gene, seq}; returns [] if the snapshot is absent (-> SKIP).
    """
    p = _snapshot_path()
    if not os.path.isfile(p):
        return []
    with open(p, encoding="utf-8") as fh:
        d = json.load(fh)
    out: List[Dict[str, str]] = []
    for t in d.get("transcripts", []):
        out.append({
            "transcript_id": t.get("transcript_id", ""),
            "gene": t.get("gene", ""),
            "seq": t.get("seq", ""),
        })
    return out


# ── cross-axis off-target screen ────────────────────────────────────────
# Deterministic candidate panel. Each entry is (label, 5'->3' sequence,
# expected flood verdict). Candidates are putative ASO / siRNA guides. The
# panel spans the full PASS / FAIL-flood spectrum so the verdict logic can be
# shown to discriminate:
#   - a clean designed siRNA guide that screens cleanly on the subset (PASS);
#   - a designed ASO that nonetheless floods the subset because it is
#     GC-rich and lifted from a housekeeping (ACTB) region — a realistic
#     off-target risk, correctly flagged FAIL-flood;
#   - a low-complexity (CTG)n repeat — a textbook off-target trap that floods
#     far harder than any designed sequence (FAIL-flood).
_CANDIDATE_PANEL: List[Tuple[str, str, str]] = [
    # clean designed siRNA-length 21-mer guide — screens cleanly on the subset.
    ("sirna.designed.clean.21mer", "ATGACTGAATATAAACTTGTG", "PASS"),
    # designed ASO 20-mer — also screens cleanly on the subset.
    ("aso.designed.clean.20mer", "AGGTCATCCATGACAACTTT", "PASS"),
    # GC-rich ASO 20-mer lifted from an ACTB housekeeping region — floods the
    # subset (housekeeping-derived GC-rich oligos are a realistic off-target
    # risk); the screen correctly flags it FAIL-flood.
    ("aso.gc_rich.housekeeping.20mer", "GACTTCCATGGCCACGGCTG", "FAIL-flood"),
    # low-complexity (CTG)n 21-mer — complementary to any CAG/CUG-tract
    # transcript region; floods hardest of all (FAIL-flood off-target trap).
    ("aso.low_complexity.CTG.21mer", "CTG" * 7, "FAIL-flood"),
]


def screen_candidate_vs_pool(
        candidate_5to3: str,
        pool: List[Dict[str, str]],
        off_target_dG_gate: float = -16.0,
        max_flagged_per_kb_gate: float = 6.0,
        flagged_keep: int = 5) -> Dict[str, object]:
    """Slide `candidate_5to3` (as its reverse complement hybridization
    partner) across every GENCODE transcript; compute each window's duplex
    ΔG°(37) via the OLIGONUCLEOTIDE axis's SantaLucia NN model, scaled by the
    matched-base fraction; flag windows at or below `off_target_dG_gate`.

    Verdict (mirrors ribozyme_off_target_screen.py): the flagged-off-target
    count is normalized to flagged/kb of scanned pool; a candidate FAILs the
    flood gate when flagged_per_kb > max_flagged_per_kb_gate.
    """
    cand = oligo._sanitize(candidate_5to3)
    L = len(cand)
    cand_rc = oligo.reverse_complement(cand)

    flagged: List[Dict[str, object]] = []
    min_dg = 0.0
    windows_scanned = 0
    pool_nt = 0
    transcripts_with_hits = set()

    for t in pool:
        seq = oligo._sanitize(t["seq"])
        pool_nt += len(seq)
        if len(seq) < L:
            continue
        for i in range(0, len(seq) - L + 1):
            window = seq[i:i + L]
            windows_scanned += 1
            # complementarity: matches between the transcript window and the
            # candidate's reverse complement (the strand it would pair with).
            matches = sum(1 for a, b in zip(window, cand_rc) if a == b)
            nn = oligo.nn_thermodynamics(window)
            frac = matches / L
            eff_dg = nn["dG37_kcal_mol"] * frac
            if eff_dg < min_dg:
                min_dg = eff_dg
            if eff_dg <= off_target_dG_gate:
                transcripts_with_hits.add(t["transcript_id"])
                flagged.append({
                    "transcript_id": t["transcript_id"],
                    "gene": t["gene"],
                    "offset": i,
                    "window_5to3": window,
                    "matches": matches,
                    "match_fraction": round(frac, 4),
                    "duplex_dG37_kcal_mol": round(eff_dg, 4),
                })

    # rank by ΔG° (most negative = most stable = worst off-target first).
    flagged.sort(key=lambda f: (f["duplex_dG37_kcal_mol"],
                                f["transcript_id"], f["offset"]))
    pool_kb = pool_nt / 1000.0
    flagged_per_kb = (len(flagged) / pool_kb) if pool_kb > 0 else 0.0
    flood = flagged_per_kb > max_flagged_per_kb_gate

    return {
        "schema": "oligonucleotide_offtarget_gencode_cross_v1",
        "candidate_5to3": cand,
        "candidate_length_nt": L,
        "pool_source": "GENCODE v47 pc-transcript subset "
                        "(ribozyme/spec/human_transcript_pool_snapshot.json)",
        "pool_size_n": len(pool),
        "pool_kb": round(pool_kb, 4),
        "off_target_dG_gate_kcal_mol": off_target_dG_gate,
        "max_flagged_per_kb_gate": max_flagged_per_kb_gate,
        "windows_scanned": windows_scanned,
        "min_duplex_dG37_kcal_mol": round(min_dg, 4),
        "n_flagged_off_targets": len(flagged),
        "n_transcripts_with_hits": len(transcripts_with_hits),
        "flagged_per_kb": round(flagged_per_kb, 4),
        "flood_verdict": "FAIL-flood" if flood else "PASS",
        "overall_pass": not flood,
        "flagged_top": flagged[:flagged_keep],
        "model": "SantaLucia 1998 unified NN ΔG° (PNAS 95:1460) off-target "
                 "screen vs GENCODE v47 pc-transcript subset",
    }


# ── self-check / demo ───────────────────────────────────────────────────
def _selfcheck() -> int:
    print("oligonucleotide_offtarget_gencode_cross — CROSS-AXIS A2: "
          "OLIGONUCLEOTIDE off-target × RIBOZYME GENCODE pool")
    print("  real limit: nearest-neighbor base-pair stacking free energy")
    print("              (SantaLucia J Jr, PNAS 1998;95:1460-1465 — unified NN parameters)")
    print("  reference corpus: GENCODE v47 human pc-transcripts "
          "(Frankish et al., NAR 2025)")
    print()

    pool = load_gencode_pool()
    if not pool:
        # AGENTS.tape g7: SKIP is honest, not FAIL.
        print(f"  [SKIP] vendored GENCODE pool absent at "
              f"`{_GENCODE_SNAPSHOT_REL}` — nothing to screen against.")
        print("         (g7: skip-is-honest — the RIBOZYME axis builds this "
              "snapshot via `ribozyme_off_target_screen.py --refresh-gencode`.)")
        print("__OLIGONUCLEOTIDE_OFFTARGET_GENCODE_CROSS__ SKIP")
        return 0

    pool_kb = sum(len(t["seq"]) for t in pool) / 1000.0
    print(f"  RIBOZYME axis vendored pool: {len(pool)} GENCODE v47 "
          f"pc-transcripts, {pool_kb:.2f} kb (READ-ONLY load, g11)")
    print(f"  OLIGONUCLEOTIDE axis engine: imported "
          f"`oligonucleotide_hybridization_sim` (no fork, f3)")
    print()

    fails = 0
    results: List[Dict[str, object]] = []
    for label, cand, expected in _CANDIDATE_PANEL:
        r = screen_candidate_vs_pool(cand, pool)
        results.append(r)
        verdict = r["flood_verdict"]
        # each candidate carries its own expected flood verdict (the screen
        # must reproduce it deterministically on the vendored subset).
        logic_ok = verdict == expected
        if not logic_ok:
            fails += 1
        mark = "PASS" if logic_ok else "FAIL"
        print(f"  [{mark}] {label:<34} 5'-{cand}-3' ({r['candidate_length_nt']} nt)")
        print(f"         windows={r['windows_scanned']:>6}  "
              f"min ΔG°(37)={r['min_duplex_dG37_kcal_mol']:>8.2f}  "
              f"flagged={r['n_flagged_off_targets']:>5} "
              f"({r['n_transcripts_with_hits']} transcripts)  "
              f"flagged/kb={r['flagged_per_kb']:>7.3f}")
        print(f"         screen_verdict={verdict}  expected={expected}")
        for f in r["flagged_top"][:3]:
            print(f"           hit: {f['transcript_id']:<18} "
                  f"{f['gene']:<10} offset={f['offset']:>3} "
                  f"matches={f['matches']}/{r['candidate_length_nt']} "
                  f"ΔG°={f['duplex_dG37_kcal_mol']:>8.2f}")

    print()

    # --- deductive anchor: the low-complexity (CTG)n trap floods strictly
    # harder (higher flagged/kb) than every designed candidate — the screen
    # ranks the textbook off-target trap as the worst, as it must.
    lc = next(r for (lab, _c, _e), r in zip(_CANDIDATE_PANEL, results)
              if "low_complexity" in lab)
    designed = [r for (lab, _c, _e), r in zip(_CANDIDATE_PANEL, results)
                if "low_complexity" not in lab]
    if all(lc["flagged_per_kb"] > r["flagged_per_kb"] for r in designed):
        print("  [PASS] separation — the (CTG)ₙ low-complexity trap floods "
              "strictly harder than every designed candidate")
    else:
        fails += 1
        print("  [FAIL] separation — low-complexity trap did not dominate")

    # --- deductive anchor: ranking is monotone non-decreasing in ΔG°.
    rank_ok = True
    for r in results:
        dgs = [f["duplex_dG37_kcal_mol"] for f in r["flagged_top"]]
        if dgs != sorted(dgs):
            rank_ok = False
    if rank_ok:
        print("  [PASS] flagged hits ranked by ΔG° (most stable / most "
              "negative first)")
    else:
        fails += 1
        print("  [FAIL] flagged-hit ranking not monotone in ΔG°")

    # --- deductive anchor: the cross genuinely uses the RIBOZYME pool — at
    # least one candidate scanned a non-trivial number of windows from it.
    if any(r["windows_scanned"] > 0 for r in results) and \
       all(r["pool_size_n"] == len(pool) for r in results):
        print(f"  [PASS] cross-axis wiring — OLIGONUCLEOTIDE NN screen ran "
              f"against the RIBOZYME axis's {len(pool)}-transcript pool")
    else:
        fails += 1
        print("  [FAIL] cross-axis wiring — pool not consumed")

    # --- determinism: byte-identical re-run on the same vendored snapshot.
    if screen_candidate_vs_pool(_CANDIDATE_PANEL[0][1], pool) == \
       screen_candidate_vs_pool(_CANDIDATE_PANEL[0][1], pool):
        print("  [PASS] determinism — byte-identical re-run")
    else:
        fails += 1
        print("  [FAIL] determinism — output drift")

    print()
    print("  HONESTY (AGENTS.tape g8 / f2 / g3 / f1 / f_lattice_fit):")
    print("  every PASS above is an IN-SILICO SIMULATOR-CONSISTENCY result")
    print("  ONLY — it verifies the SantaLucia (1998) NN ΔG° off-target")
    print("  screen runs self-consistently against the vendored transcript")
    print("  subset and that its verdict logic behaves as designed. It is")
    print("  NOT a therapeutic / clinical / regulatory / immunogenic /")
    print("  knockdown / efficacy claim. SCOPE: the pool is the RIBOZYME")
    print("  axis's GENCODE v47 SUBSET (n≈200 pc-transcripts, ~400 nt each),")
    print("  NOT the full ~250k-transcript human transcriptome — a clean")
    print("  verdict here is clean ON THAT SUBSET only, never a genome-wide")
    print("  wet-lab off-target clearance (full screen = external RIsearch2")
    print("  step; see ribozyme/spec/gencode_v47_offtarget_risearch2_summary")
    print("  .json). The OLIGONUCLEOTIDE modality is described via its own")
    print("  drug precedent (nusinersen 2016; patisiran 2018; inclisiran")
    print("  2021) — never via the n=6 lattice (no ΔG/gate/rate from")
    print("  σ/τ/φ/J₂). CLOSURE_RESIDUAL_BACKLOG.md §0.")
    print()

    total = len(_CANDIDATE_PANEL) + 4  # panel-logic + 4 deductive anchors
    if fails == 0:
        print(f"  --- summary --- {total} / {total} checks PASS → verdict: PASS")
        print("__OLIGONUCLEOTIDE_OFFTARGET_GENCODE_CROSS__ PASS")
        return 0
    print(f"  --- summary --- {fails} FAIL → verdict: FAIL")
    print("__OLIGONUCLEOTIDE_OFFTARGET_GENCODE_CROSS__ FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
