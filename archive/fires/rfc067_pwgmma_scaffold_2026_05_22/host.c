/* RFC 067 PWGMMA-SCAFFOLD -- driver for wgmma_kernel feasibility on RTX 5070 sm_120.
 *
 * Kernel: wgmma.mma_async.sync.aligned.m64n16k16.f32.f16.f16 (1 warpgroup, 128 threads).
 *
 * Falsifier F-RFC067-HEXA-WGMMA-SCAFFOLD:
 *   - Numeric: A = all-ones f16, B = all-ones f16 -> each C[i][j] = 16.0 (sum over K=16 of 1*1)
 *     sum_all_C = 64 * 16 * 16 = 16384.0
 *     We sum the C buffer in host (per-thread storage layout, not output coordinate
 *     layout: each thread stored 8 f32; total 128*8 = 1024 floats = same as 64*16)
 *     Because all values must equal 16.0, sum and per-element check both apply.
 *   - cuModuleLoadDataEx succeeds on driver-JIT to sm_120
 *
 * Build:
 *   nvcc -O2 -arch=sm_90a -o host host.c -lcuda -lm
 */

#include <cuda.h>
#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define CHECK_CU(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA driver error %d at %s:%d: %s\n", e, __FILE__, __LINE__, s ? s : "?"); \
        return 1; }} while (0)

static unsigned short f32_to_f16(float f) {
    unsigned int x; memcpy(&x, &f, 4);
    unsigned int sign = (x >> 31) & 0x1;
    int exp = (int)((x >> 23) & 0xff) - 127 + 15;
    unsigned int mant = x & 0x7fffff;
    unsigned short out;
    if (exp >= 31) {
        out = (sign << 15) | (0x1f << 10) | (mant ? (mant >> 13) : 0);
    } else if (exp <= 0) {
        if (exp < -10) {
            out = (sign << 15);
        } else {
            mant |= 0x800000;
            int shift = 14 - exp;
            out = (sign << 15) | (mant >> shift);
        }
    } else {
        out = (sign << 15) | (exp << 10) | (mant >> 13);
    }
    return out;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <wgmma_scaffold.ptx>\n", argv[0]);
        return 2;
    }
    const char *ptx_path = argv[1];

    /* Read PTX text */
    FILE *fp = fopen(ptx_path, "rb");
    if (!fp) { perror("open ptx"); return 1; }
    fseek(fp, 0, SEEK_END);
    long ptx_size = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *ptx_buf = (char *)malloc((size_t)ptx_size + 1);
    fread(ptx_buf, 1, (size_t)ptx_size, fp);
    ptx_buf[ptx_size] = '\0';
    fclose(fp);

    CHECK_CU(cuInit(0));
    CUdevice dev;
    CHECK_CU(cuDeviceGet(&dev, 0));
    int sm_major = 0, sm_minor = 0;
    CHECK_CU(cuDeviceGetAttribute(&sm_major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
    CHECK_CU(cuDeviceGetAttribute(&sm_minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
    char devname[256];
    CHECK_CU(cuDeviceGetName(devname, sizeof(devname), dev));
    printf("device: %s (sm_%d%d)\n", devname, sm_major, sm_minor);

    CUcontext ctx;
    CHECK_CU(cuCtxCreate(&ctx, 0, dev));

    /* Driver JIT compile PTX */
    CUmodule mod;
    char jit_log[16384] = {0};
    char jit_err[16384] = {0};
    CUjit_option opts[] = {
        CU_JIT_INFO_LOG_BUFFER,
        CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_ERROR_LOG_BUFFER,
        CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_LOG_VERBOSE,
    };
    void *vals[] = {
        (void *)jit_log,
        (void *)(uintptr_t)sizeof(jit_log),
        (void *)jit_err,
        (void *)(uintptr_t)sizeof(jit_err),
        (void *)(uintptr_t)1,
    };
    CUresult jres = cuModuleLoadDataEx(&mod, ptx_buf, 5, opts, vals);
    if (jres != CUDA_SUCCESS) {
        const char *s = NULL;
        cuGetErrorString(jres, &s);
        fprintf(stderr, "JIT failed: %s\n", s ? s : "?");
        fprintf(stderr, "JIT info log:\n%s\n", jit_log);
        fprintf(stderr, "JIT error log:\n%s\n", jit_err);
        return 1;
    }
    printf("cuModuleLoadDataEx: OK on sm_%d%d\n", sm_major, sm_minor);
    if (jit_log[0]) printf("JIT info:\n%s\n", jit_log);

    CUfunction func;
    CHECK_CU(cuModuleGetFunction(&func, mod, "wgmma_kernel"));

    int M = 64, N = 16, K = 16;

    /* Build inputs: A = all-ones f16 (64x16), B = all-ones f16 (16x16) */
    size_t a_elems = (size_t)M * K;
    size_t b_elems = (size_t)K * N;
    size_t c_elems = 128 * 8;  /* per-thread 8 floats */
    unsigned short *hA = (unsigned short *)malloc(a_elems * 2);
    unsigned short *hB = (unsigned short *)malloc(b_elems * 2);
    float *hC = (float *)malloc(c_elems * 4);
    unsigned short f16_one = f32_to_f16(1.0f);
    for (size_t i = 0; i < a_elems; ++i) hA[i] = f16_one;
    for (size_t i = 0; i < b_elems; ++i) hB[i] = f16_one;
    memset(hC, 0xCC, c_elems * 4);

    CUdeviceptr dA, dB, dC;
    CHECK_CU(cuMemAlloc(&dA, a_elems * 2));
    CHECK_CU(cuMemAlloc(&dB, b_elems * 2));
    CHECK_CU(cuMemAlloc(&dC, c_elems * 4));
    CHECK_CU(cuMemcpyHtoD(dA, hA, a_elems * 2));
    CHECK_CU(cuMemcpyHtoD(dB, hB, b_elems * 2));
    CHECK_CU(cuMemsetD32(dC, 0, c_elems));

    /* Launch: 1 block, 128 threads (1 warpgroup) */
    void *args[] = { &dA, &dB, &dC };
    CUevent ev_start, ev_end;
    CHECK_CU(cuEventCreate(&ev_start, CU_EVENT_DEFAULT));
    CHECK_CU(cuEventCreate(&ev_end, CU_EVENT_DEFAULT));

    /* Warmup */
    for (int w = 0; w < 5; ++w) {
        CHECK_CU(cuLaunchKernel(func, 1, 1, 1, 128, 1, 1, 0, 0, args, NULL));
    }
    CHECK_CU(cuCtxSynchronize());

    /* Measure */
    int reps = 200;
    CHECK_CU(cuEventRecord(ev_start, 0));
    for (int r = 0; r < reps; ++r) {
        CHECK_CU(cuLaunchKernel(func, 1, 1, 1, 128, 1, 1, 0, 0, args, NULL));
    }
    CHECK_CU(cuEventRecord(ev_end, 0));
    CHECK_CU(cuEventSynchronize(ev_end));
    float ms_total = 0.0f;
    CHECK_CU(cuEventElapsedTime(&ms_total, ev_start, ev_end));
    double ms_per = (double)ms_total / (double)reps;

    /* Read C back */
    CHECK_CU(cuMemcpyDtoH(hC, dC, c_elems * 4));

    /* Numeric check: every C value should be 16.0 (sum_k 1*1 for K=16) */
    double sum = 0.0;
    double max_abs_err = 0.0;
    int n_nonzero = 0;
    int n_eq16 = 0;
    int n_other = 0;
    float min_v = 1e30f, max_v = -1e30f;
    for (size_t i = 0; i < c_elems; ++i) {
        float v = hC[i];
        sum += (double)v;
        if (v != 0.0f) n_nonzero++;
        if (v == 16.0f) n_eq16++;
        else if (v != 0.0f) n_other++;
        if (v < min_v) min_v = v;
        if (v > max_v) max_v = v;
        double err = fabs((double)v - 16.0);
        if (err > max_abs_err) max_abs_err = err;
    }
    double expected_sum = 64.0 * 16.0 * 16.0;  /* M*N*K */
    double sum_err = fabs(sum - expected_sum);

    /* GFLOPS: 1 tile = 2*M*N*K = 2*64*16*16 = 32768 FLOPs per launch */
    double flops = 2.0 * (double)M * (double)N * (double)K;
    double gflops = (flops / (ms_per * 1e-3)) * 1e-9;

    printf("\n=== RESULTS ===\n");
    printf("ms_per_launch: %.6f ms (median of %d reps)\n", ms_per, reps);
    printf("gflops_single_warpgroup: %.4f\n", gflops);
    printf("c_elems: %zu  n_nonzero: %d  n_eq16: %d  n_other: %d\n", c_elems, n_nonzero, n_eq16, n_other);
    printf("min: %.6f  max: %.6f\n", min_v, max_v);
    printf("sum: %.4f  expected: %.4f  err: %.6e\n", sum, expected_sum, sum_err);
    printf("max_abs_err vs 16.0: %.6e\n", max_abs_err);

    int pass = (n_eq16 == (int)c_elems) && (sum_err < 1e-3) && (max_abs_err < 1e-3);
    printf("verdict: %s\n", pass ? "PASS" : "FAIL");

    /* Emit JSON */
    FILE *jf = fopen("result.json", "w");
    fprintf(jf,
        "{\n"
        "  \"device\": \"%s\",\n"
        "  \"compute_capability\": \"sm_%d%d\",\n"
        "  \"ptx_target\": \"sm_90a\",\n"
        "  \"tile_M\": %d, \"tile_N\": %d, \"tile_K\": %d,\n"
        "  \"warpgroup_threads\": 128,\n"
        "  \"reps\": %d,\n"
        "  \"ms_per_launch\": %.9f,\n"
        "  \"gflops_single_warpgroup\": %.6f,\n"
        "  \"c_elems\": %zu,\n"
        "  \"n_eq16\": %d, \"n_nonzero\": %d, \"n_other\": %d,\n"
        "  \"min\": %.6f, \"max\": %.6f,\n"
        "  \"sum\": %.6f, \"expected_sum\": %.6f, \"sum_err\": %.6e,\n"
        "  \"max_abs_err\": %.6e,\n"
        "  \"verdict\": \"%s\"\n"
        "}\n",
        devname, sm_major, sm_minor, M, N, K, reps,
        ms_per, gflops, c_elems, n_eq16, n_nonzero, n_other,
        min_v, max_v, sum, expected_sum, sum_err, max_abs_err,
        pass ? "PASS" : "FAIL");
    fclose(jf);
    printf("wrote result.json\n");

    cuMemFree(dA); cuMemFree(dB); cuMemFree(dC);
    cuModuleUnload(mod);
    cuCtxDestroy(ctx);
    free(hA); free(hB); free(hC); free(ptx_buf);
    return pass ? 0 : 1;
}
