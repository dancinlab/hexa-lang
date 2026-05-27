// Numeric round-trip for INBOX #1665 closure. Loads the wrapped PTX
// kernel via cuModuleLoadDataEx + driver JIT (sm_80 → sm_120 forward-
// compat), launches it with input -2.0, checks output equals -5.25.
//
// kernel: out = ((-x) + 1.5) * -1.5    →    for x=-2.0:
//   step 1: -x = -(-2.0) = 2.0       (register-neg emit)
//   step 2: 2.0 + 1.5 = 3.5          (const_float +1.5 hex)
//   step 3: 3.5 * -1.5 = -5.25       (const_float -1.5 hex, bug #1663)
//
// PASS = numerically exact equality (these are all rationals, no
// rounding error at f64).

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cuda.h>

#define CHK(call) do { \
    CUresult r = (call); \
    if (r != CUDA_SUCCESS) { \
        const char *m; cuGetErrorString(r, &m); \
        fprintf(stderr, "CUDA err %d: %s at %s:%d\n", r, m, __FILE__, __LINE__); \
        return 1; \
    } \
} while (0)

int main(void) {
    CHK(cuInit(0));
    CUdevice dev;
    CHK(cuDeviceGet(&dev, 0));
    CUcontext ctx;
    CHK(cuCtxCreate(&ctx, 0, dev));

    // Read the wrapped PTX.
    FILE *f = fopen("/tmp/unop_wrapped.ptx", "r");
    if (!f) { perror("open ptx"); return 1; }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *ptx = malloc(n + 1);
    fread(ptx, 1, n, f);
    ptx[n] = 0;
    fclose(f);

    CUmodule mod;
    char err_log[8192]; err_log[0] = 0;
    CUjit_option opts[3] = {
        CU_JIT_ERROR_LOG_BUFFER,
        CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_LOG_VERBOSE
    };
    unsigned int log_sz = sizeof(err_log);
    void *vals[3] = { err_log, (void*)(uintptr_t)log_sz, (void*)(uintptr_t)1 };
    CUresult r = cuModuleLoadDataEx(&mod, ptx, 3, opts, vals);
    if (r != CUDA_SUCCESS) {
        const char *m; cuGetErrorString(r, &m);
        fprintf(stderr, "cuModuleLoadDataEx err %d: %s\n", r, m);
        fprintf(stderr, "JIT err log:\n%s\n", err_log);
        return 1;
    }
    CUfunction kfn;
    CHK(cuModuleGetFunction(&kfn, mod, "unop_neg_kernel"));

    CUdeviceptr d_in, d_out;
    CHK(cuMemAlloc(&d_in,  sizeof(double)));
    CHK(cuMemAlloc(&d_out, sizeof(double)));
    double x = -2.0;
    double y = 99.0;
    CHK(cuMemcpyHtoD(d_in, &x, sizeof(double)));
    CHK(cuMemcpyHtoD(d_out, &y, sizeof(double)));

    void *args[] = { &d_out, &d_in };
    CHK(cuLaunchKernel(kfn, 1,1,1, 1,1,1, 0, NULL, args, NULL));
    CHK(cuCtxSynchronize());

    double got;
    CHK(cuMemcpyDtoH(&got, d_out, sizeof(double)));

    double want = -5.25;
    printf("INBOX #1665 numeric round-trip:\n");
    printf("  input   x = %.17g\n", x);
    printf("  want    y = %.17g\n", want);
    printf("  got     y = %.17g\n", got);
    if (got == want) {
        printf("  RESULT: PASS (exact f64 equality)\n");
        cuMemFree(d_in); cuMemFree(d_out);
        cuModuleUnload(mod);
        cuCtxDestroy(ctx);
        free(ptx);
        return 0;
    }
    printf("  RESULT: FAIL\n");
    return 1;
}
