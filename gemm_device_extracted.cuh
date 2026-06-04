// gemm_device_extracted.cuh — the WMMA2 own-GEMM body as a __device__ function.
//
// This is _hx_k_sgemm_cm_wmma2 (self/native/hxqwen14b_cuda.cu, PR #2704) with
// EXACTLY ONE change: the macro-tile coordinate (blockRow, blockCol) is taken
// from explicit (tileRow, tileCol) parameters instead of blockIdx.{x,y}, so the
// body can be invoked from inside the persistent megakernel for ANY tile (the
// megakernel strides one block over multiple tiles). Everything else — the
// 8-warp warp-tiling, double-buffered cp.async staging, TF32 rounding, register
// accumulators, alpha/beta col-major epilogue — is byte-for-byte the shipped
// kernel. The HXG_* defines + hxg_cp* helpers come from gemm_kernels_extracted.cuh
// (#included before this file).
//
// CONTRACT: identical TF32 own-GEMM math as the __global__ _hx_k_sgemm_cm_wmma2.
// Both the eager path (which launches the __global__) and the megakernel (which
// calls this __device__ wrapper) therefore run the SAME numeric kernel; the only
// possible rel-RMS source between the two paths is tile *visitation order*
// within a block when nTiles > gridDim (the per-tile result is identical).
//
// NOTE: a thread block of 256 threads (8 warps) is REQUIRED, same as the
// __global__. The megakernel launches 256-thread blocks.

__device__ __forceinline__ void wmma2_tile_device(
        long long tileRow, long long tileCol,
        int tA, int tB, long long M, long long N, long long K,
        float alpha, const float* __restrict__ A, long long lda,
        const float* __restrict__ B, long long ldb,
        float beta, float* __restrict__ C, long long ldc) {
    const long long blockRow = tileRow * HXG_BM;  // C rows [blockRow, +128)
    const long long blockCol = tileCol * HXG_BN;  // C cols [blockCol, +64)
    const int tid  = threadIdx.x;                 // 0..255
    const int warp = tid >> 5;                    // 0..7
    const int lane = tid & 31;                    // 0..31
    const int warpRow = warp / HXG_WCOLS;         // 0..3
    const int warpCol = warp % HXG_WCOLS;         // 0..1

    __shared__ float As[2][HXG_BM * HXG_BK];   // 2 × 128×32
    __shared__ float Bs[2][HXG_BK * HXG_BN];   // 2 × 32×64

    nvcuda::wmma::fragment<nvcuda::wmma::accumulator,16,16,8,float> acc[HXG_FM][HXG_FN];
    #pragma unroll
    for (int fm=0; fm<HXG_FM; fm++)
        #pragma unroll
        for (int fn=0; fn<HXG_FN; fn++)
            nvcuda::wmma::fill_fragment(acc[fm][fn], 0.0f);

    auto stageA = [&](int buf, long long kk0){
        #pragma unroll
        for (int e=0; e<(HXG_BM*HXG_BK)/256; e++) {
            int idx = e*256 + tid;
            int i = idx / HXG_BK;
            int l = idx % HXG_BK;
            long long r = blockRow + i, kk = kk0 + l;
            int pred = (r < M && kk < K);
            const float* sp = pred ? (tA ? &A[kk + r*lda] : &A[r + kk*lda]) : (const float*)0;
            hxg_cp4(&As[buf][idx], sp, pred);
        }
    };
    auto stageB = [&](int buf, long long kk0){
        #pragma unroll
        for (int e=0; e<(HXG_BK*HXG_BN)/256; e++) {
            int idx = e*256 + tid;
            int l = idx / HXG_BN;
            int j = idx % HXG_BN;
            long long kk = kk0 + l, c = blockCol + j;
            int pred = (kk < K && c < N);
            const float* sp = pred ? (tB ? &B[c + kk*ldb] : &B[kk + c*ldb]) : (const float*)0;
            hxg_cp4(&Bs[buf][idx], sp, pred);
        }
    };

    int buf = 0;
    stageA(buf, 0); stageB(buf, 0); hxg_cp_commit(); hxg_cp_wait();
    __syncthreads();

    nvcuda::wmma::fragment<nvcuda::wmma::matrix_a,16,16,8,nvcuda::wmma::precision::tf32,nvcuda::wmma::row_major> a_frag[HXG_FM][HXG_FK];
    nvcuda::wmma::fragment<nvcuda::wmma::matrix_b,16,16,8,nvcuda::wmma::precision::tf32,nvcuda::wmma::row_major> b_frag[HXG_FK][HXG_FN];

    for (long long k0 = 0; k0 < K; k0 += HXG_BK) {
        long long kNext = k0 + HXG_BK;
        int nbuf = buf ^ 1;
        if (kNext < K) { stageA(nbuf, kNext); stageB(nbuf, kNext); hxg_cp_commit(); }

        #pragma unroll
        for (int fk=0; fk<HXG_FK; fk++) {
            #pragma unroll
            for (int fm=0; fm<HXG_FM; fm++) {
                int srow = warpRow*HXG_WM + fm*16;
                int scol = fk*8;
                nvcuda::wmma::load_matrix_sync(a_frag[fm][fk], &As[buf][srow*HXG_BK + scol], HXG_BK);
                #pragma unroll
                for (int t=0; t<a_frag[fm][fk].num_elements; t++)
                    a_frag[fm][fk].x[t] = nvcuda::wmma::__float_to_tf32(a_frag[fm][fk].x[t]);
            }
            #pragma unroll
            for (int fn=0; fn<HXG_FN; fn++) {
                int srow = fk*8;
                int scol = warpCol*HXG_WN + fn*16;
                nvcuda::wmma::load_matrix_sync(b_frag[fk][fn], &Bs[buf][srow*HXG_BN + scol], HXG_BN);
                #pragma unroll
                for (int t=0; t<b_frag[fk][fn].num_elements; t++)
                    b_frag[fk][fn].x[t] = nvcuda::wmma::__float_to_tf32(b_frag[fk][fn].x[t]);
            }
        }
        #pragma unroll
        for (int fm=0; fm<HXG_FM; fm++)
            #pragma unroll
            for (int fn=0; fn<HXG_FN; fn++)
                #pragma unroll
                for (int fk=0; fk<HXG_FK; fk++)
                    nvcuda::wmma::mma_sync(acc[fm][fn], a_frag[fm][fk], b_frag[fk][fn], acc[fm][fn]);

        if (kNext < K) { hxg_cp_wait(); __syncthreads(); buf = nbuf; }
    }

    __shared__ float tmp[HXG_WARPS][16*16];
    #pragma unroll
    for (int fm=0; fm<HXG_FM; fm++) {
        #pragma unroll
        for (int fn=0; fn<HXG_FN; fn++) {
            nvcuda::wmma::store_matrix_sync(tmp[warp], acc[fm][fn], 16, nvcuda::wmma::mem_row_major);
            __syncwarp();
            int rowBase = (int)(blockRow) + warpRow*HXG_WM + fm*16;
            int colBase = (int)(blockCol) + warpCol*HXG_WN + fn*16;
            for (int e=lane; e<256; e+=32) {
                int i = e >> 4, j = e & 15;
                long long r = rowBase + i, c = colBase + j;
                if (r < M && c < N) {
                    float prev = (beta != 0.0f) ? C[r + c*ldc] : 0.0f;
                    C[r + c*ldc] = alpha * tmp[warp][e] + beta * prev;
                }
            }
            __syncwarp();
        }
    }
    // IMPORTANT: a trailing __syncthreads() so the next strided tile this block
    // computes does not clobber As/Bs/tmp shared while a lagging warp still reads.
    __syncthreads();
}
