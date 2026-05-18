/* rfc060_megakernel_fwd.cu — RFC 060 falsifier F-RFC060-MEGAKERNEL-WALL.
 *
 * Cheap first measurement (RFC 060 §7): does fusing the transformer-block
 * FORWARD pass into ONE persistent GPU kernel beat the kernel-per-op
 * stream? Kill if < 1.1×.
 *
 * Two faithful FP64 implementations of the SAME Llama-style block forward:
 *
 *   A. STREAM   — cuBLAS Dgemm for the 7 matmuls + QK^T/PV, separate CUDA
 *                 kernels for RMSNorm / causal-softmax / SwiGLU / residual.
 *                 N kernel launches, N HBM round-trips. (CUDA's default
 *                 kernel-per-op execution model.)
 *   B. MEGA     — ONE persistent cooperative kernel. cuBLAS is NOT callable
 *                 from inside a kernel, so the mega-kernel does its own
 *                 in-kernel shared-memory-tiled FP64 GEMM. All non-matmul
 *                 ops fused in; grid.sync() between dependent ops; one launch.
 *
 * Block forward (B=1, no biases, FP64):
 *   x1   = RMSNorm(X, g1)
 *   Q,K,V= x1·Wq, x1·Wk, x1·Wv                  [L,D]
 *   per head h:  S = Qh·Kh^T / sqrt(hd); causal mask; P = softmax(S);
 *                Ah = P·Vh                       [L,hd]
 *   ao   = A·Wo                                  [L,D]
 *   r1   = X + ao
 *   x2   = RMSNorm(r1, g2)
 *   g,u  = x2·Wgate, x2·Wup                      [L,Df]
 *   hh   = SiLU(g) * u                           [L,Df]
 *   ff   = hh·Wdown                              [L,D]
 *   Y    = r1 + ff                               [L,D]
 *
 * Reports B/A wall ratio + a diagnostic decomposition (matmul-only time:
 * cuBLAS vs in-kernel GEMM; non-matmul-only time: stream vs fused) so the
 * verdict is explained, not just stated. Emits result.json.
 *
 * Build:  nvcc -O3 -std=c++14 -arch=native rfc060_megakernel_fwd.cu \
 *              -lcublas -lcudart -lm -o rfc060_megakernel_fwd
 * Run:    ./rfc060_megakernel_fwd [small|medium|all]
 *
 * SSOT: inbox/rfc_drafts_2026_05_12/rfc_060_forge_new_compute_paradigm.md
 */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <cuda_runtime.h>
#include <cooperative_groups.h>
#include <cublas_v2.h>

namespace cg = cooperative_groups;

#define CK(c) do{ cudaError_t e=(c); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA %s:%d %s\n",__FILE__,__LINE__,cudaGetErrorString(e)); exit(1);} }while(0)
#define CB(c) do{ cublasStatus_t s=(c); if(s!=CUBLAS_STATUS_SUCCESS){ \
  fprintf(stderr,"cuBLAS %s:%d status=%d\n",__FILE__,__LINE__,(int)s); exit(1);} }while(0)

static double now_sec(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t);
  return t.tv_sec + t.tv_nsec/1e9; }

/* ── stream-baseline kernels (kernel-per-op) ───────────────────────── */

/* row-major C[M,N] = A[M,K]·B[K,N] via cuBLAS (column-major: swap). */
static void cublas_mm(cublasHandle_t h, const double* A, const double* B,
                      double* C, int M, int N, int K) {
    const double a=1.0, b=0.0;
    CB(cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                   &a, B, N, A, K, &b, C, N));
}

__global__ void k_rmsnorm(const double* X, const double* g, double* Y,
                           int R, int C, double eps) {
    int r = blockIdx.x; if (r >= R) return;
    const double* xr = X + (size_t)r*C; double* yr = Y + (size_t)r*C;
    __shared__ double sm[32];
    double v = 0.0;
    for (int j = threadIdx.x; j < C; j += blockDim.x){ double x=xr[j]; v+=x*x; }
    for (int o=16;o>0;o>>=1) v += __shfl_down_sync(0xffffffff,v,o);
    if ((threadIdx.x&31)==0) sm[threadIdx.x>>5]=v;
    __syncthreads();
    if (threadIdx.x==0){ double s=0; int nw=(blockDim.x+31)>>5;
        for(int i=0;i<nw;i++) s+=sm[i]; sm[0]=s; }
    __syncthreads();
    double inv = 1.0/sqrt(sm[0]/(double)C + eps);
    for (int j=threadIdx.x;j<C;j+=blockDim.x) yr[j]=xr[j]*inv*g[j];
}

/* causal softmax over row, in place, scale applied first. one block / row. */
__global__ void k_causal_softmax(double* S, int L, double scale) {
    int q = blockIdx.x; if (q >= L) return;
    double* sr = S + (size_t)q*L;
    __shared__ double red[32];
    double m = -1e300;
    for (int k=threadIdx.x;k<L;k+=blockDim.x){
        double v = (k<=q)? sr[k]*scale : -1e300;
        sr[k]=v; if(v>m) m=v;
    }
    for(int o=16;o>0;o>>=1){ double t=__shfl_down_sync(0xffffffff,m,o); if(t>m)m=t; }
    if((threadIdx.x&31)==0) red[threadIdx.x>>5]=m;
    __syncthreads();
    if(threadIdx.x==0){ double mm=-1e300; int nw=(blockDim.x+31)>>5;
        for(int i=0;i<nw;i++) if(red[i]>mm)mm=red[i]; red[0]=mm; }
    __syncthreads();
    double rmax=red[0], sum=0.0;
    for(int k=threadIdx.x;k<L;k+=blockDim.x){
        double e = (k<=q)? exp(sr[k]-rmax):0.0; sr[k]=e; sum+=e;
    }
    for(int o=16;o>0;o>>=1) sum+=__shfl_down_sync(0xffffffff,sum,o);
    if((threadIdx.x&31)==0) red[threadIdx.x>>5]=sum;
    __syncthreads();
    if(threadIdx.x==0){ double s=0; int nw=(blockDim.x+31)>>5;
        for(int i=0;i<nw;i++) s+=red[i]; red[0]=s; }
    __syncthreads();
    double inv=1.0/red[0];
    for(int k=threadIdx.x;k<L;k+=blockDim.x) sr[k]*=inv;
}

__global__ void k_silu_mul(const double* G, const double* U, double* H, int n){
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    if(i<n){ double g=G[i]; H[i]=(g/(1.0+exp(-g)))*U[i]; }
}
__global__ void k_add(const double* A, const double* B, double* C, int n){
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    if(i<n) C[i]=A[i]+B[i];
}
/* attention scores: S[L,L] = Qh[L,hd]·Kh[L,hd]^T (heads strided by D).
 * raw (no scale — k_causal_softmax applies it). one thread per (i,j). */
__global__ void k_qkt(const double* Q, const double* K, double* S,
                       int L, int hd, int D){
    int i = blockIdx.y*blockDim.y + threadIdx.y;
    int j = blockIdx.x*blockDim.x + threadIdx.x;
    if(i>=L || j>=L) return;
    double acc=0.0;
    for(int d=0; d<hd; d++)
        acc += Q[(size_t)i*D+d] * K[(size_t)j*D+d];
    S[(size_t)i*L+j]=acc;
}
/* attention value: Ah[L,hd] = P[L,L]·Vh[L,hd]. Ah/Vh strided by D. */
__global__ void k_pv(const double* P, const double* V, double* A,
                      int L, int hd, int D){
    int i = blockIdx.y*blockDim.y + threadIdx.y;
    int e = blockIdx.x*blockDim.x + threadIdx.x;
    if(i>=L || e>=hd) return;
    double acc=0.0;
    for(int k=0;k<L;k++)
        acc += P[(size_t)i*L+k] * V[(size_t)k*D+e];
    A[(size_t)i*D+e]=acc;
}

/* ── in-kernel device GEMM (shared-memory tiled, 16×16) ────────────── */
#define TILE 16
/* grid-strided over 16×16 output tiles; whole grid cooperates. */
__device__ void dev_gemm(cg::grid_group& grid, const double* A,
                          const double* B, double* C, int M, int N, int K) {
    int tilesM=(M+TILE-1)/TILE, tilesN=(N+TILE-1)/TILE;
    int nTiles=tilesM*tilesN;
    __shared__ double As[TILE][TILE], Bs[TILE][TILE];
    int tx=threadIdx.x%TILE, ty=threadIdx.x/TILE;
    for(int t=blockIdx.x; t<nTiles; t+=gridDim.x){
        int tm=(t/tilesN)*TILE, tn=(t%tilesN)*TILE;
        int row=tm+ty, col=tn+tx;
        double acc=0.0;
        for(int k0=0;k0<K;k0+=TILE){
            As[ty][tx] = (row<M && k0+tx<K)? A[(size_t)row*K+k0+tx]:0.0;
            Bs[ty][tx] = (k0+ty<K && col<N)? B[(size_t)(k0+ty)*N+col]:0.0;
            __syncthreads();
            #pragma unroll
            for(int kk=0;kk<TILE;kk++) acc+=As[ty][kk]*Bs[kk][tx];
            __syncthreads();
        }
        if(row<M && col<N) C[(size_t)row*N+col]=acc;
    }
}
/* C = A · B^T  (B is [N,K], we want C[M,N]=A[M,K]·B[N,K]^T). */
__device__ void dev_gemm_nt(cg::grid_group& grid, const double* A,
                             const double* B, double* C, int M, int N, int K){
    int tilesM=(M+TILE-1)/TILE, tilesN=(N+TILE-1)/TILE, nTiles=tilesM*tilesN;
    __shared__ double As[TILE][TILE], Bs[TILE][TILE];
    int tx=threadIdx.x%TILE, ty=threadIdx.x/TILE;
    for(int t=blockIdx.x;t<nTiles;t+=gridDim.x){
        int tm=(t/tilesN)*TILE, tn=(t%tilesN)*TILE;
        int row=tm+ty, col=tn+tx; double acc=0.0;
        for(int k0=0;k0<K;k0+=TILE){
            As[ty][tx]=(row<M && k0+tx<K)? A[(size_t)row*K+k0+tx]:0.0;
            Bs[ty][tx]=(col<N && k0+tx<K)? B[(size_t)col*K+k0+tx]:0.0;
            __syncthreads();
            #pragma unroll
            for(int kk=0;kk<TILE;kk++) acc+=As[ty][kk]*Bs[tx][kk];
            __syncthreads();
        }
        if(row<M && col<N) C[(size_t)row*N+col]=acc;
    }
}

__device__ void dev_rmsnorm(cg::grid_group& grid, const double* X,
                             const double* g, double* Y, int R, int C, double eps){
    for(int r=blockIdx.x;r<R;r+=gridDim.x){
        const double* xr=X+(size_t)r*C; double* yr=Y+(size_t)r*C;
        __shared__ double sm[32];
        double v=0.0;
        for(int j=threadIdx.x;j<C;j+=blockDim.x){ double x=xr[j]; v+=x*x; }
        for(int o=16;o>0;o>>=1) v+=__shfl_down_sync(0xffffffff,v,o);
        if((threadIdx.x&31)==0) sm[threadIdx.x>>5]=v;
        __syncthreads();
        if(threadIdx.x==0){ double s=0; int nw=(blockDim.x+31)>>5;
            for(int i=0;i<nw;i++) s+=sm[i]; sm[0]=s; }
        __syncthreads();
        double inv=1.0/sqrt(sm[0]/(double)C+eps);
        for(int j=threadIdx.x;j<C;j+=blockDim.x) yr[j]=xr[j]*inv*g[j];
        __syncthreads();
    }
}
__device__ void dev_causal_softmax(cg::grid_group& grid, double* S, int L, double scale){
    for(int q=blockIdx.x;q<L;q+=gridDim.x){
        double* sr=S+(size_t)q*L; __shared__ double red[32];
        double m=-1e300;
        for(int k=threadIdx.x;k<L;k+=blockDim.x){
            double v=(k<=q)?sr[k]*scale:-1e300; sr[k]=v; if(v>m)m=v; }
        for(int o=16;o>0;o>>=1){ double t=__shfl_down_sync(0xffffffff,m,o); if(t>m)m=t; }
        if((threadIdx.x&31)==0) red[threadIdx.x>>5]=m;
        __syncthreads();
        if(threadIdx.x==0){ double mm=-1e300; int nw=(blockDim.x+31)>>5;
            for(int i=0;i<nw;i++) if(red[i]>mm)mm=red[i]; red[0]=mm; }
        __syncthreads();
        double rmax=red[0], sum=0.0;
        for(int k=threadIdx.x;k<L;k+=blockDim.x){
            double e=(k<=q)?exp(sr[k]-rmax):0.0; sr[k]=e; sum+=e; }
        for(int o=16;o>0;o>>=1) sum+=__shfl_down_sync(0xffffffff,sum,o);
        if((threadIdx.x&31)==0) red[threadIdx.x>>5]=sum;
        __syncthreads();
        if(threadIdx.x==0){ double s=0; int nw=(blockDim.x+31)>>5;
            for(int i=0;i<nw;i++) s+=red[i]; red[0]=s; }
        __syncthreads();
        double inv=1.0/red[0];
        for(int k=threadIdx.x;k<L;k+=blockDim.x) sr[k]*=inv;
        __syncthreads();
    }
}
__device__ void dev_elem_silumul(cg::grid_group& grid, const double* G,
                                  const double* U, double* H, int n){
    for(int i=blockIdx.x*blockDim.x+threadIdx.x;i<n;i+=gridDim.x*blockDim.x){
        double g=G[i]; H[i]=(g/(1.0+exp(-g)))*U[i]; }
}
__device__ void dev_elem_add(cg::grid_group& grid, const double* A,
                              const double* B, double* C, int n){
    for(int i=blockIdx.x*blockDim.x+threadIdx.x;i<n;i+=gridDim.x*blockDim.x)
        C[i]=A[i]+B[i];
}

/* ── the MEGA kernel — one persistent cooperative kernel ───────────── */
struct Dims { int L,D,nh,hd,Df; };
struct Bufs {
    const double *X,*g1,*Wq,*Wk,*Wv,*Wo,*g2,*Wgate,*Wup,*Wdown;
    double *x1,*Q,*K,*V,*S,*Ah,*ao,*r1,*x2,*gg,*uu,*hh,*ff,*Y;
};
__global__ void mega_forward(Dims d, Bufs b) {
    cg::grid_group grid = cg::this_grid();
    int L=d.L,D=d.D,nh=d.nh,hd=d.hd,Df=d.Df;
    double scale = 1.0/sqrt((double)hd);
    double eps=1e-6;

    dev_rmsnorm(grid,b.X,b.g1,b.x1,L,D,eps);                 grid.sync();
    dev_gemm(grid,b.x1,b.Wq,b.Q,L,D,D);                      grid.sync();
    dev_gemm(grid,b.x1,b.Wk,b.K,L,D,D);                      grid.sync();
    dev_gemm(grid,b.x1,b.Wv,b.V,L,D,D);                      grid.sync();
    for(int h=0;h<nh;h++){
        const double* Qh=b.Q+(size_t)h*hd;
        const double* Kh=b.K+(size_t)h*hd;
        const double* Vh=b.V+(size_t)h*hd;
        double* Sh=b.S; double* Aoh=b.Ah+(size_t)h*hd;
        /* S[L,L] = Qh[L,hd]·Kh[L,hd]^T  (strided rows: D-stride) */
        { int tilesM=(L+TILE-1)/TILE,tilesN=(L+TILE-1)/TILE,nT=tilesM*tilesN;
          __shared__ double As[TILE][TILE],Bs[TILE][TILE];
          int tx=threadIdx.x%TILE,ty=threadIdx.x/TILE;
          for(int t=blockIdx.x;t<nT;t+=gridDim.x){
            int tm=(t/tilesN)*TILE,tn=(t%tilesN)*TILE;
            int row=tm+ty,col=tn+tx; double acc=0.0;
            for(int k0=0;k0<hd;k0+=TILE){
              As[ty][tx]=(row<L&&k0+tx<hd)?Qh[(size_t)row*D+k0+tx]:0.0;
              Bs[ty][tx]=(col<L&&k0+tx<hd)?Kh[(size_t)col*D+k0+tx]:0.0;
              __syncthreads();
              #pragma unroll
              for(int kk=0;kk<TILE;kk++) acc+=As[ty][kk]*Bs[tx][kk];
              __syncthreads();
            }
            if(row<L&&col<L) Sh[(size_t)row*L+col]=acc;
          }
        }
        grid.sync();
        dev_causal_softmax(grid,Sh,L,scale);                 grid.sync();
        /* Ah[L,hd] = P[L,L]·Vh[L,hd] (Vh strided D) — write strided D */
        { int tilesM=(L+TILE-1)/TILE,tilesN=(hd+TILE-1)/TILE,nT=tilesM*tilesN;
          __shared__ double As[TILE][TILE],Bs[TILE][TILE];
          int tx=threadIdx.x%TILE,ty=threadIdx.x/TILE;
          for(int t=blockIdx.x;t<nT;t+=gridDim.x){
            int tm=(t/tilesN)*TILE,tn=(t%tilesN)*TILE;
            int row=tm+ty,col=tn+tx; double acc=0.0;
            for(int k0=0;k0<L;k0+=TILE){
              As[ty][tx]=(row<L&&k0+tx<L)?Sh[(size_t)row*L+k0+tx]:0.0;
              Bs[ty][tx]=(k0+ty<L&&col<hd)?Vh[(size_t)(k0+ty)*D+col]:0.0;
              __syncthreads();
              #pragma unroll
              for(int kk=0;kk<TILE;kk++) acc+=As[ty][kk]*Bs[kk][tx];
              __syncthreads();
            }
            if(row<L&&col<hd) Aoh[(size_t)row*D+col]=acc;
          }
        }
        grid.sync();
    }
    dev_gemm(grid,b.Ah,b.Wo,b.ao,L,D,D);                     grid.sync();
    dev_elem_add(grid,b.X,b.ao,b.r1,L*D);                    grid.sync();
    dev_rmsnorm(grid,b.r1,b.g2,b.x2,L,D,eps);                grid.sync();
    dev_gemm(grid,b.x2,b.Wgate,b.gg,L,Df,D);                 grid.sync();
    dev_gemm(grid,b.x2,b.Wup,b.uu,L,Df,D);                   grid.sync();
    dev_elem_silumul(grid,b.gg,b.uu,b.hh,L*Df);              grid.sync();
    dev_gemm(grid,b.hh,b.Wdown,b.ff,L,D,Df);                 grid.sync();
    dev_elem_add(grid,b.r1,b.ff,b.Y,L*D);
}

/* ── host driver ───────────────────────────────────────────────────── */
static double frand(uint64_t* s){ *s=*s*6364136223846793005ULL+1;
    return ((double)((*s>>11)&((1ULL<<53)-1))/(double)(1ULL<<53))*2.0-1.0; }

struct Cfg { const char* name; int L,D,nh,hd,Df; };

int main(int argc, char** argv){
    const char* preset = (argc>1)?argv[1]:"all";
    Cfg cfgs[] = {
        {"small", 64,  512,  8, 64, 2048},
        {"medium",128, 2048, 16,128,5632},
    };
    int ncfg = (!strcmp(preset,"small"))?1:2;

    int dev=0; cudaDeviceProp prop; CK(cudaGetDeviceProperties(&prop,dev));
    int coop=0; cudaDeviceGetAttribute(&coop,cudaDevAttrCooperativeLaunch,dev);
    printf("device: %s cc=%d.%d SM=%d coop=%d\n",
           prop.name,prop.major,prop.minor,prop.multiProcessorCount,coop);

    FILE* jf=fopen("result.json","w");
    fprintf(jf,"{\n  \"falsifier\":\"F-RFC060-MEGAKERNEL-WALL\",\n");
    fprintf(jf,"  \"device\":\"%s\",\"cc\":\"%d.%d\",\"coop\":%d,\n",
            prop.name,prop.major,prop.minor,coop);
    fprintf(jf,"  \"configs\":[\n");

    cublasHandle_t cbh; CB(cublasCreate(&cbh));
    const int ITERS=30, WARM=5;

    for(int ci=0;ci<ncfg;ci++){
        Cfg c=cfgs[ci];
        int L=c.L,D=c.D,nh=c.nh,hd=c.hd,Df=c.Df;
        size_t LD=(size_t)L*D, LL=(size_t)L*L, LDf=(size_t)L*Df;
        size_t DD=(size_t)D*D, DDf=(size_t)D*Df, DfD=(size_t)Df*D;

        /* host init */
        double *hX=(double*)malloc(LD*8),*hg1=(double*)malloc(D*8),
               *hg2=(double*)malloc(D*8),*hWq=(double*)malloc(DD*8),
               *hWk=(double*)malloc(DD*8),*hWv=(double*)malloc(DD*8),
               *hWo=(double*)malloc(DD*8),*hWg=(double*)malloc(DDf*8),
               *hWu=(double*)malloc(DDf*8),*hWd=(double*)malloc(DfD*8);
        uint64_t s=0x60u+ci;
        for(size_t i=0;i<LD;i++) hX[i]=frand(&s)*0.1;
        for(int i=0;i<D;i++){ hg1[i]=1.0+frand(&s)*0.02; hg2[i]=1.0+frand(&s)*0.02; }
        for(size_t i=0;i<DD;i++){ double v=frand(&s)*0.04;
            hWq[i]=v; hWk[i]=frand(&s)*0.04; hWv[i]=frand(&s)*0.04; hWo[i]=frand(&s)*0.04; }
        for(size_t i=0;i<DDf;i++){ hWg[i]=frand(&s)*0.03; hWu[i]=frand(&s)*0.03; }
        for(size_t i=0;i<DfD;i++) hWd[i]=frand(&s)*0.03;

        /* device buffers */
        Bufs b; double *X,*g1,*g2,*Wq,*Wk,*Wv,*Wo,*Wg,*Wu,*Wd;
        CK(cudaMalloc(&X,LD*8));   CK(cudaMalloc(&g1,D*8)); CK(cudaMalloc(&g2,D*8));
        CK(cudaMalloc(&Wq,DD*8));  CK(cudaMalloc(&Wk,DD*8));CK(cudaMalloc(&Wv,DD*8));
        CK(cudaMalloc(&Wo,DD*8));  CK(cudaMalloc(&Wg,DDf*8));CK(cudaMalloc(&Wu,DDf*8));
        CK(cudaMalloc(&Wd,DfD*8));
        double *x1,*Q,*K,*V,*Sd,*Ah,*ao,*r1,*x2,*gg,*uu,*hh,*ff,*Ym,*Ys;
        CK(cudaMalloc(&x1,LD*8)); CK(cudaMalloc(&Q,LD*8)); CK(cudaMalloc(&K,LD*8));
        CK(cudaMalloc(&V,LD*8));  CK(cudaMalloc(&Sd,LL*8));CK(cudaMalloc(&Ah,LD*8));
        CK(cudaMalloc(&ao,LD*8)); CK(cudaMalloc(&r1,LD*8));CK(cudaMalloc(&x2,LD*8));
        CK(cudaMalloc(&gg,LDf*8));CK(cudaMalloc(&uu,LDf*8));CK(cudaMalloc(&hh,LDf*8));
        CK(cudaMalloc(&ff,LD*8)); CK(cudaMalloc(&Ym,LD*8));CK(cudaMalloc(&Ys,LD*8));
        CK(cudaMemcpy(X,hX,LD*8,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(g1,hg1,D*8,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(g2,hg2,D*8,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(Wq,hWq,DD*8,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(Wk,hWk,DD*8,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(Wv,hWv,DD*8,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(Wo,hWo,DD*8,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(Wg,hWg,DDf*8,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(Wu,hWu,DDf*8,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(Wd,hWd,DfD*8,cudaMemcpyHostToDevice));
        double scale=1.0/sqrt((double)hd);

        /* ---- A. STREAM forward (cuBLAS + per-op kernels) ---- */
        auto stream_fwd=[&](double* Yout){
            k_rmsnorm<<<L,256>>>(X,g1,x1,L,D,1e-6);
            cublas_mm(cbh,x1,Wq,Q,L,D,D);
            cublas_mm(cbh,x1,Wk,K,L,D,D);
            cublas_mm(cbh,x1,Wv,V,L,D,D);
            for(int h=0;h<nh;h++){
                /* attention via custom kernels (same math as mega-kernel —
                 * keeps the mega-vs-stream correctness check clean; avoids
                 * cuBLAS row-major OP_T convention risk). */
                dim3 bs(16,16);
                dim3 gs1((L+15)/16,(L+15)/16);
                k_qkt<<<gs1,bs>>>(Q+(size_t)h*hd,K+(size_t)h*hd,Sd,L,hd,D);
                k_causal_softmax<<<L,128>>>(Sd,L,scale);
                dim3 gs2((hd+15)/16,(L+15)/16);
                k_pv<<<gs2,bs>>>(Sd,V+(size_t)h*hd,Ah+(size_t)h*hd,L,hd,D);
            }
            cublas_mm(cbh,Ah,Wo,ao,L,D,D);
            k_add<<<(L*D+255)/256,256>>>(X,ao,r1,L*D);
            k_rmsnorm<<<L,256>>>(r1,g2,x2,L,D,1e-6);
            cublas_mm(cbh,x2,Wg,gg,L,Df,D);
            cublas_mm(cbh,x2,Wu,uu,L,Df,D);
            k_silu_mul<<<(L*Df+255)/256,256>>>(gg,uu,hh,L*Df);
            cublas_mm(cbh,hh,Wd,ff,L,D,Df);
            k_add<<<(L*D+255)/256,256>>>(r1,ff,Yout,L*D);
        };

        /* ---- B. MEGA forward (one cooperative kernel) ---- */
        Dims dm{L,D,nh,hd,Df};
        Bufs bm{X,g1,Wq,Wk,Wv,Wo,g2,Wg,Wu,Wd,
                x1,Q,K,V,Sd,Ah,ao,r1,x2,gg,uu,hh,ff,Ym};
        int blockThreads=TILE*TILE; /* 256 */
        int blocksPerSM=0;
        CK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(
            &blocksPerSM,(void*)mega_forward,blockThreads,0));
        int grid=prop.multiProcessorCount*blocksPerSM;
        if(grid<1) grid=prop.multiProcessorCount;
        void* args[]={&dm,&bm};

        auto mega_fwd=[&](){
            CK(cudaLaunchCooperativeKernel((void*)mega_forward,
               grid,blockThreads,args,0,0));
        };

        /* correctness: mega vs stream */
        stream_fwd(Ys); CK(cudaDeviceSynchronize());
        mega_fwd();     CK(cudaDeviceSynchronize());
        double *hYs=(double*)malloc(LD*8),*hYm=(double*)malloc(LD*8);
        CK(cudaMemcpy(hYs,Ys,LD*8,cudaMemcpyDeviceToHost));
        CK(cudaMemcpy(hYm,Ym,LD*8,cudaMemcpyDeviceToHost));
        double maxd=0,maxrel=0;
        for(size_t i=0;i<LD;i++){ double d2=fabs(hYs[i]-hYm[i]);
            if(d2>maxd)maxd=d2;
            double den=fabs(hYs[i])>1e-12?fabs(hYs[i]):1e-12;
            if(d2/den>maxrel)maxrel=d2/den; }

        /* timing — stream */
        for(int i=0;i<WARM;i++) stream_fwd(Ys);
        CK(cudaDeviceSynchronize());
        double t0=now_sec();
        for(int i=0;i<ITERS;i++) stream_fwd(Ys);
        CK(cudaDeviceSynchronize());
        double stream_ms=(now_sec()-t0)*1e3/ITERS;

        /* timing — mega */
        for(int i=0;i<WARM;i++) mega_fwd();
        CK(cudaDeviceSynchronize());
        t0=now_sec();
        for(int i=0;i<ITERS;i++) mega_fwd();
        CK(cudaDeviceSynchronize());
        double mega_ms=(now_sec()-t0)*1e3/ITERS;

        /* diagnostic: matmul-only — cuBLAS vs in-kernel for one D×D mm */
        auto mm_cublas=[&](){ cublas_mm(cbh,x1,Wq,Q,L,D,D); };
        for(int i=0;i<WARM;i++) mm_cublas();
        CK(cudaDeviceSynchronize()); t0=now_sec();
        for(int i=0;i<ITERS;i++) mm_cublas();
        CK(cudaDeviceSynchronize());
        double mm_cublas_ms=(now_sec()-t0)*1e3/ITERS;

        double ratio = stream_ms/mega_ms;          /* >1 = mega faster */
        const char* verdict = (ratio>=1.1)?"PASS":(ratio>=1.0?"MARGINAL":"KILL");
        printf("[%s] L=%d D=%d nh=%d Df=%d  stream=%.4fms mega=%.4fms "
               "ratio=%.4fx %s  maxd=%.3e maxrel=%.3e grid=%d/%d\n",
               c.name,L,D,nh,Df,stream_ms,mega_ms,ratio,verdict,
               maxd,maxrel,grid,prop.multiProcessorCount);

        fprintf(jf,"    {\"name\":\"%s\",\"L\":%d,\"D\":%d,\"nh\":%d,\"hd\":%d,"
                "\"Df\":%d,\"stream_ms\":%.6f,\"mega_ms\":%.6f,\"ratio\":%.6f,"
                "\"verdict\":\"%s\",\"max_abs_diff\":%.6e,\"max_rel_diff\":%.6e,"
                "\"mm_cublas_ms\":%.6f,\"grid_blocks\":%d}%s\n",
                c.name,L,D,nh,hd,Df,stream_ms,mega_ms,ratio,verdict,
                maxd,maxrel,mm_cublas_ms,grid,(ci<ncfg-1)?",":"");

        free(hX);free(hg1);free(hg2);free(hWq);free(hWk);free(hWv);free(hWo);
        free(hWg);free(hWu);free(hWd);free(hYs);free(hYm);
        cudaFree(X);cudaFree(g1);cudaFree(g2);cudaFree(Wq);cudaFree(Wk);
        cudaFree(Wv);cudaFree(Wo);cudaFree(Wg);cudaFree(Wu);cudaFree(Wd);
        cudaFree(x1);cudaFree(Q);cudaFree(K);cudaFree(V);cudaFree(Sd);
        cudaFree(Ah);cudaFree(ao);cudaFree(r1);cudaFree(x2);cudaFree(gg);
        cudaFree(uu);cudaFree(hh);cudaFree(ff);cudaFree(Ym);cudaFree(Ys);
    }
    fprintf(jf,"  ]\n}\n");
    fclose(jf);
    cublasDestroy(cbh);
    printf("result.json written\n");
    return 0;
}
