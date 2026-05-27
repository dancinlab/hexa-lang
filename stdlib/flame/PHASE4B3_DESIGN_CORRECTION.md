# Phase 4-B-3 design correction — block_fwd is INLINE, not leaf-call

> Honest finding from audit 2026-05-17 cycle. Corrects PHASE4B3_LEAF_PRIORITY.md
> framing about "leaf fn replacement" — the leaf fns are NOT called from
> block_fwd body. block_fwd inlines all leaf logic directly.

## What the audit found

```bash
grep -cE "nn_rmsnorm_fwd|nn_swiglu_fwd|nn_linear_fwd|nn_attn_core_fwd|nn_rope_apply_fwd" \
    stdlib/flame/decoder_block_lib.hexa
# → 1  (single hit, in a comment: "Inline (parallel to nn_attn_core_fwd...)")
```

`nn_decoder_block_fwd` (decoder_block_lib.hexa:217-509) inlines:
- RMSNorm × 2 (pre-attn-norm, pre-ffn-norm)
- Q/K/V projection (with farr_matmul-routed inner)
- RoPE rotation (inline cos/sin table lookups)
- Attention (softmax + value combine, ~60 lines)
- SwiGLU (2 matmul + silu + Hadamard + 1 matmul, ~40 lines)
- Residual adds (2)

The leaf fns (nn_rmsnorm_fwd, nn_swiglu_fwd, nn_attn_core_fwd, etc.)
exist in nn_lib.hexa as **standalone test/verification surface**
(used by Phase 2 falsifiers like F-RFC043-LAYER-EQ-RMSNORM-FWD).
They are NOT the composition path block_fwd uses.

## Implication for Phase 4-B-3-2-third

PHASE4B3_LEAF_PRIORITY.md framed the work as "specialize each leaf
fn → wire block_fwd to call specialized leaves". This was incorrect:
**no leaf calls exist in block_fwd to wire**.

The CORRECT Phase 4-B-3-2-third path is closer to the original
PHASE4B3_EMISSION_DESIGN.md "specialized kernel emission" model:
**emit a primitive C version of the ENTIRE block_fwd body**, with
all inline farr_get/set replaced by direct `_hx_farr_table[id].buf`
dereferences.

The boxing-elim 4× MEASURED still applies — it's the per-farr-access
boxing inside the inline body that we're eliminating, not per-fn-call
boxing.

## Revised Phase 4-B-3-2-third plan

**Sub-step 4-B-3-2-third-1 (REVISED)**: emit the entire primitive
block_fwd body (one specialization per dims_hash), with inline
operations preserved but farr_get/set → direct pointer dereference.

- Effort: 1-2 cycles for the fwd body (~200 lines of careful C
  hand-translation from the hexa-source body)
- Falsifier: F-RFC047-BLOCK-EMIT-BYTE-EQ-FWD strict byte-eq on
  F-RFC043-BLOCK-DET inputs (T=3·d=8 toy)
- Risk: mid-high (reduction-order discipline, FMA fusion context
  preservation; Path C revert commit `23705dc5` reminds us strict
  byte-eq is sensitive)

**Sub-step 4-B-3-2-third-2 (REVISED)**: bwd body primitive emission.
Same pattern, larger body (~290 lines hexa-source).
- Effort: 2-3 cycles
- Falsifier: F-RFC047-BLOCK-EMIT-BYTE-EQ-BWD

**Sub-step 4-B-3-2-third-3 (REVISED)**: full corpus benchmark.
- Falsifier: F-RFC047-CORPUS-EMIT-STEP-EQ + F-RFC047-BLOCK-WALL-IMPROVED ≥3×

## What about the leaf primitive emit (commit `dcd2ed74`)?

The `flame_rmsnorm_d32_fwd_primitive` emit + byte-eq verify (commits
`dcd2ed74` + `1da62cc1`) is STILL VALID as:
- ABI proof: `_hx_farr_table[id].buf` direct dereference works
- Verification template: byte-eq harness pattern for primitive vs reference
- Standalone usable: if hexa-source is rewritten to call this primitive
  via `extern fn`, that path is unlocked

But it does NOT help block_fwd specialization directly — block_fwd
doesn't call nn_rmsnorm_fwd. The leaf primitive becomes useful if/when:
(a) we extract block_fwd's RMSNorm inline into a separate leaf and
    rewrite block_fwd to call the leaf — duplicates work + extra
    indirection, NOT recommended
(b) we use the leaf primitive in NEW client code that calls it
    directly via extern fn — orthogonal use case

For Phase 4-B-3-2-third's wall improvement goal, the correct path is
emit the full primitive block_fwd body (not leaf-by-leaf).

## Cycle accounting (honest)

Commits `0a95371b` (emitter scaffold), `f5182641` (trampoline emit),
`28cf24a6` (caller wire-up) all remain useful — they implement the
build pipeline infrastructure (trampoline ABI, sed call-site rewrite,
forward-decl insertion, concat) which the corrected Phase 4-B-3-2-
third still uses.

Commits `dcd2ed74` (leaf rmsnorm primitive emit) and `1da62cc1`
(byte-eq verify) are not blocked but become design-validation
artifacts rather than the wall-improvement path. The verification
template + ABI proof both remain valid contributions.

Commit `725ff6bb` (PHASE4B3_LEAF_PRIORITY.md) — the leaf-by-leaf
framing is incorrect for the wall-improvement path. Should be read
with this correction in mind.

## What Phase 4-B-3-2-third-1 (REVISED) looks like

```c
// build/artifacts/<stem>_b3_block_fwd.c — appended to concat'd .c
//
// Specialized primitive block_fwd for dims (T=16, d=32, nh=4, nkv=2, h=64).
// Algorithmically identical to nn_decoder_block_fwd (decoder_block_lib.hexa:217).
// All inline farr_get/set replaced with _hx_farr_table[id].buf[index].

static inline void flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id
) {
    double* X   = _hx_farr_table[X_id].buf;
    double* Bp  = _hx_farr_table[Bp_id].buf;
    double* Bc  = _hx_farr_table[Bc_id].buf;
    double* cos_ = _hx_farr_table[cos_id].buf;
    double* sin_ = _hx_farr_table[sin_id].buf;

    // Constants from dims (literal-baked at emit time):
    const int T_ = 16, d_ = 32, nh_ = 4, nkv_ = 2, h_ = 64;
    const int hd = 8, kvd = 16;  // d/nh, nkv*hd
    const int g1_off = 0, Wq_off = 32, Wk_off = 32+1024, /* ... */;

    // 1. per-position RMSNorm(X, g1) → rin, rm1xn, rm1inv
    for (int i = 0; i < 16; i++) {
        double ms = 0.0;
        for (int c = 0; c < 32; c++) {
            double xi = X[i*32 + c];
            ms += xi * xi;
        }
        ms /= 32.0;
        double iv = 1.0 / sqrt(ms + 1e-6);
        Bc[rm1inv_off + i] = iv;
        for (int c = 0; c < 32; c++) {
            double xni = X[i*32 + c] * iv;
            Bc[rm1xn_off + i*32 + c] = xni;
            Bc[rin_off + i*32 + c] = Bp[g1_off + c] * xni;
        }
    }
    // ... Q/K/V projection inline + RoPE rotation + attention + SwiGLU + residuals
    // (200+ lines, mirroring decoder_block_lib.hexa:217-509 line-by-line)
}
```

## Next user-gate

The wall-improvement path is now clearly:
1. Hand-translate nn_decoder_block_fwd hexa body to primitive C (1-2 cycles)
2. Wire (trampoline body → primitive call instead of HexaVal fn) (1 cycle)
3. F-RFC047-BLOCK-EMIT-BYTE-EQ-FWD strict gate (PASS required)
4. F-RFC047-CORPUS-EMIT-STEP-EQ (corpus byte-id preserved)
5. F-RFC047-BLOCK-WALL-IMPROVED ≥3× measurement

Total revised effort: 3-5 cycles for the fwd-only specialization,
mirrored for bwd.

Risk-tier upgrade: mid-high (was originally low for leaf-by-leaf;
hand-translation of full block body is more careful work).

## Cross-link

- PHASE4B3_LEAF_PRIORITY.md (commit `725ff6bb`) — read with this correction
- PHASE4B3_EMISSION_DESIGN.md (commit `828717fb`+pivots) — original full-block
  approach now validated; leaf-by-leaf detour was incorrect
- decoder_block_lib.hexa:217-509 — nn_decoder_block_fwd hexa-source body
  (the canonical algorithm to hand-translate)
- Path C revert (commit `23705dc5`) — strict byte-eq discipline reminder
