/* CUTLASS-style proxy for cuBLAS s16816gemm_f16_64x64_32x6_nn_align8.
 *
 * Spec inferred from kernel name + nsys launch geometry:
 *   - s16816   = sm_80 mma.sync.aligned.m16n8k16 fp16->fp32
 *   - 64x64    = CTA output tile MxN (FP32 accum, FP16 ops)
 *   - 32       = CTA K-tile (each main loop iter consumes 32 K)
 *   - x6       = 6-stage software pipeline (cp.async.commit_group / wait_group)
 *   - nn       = both operands row-major (A NN: row-major M-major, B NN: col-major K-major)
 *   - align8   = LDG vec8 (16-byte) on FP16 = 8-elem alignment
 *   - blockDim = 128 thd (4 warps), gridDim observed = (192,3,1) for M=N=1536
 *
 * NOT a verbatim copy of cuBLAS SASS -- a structural reproduction for SASS diff
 * vs hexa N89. Compile: nvcc -O3 -arch=sm_90 -o proxy proxy.cu --ptx (or --cubin)
 *
 * Per-warp work:
 *   output tile / warps = 64x64 / 4 warps = warp_tile 32x32 (using mma m16n8k16 -> 2x4 = 8 mma per warp)
 *   per K-step: warp loads frag A 32x16 + frag B 16x32 from shared, executes 8 mma.m16n8k16
 */

#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <mma.h>

#define CTA_M 64
#define CTA_N 64
#define CTA_K 32
#define WARPS 4
#define STAGES 6
#define THREADS (32*WARPS)

extern "C" __global__ __launch_bounds__(THREADS)
void cublas_proxy_64x64x32_s6_nn_align8(
    const __half * __restrict__ A,  // M x K row-major
    const __half * __restrict__ B,  // K x N col-major (== N x K row-major)
    float        * __restrict__ C,  // M x N row-major
    int M, int N, int K)
{
    using namespace nvcuda;

    extern __shared__ __align__(16) __half smem_storage[];
    // double layout: STAGES copies of (A tile 64x32 + B tile 32x64) -> 6 * (64*32 + 32*64) * 2B = 24576 B
    __half *sA = smem_storage;
    __half *sB = smem_storage + STAGES * (CTA_M * CTA_K);
    const int stage_A_stride = CTA_M * CTA_K;
    const int stage_B_stride = CTA_K * CTA_N;

    int cta_m = blockIdx.y * CTA_M;
    int cta_n = blockIdx.x * CTA_N;

    int warp_id = threadIdx.x / 32;
    int lane    = threadIdx.x & 31;

    // 4 warps -> 2x2 spatial layout in 64x64 output
    int warp_m = (warp_id & 1) * 32;
    int warp_n = (warp_id >> 1) * 32;

    // Each warp computes 32x32 sub-tile using m16n8k16 mma
    // -> 2 m-rows x 4 n-cols = 8 mma per warp per K-step (K=32 = 2 mma.k16 chunks per K-step)

    float c00[2][4]={{0}},c01[2][4]={{0}};  // 8 accumulators of 4 floats each = 32 reg/warp

    // Initialize accumulators to 0 (already done above)

    // Software pipeline: prologue (STAGES-1) async loads, then steady-state main loop
    int k_tiles = (K + CTA_K - 1) / CTA_K;
    int prologue = STAGES - 1;
    if (prologue > k_tiles) prologue = k_tiles;

    auto async_load_stage = [&](int stage, int k_offset){
        // 128 threads cooperatively load 64x32 A and 32x64 B from gmem (vec8 = 16B per LDG).
        // 64*32 fp16 = 4096 B -> 256 vec8 = 256 / 128 = 2 per thread
        const int A_total = CTA_M * CTA_K;
        const int B_total = CTA_K * CTA_N;
        // A: row-major, row m -> A[m*K + k_offset + col]
        #pragma unroll
        for (int it = 0; it < 2; ++it) {
            int tid = threadIdx.x + it * THREADS;
            int row = tid / (CTA_K / 8); // 8 = vec8 fp16
            int col_v = tid % (CTA_K / 8);
            int col = col_v * 8;
            if (cta_m + row < M && k_offset + col < K) {
                int4 v = *reinterpret_cast<const int4 *>(&A[(cta_m + row)*K + k_offset + col]);
                *reinterpret_cast<int4 *>(&sA[stage*stage_A_stride + row*CTA_K + col]) = v;
            }
        }
        // B: stored col-major in gmem [K x N], i.e. B[col*K + row]; load 32x64
        #pragma unroll
        for (int it = 0; it < 2; ++it) {
            int tid = threadIdx.x + it * THREADS;
            int col = tid / (CTA_K / 8); // n-index 0..63
            int row_v = tid % (CTA_K / 8);
            int row = row_v * 8;
            if (cta_n + col < N && k_offset + row < K) {
                int4 v = *reinterpret_cast<const int4 *>(&B[(cta_n + col)*K + k_offset + row]);
                *reinterpret_cast<int4 *>(&sB[stage*stage_B_stride + col*CTA_K + row]) = v;
            }
        }
        // cp.async equivalent on sm_80+ via builtin
        asm volatile("cp.async.commit_group;\n" ::);
    };

    // Prologue: fire (STAGES-1) async loads, no wait yet
    int next_k = 0;
    for (int s = 0; s < prologue; ++s) {
        async_load_stage(s, next_k);
        next_k += CTA_K;
    }

    // Main loop
    int stage_compute = 0;
    int stage_issue   = prologue;
    int kt = 0;
    for (; kt < k_tiles; ++kt) {
        // Wait STAGES-1 prior to ensure stage_compute is ready
        asm volatile("cp.async.wait_group %0;\n" :: "n"(STAGES-2));
        __syncthreads();

        const __half *A_stage = sA + stage_compute * stage_A_stride;
        const __half *B_stage = sB + stage_compute * stage_B_stride;

        // Inner K loop: 32 = 2 chunks of 16
        #pragma unroll
        for (int ki = 0; ki < CTA_K; ki += 16) {
            // Load 8 fragments via ldmatrix.x4
            unsigned ra[4];
            unsigned rb[2][2];

            // ldmatrix for A: 16x16 fp16 per warp slice, 2 rows for 32x16 warp_m
            #pragma unroll
            for (int mi = 0; mi < 2; ++mi) {
                int row = warp_m + mi*16 + (lane & 15);
                int col = ki + ((lane >> 4) * 8);
                unsigned a_addr = __cvta_generic_to_shared(&A_stage[row*CTA_K + col]);
                asm volatile("ldmatrix.sync.aligned.x4.m8n8.shared.b16 {%0,%1,%2,%3}, [%4];\n"
                             : "=r"(ra[0]),"=r"(ra[1]),"=r"(ra[2]),"=r"(ra[3]) : "r"(a_addr));

                // 4 B-cols of 8: ldmatrix.x4 over 16x16 B
                #pragma unroll
                for (int nj = 0; nj < 4; ++nj) {
                    int b_row = ki + (lane & 15);
                    int b_col = warp_n + nj*8 + ((lane >> 4) * 8);
                    unsigned b_addr = __cvta_generic_to_shared(&B_stage[b_col*CTA_K + b_row]);
                    unsigned rb_local;
                    asm volatile("ldmatrix.sync.aligned.x1.m8n8.shared.b16 {%0}, [%1];\n"
                                 : "=r"(rb_local) : "r"(b_addr));
                    // mma m16n8k16 fp16->fp32
                    asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 "
                                 "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
                                 : "+f"(c00[mi][nj]), "+f"(c01[mi][nj]), "+f"(c00[mi][nj]), "+f"(c01[mi][nj])
                                 : "r"(ra[0]),"r"(ra[1]),"r"(ra[2]),"r"(ra[3]), "r"(rb_local), "r"(rb_local));
                }
            }
        }

        // Issue next async load if more K-tiles remain
        if (stage_issue < k_tiles + STAGES - 1) {
            if (next_k < K) {
                async_load_stage(stage_issue % STAGES, next_k);
                next_k += CTA_K;
            } else {
                asm volatile("cp.async.commit_group;\n" ::);
            }
            stage_issue++;
        }
        stage_compute = (stage_compute + 1) % STAGES;
    }

    asm volatile("cp.async.wait_all;\n" ::);
    __syncthreads();

    // Epilogue: write 32x32 per warp to C
    #pragma unroll
    for (int mi = 0; mi < 2; ++mi) {
        #pragma unroll
        for (int nj = 0; nj < 4; ++nj) {
            int row = cta_m + warp_m + mi*16 + (lane >> 2);
            int col = cta_n + warp_n + nj*8  + (lane & 3) * 2;
            if (row < M && col < N) C[row*N + col]   = c00[mi][nj];
            if (row < M && col+1 < N) C[row*N + col+1] = c01[mi][nj];
        }
    }
}
