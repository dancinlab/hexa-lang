/* RFC 068 P4 — f16 vec-add silicon-fire host launcher.
 *
 * Driver-API host (cuModuleLoadDataEx) for the hand-emitted f16 vec-add
 * PTX. Compares GPU output (f16 add via add.f16 PTX) against a CPU
 * f32 reference. Tolerance: max|Δ| ≤ 2 × f16-ULP × max(|c_ref|).
 *
 * F-RFC068-NUMERIC-EQ — falsifier closure on real silicon.
 *
 * Build:  nvcc -O2 -o r068_p4_host r068_p4_host.c -lcuda
 * Run:    ./r068_p4_host f16_vadd.ptx
 * Output: stdout summary + result.json
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

/* IEEE 754 binary16 (half) — bit layout: sign 1 | exp 5 | mantissa 10 */
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
    if (argc < 2) { fprintf(stderr, "usage: %s f16_vadd.ptx\n", argv[0]); return 2; }
    const char *ptx_path = argv[1];

    /* slurp PTX */
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

    CUfunction f;      CHECK(cuModuleGetFunction(&f, mod, "f16_vadd"));

    const int N = 1024;
    uint16_t *ha = (uint16_t *)malloc(N * sizeof(uint16_t));
    uint16_t *hb = (uint16_t *)malloc(N * sizeof(uint16_t));
    uint16_t *hc = (uint16_t *)malloc(N * sizeof(uint16_t));
    float    *cref = (float *)malloc(N * sizeof(float));

    /* Inputs in the safe f16 range (|x| ≤ 32) → no overflow on add */
    for (int i = 0; i < N; ++i) {
        float a = (float)((i % 64) - 32) * 0.5f;
        float b = (float)((i % 32) - 16) * 0.25f;
        ha[i] = f32_to_f16(a);
        hb[i] = f32_to_f16(b);
        /* reference: cast back to f32 (lossy), sum in f32, round-to-nearest f16 */
        float ar = f16_to_f32(ha[i]);
        float br = f16_to_f32(hb[i]);
        uint16_t cr_h = f32_to_f16(ar + br);
        cref[i] = f16_to_f32(cr_h);
    }

    CUdeviceptr da, db, dc, dn;
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

    /* Compare against reference. Tolerance = 2 × f16-ULP × max(|cref|) */
    float max_abs_cref = 0.0f;
    for (int i = 0; i < N; ++i) if (fabsf(cref[i]) > max_abs_cref) max_abs_cref = fabsf(cref[i]);
    /* f16-ULP at value v is roughly v * 2^-10 for non-denormal */
    float f16_ulp = max_abs_cref * (1.0f / 1024.0f);
    float tol = 2.0f * f16_ulp;

    float max_delta = 0.0f;
    int mismatches = 0;
    for (int i = 0; i < N; ++i) {
        float gpu = f16_to_f32(hc[i]);
        float d = fabsf(gpu - cref[i]);
        if (d > max_delta) max_delta = d;
        if (d > tol) ++mismatches;
    }

    /* Verdict */
    const char *verd = (mismatches == 0) ? "PASS" : "FAIL";
    printf("F-RFC068-NUMERIC-EQ %s — N=%d max|Δ|=%g tol=%g mismatches=%d/%d\n",
        verd, N, max_delta, tol, mismatches, N);

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"068-P4\",\n");
    fprintf(rj, "  \"kernel\": \"f16_vadd\",\n");
    fprintf(rj, "  \"falsifier\": \"F-RFC068-NUMERIC-EQ\",\n");
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
