/* OP-6 — vectorize a memory-bound flame sm_120 kernel (.v loads/stores, bit-exact).
 *
 * Target: _hx_k_adamw_step_inplace (self/cuda/runtime_cuda.c) — the fp64
 * elementwise AdamW optimizer update used by the flame trainer. Per element:
 *   reads  W,M,V,G   (4 fp64)
 *   writes M,V,W     (3 fp64)
 * = 7 fp64 memory streams, NO cross-element dependency, NO reduction → a
 * pure memory-bound kernel. The production kernel uses SCALAR (64-bit) global
 * loads/stores.
 *
 * Lever (OP-1 generalized): double2 (128-bit) coalesced loads + double2
 * vectorized stores over the contiguous element layout, with a scalar
 * remainder loop for the n%2 tail. This changes ONLY the load/store WIDTH —
 * the per-element arithmetic and order are byte-for-byte identical → bit-exact.
 *
 * GATE (g5): output (W,M,V) must be BYTE-IDENTICAL between scalar and vec
 * (max|Δ|=0, bitdiff=0). Reports effective GB/s before/after.
 *
 * Build (aiden): nvcc -O3 -arch=sm_120 op6_adamw_vec_bench.cu -o op6
 */
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <cstdlib>
#include <cuda_runtime.h>

#define CK(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA err %s:%d: %s\n",__FILE__,__LINE__,cudaGetErrorString(e)); exit(1);} }while(0)

/* ── SCALAR baseline — VERBATIM arithmetic of _hx_k_adamw_step_inplace ── */
__global__ void adamw_scalar(double* __restrict__ W,
                             double* __restrict__ Mm,
                             double* __restrict__ Vv,
                             const double* __restrict__ G,
                             int64_t n,
                             double lr, double b1, double b2,
                             double eps, double wd,
                             double c1, double c2) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < n; i += stride) {
        double g    = G[i];
        double mi   = b1 * Mm[i] + (1.0 - b1) * g;
        double vi   = b2 * Vv[i] + (1.0 - b2) * g * g;
        double mhat = mi / c1;
        double vhat = vi / c2;
        double denom = sqrt(vhat) + eps;
        double wi   = W[i] - lr * wd * W[i] - lr * mhat / denom;
        Mm[i] = mi;
        Vv[i] = vi;
        W[i]  = wi;
    }
}

/* per-element body — identical math, factored so vec path reuses it EXACTLY */
__device__ __forceinline__ void adamw_body(double w, double m, double v, double g,
                                           double lr, double b1, double b2,
                                           double eps, double wd, double c1, double c2,
                                           double* w_o, double* m_o, double* v_o) {
    double mi   = b1 * m + (1.0 - b1) * g;
    double vi   = b2 * v + (1.0 - b2) * g * g;
    double mhat = mi / c1;
    double vhat = vi / c2;
    double denom = sqrt(vhat) + eps;
    double wi   = w - lr * wd * w - lr * mhat / denom;
    *w_o = wi; *m_o = mi; *v_o = vi;
}

/* ── VECTORIZED — double2 (128-bit) coalesced loads + vectorized stores ──
 * Each thread handles 2 contiguous elements via one double2 load per stream
 * and one double2 store per output stream. The arithmetic per element is the
 * SAME adamw_body, in the SAME order. Tail (n%2) handled by a scalar remainder
 * loop. Grid-stride over PAIRS. */
__global__ void adamw_vec(double* __restrict__ W,
                          double* __restrict__ Mm,
                          double* __restrict__ Vv,
                          const double* __restrict__ G,
                          int64_t n,
                          double lr, double b1, double b2,
                          double eps, double wd,
                          double c1, double c2) {
    int64_t npair = n >> 1;                 /* number of full double2 pairs */
    double2* W2 = reinterpret_cast<double2*>(W);
    double2* M2 = reinterpret_cast<double2*>(Mm);
    double2* V2 = reinterpret_cast<double2*>(Vv);
    const double2* G2 = reinterpret_cast<const double2*>(G);
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t p = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         p < npair; p += stride) {
        double2 w = W2[p], m = M2[p], v = V2[p], g = G2[p];   /* 128-bit loads */
        double2 wo, mo, vo;
        adamw_body(w.x, m.x, v.x, g.x, lr,b1,b2,eps,wd,c1,c2, &wo.x,&mo.x,&vo.x);
        adamw_body(w.y, m.y, v.y, g.y, lr,b1,b2,eps,wd,c1,c2, &wo.y,&mo.y,&vo.y);
        M2[p] = mo;  V2[p] = vo;  W2[p] = wo;                 /* 128-bit stores */
    }
    /* scalar tail — only thread 0 of block 0 (tiny, n%2 ∈ {0,1}) */
    if (blockIdx.x == 0 && threadIdx.x == 0) {
        for (int64_t i = (npair << 1); i < n; ++i) {
            double wo,mo,vo;
            adamw_body(W[i],Mm[i],Vv[i],G[i], lr,b1,b2,eps,wd,c1,c2, &wo,&mo,&vo);
            Mm[i]=mo; Vv[i]=vo; W[i]=wo;
        }
    }
}

static double now_ms(cudaEvent_t a, cudaEvent_t b){ float ms=0; cudaEventElapsedTime(&ms,a,b); return ms; }

int main(int argc, char** argv){
    int64_t n = (argc>1)? atoll(argv[1]) : (64LL*1024*1024);  /* default 64M elems */
    int iters = (argc>2)? atoi(argv[2]) : 50;
    /* AdamW params (typical) */
    double lr=1e-3, b1=0.9, b2=0.999, eps=1e-8, wd=0.01;
    int64_t step_t = 10;
    double b1t=1.0,b2t=1.0; for(int64_t e=0;e<step_t;e++){b1t*=b1;b2t*=b2;}
    double c1=1.0-b1t, c2=1.0-b2t;

    size_t bytes = (size_t)n*sizeof(double);
    /* host init — deterministic pseudo-random */
    double *hW=(double*)malloc(bytes),*hM=(double*)malloc(bytes),
           *hV=(double*)malloc(bytes),*hG=(double*)malloc(bytes);
    uint64_t s=88172645463325252ULL;
    for(int64_t i=0;i<n;i++){
        s^=s<<13; s^=s>>7; s^=s<<17;
        double r=((double)(s>>11))/9007199254740992.0; /* [0,1) */
        hW[i]=(r-0.5)*0.2; hG[i]=(r-0.5)*0.01;
        hM[i]=r*0.001;     hV[i]=r*1e-6;
    }
    /* device buffers — two sets (scalar run + vec run, from same init) */
    double *W1,*M1,*V1,*G1,*W2,*M2,*V2,*G2;
    CK(cudaMalloc(&W1,bytes)); CK(cudaMalloc(&M1,bytes)); CK(cudaMalloc(&V1,bytes)); CK(cudaMalloc(&G1,bytes));
    CK(cudaMalloc(&W2,bytes)); CK(cudaMalloc(&M2,bytes)); CK(cudaMalloc(&V2,bytes)); CK(cudaMalloc(&G2,bytes));

    int block=256;
    int64_t want=(n+block-1)/block; int grid=(want>1024)?1024:(int)want; if(grid<1)grid=1;
    int64_t npair=n>>1; int64_t wantp=(npair+block-1)/block; int gridp=(wantp>1024)?1024:(int)wantp; if(gridp<1)gridp=1;

    cudaEvent_t e0,e1; CK(cudaEventCreate(&e0)); CK(cudaEventCreate(&e1));

    auto reset=[&](double*W,double*M,double*V,double*G){
        CK(cudaMemcpy(W,hW,bytes,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(M,hM,bytes,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(V,hV,bytes,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(G,hG,bytes,cudaMemcpyHostToDevice));
    };

    /* ── correctness: ONE step each from identical init, compare bit-exact ── */
    reset(W1,M1,V1,G1); reset(W2,M2,V2,G2);
    adamw_scalar<<<grid,block>>>(W1,M1,V1,G1,n,lr,b1,b2,eps,wd,c1,c2);
    adamw_vec   <<<gridp,block>>>(W2,M2,V2,G2,n,lr,b1,b2,eps,wd,c1,c2);
    CK(cudaDeviceSynchronize());
    double *rW1=(double*)malloc(bytes),*rM1=(double*)malloc(bytes),*rV1=(double*)malloc(bytes);
    double *rW2=(double*)malloc(bytes),*rM2=(double*)malloc(bytes),*rV2=(double*)malloc(bytes);
    CK(cudaMemcpy(rW1,W1,bytes,cudaMemcpyDeviceToHost)); CK(cudaMemcpy(rW2,W2,bytes,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(rM1,M1,bytes,cudaMemcpyDeviceToHost)); CK(cudaMemcpy(rM2,M2,bytes,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(rV1,V1,bytes,cudaMemcpyDeviceToHost)); CK(cudaMemcpy(rV2,V2,bytes,cudaMemcpyDeviceToHost));
    int64_t bitdiff=0; double maxabs=0;
    for(int64_t i=0;i<n;i++){
        if(memcmp(&rW1[i],&rW2[i],8)) bitdiff++;
        if(memcmp(&rM1[i],&rM2[i],8)) bitdiff++;
        if(memcmp(&rV1[i],&rV2[i],8)) bitdiff++;
        double dw=fabs(rW1[i]-rW2[i]),dm=fabs(rM1[i]-rM2[i]),dv=fabs(rV1[i]-rV2[i]);
        if(dw>maxabs)maxabs=dw; if(dm>maxabs)maxabs=dm; if(dv>maxabs)maxabs=dv;
    }
    printf("n=%lld  bytes_moved/step=%.2f MB  (7 fp64 streams)\n",
           (long long)n, (7.0*bytes)/1e6);
    printf("BIT-EXACT: bitdiff=%lld  max|delta|=%.3e  -> %s\n",
           (long long)bitdiff, maxabs, (bitdiff==0)?"BYTE-IDENTICAL (PASS)":"MISMATCH (FAIL)");

    /* ── timing — scalar ── */
    reset(W1,M1,V1,G1);
    /* warmup */
    adamw_scalar<<<grid,block>>>(W1,M1,V1,G1,n,lr,b1,b2,eps,wd,c1,c2); CK(cudaDeviceSynchronize());
    CK(cudaEventRecord(e0));
    for(int it=0; it<iters; ++it)
        adamw_scalar<<<grid,block>>>(W1,M1,V1,G1,n,lr,b1,b2,eps,wd,c1,c2);
    CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
    double t_scal = now_ms(e0,e1)/iters;

    /* ── timing — vec ── */
    reset(W2,M2,V2,G2);
    adamw_vec<<<gridp,block>>>(W2,M2,V2,G2,n,lr,b1,b2,eps,wd,c1,c2); CK(cudaDeviceSynchronize());
    CK(cudaEventRecord(e0));
    for(int it=0; it<iters; ++it)
        adamw_vec<<<gridp,block>>>(W2,M2,V2,G2,n,lr,b1,b2,eps,wd,c1,c2);
    CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
    double t_vec = now_ms(e0,e1)/iters;

    double gb = (7.0*bytes)/1e9;  /* 4 read + 3 write fp64 streams */
    printf("SCALAR : %.4f ms/step   %.1f GB/s\n", t_scal, gb/(t_scal/1e3));
    printf("VEC    : %.4f ms/step   %.1f GB/s\n", t_vec,  gb/(t_vec/1e3));
    printf("SPEEDUP: %.3fx (ms_scalar/ms_vec)\n", t_scal/t_vec);
    return 0;
}
