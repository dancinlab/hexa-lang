// probe_fp16_rate.cu — measure raw mma.sync throughput on sm_120 for:
//   (a) TF32 m16n8k8 .f32.tf32.tf32.f32   (the path own-GEMM uses today)
//   (b) FP16  m16n8k16 .f32.f16.f16.f32   (the full-rate FP16-accum path that
//       Ootomo-Yokota error-correction emulation would run 2-3x of)
// Pure ALU microbench: a warp loops N MMAs over register fragments (no smem/gmem),
// so we isolate the tensor-core issue rate. Reports synthetic TFLOP/s for each so
// we can see the FP16/TF32 ratio — this is the premise of Round B (FP16-accum must
// be >~1.5x TF32-accum for 2-pass emulation to win).
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cuda_runtime.h>
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)

template<int ITER>
__global__ void bench_tf32(float* out){
    unsigned a0=1,a1=2,a2=3,a3=4,b0=5,b1=6;
    float d0=0,d1=0,d2=0,d3=0;
    #pragma unroll 8
    for(int i=0;i<ITER;i++){
        asm volatile("mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32 "
          "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
          :"+f"(d0),"+f"(d1),"+f"(d2),"+f"(d3)
          :"r"(a0),"r"(a1),"r"(a2),"r"(a3),"r"(b0),"r"(b1));
        a0^=__float_as_uint(d0); // dep chain to stop DCE
    }
    if(threadIdx.x==0xffff) out[0]=d0+d1+d2+d3;
}
template<int ITER>
__global__ void bench_fp16(float* out){
    unsigned a0=0x3c003c00,a1=0x3c003c00,a2=0x3c003c00,a3=0x3c003c00; // four .f16x2
    unsigned b0=0x3c003c00,b1=0x3c003c00;
    float d0=0,d1=0,d2=0,d3=0;
    #pragma unroll 8
    for(int i=0;i<ITER;i++){
        asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 "
          "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
          :"+f"(d0),"+f"(d1),"+f"(d2),"+f"(d3)
          :"r"(a0),"r"(a1),"r"(a2),"r"(a3),"r"(b0),"r"(b1));
        a0^=__float_as_uint(d0);
    }
    if(threadIdx.x==0xffff) out[0]=d0+d1+d2+d3;
}

int main(){
    const int ITER=200000;
    int blocks=1024, tpb=256; // many warps to saturate
    float* d; CK(cudaMalloc(&d,4));
    cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);

    // warm
    bench_tf32<1000><<<blocks,tpb>>>(d); CK(cudaDeviceSynchronize());
    cudaEventRecord(t0); bench_tf32<ITER><<<blocks,tpb>>>(d); cudaEventRecord(t1);
    CK(cudaEventSynchronize(t1)); float ms_tf; cudaEventElapsedTime(&ms_tf,t0,t1);
    // each m16n8k8 mma = 2*16*8*8 flops, per warp; warps = blocks*tpb/32
    double warps=(double)blocks*tpb/32.0;
    double tf_flops=2.0*16*8*8*(double)ITER*warps;
    double tf_tflops=tf_flops/(ms_tf*1e-3)/1e12;

    bench_fp16<1000><<<blocks,tpb>>>(d); CK(cudaDeviceSynchronize());
    cudaEventRecord(t0); bench_fp16<ITER><<<blocks,tpb>>>(d); cudaEventRecord(t1);
    CK(cudaEventSynchronize(t1)); float ms_h; cudaEventElapsedTime(&ms_h,t0,t1);
    double h_flops=2.0*16*8*16*(double)ITER*warps; // k16
    double h_tflops=h_flops/(ms_h*1e-3)/1e12;

    printf("[RATE] TF32 m16n8k8  = %.1f TFLOP/s (%.2f ms)\n", tf_tflops, ms_tf);
    printf("[RATE] FP16 m16n8k16 = %.1f TFLOP/s (%.2f ms)\n", h_tflops, ms_h);
    printf("[RATE] FP16/TF32 issue-rate ratio = %.3fx  (2-pass emul needs >~1.5x to win, 3-pass >~2.2x)\n",
           h_tflops/tf_tflops);
    return 0;
}
