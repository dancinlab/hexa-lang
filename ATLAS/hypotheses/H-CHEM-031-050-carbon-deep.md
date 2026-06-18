---
id: H-CHEM-031-050
title: Carbon-Deep Chemistry Hypotheses
grade: mixed (6 green, 1 orange, 10 white, 3 black)
domain: chemistry / organic / biochemistry
verified: 2026-03-28
dependency: Golden Zone dependent (TECS mappings are post-hoc)
summary: "6 exact, 1 structural, 10 trivial, 3 wrong"
---

# Carbon-Deep Chemistry Hypotheses (H-CHEM-031 to 050)
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


## Verification Summary (2026-03-28)

```
  Total: 20 hypotheses
  GREEN  exact/proven:        6  (chemistry facts correct; n=6 mappings post-hoc)
  ORANGE structural match:    1  (numerically interesting coincidence)
  WHITE  trivial/coincidence: 10 (arithmetically correct but numerological)
  BLACK  wrong/forced:        3  (no clean mapping or factually wrong)

  Script: verify/verify_chem_carbon_deep.py
  Run:    PYTHONPATH=. python3 verify/verify_chem_carbon_deep.py
```

## Grade Distribution (ASCII)

```
  GREEN  |======                    | 6/20  (30%)
  ORANGE |=                         | 1/20  (5%)
  WHITE  |==========                | 10/20 (50%)
  BLACK  |===                       | 3/20  (15%)
         +----+----+----+----+----+
         0    4    8    12   16   20
```

## Strongest Result

> **H-CHEM-041**: Carbon bond orders {1, 2, 3} = proper divisors of 6 {1, 2, 3}.
> SET IDENTITY (not just count, but exact element-for-element match).
> Carbon is the only element that commonly forms all three integer bond orders.
> Nitrogen can form triple bonds (N2, CN-) but these are special cases.
> This is the cleanest n=6 mapping in the batch.

---

## A. Organic Chemistry (7 hypotheses)

WHITE **H-CHEM-031: Biochemistry Core Functional Groups = 6 = n** -- The 6 basic functional groups in biochemistry are hydroxyl (-OH), carbonyl (C=O), carboxyl (-COOH), amino (-NH2), sulfhydryl (-SH), and phosphate (-PO4). Count = 6 = first perfect number.
> Verified: Count = 6. EXACT.
> But: Organic chemistry recognizes 12+ functional groups (ether, ester, amide, halide, nitrile, etc.). The "6 basic" set is a pedagogical convention in biochemistry textbooks, not a fundamental chemical classification. Cherry-picked subset.

WHITE **H-CHEM-032: SN1/SN2/E1/E2 = tau(6) = 4 Mechanisms** -- The 4 core substitution/elimination mechanisms {SN1, SN2, E1, E2} = tau(6) = 4 divisors of 6.
> Verified: Count = 4 = tau(6). EXACT.
> But: Additional mechanisms exist (SN2', E1cb, SNAr, radical substitution). The 4-mechanism classification is a pedagogical simplification. 4 is a common small number.

GREEN **H-CHEM-033: Huckel 4n+2 at n=1 = 6 Pi-Electrons** -- The Huckel aromaticity rule 4n+2 yields 6 pi-electrons at n=1 (benzene), the first stable neutral aromatic. First aromatic electron count = first perfect number.
> Verified: 4(1)+2 = 6. EXACT.
> Huckel series: n=0->2, n=1->6, n=2->10, n=3->14, n=4->18.
> n=1 (benzene) is the first stable neutral aromatic compound.
> Mapping "first aromatic = first perfect number" is exact on both sides, though the Huckel rule derives from quantum mechanics, not number theory.

WHITE **H-CHEM-034: Chiral Center Requires tau(6) = 4 Substituents** -- A stereogenic (chiral) carbon requires 4 different substituents = tau(6).
> Verified: 4 different groups required. EXACT.
> Derivative of H-CHEM-001 (sp3 = 4 bonds = tau(6)). Not independent.

WHITE **H-CHEM-035: CIP Chirality Designations = sigma_{-1}(6) = 2** -- Cahn-Ingold-Prelog assigns R or S to each stereocenter: 2 designations = sigma_{-1}(6) = 2.
> Verified: sigma_{-1}(6) = 1 + 1/2 + 1/3 + 1/6 = 2.0. R/S = 2. EXACT.
> But 2 is the most trivial number for any binary classification.

WHITE **H-CHEM-036: Benzene Kekule Structures = phi(6) = 2** -- Benzene has 2 Kekule (canonical resonance) structures with alternating single/double bonds. phi(6) = 2.
> Verified: 2 Kekule structures. phi(6) = 2. EXACT.
> Including 3 Dewar structures, total = 5 (not an n=6 function). 2 is trivial.

WHITE **H-CHEM-037: Hexane C6H14 Has 5 Structural Isomers** -- C6H14 has exactly 5 structural isomers: n-hexane, 2-methylpentane, 3-methylpentane, 2,2-dimethylbutane, 2,3-dimethylbutane.
> Verified: 5 isomers. Well-known chemistry fact.
> tau(6)+1 = 5 requires +1 ad hoc correction (PROHIBITED). 6-1 = 5 is trivial.
> No clean n=6 number-theoretic function produces 5.

---

## B. Carbon Bond Properties (5 hypotheses)

BLACK **H-CHEM-038: C-C Bond Energy Ratios vs n=6** -- C=C/C-C = 614/346 = 1.775. C-triple-C/C-C = 839/346 = 2.425. Do these map to n=6 functions?
> REFUTED: Nearest targets are 11/6 = 1.833 (3.2% error, ad hoc formula) and 12/5 = 2.4 (1.0% error, arbitrary denominator). Neither maps to a natural n=6 function. Bond energies depend on electron pair interactions, not atomic number arithmetic.

```
  Bond     | Energy (kJ/mol) | Ratio to C-C | Nearest n=6 target | Error
  ---------+-----------------+--------------+--------------------+------
  C-C      | 346             | 1.000        | 1                  | 0%
  C=C      | 614             | 1.775        | 11/6 = 1.833       | 3.2%
  C-triple | 839             | 2.425        | 12/5 = 2.400       | 1.0%
```

WHITE **H-CHEM-039: 3 Hybridization Types = 3 Proper Divisors** -- Carbon has 3 hybridization states (sp, sp2, sp3). Proper divisors of 6 excluding 6 itself = {1, 2, 3} = 3 elements.
> Verified: Count match (3 = 3). EXACT.
> But: The hybridization bond counts {2, 3, 4} only partially overlap with divisors {1, 2, 3, 6}. 3 is a small common number.

WHITE **H-CHEM-040: C-H/C-C Bond Energy Ratio ~ 6/5** -- C-H = 411 kJ/mol, C-C = 346 kJ/mol. Ratio = 1.188. Compare to 6/5 = 1.200.
> Verified: Error = 1.0% from 6/5. Numerically close.
> But 6/5 is not a standard number-theoretic function of 6. Ad hoc target.

GREEN **H-CHEM-041: Bond Orders {1,2,3} = Proper Divisors of 6** -- Carbon forms single (order 1), double (order 2), and triple (order 3) bonds. The set {1, 2, 3} equals the proper divisors of 6 (excluding 6).
> Verified: SET IDENTITY. Not just count (3=3) but exact element match.
> Carbon is the ONLY element that commonly forms all three integer bond orders.
> - Nitrogen: triple bonds mostly limited to N2 and CN-
> - Oxygen: only orders 1, 2 commonly
> - Silicon: almost exclusively order 1
> STRONGEST RESULT in this batch.

```
  Element | Bond orders formed | = proper divisors of Z?
  --------+--------------------+------------------------
  C (Z=6) | {1, 2, 3}         | YES: d(6)\{6} = {1,2,3}
  N (Z=7) | {1, 2, 3} (rare)  | d(7)\{7} = {1} (NO)
  O (Z=8) | {1, 2}            | d(8)\{8} = {1,2,4} (NO)
  Si(Z=14)| {1}               | d(14)\{14} = {1,2,7} (NO)
```

GREEN **H-CHEM-042: Total Bonds per Hybridization = tau(6) = 4 Always** -- Regardless of hybridization, carbon always forms exactly 4 total bonds (sigma + pi). sp: 2+2=4, sp2: 3+1=4, sp3: 4+0=4. Conservation: sigma + pi = tau(6) = 4.
> Verified: EXACT conservation identity.

```
  Hybridization | sigma | pi | Total | = tau(6)?
  --------------+-------+----+-------+---------
  sp            | 2     | 2  | 4     | YES
  sp2           | 3     | 1  | 4     | YES
  sp3           | 4     | 0  | 4     | YES
```

> This is the octet rule for carbon (needs 4 more electrons to fill shell). The mapping to tau(6) is post-hoc, but the conservation law sigma + pi = 4 is exact.

---

## C. Carbon Allotropes Deep (4 hypotheses)

GREEN **H-CHEM-043: Graphene BZ: 6 Dirac Points, 2 Inequivalent = phi(6)** -- Graphene's hexagonal Brillouin zone has 6 corner vertices (K/K' points) with Dirac cone dispersion. By zone symmetry, only 2 are inequivalent = phi(6).
> Verified: 6 total K-points = n. 2 inequivalent (K and K') = phi(6) = 2. Both EXACT.
> 6 vertices is a geometric fact of hexagons (trivially = 6). phi(6) = 2 is trivial.
> Natural mapping for hexagonal lattice systems.

BLACK **H-CHEM-044: Diamond Band Gap 5.47 eV** -- Diamond's band gap = 5.47 eV. Does this map to any n=6 function?
> REFUTED: Nearest match is 6 - 1/sigma_{-1}(6) = 5.5 eV (0.5% error). But this formula (6 - 0.5) is completely ad hoc. Band gaps are determined by crystal field splitting and covalent bonding physics, not atomic number arithmetic. No natural n=6 number-theoretic function yields 5.47.

WHITE **H-CHEM-045: (6,6) Armchair Nanotube: 12 Atoms/Ring = sigma(6)** -- The (6,6) armchair nanotube has 2*6 = 12 atoms per circumference ring = sigma(6). Diameter = 8.14 Angstrom.
> Verified: 2*6 = 12. EXACT.
> TAUTOLOGICAL: We chose n=6 specifically. Any (n,n) nanotube has 2n atoms per ring.

BLACK **H-CHEM-046: Graphite Interlayer Spacing Ratio** -- Graphite interlayer distance / C-C bond length = 3.35/1.42 = 2.359. No n=6 function matches.
> REFUTED: Nearest simple fraction is 7/3 = 2.333 (1.1% error), which is not an n=6 function. Interlayer spacing is governed by van der Waals physics, not Z arithmetic.

---

## D. Biochemistry of Carbon (4 hypotheses)

GREEN **H-CHEM-047: Calvin Cycle: 6 CO2 -> C6H12O6, 12 NADPH = sigma(6)** -- The Calvin cycle fixes 6 CO2 into one glucose molecule (6 carbons). It consumes 18 ATP (= 3*6) and 12 NADPH = sigma(6).
> Verified: 6 CO2 in = 6 C atoms out. Carbon conservation. 12 NADPH = sigma(6). Both EXACT.
> 6 CO2 is trivially carbon conservation. 12 NADPH = 2 per CO2 * 6 CO2.

```
  Calvin Cycle (per glucose)
  --------------------------
  CO2 input:    6 = n (perfect number)
  NADPH used:  12 = sigma(6) = sum of divisors
  ATP used:    18 = 3 * n
  C in product: 6 = n
```

WHITE **H-CHEM-048: Amino Acid Backbone: 3 Atoms, 2 Angles** -- Each amino acid contributes 3 backbone atoms (N-C_alpha-C'). 3 is a divisor of 6. The 2 free Ramachandran angles (phi, psi) = phi(6) = 2.
> Verified: Both exact. But 3 and 2 are the smallest integers > 1. Any small biological count will trivially match divisors of 6 or phi(6).

ORANGE **H-CHEM-049: Krebs Cycle: 6 NADH/glucose = n, Total 12 Carriers = sigma(6)** -- The Krebs cycle produces 6 NADH per glucose = n. Full glucose oxidation yields 10 NADH + 2 FADH2 = 12 reduced electron carriers = sigma(6).
> Verified: Both exact biochemical facts from standard metabolic tables.
> 12 = sigma(6) appearing as total electron carriers is structurally interesting.
> Caveat: 6 NADH = 3 NADH/acetyl-CoA * 2 acetyl-CoA. And 12 = 10+2 mixes NADH and FADH2.
> STRUCTURALLY INTERESTING because sigma(6) = 12 appears independently in:
>   - Diamond 2nd neighbors (H-CHEM-027)
>   - C60 pentagons (H-CHEM-029)
>   - Electron carriers in metabolism (this hypothesis)

```
  Glucose Oxidation Electron Carriers
  ------------------------------------
  Stage              | NADH | FADH2 | Subtotal
  -------------------+------+-------+---------
  Glycolysis         |  2   |   0   |   2
  Pyruvate dehydrog. |  2   |   0   |   2
  Krebs cycle        |  6   |   2   |   8
  -------------------+------+-------+---------
  TOTAL              | 10   |   2   |  12 = sigma(6)
```

GREEN **H-CHEM-050: Glycolysis: C6 -> 2 x C3 (Divisor Decomposition)** -- Glycolysis splits glucose (6 carbons) into 2 pyruvate (3 carbons each). 6 = 2 * 3, where {2, 3} are proper divisors of 6. Net yield: 2 ATP = phi(6), 2 NADH = phi(6).
> Verified: 6 = 2 * 3. Both 2 and 3 are divisors of 6. EXACT.
> The divisor decomposition is elegant: the first metabolic pathway splits the perfect number into its two non-trivial proper divisors.

```
  Glycolysis Summary
  ------------------
  Input:   C6H12O6   (6 carbons = n)
  Output:  2 x C3H4O3 (2 x 3 = 6, divisor decomposition)
  Net ATP:  2 = phi(6)
  Net NADH: 2 = phi(6)
  Steps:   10 (no clean n=6 mapping)
```

---

## Cross-Reference with H-CHEM-001-030

```
  sigma(6) = 12 appearances:
    H-CHEM-012: Octahedral edges
    H-CHEM-015: Cyclohexane hydrogens
    H-CHEM-027: Diamond 2nd neighbors
    H-CHEM-029: C60 pentagons
    H-CHEM-047: Calvin cycle NADPH (NEW)
    H-CHEM-049: Total electron carriers (NEW)

  tau(6) = 4 appearances:
    H-CHEM-001: sp3 bonds
    H-CHEM-032: SN1/SN2/E1/E2 (NEW, white)
    H-CHEM-034: Chiral substituents (NEW, white)
    H-CHEM-042: Total bond conservation (NEW)

  phi(6) = 2 appearances:
    H-CHEM-026: Graphene unit cell atoms
    H-CHEM-036: Kekule structures (NEW, white)
    H-CHEM-043: Inequivalent Dirac points (NEW)
    H-CHEM-050: Glycolysis yield (NEW)

  {1,2,3} = proper divisors:
    H-CHEM-041: Bond orders (NEW, strongest result)
    H-CHEM-050: Glycolysis C6 -> 2*3 split (NEW)
```

---

## Honest Assessment

Most GREEN grades reflect exact chemistry facts with post-hoc number-theoretic labels. The mappings (tau, sigma, phi) are applied after knowing the chemistry, not predicted from the mathematics.

**H-CHEM-041** (bond orders = proper divisors) stands out because it is a SET IDENTITY, not just a count match, and carbon is unique among light elements in satisfying it.

**H-CHEM-049** (12 electron carriers = sigma(6)) earns ORANGE because sigma(6) = 12 keeps appearing across very different domains (crystallography, fullerene geometry, metabolism), though each individual appearance could be coincidence.

The 10 WHITE grades honestly reflect that small numbers {2, 3, 4} will trivially relate to divisors of 6. The 3 BLACK grades show where we looked for n=6 connections and found none -- this is informative and should not be deleted.
