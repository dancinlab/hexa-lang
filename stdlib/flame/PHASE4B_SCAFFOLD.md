# flame Phase 4-B-1 scaffold — findings (RFC 047)

> Detect-only Phase 4-B scaffold landed 2026-05-17. No source transform,
> no emit; pattern matching + classification + dims_hash only. Findings
> below drive the Phase 4-B-2 design decision (next user-directed cycle).

## What landed

- **`tool/flame_phase4b_scan.hexa`** — text-based call-site scanner for
  `nn_decoder_block_fwd` / `nn_decoder_block_bwd`. Skips fn-decls and
  comments. Paren-balanced multi-line call gather. Classifies last-5 args
  (T, d, nh, nkv, h) as `literal-tuple` / `variable-tuple` / `mixed-tuple`.
  Emits `dims_hash` (djb2 of (T,d,nh,nkv,h) text) for literal-tuple sites.

- **Falsifier F-RFC047-SCAFFOLD-DETECT** — on synthetic source with
  direct-literal call sites, scaffold reports ≥1 literal-tuple. PASS
  verified on `/tmp/literal_site.hexa` (3 literal + 1 mixed; same dims
  fwd+bwd → same hash 0x388e4067 → emit-once-reuse semantic confirmed).

- **Falsifier F-RFC047-SCAFFOLD-FALLBACK** — on real flame sources
  (`flame_block_test.hexa`, `decoder_lib.hexa`, `decoder_block_lib.hexa`,
  `flame_d32_corpus_test.hexa`), scaffold reports zero literal-tuple,
  zero false-positives on fn-decl lines. PASS verified.

## Real-source result matrix (post-fn-decl-skip)

| Source | call sites | literal-tuple | variable-tuple | mixed-tuple |
|---|---|---|---|---|
| `flame_block_test.hexa` | 5 | 0 | 5 | 0 |
| `decoder_lib.hexa` | 2 | 0 | 2 | 0 |
| `decoder_block_lib.hexa` | 0 (fn-decls skipped) | — | — | — |
| `flame_d32_corpus_test.hexa` | 0 (no direct calls) | — | — | — |

## Key finding: zero direct-literal call sites in current flame stack

All real flame sources pass `T, d, nh, nkv, h` as **fn parameters**
threaded from outer scopes. The first literal binding lives in:
- `flame_d32_corpus_test.hexa::main` — `let T = 16, d = 32, nh = 4, nkv = 2, h = 64`
- `flame_block_test.hexa::main` — same shape, smaller (T=3 or T=4)

These literals reach the call site only after **inter-procedural constant
propagation** through `nn_decoder_train_step → nn_decoder_fwd →
nn_decoder_block_fwd` (3-hop chain) or `flame_block_test::*_test →
nn_decoder_block_fwd` (1-hop).

## Implication for Phase 4-B-2

The RFC 047 §39 "extract static dim constants" requirement cannot be
satisfied by purely call-site-local literal matching. The pass needs
ONE of:

**(a) inter-procedural constant propagation** — walk back from the
  block-call site through caller chain until literals are found. Heavy
  machinery; risk: false positives when same caller is reached via
  multiple distinct literal paths (would need to specialize the caller
  too, recursively).

**(b) source-level specialization wrappers** — add `flame_decoder_d32_3L`
  / `flame_decoder_d768_12L` wrappers that bake the dims as literals.
  Block calls become literal-tuple at the wrapper layer. Simpler;
  matches the "ONE specialized fwd + ONE specialized bwd" model from
  RFC 047 §121. Cost: source-level duplication for each target config.

**(c) attribute-driven specialization** — add a `@specialize(T=16, d=32, ...)`
  attribute on `nn_decoder_train_step` that the pass reads. Cleanest
  surface; reuses the hexa-lang attribute machinery (cf. `ai_native_pass.hexa`).
  Cost: requires attribute-pass integration.

**Recommended for first emission attempt (Phase 4-B-2)**: option (b) —
the wrapper approach. Lowest risk (no compiler-internals access), gives
the literal-tuple call site the scaffold needs, and is reversible. If
performance proves out, option (c) becomes the productionization.

## What's NOT in scope for Phase 4-B-1 scaffold

- Build flag `--flame-phase4b` (next cycle — wire to `cmd_build`)
- AST-level walking (text-scan is sufficient for detect-only)
- Source rewriting (no emit yet)
- Inter-procedural CP (option (a) above — separate Phase 4-B-1.5 if pursued)

## Algorithm self-anchor

`dims_hash = djb2((T,d,nh,nkv,h) text)` — deterministic, 31-bit positive int.
Same tuple text always hashes to same value → idempotent + duplicate-free
across multiple call sites with the same dims. Verified: `T=16, d=32,
nh=4, nkv=2, h=64` → `0x388e4067` for both fwd and bwd calls (same hash =
emit-once-reuse semantic, RFC 047 §121).

## Cross-link

- RFC 047 §39 (pass placement) + §54 (pattern matching) + §144 (Phase 4-B-1)
- PERF.md "Path C attempt" (REVERTED 2026-05-17) — lesson for Phase 4-B-2
  emission: must operate on SHARED reference path or preserve reduction
  order, else Phase 2 strict byte-eq regresses
- `tool/flame_phase4b_scan.hexa` — the scaffold tool itself
