/* tool/cuda_test_attn_dt_bwd.cu — mk2-C4-bwd GQA attn-dt bwd byte-eq oracle
 *
 * Self-contained: mirrors EXACTLY the kernels in self/cuda/
 * runtime_cuda.c (`_hx_cuda_kern_attn_dt_bwd_dProw / _dS_dQ / _dV /
 * _dK` + the `_hx_cuda_dt_sqrt_d` device fn) vs an in-process CPU
 * reference that mirrors runtime.c `_hx_farr_attn_dt_bwd_cpu`
 * (byte-eq with ag_tape.hexa _ag_attn_dt_bwd host loop, FP_CONTRACT
 * OFF).
 *
 * Falsifier: F-MK2C4-ATTNDT-BWD-EXACT  |Δ| == 0 across dQ[T·nh·hd],
 *   dK[T·nkv·hd], dV[T·nkv·hd].
 *
 * Build: nvcc -arch=sm_80 -O2 -Xcompiler -ffp-contract=off \
 *             -o cuda_test_attn_dt_bwd tool/cuda_test_attn_dt_bwd.cu
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

__global__ void k_dProw(const double* __restrict__ V,
                        const double* __restrict__ dctx,
                        double* __restrict__ dProw,
                        int64_t T, int64_t nh, int64_t nkv, int64_t hd) {
    int64_t flat   = (int64_t)blockIdx.x*(int64_t)blockDim.x+(int64_t)threadIdx.x;
    int64_t total  = nh * T * T;
    int64_t stride = (int64_t)gridDim.x *(int64_t)blockDim.x;
    int64_t n_rep  = nh / nkv;
    int64_t d      = nh * hd;
    for (; flat < total; flat += stride) {
        int64_t hh = flat / (T * T);
        int64_t r  = flat - hh * T * T;
        int64_t i  = r / T;
        int64_t j  = r - i * T;
        if (j > i) { dProw[flat] = 0.0; continue; }
        int64_t kvh = hh / n_rep;
        double acc = 0.0;
        for (int64_t c = 0; c < hd; c++) {
            acc = __dadd_rn(acc,
                            __dmul_rn(dctx[i*d + hh*hd + c],
                                      V[(j*nkv + kvh)*hd + c]));
        }
        dProw[flat] = acc;
    }
}

__global__ void k_dS_dQ(const double* __restrict__ Q,
                        const double* __restrict__ K,
                        const double* __restrict__ P,
                        double* __restrict__ dProw,
                        double* __restrict__ dQ,
                        int64_t T, int64_t nh, int64_t nkv, int64_t hd) {
    int64_t flat   = (int64_t)blockIdx.x*(int64_t)blockDim.x+(int64_t)threadIdx.x;
    int64_t total  = nh * T;
    int64_t stride = (int64_t)gridDim.x *(int64_t)blockDim.x;
    int64_t n_rep  = nh / nkv;
    double scale = __ddiv_rn(1.0, d_dt_sqrt((double)hd));
    for (; flat < total; flat += stride) {
        int64_t hh = flat / T;
        int64_t i  = flat - hh * T;
        int64_t kvh = hh / n_rep;
        int64_t L = i + 1;
        double sdot = 0.0;
        for (int64_t j = 0; j < L; j++) {
            sdot = __dadd_rn(sdot,
                             __dmul_rn(P[(hh*T + i)*T + j],
                                       dProw[(hh*T + i)*T + j]));
        }
        for (int64_t j = 0; j < L; j++) {
            double v = dProw[(hh*T + i)*T + j] - sdot;
            dProw[(hh*T + i)*T + j] = __dmul_rn(
                __dmul_rn(P[(hh*T + i)*T + j], v), scale);
        }
        for (int64_t c2 = 0; c2 < hd; c2++) {
            double acc = 0.0;
            for (int64_t j = 0; j < L; j++) {
                acc = __dadd_rn(acc,
                                __dmul_rn(dProw[(hh*T + i)*T + j],
                                          K[(j*nkv + kvh)*hd + c2]));
            }
            dQ[(i*nh + hh)*hd + c2] = acc;
        }
    }
}

__global__ void k_dV(const double* __restrict__ P,
                     const double* __restrict__ dctx,
                     double* __restrict__ dV,
                     int64_t T, int64_t nh, int64_t nkv, int64_t hd) {
    int64_t flat   = (int64_t)blockIdx.x*(int64_t)blockDim.x+(int64_t)threadIdx.x;
    int64_t total  = T * nkv * hd;
    int64_t stride = (int64_t)gridDim.x *(int64_t)blockDim.x;
    int64_t n_rep  = nh / nkv;
    int64_t d      = nh * hd;
    for (; flat < total; flat += stride) {
        int64_t j   = flat / (nkv * hd);
        int64_t r   = flat - j * (nkv * hd);
        int64_t kvh = r / hd;
        int64_t c   = r - kvh * hd;
        int64_t hh0 = kvh * n_rep;
        double acc = 0.0;
        for (int64_t hh = hh0; hh < hh0 + n_rep; hh++) {
            for (int64_t i = j; i < T; i++) {
                acc = __dadd_rn(acc,
                                __dmul_rn(P[(hh*T + i)*T + j],
                                          dctx[i*d + hh*hd + c]));
            }
        }
        dV[(j*nkv + kvh)*hd + c] = acc;
    }
}

__global__ void k_dK(const double* __restrict__ Q,
                     const double* __restrict__ dS,
                     double* __restrict__ dK,
                     int64_t T, int64_t nh, int64_t nkv, int64_t hd) {
    int64_t flat   = (int64_t)blockIdx.x*(int64_t)blockDim.x+(int64_t)threadIdx.x;
    int64_t total  = T * nkv * hd;
    int64_t stride = (int64_t)gridDim.x *(int64_t)blockDim.x;
    int64_t n_rep  = nh / nkv;
    for (; flat < total; flat += stride) {
        int64_t j   = flat / (nkv * hd);
        int64_t r   = flat - j * (nkv * hd);
        int64_t kvh = r / hd;
        int64_t c   = r - kvh * hd;
        int64_t hh0 = kvh * n_rep;
        double acc = 0.0;
        for (int64_t hh = hh0; hh < hh0 + n_rep; hh++) {
            for (int64_t i = j; i < T; i++) {
                acc = __dadd_rn(acc,
                                __dmul_rn(dS[(hh*T + i)*T + j],
                                          Q[(i*nh + hh)*hd + c]));
            }
        }
        dK[(j*nkv + kvh)*hd + c] = acc;
    }
}

/* CPU reference (mirror runtime.c _hx_farr_attn_dt_bwd_cpu) */
static double h_dt_sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double g = x > 1.0 ? x : 1.0;
    int i = 0;
    while (i < 24) { g = 0.5 * (g + x / g); i = i + 1; }
    return g;
}
static void cpu_attn_dt_bwd(const double* Q, const double* K, const double* V,
                            const double* P, const double* dctx,
                            double* dQ, double* dK, double* dV,
                            int64_t T, int64_t nh, int64_t nkv, int64_t hd) {
    int64_t n_rep = nh / nkv;
    int64_t d     = nh * hd;
    double scale = 1.0 / h_dt_sqrt((double)hd);
    double* dP_row = (double*)malloc((size_t)T * sizeof(double));
    for (int64_t hh = 0; hh < nh; hh++) {
        int64_t kvh = hh / n_rep;
        for (int64_t i = 0; i < T; i++) {
            int64_t L = i + 1;
            for (int64_t j = 0; j < L; j++) {
                double acc = 0.0;
                for (int64_t c = 0; c < hd; c++) {
                    acc = acc + dctx[i*d + hh*hd + c]
                              * V[(j*nkv + kvh)*hd + c];
                }
                dP_row[j] = acc;
            }
            double sdot = 0.0;
            for (int64_t j2 = 0; j2 < L; j2++) {
                sdot = sdot + P[(hh*T + i)*T + j2] * dP_row[j2];
            }
            for (int64_t j3 = 0; j3 < L; j3++) {
                double pij = P[(hh*T + i)*T + j3];
                for (int64_t c = 0; c < hd; c++) {
                    int64_t dv_idx = (j3*nkv + kvh)*hd + c;
                    dV[dv_idx] = dV[dv_idx] + pij * dctx[i*d + hh*hd + c];
                }
            }
            for (int64_t j4 = 0; j4 < L; j4++) {
                double dS = P[(hh*T + i)*T + j4]
                          * (dP_row[j4] - sdot) * scale;
                for (int64_t c2 = 0; c2 < hd; c2++) {
                    int64_t dq_idx = (i*nh + hh)*hd + c2;
                    int64_t dk_idx = (j4*nkv + kvh)*hd + c2;
                    dQ[dq_idx] = dQ[dq_idx] + dS * K[(j4*nkv + kvh)*hd + c2];
                    dK[dk_idx] = dK[dk_idx] + dS * Q[(i*nh + hh)*hd + c2];
                }
            }
        }
    }
    free(dP_row);
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
    int64_t T   = 256;
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
    printf("[T] attn-dt bwd test — T=%lld nh=%lld nkv=%lld hd=%lld\n",
           (long long)T,(long long)nh,(long long)nkv,(long long)hd);

    double *hQ=(double*)malloc((size_t)nq*8);
    double *hK=(double*)malloc((size_t)nk*8);
    double *hV=(double*)malloc((size_t)nk*8);
    double *hP=(double*)calloc((size_t)np,8);
    double *hDctx=(double*)malloc((size_t)nq*8);
    double *hDQc=(double*)calloc((size_t)nq,8);
    double *hDKc=(double*)calloc((size_t)nk,8);
    double *hDVc=(double*)calloc((size_t)nk,8);
    double *hDQg=(double*)malloc((size_t)nq*8);
    double *hDKg=(double*)malloc((size_t)nk*8);
    double *hDVg=(double*)malloc((size_t)nk*8);
    if(!hQ||!hK||!hV||!hP||!hDctx||!hDQc||!hDKc||!hDVc||!hDQg||!hDKg||!hDVg){
        fprintf(stderr,"[T] malloc fail\n"); return 2;
    }
    uint64_t s1=0x9e3779b97f4a7c15ULL;
    for (int64_t i=0;i<nq;i++) hQ[i]=(lcg_next(&s1)-0.5)*1.0;
    for (int64_t i=0;i<nk;i++) hK[i]=(lcg_next(&s1)-0.5)*1.0;
    for (int64_t i=0;i<nk;i++) hV[i]=(lcg_next(&s1)-0.5)*1.0;
    for (int64_t i=0;i<nq;i++) hDctx[i]=(lcg_next(&s1)-0.5)*0.1;
    /* fabricate a plausible P: row-stochastic over j<=i (causal), else 0 */
    for (int64_t hh = 0; hh < nh; hh++) {
        for (int64_t i = 0; i < T; i++) {
            int64_t L = i + 1;
            double sum = 0.0;
            for (int64_t j = 0; j < L; j++) {
                double v = lcg_next(&s1);
                hP[(hh*T + i)*T + j] = v;
                sum += v;
            }
            for (int64_t j = 0; j < L; j++) {
                hP[(hh*T + i)*T + j] = hP[(hh*T + i)*T + j] / sum;
            }
        }
    }

    double *dQ,*dK,*dV,*dP,*dDctx,*dDQ,*dDK,*dDV,*dDProw;
    CK(cudaMalloc(&dQ,(size_t)nq*8));
    CK(cudaMalloc(&dK,(size_t)nk*8));
    CK(cudaMalloc(&dV,(size_t)nk*8));
    CK(cudaMalloc(&dP,(size_t)np*8));
    CK(cudaMalloc(&dDctx,(size_t)nq*8));
    CK(cudaMalloc(&dDQ,(size_t)nq*8));
    CK(cudaMalloc(&dDK,(size_t)nk*8));
    CK(cudaMalloc(&dDV,(size_t)nk*8));
    CK(cudaMalloc(&dDProw,(size_t)np*8));
    CK(cudaMemcpy(dQ,hQ,(size_t)nq*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dK,hK,(size_t)nk*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dV,hV,(size_t)nk*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dP,hP,(size_t)np*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dDctx,hDctx,(size_t)nq*8,cudaMemcpyHostToDevice));
    /* dQ/dK/dV initial = 0 (fresh t_zeros contract). */
    CK(cudaMemset(dDQ,0,(size_t)nq*8));
    CK(cudaMemset(dDK,0,(size_t)nk*8));
    CK(cudaMemset(dDV,0,(size_t)nk*8));

    cpu_attn_dt_bwd(hQ,hK,hV,hP,hDctx,hDQc,hDKc,hDVc,T,nh,nkv,hd);

    int block = 64;
    /* Step 1: dProw */
    { int64_t total = nh*T*T;
      int64_t need = (total + block - 1)/block;
      int grid = (int)(need<1?1:(need>65535?65535:need));
      k_dProw<<<grid,block>>>(dV,dDctx,dDProw,T,nh,nkv,hd); CK(cudaGetLastError()); }
    /* Step 2: dS+dQ */
    { int64_t total = nh*T;
      int64_t need = (total + block - 1)/block;
      int grid = (int)(need<1?1:(need>65535?65535:need));
      k_dS_dQ<<<grid,block>>>(dQ,dK,dP,dDProw,dDQ,T,nh,nkv,hd); CK(cudaGetLastError()); }
    /* Step 3a: dV */
    { int64_t total = T*nkv*hd;
      int64_t need = (total + block - 1)/block;
      int grid = (int)(need<1?1:(need>65535?65535:need));
      k_dV<<<grid,block>>>(dP,dDctx,dDV,T,nh,nkv,hd); CK(cudaGetLastError()); }
    /* Step 3b: dK */
    { int64_t total = T*nkv*hd;
      int64_t need = (total + block - 1)/block;
      int grid = (int)(need<1?1:(need>65535?65535:need));
      k_dK<<<grid,block>>>(dQ,dDProw,dDK,T,nh,nkv,hd); CK(cudaGetLastError()); }

    CK(cudaMemcpy(hDQg,dDQ,(size_t)nq*8,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hDKg,dDK,(size_t)nk*8,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hDVg,dDV,(size_t)nk*8,cudaMemcpyDeviceToHost));

    double md_q = max_abs_diff(hDQc,hDQg,nq);
    double md_k = max_abs_diff(hDKc,hDKg,nk);
    double md_v = max_abs_diff(hDVc,hDVg,nk);
    int beq_q = byte_equal(hDQc,hDQg,nq);
    int beq_k = byte_equal(hDKc,hDKg,nk);
    int beq_v = byte_equal(hDVc,hDVg,nk);
    int pass = (md_q==0.0)&&(md_k==0.0)&&(md_v==0.0)&&beq_q&&beq_k&&beq_v;
    printf("[F-MK2C4-ATTNDT-BWD-dQ] max|D|=%.3e byte_eq=%d (req=1)\n", md_q, beq_q);
    printf("[F-MK2C4-ATTNDT-BWD-dK] max|D|=%.3e byte_eq=%d (req=1)\n", md_k, beq_k);
    printf("[F-MK2C4-ATTNDT-BWD-dV] max|D|=%.3e byte_eq=%d (req=1)\n", md_v, beq_v);
    printf("[F-MK2C4-ATTNDT-BWD-VERDICT] %s\n", pass?"PASS":"FAIL");

    cudaFree(dQ);cudaFree(dK);cudaFree(dV);cudaFree(dP);cudaFree(dDctx);
    cudaFree(dDQ);cudaFree(dDK);cudaFree(dDV);cudaFree(dDProw);
    free(hQ);free(hK);free(hV);free(hP);free(hDctx);
    free(hDQc);free(hDKc);free(hDVc);free(hDQg);free(hDKg);free(hDVg);
    if (pass) { printf("\n[T] ALL-PASS — attn-dt bwd GPU byte-eq (T=%lld)\n",
                (long long)T); return 0; }
    printf("\n[T] FAIL — attn-dt bwd GPU byte-eq\n"); return 1;
}
