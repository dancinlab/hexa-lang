/* tool/cuda_syntax_stub/cublas_v2.h — NOT a build artifact.
 * Minimal cuBLAS stub for Mac no-GPU syntactic verification (see
 * cuda_runtime.h in this dir). Declarations only. */
#ifndef _HX_STUB_CUBLAS_V2_H
#define _HX_STUB_CUBLAS_V2_H

typedef struct _hx_cublasContext* cublasHandle_t;
typedef int cublasStatus_t;
typedef int cublasOperation_t;
enum { CUBLAS_STATUS_SUCCESS = 0 };
enum { CUBLAS_OP_N = 0, CUBLAS_OP_T = 1, CUBLAS_OP_C = 2 };

cublasStatus_t cublasCreate(cublasHandle_t* h);
cublasStatus_t cublasDestroy(cublasHandle_t h);
cublasStatus_t cublasDgemm(cublasHandle_t h,
                           cublasOperation_t transa,
                           cublasOperation_t transb,
                           int m, int n, int k,
                           const double* alpha,
                           const double* A, int lda,
                           const double* B, int ldb,
                           const double* beta,
                           double* C, int ldc);

#endif /* _HX_STUB_CUBLAS_V2_H */
