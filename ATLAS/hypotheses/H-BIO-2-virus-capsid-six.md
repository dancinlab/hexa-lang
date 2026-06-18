# H-BIO-2: Virus Capsid Six-fold Symmetry and σφ=nτ

> **Hypothesis**: The icosahedral symmetry (T-number classification) of virus capsids
> corresponds to the divisor structure of arithmetic functions, and the six-fold symmetry
> of T=1 capsids reflects the balance condition of σφ=nτ.

## Background

Virus capsid structure (Caspar-Klug theory, 1962):
- Most spherical viruses = icosahedral symmetry
- T-number: capsid triangulation number (T=1,3,4,7,13,...)
- Capsid protein count = 60T (basic unit 60 = "magic number")
- T=1: simplest, 60 proteins, 12 pentagons (pentamer)

60 = 2²·3·5 related:
```
  60 = σ(6)·5 = 12·5
  60 = P₁·10 = 6·10
  60 = τ(6)·15 = 4·15

  σ(60) = 168, τ(60) = 12 = σ(6), φ(60) = 16
  R(60) = 168·16/(60·12) = 2688/720 = 56/15 ≈ 3.733

  Note: τ(60) = 12 = σ(6)!
```

## Core Structure

### Capsid and Divisor Functions

```
  Capsid Structure       Arithmetic Functions
  ─────────────         ──────────────
  60 proteins (T=1)      60 = σ(6)·5
  12 pentagons          12 = σ(6)
  20 hexagons (T=1: 0)  20 = 5·τ(6)
  Icosahedron V=12      12 = σ(6)
  Icosahedron E=30      30 = P₁·5
  Icosahedron F=20      20 = 5·τ(6)

  T-number series: T = h²+hk+k² (h,k≥0)
    T=1: (h,k)=(1,0) → 60 proteins
    T=3: (h,k)=(1,1) → 180 = 60·3 = 60·(σ/τ)
    T=4: (h,k)=(2,0) → 240 = 60·4 = 60·τ
    T=7: (h,k)=(2,1) → 420 = 60·7 = 60·M₃

  ASCII: T=1 capsid (icosahedral projection)

       △△△
      △○△○△
     △○△○△○△
      △○△○△
       △△△

  ○ = pentagon (12 = σ(6))
  △ = triangular face (20)
```

### Immune System and R Spectrum

```
  Immune response structure:
    Antigen recognition: diversity = divisor structure
    Antibody binding: specificity = R=1 "exact matching"
    Immune tolerance: gap = natural boundary between "self" and "non-self"

  R spectrum analogy:
    R=1 (self): normal cells, tension=0
    R≠1 (non-self): foreign antigens, tension>0
    Gap (3/4,1)∪(1,7/6): immune tolerance range

  Anomaly detection (H-CX-12) ↔ Immunity:
    AUROC=1.0 = perfect immunity (complete self/non-self separation)
    95x tension = strong immune response
    R gap = "immune tolerance margin"
```

### Biological Significance of Six-fold Symmetry

```
  Why do viruses prefer icosahedra (60-fold symmetry)?

  Existing explanation: 60 identical proteins = most efficient packing
  (Crick & Watson, 1956)

  Arithmetic function perspective:
    60 = LCM(3,4,5) = smallest "all prime factors included" number
    60's 12 divisors = σ(6) symmetry axes
    τ(60) = 12 = σ(6): divisor count = divisor sum!

  Proposal: 60T structure is "arithmetic optimal packing"
    T=1 (60): basic icosahedron
    T=3 (180): 3=σ/τ fold expansion
    T=4 (240): 4=τ fold expansion
    T=7 (420): 7=M₃ fold expansion

  Prime T-numbers: T=3,7,13,19,31,...
  T=31 = M₅ (Mersenne prime!)
  → T=31 capsid = 1860 proteins (large viruses)
```

### Antibody-Antigen Binding and R=1

```
  Antibody "binding energy":
    Perfect binding = tension=0 = R=1
    Partial binding = tension>0 = R≠1
    Non-binding = tension≫0 = R≫1

  Antibody diversity:
    Human immune system: ~10¹⁰ antibody types
    VDJ recombination: V×D×J gene combinations
    → Connection to divisor structure:
      V=~50, D=~25, J=~6 gene segments
      J=6 = P₁ (perfect number!)
      Total combinations: ~50×25×6 = 7500
      (Actual diversity reaches 10¹⁰ through somatic mutation)
```

## Verification Directions

1. [ ] Systematic correspondence between T-numbers and arithmetic functions (T=h²+hk+k² analysis)
2. [ ] Correlation between capsid stability and T's divisor structure
3. [ ] Role of J=6 in VDJ recombination (literature review)
4. [ ] Quantitative comparison between immune tolerance range and R gap
5. [ ] Connection between bacteriophage T4, T7 names and T-numbers

## Judgment

```
  Status: 🟨 Observed (capsid 60=σ(6)·5, τ(60)=σ(6))
  Capsid 60-fold symmetry is physically explained (optimal packing)
  Arithmetic connection is post-hoc (beware small numbers)
  Immunity↔R analogy is structurally intriguing
```

## Difficulty: Extreme | Impact: ★★★