# OUROBOROS-novel M3 verdict — known_catalog.gen.hexa KNOWN shard + β-classifier

- **Date**: 2026-07-03
- **Branch**: `feat/ouroboros-m3-known-catalog`
- **Design SSOT**: `state/fable-eval-discovery-2026-07-02/NEXUS_novel_design_fable.md` §2-P2 / §3 · roadmap M3 row
- **Verified on**: summer (linux · CC=clang · `hexa v0.574.1`), fresh `git reset --hard origin/feat/ouroboros-m3-known-catalog`
- **Command**: `hexa run compiler/atlas/known_catalog_test.hexa` — exit 0

## Shard scale
- **Identity shard**: 58 atlas @F pure-basis product identities (A·B=C·D, all four tokens in the 18-fn af() basis) — the exact sub-space the drill BLOWUP enumerator reaches. Generated from `compiler/atlas/embedded.gen.hexa` (SSOT, unmodified) via `tool/known_catalog_gen.sh`. Numeric-constant point-value @F ("n*12=n*sigma") and physics/constant @F are outside the basis-product vocabulary and excluded by construction.
- **Sequence/composition shard**: 10 fingerprints — partition p(n), Fibonacci, Lucas, Bell, Catalan, central binomial C(2n,n), triangular, pentagonal (8 classical, mod-P recurrences) + σ∘σ and φ∘φ (nested-composition symbols). n² (squares) deliberately omitted — it is the size-2 product n·n, inside FP_k, so it must classify α not β.
- KNOWN total = 68 fingerprint entries. Frozen ie_* rolling-hash kernel (seed 1469598103 · base 1000003 · P=2^61−1) shared with identity_engine, so KNOWN and FP_k fingerprints are directly comparable. No new builtin.

## β-classification gate — PASS (16/16)
```
=== known_catalog M3 SELFTEST (N=64) ===
A. atlas @F product-identity shard (statement β):
  [PASS] count == 58 pure-basis identities
  [PASS] all 58 identities known (β 100%)
B. canonical fingerprint (permutation-invariant, no over-match):
  [PASS] A<->B swap known (8,5,9,9)
  [PASS] side swap known (9,9,5,8)
  [PASS] non-atlas tuple rejected (0,0,4,4)
C. KNOWN sequence shard (β rediscovery · negative-control):
  [PASS] all 10 KNOWN sequences classify (β 100%)
  [PASS] negctrl superperfect/Mersenne σ∘σ -> β
  [PASS] negctrl Ramanujan partition p(n) -> β
  [PASS] σ∘σ NOT in FP_k (composition ⊄ product frame)
  [PASS] partition NOT in FP_k (additive ⊄ multiplicative frame)
D. FP_k terms classify (α · inside the well):
  [PASS] σ (size-1) -> α
  [PASS] φ·J₂ (size-2) -> α
  [PASS] n·n squares in FP_k -> α (not β)
E. out-of-well non-known candidate (γ · the M4 admit case):
  [PASS] size-3 term n·σ·φ -> γ (∉FP_k ∧ ∉KNOWN)

M3 GATE PASS — β 100% · α/γ misclassification 0
```

**Gate met**: every existing rediscovery classifies (β) — 100% — with zero (α)/(γ) misclassification. The design's named negative-control triple (superperfect σ∘σ=2n, Mersenne σ∘σ=σ+n → the σ∘σ symbol; Ramanujan p(5n+4)≡0 → the partition symbol) all land β, and each is proven genuinely outside the current product grammar (∉ FP_k).

## byteeq / release integrity
Byte-neutral to shipping binaries: the two new `.hexa` files are compiler DATA + new functions, imported only by the selftest — nothing on the `hexa build`/`run`/drill-binary emit path references them yet (M4 wires them into emerge). No existing emitter output changes → no bit-changing behavior. New-builtin count = 0.

## M4 resume point
`compiler/drill/emerge.hexa` replacement (`emerge2`) + `emerge_test.hexa`: the 5 generators (sol-indicator · composition-symbolization · Dirichlet convolution · iterate/orbit · congruence-witness) + the inexpressibility gate (candidate h's fingerprint ∉ FP_k(G_t)). Wire `kc_classify(fp, fp_table, N)` from this shard so σ∘σ emerges and lands (β), while E4-style additive-closure candidates collide in FP_k and are rejected (α). The classifier + KNOWN infra this milestone lands is the prerequisite for M4's honest α/β/γ verdicts.
