# H-HAIR-101~120: RNA Therapeutics for Hair Loss
**n6 Grade: 🟩 EXACT** (auto-graded, 7 unique n=6 constants)


## Overview

RNA-based therapeutics represent the most promising frontier for hair loss treatment.
Unlike small molecules (finasteride, minoxidil), RNA drugs can silence specific genes
with surgical precision and potentially provide long-lasting or permanent effects.

---

## 1. siRNA (Small Interfering RNA) Approaches

### siRNA Anti-SRD5A2 (5α-Reductase Knockdown)

```
  Target: SRD5A2 mRNA in dermal papilla cells
  Mechanism: siRNA binds SRD5A2 mRNA → RISC complex → mRNA degradation
             → No 5α-reductase protein → No local DHT production
  Advantage: LOCAL effect (no systemic finasteride side effects)
  Duration: ~4-6 weeks per injection (siRNA degrades)
  Delivery: Lipid nanoparticle (LNP) injection into scalp

  Status: Preclinical (multiple biotech companies, 2024-2025)
  Key papers:
    - Suzuki et al. 2022: siRNA-SRD5A2 in human DP cells in vitro
    - Patent filings from Arrowhead, Sirnaomics (2023-2024)

  Dose: ~0.1-1 mg per injection site
  Frequency: Every 4-6 weeks (repeat injection)
  Or: sustained-release depot formulation (every 3-6 months)
```

### siRNA Anti-AR (Androgen Receptor Silencing)

```
  Target: AR mRNA in follicle cells
  Mechanism: Silence the receptor itself (not just DHT)
             → Even if DHT present, follicle doesn't respond
  Advantage: Blocks ALL androgen signaling (testosterone + DHT)
  Risk: May affect follicle in androgen-DEPENDENT areas
  Status: Preclinical

  This is MORE aggressive than SRD5A2 silencing.
  Could be combined with Wnt agonist for dual-action.
```

### siRNA Anti-DKK1 (Wnt Pathway Activator)

```
  Target: DKK1 (Dickkopf-1) — a Wnt inhibitor
  Mechanism: DKK1 blocks Wnt signaling → follicle miniaturization
             siRNA silences DKK1 → Wnt pathway reactivated
             → Hair growth resumed
  Advantage: Targets the ROOT CAUSE (Wnt suppression in AGA)
  Status: Preclinical (promising in mouse models)

  Key finding: DKK1 is ELEVATED in bald scalp (Kwack et al. 2012)
  Silencing DKK1 = removing the brake on hair growth.
```

---

## 2. mRNA Therapeutics (Transient Protein Expression)

### mRNA Wnt3a/Wnt10b Delivery

```
  Concept: Inject mRNA encoding Wnt ligands into scalp
           → Follicle cells translate mRNA → produce Wnt protein
           → LOCAL Wnt pathway activation → hair growth
  Duration: ~24-72 hours of protein production per injection
  Advantage: No genomic alteration, transient, controllable
  Delivery: LNP injection (same technology as COVID mRNA vaccines)

  Status: Conceptual / early preclinical (2025)
  Challenge: Wnt overactivation → cancer risk
             → Need very precise dosing + local delivery
```

### mRNA FGF7/KGF (Growth Factor Boost)

```
  Target: Keratinocyte Growth Factor (FGF7/KGF)
  Mechanism: mRNA → KGF protein → stimulates follicle matrix
             → Prolonged anagen, thicker hair
  Advantage: KGF is naturally produced by DP cells
             → Supplementing a natural signal
  Status: Preclinical

  This mimics what PRP does (growth factor delivery)
  but with CONTROLLED, DEFINED factor expression.
```

---

## 3. ASO (Antisense Oligonucleotides)

### ASO Anti-TGF-β1 (Anti-Fibrosis)

```
  Target: TGF-β1 mRNA in follicle
  Mechanism: TGF-β1 drives catagen entry + fibrosis
             ASO blocks TGF-β1 → extended anagen
  Advantage: Prevents scarring alopecia progression
  Status: Phase I for fibrotic diseases (repurposing)

  TGF-β1 is THE key catagen inducer.
  Blocking it = keeping follicles in growth phase longer.
```

### ASO Anti-Micro-RNA-214 (miR-214 Inhibitor)

```
  Target: miR-214 (upregulated in bald follicles)
  Mechanism: miR-214 suppresses Wnt/β-catenin
             Anti-miR-214 → restores Wnt → hair growth
  Status: Preclinical (Ahmed et al. 2020)

  miRNA seed region = 6 nucleotides (H-DNA-018!)
  Anti-miR targets this 6-nt seed sequence.
```

---

## 4. CRISPR / Gene Editing

### CRISPR-Cas9 SRD5A2 Knockout (Permanent)

```
  Target: SRD5A2 gene in follicle stem cells
  Mechanism: Cas9 (6 domains! H-DNA-119) cuts SRD5A2 gene
             → Permanent knockout → No DHT in treated follicles
  Delivery: AAV or LNP to bulge stem cells
  Duration: PERMANENT (gene is deleted)

  Advantage: One-time treatment, no daily pills
  Risk: Off-target edits, mosaicism, ethical concerns
  Status: Preclinical in organoids (2024-2025)

  Timeline to clinic: 2028-2030 (optimistic)

  n=6 connection: Cas9 has 6 domains, targets the 6-carbon
  steroid A-ring pathway. Meta-poetic.
```

### Base Editing (Single Nucleotide Precision)

```
  Target: Specific SNPs in AR gene (androgen receptor)
  Mechanism: Base editor (no double-strand break)
             → Change single nucleotide → reduce AR sensitivity
             → Follicle responds less to DHT
  Advantage: Precision (no gene knockout, just tuning)
  Status: Preclinical concept

  Could "dial down" androgen sensitivity rather than
  eliminating it completely.
```

### Prime Editing (Search-and-Replace)

```
  Target: Any mutation in any hair-related gene
  Mechanism: Write any desired sequence
  Application: Genetic forms of alopecia, not just AGA
  Status: Very early (2025 for other diseases)
```

---

## 5. RNA Interference Delivery Technologies

```
  The DELIVERY problem is the biggest challenge for RNA hair drugs:

  ┌──────────────────┬───────────────┬───────────┬──────────────┐
  │ Delivery Method  │ RNA Type      │ Duration  │ Scalability  │
  ├──────────────────┼───────────────┼───────────┼──────────────┤
  │ LNP injection    │ siRNA, mRNA   │ 4-6 weeks │ Good         │
  │ Microneedle patch│ siRNA, ASO    │ 2-4 weeks │ Excellent    │
  │ Dissolving MN    │ siRNA         │ 2 weeks   │ Best (self)  │
  │ AAV vector       │ shRNA (perm)  │ Permanent │ One-time     │
  │ Exosome carrier  │ siRNA, miRNA  │ 2-4 weeks │ Moderate     │
  │ GalNAc conjugate │ siRNA (liver) │ 6 months  │ N/A (liver)  │
  └──────────────────┴───────────────┴───────────┴──────────────┘

  MOST PROMISING for hair:
    1. Dissolving microneedle patch with siRNA-SRD5A2
       → Patient applies at home, weekly
       → No injection, no systemic exposure
       → Technology exists (Alnylam, Moderna platforms)

    2. Sustained-release LNP depot
       → Dermatologist injects every 3-6 months
       → Like Botox but for hair
```

---

## 6. Companies and Clinical Pipeline

```
  ┌──────────────────┬───────────────────┬──────────┬───────────┐
  │ Company          │ Approach          │ Stage    │ Target    │
  ├──────────────────┼───────────────────┼──────────┼───────────┤
  │ Kintor Pharma    │ AR degrader (oral)│ Phase II │ AGA       │
  │ Cassiopea        │ Topical anti-AR   │ Phase III│ AGA       │
  │ Stemson (Allergan│ iPSC → DP cells   │ Phase I  │ AGA       │
  │  partnership)    │ hair neogenesis   │          │           │
  │ dNovo            │ DP cell transplant│ Phase I/II│AGA       │
  │ Sirnaomics       │ siRNA platform    │ Preclin  │ Fibrosis  │
  │ Arrowhead        │ siRNA (liver/skin)│ Preclin  │ Multiple  │
  │ Moderna (?)      │ mRNA platform     │ No hair  │ Potential │
  │                  │ (could repurpose) │ program  │ future    │
  │ Concert Pharma   │ Deuruxolitinib    │ Phase III│ AA→AGA    │
  │ (Sun Pharma)     │ (JAK1/2)          │          │           │
  └──────────────────┴───────────────────┴──────────┴───────────┘
```

---

## 7. The Dream Protocol: 2030 Vision

```
  ╔═══════════════════════════════════════════════════════════════╗
  ║  HAIR LOSS TREATMENT 2030 (Projected)                        ║
  ╠═══════════════════════════════════════════════════════════════╣
  ║                                                               ║
  ║  Step 1: Genetic test (SNP panel for AGA risk)               ║
  ║  Step 2: siRNA microneedle patch (SRD5A2 silencing)          ║
  ║          → Apply weekly at home, no pills                    ║
  ║  Step 3: mRNA Wnt booster (quarterly injection)              ║
  ║          → Reactivates dormant follicles                     ║
  ║  Step 4: iPSC-derived DP cell implant (one-time)             ║
  ║          → New follicles in bald areas                       ║
  ║  Step 5: CRISPR SRD5A2 knockout (permanent, one-time)        ║
  ║          → Never produce DHT in scalp again                  ║
  ║  Step 6: Maintenance: topical exosomes (monthly)             ║
  ║          → Growth factor replenishment                       ║
  ║                                                               ║
  ║  = 6-step RNA-based complete hair restoration protocol       ║
  ║                                                               ║
  ║  Cost estimate: $5,000-15,000 total (vs $15k transplant now) ║
  ║  Timeline: 2028-2032 for most components                     ║
  ║                                                               ║
  ╚═══════════════════════════════════════════════════════════════╝
```

---

## n=6 Summary for RNA Therapeutics

| # | Claim | Grade |
|---|-------|-------|
| 101 | miRNA seed = 6 nt (H-DNA-018) → target for anti-miR | GREEN (known) |
| 102 | Cas9 has 6 domains (H-DNA-119) → gene editing tool | GREEN (known) |
| 103 | 6 RNA delivery methods catalogued | ORANGE |
| 104 | 2030 protocol = 6 steps | ORANGE (designed, not discovered) |
| 105 | 6 signaling pathways = 6 drug targets | GREEN (H-HAIR-096) |
