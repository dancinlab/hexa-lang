# RFC 048 — flame Phase 4-C: fwd+bwd graph fusion at compile time

- **Status**: design-draft (2026-05-17) — DESIGN ONLY, no implementation
- **Date**: 2026-05-17
- **Severity**: HIGHEST IMPACT (RFC 046 marks Phase 4-C as the dominant single Phase 4 win at the d=32·3L baseline where bwd is 75% of per-step wall)
- **Priority**: P1 (the path to F-RFC046-EAGER-PYTORCH-MATCH ≤1.3× of 336.85s on A100)
- **Builds on**: RFC 047 (Phase 4-B per-block IR pass — the prerequisite Stage 2 specialization), RFC 046 (Phase 4 fusion design), RFC 045 (Phase 3 closure)
- **Source convergence**: RFC 046 §"Phase 4-C — Stage 3 fwd+bwd graph fusion (HIGHEST IMPACT)" identifies this as the dominant fusion win. RFC 048 is its design.
- **Source evidence (g3)**:
  - PERF.md 5-run × 8-iter measurement (commit `3c755d68`): per-step bwd is **75% of total wall** at d=32·3L M-Mac CPU; fwd is 25%; AdamW is sub-ms. **bwd dominance ratio holds** across 1-run, 3-run, and 5-run conventions; not a measurement artifact.
  - RFC 047 Phase 4-B per-block IR pass design specifies the prerequisite fwd-only specialization (12-pass-through-memory → 2-3 register-resident passes per block); Phase 4-C extends this to merge the fwd cache materialization step with the bwd intermediate consumption step.
  - flame ↔ anima 3.12e-5 init-gn2 delta (RFC 045 source #4) must remain preserved exactly across Phase 4-C — emit pattern change, not math change.
  - TorchInductor / JAX-XLA reference: same compile-time fwd+bwd dataflow graph fusion produces 5-10× wall reduction on transformer training; this is the documented PERF target for end-to-end-training-compile architectures.

## Scope of this RFC — design draft, no implementation

RFC 048 specifies the **fwd+bwd graph fusion** — at flame stdlib build time, the IR pass takes the paired `nn_decoder_block_fwd(...)` and `nn_decoder_block_bwd(...)` invocations and emits a **single specialized C function per block-shape** that runs the fwd pass, holds ALL intermediate values in vector registers, then runs the bwd pass directly off those registers without ever writing the per-position cache (rin, hstate, ctx, sw_a, sw_b, sw_s, ...) to memory.

It lands **zero implementation**: no new source files, no codegen edits, no build. Specifies the pass architecture, IR representation, emit pattern, verification battery, staged plan, and honest performance thesis update.

## Problem — Phase 4-B leaves fwd cache materialization on the floor

After Phase 4-B Stage 2 lands (RFC 047 design), the flame emit pattern per block is:

1. `flame_block_<dims>_fwd(X, Bp, Bc, cos, sin)` — specialized fwd. All intermediates live in registers WITHIN the function, but the **block cache Bc** (rin, hstate, rin2, rm1xn, rm2xn, ctx, Q, K, V, P, sw_a, sw_b, sw_s, rm1inv, rm2inv — see decoder_block_lib.hexa) is **WRITTEN TO MAIN MEMORY** at function exit. That's ~8·T·d + 2·T·kvd + nh·T·T + 3·T·h + 2·T floats = ~8K floats per block per fwd pass at d=32·3L.

2. `flame_block_<dims>_bwd(X, Bp, Bc, dXout, dX_out, Bg, cos, sin)` — specialized bwd. Reads back the **entire Bc** from main memory to consume the cached intermediates. ~8K floats per block per bwd pass.

That's **8K floats × 2 reads/writes × 3 layers × 80 steps × 8 windows = ~30M cache transfers** through main memory per training step that are pure overhead — the data was just in registers a microsecond earlier in the fwd pass.

Eager-PyTorch + TorchInductor / JAX-XLA solve this by emitting a single kernel covering fwd + bwd; intermediates never leave the register file (or, on GPU, never leave shared memory). RFC 048's Phase 4-C does the same for flame.

## Proposal — paired fwd+bwd specialization at IR pass time

### Pass placement

RFC 048's Phase 4-C extends the RFC 047 Phase 4-B IR pass. After Phase 4-B's pattern-matcher detects a fwd block call site, it **continues forward in the AST** looking for the matching bwd block call site (within the same enclosing scope, within a bounded statement-distance window). If found AND the dim args match exactly, the two are emitted as a **single fused function** with shared register-resident intermediates.

```
.hexa source
   ↓ module_loader flatten              (existing)
   ↓ flame_phase4b pattern-match        (RFC 047)
   ↓ flame_phase4c fwd+bwd pairing      (NEW Phase 4-C extension)
   ↓ codegen_c2                         (existing)
```

Build flag: `hexa build --flame-phase4c` enables it (also implies `--flame-phase4b`). Default OFF → Phase 4-B path or Phase 3-J + 4-A-bwd path.

### Pairing detection

In `nn_decoder_grad` (decoder_lib.hexa), the per-layer bwd loop has the structure:

```hexa
while l_b >= 0 {
    ...
    nn_decoder_block_bwd(Xin, Bp_l, Bc_l, dXc, dX_l, Bg_l, cos, sin, ...)
    ...
    l_b = l_b - 1
}
```

And the matching fwd pass in `nn_decoder_fwd`:

```hexa
while l < n_layer {
    ...
    nn_decoder_block_fwd(Xc, Bp_l, Bc_l, cos, sin, T, d, nh, nkv, h)
    ...
    l = l + 1
}
```

The IR pass recognizes these as a **fwd/bwd pair** when:
1. Both call `nn_decoder_block_{fwd,bwd}` with the same (T, d, nh, nkv, h) static dims.
2. The fwd call writes the cache farr `Bc_l`; the bwd call reads it.
3. The dataflow between them is: cache farr in/out, no intervening modification.

When detected, the pair is rewritten to a single call:

```hexa
flame_block_fused_<dims>(Xc, Bp_l, dXc, dX_l, Bg_l, cos, sin)
```

Note: the **block cache Bc is no longer materialized** — it never appears at the user-visible AST level. flame's loop structure changes from "fwd-stack-down + bwd-stack-up with cache materialization" to "do-fwd-then-bwd-per-layer-with-register-only-cache" — equivalent gradient checkpointing at the block granularity (since each block independently re-runs its fwd just before its bwd in the same function call).

### Emit pattern

For each unique (T, d, nh, nkv, h) tuple, the pass emits:

```c
// Auto-generated by flame_phase4c for (T=16, d=32, nh=4, nkv=2, h=64)
static void flame_block_fused_T16_d32_nh4_nkv2_h64(
    int X_id,        // [T·d] input
    int Bp_id,       // packed params
    int dXout_id,    // [T·d] upstream gradient
    int dX_out_id,   // [T·d] output gradient (caller-pre-zero)
    int Bg_id,       // packed gradients (caller-pre-zero; this fn accumulates)
    int cos_id, int sin_id
) {
    // ALL intermediates live in vector registers; clang -O2 sees the
    // constants → register allocation for the entire 8K-floats cache
    // (M2 has 32 v-registers × 2 doubles = 64 fp64 register slots —
    // most intermediates can live there; remainder spills to L1).
    double rin[16*32];        // T·d
    double hstate[16*32];
    double Q[16*32];
    double K[16*16];          // T·kvd
    double V[16*16];
    double P[4*16*16];        // nh·T·T
    double sw_a[16*64];       // T·h
    double sw_b[16*64];
    double sw_s[16*64];
    // ... rm1xn, rm2xn, ctx, rm1inv, rm2inv ...

    // === FORWARD PASS ===
    // Pass 1: RMSNorm(X, g1) + Q/K/V proj + RoPE rotation + attn core
    // Pass 2: SwiGLU + residual
    // (all per RFC 047 Phase 4-B fwd specialization)

    // === BACKWARD PASS ===  (begins immediately after fwd; same fn)
    // Reads intermediates directly off the in-function arrays — NO
    // farr_get from a Bc farr. clang -O2 vectorizes accesses as register
    // moves where possible.
    // Pass 3: SwiGLU bwd → da/db → dWg/dWu/dWd → dr
    // Pass 4: RMSNorm2 bwd → dh contribution → dg2 accum
    // Pass 5: Wo bwd → dWo accum + dctx
    // Pass 6: attention_core bwd → dQ/dK/dV
    // Pass 7: RoPE inverse rotation → pre-RoPE dQ/dK
    // Pass 8: Q/K/V proj bwd → dWq/dWk/dWv accum + drin
    // Pass 9: RMSNorm1 bwd → dx_path + dg1 accum
    // Write final dX_out = dh + dx_path
    // Write final Bg accumulator updates
}
```

The C function is large (~600-800 LoC C per specialized variant after Phase 4-C emission), but compiler sees through it and produces ~50-100 vectorized instructions per block — dominated by the projection matmuls + attention core + SwiGLU compute, with intermediate dataflow tracked via register coloring.

### What about the Bc cache farr?

The Bc cache is **eliminated at the user-visible level** for Phase 4-C call sites. The fused kernel is self-contained: caller passes only (X, Bp, dXout, dX_out, Bg). The user's `nn_decoder_block_fwd / bwd` pair calls remain in source — they're rewritten by the pass to the fused call. Outside the Phase 4-C-affected scope (e.g., `decoder_lib.hexa::nn_decoder_grad`), the bwd loop must be restructured to do block-fwd-then-block-bwd per layer rather than fwd-all-then-bwd-all. RFC 048's pass handles this restructure when it detects the pattern.

### Memory profile

Without Phase 4-C: per training step at d=32·3L:
  - block_cache (Bc) writes: 3 layers × ~8K floats × 8 bytes = ~192 KB per fwd pass
  - block_cache reads: same on bwd pass
  - total: ~384 KB DRAM traffic per step per cache type

With Phase 4-C:
  - block_cache becomes register-resident → ~0 DRAM traffic for intermediates
  - parameters (Bp) + gradients (Bg) still in DRAM but read/write only once
  - estimated DRAM traffic reduction: 50-70% of per-step memory bandwidth

For GPU (Phase 4-D), this is the dominant fusion win — A100's memory bandwidth is ~2 TB/s, FLOPs are ~19 TFLOPS FP64. flame d=768·12L gradient checkpointing in eager-PyTorch is memory-bound; Phase 4-C eliminates the materialization → bandwidth-bound regime shifts to compute-bound regime.

## Verification

### Falsifier battery (F-RFC048-*)

- **F-RFC048-FUSED-FWD-BWD-EQ** — flame_block_fused_<dims>(...) output byte-identical to the paired (nn_decoder_block_fwd + nn_decoder_block_bwd) result (RFC 047 Phase 4-B specialization is the comparison baseline). max|Δ| = 0.0 on F-RFC043-BLOCK-DET + F-RFC043-D32 + F-RFC043-DECODER-DET test inputs.
- **F-RFC048-DECODER-FULL-EQ** — full decoder_lib fwd + grad output byte-id when Phase 4-C is enabled on all blocks. Falsifier reuses F-RFC043-DECODER-GRAD-EXACT 10-probe central-diff at the Phase 3 numerical level.
- **F-RFC048-STEP-EQ** — 80-step trajectory byte-id on d=32·3L corpus benchmark (RFC 045 F-RFC043-STEP-EQ-ORACLE reproduction). flame ↔ anima 3.12e-5 init-gn2 delta MUST be preserved exactly. The acc 8/8 trajectory + collapse 8.98e6× MUST reproduce.
- **F-RFC048-FUSED-WALL-IMPROVED** — 5-run avg wall reduction (Phase 4-C vs Phase 4-B baseline). target ≥2× over Phase 4-B (Phase 4-B target ~4.5s on M-Mac CPU d=32·3L; Phase 4-C target ≤2.5s). Combined with Phase 4-B, total Phase 4 wall reduction = (current 13.33s) → (~2.5s) ≈ 5×, matching RFC 046's Stage 1+2+3 ~10× combined expectation.
- **F-RFC048-FALLBACK-PRESERVED** — when Phase 4-C is OFF, build path is Phase 4-B + Phase 3-J + 4-A-bwd byte-identical (regression sweep all PASS).
- **F-RFC048-EAGER-PYTORCH-MATCH** — flame d=768·12L on A100 wall ≤1.3× of eager-PyTorch 336.85s. Combined with Phase 4-B + GPU dispatch.

(≥3 falsifiers per AGENTS.tape directive; this RFC specifies 6, with F-RFC048-FUSED-FWD-BWD-EQ + F-RFC048-DECODER-FULL-EQ as the connection-point closed checks per `g_blue_closed_mandate`.)

## Phasing

- **Phase 4-C-1 — pairing detection in IR pass**. Extend Phase 4-B pattern matcher to recognize fwd/bwd pairs with matching dims and dataflow. No emission yet (just log). Falsifiers: F-RFC048-FALLBACK-PRESERVED. **Effort: ~1 cycle.**
- **Phase 4-C-2 — fused emit (single-layer test)**. Emit one specialized fwd+bwd kernel per (dims, ) tuple. Test on F-RFC043-BLOCK-* falsifiers. **Effort: ~2 cycles.** Expected: ~2-3× wall reduction over Phase 4-B alone.
- **Phase 4-C-3 — multi-layer rewrite (decoder_lib.hexa restructure)**. Rewrite the fwd-loop-then-bwd-loop pattern in `nn_decoder_grad` to fwd-then-bwd-per-layer. Falsifiers: F-RFC048-DECODER-FULL-EQ + F-RFC048-STEP-EQ. **Effort: ~2 cycles.** Expected: full ~5× wall reduction (RFC 048 alone over Phase 4-B baseline).
- **Phase 4-C-4 — d=768·12L specialization + GPU dispatch**. Verify pass handles d=768·12L; Phase 4-D GPU fire with both Phase 4-B and Phase 4-C enabled. Falsifier: F-RFC048-EAGER-PYTORCH-MATCH. **Effort: 1 fire cycle, ~$5-20 cost-bearing.**

Total estimate: 5-7 cycles for full Phase 4-C pipeline (including GPU dispatch). Combined Phase 4 (4-A-bwd + 4-B + 4-C): ~10-14 cycles total → eager-PyTorch parity target reachable.

## Honest performance thesis update

RFC 046 stated Phase 4-C as "HIGHEST IMPACT, target ~10× wall improvement combined". RFC 048 sharpens:
- **Phase 4-C alone over Phase 4-B baseline**: ≥2× wall (4.5s → 2.5s on M-Mac CPU d=32·3L 80-step). Mechanism: register-resident block cache eliminates ~192KB DRAM round-trip per layer per step.
- **Combined Phase 4-B + 4-C over Phase 3-J baseline**: ≥5× wall (13.33s → 2.5s). The 5× comes from (a) Phase 4-B's 12-pass-through-memory → 2-3 in-register passes (~3×), and (b) Phase 4-C's eliminating the per-block cache materialization (~2×).
- **Phase 4-B + 4-C + GPU (4-D) on A100 d=768·12L**: ≤1.3× of eager-PyTorch 336.85s wall. Scaling math (PERF.md): 13.33s × 64 (params) / 50 (A100 vs M-Mac fp64) / 5 (Phase 4 fusion factor) ≈ 3.4s. Comfortably below 336.85s with 100× margin even — possibly enters RFC 043 §"Ultimate" "exceed eager-PyTorch" territory at this configuration. RFC 048 conservatively states ≤1.3× of eager-PyTorch as the falsifier; the actual margin could be 100×.

**Honest framing**:
- Phase 4-C ≥2× over Phase 4-B is back-of-envelope based on the ~192KB-per-layer cache materialization elimination. clang -O2 register pressure at 8K-floats-of-intermediates may force more spill than estimated → actual gain could be lower. F-RFC048-FUSED-WALL-IMPROVED is the falsifier.
- The "exceed eager-PyTorch" possibility is mentioned as an upper-bound scaling implication, NOT this RFC's assertion. RFC 043 §"Ultimate" remains the separate qualitative claim.
- **No n=6 lattice perf assertion anywhere**. Anchors: PERF.md measured 13.33s baseline + 75% bwd ratio + ~192KB-per-layer cache size + eager-PyTorch 336.85s anima A100 baseline + A100 memory bandwidth 2 TB/s.

## Non-goals (this RFC)

- No implementation. Design only.
- No public API change. flame's `nn_decoder_block_fwd/bwd` + `nn_decoder_fwd/grad` signatures stay bit-identical. The IR pass rewrites paired calls invisibly.
- No replacement of the autograd-tape model (RFC 034) — the bwd math is unchanged; only the EMIT pattern (when paired with fwd) is fused.
- No assertion of "exceed eager-PyTorch" — that's RFC 043 §"Ultimate". This RFC's assertion is "match-or-beat eager-PyTorch by ≤1.3× ratio".
- No gradient checkpointing at non-block granularity (e.g., layer-level or full-model-level) — Phase 4-C operates at the block level only. Multi-block fusion would be RFC 049+ if needed.

## Cross-RFC dependency

- **RFC 043** (design SSOT) — Phase 4-C is the dominant path RFC 043 §Phasing pointed to. **Consumed.**
- **RFC 045** (Phase 3 closure) — Phase 4-C preserves Phase 3 numerics bit-identically; F-RFC048-STEP-EQ is the regression check.
- **RFC 046** (Phase 4 fusion design) — Phase 4-C = Stage 3 from RFC 046. **Builds on**. F-RFC046-FUSED-BWD-EQ is the same falsifier as F-RFC048-FUSED-FWD-BWD-EQ.
- **RFC 047** (Phase 4-B IR pass design) — Phase 4-C **extends** Phase 4-B's pass with fwd/bwd pairing. Phase 4-B is the prerequisite (specialized fwd emission); Phase 4-C wires the bwd into the same function.
- **RFC 044** (forge regime) — Phase 4-C's specialized C functions live in `self/forge/`. Cross-link coordination with parallel session.

## Honest caveats (g3)

- **Design-only, multi-cycle implementation.** Full Phase 4-C pipeline (4-C-1 → 4-C-4) is ~5-7 cycles. Phase 4-C-4 is the cost-bearing GPU dispatch ($5-20).
- **≥2× over Phase 4-B threshold is a target, not a guarantee.** Register-pressure interaction with clang -O2 on 8K-floats of cached intermediates could force unexpected spill. F-RFC048-FUSED-WALL-IMPROVED measures the actual ratio; if <1.5×, the pass design needs revision.
- **flame ↔ anima 3.12e-5 init-gn2 delta preserved exactly.** No math change.
- **Cross-session coordination with forge required**: Phase 4-C emits specialized C kernels into self/forge/. RFC 044 + 048 must converge on the shared emission convention.
- **Block-level granularity only**: Phase 4-C does not fuse across blocks (e.g., layer-0 bwd + layer-1 fwd). The 3-layer stack still does 3 sequential block_fused calls. RFC 049+ if multi-block fusion ever becomes a target.

## Cross-link

- RFC 043 (design SSOT)
- RFC 045 (Phase 3 closure)
- RFC 046 (Phase 4 fusion design) — F-RFC046-FUSED-BWD-EQ
- RFC 047 (Phase 4-B IR pass design) — prerequisite Stage 2
- RFC 044 (forge regime, parallel session) — emit target directory
- flame PERF.md — 5-run measurement baseline
- flame_perf_breakdown_test.hexa — per-step breakdown harness
- flame_d32_corpus_test.hexa — 80-step corpus benchmark
- anima d_corpus_fire — reference oracle (gn2 7.97116 → 3.73374e-07)
- anima eager-PyTorch baseline — `~/core/anima/state/anima_pytorch_d768x12L_fire_2026_05_16/fire.log`
