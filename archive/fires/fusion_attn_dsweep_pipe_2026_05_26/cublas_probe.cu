/* Baseline-integrity probe: is my cuBLAS attention stack mis-dispatching?
 * Compare (a) GemmStridedBatchedEx batch=1 FP32, (b) plain GemmEx FP32,
 * (c) plain cublasSgemm, (d) GemmEx FP16-TC, and TIME EACH OF THE 3 LAUNCHES
 * separately so we can see where the cost is + whether the S round-trip is the
 * real floor. Also measure a single standalone N x N x d SGEMM as a sanity peg.
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define CK(c) do{cudaError_t e=(c); if(e!=cudaSuccess){fprintf(stderr,"CUDA %s @%d\n",cudaGetErrorString(e),__LINE__);return 1;}}while(0)
#define CB(c) do{cublasStatus_t s=(c); if(s!=CUBLAS_STATUS_SUCCESS){fprintf(stderr,"cuBLAS %d @%d\n",(int)s,__LINE__);return 1;}}while(0)

static int cmpd(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return x<y?-1:x>y?1:0;}
__global__ void smax(float*S,int N){int r=blockIdx.x*blockDim.x+threadIdx.x;if(r>=N)return;float*p=S+(size_t)r*N;float m=-3.4e38f;for(int j=0;j<N;++j)if(p[j]>m)m=p[j];float l=0;for(int j=0;j<N;++j){float e=expf(p[j]-m);p[j]=e;l+=e;}float iv=1.f/l;for(int j=0;j<N;++j)p[j]*=iv;}

static double med(double(*fn)(void*),void*ctx){
    for(int i=0;i<20;++i) fn(ctx); cudaDeviceSynchronize();
    int R=200; double*t=(double*)malloc(R*8); cudaEvent_t a,b; cudaEventCreate(&a);cudaEventCreate(&b);
    for(int i=0;i<R;++i){cudaEventRecord(a,0);fn(ctx);cudaEventRecord(b,0);cudaEventSynchronize(b);float ms;cudaEventElapsedTime(&ms,a,b);t[i]=ms;}
    qsort(t,R,8,cmpd); double m=t[R/2]; free(t); return m;
}

struct Ctx{cublasHandle_t h;float*dq,*dk,*dv,*dop,*dS;int N,d;float scale;};
static Ctx* G;
static double f_full(void*){const float one=1,zero=0;long long s0=0;Ctx*c=G;
    cublasGemmStridedBatchedEx(c->h,CUBLAS_OP_T,CUBLAS_OP_N,c->N,c->N,c->d,&c->scale,c->dk,CUDA_R_32F,c->d,s0,c->dq,CUDA_R_32F,c->d,s0,&zero,c->dS,CUDA_R_32F,c->N,s0,1,CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT);
    smax<<<(c->N+255)/256,256>>>(c->dS,c->N);
    cublasGemmStridedBatchedEx(c->h,CUBLAS_OP_N,CUBLAS_OP_N,c->d,c->N,c->N,&one,c->dv,CUDA_R_32F,c->d,s0,c->dS,CUDA_R_32F,c->N,s0,&zero,c->dop,CUDA_R_32F,c->d,s0,1,CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT);
    return 0;}
static double f_l1(void*){const float zero=0;long long s0=0;Ctx*c=G;
    cublasGemmStridedBatchedEx(c->h,CUBLAS_OP_T,CUBLAS_OP_N,c->N,c->N,c->d,&c->scale,c->dk,CUDA_R_32F,c->d,s0,c->dq,CUDA_R_32F,c->d,s0,&zero,c->dS,CUDA_R_32F,c->N,s0,1,CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT);return 0;}
static double f_sm(void*){Ctx*c=G;smax<<<(c->N+255)/256,256>>>(c->dS,c->N);return 0;}
static double f_l3(void*){const float one=1,zero=0;long long s0=0;Ctx*c=G;
    cublasGemmStridedBatchedEx(c->h,CUBLAS_OP_N,CUBLAS_OP_N,c->d,c->N,c->N,&one,c->dv,CUDA_R_32F,c->d,s0,c->dS,CUDA_R_32F,c->N,s0,&zero,c->dop,CUDA_R_32F,c->d,s0,1,CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT);return 0;}
static double f_sgemm(void*){const float one=1,zero=0;Ctx*c=G;
    cublasSgemm(c->h,CUBLAS_OP_T,CUBLAS_OP_N,c->N,c->N,c->d,&c->scale,c->dk,c->d,c->dq,c->d,&zero,c->dS,c->N);return 0;}

int main(int argc,char**argv){
    int N=(argc>1)?atoi(argv[1]):4096,d=(argc>2)?atoi(argv[2]):64;
    Ctx c; c.N=N; c.d=d; c.scale=1.f/sqrtf((float)d);
    size_t szT=(size_t)N*d*4, szS=(size_t)N*N*4;
    CK(cudaMalloc(&c.dq,szT));CK(cudaMalloc(&c.dk,szT));CK(cudaMalloc(&c.dv,szT));CK(cudaMalloc(&c.dop,szT));CK(cudaMalloc(&c.dS,szS));
    CK(cudaMemset(c.dq,1,szT));CK(cudaMemset(c.dk,1,szT));CK(cudaMemset(c.dv,1,szT));
    CB(cublasCreate(&c.h)); G=&c;
    double full=med(f_full,0), l1=med(f_l1,0), sm=med(f_sm,0), l3=med(f_l3,0), sg=med(f_sgemm,0);
    printf("PROBE N=%d d=%d: full_stack=%.5f  L1_QKt=%.5f  softmax=%.5f  L3_PV=%.5f  sum_parts=%.5f  bare_sgemm_QKt=%.5f\n",
           N,d,full,l1,sm,l3,l1+sm+l3,sg);
    printf("  S matrix = %dx%d = %.1f M floats = %.1f MiB HBM (written L1, read+written softmax, read L3)\n",
           N,N,(double)N*N/1e6,(double)szS/1048576.0);
    cublasDestroy(c.h);return 0;
}
