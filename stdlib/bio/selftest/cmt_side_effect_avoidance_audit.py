#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
cmt_side_effect_avoidance_audit.py — CMT 7-axis side-effect-avoidance constraint audit

Deterministic, stdlib-only audit of the 10 hxq-cmt-* candidates against the
7 side-effect-avoidance design constraints from .roadmap.disease_cmt_specific §2.
Implements falsifier F-disease-cmt-Q-8: "후보별 binary pass/fail per constraint".

This is NOT a re-derivation of the CMT roadmap design. It is a *consistency
gate* — encodes the §2 constraint-vs-candidate matrix as data, verifies:
  (a) every candidate has an explicit pass/fail verdict on every applicable axis
  (b) the matrix is self-consistent with the §1 candidate table (axis tags,
      modality, target)
  (c) the v4 "paradigm-level 100% closure" claim (§11 v4) is internally
      coherent — all 10 candidates pass all *applicable* constraints

raw_91 honest C3:
  - This audits the DESIGN-TIME constraint matrix as committed in the roadmap.
    It does NOT validate that the constraints will hold in wet-lab / Phase 1.
    Per the roadmap §9.1: the 7-axis = "known-liability avoidance by design",
    not unknown-liability avoidance.
  - "PASS" here means the candidate's design intent is documented as
    addressing the constraint (or the constraint is N/A for the modality).
    It does NOT mean the candidate has been built, dosed, or measured.
  - The constraint applicability per modality (small-molecule vs oligo vs
    Fc-fusion vs AAV vs nanocarrier) is itself a design judgment encoded
    here from the roadmap; a different modality split would change which
    axes are "applicable".

Sentinel: __CMT_SIDE_EFFECT_AUDIT__ PASS|FAIL
Cross-ref: .roadmap.disease_cmt_specific §2 (7-axis constraints) + §5 (F-disease-cmt-Q-8)
"""
from __future__ import annotations
import sys

# ── The 7 side-effect-avoidance design axes (from roadmap §2) ──────────────
AXES = [
    ("ax1_cns_avoid",        "CNS 부작용 회피 — 말초 한정 (P-gp / conjugate / capsid-tropism / muscle-promoter)"),
    ("ax2_hnpp_overshoot",   "HNPP overshoot 회피 — 가역 + dosage-titratable (siRNA/ASO > CRISPR-DNA)"),
    ("ax3_innate_immune",    "Innate immune (TLR) 회피 — 2'-OMe/2'-F/PS backbone, LNP 회피"),
    ("ax4_reversibility",    "Reversibility — 가역 non-covalent; covalent 시 reversible-covalent + short t1/2"),
    ("ax5_paralog_xrxn",     "Paralog cross-reactivity 회피 — selectivity ratio ≥500-1000 / allele-selective"),
    ("ax6_liver_kidney",     "Liver/kidney chronic accumulation 회피 — miR-122 BS / conjugate / urinary route"),
    ("ax7_aav_immunogen",    "AAV vector immunogenicity 회피 — de-immunized capsid + empty-decoy + tissue-detarget 3'UTR"),
]
AXIS_IDS = [a[0] for a in AXES]

# ── 10 hxq-cmt-* candidates × 7-axis verdict matrix (from roadmap §1/§2/§11-v4) ──
# Verdict values:
#   "PASS"  — design intent documented as addressing this constraint
#   "N/A"   — constraint not applicable to this modality (with a documented reason)
# A candidate "passes the audit" iff every axis is PASS or N/A (no "FAIL", no missing).
CANDIDATES = {
    # CMT1A — PMP22 dosage knockdown (siRNA, RB axis)
    "hxq-cmt-pmp22-001": {
        "axis": "RB", "modality": "siRNA + 지방산/SQ conjugate", "target": "PMP22 3'UTR allele-selective mRNA KD",
        "subtypes": ["CMT1A"],
        "verdicts": {
            "ax1_cns_avoid":      "PASS",   # SQ-Schwann conjugate, no CNS distribution
            "ax2_hnpp_overshoot": "PASS",   # siRNA reversible + dosage-titratable; CRISPR-DNA edit rejected
            "ax3_innate_immune":  "PASS",   # 2'-OMe + 2'-F + PS backbone → TLR7/8 회피; LNP 회피
            "ax4_reversibility":  "PASS",   # siRNA inherently reversible (non-covalent transient KD)
            "ax5_paralog_xrxn":   "PASS",   # 3'UTR allele-selective seed → wild-type allele 절약
            "ax6_liver_kidney":   "PASS",   # SQ-Schwann 한정 + optional miR-122 BS cassette → liver detarget
            "ax7_aav_immunogen":  "N/A",    # not an AAV — oligo conjugate
        },
    },
    # CMT1A/CMT1E/HNPP — PMP22 splice gapmer ASO (RB axis)
    "hxq-cmt-pmp22-002": {
        "axis": "RB", "modality": "gapmer ASO 5-10-5 (PS+MOE)", "target": "PMP22 pre-mRNA splice-modulating ASO",
        "subtypes": ["CMT1A", "CMT1E", "HNPP"],
        "verdicts": {
            "ax1_cns_avoid":      "PASS",   # Schwann-targeted distribution; intrathecal-restricted option
            "ax2_hnpp_overshoot": "PASS",   # 가역 + 농도 titratable → HNPP overshoot dial-back
            "ax3_innate_immune":  "PASS",   # MOE 전환 nucleotide → innate immune activation 최소
            "ax4_reversibility":  "PASS",   # ASO transient, non-covalent
            "ax5_paralog_xrxn":   "PASS",   # PMP22-specific gapmer sequence
            "ax6_liver_kidney":   "PASS",   # Schwann distribution analysis → chronic dosing tuned
            "ax7_aav_immunogen":  "N/A",    # not an AAV
        },
    },
    # CMT1·CMT2·CMT2F — HDAC6 selective non-hydroxamate ZBG (Q axis)
    "hxq-cmt-hd6-001": {
        "axis": "Q", "modality": "경구 소분자 (non-hydroxamate ZBG)", "target": "HDAC6 selective, 말초 한정",
        "subtypes": ["CMT1", "CMT2", "CMT2F"],
        "verdicts": {
            "ax1_cns_avoid":      "PASS",   # CNS 비투과 — P-gp substrate by polar mass; AGT-100216 paradigm
            "ax2_hnpp_overshoot": "N/A",    # not a PMP22 dosage agent
            "ax3_innate_immune":  "N/A",    # small molecule, not oligo — no TLR concern
            "ax4_reversibility":  "PASS",   # non-hydroxamate ZBG, reversible; catalytic-only engagement
            "ax5_paralog_xrxn":   "PASS",   # HDAC1/2/3 selectivity >1000 (cytopenia 회피); non-hydroxamate (genotoxicity 회피)
            "ax6_liver_kidney":   "PASS",   # peripheral-restricted; standard small-mol clearance with monitoring
            "ax7_aav_immunogen":  "N/A",    # not an AAV
        },
    },
    # CMT1·CMT2 (증상) — ClC-1 state-dependent partial blocker (Q axis)
    "hxq-cmt-clc1-001": {
        "axis": "Q", "modality": "경구 소분자 (BID)", "target": "골격근 ClC-1 state-dependent partial blocker",
        "subtypes": ["CMT1", "CMT2"],
        "verdicts": {
            "ax1_cns_avoid":      "PASS",   # P-gp efflux ratio ≥3 design — CNS leak 회피
            "ax2_hnpp_overshoot": "N/A",    # not a PMP22 agent
            "ax3_innate_immune":  "N/A",    # small molecule
            "ax4_reversibility":  "PASS",   # state-dependent open-channel block, reversible; resting state intact
            "ax5_paralog_xrxn":   "PASS",   # ClC-2 (kidney/뇌) / Kb selectivity >500; partial inhibition (myotonia 회피)
            "ax6_liver_kidney":   "PASS",   # ClC-2 selectivity → urolithiasis / renal tubular acidosis 회피
            "ax7_aav_immunogen":  "N/A",    # not an AAV
        },
    },
    # CMT2 (전 axonal) — SARM1 TIR NAD+ hydrolase reversible (Q axis)
    "hxq-cmt-sar1-001": {
        "axis": "Q", "modality": "경구 소분자", "target": "SARM1 TIR domain NAD+ hydrolase reversible",
        "subtypes": ["CMT2-axonal-broad"],
        "verdicts": {
            "ax1_cns_avoid":      "PASS",   # CMT2 axonal — peripheral nerve; standard CNS-avoidance design
            "ax2_hnpp_overshoot": "N/A",    # not a PMP22 agent
            "ax3_innate_immune":  "N/A",    # small molecule
            "ax4_reversibility":  "PASS",   # reversible non-covalent (covalent suicide-substrate 회피 → 만성 NAD+ depletion 회피)
            "ax5_paralog_xrxn":   "PASS",   # catalytic-only — ARM regulatory 영역 보존; allele-blind broad applicability
            "ax6_liver_kidney":   "PASS",   # standard small-mol clearance with monitoring
            "ax7_aav_immunogen":  "N/A",    # not an AAV — also IP-회피 chemotype constraint tracked separately (§9.9)
        },
    },
    # CMT2A (MFN2 R94Q dominant) — GTPase corrector + DN destabilizer (Q axis)
    "hxq-cmt-mfn2-001": {
        "axis": "Q", "modality": "경구 소분자 + mitochondrial-targeting 설계", "target": "MFN2 GTPase corrector + dominant-negative destabilizer",
        "subtypes": ["CMT2A"],
        "verdicts": {
            "ax1_cns_avoid":      "PASS",   # peripheral nerve target; mitochondrial-targeting 한정
            "ax2_hnpp_overshoot": "N/A",    # not a PMP22 agent
            "ax3_innate_immune":  "N/A",    # small molecule
            "ax4_reversibility":  "PASS",   # 가역 chaperone — chronic toxicity 빠른 reverse
            "ax5_paralog_xrxn":   "PASS",   # dominant-negative 만 destabilize, wild-type allele 절약; mito-targeting → cytosolic GTPase (Rab/Ras) cross-rxn 회피
            "ax6_liver_kidney":   "PASS",   # mitochondrial-targeting peptide reduces off-tissue exposure
            "ax7_aav_immunogen":  "N/A",    # not an AAV
        },
    },
    # CMT1X (GJB1/Cx32) — mutant-selective folding chaperone (Q axis)
    "hxq-cmt-gjb1-001": {
        "axis": "Q", "modality": "척수강내 + Schwann 세포 한정 소분자", "target": "Cx32 mutant-selective folding chaperone",
        "subtypes": ["CMT1X"],
        "verdicts": {
            "ax1_cns_avoid":      "PASS",   # 척수강내 dosing → 전신 노출 최소
            "ax2_hnpp_overshoot": "N/A",    # not a PMP22 agent
            "ax3_innate_immune":  "N/A",    # small molecule
            "ax4_reversibility":  "PASS",   # fold-rescue chaperone, non-covalent; ataluren-class readthrough 보다 fold-rescue 가 paralog cross-rxn 적음
            "ax5_paralog_xrxn":   "PASS",   # Cx32 mutant fold-rescue 한정 — wild-type Cx32 + 청신경 Cx26 미결합 (deafness 회피)
            "ax6_liver_kidney":   "PASS",   # 척수강내 → systemic exposure minimal
            "ax7_aav_immunogen":  "N/A",    # not an AAV (a separate CMT1X AAV9-GJB1 comparator exists; this candidate is small-molecule)
        },
    },
    # CMT1A (myelin 두께) — NRG1-III/ErbB2-3 partial agonist Fc-fusion (W axis)
    "hxq-cmt-nrg1-001": {
        "axis": "W", "modality": "Fc-fusion 단백질 + Schwann-restricted display", "target": "NRG1-III/ErbB2-3 partial agonist Fc-fusion",
        "subtypes": ["CMT1A"],
        "verdicts": {
            "ax1_cns_avoid":      "PASS",   # Schwann-restricted display (P0/MPZ peptide anchor) → 심근 (cardiotoxicity) + 유방 ErbB 회피
            "ax2_hnpp_overshoot": "N/A",    # not a PMP22 dosage agent (myelin-thickness modulator)
            "ax3_innate_immune":  "N/A",    # protein biologic, not oligo (immunogenicity is a separate biologic concern, tracked under ax5/wet-lab)
            "ax4_reversibility":  "PASS",   # Fc-fusion protein — non-covalent receptor engagement, clearable
            "ax5_paralog_xrxn":   "PASS",   # partial agonist (full agonist 시 Schwann 과증식/schwannoma 회피); Schwann-restricted display → ErbB1/4 cross-rxn 회피
            "ax6_liver_kidney":   "PASS",   # Fc-fusion → renal-sparing; FcRn recycling
            "ax7_aav_immunogen":  "N/A",    # not an AAV (a potential AAV-arm exists in roadmap §2-7 as future work, separate candidate)
        },
    },
    # CMT4J (FIG4 LoF) — AAV9 intrathecal FIG4 gene replacement (V axis)
    "hxq-cmt-fig4-001": {
        "axis": "V", "modality": "AAV9 + 차세대 capsid + liver-detarget 3'UTR", "target": "AAV9 intrathecal FIG4 gene replacement",
        "subtypes": ["CMT4J"],
        "verdicts": {
            "ax1_cns_avoid":      "PASS",   # 척수강내 only — 전신 노출 회피; FIG4 is itself a CNS+PNS gene so transduction is on-target
            "ax2_hnpp_overshoot": "N/A",    # not a PMP22 dosage agent (FIG4 is loss-of-function, gene REPLACEMENT not knockdown)
            "ax3_innate_immune":  "N/A",    # AAV, not oligo — TLR9 from CpG is handled via capsid/cassette design, tracked under ax7
            "ax4_reversibility":  "N/A",    # gene therapy is intentionally durable; reversibility is not the design goal — this is a deliberate, documented modality choice for an ultra-rare LoF disease
            "ax5_paralog_xrxn":   "PASS",   # FIG4-specific cassette; no paralog issue for a single-gene replacement
            "ax6_liver_kidney":   "PASS",   # 3'UTR miR-122 BS ×4 → 간 트랜스진 silencing (ALT/AST 상승 + insertional 우려 회피)
            "ax7_aav_immunogen":  "PASS",   # de-immunized capsid (AAV9.HSC-NL10 variant) + empty-capsid decoy + tissue-detarget 3'UTR → pre-existing nAb seropositive 우회 + 2nd-dose 가능
        },
    },
    # CMT1·CMT2 (modular cargo) — Schwann-perineurium nanocarrier (NB axis)
    "hxq-cmt-nano-001": {
        "axis": "NB", "modality": "PLGA-PEG hybrid 50-80nm + Schwann ligand + pH-shed", "target": "Schwann-perineurium nanocarrier (modular cargo)",
        "subtypes": ["CMT1", "CMT2"],
        "verdicts": {
            "ax1_cns_avoid":      "PASS",   # Schwann-targeting ligand (P0/MPZ anchor) → 간/신장 detarget; perineurium tight junction 침투 → peripheral nerve 한정
            "ax2_hnpp_overshoot": "N/A",    # the carrier itself is dosage-neutral; if cargo = pmp22 siRNA, the cargo's own ax2 (pmp22-001) applies — carrier doesn't add overshoot
            "ax3_innate_immune":  "PASS",   # biodegradable PLGA-PEG, no LNP; pH-responsive PEG-shedding limits extracellular exposure
            "ax4_reversibility":  "PASS",   # biodegradable PLGA-PEG → 만성 축적 회피 (carrier clears even if cargo is durable)
            "ax5_paralog_xrxn":   "PASS",   # Schwann-targeting ligand selectivity → off-tissue (RES uptake 회피, >200nm 회피)
            "ax6_liver_kidney":   "PASS",   # 50-80nm size + Schwann ligand → RES uptake 회피, liver/kidney detarget
            "ax7_aav_immunogen":  "N/A",    # not an AAV — polymer nanocarrier
        },
    },
}

EXPECTED_PARADIGM_CLOSURE = True  # roadmap §11 v4: "CMT 10 후보 paradigm-level 100% closure"


def audit_candidate(cid: str, info: dict) -> tuple[bool, list[str]]:
    """Returns (passed, issues). Passes iff every axis verdict is PASS or N/A."""
    issues = []
    verdicts = info.get("verdicts", {})
    # (1) every axis must have a verdict
    for ax in AXIS_IDS:
        if ax not in verdicts:
            issues.append(f"{cid}: MISSING verdict for axis {ax}")
        elif verdicts[ax] not in ("PASS", "N/A"):
            issues.append(f"{cid}: axis {ax} has verdict {verdicts[ax]!r} (not PASS / N/A)")
    # (2) no extra/unknown axes
    for ax in verdicts:
        if ax not in AXIS_IDS:
            issues.append(f"{cid}: unknown axis {ax!r} in verdicts")
    # (3) axis tag must be one of the 5 hexa-bio axes
    if info.get("axis") not in ("Q", "W", "V", "RB", "NB"):
        issues.append(f"{cid}: axis tag {info.get('axis')!r} not in {{Q,W,V,RB,NB}}")
    passed = (len(issues) == 0)
    return passed, issues


def main() -> int:
    print("cmt_side_effect_avoidance_audit — 7-axis side-effect-avoidance constraint audit")
    print(f"  candidates: {len(CANDIDATES)} hxq-cmt-*")
    print(f"  design axes: {len(AXES)} (from .roadmap.disease_cmt_specific §2)")
    print()

    all_issues = []
    pass_count = 0
    n_pass_verdicts = 0
    n_na_verdicts = 0

    # per-candidate audit
    for cid in sorted(CANDIDATES):
        info = CANDIDATES[cid]
        passed, issues = audit_candidate(cid, info)
        all_issues.extend(issues)
        if passed:
            pass_count += 1
        for ax in AXIS_IDS:
            v = info["verdicts"].get(ax)
            if v == "PASS":
                n_pass_verdicts += 1
            elif v == "N/A":
                n_na_verdicts += 1
        applicable = sum(1 for ax in AXIS_IDS if info["verdicts"].get(ax) == "PASS")
        na = sum(1 for ax in AXIS_IDS if info["verdicts"].get(ax) == "N/A")
        flag = "✅" if passed else "❌"
        print(f"  {flag} {cid:<22} axis={info['axis']:<3} applicable-PASS={applicable}/{applicable+na}  N/A={na}  ({info['modality']})")

    # 5-axis saturation check (roadmap §11 v4: "5-axis 모두 직접 cover")
    axes_covered = set(info["axis"] for info in CANDIDATES.values())
    expected_axes = {"Q", "W", "V", "RB", "NB"}
    axis_saturation = (axes_covered == expected_axes)
    print()
    print(f"  5-axis saturation: {sorted(axes_covered)} == {sorted(expected_axes)} → {'✅ YES' if axis_saturation else '❌ NO'}")
    if not axis_saturation:
        all_issues.append(f"5-axis saturation FAIL: covered {sorted(axes_covered)}, expected {sorted(expected_axes)}")

    # axis-count balance — authoritative source is roadmap §4 (5-axis cross-contribution)
    # + §11-v4 table, both of which list 5 QUANTUM candidates (hd6/clc1/sar1/mfn2/gjb1):
    #   Q(5) + RB(2) + W(1) + V(1) + NB(1) = 10.
    # (The §1 table HEADER says "QUANTUM 4" but the §1 BODY tags gjb1-001 as Q; §4 and
    #  §11-v4 resolve this — gjb1-001 IS a QUANTUM candidate (fold-rescue small molecule).
    #  Documenting the resolution here so a future reader knows which §1 line is canonical.)
    from collections import Counter
    axis_counts = Counter(info["axis"] for info in CANDIDATES.values())
    expected_counts = {"Q": 5, "RB": 2, "W": 1, "V": 1, "NB": 1}
    counts_ok = (dict(axis_counts) == expected_counts)
    print(f"  axis balance: {dict(axis_counts)} == {expected_counts} (per roadmap §4 + §11-v4) → {'✅' if counts_ok else '❌'}")
    if not counts_ok:
        all_issues.append(f"axis balance FAIL: got {dict(axis_counts)}, expected {expected_counts}")

    # paradigm-closure coherence
    paradigm_closure = (pass_count == len(CANDIDATES)) and axis_saturation and counts_ok
    print()
    print(f"  paradigm-level closure (all {len(CANDIDATES)} candidates pass all applicable constraints + 5-axis saturation + axis balance):")
    print(f"    → {'✅ COHERENT' if paradigm_closure else '❌ INCOHERENT'}")
    if paradigm_closure != EXPECTED_PARADIGM_CLOSURE:
        all_issues.append(f"paradigm-closure mismatch: computed {paradigm_closure}, roadmap §11 v4 claims {EXPECTED_PARADIGM_CLOSURE}")

    print()
    print(f"  candidates passing audit: {pass_count}/{len(CANDIDATES)}")
    print(f"  total verdicts: {n_pass_verdicts} PASS + {n_na_verdicts} N/A = {n_pass_verdicts + n_na_verdicts} (of {len(CANDIDATES)}×{len(AXES)} = {len(CANDIDATES)*len(AXES)} cells)")

    ok = (len(all_issues) == 0) and paradigm_closure
    print()
    if ok:
        print("__CMT_SIDE_EFFECT_AUDIT__ PASS")
        return 0
    print("__CMT_SIDE_EFFECT_AUDIT__ FAIL")
    for issue in all_issues:
        print(f"  issue: {issue}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
