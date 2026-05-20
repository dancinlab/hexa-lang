/* RFC 067 P5 TF32 -- WMMA TF32 single-tile silicon fire.
 *
 * Computes M=16, N=16, K=8 GEMM via the tf32_gemm kernel (single warp,
 * m16n16k8.tf32 Tensor Core mma). Compares against CPU FP32 reference.
 *
 * TF32 truncates each input multiplicand to 19 bits (sign + 8 exp +
 * 10 mantissa) at multiply time. When inputs already fit in TF32
 * representable range (mantissa fits in 10 bits), the multiply is
 * bit-for-bit identical to FP32 and we expect max|d|=0. Inputs in this
 * fire are chosen from small power-of-two scaled integers so they are
 * exactly representable in TF32.
 *
 * Build:  nvcc -O2 -arch=sm_90 -o r067_p5_tf32_host r067_p5_tf32_host.c -lcuda
 * Run:    ./r067_p5_tf32_host tf32_gemm.ptx
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

/* Round an f32 down to TF32 precision by masking the low 13 mantissa
 * bits to zero. Round-to-zero on the truncated bits. This models the
 * Tensor Core's TF32 input truncation so the CPU reference matches the
 * GPU bit-for-bit when inputs are already TF32-representable (i.e. the
 * 13 low bits are already zero). */
static float tf32_truncate(float f) {
    uint32_t x; memcpy(&x, &f, 4);
    x &= 0xFFFFE000u;  /* keep upper 19 bits (sign + 8 exp + 10 mantissa) */
    float out; memcpy(&out, &x, 4);
    return out;
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s tf32_gemm.ptx\n", argv[0]); return 2; }
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
    CHECK(cuModuleGetFunction(&f, mod, "tf32_gemm"));

    const int M = 16, N = 16, K = 8;
    const int ASZ = M * K;   /* row-major */
    const int BSZ = K * N;   /* col-major */
    const int CSZ = M * N;

    float *ha = (float *)malloc(ASZ * sizeof(float));
    float *hb = (float *)malloc(BSZ * sizeof(float));
    float *hc = (float *)malloc(CSZ * sizeof(float));
    float *cref = (float *)malloc(CSZ * sizeof(float));

    /* Inputs chosen so each value is exactly TF32-representable
       (small power-of-two scaled integers; only the top few mantissa
       bits are set). With both inputs TF32-exact, the TF32 multiply
       equals the FP32 multiply bit-for-bit. */
    for (int i = 0; i < ASZ; ++i) ha[i] = (float)((i % 8) - 4) * 0.0625f;  /* +/- {0, 0.0625, ..., 0.1875} */
    for (int i = 0; i < BSZ; ++i) hb[i] = (float)((i % 5) - 2) * 0.125f;   /* {-0.25, -0.125, 0, 0.125, 0.25} */

    /* CPU reference: A row-major a[m][k] = ha[m*K + k];
       B col-major b[k][n] = hb[n*K + k] (column n is contiguous).
       Pre-truncate inputs to TF32 precision so the CPU acc matches
       the GPU's Tensor Core multiply bit-for-bit. */
    for (int m = 0; m < M; ++m) {
        for (int n = 0; n < N; ++n) {
            float acc = 0.0f;
            for (int k = 0; k < K; ++k) {
                float av = tf32_truncate(ha[m * K + k]);
                float bv = tf32_truncate(hb[n * K + k]);
                acc += av * bv;
            }
            cref[m * N + n] = acc;
        }
    }

    CUdeviceptr da, db, dc;
    CHECK(cuMemAlloc(&da, ASZ * sizeof(float)));
    CHECK(cuMemAlloc(&db, BSZ * sizeof(float)));
    CHECK(cuMemAlloc(&dc, CSZ * sizeof(float)));
    CHECK(cuMemcpyHtoD(da, ha, ASZ * sizeof(float)));
    CHECK(cuMemcpyHtoD(db, hb, BSZ * sizeof(float)));

    void *kargs[3] = { &da, &db, &dc };
    CHECK(cuLaunchKernel(f, 1, 1, 1, 32, 1, 1, 0, NULL, kargs, NULL));
    CHECK(cuCtxSynchronize());
    CHECK(cuMemcpyDtoH(hc, dc, CSZ * sizeof(float)));

    /* Verify with tol=0; TF32 inputs are pre-truncated so multiply is exact. */
    float max_abs_cref = 0.0f;
    for (int i = 0; i < CSZ; ++i) if (fabsf(cref[i]) > max_abs_cref) max_abs_cref = fabsf(cref[i]);
    float tol_abs = 0.0f;

    float max_delta = 0.0f;
    int mismatches = 0;
    for (int i = 0; i < CSZ; ++i) {
        float d = fabsf(hc[i] - cref[i]);
        if (d > max_delta) max_delta = d;
        if (d > tol_abs) ++mismatches;
    }

    const char *verd = (mismatches == 0) ? "PASS" : "FAIL";
    printf("F-RFC067-TF32-NUMERIC %s -- M=%d N=%d K=%d max|d|=%g tol=%g mismatches=%d/%d max_abs_ref=%g\n",
        verd, M, N, K, max_delta, tol_abs, mismatches, CSZ, max_abs_cref);

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-P5-tf32\",\n");
    fprintf(rj, "  \"kernel\": \"tf32_gemm\",\n");
    fprintf(rj, "  \"falsifier\": \"F-RFC067-TF32-NUMERIC\",\n");
    fprintf(rj, "  \"mnemonic\": \"wmma.mma.sync.aligned.row.col.m16n16k8.f32.tf32.tf32.f32\",\n");
    fprintf(rj, "  \"verdict\": \"%s\",\n", verd);
    fprintf(rj, "  \"shape\": \"M=%d N=%d K=%d\",\n", M, N, K);
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
