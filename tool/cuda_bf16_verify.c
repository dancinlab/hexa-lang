/* cuda_bf16_verify.c — r3-cublas-independence r2 BF16 own-GEMM production smoke.
 *
 * Exercises the production BF16 matmul entry point hexa_farr_matmul_bf16_gpu
 * (runtime_bf16.c, #include'd into runtime_cuda.c) in BOTH modes:
 *   default (HEXA_BF16_OWN unset/=1) -> own mma.sync m16n8k16 kernel (no cuBLAS)
 *   HEXA_BF16_OWN=0                  -> cublasGemmEx BF16 (opt-out escape hatch)
 *
 * Reports, per size S (square M=N=K):
 *   - own vs FP64-ref rel-RMS, cuBLAS vs FP64-ref rel-RMS  (both <=1e-2 gate)
 *   - own vs cuBLAS-BF16 rel-RMS  (the campaign gate: same-dtype agreement <=1e-2)
 *   - own ms, cuBLAS ms, speed ratio (cuBLAS/own)
 *
 * The [BF16-OWN-FIRED] marker on stderr confirms the own path fired by default.
 *
 * Build (on aiden, sm_120): linked against runtime_cuda objects + cuBLAS.
 *   The BF16 C API is extern "C" in runtime_bf16.c.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <time.h>

/* Mirror the runtime_bf16.c public ABI (extern "C"). */
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

static double now_s(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static void fill(double* x, int64_t n, uint64_t seed) {
    uint64_t s = seed;
    for (int64_t i = 0; i < n; i++) {
        s ^= s << 13; s ^= s >> 7; s ^= s << 17;
        x[i] = (((double)(s & 0xFFFFu) / 65535.0) - 0.5) * 0.2; /* match owngemm fill scale */
    }
}

/* RNE round f64->bf16->f64 so the reference uses the SAME truncated operands as
 * the device (the device upcasts bf16 storage to fp32; bf16 mantissa = 7 bits). */
static double bf16_round(double v) {
    float f = (float)v;
    uint32_t bits; memcpy(&bits, &f, 4);
    if (((bits >> 23) & 0xFF) == 0xFF && (bits & 0x7FFFFF) != 0) { /* nan */ return v; }
    uint32_t lsb = (bits >> 16) & 1u;
    uint32_t bias = 0x7FFFu + lsb;
    uint16_t bf = (uint16_t)((bits + bias) >> 16);
    uint32_t wide = (uint32_t)bf << 16;
    float r; memcpy(&r, &wide, 4);
    return (double)r;
}

/* FP64 reference of bf16-rounded inputs: C = A@B (double accum). */
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

/* Run one BF16 matmul through the production entry point; out[] = f64 of the
 * BF16 result. iters>0 also times it (returns ms/iter via *ms). */
static int run_bf16(int64_t M, int64_t K, int64_t N,
                    const double* hA, const double* hB,
                    double* out, int iters, double* ms) {
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
    if (iters > 0 && ms) {
        double t0 = now_s();
        for (int it = 0; it < iters; it++) hexa_farr_matmul_bf16_gpu(A, M, K, B, N, C);
        *ms = (now_s() - t0) / iters * 1e3;
    }
    hexa_farr_bf16_free(A); hexa_farr_bf16_free(B); hexa_farr_bf16_free(C);
    return 0;
}

int main(int argc, char** argv) {
    int sizes[] = {512, 1024, 2048};
    int nsz = 3;
    if (argc > 1) { sizes[0] = atoi(argv[1]); nsz = 1; }
    /* Are we the own run or the cuBLAS run? read the env we ourselves see. */
    const char* ow = getenv("HEXA_BF16_OWN");
    int own_mode = !(ow && ow[0]=='0');
    printf("=== BF16 production matmul (%s) ===\n", own_mode ? "OWN default" : "cuBLAS HEXA_BF16_OWN=0");
    for (int si = 0; si < nsz; si++) {
        int64_t S = sizes[si], M=S, N=S, K=S;
        double *hA = malloc((size_t)M*K*8), *hB = malloc((size_t)K*N*8);
        double *out = malloc((size_t)M*N*8), *ref = malloc((size_t)M*N*8);
        fill(hA, M*K, 11); fill(hB, K*N, 22);
        ref_fp64(hA, hB, ref, M, N, K);
        double ms = 0;
        if (run_bf16(M, K, N, hA, hB, out, 30, &ms)) return 2;
        double rr = rel_rms(out, ref, M*N);
        double flops = 2.0*(double)M*N*K, tflops = flops/(ms*1e-3)/1e12;
        printf("[BF16 %s] S=%lld vs FP64-ref rel-RMS=%.3e  %.4f ms  %.2f TFLOP/s\n",
               own_mode?"OWN":"CUB", (long long)S, rr, ms, tflops);
        /* dump the f64 result so the two-run wrapper can compare own-vs-cuBLAS. */
        char path[256];
        snprintf(path, sizeof(path), "/tmp/bf16_%s_%lld.bin", own_mode?"own":"cub", (long long)S);
        FILE* f = fopen(path, "wb"); if (f) { fwrite(out, 8, (size_t)M*N, f); fclose(f); }
        free(hA); free(hB); free(out); free(ref);
    }
    return 0;
}
