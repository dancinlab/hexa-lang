# Parkinson disease portfolio — case study (honesty showcase)

Parkinson disease (PD) is the case study whose FDA-approved
pharmacopoeia is dominated by **OLD (1970s-2010s) CDER small molecules
whose mechanisms do not map cleanly onto the new expansion-layer axes**.
It joins Alzheimer (ZERO in-scope) and Type 2 Diabetes (SGLT2 inhibitors
no-axis-map) as another extremity of the **no-clean-axis-fit** pattern:
the new axes were designed for new modalities; legacy CNS
pharmacology is not well-served by them.

This is the **one-disease Parkinson pilot** — NOT the deferred
200-disease re-mapping flagged in `AXIS/HIERARCHY.tape` Log.

## §0 Honest scope — borderline + no-axis-map is the truthful result

The deliverable here is:

1. an honest writeup of why this disease's FDA-approved drugs produce
   **two BORDERLINE COVALENT rows** (rasagiline / selegiline, MAO-B
   irreversible propargylamines that DO form a covalent bond but to a
   non-canonical target) + **four CDER-no-axis-mapping rows** (levodopa,
   entacapone, opicapone, safinamide) under the expansion-layer axis
   tree;
2. a deterministic stdlib-only Python runner that imports the parent
   `covalent_inhibition_sim.py` via `importlib` (governance f3 — no
   fork), exercises its Eyring TST arithmetic on a class-level
   surrogate, and emits the portfolio witness JSON;
3. a draft-07 JSON Schema for the witness with three separated arrays —
   `in_scope_drugs` (2 borderline-COVALENT entries with the
   `borderline_axis_mapping: const true` flag), `cder_in_scope_no_axis_mapping`
   (4 entries with `cder_in_scope_but_no_axis_mapping: const true`, the
   same honesty const as the T2DM portfolio), and `not_in_scope_drugs`
   (research-stage CBER UNPLACED — AAV gene therapy + anti-alpha-
   synuclein mAbs).

Every PASS here is **in-silico simulator-consistency only** (governance
g8 / f2). It is NEVER a therapeutic, clinical, motor-symptom,
neuroprotective, disease-modifying, immunogenic, regulatory, or
portfolio-recommendation claim.

## §1 The two borderline-COVALENT MAO-B irreversibles (IN-SCOPE-BORDERLINE)

| # | Drug (brand)             | Sponsor | FDA year | FDA center | Modality                                      |
|---|--------------------------|---------|----------|------------|-----------------------------------------------|
| 1 | **rasagiline** (Azilect) | Teva    | 2006     | CDER       | MAO-B selective IRREVERSIBLE propargylamine inhibitor — covalent N5-flavocyanine adduct with FAD |
| 2 | **selegiline** (Eldepryl)| Mylan   | 1989     | CDER       | MAO-B selective IRREVERSIBLE propargylamine inhibitor — covalent N5-flavocyanine adduct with FAD; original L-deprenyl |

Drug-precedent citations (g3 / f1, own published modality only):

- **rasagiline.** Youdim MB, Bakhle YS 2006, *Br J Pharmacol*
  147:S287-S296 (MAO inhibitor pharmacology review; rasagiline
  N-propargyl-1-aminoindan mechanism); Binda C *et al.* 2004, *J Med
  Chem* 47:1767-1774 (crystal structure of rasagiline bound to MAO-B;
  flavin N5 adduct); FDA NDA 021641 — rasagiline mesylate (Azilect)
  approval 2006-05-16, CDER.
- **selegiline.** Youdim MB, Bakhle YS 2006, *Br J Pharmacol*
  147:S287-S296 (MAO inhibitor pharmacology review); Knoll J, Magyar K
  1972, *Adv Biochem Psychopharmacol* 5:393-408 (selegiline / deprenyl
  discovery and MAO-B selectivity); FDA NDA 019334 — selegiline
  hydrochloride (Eldepryl) approval 1989-06-05, CDER.

### 1.1 Why the placement is BORDERLINE, not clean

MAO-B irreversible propargylamines DO form a covalent bond —
observational covalency is present and not in dispute. **But** the bond
is between the propargyl carbon of the drug and the **flavin N5 of the
FAD cofactor**, NOT to a target-protein cysteine thiolate. The modern
COVALENT axis was registered with the **cysteine-acrylamide warhead
palette** as its real-limit anchor: ibrutinib (BTK Cys481, FDA 2013),
sotorasib / adagrasib (KRAS-G12C Cys12, FDA 2021/2022), afatinib (EGFR
Cys797, FDA 2013). MAO-B propargylamines lie **outside that warhead
palette**.

The honest call is therefore **BORDERLINE COVALENT**, not clean
COVALENT. Every in-scope row carries:

- `axis: "COVALENT"` (the axis the drug borderline-maps onto);
- `borderline_axis_mapping: true` (the structural honesty flag);
- `borderline_reason: "..."` (per-row explanation);
- `real_limit_anchor: "Eyring TST ..."` (the **generic** kB·T/h
  ceiling that applies to any elementary covalent step regardless of
  warhead chemistry — Eyring 1935; the kinact/Ki kinetic framework,
  Strelow 2017, is registered as the parent sim's framework anchor and
  reported as carried forward from the parent sim's panel surrogate,
  NOT fitted to the drug);
- `sim_module: "covalent_inhibition_sim"` + `sim_panel_surrogate:
  "acrylamide_thio_michael_class_surrogate"` (the parent sim's
  warhead-class surrogate exercised on a literature-informed class ΔG‡
  ≈ 19.0 kcal/mol — NOT a rasagiline / selegiline kinact fit);
- `kinact_eyring_tst_per_s` + `eyring_prefactor_ceiling_per_s` +
  `kinact_tst_below_eyring_ceiling: const true` (Eyring TST ceiling
  respected by the row).

Omitting the borderline flag and silently placing the drugs under
COVALENT would be **`f1 lattice-fit-on-external-entity`** (observational
similarity treated as derivational identity). The schema enforces the
borderline flag as `const true`; the runner emits the explicit
borderline_reason on every row.

## §2 The four CDER-no-axis-mapping drugs

| # | Drug (brand)             | Sponsor                | FDA year | FDA center | Modality                                                     |
|---|--------------------------|------------------------|----------|------------|--------------------------------------------------------------|
| 3 | **levodopa** (Sinemet)   | MSD                    | 1970     | CDER       | dopamine PRECURSOR amino-acid replacement therapy (L-DOPA + carbidopa peripheral AADC-i) |
| 4 | **entacapone** (Comtan)  | Novartis               | 1999     | CDER       | reversible peripheral COMT inhibitor (nitrocatechol)         |
| 5 | **opicapone** (Ongentys) | Neurocrine (BIAL orig.)| 2020     | CDER       | reversible peripheral COMT inhibitor (oxadiazole nitrocatechol; slow-off) |
| 6 | **safinamide** (Xadago)  | Newron                 | 2017     | CDER       | REVERSIBLE MAO-B inhibitor (alpha-aminoamide) + state-dependent sodium-channel block / glutamate-release modulator |

Drug-precedent citations (g3 / f1, own published modality only):

- **levodopa.** Cotzias GC, Van Woert MH, Schiffer LM 1967, *N Engl J
  Med* 276:374-379 (L-DOPA oral therapy for Parkinson disease);
  Birkmayer W, Hornykiewicz O 1961, *Wien Klin Wochenschr* 73:787-788
  (intravenous L-DOPA for parkinsonian akinesia); FDA NDA 017555 —
  carbidopa-levodopa (Sinemet) approval 1975-05-02, CDER (levodopa
  monotherapy FDA-approved 1970).
- **entacapone.** Mannisto PT, Kaakkola S 1999, *Pharmacol Rev*
  51:593-628 (COMT and its inhibitors); Backstrom R *et al.* 1989,
  *J Med Chem* 32:841-846 (nitrocatechol COMT inhibitor design); FDA
  NDA 020796 — entacapone (Comtan) approval 1999-10-19, CDER.
- **opicapone.** Kiss LE *et al.* 2010, *J Med Chem* 53:3396-3411
  (opicapone discovery; nitrocatechol oxadiazole COMT inhibitor);
  Ferreira JJ *et al.* 2016, *Lancet Neurol* 15:154-165 (BIPARK-I
  opicapone phase III); FDA NDA 212489 — opicapone (Ongentys) approval
  2020-04-24, CDER.
- **safinamide.** Caccia C *et al.* 2006, *Neurology* 67(7 Suppl
  2):S18-S23 (safinamide pharmacology — reversible MAO-B + glutamate);
  Borgohain R *et al.* 2014, *Mov Disord* 29:229-237 (safinamide SETTLE
  phase III); FDA NDA 207145 — safinamide (Xadago) approval 2017-03-21,
  CDER.

Each row carries the **same honesty const** the T2DM portfolio
introduced — `cder_in_scope_but_no_axis_mapping: const true` — plus a
per-row `no_axis_map_reason`, `symptomatic_not_disease_modifying: const
true`, and `reported_not_run: const true`. No axis sim is invoked for
these rows by design.

Why no axis maps onto these:

- **levodopa** is a single amino acid administered as a metabolic
  precursor; it is **NOT a folded peptide** (so the PEPTIDE sub-axis
  with its Zimm-Bragg helix-coil anchor does not apply — there is no
  helix-coil partition to compute on one residue), NOT a metallodrug,
  NOT a covalent inhibitor, NOT a PROTAC / molecular glue, NOT a
  macrocycle, NOT RNA-targeting. Amino-acid-precursor replacement is a
  1960s metabolic-substitution mechanism with no matching expansion-
  layer axis.
- **entacapone / opicapone** are reversible competitive enzyme
  inhibitors — the classical small-molecule mechanism. The expansion-
  layer axes were registered for new-modality invariants; a reversible
  classical enzyme inhibitor does not introduce a new invariant.
  (Same honest-gap call as the T2DM portfolio's SGLT2 inhibitors.)
- **safinamide** is **REVERSIBLE** MAO-B — explicitly NOT a covalent
  warhead mechanism (no propargylamine, no FAD adduct). The additional
  state-dependent sodium-channel block is classical channel
  pharmacology. Because safinamide is reversible it does **not** even
  share the observational covalency that flags rasagiline / selegiline
  as borderline COVALENT.

Force-fitting any of these into a COVALENT / METALLODRUG / PEPTIDE /
ALLOSTERIC axis would be **`f1 lattice-fit-on-external-entity`**.

## §3 Research-stage CBER UNPLACED (not_in_scope_drugs)

Parkinson disease has had multiple CBER-class research candidates over
the years; **none is FDA-approved** at this case study's evidence
horizon. Two representative candidate classes are recorded as honest
negatives (`fda_approved: false`, `axis: null`, `fda_center_if_filed:
"CBER"`, `reported_not_run: true`):

- **AAV-based gene therapy** (AAV2-GDNF, AAV2-AADC, AAV2-GAD —
  multiple sponsors, phase I/II). AAV-vectored therapeutics are CBER
  biologics under the PHSA §351 BLA pathway; outside criterion #4
  drug-only/CDER discipline. Same pattern as Zolgensma in
  `case_studies/sma_portfolio/` and the
  `AXIS/HIERARCHY.tape @N genetic_medicine_status` precedent.
- **anti-alpha-synuclein monoclonal antibodies** (prasinezumab,
  cinpanemab — phase II readouts; cinpanemab discontinued 2021). mAbs
  are CBER biologics under PHSA §351 BLA. Same pattern as the
  anti-amyloid mAbs in `case_studies/alzheimer_portfolio/`.

Listing recent candidates that have been advertised as breakthroughs
but lack an FDA approval (e.g. *lenrispodun* / LRP-1) is intentionally
avoided unless an FDA action is verifiable; the schema requires
`fda_approved: const false` for every row in this array, and the README
prose stops at candidate-class enumeration rather than naming individual
unapproved candidates as if they were on a near-term approval path.

## §4 Why this portfolio is honestly NO-CLEAN-AXIS-FIT

The Parkinson result is the **product of three independent honesty
constraints**, each binding on a different group of drugs:

1. **`f1` for the MAO-B propargylamines.** rasagiline and selegiline DO
   form a covalent bond, but to flavin N5 of FAD — not the
   cysteine-warhead palette the COVALENT axis was registered for. Clean
   COVALENT placement would be observational similarity treated as
   derivational identity. Honest handling: borderline placement with
   `borderline_axis_mapping: const true` and an explicit per-row
   `borderline_reason` — the Eyring TST generic ceiling (kB·T/h)
   anchors the row; the warhead-class divergence is the documented
   honesty caveat.
2. **`f1` (same anti-pattern) for the four CDER-no-axis drugs.** The
   expansion-layer axes were registered for **specific new-modality
   invariants** (PROTAC ternary geometry, COVALENT warhead reactivity,
   METALLODRUG coordination chemistry, MACROCYCLE peptide stapling,
   OLIGONUCLEOTIDE / RNA-targeting, etc.). Amino-acid precursor
   replacement (levodopa), reversible COMT inhibition
   (entacapone / opicapone), and reversible MAO-B + sodium-channel
   pharmacology (safinamide) are **classical pharmacology mechanisms
   with no matching new-modality invariant**. Honest handling: same
   `cder_in_scope_but_no_axis_mapping` honest-gap const the T2DM
   portfolio introduced for SGLT2 inhibitors.
3. **Criterion #4 + g8 for the research-stage CBER candidates.** AAV
   gene therapy and anti-alpha-synuclein mAbs are CBER-class biologics
   regulated under PHSA §351 BLA, not CDER NDA. Per criterion #4
   drug-only/CDER discipline the hexa-bio axis tree does not register
   CBER biologics; implementing a CBER-scope code axis would breach
   g8 in-silico-only (mAb immunogenicity / Fc-effector profile carries
   claim load the in-silico axes cannot bound; AAV biodistribution /
   capsid immunity likewise).

### 4.1 What this case study is NOT

- NOT a portfolio recommendation, ranking, or investment thesis.
- NOT a claim that any drug is superior to the others. All six listed
  FDA-approved drugs are FDA-approved.
- NOT a clinical, motor-symptom, neuroprotective, disease-modifying,
  immunogenicity, dyskinesia, "off" time, dosing, or efficacy claim.
- NOT a derivation of the modality counts from the n=6 lattice
  (`f_lattice_fit`).
- NOT the deferred 200-disease portfolio re-mapping; this is the
  one-disease Parkinson pilot only.
- NOT a closed list of all Parkinson drugs — amantadine, dopamine
  agonists (pramipexole / ropinirole / rotigotine / apomorphine),
  anticholinergics (benztropine / trihexyphenidyl), istradefylline
  (A2A antagonist, FDA 2019, CDER) and various combination products are
  intentionally not enumerated to keep the portfolio focused on the
  three category transitions (borderline COVALENT, CDER-no-axis-map,
  research-stage CBER). Their omission is a scoping choice, not a
  denial of their existence — every omitted drug would land in
  `cder_in_scope_no_axis_mapping` (or one of those categories) by the
  same honesty analysis.

## §5 Governance

The case study sits inside the standard hexa-bio governance stack:

- **g1 real-limits-first.** Each borderline-COVALENT row carries the
  parent sim's real-limit anchor forward: Eyring TST kB·T/h universal
  ceiling for the elementary covalent step (Eyring 1935) plus the
  Strelow 2017 kinact/Ki framework reported as carried forward (NOT
  drug-fitted). The schema enforces `kinact_tst_below_eyring_ceiling:
  const true` on every in-scope row. The four CDER-no-axis rows have
  no in-scope axis sim and therefore no real-limit anchor by design —
  per-row `no_axis_map_reason` documents the gap.
- **g3 honesty-external / f1 lattice-fit-on-external-entity.** All
  drugs are described **only** via their own published precedent
  (rasagiline, selegiline, levodopa, entacapone, opicapone, safinamide).
  Nothing is lattice-derived (`f_lattice_fit`). No "n=6 → 6 drugs"
  derivation. The MAO-B propargylamines are NOT silently force-fit into
  COVALENT — every in-scope row carries the borderline flag.
- **g8 in-silico-only / f2 wet-lab-clinical-claim-from-in-silico.** No
  therapeutic / motor-symptom / neuroprotective / disease-modifying /
  immunogenic / regulatory / portfolio-recommendation claim. Every CDER-
  no-axis row carries `symptomatic_not_disease_modifying: const true`.
- **g11-analogue vendored-snapshots-readonly.** No shared files are
  edited. `AXIS/*`, `selftest/run_all.sh`, `AGENTS.tape`, `HEXA-*.tape`,
  root `README.md`, `_python_bridge/module/covalent_inhibition_sim.py`
  are untouched. The case study lives entirely under
  `case_studies/parkinson_portfolio/`.
- **f3 shadow-implementation-of-sister-repo.** The runner IMPORTS
  `covalent_inhibition_sim` via `importlib`; it does not re-implement
  the Eyring TST arithmetic or the two-step kinetic model.
- **criterion #4 drug-only/CDER scope discipline.** Honored —
  research-stage AAV gene therapy and anti-alpha-synuclein mAbs are
  honestly UNPLACED per the SMA-portfolio /
  `@N genetic_medicine_status` precedent.

## §6 Cross-links to prior in-repo precedent

- `case_studies/alzheimer_portfolio/` — the **ZERO IN-SCOPE pattern**.
  Alzheimer is the extremity (all three disease-modifying drugs are
  CBER mAbs; the cholinergic palliatives are CDER but no-axis-map);
  Parkinson is the same family but with two BORDERLINE COVALENT rows
  surviving on the in-scope side.
- `case_studies/type2_diabetes_portfolio/` — the
  **`cder_in_scope_but_no_axis_mapping`** honesty const introduced for
  SGLT2 inhibitors. Parkinson re-uses the same const for levodopa,
  entacapone, opicapone, and safinamide. The two portfolios are
  structurally compatible — the const is shared, not redefined.
- `case_studies/sma_portfolio/` — the **Zolgensma UNPLACED precedent**
  (AAV gene therapy = CBER biologic). The Parkinson research-stage
  candidates (AAV2-GDNF / AAV2-AADC / AAV2-GAD) are listed under the
  same UNPLACED pattern.
- `_python_bridge/module/covalent_inhibition_sim.py` — the parent
  COVALENT axis sim. Imported via `importlib`, not forked (governance
  f3). The Eyring TST machinery (`eyring_rate`, `EYRING_PREFACTOR`) is
  exercised on a literature-informed warhead-class surrogate
  (ΔG‡ ≈ 19.0 kcal/mol, acrylamide-thio-michael class — NOT a
  rasagiline / selegiline kinact fit; the parent sim's own honesty note
  governs).

## §7 Files

- `README.md` — this writeup.
- `parkinson_portfolio_runner.py` — deterministic stdlib-only runner.
  Imports `covalent_inhibition_sim.py` via `importlib` (no fork —
  governance f3). Emits the portfolio witness JSON with 2 borderline-
  COVALENT entries (rasagiline, selegiline), 4 CDER-no-axis-mapping
  entries (levodopa, entacapone, opicapone, safinamide), and 2
  research-stage CBER UNPLACED entries (AAV gene therapy, anti-alpha-
  synuclein mAbs). Prints the `__PARKINSON_PORTFOLIO__ PASS` sentinel
  on success.
- `portfolio_v1.schema.json` — draft-07 JSON Schema. Three separated
  arrays: `in_scope_drugs` (`fda_center: const "CDER"`, `axis: const
  "COVALENT"`, `borderline_axis_mapping: const true`,
  `kinact_tst_below_eyring_ceiling: const true`),
  `cder_in_scope_no_axis_mapping` (`fda_center: const "CDER"`,
  `axis: null`, `cder_in_scope_but_no_axis_mapping: const true`,
  `symptomatic_not_disease_modifying: const true`), and
  `not_in_scope_drugs` (`fda_approved: const false`,
  `fda_center_if_filed: const "CBER"`, `axis: null`).

Run the runner directly:

```bash
python3 case_studies/parkinson_portfolio/parkinson_portfolio_runner.py
```

Expected: exit 0, last line `__PARKINSON_PORTFOLIO__ PASS`. The witness
JSON is emitted on stdout (`sort_keys=True`, `indent=2`) and is
byte-identical on every run.
