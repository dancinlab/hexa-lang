/* F-FUSION-AXISA-SOFTMAX -- fused 1-kernel softmax vs eager 4-launch baseline.
 *
 * y[row,j] = exp(x - max_row) / sum_j exp(x - max_row)   (row-wise softmax)
 *
 *   fused: softmax_fused.ptx  (1 launch, smem max+sum reductions, no HBM e)
 *   eager: softmax_eager.ptx  (k1_row_max, k2_exp, k3_row_sum, k4_div = 4 launches)
 *
 * HBM/elem: fused 3R+1W=4 ; eager 4R+2W=6.
 * Numeric: HONEST per-row-scaled RMS rel metric (softmax probs go near zero;
 *   naive |err|/(|want|+eps) would explode -- per-row RMS is the correct gate).
 *   tol 1e-2 (ex2.approx.f32 ~2^-12 rel bound).
 *
 * Build: nvcc -O2 -o host_softmax host_softmax.c -lcuda -lm
 * Run:   ./host_softmax softmax_fused.ptx softmax_eager.ptx [rows] [d] [reps]
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
    FILE *fp = fopen(path, "rb"); if (!fp){perror(path);exit(1);}
    fseek(fp,0,SEEK_END); long n=ftell(fp); fseek(fp,0,SEEK_SET);
    char *buf=(char*)malloc(n+1); if(fread(buf,1,n,fp)!=(size_t)n){perror("read");exit(1);}
    buf[n]=0; fclose(fp); return buf;
}
static int cmp_double(const void *a, const void *b){
    double x=*(const double*)a,y=*(const double*)b; return (x<y)?-1:(x>y)?1:0;
}

int main(int argc, char **argv) {
    if (argc < 3){ fprintf(stderr,"usage: %s fused.ptx eager.ptx [rows] [d] [reps]\n",argv[0]); return 2; }
    int rows = (argc>3)?atoi(argv[3]):4096;
    int d    = (argc>4)?atoi(argv[4]):4096;
    int reps = (argc>5)?atoi(argv[5]):200;
    const int warmup=20;
    size_t total=(size_t)rows*d, bytes=total*sizeof(float);

    char *fp=slurp(argv[1]), *ep=slurp(argv[2]);
    CHECK(cuInit(0));
    CUdevice dev; CHECK(cuDeviceGet(&dev,0));
    CUcontext ctx; CHECK(cuCtxCreate(&ctx,0,dev));
    CUmodule mf,me;
    CUjit_option jo[1]={CU_JIT_TARGET_FROM_CUCONTEXT}; void*jv[1]={(void*)0};
    CHECK(cuModuleLoadDataEx(&mf,fp,1,jo,jv));
    CHECK(cuModuleLoadDataEx(&me,ep,1,jo,jv));
    CUfunction kf,k1,k2,k3,k4;
    CHECK(cuModuleGetFunction(&kf,mf,"softmax_fused"));
    CHECK(cuModuleGetFunction(&k1,me,"k1_row_max"));
    CHECK(cuModuleGetFunction(&k2,me,"k2_exp"));
    CHECK(cuModuleGetFunction(&k3,me,"k3_row_sum"));
    CHECK(cuModuleGetFunction(&k4,me,"k4_div"));

    float *hx=(float*)malloc(bytes), *hy=(float*)malloc(bytes);
    double *ref=(double*)malloc(total*sizeof(double));
    uint32_t st=0x0f0e0d0u;
    for(size_t i=0;i<total;++i){ st=st*1664525u+1013904223u; hx[i]=((float)(st>>8)/(float)(1u<<24))*8.0f-4.0f; } /* [-4,4) */
    for(int r=0;r<rows;++r){
        const float *xr=hx+(size_t)r*d; double mx=-1e300;
        for(int j=0;j<d;++j) if((double)xr[j]>mx) mx=(double)xr[j];
        double s=0; for(int j=0;j<d;++j) s+=exp((double)xr[j]-mx);
        for(int j=0;j<d;++j) ref[(size_t)r*d+j]=exp((double)xr[j]-mx)/s;
    }

    CUdeviceptr dx,dy,dmx,dsm,de;
    CHECK(cuMemAlloc(&dx,bytes)); CHECK(cuMemAlloc(&dy,bytes));
    CHECK(cuMemAlloc(&dmx,(size_t)rows*4)); CHECK(cuMemAlloc(&dsm,(size_t)rows*4)); CHECK(cuMemAlloc(&de,bytes));
    CHECK(cuMemcpyHtoD(dx,hx,bytes));

    const int TPB=256; unsigned grid_rows=(unsigned)rows;
    unsigned grid_elem=(unsigned)((total+TPB-1)/TPB); unsigned total_u=(unsigned)total;
    void *f_args[3]={&dx,&dy,&d};
    void *a1[3]={&dx,&dmx,&d};
    void *a2[5]={&dx,&dmx,&de,&d,&total_u};
    void *a3[3]={&de,&dsm,&d};
    void *a4[5]={&de,&dsm,&dy,&d,&total_u};

    CHECK(cuLaunchKernel(kf,grid_rows,1,1,TPB,1,1,0,NULL,f_args,NULL));
    CHECK(cuCtxSynchronize()); CHECK(cuMemcpyDtoH(hy,dy,bytes));

    double max_row_rel=0, sse=0, ssr=0, max_abs=0;
    for(int r=0;r<rows;++r){
        double se=0,sr=0;
        for(int j=0;j<d;++j){ double g=(double)hy[(size_t)r*d+j], rf=ref[(size_t)r*d+j], e=g-rf;
            se+=e*e; sr+=rf*rf; if(fabs(e)>max_abs)max_abs=fabs(e); }
        double rr=sqrt(se/d)/(sqrt(sr/d)+1e-12); if(rr>max_row_rel)max_row_rel=rr;
        sse+=se; ssr+=sr;
    }
    double global_rms_rel=sqrt(sse)/(sqrt(ssr)+1e-12), tol=1e-2;
    const char *num_verd=(max_row_rel<=tol && global_rms_rel<=tol)?"PASS":"FAIL";

    CHECK(cuLaunchKernel(k1,grid_rows,1,1,TPB,1,1,0,NULL,a1,NULL));
    CHECK(cuLaunchKernel(k2,grid_elem,1,1,TPB,1,1,0,NULL,a2,NULL));
    CHECK(cuLaunchKernel(k3,grid_rows,1,1,TPB,1,1,0,NULL,a3,NULL));
    CHECK(cuLaunchKernel(k4,grid_elem,1,1,TPB,1,1,0,NULL,a4,NULL));
    CHECK(cuCtxSynchronize());

    CUevent e0,e1; CHECK(cuEventCreate(&e0,0)); CHECK(cuEventCreate(&e1,0));
    double *tf=(double*)malloc(reps*8), *tb=(double*)malloc(reps*8);
    for(int w=0;w<warmup;++w) CHECK(cuLaunchKernel(kf,grid_rows,1,1,TPB,1,1,0,NULL,f_args,NULL));
    CHECK(cuCtxSynchronize());
    for(int rep=0;rep<reps;++rep){ CHECK(cuEventRecord(e0,0));
        CHECK(cuLaunchKernel(kf,grid_rows,1,1,TPB,1,1,0,NULL,f_args,NULL));
        CHECK(cuEventRecord(e1,0)); CHECK(cuEventSynchronize(e1));
        float ms=0; CHECK(cuEventElapsedTime(&ms,e0,e1)); tf[rep]=(double)ms; }
    for(int w=0;w<warmup;++w){
        CHECK(cuLaunchKernel(k1,grid_rows,1,1,TPB,1,1,0,NULL,a1,NULL));
        CHECK(cuLaunchKernel(k2,grid_elem,1,1,TPB,1,1,0,NULL,a2,NULL));
        CHECK(cuLaunchKernel(k3,grid_rows,1,1,TPB,1,1,0,NULL,a3,NULL));
        CHECK(cuLaunchKernel(k4,grid_elem,1,1,TPB,1,1,0,NULL,a4,NULL)); }
    CHECK(cuCtxSynchronize());
    for(int rep=0;rep<reps;++rep){ CHECK(cuEventRecord(e0,0));
        CHECK(cuLaunchKernel(k1,grid_rows,1,1,TPB,1,1,0,NULL,a1,NULL));
        CHECK(cuLaunchKernel(k2,grid_elem,1,1,TPB,1,1,0,NULL,a2,NULL));
        CHECK(cuLaunchKernel(k3,grid_rows,1,1,TPB,1,1,0,NULL,a3,NULL));
        CHECK(cuLaunchKernel(k4,grid_elem,1,1,TPB,1,1,0,NULL,a4,NULL));
        CHECK(cuEventRecord(e1,0)); CHECK(cuEventSynchronize(e1));
        float ms=0; CHECK(cuEventElapsedTime(&ms,e0,e1)); tb[rep]=(double)ms; }

    qsort(tf,reps,8,cmp_double); qsort(tb,reps,8,cmp_double);
    double med_f=tf[reps/2], med_b=tb[reps/2];
    double mu_f=0,mu_b=0; for(int i=0;i<reps;i++){mu_f+=tf[i];mu_b+=tb[i];} mu_f/=reps;mu_b/=reps;
    double sd_f=0,sd_b=0; for(int i=0;i<reps;i++){sd_f+=(tf[i]-mu_f)*(tf[i]-mu_f);sd_b+=(tb[i]-mu_b)*(tb[i]-mu_b);}
    sd_f=sqrt(sd_f/reps);sd_b=sqrt(sd_b/reps);
    double speedup=med_f>0?med_b/med_f:0, pct=med_b>0?(1.0-med_f/med_b)*100.0:0;
    const char *gate=(pct>=30.0)?"PASS":"FAIL";

    printf("F-FUSION-AXISA-SOFTMAX rows=%d d=%d reps=%d\n", rows, d, reps);
    printf("  STRUCTURAL: launches fused=1 eager=4 (ratio 4.0x)\n");
    printf("  STRUCTURAL: HBM/elem fused=3R+1W=4 eager=4R+2W=6 (traffic ratio 1.50x)\n");
    printf("  NUMERIC %s: max_row_rel=%g global_rms_rel=%g max_abs=%g tol=%g\n",
        num_verd, max_row_rel, global_rms_rel, max_abs, tol);
    printf("  TIMED: fused_med=%.5f ms (std %.5f) eager_med=%.5f ms (std %.5f) speedup=%.3fx faster=%.1f%% gate(>=30%%) %s\n",
        med_f, sd_f, med_b, sd_b, speedup, pct, gate);

    FILE *rj=fopen("result_softmax.json","a");
    fprintf(rj, "{\"workload\":\"softmax\",\"rows\":%d,\"d\":%d,\"reps\":%d,"
        "\"launch_ratio\":4.0,\"hbm_ratio\":1.5,"
        "\"numeric_verdict\":\"%s\",\"max_row_rel\":%g,\"global_rms_rel\":%g,\"max_abs\":%g,"
        "\"fused_med_ms\":%.6f,\"fused_std_ms\":%.6f,\"eager_med_ms\":%.6f,\"eager_std_ms\":%.6f,"
        "\"speedup\":%.4f,\"pct_faster\":%.2f,\"gate30\":\"%s\"}\n",
        rows,d,reps,num_verd,max_row_rel,global_rms_rel,max_abs,med_f,sd_f,med_b,sd_b,speedup,pct,gate);
    fclose(rj);

    cuMemFree(dx);cuMemFree(dy);cuMemFree(dmx);cuMemFree(dsm);cuMemFree(de);
    cuEventDestroy(e0);cuEventDestroy(e1); cuModuleUnload(mf);cuModuleUnload(me); cuCtxDestroy(ctx);
    return (strcmp(num_verd,"PASS")==0)?0:1;
}
