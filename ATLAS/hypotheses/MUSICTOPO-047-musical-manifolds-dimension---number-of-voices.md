# MUSICTOPO-047: Musical Manifolds: Dimension = Number of Voices

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The configuration space of n independent voices is an n-dimensional manifold (specifically T^n, the n-torus). The musically standard voice counts 2 = phi(6), 3 = P1/2, and 4 = tau(6) give manifolds of dimension phi(6), P1/2, and tau(6) respectively.

## Background

Each independent voice contributes one degree of freedom (its pitch class),
so n voices give an n-dimensional configuration space. The standard
voice configurations in Western music correspond to n=6 constants.

## Verification

```
  Voice configurations:
    Monophony:   1 voice  -> T^1 = S^1     (dim 1)
    Counterpoint: 2 voices -> T^2           (dim phi(6) = 2)  EXACT
    Triadic:     3 voices -> T^3           (dim P1/2 = 3)  EXACT
    SATB:        4 voices -> T^4           (dim tau(6) = 4)  EXACT
    Quintet:     5 voices -> T^5           (dim sopfr(6) = 5)  EXACT
    Sextet:      6 voices -> T^6           (dim P1 = 6)  EXACT
```

## ASCII Dimension Ladder

```
  dim = P1 = 6:  T^6  (sextet)        ******
  dim = sopfr = 5: T^5 (quintet)      *****
  dim = tau = 4: T^4  (SATB quartet)  ****
  dim = P1/2 = 3: T^3 (triad)         ***
  dim = phi = 2: T^2  (counterpoint)   **
  dim = 1:       T^1  (monophony)      *

  Each * = one S^1 factor (one voice)
```

## Configuration Table

| Ensemble | Voices | Dimension | n=6 Constant |
|----------|--------|-----------|-------------|
| Solo | 1 | 1 | -- |
| Duo | 2 | 2 | phi(6) |
| Trio | 3 | 3 | P1/2 |
| Quartet | 4 | 4 | tau(6) |
| Quintet | 5 | 5 | sopfr(6) |
| Sextet | 6 | 6 | P1 |

## Interpretation

The standard Western ensemble sizes {2, 3, 4, 5, 6} map perfectly to
{phi(6), P1/2, tau(6), sopfr(6), P1}. This is a complete enumeration:
every n=6 arithmetic function value appears as a musically canonical voice count.
