# H-TEICH-1: Teichmüller Dimension 6(g-1) — n=6 as Universal Constant

> **Result**: The real dimension of Teichmüller space T_g is 6(g-1),
> making n=6 the universal structural constant of Riemann surface deformation.

**Status**: PROVEN (established theorem)
**Golden Zone dependency**: None (pure geometry)
**Grade**: 3x EXACT

---

## The Theorem

For a closed oriented surface of genus g ≥ 2:

```
dim_ℝ(T_g) = 6(g-1) = n·(g-1)
```

This is because:
1. dim_ℂ(T_g) = 3g-3 (complex parameters = moduli)
2. Real dimension = 2(3g-3) = 6g-6 = 6(g-1)
3. The factor 3 = σ/τ comes from dim(PSL(2,ℝ)) = 3

### Self-referential values ⭐⭐⭐

```
g = 2:        dim T₂ = 6  = n         (first nontrivial case)
g = σ/τ = 3:  dim T₃ = 12 = σ(6)     (genus = mean divisor!)
g = τ = 4:    dim T₄ = 18 = 3n
g = sopfr = 5: dim T₅ = 24 = σφ(6)   (= Leech dimension!)
g = n = 6:    dim T₆ = 30 = sopfr·n   (= 6#, primorial!)
g = n+1 = 7:  dim T₇ = 36 = n²
```

The entire n=6 arithmetic appears as Teichmüller dimensions at
genus values equal to n=6 constants.

### Weil-Petersson volume ⭐⭐

```
V_{1,1} = π²/6 = ζ(2) = π²/n
```

The simplest Weil-Petersson volume (genus 1, 1 puncture) contains
1/n = 1/6 as its rational factor — the Basel problem.

### Origin of the constant 6 ⭐⭐

```
dim(PSL(2,ℝ)) = 3 = σ/τ
dim(PSL(2,ℂ)) = 6 = n

Teichmüller: each handle ↔ one copy of PSL(2,ℂ)/PSL(2,ℝ)
            ↔ 6 real parameters per handle minus 6 for global symmetry
```

The constant n=6 = dim(PSL(2,ℂ)) governs ALL Riemann surface moduli.

## Verification

```python
n, sigma, tau, phi, sopfr = 6, 12, 4, 2, 5

for g in range(2, 8):
    dim = 6*(g-1)
    label = ""
    if dim == n: label = "= n"
    elif dim == sigma: label = "= σ"
    elif dim == sigma*phi: label = "= σφ (Leech dim)"
    elif dim == sopfr*n: label = "= sopfr·n = n#"
    elif dim == n**2: label = "= n²"
    elif dim == 3*n: label = "= 3n"
    print(f"dim T_{g} = {dim} {label}")

# dim T_2 = 6 = n
# dim T_3 = 12 = σ
# dim T_4 = 18 = 3n
# dim T_5 = 24 = σφ (Leech dim)
# dim T_6 = 30 = sopfr·n = n#
# dim T_7 = 36 = n²
```
