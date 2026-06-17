/* HEXA-FUSION MEGAKERNEL-GN-GRIDSYNC byte-eq harness.
 *
 * Closes the 2nd megakernel wall: GroupNorm full-Y reduction (G=1 over all T*C).
 * Runs the EXISTING sequential _hx_k_groupnorm (oracle, extracted verbatim from
 * runtime_cuda_emit.hexa / kit runtime_cuda.c) AND the new cooperative grid-synced
 * _hx_k_groupnorm_coop (cudaLaunchCooperativeKernel + this_grid().sync()), on the
 * IDENTICAL input, and asserts max|delta| == 0 on Y / XHAT / MEAN / INV.
 *
 * HARD GATE (g5): byte-eq max|delta| = 0 vs the sequential GN oracle BEFORE anything
 * else. The cooperative reduction must reproduce the sequential GN bit-for-bit (it does
 * NOT re-associate: the reduction stays single-thread sequential in host order; the
 * grid.sync() only broadcasts mu/inv before the embarrassingly-parallel normalize).
 *
 * Also reports: cooperative-launch supported Y/N (cudaDevAttrCooperativeLaunch),
 * one-wave grid fit (cudaOccupancyMaxActiveBlocksPerMultiprocessor * SM count).
 */
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cmath>
#include <cuda_runtime.h>
#include <cooperative_groups.h>
namespace _hxcg = cooperative_groups;

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

/* ---- ORACLE: sequential GroupNorm (verbatim _hx_k_groupnorm) ---- */
__global__ void _hx_k_groupnorm(const double* __restrict__ X,
                                const double* __restrict__ GAMMA,
                                const double* __restrict__ BETA,
                                double* __restrict__ Y,
                                double* __restrict__ MEAN,
                                double* __restrict__ INV,
                                double* __restrict__ XHAT,
                                int64_t T, int64_t C, int64_t G) {
    const double eps = 0.00001;
    int64_t cg = C / G;
    double m = (double)(cg * T);
    for (int64_t g = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         g < G; g += (int64_t)blockDim.x * gridDim.x) {
        int64_t c0 = g * cg;
        double sum = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++)
                sum += X[t * C + (c0 + c)];
        double mu = sum / m;
        double vs = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) {
                double d = X[t * C + (c0 + c)] - mu;
                vs += d * d;
            }
        double var = vs / m;
        double inv = 1.0 / _hx_gn_sqrt_dev(var + eps);
        MEAN[g] = mu;
        INV[g]  = inv;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) {
                int64_t ch = c0 + c;
                double xh = (X[t * C + ch] - mu) * inv;
                XHAT[t * C + ch] = xh;
                Y[t * C + ch] = GAMMA[ch] * xh + BETA[ch];
            }
    }
}

/* ---- COOP: cooperative grid-synced GroupNorm (verbatim _hx_k_groupnorm_coop) ---- */
__global__ void _hx_k_groupnorm_coop(const double* __restrict__ X,
                                     const double* __restrict__ GAMMA,
                                     const double* __restrict__ BETA,
                                     double* __restrict__ Y,
                                     double* __restrict__ MEAN,
                                     double* __restrict__ INV,
                                     double* __restrict__ XHAT,
                                     int64_t T, int64_t C, int64_t G) {
    _hxcg::grid_group grid = _hxcg::this_grid();
    const double eps = 0.00001;
    int64_t cg = C / G;
    double m = (double)(cg * T);
    int64_t rank = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    int64_t gridsz = (int64_t)blockDim.x * gridDim.x;
    /* PHASE 1 — reduction: one thread per group, SEQUENTIAL host order, no re-assoc. */
    for (int64_t g = rank; g < G; g += gridsz) {
        int64_t c0 = g * cg;
        double sum = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++)
                sum += X[t * C + (c0 + c)];
        double mu = sum / m;
        double vs = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) {
                double d = X[t * C + (c0 + c)] - mu;
                vs += d * d;
            }
        double var = vs / m;
        double inv = 1.0 / _hx_gn_sqrt_dev(var + eps);
        MEAN[g] = mu;
        INV[g]  = inv;
    }
    grid.sync();
    /* PHASE 2 — normalize: embarrassingly parallel, no reduction. */
    int64_t TC = T * C;
    for (int64_t idx = rank; idx < TC; idx += gridsz) {
        int64_t ch = idx % C;
        int64_t g  = ch / cg;
        double mu  = MEAN[g];
        double inv = INV[g];
        double xh  = (X[idx] - mu) * inv;
        XHAT[idx]  = xh;
        Y[idx]     = GAMMA[ch] * xh + BETA[ch];
    }
}

static int run_case(int64_t T, int64_t C, int64_t G, unsigned seed) {
    int64_t TC = T * C;
    double *hX = (double*)malloc(TC*sizeof(double));
    double *hGAMMA = (double*)malloc(C*sizeof(double));
    double *hBETA = (double*)malloc(C*sizeof(double));
    srand(seed);
    for (int64_t i=0;i<TC;i++) hX[i] = ((double)rand()/RAND_MAX)*4.0-2.0;
    for (int64_t c=0;c<C;c++){ hGAMMA[c]=((double)rand()/RAND_MAX)*2.0-1.0;
                               hBETA[c]=((double)rand()/RAND_MAX)*2.0-1.0; }
    double *X,*GA,*BE,*Ys,*MEs,*INs,*XHs,*Yc,*MEc,*INc,*XHc;
    CK(cudaMalloc(&X,TC*sizeof(double)));   CK(cudaMalloc(&GA,C*sizeof(double)));
    CK(cudaMalloc(&BE,C*sizeof(double)));
    CK(cudaMalloc(&Ys,TC*sizeof(double)));  CK(cudaMalloc(&MEs,G*sizeof(double)));
    CK(cudaMalloc(&INs,G*sizeof(double)));  CK(cudaMalloc(&XHs,TC*sizeof(double)));
    CK(cudaMalloc(&Yc,TC*sizeof(double)));  CK(cudaMalloc(&MEc,G*sizeof(double)));
    CK(cudaMalloc(&INc,G*sizeof(double)));  CK(cudaMalloc(&XHc,TC*sizeof(double)));
    CK(cudaMemcpy(X,hX,TC*sizeof(double),cudaMemcpyHostToDevice));
    CK(cudaMemcpy(GA,hGAMMA,C*sizeof(double),cudaMemcpyHostToDevice));
    CK(cudaMemcpy(BE,hBETA,C*sizeof(double),cudaMemcpyHostToDevice));

    /* ORACLE launch (sequential, same grid sizing as runtime). */
    int block_sz=64; int64_t want=(G+block_sz-1)/block_sz;
    int grid_seq=(want>1024)?1024:(int)want; if(grid_seq<1)grid_seq=1;
    _hx_k_groupnorm<<<grid_seq,block_sz>>>(X,GA,BE,Ys,MEs,INs,XHs,T,C,G);
    CK(cudaDeviceSynchronize());

    /* COOP launch — one-wave grid via occupancy. */
    int dev=0; CK(cudaGetDevice(&dev));
    int coop=0; CK(cudaDeviceGetAttribute(&coop,cudaDevAttrCooperativeLaunch,dev));
    int numSM=0; CK(cudaDeviceGetAttribute(&numSM,cudaDevAttrMultiProcessorCount,dev));
    int bpsm=0;
    CK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(&bpsm,(const void*)_hx_k_groupnorm_coop,block_sz,0));
    if(bpsm<1)bpsm=1;
    int max_grid=numSM*bpsm; if(max_grid<1)max_grid=1;
    int64_t wantc=(TC+block_sz-1)/block_sz;
    int grid_coop=(wantc>(int64_t)max_grid)?max_grid:(int)wantc; if(grid_coop<1)grid_coop=1;
    printf("  [case T=%lld C=%lld G=%lld] coop_supported=%d numSM=%d blocks/SM=%d "
           "max_wave_grid=%d coop_grid=%d (fits_one_wave=%d)\n",
           (long long)T,(long long)C,(long long)G,coop,numSM,bpsm,max_grid,grid_coop,
           (grid_coop<=max_grid));
    if(!coop){ printf("  [SKIP] device lacks cooperative launch\n"); return 3; }

    void* args[]={(void*)&X,(void*)&GA,(void*)&BE,(void*)&Yc,(void*)&MEc,
                  (void*)&INc,(void*)&XHc,(void*)&T,(void*)&C,(void*)&G};
    dim3 gd(grid_coop,1,1), bd(block_sz,1,1);
    cudaError_t le=cudaLaunchCooperativeKernel((const void*)_hx_k_groupnorm_coop,gd,bd,args,0,0);
    if(le!=cudaSuccess){ fprintf(stderr,"  coop launch FAILED: %s\n",cudaGetErrorString(le)); return 2; }
    CK(cudaDeviceSynchronize());

    /* byte-eq compare (bit-for-bit via memcmp + max ULP/abs delta). */
    double *Y1=(double*)malloc(TC*sizeof(double)),*Y2=(double*)malloc(TC*sizeof(double));
    double *X1=(double*)malloc(TC*sizeof(double)),*X2=(double*)malloc(TC*sizeof(double));
    double *M1=(double*)malloc(G*sizeof(double)),*M2=(double*)malloc(G*sizeof(double));
    double *I1=(double*)malloc(G*sizeof(double)),*I2=(double*)malloc(G*sizeof(double));
    CK(cudaMemcpy(Y1,Ys,TC*sizeof(double),cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(Y2,Yc,TC*sizeof(double),cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(X1,XHs,TC*sizeof(double),cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(X2,XHc,TC*sizeof(double),cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(M1,MEs,G*sizeof(double),cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(M2,MEc,G*sizeof(double),cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(I1,INs,G*sizeof(double),cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(I2,INc,G*sizeof(double),cudaMemcpyDeviceToHost));
    double maxd=0.0; long bitdiff=0;
    for(int64_t i=0;i<TC;i++){ double d=fabs(Y1[i]-Y2[i]); if(d>maxd)maxd=d;
        if(memcmp(&Y1[i],&Y2[i],sizeof(double))!=0)bitdiff++;
        d=fabs(X1[i]-X2[i]); if(d>maxd)maxd=d;
        if(memcmp(&X1[i],&X2[i],sizeof(double))!=0)bitdiff++; }
    for(int64_t g=0;g<G;g++){ double d=fabs(M1[g]-M2[g]); if(d>maxd)maxd=d;
        if(memcmp(&M1[g],&M2[g],sizeof(double))!=0)bitdiff++;
        d=fabs(I1[g]-I2[g]); if(d>maxd)maxd=d;
        if(memcmp(&I1[g],&I2[g],sizeof(double))!=0)bitdiff++; }
    printf("  -> max|delta|=%.17g  bitdiff_words=%ld  %s\n",maxd,bitdiff,
           (maxd==0.0&&bitdiff==0)?"BYTE-EQ PASS":"BYTE-EQ FAIL");
    free(hX);free(hGAMMA);free(hBETA);free(Y1);free(Y2);free(X1);free(X2);
    free(M1);free(M2);free(I1);free(I2);
    cudaFree(X);cudaFree(GA);cudaFree(BE);cudaFree(Ys);cudaFree(MEs);cudaFree(INs);
    cudaFree(XHs);cudaFree(Yc);cudaFree(MEc);cudaFree(INc);cudaFree(XHc);
    return (maxd==0.0&&bitdiff==0)?0:1;
}

int main(){
    int dev=0; cudaGetDevice(&dev);
    cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);
    printf("HEXA-FUSION MEGAKERNEL-GN-GRIDSYNC byte-eq gate\n");
    printf("device: %s  sm_%d%d\n",p.name,p.major,p.minor);
    int rc=0;
    /* G=1 is THE megakernel case (full-Y reduction over all T*C). Plus G>1 sanity. */
    rc |= run_case(1536,1536,1, 12345u);  /* clm_prod D1536 shape, G=1 whole-tensor */
    rc |= run_case(256, 512, 1, 777u);
    rc |= run_case(128, 256, 4, 999u);    /* G>1 multi-group */
    rc |= run_case(64,  128, 1, 42u);
    if((rc&1)==0) printf("\nALL CASES BYTE-EQ PASS (max|delta|=0)\n");
    else          printf("\nBYTE-EQ FAIL on >=1 case\n");
    return rc;
}
