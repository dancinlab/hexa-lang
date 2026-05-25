/* F-FUSION-AXISA-SWIGLU -- fused 1-kernel SwiGLU vs eager 3-launch baseline.
 *
 * y[i] = silu(g[i]) * u[i] ,  silu(g) = g * sigmoid(g)   (purely elementwise)
 *
 *   fused: swiglu_fused.ptx  (1 launch, s,t in registers, no HBM intermediate)
 *   eager: swiglu_eager.ptx  (k1_sigmoid, k2_mul_gate, k3_mul_up = 3 launches)
 *
 * HBM/elem: fused 2R+1W=3 ; eager 5R+3W=8.
 * Numeric: HONEST global RMS rel + max-abs metric, tol 1e-2 (ex2.approx).
 *
 * Build: nvcc -O2 -o host_swiglu host_swiglu.c -lcuda -lm
 * Run:   ./host_swiglu swiglu_fused.ptx swiglu_eager.ptx [n] [reps]
 */
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define CHECK(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA error %d at %s:%d: %s\n", e, __FILE__, __LINE__, s ? s : "?"); \
        return 1; }} while (0)

static char *slurp(const char *path) {
    FILE *fp=fopen(path,"rb"); if(!fp){perror(path);exit(1);}
    fseek(fp,0,SEEK_END); long n=ftell(fp); fseek(fp,0,SEEK_SET);
    char *buf=(char*)malloc(n+1); if(fread(buf,1,n,fp)!=(size_t)n){perror("read");exit(1);}
    buf[n]=0; fclose(fp); return buf;
}
static int cmp_double(const void *a,const void *b){
    double x=*(const double*)a,y=*(const double*)b; return (x<y)?-1:(x>y)?1:0;
}
static double silu_ref(double g){ return g / (1.0 + exp(-g)); }

int main(int argc, char **argv) {
    if (argc<3){ fprintf(stderr,"usage: %s fused.ptx eager.ptx [n] [reps]\n",argv[0]); return 2; }
    int n    = (argc>3)?atoi(argv[3]):16777216;  /* default 4096*4096 */
    int reps = (argc>4)?atoi(argv[4]):200;
    const int warmup=20;
    size_t bytes=(size_t)n*sizeof(float);

    char *fp=slurp(argv[1]), *ep=slurp(argv[2]);
    CHECK(cuInit(0));
    CUdevice dev; CHECK(cuDeviceGet(&dev,0));
    CUcontext ctx; CHECK(cuCtxCreate(&ctx,0,dev));
    CUmodule mf,me;
    CUjit_option jo[1]={CU_JIT_TARGET_FROM_CUCONTEXT}; void*jv[1]={(void*)0};
    CHECK(cuModuleLoadDataEx(&mf,fp,1,jo,jv));
    CHECK(cuModuleLoadDataEx(&me,ep,1,jo,jv));
    CUfunction kf,k1,k2,k3;
    CHECK(cuModuleGetFunction(&kf,mf,"swiglu_fused"));
    CHECK(cuModuleGetFunction(&k1,me,"k1_sigmoid"));
    CHECK(cuModuleGetFunction(&k2,me,"k2_mul_gate"));
    CHECK(cuModuleGetFunction(&k3,me,"k3_mul_up"));

    float *hg=(float*)malloc(bytes), *hu=(float*)malloc(bytes), *hy=(float*)malloc(bytes);
    double *ref=(double*)malloc((size_t)n*sizeof(double));
    uint32_t st=0x0a0b0c0u;
    for(int i=0;i<n;++i){
        st=st*1664525u+1013904223u; hg[i]=((float)(st>>8)/(float)(1u<<24))*6.0f-3.0f; /* [-3,3) */
        st=st*1664525u+1013904223u; hu[i]=((float)(st>>8)/(float)(1u<<24))*2.0f-1.0f; /* [-1,1) */
        ref[i]=silu_ref((double)hg[i])*(double)hu[i];
    }

    CUdeviceptr dg,du,dy,ds,dt;
    CHECK(cuMemAlloc(&dg,bytes)); CHECK(cuMemAlloc(&du,bytes)); CHECK(cuMemAlloc(&dy,bytes));
    CHECK(cuMemAlloc(&ds,bytes)); CHECK(cuMemAlloc(&dt,bytes));
    CHECK(cuMemcpyHtoD(dg,hg,bytes)); CHECK(cuMemcpyHtoD(du,hu,bytes));

    const int TPB=256; unsigned grid=(unsigned)((n+TPB-1)/TPB);
    void *f_args[4]={&dg,&du,&dy,&n};
    void *a1[3]={&dg,&ds,&n};
    void *a2[4]={&dg,&ds,&dt,&n};
    void *a3[4]={&dt,&du,&dy,&n};

    CHECK(cuLaunchKernel(kf,grid,1,1,TPB,1,1,0,NULL,f_args,NULL));
    CHECK(cuCtxSynchronize()); CHECK(cuMemcpyDtoH(hy,dy,bytes));

    double sse=0, ssr=0, max_abs=0, max_rel=0;
    for(int i=0;i<n;++i){
        double g=(double)hy[i], rf=ref[i], e=g-rf;
        sse+=e*e; ssr+=rf*rf; if(fabs(e)>max_abs)max_abs=fabs(e);
    }
    double global_rms_rel=sqrt(sse)/(sqrt(ssr)+1e-12);
    /* per-element scaled rel only on significant magnitudes (honest: skip near-zero) */
    double rms_ref=sqrt(ssr/n);
    for(int i=0;i<n;++i){
        double rf=fabs(ref[i]);
        if(rf > 0.1*rms_ref){ double r=fabs((double)hy[i]-ref[i])/rf; if(r>max_rel)max_rel=r; }
    }
    double tol=1e-2;
    const char *num_verd=(global_rms_rel<=tol && max_rel<=tol)?"PASS":"FAIL";

    CHECK(cuLaunchKernel(k1,grid,1,1,TPB,1,1,0,NULL,a1,NULL));
    CHECK(cuLaunchKernel(k2,grid,1,1,TPB,1,1,0,NULL,a2,NULL));
    CHECK(cuLaunchKernel(k3,grid,1,1,TPB,1,1,0,NULL,a3,NULL));
    CHECK(cuCtxSynchronize());

    CUevent e0,e1; CHECK(cuEventCreate(&e0,0)); CHECK(cuEventCreate(&e1,0));
    double *tf=(double*)malloc(reps*8), *tb=(double*)malloc(reps*8);
    for(int w=0;w<warmup;++w) CHECK(cuLaunchKernel(kf,grid,1,1,TPB,1,1,0,NULL,f_args,NULL));
    CHECK(cuCtxSynchronize());
    for(int rep=0;rep<reps;++rep){ CHECK(cuEventRecord(e0,0));
        CHECK(cuLaunchKernel(kf,grid,1,1,TPB,1,1,0,NULL,f_args,NULL));
        CHECK(cuEventRecord(e1,0)); CHECK(cuEventSynchronize(e1));
        float ms=0; CHECK(cuEventElapsedTime(&ms,e0,e1)); tf[rep]=(double)ms; }
    for(int w=0;w<warmup;++w){
        CHECK(cuLaunchKernel(k1,grid,1,1,TPB,1,1,0,NULL,a1,NULL));
        CHECK(cuLaunchKernel(k2,grid,1,1,TPB,1,1,0,NULL,a2,NULL));
        CHECK(cuLaunchKernel(k3,grid,1,1,TPB,1,1,0,NULL,a3,NULL)); }
    CHECK(cuCtxSynchronize());
    for(int rep=0;rep<reps;++rep){ CHECK(cuEventRecord(e0,0));
        CHECK(cuLaunchKernel(k1,grid,1,1,TPB,1,1,0,NULL,a1,NULL));
        CHECK(cuLaunchKernel(k2,grid,1,1,TPB,1,1,0,NULL,a2,NULL));
        CHECK(cuLaunchKernel(k3,grid,1,1,TPB,1,1,0,NULL,a3,NULL));
        CHECK(cuEventRecord(e1,0)); CHECK(cuEventSynchronize(e1));
        float ms=0; CHECK(cuEventElapsedTime(&ms,e0,e1)); tb[rep]=(double)ms; }

    qsort(tf,reps,8,cmp_double); qsort(tb,reps,8,cmp_double);
    double med_f=tf[reps/2], med_b=tb[reps/2];
    double mu_f=0,mu_b=0; for(int i=0;i<reps;i++){mu_f+=tf[i];mu_b+=tb[i];} mu_f/=reps;mu_b/=reps;
    double sd_f=0,sd_b=0; for(int i=0;i<reps;i++){sd_f+=(tf[i]-mu_f)*(tf[i]-mu_f);sd_b+=(tb[i]-mu_b)*(tb[i]-mu_b);}
    sd_f=sqrt(sd_f/reps);sd_b=sqrt(sd_b/reps);
    double speedup=med_f>0?med_b/med_f:0, pct=med_b>0?(1.0-med_f/med_b)*100.0:0;
    const char *gate=(pct>=30.0)?"PASS":"FAIL";

    printf("F-FUSION-AXISA-SWIGLU n=%d reps=%d\n", n, reps);
    printf("  STRUCTURAL: launches fused=1 eager=3 (ratio 3.0x)\n");
    printf("  STRUCTURAL: HBM/elem fused=2R+1W=3 eager=5R+3W=8 (traffic ratio 2.67x)\n");
    printf("  NUMERIC %s: global_rms_rel=%g max_rel(sig)=%g max_abs=%g tol=%g\n",
        num_verd, global_rms_rel, max_rel, max_abs, tol);
    printf("  TIMED: fused_med=%.5f ms (std %.5f) eager_med=%.5f ms (std %.5f) speedup=%.3fx faster=%.1f%% gate(>=30%%) %s\n",
        med_f, sd_f, med_b, sd_b, speedup, pct, gate);

    FILE *rj=fopen("result_swiglu.json","a");
    fprintf(rj, "{\"workload\":\"swiglu\",\"n\":%d,\"reps\":%d,"
        "\"launch_ratio\":3.0,\"hbm_ratio\":2.6667,"
        "\"numeric_verdict\":\"%s\",\"global_rms_rel\":%g,\"max_rel_sig\":%g,\"max_abs\":%g,"
        "\"fused_med_ms\":%.6f,\"fused_std_ms\":%.6f,\"eager_med_ms\":%.6f,\"eager_std_ms\":%.6f,"
        "\"speedup\":%.4f,\"pct_faster\":%.2f,\"gate30\":\"%s\"}\n",
        n,reps,num_verd,global_rms_rel,max_rel,max_abs,med_f,sd_f,med_b,sd_b,speedup,pct,gate);
    fclose(rj);

    cuMemFree(dg);cuMemFree(du);cuMemFree(dy);cuMemFree(ds);cuMemFree(dt);
    cuEventDestroy(e0);cuEventDestroy(e1); cuModuleUnload(mf);cuModuleUnload(me); cuCtxDestroy(ctx);
    return (strcmp(num_verd,"PASS")==0)?0:1;
}
