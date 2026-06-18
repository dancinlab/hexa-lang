# H-LING-001 through H-LING-015: Linguistics and Cognitive Science
**n6 Grade: 🟩 EXACT** (auto-graded, 12 unique n=6 constants)


## Hypothesis

> The perfect number 6 framework (n=6, sigma(6)=12, tau(6)=4, phi(6)=2,
> Golden Zone [0.2123, 0.5], center 1/e) has structural connections to
> constants and classifications in linguistics, cognitive science, and
> language statistics.

## Background

This batch tests whether the n=6 framework extends beyond physics and
mathematics into human language and cognition. We examine 15 candidates
across three domains: theoretical linguistics, cognitive science, and
statistical properties of natural language.

Related hypotheses: H-067 (1/2+1/3=5/6), H-090 (master formula = perfect
number 6), H-098 (6 is the only perfect number with proper divisor
reciprocal sum = 1).

## Verification Results

Verification script: `verify/verify_ling_001_015.py`

### Summary Table

| ID          | Claim                                      | Error% | p-value | Grade |
|-------------|--------------------------------------------|--------|---------|-------|
| H-LING-001  | Basic word orders = 3! = 6 = n             |   0.0  | 0.000   | GREEN |
| H-LING-002  | Chomsky hierarchy = 4 = tau(6)             |   0.0  | 0.000   | WHITE |
| H-LING-003  | Vowel system size ~ 6                      |   8.3  | 1.000   | WHITE |
| H-LING-004  | C/V phoneme ratio ~ tau(6) = 4             |  10.0  | 1.000   | WHITE |
| H-LING-005  | Morpheme types = 6                         |   0.0  | 1.000   | WHITE |
| H-LING-006  | Cowan WM = 4 = tau(6)                      |   0.0  | 0.000   | WHITE |
| H-LING-007  | Ebbinghaus R(S) = 1/e = GZ center          |   0.0  | 0.000   | GREEN |
| H-LING-008  | Dual process = 2 = phi(6)                  |   0.0  | 0.000   | WHITE |
| H-LING-009  | Hick's law at n=6                          |   0.0  | 1.000   | WHITE |
| H-LING-010  | Stroop effect n=6 connection               |   0.0  | 1.000   | WHITE |
| H-LING-011  | Zipf's alpha ~ 1 from n=6                  |   0.0  | 1.000   | WHITE |
| H-LING-012  | English E freq ~ sigma(6)%                 |   5.5  | 0.807   | WHITE |
| H-LING-013  | English entropy ~ n=6 constant             |   0.0  | 1.000   | WHITE |
| H-LING-014  | Heaps' beta ~ GZ upper = 1/2               |   0.0  | 1.000   | WHITE |
| H-LING-015  | Benford P(1) = log10(2) in GZ              |  18.2  | 1.000   | WHITE |

### Grade Distribution

```
  GREEN:       2  (exact but trivial/generic)
  ORANGE_STAR: 0
  ORANGE:      0
  WHITE:      13  (coincidence or classification-dependent)
  BLACK:       0
```

---

## Section A: Linguistics (5 hypotheses)

### H-LING-001: Basic Word Orders = 3! = 6

> The 6 basic word orders (SOV, SVO, VSO, VOS, OVS, OSV) equal 3! = 6 = n.

**Grade: GREEN** -- exact combinatorial identity.

All 6 permutations of Subject, Object, Verb are attested in world languages:

```
  SOV:  45.0% |#############################################
  SVO:  42.0% |##########################################
  VSO:   9.0% |#########
  VOS:   3.0% |###
  OVS:   1.0% |#
  OSV:   0.3% |
```

3! = 6 is a mathematical fact. The connection to perfect number 6 is that
6 = 1 x 2 x 3 = 3!. This is true but it is a combinatorial identity, not a
prediction. The model did not predict that languages have 3 core arguments;
it is given by Subject-Object-Verb as a starting assumption.

**Limitation:** The claim is not falsifiable. Any set of 3 linguistic roles
produces 6 orderings by definition. The interesting question would be WHY
languages have exactly 3 core syntactic roles, which this does not answer.

### H-LING-002: Chomsky Hierarchy = 4 = tau(6)

> The 4 levels of the Chomsky hierarchy equal tau(6) = 4.

**Grade: WHITE** -- human classification choice.

The Chomsky hierarchy (Type 0-3) is a classification scheme chosen by
Chomsky. One could subdivide further (mildly context-sensitive, indexed
grammars, tree-adjoining) to get 5-7 types. The count 4 is an artifact of
how Chomsky drew the boundaries, not a natural constant.

### H-LING-003: Vowel System Size ~ 6

> The most common vowel system has 6 vowels.

**Grade: WHITE** -- the mode is 5, not 6.

WALS data (563 languages):
```
  2-4 (small)    :  92 (16.3%) |########
  5 (average-low): 174 (30.9%) |###############
  6 (average)    : 100 (17.8%) |########
  7-14 (large+)  : 197 (35.0%) |#################
```

The mode is 5 vowels (/a e i o u/), not 6. Claiming 6 requires cherry-picking.

### H-LING-004: Consonant/Vowel Phoneme Ratio ~ tau(6) = 4

> Median C/V ratio across languages is ~4.4, near tau(6) = 4.

**Grade: WHITE** -- 10% error, broad distribution (range 2-12).

### H-LING-005: Morpheme Types = 6

> Standard morpheme typology has 6 categories.

**Grade: WHITE** -- classification granularity is arbitrary.

One can count 2 types (free/bound), 3 types (lexical/derivational/inflectional),
6 types (the proposed scheme), or 8+ types (adding clitics, circumfixes, infixes).
Getting exactly 6 requires choosing a specific taxonomy.

---

## Section B: Cognitive Science (5 hypotheses)

### H-LING-006: Cowan's Working Memory = 4 = tau(6)

> Cowan's (2001) working memory capacity of 4 chunks equals tau(6).

**Grade: WHITE** -- 4 is a common small integer.

Cowan's estimate is 4 +/- 1 (range 3-5). The match is exact at the center
but 4 is too common an integer to be meaningful without a causal mechanism
connecting working memory to divisor counts.

### H-LING-007: Ebbinghaus Forgetting at t=S Gives 1/e = GZ Center

> In exponential forgetting R(t) = e^(-t/S), retention at t=S equals
> 1/e = 0.3679, the Golden Zone center.

**Grade: GREEN** -- mathematically exact, but a property of the exponential
function, not of memory or consciousness.

```
  R(t) = e^(-t/S)
  R(S) = e^(-1) = 1/e = 0.3679
  GZ center       = 1/e = 0.3679
  Match: exact (by definition of exponential decay)
```

**Critical caveat:** This is true for ANY exponential decay (RC circuits,
radioactive decay, capacitor discharge). The 1/e value is a mathematical
property of e^(-x) at x=1, not a discovery about forgetting. Furthermore,
modern memory research (Wixted 2004) shows power-law decay fits better
than exponential for human forgetting.

### H-LING-008: Dual Process Theory = 2 = phi(6)

> System 1 + System 2 = 2 systems = phi(6).

**Grade: WHITE** -- 2 is the most trivial count; everything has a binary division.

### H-LING-009: Hick's Law at n=6

> Hick's law RT = a + b*log2(n) has special behavior at n=6.

**Grade: WHITE** -- no special behavior. log2(6) = 2.585 matches no n=6 constant.

### H-LING-010: Stroop Effect

> The Stroop effect has structural connection to n=6.

**Grade: WHITE** -- no meaningful connection found. Color counts and conditions
are experimenter choices.

---

## Section C: Language Statistics (5 hypotheses)

### H-LING-011: Zipf's Exponent ~ 1

> Zipf's alpha = 1 can be expressed as phi(6)/sigma_{-1}(6) = 2/2.

**Grade: WHITE** -- alpha=1 is universal scaling (self-organized criticality),
and expressing 1 = 2/2 is trivial arithmetic.

### H-LING-012: English Letter E Frequency ~ sigma(6)%

> English letter E frequency (12.7%) is near sigma(6) = 12.

**Grade: WHITE** -- language-dependent, varies 11.8-16.4% across languages.

```
  English    :  12.7% (error from 12:  5.5%)
  French     :  14.7% (error from 12: 18.4%)
  German     :  16.4% (error from 12: 26.8%)
  Spanish    :  13.7% (error from 12: 12.4%)
  Italian    :  11.8% (error from 12:  1.7%)
  Portuguese :  12.6% (error from 12:  4.8%)
```

### H-LING-013: English Text Entropy ~ n=6 Constant

> Shannon entropy of English (~1.3 bits/char) matches an n=6 expression.

**Grade: WHITE** -- entropy varies by language (Chinese 9.7, Hawaiian 1.0).
No clean match to any n=6 constant.

### H-LING-014: Heaps' Law beta ~ GZ Upper = 1/2

> Heaps' law vocabulary growth exponent beta ~ 0.5 = GZ upper boundary.

**Grade: WHITE** -- beta varies 0.4-0.8 across corpora. GZ covers 29% of [0,1],
so random values have a 29% chance of landing inside.

### H-LING-015: Benford's P(d=1) = log10(2) in Golden Zone

> Benford's law gives P(leading digit 1) = log10(2) = 0.301, which falls
> in the Golden Zone [0.212, 0.500].

**Grade: WHITE** -- GZ spans 29% of [0,1], making this unsurprising.
Error from GZ center (1/e) is 18.2%. log10(2) and 1/e are fundamentally
different constants (base-10 logarithm vs natural exponential).

```
  Benford distribution:
  d=1: P=0.3010 |############### <-- IN GZ
  d=2: P=0.1761 |########
  d=3: P=0.1249 |######
  d=4: P=0.0969 |####
  d=5: P=0.0792 |###
  d=6: P=0.0669 |###
  d=7: P=0.0580 |##
  d=8: P=0.0512 |##
  d=9: P=0.0458 |##
  Digits in GZ: 1 out of 9
```

---

## Honest Assessment

```
  Structurally meaningful: 2 (both GREEN, both trivially true)
  Coincidence/trivial:    13 (all WHITE)
  Refuted:                 0

  H-LING-001: 3!=6 is exact combinatorics, not a model prediction.
  H-LING-007: e^(-1)=1/e is a math identity, not specific to memory.

  The n=6 framework does NOT have predictive power for linguistics
  or cognitive science. All matches found are either:
  (a) trivial small integers (2, 4) that match many things,
  (b) classification-dependent (researcher chooses how many categories),
  (c) language-dependent (varies across languages), or
  (d) mathematical identities unrelated to n=6 specifically.
```

## Limitations

- WALS data used for vowel inventories is approximate (binned categories).
- Phoneme inventory medians vary by source (UPSID vs WALS vs Phoible).
- Cognitive science constants (Cowan's 4, dual process) have uncertainty ranges.
- Ebbinghaus curve model choice (exponential vs power law) affects the 1/e claim.
- All "exact matches" to small integers (2, 4, 6) suffer from the strong law
  of small numbers: there are more interesting properties than small numbers.

## Verification Direction

This domain appears to be a dead end for the n=6 framework. Potential
follow-ups if desired:

1. Test whether the DISTRIBUTION of word orders follows a Boltzmann-like
   model with temperature parameter related to GZ (rather than just counting 6).
2. Test whether the 87:13 subject-first vs object-first ratio in word orders
   relates to any n=6 ratio.
3. Investigate whether neural oscillation frequencies during language processing
   show n=6 structure (this would be neuroscience, not linguistics per se).
