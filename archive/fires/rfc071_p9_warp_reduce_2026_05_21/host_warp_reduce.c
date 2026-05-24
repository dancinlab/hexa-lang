// Host driver for warp_reduce_sum kernel.
// N=1024 FP64 array, single block of 1024 threads = 32 warps.
// Each warp emits one lane-0 output; CPU references sum entire array
// sequentially. Sum-of-warp-outputs must equal CPU sum within 4 ULP
// (FP64 add-order tolerance — accumulation order differs).
//
// Honest scope: emitted PTX has 3 codegen gaps (gpu_warp_shuffle_xor
// builtin not wired + integer `/` binop not wired). Expected outcome
// of this fire is `cuModuleLoadDataEx` FAIL with ptxas error — the
// artifact is the JIT err log proving the gap surface, not a numeric
// PASS. See ../warp_reduce_sum.sm_80.ptx for the gap markers.
//
// If the gaps were closed in a follow-on cycle (compiler-source edit),
// running this same host would emit either a numeric PASS or a
// localized FAIL (numeric or launch) — to be decided that cycle.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <cuda.h>

#define CHECK(call) do { \
    CUresult _e = (call); \
    if (_e != CUDA_SUCCESS) { \
        const char *_es; cuGetErrorString(_e, &_es); \
        fprintf(stderr, "ERROR %s:%d: %s\n", __FILE__, __LINE__, _es); \
        exit(1); \
    } \
} while (0)

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <ptx_path>\n", argv[0]); return 1; }

    FILE *f = fopen(argv[1], "rb");
    if (!f) { fprintf(stderr, "Cannot open PTX file: %s\n", argv[1]); return 1; }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *ptx = malloc(sz + 1);
    fread(ptx, 1, sz, f);
    ptx[sz] = '\0';
    fclose(f);

    CHECK(cuInit(0));
    CUdevice dev;
    CHECK(cuDeviceGet(&dev, 0));
    char dev_name[128];
    CHECK(cuDeviceGetName(dev_name, sizeof(dev_name), dev));
    fprintf(stderr, "Device: %s\n", dev_name);
    CUcontext ctx;
    CHECK(cuCtxCreate(&ctx, 0, dev));

    CUmodule module;
    char jit_log[8192] = {0};
    char jit_err[8192] = {0};
    CUjit_option opts[] = {
        CU_JIT_INFO_LOG_BUFFER,
        CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_ERROR_LOG_BUFFER,
        CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
    };
    void *vals[] = {
        jit_log, (void*)(size_t)sizeof(jit_log),
        jit_err, (void*)(size_t)sizeof(jit_err),
    };
    CUresult r = cuModuleLoadDataEx(&module, ptx, 4, opts, vals);
    if (jit_log[0]) fprintf(stderr, "JIT info: %s\n", jit_log);
    if (jit_err[0]) fprintf(stderr, "JIT err: %s\n", jit_err);
    if (r != CUDA_SUCCESS) {
        const char *es; cuGetErrorString(r, &es);
        fprintf(stderr, "cuModuleLoadDataEx FAIL: %s\n", es);
        printf("BLOCKED: PTX gaps prevent load (gpu_warp_shuffle_xor + `/` binop)\n");
        return 2;
    }
    fprintf(stderr, "PTX loaded OK\n");

    CUfunction kernel;
    CHECK(cuModuleGetFunction(&kernel, module, "warp_reduce_sum"));
    fprintf(stderr, "Kernel warp_reduce_sum resolved\n");

    const long N = 1024;
    const long NWARPS = 32;
    double *a_host = malloc(N * sizeof(double));
    double *out_host = malloc(NWARPS * sizeof(double));
    double expected = 0.0;
    // LCG-deterministic, exactly representable as in N64 (i+1)/N pattern
    // for tightest cmp; N64 used (i+1)/N → expected=512.5 for N=1024.
    for (long i = 0; i < N; i++) {
        a_host[i] = (double)(i + 1) / (double)N;
        expected += a_host[i];
    }
    for (long w = 0; w < NWARPS; w++) out_host[w] = 0.0;

    CUdeviceptr a_dev, out_dev;
    CHECK(cuMemAlloc(&a_dev, N * sizeof(double)));
    CHECK(cuMemAlloc(&out_dev, NWARPS * sizeof(double)));
    CHECK(cuMemcpyHtoD(a_dev, a_host, N * sizeof(double)));
    CHECK(cuMemcpyHtoD(out_dev, out_host, NWARPS * sizeof(double)));

    long n_arg = N;
    void *args[] = { &a_dev, &out_dev, &n_arg };
    // 1 block × 1024 threads = 32 warps × 32 lanes
    CHECK(cuLaunchKernel(kernel,
        1, 1, 1,        // grid
        1024, 1, 1,     // block
        0, 0, args, 0));
    CHECK(cuCtxSynchronize());

    CHECK(cuMemcpyDtoH(out_host, out_dev, NWARPS * sizeof(double)));

    double got = 0.0;
    for (long w = 0; w < NWARPS; w++) {
        fprintf(stderr, "  warp[%2ld] = %.17g\n", w, out_host[w]);
        got += out_host[w];
    }
    double abs_err = fabs(got - expected);
    double ulp = abs_err / fmax(fabs(expected), 1e-300) / 2.22e-16;

    fprintf(stderr, "expected = %.17g\n", expected);
    fprintf(stderr, "got      = %.17g\n", got);
    fprintf(stderr, "abs_err  = %.4e\n", abs_err);
    fprintf(stderr, "ulp_err  = %.4f\n", ulp);

    if (ulp <= 4.0) {
        printf("PASS: ulp_err=%.4f\n", ulp);
        return 0;
    } else {
        printf("FAIL: ulp_err=%.4f (>4 ULP)\n", ulp);
        return 1;
    }
}
