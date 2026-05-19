/* r049_stage2_mm_lc.cu — RFC 049 Stage 2 fire-validation (matmul + layercast).
 *
 * Completes RFC 049 Stage 2: the FFN entry point was fire-validated by
 * r049_stage2_validate.cu; this harness fires the remaining two wired forge
 * entry points THROUGH their storage classes — the production code path.
 *
 *   hexa_farr_matmul_bf16_gpu        — C[M,N]=A[M,K]@B[K,N], all farr_bf16
 *   hexa_farr_layercast_linear_bf16_gpu — Y[M,N]=X[M,K]@W[K,N], W BF16, X/Y FP32
 *
 * Falsifiers (per entry point): WIRED-CORRECT (vs reference), WIRED-PERF,
 * WIRED-DET (within-run bit-equal).
 *
 * Shims the 2-symbol runtime_cuda.c surface (g_cublas + _ensure_cublas) and
 * #includes runtime_bf16.c — the same production path forge uses.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cuda_bf16.h>

static cublasHandle_t g_cublas = NULL;
static int _ensure_cublas(void) {
    if (g_cublas) return 0;
    return (cublasCreate(&g_cublas) == CUBLAS_STATUS_SUCCESS) ? 0 : -1;
}
#define HEXA_CUDA 1
#include "../runtime_bf16.c"

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { fprintf(stderr, "[MMLC] CUDA %s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(_e)); exit(1); } } while (0)
#define CB(call) do { cublasStatus_t _s = (call); if (_s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "[MMLC] cuBLAS %s:%d %d\n", __FILE__, __LINE__, (int)_s); exit(1); } } while (0)

static double now_sec(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}
static double lcg_next(uint64_t* st) {
    *st = (*st) * 6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(((*st) >> 11) & 0x1FFFFFFFFFFFFFULL) / (double)(1ULL << 53);
}
static int dcmp(const void* a, const void* b) {
    double aa = *(const double*)a, bb = *(const double*)b;
    return (aa > bb) - (aa < bb);
}
static double median(double* a, int n) { qsort(a, n, sizeof(double), dcmp); return a[n/2]; }

struct res {
    char kind[12];
    int M, K, N;
    double t_ref_ms, t_forge_ms, speedup;
    double max_rel_delta;
    int within_run_biteq;
    int correct_pass, perf_pass, det_pass;
};

/* ── matmul: C[M,N] = A[M,K] @ B[K,N], wired hexa_farr_matmul_bf16_gpu ── */
static res run_matmul(cublasHandle_t h, int M, int K, int N, int n_warm, int n_iter) {
    res r; memset(&r, 0, sizeof(r));
    strcpy(r.kind, "matmul"); r.M = M; r.K = K; r.N = N;
    fprintf(stderr, "[MMLC] === matmul M=%d K=%d N=%d ===\n", M, K, N);
    size_t nA=(size_t)M*K, nB=(size_t)K*N, nC=(size_t)M*N;
    double *hA=(double*)malloc(nA*8),*hB=(double*)malloc(nB*8);
    double *hC_ref=(double*)malloc(nC*8),*hC_forge=(double*)malloc(nC*8);
    uint64_t st = 0x4d4dULL ^ (uint64_t)(M*1000003+K*1009+N*31);
    for (size_t i=0;i<nA;i++) hA[i]=(lcg_next(&st)-0.5)*0.1;
    for (size_t i=0;i<nB;i++) hB[i]=(lcg_next(&st)-0.5)*0.05;

    /* FP64 cuBLAS Dgemm reference */
    double *dA,*dB,*dC; CK(cudaMalloc(&dA,nA*8)); CK(cudaMalloc(&dB,nB*8)); CK(cudaMalloc(&dC,nC*8));
    CK(cudaMemcpy(dA,hA,nA*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,nB*8,cudaMemcpyHostToDevice));
    const double a1=1.0,b0=0.0;
    for (int w=0;w<n_warm;w++) cublasDgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&a1,dB,N,dA,K,&b0,dC,N);
    CK(cudaDeviceSynchronize());
    double* s=(double*)malloc(n_iter*8);
    for (int it=0;it<n_iter;it++){ double t0=now_sec();
        cublasDgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&a1,dB,N,dA,K,&b0,dC,N);
        CK(cudaDeviceSynchronize()); s[it]=(now_sec()-t0)*1000.0; }
    r.t_ref_ms=median(s,n_iter); free(s);
    CK(cudaMemcpy(hC_ref,dC,nC*8,cudaMemcpyDeviceToHost));
    cudaFree(dA); cudaFree(dB); cudaFree(dC);

    /* forge wired path */
    HexaFarrBf16 *fA=hexa_farr_bf16_alloc((int64_t)nA),*fB=hexa_farr_bf16_alloc((int64_t)nB),
                 *fC=hexa_farr_bf16_alloc((int64_t)nC);
    hexa_farr_bf16_from_f64(hA,fA,(int64_t)nA);
    hexa_farr_bf16_from_f64(hB,fB,(int64_t)nB);
    int rc=hexa_farr_matmul_bf16_gpu(fA,M,K,fB,N,fC);
    if (rc!=0){ fprintf(stderr,"[MMLC] matmul rc=%d\n",rc); return r; }
    hexa_farr_bf16_to_host(fC);
    size_t szC_bf16=nC*2; unsigned char* c1=(unsigned char*)malloc(szC_bf16);
    memcpy(c1,fC->h_buf,szC_bf16);
    rc=hexa_farr_matmul_bf16_gpu(fA,M,K,fB,N,fC); hexa_farr_bf16_to_host(fC);
    r.within_run_biteq=(rc==0 && memcmp(c1,fC->h_buf,szC_bf16)==0)?1:0; free(c1);
    hexa_farr_bf16_to_f64(fC,hC_forge,(int64_t)nC);
    for (int w=0;w<n_warm;w++) hexa_farr_matmul_bf16_gpu(fA,M,K,fB,N,fC);
    double* sg=(double*)malloc(n_iter*8);
    for (int it=0;it<n_iter;it++){ double t0=now_sec();
        hexa_farr_matmul_bf16_gpu(fA,M,K,fB,N,fC); sg[it]=(now_sec()-t0)*1000.0; }
    r.t_forge_ms=median(sg,n_iter); free(sg);

    double maxd=0,maxy=0;
    for (size_t i=0;i<nC;i++){ double d=fabs(hC_forge[i]-hC_ref[i]); if(d>maxd)maxd=d;
        double ay=fabs(hC_ref[i]); if(ay>maxy)maxy=ay; }
    r.max_rel_delta=(maxy>0)?maxd/maxy:0;
    r.speedup=r.t_ref_ms/r.t_forge_ms;
    r.correct_pass=(r.max_rel_delta<=5e-2)?1:0;
    r.perf_pass=(r.speedup>=5.0)?1:0;
    r.det_pass=r.within_run_biteq;
    fprintf(stderr,"[MMLC]   ref=%.4f forge=%.4f speedup=%.3fx maxrel=%.2e biteq=%d\n",
            r.t_ref_ms,r.t_forge_ms,r.speedup,r.max_rel_delta,r.within_run_biteq);
    hexa_farr_bf16_free(fA); hexa_farr_bf16_free(fB); hexa_farr_bf16_free(fC);
    free(hA); free(hB); free(hC_ref); free(hC_forge);
    return r;
}

/* ── layercast: Y[M,N]=X[M,K]@W[K,N], X/Y FP32 host, W BF16 farr ── */
static res run_layercast(cublasHandle_t h, int M, int K, int N, int n_warm, int n_iter) {
    res r; memset(&r, 0, sizeof(r));
    strcpy(r.kind, "layercast"); r.M = M; r.K = K; r.N = N;
    fprintf(stderr, "[MMLC] === layercast M=%d K=%d N=%d ===\n", M, K, N);
    size_t nX=(size_t)M*K, nW=(size_t)K*N, nY=(size_t)M*N;
    float  *hX=(float*)malloc(nX*4),*hY_forge=(float*)malloc(nY*4),*hY_ref=(float*)malloc(nY*4);
    float  *hY_run1=(float*)malloc(nY*4);
    double *hW=(double*)malloc(nW*8);
    uint64_t st=0x1cULL ^ (uint64_t)(M*1000003+K*1009+N*31);
    for (size_t i=0;i<nX;i++) hX[i]=(float)((lcg_next(&st)-0.5)*0.1);
    for (size_t i=0;i<nW;i++) hW[i]=(lcg_next(&st)-0.5)*0.05;

    /* FP32 cuBLAS Sgemm reference (full-FP32 truth) */
    float *dX,*dWf,*dY; CK(cudaMalloc(&dX,nX*4)); CK(cudaMalloc(&dWf,nW*4)); CK(cudaMalloc(&dY,nY*4));
    float* hWf=(float*)malloc(nW*4); for (size_t i=0;i<nW;i++) hWf[i]=(float)hW[i];
    CK(cudaMemcpy(dX,hX,nX*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dWf,hWf,nW*4,cudaMemcpyHostToDevice));
    const float a1=1.0f,b0=0.0f;
    for (int w=0;w<n_warm;w++) cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&a1,dWf,N,dX,K,&b0,dY,N);
    CK(cudaDeviceSynchronize());
    double* s=(double*)malloc(n_iter*8);
    for (int it=0;it<n_iter;it++){ double t0=now_sec();
        cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&a1,dWf,N,dX,K,&b0,dY,N);
        CK(cudaDeviceSynchronize()); s[it]=(now_sec()-t0)*1000.0; }
    r.t_ref_ms=median(s,n_iter); free(s);
    CK(cudaMemcpy(hY_ref,dY,nY*4,cudaMemcpyDeviceToHost));
    cudaFree(dX); cudaFree(dWf); cudaFree(dY); free(hWf);

    /* forge wired path */
    HexaFarrBf16* fW=hexa_farr_bf16_alloc((int64_t)nW);
    hexa_farr_bf16_from_f64(hW,fW,(int64_t)nW);
    int rc=hexa_farr_layercast_linear_bf16_gpu(hX,M,K,fW,N,hY_forge);
    if (rc!=0){ fprintf(stderr,"[MMLC] layercast rc=%d\n",rc); return r; }
    memcpy(hY_run1,hY_forge,nY*4);
    rc=hexa_farr_layercast_linear_bf16_gpu(hX,M,K,fW,N,hY_forge);
    r.within_run_biteq=(rc==0 && memcmp(hY_run1,hY_forge,nY*4)==0)?1:0;
    for (int w=0;w<n_warm;w++) hexa_farr_layercast_linear_bf16_gpu(hX,M,K,fW,N,hY_forge);
    double* sg=(double*)malloc(n_iter*8);
    for (int it=0;it<n_iter;it++){ double t0=now_sec();
        hexa_farr_layercast_linear_bf16_gpu(hX,M,K,fW,N,hY_forge); sg[it]=(now_sec()-t0)*1000.0; }
    r.t_forge_ms=median(sg,n_iter); free(sg);

    double maxd=0,maxy=0;
    for (size_t i=0;i<nY;i++){ double d=fabs((double)hY_forge[i]-(double)hY_ref[i]); if(d>maxd)maxd=d;
        double ay=fabs((double)hY_ref[i]); if(ay>maxy)maxy=ay; }
    r.max_rel_delta=(maxy>0)?maxd/maxy:0;
    r.speedup=r.t_ref_ms/r.t_forge_ms;
    r.correct_pass=(r.max_rel_delta<=5e-2)?1:0;
    r.perf_pass=(r.speedup>=1.0)?1:0;   /* layercast = BF16-weight bandwidth play vs FP32 — gate "not slower" */
    r.det_pass=r.within_run_biteq;
    fprintf(stderr,"[MMLC]   ref=%.4f forge=%.4f speedup=%.3fx maxrel=%.2e biteq=%d\n",
            r.t_ref_ms,r.t_forge_ms,r.speedup,r.max_rel_delta,r.within_run_biteq);
    hexa_farr_bf16_free(fW);
    free(hX); free(hW); free(hY_forge); free(hY_ref); free(hY_run1);
    return r;
}

int main(void) {
    int nd=0; cudaGetDeviceCount(&nd);
    if (nd<=0){ fprintf(stderr,"[MMLC] no CUDA device\n"); return 1; }
    int ccM=0,ccm=0;
    cudaDeviceGetAttribute(&ccM,cudaDevAttrComputeCapabilityMajor,0);
    cudaDeviceGetAttribute(&ccm,cudaDevAttrComputeCapabilityMinor,0);
    cudaDeviceProp prop; cudaGetDeviceProperties(&prop,0);
    fprintf(stderr,"[MMLC] device 0: %s cc=%d.%d\n",prop.name,ccM,ccm);
    if (ccM<8){ FILE* jf=fopen("result.json","w");
        fprintf(jf,"{\"error\":\"BF16 TC needs sm_80+, cc=%d.%d\"}\n",ccM,ccm); fclose(jf); return 2; }
    cublasHandle_t h; CB(cublasCreate(&h));

    res rs[6]; int n=0;
    rs[n++]=run_matmul(h, 512, 512, 512, 5, 31);
    rs[n++]=run_matmul(h, 1024,1024,1024, 5, 31);
    rs[n++]=run_matmul(h, 2048,2048,2048, 3, 21);
    rs[n++]=run_layercast(h, 256, 1024, 1024, 5, 31);
    rs[n++]=run_layercast(h, 512, 2048, 2048, 5, 31);
    rs[n++]=run_layercast(h, 1024,4096, 4096, 3, 21);

    FILE* jf=fopen("result.json","w");
    fprintf(jf,"{\n  \"experiment\": \"forge_rfc049_stage2_matmul_layercast_validate\",\n");
    fprintf(jf,"  \"date\": \"2026-05-19\",\n  \"device_name\": \"%s\",\n  \"device_cc\": \"%d.%d\",\n",
            prop.name,ccM,ccm);
    fprintf(jf,"  \"shapes\": [\n");
    for (int i=0;i<n;i++){ res* r=&rs[i];
        if (i>0) fprintf(jf,",\n");
        fprintf(jf,"    { \"kind\":\"%s\", \"M\":%d, \"K\":%d, \"N\":%d, "
                "\"t_ref_ms\":%.5f, \"t_forge_ms\":%.5f, \"speedup\":%.4f, "
                "\"max_rel_delta\":%.3e, \"within_run_biteq\":%d, "
                "\"correct_pass\":%d, \"perf_pass\":%d, \"det_pass\":%d }",
                r->kind,r->M,r->K,r->N,r->t_ref_ms,r->t_forge_ms,r->speedup,
                r->max_rel_delta,r->within_run_biteq,r->correct_pass,r->perf_pass,r->det_pass);
    }
    fprintf(jf,"\n  ],\n");
    int mm_c=1,mm_p=1,mm_d=1,lc_c=1,lc_p=1,lc_d=1;
    double mm_big_sp=0,lc_big_sp=0;
    for (int i=0;i<n;i++){ res* r=&rs[i];
        if (strcmp(r->kind,"matmul")==0){ if(!r->correct_pass)mm_c=0; if(!r->det_pass)mm_d=0;
            mm_big_sp=r->speedup; if(!r->perf_pass)mm_p=mm_p; }
        else { if(!r->correct_pass)lc_c=0; if(!r->det_pass)lc_d=0; lc_big_sp=r->speedup; }
    }
    /* perf gate on the largest shape of each kind */
    mm_p=(rs[2].speedup>=5.0)?1:0;
    lc_p=(rs[5].speedup>=1.0)?1:0;
    fprintf(jf,"  \"falsifier_verdicts\": {\n");
    fprintf(jf,"    \"F-FORGE-RFC049-STAGE2-MATMUL-CORRECT\": \"%s\",\n", mm_c?"PASS":"FAIL");
    fprintf(jf,"    \"F-FORGE-RFC049-STAGE2-MATMUL-PERF\": { \"threshold\":\"≥5× FP64 cuBLAS @ 2048³\", \"speedup\":%.4f, \"verdict\":\"%s\" },\n", mm_big_sp, mm_p?"PASS":"FAIL");
    fprintf(jf,"    \"F-FORGE-RFC049-STAGE2-MATMUL-DET\": \"%s\",\n", mm_d?"PASS":"FAIL");
    fprintf(jf,"    \"F-FORGE-RFC049-STAGE2-LAYERCAST-CORRECT\": \"%s\",\n", lc_c?"PASS":"FAIL");
    fprintf(jf,"    \"F-FORGE-RFC049-STAGE2-LAYERCAST-PERF\": { \"threshold\":\"≥1× FP32 Sgemm (not slower) @ 4096²\", \"speedup\":%.4f, \"verdict\":\"%s\" },\n", lc_big_sp, lc_p?"PASS":"FAIL");
    fprintf(jf,"    \"F-FORGE-RFC049-STAGE2-LAYERCAST-DET\": \"%s\"\n", lc_d?"PASS":"FAIL");
    fprintf(jf,"  }\n}\n");
    fclose(jf);

    fprintf(stderr,"\n[MMLC] === SUMMARY ===\n");
    for (int i=0;i<n;i++){ res* r=&rs[i];
        fprintf(stderr,"  %-9s %dx%dx%d ref=%.4f forge=%.4f sp=%.3fx maxrel=%.2e biteq=%d C=%d P=%d D=%d\n",
                r->kind,r->M,r->K,r->N,r->t_ref_ms,r->t_forge_ms,r->speedup,
                r->max_rel_delta,r->within_run_biteq,r->correct_pass,r->perf_pass,r->det_pass);
    }
    cublasDestroy(h);
    return 0;
}
