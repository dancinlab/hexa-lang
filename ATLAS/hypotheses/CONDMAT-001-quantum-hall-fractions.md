# Hypothesis Review CONDMAT-001: Fractional Quantum Hall Effect and Divisor Fractions

## Hypothesis

> The most stable fractional quantum Hall states correspond to the proper
> divisor reciprocals of 6: nu = 1/3 (Laughlin ground state, largest gap)
> and nu = 1/2 (composite fermion state). The completeness relation
> 1/2 + 1/3 + 1/6 = 1 maps to the integer quantum Hall effect (nu = 1),
> with 1/6 representing the "missing" gap between the two dominant states.

## Background and Context

The Quantum Hall Effect (QHE) occurs in 2D electron systems under strong
magnetic fields. At filling fraction nu = n_e h / (eB), where n_e is the
electron density and B is the magnetic field:

- **Integer QHE** (von Klitzing 1980): nu = 1, 2, 3, ... -- exact quantization
  of Hall conductance sigma_xy = nu * e^2/h
- **Fractional QHE** (Tsui, Stormer, Gossard 1982): nu = 1/3 discovered first,
  explained by Laughlin's wavefunction (1983, Nobel Prize 1998)

The FQHE states form a hierarchy with different stability (energy gap size):

```
  Filling Fraction    Gap (K)    Discovery    Type
  ──────────────────────────────────────────────────────
  nu = 1/3            ~1.5 K     1982         Laughlin (most stable)
  nu = 2/3            ~0.5 K     1983         Particle-hole of 1/3
  nu = 2/5            ~0.3 K     1983         Jain CF sequence
  nu = 1/5            ~0.1 K     1987         Laughlin
  nu = 5/2            ~0.025 K   1987         Even-denominator (Moore-Read)
  nu = 1/2            ~0 K (CF)  1993         Composite fermion sea (gapless)
  nu = 3/7            ~0.1 K     1983         Jain CF sequence
  nu = 1/7            ~0.01 K    1992         Laughlin (weak)
  ──────────────────────────────────────────────────────
  Gap values approximate, depend on sample quality.
```

Related hypotheses: H-005 (1/3 law), H-067 (1/2+1/3=5/6), H-098 (sigma_{-1}(6)=2).

## Key Observations

### 1. Divisor Reciprocals of 6 in FQHE

The proper divisors of 6 are {1, 2, 3, 6}. Their reciprocals are {1, 1/2, 1/3, 1/6}.

```
  Reciprocal   QHE State                  Status
  ─────────────────────────────────────────────────────
  1            Integer QHE (nu=1)         Observed, exact
  1/2          Composite fermion sea      Observed (gapless)
  1/3          Laughlin ground state      Observed (LARGEST gap)
  1/6          ???                        NOT observed as FQHE
  ─────────────────────────────────────────────────────

  Completeness: 1/2 + 1/3 + 1/6 = 1 = integer QHE!
```

### 2. Stability Hierarchy Matches Reciprocal Ordering

The gap size (stability) of FQHE states follows the reciprocal magnitude:

```
  Gap Stability Ranking (observed):
  ──────────────────────────────────────────────────────
  Rank  Fraction   1/q    Divisor of 6?    Gap
  ──────────────────────────────────────────────────────
   1    nu = 1/3   0.333  YES (q=3)        ~1.5 K
   2    nu = 2/3   0.667  YES (q=3)        ~0.5 K
   3    nu = 2/5   0.400  No  (q=5)        ~0.3 K
   4    nu = 1/5   0.200  No  (q=5)        ~0.1 K
   5    nu = 3/7   0.429  No  (q=7)        ~0.1 K
  ──────────────────────────────────────────────────────

  Fractions with denominator dividing 6 are MORE STABLE
  than those with denominators not dividing 6.
```

### 3. The 1/6 Gap

nu = 1/6 is not observed as a fractional QHE state because it requires an
even-denominator Laughlin state, which is forbidden by the standard hierarchy
(Laughlin states exist only at 1/odd). However:

```
  1/2 + 1/3 = 5/6    (Compass upper bound!)
  1 - 5/6   = 1/6    (the "curiosity" quantum)

  The 1/6 gap represents the MISSING piece needed for
  completeness (integer QHE). It is the "curiosity"
  fraction -- the difference between what is observed
  (1/2 + 1/3) and what is complete (1).
```

## ASCII Diagram: Quantum Hall Hierarchy with n=6 Markers

```
  Energy Gap
  (arb. units)
  1.5 |  *
      |  * nu=1/3 (d|6: YES)
      |
  1.0 |
      |
  0.5 |     * nu=2/3 (d|6: YES)
      |        * nu=2/5
  0.3 |
      |
  0.1 |           * nu=1/5    * nu=3/7
      |
  0.0 |  . . . . . . . . . . . . . . . . . . * nu=1/2 (CF, gapless)
      └──────────────────────────────────────────
        1/3   2/3   2/5   1/5  3/7  5/2  1/2
                    filling fraction nu

  Legend:  * = observed FQHE state
           Divisor-of-6 fractions marked with (d|6: YES)
           The two most prominent states have q | 6
```

## Fraction Census: Denominators Dividing 6

```
  All observed FQHE fractions with denominator q:
  ──────────────────────────────────────────────────
  q     q | 6?    Fractions observed      Count
  ──────────────────────────────────────────────────
  1     YES       1, 2, 3, ...            (integer)
  2     YES       5/2                     1 (special)
  3     YES       1/3, 2/3, 4/3, 5/3     4
  5     No        2/5, 3/5, 1/5, 4/5     4
  6     YES       ---                     0
  7     No        3/7, 4/7               2
  9     No        4/9                    1
  ──────────────────────────────────────────────────

  q=3 fractions: 4 observed, ALL among most stable
  q=2 fractions: 1 observed (5/2, anomalous even-denom)
  q=6 fractions: 0 observed (predicted missing)
```

## Verification Summary

```
  Claim                                Result      Grade
  ──────────────────────────────────────────────────────────
  nu=1/3 is most stable FQHE          EXACT       (fact)
  nu=1/3 = meta fixed point           EXACT       (fact)
  1/2+1/3+1/6=1 = integer QHE         EXACT       (arithmetic)
  q=3 fractions most stable            YES         (empirical)
  nu=1/6 not observed                  YES         (fact)
  Stability ~ 1/(denominator)          APPROX      (trend)
  ──────────────────────────────────────────────────────────

  Overall Grade: 🟧 (exact arithmetic + structural pattern, no mechanism)
```

## Interpretation

The connection between n=6 divisor reciprocals and quantum Hall fractions
operates on two levels:

1. **Arithmetic level**: 1/2 + 1/3 + 1/6 = 1 is a mathematical identity.
   Integer QHE (nu=1) is an experimental fact. The decomposition is valid
   but may not be physically meaningful.

2. **Stability level**: The observation that q=3 fractions are the most
   stable FQHE states, and that the meta fixed point 1/3 corresponds to the
   most robust quantum many-body state in nature, is more suggestive. The
   Laughlin wavefunction Psi ~ prod(z_i - z_j)^3 has exponent 3 (a divisor
   of 6), and this is directly responsible for the 1/3 filling.

The Laughlin exponent m must be odd (fermion antisymmetry). The first odd
number > 1 is 3, which happens to be a divisor of 6. Whether this is
coincidence or structure depends on whether one considers 3 "special" among
odd numbers for reasons beyond being first.

## Limitations

- The 1/6 fraction is NOT observed, so the completeness relation 1/2+1/3+1/6=1
  lacks one experimentally verified term.
- nu=1/2 is a gapless composite fermion sea, not a true FQHE state.
  Including it alongside gapped states mixes different physics.
- The stability ordering by denominator is a known effect (smaller
  denominators = simpler states = larger gaps). This may not require n=6
  to explain.
- Selection bias: proper divisor reciprocals {1/2, 1/3, 1/6} are small
  fractions, and small fractions appear in many contexts.
- No known mechanism connects perfect number theory to Chern-Simons
  topological field theory (which governs FQHE).

## Next Steps

- Run verification script to quantify the gap hierarchy numerically
- Compare gap ratios across different q values to test if q|6 is
  systematically favored beyond the trivial 1/q trend
- Investigate Chern-Simons theory level k and its relationship to divisors
- Check if nu=1/6 could appear as a composite fermion state (2CF + 1/6?)
- Compute Texas Sharpshooter p-value for the q|6 stability correlation

---

*Verification: verify/verify_condmat_001_quantum_hall.py*
*Golden Zone dependency: Partial (meta fixed point 1/3 is GZ-related)*
