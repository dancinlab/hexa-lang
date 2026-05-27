/* b_ffn_baseline.cu — forge Phase R / B paradigm falsifier (Stage 1/diagnostic)
 *
 * Pre-registered B hypothesis (FORGE.tape 2026-05-17):
 *   H100 DSM-aware fused FFN (matmul→SwiGLU→matmul) latency ≤ 0.5×
 *   separate cuBLAS chain.
 *
 * This fire = Stage 1 DIAGNOSTIC, not the full DSM kernel.
 * Real DSM cluster-cooperative kernel is non-trivial (multi-day work);
 * this stage measures the PREREQUISITE: is FFN actually HBM-bound at
 * our target shapes, and does kernel-launch overhead matter?
 *
 * Three paths measured per FFN shape:
 *   1. separate     — 3 explicit launches: Dgemm + SiLU + Dgemm, HBM intermediate
 *   2. graph        — same 3 ops captured into CUDA Graph + replayed (kernel-launch fusion)
 *   3. (deferred)   — single DSM-cluster fused kernel (Stage 2, requires fast Stage 1 PASS)
 *
 * Decision matrix from Stage 1 data:
 *   - achieved HBM BW > 70% peak → FFN is compute-bound → B paradigm has limited
 *     headroom regardless of fusion approach (FAIL stage gate, do not pursue B).
 *   - graph speedup > 30% → kernel-launch overhead is the bottleneck → CUDA Graphs
 *     already captures most of the win, custom DSM kernel marginal value.
 *   - achieved HBM BW < 30% peak AND graph speedup < 10% → HBM intermediate
 *     roundtrip is the bottleneck → DSM fusion (Stage 2) has clear headroom.
 *
 * Activation note: SiLU not SwiGLU (single-half). SwiGLU adds a halving
 * step (two halves of 4D, elementwise mul); the HBM-traffic and kernel-launch
 * characteristics are essentially the same. SiLU is simpler to verify.
 *
 * Pattern reference: anima/state/hexad_gpu_fire_2026_05_16/gpu_matmul_bench.c
 * (anima 잔류, 복제 X — only the cuBLAS Dgemm timing pattern is borrowed).
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
    if (_e != cudaSuccess) { fprintf(stderr, "[B] CUDA %s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(_e)); exit(1); } \
} while (0)

#define CB(call) do { \
    cublasStatus_t _s = (call); \
    if (_s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "[B] cuBLAS %s:%d status=%d\n", __FILE__, __LINE__, (int)_s); exit(1); } \
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

static int dbl_cmp(const void* a, const void* b) {
    double aa = *(const double*)a, bb = *(const double*)b;
    return (aa > bb) - (aa < bb);
}

/* SiLU = x · sigmoid(x). Elementwise, FP64. */
__global__ void silu_kernel(double* y, const double* x, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) {
        double v = x[i];
        double sig = 1.0 / (1.0 + exp(-v));
        y[i] = v * sig;
    }
}

/* Run the 3-op FFN once via separate launches. cuBLAS Dgemm uses
 * row-major→column-major trick (matches anima gpu_matmul_bench.c §95).
 * Layout: X is M×D row-major (cublas treats as D×M col-major).
 *         W1 is D×FD row-major. H = X·W1 is M×FD row-major.
 *         W2 is FD×D row-major. Y = H'·W2 is M×D where H' = silu(H).
 */
static void run_ffn_separate(cublasHandle_t h, cudaStream_t st,
                              int M, int D, int FD,
                              const double* dX, const double* dW1,
                              double* dH, double* dH_act,
                              const double* dW2, double* dY) {
    const double alpha = 1.0, beta = 0.0;
    /* H = X · W1   (M×D · D×FD = M×FD) */
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                FD, M, D, &alpha, dW1, FD, dX, D, &beta, dH, FD);
    /* H_act = SiLU(H) */
    int n_act = M * FD;
    int threads = 256, blocks = (n_act + threads - 1) / threads;
    if (blocks > 65535) blocks = 65535;
    silu_kernel<<<blocks, threads, 0, st>>>(dH_act, dH, n_act);
    /* Y = H_act · W2  (M×FD · FD×D = M×D) */
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                D, M, FD, &alpha, dW2, D, dH_act, FD, &beta, dY, D);
}

struct ffn_result {
    int M, D, FD;
    double t_separate_ms, t_graph_ms;
    double t_dgemm1_ms, t_silu_ms, t_dgemm2_ms;
    double graph_speedup_pct;  /* (sep - graph) / sep * 100 */
    double bytes_read_write;
    double achieved_bw_separate_GBs;
    double achieved_bw_graph_GBs;
    double theoretical_hbm_peak_GBs;
    int bit_equal;
    double max_abs_delta, max_rel_delta;
};

static double median(double* a, int n) {
    qsort(a, n, sizeof(double), dbl_cmp);
    return a[n / 2];
}

static struct ffn_result run_shape(cublasHandle_t h, int M, int D, int FD,
                                   int n_warm, int n_iter) {
    fprintf(stderr, "[B] === FFN shape M=%d D=%d FD=%d (warm=%d iter=%d) ===\n",
            M, D, FD, n_warm, n_iter);
    size_t szX = (size_t)M*D*sizeof(double);
    size_t szW1 = (size_t)D*FD*sizeof(double);
    size_t szH = (size_t)M*FD*sizeof(double);
    size_t szW2 = (size_t)FD*D*sizeof(double);
    size_t szY = (size_t)M*D*sizeof(double);

    double *hX = (double*)malloc(szX);
    double *hW1 = (double*)malloc(szW1);
    double *hW2 = (double*)malloc(szW2);
    double *hY_sep = (double*)malloc(szY);
    double *hY_graph = (double*)malloc(szY);

    uint64_t st = 0xb0bafe77ULL ^ (uint64_t)(M*1000003 + D*1009 + FD*31);
    for (size_t i = 0; i < (size_t)M*D; i++) hX[i] = (lcg_next(&st) - 0.5) * 0.5;
    for (size_t i = 0; i < (size_t)D*FD; i++) hW1[i] = (lcg_next(&st) - 0.5) * 0.05;
    for (size_t i = 0; i < (size_t)FD*D; i++) hW2[i] = (lcg_next(&st) - 0.5) * 0.05;

    double *dX, *dW1, *dW2, *dH, *dH_act, *dY_sep, *dY_graph;
    CK(cudaMalloc((void**)&dX, szX));
    CK(cudaMalloc((void**)&dW1, szW1));
    CK(cudaMalloc((void**)&dW2, szW2));
    CK(cudaMalloc((void**)&dH, szH));
    CK(cudaMalloc((void**)&dH_act, szH));
    CK(cudaMalloc((void**)&dY_sep, szY));
    CK(cudaMalloc((void**)&dY_graph, szY));
    CK(cudaMemcpy(dX, hX, szX, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW1, hW1, szW1, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW2, hW2, szW2, cudaMemcpyHostToDevice));

    cudaStream_t stream;
    CK(cudaStreamCreate(&stream));
    CB(cublasSetStream(h, stream));

    struct ffn_result r;
    r.M = M; r.D = D; r.FD = FD;

    /* === PATH 1: separate launches === */
    for (int w = 0; w < n_warm; w++)
        run_ffn_separate(h, stream, M, D, FD, dX, dW1, dH, dH_act, dW2, dY_sep);
    CK(cudaStreamSynchronize(stream));

    double* samples_sep = (double*)malloc((size_t)n_iter * sizeof(double));
    for (int it = 0; it < n_iter; it++) {
        double t0 = now_sec();
        run_ffn_separate(h, stream, M, D, FD, dX, dW1, dH, dH_act, dW2, dY_sep);
        CK(cudaStreamSynchronize(stream));
        samples_sep[it] = (now_sec() - t0) * 1000.0;
    }
    r.t_separate_ms = median(samples_sep, n_iter);
    free(samples_sep);

    /* Capture Y_sep for bit-equality check */
    CK(cudaMemcpy(hY_sep, dY_sep, szY, cudaMemcpyDeviceToHost));

    /* === Individual kernel timings (via cudaEvents) === */
    cudaEvent_t ev_a, ev_b, ev_c, ev_d;
    cudaEventCreate(&ev_a); cudaEventCreate(&ev_b);
    cudaEventCreate(&ev_c); cudaEventCreate(&ev_d);

    const double alpha = 1.0, beta = 0.0;
    double sum_dgemm1 = 0, sum_silu = 0, sum_dgemm2 = 0;
    int n_ev = 5;
    for (int it = 0; it < n_ev; it++) {
        cudaEventRecord(ev_a, stream);
        cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                    FD, M, D, &alpha, dW1, FD, dX, D, &beta, dH, FD);
        cudaEventRecord(ev_b, stream);
        int n_act = M * FD;
        int threads = 256, blocks = (n_act + threads - 1) / threads;
        if (blocks > 65535) blocks = 65535;
        silu_kernel<<<blocks, threads, 0, stream>>>(dH_act, dH, n_act);
        cudaEventRecord(ev_c, stream);
        cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                    D, M, FD, &alpha, dW2, D, dH_act, FD, &beta, dY_sep, D);
        cudaEventRecord(ev_d, stream);
        CK(cudaStreamSynchronize(stream));
        float ms_ab = 0, ms_bc = 0, ms_cd = 0;
        cudaEventElapsedTime(&ms_ab, ev_a, ev_b);
        cudaEventElapsedTime(&ms_bc, ev_b, ev_c);
        cudaEventElapsedTime(&ms_cd, ev_c, ev_d);
        sum_dgemm1 += ms_ab; sum_silu += ms_bc; sum_dgemm2 += ms_cd;
    }
    r.t_dgemm1_ms = sum_dgemm1 / n_ev;
    r.t_silu_ms   = sum_silu / n_ev;
    r.t_dgemm2_ms = sum_dgemm2 / n_ev;
    cudaEventDestroy(ev_a); cudaEventDestroy(ev_b);
    cudaEventDestroy(ev_c); cudaEventDestroy(ev_d);

    /* === PATH 2: CUDA Graphs (kernel-launch fusion) === */
    cudaGraph_t graph;
    cudaGraphExec_t exec;
    CK(cudaStreamBeginCapture(stream, cudaStreamCaptureModeGlobal));
    run_ffn_separate(h, stream, M, D, FD, dX, dW1, dH, dH_act, dW2, dY_graph);
    CK(cudaStreamEndCapture(stream, &graph));
    CK(cudaGraphInstantiate(&exec, graph, NULL, NULL, 0));

    for (int w = 0; w < n_warm; w++) {
        CK(cudaGraphLaunch(exec, stream));
    }
    CK(cudaStreamSynchronize(stream));

    double* samples_graph = (double*)malloc((size_t)n_iter * sizeof(double));
    for (int it = 0; it < n_iter; it++) {
        double t0 = now_sec();
        CK(cudaGraphLaunch(exec, stream));
        CK(cudaStreamSynchronize(stream));
        samples_graph[it] = (now_sec() - t0) * 1000.0;
    }
    r.t_graph_ms = median(samples_graph, n_iter);
    free(samples_graph);
    CK(cudaMemcpy(hY_graph, dY_graph, szY, cudaMemcpyDeviceToHost));

    cudaGraphExecDestroy(exec);
    cudaGraphDestroy(graph);
    cudaStreamDestroy(stream);
    CB(cublasSetStream(h, 0));

    /* === bit-equality check (separate vs graph — should be bit-equal) === */
    r.bit_equal = (memcmp(hY_sep, hY_graph, szY) == 0) ? 1 : 0;
    double max_abs = 0, max_rel = 0;
    for (size_t i = 0; i < (size_t)M*D; i++) {
        double d = fabs(hY_sep[i] - hY_graph[i]);
        if (d > max_abs) max_abs = d;
        double denom = fabs(hY_sep[i]);
        if (denom > 1e-12) {
            double rr = d / denom;
            if (rr > max_rel) max_rel = rr;
        }
    }
    r.max_abs_delta = max_abs;
    r.max_rel_delta = max_rel;

    /* === bandwidth analysis ===
     * FFN HBM traffic per step (separate, intermediate in HBM):
     *   read X (M×D), read W1 (D×FD), write H (M×FD),
     *   read H (M×FD), write H_act (M×FD),
     *   read H_act (M×FD), read W2 (FD×D), write Y (M×D)
     * = sizeof(double) × (M·D + D·FD + 3·M·FD + FD·D + M·D)
     * Sub-optimal but realistic for the separate path.
     */
    double bytes = (double)sizeof(double) *
                   ((double)M*D + (double)D*FD + 3.0*(double)M*FD +
                    (double)FD*D + (double)M*D);
    r.bytes_read_write = bytes;
    r.achieved_bw_separate_GBs = (bytes / 1e9) / (r.t_separate_ms / 1000.0);
    r.achieved_bw_graph_GBs    = (bytes / 1e9) / (r.t_graph_ms / 1000.0);
    r.theoretical_hbm_peak_GBs = 3350.0;  /* H100 SXM5 = 3.35 TB/s HBM3 */

    r.graph_speedup_pct = (r.t_separate_ms - r.t_graph_ms) / r.t_separate_ms * 100.0;

    fprintf(stderr, "[B]   sep=%.3f ms graph=%.3f ms (speedup=%+.2f%%)\n"
                    "[B]   dgemm1=%.4f silu=%.4f dgemm2=%.4f (sum=%.4f)\n"
                    "[B]   BW sep=%.1f GB/s graph=%.1f GB/s peak=%.0f GB/s (util sep=%.1f%%)\n"
                    "[B]   bit_equal=%d max|Δ|=%.3e\n",
            r.t_separate_ms, r.t_graph_ms, r.graph_speedup_pct,
            r.t_dgemm1_ms, r.t_silu_ms, r.t_dgemm2_ms,
            r.t_dgemm1_ms + r.t_silu_ms + r.t_dgemm2_ms,
            r.achieved_bw_separate_GBs, r.achieved_bw_graph_GBs, r.theoretical_hbm_peak_GBs,
            r.achieved_bw_separate_GBs / r.theoretical_hbm_peak_GBs * 100.0,
            r.bit_equal, r.max_abs_delta);

    cudaFree(dX); cudaFree(dW1); cudaFree(dW2); cudaFree(dH); cudaFree(dH_act);
    cudaFree(dY_sep); cudaFree(dY_graph);
    free(hX); free(hW1); free(hW2); free(hY_sep); free(hY_graph);
    return r;
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;
    int n_dev = 0;
    cudaGetDeviceCount(&n_dev);
    if (n_dev <= 0) { fprintf(stderr, "[B] FATAL: no CUDA device\n"); return 1; }

    int cc_major = 0, cc_minor = 0;
    cudaDeviceGetAttribute(&cc_major, cudaDevAttrComputeCapabilityMajor, 0);
    cudaDeviceGetAttribute(&cc_minor, cudaDevAttrComputeCapabilityMinor, 0);
    char pci[256] = "unknown";
    cudaDeviceGetPCIBusId(pci, sizeof(pci), 0);
    size_t mem_free = 0, mem_total = 0;
    cudaMemGetInfo(&mem_free, &mem_total);
    fprintf(stderr, "[B] device 0: pci=%s cc=%d.%d mem=%ld MB\n",
            pci, cc_major, cc_minor, (long)(mem_total >> 20));

    cublasHandle_t h;
    CB(cublasCreate(&h));
    int cublas_major = 0, cublas_minor = 0, cublas_patch = 0;
    cublasGetProperty(MAJOR_VERSION, &cublas_major);
    cublasGetProperty(MINOR_VERSION, &cublas_minor);
    cublasGetProperty(PATCH_LEVEL, &cublas_patch);
    fprintf(stderr, "[B] cuBLAS %d.%d.%d\n", cublas_major, cublas_minor, cublas_patch);

    /* Llama-7B-like FFN dims: D=4096 FD=11008 — but we start smaller for
     * Stage 1 diagnostic. d=768 FD=3072 is d_train5 scale. */
    struct { int M, D, FD; int warm, iter; } shapes[] = {
        {  64,  768, 3072, 3, 21 },  /* small batch */
        { 128,  768, 3072, 3, 21 },  /* d_train5-like */
        { 256,  768, 3072, 3, 21 },  /* medium */
        { 512,  768, 3072, 2, 11 },  /* larger */
        { 128, 1024, 4096, 3, 21 },  /* power-of-two */
        { 128, 4096,11008, 2,  7 },  /* Llama-7B-like */
    };
    int n_shapes = (int)(sizeof(shapes)/sizeof(shapes[0]));

    FILE* jf = fopen("/workspace/forge_phaseR_b/result.json", "w");
    if (!jf) { fprintf(stderr, "[B] cannot open result.json\n"); return 2; }
    fprintf(jf, "{\n");
    fprintf(jf, "  \"experiment\": \"forge_phaseR_b_ffn_baseline\",\n");
    fprintf(jf, "  \"stage\": 1,\n");
    fprintf(jf, "  \"date\": \"2026-05-17\",\n");
    fprintf(jf, "  \"device_pci\": \"%s\",\n", pci);
    fprintf(jf, "  \"device_cc\": \"%d.%d\",\n", cc_major, cc_minor);
    fprintf(jf, "  \"device_mem_mb\": %ld,\n", (long)(mem_total >> 20));
    fprintf(jf, "  \"cublas_version\": \"%d.%d.%d\",\n", cublas_major, cublas_minor, cublas_patch);
    fprintf(jf, "  \"hypothesis\": \"H100 fused FFN <= 0.5x separate cuBLAS chain — Stage 1 measures prerequisites\",\n");
    fprintf(jf, "  \"activation\": \"SiLU (single-half; SwiGLU traffic-equivalent for B paradigm)\",\n");
    fprintf(jf, "  \"shapes\": [\n");

    double max_graph_speedup = -1e9, min_graph_speedup = 1e9;
    double max_bw_util_pct = -1, min_bw_util_pct = 1e9;
    for (int i = 0; i < n_shapes; i++) {
        struct ffn_result r = run_shape(h, shapes[i].M, shapes[i].D, shapes[i].FD,
                                        shapes[i].warm, shapes[i].iter);
        double bw_util_pct = r.achieved_bw_separate_GBs / r.theoretical_hbm_peak_GBs * 100.0;
        if (r.graph_speedup_pct > max_graph_speedup) max_graph_speedup = r.graph_speedup_pct;
        if (r.graph_speedup_pct < min_graph_speedup) min_graph_speedup = r.graph_speedup_pct;
        if (bw_util_pct > max_bw_util_pct) max_bw_util_pct = bw_util_pct;
        if (bw_util_pct < min_bw_util_pct) min_bw_util_pct = bw_util_pct;

        if (i > 0) fprintf(jf, ",\n");
        fprintf(jf,
            "    { \"M\":%d, \"D\":%d, \"FD\":%d, "
            "\"t_separate_ms\":%.4f, \"t_graph_ms\":%.4f, "
            "\"graph_speedup_pct\":%.4f, "
            "\"t_dgemm1_ms\":%.5f, \"t_silu_ms\":%.5f, \"t_dgemm2_ms\":%.5f, "
            "\"bytes_rw\":%.0f, "
            "\"achieved_bw_separate_GBs\":%.2f, \"achieved_bw_graph_GBs\":%.2f, "
            "\"bw_util_pct_separate\":%.4f, "
            "\"theoretical_hbm_peak_GBs\":%.0f, "
            "\"bit_equal\":%d, \"max_abs_delta\":%.3e, \"max_rel_delta\":%.3e }",
            r.M, r.D, r.FD,
            r.t_separate_ms, r.t_graph_ms, r.graph_speedup_pct,
            r.t_dgemm1_ms, r.t_silu_ms, r.t_dgemm2_ms,
            r.bytes_read_write,
            r.achieved_bw_separate_GBs, r.achieved_bw_graph_GBs,
            bw_util_pct, r.theoretical_hbm_peak_GBs,
            r.bit_equal, r.max_abs_delta, r.max_rel_delta);
    }

    fprintf(jf, "\n  ],\n");
    fprintf(jf, "  \"summary\": {\n");
    fprintf(jf, "    \"max_graph_speedup_pct\": %.4f,\n", max_graph_speedup);
    fprintf(jf, "    \"min_graph_speedup_pct\": %.4f,\n", min_graph_speedup);
    fprintf(jf, "    \"max_bw_util_pct\": %.4f,\n", max_bw_util_pct);
    fprintf(jf, "    \"min_bw_util_pct\": %.4f,\n", min_bw_util_pct);
    fprintf(jf, "    \"decision_hint\": \"%s\"\n",
            (max_bw_util_pct > 70.0) ?
              "BW-saturated → B paradigm headroom limited regardless of fusion (compute-bound)" :
            (max_graph_speedup > 30.0) ?
              "CUDA Graphs already wins → kernel-launch overhead bottleneck; custom DSM marginal" :
            (max_bw_util_pct < 30.0 && max_graph_speedup < 10.0) ?
              "HBM intermediate-roundtrip bottleneck → DSM fusion (Stage 2) has clear headroom" :
              "intermediate diagnostic — Stage 2 fire to confirm");
    fprintf(jf, "  }\n");
    fprintf(jf, "}\n");
    fclose(jf);

    fprintf(stderr, "[B] DONE — n_shapes=%d graph_speedup=[%.2f%%, %.2f%%] bw_util=[%.2f%%, %.2f%%]\n",
            n_shapes, min_graph_speedup, max_graph_speedup, min_bw_util_pct, max_bw_util_pct);

    cublasDestroy(h);
    return 0;
}
