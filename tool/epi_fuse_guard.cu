// epi_fuse_guard.cu — #21 rank-7 epilogue-fusion BYTEEQ guard.
//
// Proves the fused residual-add+LayerNorm kernel (_hx_k_resid_layernorm_f32) is
// BIT-IDENTICAL to the separate _hx_k_residual_add_f32 + _hx_k_layernorm_rows_f32
// path it replaces — the byteeq-neutral claim behind the HEXA_EPI_FUSE opt-in.
//
// The three kernels + _hx_block_sum_f32 below are VERBATIM MIRRORS of
// self/cuda/runtime_cuda_emit.hexa (_hx_block_sum_f32 ~:4768, _hx_k_residual_add_f32
// / _hx_k_layernorm_rows_f32 / _hx_k_resid_layernorm_f32 in the LN/resid region).
// Keep in sync — same convention as tool/a_skinny_splitk2_driver.cu ("the measured
// code IS the shipped code"). If the fused kernel drifts from the separate kernels,
// this guard's byte-compare catches it.
//
// Shapes = decode LN rows: R = N_batch (1/8/32) x C = d = 1024, the exact shape
// the per-layer residual+LN runs at. eps = 1e-5.
//
// Compile-verify (no GPU): nvcc -x cu -arch=sm_120 -c epi_fuse_guard.cu (rc=0).
// Run (GPU, queued behind a-measure's window): ./epi_fuse_guard
//   PASS iff max|Y_fused - Y_sep| == 0 AND max|H_fused - H_sep| == 0 (exact bytes).

#include <cuda_runtime.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define HX_RR_BLOCK 256

// ---- VERBATIM: _hx_block_sum_f32 (runtime_cuda_emit.hexa ~:4768) ----
__device__ __forceinline__ float _hx_block_sum_f32(float v, float* smem) {
    int lane = threadIdx.x & 31;
    int wid  = threadIdx.x >> 5;
    for (int o = 16; o > 0; o >>= 1) v += __shfl_down_sync(0xffffffffu, v, o);
    if (lane == 0) smem[wid] = v;
    __syncthreads();
    int n_warps = (blockDim.x + 31) >> 5;
    if (wid == 0) {
        float w = (lane < n_warps) ? smem[lane] : 0.0f;
        for (int o = 16; o > 0; o >>= 1) w += __shfl_down_sync(0xffffffffu, w, o);
        if (lane == 0) smem[0] = w;
    }
    __syncthreads();
    return smem[0];
}

// ---- VERBATIM: _hx_k_residual_add_f32 ----
__global__ void _hx_k_residual_add_f32(const float* __restrict__ A,
                                       const float* __restrict__ B,
                                       float* __restrict__ OUT, int64_t n) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < n; i += stride) {
        OUT[i] = A[i] + B[i];
    }
}

// ---- VERBATIM: _hx_k_layernorm_rows_f32 ----
__global__ void _hx_k_layernorm_rows_f32(const float* __restrict__ X,
                                         const float* __restrict__ G,
                                         const float* __restrict__ B,
                                         float* __restrict__ Y,
                                         int64_t R, int64_t C, double eps) {
    int64_t r = blockIdx.x;
    if (r >= R) return;
    const float* xr = X + r * C;
    float*       yr = Y + r * C;
    __shared__ float smem[HX_RR_BLOCK / 32];
    float s = 0.0f;
    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) s += xr[j];
    float mean = _hx_block_sum_f32(s, smem) / (float)C;
    __syncthreads();
    float v = 0.0f;
    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) {
        float d = xr[j] - mean; v += d * d;
    }
    float var = _hx_block_sum_f32(v, smem) / (float)C;
    float inv = rsqrtf(var + (float)eps);
    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) {
        float xn = (xr[j] - mean) * inv;
        yr[j] = G[j] * xn + B[j];
    }
}

// ---- VERBATIM: _hx_k_resid_layernorm_f32 (the FUSED kernel under test) ----
__global__ void _hx_k_resid_layernorm_f32(float* __restrict__ H,
                                          const float* __restrict__ ADD,
                                          const float* __restrict__ BIAS,
                                          const float* __restrict__ G,
                                          const float* __restrict__ B,
                                          float* __restrict__ Y,
                                          int64_t R, int64_t C, double eps) {
    int64_t r = blockIdx.x;
    if (r >= R) return;
    float*       hr = H + r * C;
    const float* ar = ADD + r * C;
    float*       yr = Y + r * C;
    __shared__ float smem[HX_RR_BLOCK / 32];
    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) {
        float h = hr[j] + ar[j];
        if (BIAS) h += BIAS[j];
        hr[j] = h;
    }
    __syncthreads();
    float s = 0.0f;
    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) s += hr[j];
    float mean = _hx_block_sum_f32(s, smem) / (float)C;
    __syncthreads();
    float v = 0.0f;
    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) {
        float d = hr[j] - mean; v += d * d;
    }
    float var = _hx_block_sum_f32(v, smem) / (float)C;
    float inv = rsqrtf(var + (float)eps);
    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) {
        float xn = (hr[j] - mean) * inv;
        yr[j] = G[j] * xn + B[j];
    }
}

static int run_shape(int64_t R, int64_t C) {
    int64_t n = R * C;
    float *hH = (float*)malloc(n*4), *hADD = (float*)malloc(n*4);
    float *hG = (float*)malloc(C*4), *hB = (float*)malloc(C*4);
    srand(20260702 + (int)R);
    for (int64_t i = 0; i < n; i++) { hH[i]=(float)(rand()%2001-1000)/1000.0f; hADD[i]=(float)(rand()%2001-1000)/1000.0f; }
    for (int64_t j = 0; j < C; j++) { hG[j]=(float)(rand()%2001-1000)/1000.0f; hB[j]=(float)(rand()%2001-1000)/1000.0f; }

    float *dH,*dADD,*dG,*dB,*dY_sep,*dY_fus,*dH_sep;
    cudaMalloc(&dH,n*4); cudaMalloc(&dADD,n*4); cudaMalloc(&dG,C*4); cudaMalloc(&dB,C*4);
    cudaMalloc(&dY_sep,n*4); cudaMalloc(&dY_fus,n*4); cudaMalloc(&dH_sep,n*4);
    cudaMemcpy(dADD,hADD,n*4,cudaMemcpyHostToDevice);
    cudaMemcpy(dG,hG,C*4,cudaMemcpyHostToDevice);
    cudaMemcpy(dB,hB,C*4,cudaMemcpyHostToDevice);
    double eps = 1e-5;

    // SEPARATE path (today's reference): residual into dH_sep, then LN -> dY_sep.
    cudaMemcpy(dH_sep,hH,n*4,cudaMemcpyHostToDevice);
    { int blk=256; int64_t want=(n+blk-1)/blk; int grid=(want>1024)?1024:(int)want; if(grid<1)grid=1;
      _hx_k_residual_add_f32<<<grid,blk>>>(dH_sep,dADD,dH_sep,n); }
    _hx_k_layernorm_rows_f32<<<(unsigned)R,HX_RR_BLOCK>>>(dH_sep,dG,dB,dY_sep,R,C,eps);

    // FUSED path: residual in place into dH, LN -> dY_fus, in one launch.
    cudaMemcpy(dH,hH,n*4,cudaMemcpyHostToDevice);
    _hx_k_resid_layernorm_f32<<<(unsigned)R,HX_RR_BLOCK>>>(dH,dADD,(const float*)0,dG,dB,dY_fus,R,C,eps);
    cudaDeviceSynchronize();

    float *ysep=(float*)malloc(n*4), *yfus=(float*)malloc(n*4);
    float *hsep=(float*)malloc(n*4), *hfus=(float*)malloc(n*4);
    cudaMemcpy(ysep,dY_sep,n*4,cudaMemcpyDeviceToHost);
    cudaMemcpy(yfus,dY_fus,n*4,cudaMemcpyDeviceToHost);
    cudaMemcpy(hsep,dH_sep,n*4,cudaMemcpyDeviceToHost);
    cudaMemcpy(hfus,dH,n*4,cudaMemcpyDeviceToHost);

    int y_bit = (memcmp(ysep,yfus,n*4)==0);
    int h_bit = (memcmp(hsep,hfus,n*4)==0);
    printf("  R=%-3lld C=%-4lld : Y byte-eq=%s  H byte-eq=%s\n",
           (long long)R,(long long)C, y_bit?"YES":"NO", h_bit?"YES":"NO");

    cudaFree(dH);cudaFree(dADD);cudaFree(dG);cudaFree(dB);
    cudaFree(dY_sep);cudaFree(dY_fus);cudaFree(dH_sep);
    free(hH);free(hADD);free(hG);free(hB);free(ysep);free(yfus);free(hsep);free(hfus);
    return (y_bit && h_bit) ? 0 : 1;
}

int main(void) {
    int dev; cudaGetDevice(&dev); cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);
    printf("GPU: %s (sm_%d%d)\n", p.name, p.major, p.minor);
    printf("=== #21 rank-7 epilogue-fusion BYTEEQ guard (fused resid+LN == separate) ===\n");
    int fail = 0;
    fail |= run_shape(1,   1024);
    fail |= run_shape(8,   1024);
    fail |= run_shape(32,  1024);
    fail |= run_shape(16,  4096);
    printf("=== VERDICT: %s ===\n",
           fail ? "FAIL — fused epilogue is NOT byte-identical to the separate kernels"
                : "PASS — fused == separate, byte-for-byte (HEXA_EPI_FUSE is byteeq-neutral)");
    return fail;
}
