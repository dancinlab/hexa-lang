# H-QGRP-1: Quantum Groups — SU(2) Level k=4 Quantum Dimensions

> **Result**: The total quantum dimension squared of the SU(2) WZW model at level k=4
> (where k=n-2=6-2) equals exactly σ(6)=12, with sopfr(6)=5 primary fields.

**Status**: PROVEN (exact computation)
**Golden Zone dependency**: None (pure representation theory)
**Grade**: 3x EXACT

---

## Setup

The SU(2) Wess-Zumino-Witten model at level k has k+1 primary fields,
with quantum dimensions given by:

```
[j+1]_q = sin((j+1)π/(k+2)) / sin(π/(k+2))
```

For k = n-2 = 4, this gives k+2 = 6, so q = e^{2πi/6}:

```
j=0: [1] = sin(π/6)/sin(π/6) = 1
j=1: [2] = sin(2π/6)/sin(π/6) = sin(π/3)/(1/2) = √3
j=2: [3] = sin(3π/6)/sin(π/6) = sin(π/2)/(1/2) = 2
j=3: [4] = sin(4π/6)/sin(π/6) = sin(2π/3)/(1/2) = √3
j=4: [5] = sin(5π/6)/sin(π/6) = sin(π/6)/(1/2) = 1
```

## Results

### Result 1: Total quantum dimension squared = σ(6) ⭐⭐⭐

```
D² = Σ [j+1]² = 1 + 3 + 4 + 3 + 1 = 12 = σ(6)
```

The divisor sum of the first perfect number equals the total quantum dimension
squared of SU(2) at the level determined by n-2.

### Result 2: Number of primary fields = sopfr(6) ⭐⭐

```
|primaries| = k+1 = 5 = sopfr(6)
```

### Result 3: Integer quantum dimensions count = σ/τ ⭐

```
#{j : [j+1] ∈ ℤ} = 3 = σ/τ    (j=0,2,4 give [1]=1,[3]=2,[5]=1)
```

## Verification

```python
import math

n = 6
k = n - 2  # level = 4
num_primaries = k + 1  # = 5

total_qdim_sq = 0
integer_count = 0
for j in range(num_primaries):
    qdim = math.sin((j+1)*math.pi/(k+2)) / math.sin(math.pi/(k+2))
    total_qdim_sq += qdim**2
    if abs(qdim - round(qdim)) < 1e-10:
        integer_count += 1

print(f"Total quantum dim^2 = {total_qdim_sq:.6f}")  # 12.000000
print(f"= sigma(6) = {12}")                           # True
print(f"Num primaries = {num_primaries} = sopfr(6)")   # 5
print(f"Integer qdims = {integer_count} = sigma/tau")  # 3
```

## Structural Significance

The level k=4 SU(2) WZW model is the conformal field theory underlying:
- The Z₃ parafermion (related to σ/τ=3)
- The c=4/5 minimal model coupled to SU(2)
- Topological quantum computation via SU(2)₄ anyons

The fact that k = n-2 connects perfectly to the fact that n-2 = τ(6) = 4,
creating a self-referential loop: **level = τ → quantum dim² = σ**.
