/* F-FUSION-LAYERBLOCK-CROSS-LAYER -- round-9 timed wall host (axis C).
 *
 * Fires the merged fused 2-kernel transformer block:
 *   block_fused_k1  (LN -> QKV -> flash-attn -> OUT-proj -> +residual1)
 *   block_fused_k2  (LN2 -> FFN-up -> SiLU*gate -> FFN-down -> +residual2)
 *
 * Shape: flame existence-proof d_model=768, dff=3072, S, n_heads=12, head_dim=64.
 *
 * Numeric gate FIRST: f64 CPU reference of the FULL block; per-row-scaled
 * rel-err <= 1e-2 (repo-standard tol_abs = max_abs_ref * 1e-2). Then time the
 * K1+K2 launch pair (cuEvent: 20 warmup + 200 timed; median + std).
 *
 * Build: nvcc -O2 -o lb_host lb_host.c -lcuda -lm
 * Run:   ./lb_host block_fused_k1.ptx block_fused_k2.ptx [S]
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

static int cmp_double(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

static uint32_t lcg_state = 0x12345678u;
static float lcg_f32(void) {
    lcg_state = lcg_state * 1664525u + 1013904223u;
    return ((float)(lcg_state >> 8) / (float)(1u << 24)) - 0.5f;
}

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s k1.ptx k2.ptx [S]\n", argv[0]); return 2; }
    const char *k1_path = argv[1];
    const char *k2_path = argv[2];
    int S  = (argc > 3) ? atoi(argv[3]) : 512;
    int d  = 768;     /* d_model -- PTX param-driven but harness shapes fixed */
    int dh = 64;      /* head_dim (one head emitted in K1) */
    int dff = 3072;
    float eps = 1e-5f;

    /* read PTX */
    char *ptx1, *ptx2;
    { FILE*fp=fopen(k1_path,"rb"); if(!fp){perror("k1");return 1;}
      fseek(fp,0,SEEK_END); long n=ftell(fp); fseek(fp,0,SEEK_SET);
      ptx1=(char*)malloc(n+1); fread(ptx1,1,n,fp); ptx1[n]=0; fclose(fp); }
    { FILE*fp=fopen(k2_path,"rb"); if(!fp){perror("k2");return 1;}
      fseek(fp,0,SEEK_END); long n=ftell(fp); fseek(fp,0,SEEK_SET);
      ptx2=(char*)malloc(n+1); fread(ptx2,1,n,fp); ptx2[n]=0; fclose(fp); }

    CHECK(cuInit(0));
    CUdevice dev; CHECK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CHECK(cuCtxCreate(&ctx, 0, dev));

    CUjit_option jo[1] = { CU_JIT_TARGET_FROM_CUCONTEXT };
    void *jv[1] = { (void *)0 };
    CUmodule m1, m2;
    CHECK(cuModuleLoadDataEx(&m1, ptx1, 1, jo, jv));
    CHECK(cuModuleLoadDataEx(&m2, ptx2, 1, jo, jv));
    CUfunction fk1, fk2;
    CHECK(cuModuleGetFunction(&fk1, m1, "block_fused_k1"));
    CHECK(cuModuleGetFunction(&fk2, m2, "block_fused_k2"));

    /* ---- host buffers ---- */
    size_t bx   = (size_t)S * d * sizeof(float);   /* [S x d] */
    size_t bwqkv= (size_t)d * dh * sizeof(float);  /* [d x dh] per-head Wq/Wk/Wv */
    size_t bwo  = (size_t)dh * d * sizeof(float);  /* [dh x d] Wo */
    size_t bg   = (size_t)d * sizeof(float);       /* gamma/beta */
    size_t bwup = (size_t)d * dff * sizeof(float); /* [d x dff] Wup/Wgate */
    size_t bwdn = (size_t)dff * d * sizeof(float); /* [dff x d] Wdown */

    float *hx   = (float*)malloc(bx);
    float *hg1  = (float*)malloc(bg), *hb1 = (float*)malloc(bg);
    float *hwq  = (float*)malloc(bwqkv), *hwk = (float*)malloc(bwqkv), *hwv = (float*)malloc(bwqkv);
    float *hwo  = (float*)malloc(bwo);
    float *hg2  = (float*)malloc(bg), *hb2 = (float*)malloc(bg);
    float *hwup = (float*)malloc(bwup), *hwgate = (float*)malloc(bwup), *hwdn = (float*)malloc(bwdn);
    float *hmid = (float*)malloc(bx);   /* K1 output (block intermediate) */
    float *hout = (float*)malloc(bx);   /* K2 output (block output) */

    /* small init for well-conditioned f32 dot products */
    for (size_t i=0;i<(size_t)S*d;i++)   hx[i]   = lcg_f32();
    for (int i=0;i<d;i++){ hg1[i]=1.0f+0.1f*lcg_f32(); hb1[i]=0.05f*lcg_f32();
                           hg2[i]=1.0f+0.1f*lcg_f32(); hb2[i]=0.05f*lcg_f32(); }
    for (size_t i=0;i<(size_t)d*dh;i++){ hwq[i]=lcg_f32()*0.05f; hwk[i]=lcg_f32()*0.05f; hwv[i]=lcg_f32()*0.05f; }
    for (size_t i=0;i<(size_t)dh*d;i++)  hwo[i]=lcg_f32()*0.05f;
    for (size_t i=0;i<(size_t)d*dff;i++){ hwup[i]=lcg_f32()*0.05f; hwgate[i]=lcg_f32()*0.05f; }
    for (size_t i=0;i<(size_t)dff*d;i++) hwdn[i]=lcg_f32()*0.05f;

    float scale_attn = 1.0f / sqrtf((float)dh);
    float inv_dm = 1.0f / (float)d;

    /* ===== f64 CPU reference of the FULL block (1 head) ===== */
    double *ref = (double*)malloc((size_t)S*d*sizeof(double));
    double *xln  = (double*)malloc((size_t)S*d*sizeof(double));
    double *q    = (double*)malloc((size_t)S*dh*sizeof(double));
    double *kk   = (double*)malloc((size_t)S*dh*sizeof(double));
    double *vv   = (double*)malloc((size_t)S*dh*sizeof(double));
    double *attn = (double*)malloc((size_t)S*dh*sizeof(double));
    double *mid  = (double*)malloc((size_t)S*d*sizeof(double)); /* after K1 */

    /* --- K1 ref: LN -> QKV -> attn -> OUT -> +res1 --- */
    for (int r=0;r<S;r++){
        double mu=0; for(int i=0;i<d;i++) mu+=hx[r*d+i]; mu/=d;
        double var=0; for(int i=0;i<d;i++){double t=hx[r*d+i]-mu; var+=t*t;} var/=d;
        double rstd=1.0/sqrt(var+eps);
        for(int i=0;i<d;i++) xln[r*d+i]=(hx[r*d+i]-mu)*rstd*hg1[i]+hb1[i];
    }
    for (int r=0;r<S;r++){
        for(int h=0;h<dh;h++){
            double aq=0,ak=0,av=0;
            for(int i=0;i<d;i++){ double x=xln[r*d+i];
                aq+=x*hwq[i*dh+h]; ak+=x*hwk[i*dh+h]; av+=x*hwv[i*dh+h]; }
            q[r*dh+h]=aq; kk[r*dh+h]=ak; vv[r*dh+h]=av;
        }
    }
    for (int r=0;r<S;r++){
        double mmax=-1e300; double *s=(double*)malloc(S*sizeof(double));
        for(int j=0;j<S;j++){ double dot=0; for(int t=0;t<dh;t++) dot+=q[r*dh+t]*kk[j*dh+t];
            dot*=scale_attn; s[j]=dot; if(dot>mmax)mmax=dot; }
        double l=0; for(int j=0;j<S;j++){ s[j]=exp(s[j]-mmax); l+=s[j]; }
        for(int t=0;t<dh;t++){ double acc=0; for(int j=0;j<S;j++) acc+=s[j]*vv[j*dh+t];
            attn[r*dh+t]=acc/l; }
        free(s);
    }
    /* OUT proj + residual1 -> mid */
    for (int r=0;r<S;r++){
        for(int c=0;c<d;c++){ double o=0; for(int t=0;t<dh;t++) o+=attn[r*dh+t]*hwo[t*d+c];
            mid[r*d+c]=o+hx[r*d+c]; }
    }
    /* --- K2 ref: LN2 -> SwiGLU FFN -> +res2 -> ref --- */
    for (int r=0;r<S;r++){
        double mu=0; for(int i=0;i<d;i++) mu+=mid[r*d+i]; mu/=d;
        double var=0; for(int i=0;i<d;i++){double t=mid[r*d+i]-mu; var+=t*t;} var/=d;
        double rstd=1.0/sqrt(var+eps);
        double xln2[768];
        for(int i=0;i<d;i++) xln2[i]=(mid[r*d+i]-mu)*rstd*hg2[i]+hb2[i];
        for(int c=0;c<d;c++){
            double y=0;
            for(int h=0;h<dff;h++){
                double up=0,ga=0; for(int i=0;i<d;i++){ up+=xln2[i]*hwup[i*dff+h]; ga+=xln2[i]*hwgate[i*dff+h]; }
                double sil=up/(1.0+exp(-up));
                double hsig=sil*ga;
                y+=hsig*hwdn[h*d+c];
            }
            ref[r*d+c]=y+mid[r*d+c];
        }
    }

    /* ===== device buffers ===== */
    CUdeviceptr dx, dg1, db1, dwq, dwk, dwv, dwo, dmid;
    CUdeviceptr dg2, db2, dwup, dwgate, dwdn, dout;
    CHECK(cuMemAlloc(&dx, bx));   CHECK(cuMemAlloc(&dmid, bx));  CHECK(cuMemAlloc(&dout, bx));
    CHECK(cuMemAlloc(&dg1, bg));  CHECK(cuMemAlloc(&db1, bg));
    CHECK(cuMemAlloc(&dwq, bwqkv)); CHECK(cuMemAlloc(&dwk, bwqkv)); CHECK(cuMemAlloc(&dwv, bwqkv));
    CHECK(cuMemAlloc(&dwo, bwo));
    CHECK(cuMemAlloc(&dg2, bg));  CHECK(cuMemAlloc(&db2, bg));
    CHECK(cuMemAlloc(&dwup, bwup)); CHECK(cuMemAlloc(&dwgate, bwup)); CHECK(cuMemAlloc(&dwdn, bwdn));

    CHECK(cuMemcpyHtoD(dx, hx, bx));
    CHECK(cuMemcpyHtoD(dg1, hg1, bg));  CHECK(cuMemcpyHtoD(db1, hb1, bg));
    CHECK(cuMemcpyHtoD(dwq, hwq, bwqkv)); CHECK(cuMemcpyHtoD(dwk, hwk, bwqkv)); CHECK(cuMemcpyHtoD(dwv, hwv, bwqkv));
    CHECK(cuMemcpyHtoD(dwo, hwo, bwo));
    CHECK(cuMemcpyHtoD(dg2, hg2, bg));  CHECK(cuMemcpyHtoD(db2, hb2, bg));
    CHECK(cuMemcpyHtoD(dwup, hwup, bwup)); CHECK(cuMemcpyHtoD(dwgate, hwgate, bwup)); CHECK(cuMemcpyHtoD(dwdn, hwdn, bwdn));

    /* K1 args: x_in, gamma, beta, wq, wk, wv, wo, x_out, n_seq, d_model, inv_d, scale */
    void *k1a[12] = { &dx,&dg1,&db1,&dwq,&dwk,&dwv,&dwo,&dmid,&S,&d,&inv_dm,&scale_attn };
    /* K2 args: x_in(=mid), gamma2, beta2, wup, wgate, wdown, x_out, n_seq, d_model, d_ffn, inv_d */
    void *k2a[11] = { &dmid,&dg2,&db2,&dwup,&dwgate,&dwdn,&dout,&S,&d,&dff,&inv_dm };

    int B1 = 64;  int g1 = (S + B1 - 1)/B1;   /* K1: one query row per thread */
    int B2 = 128; int g2 = (S + B2 - 1)/B2;   /* K2: one row per thread */

    /* correctness fire */
    CHECK(cuLaunchKernel(fk1, g1,1,1, B1,1,1, 0, NULL, k1a, NULL));
    CHECK(cuLaunchKernel(fk2, g2,1,1, B2,1,1, 0, NULL, k2a, NULL));
    CHECK(cuCtxSynchronize());
    CHECK(cuMemcpyDtoH(hout, dout, bx));
    CHECK(cuMemcpyDtoH(hmid, dmid, bx));

    double max_abs_delta=0, max_abs_ref=0;
    for (size_t i=0;i<(size_t)S*d;i++){
        double r=ref[i], h=(double)hout[i];
        double a=fabs(r); if(a>max_abs_ref)max_abs_ref=a;
        double dd=fabs(h-r); if(dd>max_abs_delta)max_abs_delta=dd;
    }
    double tol_abs=(max_abs_ref>0)?max_abs_ref*1e-2:1e-3;
    double max_rel=(max_abs_ref>0)?max_abs_delta/max_abs_ref:max_abs_delta;
    int numeric_pass=(max_abs_delta<=tol_abs);

    /* ===== timed: K1+K2 launch pair ===== */
    const int WARM=20, TIMED=200;
    CUevent e0,e1; CHECK(cuEventCreate(&e0,0)); CHECK(cuEventCreate(&e1,0));
    for(int i=0;i<WARM;i++){
        CHECK(cuLaunchKernel(fk1, g1,1,1, B1,1,1, 0, NULL, k1a, NULL));
        CHECK(cuLaunchKernel(fk2, g2,1,1, B2,1,1, 0, NULL, k2a, NULL));
    }
    CHECK(cuCtxSynchronize());
    double *times=(double*)malloc(TIMED*sizeof(double));
    for(int i=0;i<TIMED;i++){
        CHECK(cuEventRecord(e0,0));
        CHECK(cuLaunchKernel(fk1, g1,1,1, B1,1,1, 0, NULL, k1a, NULL));
        CHECK(cuLaunchKernel(fk2, g2,1,1, B2,1,1, 0, NULL, k2a, NULL));
        CHECK(cuEventRecord(e1,0));
        CHECK(cuEventSynchronize(e1));
        float ms=0; CHECK(cuEventElapsedTime(&ms,e0,e1));
        times[i]=(double)ms;
    }
    qsort(times,TIMED,sizeof(double),cmp_double);
    double median=times[TIMED/2];
    double mean=0; for(int i=0;i<TIMED;i++) mean+=times[i]; mean/=TIMED;
    double var=0; for(int i=0;i<TIMED;i++){double dd=times[i]-mean; var+=dd*dd;} double sd=sqrt(var/TIMED);

    const char *verd = numeric_pass ? "PASS" : "FAIL";
    printf("F-FUSION-LAYERBLOCK-NUMERIC %s -- S=%d d=%d dh=%d dff=%d max_rel=%g tol=1e-2 max_abs_ref=%g\n",
           verd, S, d, dh, dff, max_rel, max_abs_ref);
    printf("FUSED-BLOCK-WALL S=%d launches=2 median_ms=%.6f mean_ms=%.6f std_ms=%.6f std_pct=%.4f\n",
           S, median, mean, sd, (mean>0?100.0*sd/mean:0.0));

    FILE *rj=fopen("lb_result.json","w");
    fprintf(rj,"{\n");
    fprintf(rj,"  \"falsifier\": \"F-FUSION-LAYERBLOCK-CROSS-LAYER-TIMED\",\n");
    fprintf(rj,"  \"kernels\": [\"block_fused_k1\",\"block_fused_k2\"],\n");
    fprintf(rj,"  \"numeric_verdict\": \"%s\",\n", verd);
    fprintf(rj,"  \"S\": %d, \"d\": %d, \"dh\": %d, \"dff\": %d,\n", S,d,dh,dff);
    fprintf(rj,"  \"launches\": 2,\n");
    fprintf(rj,"  \"max_rel\": %g,\n", max_rel);
    fprintf(rj,"  \"max_abs_ref\": %g,\n", max_abs_ref);
    fprintf(rj,"  \"median_ms\": %.6f,\n", median);
    fprintf(rj,"  \"mean_ms\": %.6f,\n", mean);
    fprintf(rj,"  \"std_ms\": %.6f\n", sd);
    fprintf(rj,"}\n");
    fclose(rj);

    cuCtxDestroy(ctx);
    return numeric_pass ? 0 : 1;
}
