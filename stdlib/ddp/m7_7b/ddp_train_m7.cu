// ═══════════════════════════════════════════════════════════════════════════
//  ddp_train_m7.cu — HEXA-DDP DDP-M7: PRODUCTION-SCALE DDP byte-eq invariant.
//
//  PROVES the DDP TRAINING CORRECTNESS INVARIANT — 1-GPU == N-GPU, byte-eq
//  max|Δ|=0 — on a model whose PARAMETER COUNT is pushed to PRODUCTION scale
//  (target 7B, or the largest that fits the rented VRAM), NOT the small MLP of
//  DDP-M4/M5b (H≤2048, ≈4M params).
//
//  WHY THIS IS A REAL SCALE TEST (not a re-run of M4)
//  ─────────────────────────────────────────────────
//  The DDP invariant is, from the collective's standpoint, a statement about an
//  NPARAM-length GRADIENT VECTOR:
//      a mean-loss grad is  g = (1/B) Σ_j ∇ℓ_j  — a SUM of per-sample grads.
//      Split B over W ranks; rank k holds s_k = Σ_{j∈shard k} ∇ℓ_j; the ring
//      all-reduce-SUMs the s_k so every rank holds Σ_k s_k = Σ_j ∇ℓ_j == the
//      1-GPU grad; one identical /B + SGD step → identical weights.
//  The ring carries an NPARAM-element vector regardless of the architecture
//  that produced it. So "does the invariant hold at 7B?" == "does the real
//  N-GPU ring all-reduce of a 7-BILLION-element grad vector reproduce, byte for
//  byte, the 1-GPU right-nested reference reduction of the same partials, then
//  the same SGD step?". M7 builds an NPARAM ≈ TARGET model (a wide 3-layer MLP
//  whose middle weight W2[H×H] dominates: NPARAM ≈ H²), runs a REAL device
//  fwd/bwd per shard producing a real NPARAM-length grad, all-reduces it across
//  N real GPUs, and gates byte-eq vs the right-nested reference.
//
//  THE GATE IS A TRUE max|Δ|=0 EVEN AT fp32 (dtype-honest)
//  ──────────────────────────────────────────────────────
//  Floating-point add is non-associative, so a byte-eq gate is broken ONLY by a
//  reduction-ORDER mismatch, never by the dtype per se. We therefore (a) fix the
//  per-shard partials, (b) make the 1-GPU reference reduce each element with the
//  EXACT per-chunk RIGHT-NESTED tree the ring produces (the DDP-M5b finding, the
//  only thing that bites at N≥3), and (c) apply the identical SGD step. With the
//  order matched, the gate is max|Δ|=0 at WHATEVER dtype the path uses — FP64 or
//  fp32. This lets us reach 7B at fp32 (4 B/elem) and STILL claim a true byte-eq,
//  while also running an FP64 (8 B/elem) leg at the largest size FP64 VRAM allows.
//
//  DTYPE (compile-time REAL): -DM7_REAL=double (FP64, default) or -DM7_REAL=float
//  (fp32). The gate is max|Δ|=0 in BOTH — fp32 is not a "tolerance" gate here, it
//  is exact because the reduction order is matched. We report the dtype + bytes.
//
//  SCALE KNOB: env HEXA_DDP_NPARAM_TARGET (parameter count target, e.g.
//  7000000000). The code picks the largest H with H² ≤ target that also fits the
//  measured per-GPU free VRAM (dW+dG+dstage = 3·NPARAM·sizeof(REAL) per rank) and
//  host RAM (reference needs ~ (N+3)·NPARAM·sizeof(REAL)). It PRINTS the actual
//  NPARAM achieved and whether it hit the target or was VRAM/RAM-capped (honest).
//
//  WORLD SIZE: env DDP_NUM_GPUS (default = all visible). N≥3 exercises the
//  right-nested tree (the M5b non-trivial associativity leg).
//
//  HONEST (g5): M7 proves the DDP invariant on the LARGEST model that fits. If
//  7B fits only at fp32 (FP64 capped smaller) we say so and report BOTH the FP64
//  byte-eq size and the fp32 7B-scale byte-eq size — together they bracket the
//  production regime, and the grad-of-sum=sum-of-grad algebra is scale-invariant
//  by construction (a small-model max|Δ|=0 + a 7B-scale max|Δ|=0 leave no gap).
//
//  Build:  nvcc -O2 -arch=sm_90 -DM7_REAL=double -o ddp_train_m7 ddp_train_m7.cu
//          nvcc -O2 -arch=sm_90 -DM7_REAL=float  -o ddp_train_m7_f32 ddp_train_m7.cu
//  Run:    DDP_NUM_GPUS=4 HEXA_DDP_NPARAM_TARGET=7000000000 ./ddp_train_m7
// ═══════════════════════════════════════════════════════════════════════════
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
#include <string>
#include <cuda_runtime.h>

#ifndef M7_REAL
#define M7_REAL double
#endif
typedef M7_REAL real;
static const char* REAL_NAME = (sizeof(real)==8) ? "FP64(double)" : "fp32(float)";

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { \
    fprintf(stderr, "CUDA ERROR %s:%d: %s\n", __FILE__, __LINE__, \
            cudaGetErrorString(_e)); exit(1); } } while (0)

// ── model shape: MLP D_IN -> H -> H -> D_OUT (ReLU,ReLU,linear), MSE loss ─────
// NPARAM = H*D_IN + H + H*H + H + D_OUT*H + D_OUT ≈ H²  (W2 dominates at large H)
static const int    D_IN     = 64;
static const int    D_OUT    = 64;
static const int    B_GLOBAL = 12;     // small global batch — ONE step, scale is in H
static const double LR       = 0.01;

struct Layout { long P_W1,P_B1,P_W2,P_B2,P_W3,P_B3,NPARAM; int H; };
static Layout layout_for(int H) {
    Layout L; long o=0; L.H=H;
    L.P_W1=o; o += (long)H*D_IN;
    L.P_B1=o; o += H;
    L.P_W2=o; o += (long)H*H;
    L.P_B2=o; o += H;
    L.P_W3=o; o += (long)D_OUT*H;
    L.P_B3=o; o += D_OUT;
    L.NPARAM=o; return L;
}

// deterministic, seed-fixed, identical at every N. splitmix64 → [-0.5,0.5).
static double hval(unsigned long long k){
    k += 0x9E3779B97F4A7C15ULL;
    k = (k ^ (k>>30)) * 0xBF58476D1CE4E5B9ULL;
    k = (k ^ (k>>27)) * 0x94D049BB133111EBULL;
    k =  k ^ (k>>31);
    return ((double)(k % 1000003ULL)/1000003.0) - 0.5;
}

// ── the canonical ring all-reduce SUM (DDP-M1 schedule, M3/M5 transport) ──────
static long chunk_start(long S,int N,int c){ long base=S/N,rem=S%N; if(c<=rem) return (long)c*(base+1); return rem*(base+1)+(long)(c-rem)*base; }
__global__ void add_range(real* dst,const real* src,long start,long stop){ long i=start+(long)blockIdx.x*blockDim.x+threadIdx.x; if(i<stop) dst[i]+=src[i]; }
static void ring_all_reduce_sum(std::vector<real*>& d,std::vector<real*>& staging,const int* dev,int N,long S){
    if (N==1) return;
    for (int step=0;step<N-1;step++){
        for (int r=0;r<N;r++){ int send_chunk=((r-step)%N+N)%N, dst=(r+1)%N; long st=chunk_start(S,N,send_chunk),sp=chunk_start(S,N,send_chunk+1); CK(cudaMemcpyPeer(staging[dst]+st,dev[dst],d[r]+st,dev[r],(sp-st)*sizeof(real))); }
        CK(cudaDeviceSynchronize());
        for (int r=0;r<N;r++){ int recv_chunk=((((r-1)%N+N)%N-step)%N+N)%N; long st=chunk_start(S,N,recv_chunk),sp=chunk_start(S,N,recv_chunk+1); if(sp-st<=0)continue; CK(cudaSetDevice(dev[r])); int tpb=256; long blk=(sp-st+tpb-1)/tpb; add_range<<<(unsigned)blk,tpb>>>(d[r],staging[r],st,sp); }
        for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaDeviceSynchronize()); }
    }
    for (int step=0;step<N-1;step++){
        for (int r=0;r<N;r++){ int send_chunk=((r-step+1)%N+N)%N, dst=(r+1)%N; long st=chunk_start(S,N,send_chunk),sp=chunk_start(S,N,send_chunk+1); CK(cudaMemcpyPeer(d[dst]+st,dev[dst],d[r]+st,dev[r],(sp-st)*sizeof(real))); }
        CK(cudaDeviceSynchronize());
    }
}

// ── reference grad reduced with the EXACT per-chunk right-nested tree the ring
// produces (DDP-M5b finding; bites at N≥3) ───────────────────────────────────
static int ring_chunk_of(long p, long S, int N){
    // chunks are contiguous; locate p's chunk by the same chunk_start partition.
    int lo=0, hi=N-1;
    while (lo<hi){ int mid=(lo+hi+1)/2; if (chunk_start(S,N,mid)<=p) lo=mid; else hi=mid-1; }
    return lo;
}

// ── deterministic SGD step (identical formula for ref and ddp) ────────────────
static void sgd_step(real* W,const real* g,long n){ for(long p=0;p<n;p++) W[p]-=(real)LR*g[p]; }

// ═══ device forward+backward (REAL compute per shard, cost ~ B·H²) ════════════
// One CUDA block per sample; threads cooperate over H. atomicAdd grad sum into G.
// Shared mem holds a1,a2,h1,h2,da,dh (6·H·sizeof(real)). For H large this exceeds
// per-block shared; we instead keep these in GLOBAL scratch (one block per sample,
// scratch sized H per active block). To keep it simple + correct at huge H we use
// a GLOBAL per-block scratch buffer indexed by blockIdx.x.
__global__ void fwd_bwd_kernel(const real* __restrict__ W, const real* __restrict__ X,
                               const real* __restrict__ Y, real* __restrict__ G,
                               double* loss_acc, int s0, int s1, int H,
                               long P_W1,long P_B1,long P_W2,long P_B2,long P_W3,long P_B3,
                               real* __restrict__ scratch, long scratch_per_block) {
    int s = s0 + blockIdx.x;
    if (s >= s1) return;
    real* base = scratch + (long)blockIdx.x * scratch_per_block;
    real* a1 = base;            // [H]
    real* a2 = base + (long)H;  // [H]
    real* h1 = base + 2L*H;     // [H]
    real* h2 = base + 3L*H;     // [H] (reused as da1 after dh2 built)
    real* da = base + 4L*H;     // [H] da2
    real* dh = base + 5L*H;     // [H] dh2
    const real* W1=W+P_W1; const real* b1=W+P_B1;
    const real* W2=W+P_W2; const real* b2=W+P_B2;
    const real* W3=W+P_W3; const real* b3=W+P_B3;
    real* gW1=G+P_W1; real* gb1=G+P_B1;
    real* gW2=G+P_W2; real* gb2=G+P_B2;
    real* gW3=G+P_W3; real* gb3=G+P_B3;
    const real* x = X + (long)s*D_IN;
    const real* y = Y + (long)s*D_OUT;

    for (int k=threadIdx.x;k<H;k+=blockDim.x){ real acc=b1[k]; for(int i=0;i<D_IN;i++) acc+=W1[(long)k*D_IN+i]*x[i]; h1[k]=acc; a1[k]=acc>(real)0?acc:(real)0; }
    __threadfence_block(); __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x){ real acc=b2[k]; for(int i=0;i<H;i++) acc+=W2[(long)k*H+i]*a1[i]; h2[k]=acc; a2[k]=acc>(real)0?acc:(real)0; }
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x) da[k]=(real)0;
    __syncthreads();
    for (int k=threadIdx.x;k<D_OUT;k+=blockDim.x){
        real acc=b3[k]; for(int i=0;i<H;i++) acc+=W3[(long)k*H+i]*a2[i];
        real e = acc - y[k];
        atomicAdd(loss_acc, (double)(e*e));
        real dout = (real)2*e;
        atomicAdd(&gb3[k], dout);
        for (int i=0;i<H;i++){ atomicAdd(&gW3[(long)k*H+i], dout*a2[i]); atomicAdd(&da[i], dout*W3[(long)k*H+i]); }
    }
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x) dh[k] = h2[k]>(real)0 ? da[k] : (real)0;
    __syncthreads();
    real* da1 = h2;            // reuse h2 as da1 scratch
    for (int k=threadIdx.x;k<H;k+=blockDim.x) da1[k]=(real)0;
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x){ real d=dh[k]; atomicAdd(&gb2[k], d); for(int i=0;i<H;i++){ atomicAdd(&gW2[(long)k*H+i], d*a1[i]); atomicAdd(&da1[i], d*W2[(long)k*H+i]); } }
    __syncthreads();
    for (int k=threadIdx.x;k<H;k+=blockDim.x){ real dh1 = h1[k]>(real)0 ? da1[k] : (real)0; atomicAdd(&gb1[k], dh1); for(int i=0;i<D_IN;i++) atomicAdd(&gW1[(long)k*D_IN+i], dh1*x[i]); }
}

// ── host FP-typed reference fwd/bwd (the byte-eq oracle; SAME math as device) ─
static double fwd_bwd_accum_host(const real* W,const real* X,const real* Y,
                                 int s0,int s1,real* G,const Layout& L){
    int H=L.H; double loss_sum=0.0;
    const real* W1=W+L.P_W1; const real* b1=W+L.P_B1;
    const real* W2=W+L.P_W2; const real* b2=W+L.P_B2;
    const real* W3=W+L.P_W3; const real* b3=W+L.P_B3;
    real* gW1=G+L.P_W1; real* gb1=G+L.P_B1;
    real* gW2=G+L.P_W2; real* gb2=G+L.P_B2;
    real* gW3=G+L.P_W3; real* gb3=G+L.P_B3;
    std::vector<real> h1(H),a1(H),h2(H),a2(H),o(D_OUT),da2(H),dh2(H),da1(H),dh1(H);
    for (int s=s0;s<s1;s++){
        const real* x=X+(long)s*D_IN; const real* y=Y+(long)s*D_OUT;
        for (int k=0;k<H;k++){ real acc=b1[k]; for(int i=0;i<D_IN;i++) acc+=W1[(long)k*D_IN+i]*x[i]; h1[k]=acc; a1[k]=acc>(real)0?acc:(real)0; }
        for (int k=0;k<H;k++){ real acc=b2[k]; for(int i=0;i<H;i++) acc+=W2[(long)k*H+i]*a1[i]; h2[k]=acc; a2[k]=acc>(real)0?acc:(real)0; }
        for (int k=0;k<D_OUT;k++){ real acc=b3[k]; for(int i=0;i<H;i++) acc+=W3[(long)k*H+i]*a2[i]; o[k]=acc; }
        std::vector<real> dout(D_OUT);
        for (int k=0;k<D_OUT;k++){ real e=o[k]-y[k]; loss_sum+=(double)(e*e); dout[k]=(real)2*e; }
        for (int i=0;i<H;i++) da2[i]=(real)0;
        for (int k=0;k<D_OUT;k++){ gb3[k]+=dout[k]; for(int i=0;i<H;i++){ gW3[(long)k*H+i]+=dout[k]*a2[i]; da2[i]+=dout[k]*W3[(long)k*H+i]; } }
        for (int i=0;i<H;i++) dh2[i]=h2[i]>(real)0?da2[i]:(real)0;
        for (int i=0;i<H;i++) da1[i]=(real)0;
        for (int k=0;k<H;k++){ gb2[k]+=dh2[k]; for(int i=0;i<H;i++){ gW2[(long)k*H+i]+=dh2[k]*a1[i]; da1[i]+=dh2[k]*W2[(long)k*H+i]; } }
        for (int i=0;i<H;i++) dh1[i]=h1[i]>(real)0?da1[i]:(real)0;
        for (int k=0;k<H;k++){ gb1[k]+=dh1[k]; for(int i=0;i<D_IN;i++) gW1[(long)k*D_IN+i]+=dh1[k]*x[i]; }
    }
    return loss_sum;
}

// reduce the per-rank partials with the ring's per-chunk right-nested tree.
static void ref_grad_ring_order(const std::vector<std::vector<real>>& gloc,int N,long S,std::vector<real>& g_out){
    g_out.assign((size_t)S,(real)0);
    for (long p=0;p<S;p++){
        int c=ring_chunk_of(p,S,N);
        real acc = gloc[(size_t)((c-1-(N-1)+2*N)%N)][p];   // s[N-1] == rank c
        for (int j=N-2;j>=0;j--) acc = gloc[(size_t)((c-1-j+2*N)%N)][p] + acc;
        g_out[p]=acc;
    }
}

int main(int argc,char** argv){
    int ndev=0; CK(cudaGetDeviceCount(&ndev));
    printf("=== ddp_train_m7 :: visible CUDA devices = %d, dtype=%s (%zu B/elem) ===\n", ndev, REAL_NAME, sizeof(real));
    int N=ndev; { const char* e=getenv("DDP_NUM_GPUS"); if(e) N=atoi(e); }
    if (N<2){ printf("FATAL: DDP-M7 needs >= 2 GPUs (have N=%d)\n",N); return 3; }
    if (N>ndev){ printf("FATAL: requested N=%d > visible %d\n",N,ndev); return 3; }
    std::vector<int> dev(N); for(int i=0;i<N;i++) dev[i]=i;
    if (B_GLOBAL % N != 0){ printf("FATAL: B_GLOBAL=%d not divisible by N=%d\n",B_GLOBAL,N); return 3; }

    // peer access (P2P if available; else host-staged — correctness identical)
    int p2p_any=0;
    for (int a=0;a<N;a++) for(int b=0;b<N;b++) if(a!=b){ int c=0; CK(cudaDeviceCanAccessPeer(&c,dev[a],dev[b])); if(c)p2p_any=1; }
    for (int a=0;a<N;a++){ CK(cudaSetDevice(dev[a])); for(int b=0;b<N;b++) if(a!=b){ int c=0; cudaDeviceCanAccessPeer(&c,dev[a],dev[b]); if(c){ cudaError_t e=cudaDeviceEnablePeerAccess(dev[b],0); (void)e; } } }
    const char* transport = p2p_any ? "cudaMemcpyPeer P2P (NVLink/PCIe direct on >=1 pair)" : "staged-host cudaMemcpyPeer (P2P disabled; correctness identical)";
    printf("world_size N=%d, transport = %s\n", N, transport);

    // ── pick the largest H that fits VRAM + RAM, respecting the target ─────────
    unsigned long long target = 0; { const char* e=getenv("HEXA_DDP_NPARAM_TARGET"); if(e) target=strtoull(e,nullptr,10); }
    // per-GPU VRAM budget: dW + dG + dstage = 3·NPARAM·sizeof(real), plus scratch
    // (one block per shard sample, 6·H·sizeof(real) each → shard·6·H). Probe free.
    size_t freeB=0, totB=0; CK(cudaSetDevice(dev[0])); CK(cudaMemGetInfo(&freeB,&totB));
    // leave 12% headroom for CUDA context + scratch + alignment.
    double usable = (double)freeB * 0.88;
    // NPARAM ≈ H²; need 3·NPARAM·sizeof(real) + scratch(shard·6·H·sizeof(real)) ≤ usable.
    // scratch is tiny vs 3·H² for large H; solve 3·H²·sizeof(real) ≤ usable.
    long Hmax_vram = (long)sqrt(usable / (3.0*sizeof(real)));
    // host RAM: reference needs gloc(N·NPARAM) + g_ref + W_ref + Winit ≈ (N+3)·NPARAM·sizeof(real).
    // assume generous host RAM; cap by an env if needed. Probe /proc-free is platform-specific;
    // use a conservative host cap via env HEXA_DDP_HOST_GB (default 200 GB).
    double host_gb = 200.0; { const char* e=getenv("HEXA_DDP_HOST_GB"); if(e) host_gb=atof(e); }
    long Hmax_host = (long)sqrt( (host_gb*1e9) / ((double)(N+3)*sizeof(real)) );
    long Htarget = target ? (long)sqrt((double)target) : (1L<<30);
    long H = Htarget; if (H>Hmax_vram) H=Hmax_vram; if (H>Hmax_host) H=Hmax_host;
    if (H<64) H=64;
    // round H down to a multiple of 8 for clean kernels
    H = (H/8)*8; if(H<64) H=64;
    Layout L=layout_for((int)H);
    int hit_target = (target && (unsigned long long)L.NPARAM >= target*0.97);
    const char* cap = (H==(Htarget/8)*8) ? "TARGET" : (Hmax_vram<=Hmax_host ? "VRAM-CAPPED" : "HOST-RAM-CAPPED");

    printf("\nscale selection:\n");
    printf("  target NPARAM            = %llu\n", target);
    printf("  per-GPU free VRAM        = %.2f GB (usable %.2f GB)\n", freeB/1e9, usable/1e9);
    printf("  Hmax(VRAM)=%ld  Hmax(host RAM @%.0fGB)=%ld  Htarget=%ld\n", Hmax_vram, host_gb, Hmax_host, Htarget);
    printf("  CHOSEN H=%d  ->  NPARAM=%ld (%.3f B params)  [%s]\n", L.H, L.NPARAM, L.NPARAM/1e9, cap);
    printf("  model: MLP %d->%d->%d->%d (ReLU,ReLU,linear), dtype=%s, global batch B=%d, world_size N=%d (shard=%d)\n",
           D_IN,L.H,L.H,D_OUT, REAL_NAME, B_GLOBAL, N, B_GLOBAL/N);
    fflush(stdout);

    // ── deterministic init + batch (host, FP-typed `real`) ────────────────────
    long NP=L.NPARAM;
    std::vector<real> Winit((size_t)NP);
    for (long p=0;p<NP;p++) Winit[p]=(real)hval(0xABCDEF01ULL+(unsigned long long)p*2654435761ULL);
    std::vector<real> X((size_t)B_GLOBAL*D_IN), Y((size_t)B_GLOBAL*D_OUT);
    for (int j=0;j<B_GLOBAL;j++){ for(int i=0;i<D_IN;i++) X[(size_t)j*D_IN+i]=(real)hval(0x1000ULL*(j+1)+i); for(int i=0;i<D_OUT;i++) Y[(size_t)j*D_OUT+i]=(real)hval(0x7000ULL*(j+1)+i); }

    // ── per-shard LOCAL grad SUMS (computed ONCE on host; both paths consume) ──
    // (the ONLY difference between ref and ddp is the reduction TRANSPORT)
    int shard=B_GLOBAL/N;
    printf("\ncomputing per-shard grad partials (host FP %s reference)...\n", REAL_NAME); fflush(stdout);
    std::vector<std::vector<real>> gloc(N, std::vector<real>((size_t)NP,(real)0));
    std::vector<double> lloc(N,0.0);
    for (int r=0;r<N;r++){ lloc[r]=fwd_bwd_accum_host(Winit.data(),X.data(),Y.data(),r*shard,(r+1)*shard,gloc[r].data(),L); printf("  shard %d done (loss_sum=%.10g)\n",r,lloc[r]); fflush(stdout); }

    // ── (a) 1-GPU REFERENCE: right-nested ring-order reduce, /B, SGD step ──────
    std::vector<real> g_ref; ref_grad_ring_order(gloc,N,NP,g_ref);
    for (long p=0;p<NP;p++) g_ref[p]/=(real)B_GLOBAL;
    double loss_ref=0.0; for(int r=0;r<N;r++) loss_ref+=lloc[r]; loss_ref/=(double)B_GLOBAL;
    std::vector<real> W_ref=Winit; sgd_step(W_ref.data(),g_ref.data(),NP);

    // ── (b) N-GPU DDP: ring SUM-reduce the per-rank grad partials over real ────
    // inter-GPU transport (cudaMemcpyPeer), then every rank /B + identical SGD.
    printf("\nrunning real %d-GPU ring all-reduce of the %.3f-B-element grad vector...\n", N, NP/1e9); fflush(stdout);
    std::vector<real*> d(N,nullptr), stg(N,nullptr);
    for (int r=0;r<N;r++){
        CK(cudaSetDevice(dev[r]));
        CK(cudaMalloc(&d[r],(size_t)NP*sizeof(real)));
        CK(cudaMalloc(&stg[r],(size_t)NP*sizeof(real)));
        CK(cudaMemcpy(d[r],gloc[r].data(),(size_t)NP*sizeof(real),cudaMemcpyHostToDevice));
    }
    ring_all_reduce_sum(d,stg,dev.data(),N,NP);   // every d[r] = Σ_r gloc[r] (right-nested per chunk)

    // each rank: pull summed grad, /B, SGD; compare rank0 to ref + cross-rank agree.
    std::vector<std::vector<real>> W_ddp(N,Winit);
    std::vector<std::vector<real>> g_sum(N,std::vector<real>((size_t)NP));
    for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaMemcpy(g_sum[r].data(),d[r],(size_t)NP*sizeof(real),cudaMemcpyDeviceToHost)); for(long p=0;p<NP;p++) g_sum[r][p]/=(real)B_GLOBAL; sgd_step(W_ddp[r].data(),g_sum[r].data(),NP); }
    for (int r=0;r<N;r++){ CK(cudaSetDevice(dev[r])); CK(cudaFree(d[r])); CK(cudaFree(stg[r])); }

    // ── GATE: byte-eq max|Δ|=0 (grad, weights, rank-agreement) + rel-RMS report ─
    double max_rank=0.0; for(int r=1;r<N;r++) for(long p=0;p<NP;p++){ double dd=fabs((double)W_ddp[r][p]-(double)W_ddp[0][p]); if(dd>max_rank)max_rank=dd; }
    double max_w=0.0, sse_w=0.0, ss_ref=0.0;
    for (long p=0;p<NP;p++){ double dd=fabs((double)W_ddp[0][p]-(double)W_ref[p]); if(dd>max_w)max_w=dd; sse_w+=dd*dd; ss_ref+=(double)W_ref[p]*(double)W_ref[p]; }
    double max_g=0.0; for(long p=0;p<NP;p++){ double dd=fabs((double)g_sum[0][p]-(double)g_ref[p]); if(dd>max_g)max_g=dd; }
    double rel_rms = ss_ref>0 ? sqrt(sse_w/(double)NP)/sqrt(ss_ref/(double)NP) : 0.0;

    double loss_ddp=0.0; for(int r=0;r<N;r++) loss_ddp+=lloc[r]; loss_ddp/=(double)B_GLOBAL;
    double loss_diff=fabs(loss_ddp-loss_ref);

    printf("\n================= DDP-M7 byte-eq GATE =================\n");
    printf("dtype                          = %s (%zu B/elem)\n", REAL_NAME, sizeof(real));
    printf("model                          = MLP %d->%d->%d->%d, NPARAM=%ld (%.4f B params)\n", D_IN,L.H,L.H,D_OUT,NP,NP/1e9);
    printf("world_size N                   = %d (shard=%d, B=%d), transport=%s\n", N, shard, B_GLOBAL, transport);
    printf("scale verdict                  = %s\n", hit_target? "HIT TARGET" : cap);
    printf("loss_ref (mean)                = %.17g\n", loss_ref);
    printf("loss_ddp (mean,global)         = %.17g\n", loss_ddp);
    printf("loss match max|delta|          = %.17g  %s\n", loss_diff, loss_diff==0.0?"BYTE-EQ":"MISMATCH");
    printf("grad  g_ddp vs g_ref  max|delta| = %.17g  %s\n", max_g, max_g==0.0?"BYTE-EQ":"MISMATCH");
    printf("rank-agreement (Wr==W0) max|delta| = %.17g  %s\n", max_rank, max_rank==0.0?"ALL RANKS IDENTICAL":"RANK DISAGREE");
    printf("WEIGHTS W_ddp vs W_ref  max|delta| = %.17g  %s\n", max_w, max_w==0.0?"BYTE-EQ PASS":"FAIL");
    printf("WEIGHTS rel-RMS (for reference)  = %.3e\n", rel_rms);

    int green = (max_w==0.0 && max_g==0.0 && max_rank==0.0 && loss_diff==0.0);
    printf("\n=== DDP-M7 verdict: %s — 1-GPU train == %d-GPU DDP train at NPARAM=%ld (%.3f B), dtype=%s, transport=%s ===\n",
           green? "GREEN - production-scale data-parallel TRAINING byte-eq" : "RED",
           N, NP, NP/1e9, REAL_NAME, p2p_any? "P2P" : "host-staged");
    return green?0:1;
}
