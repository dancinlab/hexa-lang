// piece-② gemv own-kernel bench — proves the own packed_gemv kernels (the ones
// that OWN the cublasDgemv/cublasSgemv call-sites under HEXA_NO_CUBLAS) are
// correct vs cuBLAS and reach the memory-bound roofline.
//
// The two own kernels are CHARACTER-FOR-CHARACTER the in-tree forge kernels:
//   _hx_k_packed_gemv_offset      — self/cuda/runtime_cuda.c (FP64 own gemv, owns cublasDgemv)
//   _hx_k_packed_gemv_offset_f32  — self/cuda/runtime_cuda.c (fp32-narrowing own gemv slice)
// Reference: cublasDgemv(CUBLAS_OP_T, m=cols, n=rows, ...) — exactly the forge
// fallthrough call (runtime_cuda.c L5539), and cublasSgemv for the fp32 slice.
//
// gemv is memory-bound (1 FMA per loaded element, reuse only of U) → the own
// block-per-row reduction kernel should reach ~the device DRAM roofline and be
// competitive with cuBLAS; cuBLAS's win on gemv is dispatch+tiling, not flops.
//
// Build (aiden sm_120):
//   nvcc -O3 -arch=sm_120 bench/gemv_own_bench.cu -lcublas -o /tmp/gemvbench
// Run: /tmp/gemvbench <rows> <cols> [reps]

#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cmath>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(x) do { cudaError_t e=(x); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA err %s @ %s:%d\n",cudaGetErrorString(e),__FILE__,__LINE__); exit(1);} } while(0)
#define CBK(x) do { cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){ \
  fprintf(stderr,"cuBLAS err %d @ %s:%d\n",(int)s,__FILE__,__LINE__); exit(1);} } while(0)

#define HX_RR_BLOCK 256

// ---- in-tree block reduction helpers (verbatim) ----
__device__ __forceinline__ double _hx_warp_sum(double v) {
    for (int offset = 16; offset > 0; offset >>= 1)
        v += __shfl_down_sync(0xFFFFFFFFu, v, offset);
    return v;
}
__device__ __forceinline__ double _hx_block_sum(double v, double* smem) {
    int lane = threadIdx.x & 31, wid = threadIdx.x >> 5;
    v = _hx_warp_sum(v);
    if (lane == 0) smem[wid] = v;
    __syncthreads();
    int n_warps = (blockDim.x + 31) >> 5;
    if (wid == 0) { double w = (lane < n_warps) ? smem[lane] : 0.0; w = _hx_warp_sum(w); if (lane==0) smem[0]=w; }
    __syncthreads();
    return smem[0];
}
__device__ __forceinline__ float _hx_warp_sum_f(float v) {
    for (int offset = 16; offset > 0; offset >>= 1)
        v += __shfl_down_sync(0xFFFFFFFFu, v, offset);
    return v;
}
__device__ __forceinline__ float _hx_block_sum_f(float v, float* smem) {
    int lane = threadIdx.x & 31, wid = threadIdx.x >> 5;
    v = _hx_warp_sum_f(v);
    if (lane == 0) smem[wid] = v;
    __syncthreads();
    int n_warps = (blockDim.x + 31) >> 5;
    if (wid == 0) { float w = (lane < n_warps) ? smem[lane] : 0.0f; w = _hx_warp_sum_f(w); if (lane==0) smem[0]=w; }
    __syncthreads();
    return smem[0];
}

// ---- own FP64 gemv (verbatim from runtime_cuda.c) ----
__global__ void _hx_k_packed_gemv_offset(const double* __restrict__ P, int64_t off,
                                 const double* __restrict__ U, double* __restrict__ O,
                                 int64_t rows, int64_t cols) {
    __shared__ double smem[HX_RR_BLOCK / 32];
    int64_t r = (int64_t)blockIdx.x;
    if (r >= rows) return;
    const double* row = P + off + r * cols;
    double acc = 0.0;
    for (int64_t j = (int64_t)threadIdx.x; j < cols; j += blockDim.x) acc += row[j] * U[j];
    double total = _hx_block_sum(acc, smem);
    if (threadIdx.x == 0) O[r] = total;
}
// ---- own fp32-narrowing gemv (verbatim) ----
__global__ void _hx_k_packed_gemv_offset_f32(const double* __restrict__ P, int64_t off,
                                 const double* __restrict__ U, double* __restrict__ O,
                                 int64_t rows, int64_t cols) {
    __shared__ float smem[HX_RR_BLOCK / 32];
    int64_t r = (int64_t)blockIdx.x;
    if (r >= rows) return;
    const double* row = P + off + r * cols;
    float acc = 0.0f;
    for (int64_t j = (int64_t)threadIdx.x; j < cols; j += blockDim.x) acc += (float)row[j] * (float)U[j];
    float total = _hx_block_sum_f(acc, smem);
    if (threadIdx.x == 0) O[r] = (double)total;
}

static double now_ms(cudaEvent_t s, cudaEvent_t e){ float ms; cudaEventElapsedTime(&ms,s,e); return ms; }

int main(int argc, char** argv){
    int64_t rows = (argc>1)? atoll(argv[1]) : 256;
    int64_t cols = (argc>2)? atoll(argv[2]) : 4096;
    int reps = (argc>3)? atoi(argv[3]) : 100;

    size_t szP=(size_t)rows*cols*sizeof(double), szU=(size_t)cols*sizeof(double), szO=(size_t)rows*sizeof(double);
    double *hP=(double*)malloc(szP),*hU=(double*)malloc(szU);
    srand(777);
    for(int64_t i=0;i<rows*cols;i++) hP[i]=(rand()%2000-1000)/1000.0;
    for(int64_t i=0;i<cols;i++) hU[i]=(rand()%2000-1000)/1000.0;

    double *dP,*dU,*dOwn,*dF32,*dCub;
    CK(cudaMalloc(&dP,szP)); CK(cudaMalloc(&dU,szU));
    CK(cudaMalloc(&dOwn,szO)); CK(cudaMalloc(&dF32,szO)); CK(cudaMalloc(&dCub,szO));
    CK(cudaMemcpy(dP,hP,szP,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dU,hU,szU,cudaMemcpyHostToDevice));

    cublasHandle_t h; CBK(cublasCreate(&h));
    cudaEvent_t e0,e1; CK(cudaEventCreate(&e0)); CK(cudaEventCreate(&e1));

    dim3 grid((unsigned)rows), block(HX_RR_BLOCK);
    const double alpha=1.0, beta=0.0;

    // warmup all three
    _hx_k_packed_gemv_offset<<<grid,block>>>(dP,0,dU,dOwn,rows,cols);
    _hx_k_packed_gemv_offset_f32<<<grid,block>>>(dP,0,dU,dF32,rows,cols);
    // cublasDgemv: row-major P[rows,cols].U = P viewed col-major as cols x rows, OP_T
    CBK(cublasDgemv(h, CUBLAS_OP_T, (int)cols,(int)rows,&alpha,dP,(int)cols,dU,1,&beta,dCub,1));
    CK(cudaDeviceSynchronize());

    // timings
    CK(cudaEventRecord(e0));
    for(int r=0;r<reps;r++) _hx_k_packed_gemv_offset<<<grid,block>>>(dP,0,dU,dOwn,rows,cols);
    CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
    double t_own = now_ms(e0,e1)/reps;

    CK(cudaEventRecord(e0));
    for(int r=0;r<reps;r++) _hx_k_packed_gemv_offset_f32<<<grid,block>>>(dP,0,dU,dF32,rows,cols);
    CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
    double t_f32 = now_ms(e0,e1)/reps;

    CK(cudaEventRecord(e0));
    for(int r=0;r<reps;r++) CBK(cublasDgemv(h,CUBLAS_OP_T,(int)cols,(int)rows,&alpha,dP,(int)cols,dU,1,&beta,dCub,1));
    CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
    double t_cub = now_ms(e0,e1)/reps;

    // clean re-run for correctness
    _hx_k_packed_gemv_offset<<<grid,block>>>(dP,0,dU,dOwn,rows,cols);
    _hx_k_packed_gemv_offset_f32<<<grid,block>>>(dP,0,dU,dF32,rows,cols);
    CBK(cublasDgemv(h,CUBLAS_OP_T,(int)cols,(int)rows,&alpha,dP,(int)cols,dU,1,&beta,dCub,1));
    CK(cudaDeviceSynchronize());

    double *hOwn=(double*)malloc(szO),*hF32=(double*)malloc(szO),*hCub=(double*)malloc(szO);
    CK(cudaMemcpy(hOwn,dOwn,szO,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hF32,dF32,szO,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hCub,dCub,szO,cudaMemcpyDeviceToHost));

    // rel-RMS own(fp64) vs cublasDgemv(fp64) and f32-narrow vs cublas
    double se_own=0,se_f32=0,den=0;
    double maxabs_own=0;
    for(int64_t i=0;i<rows;i++){
        double ref=hCub[i];
        double d1=hOwn[i]-ref, d2=hF32[i]-ref;
        se_own+=d1*d1; se_f32+=d2*d2; den+=ref*ref;
        if(fabs(d1)>maxabs_own) maxabs_own=fabs(d1);
    }
    double rms_own = sqrt(se_own/(den>0?den:1));
    double rms_f32 = sqrt(se_f32/(den>0?den:1));

    // gemv flops = 2*rows*cols; bytes moved (memory-bound) ~ P (rows*cols*8) + U (cols*8) + O
    double gflop = 2.0*(double)rows*cols/1e9;
    double gbytes = ((double)rows*cols*8.0 + cols*8.0 + rows*8.0)/1e9;
    printf("rows=%lld cols=%lld | own-FP64 %.5f ms (%.1f GFLOP/s, %.1f GB/s)  f32-narrow %.5f ms (%.1f GB/s)  cublasDgemv %.5f ms (%.1f GB/s)\n",
        (long long)rows,(long long)cols,
        t_own, gflop/(t_own/1e3), gbytes/(t_own/1e3),
        t_f32, gbytes/(t_f32/1e3),
        t_cub, gbytes/(t_cub/1e3));
    printf("        own-vs-cublas speedup=%.4fx  relRMS(own-fp64 vs cublas)=%.3e maxabs=%.3e  relRMS(f32-narrow vs cublas)=%.3e\n",
        t_cub/t_own, rms_own, maxabs_own, rms_f32);

    cublasDestroy(h);
    return 0;
}
