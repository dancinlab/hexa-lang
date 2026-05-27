/* RFC 067 PTMA probe host driver (2026-05-22)
 *
 * Probes cp.async.bulk.tensor.2d feasibility on Blackwell consumer SKU
 * (RTX 5070, sm_120). Question: does TMA (Hopper Tensor Memory Accelerator)
 * survive on consumer Blackwell, or was it removed?
 *
 * Flow:
 *  1) ptxas-accept check (offline) -- done in fire.sh
 *  2) cuInit / context on device 0 (RTX 5070)
 *  3) cuTensorMapEncodeTiled() builds a 2D TMA descriptor over a global f16
 *     buffer (128x128 elements). Tile = 64x64.
 *  4) Load tma_probe.ptx via cuModuleLoadDataEx with sm_120-target JIT.
 *  5) Launch kernel with descriptor (as __grid_constant__ param) + output ptr.
 *  6) Compare device output[] with the source tile (top-left 64x64) byte-eq.
 *  7) Emit result.json (verdict, byte_mismatch, fail-mode if any).
 *
 *  Falsifier F-RFC067-HEXA-TMA-PROBE: byte_mismatch == 0 AND no driver error.
 *  Honest scope (@D g3): if cuTensorMapEncodeTiled returns CUDA_ERROR_NOT_SUPPORTED
 *  on sm_120, or driver JIT rejects cp.async.bulk.tensor, we record that as a
 *  useful negative -- TMA unavailable on consumer Blackwell.
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
    if (argc < 2) {
        fprintf(stderr, "usage: %s tma_probe.ptx\n", argv[0]);
        return 2;
    }
    CUresult last_err = CUDA_SUCCESS;
    const char *ptx_path = argv[1];
    const char *fail_stage = "";
    int  byte_mismatch = -1;
    int  ptx_accepted  = 0;
    int  tmap_encoded  = 0;
    int  kernel_launched = 0;
    int  module_loaded   = 0;

    CHECK_CU(cuInit(0));
    fail_stage = "cuDeviceGet";
    CUdevice dev;     CHECK_CU(cuDeviceGet(&dev, 0));
    CUcontext ctx;    CHECK_CU(cuCtxCreate(&ctx, 0, dev));

    char dev_name[256];
    CHECK_CU(cuDeviceGetName(dev_name, sizeof(dev_name), dev));
    int sm_major = 0, sm_minor = 0;
    CHECK_CU(cuDeviceGetAttribute(&sm_major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
    CHECK_CU(cuDeviceGetAttribute(&sm_minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
    int driver_ver = 0;
    CHECK_CU(cuDriverGetVersion(&driver_ver));
    printf("Device: %s sm_%d%d  driver=%d\n", dev_name, sm_major, sm_minor, driver_ver);

    /* ---- Allocate source tensor (128 x 128 f16) + populate ---- */
    const int H = 128;
    const int W = 128;
    const int TILE_H = 64;
    const int TILE_W = 64;
    size_t src_bytes = (size_t)H * W * sizeof(uint16_t);
    uint16_t *hsrc = (uint16_t *)malloc(src_bytes);
    for (int y = 0; y < H; ++y)
        for (int x = 0; x < W; ++x)
            hsrc[y*W + x] = f32_to_f16((float)((y*W + x) % 17) * 0.0625f);

    CUdeviceptr dsrc = 0, dout = 0;
    fail_stage = "cuMemAlloc src";
    CHECK_CU(cuMemAlloc(&dsrc, src_bytes));
    size_t out_bytes = (size_t)TILE_H * TILE_W * sizeof(uint16_t);
    fail_stage = "cuMemAlloc out";
    CHECK_CU(cuMemAlloc(&dout, out_bytes));
    fail_stage = "cuMemcpyHtoD";
    CHECK_CU(cuMemcpyHtoD(dsrc, hsrc, src_bytes));
    CHECK_CU(cuMemsetD8(dout, 0xee, out_bytes)); /* sentinel */

    /* ---- Build TMA descriptor ---- */
    /* CUtensorMap is 128 bytes (driver opaque). cuTensorMapEncodeTiled takes:
     *   dtype = CU_TENSOR_MAP_DATA_TYPE_FLOAT16
     *   rank  = 2
     *   global address = dsrc
     *   global dims = { W, H }                (innermost first per CUDA docs)
     *   global strides[1..rank-1] = { W * 2 } (bytes; element-stride for first dim is implicit)
     *   box dims = { TILE_W, TILE_H }
     *   element strides = { 1, 1 }
     *   interleave / swizzle / l2_promotion / oob_fill = default
     */
    CUtensorMap tmap;
    memset(&tmap, 0, sizeof(tmap));
    cuuint64_t globalDim[2]   = { (cuuint64_t)W, (cuuint64_t)H };
    cuuint64_t globalStride[1]= { (cuuint64_t)(W * sizeof(uint16_t)) };
    cuuint32_t boxDim[2]      = { (cuuint32_t)TILE_W, (cuuint32_t)TILE_H };
    cuuint32_t elemStride[2]  = { 1, 1 };

    fail_stage = "cuTensorMapEncodeTiled";
    CUresult tm_res = cuTensorMapEncodeTiled(
        &tmap,
        CU_TENSOR_MAP_DATA_TYPE_FLOAT16,
        2,
        (void *)(uintptr_t)dsrc,
        globalDim,
        globalStride,
        boxDim,
        elemStride,
        CU_TENSOR_MAP_INTERLEAVE_NONE,
        CU_TENSOR_MAP_SWIZZLE_NONE,
        CU_TENSOR_MAP_L2_PROMOTION_NONE,
        CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
    if (tm_res != CUDA_SUCCESS) {
        const char *s = NULL; cuGetErrorString(tm_res, &s);
        fprintf(stderr, "cuTensorMapEncodeTiled failed: %d (%s)\n",
                (int)tm_res, s ? s : "?");
        last_err = tm_res;
        goto fail;
    }
    tmap_encoded = 1;
    printf("[OK] cuTensorMapEncodeTiled succeeded\n");

    /* ---- Load PTX with JIT to sm_120 (the device's own arch) ---- */
    FILE *fp = fopen(ptx_path, "rb");
    if (!fp) { perror("ptx open"); goto fail; }
    fseek(fp, 0, SEEK_END);
    long n_ptx = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(n_ptx + 1);
    if (fread(ptx, 1, n_ptx, fp) != (size_t)n_ptx) { fprintf(stderr, "ptx short read\n"); goto fail; }
    ptx[n_ptx] = 0;
    fclose(fp);

    /* Capture JIT log so we can record exact rejection reason if it fails. */
    char jit_log[8192]; jit_log[0] = 0;
    char jit_err[8192]; jit_err[0] = 0;
    CUjit_option jit_opts[] = {
        CU_JIT_INFO_LOG_BUFFER,
        CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_ERROR_LOG_BUFFER,
        CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_TARGET_FROM_CUCONTEXT
    };
    void *jit_vals[] = {
        (void *)jit_log,
        (void *)(uintptr_t)sizeof(jit_log),
        (void *)jit_err,
        (void *)(uintptr_t)sizeof(jit_err),
        (void *)0
    };

    CUmodule mod;
    fail_stage = "cuModuleLoadDataEx";
    CUresult mr = cuModuleLoadDataEx(&mod, ptx, 5, jit_opts, jit_vals);
    if (jit_log[0]) printf("[JIT info log]\n%s\n", jit_log);
    if (jit_err[0]) printf("[JIT error log]\n%s\n", jit_err);
    if (mr != CUDA_SUCCESS) {
        const char *s = NULL; cuGetErrorString(mr, &s);
        fprintf(stderr, "cuModuleLoadDataEx failed: %d (%s)\n", (int)mr, s ? s : "?");
        last_err = mr;
        goto fail;
    }
    module_loaded = 1;
    ptx_accepted  = 1;
    printf("[OK] cuModuleLoadDataEx succeeded -- driver JIT accepted cp.async.bulk.tensor on sm_%d%d\n",
           sm_major, sm_minor);

    CUfunction f_probe;
    fail_stage = "cuModuleGetFunction";
    CHECK_CU(cuModuleGetFunction(&f_probe, mod, "tma_probe"));

    /* ---- Launch ---- */
    /* Args: __grid_constant__ const CUtensorMap tmap (passed by value, 128 B), half* out */
    void *kargs[2] = { &tmap, &dout };

    fail_stage = "cuLaunchKernel";
    CHECK_CU(cuLaunchKernel(f_probe,
        1, 1, 1,
        128, 1, 1,
        0, NULL, kargs, NULL));
    CHECK_CU(cuCtxSynchronize());
    kernel_launched = 1;
    printf("[OK] kernel launched + synchronized\n");

    /* ---- Verify ---- */
    uint16_t *hout = (uint16_t *)malloc(out_bytes);
    CHECK_CU(cuMemcpyDtoH(hout, dout, out_bytes));

    int mismatch = 0;
    int first_mm_idx = -1;
    uint16_t first_mm_got = 0, first_mm_exp = 0;
    for (int y = 0; y < TILE_H; ++y) {
        for (int x = 0; x < TILE_W; ++x) {
            uint16_t exp = hsrc[y*W + x]; /* top-left tile */
            uint16_t got = hout[y*TILE_W + x];
            if (exp != got) {
                if (mismatch == 0) {
                    first_mm_idx = y*TILE_W + x;
                    first_mm_got = got;
                    first_mm_exp = exp;
                }
                mismatch++;
            }
        }
    }
    byte_mismatch = mismatch * 2; /* halves -> bytes */
    printf("[VERIFY] tile_elements=%d mismatch=%d byte_mismatch=%d\n",
           TILE_H * TILE_W, mismatch, byte_mismatch);
    if (mismatch) {
        printf("  first mismatch idx=%d got=0x%04x exp=0x%04x\n",
               first_mm_idx, first_mm_got, first_mm_exp);
    }

    /* ---- result.json ---- */
    {
        FILE *rj = fopen("result.json", "w");
        if (!rj) { perror("result.json"); free(hout); goto fail; }
        fprintf(rj, "{\n");
        fprintf(rj, "  \"rfc\": \"067-ptma-probe\",\n");
        fprintf(rj, "  \"date_utc\": \"2026-05-22\",\n");
        fprintf(rj, "  \"host\": \"ubu-1\",\n");
        fprintf(rj, "  \"device\": \"%s\",\n", dev_name);
        fprintf(rj, "  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
        fprintf(rj, "  \"driver_version\": %d,\n", driver_ver);
        fprintf(rj, "  \"ptx_target\": \"sm_120a\",\n");
        fprintf(rj, "  \"ptx_version\": \"8.7\",\n");
        fprintf(rj, "  \"jit_target_from_context\": \"sm_%d%d\",\n", sm_major, sm_minor);
        fprintf(rj, "  \"tile_h\": %d, \"tile_w\": %d, \"dtype\": \"float16\",\n", TILE_H, TILE_W);
        fprintf(rj, "  \"tmap_encoded\": %s,\n", tmap_encoded ? "true" : "false");
        fprintf(rj, "  \"ptx_accepted\": %s,\n", ptx_accepted ? "true" : "false");
        fprintf(rj, "  \"module_loaded\": %s,\n", module_loaded ? "true" : "false");
        fprintf(rj, "  \"kernel_launched\": %s,\n", kernel_launched ? "true" : "false");
        fprintf(rj, "  \"byte_mismatch\": %d,\n", byte_mismatch);
        fprintf(rj, "  \"tile_elements\": %d,\n", TILE_H * TILE_W);
        fprintf(rj, "  \"verdict\": \"%s\"\n",
            (byte_mismatch == 0 ? "TMA_AVAILABLE_BIT_EXACT" :
             (mismatch > 0 ? "TMA_LOADED_BUT_BIT_DIFF" :
              "UNREACHED")));
        fprintf(rj, "}\n");
        fclose(rj);
    }

    free(hout);
    free(hsrc);
    cuMemFree(dsrc);
    cuMemFree(dout);
    cuModuleUnload(mod);
    cuCtxDestroy(ctx);
    return (byte_mismatch == 0) ? 0 : 3;

fail: {
    /* Emit failure JSON so the artifact dir is self-describing. */
    const char *err_str = NULL; cuGetErrorString(last_err, &err_str);
    FILE *rj = fopen("result.json", "w");
    if (rj) {
        fprintf(rj, "{\n");
        fprintf(rj, "  \"rfc\": \"067-ptma-probe\",\n");
        fprintf(rj, "  \"date_utc\": \"2026-05-22\",\n");
        fprintf(rj, "  \"host\": \"ubu-1\",\n");
        fprintf(rj, "  \"device\": \"%s\",\n", dev_name);
        fprintf(rj, "  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
        fprintf(rj, "  \"driver_version\": %d,\n", driver_ver);
        fprintf(rj, "  \"tmap_encoded\": %s,\n", tmap_encoded ? "true" : "false");
        fprintf(rj, "  \"ptx_accepted\": %s,\n", ptx_accepted ? "true" : "false");
        fprintf(rj, "  \"module_loaded\": %s,\n", module_loaded ? "true" : "false");
        fprintf(rj, "  \"kernel_launched\": %s,\n", kernel_launched ? "true" : "false");
        fprintf(rj, "  \"byte_mismatch\": null,\n");
        fprintf(rj, "  \"fail_stage\": \"%s\",\n", fail_stage);
        fprintf(rj, "  \"cuda_error_code\": %d,\n", (int)last_err);
        fprintf(rj, "  \"cuda_error_str\": \"%s\",\n", err_str ? err_str : "?");
        fprintf(rj, "  \"verdict\": \"FAIL_%s\"\n", fail_stage);
        fprintf(rj, "}\n");
        fclose(rj);
    }
    return 1;
}
}
