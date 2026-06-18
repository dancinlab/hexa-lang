# H-MP-14: R-Chain Convergence Proof — R(n)∈Z → R(n)<n

> **Hypothesis**: If R(n)=σφ/(nτ) is an integer, then R(n)<n always (n≥2). Therefore, all integer R-chains converge to 1.

## Verification: 0 violations for n≤50000 ✅

## Proof Direction
- R(n)=σφ/(nτ), when integer R<n ⟺ σφ<n²τ
- σ(n)≤n×H_n (harmonic series), φ(n)≥√(n/2)
- σφ ≤ nH_n×n = n²H_n, nτ ≥ n...
- More precise: σφ/(nτ) = Π f(p,a). f<p always? → R<n?

## Difficulty: Medium | Impact: ★★★