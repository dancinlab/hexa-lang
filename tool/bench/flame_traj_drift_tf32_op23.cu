// flame_traj_drift_tf32_op23.cu — HEXA-0POD OP-23: TF32 vs FP64 N-step TRAJECTORY drift.
//
// THE DECISIVE VALIDATION of OP-20's deterministic TF32 fast-mode. OP-20 proved a single
// TF32 flame step is (a) self-byte-eq run-to-run and (b) rel-RMS ~1.13e-6 vs FP64 at ONE
// step, 4.2x+ faster (breaks the ~3x FP64 cap). OP-20's verdict flagged the OPEN question:
//   "Multi-step drift of the TF32 trajectory vs FP64 is the (larger) question, deferred."
//
// THAT is this harness. A 1-step rel-RMS of 1e-6 could be EITHER:
//   (a) a real fast-mode  — drift stays bounded, the LOSS curves track over N steps, or
//   (b) a 1-step illusion — the TF32 trajectory peels away from FP64 (loss diverges).
//
// HONEST FRAMING (g5): NN training is CHAOTIC. Even FP64-vs-FP64 with a 1-ULP perturbation
// diverges in WEIGHTS over many steps (butterfly effect) while the LOSS stays equivalent.
// So the RIGHT metric is "does TF32 LOSS track FP64 LOSS within training noise" (training-
// equivalent), NOT "do the weights stay byte-close" (they won't, and that's fine — that is
// exactly why flame's byte-exact identity is SELF-determinism, not cross-precision). We
// therefore report BOTH: weight rel-RMS / max|delta| (expected: chaotic-but-bounded) AND
// the per-step loss of each lane (the decisive curve). Bounded loss-tracking = TF32 is a
// real fast-mode; loss divergence = the 1-step number was an illusion.
//
// Unlike OP-20's flame_bench_step_tf32fast.cu (which RESETS the weights before each timed
// step so every step is independent), this harness runs ONE CONTINUOUS trajectory per lane:
// the AdamW state (W, m, v) PERSISTS across steps so drift can ACCUMULATE. Both lanes start
// from the SAME seed and consume the SAME fixed data every step.
//
// The step DAG is byte-identical to OP-20 (fwd GEMM -> fused valley LN+gelu+copy ->
// transpose-elim bwd GEMM -> single-launch AdamW); only the cuBLAS compute type differs.
// We ADD a deterministic scalar LOSS = mean(G^2) over the post-valley activation (fixed-
// order block reduce, no atomics) so each lane reports a comparable per-step loss.
//
// Build: nvcc -arch=sm_120 -O3 -o flame_traj_op23 flame_traj_drift_tf32_op23.cu -lcublas
//        add -DPEDANTIC for the pedantic-cublas determinism variant.
// Run:   ./flame_traj_op23 D T B Nsteps

#include <cuda_runtime.h>
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

template<class R>
__device__ __forceinline__ R gelu_glue(R v){
    R c = (R)0.7978845608;
    return (R)0.5*v*((R)1.0+tanh(c*(v+(R)0.044715*v*v*v)));
}

template<class R>
__global__ void k_valley(const R* __restrict__ H, R* __restrict__ G,
                         const R* __restrict__ dGrad, R* __restrict__ dGq, int M, int N){
    int row = blockIdx.x; if(row>=M) return;
    __shared__ R red[256];
    int t = threadIdx.x, nt = blockDim.x;
    R s=(R)0; for(int j=t;j<N;j+=nt) s+=H[(long long)row*N+j];
    red[t]=s; __syncthreads();
    for(int o=nt/2;o>0;o>>=1){ if(t<o) red[t]+=red[t+o]; __syncthreads(); }
    R mean=red[0]/(R)N; __syncthreads();
    R v=(R)0; for(int j=t;j<N;j+=nt){ R d=H[(long long)row*N+j]-mean; v+=d*d; }
    red[t]=v; __syncthreads();
    for(int o=nt/2;o>0;o>>=1){ if(t<o) red[t]+=red[t+o]; __syncthreads(); }
    R inv = (R)1.0/sqrt(red[0]/(R)N + (R)1e-5); __syncthreads();
    for(int j=t;j<N;j+=nt){
        long long idx=(long long)row*N+j;
        G[idx]   = gelu_glue<R>((H[idx]-mean)*inv);
        dGq[idx] = dGrad[idx];
    }
}

template<class R>
__global__ void k_adamw(R* dW, R* Wf, R* Mm, R* Vv, long long n, int tstep){
    R bc1=(R)1.0-(R)pow((double)ADAM_B1,(double)tstep);
    R bc2=(R)1.0-(R)pow((double)ADAM_B2,(double)tstep);
    long long stride=(long long)blockDim.x*gridDim.x;
    for(long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride){
        R g=dW[i];
        R m=(R)ADAM_B1*Mm[i]+(R)(1.0-ADAM_B1)*g;
        R v=(R)ADAM_B2*Vv[i]+(R)(1.0-ADAM_B2)*g*g;
        Mm[i]=m; Vv[i]=v;
        R mh=m/bc1, vh=v/bc2, w=Wf[i];
        w=w-(R)ADAM_LR*(mh/(sqrt(vh)+(R)ADAM_EPS)+(R)ADAM_WD*w);
        Wf[i]=w;
    }
}

// deterministic scalar loss = sum(G^2) over post-valley activation, fixed-order block tree
// reduce into a per-block partial, then a single-block final reduce. No atomics.
template<class R>
__global__ void k_loss_partial(const R* __restrict__ G, double* __restrict__ part, long long n){
    __shared__ double red[256];
    int t=threadIdx.x, nt=blockDim.x;
    double s=0;
    for(long long i=(long long)blockIdx.x*nt+t; i<n; i+=(long long)nt*gridDim.x){
        double g=(double)G[i]; s+=g*g;
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
    if(t==0) out[0]=red[0]/(double)n;   // mean(G^2)
}

template<class R>
__global__ void fill_r(R* x, long long n, unsigned seed, double scale){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=(R)(((h&0xffff)/65535.0-0.5)*scale); }
}
template<class R> __global__ void zero_r(R* x,long long n){ long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n)x[i]=(R)0; }
template<class R> __global__ void copy_r(const R* s,R* d,long long n){ long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n)d[i]=s[i]; }

template<class R>
struct Lane {
    cublasHandle_t h;
    cudaDataType_t dt;
    cublasComputeType_t ct;
    cublasGemmAlgo_t algo;
};

template<class R>
static void gemm_op(Lane<R>& L, R* C, const R* A, const R* Bm, int M, int K, int N,
                    cublasOperation_t opA, int lda){
    if (sizeof(R)==8){ const double a=1.0,b=0.0;
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

// run ONE step; ALSO returns this step's loss (mean(G^2)) via the device scalar lossOut.
template<class R>
static void run_step(Lane<R>& L, R* A, R* Wf, R* H, R* G, R* dGrad, R* dGq, R* dW,
                     R* Mm, R* Vv, int M, int K, int N, long long KN, int eGrid, int tstep,
                     double* part, double* lossOut, int lblk){
    gemm<R>(L, H, A, Wf, M, K, N);
    k_valley<R><<<M,256>>>(H,G,dGrad,dGq,M,N);
    long long MN=(long long)M*N;
    k_loss_partial<R><<<lblk,256>>>(G, part, MN);
    k_loss_final<<<1,256>>>(part, lblk, lossOut, MN);
    gemm_op<R>(L, dW, A, dGq, K, M, N, CUBLAS_OP_T, K);
    k_adamw<R><<<eGrid,256>>>(dW,Wf,Mm,Vv,KN,tstep);
}

template<class R>
struct Buf { R *A,*H,*G,*dGrad,*dGq,*dW,*Wf,*Mm,*Vv,*Wsnap; long long MK,MN,KN; };

template<class R>
static bool alloc_lane(Buf<R>& b, int M,int K,int N){
    b.MK=(long long)M*K; b.MN=(long long)M*N; b.KN=(long long)K*N;
    auto A=[&](R**pp,long long n){ return cudaMalloc((void**)pp,n*sizeof(R))==cudaSuccess; };
    return A(&b.A,b.MK)&&A(&b.H,b.MN)&&A(&b.G,b.MN)&&A(&b.dGrad,b.MN)&&A(&b.dGq,b.MN)
         &&A(&b.dW,b.KN)&&A(&b.Wf,b.KN)&&A(&b.Mm,b.KN)&&A(&b.Vv,b.KN)&&A(&b.Wsnap,b.KN);
}
template<class R>
static void init_lane(Buf<R>& b, int M,int K,int N){
    auto gB=[&](long long n){ return (int)((n+255)/256); };
    fill_r<R><<<gB(b.MK),256>>>(b.A,b.MK,11,0.1);
    fill_r<R><<<gB(b.KN),256>>>(b.Wf,b.KN,33,0.02);
    fill_r<R><<<gB(b.MN),256>>>(b.dGrad,b.MN,44,0.05);
    copy_r<R><<<gB(b.KN),256>>>(b.Wf,b.Wsnap,b.KN);
    zero_r<R><<<gB(b.KN),256>>>(b.Mm,b.KN); zero_r<R><<<gB(b.KN),256>>>(b.Vv,b.KN);
    ck(cudaDeviceSynchronize(),"init_lane");
}
template<class R>
static void reset_lane(Buf<R>& b){
    auto gB=[&](long long n){ return (int)((n+255)/256); };
    copy_r<R><<<gB(b.KN),256>>>(b.Wsnap,b.Wf,b.KN);
    zero_r<R><<<gB(b.KN),256>>>(b.Mm,b.KN); zero_r<R><<<gB(b.KN),256>>>(b.Vv,b.KN);
    ck(cudaDeviceSynchronize(),"reset_lane");
}

// run a full N-step TF32 trajectory into host arrays (loss per step + final W snapshot).
// Returns via out-params. lossArr must hold Nsteps doubles; wFinal must hold KN floats.
static void run_traj_tf32(Lane<float>& L, Buf<float>& b, int M,int K,int N,long long KN,
                          int eGrid,int Nsteps,double* part,double* dLoss,int lblk,
                          double* lossArr, float* wFinal){
    reset_lane<float>(b);
    for(int s=0;s<Nsteps;s++){
        run_step<float>(L,b.A,b.Wf,b.H,b.G,b.dGrad,b.dGq,b.dW,b.Mm,b.Vv,M,K,N,KN,eGrid,s+1,part,dLoss,lblk);
        ck(cudaMemcpy(&lossArr[s],dLoss,sizeof(double),cudaMemcpyDeviceToHost),"cp-loss-tf32");
    }
    ck(cudaDeviceSynchronize(),"traj-tf32");
    ck(cudaMemcpy(wFinal,b.Wf,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp-wfin-tf32");
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
    const char* MODE_NAME="TF32-PEDANTIC";
#else
    const char* MODE_NAME="TF32-DEFAULT";
#endif
    printf("[CFG] OP-23 %s  GPU=%s cc=%d.%d  D=%d T=%d B=%d -> M=%d K=%d N=%d Nsteps=%d\n",
           MODE_NAME,p.name,p.major,p.minor,D,T,B,M,K,N,Nsteps);

    Lane<float> Lt; cublasCreate(&Lt.h);
#ifdef PEDANTIC
    cublasSetMathMode(Lt.h, CUBLAS_PEDANTIC_MATH);
#else
    cublasSetMathMode(Lt.h, CUBLAS_TF32_TENSOR_OP_MATH);
#endif
    Lt.dt=CUDA_R_32F; Lt.ct=CUBLAS_COMPUTE_32F_FAST_TF32; Lt.algo=CUBLAS_GEMM_DEFAULT_TENSOR_OP;

    Lane<double> Lf; cublasCreate(&Lf.h);
    cublasSetMathMode(Lf.h, CUBLAS_DEFAULT_MATH);
    Lf.dt=CUDA_R_64F; Lf.ct=CUBLAS_COMPUTE_64F; Lf.algo=CUBLAS_GEMM_DEFAULT;

    Buf<float> bt; Buf<double> bf;
    if(!alloc_lane<float>(bt,M,K,N) || !alloc_lane<double>(bf,M,K,N)){
        printf("[RESULT] OP-23 %s B=%d D=%d OOM\n",MODE_NAME,B,D); return 3; }
    init_lane<float>(bt,M,K,N); init_lane<double>(bf,M,K,N);

    long long MN=(long long)M*N;
    int lblk=(int)((MN+255)/256); if(lblk>1024) lblk=1024; if(lblk<1) lblk=1;
    double *partT,*partF,*dLossT,*dLossF;
    ck(cudaMalloc((void**)&partT,lblk*sizeof(double)),"part-t");
    ck(cudaMalloc((void**)&partF,lblk*sizeof(double)),"part-f");
    ck(cudaMalloc((void**)&dLossT,sizeof(double)),"dloss-t");
    ck(cudaMalloc((void**)&dLossF,sizeof(double)),"dloss-f");

    double* lossT =(double*)malloc(Nsteps*sizeof(double));
    double* lossT2=(double*)malloc(Nsteps*sizeof(double));
    double* lossF =(double*)malloc(Nsteps*sizeof(double));
    float*  wT    =(float*) malloc(KN*sizeof(float));
    float*  wT2   =(float*) malloc(KN*sizeof(float));
    float*  wTcmp =(float*) malloc(KN*sizeof(float));   // tracked param compare lane buffer
    double* wF    =(double*)malloc(KN*sizeof(double));

    // ---- TF32 trajectory run #1 (records loss/step + final W) ----
    run_traj_tf32(Lt,bt,M,K,N,KN,eGrid,Nsteps,partT,dLossT,lblk,lossT,wT);

    // ---- TF32 trajectory run #2 (determinism-over-the-whole-trajectory check) ----
    run_traj_tf32(Lt,bt,M,K,N,KN,eGrid,Nsteps,partT,dLossT,lblk,lossT2,wT2);

    // self-byte-eq at step N: max|delta(W')| between the two TF32 trajectories.
    double maxd=0; for(long long i=0;i<KN;i++){ double d=fabs((double)wT[i]-(double)wT2[i]); if(d>maxd)maxd=d; }
    // also per-step loss byte-eq across the two TF32 runs.
    double lossMaxd=0; for(int s=0;s<Nsteps;s++){ double d=fabs(lossT[s]-lossT2[s]); if(d>lossMaxd)lossMaxd=d; }

    // ---- FP64 reference trajectory: we need per-step weight rel-RMS, so we run BOTH lanes
    //      step-by-step in lockstep and snapshot W at sampled steps. Re-run from scratch. ----
    reset_lane<float>(bt); reset_lane<double>(bf);
    // sample schedule: every step if Nsteps<=20 else ~20 evenly spaced + always the last.
    int sampleEvery = (Nsteps<=20)?1:(Nsteps/20);
    printf("[TRAJ] step   lossTF32        lossFP64        |dLoss|/|lossFP64|   relRMS(W_TF32 vs W_FP64)   maxAbs(W_TF32-W_FP64)\n");
    for(int s=0;s<Nsteps;s++){
        run_step<float >(Lt,bt.A,bt.Wf,bt.H,bt.G,bt.dGrad,bt.dGq,bt.dW,bt.Mm,bt.Vv,M,K,N,KN,eGrid,s+1,partT,dLossT,lblk);
        run_step<double>(Lf,bf.A,bf.Wf,bf.H,bf.G,bf.dGrad,bf.dGq,bf.dW,bf.Mm,bf.Vv,M,K,N,KN,eGrid,s+1,partF,dLossF,lblk);
        double lt,lf; ck(cudaMemcpy(&lt,dLossT,sizeof(double),cudaMemcpyDeviceToHost),"lt");
        ck(cudaMemcpy(&lf,dLossF,sizeof(double),cudaMemcpyDeviceToHost),"lf");
        lossT[s]=lt; lossF[s]=lf;
        bool isSample = (s%sampleEvery==0) || (s==Nsteps-1);
        if(isSample){
            ck(cudaMemcpy(wTcmp,bt.Wf,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp-wt-lock");
            ck(cudaMemcpy(wF,bf.Wf,KN*sizeof(double),cudaMemcpyDeviceToHost),"cp-wf-lock");
            double se=0,sr=0,wmax=0;
            for(long long i=0;i<KN;i++){ double a=(double)wTcmp[i], b=wF[i];
                se+=(a-b)*(a-b); sr+=b*b; double ad=fabs(a-b); if(ad>wmax)wmax=ad; }
            double relrms=(sr>0)?sqrt(se/KN)/sqrt(sr/KN):0.0;
            double lossRel=(fabs(lf)>0)?fabs(lt-lf)/fabs(lf):0.0;
            printf("[TRAJ] %5d   %.8e   %.8e   %.6e        %.6e             %.6e\n",
                   s+1, lt, lf, lossRel, relrms, wmax);
        }
    }

    // final-step summary numbers (from the lockstep run above).
    ck(cudaMemcpy(wTcmp,bt.Wf,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp-wt-fin");
    ck(cudaMemcpy(wF,bf.Wf,KN*sizeof(double),cudaMemcpyDeviceToHost),"cp-wf-fin");
    double se=0,sr=0,wmax=0;
    for(long long i=0;i<KN;i++){ double a=(double)wTcmp[i], b=wF[i];
        se+=(a-b)*(a-b); sr+=b*b; double ad=fabs(a-b); if(ad>wmax)wmax=ad; }
    double relrmsN=(sr>0)?sqrt(se/KN)/sqrt(sr/KN):0.0;
    double lossRelN=(fabs(lossF[Nsteps-1])>0)?fabs(lossT[Nsteps-1]-lossF[Nsteps-1])/fabs(lossF[Nsteps-1]):0.0;

    // worst loss-tracking gap over the whole trajectory (decisive metric).
    double worstLossRel=0; int worstStep=0;
    for(int s=0;s<Nsteps;s++){ double r=(fabs(lossF[s])>0)?fabs(lossT[s]-lossF[s])/fabs(lossF[s]):0.0;
        if(r>worstLossRel){worstLossRel=r; worstStep=s+1;} }

    printf("\n[SUMMARY] OP-23 %s D=%d T=%d B=%d Nsteps=%d\n",MODE_NAME,D,T,B,Nsteps);
    printf("[SUMMARY] TF32 self-byte-eq over WHOLE trajectory (run1 vs run2): W max|delta|=%.3e  loss max|delta|=%.3e  (==0: %s)\n",
           maxd, lossMaxd, (maxd==0.0 && lossMaxd==0.0)?"YES":"NO");
    printf("[SUMMARY] step-N weight relRMS(TF32 vs FP64) = %.6e   max|dW| = %.6e\n", relrmsN, wmax);
    printf("[SUMMARY] step-N loss-tracking  |dLoss|/|lossFP64| = %.6e\n", lossRelN);
    printf("[SUMMARY] WORST loss-tracking gap over trajectory = %.6e at step %d\n", worstLossRel, worstStep);
    printf("[RESULT] OP-23 %s D=%d B=%d Nsteps=%d  selfByteEqN=%s  relRMS_W_N=%.3e  lossTrackN=%.3e  worstLossTrack=%.3e\n",
           MODE_NAME,D,B,Nsteps, (maxd==0.0&&lossMaxd==0.0)?"Y":"N", relrmsN, lossRelN, worstLossRel);

    free(lossT);free(lossT2);free(lossF);free(wT);free(wT2);free(wTcmp);free(wF);
    return 0;
}
