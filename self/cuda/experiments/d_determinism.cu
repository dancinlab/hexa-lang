/* d_determinism.cu — forge Phase R / D paradigm falsifier
 *
 * Hypothesis: deterministic-default substrate cost ≤ 15% vs cuBLAS heuristic.
 * Measurement:
 *   - cuBLAS Dgemm (FP64), default math mode (CUBLAS_DEFAULT_MATH)
 *   - cuBLAS Dgemm (FP64), CUBLAS_PEDANTIC_MATH
 *   - Per mode: 2 runs same input → bit-equal (memcmp)?
 *   - Cross-mode: bit-equal?
 *   - Per mode: median timing over N_ITER runs (after N_WARM warmup)
 *
 * Reference: anima/state/hexad_gpu_fire_2026_05_16/gpu_matmul_bench.c
 * (anima 잔류, 복제 X — 패턴만 차용. forge 의 D paradigm 검증 산출은
 * hexa-lang state/forge_phaseR_d_2026_05_17/ 에 저장).
 *
 * SSOT references:
 *   - self/forge/PLAN.md §Phase R
 *   - self/forge/PARADIGM_RESEARCH.md §3 (LayerCast/nondeterminism arxiv)
 *   - self/forge/FORGE.tape 2026-05-17 Log entry
 *
 * Falsifier: cost > 15% → D paradigm default-on 기각 (opt-in 강등).
 * Honest framing: FP64 cuBLAS is typically deterministic per (shape, hw,
 * lib-version). PEDANTIC mostly affects FP16/BF16 Tensor Core paths. So
 * the D measurement may surface "near-zero cost" — that is itself useful
 * data (D would be FREE for the FP64 farr path).
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(call) do { \
    cudaError_t _e = (call); \
    if (_e != cudaSuccess) { fprintf(stderr, "[D] CUDA %s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(_e)); exit(1); } \
} while (0)

#define CB(call) do { \
    cublasStatus_t _s = (call); \
    if (_s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "[D] cuBLAS %s:%d status=%d\n", __FILE__, __LINE__, (int)_s); exit(1); } \
} while (0)

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static double lcg_next(uint64_t* st) {
    *st = (*st) * 6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(((*st) >> 11) & 0x1FFFFFFFFFFFFFULL) / (double)(1ULL << 53);
}

static int dcmp(int a, int b) { return (a > b) - (a < b); }
static int dbl_cmp(const void* a, const void* b) { return dcmp(*(double*)a > *(double*)b, *(double*)b > *(double*)a); }

/* Run cublasDgemm n_iter times, return median wall-ms per call. */
static double run_timed(cublasHandle_t h, int M, int N, int K,
                        const double* dA, const double* dB, double* dC,
                        int n_warm, int n_iter) {
    const double alpha = 1.0, beta = 0.0;
    for (int w = 0; w < n_warm; w++) {
        cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                    N, M, K, &alpha, dB, N, dA, K, &beta, dC, N);
    }
    CK(cudaDeviceSynchronize());
    double* samples = (double*)malloc((size_t)n_iter * sizeof(double));
    for (int it = 0; it < n_iter; it++) {
        double t0 = now_sec();
        cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                    N, M, K, &alpha, dB, N, dA, K, &beta, dC, N);
        CK(cudaDeviceSynchronize());
        samples[it] = (now_sec() - t0) * 1000.0;
    }
    qsort(samples, n_iter, sizeof(double), dbl_cmp);
    double median = samples[n_iter / 2];
    free(samples);
    return median;
}

/* Single cublasDgemm run, copy result to host. */
static void run_once(cublasHandle_t h, int M, int N, int K,
                     const double* dA, const double* dB, double* dC,
                     double* hC_out, size_t szC) {
    const double alpha = 1.0, beta = 0.0;
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                N, M, K, &alpha, dB, N, dA, K, &beta, dC, N);
    CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(hC_out, dC, szC, cudaMemcpyDeviceToHost));
}

struct shape_result {
    int M, K, N;
    double t_default_ms, t_pedantic_ms;
    double ratio_pedantic_over_default;
    double cost_pct;
    int default_bit_equal_within;
    int pedantic_bit_equal_within;
    int cross_mode_bit_equal;
    double max_abs_cross, max_rel_cross;
};

static struct shape_result run_shape(cublasHandle_t h, int M, int K, int N,
                                     int n_warm, int n_iter) {
    fprintf(stderr, "[D] === shape M=%d K=%d N=%d (warm=%d iter=%d) ===\n",
            M, K, N, n_warm, n_iter);
    size_t szA = (size_t)M*K*sizeof(double);
    size_t szB = (size_t)K*N*sizeof(double);
    size_t szC = (size_t)M*N*sizeof(double);
    double *hA = (double*)malloc(szA);
    double *hB = (double*)malloc(szB);
    double *hC_def_a = (double*)malloc(szC);
    double *hC_def_b = (double*)malloc(szC);
    double *hC_ped_a = (double*)malloc(szC);
    double *hC_ped_b = (double*)malloc(szC);

    /* Deterministic LCG inputs — same seed every run. */
    uint64_t st = 0xdeadbeefcafeULL ^ (uint64_t)(M*1000003 + K*1009 + N*31);
    for (size_t i = 0; i < (size_t)M*K; i++) hA[i] = (lcg_next(&st) - 0.5) * 2.0;
    for (size_t i = 0; i < (size_t)K*N; i++) hB[i] = (lcg_next(&st) - 0.5) * 2.0;

    double *dA, *dB, *dC;
    CK(cudaMalloc((void**)&dA, szA));
    CK(cudaMalloc((void**)&dB, szB));
    CK(cudaMalloc((void**)&dC, szC));
    CK(cudaMemcpy(dA, hA, szA, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB, hB, szB, cudaMemcpyHostToDevice));

    struct shape_result r;
    r.M = M; r.K = K; r.N = N;

    /* === MODE: DEFAULT === */
    CB(cublasSetMathMode(h, CUBLAS_DEFAULT_MATH));
    r.t_default_ms = run_timed(h, M, N, K, dA, dB, dC, n_warm, n_iter);
    run_once(h, M, N, K, dA, dB, dC, hC_def_a, szC);
    run_once(h, M, N, K, dA, dB, dC, hC_def_b, szC);
    r.default_bit_equal_within = (memcmp(hC_def_a, hC_def_b, szC) == 0) ? 1 : 0;

    /* === MODE: PEDANTIC === */
    CB(cublasSetMathMode(h, CUBLAS_PEDANTIC_MATH));
    r.t_pedantic_ms = run_timed(h, M, N, K, dA, dB, dC, n_warm, n_iter);
    run_once(h, M, N, K, dA, dB, dC, hC_ped_a, szC);
    run_once(h, M, N, K, dA, dB, dC, hC_ped_b, szC);
    r.pedantic_bit_equal_within = (memcmp(hC_ped_a, hC_ped_b, szC) == 0) ? 1 : 0;

    /* === CROSS-MODE === */
    r.cross_mode_bit_equal = (memcmp(hC_def_a, hC_ped_a, szC) == 0) ? 1 : 0;
    double max_abs = 0.0, max_rel = 0.0;
    for (size_t i = 0; i < (size_t)M*N; i++) {
        double d = fabs(hC_def_a[i] - hC_ped_a[i]);
        if (d > max_abs) max_abs = d;
        double denom = fabs(hC_def_a[i]);
        if (denom > 1e-12) {
            double rr = d / denom;
            if (rr > max_rel) max_rel = rr;
        }
    }
    r.max_abs_cross = max_abs;
    r.max_rel_cross = max_rel;

    r.ratio_pedantic_over_default = r.t_pedantic_ms / r.t_default_ms;
    r.cost_pct = (r.ratio_pedantic_over_default - 1.0) * 100.0;

    fprintf(stderr, "[D]   t_default=%.3f ms · t_pedantic=%.3f ms · cost=%+.2f%% · within_bit_eq=def:%d/ped:%d · cross_bit_eq=%d · max|Δ|=%.3e\n",
            r.t_default_ms, r.t_pedantic_ms, r.cost_pct,
            r.default_bit_equal_within, r.pedantic_bit_equal_within,
            r.cross_mode_bit_equal, r.max_abs_cross);

    cudaFree(dA); cudaFree(dB); cudaFree(dC);
    free(hA); free(hB); free(hC_def_a); free(hC_def_b); free(hC_ped_a); free(hC_ped_b);
    return r;
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;
    int n_dev = 0;
    cudaGetDeviceCount(&n_dev);
    if (n_dev <= 0) { fprintf(stderr, "[D] FATAL: no CUDA device\n"); return 1; }

    int cc_major = 0, cc_minor = 0;
    cudaDeviceGetAttribute(&cc_major, cudaDevAttrComputeCapabilityMajor, 0);
    cudaDeviceGetAttribute(&cc_minor, cudaDevAttrComputeCapabilityMinor, 0);
    char pci[256] = "unknown";
    cudaDeviceGetPCIBusId(pci, sizeof(pci), 0);
    size_t mem_free = 0, mem_total = 0;
    cudaMemGetInfo(&mem_free, &mem_total);
    fprintf(stderr, "[D] device 0: pci=%s cc=%d.%d mem_total=%ld MB\n",
            pci, cc_major, cc_minor, (long)(mem_total >> 20));

    cublasHandle_t h;
    CB(cublasCreate(&h));
    int cublas_major = 0, cublas_minor = 0, cublas_patch = 0;
    cublasGetProperty(MAJOR_VERSION, &cublas_major);
    cublasGetProperty(MINOR_VERSION, &cublas_minor);
    cublasGetProperty(PATCH_LEVEL, &cublas_patch);
    fprintf(stderr, "[D] cuBLAS %d.%d.%d\n", cublas_major, cublas_minor, cublas_patch);

    struct { int M, K, N; int warm, iter; } shapes[] = {
        { 768,  768,  768, 3, 21 },   /* d_train5 representative */
        { 768, 3072,  768, 3, 21 },   /* FFN-shaped */
        { 768,  768, 3072, 3, 21 },   /* FFN-shaped */
        {1024, 1024, 1024, 3, 21 },   /* power-of-two reference */
        {2048, 2048, 2048, 2, 11 },   /* medium */
        {4096, 4096, 4096, 2,  7 },   /* large, compute-bound */
    };
    int n_shapes = (int)(sizeof(shapes)/sizeof(shapes[0]));

    FILE* jf = fopen("/workspace/forge_phaseR_d/result.json", "w");
    if (!jf) { fprintf(stderr, "[D] cannot open result.json\n"); return 2; }
    fprintf(jf, "{\n");
    fprintf(jf, "  \"experiment\": \"forge_phaseR_d_determinism\",\n");
    fprintf(jf, "  \"date\": \"2026-05-17\",\n");
    fprintf(jf, "  \"device_pci\": \"%s\",\n", pci);
    fprintf(jf, "  \"device_cc\": \"%d.%d\",\n", cc_major, cc_minor);
    fprintf(jf, "  \"device_mem_mb\": %ld,\n", (long)(mem_total >> 20));
    fprintf(jf, "  \"cublas_version\": \"%d.%d.%d\",\n", cublas_major, cublas_minor, cublas_patch);
    fprintf(jf, "  \"hypothesis\": \"deterministic-default cost <= 15%% vs cuBLAS heuristic\",\n");
    fprintf(jf, "  \"falsifier_threshold_pct\": 15.0,\n");
    fprintf(jf, "  \"shapes\": [\n");

    int any_cost_over = 0;
    double max_cost_pct = -1e9;
    for (int i = 0; i < n_shapes; i++) {
        struct shape_result r = run_shape(h, shapes[i].M, shapes[i].K, shapes[i].N,
                                          shapes[i].warm, shapes[i].iter);
        if (r.cost_pct > max_cost_pct) max_cost_pct = r.cost_pct;
        if (r.cost_pct > 15.0) any_cost_over = 1;
        if (i > 0) fprintf(jf, ",\n");
        fprintf(jf,
            "    { \"M\":%d, \"K\":%d, \"N\":%d, "
            "\"t_default_ms\":%.4f, \"t_pedantic_ms\":%.4f, "
            "\"ratio\":%.6f, \"cost_pct\":%.4f, "
            "\"default_bit_equal_within\":%d, \"pedantic_bit_equal_within\":%d, "
            "\"cross_mode_bit_equal\":%d, "
            "\"cross_max_abs\":%.3e, \"cross_max_rel\":%.3e }",
            r.M, r.K, r.N,
            r.t_default_ms, r.t_pedantic_ms,
            r.ratio_pedantic_over_default, r.cost_pct,
            r.default_bit_equal_within, r.pedantic_bit_equal_within,
            r.cross_mode_bit_equal,
            r.max_abs_cross, r.max_rel_cross);
    }

    fprintf(jf, "\n  ],\n");
    fprintf(jf, "  \"summary\": {\n");
    fprintf(jf, "    \"max_cost_pct\": %.4f,\n", max_cost_pct);
    fprintf(jf, "    \"any_cost_over_15pct\": %d,\n", any_cost_over);
    fprintf(jf, "    \"falsifier_verdict\": \"%s\"\n",
            any_cost_over ? "FAIL — D default-on 기각 (opt-in 강등)" : "PASS — D default-on 허용");
    fprintf(jf, "  }\n");
    fprintf(jf, "}\n");
    fclose(jf);

    fprintf(stderr, "[D] DONE — n_shapes=%d max_cost_pct=%+.2f%% verdict=%s\n",
            n_shapes, max_cost_pct,
            any_cost_over ? "FAIL" : "PASS");

    cublasDestroy(h);
    return 0;
}
