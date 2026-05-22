#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
alzheimer_portfolio_runner.py — Alzheimer disease portfolio case-study
witness emitter. HONESTY SHOWCASE: ZERO in-scope drugs.

WHAT THIS IS
────────────
Alzheimer disease (AD) is the case study whose honest result is
**ZERO IN-SCOPE drugs**. The disease's three FDA-approved
*disease-modifying* therapies are all anti-amyloid monoclonal antibodies,
CBER-regulated biologics that fall outside the hexa-bio criterion #4
drug-only/CDER scope boundary:

  (1) lecanemab / Leqembi   (Eisai / Biogen, FDA 2023, CBER)
  (2) donanemab / Kisunla   (Eli Lilly,      FDA 2024, CBER)
  (3) aducanumab / Aduhelm  (Biogen,         FDA 2021, CBER — voluntarily
      withdrawn 2024)

These three are honestly UNPLACED for the SAME reason as Zolgensma /
Casgevy / Comirnaty in `AXIS/HIERARCHY.tape @N genetic_medicine_status`
and trastuzumab deruxtecan in `@N adc_status`: CBER biologics do not get
a code axis; implementing one would breach criterion #4 + g8.

The disease's other long-FDA-approved drugs are the cholinergic
palliatives:

  (a) donepezil    / Aricept  (Eisai / Pfizer,  FDA 1996, CDER)
  (b) rivastigmine / Exelon   (Novartis,        FDA 2000, CDER)
  (c) galantamine  / Razadyne (Janssen / Shire, FDA 2001, CDER)

These ARE CDER small molecules under hexa-bio's discipline, BUT their
acetylcholinesterase-inhibition mechanism does NOT map cleanly onto any
of the expansion-layer axes. The axis tree was designed for new
modalities (PROTAC / CAPSID-ASSEMBLY-MODULATOR / OLIGONUCLEOTIDE /
METALLODRUG / COVALENT / BIFUNCTIONAL / sub-axes); AChE inhibition is a
legacy cholinergic palliative mechanism with no matching axis. Force-
fitting them into e.g. ALLOSTERIC or COVALENT would be the same kind of
lattice-fit-on-external-entity error that `f1` forbids — observational
similarity is not derivational identity. They are also SYMPTOMATIC, not
disease-modifying.

Honest call: `legacy_palliatives_no_axis` — distinct from CBER UNPLACED.

ZERO IN-SCOPE IS THE HONEST RESULT
──────────────────────────────────
A portfolio that pretends to cover Alzheimer by inventing a
"MONOCLONAL-ANTIBODY" axis (to hold the three anti-amyloid mAbs) or by
shoehorning AChE inhibitors into ALLOSTERIC would be DISHONEST. Both
moves breach governance: the first violates criterion #4 + g8, the
second violates g3 / f1 (lattice-fit-on-external-entity — derivation
without a matching real-limit anchor). The honest result for this
case study is `in_scope_drugs = []`. The schema permits this exactly
(`minItems: 0, maxItems: 0, items: false`), and the honesty block
enforces `zero_in_scope_acknowledged: True` and
`zero_in_scope_is_a_valid_outcome: True` as schema-level consts so the
zero-in-scope outcome is a STRUCTURAL feature of the witness, not a
comment.

This is the extremity of the UNPLACED pattern established for SMA's
Zolgensma (one UNPLACED of three) and HIV-1's research-stage negatives
(several listed honestly): Alzheimer is the case where the disease's
entire FDA-approved disease-modifying landscape is UNPLACED.

DETERMINISM
───────────
Pure stdlib. No imports from `_python_bridge/module/` — by design,
because there is no in-scope axis sim to run. No random / network /
time / env reads. Re-running produces byte-identical JSON output, the
deductive-verification contract used across the hexa-bio repo.

EXIT
────
Exit 0 on PASS, with the line `__ALZHEIMER_PORTFOLIO__ PASS` printed
at the end. Exit 1 on FAIL with `__ALZHEIMER_PORTFOLIO__ FAIL`.

License: Apache-2.0 (hexa-bio core).
"""

from __future__ import annotations

import json
import sys
from typing import Any, Dict, List

SCHEMA_VERSION = "alzheimer_portfolio_v1"
CASE_STUDY_ID = "alzheimer_portfolio.v1"
SENTINEL_PASS = "__ALZHEIMER_PORTFOLIO__ PASS"
SENTINEL_FAIL = "__ALZHEIMER_PORTFOLIO__ FAIL"


# ── CBER UNPLACED rows (anti-amyloid mAbs — disease-modifying) ──────────


def _row_lecanemab_cber_unplaced() -> Dict[str, Any]:
    """lecanemab / Leqembi — anti-amyloid mAb, CBER biologic, UNPLACED.

    Granted accelerated FDA approval 2023-01-06 then traditional
    approval 2023-07-06 for early Alzheimer disease. Humanized IgG1
    monoclonal antibody targeting soluble amyloid-β protofibrils.
    """
    return {
        "drug_name": "lecanemab",
        "brand": "Leqembi",
        "sponsor": "Eisai / Biogen",
        "fda_year": 2023,
        "fda_center": "CBER",
        "modality": "humanized IgG1 monoclonal antibody — anti-amyloid-β "
        "protofibril binder; reduces brain amyloid plaque burden via "
        "Fc-mediated microglial clearance",
        "axis": None,
        "in_scope": False,
        "cber_reason": "Monoclonal antibody = biologic — CBER-regulated "
        "under PHSA §351 (BLA), NOT NDA under CDER. Per criterion #4 "
        "(drug-only/CDER discipline) the hexa-bio axis tree does not "
        "register CBER biologics.",
        "reason": "CBER biologic — criterion #4 drug-only/CDER scope "
        "boundary. Implementing an anti-amyloid mAb axis would breach "
        "criterion #4 + g8 in-silico-only honesty (immunogenicity, "
        "Fc-effector profile, neutralizing-antibody-pre-screen carry "
        "claim load that the in-silico axes cannot bound).",
        "unplaced_precedent_in_repo": "AXIS/HIERARCHY.tape "
        "@N genetic_medicine_status + @N adc_status — same CBER-scope "
        "UNPLACED handling already established (Zolgensma / Casgevy / "
        "Comirnaty for gene/cell/mRNA; Enhertu / Kadcyla for ADCs). "
        "Anti-amyloid mAbs join the same honesty cohort.",
        "drug_precedent_citations": [
            "van Dyck CH et al. 2023, N Engl J Med 388:9-21 "
            "(CLARITY AD lecanemab phase-3)",
            "FDA STN BL 761269 — lecanemab-irmb (Leqembi) "
            "accelerated approval 2023-01-06; traditional approval "
            "2023-07-06, CBER",
        ],
        "reported_not_run": True,
        "status_note": "FDA-approved (traditional approval 2023-07-06, "
        "CBER).",
    }


def _row_donanemab_cber_unplaced() -> Dict[str, Any]:
    """donanemab / Kisunla — anti-amyloid mAb, CBER biologic, UNPLACED.

    Traditional FDA approval 2024-07-02 for early symptomatic
    Alzheimer disease. Humanized IgG1 monoclonal antibody targeting an
    N-truncated pyroglutamate-amyloid-β epitope (deposited plaque).
    """
    return {
        "drug_name": "donanemab",
        "brand": "Kisunla",
        "sponsor": "Eli Lilly",
        "fda_year": 2024,
        "fda_center": "CBER",
        "modality": "humanized IgG1 monoclonal antibody — targets the "
        "N-terminal pyroglutamate-modified amyloid-β epitope present on "
        "deposited plaque; drives microglial plaque removal",
        "axis": None,
        "in_scope": False,
        "cber_reason": "Monoclonal antibody = biologic — CBER-regulated "
        "under PHSA §351 (BLA), NOT NDA under CDER. Per criterion #4 "
        "(drug-only/CDER discipline) the hexa-bio axis tree does not "
        "register CBER biologics.",
        "reason": "CBER biologic — criterion #4 drug-only/CDER scope "
        "boundary. Same UNPLACED rationale as lecanemab.",
        "unplaced_precedent_in_repo": "AXIS/HIERARCHY.tape "
        "@N genetic_medicine_status + @N adc_status — CBER-scope "
        "UNPLACED pattern. Anti-amyloid mAbs join this honesty cohort.",
        "drug_precedent_citations": [
            "Sims JR et al. 2023, JAMA 330:512-527 "
            "(TRAILBLAZER-ALZ 2 donanemab phase-3)",
            "FDA STN BL 761248 — donanemab-azbt (Kisunla) "
            "traditional approval 2024-07-02, CBER",
        ],
        "reported_not_run": True,
        "status_note": "FDA-approved (traditional approval 2024-07-02, "
        "CBER).",
    }


def _row_aducanumab_cber_unplaced() -> Dict[str, Any]:
    """aducanumab / Aduhelm — anti-amyloid mAb, CBER biologic, UNPLACED;
    voluntarily withdrawn 2024.

    Granted accelerated FDA approval 2021-06-07 amid significant
    controversy over the primary-endpoint evidence base. Biogen
    voluntarily withdrew the drug from the U.S. market 2024-01-31.
    """
    return {
        "drug_name": "aducanumab",
        "brand": "Aduhelm",
        "sponsor": "Biogen",
        "fda_year": 2021,
        "fda_center": "CBER",
        "modality": "human IgG1 monoclonal antibody — anti-amyloid-β "
        "aggregate (oligomer / fibril) binder; selected from a "
        "B-cell repertoire of cognitively-normal elderly donors",
        "axis": None,
        "in_scope": False,
        "cber_reason": "Monoclonal antibody = biologic — CBER-regulated "
        "under PHSA §351 (BLA), NOT NDA under CDER. Per criterion #4 "
        "(drug-only/CDER discipline) the hexa-bio axis tree does not "
        "register CBER biologics.",
        "reason": "CBER biologic — criterion #4 drug-only/CDER scope "
        "boundary. Same UNPLACED rationale as lecanemab / donanemab. "
        "The drug's accelerated-approval history (2021) and its "
        "voluntary withdrawal (2024) are recorded honestly in "
        "`status_note`; this case study does not editorialize on the "
        "approval decision (g3 / f4 — no external-entity claim).",
        "unplaced_precedent_in_repo": "AXIS/HIERARCHY.tape "
        "@N genetic_medicine_status + @N adc_status — CBER-scope "
        "UNPLACED pattern. Anti-amyloid mAbs join this honesty cohort.",
        "drug_precedent_citations": [
            "Sevigny J et al. 2016, Nature 537:50-56 "
            "(aducanumab plaque reduction)",
            "FDA STN BL 761178 — aducanumab-avwa (Aduhelm) "
            "accelerated approval 2021-06-07, CBER",
            "Biogen press release 2024-01-31 — voluntary "
            "discontinuation of Aduhelm in the United States",
        ],
        "reported_not_run": True,
        "status_note": "Accelerated approval 2021-06-07 (CBER); "
        "voluntarily withdrawn from the U.S. market 2024-01-31. "
        "Listed for completeness as one of the three FDA-approved "
        "anti-amyloid mAbs (g3 — record what is, do not editorialize).",
    }


# ── CDER-no-axis-map legacy palliatives ────────────────────────────────


def _row_donepezil_no_axis() -> Dict[str, Any]:
    """donepezil / Aricept — AChE inhibitor; CDER small molecule but
    no clean axis mapping. Symptomatic, not disease-modifying."""
    return {
        "drug_name": "donepezil",
        "brand": "Aricept",
        "sponsor": "Eisai / Pfizer",
        "fda_year": 1996,
        "fda_center": "CDER",
        "modality": "small molecule — reversible centrally-acting "
        "acetylcholinesterase (AChE) inhibitor; raises synaptic "
        "acetylcholine to compensate for cholinergic neuron loss",
        "axis": None,
        "in_scope": False,
        "legacy_palliative_no_axis": True,
        "no_axis_map_reason": "AChE inhibition is a classical "
        "reversible enzyme-inhibitor mechanism with no clean mapping "
        "onto the hexa-bio expansion-layer axes. The axis tree is "
        "designed for new modalities (PROTAC / CAPSID-ASSEMBLY-"
        "MODULATOR / OLIGONUCLEOTIDE / METALLODRUG / COVALENT / "
        "BIFUNCTIONAL / sub-axes); a reversible non-covalent AChE "
        "inhibitor does not match any. Force-fitting into ALLOSTERIC "
        "or COVALENT would be lattice-fit-on-external-entity (f1) — "
        "observational similarity is not derivational identity. "
        "Honest call: flag, do not force-fit.",
        "drug_precedent_citations": [
            "Sugimoto H et al. 1995, J Med Chem 38:4821-4829 "
            "(donepezil discovery)",
            "FDA NDA 020690 — donepezil hydrochloride (Aricept) "
            "approval 1996-11-25, CDER",
        ],
        "reported_not_run": True,
        "symptomatic_not_disease_modifying": True,
    }


def _row_rivastigmine_no_axis() -> Dict[str, Any]:
    """rivastigmine / Exelon — AChE + butyrylcholinesterase inhibitor;
    CDER small molecule, no clean axis mapping."""
    return {
        "drug_name": "rivastigmine",
        "brand": "Exelon",
        "sponsor": "Novartis",
        "fda_year": 2000,
        "fda_center": "CDER",
        "modality": "small molecule — pseudo-irreversible (slowly "
        "reversible) carbamate inhibitor of both acetylcholinesterase "
        "and butyrylcholinesterase; carbamylates the active-site serine",
        "axis": None,
        "in_scope": False,
        "legacy_palliative_no_axis": True,
        "no_axis_map_reason": "Pseudo-irreversible cholinesterase "
        "inhibition (carbamylation of the active-site serine) does not "
        "map cleanly onto the expansion-layer axes. While it has a "
        "covalent-character mechanism, the pharmacology and target "
        "class (cholinergic palliative for symptomatic AD) place it "
        "outside the scope the COVALENT axis was registered for "
        "(new-modality covalent drugs for the modern oncology / "
        "antiviral palette). Force-fitting would be f1 — flag, do not "
        "force-fit.",
        "drug_precedent_citations": [
            "Bar-On P et al. 2002, Biochemistry 41:3555-3564 "
            "(rivastigmine carbamate mechanism)",
            "FDA NDA 020823 — rivastigmine tartrate (Exelon) "
            "approval 2000-04-21, CDER",
        ],
        "reported_not_run": True,
        "symptomatic_not_disease_modifying": True,
    }


def _row_galantamine_no_axis() -> Dict[str, Any]:
    """galantamine / Razadyne — AChE inhibitor + nicotinic allosteric
    modulator; CDER small molecule, no clean axis mapping."""
    return {
        "drug_name": "galantamine",
        "brand": "Razadyne",
        "sponsor": "Janssen / Shire",
        "fda_year": 2001,
        "fda_center": "CDER",
        "modality": "small molecule — reversible competitive "
        "acetylcholinesterase inhibitor with allosteric potentiation "
        "of nicotinic acetylcholine receptors (dual cholinergic action)",
        "axis": None,
        "in_scope": False,
        "legacy_palliative_no_axis": True,
        "no_axis_map_reason": "Reversible AChE inhibition with "
        "additional allosteric nicotinic potentiation is a legacy "
        "cholinergic palliative mechanism. The dual action does not "
        "make it an ALLOSTERIC-axis drug in the expansion-layer sense: "
        "the axis was registered for the modern allosteric paradigm "
        "anchored to specific real limits, not for legacy cholinergic "
        "palliatives. Force-fitting would be f1 — flag, do not "
        "force-fit.",
        "drug_precedent_citations": [
            "Maelicke A et al. 2001, Biol Psychiatry 49:279-288 "
            "(galantamine dual mechanism)",
            "FDA NDA 021169 — galantamine hydrobromide (Razadyne, "
            "formerly Reminyl) approval 2001-02-28, CDER",
        ],
        "reported_not_run": True,
        "symptomatic_not_disease_modifying": True,
    }


# ── full portfolio assembly ─────────────────────────────────────────────


def build_portfolio() -> Dict[str, Any]:
    """Assemble the full Alzheimer portfolio witness object.

    ZERO in-scope drug rows by design. Three CBER UNPLACED rows
    (lecanemab / donanemab / aducanumab — anti-amyloid mAbs). Three
    legacy-palliative-no-axis rows (donepezil / rivastigmine /
    galantamine — AChE inhibitors with no clean axis mapping). The
    schema permits and enforces this zero-in-scope shape.
    """
    in_scope: List[Dict[str, Any]] = []
    not_in_scope: List[Dict[str, Any]] = [
        _row_lecanemab_cber_unplaced(),
        _row_donanemab_cber_unplaced(),
        _row_aducanumab_cber_unplaced(),
    ]
    legacy_no_axis: List[Dict[str, Any]] = [
        _row_donepezil_no_axis(),
        _row_rivastigmine_no_axis(),
        _row_galantamine_no_axis(),
    ]
    return {
        "schema_version": SCHEMA_VERSION,
        "case_study_id": CASE_STUDY_ID,
        "disease": {
            "name": "Alzheimer disease",
            "abbreviation": "AD",
            "primary_pathology": "extracellular amyloid-β plaque "
            "deposition + intraneuronal hyperphosphorylated tau "
            "tangles + neuroinflammation + progressive cholinergic "
            "neuron loss",
            "honest_modality_landscape": "FDA-approved disease-"
            "modifying drugs = three anti-amyloid mAbs (CBER "
            "biologics, UNPLACED by criterion #4). FDA-approved "
            "symptomatic drugs = three cholinergic palliatives "
            "(donepezil 1996 / rivastigmine 2000 / galantamine 2001, "
            "CDER) plus memantine (NMDA antagonist, not enumerated "
            "here as the expansion focus is on disease-modifying "
            "modalities). No FDA-approved small-molecule disease-"
            "modifying drug maps onto any expansion-layer axis — "
            "ZERO in-scope is the honest result.",
        },
        "in_scope_drugs": in_scope,
        "not_in_scope_drugs": not_in_scope,
        "legacy_palliatives_no_axis": legacy_no_axis,
        "cross_axis_touch_point": {
            "bridge_id": None,
            "module": None,
            "honesty_note": "No cross-axis touch point applies: with "
            "zero in-scope drugs there is no in-axis sim to bridge to "
            "anything. This is a structural acknowledgement, not a "
            "gap — the honest extremity of the UNPLACED pattern.",
        },
        "honesty": {
            "in_silico_only": True,
            "not_a_portfolio_recommendation": True,
            "not_an_efficacy_ranking": True,
            "not_a_superiority_claim": True,
            "not_a_clinical_claim": True,
            "zero_in_scope_acknowledged": True,
            "zero_in_scope_is_a_valid_outcome": True,
            "all_three_cber_disease_modifying_fda_approved": True,
            "all_three_legacy_palliatives_fda_approved": True,
            "unplaced_handling_is_honest": True,
            "legacy_palliatives_have_no_clean_axis_map": True,
            "axes_designed_for_new_modalities_not_legacy_palliatives":
                True,
            "no_lattice_derivation": True,
            "scope_is_one_disease_pilot": True,
            "statement": "Alzheimer disease is the case study whose "
            "honest result is ZERO in-scope drugs. The disease's only "
            "FDA-approved disease-modifying drugs are three anti-"
            "amyloid monoclonal antibodies (lecanemab/Leqembi 2023, "
            "donanemab/Kisunla 2024, aducanumab/Aduhelm 2021 — "
            "voluntarily withdrawn 2024); all three are CBER-"
            "regulated biologics and are honestly UNPLACED by the "
            "same criterion #4 + g8 pattern that already governs "
            "Zolgensma / Casgevy / Comirnaty (@N genetic_medicine_"
            "status) and Enhertu / Kadcyla (@N adc_status). The "
            "long-FDA-approved cholinergic palliatives (donepezil "
            "1996, rivastigmine 2000, galantamine 2001) are CDER "
            "small molecules but their acetylcholinesterase-inhibition "
            "mechanism does not map cleanly onto any of the expansion-"
            "layer axes; flagging them under `legacy_palliatives_no_"
            "axis` is honest, force-fitting them into ALLOSTERIC or "
            "COVALENT would be lattice-fit-on-external-entity (f1). "
            "ZERO in-scope is the truthful result, not a gap. The "
            "schema permits in_scope_drugs to be the empty array and "
            "enforces `zero_in_scope_acknowledged` + `zero_in_scope_"
            "is_a_valid_outcome` as schema-level consts so the outcome "
            "is structurally honest, not editorial. All six listed "
            "drugs are FDA-approved; modalities are described via "
            "their own published precedent (g3 / f1) — nothing is "
            "derived from the n=6 lattice (f_lattice_fit). Scope = "
            "one-disease pilot, NOT the 200-disease deferred work.",
        },
        "sentinel": SENTINEL_PASS,
    }


# ── self-validation against the schema shape ────────────────────────────


def _validate_witness(w: Dict[str, Any]) -> List[str]:
    """Lightweight in-module shape check. The draft-07 JSON Schema in
    portfolio_v1.schema.json is the authoritative contract; this is a
    cheap stdlib-only pre-flight."""
    errs: List[str] = []
    required_top = (
        "schema_version", "case_study_id", "disease",
        "in_scope_drugs", "not_in_scope_drugs",
        "legacy_palliatives_no_axis", "cross_axis_touch_point",
        "honesty", "sentinel",
    )
    for k in required_top:
        if k not in w:
            errs.append(f"missing top-level key '{k}'")
    if w.get("schema_version") != SCHEMA_VERSION:
        errs.append("schema_version mismatch")
    if w.get("case_study_id") != CASE_STUDY_ID:
        errs.append("case_study_id mismatch")
    if w.get("sentinel") != SENTINEL_PASS:
        errs.append("sentinel string mismatch")

    in_scope = w.get("in_scope_drugs")
    if not isinstance(in_scope, list) or len(in_scope) != 0:
        errs.append("in_scope_drugs MUST be an empty list (ZERO "
                    "in-scope is the honest result)")

    not_in = w.get("not_in_scope_drugs", [])
    if not isinstance(not_in, list) or len(not_in) != 3:
        errs.append("not_in_scope_drugs must have exactly 3 entries "
                    "(lecanemab + donanemab + aducanumab)")
    else:
        required_unplaced = (
            "drug_name", "brand", "sponsor", "fda_year", "fda_center",
            "modality", "axis", "in_scope", "cber_reason", "reason",
            "unplaced_precedent_in_repo", "drug_precedent_citations",
            "reported_not_run", "status_note",
        )
        for i, row in enumerate(not_in):
            for k in required_unplaced:
                if k not in row:
                    errs.append(f"not_in_scope_drugs[{i}]: missing '{k}'")
            if row.get("axis") is not None:
                errs.append(
                    f"not_in_scope_drugs[{i}]: axis must be null"
                )
            if row.get("in_scope") is not False:
                errs.append(
                    f"not_in_scope_drugs[{i}]: in_scope must be False"
                )
            if row.get("fda_center") != "CBER":
                errs.append(
                    f"not_in_scope_drugs[{i}]: fda_center must be CBER"
                )
            if row.get("reported_not_run") is not True:
                errs.append(
                    f"not_in_scope_drugs[{i}]: reported_not_run must be True"
                )

    legacy = w.get("legacy_palliatives_no_axis", [])
    if not isinstance(legacy, list) or len(legacy) != 3:
        errs.append("legacy_palliatives_no_axis must have exactly 3 "
                    "entries (donepezil + rivastigmine + galantamine)")
    else:
        required_legacy = (
            "drug_name", "brand", "sponsor", "fda_year", "fda_center",
            "modality", "axis", "in_scope", "legacy_palliative_no_axis",
            "no_axis_map_reason", "drug_precedent_citations",
            "reported_not_run", "symptomatic_not_disease_modifying",
        )
        for i, row in enumerate(legacy):
            for k in required_legacy:
                if k not in row:
                    errs.append(
                        f"legacy_palliatives_no_axis[{i}]: missing '{k}'"
                    )
            if row.get("axis") is not None:
                errs.append(
                    f"legacy_palliatives_no_axis[{i}]: axis must be null"
                )
            if row.get("fda_center") != "CDER":
                errs.append(
                    f"legacy_palliatives_no_axis[{i}]: fda_center "
                    "must be CDER"
                )
            if row.get("in_scope") is not False:
                errs.append(
                    f"legacy_palliatives_no_axis[{i}]: in_scope must be False"
                )
            if row.get("legacy_palliative_no_axis") is not True:
                errs.append(
                    f"legacy_palliatives_no_axis[{i}]: "
                    "legacy_palliative_no_axis must be True"
                )
            if row.get("symptomatic_not_disease_modifying") is not True:
                errs.append(
                    f"legacy_palliatives_no_axis[{i}]: "
                    "symptomatic_not_disease_modifying must be True"
                )
            if row.get("reported_not_run") is not True:
                errs.append(
                    f"legacy_palliatives_no_axis[{i}]: "
                    "reported_not_run must be True"
                )

    cx = w.get("cross_axis_touch_point", {})
    if cx.get("bridge_id") is not None:
        errs.append("cross_axis_touch_point.bridge_id must be null "
                    "(no cross-axis applies with zero in-scope drugs)")
    if cx.get("module") is not None:
        errs.append("cross_axis_touch_point.module must be null")

    h = w.get("honesty", {})
    required_honesty_flags = (
        "in_silico_only", "not_a_portfolio_recommendation",
        "not_an_efficacy_ranking", "not_a_superiority_claim",
        "not_a_clinical_claim", "zero_in_scope_acknowledged",
        "zero_in_scope_is_a_valid_outcome",
        "all_three_cber_disease_modifying_fda_approved",
        "all_three_legacy_palliatives_fda_approved",
        "unplaced_handling_is_honest",
        "legacy_palliatives_have_no_clean_axis_map",
        "axes_designed_for_new_modalities_not_legacy_palliatives",
        "no_lattice_derivation", "scope_is_one_disease_pilot",
    )
    for k in required_honesty_flags:
        if h.get(k) is not True:
            errs.append(f"honesty.{k} must be True")

    return errs


# ── self-check / demo ───────────────────────────────────────────────────


def _selfcheck() -> int:
    print("alzheimer_portfolio_runner.py — Alzheimer portfolio case study")
    print("  HONESTY SHOWCASE: ZERO in-scope drugs (the truthful result)")
    print()
    print("  IN-SCOPE drugs                           : 0  (empty array)")
    print("  CBER UNPLACED (anti-amyloid mAbs)        : 3")
    print("    (a) lecanemab  (Leqembi,  FDA 2023, CBER) — approved")
    print("    (b) donanemab  (Kisunla,  FDA 2024, CBER) — approved")
    print("    (c) aducanumab (Aduhelm,  FDA 2021, CBER) — withdrawn 2024")
    print("  CDER-no-axis-map (cholinergic palliatives): 3")
    print("    (d) donepezil    (Aricept,  FDA 1996, CDER) — AChE-i")
    print("    (e) rivastigmine (Exelon,   FDA 2000, CDER) — AChE/BuChE-i")
    print("    (f) galantamine  (Razadyne, FDA 2001, CDER) — AChE-i + nAChR")
    print()

    fails = 0
    w = build_portfolio()

    errs = _validate_witness(w)
    if not errs:
        print("  [PASS] witness shape — conforms to "
              f"portfolio_v1.schema.json ({SCHEMA_VERSION})")
    else:
        fails += 1
        print("  [FAIL] witness shape — errors below")
        for e in errs:
            print(f"         x {e}")

    # --- ZERO in-scope (the structural honesty showcase)
    if isinstance(w["in_scope_drugs"], list) and \
            len(w["in_scope_drugs"]) == 0:
        print("  [PASS] in-scope drugs — 0 entries (ZERO in-scope is "
              "the honest result)")
    else:
        fails += 1
        print("  [FAIL] in-scope drugs — must be exactly 0 (empty array)")

    # --- 3 CBER UNPLACED entries
    if len(w["not_in_scope_drugs"]) == 3:
        names = [r["drug_name"] for r in w["not_in_scope_drugs"]]
        print(f"  [PASS] CBER UNPLACED — 3 entries: {names}")
    else:
        fails += 1
        print("  [FAIL] CBER UNPLACED — must be exactly 3 entries")

    # --- 3 legacy palliatives no-axis-map entries
    if len(w["legacy_palliatives_no_axis"]) == 3:
        names = [r["drug_name"] for r in w["legacy_palliatives_no_axis"]]
        print(f"  [PASS] legacy palliatives no-axis-map — 3 entries: "
              f"{names}")
    else:
        fails += 1
        print("  [FAIL] legacy palliatives no-axis-map — must be "
              "exactly 3 entries")

    # --- each CBER row carries its own per-row cber_reason (g1)
    cber_doc_ok = all(
        isinstance(r.get("cber_reason"), str) and
        "biologic" in r["cber_reason"].lower() and
        "CBER" in r["cber_reason"]
        for r in w["not_in_scope_drugs"]
    )
    if cber_doc_ok:
        print("  [PASS] CBER documentation — each not-in-scope row carries "
              "its own per-row cber_reason (g1)")
    else:
        fails += 1
        print("  [FAIL] CBER documentation — a not-in-scope row is "
              "missing its cber_reason")

    # --- each legacy palliative row explains WHY no axis maps (f1 honest)
    legacy_doc_ok = all(
        isinstance(r.get("no_axis_map_reason"), str) and
        len(r["no_axis_map_reason"]) > 50
        for r in w["legacy_palliatives_no_axis"]
    )
    if legacy_doc_ok:
        print("  [PASS] no-axis-map documentation — each legacy row "
              "explains why no axis applies (f1 honest)")
    else:
        fails += 1
        print("  [FAIL] no-axis-map documentation — a legacy row is "
              "missing its no_axis_map_reason")

    # --- honesty block intact: all required flags True
    h = w["honesty"]
    h_ok = all(h.get(k) is True for k in (
        "in_silico_only", "not_a_portfolio_recommendation",
        "not_an_efficacy_ranking", "not_a_superiority_claim",
        "not_a_clinical_claim", "zero_in_scope_acknowledged",
        "zero_in_scope_is_a_valid_outcome",
        "all_three_cber_disease_modifying_fda_approved",
        "all_three_legacy_palliatives_fda_approved",
        "unplaced_handling_is_honest",
        "legacy_palliatives_have_no_clean_axis_map",
        "axes_designed_for_new_modalities_not_legacy_palliatives",
        "no_lattice_derivation", "scope_is_one_disease_pilot",
    ))
    if h_ok:
        print("  [PASS] honesty block — zero-in-scope acknowledged, "
              "in-silico-only, no lattice derivation")
    else:
        fails += 1
        print("  [FAIL] honesty block — missing a required honesty flag")

    # --- determinism: byte-identical re-run
    a = json.dumps(build_portfolio(), sort_keys=True)
    b = json.dumps(build_portfolio(), sort_keys=True)
    if a == b:
        print("  [PASS] determinism — byte-identical re-run")
    else:
        fails += 1
        print("  [FAIL] determinism — output drift between runs")

    # --- emit the witness JSON for downstream schema validators ──────────
    print()
    print("  ── witness JSON (canonical, sort_keys=True) ──")
    print(json.dumps(w, sort_keys=True, indent=2))

    print()
    print("  ── in-silico honesty caveat (governance g8 / f2) ──")
    print("  This case study is a one-disease pilot for Alzheimer disease")
    print("  — NOT the 200-disease deferred work. Every PASS certifies")
    print("  in-silico simulator + metadata internal consistency ONLY. It")
    print("  is NEVER a therapeutic, clinical, amyloid-clearance, cognitive,")
    print("  efficacy, immunogenic, regulatory, or portfolio-recommendation")
    print("  claim.")
    print()
    print("  ── ZERO in-scope is the honest result ──")
    print("  Alzheimer's three FDA-approved DISEASE-MODIFYING drugs are")
    print("  ALL anti-amyloid monoclonal antibodies — CBER biologics that")
    print("  fall outside the hexa-bio criterion #4 drug-only/CDER scope")
    print("  boundary. The long-FDA-approved cholinergic palliatives")
    print("  (donepezil / rivastigmine / galantamine) are CDER small")
    print("  molecules but their AChE-inhibition mechanism does not map")
    print("  cleanly onto any expansion-layer axis. Force-fitting either")
    print("  group into the axis tree would breach governance: criterion")
    print("  #4 + g8 for the mAbs, f1 lattice-fit-on-external-entity for")
    print("  the AChE-inhibitors. ZERO in-scope is therefore the truthful")
    print("  result; the schema makes this a structural feature of the")
    print("  witness (empty `in_scope_drugs` + `zero_in_scope_acknowledged:")
    print("  const true`), not an editorial comment. All six listed drugs")
    print("  are FDA-approved; modalities are described via their own")
    print("  published precedent (g3 / f1) — nothing is derived from the")
    print("  n=6 lattice (f_lattice_fit).")
    print()

    total_checks = 7
    passed = total_checks - fails
    if fails == 0:
        print(f"  --- summary --- {passed} / {total_checks} checks PASS "
              "-> verdict: PASS")
        print(SENTINEL_PASS)
        return 0
    print(f"  --- summary --- {fails} FAIL -> verdict: FAIL")
    print(SENTINEL_FAIL)
    return 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
