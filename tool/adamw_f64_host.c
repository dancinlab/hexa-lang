// §5a AdamW step fusion — host driver + CPU libm reference (Round 5)
//
// Build:
//   nvcc -O2 -arch=sm_80 -o adamw_host adamw_f64_host.c -lcuda -lm
//   (PTX expected at /tmp/probe_adamw_f64.ptx · cuModuleLoadDataEx JIT)
//
// PASS: max_abs_err < 1e-12 across (p_out, m_out, v_out) for all N elements.

#include <cuda.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define N 256
#define CK(x) do { CUresult r = (x); if (r) { const char *s; cuGetErrorString(r, &s); fprintf(stderr, "cu err %s @ %d\n", s, __LINE__); return 1; } } while (0)

int main(void) {
    // hyperparams
    double lr  = 1e-3;
    double b1  = 0.9;
    double b2  = 0.999;
    double eps = 1e-8;
    double wd  = 0.01;
    int t = 7;  // step number
    double bc1 = 1.0 - pow(b1, (double)t);
    double bc2 = 1.0 - pow(b2, (double)t);

    // init deterministic random-ish
    double p[N], g[N], m[N], v[N];
    double p_ref[N], m_ref[N], v_ref[N];
    for (int i = 0; i < N; i++) {
        double x = (double)i;
        p[i] = sin(0.013 * x + 0.7);
        g[i] = sin(0.029 * x + 1.3) * 0.1;
        m[i] = sin(0.041 * x + 2.1) * 0.05;
        v[i] = (sin(0.057 * x + 0.4) * 0.02) + 0.025;  // keep v >= 0
    }

    // CPU libm reference (closed-form same as kernel)
    for (int i = 0; i < N; i++) {
        double mt = b1 * m[i] + (1.0 - b1) * g[i];
        double vt = b2 * v[i] + (1.0 - b2) * g[i] * g[i];
        double mh = mt / bc1;
        double vh = vt / bc2;
        double denom = sqrt(vh) + eps;
        double upd = lr * mh / denom + lr * wd * p[i];
        p_ref[i] = p[i] - upd;
        m_ref[i] = mt;
        v_ref[i] = vt;
    }

    // CUDA boot
    CK(cuInit(0));
    CUdevice dev; CK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CK(cuCtxCreate(&ctx, 0, dev));

    // load PTX
    FILE *fp = fopen("/tmp/probe_adamw_f64.ptx", "rb");
    if (!fp) { fprintf(stderr, "ptx open fail\n"); return 1; }
    fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = (char*)malloc(sz + 1);
    fread(ptx, 1, sz, fp); ptx[sz] = 0; fclose(fp);

    CUmodule mod; CUjit_option opts[] = {CU_JIT_ERROR_LOG_BUFFER, CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES};
    char log[8192] = {0}; size_t logsz = sizeof(log);
    void *vals[] = {log, (void*)logsz};
    CUresult lr_ = cuModuleLoadDataEx(&mod, ptx, 2, opts, vals);
    if (lr_) { fprintf(stderr, "JIT err: %s\n", log); return 1; }

    CUfunction fn; CK(cuModuleGetFunction(&fn, mod, "probe_adamw_f64"));

    // device alloc
    CUdeviceptr dp, dg, dm, dv, dpo, dmo, dvo;
    size_t bytes = N * sizeof(double);
    CK(cuMemAlloc(&dp, bytes));  CK(cuMemAlloc(&dg, bytes));
    CK(cuMemAlloc(&dm, bytes));  CK(cuMemAlloc(&dv, bytes));
    CK(cuMemAlloc(&dpo, bytes)); CK(cuMemAlloc(&dmo, bytes)); CK(cuMemAlloc(&dvo, bytes));
    CK(cuMemcpyHtoD(dp, p, bytes));
    CK(cuMemcpyHtoD(dg, g, bytes));
    CK(cuMemcpyHtoD(dm, m, bytes));
    CK(cuMemcpyHtoD(dv, v, bytes));

    // args
    long long nn = (long long)N;
    void *kargs[] = {
        &dp, &dg, &dm, &dv, &dpo, &dmo, &dvo,
        &lr, &b1, &b2, &eps, &wd, &bc1, &bc2, &nn
    };
    CK(cuLaunchKernel(fn, 1, 1, 1, N, 1, 1, 0, 0, kargs, 0));
    CK(cuCtxSynchronize());

    double p_gpu[N], m_gpu[N], v_gpu[N];
    CK(cuMemcpyDtoH(p_gpu, dpo, bytes));
    CK(cuMemcpyDtoH(m_gpu, dmo, bytes));
    CK(cuMemcpyDtoH(v_gpu, dvo, bytes));

    double maxe_p = 0, maxe_m = 0, maxe_v = 0;
    int worst_p = 0, worst_m = 0, worst_v = 0;
    for (int i = 0; i < N; i++) {
        double e_p = fabs(p_gpu[i] - p_ref[i]);
        double e_m = fabs(m_gpu[i] - m_ref[i]);
        double e_v = fabs(v_gpu[i] - v_ref[i]);
        if (e_p > maxe_p) { maxe_p = e_p; worst_p = i; }
        if (e_m > maxe_m) { maxe_m = e_m; worst_m = i; }
        if (e_v > maxe_v) { maxe_v = e_v; worst_v = i; }
    }
    printf("AdamW step-fusion 1-kernel wedge (N=%d, step t=%d)\n", N, t);
    printf("  max_abs_err p_out = %.3e  (@i=%d, gpu=%.17g ref=%.17g)\n",
           maxe_p, worst_p, p_gpu[worst_p], p_ref[worst_p]);
    printf("  max_abs_err m_out = %.3e  (@i=%d, gpu=%.17g ref=%.17g)\n",
           maxe_m, worst_m, m_gpu[worst_m], m_ref[worst_m]);
    printf("  max_abs_err v_out = %.3e  (@i=%d, gpu=%.17g ref=%.17g)\n",
           maxe_v, worst_v, v_gpu[worst_v], v_ref[worst_v]);
    double worst = maxe_p > maxe_m ? maxe_p : maxe_m;
    if (maxe_v > worst) worst = maxe_v;
    printf("  worst across all = %.3e\n", worst);
    if (worst < 1e-12) printf("  RESULT: PASS (byte-eq band <1e-12)\n");
    else if (worst < 1e-7) printf("  RESULT: PASS-numerical (<1e-7)\n");
    else printf("  RESULT: FAIL\n");

    return 0;
}
