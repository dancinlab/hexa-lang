// HEXA-TRAIN-FLOOR M7 — standalone gemv A/B microbench (faithful to the
// runtime_cuda_emit.hexa generated paths). Measures the M2/M3 d-threshold
// gate mechanism (cuBLAS Dgemv vs on-device block-reduction kernel) and the
// M6 fp32 dtype slice, on the actual RTX 5070. $0 (pool host ubu-2).
//
// Mirrors self/cuda/runtime_cuda_emit.hexa:
//   #define HX_RR_BLOCK 256
//   _hx_k_packed_gemv_offset      (fp64 block-reduction, the small-d fallback)
//   _hx_k_packed_gemv_offset_f32  (fp32, the M6 lever)
//   cublasDgemv(CUBLAS_OP_T, ...) (the cols>=min_dim path)
//
// out[i] = Σ_j P[i·cols + j] · U[j],  i in [0,rows)   (off=0 here)
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define HX_RR_BLOCK 256

__device__ __forceinline__ double _hx_warp_sum(double v){
    for(int o=16;o>0;o>>=1) v += __shfl_down_sync(0xFFFFFFFFu,v,o);
    return v;
}
__device__ __forceinline__ double _hx_block_sum(double v,double* smem){
    int lane=threadIdx.x&31,wid=threadIdx.x>>5;
    v=_hx_warp_sum(v);
    if(lane==0) smem[wid]=v;
    __syncthreads();
    int n=(blockDim.x+31)>>5;
    if(wid==0){ double w=(lane<n)?smem[lane]:0.0; w=_hx_warp_sum(w); if(lane==0) smem[0]=w; }
    __syncthreads();
    return smem[0];
}
__device__ __forceinline__ float _hx_warp_sum_f(float v){
    for(int o=16;o>0;o>>=1) v += __shfl_down_sync(0xFFFFFFFFu,v,o);
    return v;
}
__device__ __forceinline__ float _hx_block_sum_f(float v,float* smem){
    int lane=threadIdx.x&31,wid=threadIdx.x>>5;
    v=_hx_warp_sum_f(v);
    if(lane==0) smem[wid]=v;
    __syncthreads();
    int n=(blockDim.x+31)>>5;
    if(wid==0){ float w=(lane<n)?smem[lane]:0.0f; w=_hx_warp_sum_f(w); if(lane==0) smem[0]=w; }
    __syncthreads();
    return smem[0];
}
__global__ void k_gemv_f64(const double* __restrict__ P,int64_t off,
        const double* __restrict__ U,double* __restrict__ O,int64_t rows,int64_t cols){
    __shared__ double smem[HX_RR_BLOCK/32];
    int64_t r=blockIdx.x; if(r>=rows) return;
    const double* row=P+off+r*cols; double acc=0.0;
    for(int64_t j=threadIdx.x;j<cols;j+=blockDim.x) acc+=row[j]*U[j];
    double t=_hx_block_sum(acc,smem);
    if(threadIdx.x==0) O[r]=t;
}
__global__ void k_gemv_f32(const double* __restrict__ P,int64_t off,
        const double* __restrict__ U,double* __restrict__ O,int64_t rows,int64_t cols){
    __shared__ float smem[HX_RR_BLOCK/32];
    int64_t r=blockIdx.x; if(r>=rows) return;
    const double* row=P+off+r*cols; float acc=0.0f;
    for(int64_t j=threadIdx.x;j<cols;j+=blockDim.x) acc+=(float)row[j]*(float)U[j];
    float t=_hx_block_sum_f(acc,smem);
    if(threadIdx.x==0) O[r]=(double)t;
}

static double now_ms(){ struct timespec ts; clock_gettime(CLOCK_MONOTONIC,&ts); return ts.tv_sec*1e3+ts.tv_nsec*1e-6; }

// One "step" = ITER gemv calls (the trainer inner loop is many gemv per step).
// We measure per-call latency; trainer step/s ∝ 1/(per-call · calls_per_step).
int main(int argc,char**argv){
    int64_t rows = 768;        // output dim (hidden)
    int reps = 2000;           // gemv calls timed
    int warmup = 200;
    if(argc>1) rows=atoll(argv[1]);
    if(argc>2) reps=atoi(argv[2]);

    int64_t cols_set[] = {64,128,256,768};
    int ncols = 4;

    cudaSetDevice(0);
    cublasHandle_t cub; cublasCreate(&cub);

    printf("# HEXA-TRAIN-FLOOR M7 gemv microbench — RTX 5070\n");
    printf("# rows(out)=%lld  reps=%d  warmup=%d\n", (long long)rows, reps, warmup);
    printf("# per-call latency (us) — lower=faster.  3 paths × 4 contraction dims (cols=d)\n");
    printf("# cols | cublas_Dgemv_us | ondevice_f64_us | ondevice_f32_us | f64/cublas | f32/f64\n");

    for(int ci=0; ci<ncols; ci++){
        int64_t cols = cols_set[ci];
        size_t Pn = (size_t)rows*cols;
        std::vector<double> hP(Pn), hU(cols), hO(rows);
        for(size_t i=0;i<Pn;i++) hP[i] = (double)((i*1103515245u+12345u)&0xffff)/65536.0 - 0.5;
        for(int64_t j=0;j<cols;j++) hU[j] = (double)((j*22695477u+1u)&0xffff)/65536.0 - 0.5;
        double *dP,*dU,*dO;
        cudaMalloc(&dP,Pn*sizeof(double));
        cudaMalloc(&dU,cols*sizeof(double));
        cudaMalloc(&dO,rows*sizeof(double));
        cudaMemcpy(dP,hP.data(),Pn*sizeof(double),cudaMemcpyHostToDevice);
        cudaMemcpy(dU,hU.data(),cols*sizeof(double),cudaMemcpyHostToDevice);
        dim3 grid((unsigned)rows), block(HX_RR_BLOCK);
        const double alpha=1.0,beta=0.0;

        // warmup all paths
        for(int w=0;w<warmup;w++){
            cublasDgemv(cub,CUBLAS_OP_T,(int)cols,(int)rows,&alpha,dP,(int)cols,dU,1,&beta,dO,1);
            k_gemv_f64<<<grid,block>>>(dP,0,dU,dO,rows,cols);
            k_gemv_f32<<<grid,block>>>(dP,0,dU,dO,rows,cols);
        }
        cudaDeviceSynchronize();

        // cuBLAS Dgemv — each call followed by sync (mirrors _d2h_out sync round-trip)
        double t0=now_ms();
        for(int r=0;r<reps;r++){
            cublasDgemv(cub,CUBLAS_OP_T,(int)cols,(int)rows,&alpha,dP,(int)cols,dU,1,&beta,dO,1);
            cudaDeviceSynchronize();
        }
        double cub_us=(now_ms()-t0)*1e3/reps;

        // on-device fp64 kernel + sync (the gate's small-d fallback)
        t0=now_ms();
        for(int r=0;r<reps;r++){
            k_gemv_f64<<<grid,block>>>(dP,0,dU,dO,rows,cols);
            cudaDeviceSynchronize();
        }
        double f64_us=(now_ms()-t0)*1e3/reps;

        // on-device fp32 kernel + sync (M6 lever)
        t0=now_ms();
        for(int r=0;r<reps;r++){
            k_gemv_f32<<<grid,block>>>(dP,0,dU,dO,rows,cols);
            cudaDeviceSynchronize();
        }
        double f32_us=(now_ms()-t0)*1e3/reps;

        printf("%5lld | %15.3f | %15.3f | %15.3f | %.3f | %.3f\n",
               (long long)cols, cub_us, f64_us, f32_us,
               f64_us/cub_us, f32_us/f64_us);
        cudaFree(dP);cudaFree(dU);cudaFree(dO);
    }
    cublasDestroy(cub);
    return 0;
}
