#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#define CK(c) do{CUresult e=(c); if(e!=CUDA_SUCCESS){const char*s;cuGetErrorString(e,&s);fprintf(stderr,"err %d %s\n",e,s);return 1;}}while(0)
static char*rf(const char*p){FILE*f=fopen(p,"rb");fseek(f,0,SEEK_END);long n=ftell(f);fseek(f,0,SEEK_SET);char*b=malloc(n+1);size_t r=fread(b,1,n,f);(void)r;b[n]=0;fclose(f);return b;}
double now(){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1000.0+t.tv_nsec/1e6;}
int main(int ac,char**av){
  int S=atoi(av[1]); int d=768,dh=64,dff=3072; float inv=1.0f/d, sc=1.0f/8.0f;
  char*p1=rf("block_fused_k1.ptx"),*p2=rf("block_fused_k2.ptx");
  CK(cuInit(0)); CUdevice dv; CK(cuDeviceGet(&dv,0)); CUcontext cx; CK(cuCtxCreate(&cx,0,dv));
  CUjit_option jo[1]={CU_JIT_TARGET_FROM_CUCONTEXT}; void*jv[1]={0};
  CUmodule m1,m2; CK(cuModuleLoadDataEx(&m1,p1,1,jo,jv)); CK(cuModuleLoadDataEx(&m2,p2,1,jo,jv));
  CUfunction f1,f2; CK(cuModuleGetFunction(&f1,m1,"block_fused_k1")); CK(cuModuleGetFunction(&f2,m2,"block_fused_k2"));
  size_t bx=(size_t)S*d*4, bw=(size_t)d*dh*4, bwo=(size_t)dh*d*4, bg=d*4, bwu=(size_t)d*dff*4, bwd=(size_t)dff*d*4;
  CUdeviceptr x,g,b,wq,wk,wv,wo,mid,wu,wgt,wd,out;
  CK(cuMemAlloc(&x,bx));CK(cuMemAlloc(&mid,bx));CK(cuMemAlloc(&out,bx));CK(cuMemAlloc(&g,bg));CK(cuMemAlloc(&b,bg));
  CK(cuMemAlloc(&wq,bw));CK(cuMemAlloc(&wk,bw));CK(cuMemAlloc(&wv,bw));CK(cuMemAlloc(&wo,bwo));
  CK(cuMemAlloc(&wu,bwu));CK(cuMemAlloc(&wgt,bwu));CK(cuMemAlloc(&wd,bwd));
  void*a1[12]={&x,&g,&b,&wq,&wk,&wv,&wo,&mid,&S,&d,&inv,&sc};
  void*a2[11]={&mid,&g,&b,&wu,&wgt,&wd,&out,&S,&d,&dff,&inv};
  int g1=(S+63)/64, g2=(S+127)/128;
  double t;
  t=now(); CK(cuLaunchKernel(f1,g1,1,1,64,1,1,0,0,a1,0)); CK(cuCtxSynchronize()); printf("K1 S=%d wall_ms=%.3f\n",S,now()-t);
  t=now(); CK(cuLaunchKernel(f2,g2,1,1,128,1,1,0,0,a2,0)); CK(cuCtxSynchronize()); printf("K2 S=%d wall_ms=%.3f\n",S,now()-t);
  return 0;
}
