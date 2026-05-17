# PHASE4C_PAIR_DETECT_DESIGN.md — Phase 4-C-1a paired-call detector spec

> Single-page design SSOT for `tool/flame_phase4c_pair_detect.hexa` (the
> first scaffold step of RFC 048 / Phase 4-C — fwd+bwd graph fusion).
> Cross-link: `PHASE4C_IMPLEMENTATION_AUDIT.md` §8 (scope), §3 (autonomy),
> §6 R1 (reduction-order preservation). Pure-additive scaffold —
> detection-only, observation-only, no source transform, no
> perturbation of the Phase 4-B SHIPPED build path.

## 1. Purpose

Validate the **IR pattern matcher** that subsequent commits (4-C-2 fused
emit) will rely on, BEFORE doing any source-transform work. Per the Path C
revert lesson (PHASE4C_IMPLEMENTATION_AUDIT.md §6 R1 + PERF.md commit
`23705dc5`), all reduction-order-sensitive IR changes must be validated
at the match level first — wall-fire and emit changes only happen after
detection is proven sound.

The detector scans an expanded `.hexa` source (post-`module_loader`
flatten) for paired `nn_decoder_block_fwd(...)` and
`nn_decoder_block_bwd(...)` call sites that share matching static
`(T, d, nh, nkv, h)` dimension tuples, and logs them. Output is a single
`state/flame_phase4c_pairs.log` artifact + a `PASS F-RFC048-PAIR-DETECT`
line if ≥1 pair is detected.

## 2. AST predicates

The fused-emit pass (Phase 4-C-2) requires three predicates to fire
simultaneously per `(fwd-call, bwd-call)` candidate pair:

### 2.1 Callee-name match (REQUIRED, exact)

- fwd: `nn_decoder_block_fwd(` (identifier-prefix match; ignore comments
  and `fn ` declarations)
- bwd: `nn_decoder_block_bwd(` (same prefix-match discipline)

The detector skips occurrences inside `//` comment lines and `fn ` decl
contexts, and rejects matches where the preceding character is an
identifier-character (avoids `XX_nn_decoder_block_fwd(` false hits).

### 2.2 Static-dim-arg equality (REQUIRED, lexical eq on last-5 args)

Both calls' argument lists must end with the same 5 positional args
representing `(T, d, nh, nkv, h)`. The detector splits args
parenthesis-balanced (treats `(`, `[`, `{` symmetrically as depth
markers, `,` as separator only at depth 0), then compares the last-5
slice of fwd args against the last-5 slice of bwd args as text strings.

Concrete expected match for `flame_d32_corpus_test.hexa` (d=32·3L):

```
fwd: nn_decoder_block_fwd(Mp, Mc, Mg, Op, Og, T, d, nh, nkv, h)
                                         ↑──── last 5 args ────↑
bwd: nn_decoder_block_bwd(Mp, Mc, Mg, Op, Og, Bg, dXout, dX_out, T, d, nh, nkv, h)
                                                                ↑──── last 5 args ────↑
```

Both tuples evaluate as the text `(T, d, nh, nkv, h)` → match.

The text-eq layer is sufficient at this scaffold stage because the
expanded source post-IPCP already canonicalizes dim args to literal-only
positional form. Phase 4-C-2 will tighten this to integer-literal eq
after IPCP rewrite (`hexa_int(16), hexa_int(32), ...`).

### 2.3 Bc-farr dataflow edge (DEFERRED to 4-C-2)

The full RFC 048 mechanism requires verifying that the same `Bc` (block
cache) farr id is written by the fwd call and read by the bwd call with
no intervening modification. This is the dataflow predicate that
authorizes the rewrite from "write-to-farr-then-read" to
"register-resident local arrays".

For 4-C-1a (this commit), the dataflow check is **deferred**. The
log-only output is sufficient evidence that the IR pattern matcher
fires on the expected call sites; dataflow tightening lands in
4-C-2a (`tool/flame_phase4c_block_fused_primitive.c` emit step), where
the actual source transform happens.

## 3. Why text-scan vs full AST (this commit)

**Choice for 4-C-1a: text-scan with parenthesis-balanced arg splitter.**

Rationale:

1. **Cheap iteration**: text-scan + balanced-paren tokenizer is ~200 LoC of
   hexa source, no parser-state machinery. Compare ~600+ LoC for a full
   AST walker.
2. **Sufficient for callee-name + last-N-arg-text match**: the two
   predicates that gate this scaffold step are both expressible as
   text-level operations on the expanded `.hexa` source.
3. **De-risks the IR pattern matcher cheaply**: if the predicate logic is
   wrong (e.g., misses the loop-body call shape, false-matches similar
   non-paired calls), it's caught at the log-only stage before any
   source-transform work commits to a flawed match strategy.
4. **Upgrade path is clear**: Phase 4-C-2's `flame_phase4c_emit_fused.hexa`
   (planned) will reuse the existing `flame_phase4b3_emit_trampoline.hexa`
   AST infrastructure to do dim-arg integer-eq match + dataflow check.
   The 4-C-1a text-scan logic translates ~1:1 to AST predicate calls.

Anti-rationale (rejected): building a full AST walker for 4-C-1a alone
would block this scaffold step on parser-infra investment that pays off
only at 4-C-2. Per PHASE4C_IMPLEMENTATION_AUDIT.md §8 "smallest viable
first commit", the 4-C-1a strategy is **minimal infra, maximum signal**.

## 4. F-RFC048-PAIR-DETECT falsifier spec

**Statement**: For the `flame_d32_corpus_test.hexa` (d=32·3L config)
expanded source, the detector finds **≥1** paired `(fwd, bwd)` call site
with matching static `(T, d, nh, nkv, h)` tuple. The detector emits the
literal string `PASS  F-RFC048-PAIR-DETECT` on stdout.

**Anchor expected output** (commit `ff8923d6` empirical baseline):

```
─── detected call sites ───
  fwd  line 1281  dims=(T,d,nh,nkv,h)
  bwd  line 1490  dims=(T,d,nh,nkv,h)

─── paired-call analysis ───
  PAIR  fwd line 1281 ↔ bwd line 1490  dims=(T,d,nh,nkv,h)

  total fwd call sites: 1
  total bwd call sites: 1
  matched pairs (same dim tuple): 1
PASS  F-RFC048-PAIR-DETECT  ≥1 paired fwd+bwd call site detected (fusable)
```

**Failure modes** (each is a real falsification if observed):

1. **No matches** (`pair_count = 0`) — pattern matcher is broken; the
   predicate logic doesn't fire on the canonical call shape. Action:
   audit detector code, do NOT proceed to 4-C-2.
2. **Multiple matches** (`pair_count ≥ 2` on `flame_d32_corpus_test`) —
   the per-loop call site is being double-counted, OR the source has
   additional fwd/bwd pairs that 4-C-2 must consider. Action: investigate
   before authorizing emit.
3. **Mismatched dims** (fwd and bwd dim tuples differ) — IPCP pass
   produced inconsistent specialization; this would also break Phase 4-B
   trampoline wire-up. Action: cross-check against 4-B SHIPPED state.
4. **Falsifier on a no-decoder source** (e.g., `flame_block_test.hexa`
   single-block standalone) emits `INFO` rather than `PASS` — correct
   behavior, no decoder loop = no paired call sites.

**How verified in CI**: `tool/flame_phase4b3_verify_all.sh` artifact #24
runs the detector on the expanded `flame_d32_corpus_test.hexa` source
and grep-checks for the literal `PASS  F-RFC048-PAIR-DETECT` line. Exit
non-zero if absent or if grep fails.

## 5. How 4-C-1a feeds into 4-C-2 (fused primitive emit)

The detector's per-pair output is the **input contract** for Phase 4-C-2's
fused-primitive emit step. Specifically:

- Each detected `(fwd-line, bwd-line, dim-tuple)` triplet becomes one
  candidate `flame_block_fused_<dims>(...)` C primitive that 4-C-2a
  hand-translates from the existing
  `tool/flame_phase4b3_block_fwd_primitive.c` (~270 LoC) +
  `tool/flame_phase4b3_block_bwd_primitive.c` (~400 LoC) pair by
  concatenating + dataflow-stitching (Bc-write at fwd-exit replaced with
  local-array writes; Bc-read at bwd-entry replaced with local-array
  reads).
- The `flame_phase4c_build.sh` script will extend (Phase 4-C-2b) with a
  fused-primitive concat step + sed-rewrite of the paired call sites to
  the single `_fused_` call, gated on the detector's PASS output.
- Phase 4-C-3 (post-user-gate) will extend the detector's dataflow
  predicate (§2.3) to verify "no intervening Bc modification between fwd
  and bwd call sites" — required before authorizing the
  `decoder_lib.hexa` restructure to fwd-then-bwd-per-layer.

**Invariant** (preserved through 4-C-1a → 4-C-2 → 4-C-3): the detector
output is the single source of truth for "which call sites are fusable".
Subsequent emit + restructure work consults `state/flame_phase4c_pairs.log`
rather than re-deriving the match. This makes the IR pattern matcher
the canonical authority + simplifies post-hoc audit of fusion decisions.

## 6. Out of scope (explicitly)

- **No source transform** — detector is log-only. Phase 4-B SHIPPED build
  path is untouched (g3 fallback preservation).
- **No emit work** — fused-primitive C generation is 4-C-2 scope.
- **No `decoder_lib.hexa` modification** — restructure is 4-C-3 (user-gated).
- **No GPU / cost-bearing fire** — `flame_block_fused_<dims>` GPU dispatch
  is 4-C-4 (user-gated).
- **No dataflow verification** (§2.3) — deferred to 4-C-2 emit step.
- **No multi-source corpus scan** — the detector currently runs on a
  single source file at a time; per-build-target scan only.

## 7. Cross-references

- `PHASE4C_IMPLEMENTATION_AUDIT.md` — scoping + scope-decision rationale
  (§3 autonomy classification, §6 risk taxonomy, §8 first-commit scope).
- `tool/flame_phase4c_pair_detect.hexa` — detector implementation (~210
  LoC hexa source, scaffold step landed at commit `ff8923d6`).
- `tool/flame_phase4c_build.sh` — build wrapper that runs detector after
  Phase 4-B SHIPPED build (commit landing with this design doc).
- `tool/flame_phase4b3_verify_all.sh` — CI verification battery; extends
  to 24 artifacts including `F-RFC048-PAIR-DETECT` (commit landing with
  this design doc).
- `inbox/rfc_drafts_2026_05_12/rfc_048_flame_phase4c_fwd_bwd_graph_fusion.md`
  — RFC 048 full design (mechanism, falsifier suite, projection).
- `tool/flame_phase4b3_emit_trampoline.hexa` — Phase 4-B AST infra that
  Phase 4-C-2's full-AST detector (§2.3 dataflow upgrade) will extend.
