// Standalone-cubin probe host. Demonstrates that a hexa-emit kernel can
// deploy WITHOUT linking libcublas / libcudart — the .cubin is embedded
// directly into this binary via xxd-generated `unop_cubin_data[]` +
// `unop_cubin_data_len`, loaded via cuModuleLoadData from the CUDA driver
// (libcuda.so.1), launched via cuLaunchKernel, copied via cuMemcpyHtoD/
// DtoH — every API surface lives in libcuda (the always-present driver).
//
// Numeric round-trip identical to INBOX #1665 / PR #1691:
//   kernel: out = ((-x) + 1.5) * -1.5    →    for x=-2.0:
//     step 1: -x = 2.0
//     step 2: 2.0 + 1.5 = 3.5
//     step 3: 3.5 * -1.5 = -5.25
//
// PASS = exact f64 equality (all rationals, no rounding error).
//
// Build:
//   ptxas -arch=sm_<NN> -o unop.cubin unop_wrapped.ptx
//   xxd -i unop.cubin > unop_cubin_data.h
//   sed -i 's/unop_cubin\[\]/unop_cubin_data[]/g; s/unop_cubin_len/unop_cubin_data_len/g' unop_cubin_data.h
//   cc -O2 -o gpu_standalone_cubin_host gpu_standalone_cubin_host.c -lcuda
//
// Link surface: -lcuda only. NOT -lcudart. NOT -lcublas.
//
// Cubin portability note: a .cubin binds to ONE compute capability. For
// multi-SM deploy either ship a fatbin (one cubin per arch) or ship PTX
// text + cuModuleLoadDataEx (driver JIT). The -lcuda-only link surface
// holds for both routes — this probe demonstrates route (a).

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cuda.h>

#include "unop_cubin_data.h"

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

    // Load the embedded cubin directly from the binary's data segment.
    // No file I/O, no PTX text, no driver-JIT — the cubin was already
    // ptxas-compiled at build time (AOT). cuModuleLoadData lives in
    // libcuda.so.1, so this works on any host with the NVIDIA driver
    // installed (no cuBLAS / cuDNN / cudart runtime needed).
    CUmodule mod;
    CHK(cuModuleLoadData(&mod, unop_cubin_data));

    CUfunction kfn;
    CHK(cuModuleGetFunction(&kfn, mod, "unop_neg_kernel"));

    CUdeviceptr d_in, d_out;
    CHK(cuMemAlloc(&d_in,  sizeof(double)));
    CHK(cuMemAlloc(&d_out, sizeof(double)));
    double x = -2.0;
    double y = 99.0;
    CHK(cuMemcpyHtoD(d_in,  &x, sizeof(double)));
    CHK(cuMemcpyHtoD(d_out, &y, sizeof(double)));

    void *args[] = { &d_out, &d_in };
    CHK(cuLaunchKernel(kfn, 1,1,1, 1,1,1, 0, NULL, args, NULL));
    CHK(cuCtxSynchronize());

    double got;
    CHK(cuMemcpyDtoH(&got, d_out, sizeof(double)));

    double want = -5.25;
    printf("standalone-cubin probe numeric round-trip:\n");
    printf("  cubin embedded size = %u bytes\n", unop_cubin_data_len);
    printf("  input   x = %.17g\n", x);
    printf("  want    y = %.17g\n", want);
    printf("  got     y = %.17g\n", got);
    if (got == want) {
        printf("  RESULT: PASS (exact f64 equality)\n");
        cuMemFree(d_in); cuMemFree(d_out);
        cuModuleUnload(mod);
        cuCtxDestroy(ctx);
        return 0;
    }
    printf("  RESULT: FAIL\n");
    return 1;
}
