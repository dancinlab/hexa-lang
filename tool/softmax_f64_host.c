// softmax wedge host (Round 11). Build: nvcc -O2 -o softmax_host softmax_f64_host.c -lcuda -lm
#include <cuda.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#define N 256
#define CK(x) do { CUresult r = (x); if (r) { const char *s; cuGetErrorString(r,&s); fprintf(stderr,"cu %s @%d\n",s,__LINE__); return 1; } } while(0)
int main(void) {
    double x[N], y_ref[N], y_gpu[N];
    for (int i=0;i<N;i++) x[i] = sin(0.021*(double)i + 0.4) * 3.0;
    double mx = x[0]; for (int i=1;i<N;i++) if (x[i]>mx) mx=x[i];
    double s=0.0; for (int i=0;i<N;i++) s += exp(x[i]-mx);
    for (int i=0;i<N;i++) y_ref[i] = exp(x[i]-mx)/s;
    CK(cuInit(0)); CUdevice d; CK(cuDeviceGet(&d,0)); CUcontext c; CK(cuCtxCreate(&c,0,d));
    FILE*fp=fopen("/tmp/probe_softmax_f64.ptx","rb"); if(!fp){fprintf(stderr,"ptx fail\n");return 1;}
    fseek(fp,0,SEEK_END); long sz=ftell(fp); fseek(fp,0,SEEK_SET);
    char*ptx=malloc(sz+1); if(fread(ptx,1,sz,fp)!=(size_t)sz){return 1;} ptx[sz]=0; fclose(fp);
    CUmodule m; CUjit_option o[]={CU_JIT_ERROR_LOG_BUFFER,CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES};
    char lg[8192]={0}; size_t ls=sizeof(lg); void*v[]={lg,(void*)ls};
    CUresult rj=cuModuleLoadDataEx(&m,ptx,2,o,v); if(rj){fprintf(stderr,"JIT: %s\n",lg);return 1;}
    CUfunction fn; CK(cuModuleGetFunction(&fn,m,"probe_softmax_f64"));
    CUdeviceptr dx,dy; CK(cuMemAlloc(&dx,N*sizeof(double))); CK(cuMemAlloc(&dy,N*sizeof(double)));
    CK(cuMemcpyHtoD(dx,x,N*sizeof(double)));
    long long nn=N; void*ka[]={&dx,&dy,&nn};
    CK(cuLaunchKernel(fn,1,1,1,256,1,1,0,0,ka,0)); CK(cuCtxSynchronize());
    CK(cuMemcpyDtoH(y_gpu,dy,N*sizeof(double)));
    int nan=0; double me=0,refmax=0; int w=0; double sumg=0;
    for(int i=0;i<N;i++){ if(isnan(y_gpu[i])||isinf(y_gpu[i])){nan++;continue;} sumg+=y_gpu[i];
        double e=fabs(y_gpu[i]-y_ref[i]); if(e>me){me=e;w=i;} if(fabs(y_ref[i])>refmax)refmax=fabs(y_ref[i]); }
    double rel=refmax>0?me/refmax:0;
    printf("softmax wedge (N=%d)\n",N);
    printf("  n_nan_inf=%d/%d  Σy_gpu=%.17g (should=1.0)\n",nan,N,sumg);
    printf("  max_abs_err=%.3e (@%d gpu=%.17g ref=%.17g)\n",me,w,y_gpu[w],y_ref[w]);
    printf("  max_rel_err=%.3e\n",rel);
    if(nan==0&&me<1e-12)printf("  RESULT: PASS (byte-eq <1e-12)\n");
    else if(nan==0&&rel<1e-13)printf("  RESULT: PASS-near-byte-eq\n");
    else if(nan==0&&me<1e-7)printf("  RESULT: PASS-numerical\n");
    else printf("  RESULT: FAIL (nan=%d)\n",nan);
    return 0;
}
