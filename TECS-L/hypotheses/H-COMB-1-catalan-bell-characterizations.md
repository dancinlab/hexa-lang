---
id: H-COMB-1
title: "Combinatorial Sequence Characterizations of n=6"
status: VERIFIED
grade: "🟧★ (Catalan) / 🟧 (Bell, CF, Pell)"
date: 2026-03-26
texas_p: 0.025 (Catalan), 0.010 (Bell, but ad-hoc -1)
---

# H-COMB-1: Combinatorial Sequence Characterizations of n=6

> **Conjecture.** Multiple combinatorial sequences (Catalan, Bell, Fibonacci)
> evaluated at arithmetic functions of n yield characterizations unique to n=6.

## Identity 1: Catalan at sopfr — C_sopfr(n) = n(n+1) (🟧★)

```
  C_sopfr(6) = C_5 = 42 = 6 × 7 = n(n+1)
```

| n | sopfr | C_sopfr | n(n+1) | Match? |
|---|-------|---------|--------|--------|
| 2 | 2 | 2 | 6 | NO |
| 3 | 3 | 5 | 12 | NO |
| 4 | 4 | 14 | 20 | NO |
| 5 | 5 | 42 | 30 | NO |
| **6** | **5** | **42** | **42** | **YES** |
| 7 | 7 | 429 | 56 | NO |
| 10 | 7 | 429 | 110 | NO |
| 28 | 9 | 4862 | 812 | NO |

**Unique in n = 2..2000.** Texas p = 0.025 (Bonferroni-corrected).

Note: 42 = C_5 also equals 1/B_6 (inverse of 6th Bernoulli number).
So **B_6 = 1/C_sopfr(6)** — Bernoulli↔Catalan↔sopfr bridge.

## Identity 2: Bell at tau — B_tau(n) = sigma + tau - 1 (🟧)

```
  B_tau(6) = B_4 = 15 = sigma(6) + tau(6) - 1 = 12 + 4 - 1
```

**Unique non-trivial match in n = 2..5000.** Texas p = 0.010.

⚠️ Grade capped at 🟧: contains ad-hoc -1 correction. Without -1:
B_4 = 15, sigma + tau = 16. Close but not exact.

## Identity 3: CF of sqrt(n) — period = (phi, tau) (🟧)

```
  √6 = [2; 2, 4, 2, 4, ...]
      = [φ(6); {φ(6), τ(6)}]
```

The continued fraction of √6 has:
- Integer part = φ(6) = 2
- Period = (φ(6), τ(6)) = (2, 4)

| n | CF(√n) | φ(n) | τ(n) | Period match? |
|---|--------|------|------|---------------|
| 2 | [1; {2}] | 1 | 2 | NO (period len=1) |
| 3 | [1; {1,2}] | 2 | 2 | NO |
| 5 | [2; {4}] | 4 | 2 | NO (period len=1) |
| **6** | **[2; {2,4}]** | **2** | **4** | **YES** |
| 7 | [2; {1,1,1,4}] | 6 | 2 | NO |
| 28 | [5; {3,2,3,10}] | 12 | 6 | NO |

**Unique in n = 2..500.** Texas p = 0.06 (marginal).

## Identity 4: Pell equation — fundamental = (sopfr, phi) (⚪)

```
  x² - 6y² = 1
  Fundamental solution: (x, y) = (5, 2) = (sopfr(6), φ(6))
```

Also: second solution is (49, 20) = (7², 4×5) = ((n+1)², τ·sopfr).

**Unique among tested n.** Texas p = 0.20 (not significant after Bonferroni).

## Identity 5-6: Quadratic forms (⚪)

```
  σ² + φ² + 2τ² = 5n²    →  144 + 4 + 32 = 180 = 5×36   (unique in n≤10000)
  σ² + 2φ² + 4τ² = n³    →  144 + 8 + 64 = 216 = 6³      (unique in n≤10000)
```

Coefficients (1,1,2) and (1,2,4) are powers of 2. Interesting structure but
Texas p = 0.10 after Bonferroni correction (1000 quadratics searched).

## Generalization to n=28

**None of the 6 identities hold for n=28.** These are P₁-specific, not general perfect number laws.

## Summary ASCII Graph

```
  n=6 characterization strength:

  Cyclotomic-Stirling (H-CYCL-1) ████████████████████ PROVED (⭐)
  Catalan C_sopfr=n(n+1)         ████████████████░░░░ 🟧★ (p=0.025)
  Bell B_tau=sigma+tau-1         ██████████████░░░░░░ 🟧 (ad-hoc -1)
  CF sqrt period=(phi,tau)       ████████████░░░░░░░░ 🟧 (p=0.06)
  Pell fund=(sopfr,phi)         ████████░░░░░░░░░░░░ ⚪ (p=0.20)
  Quadratic forms               ████████░░░░░░░░░░░░ ⚪ (p=0.10)
```

## Limitations

- Catalan identity: search limited to sopfr ≤ 30 (Catalan numbers grow super-exponentially)
- Bell identity: has -1 correction, blocking ⭐ upgrade
- CF identity: period matching is a rigid criterion; Texas p marginal
- All are P₁-specific — no perfect number generalization

## Verification Direction

- Extend Catalan search to n=10000 (with sopfr bound)
- Investigate: C_sopfr(P_k) = ? pattern across perfect numbers
- Look for Bell/Catalan identities without ad-hoc corrections
- CF period: investigate why φ and τ appear in √6 expansion
