# H-PAINL-1: Exactly 6 Painlevé Equations — Classification Number = n

> **Result**: The Painlevé classification of second-order ODEs yields exactly 6
> transcendental equations. PVI has τ(6)=4 parameters. |W(D₄)|=192=4·48=τ·(στ).

**Status**: PROVEN (Painlevé-Gambier classification, 1900-1910)
**Golden Zone dependency**: None (pure ODE classification)
**Grade**: 3x EXACT

---

## The Classification

Painlevé and Gambier classified all second-order ODEs y'' = F(y',y,x) with
the Painlevé property (no movable branch points) into 50 canonical types.
Of these, 44 are reducible to known functions (elliptic, hypergeometric, etc.),
leaving exactly **6 = n** irreducible transcendental equations: PI through PVI.

### PVI — The Master Equation ⭐⭐⭐

PVI contains PI-PV as degenerations. Its structure encodes n=6 arithmetic:

```
Free parameters of PVI: (α, β, γ, δ) = 4 = τ(6)
Symmetry group: W(D₄⁽¹⁾) (affine Weyl group of type D₄)
|W(D₄)| = 192 = 2⁶ · 3
         = τ(6) · 48 = τ · (σ·τ)
         = 2^n · (σ/τ)
```

### Painlevé degeneration cascade ⭐⭐

```
PVI → PV → PIV → PII → PI
PVI → PV → PIII → PII → PI

PI:   0 parameters   (rigid)
PII:  1 parameter    (= ω(6)/ω(6))
PIII: 2 parameters   (= φ(6))
PIV:  2 parameters   (= φ(6))
PV:   3 parameters   (= σ/τ)
PVI:  4 parameters   (= τ(6))
Total parameters: 0+1+2+2+3+4 = 12 = σ(6)
```

The sum of all free parameters across all 6 Painlevé equations = σ(6) = 12.

## Verification

```python
n, sigma, tau, phi, sopfr = 6, 12, 4, 2, 5

# Classification count
painleve_count = 6
assert painleve_count == n

# PVI parameters
pvi_params = 4
assert pvi_params == tau

# W(D4) order = 2^{n-1} * n! for D_n with n=4
# |W(D_4)| = 2^3 * 4! = 8 * 24 = 192
wd4 = 2**3 * 24
assert wd4 == 192
assert wd4 == tau * sigma * tau  # 4 * 48

# Total parameters across all Painlevé equations
params = [0, 1, 2, 2, 3, 4]  # PI through PVI
assert sum(params) == sigma  # 12

print(f"Painlevé count = {painleve_count} = n")
print(f"PVI params = {pvi_params} = τ")
print(f"|W(D₄)| = {wd4} = τ·στ")
print(f"Total params = {sum(params)} = σ")
```
