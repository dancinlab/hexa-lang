// RFC 071 P4 — F-RFC071-E2E-NUMERIC-EQ host launcher
//
// Loads /tmp/rfc071_e2e_my_test_kernel.ptx via cuModuleLoadDataEx
// (driver-JIT, sm_120 forward-compat from sm_80 PTX per
// `reference_gpu_fire_infra`), launches `my_test_kernel` with
// 1 block × 1024 threads, FP64 a + b -> c, compares to CPU ref.
//
// Build: gcc rfc071_e2e_host.c -o /tmp/rfc071_e2e -lcuda
// Run:   /tmp/rfc071_e2e
// Output: JSON-ish single line with PASS/FAIL + max_abs_diff +
//         byte_mismatch count + JIT log on failure.

#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

#define N 1024
#define PTX_PATH "/tmp/rfc071_e2e_my_test_kernel.ptx"

static int check(CUresult r, const char *what) {
    if (r == CUDA_SUCCESS) return 0;
    const char *name = NULL, *str = NULL;
    cuGetErrorName(r, &name);
    cuGetErrorString(r, &str);
    fprintf(stderr, "CUDA error in %s: %s (%s)\n", what, name ? name : "?", str ? str : "?");
    return 1;
}

int main(void) {
    if (check(cuInit(0), "cuInit")) return 10;
    CUdevice dev;
    if (check(cuDeviceGet(&dev, 0), "cuDeviceGet")) return 11;
    CUcontext ctx;
    if (check(cuCtxCreate(&ctx, 0, dev), "cuCtxCreate")) return 12;

    // Read PTX file
    FILE *fp = fopen(PTX_PATH, "rb");
    if (!fp) { fprintf(stderr, "cannot open %s\n", PTX_PATH); return 20; }
    fseek(fp, 0, SEEK_END);
    long ptx_sz = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *ptx = (char*)malloc(ptx_sz + 1);
    fread(ptx, 1, ptx_sz, fp);
    ptx[ptx_sz] = 0;
    fclose(fp);
    fprintf(stderr, "loaded PTX %ld bytes\n", ptx_sz);

    // JIT-load PTX with verbose log
    char jit_info[8192] = {0};
    char jit_err[8192]  = {0};
    CUjit_option opts[] = {
        CU_JIT_INFO_LOG_BUFFER,
        CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_ERROR_LOG_BUFFER,
        CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_LOG_VERBOSE
    };
    void *vals[] = {
        jit_info,
        (void*)(uintptr_t)sizeof(jit_info),
        jit_err,
        (void*)(uintptr_t)sizeof(jit_err),
        (void*)(uintptr_t)1
    };
    CUmodule mod;
    CUresult r = cuModuleLoadDataEx(&mod, ptx, 5, opts, vals);
    if (r != CUDA_SUCCESS) {
        fprintf(stderr, "cuModuleLoadDataEx FAILED\n");
        fprintf(stderr, "JIT info log: %s\n", jit_info);
        fprintf(stderr, "JIT err  log: %s\n", jit_err);
        printf("{\"status\":\"FAIL\",\"phase\":\"jit_load\",\"jit_err\":\"%s\"}\n", jit_err);
        return 30;
    }
    fprintf(stderr, "JIT info: %s\n", jit_info);

    CUfunction fn;
    if (check(cuModuleGetFunction(&fn, mod, "my_test_kernel"), "cuModuleGetFunction")) {
        printf("{\"status\":\"FAIL\",\"phase\":\"get_function\"}\n");
        return 31;
    }

    // Allocate host + device buffers
    double *ha = (double*)malloc(N * sizeof(double));
    double *hb = (double*)malloc(N * sizeof(double));
    double *hc = (double*)malloc(N * sizeof(double));
    double *href = (double*)malloc(N * sizeof(double));
    // Deterministic LCG fill
    uint64_t s = 0x0123456789abcdefULL;
    for (int i = 0; i < N; i++) {
        s = s * 6364136223846793005ULL + 1442695040888963407ULL;
        union { uint64_t u; double d; } ua;
        ua.u = (s >> 12) | 0x3ff0000000000000ULL;  // [1, 2)
        ha[i] = ua.d;
        s = s * 6364136223846793005ULL + 1442695040888963407ULL;
        union { uint64_t u; double d; } ub;
        ub.u = (s >> 12) | 0x3ff0000000000000ULL;
        hb[i] = ub.d;
        href[i] = ha[i] + hb[i];
        hc[i] = -1.0;  // sentinel
    }

    CUdeviceptr da, db, dc;
    if (check(cuMemAlloc(&da, N * sizeof(double)), "alloc a")) return 40;
    if (check(cuMemAlloc(&db, N * sizeof(double)), "alloc b")) return 41;
    if (check(cuMemAlloc(&dc, N * sizeof(double)), "alloc c")) return 42;
    if (check(cuMemcpyHtoD(da, ha, N * sizeof(double)), "H2D a")) return 43;
    if (check(cuMemcpyHtoD(db, hb, N * sizeof(double)), "H2D b")) return 44;
    if (check(cuMemsetD8(dc, 0xee, N * sizeof(double)), "memset c")) return 45;

    int64_t n = N;
    void *args[] = { &da, &db, &dc, &n };
    r = cuLaunchKernel(fn, 1,1,1, 1024,1,1, 0, NULL, args, NULL);
    if (r != CUDA_SUCCESS) {
        const char *nm = NULL, *ss = NULL;
        cuGetErrorName(r, &nm); cuGetErrorString(r, &ss);
        fprintf(stderr, "cuLaunchKernel FAILED: %s (%s)\n", nm, ss);
        printf("{\"status\":\"FAIL\",\"phase\":\"launch\",\"err\":\"%s\"}\n", nm);
        return 50;
    }
    r = cuCtxSynchronize();
    if (r != CUDA_SUCCESS) {
        const char *nm = NULL, *ss = NULL;
        cuGetErrorName(r, &nm); cuGetErrorString(r, &ss);
        fprintf(stderr, "cuCtxSynchronize FAILED: %s (%s)\n", nm, ss);
        printf("{\"status\":\"FAIL\",\"phase\":\"sync\",\"err\":\"%s\"}\n", nm);
        return 51;
    }
    if (check(cuMemcpyDtoH(hc, dc, N * sizeof(double)), "D2H c")) return 52;

    double max_abs = 0.0;
    int bm = 0;
    int firstmis = -1;
    for (int i = 0; i < N; i++) {
        double d = fabs(hc[i] - href[i]);
        if (d > max_abs) max_abs = d;
        union { double d; uint64_t u; } a, b;
        a.d = hc[i]; b.d = href[i];
        if (a.u != b.u) { bm++; if (firstmis < 0) firstmis = i; }
    }
    int pass = (bm == 0);
    printf("{\"status\":\"%s\",\"max_abs_diff\":%.17g,\"byte_mismatch\":%d,\"N\":%d,\"first_mis\":%d,\"c[0]\":%.17g,\"ref[0]\":%.17g}\n",
           pass ? "PASS" : "FAIL", max_abs, bm, N, firstmis, hc[0], href[0]);
    return pass ? 0 : 1;
}
