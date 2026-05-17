/* tool/cuda_syntax_stub/cuda_runtime.h — NOT a build artifact.
 *
 * Minimal CUDA Runtime API stub for Mac no-GPU SYNTACTIC verification
 * of the HOST C in self/cuda/runtime_cuda.c (the `__CUDACC__`-guarded
 * __global__ kernel bodies are excluded under plain clang — those are
 * the nvcc/A100 path verified by the Phase 4-D-5-3 oracle + the
 * pre-approved d768 fire). This header lets
 *   clang -fsyntax-only -DHEXA_CUDA -Itool/cuda_syntax_stub -x c ...
 * type-check the H2D-skip / D2H-defer / dev-view residence logic
 * (RFC 056 §6.1-6.4) without a CUDA SDK. Declarations only; no GPU
 * semantics, no linkage.
 */
#ifndef _HX_STUB_CUDA_RUNTIME_H
#define _HX_STUB_CUDA_RUNTIME_H
#include <stddef.h>

/* Neutralize CUDA kernel-language tokens so the HOST C of
 * runtime_cuda.c type-checks under plain clang. The elementwise
 * __global__ block is `#ifdef HEXA_CUDA` (not `#ifdef __CUDACC__`) so
 * it is parsed even on Mac; these macros make it syntactically valid C
 * (the real device codegen is nvcc/A100 — Phase 4-D-5-3 oracle). The
 * <<<grid,block>>> launch syntax IS `#ifdef __CUDACC__`-only so it
 * stays excluded. */
#ifndef __CUDACC__
#define __global__
#define __device__
#define __host__
#define __forceinline__ inline
#define __restrict__ restrict
#define __shared__
static struct { unsigned x, y, z; } blockIdx, blockDim, threadIdx, gridDim;
static inline void __syncthreads(void) {}
static inline double __shfl_down_sync(unsigned m, double v, int o) {
    (void)m; (void)o; return v;
}
#endif

typedef int cudaError_t;
enum { cudaSuccess = 0 };
typedef int cudaMemcpyKind;
enum {
    cudaMemcpyHostToHost = 0,
    cudaMemcpyHostToDevice = 1,
    cudaMemcpyDeviceToHost = 2,
    cudaMemcpyDeviceToDevice = 3
};
typedef struct { unsigned int x, y, z; } dim3;

cudaError_t cudaMalloc(void** p, size_t n);
cudaError_t cudaFree(void* p);
cudaError_t cudaMemcpy(void* dst, const void* src, size_t n,
                       cudaMemcpyKind k);
cudaError_t cudaGetDeviceCount(int* n);
cudaError_t cudaDeviceSynchronize(void);
cudaError_t cudaGetLastError(void);
const char* cudaGetErrorString(cudaError_t e);

#endif /* _HX_STUB_CUDA_RUNTIME_H */
