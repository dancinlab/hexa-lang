# H-EE-68: Dark Matter Fraction from N=6 Arithmetic — Open
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


## Hypothesis

> The observed dark matter fraction of the universe (26.8%) can be derived from n=6
> arithmetic functions. Dark matter represents the "hidden divisors" — the structural
> mass that does not emit light but participates in gravitational balance.

## Background

- Observed fractions (Planck 2018): dark energy 68.3%, dark matter 26.8%, baryonic 4.9%
- n=6 values: sigma(6)=12, phi(6)=2, tau(6)=4, sopfr(6)=5

## Attempts (None Precise)

```
Attempt 1: phi(6)/sigma(6) = 2/12 = 0.167 (16.7%)
  Error: (26.8 - 16.7)/26.8 = 37.7% -- too low

Attempt 2: tau(6)/sigma(6) = 4/12 = 0.333 (33.3%)
  Error: (33.3 - 26.8)/26.8 = 24.3% -- too high

Attempt 3: phi(6)*ln(4/3) = 2 * 0.288 = 0.576 -> matter = 1 - 0.576 - 0.685
  Doesn't produce consistent decomposition

Attempt 4: (sigma - tau - phi)/sigma = (12-4-2)/12 = 6/12 = 0.5 -- far off

Attempt 5: 1/(sopfr(6)^phi(6)) = 1/25 = 0.04 (baryonic? 4.9% -- close!)
  Baryonic: 1/5^2 = 4% vs observed 4.9% (18% error)
  But if baryonic ~ 1/sopfr^2, then dark matter ~ 1 - 1/sopfr^2 - dark_energy
  Dark energy still undetermined from n=6 alone.
```

## Current Status

No formula with error < 10% found using only {sigma(6), phi(6), tau(6), sopfr(6)}
without introducing arbitrary combinations. The baryonic fraction 4.9% ~ 1/sopfr^2 = 4%
is the closest result (18% error). The dark matter fraction 26.8% remains open.

## Conclusion

**Status:** Open — no precise formula found yet
**Bridge:** Dark matter ↔ n=6 ↔ open problem
**Next step:** Check if dark matter fraction = tau(6)/(sopfr(6)*tau(6)+phi(6)) or similar
