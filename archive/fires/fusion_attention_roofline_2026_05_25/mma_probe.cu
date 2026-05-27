/* Minimal mma.m16n8k16 fragment-map probe. Computes C[16x16] = A[16x16].B[16x16]
 * via ldmatrix.x4 (A) + ldmatrix.x4 (B variants) + 4 mma.m16n8k16, dumps C, and
 * compares to a CPU 16x16x16 GEMM for several B-load strategies so we can read
 * off the correct trans/non-trans + B-half->n-col mapping empirically.
 *
 * A is row-major [16x16]. B is row-major [16x16] interpreted as B[k][n] (so the
 * GEMM is C[m][n] = sum_k A[m][k]*B[k][n]) -- this is the P.V case (contraction
 * along B's rows). We test ldmatrix non-trans for B.
 * Also test B as Bt[n][k] row-major (the QK^T case: contraction along B's cols),
 * loaded with ldmatrix.trans.
 *
 * Build: nvcc -O2 -arch=sm_90a -o mma_probe mma_probe.cu
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <stdio.h>
#include <math.h>

__device__ uint32_t s2u(const void*p){ return (uint32_t)__cvta_generic_to_shared(p); }

/* mode 0: P.V style. A[m][k] row-major, B[k][n] row-major, non-trans B.
 * mode 1: QK^T style. A[m][k] row-major, Bt[n][k] row-major, trans B. */
__global__ void probe(const __half* A, const __half* B, float* C, int mode){
    __shared__ __half sA[16*16];
    __shared__ __half sB[16*16];
    int t = threadIdx.x;
    for(int i=t;i<256;i+=32){ sA[i]=A[i]; sB[i]=B[i]; }
    __syncthreads();
    int lane=t;
    int r15=lane&15, chalf=(lane>>4)*8;
    uint32_t aA=s2u(sA)+r15*32+chalf*2;   /* 16x16 fp16, 32 B/row */
    uint32_t ra[4], rb[4];
    asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3},[%4];"
        :"=r"(ra[0]),"=r"(ra[1]),"=r"(ra[2]),"=r"(ra[3]):"r"(aA));
    uint32_t bB;
    if(mode==1){ /* trans: lane addresses Bt[n=r15][k=chalf] */
        bB=s2u(sB)+r15*32+chalf*2;
        asm volatile("ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16 {%0,%1,%2,%3},[%4];"
            :"=r"(rb[0]),"=r"(rb[1]),"=r"(rb[2]),"=r"(rb[3]):"r"(bB));
    } else { /* non-trans: lane addresses B[k=r15][n=chalf] */
        bB=s2u(sB)+r15*32+chalf*2;
        asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3},[%4];"
            :"=r"(rb[0]),"=r"(rb[1]),"=r"(rb[2]),"=r"(rb[3]):"r"(bB));
    }
    float c0[4]={0,0,0,0}, c1[4]={0,0,0,0};
    /* n-block 0 (cols 0-7): B halves rb[0],rb[2] ; n-block 1 (cols 8-15): rb[1],rb[3] */
    asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 {%0,%1,%2,%3},{%4,%5,%6,%7},{%8,%9},{%0,%1,%2,%3};"
        :"+f"(c0[0]),"+f"(c0[1]),"+f"(c0[2]),"+f"(c0[3]):"r"(ra[0]),"r"(ra[1]),"r"(ra[2]),"r"(ra[3]),"r"(rb[0]),"r"(rb[2]));
    asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 {%0,%1,%2,%3},{%4,%5,%6,%7},{%8,%9},{%0,%1,%2,%3};"
        :"+f"(c1[0]),"+f"(c1[1]),"+f"(c1[2]),"+f"(c1[3]):"r"(ra[0]),"r"(ra[1]),"r"(ra[2]),"r"(ra[3]),"r"(rb[1]),"r"(rb[3]));
    /* C-frag scatter: d0=(r=lane>>2,c=(lane&3)*2) d1=(+0,+1) d2=(r+8,c) d3=(r+8,c+1) */
    int r2=lane>>2, c2=(lane&3)*2;
    /* n-block 0 -> cols 0-7 */
    C[(r2)*16 + (0+c2+0)]=c0[0];
    C[(r2)*16 + (0+c2+1)]=c0[1];
    C[(r2+8)*16 + (0+c2+0)]=c0[2];
    C[(r2+8)*16 + (0+c2+1)]=c0[3];
    /* n-block 1 -> cols 8-15 */
    C[(r2)*16 + (8+c2+0)]=c1[0];
    C[(r2)*16 + (8+c2+1)]=c1[1];
    C[(r2+8)*16 + (8+c2+0)]=c1[2];
    C[(r2+8)*16 + (8+c2+1)]=c1[3];
}

int main(int argc,char**argv){
    int mode=(argc>1)?atoi(argv[1]):0;
    __half hA[256], hB[256]; float hC[256], ref[256];
    for(int i=0;i<256;++i){ hA[i]=__float2half(((i*7)%13)*0.1f-0.6f); hB[i]=__float2half(((i*5)%11)*0.1f-0.5f); }
    /* CPU ref */
    for(int m=0;m<16;++m)for(int n=0;n<16;++n){ double s=0;
        for(int k=0;k<16;++k){ float a=__half2float(hA[m*16+k]);
            float b = (mode==1)? __half2float(hB[n*16+k]) /* Bt[n][k] */ : __half2float(hB[k*16+n]); /* B[k][n] */
            s+=(double)a*(double)b; }
        ref[m*16+n]=(float)s; }
    __half *dA,*dB; float*dC;
    cudaMalloc(&dA,512); cudaMalloc(&dB,512); cudaMalloc(&dC,1024);
    cudaMemcpy(dA,hA,512,cudaMemcpyHostToDevice); cudaMemcpy(dB,hB,512,cudaMemcpyHostToDevice);
    probe<<<1,32>>>(dA,dB,dC,mode);
    cudaDeviceSynchronize();
    cudaMemcpy(hC,dC,1024,cudaMemcpyDeviceToHost);
    double maxe=0; for(int i=0;i<256;++i){ double e=fabs(hC[i]-ref[i]); if(e>maxe)maxe=e; }
    printf("mode=%d max_abs_err=%.6g %s\n",mode,maxe,(maxe<1e-2)?"MATCH":"MISMATCH");
    if(maxe>=1e-2){ printf("got[0..7]: "); for(int i=0;i<8;++i)printf("%.3f ",hC[i]); printf("\nref[0..7]: "); for(int i=0;i<8;++i)printf("%.3f ",ref[i]); printf("\n"); }
    return 0;
}
