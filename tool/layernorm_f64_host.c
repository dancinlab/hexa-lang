/* tool/layernorm_f64_host.c — §5a LN+GEMM wedge (LN-fwd 1-kernel)
 *
 * Validates probe_layernorm_f64.hexa against CPU LayerNorm-fwd reference.
 * eps=1e-5, N=256, peak input dynamic range arbitrary. Tolerance 1e-9
 * (rsqrt + 2-pass reduce + elementwise; libm rsqrt = 1/sqrt within ulp).
 *
 * Build (ubu-2 RTX 5070):
 *   gcc tool/layernorm_f64_host.c -o /tmp/ln_host \
 *       -I/usr/local/cuda/include -L/lib/x86_64-linux-gnu -lcuda -lm
 *   /tmp/ln_host /tmp/probe_layernorm_f64.hexa.ptx
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <cuda.h>

#define N      256
#define BLOCK  256
#define GRID   1
#define EPS    1.0e-5

static const char* cu_err(CUresult cr){ const char* s=NULL; cuGetErrorString(cr,&s); return s?s:"(no message)"; }

static char* read_ptx(const char* path){
    FILE* f=fopen(path,"rb");
    if(!f){ fprintf(stderr,"cannot open %s\n",path); return NULL; }
    fseek(f,0,SEEK_END); long sz=ftell(f); fseek(f,0,SEEK_SET);
    char* buf=malloc(sz+1);
    if(fread(buf,1,sz,f)!=(size_t)sz){ fclose(f); free(buf); return NULL; }
    fclose(f); buf[sz]=0; return buf;
}

static CUresult load_ptx_logged(CUmodule* mod, const char* ptx, const char* tag){
    static char err_log[8192];
    err_log[0]=0;
    CUjit_option opts[2] = { CU_JIT_ERROR_LOG_BUFFER, CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES };
    void* vals[2] = { err_log, (void*)(size_t)sizeof(err_log) };
    CUresult cr = cuModuleLoadDataEx(mod, ptx, 2, opts, vals);
    if(cr != CUDA_SUCCESS) fprintf(stderr,"  [%s JIT err] %s\n", tag, err_log[0]?err_log:"(empty log)");
    return cr;
}

int main(int argc, char** argv){
    const char* ptx_path = (argc>1)?argv[1]:"probe_layernorm_f64.hexa.ptx";
    CUresult cr;

    cr=cuInit(0);                              if(cr){fprintf(stderr,"cuInit: %s\n",cu_err(cr));return 3;}
    CUdevice dev; cr=cuDeviceGet(&dev,0);      if(cr){fprintf(stderr,"cuDeviceGet: %s\n",cu_err(cr));return 3;}
    CUcontext ctx; cr=cuCtxCreate(&ctx,0,dev); if(cr){fprintf(stderr,"cuCtxCreate: %s\n",cu_err(cr));return 3;}

    char* ptx = read_ptx(ptx_path);
    if(!ptx){ fprintf(stderr,"FAIL: cannot read %s\n",ptx_path); return 4; }

    CUmodule mod;
    cr = load_ptx_logged(&mod, ptx, "probe_layernorm_f64");
    if(cr){ free(ptx); return 5; }

    CUfunction kfn;
    cr = cuModuleGetFunction(&kfn, mod, "probe_layernorm_f64");
    if(cr){ fprintf(stderr,"FAIL cuModuleGetFunction: %s\n", cu_err(cr)); return 6; }

    /* Input: bounded dynamic range, deterministic */
    double x[N], y[N];
    for(int i=0;i<N;i++){
        x[i] = sin(0.11 * i) + 0.3 * cos(0.07 * i) + 0.005 * (double)i;
        y[i] = 0.0;
    }

    CUdeviceptr d_x, d_y;
    cuMemAlloc(&d_x, N*8);
    cuMemAlloc(&d_y, N*8);
    cuMemcpyHtoD(d_x, x, N*8);
    cuMemcpyHtoD(d_y, y, N*8);

    int64_t n_param = (int64_t)N;
    void* args[] = { &d_x, &d_y, &n_param };
    cr = cuLaunchKernel(kfn, GRID,1,1, BLOCK,1,1, 0, NULL, args, NULL);
    if(cr){ fprintf(stderr,"FAIL cuLaunchKernel: %s\n", cu_err(cr)); return 7; }

    cr = cuCtxSynchronize();
    if(cr){ fprintf(stderr,"FAIL cuCtxSynchronize: %s\n", cu_err(cr)); return 8; }

    cuMemcpyDtoH(y, d_y, N*8);

    /* CPU LayerNorm-fwd reference (2-pass reduce + normalize) */
    double sum = 0.0;
    for(int i=0;i<N;i++) sum += x[i];
    double mean = sum / (double)N;
    double sumsq = 0.0;
    for(int i=0;i<N;i++){
        double d = x[i] - mean;
        sumsq += d * d;
    }
    double var = sumsq / (double)N;
    double inv = 1.0 / sqrt(var + EPS);

    double max_abs_err = 0.0;
    double max_rel_err = 0.0;
    int max_rel_idx = -1;
    for(int i=0;i<N;i++){
        double expected = (x[i] - mean) * inv;
        double got = y[i];
        double abs_err = got - expected; if(abs_err < 0) abs_err = -abs_err;
        double denom = (expected < 0) ? -expected : expected;
        double rel_err = (denom > 0) ? (abs_err / denom) : abs_err;
        if(abs_err > max_abs_err) max_abs_err = abs_err;
        if(rel_err > max_rel_err){ max_rel_err = rel_err; max_rel_idx = i; }
    }

    fprintf(stderr, "max_abs_err = %.17g\n", max_abs_err);
    fprintf(stderr, "max_rel_err = %.17g (at i=%d)\n", max_rel_err, max_rel_idx);
    fprintf(stderr, "mean = %.17g · var = %.17g · inv = %.17g\n", mean, var, inv);

    int ok = (max_rel_err < 1e-9);
    if(ok){
        printf("PASS LayerNorm rel_err=%.3e < 1e-9 (N=%d) — §5a LN-fwd 1-kernel wedge\n", max_rel_err, N);
    } else {
        printf("FAIL LayerNorm rel_err=%.3e >= 1e-9 (N=%d, peak idx=%d)\n", max_rel_err, N, max_rel_idx);
    }

    cuMemFree(d_x); cuMemFree(d_y);
    cuModuleUnload(mod); cuCtxDestroy(ctx); free(ptx);
    return ok ? 0 : 1;
}
