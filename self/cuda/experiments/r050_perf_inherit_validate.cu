/* r050_perf_inherit_validate.cu — RFC 050 PERF-INHERITANCE validation.
 *
 * L1 routed flame's FP64 matmul through forge_tier_dispatch_v1
 * (commits deaf8bd5 + 5a38712f), but the FP64 dispatcher path bottoms
 * out at the same hexa_farr_matmul baseline — perf inheritance NOT
 * achieved. RFC 050 Stage 2 (commit 351cd87d) opened the dispatcher's
 * BF16 path, routing PURE_BF16 MATMUL/FFN through the RFC 049 measured
 * substrate (hexa_farr_ffn_bf16_gpu, 11.66x FP64 cuBLAS Dgemm @ A100
 * d768·12L). This cycle adds the flame-side wrapper
 * `forge_dispatch_ffn_fp64_via_bf16` (self/runtime.c) that takes FP64
 * farr inputs, internally allocates BF16 staging, routes through the
 * dispatcher, casts back to FP64.
 *
 * This harness fires the WRAPPER (same code path runtime.c hosts) and
 * measures wall (BF16 dispatch) vs wall (FP64 cuBLAS Dgemm reference)
 * at the d768·12L FFN shapes RFC 049 Stage 2 measured. The wrapper
 * includes FP64↔BF16 cast overhead the bare substrate kernel does not;
 * the falsifier gate is intentionally ≥5x (vs Stage 2's measured 11.66x)
 * to absorb that overhead honestly.
 *
 * Pre-registered falsifiers:
 *   F-RFC050-PERF-INHERIT-FFN-D768-64   — wall_bf16_wrap <= wall_fp64/5
 *     at 64·768·3072 FFN.
 *   F-RFC050-PERF-INHERIT-FFN-D768-128  — wall_bf16_wrap <= wall_fp64/5
 *     at 128·768·3072 FFN (RFC 049 Stage 2 anchor shape).
 *   F-RFC050-PERF-INHERIT-CORRECT       — max|Δ|/max|Y| <= 5e-2 vs FP64
 *     cuBLAS reference (each shape).
 *   F-RFC050-PERF-INHERIT-DISPATCH-OK   — wrapper returns 0 (every fire).
 *
 * Honest scope (g3):
 *  - Inheritance gate ≥5x is a RELAXED bound vs Stage 2's 11.66x. If
 *    the actual measurement falls between 5x and 11.66x, the gate PASSes
 *    and the host↔device + FP64↔BF16 conversion overhead is the
 *    explanation (NOT a substrate regression). If <5x, the wrapper's
 *    conversion overhead is dominating — that is itself a useful
 *    signal documented in result.json.
 *  - Speedup is vs FP64 cuBLAS Dgemm (the only RFC 049 / RFC 050
 *    baseline). NEVER claim a PyTorch speedup — gpu/HANDOFF.md
 *    retracted that comparison.
 *  - One trial per shape, with 1 warmup + 3 measured iters; perf
 *    variance handled by reporting min wall across iters. Multi-trial
 *    statistical sweep is out of scope for this validation.
 *
 * Build pattern: mirrors r050_dispatch_validate.cu. Includes
 * runtime_bf16.c (BF16 substrate), then defines FORGE_TIER_V1_BF16
 * before including forge_tier_v1.c so the BF16 dispatcher path is wired
 * in this TU exactly as production runtime.c does it on -DHEXA_CUDA.
 *
 * Reference: state/forge_rfc050_perf_inherit_2026_05_19/design.md;
 *   RFC 049 Stage 2 measured anchors (commit c8fdc3bd);
 *   runtime.c hexa_forge_dispatch_ffn_fp64_via_bf16 wrapper (this cycle).
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cuda_bf16.h>

/* ── shim runtime_cuda.c's dependency surface (g_cublas + _ensure_cublas)
 * exactly as runtime_cuda.c declares them before its #include. ── */
static cublasHandle_t g_cublas = NULL;
static int _ensure_cublas(void) {
    if (g_cublas) return 0;
    return (cublasCreate(&g_cublas) == CUBLAS_STATUS_SUCCESS) ? 0 : -1;
}

#define HEXA_CUDA 1
#include "../runtime_bf16.c"

/* Open the dispatcher's BF16 path. FORGE_TIER_V1_LIVE deliberately
 * NOT defined — the FP64 hexa_farr_matmul is a runtime.c symbol not
 * present standalone; this harness only fires the BF16 path. */
#define FORGE_TIER_V1_BF16 1
#include "../../forge/forge_tier_v1.c"

#define CK(call) do { cudaError_t _e=(call); if(_e!=cudaSuccess){ fprintf(stderr,"[R050p] CUDA %s:%d %s\n",__FILE__,__LINE__,cudaGetErrorString(_e)); exit(1);} } while(0)
#define CB(call) do { cublasStatus_t _s=(call); if(_s!=CUBLAS_STATUS_SUCCESS){ fprintf(stderr,"[R050p] cuBLAS %s:%d %d\n",__FILE__,__LINE__,(int)_s); exit(1);} } while(0)

static double lcg_next(uint64_t* st) {
    *st = (*st) * 6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(((*st) >> 11) & 0x1FFFFFFFFFFFFFULL) / (double)(1ULL << 53);
}

/* monotonic wall — same metric the flame Phase 4-D campaign uses. */
static double mono_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + 1e-9 * (double)ts.tv_nsec;
}

/* ── FP64 cuBLAS Dgemm FFN reference (baseline for perf comparison) ──── */
__global__ void silu_f64_k(double* y, const double* x, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) { double v = x[i]; y[i] = v / (1.0 + exp(-v)); }
}

static void cublas_ffn_f64(cublasHandle_t h, int M, int D, int FD,
                           const double* dX, const double* dW1,
                           double* dH, double* dH_act,
                           const double* dW2, double* dY) {
    const double alpha = 1.0, beta = 0.0;
    /* row-major mapping via col-major swap (see r049_stage2_validate.cu). */
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, FD, M, D,
                &alpha, dW1, FD, dX, D, &beta, dH, FD);
    int n_act = M * FD, t = 256, b = (n_act + t - 1) / t; if (b > 65535) b = 65535;
    silu_f64_k<<<b, t>>>(dH_act, dH, n_act);
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, D, M, FD,
                &alpha, dW2, D, dH_act, FD, &beta, dY, D);
}

/* max|Δ|/max|Y| scale-relative metric (matches r050_dispatch_validate.cu). */
static double scale_rel_delta(const double* a, const double* b, size_t n) {
    double max_abs = 0, max_y = 0;
    for (size_t i = 0; i < n; i++) {
        double d = fabs(a[i] - b[i]);
        if (d > max_abs) max_abs = d;
        double ay = fabs(b[i]);
        if (ay > max_y) max_y = ay;
    }
    return (max_y > 0.0) ? (max_abs / max_y) : 0.0;
}

/* ── per-shape FFN perf measurement ──────────────────────────────────── */
struct perf_result {
    int M, D, FD;
    double wall_fp64_min;
    double wall_bf16_min;
    double speedup;        /* wall_fp64 / wall_bf16 */
    double rel_delta;
    int    dispatch_rc;    /* wrapper's dispatcher rc (0 == FORGE_OK path) */
    int    perf_ok;        /* speedup >= 5.0 */
    int    correct_ok;     /* rel_delta <= 5e-2 */
    int    dispatch_ok;    /* dispatch_rc == FORGE_OK */
};

#define N_ITER_WARMUP 1
#define N_ITER_MEAS   3

static perf_result run_perf_shape(cublasHandle_t hf64, int M, int D, int FD) {
    perf_result r; memset(&r, 0, sizeof(r));
    r.M = M; r.D = D; r.FD = FD;
    size_t nX = (size_t)M*D, nW1 = (size_t)D*FD, nW2 = (size_t)FD*D,
           nY = (size_t)M*D, nH = (size_t)M*FD;

    /* host master data */
    double* hX  = (double*)malloc(nX*sizeof(double));
    double* hW1 = (double*)malloc(nW1*sizeof(double));
    double* hW2 = (double*)malloc(nW2*sizeof(double));
    double* hY_f64   = (double*)malloc(nY*sizeof(double));
    double* hY_bf16  = (double*)malloc(nY*sizeof(double));

    uint64_t st = 0x050e2feaULL ^ (uint64_t)(M*1000003 + D*1009 + FD*31);
    for (size_t i = 0; i < nX;  i++) hX[i]  = (lcg_next(&st) - 0.5) * 0.1;
    for (size_t i = 0; i < nW1; i++) hW1[i] = (lcg_next(&st) - 0.5) * 0.05;
    for (size_t i = 0; i < nW2; i++) hW2[i] = (lcg_next(&st) - 0.5) * 0.05;

    /* ── FP64 cuBLAS Dgemm reference + wall ── */
    double *dX, *dW1, *dW2, *dH, *dH_act, *dY;
    CK(cudaMalloc(&dX, nX*sizeof(double)));   CK(cudaMalloc(&dW1, nW1*sizeof(double)));
    CK(cudaMalloc(&dW2, nW2*sizeof(double))); CK(cudaMalloc(&dH, nH*sizeof(double)));
    CK(cudaMalloc(&dH_act, nH*sizeof(double))); CK(cudaMalloc(&dY, nY*sizeof(double)));
    CK(cudaMemcpy(dX, hX, nX*sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW1, hW1, nW1*sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW2, hW2, nW2*sizeof(double), cudaMemcpyHostToDevice));

    /* warmup */
    for (int w = 0; w < N_ITER_WARMUP; w++) {
        cublas_ffn_f64(hf64, M, D, FD, dX, dW1, dH, dH_act, dW2, dY);
    }
    CK(cudaDeviceSynchronize());

    /* measured iters — record min wall (best-of-3) */
    r.wall_fp64_min = 1e30;
    for (int w = 0; w < N_ITER_MEAS; w++) {
        double t0 = mono_sec();
        cublas_ffn_f64(hf64, M, D, FD, dX, dW1, dH, dH_act, dW2, dY);
        CK(cudaDeviceSynchronize());
        double t1 = mono_sec();
        double wall = t1 - t0;
        if (wall < r.wall_fp64_min) r.wall_fp64_min = wall;
    }
    /* keep the last fp64 result for the correctness oracle */
    CK(cudaMemcpy(hY_f64, dY, nY*sizeof(double), cudaMemcpyDeviceToHost));
    cudaFree(dX); cudaFree(dW1); cudaFree(dW2);
    cudaFree(dH); cudaFree(dH_act); cudaFree(dY);

    /* ── BF16-dispatch-wrapper path ──
     * This mirrors what hexa_forge_dispatch_ffn_fp64_via_bf16 (the
     * runtime.c wrapper) does step-by-step — we cannot call the runtime.c
     * symbol directly because this TU is standalone (no _hx_farr_table).
     * We exercise the SAME wire: HexaFarrBf16 alloc, RNE cast from FP64
     * host master, ForgeArgs pointer-cast pack, forge_tier_dispatch_v1
     * (FFN_FUSED, PURE_BF16), BF16 → FP64 back to a host FP64 buffer.
     * The wall captured includes the WHOLE wrapper cost (alloc + cast +
     * dispatch + cast back + free) so the speedup gate is meaningful. */
    HexaFarrBf16 *fX  = hexa_farr_bf16_alloc((int64_t)nX);
    HexaFarrBf16 *fW1 = hexa_farr_bf16_alloc((int64_t)nW1);
    HexaFarrBf16 *fW2 = hexa_farr_bf16_alloc((int64_t)nW2);
    HexaFarrBf16 *fY  = hexa_farr_bf16_alloc((int64_t)nY);

    /* warmup */
    for (int w = 0; w < N_ITER_WARMUP; w++) {
        hexa_farr_bf16_from_f64(hX,  fX,  (int64_t)nX);
        hexa_farr_bf16_from_f64(hW1, fW1, (int64_t)nW1);
        hexa_farr_bf16_from_f64(hW2, fW2, (int64_t)nW2);
        ForgeShapeInfo shape; memset(&shape, 0, sizeof(shape));
        shape.M = M; shape.K = D; shape.N = FD;
        ForgeArgs in;  memset(&in, 0, sizeof(in));
        ForgeArgs out; memset(&out, 0, sizeof(out));
        in.farr_ids[0]  = (int64_t)(intptr_t)fX;
        in.farr_ids[1]  = (int64_t)(intptr_t)fW1;
        in.farr_ids[2]  = (int64_t)(intptr_t)fW2;
        in.count        = 3;
        out.farr_ids[0] = (int64_t)(intptr_t)fY;
        out.count       = 1;
        (void)forge_tier_dispatch_v1(FORGE_KERNEL_FFN_FUSED, &shape,
                                     FORGE_REGIME_AUTO, FORGE_PREC_PURE_BF16,
                                     FORGE_DET_DEFAULT, &in, &out);
        hexa_farr_bf16_to_host(fY);
        hexa_farr_bf16_to_f64(fY, hY_bf16, (int64_t)nY);
    }
    CK(cudaDeviceSynchronize());

    /* measured iters */
    r.wall_bf16_min = 1e30;
    int last_rc = -1;
    for (int w = 0; w < N_ITER_MEAS; w++) {
        double t0 = mono_sec();
        /* full wrapper wire — every step of hexa_forge_dispatch_ffn_fp64_via_bf16. */
        hexa_farr_bf16_from_f64(hX,  fX,  (int64_t)nX);
        hexa_farr_bf16_from_f64(hW1, fW1, (int64_t)nW1);
        hexa_farr_bf16_from_f64(hW2, fW2, (int64_t)nW2);
        ForgeShapeInfo shape; memset(&shape, 0, sizeof(shape));
        shape.M = M; shape.K = D; shape.N = FD;
        ForgeArgs in;  memset(&in, 0, sizeof(in));
        ForgeArgs out; memset(&out, 0, sizeof(out));
        in.farr_ids[0]  = (int64_t)(intptr_t)fX;
        in.farr_ids[1]  = (int64_t)(intptr_t)fW1;
        in.farr_ids[2]  = (int64_t)(intptr_t)fW2;
        in.count        = 3;
        out.farr_ids[0] = (int64_t)(intptr_t)fY;
        out.count       = 1;
        last_rc = forge_tier_dispatch_v1(FORGE_KERNEL_FFN_FUSED, &shape,
                                         FORGE_REGIME_AUTO, FORGE_PREC_PURE_BF16,
                                         FORGE_DET_DEFAULT, &in, &out);
        hexa_farr_bf16_to_host(fY);
        hexa_farr_bf16_to_f64(fY, hY_bf16, (int64_t)nY);
        CK(cudaDeviceSynchronize());
        double t1 = mono_sec();
        double wall = t1 - t0;
        if (wall < r.wall_bf16_min) r.wall_bf16_min = wall;
    }
    r.dispatch_rc = last_rc;
    r.dispatch_ok = (last_rc == FORGE_OK) ? 1 : 0;

    hexa_farr_bf16_free(fX); hexa_farr_bf16_free(fW1);
    hexa_farr_bf16_free(fW2); hexa_farr_bf16_free(fY);

    r.rel_delta = scale_rel_delta(hY_bf16, hY_f64, nY);
    r.correct_ok = (r.rel_delta <= 5e-2) ? 1 : 0;
    r.speedup    = r.wall_fp64_min / r.wall_bf16_min;
    r.perf_ok    = (r.speedup >= 5.0) ? 1 : 0;

    fprintf(stderr, "[R050p] FFN M=%d D=%d FD=%d  "
            "fp64=%.4fs  bf16=%.4fs  speedup=%.2fx  rel|Δ|=%.3e  "
            "rc=%d  dispatch=%s  perf=%s  correct=%s\n",
            M, D, FD, r.wall_fp64_min, r.wall_bf16_min, r.speedup,
            r.rel_delta, r.dispatch_rc,
            r.dispatch_ok ? "PASS" : "FAIL",
            r.perf_ok     ? "PASS" : "FAIL",
            r.correct_ok  ? "PASS" : "FAIL");

    free(hX); free(hW1); free(hW2); free(hY_f64); free(hY_bf16);
    return r;
}

int main(void) {
    int n_dev = 0; cudaGetDeviceCount(&n_dev);
    if (n_dev <= 0) { fprintf(stderr, "[R050p] FATAL: no CUDA device\n"); return 1; }
    int ccM = 0, ccm = 0;
    cudaDeviceGetAttribute(&ccM, cudaDevAttrComputeCapabilityMajor, 0);
    cudaDeviceGetAttribute(&ccm, cudaDevAttrComputeCapabilityMinor, 0);
    cudaDeviceProp prop; cudaGetDeviceProperties(&prop, 0);
    fprintf(stderr, "[R050p] device 0: %s cc=%d.%d\n", prop.name, ccM, ccm);
    if (ccM < 8) {
        FILE* jf = fopen("result.json", "w");
        fprintf(jf, "{\"error\":\"BF16 TC needs sm_80+, got cc=%d.%d\"}\n", ccM, ccm);
        fclose(jf); return 2;
    }
    cublasHandle_t hf64; CB(cublasCreate(&hf64));

    /* ── F-RFC050-PERF-INHERIT-FFN-D768-{64,128} ── */
    int fM[]  = {  64, 128 }, fD[] = { 768, 768 }, fFD[] = { 3072, 3072 };
    perf_result pr[2];
    for (int i = 0; i < 2; i++) pr[i] = run_perf_shape(hf64, fM[i], fD[i], fFD[i]);

    int perf_all = 1, correct_all = 1, dispatch_all = 1;
    for (int i = 0; i < 2; i++) {
        if (!pr[i].perf_ok)     perf_all     = 0;
        if (!pr[i].correct_ok)  correct_all  = 0;
        if (!pr[i].dispatch_ok) dispatch_all = 0;
    }

    /* ── emit result.json ── */
    FILE* jf = fopen("result.json", "w");
    fprintf(jf, "{\n  \"experiment\": \"forge_rfc050_perf_inherit\",\n");
    fprintf(jf, "  \"date\": \"2026-05-19\",\n");
    fprintf(jf, "  \"device_name\": \"%s\",\n  \"device_cc\": \"%d.%d\",\n",
            prop.name, ccM, ccm);
    fprintf(jf, "  \"path\": \"forge_tier_dispatch_v1(FFN_FUSED, PURE_BF16) -> hexa_farr_ffn_bf16_gpu (RFC 049 substrate); harness mirrors hexa_forge_dispatch_ffn_fp64_via_bf16 wrapper\",\n");
    fprintf(jf, "  \"baseline\": \"FP64 cuBLAS Dgemm (NEVER claim PyTorch speedup; gpu/HANDOFF.md retracted)\",\n");
    fprintf(jf, "  \"forge_api_version\": \"0x%08x\",\n", (unsigned)forge_api_version_v1());
    fprintf(jf, "  \"iters_per_shape\": { \"warmup\":%d, \"measured\":%d, \"reporter\":\"min wall\" },\n",
            N_ITER_WARMUP, N_ITER_MEAS);

    fprintf(jf, "  \"shapes\": [\n");
    for (int i = 0; i < 2; i++) {
        if (i > 0) fprintf(jf, ",\n");
        fprintf(jf, "    { \"M\":%d, \"D\":%d, \"FD\":%d, "
                "\"wall_fp64_s\":%.6f, \"wall_bf16_s\":%.6f, \"speedup\":%.4f, "
                "\"rel_delta\":%.3e, \"dispatch_rc\":%d, "
                "\"perf_ok\":%d, \"correct_ok\":%d, \"dispatch_ok\":%d }",
                pr[i].M, pr[i].D, pr[i].FD,
                pr[i].wall_fp64_min, pr[i].wall_bf16_min, pr[i].speedup,
                pr[i].rel_delta, pr[i].dispatch_rc,
                pr[i].perf_ok, pr[i].correct_ok, pr[i].dispatch_ok);
    }
    fprintf(jf, "\n  ],\n");

    fprintf(jf, "  \"falsifier_verdicts\": {\n");
    fprintf(jf, "    \"F-RFC050-PERF-INHERIT-FFN-D768-64\": { \"threshold\":\"speedup_64x768x3072 >= 5x FP64 cuBLAS Dgemm\", \"speedup\":%.4f, \"verdict\":\"%s\" },\n",
            pr[0].speedup, pr[0].perf_ok ? "PASS" : "FAIL");
    fprintf(jf, "    \"F-RFC050-PERF-INHERIT-FFN-D768-128\": { \"threshold\":\"speedup_128x768x3072 >= 5x FP64 cuBLAS Dgemm (RFC 049 Stage 2 anchor; measured 11.66x bare-substrate)\", \"speedup\":%.4f, \"verdict\":\"%s\" },\n",
            pr[1].speedup, pr[1].perf_ok ? "PASS" : "FAIL");
    fprintf(jf, "    \"F-RFC050-PERF-INHERIT-CORRECT\": { \"threshold\":\"max|Δ|/max|Y| <= 5e-2 vs FP64 cuBLAS Dgemm (all shapes)\", \"verdict\":\"%s\" },\n",
            correct_all ? "PASS" : "FAIL");
    fprintf(jf, "    \"F-RFC050-PERF-INHERIT-DISPATCH-OK\": { \"threshold\":\"forge_tier_dispatch_v1 returns FORGE_OK (all shapes)\", \"verdict\":\"%s\" }\n",
            dispatch_all ? "PASS" : "FAIL");
    fprintf(jf, "  },\n");

    fprintf(jf, "  \"notes\": [\n");
    fprintf(jf, "    \"This harness validates the runtime.c wrapper's wire (HexaFarrBf16 alloc + FP64->BF16 RNE cast + forge_tier_dispatch_v1 + BF16->FP64 cast) end-to-end. The harness mirrors hexa_forge_dispatch_ffn_fp64_via_bf16 step-by-step in a standalone TU because the wrapper symbol is in runtime.c which depends on _hx_farr_table (not present standalone).\",\n");
    fprintf(jf, "    \"5x gate is RELAXED vs RFC 049 Stage 2 measured 11.66x (bare hexa_farr_ffn_bf16_gpu, no wrapper) — relaxation absorbs the wrapper's host alloc + FP64<->BF16 cast overhead. A measurement between 5x and 11.66x is honest-PASS and documents the wrapper overhead.\",\n");
    fprintf(jf, "    \"Baseline is FP64 cuBLAS Dgemm. NEVER claim a PyTorch speedup — gpu/HANDOFF.md retracted that comparison (unit-mismatch).\",\n");
    fprintf(jf, "    \"flame call-site rewiring (which model code adopts nn_ffn_bf16_fwd) is a SEPARATE decision — this cycle delivers the routing + measurement capability only.\"\n");
    fprintf(jf, "  ]\n}\n");
    fclose(jf);

    fprintf(stderr, "\n[R050p] === SUMMARY ===\n");
    fprintf(stderr, "  PERF-INHERIT-FFN-D768-64   : %s (speedup=%.2fx, gate>=5x)\n",
            pr[0].perf_ok ? "PASS" : "FAIL", pr[0].speedup);
    fprintf(stderr, "  PERF-INHERIT-FFN-D768-128  : %s (speedup=%.2fx, gate>=5x)\n",
            pr[1].perf_ok ? "PASS" : "FAIL", pr[1].speedup);
    fprintf(stderr, "  PERF-INHERIT-CORRECT       : %s (rel|Δ| max %.3e)\n",
            correct_all ? "PASS" : "FAIL",
            (pr[0].rel_delta > pr[1].rel_delta ? pr[0].rel_delta : pr[1].rel_delta));
    fprintf(stderr, "  PERF-INHERIT-DISPATCH-OK   : %s\n",
            dispatch_all ? "PASS" : "FAIL");

    cublasDestroy(hf64);
    return 0;
}
