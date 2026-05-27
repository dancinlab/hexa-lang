#!/usr/bin/env python3
"""ml_capsid_fitness.py — drylab #11 · transparent public-proxy capsid scorer.

Built from the committed spec drylab/research/ml_capsid_fitness.md
(RE-wave2 #11, commit 879d387).

═══ WHAT THIS IS NOT (per spec §what-this-is-NOT) ═══
- NOT a reproduction / reimplementation / reverse-engineering of any
  proprietary method. Dyno CapsidMap, Form Bio FORMsightAI, Affinia ART,
  Voyager TRACER are described ONLY by their own public claims; their
  ML / training data / wet-lab-selection methods are undisclosed and are
  neither reconstructed nor guessed. THIS USES NO ML AT ALL (g3).
- NOT a tropism / transduction / efficacy / immune-evasion /
  manufacturability / clinical predictor. A high score means ONLY that
  more cited documented public proxies matched — NO in-vivo evidence
  (g8/f2).
- Weights are a documented order-of-magnitude heuristic, explicitly NOT
  fitted and NOT validated against any outcome (g1). No pI band is
  hard-coded; net charge is a relative direction only.

It is a deterministic, transparent, weighted CHECKLIST over the spec's
cited public proxies P1-P7 (AAV9 VP3 frame PDB 3UX1 / DiMattia 2012;
VR-VIII 7-mer Chan 2017; RGD cardiac anchors Weinmann 2020 / Tabebordbar
2021; HS R585/R588 Kern 2003 / Opie 2003; AAV9 galactose pocket Shen
2011 / Bell 2012; anti-AAV9 NAb epitope Giles 2018 / Emmanuel 2022;
4.7 kb ssDNA cap Wu 2010 / Wang 2019). Positions are spec-cited
constants; the SCORED sequence is user input; the selftest uses a
clearly-labelled SYNTHETIC sequence (NOT real AAV9 VP1 — no reference
sequence is embedded or fabricated, g3).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys

# Canonical AA charge convention @ pH ~7.4 (fixed biochemistry, NOT fitted).
_CHARGE = {"D": -1, "E": -1, "K": +1, "R": +1, "H": 0}

# Spec-cited proxy positions (1-indexed VP1, AAV9/AAV2 numbering per spec).
HS_BASIC_POS = (585, 588, 484, 487, 527, 532)        # P4 Kern/Opie 2003
GAL_POCKET = {470: "N", 271: "D", 272: "N", 446: "Y", 503: "W"}  # P5 Shen/Bell
NAB_EPITOPE_POS = (496, 497, 498, 588, 589, 590, 591, 592, 454, 659)  # P6
VR_VIII_WINDOW = range(587, 591)                       # P2 Chan 2017 (587-590)
PACKAGING_CAP_BP = 4700                                # P7 Wu 2010 / Wang 2019

DEFAULT_WEIGHTS = {
    "seven_mer_display_ok": 0.30,    # structural prerequisite (gate-like)
    "hs_basic_cluster": 0.15,        # P4
    "gal_pocket_conserved": 0.15,    # P5 (AAV9 primary receptor footprint)
    "rgd_motif_present": 0.15,       # P3 (cardiac/muscle anchor common feature)
    "nab_epitope_divergence": 0.15,  # P6 (antigenic surface, normalized)
    "net_charge_direction": 0.10,    # weakest/indirect → lowest
}
WEIGHTS_STATUS = "documented-heuristic-NOT-fitted-NOT-validated"


def _at(seq: str, pos1: int) -> str:
    return seq[pos1 - 1] if 1 <= pos1 <= len(seq) else ""


def hs_basic_cluster(seq: str) -> bool:               # P4
    return all(_at(seq, p) in ("R", "K") for p in HS_BASIC_POS if _at(seq, p))


def gal_pocket_conserved(seq: str) -> bool:           # P5
    return all(_at(seq, p) == aa for p, aa in GAL_POCKET.items() if _at(seq, p))


def seven_mer_display_ok(peptide: str, pos: int, seqlen: int) -> bool:  # P2
    return len(peptide) == 7 and pos in VR_VIII_WINDOW and seqlen >= 736


def rgd_motif_present(peptide: str) -> bool:          # P3
    return "RGD" in peptide.upper()


def nab_epitope_divergence(seq: str, ref: str) -> int:  # P6 — descriptor only
    return sum(1 for p in NAB_EPITOPE_POS
               if _at(seq, p) and _at(ref, p) and _at(seq, p) != _at(ref, p))


def net_charge_direction(seq: str) -> float:          # relative direction only
    return float(sum(_CHARGE.get(a, 0) for a in seq.upper()))


def packaging_ok(payload_bp):                          # P7
    if payload_bp is None:
        return "not_evaluated"
    return int(payload_bp) <= PACKAGING_CAP_BP


def score(vp1: str, peptide: str, insert_pos: int = 588,
          payload_bp=None, ref_vp1: str = "", weights=None) -> dict:
    w = dict(DEFAULT_WEIGHTS)
    if weights:
        w.update(weights)
    f = {
        "seven_mer_display_ok": bool(seven_mer_display_ok(peptide, insert_pos, len(vp1))),
        "hs_basic_cluster": bool(hs_basic_cluster(vp1)),
        "gal_pocket_conserved": bool(gal_pocket_conserved(vp1)),
        "rgd_motif_present": bool(rgd_motif_present(peptide)),
        "nab_epitope_divergence": nab_epitope_divergence(vp1, ref_vp1) if ref_vp1 else 0,
        "net_charge_direction": net_charge_direction(vp1),
    }
    cite = {
        "seven_mer_display_ok": "P2 Chan 2017 Nat Neurosci",
        "hs_basic_cluster": "P4 Kern 2003 / Opie 2003 J Virol",
        "gal_pocket_conserved": "P5 Shen 2011 JBC / Bell 2012 J Virol",
        "rgd_motif_present": "P3 Weinmann 2020 Nat Commun / Tabebordbar 2021 Cell",
        "nab_epitope_divergence": "P6 Giles 2018 / Emmanuel 2022 J Virol",
        "net_charge_direction": "P4 (relative HS-electrostatic direction only)",
        "packaging_ok": "P7 Wu 2010 Mol Ther / Wang 2019 Nat Rev Drug Discov",
    }
    nab_norm = (f["nab_epitope_divergence"] / len(NAB_EPITOPE_POS)) if NAB_EPITOPE_POS else 0.0
    # net charge → relative 0..1 direction (sign only; magnitude capped, NOT a pI band)
    nc_dir = 1.0 if f["net_charge_direction"] > 0 else (0.0 if f["net_charge_direction"] < 0 else 0.5)
    contrib = {
        "seven_mer_display_ok": w["seven_mer_display_ok"] * (1.0 if f["seven_mer_display_ok"] else 0.0),
        "hs_basic_cluster": w["hs_basic_cluster"] * (1.0 if f["hs_basic_cluster"] else 0.0),
        "gal_pocket_conserved": w["gal_pocket_conserved"] * (1.0 if f["gal_pocket_conserved"] else 0.0),
        "rgd_motif_present": w["rgd_motif_present"] * (1.0 if f["rgd_motif_present"] else 0.0),
        "nab_epitope_divergence": w["nab_epitope_divergence"] * nab_norm,
        "net_charge_direction": w["net_charge_direction"] * nc_dir,
    }
    pkg = packaging_ok(payload_bp)
    aggregate = round(sum(contrib.values()), 6)
    flag = "packaging_fail" if pkg is False else "ok"
    vp1_hash = hashlib.sha256(vp1.encode()).hexdigest()[:16]
    return {
        "scaffold": "AAV9",
        "vp1_sha256_16": vp1_hash,
        "peptide": peptide, "insert_pos": insert_pos,
        "per_proxy": f, "per_proxy_citation": cite,
        "packaging_ok": pkg, "packaging_cap_bp": PACKAGING_CAP_BP,
        "weights": w, "weights_status": WEIGHTS_STATUS,
        "contributions": {k: round(v, 6) for k, v in contrib.items()},
        "aggregate_proxy_score": aggregate, "flag": flag,
        "honesty_banner": ("transparent bookkeeping over CITED public proxies; "
                           "NOT ML, NOT a proprietary reproduction, NOT a "
                           "tropism/efficacy/clinical prediction (g3/g8/f2); "
                           "weights " + WEIGHTS_STATUS),
    }


def _synthetic_vp1(n=736, mutate=None) -> str:
    """SYNTHETIC TEST SEQUENCE — NOT real AAV9 VP1. Deterministic filler with
    the spec-cited proxy positions set to documented-conserved residues so the
    feature-function LOGIC can be exercised; asserts nothing about real AAV9."""
    seq = list(("ACDEFGHIKLMNPQRSTVWY" * 40)[:n])
    for p in HS_BASIC_POS:
        seq[p - 1] = "R"
    for p, aa in GAL_POCKET.items():
        seq[p - 1] = aa
    if mutate:
        for p, aa in mutate.items():
            seq[p - 1] = aa
    return "".join(seq)


def _selfcheck() -> int:
    print("ml_capsid_fitness — drylab #11 · transparent public-proxy scorer\n")
    print("  [INFO] selftest uses a SYNTHETIC sequence — NOT real AAV9 VP1; "
          "no reference sequence embedded/fabricated (g3).")
    ref = _synthetic_vp1()                              # synthetic 'baseline'
    # AAV9-baseline-like: conserved proxies, non-RGD 7-mer at 588.
    base = score(ref, "AAAAAAA", 588, payload_bp=4200, ref_vp1=ref)
    # Engineered-positive-like: RGD 7-mer (P3 cardiac anchor) at 588.
    eng = score(_synthetic_vp1(mutate={496: "Q"}), "ARGDLGS", 588,
                payload_bp=4200, ref_vp1=ref)
    det = (score(ref, "AAAAAAA", 588, payload_bp=4200, ref_vp1=ref)
           == base)

    print(f"  baseline   agg={base['aggregate_proxy_score']:.3f}  "
          f"7mer_ok={base['per_proxy']['seven_mer_display_ok']} "
          f"hs={base['per_proxy']['hs_basic_cluster']} "
          f"gal={base['per_proxy']['gal_pocket_conserved']} "
          f"rgd={base['per_proxy']['rgd_motif_present']}")
    print(f"  engineered agg={eng['aggregate_proxy_score']:.3f}  "
          f"rgd={eng['per_proxy']['rgd_motif_present']} "
          f"nab_div={eng['per_proxy']['nab_epitope_divergence']}")
    print(f"  weights_status = {base['weights_status']}")
    print(f"  honesty: {base['honesty_banner']}")

    # Acceptance (NOT a tropism claim): scorer self-consistent —
    #  (i) deterministic; (ii) adding the cited RGD anchor RAISES the
    #  documented-proxy bookkeeping (more cited proxies matched);
    #  (iii) packaging hard-gate fires on oversized cargo.
    raised = eng["aggregate_proxy_score"] > base["aggregate_proxy_score"]
    over = score(ref, "AAAAAAA", 588, payload_bp=9000, ref_vp1=ref)
    gate = (over["flag"] == "packaging_fail")
    print(f"\n  det={det} · RGD raises proxy-count={raised} · "
          f"packaging hard-gate(9000bp)={gate}")
    ok = det and raised and gate and base["weights_status"] == WEIGHTS_STATUS
    print("  [honesty] documented-proxy bookkeeping only — NOT ML, NOT "
          "proprietary reproduction, NOT tropism/efficacy (g3/g8/f2). "
          "See ../research/ml_capsid_fitness.md.")
    print("\n__DRYLAB_ML_CAPSID_FITNESS__ PASS" if ok
          else "\n__DRYLAB_ML_CAPSID_FITNESS__ FAIL")
    return 0 if ok else 1


def _main() -> int:
    ap = argparse.ArgumentParser(description="transparent public-proxy AAV9 capsid scorer (NOT ML, NOT a predictor)")
    ap.add_argument("--vp1"); ap.add_argument("--peptide", default="")
    ap.add_argument("--insert-pos", type=int, default=588)
    ap.add_argument("--ref", default="AAV9")
    ap.add_argument("--ref-vp1", default="")
    ap.add_argument("--payload-bp", type=int, default=None)
    ap.add_argument("--weights")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest or not a.vp1:
        return _selfcheck()
    if a.ref != "AAV9":
        print("refuse: only AAV9 scaffold supported (cited proxy positions are "
              "AAV9/AAV2-numbered; refusing to guess other scaffolds — g3)", file=sys.stderr)
        return 2
    w = json.load(open(a.weights)) if a.weights else None
    print(json.dumps(score(a.vp1, a.peptide, a.insert_pos, a.payload_bp,
                            a.ref_vp1, w), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(_main())
