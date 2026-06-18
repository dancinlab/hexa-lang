# Frontier 4: Cross-Domain Hypothesis Batch (90 hypotheses)

**Date:** 2026-03-27
**Domains:** analytic-NT, alg-geom, rep-theory, dynamical, info-theory, quantum-comp, cosmology, condensed-matter, biology, music
**Verified:** 22 GREEN + 3 ORANGE-STAR + 52 WHITE + 13 BLACK

---

## GREEN Verified (22)

### H-F4-003: Euler Product at Primes of 6 for zeta(2) = 3/2
- **Domain:** Analytic Number Theory
- **Formula:** prod_{p|6} 1/(1-p^{-2}) = (4/3)(9/8) = 3/2
- **Result:** EXACT. Known identity from partial Euler product of zeta(2) = pi^2/6, truncated at p=2,3.
- **Grade:** 🟩

### H-F4-004: Squarefree Divisor Count = tau(6)
- **Domain:** Analytic Number Theory
- **Formula:** sum_{d|6} mu(d)^2 = 4 = tau(6)
- **Result:** EXACT. Standard theorem: for squarefree n, all divisors are squarefree, so sum = tau(n).
- **Grade:** 🟩

### H-F4-006: Liouville Sum over Divisors = 0
- **Domain:** Analytic Number Theory
- **Formula:** sum_{d|6} lambda(d) = 0 (since 6 is not a perfect square)
- **Result:** EXACT. Classic identity: sum_{d|n} lambda(d) = 1 if n is a perfect square, 0 otherwise.
- **Grade:** 🟩

### H-F4-007: Dedekind psi(6) = 12 = sigma(6)
- **Domain:** Analytic Number Theory
- **Formula:** psi(6) = 6 * prod_{p|6} (1 + 1/p) = 6 * (3/2)(4/3) = 12 = sigma(6)
- **Result:** EXACT. Dedekind psi equals divisor sum for n=6. Does not hold in general (e.g. psi(12)=24 != sigma(12)=28). Characterization candidate.
- **Grade:** 🟩

### H-F4-008: Jordan J_2(6) = 24 = 2*sigma(6)
- **Domain:** Analytic Number Theory
- **Formula:** J_2(6) = 6^2 * prod_{p|6} (1 - 1/p^2) = 36 * (3/4)(8/9) = 24
- **Result:** EXACT. J_2(6) = 2*sigma(6) = 2*12 = 24. Relates higher totient to divisor sum.
- **Grade:** 🟩

### H-F4-010: Mean sigma(d) for d|6 = 5 = sopfr(6)
- **Domain:** Analytic Number Theory
- **Formula:** (1/tau(6)) * sum_{d|6} sigma(d) = (1/4)(1+3+4+12) = 20/4 = 5 = sopfr(6)
- **Result:** EXACT. Average divisor sum over divisors of 6 equals sum of prime factors (2+3=5). Nontrivial coincidence.
- **Grade:** 🟩

### H-F4-012: Genus of X_0(6) = 0
- **Domain:** Algebraic Geometry
- **Formula:** g(X_0(6)) = 0 (modular curve of level 6 is genus zero)
- **Result:** EXACT. X_0(6) is rational. Level 6 is among the 15 levels where X_0(N) has genus 0.
- **Grade:** 🟩

### H-F4-018: Fermat x^6 + y^6 = 1 Rational Points = 4 = tau(6)
- **Domain:** Algebraic Geometry
- **Formula:** |{(x,y) in Q^2 : x^6 + y^6 = 1}| = 4 = tau(6)
- **Result:** EXACT. The 4 trivial points (+-1,0),(0,+-1). No nontrivial rational points by Fermat's Last Theorem (n=6 > 2).
- **Grade:** 🟩

### H-F4-021: p(6) = 11 = Number of Irreps of S_6
- **Domain:** Representation Theory
- **Formula:** p(6) = 11 = |Conj(S_6)| = number of irreducible representations of S_6
- **Result:** EXACT. Partitions of n biject with conjugacy classes and irreps of S_n. Standard.
- **Grade:** 🟩

### H-F4-022: dim(Standard Rep of S_6) = 5 = sopfr(6)
- **Domain:** Representation Theory
- **Formula:** dim(V_std) = 6 - 1 = 5 = sopfr(6)
- **Result:** EXACT. Standard representation always has dim n-1. For n=6: n-1 = sopfr(6) = 2+3. Coincidental match.
- **Grade:** 🟩

### H-F4-023: Conjugacy Classes of A_6 = 7 = tau + phi + 1
- **Domain:** Representation Theory
- **Formula:** |Conj(A_6)| = 7 = tau(6) + phi(6) + 1 = 4 + 2 + 1
- **Result:** EXACT. A_6 has 7 conjugacy classes (verified). The arithmetic decomposition tau+phi+1 is exact.
- **Grade:** 🟩

### H-F4-026: SYT of Shapes (6) and (1^6) = 2 = phi(6)
- **Domain:** Representation Theory
- **Formula:** |SYT((6))| + |SYT((1^6))| = 1 + 1 = 2 = phi(6)
- **Result:** EXACT. Trivial and sign representations each have 1 SYT. Sum = phi(6). Mild coincidence.
- **Grade:** 🟩

### H-F4-027: Plethysm s_2[s_3] Has 3 Terms = tau(6) - 1
- **Domain:** Representation Theory
- **Formula:** s_2[s_3] = s_{(6)} + s_{(4,2)} + s_{(2,2,2)}, 3 terms = tau(6) - 1
- **Result:** EXACT. Verified plethysm decomposition. Three irreducible components.
- **Grade:** 🟩

### H-F4-035: log(6) = log(2) + log(3)
- **Domain:** Information Theory
- **Formula:** log(6) = log(2) + log(3)
- **Result:** EXACT. Trivially true from log(ab) = log(a) + log(b). Included for completeness.
- **Grade:** 🟩

### H-F4-041: Shannon Entropy of Uniform Distribution over tau(6) = phi(6) bits
- **Domain:** Information Theory
- **Formula:** H(Uniform(tau(6))) = log2(4) = 2 = phi(6)
- **Result:** EXACT. H(Uniform(k)) = log2(k). For k=tau(6)=4: log2(4)=2=phi(6).
- **Grade:** 🟩

### H-F4-044: ceil(log2(6)) = 3 = tau(6) - 1 = sigma/tau
- **Domain:** Information Theory
- **Formula:** ceil(log2(6)) = 3 = tau(6) - 1 = sigma(6)/tau(6)
- **Result:** EXACT. 6 requires 3 bits. Multiple arithmetic expressions match.
- **Grade:** 🟩

### H-F4-045: Fisher Information for Poisson(6) = 1/6 = phi(6)/sigma(6)
- **Domain:** Information Theory
- **Formula:** I_Fisher(Poisson(lambda=6)) = 1/6 = phi(6)/sigma(6)
- **Result:** EXACT. Fisher info of Poisson(lambda) = 1/lambda. Ratio phi/sigma is a known quantity.
- **Grade:** 🟩

### H-F4-048: Rate-Distortion R(D) at D = tau - 1 = 1 bit
- **Domain:** Information Theory
- **Formula:** R(D=3) for Uniform(6) with Hamming distortion = max(log2(6)-log2(3), 0) = log2(2) = 1 bit
- **Result:** EXACT. At D=tau(6)-1=3, rate-distortion function evaluates to exactly 1 bit.
- **Grade:** 🟩

### H-F4-053: [[6,2,2]] Quantum Error-Correcting Code
- **Domain:** Quantum Computing
- **Formula:** [[n,k,d]] = [[6, phi(6), tau(6)/phi(6)]] = [[6, 2, 2]]
- **Result:** EXACT. The [[6,2,2]] code exists (smallest code detecting 1 error on 2 logical qubits). Parameters match arithmetic functions.
- **Grade:** 🟩

### H-F4-054: Quantum Walk on C_6 Spectral Gap = 1/2
- **Domain:** Quantum Computing
- **Formula:** Delta = 1 - cos(2*pi/6) = 1 - 1/2 = 1/2 = Golden Zone upper boundary
- **Result:** EXACT. Spectral gap of continuous-time quantum walk on cycle graph C_6 equals the Riemann critical line value.
- **Grade:** 🟩

### H-F4-076: Z_6 Torus Ground State Degeneracy = 36 = 6^phi(6)
- **Domain:** Condensed Matter
- **Formula:** GSD(Z_6 toric code on torus) = 6^2 = 36 = n^phi(n) for n=6
- **Result:** EXACT. Z_N toric code on torus has GSD = N^2. For N=6: 36 = 6^phi(6) since phi(6)=2.
- **Grade:** 🟩

### H-F4-090: (sigma - tau - phi) / tau = 3/2 = Perfect Fifth
- **Domain:** Music Theory
- **Formula:** (12 - 4 - 2) / 4 = 6/4 = 3/2
- **Result:** EXACT. The ratio 3/2 is the frequency ratio of the perfect fifth in just intonation. Arithmetic of n=6 produces a fundamental musical interval.
- **Grade:** 🟩

---

## ORANGE-STAR Structural (3)

### H-F4-058: 2-Qubit Stabilizer States = 60 = sopfr(6) * sigma(6)
- **Domain:** Quantum Computing
- **Formula:** |Stab_2| = 60 = 5 * 12 = sopfr(6) * sigma(6)
- **Result:** EXACT numerically. The number of 2-qubit stabilizer states is known to be 60. The factorization sopfr*sigma is nontrivial and connects quantum resource counting to divisor arithmetic.
- **Why ORANGE-STAR:** Exact match but potentially ad hoc decomposition. The factorization 60=5*12 has many representations. Needs broader context to confirm structural significance.
- **Grade:** 🟧★

### H-F4-069: Spectral Index n_s = 1 - 2/60 = 0.9667 (0.18% from Planck)
- **Domain:** Cosmology
- **Formula:** n_s = 1 - 2/(sopfr(6)*sigma(6)) = 1 - 2/60 = 29/30 = 0.96667
- **Result:** Planck measured n_s = 0.9649 +/- 0.0042. Our prediction 0.9667 is within 0.18% (well within 1-sigma).
- **Why ORANGE-STAR:** Remarkably close to observation. The e-folding number N=60 is standard in slow-roll inflation, and here it emerges as sopfr*sigma. If this decomposition has independent justification, this would be a major connection.
- **Grade:** 🟧★

### H-F4-075: sigma(6) / 6^phi(6) = 12/36 = 1/3 = Meta Fixed Point
- **Domain:** Condensed Matter
- **Formula:** sigma/n^phi = 12/36 = 1/3 = Meta Fixed Point (f(I)=0.7I+0.1 convergence)
- **Result:** EXACT. The ratio sigma/n^phi produces the contraction mapping fixed point 1/3. Connects Cooper pair physics (BCS denominator structure) to the system's meta fixed point.
- **Why ORANGE-STAR:** Exact arithmetic but the physical interpretation (Cooper pair ratio) needs deeper justification. The 1/3 emergence is structurally interesting.
- **Grade:** 🟧★

---

## WHITE Coincidence (52)

| ID | Domain | Statement | Why White |
|----|--------|-----------|-----------|
| H-F4-002 | Analytic NT | Ramanujan sum c_6(1) analogy | Tautological restatement of mu(6) |
| H-F4-009 | Analytic NT | Farey mediant F_6 density | Standard Farey sequence property, no n=6 specificity |
| H-F4-011 | Alg Geom | Hilbert scheme Hilb^6(C^2) irreducible | True for all n, not specific to 6 |
| H-F4-013 | Alg Geom | Elliptic curve E: y^2=x^3-x torsion Z/2 | Curve choice arbitrary, not intrinsic to 6 |
| H-F4-014 | Alg Geom | Grassmannian Gr(2,6) dim=8 | dim=k(n-k), coincidental match to sigma-tau |
| H-F4-015 | Alg Geom | del Pezzo degree 6 has 6 lines | Already recorded in H-TOP-8, duplicate |
| H-F4-016 | Alg Geom | Cubic surface 27 lines (27=sigma*phi+3) | Ad hoc formula with +3 correction |
| H-F4-017 | Alg Geom | Hurwitz genus 0 -> 2g-2 formula | Standard Riemann-Hurwitz, no 6-specific content |
| H-F4-019 | Dynamical | Logistic map period-6 window | Period-n windows exist for all n, not special |
| H-F4-020 | Dynamical | Arnold cat map period mod 6 | Modular periodicity varies, coincidental |
| H-F4-025 | Rep Theory | Exterior power dim C(6,2)=15 | Standard binomial coefficient, not deep |
| H-F4-028 | Rep Theory | Schur-Weyl duality for V^{tensor 6} | Holds for all n, not specific |
| H-F4-029 | Rep Theory | Kronecker coefficient for S_6 | Computational fact, no structural insight |
| H-F4-031 | Dynamical | Henon map fixed points | Not intrinsically related to n=6 |
| H-F4-033 | Dynamical | Circle map rotation number | Universal phenomenon, not 6-specific |
| H-F4-036 | Info Theory | Kolmogorov complexity K(6) ~ 7 bits | Approximate, no structural content |
| H-F4-037 | Info Theory | Channel capacity BSC(1/6) | Standard formula evaluation, tautological |
| H-F4-038 | Info Theory | Renyi entropy H_alpha(Uniform(6)) | Equals log(6) for all alpha, trivial |
| H-F4-039 | Info Theory | Min-entropy H_inf(dice) = log(6) | Uniform distribution, trivial |
| H-F4-040 | Info Theory | Mutual information I(X;Y) for joint | Depends on specific joint distribution chosen |
| H-F4-042 | Info Theory | Huffman coding 6-symbol | Optimal code properties, standard |
| H-F4-043 | Info Theory | Lempel-Ziv complexity of 123456 | Depends on specific string, arbitrary |
| H-F4-046 | Info Theory | KL divergence between two 6-distributions | Depends on chosen distributions |
| H-F4-047 | Info Theory | Maximum entropy with mean=sigma/tau | Exponential distribution, follows from constraint |
| H-F4-049 | Quantum Comp | 6-qubit stabilizer group size | Standard group theory, no surprise |
| H-F4-050 | Quantum Comp | Clifford group on 3 qubits | 3=tau-1, but tau-1 is just ceil(log2(6)) |
| H-F4-051 | Quantum Comp | Magic state count for 6 qubits | Exponential in n, no 6-specific structure |
| H-F4-052 | Quantum Comp | QFT circuit depth for 6 qubits | O(n^2) standard, coincidental numbers |
| H-F4-055 | Quantum Comp | Grover iterations for N=6 | Floor(pi/4 * sqrt(6)), standard formula |
| H-F4-056 | Quantum Comp | Entanglement entropy of 6-qubit state | Depends on specific state, not universal |
| H-F4-059 | Cosmology | Hubble constant H_0 ~ 70 km/s/Mpc | 70 != any clean function of 6 |
| H-F4-060 | Cosmology | Baryon-to-photon ratio eta | Order 10^{-10}, no connection |
| H-F4-061 | Cosmology | CMB temperature 2.725K | No clean arithmetic connection |
| H-F4-063 | Cosmology | BAO scale ~150 Mpc | No arithmetic connection |
| H-F4-066 | Cosmology | Reionization redshift z~6 | Coincidental number match |
| H-F4-067 | Cosmology | Dark energy equation of state w~-1 | Off by significant margin from any formula |
| H-F4-068 | Cosmology | Structure formation sigma_8 ~ 0.8 | No clean match |
| H-F4-071 | Condensed Matter | Phonon modes 3N = 18 | Trivial: 3*6=18, holds for any N |
| H-F4-072 | Condensed Matter | Anderson localization d=2 | Localization dimension, not specific to 6 |
| H-F4-073 | Condensed Matter | Hexagonal lattice coordination = 6 | Geometry, not arithmetic |
| H-F4-074 | Condensed Matter | Chern number C=1 for Haldane model | Model parameter choice, not intrinsic |
| H-F4-078 | Condensed Matter | Topological insulator Z_2 index | Binary classification, not 6-specific |
| H-F4-080 | Biology | Cranial nerves = 12 = sigma(6) | Anatomical coincidence, no mechanism |
| H-F4-081 | Biology | Thoracic vertebrae = 12 = sigma(6) | Anatomical coincidence, no mechanism |
| H-F4-082 | Biology | Codon length = 3 = tau-1 | Biochemistry, not arithmetic |
| H-F4-083 | Biology | Protein secondary structure types = 4 = tau | Approximate classification, arbitrary count |
| H-F4-084 | Biology | Kingdoms of life = 6 | Taxonomic convention, varies by system |
| H-F4-086 | Biology | Holographic bound S <= A/(4*l_P^2) | No 6-specific content |
| H-F4-087 | Biology | Genetic code redundancy 64/20 ~ 3.2 | Approximate, no exact match |
| H-F4-088 | Music | Chromatic scale = 12 = sigma(6) | Cultural convention, also 2^(7/12) ~ 3/2 known |
| H-F4-089 | Music | Hexatonic scale = 6 notes | Tautological |
| H-F4-091 | Music | Circle of fifths has 12 keys = sigma(6) | Same as chromatic scale, cultural |

---

## BLACK Refuted (13)

| ID | Statement | Why Refuted |
|----|-----------|-------------|
| H-F4-001 | sum_{d\|6} sigma(d)/d = 35/6, claimed = 4 | 35/6 != 4. Arithmetic error in hypothesis. |
| H-F4-005 | c_6(1) = mu(6) = 1, claimed = phi(6) = 2 | Ramanujan sum c_6(1) = mu(6/gcd(1,6)) = mu(6) = 1, not 2. |
| H-F4-024 | 6! = 720 = sigma*tau*phi*n | sigma*tau*phi*n = 12*4*2*6 = 576 != 720. Off by factor 720/576 = 5/4. |
| H-F4-030 | Involutions in S_6 = 76, claimed clean formula | 76 has no clean divisor function expression. Nearest: 76 != any simple f(sigma,tau,phi,n). |
| H-F4-032 | Tent map period-6 orbits via Mobius = 54 | 54 is not expressible cleanly via tau/sigma/phi. Raw Mobius count unrelated. |
| H-F4-034 | Logistic map period-6 onset at r = 3 = sigma/tau | Actual onset r ~ 3.6257. Off by 20%. |
| H-F4-057 | Kneser graph K(6,2) = Petersen graph | Petersen graph is K(5,2), not K(6,2). K(6,2) has 15 vertices. |
| H-F4-062 | Dark energy EoS w = -11/12 = -0.917 | Observed w ~ -1.03 +/- 0.03. Prediction 3.8 sigma away from observation. |
| H-F4-064 | CMB acoustic peak ratios 1:2:3 | Observed ratios 1:2.45:3.68, not integer ratios. |
| H-F4-065 | GW frequency f_ISCO = 288 Hz from 6 | Actual f_ISCO ~ 733 Hz for 10 M_sun. Off by 60%. |
| H-F4-070 | phi/n + 1/tau = 0.583 = Omega_m | Omega_m = 0.315. Off by 85%. |
| H-F4-077 | Kitaev model isotropic gap = 1/6 | Isotropic Kitaev model is GAPLESS (critical point). No gap exists. |
| H-F4-079 | nu = 1/6 Laughlin state | Even denominator (6) forbidden for fermionic Laughlin states. Unphysical. |

---

## Summary Statistics

```
  Total hypotheses:  90
  GREEN  (exact):    22  (24.4%)
  ORANGE-STAR:        3  ( 3.3%)
  WHITE  (weak):     52  (57.8%)
  BLACK  (wrong):    13  (14.4%)

  Hit rate (GREEN+ORANGE): 25/90 = 27.8%

  Best domains:
    Analytic NT:       6/10 GREEN
    Rep Theory:        5/8  GREEN
    Info Theory:       5/12 GREEN
    Quantum Comp:      3/8  GREEN + 1 ORANGE-STAR
    Condensed Matter:  1/5  GREEN + 1 ORANGE-STAR

  Worst domains:
    Biology:           0/8  (all WHITE or BLACK)
    Cosmology:         0/10 (1 ORANGE-STAR, rest WHITE/BLACK)
    Dynamical:         0/5  (all WHITE or BLACK)
```
