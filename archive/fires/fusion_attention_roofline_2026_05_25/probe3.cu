#include <cuda_runtime.h>
#include <stdint.h>
#include <cuda_fp16.h>
#include <stdio.h>
#include <math.h>
__device__ uint32_t s2u(const void*p){ return (uint32_t)__cvta_generic_to_shared(p); }
/* O = P.V (contraction keys, V stored [keys x d] row-major). non-trans mma
 * computes A.Bop^T (k along Bop columns). For P.V we need Bop^T=V => Bop=V^T.
 * We pre-transpose V into smem (sVt[d x keys]) and feed it with non-trans, just
 * like K in QK^T. That GUARANTEES correctness using the proven non-trans path. */
__global__ void probe(const __half* P, const __half* V, float* C){
    __shared__ __half sP[256], sVt[256];
    int t=threadIdx.x;
    for(int i=t;i<256;i+=32) sP[i]=P[i];
    /* transpose V[k][n] -> sVt[n][k] */
    for(int i=t;i<256;i+=32){ int k=i/16,n=i%16; sVt[n*16+k]=V[k*16+n]; }
    __syncthreads();
    int lane=t,r15=lane&15,chalf=(lane>>4)*8;
    uint32_t aA=s2u(sP)+r15*32+chalf*2;
    uint32_t bB=s2u(sVt)+r15*32+chalf*2;
    uint32_t ra[4],rb[4];
    asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3},[%4];":"=r"(ra[0]),"=r"(ra[1]),"=r"(ra[2]),"=r"(ra[3]):"r"(aA));
    asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3},[%4];":"=r"(rb[0]),"=r"(rb[1]),"=r"(rb[2]),"=r"(rb[3]):"r"(bB));
    float c0[4]={0},c1[4]={0};
    asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 {%0,%1,%2,%3},{%4,%5,%6,%7},{%8,%9},{%0,%1,%2,%3};":"+f"(c0[0]),"+f"(c0[1]),"+f"(c0[2]),"+f"(c0[3]):"r"(ra[0]),"r"(ra[1]),"r"(ra[2]),"r"(ra[3]),"r"(rb[0]),"r"(rb[2]));
    asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 {%0,%1,%2,%3},{%4,%5,%6,%7},{%8,%9},{%0,%1,%2,%3};":"+f"(c1[0]),"+f"(c1[1]),"+f"(c1[2]),"+f"(c1[3]):"r"(ra[0]),"r"(ra[1]),"r"(ra[2]),"r"(ra[3]),"r"(rb[1]),"r"(rb[3]));
    int r2=lane>>2,c2=(lane&3)*2;
    C[r2*16+c2]=c0[0];C[r2*16+c2+1]=c0[1];C[(r2+8)*16+c2]=c0[2];C[(r2+8)*16+c2+1]=c0[3];
    C[r2*16+8+c2]=c1[0];C[r2*16+8+c2+1]=c1[1];C[(r2+8)*16+8+c2]=c1[2];C[(r2+8)*16+8+c2+1]=c1[3];
}
int main(){
    __half hP[256],hV[256]; float hC[256];
    for(int i=0;i<256;++i){hP[i]=__float2half(((i*7)%13)*0.1f-0.6f);hV[i]=__float2half(((i*5)%11)*0.1f-0.5f);}
    double ref[256];
    for(int m=0;m<16;++m)for(int n=0;n<16;++n){double s=0;for(int k=0;k<16;++k)s+=(double)__half2float(hP[m*16+k])*__half2float(hV[k*16+n]);ref[m*16+n]=s;}
    __half*dP,*dV; float*dC; cudaMalloc(&dP,512);cudaMalloc(&dV,512);cudaMalloc(&dC,1024);
    cudaMemcpy(dP,hP,512,cudaMemcpyHostToDevice);cudaMemcpy(dV,hV,512,cudaMemcpyHostToDevice);
    probe<<<1,32>>>(dP,dV,dC); cudaDeviceSynchronize(); cudaMemcpy(hC,dC,1024,cudaMemcpyDeviceToHost);
    double e=0; for(int i=0;i<256;++i){double a=fabs(hC[i]-ref[i]);if(a>e)e=a;}
    printf("P.V via V-pretranspose + non-trans: err=%.4g %s\n",e,e<1e-2?"<== MATCH":"MISMATCH");
    return 0;
}
