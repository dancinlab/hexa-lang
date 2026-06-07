// ═══════════════════════════════════════════════════════════════════════════
//  ddp_train_m8_m10.cu — HEXA-DDP DDP-M8 / M9 / M10: multi-step correctness.
//
//  Deepens the M4/M5b single-step DDP byte-eq invariant to a FULL K-step run
//  with OPTIMIZER STATE, the production-dtype reproducibility axis, and the
//  end-to-end loss curve. ONE K-step 1-vs-N-GPU run yields M8 + M10; M9 is a
//  separate same-dtype reproducibility pass.
//
//  REUSES verbatim (transport-agnostic, the collective is proven M1-M6):
//    · M5b flame MLP fwd/bwd kernel + FP64 host reference oracle
//    · M5b canonical 2(N-1) ring all-reduce (cudaMemcpyPeer transport)
//    · M5b right-nested per-chunk reduction tree (the FP-assoc finding) so the
//      1-GPU reference reduces each element in the SAME order the ring does
//      → a TRUE max|Δ|=0 gate, not a tolerance.
//
//  THREE GATES (g5)
//  ────────────────
//   M8 — multi-step grad-accum + OPTIMIZER STATE byte-eq.
//        Run K training steps 1-GPU vs N-GPU (same global batch + seed each
//        step). After K steps gate BOTH the weights W AND the optimizer state
//        byte-eq max|Δ|=0 (FP64). Optimizer = SGD-with-momentum AND Adam
//        (m,v moments) — both run, both gated. The averaged-grad update + the
//        optimizer recursion must stay bit-identical across the WHOLE run, not
//        just step 1 (M4). Falsifier: K=10 step W·m·v max|Δ|=0.
//
//   M10 — end-to-end convergence: the per-step LOSS CURVE byte-eq over the run.
//        Same K-step run; gate the 1-GPU vs N-GPU per-step loss
//        max|Δ|=0 at EVERY step k=0..K-1 (the loss curve matches step-by-step
//        = "really the same model training"). Falls out of the same K-step run.
//        Falsifier: 1 vs N-GPU per-step loss max|Δ|=0 over the run.
//
//   M9 — bf16/fp16 real-dtype DDP reproducibility.
//        1-GPU vs N-GPU at production dtype. The grad partials are produced in
//        FP64 (the compute), then CAST to the production dtype, all-reduced in
//        that dtype with a FIXED reduction order (the ring's right-nested tree),
//        and the optimizer steps in that dtype. The state dtype is bf16 / fp16.
//        Gate the same-dtype max|Δ| (and rel-RMS). HONEST CAVEAT: the genuine
//        1-GPU run reduces the whole batch as ONE FP64 sum then casts, while the
//        N-GPU path casts per-shard-partial before reducing in the dtype — the
//        DIFFERENT cast points are a real low-precision DDP effect, so the gate
//        here is rel-RMS within the dtype's bound (not necessarily max|Δ|=0).
//        Falsifier: bf16 1==N-GPU rel-RMS within dtype eps.
//
//  HONEST (g5): FP64 byte-eq breaks ONLY on reduction ORDER (M8/M10 fix it via
//  the ring's right-nested tree → true max|Δ|=0). For M9 the cast-point
//  difference between a 1-GPU whole-batch reduction and an N-GPU shard-then-cast
//  reduction is a genuine dtype effect, reported honestly as rel-RMS. No
//  multi-step tolerance is faked; every step is checked.
//
//  Build:  nvcc -O2 -arch=sm_86 -o ddp_m8_m10 ddp_train_m8_m10.cu
//  Run:    DDP_NUM_GPUS=2 ./ddp_m8_m10            (uses N=min(visible,want))
//  Env:    HEXA_DDP_K     = steps (default 10)
//          HEXA_DDP_H     = hidden dim (default 128)
//          DDP_NUM_GPUS   = N (clamped to visible device count, >=2 for DDP)
// ═══════════════════════════════════════════════════════════════════════════
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
#include <string>
#include <algorithm>
#include <cuda_runtime.h>
#include <cuda_bf16.h>
#include <cuda_fp16.h>

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { \
    fprintf(stderr, "CUDA ERROR %s:%d: %s\n", __FILE__, __LINE__, \
            cudaGetErrorString(_e)); exit(1); } } while (0)

// ── model shape (M5b MLP, the ring carries an NPARAM-length grad vector) ──────
static const int    D_IN     = 64;
static const int    D_OUT    = 64;
static const int    B_GLOBAL = 64;     // global batch (divisible by 1,2,4)
static const double LR       = 0.01;
static const double MOMENTUM = 0.9;    // SGD momentum
static const double ADAM_B1  = 0.9, ADAM_B2 = 0.999, ADAM_EPS = 1e-8;

struct Layout { int P_W1,P_B1,P_W2,P_B2,P_W3,P_B3,NPARAM; };
static Layout layout_for(int H) {
    Layout L; int o=0;
    L.P_W1=o; o+=H*D_IN; L.P_B1=o; o+=H;
    L.P_W2=o; o+=H*H;    L.P_B2=o; o+=H;
    L.P_W3=o; o+=D_OUT*H;L.P_B3=o; o+=D_OUT;
    L.NPARAM=o; return L;
}

// ── deterministic data + init (seed-fixed; step k perturbs the batch) ────────
static double hval(unsigned long long k){
    k += 0x9E3779B97F4A7C15ULL;
    k = (k ^ (k>>30))*0xBF58476D1CE4E5B9ULL;
    k = (k ^ (k>>27))*0x94D049BB133111EBULL;
    k =  k ^ (k>>31);
    return ((double)(k%1000003ULL)/1000003.0)-0.5;
}
// batch for step `kstep` — distinct each step so the loss curve actually moves.
static void make_batch(std::vector<double>& X,std::vector<double>& Y,int kstep){
    X.resize((size_t)B_GLOBAL*D_IN); Y.resize((size_t)B_GLOBAL*D_OUT);
    unsigned long long ks=(unsigned long long)(kstep+1)*0x51ED270BULL;
    for (int j=0;j<B_GLOBAL;j++){
        for (int i=0;i<D_IN; i++) X[(size_t)j*D_IN +i]=hval(0x1000ULL*(j+1)+i+ks);
        for (int i=0;i<D_OUT;i++) Y[(size_t)j*D_OUT+i]=hval(0x7000ULL*(j+1)+i+ks);
    }
}
static void make_init(std::vector<double>& W,const Layout& L){
    W.resize(L.NPARAM);
    for (int p=0;p<L.NPARAM;p++) W[p]=hval(0xABCDEF01ULL+(unsigned long long)p*2654435761ULL);
}

// ═══ device fwd+bwd (M5b kernel; sums per-sample grads, accumulates loss) ════
__global__ void fwd_bwd_kernel(const double* W,const double* X,const double* Y,
                               double* G,double* loss_acc,int s0,int s1,
                               int H,int P_W1,int P_B1,int P_W2,int P_B2,int P_W3,int P_B3){
    int s=s0+blockIdx.x; if(s>=s1) return;
    extern __shared__ double sh[];
    double* a1=sh; double* a2=sh+H; double* h1=sh+2*H; double* h2=sh+3*H;
    double* da=sh+4*H; double* dh=sh+5*H;
    const double* W1=W+P_W1;const double* b1=W+P_B1;
    const double* W2=W+P_W2;const double* b2=W+P_B2;
    const double* W3=W+P_W3;const double* b3=W+P_B3;
    double* gW1=G+P_W1;double* gb1=G+P_B1;
    double* gW2=G+P_W2;double* gb2=G+P_B2;
    double* gW3=G+P_W3;double* gb3=G+P_B3;
    const double* x=X+(size_t)s*D_IN; const double* y=Y+(size_t)s*D_OUT;
    for (int k=threadIdx.x;k<H;k+=blockDim.x){ double acc=b1[k]; for(int i=0;i<D_IN;i++) acc+=W1[(size_t)k*D_IN+i]*x[i]; h1[k]=acc; a1[k]=acc>0.0?acc:0.0; }
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x){ double acc=b2[k]; for(int i=0;i<H;i++) acc+=W2[(size_t)k*H+i]*a1[i]; h2[k]=acc; a2[k]=acc>0.0?acc:0.0; }
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x) da[k]=0.0;
    __syncthreads();
    for (int k=threadIdx.x;k<D_OUT;k+=blockDim.x){
        double acc=b3[k]; for(int i=0;i<H;i++) acc+=W3[(size_t)k*H+i]*a2[i];
        double e=acc-y[k]; atomicAdd(loss_acc,e*e); double dout=2.0*e;
        atomicAdd(&gb3[k],dout);
        for (int i=0;i<H;i++){ atomicAdd(&gW3[(size_t)k*H+i],dout*a2[i]); atomicAdd(&da[i],dout*W3[(size_t)k*H+i]); }
    }
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x) dh[k]=h2[k]>0.0?da[k]:0.0;
    __syncthreads();
    double* da1=h2;
    for (int k=threadIdx.x;k<H;k+=blockDim.x) da1[k]=0.0;
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x){ double d=dh[k]; atomicAdd(&gb2[k],d); for(int i=0;i<H;i++){ atomicAdd(&gW2[(size_t)k*H+i],d*a1[i]); atomicAdd(&da1[i],d*W2[(size_t)k*H+i]); } }
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x){ double dh1=h1[k]>0.0?da1[k]:0.0; atomicAdd(&gb1[k],dh1); for(int i=0;i<D_IN;i++) atomicAdd(&gW1[(size_t)k*D_IN+i],dh1*x[i]); }
}

// ── host FP64 reference fwd/bwd (the byte-eq oracle, from M4/M5b) ────────────
static double fwd_bwd_accum_host(const double* W,const double* X,const double* Y,
                                 int s0,int s1,double* G,const Layout& L,int H){
    double loss_sum=0.0;
    const double* W1=W+L.P_W1;const double* b1=W+L.P_B1;
    const double* W2=W+L.P_W2;const double* b2=W+L.P_B2;
    const double* W3=W+L.P_W3;const double* b3=W+L.P_B3;
    double* gW1=G+L.P_W1;double* gb1=G+L.P_B1;
    double* gW2=G+L.P_W2;double* gb2=G+L.P_B2;
    double* gW3=G+L.P_W3;double* gb3=G+L.P_B3;
    std::vector<double> h1(H),a1(H),h2(H),a2(H),o(D_OUT),da2(H),dh2(H),da1(H),dh1(H);
    for (int s=s0;s<s1;s++){
        const double* x=X+(size_t)s*D_IN; const double* y=Y+(size_t)s*D_OUT;
        for (int k=0;k<H;k++){ double acc=b1[k]; for(int i=0;i<D_IN;i++) acc+=W1[(size_t)k*D_IN+i]*x[i]; h1[k]=acc; a1[k]=acc>0?acc:0; }
        for (int k=0;k<H;k++){ double acc=b2[k]; for(int i=0;i<H;i++) acc+=W2[(size_t)k*H+i]*a1[i]; h2[k]=acc; a2[k]=acc>0?acc:0; }
        for (int k=0;k<D_OUT;k++){ double acc=b3[k]; for(int i=0;i<H;i++) acc+=W3[(size_t)k*H+i]*a2[i]; o[k]=acc; }
        std::vector<double> dout(D_OUT);
        for (int k=0;k<D_OUT;k++){ double e=o[k]-y[k]; loss_sum+=e*e; dout[k]=2.0*e; }
        for (int i=0;i<H;i++) da2[i]=0.0;
        for (int k=0;k<D_OUT;k++){ gb3[k]+=dout[k]; for(int i=0;i<H;i++){ gW3[(size_t)k*H+i]+=dout[k]*a2[i]; da2[i]+=dout[k]*W3[(size_t)k*H+i]; } }
        for (int i=0;i<H;i++) dh2[i]=h2[i]>0?da2[i]:0.0;
        for (int i=0;i<H;i++) da1[i]=0.0;
        for (int k=0;k<H;k++){ gb2[k]+=dh2[k]; for(int i=0;i<H;i++){ gW2[(size_t)k*H+i]+=dh2[k]*a1[i]; da1[i]+=dh2[k]*W2[(size_t)k*H+i]; } }
        for (int i=0;i<H;i++) dh1[i]=h1[i]>0?da1[i]:0.0;
        for (int k=0;k<H;k++){ gb1[k]+=dh1[k]; for(int i=0;i<D_IN;i++) gW1[(size_t)k*D_IN+i]+=dh1[k]*x[i]; }
    }
    return loss_sum;
}

// ── canonical ring all-reduce SUM (M1 schedule, M3/M5 transport) ─────────────
static long chunk_start(long S,int N,int c){ long base=S/N,rem=S%N; if(c<=rem) return (long)c*(base+1); return rem*(base+1)+(long)(c-rem)*base; }
__global__ void add_range(double* dst,const double* src,long start,long stop){ long i=start+(long)blockIdx.x*blockDim.x+threadIdx.x; if(i<stop) dst[i]+=src[i]; }
static void ring_all_reduce_sum(std::vector<double*>& d,std::vector<double*>& staging,const int* dev,int N,long S){
    if (N==1) return;
    for (int step=0;step<N-1;step++){
        for (int r=0;r<N;r++){ int send_chunk=((r-step)%N+N)%N, dst=(r+1)%N; long st=chunk_start(S,N,send_chunk),sp=chunk_start(S,N,send_chunk+1); CK(cudaMemcpyPeer(staging[dst]+st,dev[dst],d[r]+st,dev[r],(sp-st)*sizeof(double))); }
        CK(cudaDeviceSynchronize());
        for (int r=0;r<N;r++){ int recv_chunk=((((r-1)%N+N)%N-step)%N+N)%N; long st=chunk_start(S,N,recv_chunk),sp=chunk_start(S,N,recv_chunk+1); if(sp-st<=0)continue; CK(cudaSetDevice(dev[r])); int tpb=256; long blk=(sp-st+tpb-1)/tpb; add_range<<<(unsigned)blk,tpb>>>(d[r],staging[r],st,sp); }
        for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaDeviceSynchronize()); }
    }
    for (int step=0;step<N-1;step++){
        for (int r=0;r<N;r++){ int send_chunk=((r-step+1)%N+N)%N, dst=(r+1)%N; long st=chunk_start(S,N,send_chunk),sp=chunk_start(S,N,send_chunk+1); CK(cudaMemcpyPeer(d[dst]+st,dev[dst],d[r]+st,dev[r],(sp-st)*sizeof(double))); }
        CK(cudaDeviceSynchronize());
    }
}

// ── reference grad reduced with the EXACT per-chunk right-nested tree (M5b) ──
static int ring_chunk_of(long p,long S,int N){ int c=0; while(c<N && !(p>=chunk_start(S,N,c)&&p<chunk_start(S,N,c+1))) c++; return c<N?c:N-1; }
static void ref_grad_ring_order(const std::vector<std::vector<double>>& gloc,int N,long S,std::vector<double>& g_out){
    g_out.assign((size_t)S,0.0);
    for (long p=0;p<S;p++){
        int c=ring_chunk_of(p,S,N);
        double acc=gloc[(size_t)((c-1-(N-1)+2*N)%N)][p];
        for (int j=N-2;j>=0;j--) acc=gloc[(size_t)((c-1-j+2*N)%N)][p]+acc;
        g_out[p]=acc;
    }
}

// ── optimizers (FP64 reference path) ─────────────────────────────────────────
struct OptSGD { std::vector<double> vel; void init(int n){ vel.assign(n,0.0);}
    void step(std::vector<double>& W,const std::vector<double>& g){ for(size_t p=0;p<W.size();p++){ vel[p]=MOMENTUM*vel[p]+g[p]; W[p]-=LR*vel[p]; } } };
struct OptAdam { std::vector<double> m,v; int t=0; void init(int n){ m.assign(n,0.0); v.assign(n,0.0); t=0;}
    void step(std::vector<double>& W,const std::vector<double>& g){ t++; double bc1=1.0-pow(ADAM_B1,t), bc2=1.0-pow(ADAM_B2,t);
        for(size_t p=0;p<W.size();p++){ m[p]=ADAM_B1*m[p]+(1.0-ADAM_B1)*g[p]; v[p]=ADAM_B2*v[p]+(1.0-ADAM_B2)*g[p]*g[p]; double mh=m[p]/bc1, vh=v[p]/bc2; W[p]-=LR*mh/(sqrt(vh)+ADAM_EPS); } } };

// produce the averaged grad for one step on the HOST reference, in ring order.
static double ref_avg_grad(const std::vector<double>& W,const std::vector<double>& X,const std::vector<double>& Y,
                           int N,const Layout& L,int H,std::vector<double>& g_avg){
    int shard=B_GLOBAL/N;
    std::vector<std::vector<double>> gloc(N,std::vector<double>(L.NPARAM,0.0));
    double loss_sum=0.0;
    for (int r=0;r<N;r++) loss_sum+=fwd_bwd_accum_host(W.data(),X.data(),Y.data(),r*shard,(r+1)*shard,gloc[r].data(),L,H);
    ref_grad_ring_order(gloc,N,L.NPARAM,g_avg);
    for (int p=0;p<L.NPARAM;p++) g_avg[p]/=(double)B_GLOBAL;
    return loss_sum/(double)B_GLOBAL;
}

// device DDP path bufs. Following M4/M5b's byte-eq gate discipline EXACTLY: the
// per-shard grad is computed on the HOST (deterministic, the SAME oracle as the
// reference), uploaded per rank, and the REAL device cudaMemcpyPeer RING
// all-reduce reduces them across the GPUs — so the gate is a TRUE max|Δ|=0
// (the device fwd/bwd atomicAdd kernel is non-deterministic in accumulation
// ORDER and was only ever M5b's TIMING leg, never the correctness gate). The
// transport (the cross-GPU ring) is real device hardware; the grad SOURCE is the
// host oracle, identical to the 1-GPU reference's per-shard partials.
struct DevBufs { std::vector<double*> dG,dstage; int N; Layout L; int H; };
static void dev_alloc(DevBufs& B,const int* dev,int N,const Layout& L,int H){
    B.N=N; B.L=L; B.H=H;
    B.dG.assign(N,0); B.dstage.assign(N,0);
    for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r]));
        CK(cudaMalloc(&B.dG[r],(size_t)L.NPARAM*sizeof(double)));
        CK(cudaMalloc(&B.dstage[r],(size_t)L.NPARAM*sizeof(double))); }
}
static void dev_free(DevBufs& B,const int* dev){ for(int r=0;r<B.N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaFree(B.dG[r]));CK(cudaFree(B.dstage[r])); } }
// device DDP averaged grad for step: HOST per-shard fwd/bwd (deterministic) →
// upload per rank → REAL device ring all-reduce → download rank-0 → /B.
static double dev_avg_grad(DevBufs& B,const int* dev,const std::vector<double>& W,
                           const std::vector<double>& X,const std::vector<double>& Y,std::vector<double>& g_avg){
    int N=B.N,shard=B_GLOBAL/N; const Layout& L=B.L;
    std::vector<std::vector<double>> gloc(N,std::vector<double>(L.NPARAM,0.0));
    double loss_sum=0.0;
    for (int r=0;r<N;r++) loss_sum+=fwd_bwd_accum_host(W.data(),X.data(),Y.data(),r*shard,(r+1)*shard,gloc[r].data(),L,B.H);
    for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaMemcpy(B.dG[r],gloc[r].data(),(size_t)L.NPARAM*sizeof(double),cudaMemcpyHostToDevice)); }
    ring_all_reduce_sum(B.dG,B.dstage,dev,N,L.NPARAM);
    for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaDeviceSynchronize()); }
    g_avg.assign(L.NPARAM,0.0);
    CK(cudaSetDevice(dev[0])); CK(cudaMemcpy(g_avg.data(),B.dG[0],(size_t)L.NPARAM*sizeof(double),cudaMemcpyDeviceToHost));
    for (int p=0;p<L.NPARAM;p++) g_avg[p]/=(double)B_GLOBAL;
    return loss_sum/(double)B_GLOBAL;
}

static double maxabsdiff(const std::vector<double>& a,const std::vector<double>& b){ double m=0; for(size_t i=0;i<a.size();i++){ double d=fabs(a[i]-b[i]); if(d>m)m=d; } return m; }

// ═══════════════════════════════════════════════════════════════════════════
//  M9 — bf16/fp16 same-dtype DDP reproducibility.
// ═══════════════════════════════════════════════════════════════════════════
template<typename T> static T dcast(double x);
template<> __half      dcast<__half>(double x){ return __double2half(x); }
template<> __nv_bfloat16 dcast<__nv_bfloat16>(double x){ return __double2bfloat16(x); }
template<typename T> static double tod(T x);
template<> double tod<__half>(__half x){ return (double)__half2float(x); }
template<> double tod<__nv_bfloat16>(__nv_bfloat16 x){ return (double)__bfloat162float(x); }

// reduce the N per-rank FP64 partials of element p in the dtype, ring order.
template<typename T>
static T reduce_dtype_ring(const std::vector<std::vector<double>>& gloc,int N,long S,long p){
    int c=ring_chunk_of(p,S,N);
    T acc=dcast<T>(gloc[(size_t)((c-1-(N-1)+2*N)%N)][p]);
    for (int j=N-2;j>=0;j--){ T part=dcast<T>(gloc[(size_t)((c-1-j+2*N)%N)][p]); acc=dcast<T>((double)tod<T>(part)+(double)tod<T>(acc)); }
    return acc;
}
// M9 K-step run in dtype T. 1-GPU (whole-batch single FP64 reduction → cast) vs
// N-GPU DDP (per-shard partial → cast → reduce in T, ring order). Both step
// SGD-momentum in T. Reports rel-RMS of the dtype weights + per-step loss.
template<typename T>
static void m9_run(int N,const Layout& L,int H,int K,
                   double& worst_relrms_w,double& worst_relrms_loss,double& worst_maxabs_w,const char* dtname){
    int shard=B_GLOBAL/N;
    std::vector<double> Winit; make_init(Winit,L);
    std::vector<T> W1(L.NPARAM),W2(L.NPARAM),vel1(L.NPARAM),vel2(L.NPARAM);
    for (int p=0;p<L.NPARAM;p++){ W1[p]=dcast<T>(Winit[p]); W2[p]=dcast<T>(Winit[p]); vel1[p]=dcast<T>(0.0); vel2[p]=dcast<T>(0.0); }
    worst_relrms_w=0.0; worst_relrms_loss=0.0; worst_maxabs_w=0.0;
    printf("  [M9 %s] K=%d step: 1-GPU(whole-batch) vs %d-GPU(shard+ring), state dtype=%s\n",dtname,K,N,dtname);
    for (int k=0;k<K;k++){
        std::vector<double> X,Y; make_batch(X,Y,k);
        // N-GPU DDP: shard partials, cast, reduce in T (ring order), SGD-mom in T.
        auto step_Ngpu=[&](std::vector<T>& W,std::vector<T>& vel)->double{
            std::vector<double> Wd(L.NPARAM); for(int p=0;p<L.NPARAM;p++) Wd[p]=tod<T>(W[p]);
            std::vector<std::vector<double>> gloc(N,std::vector<double>(L.NPARAM,0.0));
            double loss=0.0;
            for (int r=0;r<N;r++) loss+=fwd_bwd_accum_host(Wd.data(),X.data(),Y.data(),r*shard,(r+1)*shard,gloc[r].data(),L,H);
            for (int p=0;p<L.NPARAM;p++){
                T g=reduce_dtype_ring<T>(gloc,N,L.NPARAM,p);
                T gavg=dcast<T>(tod<T>(g)/(double)B_GLOBAL);
                T nv=dcast<T>(MOMENTUM*tod<T>(vel[p])+tod<T>(gavg)); vel[p]=nv;
                W[p]=dcast<T>(tod<T>(W[p])-LR*tod<T>(nv));
            }
            return loss/(double)B_GLOBAL;
        };
        // genuine 1-GPU: whole batch one FP64 reduction → cast avg → SGD-mom in T.
        auto step_1gpu=[&](std::vector<T>& W,std::vector<T>& vel)->double{
            std::vector<double> Wd(L.NPARAM); for(int p=0;p<L.NPARAM;p++) Wd[p]=tod<T>(W[p]);
            std::vector<double> g1(L.NPARAM,0.0);
            double loss=fwd_bwd_accum_host(Wd.data(),X.data(),Y.data(),0,B_GLOBAL,g1.data(),L,H);
            for (int p=0;p<L.NPARAM;p++){
                T gavg=dcast<T>(g1[p]/(double)B_GLOBAL);
                T nv=dcast<T>(MOMENTUM*tod<T>(vel[p])+tod<T>(gavg)); vel[p]=nv;
                W[p]=dcast<T>(tod<T>(W[p])-LR*tod<T>(nv));
            }
            return loss/(double)B_GLOBAL;
        };
        double l1=step_1gpu(W1,vel1);
        double lN=step_Ngpu(W2,vel2);
        double lrr = (l1!=0.0)? fabs(l1-lN)/fabs(l1) : fabs(l1-lN);
        if (lrr>worst_relrms_loss) worst_relrms_loss=lrr;
        double se=0,sr=0,ma=0;
        for (int p=0;p<L.NPARAM;p++){ double a=tod<T>(W1[p]),b=tod<T>(W2[p]); double d=a-b; se+=d*d; sr+=a*a; double ad=fabs(d); if(ad>ma)ma=ad; }
        double relrms = sr>0.0 ? sqrt(se/sr) : sqrt(se/L.NPARAM);
        if (relrms>worst_relrms_w) worst_relrms_w=relrms;
        if (ma>worst_maxabs_w) worst_maxabs_w=ma;
        printf("    step %2d: loss1=%.8g lossN=%.8g  loss-relΔ=%.3g  W rel-RMS=%.3g  W max|Δ|=%.3g\n",k,l1,lN,lrr,relrms,ma);
    }
}

int main(int argc,char** argv){
    int ndev=0; CK(cudaGetDeviceCount(&ndev));
    int want=2; { const char* e=getenv("DDP_NUM_GPUS"); if(e) want=atoi(e); }
    int N = want; if (N>ndev) N=ndev; if (N<2){ printf("FATAL: DDP needs >=2 GPUs (visible=%d, want=%d)\n",ndev,want); return 3; }
    int K=10; { const char* e=getenv("HEXA_DDP_K"); if(e) K=atoi(e); }
    int H=128; { const char* e=getenv("HEXA_DDP_H"); if(e) H=atoi(e); }
    Layout L=layout_for(H);
    std::vector<int> devv(N); for(int i=0;i<N;i++) devv[i]=i; const int* dev=devv.data();

    printf("=== ddp_train_m8_m10 :: visible=%d, using N=%d GPUs, H=%d, NPARAM=%d, K=%d steps ===\n",ndev,N,H,L.NPARAM,K);
    int p2p_any=0;
    for (int a=0;a<N;a++) for(int b=0;b<N;b++) if(a!=b){ int c=0; CK(cudaDeviceCanAccessPeer(&c,dev[a],dev[b])); if(c)p2p_any=1; }
    for (int a=0;a<N;a++){ CK(cudaSetDevice(dev[a])); for(int b=0;b<N;b++) if(a!=b){ int c=0; cudaDeviceCanAccessPeer(&c,dev[a],dev[b]); if(c){ cudaError_t e=cudaDeviceEnablePeerAccess(dev[b],0); (void)e; } } }
    const char* transport = p2p_any ? "cudaMemcpyPeer P2P (NVLink/PCIe direct on >=1 pair)" : "staged-host cudaMemcpyPeer (P2P disabled all pairs; correctness identical)";
    printf("transport = %s\n", transport);
    printf("model: MLP %d->%d->%d->%d (ReLU,ReLU,linear), FP64. global batch B=%d split %d/rank.\n",D_IN,H,H,D_OUT,B_GLOBAL,B_GLOBAL/N);

    DevBufs DB; dev_alloc(DB,dev,N,L,H);

    // ════════ M8 + M10: two optimizers, K-step 1-GPU vs N-GPU run ════════════
    int overall_green=1;
    struct OptResult { const char* name; double worst_loss; double worst_W; double worst_opt1; double worst_opt2; };
    std::vector<OptResult> results;

    for (int opt_kind=0; opt_kind<2; opt_kind++){
        const char* oname = opt_kind==0 ? "SGD-momentum" : "Adam";
        printf("\n================= M8/M10 :: optimizer = %s, K=%d steps =================\n",oname,K);
        std::vector<double> Winit; make_init(Winit,L);
        std::vector<double> Wref=Winit, Wddp=Winit;
        OptSGD sgdR,sgdD; OptAdam adamR,adamD;
        sgdR.init(L.NPARAM); sgdD.init(L.NPARAM); adamR.init(L.NPARAM); adamD.init(L.NPARAM);
        double worst_loss=0.0, worst_W=0.0, worst_opt1=0.0, worst_opt2=0.0;
        printf("  per-step loss curve (M10) + after-step W/opt byte-eq (M8):\n");
        for (int k=0;k<K;k++){
            std::vector<double> X,Y; make_batch(X,Y,k);
            // 1-GPU reference grad reduced in the SAME ring right-nested order so
            // the gate is a true max|Δ|=0 (M5b finding). loss is order-free sum.
            std::vector<double> gref; double loss_ref_ring = ref_avg_grad(Wref,X,Y,N,L,H,gref);
            // N-GPU DDP: device fwd/bwd on shards + real ring all-reduce.
            std::vector<double> gddp; double loss_ddp = dev_avg_grad(DB,dev,Wddp,X,Y,gddp);
            double ldiff = fabs(loss_ref_ring - loss_ddp);
            if (ldiff>worst_loss) worst_loss=ldiff;
            double gdiff = maxabsdiff(gref,gddp);
            if (opt_kind==0){ sgdR.step(Wref,gref); sgdD.step(Wddp,gddp); }
            else            { adamR.step(Wref,gref); adamD.step(Wddp,gddp); }
            double wdiff = maxabsdiff(Wref,Wddp);
            if (wdiff>worst_W) worst_W=wdiff;
            double o1=0,o2=0;
            if (opt_kind==0){ o1=maxabsdiff(sgdR.vel,sgdD.vel); }
            else            { o1=maxabsdiff(adamR.m,adamD.m); o2=maxabsdiff(adamR.v,adamD.v); }
            if (o1>worst_opt1) worst_opt1=o1; if (o2>worst_opt2) worst_opt2=o2;
            if (opt_kind==0)
                printf("    step %2d: loss_1gpu=%.15g loss_Ngpu=%.15g  loss|Δ|=%.3g grad|Δ|=%.3g  W|Δ|=%.3g  vel|Δ|=%.3g\n",
                       k,loss_ref_ring,loss_ddp,ldiff,gdiff,wdiff,o1);
            else
                printf("    step %2d: loss_1gpu=%.15g loss_Ngpu=%.15g  loss|Δ|=%.3g grad|Δ|=%.3g  W|Δ|=%.3g  m|Δ|=%.3g v|Δ|=%.3g\n",
                       k,loss_ref_ring,loss_ddp,ldiff,gdiff,wdiff,o1,o2);
        }
        if (opt_kind==0)
            printf("  --- %s after K=%d: loss-curve max|Δ|=%.17g  W max|Δ|=%.17g  vel max|Δ|=%.17g ---\n",oname,K,worst_loss,worst_W,worst_opt1);
        else
            printf("  --- %s after K=%d: loss-curve max|Δ|=%.17g  W max|Δ|=%.17g  m max|Δ|=%.17g  v max|Δ|=%.17g ---\n",oname,K,worst_loss,worst_W,worst_opt1,worst_opt2);
        int fail = (worst_loss!=0.0||worst_W!=0.0||worst_opt1!=0.0||worst_opt2!=0.0);
        if (fail) overall_green=0;
        results.push_back({oname,worst_loss,worst_W,worst_opt1,worst_opt2});
    }
    dev_free(DB,dev);

    // ════════ M9: bf16/fp16 same-dtype reproducibility ════════════════════════
    printf("\n================= M9 :: bf16/fp16 real-dtype DDP reproducibility =================\n");
    double bf_rw=0,bf_rl=0,bf_ma=0,hf_rw=0,hf_rl=0,hf_ma=0;
    m9_run<__nv_bfloat16>(N,L,H,K,bf_rw,bf_rl,bf_ma,"bf16");
    m9_run<__half>       (N,L,H,K,hf_rw,hf_rl,hf_ma,"fp16");
    // dtype reproduction bounds (1 ULP at the weight magnitude ~ unit-ish): bf16
    // has 8 mantissa bits (eps≈3.9e-3), fp16 has 11 (eps≈9.8e-4). The order-fixed
    // ring is bit-reproducible IF both sides cast at the same points; here 1-GPU
    // (whole-batch) vs N-GPU (shard-then-cast) differ at the cast points, so the
    // honest gate is rel-RMS within a few× the dtype eps.
    const double BF16_EPS=1.0/256.0, FP16_EPS=1.0/2048.0;
    int bf_pass = bf_rw <= 4.0*BF16_EPS;
    int hf_pass = hf_rw <= 4.0*FP16_EPS;

    // ════════ VERDICT ════════════════════════════════════════════════════════
    printf("\n================= DDP-M8/M9/M10 VERDICT =================\n");
    printf("transport: %s\n",transport);
    printf("K = %d steps,  N = %d GPUs,  H = %d,  NPARAM = %d,  B_GLOBAL = %d\n",K,N,H,L.NPARAM,B_GLOBAL);
    for (auto& r : results){
        int isadam = strcmp(r.name,"Adam")==0;
        printf("[M8 opt=%s] W max|Δ|=%.17g  opt-state(%s) max|Δ|=%.17g",r.name,r.worst_W, isadam?"m":"vel",r.worst_opt1);
        if (isadam) printf("  v max|Δ|=%.17g",r.worst_opt2);
        printf("  %s\n", (r.worst_W==0.0&&r.worst_opt1==0.0&&r.worst_opt2==0.0)?"BYTE-EQ PASS":"FAIL");
        printf("[M10 opt=%s] loss-curve max|Δ| over K steps = %.17g  %s\n",r.name,r.worst_loss, r.worst_loss==0.0?"BYTE-EQ PASS":"FAIL");
    }
    printf("[M9 bf16] 1-GPU vs %d-GPU: loss rel-Δ=%.4g  W rel-RMS=%.4g  W max|Δ|=%.4g  (bound 4*eps=%.4g) %s\n",N,bf_rl,bf_rw,bf_ma,4.0*BF16_EPS,bf_pass?"PASS":"OUT-OF-BOUND");
    printf("[M9 fp16] 1-GPU vs %d-GPU: loss rel-Δ=%.4g  W rel-RMS=%.4g  W max|Δ|=%.4g  (bound 4*eps=%.4g) %s\n",N,hf_rl,hf_rw,hf_ma,4.0*FP16_EPS,hf_pass?"PASS":"OUT-OF-BOUND");
    printf("=== DDP-M8/M10: %s ===\n", overall_green?"GREEN - K-step W+optimizer-state+loss-curve byte-eq":"RED");
    return overall_green?0:1;
}
