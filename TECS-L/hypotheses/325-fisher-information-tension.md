# Hypothesis 325: Fisher Information Geometry and Tension Manifold (NM-5)
**n6 Grade: 🟩 EXACT** (auto-graded, 10 unique n=6 constants)


> **The tension fingerprint space forms a statistical manifold, and its curvature is measured by the Fisher information matrix. High tension regions have high Fisher information, corresponding to "informationally rich" inputs. H313 (tension=confidence) and H318 (fingerprint sufficiency) are different cross-sections of this geometric structure.**

## Background/Context

```
  The consciousness engine's tension fingerprint is a 10-dimensional vector:
    fp(x) = [t_0, t_1, ..., t_9]  (per-class tension values)

  H313: tension = confidence
    Correct sample tension > wrong sample tension (confirmed in 3 datasets)

  H318: High-confidence classes recognizable from fingerprint alone
    r(tension, knn_acc) = +0.705

  Question: What is the geometric structure of the space formed by these fingerprint vectors?
  -> Fisher information geometry is a natural framework
```

## Fisher Information Matrix — Mathematical Framework

```
  Definition:
    F_ij = E[ (d log p(x|theta) / d theta_i) * (d log p(x|theta) / d theta_j) ]

  Where:
    p(x|theta) = probability distribution of tension fingerprints (parameterized by theta)
    theta = model parameters (engine weights)
    x = input sample

  Meaning of Fisher matrix:
    Large F_ij = small change in theta causes large change in p(x|theta)
               = large "curvature" in parameter space
               = data is "informative" about parameters

  Fisher matrix as Riemannian metric:
    ds^2 = sum_ij F_ij * d_theta_i * d_theta_j

    This is the Riemannian metric on parameter space (Rao, 1945).
    -> The tension fingerprint space is a Riemannian manifold.
```

## Application to Tension Space

```
  Tension fingerprint distribution for class k:
    p_k(fp) = fingerprint distribution of samples belonging to class k

  Per-class Fisher information:
    F_k = E_{x in class k}[ (d log p_k(fp(x)) / d theta)^2 ]

  Core claim of hypothesis:
    F_k  proportional to  mean_tension_k

  That is, classes with higher mean tension have higher Fisher information.
```

## Predicted Mapping (from H318 data)

```
  Fashion-MNIST per-class predictions:

  Class     Tension  KNN%   Predicted F_k  Interpretation
  --------  -------  -----  --------        --------
  Boot       1006    93.0   high            large curvature = easy to distinguish
  Sandal      704    88.3   high            large curvature
  Sneaker     526    92.4   moderate
  Trouser     511    93.3   moderate
  Bag         429    85.4   moderate
  T-shirt     392    71.6   low
  Coat        329    66.0   low             small curvature = hard to distinguish
  Pullover    318    63.9   low             small curvature
  Shirt       302    56.2   low             minimum curvature

  Prediction: F_Boot >> F_Shirt
  -> Boot fingerprint space is "curved" making it easy to distinguish neighbors
  -> Shirt fingerprint space is "flat" making it hard to distinguish neighbors
```

## Geometric Interpretation

```
  High Fisher information (high tension):
    ┌─────────────────┐
    │  *   *           │   fingerprints are well separated
    │       *          │   large curvature -> distance feels large
    │  *        *      │   KNN classifies easily
    │      *           │   -> H318's "fingerprint sufficient" state
    └─────────────────┘

  Low Fisher information (low tension):
    ┌─────────────────┐
    │     ***          │   fingerprints are clustered
    │    ****          │   small curvature -> distance difference negligible
    │     **           │   KNN confused
    │                  │   -> H318's "fingerprint insufficient" state
    └─────────────────┘

  Geometric diagram:

  Fisher info
  (curvature)
    |
    |  Boot *
    |            Sandal *
    |                   Sneaker *  Trouser *
    |                          Bag *
    |                     T-shirt *
    |                Coat * Pullover *
    |           Shirt *
    +-----------------------------------> mean tension
         300   400   500   600   700   1000

  Prediction: monotonically increasing relationship (r > +0.7)
```

## Integration with H313 and H318

```
  H313 (tension = confidence):
    Tension = magnitude of confidence
    Fisher interpretation: confidence = parameters explain data well
                        = likelihood has sharp peak
                        = Fisher information is large
    -> H313 is a scalar summary of Fisher information

  H318 (fingerprint sufficiency):
    High tension -> KNN sufficient
    Fisher interpretation: high curvature -> metric distance well defined
                        -> Euclidean KNN approximates Riemannian distance well
                        -> Classification possible from geometry alone, without labels
    -> H318 is the KNN approximability of Fisher metric

  Integration:
    H313 = det(F) or tr(F) (overall size of Fisher information)
    H318 = eigenvalue distribution of F (deviation between Euclidean and Riemannian distance)
    H325 = geometric framework encompassing both hypotheses
```

## Cramer-Rao Inequality and Tension

```
  Cramer-Rao lower bound:
    Var(theta_hat) >= 1 / F(theta)

  Interpretation:
    Large Fisher information F -> small estimation variance -> accurate estimation possible
    Small Fisher information F -> large estimation variance -> inaccurate estimation

  Tension translation:
    High tension = high F -> low estimation variance -> confident classification
    Low tension = low F -> high estimation variance -> uncertain classification

  -> Cramer-Rao is the mathematical basis for H313 (tension=confidence)!
```

## Connection with Natural Gradient

```
  Ordinary gradient:        d_theta = -lr * grad L(theta)
  Natural gradient (Amari): d_theta = -lr * F^{-1} * grad L(theta)

  The natural gradient corrects for curvature in parameter space
  using Fisher information. Small steps in high-curvature directions, large in low-curvature.

  Consciousness engine interpretation:
    High-tension class -> large curvature -> natural gradient takes small step
    Low-tension class -> small curvature -> natural gradient takes large step

  Prediction: applying natural gradient learning
    -> Selectively improves accuracy of low-tension classes (Coat, Shirt)
    -> High-tension classes (Boot) already sufficient, little change
```

## Verification Direction

```
  Experiment 1: Direct Fisher information measurement
    - Compute empirical Fisher matrix from fingerprint distribution of each class
    - F_k = (1/N) * sum_i (d log p / d fp_j)^2
    - Calculate r(tr(F_k), mean_tension_k) -> prediction: r > +0.7

  Experiment 2: Riemannian distance vs Euclidean distance
    - Compute Riemannian distance using Fisher metric
    - Compare Euclidean KNN vs Riemannian KNN accuracy
    - Prediction: Riemannian KNN improves especially for low-tension classes

  Experiment 3: Natural gradient training
    - Apply Fisher matrix-based natural gradient to consciousness engine
    - Observe accuracy changes for low-tension classes
    - Prediction: Coat/Shirt +5~10pp, Boot/Sneaker minimal change

  Experiment 4: Curvature and learning difficulty
    - Track Fisher information changes from early to late training
    - Prediction: F increases as training progresses (curvature increase = confidence increase)
```

## Limitations

```
  1. Empirical estimation of Fisher matrix is unstable in high dimensions (10D is OK)
  2. Fingerprint distribution may not be Gaussian -> non-parametric estimation (KDE, etc.) needed
  3. Proportional relationship between "curvature" and "tension" is still a hypothesis, not theoretical proof
  4. Golden Zone dependency: indirect (tension itself comes from Golden Zone structure)
  5. Fisher matrix of 10D fingerprint = 10x10 = 100 components
     -> Sufficient samples needed (at least hundreds per class)
```

## Verification Results: MNIST RepulsionField 2-Pole Experiment (2026-03-24)

### Experimental Setup

```
  Model: RepulsionField2Pole (2-pole, engine_A vs engine_G)
  Data: MNIST, 15 epochs, Adam lr=1e-3, batch=256
  Fisher estimation:
    (A) Covariance inverse: F = Cov^{-1}, logdet(F) = -logdet(Cov)
    (B) Gradient-based: F_k = E[|grad log p(y=k|x)|^2], 200 samples/class
  Test accuracy: 97.9%
  tension_scale (learned): 2.0531
```

### Per-Class Data

| Class | N    | Mean T   | Std T    | F_logdet | F_grad     | Acc%  |
|-------|------|----------|----------|----------|------------|-------|
|     0 |  980 | 157.88   |  67.96   |   -86.14 |       2.43 |  99.0 |
|     1 | 1135 |  92.88   |  29.10   |   -76.75 |       3.04 |  99.1 |
|     2 | 1032 | 227.56   | 120.56   |   -98.06 |      11.69 |  97.7 |
|     3 | 1010 | 216.01   | 105.60   |   -92.61 |       8.08 |  97.7 |
|     4 |  982 | 133.78   |  51.04   |   -86.63 |      14.43 |  97.8 |
|     5 |  892 | 191.70   | 102.99   |   -94.53 |      14.02 |  98.3 |
|     6 |  958 | 150.81   |  69.08   |   -89.27 |      14.54 |  98.3 |
|     7 | 1028 | 192.57   |  85.75   |   -89.54 |      17.19 |  96.6 |
|     8 |  974 | 111.52   |  43.46   |   -88.31 |      23.92 |  96.9 |
|     9 | 1009 | 144.79   |  54.06   |   -83.29 |      13.00 |  97.5 |

```
  F_logdet = -log(det(Cov)): more negative = wider distribution = lower Fisher information
  F_grad = mean squared gradient: larger = model more sensitive to that class

  Top tension: class 2 (227.6) > 3 (216.0) > 7 (192.6) > 5 (191.7)
  Bottom tension: class 1 (92.9) < 8 (111.5) < 4 (133.8) < 9 (144.8)
```

### Correlation Analysis

| Metric                        | Pearson r | p-value  | Spearman rho | p-value  |
|-------------------------------|-----------|----------|--------------|----------|
| tension vs F_logdet           |   -0.8526 |   0.0017 |      -0.8182 |   0.0038 |
| tension vs F_trace (cov-inv)  |   -0.6410 |   0.0458 |      -0.6848 |   0.0289 |
| tension vs F_grad             |   -0.0274 |   0.9400 |      -0.1515 |   0.6761 |
| tension vs accuracy           |   -0.2646 |   0.4600 |              |          |
| F_trace vs accuracy           |   +0.6524 |   0.0409 |              |          |

### Covariance Eigenvalue Spectrum

```
  Class | lambda_1      | lambda_2      | lambda_3      | cond num
  ------|--------------:|-------------:|--------------:|--------:
      0 |   127,062     |    63,003     |    30,429     |    672.8
      1 |    29,350     |    15,886     |     7,748     |    258.5
      2 |   385,179     |   199,596     |    40,276     |    547.6
      3 |   311,424     |    62,291     |    40,034     |    226.5
      4 |    62,417     |    41,828     |    13,974     |     62.5
      5 |   234,912     |    74,455     |    53,682     |    247.9
      6 |   101,947     |    48,608     |    32,752     |    206.5
      7 |   234,734     |    26,461     |    20,328     |    293.7
      8 |    37,364     |    30,091     |    28,209     |     33.2
      9 |    78,315     |    52,877     |    13,368     |    171.7

  r(tension, condition_number) = +0.4462 (p=0.1961)
```

### Scatter Plot (ASCII)

```
  Fisher logdet ^   (more positive = narrower distribution = higher Fisher)
  |
  |  1 (low T, high F)
  |
  |      9
  |          0   4
  |              8
  |                  6
  |                       7   3
  |                           5
  |
  |                               2 (high T, low F)
  +──────────────────────────────────> Mean Tension
     90   120  150  180  210  228

  Direction: clear negative correlation (r = -0.85)
  High tension = wide distribution = low Fisher information
```

### Key Findings

```
  1. Hypothesis prediction disproved: tension and Fisher information have negative correlation
     - r(tension, F_logdet) = -0.8526 (p=0.0017, significant)
     - H325 prediction r > +0.7 -> measured r = -0.85 -> opposite direction

  2. Interpretation: high tension = wide fingerprint distribution = low Fisher information
     - High-tension classes (2,3,7): large fingerprint variance
     - Low-tension classes (1,8): fingerprints cluster narrowly
     - Intuitive: tension = repulsion magnitude -> distribution widens

  3. Fisher trace vs accuracy is positively correlated (r=+0.65, p=0.04)
     - Narrow distribution (high Fisher) = high accuracy
     - That is, Fisher -> accuracy path works, but
       tension -> Fisher direction is opposite of prediction

  4. Gradient Fisher (F_grad) has no correlation with tension (r=-0.03, ns)
     - Covariance-based Fisher and gradient-based Fisher measure different things
     - F_grad is higher for "hard classes" (4,6,7,8)

  5. tension vs accuracy also uncorrelated (r=-0.26, ns)
     - All MNIST classes are 96%+ -> ceiling effect
```

### Why Was It Disproved: Mathematical Reason

```
  H325 logic: high tension -> parameter-sensitive -> high Fisher
  Measured logic: high tension -> wide distribution -> low Fisher

  Error point:
    H325 assumed "high tension = informationally rich",
    but in reality high tension = large opinion difference between engines = fingerprints disperse.

    Fisher information = 1/variance, so large variance means small Fisher.
    Therefore tension ~ variance ~ 1/Fisher.

  That is, the predicted direction of H325 was fundamentally wrong.

  Correct relationship:
    tension proportional to 1/Fisher (inverse proportion)
    This is strongly confirmed by r = -0.85.
```

### Possibility of Salvage

```
  The geometric framework of H325 itself is valid:
    - Fingerprint space actually forms a statistical manifold
    - Fisher matrix provides meaningful metric
    - Only the "direction" is opposite

  Revised hypothesis (H325-R):
    High tension = high variance = low Fisher = uncertain region
    Low tension = low variance = high Fisher = certain region

  This also contradicts H313 (tension = confidence):
    H313 says high tension = high confidence,
    but from Fisher perspective, high tension = high uncertainty.

  Possible reconciliation:
    - "Confidence" in H313 is model output confidence,
      "information" in Fisher is concentration of fingerprint distribution.
    - They may measure different things.
    - Possible distortion due to MNIST ceiling effect.
```

### Verdict

```
  Core prediction "tension proportional to Fisher": disproved (r = -0.85, p = 0.0017)
  Direction: inverse proportion (tension ~ 1/Fisher)
  Grade: disproved (core prediction is significantly in opposite direction)

  However, since the Fisher geometric framework itself is valid,
  it can be reframed as revised hypothesis H325-R (inverse proportion).
```

## Status: Disproved (core prediction direction reversed, r=-0.85, p=0.0017)
