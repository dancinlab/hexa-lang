// hxqwen14b_p1d_driver.cu — Phase 1d LoRA fwd+bwd correctness driver.
//
// Drives hxqwen14b_lora_fwd_single + hxqwen14b_lora_bwd_single on DEVICE
// (is_device=1) with small random FP32 inputs, then dumps y, dA, dB, dx to
// a binary file. Run twice — once with HEXA_OWN_GEMM unset (cuBLAS oracle),
// once with HEXA_OWN_GEMM=1 (our _hx_k_sgemm_cm) — and diff the dumps.
//
// Build (on the H100 pod):
//   nvcc -O3 -arch=compute_90 -DHXQWEN14B_CUDA -c hxqwen14b_cuda.cu -o cu.o
//   gcc  -O3 -DHXQWEN14B_CUDA -I$CUDA/include -c hxqwen14b.c -o host.o
//   nvcc -O3 -arch=compute_90 -DHXQWEN14B_CUDA hxqwen14b_p1d_driver.cu \
//        host.o cu.o lora_cuda*.o -lcuda -lcudart -lcublas -lm -o p1d_driver
//
// Usage:  ./p1d_driver <out.bin>
//   The struct layouts MUST match hxqwen14b.c exactly (kept in sync here).

#include <cuda_runtime.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

extern "C" {
typedef struct HxQwenLoraFwdArgs {
    int64_t M_rows, N_out, K_in, R_lora;
    int64_t x_p, A_p, B_p, y_p;
    double  alpha_over_r;
    int64_t tmp_p, accumulate, is_device, reserved0, reserved1;
} HxQwenLoraFwdArgs;

typedef struct HxQwenLoraBwdArgs {
    int64_t M_rows, N_out, K_in, R_lora;
    int64_t x_p, A_p, B_p, dy_p, dA_p, dB_p, dx_p;
    double  alpha_over_r;
    int64_t u_p, tmp_p, accumulate_grads, is_device, reserved0, reserved1;
} HxQwenLoraBwdArgs;

int hxqwen14b_lora_fwd_single(void* args);
int hxqwen14b_lora_bwd_single(void* args);
}

static int64_t dmalloc(size_t n_floats) {
    void* p = NULL;
    if (cudaMalloc(&p, n_floats * sizeof(float)) != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed (%zu floats)\n", n_floats); exit(2);
    }
    return (int64_t)(uintptr_t)p;
}
static void h2d(int64_t dev, const float* host, size_t n) {
    if (cudaMemcpy((void*)(uintptr_t)dev, host, n*sizeof(float),
                   cudaMemcpyHostToDevice) != cudaSuccess) { fprintf(stderr,"h2d fail\n"); exit(2); }
}
static void d2h(float* host, int64_t dev, size_t n) {
    if (cudaMemcpy(host, (void*)(uintptr_t)dev, n*sizeof(float),
                   cudaMemcpyDeviceToHost) != cudaSuccess) { fprintf(stderr,"d2h fail\n"); exit(2); }
}

int main(int argc, char** argv) {
    const char* out = (argc > 1) ? argv[1] : "p1d_out.bin";

    // Deterministic problem; env-overridable for a GEMM-bound timing sweep.
    const int64_t M = getenv("P1D_M") ? atoll(getenv("P1D_M")) : 64;    // rows/tokens
    const int64_t N = getenv("P1D_N") ? atoll(getenv("P1D_N")) : 96;    // out features
    const int64_t K = getenv("P1D_K") ? atoll(getenv("P1D_K")) : 80;    // in features
    const int64_t R = getenv("P1D_R") ? atoll(getenv("P1D_R")) : 8;     // LoRA rank
    const double  s = 2.0 / (double)R;   // alpha/r

    srand(12345);
    auto fill = [](float* p, int64_t n){ for (int64_t i=0;i<n;i++) p[i] = (float)((rand()%2000)-1000)/1000.0f; };

    float* hx  = (float*)malloc(M*K*sizeof(float));
    float* hA  = (float*)malloc(R*K*sizeof(float));
    float* hB  = (float*)malloc(N*R*sizeof(float));
    float* hdy = (float*)malloc(M*N*sizeof(float));
    fill(hx, M*K); fill(hA, R*K); fill(hB, N*R); fill(hdy, M*N);

    int64_t dx_in = dmalloc(M*K), dA = dmalloc(R*K), dB = dmalloc(N*R);
    int64_t dy_out = dmalloc(M*N), dtmp = dmalloc(M*R);
    int64_t ddy = dmalloc(M*N), ddA = dmalloc(R*K), ddB = dmalloc(N*R);
    int64_t ddx = dmalloc(M*K), du = dmalloc(M*R);

    h2d(dx_in, hx, M*K); h2d(dA, hA, R*K); h2d(dB, hB, N*R); h2d(ddy, hdy, M*N);
    cudaMemset((void*)(uintptr_t)ddA, 0, R*K*sizeof(float));
    cudaMemset((void*)(uintptr_t)ddB, 0, N*R*sizeof(float));
    cudaMemset((void*)(uintptr_t)ddx, 0, M*K*sizeof(float));

    // ── forward: y = s · (x·Aᵀ)·Bᵀ ──
    HxQwenLoraFwdArgs fwd; memset(&fwd,0,sizeof(fwd));
    fwd.M_rows=M; fwd.N_out=N; fwd.K_in=K; fwd.R_lora=R;
    fwd.x_p=dx_in; fwd.A_p=dA; fwd.B_p=dB; fwd.y_p=dy_out;
    fwd.alpha_over_r=s; fwd.tmp_p=dtmp; fwd.accumulate=0; fwd.is_device=1;
    int rc_f = hxqwen14b_lora_fwd_single(&fwd);
    if (rc_f != 0) { fprintf(stderr,"fwd rc=%d\n", rc_f); return 3; }

    // ── backward: dA, dB, dx (+ u, tmp scratch) ──
    HxQwenLoraBwdArgs bwd; memset(&bwd,0,sizeof(bwd));
    bwd.M_rows=M; bwd.N_out=N; bwd.K_in=K; bwd.R_lora=R;
    bwd.x_p=dx_in; bwd.A_p=dA; bwd.B_p=dB; bwd.dy_p=ddy;
    bwd.dA_p=ddA; bwd.dB_p=ddB; bwd.dx_p=ddx;
    bwd.alpha_over_r=s; bwd.u_p=du; bwd.tmp_p=dtmp;
    bwd.accumulate_grads=0; bwd.is_device=1;
    int rc_b = hxqwen14b_lora_bwd_single(&bwd);
    if (rc_b != 0) { fprintf(stderr,"bwd rc=%d\n", rc_b); return 3; }

    cudaDeviceSynchronize();

    // Optional in-process timed loop (CUDA events) to surface the GEMM-time
    // ratio own-vs-cuBLAS without process/cudaInit overhead. P1D_ITERS>0.
    const char* iters_s = getenv("P1D_ITERS");
    int iters = iters_s ? atoi(iters_s) : 0;
    if (iters > 0) {
        cudaEvent_t e0, e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
        // warm
        hxqwen14b_lora_fwd_single(&fwd); hxqwen14b_lora_bwd_single(&bwd);
        cudaDeviceSynchronize();
        cudaEventRecord(e0);
        for (int it=0; it<iters; it++) {
            hxqwen14b_lora_fwd_single(&fwd);
            hxqwen14b_lora_bwd_single(&bwd);
        }
        cudaEventRecord(e1); cudaEventSynchronize(e1);
        float ms=0; cudaEventElapsedTime(&ms, e0, e1);
        fprintf(stderr,"[driver] TIMED %d iters fwd+bwd: %.4f ms total, %.5f ms/iter\n",
                iters, ms, ms/iters);
    }

    float* hy  = (float*)malloc(M*N*sizeof(float));
    float* hdA = (float*)malloc(R*K*sizeof(float));
    float* hdB = (float*)malloc(N*R*sizeof(float));
    float* hdx = (float*)malloc(M*K*sizeof(float));
    d2h(hy, dy_out, M*N); d2h(hdA, ddA, R*K); d2h(hdB, ddB, N*R); d2h(hdx, ddx, M*K);

    // Dump: header (4 int64 sizes) then y, dA, dB, dx.
    FILE* f = fopen(out, "wb");
    if (!f) { fprintf(stderr,"fopen %s fail\n", out); return 4; }
    int64_t hdr[4] = { M*N, R*K, N*R, M*K };
    fwrite(hdr, sizeof(int64_t), 4, f);
    fwrite(hy,  sizeof(float), M*N, f);
    fwrite(hdA, sizeof(float), R*K, f);
    fwrite(hdB, sizeof(float), N*R, f);
    fwrite(hdx, sizeof(float), M*K, f);
    fclose(f);
    fprintf(stderr,"[driver] wrote %s (M=%lld N=%lld K=%lld R=%lld) fwd_rc=%d bwd_rc=%d\n",
            out, (long long)M,(long long)N,(long long)K,(long long)R, rc_f, rc_b);
    return 0;
}
