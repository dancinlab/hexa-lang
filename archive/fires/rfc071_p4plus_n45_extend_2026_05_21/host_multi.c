// RFC 071 P5 N55 — F-RFC071-E2E-MULTI-KERNEL-NUMERIC-EQ host launcher
//
// Multi-kernel-per-file generalisation of N34 (vec_add) + N50 (vec_mul).
// Loads /tmp/rfc071_n55_multi_kernel.ptx ONCE via cuModuleLoadDataEx
// (one module, two .visible .entry directives), then resolves BOTH
// `vec_add` and `vec_mul` via cuModuleGetFunction and fires each in
// turn against the SAME LCG-derived inputs A + B. CPU reference is
// computed in `double` (IEEE 754 binary64); both ops are bit-exact
// (add+mul are correctly-rounded single ops, no FMA contraction risk).
//
// Build: gcc host_multi.c -o /tmp/host_multi -lcuda
// Run:   /tmp/host_multi
// Output: JSON single line with per-kernel PASS/FAIL + max_abs_diff
//         + byte_mismatch counts + first-mismatch indices.

#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

#define N 1024
#define PTX_PATH "/tmp/rfc071_n55_multi_kernel.ptx"

static int check(CUresult r, const char *what) {
    if (r == CUDA_SUCCESS) return 0;
    const char *name = NULL, *str = NULL;
    cuGetErrorName(r, &name);
    cuGetErrorString(r, &str);
    fprintf(stderr, "CUDA error in %s: %s (%s)\n", what, name ? name : "?", str ? str : "?");
    return 1;
}

// Returns 0 on PASS, sets *out_max_abs / *out_bm / *out_firstmis.
static int fire_kernel(CUfunction fn, const char *label,
                       double *ha, double *hb, double *href,
                       double *out_max_abs, int *out_bm, int *out_firstmis,
                       double *out_c0) {
    double *hc = (double*)malloc(N * sizeof(double));
    for (int i = 0; i < N; i++) hc[i] = -1.0;

    CUdeviceptr da, db, dc;
    if (check(cuMemAlloc(&da, N * sizeof(double)), "alloc a")) return 40;
    if (check(cuMemAlloc(&db, N * sizeof(double)), "alloc b")) return 41;
    if (check(cuMemAlloc(&dc, N * sizeof(double)), "alloc c")) return 42;
    if (check(cuMemcpyHtoD(da, ha, N * sizeof(double)), "H2D a")) return 43;
    if (check(cuMemcpyHtoD(db, hb, N * sizeof(double)), "H2D b")) return 44;
    if (check(cuMemsetD8(dc, 0xee, N * sizeof(double)), "memset c")) return 45;

    int64_t n = N;
    void *args[] = { &da, &db, &dc, &n };
    CUresult r = cuLaunchKernel(fn, 1,1,1, 1024,1,1, 0, NULL, args, NULL);
    if (r != CUDA_SUCCESS) {
        const char *nm = NULL, *ss = NULL;
        cuGetErrorName(r, &nm); cuGetErrorString(r, &ss);
        fprintf(stderr, "%s cuLaunchKernel FAILED: %s (%s)\n", label, nm, ss);
        return 50;
    }
    r = cuCtxSynchronize();
    if (r != CUDA_SUCCESS) {
        const char *nm = NULL, *ss = NULL;
        cuGetErrorName(r, &nm); cuGetErrorString(r, &ss);
        fprintf(stderr, "%s cuCtxSynchronize FAILED: %s (%s)\n", label, nm, ss);
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
    *out_max_abs  = max_abs;
    *out_bm       = bm;
    *out_firstmis = firstmis;
    *out_c0       = hc[0];

    cuMemFree(da); cuMemFree(db); cuMemFree(dc);
    free(hc);
    return (bm == 0) ? 0 : 1;
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

    // JIT-load PTX with verbose log — ONE module, BOTH entries.
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

    CUfunction fn_add, fn_mul;
    if (check(cuModuleGetFunction(&fn_add, mod, "vec_add"), "cuModuleGetFunction vec_add")) {
        printf("{\"status\":\"FAIL\",\"phase\":\"get_function\",\"missing\":\"vec_add\"}\n");
        return 31;
    }
    if (check(cuModuleGetFunction(&fn_mul, mod, "vec_mul"), "cuModuleGetFunction vec_mul")) {
        printf("{\"status\":\"FAIL\",\"phase\":\"get_function\",\"missing\":\"vec_mul\"}\n");
        return 32;
    }
    fprintf(stderr, "resolved both entries: vec_add + vec_mul\n");

    // Shared inputs — both kernels see the same A+B (deterministic LCG,
    // same seed as N34/N50 so cross-fixture cross-check works).
    double *ha       = (double*)malloc(N * sizeof(double));
    double *hb       = (double*)malloc(N * sizeof(double));
    double *href_add = (double*)malloc(N * sizeof(double));
    double *href_mul = (double*)malloc(N * sizeof(double));
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
        href_add[i] = ha[i] + hb[i];   // vec_add ref
        href_mul[i] = ha[i] * hb[i];   // vec_mul ref
    }

    // Fire vec_add
    double add_max_abs = 0.0, add_c0 = 0.0;
    int add_bm = 0, add_firstmis = -1;
    int add_rc = fire_kernel(fn_add, "vec_add", ha, hb, href_add,
                             &add_max_abs, &add_bm, &add_firstmis, &add_c0);
    fprintf(stderr, "vec_add: max_abs=%g bm=%d firstmis=%d c[0]=%.17g ref[0]=%.17g\n",
            add_max_abs, add_bm, add_firstmis, add_c0, href_add[0]);

    // Fire vec_mul
    double mul_max_abs = 0.0, mul_c0 = 0.0;
    int mul_bm = 0, mul_firstmis = -1;
    int mul_rc = fire_kernel(fn_mul, "vec_mul", ha, hb, href_mul,
                             &mul_max_abs, &mul_bm, &mul_firstmis, &mul_c0);
    fprintf(stderr, "vec_mul: max_abs=%g bm=%d firstmis=%d c[0]=%.17g ref[0]=%.17g\n",
            mul_max_abs, mul_bm, mul_firstmis, mul_c0, href_mul[0]);

    int add_pass = (add_rc == 0);
    int mul_pass = (mul_rc == 0);
    int overall_pass = add_pass && mul_pass;

    printf("{\"status\":\"%s\","
           "\"vec_add\":{\"status\":\"%s\",\"max_abs_diff\":%.17g,\"byte_mismatch\":%d,\"first_mis\":%d,\"c0\":%.17g,\"ref0\":%.17g},"
           "\"vec_mul\":{\"status\":\"%s\",\"max_abs_diff\":%.17g,\"byte_mismatch\":%d,\"first_mis\":%d,\"c0\":%.17g,\"ref0\":%.17g},"
           "\"N\":%d,\"a0\":%.17g,\"b0\":%.17g}\n",
           overall_pass ? "PASS" : "FAIL",
           add_pass ? "PASS" : "FAIL", add_max_abs, add_bm, add_firstmis, add_c0, href_add[0],
           mul_pass ? "PASS" : "FAIL", mul_max_abs, mul_bm, mul_firstmis, mul_c0, href_mul[0],
           N, ha[0], hb[0]);
    return overall_pass ? 0 : 1;
}
