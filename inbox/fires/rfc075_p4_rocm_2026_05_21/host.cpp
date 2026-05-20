/*
 * RFC 075 P4 — ROCm/HIP silicon-fire host (C++).
 *
 * Loads vec_add.hip kernel object (multi-TU hipcc build), runs the
 * `vec_add` kernel on N=1024 FP32 buffers, compares against a CPU
 * reference. Exit 0 if max|Δ|=0, else exit 1.
 *
 * Build:
 *   hipcc -O2 host.cpp vec_add.hip -o host
 * Run:
 *   ./host
 *
 * LCG seed matches the Metal P4 host (0xC0FFEE_DEADBEEF) so the input
 * stream is byte-identical across vendors. With a single FP32 add per
 * element and no FMA opportunity, both CPU and GPU produce IEEE 754
 * exact results -> max|Δ|=0 is the right gate (per @D g3 honest scope).
 */
#include <hip/hip_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

#define N 1024

static uint64_t lcg_state = 0xC0FFEEDEADBEEFULL;

static float lcg_next(void) {
    lcg_state = lcg_state * 6364136223846793005ULL + 1442695040888963407ULL;
    uint64_t mantissa = (lcg_state >> 40) & 0xFFFFFFULL;  // 24-bit
    return (float)mantissa / (float)(1U << 24);            // [0, 1)
}

#define HIP_CHECK(call) do {                                                  \
    hipError_t _e = (call);                                                   \
    if (_e != hipSuccess) {                                                   \
        fprintf(stderr, "FAIL: %s -> %s\n", #call, hipGetErrorString(_e));    \
        return 2;                                                             \
    }                                                                         \
} while (0)

extern "C" __global__ void vec_add(const float* a, const float* b, float* c, int n);

int main(void) {
    int device_id = 0;
    HIP_CHECK(hipSetDevice(device_id));

    hipDeviceProp_t prop;
    HIP_CHECK(hipGetDeviceProperties(&prop, device_id));
    printf("device: %s\n", prop.name);
    printf("arch: %s\n", prop.gcnArchName);
    printf("totalGlobalMem_GB: %.2f\n", (double)prop.totalGlobalMem / (1024.0 * 1024.0 * 1024.0));

    int driver_version = 0, runtime_version = 0;
    HIP_CHECK(hipDriverGetVersion(&driver_version));
    HIP_CHECK(hipRuntimeGetVersion(&runtime_version));
    printf("hip_driver_version: %d\n", driver_version);
    printf("hip_runtime_version: %d\n", runtime_version);

    float a_host[N], b_host[N], c_ref[N];
    for (int i = 0; i < N; i++) {
        a_host[i] = lcg_next() * 100.0f - 50.0f;
        b_host[i] = lcg_next() * 100.0f - 50.0f;
        c_ref[i]  = a_host[i] + b_host[i];
    }

    size_t bytes = N * sizeof(float);
    float *a_dev = NULL, *b_dev = NULL, *c_dev = NULL;
    HIP_CHECK(hipMalloc((void**)&a_dev, bytes));
    HIP_CHECK(hipMalloc((void**)&b_dev, bytes));
    HIP_CHECK(hipMalloc((void**)&c_dev, bytes));

    HIP_CHECK(hipMemcpy(a_dev, a_host, bytes, hipMemcpyHostToDevice));
    HIP_CHECK(hipMemcpy(b_dev, b_host, bytes, hipMemcpyHostToDevice));

    dim3 block(64, 1, 1);
    dim3 grid((N + block.x - 1) / block.x, 1, 1);
    hipLaunchKernelGGL(vec_add, grid, block, 0, 0, a_dev, b_dev, c_dev, N);
    HIP_CHECK(hipGetLastError());
    HIP_CHECK(hipDeviceSynchronize());

    float c_host[N];
    HIP_CHECK(hipMemcpy(c_host, c_dev, bytes, hipMemcpyDeviceToHost));

    float max_delta = 0.0f;
    int mismatches = 0;
    int first_i = -1;
    float first_gpu = 0, first_cpu = 0;
    for (int i = 0; i < N; i++) {
        float d = fabsf(c_host[i] - c_ref[i]);
        if (d > max_delta) max_delta = d;
        if (d != 0.0f) {
            if (mismatches == 0) {
                first_i = i;
                first_gpu = c_host[i];
                first_cpu = c_ref[i];
            }
            mismatches++;
        }
    }

    const char* verdict = (max_delta == 0.0f) ? "PASS" : "FAIL";
    printf("N: %d\n", N);
    printf("max_delta: %g\n", max_delta);
    printf("mismatches: %d\n", mismatches);
    if (first_i >= 0) {
        printf("first_mismatch: i=%d gpu=%g cpu=%g\n", first_i, first_gpu, first_cpu);
    }
    printf("verdict: %s\n", verdict);
    printf("samples: c[0]=%g ref[0]=%g; c[%d]=%g ref[%d]=%g\n",
           c_host[0], c_ref[0], N-1, c_host[N-1], N-1, c_ref[N-1]);
    printf("RESULT_JSON: {\"verdict\":\"%s\",\"max_delta\":%g,\"mismatches\":%d,\"N\":%d,\"device\":\"%s\",\"arch\":\"%s\"}\n",
           verdict, max_delta, mismatches, N, prop.name, prop.gcnArchName);

    hipFree(a_dev);
    hipFree(b_dev);
    hipFree(c_dev);

    return (max_delta == 0.0f) ? 0 : 1;
}
