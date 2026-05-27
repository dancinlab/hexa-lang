/* RFC 067 P4 cp.async pipelined WMMA -- silicon fire host.
 *
 * Mirrors r067_p4_multitile_host.c but adds CUevent timing on the kernel
 * launch and emits a perf comparison field. Inputs/outputs are
 * byte-identical with PR #205 so max|d|=0 is the numeric falsifier gate.
 *
 * Build:  nvcc -O2 -arch=sm_90 -o r067_p4_cp_async_host r067_p4_cp_async_host.c -lcuda
 * Run:    ./r067_p4_cp_async_host wmma_cp_async.ptx [baseline_ptx]
 *
 * If a second argument is given, it is interpreted as the PR #205
 * baseline PTX file -- the host loads BOTH, runs each with identical
 * inputs, and reports both numeric delta (vs CPU FP32 reference) AND
 * timing delta (cp.async vs baseline). Without the second arg, only
 * the cp.async kernel is timed and compared against CPU reference.
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

static uint16_t f32_to_f16(float f) {
    uint32_t x; memcpy(&x, &f, 4);
    uint32_t sign  = (x >> 16) & 0x8000;
    int32_t  exp   = ((x >> 23) & 0xff) - 127 + 15;
    uint32_t mant  =  x & 0x7fffff;
    if (exp <= 0)        return (uint16_t)sign;
    if (exp >= 31)       return (uint16_t)(sign | 0x7c00);
    return (uint16_t)(sign | (exp << 10) | (mant >> 13));
}
static float f16_to_f32(uint16_t h) {
    uint32_t sign  = (h & 0x8000) << 16;
    uint32_t exp   = (h & 0x7c00) >> 10;
    uint32_t mant  =  h & 0x3ff;
    uint32_t f;
    if (exp == 0)        { f = sign; }
    else if (exp == 31)  { f = sign | 0x7f800000 | (mant << 13); }
    else                 { f = sign | ((exp - 15 + 127) << 23) | (mant << 13); }
    float out; memcpy(&out, &f, 4);
    return out;
}

static char *read_ptx(const char *path) {
    FILE *fp = fopen(path, "rb");
    if (!fp) { perror(path); return NULL; }
    fseek(fp, 0, SEEK_END);
    long n = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *buf = (char *)malloc(n + 1);
    fread(buf, 1, n, fp);
    buf[n] = 0;
    fclose(fp);
    return buf;
}

/* Returns mean ms across NREP reps after WARMUP warmups. */
static float time_kernel(CUfunction f, void **kargs, int blocks, int threads, int warmup, int nrep) {
    CUevent t0, t1;
    cuEventCreate(&t0, 0);
    cuEventCreate(&t1, 0);
    for (int i = 0; i < warmup; ++i) {
        cuLaunchKernel(f, blocks, 1, 1, threads, 1, 1, 0, NULL, kargs, NULL);
    }
    cuCtxSynchronize();
    float total_ms = 0.0f;
    for (int i = 0; i < nrep; ++i) {
        cuEventRecord(t0, 0);
        cuLaunchKernel(f, blocks, 1, 1, threads, 1, 1, 0, NULL, kargs, NULL);
        cuEventRecord(t1, 0);
        cuEventSynchronize(t1);
        float ms = 0.0f;
        cuEventElapsedTime(&ms, t0, t1);
        total_ms += ms;
    }
    cuEventDestroy(t0);
    cuEventDestroy(t1);
    return total_ms / (float)nrep;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s wmma_cp_async.ptx [baseline_ptx]\n", argv[0]);
        return 2;
    }
    const char *ptx_path   = argv[1];
    const char *base_path  = (argc >= 3) ? argv[2] : NULL;

    char *ptx_cpa = read_ptx(ptx_path);
    if (!ptx_cpa) return 1;
    char *ptx_base = base_path ? read_ptx(base_path) : NULL;
    if (base_path && !ptx_base) return 1;

    CHECK(cuInit(0));
    CUdevice dev;     CHECK(cuDeviceGet(&dev, 0));
    CUcontext ctx;    CHECK(cuCtxCreate(&ctx, 0, dev));

    CUmodule mod_cpa;
    CUjit_option jit_opts[1] = { CU_JIT_TARGET_FROM_CUCONTEXT };
    void *jit_vals[1] = { (void *)0 };
    CHECK(cuModuleLoadDataEx(&mod_cpa, ptx_cpa, 1, jit_opts, jit_vals));

    CUmodule mod_base;
    CUfunction f_base = NULL;
    if (ptx_base) {
        CHECK(cuModuleLoadDataEx(&mod_base, ptx_base, 1, jit_opts, jit_vals));
        CHECK(cuModuleGetFunction(&f_base, mod_base, "wmma_multitile"));
    }

    CUfunction f_cpa;
    CHECK(cuModuleGetFunction(&f_cpa, mod_cpa, "wmma_cp_async"));

    const int M = 16, N = 16, K_PER_TILE = 16, K_TILES = 4;
    const int K_TOTAL = K_PER_TILE * K_TILES;
    const int ASZ = M * K_TOTAL;
    const int BSZ = K_TOTAL * N;
    const int CSZ = M * N;

    uint16_t *ha = (uint16_t *)malloc(ASZ * sizeof(uint16_t));
    uint16_t *hb = (uint16_t *)malloc(BSZ * sizeof(uint16_t));
    float    *hc_cpa  = (float *)malloc(CSZ * sizeof(float));
    float    *hc_base = (float *)malloc(CSZ * sizeof(float));
    float    *cref    = (float *)malloc(CSZ * sizeof(float));

    /* Identical input pattern as PR #205. */
    for (int i = 0; i < ASZ; ++i) ha[i] = f32_to_f16((float)((i % 8) - 4) * 0.0625f);
    for (int i = 0; i < BSZ; ++i) hb[i] = f32_to_f16((float)((i % 5) - 2) * 0.125f);

    for (int m = 0; m < M; ++m) {
        for (int n = 0; n < N; ++n) {
            float acc = 0.0f;
            for (int k = 0; k < K_TOTAL; ++k) {
                float av = f16_to_f32(ha[m * K_TOTAL + k]);
                float bv = f16_to_f32(hb[n * K_TOTAL + k]);
                acc += av * bv;
            }
            cref[m * N + n] = acc;
        }
    }

    CUdeviceptr da, db, dc_cpa, dc_base;
    CHECK(cuMemAlloc(&da, ASZ * sizeof(uint16_t)));
    CHECK(cuMemAlloc(&db, BSZ * sizeof(uint16_t)));
    CHECK(cuMemAlloc(&dc_cpa,  CSZ * sizeof(float)));
    CHECK(cuMemAlloc(&dc_base, CSZ * sizeof(float)));
    CHECK(cuMemcpyHtoD(da, ha, ASZ * sizeof(uint16_t)));
    CHECK(cuMemcpyHtoD(db, hb, BSZ * sizeof(uint16_t)));

    unsigned long long k_arg = (unsigned long long)K_TILES;

    /* === cp.async kernel === */
    void *kargs_cpa[4] = { &da, &db, &dc_cpa, &k_arg };
    float ms_cpa = time_kernel(f_cpa, kargs_cpa, 1, 32, 32, 256);
    CHECK(cuMemcpyDtoH(hc_cpa, dc_cpa, CSZ * sizeof(float)));

    /* === baseline (PR #205) kernel, if provided === */
    float ms_base = -1.0f;
    if (f_base) {
        void *kargs_base[4] = { &da, &db, &dc_base, &k_arg };
        ms_base = time_kernel(f_base, kargs_base, 1, 32, 32, 256);
        CHECK(cuMemcpyDtoH(hc_base, dc_base, CSZ * sizeof(float)));
    }

    /* Numeric verification: cp.async vs CPU FP32 reference. */
    float max_abs_cref = 0.0f;
    for (int i = 0; i < CSZ; ++i) if (fabsf(cref[i]) > max_abs_cref) max_abs_cref = fabsf(cref[i]);
    float tol_abs = (max_abs_cref > 0.0f) ? max_abs_cref * 1e-2f : 1e-3f;

    float max_delta_vs_ref = 0.0f;
    int   mismatches_vs_ref = 0;
    for (int i = 0; i < CSZ; ++i) {
        float d = fabsf(hc_cpa[i] - cref[i]);
        if (d > max_delta_vs_ref) max_delta_vs_ref = d;
        if (d > tol_abs) ++mismatches_vs_ref;
    }

    /* Numeric verification: cp.async vs PR #205 baseline kernel
       (the F-RFC067-CP-ASYNC-PERF "pure perf transform" gate => max|d|=0). */
    float max_delta_vs_base = -1.0f;
    int   mismatches_vs_base = 0;
    if (f_base) {
        max_delta_vs_base = 0.0f;
        for (int i = 0; i < CSZ; ++i) {
            float d = fabsf(hc_cpa[i] - hc_base[i]);
            if (d > max_delta_vs_base) max_delta_vs_base = d;
            if (d != 0.0f) ++mismatches_vs_base;
        }
    }

    int numeric_pass = (mismatches_vs_ref == 0) && (!f_base || mismatches_vs_base == 0);
    const char *verd = numeric_pass ? "PASS" : "FAIL";

    printf("F-RFC067-CP-ASYNC-PERF %s -- M=%d N=%d K=%d max|d|_vs_ref=%g tol=%g mism_ref=%d/%d  vs_base max|d|=%g mism_base=%d/%d  ms_cpa=%.4f ms_base=%.4f speedup=%.3f\n",
        verd, M, N, K_TOTAL, max_delta_vs_ref, tol_abs, mismatches_vs_ref, CSZ,
        max_delta_vs_base, mismatches_vs_base, CSZ,
        ms_cpa, ms_base, (ms_base > 0.0f) ? (ms_base / ms_cpa) : 0.0f);

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-P4-cp-async\",\n");
    fprintf(rj, "  \"kernel\": \"wmma_cp_async\",\n");
    fprintf(rj, "  \"falsifier\": \"F-RFC067-CP-ASYNC-PERF\",\n");
    fprintf(rj, "  \"verdict\": \"%s\",\n", verd);
    fprintf(rj, "  \"shape\": \"M=%d N=%d K=%d (K_TILES=%d)\",\n", M, N, K_TOTAL, K_TILES);
    fprintf(rj, "  \"max_delta_vs_cpu_ref\": %g,\n", max_delta_vs_ref);
    fprintf(rj, "  \"tolerance_vs_ref\": %g,\n", tol_abs);
    fprintf(rj, "  \"mismatches_vs_ref\": %d,\n", mismatches_vs_ref);
    fprintf(rj, "  \"max_delta_vs_baseline\": %g,\n", max_delta_vs_base);
    fprintf(rj, "  \"mismatches_vs_baseline\": %d,\n", mismatches_vs_base);
    fprintf(rj, "  \"max_abs_cref\": %g,\n", max_abs_cref);
    fprintf(rj, "  \"ms_cp_async_mean_256rep\": %g,\n", ms_cpa);
    fprintf(rj, "  \"ms_baseline_mean_256rep\": %g,\n", ms_base);
    fprintf(rj, "  \"speedup_base_over_cpa\": %g\n", (ms_base > 0.0f) ? (ms_base / ms_cpa) : 0.0);
    fprintf(rj, "}\n");
    fclose(rj);

    cuMemFree(da); cuMemFree(db); cuMemFree(dc_cpa); cuMemFree(dc_base);
    cuModuleUnload(mod_cpa);
    if (f_base) cuModuleUnload(mod_base);
    cuCtxDestroy(ctx);
    return numeric_pass ? 0 : 1;
}
