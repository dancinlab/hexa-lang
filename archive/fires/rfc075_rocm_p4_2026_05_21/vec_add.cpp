// RFC 075 ROCm P4 — silicon-fire vec-add HIP kernel
//
// Hand-emit mirror of what `codegen_emit_rocm_il` (compiler/codegen/rocm_target.hexa)
// would produce for a vec-add MIR module once P1-P3 land. Same MIR pattern
// that the NVPTX (RFC 055) and Metal (RFC 075 Metal P3 commit a1a2a8fa) paths
// also handle.
//
// Compile: hipcc vec_add.cpp -o vec_add
// Run:     ./vec_add
//
// @D g3 — Hand-emit, NOT codegen-produced. ROCm codegen P1+ remains future
// work. This fire proves the AMD silicon path is open (hipcc toolchain + GPU)
// for follow-on codegen wiring.

#include <hip/hip_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cstring>

// ── Kernel — mirrors codegen pattern (matches NVPTX vec_add + Metal vec_add)
__global__ void vec_add(const float* __restrict__ a,
                        const float* __restrict__ b,
                        float* __restrict__ c,
                        int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        c[i] = a[i] + b[i];
    }
}

// ── LCG-deterministic FP32 generator (matches Metal P4 fire pattern)
static uint32_t lcg_state = 0x12345678u;
static float lcg_float() {
    lcg_state = lcg_state * 1664525u + 1013904223u;
    // map u32 → [-1.0, 1.0] FP32, deterministic
    uint32_t bits = (lcg_state & 0x007FFFFFu) | 0x3F800000u; // [1.0, 2.0)
    float f;
    std::memcpy(&f, &bits, sizeof(f));
    return (f - 1.5f) * 2.0f; // [-1.0, 1.0)
}

#define HIP_CHECK(call) do {                                            \
    hipError_t _e = (call);                                             \
    if (_e != hipSuccess) {                                             \
        std::fprintf(stderr, "HIP error %d at %s:%d: %s\n",             \
                     (int)_e, __FILE__, __LINE__,                       \
                     hipGetErrorString(_e));                            \
        std::exit(2);                                                   \
    }                                                                   \
} while (0)

int main() {
    const int N = 1024;
    const size_t bytes = N * sizeof(float);

    // Host buffers
    float* h_a   = (float*)std::malloc(bytes);
    float* h_b   = (float*)std::malloc(bytes);
    float* h_c   = (float*)std::malloc(bytes);
    float* h_ref = (float*)std::malloc(bytes);

    for (int i = 0; i < N; ++i) {
        h_a[i] = lcg_float();
        h_b[i] = lcg_float();
        h_ref[i] = h_a[i] + h_b[i]; // CPU reference (single FP32 add, no fma contract)
    }

    // Device buffers
    float *d_a = nullptr, *d_b = nullptr, *d_c = nullptr;
    HIP_CHECK(hipMalloc((void**)&d_a, bytes));
    HIP_CHECK(hipMalloc((void**)&d_b, bytes));
    HIP_CHECK(hipMalloc((void**)&d_c, bytes));

    HIP_CHECK(hipMemcpy(d_a, h_a, bytes, hipMemcpyHostToDevice));
    HIP_CHECK(hipMemcpy(d_b, h_b, bytes, hipMemcpyHostToDevice));

    // Launch: 1024 threads / 4 blocks of 256
    const int threads = 256;
    const int blocks = (N + threads - 1) / threads;
    hipLaunchKernelGGL(vec_add, dim3(blocks), dim3(threads), 0, 0,
                       d_a, d_b, d_c, N);
    HIP_CHECK(hipGetLastError());
    HIP_CHECK(hipDeviceSynchronize());

    HIP_CHECK(hipMemcpy(h_c, d_c, bytes, hipMemcpyDeviceToHost));

    // Byte-eq comparison
    int byte_mismatch = 0;
    float max_abs_diff = 0.0f;
    for (int i = 0; i < N; ++i) {
        uint32_t bc, br;
        std::memcpy(&bc, &h_c[i], sizeof(bc));
        std::memcpy(&br, &h_ref[i], sizeof(br));
        if (bc != br) byte_mismatch++;
        float d = h_c[i] - h_ref[i];
        if (d < 0) d = -d;
        if (d > max_abs_diff) max_abs_diff = d;
    }

    // Device props
    hipDeviceProp_t prop;
    HIP_CHECK(hipGetDeviceProperties(&prop, 0));

    std::printf("RFC 075 ROCm P4 silicon-fire\n");
    std::printf("  device:           %s\n", prop.name);
    std::printf("  gcnArchName:      %s\n", prop.gcnArchName);
    std::printf("  multiProcessors:  %d\n", prop.multiProcessorCount);
    std::printf("  N:                %d\n", N);
    std::printf("  max_abs_diff:     %.9g\n", (double)max_abs_diff);
    std::printf("  byte_mismatch:    %d / %d\n", byte_mismatch, N);
    std::printf("  status:           %s\n",
                (byte_mismatch == 0) ? "PASS (byte-identical)" : "FAIL");

    HIP_CHECK(hipFree(d_a));
    HIP_CHECK(hipFree(d_b));
    HIP_CHECK(hipFree(d_c));
    std::free(h_a); std::free(h_b); std::free(h_c); std::free(h_ref);

    return (byte_mismatch == 0) ? 0 : 1;
}
