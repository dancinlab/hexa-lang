# TECS-L F19 spec — BSD congruent-number rational-point witness lane (PARTIAL ANGLE)

@axis: MATH-MILLENNIUM (Clay G axis)
@target: Birch–Swinnerton-Dyer (BSD)
@scope: **partial angle**, NOT a proof. n=6 deep witness.
@status: 🔵 partial — integer-exact rational-point witnesses at n=5, n=6 (UNCONDITIONAL on BSD)

## 1 · What this is, and what it is NOT

**IS**: a verify-witness lane for BSD's congruent-number specialization. For
square-free n ≥ 1, n is a *congruent number* iff E_n: y² = x³ − n²x has positive
rank over ℚ. By Mazur's torsion theorem applied to E_n, the torsion subgroup is
*always* Z/2Z × Z/2Z = {∞, (0,0), (n,0), (−n,0)} (4 points). Therefore the
existence of any rational point (x,y) with y ≠ 0 is equivalent to rank ≥ 1, and
the n is a congruent number. **This direction does not need BSD.**

**IS NOT**: a proof of BSD. BSD is the statement L(E,1) = 0 ⟺ rank ≥ 1
(refined: ord_{s=1} L(E,s) = rank(E(ℚ))). We use only the *unconditional*
direction (rational point ⇒ rank ≥ 1); the converse (rank ⇒ L-vanishing) is BSD.

## 2 · TECS-L methodology transfer

| TECS-L primitive (axis 0)         | Transferred form (this lane)                  |
|-----------------------------------|----------------------------------------------|
| n=6 closed-form witness          | (−3, 9) ∈ E_6(ℚ) integer witness             |
| sopfr / D(n) integer arithmetic   | y² = x³ − n²x integer arithmetic check       |
| M1/M10 unicity locus              | E_n unicity of torsion = Z/2 × Z/2 ∀ sqfree n |
| Closed-negative ruling-out        | n ∈ {1,2,3} non-CN by Fermat descent (🟡 cite) |
| n=6 multilayer probe              | n=6 appears in BOTH the σφ=nτ locus AND the CN list — independent axes |

## 3 · Concrete partial-result (this F19 round)

**Verified integer witnesses (UNCONDITIONAL):**

  n=5 : (x,y) = (−4, 6)
    y² = 36
    x³ − n²x = (−4)³ − 25·(−4) = −64 + 100 = 36
    ✓ EXACT INTEGER MATCH → rank(E_5(ℚ)) ≥ 1 → 5 is CN

  n=6 : (x,y) = (−3, 9)
    y² = 81
    x³ − n²x = (−3)³ − 36·(−3) = −27 + 108 = 81
    ✓ EXACT INTEGER MATCH → rank(E_6(ℚ)) ≥ 1 → 6 is CN
      (classical: 3-4-5 right triangle has area 6)

Anchor verdicts (load-bearing for the integer arithmetic above):
  hexa verify --expr sigma 6 12 → 🔵 (anchor for n=6 σ scale)
  hexa verify --expr phi 6 2     → 🔵
  hexa verify --expr tau 6 4     → 🔵
  hexa verify --expr mu 5 -1     → 🔵 (5 squarefree)
  hexa verify --expr mu 6 1      → 🔵 (6 squarefree)

The rational-point checks themselves are *cubic Diophantine arithmetic* in the
integers; not yet a `hexa verify` builtin (would need a new 3-op fn like
`elliptic_y2x3` checking y² = x³ + a·x + b for integer (x, y, a, b)).
**OPEN FRONTIER (verify infra)**: add `elliptic_witness` 4-op or similar to
verify_cli to fold this lane to per-witness 🔵 directly.

## 4 · n=6 multilayer observation (TECS-L cross-axis)

n = 6 is non-trivial in BOTH:

  Axis 0 (TECS-L identity locus): σ(6)·φ(6) = n·τ(6) = 24 (M1 unique-with-1)
  Axis G (BSD/CN): 6 IS a congruent number (smallest, classical)

The TECS-L unicity locus is {1, 6}; the CN sequence A003273 starts {5, 6, 7,
13, 14, …} — DIFFERENT sets. **n = 6 lies in both, n = 1 does not** (1 is not
a CN). This is consistent with TECS-L principle 3 (arithmetic-vs-geometric
layer separation): σ/τ/φ identity is an *arithmetic* layer; CN-ness is a
*geometric/L-function* layer. Different layers, different unicity sets.

**Honest**: this is an **observation**, not a mechanistic link. No claim that
the σφ=nτ identity at n=6 *causes* CN-ness at n=6. Both axes have n=6 as
non-trivial, but the proofs are independent.

## 5 · Atlas fold decision

**FOLD candidates** (subject to gate; 4-op verify-fn doesn't exist yet so
auto-absorb path blocked):
  e5_witness:  (x=-4, y=6) ∈ E_5(ℚ) non-torsion rational point
  e6_witness:  (x=-3, y=9) ∈ E_6(ℚ) non-torsion rational point

**Current decision: NO atlas fold this round.** Reason: verify_cli has no
elliptic-curve witness fn; folding without a verify recompute path would
violate `claim_verify` g5. Defer until `elliptic_witness` 4-op is added
(F19 follow-up: g59 INBOX → stdlib/verify_cli.hexa).

## 6 · Paper-significance assessment (paper_significance gate)

- Pre-registered falsifier? **PARTIAL** — could pre-register "n=1 has a
  rational point with y≠0" (would be FALSIFIED by Fermat). But we don't
  recompute Fermat descent in hexa.
- Real measurement? **YES** — 2 integer-exact rational-point witnesses + 5
  anchor verdicts.
- Finding? **MARGINAL** — partial unconditional supporting evidence for
  rank(E_n) ≥ 1 at specific n, not a Δ vs baseline (these are classical results
  reformulated as hexa-verify witnesses).

**Verdict: paper-INELIGIBLE under strict paper_significance.** No /paper draft.
This is a candidate-spec only (per @D candidate_spec_only in millennium scope).
A *survey paper* on the verify-witness lane structure (NOT a Clay claim) could
be drafted if scoped honestly; deferred.

## 7 · Cross-link

- Methodology: TECS-L axis 0 M4 (n=6 characterizations triage) + M10 (closed-
  form unicity) — same closed-form-integer-arithmetic discipline.
- Architectural reuse: stdlib/core/math.hexa σ/τ/φ/μ for anchor verdicts.
- Follow-up: INBOX entry to add `elliptic_witness` 4-op verify fn (then fold
  e5/e6_witness atoms to embedded.gen.hexa).
