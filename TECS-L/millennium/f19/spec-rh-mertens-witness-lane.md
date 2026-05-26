# TECS-L F19 spec — RH Mertens-function verify-witness lane (PARTIAL ANGLE)

@axis: MATH-MILLENNIUM (Clay G axis)
@target: Riemann Hypothesis (RH)
@scope: **partial angle**, NOT a proof. TECS-L methodology transfer.
@status: 🟡 candidate-spec (no Clay-proof claim)

## 1 · What this is, and what it is NOT

**IS**: a verify-witness lane formalizing the Mertens-function partial-sum check
as a hexa-native `hexa verify` cascade. Each μ(k) is 🔵 SUPPORTED-FORMAL via
hexa-native closed-form; cumulative M(n) = Σ_{k=1}^n μ(k) is exact-integer
arithmetic over those 🔵 components.

**IS NOT**: a proof of RH. RH is open. Mertens conjecture |M(n)| ≤ √n was
**disproved** (Odlyzko & te Riele 1985, n ≈ 1.39 × 10⁶⁴). Littlewood's RH-
equivalent (M(n) = O(n^(½+ε))) remains open.

## 2 · TECS-L methodology transfer

| TECS-L primitive (axis 0)  | Transferred form (this lane)                 |
|----------------------------|----------------------------------------------|
| σ/τ/φ closed-form recompute | μ(k) closed-form (hexa verify --expr mu k v) |
| M3 D(n) sweep 1..100        | M(n) partial-sum sweep over chosen range     |
| g5 verify-gate per atom     | per-k μ verdict in `.verdicts/tecs-l-f19-rh-mertens/mu_<k>.txt` |
| 2-op verify bypass          | scalar μ(k) suffices (1-op); cumulative is in-file integer |

## 3 · Concrete partial-result (this F19 round)

Range: n = 1..20. All |M(n)| ≤ √n PASS.

Largest |M(n)| in range: |M(13)| = |-3| = 3 vs √13 ≈ 3.606 (tight; PASS).

Tier: 🟢 SUPPORTED-NUMERICAL (verify-witness lane established; μ component 🔵 each).

**Honest interpretation**: this lane neither supports nor refutes RH; it's the
verify-infra a future audit-driven extension would run on. The result is
**consistent with** RH and **consistent with** the disproved Mertens conjecture
at this scale (range too small to distinguish).

## 4 · Open frontier

- Hexa verify --expr is per-call; M(n) for n > 100 needs a hexa-native loop
  construct (gated by stdlib/main-tree calc-fn). Range extension is verify
  infra work, not RH progress.
- The actual RH-equivalent O(n^(½+ε)) needs n → ∞; finite sweeps can never
  decide it (a single counterexample, or none, doesn't generalize).

## 5 · Atlas fold decision

**NO atom fold to embedded.gen.hexa**: M(n) is a derived sum, not a Tier-1
identity; the load-bearing 🔵 atoms are μ(k) which are already canonical OEIS
A008683 atoms (no need to re-fold).

The partial-sum verdict files live in `.verdicts/tecs-l-f19-rh-mertens/` only.
This adheres to `claim_verify` g5 (no LLM verdict-promotion) and `claim_manifest`
(verdict-only sink).

## 6 · Paper-significance assessment (paper_significance gate)

- Pre-registered falsifier? **NO** — sweep is descriptive, no falsifier defined
  (Mertens conjecture's known failure is at n ≈ 10⁶⁴, beyond our range).
- Real measurement? **YES** — 20 μ(k) verdicts + integer-exact M(n) sum.
- Finding? **WEAK** — verify lane established, but no Δ vs baseline.

**Verdict: paper-INELIGIBLE under paper_significance.** No /paper draft.
This is a candidate-spec only (per @D candidate_spec_only in millennium scope).

## 7 · Cross-link

- Methodology: TECS-L axis 0 M3 (Dedekind ψ discrepancy sweep) is the
  structural analog — same closed-form-per-element + integer-arithmetic
  cumulative pattern.
- Architectural reuse: μ as 🔵 baseline ← stdlib/core/math.hexa.
