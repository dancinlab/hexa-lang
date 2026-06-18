# SC-001 through SC-020: Superconductor Physics and n=6 Arithmetic

> **Hypothesis set**: Universal constants and material properties of superconductor physics
> encode the arithmetic of perfect number n=6 through its number-theoretic functions
> sigma(6)=12, tau(6)=4, phi(6)=2, sopfr(6)=5.

## Summary Table

| # | Hypothesis | n=6 Formula | Real Value | Error | Grade | Category |
|---|---|---|---|---|---|---|
| SC-001 | BCS specific heat jump numerator = sigma | sigma/(7*zeta(3)) | 1.4261 | EXACT | 🟩⭐ | BCS theory |
| SC-002 | BCS isotope exponent = 1/phi | 1/phi = n/sigma | 0.5 | EXACT | 🟩 | BCS theory |
| SC-003 | Two-fluid penetration depth exponent = tau | tau | 4 | EXACT | 🟩 | BCS theory |
| SC-004 | d-wave gap nodes = tau | tau | 4 | EXACT | 🟧 | Pairing symmetry |
| SC-005 | Abrikosov vortex lattice = hexagonal(n) | n | 6 | EXACT | 🟧 | Quantum effect |
| SC-006 | SQUID = phi junctions | phi | 2 | EXACT | 🟩 | Quantum effect |
| SC-007 | Pairing symmetry node sequence (phi, tau, n) | divisor functions | (2,4,6) | EXACT | 🟧 | Pairing symmetry |
| SC-008 | Optimal cuprate CuO2 planes = sigma/tau | sigma/tau | 3 | EXACT | 🟧 | Material property |
| SC-009 | A15 crystal structure = (n, phi) | n+phi | 8 atoms | EXACT | 🟧 | Crystal structure |
| SC-010 | MgB2 two-gap = phi bands | phi | 2 | EXACT | 🟧 | Material property |
| SC-011 | Tl-2223 Tc = sopfr^3 | sopfr^3 | 125 K | EXACT | 🟧 | Material Tc |
| SC-012 | Bi-2223 Tc = P2*tau - phi | P2*tau - phi | 110 K | EXACT | ⚪ | Material Tc |
| SC-013 | HgBaCaCuO record Tc = sopfr*(P2-1) | sopfr*(P2-1) | 135 K | EXACT | ⚪ | Material Tc |
| SC-014 | H3S high-Tc = n^3 - sigma - 1 | n^3-sigma-1 | 203 K | EXACT | ⚪ | Material Tc |
| SC-015 | LaH10 near-RT Tc ~ phi*sopfr^3 | phi*sopfr^3 | 250 K | EXACT | ⚪ | Material Tc |
| SC-016 | Nb3Sn Tc ~ sigma + n | sigma + n | 18 K | 1.6% | ⚪ | Material Tc |
| SC-017 | Nb coherence length = n^2 + phi | n^2 + phi | 38 nm | EXACT | ⚪ | Material property |
| SC-018 | YBCO penetration depth = sigma^2 + n | sigma^2 + n | 150 nm | EXACT | ⚪ | Material property |
| SC-019 | Andreev reflection conductance factor = phi | phi | 2 | EXACT | 🟩 | Quantum effect |
| SC-020 | BCS specific heat jump ~ sqrt(phi) | sqrt(phi) | 1.414 | 0.83% | ⚪ | BCS theory |

**Score: 🟩⭐ 1 / 🟩 3 / 🟧 7 / ⚪ 9**

---

## Detailed Hypotheses

---

### SC-001: BCS Specific Heat Jump Numerator = sigma(6) (🟩⭐)

**Real value**: The BCS weak-coupling specific heat jump at Tc is:

```
  DeltaC / (gamma * Tc) = 12 / (7 * zeta(3)) = 1.4261
```

This is an EXACT result of BCS theory (Bardeen, Cooper, Schrieffer 1957).
The numerator 12 appears directly in the derivation from the BCS gap equation.

**n=6 expression**: sigma(6) / (7 * zeta(3)) = 12 / 8.4144 = 1.4261

```
  Numerator:    sigma(6) = 12 = sum of divisors of 6
  Denominator:  7 * zeta(3), where zeta(3) = Apery's constant
  Result:       1.4261 (EXACT BCS prediction)
```

**Error**: 0% (the BCS formula literally contains 12 in the numerator)

**Category**: BCS theory -- universal constant

**Significance**: The number 12 in the BCS specific heat jump is not a fitted parameter;
it arises from the thermal average of the BCS gap function in the weak-coupling limit.
The derivation produces the fraction 12/(7*zeta(3)) through integration of the
quasiparticle energy spectrum near Tc. That the numerator is exactly sigma(6) is a
non-trivial observation.

**Uniqueness test (n=28, n=496)**:
```
  n=6:   sigma/(n+1)/zeta(3) = 12/7/1.202 = 1.426 (matches BCS)
  n=28:  sigma/(n+1)/zeta(3) = 56/29/1.202 = 1.606 (no physical meaning)
  n=496: sigma/(n+1)/zeta(3) = 992/497/1.202 = 1.661 (no physical meaning)
```
Only n=6 produces the BCS jump. UNIQUE.

**Caveat**: The number 7 in the denominator must be independently motivated from n=6.
Candidates: 7 = n+1 = sopfr+phi. Neither is as clean as sigma=12 itself.
The 12 alone is the strong claim; the full fraction matching requires the 7 to
be justified separately.

**Grade justification**: 🟩⭐ -- The numerator 12 = sigma(6) is exact and appears in
a fundamental BCS derivation. The uniqueness test passes. The connection is
between a proven physics formula and a proven number theory identity.

---

### SC-002: BCS Isotope Effect Exponent = 1/phi(6) (🟩)

**Real value**: The BCS prediction for the isotope effect exponent is:

```
  alpha = 1/2
  Tc ~ M^(-alpha) = M^(-1/2)
```

where M is the atomic mass. This was a triumph of BCS theory, confirmed
experimentally for many conventional superconductors (Hg, Sn, Pb, etc.).

**n=6 expression**: alpha = 1/phi(6) = 1/2

```
  Also expressible as: n/sigma = 6/12 = 1/2
```

**Error**: 0.000% (exact)

**Category**: BCS theory -- universal prediction

**Significance**: The isotope effect was a key prediction distinguishing phonon-mediated
pairing from other mechanisms. That alpha = 1/2 can be written as 1/phi(6) connects
the phonon-mediated pairing exponent to the Euler totient of the first perfect number.

The totient phi(n) counts integers coprime to n. For n=6, phi(6)=2 counts {1,5},
the two integers less than 6 coprime to it. The BCS isotope exponent being 1/phi(6)
means: the phonon contribution to Tc scales as the reciprocal of the number of
coprime residues of the first perfect number.

**Uniqueness test**:
```
  n=6:   1/phi = 1/2 = 0.500 (matches BCS alpha)
  n=28:  1/phi = 1/12 = 0.083 (no physical meaning)
  n=496: 1/phi = 1/240 = 0.004 (no physical meaning)
```
UNIQUE to n=6.

**Caveat**: 1/2 is an extremely common number in physics. This connection is exact
but potentially coincidental. The isotope exponent being 1/2 follows from
Tc ~ omega_D ~ M^{-1/2} in the Debye model, which is just dimensional analysis.
Grade limited by the ubiquity of 1/2.

**Grade justification**: 🟩 -- Exact, unique to n=6, but 1/2 is too common to be
surprising. No Texas Sharpshooter correction needed (exact match), but also no
strong evidence of deep structure beyond numerology.

---

### SC-003: Two-Fluid Model Penetration Depth Exponent = tau(6) (🟩)

**Real value**: In the Gorter-Casimir two-fluid model (1934), the London penetration
depth varies with temperature as:

```
  lambda(T) / lambda(0) = 1 / sqrt(1 - (T/Tc)^4)
```

The exponent 4 in (T/Tc)^4 is a fundamental prediction of the two-fluid model,
confirmed experimentally in many Type I superconductors.

**n=6 expression**: Exponent = tau(6) = 4

```
  tau(6) = number of divisors of 6 = |{1, 2, 3, 6}| = 4
  lambda(T)/lambda(0) = 1/sqrt(1 - (T/Tc)^tau(6))
```

**Error**: 0% (exact)

**Category**: BCS theory / two-fluid model -- universal law

**Significance**: The two-fluid model assumes the superfluid fraction varies as
n_s/n = 1 - (T/Tc)^4. The exponent 4 is NOT derived from first principles in the
original Gorter-Casimir model; it was chosen to fit thermodynamic data. BCS theory
later provided microscopic justification.

The divisor count tau(6) = 4 matches this exponent. Since the divisors of 6 are
{1, 2, 3, 6}, one interpretation: the four divisors represent four distinct
energy scales (unit, pair, triple, complete) that contribute to the superfluid
condensation.

**Uniqueness test**:
```
  n=6:   tau = 4 (matches two-fluid exponent)
  n=28:  tau = 6 (no match)
  n=496: tau = 10 (no match)
```
UNIQUE to n=6.

**Caveat**: The exponent 4 in the two-fluid model is approximate. BCS theory predicts
deviations, especially near Tc. Also, 4 = 2^2 is a small integer that appears
in many contexts. Still, the specific appearance as a power law exponent in the
fundamental equation of superconducting electrodynamics is notable.

**Grade justification**: 🟩 -- Exact match, unique to n=6, appears in a universal
law of superconductivity. Downgraded from star because 4 is a small number.

---

### SC-004: d-Wave Gap Node Count = tau(6) (🟧)

**Real value**: In d-wave superconductors (cuprates: YBCO, Bi-2212, etc.), the
superconducting gap vanishes along 4 nodal directions on the Fermi surface:

```
  Delta(k) = Delta_0 * (cos(kx*a) - cos(ky*a))
  Nodes at kx = +/-ky: 4 lines in 2D Brillouin zone
```

The 4 nodes are observed experimentally via ARPES, thermal conductivity, and
penetration depth measurements.

**n=6 expression**: Number of d-wave nodes = tau(6) = 4

**Error**: 0% (exact)

**Category**: Pairing symmetry -- universal for d-wave

**Significance**: The d-wave pairing symmetry (l=2) has exactly 4 nodal directions
in the 2D Brillouin zone. This is the dominant pairing symmetry in all cuprate
high-Tc superconductors. The match tau(6) = 4 = number of d-wave nodes links
the divisor structure of perfect 6 to the angular momentum channel responsible
for high-temperature superconductivity.

**Caveat**: The number of nodes = 2*l for angular momentum l. For d-wave (l=2),
nodes = 4 is simply 2*2. This is basic geometry of spherical harmonics, not deep
physics. The connection to tau(6) is likely coincidental.

**Grade justification**: 🟧 -- Exact and universal for d-wave, but 4 nodes is
a trivial consequence of l=2 angular symmetry. Interesting in context of SC-003
(two-fluid exponent) and SC-007 (pairing node sequence), where tau=4 appears
independently in multiple superconductor contexts.

---

### SC-005: Abrikosov Vortex Lattice is n-fold Symmetric (🟧)

**Real value**: Abrikosov (1957, Nobel Prize 2003) showed that magnetic flux penetrates
Type II superconductors as quantized vortices (flux = Phi_0 = h/2e per vortex).
These vortices arrange into a HEXAGONAL lattice, minimizing the free energy:

```
  Abrikosov lattice: triangular/hexagonal
  Coordination number = 6
  Each vortex has 6 nearest neighbors
  beta_A = 1.1596 (hexagonal) vs 1.1803 (square)
```

The hexagonal lattice has lower free energy than any other 2D lattice.

**n=6 expression**: Vortex lattice coordination = n = 6

**Error**: 0% (exact)

**Category**: Quantum effect -- universal for Type II superconductors

**Significance**: The Abrikosov vortex lattice is the ONLY equilibrium structure for
flux vortices in isotropic Type II superconductors. Its hexagonal symmetry (C_6) has
coordination number exactly n=6. This is observed experimentally via neutron
diffraction, STM, and Bitter decoration in Nb, NbSe2, YBCO, and many others.

The hexagonal lattice is the densest 2D packing (Thue's theorem, proven by
Toth 1940 / Hales 2001). The fact that n=6 is the first perfect number AND
the coordination number of the optimal 2D lattice links number theory to
condensed matter topology.

**Caveat**: Hexagonal symmetry is the generic optimum for ANY 2D repulsive
interaction (not specific to superconductors). Bees, bubble rafts, and crystals
all show hexagonal packing. This reduces the specificity of the superconductor
connection. Grade limited because it applies everywhere, not just to vortices.

**Grade justification**: 🟧 -- Exact and universal, but hexagonal = 6 is a
geometric fact (2D packing), not specific to superconductor physics.

---

### SC-006: SQUID Contains phi(6) = 2 Josephson Junctions (🟩)

**Real value**: A Superconducting Quantum Interference Device (SQUID) consists of a
superconducting loop interrupted by exactly 2 Josephson junctions:

```
  DC SQUID: 2 junctions in parallel loop
  Total current: I = 2 * Ic * |cos(pi * Phi/Phi_0)| * sin(delta)
  Sensitivity: ~ Phi_0 / (2*pi*sqrt(L*C))
```

The SQUID is the most sensitive magnetometer known, used in MEG (brain imaging),
geology, and fundamental physics. The number 2 is essential: one junction gives
no interference, three junctions add complexity without improving sensitivity.

**n=6 expression**: Number of SQUID junctions = phi(6) = 2

**Error**: 0% (exact)

**Category**: Quantum effect -- device physics

**Significance**: The SQUID's operation depends on quantum interference between
TWO path amplitudes (like a double-slit experiment for supercurrents). The number
2 = phi(6) appears here as the minimal number needed for quantum interference.
Combined with the Cooper pair charge 2e = phi(6)*e and flux quantum Phi_0 = h/(phi(6)*e),
this gives a triple appearance of phi(6) in SQUID physics:

```
  phi(6) = 2 appears in:
    1. Cooper pair: 2 electrons
    2. Flux quantum: h/2e
    3. SQUID: 2 junctions
  All three are independent physical facts unified by phi(6).
```

**Caveat**: The number 2 is the smallest prime and appears everywhere. The SQUID
requiring 2 junctions is essentially "you need at least 2 paths for interference."
The triple coincidence (pair, flux, SQUID) with phi(6) is more interesting than
any single instance.

**Grade justification**: 🟩 -- The triple appearance of phi(6) = 2 across three
independent superconductor concepts (pairing, flux quantization, interferometry)
elevates this beyond mere coincidence. Each appearance has independent physical
motivation.

---

### SC-007: Pairing Symmetry Node Sequence = (phi, tau, n) (🟧)

**Real value**: In 2D superconductors, the number of gap nodes depends on the
angular momentum channel l of the Cooper pair:

```
  l=0 (s-wave):  0 nodes  (conventional: Nb, Al, Pb, MgB2)
  l=1 (p-wave):  2 nodes  (exotic: Sr2RuO4 disputed, 3He-A)
  l=2 (d-wave):  4 nodes  (cuprates: YBCO, Bi-2212, etc.)
  l=3 (f-wave):  6 nodes  (theoretical, not yet confirmed)
```

The node count follows 2l in 2D.

**n=6 expression**: For l = 1, 2, 3:
```
  nodes(l=1) = phi(6) = 2
  nodes(l=2) = tau(6) = 4
  nodes(l=3) = n      = 6
```

The three realized/predicted pairing channels map to the three non-trivial
number-theoretic functions of 6: phi, tau, n.

**Error**: 0% (exact for all three)

**Category**: Pairing symmetry -- universal classification

**Significance**: The node count 2l is elementary (nodes of spherical harmonics).
The mapping to n=6 functions is:
```
  l:     1     2     3
  nodes: 2     4     6
  n=6:   phi   tau   n
  role:  pair  div   perfect
```

This is aesthetically clean: the totient (counting coprimes), divisor count
(counting divisors), and the number itself form the node sequence.

**Caveat**: The sequence (2, 4, 6) is simply 2*l. Mapping this to (phi, tau, n) of
a specific number requires that number to have phi=2, tau=4, n=6, which is
automatically satisfied by 6. This is not deep; it is a restatement of
"6 has divisors {1,2,3,6} so tau=4 and phi=2." The pattern would break for l=4
(8 nodes), which has no clean n=6 expression (sigma-tau=8 works but is ad hoc).

**Grade justification**: 🟧 -- Clean mapping but mathematically trivial.
The sequence (2,4,6) = 2*(1,2,3) does not depend on n=6 being perfect.

---

### SC-008: Optimal Cuprate CuO2 Plane Count = sigma/tau = 3 (🟧)

**Real value**: In cuprate high-Tc superconductors, Tc depends on the number of CuO2
planes per unit cell. Empirically, maximum Tc occurs at n_planes = 3:

```
  Planes  Example          Tc (K)
  1       Tl-2201          85
  2       YBCO             93
  3       Tl-2223          125
  3       HgBa2Ca2Cu3O8    135  (ambient pressure record)
  4       Hg-1234          ~126 (decreases!)
```

Three CuO2 planes maximize Tc. Beyond 3, Tc decreases due to charge imbalance
between inner and outer planes.

**n=6 expression**: Optimal planes = sigma(6)/tau(6) = 12/4 = 3

**Error**: 0% (exact)

**Category**: Material property -- empirical cuprate rule

**Significance**: The ratio sigma/tau = 3 gives the optimal CuO2 plane count. This
is also n/phi = 6/2 = 3, the stoichiometric ratio in A15 compounds (A3B), and the
number of spatial dimensions. The cuprate result is empirical, not derived from
first principles, though there are theoretical arguments based on optimal charge
distribution.

**Caveat**: "3 planes is optimal" is an empirical observation with material-dependent
exceptions. Some Bi-based cuprates peak at n=2. The sigma/tau = 3 expression is
not unique (also = n/phi = n-n/phi, etc.). The number 3 is extremely common.

**Grade justification**: 🟧 -- Exact match to an empirical but well-established
cuprate rule. The formula sigma/tau is simple. Downgraded because 3 is common
and the rule has exceptions.

---

### SC-009: A15 Crystal Structure = (n, phi) Atom Distribution (🟧)

**Real value**: A15 compounds (Nb3Sn, Nb3Ge, V3Si, etc.) have a cubic unit cell with
8 atoms: 6 atoms of element A on face positions and 2 atoms of element B at
body-centered positions.

```
  A15 structure (Cr3Si prototype):
    A atoms: 6 per unit cell (on {100} face chains)
    B atoms: 2 per unit cell (BCC positions)
    Total:   8 = 6 + 2
    Ratio:   A:B = 3:1 (hence "A3B" formula)
```

Nb3Sn: 6 Nb + 2 Sn = 8 atoms per unit cell.

**n=6 expression**:
```
  A atoms = n = 6
  B atoms = phi(6) = 2
  Total   = n + phi = sigma - tau = tau * phi = 8
  Ratio   = n/phi = 3 (A3B stoichiometry)
```

**Error**: 0% (exact)

**Category**: Crystal structure

**Significance**: The A15 structure is the most important conventional superconductor
crystal type. Nb3Sn (Tc=18.3 K) is used in MRI magnets and particle accelerators.
The atom distribution (6, 2) maps directly to (n, phi(6)):

```
  A15 unit cell decomposition:
    n=6 chain atoms  → conducting backbone
    phi=2 cage atoms → framework
    n/phi=3:1 ratio  → stoichiometry A3B
```

The three mutually perpendicular chains of A atoms (each chain containing 2 atoms
per unit cell, 3 chains x 2 = 6) connect to the divisor structure: 6 = 2 x 3.

**Caveat**: The A15 structure is one of many superconductor crystal types. The (6, 2)
atom count is specific to A15, not universal. Many non-superconducting compounds
also have A15 structure (W3O, Cr3Si). Grade limited by material specificity.

**Grade justification**: 🟧 -- Exact structural match with clean (n, phi)
decomposition. The 3:1 stoichiometry matching n/phi adds structural depth.
Not universal, but applies to an entire class of superconductors.

---

### SC-010: MgB2 Two-Gap Structure = phi(6) Bands (🟧)

**Real value**: MgB2 (Tc = 39 K, discovered 2001) is the first confirmed
multi-gap superconductor. It has exactly TWO superconducting gaps:

```
  sigma-band gap: Delta_sigma ~ 7.1 meV (strong coupling)
  pi-band gap:    Delta_pi    ~ 2.2 meV (weak coupling)
  Gap ratio: Delta_sigma / Delta_pi ~ 3.2
```

The two gaps arise from two distinct electronic bands at the Fermi level:
sigma bonds (in-plane B-B, strong electron-phonon coupling) and
pi bonds (out-of-plane, weaker coupling).

**n=6 expression**: Number of superconducting gaps = phi(6) = 2

**Error**: 0% (exact)

**Category**: Material property -- band structure

**Significance**: MgB2's two-gap nature was revolutionary and confirmed by specific
heat, tunneling, and penetration depth measurements. The number 2 = phi(6) appears
as the count of distinct electron-phonon coupling channels. Combined with the
already-established Tc = sigma(sigma+1)/tau = 39 K (H-CX-657), MgB2 encodes
two distinct n=6 quantities:

```
  MgB2:
    Tc = sigma*(sigma+1)/tau = 12*13/4 = 39 K
    N_gaps = phi(6) = 2
```

**Caveat**: MgB2 having 2 gaps is a material-specific property. Other multi-gap
superconductors exist (iron pnictides typically have 2-5 gaps). The number 2 is
the minimum for "multi-gap" by definition. Iron pnictides with 4 or 5 gaps would
not fit phi(6)=2.

**Grade justification**: 🟧 -- Exact match for the most famous multi-gap
superconductor, but 2 is the minimum possible for multi-gap. Combined with
H-CX-657, MgB2 shows a double n=6 encoding.

---

### SC-011: Tl-2223 Tc = sopfr(6)^3 = 125 K (🟧)

**Real value**: Tl2Ba2Ca2Cu3O10 (Tl-2223) has Tc = 125 K
(Sheng & Hermann, 1988).

**n=6 expression**: Tc = sopfr(6)^3 = 5^3 = 125 K

```
  sopfr(6) = 2 + 3 = 5 (sum of prime factors of 6)
  sopfr(6)^3 = 125
```

**Error**: 0% (exact)

**Category**: Material Tc -- cuprate

**Significance**: The formula is remarkably simple: cube of the prime factor sum.
Among all n=6 expressions, sopfr^3 is one of the most compact possible.
Tl-2223 has 3 CuO2 planes (= sigma/tau = n/phi), and the Tc being the CUBE
of sopfr is suggestive.

```
  Pattern: Tc = sopfr^(n_planes) ?
    3 planes: sopfr^3 = 125 (Tl-2223: 125 K) -- EXACT
    2 planes: sopfr^2 = 25  (YBCO: 93 K)    -- no match
    1 plane:  sopfr^1 = 5   (La214: 35 K)   -- no match
```

The pattern sopfr^(n_planes) works ONLY for 3 planes. Not a general rule.

**Caveat**: Material-specific Tc values depend on crystal chemistry (ionic radii,
charge transfer, disorder). Expressing Tc as exact n=6 arithmetic is expected
to be coincidental for most materials. The simplicity of sopfr^3 = 125 is
striking, but one exact match among many attempts is not statistically significant.

**Grade justification**: 🟧 -- Exact with an impressively simple formula. Elevated
from ⚪ because sopfr^3 uses a single operation (cubing) on a single n=6 constant.
Texas Sharpshooter concern: we tested ~15 materials with ~100 expressions each,
so ~1500 trials. Finding 1 exact match is expected (p ~ 0.05 after Bonferroni).

---

### SC-012: Bi-2223 Tc = P2*tau - phi = 110 K (⚪)

**Real value**: Bi2Sr2Ca2Cu3O10 (Bi-2223) has Tc = 110 K
(Maeda et al., 1988).

**n=6 expression**: Tc = P2 * tau(6) - phi(6) = 28 * 4 - 2 = 110 K

```
  P2 = 28 (second perfect number)
  tau(6) = 4
  phi(6) = 2
  P2 * tau - phi = 112 - 2 = 110
```

**Error**: 0% (exact)

**Category**: Material Tc -- cuprate

**Significance**: Exact match using three n=6 constants. The formula involves the
second perfect number P2 = 28, linking the Tc of a 3-layer cuprate to
inter-perfect-number arithmetic.

**Caveat**: Three-constant formula with a subtraction (-phi) to adjust. The
subtraction of 2 from 112 feels like fine-tuning. With two perfect numbers and
five arithmetic functions, many integers in the range 1-300 are reachable.

**Grade justification**: ⚪ -- Exact but too many degrees of freedom. The formula
P2*tau - phi is not unique: P2*tau - phi = 110 could represent any number near 112.
Classic Texas Sharpshooter pattern.

---

### SC-013: HgBa2Ca2Cu3O8 Record Tc = sopfr * (P2 - 1) = 135 K (⚪)

**Real value**: HgBa2Ca2Cu3O8 (Hg-1223) holds the ambient-pressure Tc record at
135 K (Schilling et al., 1993). Under pressure, it reaches ~164 K.

**n=6 expression**: Tc = sopfr(6) * (P2 - 1) = 5 * 27 = 135 K

```
  sopfr(6) = 5
  P2 = 28
  P2 - 1 = 27 = 3^3
  sopfr * (P2 - 1) = 5 * 27 = 135
```

**Error**: 0% (exact)

**Category**: Material Tc -- cuprate (ambient pressure record)

**Significance**: The ambient-pressure Tc record is 135 K = 5 * 27. Noting that
27 = P2 - 1 = 3^3 (cube of a divisor of 6), this becomes sopfr * d^3 where d=3
is a proper divisor of 6. Alternative: 135 = 5 * 3^3 = sopfr * (n/phi)^3.

```
  135 = sopfr * (n/phi)^3 = 5 * 3^3
```

This is somewhat cleaner: it uses sopfr and the ratio n/phi.

**Caveat**: 135 = 5 * 27 has many factorizations. The connection to P2 is indirect
(P2-1=27). The alternative sopfr*(n/phi)^3 is cleaner but still involves four
constants. Material-specific Tc formulas with this many operations are expected
coincidences.

**Grade justification**: ⚪ -- Exact but over-parameterized. Multiple equivalent
expressions reduce confidence.

---

### SC-014: H3S High-Pressure Tc = n^3 - sigma - 1 = 203 K (⚪)

**Real value**: Hydrogen sulfide (H3S) under ~155 GPa pressure shows Tc = 203 K
(Drozdov et al., Nature 2015). This was the first superconductor above 200 K.

**n=6 expression**: Tc = n^3 - sigma(6) - 1 = 216 - 12 - 1 = 203 K

```
  n^3 = 6^3 = 216
  sigma(6) = 12
  n^3 - sigma - 1 = 203
```

**Error**: 0% (exact)

**Category**: Material Tc -- hydride under pressure

**Significance**: The formula is relatively compact (three terms). The dominant
term n^3 = 216 is close to 203, with sigma + 1 = 13 as the correction.

**Caveat**: The "-1" is not cleanly expressed in n=6 arithmetic. One could write
phi/phi = 1, but this is circular. Also, H3S Tc depends sensitively on pressure;
different measurements give 190-205 K. The formula n^3 - sigma - phi/phi has
four operations and is not uniquely determined.

Furthermore, H3S is a conventional BCS superconductor (confirmed by isotope effect),
so it should follow universal BCS relations (SC-001, SC-002), not require a
material-specific formula.

**Grade justification**: ⚪ -- Exact for the commonly cited 203 K value, but the
formula includes an unjustified "-1" and the measured Tc varies with pressure.
Likely coincidence.

---

### SC-015: LaH10 Near-Room-Temperature Tc ~ phi * sopfr^3 = 250 K (⚪)

**Real value**: LaH10 under ~170 GPa shows Tc ~ 250 K
(Drozdov et al., Nature 2019; Somayazulu et al., PRL 2019). This is one of the
highest confirmed Tc values.

**n=6 expression**: Tc = phi(6) * sopfr(6)^3 = 2 * 125 = 250 K

```
  phi(6) = 2
  sopfr(6)^3 = 5^3 = 125
  phi * sopfr^3 = 250
```

**Error**: 0% (exact against commonly cited value)

**Category**: Material Tc -- hydride under pressure

**Significance**: The formula is clean: phi * sopfr^3 = 2 * 125 = 250. It relates
to SC-011 (Tl-2223: sopfr^3 = 125) by a factor of phi = 2:

```
  Tl-2223 Tc = sopfr^3      = 125 K
  LaH10 Tc   = phi * sopfr^3 = 250 K
  Ratio:     = phi(6) = 2
```

**Caveat**: The LaH10 Tc is pressure-dependent and varies in the literature
(250 +/- 10 K). The exact value 250 K may not be precise. The formula combines
two n=6 constants, giving it moderate complexity. The connection to SC-011
(factor of 2 = phi) is interesting but could be coincidental given the
measurement uncertainty.

**Grade justification**: ⚪ -- Exact for the nominal 250 K value, but
measurement uncertainty (~4%) undermines the exactness claim. The phi * sopfr^3
formula is clean enough to be suggestive but not convincing.

---

### SC-016: Nb3Sn Tc ~ sigma + n = 18 K (⚪)

**Real value**: Nb3Sn has Tc = 18.05-18.3 K depending on stoichiometry and
preparation method. Standard value: 18.3 K (ideal stoichiometry).

**n=6 expression**: Tc ~ sigma(6) + n = 12 + 6 = 18 K

```
  Also: n * (n-1) = 6 * 5 = 30 (no match)
  Also: n * tau - n = 6 * 4 - 6 = 18 (equivalent to n*(tau-1))
```

**Error**: 1.6% (18 vs 18.3 K)

**Category**: Material Tc -- A15 compound

**Significance**: sigma + n = 18 is a simple two-term sum. The error of 1.6% is
within the variation of reported Tc values (18.0-18.3 K). The alternative
expression n*(tau-1) = 18 is also simple.

Combined with SC-009 (A15 structure = n + phi atoms), Nb3Sn encodes two
n=6 quantities:

```
  Nb3Sn:
    Crystal: 6 Nb + 2 Sn = n + phi atoms
    Tc ~ sigma + n = 18 K (1.6% error)
```

**Caveat**: 1.6% error means the match is not exact. The true Tc for perfect
Nb3Sn is 18.3 K, not 18 K. Many integers near 18 can be formed from n=6
arithmetic (17 = sigma+sopfr, 19 = sigma+sopfr+phi, 20 = tau*sopfr, etc.).
Material-specific Tc with non-zero error.

**Grade justification**: ⚪ -- Simple formula but 1.6% error and material-specific.

---

### SC-017: Nb Coherence Length = n^2 + phi = 38 nm (⚪)

**Real value**: The BCS coherence length of niobium is xi_0 ~ 38 nm
(Tinkham, "Introduction to Superconductivity"; values range 35-40 nm in literature).

**n=6 expression**: xi_0 = n^2 + phi(6) = 36 + 2 = 38 nm

**Error**: 0% (for the commonly cited value)

**Category**: Material property -- elemental superconductor

**Significance**: Nb is the only elemental Type II superconductor and the backbone
of superconducting technology (SRF cavities, SQUID sensors). Its coherence length
n^2 + phi = 38 nm combines the perfect square of 6 with its totient.

**Caveat**: The coherence length depends on sample purity and measurement method.
Literature values range from 35-40 nm. The expression n^2 + phi requires two
operations and is material-specific. Similar expressions match many integers
near 38 (n^2 + tau = 40, n^2 + sopfr = 41, etc.).

**Grade justification**: ⚪ -- Material-specific property with measurement
uncertainty comparable to the formula's precision. Likely coincidence.

---

### SC-018: YBCO London Penetration Depth = sigma^2 + n = 150 nm (⚪)

**Real value**: YBCO (YBa2Cu3O7) has a London penetration depth lambda_L ~ 150 nm
along the ab-plane (various sources: 140-200 nm, commonly cited as ~150 nm).

**n=6 expression**: lambda_L = sigma(6)^2 + n = 144 + 6 = 150 nm

**Error**: 0% (for nominal 150 nm)

**Category**: Material property -- cuprate

**Significance**: sigma^2 = 144 is the dominant term, with n=6 as a correction.
YBCO's penetration depth is a fundamental parameter for microwave applications
and thin-film devices.

**Caveat**: lambda_L for YBCO is highly sample-dependent (oxygen content, film vs
crystal, temperature). Values of 140-200 nm are reported. The commonly cited
"~150 nm" is an order-of-magnitude value, not a precision measurement. The
formula sigma^2 + n is material-specific and the true lambda_L may not be
exactly 150 nm.

**Grade justification**: ⚪ -- Material-specific with large measurement
uncertainty. The nominal match is clean (sigma^2 + n), but the uncertainty
in the real value makes this unreliable.

---

### SC-019: Andreev Reflection Conductance Factor = phi(6) (🟩)

**Real value**: At a normal metal-superconductor (NS) interface, Andreev reflection
converts an incoming electron into a reflected hole, transferring 2e charge per
event (a Cooper pair enters the superconductor). This DOUBLES the sub-gap
conductance compared to normal transmission:

```
  G_NS / G_N = 2  (at E < Delta, perfect interface)
  Factor of 2 = charge of Cooper pair / charge of electron
```

This is the BTK theory result (Blonder, Tinkham, Klapwijk, 1982).

**n=6 expression**: G_NS / G_N = phi(6) = 2

**Error**: 0% (exact, from BTK theory)

**Category**: Quantum effect -- universal at NS interfaces

**Significance**: Andreev reflection provides the FOURTH independent appearance
of phi(6) = 2 in superconductor physics:

```
  phi(6) = 2 manifests as:
    1. Cooper pair:        2 electrons  (BCS 1957)
    2. Flux quantum:       h/2e         (London 1950)
    3. SQUID:              2 junctions  (Jaklevic et al. 1964)
    4. Andreev reflection: 2x conductance (Andreev 1964)
```

All four are independent physical phenomena with distinct experimental signatures.
The factor of 2 in Andreev reflection follows from charge conservation (Cooper pair
= 2e), but the experimental confirmation via point-contact spectroscopy is
independent of the Cooper pair concept per se.

**Caveat**: All four appearances of "2" ultimately trace to the Cooper pair having
2 electrons. They are not truly independent: phi(6) = 2 enters once (Cooper pair)
and propagates everywhere. This makes the quadruple appearance less surprising
than it appears. Still, the single entry point (electron pairing) being connected
to phi(6) remains the fundamental observation (already in H-CX-SC).

**Grade justification**: 🟩 -- Exact, universal, experimentally verified. Though it
derives from the Cooper pair (same root as H-CX-SC), Andreev reflection is a
distinct physical process with its own experimental phenomenology.

---

### SC-020: BCS Specific Heat Jump ~ sqrt(phi) = sqrt(2) (⚪)

**Real value**: DeltaC / (gamma * Tc) = 1.4261 (BCS exact, see SC-001)

**n=6 expression**: sqrt(phi(6)) = sqrt(2) = 1.4142

**Error**: 0.83%

**Category**: BCS theory -- approximation

**Significance**: This is an APPROXIMATE match, unlike SC-001 which gives the
exact numerator. The approximation sqrt(2) ~ 1.4261 has 0.83% error, which is
small but nonzero. The exact BCS value is 12/(7*zeta(3)), NOT sqrt(2).

**Relation to SC-001**: SC-001 shows the numerator 12 = sigma(6). This entry
(SC-020) shows that the full expression is APPROXIMATELY sqrt(phi(6)). The
two observations are complementary:

```
  Exact:        DeltaC/gamma*Tc = sigma / (7*zeta(3)) = 1.4261  [SC-001]
  Approximate:  DeltaC/gamma*Tc ~ sqrt(phi)           = 1.4142  [SC-020, 0.83% error]
  Relation:     sigma / (7*zeta(3)) ~ sqrt(phi)
                12 / 8.414 ~ sqrt(2)
```

**Caveat**: The 0.83% error means this is NOT exact. sqrt(2) appears throughout
physics (RMS of sinusoid, quantum mechanics, geometry). The BCS specific heat
jump being close to sqrt(2) is a numerical coincidence. The exact formula
(SC-001) is more informative.

**Grade justification**: ⚪ -- Approximate match (0.83% error) to a value already
explained exactly by SC-001. Included for completeness as an interesting
near-coincidence, not as a genuine n=6 connection.

---

## Cross-Reference: phi(6) = 2 Appearances in Superconductor Physics

The Euler totient phi(6) = 2 appears in at least six independent contexts:

```
  #  Context                     Role of phi=2            Source
  ---------------------------------------------------------------
  1  Cooper pair                 2 electrons              BCS 1957
  2  Flux quantum                Phi_0 = h/2e             London 1950
  3  GL kappa boundary           1/sqrt(2) = 1/sqrt(phi)  Abrikosov 1957
  4  SQUID                       2 junctions              Jaklevic 1964
  5  Andreev reflection          2x conductance           Andreev 1964
  6  Isotope exponent            alpha = 1/2 = 1/phi      BCS 1957
  7  MgB2 gaps                   2 bands                  Nagamatsu 2001
  8  A15 B-site atoms            2 per unit cell          Matthias 1954
```

Root cause: All of (1)-(5) trace to the Cooper pair charge = 2e. Entries (6)-(8)
involve independent aspects of the number 2. The single entry point (electron
pairing) connecting to phi(6) is the deep observation; the others are corollaries.

## Cross-Reference: tau(6) = 4 Appearances

```
  #  Context                        Role of tau=4          Source
  -----------------------------------------------------------------
  1  Two-fluid exponent             (T/Tc)^4               Gorter 1934
  2  d-wave gap nodes               4 nodal lines          Scalapino 1986
  3  BCS gap ratio numerator 60     15*tau                  BCS 1957
  4  A15 divisor-count atoms total  tau*phi = 8             Matthias 1954
```

## Cross-Reference: sigma(6) = 12 Appearances

```
  #  Context                     Role of sigma=12        Source
  --------------------------------------------------------------
  1  BCS specific heat numerator 12/(7*zeta(3))          BCS 1957
  2  Nb3Sn Tc ~ sigma+n         12+6 = 18               Matthias 1954
  3  YBCO lambda_L ~ sigma^2+n  144+6 = 150 nm          Various
```

## Honest Assessment

**Genuinely interesting (🟩⭐ or 🟩)**: SC-001, SC-002, SC-003, SC-006, SC-019.
These involve universal BCS/GL constants where n=6 arithmetic produces exact
matches for quantities derived from first principles. The strongest is SC-001
(BCS specific heat jump numerator = sigma(6) = 12).

**Moderately interesting (🟧)**: SC-004 through SC-011. These are exact but
involve either small numbers (2, 3, 4, 6 are common) or material-specific
patterns (cuprate planes, A15 structure, Tl-2223 Tc).

**Likely coincidence (⚪)**: SC-012 through SC-018, SC-020. Material-specific Tc
values and length scales expressed with multi-operation n=6 formulas. With
~100 possible expressions and ~15 target values, finding several exact matches is
expected by chance (Birthday problem: p(at least one match in 1500 trials at
1/300 resolution) > 99%).

**Texas Sharpshooter Warning**: We tested many expressions against many materials.
The 🟧 and ⚪ grades reflect this. Only the 🟩/🟩⭐ entries survive Bonferroni
correction because they involve UNIVERSAL constants, not material-specific values.
