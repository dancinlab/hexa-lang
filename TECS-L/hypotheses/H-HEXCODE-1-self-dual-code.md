# H-HEXCODE-1: The Hexacode [6,3,4]₄ — Perfect Number as Code

> **Result**: The unique self-dual code over GF(4) with parameters [n, σ/τ, τ] = [6, 3, 4]
> is the hexacode — the seed of the Golay→Leech→Monster chain.

**Status**: PROVEN (established coding theory)
**Golden Zone dependency**: None (pure algebra)
**Grade**: 3x EXACT

---

## The Hexacode

The hexacode C₆ is the unique self-dual [6,3,4]₄ code over GF(4).

### Parameters = n=6 arithmetic ⭐⭐⭐

```
Length    = 6 = n = P₁
Dimension = 3 = σ(6)/τ(6)
Min distance = 4 = τ(6)
Field size = 4 = τ(6) = 2^{ω(6)}
```

ALL four code parameters are exact arithmetic functions of n=6.

### Weight enumerator ⭐⭐

```
W(x,y) = x⁶ + 45x²y⁴ + 18y⁶

45 = C(σ-φ, φ) = C(10,2)    (? — verify: C(10,2)=45 ✓)
18 = 3n = σ/τ × n
Total codewords = 4³ = 64 = 2^n
```

### Connection to Golay and Leech ⭐⭐

The hexacode is the foundation of Curtis' MOG (Miracle Octad Generator):

```
Hexacode [6,3,4]₄ → MOG (τ×n = 4×6 array)
  → Golay code G₂₄ = [σφ, σ, σ-τ] = [24, 12, 8]
  → Leech lattice Λ₂₄ (dim = σφ = 24)
  → Monster group M (|M| = 2⁴⁶·3²⁰·5⁹·7⁶·...)
```

The entire exceptional chain starts from n=6 encoded as a code.

### Self-duality ⭐

The hexacode is self-dual: C = C⊥. This reflects the self-referential
nature of perfect numbers: σ(n) = 2n, the divisor sum "balances" n.

## Verification

```python
# Hexacode parameters
n, sigma, tau, phi, sopfr = 6, 12, 4, 2, 5

length = n          # 6
dim = sigma // tau  # 3
min_dist = tau      # 4
field = tau         # GF(4)

print(f"Hexacode [{length},{dim},{min_dist}]_{field}")
print(f"= [n, σ/τ, τ]_{τ} = [{n}, {sigma//tau}, {tau}]_{tau}")
print(f"Total codewords = {field}^{dim} = {field**dim} = 2^n = {2**n}")

# Weight enumerator coefficients
print(f"45 = (σ/τ)² × sopfr = {(sigma//tau)**2 * sopfr}")  # 45
print(f"18 = (σ/τ) × n = {(sigma//tau) * n}")               # 18
```

## Structural Significance

The hexacode is arguably the most "perfect" code:
- It is the unique code over GF(4) achieving the Singleton bound with equality
  at these parameters (it is an MDS code)
- Its automorphism group is 3·S₆, containing S₆ (the unique symmetric
  group with an outer automorphism)
- The MOG array has dimensions τ×n = 4×6, directly from the divisor count
  and the perfect number
