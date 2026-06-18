# THERMO-001~020: Thermodynamics, Statistical Mechanics, and Phase Transitions Meet Perfect Number 6

> **Hypothesis**: Classical thermodynamics, statistical mechanics, and critical phenomena
> exhibit systematic connections to perfect number 6 arithmetic functions:
> sigma(6)=12, tau(6)=4, phi(6)=2, sopfr(6)=5, P1=6, M6=63, P2=28.

**Status**: 20 hypotheses verified
**Grade Summary**: 🟩star 3 + 🟩 4 + 🟧star 1 + 🟧 6 + ⚪ 6
**Hit Rate**: 14/20 = 70% (grade >= 🟧)

---

## Background

Thermodynamics and statistical mechanics are the bedrock of physics, governing
everything from heat engines to phase transitions. The mathematical constants that
appear in these theories (degrees of freedom, critical exponents, power laws) are
not arbitrary -- they emerge from deep symmetry and dimensional arguments. This
document tests whether these constants decompose into n=6 arithmetic in a
non-trivial way.

### P1=6 Core Functions

| Function | Value | Meaning |
|----------|-------|---------|
| sigma(6) | 12 | Sum of divisors: 1+2+3+6 |
| tau(6) | 4 | Number of divisors |
| phi(6) | 2 | Euler totient (coprime count) |
| sopfr(6) | 5 | Sum of prime factors: 2+3 |
| P1 | 6 | First perfect number |
| M6 | 63 | Mersenne number 2^6-1 |
| P2 | 28 | Second perfect number |

### Honesty Note

Many of the constants in thermodynamics (3, 4, 5) are small integers that
arise from spatial dimension d=3 and basic counting. The Strong Law of Small
Numbers applies heavily here. Connections to small integers like tau=4 or
sopfr=5 must be evaluated with particular skepticism. We grade accordingly.

---

## THERMO-001: Four Laws of Thermodynamics = tau(6) (🟧)

> The laws of thermodynamics number exactly 4: the 0th, 1st, 2nd, and 3rd laws.
> tau(6) = 4 = number of divisors of 6.

```
  Laws of Thermodynamics:
    0th Law: Thermal equilibrium is transitive
    1st Law: Energy conservation (dU = dQ - dW)
    2nd Law: Entropy never decreases (dS >= 0)
    3rd Law: S -> 0 as T -> 0

  Count = 4 = tau(6)
```

**Assessment**: The count of 4 laws is a historical convention. The 0th law was
added later (by Fowler, 1930s) precisely because the other three were already
numbered. The "four laws" framing is somewhat arbitrary -- some formulations
merge the 0th into axioms. That said, tau=4 is a small integer that appears in
many contexts.

**Grade**: 🟧 -- Numerically exact but the count is a human convention, not a
physical constant. Weak structural significance.

---

## THERMO-002: Nonlinear Polyatomic DOF = P1 = 6 (🟩star)

> A nonlinear polyatomic molecule (e.g., H2O, CH4) at high temperature has
> f = 6 degrees of freedom (3 translational + 3 rotational), giving
> gamma = (f+2)/f = 8/6 = 4/3 = tau(6)/3.

```
  Molecule Type       f (DOF)    gamma = (f+2)/f
  ──────────────────────────────────────────────
  Monatomic (He)      3          5/3 = 1.667
  Diatomic (N2)       5          7/5 = 1.400
  Nonlinear poly      6          8/6 = 4/3 = 1.333

  f(polyatomic) = 6 = P1
  gamma(poly)   = 4/3 = tau/3

  ┌──────────────────────────────────────────────────┐
  │  DOF decomposition for nonlinear polyatomic:     │
  │                                                  │
  │  Translation:  x, y, z         = 3 DOF           │
  │  Rotation:     Rx, Ry, Rz      = 3 DOF           │
  │  ──────────────────────────────                  │
  │  Total:                         = 6 DOF = P1     │
  │                                                  │
  │  (Vibrational DOF frozen at room temperature)    │
  └──────────────────────────────────────────────────┘
```

**Physical Significance**: The 6 DOF arise from 3 spatial dimensions times 2
types of motion (translation + rotation). This is geometrically fundamental:
a rigid body in 3D has exactly 6 DOF (the dimension of the Euclidean group
SE(3)). The match to P1=6 reflects the deep connection between spatial
dimension 3 and perfect number arithmetic.

**Dual mapping**: f=P1 AND gamma=tau/3 simultaneously.

**Grade**: 🟩star -- Exact, physically fundamental (SE(3) group dimension),
dual correspondence. Not merely numerological: the number 6 = 3x2 here
encodes the structure of rigid body motion in 3-space.

---

## THERMO-003: Dulong-Petit Law = P1 Modes per Atom (🟩star)

> The Dulong-Petit law states C_V = 3R per mole of atoms, arising from
> 6 = P1 quadratic energy terms per atom (3 kinetic + 3 potential).

```
  Each atom in a crystal lattice:
    3 kinetic energy terms:    (1/2)m*vx^2, (1/2)m*vy^2, (1/2)m*vz^2
    3 potential energy terms:  (1/2)k*x^2,  (1/2)k*y^2,  (1/2)k*z^2
    ─────────────────────────────────────────
    Total: 6 quadratic terms = P1

  Equipartition: each term contributes (1/2)k_B*T
  Total energy: U = 6 * (1/2)k_B*T = 3k_B*T per atom
  Heat capacity: C_V = dU/dT = 3k_B per atom = 3R per mole

  Number of modes per atom
  │
  6 ┤ ████████████████████ = P1
  5 ┤
  4 ┤
  3 ┤ ██████████ kinetic only
  2 ┤
  1 ┤
  0 ┼─────────────────────
       KE only    KE + PE
```

**Physical Significance**: The Dulong-Petit law is one of the oldest results
in solid state physics (1819). The factor of 6 arises because a 3D harmonic
oscillator has 6 quadratic terms in its Hamiltonian (3 kinetic + 3 potential).
This is the same 6 = dim(SE(3)) from THERMO-002 but now applied to oscillatory
motion rather than rigid body motion.

**Grade**: 🟩star -- Exact, experimentally verified for centuries, fundamental
to solid state physics. The P1=6 here is genuinely structural (3D oscillator).

---

## THERMO-004: Stefan-Boltzmann T^4 = T^tau (🟩)

> The Stefan-Boltzmann law states radiated power j = sigma_SB * T^4.
> The exponent 4 = tau(6).

```
  Stefan-Boltzmann law:  j = sigma_SB * T^4
  Exponent = 4 = tau(6)

  Derivation chain:
    Planck spectrum integration -> integral over nu^3 / (exp(hnu/kT) - 1)
    Substitution x = hnu/kT -> T^4 * integral(x^3/(e^x - 1))
    The x^3 factor comes from: nu^2 (density of states) * nu (energy per mode)
    So exponent = 2 + 1 + 1 = 4 (from 3D + Planck)

  T dependence of blackbody radiation
  │
  │                          ╱
  │                        ╱
  │                      ╱  j ~ T^4 = T^tau
  │                   ╱╱
  │               ╱╱
  │          ╱╱╱
  │     ╱╱╱╱
  │ ╱╱╱╱
  ┼──────────────────── T
```

**Assessment**: The T^4 exponent arises from integrating the Planck distribution
in 3D. In d dimensions, the Stefan-Boltzmann law would give T^(d+1). So the
exponent 4 = 3+1, encoding spatial dimension d=3 plus one power from the
energy-frequency relation. Writing this as tau(6) is correct but the exponent
is really "d+1 for d=3," not specific to n=6 arithmetic.

**Grade**: 🟩 -- Exact match, but the origin is dimensional (d+1=4), not
number-theoretic. The connection to tau(6) is real arithmetic but not deep.

---

## THERMO-005: Monatomic Gas gamma = sopfr/3 (🟩)

> For a monatomic ideal gas, gamma = C_p/C_v = 5/3.
> This equals sopfr(6)/3 = 5/3.

```
  Monatomic gas (He, Ne, Ar):
    f = 3 (translational DOF only)
    C_V = (3/2)R
    C_P = (5/2)R
    gamma = C_P/C_V = 5/3

  n=6 decomposition:
    gamma = 5/3 = sopfr(6) / (sigma(6)/tau(6))
          = sopfr / (sigma/tau)

  Alternative:
    gamma = 5/3 = sopfr(6) / 3
    where 3 = spatial dimension = sigma(6)/tau(6) = 12/4

  Experimental values:
    He:  gamma = 1.664  (theory: 1.6667)
    Ne:  gamma = 1.667
    Ar:  gamma = 1.667
    Excellent agreement with 5/3
```

**Assessment**: gamma = 5/3 = (f+2)/f for f=3 DOF. The fraction 5/3 happens
to equal sopfr/3. However, sopfr=5 and the denominator 3 are both small integers
that arise independently (sopfr from prime factorization, 3 from spatial dimension).
The decomposition into n=6 functions is arithmetically valid but may be coincidental.

**Grade**: 🟩 -- Exact, experimentally confirmed to high precision, but the
n=6 connection is somewhat superficial (5 and 3 arise independently).

---

## THERMO-006: Diatomic Gas gamma = (P1+1)/sopfr (🟩)

> For a diatomic ideal gas at room temperature, gamma = 7/5.
> This equals (P1+1)/sopfr(6) = 7/5.

```
  Diatomic gas (N2, O2, H2):
    f = 5 (3 translational + 2 rotational)
    C_V = (5/2)R
    C_P = (7/2)R
    gamma = 7/5 = 1.400

  n=6 decomposition:
    gamma = 7/5 = (P1 + 1) / sopfr(6) = 7/5

  Experimental values:
    N2:  gamma = 1.404
    O2:  gamma = 1.395
    H2:  gamma = 1.410
    Agreement at ~1% level

  Complete gamma ladder:
  gamma │
   1.67 ┤ ● monatomic    5/3 = sopfr/3
   1.40 ┤ ● diatomic     7/5 = (P1+1)/sopfr
   1.33 ┤ ● polyatomic   4/3 = tau/3
        ┼─────────────────────────── f (DOF)
          3       5       6
```

**Assessment**: f=5=sopfr for diatomic gas, and the numerator 7=P1+1. The
"+1" construction is a mild ad hoc adjustment. However, the complete gamma
ladder (5/3, 7/5, 4/3) ALL decomposing into n=6 functions is more striking
than any single case. See THERMO-007 for the unified view.

**Grade**: 🟩 -- Exact, with the caveat that the "+1" in P1+1 is ad hoc.

---

## THERMO-007: Complete Gamma Ladder = n=6 Arithmetic (🟧star)

> All three heat capacity ratios for ideal gases decompose simultaneously
> into n=6 arithmetic functions.

```
  ┌──────────────────────────────────────────────────────────┐
  │  THE GAMMA LADDER                                        │
  │                                                          │
  │  Gas Type     f    gamma    n=6 Form        Components   │
  │  ─────────────────────────────────────────────────────── │
  │  Monatomic    3    5/3      sopfr/3          5/3         │
  │  Diatomic     5    7/5      (P1+1)/sopfr     7/5         │
  │  Polyatomic   6    4/3      tau/3            4/3         │
  │                                                          │
  │  DOF values:  3 = sigma/tau                              │
  │               5 = sopfr                                  │
  │               6 = P1                                     │
  │                                                          │
  │  Gamma numerators:  5 = sopfr                            │
  │                     7 = P1 + 1                           │
  │                     4 = tau                               │
  │                                                          │
  │  Gamma denominators: 3 = sigma/tau = P1/phi              │
  │                      5 = sopfr                           │
  │                      3 = sigma/tau                       │
  └──────────────────────────────────────────────────────────┘

  Consistency check:
    gamma_mono * gamma_di * gamma_poly
    = (5/3)(7/5)(4/3)
    = 140/45 = 28/9 = P2/9 = P2/(sigma/tau)^2

  Product of all three gammas involves P2 = 28, the second perfect number!
```

**Assessment**: Individually, each gamma decomposition is somewhat trivial
(small integers). But the SIMULTANEOUS decomposition of all three gammas,
plus the DOF values (3, 5, 6) mapping to (sigma/tau, sopfr, P1), plus the
product involving P2=28, is collectively more impressive. The probability
of this triple coincidence needs careful estimation.

**Coincidence estimate**: Three independent fractions from {1,...,12} pool.
P(all three map to n=6 functions) ~ (6/12)^6 ~ 1/64. Not extraordinary
but notable.

**Grade**: 🟧star -- The individual mappings are weak (small integers), but
the collective pattern across all three gas types is structurally suggestive.

---

## THERMO-008: Debye T^3 Law Exponent = sigma/tau (⚪)

> The Debye low-temperature heat capacity law gives C_V ~ T^3.
> The exponent 3 = sigma(6)/tau(6) = 12/4.

```
  Debye law: C_V = (12/5) * pi^4 * N * k_B * (T/Theta_D)^3

  Exponent = 3 = sigma/tau = 12/4

  Origin: In d dimensions, C_V ~ T^d at low temperature.
  For d=3: C_V ~ T^3
```

**Assessment**: The exponent 3 IS the spatial dimension d. Writing d=3 as
sigma/tau=12/4 adds no explanatory power. Every appearance of "3" in physics
can be written this way.

**Grade**: ⚪ -- Trivially correct. The exponent 3 is the spatial dimension,
not a number-theoretic quantity. Mapping d=3 to sigma/tau is meaningless.

---

## THERMO-009: Six-Vertex Model = P1 Configurations (🟩star)

> The six-vertex model, one of the most important exactly solvable models
> in statistical mechanics, has exactly 6 = P1 allowed vertex configurations.

```
  THE SIX-VERTEX MODEL (Ice-type model)

  Square lattice with arrows on edges.
  Ice rule: exactly 2 arrows point in, 2 point out at each vertex.

  The 6 allowed configurations:

    Type 1:        Type 2:        Type 3:
    ↑              ↓              ↑
  →─┼─→          ←─┼─←          ←─┼─→
    ↓              ↑              ↓

    Type 4:        Type 5:        Type 6:
    ↓              ↑              ↓
  →─┼─←          →─┼─←          ←─┼─→
    ↑              ↑              ↓

  Count = 6 = P1

  Why exactly 6?
    4 edges, each with 2 states = 16 total configurations
    Ice rule (2-in, 2-out) selects C(4,2) = 6

  C(4,2) = C(tau, phi) = 6 = P1 !!!
```

**Mathematical Structure**: The six-vertex model is solved by the Bethe ansatz
and is connected to quantum groups, the Yang-Baxter equation, and random matrix
theory. The number of allowed vertices = C(4,2) = C(tau,phi) = 6 = P1 is not
accidental but reflects the ice rule constraint on a square lattice.

The derivation chain: tau edges per vertex, phi states per edge in the
constrained system, C(tau, phi) = P1 vertices allowed.

**Significance**: The six-vertex model is considered "perhaps the most important
exactly solvable model in statistical mechanics" (Reshetikhin). Its exact
solvability via Bethe ansatz connects to deep mathematical structures. That
the vertex count equals the first perfect number through C(tau,phi)=P1 is
a genuine structural relationship.

**Grade**: 🟩star -- Exact, mathematically deep (Bethe ansatz, Yang-Baxter),
and the C(tau,phi)=P1 derivation gives a non-trivial explanation. This is
not just "6 happens to appear" -- the combinatorial origin links to n=6.

---

## THERMO-010: 2D Ising beta = 1/(phi*tau) (🟩)

> The 2D Ising model order parameter exponent beta = 1/8.
> This equals 1/(phi(6)*tau(6)) = 1/(2*4) = 1/8.

```
  2D Ising critical exponents (exact, Onsager 1944):

  Exponent   Value     n=6 decomposition         Match
  ─────────────────────────────────────────────────────
  alpha      0         0                          trivial
  beta       1/8       1/(phi*tau)                exact
  gamma      7/4       (P1+1)/tau                 exact*
  delta      15        (sigma+sigma/tau)-1=15?    forced
  nu         1         sigma/sigma                trivial
  eta        1/4       1/tau                      exact

  * gamma = 7/4: requires P1+1=7, same ad hoc "+1" as THERMO-006

  beta = 1/8:
    8 = phi * tau = 2 * 4
    beta = 1/(phi*tau)

  eta = 1/4:
    4 = tau
    eta = 1/tau
```

**Assessment**: beta=1/8 and eta=1/4 have clean decompositions. gamma=7/4
requires the ad hoc P1+1. delta=15 and nu=1 are forced or trivial. The
meaningful matches are beta and eta.

**Grade**: 🟩 -- beta = 1/(phi*tau) is exact and non-trivial (product of
two independent n=6 functions). eta = 1/tau is simpler but also exact.

---

## THERMO-011: 2D Ising Exponent Sum and Scaling Relations (🟧)

> The Rushbrooke scaling relation alpha + 2*beta + gamma = 2 can be
> rewritten in n=6 arithmetic.

```
  Rushbrooke relation:
    alpha + 2*beta + gamma = 2

  In n=6 terms:
    0 + 2/(phi*tau) + (P1+1)/tau = 2
    0 + 2/8 + 7/4 = 2
    0 + 1/4 + 7/4 = 2  CHECK

  Widom relation:
    gamma = beta*(delta - 1)
    7/4 = (1/8)*(15 - 1) = (1/8)*14 = 14/8 = 7/4  CHECK

  Fisher relation:
    gamma = nu*(2 - eta)
    7/4 = 1*(2 - 1/4) = 7/4  CHECK

  Hyperscaling (d=2):
    d*nu = 2 - alpha
    2*1 = 2 - 0 = 2  CHECK

  All four scaling relations satisfied with n=6 decompositions.
```

**Assessment**: The scaling relations are constraints, so once beta and gamma
match, the others follow automatically. This is not 4 independent confirmations
but rather 2 independent matches (beta, eta) propagated through constraints.

**Grade**: 🟧 -- Correct and self-consistent, but the scaling relations
reduce the independent information content. Only beta and eta are truly
independent matches.

---

## THERMO-012: Ising Upper Critical Dimension = tau (🟧)

> The upper critical dimension of the Ising universality class is d_c = 4 = tau(6).
> Above d=4, mean field theory becomes exact.

```
  Upper critical dimension by universality class:

  Model              d_c    n=6?
  ───────────────────────────────
  Ising (phi^4)      4      tau(6)
  Tricritical         3      sigma/tau
  Percolation         6      P1 !!
  Self-avoiding walk  4      tau(6)
  Lee-Yang            6      P1 !!

  d_c(Ising) = tau(6) = 4

  Why d_c = 4:
    The phi^4 coupling has dimension [g] = 4 - d
    g is relevant when d < 4, marginal at d = 4, irrelevant when d > 4
    This is purely dimensional analysis in field theory.
```

**Assessment**: d_c=4 for Ising is a dimensional analysis result from phi^4
field theory. The match to tau(6) is arithmetically exact but the origin is
"4-d" scaling, not number theory. However, note that percolation has d_c=6=P1,
which is separately interesting (see SLE_6 connections in other documents).

**Grade**: 🟧 -- Exact match. The percolation d_c=6=P1 echo adds interest,
but d_c=4 for Ising is fundamentally about phi^4 field theory dimensions.

---

## THERMO-013: Landau Free Energy = Quartic = tau Power (⚪)

> Landau theory expands free energy as F = a*t*phi^2 + b*phi^4.
> The leading nonlinear term is phi^4 = phi^tau.

```
  Landau free energy expansion:

  F(phi) = F_0 + a(T-Tc)*phi^2 + b*phi^4 + ...

  Powers present: 0, 2, 4
    phi^2 exponent = 2 = phi(6)
    phi^4 exponent = 4 = tau(6)

  For first-order transitions (negative phi^4):
  F(phi) = a*phi^2 - b*phi^4 + c*phi^6

    phi^6 exponent = 6 = P1 !!

  Power sequence: 2, 4, 6 = phi, tau, P1
```

**Assessment**: The even powers (2, 4, 6) in the Landau expansion arise from
the Z2 symmetry phi -> -phi. Only even powers are allowed, so the sequence
2, 4, 6 is simply "the first three even numbers." Mapping these to phi, tau, P1
is trivially true for ANY sequence of first three even numbers, regardless of
n=6. This is not a structural connection.

**Grade**: ⚪ -- The sequence 2, 4, 6 is forced by Z2 symmetry (even powers
only). No information content in the n=6 mapping.

---

## THERMO-014: Avogadro Coefficient ~ P1 (⚪)

> Avogadro's number N_A = 6.02214076 x 10^23.
> The leading coefficient 6.022... is close to P1 = 6.

```
  N_A = 6.02214076 x 10^23  (exact, defined 2019)

  Leading coefficient: 6.022...
  P1 = 6
  Deviation: (6.022 - 6)/6 = 0.37%

  But: the coefficient depends on the unit system!
    In CGS or natural units, N_A has a different numerical coefficient.
    The value 6.022 x 10^23 is specific to the gram-mole convention.
```

**Assessment**: The coefficient 6.022 is an artifact of defining the mole
relative to 12 grams of carbon-12 (historical). In a different unit system,
the coefficient would be completely different. Since 2019, N_A is defined
as exactly 6.02214076 x 10^23, but this exact value was chosen to match the
previous experimental value, which itself depended on the gram definition.

**Grade**: ⚪ -- Unit-dependent. The "6" in Avogadro's number is a consequence
of the CGS/SI unit convention, not physics. Meaningless as a P1 connection.

---

## THERMO-015: Boltzmann Entropy Formula Partition = sigma (🟧)

> For a perfect crystal of 6 atoms with 2 states each, W = 2^6 = M6+1 = 64.
> S = k_B * ln(64) = k_B * ln(2^P1) = P1 * k_B * ln(2).

```
  Boltzmann entropy: S = k_B * ln(W)

  For P1 = 6 two-state particles:
    W = 2^P1 = 2^6 = 64 = M6 + 1
    S = k_B * ln(64) = 6 * k_B * ln(2)
    S/k_B = P1 * ln(phi) = P1 * ln(2)

  Entropy per particle: s = k_B * ln(2)

  More generally, for N particles with q states:
    S = N * k_B * ln(q)
    When N=P1, q=phi: S = P1 * k_B * ln(phi)

  ┌──────────────────────────────────────────────┐
  │  Entropy landscape for 6 binary spins        │
  │                                              │
  │  Configuration     W        S/k_B            │
  │  All aligned       1        0                │
  │  1 flipped         6        ln(6) = ln(P1)   │
  │  2 flipped        15        ln(15)           │
  │  3 flipped        20        ln(20)  (max)    │
  │  All random       64        ln(64)           │
  │                                              │
  │  W(1 flip) = C(6,1) = 6 = P1                │
  │  W(total)  = 2^6 = 64 = M6 + 1              │
  └──────────────────────────────────────────────┘
```

**Assessment**: Setting N=6 and q=2 is a specific choice, not a universal
result. However, the structure is self-consistent: C(P1,1)=P1 microstates
for one excitation, and the maximum entropy state has exactly P1*ln(2) bits.
This is a valid illustration of how P1=6 organizes a spin system, even if
the choice of N=6 is imposed rather than derived.

**Grade**: 🟧 -- Self-consistent construction, but relies on choosing N=P1.
Interesting as a pedagogical model, not as a discovery.

---

## THERMO-016: Equipartition Half-Integer Pattern (⚪)

> The equipartition theorem assigns (1/2)k_B*T per quadratic DOF.
> The factor 1/2 = the Golden Zone upper boundary = Riemann critical line.

```
  Equipartition: <E_i> = (1/2) * k_B * T

  1/2 appears throughout thermodynamics:
    - Energy per DOF: (1/2)k_B*T
    - Mean field nu: 1/2
    - Mean field beta: 1/2
    - Virial theorem: <KE> = (1/2)<PE> for harmonic

  1/2 = Golden Zone upper = sigma_-1(6) / tau(6)... etc.
```

**Assessment**: 1/2 is the most common fraction in all of physics. It appears
in equipartition for the simple reason that quadratic forms have exponent 2.
Connecting 1/2 to n=6 arithmetic adds no insight whatsoever.

**Grade**: ⚪ -- Ubiquitous constant. Every occurrence of 1/2 in physics
cannot be claimed as an n=6 connection.

---

## THERMO-017: 3D Ising nu ~ 0.630 ~ P1*sopfr/P2*phi (⚪)

> The 3D Ising correlation length exponent nu = 0.6300(5).
> Attempting decomposition: P1*sopfr / (P2*phi) = 30/56 = 0.5357. No match.
> Alternative: sigma/(sigma+P1+1) = 12/19 = 0.6316. Close but forced.

```
  3D Ising critical exponents (conformal bootstrap, 2025):

  Exponent   Value          Attempted n=6 form       Error
  ──────────────────────────────────────────────────────────
  nu         0.6300(5)      12/19 = 0.6316           0.25%
  eta        0.0362(5)      --                       no match
  beta       0.3265(3)      1/e = 0.3679             12.7%
  gamma      1.237(2)       sigma*sopfr/P2*phi?      no clean form
  delta      4.789(2)       --                       no match

  nu ~ 12/19: requires 19, which is not a standard n=6 function.
  beta ~ 1/e: interesting echo of Golden Zone center, but 12.7% off.
```

**Assessment**: Unlike the 2D Ising model (exact rational exponents), the 3D
Ising exponents are irrational numbers. They do not decompose cleanly into
rational combinations of n=6 functions. This is an honest negative result.

**Grade**: ⚪ -- No clean match. The 3D Ising exponents resist n=6 decomposition.
This is expected: they arise from a non-trivial CFT, not simple arithmetic.

---

## THERMO-018: Mean Field Exponents = Simplest n=6 Fractions (🟧)

> Mean field critical exponents use only the simplest n=6 values:
> 0, 1/2, 1, 3 -- all expressible as ratios of {1, phi, sigma/tau, P1/phi}.

```
  Mean field exponents:

  Exponent   Value    n=6 form
  ────────────────────────────────
  alpha      0        0
  beta       1/2      1/phi = phi_-1(6)/phi(6)
  gamma      1        phi/phi = tau/tau = ...
  delta      3        sigma/tau = 12/4
  nu         1/2      1/phi
  eta        0        0

  The only non-trivial values are:
    1/2 = 1/phi(6)
    3   = sigma(6)/tau(6)

  ┌───────────────────────────────────────────────────┐
  │  Mean field as "zeroth order" n=6:                │
  │                                                   │
  │  beta_MF = 1/phi           beta_2D = 1/(phi*tau)  │
  │  delta_MF = sigma/tau      delta_2D = 3*sopfr     │
  │  nu_MF = 1/phi             nu_2D = 1              │
  │                                                   │
  │  2D Ising = "dressed" mean field with tau, sopfr   │
  │  corrections from fluctuations                    │
  └───────────────────────────────────────────────────┘
```

**Assessment**: Mean field exponents are derived from Landau theory and use
only {0, 1/2, 1, 3}. These are the simplest possible rational values. The
observation that 2D Ising exponents introduce tau and sopfr as "corrections"
to mean field values is a potentially interesting organizational principle,
but it could be post-hoc pattern fitting.

**Grade**: 🟧 -- The "mean field = simplest n=6, exact = dressed n=6"
interpretation is suggestive but needs rigorous testing with other models.

---

## THERMO-019: Rushbrooke Sum = phi(6) = 2 (🟧)

> The Rushbrooke scaling relation states alpha + 2*beta + gamma = 2.
> The sum equals phi(6) = 2 for ALL universality classes (exact relation).

```
  Rushbrooke relation: alpha + 2*beta + gamma = 2 = phi(6)

  Universality class   alpha    2*beta   gamma    Sum
  ──────────────────────────────────────────────────────
  Mean field           0        1        1        2 = phi
  2D Ising             0        1/4      7/4      2 = phi
  3D Ising             0.110    0.653    1.237    2 = phi
  3D XY                -0.015   0.697    1.318    2 = phi
  3D Heisenberg        -0.134   0.741    1.393    2 = phi
  Percolation (d=2)    -2/3     5/36*2   43/18    2 = phi

  The sum is ALWAYS 2 = phi(6), regardless of universality class!

  ┌────────────────────────────────────────────────┐
  │  This is a UNIVERSAL constraint, not a         │
  │  coincidence. Rushbrooke is exact (proven from  │
  │  thermodynamic stability).                     │
  │                                                │
  │  But: the sum = 2 because of dimensional       │
  │  analysis (extensive vs intensive scaling),     │
  │  not because of number theory.                 │
  └────────────────────────────────────────────────┘
```

**Assessment**: The Rushbrooke sum = 2 is a deep result, but 2 = phi(6) is
also the most common small integer in physics. The constraint comes from
thermodynamic consistency (Gibbs-Duhem relation), not from perfect number
arithmetic. Still, the universality of the sum phi(6) across ALL critical
phenomena is noteworthy as a pattern.

**Grade**: 🟧 -- Universal and exact, but the origin is thermodynamic
scaling, not n=6 arithmetic. The phi(6)=2 label is decorative.

---

## THERMO-020: Percolation Upper Critical Dimension = P1 (🟩)

> The upper critical dimension for percolation is d_c = 6 = P1.
> This is the same P1=6 that governs SLE_6 (proven by Smirnov, Fields Medal 2010).

```
  Upper critical dimensions in statistical mechanics:

  Model                d_c     n=6 function
  ──────────────────────────────────────────
  Ising/phi^4          4       tau(6)
  Percolation          6       P1 !!
  Self-avoiding walk   4       tau(6)
  Lee-Yang edge        6       P1 !!
  Branched polymer     8       phi*tau = phi(6)*tau(6)

  PERCOLATION: d_c = 6 = P1

  Why d_c = 6 for percolation:
    The upper critical dimension is determined by when the
    mean-field (Bethe lattice) exponents become exact.
    For percolation, the relevant field theory has coupling
    dimension [g] = 6 - d, making d_c = 6.

  Connection to SLE_6:
    Schramm-Loewner Evolution with kappa = 6
    Critical percolation interfaces in 2D are SLE_6 curves
    Cardy's formula (proven by Smirnov 2001): crossing probabilities
    The parameter kappa = 6 = P1 is EXACT and PROVEN

  ┌──────────────────────────────────────────────────────┐
  │  PERCOLATION-P1 CORRESPONDENCE                       │
  │                                                      │
  │  d_c = 6 = P1         (upper critical dimension)     │
  │  SLE kappa = 6 = P1   (conformal interface)          │
  │  Cardy formula: exact at P1                          │
  │                                                      │
  │  Two independent appearances of 6 in percolation:    │
  │  one from field theory (d_c), one from conformal     │
  │  invariance (SLE). Both equal P1.                    │
  └──────────────────────────────────────────────────────┘
```

**Physical Significance**: Percolation is the simplest geometric phase
transition. The fact that its upper critical dimension equals P1=6 is
well-established physics. Combined with SLE_6 (a completely independent
mathematical framework), percolation shows P1=6 appearing from two
different directions in the same physical system.

**Grade**: 🟩 -- Exact, proven, and the dual appearance (d_c=6 from field
theory, SLE_6 from conformal invariance) makes this one of the strongest
connections in the document.

---

## Summary Table

| # | Hypothesis | n=6 Form | Grade | Notes |
|---|-----------|----------|-------|-------|
| 001 | 4 laws of thermodynamics | tau=4 | 🟧 | Human convention |
| 002 | Polyatomic 6 DOF | P1=6 (SE(3)) | 🟩star | Geometrically fundamental |
| 003 | Dulong-Petit 6 modes | P1=6 | 🟩star | 3D oscillator, centuries verified |
| 004 | Stefan-Boltzmann T^4 | T^tau | 🟩 | Exact but dimensional (d+1) |
| 005 | Monatomic gamma=5/3 | sopfr/3 | 🟩 | Exact, experimental |
| 006 | Diatomic gamma=7/5 | (P1+1)/sopfr | 🟩 | Ad hoc +1 |
| 007 | Complete gamma ladder | All three map | 🟧star | Collective pattern |
| 008 | Debye T^3 exponent | sigma/tau=3 | ⚪ | Just spatial dimension |
| 009 | Six-vertex model | C(tau,phi)=P1 | 🟩star | Deep (Bethe ansatz) |
| 010 | 2D Ising beta=1/8 | 1/(phi*tau) | 🟩 | Exact, non-trivial product |
| 011 | Ising scaling relations | Self-consistent | 🟧 | Propagated, not independent |
| 012 | Upper critical dim = 4 | tau | 🟧 | Dimensional analysis |
| 013 | Landau phi^4 = phi^tau | Even powers | ⚪ | Z2 symmetry forces this |
| 014 | Avogadro ~ 6.022 | ~P1 | ⚪ | Unit-dependent |
| 015 | Boltzmann entropy N=6 | P1*k_B*ln(2) | 🟧 | Self-consistent but imposed |
| 016 | Equipartition 1/2 | 1/phi | ⚪ | Ubiquitous constant |
| 017 | 3D Ising exponents | No clean form | ⚪ | Honest negative result |
| 018 | Mean field = simplest | 1/phi, sigma/tau | 🟧 | Organizational principle |
| 019 | Rushbrooke sum = 2 | phi(6) | 🟧 | Universal but dimensional |
| 020 | Percolation d_c = 6 | P1 (+ SLE_6) | 🟩 | Dual proof, Fields Medal |

### Grade Distribution

```
  🟩star:  3  (THERMO-002, 003, 009)
  🟩:      4  (THERMO-004, 005, 006, 010)
  🟧star:  1  (THERMO-007)
  🟧:      6  (THERMO-001, 011, 012, 015, 018, 019)
  ⚪:      6  (THERMO-008, 013, 014, 016, 017)
  ─────────
  Total:  20

  Strong (>= 🟩):     8/20 = 40%  (includes star)
  Meaningful (>= 🟧): 14/20 = 70%
  No match (⚪):       6/20 = 30%
```

### Structural Hit Rate

- Strong matches (>= 🟩): 8/20 = 40%
- Meaningful matches (>= 🟧): 14/20 = 70%
- No match (⚪): 6/20 = 30%

### Strongest Results (Top 3)

1. **THERMO-009**: Six-vertex model. C(tau,phi) = C(4,2) = 6 = P1.
   Combinatorial derivation, connected to Yang-Baxter equation and quantum groups.

2. **THERMO-002/003**: Polyatomic 6 DOF and Dulong-Petit 6 modes.
   Both trace to dim(SE(3)) = 6, the fundamental geometric fact that rigid bodies
   in 3D have 6 degrees of freedom.

3. **THERMO-020**: Percolation d_c = P1 = 6, independently confirmed by SLE_6.
   Two completely different mathematical frameworks (field theory and conformal
   invariance) both yield P1 for the same physical system.

### Honest Assessment

The thermodynamics/statistical mechanics domain shows a split:

**Genuine structural connections** (3 results): The six-vertex model, rigid body
DOF, and percolation critical dimension are legitimate appearances of P1=6
in physics, traceable to combinatorics (C(4,2)), geometry (SE(3)), and field
theory ([g] = 6-d) respectively.

**Dimensional echoes** (4 results): T^4, gamma=5/3, gamma=7/5, beta=1/8 are
exact matches where the numbers arise from spatial dimension d=3 and simple
counting. The n=6 decompositions are arithmetically correct but the causation
runs "d=3 implies these fractions" rather than "n=6 implies these fractions."

**False positives** (6 results): Debye T^3, Landau even powers, Avogadro,
equipartition 1/2, 3D Ising, and Rushbrooke sum = 2 are either trivially
correct, unit-dependent, or honest failures to match.

**Key insight**: The STRONGEST connections (six-vertex, DOF, percolation)
share a common thread: they involve COMBINATORIAL or GEOMETRIC counting
where P1=6 emerges from structure, not from tuning small integers. This
distinguishes genuine n=6 physics from post-hoc numerology.

---

## Verification Directions

1. **Six-vertex model**: Explore whether the Boltzmann weights of the 6 vertices
   decompose into n=6 arithmetic at criticality (antiferroelectric point).
2. **Eight-vertex model**: Baxter's exact solution has 8 = phi*tau vertices.
   Do the additional 2 vertices correspond to phi(6)?
3. **Percolation**: Test whether 3D percolation exponents at d_c=6 show n=6
   structure in their mean-field values.
4. **BKT transition**: The XY model eta=1/4=1/tau at the BKT transition --
   verify if other BKT exponents decompose similarly.
5. **Potts model**: q-state Potts model at q=P1=6 -- is this critical point
   special? (q_c=4 for 2D: first-order transition for q>4.)

---

## References

- Onsager, L. (1944). Crystal statistics. Physical Review, 65, 117.
- Baxter, R.J. (1982). Exactly Solved Models in Statistical Mechanics.
- Smirnov, S. (2001). Critical percolation in the plane. C. R. Acad. Sci. Paris.
- Kos, F. et al. (2025). Bootstrapping the 3d Ising stress tensor. JHEP.
- Wikipedia: Critical exponents, Six-vertex model, Heat capacity ratio.
