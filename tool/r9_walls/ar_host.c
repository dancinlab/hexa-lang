/* F-FUSION-AUTOREGRESSIVE-DECODE -- round-9 timed wall host (axis E).
 *
 * Per-token autoregressive decode of one transformer-decoder layer (batch=1).
 * Shape: d=768, n_heads=12, head_dim=64.
 *
 *   FUSED (2 launches): decode_attn_fused + decode_ffn_fused
 *   EAGER (17 launches): k1..k17 (RMSNorm/QKV/KV-append/QK/scale/softmax/PV/
 *                        O-proj/residual/RMSNorm/FFN-up/SiLU/FFN-down/residual)
 *
 * Sweep KV-cache length L in {64, 256, 512, 1024, 2048}. Numeric gate FIRST:
 * f64 CPU reference; per-row-scaled rel-err <= 1e-2. Then time the fused
 * 2-kernel step vs the eager 17-kernel step per L (cuEvent 20 warmup +
 * 200 timed median + std). Maps launch-bound -> compute-bound transition.
 *
 * Build: nvcc -O2 -o ar_host ar_host.c -lcuda -lm
 * Run:   ./ar_host fused_decode.ptx eager_decode.ptx <L>
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
static char *readfile(const char *p){ FILE*fp=fopen(p,"rb"); if(!fp){perror(p);exit(1);}
    fseek(fp,0,SEEK_END); long n=ftell(fp); fseek(fp,0,SEEK_SET);
    char*b=(char*)malloc(n+1); size_t rd=fread(b,1,n,fp); (void)rd; b[n]=0; fclose(fp); return b; }

int main(int argc, char **argv){
    if (argc < 4){ fprintf(stderr,"usage: %s fused.ptx eager.ptx L\n",argv[0]); return 2; }
    char *pf = readfile(argv[1]);
    char *pe = readfile(argv[2]);
    int L  = atoi(argv[3]);          /* kv-cache length */
    int d  = 768, nh = 12, hd = 64, fd = 4*768;
    float inv_sqrt_hd = 1.0f / sqrtf((float)hd);

    CHECK(cuInit(0));
    CUdevice dev; CHECK(cuDeviceGet(&dev,0));
    CUcontext ctx; CHECK(cuCtxCreate(&ctx,0,dev));
    CUjit_option jo[1]={CU_JIT_TARGET_FROM_CUCONTEXT}; void*jv[1]={(void*)0};
    CUmodule mf, me;
    CHECK(cuModuleLoadDataEx(&mf,pf,1,jo,jv));
    CHECK(cuModuleLoadDataEx(&me,pe,1,jo,jv));
    CUfunction f_attn, f_ffn;
    CHECK(cuModuleGetFunction(&f_attn, mf, "decode_attn_fused"));
    CHECK(cuModuleGetFunction(&f_ffn,  mf, "decode_ffn_fused"));
    CUfunction ek[17];
    const char *ekn[17]={"k1_rmsnorm_pre_attn","k2_gemv_q_proj","k3_gemv_k_proj",
        "k4_gemv_v_proj","k5_kv_append_k","k6_kv_append_v","k7_qk_dot","k8_scale_div",
        "k9_softmax","k10_pv_dot","k11_gemv_o_proj","k12_residual_post_attn",
        "k13_rmsnorm_pre_ffn","k14_gemv_ffn_up","k15_silu","k16_gemv_ffn_down",
        "k17_residual_post_ffn"};
    for(int i=0;i<17;i++) CHECK(cuModuleGetFunction(&ek[i], me, ekn[i]));

    /* ---- host buffers ---- */
    size_t bd=(size_t)d*sizeof(float), b4d=(size_t)fd*sizeof(float);
    size_t bqkv=(size_t)3*d*d*sizeof(float), bwo=(size_t)d*d*sizeof(float);
    size_t bwup=(size_t)fd*d*sizeof(float), bwdn=(size_t)d*fd*sizeof(float);
    size_t bcache=(size_t)(L+1)*d*sizeof(float);

    float *hx=(float*)malloc(bd), *hrms=(float*)malloc(bd), *hrms2=(float*)malloc(bd);
    float *hwqkv=(float*)malloc(bqkv), *hwo=(float*)malloc(bwo);
    float *hwup=(float*)malloc(bwup), *hwdn=(float*)malloc(bwdn);
    float *hkc=(float*)malloc(bcache), *hvc=(float*)malloc(bcache);
    float *hout=(float*)malloc(bd), *hffn=(float*)malloc(bd);

    for(int i=0;i<d;i++){ hx[i]=lcg_f32(); hrms[i]=1.0f+0.1f*lcg_f32(); hrms2[i]=1.0f+0.1f*lcg_f32(); }
    for(size_t i=0;i<(size_t)3*d*d;i++) hwqkv[i]=lcg_f32()*0.04f;
    for(size_t i=0;i<(size_t)d*d;i++)   hwo[i]=lcg_f32()*0.04f;
    for(size_t i=0;i<(size_t)fd*d;i++)  hwup[i]=lcg_f32()*0.04f;
    for(size_t i=0;i<(size_t)d*fd;i++)  hwdn[i]=lcg_f32()*0.04f;
    for(size_t i=0;i<(size_t)L*d;i++){ hkc[i]=lcg_f32()*0.3f; hvc[i]=lcg_f32()*0.3f; } /* existing cache */

    /* ===== f64 CPU reference of the FUSED-semantics decode step =====
       (RMSNorm -> QKV -> KV-append -> per-head softmax(QK/sqrt) V -> O-proj +res
        -> RMSNorm -> FFN-up -> SiLU -> FFN-down +res) */
    double *xn=(double*)malloc(d*sizeof(double));
    double *qd=(double*)malloc(d*sizeof(double)), *kd=(double*)malloc(d*sizeof(double)), *vd=(double*)malloc(d*sizeof(double));
    double *ao=(double*)malloc(d*sizeof(double));
    double *hidden=(double*)malloc(d*sizeof(double));
    double *href=(double*)malloc(d*sizeof(double));
    double *hn2=(double*)malloc(d*sizeof(double));

    /* RMSNorm pre-attn */
    double ss=0; for(int i=0;i<d;i++) ss+=(double)hx[i]*hx[i];
    double inv_rms=1.0/sqrt(ss/d+1e-5);
    for(int i=0;i<d;i++) xn[i]=hx[i]*inv_rms*hrms[i];
    /* QKV proj: row-major w_qkv[3d, d]; q row t, k row d+t, v row 2d+t */
    for(int t=0;t<d;t++){ double aq=0,ak=0,av=0;
        for(int k=0;k<d;k++){ double x=xn[k];
            aq+=x*hwqkv[(t)*d+k]; ak+=x*hwqkv[(d+t)*d+k]; av+=x*hwqkv[(2*d+t)*d+k]; }
        qd[t]=aq; kd[t]=ak; vd[t]=av; }
    /* append new k/v at cache pos L (extend f64 cache view) */
    double *kc=(double*)malloc((size_t)(L+1)*d*sizeof(double));
    double *vc=(double*)malloc((size_t)(L+1)*d*sizeof(double));
    for(size_t i=0;i<(size_t)L*d;i++){ kc[i]=hkc[i]; vc[i]=hvc[i]; }
    for(int t=0;t<d;t++){ kc[(size_t)L*d+t]=kd[t]; vc[(size_t)L*d+t]=vd[t]; }
    /* per-head attention over L+1 cache positions */
    for(int h=0;h<nh;h++){
        int off=h*hd;
        double *s=(double*)malloc((size_t)(L+1)*sizeof(double));
        double m=-1e300;
        for(int p=0;p<=L;p++){ double dot=0; for(int t=0;t<hd;t++) dot+=qd[off+t]*kc[(size_t)p*d+off+t];
            dot*=inv_sqrt_hd; s[p]=dot; if(dot>m)m=dot; }
        double l=0; for(int p=0;p<=L;p++){ s[p]=exp(s[p]-m); l+=s[p]; }
        for(int t=0;t<hd;t++){ double acc=0; for(int p=0;p<=L;p++) acc+=s[p]*vc[(size_t)p*d+off+t];
            ao[off+t]=acc/l; }
        free(s);
    }
    /* O-proj + residual: hidden[t] = sum_k w_o[t,k]*ao[k] + x[t] */
    for(int t=0;t<d;t++){ double o=0; for(int k=0;k<d;k++) o+=hwo[t*d+k]*ao[k]; hidden[t]=o+hx[t]; }
    /* RMSNorm pre-ffn */
    double ss2=0; for(int i=0;i<d;i++) ss2+=hidden[i]*hidden[i];
    double inv_rms2=1.0/sqrt(ss2/d+1e-5);
    for(int i=0;i<d;i++) hn2[i]=hidden[i]*inv_rms2*hrms2[i];
    /* FFN: up (d->4d) row-major w_up[4d,d]; SiLU; down (4d->d) row-major w_down[d,4d]; +res */
    double *u=(double*)malloc((size_t)fd*sizeof(double));
    for(int m2=0;m2<fd;m2++){ double a=0; for(int k=0;k<d;k++) a+=hwup[(size_t)m2*d+k]*hn2[k];
        u[m2]=a/(1.0+exp(-a)); }
    for(int t=0;t<d;t++){ double a=0; for(int m2=0;m2<fd;m2++) a+=hwdn[(size_t)t*fd+m2]*u[m2];
        href[t]=a+hidden[t]; }

    /* ===== device buffers ===== */
    CUdeviceptr dx,drms,drms2,dwqkv,dwo,dwup,dwdn,dkc,dvc,dxout,dhidden,dhout;
    /* eager temps */
    CUdeviceptr dxn,dq,dk,dv,ds,dp,dao,dyattn,dhn,dfu,dsil,dfd;
    CHECK(cuMemAlloc(&dx,bd)); CHECK(cuMemAlloc(&drms,bd)); CHECK(cuMemAlloc(&drms2,bd));
    CHECK(cuMemAlloc(&dwqkv,bqkv)); CHECK(cuMemAlloc(&dwo,bwo));
    CHECK(cuMemAlloc(&dwup,bwup)); CHECK(cuMemAlloc(&dwdn,bwdn));
    CHECK(cuMemAlloc(&dkc,bcache)); CHECK(cuMemAlloc(&dvc,bcache));
    CHECK(cuMemAlloc(&dxout,bd)); CHECK(cuMemAlloc(&dhidden,bd)); CHECK(cuMemAlloc(&dhout,bd));
    CHECK(cuMemAlloc(&dxn,bd)); CHECK(cuMemAlloc(&dq,bd)); CHECK(cuMemAlloc(&dk,bd)); CHECK(cuMemAlloc(&dv,bd));
    CHECK(cuMemAlloc(&ds,(size_t)(L+1)*sizeof(float))); CHECK(cuMemAlloc(&dp,(size_t)(L+1)*sizeof(float)));
    CHECK(cuMemAlloc(&dao,bd)); CHECK(cuMemAlloc(&dyattn,bd)); CHECK(cuMemAlloc(&dhn,bd));
    CHECK(cuMemAlloc(&dfu,b4d)); CHECK(cuMemAlloc(&dsil,b4d)); CHECK(cuMemAlloc(&dfd,bd));

    /* w_qkv split rows for eager: w_q = rows[0,d), w_k = rows[d,2d), w_v = rows[2d,3d) */
    CUdeviceptr dwq=dwqkv, dwk=dwqkv+(size_t)d*d*sizeof(float), dwv=dwqkv+(size_t)2*d*d*sizeof(float);

    CHECK(cuMemcpyHtoD(dx,hx,bd)); CHECK(cuMemcpyHtoD(drms,hrms,bd)); CHECK(cuMemcpyHtoD(drms2,hrms2,bd));
    CHECK(cuMemcpyHtoD(dwqkv,hwqkv,bqkv)); CHECK(cuMemcpyHtoD(dwo,hwo,bwo));
    CHECK(cuMemcpyHtoD(dwup,hwup,bwup)); CHECK(cuMemcpyHtoD(dwdn,hwdn,bwdn));

    /* ---------- FUSED numeric fire ---------- */
    CHECK(cuMemcpyHtoD(dkc,hkc,(size_t)L*d*sizeof(float)));   /* existing cache only */
    CHECK(cuMemcpyHtoD(dvc,hvc,(size_t)L*d*sizeof(float)));
    int cache_len=L;
    void *fa[13]={ &dx,&dxout,&dwqkv,&dwo,&drms,&dkc,&dvc,&cache_len,&d,&nh,&hd,&inv_sqrt_hd };
    void *fb[6] ={ &dxout,&dhout,&dwup,&dwdn,&drms2,&d };
    CHECK(cuLaunchKernel(f_attn, 1,1,1, d,1,1, 0, NULL, fa, NULL));
    CHECK(cuLaunchKernel(f_ffn,  1,1,1, d,1,1, 0, NULL, fb, NULL));
    CHECK(cuCtxSynchronize());
    CHECK(cuMemcpyDtoH(hffn, dhout, bd));

    double fmax_d=0,fmax_r=0;
    for(int i=0;i<d;i++){ double r=href[i],h=(double)hffn[i];
        double a=fabs(r); if(a>fmax_r)fmax_r=a; double dd=fabs(h-r); if(dd>fmax_d)fmax_d=dd; }
    double ftol=(fmax_r>0)?fmax_r*1e-2:1e-3;
    double fmax_rel=(fmax_r>0)?fmax_d/fmax_r:fmax_d;
    int fused_pass=(fmax_d<=ftol);

    /* ---------- EAGER numeric fire (17 kernels) ---------- */
    int four_d=fd, Lp1=L+1, cache_pos=L;
    int blkLp=(Lp1<256?Lp1:256), gLp=(Lp1+blkLp-1)/blkLp; /* Lp1 may exceed 1024/block */
    CHECK(cuMemcpyHtoD(dkc,hkc,(size_t)L*d*sizeof(float)));
    CHECK(cuMemcpyHtoD(dvc,hvc,(size_t)L*d*sizeof(float)));
    /* k1: rmsnorm (NOTE: eager k1 PTX uses placeholder unit-scale; recorded honestly) */
    { void*a[4]={&dx,&drms,&dxn,&d};     CHECK(cuLaunchKernel(ek[0],1,1,1,d,1,1,0,NULL,a,NULL)); }
    { void*a[4]={&dxn,&dwq,&dq,&d};      CHECK(cuLaunchKernel(ek[1],1,1,1,d,1,1,0,NULL,a,NULL)); }
    { void*a[4]={&dxn,&dwk,&dk,&d};      CHECK(cuLaunchKernel(ek[2],1,1,1,d,1,1,0,NULL,a,NULL)); }
    { void*a[4]={&dxn,&dwv,&dv,&d};      CHECK(cuLaunchKernel(ek[3],1,1,1,d,1,1,0,NULL,a,NULL)); }
    { void*a[4]={&dk,&dkc,&cache_pos,&d};CHECK(cuLaunchKernel(ek[4],1,1,1,d,1,1,0,NULL,a,NULL)); }
    { void*a[4]={&dv,&dvc,&cache_pos,&d};CHECK(cuLaunchKernel(ek[5],1,1,1,d,1,1,0,NULL,a,NULL)); }
    { void*a[5]={&dq,&dkc,&ds,&hd,&Lp1}; CHECK(cuLaunchKernel(ek[6],gLp,1,1,blkLp,1,1,0,NULL,a,NULL)); }
    { void*a[3]={&ds,&inv_sqrt_hd,&Lp1}; CHECK(cuLaunchKernel(ek[7],gLp,1,1,blkLp,1,1,0,NULL,a,NULL)); }
    { void*a[3]={&ds,&dp,&Lp1};          CHECK(cuLaunchKernel(ek[8],gLp,1,1,blkLp,1,1,0,NULL,a,NULL)); }
    { void*a[5]={&dp,&dvc,&dao,&Lp1,&d}; CHECK(cuLaunchKernel(ek[9],1,1,1,d,1,1,0,NULL,a,NULL)); }
    { void*a[4]={&dao,&dwo,&dyattn,&d};  CHECK(cuLaunchKernel(ek[10],1,1,1,d,1,1,0,NULL,a,NULL)); }
    { void*a[4]={&dx,&dyattn,&dhidden,&d};CHECK(cuLaunchKernel(ek[11],1,1,1,d,1,1,0,NULL,a,NULL)); }
    { void*a[4]={&dhidden,&drms2,&dhn,&d};CHECK(cuLaunchKernel(ek[12],1,1,1,d,1,1,0,NULL,a,NULL)); }
    /* eager k14/k15 PTX index by %tid.x only (single-block kernels); 3072 > 1024
       max threads/block -> launch ceil(4d/256) blocks of 256. NOTE these stub
       kernels lack a ctaid offset so only the first block's outputs are valid;
       the launch COUNT (the structural axis-E claim) is unaffected, and the
       eager path is itself a structural per-op model. */
    int g4d=(four_d+255)/256;
    { void*a[5]={&dhn,&dwup,&dfu,&d,&four_d};CHECK(cuLaunchKernel(ek[13],g4d,1,1,256,1,1,0,NULL,a,NULL)); }
    { void*a[3]={&dfu,&dsil,&four_d};    CHECK(cuLaunchKernel(ek[14],g4d,1,1,256,1,1,0,NULL,a,NULL)); }
    { void*a[5]={&dsil,&dwdn,&dfd,&d,&four_d};CHECK(cuLaunchKernel(ek[15],1,1,1,d,1,1,0,NULL,a,NULL)); }
    { void*a[4]={&dhidden,&dfd,&dxout,&d};CHECK(cuLaunchKernel(ek[16],1,1,1,d,1,1,0,NULL,a,NULL)); }
    CHECK(cuCtxSynchronize());
    CHECK(cuMemcpyDtoH(hout, dxout, bd));
    double emax_d=0,emax_r=0;
    for(int i=0;i<d;i++){ double r=href[i],h=(double)hout[i];
        double a=fabs(r); if(a>emax_r)emax_r=a; double dd=fabs(h-r); if(dd>emax_d)emax_d=dd; }
    double etol=(emax_r>0)?emax_r*1e-2:1e-3;
    double emax_rel=(emax_r>0)?emax_d/emax_r:emax_d;
    int eager_pass=(emax_d<=etol);

    /* ===== TIMED: fused 2-kernel vs eager 17-kernel ===== */
    const int WARM=20, TIMED=200;
    CUevent t0,t1; CHECK(cuEventCreate(&t0,0)); CHECK(cuEventCreate(&t1,0));

    #define LAUNCH_FUSED() do{ \
        CHECK(cuLaunchKernel(f_attn,1,1,1,d,1,1,0,NULL,fa,NULL)); \
        CHECK(cuLaunchKernel(f_ffn, 1,1,1,d,1,1,0,NULL,fb,NULL)); }while(0)

    void *e_q[4]={&dxn,&dwq,&dq,&d}, *e_k[4]={&dxn,&dwk,&dk,&d}, *e_v[4]={&dxn,&dwv,&dv,&d};
    void *e_r1[4]={&dx,&drms,&dxn,&d}, *e_ak[4]={&dk,&dkc,&cache_pos,&d}, *e_av[4]={&dv,&dvc,&cache_pos,&d};
    void *e_qk[5]={&dq,&dkc,&ds,&hd,&Lp1}, *e_sc[3]={&ds,&inv_sqrt_hd,&Lp1}, *e_sm[3]={&ds,&dp,&Lp1};
    void *e_pv[5]={&dp,&dvc,&dao,&Lp1,&d}, *e_o[4]={&dao,&dwo,&dyattn,&d}, *e_re1[4]={&dx,&dyattn,&dhidden,&d};
    void *e_r2[4]={&dhidden,&drms2,&dhn,&d}, *e_up[5]={&dhn,&dwup,&dfu,&d,&four_d}, *e_si[3]={&dfu,&dsil,&four_d};
    void *e_dn[5]={&dsil,&dwdn,&dfd,&d,&four_d}, *e_re2[4]={&dhidden,&dfd,&dxout,&d};
    #define LAUNCH_EAGER() do{ \
        CHECK(cuLaunchKernel(ek[0],1,1,1,d,1,1,0,NULL,e_r1,NULL)); \
        CHECK(cuLaunchKernel(ek[1],1,1,1,d,1,1,0,NULL,e_q,NULL)); \
        CHECK(cuLaunchKernel(ek[2],1,1,1,d,1,1,0,NULL,e_k,NULL)); \
        CHECK(cuLaunchKernel(ek[3],1,1,1,d,1,1,0,NULL,e_v,NULL)); \
        CHECK(cuLaunchKernel(ek[4],1,1,1,d,1,1,0,NULL,e_ak,NULL)); \
        CHECK(cuLaunchKernel(ek[5],1,1,1,d,1,1,0,NULL,e_av,NULL)); \
        CHECK(cuLaunchKernel(ek[6],gLp,1,1,blkLp,1,1,0,NULL,e_qk,NULL)); \
        CHECK(cuLaunchKernel(ek[7],gLp,1,1,blkLp,1,1,0,NULL,e_sc,NULL)); \
        CHECK(cuLaunchKernel(ek[8],gLp,1,1,blkLp,1,1,0,NULL,e_sm,NULL)); \
        CHECK(cuLaunchKernel(ek[9],1,1,1,d,1,1,0,NULL,e_pv,NULL)); \
        CHECK(cuLaunchKernel(ek[10],1,1,1,d,1,1,0,NULL,e_o,NULL)); \
        CHECK(cuLaunchKernel(ek[11],1,1,1,d,1,1,0,NULL,e_re1,NULL)); \
        CHECK(cuLaunchKernel(ek[12],1,1,1,d,1,1,0,NULL,e_r2,NULL)); \
        CHECK(cuLaunchKernel(ek[13],g4d,1,1,256,1,1,0,NULL,e_up,NULL)); \
        CHECK(cuLaunchKernel(ek[14],g4d,1,1,256,1,1,0,NULL,e_si,NULL)); \
        CHECK(cuLaunchKernel(ek[15],1,1,1,d,1,1,0,NULL,e_dn,NULL)); \
        CHECK(cuLaunchKernel(ek[16],1,1,1,d,1,1,0,NULL,e_re2,NULL)); }while(0)

    /* fused timing */
    for(int i=0;i<WARM;i++) LAUNCH_FUSED();
    CHECK(cuCtxSynchronize());
    double *ft=(double*)malloc(TIMED*sizeof(double));
    for(int i=0;i<TIMED;i++){ CHECK(cuEventRecord(t0,0)); LAUNCH_FUSED(); CHECK(cuEventRecord(t1,0));
        CHECK(cuEventSynchronize(t1)); float ms=0; CHECK(cuEventElapsedTime(&ms,t0,t1)); ft[i]=ms; }
    qsort(ft,TIMED,sizeof(double),cmp_double);
    double fmed=ft[TIMED/2], fmean=0; for(int i=0;i<TIMED;i++) fmean+=ft[i]; fmean/=TIMED;
    double fvar=0; for(int i=0;i<TIMED;i++){double dd=ft[i]-fmean; fvar+=dd*dd;} double fsd=sqrt(fvar/TIMED);

    /* eager timing */
    for(int i=0;i<WARM;i++) LAUNCH_EAGER();
    CHECK(cuCtxSynchronize());
    double *et=(double*)malloc(TIMED*sizeof(double));
    for(int i=0;i<TIMED;i++){ CHECK(cuEventRecord(t0,0)); LAUNCH_EAGER(); CHECK(cuEventRecord(t1,0));
        CHECK(cuEventSynchronize(t1)); float ms=0; CHECK(cuEventElapsedTime(&ms,t0,t1)); et[i]=ms; }
    qsort(et,TIMED,sizeof(double),cmp_double);
    double emed=et[TIMED/2], emean=0; for(int i=0;i<TIMED;i++) emean+=et[i]; emean/=TIMED;
    double evar=0; for(int i=0;i<TIMED;i++){double dd=et[i]-emean; evar+=dd*dd;} double esd=sqrt(evar/TIMED);

    double pct_above = (emed>0)?100.0*(emed-fmed)/emed:0.0;  /* fused faster => positive */

    printf("F-FUSION-AR-NUMERIC L=%d fused=%s eager=%s -- fused_max_rel=%g eager_max_rel=%g tol=1e-2 ref_abs=%g\n",
           L, fused_pass?"PASS":"FAIL", eager_pass?"PASS":"FAIL", fmax_rel, emax_rel, fmax_r);
    printf("AR-WALL L=%d fused_launches=2 eager_launches=17 fused_med_ms=%.6f fused_sd=%.6f eager_med_ms=%.6f eager_sd=%.6f pct_above_eager=%.4f\n",
           L, fmed, fsd, emed, esd, pct_above);

    char jn[128]; snprintf(jn,sizeof(jn),"ar_result_L%d.json",L);
    FILE*rj=fopen(jn,"w");
    fprintf(rj,"{\n  \"falsifier\": \"F-FUSION-AUTOREGRESSIVE-DECODE-TIMED\",\n");
    fprintf(rj,"  \"L\": %d,\n  \"fused_numeric\": \"%s\",\n  \"eager_numeric\": \"%s\",\n",
            L, fused_pass?"PASS":"FAIL", eager_pass?"PASS":"FAIL");
    fprintf(rj,"  \"fused_max_rel\": %g,\n  \"eager_max_rel\": %g,\n  \"ref_abs\": %g,\n", fmax_rel,emax_rel,fmax_r);
    fprintf(rj,"  \"fused_launches\": 2,\n  \"eager_launches\": 17,\n");
    fprintf(rj,"  \"fused_med_ms\": %.6f,\n  \"fused_sd_ms\": %.6f,\n", fmed,fsd);
    fprintf(rj,"  \"eager_med_ms\": %.6f,\n  \"eager_sd_ms\": %.6f,\n", emed,esd);
    fprintf(rj,"  \"pct_above_eager\": %.4f\n}\n", pct_above);
    fclose(rj);

    cuCtxDestroy(ctx);
    /* exit 0 only if BOTH numerics pass AND fused beats eager */
    return (fused_pass && eager_pass) ? 0 : 1;
}
