# HEXA-QRNG — log

## 2026-06-08 — domain registered

User asked "ANU QRNG 활용할순없나" during the MEGASTEP ~3x-cap campaign. Honest assessment (g5): QRNG does
NOT touch the ~3x speed cap (that wall is GPU launch-dispatch/occupancy, orthogonal to RNG quality), AND
true randomness CONFLICTS with flame's byte-exact reproducibility north-star — so QRNG must be isolated
from the deterministic training core. BUT it has real value on a separate capability axis: seed-provenance,
DP noise, MC sampling. hexa already ships a `compiler/hw_probes/qrng.hexa` probe stub to wire it into.

Registered HEXA-QRNG with the isolation boundary as the load-bearing constraint (Q1 client → Q2 provenance
→ Q3 DP → Q4 MC → Q5 isolation guard). GPU 0, opt-in, NOT on the critical path. Milestones NOT yet attempted.
Related: the flame reproducibility value is documented in commons g85 + reference_megastep_research.
