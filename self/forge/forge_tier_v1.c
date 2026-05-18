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
    int64_t c_id = out->farr_ids[0];
    (void)c_id;  /* hexa_farr_matmul allocates its own output farr per RFC 032 */

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
    HexaVal r = hexa_farr_matmul(hexa_int(a_id),
                                 hexa_int(shape->M),
                                 hexa_int(shape->K),
                                 hexa_int(b_id),
                                 hexa_int(shape->N));
    (void)r;  /* Stage 2 will plumb r into c_id once _into variant lands */
#else
    (void)a_id; (void)b_id;  /* standalone smoke: ack args, skip live call */
#endif
    /* Stage A: even when MATMUL+FP64 runs the live RFC 040 baseline,
     * report FORGE_FALLBACK_USED — the registry-based specialized
     * path is empty until Stage 2. Caller (flame) can log + continue. */
    return FORGE_FALLBACK_USED;
}

int forge_tier_dispatch_v1(
    int                     kernel_family,
    const ForgeShapeInfo   *shape,
    int                     regime_hint,
    int                     precision_policy,
    int                     det_mode,
    const ForgeArgs        *in,
    const ForgeArgs        *out
) {
    /* PEDANTIC det mode is FP64-only per RFC 049 §3.3. */
    if (det_mode == FORGE_DET_PEDANTIC && precision_policy != FORGE_PREC_FP64) {
        return FORGE_PRECISION_UNSUPPORTED;
    }
    /* BF16 substrates not landed yet (gated on RFC 049 Stage 2). */
    if (precision_policy != FORGE_PREC_FP64) {
        return FORGE_PRECISION_UNSUPPORTED;
    }
    /* Regime is a hint, not a constraint; AUTO/SMALL/MEDIUM/LARGE all
     * accepted. Out-of-range values are still INVALID_ARGS.         */
    if (regime_hint < FORGE_REGIME_AUTO || regime_hint > FORGE_REGIME_LARGE) {
        return FORGE_INVALID_ARGS;
    }

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
