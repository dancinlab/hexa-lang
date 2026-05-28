// RoPE wedge host (Round 11). Build: nvcc -O2 -o rope_host rope_f64_host.c -lcuda -lm
#include <cuda.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#define D 128
#define NP (D/2)
#define CK(x) do { CUresult r=(x); if(r){const char*s;cuGetErrorString(r,&s);fprintf(stderr,"cu %s @%d\n",s,__LINE__);return 1;} } while(0)
int main(void) {
    double x[D], y_ref[D], y_gpu[D];
    double pos = 7.0, base = 10000.0;
    for (int i=0;i<D;i++) x[i] = sin(0.017*(double)i + 0.9) * 1.2;
    for (int p=0;p<NP;p++) {
        double expo = (2.0*(double)p)/(double)D;
        double freq = pow(base, expo);
        double th = pos/freq;
        double cc=cos(th), ss=sin(th);
        double x0=x[2*p], x1=x[2*p+1];
        y_ref[2*p]   = x0*cc - x1*ss;
        y_ref[2*p+1] = x0*ss + x1*cc;
    }
    CK(cuInit(0)); CUdevice d; CK(cuDeviceGet(&d,0)); CUcontext c; CK(cuCtxCreate(&c,0,d));
    FILE*fp=fopen("/tmp/probe_rope_f64.ptx","rb"); if(!fp){fprintf(stderr,"ptx fail\n");return 1;}
    fseek(fp,0,SEEK_END); long sz=ftell(fp); fseek(fp,0,SEEK_SET);
    char*ptx=malloc(sz+1); if(fread(ptx,1,sz,fp)!=(size_t)sz){return 1;} ptx[sz]=0; fclose(fp);
    CUmodule m; CUjit_option o[]={CU_JIT_ERROR_LOG_BUFFER,CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES};
    char lg[8192]={0}; size_t ls=sizeof(lg); void*v[]={lg,(void*)ls};
    CUresult rj=cuModuleLoadDataEx(&m,ptx,2,o,v); if(rj){fprintf(stderr,"JIT: %s\n",lg);return 1;}
    CUfunction fn; CK(cuModuleGetFunction(&fn,m,"probe_rope_f64"));
    CUdeviceptr dx,dy; CK(cuMemAlloc(&dx,D*sizeof(double))); CK(cuMemAlloc(&dy,D*sizeof(double)));
    CK(cuMemcpyHtoD(dx,x,D*sizeof(double)));
    long long np=NP, dd=D; void*ka[]={&dx,&dy,&pos,&base,&np,&dd};
    CK(cuLaunchKernel(fn,1,1,1,NP,1,1,0,0,ka,0)); CK(cuCtxSynchronize());
    CK(cuMemcpyDtoH(y_gpu,dy,D*sizeof(double)));
    int nan=0; double me=0,refmax=0; int w=0;
    for(int i=0;i<D;i++){ if(isnan(y_gpu[i])||isinf(y_gpu[i])){nan++;continue;}
        double e=fabs(y_gpu[i]-y_ref[i]); if(e>me){me=e;w=i;} if(fabs(y_ref[i])>refmax)refmax=fabs(y_ref[i]); }
    double rel=refmax>0?me/refmax:0;
    printf("RoPE wedge (D=%d, %d pairs, pos=%.0f base=%.0f)\n",D,NP,pos,base);
    printf("  n_nan_inf=%d/%d\n",nan,D);
    printf("  max_abs_err=%.3e (@%d gpu=%.17g ref=%.17g)\n",me,w,y_gpu[w],y_ref[w]);
    printf("  max_rel_err=%.3e\n",rel);
    if(nan==0&&me<1e-12)printf("  RESULT: PASS (byte-eq <1e-12)\n");
    else if(nan==0&&rel<1e-13)printf("  RESULT: PASS-near-byte-eq\n");
    else if(nan==0&&me<1e-7)printf("  RESULT: PASS-numerical\n");
    else printf("  RESULT: FAIL (nan=%d)\n",nan);
    return 0;
}
