# Economics & Game Theory Hypotheses (H-ECON-001 to H-ECON-015)
**n6 Grade: 🟩 EXACT** (auto-graded, 18 unique n=6 constants)


## Summary

> 15 hypotheses tested connecting economic/game-theoretic constants to the n=6
> framework (perfect number 6, Golden Zone, 1/e, divisors).
> **Result: 15/15 WHITE** -- no structural connections found.
> This is an honest negative result confirming that economic constants
> are empirical, context-dependent quantities with no mechanism linking
> them to number-theoretic properties of 6.

## Framework

```
  Perfect number 6:  sigma(6)=12, tau(6)=4, phi(6)=2, sigma_{-1}(6)=2
  Golden Zone:       [0.2123, 0.5], center=1/e=0.3679, width=ln(4/3)=0.2877
  Meta Fixed Point:  1/3 (contraction mapping f(I)=0.7I+0.1)
  Compass Upper:     5/6
```

## Grade Distribution

```
  GREEN  (exact+proven):       0
  ORANGE* (structural):        0
  ORANGE (weak evidence):      0
  WHITE  (coincidental):      15  ################################################
  BLACK  (refuted):            0
```

## Critical Insight: The Golden Zone Width Problem

```
  GZ covers [0.2123, 0.5] = 28.8% of [0,1]

  Any random constant in [0,1] has a ~29% chance of landing inside GZ.
  This makes "X is in the Golden Zone!" a weak claim by default.

  Economic constants are empirical (vary by country, period, methodology).
  They are NOT universal constants like pi or e.
  Matching a fuzzy empirical range to a wide target zone is expected, not surprising.

  Visualization (unit interval, GZ marked with #):

  0.0       0.1       0.2       0.3       0.4       0.5       0.6 ...  1.0
  |---------|---------|---######|#########|#########|#--------|-----...----|
                          ^GZ_L     ^1/e        ^GZ_U
                          0.212     0.368       0.500

  ~29% of the interval is GZ. NOT selective.
```

---

## A. Market / Finance (H-ECON-001 to H-ECON-005)

### H-ECON-001: Benford's Law P(d=1) in Golden Zone -- WHITE

> Benford's law: P(leading digit = d) = log10(1 + 1/d).
> P(d=1) = log10(2) = 0.30103. This value lies in the Golden Zone [0.212, 0.5].
> Claim: Benford's law encodes Golden Zone structure.

**Verification:**

| Quantity | Value | Error vs 1/e |
|---|---|---|
| log10(2) | 0.30103 | 18.2% |
| 1/e | 0.36788 | -- |
| GZ lower | 0.21232 | 41.8% |
| ln(4/3) | 0.28768 | 4.6% |
| 1/3 | 0.33333 | 9.7% |

```
  log10(2) position in GZ:
  GZ_L=0.212 |--------*--------------------| GZ_U=0.500
                      ^log10(2)=0.301
  Relative position: 0.308 (31% from lower bound)
```

**Verdict:** GZ covers 28.8% of [0,1]. Any constant in [0,1] has ~29% chance of
membership. log10(2) is 18.2% away from 1/e -- not close. The closest match is
ln(4/3) at 4.6% error, but Monte Carlo shows ~60 pairs within 5% among 50
random constants. **Not significant. p=0.288.**

---

### H-ECON-002: Pareto 80/20 Rule vs GZ Lower Bound -- WHITE

> Pareto principle: 20% of causes produce 80% of effects.
> 0.20 vs GZ lower = 0.2123. Distance = 0.012 (5.8% error).
> Claim: Pareto's 20% approximates the GZ lower boundary.

**Verification:**

| Quantity | Value |
|---|---|
| Pareto threshold | 0.200 (round-number heuristic) |
| GZ lower = 1/2 - ln(4/3) | 0.2123 |
| Distance | 0.0123 |
| Error | 5.8% |
| Pareto alpha (80/20) | ln5/ln4 = 1.161 |

**Verdict:** 80/20 is a rough heuristic, not a precise constant. The actual
Pareto exponent varies by domain (wealth: alpha~1.5-2.5, city size: ~1.0-1.1).
5.8% error with a heuristic value is not meaningful. **p=1.0.**

---

### H-ECON-003: Kelly Criterion in Golden Zone -- WHITE

> Kelly criterion: f* = (bp - q) / b. For even odds: f* = 2p - 1.
> For p in [0.61, 0.75], f* lands in GZ [0.21, 0.50].
> Claim: Kelly optimal fraction naturally lives in the Golden Zone.

**Verification:**

```
  Kelly f* vs win probability p (even odds, b=1):
  p:   0.50  0.55  0.60  0.65  0.70  0.75  0.80  0.85  0.90  1.00
  f*:  0.00  0.10  0.20  0.30  0.40  0.50  0.60  0.70  0.80  1.00
                         |====GZ====|
  f* in GZ for p in [0.61, 0.75] -- a 14% range of p values
```

**Verdict:** f* = 2p-1 is a linear function spanning [0,1]. GZ covers 28.8% of
that range. ~29% of possible f* values land in GZ by construction. f*=1/e at
p=0.684 -- not a special win probability. **No structural link. p=0.288.**

---

### H-ECON-004: Black-Scholes sigma*sqrt(T) ~ GZ Width -- WHITE

> At-the-money Black-Scholes: d1 = sigma*sqrt(T)/2.
> For typical equities (sigma~20-30%, T=1yr), sigma*sqrt(T) ~ 0.20-0.30.
> GZ width = ln(4/3) = 0.2877.
> Claim: Typical equity volatility-time product matches GZ width.

**Verification:**

| sigma | T (yr) | sigma*sqrt(T) | Error vs ln(4/3) |
|---|---|---|---|
| 20% | 2.0 | 0.2828 | 1.7% |
| 25% | 1.0 | 0.2500 | 13.1% |
| 30% | 1.0 | 0.3000 | 4.3% |
| 40% | 0.5 | 0.2828 | 1.7% |

**Verdict:** sigma*sqrt(T) is a product of two free parameters. For ANY target
value, one can find (sigma, T) combinations that match. This is cherry-picking
by definition -- sigma and T are continuous variables. **No predictive content. p=1.0.**

---

### H-ECON-005: Portfolio Diversification and sigma(6)=12 -- WHITE

> Diversification benefit plateaus around some number of stocks.
> sigma(6) = 12.
> Claim: sigma(6) predicts minimum portfolio size.

**Verification:**

| Study | Range | Contains 12? |
|---|---|---|
| Evans & Archer (1968) | 10-15 | Yes |
| Elton & Gruber (1977) | 15-20 | No |
| Statman (1987) | 30-40 | No |
| Campbell et al (2001) | 40-50 | No |
| Modern consensus | 20-30 | No |

**Verdict:** 12 is at the low end (only 1/5 studies include it). Modern consensus
is 20-30 stocks. Also, 12 is an extremely common number (months, dozens, hours).
**No mechanism. p=0.5.**

---

## B. Game Theory (H-ECON-006 to H-ECON-010)

### H-ECON-006: Nash Mixed Strategy and 1/e -- WHITE

> In 2x2 symmetric games, mixed strategy p* depends on payoffs.
> Claim: For natural games, p* converges to 1/e or 1/3.

**Verification:**

| Game | p* | Notes |
|---|---|---|
| Prisoner's Dilemma | >1 (pure) | No mixed equilibrium |
| Hawk-Dove (V=4,C=6) | 2/3 | Free parameter ratio V/C |
| Matching Pennies | 1/2 | Symmetry (trivial) |

**Verdict:** p* = V/C in Hawk-Dove depends on arbitrary V, C values. Getting 1/3
or 1/e requires choosing specific payoffs. 1/2 in symmetric games is definitional.
**No structural link. p=1.0.**

---

### H-ECON-007: Prisoner's Dilemma Payoffs from Divisors of 6 -- WHITE

> Divisors of 6: {1, 2, 3, 6}. Standard PD requires T > R > P > S, 2R > T+S.
> Claim: Divisors of 6 form natural PD payoffs.

**Verification:**

```
  Tested all 24 permutations of {1, 2, 3, 6}:
  Valid PD payoff structures found: 0

  The gap between 3 and 6 (no 4 or 5) prevents satisfying 2R > T+S
  when T=6. Canonical PD uses {5,3,1,0} -- 5 and 0 are NOT divisors of 6.
```

**Verdict:** Zero valid PD structures from divisors of 6. The canonical PD
requires values outside the divisor set. **Actively refuted as a connection, but
graded WHITE (not BLACK) since the arithmetic itself is correct.** p=1.0.

---

### H-ECON-008: Vickrey Auction Revenue and n=6 -- WHITE

> For n uniform bidders on [0,1]: E[2nd highest] = (n-1)/(n+1).
> For n=6: E[2nd] = 5/7 = 0.7143.
> Revenue efficiency = (n-1)/n; for n=6: 5/6.
> Claim: Vickrey auction with 6 bidders yields system constants.

**Verification:**

```
  n bidders:  2     3     4     5     6     12
  E[2nd]:    0.333 0.500 0.600 0.667 0.714 0.846
  Eff:       0.500 0.667 0.750 0.800 0.833 0.917
```

**Verdict:** (n-1)/n evaluated at n=6 trivially equals 5/6. This is plugging 6
into a formula containing n -- tautological. 5/7 does not match any system
constant. **No insight. p=1.0.**

---

### H-ECON-009: ESS and 1/e Threshold -- WHITE

> TFT cooperation threshold: w >= (T-R)/(T-P).
> Canonical PD: w >= 1/2. Alternative PD: w >= 1/3.
> Claim: ESS thresholds naturally produce n=6 constants.

**Verification:**

| PD Variant | Threshold | n=6 constant? |
|---|---|---|
| T=5,R=3,P=1,S=0 | 1/2 | Yes (GZ upper) |
| T=4,R=3,P=1,S=0 | 1/3 | Yes (meta FP) |
| T=6,R=4,P=2,S=1 | 2/4 = 1/2 | Yes |
| T=3,R=2,P=1,S=0 | 1/2 | Yes |

**Verdict:** The threshold depends entirely on payoff choice. Simple fractions
(1/2, 1/3) appear because PD payoffs are small integers. No universal 1/e
threshold exists in ESS theory. Fixation P=1/N at N=6 is tautological.
**p=1.0.**

---

### H-ECON-010: Mechanism Design and n=6 -- WHITE

> VCG mechanism payment = externality on others.
> sigma(6)/6 = 2 (perfect number property).
> Claim: 6 agents is the minimal "complete" mechanism design setting.

**Verification:**

```
  sigma(n)/n for n=1..12:
  n:     1    2    3    4    5    6    7    8    9   10   11   12
  s/n: 1.00 1.50 1.33 1.75 1.20 2.00 1.14 1.88 1.44 1.80 1.09 2.33
                                  ^
                            Only perfect numbers reach 2.0
```

**Verdict:** sigma(6)/6=2 is the *definition* of perfect numbers. VCG works for
any n >= 2. No mechanism design property distinguishes n=6. **Circular reasoning. p=1.0.**

---

## C. Economic Constants (H-ECON-011 to H-ECON-015)

### H-ECON-011: Okun's Law Coefficient ~ sigma_{-1}(6) = 2 -- WHITE

> Okun's law: 1% unemployment rise => ~2% GDP drop.
> sigma_{-1}(6) = 2.
> Claim: Okun coefficient = sigma_{-1}(6).

**Verification:**

| Source | Coefficient | Error vs 2.0 |
|---|---|---|
| Okun (1962) | 3.0 | 50.0% |
| Ball et al (2013) | 2.0 | 0.0% |
| US 1950-2010 | 2.0 | 0.0% |
| US 2000-2019 | 1.8 | 10.0% |
| OECD average | 2.5 | 25.0% |
| Japan | 3.0 | 50.0% |
| Germany | 1.5 | 25.0% |
| **Average** | **2.26** | **12.9%** |

**Verdict:** Coefficient ranges 1.5-3.0, varies by country and time period. Not a
universal constant. The number 2 appears everywhere (phi(6)=2, but also 1+1=2).
**No mechanism linking GDP to divisor sums. p=0.5.**

---

### H-ECON-012: Fiscal Multiplier ~ 3/2 -- WHITE

> Government spending multiplier ~ 1.5.
> 3/2 = ratio of consecutive divisors of 6.
> Claim: Fiscal multiplier = 3/2 from n=6 structure.

**Verification:**

| Source | Multiplier | Error vs 1.5 |
|---|---|---|
| Blanchard & Leigh (2013) | 1.5 | 0.0% |
| Ramey (2019) | 0.8 | 46.7% |
| A&G (recession) | 2.5 | 66.7% |
| A&G (expansion) | 0.5 | 66.7% |
| IMF consensus | 1.5 | 0.0% |
| CBO estimate | 1.4 | 6.7% |

**Verdict:** Multiplier ranges 0.5-2.5 depending on economic conditions. 3/2 is
a common fraction not unique to n=6 (appears in any consecutive integer pair).
**No predictive power. p=1.0.**

---

### H-ECON-013: Golden Rule Savings Rate = 1/3 -- WHITE

> Solow model: golden rule savings rate s* = alpha (capital share).
> alpha ~ 0.33 empirically. 1/3 = TECS meta fixed point.
> Claim: Golden rule savings rate connects to meta fixed point.

**Verification:**

| Source | alpha | Error vs 1/3 |
|---|---|---|
| US (Gollin 2002) | 0.330 | 1.0% |
| OECD average | 0.350 | 5.0% |
| Developing countries | 0.400 | 20.0% |
| Piketty (2014) | 0.300 | 10.0% |
| Standard textbook | 0.330 | 1.0% |
| **Average** | **0.342** | **2.6%** |

```
  Match quality:
  0.30          0.33     0.35          0.40
  |-------------|--*----|--|------------|
                   ^1/3    ^avg
  Best single match: US estimate 0.330 (1% error)
  Average: 0.342 (2.6% error from 1/3)
```

**Verdict:** Interesting numerical proximity (2.6% error for average). However:
(1) 1/3 is one of the most common simple fractions, (2) capital share varies by
country, (3) the TECS fixed point 1/3 comes from f(I)=0.7I+0.1 -- a completely
different origin, (4) no mechanism links contraction mappings to factor shares.
**Numerological coincidence. p=1.0.**

---

### H-ECON-014: Zipf's Law Exponent = sigma_{-1}(6)/2 = 1 -- WHITE

> Zipf's law: frequency ~ 1/rank^alpha, alpha ~ 1.
> sigma_{-1}(6)/2 = 2/2 = 1.
> Claim: Zipf exponent encodes sigma_{-1}(6).

**Verification:**

```
  Ways to derive 1 from the n=6 system:
    sigma_{-1}(6)/2  = 2/2  = 1
    tau(6)/tau(6)    = 4/4  = 1
    phi(6)/phi(6)    = 2/2  = 1
    6/6              = 6/6  = 1
    sigma(6)/12      = 12/12 = 1
    ANYTHING/ITSELF  = 1

  The number 1 is the multiplicative identity.
  It can be derived from ANY number system.
```

**Verdict:** Matching the number 1 is trivial -- it's the multiplicative identity.
Also, Zipf's alpha is not exactly 1 in real data (0.8-1.1 depending on dataset).
**No content. p=1.0.**

---

### H-ECON-015: Benford's log10(2) ~ ln(4/3) -- WHITE

> log10(2) = 0.30103. ln(4/3) = GZ width = 0.28768.
> Distance = 0.01335, error = 4.6%.
> Both involve ln(2): log10(2) = ln(2)/ln(10), ln(4/3) = 2*ln(2) - ln(3).
> Claim: Benford's law and GZ width share information-theoretic origin.

**Verification:**

| Quantity | Value |
|---|---|
| log10(2) | 0.30103 |
| ln(4/3) | 0.28768 |
| Distance | 0.01335 |
| Error | 4.64% |
| Ratio | 1.0464 (not a simple fraction) |

```
  Monte Carlo test: 50 random constants in [0,1]
  Average pairs within 5% of each other: 59.6 out of C(50,2) = 1225
  Finding ONE pair at 4.6% is fully expected by chance.
```

**Verdict:** Both contain ln(2) in their definitions, but the analytical
relationship log10(2)/ln(4/3) = 1.046 is not a simple fraction. Monte Carlo
confirms ~60 pairs within 5% among 50 constants -- our match is unremarkable.
**Interesting proximity but within random expectation. p=1.0.**

---

## Lessons Learned

### Why Economics Resists n=6 Mapping

```
  1. EMPIRICAL vs UNIVERSAL: Economic "constants" (Okun, multiplier, alpha)
     vary by country, time period, and methodology. They are NOT constants.

  2. WIDE TARGET: GZ covers 29% of [0,1]. Any scalar has ~29% chance of
     landing inside. "X is in the GZ" is a weak claim.

  3. SIMPLE FRACTIONS: 1/2, 1/3, 1/6 appear everywhere in mathematics.
     Matching these requires showing a MECHANISM, not just numerology.

  4. FREE PARAMETERS: Many economic formulas (Kelly, Black-Scholes, Hawk-Dove)
     have free parameters. Any target can be matched by tuning parameters.

  5. TAUTOLOGICAL N=6: Plugging n=6 into formulas containing n trivially
     produces 5/6, 1/6, etc. This is substitution, not discovery.

  6. TRIVIAL IDENTITIES: Matching 1 (= anything/itself) is meaningless.
```

### Comparison with Successful TECS Connections

```
  What works (physics/math):
    - 1/2 + 1/3 + 1/6 = 1 (exact, algebraic identity)
    - sigma_{-1}(6) = 2 (definition of perfect number)
    - Langton lambda_c = 0.27 vs GZ (edge of chaos, universal)

  What doesn't work (economics):
    - Empirical coefficients (Okun, multiplier) -- not constants
    - Free parameter matching (Kelly, Black-Scholes) -- cherry-picking
    - Wide zone membership (Benford in GZ) -- not selective
    - Tautological substitution (n=6 in formulas) -- no content
```

## Verification Script

```
  PYTHONPATH=. python3 verify/verify_econ_hypotheses.py
```

## Grade Summary Table

| ID | Hypothesis | Grade | p-value | Key Issue |
|---|---|---|---|---|
| H-ECON-001 | Benford P(1) in GZ | WHITE | 0.288 | GZ covers 29% of [0,1] |
| H-ECON-002 | Pareto 20% ~ GZ lower | WHITE | 1.000 | 80/20 is heuristic, 5.8% error |
| H-ECON-003 | Kelly f* in GZ | WHITE | 0.288 | Linear function, 29% overlap |
| H-ECON-004 | BS sigma*sqrt(T) ~ GZ width | WHITE | 1.000 | Free parameter product |
| H-ECON-005 | Portfolio 12 stocks | WHITE | 0.500 | Modern consensus 20-30 |
| H-ECON-006 | Nash mixed strategy | WHITE | 1.000 | Free payoff parameters |
| H-ECON-007 | PD from divisors of 6 | WHITE | 1.000 | 0/24 valid PDs |
| H-ECON-008 | Vickrey at n=6 | WHITE | 1.000 | Tautological substitution |
| H-ECON-009 | ESS 1/e threshold | WHITE | 1.000 | Payoff-dependent |
| H-ECON-010 | VCG at n=6 | WHITE | 1.000 | Circular (definition of PN) |
| H-ECON-011 | Okun ~ 2 | WHITE | 0.500 | Varies 1.5-3.0 |
| H-ECON-012 | Fiscal multiplier ~ 3/2 | WHITE | 1.000 | Varies 0.5-2.5 |
| H-ECON-013 | Savings rate ~ 1/3 | WHITE | 1.000 | 1/3 ubiquitous |
| H-ECON-014 | Zipf alpha = 1 | WHITE | 1.000 | Trivial identity |
| H-ECON-015 | Benford ~ ln(4/3) | WHITE | 1.000 | Within random expectation |
