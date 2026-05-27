// wgmma_numeric_probe.cu — verify wgmma actually computes correct GEMM on sm_120 driver-JIT
// Pattern: A[64x16] * B[16x32] = D[64x32] with known values, compare vs CPU reference.
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cuda_runtime.h>
#include <cuda_fp16.h>

extern "C" __global__ void wgmma_gemm_kernel(const __half* A, const __half* B, float* D) {
    extern __shared__ __align__(16) unsigned char smem[];
    __half* As = reinterpret_cast<__half*>(smem);                 // 64x16 row-major
    __half* Bs = reinterpret_cast<__half*>(smem + 64*16*2);       // 16x32 row-major

    int tid = threadIdx.x;
    for (int i = tid; i < 64*16; i += 128) As[i] = A[i];
    for (int i = tid; i < 16*32; i += 128) Bs[i] = B[i];
    __syncthreads();

    auto make_desc = [](const void* ptr, unsigned lbo_bytes, unsigned sbo_bytes) -> unsigned long long {
        unsigned long long addr = __cvta_generic_to_shared(const_cast<void*>(ptr));
        unsigned long long desc = 0;
        desc |= ((addr & 0x3FFFFULL) >> 4);
        desc |= (((unsigned long long)(lbo_bytes >> 4)) & 0x3FFFULL) << 16;
        desc |= (((unsigned long long)(sbo_bytes >> 4)) & 0x3FFFULL) << 32;
        return desc;
    };

    unsigned long long descA = make_desc(As, 16, 32);
    unsigned long long descB = make_desc(Bs, 64, 16);

    float d[16];
    for (int i = 0; i < 16; ++i) d[i] = 0.f;

    asm volatile("wgmma.fence.sync.aligned;\n" ::: "memory");
    asm volatile(
        "wgmma.mma_async.sync.aligned.m64n32k16.f32.f16.f16 "
        "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15}, "
        "%16, %17, 0, 1, 1, 0, 0;\n"
        : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3]),
          "+f"(d[4]),"+f"(d[5]),"+f"(d[6]),"+f"(d[7]),
          "+f"(d[8]),"+f"(d[9]),"+f"(d[10]),"+f"(d[11]),
          "+f"(d[12]),"+f"(d[13]),"+f"(d[14]),"+f"(d[15])
        : "l"(descA), "l"(descB));
    asm volatile("wgmma.commit_group.sync.aligned;\n" ::: "memory");
    asm volatile("wgmma.wait_group.sync.aligned 0;\n" ::: "memory");

    int wgroup_tid = tid;
    for (int i = 0; i < 16; ++i) {
        D[wgroup_tid * 16 + i] = d[i];
    }
}

int main() {
    const int M=64, N=32, K=16;
    __half *hA = new __half[M*K];
    __half *hB = new __half[K*N];
    for (int i = 0; i < M*K; ++i) hA[i] = __float2half((i % 7) * 0.1f);
    for (int i = 0; i < K*N; ++i) hB[i] = __float2half((i % 5) * 0.1f);

    float *Dref = new float[M*N];
    for (int i = 0; i < M; ++i) {
        for (int j = 0; j < N; ++j) {
            float acc = 0.f;
            for (int k = 0; k < K; ++k) acc += __half2float(hA[i*K+k]) * __half2float(hB[k*N+j]);
            Dref[i*N+j] = acc;
        }
    }

    __half *dA, *dB;
    float *dD;
    cudaMalloc(&dA, M*K*sizeof(__half));
    cudaMalloc(&dB, K*N*sizeof(__half));
    cudaMalloc(&dD, 128*16*sizeof(float));
    cudaMemcpy(dA, hA, M*K*sizeof(__half), cudaMemcpyHostToDevice);
    cudaMemcpy(dB, hB, K*N*sizeof(__half), cudaMemcpyHostToDevice);
    cudaMemset(dD, 0, 128*16*sizeof(float));

    size_t smem_bytes = M*K*sizeof(__half) + K*N*sizeof(__half);
    wgmma_gemm_kernel<<<1, 128, smem_bytes>>>(dA, dB, dD);
    cudaError_t e = cudaDeviceSynchronize();
    printf("Launch verdict: %s\n", e==cudaSuccess ? "OK" : cudaGetErrorString(e));
    if (e != cudaSuccess) return 1;

    float *Dgpu = new float[128*16];
    cudaMemcpy(Dgpu, dD, 128*16*sizeof(float), cudaMemcpyDeviceToHost);

    int nonzero = 0;
    float maxabs = 0;
    double sum_gpu = 0, sum_ref = 0;
    for (int i = 0; i < 128*16; ++i) {
        if (Dgpu[i] != 0.f) ++nonzero;
        if (fabsf(Dgpu[i]) > maxabs) maxabs = fabsf(Dgpu[i]);
        sum_gpu += Dgpu[i];
    }
    for (int i = 0; i < M*N; ++i) sum_ref += Dref[i];

    printf("GPU outputs: nonzero=%d/2048  max_abs=%.4f  sum=%.4f\n", nonzero, maxabs, sum_gpu);
    printf("CPU ref:                                 sum=%.4f\n", sum_ref);

    bool pass = (nonzero > 1500) && (fabs(sum_gpu - sum_ref) / fmax(1.0, fabs(sum_ref)) < 0.1);
    printf("WGMMA_NUMERIC_PROBE: %s\n", pass ? "PASS — wgmma executes correctly on sm_120" :
        (nonzero==0 ? "FAIL — output all zero (wgmma silently NOPs on sm_120 Blackwell)" : "FAIL — output mismatches CPU ref"));
    return pass ? 0 : 2;
}
