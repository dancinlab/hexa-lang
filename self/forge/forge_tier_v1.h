/* ═══════════════════════════════════════════════════════════════════
 * forge_tier_v1.h — flame ↔ forge integration ABI (RFC 050).
 *
 * Public surface of forge_tier_v1: the dispatch contract flame's
 * compiled stdlib calls into. Stable per the _v1 suffix — any ABI
 * change requires a _v2 bump (see RFC 050 §6.7). Until that bump,
 * flame source compiled against forge >= 1.0 keeps working.
 *
 * Header-only — no HexaVal / runtime.h dependency so this can be
 * included by smoke tests, future codegen targets, and downstream
 * consumers without dragging the whole runtime in.
 *
 * SSOT: inbox/rfc_drafts_2026_05_12/rfc_050_flame_forge_integration.md
 * ═══════════════════════════════════════════════════════════════════ */
#ifndef FORGE_TIER_V1_H
#define FORGE_TIER_V1_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ─── version ──────────────────────────────────────────────────────── */
/* Encoded (major << 16) | minor — 1.0 = 0x00010000.                  */
#define FORGE_API_VERSION_V1_MAJOR  1
#define FORGE_API_VERSION_V1_MINOR  0
#define FORGE_API_VERSION_V1_ENCODED \
    ((uint32_t)((FORGE_API_VERSION_V1_MAJOR << 16) | FORGE_API_VERSION_V1_MINOR))

/* ─── kernel families ──────────────────────────────────────────────── */
/* Stage-2 substrates land kernel-by-kernel. MATMUL is always available
 * (RFC 040 cuBLAS Dgemm fallback). Other families return
 * FORGE_KERNEL_UNSUPPORTED until their Stage 2 lands.            */
#define FORGE_KERNEL_MATMUL            1
#define FORGE_KERNEL_FFN_FUSED         2   /* RFC 044 B tier (Stage 2) */
#define FORGE_KERNEL_FWD_BWD_LINEAR    3   /* RFC 048 Phase 4-C        */
#define FORGE_KERNEL_ATTN_DT_FWD       4   /* mk2-C4 (forge-routed)    */
#define FORGE_KERNEL_ATTN_DT_BWD       5   /* mk2-C4 (forge-routed)    */
#define FORGE_KERNEL_RMSNORM_MH        6   /* mk2-C2 (forge-routed)    */
#define FORGE_KERNEL_SILU_GATE         7   /* RFC 041 .cu kernel       */
#define FORGE_KERNEL_ROPE_MH           8

/* ─── regime hints (shape × batch × compute) ──────────────────────── */
/* Compile-time when shapes are static, AUTO otherwise.            */
#define FORGE_REGIME_AUTO              0
#define FORGE_REGIME_SMALL             1   /* compute < 100us, B <= 128 */
#define FORGE_REGIME_MEDIUM            2   /* compute ~1-10ms, B 128-512 */
#define FORGE_REGIME_LARGE             3   /* compute > 10ms, B >= 512   */

/* ─── precision policy (RFC 049) ──────────────────────────────────── */
/* FP64 always available; BF16 paths gated on RFC 049 Stage 2 land.  */
#define FORGE_PREC_FP64                  0
#define FORGE_PREC_LAYERCAST_BF16_FP32   1
#define FORGE_PREC_PURE_BF16             2

/* ─── determinism mode (orthogonal to precision) ──────────────────── */
#define FORGE_DET_DEFAULT              0   /* within-run bit-eq FREE on FP64 */
#define FORGE_DET_PEDANTIC             1   /* cross-mode bit-eq, +15-33% cost */

/* ─── return codes ────────────────────────────────────────────────── */
#define FORGE_OK                       0
#define FORGE_FALLBACK_USED            1   /* dispatched, not via primary tier */
#define FORGE_KERNEL_UNSUPPORTED      (-1) /* Stage 2 kernel not landed yet     */
#define FORGE_REGIME_UNSUPPORTED      (-2) /* regime tier not registered        */
#define FORGE_PRECISION_UNSUPPORTED   (-3) /* RFC 049 substrate not landed yet  */
#define FORGE_INVALID_ARGS            (-4) /* bad shape / farr id / null ptr    */
#define FORGE_ABI_MISMATCH            (-5) /* caller compiled against different version */

/* ─── shape descriptor ────────────────────────────────────────────── */
/* Family-specific interpretation. MATMUL: M rows of A, K shared, N cols
 * of B. Other families use the same struct (batch axis, future).   */
typedef struct ForgeShapeInfo {
    int64_t M;
    int64_t N;
    int64_t K;
    int64_t batch;          /* 0 if no batch axis */
} ForgeShapeInfo;

/* ─── farr id bundle (caller-managed lifetime) ───────────────────── */
/* Caller (flame) allocates input/output farrs; forge dispatcher only
 * reads/writes them. No hidden alloc / no hidden release. Preserves
 * RFC 035/040 packed-double arena ownership.                       */
typedef struct ForgeArgs {
    int64_t farr_ids[8];    /* family-specific; MATMUL: in=[A,B], out=[C] */
    int     count;
} ForgeArgs;

/* ─── public API ──────────────────────────────────────────────────── */

/* Returns FORGE_API_VERSION_V1_ENCODED. Callers compare against the
 * value they were compiled with; mismatch -> emit build error / abort. */
uint32_t forge_api_version_v1(void);

/* Single dispatch entry point per RFC 050 §6.1. Routes (kernel_family,
 * regime_hint, precision_policy, det_mode) to the registered Stage 2
 * tier or falls back through the chain in RFC 050 §6.6.            */
int forge_tier_dispatch_v1(
    int                     kernel_family,
    const ForgeShapeInfo   *shape,
    int                     regime_hint,
    int                     precision_policy,
    int                     det_mode,
    const ForgeArgs        *in,
    const ForgeArgs        *out
);

/* flame Phase 4-C / RFC 048 calls this at module-init to register
 * specialized fused kernels. v1 stub returns FORGE_OK and remembers
 * the registration (in-memory only, no persistence). Stage 2 will
 * exercise the registry via dispatch lookup. fn_ptr is opaque -
 * dispatcher recasts to the family-specific call signature.        */
int forge_register_specialized_v1(
    int                     kernel_family,
    const ForgeShapeInfo   *shape,
    int                     precision_policy,
    int                     regime_hint,
    void                   *fn_ptr
);

#ifdef __cplusplus
}
#endif

#endif /* FORGE_TIER_V1_H */
