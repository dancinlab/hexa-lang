# TECS-L F20 — Clay retry with verify-infra extension

> Round 20 of the TECS-L NOVEL/MILLENNIUM axis. Follow-up to F19 (PR #1372,
> 2026-05-27). Two lanes — RH (Mertens partial sum extension) and BSD
> (congruent-number witness extension) — and one verify-infra extension
> (mertens calc-fn proposal landed in source; binary-rebuild deferred).

## Scope

**Extreme honesty mandate (F20 cont.):** Clay full proof is *not* in scope.
F20 ships **scale-extensions** of F19's two lanes (verify-witness widening),
**three INBOX entries** documenting the next verify-fn gaps, and **one
verify-infra land attempt** (`mertens()` in stdlib + verify_cli arm). No
novel atom, no Δ-finding, no paper.

## What landed

1. **stdlib `pub fn mertens(n)`** — added next to `mobius()` in
   `compiler/atlas/symbolic/congruence_chain_engine.hexa`. Trivial loop
   summation; descriptive only, NOT a conjectural inequality.
2. **verify_cli `_recompute` arm** — `mertens` single-arg added next to
   `mobius`. `hexa parse` clean on both files.
3. **INBOX entries (3, 2026-05-27)** — `elliptic_witness(x,y,n)` (P1, BSD
   4-op), `tunnell_count_{odd,even}(n)` (P2, BSD ternary-form), `mertens(n)`
   (P0, F20 implementation).
4. **RH lane M(n) extension** — n=21..30 partial sums; 10 mu(k) g5-verified
   🔵; descriptive table format (NO conjectural claim). Cumulative range
   n=1..30 now witnessed.
5. **BSD lane CN witness extension** — n in {7,14,15,20,21,28,30} integer
   rational points exhibited on E_n: y^2 = x^3 - n^2 x (7 new witnesses).
   9 total when added to F19's n=5,6. Each witness check is hand-arithmetic
   (no calc-fn yet); 7 g5-verified sigma anchors confirm n is grounded.
6. **Atlas fold: NONE.** elliptic_witness fn doesn't exist as a verify path
   (g5 violation avoided per F19 pattern); mertens calc-fn is binary-embedded
   pending source-rebuild.

## What did NOT land

- Source-rebuild of `hexa` binary to activate `mertens` arm — refused by
  pool (heavy-classified, no eligible pool host workdir) AND local-bound
  heavy gate (mac fork-storm trigger, requires `sidecar sign local` 5-min
  token). Mertens is in source; binary still rejects with "no path for
  'mertens'" — verified live.
- elliptic_witness / tunnell_count source impls — multi-arg & ternary-form
  enum require new `--expr-3op` dispatch surface. INBOX spec only.
- Paper. `paper_significance` gate FAIL (no pre-registered falsifier with
  Δ-finding; scale-extension is descriptive). `paper_negative_ok` also
  FAIL (no closed-negative finding ruling out a specific axis).

## Honest assessment

**Is this real progress?** No. F20 is a **width-extension** of F19's two
verify-lanes (10 new mu g5 verdicts, 7 new sigma anchors, 7 new BSD
witnesses), plus a half-landed verify-infra fix (mertens in source, binary
inactive). Zero new mathematical content; zero closed-negative findings;
zero novel atoms.

**Framework recasting?** Yes — verifies the same descriptive observations
F19 had (|M(n)| small at small n; some CNs have small-height integer
points) at slightly larger scale. The asymptotic RH/BSD questions are
untouched. Mertens cnj remains disproved (Odlyzko-te Riele 1985); BSD
remains open.

**Closed-negative value?** Limited. The honest negative is that
**scale-extension alone (n=20 -> n=30) does not change the asymptotic
question**, which is what we'd already conjectured in F19. No new axis
ruled out.

**Paper-eligible?** No. `paper_significance` and `paper_negative_ok` both
fail per gate definitions.

**Verify-infra progress?** Marginal. mertens calc-fn source land closes
one of F19's three INBOX gaps in source; binary activation is blocked
behind hexa source-build (pool refused, local sign-token required). The
spec-only entries (elliptic_witness, tunnell_count) at least make the
gaps tracker-visible.

## Pointers

- F19 PR: #1372 (commit 007e8e8d)
- F19 specs (sibling): `TECS-L/millennium/f19/`
- F20 verdicts: `TECS-L/.verdicts/tecs-l-f20-rh-mertens/` (10 mu + table)
  and `TECS-L/.verdicts/tecs-l-f20-bsd-witnesses/` (7 sigma anchors + cn_witness summary)
- Source landing: `compiler/atlas/symbolic/congruence_chain_engine.hexa`
  (mertens fn) and `tool/verify_cli.hexa` (_recompute arm)
- INBOX: `INBOX.log.md` head entry 2026-05-27T00:30Z
