#!/usr/bin/env python3
# patch_precision.py — inject the HEXA-FUSION precision-change axis into the
# proven FP64 runtime_cuda.c (p1b-aprime3 base). Adds an env-gated GEMM path
#   HEXA_GEMM_PREC = fp64 (default, unchanged) | tf32 | bf16
# to BOTH _hx_cuda_farr_matmul_gpu (single) and the strided-batched launcher,
# plus a one-shot rel-RMS instrumentation vs the FP64 cuBLAS oracle (the W14
# precision gate: rel_rms of the low-precision GEMM output vs same-shape FP64).
#
# TF32: A,B fp64 -> fp32 device buffers, cublasGemmEx(CUDA_R_32F operands,
#       CUDA_R_32F out, CUBLAS_COMPUTE_32F_FAST_TF32) -> fp32 C -> fp64.
# BF16: A,B fp64 -> __nv_bfloat16 device buffers, cublasGemmEx(CUDA_R_16BF
#       operands, CUDA_R_32F out, CUBLAS_COMPUTE_32F) -> fp32 C -> fp64.
#
# The same-dtype oracle for the W14 rel-RMS gate IS cuBLAS itself (we call
# cuBLAS for the low-precision GEMM), so rel_rms-vs-same-dtype is ~0 by
# construction; the instrumentation we EMIT is the *precision-change error*
# rel_rms vs FP64 cuBLAS — the honest number that says how far TF32/BF16 drifts
# from the FP64 baseline on the REAL flame GEMM shapes. The whole-step CE +
# step/s vs FP64 are the speedup signal.
import sys, re
src = open(sys.argv[1]).read()

HELPERS = r'''
/* ════════════════════════════════════════════════════════════════════
 * HEXA-FUSION PRECISION-CHANGE — env HEXA_GEMM_PREC = fp64|tf32|bf16.
 * Low-precision tensor-core GEMM path for the flame CLMConvMoE step.
 * Convert the fp64 device operands to fp32 (TF32 math) / bf16, run
 * cublasGemmEx on the tensor cores, write fp32 C, convert back to fp64.
 * A one-shot rel-RMS-vs-FP64 instrumentation prints the precision-change
 * error on the FIRST GEMM (the W14 gate number).
 * ════════════════════════════════════════════════════════════════════ */
typedef enum { HX_PREC_FP64=0, HX_PREC_TF32=1, HX_PREC_BF16=2 } HxGemmPrec;
static HxGemmPrec _hx_gemm_prec(void) {
    const char* e = getenv("HEXA_GEMM_PREC");
    if (!e || !e[0]) return HX_PREC_FP64;
    if (e[0]=='t'||e[0]=='T') return HX_PREC_TF32;
    if (e[0]=='b'||e[0]=='B') return HX_PREC_BF16;
    return HX_PREC_FP64;
}
__global__ void _hx_d2f_kern(const double* __restrict d, float* __restrict f, int64_t n){
    int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x; if(i<n) f[i]=(float)d[i];
}
__global__ void _hx_f2d_kern(const float* __restrict f, double* __restrict d, int64_t n){
    int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x; if(i<n) d[i]=(double)f[i];
}
__global__ void _hx_d2bf_kern(const double* __restrict d, __nv_bfloat16* __restrict h, int64_t n){
    int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x; if(i<n) h[i]=__float2bfloat16((float)d[i]);
}
/* rel_rms( low-prec fp64-result  vs  fp64-ref )  over n elems, on device->host. */
static double _hx_relrms_fp64(const double* x, const double* ref, int64_t n){
    double num=0.0, den=0.0;
    for(int64_t i=0;i<n;i++){ double dd=x[i]-ref[i]; num+=dd*dd; den+=ref[i]*ref[i]; }
    if(den<=0.0) return (num<=0.0)?0.0:1.0;
    return sqrt(num/den);
}
/* Core low-precision GEMM in the SAME row->col swapped convention the FP64
 * launcher uses: produces column-major (N x M) == row-major C (M x N).
 * A_dev (fp64, M*K), B_dev (fp64, K*N) -> C_dev (fp64, M*N). prec in {TF32,BF16}.
 * gate!=0 -> also run the FP64 cuBLAS reference + print one-shot rel_rms. */
static int _hx_lowprec_gemm(cublasHandle_t h, HxGemmPrec prec,
                            const double* A_dev, const double* B_dev, double* C_dev,
                            int64_t M, int64_t K, int64_t N, int gate, const char* tag){
    int64_t aN=M*K, bN=K*N, cN=M*N;
    float alpha=1.0f, beta=0.0f;
    cublasStatus_t st;
    /* fp32 output buffer (both paths accumulate to fp32). */
    float *Cf=NULL; cudaMalloc((void**)&Cf,(size_t)cN*sizeof(float));
    dim3 bk(256);
    if(prec==HX_PREC_TF32){
        float *Af=NULL,*Bf=NULL;
        cudaMalloc((void**)&Af,(size_t)aN*sizeof(float));
        cudaMalloc((void**)&Bf,(size_t)bN*sizeof(float));
        _hx_d2f_kern<<<(unsigned)((aN+255)/256),bk>>>(A_dev,Af,aN);
        _hx_d2f_kern<<<(unsigned)((bN+255)/256),bk>>>(B_dev,Bf,bN);
        cublasSetMathMode(h, CUBLAS_TF32_TENSOR_OP_MATH);
        st=cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N, (int)N,(int)M,(int)K,
                        &alpha, Bf, CUDA_R_32F,(int)N, Af, CUDA_R_32F,(int)K,
                        &beta,  Cf, CUDA_R_32F,(int)N,
                        CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cublasSetMathMode(h, CUBLAS_DEFAULT_MATH);
        cudaFree(Af); cudaFree(Bf);
    } else { /* BF16 */
        __nv_bfloat16 *Ah=NULL,*Bh=NULL;
        cudaMalloc((void**)&Ah,(size_t)aN*sizeof(__nv_bfloat16));
        cudaMalloc((void**)&Bh,(size_t)bN*sizeof(__nv_bfloat16));
        _hx_d2bf_kern<<<(unsigned)((aN+255)/256),bk>>>(A_dev,Ah,aN);
        _hx_d2bf_kern<<<(unsigned)((bN+255)/256),bk>>>(B_dev,Bh,bN);
        st=cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N, (int)N,(int)M,(int)K,
                        &alpha, Bh, CUDA_R_16BF,(int)N, Ah, CUDA_R_16BF,(int)K,
                        &beta,  Cf, CUDA_R_32F,(int)N,
                        CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cudaFree(Ah); cudaFree(Bh);
    }
    if(st!=CUBLAS_STATUS_SUCCESS){ fprintf(stderr,"[cuda] lowprec GemmEx failed: %d\n",(int)st); cudaFree(Cf); return -1; }
    _hx_f2d_kern<<<(unsigned)((cN+255)/256),bk>>>(Cf,C_dev,cN);
    cudaDeviceSynchronize();
    if(gate){
        static int _gate_fired=0;
        if(!_gate_fired){ _gate_fired=1;
            /* FP64 cuBLAS reference into a scratch device buffer. */
            double *Cref=NULL, dalpha=1.0, dbeta=0.0;
            cudaMalloc((void**)&Cref,(size_t)cN*sizeof(double));
            cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, (int)N,(int)M,(int)K,
                        &dalpha, B_dev,(int)N, A_dev,(int)K, &dbeta, Cref,(int)N);
            cudaDeviceSynchronize();
            double *hC=(double*)malloc((size_t)cN*sizeof(double));
            double *hR=(double*)malloc((size_t)cN*sizeof(double));
            cudaMemcpy(hC,C_dev,(size_t)cN*sizeof(double),cudaMemcpyDeviceToHost);
            cudaMemcpy(hR,Cref,(size_t)cN*sizeof(double),cudaMemcpyDeviceToHost);
            double rr=_hx_relrms_fp64(hC,hR,cN);
            fprintf(stderr,"[PREC-GATE] %s prec=%s M=%lld K=%lld N=%lld rel_rms_vs_fp64=%.6e gate(<=1e-2)=%s\n",
                    tag, (prec==HX_PREC_TF32?"tf32":"bf16"),
                    (long long)M,(long long)K,(long long)N, rr, (rr<=1e-2?"PASS":"FAIL"));
            free(hC); free(hR); cudaFree(Cref);
        }
    }
    cudaFree(Cf);
    return 0;
}
'''

# 1) insert helpers right before the single matmul launcher definition.
anchor = "int _hx_cuda_farr_matmul_gpu(int64_t a_id, int64_t M, int64_t K,"
assert anchor in src, "single matmul launcher anchor not found"
src = src.replace(anchor, HELPERS + "\n" + anchor, 1)

# 2) single launcher: wrap the cublasDgemm else-block with a precision branch.
SINGLE_OLD = '''    } else {
    cublasStatus_t st = cublasDgemm(g_cublas,
                                    CUBLAS_OP_N, CUBLAS_OP_N,
                                    (int)N, (int)M, (int)K,
                                    &alpha,
                                    B_dev, (int)N,
                                    A_dev, (int)K,
                                    &beta,
                                    C_dev, (int)N);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasDgemm failed: %d\\n", (int)st);
        return -1;
    }
    }'''
SINGLE_NEW = '''    } else {
    HxGemmPrec _pr = _hx_gemm_prec();
    if (_pr != HX_PREC_FP64) {
        if (_hx_lowprec_gemm(g_cublas, _pr, A_dev, B_dev, C_dev, M, K, N, 1, "single") != 0) return -1;
    } else {
    cublasStatus_t st = cublasDgemm(g_cublas,
                                    CUBLAS_OP_N, CUBLAS_OP_N,
                                    (int)N, (int)M, (int)K,
                                    &alpha,
                                    B_dev, (int)N,
                                    A_dev, (int)K,
                                    &beta,
                                    C_dev, (int)N);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasDgemm failed: %d\\n", (int)st);
        return -1;
    }
    }
    }'''
assert SINGLE_OLD in src, "single Dgemm block not matched"
src = src.replace(SINGLE_OLD, SINGLE_NEW, 1)

# 3) strided-batched launcher: loop the low-prec gemm per problem when prec!=fp64.
BATCH_OLD = '''    } else {
    cublasStatus_t st = cublasDgemmStridedBatched(
        g_cublas, CUBLAS_OP_N, CUBLAS_OP_N,
        (int)N, (int)M, (int)K,
        &alpha,
        B_dev, (int)N, (long long)(K * N),
        A_dev, (int)K, (long long)(M * K),
        &beta,
        C_dev, (int)N, (long long)(M * N),
        (int)batch);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasDgemmStridedBatched failed: %d\\n", (int)st);
        return -1;
    }
    }'''
BATCH_NEW = '''    } else {
    HxGemmPrec _pr = _hx_gemm_prec();
    if (_pr != HX_PREC_FP64) {
        for (int64_t _g = 0; _g < batch; _g++) {
            if (_hx_lowprec_gemm(g_cublas, _pr,
                    A_dev + _g*M*K, B_dev + _g*K*N, C_dev + _g*M*N,
                    M, K, N, (_g==0?1:0), "batched") != 0) return -1;
        }
    } else {
    cublasStatus_t st = cublasDgemmStridedBatched(
        g_cublas, CUBLAS_OP_N, CUBLAS_OP_N,
        (int)N, (int)M, (int)K,
        &alpha,
        B_dev, (int)N, (long long)(K * N),
        A_dev, (int)K, (long long)(M * K),
        &beta,
        C_dev, (int)N, (long long)(M * N),
        (int)batch);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasDgemmStridedBatched failed: %d\\n", (int)st);
        return -1;
    }
    }
    }'''
assert BATCH_OLD in src, "batched Dgemm block not matched"
src = src.replace(BATCH_OLD, BATCH_NEW, 1)

open(sys.argv[2], "w").write(src)
print("patched ->", sys.argv[2], len(src), "bytes")
