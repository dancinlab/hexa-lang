/* RFC 067 P4 -- WMMA 16x16 GEMM silicon fire host launcher.
 *
 * Fires the hand-emitted wmma_16x16.ptx kernel: computes one 16x16 GEMM
 * tile via Tensor Core wmma.mma (f16 inputs, f32 accumulator). Compares
 * against CPU FP32 reference. Tolerance: max relative error <= 1e-2
 * (the canonical f16-mul-f32-accum bound per NVIDIA PTX ISA 9.7.13.4).
 *
 * Build:  nvcc -O2 -o r067_p4_host r067_p4_host.c -lcuda
 * Run:    ./r067_p4_host wmma_16x16.ptx
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

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s wmma_16x16.ptx\n", argv[0]); return 2; }
    const char *ptx_path = argv[1];

    FILE *fp = fopen(ptx_path, "rb");
    if (!fp) { perror("ptx open"); return 1; }
    fseek(fp, 0, SEEK_END);
    long n_ptx = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(n_ptx + 1);
    fread(ptx, 1, n_ptx, fp);
    ptx[n_ptx] = 0;
    fclose(fp);

    CHECK(cuInit(0));
    CUdevice  dev;     CHECK(cuDeviceGet(&dev, 0));
    CUcontext ctx;     CHECK(cuCtxCreate(&ctx, 0, dev));

    CUmodule mod;
    CUjit_option jit_opts[1] = { CU_JIT_TARGET_FROM_CUCONTEXT };
    void *jit_vals[1] = { (void *)0 };
    CHECK(cuModuleLoadDataEx(&mod, ptx, 1, jit_opts, jit_vals));

    CUfunction f;
    CHECK(cuModuleGetFunction(&f, mod, "wmma_16x16"));

    const int M = 16, N = 16, K = 16;
    const int ASZ = M * K;
    const int BSZ = K * N;
    const int CSZ = M * N;

    uint16_t *ha = (uint16_t *)malloc(ASZ * sizeof(uint16_t));
    uint16_t *hb = (uint16_t *)malloc(BSZ * sizeof(uint16_t));
    float    *hc = (float    *)malloc(CSZ * sizeof(float));
    float    *cref = (float  *)malloc(CSZ * sizeof(float));

    /* Inputs: small values so f16 representation is clean. A row-major,
       B col-major. */
    for (int i = 0; i < ASZ; ++i) ha[i] = f32_to_f16((float)((i % 8) - 4) * 0.25f);
    for (int i = 0; i < BSZ; ++i) hb[i] = f32_to_f16((float)((i % 5) - 2) * 0.5f);

    /* Reference: cast inputs to f32, GEMM in f32 (matches wmma's f32 accum).
       A row-major: a[m][k] = ha[m*K + k]; B col-major: b[k][n] = hb[n*K + k]. */
    for (int m = 0; m < M; ++m) {
        for (int n = 0; n < N; ++n) {
            float acc = 0.0f;
            for (int k = 0; k < K; ++k) {
                float av = f16_to_f32(ha[m * K + k]);
                float bv = f16_to_f32(hb[n * K + k]);
                acc += av * bv;
            }
            cref[m * N + n] = acc;
        }
    }

    CUdeviceptr da, db, dc;
    CHECK(cuMemAlloc(&da, ASZ * sizeof(uint16_t)));
    CHECK(cuMemAlloc(&db, BSZ * sizeof(uint16_t)));
    CHECK(cuMemAlloc(&dc, CSZ * sizeof(float)));
    CHECK(cuMemcpyHtoD(da, ha, ASZ * sizeof(uint16_t)));
    CHECK(cuMemcpyHtoD(db, hb, BSZ * sizeof(uint16_t)));

    void *kargs[3] = { &da, &db, &dc };
    CHECK(cuLaunchKernel(f, 1, 1, 1, 32, 1, 1, 0, NULL, kargs, NULL));
    CHECK(cuCtxSynchronize());
    CHECK(cuMemcpyDtoH(hc, dc, CSZ * sizeof(float)));

    /* Compare. Tolerance: rel-err <= 1e-2 per ISA spec for f16-mul-f32-acc. */
    float max_abs_cref = 0.0f;
    for (int i = 0; i < CSZ; ++i) if (fabsf(cref[i]) > max_abs_cref) max_abs_cref = fabsf(cref[i]);
    float tol_abs = (max_abs_cref > 0.0f) ? max_abs_cref * 1e-2f : 1e-3f;

    float max_delta = 0.0f;
    int mismatches = 0;
    for (int i = 0; i < CSZ; ++i) {
        float d = fabsf(hc[i] - cref[i]);
        if (d > max_delta) max_delta = d;
        if (d > tol_abs) ++mismatches;
    }

    const char *verd = (mismatches == 0) ? "PASS" : "FAIL";
    printf("F-RFC067-TILE-LOOP-NUMERIC %s -- 16x16 max|d|=%g tol=%g mismatches=%d/%d max_abs_ref=%g\n",
        verd, max_delta, tol_abs, mismatches, CSZ, max_abs_cref);

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-P4\",\n");
    fprintf(rj, "  \"kernel\": \"wmma_16x16\",\n");
    fprintf(rj, "  \"falsifier\": \"F-RFC067-TILE-LOOP-NUMERIC\",\n");
    fprintf(rj, "  \"verdict\": \"%s\",\n", verd);
    fprintf(rj, "  \"shape\": \"16x16x16\",\n");
    fprintf(rj, "  \"max_delta\": %g,\n", max_delta);
    fprintf(rj, "  \"tolerance\": %g,\n", tol_abs);
    fprintf(rj, "  \"mismatches\": %d,\n", mismatches);
    fprintf(rj, "  \"max_abs_cref\": %g\n", max_abs_cref);
    fprintf(rj, "}\n");
    fclose(rj);

    cuMemFree(da); cuMemFree(db); cuMemFree(dc);
    cuModuleUnload(mod);
    cuCtxDestroy(ctx);
    return (mismatches == 0) ? 0 : 1;
}
