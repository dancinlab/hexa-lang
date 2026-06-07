// ═══════════════════════════════════════════════════════════════════════════
//  ddp_train_m5c.cu — HEXA-DDP DDP-M5c: NVLink crossover — the model size
//  where multi-GPU DDP TRAINING actually BEATS 1-GPU (speedup > 1x).
//
//  M5c re-runs the M5b harness (same model, same ring, same byte-eq gate) on an
//  NVLink node (cudaDeviceCanAccessPeer=1, NV# bonds) and sweeps the model-size
//  knob UP until 2-GPU and 4-GPU per-step training wall crosses 1.0x vs 1-GPU.
//  It reports the canAccessPeer probe (P2P-any) + the per-(N,H) wall table + the
//  crossover H for BOTH 2-GPU and 4-GPU. Identical correctness algebra to M5b.
//
//  COMPOSES the two prior legs:
//    · DDP-M4 (#2894): the flame MLP train step + grad ring all-reduce,
//      proven 1-GPU == 2-GPU byte-eq on real 2-GPU hardware.
//    · DDP-M5 (#2892): the SAME canonical ring scaled to a real 4-rank ring
//      (2(N-1) steps), byte-eq + collective scaling measured on 4 GPUs.
//
//  M5b runs the SAME M4 training step as N-GPU DDP for N ∈ {1,2,4}, splitting
//  the SAME global batch + SAME seed across the ranks, all-reducing the grad
//  via the real cudaMemcpyPeer ring, and MEASURES the per-step wall-clock at
//  each N → speedup ratios + efficiency. Plus the N=4 byte-eq gate (the M4
//  correctness invariant extended to N=4).
//
//  TWO GATES (g5)
//  ──────────────
//   (1) CORRECTNESS — for the SAME global batch + seed,
//          1-GPU W_ref  ==  4-GPU DDP W_ddp   byte-eq max|Δ|=0  (FP64).
//       (the M4 DDP invariant, N extended 2 → 4). Algebra: a mean-loss grad is
//       a SUM of per-sample grads scaled by 1/B; splitting B over W ranks and
//       summing the per-rank partials via the ring reproduces the exact same
//       grad on every rank == the 1-GPU grad. Model size is irrelevant to the
//       algebra; we keep FP64 + a fixed per-shard reduction ORDER so the gate
//       is a true max|Δ|=0, not a tolerance.
//
//   (2) SPEEDUP — wall-clock per TRAINING step (full fwd+bwd on the shard +
//       grad all-reduce + SGD) at N = 1 / 2 / 4 GPUs. Report speedup(N) =
//       t(1)/t(N) and efficiency(N) = speedup(N)/N.
//
//  HONEST (g5/g83): N-GPU speedup is ALWAYS < N× — the all-reduce comm + sync
//  is a tax (Amdahl). On a GeForce-class PHB/SYS node (no NVLink) every
//  cudaMemcpyPeer is HOST-STAGED, so for a SMALL model where comm ≫ compute
//  the 4-GPU step can be SLOWER than 1-GPU — that is an honest measured finding,
//  NOT a failure. To make 4-GPU WIN you need compute-per-step ≫ comm: a bigger
//  model (more FLOPs/step) and/or NVLink (cheaper comm). We therefore sweep a
//  MODEL-SIZE knob (HEXA_DDP_H, the hidden dim) and report the per-step wall at
//  each N for each size, so the crossover (the H at which 4-GPU starts winning)
//  is MEASURED on this exact node — not modeled, not faked.
//
//  The compute leg here is a real device fwd+bwd per shard (cost ~ H²), giving
//  an honest compute-vs-comm ratio that grows with H. The correctness/byte-eq
//  leg uses the SAME deterministic FP64 host reference reduction as M4 (the
//  ring carries the grad; transport-agnostic).
//
//  Build:  nvcc -O2 -arch=sm_86 -o ddp_train_m5b ddp_train_m5b.cu
//  Run:    DDP_NUM_GPUS=4 ./ddp_train_m5b        (sweeps N=1,2,4 internally)
//  Env:    HEXA_DDP_H    = comma list of hidden dims (default "64,256,1024,2048")
//          HEXA_DDP_REPS = timed reps per (N,H) (default 30, warmup 5 discarded)
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
static const int    D_IN     = 64;
static const int    D_OUT    = 64;
static const int    B_GLOBAL = 64;     // global batch (divisible by 1,2,4)
static const double LR       = 0.01;

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
static void make_batch(std::vector<double>& X, std::vector<double>& Y) {
    X.resize((size_t)B_GLOBAL*D_IN); Y.resize((size_t)B_GLOBAL*D_OUT);
    for (int j=0;j<B_GLOBAL;j++){
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
// This is the compute leg whose cost grows with H so the compute-vs-comm ratio
// is real and tunable. Correctness of the GATE does NOT depend on this kernel
// (the byte-eq gate uses the FP64 host reference below); this kernel makes the
// TIMING leg compute-bound at large H.
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

// ── reference grad reduced with the EXACT per-chunk PARENTHESIZATION the ring
// produces ──────────────────────────────────────────────────────────────────
// FP add is NOT associative. The ring reduce-scatter (DDP-M1 schedule) sums
// each chunk's N rank-partials in a CHUNK-DEPENDENT RIGHT-NESTED tree: a 4-rank
// simulation tracking the actual `d += staging` parenthesization gives, for
// chunk c (where the sequence is s[j]=(c-1-j+2N)%N, j=0..N-1, i.e. start at rank
// (c-1+N)%N and walk DOWN mod N):
//     chunk c value = s[0] + ( s[1] + ( s[2] + ... + s[N-1] ) )   (RIGHT-fold).
// e.g. chunk 0 = (3+(2+(1+0))). A naive LEFT-fold (((3+2)+1)+0) differs at the
// ULP (~3.5e-15 measured on a 4-GPU 3090 node) — that residual is exactly this
// associativity, NOT a transport error. To make the gate a TRUE max|delta|=0,
// the 1-GPU reference must reduce element p with the same right-nested order as
// the ring reduces p's chunk. This IS the honest DDP-equivalence definition:
// same partials, same reduction tree. (N=2 has a single add, so M4 — and any
// 2-GPU reduction — was trivially order-invariant; the tree only bites at N>=3.)
static int ring_chunk_of(long p, long S, int N){
    int c=0; while (c<N && !(p>=chunk_start(S,N,c) && p<chunk_start(S,N,c+1))) c++;
    return c<N?c:N-1;
}
static void ref_grad_ring_order(const std::vector<std::vector<double>>& gloc,
                                int N, long S, std::vector<double>& g_out){
    g_out.assign((size_t)S,0.0);
    for (long p=0;p<S;p++){
        int c=ring_chunk_of(p,S,N);
        // s[j] = (c-1-j+2N) % N ; right-fold from the innermost (j=N-1) up.
        double acc = gloc[(size_t)((c-1-(N-1)+2*N)%N)][p];   // s[N-1] == rank c
        for (int j=N-2;j>=0;j--) acc = gloc[(size_t)((c-1-j+2*N)%N)][p] + acc;
        g_out[p]=acc;
    }
}

// ── persistent per-rank device buffers (alloc once per (N,H), reused for reps) ─
struct RankBufs { std::vector<double*> dW, dX, dY, dG, dloss, dstage; };

static void alloc_rank_bufs(RankBufs& B,const int* dev,int N,const Layout& L,
                            const std::vector<double>& Winit,
                            const std::vector<double>& X,const std::vector<double>& Y){
    int shard=B_GLOBAL/N;
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

// run ONE training step (device compute + ring all-reduce), timed end-to-end on
// the wall clock (covers all ranks' fwd/bwd + the cross-GPU all-reduce + sync).
// opt the kernel into the device's max dynamic shared-mem (sm_86: up to ~99KB,
// vs the 48KB default opt-out cap) on every device once per (N,H). Returns the
// per-block dynamic shmem bytes, or aborts if H doesn't fit (caller caps H).
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
static double ddp_step_timed(RankBufs& B,const int* dev,int N,const Layout& L,int H,size_t shmem){
    int shard=B_GLOBAL/N;
    for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaMemsetAsync(B.dG[r],0,(size_t)L.NPARAM*sizeof(double))); CK(cudaMemsetAsync(B.dloss[r],0,sizeof(double))); }
    for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaDeviceSynchronize()); }
    struct timespec ts0,ts1; clock_gettime(CLOCK_MONOTONIC,&ts0);
    for (int r=0;r<N;r++){
        CK(cudaSetDevice(dev[r]));
        fwd_bwd_kernel<<<shard,256,shmem>>>(B.dW[r],B.dX[r],B.dY[r],B.dG[r],B.dloss[r],0,shard,H,
            L.P_W1,L.P_B1,L.P_W2,L.P_B2,L.P_W3,L.P_B3);
        CK(cudaGetLastError());                  // catch launch-config errors NOW
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
    printf("=== ddp_train_m5b :: visible CUDA devices = %d ===\n", ndev);
    if (ndev<4){ printf("FATAL: DDP-M5c needs >= 4 GPUs on one node (found %d)\n",ndev); return 3; }
    const int dev4[4]={0,1,2,3};

    int p2p_any=0;
    for (int a=0;a<4;a++) for(int b=0;b<4;b++) if(a!=b){ int c=0; CK(cudaDeviceCanAccessPeer(&c,dev4[a],dev4[b])); printf("canAccessPeer(%d->%d)=%d\n",a,b,c); if(c)p2p_any=1; }
    for (int a=0;a<4;a++){ CK(cudaSetDevice(dev4[a])); for(int b=0;b<4;b++) if(a!=b){ int c=0; cudaDeviceCanAccessPeer(&c,dev4[a],dev4[b]); if(c){ cudaError_t e=cudaDeviceEnablePeerAccess(dev4[b],0); (void)e; } } }
    const char* transport = p2p_any ? "cudaMemcpyPeer P2P (NVLink/PCIe direct on >=1 pair)" : "staged-host cudaMemcpyPeer (P2P disabled on all pairs; correctness identical)";
    printf("transport = %s\n", transport);

    std::vector<int> Hs;
    { const char* e=getenv("HEXA_DDP_H"); std::string s = e?e:"64,256,1024,2048"; size_t i=0; while(i<s.size()){ size_t j=s.find(',',i); std::string tok=s.substr(i, j==std::string::npos?std::string::npos:j-i); if(!tok.empty()) Hs.push_back(atoi(tok.c_str())); if(j==std::string::npos)break; i=j+1; } }
    int REPS=30; { const char* e=getenv("HEXA_DDP_REPS"); if(e) REPS=atoi(e); } int WARM=5;
    const int Ns[3]={1,2,4};

    printf("\nmodel: MLP %d->H->H->%d (ReLU,ReLU,linear), FP64. global batch B=%d.\n",D_IN,D_OUT,B_GLOBAL);
    printf("size sweep H = "); for(size_t i=0;i<Hs.size();i++) printf("%d%s",Hs[i], i+1<Hs.size()?",":"\n");
    printf("timing: median of %d reps (%d warmup discarded), per-step wall (fwd+bwd+all-reduce+sync).\n",REPS,WARM);

    std::vector<double> X,Y; make_batch(X,Y);

    int overall_green=1;
    int byteeq_fail=0; double worst_byteeq=0.0; int H_for_gate=0;
    int crossover_H=-1;   // first H where 4-GPU speedup > 1.0x
    int crossover2_H=-1;  // first H where 2-GPU speedup > 1.0x

    printf("\n================= PER-STEP WALL + SPEEDUP SWEEP =================\n");
    for (int H : Hs){
        Layout L=layout_for(H);
        std::vector<double> Winit; make_init(Winit,L);
        printf("\n--- H=%d  NPARAM=%d ---\n",H,L.NPARAM);
        double t[3]={0,0,0};
        size_t shmem=enable_shmem(dev4,4,H);
        for (int ni=0; ni<3; ni++){
            int N=Ns[ni];
            RankBufs B; alloc_rank_bufs(B,dev4,N,L,Winit,X,Y);
            for (int w=0;w<WARM;w++) ddp_step_timed(B,dev4,N,L,H,shmem);
            std::vector<double> reps; reps.reserve(REPS);
            for (int r=0;r<REPS;r++) reps.push_back(ddp_step_timed(B,dev4,N,L,H,shmem));
            t[ni]=median(reps);
            free_rank_bufs(B,dev4,N);
            printf("  N=%d  per-step wall(median)= %10.4f ms\n",N,t[ni]);
        }
        double sp2=t[0]/t[1], sp4=t[0]/t[2];
        printf("  speedup: 2-GPU= %.3fx (eff %.1f%%)   4-GPU= %.3fx (eff %.1f%%)\n",
               sp2, 100.0*sp2/2.0, sp4, 100.0*sp4/4.0);
        if (sp4>1.0 && crossover_H<0) crossover_H=H;
        if (sp2>1.0 && crossover2_H<0) crossover2_H=H;
    }

    // ─────────── byte-eq gate (N=4): 1-GPU W_ref == 4-GPU W_ddp ────────────
    {
        int H=Hs.empty()?64:Hs[0]; H_for_gate=H;
        Layout L=layout_for(H);
        std::vector<double> Winit; make_init(Winit,L);
        printf("\n================= N=4 BYTE-EQ GATE (H=%d) =================\n",H);

        const int NW=4; int shard=B_GLOBAL/NW;
        std::vector<std::vector<double>> gloc(NW, std::vector<double>(L.NPARAM,0.0));
        std::vector<double> lloc(NW,0.0);
        for (int r=0;r<NW;r++) lloc[r]=fwd_bwd_accum_host(Winit.data(),X.data(),Y.data(),r*shard,(r+1)*shard,gloc[r].data(),L,H);
        std::vector<double> g_ref, W_ref=Winit;
        // reference reduces each element in the ring's per-chunk order (so the
        // gate is a true max|delta|=0, matching the device ring's associativity).
        ref_grad_ring_order(gloc, NW, L.NPARAM, g_ref);
        for (int p=0;p<L.NPARAM;p++) g_ref[p] /= (double)B_GLOBAL;
        double loss_ref=lloc[0]; for(int r=1;r<NW;r++) loss_ref+=lloc[r]; loss_ref/=(double)B_GLOBAL;
        sgd_step(W_ref.data(),g_ref.data(),L.NPARAM);

        std::vector<double*> d(NW,nullptr), stg(NW,nullptr);
        for (int r=0;r<NW;r++){ CK(cudaSetDevice(dev4[r])); CK(cudaMalloc(&d[r],(size_t)L.NPARAM*sizeof(double))); CK(cudaMalloc(&stg[r],(size_t)L.NPARAM*sizeof(double))); CK(cudaMemcpy(d[r],gloc[r].data(),(size_t)L.NPARAM*sizeof(double),cudaMemcpyHostToDevice)); }
        ring_all_reduce_sum(d,stg,dev4,NW,L.NPARAM);
        std::vector<std::vector<double>> W_ddp(NW,Winit);
        std::vector<std::vector<double>> g_sum(NW,std::vector<double>(L.NPARAM));
        for (int r=0;r<NW;r++){ CK(cudaSetDevice(dev4[r])); CK(cudaMemcpy(g_sum[r].data(),d[r],(size_t)L.NPARAM*sizeof(double),cudaMemcpyDeviceToHost)); for(int p=0;p<L.NPARAM;p++) g_sum[r][p]/=(double)B_GLOBAL; sgd_step(W_ddp[r].data(),g_sum[r].data(),L.NPARAM); }
        double rank_dis=0.0; for(int r=1;r<NW;r++) for(int p=0;p<L.NPARAM;p++){ double dd=fabs(W_ddp[r][p]-W_ddp[0][p]); if(dd>rank_dis)rank_dis=dd; }
        double w_diff=0.0; for(int p=0;p<L.NPARAM;p++){ double dd=fabs(W_ddp[0][p]-W_ref[p]); if(dd>w_diff)w_diff=dd; }
        double g_diff=0.0; for(int p=0;p<L.NPARAM;p++){ double dd=fabs(g_sum[0][p]-g_ref[p]); if(dd>g_diff)g_diff=dd; }
        for (int r=0;r<NW;r++){ CK(cudaSetDevice(dev4[r])); CK(cudaFree(d[r])); CK(cudaFree(stg[r])); }

        printf("loss_ref (mean)            = %.17g\n",loss_ref);
        printf("grad  g_ddp vs g_ref  max|delta| = %.17g  %s\n",g_diff, g_diff==0.0?"BYTE-EQ":"MISMATCH");
        printf("rank-agreement (Wr==W0) max|delta| = %.17g  %s\n",rank_dis, rank_dis==0.0?"ALL RANKS IDENTICAL":"RANK DISAGREE");
        printf("WEIGHTS W_ddp vs W_ref  max|delta| = %.17g  %s\n",w_diff, w_diff==0.0?"BYTE-EQ PASS":"FAIL");
        worst_byteeq = w_diff; if(g_diff>worst_byteeq)worst_byteeq=g_diff; if(rank_dis>worst_byteeq)worst_byteeq=rank_dis;
        byteeq_fail = (w_diff!=0.0||g_diff!=0.0||rank_dis!=0.0);
        if (byteeq_fail) overall_green=0;
    }

    printf("\n================= DDP-M5c VERDICT =================\n");
    printf("byte-eq (N=4, H=%d): max|delta| = %.17g  %s\n",H_for_gate,worst_byteeq, byteeq_fail?"FAIL":"BYTE-EQ PASS");
    if (crossover2_H>=0) printf("crossover: 2-GPU speedup > 1.0x FIRST at H=%d (2-GPU beats 1-GPU there)\n",crossover2_H);
    else printf("crossover: 2-GPU speedup never exceeded 1.0x across swept H (comm-bound on this %s transport)\n", p2p_any?"P2P":"host-staged");
    if (crossover_H>=0) printf("crossover: 4-GPU speedup > 1.0x FIRST at H=%d (4-GPU beats 1-GPU there)\n",crossover_H);
    else printf("crossover: 4-GPU speedup never exceeded 1.0x across swept H (comm-bound on this %s transport)\n", p2p_any?"P2P":"host-staged");
    printf("transport: %s   P2P-any=%d (NVLink/direct-P2P active on >=1 pair => %s)\n", transport, p2p_any, p2p_any?"YES":"NO (staged-host)");
    printf("=== DDP-M5c: %s ===\n", overall_green? "GREEN - {1,2,4}-GPU DDP train byte-eq + crossover swept" : "RED");
    return overall_green?0:1;
}
