// HEXA-TRAIN-FLOOR M8 — gate-rekey verification microbench (RTX 5070, $0).
// Replicates the rekeyed dispatch decision from
// self/cuda/runtime_cuda_emit.hexa:_hx_cuda_farr_packed_gemv_offset_gpu:
//   on-device kernel iff rows < HEXA_GEMV_CUBLAS_MIN_ROWS (default 512),
//   else cuBLAS Dgemv.  Confirms the rekeyed gate (a) picks cuBLAS at the
//   M7 regression case rows=768·cols=64, and (b) picks on-device at small
//   rows — and that the chosen path is in fact the faster one (no regression).
//
// Faithful to the generated kernels (HX_RR_BLOCK=256, block-reduction tree).
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
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
__global__ void k_gemv_f64(const double* __restrict__ P,int64_t off,
        const double* __restrict__ U,double* __restrict__ O,int64_t rows,int64_t cols){
    __shared__ double smem[HX_RR_BLOCK/32];
    int64_t r=blockIdx.x; if(r>=rows) return;
    const double* row=P+off+r*cols; double acc=0.0;
    for(int64_t j=threadIdx.x;j<cols;j+=blockDim.x) acc+=row[j]*U[j];
    double t=_hx_block_sum(acc,smem);
    if(threadIdx.x==0) O[r]=t;
}

static double now_ms(){ struct timespec ts; clock_gettime(CLOCK_MONOTONIC,&ts); return ts.tv_sec*1e3+ts.tv_nsec*1e-6; }

// Mirror of the rekeyed host-wrapper gate decision.
static int gate_picks_ondevice(int64_t rows){
    long min_rows = 512;
    const char* mr = getenv("HEXA_GEMV_CUBLAS_MIN_ROWS");
    if(!(mr && *mr)) mr = getenv("HEXA_GEMV_CUBLAS_MIN_DIM"); // legacy alias
    if(mr && *mr){ long v=atol(mr); if(v>0) min_rows=v; }
    return rows < min_rows ? 1 : 0;
}

int main(int argc,char**argv){
    int reps = 4000, warmup = 200;
    int64_t rows_set[] = {16,64,256,768};
    int64_t cols_set[] = {64,128,256,768};
    int nrows=4, ncols=4;

    cudaSetDevice(0);
    cublasHandle_t cub; cublasCreate(&cub);

    printf("# HEXA-TRAIN-FLOOR M8 gate-rekey verify — RTX 5070\n");
    printf("# rekeyed gate: on-device iff rows < HEXA_GEMV_CUBLAS_MIN_ROWS (default 512)\n");
    printf("# reps=%d warmup=%d  HX_RR_BLOCK=%d\n", reps, warmup, HX_RR_BLOCK);
    printf("# rows | cols | gate_picks | cublas_us | ondev_us | faster_path | regression?\n");

    int any_regress = 0;
    for(int ri=0; ri<nrows; ri++){
      for(int ci=0; ci<ncols; ci++){
        int64_t rows=rows_set[ri], cols=cols_set[ci];
        size_t Pn=(size_t)rows*cols;
        std::vector<double> hP(Pn), hU(cols);
        for(size_t i=0;i<Pn;i++) hP[i]=(double)((i*1103515245u+12345u)&0xffff)/65536.0-0.5;
        for(int64_t j=0;j<cols;j++) hU[j]=(double)((j*22695477u+1u)&0xffff)/65536.0-0.5;
        double *dP,*dU,*dO;
        cudaMalloc(&dP,Pn*sizeof(double));
        cudaMalloc(&dU,cols*sizeof(double));
        cudaMalloc(&dO,rows*sizeof(double));
        cudaMemcpy(dP,hP.data(),Pn*sizeof(double),cudaMemcpyHostToDevice);
        cudaMemcpy(dU,hU.data(),cols*sizeof(double),cudaMemcpyHostToDevice);
        dim3 grid((unsigned)rows), block(HX_RR_BLOCK);
        const double alpha=1.0,beta=0.0;
        for(int w=0;w<warmup;w++){
            cublasDgemv(cub,CUBLAS_OP_T,(int)cols,(int)rows,&alpha,dP,(int)cols,dU,1,&beta,dO,1);
            k_gemv_f64<<<grid,block>>>(dP,0,dU,dO,rows,cols);
        }
        cudaDeviceSynchronize();
        double t0=now_ms();
        for(int r=0;r<reps;r++){ cublasDgemv(cub,CUBLAS_OP_T,(int)cols,(int)rows,&alpha,dP,(int)cols,dU,1,&beta,dO,1); cudaDeviceSynchronize(); }
        double cub_us=(now_ms()-t0)*1e3/reps;
        t0=now_ms();
        for(int r=0;r<reps;r++){ k_gemv_f64<<<grid,block>>>(dP,0,dU,dO,rows,cols); cudaDeviceSynchronize(); }
        double ond_us=(now_ms()-t0)*1e3/reps;

        int picks_ond = gate_picks_ondevice(rows);
        const char* faster = (ond_us < cub_us) ? "ondevice" : "cublas";
        // regression = gate chose the SLOWER path (beyond a 3% noise band)
        double chosen = picks_ond ? ond_us : cub_us;
        double other  = picks_ond ? cub_us : ond_us;
        int regress = (chosen > other*1.03) ? 1 : 0;
        if(regress) any_regress=1;
        printf("%5lld | %4lld | %9s | %9.3f | %8.3f | %9s | %s\n",
               (long long)rows,(long long)cols,
               picks_ond?"ondevice":"cublas", cub_us, ond_us, faster,
               regress?"YES":"no");
        cudaFree(dP);cudaFree(dU);cudaFree(dO);
      }
    }
    cublasDestroy(cub);
    printf("# ANY_REGRESSION=%s\n", any_regress?"YES":"NO");
    return 0;
}
