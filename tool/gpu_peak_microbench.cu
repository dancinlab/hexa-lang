/* gpu_peak_microbench - achieved-peak microbench for the GPU-ROOFLINE stand.
 *
 * Measures, on the resident device, three achieved-peak denominators:
 *   1. HBM bandwidth (GB/s)       - grid-stride read+write STREAM-style copy
 *   2. FP32 FMA-bound peak (TFLOP/s) - register-resident FMA chain, no memory
 *   3. FP16 (half2) FMA-bound peak (TFLOP/s)
 *
 * theoretical specs are printed side by side (no gap hiding). ASCII only.
 *
 * Build: nvcc -O3 -arch=sm_120 -o gpu_peak_microbench gpu_peak_microbench.cu
 *   (falls back to default arch if sm_120 unsupported by this nvcc)
 * Run:   ./gpu_peak_microbench
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <stdio.h>
#include <stdlib.h>

#define CK(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { fprintf(stderr, "CUDA error %s at %s:%d\n", \
        cudaGetErrorString(e), __FILE__, __LINE__); return 1; }} while (0)

static int cmp_d(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

/* STREAM-style copy: dst[i] = src[i] (read + write traffic). */
__global__ void copy_kernel(const float *src, float *dst, size_t n) {
    size_t i = blockIdx.x * (size_t)blockDim.x + threadIdx.x;
    size_t stride = (size_t)gridDim.x * blockDim.x;
    for (; i < n; i += stride) dst[i] = src[i];
}

/* FP32 FMA peak: long register-resident FMA chain, no memory traffic. */
__global__ void fma_f32_kernel(float *out, int iters) {
    float a = (float)(threadIdx.x & 7) * 0.1f + 1.0f;
    float b = (float)(blockIdx.x & 7) * 0.1f + 1.0f;
    float c0 = 0.0f, c1 = 0.1f, c2 = 0.2f, c3 = 0.3f;
    for (int i = 0; i < iters; ++i) {
        c0 = fmaf(a, b, c0); c1 = fmaf(a, b, c1);
        c2 = fmaf(a, b, c2); c3 = fmaf(a, b, c3);
    }
    if ((c0 + c1 + c2 + c3) == -1.0f) out[blockIdx.x * blockDim.x + threadIdx.x] = c0;
}

/* FP16 (half2) FMA peak. */
__global__ void fma_f16_kernel(__half *out, int iters) {
    half2 a = __floats2half2_rn((float)(threadIdx.x & 7) * 0.1f + 1.0f, 1.0f);
    half2 b = __floats2half2_rn((float)(blockIdx.x & 7) * 0.1f + 1.0f, 1.0f);
    half2 c0 = __floats2half2_rn(0.0f, 0.0f);
    half2 c1 = __floats2half2_rn(0.1f, 0.1f);
    half2 c2 = __floats2half2_rn(0.2f, 0.2f);
    half2 c3 = __floats2half2_rn(0.3f, 0.3f);
    for (int i = 0; i < iters; ++i) {
        c0 = __hfma2(a, b, c0); c1 = __hfma2(a, b, c1);
        c2 = __hfma2(a, b, c2); c3 = __hfma2(a, b, c3);
    }
    half2 s = __hadd2(__hadd2(c0, c1), __hadd2(c2, c3));
    if (__low2float(s) == -1.0f) out[blockIdx.x * blockDim.x + threadIdx.x] = __low2half(s);
}

int main(void) {
    cudaDeviceProp prop;
    CK(cudaGetDeviceProperties(&prop, 0));
    printf("# device: %s  (sm_%d%d, %d SMs, %.0f MHz, mem %.0f MHz x %d-bit)\n",
           prop.name, prop.major, prop.minor, prop.multiProcessorCount,
           prop.clockRate / 1000.0, prop.memoryClockRate / 1000.0,
           prop.memoryBusWidth);
    double theo_bw = 2.0 * (prop.memoryClockRate * 1e3) * (prop.memoryBusWidth / 8) / 1e9;
    printf("# theoretical HBM BW (mem_clk x bus/8 x2) = %.1f GB/s\n", theo_bw);

    cudaEvent_t e0, e1;
    CK(cudaEventCreate(&e0));
    CK(cudaEventCreate(&e1));

    /* === 1. HBM bandwidth === */
    {
        const size_t N = 64ULL * 1024 * 1024;  /* 64M floats = 256 MB each */
        float *src, *dst;
        CK(cudaMalloc((void **)&src, N * sizeof(float)));
        CK(cudaMalloc((void **)&dst, N * sizeof(float)));
        CK(cudaMemset(src, 1, N * sizeof(float)));
        int block = 256, grid = prop.multiProcessorCount * 32;
        for (int i = 0; i < 10; ++i) copy_kernel<<<grid, block>>>(src, dst, N);
        CK(cudaDeviceSynchronize());
        const int IT = 100;
        double *s = (double *)malloc(IT * sizeof(double));
        for (int i = 0; i < IT; ++i) {
            CK(cudaEventRecord(e0, 0));
            copy_kernel<<<grid, block>>>(src, dst, N);
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms; CK(cudaEventElapsedTime(&ms, e0, e1));
            s[i] = ms;
        }
        qsort(s, IT, sizeof(double), cmp_d);
        double med = s[IT / 2];
        double gbps = 2.0 * N * sizeof(float) / (med * 1e-3) / 1e9;  /* read+write */
        printf("BW_achieved_GBps %.2f  (median %.4f ms, %.1f%% of theoretical)\n",
               gbps, med, 100.0 * gbps / theo_bw);
        cudaFree(src); cudaFree(dst); free(s);
    }

    /* === 2. FP32 FMA peak === */
    {
        int block = 256, grid = prop.multiProcessorCount * 64;
        int iters = 8192;
        float *out; CK(cudaMalloc((void **)&out, (size_t)grid * block * sizeof(float)));
        for (int i = 0; i < 5; ++i) fma_f32_kernel<<<grid, block>>>(out, iters);
        CK(cudaDeviceSynchronize());
        const int IT = 50;
        double *s = (double *)malloc(IT * sizeof(double));
        for (int i = 0; i < IT; ++i) {
            CK(cudaEventRecord(e0, 0));
            fma_f32_kernel<<<grid, block>>>(out, iters);
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms; CK(cudaEventElapsedTime(&ms, e0, e1));
            s[i] = ms;
        }
        qsort(s, IT, sizeof(double), cmp_d);
        double med = s[IT / 2];
        /* 4 FMA per iter * 2 flop/FMA * iters * threads */
        double flops = 4.0 * 2.0 * (double)iters * (double)grid * (double)block;
        double tflops = flops / (med * 1e-3) / 1e12;
        double theo_fp32 = 2.0 * (prop.clockRate * 1e3) *
                           prop.multiProcessorCount * 128 / 1e12;  /* 128 FP32 lanes/SM est */
        printf("FP32_achieved_TFLOPs %.2f  (median %.4f ms, theoretical ~%.1f, %.1f%%)\n",
               tflops, med, theo_fp32, 100.0 * tflops / theo_fp32);
        cudaFree(out); free(s);
    }

    /* === 3. FP16 (half2) FMA peak === */
    {
        int block = 256, grid = prop.multiProcessorCount * 64;
        int iters = 8192;
        __half *out; CK(cudaMalloc((void **)&out, (size_t)grid * block * sizeof(__half)));
        for (int i = 0; i < 5; ++i) fma_f16_kernel<<<grid, block>>>(out, iters);
        CK(cudaDeviceSynchronize());
        const int IT = 50;
        double *s = (double *)malloc(IT * sizeof(double));
        for (int i = 0; i < IT; ++i) {
            CK(cudaEventRecord(e0, 0));
            fma_f16_kernel<<<grid, block>>>(out, iters);
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms; CK(cudaEventElapsedTime(&ms, e0, e1));
            s[i] = ms;
        }
        qsort(s, IT, sizeof(double), cmp_d);
        double med = s[IT / 2];
        /* half2 = 2 lanes, 4 hfma2/iter * 2 flop/fma * 2 lanes */
        double flops = 4.0 * 2.0 * 2.0 * (double)iters * (double)grid * (double)block;
        double tflops = flops / (med * 1e-3) / 1e12;
        printf("FP16_achieved_TFLOPs %.2f  (median %.4f ms)\n", tflops, med);
        cudaFree(out); free(s);
    }

    cudaEventDestroy(e0); cudaEventDestroy(e1);
    return 0;
}
