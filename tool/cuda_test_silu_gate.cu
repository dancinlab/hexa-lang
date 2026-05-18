/* tool/cuda_test_silu_gate.cu — mk2-C1b silu-gate GPU byte-eq oracle
 *
 * Self-contained (no full hexa runtime). Mirrors EXACTLY the kernel
 * added to self/cuda/runtime_cuda.c (_hx_cuda_dt_exp_d +
 * _hx_cuda_kern_silu_gate) and runs it vs an in-process CPU
 * reference that mirrors runtime.c _hx_dt_exp_d / _hx_farr_silu_
 * gate_cpu (which Mac flame_ag_tape_test Test 11 already proved
 * bit-exact to hexa dt_exp / _ag_silu(a)*b).
 *
 * Falsifier: F-MK2C1B-SILUGATE-EXACT  |Δ| == 0 (bit-exact: the
 *   dt_exp Taylor mirror + (a·σ(a))·b, all single round-to-nearest,
 *   no FMA — __dmul_rn/__ddiv_rn/__dadd_rn on device, FP_CONTRACT
 *   OFF on host).
 *
 * Build (CUDA host): nvcc -arch=sm_80 -O2 -Xcompiler -ffp-contract=off \
 *                          -o cuda_test_silu_gate tool/cuda_test_silu_gate.cu
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
#define _ELEM_BLOCK 256

/* ── device kernel duplicates (must mirror runtime_cuda.c EXACTLY) ── */
__device__ __forceinline__ double d_dt_exp(double x) {
    int r = 0;
    double xr = x;
    while ((xr > 0.0 ? xr : 0.0 - xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0;
    double acc  = 1.0;
    int k = 1;
    while (k < 12) {
        term = __ddiv_rn(__dmul_rn(term, xr), (double)k);
        acc  = __dadd_rn(acc, term);
        k = k + 1;
    }
    int s = 0;
    while (s < r) { acc = __dmul_rn(acc, acc); s = s + 1; }
    return acc;
}
__global__ void k_silu_gate(const double* __restrict__ A,
                            const double* __restrict__ B,
                            double* __restrict__ O, int64_t n) {
    int64_t i      = (int64_t)blockIdx.x*(int64_t)blockDim.x+(int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x *(int64_t)blockDim.x;
    for (; i < n; i += stride) {
        double ai  = A[i];
        double sig = 1.0 / (1.0 + d_dt_exp(0.0 - ai));
        O[i] = __dmul_rn(__dmul_rn(ai, sig), B[i]);
    }
}

/* ── CPU reference (mirror runtime.c _hx_dt_exp_d / silu_gate_cpu) ── */
static double h_dt_exp(double x) {
    int r = 0;
    double xr = x;
    while ((xr > 0.0 ? xr : 0.0 - xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0, acc = 1.0;
    int k = 1;
    while (k < 12) { term = term * xr / (double)k; acc = acc + term; k = k + 1; }
    int s = 0;
    while (s < r) { acc = acc * acc; s = s + 1; }
    return acc;
}
static void cpu_silu_gate(const double* A, const double* B,
                          double* O, int64_t n) {
    for (int64_t i = 0; i < n; i++) {
        double ai  = A[i];
        double sig = 1.0 / (1.0 + h_dt_exp(0.0 - ai));
        O[i] = (ai * sig) * B[i];
    }
}

static double lcg_next(uint64_t* st) {
    *st = (*st)*6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(((*st)>>11)&0x1FFFFFFFFFFFFFULL)/(double)(1ULL<<53);
}
static double max_abs_diff(const double* a, const double* b, int64_t n) {
    double m=0.0; for(int64_t i=0;i<n;i++){double d=fabs(a[i]-b[i]); if(d>m)m=d;}
    return m;
}
static int byte_equal(const double* a, const double* b, int64_t n) {
    return memcmp(a,b,(size_t)n*sizeof(double))==0;
}

int main(int argc, char** argv) {
    int64_t n = 786432;                 /* d768-class: T·h-ish */
    if (argc > 1) { long p=strtol(argv[1],NULL,10); if(p>0) n=p; }
    int grid=(int)((n+_ELEM_BLOCK-1)/_ELEM_BLOCK); if(grid<1)grid=1;
    if(grid>65535)grid=65535;
    printf("[T] silu-gate test — n=%lld\n",(long long)n);

    double *hA=(double*)malloc((size_t)n*8), *hB=(double*)malloc((size_t)n*8);
    double *hC=(double*)malloc((size_t)n*8), *hG=(double*)malloc((size_t)n*8);
    double *hG2=(double*)malloc((size_t)n*8);
    if(!hA||!hB||!hC||!hG||!hG2){fprintf(stderr,"[T] malloc fail\n");return 2;}
    uint64_t s1=0x1234567890abcdefULL;
    for(int64_t i=0;i<n;i++){ hA[i]=(lcg_next(&s1)-0.5)*8.0;     /* [-4,4] */
                              hB[i]=(lcg_next(&s1)-0.5)*4.0; }   /* [-2,2] */

    double *dA,*dB,*dO,*dO2;
    CK(cudaMalloc(&dA,(size_t)n*8)); CK(cudaMalloc(&dB,(size_t)n*8));
    CK(cudaMalloc(&dO,(size_t)n*8)); CK(cudaMalloc(&dO2,(size_t)n*8));
    CK(cudaMemcpy(dA,hA,(size_t)n*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,(size_t)n*8,cudaMemcpyHostToDevice));

    cpu_silu_gate(hA,hB,hC,n);
    k_silu_gate<<<grid,_ELEM_BLOCK>>>(dA,dB,dO,n);  CK(cudaGetLastError());
    CK(cudaMemcpy(hG,dO,(size_t)n*8,cudaMemcpyDeviceToHost));
    k_silu_gate<<<grid,_ELEM_BLOCK>>>(dA,dB,dO2,n); CK(cudaGetLastError());
    CK(cudaMemcpy(hG2,dO2,(size_t)n*8,cudaMemcpyDeviceToHost));

    double md = max_abs_diff(hC,hG,n);
    int beq   = byte_equal(hC,hG,n);
    int det   = byte_equal(hG,hG2,n);
    int pass  = (md==0.0) && beq && det;
    printf("[F-MK2C1B-SILUGATE-EXACT] max|D|=%.3e tol=0.000e+00 "
           "byte_eq=%d (req=1) det_byte_eq=%d => %s\n",
           md, beq, det, pass?"PASS":"FAIL");

    cudaFree(dA);cudaFree(dB);cudaFree(dO);cudaFree(dO2);
    free(hA);free(hB);free(hC);free(hG);free(hG2);
    if(pass){ printf("\n[T] ALL-PASS — silu-gate GPU byte-eq (n=%lld)\n",
              (long long)n); return 0; }
    printf("\n[T] FAIL — silu-gate GPU byte-eq\n"); return 1;
}
