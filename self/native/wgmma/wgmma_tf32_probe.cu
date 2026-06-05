// wgmma_tf32_probe.cu — Stage-1 FEASIBILITY PROBE for F-FUSION-SM90-WGMMA-TMA.
//
// Goal: confirm a MINIMAL single-warpgroup wgmma.mma_async TF32 GEMM
//   (sm_90a) compiles AND computes the correct result on a native sm_90 H100,
//   BEFORE investing in the full TMA-fed warpgroup mainloop. The prior mma.sync
//   CB mainloop (F-FUSION-SM90-CUBLAS-MAINLOOP) topped out at 11.55 TFLOP/s =
//   29.4x off cuBLAS; the binding constraint is the mma.sync warp-level class.
//   wgmma.mma_async (warpgroup async, sm_90a) is the only class reaching Hopper
//   TC peak. This probe pins whether wgmma is build- AND run-correct here.
//
// Shape: one wgmma instruction tile M=64 N=64 K=8 (TF32), single warpgroup
//   (128 threads), A/B staged in __shared__ in the canonical 128-byte
//   "swizzle-free" (interleave=0) descriptor layout. We verify against a CPU
//   TF32-rounded reference (rel-RMS) and report the canonical wgmma D-register
//   -> C[row,col] mapping correctness explicitly.
//
// Build (on-pod, nvcc 12.x, native sm_90 H100):
//   nvcc -O3 -arch=sm_90a -o wgmma_tf32_probe wgmma_tf32_probe.cu
//
// Output: a single PASS/FAIL line + rel-RMS, parseable by the verdict harness.
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>

#define CK(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  printf("CUDA-ERR %s @%d: %s\n", #x, __LINE__, cudaGetErrorString(e)); return 3; } }while(0)

// ---- wgmma shared-memory matrix descriptor (PTX ISA 9.7.13.4.2) -------------
// 64-bit. We use the no-swizzle (interleaved=0) layout. Bits:
//   [13:0]   matrix start address (encoded: (addr & 0x3FFFF) >> 4)
//   [29:16]  leading-dim byte offset (LBO) >> 4
//   [45:32]  stride-dim byte offset (SBO) >> 4
//   [51:49]  matrix base offset (0 for non-swizzled)
//   [63:62]  swizzle mode (0 = none)
__device__ __forceinline__ uint64_t make_smem_desc(const void* p, uint32_t lbo, uint32_t sbo) {
    uint32_t saddr = (uint32_t)__cvta_generic_to_shared(const_cast<void*>(p));
    uint64_t desc = 0;
    desc |= ((uint64_t)((saddr & 0x3FFFF) >> 4));
    desc |= ((uint64_t)((lbo >> 4) & 0x3FFF)) << 16;
    desc |= ((uint64_t)((sbo >> 4) & 0x3FFF)) << 32;
    // swizzle = 0 (bits 62-63), base offset = 0 (bits 49-51)
    return desc;
}

// Single-warpgroup TF32 wgmma: D[64x64] = A[64x8] * B[8x64].
// A is stored K-major (row-major MxK, i.e. As[m*8 + k]); B is row-major KxN.
// m64n64k8.f32.tf32.tf32 produces 32 f32 accumulators per thread.
extern "C" __global__ void wgmma_tf32_kernel(const float* gA, const float* gB, float* gD) {
    extern __shared__ __align__(128) float smem[];
    float* As = smem;              // 64x8 = 512 floats, row-major (M x K)
    float* Bs = smem + 64 * 8;     // 8x64 = 512 floats, row-major (K x N)

    int tid = threadIdx.x;         // 0..127
    for (int i = tid; i < 64 * 8; i += 128) As[i] = gA[i];
    for (int i = tid; i < 8 * 64; i += 128) Bs[i] = gB[i];
    __syncthreads();

    // Descriptors. For row-major MxK A (core matrix 8x8 in the canonical
    // wgmma layout), LBO/SBO chosen so the warpgroup walks the 64x8 tile.
    // We use the documented non-swizzle byte offsets: LBO = 8*4 (one row of 8
    // tf32 = 32B) won't satisfy the 16B encode; the canonical encode uses the
    // core-matrix offsets. For the minimal probe we pass LBO/SBO from the K8
    // single-tile geometry; correctness is verified numerically below.
    uint64_t descA = make_smem_desc(As, /*lbo=*/ 16, /*sbo=*/ 8 * 8 * 4);
    uint64_t descB = make_smem_desc(Bs, /*lbo=*/ 16, /*sbo=*/ 8 * 8 * 4);

    // 32 accumulators per thread for m64n64.
    float d[32];
    #pragma unroll
    for (int i = 0; i < 32; ++i) d[i] = 0.f;

    asm volatile("wgmma.fence.sync.aligned;\n" ::: "memory");
    asm volatile(
        "wgmma.mma_async.sync.aligned.m64n64k8.f32.tf32.tf32 "
        "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15,"
        " %16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31}, "
        "%32, %33, 1, 1, 1, 0, 0;\n"
        : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3]),"+f"(d[4]),"+f"(d[5]),"+f"(d[6]),"+f"(d[7]),
          "+f"(d[8]),"+f"(d[9]),"+f"(d[10]),"+f"(d[11]),"+f"(d[12]),"+f"(d[13]),"+f"(d[14]),"+f"(d[15]),
          "+f"(d[16]),"+f"(d[17]),"+f"(d[18]),"+f"(d[19]),"+f"(d[20]),"+f"(d[21]),"+f"(d[22]),"+f"(d[23]),
          "+f"(d[24]),"+f"(d[25]),"+f"(d[26]),"+f"(d[27]),"+f"(d[28]),"+f"(d[29]),"+f"(d[30]),"+f"(d[31])
        : "l"(descA), "l"(descB));
    asm volatile("wgmma.commit_group.sync.aligned;\n" ::: "memory");
    asm volatile("wgmma.wait_group.sync.aligned 0;\n" ::: "memory");

    // Canonical wgmma m64nN accumulator -> C layout (PTX ISA 9.7.13.4.7):
    //   warp w = tid/32 (0..3) owns C rows [16w, 16w+16).
    //   within a warp, lane l: rows {l/4, l/4+8}; the 32 d-regs cover N in
    //   pairs (d[2c], d[2c+1]) at cols {2*(l%4), 2*(l%4)+1} + 8*(c/2)... the
    //   exact stride is: for f32 N=64, each thread holds N/2=32 elems across
    //   16 column-groups of 2. Map per the canonical formula:
    int warp = tid >> 5;       // 0..3
    int lane = tid & 31;       // 0..31
    int row_base = warp * 16 + (lane >> 2);   // + {0,8}
    int col_base = (lane & 3) * 2;            // 0,2,4,6
    #pragma unroll
    for (int c = 0; c < 8; ++c) {        // 8 column octets
        #pragma unroll
        for (int r = 0; r < 2; ++r) {    // row {+0,+8}
            #pragma unroll
            for (int p = 0; p < 2; ++p) {// the 2-wide column pair
                int idx = c * 4 + r * 2 + p;
                int row = row_base + r * 8;
                int col = col_base + p + c * 8;
                if (row < 64 && col < 64) gD[row * 64 + col] = d[idx];
            }
        }
    }
}

static inline float tf32_round(float x) {
    // Truncate fp32 mantissa to 10 bits (tf32) for the reference, matching the
    // tensor-core input rounding (RNA in hardware; truncation is a close ref).
    uint32_t u; memcpy(&u, &x, 4);
    u = (u + 0x1000u) & 0xFFFFE000u;   // round-to-nearest at bit 13
    float r; memcpy(&r, &u, 4); return r;
}

int main() {
    const int M = 64, N = 64, K = 8;
    float *hA = new float[M*K], *hB = new float[K*N], *hD = new float[M*N];
    srand(1234);
    for (int i = 0; i < M*K; ++i) hA[i] = (float)((rand() % 17) - 8) * 0.125f;
    for (int i = 0; i < K*N; ++i) hB[i] = (float)((rand() % 17) - 8) * 0.125f;

    // CPU TF32-rounded reference: Dref = A * B
    float *Dref = new float[M*N];
    for (int m = 0; m < M; ++m)
        for (int n = 0; n < N; ++n) {
            float acc = 0.f;
            for (int k = 0; k < K; ++k)
                acc += tf32_round(hA[m*K+k]) * tf32_round(hB[k*N+n]);
            Dref[m*N+n] = acc;
        }

    float *dA, *dB, *dD;
    CK(cudaMalloc(&dA, M*K*4)); CK(cudaMalloc(&dB, K*N*4)); CK(cudaMalloc(&dD, M*N*4));
    CK(cudaMemcpy(dA, hA, M*K*4, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB, hB, K*N*4, cudaMemcpyHostToDevice));
    CK(cudaMemset(dD, 0, M*N*4));

    size_t smem = (M*K + K*N) * sizeof(float);
    wgmma_tf32_kernel<<<1, 128, smem>>>(dA, dB, dD);
    CK(cudaGetLastError());
    CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(hD, dD, M*N*4, cudaMemcpyDeviceToHost));

    double se = 0, sr = 0; int nonzero = 0;
    for (int i = 0; i < M*N; ++i) {
        double e = (double)hD[i] - (double)Dref[i];
        se += e*e; sr += (double)Dref[i]*Dref[i];
        if (hD[i] != 0.f) ++nonzero;
    }
    double relrms = sqrt(se / fmax(1e-12, sr));
    printf("WGMMA_TF32_PROBE nonzero=%d/%d rel_rms=%.3e ref0=%.4f gpu0=%.4f\n",
           nonzero, M*N, relrms, Dref[0], hD[0]);
    int pass = (nonzero > M*N*3/4) && (relrms <= 3e-3);
    printf("WGMMA_TF32_PROBE: %s\n", pass ? "PASS" : "FAIL");
    return pass ? 0 : 2;
}
