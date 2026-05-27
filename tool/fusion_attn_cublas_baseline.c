/* F-FUSION-ATTENTION-FLASH -- cuBLAS-using baseline (the stack hexa beats).
 *
 * The canonical non-fused attention path cuBLAS forces:
 *   L1  cublasGemmStridedBatchedEx  S = Q K^T * scale   -> S written to HBM (N x N)
 *   L2  standalone softmax kernel    S = softmax_row(S)  -> reads S, writes S
 *   L3  cublasGemmStridedBatchedEx  O = softmax(S) . V  -> reads S
 * 3 kernel launches + O(N^2) S materialization to HBM. This is exactly what
 * the fused flash-attention kernel structurally avoids.
 *
 * FP32 inputs/outputs. cublasGemmStridedBatchedEx with CUDA_R_32F + the
 * default math mode (matches a typical SGEMM attention path). batch = 1 head.
 * Times the WHOLE 3-launch sequence with cudaEvent: >=20 warmup, >=200 timed.
 *
 * Build:  nvcc -O2 -o fusion_attn_cublas_baseline fusion_attn_cublas_baseline.c -lcublas -lcudart
 * Run:    ./fusion_attn_cublas_baseline [N] [d]
 */
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define CK(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { fprintf(stderr, "CUDA err %s at %s:%d\n", cudaGetErrorString(e), __FILE__, __LINE__); return 1; }} while (0)
#define CB(call) do { cublasStatus_t s = (call); \
    if (s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "cuBLAS err %d at %s:%d\n", (int)s, __FILE__, __LINE__); return 1; }} while (0)

static int cmp_double(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

static uint32_t lcg_state = 0x12345678u;
static float lcg_f32(void) {
    lcg_state = lcg_state * 1664525u + 1013904223u;
    return ((float)(lcg_state >> 8) / (float)(1u << 24)) - 0.5f;
}

/* Row-wise softmax over an N x N matrix S (row-major). One thread per row. */
__global__ void softmax_rows(float *S, int N, int rowlen) {
    int row = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= N) return;
    float *r = S + (size_t)row * rowlen;
    float m = -3.4e38f;
    for (int j = 0; j < rowlen; ++j) if (r[j] > m) m = r[j];
    float l = 0.0f;
    for (int j = 0; j < rowlen; ++j) { float e = expf(r[j] - m); r[j] = e; l += e; }
    float inv = 1.0f / l;
    for (int j = 0; j < rowlen; ++j) r[j] *= inv;
}

int main(int argc, char **argv) {
    int N = (argc > 1) ? atoi(argv[1]) : 2048;
    int d = (argc > 2) ? atoi(argv[2]) : 64;

    size_t szT = (size_t)N * d * sizeof(float);   /* Q/K/V/O */
    size_t szS = (size_t)N * N * sizeof(float);    /* S score matrix */
    float *hq = (float *)malloc(szT), *hk = (float *)malloc(szT);
    float *hv = (float *)malloc(szT), *ho = (float *)malloc(szT);
    double *ref = (double *)malloc((size_t)N * d * sizeof(double));

    /* Q,K scaled wider (matches the fused host) so softmax is peaked and the
       f32-vs-f64 rel-error has a well-conditioned denominator. */
    for (int i = 0; i < N * d; ++i) hq[i] = lcg_f32() * 4.0f;
    for (int i = 0; i < N * d; ++i) hk[i] = lcg_f32() * 4.0f;
    for (int i = 0; i < N * d; ++i) hv[i] = lcg_f32();
    float scale = 1.0f / sqrtf((float)d);

    /* f64 CPU reference (same as fused host). */
    for (int qi = 0; qi < N; ++qi) {
        double m = -1e300;
        double *s = (double *)malloc((size_t)N * sizeof(double));
        for (int kj = 0; kj < N; ++kj) {
            double dot = 0.0;
            for (int t = 0; t < d; ++t) dot += (double)hq[qi*d+t] * (double)hk[kj*d+t];
            dot *= (double)scale; s[kj] = dot; if (dot > m) m = dot;
        }
        double l = 0.0;
        for (int kj = 0; kj < N; ++kj) { s[kj] = exp(s[kj]-m); l += s[kj]; }
        for (int t = 0; t < d; ++t) {
            double acc = 0.0;
            for (int kj = 0; kj < N; ++kj) acc += s[kj] * (double)hv[kj*d+t];
            ref[qi*d+t] = acc / l;
        }
        free(s);
    }

    float *dq, *dk, *dv, *dop, *dS;
    CK(cudaMalloc(&dq, szT)); CK(cudaMalloc(&dk, szT));
    CK(cudaMalloc(&dv, szT)); CK(cudaMalloc(&dop, szT));
    CK(cudaMalloc(&dS, szS));
    CK(cudaMemcpy(dq, hq, szT, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dk, hk, szT, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dv, hv, szT, cudaMemcpyHostToDevice));

    cublasHandle_t h; CB(cublasCreate(&h));

    /* cuBLAS is column-major. We store everything row-major in C. The trick:
       a row-major [M x K] matrix is, viewed column-major, a [K x M] matrix.
       We compute S^T (col-major) = K (row d x N viewed) ... rather than fight
       layouts we use the standard attention recipe:

       S[i][j] = sum_t Q[i][t] * K[j][t]   (Q,K row-major [N x d])
       In col-major terms with leading dims = d:
         treat Q as a d x N col-major matrix Qc (since Q row-major [N x d]),
         treat K as a d x N col-major matrix Kc.
         S row-major [N x N] == Sc col-major [N x N] computed as
           Sc = Qc^T * Kc  -> op(A)=T on Qc (d x N) gives N x d,
                              op(B)=N on Kc (d x N) gives d x N -> N x N. OK.
       So: cublasSgemm(handle, CUBLAS_OP_T, CUBLAS_OP_N,
                       N, N, d, &scale, Qc(d,N,lda=d), Kc(d,N,ldb=d),
                       &beta0, Sc(N,N,ldc=N)).
       That yields Sc[col j][row i] = scale * sum_t Q[i][t]*K[j][t] = S[i][j]
       when read row-major. Good. */
    const float one = 1.0f, zero = 0.0f;

    /* We use cublasGemmStridedBatchedEx per the falsifier wording (batch=1).
       cuBLAS is column-major; everything in host memory is row-major.
       A row-major [N x d] matrix M, read column-major with ld=d, is M^T i.e.
       Mc[t][i] = M[i][t]. Call the column-major views Qc,Kc,Vc (all d x N).

       L1: we want the softmax kernel (row-major, row stride N) to softmax over
       the j (key) axis of S[i][j]. So dS in HBM must satisfy row-major
       dS[i*N + j] = S[i][j] = scale * sum_t Q[i][t] K[j][t].
       A column-major write with ldc=N stores element (r,c) at r + c*N; to make
       r + c*N == i*N + j we need c=i, r=j, i.e. cuBLAS computes column-major
       Sc[j][i] = S[i][j] = scale * sum_t Kc[t][j] Qc[t][i] = (Kc^T Qc)[j][i].
         gemm(OP_T, OP_N, m=N(j), n=N(i), k=d, scale, A=Kc(d x N ld d),
              B=Qc(d x N ld d), 0, C=dS ld N).

       L3: O[i][t] = sum_j P[i][j] V[j][t], P = softmax(S) row-major in dS.
       Want row-major dop[i*d + t] = O[i][t]; column-major ld=d stores (r,c) at
       r + c*d, so make r=t, c=i -> Oc[t][i] = O[i][t]
                 = sum_j Vc[t][j] * P[i][j].
       P[i][j] is row-major dS[i*N + j]; that memory read column-major ld=N is
       Pc[j][i] (Pc[r][c] at r + c*N -> r=j, c=i). So
         Oc[t][i] = sum_j Vc[t][j] * Pc[j][i] = (Vc Pc)[t][i].
         gemm(OP_N, OP_N, m=d(t), n=N(i), k=N(j), 1, A=Vc(d x N ld d),
              B=dS(N x N ld N), 0, C=dop ld d). */
    long long strideA = 0, strideB = 0, strideC = 0;

    cudaEvent_t e0, e1; CK(cudaEventCreate(&e0)); CK(cudaEventCreate(&e1));
    int sm_threads = 256;
    int sm_blocks = (N + sm_threads - 1) / sm_threads;

    /* one correctness pass */
    {
        CB(cublasGemmStridedBatchedEx(h, CUBLAS_OP_T, CUBLAS_OP_N, N, N, d,
            &scale, dk, CUDA_R_32F, d, strideA, dq, CUDA_R_32F, d, strideB,
            &zero, dS, CUDA_R_32F, N, strideC, 1,
            CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT));
        softmax_rows<<<sm_blocks, sm_threads>>>(dS, N, N);
        CB(cublasGemmStridedBatchedEx(h, CUBLAS_OP_N, CUBLAS_OP_N, d, N, N,
            &one, dv, CUDA_R_32F, d, strideA, dS, CUDA_R_32F, N, strideB,
            &zero, dop, CUDA_R_32F, d, strideC, 1,
            CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT));
        CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(ho, dop, szT, cudaMemcpyDeviceToHost));
    }
    /* scale-normalized tolerance, same metric as the fused host. */
    double max_abs_delta = 0.0, max_abs_ref = 0.0;
    for (int i = 0; i < N * d; ++i) {
        double r = ref[i], hh = (double)ho[i];
        double a = fabs(r); if (a > max_abs_ref) max_abs_ref = a;
        double dd = fabs(hh - r); if (dd > max_abs_delta) max_abs_delta = dd;
    }
    double tol_abs = (max_abs_ref > 0.0) ? max_abs_ref * 1e-2 : 1e-3;
    double max_rel = (max_abs_ref > 0.0) ? max_abs_delta / max_abs_ref : max_abs_delta;
    int numeric_pass = (max_abs_delta <= tol_abs);

    const int WARMUP = 20, TIMED = 200;
    for (int i = 0; i < WARMUP; ++i) {
        CB(cublasGemmStridedBatchedEx(h, CUBLAS_OP_T, CUBLAS_OP_N, N, N, d,
            &scale, dk, CUDA_R_32F, d, strideA, dq, CUDA_R_32F, d, strideB,
            &zero, dS, CUDA_R_32F, N, strideC, 1, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT));
        softmax_rows<<<sm_blocks, sm_threads>>>(dS, N, N);
        CB(cublasGemmStridedBatchedEx(h, CUBLAS_OP_N, CUBLAS_OP_N, d, N, N,
            &one, dv, CUDA_R_32F, d, strideA, dS, CUDA_R_32F, N, strideB,
            &zero, dop, CUDA_R_32F, d, strideC, 1, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT));
    }
    CK(cudaDeviceSynchronize());

    double *times = (double *)malloc(TIMED * sizeof(double));
    for (int i = 0; i < TIMED; ++i) {
        CK(cudaEventRecord(e0, 0));
        CB(cublasGemmStridedBatchedEx(h, CUBLAS_OP_T, CUBLAS_OP_N, N, N, d,
            &scale, dk, CUDA_R_32F, d, strideA, dq, CUDA_R_32F, d, strideB,
            &zero, dS, CUDA_R_32F, N, strideC, 1, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT));
        softmax_rows<<<sm_blocks, sm_threads>>>(dS, N, N);
        CB(cublasGemmStridedBatchedEx(h, CUBLAS_OP_N, CUBLAS_OP_N, d, N, N,
            &one, dv, CUDA_R_32F, d, strideA, dS, CUDA_R_32F, N, strideB,
            &zero, dop, CUDA_R_32F, d, strideC, 1, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT));
        CK(cudaEventRecord(e1, 0));
        CK(cudaEventSynchronize(e1));
        float ms = 0; CK(cudaEventElapsedTime(&ms, e0, e1));
        times[i] = (double)ms;
    }
    qsort(times, TIMED, sizeof(double), cmp_double);
    double median = times[TIMED/2];
    double mean = 0; for (int i = 0; i < TIMED; ++i) mean += times[i]; mean /= TIMED;
    double var = 0; for (int i = 0; i < TIMED; ++i) { double dd = times[i]-mean; var += dd*dd; }
    double sd = sqrt(var / TIMED);

    const char *verd = numeric_pass ? "PASS" : "FAIL";
    printf("BASELINE-CUBLAS-NUMERIC %s -- N=%d d=%d max_rel=%g tol=1e-2 max_abs_ref=%g\n",
           verd, N, d, max_rel, max_abs_ref);
    printf("BASELINE-WALL N=%d d=%d launches=3 median_ms=%.6f mean_ms=%.6f std_ms=%.6f std_pct=%.4f\n",
           N, d, median, mean, sd, (mean > 0 ? 100.0*sd/mean : 0.0));

    FILE *rj = fopen("baseline_result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"baseline\": \"cublasGemmStridedBatchedEx x2 + softmax kernel\",\n");
    fprintf(rj, "  \"verdict\": \"%s\",\n", verd);
    fprintf(rj, "  \"N\": %d,\n  \"d\": %d,\n", N, d);
    fprintf(rj, "  \"launches\": 3,\n");
    fprintf(rj, "  \"max_rel\": %g,\n", max_rel);
    fprintf(rj, "  \"median_ms\": %.6f,\n", median);
    fprintf(rj, "  \"mean_ms\": %.6f,\n", mean);
    fprintf(rj, "  \"std_ms\": %.6f\n", sd);
    fprintf(rj, "}\n");
    fclose(rj);

    cudaFree(dq); cudaFree(dk); cudaFree(dv); cudaFree(dop); cudaFree(dS);
    cublasDestroy(h);
    return numeric_pass ? 0 : 1;
}
