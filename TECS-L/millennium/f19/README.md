# TECS-L F19 — Clay Millennium attempt via TECS-L methodology transfer

**Status**: candidate-spec only. **NOT a Clay-proof claim.**

This directory holds partial-angle work products on two Clay problems where
TECS-L's hexa-native verify methodology has a concrete (if narrow) transfer
path:

  RH  → `spec-rh-mertens-witness-lane.md`
        — Mertens function M(n) partial-sum sweep, μ(k) 🔵 per-element.
        — Range n=1..20; descriptive lane, no falsifier.

  BSD → `spec-bsd-congruent-number-witness.md`
        — Integer-exact rational-point witnesses on E_n: y²=x³−n²x.
        — n=5: (−4, 6) ✓; n=6: (−3, 9) ✓.
        — UNCONDITIONAL on BSD (only the rational-point ⇒ rank≥1 direction).

## Problem fit table (s1)

| Clay problem | TECS-L methodology fit  | Verify path        | F19 work |
|--------------|-------------------------|--------------------|----------|
| P vs NP      | none (complexity class) | no SAT path        | skip     |
| Hodge        | none (algebraic geometry)| no cohomology path | skip     |
| Poincaré     | DONE (Perelman 2003)    | N/A                | skip     |
| Riemann (RH) | PARTIAL — μ closed-form | μ builtin 🔵         | RH lane  |
| Yang-Mills   | none (QFT mass gap)     | no QFT path        | skip     |
| Navier-Stokes| none (PDE smoothness)   | no PDE path        | skip     |
| BSD          | PARTIAL — integer Diophantine | σ/τ/φ/μ anchors 🔵 | BSD lane |

## Honest verdict (final)

- **Real progress on Clay 7? NO.** This is *verify-infra and witness recasting*.
- **TECS-L methodology genuinely transferable to RH or BSD? PARTIAL** — only on
  the integer-arithmetic side of each problem. The hard parts (zero-distribution
  for RH, L(E,s) for BSD) remain off-lane.
- **paper_significance? FAIL for both.** No pre-registered falsifiers with
  finding-Δ; no paper drafts.
- **🔵 novel? Only the (−3,9)/(−4,6) integer-witness recast for E_5/E_6 in this
  particular form** — and these witnesses are CLASSICAL (Fibonacci-era), so
  even those are 🟡 KNOWN-IDENTITY restated in hexa-native form, not novel.

## What this adds to TECS-L

1. Two candidate-spec files in `TECS-L/millennium/f19/` showing the methodology-
   transfer pattern explicitly (which TECS-L primitives map to which Clay-axis
   constructs).
2. Verdict files (`.verdicts/tecs-l-f19-rh-mertens/`, `.verdicts/tecs-l-f19-bsd-tunnell/`)
   establishing the verify-lane.
3. An INBOX-able follow-up: add `elliptic_witness` 4-op verify-fn to enable
   per-witness 🔵 auto-fold for E_n rational-point checks (F19 follow-up).

## What this does NOT add

- No new theorems.
- No atlas atoms folded this round.
- No paper draft.
- No claim of "Clay-7 partial progress" beyond what TECS-L's axis 0 already
  carries (M4 has already cited Γ₀(6) on the modular-curve side; this just
  reframes Mertens / CN through the same lens).
