# HEXA-QRNG

@title: 🎲 HEXA-QRNG — 양자난수(ANU QRNG) 통합

@goal: Wire the ANU Quantum Random Number Generator (qrng.anu.edu.au) into hexa's existing
`compiler/hw_probes/qrng.hexa` probe as an OPT-IN true-entropy source for the legitimate non-deterministic
use cases (seed-provenance, differential-privacy noise, Monte-Carlo sampling) — STRICTLY isolated from the
flame byte-exact deterministic training core, whose reproducibility north-star true randomness would break.

## scope boundary (the load-bearing honest constraint)

QRNG is NOT a speed lever — the flame ~3x train-step cap is a GPU launch-dispatch/occupancy wall (commons
g85), orthogonal to random-number quality. QRNG is a NEW capability axis (true entropy), and it must NEVER
feed the deterministic byte-exact path (weight init / dropout / shuffle in a reproducible run) — that path
stays on a fixed-seed PRNG so 1==N-GPU byte-eq and run-replay hold. QRNG is opt-in, isolated, provenance-only.

## milestones

- [ ] **Q1 — ANU QRNG client wired to the qrng.hexa probe** — hexa-native HTTPS fetch from qrng.anu.edu.au
  (the public JSON API) into `compiler/hw_probes/qrng.hexa`, with a local-OS-entropy fallback (getrandom)
  when the API is unreachable/rate-limited. Gate: a fetched block passes a basic entropy sanity check
  (byte histogram ~uniform) + the fallback path is exercised. No network dep in the deterministic build.
- [ ] **Q2 — seed-provenance record (repro preserved)** — stamp a run with "seeded from quantum source
  <ANU-block-id/hash>" provenance WITHOUT making the run non-reproducible: QRNG draws the seed ONCE, the
  seed is recorded, and the run replays deterministically from that fixed seed. Gate: same recorded seed →
  byte-identical run; the provenance record round-trips. The quantum source stamps ORIGIN, not the per-step RNG.
- [ ] **Q3 — differential-privacy noise source (opt-in)** — expose QRNG as the entropy source for DP noise
  (Laplace/Gaussian mechanism) where true hardware entropy is a genuine security advantage over a PRNG.
  Gate: the DP noise sampler draws from QRNG, documented as a non-reproducible-by-design path (DP runs are
  not meant to replay). Isolated from the training-core RNG.
- [ ] **Q4 — Monte-Carlo sampling (repro-not-needed experiments)** — QRNG-sourced sampling for statistical
  MC experiments where replay is not required; a clean example/bench showing QRNG vs PRNG draw. Gate: runs,
  documented as the non-deterministic lane.
- [ ] **Q5 — isolation guard + docs (the boundary is enforced, not just stated)** — a guard ensuring the
  QRNG source can NOT be selected for the deterministic flame training-core RNG (compile-time or runtime
  reject), + a docs/ note explaining the byte-exact-vs-true-entropy split. Gate: attempting to feed QRNG
  into the deterministic path is REJECTED; the flame reproducibility invariant is provably untouched.
