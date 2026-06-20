/* cuda_no_cublas_smoke.c — piece ④ HEADLINE smoke for the HEXA_NO_CUBLAS variant.
 *
 * Drives the production BF16 matmul entry point hexa_farr_matmul_bf16_gpu
 * (runtime_bf16.c, #include'd into runtime_cuda.c) which, under -DHEXA_NO_CUBLAS,
 * routes to the OWN mma.sync m16n8k16 kernel (_hx_k_gemm_bf16_owngemm) — NO cuBLAS.
 *
 * The PROOF is two-fold:
 *   1) the whole TU links with ZERO -lcublas (the link line in build_no_cublas_smoke
 *      has no -lcublas; an unguarded cublas* symbol would be an undefined-ref error)
 *   2) the forge GEMM produces correct output: own-vs-FP64-ref rel-RMS within the
 *      BF16 tolerance (<= 1e-2, the file-header contract C2).
 *
 * The [BF16-OWN-FIRED] marker on stderr confirms the cuBLAS-free path executed.
 * Self-contained: uses the HexaFarrBf16 descriptor ABI (no farr-table bootstrap).
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

typedef struct HexaFarrBf16 {
    void*    h_buf;
    void*    d_buf;
    int64_t  len;
    int      loc;
    int      owns;
} HexaFarrBf16;

extern HexaFarrBf16* hexa_farr_bf16_alloc(int64_t len);
extern void          hexa_farr_bf16_free(HexaFarrBf16* f);
extern int           hexa_farr_bf16_from_f64(const double* src, HexaFarrBf16* dst, int64_t n);
extern int           hexa_farr_bf16_to_f64(const HexaFarrBf16* src, double* dst, int64_t n);
extern int           hexa_farr_bf16_to_device(HexaFarrBf16* f);
extern int           hexa_farr_bf16_to_host(HexaFarrBf16* f);
extern int           hexa_farr_matmul_bf16_gpu(HexaFarrBf16* A, int64_t M, int64_t K,
                                               HexaFarrBf16* B, int64_t N,
                                               HexaFarrBf16* C);

static void fill(double* x, int64_t n, uint64_t seed) {
    uint64_t s = seed;
    for (int64_t i = 0; i < n; i++) {
        s ^= s << 13; s ^= s >> 7; s ^= s << 17;
        x[i] = (((double)(s & 0xFFFFu) / 65535.0) - 0.5) * 0.2;
    }
}
static double bf16_round(double v) {
    float f = (float)v;
    uint32_t bits; memcpy(&bits, &f, 4);
    if (((bits >> 23) & 0xFF) == 0xFF && (bits & 0x7FFFFF) != 0) return v;
    uint32_t lsb = (bits >> 16) & 1u;
    uint32_t bias = 0x7FFFu + lsb;
    uint16_t bf = (uint16_t)((bits + bias) >> 16);
    uint32_t wide = (uint32_t)bf << 16;
    float r; memcpy(&r, &wide, 4);
    return (double)r;
}
static void ref_fp64(const double* A, const double* B, double* R,
                     int64_t M, int64_t N, int64_t K) {
    for (int64_t i = 0; i < M; i++)
        for (int64_t j = 0; j < N; j++) {
            double s = 0;
            for (int64_t k = 0; k < K; k++)
                s += bf16_round(A[i*K+k]) * bf16_round(B[k*N+j]);
            R[i*N+j] = s;
        }
}
static double rel_rms(const double* a, const double* b, int64_t n) {
    double se = 0, sr = 0;
    for (int64_t i = 0; i < n; i++) { double d = a[i]-b[i]; se += d*d; sr += b[i]*b[i]; }
    return sr > 0 ? sqrt(se/n)/sqrt(sr/n) : 0.0;
}
static int run_bf16(int64_t M, int64_t K, int64_t N,
                    const double* hA, const double* hB, double* out) {
    HexaFarrBf16 *A = hexa_farr_bf16_alloc(M*K);
    HexaFarrBf16 *B = hexa_farr_bf16_alloc(K*N);
    HexaFarrBf16 *C = hexa_farr_bf16_alloc(M*N);
    if (!A || !B || !C) { fprintf(stderr, "alloc fail\n"); return -1; }
    hexa_farr_bf16_from_f64(hA, A, M*K);
    hexa_farr_bf16_from_f64(hB, B, K*N);
    if (hexa_farr_bf16_to_device(A) || hexa_farr_bf16_to_device(B) ||
        hexa_farr_bf16_to_device(C)) { fprintf(stderr, "H2D fail\n"); return -1; }
    if (hexa_farr_matmul_bf16_gpu(A, M, K, B, N, C)) { fprintf(stderr, "matmul fail\n"); return -1; }
    if (hexa_farr_bf16_to_host(C)) { fprintf(stderr, "D2H fail\n"); return -1; }
    hexa_farr_bf16_to_f64(C, out, M*N);
    hexa_farr_bf16_free(A); hexa_farr_bf16_free(B); hexa_farr_bf16_free(C);
    return 0;
}

int main(int argc, char** argv) {
    int sizes[] = {512, 1024, 2048};
    int nsz = 3;
    if (argc > 1) { sizes[0] = atoi(argv[1]); nsz = 1; }
    printf("=== HEXA_NO_CUBLAS forge GEMM smoke (own mma.sync BF16, ZERO cuBLAS) ===\n");
    int fail = 0;
    for (int si = 0; si < nsz; si++) {
        int64_t S = sizes[si], M=S, N=S, K=S;
        double *hA = malloc((size_t)M*K*8), *hB = malloc((size_t)K*N*8);
        double *out = malloc((size_t)M*N*8), *ref = malloc((size_t)M*N*8);
        fill(hA, M*K, 11); fill(hB, K*N, 22);
        ref_fp64(hA, hB, ref, M, N, K);
        if (run_bf16(M, K, N, hA, hB, out)) return 2;
        double rr = rel_rms(out, ref, M*N);
        int ok = (rr <= 1e-2);
        printf("[NO_CUBLAS GEMM] S=%lld  own-vs-FP64ref rel-RMS=%.3e  (gate<=1e-2: %s)\n",
               (long long)S, rr, ok ? "PASS" : "FAIL");
        if (!ok) fail = 1;
        free(hA); free(hB); free(out); free(ref);
    }
    printf("=== SMOKE %s ===\n", fail ? "FAIL" : "PASS");
    return fail;
}
