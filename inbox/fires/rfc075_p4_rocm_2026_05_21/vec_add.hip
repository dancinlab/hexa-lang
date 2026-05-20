// RFC 075 P4 — ROCm/HIP silicon-fire kernel.
// Compiled with hipcc on AMD Instinct MI300X (gfx942) inside RunPod
// rocm/pytorch container.
//
// Provenance: hand-written to match the canonical RFC 075 ROCm emitter
// contract (compiler/codegen/rocm_target.hexa). Emit-body wiring is a
// separate cycle; this fire only proves the HIP toolchain + numeric path.
#include <hip/hip_runtime.h>

extern "C" __global__ void vec_add(const float* a, const float* b, float* c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        c[i] = a[i] + b[i];
    }
}
