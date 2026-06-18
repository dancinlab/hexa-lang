---
id: H-CHEM-091-110
title: Biochemistry Deep — WHY Life is Built on 6
grade: mixed (7 green, 1 orange, 12 white, 0 black)
domain: biochemistry / molecular biology
verified: 2026-03-28
summary: "7 exact, 1 structural, 12 trivial, 0 wrong"
golden_zone_dependent: false (pure biochemistry facts; TECS mappings are ad hoc)
---

# Biochemistry Deep Hypotheses (H-CHEM-091 to 110)

> **Central question:** WHY is life built on the number 6?
> Carbon (Z=6) is the backbone of all life. This document investigates
> whether the perfect number 6 appears structurally in molecular biology
> beyond the trivial Z=6 connection, or whether deeper patterns exist.

## Verification Summary (2026-03-28)

```
  Total: 20 hypotheses
  🟩 Exact/Proven:        7  (biochemistry facts correct; some TECS mappings tautological)
  🟧 Structural match:    1  (ETC proton pumping = sigma(6), debated stoichiometry)
  ⚪ Trivial/Coincidence: 12  (arithmetically correct but numerological)
  ⬛ Wrong/Incorrect:      0

  Script: verify/verify_chem_biochem_deep.py
  Run:    PYTHONPATH=. python3 verify/verify_chem_biochem_deep.py
```

## Grade Distribution

```
  🟩 |####################| 7
  🟧 |###                 | 1
  ⚪ |####################################| 12
  ⬛ |                    | 0
```

## Causal Chain: Z=6 -> Life

```
  Carbon (Z=6)
    |
    v
  6-carbon sugars (glucose C6H12O6)        <-- H-CHEM-102
    |
    +---> Glycolysis: 6C -> 2 x 3C          <-- H-CHEM-103
    |       (factorization of perfect number)
    +---> 6 CO2 fixed per glucose            <-- H-CHEM-102
    |
    v
  DNA: 4 bases in triplets                   <-- H-CHEM-091
    |   4^3 = 64 = 2^6
    |
    +---> 6 reading frames (3 x 2)           <-- H-CHEM-095
    +---> Max codon degeneracy = 6           <-- H-CHEM-109
    +---> 6^2 = 36 max redundancy            <-- H-CHEM-110
    |
    v
  Proteins
    +---> Hexameric ring machines            <-- H-CHEM-098
    +---> 20 AAs = sum(first 6 Fibonacci)    <-- H-CHEM-096
    |
    v
  Cell Division: 6 mitotic phases            <-- H-CHEM-106
    |
    v
  Energy: sigma(6) = 12 protons/NADH in ETC  <-- H-CHEM-105
```

---

## A. DNA/RNA Structure (091-095)

### 🟩 H-CHEM-091: 64 Codons = 2^6

> The genetic code uses 4 bases in triplets: 4^3 = 64 = 2^6. The codon
> space equals 2 raised to the perfect number.

**Verification:**
| Quantity | Value | Connection to 6 |
|----------|-------|------------------|
| Base types | 4 = 2^2 | tau(6) = 4 |
| Codon length | 3 | Proper divisor of 6 |
| Total codons | 4^3 = 64 | = 2^6 (exact) |

The identity 4^3 = (2^2)^3 = 2^6 is algebraic. The deeper question is why
evolution selected triplets (3) and 4 bases. Both 3 and 4 are divisors of 6
(3 directly, 4 = tau(6)). Grade: exact arithmetic, but 2^6 = 64 is a
straightforward algebraic consequence.

---

### ⚪ H-CHEM-092: Start + Stop Codons = tau(6)

> ATG = 1 start codon. TAA, TAG, TGA = 3 stop codons. Total = 4 = tau(6).

| Signal | Codons | Count |
|--------|--------|-------|
| Start | ATG | 1 |
| Stop | TAA, TAG, TGA | 3 |
| Total | | 4 = tau(6) |

Both 1 and 3 are proper divisors of 6. Arithmetically exact but 4 is
trivially small; mapping to tau(6) is forced. Grade: coincidence.

---

### ⚪ H-CHEM-093: RNA Canonical Base Pairs = 3

> RNA has 3 canonical base pair types: AU, GC, GU (wobble).
> 3 = largest proper divisor of 6.

DNA has only 2 types (AT, GC). RNA adds GU wobble to reach 3. Exact match
to largest proper divisor but 3 is ubiquitous in biology. Grade: trivial.

---

### ⚪ H-CHEM-094: DNA bp/turn = sigma(6) - phi(6)

> B-DNA has 10.0 bp per turn. sigma(6) - phi(6) = 12 - 2 = 10.

| B-DNA Parameter | Value |
|-----------------|-------|
| Base pairs/turn | 10.0 |
| Spacing | 3.4 A |
| Pitch | 34.0 A |
| sigma(6) - phi(6) | 12 - 2 = 10 |

Arithmetically exact. Same formula gives glycolysis step count (H-CHEM-104).
However, 10 = 12 - 2 is trivial arithmetic. Physical cause is backbone
geometry, not number theory. Grade: coincidence.

---

### 🟩 H-CHEM-095: 6 Reading Frames in dsDNA

> Each DNA strand has 3 reading frames (codon offset 0, 1, 2).
> Double-stranded: 2 strands x 3 frames = 6 total reading frames.

```
  Strand 1:  Frame +1  |ATG|...|...|...
             Frame +2   A|TGx|xx|...|...
             Frame +3   AT|Gxx|xx|...|...

  Strand 2:  Frame -1  |ATG|...|...|...
             Frame -2   A|TGx|xx|...|...
             Frame -3   AT|Gxx|xx|...|...

  Total: 6 frames = 3 x 2 = product of proper divisors of 6
```

ALL possible protein-coding information in DNA is accessed through exactly
6 reading frames. This is structurally significant: the information
architecture of life is organized in 6-fold. Grade: exact and genuine.

---

## B. Protein Structure (096-100)

### ⚪ H-CHEM-096: 20 Amino Acids = Sum of First 6 Fibonacci

> F(1)+F(2)+F(3)+F(4)+F(5)+F(6) = 1+1+2+3+5+8 = 20 amino acids.

Arithmetically exact. But 20 has many decompositions (4x5, 2x10, etc.);
selecting "first 6 Fibonacci" is cherry-picked. The biological reason for
20 AAs is evolutionary optimization. Grade: coincidence.

---

### ⚪ H-CHEM-097: Alpha Helix 3.6 Residues/Turn

> Alpha helix has 3.6 residues/turn = 6 x 0.6.

| Helix Parameter | Value |
|-----------------|-------|
| Residues/turn | 3.6 |
| H-bond pattern | i -> i+4 |
| H-bond loop atoms | 13 |
| Pitch | 5.4 A |
| Rise/residue | 1.5 A |

3.6/6 = 0.6 = 3/5. The 0.6 factor has no clean number-theoretic meaning.
13 atoms in the H-bond loop is prime, unrelated to 6. Connection is
numerological. Grade: coincidence.

---

### 🟩 H-CHEM-098: Hexameric Protein Machines

> Ring-shaped molecular machines strongly prefer 6-fold (hexameric) symmetry.

| Protein | Function | Symmetry |
|---------|----------|----------|
| DnaB | Replicative helicase | Hexamer |
| Rho | Transcription terminator | Hexamer |
| T7 gp4 | Helicase-primase | Hexamer |
| Glutamine synthetase | Nitrogen metabolism | 12-mer (2x6) |
| Insulin | Storage form | Hexamer (2Zn + 6) |
| ClpX | Protease unfoldase | Hexamer |
| p97/VCP | AAA+ ATPase | Hexamer |
| Hfq | RNA chaperone | Hexamer |
| Papillomavirus E1 | Helicase | Hexamer |

Physical reason: 6-fold symmetry creates optimal pore geometry for threading
DNA and polypeptide chains. Honeycomb tiling is maximally efficient.
Pentamers and heptamers exist but hexamers dominate among ring ATPases.
Grade: genuine structural preference for 6.

---

### ⚪ H-CHEM-099: Parallel Beta Sheet phi+psi = -6

> Parallel beta sheet: phi = -119, psi = +113. Sum = -6 (perfect number).

| Conformation | phi | psi | phi+psi |
|-------------|-----|-----|---------|
| Parallel beta | -119 | +113 | **-6** |
| Antiparallel beta | -139 | +135 | -4 |
| Alpha helix | -57 | -47 | -104 |

Exact to standard textbook values. But phi/psi vary by +/-10 degrees
depending on residue and data source. Some sources give sum = -5.
Grade: coincidence (within measurement uncertainty).

---

### ⚪ H-CHEM-100: Ramachandran 3 Allowed Regions

> The Ramachandran plot has 3 main allowed conformational regions.
> 3 = largest proper divisor of 6.

Three regions: alpha-R, beta, alpha-L. Some classifications add PPII as
4th. The count depends on how strictly "allowed" is defined. 3 is trivially
common. Grade: coincidence.

---

## C. Metabolic Cycles (101-105)

### ⚪ H-CHEM-101: TCA Cycle Electron Carriers = tau(6)

> Per TCA turn: 3 NADH + 1 FADH2 = 4 reduced carriers = tau(6).

| Carrier | Count | Enzyme |
|---------|-------|--------|
| NADH | 3 | Isocitrate DH, alpha-KG DH, Malate DH |
| FADH2 | 1 | Succinate DH |
| GTP | 1 | Succinyl-CoA synthetase |
| **Total carriers** | **4** | = tau(6) |

If counting GTP, total = 5 (not a divisor of 6). Selective counting of
electron carriers only gives 4. Mild cherry-picking. Grade: trivial.

---

### 🟩 H-CHEM-102: Photosynthesis Equation = All 6s

> 6 CO2 + 6 H2O + light -> C6H12O6 + 6 O2

| Molecule | Coefficient | Carbon | Hydrogen | Oxygen |
|----------|-------------|--------|----------|--------|
| CO2 | **6** | 6 | - | 12 |
| H2O | **6** | - | 12 | 6 |
| Glucose | 1 | **6** | **12=sigma(6)** | **6** |
| O2 | **6** | - | - | 12 |

Every stoichiometric coefficient is 6 or sigma(6)=12. The most fundamental
biochemical equation is saturated with the perfect number. This is
tautological (6C sugar requires 6 CO2) but the question of WHY life chose
6-carbon sugars as primary fuel is genuine. Grade: exact.

---

### 🟩 H-CHEM-103: Glycolysis = Factorization of 6

> Glucose (6C) -> 2 pyruvate (3C each). 6 = 2 x 3.

```
  Glucose (6C)
     |
     | glycolysis (10 steps)
     |
     v
  2 x Pyruvate (3C)

  6 = 2 x 3 = product of proper divisors {1, 2, 3}
```

The most fundamental metabolic split in biology is the factorization of
the perfect number 6 into its proper divisors 2 and 3. Carbon conservation
requires this identity. Grade: exact and structurally meaningful.

---

### ⚪ H-CHEM-104: Glycolysis Steps = sigma(6) - phi(6)

> Glycolysis has exactly 10 enzymatic steps = sigma(6) - phi(6) = 12 - 2.

Same formula as DNA bp/turn (H-CHEM-094). Interesting recurrence of
sigma(6) - phi(6) = 10 in two unrelated biological systems. But 10 is
easily reached by many arithmetic combinations. Grade: coincidence.

---

### 🟧 H-CHEM-105: ETC Proton Pumping = sigma(6) per NADH

> Electron transport chain pumps 4+4+4 = 12 = sigma(6) protons per NADH.

| Complex | H+ Pumped | Notes |
|---------|-----------|-------|
| I (NADH DH) | 4 | Well established |
| III (Cytochrome bc1) | 4 | Q-cycle mechanism |
| IV (Cytochrome c oxidase) | 4 | Modern consensus (older: 2) |
| **Total** | **12** | = sigma(6) |

```
  H+ pumped per NADH through ETC:

  Complex I    ████  (4 H+)
  Complex III  ████  (4 H+)
  Complex IV   ████  (4 H+)
               ──────────
  Total:       12 H+ = sigma(6)
```

Combined with the known result ATP/RT ~ 12, two appearances of sigma(6)
in the bioenergetic core. Grade: structural (sigma(6) in energy transfer),
but Complex IV stoichiometry is still debated in some literature.

---

## D. Cell Biology (106-110)

### 🟩 H-CHEM-106: Mitosis = 6 Phases

> Cell division proceeds through exactly 6 phases: Prophase, Prometaphase,
> Metaphase, Anaphase, Telophase, Cytokinesis.

```
  1. Prophase        ──> Chromatin condenses
  2. Prometaphase    ──> Nuclear envelope breaks
  3. Metaphase       ──> Chromosomes align at plate
  4. Anaphase        ──> Sister chromatids separate
  5. Telophase       ──> Nuclear envelopes reform
  6. Cytokinesis     ──> Cell physically divides

  Phases: |==1==|==2==|==3==|==4==|==5==|==6==|
          Pro   ProM  Meta  Ana   Telo  Cyto
```

The most fundamental life process (cell replication) occurs in 6 steps.
Caveat: some texts count 5 (merging pro/prometaphase) or 4 (excluding
cytokinesis). The 6-count is the most common modern classification.
Grade: exact.

---

### ⚪ H-CHEM-107: Cell Cycle = tau(6) Phases

> G1, S, G2, M = 4 phases = tau(6) = 4.

Standard count = 4. G0 (quiescent) would make 5. tau(6) = 4 is exact but
4 is trivially common. Grade: coincidence.

---

### ⚪ H-CHEM-108: Histone Types = tau(6)

> Core histone types: H2A, H2B, H3, H4 = 4 = tau(6). Octamer = 2 x 4 = 8.

147 bp per nucleosome has no clean connection to 6 (147 = 3 x 7^2).
Histone type count matches tau(6) but 4 is common. Grade: coincidence.

---

### 🟩 H-CHEM-109: Max Codon Degeneracy = 6

> Three amino acids (Leu, Ser, Arg) each have exactly 6 codons.
> The genetic code's maximum redundancy = 6 (perfect number).
> The number of maximally degenerate AAs = 3 (proper divisor of 6).

| Amino Acid | Codons (6 each) |
|------------|-----------------|
| Leucine | UUA, UUG, CUU, CUC, CUA, CUG |
| Serine | UCU, UCC, UCA, UCG, AGU, AGC |
| Arginine | CGU, CGC, CGA, CGG, AGA, AGG |

```
  Codon degeneracy distribution:
  6 codons: |###| Leu, Ser, Arg (3 AAs)
  4 codons: |#####| Val, Pro, Thr, Ala, Gly (5 AAs)
  3 codons: |##| Ile (1 AA)
  2 codons: |#########| Phe, Tyr, His, Gln, Asn, Lys, Asp, Glu, Cys (9 AAs)
  1 codon:  |##| Met, Trp (2 AAs)
```

The error-correction ceiling of the genetic code equals the perfect number.
These 3 AAs (Leu, Ser, Arg) are among the most abundant in proteins.
Grade: exact and structurally significant.

---

### ⚪ H-CHEM-110: Maximum Redundancy = 6^2

> 6 reading frames x 6 max degeneracy = 36 = 6^2.

Derived from H-CHEM-095 and H-CHEM-109. Tautological (6 x 6 = 36).
Theoretical maximum, not typical usage. Grade: trivial.

---

## Verdict

```
  STRONGEST CONNECTIONS (non-trivial):
    H-CHEM-095: 6 reading frames = 3 x 2 (proper divisors)    [STRUCTURAL]
    H-CHEM-098: Hexameric proteins dominate ring machines      [PHYSICAL]
    H-CHEM-103: Glycolysis = factorization of 6 into 2 x 3    [EXACT]
    H-CHEM-105: ETC pumps sigma(6)=12 protons per NADH         [STRUCTURAL]
    H-CHEM-109: Max codon degeneracy = 6, for 3 amino acids   [EXACT]

  TAUTOLOGICAL BUT REAL:
    H-CHEM-091: 64 = 2^6 (algebraic identity)
    H-CHEM-102: Glucose equation = all 6s (follows from C6)
    H-CHEM-106: Mitosis 6 phases (classification dependent)

  CAUSAL CHAIN:
    Z=6 (carbon) -> 6C sugars -> 6=2x3 glycolysis split
                  -> 3-base codons x 2 strands = 6 reading frames
                  -> max degeneracy = 6

  Life is built on 6 because carbon is element 6, and the unique
  properties of 6 as a perfect number (1+2+3=6=1x2x3) propagate
  through biochemistry via carbon's 6-electron chemistry.
```
