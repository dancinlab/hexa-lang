// fusion-r2 GPU — c23 beyond-parity microbench
// Proves: own-GEMM with residual epilogue FUSED into the C-store site (1 launch)
// beats own-GEMM (1 launch) + separate _hx_k_residual_add (1 launch + M*N DRAM
// round-trip), the structural shape forge currently ships.
//
// The two GEMM kernels are CHARACTER-FOR-CHARACTER the in-tree forge kernels:
//   _hx_k_gemm        — self/cuda/runtime_cuda.c L715-725 (own-GEMM default path)
//   _hx_k_residual_add — self/cuda/runtime_cuda.c L1571-1579 (separate epilogue)
// The fused kernel is _hx_k_gemm with one change: C[m*N+n] = acc + R[m*N+n].
// byte-eq holds by construction (same acc, same +R[i], same FP64 association).
//
// Build (aiden, sm_120):
//   nvcc -O3 -arch=sm_120 bench/fusion_epilogue_bench.cu -o /tmp/fusebench
// Run:
//   /tmp/fusebench 1024 ; /tmp/fusebench 2048 ; /tmp/fusebench 4096

#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cmath>
#include <cuda_runtime.h>

#define CK(x) do { cudaError_t e=(x); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA err %s @ %s:%d\n",cudaGetErrorString(e),__FILE__,__LINE__); exit(1);} } while(0)

// ---- in-tree forge own-GEMM (verbatim, L715-725) ----
__global__ void _hx_k_gemm(const double* __restrict__ A,
                           const double* __restrict__ B,
                           double* __restrict__ C,
                           int64_t M, int64_t K, int64_t N) {
    int64_t n = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    int64_t m = (int64_t)blockIdx.y * blockDim.y + threadIdx.y;
    if (m >= M || n >= N) return;
    double acc = 0.0;
    for (int64_t k = 0; k < K; k++) acc += A[m * K + k] * B[k * N + n];
    C[m * N + n] = acc;
}

// ---- in-tree forge separate epilogue (verbatim, L1571-1579) ----
__global__ void _hx_k_residual_add(const double* __restrict__ A,
                                   const double* __restrict__ B,
                                   double* __restrict__ OUT, int64_t n) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < n; i += stride) {
        OUT[i] = A[i] + B[i];
    }
}

// ---- FUSED: own-GEMM with the residual added at the C-store site ----
// Only the last line differs from _hx_k_gemm. R is the residual [M*N].
__global__ void _hx_k_gemm_fused_residual(const double* __restrict__ A,
                                          const double* __restrict__ B,
                                          const double* __restrict__ R,
                                          double* __restrict__ C,
                                          int64_t M, int64_t K, int64_t N) {
    int64_t n = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    int64_t m = (int64_t)blockIdx.y * blockDim.y + threadIdx.y;
    if (m >= M || n >= N) return;
    double acc = 0.0;
    for (int64_t k = 0; k < K; k++) acc += A[m * K + k] * B[k * N + n];
    C[m * N + n] = acc + R[m * N + n];   // <-- fused, register-resident, no 2nd launch
}

// ---- fast tiled (shared-memory) GEMM — a competitive reference so the
//      epilogue round-trip is a MEANINGFUL fraction of total time. Same C=A.B
//      math; TS=16 tile. _tiled (plain store) vs _tiled_fused (acc+R store). ----
#define TS 16
__global__ void _hx_k_gemm_tiled(const double* __restrict__ A,
                                 const double* __restrict__ B,
                                 double* __restrict__ C,
                                 int64_t M, int64_t K, int64_t N) {
    __shared__ double As[TS][TS], Bs[TS][TS];
    int row = blockIdx.y*TS + threadIdx.y;
    int col = blockIdx.x*TS + threadIdx.x;
    double acc = 0.0;
    for (int t=0; t<K; t+=TS) {
        As[threadIdx.y][threadIdx.x] = (row<M && t+threadIdx.x<K)? A[(int64_t)row*K + t+threadIdx.x] : 0.0;
        Bs[threadIdx.y][threadIdx.x] = (t+threadIdx.y<K && col<N)? B[(int64_t)(t+threadIdx.y)*N + col] : 0.0;
        __syncthreads();
        for (int k=0;k<TS;k++) acc += As[threadIdx.y][k]*Bs[k][threadIdx.x];
        __syncthreads();
    }
    if (row<M && col<N) C[(int64_t)row*N+col] = acc;
}
__global__ void _hx_k_gemm_tiled_fused(const double* __restrict__ A,
                                       const double* __restrict__ B,
                                       const double* __restrict__ R,
                                       double* __restrict__ C,
                                       int64_t M, int64_t K, int64_t N) {
    __shared__ double As[TS][TS], Bs[TS][TS];
    int row = blockIdx.y*TS + threadIdx.y;
    int col = blockIdx.x*TS + threadIdx.x;
    double acc = 0.0;
    for (int t=0; t<K; t+=TS) {
        As[threadIdx.y][threadIdx.x] = (row<M && t+threadIdx.x<K)? A[(int64_t)row*K + t+threadIdx.x] : 0.0;
        Bs[threadIdx.y][threadIdx.x] = (t+threadIdx.y<K && col<N)? B[(int64_t)(t+threadIdx.y)*N + col] : 0.0;
        __syncthreads();
        for (int k=0;k<TS;k++) acc += As[threadIdx.y][k]*Bs[k][threadIdx.x];
        __syncthreads();
    }
    if (row<M && col<N) C[(int64_t)row*N+col] = acc + R[(int64_t)row*N+col];
}

static double now_ms(cudaEvent_t s, cudaEvent_t e){ float ms; cudaEventElapsedTime(&ms,s,e); return ms; }

int main(int argc, char** argv){
    int64_t D = (argc>1)? atoll(argv[1]) : 1024;
    int reps = (argc>2)? atoi(argv[2]) : 30;
    // optional arg3 = K override (drives arithmetic intensity; small K => memory-bound GEMM
    // => epilogue round-trip is a real fraction => fusion should pay).
    int64_t M=D,N=D, K = (argc>3)? atoll(argv[3]) : D;

    size_t szA=(size_t)M*K*sizeof(double), szB=(size_t)K*N*sizeof(double),
           szC=(size_t)M*N*sizeof(double), szR=(size_t)M*N*sizeof(double);

    double *hA=(double*)malloc(szA),*hB=(double*)malloc(szB),*hR=(double*)malloc(szR);
    srand(12345);
    for(int64_t i=0;i<M*K;i++) hA[i]=(rand()%1000)/1000.0;
    for(int64_t i=0;i<K*N;i++) hB[i]=(rand()%1000)/1000.0;
    for(int64_t i=0;i<M*N;i++) hR[i]=(rand()%1000)/1000.0;

    double *dA,*dB,*dR,*dC2,*dCf;
    CK(cudaMalloc(&dA,szA)); CK(cudaMalloc(&dB,szB)); CK(cudaMalloc(&dR,szR));
    CK(cudaMalloc(&dC2,szC)); CK(cudaMalloc(&dCf,szC));
    CK(cudaMemcpy(dA,hA,szA,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dR,hR,szR,cudaMemcpyHostToDevice));

    dim3 blk(16,16);
    dim3 grd((unsigned)((N+15)/16),(unsigned)((M+15)/16));
    // residual_add launch config — verbatim from L1591-1593
    int64_t nElem=M*N; int rblk=256;
    int64_t want=(nElem+rblk-1)/rblk; int rgrid=(want>1024)?1024:(int)want; if(rgrid<1)rgrid=1;

    cudaEvent_t ev0,ev1; CK(cudaEventCreate(&ev0)); CK(cudaEventCreate(&ev1));

    // warmup
    _hx_k_gemm<<<grd,blk>>>(dA,dB,dC2,M,K,N);
    _hx_k_residual_add<<<rgrid,rblk>>>(dC2,dR,dC2,nElem);
    _hx_k_gemm_fused_residual<<<grd,blk>>>(dA,dB,dR,dCf,M,K,N);
    CK(cudaDeviceSynchronize());

    // ---- TWO-CALL path (own-GEMM + separate residual_add), the forge shape ----
    CK(cudaEventRecord(ev0));
    for(int r=0;r<reps;r++){
        _hx_k_gemm<<<grd,blk>>>(dA,dB,dC2,M,K,N);
        _hx_k_residual_add<<<rgrid,rblk>>>(dC2,dR,dC2,nElem);
    }
    CK(cudaEventRecord(ev1)); CK(cudaEventSynchronize(ev1));
    double t2 = now_ms(ev0,ev1)/reps;

    // ---- FUSED path (1 launch) ----
    CK(cudaEventRecord(ev0));
    for(int r=0;r<reps;r++){
        _hx_k_gemm_fused_residual<<<grd,blk>>>(dA,dB,dR,dCf,M,K,N);
    }
    CK(cudaEventRecord(ev1)); CK(cudaEventSynchronize(ev1));
    double tf = now_ms(ev0,ev1)/reps;

    // ---- isolated timings into a SCRATCH buffer (dCf) so dC2 keeps the
    //      correct 2-call result for the byte-eq gate below ----
    // isolated: own-GEMM only (no epilogue)
    CK(cudaEventRecord(ev0));
    for(int r=0;r<reps;r++){ _hx_k_gemm<<<grd,blk>>>(dA,dB,dCf,M,K,N); }
    CK(cudaEventRecord(ev1)); CK(cudaEventSynchronize(ev1));
    double tg = now_ms(ev0,ev1)/reps;

    // isolated: residual_add only (the separate epilogue's own cost) — scratch dCf
    CK(cudaEventRecord(ev0));
    for(int r=0;r<reps;r++){ _hx_k_residual_add<<<rgrid,rblk>>>(dCf,dR,dCf,nElem); }
    CK(cudaEventRecord(ev1)); CK(cudaEventSynchronize(ev1));
    double tr = now_ms(ev0,ev1)/reps;

    // re-run the two paths cleanly so dC2 (2-call) and dCf (fused) hold the
    // canonical results for the byte-eq gate (the isolated timings clobbered dCf).
    _hx_k_gemm<<<grd,blk>>>(dA,dB,dC2,M,K,N);
    _hx_k_residual_add<<<rgrid,rblk>>>(dC2,dR,dC2,nElem);
    _hx_k_gemm_fused_residual<<<grd,blk>>>(dA,dB,dR,dCf,M,K,N);
    CK(cudaDeviceSynchronize());

    // ---- byte-eq gate: fused result vs 2-call result, max|delta| ----
    double *hC2=(double*)malloc(szC),*hCf=(double*)malloc(szC);
    CK(cudaMemcpy(hC2,dC2,szC,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hCf,dCf,szC,cudaMemcpyDeviceToHost));
    double maxabs=0.0; int64_t bitne=0;
    for(int64_t i=0;i<M*N;i++){
        double d=fabs(hC2[i]-hCf[i]); if(d>maxabs)maxabs=d;
        if(hC2[i]!=hCf[i]) bitne++;
    }

    // ====== FAST tiled GEMM: 2call vs fused (where epilogue fraction matters) ======
    double *dCt2, *dCtf; CK(cudaMalloc(&dCt2,szC)); CK(cudaMalloc(&dCtf,szC));
    _hx_k_gemm_tiled<<<grd,blk>>>(dA,dB,dCt2,M,K,N);
    _hx_k_gemm_tiled_fused<<<grd,blk>>>(dA,dB,dR,dCtf,M,K,N);
    CK(cudaDeviceSynchronize());
    // 2call tiled
    CK(cudaEventRecord(ev0));
    for(int r=0;r<reps;r++){
        _hx_k_gemm_tiled<<<grd,blk>>>(dA,dB,dCt2,M,K,N);
        _hx_k_residual_add<<<rgrid,rblk>>>(dCt2,dR,dCt2,nElem);
    }
    CK(cudaEventRecord(ev1)); CK(cudaEventSynchronize(ev1));
    double tt2 = now_ms(ev0,ev1)/reps;
    // fused tiled
    CK(cudaEventRecord(ev0));
    for(int r=0;r<reps;r++){ _hx_k_gemm_tiled_fused<<<grd,blk>>>(dA,dB,dR,dCtf,M,K,N); }
    CK(cudaEventRecord(ev1)); CK(cudaEventSynchronize(ev1));
    double ttf = now_ms(ev0,ev1)/reps;
    // tiled byte-eq (clean re-run)
    _hx_k_gemm_tiled<<<grd,blk>>>(dA,dB,dCt2,M,K,N);
    _hx_k_residual_add<<<rgrid,rblk>>>(dCt2,dR,dCt2,nElem);
    _hx_k_gemm_tiled_fused<<<grd,blk>>>(dA,dB,dR,dCtf,M,K,N);
    CK(cudaDeviceSynchronize());
    double *hCt2=(double*)malloc(szC),*hCtf=(double*)malloc(szC);
    CK(cudaMemcpy(hCt2,dCt2,szC,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hCtf,dCtf,szC,cudaMemcpyDeviceToHost));
    double tmaxabs=0.0; int64_t tbitne=0;
    for(int64_t i=0;i<M*N;i++){ double d=fabs(hCt2[i]-hCtf[i]); if(d>tmaxabs)tmaxabs=d; if(hCt2[i]!=hCtf[i])tbitne++; }

    double gflops = 2.0*(double)M*N*K/1e9;
    // eliminated DRAM traffic from fusion: the separate residual_add reads C (M*N),
    // reads R (M*N), writes C (M*N) = 3*M*N*8 bytes; fusion adds only R read (M*N*8)
    // and removes the GEMM's own C round-write+reread. Net eliminated ~ 2*M*N*8
    // (the C write+read of the separate pass) per the structural round-trip.
    double elim_MB = 2.0*(double)M*N*sizeof(double)/1e6;

    printf("M=N=%lld K=%lld [NAIVE own-GEMM]  2call=%.4f ms (%.1f GFLOP/s)  fused=%.4f ms (%.1f GFLOP/s)  speedup=%.4fx  | gemm_only=%.4f ms  resid_only=%.4f ms (epi=%.2f%%)  maxabs=%.3e bit_ne=%lld\n",
        (long long)D, (long long)K, t2, gflops/(t2/1e3), tf, gflops/(tf/1e3), t2/tf, tg, tr, 100.0*tr/t2, maxabs, (long long)bitne);
    printf("M=N=%lld K=%lld [FAST tiled-GEMM] 2call=%.4f ms (%.1f GFLOP/s)  fused=%.4f ms (%.1f GFLOP/s)  speedup=%.4fx  (epi=%.2f%% of tiled-2call)  elim_DRAM~%.1f MB/call  maxabs=%.3e bit_ne=%lld\n",
        (long long)D, (long long)K, tt2, gflops/(tt2/1e3), ttf, gflops/(ttf/1e3), tt2/ttf, 100.0*tr/tt2, elim_MB, tmaxabs, (long long)tbitne);

    free(hA);free(hB);free(hR);free(hC2);free(hCf);
    cudaFree(dA);cudaFree(dB);cudaFree(dR);cudaFree(dC2);cudaFree(dCf);
    return 0;
}
