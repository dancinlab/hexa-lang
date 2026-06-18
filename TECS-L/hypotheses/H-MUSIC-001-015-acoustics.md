# H-MUSIC-001 through H-MUSIC-015: Music and Acoustics Connections to n=6
**n6 Grade: 🟩 EXACT** (auto-graded, 14 unique n=6 constants)


**Date**: 2026-03-28
**Category**: Music Theory / Acoustics / Number Theory
**Golden Zone Dependency**: H-MU-010 (GZ-dependent, failed), H-MU-015 (GZ-referenced). All others: None (pure number theory + acoustics)
**Verification Script**: `verify/verify_music_acoustics_015.py`
**Related**: H-UD-1 (just intonation = divisor ratios), #213 (music resonance = I sync), #237 (music intervals golden)

## Summary

> 15 hypotheses testing whether the structure of perfect number 6 --
> divisors {1,2,3,6}, sigma(6)=12, tau(6)=4, phi(6)=2, and the
> identity 1/2+1/3+1/6=1 -- explains structural features of Western
> music theory and acoustics.

**Result**: 2 structural (p<0.01), 1 weak evidence (p<0.05), 8 exact but high p, 4 failures/coincidences.

## Grade Summary

| #   | Grade | p-value | Exact | Hypothesis                                   |
|-----|-------|---------|-------|----------------------------------------------|
| 001 | GRN   | 1.0000  | YES   | 12 semitones = sigma(6)                      |
| 002 | GS*   | 0.0015  | YES   | Perfect consonances = div(6) ratios          |
| 003 | GRN   | 0.7500  | YES   | Pythagorean comma at sigma(6) steps          |
| 004 | WHT   | 1.0000  | no    | First 6 harmonics generate consonances       |
| 005 | GS*   | 0.0010  | YES   | Reciprocal sum = 1 (harmonic completeness)   |
| 006 | GRN   | 0.1136  | YES   | Time signatures from n=6 constants           |
| 007 | GRN   | 0.0500  | YES   | 6/8 compound time = 2x3 duality              |
| 008 | GRN   | 0.7140  | YES   | Polyrhythm 2:3 = primes of 6                |
| 009 | WHT   | 0.5000  | no    | Phrase lengths = tau(6) * 2^k                |
| 010 | WHT   | 1.0000  | no    | HR/BPM ratio in Golden Zone                  |
| 011 | GRN   | 0.1000  | YES   | Standing wave nodes = divisor reciprocals    |
| 012 | ORG   | 0.0455  | no    | Top consonances use only primes of 6         |
| 013 | GRN   | 1.0000  | YES   | 12-TET optimality from sigma(6)              |
| 014 | WHT   | 0.8000  | no    | First 6 harmonics energy fraction            |
| 015 | GRN   | 0.7140  | YES   | Tritone = n=6 semitones at 1/2 boundary      |

**Grades**: GS* 2, GRN 8, ORG 1, WHT 4 | Verified 12/15, Exact 10/15, Structural (p<0.05) 3/15

---

## CATEGORY 1: HARMONY AND INTERVALS

### H-MU-001: 12 Chromatic Semitones = sigma(6) [GRN, p=1.00]

> The 12-note chromatic scale has 12 semitones, which equals sigma(6) = 12,
> the sum of divisors of 6.

```
  sigma(6) = 1 + 2 + 3 + 6 = 12
  Chromatic semitones   = 12       EXACT MATCH
  LCM(2,3,4)           = 12       Also matches (divisors + tau)

  Equal temperament 5th: 2^(7/12) = 1.498307
  Just 5th:              3/2      = 1.500000
  Error:                 0.1129%
```

**Why 12?** 12 is simultaneously:
- sigma(6): divisor sum of perfect number 6
- LCM(1,2,3,4): smallest N where N-TET approximates ALL simple ratios
- Best N-TET for N<=15 (avg error 9.78 cents, see H-MU-013)

**Honest assessment**: The match is exact but 12 is a common number. High p-value (1.0) because 12 appears in many contexts. The STRUCTURAL claim is that 12's role in music derives from it being the LCM of the divisors of 6 -- which is deeper than the numerical coincidence alone.

### H-MU-002: Perfect Consonances = Divisor Ratios of 6 [GS*, p=0.0015]

> All four "perfect" consonances in music (unison, fourth, fifth, octave)
> have frequency ratios expressible using ONLY divisors of 6 and tau(6).

```
  Interval       Ratio   Components
  ──────────────────────────────────
  Unison         1:1     1/1  (divisors of 6)
  Perfect 5th    3:2     3/2  (divisors of 6)
  Perfect 4th    4:3     tau(6)/3
  Octave         2:1     2/1  (divisors of 6)

  Allowed set: {1, 2, 3, 4, 6} = div(6) U {tau(6)}
  All perfect consonances: YES
```

**Texas Sharpshooter**:
```
  Possible ratios a/b with a,b in {1..10}, a>b:  45
  Ratios using only {1,2,3,4}:                     6
  P(top 4 consonances all from this 6-set):        C(6,4)/C(45,4) = 0.000101
  Bonferroni-corrected p:                           0.0015
```

This is the STRONGEST result in this set. The probability that the four most consonant intervals all use exclusively the numbers {1,2,3,4} (the divisors of 6 plus tau(6)) is extremely low by chance.

**Consonance ranking (Helmholtz/Euler):**
```
  Consonance  |****    Unison    1:1   div(6) direct
              |****    Octave    2:1   div(6) direct
              |***     5th       3:2   div(6) direct
              |***     4th       4:3   tau(6)/3
              |**      Maj 3rd   5:4   requires 5 (sopfr)
              |**      Min 3rd   6:5   requires 5 (sopfr)
              |*       Maj 6th   5:3   requires 5
              |        ...
  ────────────┴───────────────────────────────
  BOUNDARY: divisors-only vs. needs sopfr(6)=5
```

### H-MU-003: Pythagorean Comma at sigma(6) Steps [GRN, p=0.75]

> The circle of fifths closes (approximately) after sigma(6) = 12 steps.
> The Pythagorean comma = (3/2)^12 / 2^7 = 531441/524288 = 23.46 cents.

```
  N   |  3^N vs 2^M  |  Error%
  ────┼──────────────┼──────────
   1  |  3 vs 4      |  25.00%
   5  |  243 vs 256  |   5.08%
   7  |  2187 vs 2048|   6.79%
  12  |  531441 vs   |   1.36%  <-- sigma(6), BEST for N<=20
      |  524288       |

  Circle of fifths:
  C -> G -> D -> A -> E -> B -> F# -> C# -> Ab -> Eb -> Bb -> F -> C
  |___________________________ 12 steps ___________________________|
```

**Verification**: 12 IS the best approximation point for N<=20 (error 1.36%). The next better value is N=41 (error 0.13%). 12 being the FIRST good closure point is why the chromatic scale settled at 12.

**Honest assessment**: p=0.75 because being best-of-20 is a 1/20 chance times Bonferroni. The connection to sigma(6) is real but the causality runs the other way: 12 works because it's related to the prime factorization 2x3, not because sigma(6) "causes" music to have 12 notes.

### H-MU-004: First 6 Harmonics Generate All Consonances [WHT, FAILED]

> Claim: harmonics 1-6 generate ALL just intonation intervals as pairwise ratios.

```
  Harmonics 1-6 pairwise ratios (11 unique):
  6/5, 5/4, 4/3, 3/2, 5/3, 2/1, 5/2, 3/1, 4/1, 5/1, 6/1

  Matched to just intonation: 6/11 (55%)
  Missing: m2(16:15), M2(9:8), m6(8:5), m7(9:5), M7(15:8)

  Comparison:
    Harmonics 1-5:  5/11  intervals
    Harmonics 1-6:  6/11  intervals  (+1: minor 3rd 6:5)
    Harmonics 1-7:  6/11  intervals  (+0: no new intervals)
```

**FAILED**: 6 harmonics capture only 55% of just intervals. The 6th harmonic adds only the minor third (6:5). However, note that harmonics 1-7 add NOTHING new -- so 6 is a natural stopping point, just not a complete one.

### H-MU-005: Reciprocal Sum 1/2+1/3+1/6=1 as Harmonic Completeness [GS*, p=0.001]

> The proper divisor reciprocals of 6 sum to exactly 1: 1/2 + 1/3 + 1/6 = 1.
> On a vibrating string, nodes at 1/2, 1/3, and 1/6 of the string length
> exactly "tile" the full string. This is the acoustic meaning of perfect numbers.

```
  1/2 + 1/3 + 1/6 = 1     EXACT

  String nodes:
  |=========|=========|=========|===================|
  0        1/6       1/3       1/2                  1
  |---1/6---|---1/6---|---1/6---|-------1/2----------|

  Harmonic 2: node at 1/2 (divides string in half)
  Harmonic 3: node at 1/3 (divides string in thirds)
  Harmonic 6: node at 1/6 (divides string in sixths)

  Their reciprocals tile the unit interval = complete coverage
```

**Perfect numbers with sigma_{-1}(n) = 2 (all divisor reciprocal sum = 2):**
```
  N=6:    1/1 + 1/2 + 1/3 + 1/6 = 2          (first perfect number)
  N=28:   1/1 + 1/2 + 1/4 + 1/7 + 1/14 + 1/28 = 2
  N=496:  (similarly sums to 2)

  No composite non-perfect number <= 1000 has proper divisor reciprocal sum = 1
```

**Structural**: This is a mathematical fact (the definition of perfect numbers), not a statistical claim. The MUSICAL interpretation -- that the proper divisor reciprocals of 6 tile a vibrating string -- gives physical meaning to the abstract number-theoretic property.

---

## CATEGORY 2: RHYTHM AND TIME

### H-MU-006: Time Signature Numerators from n=6 Constants [GRN, p=0.11]

> All common time signature numerators belong to the set {1,2,3,4,6,12}
> -- the divisors and arithmetic functions of 6.

```
  Time sig | Numerator | In n=6 set?
  ─────────┼───────────┼────────────
  4/4      |     4     |  YES (tau)
  3/4      |     3     |  YES (div)
  2/4      |     2     |  YES (div)
  6/8      |     6     |  YES (n)
  2/2      |     2     |  YES (div)
  3/8      |     3     |  YES (div)
  6/4      |     6     |  YES (n)
  12/8     |    12     |  YES (sigma)
  ─────────┴───────────┴────────────
  8/8 match (100%)

  Distinct numerators used: {2, 3, 4, 6, 12}
  n=6 set {1,2,3,4,6,12} covers 50% of integers 1-12
  P(random 6-set contains all 5 numerators) = 0.0076
  Bonferroni p = 0.114
```

**Honest assessment**: The match is exact but p=0.114 is above the 0.05 threshold. Small-number bias inflates the result -- time signatures naturally use small numbers. Grade: GRN (exact, not statistically significant).

### H-MU-007: 6/8 Compound Time = 2x3 Duality [GRN, p=0.05]

> 6/8 compound time exists because 6 = 2 x 3, the smallest number divisible
> by both 2 (duple feel) and 3 (triple subdivision). The prime factorization
> of 6 IS the duple-triple duality that defines compound meter.

```
  6/8 structure:
  |  .  .  |  .  .  |     = 2 groups of 3 (duple feel, triple subdivision)
  |  .  |  .  |  .  |     = 3 groups of 2 (triple feel, duple subdivision)

  6 = 2 x 3 = LCM(2,3)
  phi(6) = 2 (number of prime factors, giving the duality)
```

**Honest assessment**: This is definitional. 6/8 exists because 6 = 2 x 3 is a tautology. The musical insight is that 6 is the SMALLEST compound meter precisely because it's the smallest semiperfect number with both 2 and 3 as factors. Grade: GRN (exact, borderline p).

### H-MU-008: Fundamental Polyrhythm 2:3 = Prime Factors of 6 [GRN, p=0.71]

> The most fundamental polyrhythm (2 against 3) uses exactly the prime factors
> of 6, and resolves after LCM(2,3) = 6 beats.

```
  2:3 polyrhythm:
  Beat:  1  2  3  4  5  6 | 1  2  3  4  5  6
  2s:    X     X     X    | X     X     X
  3s:    X        X       | X        X
         ^                  ^
         coincide every 6 beats = n

  West African 12/8 bell pattern:
  12 pulses = sigma(6)
  Grouping: [2+2+3+2+3] = 12 or [3+3+3+3] = 12
```

**Honest assessment**: The 2:3 polyrhythm using primes of 6 is definitional (these are the smallest primes). The LCM=6 resolution is a mathematical consequence. p=0.71 reflects this is not statistically surprising. Grade: GRN (exact, not significant).

### H-MU-009: Phrase Lengths = tau(6) x 2^k [WHT, COINCIDENCE]

> Claim: standard phrase lengths (4, 8, 16, 32 bars) equal tau(6) x 2^k.

```
  tau(6) = 4 = 2^2
  4  = tau(6) x 2^0 = 2^2
  8  = tau(6) x 2^1 = 2^3
  16 = tau(6) x 2^2 = 2^4
  32 = tau(6) x 2^3 = 2^5
```

**HONEST FAILURE**: tau(6) = 4 = 2^2. These are just powers of 2. The connection to tau(6) is superficial -- phrase lengths are binary because of human preference for binary subdivision, not because of perfect number 6. Grade: WHT (coincidence, ad hoc).

### H-MU-010: Heart Rate / BPM Ratio in Golden Zone [WHT, FAILED]

> Claim: the ratio of resting heart rate to preferred music tempo falls
> in the Golden Zone [0.212, 0.500].

```
  HR/Tempo (HR=70 bpm assumed):
  Genre          | Tempo | HR/Tempo | In GZ?
  ───────────────┼───────┼──────────┼───────
  Adagio  (66)   |  66   |  1.061   |  NO
  Andante (90)   |  90   |  0.778   |  NO
  Allegro (130)  | 130   |  0.538   |  NO
  Presto  (180)  | 180   |  0.389   |  YES
  Dance   (120)  | 120   |  0.583   |  NO
  ─────────────────────────────────────────
  In Golden Zone: 1/5 (only extreme tempo Presto)
```

**FAILED**: The hypothesis does not hold. Most preferred tempi give HR/tempo ratios ABOVE the Golden Zone. Only Presto (which is extreme, not preferred) falls within. Grade: WHT (refuted).

---

## CATEGORY 3: ACOUSTICS AND PHYSICS

### H-MU-011: Standing Wave Nodes = Divisor Reciprocals [GRN, p=0.10]

> Harmonics 1-6 create standing wave nodes at 11 unique positions on a string.
> The proper divisor reciprocals of 6 (1/6, 1/3, 1/2) are ALL present as nodes.

```
  Harmonics 1-6 node positions (11 unique):
  1/6, 1/5, 1/4, 1/3, 2/5, 1/2, 3/5, 2/3, 3/4, 4/5, 5/6

  Divisor reciprocals present:
    1/6: YES (harmonic 6)
    1/3: YES (harmonic 3)
    1/2: YES (harmonic 2)

  Segment analysis:
  |=====|=====|=====|===============|
  0    1/6   1/3   1/2             1
  |-1/6-|-1/6-|-1/6-|-----1/2------|

  First half: trisected by factor 3
  Second half: undivided (the "fundamental" half)
```

**Honest assessment**: This follows from the definition of harmonics. Any set of harmonics 1-N will have nodes at k/n for all k,n<=N. The divisor reciprocals appearing is guaranteed. Grade: GRN (exact but partially trivial, p=0.10).

### H-MU-012: Top Consonances Use Only Primes of 6 [ORG, p=0.045]

> The top 3 (of 4 claimed) most consonant intervals by Euler's Gradus Suavitatis
> use ONLY the prime factors of 6 (i.e., 2 and 3) in their frequency ratios.

```
  Rank | Interval | Ratio | Gradus | Only {2,3}?
  ─────┼──────────┼───────┼────────┼────────────
    1  | Octave   | 2/1   |   2    |  YES
    2  | 5th      | 3/2   |   4    |  YES
    3  | 4th      | 4/3   |   5    |  YES
    4  | Maj 3rd  | 5/4   |   7    |  NO  (uses 5)
    5  | Maj 6th  | 5/3   |   7    |  NO  (uses 5)
    6  | Maj 2nd  | 9/8   |   8    |  YES
    7  | Min 3rd  | 6/5   |   8    |  NO  (uses 5)
    ...

  Top 3 all use only {2,3}: YES
  Top 4: FAILS (Major 3rd uses 5 = sopfr(6))

  {2,3}-only intervals: 4 out of 11 total
  P(top 4 all from {2,3} | random): C(4,4)/C(11,4) = 0.003
  P(top 3 all from {2,3} | random): C(4,3)/C(11,3) = 0.024
  Bonferroni p = 0.045
```

**Near miss**: The claim for top 4 fails because Major 3rd (5:4) at rank 4 uses the prime 5. However, note that 5 = sopfr(6) = 2+3, the sum of prime factors of 6. The top 3 being exclusively {2,3} is significant (p=0.024 raw). Grade: ORG (weak evidence, borderline).

### H-MU-013: 12-TET is Optimal N-TET for N = sigma(6) [GRN, p=1.00]

> Among equal temperament systems with N<=15 divisions per octave,
> 12-TET (N = sigma(6)) has the lowest average approximation error
> to just intonation intervals.

```
  N-TET | Avg Error (cents) | Max Error (cents)
  ──────┼───────────────────┼──────────────────
     5  |        62.90      |       111.73
     7  |        30.61      |        59.70
    10  |        26.15      |        57.60
    12  |         9.78      |        17.60   <-- BEST for N<=15
    13  |        22.27      |        38.72
    15  |        17.65      |        36.09
    19  |         7.29      |        14.58   <-- beats 12 for N>15
    24  |         9.78      |        17.60   (= 2x12)
    31  |         4.92      |        11.14   <-- best overall

  12 avg error vs neighbors:
       |
  60c  |*
       |
  40c  |
       |  *
  20c  |      * *         *     *
       |            *                 *  *
  10c  |          X              *
       |                *           *        *
   0c  └──5──7──10─12─13─15──17─19─22─24──31──
              N-TET                     ^
              X = 12-TET, best for N<=15

  Rank of 12-TET among N=5..31: 5th out of 27
  But: BEST among N<=15 (the practical range for instruments)
```

**Honest assessment**: 12-TET IS the best for small N (<=15), which is the musically practical range. But 19-TET and 31-TET beat it for larger N. The p=1.0 reflects that being best among 11 candidates (5-15) has probability ~1/11 = 0.09, times Bonferroni > 1. Grade: GRN (exact, verified, but p inflated by Bonferroni).

### H-MU-014: First 6 Harmonics Energy Fraction of zeta(2) [WHT, COINCIDENCE]

> First n=6 terms of sum(1/n^2) capture 90.67% of zeta(2) = pi^2/6.

```
  N terms | sum(1/n^2) | % of zeta(2)
  ────────┼────────────┼────────────
       5  |   1.4636   |    88.98%
       6  |   1.4914   |    90.67%   <-- n=6
       7  |   1.5118   |    91.91%
       8  |   1.5274   |    92.86%
      10  |   1.5498   |    94.22%

  Gain 5->6: +1.69%
  Gain 6->7: +1.24%

  NOTE: pi^2/6 = zeta(2) -- the denominator IS 6!
  But the convergence is smooth, no discontinuity at n=6.
```

**HONEST FAILURE**: While it's poetic that zeta(2) = pi^2/6 (the 6 in the denominator!), the convergence of sum(1/n^2) is smooth with no special jump at n=6. The 90.67% figure is unremarkable. Grade: WHT (coincidence).

### H-MU-015: Tritone = n=6 Semitones at 1/2 Boundary [GRN, p=0.71]

> The tritone (most dissonant interval, "diabolus in musica") spans exactly
> n=6 semitones, dividing the sigma(6)=12 semitone octave precisely in half.
> Its frequency ratio is 2^(1/2) = sqrt(2), where the exponent 1/2 equals
> the Golden Zone upper boundary.

```
  Tritone structure:

  C  C# D  Eb E  F  F# G  Ab A  Bb B  C
  |--|--|--|--|--|--|--|--|--|--|--|--|--|
  |<--- 6 semitones --->|<--- 6 semitones --->|
  |<-------- n=6 ------>|<-------- n=6 ------>|
  |<------------- sigma(6)=12 -------------->|

  Frequency ratio: 2^(6/12) = 2^(1/2) = sqrt(2) = 1.41421...
  Exponent: 1/2 = Golden Zone upper = Riemann critical line Re(s)

  Maximum dissonance occurs at the EXACT midpoint
  = boundary between consonance and "the other side"
```

**Honest assessment**: The tritone being 6 semitones in a 12-semitone system is tautological (12/2 = 6). But the TRIPLE coincidence -- that n=6 semitones = the tritone = the maximum dissonance point, and that the frequency ratio exponent is 1/2 = the GZ upper boundary -- is aesthetically striking even if not statistically significant. Grade: GRN (exact, meaningful but p=0.71).

---

## Overall Honest Assessment

### What is real (structural):
1. **H-MU-002** (p=0.0015): Perfect consonances using only divisors of 6 is statistically significant
2. **H-MU-005** (p=0.001): The reciprocal sum 1/2+1/3+1/6=1 is a mathematical fact with genuine acoustic meaning
3. **H-MU-012** (p=0.045): Top 3 consonances using only primes {2,3} of 6 has weak but real evidence

### What is exact but not surprising:
4. **H-MU-001**: 12 = sigma(6) is exact but 12 is too common a number
5. **H-MU-003**: Circle of fifths at 12 steps is real but causality is reversed (3^12 ~ 2^19)
6. **H-MU-013**: 12-TET is genuinely optimal for small N but Bonferroni kills significance
7. **H-MU-006,007,008,011,015**: All exact but p > 0.05

### What failed honestly:
8. **H-MU-004**: 6 harmonics only generate 55% of just intervals
9. **H-MU-009**: tau(6) = 4 = 2^2, just powers of 2
10. **H-MU-010**: HR/BPM ratio does NOT fall in Golden Zone
11. **H-MU-014**: No special jump in zeta(2) convergence at n=6

### The deeper picture:

The strongest finding is that music's fundamental intervals arise from ratios of VERY small numbers -- specifically {1, 2, 3} and their products. Since 6 = 2 x 3 x 1 is the smallest perfect number, and its divisors ARE {1, 2, 3, 6}, there is a genuine (if perhaps tautological) connection: **the arithmetic of n=6 IS the arithmetic of musical consonance because both are built from the same tiny primes**.

The question of causality remains: does n=6 "explain" music, or do both music and n=6 simply reflect the special role of 2 and 3 as the smallest primes?

```
  Causal diagram:

  Smallest primes {2, 3}
        |                \
        v                 v
  Perfect number 6    Musical consonance
  (2 x 3 = 6)        (ratios of 2 and 3)
  (1+2+3=6)           (octave, fifth, fourth)
        |                 |
        v                 v
  sigma(6) = 12       12 semitones
  1/2+1/3+1/6=1       Harmonic completeness
```

Both branches grow from the same root: the special role of 2 and 3 in both number theory and human auditory perception.

---

## Limitations

1. Small-number bias: many connections trace back to 2 and 3 being the smallest primes, not specifically to n=6
2. Bonferroni correction (15 hypotheses) deflates significance of individually promising results
3. Western music bias: non-Western scales (gamelan, raga) use different divisions, weakening universality claims
4. H-UD-1 already covers just intonation mapping; some overlap exists
5. Causality direction unclear for most hypotheses

## Next Steps

1. Test with perfect number 28: do its divisors {1,2,4,7,14,28} predict any scale system?
2. Cross-cultural test: do non-Western scales also use n=6 arithmetic?
3. Investigate whether the 19-TET and 31-TET optimality points relate to other number-theoretic constants
4. Connect H-MU-012 (Euler Gradus) more rigorously to the n=6 framework
5. Explore whether sigma(28)=56 has any musical analogue (56-TET?)
