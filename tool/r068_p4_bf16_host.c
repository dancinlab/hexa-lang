/* RFC 068 P4 -- bf16 vec-add silicon fire host launcher.
 *
 * Same shape as r068_p4_host.c (f16 fire, PR #189) but bf16 inputs/
 * outputs. PTX uses .reg .b16 containers + add.bf16 (ptxas 12.0 sm_90+
 * canonical bf16 syntax — see GPU.md §2c probe).
 *
 * Build:  nvcc -O2 -o r068_p4_bf16_host r068_p4_bf16_host.c -lcuda
 * Run:    ./r068_p4_bf16_host bf16_vadd.ptx
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

/* IEEE 754 bfloat16 — sign 1 | exp 8 | mantissa 7 (top 16 bits of f32) */
static uint16_t f32_to_bf16(float f) {
    uint32_t x; memcpy(&x, &f, 4);
    /* round-to-nearest-even */
    uint32_t bias = 0x7fff + ((x >> 16) & 1);
    return (uint16_t)((x + bias) >> 16);
}
static float bf16_to_f32(uint16_t h) {
    uint32_t f = ((uint32_t)h) << 16;
    float out; memcpy(&out, &f, 4);
    return out;
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s bf16_vadd.ptx\n", argv[0]); return 2; }
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
    CHECK(cuModuleGetFunction(&f, mod, "bf16_vadd"));

    const int N = 1024;
    uint16_t *ha = (uint16_t *)malloc(N * sizeof(uint16_t));
    uint16_t *hb = (uint16_t *)malloc(N * sizeof(uint16_t));
    uint16_t *hc = (uint16_t *)malloc(N * sizeof(uint16_t));
    float    *cref = (float  *)malloc(N * sizeof(float));

    /* Inputs in safe bf16 range (much wider than f16 — bf16 has same
       8-bit exponent as f32, so range covers [~1e-38, ~3e38]) */
    for (int i = 0; i < N; ++i) {
        float a = (float)((i % 64) - 32) * 0.5f;
        float b = (float)((i % 32) - 16) * 0.25f;
        ha[i] = f32_to_bf16(a);
        hb[i] = f32_to_bf16(b);
        float ar = bf16_to_f32(ha[i]);
        float br = bf16_to_f32(hb[i]);
        uint16_t cr_h = f32_to_bf16(ar + br);
        cref[i] = bf16_to_f32(cr_h);
    }

    CUdeviceptr da, db, dc;
    CHECK(cuMemAlloc(&da, N * sizeof(uint16_t)));
    CHECK(cuMemAlloc(&db, N * sizeof(uint16_t)));
    CHECK(cuMemAlloc(&dc, N * sizeof(uint16_t)));
    CHECK(cuMemcpyHtoD(da, ha, N * sizeof(uint16_t)));
    CHECK(cuMemcpyHtoD(db, hb, N * sizeof(uint16_t)));

    unsigned long long n_arg = (unsigned long long)N;
    void *kargs[4] = { &da, &db, &dc, &n_arg };
    const int block = 128;
    const int grid  = (N + block - 1) / block;
    CHECK(cuLaunchKernel(f, grid, 1, 1, block, 1, 1, 0, NULL, kargs, NULL));
    CHECK(cuCtxSynchronize());
    CHECK(cuMemcpyDtoH(hc, dc, N * sizeof(uint16_t)));

    /* Compare. bf16 has only 7-bit mantissa → ULP ~ 2^-7 * max(|cref|) */
    float max_abs_cref = 0.0f;
    for (int i = 0; i < N; ++i) if (fabsf(cref[i]) > max_abs_cref) max_abs_cref = fabsf(cref[i]);
    float bf16_ulp = max_abs_cref * (1.0f / 128.0f);
    float tol = 2.0f * bf16_ulp;

    float max_delta = 0.0f;
    int mismatches = 0;
    for (int i = 0; i < N; ++i) {
        float gpu = bf16_to_f32(hc[i]);
        float d = fabsf(gpu - cref[i]);
        if (d > max_delta) max_delta = d;
        if (d > tol) ++mismatches;
    }

    const char *verd = (mismatches == 0) ? "PASS" : "FAIL";
    printf("F-RFC068-NUMERIC-EQ-BF16 %s -- N=%d max|d|=%g tol=%g mismatches=%d/%d\n",
        verd, N, max_delta, tol, mismatches, N);

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"068-P4-bf16\",\n");
    fprintf(rj, "  \"kernel\": \"bf16_vadd\",\n");
    fprintf(rj, "  \"falsifier\": \"F-RFC068-NUMERIC-EQ-BF16\",\n");
    fprintf(rj, "  \"verdict\": \"%s\",\n", verd);
    fprintf(rj, "  \"n\": %d,\n", N);
    fprintf(rj, "  \"max_delta\": %g,\n", max_delta);
    fprintf(rj, "  \"tolerance\": %g,\n", tol);
    fprintf(rj, "  \"mismatches\": %d,\n", mismatches);
    fprintf(rj, "  \"max_abs_cref\": %g\n", max_abs_cref);
    fprintf(rj, "}\n");
    fclose(rj);

    cuMemFree(da); cuMemFree(db); cuMemFree(dc);
    cuModuleUnload(mod);
    cuCtxDestroy(ctx);

    return (mismatches == 0) ? 0 : 1;
}
