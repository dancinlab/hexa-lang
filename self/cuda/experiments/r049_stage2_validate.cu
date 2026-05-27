/* r049_stage2_validate.cu — RFC 049 Stage 2 fire-validation.
 *
 * Closes the open cycle: the Stage 2 PRODUCTION kernel bodies in
 * self/cuda/runtime_bf16.c (hexa_farr_{matmul,ffn}_bf16_gpu) are wired
 * to the measured Stage 1 cuBLAS GemmEx BF16 path — this harness fires
 * the WIRED forge entry points on a GPU and confirms they reproduce the
 * Stage 1 result through the farr_bf16 storage class.
 *
 * Pre-registered falsifiers (RFC 049 Stage 2 wiring):
 *   F-FORGE-RFC049-STAGE2-WIRED-CORRECT — forge ffn output matches the FP64
 *     cuBLAS reference within BF16 tolerance (rel|Δ| ≤ 5e-2; Stage 1
 *     measured 1.2-1.5% LayerCast divergence — margin for the fused chain).
 *   F-FORGE-RFC049-STAGE2-WIRED-PERF — forge ffn ≥ 5× faster than the FP64
 *     cuBLAS Dgemm chain (re-confirms the Stage 1 9.67× anchor THROUGH the
 *     wired farr_bf16 entry point, not the bare kernel).
 *   F-FORGE-RFC049-STAGE2-WIRED-DET — within-run bit-equal (contract C1):
 *     two runs of the wired entry point, byte-equal BF16 output.
 *
 * runtime_bf16.c is designed to be #included into runtime_cuda.c, which
 * defines `g_cublas` + `_ensure_cublas()` above the include. This harness
 * shims exactly that 2-symbol surface, then #includes runtime_bf16.c — the
 * SAME code path forge uses in production, no fork.
 *
 * Reference: RFC 049 §"Components" item 2, runtime_bf16.c Stage 2 bodies,
 *   r049_bf16_fused_ffn.cu (Stage 1 measured anchor).
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

/* ── shim the runtime_cuda.c dependency surface (g_cublas + _ensure_cublas)
 * exactly as runtime_cuda.c declares them before its #include. ── */
static cublasHandle_t g_cublas = NULL;
static int _ensure_cublas(void) {
    if (g_cublas) return 0;
    return (cublasCreate(&g_cublas) == CUBLAS_STATUS_SUCCESS) ? 0 : -1;
}

#define HEXA_CUDA 1
#include "../runtime_bf16.c"

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { fprintf(stderr, "[R049v] CUDA %s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(_e)); exit(1); } } while (0)
#define CB(call) do { cublasStatus_t _s = (call); if (_s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "[R049v] cuBLAS %s:%d %d\n", __FILE__, __LINE__, (int)_s); exit(1); } } while (0)

static double now_sec(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}
static double lcg_next(uint64_t* st) {
    *st = (*st) * 6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(((*st) >> 11) & 0x1FFFFFFFFFFFFFULL) / (double)(1ULL << 53);
}
static int dbl_cmp(const void* a, const void* b) {
    double aa = *(const double*)a, bb = *(const double*)b;
    return (aa > bb) - (aa < bb);
}
static double median(double* a, int n) {
    qsort(a, n, sizeof(double), dbl_cmp);
    return a[n / 2];
}

__global__ void silu_f64_k(double* y, const double* x, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) { double v = x[i]; y[i] = v / (1.0 + exp(-v)); }
}

/* FP64 cuBLAS Dgemm reference FFN chain (ground truth) */
static void cublas_ffn_f64(cublasHandle_t h, int M, int D, int FD,
                           const double* dX, const double* dW1,
                           double* dH, double* dH_act,
                           const double* dW2, double* dY) {
    const double alpha = 1.0, beta = 0.0;
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, FD, M, D, &alpha, dW1, FD, dX, D, &beta, dH, FD);
    int n_act = M * FD, t = 256, b = (n_act + t - 1) / t; if (b > 65535) b = 65535;
    silu_f64_k<<<b, t>>>(dH_act, dH, n_act);
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, D, M, FD, &alpha, dW2, D, dH_act, FD, &beta, dY, D);
}

struct shape_result {
    int M, D, FD;
    double t_f64_ms, t_forge_ms, speedup;
    double max_rel_delta, mean_abs_delta;
    int within_run_biteq;
    int wired_correct_pass, wired_perf_pass, wired_det_pass;
    char status[96];
};

static shape_result run_shape(cublasHandle_t hf64, int M, int D, int FD,
                              int n_warm, int n_iter) {
    shape_result r; memset(&r, 0, sizeof(r));
    r.M = M; r.D = D; r.FD = FD;
    fprintf(stderr, "[R049v] === M=%d D=%d FD=%d ===\n", M, D, FD);

    size_t nX = (size_t)M*D, nW1 = (size_t)D*FD, nW2 = (size_t)FD*D, nY = (size_t)M*D, nH = (size_t)M*FD;
    double* hX  = (double*)malloc(nX*sizeof(double));
    double* hW1 = (double*)malloc(nW1*sizeof(double));
    double* hW2 = (double*)malloc(nW2*sizeof(double));
    double* hY_f64   = (double*)malloc(nY*sizeof(double));
    double* hY_forge = (double*)malloc(nY*sizeof(double));
    double* hY_forge2 = (double*)malloc(nY*sizeof(double));

    uint64_t st = 0x049f2a1eULL ^ (uint64_t)(M*1000003 + D*1009 + FD*31);
    for (size_t i = 0; i < nX;  i++) hX[i]  = (lcg_next(&st) - 0.5) * 0.1;
    for (size_t i = 0; i < nW1; i++) hW1[i] = (lcg_next(&st) - 0.5) * 0.05;
    for (size_t i = 0; i < nW2; i++) hW2[i] = (lcg_next(&st) - 0.5) * 0.05;

    /* ── FP64 cuBLAS reference ── */
    double *dX, *dW1, *dW2, *dH, *dH_act, *dY;
    CK(cudaMalloc(&dX, nX*sizeof(double)));   CK(cudaMalloc(&dW1, nW1*sizeof(double)));
    CK(cudaMalloc(&dW2, nW2*sizeof(double))); CK(cudaMalloc(&dH, nH*sizeof(double)));
    CK(cudaMalloc(&dH_act, nH*sizeof(double))); CK(cudaMalloc(&dY, nY*sizeof(double)));
    CK(cudaMemcpy(dX, hX, nX*sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW1, hW1, nW1*sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW2, hW2, nW2*sizeof(double), cudaMemcpyHostToDevice));
    for (int w = 0; w < n_warm; w++) cublas_ffn_f64(hf64, M, D, FD, dX, dW1, dH, dH_act, dW2, dY);
    CK(cudaDeviceSynchronize());
    double* sf = (double*)malloc(n_iter*sizeof(double));
    for (int it = 0; it < n_iter; it++) {
        double t0 = now_sec();
        cublas_ffn_f64(hf64, M, D, FD, dX, dW1, dH, dH_act, dW2, dY);
        CK(cudaDeviceSynchronize());
        sf[it] = (now_sec() - t0) * 1000.0;
    }
    r.t_f64_ms = median(sf, n_iter); free(sf);
    CK(cudaMemcpy(hY_f64, dY, nY*sizeof(double), cudaMemcpyDeviceToHost));
    cudaFree(dX); cudaFree(dW1); cudaFree(dW2); cudaFree(dH); cudaFree(dH_act); cudaFree(dY);

    /* ── forge wired path: hexa_farr_ffn_bf16_gpu through farr_bf16 ── */
    HexaFarrBf16 *fX = hexa_farr_bf16_alloc((int64_t)nX);
    HexaFarrBf16 *fW1 = hexa_farr_bf16_alloc((int64_t)nW1);
    HexaFarrBf16 *fW2 = hexa_farr_bf16_alloc((int64_t)nW2);
    HexaFarrBf16 *fY = hexa_farr_bf16_alloc((int64_t)nY);
    if (!fX || !fW1 || !fW2 || !fY) { snprintf(r.status, sizeof(r.status), "FARR_ALLOC_FAIL"); return r; }
    hexa_farr_bf16_from_f64(hX, fX, (int64_t)nX);
    hexa_farr_bf16_from_f64(hW1, fW1, (int64_t)nW1);
    hexa_farr_bf16_from_f64(hW2, fW2, (int64_t)nW2);

    int rc = hexa_farr_ffn_bf16_gpu(fX, M, D, FD, fW1, fW2, fY);
    if (rc != 0) { snprintf(r.status, sizeof(r.status), "FFN_ENTRY_RC=%d", rc); return r; }
    hexa_farr_bf16_to_host(fY);
    hexa_farr_bf16_to_f64(fY, hY_forge, (int64_t)nY);

    /* within-run determinism: re-run, re-read, byte-compare BF16 host buf */
    size_t szY_bf16 = nY * 2;
    unsigned char* y_run1 = (unsigned char*)malloc(szY_bf16);
    memcpy(y_run1, fY->h_buf, szY_bf16);
    rc = hexa_farr_ffn_bf16_gpu(fX, M, D, FD, fW1, fW2, fY);
    hexa_farr_bf16_to_host(fY);
    r.within_run_biteq = (rc == 0 && memcmp(y_run1, fY->h_buf, szY_bf16) == 0) ? 1 : 0;
    free(y_run1);
    hexa_farr_bf16_to_f64(fY, hY_forge2, (int64_t)nY);

    /* timing — entry point self-syncs (cudaDeviceSynchronize inside) */
    for (int w = 0; w < n_warm; w++) hexa_farr_ffn_bf16_gpu(fX, M, D, FD, fW1, fW2, fY);
    double* sg = (double*)malloc(n_iter*sizeof(double));
    for (int it = 0; it < n_iter; it++) {
        double t0 = now_sec();
        hexa_farr_ffn_bf16_gpu(fX, M, D, FD, fW1, fW2, fY);
        sg[it] = (now_sec() - t0) * 1000.0;
    }
    r.t_forge_ms = median(sg, n_iter); free(sg);

    /* numerics — forge BF16 path vs FP64 reference.
     * Correctness metric = max|Δ| relative to max|Y| (a stable denominator).
     * Per-element rel|Δ| is rejected here: random FFN outputs contain
     * near-zero elements where d/|y| explodes even though the absolute
     * error is BF16-precision-tiny — that inflates the metric without
     * reflecting a real error. Scale-relative (max|Δ|/max|Y|) is honest. */
    double max_abs = 0, sum_abs = 0, max_y = 0;
    for (size_t i = 0; i < nY; i++) {
        double d = fabs(hY_forge[i] - hY_f64[i]);
        sum_abs += d;
        if (d > max_abs) max_abs = d;
        double ay = fabs(hY_f64[i]);
        if (ay > max_y) max_y = ay;
    }
    r.max_rel_delta = (max_y > 0.0) ? (max_abs / max_y) : 0.0;
    r.mean_abs_delta = sum_abs / (double)nY;
    r.speedup = r.t_f64_ms / r.t_forge_ms;
    r.wired_correct_pass = (r.max_rel_delta <= 5e-2) ? 1 : 0;
    r.wired_perf_pass    = (r.speedup >= 5.0) ? 1 : 0;
    r.wired_det_pass     = r.within_run_biteq;
    snprintf(r.status, sizeof(r.status), "ok");

    fprintf(stderr, "[R049v]   f64=%.4f ms · forge_bf16=%.4f ms · speedup=%.3f×\n",
            r.t_f64_ms, r.t_forge_ms, r.speedup);
    fprintf(stderr, "[R049v]   max_rel|Δ|=%.3e · mean|Δ|=%.3e · within_biteq=%d\n",
            r.max_rel_delta, r.mean_abs_delta, r.within_run_biteq);
    fprintf(stderr, "[R049v]   WIRED-CORRECT=%s · WIRED-PERF≥5×=%s · WIRED-DET=%s\n",
            r.wired_correct_pass?"PASS":"FAIL", r.wired_perf_pass?"PASS":"FAIL",
            r.wired_det_pass?"PASS":"FAIL");

    hexa_farr_bf16_free(fX); hexa_farr_bf16_free(fW1);
    hexa_farr_bf16_free(fW2); hexa_farr_bf16_free(fY);
    free(hX); free(hW1); free(hW2); free(hY_f64); free(hY_forge); free(hY_forge2);
    return r;
}

int main(void) {
    int n_dev = 0; cudaGetDeviceCount(&n_dev);
    if (n_dev <= 0) { fprintf(stderr, "[R049v] FATAL: no CUDA device\n"); return 1; }
    int ccM = 0, ccm = 0;
    cudaDeviceGetAttribute(&ccM, cudaDevAttrComputeCapabilityMajor, 0);
    cudaDeviceGetAttribute(&ccm, cudaDevAttrComputeCapabilityMinor, 0);
    cudaDeviceProp prop; cudaGetDeviceProperties(&prop, 0);
    fprintf(stderr, "[R049v] device 0: %s cc=%d.%d\n", prop.name, ccM, ccm);
    if (ccM < 8) {
        FILE* jf = fopen("result.json", "w");
        fprintf(jf, "{\"error\":\"BF16 TC needs sm_80+, got cc=%d.%d\"}\n", ccM, ccm);
        fclose(jf); return 2;
    }
    cublasHandle_t hf64; CB(cublasCreate(&hf64));

    struct { int M, D, FD, warm, iter; const char* tier; } shapes[] = {
        {  64,  768,  3072, 5, 31, "SMALL"  },
        { 128,  768,  3072, 5, 31, "MEDIUM" },
        { 128, 4096, 11008, 3, 21, "LARGE"  },   /* Llama-7B FFN */
    };
    int ns = (int)(sizeof(shapes)/sizeof(shapes[0]));
    shape_result res[8];
    for (int i = 0; i < ns; i++)
        res[i] = run_shape(hf64, shapes[i].M, shapes[i].D, shapes[i].FD, shapes[i].warm, shapes[i].iter);

    FILE* jf = fopen("result.json", "w");
    fprintf(jf, "{\n  \"experiment\": \"forge_rfc049_stage2_wired_validate\",\n");
    fprintf(jf, "  \"date\": \"2026-05-19\",\n");
    fprintf(jf, "  \"device_name\": \"%s\",\n  \"device_cc\": \"%d.%d\",\n", prop.name, ccM, ccm);
    fprintf(jf, "  \"path\": \"hexa_farr_ffn_bf16_gpu via farr_bf16 storage class (runtime_bf16.c production body)\",\n");
    fprintf(jf, "  \"shapes\": [\n");
    for (int i = 0; i < ns; i++) {
        shape_result* r = &res[i];
        if (i > 0) fprintf(jf, ",\n");
        fprintf(jf, "    { \"tier\":\"%s\", \"M\":%d, \"D\":%d, \"FD\":%d, \"status\":\"%s\", "
                "\"t_f64_ms\":%.5f, \"t_forge_ms\":%.5f, \"speedup\":%.4f, "
                "\"max_rel_delta\":%.3e, \"mean_abs_delta\":%.3e, \"within_run_biteq\":%d, "
                "\"wired_correct_pass\":%d, \"wired_perf_pass\":%d, \"wired_det_pass\":%d }",
                shapes[i].tier, r->M, r->D, r->FD, r->status,
                r->t_f64_ms, r->t_forge_ms, r->speedup,
                r->max_rel_delta, r->mean_abs_delta, r->within_run_biteq,
                r->wired_correct_pass, r->wired_perf_pass, r->wired_det_pass);
    }
    fprintf(jf, "\n  ],\n");
    int li = -1; for (int i = 0; i < ns; i++) if (strcmp(shapes[i].tier, "LARGE") == 0) li = i;
    int all_c = 1, all_d = 1;
    for (int i = 0; i < ns; i++) { if (!res[i].wired_correct_pass) all_c = 0; if (!res[i].wired_det_pass) all_d = 0; }
    fprintf(jf, "  \"falsifier_verdicts\": {\n");
    if (li >= 0)
        fprintf(jf, "    \"F-FORGE-RFC049-STAGE2-WIRED-PERF\": { \"threshold\":\"≥5× FP64 cuBLAS\", \"speedup\":%.4f, \"shape\":\"LARGE\", \"verdict\":\"%s\" },\n",
                res[li].speedup, res[li].wired_perf_pass ? "PASS" : "FAIL");
    fprintf(jf, "    \"F-FORGE-RFC049-STAGE2-WIRED-CORRECT\": { \"threshold\":\"max|Δ|/max|Y| ≤5e-2 vs FP64 (all shapes)\", \"verdict\":\"%s\" },\n", all_c ? "PASS" : "FAIL");
    fprintf(jf, "    \"F-FORGE-RFC049-STAGE2-WIRED-DET\": { \"threshold\":\"within-run bit-equal (all shapes)\", \"verdict\":\"%s\" }\n", all_d ? "PASS" : "FAIL");
    fprintf(jf, "  },\n");
    fprintf(jf, "  \"notes\": [\n");
    fprintf(jf, "    \"Fires the WIRED forge entry point hexa_farr_ffn_bf16_gpu through the farr_bf16 storage class — the production code path, not the bare Stage 1 kernel.\",\n");
    fprintf(jf, "    \"Stage 1 anchor: r049_bf16_fused_ffn.cu measured 9.67x FP64 cuBLAS on A100.\"\n");
    fprintf(jf, "  ]\n}\n");
    fclose(jf);

    fprintf(stderr, "\n[R049v] === SUMMARY ===\n");
    for (int i = 0; i < ns; i++) {
        shape_result* r = &res[i];
        fprintf(stderr, "  %-7s f64=%.4f forge=%.4f speedup=%.3f× rel|Δ|=%.2e biteq=%d %s\n",
                shapes[i].tier, r->t_f64_ms, r->t_forge_ms, r->speedup,
                r->max_rel_delta, r->within_run_biteq, r->status);
    }
    cublasDestroy(hf64);
    return 0;
}
