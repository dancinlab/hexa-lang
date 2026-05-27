/* tool/probe_atan_f64_host.c — F-ATANF64-NUMERIC host harness
 *
 * Validates the f64 atan(x) codegen landed by PR #1524 (RFC 055 §13,
 * Abramowitz & Stegun 4.4.49 + reciprocal range reduction). Range
 * [-8, +8) sampled at 256 points (covers the |x|>1 π/2-complement
 * fold); tolerance target max_abs_err < 1e-7 vs CPU libm atan.
 *
 * Absolute error (not relative): atan(0)=0 makes a relative metric
 * blow up near the origin; atan's range is bounded to (-π/2, π/2) so
 * an absolute bound is the honest accuracy gate.
 *
 * Mirrors tool/exp_f64_probe_host.c (cu_err / read_ptx / load_ptx_logged).
 *
 * Build (ubu-2 RTX 5070, /lib/x86_64-linux-gnu has libcuda.so):
 *   gcc tool/probe_atan_f64_host.c -o /tmp/atan_f64_host \
 *       -I/usr/local/cuda/include -L/lib/x86_64-linux-gnu -lcuda -lm
 *   /tmp/atan_f64_host /tmp/probe_atan_f64.hexa.ptx
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
    static char err_log[8192], info_log[8192];
    err_log[0]=0; info_log[0]=0;
    CUjit_option opts[4] = {
        CU_JIT_ERROR_LOG_BUFFER, CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_INFO_LOG_BUFFER,  CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES };
    void* vals[4] = {
        err_log, (void*)(size_t)sizeof(err_log),
        info_log, (void*)(size_t)sizeof(info_log) };
    CUresult cr = cuModuleLoadDataEx(mod, ptx, 4, opts, vals);
    if(cr != CUDA_SUCCESS){
        fprintf(stderr,"  [%s JIT err] %s\n", tag, err_log[0]?err_log:"(empty log)");
        if(info_log[0]) fprintf(stderr,"  [%s JIT info] %s\n", tag, info_log);
    }
    return cr;
}

int main(int argc, char** argv){
    const char* ptx_path = (argc>1)?argv[1]:"probe_atan_f64.hexa.ptx";
    CUresult cr;

    cr=cuInit(0);                              if(cr){fprintf(stderr,"cuInit: %s\n",cu_err(cr));return 3;}
    CUdevice dev; cr=cuDeviceGet(&dev,0);      if(cr){fprintf(stderr,"cuDeviceGet: %s\n",cu_err(cr));return 3;}
    CUcontext ctx; cr=cuCtxCreate(&ctx,0,dev); if(cr){fprintf(stderr,"cuCtxCreate: %s\n",cu_err(cr));return 3;}

    char* ptx = read_ptx(ptx_path);
    if(!ptx){ fprintf(stderr,"FAIL: cannot read %s\n",ptx_path); return 4; }

    CUmodule mod;
    cr = load_ptx_logged(&mod, ptx, "atan_f64_probe");
    if(cr){ fprintf(stderr,"FAIL JIT: %s\n", cu_err(cr)); free(ptx); return 5; }

    CUfunction kfn;
    cr = cuModuleGetFunction(&kfn, mod, "atan_f64_probe");
    if(cr){ fprintf(stderr,"FAIL cuModuleGetFunction: %s\n", cu_err(cr)); return 6; }

    double a[N], c[N];
    for(int i=0;i<N;i++){
        a[i] = ((double)i / (double)N) * 16.0 - 8.0;  /* [-8, +8) */
        c[i] = 0.0;
    }

    CUdeviceptr d_a, d_c;
    cuMemAlloc(&d_a, N*8);
    cuMemAlloc(&d_c, N*8);
    cuMemcpyHtoD(d_a, a, N*8);
    cuMemcpyHtoD(d_c, c, N*8);

    int64_t n_param = (int64_t)N;
    void* args[] = { &d_a, &d_c, &n_param };
    cr = cuLaunchKernel(kfn, GRID,1,1, BLOCK,1,1, 0, NULL, args, NULL);
    if(cr){ fprintf(stderr,"FAIL cuLaunchKernel: %s\n", cu_err(cr)); return 7; }

    cr = cuCtxSynchronize();
    if(cr){ fprintf(stderr,"FAIL cuCtxSynchronize: %s\n", cu_err(cr)); return 8; }

    cuMemcpyDtoH(c, d_c, N*8);

    double max_abs_err = 0.0;
    int max_abs_idx = -1;
    for(int i=0;i<N;i++){
        double expected = atan(a[i]);
        double got = c[i];
        double abs_err = got - expected; if(abs_err < 0) abs_err = -abs_err;
        if(abs_err > max_abs_err){ max_abs_err = abs_err; max_abs_idx = i; }
    }

    fprintf(stderr, "max_abs_err = %.17g (at i=%d, x=%.6f, got=%.17g, expected=%.17g)\n",
            max_abs_err, max_abs_idx, a[max_abs_idx], c[max_abs_idx], atan(a[max_abs_idx]));

    int ok = (max_abs_err < 1e-7);
    if(ok){
        printf("PASS max_abs_err=%.3e < 1e-7 (N=%d, x in [-8,+8))\n", max_abs_err, N);
    } else {
        printf("FAIL max_abs_err=%.3e >= 1e-7 (N=%d)\n", max_abs_err, N);
    }

    cuMemFree(d_a); cuMemFree(d_c);
    cuModuleUnload(mod); cuCtxDestroy(ctx); free(ptx);
    return ok ? 0 : 1;
}
