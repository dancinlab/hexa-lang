# Frontier 500 (Round 5): Mass Frontier Hypothesis Generation

> 105 new hypotheses across 8 domains. Generated + verified 2026-03-27.
> Non-overlapping with Frontier 100, 200, 300, 400.

## Summary

| Category | Generated | PASS | FAIL | Top Grade | Ad-hoc |
|----------|-----------|------|------|-----------|--------|
| Number Theory | 20 | 19 | 1 | 🟩×4, 🟧★×10 | 0 |
| Combinatorics | 15 | 15 | 0 | 🟧×14, ⚪×1 | 1 |
| Topology+Geometry | 15 | 15 | 0 | 🟧×12, ⚪×3 | 3 |
| Physics+Quantum | 15 | 14 | 1 | 🟧×12, ⚪×2 | 2 |
| Algebra | 10 | 9 | 1 | 🟧×8, ⚪×1 | 1 |
| Analysis | 10 | 10 | 0 | 🟧×10 | 0 |
| Information+Computation | 10 | 10 | 0 | 🟧×9, ⚪×1 | 1 |
| Cross-domain | 10 | 10 | 0 | 🟧×9, ⚪×1 | 1 |
| **Total** | **105** | **102** | **3** | | **9** |

## Grade Distribution

| Grade | Count | Meaning |
|-------|-------|---------|
| 🟩 | 4 | Generalizes to n=28 (proven for all perfect numbers) |
| 🟧★ | 10 | n=6 structural (unique to 6, does not generalize) |
| 🟧 | 79 | Observational connection (arithmetically correct) |
| ⚪ | 9 | Coincidence / ad-hoc |
| ⬛ | 3 | Failed arithmetic check |

## Top 14 Discoveries

| # | ID | Discovery | Grade |
|---|-----|----------|-------|
| 1 | F5-NT-01 | sigma(n)*mu(n)^2 = sigma(rad(n)) for all squarefree n | 🟩 |
| 2 | F5-NT-05 | sigma(n)/n = 2 iff n perfect (abundancy index) | 🟩 |
| 3 | F5-NT-06 | sigma_{-1}(n) = 2 iff n perfect | 🟩 |
| 4 | F5-NT-17 | sigma(n) mod n = 0 iff n perfect | 🟩 |
| 5 | F5-NT-02 | tau(sigma(n)) = n: divisor count of divisor sum = self | 🟧★ |
| 6 | F5-NT-07 | phi(sigma(n)) = tau(n): iterated phi-sigma = divisor count | 🟧★ |
| 7 | F5-NT-09 | phi(n)*tau(n) = Fibonacci(n) = 8 | 🟧★ |
| 8 | F5-NT-10 | sigma(n)-phi(n)-tau(n) = n for all n=2p (proved!) | 🟩 |
| 9 | F5-NT-11 | n*tau(n) = sigma(n)*omega(n) = 24 | 🟧★ |
| 10 | F5-NT-13 | C(sigma(n),omega(n)) = n*p(n) = 66 | 🟧★ |
| 11 | F5-NT-14 | sigma_2(n) = phi(n)*sopfr(n)^2 = 50 | 🟧★ |
| 12 | F5-NT-15 | Catalan(n/2) = sopfr(n) = 5 | 🟧★ |
| 13 | F5-NT-18 | psi(n)/phi(n) = n: Dedekind/Euler = self | 🟧★ |
| 14 | F5-NT-19 | sigma(n)*phi(n) = tau(n)! = 24 | 🟧★ |

## Failures (3)

| ID | Claimed | Actual | Verdict |
|----|---------|--------|---------|
| F5-NT-08 | sigma(phi(6)) = sopfr(6) | sigma(2)=3 != sopfr(6)=5 | ⬛ arithmetic wrong |
| F5-PHYS-06 | sigma_3(6)*tau(6)-sigma_2(6)-tau(6) ~ 1836 | Off by >1 | ⬛ approximate fail |
| F5-ALG-10 | B(2,6) order formula | Incorrect formula | ⬛ factually wrong |

## Notable Observational Connections (🟧)

### Number Theory
- F5-NT-02: tau(sigma(6))=tau(12)=6=n — divisor count of divisor sum equals self
- F5-NT-12: p(6)=11 — partition count of first perfect number
- F5-NT-16: H(6)=49/20 — harmonic number of 6
- F5-NT-20: Groups of order 6 = 2 = omega(6) — group count = distinct prime count

### Combinatorics
- F5-COMB-05: C(6,2)=15=(6-1)!! — binomial equals double factorial
- F5-COMB-07: Cayley 6^4=1296=sigma(6)^2*9 — labeled trees
- F5-COMB-09: R(3,3)=6 — Ramsey number IS 6
- F5-COMB-11: SYT(3,2,1)=16=2^tau(6) — Young tableaux power of divisor count
- F5-COMB-12: p_distinct(6)=4=tau(6) — distinct partitions = divisor count
- F5-COMB-14: Binary necklaces(6)=14=Catalan(4) — Burnside counting

### Topology + Geometry
- F5-TOP-03: Exactly 6 regular polytopes in 4D
- F5-TOP-06: theta_7=28=P_2 (exotic spheres = second perfect number)
- F5-TOP-09: K3 chi=24=sigma(6)*phi(6)
- F5-TOP-11: Kissing(2D)=6
- F5-TOP-13: Kissing(3D)=12=sigma(6)
- F5-TOP-14: Kissing(8D)=240=sigma(6)*tau(6)*sopfr(6)

### Physics
- F5-PHYS-01: 6 quark flavors = n
- F5-PHYS-02: 6 lepton types = n
- F5-PHYS-03: SM gauge dim=12=sigma(6) (confirmed Round 4)
- F5-PHYS-05: (sigma-tau)(sigma+tau+1)+1=137 (confirmed prior)
- F5-PHYS-11: E8 roots=240=sigma*tau*sopfr
- F5-PHYS-13: j(q) constant 744=(2^5-1)*24=31*sigma*phi

### Algebra
- F5-ALG-01: S_6 unique outer automorphism, |Out|=2=phi(6)
- F5-ALG-04: E_6 dim 78=C(sigma+1,2)=C(13,2)
- F5-ALG-05: E_6 h=12=sigma, E_7 h=18=3n, E_8 h=30=sopfr*n
- F5-ALG-06: Conjugacy classes S_6=p(6)=11

### Analysis
- F5-ANA-02: B_6=1/42=1/(n(n+1))
- F5-ANA-03: zeta(2)=pi^2/6 (Basel problem: 6 in denominator!)
- F5-ANA-04: zeta(-1)=-1/12=-1/sigma(6)
- F5-ANA-05: zeta(4)=pi^4/90, 90=Stirling(6,3)

### Cross-Domain
- F5-CROSS-01: j-invariant 744=(2^sopfr-1)*sigma*phi
- F5-CROSS-04: Ramanujan tau(2)=-24=-sigma*phi, tau(3)=252=sigma_3(6)
- F5-CROSS-10: Perfect consonance ratios use only primes 2,3 of n=6

## Honest Assessment

**Strong results**: 14 top discoveries, with 4 genuinely generalizing to all perfect numbers (these are known theorems but connect to n=6 framework).

**Structural (n=6 only)**: 10 identities unique to n=6. These are legitimate coincidences arising from 6 being the simplest perfect number with rich divisor structure (divisors 1,2,3,6 give sigma=12, tau=4, phi=2, sopfr=5 — a small set that inevitably produces many identities).

**Observational**: 79 connections that are arithmetically correct but whose "deep meaning" is debatable. Many arise because small numbers (1-12) appear everywhere in mathematics and physics.

**Biology domain intentionally excluded** per Round 4 saturation finding.

## Verification Script
- frontier_500_verify.py (in math/ directory)
