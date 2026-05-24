/* RFC 067 N201 multi-stage TMA perf-proxy host driver.
 *
 * Fires sgemm_tma_perf_s{1,2,3}_k{N}.ptx with shape M (configurable) x K.
 * Grid = (M/64, 1, 1); 128 threads/CTA.
 * Measures elapsed time via cuEventRecord; reports GB/s of TMA traffic.
 *
 * NOTE: this is a BANDWIDTH PROXY, not a real SGEMM. We measure how multi-stage
 * mbarrier-pool TMA pipelining affects DMA-bound steady state, which is the
 * dominant regime at the SGEMM cliff (M >= 4096). The reduce-to-1-f32-per-CTA
 * compute path keeps ALU active enough to expose pipelining; mma replacement
 * is left for the follow-up "real mma chain" step.
 *
 * Args: ./host_perf <ptx> <M> <K_TILES> <stages> [<reps>]
 */

#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#define CHECK_CU(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA driver error %d at %s:%d: %s\n", e, __FILE__, __LINE__, s ? s : "?"); \
        last_err = e; goto fail; }} while (0)

static uint16_t f32_to_f16(float f) {
    uint32_t x; memcpy(&x, &f, 4);
    uint32_t sign  = (x >> 16) & 0x8000;
    int32_t  exp   = ((x >> 23) & 0xff) - 127 + 15;
    uint32_t mant  =  x & 0x7fffff;
    if (exp <= 0)        return (uint16_t)sign;
    if (exp >= 31)       return (uint16_t)(sign | 0x7c00);
    return (uint16_t)(sign | (exp << 10) | (mant >> 13));
}

int main(int argc, char **argv) {
    if (argc < 5) {
        fprintf(stderr, "usage: %s ptx M K_TILES STAGES [REPS]\n", argv[0]);
        return 2;
    }
    CUresult last_err = CUDA_SUCCESS;
    const char *ptx_path = argv[1];
    int M  = atoi(argv[2]);
    int KT = atoi(argv[3]);
    int stages = atoi(argv[4]);
    int reps   = (argc >= 6) ? atoi(argv[5]) : 32;
    const char *fail_stage = "";
    char jit_log[8192]; jit_log[0] = 0;

    /* derived */
    const int TILE_K = 16;
    const int TILE_M = 64;
    const int K = KT * TILE_K;
    const int N = 64;                     /* B is K x N=64; descriptor is global */
    const int grid = M / TILE_M;
    size_t a_bytes = (size_t)M * K * sizeof(uint16_t);
    size_t b_bytes = (size_t)K * N * sizeof(uint16_t);
    size_t c_bytes = (size_t)grid * sizeof(float);

    CHECK_CU(cuInit(0));
    CUdevice dev;    CHECK_CU(cuDeviceGet(&dev, 0));
    CUcontext ctx;   CHECK_CU(cuCtxCreate(&ctx, 0, dev));

    char dev_name[256];
    CHECK_CU(cuDeviceGetName(dev_name, sizeof(dev_name), dev));
    int sm_major = 0, sm_minor = 0;
    CHECK_CU(cuDeviceGetAttribute(&sm_major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
    CHECK_CU(cuDeviceGetAttribute(&sm_minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
    printf("Device: %s sm_%d%d  M=%d K=%d KT=%d stages=%d reps=%d grid=%d\n",
           dev_name, sm_major, sm_minor, M, K, KT, stages, reps, grid);

    uint16_t *ha = (uint16_t *)malloc(a_bytes);
    uint16_t *hb = (uint16_t *)malloc(b_bytes);
    for (size_t i = 0; i < (size_t)M * K; ++i) ha[i] = f32_to_f16((float)(i % 13) / 16.0f);
    for (size_t i = 0; i < (size_t)K * N; ++i) hb[i] = f32_to_f16((float)((i*7) % 17) / 16.0f);

    CUdeviceptr da, db, dc;
    fail_stage = "alloc";
    CHECK_CU(cuMemAlloc(&da, a_bytes));
    CHECK_CU(cuMemAlloc(&db, b_bytes));
    CHECK_CU(cuMemAlloc(&dc, c_bytes));
    CHECK_CU(cuMemcpyHtoD(da, ha, a_bytes));
    CHECK_CU(cuMemcpyHtoD(db, hb, b_bytes));
    CHECK_CU(cuMemsetD8(dc, 0, c_bytes));

    /* Build TMA descriptors. A: full M x K fp16, tile 64 rows x 16 cols
       (descriptor `boxDim = {16, 64}` per N200 convention: innermost first).
       B: K x N=64 fp16, tile 16 rows x 64 cols. */
    CUtensorMap tmap_a, tmap_b;
    {
        cuuint64_t globalDim[2]    = { (cuuint64_t)K, (cuuint64_t)M };
        cuuint64_t globalStride[1] = { (cuuint64_t)K * 2 };
        cuuint32_t boxDim[2]       = { 16, 64 };
        cuuint32_t elemStride[2]   = { 1, 1 };
        fail_stage = "cuTensorMapEncodeTiled(A)";
        CHECK_CU(cuTensorMapEncodeTiled(
            &tmap_a, CU_TENSOR_MAP_DATA_TYPE_FLOAT16, 2, (void *)da,
            globalDim, globalStride, boxDim, elemStride,
            CU_TENSOR_MAP_INTERLEAVE_NONE, CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE, CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE));
    }
    {
        cuuint64_t globalDim[2]    = { (cuuint64_t)N, (cuuint64_t)K };
        cuuint64_t globalStride[1] = { (cuuint64_t)N * 2 };
        cuuint32_t boxDim[2]       = { 64, 16 };
        cuuint32_t elemStride[2]   = { 1, 1 };
        fail_stage = "cuTensorMapEncodeTiled(B)";
        CHECK_CU(cuTensorMapEncodeTiled(
            &tmap_b, CU_TENSOR_MAP_DATA_TYPE_FLOAT16, 2, (void *)db,
            globalDim, globalStride, boxDim, elemStride,
            CU_TENSOR_MAP_INTERLEAVE_NONE, CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE, CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE));
    }

    FILE *f = fopen(ptx_path, "rb");
    if (!f) { fprintf(stderr, "open %s failed\n", ptx_path); return 1; }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    rewind(f);
    char *ptx = (char *)malloc(sz + 1);
    if (fread(ptx, 1, (size_t)sz, f) != (size_t)sz) { /* ignore */ }
    ptx[sz] = 0;
    fclose(f);

    CUmodule mod;
    fail_stage = "cuModuleLoadDataEx";
    CUjit_option opts[] = { CU_JIT_INFO_LOG_BUFFER, CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES,
                            CU_JIT_ERROR_LOG_BUFFER, CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES };
    void *vals[] = { jit_log, (void *)(uintptr_t)sizeof(jit_log),
                     jit_log, (void *)(uintptr_t)sizeof(jit_log) };
    CHECK_CU(cuModuleLoadDataEx(&mod, ptx, 4, opts, vals));
    if (jit_log[0]) printf("[JIT log] %s\n", jit_log);

    CUfunction kernel;
    CHECK_CU(cuModuleGetFunction(&kernel, mod, "sgemm_tma_perf"));

    void *kargs[] = { &tmap_a, &tmap_b, &dc };

    /* warmup */
    fail_stage = "launch_warmup";
    for (int w = 0; w < 3; ++w) {
        CHECK_CU(cuLaunchKernel(kernel, grid, 1, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuCtxSynchronize());

    /* time `reps` launches */
    CUevent ev_start, ev_stop;
    CHECK_CU(cuEventCreate(&ev_start, CU_EVENT_DEFAULT));
    CHECK_CU(cuEventCreate(&ev_stop, CU_EVENT_DEFAULT));
    fail_stage = "launch_timed";
    CHECK_CU(cuEventRecord(ev_start, 0));
    for (int r = 0; r < reps; ++r) {
        CHECK_CU(cuLaunchKernel(kernel, grid, 1, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuEventRecord(ev_stop, 0));
    CHECK_CU(cuEventSynchronize(ev_stop));
    float ms_total = 0;
    CHECK_CU(cuEventElapsedTime(&ms_total, ev_start, ev_stop));
    float ms_per_launch = ms_total / (float)reps;

    /* Traffic per launch: per CTA each K-iter loads A 2048 B + B 2048 B = 4096 B.
       grid CTAs * KT iters * 4096 B. */
    double bytes_per_launch = (double)grid * (double)KT * 4096.0;
    double gbps = (bytes_per_launch / (ms_per_launch * 1e-3)) / 1.0e9;

    /* SGEMM-equivalent FLOPs for the shape M x N=64 x K=KT*16 (effective workload):
       though we don't do real mma, report a notional GEMM FLOP rate for comparison. */
    double flops = 2.0 * (double)M * (double)N * (double)K;
    double tflops = (flops / (ms_per_launch * 1e-3)) / 1.0e12;

    printf("{\n");
    printf("  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    printf("  \"M\": %d,  \"K\": %d,  \"N\": %d,\n", M, K, N);
    printf("  \"stages\": %d,  \"K_TILES\": %d,  \"grid\": %d,  \"reps\": %d,\n", stages, KT, grid, reps);
    printf("  \"ms_per_launch\": %f,\n", ms_per_launch);
    printf("  \"tma_bytes_per_launch\": %.0f,\n", bytes_per_launch);
    printf("  \"tma_gbps\": %f,\n", gbps);
    printf("  \"notional_tflops\": %f\n", tflops);
    printf("}\n");

    free(ptx);
    free(ha); free(hb);
    cuMemFree(da); cuMemFree(db); cuMemFree(dc);
    cuCtxDestroy(ctx);
    return 0;

fail:
    fprintf(stderr, "FAILED at %s (CUDA error %d)\n", fail_stage, last_err);
    if (jit_log[0]) fprintf(stderr, "[JIT log] %s\n", jit_log);
    return 1;
}
