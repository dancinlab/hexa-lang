/* tool/cuda_test_rmsnorm_mh.cu — mk2-C2 rmsnorm-mh GPU byte-eq oracle
 *
 * Self-contained (no full hexa runtime). Mirrors EXACTLY the kernel
 * added to self/cuda/runtime_cuda.c (_hx_cuda_dt_sqrt_d +
 * _hx_cuda_kern_rmsnorm_mh) and runs it vs an in-process CPU
 * reference that mirrors runtime.c _hx_dt_sqrt_d /
 * _hx_farr_rmsnorm_mh_cpu (byte-eq to hexa ag_tape::ag_rmsnorm_mh
 * host-scalar loop, FP_CONTRACT OFF).
 *
 * Falsifier: F-MK2C2-RMSNORM-EXACT  |Δ| == 0 across y[T·d], xn[T·d],
 *   inv[T] (bit-exact: dt_sqrt Newton-24 mirror + strict left-to-right
 *   per-row sum, all single round-to-nearest, no FMA — __dmul_rn /
 *   __ddiv_rn / __dadd_rn on device, FP_CONTRACT OFF on host).
 *
 * Build: nvcc -arch=sm_80 -O2 -Xcompiler -ffp-contract=off \
 *             -o cuda_test_rmsnorm_mh tool/cuda_test_rmsnorm_mh.cu
 * Exit 0 = ALL-PASS.
 */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <cuda_runtime.h>

#define CK(call) do { cudaError_t _e=(call); if(_e!=cudaSuccess){ \
  fprintf(stderr,"[T] CUDA %s:%d %s\n",__FILE__,__LINE__, \
  cudaGetErrorString(_e)); exit(2);} } while(0)

/* ── device kernel duplicates (must mirror runtime_cuda.c EXACTLY) ── */
__device__ __forceinline__ double d_dt_sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double g = x > 1.0 ? x : 1.0;
    int i = 0;
    while (i < 24) {
        g = __dmul_rn(0.5, __dadd_rn(g, __ddiv_rn(x, g)));
        i = i + 1;
    }
    return g;
}
__global__ void k_rmsnorm_mh(const double* __restrict__ X,
                             const double* __restrict__ G,
                             double* __restrict__ Y,
                             double* __restrict__ XN,
                             double* __restrict__ I,
                             int64_t T, int64_t d) {
    int64_t i      = (int64_t)blockIdx.x*(int64_t)blockDim.x+(int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x *(int64_t)blockDim.x;
    const double eps = 0.000001;
    for (; i < T; i += stride) {
        double ms = 0.0;
        for (int64_t c = 0; c < d; c++) {
            double xv = X[i*d + c];
            ms = __dadd_rn(ms, __dmul_rn(xv, xv));
        }
        ms = __ddiv_rn(ms, (double)d);
        double iv = __ddiv_rn(1.0, d_dt_sqrt(__dadd_rn(ms, eps)));
        I[i] = iv;
        for (int64_t c = 0; c < d; c++) {
            double xni = __dmul_rn(X[i*d + c], iv);
            XN[i*d + c] = xni;
            Y[i*d + c]  = __dmul_rn(G[c], xni);
        }
    }
}

/* ── CPU reference (mirror runtime.c _hx_dt_sqrt_d / rmsnorm_mh_cpu) ── */
static double h_dt_sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double g = x > 1.0 ? x : 1.0;
    int i = 0;
    while (i < 24) { g = 0.5 * (g + x / g); i = i + 1; }
    return g;
}
static void cpu_rmsnorm_mh(const double* X, const double* G,
                           double* Y, double* XN, double* I,
                           int64_t T, int64_t d) {
    const double eps = 0.000001;
    for (int64_t i = 0; i < T; i++) {
        double ms = 0.0;
        for (int64_t c = 0; c < d; c++) {
            double xv = X[i*d + c];
            ms = ms + xv * xv;
        }
        ms = ms / (double)d;
        double iv = 1.0 / h_dt_sqrt(ms + eps);
        I[i] = iv;
        for (int64_t c = 0; c < d; c++) {
            double xni = X[i*d + c] * iv;
            XN[i*d + c] = xni;
            Y[i*d + c]  = G[c] * xni;
        }
    }
}

static double lcg_next(uint64_t* st) {
    *st = (*st)*6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(((*st)>>11)&0x1FFFFFFFFFFFFFULL)/(double)(1ULL<<53);
}
static double max_abs_diff(const double* a, const double* b, int64_t n) {
    double m=0.0; for(int64_t i=0;i<n;i++){double dd=fabs(a[i]-b[i]); if(dd>m)m=dd;}
    return m;
}
static int byte_equal(const double* a, const double* b, int64_t n) {
    return memcmp(a,b,(size_t)n*sizeof(double))==0;
}

int main(int argc, char** argv) {
    int64_t T = 1024;
    int64_t d = 768;
    if (argc > 1) { long p=strtol(argv[1],NULL,10); if(p>0) T=p; }
    if (argc > 2) { long p=strtol(argv[2],NULL,10); if(p>0) d=p; }
    int64_t n_xy = T * d;
    printf("[T] rmsnorm-mh test — T=%lld d=%lld\n",(long long)T,(long long)d);

    double *hX=(double*)malloc((size_t)n_xy*8);
    double *hG=(double*)malloc((size_t)d*8);
    double *hYc=(double*)malloc((size_t)n_xy*8);
    double *hXNc=(double*)malloc((size_t)n_xy*8);
    double *hIc=(double*)malloc((size_t)T*8);
    double *hYg=(double*)malloc((size_t)n_xy*8);
    double *hXNg=(double*)malloc((size_t)n_xy*8);
    double *hIg=(double*)malloc((size_t)T*8);
    double *hYg2=(double*)malloc((size_t)n_xy*8);
    if(!hX||!hG||!hYc||!hXNc||!hIc||!hYg||!hXNg||!hIg||!hYg2){
        fprintf(stderr,"[T] malloc fail\n"); return 2;
    }
    uint64_t s1=0x1234567890abcdefULL;
    for (int64_t i=0;i<n_xy;i++) hX[i]=(lcg_next(&s1)-0.5)*2.0;   /* [-1,1] */
    for (int64_t c=0;c<d;c++)    hG[c]=(lcg_next(&s1)-0.5)*0.4 + 1.0; /* g≈1 */

    double *dX,*dG,*dY,*dXN,*dI,*dY2,*dXN2,*dI2;
    CK(cudaMalloc(&dX,(size_t)n_xy*8)); CK(cudaMalloc(&dG,(size_t)d*8));
    CK(cudaMalloc(&dY,(size_t)n_xy*8)); CK(cudaMalloc(&dXN,(size_t)n_xy*8));
    CK(cudaMalloc(&dI,(size_t)T*8));
    CK(cudaMalloc(&dY2,(size_t)n_xy*8)); CK(cudaMalloc(&dXN2,(size_t)n_xy*8));
    CK(cudaMalloc(&dI2,(size_t)T*8));
    CK(cudaMemcpy(dX,hX,(size_t)n_xy*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dG,hG,(size_t)d*8,cudaMemcpyHostToDevice));

    cpu_rmsnorm_mh(hX,hG,hYc,hXNc,hIc,T,d);

    int block = 256;
    int64_t need = (T + block - 1)/block;
    int grid = (int)(need<1?1:(need>65535?65535:need));
    k_rmsnorm_mh<<<grid,block>>>(dX,dG,dY,dXN,dI,T,d);   CK(cudaGetLastError());
    CK(cudaMemcpy(hYg ,dY ,(size_t)n_xy*8,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hXNg,dXN,(size_t)n_xy*8,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hIg ,dI ,(size_t)T   *8,cudaMemcpyDeviceToHost));
    /* second run for nondeterminism check (Y only) */
    k_rmsnorm_mh<<<grid,block>>>(dX,dG,dY2,dXN2,dI2,T,d); CK(cudaGetLastError());
    CK(cudaMemcpy(hYg2,dY2,(size_t)n_xy*8,cudaMemcpyDeviceToHost));

    double md_y = max_abs_diff(hYc, hYg , n_xy);
    double md_x = max_abs_diff(hXNc,hXNg, n_xy);
    double md_i = max_abs_diff(hIc, hIg , T);
    int beq_y = byte_equal(hYc, hYg , n_xy);
    int beq_x = byte_equal(hXNc,hXNg, n_xy);
    int beq_i = byte_equal(hIc, hIg , T);
    int det   = byte_equal(hYg, hYg2, n_xy);
    int pass  = (md_y==0.0) && (md_x==0.0) && (md_i==0.0) && beq_y && beq_x && beq_i && det;
    printf("[F-MK2C2-RMSNORM-EXACT-Y]   max|D|=%.3e byte_eq=%d (req=1)\n", md_y, beq_y);
    printf("[F-MK2C2-RMSNORM-EXACT-XN]  max|D|=%.3e byte_eq=%d (req=1)\n", md_x, beq_x);
    printf("[F-MK2C2-RMSNORM-EXACT-INV] max|D|=%.3e byte_eq=%d (req=1)\n", md_i, beq_i);
    printf("[F-MK2C2-RMSNORM-DET]       det_byte_eq=%d (req=1)\n", det);
    printf("[F-MK2C2-RMSNORM-VERDICT]   %s\n", pass?"PASS":"FAIL");

    cudaFree(dX);cudaFree(dG);cudaFree(dY);cudaFree(dXN);cudaFree(dI);
    cudaFree(dY2);cudaFree(dXN2);cudaFree(dI2);
    free(hX);free(hG);free(hYc);free(hXNc);free(hIc);
    free(hYg);free(hXNg);free(hIg);free(hYg2);
    if(pass){ printf("\n[T] ALL-PASS — rmsnorm-mh GPU byte-eq (T=%lld d=%lld)\n",
              (long long)T,(long long)d); return 0; }
    printf("\n[T] FAIL — rmsnorm-mh GPU byte-eq\n"); return 1;
}
