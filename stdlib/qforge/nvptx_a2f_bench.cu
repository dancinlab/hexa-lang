// stdlib/qforge/nvptx_a2f_bench.cu — M35 GPU-accel lever quantification.
//
// Times the α²F BZ-sum hot kernel (M27 qforge_a2f_bzsum) CPU vs GPU across
// several (ns × ng) problem sizes, on the SAME pod (vast 39481710, sm_120).
// The kernel is O(ns·ng) Gaussian-δ evaluations — the el-ph assembler hot
// kernel (distinct from the DFPT n_iter-dominant cost model #2706). Reports
// measured wall-time speedup + a roofline/FLOP context per size.
//
//   build: nvcc -O2 nvptx_a2f_bench.cu -o nvptx_a2f_bench -lcuda
//   run:   ./nvptx_a2f_bench kernel.ptx
//
// CPU timer = the SAME C++ reference loop (FP64, libm exp) the parity used,
// compiled -O2 — an honest single-core scalar baseline on the pod CPU. GPU
// timer = cuEvent around the kernel launch (kernel-only, excludes H2D/D2H so
// the lever is the COMPUTE speedup; transfer is reported separately).

#include <cuda.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <chrono>

#define DR(x) do{ CUresult r=(x); if(r!=CUDA_SUCCESS){ const char*s; cuGetErrorString(r,&s); \
  fprintf(stderr,"CUDA-ERR %s @ %d\n",s,__LINE__); exit(2);} }while(0)

static const double SQRT2PI = 2.5066282746310002;
static inline double gdelta(double x,double s){ if(s<=0)return 0; double z=x/s; double e=-0.5*z*z;
  return e>-700.0 ? exp(e)/(s*SQRT2PI) : 0.0; }

static CUfunction g_fn;

// CPU ref: same hot loop, FP64, -O2. Single core. Returns wall seconds.
static double cpu_run(int ns,int ng,const double*ek,const double*ekq,const double*g2,
                      const double*omq,const double*wg,double ef,double nef,double w,
                      double sel,double sph,double*out){
    auto t0=std::chrono::high_resolution_clock::now();
    double in=1.0/nef;
    for(int j=0;j<ng;j++) out[j]=0.0;
    for(int i=0;i<ns;i++){
        double dk=gdelta(ek[i]-ef,sel), dkq=gdelta(ekq[i]-ef,sel);
        double wgt=w*g2[i]*dk*dkq*in;
        if(wgt!=0.0){ double wq=omq[i];
            for(int j=0;j<ng;j++) out[j]+=wgt*gdelta(wg[j]-wq,sph); }
    }
    auto t1=std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double>(t1-t0).count();
}

int main(int argc,char**argv){
    const char* ptx=argc>1?argv[1]:"nvptx_a2f_kernel.hexa.ptx";
    DR(cuInit(0)); CUdevice d; DR(cuDeviceGet(&d,0));
    char nm[256]; DR(cuDeviceGetName(nm,256,d));
    int ccM,ccm; DR(cuDeviceGetAttribute(&ccM,CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR,d));
    DR(cuDeviceGetAttribute(&ccm,CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR,d));
    int sm_count=0; DR(cuDeviceGetAttribute(&sm_count,CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT,d));
    CUcontext ctx; DR(cuCtxCreate(&ctx,0,d));
    FILE*f=fopen(ptx,"rb"); if(!f){perror("ptx");return 2;} fseek(f,0,SEEK_END);
    long np=ftell(f); fseek(f,0,SEEK_SET); char*pt=(char*)malloc(np+1);
    if(fread(pt,1,np,f)!=(size_t)np){return 2;} pt[np]=0; fclose(f);
    CUmodule mod; CUjit_option jo[1]={CU_JIT_TARGET_FROM_CUCONTEXT}; void*jv[1]={0};
    DR(cuModuleLoadDataEx(&mod,pt,1,jo,jv)); DR(cuModuleGetFunction(&g_fn,mod,"qforge_a2f_bzsum"));

    printf("# pod %s sm_%d%d  SMs=%d  (M35 α²F BZ-sum lever)\n",nm,ccM,ccm,sm_count);
    printf("# %-22s %12s %12s %10s %12s %10s\n",
           "size (ns x ng)","cpu_ms","gpu_ms","speedup","gpu_GFLOPs","h2d_ms");

    // ~13 FLOP per (i,j) inner Gaussian deposit (sub,mul,mul,exp~8,mul,fma)
    // plus the per-i prefactor; use 13·ns·ng as a conservative inner FLOP count.
    struct Sz{int ns,ng;};
    Sz sizes[]={{256,64},{1024,128},{4096,256},{16384,512},{65536,512},{131072,1024}};
    int nsz=sizeof(sizes)/sizeof(sizes[0]);

    double ef=0.30,nef=2.5,sel=0.05,sph=0.02;
    for(int s=0;s<nsz;s++){
        int ns=sizes[s].ns, ng=sizes[s].ng; double w=1.0/(double)ns;
        double*ek=(double*)malloc(ns*8),*ekq=(double*)malloc(ns*8),
              *g2=(double*)malloc(ns*8),*omq=(double*)malloc(ns*8),*wg=(double*)malloc(ng*8);
        for(int i=0;i<ns;i++){double t=i;ek[i]=ef+0.12*sin(0.013*t+0.7);
            ekq[i]=ef+0.12*sin(0.017*t+1.9);g2[i]=0.5+0.4*(0.5+0.5*sin(0.011*t));
            omq[i]=0.10+0.80*(0.5+0.5*sin(0.007*t+2.1));}
        for(int j=0;j<ng;j++) wg[j]=(double)j/(double)(ng-1);
        double par[8]={ef,nef,w,sel,sph,1.0/SQRT2PI,(double)ns,(double)ng};
        double*cpu=(double*)malloc(ng*8),*gpu=(double*)malloc(ng*8);

        // CPU (median of 3 for small, 1 for large)
        int reps = ns<=4096?3:1; double cpu_ms=1e30;
        for(int r=0;r<reps;r++){ double t=cpu_run(ns,ng,ek,ekq,g2,omq,wg,ef,nef,w,sel,sph,cpu);
            if(t*1e3<cpu_ms)cpu_ms=t*1e3; }

        // GPU buffers + H2D timing
        CUdeviceptr dek,dekq,dg2,domq,dwg,dpar,da2f;
        DR(cuMemAlloc(&dek,ns*8));DR(cuMemAlloc(&dekq,ns*8));DR(cuMemAlloc(&dg2,ns*8));
        DR(cuMemAlloc(&domq,ns*8));DR(cuMemAlloc(&dwg,ng*8));DR(cuMemAlloc(&dpar,64));DR(cuMemAlloc(&da2f,ng*8));
        CUevent h0,h1,k0,k1; cuEventCreate(&h0,0);cuEventCreate(&h1,0);cuEventCreate(&k0,0);cuEventCreate(&k1,0);
        DR(cuEventRecord(h0,0));
        DR(cuMemcpyHtoD(dek,ek,ns*8));DR(cuMemcpyHtoD(dekq,ekq,ns*8));DR(cuMemcpyHtoD(dg2,g2,ns*8));
        DR(cuMemcpyHtoD(domq,omq,ns*8));DR(cuMemcpyHtoD(dwg,wg,ng*8));DR(cuMemcpyHtoD(dpar,par,64));
        DR(cuEventRecord(h1,0));
        long long nsL=ns,ngL=ng; void*ka[]={&dek,&dekq,&dg2,&domq,&dwg,&dpar,&da2f,&nsL,&ngL};
        int blk=128, grd=(ng+blk-1)/blk;
        // warmup
        DR(cuLaunchKernel(g_fn,grd,1,1,blk,1,1,0,0,ka,0)); DR(cuCtxSynchronize());
        DR(cuEventRecord(k0,0));
        int kreps=ns<=4096?20:5;
        for(int r=0;r<kreps;r++) DR(cuLaunchKernel(g_fn,grd,1,1,blk,1,1,0,0,ka,0));
        DR(cuEventRecord(k1,0)); DR(cuEventSynchronize(k1));
        float h_ms=0,k_ms=0; cuEventElapsedTime(&h_ms,h0,h1); cuEventElapsedTime(&k_ms,k0,k1);
        double gpu_ms=k_ms/kreps;
        DR(cuMemcpyDtoH(gpu,da2f,ng*8));

        // parity guard per size (don't report a speedup on wrong numbers)
        double mr=0; for(int j=0;j<ng;j++){double a=cpu[j],b=gpu[j];
            if(fabs(a)>1e-300){double r=fabs((a-b)/a); if(r>mr)mr=r;}}
        double flop=13.0*(double)ns*(double)ng;
        double gflops=flop/(gpu_ms*1e-3)/1e9;
        char tag[32]; snprintf(tag,32,"%d x %d",ns,ng);
        printf("  %-22s %12.3f %12.4f %9.1fx %12.1f %10.3f%s\n",
               tag,cpu_ms,gpu_ms,cpu_ms/gpu_ms,gflops,h_ms, mr>1e-5?"  PARITY-FAIL!":"");
        cuMemFree(dek);cuMemFree(dekq);cuMemFree(dg2);cuMemFree(domq);cuMemFree(dwg);cuMemFree(dpar);cuMemFree(da2f);
        free(ek);free(ekq);free(g2);free(omq);free(wg);free(cpu);free(gpu);
    }
    return 0;
}
