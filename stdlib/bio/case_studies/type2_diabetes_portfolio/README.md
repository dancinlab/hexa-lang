# Type 2 Diabetes portfolio — case study

Type 2 Diabetes Mellitus (T2DM) is the case where multiple FDA-approved
drug classes hit the same disease via mechanistically distinct routes —
some classes map cleanly onto hexa-bio expansion-layer axes, **some are
CDER small molecules whose mechanism the new code axes were never
designed to cover**, and some are CBER biologics that fall outside the
drug-only/CDER criterion #4 scope boundary. This case study writes that
fact up — and introduces a NEW honest category distinct from the SMA
portfolio's CBER UNPLACED pattern.

## §0 Honest scope

This is a **one-disease pilot** — T2DM only. It is NOT the deferred
200-disease portfolio re-mapping. The deliverable here is:

1. a portfolio writeup of FDA-approved T2DM drugs and how they map (or
   honestly do not map) onto the hexa-bio axis tree;
2. a deterministic stdlib-only Python runner that exercises the
   PEPTIDE-axis sim for the two in-scope peptide drugs and emits a
   portfolio witness JSON;
3. a draft-07 JSON Schema for that witness with **three separated
   arrays** — `in_scope_drugs` (axis-mapped) / `cder_in_scope_no_axis_mapping`
   (the NEW honest category) / `not_in_scope_drugs` (CBER UNPLACED).

Every PASS here is **in-silico simulator-consistency only** (governance
g8 / f2). It is NEVER a therapeutic, clinical, glycemic, efficacy,
cardiovascular, weight-loss, immunogenic, regulatory, or
portfolio-recommendation claim.

## §1 FDA-approved T2DM drugs in this portfolio

T2DM is a heterogeneous metabolic disease (insulin resistance + relative
β-cell insulin-secretion deficit + accumulated hyperglycemia). The
FDA-approved pharmacopoeia spans many distinct mechanism classes. This
portfolio is intentionally **focused** — it includes the two GLP-1-class
peptides (clean PEPTIDE-axis mapping), the three SGLT2-inhibitor small
molecules (the NEW CDER-but-no-axis-mapping demonstration), and the
CBER insulin analogs (UNPLACED). Metformin (biguanide, very old,
complex/AMPK-mediated mechanism) and thiazolidinediones (PPAR-γ
agonists) are intentionally left out to keep the portfolio focused on
the three category transitions.

| # | Drug (brand) | Sponsor | FDA year | FDA center | Modality | Category |
|---|---|---|---|---|---|---|
| 1 | **semaglutide** (Ozempic / Wegovy / Rybelsus) | Novo Nordisk | 2017 inj. / 2019 oral | CDER | GLP-1 receptor agonist peptide | IN-SCOPE → `PEPTIDE` (`:>` `WEAVE` core) |
| 2 | **tirzepatide** (Mounjaro / Zepbound) | Eli Lilly | 2022 | CDER | dual GIP+GLP-1 agonist peptide | IN-SCOPE → `PEPTIDE` (`:>` `WEAVE` core) |
| 3 | **dapagliflozin** (Farxiga) | AstraZeneca | 2014 | CDER | SGLT2 inhibitor small molecule | **CDER-IN-SCOPE-NO-AXIS-MAPPING** (new category) |
| 4 | **empagliflozin** (Jardiance) | Boehringer Ingelheim / Lilly | 2014 | CDER | SGLT2 inhibitor small molecule | **CDER-IN-SCOPE-NO-AXIS-MAPPING** |
| 5 | **canagliflozin** (Invokana) | Johnson & Johnson | 2013 | CDER | SGLT2 inhibitor small molecule | **CDER-IN-SCOPE-NO-AXIS-MAPPING** |
| 6 | **insulin analogs** (Humalog / Lantus / Tresiba etc.) | various | various | **CBER** | recombinant insulin protein biologic | NOT-IN-SCOPE — CBER UNPLACED (criterion #4) |

### 1.1 semaglutide (Ozempic / Wegovy / Rybelsus) → `PEPTIDE`

semaglutide is a GLP-1 receptor agonist peptide analog of native human
GLP-1(7-37). Substitutions at positions 8 (Aib) and 34 (Arg) plus a
C18 fatty-diacid linker confer protease resistance and albumin binding;
the receptor-bound backbone is α-helical. Approved injectable in 2017
(Ozempic) and as the first oral GLP-1 receptor agonist (Rybelsus) in
2019; the high-dose obesity formulation (Wegovy) was approved 2021.

- Axis: `PEPTIDE` — a sub-axis of `WEAVE` declared in
  `AXIS/HIERARCHY.tape` `@D sub_under_weave`. semaglutide is named as
  modality precedent inside the parent sim itself
  (`_python_bridge/module/peptide_sim.py` panel + docstring).
- In-axis sim: `_python_bridge/module/peptide_sim.py` (deterministic
  Zimm-Bragg helix-coil partition; `__PEPTIDE__ PASS`). This runner
  IMPORTS it via `importlib` (no fork — governance f3).
- Real-limit anchor (g1): Zimm-Bragg helix-coil theory. Zimm & Bragg
  1959, *J. Chem. Phys.* 31:526 (the cooperative two-state model);
  equivalent Lifson-Roig formulation, Lifson & Roig 1961, *J. Chem.
  Phys.* 34:1963. Helix propensities follow Pace & Scholtz 1998 /
  Chakrabartty, Kortemme & Baldwin 1994 host-guest scales.
- Drug precedent (g3 / f1, own published modality only): Lau *et al.*
  2015, *J. Med. Chem.* 58:7370-7380 (semaglutide discovery /
  pharmacokinetic optimization).

### 1.2 tirzepatide (Mounjaro / Zepbound) → `PEPTIDE`

tirzepatide is a 39-residue dual-agonist peptide that engages both the
GIP and GLP-1 receptors. It carries an Aib at positions 2 and 13 and a
C20 fatty-diacid linker for albumin binding; the engineered backbone
retains the α-helical receptor-binding geometry shared with the GLP-1
class. Approved 2022 for T2DM (Mounjaro) and 2023 for obesity (Zepbound).

- Axis: `PEPTIDE` (same sub-axis as semaglutide). Tirzepatide is
  explicitly named in the `peptide_sim.py` modality-precedent panel as
  part of the GLP-1 analog class.
- In-axis sim: same `peptide_sim.py` parent (no fork — f3). The cross-axis
  G4 touch-point (PEPTIDE × MACROCYCLE) covers the peptide-chemistry
  side of this class.
- Real-limit anchor (g1): same Zimm-Bragg helix-coil theory as §1.1.
- Drug precedent (g3 / f1, own published modality only): Coskun *et al.*
  2018, *Mol. Metab.* 18:3-14 (LY3298176 / tirzepatide discovery).

### 1.3 SGLT2 inhibitors → CDER-IN-SCOPE-but-NO-AXIS-MAPPING (NEW)

dapagliflozin (Farxiga, AstraZeneca, FDA 2014), empagliflozin (Jardiance,
BI/Lilly, FDA 2014) and canagliflozin (Invokana, J&J, FDA 2013) are
**FDA-approved CDER small-molecule drugs** that inhibit the renal
sodium-glucose cotransporter 2 (SGLT2 / *SLC5A2*) in the proximal
convoluted tubule, blocking renal glucose reabsorption and inducing
glucosuria. See §3 for the full new-category writeup.

### 1.4 insulin analogs → NOT-IN-SCOPE (CBER UNPLACED)

Recombinant insulin analogs (Humalog/lispro, Lantus/glargine,
Tresiba/degludec, NovoLog/aspart, etc.) are **CBER-regulated protein
biologics**. CBER biologics fall outside the drug-only/CDER criterion #4
scope boundary — the same pattern that already governs Zolgensma in the
SMA portfolio, and GENETIC-MEDICINE / ADC / THERANOSTIC in
`AXIS/HIERARCHY.tape`. See §4 for the UNPLACED handling.

## §2 In-silico runs

The runner `type2_diabetes_portfolio_runner.py` invokes the PEPTIDE
parent sim on the two GLP-1-class peptides and aggregates the outputs
into a single portfolio witness JSON.

### 2.1 What is run

- **semaglutide-like path** — the `peptide_sim` parent provides a
  `model_glp1_like` panel entry. The runner exercises that entry's
  helix-coil partition via `helix_coil_partition()` to read out the
  fractional helicity θ_H and the partition Z. The reported model signal
  is θ_H — the equilibrium fraction of residues in the α-helical state
  under the Zimm-Bragg cooperative two-state model.
- **tirzepatide-like path** — the same `peptide_sim` parent is invoked
  on a separate engineered-helicity model peptide (the `model_helical_high`
  panel entry); this carries the dual-agonist engineered-helicity precedent
  in the same parent-sim panel. The reported model signal is θ_H from the
  same Zimm-Bragg partition. The σ→1 independent-residue baseline is also
  reported as the analytic non-cooperative cross-check.
- **SGLT2 inhibitors** — REPORTED-NOT-RUN. No PEPTIDE-axis sim is
  invoked for these rows by design; their mechanism is renal-transporter
  inhibition, not a peptide conformational ensemble. They appear in the
  `cder_in_scope_no_axis_mapping[]` array with `axis: null`,
  `fda_center: "CDER"`, `in_scope_by_cder_discipline: true`,
  `no_axis_mapping: true`, and an explicit `reason` string. See §3.
- **insulin analogs** — REPORTED-NOT-RUN. CBER biologic — UNPLACED. See §4.

### 2.2 Sequences are toy constructs

The illustrative GLP-1-like and engineered-helicity model sequences live
inside `peptide_sim.py` and are **toy constructs** chosen to span the
helicity range — not the literal drug sequences. They exercise the
Zimm-Bragg model arithmetic; they assert no real receptor binding,
permeability or potency (g8 / f2).

### 2.3 Determinism

The upstream `peptide_sim` is stdlib-only and deterministic (exact 2^N
partition enumeration). The runner is likewise stdlib-only. `json.dumps(
build_portfolio(), sort_keys=True)` produces byte-identical output on
every run — the deductive-verification contract used across
`_python_bridge/module/`.

## §3 NEW honest category — CDER-in-scope but no axis mapping

This is the **new pattern** this portfolio introduces. It is **distinct**
from the CBER UNPLACED pattern that the SMA portfolio already
demonstrates.

### 3.1 The mechanism

SGLT2 inhibitors (dapagliflozin / empagliflozin / canagliflozin) block
the renal sodium-glucose cotransporter 2 — a membrane transporter in the
proximal convoluted tubule that normally reabsorbs ~90% of filtered
glucose. Inhibition triggers glucosuria (urinary glucose excretion),
lowering plasma glucose independent of insulin. The drugs are
C-glucoside small molecules; SGLT2 is the validated target.

### 3.2 Why no axis maps onto this

The hexa-bio expansion-layer axes (and their sub-axes) were designed for
specific NEW MODALITY CHEMISTRIES whose distinct invariants justify a
separate axis tree:

- `PROTAC` — heterobifunctional E3-ligase recruiter + target binder
  (induced ternary complex);
- `CAM` / molecular glue — small-molecule-induced new PPI interface;
- `COVALENT` — covalent inhibitor with a warhead;
- `METALLODRUG` — coordination-chemistry-driven mechanism;
- `MACROCYCLE` — cyclic / stapled peptide chemistry;
- `MWC-ALLOSTERIC` — concerted allosteric switch model;
- `RNA-TARGETING-SMALL-MOLECULE` — small molecule binds an RNA target;
- (etc., per `AXIS/HIERARCHY.tape`).

SGLT2 inhibitors are CDER small molecules but their mechanism is **renal
glucose-reabsorption blockade at a membrane transporter** — a *classical*
target-class engagement that none of the NEW modality axes were designed
to cover. They are NOT PROTACs, NOT molecular glues, NOT covalent
inhibitors, NOT metallodrugs, NOT macrocycles, NOT MWC-allosteric, NOT
RNA-targeting. They simply do not slot into any of the new-modality
axis invariants.

### 3.3 The honest call

The honest call is: **CDER-in-scope, no axis mapping, no sim run**.

The schema records each SGLT2 inhibitor in
`cder_in_scope_no_axis_mapping[]` with:

- `fda_center: "CDER"` — the FDA scope discipline IS satisfied;
- `axis: null` — no code axis to map onto;
- `in_scope_by_cder_discipline: true` — the criterion #4 drug-only/CDER
  gate passes;
- `no_axis_mapping: true` — but no expansion-layer axis fits;
- `reported_not_run: true` — no sim is invoked for the row;
- an explicit `reason` string spelling out why none of the new modality
  axes fit (transporter inhibition mechanism, not new-modality
  chemistry).

### 3.4 Why this is a NEW category, distinct from CBER UNPLACED

The SMA portfolio's UNPLACED category (Zolgensma) is for drugs that fail
criterion #4 itself — **CBER biologics**. They are out of the drug-only
discipline.

This new `cder_in_scope_no_axis_mapping` category is for drugs that
**pass** criterion #4 (CDER small molecule, drug-only) but for which the
axis tree itself has no fit — the new modality axes were designed for
new modality chemistries, and the SGLT2 inhibitor mechanism is the
classical transporter-inhibitor case that no new axis was designed for.

Structurally:

| Category | `fda_center` | `axis` | criterion #4 | gap nature |
|---|---|---|---|---|
| `in_scope_drugs` | CDER | non-null | PASS | axis maps, sim runs |
| `cder_in_scope_no_axis_mapping` | CDER | null | PASS | axis-tree gap (no new-modality fit) — NEW |
| `not_in_scope_drugs` | CBER / CDRH | null | FAIL | scope-discipline gap (already SMA precedent) |

### 3.5 Why this is HONEST GAP recognition, not an axis-tree bug

The axis tree was designed bottom-up from the new modality chemistries
that needed their own invariants (PROTAC ternary geometry, COVALENT
warhead reactivity, MACROCYCLE peptide stapling, etc.). Classical
target-class mechanisms (transporter inhibitors, channel blockers,
classical enzyme inhibitors) do not need a new axis — they are well-
studied by classical pharmacology and do not introduce new modality
invariants. Listing every classical-pharmacology mechanism as its own
axis would dilute the axis tree without adding modeling content. **The
honest call is to acknowledge the gap, not paper over it.**

This is the same honesty principle the SMA portfolio applied to
Zolgensma — but here the gap is INSIDE the criterion #4 boundary
(CDER pass + axis-mapping fail) rather than OUTSIDE (CDER fail).

### 3.6 Drug precedent for the SGLT2 inhibitors (own modality only — g3 / f1)

- dapagliflozin — Meng *et al.* 2008, *J. Med. Chem.* 51:1145-1149
  (C-aryl glucoside SGLT2 inhibitor discovery). FDA approval 2014.
- empagliflozin — Grempler *et al.* 2012, *Diabetes Obes. Metab.*
  14:83-90 (BI 10773 SGLT2 inhibitor characterization). FDA approval
  2014. EMPA-REG OUTCOME cardiovascular outcomes (Zinman *et al.* 2015,
  *N. Engl. J. Med.* 373:2117-2128) cited only as the trial precedent
  for the modality, not as a hexa-bio efficacy claim.
- canagliflozin — Nomura *et al.* 2010, *J. Med. Chem.* 53:6355-6360
  (canagliflozin discovery as the first FDA-approved SGLT2 inhibitor in
  the US). FDA approval 2013.

## §4 UNPLACED handling — insulin analogs (CBER biologic)

Recombinant insulin analogs (Humalog/lispro 1996, Lantus/glargine 2000,
NovoLog/aspart 2000, Levemir/detemir 2005, Tresiba/degludec 2015,
Fiasp/aspart 2017, etc.) are CBER-regulated **protein biologics**. They
fall outside the hexa-bio drug-only/CDER criterion #4 scope boundary —
the same way Zolgensma falls outside in the SMA portfolio, and the same
way GENETIC-MEDICINE / ADC / THERANOSTIC are left UNPLACED in
`AXIS/HIERARCHY.tape`.

This case study applies the SAME pattern:

- the witness records insulin analogs in `not_in_scope_drugs[]` with
  `axis: null`, `in_scope: false`, `fda_center: "CBER"`,
  `reported_not_run: true`, and an explicit `reason` string;
- the schema separates `not_in_scope_drugs` from
  `cder_in_scope_no_axis_mapping` so the two distinct honesty gaps are
  STRUCTURALLY DISTINCT, not merged into one bucket;
- the row points back to `@N genetic_medicine_status` / the SMA portfolio
  via `unplaced_precedent_in_repo` so a reader can follow the trail.

### 4.1 Drug precedent for insulin analogs (own modality only — g3 / f1)

- Hirsch IB 2005, *N. Engl. J. Med.* 352:174-183 — insulin analog
  pharmacology review.
- FDA STN BL approvals — Humalog/lispro (BL 020563, 1996, CBER);
  Lantus/glargine (BL 021081, 2000, CBER); Tresiba/degludec (BL 203314,
  2015, CBER).

## §5 Cross-axis touch-point — G4 (PEPTIDE × MACROCYCLE)

The peptide-chemistry side of the GLP-1 class touches the existing G4
cross — PEPTIDE × MACROCYCLE — which covers stapled / macrocyclic
peptide chemistry (engineered helicity, protease resistance). The
witness emits a `cross_axis_touch_point` block pointing at G4 by
`bridge_id`, source axis (`PEPTIDE` :> `WEAVE` core), and a sister axis
(`MACROCYCLE`). The relationship is **strict observation**: this case
study NOTES the G4 touch-point on the peptide-chemistry side without
re-running it. G4 stays the canonical PEPTIDE × MACROCYCLE bridge.

## §6 Governance

The case study sits inside the standard hexa-bio governance stack:

- **g1 real-limits-first.** Each in-scope row carries `peptide_sim`'s
  real-limit anchor forward into the witness: Zimm-Bragg helix-coil
  theory (Zimm & Bragg 1959; Lifson & Roig 1961). Helix propensities
  from Pace & Scholtz 1998 / Chakrabartty, Kortemme & Baldwin 1994.
- **g3 honesty-external / f1 lattice-fit-on-external-entity.** All drugs
  are described **only** via their own published precedent (semaglutide,
  tirzepatide, dapagliflozin, empagliflozin, canagliflozin, insulin
  analogs). Nothing here is lattice-derived (`f_lattice_fit`). No
  "n=6 → 6 drugs" or similar derivation. CDER/CBER center designations
  use the FDA's own invariants, not lattice fits.
- **g8 in-silico-only / f2 wet-lab-clinical-claim-from-in-silico.**
  Every PASS certifies in-silico simulator+metadata internal consistency
  only. This case study makes **no** therapeutic, glycemic, weight-loss,
  cardiovascular, immunogenic, regulatory, or **portfolio-recommendation**
  claim.
- **f3 shadow-implementation-of-sister-repo.** The runner IMPORTS
  `peptide_sim` via `importlib`; it does not re-implement the Zimm-Bragg
  partition.
- **criterion #4 drug-only/CDER scope discipline.** Honored — insulin
  analogs are left UNPLACED (CBER), per the SMA-portfolio /
  `@N genetic_medicine_status` precedent.
- **NEW honest category.** `cder_in_scope_no_axis_mapping[]` is
  introduced for FDA-approved CDER small molecules whose mechanism the
  new-modality axes were never designed to cover (SGLT2 inhibitors).
  This is HONEST GAP RECOGNITION — the axes were built for new
  modalities; classical transporter inhibition does not need a new axis.

### 6.1 What this case study is NOT

- NOT a portfolio recommendation, ranking, or investment thesis.
- NOT a claim that any one modality is superior. All listed in-scope
  drugs are FDA-approved.
- NOT a clinical, regulatory, glycemic-control, weight-loss,
  cardiovascular-outcomes, immunogenicity, dosing, or efficacy claim.
- NOT a derivation of the modality count from the n=6 lattice.
- NOT the deferred 200-disease portfolio re-mapping; this is the
  one-disease T2DM pilot only.
- NOT exhaustive — metformin, sulfonylureas, DPP-4 inhibitors,
  thiazolidinediones, meglitinides, α-glucosidase inhibitors, and
  amylin-analog peptides are intentionally excluded to keep the
  portfolio focused on the three category transitions (IN-SCOPE peptides,
  the NEW CDER-no-axis-mapping demonstration, CBER UNPLACED). The
  excluded classes are not denied — they are simply outside this pilot.

## §7 Files

- `README.md` — this writeup.
- `type2_diabetes_portfolio_runner.py` — deterministic stdlib-only
  runner; imports `peptide_sim` via `importlib`; emits the portfolio
  witness JSON; prints the `__TYPE2_DIABETES_PORTFOLIO__ PASS` sentinel
  on success.
- `portfolio_v1.schema.json` — draft-07 JSON Schema for the witness;
  three separated arrays — `in_scope_drugs` (2 peptide entries,
  `fda_center=CDER`, `in_scope=true`), `cder_in_scope_no_axis_mapping`
  (3 SGLT2-inhibitor entries, `fda_center=CDER`, `axis=null`,
  `cder_in_scope_but_no_axis_mapping: const true`, `no_axis_mapping=true`),
  and `not_in_scope_drugs` (≥1 CBER insulin-analog entry, `axis=null`,
  `in_scope=false`).

Run the runner directly:

```bash
python3 case_studies/type2_diabetes_portfolio/type2_diabetes_portfolio_runner.py
```

Expected: exit 0, last line `__TYPE2_DIABETES_PORTFOLIO__ PASS`. The
witness JSON is emitted on stdout (`sort_keys=True`, `indent=2`) and is
byte-identical on every run.
