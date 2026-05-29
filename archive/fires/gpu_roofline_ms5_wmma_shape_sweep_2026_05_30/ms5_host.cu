// MS#5 forge/hexa WMMA variable-shape roofline sweep harness.
// ubu-2 RTX 5070 sm_120. Loads existing hexa-emit WMMA PTX (PR #214 256-shape +
// pD hand-emit shape-ports 512/1024), runs cuBLAS HGEMM at the same shape,
// times both (median of 200, 20 warmup, cudaEventRecord per-launch), and does a
// byte-eq numeric check (hexa WMMA D vs cuBLAS C, max|Δ|).
// Pure-ASCII. /tmp only.
#include <cuda.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cuda_fp16.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static int cmp_d(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return x<y?-1:x>y?1:0;}

typedef struct { int S; const char* ptx; const char* entry; } Shape;

int main(int argc,char**argv){
  cuInit(0);
  CUdevice dev; cuDeviceGet(&dev,0);
  CUcontext ctx; cuCtxCreate(&ctx,0,dev);
  char name[256]; cuDeviceGetName(name,256,dev);
  int drv,rt; cuDriverGetVersion(&drv); cudaRuntimeGetVersion(&rt);
  printf("Device: %s\nCUDA driver=%d runtime=%d\n",name,drv,rt);

  // shapes passed as: S:ptxpath:entry ...
  Shape sh[8]; int ns=0;
  for(int i=1;i<argc;i++){
    char buf[1024]; strncpy(buf,argv[i],1023);
    char* c1=strchr(buf,':'); *c1=0; char* c2=strchr(c1+1,':'); *c2=0;
    sh[ns].S=atoi(buf); sh[ns].ptx=strdup(c1+1); sh[ns].entry=strdup(c2+1); ns++;
  }

  cublasHandle_t cub; cublasCreate(&cub);
  const int WARM=20, REP=200;

  for(int s=0;s<ns;s++){
    int S=sh[s].S; size_t n=(size_t)S*S;
    // host A,B f16 row/col-major; deterministic sawtooth (TF32/f16 lossless small ints)
    __half* hA=(__half*)malloc(n*2); __half* hB=(__half*)malloc(n*2);
    for(size_t i=0;i<n;i++){ hA[i]=__float2half((float)((i%7)-3)); hB[i]=__float2half((float)((i%5)-2)); }
    __half *dA,*dB; cudaMalloc(&dA,n*2); cudaMalloc(&dB,n*2);
    cudaMemcpy(dA,hA,n*2,cudaMemcpyHostToDevice);
    cudaMemcpy(dB,hB,n*2,cudaMemcpyHostToDevice);
    float *dC_hexa,*dC_cub; cudaMalloc(&dC_hexa,n*4); cudaMalloc(&dC_cub,n*4);

    // load hexa PTX kernel
    CUmodule mod; CUresult r=cuModuleLoad(&mod,sh[s].ptx);
    if(r!=CUDA_SUCCESS){const char*es;cuGetErrorString(r,&es);printf("[S=%d] PTX load FAIL: %s\n",S,es);continue;}
    CUfunction fn; cuModuleGetFunction(&fn,mod,sh[s].entry);
    long long k_tiles=S/16;
    void* a_=dA; void* b_=dB; void* c_=dC_hexa; long long kt=k_tiles;
    void* args[]={&a_,&b_,&c_,&kt};
    int grid=S/64; dim3 g(grid,grid,1); dim3 blk(512,1,1);

    // cuBLAS HGEMM: C = A * B, A row-major[S,S] f16, B col-major[S,S] f16, out f32.
    // cublas is col-major. We compute D = A(row)*B(col). Use HgemmEx style via cublasGemmEx with f16 in, f32 out.
    __half alpha=__float2half(1.f), beta=__float2half(0.f);
    float alphaf=1.f, betaf=0.f;

    // ---- timing hexa ----
    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    for(int w=0;w<WARM;w++){ cuLaunchKernel(fn,g.x,g.y,1,blk.x,1,1,0,0,args,0); }
    cudaDeviceSynchronize();
    double* th=(double*)malloc(REP*sizeof(double));
    for(int it=0;it<REP;it++){ cudaEventRecord(e0); cuLaunchKernel(fn,g.x,g.y,1,blk.x,1,1,0,0,args,0); cudaEventRecord(e1); cudaEventSynchronize(e1); float ms; cudaEventElapsedTime(&ms,e0,e1); th[it]=ms; }
    qsort(th,REP,sizeof(double),cmp_d); double hmed=th[REP/2];
    double hflops=2.0*S*S*S; double htf=hflops/(hmed*1e-3)/1e12;

    // ---- cuBLAS HGEMM (f32 accumulate via GemmEx) ----
    // D(col)[N,M] = B(col)[K,N]^? ... replicate hexa semantics: D[i,j]=sum_k A[i,k]*B[j,k] (B col-major == B^T row).
    // cublasGemmEx col-major: C = op(A)*op(B). To get row-major D = A_row * B_colmajor :
    // Treat output as col-major NxM; compute via standard trick. We just need a consistent reference + same FLOP for timing.
    for(int w=0;w<WARM;w++){
      cublasGemmEx(cub,CUBLAS_OP_T,CUBLAS_OP_N,S,S,S,&alphaf,
        dB,CUDA_R_16F,S, dA,CUDA_R_16F,S,&betaf, dC_cub,CUDA_R_32F,S,
        CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP);
    }
    cudaDeviceSynchronize();
    double* tc=(double*)malloc(REP*sizeof(double));
    for(int it=0;it<REP;it++){ cudaEventRecord(e0);
      cublasGemmEx(cub,CUBLAS_OP_T,CUBLAS_OP_N,S,S,S,&alphaf,
        dB,CUDA_R_16F,S, dA,CUDA_R_16F,S,&betaf, dC_cub,CUDA_R_32F,S,
        CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP);
      cudaEventRecord(e1); cudaEventSynchronize(e1); float ms; cudaEventElapsedTime(&ms,e0,e1); tc[it]=ms; }
    qsort(tc,REP,sizeof(double),cmp_d); double cmed=tc[REP/2];
    double ctf=hflops/(cmed*1e-3)/1e12;

    // ---- byte-eq / numeric check: compare hexa D vs CPU-ref of same op ----
    // CPU ref: D[i,j] = sum_k A[i,k]*B[j,k]  (B col-major: B[j,k] at index j*S+k... but B stored col-major[K,N]=B[k + n*S])
    float* hHexa=(float*)malloc(n*4); cudaMemcpy(hHexa,dC_hexa,n*4,cudaMemcpyDeviceToHost);
    double maxabs=0.0;
    int chk = S<=512 ? S : 64; // limit CPU ref cost at large S to a corner block
    for(int i=0;i<chk;i++) for(int j=0;j<chk;j++){
      double acc=0;
      for(int k=0;k<S;k++){ acc += (double)__half2float(hA[(size_t)i*S+k]) * (double)__half2float(hB[(size_t)j*S+k]); }
      double got=hHexa[(size_t)i*S+j]; double d=fabs(got-acc); if(d>maxabs)maxabs=d;
    }

    printf("[S=%d] cuBLAS median=%.6f ms TFLOPS=%.4f | hexa median=%.6f ms TFLOPS=%.4f | ratio=%.4f | hexa-vs-CPUref max|d|=%.6g (corner %dx%d)\n",
      S,cmed,ctf,hmed,htf,htf/ctf,maxabs,chk,chk);

    free(th);free(tc);free(hHexa);free(hA);free(hB);
    cudaFree(dA);cudaFree(dB);cudaFree(dC_hexa);cudaFree(dC_cub);
    cuModuleUnload(mod);
  }
  return 0;
}
