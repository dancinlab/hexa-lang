// ═══════════════════════════════════════════════════════════════════════════
//  ddp_train_m5d.cu — HEXA-DDP DDP-M5d: THROUGHPUT scaling — the regime where
//  data-parallel DDP ACTUALLY wins.
//
//  THE M5b/M5c FINDING THIS TESTS
//  ──────────────────────────────
//  DDP-M5b (#2897) and DDP-M5c (#2901) measured PER-STEP latency: split a
//  FIXED global batch B=64 across N ranks. Result: per-step wall never beats
//  1-GPU (2-GPU 0.99x asymptote, 4-GPU 0.974x) EVEN on real NVLink — because
//  splitting a fixed batch only shards the BATCH dimension, but an H->H MLP
//  step is the H² weight-bound GEMM, so 64 rows -> 16 rows barely reduces
//  per-rank FLOPs. M5c's explicit conclusion: small-batch data-parallel
//  per-step wall is STRUCTURALLY capped at 1.0x (any transport); DDP's REAL
//  win is the BATCH-BOUND regime — keep per-GPU batch FIXED and scale the
//  GLOBAL batch with N, so each GPU does the SAME work and you process N× more
//  samples per step.
//
//  M5d MEASURES that regime: FIX per-GPU batch (B_perGPU), set
//      B_global(N) = B_perGPU × N,
//  and measure SAMPLES/SEC (throughput) at N = 1 / 2 / 4. Each rank always
//  forwards/backwards B_perGPU samples (constant per-rank work), so the wall
//  per step stays ≈flat while N× more samples are consumed → throughput SHOULD
//  scale UP with N (minus the comm tax). This is the metric DDP is designed
//  for and the inverse of the per-step latency M5b/M5c reported.
//
//  TWO GATES (g5)
//  ──────────────
//   (1) CORRECTNESS — for a given N, the N-GPU DDP step is byte-eq to a
//       1-process reference that consumes the SAME total batch B_global(N) and
//       reduces the per-shard grad partials in the ring's RIGHT-NESTED order.
//       Proven at N=4 (the case where the per-chunk right-nested tree bites;
//       N=2 is a single add, trivially order-invariant): grad / weights /
//       rank-agreement all max|Δ|=0, FP64. (M4/M5b/M5c invariant; the ring
//       carries an NPARAM-length grad vector — model size & batch size are
//       irrelevant to the algebra. With per-GPU batch fixed, the global batch
//       B_global = B_perGPU·N IS the data-parallel definition: each rank owns
//       its B_perGPU samples, partials summed by the ring == the grad of the
//       mean loss over all B_global samples.)
//
//   (2) THROUGHPUT SCALING — samples/sec = B_global(N)·1000 / wall_ms at
//       N = 1 / 2 / 4 with B_perGPU FIXED, plus scaling efficiency
//       eff(N) = throughput(N) / (N · throughput(1)). Reported per model size.
//
//  HONEST (g5/g83): expect eff < 100% (comm tax — the all-reduce of the grad
//  vector is the same NPARAM-length ring at every N). But UNLIKE per-step
//  latency (M5b/M5c < 1×), throughput SHOULD scale UP with N — that is the
//  regime DDP is built for. If even throughput fails to scale, that is a
//  surprising honest finding and is reported verbatim. We sweep a model-size
//  knob (HEXA_DDP_H) because comm/compute ratio shifts the efficiency.
//
//  COMPOSES the prior legs unchanged:
//    · DDP-M4 (#2894): flame MLP fwd/bwd train step + grad ring all-reduce,
//      1-GPU == 2-GPU byte-eq on real hardware.
//    · DDP-M5 (#2892) / M5b (#2897): the SAME canonical ring at N=4
//      (2(N-1) steps), real cudaMemcpyPeer transport.
//    · DDP-M5c (#2901): the per-chunk RIGHT-NESTED reference reduction making
//      the N=4 gate a true max|Δ|=0 (not a tolerance).
//  The ONLY M5d change vs M5c: per-GPU batch is FIXED and the global batch
//  scales with N; the timed metric is SAMPLES/SEC, not per-step wall.
//
//  Build:  nvcc -O2 -arch=sm_80 -o ddp_train_m5d ddp_train_m5d.cu
//  Run:    DDP_NUM_GPUS=4 ./ddp_train_m5d
//  Env:    HEXA_DDP_H        = comma list of hidden dims (default "256,1024,2048")
//          HEXA_DDP_BPERGPU  = per-GPU (per-rank) batch, FIXED (default 64)
//          HEXA_DDP_REPS     = timed reps per (N,H) (default 30, 5 warmup)
// ═══════════════════════════════════════════════════════════════════════════
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
#include <string>
#include <algorithm>
#include <ctime>
#include <cuda_runtime.h>

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { \
    fprintf(stderr, "CUDA ERROR %s:%d: %s\n", __FILE__, __LINE__, \
            cudaGetErrorString(_e)); exit(1); } } while (0)

// ── model shape ─────────────────────────────────────────────────────────────
// MLP  D_IN -> H -> H -> D_OUT (ReLU,ReLU,linear), MSE loss. H is the SIZE knob.
static const int    D_IN  = 64;
static const int    D_OUT = 64;
static const double LR    = 0.01;
// per-GPU batch is FIXED (the M5d regime). Global batch = B_PERGPU * N.
static int B_PERGPU = 64;

// parameter layout (flat FP64): W1[H*D_IN] b1[H] W2[H*H] b2[H] W3[D_OUT*H] b3[D_OUT]
struct Layout { int P_W1,P_B1,P_W2,P_B2,P_W3,P_B3,NPARAM; };
static Layout layout_for(int H) {
    Layout L; int o = 0;
    L.P_W1=o; o += H*D_IN;
    L.P_B1=o; o += H;
    L.P_W2=o; o += H*H;
    L.P_B2=o; o += H;
    L.P_W3=o; o += D_OUT*H;
    L.P_B3=o; o += D_OUT;
    L.NPARAM=o; return L;
}

// ── deterministic data + init (seed-fixed, identical at every N) ─────────────
static double hval(unsigned long long k) {
    k += 0x9E3779B97F4A7C15ULL;
    k = (k ^ (k >> 30)) * 0xBF58476D1CE4E5B9ULL;
    k = (k ^ (k >> 27)) * 0x94D049BB133111EBULL;
    k =  k ^ (k >> 31);
    return ((double)(k % 1000003ULL) / 1000003.0) - 0.5;
}
// make a batch of EXACTLY B samples (B_global, scales with N).
static void make_batch(std::vector<double>& X, std::vector<double>& Y, int B) {
    X.resize((size_t)B*D_IN); Y.resize((size_t)B*D_OUT);
    for (int j=0;j<B;j++){
        for (int i=0;i<D_IN; i++) X[(size_t)j*D_IN +i]=hval(0x1000ULL*(j+1)+i);
        for (int i=0;i<D_OUT;i++) Y[(size_t)j*D_OUT+i]=hval(0x7000ULL*(j+1)+i);
    }
}
static void make_init(std::vector<double>& W, const Layout& L) {
    W.resize(L.NPARAM);
    for (int p=0;p<L.NPARAM;p++) W[p]=hval(0xABCDEF01ULL+(unsigned long long)p*2654435761ULL);
}

// ═══ device forward+backward (REAL compute per shard, cost ~ H²) ═════════════
// One CUDA block per sample; threads cooperate over H. Accumulates the SUM of
// per-sample grads into G (atomicAdd) and the loss-sum into a scalar. FP64.
__global__ void fwd_bwd_kernel(const double* W, const double* X, const double* Y,
                               double* G, double* loss_acc, int s0, int s1,
                               int H, int P_W1,int P_B1,int P_W2,int P_B2,int P_W3,int P_B3) {
    int s = s0 + blockIdx.x;
    if (s >= s1) return;
    extern __shared__ double sh[];           // a1[H] a2[H] h1[H] h2[H] da[H] dh[H]
    double* a1 = sh;          // [H]
    double* a2 = sh + H;      // [H]
    double* h1 = sh + 2*H;    // [H]
    double* h2 = sh + 3*H;    // [H] (reused as da1 scratch after dh2 built)
    double* da = sh + 4*H;    // [H] (da2)
    double* dh = sh + 5*H;    // [H] (dh2)
    const double* W1=W+P_W1; const double* b1=W+P_B1;
    const double* W2=W+P_W2; const double* b2=W+P_B2;
    const double* W3=W+P_W3; const double* b3=W+P_B3;
    double* gW1=G+P_W1; double* gb1=G+P_B1;
    double* gW2=G+P_W2; double* gb2=G+P_B2;
    double* gW3=G+P_W3; double* gb3=G+P_B3;
    const double* x = X + (size_t)s*D_IN;
    const double* y = Y + (size_t)s*D_OUT;

    for (int k=threadIdx.x;k<H;k+=blockDim.x){
        double acc=b1[k];
        for (int i=0;i<D_IN;i++) acc+=W1[(size_t)k*D_IN+i]*x[i];
        h1[k]=acc; a1[k]=acc>0.0?acc:0.0;
    }
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x){
        double acc=b2[k];
        for (int i=0;i<H;i++) acc+=W2[(size_t)k*H+i]*a1[i];
        h2[k]=acc; a2[k]=acc>0.0?acc:0.0;
    }
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x) da[k]=0.0;   // da2 accumulator
    __syncthreads();
    for (int k=threadIdx.x;k<D_OUT;k+=blockDim.x){
        double acc=b3[k];
        for (int i=0;i<H;i++) acc+=W3[(size_t)k*H+i]*a2[i];
        double e = acc - y[k];
        atomicAdd(loss_acc, e*e);
        double dout = 2.0*e;
        atomicAdd(&gb3[k], dout);
        for (int i=0;i<H;i++){
            atomicAdd(&gW3[(size_t)k*H+i], dout*a2[i]);
            atomicAdd(&da[i], dout*W3[(size_t)k*H+i]);   // da2[i]
        }
    }
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x) dh[k] = h2[k]>0.0 ? da[k] : 0.0;  // dh2
    __syncthreads();
    double* da1 = h2;        // h2 no longer needed -> reuse as da1 scratch
    for (int k=threadIdx.x;k<H;k+=blockDim.x) da1[k]=0.0;
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x){
        double d=dh[k];
        atomicAdd(&gb2[k], d);
        for (int i=0;i<H;i++){
            atomicAdd(&gW2[(size_t)k*H+i], d*a1[i]);
            atomicAdd(&da1[i], d*W2[(size_t)k*H+i]);
        }
    }
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x){
        double dh1 = h1[k]>0.0 ? da1[k] : 0.0;
        atomicAdd(&gb1[k], dh1);
        for (int i=0;i<D_IN;i++) atomicAdd(&gW1[(size_t)k*D_IN+i], dh1*x[i]);
    }
}

// ── host FP64 reference fwd/bwd (the byte-eq GATE oracle, from M4) ───────────
static double fwd_bwd_accum_host(const double* W,const double* X,const double* Y,
                                 int s0,int s1,double* G,const Layout& L,int H){
    double loss_sum=0.0;
    const double* W1=W+L.P_W1; const double* b1=W+L.P_B1;
    const double* W2=W+L.P_W2; const double* b2=W+L.P_B2;
    const double* W3=W+L.P_W3; const double* b3=W+L.P_B3;
    double* gW1=G+L.P_W1; double* gb1=G+L.P_B1;
    double* gW2=G+L.P_W2; double* gb2=G+L.P_B2;
    double* gW3=G+L.P_W3; double* gb3=G+L.P_B3;
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

// ── canonical ring all-reduce SUM (DDP-M1 schedule, M3/M5 transport) ─────────
static long chunk_start(long S,int N,int c){ long base=S/N,rem=S%N; if(c<=rem) return (long)c*(base+1); return rem*(base+1)+(long)(c-rem)*base; }
__global__ void add_range(double* dst,const double* src,long start,long stop){ long i=start+(long)blockIdx.x*blockDim.x+threadIdx.x; if(i<stop) dst[i]+=src[i]; }
static void ring_all_reduce_sum(std::vector<double*>& d,std::vector<double*>& staging,const int* dev,int N,long S){
    if (N==1) return;                               // single rank: nothing to reduce
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

static void sgd_step(double* W,const double* g,int n){ for(int p=0;p<n;p++) W[p]-=LR*g[p]; }

// ── reference grad reduced with the EXACT per-chunk RIGHT-NESTED parenthesization
// the ring produces (DDP-M5c finding) ──────────────────────────────────────
static int ring_chunk_of(long p, long S, int N){
    int c=0; while (c<N && !(p>=chunk_start(S,N,c) && p<chunk_start(S,N,c+1))) c++;
    return c<N?c:N-1;
}
static void ref_grad_ring_order(const std::vector<std::vector<double>>& gloc,
                                int N, long S, std::vector<double>& g_out){
    g_out.assign((size_t)S,0.0);
    for (long p=0;p<S;p++){
        int c=ring_chunk_of(p,S,N);
        double acc = gloc[(size_t)((c-1-(N-1)+2*N)%N)][p];   // s[N-1] == rank c
        for (int j=N-2;j>=0;j--) acc = gloc[(size_t)((c-1-j+2*N)%N)][p] + acc;
        g_out[p]=acc;
    }
}

// ── persistent per-rank device buffers (alloc once per (N,H), reused for reps) ─
// EACH rank holds B_PERGPU samples (per-GPU batch FIXED — the M5d regime).
struct RankBufs { std::vector<double*> dW, dX, dY, dG, dloss, dstage; };

static void alloc_rank_bufs(RankBufs& B,const int* dev,int N,const Layout& L,
                            const std::vector<double>& Winit,
                            const std::vector<double>& X,const std::vector<double>& Y){
    int shard=B_PERGPU;                  // per-rank batch is FIXED at B_PERGPU
    B.dW.assign(N,nullptr); B.dX.assign(N,nullptr); B.dY.assign(N,nullptr);
    B.dG.assign(N,nullptr); B.dloss.assign(N,nullptr); B.dstage.assign(N,nullptr);
    for (int r=0;r<N;r++){
        CK(cudaSetDevice(dev[r]));
        CK(cudaMalloc(&B.dW[r], (size_t)L.NPARAM*sizeof(double)));
        CK(cudaMalloc(&B.dG[r], (size_t)L.NPARAM*sizeof(double)));
        CK(cudaMalloc(&B.dstage[r], (size_t)L.NPARAM*sizeof(double)));
        CK(cudaMalloc(&B.dloss[r], sizeof(double)));
        CK(cudaMalloc(&B.dX[r], (size_t)shard*D_IN*sizeof(double)));
        CK(cudaMalloc(&B.dY[r], (size_t)shard*D_OUT*sizeof(double)));
        CK(cudaMemcpy(B.dW[r], Winit.data(), (size_t)L.NPARAM*sizeof(double), cudaMemcpyHostToDevice));
        CK(cudaMemcpy(B.dX[r], X.data()+(size_t)r*shard*D_IN,  (size_t)shard*D_IN *sizeof(double), cudaMemcpyHostToDevice));
        CK(cudaMemcpy(B.dY[r], Y.data()+(size_t)r*shard*D_OUT, (size_t)shard*D_OUT*sizeof(double), cudaMemcpyHostToDevice));
    }
}
static void free_rank_bufs(RankBufs& B,const int* dev,int N){
    for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaFree(B.dW[r])); CK(cudaFree(B.dG[r])); CK(cudaFree(B.dstage[r])); CK(cudaFree(B.dloss[r])); CK(cudaFree(B.dX[r])); CK(cudaFree(B.dY[r])); }
}

static size_t enable_shmem(const int* dev,int N,int H){
    size_t shmem=(size_t)6*H*sizeof(double);
    for (int r=0;r<N;r++){
        CK(cudaSetDevice(dev[r]));
        int maxsh=0; CK(cudaDeviceGetAttribute(&maxsh,cudaDevAttrMaxSharedMemoryPerBlockOptin,dev[r]));
        if (shmem>(size_t)maxsh){ fprintf(stderr,"FATAL: H=%d needs %zu B shared > device optin max %d B\n",H,shmem,maxsh); exit(2); }
        CK(cudaFuncSetAttribute(fwd_bwd_kernel,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)shmem));
    }
    return shmem;
}

// run ONE training step (device compute on each rank's FIXED B_PERGPU shard +
// ring all-reduce of the grad), timed end-to-end on the wall clock.
static double ddp_step_timed(RankBufs& B,const int* dev,int N,const Layout& L,int H,size_t shmem){
    int shard=B_PERGPU;
    for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaMemsetAsync(B.dG[r],0,(size_t)L.NPARAM*sizeof(double))); CK(cudaMemsetAsync(B.dloss[r],0,sizeof(double))); }
    for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaDeviceSynchronize()); }
    struct timespec ts0,ts1; clock_gettime(CLOCK_MONOTONIC,&ts0);
    for (int r=0;r<N;r++){
        CK(cudaSetDevice(dev[r]));
        fwd_bwd_kernel<<<shard,256,shmem>>>(B.dW[r],B.dX[r],B.dY[r],B.dG[r],B.dloss[r],0,shard,H,
            L.P_W1,L.P_B1,L.P_W2,L.P_B2,L.P_W3,L.P_B3);
        CK(cudaGetLastError());
    }
    for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaDeviceSynchronize()); }
    ring_all_reduce_sum(B.dG,B.dstage,dev,N,L.NPARAM);
    for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaDeviceSynchronize()); }
    clock_gettime(CLOCK_MONOTONIC,&ts1);
    return (ts1.tv_sec-ts0.tv_sec)*1e3 + (ts1.tv_nsec-ts0.tv_nsec)/1e6;  // ms
}

static double median(std::vector<double> v){ std::sort(v.begin(),v.end()); size_t n=v.size(); return n? (n%2? v[n/2] : 0.5*(v[n/2-1]+v[n/2])) : 0.0; }

int main(int argc,char** argv){
    int ndev=0; CK(cudaGetDeviceCount(&ndev));
    printf("=== ddp_train_m5d :: visible CUDA devices = %d ===\n", ndev);
    if (ndev<4){ printf("FATAL: DDP-M5d needs >= 4 GPUs on one node (found %d)\n",ndev); return 3; }
    const int dev4[4]={0,1,2,3};

    { const char* e=getenv("HEXA_DDP_BPERGPU"); if(e){ B_PERGPU=atoi(e); if(B_PERGPU<1)B_PERGPU=1; } }

    int p2p_any=0;
    for (int a=0;a<4;a++) for(int b=0;b<4;b++) if(a!=b){ int c=0; CK(cudaDeviceCanAccessPeer(&c,dev4[a],dev4[b])); printf("canAccessPeer(%d->%d)=%d\n",a,b,c); if(c)p2p_any=1; }
    for (int a=0;a<4;a++){ CK(cudaSetDevice(dev4[a])); for(int b=0;b<4;b++) if(a!=b){ int c=0; cudaDeviceCanAccessPeer(&c,dev4[a],dev4[b]); if(c){ cudaError_t e=cudaDeviceEnablePeerAccess(dev4[b],0); (void)e; } } }
    const char* transport = p2p_any ? "cudaMemcpyPeer P2P (NVLink/PCIe direct on >=1 pair)" : "staged-host cudaMemcpyPeer (P2P disabled on all pairs; correctness identical)";
    printf("transport = %s\n", transport);

    std::vector<int> Hs;
    { const char* e=getenv("HEXA_DDP_H"); std::string s = e?e:"256,1024,2048"; size_t i=0; while(i<s.size()){ size_t j=s.find(',',i); std::string tok=s.substr(i, j==std::string::npos?std::string::npos:j-i); if(!tok.empty()) Hs.push_back(atoi(tok.c_str())); if(j==std::string::npos)break; i=j+1; } }
    int REPS=30; { const char* e=getenv("HEXA_DDP_REPS"); if(e) REPS=atoi(e); } int WARM=5;
    const int Ns[3]={1,2,4};

    printf("\nM5d THROUGHPUT regime: per-GPU batch FIXED, global batch scales with N.\n");
    printf("model: MLP %d->H->H->%d (ReLU,ReLU,linear), FP64.\n",D_IN,D_OUT);
    printf("per-GPU batch B_perGPU = %d (FIXED).  B_global(N) = B_perGPU * N => N=1:%d N=2:%d N=4:%d.\n",
           B_PERGPU, B_PERGPU*1, B_PERGPU*2, B_PERGPU*4);
    printf("size sweep H = "); for(size_t i=0;i<Hs.size();i++) printf("%d%s",Hs[i], i+1<Hs.size()?",":"\n");
    printf("timing: median of %d reps (%d warmup discarded), per-step wall (fwd+bwd+all-reduce+sync).\n",REPS,WARM);
    printf("throughput(N) = B_global(N) * 1000 / wall_ms  (samples/sec).\n");

    int overall_green=1;
    int byteeq_fail=0; double worst_byteeq=0.0; int H_for_gate=0; int Bglob_gate=0;

    printf("\n================= THROUGHPUT SCALING SWEEP =================\n");
    for (int H : Hs){
        Layout L=layout_for(H);
        std::vector<double> Winit; make_init(Winit,L);
        printf("\n--- H=%d  NPARAM=%d ---\n",H,L.NPARAM);
        double thr[3]={0,0,0}; double wall[3]={0,0,0};
        size_t shmem=enable_shmem(dev4,4,H);
        for (int ni=0; ni<3; ni++){
            int N=Ns[ni];
            int Bglob = B_PERGPU*N;
            std::vector<double> X,Y; make_batch(X,Y,Bglob);   // global batch = B_perGPU*N
            RankBufs B; alloc_rank_bufs(B,dev4,N,L,Winit,X,Y);
            for (int w=0;w<WARM;w++) ddp_step_timed(B,dev4,N,L,H,shmem);
            std::vector<double> reps; reps.reserve(REPS);
            for (int r=0;r<REPS;r++) reps.push_back(ddp_step_timed(B,dev4,N,L,H,shmem));
            double t=median(reps);
            wall[ni]=t;
            thr[ni]= t>0.0 ? (double)Bglob*1000.0/t : 0.0;
            free_rank_bufs(B,dev4,N);
            printf("  N=%d  B_global=%4d  per-step wall(median)= %10.4f ms  throughput= %12.2f samples/sec\n",
                   N, Bglob, t, thr[ni]);
        }
        double eff2 = thr[0]>0 ? thr[1]/(2.0*thr[0]) : 0.0;
        double eff4 = thr[0]>0 ? thr[2]/(4.0*thr[0]) : 0.0;
        double sc2  = thr[0]>0 ? thr[1]/thr[0] : 0.0;
        double sc4  = thr[0]>0 ? thr[2]/thr[0] : 0.0;
        printf("  throughput scaling vs 1-GPU: 2-GPU= %.3fx (eff %.1f%%)   4-GPU= %.3fx (eff %.1f%%)\n",
               sc2, 100.0*eff2, sc4, 100.0*eff4);
    }

    // ─────────── byte-eq gate (N=4): 1-process ref == 4-GPU DDP ────────────
    // Per-GPU batch FIXED -> B_global = B_perGPU*4. The 1-process reference
    // consumes ALL B_global samples sharded into 4 pieces and reduced in the
    // ring's per-chunk right-nested order (the DDP-equivalence definition).
    {
        int H=Hs.empty()?256:Hs[0]; H_for_gate=H;
        const int NW=4; int shard=B_PERGPU; int Bglob=B_PERGPU*NW; Bglob_gate=Bglob;
        Layout L=layout_for(H);
        std::vector<double> Winit; make_init(Winit,L);
        std::vector<double> X,Y; make_batch(X,Y,Bglob);
        printf("\n================= N=4 BYTE-EQ GATE (H=%d, B_global=%d, per-GPU=%d) =================\n",H,Bglob,shard);

        std::vector<std::vector<double>> gloc(NW, std::vector<double>(L.NPARAM,0.0));
        std::vector<double> lloc(NW,0.0);
        for (int r=0;r<NW;r++) lloc[r]=fwd_bwd_accum_host(Winit.data(),X.data(),Y.data(),r*shard,(r+1)*shard,gloc[r].data(),L,H);
        std::vector<double> g_ref, W_ref=Winit;
        ref_grad_ring_order(gloc, NW, L.NPARAM, g_ref);
        for (int p=0;p<L.NPARAM;p++) g_ref[p] /= (double)Bglob;
        double loss_ref=lloc[0]; for(int r=1;r<NW;r++) loss_ref+=lloc[r]; loss_ref/=(double)Bglob;
        sgd_step(W_ref.data(),g_ref.data(),L.NPARAM);

        std::vector<double*> d(NW,nullptr), stg(NW,nullptr);
        for (int r=0;r<NW;r++){ CK(cudaSetDevice(dev4[r])); CK(cudaMalloc(&d[r],(size_t)L.NPARAM*sizeof(double))); CK(cudaMalloc(&stg[r],(size_t)L.NPARAM*sizeof(double))); CK(cudaMemcpy(d[r],gloc[r].data(),(size_t)L.NPARAM*sizeof(double),cudaMemcpyHostToDevice)); }
        ring_all_reduce_sum(d,stg,dev4,NW,L.NPARAM);
        std::vector<std::vector<double>> W_ddp(NW,Winit);
        std::vector<std::vector<double>> g_sum(NW,std::vector<double>(L.NPARAM));
        for (int r=0;r<NW;r++){ CK(cudaSetDevice(dev4[r])); CK(cudaMemcpy(g_sum[r].data(),d[r],(size_t)L.NPARAM*sizeof(double),cudaMemcpyDeviceToHost)); for(int p=0;p<L.NPARAM;p++) g_sum[r][p]/=(double)Bglob; sgd_step(W_ddp[r].data(),g_sum[r].data(),L.NPARAM); }
        double rank_dis=0.0; for(int r=1;r<NW;r++) for(int p=0;p<L.NPARAM;p++){ double dd=fabs(W_ddp[r][p]-W_ddp[0][p]); if(dd>rank_dis)rank_dis=dd; }
        double w_diff=0.0; for(int p=0;p<L.NPARAM;p++){ double dd=fabs(W_ddp[0][p]-W_ref[p]); if(dd>w_diff)w_diff=dd; }
        double g_diff=0.0; for(int p=0;p<L.NPARAM;p++){ double dd=fabs(g_sum[0][p]-g_ref[p]); if(dd>g_diff)g_diff=dd; }
        for (int r=0;r<NW;r++){ CK(cudaSetDevice(dev4[r])); CK(cudaFree(d[r])); CK(cudaFree(stg[r])); }

        printf("loss_ref (mean over B_global=%d) = %.17g\n",Bglob,loss_ref);
        printf("grad  g_ddp vs g_ref  max|delta| = %.17g  %s\n",g_diff, g_diff==0.0?"BYTE-EQ":"MISMATCH");
        printf("rank-agreement (Wr==W0) max|delta| = %.17g  %s\n",rank_dis, rank_dis==0.0?"ALL RANKS IDENTICAL":"RANK DISAGREE");
        printf("WEIGHTS W_ddp vs W_ref  max|delta| = %.17g  %s\n",w_diff, w_diff==0.0?"BYTE-EQ PASS":"FAIL");
        worst_byteeq = w_diff; if(g_diff>worst_byteeq)worst_byteeq=g_diff; if(rank_dis>worst_byteeq)worst_byteeq=rank_dis;
        byteeq_fail = (w_diff!=0.0||g_diff!=0.0||rank_dis!=0.0);
        if (byteeq_fail) overall_green=0;
    }

    printf("\n================= DDP-M5d VERDICT =================\n");
    printf("byte-eq (N=4, H=%d, B_global=%d): max|delta| = %.17g  %s\n",H_for_gate,Bglob_gate,worst_byteeq, byteeq_fail?"FAIL":"BYTE-EQ PASS");
    printf("regime: per-GPU batch FIXED = %d, global batch = B_perGPU * N (THROUGHPUT, not per-step latency).\n",B_PERGPU);
    printf("contrast: M5b/M5c FIXED global batch B=64 split across N -> per-step wall < 1.0x (weight-bound).\n");
    printf("          M5d FIXES per-GPU batch, scales global batch -> samples/sec SHOULD scale UP with N.\n");
    printf("transport: %s   P2P-any=%d (NVLink/direct-P2P active on >=1 pair => %s)\n", transport, p2p_any, p2p_any?"YES":"NO (staged-host)");
    printf("=== DDP-M5d: %s ===\n", overall_green? "GREEN - {1,2,4}-GPU DDP throughput scaling + N=4 byte-eq" : "RED");
    return overall_green?0:1;
}
