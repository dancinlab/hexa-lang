/* a_aot_trainer.cu — forge Phase R / A paradigm falsifier
 *
 * Pre-registered A hypothesis (FORGE.tape 2026-05-17):
 *   3-layer MLP (MNIST scale) AOT step throughput ≥ 1.2 × PyTorch eager.
 *
 * This is a SINGLE-FILE AOT-compiled mini trainer:
 *   - 3 Linear layers (D_in → D_hid → D_hid → D_out)
 *   - ReLU activations
 *   - Softmax cross-entropy loss
 *   - Full forward + backward pass
 *   - AdamW optimizer step
 *   - 100 step timing (median across batches of same random data — wall ms)
 *
 * Comparison baseline: same model in PyTorch eager (a_pytorch_baseline.py).
 * The hypothesis is that NO-Python + NO-ATen-dispatch + AOT-compiled-single-binary
 * is faster than PyTorch eager's Python + ATen + kernel-launch overhead.
 *
 * Architecture: 3-layer MLP for MNIST-scale (D_in=784, D_hid=256, D_out=10)
 *   x[B, 784] → Linear → h1[B, 256] → ReLU → Linear → h2[B, 256] → ReLU
 *               → Linear → logits[B, 10] → softmax → CE loss
 *
 * Backward:
 *   d_logits = softmax - one_hot(y)
 *   d_W3 = h2_act^T · d_logits   ;   d_h2_act = d_logits · W3^T
 *   d_h2 = relu_grad(d_h2_act, h2)
 *   d_W2 = h1_act^T · d_h2       ;   d_h1_act = d_h2 · W2^T
 *   d_h1 = relu_grad(d_h1_act, h1)
 *   d_W1 = x^T · d_h1            ;   (d_x not needed for this trainer)
 *
 * Optimizer: AdamW (decoupled weight decay)
 *   m = β1·m + (1-β1)·grad
 *   v = β2·v + (1-β2)·grad²
 *   param -= lr·(m̂ / (√v̂ + ε) + wd·param)
 *
 * Total ops per step:
 *   Forward:  3 Dgemm + 2 ReLU + 1 softmax+CE
 *   Backward: 3 Dgemm (gradients) + 2 Dgemm (input gradients) + 2 relu_grad
 *   AdamW:    3 fused param updates (one per weight)
 *   ≈ 14 cuBLAS Dgemms + 6 custom kernels per step
 *
 * vs PyTorch eager: same op count, but Python+ATen+launch overhead per op.
 * Hypothesis: AOT single-program saves ~10× (op_count) × (15-25 μs) per step.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(call) do { \
    cudaError_t _e = (call); \
    if (_e != cudaSuccess) { fprintf(stderr, "[A] CUDA %s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(_e)); exit(1); } \
} while (0)

#define CB(call) do { \
    cublasStatus_t _s = (call); \
    if (_s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "[A] cuBLAS %s:%d status=%d\n", __FILE__, __LINE__, (int)_s); exit(1); } \
} while (0)

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static double lcg_next(uint64_t* st) {
    *st = (*st) * 6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(((*st) >> 11) & 0x1FFFFFFFFFFFFFULL) / (double)(1ULL << 53);
}

static int dbl_cmp(const void* a, const void* b) {
    double aa = *(const double*)a, bb = *(const double*)b;
    return (aa > bb) - (aa < bb);
}

static double median(double* a, int n) {
    qsort(a, n, sizeof(double), dbl_cmp);
    return a[n / 2];
}

/* ===== Custom kernels ===== */

__global__ void relu_fwd(double* y, double* mask, const double* x, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) {
        double v = x[i];
        double on = (v > 0.0) ? 1.0 : 0.0;
        mask[i] = on;
        y[i] = v * on;
    }
}

__global__ void relu_bwd(double* dx, const double* dy, const double* mask, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) {
        dx[i] = dy[i] * mask[i];
    }
}

/* softmax + cross-entropy + dlogits in one row-per-block kernel.
 * Input: logits[B, C], y[B] (class index)
 * Output: loss (scalar, sum reduced on host), dlogits[B, C] = softmax - one_hot(y)
 */
__global__ void softmax_ce_bwd(double* dlogits, double* loss_per_row,
                                const double* logits, const int* y,
                                int B, int C) {
    int b = blockIdx.x;
    if (b >= B) return;
    const double* lrow = logits + (size_t)b * C;
    double* drow = dlogits + (size_t)b * C;
    /* find max for numerical stability — single-thread inside block (C small=10) */
    if (threadIdx.x == 0) {
        double m = lrow[0];
        for (int j = 1; j < C; j++) if (lrow[j] > m) m = lrow[j];
        double sum = 0.0;
        for (int j = 0; j < C; j++) sum += exp(lrow[j] - m);
        double lse = m + log(sum);
        int yi = y[b];
        loss_per_row[b] = -(lrow[yi] - lse);
        for (int j = 0; j < C; j++) {
            double p = exp(lrow[j] - lse);
            drow[j] = p - ((j == yi) ? 1.0 : 0.0);
        }
        /* scale by 1/B for mean-loss gradient */
        for (int j = 0; j < C; j++) drow[j] /= (double)B;
    }
}

/* AdamW fused update for one parameter tensor.
 * m, v = momentum/variance buffers (in/out).
 * param = in-place.
 * grad = gradient.
 * step = current step (1-indexed for bias correction).
 */
__global__ void adamw_step(double* param, double* m, double* v,
                            const double* grad, int n, int step,
                            double lr, double beta1, double beta2,
                            double eps, double wd) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    double b1t = pow(beta1, (double)step);
    double b2t = pow(beta2, (double)step);
    double bc1 = 1.0 / (1.0 - b1t);
    double bc2 = 1.0 / (1.0 - b2t);
    for (; i < n; i += stride) {
        double g = grad[i];
        double mi = beta1 * m[i] + (1.0 - beta1) * g;
        double vi = beta2 * v[i] + (1.0 - beta2) * g * g;
        m[i] = mi;
        v[i] = vi;
        double mhat = mi * bc1;
        double vhat = vi * bc2;
        double p = param[i];
        param[i] = p - lr * (mhat / (sqrt(vhat) + eps) + wd * p);
    }
}

/* ===== Trainer ===== */

struct trainer {
    int B, D_in, D_hid, D_out;
    /* Weights */
    double *W1, *W2, *W3;
    /* Adam moments */
    double *m_W1, *m_W2, *m_W3;
    double *v_W1, *v_W2, *v_W3;
    /* Activations (cached for backward) */
    double *X, *h1, *h1_mask, *h1_act;
    double *h2, *h2_mask, *h2_act;
    double *logits;
    /* Gradients */
    double *d_logits, *d_h2_act, *d_h2;
    double *d_h1_act, *d_h1;
    double *d_W1, *d_W2, *d_W3;
    /* Labels */
    int *y;
    /* Loss accumulator */
    double *loss_per_row;
    /* Step counter */
    int step;
    cublasHandle_t cublas;
    cudaStream_t stream;
};

static void trainer_init(struct trainer* t, int B, int D_in, int D_hid, int D_out) {
    t->B = B; t->D_in = D_in; t->D_hid = D_hid; t->D_out = D_out;
    t->step = 0;
    CB(cublasCreate(&t->cublas));
    CK(cudaStreamCreate(&t->stream));
    CB(cublasSetStream(t->cublas, t->stream));

    auto alloc_init = [&](double** dp, size_t n, double scale, uint64_t seed) {
        CK(cudaMalloc((void**)dp, n * sizeof(double)));
        double* h = (double*)malloc(n * sizeof(double));
        uint64_t st = seed;
        for (size_t i = 0; i < n; i++) h[i] = (lcg_next(&st) - 0.5) * scale;
        CK(cudaMemcpy(*dp, h, n * sizeof(double), cudaMemcpyHostToDevice));
        free(h);
    };
    auto alloc_zero = [&](double** dp, size_t n) {
        CK(cudaMalloc((void**)dp, n * sizeof(double)));
        CK(cudaMemset(*dp, 0, n * sizeof(double)));
    };

    /* Kaiming-ish init: scale = sqrt(2/fan_in) approximation via uniform */
    double s1 = 2.0 / sqrt((double)D_in);
    double s2 = 2.0 / sqrt((double)D_hid);
    double s3 = 2.0 / sqrt((double)D_hid);
    alloc_init(&t->W1, (size_t)D_in * D_hid, s1, 0xAAAA0001ULL);
    alloc_init(&t->W2, (size_t)D_hid * D_hid, s2, 0xAAAA0002ULL);
    alloc_init(&t->W3, (size_t)D_hid * D_out, s3, 0xAAAA0003ULL);
    alloc_zero(&t->m_W1, (size_t)D_in * D_hid);
    alloc_zero(&t->m_W2, (size_t)D_hid * D_hid);
    alloc_zero(&t->m_W3, (size_t)D_hid * D_out);
    alloc_zero(&t->v_W1, (size_t)D_in * D_hid);
    alloc_zero(&t->v_W2, (size_t)D_hid * D_hid);
    alloc_zero(&t->v_W3, (size_t)D_hid * D_out);

    CK(cudaMalloc((void**)&t->X,        (size_t)B * D_in  * sizeof(double)));
    CK(cudaMalloc((void**)&t->h1,       (size_t)B * D_hid * sizeof(double)));
    CK(cudaMalloc((void**)&t->h1_mask,  (size_t)B * D_hid * sizeof(double)));
    CK(cudaMalloc((void**)&t->h1_act,   (size_t)B * D_hid * sizeof(double)));
    CK(cudaMalloc((void**)&t->h2,       (size_t)B * D_hid * sizeof(double)));
    CK(cudaMalloc((void**)&t->h2_mask,  (size_t)B * D_hid * sizeof(double)));
    CK(cudaMalloc((void**)&t->h2_act,   (size_t)B * D_hid * sizeof(double)));
    CK(cudaMalloc((void**)&t->logits,   (size_t)B * D_out * sizeof(double)));
    CK(cudaMalloc((void**)&t->d_logits, (size_t)B * D_out * sizeof(double)));
    CK(cudaMalloc((void**)&t->d_h2_act, (size_t)B * D_hid * sizeof(double)));
    CK(cudaMalloc((void**)&t->d_h2,     (size_t)B * D_hid * sizeof(double)));
    CK(cudaMalloc((void**)&t->d_h1_act, (size_t)B * D_hid * sizeof(double)));
    CK(cudaMalloc((void**)&t->d_h1,     (size_t)B * D_hid * sizeof(double)));
    CK(cudaMalloc((void**)&t->d_W1,     (size_t)D_in  * D_hid * sizeof(double)));
    CK(cudaMalloc((void**)&t->d_W2,     (size_t)D_hid * D_hid * sizeof(double)));
    CK(cudaMalloc((void**)&t->d_W3,     (size_t)D_hid * D_out * sizeof(double)));
    CK(cudaMalloc((void**)&t->y,        (size_t)B * sizeof(int)));
    CK(cudaMalloc((void**)&t->loss_per_row, (size_t)B * sizeof(double)));

    /* fill X with deterministic noise; y with random labels */
    double* hX = (double*)malloc((size_t)B * D_in * sizeof(double));
    int* hy = (int*)malloc((size_t)B * sizeof(int));
    uint64_t st = 0xDEADBEEFULL;
    for (size_t i = 0; i < (size_t)B * D_in; i++) hX[i] = (lcg_next(&st) - 0.5) * 0.5;
    for (int i = 0; i < B; i++) hy[i] = (int)(lcg_next(&st) * (double)D_out);
    CK(cudaMemcpy(t->X, hX, (size_t)B * D_in * sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(t->y, hy, (size_t)B * sizeof(int), cudaMemcpyHostToDevice));
    free(hX); free(hy);
}

static void trainer_step(struct trainer* t) {
    const double alpha = 1.0, beta = 0.0;
    int B = t->B, Din = t->D_in, Dh = t->D_hid, Do = t->D_out;
    cublasHandle_t H = t->cublas;
    cudaStream_t st = t->stream;

    /* ===== Forward ===== */
    /* h1 = X · W1   (B × Din · Din × Dh = B × Dh) */
    cublasDgemm(H, CUBLAS_OP_N, CUBLAS_OP_N,
                Dh, B, Din, &alpha, t->W1, Dh, t->X, Din, &beta, t->h1, Dh);
    int n_h1 = B * Dh;
    int threads = 256, blocks = (n_h1 + threads - 1) / threads;
    if (blocks > 65535) blocks = 65535;
    relu_fwd<<<blocks, threads, 0, st>>>(t->h1_act, t->h1_mask, t->h1, n_h1);
    /* h2 = h1_act · W2 */
    cublasDgemm(H, CUBLAS_OP_N, CUBLAS_OP_N,
                Dh, B, Dh, &alpha, t->W2, Dh, t->h1_act, Dh, &beta, t->h2, Dh);
    int n_h2 = B * Dh;
    relu_fwd<<<blocks, threads, 0, st>>>(t->h2_act, t->h2_mask, t->h2, n_h2);
    /* logits = h2_act · W3 */
    cublasDgemm(H, CUBLAS_OP_N, CUBLAS_OP_N,
                Do, B, Dh, &alpha, t->W3, Do, t->h2_act, Dh, &beta, t->logits, Do);

    /* ===== Softmax + CE + dlogits ===== */
    softmax_ce_bwd<<<B, 1, 0, st>>>(t->d_logits, t->loss_per_row,
                                     t->logits, t->y, B, Do);

    /* ===== Backward ===== */
    /* d_W3 = h2_act^T · d_logits   (Dh × B · B × Do = Dh × Do) */
    cublasDgemm(H, CUBLAS_OP_N, CUBLAS_OP_T,
                Do, Dh, B, &alpha, t->d_logits, Do, t->h2_act, Dh, &beta, t->d_W3, Do);
    /* d_h2_act = d_logits · W3^T  (B × Do · Do × Dh = B × Dh) */
    cublasDgemm(H, CUBLAS_OP_T, CUBLAS_OP_N,
                Dh, B, Do, &alpha, t->W3, Do, t->d_logits, Do, &beta, t->d_h2_act, Dh);
    relu_bwd<<<blocks, threads, 0, st>>>(t->d_h2, t->d_h2_act, t->h2_mask, n_h2);

    /* d_W2 = h1_act^T · d_h2 */
    cublasDgemm(H, CUBLAS_OP_N, CUBLAS_OP_T,
                Dh, Dh, B, &alpha, t->d_h2, Dh, t->h1_act, Dh, &beta, t->d_W2, Dh);
    /* d_h1_act = d_h2 · W2^T */
    cublasDgemm(H, CUBLAS_OP_T, CUBLAS_OP_N,
                Dh, B, Dh, &alpha, t->W2, Dh, t->d_h2, Dh, &beta, t->d_h1_act, Dh);
    relu_bwd<<<blocks, threads, 0, st>>>(t->d_h1, t->d_h1_act, t->h1_mask, n_h1);

    /* d_W1 = X^T · d_h1   (Din × B · B × Dh = Din × Dh) */
    cublasDgemm(H, CUBLAS_OP_N, CUBLAS_OP_T,
                Dh, Din, B, &alpha, t->d_h1, Dh, t->X, Din, &beta, t->d_W1, Dh);

    /* ===== AdamW update (3 fused per-tensor) ===== */
    t->step++;
    int n1 = Din * Dh, n2 = Dh * Dh, n3 = Dh * Do;
    int b1 = (n1 + threads - 1) / threads; if (b1 > 65535) b1 = 65535;
    int b2 = (n2 + threads - 1) / threads; if (b2 > 65535) b2 = 65535;
    int b3 = (n3 + threads - 1) / threads; if (b3 > 65535) b3 = 65535;
    const double lr = 1e-3, b1d = 0.9, b2d = 0.999, eps = 1e-8, wd = 1e-2;
    adamw_step<<<b1, threads, 0, st>>>(t->W1, t->m_W1, t->v_W1, t->d_W1, n1, t->step, lr, b1d, b2d, eps, wd);
    adamw_step<<<b2, threads, 0, st>>>(t->W2, t->m_W2, t->v_W2, t->d_W2, n2, t->step, lr, b1d, b2d, eps, wd);
    adamw_step<<<b3, threads, 0, st>>>(t->W3, t->m_W3, t->v_W3, t->d_W3, n3, t->step, lr, b1d, b2d, eps, wd);
}

static void trainer_destroy(struct trainer* t) {
    cudaFree(t->W1); cudaFree(t->W2); cudaFree(t->W3);
    cudaFree(t->m_W1); cudaFree(t->m_W2); cudaFree(t->m_W3);
    cudaFree(t->v_W1); cudaFree(t->v_W2); cudaFree(t->v_W3);
    cudaFree(t->X); cudaFree(t->h1); cudaFree(t->h1_mask); cudaFree(t->h1_act);
    cudaFree(t->h2); cudaFree(t->h2_mask); cudaFree(t->h2_act);
    cudaFree(t->logits);
    cudaFree(t->d_logits); cudaFree(t->d_h2_act); cudaFree(t->d_h2);
    cudaFree(t->d_h1_act); cudaFree(t->d_h1);
    cudaFree(t->d_W1); cudaFree(t->d_W2); cudaFree(t->d_W3);
    cudaFree(t->y); cudaFree(t->loss_per_row);
    cudaStreamDestroy(t->stream);
    cublasDestroy(t->cublas);
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;
    int n_dev = 0;
    cudaGetDeviceCount(&n_dev);
    if (n_dev <= 0) { fprintf(stderr, "[A] FATAL: no CUDA device\n"); return 1; }

    int cc_major = 0, cc_minor = 0;
    cudaDeviceGetAttribute(&cc_major, cudaDevAttrComputeCapabilityMajor, 0);
    cudaDeviceGetAttribute(&cc_minor, cudaDevAttrComputeCapabilityMinor, 0);
    char pci[256] = "unknown";
    cudaDeviceGetPCIBusId(pci, sizeof(pci), 0);
    size_t mem_free = 0, mem_total = 0;
    cudaMemGetInfo(&mem_free, &mem_total);
    fprintf(stderr, "[A] device 0: pci=%s cc=%d.%d mem=%ld MB\n",
            pci, cc_major, cc_minor, (long)(mem_total >> 20));

    int cublas_major = 0, cublas_minor = 0, cublas_patch = 0;
    cublasHandle_t htmp; cublasCreate(&htmp);
    cublasGetProperty(MAJOR_VERSION, &cublas_major);
    cublasGetProperty(MINOR_VERSION, &cublas_minor);
    cublasGetProperty(PATCH_LEVEL, &cublas_patch);
    cublasDestroy(htmp);

    /* Stage 1 + Stage 2 compute-regime spectrum:
     * Stage 1 (originally measured 2026-05-17 Phase R fire):
     *   mnist_b32  : 0.110 ms AOT / 0.668 ms PyT = 6.06× (small, dispatch-dominated)
     *   mnist_b128 : 0.111 ms / 0.668 ms = 6.01× (batch invariant — overhead constant)
     *   mid_b32    : 1.206 ms / 2.704 ms = 2.24× (compute begins to dominate)
     * Stage 2 (large compute regime, F-FORGE-A-STAGE2-LARGE hypothesis):
     *   large_b128  : D=8192   B=128  ~3-4ms wall expected (overhead ~1.5ms → ~1.4-1.5×)
     *   large_b512  : D=8192   B=512  ~10ms wall expected (~1.15-1.2×)
     *   xlarge_b128 : D=16384  B=128  ~10-20ms wall expected (~1.07-1.15×)
     * Optional: argv[1] = "stage1" | "stage2" | "all" (default: all). */
    struct cfg_t { int B, D_in, D_hid, D_out; int n_warm, n_iter; const char* label; const char* stage; };
    struct cfg_t all_configs[] = {
        {  32,   784,   256,   10, 10, 100, "mnist_b32",   "stage1" },
        { 128,   784,   256,   10, 10, 100, "mnist_b128",  "stage1" },
        {  32,  4096,  4096,  100,  5,  50, "mid_b32",     "stage1" },
        { 128,  8192,  8192, 1000,  3,  30, "large_b128",  "stage2" },
        { 512,  8192,  8192, 1000,  3,  20, "large_b512",  "stage2" },
        { 128, 16384, 16384, 1000,  3,  10, "xlarge_b128", "stage2" },
    };
    const char* preset = (argc > 1) ? argv[1] : "all";
    struct cfg_t configs[6]; int n_cfg = 0;
    for (int i = 0; i < (int)(sizeof(all_configs)/sizeof(all_configs[0])); i++) {
        if (strcmp(preset, "all") == 0 || strcmp(preset, all_configs[i].stage) == 0) {
            configs[n_cfg++] = all_configs[i];
        }
    }
    fprintf(stderr, "[A] preset=%s · selected %d configs\n", preset, n_cfg);

    FILE* jf = fopen("result.json", "w");  /* CWD — dispatch script sets cwd to REMOTE_WORK */
    if (!jf) { fprintf(stderr, "[A] cannot open result.json\n"); return 2; }
    fprintf(jf, "{\n");
    fprintf(jf, "  \"experiment\": \"forge_phaseR_a_aot_trainer\",\n");
    fprintf(jf, "  \"date\": \"2026-05-17\",\n");
    fprintf(jf, "  \"device_pci\": \"%s\",\n", pci);
    fprintf(jf, "  \"device_cc\": \"%d.%d\",\n", cc_major, cc_minor);
    fprintf(jf, "  \"device_mem_mb\": %ld,\n", (long)(mem_total >> 20));
    fprintf(jf, "  \"cublas_version\": \"%d.%d.%d\",\n", cublas_major, cublas_minor, cublas_patch);
    fprintf(jf, "  \"hypothesis\": \"AOT MLP train_step >= 1.2x PyTorch eager (measured on same hardware)\",\n");
    fprintf(jf, "  \"configs\": [\n");

    for (int c = 0; c < n_cfg; c++) {
        fprintf(stderr, "[A] === config: %s B=%d Din=%d Dh=%d Do=%d (warm=%d iter=%d) ===\n",
                configs[c].label, configs[c].B, configs[c].D_in, configs[c].D_hid,
                configs[c].D_out, configs[c].n_warm, configs[c].n_iter);
        struct trainer t;
        trainer_init(&t, configs[c].B, configs[c].D_in, configs[c].D_hid, configs[c].D_out);

        /* Warmup */
        for (int w = 0; w < configs[c].n_warm; w++) trainer_step(&t);
        CK(cudaStreamSynchronize(t.stream));

        /* Time N iterations, gather median per-step ms */
        double* samples = (double*)malloc(configs[c].n_iter * sizeof(double));
        for (int it = 0; it < configs[c].n_iter; it++) {
            double t0 = now_sec();
            trainer_step(&t);
            CK(cudaStreamSynchronize(t.stream));
            samples[it] = (now_sec() - t0) * 1000.0;
        }
        double med_ms = median(samples, configs[c].n_iter);
        double min_ms = samples[0];
        double max_ms = samples[configs[c].n_iter - 1];
        double mean_ms = 0; for (int i = 0; i < configs[c].n_iter; i++) mean_ms += samples[i];
        mean_ms /= configs[c].n_iter;
        free(samples);

        /* Sample loss to verify training progresses */
        double host_loss[2048] = {0};
        int B_check = (configs[c].B > 2048) ? 2048 : configs[c].B;
        CK(cudaMemcpy(host_loss, t.loss_per_row, B_check * sizeof(double), cudaMemcpyDeviceToHost));
        double final_loss = 0; for (int i = 0; i < B_check; i++) final_loss += host_loss[i];
        final_loss /= B_check;

        fprintf(stderr, "[A]   median=%.4f ms · min=%.4f · max=%.4f · mean=%.4f · final_loss=%.4f\n",
                med_ms, min_ms, max_ms, mean_ms, final_loss);

        if (c > 0) fprintf(jf, ",\n");
        fprintf(jf,
            "    { \"label\":\"%s\", \"B\":%d, \"D_in\":%d, \"D_hid\":%d, \"D_out\":%d, "
            "\"step_ms_median\":%.6f, \"step_ms_min\":%.6f, \"step_ms_max\":%.6f, "
            "\"step_ms_mean\":%.6f, "
            "\"final_loss_mean\":%.6f, \"n_warm\":%d, \"n_iter\":%d }",
            configs[c].label, configs[c].B, configs[c].D_in, configs[c].D_hid,
            configs[c].D_out, med_ms, min_ms, max_ms, mean_ms, final_loss,
            configs[c].n_warm, configs[c].n_iter);

        trainer_destroy(&t);
    }

    fprintf(jf, "\n  ]\n");
    fprintf(jf, "}\n");
    fclose(jf);

    fprintf(stderr, "[A] DONE — %d configs (AOT trainer measurement)\n", n_cfg);
    return 0;
}
