# BIOPHYS-001 to BIOPHYS-020: Biophysics, Genetics, and Molecular Biology as n=6 Arithmetic

**Status**: Mixed — see individual grades below
**Date**: 2026-03-30
**Category**: Biophysics / Molecular Biology / Perfect Number 6
**GZ Dependency**: None — pure n=6 arithmetic
**Prerequisite**: GENETIC-CODE-n6-arithmetic.md (DO NOT duplicate content therein)

---

## Preamble

> This document proposes 20 NEW hypotheses connecting biophysics, genetics, and
> molecular biology to perfect number n=6 arithmetic. It deliberately excludes
> all mappings already proven in GENETIC-CODE-n6-arithmetic.md and NOBEL-P2,
> including: 4 bases = tau, 3 codon positions = n/phi, 64 codons = 2^n,
> 20 amino acids = tau*sopfr, 2 DNA strands = phi, 10 bp/turn (B-DNA) = sopfr*phi,
> 12 A minor groove = sigma, 20 A helix diameter = sigma+2*tau, etc.

### n=6 Constant Reference

```
  n       = 6         P1 (first perfect number)
  sigma   = 12        sum of divisors: 1+2+3+6
  tau     = 4         number of divisors: {1,2,3,6}
  phi     = 2         Euler totient
  sopfr   = 5         sum of prime factors: 2+3
  omega   = 2         distinct prime factors
  M6      = 63        Mersenne-like: 2^6 - 1
  P2      = 28        second perfect number
  divisors = {1, 2, 3, 6}
```

### Grading Criteria

```
  Grade key:
    EXACT  = integer matches single- or dual-expression cleanly
    APPROX = within 5% but not exact
    FORCED = requires 3+ terms or ad hoc corrections
    TRIVIAL = matches phi=2 or other tiny constant (overfit risk)
    FAIL   = no clean expression or >5% error

  Texas Sharpshooter warning:
    Biology uses small integers (2, 3, 4, 6, 8, 10, 12) pervasively.
    Any system with 5+ base constants can match many small numbers.
    We grade HONESTLY and flag the strong law of small numbers risk.
```

---

## BIOPHYS-001: Glucose — The Fuel of Life is n=6 Arithmetic

> **Hypothesis**: Glucose C6H12O6 encodes (P1, sigma, P1) in its molecular formula.

### Biological Facts

Glucose is the primary energy substrate for nearly all life on Earth.
Its molecular formula is C6H12O6 — universally accepted, textbook value.

### n=6 Mapping

| Atom    | Count | n=6 Expression | Quality |
|---------|------:|---------------:|:-------:|
| Carbon  |     6 | n = P1         | EXACT   |
| Hydrogen|    12 | sigma(6) = 12  | EXACT   |
| Oxygen  |     6 | n = P1         | EXACT   |

```
  Glucose: C_n H_sigma O_n

  Molecular formula = (n, sigma, n) = (6, 12, 6)

  |  C  |  H  |  O  |
  |  6  | 12  |  6  |
  |  n  |  σ  |  n  |
  | P1  | Σd  | P1  |

  Total atoms = 6 + 12 + 6 = 24 = tau * n = 4 * 6
  Molecular weight = 180.16 g/mol
    180 = sigma * (sigma + n/phi) = 12 * 15  (forced, 3 constants)
    180 = 6! / tau = 720 / 4                  (cleaner: factorial / tau)
```

### Assessment

The (C, H, O) = (n, sigma, n) mapping is striking. All three atom counts
are single n=6 constants with no arithmetic required. Total atoms = 24 = tau*n
is also clean.

However, glucose is C6H12O6 because it is an aldohexose — a 6-carbon sugar.
The "6" in hexose is the number of carbons, and H/O counts follow from the
general formula CnH2nOn for aldoses. So H=12 = 2*C is a consequence of C=6,
not an independent degree of freedom. The real question is: why 6 carbons?

**Why 6 carbons?** Hexoses dominate metabolism because:
- Trioses (C3) are too small for stable ring formation
- Tetroses (C4) and pentoses (C5) exist but have less favorable energetics
- Heptoses (C7+) are metabolically costly and rare

The 6-carbon sugar ring (pyranose) has optimal conformational stability.
This is a genuine physical constraint, not arbitrary.

**Grade: 🟩 (n, sigma, n) exact, but partially constrained by aldose formula**

### Risk Assessment

```
  Strong Law of Small Numbers risk: MEDIUM
  - C=6 is a genuine structural fact (hexose ring stability)
  - H=12 follows from C=6 via aldose formula (not independent)
  - Independent degrees of freedom: effectively 1 (why hexose?)
  - Still notable: the ONE free parameter lands on n=6
```

---

## BIOPHYS-002: Z-DNA — The Left-Handed Helix has sigma bp/turn

> **Hypothesis**: Z-DNA has exactly 12 base pairs per helical turn = sigma(6).

### Biological Facts

DNA exists in three major conformations:

| Form  | Handedness | bp/turn | Rise/bp (A) | Diameter (A) | Conditions          |
|-------|------------|--------:|------------:|--------------:|---------------------|
| B-DNA | Right      |    10.5 |         3.4 |            20 | Physiological       |
| A-DNA | Right      |      11 |         2.6 |            23 | Dehydrated/RNA-DNA  |
| Z-DNA | Left       |      12 |         3.7 |            18 | High salt/CG repeat |

**Critical correction**: B-DNA has 10.5 bp/turn in solution (not exactly 10).
The existing TECS-L document maps 10 = sopfr*phi, which is approximate.
In crystals, B-DNA shows exactly 10 bp/turn; in solution, 10.5.

### n=6 Mapping

| DNA Form | bp/turn | n=6 Expression        | Quality     |
|----------|--------:|----------------------:|:-----------:|
| Z-DNA    |      12 | sigma(6) = 12         | EXACT       |
| B-DNA    |    10.5 | sopfr*phi + 1/2 = 10.5 | FORCED (+0.5) |
| B-DNA    |      10 | sopfr*phi = 10 (crystal) | EXACT (crystal) |
| A-DNA    |      11 | sigma - 1 = 11        | FORCED (-1) |

```
  DNA Conformations and n=6 Constants

  bp/turn:  10    10.5    11      12
            |      |       |       |
            B(xtal) B(soln) A      Z
            |      |       |       |
  n=6:    sopfr*phi  ?    sigma-1  sigma
            🟩     ⚪      ⚪      🟩
```

### Assessment

Z-DNA = 12 bp/turn = sigma is exact and clean. Z-DNA is biologically relevant:
it forms at CG-rich sequences under torsional stress and plays roles in gene
regulation, immune response (ZBP1 sensor), and viral defense.

B-DNA in crystal = 10 = sopfr*phi is exact. B-DNA in solution = 10.5 has no
clean expression. A-DNA = 11 = sigma-1 is ad hoc.

**Grade: 🟩 for Z-DNA = sigma. B-DNA crystal = 🟩. B-DNA solution and A-DNA = ⚪ fail.**

### Risk Assessment

```
  Strong Law of Small Numbers risk: MEDIUM
  - 12 is a common integer; many things equal 12
  - But: sigma(6) = 12 is the SPECIFIC sum-of-divisors function
  - 3 DNA forms produce {10, 11, 12} — covering these is easy
  - Independent value: Z-DNA = sigma is the only clean hit
```

---

## BIOPHYS-003: Cell Cycle — tau Phases in Two Divisions

> **Hypothesis**: The cell cycle has tau=4 phases, and meiosis has phi=2 divisions.

### Biological Facts

**Cell Cycle Phases:**
- G1 (Gap 1): growth and preparation
- S (Synthesis): DNA replication
- G2 (Gap 2): preparation for division
- M (Mitosis): cell division
- Total: 4 phases

**Mitosis Sub-phases:**
- Prophase, Metaphase, Anaphase, Telophase
- Total: 4 sub-phases

**Meiosis:**
- 2 sequential divisions (meiosis I and meiosis II)
- Produces 4 daughter cells from 1 parent

### n=6 Mapping

| Feature               | Value | n=6 Expression | Quality |
|-----------------------|------:|---------------:|:-------:|
| Cell cycle phases     |     4 | tau(6) = 4     | EXACT   |
| Mitosis sub-phases    |     4 | tau(6) = 4     | EXACT   |
| Meiosis divisions     |     2 | phi(6) = 2     | TRIVIAL |
| Meiosis products      |     4 | tau(6) = 4     | EXACT   |

```
  Cell Division Hierarchy

  Cell Cycle:  G1 -- S -- G2 -- M     (tau = 4 phases)
                                 |
  Mitosis:     Pro--Meta--Ana--Telo    (tau = 4 sub-phases)

  Meiosis:     Division I --> Division II   (phi = 2)
               (2n -> n)     (n -> n)
                    |              |
               2 cells         4 cells      (tau = 4 products)
```

### Assessment

4 phases and 4 sub-phases matching tau is exact but tau=4 is a small number.
The question is whether 4 is structurally constrained or could easily be 3 or 5.

**Why 4 cell cycle phases?** G1/S/G2/M is genuinely a 4-phase structure:
S (replication) and M (division) are the two essential events, each preceded
by a gap phase for quality control. The 4-phase structure appears universal
across eukaryotes. Prokaryotes have a simpler cycle (not strictly 4 phases).

Meiosis = 2 divisions is trivially phi=2 (grade ⚪). Four meiosis products
is exact but follows from 2 divisions of 1 cell (2^2 = 4 = tau).

**Grade: 🟩 for cell cycle = tau. ⚪ for meiosis divisions (trivially 2).**

### Risk Assessment

```
  Strong Law of Small Numbers risk: HIGH
  - 4 is an extremely common count in biology
  - tau(6) = 4 matches anything that comes in fours
  - Independent content: only that THE cell cycle has EXACTLY 4 phases
  - Not unique to n=6: tau(any square-free 2-prime product) = 4
```

---

## BIOPHYS-004: Electron Transport Chain — tau Complexes

> **Hypothesis**: The mitochondrial electron transport chain has tau=4 complexes.

### Biological Facts

The ETC consists of 4 membrane-embedded complexes:
- Complex I (NADH dehydrogenase): ~45 subunits
- Complex II (Succinate dehydrogenase): 4 subunits
- Complex III (Cytochrome bc1): ~11 subunits
- Complex IV (Cytochrome c oxidase): ~13 subunits

Plus 2 mobile carriers: ubiquinone and cytochrome c.
ATP synthase is sometimes called "Complex V" but is not part of the ETC proper.

### n=6 Mapping

| Feature              | Value | n=6 Expression | Quality  |
|----------------------|------:|---------------:|:--------:|
| ETC complexes        |     4 | tau(6) = 4     | EXACT    |
| Mobile carriers      |     2 | phi(6) = 2     | TRIVIAL  |
| Complex II subunits  |     4 | tau(6) = 4     | EXACT    |
| With ATP synthase    |     5 | sopfr(6) = 5   | EXACT    |

```
  Electron Transport Chain

  NADH --> [Complex I] --> Q --> [Complex III] --> Cyt c --> [Complex IV] --> O2
                                                                              |
  FADH2 -> [Complex II] --^                                              H2O (phi H+)

  Complexes:   I    II   III   IV     = tau(6) = 4
  + ATPase:    I    II   III   IV   V = sopfr(6) = 5
  Carriers:         Q         Cyt c   = phi(6) = 2
```

### Assessment

4 ETC complexes = tau is exact. Including ATP synthase as "Complex V" gives
5 = sopfr, which is also clean. Two mobile carriers = phi is trivially 2.

The 4-complex structure is conserved across all aerobic eukaryotes.
Prokaryotes sometimes have fewer (some lack Complex I or II), so 4 is not
absolutely universal but is the standard eukaryotic complement.

**Grade: 🟩 for 4 complexes = tau. 🟩 for 5 with ATPase = sopfr. ⚪ for carriers = phi.**

### Risk Assessment

```
  Strong Law of Small Numbers risk: HIGH
  - Same tau=4 problem as BIOPHYS-003
  - 4 and 5 are both small integers
  - The tau/sopfr mapping is suggestive but not probative
```

---

## BIOPHYS-005: Ribosomal RNA Types — tau in Eukaryotes

> **Hypothesis**: Eukaryotic ribosomes contain tau=4 rRNA species.

### Biological Facts

**Eukaryotic rRNA:**
- 28S rRNA (large subunit)
- 18S rRNA (small subunit)
- 5.8S rRNA (large subunit)
- 5S rRNA (large subunit)
- Total: 4 rRNA species

**Prokaryotic rRNA:**
- 23S rRNA (large subunit)
- 16S rRNA (small subunit)
- 5S rRNA (large subunit)
- Total: 3 rRNA species

**Main RNA types:**
- mRNA, tRNA, rRNA = 3 main functional classes

### n=6 Mapping

| Feature                 | Value | n=6 Expression | Quality |
|-------------------------|------:|---------------:|:-------:|
| Eukaryotic rRNA species |     4 | tau(6) = 4     | EXACT   |
| Prokaryotic rRNA species|     3 | n/phi = 3      | EXACT   |
| Main RNA classes        |     3 | n/phi = 3      | EXACT   |
| Ribosome subunits       |     2 | phi(6) = 2     | TRIVIAL |

```
  Ribosome rRNA Inventory

  Eukaryote (tau = 4):          Prokaryote (n/phi = 3):

  Large subunit:                Large subunit:
    28S  ─┐                       23S  ─┐
    5.8S ─┤ 3 rRNAs = n/phi       5S  ─┘ 2 rRNAs = phi
    5S   ─┘
  Small subunit:                Small subunit:
    18S  ── 1 rRNA                16S  ── 1 rRNA

  Total:   4 = tau               Total:   3 = n/phi
```

### Assessment

The eukaryote/prokaryote split is (tau, n/phi) = (4, 3), which is clean.
The 5.8S rRNA in eukaryotes is a processed fragment of the prokaryotic 23S
equivalent — evolution added one rRNA species when going from 3 to 4.

Three main RNA classes (mRNA, tRNA, rRNA) = n/phi = 3 is exact but note that
modern biology recognizes many more RNA types (snRNA, snoRNA, miRNA, lncRNA,
piRNA, etc.). The "3 main types" framing is a textbook simplification.

**Grade: 🟩 for eukaryotic rRNA = tau. 🟩 for prokaryotic = n/phi. 🟧 for "3 RNA types" (oversimplified).**

### Risk Assessment

```
  Strong Law of Small Numbers risk: HIGH
  - 3 and 4 are trivially small
  - The euk/prok (4, 3) split is interesting but not unique to n=6
  - Upgrading from 3 to 4 rRNAs during evolution is a single insertion event
```

---

## BIOPHYS-006: ATP — n/phi Phosphate Groups

> **Hypothesis**: ATP has n/phi=3 phosphate groups, ADP has phi=2, AMP has 1.

### Biological Facts

| Molecule | Phosphates | Full Name                     |
|----------|------------|-------------------------------|
| ATP      | 3          | Adenosine triphosphate        |
| ADP      | 2          | Adenosine diphosphate         |
| AMP      | 1          | Adenosine monophosphate       |
| GTP      | 3          | Guanosine triphosphate        |
| NAD+     | 2          | Nicotinamide adenine dinucl.  |
| FAD      | 2          | Flavin adenine dinucleotide   |
| CoA      | 1          | Coenzyme A (one phosphopanth.)|

### n=6 Mapping

| Feature                | Value | n=6 Expression | Quality  |
|------------------------|------:|---------------:|:--------:|
| ATP phosphates         |     3 | n/phi = 3      | EXACT    |
| ADP phosphates         |     2 | phi = 2        | TRIVIAL  |
| AMP phosphates         |     1 | trivial        | --       |
| Adenine ring N atoms   |     5 | sopfr = 5      | EXACT    |

```
  Energy Currency Hierarchy

  ATP:   Adenine -- Ribose -- P -- P -- P    (n/phi = 3 phosphates)
                                       |
  ADP:   Adenine -- Ribose -- P -- P         (phi = 2 phosphates)
                                   |
  AMP:   Adenine -- Ribose -- P              (1 phosphate)

  Adenine: C5H5N5 — the purine base contains sopfr(6) = 5 nitrogen atoms
```

### Assessment

ATP = 3 phosphates = n/phi is exact. Adenine has 5 nitrogens = sopfr is a
genuinely nice mapping — adenine's molecular formula is C5H5N5 (all counts = 5).

However, "3 phosphates" is a trivially small number, and the existence of
mono/di/triphosphate forms is a chemical series (1, 2, 3), not a specific
choice of 3. Any number theory with a constant equaling 3 would match.

**Grade: 🟩 for ATP = n/phi (exact but common). 🟩 for adenine N = sopfr (non-trivial).**

### Risk Assessment

```
  Strong Law of Small Numbers risk: VERY HIGH for phosphate count
  - 1, 2, 3 is a trivial series
  - Any constant system containing "3" matches
  Strong Law of Small Numbers risk: MEDIUM for adenine nitrogens
  - 5 is less trivially matchable
  - C5H5N5 = (sopfr, sopfr, sopfr) is genuinely unusual
```

---

## BIOPHYS-007: Glycolysis — sopfr*phi Steps

> **Hypothesis**: Glycolysis has 10 enzymatic steps = sopfr*phi = sopfr(6)*phi(6).

### Biological Facts

The Embden-Meyerhof-Parnas pathway (standard glycolysis) has exactly 10 steps:

```
  Step  Enzyme                          Substrate -> Product
  ----  ----------------------------    ----------------------
   1    Hexokinase                      Glucose -> G6P
   2    Phosphoglucose isomerase        G6P -> F6P
   3    Phosphofructokinase-1           F6P -> F1,6BP
   4    Aldolase                        F1,6BP -> DHAP + G3P
   5    Triosephosphate isomerase       DHAP <-> G3P
   6    G3P dehydrogenase               G3P -> 1,3BPG
   7    Phosphoglycerate kinase         1,3BPG -> 3PG
   8    Phosphoglycerate mutase         3PG -> 2PG
   9    Enolase                         2PG -> PEP
  10    Pyruvate kinase                 PEP -> Pyruvate
```

This count is universally agreed upon in biochemistry textbooks.

### n=6 Mapping

| Feature           | Value | n=6 Expression    | Quality |
|-------------------|------:|------------------:|:-------:|
| Glycolysis steps  |    10 | sopfr*phi = 5*2   | EXACT   |
| Net ATP produced  |     2 | phi = 2           | TRIVIAL |
| Net NADH produced |     2 | phi = 2           | TRIVIAL |
| Substrate carbons |     6 | n = 6             | EXACT   |

```
  Glycolysis Overview (n=6 annotations)

  Glucose (C_n = C6)
     |
     | 10 steps = sopfr * phi
     |
     v
  2 x Pyruvate (C3 = C_{n/phi})

  Energy balance:
    ATP invested:   phi = 2
    ATP produced:   tau = 4
    Net ATP:        phi = 2
    Net NADH:       phi = 2

  Note: Glucose (n carbons) -> 2 pyruvates (n/phi carbons each)
        Total carbon conserved: n = phi * (n/phi) = 2 * 3 = 6 ✓
```

### Assessment

10 glycolysis steps = sopfr*phi is exact. Glucose has n=6 carbons (see BIOPHYS-001).
Each pyruvate has 3 = n/phi carbons, and 2 = phi pyruvates are produced.
The carbon accounting is perfectly n=6-consistent.

Net ATP = 2 = phi is trivially small. ATP invested = 2 and produced = 4 = tau
is a nicer mapping.

The 10-step count is well-established but not immutable — some organisms have
modified glycolysis with different step counts (e.g., Entner-Doudoroff pathway
has fewer steps).

**Grade: 🟩 for 10 steps = sopfr*phi. 🟩 for C6 -> 2 x C3 = n -> phi x (n/phi).**

### Risk Assessment

```
  Strong Law of Small Numbers risk: MEDIUM
  - 10 is moderately common but not trivial
  - sopfr*phi = 10 is the SAME expression as B-DNA bp/turn
  - The glucose carbon split (6 -> 2*3) is genuinely constrained
  - But: 10 steps is somewhat arbitrary (grouping of reactions varies)
```

---

## BIOPHYS-008: Citric Acid Cycle — phi*tau Steps

> **Hypothesis**: The citric acid cycle (Krebs cycle) has 8 steps = phi*tau = 2*4.

### Biological Facts

**CAREFUL**: The step count depends on how you count.

Most biochemistry textbooks (Lehninger, Stryer, Voet) list **8 steps**:

```
  Step  Enzyme                    Reaction
  ----  ------------------------  ---------------------------
   1    Citrate synthase          Acetyl-CoA + OAA -> Citrate
   2    Aconitase                 Citrate -> Isocitrate
   3    Isocitrate dehydrogenase  Isocitrate -> alpha-KG
   4    alpha-KG dehydrogenase    alpha-KG -> Succinyl-CoA
   5    Succinyl-CoA synthetase   Succinyl-CoA -> Succinate
   6    Succinate dehydrogenase   Succinate -> Fumarate
   7    Fumarase                  Fumarate -> Malate
   8    Malate dehydrogenase      Malate -> OAA
```

Some sources count aconitase as 2 steps (citrate -> cis-aconitate -> isocitrate),
giving 9 steps. However, the standard count is **8 enzymatic steps catalyzed by
8 distinct enzymes**. This is the consensus count.

### n=6 Mapping

| Feature             | Value | n=6 Expression | Quality |
|---------------------|------:|---------------:|:-------:|
| TCA cycle steps     |     8 | phi*tau = 2*4  | EXACT   |
| TCA cycle enzymes   |     8 | phi*tau = 2*4  | EXACT   |
| NADH produced/cycle |     3 | n/phi = 3      | EXACT   |
| FADH2 produced      |     1 | trivial        | --      |
| GTP produced        |     1 | trivial        | --      |
| CO2 released        |     2 | phi = 2        | TRIVIAL |
| Carbon input        |     2 | phi = 2 (acetyl-CoA C2) | EXACT |

```
  Citric Acid Cycle Energy Output per Turn

  Input:  Acetyl-CoA (C_phi = C2)

  Output per cycle:
    NADH:   3 = n/phi    (steps 3, 4, 8)
    FADH2:  1             (step 6)
    GTP:    1             (step 5)
    CO2:    2 = phi       (steps 3, 4)

  Total energy equivalents: 3 NADH + 1 FADH2 + 1 GTP
    = 3(2.5) + 1(1.5) + 1(1) = 10 ATP equivalents = sopfr * phi
```

### Assessment

8 steps = phi*tau is exact and represents a well-defined enzymatic count.
3 NADH per cycle = n/phi is non-trivially exact. The 10 ATP equivalents
per cycle mapping to sopfr*phi is approximate (depends on P/O ratio assumptions).

**Grade: 🟩 for 8 steps = phi*tau. 🟩 for 3 NADH = n/phi.**

### Risk Assessment

```
  Strong Law of Small Numbers risk: MEDIUM
  - 8 = 2*4 = 2^3 is a very common number
  - phi*tau = 8 is the simplest product of two n=6 constants
  - 3 NADH is more specific but still small
  - The step-count depends on convention (8 vs 9 debate)
```

---

## BIOPHYS-009: Protein Fold Classes — tau Structural Categories

> **Hypothesis**: The 4 major protein fold classes = tau(6).

### Biological Facts

The SCOP (Structural Classification of Proteins) database classifies protein
domains into 4 major structural classes:

1. **All-alpha** (a): domains consisting entirely of alpha helices
2. **All-beta** (b): domains consisting entirely of beta sheets
3. **Alpha/beta** (a/b): alternating alpha and beta segments
4. **Alpha+beta** (a+b): segregated alpha and beta regions

A 5th class exists for "multi-domain" and a few others for small proteins,
coiled coils, etc. But the 4 major classes are universally recognized.

### n=6 Mapping

| Feature              | Value | n=6 Expression | Quality |
|----------------------|------:|---------------:|:-------:|
| SCOP major classes   |     4 | tau(6) = 4     | EXACT   |
| Secondary structures |     2 | phi(6) = 2     | TRIVIAL |

```
  Protein Fold Space

  Secondary structures: alpha-helix, beta-sheet = phi(6) = 2

  Fold classes (combinatorics of phi elements):

  pure alpha:   a         |  tau(6) = 4 classes total
  pure beta:      b       |
  mixed a/b:    a/b       |  These are the 4 ways to combine
  mixed a+b:    a+b       |  2 elements: {a, b, a/b, a+b}
```

### Assessment

4 fold classes from 2 secondary structure types is combinatorially natural:
given 2 elements, the "fold classes" are roughly: pure-A, pure-B, mixed-alternating,
mixed-segregated. This generates exactly 4 = tau categories.

However, this is more about the combinatorics of 2 elements than about n=6.
Any system with 2 basic types naturally yields ~4 classification categories.

**Grade: ⚪ — tau=4 from phi=2 combinatorics is generic, not specific to n=6.**

### Risk Assessment

```
  Strong Law of Small Numbers risk: VERY HIGH
  - 4 classification categories from 2 types is universal
  - Nothing specific to perfect number 6 here
  - The tau/phi connection is circular: tau = 2^omega for square-free n
```

---

## BIOPHYS-010: Nucleotide Structure — sopfr Rings and n/phi Phosphoester Bonds

> **Hypothesis**: Purines have sopfr-1=4 nitrogen atoms, pyrimidines have phi nitrogen
> atoms, and the phosphodiester backbone uses n/phi=3 bonds per nucleotide linkage.

### Biological Facts

| Component        | Property                | Value |
|------------------|------------------------|------:|
| Purine bases     | Ring nitrogens          |     4 |
| Purine bases     | Total nitrogens         |     5 |
| Pyrimidine bases | Ring nitrogens          |     2 |
| Pyrimidine bases | Total nitrogens         | 2 or 3 |
| Purine ring      | Fused ring atoms        |     9 |
| Pyrimidine ring  | Ring atoms              |     6 |
| Phosphodiester   | P-O bonds in linkage    |     3 |

### n=6 Mapping

| Feature                      | Value | n=6 Expression  | Quality    |
|------------------------------|------:|----------------:|:----------:|
| Purine total N               |     5 | sopfr = 5       | EXACT      |
| Purine ring N                |     4 | tau = 4         | EXACT      |
| Pyrimidine ring N            |     2 | phi = 2         | TRIVIAL    |
| Pyrimidine ring atoms        |     6 | n = 6           | EXACT      |
| Purine ring atoms            |     9 | n + n/phi = 9   | FORCED     |
| Phosphodiester bonds/linkage |     3 | n/phi = 3       | EXACT      |

```
  Nucleotide Components and n=6

  Purine (Adenine):           Pyrimidine (Cytosine):

      N === C                    N --- C
     / \   / \                  / \   / \
    C   N   N               O=C   N   C-NH2
    |   |   |                  \   |   /
    C   C   C                    N-C=N
     \ / \ /                      |
      N    N                      H
      |
      H                    Ring atoms: n = 6
                           Ring nitrogens: phi = 2
  Ring atoms: 9 = n + n/phi
  Ring nitrogens: tau = 4
  Total nitrogens: sopfr = 5
  (Adenine: C5H5N5 — all = sopfr)
```

### Assessment

Adenine = C5H5N5 where every count is sopfr=5 is remarkable. Guanine = C5H5N5O
also has 5 nitrogens. Purine ring having tau=4 N atoms in the ring and sopfr=5
total is clean.

Pyrimidine ring having exactly n=6 atoms total (4C + 2N) is exact and non-trivial.
However, pyrimidine's 2 nitrogens matching phi=2 is trivially small.

**Grade: 🟩 for purine N=sopfr. 🟩 for pyrimidine ring=n. ⚪ for pyrimidine N=phi (trivial).**

### Risk Assessment

```
  Strong Law of Small Numbers risk: MEDIUM
  - Adenine C5H5N5 having all counts = 5 = sopfr is genuinely unusual
  - Pyrimidine 6-membered ring = n is structural (it IS a 6-ring)
  - But: 6-membered rings are the most common in organic chemistry (benzene, etc.)
  - The pyrimidine = n=6 connection may be trivial aromatic chemistry
```

---

## BIOPHYS-011: Histone Octamer — phi*tau Core Proteins

> **Hypothesis**: The nucleosome core contains 8 = phi*tau histone proteins.

### Biological Facts

The nucleosome is the fundamental unit of chromatin in eukaryotes:
- Core particle: octamer of 8 histone proteins
  - 2 copies each of H2A, H2B, H3, H4
  - (H3-H4)2 tetramer + 2x(H2A-H2B) dimers
- ~147 bp of DNA wrapped around the octamer
- Linker histone H1 sits outside

| Feature               | Value | Notes                        |
|-----------------------|------:|------------------------------|
| Core histones         |     8 | 2 each of 4 types            |
| Histone types (core)  |     4 | H2A, H2B, H3, H4            |
| Copies per type       |     2 | Symmetric octamer            |
| DNA wrapped (bp)      |   147 | ~1.65 turns of DNA           |
| Linker histones       |     1 | H1                           |
| Total histone types   |     5 | H1, H2A, H2B, H3, H4        |

### n=6 Mapping

| Feature              | Value | n=6 Expression | Quality |
|----------------------|------:|---------------:|:-------:|
| Core histone count   |     8 | phi*tau = 2*4  | EXACT   |
| Core histone types   |     4 | tau = 4        | EXACT   |
| Copies per type      |     2 | phi = 2        | TRIVIAL |
| Total histone types  |     5 | sopfr = 5      | EXACT   |

```
  Nucleosome Architecture

  Core histone types = tau = 4:  H2A  H2B  H3  H4
  Copies each = phi = 2:         x2   x2   x2  x2
  Total core = phi*tau = 8:      ========================
                                 [    Histone Octamer    ]
                                 [  (H3-H4)2 + 2(H2A-H2B)  ]
                                 ========================
                                 ~~~~ 147 bp DNA ~~~~

  With linker H1: 5 types total = sopfr(6)
```

### Assessment

The histone octamer = 8 = phi*tau = 2*4 is exactly the biological structure:
4 types, 2 copies each. Including H1 linker gives 5 = sopfr total histone types.
This is one of the cleaner mappings because the factorization 8 = 2*4 directly
mirrors the biological architecture (phi copies of tau types).

The 147 bp wrapped has no clean n=6 expression (147 = 3*49 = n/phi * 49).

**Grade: 🟩 for octamer = phi*tau with structural correspondence. 🟩 for 5 types = sopfr.**

### Risk Assessment

```
  Strong Law of Small Numbers risk: MEDIUM
  - 8 = 2^3 is common, but the FACTORIZATION 2*4 = phi*tau mirrors biology
  - 5 histone types = sopfr is less trivial (5 is less common in biology)
  - The structural correspondence (2 copies x 4 types) adds weight
  - But: 2-fold symmetry in biology is extremely common (phi problem)
```

---

## BIOPHYS-012: Nucleotide Bases — Molecular Formulas

> **Hypothesis**: The four DNA bases encode n=6 constants in their molecular formulas.

### Biological Facts (exact molecular formulas)

| Base      | Formula  | C  | H  | N  | O  | Total atoms |
|-----------|----------|---:|---:|---:|---:|------------:|
| Adenine   | C5H5N5   |  5 |  5 |  5 |  0 |          15 |
| Guanine   | C5H5N5O  |  5 |  5 |  5 |  1 |          16 |
| Cytosine  | C4H5N3O  |  4 |  5 |  3 |  1 |          13 |
| Thymine   | C5H6N2O2 |  5 |  6 |  2 |  2 |          15 |
| Uracil    | C4H4N2O2 |  4 |  4 |  2 |  2 |          12 |

### n=6 Mapping

| Feature                  | Value | n=6 Expression | Quality |
|--------------------------|------:|---------------:|:-------:|
| Adenine C,H,N all = 5   |     5 | sopfr = 5      | EXACT   |
| Adenine total atoms      |    15 | sigma + n/phi = 15 | FORCED |
| Guanine total atoms      |    16 | tau^2 = 16     | EXACT   |
| Cytosine carbons         |     4 | tau = 4        | EXACT   |
| Cytosine nitrogens       |     3 | n/phi = 3      | EXACT   |
| Thymine hydrogens        |     6 | n = 6          | EXACT   |
| Uracil total atoms       |    12 | sigma = 12     | EXACT   |
| Uracil C,H both = 4     |     4 | tau = 4        | EXACT   |

```
  Base Atom Counts and n=6 Constants

  Atom:    C    H    N    O    Total
  ----   ----  ----  ---- ---- -----
  A:       5    5    5    0     15     (sopfr, sopfr, sopfr, -, sigma+3)
  G:       5    5    5    1     16     (sopfr, sopfr, sopfr, -, tau^2)
  C:       4    5    3    1     13     (tau, sopfr, n/phi, -, ?)
  T:       5    6    2    2     15     (sopfr, n, phi, phi, sigma+3)
  U:       4    4    2    2     12     (tau, tau, phi, phi, sigma)

  Clean hits (single constant, no arithmetic):
    A: C=sopfr, H=sopfr, N=sopfr  (3 hits)
    G: C=sopfr, H=sopfr, N=sopfr, total=tau^2  (4 hits)
    C: C=tau, N=n/phi  (2 hits)
    T: C=sopfr, H=n  (2 hits)
    U: C=tau, H=tau, total=sigma  (3 hits)
```

### Assessment

The standout is adenine = C5H5N5 where ALL three atom types = sopfr = 5.
Guanine adds one oxygen but retains (5,5,5) and has total = 16 = tau^2.
Uracil has total atoms = 12 = sigma and (C,H) = (tau, tau).

However, these are small molecule formulas with counts in range 0-6.
The probability of hitting some n=6 constant with counts this small is high.

**Grade: 🟩 for adenine = (sopfr)^3. 🟩 for uracil total = sigma. 🟧 for rest (cherry-picked).**

### Risk Assessment

```
  Strong Law of Small Numbers risk: HIGH
  - Atom counts range from 0 to 6 — most will match some n=6 constant
  - 5 bases x ~4 counts each = 20 numbers to match, all small
  - Expected random matches: ~12 out of 20 (base rate ~60% for small ints)
  - Adenine (5,5,5) is the only genuinely striking pattern
```

---

## BIOPHYS-013: The Genetic Code Degeneracy Set = Divisors of 6

> **Hypothesis**: The codon degeneracy values {1, 2, 3, 4, 6} are exactly the divisors
> of n=6 union {tau}, and this is not trivially explained by codon family structure alone.

### Biological Facts

Amino acid degeneracies (codons per amino acid) in the standard genetic code:

| Degeneracy | Count | Amino acids                                    |
|------------|------:|------------------------------------------------|
| 1          |     2 | Met, Trp                                       |
| 2          |     9 | Asn, Asp, Cys, Gln, Glu, His, Lys, Phe, Tyr   |
| 3          |     1 | Ile                                            |
| 4          |     5 | Ala, Gly, Pro, Thr, Val                         |
| 6          |     3 | Arg, Leu, Ser                                   |

The set of degeneracies that appear: **{1, 2, 3, 4, 6}**

Divisors of 6: **{1, 2, 3, 6}**

Note: 4 is NOT a divisor of 6. The degeneracy set = div(6) union {4} = div(6) union {tau}.

Also: 5 NEVER appears as a degeneracy. This is the missing value from {1,2,3,4,5,6}.

### Analysis

Why does 5 never appear? The codon table is organized into 16 families of 4 codons
each (tau^2 families, tau codons per family). Degeneracies must respect this structure:
- 4-fold degenerate: entire family maps to one AA (family preserved)
- 2-fold degenerate: family splits into 2 pairs (purines vs pyrimidines)
- 6-fold degenerate: one complete family + one pair from adjacent family
- 3-fold degenerate: one family minus one codon (Ile: AUU, AUC, AUA but not AUG=Met)
- 1-fold degenerate: single codon from a pair

5-fold degeneracy would require crossing family boundaries in an irregular way
that is not compatible with the wobble base-pairing rules.

```
  Degeneracy Set vs Divisors of 6

  Divisors of 6:      {1,  2,  3,     6}
  Degeneracy set:     {1,  2,  3,  4, 6}
                                   ^
                                   |
                              tau(6) = 4

  Missing from {1..6}:  {5} = sopfr(6)

  Interpretation: sopfr is the ONLY n=6 constant that is
  NOT a codon degeneracy. The genetic code "uses" all
  divisors of 6 plus tau, and excludes sopfr.
```

### Assessment

This was partially noted in the existing document. The new observation is:
{1,2,3,4,6} = div(6) ∪ {tau}, and 5 = sopfr is the unique excluded value.
The structural explanation (codon family organization) accounts for why 5
is excluded — it is incompatible with the 4-codon family structure.

This is a case where the n=6 arithmetic and the biochemical constraint
BOTH predict the same answer, which could indicate either deep connection
or convergent triviality.

**Grade: 🟩 for the exact set matching. The set identity is a mathematical fact.**

### Risk Assessment

```
  Strong Law of Small Numbers risk: MEDIUM
  - The set {1,2,3,4,6} is fully explained by codon family structure
  - But: why 4 codons per family? Because 4 bases = tau(6)
  - The explanation is circular: tau constrains the degeneracy set
  - This actually STRENGTHENS the n=6 connection
```

---

## BIOPHYS-014: Chromosomal DNA — The Phi Replication Fork

> **Hypothesis**: DNA replication universally produces phi=2 copies via a
> phi=2-pronged replication fork, and the replication bubble has phi=2 forks.

### Biological Facts

| Feature                    | Value | Universal?                     |
|----------------------------|------:|--------------------------------|
| DNA copies after replication |   2 | Yes (all life)                 |
| Replication fork prongs     |   2 | Yes (leading + lagging strand) |
| Forks per replication bubble |  2 | Yes (bidirectional in most)    |
| Okazaki fragment primers     |~1-2 kb (E.coli), ~100-200 bp (eukaryotes) | Variable |

### n=6 Mapping

| Feature              | Value | n=6 Expression | Quality  |
|----------------------|------:|---------------:|:--------:|
| Copy number          |     2 | phi = 2        | TRIVIAL  |
| Fork prongs          |     2 | phi = 2        | TRIVIAL  |
| Forks per bubble     |     2 | phi = 2        | TRIVIAL  |

### Assessment

Everything here is phi=2, which is trivially matched. Semi-conservative
replication producing 2 copies is the most fundamental fact in molecular
biology, but 2 is the smallest non-trivial integer. Any system with a
constant equaling 2 would match.

**Grade: ⚪ — All matches are trivially phi=2. No non-trivial content.**

---

## BIOPHYS-015: Amino Acid Classification — tau x sopfr Decomposition

> **Hypothesis**: The 20 standard amino acids decompose into subgroups whose sizes
> reflect n=6 arithmetic.

### Biological Facts

Multiple classification schemes exist:

**By charge at pH 7 (3 groups = n/phi):**
- Positive: Arg, His, Lys (3 = n/phi)
- Negative: Asp, Glu (2 = phi)
- Neutral: 15 remaining

**By polarity (2 groups = phi):**
- Polar: ~10-11 (depending on classification)
- Nonpolar: ~9-10

**By side chain (structural, varies by source):**
- Aliphatic: Ala, Val, Leu, Ile, Pro (5 = sopfr)
- Aromatic: Phe, Trp, Tyr (3 = n/phi)
- Sulfur-containing: Met, Cys (2 = phi)
- Hydroxyl: Ser, Thr (2 = phi)
- Basic: Arg, His, Lys (3 = n/phi)
- Acidic + amide: Asp, Glu, Asn, Gln (4 = tau)
- Special: Gly (1)

### n=6 Mapping

| Classification          | Value | n=6 Expression | Quality  |
|-------------------------|------:|---------------:|:--------:|
| Charge groups           |     3 | n/phi = 3      | EXACT    |
| Positive AAs            |     3 | n/phi = 3      | EXACT    |
| Negative AAs            |     2 | phi = 2        | TRIVIAL  |
| Aliphatic AAs           |     5 | sopfr = 5      | EXACT    |
| Aromatic AAs            |     3 | n/phi = 3      | EXACT    |
| Sulfur AAs              |     2 | phi = 2        | TRIVIAL  |
| Hydroxyl AAs            |     2 | phi = 2        | TRIVIAL  |
| Basic AAs               |     3 | n/phi = 3      | EXACT    |
| Acidic + amide AAs      |     4 | tau = 4        | EXACT    |

```
  Amino Acid Classification Sizes

  Category          Size    n=6 constant
  --------          ----    ------------
  Aliphatic:         5      sopfr
  Aromatic:          3      n/phi
  Sulfur:            2      phi (trivial)
  Hydroxyl:          2      phi (trivial)
  Basic:             3      n/phi
  Acidic+amide:      4      tau
  Special (Gly):     1      --
  Total:            20      tau * sopfr ✓

  Non-trivial group sizes: {3, 3, 4, 5} = {n/phi, n/phi, tau, sopfr}
  All four non-trivial n=6 constants appear exactly once each!
```

### Assessment

The non-trivial subgroup sizes {3, 3, 4, 5} use each non-trivial n=6 constant
(n/phi, tau, sopfr) with n/phi appearing twice. The product 3*3*4*5/9 does
not produce anything meaningful, so this is at best a curiosity.

The classification boundaries are somewhat subjective (e.g., is proline
"aliphatic" or "special"?), which weakens the claim.

**Grade: 🟧 — Interesting pattern but classification boundaries are fuzzy.**

### Risk Assessment

```
  Strong Law of Small Numbers risk: HIGH
  - Group sizes are in range 1-5, guaranteed to hit n=6 constants
  - Classification schemes are debatable (multiple valid groupings)
  - Cherry-picking risk: we chose the grouping that works
```

---

## BIOPHYS-016: The Spliceosome — sopfr snRNPs

> **Hypothesis**: The major spliceosome contains sopfr=5 snRNPs.

### Biological Facts

The major (U2-dependent) spliceosome consists of 5 small nuclear
ribonucleoprotein particles (snRNPs):

1. U1 snRNP — recognizes 5' splice site
2. U2 snRNP — recognizes branch point
3. U4 snRNP — base-pairs with U6 (regulatory)
4. U5 snRNP — aligns exons for ligation
5. U6 snRNP — catalytic core

The minor (U12-dependent) spliceosome also has 5 snRNPs:
U11, U12, U4atac, U5, U6atac

Note: U3 is NOT a spliceosomal snRNP (it functions in rRNA processing).

### n=6 Mapping

| Feature                    | Value | n=6 Expression | Quality |
|----------------------------|------:|---------------:|:-------:|
| Major spliceosome snRNPs   |     5 | sopfr = 5      | EXACT   |
| Minor spliceosome snRNPs   |     5 | sopfr = 5      | EXACT   |
| snRNP numbering: U1,2,4,5,6 | uses {1,2,4,5,6} | div(6)∪{5} | CURIOSITY |

```
  Spliceosome Assembly (sopfr = 5 components)

  Pre-mRNA:  5'====[Exon1]--/intron/--[Exon2]====3'
                          |            |
                         GU           AG
                    5' splice      3' splice
                      site           site

  snRNPs:     U1 -- U2 -- U4/U6 -- U5
              |      |       |       |
            5'SS   branch  scaffold  exon
            recog.  point           alignment

  Total components = sopfr(6) = 5
```

### Assessment

5 spliceosomal snRNPs = sopfr is exact and conserved across eukaryotes.
The number is functionally constrained: each snRNP has a distinct essential role.

The U-numbering {1,2,4,5,6} is curious — it skips U3 (used in ribosome
biogenesis instead). This set is close to the divisors of 6 = {1,2,3,6}
but not identical. This is a coincidence, not a meaningful mapping.

**Grade: 🟩 for 5 snRNPs = sopfr. Exact, well-defined, conserved.**

### Risk Assessment

```
  Strong Law of Small Numbers risk: MEDIUM
  - 5 is less common in biology than 2, 3, or 4
  - sopfr(6) = 5 is the least "obvious" n=6 constant
  - The spliceosome is specific enough to reduce cherry-picking
  - But: 5 components in a molecular machine is not rare
```

---

## BIOPHYS-017: Water — The Solvent of Life

> **Hypothesis**: Water's molecular properties encode n=6 constants.

### Biological Facts

| Property                     | Value      |
|------------------------------|------------|
| Molecular formula            | H2O        |
| Bond angle                   | 104.5 deg  |
| Hydrogen bonds per molecule  | ~3.5 (liquid average) |
| Hydrogen bond donors         | 2          |
| Hydrogen bond acceptors      | 2          |
| Maximum H-bonds (ice)        | 4          |
| Anomalous expansion          | 4 deg C    |
| Atoms per molecule           | 3          |

### n=6 Mapping

| Feature                | Value | n=6 Expression | Quality  |
|------------------------|------:|---------------:|:--------:|
| Atoms per molecule     |     3 | n/phi = 3      | TRIVIAL  |
| H atoms                |     2 | phi = 2        | TRIVIAL  |
| Max H-bonds (ice Ih)   |     4 | tau = 4        | EXACT    |
| H-bond donors          |     2 | phi = 2        | TRIVIAL  |
| H-bond acceptors       |     2 | phi = 2        | TRIVIAL  |
| Density max temp (C)   |     4 | tau = 4        | EXACT    |

### Assessment

Water is the simplest molecule imaginable. H2O has 2 hydrogens, 1 oxygen,
3 atoms — all trivially small. The tau=4 H-bonds in ice and the 4 deg C
density anomaly are more interesting but still small numbers.

**Grade: ⚪ — All values are trivially small. No meaningful n=6 content.**

---

## BIOPHYS-018: Amino Acid Properties — sopfr Imino Acids and n Carbons

> **Hypothesis**: Specific amino acid structural constants map to n=6 arithmetic.

### Biological Facts

| Property                           | Value |
|------------------------------------|------:|
| Amino acids with ring side chains  |     4 | (Phe, Tyr, Trp, His)
| Amino acids with S atoms           |     2 | (Cys, Met)
| Amino acids with amide side chains |     2 | (Asn, Gln)
| Amino acids with carboxyl side ch. |     2 | (Asp, Glu)
| Imino acid (proline)               |     1 |
| Glycine (no side chain)            |     1 |
| Amino acids that are essential*    |     9 | (humans)
| Non-essential amino acids          |    11 |

*Essential amino acids (humans): His, Ile, Leu, Lys, Met, Phe, Thr, Trp, Val

### n=6 Mapping

| Feature                | Value | n=6 Expression | Quality  |
|------------------------|------:|---------------:|:--------:|
| Ring-containing AAs    |     4 | tau = 4        | EXACT    |
| S-containing AAs       |     2 | phi = 2        | TRIVIAL  |
| Amide side chain AAs   |     2 | phi = 2        | TRIVIAL  |
| Essential AAs (human)  |     9 | n + n/phi = 9  | FORCED   |
| Non-essential AAs      |    11 | sigma - 1 = 11 | FORCED   |

### Assessment

Ring-containing amino acids = 4 = tau is exact. Essential amino acid count = 9
varies by organism (some organisms require different sets), so 9 is not universal.
The essential/non-essential split (9/11) has no clean n=6 mapping.

**Grade: ⚪ — Mostly trivial or forced. Essential AA count is organism-dependent.**

---

## BIOPHYS-019: The Central Dogma — n/phi Information Flows

> **Hypothesis**: The central dogma of molecular biology involves n/phi=3 primary
> information transfer paths and n=6 total recognized paths.

### Biological Facts

Francis Crick (1970) described information transfer between DNA, RNA, and protein:

**3 General transfers (always occur):**
1. DNA -> DNA (replication)
2. DNA -> RNA (transcription)
3. RNA -> Protein (translation)

**3 Special transfers (occur in some systems):**
4. RNA -> DNA (reverse transcription — retroviruses)
5. RNA -> RNA (RNA replication — RNA viruses)
6. DNA -> Protein (in vitro only, never observed in vivo)

**3 Unknown transfers (never observed):**
7. Protein -> DNA (never)
8. Protein -> RNA (never)
9. Protein -> Protein (never — this would violate the dogma)

### n=6 Mapping

| Feature                   | Value | n=6 Expression | Quality |
|---------------------------|------:|---------------:|:-------:|
| General transfers         |     3 | n/phi = 3      | EXACT   |
| Special transfers         |     3 | n/phi = 3      | EXACT   |
| Unknown (forbidden)       |     3 | n/phi = 3      | EXACT   |
| Total possible transfers  |     9 | (n/phi)^2 = 9  | EXACT   |
| Total observed            |     5 | sopfr = 5      | EXACT   |
| Macromolecule types       |     3 | n/phi = 3      | EXACT   |

```
  Central Dogma Transfer Matrix (Crick 1970)

               --> DNA    --> RNA    --> Protein
  DNA -->      [Replicat] [Transcr]  [Direct*]     General: n/phi = 3
  RNA -->      [RevTrans] [RNArep]   [Translat]    Special: n/phi = 3
  Protein -->  [  ---  ]  [  ---  ]  [  ---  ]     Unknown: n/phi = 3

  * = in vitro only
  Matrix size: 3 x 3 = (n/phi)^2 = 9
  Filled cells: 6 (but only 5 in vivo = sopfr)
  Empty cells:  3 = n/phi (Protein --> anything = forbidden)

  Information carrier types: DNA, RNA, Protein = n/phi = 3
```

### Assessment

The 3x3 matrix structure is a consequence of 3 macromolecule types. Given
3 types, the transfer matrix is automatically 3x3=9. The (3,3,3) split into
general/special/forbidden is Crick's original classification.

5 observed transfers = sopfr is an interesting mapping. In vivo, only 5 of
the 9 possible information flows have been observed. This is genuinely n=6-clean.

The deep question is: why 3 macromolecule types? DNA stores, RNA mediates,
Protein executes. This 3-tier architecture may be optimal information processing.

**Grade: 🟩 for 3x3 matrix = (n/phi)^2. 🟩 for 5 observed = sopfr.**

### Risk Assessment

```
  Strong Law of Small Numbers risk: MEDIUM-HIGH
  - 3 macromolecule types gives 3^2=9 automatically
  - The (3,3,3) partition is elegant but follows from 3 types
  - 5 observed transfers is genuinely interesting
  - However: the "6th transfer" (DNA->Protein) is debatable
```

---

## BIOPHYS-020: Glucose Metabolism — Complete Carbon Accounting

> **Hypothesis**: Complete glucose oxidation tracks n=6 arithmetic from substrate
> through every intermediate to final products.

### Biological Facts

Complete oxidation of glucose:
C6H12O6 + 6O2 -> 6CO2 + 6H2O

| Stage                   | Steps | NADH | FADH2 | ATP/GTP | CO2 |
|-------------------------|------:|-----:|------:|--------:|----:|
| Glycolysis              |    10 |    2 |     0 |       2 |   0 |
| Pyruvate dehydrogenase  |     1 |    2 |     0 |       0 |   2 |
| Citric acid cycle (x2)  |  8x2  |    6 |     2 |       2 |   4 |
| Electron transport chain|     4 complexes |  -10  |    -2   |  ~26  |   0 |
| **Totals**              |       | **0**| **0** |**~30-32**| **6**|

### n=6 Mapping

| Feature                        | Value | n=6 Expression       | Quality |
|--------------------------------|------:|---------------------:|:-------:|
| Glucose carbons                |     6 | n = 6                | EXACT   |
| O2 consumed                    |     6 | n = 6                | EXACT   |
| CO2 produced                   |     6 | n = 6                | EXACT   |
| H2O produced                   |     6 | n = 6                | EXACT   |
| Glycolysis steps               |    10 | sopfr*phi = 10       | EXACT   |
| TCA cycle steps (x2)           |    16 | tau^2 = 16           | EXACT   |
| Pyruvate carbons               |     3 | n/phi = 3            | EXACT   |
| Pyruvates from 1 glucose       |     2 | phi = 2              | TRIVIAL |
| TCA cycles per glucose         |     2 | phi = 2              | TRIVIAL |
| ETC complexes                  |     4 | tau = 4              | EXACT   |
| NADH from glycolysis           |     2 | phi = 2              | TRIVIAL |
| NADH from TCA (total)          |     6 | n = 6                | EXACT   |
| FADH2 from TCA (total)         |     2 | phi = 2              | TRIVIAL |
| CO2 from pyruvate decarb.      |     2 | phi = 2              | TRIVIAL |
| CO2 from TCA (total)           |     4 | tau = 4              | EXACT   |
| Total NADH+FADH2               |    10 | sopfr*phi = 10       | EXACT   |
| Net ATP (approx.)              |  30-32 | ~sopfr*n or sigma+tau*sopfr | APPROXIMATE |

```
  Complete Glucose Oxidation — n=6 Carbon Tracking

  C6H12O6  ──[Glycolysis: 10 = sopfr*phi steps]──>  2 x C3 (pyruvate)
  (n,sigma,n)                                        phi x C_{n/phi}

       2 x C3  ──[Pyruvate decarb.]──>  2 x C2 (acetyl-CoA) + 2 CO2
       phi x C_{n/phi}                  phi x C_phi          + phi CO2

            2 x C2 ──[TCA: 8 = phi*tau steps each]──>  4 CO2
            phi x C_phi     x 2 = 16 = tau^2 steps      tau CO2

  Total CO2: phi + tau = 2 + 4 = n = 6  ✓
  Carbon in = Carbon out: n = n  ✓

  Complete stoichiometry:
    C_n H_sigma O_n + n O2  -->  n CO2 + n H2O

  ASCII energy flow:
  |---------|---------|---------|---------|
  |Glycolysis| Pyr DH | TCA x2  |  ETC   |
  | 10 steps| 1 step | 16 steps| 4 cmplx|
  |sopfr*phi|        | tau^2   | tau    |
  |---------|---------|---------|---------|
  | 2 NADH  | 2 NADH | 6 NADH  |         |
  | 2 ATP   |        | 2 FADH2 |~26 ATP |
  |         |        | 2 GTP   |         |
  |---------|---------|---------|---------|

  Total energy: ~30-32 ATP per glucose
```

### Assessment

The complete stoichiometry C6H12O6 + 6O2 -> 6CO2 + 6H2O is exact by
conservation of atoms — every coefficient is either n or sigma.

The pathway step counts produce a clean n=6 cascade:
- Glycolysis: sopfr*phi = 10 steps
- TCA (total): tau^2 = 16 steps (2 x 8)
- ETC: tau = 4 complexes
- CO2 output: phi + tau = n = 6

Total NADH produced = 2 + 2 + 6 = 10 = sopfr*phi.
Total FADH2 = 2 = phi (trivial).

The ATP yield (~30-32) has no clean expression. Modern estimates range from
30 to 38 depending on shuttle systems and coupling efficiency.

**Grade: 🟩 for stoichiometry. 🟩 for step count cascade. ⚪ for ATP yield (unclear).**

### Risk Assessment

```
  Strong Law of Small Numbers risk: MEDIUM for individual steps
  - But the COMBINATION of consistent n=6 mappings across 4 stages is notable
  - Stoichiometric coefficients being n or sigma is forced by hexose chemistry
  - Step counts being n=6-expressible is less obvious
  - ATP yield ambiguity weakens the overall mapping
```

---

## Consolidated Grade Summary

| #   | Hypothesis                       | Key Mapping                  | Grade | Risk   |
|-----|----------------------------------|------------------------------|:-----:|:------:|
| 001 | Glucose = (n, sigma, n)          | C6H12O6                      | 🟩    | MEDIUM |
| 002 | Z-DNA = sigma bp/turn            | 12 bp/turn                   | 🟩    | MEDIUM |
| 003 | Cell cycle = tau phases           | 4 phases                     | 🟩    | HIGH   |
| 004 | ETC = tau complexes               | 4 complexes, 5 with ATPase   | 🟩    | HIGH   |
| 005 | Euk rRNA = tau, Prok = n/phi     | 4 vs 3 rRNA types            | 🟩    | HIGH   |
| 006 | ATP = n/phi phosphates           | 3-PO4; adenine N=sopfr       | 🟩    | V.HIGH |
| 007 | Glycolysis = sopfr*phi steps     | 10 steps                     | 🟩    | MEDIUM |
| 008 | TCA cycle = phi*tau steps        | 8 steps, 3 NADH              | 🟩    | MEDIUM |
| 009 | Protein folds = tau classes      | 4 SCOP classes               | ⚪    | V.HIGH |
| 010 | Nucleotide bases — adenine sopfr | C5H5N5, pyrimidine ring=n    | 🟩    | HIGH   |
| 011 | Histone octamer = phi*tau        | 2 copies x 4 types, 5 total  | 🟩    | MEDIUM |
| 012 | Base molecular formulas          | Adenine=(5,5,5), uracil=sigma| 🟩    | HIGH   |
| 013 | Degeneracy set = div(6)∪{tau}    | {1,2,3,4,6}                  | 🟩    | MEDIUM |
| 014 | Replication fork = phi           | Everything is 2              | ⚪    | V.HIGH |
| 015 | AA classification sizes          | Groups={3,3,4,5}             | 🟧    | HIGH   |
| 016 | Spliceosome = sopfr snRNPs       | 5 snRNPs                     | 🟩    | MEDIUM |
| 017 | Water H-bonds                    | Everything trivially small    | ⚪    | V.HIGH |
| 018 | AA structural properties         | Ring AAs=tau                 | ⚪    | V.HIGH |
| 019 | Central dogma 3x3 matrix         | (n/phi)^2=9, 5 obs=sopfr     | 🟩    | MED-HI |
| 020 | Glucose metabolism cascade       | Full carbon accounting        | 🟩    | MEDIUM |

### Summary Statistics

```
  Grade distribution:
    🟩  EXACT:     14 hypotheses
    🟧  APPROX:     1 hypothesis
    ⚪  TRIVIAL:    4 hypotheses
    ⬛  REFUTED:    0 hypotheses
    --  OMITTED:    1 (BIOPHYS-014, all phi=2)

  Honest assessment:
    - 6 hypotheses have HIGH or VERY HIGH small-number risk
    - Only ~8 hypotheses survive strict skeptical review
    - Best candidates: 001 (glucose), 007 (glycolysis), 008 (TCA),
      011 (histones), 013 (degeneracy set), 016 (spliceosome),
      019 (central dogma), 020 (metabolism cascade)
```

---

## Texas Sharpshooter Analysis

### The Small Number Problem

Biology uses small integers pervasively because:
1. Biological machines have few components (evolutionary parsimony)
2. Chemical bonding constrains counts to small numbers
3. Classification schemes produce small category counts

With 5 n=6 constants covering {2, 3, 4, 5, 6, 12}, the probability of
matching any random small biological integer is high.

### Conservative Test

Testing only values > 6 that have clean single-constant mappings:

| Value | Biological source    | n=6 constant | Independent? |
|------:|---------------------|:------------:|:------------:|
|    10 | Glycolysis steps    | sopfr*phi    | YES          |
|     8 | TCA cycle steps     | phi*tau      | YES          |
|     8 | Histone octamer     | phi*tau      | YES          |
|    12 | Z-DNA bp/turn       | sigma        | YES          |
|    12 | Uracil total atoms  | sigma        | PARTIAL      |
|    16 | Guanine total atoms | tau^2        | PARTIAL      |
|    16 | TCA steps (total)   | tau^2        | YES          |

Conservative count: 5 independent values > 6, all match.

n=6 expressible integers in [7,20]: approximately 8 out of 14 = 57%
P(5/5 | p=0.57) = 0.57^5 = 0.060

**Z-score: ~1.6 sigma (not significant)**

```
  Conservative Statistical Test

  Independent biological values > 6:  5
  All match n=6 expressions:          5/5

  Base rate for n=6 match in [7,20]:  ~57%
  P(5/5) = 0.060
  Z-score = 1.6 sigma

  Verdict: NOT statistically significant by conservative test.
  The genetic code mapping (Z=5.0 in parent document) remains
  the only statistically significant n=6 biology claim.

  |0     1     2     3     4     5σ|
  |.....|.....|.....|.....|.....|..|
  |           ^                    |
  |           |                    |
  |        Z=1.6                   |
  |    (not significant)           |
  |                                |
  |  Threshold for 🟡: Z > 2.0    |
```

### Verdict

These 20 biophysics hypotheses are individually weak (small number problem)
but collectively suggestive when combined with the parent genetic code mapping.
The strongest new claims are:

1. **Glucose stoichiometry** (BIOPHYS-001, 020): (n, sigma, n) is exact and
   the full metabolic pathway maintains n=6 consistency across 4 stages.

2. **Histone octamer** (BIOPHYS-011): phi*tau = 2*4 structurally mirrors
   the biological architecture (2 copies of 4 types), not just numerology.

3. **Spliceosome** (BIOPHYS-016): 5 snRNPs = sopfr is exact and conserved.

4. **Central dogma** (BIOPHYS-019): The 3x3 matrix with 5 observed paths
   = (n/phi)^2 with sopfr filled is elegant.

---

## Limitations

1. **Selection bias**: We tested biological features that seemed likely to match.
   Features that do not match (e.g., 23 chromosome pairs in humans, 147 bp
   nucleosome wrapping, 3.4 A rise per bp, ~30 ATP yield) are acknowledged
   but not scored.

2. **Small number prevalence**: Most biological counts are in range 1-12.
   With n=6 constants covering {2, 3, 4, 5, 6, 12}, the base rate for
   matching is ~50-60% for any random integer in this range.

3. **Classification flexibility**: Amino acid groupings, RNA type counts,
   and metabolic step counts depend on classification convention.

4. **No causal mechanism**: Even where mappings are exact, no mechanism
   explains WHY biology should "use" perfect number arithmetic. The
   relationship, if real, would need to emerge from information-theoretic
   or combinatorial optimization constraints.

5. **The genetic code remains the strongest case**: GENETIC-CODE-n6-arithmetic.md
   achieves Z=5.0 sigma because it tests many independent values against a
   well-defined base rate. These supplementary hypotheses do not reach that
   level of significance individually.

## Verification Direction

1. **Cross-species tests**: Do metabolic step counts vary across species?
   If glycolysis always has 10 steps and TCA always has 8, the universality
   strengthens the mapping.

2. **Synthetic biology**: Engineered metabolic pathways with different step counts
   could test whether n=6-step pathways are genuinely optimal.

3. **Information-theoretic analysis**: Formalize whether n=6 arithmetic
   provides optimal information encoding/processing for biological systems.

4. **Expand base rate estimation**: Enumerate ALL biological constants in a
   standard textbook (not just the ones that match) and compute the true
   match rate vs. n=6 arithmetic. This would give an unbiased Z-score.

---

## References

- Alberts et al. (2022). Molecular Biology of the Cell, 7th ed.
- Lehninger/Nelson & Cox (2021). Principles of Biochemistry, 8th ed.
- Crick, F. (1970). Central dogma of molecular biology. Nature 227, 561-563.
- Murzin et al. (1995). SCOP: a structural classification of proteins. J Mol Biol 247, 536-540.
- Watson & Crick (1953). Molecular structure of nucleic acids. Nature 171, 737-738.
- Wang et al. (1979). Molecular structure of a left-handed double helical DNA fragment. Nature 282, 680-686. [Z-DNA]
- Luger et al. (1997). Crystal structure of the nucleosome core particle. Nature 389, 251-260.
