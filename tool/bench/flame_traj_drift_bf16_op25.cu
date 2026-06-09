// flame_traj_drift_bf16_op25.cu — HEXA-0POD OP-25: BF16 vs FP64 N-step TRAJECTORY drift.
//
// The OP-23-for-BF16 validation. OP-25's 1-step harness proves the single BF16 flame step is
// (a) self-byte-eq run-to-run and (b) rel-RMS ~e-3 vs FP64 (looser than TF32's e-6 but inside
// the W14 1e-2 contract). The decisive question (same as OP-23 for TF32): does the e-3
// per-step error ACCUMULATE/PEEL over N steps, or does the BF16 LOSS still TRACK FP64?
//
// HONEST FRAMING (g5): NN training is CHAOTIC — weights diverge under any perturbation
// (butterfly), so the RIGHT metric is "does BF16 LOSS track FP64 LOSS within training noise",
// NOT "do the weights stay byte-close". BF16's per-step error is ~1000x larger than TF32's,
// so this is exactly where BF16 might PEEL where TF32 didn't. We report BOTH the weight
// rel-RMS/max|delta| (chaotic-but-bounded expected) AND the per-step loss of each lane (the
// decisive curve). Bounded loss-tracking = BF16 still trainable; loss blow-up = BF16 peels.
//
// One CONTINUOUS trajectory per lane (AdamW state W,m,v PERSISTS across steps so drift
// accumulates). Master weights kept in fp32 for BF16, the bf16 copy refreshed each AdamW (the
// standard mixed-precision contract). Both lanes start from the SAME seed, same fixed data.
// Step DAG identical to OP-25 1-step; ADD a deterministic scalar LOSS=mean(G^2), fp64 reduce.
//
// Build: nvcc -arch=sm_120 -O3 -o flame_traj_op25 flame_traj_drift_bf16_op25.cu -lcublas
//        add -DPEDANTIC for the pedantic-cublas determinism variant.
// Run:   ./flame_traj_op25 D T B Nsteps

#include <cuda_runtime.h>
#include <cuda_bf16.h>
#include <cublas_v2.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define ADAM_LR  0.001
#define ADAM_B1  0.9
#define ADAM_B2  0.999
#define ADAM_EPS 1e-8
#define ADAM_WD  0.01

static void ck(cudaError_t e, const char* what){
    if(e!=cudaSuccess){ printf("CUDA ERR %s: %s\n", what, cudaGetErrorString(e)); exit(2);} }

template<class R> struct Acc        { typedef double type; };
template<>        struct Acc<float> { typedef float  type; };
template<>        struct Acc<__nv_bfloat16> { typedef float type; };

template<class A> __device__ __forceinline__ A gelu_acc(A v){
    A c=(A)0.7978845608;
    return (A)0.5*v*((A)1.0+(A)tanh((double)(c*(v+(A)0.044715*v*v*v))));
}
template<class R> __device__ __forceinline__ typename Acc<R>::type ld(const R* p, long long i){ return (typename Acc<R>::type)p[i]; }
template<> __device__ __forceinline__ float ld<__nv_bfloat16>(const __nv_bfloat16* p, long long i){ return __bfloat162float(p[i]); }
template<class R> __device__ __forceinline__ void st(R* p, long long i, typename Acc<R>::type v){ p[i]=(R)v; }
template<> __device__ __forceinline__ void st<__nv_bfloat16>(__nv_bfloat16* p, long long i, float v){ p[i]=__float2bfloat16(v); }

template<class R>
__global__ void k_valley(const R* __restrict__ H, R* __restrict__ G,
                         const R* __restrict__ dGrad, R* __restrict__ dGq, int M, int N){
    typedef typename Acc<R>::type A;
    int row=blockIdx.x; if(row>=M) return;
    __shared__ A red[256];
    int t=threadIdx.x, nt=blockDim.x;
    A s=(A)0; for(int j=t;j<N;j+=nt) s+=ld<R>(H,(long long)row*N+j);
    red[t]=s; __syncthreads();
    for(int o=nt/2;o>0;o>>=1){ if(t<o) red[t]+=red[t+o]; __syncthreads(); }
    A mean=red[0]/(A)N; __syncthreads();
    A v=(A)0; for(int j=t;j<N;j+=nt){ A d=ld<R>(H,(long long)row*N+j)-mean; v+=d*d; }
    red[t]=v; __syncthreads();
    for(int o=nt/2;o>0;o>>=1){ if(t<o) red[t]+=red[t+o]; __syncthreads(); }
    A inv=(A)1.0/(A)sqrt((double)(red[0]/(A)N+(A)1e-5)); __syncthreads();
    for(int j=t;j<N;j+=nt){
        long long idx=(long long)row*N+j;
        st<R>(G,   idx, gelu_acc<A>((ld<R>(H,idx)-mean)*inv));
        st<R>(dGq, idx, ld<R>(dGrad,idx));
    }
}

template<class R>
__global__ void k_adamw(const R* dWs, typename Acc<R>::type* Wf,
                        typename Acc<R>::type* Mm, typename Acc<R>::type* Vv,
                        R* Wlp, long long n, int tstep){
    typedef typename Acc<R>::type A;
    A bc1=(A)1.0-(A)pow((double)ADAM_B1,(double)tstep);
    A bc2=(A)1.0-(A)pow((double)ADAM_B2,(double)tstep);
    long long stride=(long long)blockDim.x*gridDim.x;
    for(long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride){
        A g=ld<R>(dWs,i);
        A m=(A)ADAM_B1*Mm[i]+(A)(1.0-ADAM_B1)*g;
        A v=(A)ADAM_B2*Vv[i]+(A)(1.0-ADAM_B2)*g*g;
        Mm[i]=m; Vv[i]=v;
        A mh=m/bc1, vh=v/bc2, w=Wf[i];
        w=w-(A)ADAM_LR*(mh/((A)sqrt((double)vh)+(A)ADAM_EPS)+(A)ADAM_WD*w);
        Wf[i]=w; st<R>(Wlp,i,w);
    }
}

// deterministic scalar loss = mean(G^2), fixed-order block tree reduce in fp64. No atomics.
template<class R>
__global__ void k_loss_partial(const R* __restrict__ G, double* __restrict__ part, long long n){
    __shared__ double red[256];
    int t=threadIdx.x, nt=blockDim.x;
    double s=0;
    for(long long i=(long long)blockIdx.x*nt+t; i<n; i+=(long long)nt*gridDim.x){
        double g=ld<R>(G,i); s+=g*g;
    }
    red[t]=s; __syncthreads();
    for(int o=nt/2;o>0;o>>=1){ if(t<o) red[t]+=red[t+o]; __syncthreads(); }
    if(t==0) part[blockIdx.x]=red[0];
}
__global__ void k_loss_final(const double* __restrict__ part, int nblk, double* __restrict__ out, long long n){
    __shared__ double red[256];
    int t=threadIdx.x;
    double s=0; for(int i=t;i<nblk;i+=blockDim.x) s+=part[i];
    red[t]=s; __syncthreads();
    for(int o=blockDim.x/2;o>0;o>>=1){ if(t<o) red[t]+=red[t+o]; __syncthreads(); }
    if(t==0) out[0]=red[0]/(double)n;
}

template<class R> __global__ void fill_r(R* x, long long n, unsigned seed, double scale){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n){ unsigned h=(unsigned)(i*2654435761u)^seed; double val=((h&0xffff)/65535.0-0.5)*scale; st<R>(x,i,(typename Acc<R>::type)val); }
}
template<class R> __global__ void fillacc(typename Acc<R>::type* x, long long n, unsigned seed, double scale){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=(typename Acc<R>::type)(((h&0xffff)/65535.0-0.5)*scale); }
}
template<class R> __global__ void copyacc(const typename Acc<R>::type* s, R* d, long long n){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n) st<R>(d,i,s[i]); }
template<class T> __global__ void zero_t(T* x,long long n){ long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n)x[i]=(T)0; }
template<class T> __global__ void copy_t(const T* s,T* d,long long n){ long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n)d[i]=s[i]; }

template<class R>
struct Lane { cublasHandle_t h; cudaDataType_t dt; cublasComputeType_t ct; cublasGemmAlgo_t algo; };

template<class R>
static void gemm_op(Lane<R>& L, R* C, const R* A, const R* Bm, int M, int K, int N,
                    cublasOperation_t opA, int lda){
    if (L.ct==CUBLAS_COMPUTE_64F){ const double a=1.0,b=0.0;
        cublasGemmEx(L.h, CUBLAS_OP_N, opA, N, M, K, &a, Bm, L.dt, N, A, L.dt, lda, &b,
                     C, L.dt, N, L.ct, L.algo);
    } else { const float a=1.f,b=0.f;
        cublasGemmEx(L.h, CUBLAS_OP_N, opA, N, M, K, &a, Bm, L.dt, N, A, L.dt, lda, &b,
                     C, L.dt, N, L.ct, L.algo);
    }
}
template<class R> static void gemm(Lane<R>& L, R* C, const R* A, const R* Bm, int M,int K,int N){
    gemm_op<R>(L, C, A, Bm, M, K, N, CUBLAS_OP_N, K);
}

template<class R>
struct Buf {
    typedef typename Acc<R>::type A;
    R *Astor,*Wlp,*H,*G,*dGrad,*dGq,*dW;
    A *Wf,*Mm,*Vv,*Wsnap;
    long long MK,MN,KN;
};
template<class R>
static bool alloc_lane(Buf<R>& b, int M,int K,int N){
    typedef typename Acc<R>::type A;
    b.MK=(long long)M*K; b.MN=(long long)M*N; b.KN=(long long)K*N;
    auto AR=[&](R**pp,long long n){ return cudaMalloc((void**)pp,n*sizeof(R))==cudaSuccess; };
    auto AA=[&](A**pp,long long n){ return cudaMalloc((void**)pp,n*sizeof(A))==cudaSuccess; };
    return AR(&b.Astor,b.MK)&&AR(&b.Wlp,b.KN)&&AR(&b.H,b.MN)&&AR(&b.G,b.MN)&&AR(&b.dGrad,b.MN)
         &&AR(&b.dGq,b.MN)&&AR(&b.dW,b.KN)
         &&AA(&b.Wf,b.KN)&&AA(&b.Mm,b.KN)&&AA(&b.Vv,b.KN)&&AA(&b.Wsnap,b.KN);
}
template<class R>
static void init_lane(Buf<R>& b, int M,int K,int N){
    auto gB=[&](long long n){ return (int)((n+255)/256); };
    fill_r<R><<<gB(b.MK),256>>>(b.Astor,b.MK,11,0.1);
    fillacc<R><<<gB(b.KN),256>>>(b.Wf,b.KN,33,0.02);
    copyacc<R><<<gB(b.KN),256>>>(b.Wf,b.Wlp,b.KN);
    fill_r<R><<<gB(b.MN),256>>>(b.dGrad,b.MN,44,0.05);
    copy_t<typename Acc<R>::type><<<gB(b.KN),256>>>(b.Wf,b.Wsnap,b.KN);
    zero_t<typename Acc<R>::type><<<gB(b.KN),256>>>(b.Mm,b.KN);
    zero_t<typename Acc<R>::type><<<gB(b.KN),256>>>(b.Vv,b.KN);
    ck(cudaDeviceSynchronize(),"init_lane");
}
template<class R>
static void reset_lane(Buf<R>& b){
    auto gB=[&](long long n){ return (int)((n+255)/256); };
    copy_t<typename Acc<R>::type><<<gB(b.KN),256>>>(b.Wsnap,b.Wf,b.KN);
    copyacc<R><<<gB(b.KN),256>>>(b.Wf,b.Wlp,b.KN);
    zero_t<typename Acc<R>::type><<<gB(b.KN),256>>>(b.Mm,b.KN);
    zero_t<typename Acc<R>::type><<<gB(b.KN),256>>>(b.Vv,b.KN);
    ck(cudaDeviceSynchronize(),"reset_lane");
}

template<class R>
static void run_step(Buf<R>& b, Lane<R>& L, int M,int K,int N,long long KN,int eGrid,int tstep,
                     double* part, double* lossOut, int lblk){
    gemm<R>(L, b.H, b.Astor, b.Wlp, M, K, N);
    k_valley<R><<<M,256>>>(b.H,b.G,b.dGrad,b.dGq,M,N);
    long long MN=(long long)M*N;
    k_loss_partial<R><<<lblk,256>>>(b.G, part, MN);
    k_loss_final<<<1,256>>>(part, lblk, lossOut, MN);
    gemm_op<R>(L, b.dW, b.Astor, b.dGq, K, M, N, CUBLAS_OP_T, K);
    k_adamw<R><<<eGrid,256>>>(b.dW,b.Wf,b.Mm,b.Vv,b.Wlp,KN,tstep);
}

template<class R>
static void wf_to_host(Buf<R>& b, double* out, long long KN){
    typedef typename Acc<R>::type A;
    A* tmp=(A*)malloc(KN*sizeof(A));
    ck(cudaMemcpy(tmp,b.Wf,KN*sizeof(A),cudaMemcpyDeviceToHost),"wf2host");
    for(long long i=0;i<KN;i++) out[i]=(double)tmp[i];
    free(tmp);
}

// run a full N-step BF16 trajectory recording loss/step + final master W (host double buffer).
static void run_traj_bf16(Lane<__nv_bfloat16>& L, Buf<__nv_bfloat16>& b, int M,int K,int N,long long KN,
                          int eGrid,int Nsteps,double* part,double* dLoss,int lblk,
                          double* lossArr, double* wFinal){
    reset_lane<__nv_bfloat16>(b);
    for(int s=0;s<Nsteps;s++){
        run_step<__nv_bfloat16>(b,L,M,K,N,KN,eGrid,s+1,part,dLoss,lblk);
        ck(cudaMemcpy(&lossArr[s],dLoss,sizeof(double),cudaMemcpyDeviceToHost),"cp-loss-bf16");
    }
    ck(cudaDeviceSynchronize(),"traj-bf16");
    wf_to_host<__nv_bfloat16>(b,wFinal,KN);
}

int main(int argc,char**argv){
    int D=(argc>1)?atoi(argv[1]):768;
    int T=(argc>2)?atoi(argv[2]):256;
    int B=(argc>3)?atoi(argv[3]):1;
    int Nsteps=(argc>4)?atoi(argv[4]):100;
    int M=B*T, K=D, N=D;
    long long KN=(long long)K*N;
    int eGrid=(int)((KN+255)/256);
    cudaSetDevice(0);
    cudaDeviceProp p; cudaGetDeviceProperties(&p,0);

#ifdef PEDANTIC
    const char* MODE_NAME="BF16-PEDANTIC";
#else
    const char* MODE_NAME="BF16-DEFAULT";
#endif
    printf("[CFG] OP-25-DRIFT %s  GPU=%s cc=%d.%d  D=%d T=%d B=%d -> M=%d K=%d N=%d Nsteps=%d\n",
           MODE_NAME,p.name,p.major,p.minor,D,T,B,M,K,N,Nsteps);

    Lane<__nv_bfloat16> Lb; cublasCreate(&Lb.h);
#ifdef PEDANTIC
    cublasSetMathMode(Lb.h, CUBLAS_PEDANTIC_MATH);
#else
    cublasSetMathMode(Lb.h, CUBLAS_DEFAULT_MATH);
#endif
    Lb.dt=CUDA_R_16BF; Lb.ct=CUBLAS_COMPUTE_32F_FAST_16BF; Lb.algo=CUBLAS_GEMM_DEFAULT_TENSOR_OP;

    Lane<double> Lf; cublasCreate(&Lf.h);
    cublasSetMathMode(Lf.h, CUBLAS_DEFAULT_MATH);
    Lf.dt=CUDA_R_64F; Lf.ct=CUBLAS_COMPUTE_64F; Lf.algo=CUBLAS_GEMM_DEFAULT;

    Buf<__nv_bfloat16> bb; Buf<double> bf;
    if(!alloc_lane<__nv_bfloat16>(bb,M,K,N) || !alloc_lane<double>(bf,M,K,N)){
        printf("[RESULT] OP-25-DRIFT %s B=%d D=%d OOM\n",MODE_NAME,B,D); return 3; }
    init_lane<__nv_bfloat16>(bb,M,K,N); init_lane<double>(bf,M,K,N);

    long long MN=(long long)M*N;
    int lblk=(int)((MN+255)/256); if(lblk>1024) lblk=1024; if(lblk<1) lblk=1;
    double *partB,*partF,*dLossB,*dLossF;
    ck(cudaMalloc((void**)&partB,lblk*sizeof(double)),"part-b");
    ck(cudaMalloc((void**)&partF,lblk*sizeof(double)),"part-f");
    ck(cudaMalloc((void**)&dLossB,sizeof(double)),"dloss-b");
    ck(cudaMalloc((void**)&dLossF,sizeof(double)),"dloss-f");

    double* lossB =(double*)malloc(Nsteps*sizeof(double));
    double* lossB2=(double*)malloc(Nsteps*sizeof(double));
    double* lossF =(double*)malloc(Nsteps*sizeof(double));
    double* wB    =(double*)malloc(KN*sizeof(double));
    double* wB2   =(double*)malloc(KN*sizeof(double));
    double* wBcmp =(double*)malloc(KN*sizeof(double));
    double* wF    =(double*)malloc(KN*sizeof(double));

    // ---- BF16 trajectory run #1 + #2 (whole-trajectory determinism) ----
    run_traj_bf16(Lb,bb,M,K,N,KN,eGrid,Nsteps,partB,dLossB,lblk,lossB,wB);
    run_traj_bf16(Lb,bb,M,K,N,KN,eGrid,Nsteps,partB,dLossB,lblk,lossB2,wB2);
    double maxd=0; for(long long i=0;i<KN;i++){ double d=fabs(wB[i]-wB2[i]); if(d>maxd)maxd=d; }
    double lossMaxd=0; for(int s=0;s<Nsteps;s++){ double d=fabs(lossB[s]-lossB2[s]); if(d>lossMaxd)lossMaxd=d; }

    // ---- lockstep BF16 + FP64 to get per-step loss + sampled weight rel-RMS ----
    reset_lane<__nv_bfloat16>(bb); reset_lane<double>(bf);
    int sampleEvery = (Nsteps<=20)?1:(Nsteps/20);
    printf("[TRAJ] step   lossBF16         lossFP64         |dLoss|/|lossFP64|   relRMS(W_BF16 vs W_FP64)   maxAbs(W_BF16-W_FP64)\n");
    for(int s=0;s<Nsteps;s++){
        run_step<__nv_bfloat16>(bb,Lb,M,K,N,KN,eGrid,s+1,partB,dLossB,lblk);
        run_step<double>(bf,Lf,M,K,N,KN,eGrid,s+1,partF,dLossF,lblk);
        double lt,lf; ck(cudaMemcpy(&lt,dLossB,sizeof(double),cudaMemcpyDeviceToHost),"lt");
        ck(cudaMemcpy(&lf,dLossF,sizeof(double),cudaMemcpyDeviceToHost),"lf");
        lossB[s]=lt; lossF[s]=lf;
        bool isSample = (s%sampleEvery==0) || (s==Nsteps-1);
        if(isSample){
            wf_to_host<__nv_bfloat16>(bb,wBcmp,KN);
            wf_to_host<double>(bf,wF,KN);
            double se=0,sr=0,wmax=0;
            for(long long i=0;i<KN;i++){ double a=wBcmp[i], b=wF[i];
                se+=(a-b)*(a-b); sr+=b*b; double ad=fabs(a-b); if(ad>wmax)wmax=ad; }
            double relrms=(sr>0)?sqrt(se/KN)/sqrt(sr/KN):0.0;
            double lossRel=(fabs(lf)>0)?fabs(lt-lf)/fabs(lf):0.0;
            printf("[TRAJ] %5d   %.8e   %.8e   %.6e        %.6e             %.6e\n",
                   s+1, lt, lf, lossRel, relrms, wmax);
        }
    }

    wf_to_host<__nv_bfloat16>(bb,wBcmp,KN);
    wf_to_host<double>(bf,wF,KN);
    double se=0,sr=0,wmax=0;
    for(long long i=0;i<KN;i++){ double a=wBcmp[i], b=wF[i];
        se+=(a-b)*(a-b); sr+=b*b; double ad=fabs(a-b); if(ad>wmax)wmax=ad; }
    double relrmsN=(sr>0)?sqrt(se/KN)/sqrt(sr/KN):0.0;
    double lossRelN=(fabs(lossF[Nsteps-1])>0)?fabs(lossB[Nsteps-1]-lossF[Nsteps-1])/fabs(lossF[Nsteps-1]):0.0;

    double worstLossRel=0; int worstStep=0;
    for(int s=0;s<Nsteps;s++){ double r=(fabs(lossF[s])>0)?fabs(lossB[s]-lossF[s])/fabs(lossF[s]):0.0;
        if(r>worstLossRel){worstLossRel=r; worstStep=s+1;} }

    printf("\n[SUMMARY] OP-25-DRIFT %s D=%d T=%d B=%d Nsteps=%d\n",MODE_NAME,D,T,B,Nsteps);
    printf("[SUMMARY] BF16 self-byte-eq over WHOLE trajectory (run1 vs run2): W max|delta|=%.3e  loss max|delta|=%.3e  (==0: %s)\n",
           maxd, lossMaxd, (maxd==0.0 && lossMaxd==0.0)?"YES":"NO");
    printf("[SUMMARY] step-N weight relRMS(BF16 vs FP64) = %.6e   max|dW| = %.6e\n", relrmsN, wmax);
    printf("[SUMMARY] step-N loss-tracking  |dLoss|/|lossFP64| = %.6e\n", lossRelN);
    printf("[SUMMARY] WORST loss-tracking gap over trajectory = %.6e at step %d\n", worstLossRel, worstStep);
    printf("[RESULT] OP-25-DRIFT %s D=%d B=%d Nsteps=%d  selfByteEqN=%s  relRMS_W_N=%.3e  lossTrackN=%.3e  worstLossTrack=%.3e\n",
           MODE_NAME,D,B,Nsteps, (maxd==0.0&&lossMaxd==0.0)?"Y":"N", relrmsN, lossRelN, worstLossRel);

    free(lossB);free(lossB2);free(lossF);free(wB);free(wB2);free(wBcmp);free(wF);
    return 0;
}
