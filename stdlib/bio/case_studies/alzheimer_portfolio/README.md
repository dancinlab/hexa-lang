# Alzheimer disease portfolio — case study (honesty showcase)

Alzheimer disease (AD) is the case study whose **honest result is ZERO
in-scope drugs**. The disease has six relevant FDA-approved drugs:
three anti-amyloid monoclonal antibodies (the only FDA-approved
*disease-modifying* therapies for AD, all CBER biologics) and three
long-approved cholinergic palliatives (CDER small molecules whose
AChE-inhibition mechanism does not map cleanly onto any expansion-layer
axis). NONE of them can be honestly placed into the hexa-bio axis tree.

This case study is the **extremity of the UNPLACED pattern** already
established for SMA's Zolgensma (`case_studies/sma_portfolio/`) and for
the GENETIC-MEDICINE / ADC / THERANOSTIC notes in
`AXIS/HIERARCHY.tape`. SMA had one UNPLACED of three; Alzheimer has the
entire disease-modifying landscape UNPLACED.

## §0 Honest scope — ZERO IN-SCOPE drugs is the truthful result

This is a **one-disease pilot** — Alzheimer disease only. It is NOT
the 200-disease deferred re-mapping flagged in `AXIS/HIERARCHY.tape`;
that effort remains deferred.

The deliverable here is:

1. an honest writeup of why this disease's six FDA-approved drugs
   produce ZERO in-scope rows under the expansion-layer axis tree;
2. a deterministic stdlib-only Python runner that emits the
   zero-in-scope portfolio witness JSON (no in-axis sim is run — by
   design, because there is none to run);
3. a draft-07 JSON Schema for the witness that **permits**
   `in_scope_drugs` to be the empty array (`minItems: 0, maxItems: 0`,
   `items: false`) and **enforces** `zero_in_scope_acknowledged: const
   true` + `zero_in_scope_is_a_valid_outcome: const true` in the
   honesty block.

The empty-array shape is therefore a **structural feature** of the
witness, not a comment: the schema rejects any attempt to paper over
the zero-in-scope outcome with invented rows.

Every PASS here is **in-silico simulator-consistency only** (governance
g8 / f2). It is NEVER a therapeutic, clinical, amyloid-clearance,
cognitive, efficacy, immunogenic, regulatory, or
portfolio-recommendation claim.

## §1 The three FDA-approved Alzheimer disease-modifying drugs (all CBER)

All three FDA-approved *disease-modifying* drugs for AD are anti-amyloid
monoclonal antibodies. Monoclonal antibodies are biologics regulated by
the FDA's Center for Biologics Evaluation and Research (CBER) under the
Public Health Service Act §351 (BLA), NOT by the Center for Drug
Evaluation and Research (CDER) under an NDA. The hexa-bio axis tree is
CDER-only by `AXIS/README.md` criterion #4 (drug-only discipline);
CBER biologics are UNPLACED by design.

| # | Drug (brand)         | Sponsor          | FDA year | FDA center | CBER reason                                  | Status                                            |
|---|----------------------|------------------|----------|------------|----------------------------------------------|---------------------------------------------------|
| 1 | **lecanemab** (Leqembi)  | Eisai / Biogen   | 2023     | **CBER**   | humanized IgG1 mAb = biologic = BLA = CBER   | approved (accelerated 2023-01-06; traditional 2023-07-06) |
| 2 | **donanemab** (Kisunla)  | Eli Lilly        | 2024     | **CBER**   | humanized IgG1 mAb = biologic = BLA = CBER   | approved (traditional 2024-07-02)                 |
| 3 | **aducanumab** (Aduhelm) | Biogen           | 2021     | **CBER**   | human IgG1 mAb = biologic = BLA = CBER       | voluntarily withdrawn from U.S. market 2024-01-31 |

Drug-precedent citations (g3 / f1, own published modality only):

- **lecanemab.** van Dyck CH *et al.* 2023, *N Engl J Med* 388:9-21
  (CLARITY AD phase-3); FDA STN BL 761269 — lecanemab-irmb (Leqembi)
  accelerated 2023-01-06, traditional 2023-07-06, CBER.
- **donanemab.** Sims JR *et al.* 2023, *JAMA* 330:512-527
  (TRAILBLAZER-ALZ 2 phase-3); FDA STN BL 761248 — donanemab-azbt
  (Kisunla) traditional approval 2024-07-02, CBER.
- **aducanumab.** Sevigny J *et al.* 2016, *Nature* 537:50-56
  (plaque-reduction proof-of-concept); FDA STN BL 761178 — aducanumab-
  avwa (Aduhelm) accelerated approval 2021-06-07, CBER; Biogen press
  release 2024-01-31 — voluntary discontinuation in the United States.

All three are honestly UNPLACED via the **same** pattern that
`AXIS/HIERARCHY.tape` already applies to gene/cell/mRNA therapies
(`@N genetic_medicine_status`) and antibody-drug conjugates
(`@N adc_status`). Each witness row carries:

- `fda_center: "CBER"` (g1 — per-row CBER documentation);
- `axis: null` (UNPLACED — no code axis);
- `in_scope: false` and `reported_not_run: true`;
- an explicit `cber_reason` string (why the mAb is CBER-regulated);
- an explicit `reason` string (criterion #4 + g8 rationale);
- `unplaced_precedent_in_repo` pointing back to the governing axis-layer
  notes;
- a `status_note` recording current regulatory status (approved /
  withdrawn) without editorial commentary (g3 / f4).

## §2 The legacy cholinergic palliatives — CDER but no clean axis mapping

The other FDA-approved AD drugs of interest here are the cholinergic
palliatives. These ARE CDER small molecules under hexa-bio's discipline,
BUT their mechanism does NOT map cleanly onto any of the expansion-layer
axes that the recent axis-tree expansion registered (PROTAC /
CAPSID-ASSEMBLY-MODULATOR / OLIGONUCLEOTIDE / METALLODRUG / COVALENT /
BIFUNCTIONAL / sub-axes). They are also SYMPTOMATIC, not
disease-modifying.

| # | Drug (brand)               | Sponsor          | FDA year | FDA center | Modality                                                                          |
|---|----------------------------|------------------|----------|------------|-----------------------------------------------------------------------------------|
| 1 | **donepezil** (Aricept)    | Eisai / Pfizer   | 1996     | CDER       | reversible centrally-acting AChE inhibitor                                        |
| 2 | **rivastigmine** (Exelon)  | Novartis         | 2000     | CDER       | pseudo-irreversible carbamate AChE + butyrylcholinesterase inhibitor              |
| 3 | **galantamine** (Razadyne) | Janssen / Shire  | 2001     | CDER       | reversible AChE inhibitor + nicotinic acetylcholine receptor allosteric potentiator |

Drug-precedent citations:

- **donepezil.** Sugimoto H *et al.* 1995, *J Med Chem* 38:4821-4829
  (discovery); FDA NDA 020690 — Aricept approval 1996-11-25, CDER.
- **rivastigmine.** Bar-On P *et al.* 2002, *Biochemistry* 41:3555-3564
  (carbamate mechanism); FDA NDA 020823 — Exelon approval 2000-04-21,
  CDER.
- **galantamine.** Maelicke A *et al.* 2001, *Biol Psychiatry* 49:279-288
  (dual mechanism); FDA NDA 021169 — Razadyne (formerly Reminyl) approval
  2001-02-28, CDER.

These rows are categorized as **CDER-but-no-axis-mapping** under a
distinct honesty const (`legacy_palliative_no_axis: true`), separate
from the CBER UNPLACED const. Each row carries:

- `fda_center: "CDER"` (CDER-class confirmed);
- `axis: null` (no clean axis mapping);
- `in_scope: false` and `reported_not_run: true`;
- a `no_axis_map_reason` string explaining WHY no expansion-layer axis
  applies (the axes were registered for modern modalities anchored to
  specific real limits; legacy cholinergic palliative mechanisms have
  no matching anchor — see §3);
- `symptomatic_not_disease_modifying: true` (g8 / f2 — no
  disease-modifying claim).

Force-fitting rivastigmine into the COVALENT axis (carbamate is
nominally covalent) or galantamine into ALLOSTERIC (it has nicotinic
allosteric potentiation) would be the **lattice-fit-on-external-entity**
anti-pattern (`f1`): observational similarity is not derivational
identity. The COVALENT axis was registered with the modern targeted-
covalent-inhibitor palette as its real-limit anchor (KRAS G12C/G12D
warheads, BTK irreversibles, etc.); legacy cholinergic carbamates are
outside that scope. Similar for ALLOSTERIC. **Honest call: flag, do not
force-fit.**

(memantine — an NMDA-receptor antagonist, FDA 2003, CDER — is the
fourth long-FDA-approved AD drug. It is not enumerated here because the
expansion focus of this case study is the disease-modifying landscape
and the cholinergic-palliative cohort that is most often discussed
alongside it; its omission is a scoping choice, not a denial of its
existence.)

## §3 Why this portfolio has ZERO IN-SCOPE-with-axis drugs

The zero-in-scope outcome is the **product of two independent honesty
constraints**, each binding on a different group of drugs:

1. **Criterion #4 + g8 — for the CBER mAbs.** The hexa-bio scope
   discipline is drug-only/CDER (`AXIS/README.md` criterion #4).
   Monoclonal antibodies are CBER biologics regulated under the PHSA
   §351 BLA pathway, not CDER NDA. Implementing a hypothetical
   "MONOCLONAL-ANTIBODY" or "ANTI-AMYLOID" axis to hold lecanemab /
   donanemab / aducanumab would BREACH criterion #4 AND would carry an
   implicit immunogenicity / Fc-effector / neutralizing-antibody-pre-
   screen claim load that g8 in-silico-only forbids. The honest
   handling is the same one already used for `@N genetic_medicine_
   status` and `@N adc_status`: UNPLACED.

2. **g3 / f1 — for the CDER cholinergic palliatives.** The expansion-
   layer axes (PROTAC / CAPSID-ASSEMBLY-MODULATOR / OLIGONUCLEOTIDE /
   METALLODRUG / COVALENT / BIFUNCTIONAL / sub-axes) were registered
   each with a specific real-limit anchor for a specific modern
   modality. AChE inhibition is a legacy cholinergic palliative
   mechanism with no axis built for it. Force-fitting donepezil into
   ALLOSTERIC or rivastigmine into COVALENT would treat observational
   resemblance as derivational identity — the
   `f1 lattice-fit-on-external-entity` anti-pattern. The honest
   handling is to flag them under `legacy_palliatives_no_axis` and
   move on.

A naïve portfolio could paper over these by inventing axes or by
relaxing scope; both moves are governance violations. The honest
choice is to acknowledge that the **truthful result** for Alzheimer,
under the current axis tree and scope discipline, is ZERO in-scope.

### 3.1 Why ZERO in-scope is a feature, not a gap

1. **It tests the axis tree's scope discipline.** A portfolio that
   trivially produced in-scope rows for every disease would not be
   testing the discipline — it would be papering over it. Alzheimer
   exercises the criterion #4 boundary directly.
2. **It keeps in-silico claims in-silico.** The two paths that would
   have produced non-zero in-scope rows (a CBER axis for mAbs, a
   force-fit of AChE-inhibitors into ALLOSTERIC/COVALENT) each carry
   claim loads that g8 forbids. Zero-in-scope keeps the discipline
   intact.
3. **It records the disease's drugs honestly.** The six drugs appear
   in the witness with their sponsors, FDA years, FDA centers,
   modalities, status notes, and drug-precedent citations — a reader
   of the portfolio is not left with the impression that AD has no
   FDA-approved drugs. The witness says: here are the drugs; here is
   why none of them sit in the in-scope axes.
4. **It is structurally enforced, not editorial.** The schema's
   `in_scope_drugs` is `minItems: 0, maxItems: 0, items: false` — it
   REQUIRES the empty array. The honesty block's
   `zero_in_scope_acknowledged: const true` + `zero_in_scope_is_a_
   valid_outcome: const true` are schema-level consts. Any future
   attempt to silently introduce an in-scope row would fail schema
   validation.

## §4 Governance

The case study sits inside the standard hexa-bio governance stack:

- **g1 real-limits-first.** Each not-in-scope CBER row carries a
  per-row `cber_reason` documenting WHY the drug is CBER-regulated
  (monoclonal antibody = biologic under PHSA §351, BLA not NDA). Each
  legacy palliative row carries a per-row `no_axis_map_reason`
  documenting WHY no expansion-layer axis applies. There is no
  in-scope row to anchor to a thermodynamic / kinetic real limit by
  design — that absence is the honest outcome.
- **g3 honesty-external / f1 lattice-fit-on-external-entity.** All six
  drugs are described **only** via their own published precedent
  (CLARITY AD; TRAILBLAZER-ALZ 2; Aduhelm phase-3 + 2024 withdrawal;
  Aricept 1996; Exelon 2000; Razadyne 2001). Nothing is lattice-derived
  (`f_lattice_fit`). No "n=6 → 3 mAbs + 3 palliatives" derivation. The
  AChE-inhibitors are NOT force-fit into ALLOSTERIC or COVALENT.
- **g8 in-silico-only / f2 wet-lab-clinical-claim-from-in-silico.** No
  in-silico sim is invoked (there is no in-scope axis to invoke one for).
  The witness asserts no therapeutic, clinical, amyloid-clearance,
  cognitive, efficacy, immunogenic, regulatory, or
  portfolio-recommendation claim. The legacy-palliative rows also carry
  `symptomatic_not_disease_modifying: true`.
- **g11 (analogue) vendored-snapshots-readonly.** No shared files are
  edited by this case study. `AXIS/*`, `selftest/run_all.sh`,
  `AGENTS.tape`, `HEXA-*.tape`, root `README.md` are untouched. The
  case study lives entirely under `case_studies/alzheimer_portfolio/`.
- **f3 shadow-implementation-of-sister-repo.** The runner imports
  nothing from `_python_bridge/module/` — there is no in-scope axis
  sim to import. This is the honest absence; not a fork.
- **f4 external-contact-proposal-in-summary.** The runner does not
  recommend external contact, regulatory action, or any propose-step.
  The Aduhelm withdrawal is recorded factually in `status_note` without
  editorial commentary.
- **scope discipline (criterion #4 drug-only/CDER).** Honored —
  lecanemab / donanemab / aducanumab are honestly UNPLACED per the
  same pattern that already governs GENETIC-MEDICINE / ADC /
  THERANOSTIC in `AXIS/HIERARCHY.tape`.

### 4.1 What this case study is NOT

- NOT a portfolio recommendation, ranking, or investment thesis.
- NOT a claim that any one of the six drugs is superior to the others.
  All six are FDA-approved (one currently withdrawn).
- NOT a clinical, regulatory, immunogenicity, amyloid-clearance,
  cognitive, dosing, or efficacy claim.
- NOT an editorial on the Aduhelm 2021 accelerated-approval decision or
  the 2024 voluntary withdrawal; status is recorded factually.
- NOT a derivation of the modality counts from the n=6 lattice.
- NOT the deferred 200-disease portfolio re-mapping; this is the
  one-disease Alzheimer pilot only.
- NOT a closed list of all Alzheimer drugs — memantine and combination
  products are omitted from the enumeration here for focus, not denied.

## §5 Cross-links to prior in-repo precedent

The pattern this case study applies has two precedents already on
record in the repo:

- `AXIS/HIERARCHY.tape` `@N genetic_medicine_status` — the canonical
  in-repo statement that CBER biologics (gene / cell / mRNA therapy)
  are UNPLACED by criterion #4 and that implementing a CBER-scope code
  axis would breach g8. Same rationale used here for the three
  anti-amyloid mAbs.
- `AXIS/HIERARCHY.tape` `@N adc_status` — parallel UNPLACED note for
  antibody-drug conjugates (antibody component = CBER biologic).
  Establishes the CBER + mAb UNPLACED pattern that this Alzheimer
  case study extends.
- `case_studies/sma_portfolio/` — the **Zolgensma precedent**:
  onasemnogene abeparvovec / Zolgensma is the SMA portfolio's UNPLACED
  drug for the same reason (AAV9 gene therapy = CBER biologic). SMA had
  one UNPLACED of three; Alzheimer takes the same logic to its honest
  extremity, where the entire disease-modifying landscape is UNPLACED.

This case study is therefore not a new policy — it is the consistent
application of the existing CBER-UNPLACED policy to a disease where
that policy's bite is total. The legacy-cholinergic-palliative cohort
is the additional honest category this case study introduces: CDER but
no clean axis mapping. The schema's separate `legacy_palliatives_no_
axis` array with its distinct `legacy_palliative_no_axis: true` const
keeps that category structurally distinct from CBER UNPLACED.

## §6 Files

- `README.md` — this writeup.
- `alzheimer_portfolio_runner.py` — deterministic stdlib-only runner.
  Imports no in-axis sim (by design). Emits the portfolio witness JSON
  with empty `in_scope_drugs`, three CBER UNPLACED rows, three
  legacy-palliative-no-axis rows. Prints the
  `__ALZHEIMER_PORTFOLIO__ PASS` sentinel on success.
- `portfolio_v1.schema.json` — draft-07 JSON Schema. Permits
  `in_scope_drugs` to be the empty array (`minItems: 0, maxItems: 0`,
  `items: false`); separates `not_in_scope_drugs` (`fda_center: const
  "CBER"`, `axis: null`) from `legacy_palliatives_no_axis`
  (`fda_center: const "CDER"`, `axis: null`, `legacy_palliative_no_
  axis: const true`); enforces `zero_in_scope_acknowledged: const true`
  + `zero_in_scope_is_a_valid_outcome: const true` in the honesty block.

Run the runner directly:

```bash
python3 case_studies/alzheimer_portfolio/alzheimer_portfolio_runner.py
```

Expected: exit 0, last line `__ALZHEIMER_PORTFOLIO__ PASS`. The witness
JSON is emitted on stdout (`sort_keys=True`, `indent=2`) and is
byte-identical on every run.
