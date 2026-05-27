/* ═══════════════════════════════════════════════════════════════════
 * forge_tier_v1.c — RFC 050 v1 ABI stub dispatcher.
 *
 * STAGE A LAND (this file): the API surface is real + stable; the
 * Stage 2 tier registry is empty until per-tier substrate RFCs land
 * (RFC 044 A'/B'/C' Stage 2, RFC 049 BF16, RFC 048 fused). Calls
 * that ask for an unbuilt tier fall back deterministically through
 * the RFC 050 §6.6 chain ending at the RFC 040 cuBLAS Dgemm chain
 * (or CPU farr on no-CUDA hosts).
 *
 * MATMUL + FP64 + (any regime) + DET_DEFAULT is routed directly to
 * the existing hexa_farr_matmul (CPU + cuBLAS-conditional) - the
 * RFC 040 baseline that is the always-available fallback at the
 * bottom of the chain. Until Stage 2 tiers register specialized
 * kernels, every supported dispatch is a fallback by definition;
 * we honestly return FORGE_FALLBACK_USED so callers can log it.
 *
 * Compiled inline at the end of self/runtime.c so hexa_farr_matmul
 * (defined earlier in the same TU) is in scope without a forward
 * declaration that would re-clash with HexaVal-vs-int signatures.
 *
 * SSOT: inbox/rfc_drafts_2026_05_12/rfc_050_flame_forge_integration.md
 * ═══════════════════════════════════════════════════════════════════ */
#include "forge_tier_v1.h"

#include <stddef.h>
#include <string.h>

/* ─── BF16 substrate surface (RFC 049 / RFC 050 Stage 2) ──────────────
 * The BF16 precision path routes to runtime_bf16.c's `*_bf16_gpu` entry
 * points. Those symbols only exist when this TU is compiled together
 * with runtime_bf16.c (the nvcc -x cu build, or a standalone harness
 * that #includes runtime_bf16.c before this file). A TU that wants the
 * BF16 routing live #defines FORGE_TIER_V1_BF16 — parallel to the
 * FORGE_TIER_V1_LIVE guard for the FP64 path. When FORGE_TIER_V1_BF16
 * is NOT defined the BF16 branches return FORGE_PRECISION_UNSUPPORTED
 * (graceful — no behavior change, no link dependency on runtime_bf16.c).
 *
 * ABI note (RFC 050 §6.3): for BF16-precision dispatch the
 * ForgeArgs.farr_ids[] slots carry `HexaFarrBf16*` pointers cast to
 * int64_t via intptr_t — see the ForgeArgs comment in forge_tier_v1.h.
 * The dispatcher recovers them with `(HexaFarrBf16*)(intptr_t)id`. */
#ifdef FORGE_TIER_V1_BF16
#include <stdint.h>
/* runtime_bf16.c defines `typedef struct HexaFarrBf16 { ... }
 * HexaFarrBf16;` — so the `struct HexaFarrBf16` tag is in scope when
 * this file is #included AFTER it (the standalone harness + the nvcc
 * TU pattern). A bare `struct HexaFarrBf16;` re-declaration of an
 * already-defined tag is legal C; the dispatcher only ever passes the
 * pointer through, so the incomplete-type forward decl is sufficient
 * for the extern signatures below. The including TU is responsible for
 * having runtime_bf16.c's definitions linkable. */
struct HexaFarrBf16;  /* opaque — dispatcher only passes the pointer */
extern int hexa_farr_matmul_bf16_gpu(struct HexaFarrBf16* A,
                                     int64_t M, int64_t K,
                                     struct HexaFarrBf16* B, int64_t N,
                                     struct HexaFarrBf16* C);
extern int hexa_farr_ffn_bf16_gpu(struct HexaFarrBf16* X,
                                  int64_t M, int64_t D, int64_t FD,
                                  struct HexaFarrBf16* W1,
                                  struct HexaFarrBf16* W2,
                                  struct HexaFarrBf16* Y);
#endif /* FORGE_TIER_V1_BF16 */

/* ─── version ─────────────────────────────────────────────────────── */
uint32_t forge_api_version_v1(void) {
    return FORGE_API_VERSION_V1_ENCODED;
}

/* ─── specialized registry (in-memory, capped) ────────────────────── */
/* flame Phase 4-C / RFC 048 will populate this at module-init. The v1
 * stub stores entries but does NOT consult the registry from dispatch
 * yet (no specialized fn_ptr is callable through a single int return
 * signature; full plumbing arrives with Stage 2 when specialized
 * kernels exist). Empty registry => every dispatch falls back.    */
#define FORGE_REG_CAP 256
typedef struct ForgeRegEntry {
    int                 in_use;
    int                 kernel_family;
    int                 precision_policy;
    int                 regime_hint;
    ForgeShapeInfo      shape;
    void               *fn_ptr;
} ForgeRegEntry;
static ForgeRegEntry _forge_reg_table[FORGE_REG_CAP];
static int           _forge_reg_count = 0;

int forge_register_specialized_v1(
    int                     kernel_family,
    const ForgeShapeInfo   *shape,
    int                     precision_policy,
    int                     regime_hint,
    void                   *fn_ptr
) {
    if (!shape || !fn_ptr)            return FORGE_INVALID_ARGS;
    if (_forge_reg_count >= FORGE_REG_CAP) return FORGE_INVALID_ARGS;
    ForgeRegEntry *e   = &_forge_reg_table[_forge_reg_count++];
    e->in_use          = 1;
    e->kernel_family   = kernel_family;
    e->precision_policy= precision_policy;
    e->regime_hint     = regime_hint;
    e->shape           = *shape;
    e->fn_ptr          = fn_ptr;
    return FORGE_OK;
}

/* ─── dispatcher ──────────────────────────────────────────────────── */
/* MATMUL + FP64 path: delegates to hexa_farr_matmul (RFC 040 baseline,
 * always available). On non-CUDA hosts this runs the CPU reference;
 * on CUDA hosts hexa_farr_matmul forwards through the cuBLAS Dgemm
 * path inside runtime.c. Either way: correct, byte-eq with the CPU
 * farr oracle, and the bottom of the §6.6 fallback chain.       */
static int _forge_dispatch_matmul_fp64(
    const ForgeShapeInfo *shape,
    const ForgeArgs      *in,
    const ForgeArgs      *out
) {
    if (!shape || !in || !out)        return FORGE_INVALID_ARGS;
    if (in->count  < 2)               return FORGE_INVALID_ARGS;
    if (out->count < 1)               return FORGE_INVALID_ARGS;
    if (shape->M <= 0 || shape->N <= 0 || shape->K <= 0) return FORGE_INVALID_ARGS;

    int64_t a_id = in->farr_ids[0];
    int64_t b_id = in->farr_ids[1];

    /* Output-farr contract (L1 slice 1, RFC 050 §6.2):
     * hexa_farr_matmul follows the RFC 032 pattern — it allocates its
     * OWN output farr and returns the integer handle (id into the host
     * _hx_farr_table). The dispatcher does NOT pre-allocate the output
     * farr; instead it writes the produced id back into the caller's
     * out->farr_ids[0] slot so the caller (flame / the forge_dispatch_
     * matmul builtin) can recover the result. The `out` parameter is
     * declared `const ForgeArgs*` for ABI stability, but the result-id
     * write-back is a documented, deliberate exception — we cast away
     * const for that single slot store. The caller still OWNS the farr
     * lifetime (RFC 035/040 arena ownership): the dispatcher produces
     * the handle, the caller releases it. A future _v2 ABI may make
     * `out` non-const to surface this intent in the type. */
    int64_t c_id = out->farr_ids[0];
    (void)c_id;  /* slot is OUT-only: overwritten with the produced id below */

    /* The live MATMUL+FP64 path delegates to hexa_farr_matmul (defined
     * in runtime.c). That dependency only exists when this TU is
     * compiled inline by runtime.c (which #defines FORGE_TIER_V1_LIVE
     * before the #include). Standalone smoke builds skip the live
     * call so the dispatcher can be unit-tested without linking the
     * whole runtime.                                                 */
#ifdef FORGE_TIER_V1_LIVE
    extern HexaVal hexa_farr_matmul(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                                    HexaVal b_v, HexaVal bc_v);
    extern HexaVal hexa_int(int64_t);
    extern int64_t hexa_as_num(HexaVal v);
    HexaVal r = hexa_farr_matmul(hexa_int(a_id),
                                 hexa_int(shape->M),
                                 hexa_int(shape->K),
                                 hexa_int(b_id),
                                 hexa_int(shape->N));
    /* Plumb the produced farr id back into the caller-designated out
     * slot. hexa_farr_matmul returns the farr handle (or hexa_int(-1)
     * on a bad-args / OOM path); hexa_as_num unwraps it to int64_t. The
     * caller checks for a negative id to detect failure. */
    ((ForgeArgs *)out)->farr_ids[0] = hexa_as_num(r);
#else
    (void)a_id; (void)b_id;  /* standalone smoke: ack args, skip live call */
#endif
    /* Stage A: even when MATMUL+FP64 runs the live RFC 040 baseline,
     * report FORGE_FALLBACK_USED — the registry-based specialized
     * path is empty until Stage 2. Caller (flame) can log + continue. */
    return FORGE_FALLBACK_USED;
}

/* ─── BF16 dispatch helpers (RFC 050 Stage 2, RFC 049 substrate) ──────
 * These route FORGE_PREC_PURE_BF16 work to the fire-validated
 * runtime_bf16.c entry points (RFC 049 Stage 2 measured-PASS:
 * hexa_farr_matmul_bf16_gpu 8.48× FP64 cuBLAS, hexa_farr_ffn_bf16_gpu
 * 11.66×). The ForgeArgs.farr_ids[] slots carry HexaFarrBf16* pointers
 * cast through intptr_t (see the forge_tier_v1.h ForgeArgs comment).
 *
 * When FORGE_TIER_V1_BF16 is not defined the BF16 substrate symbols are
 * not in scope, so each helper returns FORGE_PRECISION_UNSUPPORTED —
 * graceful, no crash, honoring the §6.6 no-crash mandate.            */

/* MATMUL + PURE_BF16: C[M,N] = A[M,K] @ B[K,N], all HexaFarrBf16.
 * in->farr_ids = [A,B]; out->farr_ids = [C]. Maps the kernel's
 * 0 ok / -1 err to FORGE_OK / FORGE_KERNEL_UNSUPPORTED. */
static int _forge_dispatch_matmul_bf16(
    const ForgeShapeInfo *shape,
    const ForgeArgs      *in,
    const ForgeArgs      *out
) {
    if (!shape || !in || !out)        return FORGE_INVALID_ARGS;
    if (in->count  < 2)               return FORGE_INVALID_ARGS;
    if (out->count < 1)               return FORGE_INVALID_ARGS;
    if (shape->M <= 0 || shape->N <= 0 || shape->K <= 0) return FORGE_INVALID_ARGS;
#ifdef FORGE_TIER_V1_BF16
    /* farr_ids[] slots are HexaFarrBf16* cast via intptr_t (RFC 050 ABI). */
    struct HexaFarrBf16 *A = (struct HexaFarrBf16*)(intptr_t)in->farr_ids[0];
    struct HexaFarrBf16 *B = (struct HexaFarrBf16*)(intptr_t)in->farr_ids[1];
    struct HexaFarrBf16 *C = (struct HexaFarrBf16*)(intptr_t)out->farr_ids[0];
    if (!A || !B || !C)               return FORGE_INVALID_ARGS;
    int rc = hexa_farr_matmul_bf16_gpu(A, shape->M, shape->K, B, shape->N, C);
    /* Kernel: 0 ok / -1 err. -1 means the BF16 GPU substrate was
     * unavailable or cuBLAS failed — report KERNEL_UNSUPPORTED so the
     * caller can fall back through the §6.6 chain (never crash). */
    return (rc == 0) ? FORGE_OK : FORGE_KERNEL_UNSUPPORTED;
#else
    (void)shape; (void)in; (void)out;
    /* BF16 substrate not compiled in — graceful, no link dependency. */
    return FORGE_PRECISION_UNSUPPORTED;
#endif
}

/* FFN_FUSED + PURE_BF16: Y = SiLU(X @ W1) @ W2, all HexaFarrBf16.
 * Shape mapping (documented per task spec): M = shape->M (rows),
 * D = shape->K (model dim), FD = shape->N (FFN inner dim). The kernel
 * signature is hexa_farr_ffn_bf16_gpu(X, M, D, FD, W1, W2, Y).
 * in->farr_ids = [X,W1,W2]; out->farr_ids = [Y]. */
static int _forge_dispatch_ffn_bf16(
    const ForgeShapeInfo *shape,
    const ForgeArgs      *in,
    const ForgeArgs      *out
) {
    if (!shape || !in || !out)        return FORGE_INVALID_ARGS;
    if (in->count  < 3)               return FORGE_INVALID_ARGS;
    if (out->count < 1)               return FORGE_INVALID_ARGS;
    if (shape->M <= 0 || shape->N <= 0 || shape->K <= 0) return FORGE_INVALID_ARGS;
#ifdef FORGE_TIER_V1_BF16
    struct HexaFarrBf16 *X  = (struct HexaFarrBf16*)(intptr_t)in->farr_ids[0];
    struct HexaFarrBf16 *W1 = (struct HexaFarrBf16*)(intptr_t)in->farr_ids[1];
    struct HexaFarrBf16 *W2 = (struct HexaFarrBf16*)(intptr_t)in->farr_ids[2];
    struct HexaFarrBf16 *Y  = (struct HexaFarrBf16*)(intptr_t)out->farr_ids[0];
    if (!X || !W1 || !W2 || !Y)       return FORGE_INVALID_ARGS;
    /* M=shape->M, D=shape->K, FD=shape->N — see helper-comment mapping. */
    int rc = hexa_farr_ffn_bf16_gpu(X, shape->M, shape->K, shape->N,
                                    W1, W2, Y);
    return (rc == 0) ? FORGE_OK : FORGE_KERNEL_UNSUPPORTED;
#else
    (void)shape; (void)in; (void)out;
    return FORGE_PRECISION_UNSUPPORTED;
#endif
}

/* LAYERCAST (FORGE_PREC_LAYERCAST_BF16_FP32): the substrate kernel
 * hexa_farr_layercast_linear_bf16_gpu takes X / Y as plain `float*`
 * HOST arrays (only the weight is HexaFarrBf16). The ForgeArgs model
 * keys every slot as a farr handle / pointer — it has no clean way to
 * carry raw `float*` host activation buffers. Rather than overload the
 * int64 slot with a third pointer convention, layercast dispatch is
 * left UNSUPPORTED through the ForgeArgs path: callers that need the
 * LayerCast linear call hexa_farr_layercast_linear_bf16_gpu directly
 * (it is exported from runtime_bf16.c). A future _v2 ABI with an
 * explicit host-buffer descriptor would re-home it here.            */

int forge_tier_dispatch_v1(
    int                     kernel_family,
    const ForgeShapeInfo   *shape,
    int                     regime_hint,
    int                     precision_policy,
    int                     det_mode,
    const ForgeArgs        *in,
    const ForgeArgs        *out
) {
    /* PEDANTIC det mode is FP64-only per RFC 049 §3.3 (BF16 GemmEx
     * Tensor Core algos reduce in algo-dependent order — no cross-mode
     * bit-eq, see runtime_bf16.c contract C4). */
    if (det_mode == FORGE_DET_PEDANTIC && precision_policy != FORGE_PREC_FP64) {
        return FORGE_PRECISION_UNSUPPORTED;
    }
    /* Precision gate (RFC 050 Stage 2). FP64 is always available
     * (RFC 040 baseline). BF16 precisions route to the RFC 049
     * substrate below — no longer rejected outright. LAYERCAST_BF16_FP32
     * is accepted past this gate but its kernel family does not fit the
     * ForgeArgs model (host float* X/Y) — handled per-family below.
     * Any other precision value is genuinely unknown.               */
    if (precision_policy != FORGE_PREC_FP64 &&
        precision_policy != FORGE_PREC_PURE_BF16 &&
        precision_policy != FORGE_PREC_LAYERCAST_BF16_FP32) {
        return FORGE_PRECISION_UNSUPPORTED;
    }
    /* Regime is a hint, not a constraint; AUTO/SMALL/MEDIUM/LARGE all
     * accepted. Out-of-range values are still INVALID_ARGS.         */
    if (regime_hint < FORGE_REGIME_AUTO || regime_hint > FORGE_REGIME_LARGE) {
        return FORGE_INVALID_ARGS;
    }

    /* ─── BF16 precision routing (RFC 050 Stage 2 / RFC 049) ──────────
     * PURE_BF16 routes MATMUL + FFN_FUSED to the fire-validated
     * runtime_bf16.c entry points. Other (family, BF16) combinations
     * keep returning UNSUPPORTED honestly — their BF16 substrate is not
     * landed. LAYERCAST_BF16_FP32 does not fit the ForgeArgs pointer
     * model (see _forge_dispatch_*_bf16 comments) so it falls through
     * to UNSUPPORTED for every family.                              */
    if (precision_policy == FORGE_PREC_PURE_BF16) {
        switch (kernel_family) {
            case FORGE_KERNEL_MATMUL:
                return _forge_dispatch_matmul_bf16(shape, in, out);
            case FORGE_KERNEL_FFN_FUSED:
                return _forge_dispatch_ffn_bf16(shape, in, out);
            case FORGE_KERNEL_FWD_BWD_LINEAR:
            case FORGE_KERNEL_ATTN_DT_FWD:
            case FORGE_KERNEL_ATTN_DT_BWD:
            case FORGE_KERNEL_RMSNORM_MH:
            case FORGE_KERNEL_SILU_GATE:
            case FORGE_KERNEL_ROPE_MH:
                /* BF16 substrate for these families not landed. */
                return FORGE_KERNEL_UNSUPPORTED;
            default:
                return FORGE_INVALID_ARGS;
        }
    }
    if (precision_policy == FORGE_PREC_LAYERCAST_BF16_FP32) {
        /* LayerCast linear's X/Y are host float* arrays — they do not
         * fit the ForgeArgs farr-handle model. Honest UNSUPPORTED;
         * callers use hexa_farr_layercast_linear_bf16_gpu directly. */
        if (kernel_family < FORGE_KERNEL_MATMUL ||
            kernel_family > FORGE_KERNEL_ROPE_MH) {
            return FORGE_INVALID_ARGS;
        }
        return FORGE_KERNEL_UNSUPPORTED;
    }

    /* ─── FP64 routing (RFC 040 baseline) ──────────────────────────── */
    switch (kernel_family) {
        case FORGE_KERNEL_MATMUL:
            return _forge_dispatch_matmul_fp64(shape, in, out);

        case FORGE_KERNEL_FFN_FUSED:
        case FORGE_KERNEL_FWD_BWD_LINEAR:
        case FORGE_KERNEL_ATTN_DT_FWD:
        case FORGE_KERNEL_ATTN_DT_BWD:
        case FORGE_KERNEL_RMSNORM_MH:
        case FORGE_KERNEL_SILU_GATE:
        case FORGE_KERNEL_ROPE_MH:
            /* Stage 2 wiring lands kernel-by-kernel; until then the
             * caller (flame) keeps using the direct *_gpu builtins
             * (e.g. farr_rmsnorm_mh_gpu) instead of routing through
             * the dispatcher.                                       */
            return FORGE_KERNEL_UNSUPPORTED;

        default:
            return FORGE_INVALID_ARGS;
    }
}
