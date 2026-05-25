/* F-FUSION-EPILOGUE-GEMM-BIAS-GELU -- FUSED hexa-emit kernel host launcher.
 *
 * Loads the hand-emitted fused_gemm_bias_gelu.ptx (the GEMM + bias-add + GeLU
 * epilogue fused into ONE kernel) and launches it ONCE, writing the M x N
 * result C to HBM EXACTLY ONCE. Compares against an f64 CPU reference.
 *
 * Driver API (cuModuleLoadDataEx) -- same pattern as tool/r067_p4_host.c.
 * Single launch:  cuLaunchKernel(f, gx, gy, 1, 16, 16, 1, ...)
 *   gx = ceil(N/16), gy = ceil(M/16), block = 16 x 16 threads.
 *
 * Tolerance: rel-err <= 1e-2 (matches the falsifier's correctness gate; the
 * ex2.approx/rcp.approx GeLU path is single-precision-approximate, well
 * within 1e-2 of the f64 reference).
 *
 * Build:  nvcc -O2 -o fusion_fused fusion_epilogue_fused_host.c -lcuda
 * Run:    ./fusion_fused fused_gemm_bias_gelu.ptx M N K   (default 256 256 256)
 */
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define CK(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA error %d at %s:%d: %s\n", e, __FILE__, __LINE__, s ? s : "?"); \
        return 1; }} while (0)

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s fused.ptx [M N K]\n", argv[0]); return 2; }
    const char *ptx_path = argv[1];
    int M = (argc > 2) ? atoi(argv[2]) : 256;
    int N = (argc > 3) ? atoi(argv[3]) : 256;
    int K = (argc > 4) ? atoi(argv[4]) : 256;

    FILE *fp = fopen(ptx_path, "rb");
    if (!fp) { perror("ptx open"); return 1; }
    fseek(fp, 0, SEEK_END); long np = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(np + 1);
    fread(ptx, 1, np, fp); ptx[np] = 0; fclose(fp);

    CK(cuInit(0));
    CUdevice dev; CK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CK(cuCtxCreate(&ctx, 0, dev));
    CUmodule mod;
    CUjit_option jo[1] = { CU_JIT_TARGET_FROM_CUCONTEXT };
    void *jv[1] = { (void *)0 };
    CK(cuModuleLoadDataEx(&mod, ptx, 1, jo, jv));
    CUfunction f; CK(cuModuleGetFunction(&f, mod, "fused_gemm_bias_gelu"));

    size_t szA = (size_t)M * K * sizeof(float);
    size_t szB = (size_t)K * N * sizeof(float);
    size_t szC = (size_t)M * N * sizeof(float);
    size_t szBias = (size_t)N * sizeof(float);

    float *hA = (float *)malloc(szA);
    float *hB = (float *)malloc(szB);
    float *hBias = (float *)malloc(szBias);
    float *hC = (float *)malloc(szC);
    for (int i = 0; i < M * K; ++i) hA[i] = (float)((i % 7) - 3) * 0.1f;
    for (int i = 0; i < K * N; ++i) hB[i] = (float)((i % 5) - 2) * 0.1f;
    for (int i = 0; i < N; ++i)     hBias[i] = (float)((i % 3) - 1) * 0.5f;

    CUdeviceptr dA, dB, dBias, dC;
    CK(cuMemAlloc(&dA, szA));
    CK(cuMemAlloc(&dB, szB));
    CK(cuMemAlloc(&dBias, szBias));
    CK(cuMemAlloc(&dC, szC));
    CK(cuMemcpyHtoD(dA, hA, szA));
    CK(cuMemcpyHtoD(dB, hB, szB));
    CK(cuMemcpyHtoD(dBias, hBias, szBias));

    /* ===== single fused launch -- writes M x N result to HBM ONCE ===== */
    void *kargs[7] = { &dA, &dB, &dBias, &dC, &M, &N, &K };
    unsigned gx = (N + 15) / 16, gy = (M + 15) / 16;
    CK(cuLaunchKernel(f, gx, gy, 1, 16, 16, 1, 0, NULL, kargs, NULL));
    CK(cuCtxSynchronize());
    CK(cuMemcpyDtoH(hC, dC, szC));

    /* f64 CPU reference (sampled for large shapes). */
    int total = M * N;
    int step = (total > 4096) ? (total / 4096) : 1;
    double max_rel = 0.0, max_abs = 0.0; int checked = 0;
    for (int idx = 0; idx < total; idx += step) {
        int m = idx / N, n = idx % N;
        double acc = 0.0;
        for (int k = 0; k < K; ++k)
            acc += (double)hA[m * K + k] * (double)hB[k * N + n];
        double x = acc + (double)hBias[n];
        double t = 0.7978845608028654 * (x + 0.044715 * x * x * x);
        double g = 0.5 * x * (1.0 + tanh(t));
        double d = fabs((double)hC[idx] - g);
        double rel = d / (fabs(g) + 1e-6);
        if (d > max_abs) max_abs = d;
        if (rel > max_rel) max_rel = rel;
        ++checked;
    }

    const char *verd = (max_rel <= 1e-2) ? "PASS" : "FAIL";
    printf("F-FUSION-EPILOGUE-GEMM-BIAS-GELU fused %s -- shape M=%d N=%d K=%d "
           "launches=1 hbm_C_writes=1 max_rel=%g max_abs=%g checked=%d/%d\n",
           verd, M, N, K, max_rel, max_abs, checked, total);

    FILE *rj = fopen("result_fused.json", "w");
    if (rj) {
        fprintf(rj, "{\n  \"falsifier\": \"F-FUSION-EPILOGUE-GEMM-BIAS-GELU\",\n");
        fprintf(rj, "  \"kernel\": \"fused_gemm_bias_gelu\",\n");
        fprintf(rj, "  \"verdict\": \"%s\",\n", verd);
        fprintf(rj, "  \"shape\": \"%dx%dx%d\",\n", M, N, K);
        fprintf(rj, "  \"launches\": 1,\n  \"hbm_C_writes\": 1,\n");
        fprintf(rj, "  \"max_rel\": %g,\n  \"max_abs\": %g,\n", max_rel, max_abs);
        fprintf(rj, "  \"checked\": %d\n}\n", checked);
        fclose(rj);
    }

    cuMemFree(dA); cuMemFree(dB); cuMemFree(dBias); cuMemFree(dC);
    cuModuleUnload(mod); cuCtxDestroy(ctx);
    return (max_rel <= 1e-2) ? 0 : 1;
}
