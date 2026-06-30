# ATLAS — domain guide (sub-CLAUDE · formerly TECS-L, renamed 2026-06-18)

> hexa-lang **governance SSOT is the repo-root `../CLAUDE.md`** (this file is merely its sub-domain guide; on conflict, root wins).
> Source note: `dancinlab/archive-TECS-L:CLAUDE.md` is a 4-line SPECKIT stub, so this guide replaces it instead of preserving it verbatim (the external repo name stays `archive-TECS-L`).

## What is this directory

`ATLAS/` (formerly `TECS-L/`) = the human-facing ledger of a **general universe-law discovery engine** (number theory · physics · cosmos · life/consciousness math).
It re-grounds `dancinlab/archive-TECS-L` (the consciousness-continuity engine source corpus, 375+ hypotheses) on top of hexa-lang's
theorem atlas + the `hexa verify` g5 gate.

```
ATLAS/
├─ README.md        — macro↔quantum Math System Map (single math map · 11-color legend + node graph)
├─ hypotheses/      — hypothesis docs 3074 (flat, no subfolders · docs/hypotheses + math/docs/hypotheses)
│  ├─ NNN-slug.md   — numbered hypotheses (002-golden-zone-universality … 132-second-law)
│  └─ H-XX-NNN-*.md — domain hypotheses (H-AI-·H-CX-·H-NT- etc.)
├─ archive/         — source-document preservation (README.md + math/README.md = Math System Map original)
│  └─ SOURCE.md     — provenance record
└─ CLAUDE.md        — this file
```

## Work rules (root governance + domain reinforcement)

- **The verification-atom machine SSOT** = `../compiler/atlas/embedded.gen.hexa` (rodata, frozen). To raise a hypothesis
  to "verified", `hexa verify` g5 PASS → atom fold (root `verify is ambient` rule).
- **n=6 is a single node** (lattice-as-tool · no anchoring on external domains · `../LATTICE_POLICY.md`).
  The map's center is the macro↔quantum bridges, not any particular number.
- **Honesty (c2)**: unread formulas · unverified models · lattice-fit · unproven conjectures are not fabricated but
  honestly tagged by tier (🟧/🟠/🟥 etc.). Golden Zone-dependent claims are 🟥 (when the model is unverified, the claim is unverified too).
- **No edits to preserved docs**: `archive/`·`hypotheses/` are faithful copies of the original — do not edit them;
  reflect new discoveries / re-groundings via the README map / atlas atoms.
- **Math DFS runs via `hexa loop --dfs`** (NOVEL axis): exploration of e.g. arithmetic-function identity spaces runs
  per the root governance `external LLM` rule on the **single surface `hexa loop --dfs`** (budget cap + verify gate)
  — ad-hoc Python scripts are only for one-off cross-checks, not the official path. **New discoveries
  should not get their own .md; append them to `README.md`'s "DFS Exploration Status" (the Ralph N chronicle)**
  + the verify atom is `../compiler/atlas/embedded.gen.hexa`. Exact-integer finite sweep = bounded-unique
  (🟩); universal ⟺ stays unclaimed until proven (c2). Reference engine: `state/novel-dfs/` (for reproduction/cross-check).
  **The 12-fn 2-term arithmetic-identity Venn is exhausted** (README Ralph 369~371) — the verifier was
  **upgraded** beyond that box (Ralph 375 · `compiler/atlas/identity_engine.hexa`): ① extended vocab of 6 (μ·λ·μ²·
  J₃·2^ω·core idx 12–17 · sign-exact) ② arity-3 (`verify_identity3` · `is_universal2/3` forall-n
  frame). Measured result = under the extended vocab, **all universal 2-generators are classical** (J₂=φ·ψ · core·rad=n) ·
  arity-3 bounded-unique 1431 all reduce to 2-term core → **novel=0** (honest DRY). The productive Venn is
  still the **composed/iterated function basis** (Ralph 372 σ∘σ superperfect/Mersenne — function composition ≠ value product).
  **Orthogonal pivot (Ralph 377 · 2026-06-27)**: leaving the multiplicative vocab for **non-multiplicative generating-function/recurrence sequences** (partition
  p(n) A000041 · Catalan A000108 · Bell A000110 · Fibonacci A000045 · Lucas A000032) —
  the new identity FORM = arithmetic-progression **congruence** `a(αn+β)≡0 (mod m)` (Ramanujan p(5n+4)≡0 mod5 = no multiplicative
  analog, canonical). native exact-int (`identity_engine.hexa`: partition_p·catalan·bell·fib·lucas + mod-m
  table + `verify_congruence`) + selftest (`drill/additive_test.hexa`) + drill wiring (`_native_additive_screen`
  → `DRILL_ADDITIVE` audit) + reference engine `state/novel-dfs/additive_partition_hunt.py`. **Measurement** (N=4000):
  sanity 8/8 PASS (Ramanujan 3-congruence rediscovered) · congruence sweep RAMANUJAN=3 · KNOWN-structural=752 (Touchard/
  Lucas-divisibility/Deutsch–Sagan) · TAUTOLOGY=31 · **NOVEL=0** · cross-seq bounded-unique=0. An orthogonal
  domain, yet equally DRY (all classical Ramanujan/Watson/Atkin/Touchard/Lucas/Deutsch–Sagan) — honest 0
  report (no fabrication). The pivot itself is the deliverable (the engine natively represents non-multiplicative sequences + the congruence FORM). The congruence is [0,N]
  bounded · ∀n UNPROVEN (c2). The next unexplored dimension is still composed/iterated functions (Ralph 372).
- Detailed history is in `../CHANGELOG.md` + git.
