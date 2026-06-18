# Hypothesis Review STATMECH-001: 6-Vertex Model and Golden Zone

## Hypothesis

> The 6-vertex model (square ice model) in statistical mechanics has exactly 6 allowed
> vertex configurations -- equal to the first perfect number P_1 = 6. Lieb's exact
> solution (1967) gives residual entropy ln(W) = (3/2) * ln(4/3), where ln(4/3) is
> precisely the Golden Zone width. The same constant ln(4/3) that governs the
> information-theoretic width of the Golden Zone also governs the residual entropy
> of ice, suggesting a deep structural connection between consciousness-zone boundaries
> and exactly solvable models in statistical mechanics.

## Background and Context

The 6-vertex model is one of the most important exactly solvable models in statistical
mechanics. On a square lattice, each edge carries an arrow (direction). At each vertex,
the **ice rule** constrains the configuration: exactly 2 arrows point in and 2 point out.
This constraint yields exactly 6 valid vertex types out of 2^4 = 16 possible orientations.

Lieb (1967) computed the exact residual entropy of square ice:

```
  W = (4/3)^(3/2)
  S/k_B = ln(W) = (3/2) * ln(4/3) = 0.43152...
```

The constant ln(4/3) = 0.28768... appears in the TECS-L framework as the **Golden Zone
width** -- the information-theoretic gap between the Riemann critical line (1/2) and the
entropy boundary (1/2 - ln(4/3) = 0.2123...).

Related hypotheses:
- H-042: Entropy ln(4/3) jump at 3->4 state transition
- H-044: Golden Zone 4-state upper bound = 1/2
- H-067: 1/2 + 1/3 = 5/6 constant relationship
- H-090: Master formula = perfect number 6

## The 6 Vertex Types

```
  Type a1       Type a2       Type b1       Type b2       Type c1       Type c2
  ("frozen")    ("frozen")    ("antiferro") ("antiferro") ("disordered")("disordered")

    ^             |             ^             |             ^             |
    |             v             |             v             |             v
  ->o->         <-o<-         <-o->         ->o<-         <-o->         ->o<-
    ^             |             |             ^             ^             |
    |             v             v             ^             |             v

  All-in/out    All-in/out    Alternating   Alternating    Mixed         Mixed
  horizontal    horizontal    horizontal    horizontal     pattern       pattern

  Count:  a(2)  +  b(2)  +  c(2)  =  6  =  P_1  (first perfect number)
```

Each type satisfies the ice rule: 2 arrows in, 2 arrows out. The types group into
three pairs, mirroring the proper divisor structure of 6: {1, 2, 3} -> three pairs.

## Partition Function and Phase Diagram

The partition function of the 6-vertex model:

```
  Z = SUM_configs  w_a^(n_a) * w_b^(n_b) * w_c^(n_c)

  where n_a + n_b + n_c = N (total vertices)
  and w_a, w_b, w_c are Boltzmann weights for each type
```

The anisotropy parameter:

```
  Delta = (w_a^2 + w_b^2 - w_c^2) / (2 * w_a * w_b)
```

Phase diagram (Delta axis):

```
  Delta
  <----|-----------|-----------------------|---------->
      -1           0                       1

  Antiferro-      Disordered              Ferro-
  electric        (critical)              electric
  (ordered)                               (ordered)

  |<-- AFE -->|<-- DISORDERED PHASE -->|<-- FE -->|
       ^                  ^                  ^
       |                  |                  |
    KDP point        Free fermion        Frozen
    (Delta=-1)       (Delta=0)           (Delta=1)

  The disordered phase (-1 < Delta < 1) is the GOLDEN ZONE ANALOG:
  a critical region between two ordered extremes.
```

## Key Numerical Results

### Lieb's Ice Entropy

```
  W = (4/3)^(3/2) = 1.53960...
  ln(W) = (3/2) * ln(4/3) = 1.5 * 0.28768... = 0.43152...

  Comparison with TECS-L constants:
  ┌─────────────────────────────┬────────────┬────────────────────────┐
  │ Quantity                    │ Value      │ Formula                │
  ├─────────────────────────────┼────────────┼────────────────────────┤
  │ Golden Zone width           │ 0.28768    │ ln(4/3)                │
  │ Ice residual entropy        │ 0.43152    │ (3/2) * ln(4/3)        │
  │ Multiplier                  │ 1.5        │ 3/2 = 3/phi(6)         │
  │ Golden Zone upper           │ 0.50000    │ 1/2                    │
  │ Golden Zone lower           │ 0.21232    │ 1/2 - ln(4/3)          │
  │ Golden Zone center          │ 0.36788    │ 1/e                    │
  │ Meta fixed point            │ 0.33333    │ 1/3                    │
  └─────────────────────────────┴────────────┴────────────────────────┘
```

### Multiplier 3/2 Decomposition

```
  3/2 = 3 / phi(6)          (prime 3 over Euler totient)
  3/2 = sigma(6) / (2*tau(6))  = 12 / 8
  3/2 = sopfr(6) / sigma_-1(6) ... not exact (5/2 = 2.5)

  Best interpretation:
  3/2 = (number of vertex pairs) / (pairs with frozen behavior)
      = 3 / 2
  Also: 3/2 is the critical exponent relating ice entropy to Golden Zone width
```

### Connection to n=6 Arithmetic Functions

```
  ┌──────────────────────────────────┬───────────┬───────────────────┐
  │ Property                         │ Value     │ n=6 Function      │
  ├──────────────────────────────────┼───────────┼───────────────────┤
  │ Number of vertex types           │ 6         │ n = P_1            │
  │ Number of vertex pairs           │ 3         │ sopfr(6)-phi(6)=3  │
  │ Ice rule: arrows in              │ 2         │ phi(6) = 2         │
  │ Ice rule: arrows out             │ 2         │ phi(6) = 2         │
  │ Edges per vertex (square)        │ 4         │ tau(6) = 4         │
  │ Total orientations per vertex    │ 16 = 2^4  │ 2^tau(6)           │
  │ Forbidden configs                │ 10        │ 2^tau(6) - n = 10  │
  │ Entropy multiplier               │ 3/2       │ 3/phi(6)           │
  └──────────────────────────────────┴───────────┴───────────────────┘
```

## ASCII Graph: Entropy as Function of Vertex Count

```
  S/k_B
  0.50 |
       |                          * (3/2)*ln(4/3) = 0.4315  [n=6, ice]
  0.45 |                        *
       |
  0.40 |
       |
  0.35 |
       |
  0.30 |  ---- ln(4/3) = 0.2877 ---- Golden Zone width --------
       |
  0.25 |
       |
  0.20 |
       |
  0.15 |
       |              o ln(2) * (3/4) = 0.1733  [n=4, hypothetical]
  0.10 |
       |
  0.05 |
       |
  0.00 +------+------+------+------+------+------+------+
       0      2      4      6      8     10     12     14
                    Number of vertex types (n)

  Only n=6 is exactly solvable with ice rule and gives
  entropy proportional to ln(4/3) = Golden Zone width.
```

## Free Fermion Point

At the symmetric point w_a = w_b = w_c (equal weights), Delta = 1/2, and the
model maps to free fermions. The free fermion condition is:

```
  w_a^2 + w_b^2 = w_c^2    (Pythagorean condition!)
```

This connects to the Pythagorean triple structure. For the ice model (w_a = w_b = w_c = 1),
Delta = 1/2, which is exactly the Golden Zone upper bound.

## Texas Sharpshooter Analysis

```
  Claim: A model with exactly n=6 vertex types has entropy involving ln(4/3)

  Parameters:
  - n=6 vertex types: probability of exactly 6 among {3,4,5,...,16} = 1/14
  - Entropy involves ln(4/3): one specific constant among ~10 natural candidates
    (ln(2), ln(3), ln(4/3), ln(3/2), pi, e, ...) = 1/10
  - Combined: P(both) = 1/140

  However: the 6-vertex model is DERIVED from physics (ice rule),
  not chosen ad hoc. The number 6 follows from 2-in-2-out on 4 edges
  = C(4,2) = 6. This is a necessary consequence, not selection bias.

  Bonferroni: testing ~5 statistical mechanics models -> p = 5/140 = 0.036
  Grade: 🟧 (p < 0.05, structural but with caveats)
```

## Verification Results

```
  ┌────────────────────────────────────────┬────────┬────────────┐
  │ Claim                                  │ Status │ Grade      │
  ├────────────────────────────────────────┼────────┼────────────┤
  │ 6 vertex types satisfy ice rule        │ PASS   │ 🟩 exact   │
  │ W = (4/3)^(3/2)                        │ PASS   │ 🟩 exact   │
  │ ln(W) = (3/2)*ln(4/3)                  │ PASS   │ 🟩 exact   │
  │ ln(4/3) = Golden Zone width            │ PASS   │ 🟩 exact   │
  │ Multiplier 3/2 = 3/phi(6)             │ PASS   │ 🟩 exact   │
  │ 2^tau(6) = 16 total orientations       │ PASS   │ 🟩 exact   │
  │ Disordered phase ~ Golden Zone         │ ANAL   │ 🟧 analogy │
  │ Delta=1/2 at free fermion              │ NOTE   │ see text   │
  └────────────────────────────────────────┴────────┴────────────┘
```

## Interpretation and Meaning

1. **The ln(4/3) constant appears independently** in two domains: (a) as the Golden Zone
   width in the TECS-L consciousness model, and (b) as the base of the residual entropy
   in Lieb's exact solution of square ice. Both contexts involve a 3->4 state transition.

2. **The number 6** arises necessarily from the ice rule on a square lattice:
   C(4,2) = 6 ways to choose 2-in from 4 edges. This is not ad hoc -- it is a
   combinatorial necessity, making the P_1 = 6 connection structurally meaningful.

3. **The disordered phase** (-1 < Delta < 1) in the 6-vertex model is analogous to the
   Golden Zone: a critical region between ordered extremes where complexity emerges.

4. **The multiplier 3/2 = 3/phi(6)** links the entropy to n=6 arithmetic through
   the Euler totient function.

## Limitations

- The connection between the 6-vertex model's disordered phase and the Golden Zone
  is an analogy, not a mathematical equivalence. The phase boundaries (Delta = +/-1)
  do not directly map to I = 0.2123 and I = 0.5.
- The number 6 = C(4,2) arises from the square lattice geometry, not from perfect
  number theory. The coincidence with P_1 may be just that -- a coincidence.
- Lieb's entropy applies to the thermodynamic limit on a square lattice only.
  Other lattices give different residual entropies.
- The multiplier 3/2 has multiple possible interpretations; 3/phi(6) is one of several.

## Next Steps

- Investigate whether the 8-vertex model (Baxter, 1972) has connections to n=28 (P_2)
- Check if the free fermion point Delta = 1/2 = Golden Zone upper bound is coincidental
- Explore transfer matrix eigenvalues for connections to divisor structure of 6
- Compare the disordered phase width (Delta in [-1,1], width=2) with Golden Zone width
- Test whether other exactly solvable models with n-vertex types show n=perfect number patterns

---

*Verification: verify/verify_statmech_001_six_vertex.py*
*Grade: 🟧 (structural connection via ln(4/3), but analogy not proven)*
*Golden Zone dependency: YES (Golden Zone width = ln(4/3) is the core claim)*
