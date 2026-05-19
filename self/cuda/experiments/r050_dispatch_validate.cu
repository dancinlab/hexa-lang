/* r050_dispatch_validate.cu — RFC 050 Stage 2 (forge-side) dispatch
 * routing validation.
 *
 * RFC 050 Stage A landed forge_tier_v1.{h,c} — a stub dispatcher that
 * rejected every non-FP64 precision. RFC 049 Stage 2 then measured-PASS
 * the BF16 substrate (runtime_bf16.c: hexa_farr_{matmul,ffn}_bf16_gpu).
 * RFC 050 Stage 2 opens the dispatcher's BF16 precision path. This
 * harness fires the WIRED dispatcher — forge_tier_dispatch_v1 routed to
 * the BF16 substrate through the ForgeArgs pointer-cast ABI — and
 * confirms it returns FORGE_OK + numerically-correct output, and that
 * unsupported combinations fall back with a code (never crash).
 *
 * Pre-registered falsifiers exercised here (forge-only scope):
 *   F-FORGE-RFC050-VERSION-API        — forge_api_version_v1() pin.
 *   F-FORGE-RFC050-DISPATCH-ROUTES-BF16 — MATMUL/FFN + PURE_BF16 route
 *     through the dispatcher to the RFC 049 substrate, return FORGE_OK,
 *     output matches an FP64 cuBLAS reference within BF16 tolerance
 *     (max|Δ|/max|Y| ≤ 5e-2).
 *   F-FORGE-RFC050-FALLBACK-CHAIN     — unsupported (family, precision,
 *     regime, det) combos return a negative code, never crash (§6.6).
 *
 * OUT OF SCOPE (honest — needs flame, a parallel session): the
 * flame-integration falsifiers F-FORGE-RFC050-REGIME-CORRECT,
 * -PERF-INHERITANCE, -FORGE-BACKWARD-FUSE, -DISPATCH-API-MATCH,
 * -PRECISION-D-PRESERVE. This harness only validates the forge-side
 * dispatcher routing — it does not measure flame end-to-end wins.
 *
 * Build pattern (mirrors r049_stage2_validate.cu): shim the
 * runtime_cuda.c dependency surface (g_cublas + _ensure_cublas),
 * #define HEXA_CUDA, #include runtime_bf16.c, then #define
 * FORGE_TIER_V1_BF16 and #include forge_tier_v1.c — the SAME code path
 * forge uses in production. FORGE_TIER_V1_LIVE is intentionally NOT
 * defined: the FP64 hexa_farr_matmul is a runtime.c symbol not present
 * standalone — this harness validates the BF16 path only.
 *
 * Reference: RFC 050 §6 (dispatch primitive / fallback chain §6.6) +
 *   §7 falsifiers; runtime_bf16.c RFC 049 Stage 2 measured anchors.
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
 * NOT defined — the FP64 hexa_farr_matmul is unavailable standalone. */
#define FORGE_TIER_V1_BF16 1
#include "../../forge/forge_tier_v1.c"

#define CK(call) do { cudaError_t _e=(call); if(_e!=cudaSuccess){ fprintf(stderr,"[R050v] CUDA %s:%d %s\n",__FILE__,__LINE__,cudaGetErrorString(_e)); exit(1);} } while(0)
#define CB(call) do { cublasStatus_t _s=(call); if(_s!=CUBLAS_STATUS_SUCCESS){ fprintf(stderr,"[R050v] cuBLAS %s:%d %d\n",__FILE__,__LINE__,(int)_s); exit(1);} } while(0)

static double lcg_next(uint64_t* st) {
    *st = (*st) * 6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(((*st) >> 11) & 0x1FFFFFFFFFFFFFULL) / (double)(1ULL << 53);
}

/* ── FP64 cuBLAS references (ground truth) ───────────────────────────── */
__global__ void silu_f64_k(double* y, const double* x, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) { double v = x[i]; y[i] = v / (1.0 + exp(-v)); }
}

static void cublas_matmul_f64(cublasHandle_t h, int M, int K, int N,
                              const double* dA, const double* dB, double* dC) {
    const double alpha = 1.0, beta = 0.0;
    /* row-major C[M,N]=A[M,K]@B[K,N] via column-major swap. */
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                &alpha, dB, N, dA, K, &beta, dC, N);
}

static void cublas_ffn_f64(cublasHandle_t h, int M, int D, int FD,
                           const double* dX, const double* dW1,
                           double* dH, double* dH_act,
                           const double* dW2, double* dY) {
    const double alpha = 1.0, beta = 0.0;
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, FD, M, D,
                &alpha, dW1, FD, dX, D, &beta, dH, FD);
    int n_act = M * FD, t = 256, b = (n_act + t - 1) / t; if (b > 65535) b = 65535;
    silu_f64_k<<<b, t>>>(dH_act, dH, n_act);
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, D, M, FD,
                &alpha, dW2, D, dH_act, FD, &beta, dY, D);
}

/* max|Δ|/max|Y| scale-relative metric — the honest correctness denom
 * (runtime_bf16.c / r049 harness rationale: per-element rel|Δ| explodes
 * near zero outputs). */
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

/* ── per-shape MATMUL routing check ──────────────────────────────────── */
struct mm_result {
    int M, K, N, rc;
    double rel_delta;
    int routes_ok;       /* rc == FORGE_OK */
    int correct_ok;      /* rel_delta <= 5e-2 */
    char status[64];
};

static mm_result run_matmul_shape(cublasHandle_t hf64, int M, int K, int N) {
    mm_result r; memset(&r, 0, sizeof(r));
    r.M = M; r.K = K; r.N = N;
    size_t nA = (size_t)M*K, nB = (size_t)K*N, nC = (size_t)M*N;

    double* hA = (double*)malloc(nA*sizeof(double));
    double* hB = (double*)malloc(nB*sizeof(double));
    double* hC_f64   = (double*)malloc(nC*sizeof(double));
    double* hC_forge = (double*)malloc(nC*sizeof(double));

    uint64_t st = 0x050a11ceULL ^ (uint64_t)(M*1000003 + K*1009 + N*31);
    for (size_t i = 0; i < nA; i++) hA[i] = (lcg_next(&st) - 0.5) * 0.1;
    for (size_t i = 0; i < nB; i++) hB[i] = (lcg_next(&st) - 0.5) * 0.1;

    /* FP64 cuBLAS reference */
    double *dA, *dB, *dC;
    CK(cudaMalloc(&dA, nA*sizeof(double)));
    CK(cudaMalloc(&dB, nB*sizeof(double)));
    CK(cudaMalloc(&dC, nC*sizeof(double)));
    CK(cudaMemcpy(dA, hA, nA*sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB, hB, nB*sizeof(double), cudaMemcpyHostToDevice));
    cublas_matmul_f64(hf64, M, K, N, dA, dB, dC);
    CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(hC_f64, dC, nC*sizeof(double), cudaMemcpyDeviceToHost));
    cudaFree(dA); cudaFree(dB); cudaFree(dC);

    /* forge dispatcher path: build BF16 farrs, pack pointers as int64
     * into ForgeArgs.farr_ids[] (RFC 050 ABI), dispatch MATMUL+PURE_BF16. */
    HexaFarrBf16 *fA = hexa_farr_bf16_alloc((int64_t)nA);
    HexaFarrBf16 *fB = hexa_farr_bf16_alloc((int64_t)nB);
    HexaFarrBf16 *fC = hexa_farr_bf16_alloc((int64_t)nC);
    if (!fA || !fB || !fC) { snprintf(r.status,sizeof(r.status),"FARR_ALLOC_FAIL"); return r; }
    hexa_farr_bf16_from_f64(hA, fA, (int64_t)nA);
    hexa_farr_bf16_from_f64(hB, fB, (int64_t)nB);

    ForgeShapeInfo shape; memset(&shape, 0, sizeof(shape));
    shape.M = M; shape.K = K; shape.N = N;
    ForgeArgs in;  memset(&in, 0, sizeof(in));
    ForgeArgs out; memset(&out, 0, sizeof(out));
    in.farr_ids[0]  = (int64_t)(intptr_t)fA;
    in.farr_ids[1]  = (int64_t)(intptr_t)fB;
    in.count        = 2;
    out.farr_ids[0] = (int64_t)(intptr_t)fC;
    out.count       = 1;

    r.rc = forge_tier_dispatch_v1(FORGE_KERNEL_MATMUL, &shape,
                                  FORGE_REGIME_AUTO, FORGE_PREC_PURE_BF16,
                                  FORGE_DET_DEFAULT, &in, &out);
    r.routes_ok = (r.rc == FORGE_OK) ? 1 : 0;
    if (r.routes_ok) {
        hexa_farr_bf16_to_host(fC);
        hexa_farr_bf16_to_f64(fC, hC_forge, (int64_t)nC);
        r.rel_delta = scale_rel_delta(hC_forge, hC_f64, nC);
        r.correct_ok = (r.rel_delta <= 5e-2) ? 1 : 0;
        snprintf(r.status, sizeof(r.status), "ok");
    } else {
        snprintf(r.status, sizeof(r.status), "DISPATCH_RC=%d", r.rc);
    }
    fprintf(stderr, "[R050v] MATMUL M=%d K=%d N=%d rc=%d rel|Δ|=%.3e routes=%s correct=%s\n",
            M, K, N, r.rc, r.rel_delta, r.routes_ok?"PASS":"FAIL",
            r.correct_ok?"PASS":"FAIL");

    hexa_farr_bf16_free(fA); hexa_farr_bf16_free(fB); hexa_farr_bf16_free(fC);
    free(hA); free(hB); free(hC_f64); free(hC_forge);
    return r;
}

/* ── per-shape FFN routing check ─────────────────────────────────────── */
struct ffn_result {
    int M, D, FD, rc;
    double rel_delta;
    int routes_ok, correct_ok;
    char status[64];
};

static ffn_result run_ffn_shape(cublasHandle_t hf64, int M, int D, int FD) {
    ffn_result r; memset(&r, 0, sizeof(r));
    r.M = M; r.D = D; r.FD = FD;
    size_t nX = (size_t)M*D, nW1 = (size_t)D*FD, nW2 = (size_t)FD*D,
           nY = (size_t)M*D, nH = (size_t)M*FD;

    double* hX  = (double*)malloc(nX*sizeof(double));
    double* hW1 = (double*)malloc(nW1*sizeof(double));
    double* hW2 = (double*)malloc(nW2*sizeof(double));
    double* hY_f64   = (double*)malloc(nY*sizeof(double));
    double* hY_forge = (double*)malloc(nY*sizeof(double));

    uint64_t st = 0x050ff2aeULL ^ (uint64_t)(M*1000003 + D*1009 + FD*31);
    for (size_t i = 0; i < nX;  i++) hX[i]  = (lcg_next(&st) - 0.5) * 0.1;
    for (size_t i = 0; i < nW1; i++) hW1[i] = (lcg_next(&st) - 0.5) * 0.05;
    for (size_t i = 0; i < nW2; i++) hW2[i] = (lcg_next(&st) - 0.5) * 0.05;

    /* FP64 cuBLAS reference */
    double *dX, *dW1, *dW2, *dH, *dH_act, *dY;
    CK(cudaMalloc(&dX, nX*sizeof(double)));   CK(cudaMalloc(&dW1, nW1*sizeof(double)));
    CK(cudaMalloc(&dW2, nW2*sizeof(double))); CK(cudaMalloc(&dH, nH*sizeof(double)));
    CK(cudaMalloc(&dH_act, nH*sizeof(double))); CK(cudaMalloc(&dY, nY*sizeof(double)));
    CK(cudaMemcpy(dX, hX, nX*sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW1, hW1, nW1*sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW2, hW2, nW2*sizeof(double), cudaMemcpyHostToDevice));
    cublas_ffn_f64(hf64, M, D, FD, dX, dW1, dH, dH_act, dW2, dY);
    CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(hY_f64, dY, nY*sizeof(double), cudaMemcpyDeviceToHost));
    cudaFree(dX); cudaFree(dW1); cudaFree(dW2);
    cudaFree(dH); cudaFree(dH_act); cudaFree(dY);

    /* forge dispatcher path: FFN_FUSED + PURE_BF16, ForgeArgs pointer ABI.
     * Shape mapping: M=shape.M, D=shape.K, FD=shape.N. */
    HexaFarrBf16 *fX  = hexa_farr_bf16_alloc((int64_t)nX);
    HexaFarrBf16 *fW1 = hexa_farr_bf16_alloc((int64_t)nW1);
    HexaFarrBf16 *fW2 = hexa_farr_bf16_alloc((int64_t)nW2);
    HexaFarrBf16 *fY  = hexa_farr_bf16_alloc((int64_t)nY);
    if (!fX || !fW1 || !fW2 || !fY) { snprintf(r.status,sizeof(r.status),"FARR_ALLOC_FAIL"); return r; }
    hexa_farr_bf16_from_f64(hX, fX, (int64_t)nX);
    hexa_farr_bf16_from_f64(hW1, fW1, (int64_t)nW1);
    hexa_farr_bf16_from_f64(hW2, fW2, (int64_t)nW2);

    ForgeShapeInfo shape; memset(&shape, 0, sizeof(shape));
    shape.M = M; shape.K = D; shape.N = FD;   /* D->K, FD->N */
    ForgeArgs in;  memset(&in, 0, sizeof(in));
    ForgeArgs out; memset(&out, 0, sizeof(out));
    in.farr_ids[0]  = (int64_t)(intptr_t)fX;
    in.farr_ids[1]  = (int64_t)(intptr_t)fW1;
    in.farr_ids[2]  = (int64_t)(intptr_t)fW2;
    in.count        = 3;
    out.farr_ids[0] = (int64_t)(intptr_t)fY;
    out.count       = 1;

    r.rc = forge_tier_dispatch_v1(FORGE_KERNEL_FFN_FUSED, &shape,
                                  FORGE_REGIME_AUTO, FORGE_PREC_PURE_BF16,
                                  FORGE_DET_DEFAULT, &in, &out);
    r.routes_ok = (r.rc == FORGE_OK) ? 1 : 0;
    if (r.routes_ok) {
        hexa_farr_bf16_to_host(fY);
        hexa_farr_bf16_to_f64(fY, hY_forge, (int64_t)nY);
        r.rel_delta = scale_rel_delta(hY_forge, hY_f64, nY);
        r.correct_ok = (r.rel_delta <= 5e-2) ? 1 : 0;
        snprintf(r.status, sizeof(r.status), "ok");
    } else {
        snprintf(r.status, sizeof(r.status), "DISPATCH_RC=%d", r.rc);
    }
    fprintf(stderr, "[R050v] FFN    M=%d D=%d FD=%d rc=%d rel|Δ|=%.3e routes=%s correct=%s\n",
            M, D, FD, r.rc, r.rel_delta, r.routes_ok?"PASS":"FAIL",
            r.correct_ok?"PASS":"FAIL");

    hexa_farr_bf16_free(fX); hexa_farr_bf16_free(fW1);
    hexa_farr_bf16_free(fW2); hexa_farr_bf16_free(fY);
    free(hX); free(hW1); free(hW2); free(hY_f64); free(hY_forge);
    return r;
}

/* ── fallback / no-crash mandate (§6.6, F-FORGE-RFC050-FALLBACK-CHAIN) ─
 * Each entry is a deliberately unsupported (family, precision, regime,
 * det) tuple — the dispatcher MUST return a negative code, never crash. */
struct fb_case {
    const char* name;
    int family, regime, precision, det;
    int rc;       /* filled in */
    int pass;     /* rc < 0 (a code, no crash) */
};

int main(void) {
    int n_dev = 0; cudaGetDeviceCount(&n_dev);
    if (n_dev <= 0) { fprintf(stderr, "[R050v] FATAL: no CUDA device\n"); return 1; }
    int ccM = 0, ccm = 0;
    cudaDeviceGetAttribute(&ccM, cudaDevAttrComputeCapabilityMajor, 0);
    cudaDeviceGetAttribute(&ccm, cudaDevAttrComputeCapabilityMinor, 0);
    cudaDeviceProp prop; cudaGetDeviceProperties(&prop, 0);
    fprintf(stderr, "[R050v] device 0: %s cc=%d.%d\n", prop.name, ccM, ccm);
    if (ccM < 8) {
        FILE* jf = fopen("result.json", "w");
        fprintf(jf, "{\"error\":\"BF16 TC needs sm_80+, got cc=%d.%d\"}\n", ccM, ccm);
        fclose(jf); return 2;
    }
    cublasHandle_t hf64; CB(cublasCreate(&hf64));

    /* ── F-FORGE-RFC050-VERSION-API ── */
    uint32_t api_v = forge_api_version_v1();
    int version_ok = (api_v == FORGE_API_VERSION_V1_ENCODED) ? 1 : 0;
    fprintf(stderr, "[R050v] forge_api_version_v1()=0x%08x expected=0x%08x %s\n",
            api_v, (unsigned)FORGE_API_VERSION_V1_ENCODED,
            version_ok ? "PASS" : "FAIL");

    /* ── F-FORGE-RFC050-DISPATCH-ROUTES-BF16 — MATMUL + FFN shapes ── */
    int mmM[] = { 256, 1024 }, mmK[] = { 256, 1024 }, mmN[] = { 256, 1024 };
    mm_result mm[2];
    for (int i = 0; i < 2; i++) mm[i] = run_matmul_shape(hf64, mmM[i], mmK[i], mmN[i]);

    int fM[]  = {  64, 128 }, fD[] = { 768, 768 }, fFD[] = { 3072, 3072 };
    ffn_result ffn[2];
    for (int i = 0; i < 2; i++) ffn[i] = run_ffn_shape(hf64, fM[i], fD[i], fFD[i]);

    int routes_all = 1, correct_all = 1;
    for (int i = 0; i < 2; i++) {
        if (!mm[i].routes_ok)  routes_all  = 0;
        if (!mm[i].correct_ok) correct_all = 0;
        if (!ffn[i].routes_ok)  routes_all  = 0;
        if (!ffn[i].correct_ok) correct_all = 0;
    }
    int dispatch_routes_ok = (routes_all && correct_all) ? 1 : 0;

    /* ── F-FORGE-RFC050-FALLBACK-CHAIN — unsupported combos, no crash ── */
    fb_case fb[] = {
        { "ROPE_MH+PURE_BF16 (BF16 substrate not landed)",
          FORGE_KERNEL_ROPE_MH, FORGE_REGIME_AUTO, FORGE_PREC_PURE_BF16,
          FORGE_DET_DEFAULT, 0, 0 },
        { "out-of-range regime (=99)",
          FORGE_KERNEL_MATMUL, 99, FORGE_PREC_PURE_BF16,
          FORGE_DET_DEFAULT, 0, 0 },
        { "PEDANTIC det + PURE_BF16 (FP64-only per RFC 049 §3.3)",
          FORGE_KERNEL_MATMUL, FORGE_REGIME_AUTO, FORGE_PREC_PURE_BF16,
          FORGE_DET_PEDANTIC, 0, 0 },
        { "MATMUL + LAYERCAST_BF16_FP32 (host float* X/Y, no ForgeArgs fit)",
          FORGE_KERNEL_MATMUL, FORGE_REGIME_AUTO,
          FORGE_PREC_LAYERCAST_BF16_FP32, FORGE_DET_DEFAULT, 0, 0 },
        { "unknown kernel family (=42) + PURE_BF16",
          42, FORGE_REGIME_AUTO, FORGE_PREC_PURE_BF16,
          FORGE_DET_DEFAULT, 0, 0 },
    };
    int n_fb = (int)(sizeof(fb)/sizeof(fb[0]));
    /* Minimal well-formed args so the only thing under test is the
     * (family, precision, regime, det) rejection logic, not arg checks. */
    HexaFarrBf16 *gA = hexa_farr_bf16_alloc(64);
    HexaFarrBf16 *gB = hexa_farr_bf16_alloc(64);
    HexaFarrBf16 *gC = hexa_farr_bf16_alloc(64);
    ForgeShapeInfo gshape; memset(&gshape, 0, sizeof(gshape));
    gshape.M = 8; gshape.K = 8; gshape.N = 8;
    ForgeArgs gin;  memset(&gin, 0, sizeof(gin));
    ForgeArgs gout; memset(&gout, 0, sizeof(gout));
    gin.farr_ids[0] = (int64_t)(intptr_t)gA;
    gin.farr_ids[1] = (int64_t)(intptr_t)gB;
    gin.farr_ids[2] = (int64_t)(intptr_t)gA;
    gin.count = 3;
    gout.farr_ids[0] = (int64_t)(intptr_t)gC;
    gout.count = 1;

    int fallback_all = 1;
    for (int i = 0; i < n_fb; i++) {
        fb[i].rc = forge_tier_dispatch_v1(fb[i].family, &gshape,
                                          fb[i].regime, fb[i].precision,
                                          fb[i].det, &gin, &gout);
        fb[i].pass = (fb[i].rc < 0) ? 1 : 0;   /* a code, no crash */
        if (!fb[i].pass) fallback_all = 0;
        fprintf(stderr, "[R050v] FALLBACK [%s] rc=%d %s\n",
                fb[i].name, fb[i].rc, fb[i].pass ? "PASS" : "FAIL");
    }
    hexa_farr_bf16_free(gA); hexa_farr_bf16_free(gB); hexa_farr_bf16_free(gC);

    /* ── emit result.json ── */
    FILE* jf = fopen("result.json", "w");
    fprintf(jf, "{\n  \"experiment\": \"forge_rfc050_stage2_dispatch_validate\",\n");
    fprintf(jf, "  \"date\": \"2026-05-19\",\n");
    fprintf(jf, "  \"device_name\": \"%s\",\n  \"device_cc\": \"%d.%d\",\n",
            prop.name, ccM, ccm);
    fprintf(jf, "  \"path\": \"forge_tier_dispatch_v1 -> runtime_bf16.c BF16 substrate (FORGE_TIER_V1_BF16 wired)\",\n");
    fprintf(jf, "  \"forge_api_version\": \"0x%08x\",\n", api_v);

    fprintf(jf, "  \"matmul_shapes\": [\n");
    for (int i = 0; i < 2; i++) {
        if (i > 0) fprintf(jf, ",\n");
        fprintf(jf, "    { \"M\":%d, \"K\":%d, \"N\":%d, \"rc\":%d, \"status\":\"%s\", "
                "\"rel_delta\":%.3e, \"routes_ok\":%d, \"correct_ok\":%d }",
                mm[i].M, mm[i].K, mm[i].N, mm[i].rc, mm[i].status,
                mm[i].rel_delta, mm[i].routes_ok, mm[i].correct_ok);
    }
    fprintf(jf, "\n  ],\n");

    fprintf(jf, "  \"ffn_shapes\": [\n");
    for (int i = 0; i < 2; i++) {
        if (i > 0) fprintf(jf, ",\n");
        fprintf(jf, "    { \"M\":%d, \"D\":%d, \"FD\":%d, \"rc\":%d, \"status\":\"%s\", "
                "\"rel_delta\":%.3e, \"routes_ok\":%d, \"correct_ok\":%d }",
                ffn[i].M, ffn[i].D, ffn[i].FD, ffn[i].rc, ffn[i].status,
                ffn[i].rel_delta, ffn[i].routes_ok, ffn[i].correct_ok);
    }
    fprintf(jf, "\n  ],\n");

    fprintf(jf, "  \"fallback_cases\": [\n");
    for (int i = 0; i < n_fb; i++) {
        if (i > 0) fprintf(jf, ",\n");
        fprintf(jf, "    { \"case\":\"%s\", \"rc\":%d, \"no_crash_code\":%d }",
                fb[i].name, fb[i].rc, fb[i].pass);
    }
    fprintf(jf, "\n  ],\n");

    fprintf(jf, "  \"falsifier_verdicts\": {\n");
    fprintf(jf, "    \"F-FORGE-RFC050-VERSION-API\": { \"threshold\":\"forge_api_version_v1() == FORGE_API_VERSION_V1_ENCODED\", \"verdict\":\"%s\" },\n",
            version_ok ? "PASS" : "FAIL");
    fprintf(jf, "    \"F-FORGE-RFC050-DISPATCH-ROUTES-BF16\": { \"threshold\":\"MATMUL+FFN PURE_BF16 route via dispatcher, rc==FORGE_OK, max|Δ|/max|Y| <=5e-2 vs FP64 (all shapes)\", \"verdict\":\"%s\" },\n",
            dispatch_routes_ok ? "PASS" : "FAIL");
    fprintf(jf, "    \"F-FORGE-RFC050-FALLBACK-CHAIN\": { \"threshold\":\"all unsupported (family,precision,regime,det) combos return a negative code, no crash\", \"verdict\":\"%s\" }\n",
            fallback_all ? "PASS" : "FAIL");
    fprintf(jf, "  },\n");

    fprintf(jf, "  \"notes\": [\n");
    fprintf(jf, "    \"Forge-side dispatch routing only. forge_tier_dispatch_v1 routed to the RFC 049 BF16 substrate (runtime_bf16.c) via the RFC 050 ForgeArgs pointer-cast ABI.\",\n");
    fprintf(jf, "    \"FORGE_TIER_V1_LIVE intentionally NOT defined — the FP64 hexa_farr_matmul is a runtime.c symbol not present standalone; this harness validates the BF16 path.\",\n");
    fprintf(jf, "    \"OUT OF SCOPE (need flame, a parallel session): F-FORGE-RFC050-REGIME-CORRECT, -PERF-INHERITANCE, -FORGE-BACKWARD-FUSE, -DISPATCH-API-MATCH, -PRECISION-D-PRESERVE — those are flame-integration falsifiers, not forge-side dispatch routing.\",\n");
    fprintf(jf, "    \"BF16 numerics inherit RFC 049 Stage 2 measured anchors (matmul 8.48x, ffn 11.66x FP64 cuBLAS); this harness checks dispatcher-routed correctness, not a re-measurement of the speedup.\"\n");
    fprintf(jf, "  ]\n}\n");
    fclose(jf);

    fprintf(stderr, "\n[R050v] === SUMMARY ===\n");
    fprintf(stderr, "  VERSION-API          : %s\n", version_ok ? "PASS" : "FAIL");
    fprintf(stderr, "  DISPATCH-ROUTES-BF16 : %s (routes=%d correct=%d)\n",
            dispatch_routes_ok ? "PASS" : "FAIL", routes_all, correct_all);
    fprintf(stderr, "  FALLBACK-CHAIN       : %s\n", fallback_all ? "PASS" : "FAIL");

    cublasDestroy(hf64);
    return 0;
}
