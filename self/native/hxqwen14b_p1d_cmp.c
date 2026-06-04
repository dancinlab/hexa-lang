// hxqwen14b_p1d_cmp.c — compare two p1d_driver dumps (oracle vs own GEMM).
// Reports per-output (y, dA, dB, dx) max|Δ| and max rel error, then PASS/FAIL
// against an fp32 tolerance (default 1e-4 rel, override TOL env).
//
//   cc -O2 hxqwen14b_p1d_cmp.c -lm -o p1d_cmp
//   ./p1d_cmp oracle.bin own.bin

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

static float* slurp(const char* path, int64_t hdr[4], int64_t* total) {
    FILE* f = fopen(path,"rb");
    if (!f){ fprintf(stderr,"open %s fail\n",path); exit(2); }
    if (fread(hdr,sizeof(int64_t),4,f)!=4){ fprintf(stderr,"hdr read fail %s\n",path); exit(2);}
    int64_t n = hdr[0]+hdr[1]+hdr[2]+hdr[3];
    float* p = (float*)malloc(n*sizeof(float));
    if (fread(p,sizeof(float),n,f)!=(size_t)n){ fprintf(stderr,"data read fail %s\n",path); exit(2);}
    fclose(f); *total=n; return p;
}

static void cmp_block(const char* name, const float* a, const float* b, int64_t n,
                      double* gmaxabs, int* fail, double tol) {
    double maxabs=0.0, maxrel=0.0;
    for (int64_t i=0;i<n;i++){
        double d = fabs((double)a[i]-(double)b[i]);
        double denom = fabs((double)a[i]); if (denom<1e-6) denom=1e-6;
        double rel = d/denom;
        if (d>maxabs) maxabs=d;
        if (rel>maxrel) maxrel=rel;
    }
    int ok = (maxrel <= tol) || (maxabs <= tol);
    if (!ok) *fail=1;
    if (maxabs>*gmaxabs) *gmaxabs=maxabs;
    printf("  %-4s n=%-7lld max|Δ|=%.3e  max_rel=%.3e  %s\n",
           name,(long long)n,maxabs,maxrel, ok?"PASS":"FAIL");
}

int main(int argc, char** argv){
    if (argc<3){ fprintf(stderr,"usage: %s oracle.bin own.bin\n",argv[0]); return 1; }
    double tol = getenv("TOL")? atof(getenv("TOL")) : 1e-4;
    int64_t h1[4],h2[4],n1,n2;
    float* o = slurp(argv[1],h1,&n1);
    float* w = slurp(argv[2],h2,&n2);
    for (int i=0;i<4;i++) if (h1[i]!=h2[i]){ fprintf(stderr,"shape mismatch dim %d\n",i); return 2; }
    double gmax=0.0; int fail=0;
    printf("== Phase 1d LoRA correctness: oracle(%s) vs own(%s), tol(rel|abs)=%.1e ==\n",
           argv[1],argv[2],tol);
    int64_t off=0;
    cmp_block("y",  o+off, w+off, h1[0], &gmax,&fail,tol); off+=h1[0];
    cmp_block("dA", o+off, w+off, h1[1], &gmax,&fail,tol); off+=h1[1];
    cmp_block("dB", o+off, w+off, h1[2], &gmax,&fail,tol); off+=h1[2];
    cmp_block("dx", o+off, w+off, h1[3], &gmax,&fail,tol);
    printf("global max|Δ| = %.3e   VERDICT: %s\n", gmax, fail?"FAIL":"PASS");
    return fail?1:0;
}
