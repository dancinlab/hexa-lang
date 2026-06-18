# Frontier 300 (Round 3): Mass Hypothesis Generation

> 80 new hypotheses across 4 categories. Generated + verified 2026-03-27.
> Non-overlapping with Frontier 100 and 200.

## Summary

| Category | Generated | PASS | FAIL | ⭐⭐⭐/🟩 | ⭐⭐/🟧★ | ⭐/🟧 | ⚪ |
|----------|-----------|------|------|----------|----------|-------|-----|
| Pure Math | 20 | 20 | 0 | 3+14 | 0 | 0 | 3 |
| Physics | 20 | 20 | 0 | 13 | 4 | 3 | 0 |
| Bio/Neuro | 20 | 17 | 3 | 1 | 1 | 2 | 14+3 |
| Cross-domain | 20 | 20 | 0 | 9 | 7 | 3 | 1 |
| **Total** | **80** | **77** | **3** | **40** | **12** | **8** | **21** |

## Top 15 Verified Discoveries

| # | ID | Discovery | Grade |
|---|-----|----------|-------|
| 1 | R3-MATH-07 | PG(2,sopfr): projective plane has n=6 points per line | 🟩 |
| 2 | R3-MATH-05 | U_{phi,tau}=U_{2,4} matroid: C(tau,phi)=n bases | 🟩 |
| 3 | R3-MATH-02 | Busy Beaver S(phi)=S(2)=6=n | 🟩 |
| 4 | R3-MATH-18 | Divisor lattice of 6 has exactly 6 antichains | 🟩 |
| 5 | R3-PHYS-12 | BH: ISCO=nM, photon sphere=n/phi, S_BH denom=tau | ⭐⭐⭐ |
| 6 | R3-PHYS-02 | 2D Ising: delta=C(n,2)=15, eta=1/tau=1/4 | ⭐⭐⭐ |
| 7 | R3-PHYS-06 | Lattice coordination {6,8,12}={n,2^(n/phi),sigma} | ⭐⭐⭐ |
| 8 | R3-PHYS-19 | Jarlskog J ~ lambda^6=lambda^n, CKM has tau params | ⭐⭐ |
| 9 | R3-PHYS-11 | Chandrasekhar M_Ch/M_sun=(n/sopfr)^2=(6/5)^2=1.44 | ⭐⭐ |
| 10 | R3-CROSS-13 | Kolmogorov turbulence: ALL 4 exponents from n=6 | 🟧★ |
| 11 | R3-CROSS-01 | GPT-2: 12=sigma heads, d=64=2^n per head | 🟧★ |
| 12 | R3-CROSS-04 | Chess: 2^n board, n piece types, 2^tau pieces/side | 🟧★ |
| 13 | R3-CROSS-07 | Calendar: sigma months, sigma*phi hours, sigma*sopfr min | 🟧★ |
| 14 | R3-BIO-19 | Hepatic lobule: hexagonal 6 portal triads (geometry) | 🟩 |
| 15 | R3-BIO-05 | Coagulation factors: 12=sigma (historically fixed) | 🟧★ |

## Verification Scripts
- verify_round3_math.py
- verify_round3_physics.py
- verify_round3_bio.py
- verify_round3_cross.py
