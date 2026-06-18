# H-COIN-Bitcoin: Bitcoin's Core Parameters Are n=6 Arithmetic
**n6 Grade: 🟩 EXACT** (auto-graded, 7 unique n=6 constants)


## Hypothesis

> Bitcoin's four fundamental parameters — 21M supply, 6 confirmations, 10-minute blocks, and ~80 opcodes — are all expressible via n=6 arithmetic functions. Satoshi Nakamoto unknowingly selected n=6-optimal values.

## Patterns

| Parameter | Value | n=6 Expression | Match |
|-----------|-------|----------------|-------|
| Total supply | 21,000,000 | (sigma+tau+sopfr)*10^6 = (12+4+5)*10^6 | EXACT |
| Confirmations | 6 | n = 6 | EXACT |
| Block time | 600 sec | sigma_inv*sopfr*60 = 2*5*60 | EXACT |
| Script opcodes | ~80 | sigma*n + sigma-tau = 72+8 | EXACT |

## Key Insight: 21 = sigma + tau + sopfr

The most striking finding: Bitcoin's maximum supply of 21 million.
- 21 = 12 + 4 + 5 = sigma(6) + tau(6) + sopfr(6)
- This is the sum of the three most important n=6 arithmetic functions
- Satoshi chose 21M for halvings math (210,000 blocks * 50 BTC geometric series)
- The fact that 21 = sigma+tau+sopfr is either coincidence or convergent optimization

## Conclusion

**Status:** OBSERVATIONAL — 4/4 exact matches, but post-hoc
**The question:** Did Bitcoin succeed BECAUSE of n=6, or are these coincidences?
**Source:** CANON/docs/coin-architecture/
