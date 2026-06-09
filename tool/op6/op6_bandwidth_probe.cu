/* OP-6 probe: is the AdamW fp64 kernel bandwidth-bound or fp64-ALU-bound on
 * the RTX 5070? Compare a pure copy (bandwidth ceiling) vs fp64 elementwise
 * vs fp32 elementwise, scalar vs vectorized. */
#include <cstdio>
#include <cstdint>
#include <cuda_runtime.h>
#define CK(x) do{cudaError_t e=(x); if(e){printf("err %s\n",cudaGetErrorString(e));return 1;}}while(0)
__global__ void copy_scalar(const double*__restrict__ a,double*__restrict__ b,int64_t n){
  int64_t s=(int64_t)blockDim.x*gridDim.x;
  for(int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;i<n;i+=s) b[i]=a[i]; }
__global__ void copy_vec(const double2*__restrict__ a,double2*__restrict__ b,int64_t np){
  int64_t s=(int64_t)blockDim.x*gridDim.x;
  for(int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;i<np;i+=s) b[i]=a[i]; }
/* fp32 adamw — genuinely bandwidth-bound (fp32 ALU is fast on 5070) */
__global__ void adamw32_scalar(float*__restrict__ W,float*__restrict__ M,float*__restrict__ V,
   const float*__restrict__ G,int64_t n,float lr,float b1,float b2,float eps,float wd,float c1,float c2){
  int64_t s=(int64_t)blockDim.x*gridDim.x;
  for(int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;i<n;i+=s){
    float g=G[i],mi=b1*M[i]+(1-b1)*g,vi=b2*V[i]+(1-b2)*g*g;
    float wi=W[i]-lr*wd*W[i]-lr*(mi/c1)/(sqrtf(vi/c2)+eps); M[i]=mi;V[i]=vi;W[i]=wi; } }
__global__ void adamw32_vec(float4*__restrict__ W4,float4*__restrict__ M4,float4*__restrict__ V4,
   const float4*__restrict__ G4,int64_t nq,float lr,float b1,float b2,float eps,float wd,float c1,float c2){
  int64_t s=(int64_t)blockDim.x*gridDim.x;
  for(int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;i<nq;i+=s){
    float4 w=W4[i],m=M4[i],v=V4[i],g=G4[i],wo,mo,vo;
    #define B(c) {float gg=g.c,mi=b1*m.c+(1-b1)*gg,vi=b2*v.c+(1-b2)*gg*gg; \
      wo.c=w.c-lr*wd*w.c-lr*(mi/c1)/(sqrtf(vi/c2)+eps);mo.c=mi;vo.c=vi;}
    B(x)B(y)B(z)B(w) M4[i]=mo;V4[i]=vo;W4[i]=wo; } }
double tk(cudaEvent_t a,cudaEvent_t b){float m;cudaEventElapsedTime(&m,a,b);return m;}
int main(){
  int64_t n=64LL*1024*1024; int it=50; int bl=256;
  int64_t wb=(n+bl-1)/bl; int g=wb>1024?1024:(int)wb;
  int64_t np=n/2; int64_t wp=(np+bl-1)/bl; int gp=wp>1024?1024:(int)wp;
  int64_t nq=n/4; int64_t wq=(nq+bl-1)/bl; int gq=wq>1024?1024:(int)wq;
  double *da,*db; CK(cudaMalloc(&da,n*8)); CK(cudaMalloc(&db,n*8));
  float *fW,*fM,*fV,*fG; CK(cudaMalloc(&fW,n*4));CK(cudaMalloc(&fM,n*4));CK(cudaMalloc(&fV,n*4));CK(cudaMalloc(&fG,n*4));
  cudaEvent_t e0,e1; cudaEventCreate(&e0);cudaEventCreate(&e1);
  auto bw=[&](double ms,double gb){return gb/(ms/1e3);};
  /* copy fp64 (2 streams) */
  copy_scalar<<<g,bl>>>(da,db,n);cudaDeviceSynchronize();
  cudaEventRecord(e0);for(int i=0;i<it;i++)copy_scalar<<<g,bl>>>(da,db,n);cudaEventRecord(e1);cudaEventSynchronize(e1);
  double cs=tk(e0,e1)/it;
  copy_vec<<<gp,bl>>>((double2*)da,(double2*)db,np);cudaDeviceSynchronize();
  cudaEventRecord(e0);for(int i=0;i<it;i++)copy_vec<<<gp,bl>>>((double2*)da,(double2*)db,np);cudaEventRecord(e1);cudaEventSynchronize(e1);
  double cv=tk(e0,e1)/it;
  printf("COPY fp64 (2 streams %.1fGB): scalar %.2fGB/s  vec(d2) %.2fGB/s  speedup %.3fx\n",
    2.0*n*8/1e9, bw(cs,2.0*n*8/1e9), bw(cv,2.0*n*8/1e9), cs/cv);
  /* adamw fp32 (7 streams) */
  float lr=1e-3f,b1=.9f,b2=.999f,eps=1e-8f,wd=.01f,c1=.65f,c2=.01f;
  adamw32_scalar<<<g,bl>>>(fW,fM,fV,fG,n,lr,b1,b2,eps,wd,c1,c2);cudaDeviceSynchronize();
  cudaEventRecord(e0);for(int i=0;i<it;i++)adamw32_scalar<<<g,bl>>>(fW,fM,fV,fG,n,lr,b1,b2,eps,wd,c1,c2);cudaEventRecord(e1);cudaEventSynchronize(e1);
  double as=tk(e0,e1)/it;
  adamw32_vec<<<gq,bl>>>((float4*)fW,(float4*)fM,(float4*)fV,(float4*)fG,nq,lr,b1,b2,eps,wd,c1,c2);cudaDeviceSynchronize();
  cudaEventRecord(e0);for(int i=0;i<it;i++)adamw32_vec<<<gq,bl>>>((float4*)fW,(float4*)fM,(float4*)fV,(float4*)fG,nq,lr,b1,b2,eps,wd,c1,c2);cudaEventRecord(e1);cudaEventSynchronize(e1);
  double av=tk(e0,e1)/it;
  printf("ADAMW fp32 (7 streams %.1fGB): scalar %.2fGB/s  vec(f4) %.2fGB/s  speedup %.3fx\n",
    7.0*n*4/1e9, bw(as,7.0*n*4/1e9), bw(av,7.0*n*4/1e9), as/av);
  return 0; }
