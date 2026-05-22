# ML-Capsid-Fitness — Independent Transparent Proxy Scorer Spec (CITED, stdlib-only)

> **drylab simulator (research-spec only this wave)** · in-silico software
> research · a **deterministic, transparent, public-proxy** scorer for a
> candidate AAV capsid variant. **NOT wet-lab, NOT clinical, NOT a tropism /
> transduction / efficacy predictor, NOT a reproduction of any proprietary ML
> method.** Honesty governance: g3 (external entities by own claims, no
> lattice-fit, methods flagged undisclosed where undisclosed), g8 / f2 (no
> therapeutic / efficacy claim from in-silico), g1 (real-limit anchored).
>
> **Distinction from drylab #3 (`aav_vector_optimizer`).** #3 scores the
> **cargo/cassette budget** (codon-opt + element sizing under the ssDNA cap).
> This entry scores the **capsid protein variant itself** on
> publicly-documented structural/biochemical proxies — an orthogonal axis.
> No overlap; both stdlib-only.
>
> **Premise (the honesty crux).** A class of *proprietary* tools (Dyno
> CapsidMap, Form Bio, Affinia ART, Voyager TRACER) publicly state a
> **FUNCTION** (they output engineered AAV capsids with improved
> tropism/immune-evasion/manufacturability) but **do NOT disclose their ML
> model architecture or training data**. We are **not** cloning their method
> and explicitly do not pretend to. We build an **independent, fully
> transparent, stdlib heuristic** that scores a candidate variant on
> **open-science, citable** capsid-engineering proxies — explicitly labeled an
> *independent proxy*, not a reconstruction of any proprietary pipeline.

---

## §SOTA-landscape-undisclosed-method

Each tool below described **only by its own public claims** (g3). For each:
its stated **FUNCTION** (what it outputs) is given, and it is **explicitly
recorded that the underlying ML method / training data are proprietary and
undisclosed**. No lattice-fit, no efficacy endorsement, no inference about how
the method works.

| Tool | Publicly-stated FUNCTION (own claims) | Method status | Source |
|---|---|---|---|
| **Dyno Therapeutics — CapsidMap™** | "rapidly discover and systematically optimize superior AAV capsid vectors" with improved muscle targeting, immune evasion, packaging and manufacturing; builds "a comprehensive map of sequence space" from DNA-library synthesis + NGS measurement of in-vivo delivery. | **Undisclosed** — "advanced search algorithms leveraging machine learning and Dyno's massive quantities of experimental data"; model architecture and training data **not public**. | dynotx.com/platform |
| **Form Bio — FORMsightAI / FormManufacturing** | AI model that "optimizes designs and identifies codon substitutions", predicts manufacturability (full vs partial genome, truncation hotspots), construct design flaws, and immunogenicity potential. | **Undisclosed** — "proprietary FORMsightAI model"; architecture/training data **not public**. | formbio.com |
| **Affinia Therapeutics — ART platform** | "rationally designed" next-gen capsids/promoters; states cardiotropic capsids with increased cardiac-muscle mRNA expression and liver/DRG de-targeting vs AAV9. | **Partially disclosed in kind, not in detail** — states "rational design… based on structural modeling and mechanistic hypotheses" plus "AI and structural modeling"; the specific models/rules are **not public**. | affiniatx.com |
| **Voyager Therapeutics — TRACER™** | RNA-based in-vivo functional screening platform ("Tropism Redirection of AAV by Cell-type-specific Expression of RNA") that evolves AAV9-scaffold capsids with broad CNS/cardiac/skeletal tropism and liver/DRG de-targeting. | **Method is a wet-lab selection platform, not an ML model** — the selection technology is described; the resulting capsid sequences and any computational ranking are **proprietary/undisclosed**. | voyagertherapeutics.com/science-tracer |

> **Honest scoping note.** Voyager TRACER is an *experimental selection*
> platform (RNA-driven directed evolution), not primarily an ML predictor; it
> is included because the brief named it and because it shares the FUNCTION
> (engineered capsid output) — its *method category* is stated, its *outputs*
> (sequences) and any ranking are not public. Affinia's method *category*
> (rational/structural) is stated; the *rules/models* are not. For Dyno and
> Form Bio the ML method is entirely undisclosed. **No tool's internal method
> is reconstructed, guessed, or implemented anywhere in this spec.** Any tool
> whose FUNCTION was not publicly stated would be excluded — all four above do
> publicly state a function, so all four are retained with method flagged.

Other ML-AAV efforts exist in open literature (e.g. academic deep-learning
capsid-fitness models — Bryant et al. 2021 *Nat Biotechnol*; Ogden et al. 2019
*Science* AAV2 fitness landscape). These are **published methods**, not the
proprietary tools above; they are *not* implemented here either (this spec is
a transparent heuristic, deliberately **not** an ML reimplementation — see
§what-this-is-NOT).

---

## §publicly-documented-proxies-cited

The scorer uses **only open-science, primary-literature** proxies that any
researcher can read and verify. Each has one fetched citation. Anything that
could not be primary-sourced is dropped (no fabrication, g3).

### P1 — AAV9 VP3 reference structure & the ordered capsid frame

- **PDB 3UX1** — X-ray structure of the AAV9 capsid (VP3-overlap region),
  2.80 Å. Ordered residues ≈ **219–736 (VP1 numbering)**, all within the VP3
  sequence; conserved eight-stranded antiparallel β-barrel (βB–βI) + αA core,
  surface loops between strands.
  *DiMattia MA, Nam H-J, Van Vliet K, et al. Structural insight into the
  unique properties of adeno-associated virus serotype 9. **J Virol**
  2012;86(12):6947–6958. PMID 22496238. DOI 10.1128/JVI.07232-11.*
  (Verified via RCSB 3UX1 + PMC3393551.)
- Use in scorer: defines the **canonical residue frame** (VP1 numbering, VP3
  ordered window) the candidate variant is mapped onto, and the **9 variable
  regions VR-I..VR-IX** whose surface loops carry tropism/antigenic
  determinants.

### P2 — VR-VIII 7-mer peptide-display insertion site (the engineering site)

- The hypervariable region **VR-VIII** at the 3-fold protrusion, around
  **AAV9 position 588/589 (VP1 numbering)**, is the canonical site for
  inserting a randomized **7-amino-acid** peptide loop in AAV9-scaffold
  capsid engineering.
  *Chan KY, Jang MJ, Yoo BB, et al. Engineered AAVs for efficient noninvasive
  gene delivery to the central and peripheral nervous systems. **Nat Neurosci**
  2017;20:1172–1179. DOI 10.1038/nn.4593.* (CREATE: 7-aa domain inserted into
  AAV9 hypervariable region VIII; AAV-PHP.B carries the 7-mer **TLAVPFK**.)
- Use in scorer: the **7-mer-display-feasibility** check (peptide length == 7,
  insertion mapped at the documented VR-VIII 588/589 locus, flanking-frame
  preserved).

### P3 — Cardiotropic / myotropic engineered-capsid positive anchors

These are **published** engineered capsids (open literature) used purely as
documented positive-control *motif* anchors — NOT as a guarantee the scorer's
output will behave like them.

- **AAVMYO** — AAV9 + **7-mer peptide P1 = `RGDLGLS`** (contains an **RGD**
  integrin-binding motif) inserted in VR-VIII; stated function: "superior
  efficiency and specificity in the musculature including skeletal muscle,
  **heart** and diaphragm" with "pronounced detargeting from the liver".
  *Weinmann J, Weis S, Sippel J, et al. Identification of a myotropic AAV by
  massively parallel in vivo evaluation of barcoded capsid variants.
  **Nat Commun** 2020;11:5432. DOI 10.1038/s41467-020-19230-w. PMID 33116134.*
  (Verified via PMC7595228; peptide & function quoted verbatim.)
- **MyoAAV** — directed-evolution AAV9-scaffold family whose common feature is
  an **RGD** integrin-binding motif in a VR-VIII 7-mer insertion; stated
  function: enhanced muscle (incl. cardiac in the broader family) transduction
  with liver de-targeting, integrin-dependent.
  *Tabebordbar M, Lagerborg KA, Stanton A, et al. Directed evolution of a
  family of AAV capsid variants enabling potent muscle-directed gene delivery
  across species. **Cell** 2021;184(19):4919–4938.e22. PMID 34506722.
  DOI 10.1016/j.cell.2021.08.028.*
- **AAV-PHP.eB / AAV-PHP.B** — AAV9 + VR-VIII 7-mer (`TLAVPFK` for PHP.B);
  stated function: efficient CNS transduction after IV delivery (CNS anchor,
  used to document the *same insertion site* — not a cardiac claim).
  (Chan 2017, as P2.)
- Use in scorer: an **RGD-motif presence** flag in the 7-mer (documented
  common feature of the muscle/cardiac-tropic positive anchors AAVMYO &
  MyoAAV) — reported as a *documented-motif-match*, never as a tropism
  prediction.

### P4 — AAV2 heparan-sulfate (HS) binding basic-residue cluster

- AAV2 HS-proteoglycan attachment is governed by a cluster of basic residues;
  **R585 and R588** are primary (mutation of either abolishes heparin
  binding), with R484, R487, K527, K532 contributing.
  *Kern A, Schmidt K, Leder C, et al. Identification of a heparin-binding
  motif on adeno-associated virus type 2 capsids. **J Virol**
  2003;77(20):11072–11081. PMID 14512555;* and *Opie SR, Warrington KH,
  Agbandje-McKenna M, et al. Identification of amino acid residues in the
  capsid proteins of AAV2 that contribute to heparan sulfate proteoglycan
  binding. **J Virol** 2003;77(12):6995–7006. PMID 12768018.*
- Use in scorer: an **HS-binding-motif-presence** flag — does the candidate's
  mapped sequence retain a basic-residue cluster at the documented
  AAV2-equivalent positions. Reported as a documented surface-charge /
  glycan-attachment proxy, **not** a transduction prediction.

### P5 — AAV9 primary glycan receptor (terminal N-linked galactose pocket)

- AAV9's primary attachment receptor is **terminal galactose on N-linked
  glycans**; the galactose-binding pocket is formed by **N470, D271, N272,
  Y446, W503** at the base of the 3-fold protrusions.
  *Shen S, Bryant KD, Brown SM, et al. Terminal N-linked galactose is the
  primary receptor for adeno-associated virus 9. **J Biol Chem**
  2011;286(15):13532–13540. PMID 21330365;* galactose-binding-domain residues
  confirmed in *Bell CL, Gurda BL, Van Vliet K, et al. Identification of the
  galactose binding domain of the AAV9 capsid. **J Virol**
  2012;86(13):7326–7333. PMID 22514350.*
- Use in scorer: a **galactose-pocket-conservation** flag — are the five
  documented pocket residues retained at their canonical positions in the
  mapped variant. Reported as a documented receptor-footprint proxy only.

### P6 — Anti-AAV9 neutralizing-antibody (NAb) epitope footprint

- A dominant AAV9-specific neutralizing epitope maps to the **3-fold axis**:
  residues **496-NNN-498** and **588-QAQAQT-592** (PAV9.1, neutralizing
  titer >1:160,000); additional mAb contacts incl. **S454, P659**.
  *Giles AR, Govindasamy L, Somanathan S, Wilson JM. Mapping an AAV9-specific
  neutralizing epitope to develop next-generation gene delivery vectors.
  **J Virol** 2018;92(20):e01011-18. PMID 30068654;* extended in *Emmanuel SN,
  Mietzsch M, Tseng YS, et al. Structurally mapping antigenic epitopes of
  AAV9: development of antibody escape variants. **J Virol**
  2022;96(3):e01251-21. PMID 34757842.*
- Use in scorer: a **NAb-epitope-divergence** descriptor — how many of the
  documented epitope positions differ from wild-type AAV9 (a higher count is
  reported as *documented-epitope-divergence*, explicitly **not** an
  immune-evasion or clinical claim — f2/g8).

### P7 — AAV ssDNA packaging size ceiling (real-limit anchor; see §real-limit-anchor)

- Packaged AAV genomes do not reliably exceed ≈ **4.7 kb**.
  *Wu Z, Yang H, Colosi P. Effect of genome size on AAV vector packaging.
  **Mol Ther** 2010;18(1):80–86. DOI 10.1038/mt.2009.255;* confirmed
  *Wang D, Tai PWL, Gao G. AAV vector as a platform for gene therapy delivery.
  **Nat Rev Drug Discov** 2019;18:358–378.*
- Use in scorer: a hard **packaging-feasibility** gate on the *paired transgene
  budget* if the user supplies one (capsid engineering is moot if the cargo
  cannot be packaged). The capsid VP1 ORF itself is on the *rep/cap* plasmid,
  not the packaged genome — so this gate applies to the **user-supplied
  payload size**, defaulting to "not evaluated" when no payload is given.

> **Dropped (could not primary-source a single defensible number, g3):**
> a specific numeric "optimal capsid isoelectric point band" for cardiac
> tropism. The literature (e.g. AEM 2021 PMC7848896; *Sci Rep* 2023
> s41598-023-35547-0) establishes that **surface charge influences tropism &
> biodistribution and that AAV preps are pI-heterogeneous**, but does **not**
> publish a validated cardiac-optimal pI window. The scorer therefore treats
> net-charge only as a **relative, computed, documented-direction** descriptor
> (more basic surface ↔ stronger HS-type electrostatic attachment per P4) and
> **does not hard-code an invented pI target band** (g1: not-fitted).

---

## §function-level-stdlib-spec

**Module (planned, a LATER wave — this wave is the spec only):**
`drylab/sim/ml_capsid_fitness.py` (Python standard library only —
`math`, `json`, `argparse`, `sys`; **no** ML library, no numpy, no Biopython,
no network).

### What it is

A **deterministic, transparent, weighted heuristic** that maps a candidate
AAV9-scaffold capsid variant onto the cited public proxies (P1–P7) and emits a
per-proxy boolean/score plus an aggregate. It is a *documented-proxy
checklist*, **not** a learned model and **not** any proprietary pipeline.

### Inputs

```
--vp1            FASTA / raw protein sequence of the candidate VP1 (AAV9-scaffold)
--peptide        the inserted 7-mer (string) OR auto-extracted at VR-VIII locus
--insert-pos     VP1 position of the VR-VIII insertion (default 588, per P2)
--ref            "AAV9" (only supported scaffold; the cited proxy positions are
                 AAV9/AAV2-numbered — refuse other scaffolds rather than guess)
--payload-bp     OPTIONAL int; if given, run the P7 packaging gate on the cargo
--weights        OPTIONAL path to JSON heuristic-weight file (see weights note)
```

### Per-proxy feature functions (each cites its source in output)

1. **`hs_basic_cluster(seq)`** → bool. Are the AAV2-equivalent basic positions
   (R585/R588 primary + R484/R487/K527/K532) basic (R/K) in the mapped
   variant? Cite P4 (Kern 2003 / Opie 2003).
2. **`gal_pocket_conserved(seq)`** → bool. Are the 5 AAV9 galactose-pocket
   residues (N470, D271, N272, Y446, W503) retained at canonical positions?
   Cite P5 (Shen 2011 / Bell 2012).
3. **`seven_mer_display_ok(peptide, pos)`** → bool. `len(peptide)==7` AND
   `pos` within the documented VR-VIII window (587–590, default 588) AND the
   capsid frame (P1 ordered 219–736) intact. Cite P2 (Chan 2017).
4. **`rgd_motif_present(peptide)`** → bool. Does the 7-mer contain `RGD`
   (documented common feature of muscle/cardiac positive anchors AAVMYO,
   MyoAAV)? Cite P3 (Weinmann 2020 / Tabebordbar 2021).
5. **`nab_epitope_divergence(seq)`** → int (0..N). Count documented anti-AAV9
   epitope positions (496–498, 588–592, S454, P659) that differ from
   wild-type AAV9. Cite P6 (Giles 2018 / Emmanuel 2022). Reported as a
   descriptor, **not** an evasion claim.
6. **`net_charge_direction(seq)`** → float. Net charge from a **canonical
   constant** amino-acid charge set (Asp/Glu = −1, Lys/Arg = +1, His ≈ 0 at
   pH 7.4 — a fixed biochemical convention, not a fitted statistic), reported
   as a **relative direction only** (more positive ↔ stronger
   HS-type electrostatic attachment per P4). **No pI band hard-coded** (g1).
7. **`packaging_ok(payload_bp)`** → bool | "not_evaluated". `payload_bp ≤ cap`
   (default cap = 4700, anchored to P7 Wu 2010 / Wang 2019). Returns
   `"not_evaluated"` when no payload supplied.

### Aggregate (transparent weighted sum — heuristic, NOT validated)

```
fitness_proxy = Σ_i  w_i · f_i        (f_i ∈ {0,1} or normalized float)
```

with the **default documented heuristic weights** (order-of-magnitude,
**not fitted, not validated** — g1; each rationale recorded inline):

| Proxy | Default w | Rationale (documented, not fitted) |
|---|---|---|
| `seven_mer_display_ok` | 0.30 | structural feasibility is a **prerequisite** — if the display is malformed nothing else matters; weighted highest as a gate-like term |
| `hs_basic_cluster` | 0.15 | one well-documented attachment determinant (P4) |
| `gal_pocket_conserved` | 0.15 | AAV9's **primary** documented receptor footprint (P5) |
| `rgd_motif_present` | 0.15 | documented common feature of the cardiac/muscle positive anchors (P3) |
| `nab_epitope_divergence` | 0.15 | documented antigenic surface (P6); normalized 0..1 over the epitope-position count |
| `net_charge_direction` | 0.10 | weakest/most-indirect proxy → lowest weight; relative only |
| `packaging_ok` | hard gate | if a payload is given and exceeds the P7 cap, aggregate is flagged `packaging_fail` (not silently summed) |

> **Weights honesty (g1).** These weights are a **documented, transparent,
> order-of-magnitude heuristic**, explicitly **NOT** fitted to any dataset and
> **NOT** validated against any in-vivo outcome. They encode only the
> qualitative reasoning "structural feasibility > documented receptor
> footprints ≈ documented motif/antigenic features > indirect charge". They
> are overridable via `--weights`. The output **must** carry
> `"weights_status": "documented-heuristic-NOT-fitted-NOT-validated"`. The
> aggregate is a **transparent bookkeeping number over cited proxies**, never
> a learned fitness and never a tropism probability.

### Determinism / witness

Same inputs → byte-identical output. Emit a witness JSON row: input VP1 hash,
peptide, insert-pos, every per-proxy boolean/value **with its citation id**,
the weight vector + `weights_status`, the aggregate, and the honesty banner.

### Output (machine-readable)

```json
{
  "scaffold": "AAV9",
  "peptide": "RGDLGLS",
  "insert_pos": 588,
  "proxies": {
    "seven_mer_display_ok": {"value": true,  "cite": "P2 Chan 2017"},
    "hs_basic_cluster":     {"value": true,  "cite": "P4 Kern/Opie 2003"},
    "gal_pocket_conserved": {"value": true,  "cite": "P5 Shen2011/Bell2012"},
    "rgd_motif_present":    {"value": true,  "cite": "P3 Weinmann2020/Tabebordbar2021"},
    "nab_epitope_divergence": {"value": 0,   "cite": "P6 Giles2018/Emmanuel2022"},
    "net_charge_direction": {"value": 12.0,  "cite": "P4 (relative only)"},
    "packaging_ok":         {"value": "not_evaluated", "cite": "P7 Wu2010/Wang2019"}
  },
  "fitness_proxy": 0.85,
  "weights_status": "documented-heuristic-NOT-fitted-NOT-validated",
  "honesty": "independent transparent public-proxy score; NOT the proprietary ML; NOT a tropism/efficacy prediction"
}
```

---

## §what-this-is-NOT

This scorer is an **independent, transparent heuristic over publicly-documented
AAV capsid-engineering proxies**. It is explicitly **NOT** the following, and
must never be presented as such:

It is **not** a reproduction, reimplementation, approximation, or
reverse-engineering of any proprietary method — not Dyno CapsidMap, not Form
Bio FORMsightAI, not Affinia's ART platform, not Voyager TRACER. Those tools'
ML model architectures and training data are **undisclosed**, and this spec
neither reconstructs nor guesses them; it builds something deliberately
*different* (a small, fully-readable, cited checklist — no machine learning at
all). It is **not** a tropism predictor, a transduction-efficiency predictor,
a cardiac-targeting guarantee, an immune-evasion claim, an immunogenicity
predictor, a manufacturability predictor, or any in-vivo / clinical /
regulatory claim. A high `fitness_proxy` means **only** that the candidate
sequence matches more of the cited *documented* structural/biochemical proxies
— it carries **no** evidence that the variant will work in any cell, animal,
or patient. The positive anchors (AAVMYO, MyoAAV, AAV-PHP.eB) are used solely
as *documented-motif references*, not as a promise the scored variant will
behave like them. The heuristic weights are a documented order-of-magnitude
convenience, **not** fitted or validated against any data. All AAV axes in
hexa-bio are scientifically **UNPROVEN at the wet-lab boundary**
(CLOSURE_RESIDUAL_BACKLOG §0).

---

## §real-limit-anchor

The scorer is anchored to **real molecular-biology limits**, never the n=6
lattice (g1 / g2 / f1):

- **AAV ssDNA packaging ceiling ≈ 4.7 kb** (P7; Wu 2010 *Mol Ther*
  18(1):80–86, DOI 10.1038/mt.2009.255; confirmed Wang 2019 *Nat Rev Drug
  Discov* 18:358–378). The optional payload gate uses **cap = 4700 bp**,
  anchored to this cited wall — not to any lattice number.
- **AAV9 ordered-capsid frame: VP1 residues ≈ 219–736** (P1; DiMattia 2012
  *J Virol* 86(12):6947–6958, PDB 3UX1). Proxy residue positions are validated
  against this real crystallographic frame; out-of-frame inputs are rejected,
  not silently scored.
- **Documented receptor/epitope residues are *measured* positions** (P4–P6),
  taken verbatim from the cited mutagenesis / cryo-EM papers — the scorer
  never invents a binding residue.

No proxy, weight, threshold, or aggregate is derived from the n=6 lattice
(σ=12 · τ=4 · φ=2 · J₂=24). The fact that "6 variable regions are scored" or
similar would be a coincidence, never a derivation (f1).

---

## §honesty-caveat

- **External entities (g3 / f1).** Dyno, Form Bio, Affinia, Voyager are
  described by their **own public claims only**; their ML methods are
  **explicitly flagged undisclosed** where undisclosed; no lattice-fit, no
  efficacy endorsement, no inference of their internals.
- **No method fabrication (g3).** This spec implements **none** of the
  proprietary methods and does not pretend to. It implements a *different*,
  transparent, non-ML heuristic over independently-cited open science.
- **Scope (g8 / f2).** Output is a **documented-proxy bookkeeping score**, not
  a tropism / transduction / immunogenicity / manufacturability / therapeutic
  / clinical / regulatory claim. "High score" ≠ "works".
- **No fabricated data (g3).** Every proxy residue/position/motif is quoted
  from a fetched primary source; the one unfindable number (a validated
  cardiac-optimal pI band) is **explicitly dropped**, not guessed. Heuristic
  weights are labeled NOT-fitted / NOT-validated.
- **No lattice-fit (g1 / g2 / f1).** All anchors are real biology limits.
- **In-silico only.** All hexa-bio AAV axes are UNPROVEN at the wet-lab
  boundary (CLOSURE_RESIDUAL_BACKLOG §0).

---

## §references

All verified during this research via WebSearch / WebFetch against primary
sources (RCSB, PMC, journal pages). Unverifiable items dropped (no fabrication).

1. **DiMattia MA, Nam H-J, Van Vliet K, et al.** Structural insight into the
   unique properties of adeno-associated virus serotype 9. *J Virol*
   2012;86(12):6947–6958. PMID 22496238. DOI 10.1128/JVI.07232-11.
   PDB **3UX1** (RCSB). PMC: PMC3393551.
2. **Chan KY, Jang MJ, Yoo BB, et al.** Engineered AAVs for efficient
   noninvasive gene delivery to the central and peripheral nervous systems.
   *Nat Neurosci* 2017;20:1172–1179. DOI 10.1038/nn.4593.
3. **Weinmann J, Weis S, Sippel J, et al.** Identification of a myotropic AAV
   by massively parallel in vivo evaluation of barcoded capsid variants.
   *Nat Commun* 2020;11:5432. DOI 10.1038/s41467-020-19230-w. PMID 33116134.
   PMC: PMC7595228. (AAVMYO 7-mer P1 = `RGDLGLS`; "skeletal muscle, heart and
   diaphragm" + liver detargeting — quoted verbatim.)
4. **Tabebordbar M, Lagerborg KA, Stanton A, et al.** Directed evolution of a
   family of AAV capsid variants enabling potent muscle-directed gene delivery
   across species. *Cell* 2021;184(19):4919–4938.e22. PMID 34506722.
   DOI 10.1016/j.cell.2021.08.028. (MyoAAV; RGD integrin-binding motif in
   VR-VIII heptamer.)
5. **Kern A, Schmidt K, Leder C, et al.** Identification of a heparin-binding
   motif on adeno-associated virus type 2 capsids. *J Virol*
   2003;77(20):11072–11081. PMID 14512555.
6. **Opie SR, Warrington KH, Agbandje-McKenna M, et al.** Identification of
   amino acid residues in the capsid proteins of AAV2 that contribute to
   heparan sulfate proteoglycan binding. *J Virol* 2003;77(12):6995–7006.
   PMID 12768018. (R585/R588 primary; R484/R487/K527/K532 contributing.)
7. **Shen S, Bryant KD, Brown SM, et al.** Terminal N-linked galactose is the
   primary receptor for adeno-associated virus 9. *J Biol Chem*
   2011;286(15):13532–13540. PMID 21330365. PMC: PMC3075699.
8. **Bell CL, Gurda BL, Van Vliet K, et al.** Identification of the galactose
   binding domain of the AAV9 capsid. *J Virol* 2012;86(13):7326–7333.
   PMID 22514350. PMC: PMC3416318. (Pocket: N470, D271, N272, Y446, W503.)
9. **Giles AR, Govindasamy L, Somanathan S, Wilson JM.** Mapping an
   AAV9-specific neutralizing epitope to develop next-generation gene delivery
   vectors. *J Virol* 2018;92(20):e01011-18. PMID 30068654. PMC: PMC6158442.
   (Epitope 496-NNN-498 + 588-QAQAQT-592; PAV9.1 titer >1:160,000.)
10. **Emmanuel SN, Mietzsch M, Tseng YS, et al.** Structurally mapping
    antigenic epitopes of AAV9: development of antibody escape variants.
    *J Virol* 2022;96(3):e01251-21. PMID 34757842. PMC: PMC8827038.
    (Extended mAb contacts incl. S454, P659.)
11. **Wu Z, Yang H, Colosi P.** Effect of genome size on AAV vector packaging.
    *Mol Ther* 2010;18(1):80–86. DOI 10.1038/mt.2009.255. PMC: PMC2839202.
12. **Wang D, Tai PWL, Gao G.** Adeno-associated virus vector as a platform
    for gene therapy delivery. *Nat Rev Drug Discov* 2019;18:358–378.
    (Confirming ~4.7 kb packaging ceiling.)

**Proprietary-tool public pages (own-claims only, methods flagged undisclosed
— g3; not implemented anywhere):**
13. Dyno Therapeutics — CapsidMap™ platform page (dynotx.com/platform);
    BusinessWire 2020-05-11 emergence release. Method: undisclosed ML.
14. Form Bio — formbio.com (FORMsightAI / FormManufacturing). Method:
    proprietary AI model, undisclosed.
15. Affinia Therapeutics — affiniatx.com (ART platform; ASGCT 2023/2024/2025
    preclinical releases). Method: rational/structural + AI, rules not public.
16. Voyager Therapeutics — voyagertherapeutics.com/science-tracer (TRACER™
    RNA-driven in-vivo selection). Method category stated (wet-lab selection);
    output sequences/ranking proprietary.

> Dropped (could not primary-source a single defensible number, g3): a
> validated cardiac-optimal capsid isoelectric-point band — omitted, not
> guessed. Net charge is used as a relative computed direction only.
