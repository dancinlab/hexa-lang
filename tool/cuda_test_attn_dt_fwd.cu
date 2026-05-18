/* tool/cuda_test_attn_dt_fwd.cu — mk2-C4 GQA attn-dt fwd byte-eq oracle
 *
 * Self-contained (no full hexa runtime). Mirrors EXACTLY the kernel
 * added to self/cuda/runtime_cuda.c (_hx_cuda_dt_sqrt_d +
 * _hx_cuda_dt_exp_d + _hx_cuda_kern_attn_dt_fwd) vs an in-process
 * CPU reference that mirrors runtime.c _hx_dt_sqrt_d / _hx_dt_exp_d /
 * _hx_farr_attn_dt_fwd_cpu (byte-eq with ag_tape.hexa _ag_attn_dt_fwd
 * host loop, FP_CONTRACT OFF).
 *
 * Falsifier: F-MK2C4-ATTNDT-FWD-EXACT  |Δ| == 0 across P[nh·T·T] and
 *   CTX[T·nh·hd] (bit-exact: dt_sqrt scale + stable softmax via dt_exp
 *   + strict left-to-right per-row sums, all single round-to-nearest,
 *   no FMA — __dmul_rn/__ddiv_rn/__dadd_rn on device, FP_CONTRACT OFF
 *   on host).
 *
 * Build: nvcc -arch=sm_80 -O2 -Xcompiler -ffp-contract=off \
 *             -o cuda_test_attn_dt_fwd tool/cuda_test_attn_dt_fwd.cu
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

/* ── device fns (must mirror runtime_cuda.c EXACTLY) ── */
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
__global__ void k_attn_dt_fwd(const double* __restrict__ Q,
                              const double* __restrict__ K,
                              const double* __restrict__ V,
                              double* __restrict__ P,
                              double* __restrict__ CTX,
                              int64_t T, int64_t nh, int64_t nkv, int64_t hd) {
    int64_t flat   = (int64_t)blockIdx.x*(int64_t)blockDim.x+(int64_t)threadIdx.x;
    int64_t total  = nh * T;
    int64_t stride = (int64_t)gridDim.x *(int64_t)blockDim.x;
    int64_t n_rep  = nh / nkv;
    int64_t d      = nh * hd;
    double scale = __ddiv_rn(1.0, d_dt_sqrt((double)hd));
    for (; flat < total; flat += stride) {
        int64_t hh = flat / T;
        int64_t i  = flat % T;
        int64_t kvh= hh / n_rep;
        int64_t L  = i + 1;
        for (int64_t j = 0; j < L; j++) {
            double dot = 0.0;
            for (int64_t c = 0; c < hd; c++) {
                dot = __dadd_rn(dot,
                                __dmul_rn(Q[(i*nh + hh)*hd + c],
                                          K[(j*nkv + kvh)*hd + c]));
            }
            P[(hh*T + i)*T + j] = __dmul_rn(dot, scale);
        }
        double mx = P[(hh*T + i)*T + 0];
        for (int64_t j = 1; j < L; j++) {
            double v = P[(hh*T + i)*T + j];
            if (v > mx) mx = v;
        }
        double tot = 0.0;
        for (int64_t j = 0; j < L; j++) {
            double e = d_dt_exp(P[(hh*T + i)*T + j] - mx);
            P[(hh*T + i)*T + j] = e;
            tot = __dadd_rn(tot, e);
        }
        for (int64_t j = 0; j < L; j++) {
            P[(hh*T + i)*T + j] = __ddiv_rn(P[(hh*T + i)*T + j], tot);
        }
        for (int64_t c2 = 0; c2 < hd; c2++) {
            double acc = 0.0;
            for (int64_t j = 0; j < L; j++) {
                acc = __dadd_rn(acc,
                                __dmul_rn(P[(hh*T + i)*T + j],
                                          V[(j*nkv + kvh)*hd + c2]));
            }
            CTX[i*d + hh*hd + c2] = acc;
        }
    }
}

/* ── CPU reference ── */
static double h_dt_sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double g = x > 1.0 ? x : 1.0;
    int i = 0;
    while (i < 24) { g = 0.5 * (g + x / g); i = i + 1; }
    return g;
}
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
static void cpu_attn_dt_fwd(const double* Q, const double* K, const double* V,
                            double* P, double* C,
                            int64_t T, int64_t nh, int64_t nkv, int64_t hd) {
    int64_t n_rep = nh / nkv;
    int64_t d     = nh * hd;
    double scale = 1.0 / h_dt_sqrt((double)hd);
    for (int64_t hh = 0; hh < nh; hh++) {
        int64_t kvh = hh / n_rep;
        for (int64_t i = 0; i < T; i++) {
            int64_t L = i + 1;
            for (int64_t j = 0; j < L; j++) {
                double dot = 0.0;
                for (int64_t c = 0; c < hd; c++) {
                    dot = dot + Q[(i*nh + hh)*hd + c] * K[(j*nkv + kvh)*hd + c];
                }
                P[(hh*T + i)*T + j] = dot * scale;
            }
            double mx = P[(hh*T + i)*T + 0];
            for (int64_t j = 1; j < L; j++) {
                double v = P[(hh*T + i)*T + j];
                if (v > mx) mx = v;
            }
            double tot = 0.0;
            for (int64_t j = 0; j < L; j++) {
                double e = h_dt_exp(P[(hh*T + i)*T + j] - mx);
                P[(hh*T + i)*T + j] = e;
                tot = tot + e;
            }
            for (int64_t j = 0; j < L; j++) {
                P[(hh*T + i)*T + j] = P[(hh*T + i)*T + j] / tot;
            }
            for (int64_t c2 = 0; c2 < hd; c2++) {
                double acc = 0.0;
                for (int64_t j = 0; j < L; j++) {
                    acc = acc + P[(hh*T + i)*T + j] * V[(j*nkv + kvh)*hd + c2];
                }
                C[i*d + hh*hd + c2] = acc;
            }
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
    int64_t T   = 256;   /* keep memory modest for the default oracle */
    int64_t nh  = 12;
    int64_t nkv = 4;
    int64_t hd  = 64;
    if (argc > 1) { long p=strtol(argv[1],NULL,10); if(p>0) T=p; }
    if (argc > 2) { long p=strtol(argv[2],NULL,10); if(p>0) nh=p; }
    if (argc > 3) { long p=strtol(argv[3],NULL,10); if(p>0) nkv=p; }
    if (argc > 4) { long p=strtol(argv[4],NULL,10); if(p>0) hd=p; }
    int64_t nq = T * nh  * hd;
    int64_t nk = T * nkv * hd;
    int64_t np = nh * T * T;
    printf("[T] attn-dt fwd test — T=%lld nh=%lld nkv=%lld hd=%lld (nq=%lld np=%lld)\n",
           (long long)T,(long long)nh,(long long)nkv,(long long)hd,
           (long long)nq,(long long)np);

    double *hQ=(double*)malloc((size_t)nq*8);
    double *hK=(double*)malloc((size_t)nk*8);
    double *hV=(double*)malloc((size_t)nk*8);
    double *hPc=(double*)calloc((size_t)np,8);
    double *hCc=(double*)malloc((size_t)nq*8);
    double *hPg=(double*)malloc((size_t)np*8);
    double *hCg=(double*)malloc((size_t)nq*8);
    if(!hQ||!hK||!hV||!hPc||!hCc||!hPg||!hCg){
        fprintf(stderr,"[T] malloc fail\n"); return 2;
    }
    uint64_t s1=0x1234567890abcdefULL;
    for (int64_t i=0;i<nq;i++) hQ[i]=(lcg_next(&s1)-0.5)*1.0;
    for (int64_t i=0;i<nk;i++) hK[i]=(lcg_next(&s1)-0.5)*1.0;
    for (int64_t i=0;i<nk;i++) hV[i]=(lcg_next(&s1)-0.5)*1.0;

    double *dQ,*dK,*dV,*dP,*dC;
    CK(cudaMalloc(&dQ,(size_t)nq*8));
    CK(cudaMalloc(&dK,(size_t)nk*8));
    CK(cudaMalloc(&dV,(size_t)nk*8));
    CK(cudaMalloc(&dP,(size_t)np*8));
    CK(cudaMalloc(&dC,(size_t)nq*8));
    CK(cudaMemcpy(dQ,hQ,(size_t)nq*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dK,hK,(size_t)nk*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dV,hV,(size_t)nk*8,cudaMemcpyHostToDevice));
    CK(cudaMemset(dP,0,(size_t)np*8));   /* upper triangle stays 0 */

    cpu_attn_dt_fwd(hQ,hK,hV,hPc,hCc,T,nh,nkv,hd);

    int64_t total = nh * T;
    int block = 64;
    int64_t need = (total + block - 1)/block;
    int grid = (int)(need<1?1:(need>65535?65535:need));
    k_attn_dt_fwd<<<grid,block>>>(dQ,dK,dV,dP,dC,T,nh,nkv,hd);  CK(cudaGetLastError());
    CK(cudaMemcpy(hPg,dP,(size_t)np*8,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hCg,dC,(size_t)nq*8,cudaMemcpyDeviceToHost));

    double md_p = max_abs_diff(hPc,hPg,np);
    double md_c = max_abs_diff(hCc,hCg,nq);
    int beq_p = byte_equal(hPc,hPg,np);
    int beq_c = byte_equal(hCc,hCg,nq);
    int pass  = (md_p==0.0) && (md_c==0.0) && beq_p && beq_c;
    printf("[F-MK2C4-ATTNDT-FWD-P]   max|D|=%.3e byte_eq=%d (req=1)\n", md_p, beq_p);
    printf("[F-MK2C4-ATTNDT-FWD-CTX] max|D|=%.3e byte_eq=%d (req=1)\n", md_c, beq_c);
    printf("[F-MK2C4-ATTNDT-FWD-VERDICT] %s\n", pass?"PASS":"FAIL");

    cudaFree(dQ);cudaFree(dK);cudaFree(dV);cudaFree(dP);cudaFree(dC);
    free(hQ);free(hK);free(hV);free(hPc);free(hCc);free(hPg);free(hCg);
    if (pass) { printf("\n[T] ALL-PASS — attn-dt fwd GPU byte-eq (T=%lld)\n",
                (long long)T); return 0; }
    printf("\n[T] FAIL — attn-dt fwd GPU byte-eq\n"); return 1;
}
