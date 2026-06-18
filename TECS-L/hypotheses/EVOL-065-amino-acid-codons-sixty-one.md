# EVOL-065: Sense Codons = 64 - P1/2 = 61

> **Hypothesis**: There are 61 sense codons out of 64 total = 2^P1 - P1/2 = 61.

## Numerical Verification

| Category | Count | n=6 relation |
|----------|-------|-------------|
| Total codons | 64 | 2^P1 |
| Stop codons | 3 | P1/2 |
| Sense codons | 61 | 2^P1 - P1/2 |
| Amino acids | 20 | tau(6) x sopfr(6) |

## Structure

```
  Codon allocation:

  Total:  [################] 64 = 2^P1
  Sense:  [###############.] 61
  Stop:   [...]              3 = P1/2

  Degeneracy = 61/20 = 3.05 ~ P1/2
```

## Structural Meaning

The genetic code allocates 2^P1 codons minus P1/2 stops for tau(6)*sopfr(6) amino acids.

## Grade

🟩 EXACT -- 61 sense codons is a mathematical fact of the genetic code

## Limitations
- None -- arithmetic fact

## GZ Dependency
GZ independent (biology)
