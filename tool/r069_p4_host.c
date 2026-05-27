/* RFC 069 P4 -- unroll=1 vs unroll=2 silicon byte-eq fire.
 *
 * Fires both vec_add_unroll1.ptx and vec_add_unroll2.ptx on the same
 * inputs, compares output buffers byte-for-byte. F-RFC069-NUMERIC-EQ
 * PASS = byte-eq (unroll is a perf transform on element-independent
 * kernels; output MUST match the no-unroll baseline).
 *
 * Build:  nvcc -O2 -o r069_p4_host r069_p4_host.c -lcuda
 * Run:    ./r069_p4_host vec_add_unroll1.ptx vec_add_unroll2.ptx
 */
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define CHECK(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA error %d at %s:%d: %s\n", e, __FILE__, __LINE__, s ? s : "?"); \
        return 1; }} while (0)

static char *slurp(const char *path, long *n_out) {
    FILE *fp = fopen(path, "rb");
    if (!fp) { perror(path); return NULL; }
    fseek(fp, 0, SEEK_END);
    long n = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *buf = (char *)malloc(n + 1);
    fread(buf, 1, n, fp);
    buf[n] = 0;
    fclose(fp);
    if (n_out) *n_out = n;
    return buf;
}

static int fire_kernel(const char *ptx, const char *kname, int N,
                       double *ha, double *hb, double *hc,
                       int block_factor) {
    CUmodule mod;
    CUjit_option jit_opts[1] = { CU_JIT_TARGET_FROM_CUCONTEXT };
    void *jit_vals[1] = { (void *)0 };
    CHECK(cuModuleLoadDataEx(&mod, ptx, 1, jit_opts, jit_vals));

    CUfunction f;
    CHECK(cuModuleGetFunction(&f, mod, kname));

    CUdeviceptr da, db, dc;
    CHECK(cuMemAlloc(&da, N * sizeof(double)));
    CHECK(cuMemAlloc(&db, N * sizeof(double)));
    CHECK(cuMemAlloc(&dc, N * sizeof(double)));
    CHECK(cuMemcpyHtoD(da, ha, N * sizeof(double)));
    CHECK(cuMemcpyHtoD(db, hb, N * sizeof(double)));

    unsigned long long n_arg = (unsigned long long)N;
    void *kargs[4] = { &da, &db, &dc, &n_arg };
    const int block = 128;
    /* block_factor=1: each thread processes 1 element; grid = ceil(N/128)
       block_factor=2: each thread processes 2 elements; grid = ceil(N/256) */
    const int per_block = block * block_factor;
    const int grid = (N + per_block - 1) / per_block;
    CHECK(cuLaunchKernel(f, grid, 1, 1, block, 1, 1, 0, NULL, kargs, NULL));
    CHECK(cuCtxSynchronize());
    CHECK(cuMemcpyDtoH(hc, dc, N * sizeof(double)));

    cuMemFree(da); cuMemFree(db); cuMemFree(dc);
    cuModuleUnload(mod);
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s unroll1.ptx unroll2.ptx\n", argv[0]); return 2; }

    long n_p1, n_p2;
    char *ptx1 = slurp(argv[1], &n_p1);
    char *ptx2 = slurp(argv[2], &n_p2);
    if (!ptx1 || !ptx2) return 1;

    CHECK(cuInit(0));
    CUdevice  dev;     CHECK(cuDeviceGet(&dev, 0));
    CUcontext ctx;     CHECK(cuCtxCreate(&ctx, 0, dev));

    const int N = 1024;
    double *ha = (double *)malloc(N * sizeof(double));
    double *hb = (double *)malloc(N * sizeof(double));
    double *hc1 = (double *)malloc(N * sizeof(double));
    double *hc2 = (double *)malloc(N * sizeof(double));

    /* Inputs in a clean range. */
    for (int i = 0; i < N; ++i) {
        ha[i] = (double)(i % 64) * 0.5;
        hb[i] = (double)(i % 32) * 0.25;
    }

    if (fire_kernel(ptx1, "vec_add_unroll1", N, ha, hb, hc1, 1) != 0) return 1;
    if (fire_kernel(ptx2, "vec_add_unroll2", N, ha, hb, hc2, 2) != 0) return 1;

    /* Compare hc1 vs hc2 — byte-equal expected. */
    int byte_mismatch = memcmp(hc1, hc2, N * sizeof(double));
    int elem_mismatches = 0;
    double max_delta = 0.0;
    for (int i = 0; i < N; ++i) {
        double d = fabs(hc1[i] - hc2[i]);
        if (d > max_delta) max_delta = d;
        if (d != 0.0) ++elem_mismatches;
    }

    const char *verd = (byte_mismatch == 0 && elem_mismatches == 0) ? "PASS" : "FAIL";
    printf("F-RFC069-NUMERIC-EQ %s -- N=%d byte_mismatch=%d elem_mismatches=%d max|d|=%g\n",
        verd, N, byte_mismatch, elem_mismatches, max_delta);

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"069-P4\",\n");
    fprintf(rj, "  \"kernels\": [\"vec_add_unroll1\", \"vec_add_unroll2\"],\n");
    fprintf(rj, "  \"falsifier\": \"F-RFC069-NUMERIC-EQ\",\n");
    fprintf(rj, "  \"verdict\": \"%s\",\n", verd);
    fprintf(rj, "  \"n\": %d,\n", N);
    fprintf(rj, "  \"byte_mismatch\": %d,\n", byte_mismatch);
    fprintf(rj, "  \"elem_mismatches\": %d,\n", elem_mismatches);
    fprintf(rj, "  \"max_delta\": %g\n", max_delta);
    fprintf(rj, "}\n");
    fclose(rj);

    cuCtxDestroy(ctx);
    return (byte_mismatch == 0 && elem_mismatches == 0) ? 0 : 1;
}
