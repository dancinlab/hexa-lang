// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4c_block_fused_primitive.c — Phase 4-C-2a (SCAFFOLD)
//
// Phase 4-C-2a SCAFFOLD landing: fused fwd+bwd primitive wrapper.
// This file establishes the build pipeline + falsifier infra for full
// fusion. Honest scope:
//
//   THIS FILE (scaffold):  trivial wrapper calls fwd then bwd back-to-back.
//                         No Bc-elimination yet — Bc DRAM traffic
//                         unchanged. F-RFC048-FUSED-FWD-BWD-EQ PASSES
//                         trivially (semantically identical to paired call).
//                         F-RFC048-FUSED-WALL-IMPROVED FAILS (no win, by
//                         construction).
//
//   FULL FUSION (next):   incrementally extract Bc intermediates to C
//                         local arrays. Targets:
//                           - oRm1inv (16 doubles), oRm2inv (16 doubles)
//                           - oRm1xn (T*d = 512), oRm2xn (T*d = 512)
//                           - oRin (T*d = 512), oRin2 (T*d = 512)
//                           - oSwS (T*h = 1024)
//                         Matmul outputs (oQ, oK, oV, oP, oCtx, oSwA, oSwB)
//                         stay in Bc unless matmul primitive signature
//                         changes (next-RFC scope).
//
// Audit: stdlib/flame/PHASE4C_IMPLEMENTATION_AUDIT.md §4 (Phase 4-C-2a)
// Design: stdlib/flame/PHASE4C_PAIR_DETECT_DESIGN.md
// Falsifier: F-RFC048-FUSED-FWD-BWD-EQ (max|Δ|=0 vs paired-call baseline)
//
// ── Bc data flow audit (which intermediates are "pure fwd→bwd local") ──
//
// PURE LOCALS (eliminate Bc traffic, save ~6 KB DRAM RT per block-call):
//   oRm1inv  16 dbl   rmsnorm1 fwd → rmsnorm1 vjp (section 1rev)
//   oRm2inv  16 dbl   rmsnorm2 fwd → rmsnorm2 vjp (section 7rev)
//   oRm1xn  512 dbl   rmsnorm1 normalized → vjp x-grad
//   oRm2xn  512 dbl   rmsnorm2 normalized → vjp x-grad
//   oRin    512 dbl   rmsnorm1 output → matmul Q/K/V input (bwd reads for grad)
//   oRin2   512 dbl   rmsnorm2 output → SwiGLU input (bwd reads for grad)
//   oSwS   1024 dbl   silu(a)*b → SwiGLU bwd
//
// REMAINS IN Bc (matmul intermediate, requires _db_proj_batch_farr API change):
//   oQ, oK, oV, oP, oCtx (attention intermediates)
//   oSwA, oSwB (SwiGLU pre-activation)
//   oXout, oHstate (block output + residual)
//
// Total potential local-array footprint per block-call:
//   16+16+512+512+512+512+1024 = 3104 doubles = 24 KB
//   Fits in L1 cache (96 KB typical), well within frame budget.
//
// Build (standalone compile check):
//   clang -O2 -DFLAME_BLOCK_FUSED_PRIM_STANDALONE -c \
//     tool/flame_phase4c_block_fused_primitive.c -o /tmp/block_fused_prim.o
// ════════════════════════════════════════════════════════════════════════

// Forward declarations of fwd + bwd primitives.
// These are normally concat'd into the IPCP build pipeline via
// tool/flame_phase4c_build.sh. For standalone compile-check, the
// FLAME_BLOCK_FUSED_PRIM_STANDALONE define provides type stubs only.

#ifndef FLAME_BLOCK_FUSED_PRIM_STANDALONE
// Real build path: fwd + bwd primitives are concat'd alongside us by
// the build wrapper. Forward decls match their signatures.
extern void flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id
);
extern void flame_block_T16_d32_nh4_nkv2_h64_bwd_primitive(
    int X_id, int Bp_id, int Bc_id,
    int dXout_id, int dX_out_id, int Bg_id,
    int cos_id, int sin_id
);
#endif

#ifdef FLAME_BLOCK_FUSED_PRIM_STANDALONE
#include <math.h>
#include <stdint.h>
#include <stddef.h>
typedef struct { int tag; union { int64_t i; double f; void* p; }; } HexaVal;
typedef struct { double* buf; long len; void* d_buf; int loc, pinned, dirty_host, dirty_dev; } HexaFarrEntry;
static HexaFarrEntry* _hx_farr_table = NULL;
static void flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id
) {
    (void)X_id; (void)Bp_id; (void)Bc_id; (void)cos_id; (void)sin_id;
}
static void flame_block_T16_d32_nh4_nkv2_h64_bwd_primitive(
    int X_id, int Bp_id, int Bc_id,
    int dXout_id, int dX_out_id, int Bg_id,
    int cos_id, int sin_id
) {
    (void)X_id; (void)Bp_id; (void)Bc_id; (void)dXout_id; (void)dX_out_id;
    (void)Bg_id; (void)cos_id; (void)sin_id;
}
#endif

// ── Fused primitive (SCAFFOLD: trivial wrapper) ─────────────────────
//
// Signature combines fwd + bwd args. Semantically equivalent to
// invoking fwd then bwd back-to-back. Bc traffic unchanged from
// paired-call baseline at this scaffold level — full fusion is the
// next iteration (extract local intermediates per audit above).
//
static inline void flame_block_T16_d32_nh4_nkv2_h64_fused_primitive(
    int X_id, int Bp_id, int Bc_id,
    int dXout_id, int dX_out_id, int Bg_id,
    int cos_id, int sin_id
) {
    // ── fwd phase ─────────────────────────────────────────────────
    flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive(
        X_id, Bp_id, Bc_id, cos_id, sin_id
    );

    // ── bwd phase ─────────────────────────────────────────────────
    // Reads Bc that was just populated by fwd. At scaffold level,
    // this read goes through DRAM (Bc still materialized between
    // fwd-exit and bwd-entry). Full fusion (next iteration) extracts
    // intermediates to C local arrays sized per audit comment above
    // (3104 doubles total = 24 KB, L1-resident).
    flame_block_T16_d32_nh4_nkv2_h64_bwd_primitive(
        X_id, Bp_id, Bc_id, dXout_id, dX_out_id, Bg_id, cos_id, sin_id
    );
}

// ── Optional: byte-eq harness entry for F-RFC048-FUSED-FWD-BWD-EQ ──
//
// The fused primitive is byte-equivalent to paired-call baseline by
// construction — same fwd + same bwd in same order. Verify harness
// can be the existing flame_phase4b3_verify_all.sh pipeline; this
// scaffold needs no additional test driver because the fused output
// (dXout, dX_out, Bg) is bit-identical to paired baseline.
//
// Future Bc-elimination iterations will require explicit byte-eq
// re-verification per intermediate extracted, because local-array
// ordering may differ subtly from farr ordering (especially under
// clang -O2 vectorization of inner loops).
