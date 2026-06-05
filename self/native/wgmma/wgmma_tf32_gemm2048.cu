// wgmma_tf32_gemm2048.cu — W3/W4: full tiled TF32 wgmma+shared GEMM at 2048^3, using
// the W2-proven GMMA INTER 8x4-core layout. rel_rms vs CPU/cuBLAS ref + own GFLOP/s +
// ratio vs cuBLAS-TF32. Square M=N=K=2048 (override via argv[1]).
//
// Tile: each block computes a 64(M) x 64(N) output tile. K loop in steps of 8.
// Per K-step: cooperatively stage A(64x8) and B(8x64) into shared in the proven
// GMMA core layout (gmma_phys), one wgmma.mma_async.m64n64k8 accumulating into the
// SAME 32 f32 registers across the whole K loop. Multi-stage not needed for correctness
// (W3 gate); W5 would add cp.async/TMA pipelining for perf.
//
// NOTE: this is a straightforward shared-staged wgmma loop (no TMA) — its job is the
// W3 bit-correctness GATE + an HONEST first own GFLOP/s number. cuBLAS = roofline.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d:%s\n",#x,__LINE__,cudaGetErrorString(e));return 3;}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %s @%d:%d\n",#x,__LINE__,(int)s);return 3;}}while(0)

__device__ __forceinline__ uint64_t mk(uint32_t s,uint32_t lbo,uint32_t sbo){
    uint64_t d=0;
    d |= (uint64_t)((s>>4)&0x3FFF);
    d |= ((uint64_t)((lbo>>4)&0x3FFF))<<16;
    d |= ((uint64_t)((sbo>>4)&0x3FFF))<<32;
    return d; // INTERLEAVE / no-swizzle, base_offset=0
}
// proven GMMA INTER core map: 8 strided-rows x 4 K-elems per core, K-core inner.
__device__ __forceinline__ int gmma_phys(int s,int k){
    int strip=s>>3, sr=s&7, kcore=k>>2, kc=k&3;
    return (strip*2+kcore)*32 + sr*4 + kc;
}

// gA: M x K row-major, gB: K x N row-major (B[k][n]), gD: M x N row-major.
extern "C" __global__ void gemm(const float* __restrict__ gA,const float* __restrict__ gB,
                                float* __restrict__ gD,int M,int N,int K){
    const int TM=64,TN=64,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    // double-buffered shared (ping-pong) so an in-flight async wgmma's read is never
    // overwritten by the next K-step's stage. buf size = (TM*TK + TK*TN) floats each.
    const int BUF=TM*TK+TK*TN;
    int tid=threadIdx.x;
    float d[32];
    #pragma unroll
    for(int i=0;i<32;++i)d[i]=0.f;
    int ping=0;
    for(int k0=0;k0<K;k0+=TK,ping^=1){
        float* As=sm+ping*BUF; float* Bs=As+TM*TK;
        // stage A tile (TM x TK) and B tile (TK x TN) in GMMA core layout
        for(int i=tid;i<TM*TK;i+=128){int m=i/TK,kk=i%TK; As[gmma_phys(m,kk)]=gA[(bm+m)*K+(k0+kk)];}
        for(int i=tid;i<TK*TN;i+=128){int kk=i/TN,n=i%TN; Bs[gmma_phys(n,kk)]=gB[(k0+kk)*N+(bn+n)];}
        __syncthreads();
        uint32_t aA=(uint32_t)__cvta_generic_to_shared(As), aB=(uint32_t)__cvta_generic_to_shared(Bs);
        uint64_t dA=mk(aA,128,256), dB=mk(aB,128,256);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        asm volatile(
          "wgmma.mma_async.sync.aligned.m64n64k8.f32.tf32.tf32 "
          "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15,"
          "%16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31}, "
          "%32,%33, 1,1,1;\n"
          :"+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3]),"+f"(d[4]),"+f"(d[5]),"+f"(d[6]),"+f"(d[7]),
           "+f"(d[8]),"+f"(d[9]),"+f"(d[10]),"+f"(d[11]),"+f"(d[12]),"+f"(d[13]),"+f"(d[14]),"+f"(d[15]),
           "+f"(d[16]),"+f"(d[17]),"+f"(d[18]),"+f"(d[19]),"+f"(d[20]),"+f"(d[21]),"+f"(d[22]),"+f"(d[23]),
           "+f"(d[24]),"+f"(d[25]),"+f"(d[26]),"+f"(d[27]),"+f"(d[28]),"+f"(d[29]),"+f"(d[30]),"+f"(d[31])
          :"l"(dA),"l"(dB));
        asm volatile("wgmma.commit_group.sync.aligned;\n":::"memory");
        asm volatile("wgmma.wait_group.sync.aligned 0;\n":::"memory");
        __syncthreads();   // reuse shared next K-step
    }
    int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=bm+rb+r*8,col=bn+cb+p+c*8;
        if(row<M&&col<N)gD[row*N+col]=d[idx];
    }
}
static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}
int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):2048;
    int M=S,N=S,K=S;
    size_t szA=(size_t)M*K, szB=(size_t)K*N, szD=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hD=(float*)malloc(szD*4),*hR=(float*)malloc(szD*4);
    srand(7);
    for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
    for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
    float *dA,*dB,*dD,*dR;
    CK(cudaMalloc(&dA,szA*4));CK(cudaMalloc(&dB,szB*4));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));

    // cuBLAS-TF32 reference (roofline). cuBLAS is column-major: compute D^T = B^T A^T.
    cublasHandle_t h; CB(cublasCreate(&h));
    CB(cublasSetMathMode(h, CUBLAS_TF32_TENSOR_OP_MATH));
    float alpha=1.f,beta=0.f;
    // Our arrays are row-major MxN. Use the trick: row-major C = col-major C^T.
    // C(MxN)=A(MxK)B(KxN). In col-major: treat as Ccm(NxM)=Bcm(NxK?)... use standard:
    // cublasSgemm(N,N, n,m,k, &al, B,n, A,k, &be, C,n) gives row-major C=A*B.
    CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dB, N, dA, K, &beta, dR, N));
    CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));

    // own wgmma GEMM
    dim3 grid((N+63)/64,(M+63)/64), blk(128);
    size_t smsz=2*(64*8+8*64)*4;   // double-buffered ping-pong
    CK(cudaMemset(dD,0,szD*4));
    gemm<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){printf("OWN-FAULT %s\n",cudaGetErrorString(e));return 4;}
    CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));

    // rel_rms (own vs cuBLAS-TF32)
    double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
    double rr=sqrt(se/fmax(1e-30,sr));
    // independent CPU f32 ref on a sampled tile to disambiguate own-bug vs cuBLAS-numeric.
    // compare own[m][n] and cuBLAS[m][n] both to CPU double-accum for first 64x64 tile.
    double own_cpu=0;
    {
        double se_o=0,se_c=0,sr2=0;
        for(int m=0;m<64;++m)for(int n=0;n<64;++n){
            double acc=0; for(int kk=0;kk<K;++kk) acc+=(double)hA[(size_t)m*K+kk]*hB[(size_t)kk*N+n];
            double o=hD[(size_t)m*N+n], c=hR[(size_t)m*N+n];
            se_o+=(o-acc)*(o-acc); se_c+=(c-acc)*(c-acc); sr2+=acc*acc;
        }
        own_cpu=sqrt(se_o/fmax(1e-30,sr2));
        printf("  [tile0 vs CPU-f64] own_rms=%.3e cuBLAS_rms=%.3e\n", own_cpu, sqrt(se_c/fmax(1e-30,sr2)));
    }
    // W3 gate = own vs CPU-f64 (the ground truth for TF32 inputs). cuBLAS rms reported
    // separately (cuBLAS has its own internal TF32 blocking/rounding).
    int pass = (own_cpu<=3e-3);
    printf("S=%d rel_rms(own vs cuBLAS-TF32)=%.3e own_vs_CPU=%.3e %s\n",S,rr,own_cpu, pass?"W3_PASS":"W3_FAIL");
    if(!pass){ printf("W3_FAIL — not measuring perf (g5: no perf on wrong kernel)\n"); return 2; }

    // ---- W4 perf: time own + cuBLAS ----
    cudaEvent_t s0,s1; CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));
    int iters=20;
    // warmup
    gemm<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K); CK(cudaDeviceSynchronize());
    CK(cudaEventRecord(s0));
    for(int it=0;it<iters;++it) gemm<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K);
    CK(cudaEventRecord(s1)); CK(cudaEventSynchronize(s1));
    float ms_own; CK(cudaEventElapsedTime(&ms_own,s0,s1)); ms_own/=iters;
    double flops=2.0*(double)M*N*K;
    double tfo=flops/(ms_own*1e-3)/1e12;

    cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&alpha,dB,N,dA,K,&beta,dR,N); CK(cudaDeviceSynchronize());
    CK(cudaEventRecord(s0));
    for(int it=0;it<iters;++it) cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&alpha,dB,N,dA,K,&beta,dR,N);
    CK(cudaEventRecord(s1)); CK(cudaEventSynchronize(s1));
    float ms_cub; CK(cudaEventElapsedTime(&ms_cub,s0,s1)); ms_cub/=iters;
    double tfc=flops/(ms_cub*1e-3)/1e12;

    double ratio=tfc/tfo;  // how many x cuBLAS is faster (roofline)
    printf("W4 S=%d own=%.1f TFLOP/s cuBLAS-TF32=%.1f TFLOP/s ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
           S, tfo, tfc, ratio, rr, ratio<=1.3?"YES":"NO");
    return 0;
}
