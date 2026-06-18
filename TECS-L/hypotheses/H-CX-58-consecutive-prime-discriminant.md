# H-CX-58: Consecutive-Prime Discriminant and Maximum-Margin 6-Class Classification

**Category:** Cross-Domain (Number Theory x Machine Learning Theory)
**Status:** New hypothesis (unverified)
**Grade:** Pending
**Golden Zone dependency:** NONE for math basis; partial for ML prediction
**Date:** 2026-03-26

---

## Hypothesis

> 6 = 2*3 is the unique semiprime whose prime factors form a unit-discriminant
> quadratic: disc(x^2 - (p+q)x + pq) = (p-q)^2 = 1. This arises because {2,3}
> are the ONLY pair of consecutive integers that are both prime (twin prime at
> distance 1). This predicts that in a 6-class classification problem, the
> optimal linear decision boundary achieves the maximum-margin configuration
> precisely when the two nearest class prototypes are at unit distance in
> representation space -- a condition impossible to achieve with any other
> number of classes derived from a semiprime structure.

---

## Mathematical Basis (Proven, Golden-Zone-independent)

### Prime Factor Discriminant

For any semiprime n = p*q (p < q both prime), consider the monic quadratic
whose roots are the prime factors:

```
  f(x) = (x - p)(x - q) = x^2 - (p+q)x + pq
```

The discriminant of this quadratic is:

```
  disc(f) = (p+q)^2 - 4pq = (p-q)^2
```

This equals 1 if and only if |p - q| = 1.

### Uniqueness Proof

We need |p - q| = 1 with both p and q prime.

If |p-q| = 1, then one of {p, q} is even. The only even prime is 2. So the
pair must be {2, 3} (since 3-2=1 and both are prime).

No other pair of consecutive integers are both prime, because for n > 2, one
of {n, n+1} is even (and thus divisible by 2 > 1, hence not prime unless it IS 2).

Therefore:

```
  disc((x-p)(x-q)) = 1  iff  n = pq = 2*3 = 6

  For ALL other semiprimes:
    n=10=2*5:  disc = (5-2)^2 = 9
    n=15=3*5:  disc = (5-3)^2 = 4
    n=21=3*7:  disc = (7-3)^2 = 16
    n=22=2*11: disc = (11-2)^2 = 81
    n=35=5*7:  disc = (7-5)^2 = 4
    n=77=7*11: disc = (11-7)^2 = 16
```

For n=6 specifically:

```
  f(x) = x^2 - 5x + 6 = (x-2)(x-3)
  disc  = 5^2 - 4*6 = 25 - 24 = 1

  The roots are 2 and 3 (the prime factors of 6)
  The discriminant = 1 = unit = the MINIMUM positive integer
```

### Connection to (n+1)^2 - 4*sigma(n) = 1

An equivalent form uses sigma(n):

```
  (n+1)^2 - 4*sigma(n) = ?

  For n=6: (7)^2 - 4*12 = 49 - 48 = 1

  This is different from the prime-factor discriminant above.
  Let's clarify both:

  Form 1: disc of prime-factor quadratic = (p-q)^2 = 1  for n=pq=6
  Form 2: (n+1)^2 - 4*sigma(n) = 1  for n=6

  Form 2 derivation: sigma(6)=12, so 4*sigma(6) = 48 = 49-1 = 7^2-1 = (n+1)^2-1
  => (n+1)^2 - 4*sigma(n) = 1 is equivalent to sigma(n) = n(n+2)/4

  For n=6: sigma(6) = 6*8/4 = 12 YES
  For perfect numbers sigma(n)=2n: 2n = n(n+2)/4 => 8 = n+2 => n=6 (!)
  So this also uniquely pins n=6 among perfect numbers.
```

### ASCII: Discriminant landscape for semiprimes

```
  Semiprime  | disc = (p-q)^2 | sqrt(disc) = p-q
  n=6  =2*3  |      1         |     1   *** UNIT
  n=10 =2*5  |      9         |     3
  n=15 =3*5  |      4         |     2
  n=21 =3*7  |     16         |     4
  n=22 =2*11 |     81         |     9
  n=33 =3*11 |     64         |     8
  n=35 =5*7  |      4         |     2
  n=55 =5*11 |     36         |     6

  Only n=6 achieves discriminant = 1
  (a perfect square with sqrt = 1)
```

---

## Cross-Domain Prediction

### Maximum-Margin Classification

In Support Vector Machines (SVM), the maximum-margin hyperplane between two
class means mu_1 and mu_2 satisfies:

```
  margin = 2 / ||w||
```

The unit-discriminant condition (p-q=1 for n=6) corresponds to the two nearest
class prototypes being separated by unit distance in feature space BEFORE
projection:

```
  ||mu_2 - mu_1|| = 1  (unit distance between nearest class means)
```

**Prediction:** For a K-class classifier where K has a "natural" factoring,
the maximum-margin geometry is achieved with clean integer spacing ONLY when
K = 6 (the unique semiprime with consecutive prime factors).

### The 6-Class Boundary Uniqueness

For a 6-class problem with classes organized by the 2x3 factor structure:
- Group by factor 2: {even classes} vs {odd classes}
- Group by factor 3: {class mod 3 = 0} vs {= 1} vs {= 2}

The joint structure creates a grid that tiles perfectly in 2D because:

```
  Factor 2 hyperplane: normal n_2, margin 1
  Factor 3 hyperplane: normal n_3, margin 1
  Both have UNIT discriminant in their respective factorizations:
    (2-? well, single prime, so 2 alone is prime)

  The 2x3 product structure uniquely creates orthogonal boundary conditions
```

More concretely: a 6-class classifier can be decomposed as a binary
(2-class, factor=2) AND a ternary (3-class, factor=3) classifier.
The binary and ternary classifiers operate at "unit distance" from each other
because gcd(2,3)=1 and lcm(2,3)=6. This is a consequence of the coprimality
of the factors, which is unique to {2,3} being both prime AND consecutive.

### Specific Testable Prediction

**In a 6-class neural classifier trained to maximum accuracy:**

```
  1. Measure class mean representations: mu_1, ..., mu_6 in final layer space

  2. Find the nearest-neighbor pair: (i*, j*) = argmin_{i!=j} ||mu_i - mu_j||

  3. Measure: d_min = ||mu_{i*} - mu_{j*}||

  4. In normalized representation space (sphere of radius 1):
     d_min ≈ 2 * sin(pi/6) = 2 * 1/2 = 1   (hexagonal nearest-neighbor distance)

  5. The 6 class means should approximately form a REGULAR HEXAGON
     in the 2D principal subspace of representation space.
```

The hexagonal prediction comes from: 6 equidistant points on a circle are
exactly the vertices of a regular hexagon. The angle between adjacent vertices
is pi/3 = 60 degrees. Their separation = 2*sin(pi/6) = 1 (for unit-radius circle).

This directly connects to sin(pi/6) = 1/2 = phi(6)/tau(6).

---

## Experiment Design

### Experiment A: 6-class vs other-class representation geometry

```python
# Dataset: MNIST (10 classes, use only 6 at a time)
# Or: Synthetic 6-class Gaussian mixture

# After training, extract final-layer representations

import torch.nn.functional as F

def measure_class_geometry(model, dataloader, n_classes):
    class_activations = {c: [] for c in range(n_classes)}
    with torch.no_grad():
        for x, y in dataloader:
            feat = model.get_features(x)
            for c in range(n_classes):
                mask = (y == c)
                class_activations[c].extend(feat[mask].tolist())

    # Compute class means
    means = [torch.tensor(class_activations[c]).mean(0)
             for c in range(n_classes)]
    means = F.normalize(torch.stack(means), dim=1)

    # Pairwise distances
    dists = torch.cdist(means, means)
    upper = dists[dists > 0]

    return {
        'min_dist': upper.min().item(),
        'max_dist': upper.max().item(),
        'mean_dist': upper.mean().item(),
        'std_dist': upper.std().item(),
        'hexagonal_score': abs(upper.min().item() - 1.0)  # distance from unit
    }
```

### Experiment B: 6-class vs 4-class vs 8-class vs 10-class

Train identical architectures on different numbers of classes. Measure:
1. Minimum pairwise class distance (should be ~1.0 for 6-class)
2. Distribution of pairwise angles (should be peaked at 60 degrees = pi/3)
3. Hexagonal packing score

### Expected Results

```
  n_classes | min_dist | hexagonal_score | interpretation
  ----------|----------|----------------|----------------
      4      |   ?      |      ?          | square lattice
      6      |   1.00   |     0.00        | hexagonal *** PREDICTED
      8      |   ?      |      ?          | octagonal
     10      |   ?      |      ?          | no clean lattice

  For n_classes=6: expect min_dist closer to 1.0 than any other class count
```

---

## Falsification Criteria

| Claim | Falsified if |
|-------|-------------|
| 6-class representations tend to hexagonal geometry | 4-class or 8-class is MORE hexagonal |
| min pairwise dist ≈ 1.0 for 6-class only | Multiple class counts achieve dist ≈ 1.0 |
| unit discriminant predicts min dist | No correlation between disc and dist |
| sin(pi/6)=1/2 appears in 6-class geometry | Angle distribution not peaked at pi/3 |

---

## Connections to Existing Hypotheses

- **H-CX-40 (kissing numbers):** hexagonal kissing number k(2)=6 supports the
  hexagonal geometry prediction for 6 classes
- **H-CX-55 (hexagonal self-reference):** H(phi(6))=6 connects hexagonal numbers
  to the 6-class structure
- **sin(pi/6)=phi(6)/tau(6)=1/2:** directly appears in the unit-distance
  hexagonal spacing formula 2*sin(pi/6)=1
- **H-CX-3 (six modules):** 6 consciousness modules with 2x3 factorization
  matches the binary x ternary decomposition of the classifier

---

## Limitations

1. The "unit distance" prediction assumes normalized representations (sphere).
   Real neural networks do not automatically normalize representations; this
   requires careful implementation (e.g., cosine similarity heads).
2. Hexagonal geometry in representation space is a 2D concept; high-dimensional
   representation spaces will not literally form 2D hexagons.
3. The prime-factor discriminant is a property of semiprimes specifically; the
   argument does not directly apply to primes or composites with more factors.
4. The connection between discriminant=1 and ML maximum-margin is analogical
   and would benefit from a formal derivation.

---

## Mathematical Grade

The mathematical claim is **proven** (graded 🟩):
- disc((x-2)(x-3)) = 1 is arithmetic fact
- Uniqueness among semiprimes follows from "no two consecutive primes except {2,3}"
- This is provable with elementary number theory

The ML cross-domain prediction is **unverified** (pending experiment).
