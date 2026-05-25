#include <cuda_runtime.h>
#include <stdint.h>
#include <cuda_fp16.h>
#include <stdio.h>
#include <math.h>
__device__ uint32_t s2u(const void*p){ return (uint32_t)__cvta_generic_to_shared(p); }
/* trans flag controls ONLY the B ldmatrix. We dump C and compare to BOTH
 * possible contractions to identify what each (trans, A-layout) computes. */
__global__ void probe(const __half* A, const __half* B, float* C, int btrans){
    __shared__ __half sA[256], sB[256];
    int t=threadIdx.x; for(int i=t;i<256;i+=32){sA[i]=A[i];sB[i]=B[i];} __syncthreads();
    int lane=t, r15=lane&15, chalf=(lane>>4)*8;
    uint32_t aA=s2u(sA)+r15*32+chalf*2;
    uint32_t ra[4], rb[4];
    asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3},[%4];":"=r"(ra[0]),"=r"(ra[1]),"=r"(ra[2]),"=r"(ra[3]):"r"(aA));
    uint32_t bB=s2u(sB)+r15*32+chalf*2;
    if(btrans) asm volatile("ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16 {%0,%1,%2,%3},[%4];":"=r"(rb[0]),"=r"(rb[1]),"=r"(rb[2]),"=r"(rb[3]):"r"(bB));
    else asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3},[%4];":"=r"(rb[0]),"=r"(rb[1]),"=r"(rb[2]),"=r"(rb[3]):"r"(bB));
    float c0[4]={0},c1[4]={0};
    asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 {%0,%1,%2,%3},{%4,%5,%6,%7},{%8,%9},{%0,%1,%2,%3};":"+f"(c0[0]),"+f"(c0[1]),"+f"(c0[2]),"+f"(c0[3]):"r"(ra[0]),"r"(ra[1]),"r"(ra[2]),"r"(ra[3]),"r"(rb[0]),"r"(rb[2]));
    asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 {%0,%1,%2,%3},{%4,%5,%6,%7},{%8,%9},{%0,%1,%2,%3};":"+f"(c1[0]),"+f"(c1[1]),"+f"(c1[2]),"+f"(c1[3]):"r"(ra[0]),"r"(ra[1]),"r"(ra[2]),"r"(ra[3]),"r"(rb[1]),"r"(rb[3]));
    int r2=lane>>2,c2=(lane&3)*2;
    C[r2*16+c2]=c0[0]; C[r2*16+c2+1]=c0[1]; C[(r2+8)*16+c2]=c0[2]; C[(r2+8)*16+c2+1]=c0[3];
    C[r2*16+8+c2]=c1[0]; C[r2*16+8+c2+1]=c1[1]; C[(r2+8)*16+8+c2]=c1[2]; C[(r2+8)*16+8+c2+1]=c1[3];
}
int main(int argc,char**argv){
    int bt=(argc>1)?atoi(argv[1]):0;
    __half hA[256],hB[256]; float hC[256];
    for(int i=0;i<256;++i){hA[i]=__float2half(((i*7)%13)*0.1f-0.6f);hB[i]=__float2half(((i*5)%11)*0.1f-0.5f);}
    double refB[256], refBt[256]; /* refB: C=A.B (k along B rows); refBt: C=A.B^T (k along B cols) */
    for(int m=0;m<16;++m)for(int n=0;n<16;++n){ double sB=0,sBt=0;
        for(int k=0;k<16;++k){ float a=__half2float(hA[m*16+k]); sB+=(double)a*__half2float(hB[k*16+n]); sBt+=(double)a*__half2float(hB[n*16+k]); }
        refB[m*16+n]=sB; refBt[m*16+n]=sBt; }
    __half*dA,*dB; float*dC; cudaMalloc(&dA,512);cudaMalloc(&dB,512);cudaMalloc(&dC,1024);
    cudaMemcpy(dA,hA,512,cudaMemcpyHostToDevice);cudaMemcpy(dB,hB,512,cudaMemcpyHostToDevice);
    probe<<<1,32>>>(dA,dB,dC,bt); cudaDeviceSynchronize(); cudaMemcpy(hC,dC,1024,cudaMemcpyDeviceToHost);
    double eB=0,eBt=0; for(int i=0;i<256;++i){ double a=fabs(hC[i]-refB[i]),b=fabs(hC[i]-refBt[i]); if(a>eB)eB=a; if(b>eBt)eBt=b; }
    printf("btrans=%d  err_vs_A.B(k=Brows)=%.4g %s   err_vs_A.Bt(k=Bcols)=%.4g %s\n",bt,eB,eB<1e-2?"<==":"",eBt,eBt<1e-2?"<==":"");
    return 0;
}
