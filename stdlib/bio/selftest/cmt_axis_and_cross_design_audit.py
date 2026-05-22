#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
cmt_axis_and_cross_design_audit.py — CMT per-axis + cross-axis design-audit gates

Implements the remaining in-repo-closeable CMT falsifiers from
.roadmap.disease_cmt_specific §5:
  F-disease-cmt-W-1   — hxq-cmt-nrg1-001 (WEAVE — Schwann-restricted Fc-fusion)
  F-disease-cmt-V-1   — hxq-cmt-fig4-001 (VIROCAPSID — AAV9 de-immunized + miR-122 detarget)
  F-disease-cmt-RB-1  — hxq-cmt-pmp22-001/002 (RIBOZYME — siRNA conjugate + gapmer ASO)
  F-disease-cmt-NB-1  — hxq-cmt-nano-001 (NANOBOT — PLGA-PEG nanocarrier, modular cargo)
  F-disease-cmt-cross-1 — hd6-001 + pmp22-001 + EN001(comparator) demyelinating combo
  F-disease-cmt-cross-2 — sar1-001 + nrg1-001 axonal-CMT2 neuroprotection+regeneration combo

These are DESIGN-AUDIT gates (deterministic, stdlib-only) — they verify that
each candidate's modality-specific spec axis (Fc-fusion display / AAV cassette /
oligo backbone+conjugate / nanocarrier physchem) is documented + coherent with
the roadmap §1/§2/§4/§11-v4, and that the cross-axis combos are mechanistically
distinct + non-overlapping (the roadmap's combo rationale encoded as data).

raw_91 honest C3:
  - DESIGN-AUDIT, not VQE-binding / wet-lab. "PASS" means the candidate's
    modality-specific design intent (the spec-axis fields the roadmap commits)
    is present + internally coherent. It does NOT mean the construct has been
    built / expressed / folded / dosed / measured.
  - The modality-specific spec axes (W: Schwann-display + partial-agonism + ErbB-
    cross-rxn; V: AAV cassette + miR-122-BS + de-immunized capsid + IT-only +
    empty-decoy; RB: backbone-chem + conjugate + allele-selectivity + HNPP-dial-
    back; NB: size + biodegradability + targeting-ligand + pH-shed + modular-
    cargo) are themselves design judgments from the roadmap; a different spec
    axis would change which fields are "required".
  - The cross-axis combos (cross-1 demyelinating: hd6+pmp22+EN001; cross-2
    axonal: sar1+nrg1) are the roadmap's stated combo arms; the audit checks
    that the combined candidates target distinct mechanisms (no double-counting
    a single mechanism as a "combo"), not that the combo has been tested.

Sentinel: __CMT_AXIS_CROSS_DESIGN_AUDIT__ PASS|FAIL
Cross-ref: .roadmap.disease_cmt_specific §5 (F-disease-cmt-W-1/V-1/RB-1/NB-1/cross-1/cross-2)
           + §4 (5-axis cross-contribution) + §11-v4 (paradigm closure)
"""
from __future__ import annotations
import sys

# ── F-disease-cmt-W-1: WEAVE — hxq-cmt-nrg1-001 Schwann-restricted Fc-fusion ──
# Required spec-axis fields for a WEAVE protein-composition candidate (per §1/§2-1/§2-5/§11-v4):
W1_NRG1 = {
    "candidate": "hxq-cmt-nrg1-001",
    "axis": "W",
    "subtype": "CMT1A (myelin 두께)",
    "modality": "Fc-fusion 단백질 + Schwann-restricted display",
    "composition": "NRG1-III EGF domain + Fc + P0/MPZ Schwann-targeting peptide (variant land §11-v4)",
    "spec_axis": {
        "schwann_restricted_display": True,   # P0/MPZ peptide anchor → cardiotoxicity (트라스투주맙 교훈) + 유방 ErbB 회피
        "partial_agonist": True,              # full agonist 시 Schwann 과증식 (schwannoma) 회피
        "fc_fusion_halflife_extension": True, # 반감기 연장 → 저빈도 dosing
        "erbb1_4_cross_rxn_avoidance": True,  # ErbB2-3 only (Schwann-restricted display does this)
        "cardiotoxicity_avoidance": True,     # Schwann-restricted → 심근 ErbB 회피
    },
    "comparator": "NT-3 protein arm",
    "wet_lab_residual": "partial agonist 강도 dose-response (schwannoma 회피 window) + ErbB1/4 cross-rxn panel + cardiac safety",  # (c) out-of-software-scope
}

# ── F-disease-cmt-V-1: VIROCAPSID — hxq-cmt-fig4-001 AAV9 de-immunized + miR-122 detarget ──
V1_FIG4 = {
    "candidate": "hxq-cmt-fig4-001",
    "axis": "V",
    "subtype": "CMT4J (FIG4 LoF)",
    "modality": "AAV9 + 차세대 capsid + liver-detarget 3'UTR",
    "composition": "AAV9-CAG-FIG4-WPRE + 4×miR-122 BS + AAV9.HSC-NL10 de-immunized VP3 (variant land §11-v4)",
    "spec_axis": {
        "cassette_complete": True,            # CAG promoter + FIG4 CDS + WPRE
        "mir122_bs_count": 4,                 # 3'UTR miR-122 binding sites ×4 → 간 트랜스진 silencing (ALT/AST + insertional 회피)
        "deimmunized_capsid": True,           # AAV9.HSC-NL10 variant → pre-existing nAb seropositive 우회
        "intrathecal_only": True,             # 전신 노출 회피 → 면역원성 최소화; FIG4 is CNS+PNS gene so transduction on-target
        "empty_capsid_decoy": True,           # 2nd-dose 가능성
        "gene_replacement_not_knockdown": True,  # FIG4 is LoF → REPLACEMENT (no HNPP-style overshoot concern — FIG4 isn't a dosage-overexpression disease)
    },
    "comparator": "ELP-02 (Elpida, AAV9-FIG4 intrathecal)",
    "wet_lab_residual": "NHP IT durability + seropositive cohort 30→70% expansion + insertional safety",  # (c) out-of-software-scope
}

# ── F-disease-cmt-RB-1: RIBOZYME — hxq-cmt-pmp22-001 (siRNA) + pmp22-002 (gapmer ASO) ──
RB1_PMP22_001 = {
    "candidate": "hxq-cmt-pmp22-001",
    "axis": "RB",
    "subtype": "CMT1A (PMP22 dup)",
    "modality": "siRNA + 지방산/스쿠알렌 conjugate (Schwann 향)",
    "composition": "21nt antisense seed scaffold (Phase β specify) + GalNAc/SQ-alternative conjugate",
    "spec_axis": {
        "allele_selective_seed": True,        # 3'UTR allele-selective → wild-type allele 절약
        "backbone_chem": "2'-OMe + 2'-F + PS",  # TLR7/8 회피 (innate immune)
        "schwann_conjugate": "fatty-acid / squalene (SQ)",  # Schwann 한정 → 간 detarget
        "mir122_bs_cassette_option": True,    # optional miR-122 BS cassette → liver detarget reinforce
        "dosage_titratable": True,            # siRNA reversible — HNPP overshoot dial-back; CRISPR-DNA 영구편집 회피
        "lnp_avoidance": True,                # conjugate (not LNP) → chronic dosing safety
    },
    "comparator": "DTx-1252 (Novartis FALCON 지방산-리간드 siRNA), SQ-siRNA (Inserm/CNRS)",
}
RB1_PMP22_002 = {
    "candidate": "hxq-cmt-pmp22-002",
    "axis": "RB",
    "subtype": "CMT1A / CMT1E / HNPP",
    "modality": "gapmer ASO 5-10-5 (PS+MOE) — Cas13 RNA-targeting 대체 옵션",
    "composition": "18-mer gapmer 5-10-5 (PS backbone + MOE wings) (Phase β specify)",
    "spec_axis": {
        "gapmer_design": "5-10-5",            # 5 MOE / 10 DNA gap / 5 MOE
        "backbone_chem": "PS + MOE",          # MOE 전환 nucleotide → innate immune activation 최소
        "splice_modulating_or_rnase_h": True, # PMP22 pre-mRNA splice-modulating ASO (transient)
        "dosage_titratable": True,            # 가역 + 농도 titratable → HNPP overshoot dial-back
        "schwann_distribution_analysis": True,  # → chronic dosing 미세조정
        "crispr_dna_edit_avoidance": True,    # gapmer ASO transient, not permanent DNA edit
    },
    "comparator": "Ionis/학계 PMP22-ASO PoC (Svaren·Kleopa 2018 STM)",
}

# ── F-disease-cmt-NB-1: NANOBOT — hxq-cmt-nano-001 PLGA-PEG nanocarrier, modular cargo ──
NB1_NANO = {
    "candidate": "hxq-cmt-nano-001",
    "axis": "NB",
    "subtype": "CMT1·CMT2 (cargo modular: pmp22 siRNA / hd6 small mol / NT-3 펩티드)",
    "modality": "PLGA-PEG hybrid nanocarrier 50-80nm, modular cargo",
    "composition": "PLGA-PEG hybrid + P0/MPZ Schwann-targeting ligand (variant land §11-v4) + pH-cleavable PEG + modular cargo",
    "spec_axis": {
        "size_nm_min": 50, "size_nm_max": 80,  # perineurium tight junction 침투, RES uptake 회피 (>200nm 회피)
        "schwann_targeting_ligand": "P0/MPZ surface anchor (or GalNAc-class)",  # 간/신장 detarget
        "biodegradable_plga_peg": True,       # 만성 축적 회피
        "ph_responsive_peg_shedding": True,   # extracellular 안정 + intracellular 방출 → off-target 노출 최소
        "modular_cargo": ["pmp22 siRNA", "hd6 small mol", "NT-3 peptide"],  # multi-axis combo platform
        "perineurium_penetration": True,      # tight junction 투과 (50-80nm size optimum)
    },
    "comparator": "preclinical Schwann-tropic nanocarrier (학계)",
    "wet_lab_residual": "Schwann-targeting ligand selectivity + perineurium ex-vivo perfusion + pH-shedding kinetics + RES uptake assay + modular cargo loading efficiency",  # (c) out-of-software-scope
}

# ── F-disease-cmt-cross-1: demyelinating multi-mechanism combo ──
CROSS1 = {
    "name": "F-disease-cmt-cross-1",
    "scope": "탈수초형 (demyelinating) CMT multi-mechanism cross-axis pilot",
    "members": [
        ("hxq-cmt-hd6-001", "Q",  "HDAC6 axonal-transport 회복 — α-tubulin 아세틸화 (말초 한정 non-hydroxamate)"),
        ("hxq-cmt-pmp22-001", "RB", "PMP22 mRNA 3'UTR allele-selective knockdown — dosage correction (siRNA reversible)"),
        ("EN001", "comparator-cell", "MSC secretome — Schwann remyelination support (mechanistically distinct from hd6/pmp22; ENCell Ph1 9pts CMT1A CMTNSv2 −2.89)"),
    ],
    "distinctness_claim": "3 distinct mechanisms: (1) microtubule-acetylation transport rescue, (2) PMP22-mRNA dosage correction, (3) MSC-secretome remyelination support — no two members target the same mechanism, so the combo is genuinely additive, not a re-label.",
    "wet_lab_residual": "combo / sequencing dose-finding + drug-drug interaction + temporal staging",  # (c)
}
# ── F-disease-cmt-cross-2: axonal CMT2 neuroprotection + regeneration combo ──
CROSS2 = {
    "name": "F-disease-cmt-cross-2",
    "scope": "축삭형 (axonal) CMT2 neuroprotection + regeneration cross-axis pilot",
    "members": [
        ("hxq-cmt-sar1-001", "Q", "SARM1 TIR NAD+ hydrolase reversible inhibition — Wallerian-degeneration block (neuroPROTECTION; allele-blind broad CMT2 applicability)"),
        ("hxq-cmt-nrg1-001", "W", "NRG1-III/ErbB2-3 partial agonist Fc-fusion — Schwann-driven remyelination / regeneration support (neuroREGENERATION)"),
    ],
    "distinctness_claim": "2 distinct mechanisms: (1) axon-survival via SARM1 inhibition (prevents degeneration), (2) regeneration support via NRG1-III (rebuilds myelin on surviving axons) — protection ≠ regeneration; the combo addresses both halves of the axonal-CMT2 lesion.",
    "wet_lab_residual": "combo timing (protect-then-regenerate sequencing) + Schwann/axon co-culture validation",  # (c)
}


def audit_axis_candidate(spec: dict) -> tuple[bool, list[str]]:
    """Verify a per-axis candidate spec is complete + coherent."""
    issues = []
    cid = spec.get("candidate", "?")
    # required top-level fields
    for f in ("candidate", "axis", "subtype", "modality", "composition", "spec_axis", "comparator"):
        if f not in spec:
            issues.append(f"{cid}: missing top-level field {f!r}")
    # axis must be one of the 5
    if spec.get("axis") not in ("Q", "W", "V", "RB", "NB"):
        issues.append(f"{cid}: axis {spec.get('axis')!r} not in {{Q,W,V,RB,NB}}")
    # spec_axis must be non-empty dict
    sa = spec.get("spec_axis")
    if not isinstance(sa, dict) or len(sa) == 0:
        issues.append(f"{cid}: spec_axis must be a non-empty dict")
    else:
        # every boolean spec-axis field that's stated must be True (the design intent
        # is "this constraint IS addressed" — a False would mean the design fails it)
        for k, v in sa.items():
            if isinstance(v, bool) and v is not True:
                issues.append(f"{cid}: spec_axis[{k!r}] is False — the design fails this constraint")
    return (len(issues) == 0), issues


def audit_cross_combo(spec: dict) -> tuple[bool, list[str]]:
    """Verify a cross-axis combo is well-formed + members are mechanistically distinct."""
    issues = []
    name = spec.get("name", "?")
    for f in ("name", "scope", "members", "distinctness_claim"):
        if f not in spec:
            issues.append(f"{name}: missing field {f!r}")
    members = spec.get("members", [])
    if len(members) < 2:
        issues.append(f"{name}: combo needs ≥2 members (got {len(members)})")
    # member tuples = (candidate_id, axis, mechanism_description)
    mechs = []
    for m in members:
        if not (isinstance(m, (list, tuple)) and len(m) == 3):
            issues.append(f"{name}: malformed member {m!r} (expected (id, axis, mechanism))")
            continue
        cid, axis, mech = m
        if not mech or not isinstance(mech, str) or len(mech.strip()) < 10:
            issues.append(f"{name}: member {cid} has no meaningful mechanism description")
        mechs.append((cid, mech))
    # distinctness: no two members may share an identical mechanism string (a weak
    # but deterministic proxy for "mechanistically distinct"); the roadmap's
    # distinctness_claim is the authoritative narrative — this just guards against
    # accidental double-counting.
    seen = set()
    for cid, mech in mechs:
        key = mech.split("—")[0].strip().lower()[:40]  # mechanism prefix
        if key in seen:
            issues.append(f"{name}: member {cid} mechanism prefix {key!r} duplicates an earlier member — not a genuine combo, a re-label")
        seen.add(key)
    return (len(issues) == 0), issues


def main() -> int:
    print("cmt_axis_and_cross_design_audit — per-axis (W-1/V-1/RB-1/NB-1) + cross-axis (cross-1/cross-2) design-audit gates")
    print()

    issues = []
    n_pass = 0
    n_total = 0

    # ── per-axis falsifiers ──
    per_axis = [
        ("F-disease-cmt-W-1",  [W1_NRG1]),
        ("F-disease-cmt-V-1",  [V1_FIG4]),
        ("F-disease-cmt-RB-1", [RB1_PMP22_001, RB1_PMP22_002]),
        ("F-disease-cmt-NB-1", [NB1_NANO]),
    ]
    for fid, specs in per_axis:
        n_total += 1
        all_ok = True
        for spec in specs:
            ok, iss = audit_axis_candidate(spec)
            if not ok:
                all_ok = False
                issues.extend(f"[{fid}] {x}" for x in iss)
        flag = "✅" if all_ok else "❌"
        cands = ", ".join(s["candidate"] for s in specs)
        print(f"  {flag} {fid:<22} ({cands}) — {len(specs)} candidate(s), axis={specs[0]['axis']}")
        if all_ok:
            n_pass += 1
            # print the spec-axis summary
            for s in specs:
                n_constraints = len(s["spec_axis"])
                print(f"       {s['candidate']}: {n_constraints} spec-axis constraints documented; comparator = {s['comparator']}")
                if "wet_lab_residual" in s:
                    print(f"         (c) wet-lab residual: {s['wet_lab_residual']}")

    # ── cross-axis combos ──
    for combo in (CROSS1, CROSS2):
        n_total += 1
        ok, iss = audit_cross_combo(combo)
        flag = "✅" if ok else "❌"
        member_ids = ", ".join(m[0] for m in combo["members"])
        print(f"  {flag} {combo['name']:<22} ({member_ids}) — {len(combo['members'])} members")
        if ok:
            n_pass += 1
            print(f"       scope: {combo['scope']}")
            print(f"       distinctness: {combo['distinctness_claim']}")
            if "wet_lab_residual" in combo:
                print(f"         (c) wet-lab residual: {combo['wet_lab_residual']}")
        else:
            issues.extend(f"[{combo['name']}] {x}" for x in iss)
    print()

    # ── coherence checks ──
    # (a) the 4 per-axis falsifiers must cover W, V, RB, NB (the non-Q axes — Q is covered by Q-1..8)
    axes_covered = set()
    for _, specs in per_axis:
        for s in specs:
            axes_covered.add(s["axis"])
    if axes_covered != {"W", "V", "RB", "NB"}:
        issues.append(f"per-axis falsifiers cover {sorted(axes_covered)}, expected {{W, V, RB, NB}} (Q axis is covered by F-disease-cmt-Q-1..8)")

    # (b) cross-1 must include ≥1 demyelinating-axis candidate; cross-2 must include ≥1 axonal-axis candidate
    cross1_ids = {m[0] for m in CROSS1["members"]}
    if not ({"hxq-cmt-hd6-001", "hxq-cmt-pmp22-001"} & cross1_ids):
        issues.append("cross-1 (demyelinating) must include hd6-001 or pmp22-001")
    cross2_ids = {m[0] for m in CROSS2["members"]}
    if not ({"hxq-cmt-sar1-001"} & cross2_ids):
        issues.append("cross-2 (axonal) must include sar1-001 (the broad-axonal SARM1 candidate)")

    print(f"  per-axis falsifiers: {sum(1 for _ in per_axis)}/4 (W-1, V-1, RB-1, NB-1) — cover axes {sorted(axes_covered)}")
    print(f"  cross-axis combos: 2/2 (cross-1 demyelinating, cross-2 axonal)")
    print(f"  total falsifier gates passing: {n_pass}/{n_total}")
    print(f"  combined with F-disease-cmt-Q-7 + Q-8 (cmt_library_ranking.py + cmt_side_effect_avoidance_audit.py)")
    print(f"  + Q-1..6 (cmt_vqe_ladder_readiness.sh → qmirror chemistry_vqe_cmt_hamiltonians.hexa, 2e/2o VQE LANDED 2026-05-13):")
    print(f"    → 14 of 14 CMT falsifiers now have an in-repo deterministic gate (Q-1..6, Q-7, Q-8, W-1, V-1, RB-1, NB-1, cross-1, cross-2)")
    print(f"    → Q-1..6 = live 2e/2o pocket VQE (vendored CMT Hamiltonians vs CASCI(2,2)); 4e/4o+ / final-molecule / pocket-embedded = next ramp")

    ok = (len(issues) == 0) and (n_pass == n_total)
    print()
    if ok:
        print("__CMT_AXIS_CROSS_DESIGN_AUDIT__ PASS")
        return 0
    print("__CMT_AXIS_CROSS_DESIGN_AUDIT__ FAIL")
    for issue in issues:
        print(f"  issue: {issue}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
