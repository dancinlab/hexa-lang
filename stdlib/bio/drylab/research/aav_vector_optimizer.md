# AAV Vector-Design Optimizer — Algorithm Spec (CITED, stdlib-only)

> **drylab simulator #3** · in-silico software research · sequence-level budget
> optimizer. **NOT wet-lab, NOT clinical, NOT an expression/transduction
> predictor.** Honesty governance: g3 (no fabricated numbers / no lattice-fit on
> external entities), g8 / f2 (no therapeutic / efficacy claims from in-silico).
>
> **Motivation.** hexa-bio LVAD scenario ③ has (planned)
> `_python_bridge/module/aav_cargo_capacity_check.py` which only **judges**
> whether a cargo fits the AAV9 ssDNA wall. There is no **optimizer** that
> *maximizes* payload headroom (codon-optimization + minimal-promoter selection
> + ITR/polyA accounting) within a fixed budget. This spec defines that
> optimizer at the **sequence-budget level only**.

---

## §SOTA-landscape

Honest one-liners (g3 — these are third-party tools; described by their *own*
stated function, no lattice-fit, no efficacy endorsement):

**Proprietary / commercial:**
- **Benchling** — cloud molecular-biology suite; includes a codon-optimization
  tool and plasmid/sequence editor (organism codon tables, constraint avoidance).
  Proprietary; algorithm internals not fully published.
- **Geneious (Geneious Prime)** — desktop molecular workbench with a
  codon-optimization plugin and cloning tools; closed-source heuristics.
- **SnapGene** — sequence/cloning editor with feature annotation; not primarily
  an optimization engine (cassette assembly + visualization focus).
- **Dyno Therapeutics** — ML-driven *capsid* engineering (CapsidMap); optimizes
  the AAV **capsid protein**, an orthogonal axis to the **cargo-budget**
  problem this spec addresses. Proprietary.
- **Form Bio** — gene-therapy informatics platform incl. construct design /
  manufacturability analytics; proprietary.

**Open / open-source primitives (reusable building blocks, not whole optimizers):**
- **ViennaRNA (RNAfold)** — secondary-structure / MFE prediction; relevant if a
  future version scores 5′-UTR / cassette folding. Out of scope for the
  sequence-budget core.
- **CAI / codon-bias tools** — e.g. the `seqinr` R package `cai()` function and
  EMBOSS `cai` implement the Sharp & Li 1987 index (see §Reverse-engineered).
- **Public codon-usage tables** — Kazusa Codon Usage Database and HIVE-CUT /
  CoCoPUTs (see §codon-table-sourcing-note).

> No tool above is wrapped or reimplemented by this spec — only the *published
> algorithms* below are reverse-engineered into a stdlib implementation.

---

## §Reverse-engineered-algorithms (cited formulae)

### A. Codon Adaptation Index — Sharp & Li 1987

**Primary citation.** Sharp PM, Li WH. *The codon adaptation index — a measure
of directional synonymous codon usage bias, and its potential applications.*
Nucleic Acids Research 1987;15(3):1281–1295. PMID 3547335. (Confirmed via
PubMed / Oxford Academic / PMC PMC340524.)

**Relative adaptiveness.** For codon `i` encoding a given amino acid, with
synonymous-codon set `S(aa)`:

```
w_i = f_i / max_{ j ∈ S(aa) } f_j
```

where `f_i` is the observed frequency (or count) of codon `i` in the
**reference set of highly expressed genes** (Sharp & Li used a reference set of
highly expressed genes from the species). `w_i ∈ (0, 1]`; the most-used
synonymous codon has `w = 1`.

**CAI as geometric mean (the form this spec implements).** For a gene of `L`
counted codons:

```
CAI = ( Π_{k=1}^{L} w_k )^(1/L)
```

equivalently, the numerically stable log form actually implemented:

```
CAI = exp[ (1/L) · Σ_{k=1}^{L} ln w_k ]
```

(verbatim formula confirmed on Wikipedia/Codon_Adaptation_Index and
`seqinr::cai` docs, both attributing to Sharp & Li 1987.)

**Exclusions (per the standard `seqinr`/EMBOSS definition).** Single-codon
amino acids — **Met (AUG)** and **Trp (UGG)** — and **stop codons** are
excluded from `L` (they carry no synonymous-bias information; `w` would be
trivially 1 / undefined). To avoid `ln 0`, codons whose relative adaptiveness
is `< 1e-4` are floored to `0.01` (the standard `seqinr` convention).

### B. Codon-optimization strategies

**Primary review.** Mauro VP, Chappell SA. *A critical analysis of codon
optimization in human therapeutics.* Trends in Molecular Medicine
2014;20(11):604–613. (Confirmed via search; review of the three strategies.)

Three published strategies (this spec implements **(ii) CAI-targeted**,
deterministically):

1. **Most-frequent-codon** — replace every codon with the single most frequent
   synonymous codon in the host. Simple; can over-bias and deplete tRNA pools.
2. **CAI-targeted / frequency-matching** — choose synonymous codons so the
   gene's codon distribution matches (or maximizes proximity to) the host
   highly-expressed reference. Deterministic variant: pick `argmax w_i` per
   amino acid (this collapses to (1) for the argmax rule, so the spec records
   the chosen rule explicitly — see §stdlib-implementation-spec).
3. **Codon harmonization** — preserve the *native* host's rare/common rhythm
   (translational pauses for folding) when porting to a new host.

> The optimizer's **objective is sequence length / budget headroom**, not
> expression. CAI is used only to make the synonymous-codon choice
> *deterministic and literature-anchored*; it does **not** change CDS length
> (synonymous substitution is length-invariant), so codon optimization in this
> tool affects **only** the optionally-attached intron/UTR-free recoding
> compatibility, never the amino-acid sequence and never the codon count.

### C. Minimal cardiac promoters (length budget)

Sizes below are **as stated in the cited literature** (g3 — not invented;
sources noted). Relevant because promoter choice is the single largest tunable
budget line after the CDS.

| Promoter | Stated length | Source |
|---|---|---|
| chicken cTnT (truncated, −375..+43) | ~418 bp | Transcriptional Targeting review, Pathogens 2023;12(11):1301 (MDPI / PMC10675517) |
| human cTnT element (AAV9 Cre) | ~544 bp | same review |
| cTnT + CS-CRM4 hybrid | ~637 bp | same review |
| MHCK7 cassette | ~770 bp (565 bp core MCK + 50 bp exon + 188 bp αMHC enhancer) | same review |
| CK8 (MHCK7-derived, 2×206 bp MCK enh.) | ~837–980 bp | same review |
| CMV (full immediate-early promoter) | ~750–800 bp | Powell, Rivera-Soto & Gray, Discovery Medicine 2015;19(102):49–57 (PMID 25636961) |

> **Unverified (honest):** a precise "minimal CMV" (e.g. ~200 bp minimal/core
> CMV) length was **not** confirmed from a primary source during this research.
> The spec therefore lists full CMV (~750–800 bp, Powell 2015) and does **not**
> hard-code a minimal-CMV figure. The element table is **data-driven** (loaded
> from a sourced file), so a curator may add minimal CMV later **with a
> citation** — the optimizer must not fabricate it.

### D. AAV cassette element sizing

**Primary review for polyA / WPRE / packaging budget.** Powell SK,
Rivera-Soto R, Gray SJ. *Viral Expression Cassette Elements to Enhance
Transgene Target Specificity and Expression in Gene Therapy.* Discovery
Medicine 2015;19(102):49–57. PMID 25636961. (Sizes quoted verbatim from
PMC4505817.)

| Element | Stated length | Source |
|---|---|---|
| ITR (each, ×2) | 145 bp | Wu/Yang/Colosi 2010 + Addgene viral-vectors-101 (145 b each, two per genome) |
| SV40 late polyA | 135 bp | Powell 2015 |
| bGH polyA | ~250 bp | Powell 2015 |
| SPA synthetic polyA | 49 bp | Powell 2015 |
| WPRE (full) | 600 bp | Powell 2015 |
| WPRE3 / shortened | 247 bp | Powell 2015 |
| Kozak consensus | 10 nt motif `GCCRCCATGG` (functional region −9..−1 + AUG) | Kozak M, Nucleic Acids Res 1987 (699 vertebrate mRNAs) |

> Kozak contributes a negligible ~6–10 bp; included for completeness. The
> task brief's "polyA SV40 ~135 / bGH ~225 / synthetic ~50" — the primary
> source (Powell 2015) gives **SV40 135 bp, bGH ~250 bp, SPA 49 bp**. The
> spec uses the **sourced** numbers (bGH ~250, not 225) and records this
> discrepancy honestly rather than silently using the brief's figure.

### E. Dual-AAV / oversized-cargo split strategies

**Primary citation.** Trapani I, Colella P, Sommella A, *et al.* (Auricchio
lab). *Effective delivery of large genes to the retina by dual AAV vectors.*
EMBO Molecular Medicine 2014;6(2):194–211. PMID 24150896. DOI
10.1002/emmm.201302948.

Three published dual-AAV reconstitution strategies (the optimizer only needs
to **flag** which applies when cargo > cap; it does not simulate
recombination):

1. **Trans-splicing (TS)** — vector A: promoter + 5′-half + splice donor;
   vector B: splice acceptor + 3′-half + polyA. mRNA reconstituted via ITR
   head-to-tail concatemerization + splicing.
2. **Overlapping (OV)** — A and B share a homologous overlap region;
   reconstitution by homologous recombination.
3. **Hybrid (AK / hybrid)** — TS + an added recombinogenic region (e.g. AK
   from alkaline phosphatase / F1 phage) to boost concatemerization.

Per the review, **TS and hybrid were the most efficient in vivo** (qualitative
literature statement, reported as cited context — **not** an efficacy claim by
this tool).

---

## §stdlib-implementation-spec

**Module (planned):** `_python_bridge/module/aav_vector_optimizer.py`
(Python standard library only — `math`, `json`, `argparse`, `sys`; **no**
numpy / Biopython / external network).

### Inputs

```
--cds            FASTA / raw nucleotide CDS (in-frame, ATG..stop) OR
--protein        one-letter amino-acid sequence (back-translate via codon table)
--codon-table    path to JSON codon-usage table (REQUIRED — see §codon-table-sourcing-note)
--elements       path to JSON element-size table (sourced; defaults shipped read-only with citations)
--promoter       key into element table (e.g. "cTnT_chicken", "MHCK7", "CK8")
--polyA          key (e.g. "SV40", "bGH", "SPA")
--wpre           "none" | "WPRE" | "WPRE3"
--cap            integer, default 4650   (effective ssDNA payload, see §real-limit-anchor)
--codon-rule     "argmax_w" (default, deterministic CAI-maximizing) | "report_only"
```

### Objective

```
headroom = cap − Σ elements
Σ elements = 2·len(ITR) + len(promoter) + len(Kozak) + len(CDS_opt)
             + len(WPRE?) + len(polyA)
maximize headroom  s.t.  optimized CDS preserves the input amino-acid sequence exactly
```

Because synonymous codon substitution is **length-invariant** (3 nt/codon
always), `len(CDS_opt) == len(CDS_in)`. The optimizer therefore maximizes
headroom by **element selection** (smallest adequate promoter/polyA/WPRE from
the sourced table per user-allowed candidate set), and reports the
**CAI of the recoded CDS** as a deterministic quality annotation — *not* as an
expression prediction.

### Algorithm (deterministic)

1. **Parse & validate** CDS: length divisible by 3, single in-frame stop,
   starts with ATG. Translate to amino acids (standard genetic code, embedded
   constant — the genetic code is canonical, not a "frequency" — safe to
   embed).
2. **Load codon-usage table** from `--codon-table` JSON (per-codon counts or
   per-thousand frequencies). **Fail loudly** if absent — the tool must
   **never** fall back to a fabricated table (g3).
3. **Compute relative adaptiveness** `w_i = f_i / max_{S(aa)} f_j` for every
   codon; floor `< 1e-4 → 0.01`; exclude Met/Trp/stop from `L`.
4. **Recode CDS** per `--codon-rule`:
   - `argmax_w`: replace each codon with `argmax_{S(aa)} w` (CAI-maximizing,
     deterministic; ties broken by lexicographic codon order for
     reproducibility).
   - `report_only`: leave CDS as-is, only score.
5. **Compute CAI** of the (recoded) CDS via the log-form geometric mean (§A).
6. **Element accounting**: sum the sourced element lengths for the chosen
   promoter / polyA / WPRE / 2×ITR / Kozak.
7. **Headroom & flag**:
   - `headroom = cap − Σ` ; `fits = headroom ≥ 0`.
   - If `not fits`: set `dual_aav_required = true`, emit the three published
     split options (TS / OV / hybrid; §E) as **informational candidates**
     (with the Trapani 2014 citation), and compute the *minimum* split point
     (≈ midpoint of CDS, ITR/splice overhead added per arm) — **structural
     suggestion only, not a recombination simulation**.
8. **Determinism / witness**: same inputs → byte-identical output; emit a
   witness JSON row (inputs hash, element table source id, codon-table source
   id, CAI, headroom, fits, dual flag).

### Output (machine-readable + cassette map)

```json
{
  "cassette_map": [
    {"element": "ITR_5",    "len": 145},
    {"element": "promoter", "key": "cTnT_chicken", "len": 418, "source": "MDPI 2023;12:1301"},
    {"element": "Kozak",    "len": 10},
    {"element": "CDS_opt",  "len": 3201, "cai": 0.7421, "codon_rule": "argmax_w"},
    {"element": "WPRE3",    "len": 247, "source": "Powell 2015"},
    {"element": "polyA",    "key": "SPA", "len": 49,  "source": "Powell 2015"},
    {"element": "ITR_3",    "len": 145}
  ],
  "sum_bp": 4215,
  "cap_bp": 4650,
  "headroom_bp": 435,
  "fits": true,
  "dual_aav_required": false,
  "cai_recoded": 0.7421,
  "codon_table_source": "Kazusa Homo sapiens (curator-supplied) — see sourcing note",
  "honesty": "sequence-level budget optimizer; NOT expression/transduction prediction"
}
```

---

## §codon-table-sourcing-note

**The optimizer must NOT embed fabricated codon frequencies (g3).** The codon
table is a **required external input** sourced by the curator/foreground from
an authoritative public database:

- **Kazusa Codon Usage Database** — *Homo sapiens* `[gbpri]`, taxid 9606.
  Primary citation: Nakamura Y, Gojobori T, Ikemura T. *Codon usage tabulated
  from international DNA sequence databases: status for the year 2000.* Nucleic
  Acids Research 2000;28(1):292. URL `http://www.kazusa.or.jp/codon/`
  (`showcodon.cgi?species=9606`). Note: Kazusa is GenBank-derived and can be
  redundant for some genes.
- **HIVE-CUT / CoCoPUTs** — a newer, RefSeq-curated alternative
  (Athey *et al.*, BMC Bioinformatics 2017;18:391). Recommended when
  reduced redundancy matters; curator selects and records which table was used.

**Procedure for the agent/foreground (do NOT auto-fabricate):**
1. Download the human codon-usage table from Kazusa (or HIVE-CUT/CoCoPUTs).
2. Convert to the optimizer's JSON schema
   (`{ "TTT": {"aa":"F","count":N}, ... }`).
3. Record the **source URL + access date + database version** in the JSON
   header and in the witness row.
4. The optimizer reads this file and **fails closed** if it is missing or
   schema-invalid — it never substitutes invented numbers.

The canonical **genetic code** (codon→amino-acid mapping) *is* embeddable: it
is a fixed biological constant, not a frequency statistic.

---

## §real-limit-anchor

The optimizer's ceiling is set by a **real molecular-biology limit**, never by
the n=6 lattice (g1 / g2):

- **AAV ssDNA packaging limit ≈ 4.7 kb.** Primary: Wu Z, Yang H, Colosi P.
  *Effect of Genome Size on AAV Vector Packaging.* Molecular Therapy
  2010;18(1):80–86. DOI 10.1038/mt.2009.255. (Packaged genomes never exceeded
  ~5.0–5.2 kb; vectors >5 kb were heterogeneous and 5′-truncated.)
- **Confirming review.** Wang D, Tai PWL, Gao G. *Adeno-associated virus
  vector as a platform for gene therapy delivery.* Nature Reviews Drug
  Discovery 2019;18:358–378. (~4.7 kb genome.)
- **ITR overhead.** Two 145 bp ITRs are mandatory for replication/packaging
  (Wu 2010; Addgene viral-vectors-101), leaving the *effective* payload.

**Default cap = 4650 bp** = a conservative effective payload below the ~4.7 kb
wall after accounting for the two 145 bp ITRs and packaging-efficiency
margin (literature treats ≤4.7 kb as the safe regime; ≥5 kb degrades).
`--cap` is user-overridable but the default is **anchored to the cited
Wu 2010 / Wang 2019 wall**, not to any lattice number.

---

## §honesty-caveat

- **Scope (g8 / f2).** This is a **sequence-level budget optimizer**. It
  computes element lengths, headroom, a deterministic CAI annotation, and a
  dual-AAV flag. It does **NOT** predict expression level, transduction
  efficiency, immunogenicity, tropism, splicing fidelity, protein folding, or
  any therapeutic / clinical / regulatory outcome. CAI is reported as a
  literature-anchored codon-bias *statistic*, **not** an efficacy proxy
  (Mauro & Chappell 2014 explicitly caution against equating codon
  optimization with improved therapeutic outcome).
- **In-silico only.** All AAV axes in hexa-bio are scientifically UNPROVEN at
  the wet-lab boundary (CLOSURE_RESIDUAL_BACKLOG §0). A "fits / headroom > 0"
  result means *only* that the chosen sequence elements sum below the cited
  packaging cap — it is **not** a claim that the vector works.
- **No fabricated data (g3).** Codon frequencies are never invented — the
  table is a required, sourced external input. Element sizes are quoted from
  cited primary literature; the one figure that could not be primary-sourced
  (minimal-CMV length) is **explicitly omitted**, not guessed.
- **No lattice-fit (g1 / g2 / f1).** No element size, cap, or score is derived
  from the n=6 lattice. The cap is anchored to the Wu 2010 / Wang 2019
  biological packaging limit.
- **External entities (g3 / f1).** SOTA tools are described by their own
  stated function only; no lattice-fit, no efficacy endorsement.

---

## §references

All verified during this research via WebSearch / WebFetch against primary
sources. Unverifiable items were dropped (no fabrication).

1. **Sharp PM, Li WH.** The codon adaptation index — a measure of directional
   synonymous codon usage bias, and its potential applications. *Nucleic Acids
   Research* 1987;15(3):1281–1295. PMID 3547335.
   PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC340524/
2. **Wu Z, Yang H, Colosi P.** Effect of Genome Size on AAV Vector Packaging.
   *Molecular Therapy* 2010;18(1):80–86. DOI 10.1038/mt.2009.255.
   PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC2839202/
3. **Wang D, Tai PWL, Gao G.** Adeno-associated virus vector as a platform for
   gene therapy delivery. *Nature Reviews Drug Discovery* 2019;18:358–378.
   (Cited for the ~4.7 kb genome confirming statement.)
4. **Mauro VP, Chappell SA.** A critical analysis of codon optimization in
   human therapeutics. *Trends in Molecular Medicine* 2014;20(11):604–613.
5. **Powell SK, Rivera-Soto R, Gray SJ.** Viral Expression Cassette Elements
   to Enhance Transgene Target Specificity and Expression in Gene Therapy.
   *Discovery Medicine* 2015;19(102):49–57. PMID 25636961.
   PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC4505817/
6. **Trapani I, Colella P, Sommella A, et al.** Effective delivery of large
   genes to the retina by dual AAV vectors. *EMBO Molecular Medicine*
   2014;6(2):194–211. PMID 24150896. DOI 10.1002/emmm.201302948.
   PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC3927955/
7. **Kozak M.** An analysis of 5′-noncoding sequences from 699 vertebrate
   messenger RNAs. *Nucleic Acids Research* 1987. (Kozak consensus
   `GCCRCCATGG`.)
8. **Nakamura Y, Gojobori T, Ikemura T.** Codon usage tabulated from
   international DNA sequence databases: status for the year 2000. *Nucleic
   Acids Research* 2000;28(1):292. Kazusa Codon Usage Database,
   http://www.kazusa.or.jp/codon/
9. **Athey J, Alexaki A, Osipova E, et al.** A new and updated resource for
   codon usage tables (HIVE-CUT / CoCoPUTs). *BMC Bioinformatics*
   2017;18:391.
10. Transcriptional Targeting Approaches in Cardiac Gene Transfer Using AAV
    Vectors. *Pathogens* 2023;12(11):1301 (MDPI; PMC10675517) — cardiac
    minimal-promoter lengths (cTnT, MHCK7, CK8).
11. Addgene — *Viral Vectors 101: Parts of the AAV Transfer Plasmid* /
    *Four Ways to Package Transgenes That Exceed the Size Limit of AAV*
    (ITR 145 b ×2; dual-AAV overview — corroborating, not primary).
12. `seqinr` R package `cai()` documentation; EMBOSS `cai` — corroborating
    the standard computational CAI definition and Met/Trp/stop exclusion +
    1e-4→0.01 flooring convention (both attribute to ref. 1).

> Dropped (could not primary-source a usable number): a specific
> "minimal CMV" promoter length — omitted rather than guessed (g3).
