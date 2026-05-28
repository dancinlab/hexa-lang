// gpu_wedge_d64_matmul_tc.cu
// F-WEDGE-D64-MATMUL-TC-CEILING cheap-first oracle (anima M4b decoder).
// Measures cuBLAS Sgemm (FP32) vs GemmEx-TF32 vs GemmEx-BF16 on the trainer's
// hottest matmul shapes (d=64 narrow, V=151643 unembed GEMV dominates).
// Pre-registered falsifier: TC >= 1.5x cuBLAS Sgemm at hottest shape = GREEN.
// Pure-ASCII comments only (driver-JIT requirement per reference_gpu_fire_infra).
//
// Build: nvcc -O3 -arch=sm_120 tool/gpu_wedge_d64_matmul_tc.cu -lcublas -o /tmp/d64tc
// Run  : /tmp/d64tc

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cuda_runtime.h>
#include <cuda_bf16.h>
#include <cublas_v2.h>

#define CK(x) do { cudaError_t _ck_err = (x); if (_ck_err != cudaSuccess) { \
  fprintf(stderr, "CUDA fail %s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(_ck_err)); std::exit(1); } } while (0)
#define CKB(x) do { cublasStatus_t _ckb_st = (x); if (_ckb_st != CUBLAS_STATUS_SUCCESS) { \
  fprintf(stderr, "cuBLAS fail %s:%d code=%d\n", __FILE__, __LINE__, (int)_ckb_st); std::exit(1); } } while (0)

struct Shape { int M; int K; int N; const char* label; };

// trainer-canonical shapes (anima M4b decoder pilot, d=64 V=151643 T=4 h=256)
// Plus task-spec sweep shapes (8x64x64, 32x64x64) for batch-scaling context.
static const Shape SHAPES[] = {
  // shape order: (M, K, N) with C = A[MxK] * B[KxN]
  // --- task-spec sweep (small-d square) ---
  { 1,       64,    64,     "S1x64x64 (degenerate)"               },
  { 8,       64,    64,     "S8x64x64 (B=8 attn-proj)"            },
  { 32,      64,    64,     "S32x64x64 (B=32 attn-proj)"          },
  // --- trainer-actual hot shapes (T=4) ---
  { 4,       64,    64,     "T4xdxd (Q/K/V/O proj fwd)"           },
  { 4,       64,    256,    "T4xdxh (MLP up fwd)"                 },
  { 4,       256,   64,     "T4xhxd (MLP down fwd)"               },
  // --- the DOMINANT cost: V=151643 unembed GEMV (fwd) ---
  { 151643,  64,    1,      "VxdxN1 (unembed GEMV fwd) HOT"       },
  // --- bwd outer-product (rank-1 GEMM) ---
  { 151643,  1,     64,     "VxN1xd (unembed outer bwd)"          },
  // --- task-spec sweep extreme (V x d x d) ---
  { 151643,  64,    64,     "VxdxN64 (sweep extreme)"             },
  { 64,      151643, 64,    "dxVxd (transpose-ish sweep)"         },
};
static const int N_SHAPES = sizeof(SHAPES) / sizeof(SHAPES[0]);

// timed runner (cuEvent, 20 warmup / 200 measured)
static double time_ms(cudaEvent_t a, cudaEvent_t b) {
  float ms = 0.0f;
  CK(cudaEventSynchronize(b));
  CK(cudaEventElapsedTime(&ms, a, b));
  return (double)ms;
}

struct Result { double ms; double tflops; };

// variant A: cuBLAS Sgemm (FP32 baseline, no TC)
static Result run_sgemm(cublasHandle_t h, int M, int K, int N,
                        float* dA, float* dB, float* dC) {
  const float alpha = 1.0f, beta = 0.0f;
  // cublasSgemm column-major: compute C = A * B with A[MxK] B[KxN] row-major
  // -> call as cublasSgemm(N, K, M, B^T, A^T) trick: use op_T on both.
  // Simpler: treat row-major C = A*B as col-major C^T = B^T * A^T
  // i.e. cublasSgemm(N=N, M=M, K=K, B, K, A, M)  with transA/B = N
  // We'll do row-major semantics via the standard swap:
  //   col-major op: C(NxM) = B(NxK) * A(KxM)  with all N op
  // Lda/Ldb/Ldc adjusted accordingly.
  for (int i = 0; i < 20; ++i) {
    CKB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                    N, M, K,
                    &alpha, dB, N, dA, K,
                    &beta,  dC, N));
  }
  CK(cudaDeviceSynchronize());
  cudaEvent_t s, e; CK(cudaEventCreate(&s)); CK(cudaEventCreate(&e));
  CK(cudaEventRecord(s));
  for (int i = 0; i < 200; ++i) {
    CKB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                    N, M, K,
                    &alpha, dB, N, dA, K,
                    &beta,  dC, N));
  }
  CK(cudaEventRecord(e));
  double total_ms = time_ms(s, e);
  CK(cudaEventDestroy(s)); CK(cudaEventDestroy(e));
  double ms = total_ms / 200.0;
  double flops = 2.0 * (double)M * (double)K * (double)N;
  double tflops = flops / (ms * 1.0e-3) / 1.0e12;
  return { ms, tflops };
}

// variant B: cuBLAS GemmEx tf32 (input FP32, accumulator FP32, math TF32 = TC)
static Result run_gemmex_tf32(cublasHandle_t h, int M, int K, int N,
                              float* dA, float* dB, float* dC) {
  const float alpha = 1.0f, beta = 0.0f;
  for (int i = 0; i < 20; ++i) {
    CKB(cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N,
                     N, M, K,
                     &alpha, dB, CUDA_R_32F, N,
                             dA, CUDA_R_32F, K,
                     &beta,  dC, CUDA_R_32F, N,
                     CUBLAS_COMPUTE_32F_FAST_TF32,
                     CUBLAS_GEMM_DEFAULT_TENSOR_OP));
  }
  CK(cudaDeviceSynchronize());
  cudaEvent_t s, e; CK(cudaEventCreate(&s)); CK(cudaEventCreate(&e));
  CK(cudaEventRecord(s));
  for (int i = 0; i < 200; ++i) {
    CKB(cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N,
                     N, M, K,
                     &alpha, dB, CUDA_R_32F, N,
                             dA, CUDA_R_32F, K,
                     &beta,  dC, CUDA_R_32F, N,
                     CUBLAS_COMPUTE_32F_FAST_TF32,
                     CUBLAS_GEMM_DEFAULT_TENSOR_OP));
  }
  CK(cudaEventRecord(e));
  double total_ms = time_ms(s, e);
  CK(cudaEventDestroy(s)); CK(cudaEventDestroy(e));
  double ms = total_ms / 200.0;
  double flops = 2.0 * (double)M * (double)K * (double)N;
  double tflops = flops / (ms * 1.0e-3) / 1.0e12;
  return { ms, tflops };
}

// variant C: cuBLAS GemmEx bf16 (input bf16, accumulator FP32, math bf16 = TC strongest)
static Result run_gemmex_bf16(cublasHandle_t h, int M, int K, int N,
                              __nv_bfloat16* dAb, __nv_bfloat16* dBb, float* dC) {
  const float alpha = 1.0f, beta = 0.0f;
  for (int i = 0; i < 20; ++i) {
    CKB(cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N,
                     N, M, K,
                     &alpha, dBb, CUDA_R_16BF, N,
                             dAb, CUDA_R_16BF, K,
                     &beta,  dC,  CUDA_R_32F,  N,
                     CUBLAS_COMPUTE_32F,
                     CUBLAS_GEMM_DEFAULT_TENSOR_OP));
  }
  CK(cudaDeviceSynchronize());
  cudaEvent_t s, e; CK(cudaEventCreate(&s)); CK(cudaEventCreate(&e));
  CK(cudaEventRecord(s));
  for (int i = 0; i < 200; ++i) {
    CKB(cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N,
                     N, M, K,
                     &alpha, dBb, CUDA_R_16BF, N,
                             dAb, CUDA_R_16BF, K,
                     &beta,  dC,  CUDA_R_32F,  N,
                     CUBLAS_COMPUTE_32F,
                     CUBLAS_GEMM_DEFAULT_TENSOR_OP));
  }
  CK(cudaEventRecord(e));
  double total_ms = time_ms(s, e);
  CK(cudaEventDestroy(s)); CK(cudaEventDestroy(e));
  double ms = total_ms / 200.0;
  double flops = 2.0 * (double)M * (double)K * (double)N;
  double tflops = flops / (ms * 1.0e-3) / 1.0e12;
  return { ms, tflops };
}

int main() {
  cudaDeviceProp prop; CK(cudaGetDeviceProperties(&prop, 0));
  fprintf(stderr, "device: %s sm_%d%d  SMs=%d\n",
          prop.name, prop.major, prop.minor, prop.multiProcessorCount);

  cublasHandle_t handle;
  CKB(cublasCreate(&handle));

  // print JSON header
  printf("{\n  \"device\": \"%s\",\n  \"sm\": \"%d%d\",\n  \"results\": [\n",
         prop.name, prop.major, prop.minor);

  for (int si = 0; si < N_SHAPES; ++si) {
    int M = SHAPES[si].M, K = SHAPES[si].K, N = SHAPES[si].N;
    const char* label = SHAPES[si].label;

    // alloc host + fill with deterministic FP32 (0..1 range)
    size_t bytesA = (size_t)M * K * sizeof(float);
    size_t bytesB = (size_t)K * N * sizeof(float);
    size_t bytesC = (size_t)M * N * sizeof(float);

    float *dA, *dB, *dC;
    CK(cudaMalloc(&dA, bytesA));
    CK(cudaMalloc(&dB, bytesB));
    CK(cudaMalloc(&dC, bytesC));

    // fill A/B with deterministic FP32 host-side then H2D
    float* hA = (float*)std::malloc(bytesA);
    float* hB = (float*)std::malloc(bytesB);
    for (size_t i = 0; i < (size_t)M*K; ++i) hA[i] = ((i % 17) - 8) * 0.03125f;
    for (size_t i = 0; i < (size_t)K*N; ++i) hB[i] = ((i % 13) - 6) * 0.03125f;
    CK(cudaMemcpy(dA, hA, bytesA, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB, hB, bytesB, cudaMemcpyHostToDevice));

    // bf16 copies (host-side __float2bfloat16 conversion)
    __nv_bfloat16 *dAb, *dBb;
    CK(cudaMalloc(&dAb, (size_t)M * K * sizeof(__nv_bfloat16)));
    CK(cudaMalloc(&dBb, (size_t)K * N * sizeof(__nv_bfloat16)));
    __nv_bfloat16* hAb = (__nv_bfloat16*)std::malloc((size_t)M * K * sizeof(__nv_bfloat16));
    __nv_bfloat16* hBb = (__nv_bfloat16*)std::malloc((size_t)K * N * sizeof(__nv_bfloat16));
    for (size_t i = 0; i < (size_t)M*K; ++i) hAb[i] = __float2bfloat16(hA[i]);
    for (size_t i = 0; i < (size_t)K*N; ++i) hBb[i] = __float2bfloat16(hB[i]);
    CK(cudaMemcpy(dAb, hAb, (size_t)M * K * sizeof(__nv_bfloat16), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dBb, hBb, (size_t)K * N * sizeof(__nv_bfloat16), cudaMemcpyHostToDevice));

    Result rA = run_sgemm       (handle, M, K, N, dA, dB, dC);
    Result rB = run_gemmex_tf32 (handle, M, K, N, dA, dB, dC);
    Result rC = run_gemmex_bf16 (handle, M, K, N, dAb, dBb, dC);

    double ratio_tf32_over_fp32 = rB.tflops > 0.0 ? rB.tflops / rA.tflops : 0.0;
    double ratio_bf16_over_fp32 = rC.tflops > 0.0 ? rC.tflops / rA.tflops : 0.0;

    fprintf(stderr, "shape %-40s  M=%d K=%d N=%d\n", label, M, K, N);
    fprintf(stderr, "  A.fp32-sgemm        : %10.4f ms  %8.3f TFLOPS\n", rA.ms, rA.tflops);
    fprintf(stderr, "  B.tf32-gemmex (TC)  : %10.4f ms  %8.3f TFLOPS  ratio=%.3fx vs A\n", rB.ms, rB.tflops, ratio_tf32_over_fp32);
    fprintf(stderr, "  C.bf16-gemmex (TC)  : %10.4f ms  %8.3f TFLOPS  ratio=%.3fx vs A\n", rC.ms, rC.tflops, ratio_bf16_over_fp32);

    printf("    %s{\n      \"shape\": \"%s\", \"M\": %d, \"K\": %d, \"N\": %d,\n",
           si == 0 ? "" : ",\n    ", label, M, K, N);
    printf("      \"fp32_sgemm_ms\":     %.6f, \"fp32_sgemm_tflops\":     %.4f,\n", rA.ms, rA.tflops);
    printf("      \"tf32_gemmex_ms\":    %.6f, \"tf32_gemmex_tflops\":    %.4f, \"tf32_over_fp32\": %.4f,\n", rB.ms, rB.tflops, ratio_tf32_over_fp32);
    printf("      \"bf16_gemmex_ms\":    %.6f, \"bf16_gemmex_tflops\":    %.4f, \"bf16_over_fp32\": %.4f\n", rC.ms, rC.tflops, ratio_bf16_over_fp32);
    printf("    }");

    std::free(hA); std::free(hB); std::free(hAb); std::free(hBb);
    CK(cudaFree(dA)); CK(cudaFree(dB)); CK(cudaFree(dC));
    CK(cudaFree(dAb)); CK(cudaFree(dBb));
  }

  printf("\n  ]\n}\n");
  CKB(cublasDestroy(handle));
  return 0;
}
