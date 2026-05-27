// BC4 round-14 risk-d cheap-first oracle (1 probe, ~5 min).
//
// Question: at the wedge tile shape BM=32 BK=32, does the round-7
// mma-fragment-map discovery still hold?
//   (round-7 finding: ldmatrix.x4 .trans does 8x8-BLOCK transpose, NOT full
//    16x16 transpose => P*V non-trans path requires V pre-transpose.)
//
// Two kernels, single 32-thread warp each, both produce a 16x16 fp32 result
// tile and compare against CPU FP64 reference matrix multiply:
//   Kernel A (probeA_trans): mma.sync.m16n8k16 + ldmatrix.x4 .trans
//     -> if err vs "A.B" (k along B rows) < 1e-3 => .trans does FULL transpose
//        => V pre-transpose NOT needed at BK=32.
//     -> if err vs "A.B^T" (k along B cols) < 1e-3 => .trans only flips 8x8 blocks
//        in the way that yields A.B^T => same as round-7, V pre-transpose IS needed.
//
//   Kernel B (probeB_pretrans): V pre-transposed in smem + ldmatrix non-trans
//     -> err vs "P.V" (k along V rows) < 1e-3 => pre-transpose path works
//        (just confirms the round-7 work-around still applies at BK=32 tile).
//
// Tile context note (BM=32, BK=32):
//   - mma.sync.m16n8k16 is the atomic GPU primitive (16x8 output tile, k=16).
//   - A BM=32 BK=32 wedge uses a 2x2 grid of m16n8 fragments per (Q-tile, K-tile).
//   - The fragment-map property is invariant to grid count (mma is atomic), so the
//     single-fragment probe is sufficient to settle risk-d at the wedge shape.
//
// Build:  nvcc -O2 -arch=sm_120 probe_bm32_bk32.cu -o probe_bm32_bk32 -lcuda
//         (driver JIT to sm_120 if nvcc < 12.8; built with compute_90 PTX.)
// Run:    ./probe_bm32_bk32
// Output: pass/fail per kernel + which contraction matched.

#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <stdint.h>
#include <stdio.h>
#include <math.h>
#include <stdlib.h>

__device__ uint32_t s2u(const void* p) {
    return (uint32_t)__cvta_generic_to_shared(p);
}

// -------- Kernel A: m16n8k16 .trans path --------
// Reads sA (16x16 fp16) and sB (16x16 fp16) via ldmatrix; B path uses .trans.
// Two m16n8 issues cover the 16x16 output. Writes fp32 16x16 to C.
__global__ void probeA_trans(const __half* A, const __half* B, float* C) {
    __shared__ __half sA[256], sB[256];
    int t = threadIdx.x;
    for (int i = t; i < 256; i += 32) { sA[i] = A[i]; sB[i] = B[i]; }
    __syncthreads();

    int lane = t;
    int r15  = lane & 15;
    int chalf = (lane >> 4) * 8;

    uint32_t aA = s2u(sA) + r15 * 32 + chalf * 2;
    uint32_t bB = s2u(sB) + r15 * 32 + chalf * 2;
    uint32_t ra[4], rb[4];

    asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3},[%4];"
                 : "=r"(ra[0]), "=r"(ra[1]), "=r"(ra[2]), "=r"(ra[3]) : "r"(aA));
    asm volatile("ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16 {%0,%1,%2,%3},[%4];"
                 : "=r"(rb[0]), "=r"(rb[1]), "=r"(rb[2]), "=r"(rb[3]) : "r"(bB));

    float c0[4] = {0, 0, 0, 0};
    float c1[4] = {0, 0, 0, 0};
    asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 "
                 "{%0,%1,%2,%3},{%4,%5,%6,%7},{%8,%9},{%0,%1,%2,%3};"
                 : "+f"(c0[0]), "+f"(c0[1]), "+f"(c0[2]), "+f"(c0[3])
                 : "r"(ra[0]), "r"(ra[1]), "r"(ra[2]), "r"(ra[3]),
                   "r"(rb[0]), "r"(rb[2]));
    asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 "
                 "{%0,%1,%2,%3},{%4,%5,%6,%7},{%8,%9},{%0,%1,%2,%3};"
                 : "+f"(c1[0]), "+f"(c1[1]), "+f"(c1[2]), "+f"(c1[3])
                 : "r"(ra[0]), "r"(ra[1]), "r"(ra[2]), "r"(ra[3]),
                   "r"(rb[1]), "r"(rb[3]));

    int r2 = lane >> 2;
    int c2 = (lane & 3) * 2;
    C[r2 * 16 + c2]         = c0[0];
    C[r2 * 16 + c2 + 1]     = c0[1];
    C[(r2 + 8) * 16 + c2]     = c0[2];
    C[(r2 + 8) * 16 + c2 + 1] = c0[3];
    C[r2 * 16 + 8 + c2]         = c1[0];
    C[r2 * 16 + 8 + c2 + 1]     = c1[1];
    C[(r2 + 8) * 16 + 8 + c2]     = c1[2];
    C[(r2 + 8) * 16 + 8 + c2 + 1] = c1[3];
}

// -------- Kernel B: V pre-transpose + non-trans path --------
// Mirror of round-7 probe3: pre-transpose V in smem (sVt[n][k]) and feed
// non-trans ldmatrix. Computes P.V = sum_k P[m,k] * V[k,n].
__global__ void probeB_pretrans(const __half* P, const __half* V, float* C) {
    __shared__ __half sP[256], sVt[256];
    int t = threadIdx.x;
    for (int i = t; i < 256; i += 32) sP[i] = P[i];
    for (int i = t; i < 256; i += 32) {
        int k = i / 16;
        int n = i % 16;
        sVt[n * 16 + k] = V[k * 16 + n];
    }
    __syncthreads();

    int lane = t;
    int r15  = lane & 15;
    int chalf = (lane >> 4) * 8;

    uint32_t aA = s2u(sP)  + r15 * 32 + chalf * 2;
    uint32_t bB = s2u(sVt) + r15 * 32 + chalf * 2;
    uint32_t ra[4], rb[4];

    asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3},[%4];"
                 : "=r"(ra[0]), "=r"(ra[1]), "=r"(ra[2]), "=r"(ra[3]) : "r"(aA));
    asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3},[%4];"
                 : "=r"(rb[0]), "=r"(rb[1]), "=r"(rb[2]), "=r"(rb[3]) : "r"(bB));

    float c0[4] = {0, 0, 0, 0};
    float c1[4] = {0, 0, 0, 0};
    asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 "
                 "{%0,%1,%2,%3},{%4,%5,%6,%7},{%8,%9},{%0,%1,%2,%3};"
                 : "+f"(c0[0]), "+f"(c0[1]), "+f"(c0[2]), "+f"(c0[3])
                 : "r"(ra[0]), "r"(ra[1]), "r"(ra[2]), "r"(ra[3]),
                   "r"(rb[0]), "r"(rb[2]));
    asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 "
                 "{%0,%1,%2,%3},{%4,%5,%6,%7},{%8,%9},{%0,%1,%2,%3};"
                 : "+f"(c1[0]), "+f"(c1[1]), "+f"(c1[2]), "+f"(c1[3])
                 : "r"(ra[0]), "r"(ra[1]), "r"(ra[2]), "r"(ra[3]),
                   "r"(rb[1]), "r"(rb[3]));

    int r2 = lane >> 2;
    int c2 = (lane & 3) * 2;
    C[r2 * 16 + c2]         = c0[0];
    C[r2 * 16 + c2 + 1]     = c0[1];
    C[(r2 + 8) * 16 + c2]     = c0[2];
    C[(r2 + 8) * 16 + c2 + 1] = c0[3];
    C[r2 * 16 + 8 + c2]         = c1[0];
    C[r2 * 16 + 8 + c2 + 1]     = c1[1];
    C[(r2 + 8) * 16 + 8 + c2]     = c1[2];
    C[(r2 + 8) * 16 + 8 + c2 + 1] = c1[3];
}

int main(void) {
    __half hA[256], hB[256];
    float hC[256];
    for (int i = 0; i < 256; ++i) {
        hA[i] = __float2half(((i * 7) % 13) * 0.1f - 0.6f);
        hB[i] = __float2half(((i * 5) % 11) * 0.1f - 0.5f);
    }

    // Two FP64 reference matrices.
    double refB[256];   // C = A . B  (k along B rows; standard mat-mul)
    double refBt[256];  // C = A . B^T (k along B cols)
    for (int m = 0; m < 16; ++m) {
        for (int n = 0; n < 16; ++n) {
            double sB = 0, sBt = 0;
            for (int k = 0; k < 16; ++k) {
                double a = (double)__half2float(hA[m * 16 + k]);
                sB  += a * (double)__half2float(hB[k * 16 + n]);
                sBt += a * (double)__half2float(hB[n * 16 + k]);
            }
            refB[m * 16 + n]  = sB;
            refBt[m * 16 + n] = sBt;
        }
    }

    __half *dA, *dB;
    float  *dC;
    cudaMalloc(&dA, 512);
    cudaMalloc(&dB, 512);
    cudaMalloc(&dC, 1024);
    cudaMemcpy(dA, hA, 512, cudaMemcpyHostToDevice);
    cudaMemcpy(dB, hB, 512, cudaMemcpyHostToDevice);

    // --- Kernel A: .trans path ---
    probeA_trans<<<1, 32>>>(dA, dB, dC);
    cudaError_t err = cudaDeviceSynchronize();
    if (err != cudaSuccess) {
        printf("probeA launch FAIL: %s\n", cudaGetErrorString(err));
        return 1;
    }
    cudaMemcpy(hC, dC, 1024, cudaMemcpyDeviceToHost);

    double eA_B = 0, eA_Bt = 0;
    for (int i = 0; i < 256; ++i) {
        double dB1 = fabs((double)hC[i] - refB[i]);
        double dBt = fabs((double)hC[i] - refBt[i]);
        if (dB1 > eA_B)  eA_B  = dB1;
        if (dBt > eA_Bt) eA_Bt = dBt;
    }
    printf("PROBE_A_TRANS_BK32 err_vs_A.B=%.4g %s err_vs_A.Bt=%.4g %s\n",
           eA_B,  eA_B  < 1e-2 ? "MATCH" : "miss",
           eA_Bt, eA_Bt < 1e-2 ? "MATCH" : "miss");

    // --- Kernel B: V pre-transpose path ---
    probeB_pretrans<<<1, 32>>>(dA, dB, dC);
    err = cudaDeviceSynchronize();
    if (err != cudaSuccess) {
        printf("probeB launch FAIL: %s\n", cudaGetErrorString(err));
        return 1;
    }
    cudaMemcpy(hC, dC, 1024, cudaMemcpyDeviceToHost);

    double eB_PV = 0;
    for (int i = 0; i < 256; ++i) {
        double dPV = fabs((double)hC[i] - refB[i]);  // P.V (k along V rows)
        if (dPV > eB_PV) eB_PV = dPV;
    }
    printf("PROBE_B_PRETRANS_BK32 err_vs_P.V=%.4g %s\n",
           eB_PV, eB_PV < 1e-2 ? "MATCH" : "miss");

    // Verdict summary line.
    const char* a_behavior =
        (eA_B  < 1e-2) ? "FULL_TRANSPOSE_AT_BK32" :
        (eA_Bt < 1e-2) ? "8X8_BLOCK_TRANSPOSE_AT_BK32" :
                         "NEITHER_OTHER";
    bool v_pretranspose_required = (eA_B >= 1e-2);
    bool b_pretranspose_works    = (eB_PV < 1e-2);
    printf("VERDICT trans_behavior=%s v_pretranspose_required=%d "
           "b_pretranspose_works=%d\n",
           a_behavior,
           v_pretranspose_required ? 1 : 0,
           b_pretranspose_works    ? 1 : 0);

    cudaFree(dA);
    cudaFree(dB);
    cudaFree(dC);
    return 0;
}
