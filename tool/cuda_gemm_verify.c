/* cuda_gemm_verify.c — ing-cuda-build PRIMARY verification harness.
 *
 * Exercises the hexa runtime CUDA-routing surface (RFC 040 Phase D) via
 * the PUBLIC runtime.h API only (no internal struct access), linked
 * against the runtime objects. Built + linked TWICE on aiden:
 *   (A) CPU-only : cc cuda_gemm_verify.c runtime_cpu.o <cores>      (cuda_available()==0)
 *   (B) CUDA     : cc -DHEXA_CUDA ... runtime_cuda_rt.o runtime_cuda.o <cores> -lcublas -lcudart
 *                  (cuda_available()==1; farr_matmul M*K>8192 -> cuBLAS Dgemm)
 *
 * Captures the anima #2386 verdict: cuda_available, GEMM timing+speedup,
 * rel-RMS GPU-vs-independent-CPU-ikj correctness. Inputs: xorshift64 seed.
 */
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
#include <time.h>

#include "runtime.h"

static double now_s(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static double dval(HexaVal v) { return __hx_to_double(v); }

/* deterministic [-1,1) farr of n elements */
static HexaVal make_farr(int64_t n, uint64_t seed) {
    HexaVal h = hexa_farr_zeros(hexa_int(n));
    uint64_t x = seed;
    for (int64_t i = 0; i < n; i++) {
        x ^= x << 13; x ^= x >> 7; x ^= x << 17;
        double v = ((double)(x & 0xFFFFFFFFu) / 4294967296.0) * 2.0 - 1.0;
        hexa_farr_set(h, hexa_int(i), hexa_float(v));
    }
    return h;
}

/* independent ikj reference into a plain malloc buffer */
static void ref_gemm(HexaVal A, HexaVal B, double* C, int64_t M, int64_t K, int64_t N) {
    double* a = malloc((size_t)M * K * sizeof(double));
    double* b = malloc((size_t)K * N * sizeof(double));
    for (int64_t i = 0; i < M * K; i++) a[i] = dval(hexa_farr_get(A, hexa_int(i)));
    for (int64_t i = 0; i < K * N; i++) b[i] = dval(hexa_farr_get(B, hexa_int(i)));
    for (int64_t i = 0; i < M * N; i++) C[i] = 0.0;
    for (int64_t i = 0; i < M; i++)
        for (int64_t k = 0; k < K; k++) {
            double av = a[i * K + k];
            for (int64_t j = 0; j < N; j++)
                C[i * N + j] += av * b[k * N + j];
        }
    free(a); free(b);
}

static double rel_rms_vs(HexaVal C, const double* ref, int64_t n) {
    double num = 0.0, den = 0.0;
    for (int64_t i = 0; i < n; i++) {
        double c = dval(hexa_farr_get(C, hexa_int(i)));
        double d = c - ref[i];
        num += d * d; den += ref[i] * ref[i];
    }
    if (den == 0.0) return num == 0.0 ? 0.0 : INFINITY;
    return sqrt(num / den);
}

static void run_d(int64_t d, int reps) {
    int64_t M = d, K = d, N = d;
    HexaVal A = make_farr(M * K, 0x1234567u + (uint64_t)d);
    HexaVal B = make_farr(K * N, 0x89abcdeu + (uint64_t)d);

    HexaVal C = hexa_farr_matmul(A, hexa_int(M), hexa_int(K), B, hexa_int(N)); /* warm */
    double t0 = now_s();
    for (int r = 0; r < reps; r++)
        C = hexa_farr_matmul(A, hexa_int(M), hexa_int(K), B, hexa_int(N));
    double t1 = now_s();
    double t_per = (t1 - t0) / (double)reps;

    double* Cref = malloc((size_t)M * N * sizeof(double));
    ref_gemm(A, B, Cref, M, K, N);
    double rr = rel_rms_vs(C, Cref, M * N);
    free(Cref);

    double gflop = 2.0 * (double)M * N * K / 1e9;
#ifdef HEXA_CUDA
    const char* path = "CUDA";
#else
    const char* path = "CPU";
#endif
    printf("[d=%lld] path=%s  t=%.6f s  %.2f GFLOP/s  rel_rms_vs_ikj=%.3e\n",
           (long long)d, path, t_per, gflop / t_per, rr);
}

int main(void) {
    int avail = (int)hexa_as_num(hexa_cuda_available());
    int ndev  = (int)hexa_as_num(hexa_cuda_device_count());
#ifdef HEXA_CUDA
    printf("BUILD=CUDA   cuda_available()=%d  cuda_device_count()=%d\n", avail, ndev);
#else
    printf("BUILD=CPU    cuda_available()=%d  cuda_device_count()=%d\n", avail, ndev);
#endif
    run_d(1024, 5);
    run_d(2048, 2);
    return 0;
}
