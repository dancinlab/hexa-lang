// Host driver for reduce_sum kernel: load PTX, copy 1024 f64 inputs, launch 1 thread.
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
    
    // Read PTX file
    FILE *f = fopen(argv[1], "rb");
    if (!f) { fprintf(stderr, "Cannot open PTX file: %s\n", argv[1]); return 1; }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *ptx = malloc(sz + 1);
    fread(ptx, 1, sz, f);
    ptx[sz] = '\0';
    fclose(f);
    
    // CUDA init
    CHECK(cuInit(0));
    CUdevice dev;
    CHECK(cuDeviceGet(&dev, 0));
    char dev_name[128];
    CHECK(cuDeviceGetName(dev_name, sizeof(dev_name), dev));
    fprintf(stderr, "Device: %s\n", dev_name);
    CUcontext ctx;
    CHECK(cuCtxCreate(&ctx, 0, dev));
    
    // Load PTX module with JIT options for better diagnostics
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
        return 1;
    }
    fprintf(stderr, "PTX loaded OK\n");
    
    CUfunction kernel;
    CHECK(cuModuleGetFunction(&kernel, module, "reduce_sum"));
    fprintf(stderr, "Kernel reduce_sum resolved\n");
    
    // Prepare buffers
    const long N = 1024;
    double *a_host = malloc(N * sizeof(double));
    double *out_host = malloc(sizeof(double));
    double expected = 0.0;
    for (long i = 0; i < N; i++) {
        // Use small floats so sum is exact: 1/N + 2/N + ... + N/N
        a_host[i] = (double)(i + 1) / (double)N;
        expected += a_host[i];
    }
    out_host[0] = -1.0;
    
    CUdeviceptr a_dev, out_dev;
    CHECK(cuMemAlloc(&a_dev, N * sizeof(double)));
    CHECK(cuMemAlloc(&out_dev, sizeof(double)));
    CHECK(cuMemcpyHtoD(a_dev, a_host, N * sizeof(double)));
    
    // Launch 1 thread
    long n_arg = N;
    void *args[] = { &a_dev, &out_dev, &n_arg };
    CHECK(cuLaunchKernel(kernel,
        1, 1, 1,   // grid 1x1x1
        1, 1, 1,   // block 1x1x1
        0, 0, args, 0));
    CHECK(cuCtxSynchronize());
    
    // Read back
    CHECK(cuMemcpyDtoH(out_host, out_dev, sizeof(double)));
    
    double got = out_host[0];
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
