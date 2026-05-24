// RFC 071 P7 N59 — F-RFC071-E2E-REDUCE-SUM-SINGLE-THREAD-NUMERIC-EQ host launcher
//
// Follow-on cycle to N50 vec_mul (`097451f3`) + N56 vec_div. First
// NON-element-wise kernel — single-thread sum reduction. Kernel launched
// 1x1 grid, 1x1x1 block (one thread accumulates all N values).
//
// Host:
//   - Alloc FP64 input a[N], FP64 output out[1]
//   - Fill a[] deterministic LCG, mirror seed of N50/N56 ([1, 2))
//   - CPU reference: ref_sum = a[0] + a[1] + ... + a[N-1] (sequential)
//   - Launch reduce_sum<1,1,1><1,1,1>(a, out, N)
//   - Compare out[0] vs ref_sum (byte-eq if accumulation order matches,
//     else <= 4 ULP)
//
// Build:  gcc host_reduce_sum.c -o /tmp/host_reduce_sum -lcuda
// Run:    /tmp/host_reduce_sum
// Output: JSON {status,max_abs_diff,max_ulp,byte_mismatch,...} on stdout.

#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

#define N 1024
#define PTX_PATH "/tmp/rfc071_n59_reduce_sum.ptx"

static int check(CUresult r, const char *what) {
    if (r == CUDA_SUCCESS) return 0;
    const char *name = NULL, *str = NULL;
    cuGetErrorName(r, &name);
    cuGetErrorString(r, &str);
    fprintf(stderr, "CUDA error in %s: %s (%s)\n", what, name ? name : "?", str ? str : "?");
    return 1;
}

static uint64_t ulp_dist(double a, double b) {
    union { double d; uint64_t u; } ua, ub;
    ua.d = a; ub.d = b;
    if (ua.u == ub.u) return 0;
    int64_t sa = (int64_t)ua.u;
    int64_t sb = (int64_t)ub.u;
    if ((sa < 0) != (sb < 0)) {
        if (sa < 0) sa = (int64_t)(0x8000000000000000ULL - (uint64_t)sa);
        if (sb < 0) sb = (int64_t)(0x8000000000000000ULL - (uint64_t)sb);
    }
    int64_t d = sa - sb;
    if (d < 0) d = -d;
    return (uint64_t)d;
}

int main(void) {
    if (check(cuInit(0), "cuInit")) return 10;
    CUdevice dev;
    if (check(cuDeviceGet(&dev, 0), "cuDeviceGet")) return 11;
    CUcontext ctx;
    if (check(cuCtxCreate(&ctx, 0, dev), "cuCtxCreate")) return 12;

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
        char ebuf[4096]; int ei = 0;
        for (int k = 0; k < (int)sizeof(jit_err) && jit_err[k] && ei < (int)sizeof(ebuf)-1; k++) {
            char c = jit_err[k];
            if (c == '"' || c == '\\') { if (ei < (int)sizeof(ebuf)-2) { ebuf[ei++] = '\\'; ebuf[ei++] = c; } }
            else if (c == '\n') { if (ei < (int)sizeof(ebuf)-2) { ebuf[ei++] = '\\'; ebuf[ei++] = 'n'; } }
            else if (c >= 32 && c < 127) ebuf[ei++] = c;
        }
        ebuf[ei] = 0;
        printf("{\"status\":\"FAIL\",\"phase\":\"jit_load\",\"jit_err\":\"%s\"}\n", ebuf);
        return 30;
    }
    fprintf(stderr, "JIT info: %s\n", jit_info);

    CUfunction fn;
    if (check(cuModuleGetFunction(&fn, mod, "reduce_sum"), "cuModuleGetFunction")) {
        printf("{\"status\":\"FAIL\",\"phase\":\"get_function\"}\n");
        return 31;
    }

    double *ha = (double*)malloc(N * sizeof(double));
    double hout[1] = {-1.0};
    // Deterministic LCG fill — same seed/encoding as N34/N50/N56.
    uint64_t s = 0x0123456789abcdefULL;
    double ref_sum = 0.0;
    for (int i = 0; i < N; i++) {
        s = s * 6364136223846793005ULL + 1442695040888963407ULL;
        union { uint64_t u; double d; } ua;
        ua.u = (s >> 12) | 0x3ff0000000000000ULL;  // [1, 2)
        ha[i] = ua.d;
        ref_sum = ref_sum + ha[i];   // sequential FP64 accumulation
    }

    CUdeviceptr da, dout;
    if (check(cuMemAlloc(&da, N * sizeof(double)), "alloc a")) return 40;
    if (check(cuMemAlloc(&dout, 1 * sizeof(double)), "alloc out")) return 41;
    if (check(cuMemcpyHtoD(da, ha, N * sizeof(double)), "H2D a")) return 43;
    if (check(cuMemsetD8(dout, 0xee, 1 * sizeof(double)), "memset out")) return 45;

    int64_t n = N;
    void *args[] = { &da, &dout, &n };
    // Single thread reduce — 1x1 grid, 1x1x1 block.
    r = cuLaunchKernel(fn, 1,1,1, 1,1,1, 0, NULL, args, NULL);
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
    if (check(cuMemcpyDtoH(hout, dout, 1 * sizeof(double)), "D2H out")) return 52;

    double d = fabs(hout[0] - ref_sum);
    uint64_t u = ulp_dist(hout[0], ref_sum);
    union { double d; uint64_t u; } ahx, bhx;
    ahx.d = hout[0]; bhx.d = ref_sum;
    int bm = (ahx.u != bhx.u) ? 1 : 0;

    const char *status;
    if (bm == 0)            status = "PASS_BYTEEQ";
    else if (u <= 4)        status = "PASS_LOW_ULP";
    else                    status = "FAIL";
    printf("{\"status\":\"%s\",\"max_abs_diff\":%.17g,\"max_ulp\":%llu,\"byte_mismatch\":%d,\"N\":%d,\"out[0]\":%.17g,\"ref_sum\":%.17g,\"a[0]\":%.17g}\n",
           status, d, (unsigned long long)u, bm, N, hout[0], ref_sum, ha[0]);
    return (bm == 0) ? 0 : (u <= 4 ? 0 : 1);
}
