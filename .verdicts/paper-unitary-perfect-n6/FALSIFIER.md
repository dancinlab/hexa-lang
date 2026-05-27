# Pre-registered falsifier — paper-unitary-perfect-n6-dual

**Registered before measurement** (TECS-L axis-0 n=6 minimality program; INBOX #10 paper 2/3).

## F-DUAL-PERFECT-N6

> ∃ n ≠ 6 with σ(n) = 2n  AND  σ*(n) = 2n   ⟹   uniqueness FALSIFIED.

Where
- σ(n)  = Σ_{d|n} d        — ordinary divisor sum (n is *ordinary-perfect* iff σ(n)=2n).
- σ*(n) = Σ_{d‖n} d        — unitary divisor sum, d‖n ⟺ d|n ∧ gcd(d, n/d)=1
                              (n is *unitary-perfect* iff σ*(n)=2n).

## Finding hypothesis (to be confirmed or falsified)

n = 6 is the **unique** simultaneous ordinary-AND-unitary perfect number in a
verifiable range [1, N]. Concretely:

1. n=6 is BOTH the smallest ordinary-perfect AND the smallest unitary-perfect.
2. The two perfection sequences **diverge immediately after 6**:
   - next ordinary-perfect = 28; σ*(28) ≠ 56  ⟹ 28 is NOT unitary-perfect.
   - next unitary-perfect  = 60; σ(60)  ≠ 120 ⟹ 60 is NOT ordinary-perfect.
3. No n in [1, N] other than 6 satisfies BOTH predicates  (closed-negative
   ruling out the "second coincidence" axis on the tested range).

## Measurement protocol (g5 — verify-via-CLI-only)

- σ(6), σ(28), σ(60)        via `hexa verify --expr sigma <n> <v>`.
- σ*(6), σ*(28), σ*(60)     via `hexa verify --expr sigma_star <n> <v>`
  (sigma_star landed PR #1473; built into bin/hexa-verify from worktree source).
- The full n=1..N sweep via a hexa-native driver importing the SAME stdlib SSOT
  (`stdlib/core/math` :: sigma / sigma_star) that backs verify_cli — guaranteeing
  the sweep and the per-value CLI verdicts share one source of truth.

## Terminal-verdict requirement (paper_gate)

PROCEED to scaffold ONLY if every core value is 🔵 SUPPORTED-FORMAL and the
sweep returns DUAL-PERFECT count == 1 (n=6). Any 🟠/🟡/⚪ → DEFER.
A non-1 dual count ⟹ FALSIFIED (which is itself a publishable closed-negative,
but would change the finding framing).
