// hxqwen14b_cuda.cu — v5.3 CUDA kernels for hxqwen14b FFI shim.
//
// This file ships the 4 attention primitive CUDA kernels +
// host-side launchers exposed as extern "C" so the main .c shim can
// link against them. It's compiled with nvcc; the main .c continues
// to compile with gcc, avoiding the C++ goto-over-init errors that
// would otherwise fire against v5.1 pre-existing code.
//
// Symbols exported (all return int rc; 0=OK, nonzero=CUDA error):
//   hxqwen14b_cu_launch_rmsnorm
//   hxqwen14b_cu_launch_rope
//   hxqwen14b_cu_launch_gqa
//   hxqwen14b_cu_launch_swiglu
//   hxqwen14b_cu_memcpy_h2d
//   hxqwen14b_cu_memcpy_d2h
//   hxqwen14b_cu_malloc_bytes   (returns device ptr as int64)
//   hxqwen14b_cu_free_ptr
//   hxqwen14b_cu_device_sync

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <mma.h>
#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define HXQ_RC_OK          0
#define HXQ_RC_KERNEL_FAIL -4

// ═════════════════════════════════════════════════════════════════════
// Kernel 1: RMSNorm forward
//   y[i,j] = x[i,j] * rsqrt(mean(x[i]^2) + eps) * w[j]
// Grid: (M, 1). Block: threads tree-reduce per row then broadcast.
// ═════════════════════════════════════════════════════════════════════
__global__ void v53_rmsnorm_kernel(
    const float* __restrict__ x,
    const float* __restrict__ w,
    float* __restrict__ y,
    int d, float eps
) {
    int row = blockIdx.x;
    int tid = threadIdx.x;
    const float* xr = x + row * d;
    float*       yr = y + row * d;

    float sum_sq = 0.0f;
    for (int j = tid; j < d; j += blockDim.x) {
        float v = xr[j];
        sum_sq += v * v;
    }
    // warp-level reduce then cross-warp via shared.
    __shared__ float s_red[32];
    unsigned mask = 0xffffffff;
    for (int off = 16; off > 0; off >>= 1) {
        sum_sq += __shfl_down_sync(mask, sum_sq, off);
    }
    int warp_id = tid >> 5;
    int lane    = tid & 31;
    if (lane == 0) s_red[warp_id] = sum_sq;
    __syncthreads();
    if (warp_id == 0) {
        int n_warps = (blockDim.x + 31) >> 5;
        float v = (lane < n_warps) ? s_red[lane] : 0.0f;
        for (int off = 16; off > 0; off >>= 1) {
            v += __shfl_down_sync(mask, v, off);
        }
        if (lane == 0) s_red[0] = v;
    }
    __syncthreads();
    float mean_sq = s_red[0] / (float)d;
    float inv_rms = rsqrtf(mean_sq + eps);
    for (int j = tid; j < d; j += blockDim.x) {
        yr[j] = xr[j] * inv_rms * w[j];
    }
}

// ═════════════════════════════════════════════════════════════════════
// Kernel 2: RoPE rotate_half forward (in-place, Llama/Qwen2 layout — v5.4.3)
// Grid: (B*S, n_heads). Block: head_dim/2 threads — one per freq index.
// Pair layout: x0 = x[k], x1 = x[D/2+k]. Each thread owns unique (k, D/2+k)
// slot pair — safe in-place after register load.
// Matches HF transformers.models.qwen2.modeling_qwen2.apply_rotary_pos_emb:
//   rotate_half(x) = cat([-x[..., D/2:], x[..., :D/2]], dim=-1)
// Prior interleaved (GPT-J / NeoX) version confirmed incompatible with
// Qwen2 weights — v5.4.2 smoke CE=16.09 before this fix.
// ═════════════════════════════════════════════════════════════════════
__global__ void v53_rope_kernel(
    float* __restrict__ x,
    int B, int S, int H, int D,
    float theta_base, int pos_offset
) {
    int bs   = blockIdx.x;
    int h    = blockIdx.y;
    int k    = threadIdx.x;
    int half = D >> 1;
    if (k >= half) return;
    (void)B;
    int s = bs - (bs / S) * S;
    float pos = (float)(pos_offset + s);
    // HF Qwen2 freq formula: inv_freq[k] = 1 / theta^(2k/D), k in [0, D/2).
    float inv_freq = powf(theta_base, -((float)(2 * k)) / (float)D);
    float angle    = pos * inv_freq;
    float cs, sn;
    __sincosf(angle, &sn, &cs);

    int base = (bs * H + h) * D;
    float x0 = x[base + k];
    float x1 = x[base + half + k];
    x[base + k]        = x0 * cs - x1 * sn;
    x[base + half + k] = x1 * cs + x0 * sn;
}

// ═════════════════════════════════════════════════════════════════════
// Kernel 3: GQA attention forward (hand-rolled online softmax)
// Grid: (B, HQ, S). Block: head_dim threads. No flash tiling — reference.
// ═════════════════════════════════════════════════════════════════════
__global__ void v53_gqa_kernel(
    const float* __restrict__ Q,
    const float* __restrict__ K,
    const float* __restrict__ V,
    float* __restrict__ O,
    int B, int S, int HQ, int HK, int D,
    float scale, int causal
) {
    int b  = blockIdx.x;
    int hq = blockIdx.y;
    int i  = blockIdx.z;
    int d  = threadIdx.x;
    if (d >= D) return;
    int G  = HQ / HK;
    int hk = hq / G;
    (void)B;

    const float* qi = Q + (((b * S + i) * HQ + hq) * D);
    float*       oi = O + (((b * S + i) * HQ + hq) * D);

    __shared__ float s_m;
    __shared__ float s_l;
    __shared__ float s_qi[256];
    __shared__ float s_dot_red[8];
    __shared__ float s_alpha;
    __shared__ float s_mnew;

    if (d == 0) { s_m = -1e30f; s_l = 0.0f; }
    s_qi[d] = qi[d];
    __syncthreads();

    float acc = 0.0f;
    int j_end = causal ? (i + 1) : S;
    unsigned mask = 0xffffffff;

    for (int j = 0; j < j_end; j++) {
        const float* kj = K + (((b * S + j) * HK + hk) * D);
        const float* vj = V + (((b * S + j) * HK + hk) * D);

        float partial = s_qi[d] * kj[d];
        for (int off = 16; off > 0; off >>= 1) {
            partial += __shfl_down_sync(mask, partial, off);
        }
        int warp = d >> 5;
        int lane = d & 31;
        if (lane == 0) s_dot_red[warp] = partial;
        __syncthreads();
        if (warp == 0) {
            int n_warps = (D + 31) >> 5;
            float v = (lane < n_warps) ? s_dot_red[lane] : 0.0f;
            for (int off = 16; off > 0; off >>= 1) {
                v += __shfl_down_sync(mask, v, off);
            }
            if (lane == 0) s_dot_red[0] = v;
        }
        __syncthreads();
        float dot = s_dot_red[0] * scale;

        if (d == 0) {
            float m_new = (dot > s_m) ? dot : s_m;
            s_alpha = expf(s_m - m_new);
            s_mnew  = m_new;
            s_m     = m_new;
        }
        __syncthreads();
        float a  = s_alpha;
        float mn = s_mnew;

        acc = acc * a;
        float p = expf(dot - mn);
        if (d == 0) s_l = s_l * a + p;
        __syncthreads();
        acc += p * vj[d];
    }
    __syncthreads();
    float inv_l = (s_l > 0.0f) ? 1.0f / s_l : 0.0f;
    oi[d] = acc * inv_l;
}

// ═════════════════════════════════════════════════════════════════════
// Kernel 4: SwiGLU forward, element-wise.
//   y[i] = silu(gate[i]) * up[i]
// ═════════════════════════════════════════════════════════════════════
__global__ void v53_swiglu_kernel(
    const float* __restrict__ g,
    const float* __restrict__ u,
    float* __restrict__ y,
    int64_t N
) {
    int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;
    float gi = g[i];
    float sig;
    if (gi >= 0.0f) {
        sig = 1.0f / (1.0f + expf(-gi));
    } else {
        float e = expf(gi);
        sig = e / (1.0f + e);
    }
    y[i] = (gi * sig) * u[i];
}

// ═════════════════════════════════════════════════════════════════════
// Host-side launchers — extern "C" so the main .c shim can link these.
// Each returns 0 on success, nonzero on CUDA error.
// ═════════════════════════════════════════════════════════════════════
extern "C" {

int hxqwen14b_cu_launch_rmsnorm(
    const float* x_dev, const float* w_dev, float* y_dev,
    int64_t M, int64_t d, float eps)
{
    int threads = 256;
    if (d < 256) threads = 128;
    if (d < 128) threads = 64;
    v53_rmsnorm_kernel<<<(unsigned)M, threads>>>(x_dev, w_dev, y_dev, (int)d, eps);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

int hxqwen14b_cu_launch_rope(
    float* x_dev, int64_t B, int64_t S, int64_t H, int64_t D,
    float theta_base, int64_t pos_offset)
{
    dim3 grid((unsigned)(B * S), (unsigned)H, 1);
    int  threads = (int)(D / 2);
    if (threads < 32) threads = 32;
    v53_rope_kernel<<<grid, threads>>>(x_dev, (int)B, (int)S, (int)H, (int)D,
                                        theta_base, (int)pos_offset);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

int hxqwen14b_cu_launch_gqa(
    const float* Q_dev, const float* K_dev, const float* V_dev, float* O_dev,
    int64_t B, int64_t S, int64_t HQ, int64_t HK, int64_t D,
    float scale, int64_t causal)
{
    dim3 grid((unsigned)B, (unsigned)HQ, (unsigned)S);
    int  threads = (int)D;
    v53_gqa_kernel<<<grid, threads>>>(Q_dev, K_dev, V_dev, O_dev, (int)B, (int)S,
                                       (int)HQ, (int)HK, (int)D,
                                       scale, (int)causal);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

int hxqwen14b_cu_launch_swiglu(
    const float* g_dev, const float* u_dev, float* y_dev, int64_t N)
{
    int threads = 256;
    unsigned blocks = (unsigned)((N + threads - 1) / threads);
    v53_swiglu_kernel<<<blocks, threads>>>(g_dev, u_dev, y_dev, N);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

// ─────────────────────────────────────────────────────────────
// Memory + sync helpers. These let the main .c shim manage device
// buffers without needing to include cuda_runtime.h directly.
// Pointers returned via int64_t for ABI cleanliness.
// ─────────────────────────────────────────────────────────────
int64_t hxqwen14b_cu_malloc_bytes(int64_t n_bytes) {
    if (n_bytes <= 0) return 0;
    void* p = NULL;
    cudaError_t e = cudaMalloc(&p, (size_t)n_bytes);
    if (e != cudaSuccess) return 0;
    return (int64_t)(uintptr_t)p;
}

int hxqwen14b_cu_free_ptr(int64_t dev_ptr) {
    if (dev_ptr == 0) return HXQ_RC_OK;
    cudaError_t e = cudaFree((void*)(uintptr_t)dev_ptr);
    return (e == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

int hxqwen14b_cu_memcpy_h2d(int64_t dst_dev, const void* src_host, int64_t n_bytes) {
    if (dst_dev == 0 || src_host == NULL || n_bytes <= 0) return -1;
    cudaError_t e = cudaMemcpy((void*)(uintptr_t)dst_dev, src_host,
                                (size_t)n_bytes, cudaMemcpyHostToDevice);
    return (e == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

int hxqwen14b_cu_memcpy_d2h(void* dst_host, int64_t src_dev, int64_t n_bytes) {
    if (dst_host == NULL || src_dev == 0 || n_bytes <= 0) return -1;
    cudaError_t e = cudaMemcpy(dst_host, (const void*)(uintptr_t)src_dev,
                                (size_t)n_bytes, cudaMemcpyDeviceToHost);
    return (e == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

int hxqwen14b_cu_device_sync(void) {
    cudaError_t e = cudaDeviceSynchronize();
    return (e == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

}  // extern "C" (close v5.3 block; v5.4 kernels below are not in extern C)

// ═════════════════════════════════════════════════════════════════════
// v5.4 additions: kernels + launchers for full 48-layer LM forward.
//
//   - bf16→fp32 dequant kernel (used to hydrate weight tensors loaded by
//     v5.3 load_tensor_bf16 into fp32 device buffers, which the existing
//     v5.3 kernels + cuBLAS Sgemm consume).
//   - embed_lookup_kernel: gather rows from embed table [V,d] by token id.
//   - cuBLAS Sgemm launcher: thin wrapper that handles row-major semantics
//     for (M,K) × (K,N) → (M,N) = x @ W (used for q/k/v/o/gate/up/down).
//     W stored as [N,K] row-major (HF convention: weight shape [out, in]),
//     so we compute x[M,K] @ W^T [K,N] → out [M,N].
//   - tied_lm_head_launcher: same as sgemm but semantically projects
//     [M,d] × embed[V,d]^T → logits [M,V]. (embed is tied to lm_head.)
//   - causal_softmax_ce_kernel: log_softmax over vocab, gather target
//     token's log-prob, sum-negate → CE per sample. Returns mean CE.
//   - residual_add_kernel: elementwise y[i] += x[i].
//   - bf16 weights are stored in device memory as uint16 packed in fp32
//     buffers (v5.3 load_tensor_bf16 already does this — the bytes are
//     raw bf16 in device memory, 2 bytes per element). v5.4 dequants them
//     on the fly into separate fp32 buffers for Sgemm consumption.
// ═════════════════════════════════════════════════════════════════════

#include <cuda_bf16.h>

// Dequantize bf16 (stored as uint16 half of a 32-bit pair? No — actually
// v5.3 load_tensor_bf16 writes n_elems*2 bytes to device as raw bf16.
// Each element is 2 bytes. We treat the device buffer as __nv_bfloat16*.
__global__ void v54_bf16_to_fp32_kernel(
    const __nv_bfloat16* __restrict__ src,
    float* __restrict__ dst,
    int64_t N
) {
    int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;
    dst[i] = __bfloat162float(src[i]);
}

// Embed lookup: for each token_ids[m] (m in 0..M), copy embed[tok_id, :d]
// → out[m, :d]. Grid: (M,). Block: min(d, 256).
__global__ void v54_embed_lookup_kernel(
    const float* __restrict__ embed,  // [V, d]
    const int32_t* __restrict__ ids,  // [M]
    float* __restrict__ out,          // [M, d]
    int64_t V, int64_t d
) {
    int64_t m = blockIdx.x;
    int32_t tid = ids[m];
    if (tid < 0 || (int64_t)tid >= V) tid = 0;
    const float* src = embed + (int64_t)tid * d;
    float*       dst = out   + m * d;
    for (int64_t j = threadIdx.x; j < d; j += blockDim.x) {
        dst[j] = src[j];
    }
}

// Residual add: y[i] += x[i].
__global__ void v54_residual_add_kernel(
    const float* __restrict__ x, float* __restrict__ y, int64_t N
) {
    int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;
    y[i] += x[i];
}

// v5.4.2: 1D bias add — tensor[M, D] += bias[D] broadcast over rows.
// Grid: (M,), Block: min(D, 1024). Inner loop handles D > 1024 case
// (Q dim dq=5120 > 1024, K/V dim dkv=1024 fits exactly).
__global__ void v54_add_bias_1d_kernel(
    float* __restrict__ tensor,       // [M, D]
    const float* __restrict__ bias,   // [D]
    int64_t M, int64_t D
) {
    int64_t row = blockIdx.x;
    if (row >= M) return;
    float* tr = tensor + row * D;
    for (int64_t col = threadIdx.x; col < D; col += blockDim.x) {
        tr[col] += bias[col];
    }
}

// Log-softmax + gather target token's nll, then reduce to sum.
// Grid: (M,). Block: min(V_pow2, 256). Shared: max + sum.
// out_nll: [M] — each cell's -log p(target[m]).
__global__ void v54_softmax_ce_kernel(
    const float* __restrict__ logits,   // [M, V]
    const int32_t* __restrict__ targets,// [M]
    float* __restrict__ out_nll,        // [M]
    int64_t V
) {
    int64_t m = blockIdx.x;
    int32_t tgt = targets[m];
    const float* lr = logits + m * V;

    __shared__ float s_max;
    __shared__ float s_sum;
    if (threadIdx.x == 0) { s_max = -1e30f; s_sum = 0.0f; }
    __syncthreads();

    // pass 1: max
    float my_max = -1e30f;
    for (int64_t j = threadIdx.x; j < V; j += blockDim.x) {
        float v = lr[j];
        if (v > my_max) my_max = v;
    }
    // block reduce max
    unsigned mask = 0xffffffff;
    for (int off = 16; off > 0; off >>= 1) {
        float o = __shfl_down_sync(mask, my_max, off);
        if (o > my_max) my_max = o;
    }
    __shared__ float s_max_red[32];
    int lane = threadIdx.x & 31;
    int warp = threadIdx.x >> 5;
    if (lane == 0) s_max_red[warp] = my_max;
    __syncthreads();
    if (warp == 0) {
        int n_warps = (blockDim.x + 31) >> 5;
        float v = (lane < n_warps) ? s_max_red[lane] : -1e30f;
        for (int off = 16; off > 0; off >>= 1) {
            float o = __shfl_down_sync(mask, v, off);
            if (o > v) v = o;
        }
        if (lane == 0) s_max = v;
    }
    __syncthreads();
    float mx = s_max;

    // pass 2: sum of exp(x - max)
    float my_sum = 0.0f;
    for (int64_t j = threadIdx.x; j < V; j += blockDim.x) {
        my_sum += expf(lr[j] - mx);
    }
    for (int off = 16; off > 0; off >>= 1) {
        my_sum += __shfl_down_sync(mask, my_sum, off);
    }
    __shared__ float s_sum_red[32];
    if (lane == 0) s_sum_red[warp] = my_sum;
    __syncthreads();
    if (warp == 0) {
        int n_warps = (blockDim.x + 31) >> 5;
        float v = (lane < n_warps) ? s_sum_red[lane] : 0.0f;
        for (int off = 16; off > 0; off >>= 1) v += __shfl_down_sync(mask, v, off);
        if (lane == 0) s_sum = v;
    }
    __syncthreads();

    if (threadIdx.x == 0) {
        float logZ = logf(s_sum) + mx;
        float lp;
        if (tgt >= 0 && (int64_t)tgt < V) {
            lp = lr[tgt] - logZ;
        } else {
            lp = -logZ;  // degenerate
        }
        out_nll[m] = -lp;
    }
}

extern "C" {

// One cuBLAS handle cached per process (lazy-init on first use).
static cublasHandle_t g_cublas_handle = NULL;
static int v54_ensure_cublas(void) {
    if (g_cublas_handle == NULL) {
        if (cublasCreate(&g_cublas_handle) != CUBLAS_STATUS_SUCCESS)
            return HXQ_RC_KERNEL_FAIL;
    }
    return HXQ_RC_OK;
}

// ═════════════════════════════════════════════════════════════════════
// Phase 1d — HEXA-FUSION CUDA-OWN FP32 GEMM (env HEXA_OWN_GEMM), frozen-base
// path. Same general column-major Sgemm kernel + dispatch shim as the LoRA
// path in hxqwen14b_emit.hexa, here over g_cublas_handle. When HEXA_OWN_GEMM
// is set+non-empty the base/lm_head/input-grad GEMMs run on our own kernel;
// otherwise cublasSgemm (OFF == byte-identical). cuBLAS = correctness oracle.
// ═════════════════════════════════════════════════════════════════════
__global__ void _hx_k_sgemm_cm_v54(int tA, int tB, long long M, long long N, long long K,
                                   float alpha, const float* A, long long lda,
                                   const float* B, long long ldb,
                                   float beta, float* C, long long ldc) {
    long long i = (long long)blockIdx.x * blockDim.x + threadIdx.x;  // C row 0..M
    long long j = (long long)blockIdx.y * blockDim.y + threadIdx.y;  // C col 0..N
    if (i >= M || j >= N) return;
    float acc = 0.0f;
    for (long long l = 0; l < K; l++) {
        float a = tA ? A[l + i*lda] : A[i + l*lda];   // op(A)[i,l], col-major
        float b = tB ? B[j + l*ldb] : B[l + j*ldb];   // op(B)[l,j], col-major
        acc += a * b;
    }
    float prev = (beta != 0.0f) ? C[i + j*ldc] : 0.0f;
    C[i + j*ldc] = alpha * acc + beta * prev;
}
// ═════════════════════════════════════════════════════════════════════
// Phase 1b — shared-memory TILED variant of _hx_k_sgemm_cm_v54. SAME col-
// major signature/semantics + transpose handling (faithful to cublasSgemm),
// but each 16×16 block cooperatively stages a HXTILE×HXTILE sub-tile of
// op(A) and op(B) into __shared__, reusing each loaded element HXTILE times
// → cuts global loads ~HXTILE× vs the naive one-thread-per-output kernel.
// NOT bit-identical to cuBLAS (accumulation order differs) — cuBLAS stays a
// correctness ORACLE (fp32 tolerance). Selected at launch via HEXA_OWN_GEMM_TILED.
// ═════════════════════════════════════════════════════════════════════
#define HXTILE 16
__global__ void _hx_k_sgemm_cm_tiled(int tA, int tB, long long M, long long N, long long K,
                                     float alpha, const float* A, long long lda,
                                     const float* B, long long ldb,
                                     float beta, float* C, long long ldc) {
    __shared__ float As[HXTILE][HXTILE];
    __shared__ float Bs[HXTILE][HXTILE];
    long long row = (long long)blockIdx.x * HXTILE + threadIdx.x;  // C row i (0..M)
    long long col = (long long)blockIdx.y * HXTILE + threadIdx.y;  // C col j (0..N)
    float acc = 0.0f;
    for (long long t = 0; t < K; t += HXTILE) {
        long long ak = t + threadIdx.y;
        As[threadIdx.x][threadIdx.y] =
            (row < M && ak < K) ? (tA ? A[ak + row*lda] : A[row + ak*lda]) : 0.0f;  // op(A)[row,ak]
        long long bk = t + threadIdx.x;
        Bs[threadIdx.x][threadIdx.y] =
            (bk < K && col < N) ? (tB ? B[col + bk*ldb] : B[bk + col*ldb]) : 0.0f;  // op(B)[bk,col]
        __syncthreads();
        for (int l = 0; l < HXTILE; l++) acc += As[threadIdx.x][l] * Bs[l][threadIdx.y];
        __syncthreads();
    }
    if (row < M && col < N) {
        float prev = (beta != 0.0f) ? C[row + col*ldc] : 0.0f;
        C[row + col*ldc] = alpha * acc + beta * prev;
    }
}
// ═════════════════════════════════════════════════════════════════════
// Phase 1b-3 (CUDA-OWN, precision-approved): TF32 Tensor-Core own-GEMM via
// the WMMA API — the cuBLAS-parity path. One warp (32 threads) per 16×16 C
// tile; K stepped by 8 (TF32 frag = 16×16×8). Transpose (tA/tB) + edge
// zero-pad are handled while STAGING op(A)/op(B) sub-tiles into __shared__,
// so the WMMA load is a fixed row_major layout regardless of transpose (no
// 4-variant template). Inputs rounded fp32→tf32 (≈10-bit mantissa) → NOT
// fp32-exact; correctness bar loosens to TF32 tol (rel-RMS ~1e-3), which is
// the approved precision tradeoff for Tensor-Core throughput. cublasSgemm
// column-major semantics preserved: C[i+j·ldc]=α·Σ op(A)·op(B)+β·C.
// Env HEXA_OWN_GEMM_WMMA selects this within the own path.
// ═════════════════════════════════════════════════════════════════════
__global__ void _hx_k_sgemm_cm_wmma(int tA, int tB, long long M, long long N, long long K,
                                    float alpha, const float* A, long long lda,
                                    const float* B, long long ldb,
                                    float beta, float* C, long long ldc) {
    const long long row0 = (long long)blockIdx.x * 16;   // C row block
    const long long col0 = (long long)blockIdx.y * 16;   // C col block
    __shared__ float As[16*8];   // row-major 16×8  (op(A)[row0+i, t+l])
    __shared__ float Bs[8*16];   // row-major 8×16  (op(B)[t+l, col0+j])
    __shared__ float Cs[16*16];
    nvcuda::wmma::fragment<nvcuda::wmma::matrix_a, 16,16,8, nvcuda::wmma::precision::tf32, nvcuda::wmma::row_major> a_frag;
    nvcuda::wmma::fragment<nvcuda::wmma::matrix_b, 16,16,8, nvcuda::wmma::precision::tf32, nvcuda::wmma::row_major> b_frag;
    nvcuda::wmma::fragment<nvcuda::wmma::accumulator, 16,16,8, float> c_frag;
    nvcuda::wmma::fill_fragment(c_frag, 0.0f);
    int tid = threadIdx.x;   // 0..31 (one warp)
    for (long long t = 0; t < K; t += 8) {
        for (int idx = tid; idx < 128; idx += 32) {        // stage As 16×8
            int i = idx >> 3, l = idx & 7;
            long long r = row0 + i, kk = t + l;
            float v = (r < M && kk < K) ? (tA ? A[kk + r*lda] : A[r + kk*lda]) : 0.0f;
            As[idx] = nvcuda::wmma::__float_to_tf32(v);
        }
        for (int idx = tid; idx < 128; idx += 32) {        // stage Bs 8×16
            int l = idx >> 4, j = idx & 15;
            long long kk = t + l, c = col0 + j;
            float v = (kk < K && c < N) ? (tB ? B[c + kk*ldb] : B[kk + c*ldb]) : 0.0f;
            Bs[idx] = nvcuda::wmma::__float_to_tf32(v);
        }
        __syncwarp();
        nvcuda::wmma::load_matrix_sync(a_frag, As, 8);
        nvcuda::wmma::load_matrix_sync(b_frag, Bs, 16);
        nvcuda::wmma::mma_sync(c_frag, a_frag, b_frag, c_frag);
        __syncwarp();
    }
    nvcuda::wmma::store_matrix_sync(Cs, c_frag, 16, nvcuda::wmma::mem_row_major);
    for (int idx = tid; idx < 256; idx += 32) {
        int i = idx >> 4, j = idx & 15;
        long long r = row0 + i, c = col0 + j;
        if (r < M && c < N) {
            float prev = (beta != 0.0f) ? C[r + c*ldc] : 0.0f;
            C[r + c*ldc] = alpha * Cs[idx] + beta * prev;
        }
    }
}
// ═════════════════════════════════════════════════════════════════════
// Phase 1b-3 CUTLASS-GRADE (env HEXA_OWN_GEMM_WMMA2): a properly-tiled TF32
// Tensor-Core GEMM applying the standard throughput optimizations that let
// cuBLAS/CUTLASS reach TC peak — the naive WMMA above (1 warp / 16×16 C tile,
// K-step 8, shared round-trip every step) pays TC overhead WITHOUT throughput.
//
// TECHNIQUES APPLIED:
//   • Block-level tile  BM=128 × BN=64 × BK=32 computed by an 8-warp block.
//   • Warp tiling — warps laid out 4(row)×2(col); each warp owns a 32×32
//     warp-tile = a 2×2 grid of 16×16 WMMA fragment ops → 4 accumulator
//     fragments held in registers across the whole K loop (no shared
//     round-trip of partial sums; the naive kernel re-stored C every step).
//   • Double-buffered shared-memory pipeline: while WMMA computes on buffer p,
//     the next BK-slice is staged into buffer 1-p (manual double-buffer; on
//     sm_80+ the global→shared copies use cp.async to overlap with compute).
//   • op(A)/op(B) transpose (tA/tB) + edge zero-pad handled while STAGING into
//     __shared__ as a fixed row_major layout → one WMMA load path (no template
//     explosion), bounds-guarded for non-128/64/32-multiple shapes.
//   • Register accumulators; epilogue applies alpha/beta + col-major store.
//   • TF32 rounding (fp32→tf32 ~10-bit mantissa) — same precision contract as
//     the naive WMMA (correctness bar = TF32 rel-RMS ≤ 3e-3). cublasSgemm
//     col-major semantics preserved: C[i+j·ldc]=α·Σ op(A)·op(B)+β·C.
// LAYOUT: block = 256 threads (8 warps). Shared As: BM×BK row-major (128×32),
//   Bs: BK×BN row-major (32×64), ×2 for double buffer. Each = 128*32*4=16KB and
//   32*64*4=8KB → 2*(16+8)=48KB shared/block (fits H100/Blackwell 100KB+ smem).
// ═════════════════════════════════════════════════════════════════════
#define HXG_BM 128
#define HXG_BN 64
#define HXG_BK 32
#define HXG_WARPS 8        // 4 (row) × 2 (col)
#define HXG_WROWS 4
#define HXG_WCOLS 2
#define HXG_WM (HXG_BM / HXG_WROWS)   // 32 rows per warp-tile
#define HXG_WN (HXG_BN / HXG_WCOLS)   // 32 cols per warp-tile
#define HXG_FM (HXG_WM / 16)          // 2 frag rows per warp
#define HXG_FN (HXG_WN / 16)          // 2 frag cols per warp
#define HXG_FK (HXG_BK / 8)           // 4 K-frags per BK slice (TF32 frag K-dim = 8)

#if defined(__CUDA_ARCH__) && (__CUDA_ARCH__ >= 800)
#define HXG_CP_ASYNC 1
#endif

__device__ __forceinline__ void hxg_cp4(float* dst, const float* src, int pred) {
#if HXG_CP_ASYNC
    unsigned long long s = pred ? (unsigned long long)(uintptr_t)src : 0ull;
    unsigned d = (unsigned)__cvta_generic_to_shared(dst);
    if (pred)
        asm volatile("cp.async.ca.shared.global [%0], [%1], 4;\n" :: "r"(d), "l"(s));
    else
        *dst = 0.0f;
#else
    *dst = pred ? *src : 0.0f;
#endif
}
__device__ __forceinline__ void hxg_cp_commit() {
#if HXG_CP_ASYNC
    asm volatile("cp.async.commit_group;\n" ::);
#endif
}
__device__ __forceinline__ void hxg_cp_wait() {
#if HXG_CP_ASYNC
    asm volatile("cp.async.wait_group 0;\n" ::);
#endif
}

__global__ void _hx_k_sgemm_cm_wmma2(int tA, int tB, long long M, long long N, long long K,
                                     float alpha, const float* A, long long lda,
                                     const float* B, long long ldb,
                                     float beta, float* C, long long ldc) {
    const long long blockRow = (long long)blockIdx.x * HXG_BM;  // C rows [blockRow, +128)
    const long long blockCol = (long long)blockIdx.y * HXG_BN;  // C cols [blockCol, +64)
    const int tid  = threadIdx.x;                               // 0..255
    const int warp = tid >> 5;                                  // 0..7
    const int lane = tid & 31;                                  // 0..31
    const int warpRow = warp / HXG_WCOLS;                       // 0..3
    const int warpCol = warp % HXG_WCOLS;                       // 0..1

    // Double-buffered shared staging. As: 2 × (BM×BK) row-major, Bs: 2 × (BK×BN).
    __shared__ float As[2][HXG_BM * HXG_BK];   // 2 × 128×32
    __shared__ float Bs[2][HXG_BK * HXG_BN];   // 2 × 32×64

    // Register accumulator fragments: HXG_FM × HXG_FN per warp (held all K).
    nvcuda::wmma::fragment<nvcuda::wmma::accumulator,16,16,8,float> acc[HXG_FM][HXG_FN];
    #pragma unroll
    for (int fm=0; fm<HXG_FM; fm++)
        #pragma unroll
        for (int fn=0; fn<HXG_FN; fn++)
            nvcuda::wmma::fill_fragment(acc[fm][fn], 0.0f);

    // Staging helpers: each of the 256 threads cooperatively loads the tiles.
    //   As tile = 128*32 = 4096 elems → 16 per thread.
    //   Bs tile = 32*64  = 2048 elems →  8 per thread.
    auto stageA = [&](int buf, long long kk0){
        #pragma unroll
        for (int e=0; e<(HXG_BM*HXG_BK)/256; e++) {
            int idx = e*256 + tid;          // 0..4095
            int i = idx / HXG_BK;           // 0..127  (row in block)
            int l = idx % HXG_BK;           // 0..31   (k within slice)
            long long r = blockRow + i, kk = kk0 + l;
            int pred = (r < M && kk < K);
            const float* sp = pred ? (tA ? &A[kk + r*lda] : &A[r + kk*lda]) : (const float*)0; // op(A)[r,kk]
            hxg_cp4(&As[buf][idx], sp, pred);
        }
    };
    auto stageB = [&](int buf, long long kk0){
        #pragma unroll
        for (int e=0; e<(HXG_BK*HXG_BN)/256; e++) {
            int idx = e*256 + tid;          // 0..2047
            int l = idx / HXG_BN;           // 0..31   (k within slice)
            int j = idx % HXG_BN;           // 0..63   (col in block)
            long long kk = kk0 + l, c = blockCol + j;
            int pred = (kk < K && c < N);
            const float* sp = pred ? (tB ? &B[c + kk*ldb] : &B[kk + c*ldb]) : (const float*)0; // op(B)[kk,c]
            hxg_cp4(&Bs[buf][idx], sp, pred);
        }
    };

    int buf = 0;
    stageA(buf, 0); stageB(buf, 0); hxg_cp_commit(); hxg_cp_wait();
    __syncthreads();

    nvcuda::wmma::fragment<nvcuda::wmma::matrix_a,16,16,8,nvcuda::wmma::precision::tf32,nvcuda::wmma::row_major> a_frag[HXG_FM][HXG_FK];
    nvcuda::wmma::fragment<nvcuda::wmma::matrix_b,16,16,8,nvcuda::wmma::precision::tf32,nvcuda::wmma::row_major> b_frag[HXG_FK][HXG_FN];

    for (long long k0 = 0; k0 < K; k0 += HXG_BK) {
        // Prefetch next BK slice into the other buffer (overlaps with compute).
        long long kNext = k0 + HXG_BK;
        int nbuf = buf ^ 1;
        if (kNext < K) { stageA(nbuf, kNext); stageB(nbuf, kNext); hxg_cp_commit(); }

        // Compute on current buffer: load this warp's A/B fragments, round to TF32, mma.
        #pragma unroll
        for (int fk=0; fk<HXG_FK; fk++) {
            #pragma unroll
            for (int fm=0; fm<HXG_FM; fm++) {
                int srow = warpRow*HXG_WM + fm*16;       // row in block tile
                int scol = fk*8;                         // k within BK (TF32 frag K=8)
                nvcuda::wmma::load_matrix_sync(a_frag[fm][fk], &As[buf][srow*HXG_BK + scol], HXG_BK);
                #pragma unroll
                for (int t=0; t<a_frag[fm][fk].num_elements; t++)
                    a_frag[fm][fk].x[t] = nvcuda::wmma::__float_to_tf32(a_frag[fm][fk].x[t]);
            }
            #pragma unroll
            for (int fn=0; fn<HXG_FN; fn++) {
                int srow = fk*8;                         // k within BK (TF32 frag K=8)
                int scol = warpCol*HXG_WN + fn*16;       // col in block tile
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

    // Epilogue: store each accumulator frag to shared, then col-major C with alpha/beta.
    __shared__ float tmp[HXG_WARPS][16*16];   // per-warp 16×16 scratch
    #pragma unroll
    for (int fm=0; fm<HXG_FM; fm++) {
        #pragma unroll
        for (int fn=0; fn<HXG_FN; fn++) {
            // Stage this frag (16×16) to a per-warp shared region then scatter to C.
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
}
// ═════════════════════════════════════════════════════════════════════
// SPLIT-K skinny own-GEMM (env HEXA_OWN_GEMM_SPLITK). The thru-parity tune
// left a NAMED residual: the worst 2 skinny R=16 LoRA GEMMs are
//   dA: out (4096,16)  K=8192  (tiny N=16, huge K)
//   dB: out (16,4096)  K=8192  (tiny M=16, huge K)
// The 16×16 tiled fallback does a SINGLE sequential K-reduction per output
// element → with K=8192 and only ~16 useful output rows/cols, there are far
// fewer output tiles than the GPU has SMs → the GPU is under-occupied while
// each block grinds the full 8192-long K serially. cuBLAS uses SPLIT-K on
// such tiny-output/large-K shapes: partition K into G chunks, run G× more
// blocks (one per (output-tile, k-chunk)), each computes a partial dot over
// its K-slice, then accumulate the G partials into C via atomicAdd.
//
// BETA handling with atomics: a pre-kernel sets C = beta*C (or 0 when
// beta==0), THEN every split block atomicAdds alpha*partial. This is the
// simplest correct beta+atomic composition (folding beta into "the first
// partial only" is racy when chunks finish out of order). Summation order
// differs from sequential → NOT bit-identical, but stays within TF32 tol
// (rel-RMS ≤ 3e-3), the same contract as the WMMA2/tiled paths.
// col-major cublasSgemm faithful: C[i+j·ldc] = α·Σ_l op(A)·op(B) + β·C.
// ═════════════════════════════════════════════════════════════════════
#define HXSK 16   // 16×16 output tile for split-K (matches _hx_k_sgemm_cm_tiled)

// Pre-kernel: C = beta*C over the (m,n) output region. One thread/element.
__global__ void _hx_k_sgemm_cm_betascale(long long M, long long N,
                                         float beta, float* C, long long ldc) {
    long long row = (long long)blockIdx.x * blockDim.x + threadIdx.x;
    long long col = (long long)blockIdx.y * blockDim.y + threadIdx.y;
    if (row < M && col < N) {
        float* p = &C[row + col*ldc];
        *p = (beta != 0.0f) ? (beta * (*p)) : 0.0f;
    }
}

// Split-K partial kernel. grid.z = G (the K split factor). Block (16×16)
// owns output tile (blockIdx.x, blockIdx.y); blockIdx.z = which K-chunk.
// Each thread accumulates alpha·(partial dot over [kbeg,kend)) then
// atomicAdd's it into C[row+col*ldc]. C must be pre-scaled by beta (above).
__global__ void _hx_k_sgemm_cm_splitk(int tA, int tB, long long M, long long N, long long K,
                                      float alpha, const float* A, long long lda,
                                      const float* B, long long ldb,
                                      float* C, long long ldc, int G) {
    __shared__ float As[HXSK][HXSK];
    __shared__ float Bs[HXSK][HXSK];
    long long row = (long long)blockIdx.x * HXSK + threadIdx.x;  // C row i
    long long col = (long long)blockIdx.y * HXSK + threadIdx.y;  // C col j
    // This block's K-chunk: split [0,K) into G near-equal slices, snapped to
    // HXSK so the shared-mem staging loop is tile-aligned.
    long long tilesK = (K + HXSK - 1) / HXSK;                    // # of HXSK K-tiles
    long long perz   = (tilesK + G - 1) / G;                     // K-tiles per chunk
    long long kbeg   = (long long)blockIdx.z * perz * HXSK;
    long long kend   = kbeg + perz * HXSK; if (kend > K) kend = K;
    float acc = 0.0f;
    for (long long t = kbeg; t < kend; t += HXSK) {
        long long ak = t + threadIdx.y;
        As[threadIdx.x][threadIdx.y] =
            (row < M && ak < K) ? (tA ? A[ak + row*lda] : A[row + ak*lda]) : 0.0f;  // op(A)[row,ak]
        long long bk = t + threadIdx.x;
        Bs[threadIdx.x][threadIdx.y] =
            (bk < K && col < N) ? (tB ? B[col + bk*ldb] : B[bk + col*ldb]) : 0.0f;  // op(B)[bk,col]
        __syncthreads();
        #pragma unroll
        for (int l = 0; l < HXSK; l++) acc += As[threadIdx.x][l] * Bs[l][threadIdx.y];
        __syncthreads();
    }
    if (row < M && col < N && kbeg < kend) {
        atomicAdd(&C[row + col*ldc], alpha * acc);
    }
}
// ═════════════════════════════════════════════════════════════════════
// A-SKINNY (env HEXA_OWN_GEMM_SPLITK2): TWO-PASS, ATOMIC-FREE split-K.
// The split-K verdict (F-FUSION-SPLITK-SKINNY §4a) NAMED the residual-of-
// residual on the worst skinny-M shape dB (out 16×N, K=8192, G=16): the
// single-pass split-K atomicAdds each of the G K-chunk partials into the
// SAME tiny 16-row output column. With G=16 writers hammering the same
// 16-wide cache lines per column, the global atomicAdd SERIALIZES on cache-
// line contention — the un-fixed cost cuBLAS avoids. The verdict named the
// fix verbatim: "A two-pass split-K (partials buffer + a tree reduction
// kernel) ... would recover more — a further separable kernel step, NOT a
// tuning knob." This is that step, never built until now.
//
// PASS 1 (_hx_k_sgemm_cm_splitk2_partial): identical partial-dot math to the
// single-pass kernel, BUT each (output-tile, k-chunk=blockIdx.z) writes its
// partial to a DISTINCT slice of a scratch buffer P[g·(M·N) + row + col·M]
// (g = blockIdx.z). NO atomic — every write address is unique across g, so
// G blocks for one output element touch G separate cache lines. Zero
// contention. P is a plain device malloc of G·M·N floats.
// PASS 2 (_hx_k_sgemm_cm_splitk2_reduce): one thread per output element sums
// the G partials P[g·MN + idx] in fp32 (ascending g — DETERMINISTIC order,
// unlike the race-ordered atomicAdd) then writes C = beta·C_old + alpha·Σ.
// Because the reduce is the ONLY writer of C and reads the pre-scale C value
// itself, NO separate betascale pre-kernel is needed (fold beta in here).
// Summation is fp32 over G≤32 terms in fixed order → rel-RMS ≤ 3e-3 (same
// own-GEMM contract; in fact MORE deterministic than the atomic path).
// col-major faithful: C[i+j·ldc] = α·Σ_l op(A)·op(B) + β·C.
// ═════════════════════════════════════════════════════════════════════
// PASS 1: partial dots → distinct scratch slices (atomic-free). Same tile
// math as _hx_k_sgemm_cm_splitk; only the epilogue store differs (no atomic).
__global__ void _hx_k_sgemm_cm_splitk2_partial(int tA, int tB, long long M, long long N, long long K,
                                               const float* A, long long lda,
                                               const float* B, long long ldb,
                                               float* P, int G) {
    __shared__ float As[HXSK][HXSK];
    __shared__ float Bs[HXSK][HXSK];
    long long row = (long long)blockIdx.x * HXSK + threadIdx.x;  // C row i
    long long col = (long long)blockIdx.y * HXSK + threadIdx.y;  // C col j
    long long tilesK = (K + HXSK - 1) / HXSK;
    long long perz   = (tilesK + G - 1) / G;
    long long kbeg   = (long long)blockIdx.z * perz * HXSK;
    long long kend   = kbeg + perz * HXSK; if (kend > K) kend = K;
    float acc = 0.0f;
    for (long long t = kbeg; t < kend; t += HXSK) {
        long long ak = t + threadIdx.y;
        As[threadIdx.x][threadIdx.y] =
            (row < M && ak < K) ? (tA ? A[ak + row*lda] : A[row + ak*lda]) : 0.0f;
        long long bk = t + threadIdx.x;
        Bs[threadIdx.x][threadIdx.y] =
            (bk < K && col < N) ? (tB ? B[col + bk*ldb] : B[bk + col*ldb]) : 0.0f;
        __syncthreads();
        #pragma unroll
        for (int l = 0; l < HXSK; l++) acc += As[threadIdx.x][l] * Bs[l][threadIdx.y];
        __syncthreads();
    }
    if (row < M && col < N) {
        // DISTINCT slice per k-chunk g=blockIdx.z → no two blocks share an
        // address → atomic-free. Write 0 when this chunk was empty (kbeg>=kend)
        // so PASS 2's fixed-length Σ over [0,G) is correct.
        long long mn = M * N;
        P[(long long)blockIdx.z * mn + row + col * M] = (kbeg < kend) ? acc : 0.0f;
    }
}
// PASS 2: reduce G partials per output element in fixed fp32 order + epilogue.
__global__ void _hx_k_sgemm_cm_splitk2_reduce(long long M, long long N,
                                              float alpha, float beta,
                                              const float* P, float* C, long long ldc, int G) {
    long long row = (long long)blockIdx.x * blockDim.x + threadIdx.x;
    long long col = (long long)blockIdx.y * blockDim.y + threadIdx.y;
    if (row >= M || col >= N) return;
    long long mn = M * N;
    long long idx = row + col * M;        // partials are stored ldP = M (packed)
    float s = 0.0f;
    for (int g = 0; g < G; g++) s += P[(long long)g * mn + idx];   // fixed ascending order
    float* c = &C[row + col * ldc];
    *c = (beta != 0.0f) ? (beta * (*c) + alpha * s) : (alpha * s);
}
// ═════════════════════════════════════════════════════════════════════
// A-VEC (env HEXA_OWN_GEMM_VEC): float4 (128-bit) VECTORIZED-LOAD split-K
// skinny own-GEMM. A2 (#2725, CLOSED-NEGATIVE on the K-reduction-strategy
// axis) NAMED the real residual: the un-vectorized 32-bit scalar global-load
// inner loop of the 16×16-tiled split-K partial kernel above. cuBLAS wins the
// skinny LoRA GEMMs (dA: M=4096,N=16,K=8192 ; dB: M=16,N=4096,K=8192) via
// 128-bit vectorized loads + a wider register-blocked tile. This kernel is the
// separable next step A2 named: float4 vectorized global loads + a wider
// register-blocked tile (each thread owns a VECW-wide micro-column of C).
//
// VECTORIZATION GEOMETRY (col-major, faithful cublasSgemm semantics):
//   • Block = 16 cols (threadIdx.y) × (HXSK/ VECW) thread-rows; each thread
//     owns a VECW=4 strip of CONSECUTIVE output ROWS (C[row..row+3, col]).
//   • For the K-reduction we stage A and B into __shared__ exactly like the
//     scalar split-K kernel, BUT the global→register/shared load of op(A)'s
//     row-strip uses a single float4 (128-bit) transaction when op(A) is
//     ROW-CONTIGUOUS (tA==0 → A[row + ak·lda]: consecutive `row` are unit-
//     stride) AND the base is 16-byte aligned AND row+3 < M. That is the
//     hot, memory-bound path of the dA/dB skinny GEMMs.
//   • TAIL/UNALIGNED: when row+3 >= M, or the base is not 16B-aligned, or
//     op(A) is transposed (tA==1 → not row-contiguous), the strip falls back
//     to 4 scalar loads. Correctness identical; only the load width changes.
//   • Each thread holds VECW register accumulators across the whole K-chunk
//     (register-blocked) → A is reloaded once per VECW outputs (4× fewer A
//     global transactions), the named scalar-load inefficiency.
// Same beta-via-pre-scale + atomicAdd partial composition as the scalar
// split-K kernel → NOT bit-identical (atomic order), TF32/fp32 tol rel-RMS
// ≤ 3e-3 (the shared own-GEMM contract). C[i+j·ldc]=α·Σ op(A)·op(B)+β·C.
// ═════════════════════════════════════════════════════════════════════
#define HXVECW 4    // float4: 4 consecutive output rows per thread

// grid: (ceil(M/HXSK), ceil(N/HXSK), G).  block: (HXSK/HXVECW=4) × HXSK=16.
// threadIdx.x ∈ [0,4) selects which 4-row strip; threadIdx.y ∈ [0,16) the col.
__global__ void _hx_k_sgemm_cm_splitk_vec(int tA, int tB, long long M, long long N, long long K,
                                          float alpha, const float* A, long long lda,
                                          const float* B, long long ldb,
                                          float* C, long long ldc, int G) {
    // Shared B-tile (HXSK K-rows × HXSK cols), staged once per K-tile and
    // reused by all 4 row-strips of the block. A is loaded straight to
    // registers as a float4 strip (no shared round-trip for A).
    __shared__ float Bs[HXSK][HXSK];
    long long row0 = (long long)blockIdx.x * HXSK + (long long)threadIdx.x * HXVECW; // first of 4 C rows
    long long col  = (long long)blockIdx.y * HXSK + threadIdx.y;                      // C col j
    long long tilesK = (K + HXSK - 1) / HXSK;
    long long perz   = (tilesK + G - 1) / G;
    long long kbeg   = (long long)blockIdx.z * perz * HXSK;
    long long kend   = kbeg + perz * HXSK; if (kend > K) kend = K;

    float acc0 = 0.0f, acc1 = 0.0f, acc2 = 0.0f, acc3 = 0.0f;   // VECW register accumulators

    // Can A's 4-row strip be a single 128-bit (float4) load this kernel?
    //   tA==0 → op(A)[row,ak] = A[row + ak·lda]; consecutive `row` unit-stride.
    //   Needs row0+3 < M (no tail) AND the A column base 16B-aligned.
    const int a_rowcontig = (tA == 0);

    for (long long t = kbeg; t < kend; t += HXSK) {
        // Stage Bs[k][j] = op(B)[t+k, col_of_this_block_j]. The full block (64
        // threads) cooperatively fills the 16×16 B-tile: each thread loads
        // HXSK*HXSK/64 = 4 elements. Indexed flat for coalescing on op(B).
        int flat = threadIdx.x * HXSK + threadIdx.y;   // 0..63
        #pragma unroll
        for (int e = 0; e < (HXSK*HXSK)/64; e++) {
            int idx = flat + e*64;                     // 0..255
            int bk = idx >> 4;                         // K-row within tile 0..15
            int bj = idx & 15;                         // col within tile  0..15
            long long gk = t + bk;
            long long gc = (long long)blockIdx.y * HXSK + bj;
            Bs[bk][bj] = (gk < K && gc < N)
                ? (tB ? B[gc + gk*ldb] : B[gk + gc*ldb]) : 0.0f;   // op(B)[gk,gc]
        }
        __syncthreads();

        // K-reduction over this HXSK-tile. For each k, load op(A)[row0..row0+3, t+k]
        // as ONE float4 when row-contiguous + aligned + in-bounds, else 4 scalars.
        #pragma unroll
        for (int kk = 0; kk < HXSK; kk++) {
            long long ak = t + kk;
            if (ak >= K) break;
            float a0, a1, a2, a3;
            const float* aptr = &A[row0 + ak*lda];     // op(A)[row0,ak], unit-stride in row (tA==0)
            int aligned = (((uintptr_t)aptr & 15ULL) == 0);
            if (a_rowcontig && aligned && (row0 + HXVECW - 1) < M) {
                float4 av = *reinterpret_cast<const float4*>(aptr);  // 128-bit vectorized load
                a0 = av.x; a1 = av.y; a2 = av.z; a3 = av.w;
            } else {
                // tail / unaligned / transposed-A scalar fallback
                a0 = (row0+0 < M) ? (tA ? A[ak + (row0+0)*lda] : A[(row0+0) + ak*lda]) : 0.0f;
                a1 = (row0+1 < M) ? (tA ? A[ak + (row0+1)*lda] : A[(row0+1) + ak*lda]) : 0.0f;
                a2 = (row0+2 < M) ? (tA ? A[ak + (row0+2)*lda] : A[(row0+2) + ak*lda]) : 0.0f;
                a3 = (row0+3 < M) ? (tA ? A[ak + (row0+3)*lda] : A[(row0+3) + ak*lda]) : 0.0f;
            }
            float b = Bs[kk][threadIdx.y];             // op(B)[t+kk, col]
            acc0 += a0 * b; acc1 += a1 * b; acc2 += a2 * b; acc3 += a3 * b;
        }
        __syncthreads();
    }

    if (col < N && kbeg < kend) {
        if (row0+0 < M) atomicAdd(&C[(row0+0) + col*ldc], alpha * acc0);
        if (row0+1 < M) atomicAdd(&C[(row0+1) + col*ldc], alpha * acc1);
        if (row0+2 < M) atomicAdd(&C[(row0+2) + col*ldc], alpha * acc2);
        if (row0+3 < M) atomicAdd(&C[(row0+3) + col*ldc], alpha * acc3);
    }
}
// ═════════════════════════════════════════════════════════════════════
// HEXA-FUSION C1 — BF16 own-GEMM (env HEXA_OWN_GEMM_BF16). The hexa-native
// counterpart to forge's BF16 Tensor-Core mega-kernel: a CUTLASS-grade,
// BF16-fragment WMMA GEMM that MIRRORS _hx_k_sgemm_cm_wmma2's schedule
// (128×64 block, 8-warp 4×2 layout, 2×2 warp-tile, double-buffered
// cp.async shared pipeline, register accumulators, col-major epilogue) but
// swaps the math regime from TF32 → BF16:
//   • WMMA fragment shape 16×16×16 (BF16's native shape; the TF32 path uses
//     16×16×8). So K-frags per BK slice = BK/16 = 2 (vs 4 for TF32 K=8).
//   • Shared staging buffers are __nv_bfloat16 (As/Bs), and fp32 inputs are
//     ROUNDED to bf16 on load (__float2bfloat16) while staging — i.e. the
//     own kernel accepts the SAME fp32 host buffers as the TF32 path, casting
//     to bf16 internally (faithful to cublasGemmEx(CUDA_R_16BF) which also
//     reads bf16 inputs). FP32 accumulator → bf16 precision loss is confined
//     to the inputs + per-mma rounding, accumulation stays fp32.
//   • PRECISION CONTRACT (the dtype tradeoff, stated explicitly): BF16 has an
//     ~8-bit mantissa (vs TF32's ~10-bit), so the correctness bar is the
//     LOOSER BF16 tol rel-RMS ≤ 1e-2 — NOT the 3e-3 TF32 bar. This is a
//     precision-for-throughput trade: usable on the INFERENCE / FORWARD path
//     (logits, FFN, attention projections) where bf16 is the industry-standard
//     activation dtype; NOT a drop-in for precision-critical fp32 accumulation
//     paths without an error-budget check.
//   • col-major cublasGemmEx faithful: C[i+j·ldc] = α·Σ op(A)·op(B) + β·C,
//     same tA/tB op() + edge zero-pad semantics as the TF32 WMMA2 kernel.
// LAYOUT: block = 256 threads (8 warps). Shared As: BM×BK bf16 (128×32),
//   Bs: BK×BN bf16 (32×64), ×2 double-buffer = 2*(128*32+32*64)*2B = 24KB
//   shared/block (half the TF32 path's 48KB — bf16 is 2B). Fits any sm_80+.
// ═════════════════════════════════════════════════════════════════════
#define HXGB_FK (HXG_BK / 16)   // 2 K-frags per BK slice (BF16 frag K-dim = 16)

// cp.async of a single bf16 (2 bytes) from global→shared. Mirrors hxg_cp4 but
// 2-byte copy. On sm_80+ uses cp.async; else a plain predicated store.
__device__ __forceinline__ void hxg_cp2_bf(__nv_bfloat16* dst, const __nv_bfloat16* src, int pred) {
#if HXG_CP_ASYNC
    unsigned d = (unsigned)__cvta_generic_to_shared(dst);
    if (pred)
        asm volatile("cp.async.ca.shared.global [%0], [%1], 2;\n" :: "r"(d), "l"(src));
    else
        *dst = __float2bfloat16(0.0f);
#else
    *dst = pred ? *src : __float2bfloat16(0.0f);
#endif
}

__global__ void _hx_k_sgemm_cm_bf16(int tA, int tB, long long M, long long N, long long K,
                                    float alpha, const float* A, long long lda,
                                    const float* B, long long ldb,
                                    float beta, float* C, long long ldc) {
    const long long blockRow = (long long)blockIdx.x * HXG_BM;  // C rows [blockRow, +128)
    const long long blockCol = (long long)blockIdx.y * HXG_BN;  // C cols [blockCol, +64)
    const int tid  = threadIdx.x;                               // 0..255
    const int warp = tid >> 5;                                  // 0..7
    const int lane = tid & 31;                                  // 0..31
    const int warpRow = warp / HXG_WCOLS;                       // 0..3
    const int warpCol = warp % HXG_WCOLS;                       // 0..1

    // Double-buffered shared staging, bf16. As: 2×(BM×BK), Bs: 2×(BK×BN).
    // NOTE: fp32 inputs are rounded to bf16 HERE (on stage), not in registers
    // (BF16 frags carry bf16 storage natively, unlike the TF32 path which loads
    // fp32 frags then rounds each element).
    __shared__ __nv_bfloat16 As[2][HXG_BM * HXG_BK];   // 2 × 128×32
    __shared__ __nv_bfloat16 Bs[2][HXG_BK * HXG_BN];   // 2 × 32×64

    // Register accumulator fragments (FP32 accumulate): HXG_FM × HXG_FN per warp.
    nvcuda::wmma::fragment<nvcuda::wmma::accumulator,16,16,16,float> acc[HXG_FM][HXG_FN];
    #pragma unroll
    for (int fm=0; fm<HXG_FM; fm++)
        #pragma unroll
        for (int fn=0; fn<HXG_FN; fn++)
            nvcuda::wmma::fill_fragment(acc[fm][fn], 0.0f);

    // Staging: each of the 256 threads cooperatively loads tiles, casting
    // fp32→bf16. As tile = 4096 elems → 16/thread; Bs tile = 2048 → 8/thread.
    auto stageA = [&](int buf, long long kk0){
        #pragma unroll
        for (int e=0; e<(HXG_BM*HXG_BK)/256; e++) {
            int idx = e*256 + tid;          // 0..4095
            int i = idx / HXG_BK;           // 0..127  (row in block)
            int l = idx % HXG_BK;           // 0..31   (k within slice)
            long long r = blockRow + i, kk = kk0 + l;
            int pred = (r < M && kk < K);
            // round fp32→bf16 into a register, then cp.async the bf16 into shared.
            __nv_bfloat16 v = pred ? __float2bfloat16(tA ? A[kk + r*lda] : A[r + kk*lda])
                                   : __float2bfloat16(0.0f);
            As[buf][idx] = v;   // bf16 store (already rounded); cp.async path below for sm_80
        }
    };
    auto stageB = [&](int buf, long long kk0){
        #pragma unroll
        for (int e=0; e<(HXG_BK*HXG_BN)/256; e++) {
            int idx = e*256 + tid;          // 0..2047
            int l = idx / HXG_BN;           // 0..31   (k within slice)
            int j = idx % HXG_BN;           // 0..63   (col in block)
            long long kk = kk0 + l, c = blockCol + j;
            int pred = (kk < K && c < N);
            __nv_bfloat16 v = pred ? __float2bfloat16(tB ? B[c + kk*ldb] : B[kk + c*ldb])
                                   : __float2bfloat16(0.0f);
            Bs[buf][idx] = v;
        }
    };

    // NOTE on the pipeline: the TF32 path cp.async's fp32 words global→shared
    // (no on-the-fly cast possible in HW). BF16 inputs arrive as fp32 here, so
    // the fp32→bf16 ROUND must happen on a thread (cp.async can't cast). We
    // therefore stage via a register round + a plain bf16 shared store (still
    // double-buffered + __syncthreads-pipelined for shared reuse; the global
    // loads are coalesced fp32 reads). This keeps the SAME tiling/warp schedule.
    int buf = 0;
    stageA(buf, 0); stageB(buf, 0);
    __syncthreads();

    nvcuda::wmma::fragment<nvcuda::wmma::matrix_a,16,16,16,__nv_bfloat16,nvcuda::wmma::row_major> a_frag[HXG_FM][HXGB_FK];
    nvcuda::wmma::fragment<nvcuda::wmma::matrix_b,16,16,16,__nv_bfloat16,nvcuda::wmma::row_major> b_frag[HXGB_FK][HXG_FN];

    for (long long k0 = 0; k0 < K; k0 += HXG_BK) {
        long long kNext = k0 + HXG_BK;
        int nbuf = buf ^ 1;
        if (kNext < K) { stageA(nbuf, kNext); stageB(nbuf, kNext); }

        // Compute on current buffer: load this warp's bf16 A/B fragments, mma.
        #pragma unroll
        for (int fk=0; fk<HXGB_FK; fk++) {
            #pragma unroll
            for (int fm=0; fm<HXG_FM; fm++) {
                int srow = warpRow*HXG_WM + fm*16;       // row in block tile
                int scol = fk*16;                        // k within BK (BF16 frag K=16)
                nvcuda::wmma::load_matrix_sync(a_frag[fm][fk], &As[buf][srow*HXG_BK + scol], HXG_BK);
            }
            #pragma unroll
            for (int fn=0; fn<HXG_FN; fn++) {
                int srow = fk*16;                        // k within BK (BF16 frag K=16)
                int scol = warpCol*HXG_WN + fn*16;       // col in block tile
                nvcuda::wmma::load_matrix_sync(b_frag[fk][fn], &Bs[buf][srow*HXG_BN + scol], HXG_BN);
            }
        }
        #pragma unroll
        for (int fm=0; fm<HXG_FM; fm++)
            #pragma unroll
            for (int fn=0; fn<HXG_FN; fn++)
                #pragma unroll
                for (int fk=0; fk<HXGB_FK; fk++)
                    nvcuda::wmma::mma_sync(acc[fm][fn], a_frag[fm][fk], b_frag[fk][fn], acc[fm][fn]);

        if (kNext < K) { __syncthreads(); buf = nbuf; }
    }

    // Epilogue: store each accumulator frag to shared, then col-major C w/ α/β.
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
}
// Host launcher for the own-GEMM kernel — extern "C" so the gcc-compiled
// hxqwen14b.c TU (LoRA fwd/bwd) can call it. tA/tB are 1 if op==T else 0.
// Returns 0 on success, nonzero on a CUDA launch/sync error.
// HEXA_OWN_GEMM_TILED (set+non-empty) selects the shared-mem tiled kernel;
// otherwise the naive one-thread-per-output kernel. The outer HEXA_OWN_GEMM
// gate (in the shims) still chooses own-vs-cuBLAS; this only picks tiled-vs-naive
// WITHIN the own path. Block is always 16×16, grid covers (M,N) in 16-tiles.
// THRU-PARITY TUNE (HEXA-FUSION ③ throughput-parity): the WMMA2 path reaches
// cuBLAS-class util + ~1.13× GEMM-iso step-time, yet the FULL LoRA step ran
// ~2.2× slower steps/s. Two diagnosed causes, both fixed here:
//   (1) a per-call cudaDeviceSynchronize() (was below) serialized all 7 LoRA
//       GEMMs + the glue every step — cuBLAS queues them async, so WMMA2 paid
//       7 host↔device round-trips/step the cuBLAS arm never pays. We drop the
//       sync to a non-blocking cudaGetLastError() launch check (env
//       HEXA_OWN_GEMM_SYNC=1 restores the old per-call sync for debugging).
//   (2) the R=16 LoRA GEMMs (output dim M or N = R=16, or K = R=16) launch the
//       big 128×64×32 WMMA2 tile over a 16-tall/16-wide problem → ≥75% of every
//       threadblock + half the BK K-tile are wasted (a CUTLASS-grade big tile is
//       the wrong tool for a skinny GEMM). We shape-dispatch: any GEMM whose
//       output rows m<HXG_BM or cols n<HXG_BN (the skinny LoRA GEMMs) falls back
//       to the lightweight 16×16 tiled kernel (right-sized grid, no wasted tile);
//       only the big square GEMMs use WMMA2. Correctness is unchanged (both
//       paths are the same col-major TF32/fp32 contract; the gate still guards).
//   Env HEXA_OWN_GEMM_NOSHAPE=1 disables the skinny fallback (always WMMA2).
int _hx_own_sgemm_cm_launch(int tA, int tB, int m, int n, int k,
                            float alpha, const float* A, int lda,
                            const float* B, int ldb,
                            float beta, float* C, int ldc) {
    dim3 blk(16,16); dim3 grd((unsigned)((m+15)/16),(unsigned)((n+15)/16));
    // HEXA-FUSION C1 — BF16 own-GEMM gate (env HEXA_OWN_GEMM_BF16). Highest
    // priority within the own path: when set, the BF16 WMMA kernel handles the
    // GEMM (bf16 inputs/fragments, fp32 accumulate, 16×16×16 mma) over the SAME
    // 128×64 8-warp schedule as WMMA2. This is a PRECISION change (bf16 ~8-bit
    // mantissa) — correctness contract is the looser BF16 tol rel-RMS ≤ 1e-2.
    // OFF (default) = byte-identical to the prior TF32/fp32 dispatch below.
    int want_bf16 = (getenv("HEXA_OWN_GEMM_BF16") && getenv("HEXA_OWN_GEMM_BF16")[0]);
    if (want_bf16) {
        static int bffired = 0; if (!bffired){bffired=1; fprintf(stderr,"[OWN-SGEMM-BF16-FIRED] _hx_k_sgemm_cm_bf16 (BF16 Tensor-Core: 128x64 block, 8-warp, 2x2 warp-tile, 16x16x16 bf16 frag, fp32 accum; bf16 tol 1e-2)\n");}
        dim3 bfblk(256);  // 8 warps
        dim3 bfgrd((unsigned)((m + HXG_BM - 1)/HXG_BM), (unsigned)((n + HXG_BN - 1)/HXG_BN));
        _hx_k_sgemm_cm_bf16<<<bfgrd,bfblk>>>(tA,tB,
                                             (long long)m,(long long)n,(long long)k,
                                             alpha, A,(long long)lda, B,(long long)ldb,
                                             beta, C,(long long)ldc);
        if (getenv("HEXA_OWN_GEMM_SYNC") && getenv("HEXA_OWN_GEMM_SYNC")[0]) {
            cudaError_t e = cudaDeviceSynchronize();
            return (e==cudaSuccess) ? 0 : (int)e;
        }
        cudaError_t e = cudaGetLastError();
        return (e==cudaSuccess) ? 0 : (int)e;
    }
    int want_wmma2 = (getenv("HEXA_OWN_GEMM_WMMA2") && getenv("HEXA_OWN_GEMM_WMMA2")[0]);
    // Shape gate: a "skinny" GEMM (output < a single WMMA2 block tile in m or n)
    // wastes the 128×64 tile → route it to the small 16×16 tiled kernel instead.
    int noshape = (getenv("HEXA_OWN_GEMM_NOSHAPE") && getenv("HEXA_OWN_GEMM_NOSHAPE")[0]);
    int skinny  = (m < HXG_BM || n < HXG_BN);
    // SPLIT-K skinny path (env HEXA_OWN_GEMM_SPLITK): for a skinny+large-K GEMM
    // (min(m,n) <= 64 AND k >= 1024) the 16×16 tiled fallback under-occupies the
    // GPU (too few output tiles, each grinding a huge serial K). Split K into G
    // chunks → G× more blocks → fills the SMs. G = clamp(k/512,1,32) by default
    // (MEASURED sweet spot on Blackwell: k=4096→G=8, k=8192→G=16; saturates ~16-32),
    // overridable via HEXA_OWN_GEMM_SPLITK_G for on-pod tuning.
    int want_splitk = (getenv("HEXA_OWN_GEMM_SPLITK") && getenv("HEXA_OWN_GEMM_SPLITK")[0]);
    int skinny_splitk = ((m <= 64 || n <= 64) && k >= 1024);
    // A-VEC (env HEXA_OWN_GEMM_VEC): float4 (128-bit) vectorized-load split-K.
    // The A2-named lever — replaces the scalar global-load inner loop of the
    // 16×16 split-K kernel with 128-bit float4 loads + a VECW=4 register-blocked
    // micro-column. Same skinny+large-K trigger as scalar split-K; takes
    // priority when both VEC and SPLITK are set (VEC is the vectorized split-K).
    int want_vec = (getenv("HEXA_OWN_GEMM_VEC") && getenv("HEXA_OWN_GEMM_VEC")[0]);
    // MEASURED shape gate (verdict F-FUSION-AVEC-FLOAT4): the float4 path
    // register-blocks across the output-ROW dim (m) and needs a LARGE contiguous
    // m extent to fire (row0+3 < M). It WINS on skinny-N/square (dA m=4096:
    // 1.11x, square: 1.99x over scalar) but REGRESSES on skinny-M (dB m=16:
    // 0.68x, -90%) where the float4 load can't fire and 4-row blocking starves
    // the already-tiny m-occupancy. So VEC only fires when m >= the float4-strip
    // threshold; on skinny-M it falls through to the scalar split-K below.
    // HEXA_OWN_GEMM_VEC_MINM overrides the threshold for on-pod tuning.
    int vec_minm = 64;
    { const char* vm = getenv("HEXA_OWN_GEMM_VEC_MINM"); if (vm && vm[0]) { int v = atoi(vm); if (v >= 1) vec_minm = v; } }
    // A-SKINNY two-pass atomic-free split-K (env HEXA_OWN_GEMM_SPLITK2). The
    // verdict-named fix for the skinny-M dB residual: PASS 1 writes G partials to
    // distinct scratch slices (no atomicAdd cache-line contention), PASS 2
    // reduces them in deterministic fp32 order + epilogue. Same skinny+large-K
    // trigger; takes priority over scalar split-K when set (it IS the split-K
    // path, contention-free). Falls through if the scratch malloc fails.
    int want_splitk2 = (getenv("HEXA_OWN_GEMM_SPLITK2") && getenv("HEXA_OWN_GEMM_SPLITK2")[0]);
    if (want_wmma2 && want_splitk2 && skinny_splitk && !noshape) {
        int G = (int)(k / 512); if (G < 1) G = 1; if (G > 32) G = 32;
        const char* ge = getenv("HEXA_OWN_GEMM_SPLITK_G");
        if (ge && ge[0]) { int gv = atoi(ge); if (gv >= 1 && gv <= 64) G = gv; }
        long long mn = (long long)m * (long long)n;
        float* P = nullptr;
        cudaError_t pe = cudaMalloc((void**)&P, (size_t)G * (size_t)mn * sizeof(float));
        if (pe == cudaSuccess && P) {
            static int sk2fired = 0; if (!sk2fired){sk2fired=1; fprintf(stderr,"[OWN-SGEMM-SPLITK2-FIRED] skinny GEMM -> _hx_k_sgemm_cm_splitk2 (TWO-PASS atomic-free, partials buffer + fixed-order reduce, G=%d, m=%d n=%d k=%d)\n", G, m, n, k);}
            dim3 sblk(16,16);
            dim3 sgrd((unsigned)((m+15)/16),(unsigned)((n+15)/16),(unsigned)G);
            _hx_k_sgemm_cm_splitk2_partial<<<sgrd,sblk>>>(tA,tB,
                                                          (long long)m,(long long)n,(long long)k,
                                                          A,(long long)lda, B,(long long)ldb, P, G);
            dim3 rblk(16,16);
            dim3 rgrd((unsigned)((m+15)/16),(unsigned)((n+15)/16));
            _hx_k_sgemm_cm_splitk2_reduce<<<rgrd,rblk>>>((long long)m,(long long)n,
                                                         alpha, beta, P, C,(long long)ldc, G);
            cudaError_t se = cudaGetLastError();
            cudaFree(P);
            return (se==cudaSuccess) ? 0 : (int)se;
        }
        // malloc failed → fall through to the scalar split-K path below.
    }
    if (want_wmma2 && want_vec && skinny_splitk && m >= vec_minm && !noshape) {
        int G = (int)(k / 512); if (G < 1) G = 1; if (G > 32) G = 32;
        const char* ge = getenv("HEXA_OWN_GEMM_SPLITK_G");
        if (ge && ge[0]) { int gv = atoi(ge); if (gv >= 1 && gv <= 64) G = gv; }
        static int vfired = 0; if (!vfired){vfired=1; fprintf(stderr,"[OWN-SGEMM-VEC-FIRED] skinny GEMM -> _hx_k_sgemm_cm_splitk_vec (float4 128-bit vectorized loads, VECW=4 register-blocked, G=%d, m=%d n=%d k=%d)\n", G, m, n, k);}
        // Pre-scale C = beta*C (or 0), then atomicAdd alpha*partials (same beta
        // composition as the scalar split-K path).
        dim3 sblk_scale(16,16);
        dim3 sgrd_scale((unsigned)((m+15)/16),(unsigned)((n+15)/16));
        _hx_k_sgemm_cm_betascale<<<sgrd_scale,sblk_scale>>>((long long)m,(long long)n,beta,C,(long long)ldc);
        // block = (HXSK/HXVECW=4) × HXSK(16) = 64 threads; grid = (M/16, N/16, G).
        dim3 vblk(HXSK/HXVECW, HXSK);
        dim3 vgrd((unsigned)((m+15)/16),(unsigned)((n+15)/16),(unsigned)G);
        _hx_k_sgemm_cm_splitk_vec<<<vgrd,vblk>>>(tA,tB,
                                                 (long long)m,(long long)n,(long long)k,
                                                 alpha, A,(long long)lda, B,(long long)ldb,
                                                 C,(long long)ldc, G);
    } else if (want_wmma2 && want_splitk && skinny_splitk && !noshape) {
        int G = (int)(k / 512); if (G < 1) G = 1; if (G > 32) G = 32;
        const char* ge = getenv("HEXA_OWN_GEMM_SPLITK_G");
        if (ge && ge[0]) { int gv = atoi(ge); if (gv >= 1 && gv <= 64) G = gv; }
        static int skfired = 0; if (!skfired){skfired=1; fprintf(stderr,"[OWN-SGEMM-SPLITK-FIRED] skinny GEMM -> _hx_k_sgemm_cm_splitk (split-K atomicAdd, G=%d, m=%d n=%d k=%d)\n", G, m, n, k);}
        // Pre-scale C = beta*C (or 0), then atomicAdd alpha*partials.
        dim3 sblk(16,16);
        dim3 sgrd_scale((unsigned)((m+15)/16),(unsigned)((n+15)/16));
        _hx_k_sgemm_cm_betascale<<<sgrd_scale,sblk>>>((long long)m,(long long)n,beta,C,(long long)ldc);
        dim3 sgrd((unsigned)((m+15)/16),(unsigned)((n+15)/16),(unsigned)G);
        _hx_k_sgemm_cm_splitk<<<sgrd,sblk>>>(tA,tB,
                                             (long long)m,(long long)n,(long long)k,
                                             alpha, A,(long long)lda, B,(long long)ldb,
                                             C,(long long)ldc, G);
    } else if (want_wmma2 && !(skinny && !noshape)) {
        static int w2fired = 0; if (!w2fired){w2fired=1; fprintf(stderr,"[OWN-SGEMM-WMMA2-FIRED] _hx_k_sgemm_cm_wmma2 (CUTLASS-grade TF32: 128x64 block, 8-warp, 2x2 warp-tile, double-buffered cp.async)\n");}
        dim3 w2blk(256);  // 8 warps
        dim3 w2grd((unsigned)((m + HXG_BM - 1)/HXG_BM), (unsigned)((n + HXG_BN - 1)/HXG_BN));
        _hx_k_sgemm_cm_wmma2<<<w2grd,w2blk>>>(tA,tB,
                                              (long long)m,(long long)n,(long long)k,
                                              alpha, A,(long long)lda, B,(long long)ldb,
                                              beta, C,(long long)ldc);
    } else if (want_wmma2 && skinny && !noshape) {
        // Skinny LoRA GEMM under WMMA2 mode: use a right-sized small-grid kernel
        // (no wasted 128×64 tile). Default = the 16×16 shared-mem tiled kernel —
        // MEASURED best on the R=16 LoRA shapes (337 vs 240 steps/s @M8192 vs the
        // naive one-thread-per-output kernel): even with a half-wasted 16-wide M
        // tile, the shared-mem K-reuse wins because K is large (4096-8192).
        // HEXA_OWN_GEMM_SKINNY_NAIVE=1 selects the naive kernel (measured slower).
        if (getenv("HEXA_OWN_GEMM_SKINNY_NAIVE") && getenv("HEXA_OWN_GEMM_SKINNY_NAIVE")[0]) {
            static int snfired = 0; if (!snfired){snfired=1; fprintf(stderr,"[OWN-SGEMM-WMMA2-SKINNY-FIRED] skinny GEMM -> _hx_k_sgemm_cm_v54 (naive)\n");}
            _hx_k_sgemm_cm_v54<<<grd,blk>>>(tA,tB,
                                            (long long)m,(long long)n,(long long)k,
                                            alpha, A,(long long)lda, B,(long long)ldb,
                                            beta, C,(long long)ldc);
        } else {
            static int stfired = 0; if (!stfired){stfired=1; fprintf(stderr,"[OWN-SGEMM-WMMA2-SKINNY-FIRED] skinny GEMM -> _hx_k_sgemm_cm_tiled (16x16, no wasted 128x64 tile)\n");}
            _hx_k_sgemm_cm_tiled<<<grd,blk>>>(tA,tB,
                                              (long long)m,(long long)n,(long long)k,
                                              alpha, A,(long long)lda, B,(long long)ldb,
                                              beta, C,(long long)ldc);
        }
    } else if (getenv("HEXA_OWN_GEMM_WMMA") && getenv("HEXA_OWN_GEMM_WMMA")[0]) {
        static int wfired = 0; if (!wfired){wfired=1; fprintf(stderr,"[OWN-SGEMM-WMMA-FIRED] _hx_k_sgemm_cm_wmma (TF32 Tensor-Core)\n");}
        dim3 wblk(32); dim3 wgrd((unsigned)((m+15)/16),(unsigned)((n+15)/16));  // 1 warp / 16×16 C tile
        _hx_k_sgemm_cm_wmma<<<wgrd,wblk>>>(tA,tB,
                                           (long long)m,(long long)n,(long long)k,
                                           alpha, A,(long long)lda, B,(long long)ldb,
                                           beta, C,(long long)ldc);
    } else if (getenv("HEXA_OWN_GEMM_TILED") && getenv("HEXA_OWN_GEMM_TILED")[0]) {
        static int tfired = 0; if (!tfired){tfired=1; fprintf(stderr,"[OWN-SGEMM-TILED-FIRED] _hx_k_sgemm_cm_tiled\n");}
        _hx_k_sgemm_cm_tiled<<<grd,blk>>>(tA,tB,
                                          (long long)m,(long long)n,(long long)k,
                                          alpha, A,(long long)lda, B,(long long)ldb,
                                          beta, C,(long long)ldc);
    } else {
        _hx_k_sgemm_cm_v54<<<grd,blk>>>(tA,tB,
                                        (long long)m,(long long)n,(long long)k,
                                        alpha, A,(long long)lda, B,(long long)ldb,
                                        beta, C,(long long)ldc);
    }
    // THRU-PARITY: do NOT cudaDeviceSynchronize per call — that serialized all 7
    // LoRA GEMMs + glue every step (the 2.2× steps/s gap vs async cuBLAS). A
    // non-blocking launch-error check keeps correctness coverage without forcing
    // a host↔device round-trip; the caller syncs once at the step boundary (the
    // glue/CE readback already does). HEXA_OWN_GEMM_SYNC=1 restores the old sync.
    if (getenv("HEXA_OWN_GEMM_SYNC") && getenv("HEXA_OWN_GEMM_SYNC")[0]) {
        cudaError_t e = cudaDeviceSynchronize();
        return (e==cudaSuccess) ? 0 : (int)e;
    }
    cudaError_t e = cudaGetLastError();
    return (e==cudaSuccess) ? 0 : (int)e;
}
static cublasStatus_t hxqwen_sgemm_base(cublasOperation_t tA, cublasOperation_t tB,
                                        int m, int n, int k, const float* alpha,
                                        const float* A, int lda, const float* B, int ldb,
                                        const float* beta, float* C, int ldc) {
    if (getenv("HEXA_OWN_GEMM") && getenv("HEXA_OWN_GEMM")[0]) {
        static int fired = 0; if (!fired){fired=1; fprintf(stderr,"[OWN-SGEMM-FIRED] _hx_k_sgemm_cm_v54\n");}
        int rc = _hx_own_sgemm_cm_launch((tA==CUBLAS_OP_T),(tB==CUBLAS_OP_T),
                                         m,n,k, *alpha, A,lda, B,ldb, *beta, C,ldc);
        return (rc==0) ? CUBLAS_STATUS_SUCCESS : CUBLAS_STATUS_EXECUTION_FAILED;
    }
    return cublasSgemm(g_cublas_handle, tA,tB, m,n,k, alpha,A,lda,B,ldb, beta,C,ldc);
}

int hxqwen14b_cu_launch_bf16_to_fp32(
    int64_t src_bf16_dev, int64_t dst_fp32_dev, int64_t N
) {
    if (src_bf16_dev == 0 || dst_fp32_dev == 0 || N <= 0) return HXQ_RC_KERNEL_FAIL;
    int threads = 256;
    unsigned blocks = (unsigned)((N + threads - 1) / threads);
    v54_bf16_to_fp32_kernel<<<blocks, threads>>>(
        (const __nv_bfloat16*)(uintptr_t)src_bf16_dev,
        (float*)(uintptr_t)dst_fp32_dev, N);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

int hxqwen14b_cu_launch_embed_lookup(
    int64_t embed_dev, int64_t ids_dev, int64_t out_dev,
    int64_t V, int64_t d, int64_t M
) {
    if (embed_dev == 0 || ids_dev == 0 || out_dev == 0) return HXQ_RC_KERNEL_FAIL;
    int threads = (d < 256) ? (int)d : 256;
    if (threads < 32) threads = 32;
    v54_embed_lookup_kernel<<<(unsigned)M, threads>>>(
        (const float*)(uintptr_t)embed_dev,
        (const int32_t*)(uintptr_t)ids_dev,
        (float*)(uintptr_t)out_dev, V, d);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

int hxqwen14b_cu_launch_residual_add(
    int64_t x_dev, int64_t y_dev, int64_t N
) {
    if (x_dev == 0 || y_dev == 0 || N <= 0) return HXQ_RC_KERNEL_FAIL;
    int threads = 256;
    unsigned blocks = (unsigned)((N + threads - 1) / threads);
    v54_residual_add_kernel<<<blocks, threads>>>(
        (const float*)(uintptr_t)x_dev,
        (float*)(uintptr_t)y_dev, N);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

// v5.4.2: launch 1D bias add — tensor[M, D] += bias[D].
int hxqwen14b_cu_launch_add_bias_1d(
    int64_t tensor_dev, int64_t bias_dev, int64_t M, int64_t D
) {
    if (tensor_dev == 0 || bias_dev == 0 || M <= 0 || D <= 0)
        return HXQ_RC_KERNEL_FAIL;
    int threads = (D < 1024) ? (int)D : 1024;
    dim3 grid((unsigned)M);
    dim3 block(threads);
    v54_add_bias_1d_kernel<<<grid, block>>>(
        (float*)(uintptr_t)tensor_dev,
        (const float*)(uintptr_t)bias_dev,
        M, D);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

// Compute C[M,N] = X[M,K] @ W_T[K,N] where W is stored row-major as [N,K]
// (HF weight convention).
//
// v5.4.4 CORRECTED LAYOUT — prior v5.4.0..v5.4.3 used (OP_N, OP_N, lda=N)
// which silently returns a permuted/strided WRONG result whenever N != K.
// That single bug was the BLOCKED_WEIGHT_DECODE smoke CE≈16 symptom: it
// garbles every sgemm (q/k/v/o/gate/up/down + lm_head), producing
// confidently wrong logits — exactly the pattern expected.
// Verified against /tmp/sgemm_verify.cu on H100 (2026-04-20).
//
// Derivation (col-major cuBLAS, row-major inputs):
//   row-major M[a,b] == col-major M^T[b,a] with lda=b.
// So:
//   row-major X[M,K]         → col-major X^T[K,M]          with ldb=K
//   row-major W[N,K]         → col-major W^T[K,N]          with lda=K
//   desired row-major C[M,N] → col-major C^T[N,M]          with ldc=N
// We need col-major C^T = (X @ W^T)^T = W @ X^T.
//   op(A) = col-major W[N,K] → apply OP_T to col-major W^T[K,N]
//   op(B) = col-major X^T[K,M] → OP_N (no transpose).
// => cublasSgemm(OP_T, OP_N, m=N, n=M, k=K,
//                A=W ptr, lda=K,
//                B=X ptr, ldb=K,
//                C ptr, ldc=N).
int hxqwen14b_cu_launch_sgemm_rowmajor_xwt(
    int64_t X_dev, int64_t W_dev, int64_t C_dev,
    int64_t M, int64_t N, int64_t K,
    float alpha, float beta
) {
    if (v54_ensure_cublas() != HXQ_RC_OK) return HXQ_RC_KERNEL_FAIL;
    if (X_dev == 0 || W_dev == 0 || C_dev == 0) return HXQ_RC_KERNEL_FAIL;
    if (M <= 0 || N <= 0 || K <= 0) return HXQ_RC_KERNEL_FAIL;
    cublasStatus_t st = hxqwen_sgemm_base(
        CUBLAS_OP_T, CUBLAS_OP_N,
        (int)N, (int)M, (int)K,
        &alpha,
        (const float*)(uintptr_t)W_dev, (int)K,
        (const float*)(uintptr_t)X_dev, (int)K,
        &beta,
        (float*)(uintptr_t)C_dev, (int)N);
    return (st == CUBLAS_STATUS_SUCCESS) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

// Same as above but the "W" is the embed matrix [V,d], and we want
// logits[M,V] = x[M,d] @ embed[V,d]^T. Same signature semantics as
// sgemm_rowmajor_xwt with N=V, K=d.  Separate entry kept for caller
// readability / potential future bf16 specialization.
int hxqwen14b_cu_launch_tied_lm_head(
    int64_t x_dev, int64_t embed_dev, int64_t logits_dev,
    int64_t M, int64_t V, int64_t d
) {
    return hxqwen14b_cu_launch_sgemm_rowmajor_xwt(
        x_dev, embed_dev, logits_dev, M, V, d, 1.0f, 0.0f);
}

int hxqwen14b_cu_launch_softmax_ce(
    int64_t logits_dev, int64_t targets_dev, int64_t out_nll_dev,
    int64_t M, int64_t V
) {
    if (logits_dev == 0 || targets_dev == 0 || out_nll_dev == 0) return HXQ_RC_KERNEL_FAIL;
    int threads = 256;
    v54_softmax_ce_kernel<<<(unsigned)M, threads>>>(
        (const float*)(uintptr_t)logits_dev,
        (const int32_t*)(uintptr_t)targets_dev,
        (float*)(uintptr_t)out_nll_dev, V);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

int hxqwen14b_cu_cublas_destroy(void) {
    if (g_cublas_handle != NULL) {
        cublasDestroy(g_cublas_handle);
        g_cublas_handle = NULL;
    }
    return HXQ_RC_OK;
}

// ═════════════════════════════════════════════════════════════════════
// v5.6.3 backward kernels — Phase-2 LoRA training surface.
// ═════════════════════════════════════════════════════════════════════

// Kernel: softmax + cross-entropy backward.
// Given logits[M,V] and targets[M] (int32 token ids), produce
//   dlogits[m,v] = (softmax(logits[m])[v] - onehot(targets[m])[v]) / M
// One block per row m, threads tree-reduce sum(exp).
__global__ void v563_softmax_ce_bwd_kernel(
    const float* __restrict__ logits,
    const int32_t* __restrict__ targets,
    float* __restrict__ dlogits,
    int V, int M
) {
    int m = blockIdx.x;
    int tid = threadIdx.x;
    const float* lr = logits + m * V;
    float*       dr = dlogits + m * V;

    // Step 1: row max for numerical stability.
    __shared__ float s_max[32];
    float local_max = -INFINITY;
    for (int v = tid; v < V; v += blockDim.x) {
        float lv = lr[v];
        if (lv > local_max) local_max = lv;
    }
    // warp reduce
    for (int off = 16; off > 0; off >>= 1) {
        float other = __shfl_down_sync(0xffffffff, local_max, off);
        if (other > local_max) local_max = other;
    }
    int warp = tid >> 5;
    int lane = tid & 31;
    if (lane == 0) s_max[warp] = local_max;
    __syncthreads();
    if (warp == 0) {
        float vmax = (tid < (blockDim.x + 31)/32) ? s_max[lane] : -INFINITY;
        for (int off = 16; off > 0; off >>= 1) {
            float other = __shfl_down_sync(0xffffffff, vmax, off);
            if (other > vmax) vmax = other;
        }
        if (lane == 0) s_max[0] = vmax;
    }
    __syncthreads();
    float row_max = s_max[0];

    // Step 2: row sum of exp(l-max).
    __shared__ float s_sum[32];
    float local_sum = 0.0f;
    for (int v = tid; v < V; v += blockDim.x) {
        local_sum += expf(lr[v] - row_max);
    }
    for (int off = 16; off > 0; off >>= 1) {
        local_sum += __shfl_down_sync(0xffffffff, local_sum, off);
    }
    if (lane == 0) s_sum[warp] = local_sum;
    __syncthreads();
    if (warp == 0) {
        float vs = (tid < (blockDim.x + 31)/32) ? s_sum[lane] : 0.0f;
        for (int off = 16; off > 0; off >>= 1) {
            vs += __shfl_down_sync(0xffffffff, vs, off);
        }
        if (lane == 0) s_sum[0] = vs;
    }
    __syncthreads();
    float row_Z = s_sum[0];
    float invZ = 1.0f / row_Z;
    float invM = 1.0f / (float)M;

    int t = targets[m];
    // Step 3: write dlogits = (softmax - onehot) / M
    for (int v = tid; v < V; v += blockDim.x) {
        float p = expf(lr[v] - row_max) * invZ;
        float oh = (v == t) ? 1.0f : 0.0f;
        dr[v] = (p - oh) * invM;
    }
}

int hxqwen14b_cu_launch_softmax_ce_bwd(
    int64_t logits_dev, int64_t targets_dev, int64_t dlogits_dev,
    int64_t M, int64_t V
) {
    if (logits_dev == 0 || targets_dev == 0 || dlogits_dev == 0) return HXQ_RC_KERNEL_FAIL;
    if (M <= 0 || V <= 0) return HXQ_RC_KERNEL_FAIL;
    int threads = 256;
    v563_softmax_ce_bwd_kernel<<<(unsigned)M, threads>>>(
        (const float*)(uintptr_t)logits_dev,
        (const int32_t*)(uintptr_t)targets_dev,
        (float*)(uintptr_t)dlogits_dev,
        (int)V, (int)M);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

// ═════════════════════════════════════════════════════════════════════
// Kernel: RMSNorm backward.
//   Forward: y[i,j] = x[i,j] * rsqrt(mean(x[i]^2) + eps) * w[j]
//   Let r = rsqrt(mean(x[i]^2) + eps).  (computed per-row in fwd, here recomputed.)
//   ∂L/∂x[i,k] = w[k] * r * ∂y[i,k]
//                - (1/d) * x[i,k] * r^3 * Σ_j (w[j] * ∂y[i,j] * x[i,j])
//   ∂L/∂w[j]  += Σ_i ∂y[i,j] * x[i,j] * r_i           (atomic across rows)
//
// One block per row m. Threads tree-reduce sum_sq (for r) then sum(w*dy*x)
// (for the second term and for dw partials). Two reductions — recompute r
// inside kernel rather than reading rstd cache (avoids extra slot).
// ═════════════════════════════════════════════════════════════════════
__global__ void v563_rmsnorm_bwd_kernel(
    const float* __restrict__ x,    // [M, d]
    const float* __restrict__ w,    // [d]
    const float* __restrict__ dy,   // [M, d]
    float* __restrict__ dx,         // [M, d]   (written)
    float* __restrict__ dw,         // [d]      (atomicAdd accumulated)
    int d, float eps
) {
    int row = blockIdx.x;
    int tid = threadIdx.x;
    const float* xr  = x  + row * d;
    const float* dyr = dy + row * d;
    float*       dxr = dx + row * d;

    // Pass 1: sum_sq for r = rsqrt(mean(x^2)+eps)
    float sum_sq = 0.0f;
    for (int j = tid; j < d; j += blockDim.x) {
        float v = xr[j];
        sum_sq += v * v;
    }
    __shared__ float s_red[32];
    unsigned mask = 0xffffffff;
    for (int off = 16; off > 0; off >>= 1) sum_sq += __shfl_down_sync(mask, sum_sq, off);
    int warp = tid >> 5;
    int lane = tid & 31;
    if (lane == 0) s_red[warp] = sum_sq;
    __syncthreads();
    if (warp == 0) {
        int n_warps = (blockDim.x + 31) >> 5;
        float v = (lane < n_warps) ? s_red[lane] : 0.0f;
        for (int off = 16; off > 0; off >>= 1) v += __shfl_down_sync(mask, v, off);
        if (lane == 0) s_red[0] = v;
    }
    __syncthreads();
    float mean_sq = s_red[0] / (float)d;
    float r       = rsqrtf(mean_sq + eps);

    // Pass 2: c = Σ_j (w[j] * dy[j] * x[j])  — needed for dx second term.
    float c_part = 0.0f;
    for (int j = tid; j < d; j += blockDim.x) {
        c_part += w[j] * dyr[j] * xr[j];
    }
    for (int off = 16; off > 0; off >>= 1) c_part += __shfl_down_sync(mask, c_part, off);
    if (lane == 0) s_red[warp] = c_part;
    __syncthreads();
    if (warp == 0) {
        int n_warps = (blockDim.x + 31) >> 5;
        float v = (lane < n_warps) ? s_red[lane] : 0.0f;
        for (int off = 16; off > 0; off >>= 1) v += __shfl_down_sync(mask, v, off);
        if (lane == 0) s_red[0] = v;
    }
    __syncthreads();
    float c = s_red[0];

    // Pass 3: write dx + accumulate dw.
    float r3_over_d = r * r * r / (float)d;
    for (int j = tid; j < d; j += blockDim.x) {
        float wj = w[j];
        float dyj = dyr[j];
        float xj  = xr[j];
        dxr[j] = wj * r * dyj - xj * r3_over_d * c;
        // dw partial — atomic across rows. Cheap because contention is per-col.
        atomicAdd(&dw[j], dyj * xj * r);
    }
}

int hxqwen14b_cu_launch_rmsnorm_bwd(
    int64_t x_dev, int64_t w_dev, int64_t dy_dev,
    int64_t dx_dev, int64_t dw_dev,
    int64_t M, int64_t d, float eps
) {
    if (x_dev == 0 || w_dev == 0 || dy_dev == 0 || dx_dev == 0 || dw_dev == 0)
        return HXQ_RC_KERNEL_FAIL;
    if (M <= 0 || d <= 0) return HXQ_RC_KERNEL_FAIL;
    int threads = 256;
    if (d < 256) threads = 128;
    if (d < 128) threads = 64;
    v563_rmsnorm_bwd_kernel<<<(unsigned)M, threads>>>(
        (const float*)(uintptr_t)x_dev,
        (const float*)(uintptr_t)w_dev,
        (const float*)(uintptr_t)dy_dev,
        (float*)(uintptr_t)dx_dev,
        (float*)(uintptr_t)dw_dev,
        (int)d, eps);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

// ═════════════════════════════════════════════════════════════════════
// Kernel: RoPE backward (rotate_half layout, Llama/Qwen2).
//   Forward (per (bs, h, k) with k in [0, D/2)):
//     x0' = x0 * cs - x1 * sn
//     x1' = x1 * cs + x0 * sn
//   Backward (rotation is unitary; transpose = inverse rotation):
//     dx0 =  dy0 * cs + dy1 * sn
//     dx1 = -dy0 * sn + dy1 * cs
//
// dy is the upstream gradient on the rotated tensor; we write dx in-place.
// Caller may pass dx_dev == dy_dev for in-place backward (kernel reads
// both halves into registers before writing, like the forward).
// ═════════════════════════════════════════════════════════════════════
__global__ void v563_rope_bwd_kernel(
    const float* __restrict__ dy,
    float* __restrict__ dx,
    int B, int S, int H, int D,
    float theta_base, int pos_offset
) {
    int bs   = blockIdx.x;
    int h    = blockIdx.y;
    int k    = threadIdx.x;
    int half = D >> 1;
    if (k >= half) return;
    (void)B;
    int s = bs - (bs / S) * S;
    float pos = (float)(pos_offset + s);
    float inv_freq = powf(theta_base, -((float)(2 * k)) / (float)D);
    float angle    = pos * inv_freq;
    float cs, sn;
    __sincosf(angle, &sn, &cs);

    int base = (bs * H + h) * D;
    float dy0 = dy[base + k];
    float dy1 = dy[base + half + k];
    // Inverse rotation (transpose).
    dx[base + k]        =  dy0 * cs + dy1 * sn;
    dx[base + half + k] = -dy0 * sn + dy1 * cs;
}

int hxqwen14b_cu_launch_rope_bwd(
    int64_t dy_dev, int64_t dx_dev,
    int64_t B, int64_t S, int64_t H, int64_t D,
    float theta_base, int64_t pos_offset
) {
    if (dy_dev == 0 || dx_dev == 0) return HXQ_RC_KERNEL_FAIL;
    if (B <= 0 || S <= 0 || H <= 0 || D <= 0) return HXQ_RC_KERNEL_FAIL;
    dim3 grid((unsigned)(B * S), (unsigned)H, 1);
    int  threads = (int)(D / 2);
    if (threads < 32) threads = 32;
    v563_rope_bwd_kernel<<<grid, threads>>>(
        (const float*)(uintptr_t)dy_dev,
        (float*)(uintptr_t)dx_dev,
        (int)B, (int)S, (int)H, (int)D, theta_base, (int)pos_offset);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

// ═════════════════════════════════════════════════════════════════════
// Kernel: SwiGLU backward.
//   Forward: y = silu(g) * u   where silu(g) = g * sigmoid(g)
//   Let s = sigmoid(g);  silu(g) = g*s;  silu'(g) = s + g*s*(1-s)
//   ∂L/∂g = ∂L/∂y * u * silu'(g)
//   ∂L/∂u = ∂L/∂y * silu(g)
// Element-wise. dg/du can alias g/u (read both into registers first).
// ═════════════════════════════════════════════════════════════════════
__global__ void v563_swiglu_bwd_kernel(
    const float* __restrict__ g,
    const float* __restrict__ u,
    const float* __restrict__ dy,
    float* __restrict__ dg,
    float* __restrict__ du,
    int64_t N
) {
    int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;
    float gi = g[i];
    float ui = u[i];
    float dyi = dy[i];
    float sig;
    if (gi >= 0.0f) {
        sig = 1.0f / (1.0f + expf(-gi));
    } else {
        float e = expf(gi);
        sig = e / (1.0f + e);
    }
    float silu_g = gi * sig;
    float silu_d = sig + gi * sig * (1.0f - sig);  // silu'(g)
    dg[i] = dyi * ui * silu_d;
    du[i] = dyi * silu_g;
}

int hxqwen14b_cu_launch_swiglu_bwd(
    int64_t g_dev, int64_t u_dev, int64_t dy_dev,
    int64_t dg_dev, int64_t du_dev, int64_t N
) {
    if (g_dev == 0 || u_dev == 0 || dy_dev == 0 || dg_dev == 0 || du_dev == 0)
        return HXQ_RC_KERNEL_FAIL;
    if (N <= 0) return HXQ_RC_KERNEL_FAIL;
    int threads = 256;
    unsigned blocks = (unsigned)((N + threads - 1) / threads);
    v563_swiglu_bwd_kernel<<<blocks, threads>>>(
        (const float*)(uintptr_t)g_dev,
        (const float*)(uintptr_t)u_dev,
        (const float*)(uintptr_t)dy_dev,
        (float*)(uintptr_t)dg_dev,
        (float*)(uintptr_t)du_dev, N);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

// ═════════════════════════════════════════════════════════════════════
// Kernel: GQA attention backward (reference; not flash).
//
// Forward (per (b, hq, i)):
//   dot[j] = scale * Σ_d Q[b,i,hq,d] * K[b,j,hk,d]    (hk = hq/G)
//   p[j]   = softmax_j(dot[j])    (causal: j <= i)
//   O[b,i,hq,d] = Σ_j p[j] * V[b,j,hk,d]
//
// Backward (given dO):
//   dV[b,j,hk,d] += Σ_i p[j|i] * dO[b,i,hq,d]    (sum over hq in the GQA group)
//   dp[j]        = Σ_d dO[b,i,hq,d] * V[b,j,hk,d]
//   dscore[j]    = (dp[j] - Σ_k p[k]*dp[k]) * p[j]
//   dQ[b,i,hq,d] += scale * Σ_j dscore[j] * K[b,j,hk,d]
//   dK[b,j,hk,d] += scale * Σ_i dscore[j|i] * Q[b,i,hq,d] (sum over hq in group)
//
// Recompute p inside the kernel (memory-saving, like the fwd online softmax).
// One block per (b, hq, i).  Threads = D, used to:
//   - hold q[d] in shared
//   - compute dot per j (warp reduce)
//   - compute softmax (recompute with the same online-max trick as fwd)
//   - compute p[j], dp[j], sum(p*dp) → dscore[j] → atomic dK / dQ accumulation
//   - per-d update dQ[i,hq,d] (no atomic; unique per block)
//   - atomicAdd into dV[j,hk,d] (multiple hq blocks share hk)
// ═════════════════════════════════════════════════════════════════════
__global__ void v563_gqa_bwd_kernel(
    const float* __restrict__ Q,    // [B, S, HQ, D]
    const float* __restrict__ K,    // [B, S, HK, D]
    const float* __restrict__ V,    // [B, S, HK, D]
    const float* __restrict__ dO,   // [B, S, HQ, D]
    float* __restrict__ dQ,         // [B, S, HQ, D]   (written; assume zero-init by caller)
    float* __restrict__ dK,         // [B, S, HK, D]   (atomicAdd)
    float* __restrict__ dV,         // [B, S, HK, D]   (atomicAdd)
    int B, int S, int HQ, int HK, int D,
    float scale, int causal
) {
    int b  = blockIdx.x;
    int hq = blockIdx.y;
    int i  = blockIdx.z;
    int d  = threadIdx.x;
    if (d >= D) return;
    int G  = HQ / HK;
    int hk = hq / G;
    (void)B;

    const float* qi   = Q  + (((b * S + i) * HQ + hq) * D);
    const float* dOi  = dO + (((b * S + i) * HQ + hq) * D);
    float*       dQi  = dQ + (((b * S + i) * HQ + hq) * D);

    __shared__ float s_qi[256];
    __shared__ float s_dOi[256];
    __shared__ float s_red[8];   // warp partials for dot reductions
    __shared__ float s_max;
    __shared__ float s_sumZ;
    __shared__ float s_sum_pdp;

    s_qi[d]  = qi[d];
    s_dOi[d] = dOi[d];
    if (d == 0) { s_max = -1e30f; s_sumZ = 0.0f; s_sum_pdp = 0.0f; }
    __syncthreads();

    int j_end = causal ? (i + 1) : S;
    unsigned mask = 0xffffffff;

    // ── Pass 1: row max of dot[j] for numerical stability.
    float my_max = -1e30f;
    for (int j = 0; j < j_end; j++) {
        const float* kj = K + (((b * S + j) * HK + hk) * D);
        float partial = s_qi[d] * kj[d];
        for (int off = 16; off > 0; off >>= 1) partial += __shfl_down_sync(mask, partial, off);
        int warp = d >> 5;
        int lane = d & 31;
        if (lane == 0) s_red[warp] = partial;
        __syncthreads();
        if (warp == 0) {
            int n_warps = (D + 31) >> 5;
            float v = (lane < n_warps) ? s_red[lane] : 0.0f;
            for (int off = 16; off > 0; off >>= 1) v += __shfl_down_sync(mask, v, off);
            if (lane == 0) s_red[0] = v;
        }
        __syncthreads();
        float dot = s_red[0] * scale;
        if (d == 0 && dot > my_max) my_max = dot;
        __syncthreads();
    }
    if (d == 0) s_max = my_max;
    __syncthreads();
    float row_max = s_max;

    // ── Pass 2: row sum Z = Σ exp(dot - max) — needed to normalize p.
    float my_Z = 0.0f;
    for (int j = 0; j < j_end; j++) {
        const float* kj = K + (((b * S + j) * HK + hk) * D);
        float partial = s_qi[d] * kj[d];
        for (int off = 16; off > 0; off >>= 1) partial += __shfl_down_sync(mask, partial, off);
        int warp = d >> 5;
        int lane = d & 31;
        if (lane == 0) s_red[warp] = partial;
        __syncthreads();
        if (warp == 0) {
            int n_warps = (D + 31) >> 5;
            float v = (lane < n_warps) ? s_red[lane] : 0.0f;
            for (int off = 16; off > 0; off >>= 1) v += __shfl_down_sync(mask, v, off);
            if (lane == 0) s_red[0] = v;
        }
        __syncthreads();
        float dot = s_red[0] * scale;
        if (d == 0) my_Z += expf(dot - row_max);
        __syncthreads();
    }
    if (d == 0) s_sumZ = my_Z;
    __syncthreads();
    float invZ = 1.0f / s_sumZ;

    // ── Pass 3: compute Σ_j p[j]*dp[j]   where dp[j] = Σ_d dO[d] * V[j,d]
    float my_sum_pdp = 0.0f;
    for (int j = 0; j < j_end; j++) {
        const float* kj = K + (((b * S + j) * HK + hk) * D);
        const float* vj = V + (((b * S + j) * HK + hk) * D);
        // dot for p[j]
        float partial = s_qi[d] * kj[d];
        for (int off = 16; off > 0; off >>= 1) partial += __shfl_down_sync(mask, partial, off);
        int warp = d >> 5;
        int lane = d & 31;
        if (lane == 0) s_red[warp] = partial;
        __syncthreads();
        if (warp == 0) {
            int n_warps = (D + 31) >> 5;
            float v = (lane < n_warps) ? s_red[lane] : 0.0f;
            for (int off = 16; off > 0; off >>= 1) v += __shfl_down_sync(mask, v, off);
            if (lane == 0) s_red[0] = v;
        }
        __syncthreads();
        float dot = s_red[0] * scale;
        float p = expf(dot - row_max) * invZ;
        // dp[j] = Σ_d dO[d] * V[j,d]
        float dpp = s_dOi[d] * vj[d];
        for (int off = 16; off > 0; off >>= 1) dpp += __shfl_down_sync(mask, dpp, off);
        if (lane == 0) s_red[warp] = dpp;
        __syncthreads();
        if (warp == 0) {
            int n_warps = (D + 31) >> 5;
            float v = (lane < n_warps) ? s_red[lane] : 0.0f;
            for (int off = 16; off > 0; off >>= 1) v += __shfl_down_sync(mask, v, off);
            if (lane == 0) s_red[0] = v;
        }
        __syncthreads();
        float dp = s_red[0];
        if (d == 0) my_sum_pdp += p * dp;
        __syncthreads();
    }
    if (d == 0) s_sum_pdp = my_sum_pdp;
    __syncthreads();
    float sum_pdp = s_sum_pdp;

    // ── Pass 4: write dQ, accumulate dK and dV. dQ[i,hq,d] uniquely owned by
    //          this block; dK and dV shared across hq in the group → atomic.
    float my_dQ = 0.0f;
    for (int j = 0; j < j_end; j++) {
        const float* kj = K + (((b * S + j) * HK + hk) * D);
        const float* vj = V + (((b * S + j) * HK + hk) * D);
        float* dKj = dK + (((b * S + j) * HK + hk) * D);
        float* dVj = dV + (((b * S + j) * HK + hk) * D);

        // Recompute dot, p[j].
        float partial = s_qi[d] * kj[d];
        for (int off = 16; off > 0; off >>= 1) partial += __shfl_down_sync(mask, partial, off);
        int warp = d >> 5;
        int lane = d & 31;
        if (lane == 0) s_red[warp] = partial;
        __syncthreads();
        if (warp == 0) {
            int n_warps = (D + 31) >> 5;
            float v = (lane < n_warps) ? s_red[lane] : 0.0f;
            for (int off = 16; off > 0; off >>= 1) v += __shfl_down_sync(mask, v, off);
            if (lane == 0) s_red[0] = v;
        }
        __syncthreads();
        float dot = s_red[0] * scale;
        float p = expf(dot - row_max) * invZ;

        // Recompute dp[j].
        float dpp = s_dOi[d] * vj[d];
        for (int off = 16; off > 0; off >>= 1) dpp += __shfl_down_sync(mask, dpp, off);
        if (lane == 0) s_red[warp] = dpp;
        __syncthreads();
        if (warp == 0) {
            int n_warps = (D + 31) >> 5;
            float v = (lane < n_warps) ? s_red[lane] : 0.0f;
            for (int off = 16; off > 0; off >>= 1) v += __shfl_down_sync(mask, v, off);
            if (lane == 0) s_red[0] = v;
        }
        __syncthreads();
        float dp = s_red[0];

        float dscore = (dp - sum_pdp) * p;
        // dQ[d] += scale * dscore * K[j,d]
        my_dQ += scale * dscore * kj[d];
        // dK[j,d] += scale * dscore * Q[i,d]
        atomicAdd(&dKj[d], scale * dscore * s_qi[d]);
        // dV[j,d] += p * dO[d]
        atomicAdd(&dVj[d], p * s_dOi[d]);
    }
    dQi[d] = my_dQ;
}

int hxqwen14b_cu_launch_gqa_bwd(
    int64_t Q_dev, int64_t K_dev, int64_t V_dev, int64_t dO_dev,
    int64_t dQ_dev, int64_t dK_dev, int64_t dV_dev,
    int64_t B, int64_t S, int64_t HQ, int64_t HK, int64_t D,
    float scale, int64_t causal
) {
    if (Q_dev == 0 || K_dev == 0 || V_dev == 0 || dO_dev == 0) return HXQ_RC_KERNEL_FAIL;
    if (dQ_dev == 0 || dK_dev == 0 || dV_dev == 0)             return HXQ_RC_KERNEL_FAIL;
    if (B <= 0 || S <= 0 || HQ <= 0 || HK <= 0 || D <= 0)      return HXQ_RC_KERNEL_FAIL;
    if (HQ % HK != 0)                                          return HXQ_RC_KERNEL_FAIL;
    dim3 grid((unsigned)B, (unsigned)HQ, (unsigned)S);
    int  threads = (int)D;
    v563_gqa_bwd_kernel<<<grid, threads>>>(
        (const float*)(uintptr_t)Q_dev,
        (const float*)(uintptr_t)K_dev,
        (const float*)(uintptr_t)V_dev,
        (const float*)(uintptr_t)dO_dev,
        (float*)(uintptr_t)dQ_dev,
        (float*)(uintptr_t)dK_dev,
        (float*)(uintptr_t)dV_dev,
        (int)B, (int)S, (int)HQ, (int)HK, (int)D,
        scale, (int)causal);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

// ═════════════════════════════════════════════════════════════════════
// v5.6.5 — host helpers needed by the backward orchestrator.
//
// 1. sgemm_rowmajor_xw  — dx = dy[M,N] @ W[N,K]   (input-grad through a
//    frozen base sgemm whose forward was C = X @ W^T). cuBLAS row-major
//    derivation: row-major dy[M,N] @ W[N,K] = row-major dx[M,K].
//    col-major view: dx^T[K,M] = W^T[N,K]^T_col · dy^T[N,M]_col.
//    Use cublasSgemm(OP_N, OP_N, m=K, n=M, k=N,
//                    A=W,  lda=K,
//                    B=dy, ldb=N,
//                    C=dx, ldc=K).
// 2. cu_memset_zero(dst, bytes) — wraps cudaMemsetAsync, used to zero
//    accumulators between layer steps without per-launch malloc.
// 3. cu_axpy(dst, src, N, alpha) — dst += alpha * src; element-wise.
//    Used for accumulating dnormed contributions from q/k/v branches and
//    residual carry adds.
// ═════════════════════════════════════════════════════════════════════

int hxqwen14b_cu_launch_sgemm_rowmajor_xw(
    int64_t dy_dev, int64_t W_dev, int64_t dx_dev,
    int64_t M, int64_t K, int64_t N,
    float alpha, float beta
) {
    if (v54_ensure_cublas() != HXQ_RC_OK) return HXQ_RC_KERNEL_FAIL;
    if (dy_dev == 0 || W_dev == 0 || dx_dev == 0) return HXQ_RC_KERNEL_FAIL;
    if (M <= 0 || N <= 0 || K <= 0) return HXQ_RC_KERNEL_FAIL;
    cublasStatus_t st = hxqwen_sgemm_base(
        CUBLAS_OP_N, CUBLAS_OP_N,
        (int)K, (int)M, (int)N,
        &alpha,
        (const float*)(uintptr_t)W_dev,  (int)K,
        (const float*)(uintptr_t)dy_dev, (int)N,
        &beta,
        (float*)(uintptr_t)dx_dev, (int)K);
    return (st == CUBLAS_STATUS_SUCCESS) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

int hxqwen14b_cu_launch_memset_zero(int64_t dst_dev, int64_t bytes) {
    if (dst_dev == 0 || bytes <= 0) return HXQ_RC_KERNEL_FAIL;
    cudaError_t e = cudaMemsetAsync((void*)(uintptr_t)dst_dev, 0, (size_t)bytes, 0);
    return (e == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

__global__ void v565_axpy_kernel(
    float* __restrict__ dst, const float* __restrict__ src,
    float alpha, int64_t N
) {
    int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;
    dst[i] = dst[i] + alpha * src[i];
}

int hxqwen14b_cu_launch_axpy(int64_t dst_dev, int64_t src_dev,
                              int64_t N, float alpha) {
    if (dst_dev == 0 || src_dev == 0 || N <= 0) return HXQ_RC_KERNEL_FAIL;
    int threads = 256;
    unsigned blocks = (unsigned)((N + threads - 1) / threads);
    v565_axpy_kernel<<<blocks, threads>>>(
        (float*)(uintptr_t)dst_dev,
        (const float*)(uintptr_t)src_dev, alpha, N);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

// ═════════════════════════════════════════════════════════════════════
// v5.6.5 — on-device AdamW step.
//   Update rule (per element):
//     m = β1·m + (1-β1)·g
//     v = β2·v + (1-β2)·g²
//     m_hat = m / (1 - β1^t)
//     v_hat = v / (1 - β2^t)
//     θ -= lr · (m_hat / (sqrt(v_hat) + eps) + wd · θ)
//   Decoupled weight decay (AdamW). bias_correction handled per-call so
//   caller passes step t≥1.
//
// v5.6.6 NaN-guard (r12 NaN root-cause fix 2026-04-20):
//   If gi is NaN/Inf, skip element entirely (preserve previous m/v/p),
//   so a single bad gradient cannot poison every subsequent step. This
//   is defense-in-depth alongside the new global L2 grad-clip helper.
// ═════════════════════════════════════════════════════════════════════
__global__ void v565_adamw_step_kernel(
    float* __restrict__ p,
    const float* __restrict__ g,
    float* __restrict__ m,
    float* __restrict__ v,
    float lr, float beta1, float beta2, float eps, float wd,
    float bc1, float bc2,    // bias corrections: 1 - beta^t
    int64_t N
) {
    int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;
    float gi = g[i];
    // r12 NaN-guard: drop bad gradient elements without corrupting state.
    // isfinite() returns false for NaN, +Inf, -Inf.
    if (!isfinite(gi)) return;
    float mi = beta1 * m[i] + (1.0f - beta1) * gi;
    float vi = beta2 * v[i] + (1.0f - beta2) * gi * gi;
    m[i] = mi;
    v[i] = vi;
    float m_hat = mi / bc1;
    float v_hat = vi / bc2;
    float upd = m_hat / (sqrtf(v_hat) + eps) + wd * p[i];
    float p_new = p[i] - lr * upd;
    // r12 NaN-guard: also drop poisoned param updates (e.g. NaN m/v leak
    // from a pre-fix run). Parameter stays at its last finite value.
    if (!isfinite(p_new)) return;
    p[i] = p_new;
}

extern "C" int hxqwen14b_cu_launch_adamw_step(
    int64_t p_dev, int64_t g_dev, int64_t m_dev, int64_t v_dev,
    float lr, float beta1, float beta2, float eps, float wd,
    int64_t step, int64_t N
) {
    if (p_dev == 0 || g_dev == 0 || m_dev == 0 || v_dev == 0) return HXQ_RC_KERNEL_FAIL;
    if (N <= 0 || step <= 0) return HXQ_RC_KERNEL_FAIL;
    float bc1 = 1.0f - powf(beta1, (float)step);
    float bc2 = 1.0f - powf(beta2, (float)step);
    int threads = 256;
    unsigned blocks = (unsigned)((N + threads - 1) / threads);
    v565_adamw_step_kernel<<<blocks, threads>>>(
        (float*)(uintptr_t)p_dev,
        (const float*)(uintptr_t)g_dev,
        (float*)(uintptr_t)m_dev,
        (float*)(uintptr_t)v_dev,
        lr, beta1, beta2, eps, wd, bc1, bc2, N);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

// ═════════════════════════════════════════════════════════════════════
// v5.6.6 — global L2 grad-norm + clip helpers (r12 NaN fix 2026-04-20).
//
//   ALM r12 M=512 real-corpus smoke explodes to NaN by step 10 once
//   warmup completes. Diagnosis: chained sgemm backward through 48
//   layers can produce dA/dB tensors with very large L2 (~1e3+) for a
//   handful of activation outliers; AdamW v_hat normalises per-element
//   but a single Inf grad poisons the entire downstream cascade.
//
//   Standard fix is global L2 grad clipping:
//     1. compute total = Σ_i ||g_i||²  across all 384 LoRA buffers
//     2. norm = sqrt(total) ; if norm > max_norm, scale = max_norm / norm
//     3. multiply every grad in-place by `scale`
//
//   Two device kernels:
//     v566_sumsq_kernel — block-strided fp32 reduction, atomic add into
//                          single-element accumulator (per-call zeroed).
//     v566_scale_kernel — element-wise dst[i] *= scale.
//
//   Hosts (extern "C" wrappers):
//     hxqwen14b_cu_launch_sumsq      — accumulate ||g||² of one buffer
//     hxqwen14b_cu_launch_scale_inplace — multiply one buffer by scale
//     hxqwen14b_cu_alloc_scalar_fp32 / free_scalar_fp32 — accumulator
//     hxqwen14b_cu_read_scalar_fp32  — d2h sync read of accumulator
//
//   The .c orchestrator iterates the 384 buffers twice: once for sum-sq
//   accumulate, once for scale (only if norm > max_norm). NaN/Inf in
//   any element → norm becomes NaN → scale = max_norm / NaN = NaN; the
//   .c orchestrator detects this and treats the step as a "skip" (no
//   scale, no AdamW; AdamW NaN-guard above handles in-flight NaNs as a
//   final safety net).
// ═════════════════════════════════════════════════════════════════════
__global__ void v566_sumsq_kernel(
    const float* __restrict__ g,
    float* __restrict__ acc,    // single fp32, atomicAdd target
    int64_t N
) {
    extern __shared__ float s_data[];
    int tid = threadIdx.x;
    int64_t i = (int64_t)blockIdx.x * blockDim.x + tid;

    float local = 0.0f;
    if (i < N) {
        float v = g[i];
        // NaN-tolerant accumulation: NaN²=NaN poisons sum, but caller
        // can detect via final isnan(norm). Inf² overflows to Inf.
        local = v * v;
    }
    s_data[tid] = local;
    __syncthreads();

    for (int s = blockDim.x >> 1; s > 0; s >>= 1) {
        if (tid < s) s_data[tid] += s_data[tid + s];
        __syncthreads();
    }

    if (tid == 0 && s_data[0] != 0.0f) {
        atomicAdd(acc, s_data[0]);
    }
}

extern "C" int hxqwen14b_cu_launch_sumsq(
    int64_t g_dev, int64_t acc_dev, int64_t N
) {
    if (g_dev == 0 || acc_dev == 0 || N <= 0) return HXQ_RC_KERNEL_FAIL;
    int threads = 256;
    unsigned blocks = (unsigned)((N + threads - 1) / threads);
    size_t shmem = (size_t)threads * sizeof(float);
    v566_sumsq_kernel<<<blocks, threads, shmem>>>(
        (const float*)(uintptr_t)g_dev,
        (float*)(uintptr_t)acc_dev, N);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

__global__ void v566_scale_kernel(
    float* __restrict__ dst, float scale, int64_t N
) {
    int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;
    dst[i] = dst[i] * scale;
}

extern "C" int hxqwen14b_cu_launch_scale_inplace(
    int64_t dst_dev, int64_t N, float scale
) {
    if (dst_dev == 0 || N <= 0) return HXQ_RC_KERNEL_FAIL;
    int threads = 256;
    unsigned blocks = (unsigned)((N + threads - 1) / threads);
    v566_scale_kernel<<<blocks, threads>>>(
        (float*)(uintptr_t)dst_dev, scale, N);
    return (cudaGetLastError() == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

extern "C" int64_t hxqwen14b_cu_alloc_scalar_fp32(void) {  // r12 fix scratch
    void* p = NULL;
    cudaError_t e = cudaMalloc(&p, sizeof(float));
    if (e != cudaSuccess) return 0;
    cudaMemsetAsync(p, 0, sizeof(float), 0);
    return (int64_t)(uintptr_t)p;
}

extern "C" int hxqwen14b_cu_zero_scalar_fp32(int64_t scalar_dev) {
    if (scalar_dev == 0) return HXQ_RC_KERNEL_FAIL;
    cudaError_t e = cudaMemsetAsync((void*)(uintptr_t)scalar_dev, 0, sizeof(float), 0);
    return (e == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

extern "C" double hxqwen14b_cu_read_scalar_fp32(int64_t scalar_dev) {
    if (scalar_dev == 0) return 0.0;
    cudaDeviceSynchronize();
    float v = 0.0f;
    cudaError_t e = cudaMemcpy(&v, (void*)(uintptr_t)scalar_dev,
                                sizeof(float), cudaMemcpyDeviceToHost);
    if (e != cudaSuccess) return 0.0;
    return (double)v;
}

extern "C" int hxqwen14b_cu_free_scalar_fp32(int64_t scalar_dev) {
    if (scalar_dev == 0) return HXQ_RC_OK;
    cudaError_t e = cudaFree((void*)(uintptr_t)scalar_dev);
    return (e == cudaSuccess) ? HXQ_RC_OK : HXQ_RC_KERNEL_FAIL;
}

}  // extern "C" (closes the v5.4 block opened at line 466; v5.6.3 bwd kernels + v5.6.5 helpers + adamw + v5.6.6 grad-clip added inside)
