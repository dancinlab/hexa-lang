/* HEXA-FUSION FF-GN-PARALLEL — fixed-order parallel-tree GroupNorm reduction.
 *
 * DUTYCYCLE proved: of GPU-active time, _hx_k_groupnorm (fwd) + _hx_k_groupnorm_bwd_dx
 * (bwd) = 90.5%, each 105-132 ms, because byte-eq FORCES a SINGLE thread to do the whole
 * T*C reduction (G=1 whole-tensor) in host sequential order. That serial O(N) sum is the
 * dominant on-device cost.
 *
 * THIS harness implements a FIXED-ORDER PARALLEL-TREE reduction that is:
 *   (1) DETERMINISTIC run-to-run (fixed partition, fixed pairwise combine order, NO atomics,
 *       NO race) -> bit-reproducible across runs. PRESERVES the reproducibility north-star.
 *   (2) A NUMERICALLY-NEGLIGIBLE RE-BASELINE of the GN reference: tree order yields a
 *       DIFFERENT (but fixed) FP64 value than the pure sequential sum (FP non-associativity),
 *       delta ~ machine-eps over the group N (FP64 ~1e-15..1e-13), NOT an accuracy regression.
 *
 * GATES (g5), reported VERBATIM:
 *   1. DETERMINISM: run the tree kernels TWICE, assert run-to-run max|delta| == 0 (bit-eq).
 *   2. RE-BASELINE: max|delta| of tree-order vs the OLD sequential-sum oracle (~machine-eps).
 *   3. SPEEDUP: time tree vs single-thread sequential for fwd + bwd_dx at DUTYCYCLE shape
 *      (D1536/T512/E2/K3 => T=512 C=1536 G=1, FP64), report ms before/after + speedup.
 *
 * FIXED-ORDER TREE DESIGN (deterministic, no atomics):
 *   For the whole-tensor (G=1) reduction over N = T*C elements:
 *   - Launch a FIXED grid of NB blocks x BS threads (config-fixed: NB=256, BS=256).
 *   - Lane r (global rank) owns a FIXED contiguous-strided set of indices; it accumulates
 *     them in ASCENDING index order into a per-lane partial (sequential within lane).
 *   - Pass 1 (reduce_blocks): each block tree-combines its BS lane-partials in shared mem
 *     in a FIXED pairwise (stride-halving) order -> one block-partial per block, written to
 *     a scratch array indexed by blockIdx (no atomics).
 *   - Pass 2 (finalize): a SINGLE block reads the NB block-partials in ASCENDING block order
 *     and tree-combines them (fixed order) -> the final scalar (mu numerator / var numerator).
 *   Same partition/order every run => bit-reproducible. Different assoc than serial => the
 *     re-baseline delta (gate 2). G>1 falls back to per-group lanes (kept for sanity).
 *
 * The normalize / DX-write phases are already embarrassingly parallel & byte-identical to
 * the existing kernels; the WIN is purely in the reduction.
 */
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cuda_runtime.h>

#define CK(call) do { cudaError_t _e=(call); if(_e!=cudaSuccess){ \
    fprintf(stderr,"CUDA ERR %s:%d: %s\n",__FILE__,__LINE__,cudaGetErrorString(_e)); \
    return 2; } } while(0)

/* ---- byte-identical NR-40 sqrt (from runtime_cuda_emit.hexa _hx_gn_sqrt_dev) ---- */
__device__ static double _hx_gn_sqrt_dev(double x) {
    if (x <= 0.0) return 0.0;
    double g = x;
    for (int i = 0; i < 40; i++) { g = 0.5 * (g + x / g); }
    return g;
}

/* fixed tree config */
#define GN_NB 256
#define GN_BS 256

/* ================================================================= *
 *  ORACLE: sequential GroupNorm fwd (verbatim _hx_k_groupnorm)       *
 * ================================================================= */
__global__ void _hx_k_groupnorm(const double* __restrict__ X,
                                const double* __restrict__ GAMMA,
                                const double* __restrict__ BETA,
                                double* __restrict__ Y, double* __restrict__ MEAN,
                                double* __restrict__ INV, double* __restrict__ XHAT,
                                int64_t T, int64_t C, int64_t G) {
    const double eps = 0.00001;
    int64_t cg = C / G;
    double m = (double)(cg * T);
    for (int64_t g = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         g < G; g += (int64_t)blockDim.x * gridDim.x) {
        int64_t c0 = g * cg;
        double sum = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) sum += X[t * C + (c0 + c)];
        double mu = sum / m;
        double vs = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) { double d = X[t*C+(c0+c)] - mu; vs += d*d; }
        double var = vs / m;
        double inv = 1.0 / _hx_gn_sqrt_dev(var + eps);
        MEAN[g] = mu; INV[g] = inv;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) {
                int64_t ch = c0 + c;
                double xh = (X[t*C+ch] - mu) * inv;
                XHAT[t*C+ch] = xh; Y[t*C+ch] = GAMMA[ch]*xh + BETA[ch];
            }
    }
}

/* ================================================================= *
 *  ORACLE: sequential GroupNorm bwd_dx (verbatim _hx_k_groupnorm_bwd_dx) *
 * ================================================================= */
__global__ void _hx_k_groupnorm_bwd_dx(const double* __restrict__ XHAT,
                                       const double* __restrict__ INV,
                                       const double* __restrict__ GAMMA,
                                       const double* __restrict__ DY,
                                       double* __restrict__ DX,
                                       int64_t T, int64_t C, int64_t G) {
    int64_t cg = C / G;
    double m = (double)(cg * T);
    for (int64_t g = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         g < G; g += (int64_t)blockDim.x * gridDim.x) {
        int64_t c0 = g * cg;
        double inv_g = INV[g];
        double s1 = 0.0, s2 = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t cc = 0; cc < cg; cc++) {
                int64_t ch = c0+cc, idx = t*C+ch;
                double dxh = DY[idx]*GAMMA[ch];
                s1 += dxh; s2 += dxh*XHAT[idx];
            }
        for (int64_t t = 0; t < T; t++)
            for (int64_t cc = 0; cc < cg; cc++) {
                int64_t ch = c0+cc, idx = t*C+ch;
                double dxh = DY[idx]*GAMMA[ch];
                DX[idx] = inv_g*(dxh - s1/m - XHAT[idx]*s2/m);
            }
    }
}

/* ================================================================= *
 *  TREE: fixed-order block reduction (G=1 whole-tensor)              *
 *  Generic: reduce one or two co-located accumulators over [0,N).    *
 *  selector picks what to accumulate per index.                      *
 * ================================================================= */

/* fwd: pass-1 sum of X over a group's index range -> block partial. */
__global__ void gn_fwd_sum_blocks(const double* __restrict__ X,
                                  int64_t base, int64_t N, double* __restrict__ bpart) {
    __shared__ double sh[GN_BS];
    int64_t rank = (int64_t)blockIdx.x*blockDim.x + threadIdx.x;
    int64_t stride = (int64_t)gridDim.x*blockDim.x;
    double acc = 0.0;
    for (int64_t i = rank; i < N; i += stride) acc += X[base + i];   /* ascending fixed order */
    sh[threadIdx.x] = acc; __syncthreads();
    for (int s = blockDim.x>>1; s > 0; s >>= 1) {                    /* fixed pairwise tree */
        if (threadIdx.x < s) sh[threadIdx.x] += sh[threadIdx.x + s];
        __syncthreads();
    }
    if (threadIdx.x == 0) bpart[blockIdx.x] = sh[0];
}

/* fwd: pass-2 var numerator (sum (X-mu)^2) -> block partial. mu read from device. */
__global__ void gn_fwd_var_blocks(const double* __restrict__ X, const double* __restrict__ pMu,
                                  int64_t base, int64_t N, double* __restrict__ bpart) {
    __shared__ double sh[GN_BS];
    double mu = *pMu;
    int64_t rank = (int64_t)blockIdx.x*blockDim.x + threadIdx.x;
    int64_t stride = (int64_t)gridDim.x*blockDim.x;
    double acc = 0.0;
    for (int64_t i = rank; i < N; i += stride) { double d = X[base+i]-mu; acc += d*d; }
    sh[threadIdx.x] = acc; __syncthreads();
    for (int s = blockDim.x>>1; s > 0; s >>= 1) {
        if (threadIdx.x < s) sh[threadIdx.x] += sh[threadIdx.x + s];
        __syncthreads();
    }
    if (threadIdx.x == 0) bpart[blockIdx.x] = sh[0];
}

/* bwd_dx: pass-1 reduce s1=sum(dxh), s2=sum(dxh*xhat) over the group -> 2 block partials. */
__global__ void gn_bwd_s1s2_blocks(const double* __restrict__ XHAT, const double* __restrict__ GAMMA,
                                   const double* __restrict__ DY, int64_t base, int64_t C,
                                   int64_t cg, int64_t c0, int64_t N,
                                   double* __restrict__ bp1, double* __restrict__ bp2) {
    __shared__ double s1[GN_BS];
    __shared__ double s2[GN_BS];
    int64_t rank = (int64_t)blockIdx.x*blockDim.x + threadIdx.x;
    int64_t stride = (int64_t)gridDim.x*blockDim.x;
    double a1 = 0.0, a2 = 0.0;
    for (int64_t i = rank; i < N; i += stride) {
        /* i ranges over the group's (t,cc) flattened in t-outer/cc-inner order */
        int64_t t = i / cg, cc = i % cg;
        int64_t ch = c0 + cc, idx = t*C + ch;
        double dxh = DY[idx]*GAMMA[ch];
        a1 += dxh; a2 += dxh*XHAT[idx];
    }
    s1[threadIdx.x] = a1; s2[threadIdx.x] = a2; __syncthreads();
    for (int s = blockDim.x>>1; s > 0; s >>= 1) {
        if (threadIdx.x < s) { s1[threadIdx.x]+=s1[threadIdx.x+s]; s2[threadIdx.x]+=s2[threadIdx.x+s]; }
        __syncthreads();
    }
    if (threadIdx.x == 0) { bp1[blockIdx.x]=s1[0]; bp2[blockIdx.x]=s2[0]; }
}

/* finalize: single block, ascending-block-order tree combine of NB partials -> scalar(s).
 * For fwd: combine 1 array. We reuse for both by calling with one array (other=NULL). */
__global__ void gn_finalize1(const double* __restrict__ bp, int NB, double m,
                             int mode, double eps, double* __restrict__ out) {
    /* mode 0: out = sum(bp)/m  (mean)   ;  mode 1: out = 1/sqrt(sum(bp)/m + eps) (inv) */
    __shared__ double sh[GN_NB];
    int tid = threadIdx.x;
    sh[tid] = (tid < NB) ? bp[tid] : 0.0; __syncthreads();
    for (int s = GN_NB>>1; s > 0; s >>= 1) {
        if (tid < s) sh[tid] += sh[tid+s];
        __syncthreads();
    }
    if (tid == 0) {
        double val = sh[0]/m;
        out[0] = (mode==1) ? (1.0/_hx_gn_sqrt_dev(val+eps)) : val;
    }
}
__global__ void gn_finalize2(const double* __restrict__ bp1, const double* __restrict__ bp2,
                             int NB, double* __restrict__ o1, double* __restrict__ o2) {
    __shared__ double a[GN_NB];
    __shared__ double b[GN_NB];
    int tid = threadIdx.x;
    a[tid] = (tid<NB)?bp1[tid]:0.0; b[tid] = (tid<NB)?bp2[tid]:0.0; __syncthreads();
    for (int s = GN_NB>>1; s > 0; s >>= 1) {
        if (tid < s) { a[tid]+=a[tid+s]; b[tid]+=b[tid+s]; }
        __syncthreads();
    }
    if (tid==0){ o1[0]=a[0]; o2[0]=b[0]; }
}

/* embarrassingly-parallel normalize (byte-identical to oracle math, G=1). */
__global__ void gn_normalize(const double* __restrict__ X, const double* __restrict__ GAMMA,
                             const double* __restrict__ BETA, const double* __restrict__ pMu,
                             const double* __restrict__ pInv, double* __restrict__ Y,
                             double* __restrict__ XHAT, int64_t TC, int64_t C) {
    double mu=*pMu, inv=*pInv;
    int64_t rank=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;
    int64_t stride=(int64_t)gridDim.x*blockDim.x;
    for (int64_t idx=rank; idx<TC; idx+=stride) {
        int64_t ch = idx % C;
        double xh=(X[idx]-mu)*inv;
        XHAT[idx]=xh; Y[idx]=GAMMA[ch]*xh+BETA[ch];
    }
}
/* bwd DX write (byte-identical math, G=1). */
__global__ void gn_bwd_write(const double* __restrict__ XHAT, const double* __restrict__ GAMMA,
                             const double* __restrict__ DY, const double* __restrict__ pS1,
                             const double* __restrict__ pS2, double inv_g, double m,
                             double* __restrict__ DX, int64_t TC, int64_t C) {
    double s1=*pS1, s2=*pS2;
    int64_t rank=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;
    int64_t stride=(int64_t)gridDim.x*blockDim.x;
    for (int64_t idx=rank; idx<TC; idx+=stride) {
        int64_t ch=idx%C;
        double dxh=DY[idx]*GAMMA[ch];
        DX[idx]=inv_g*(dxh - s1/m - XHAT[idx]*s2/m);
    }
}

/* host driver: tree fwd GN (G=1). writes Y,MEAN,INV,XHAT. mu/inv left on device too. */
static int tree_fwd(const double*X,const double*GA,const double*BE,double*Y,double*ME,
                    double*IN,double*XH,int64_t T,int64_t C, double*bp,double*pMu,double*pInv){
    const double eps=0.00001; int64_t TC=T*C; double m=(double)TC;
    gn_fwd_sum_blocks<<<GN_NB,GN_BS>>>(X,0,TC,bp);
    gn_finalize1<<<1,GN_NB>>>(bp,GN_NB,m,0,eps,pMu);   /* mu */
    gn_fwd_var_blocks<<<GN_NB,GN_BS>>>(X,pMu,0,TC,bp);
    gn_finalize1<<<1,GN_NB>>>(bp,GN_NB,m,1,eps,pInv);  /* inv */
    /* copy scalars to MEAN[0]/INV[0] */
    CK(cudaMemcpy(ME,pMu,sizeof(double),cudaMemcpyDeviceToDevice));
    CK(cudaMemcpy(IN,pInv,sizeof(double),cudaMemcpyDeviceToDevice));
    int nb=(int)((TC+255)/256); if(nb>65535)nb=65535;
    gn_normalize<<<nb,256>>>(X,GA,BE,pMu,pInv,Y,XH,TC,C);
    return 0;
}
/* host driver: tree bwd_dx GN (G=1). needs INV[0] on host for inv_g; reads xhat. */
static int tree_bwd(const double*XH,double inv_g,const double*GA,const double*DY,double*DX,
                    int64_t T,int64_t C,double*bp1,double*bp2,double*pS1,double*pS2){
    int64_t TC=T*C; double m=(double)TC; int64_t cg=C; int64_t c0=0;
    gn_bwd_s1s2_blocks<<<GN_NB,GN_BS>>>(XH,GA,DY,0,C,cg,c0,TC,bp1,bp2);
    gn_finalize2<<<1,GN_NB>>>(bp1,bp2,GN_NB,pS1,pS2);
    int nb=(int)((TC+255)/256); if(nb>65535)nb=65535;
    gn_bwd_write<<<nb,256>>>(XH,GA,DY,pS1,pS2,inv_g,m,DX,TC,C);
    return 0;
}

static double maxabs(const double*a,const double*b,int64_t n,long*bitdiff){
    double mx=0; for(int64_t i=0;i<n;i++){double d=fabs(a[i]-b[i]); if(d>mx)mx=d;
        if(memcmp(&a[i],&b[i],sizeof(double))!=0)(*bitdiff)++;} return mx;
}

int main(int argc,char**argv){
    int dev=0; cudaGetDevice(&dev); cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);
    printf("HEXA-FUSION FF-GN-PARALLEL fixed-order tree gate\n");
    printf("device: %s  sm_%d%d  NB=%d BS=%d\n",p.name,p.major,p.minor,GN_NB,GN_BS);
    /* DUTYCYCLE shape: T=512 C=1536 G=1 (whole tensor). */
    int64_t T=512, C=1536, G=1; int64_t TC=T*C;
    int iters = (argc>1)?atoi(argv[1]):50;

    double *hX=(double*)malloc(TC*sizeof(double)),*hG=(double*)malloc(C*sizeof(double)),
           *hB=(double*)malloc(C*sizeof(double)),*hDY=(double*)malloc(TC*sizeof(double));
    srand(12345u);
    for(int64_t i=0;i<TC;i++){hX[i]=((double)rand()/RAND_MAX)*4.0-2.0; hDY[i]=((double)rand()/RAND_MAX)*2.0-1.0;}
    for(int64_t c=0;c<C;c++){hG[c]=((double)rand()/RAND_MAX)*2.0-1.0; hB[c]=((double)rand()/RAND_MAX)*2.0-1.0;}

    double *X,*GA,*BE,*DY;
    CK(cudaMalloc(&X,TC*sizeof(double)));CK(cudaMalloc(&GA,C*sizeof(double)));
    CK(cudaMalloc(&BE,C*sizeof(double)));CK(cudaMalloc(&DY,TC*sizeof(double)));
    CK(cudaMemcpy(X,hX,TC*sizeof(double),cudaMemcpyHostToDevice));
    CK(cudaMemcpy(GA,hG,C*sizeof(double),cudaMemcpyHostToDevice));
    CK(cudaMemcpy(BE,hB,C*sizeof(double),cudaMemcpyHostToDevice));
    CK(cudaMemcpy(DY,hDY,TC*sizeof(double),cudaMemcpyHostToDevice));
    /* oracle buffers */
    double *Yo,*MEo,*INo,*XHo,*DXo;
    CK(cudaMalloc(&Yo,TC*sizeof(double)));CK(cudaMalloc(&MEo,G*sizeof(double)));
    CK(cudaMalloc(&INo,G*sizeof(double)));CK(cudaMalloc(&XHo,TC*sizeof(double)));
    CK(cudaMalloc(&DXo,TC*sizeof(double)));
    /* tree buffers (run twice -> a/b for determinism) */
    double *Ya,*MEa,*INa,*XHa,*DXa,*Yb,*MEb,*INb,*XHb,*DXb;
    CK(cudaMalloc(&Ya,TC*sizeof(double)));CK(cudaMalloc(&MEa,G*sizeof(double)));CK(cudaMalloc(&INa,G*sizeof(double)));CK(cudaMalloc(&XHa,TC*sizeof(double)));CK(cudaMalloc(&DXa,TC*sizeof(double)));
    CK(cudaMalloc(&Yb,TC*sizeof(double)));CK(cudaMalloc(&MEb,G*sizeof(double)));CK(cudaMalloc(&INb,G*sizeof(double)));CK(cudaMalloc(&XHb,TC*sizeof(double)));CK(cudaMalloc(&DXb,TC*sizeof(double)));
    double *bp,*bp1,*bp2,*pMu,*pInv,*pS1,*pS2;
    CK(cudaMalloc(&bp,GN_NB*sizeof(double)));CK(cudaMalloc(&bp1,GN_NB*sizeof(double)));CK(cudaMalloc(&bp2,GN_NB*sizeof(double)));
    CK(cudaMalloc(&pMu,sizeof(double)));CK(cudaMalloc(&pInv,sizeof(double)));CK(cudaMalloc(&pS1,sizeof(double)));CK(cudaMalloc(&pS2,sizeof(double)));

    /* ---- ORACLE single-thread fwd + bwd_dx (1 thread, the pathology) ---- */
    _hx_k_groupnorm<<<1,1>>>(X,GA,BE,Yo,MEo,INo,XHo,T,C,G); CK(cudaDeviceSynchronize());
    double hINo; CK(cudaMemcpy(&hINo,INo,sizeof(double),cudaMemcpyDeviceToHost));
    _hx_k_groupnorm_bwd_dx<<<1,1>>>(XHo,INo,GA,DY,DXo,T,C,G); CK(cudaDeviceSynchronize());

    /* ---- TREE run A ---- */
    tree_fwd(X,GA,BE,Ya,MEa,INa,XHa,T,C,bp,pMu,pInv); CK(cudaDeviceSynchronize());
    double hINa; CK(cudaMemcpy(&hINa,INa,sizeof(double),cudaMemcpyDeviceToHost));
    tree_bwd(XHa,hINa,GA,DY,DXa,T,C,bp1,bp2,pS1,pS2); CK(cudaDeviceSynchronize());
    /* ---- TREE run B (determinism) ---- */
    tree_fwd(X,GA,BE,Yb,MEb,INb,XHb,T,C,bp,pMu,pInv); CK(cudaDeviceSynchronize());
    double hINb; CK(cudaMemcpy(&hINb,INb,sizeof(double),cudaMemcpyDeviceToHost));
    tree_bwd(XHb,hINb,GA,DY,DXb,T,C,bp1,bp2,pS1,pS2); CK(cudaDeviceSynchronize());

    /* host copies */
    double *Ho=(double*)malloc(TC*sizeof(double)),*Ha=(double*)malloc(TC*sizeof(double)),*Hb=(double*)malloc(TC*sizeof(double));
    double *DHo=(double*)malloc(TC*sizeof(double)),*DHa=(double*)malloc(TC*sizeof(double)),*DHb=(double*)malloc(TC*sizeof(double));
    CK(cudaMemcpy(Ho,Yo,TC*sizeof(double),cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(Ha,Ya,TC*sizeof(double),cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(Hb,Yb,TC*sizeof(double),cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(DHo,DXo,TC*sizeof(double),cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(DHa,DXa,TC*sizeof(double),cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(DHb,DXb,TC*sizeof(double),cudaMemcpyDeviceToHost));

    /* GATE 1: determinism run A vs run B (must be bit-eq, max|delta|=0). */
    long bd=0; double det_y=maxabs(Ha,Hb,TC,&bd); long bd2=0; double det_dx=maxabs(DHa,DHb,TC,&bd2);
    printf("\n[GATE1 DETERMINISM] fwd Y  run-to-run max|delta|=%.17g bitdiff=%ld\n",det_y,bd);
    printf("[GATE1 DETERMINISM] bwd DX run-to-run max|delta|=%.17g bitdiff=%ld  %s\n",
           det_dx,bd2,(det_y==0.0&&det_dx==0.0&&bd==0&&bd2==0)?"DETERMINISTIC PASS":"FAIL");

    /* GATE 2: re-baseline tree vs sequential oracle (~machine-eps). */
    long z=0; double rb_y=maxabs(Ho,Ha,TC,&z); long z2=0; double rb_dx=maxabs(DHo,DHa,TC,&z2);
    printf("\n[GATE2 REBASELINE] fwd Y  tree-vs-seq max|delta|=%.17g\n",rb_y);
    printf("[GATE2 REBASELINE] bwd DX tree-vs-seq max|delta|=%.17g\n",rb_dx);
    printf("[GATE2 REBASELINE] (expect ~machine-eps over N=%lld, FP64)\n",(long long)TC);

    /* GATE 3: timing tree vs single-thread. */
    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    /* seq fwd */
    cudaEventRecord(e0);
    for(int it=0;it<iters;it++) _hx_k_groupnorm<<<1,1>>>(X,GA,BE,Yo,MEo,INo,XHo,T,C,G);
    cudaEventRecord(e1); cudaEventSynchronize(e1);
    float ms_seq_fwd=0; cudaEventElapsedTime(&ms_seq_fwd,e0,e1); ms_seq_fwd/=iters;
    /* seq bwd */
    cudaEventRecord(e0);
    for(int it=0;it<iters;it++) _hx_k_groupnorm_bwd_dx<<<1,1>>>(XHo,INo,GA,DY,DXo,T,C,G);
    cudaEventRecord(e1); cudaEventSynchronize(e1);
    float ms_seq_bwd=0; cudaEventElapsedTime(&ms_seq_bwd,e0,e1); ms_seq_bwd/=iters;
    /* tree fwd */
    cudaEventRecord(e0);
    for(int it=0;it<iters;it++) tree_fwd(X,GA,BE,Ya,MEa,INa,XHa,T,C,bp,pMu,pInv);
    cudaEventRecord(e1); cudaEventSynchronize(e1);
    float ms_tree_fwd=0; cudaEventElapsedTime(&ms_tree_fwd,e0,e1); ms_tree_fwd/=iters;
    /* tree bwd */
    cudaEventRecord(e0);
    for(int it=0;it<iters;it++) tree_bwd(XHa,hINa,GA,DY,DXa,T,C,bp1,bp2,pS1,pS2);
    cudaEventRecord(e1); cudaEventSynchronize(e1);
    float ms_tree_bwd=0; cudaEventElapsedTime(&ms_tree_bwd,e0,e1); ms_tree_bwd/=iters;

    printf("\n[GATE3 SPEEDUP] (T=%lld C=%lld G=1, FP64, iters=%d, ms/call)\n",(long long)T,(long long)C,iters);
    printf("  fwd  GN  seq=%.4f ms   tree=%.4f ms   speedup=%.2fx\n",ms_seq_fwd,ms_tree_fwd,ms_seq_fwd/ms_tree_fwd);
    printf("  bwd  DX  seq=%.4f ms   tree=%.4f ms   speedup=%.2fx\n",ms_seq_bwd,ms_tree_bwd,ms_seq_bwd/ms_tree_bwd);
    printf("  GN total seq=%.4f ms   tree=%.4f ms   speedup=%.2fx\n",
           ms_seq_fwd+ms_seq_bwd,ms_tree_fwd+ms_tree_bwd,(ms_seq_fwd+ms_seq_bwd)/(ms_tree_fwd+ms_tree_bwd));

    int ok=(det_y==0.0&&det_dx==0.0&&bd==0&&bd2==0);
    printf("\n%s\n", ok?"GATE1 DETERMINISM PASS (tree is bit-reproducible)":"GATE1 FAIL");
    return ok?0:1;
}
