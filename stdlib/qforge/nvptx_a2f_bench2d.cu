// stdlib/qforge/nvptx_a2f_bench2d.cu — M35 lever, 2D-parallel α²F BZ-sum.
//
// Times the 2D (sample×bin) kernel qforge_a2f_bzsum2d vs CPU vs the M27 1D
// kernel qforge_a2f_bzsum, at several (ns×ng). The 2D grid spawns
// (ns/nchunk)·ng threads → fills the 188-SM Blackwell that the 1D kernel
// (ng threads only) starved. Atomic-add reduction over the sample tiles.
// Parity-checked per size vs CPU (rel ≤ 1e-5) before any speedup is reported.
//
//   build: nvcc -O2 nvptx_a2f_bench2d.cu -o nvptx_a2f_bench2d -lcuda
//   run:   ./nvptx_a2f_bench2d kernel1d.ptx kernel2d.ptx

#include <cuda.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <chrono>
#define DR(x) do{ CUresult r=(x); if(r){const char*s;cuGetErrorString(r,&s);fprintf(stderr,"ERR %s @%d\n",s,__LINE__);exit(2);} }while(0)
static const double S2PI=2.5066282746310002;
static inline double gd(double x,double s){if(s<=0)return 0;double z=x/s;double e=-0.5*z*z;return e>-700.0?exp(e)/(s*S2PI):0.0;}
static double cpu_run(int ns,int ng,double*ek,double*ekq,double*g2,double*omq,double*wg,
   double ef,double nef,double w,double sel,double sph,double*o){
  auto t0=std::chrono::high_resolution_clock::now();double in=1.0/nef;
  for(int j=0;j<ng;j++)o[j]=0;
  for(int i=0;i<ns;i++){double dk=gd(ek[i]-ef,sel),dkq=gd(ekq[i]-ef,sel),wgt=w*g2[i]*dk*dkq*in;
    if(wgt!=0){double wq=omq[i];for(int j=0;j<ng;j++)o[j]+=wgt*gd(wg[j]-wq,sph);}}
  auto t1=std::chrono::high_resolution_clock::now();
  return std::chrono::duration<double>(t1-t0).count();}

int main(int argc,char**argv){
  const char*p1=argc>1?argv[1]:"nvptx_a2f_kernel.ptx";
  const char*p2=argc>2?argv[2]:"nvptx_a2f_kernel2d.ptx";
  DR(cuInit(0));CUdevice d;DR(cuDeviceGet(&d,0));char nm[256];DR(cuDeviceGetName(nm,256,d));
  int ccM,ccm,sm;DR(cuDeviceGetAttribute(&ccM,CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR,d));
  DR(cuDeviceGetAttribute(&ccm,CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR,d));
  DR(cuDeviceGetAttribute(&sm,CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT,d));
  CUcontext ctx;DR(cuCtxCreate(&ctx,0,d));
  auto load=[&](const char*p,const char*fn)->CUfunction{FILE*f=fopen(p,"rb");if(!f){perror(p);exit(2);}
    fseek(f,0,2);long n=ftell(f);fseek(f,0,0);char*b=(char*)malloc(n+1);if(fread(b,1,n,f)!=(size_t)n)exit(2);b[n]=0;fclose(f);
    CUmodule m;static char jl[16384];jl[0]=0;
    CUjit_option jo[3]={CU_JIT_TARGET_FROM_CUCONTEXT,CU_JIT_ERROR_LOG_BUFFER,CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES};
    void*jv[3]={0,(void*)jl,(void*)(size_t)sizeof jl};
    CUresult lr=cuModuleLoadDataEx(&m,b,3,jo,jv);
    if(lr){const char*s;cuGetErrorString(lr,&s);fprintf(stderr,"JIT FAIL %s (%s): %s\njitlog:%s\n",p,fn,s,jl);exit(3);}
    CUfunction fnc;DR(cuModuleGetFunction(&fnc,m,fn));return fnc;};
  CUfunction f1=load(p1,"qforge_a2f_bzsum"), f2=load(p2,"qforge_a2f_bzsum2d");

  printf("# pod %s sm_%d%d SMs=%d  (M35 2D lever — sample x bin)\n",nm,ccM,ccm,sm);
  printf("# %-18s %10s %10s %10s %8s %8s %10s\n","size","cpu_ms","gpu1d_ms","gpu2d_ms","sp1d","sp2d","gpu2d_GF");
  struct Sz{int ns,ng;};Sz sz[]={{1024,128},{4096,256},{16384,512},{65536,512},{131072,1024},{262144,1024}};
  int nsz=6;double ef=0.30,nef=2.5,sel=0.05,sph=0.02;
  for(int s=0;s<nsz;s++){int ns=sz[s].ns,ng=sz[s].ng;double w=1.0/ns;
    double*ek=(double*)malloc(ns*8),*ekq=(double*)malloc(ns*8),*g2=(double*)malloc(ns*8),
      *omq=(double*)malloc(ns*8),*wg=(double*)malloc(ng*8),*cpu=(double*)malloc(ng*8),*g=(double*)malloc(ng*8);
    for(int i=0;i<ns;i++){double t=i;ek[i]=ef+0.12*sin(0.013*t+0.7);ekq[i]=ef+0.12*sin(0.017*t+1.9);
      g2[i]=0.5+0.4*(0.5+0.5*sin(0.011*t));omq[i]=0.10+0.80*(0.5+0.5*sin(0.007*t+2.1));}
    for(int j=0;j<ng;j++)wg[j]=(double)j/(ng-1);
    double par[8]={ef,nef,w,sel,sph,1.0/S2PI,0,0};
    int rp=ns<=4096?3:1;double cms=1e30;
    for(int r=0;r<rp;r++){double t=cpu_run(ns,ng,ek,ekq,g2,omq,wg,ef,nef,w,sel,sph,cpu);if(t*1e3<cms)cms=t*1e3;}
    CUdeviceptr dek,dekq,dg2,domq,dwg,dpar,da;
    DR(cuMemAlloc(&dek,ns*8));DR(cuMemAlloc(&dekq,ns*8));DR(cuMemAlloc(&dg2,ns*8));DR(cuMemAlloc(&domq,ns*8));
    DR(cuMemAlloc(&dwg,ng*8));DR(cuMemAlloc(&dpar,64));DR(cuMemAlloc(&da,ng*8));
    DR(cuMemcpyHtoD(dek,ek,ns*8));DR(cuMemcpyHtoD(dekq,ekq,ns*8));DR(cuMemcpyHtoD(dg2,g2,ns*8));
    DR(cuMemcpyHtoD(domq,omq,ns*8));DR(cuMemcpyHtoD(dwg,wg,ng*8));DR(cuMemcpyHtoD(dpar,par,64));
    long long nsL=ns,ngL=ng;
    CUevent a,b;cuEventCreate(&a,0);cuEventCreate(&b,0);
    // 1D
    void*k1[]={&dek,&dekq,&dg2,&domq,&dwg,&dpar,&da,&nsL,&ngL};
    int blk=128,grd=(ng+blk-1)/blk;
    DR(cuLaunchKernel(f1,grd,1,1,blk,1,1,0,0,k1,0));DR(cuCtxSynchronize());
    int kr=ns<=16384?20:5;DR(cuEventRecord(a,0));
    for(int r=0;r<kr;r++)DR(cuLaunchKernel(f1,grd,1,1,blk,1,1,0,0,k1,0));
    DR(cuEventRecord(b,0));DR(cuEventSynchronize(b));float m1=0;cuEventElapsedTime(&m1,a,b);double g1=m1/kr;
    // 2D — nchunk tuned so ntile keeps grid large; aim ~256 samples/thread
    long long nchunk = ns>4096? 256 : 32; long long ntile=(ns+nchunk-1)/nchunk;
    void*k2[]={&dek,&dekq,&dg2,&domq,&dwg,&dpar,&da,&nsL,&ngL,&nchunk};
    int bx=64,by=4; unsigned gx=(ng+bx-1)/bx, gy=(unsigned)((ntile+by-1)/by);
    DR(cuMemsetD8(da,0,ng*8));
    DR(cuLaunchKernel(f2,gx,gy,1,bx,by,1,0,0,k2,0));DR(cuCtxSynchronize());
    DR(cuMemcpyDtoH(g,da,ng*8));
    double mr=0;for(int j=0;j<ng;j++){double A=cpu[j],B=g[j];if(fabs(A)>1e-300){double rr=fabs((A-B)/A);if(rr>mr)mr=rr;}}
    DR(cuEventRecord(a,0));
    for(int r=0;r<kr;r++){DR(cuMemsetD8(da,0,ng*8));DR(cuLaunchKernel(f2,gx,gy,1,bx,by,1,0,0,k2,0));}
    DR(cuEventRecord(b,0));DR(cuEventSynchronize(b));float m2=0;cuEventElapsedTime(&m2,a,b);double g2t=m2/kr;
    double flop=13.0*(double)ns*ng;double gf=flop/(g2t*1e-3)/1e9;
    char tg[24];snprintf(tg,24,"%dx%d",ns,ng);
    printf("  %-18s %10.3f %10.4f %10.4f %7.1fx %7.1fx %10.1f%s\n",
      tg,cms,g1,g2t,cms/g1,cms/g2t,gf, mr>1e-5?"  2D-PARITY-FAIL!":"");
    cuMemFree(dek);cuMemFree(dekq);cuMemFree(dg2);cuMemFree(domq);cuMemFree(dwg);cuMemFree(dpar);cuMemFree(da);
    free(ek);free(ekq);free(g2);free(omq);free(wg);free(cpu);free(g);
  }
  return 0;
}
