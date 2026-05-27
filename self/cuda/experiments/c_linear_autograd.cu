/* c_linear_autograd.cu — forge Phase R / C paradigm falsifier (Stage 1 diagnostic)
 *
 * Pre-registered C hypothesis (FORGE.tape 2026-05-17):
 *   Fused (fwd, bwd) pair HBM traffic ≤ 0.6 × separate fwd-then-bwd.
 *
 * Stage 1 measures the linear-layer forward+backward chain on cuBLAS:
 *   - forward: y = x · W                (1 Dgemm)
 *   - backward: dW = x^T · dy            (1 Dgemm)
 *               dx = dy · W^T            (1 Dgemm)
 *   = 3 cuBLAS Dgemms total per full fwd+bwd of one linear layer.
 *
 * Three paths measured:
 *   1. separate     — 3 explicit cuBLAS launches with HBM intermediate (dy and x are
 *                     read by both bwd ops; W and x are read twice each)
 *   2. graph        — same 3 ops captured into CUDA Graph + replayed (kernel-launch fusion)
 *   3. (deferred)   — custom co-emitted kernel that reuses x, dy, W tiles in
 *                     SMEM/registers across fwd and bwd (Stage 2, requires
 *                     non-trivial kernel writing)
 *
 * Decision matrix from Stage 1 data:
 *   - achieved HBM BW > 70% peak → linear bwd is compute-bound → C paradigm
 *     has limited headroom (FAIL stage gate).
 *   - graph speedup > 30% → kernel-launch overhead dominates → CUDA Graphs
 *     wins most of paradigm C already, custom kernel marginal.
 *   - HBM bytes_separate / bytes_minimal > 1.6 (i.e., separate path re-reads
 *     x and dy more than 1.6× vs theoretical minimum) AND achieved BW < 30%
 *     peak → HBM roundtrip is the bottleneck → Stage 2 (co-emitted kernel
 *     that reuses tiles) has clear headroom.
 *
 * Bit-equality: separate path output dW, dx vs graph path → byte-equal
 * (CUDA Graphs same ops, same input → same output).
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
    if (_e != cudaSuccess) { fprintf(stderr, "[C] CUDA %s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(_e)); exit(1); } \
} while (0)

#define CB(call) do { \
    cublasStatus_t _s = (call); \
    if (_s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "[C] cuBLAS %s:%d status=%d\n", __FILE__, __LINE__, (int)_s); exit(1); } \
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

static double median(double* a, int n) {
    qsort(a, n, sizeof(double), dbl_cmp);
    return a[n / 2];
}

/* Run forward+backward of a single linear layer (y = x·W) once.
 *   x:  M × Din  (input)
 *   W:  Din × Dout  (weight)
 *   y:  M × Dout  (forward output)
 *   dy: M × Dout  (upstream gradient, given)
 *   dW: Din × Dout (weight gradient)
 *   dx: M × Din   (input gradient)
 *
 * Forward:   y  = x · W                              [M·Din × Din·Dout → M·Dout]
 * Backward:  dW = x^T · dy                           [Din·M × M·Dout → Din·Dout]
 *            dx = dy · W^T                           [M·Dout × Dout·Din → M·Din]
 *
 * cuBLAS row-major→column-major via swap-arg trick (anima pattern):
 *   row-major C(M,N) = A(M,K) · B(K,N) is computed as col-major
 *   C^T(N,M) = B^T(N,K) · A^T(K,M); we ask cublasDgemm(N, M, K, B, A) which
 *   reads B as N×K col-major == B^T (which is what we want when B is row-major K×N).
 */
static void run_linear_fwdbwd(cublasHandle_t h, cudaStream_t st,
                              int M, int Din, int Dout,
                              const double* dX, const double* dW,
                              const double* dY, double* dY_out,
                              double* dW_out, double* dX_out) {
    const double alpha = 1.0, beta = 0.0;
    /* forward: Y = X · W            (M × Din) · (Din × Dout) = M × Dout */
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                Dout, M, Din, &alpha, dW, Dout, dX, Din, &beta, dY_out, Dout);
    /* backward dW: dW = X^T · dY    (Din × M) · (M × Dout) = Din × Dout */
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_T,
                Dout, Din, M, &alpha, dY, Dout, dX, Din, &beta, dW_out, Dout);
    /* backward dx: dX = dY · W^T    (M × Dout) · (Dout × Din) = M × Din */
    cublasDgemm(h, CUBLAS_OP_T, CUBLAS_OP_N,
                Din, M, Dout, &alpha, dW, Dout, dY, Dout, &beta, dX_out, Din);
}

struct c_result {
    int M, Din, Dout;
    double t_separate_ms, t_graph_ms;
    double graph_speedup_pct;
    /* Per-kernel timings (from cudaEvents). */
    double t_fwd_ms, t_dW_ms, t_dX_ms;
    /* HBM traffic analysis:
     *   bytes_separate = bytes a no-tile-reuse implementation reads/writes
     *                  = sizeof(double) × (
     *                      read X (M·Din) + read W (Din·Dout) + write Y (M·Dout) +     [fwd]
     *                      read X (M·Din) + read dY (M·Dout) + write dW (Din·Dout) +    [bwd dW]
     *                      read dY (M·Dout) + read W (Din·Dout) + write dX (M·Din)      [bwd dX]
     *                    )
     *   bytes_minimal  = sizeof(double) × (
     *                      read X (M·Din once) + read W (Din·Dout once) + read dY (M·Dout once) +
     *                      write Y (M·Dout) + write dW (Din·Dout) + write dX (M·Din)
     *                    )
     *   bytes_separate / bytes_minimal ratio = how much HBM headroom exists
     *   (1.0 = already optimal, > 1.5 = significant re-read, target for Stage 2).
     */
    double bytes_separate;
    double bytes_minimal;
    double bytes_redundancy_ratio;  /* separate / minimal */
    double achieved_bw_separate_GBs;
    double achieved_bw_graph_GBs;
    double theoretical_hbm_peak_GBs;
    double bw_util_pct_separate;
    int bit_equal_dW, bit_equal_dX, bit_equal_Y;
    double max_abs_delta_dW, max_abs_delta_dX, max_abs_delta_Y;
};

static struct c_result run_shape(cublasHandle_t h, int M, int Din, int Dout,
                                 int n_warm, int n_iter) {
    fprintf(stderr, "[C] === linear fwd+bwd M=%d Din=%d Dout=%d (warm=%d iter=%d) ===\n",
            M, Din, Dout, n_warm, n_iter);
    size_t szX  = (size_t)M*Din*sizeof(double);
    size_t szW  = (size_t)Din*Dout*sizeof(double);
    size_t szY  = (size_t)M*Dout*sizeof(double);
    size_t szdW = (size_t)Din*Dout*sizeof(double);
    size_t szdX = (size_t)M*Din*sizeof(double);

    double *hX = (double*)malloc(szX);
    double *hW = (double*)malloc(szW);
    double *hDy = (double*)malloc(szY);
    double *hY_sep = (double*)malloc(szY);
    double *hY_graph = (double*)malloc(szY);
    double *hdW_sep = (double*)malloc(szdW);
    double *hdW_graph = (double*)malloc(szdW);
    double *hdX_sep = (double*)malloc(szdX);
    double *hdX_graph = (double*)malloc(szdX);

    uint64_t st = 0xc1c1c1c1ULL ^ (uint64_t)(M*1000003 + Din*1009 + Dout*31);
    for (size_t i = 0; i < (size_t)M*Din; i++)   hX[i]  = (lcg_next(&st) - 0.5) * 0.5;
    for (size_t i = 0; i < (size_t)Din*Dout; i++) hW[i]  = (lcg_next(&st) - 0.5) * 0.05;
    for (size_t i = 0; i < (size_t)M*Dout; i++)   hDy[i] = (lcg_next(&st) - 0.5) * 0.1;

    double *dX, *dW, *dY, *dY_out, *dW_out, *dX_out;
    double *dY_out_g, *dW_out_g, *dX_out_g;
    CK(cudaMalloc((void**)&dX, szX));
    CK(cudaMalloc((void**)&dW, szW));
    CK(cudaMalloc((void**)&dY, szY));
    CK(cudaMalloc((void**)&dY_out, szY));
    CK(cudaMalloc((void**)&dW_out, szdW));
    CK(cudaMalloc((void**)&dX_out, szdX));
    CK(cudaMalloc((void**)&dY_out_g, szY));
    CK(cudaMalloc((void**)&dW_out_g, szdW));
    CK(cudaMalloc((void**)&dX_out_g, szdX));
    CK(cudaMemcpy(dX, hX, szX, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW, hW, szW, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dY, hDy, szY, cudaMemcpyHostToDevice));

    cudaStream_t stream;
    CK(cudaStreamCreate(&stream));
    CB(cublasSetStream(h, stream));

    struct c_result r;
    r.M = M; r.Din = Din; r.Dout = Dout;

    /* === PATH 1: separate launches === */
    for (int w = 0; w < n_warm; w++)
        run_linear_fwdbwd(h, stream, M, Din, Dout, dX, dW, dY,
                          dY_out, dW_out, dX_out);
    CK(cudaStreamSynchronize(stream));

    double* samples_sep = (double*)malloc((size_t)n_iter * sizeof(double));
    for (int it = 0; it < n_iter; it++) {
        double t0 = now_sec();
        run_linear_fwdbwd(h, stream, M, Din, Dout, dX, dW, dY,
                          dY_out, dW_out, dX_out);
        CK(cudaStreamSynchronize(stream));
        samples_sep[it] = (now_sec() - t0) * 1000.0;
    }
    r.t_separate_ms = median(samples_sep, n_iter);
    free(samples_sep);

    CK(cudaMemcpy(hY_sep,  dY_out, szY,  cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hdW_sep, dW_out, szdW, cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hdX_sep, dX_out, szdX, cudaMemcpyDeviceToHost));

    /* === Per-kernel breakdown (cudaEvents) === */
    cudaEvent_t ev_a, ev_b, ev_c, ev_d;
    cudaEventCreate(&ev_a); cudaEventCreate(&ev_b);
    cudaEventCreate(&ev_c); cudaEventCreate(&ev_d);
    const double alpha = 1.0, beta = 0.0;
    double sum_fwd = 0, sum_dW = 0, sum_dX = 0;
    int n_ev = 5;
    for (int it = 0; it < n_ev; it++) {
        cudaEventRecord(ev_a, stream);
        cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                    Dout, M, Din, &alpha, dW, Dout, dX, Din, &beta, dY_out, Dout);
        cudaEventRecord(ev_b, stream);
        cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_T,
                    Dout, Din, M, &alpha, dY, Dout, dX, Din, &beta, dW_out, Dout);
        cudaEventRecord(ev_c, stream);
        cublasDgemm(h, CUBLAS_OP_T, CUBLAS_OP_N,
                    Din, M, Dout, &alpha, dW, Dout, dY, Dout, &beta, dX_out, Din);
        cudaEventRecord(ev_d, stream);
        CK(cudaStreamSynchronize(stream));
        float ab=0, bc=0, cd=0;
        cudaEventElapsedTime(&ab, ev_a, ev_b);
        cudaEventElapsedTime(&bc, ev_b, ev_c);
        cudaEventElapsedTime(&cd, ev_c, ev_d);
        sum_fwd += ab; sum_dW += bc; sum_dX += cd;
    }
    r.t_fwd_ms = sum_fwd / n_ev;
    r.t_dW_ms  = sum_dW / n_ev;
    r.t_dX_ms  = sum_dX / n_ev;
    cudaEventDestroy(ev_a); cudaEventDestroy(ev_b);
    cudaEventDestroy(ev_c); cudaEventDestroy(ev_d);

    /* === PATH 2: CUDA Graphs === */
    cudaGraph_t graph;
    cudaGraphExec_t exec;
    CK(cudaStreamBeginCapture(stream, cudaStreamCaptureModeGlobal));
    run_linear_fwdbwd(h, stream, M, Din, Dout, dX, dW, dY,
                      dY_out_g, dW_out_g, dX_out_g);
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

    CK(cudaMemcpy(hY_graph,  dY_out_g, szY,  cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hdW_graph, dW_out_g, szdW, cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hdX_graph, dX_out_g, szdX, cudaMemcpyDeviceToHost));

    cudaGraphExecDestroy(exec);
    cudaGraphDestroy(graph);
    cudaStreamDestroy(stream);
    CB(cublasSetStream(h, 0));

    /* === bit-equality === */
    r.bit_equal_Y  = (memcmp(hY_sep,  hY_graph,  szY)  == 0) ? 1 : 0;
    r.bit_equal_dW = (memcmp(hdW_sep, hdW_graph, szdW) == 0) ? 1 : 0;
    r.bit_equal_dX = (memcmp(hdX_sep, hdX_graph, szdX) == 0) ? 1 : 0;
    double max_Y = 0, max_dW = 0, max_dX = 0;
    for (size_t i = 0; i < (size_t)M*Dout; i++) {
        double d = fabs(hY_sep[i] - hY_graph[i]);
        if (d > max_Y) max_Y = d;
    }
    for (size_t i = 0; i < (size_t)Din*Dout; i++) {
        double d = fabs(hdW_sep[i] - hdW_graph[i]);
        if (d > max_dW) max_dW = d;
    }
    for (size_t i = 0; i < (size_t)M*Din; i++) {
        double d = fabs(hdX_sep[i] - hdX_graph[i]);
        if (d > max_dX) max_dX = d;
    }
    r.max_abs_delta_Y = max_Y;
    r.max_abs_delta_dW = max_dW;
    r.max_abs_delta_dX = max_dX;

    /* === HBM traffic accounting === */
    double bytes_sep = (double)sizeof(double) * (
        /* fwd  : read X, read W, write Y  */ (double)M*Din + (double)Din*Dout + (double)M*Dout +
        /* dW   : read X, read dY, write dW */ (double)M*Din + (double)M*Dout + (double)Din*Dout +
        /* dX   : read dY, read W, write dX */ (double)M*Dout + (double)Din*Dout + (double)M*Din
    );
    double bytes_min = (double)sizeof(double) * (
        /* min  : read X once, read W once, read dY once, write Y, write dW, write dX */
        (double)M*Din + (double)Din*Dout + (double)M*Dout +
        (double)M*Dout + (double)Din*Dout + (double)M*Din
    );
    r.bytes_separate = bytes_sep;
    r.bytes_minimal = bytes_min;
    r.bytes_redundancy_ratio = bytes_sep / bytes_min;
    r.achieved_bw_separate_GBs = (bytes_sep / 1e9) / (r.t_separate_ms / 1000.0);
    r.achieved_bw_graph_GBs    = (bytes_sep / 1e9) / (r.t_graph_ms / 1000.0);
    r.theoretical_hbm_peak_GBs = 3350.0;  /* H100 SXM5 HBM3 */
    r.bw_util_pct_separate = r.achieved_bw_separate_GBs / r.theoretical_hbm_peak_GBs * 100.0;

    r.graph_speedup_pct = (r.t_separate_ms - r.t_graph_ms) / r.t_separate_ms * 100.0;

    fprintf(stderr, "[C]   sep=%.3f ms graph=%.3f ms (speedup=%+.2f%%)\n"
                    "[C]   fwd=%.4f dW=%.4f dX=%.4f (sum=%.4f)\n"
                    "[C]   bytes_sep=%.2e min=%.2e redundancy=%.3f×\n"
                    "[C]   BW sep=%.1f GB/s graph=%.1f GB/s peak=%.0f util=%.1f%%\n"
                    "[C]   bit_eq Y/dW/dX = %d/%d/%d max|Δ| Y=%.2e dW=%.2e dX=%.2e\n",
            r.t_separate_ms, r.t_graph_ms, r.graph_speedup_pct,
            r.t_fwd_ms, r.t_dW_ms, r.t_dX_ms, r.t_fwd_ms + r.t_dW_ms + r.t_dX_ms,
            r.bytes_separate, r.bytes_minimal, r.bytes_redundancy_ratio,
            r.achieved_bw_separate_GBs, r.achieved_bw_graph_GBs,
            r.theoretical_hbm_peak_GBs, r.bw_util_pct_separate,
            r.bit_equal_Y, r.bit_equal_dW, r.bit_equal_dX,
            r.max_abs_delta_Y, r.max_abs_delta_dW, r.max_abs_delta_dX);

    cudaFree(dX); cudaFree(dW); cudaFree(dY);
    cudaFree(dY_out); cudaFree(dW_out); cudaFree(dX_out);
    cudaFree(dY_out_g); cudaFree(dW_out_g); cudaFree(dX_out_g);
    free(hX); free(hW); free(hDy);
    free(hY_sep); free(hY_graph);
    free(hdW_sep); free(hdW_graph);
    free(hdX_sep); free(hdX_graph);
    return r;
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;
    int n_dev = 0;
    cudaGetDeviceCount(&n_dev);
    if (n_dev <= 0) { fprintf(stderr, "[C] FATAL: no CUDA device\n"); return 1; }

    int cc_major = 0, cc_minor = 0;
    cudaDeviceGetAttribute(&cc_major, cudaDevAttrComputeCapabilityMajor, 0);
    cudaDeviceGetAttribute(&cc_minor, cudaDevAttrComputeCapabilityMinor, 0);
    char pci[256] = "unknown";
    cudaDeviceGetPCIBusId(pci, sizeof(pci), 0);
    size_t mem_free = 0, mem_total = 0;
    cudaMemGetInfo(&mem_free, &mem_total);
    fprintf(stderr, "[C] device 0: pci=%s cc=%d.%d mem=%ld MB\n",
            pci, cc_major, cc_minor, (long)(mem_total >> 20));

    cublasHandle_t h;
    CB(cublasCreate(&h));
    int cublas_major = 0, cublas_minor = 0, cublas_patch = 0;
    cublasGetProperty(MAJOR_VERSION, &cublas_major);
    cublasGetProperty(MINOR_VERSION, &cublas_minor);
    cublasGetProperty(PATCH_LEVEL, &cublas_patch);
    fprintf(stderr, "[C] cuBLAS %d.%d.%d\n", cublas_major, cublas_minor, cublas_patch);

    struct { int M, Din, Dout; int warm, iter; } shapes[] = {
        { 128,  768,  768, 3, 21 },  /* d_train5 representative */
        { 256,  768,  768, 3, 21 },
        { 512,  768,  768, 2, 11 },
        { 128, 1024, 1024, 3, 21 },
        { 128, 4096, 4096, 2,  7 },  /* Llama-7B scale */
    };
    int n_shapes = (int)(sizeof(shapes)/sizeof(shapes[0]));

    FILE* jf = fopen("/workspace/forge_phaseR_c/result.json", "w");
    if (!jf) { fprintf(stderr, "[C] cannot open result.json\n"); return 2; }
    fprintf(jf, "{\n");
    fprintf(jf, "  \"experiment\": \"forge_phaseR_c_linear_autograd\",\n");
    fprintf(jf, "  \"stage\": 1,\n");
    fprintf(jf, "  \"date\": \"2026-05-17\",\n");
    fprintf(jf, "  \"device_pci\": \"%s\",\n", pci);
    fprintf(jf, "  \"device_cc\": \"%d.%d\",\n", cc_major, cc_minor);
    fprintf(jf, "  \"device_mem_mb\": %ld,\n", (long)(mem_total >> 20));
    fprintf(jf, "  \"cublas_version\": \"%d.%d.%d\",\n", cublas_major, cublas_minor, cublas_patch);
    fprintf(jf, "  \"hypothesis\": \"fused (fwd,bwd) HBM traffic <= 0.6x separate — Stage 1 measures prerequisites\",\n");
    fprintf(jf, "  \"shapes\": [\n");

    double max_redundancy = -1e9, min_redundancy = 1e9;
    double max_graph_speedup = -1e9, max_bw_util_pct = -1e9;
    for (int i = 0; i < n_shapes; i++) {
        struct c_result r = run_shape(h, shapes[i].M, shapes[i].Din, shapes[i].Dout,
                                      shapes[i].warm, shapes[i].iter);
        if (r.bytes_redundancy_ratio > max_redundancy) max_redundancy = r.bytes_redundancy_ratio;
        if (r.bytes_redundancy_ratio < min_redundancy) min_redundancy = r.bytes_redundancy_ratio;
        if (r.graph_speedup_pct > max_graph_speedup) max_graph_speedup = r.graph_speedup_pct;
        if (r.bw_util_pct_separate > max_bw_util_pct) max_bw_util_pct = r.bw_util_pct_separate;

        if (i > 0) fprintf(jf, ",\n");
        fprintf(jf,
            "    { \"M\":%d, \"Din\":%d, \"Dout\":%d, "
            "\"t_separate_ms\":%.4f, \"t_graph_ms\":%.4f, "
            "\"graph_speedup_pct\":%.4f, "
            "\"t_fwd_ms\":%.5f, \"t_dW_ms\":%.5f, \"t_dX_ms\":%.5f, "
            "\"bytes_separate\":%.0f, \"bytes_minimal\":%.0f, \"bytes_redundancy_ratio\":%.4f, "
            "\"achieved_bw_separate_GBs\":%.2f, \"achieved_bw_graph_GBs\":%.2f, "
            "\"bw_util_pct_separate\":%.4f, \"theoretical_hbm_peak_GBs\":%.0f, "
            "\"bit_equal_Y\":%d, \"bit_equal_dW\":%d, \"bit_equal_dX\":%d, "
            "\"max_abs_delta_Y\":%.3e, \"max_abs_delta_dW\":%.3e, \"max_abs_delta_dX\":%.3e }",
            r.M, r.Din, r.Dout,
            r.t_separate_ms, r.t_graph_ms, r.graph_speedup_pct,
            r.t_fwd_ms, r.t_dW_ms, r.t_dX_ms,
            r.bytes_separate, r.bytes_minimal, r.bytes_redundancy_ratio,
            r.achieved_bw_separate_GBs, r.achieved_bw_graph_GBs,
            r.bw_util_pct_separate, r.theoretical_hbm_peak_GBs,
            r.bit_equal_Y, r.bit_equal_dW, r.bit_equal_dX,
            r.max_abs_delta_Y, r.max_abs_delta_dW, r.max_abs_delta_dX);
    }

    fprintf(jf, "\n  ],\n");
    fprintf(jf, "  \"summary\": {\n");
    fprintf(jf, "    \"max_redundancy_ratio\": %.4f,\n", max_redundancy);
    fprintf(jf, "    \"min_redundancy_ratio\": %.4f,\n", min_redundancy);
    fprintf(jf, "    \"max_graph_speedup_pct\": %.4f,\n", max_graph_speedup);
    fprintf(jf, "    \"max_bw_util_pct\": %.4f,\n", max_bw_util_pct);
    fprintf(jf, "    \"decision_hint\": \"%s\"\n",
            (max_bw_util_pct > 70.0) ?
              "compute-bound → C paradigm limited regardless of fusion" :
            (max_graph_speedup > 30.0) ?
              "CUDA Graphs already wins → custom co-emission marginal" :
            (max_redundancy > 1.5 && max_bw_util_pct < 30.0) ?
              "HBM re-read 1.5×+ AND BW < 30% peak → Stage 2 custom co-emission has clear headroom" :
              "intermediate diagnostic — Stage 2 fire to confirm");
    fprintf(jf, "  }\n");
    fprintf(jf, "}\n");
    fclose(jf);

    fprintf(stderr, "[C] DONE — n_shapes=%d max_redundancy=%.3fx max_graph_speedup=%+.2f%% max_bw_util=%.2f%%\n",
            n_shapes, max_redundancy, max_graph_speedup, max_bw_util_pct);

    cublasDestroy(h);
    return 0;
}
