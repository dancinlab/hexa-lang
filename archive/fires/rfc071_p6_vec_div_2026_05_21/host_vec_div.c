// RFC 071 P6 N56 — F-RFC071-E2E-VEC-DIV-NUMERIC-EQ host launcher
//
// Follow-on cycle to N50 vec_mul (commit 097451f3). Same N=1024 FP64
// shape, payload `c[i] = a[i] / b[i]`. Probes whether
// _nvptx_binop_mnemonic in compiler/codegen/nvptx_target.hexa covers
// FP64 division.
//
// Expected outcome (predicted by static read of nvptx_target.hexa
// lines 460-482 BEFORE the fire): codegen falls through to the
// "RFC 055 055-P0 - unsupported binop" stub, no `div.*.f64`
// instruction is emitted, %fd18 is declared but never written, and
// st.global.f64 reads an uninitialized register. ptxas may either:
//   (a) reject the PTX (uninitialized use), or
//   (b) JIT-compile and launch with garbage data (failing numeric eq).
// Either way F-RFC071-E2E-VEC-DIV-NUMERIC-EQ is FAIL and we get an
// honest codegen-gap diagnosis on a real binop the user actually
// writes in source.
//
// b values forced |b| > 0.01 to avoid div-by-zero in the CPU ref so
// our numeric-eq comparison can't be confused by NaN/Inf semantics.
//
// Build:  gcc host_vec_div.c -o /tmp/host_vec_div -lcuda
// Run:    /tmp/host_vec_div
// Output: JSON {status,max_abs_diff,max_ulp,byte_mismatch,...} on stdout.

#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

#define N 1024
#define PTX_PATH "/tmp/rfc071_n56_vec_div.ptx"

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
    // Both same sign? Direct diff.
    int64_t sa = (int64_t)ua.u;
    int64_t sb = (int64_t)ub.u;
    if ((sa < 0) != (sb < 0)) {
        // Across zero — count both halves.
        // Map sign-magnitude to twos-complement-ish ordering.
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
        // emit single-line JSON with err-log truncated
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
    if (check(cuModuleGetFunction(&fn, mod, "vec_div"), "cuModuleGetFunction")) {
        printf("{\"status\":\"FAIL\",\"phase\":\"get_function\"}\n");
        return 31;
    }

    // Allocate host + device buffers
    double *ha = (double*)malloc(N * sizeof(double));
    double *hb = (double*)malloc(N * sizeof(double));
    double *hc = (double*)malloc(N * sizeof(double));
    double *href = (double*)malloc(N * sizeof(double));
    // Deterministic LCG fill — same seed as N34/N50.
    uint64_t s = 0x0123456789abcdefULL;
    for (int i = 0; i < N; i++) {
        s = s * 6364136223846793005ULL + 1442695040888963407ULL;
        union { uint64_t u; double d; } ua;
        ua.u = (s >> 12) | 0x3ff0000000000000ULL;  // [1, 2)
        ha[i] = ua.d;
        s = s * 6364136223846793005ULL + 1442695040888963407ULL;
        union { uint64_t u; double d; } ub;
        ub.u = (s >> 12) | 0x3ff0000000000000ULL;  // [1, 2)
        hb[i] = ub.d;
        // b is already in [1, 2) so |b| > 0.01 trivially; no div-by-0
        // risk. Numerator a also in [1, 2) so quotient in (0.5, 2).
        href[i] = ha[i] / hb[i];   // <-- div, not mul
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
    uint64_t max_ulp = 0;
    int bm = 0;
    int firstmis = -1;
    for (int i = 0; i < N; i++) {
        double d = fabs(hc[i] - href[i]);
        if (d > max_abs) max_abs = d;
        uint64_t u = ulp_dist(hc[i], href[i]);
        if (u > max_ulp) max_ulp = u;
        union { double d; uint64_t u; } a, b;
        a.d = hc[i]; b.d = href[i];
        if (a.u != b.u) { bm++; if (firstmis < 0) firstmis = i; }
    }
    // Status semantics:
    //   PASS_BYTEEQ     bm == 0                        (IEEE div.rn.f64)
    //   PASS_LOW_ULP    bm > 0, max_ulp <= 4           (div.approx.f64 fast)
    //   FAIL            otherwise                      (codegen gap / wrong op)
    const char *status;
    if (bm == 0)          status = "PASS_BYTEEQ";
    else if (max_ulp <= 4) status = "PASS_LOW_ULP";
    else                  status = "FAIL";
    printf("{\"status\":\"%s\",\"max_abs_diff\":%.17g,\"max_ulp\":%llu,\"byte_mismatch\":%d,\"N\":%d,\"first_mis\":%d,\"c[0]\":%.17g,\"ref[0]\":%.17g,\"a[0]\":%.17g,\"b[0]\":%.17g}\n",
           status, max_abs, (unsigned long long)max_ulp, bm, N, firstmis, hc[0], href[0], ha[0], hb[0]);
    return (bm == 0) ? 0 : (max_ulp <= 4 ? 0 : 1);
}
