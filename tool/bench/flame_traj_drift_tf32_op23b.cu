// flame_traj_drift_tf32_op23b.cu — HEXA-0POD OP-23b: TF32 vs FP64 LONG + HARSH trajectory drift.
//
// EXTENDS OP-23 (#3005). OP-23 validated the deterministic TF32 fast-mode as a REAL training
// fast-mode at N=100 on a small synthetic: the TF32 LOSS tracked the FP64 LOSS to ~1e-7/step
// (worst gap 2.5e-5, AT step 1 — does NOT grow), weight rel-RMS BOUNDED ~5e-7 (shrinks, not
// grows), self-byte-eq run-to-run over the whole trajectory. OP-23's HONEST CAVEAT:
//   "N=100 on a small synthetic config (loss = mean(G^2) proxy, no real corpus / LR-schedule);
//    the drift trend is flat-to-shrinking to step 100 with no late blow-up."
//
// THE OPEN QUESTION OP-23b decides: does the bounded loss-tracking HOLD at a LONGER + HARSHER
// horizon — N=500 (5x longer) UNDER an LR SCHEDULE (linear warmup + cosine decay, the standard
// transformer schedule, so step sizes VARY and could amplify drift), on a slightly HARDER
// synthetic (non-trivial structured target so the loss actually MOVES over 500 steps)?
//   (a) bounded to N=500 + survives the LR schedule  -> TF32 fast-mode validated at longer/harsher
//       horizon (strengthens OP-23), or
//   (b) a LATE blow-up appears (the OP-23 caveat realized) -> an honest bound on the safe horizon.
//
// HONEST FRAMING (g5), CARRIED FROM OP-23: NN training is CHAOTIC. Even FP64-vs-FP64 with a
// 1-ULP perturbation diverges in WEIGHTS over many steps (butterfly) while the LOSS stays
// equivalent. So the RIGHT metric is LOSS-TRACKING (training-equivalent), NOT weight byte-
// closeness (chaos GUARANTEES weights drift — that's why flame's identity is SELF-determinism,
// not cross-precision). We report BOTH: per-step weight rel-RMS / max|dW| (chaotic-but-bounded)
// AND the per-step loss of each lane (the decisive curve). Bounded loss-tracking = real fast-
// mode; a sustained loss divergence = the 1-step number was an illusion at this horizon.
//
// SYNTHETIC-PROXY CAVEAT (unchanged from OP-23): this is still a SYNTHETIC proxy. The real
// CLMConvMoE corpus trainer is GPU-BUILD-gated (-DHEXA_CUDA, see OP-24b/24c). This 0-pod core
// runs the aiden HARNESS at the longer/harsher settings; it does NOT replace the real-data run.
//
// WHAT CHANGED vs flame_traj_drift_tf32_op23.cu:
//   (1) N default 500 (was 100) — 5x longer horizon.
//   (2) LR SCHEDULE: lr(t) = base_lr * warmup_then_cosine(t), warmup = WARMUP steps linear ramp
//       0->1, then cosine decay 1->LR_FLOOR over the rest. The schedule is computed in DOUBLE on
//       host and passed identically to BOTH lanes each step (so the schedule itself is not a
//       source of cross-lane divergence — only the precision of the GEMM/AdamW math is).
//   (3) HARDER synthetic: a STRUCTURED target dGrad that depends on the row index with a
//       non-trivial sinusoidal pattern (was a flat pseudo-random fill), and a slightly larger
//       default D, so the loss has real structure to descend over 500 steps instead of flat noise.
//
// The step DAG is otherwise byte-identical to OP-23/OP-20 (fwd GEMM -> fused valley LN+gelu+copy
// -> transpose-elim bwd GEMM -> single-launch AdamW); only the cuBLAS compute type differs
// (TF32 = CUDA_R_32F / COMPUTE_32F_FAST_TF32 tensor-op; FP64 = CUDA_R_64F / COMPUTE_64F) and the
// AdamW LR is now per-step from the schedule.
//
// Build: nvcc -arch=sm_120 -O3 -o flame_traj_op23b flame_traj_drift_tf32_op23b.cu -lcublas
//        add -DPEDANTIC for the pedantic-cublas determinism variant.
// Run:   ./flame_traj_op23b D T B Nsteps [WARMUP]

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define ADAM_B1  0.9
#define ADAM_B2  0.999
#define ADAM_EPS 1e-8
#define ADAM_WD  0.01
#define BASE_LR  0.001
#define LR_FLOOR 0.05    // cosine decays base_lr down to 5% of base, never to 0 (standard)

static void ck(cudaError_t e, const char* what){
    if(e!=cudaSuccess){ printf("CUDA ERR %s: %s\n", what, cudaGetErrorString(e)); exit(2);} }

// LR SCHEDULE (computed in double, host side, identical to both lanes):
//   t in [1..Nsteps]. linear warmup over [1..WARMUP], then cosine decay 1->LR_FLOOR over the rest.
static double lr_at(int t, int Nsteps, int warmup){
    double base = BASE_LR;
    if(t <= warmup){
        return base * ((double)t / (double)warmup);   // linear ramp 0->base
    }
    // cosine decay from base (at t=warmup) down to base*LR_FLOOR (at t=Nsteps)
    double prog = (double)(t - warmup) / (double)(Nsteps - warmup);   // 0..1
    double cos_factor = 0.5 * (1.0 + cos(M_PI * prog));               // 1..0
    return base * (LR_FLOOR + (1.0 - LR_FLOOR) * cos_factor);
}

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

// AdamW with per-step LR passed from the host schedule (the OP-23b change).
template<class R>
__global__ void k_adamw(R* dW, R* Wf, R* Mm, R* Vv, long long n, int tstep, R lr){
    R bc1=(R)1.0-(R)pow((double)ADAM_B1,(double)tstep);
    R bc2=(R)1.0-(R)pow((double)ADAM_B2,(double)tstep);
    long long stride=(long long)blockDim.x*gridDim.x;
    for(long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride){
        R g=dW[i];
        R m=(R)ADAM_B1*Mm[i]+(R)(1.0-ADAM_B1)*g;
        R v=(R)ADAM_B2*Vv[i]+(R)(1.0-ADAM_B2)*g*g;
        Mm[i]=m; Vv[i]=v;
        R mh=m/bc1, vh=v/bc2, w=Wf[i];
        w=w-lr*(mh/(sqrt(vh)+(R)ADAM_EPS)+(R)ADAM_WD*w);
        Wf[i]=w;
    }
}

// deterministic scalar loss = mean(G^2) over post-valley activation, fixed-order block tree
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

template<class R> __global__ void fill_r(R* x, long long n, unsigned seed, double scale){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=(R)(((h&0xffff)/65535.0-0.5)*scale); }
}
// HARDER synthetic target: a STRUCTURED dGrad with a row-dependent sinusoidal pattern so the
// loss has real descent structure over 500 steps (was a flat pseudo-random fill in OP-23).
template<class R> __global__ void fill_struct(R* x, long long n, int N, unsigned seed, double scale){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n){
        long long row = i / N, col = i % N;
        double base = (((unsigned)(i*2654435761u)^seed)&0xffff)/65535.0 - 0.5;
        double structure = 0.5*sin(0.013*(double)row + 0.007*(double)col)
                         + 0.3*cos(0.0021*(double)(row*col));
        x[i]=(R)((0.4*base + 0.6*structure)*scale);
    }
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

// run ONE step with a per-step LR; ALSO returns this step's loss (mean(G^2)) via lossOut.
template<class R>
static void run_step(Lane<R>& L, R* A, R* Wf, R* H, R* G, R* dGrad, R* dGq, R* dW,
                     R* Mm, R* Vv, int M, int K, int N, long long KN, int eGrid, int tstep,
                     double* part, double* lossOut, int lblk, double lr){
    gemm<R>(L, H, A, Wf, M, K, N);
    k_valley<R><<<M,256>>>(H,G,dGrad,dGq,M,N);
    long long MN=(long long)M*N;
    k_loss_partial<R><<<lblk,256>>>(G, part, MN);
    k_loss_final<<<1,256>>>(part, lblk, lossOut, MN);
    gemm_op<R>(L, dW, A, dGq, K, M, N, CUBLAS_OP_T, K);
    k_adamw<R><<<eGrid,256>>>(dW,Wf,Mm,Vv,KN,tstep,(R)lr);
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
    fill_struct<R><<<gB(b.MN),256>>>(b.dGrad,b.MN,N,44,0.05);   // HARDER structured target
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

// run a full N-step TF32 trajectory into host arrays (loss per step + final W snapshot),
// using the LR schedule. lossArr must hold Nsteps doubles; wFinal must hold KN floats.
static void run_traj_tf32(Lane<float>& L, Buf<float>& b, int M,int K,int N,long long KN,
                          int eGrid,int Nsteps,int warmup,double* part,double* dLoss,int lblk,
                          double* lossArr, float* wFinal){
    reset_lane<float>(b);
    for(int s=0;s<Nsteps;s++){
        double lr = lr_at(s+1, Nsteps, warmup);
        run_step<float>(L,b.A,b.Wf,b.H,b.G,b.dGrad,b.dGq,b.dW,b.Mm,b.Vv,M,K,N,KN,eGrid,s+1,part,dLoss,lblk,lr);
        ck(cudaMemcpy(&lossArr[s],dLoss,sizeof(double),cudaMemcpyDeviceToHost),"cp-loss-tf32");
    }
    ck(cudaDeviceSynchronize(),"traj-tf32");
    ck(cudaMemcpy(wFinal,b.Wf,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp-wfin-tf32");
}

int main(int argc,char**argv){
    int D=(argc>1)?atoi(argv[1]):1024;       // OP-23b default D bumped 768->1024 (harder)
    int T=(argc>2)?atoi(argv[2]):256;
    int B=(argc>3)?atoi(argv[3]):1;
    int Nsteps=(argc>4)?atoi(argv[4]):500;   // OP-23b default 100->500 (5x longer)
    int warmup=(argc>5)?atoi(argv[5]):50;    // OP-23b LR warmup steps
    if(warmup<1) warmup=1; if(warmup>=Nsteps) warmup=Nsteps/2;
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
    printf("[CFG] OP-23b %s  GPU=%s cc=%d.%d  D=%d T=%d B=%d -> M=%d K=%d N=%d Nsteps=%d warmup=%d\n",
           MODE_NAME,p.name,p.major,p.minor,D,T,B,M,K,N,Nsteps,warmup);
    printf("[CFG] LR SCHEDULE: linear warmup %d steps (0->%.4g) then cosine decay to %.4g*base over remaining %d\n",
           warmup, BASE_LR, LR_FLOOR, Nsteps-warmup);
    // emit a few schedule sample points so the schedule is auditable in the log.
    printf("[CFG] lr samples: t=1:%.6e  t=%d(peak):%.6e  t=%d:%.6e  t=%d:%.6e  t=%d:%.6e\n",
           lr_at(1,Nsteps,warmup), warmup, lr_at(warmup,Nsteps,warmup),
           Nsteps/4, lr_at(Nsteps/4,Nsteps,warmup), Nsteps/2, lr_at(Nsteps/2,Nsteps,warmup),
           Nsteps, lr_at(Nsteps,Nsteps,warmup));

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
        printf("[RESULT] OP-23b %s B=%d D=%d OOM\n",MODE_NAME,B,D); return 3; }
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
    float*  wTcmp =(float*) malloc(KN*sizeof(float));
    double* wF    =(double*)malloc(KN*sizeof(double));

    // ---- TF32 trajectory run #1 (records loss/step + final W) ----
    run_traj_tf32(Lt,bt,M,K,N,KN,eGrid,Nsteps,warmup,partT,dLossT,lblk,lossT,wT);
    // ---- TF32 trajectory run #2 (self-determinism over the WHOLE 500-step trajectory) ----
    run_traj_tf32(Lt,bt,M,K,N,KN,eGrid,Nsteps,warmup,partT,dLossT,lblk,lossT2,wT2);

    // self-byte-eq at step N: max|delta(W')| between the two TF32 trajectories.
    double maxd=0; for(long long i=0;i<KN;i++){ double d=fabs((double)wT[i]-(double)wT2[i]); if(d>maxd)maxd=d; }
    double lossMaxd=0; for(int s=0;s<Nsteps;s++){ double d=fabs(lossT[s]-lossT2[s]); if(d>lossMaxd)lossMaxd=d; }

    // ---- lockstep FP64-vs-TF32 run for per-step weight rel-RMS + loss tracking ----
    reset_lane<float>(bt); reset_lane<double>(bf);
    int sampleEvery = (Nsteps<=20)?1:(Nsteps/50);   // ~50 sampled rows over 500 steps (~every 10)
    if(sampleEvery<1) sampleEvery=1;
    printf("[TRAJ] step      lr            lossTF32        lossFP64        |dLoss|/|lossFP64|   relRMS(W_TF32 vs W_FP64)   maxAbs(W_TF32-W_FP64)\n");
    for(int s=0;s<Nsteps;s++){
        double lr = lr_at(s+1, Nsteps, warmup);
        run_step<float >(Lt,bt.A,bt.Wf,bt.H,bt.G,bt.dGrad,bt.dGq,bt.dW,bt.Mm,bt.Vv,M,K,N,KN,eGrid,s+1,partT,dLossT,lblk,lr);
        run_step<double>(Lf,bf.A,bf.Wf,bf.H,bf.G,bf.dGrad,bf.dGq,bf.dW,bf.Mm,bf.Vv,M,K,N,KN,eGrid,s+1,partF,dLossF,lblk,lr);
        double lt,lf; ck(cudaMemcpy(&lt,dLossT,sizeof(double),cudaMemcpyDeviceToHost),"lt");
        ck(cudaMemcpy(&lf,dLossF,sizeof(double),cudaMemcpyDeviceToHost),"lf");
        lossT[s]=lt; lossF[s]=lf;
        bool isSample = (s%sampleEvery==0) || (s==Nsteps-1) || (s+1==warmup);
        if(isSample){
            ck(cudaMemcpy(wTcmp,bt.Wf,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp-wt-lock");
            ck(cudaMemcpy(wF,bf.Wf,KN*sizeof(double),cudaMemcpyDeviceToHost),"cp-wf-lock");
            double se=0,sr=0,wmax=0;
            for(long long i=0;i<KN;i++){ double a=(double)wTcmp[i], b=wF[i];
                se+=(a-b)*(a-b); sr+=b*b; double ad=fabs(a-b); if(ad>wmax)wmax=ad; }
            double relrms=(sr>0)?sqrt(se/KN)/sqrt(sr/KN):0.0;
            double lossRel=(fabs(lf)>0)?fabs(lt-lf)/fabs(lf):0.0;
            printf("[TRAJ] %5d   %.6e   %.8e   %.8e   %.6e        %.6e             %.6e\n",
                   s+1, lr, lt, lf, lossRel, relrms, wmax);
        }
    }

    // final-step summary numbers.
    ck(cudaMemcpy(wTcmp,bt.Wf,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp-wt-fin");
    ck(cudaMemcpy(wF,bf.Wf,KN*sizeof(double),cudaMemcpyDeviceToHost),"cp-wf-fin");
    double se=0,sr=0,wmax=0;
    for(long long i=0;i<KN;i++){ double a=(double)wTcmp[i], b=wF[i];
        se+=(a-b)*(a-b); sr+=b*b; double ad=fabs(a-b); if(ad>wmax)wmax=ad; }
    double relrmsN=(sr>0)?sqrt(se/KN)/sqrt(sr/KN):0.0;
    double lossRelN=(fabs(lossF[Nsteps-1])>0)?fabs(lossT[Nsteps-1]-lossF[Nsteps-1])/fabs(lossF[Nsteps-1]):0.0;

    // worst loss-tracking gap over the whole trajectory + WHERE it occurs (early vs late).
    double worstLossRel=0; int worstStep=0;
    for(int s=0;s<Nsteps;s++){ double r=(fabs(lossF[s])>0)?fabs(lossT[s]-lossF[s])/fabs(lossF[s]):0.0;
        if(r>worstLossRel){worstLossRel=r; worstStep=s+1;} }
    // late-half worst (steps > Nsteps/2): is there a LATE blow-up?
    double lateWorst=0; int lateStep=0;
    for(int s=Nsteps/2;s<Nsteps;s++){ double r=(fabs(lossF[s])>0)?fabs(lossT[s]-lossF[s])/fabs(lossF[s]):0.0;
        if(r>lateWorst){lateWorst=r; lateStep=s+1;} }
    // warmup-peak-window worst (steps near the high-LR warmup peak): does the schedule amplify?
    int wlo=(warmup>5)?warmup-5:1, whi=(warmup+5<Nsteps)?warmup+5:Nsteps;
    double peakWorst=0; int peakStep=0;
    for(int s=wlo-1;s<whi;s++){ double r=(fabs(lossF[s])>0)?fabs(lossT[s]-lossF[s])/fabs(lossF[s]):0.0;
        if(r>peakWorst){peakWorst=r; peakStep=s+1;} }

    printf("\n[SUMMARY] OP-23b %s D=%d T=%d B=%d Nsteps=%d warmup=%d\n",MODE_NAME,D,T,B,Nsteps,warmup);
    printf("[SUMMARY] TF32 self-byte-eq over WHOLE 500-step trajectory (run1 vs run2): W max|delta|=%.3e  loss max|delta|=%.3e  (==0: %s)\n",
           maxd, lossMaxd, (maxd==0.0 && lossMaxd==0.0)?"YES":"NO");
    printf("[SUMMARY] step-N weight relRMS(TF32 vs FP64) = %.6e   max|dW| = %.6e\n", relrmsN, wmax);
    printf("[SUMMARY] step-N loss-tracking  |dLoss|/|lossFP64| = %.6e\n", lossRelN);
    printf("[SUMMARY] WORST loss-tracking gap over trajectory = %.6e at step %d  (%s)\n",
           worstLossRel, worstStep, (worstStep <= Nsteps/2)?"EARLY half — bounded, no late blow-up":"LATE half — investigate");
    printf("[SUMMARY] LATE-half (steps>%d) worst loss-track = %.6e at step %d\n", Nsteps/2, lateWorst, lateStep);
    printf("[SUMMARY] WARMUP-PEAK window [%d..%d] worst loss-track = %.6e at step %d (LR-schedule amplify test)\n",
           wlo, whi, peakWorst, peakStep);
    printf("[RESULT] OP-23b %s D=%d B=%d Nsteps=%d warmup=%d  selfByteEqN=%s  relRMS_W_N=%.3e  lossTrackN=%.3e  worstLossTrack=%.3e@%d  lateWorst=%.3e@%d  peakWorst=%.3e@%d\n",
           MODE_NAME,D,B,Nsteps,warmup, (maxd==0.0&&lossMaxd==0.0)?"Y":"N",
           relrmsN, lossRelN, worstLossRel, worstStep, lateWorst, lateStep, peakWorst, peakStep);

    free(lossT);free(lossT2);free(lossF);free(wT);free(wT2);free(wTcmp);free(wF);
    return 0;
}
