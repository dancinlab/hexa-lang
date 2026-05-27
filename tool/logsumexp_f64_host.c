/* tool/logsumexp_f64_host.c — §5j custom-reduction (LogSumExp) host harness
 *
 * Validates the hand-emitted LogSumExp @gpu_kernel (tool/probe_logsumexp_f64.hexa)
 * — a custom reduction cuBLAS cannot express — against CPU libm. N=256 inputs
 * a[i] = (i/N)*10 - 5  in [-5, +5); compares out[0] to
 *   m + log( sum_i exp(a[i]-m) ),  m = max a[i].  Tolerance: rel_err < 1e-7.
 *
 * Mirrors tool/exp_f64_probe_host.c (cu_err / read_ptx / load_ptx_logged).
 *
 * Build (ubu-2 RTX 5070, /lib/x86_64-linux-gnu has libcuda.so):
 *   gcc tool/logsumexp_f64_host.c -o /tmp/lse_host \
 *       -I/usr/local/cuda/include -L/lib/x86_64-linux-gnu -lcuda -lm
 *   /tmp/lse_host /tmp/probe_logsumexp_f64.hexa.ptx
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
    const char* ptx_path = (argc>1)?argv[1]:"probe_logsumexp_f64.hexa.ptx";
    CUresult cr;

    cr=cuInit(0);                              if(cr){fprintf(stderr,"cuInit: %s\n",cu_err(cr));return 3;}
    CUdevice dev; cr=cuDeviceGet(&dev,0);      if(cr){fprintf(stderr,"cuDeviceGet: %s\n",cu_err(cr));return 3;}
    CUcontext ctx; cr=cuCtxCreate(&ctx,0,dev); if(cr){fprintf(stderr,"cuCtxCreate: %s\n",cu_err(cr));return 3;}

    char* ptx = read_ptx(ptx_path);
    if(!ptx){ fprintf(stderr,"FAIL: cannot read %s\n",ptx_path); return 4; }

    CUmodule mod;
    cr = load_ptx_logged(&mod, ptx, "probe_logsumexp_f64");
    if(cr){ fprintf(stderr,"FAIL JIT: %s\n", cu_err(cr)); free(ptx); return 5; }

    CUfunction kfn;
    cr = cuModuleGetFunction(&kfn, mod, "probe_logsumexp_f64");
    if(cr){ fprintf(stderr,"FAIL cuModuleGetFunction: %s\n", cu_err(cr)); return 6; }

    double a[N], out[N];
    for(int i=0;i<N;i++){
        a[i]   = ((double)i / (double)N) * 10.0 - 5.0;  /* [-5, +5) */
        out[i] = 0.0;
    }

    CUdeviceptr d_a, d_out;
    cuMemAlloc(&d_a,   N*8);
    cuMemAlloc(&d_out, N*8);
    cuMemcpyHtoD(d_a,   a,   N*8);
    cuMemcpyHtoD(d_out, out, N*8);

    int64_t n_param = (int64_t)N;
    void* args[] = { &d_a, &d_out, &n_param };
    cr = cuLaunchKernel(kfn, GRID,1,1, BLOCK,1,1, 0, NULL, args, NULL);
    if(cr){ fprintf(stderr,"FAIL cuLaunchKernel: %s\n", cu_err(cr)); return 7; }

    cr = cuCtxSynchronize();
    if(cr){ fprintf(stderr,"FAIL cuCtxSynchronize: %s\n", cu_err(cr)); return 8; }

    cuMemcpyDtoH(out, d_out, N*8);

    /* CPU libm reference: numerically-stable LogSumExp */
    double m = a[0];
    for(int i=1;i<N;i++){ if(a[i] > m) m = a[i]; }
    double s = 0.0;
    for(int i=0;i<N;i++){ s += exp(a[i] - m); }
    double expected = m + log(s);

    double got = out[0];
    double abs_err = got - expected; if(abs_err < 0) abs_err = -abs_err;
    double denom = (expected < 0) ? -expected : expected;
    double rel_err = (denom > 0) ? (abs_err / denom) : abs_err;

    fprintf(stderr, "got=%.17g expected=%.17g abs_err=%.3e rel_err=%.3e (m=%.6f)\n",
            got, expected, abs_err, rel_err, m);

    int ok = (rel_err < 1e-7);
    if(ok){
        printf("PASS LogSumExp rel_err=%.3e < 1e-7 (N=%d, custom max+exp+log+sum reduction)\n", rel_err, N);
    } else {
        printf("FAIL LogSumExp rel_err=%.3e >= 1e-7 (N=%d)\n", rel_err, N);
    }

    cuMemFree(d_a); cuMemFree(d_out);
    cuModuleUnload(mod); cuCtxDestroy(ctx); free(ptx);
    return ok ? 0 : 1;
}
