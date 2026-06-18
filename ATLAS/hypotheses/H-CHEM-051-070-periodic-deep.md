---
id: H-CHEM-051-070
title: Deep Periodic Table Structure Hypotheses
grade: mixed (6 GREEN, 3 ORANGE, 10 WHITE, 1 BLACK)
domain: chemistry / nuclear physics / thermochemistry
verified: 2026-03-28
summary: "Structural patterns in periodic table connecting to n=6"
---

# Deep Periodic Table Hypotheses (H-CHEM-051 to 070)

> Can the number-theoretic properties of perfect number 6 predict or explain
> structural features of the periodic table beyond surface-level Z=6 matching?

## Verification Summary (2026-03-28)

```
  Total: 20 hypotheses
  Script: verify/verify_chem_periodic_deep.py
  Run:    PYTHONPATH=. python3 verify/verify_chem_periodic_deep.py

  Grade Distribution:
  -----------------------------------------------
  🟩 Exact/Proven:         6  |  ######
  🟧 Structural match:     3  |  ###
  ⚪ Trivial/Coincidence:  10 |  ##########
  ⬛ Wrong/Refuted:        1  |  #
  -----------------------------------------------
  Total:                   20

  Strong matches (GREEN+ORANGE):  9
  Expected random (small int):   ~6
  Excess:                         3
```

## Background

Previous H-CHEM-001-030 focused on molecular chemistry. This batch targets
deeper periodic table structure: electron shells, nuclear magic numbers,
nucleosynthesis, and thermochemistry. The goal is to find patterns that
go beyond "carbon has Z=6" tautologies.

Key n=6 number-theoretic functions used throughout:

```
  n = 6             (the perfect number)
  sigma(6) = 12     (sum of divisors: 1+2+3+6)
  sigma_{-1}(6) = 2 (sum of reciprocals: 1/1+1/2+1/3+1/6)
  tau(6) = 4        (number of divisors)
  phi(6) = 2        (Euler totient)
  Proper divisors:  {1, 2, 3}
  Divisors:         {1, 2, 3, 6}
```

---

## A. Shell Structure (5 hypotheses)

### H-CHEM-051: Shell Capacities and Perfect Numbers

> The total electron capacity of shells 1-3 (quantum numbers n=1,2,3)
> equals 28, the second perfect number.

| Shell (n) | Capacity (2n^2) | Cumulative |
|-----------|----------------|------------|
| 1         | 2              | 2          |
| 2         | 8              | 10         |
| 3         | 18             | 28         |
| 4         | 32             | 60         |

```
  2 + 8 + 18 = 28 = second perfect number
  is_perfect(28) = True (sigma(28) = 56 = 2*28)
  Shell 1 capacity = 2 = phi(6)
```

**Grade: GREEN** -- Exact arithmetic. The 2n^2 formula is quantum mechanical;
28 appearing as a perfect number is non-trivial. However, the link to n=6 is
indirect (via the perfect number sequence, not directly from 6's properties).

---

### H-CHEM-052: 4d Block Aufbau Exceptions = 6

> The 4d transition metal block has exactly 6 Aufbau exceptions
> (elements whose electron configuration differs from the predicted filling order).

| Block | Exceptions | Count |
|-------|-----------|-------|
| 3d (Z=21-30) | Cr(24), Cu(29) | 2 = phi(6) |
| 4d (Z=39-48) | Nb(41), Mo(42), Ru(44), Rh(45), Pd(46), Ag(47) | **6 = n** |

**Grade: GREEN** -- Count = 6 is exact. The 3d block has 2 = phi(6) exceptions.
However, Aufbau exceptions arise from electron-electron repulsion energetics,
not number theory. This is a counting coincidence.

---

### H-CHEM-053: Orbital Capacities Decompose via sigma(6) and phi(6)

> The four orbital types have capacities that form an arithmetic sequence
> reconstructable entirely from sigma(6) and phi(6).

```
  Orbital capacities: s=2, p=6, d=10, f=14

  s =  2 = phi(6)
  p =  6 = n (the perfect number itself)
  d = 10 = sigma(6) - phi(6) = 12 - 2
  f = 14 = sigma(6) + phi(6) = 12 + 2

  Common difference: 4 = tau(6)
  Sequence: phi(6), n, sigma(6)-phi(6), sigma(6)+phi(6)

  ASCII diagram (capacity vs orbital type):
  f  |##############  14 = sigma+phi
  d  |##########      10 = sigma-phi
  p  |######           6 = n
  s  |##               2 = phi
     +----------------
      0  2  4  6  8 10 12 14
```

**Grade: GREEN** -- All four identities are exact. The arithmetic sequence
{2, 6, 10, 14} with step tau(6)=4 is a mathematical identity from 2(2l+1).
The structural observation is that sigma(6) and phi(6) alone reconstruct
all orbital capacities. This is the strongest shell-structure finding.

---

### H-CHEM-054: Orbital Type Count = tau(6)

> There are exactly 4 orbital types (s,p,d,f) used in known chemistry,
> and the capacity step between them is 4. Both equal tau(6).

```
  Number of orbital types: 4 = tau(6)
  Capacity step:           4 = tau(6)
  Sum of all capacities:  32 = 2^5
```

**Grade: GREEN** -- Exact. The number 4 follows from l=0,1,2,3 for elements
through Z=118. Step = 4 is a mathematical identity: 2(2(l+1)+1) - 2(2l+1) = 4.
Both equalities to tau(6) are exact but follow from quantum mechanics.

---

### H-CHEM-055: Period Length Bases = Proper Divisors of 6

> The first 6 periods of the periodic table have lengths determined by
> k = {1,1,2,2,3,3} where each length = 2k^2. The set {1,2,3} equals
> the proper divisors of 6.

| Period | Length | k (from 2k^2) |
|--------|--------|---------------|
| 1      | 2      | 1             |
| 2      | 8      | 2             |
| 3      | 8      | 2             |
| 4      | 18     | 3             |
| 5      | 18     | 3             |
| 6      | 32     | 4             |

**Grade: WHITE** -- {1,2,3} is trivially the first 3 positive integers.
That they are also proper divisors of 6 is coincidence. Period 7 introduces k=4.

---

## B. Chemical Periodicity (5 hypotheses)

### H-CHEM-056: Diagonal Relationships Count = 3

> The number of classical diagonal relationships in the periodic table
> (Li-Mg, Be-Al, B-Si) is 3, a proper divisor of 6.

**Grade: WHITE** -- 3 is a trivially small number. Some sources list additional
diagonal relationships (C-P, N-S), which would break the count.

---

### H-CHEM-057: Elements with ~6 Stable Oxidation States

> Multiple transition metals (Fe, Mn, Cr) have approximately 6 common
> oxidation states.

| Element | Oxidation States | Count |
|---------|-----------------|-------|
| Fe      | 0, +2, +3, +4, +5, +6 | 6 |
| Mn      | 0, +2, +3, +4, +6, +7 | 6 |
| Cr      | 0, +2, +3, +4, +5, +6 | 6 |

**Grade: WHITE** -- Count is highly sensitive to inclusion criteria.
Including/excluding 0 or rare states changes the count. Cherry-picked.

---

### H-CHEM-058: Pauling Electronegativity Maximum = tau(6)

> Fluorine's Pauling electronegativity (3.98) approximates tau(6) = 4
> within 0.50%.

**Grade: WHITE** -- 3.98/4.00 = 0.995. Within 0.5%. But the Pauling scale
has an arbitrary offset. If defined differently, the maximum would not be 4.
Scale-dependent coincidence.

---

### H-CHEM-059: Noble Gas Z and Multiples of 6

> Three of six noble gases have Z divisible by 6: Ar(18), Kr(36), Xe(54).
> Kr(36) = 6^2.

```
  He(2):  Z mod 6 = 2   (not multiple)
  Ne(10): Z mod 6 = 4   (not multiple)
  Ar(18): Z mod 6 = 0   Z/6 = 3
  Kr(36): Z mod 6 = 0   Z/6 = 6 = 6^2!
  Xe(54): Z mod 6 = 0   Z/6 = 9
  Rn(86): Z mod 6 = 2   (not multiple)
```

**Grade: WHITE** -- 50% divisibility rate. Kr=6^2 is interesting but follows
from cumulative 2n^2 shell sums.

---

### H-CHEM-060: Halogen Z = Noble Gas Z - 1

> Every halogen has Z = (noble gas Z) - 1. Br = 6^2 - 1, I = 9*6 - 1.

**Grade: WHITE** -- Trivially true by periodic table structure (group 17 is
adjacent to group 18). No independent n=6 prediction.

---

## C. Nuclear Chemistry (5 hypotheses)

### H-CHEM-061: Magic Number Gaps and Perfect Numbers

> Nuclear magic numbers {2, 8, 20, 28, 50, 82, 126} have first gap = 6 = n,
> second gap = 12 = sigma(6), and contain 28 (second perfect number).

```
  Magic numbers: 2, 8, 20, 28, 50, 82, 126
  Gaps:          6, 12,  8, 22, 32, 44
                 ^   ^
                 n  sigma(6)

  Perfect numbers in sequence: {28}
  (Note: 2 is NOT perfect; sigma(2)=3 != 4)
```

**Grade: ORANGE** -- Two independent n=6 connections in the gap structure
plus 28 being both magic and perfect. Magic numbers arise from nuclear
spin-orbit coupling, not number theory. But the coincidence of the first
two gaps matching n and sigma(n) exactly is structurally notable.

---

### H-CHEM-062: Perfect Number Nuclei in Astrophysics

> Both known small perfect numbers (6 and 28) produce isotopes A = sigma(Z)
> with special nuclear roles: C-12 (mass standard) and Ni-56 (supernova product).

```
  Z=6  (perfect): sigma(6)  = 12 -> C-12  = atomic mass unit standard
  Z=28 (perfect): sigma(28) = 56 -> Ni-56 = dominant supernova product

  Why: sigma(p) = 2p for any perfect number p.
       A = 2Z means equal protons and neutrons.
       Equal p,n maximizes nuclear binding at low-to-mid Z.
       -> Perfect number elements naturally produce the most stable equal-p,n isotopes.
```

**Grade: ORANGE** -- This is the deepest finding. The perfect number property
sigma(n) = 2n directly implies A = 2Z (symmetric nucleus), which is the
condition for maximum binding energy at low Z. Both Z=6 and Z=28 isotopes
with A = sigma(Z) play outsized roles in physics (mass standard, nucleosynthesis).
The structural connection is genuine, though the causal mechanism is nuclear
physics, not number theory.

---

### H-CHEM-063: Fe-56 Mass Number = sigma(28)

> Fe-56 has mass number 56 = sigma(28) and Z = 28 - phi(6) = 26.

```
  Fe: Z=26, A=56
  sigma(28) = 56: True
  28 - phi(6) = 26 = Z(Fe): True

  CORRECTION: Fe-56 is NOT the most tightly bound nucleus.
  Ni-62 has higher binding energy per nucleon:
    Ni-62: 8.7945 MeV/nucleon
    Fe-56: 8.7903 MeV/nucleon
  Fe-56 has lowest MASS per nucleon (different metric).
```

**Grade: WHITE** -- The arithmetic A = sigma(28) is exact, but the commonly
cited physics claim about Fe-56 being the most bound is incorrect.

---

### H-CHEM-064: Triple-Alpha Process Maps Completely to n=6

> Every number in the triple-alpha reaction 3*He-4 -> C-12 maps to
> a distinct number-theoretic function of 6.

```
  3 * He-4 -> C-12

  3  = proper divisor of 6     (reaction count)
  4  = tau(6)                  (alpha particle mass number)
  12 = sigma(6)                (product mass number)
  2  = phi(6)                  (helium atomic number)
  6  = n                       (carbon atomic number)

  MAPPING COMPLETENESS:
  +----------+-------+------------------+
  | Quantity | Value | n=6 function     |
  +----------+-------+------------------+
  | # alphas |   3   | proper divisor   |
  | A(He)    |   4   | tau(6)           |
  | A(C)     |  12   | sigma(6)         |
  | Z(He)    |   2   | phi(6)           |
  | Z(C)     |   6   | n itself         |
  +----------+-------+------------------+

  Five independent mappings. Zero leftover quantities.
```

**Grade: ORANGE** -- This is the most striking single finding. The triple-alpha
process is the primary carbon-producing reaction in stellar nucleosynthesis.
Every quantity in the reaction maps to a different n=6 number-theoretic function
with zero overlap and zero remainder. The coverage is complete.

However: the individual numbers (2, 3, 4, 6, 12) are all small, and n=6 generates
enough functions to cover many small-number combinations. A Texas Sharpshooter
test would be needed to assess significance rigorously.

---

### H-CHEM-065: Hoyle State Resonance Ratio

> The ratio of Hoyle state energy above 3-alpha threshold to Be-8 energy
> above 2-alpha threshold is approximately tau(6) = 4.

```
  Hoyle above 3-alpha:  0.379 MeV
  Be-8 above 2-alpha:   0.092 MeV
  Ratio: 4.126
  tau(6) = 4, error: 3.2%
```

**Grade: WHITE** -- Close to 4 but 3.2% error. Nuclear energy levels are
determined by the strong force; the mapping to tau(6) is ad hoc.

---

## D. Thermochemistry (5 hypotheses)

### H-CHEM-066: Dulong-Petit Law Uses 6 DOF

> A 3D harmonic solid has exactly 6 degrees of freedom per atom
> (3 kinetic + 3 potential), giving C_v = 6 * (kT/2) = 3kT = 3R per mole.

```
  DOF = 3 (kinetic) + 3 (potential) = 6 = n
  C_v = 6 * kT/2 = 3kT per atom = 3R per mole

  DOF breakdown:
  kinetic    |###  3
  potential  |###  3
  total      |######  6 = n
```

**Grade: GREEN** -- The factor 6 = n is exact. It arises from 2 * 3 dimensions,
where both 2 and 3 are proper divisors of 6. The coincidence that spatial
dimensionality gives exactly n=6 DOF is interesting but the 6 here comes
from physics (equipartition theorem), not from perfect number properties.

---

### H-CHEM-067: Benzene Resonance Energy = sigma_{-1}(6)

> Benzene's Huckel delocalization energy is exactly 2|beta| = sigma_{-1}(6),
> with 6 pi electrons = n and 12 total bonds = sigma(6).

```
  Huckel pi energies for benzene (6 MOs):
  E = alpha + k*beta, k = {+2, +1, +1, -1, -1, -2}

  Total pi energy:   6*alpha + 8*beta
  3 ethylenes:       6*alpha + 6*beta
  Delocalization:    2*beta = sigma_{-1}(6)|beta|

  Pi electrons: 6 = n
  Total bonds (C-C + C-H): 6 + 6 = 12 = sigma(6)
  Kekule structures: 2 = sigma_{-1}(6) = phi(6)
```

**Grade: GREEN** -- All three identities are exact. Benzene is the canonical
n=6 molecule; these connections are expected but arithmetically clean.

---

### H-CHEM-068: Carbon Debye Temperature

> Attempted: find n=6 connection to diamond Debye temperature (2230 K).

**Grade: BLACK** -- No clean ratio found. theta_D/6 = 371.7 vs 1000/e = 367.9
is 1.0% error but unit-dependent (Kelvin is arbitrary). Refuted.

---

### H-CHEM-069: Gibbs Phase Rule Constant = phi(6)

> The "+2" in Gibbs phase rule F = C - P + 2 equals phi(6), counting
> the two intensive variables (T, P).

```
  Max phases for C components: P_max = C + 2
  C=1: P_max = 3 (triple point) = divisor of 6
  C=2: P_max = 4 = tau(6)
  C=4: P_max = 6 = n
```

**Grade: WHITE** -- Exact arithmetic but C=1,2,4 are cherry-picked.
The Gibbs constant counts intensive variables; mapping to phi(6) is ad hoc.

---

### H-CHEM-070: Number of Noble Gases = 6

> Exactly 6 stable noble gases exist (He, Ne, Ar, Kr, Xe, Rn) and
> 2 elements are liquid at STP (Br, Hg) = phi(6).

**Grade: WHITE** -- Exact counts. But 6 noble gases reflects 6 completed
shells through Rn (period structure), and 2 is a trivially small number.
Oganesson (Z=118) is too unstable to count as a 7th.

---

## Limitations

1. **Small integer bias**: n=6 generates {1, 2, 3, 4, 6, 12} which are
   ubiquitous in chemistry. Many matches are expected by chance (~6 out of 20).
2. **Post-hoc selection**: Choosing which chemistry facts to test introduces
   selection bias. A rigorous test would predefine the mapping before looking
   at data.
3. **No causal mechanism**: Even genuine arithmetic matches (like orbital
   capacity decomposition) lack a causal explanation connecting perfect numbers
   to quantum mechanics.
4. **Carbon tautology**: Many connections follow from C having Z=6, which is
   the starting assumption, not an independent prediction.

## Strongest Findings (Worth Further Investigation)

| Rank | ID | Finding | Why Notable |
|------|----|---------|-------------|
| 1 | H-CHEM-064 | Triple-alpha complete mapping | 5 quantities, 5 distinct n=6 functions, zero waste |
| 2 | H-CHEM-062 | Perfect number nuclei | sigma(n)=2n implies stable nuclei; C-12 + Ni-56 |
| 3 | H-CHEM-053 | Orbital capacity decomposition | s,p,d,f from sigma(6) and phi(6) alone |
| 4 | H-CHEM-061 | Magic number gaps | First two gaps = 6, 12; contains perfect number 28 |

## Verification Direction

- Run formal Texas Sharpshooter test on H-CHEM-064 (triple-alpha mapping)
  with Bonferroni correction for number of tested reactions
- Investigate whether the sigma(n)=2n -> stable nucleus connection (H-CHEM-062)
  extends to perfect number 496 (Z=496 does not exist, but binding energy
  extrapolation might be meaningful)
- Check if orbital capacity arithmetic sequence generalizes to g-orbitals
  (l=4, capacity=18): does 18 = sigma(6) + n? Yes (12+6=18). Test this.
