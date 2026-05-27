/* RFC 067 N201 multi-stage TMA SMOKE host driver
 *
 * Fires sgemm_tma_multistage_s{2,3}.ptx on RTX 5070 sm_120 (ubu-1).
 * Same shape as N200 SMOKE: M=N=K=64, single CTA, 128 threads.
 * Builds 2 TMA descriptors, launches kernel, reads C back, verifies the FINAL
 * slab (k_iter=3, slot = 3 % STAGES) holds the last K-tile of A.
 *
 * Falsifier F-RFC067-HEXA-TMA-MULTISTAGE: byte_mismatch == 0 across all sweep
 * shapes (here SMOKE = M=N=K=64; cliff-regime sweep uses the larger driver).
 *
 * Adapted from N200 host.c (`c5840f19`) -- only kernel symbol renamed.
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

static float f16_to_f32(uint16_t h) {
    uint32_t sign = (h & 0x8000) << 16;
    int32_t  exp  = (h >> 10) & 0x1f;
    uint32_t mant = h & 0x3ff;
    if (exp == 0) {
        if (mant == 0) { uint32_t r = sign; float f; memcpy(&f, &r, 4); return f; }
        while ((mant & 0x400) == 0) { mant <<= 1; exp--; }
        mant &= 0x3ff;
        exp++;
    } else if (exp == 31) {
        uint32_t r = sign | 0x7f800000 | (mant << 13);
        float f; memcpy(&f, &r, 4); return f;
    }
    uint32_t r = sign | ((exp + 127 - 15) << 23) | (mant << 13);
    float f; memcpy(&f, &r, 4); return f;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s sgemm_tma_multistage.ptx [stages]\n", argv[0]);
        return 2;
    }
    CUresult last_err = CUDA_SUCCESS;
    const char *ptx_path = argv[1];
    int stages = (argc >= 3) ? atoi(argv[2]) : 3;
    const char *fail_stage = "";
    char jit_log[8192]; jit_log[0] = 0;

    CHECK_CU(cuInit(0));
    fail_stage = "cuDeviceGet";
    CUdevice dev;     CHECK_CU(cuDeviceGet(&dev, 0));
    CUcontext ctx;    CHECK_CU(cuCtxCreate(&ctx, 0, dev));

    char dev_name[256];
    CHECK_CU(cuDeviceGetName(dev_name, sizeof(dev_name), dev));
    int sm_major = 0, sm_minor = 0;
    CHECK_CU(cuDeviceGetAttribute(&sm_major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
    CHECK_CU(cuDeviceGetAttribute(&sm_minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
    printf("Device: %s sm_%d%d  stages=%d\n", dev_name, sm_major, sm_minor, stages);

    const int M = 64;
    const int K = 64;
    const int N = 64;
    const int TILE_K = 16;
    const int K_TILES = K / TILE_K;
    const int final_slot = (K_TILES - 1) % stages;
    size_t a_bytes = (size_t)M * K * sizeof(uint16_t);
    size_t b_bytes = (size_t)K * N * sizeof(uint16_t);
    size_t c_bytes = (size_t)M * N * sizeof(float);

    uint16_t *ha = (uint16_t *)malloc(a_bytes);
    uint16_t *hb = (uint16_t *)malloc(b_bytes);
    float    *hc = (float    *)malloc(c_bytes);
    for (int i = 0; i < M; ++i)
        for (int j = 0; j < K; ++j) ha[i*K + j] = f32_to_f16((float)(i+j) / 16.0f);
    for (int i = 0; i < K; ++i)
        for (int j = 0; j < N; ++j) hb[i*N + j] = f32_to_f16((i == j) ? 1.0f : 0.0f);

    CUdeviceptr da, db, dc;
    fail_stage = "cuMemAlloc(A)";
    CHECK_CU(cuMemAlloc(&da, a_bytes));
    CHECK_CU(cuMemAlloc(&db, b_bytes));
    CHECK_CU(cuMemAlloc(&dc, c_bytes));
    CHECK_CU(cuMemcpyHtoD(da, ha, a_bytes));
    CHECK_CU(cuMemcpyHtoD(db, hb, b_bytes));
    CHECK_CU(cuMemsetD8(dc, 0, c_bytes));

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
    fread(ptx, 1, (size_t)sz, f);
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
    CHECK_CU(cuModuleGetFunction(&kernel, mod, "sgemm_tma_multistage"));

    void *kargs[] = { &tmap_a, &tmap_b, &dc };
    fail_stage = "cuLaunchKernel";
    CHECK_CU(cuLaunchKernel(kernel, 1, 1, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    CHECK_CU(cuCtxSynchronize());

    CHECK_CU(cuMemcpyDtoH(hc, dc, c_bytes));

    /* SMOKE verify: the FINAL slab holds a[row, 48..63] for row=0..63 (1024
       fp16 elements). Each thread tx wrote 2 f32 at C[2*tx,2*tx+1], reading
       from slab byte offset tx*8 == elem index tx*4. So:
         C[2*tx]   = f16_to_f32(a[(tx*4)/16,   48 + (tx*4)%16])
         C[2*tx+1] = f16_to_f32(a[(tx*4+1)/16, 48 + (tx*4+1)%16])  */
    int mismatch = 0;
    int first_mismatch_idx = -1;
    float first_got = 0, first_exp = 0;
    for (int tx = 0; tx < 128; ++tx) {
        int e0 = tx * 4;
        int e1 = tx * 4 + 1;
        int r0 = e0 / 16, c0 = 48 + (e0 % 16);
        int r1 = e1 / 16, c1 = 48 + (e1 % 16);
        float exp0 = f16_to_f32(ha[r0 * K + c0]);
        float exp1 = f16_to_f32(ha[r1 * K + c1]);
        if (hc[2*tx] != exp0) {
            if (mismatch == 0) { first_mismatch_idx = 2*tx; first_got = hc[2*tx]; first_exp = exp0; }
            mismatch++;
        }
        if (hc[2*tx+1] != exp1) {
            if (mismatch == 0) { first_mismatch_idx = 2*tx+1; first_got = hc[2*tx+1]; first_exp = exp1; }
            mismatch++;
        }
    }

    printf("{\n");
    printf("  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    printf("  \"stages\": %d,\n", stages);
    printf("  \"final_slot\": %d,\n", final_slot);
    printf("  \"mismatch\": %d,\n", mismatch);
    printf("  \"total_cells\": 256,\n");
    if (mismatch > 0)
        printf("  \"first_mismatch_idx\": %d,\n  \"got\": %f,\n  \"exp\": %f,\n", first_mismatch_idx, first_got, first_exp);
    printf("  \"verdict\": \"%s\"\n", mismatch == 0 ? "TMA_MULTISTAGE_SMOKE_PASS" : "TMA_MULTISTAGE_SMOKE_MISMATCH");
    printf("}\n");

    free(ptx); free(ha); free(hb); free(hc);
    cuMemFree(da); cuMemFree(db); cuMemFree(dc);
    cuCtxDestroy(ctx);
    return mismatch == 0 ? 0 : 1;

fail:
    fprintf(stderr, "FAILED at %s (CUDA error %d)\n", fail_stage, last_err);
    if (jit_log[0]) fprintf(stderr, "[JIT log] %s\n", jit_log);
    return 1;
}
