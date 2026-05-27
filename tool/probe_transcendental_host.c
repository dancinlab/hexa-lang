/* tool/probe_transcendental_host.c — generic CUDA-driver host harness
 *
 * Validates RFC 055 §13 f64 transcendental codegen on ubu-2 RTX 5070.
 * Selects kernel + libm reference + input domain by argv[1] name.
 *
 * Usage:
 *   ./host <kernel_name> <kernel.ptx>
 *
 *   kernel_name in: sin_f64_probe · cos_f64_probe · tan_f64_probe
 *                 · exp_f64_probe · log_f64_probe · pow_f64_probe
 *                 · atan_f64_probe · tanh_f64_probe · sigmoid_f64_probe
 *
 * Range / tolerance per fn (chosen to avoid singularities):
 *   sin/cos        : [-8, +8)         tol 1e-7
 *   tan            : [-1.4, +1.4)     tol 1e-6  (avoid pi/2 poles)
 *   exp            : [-5, +5)         tol 1e-9  (exp magnitudes manageable, rel-like)
 *   log            : [0.1, +12.85)    tol 1e-9
 *   pow            : a in [0.1,12.85), b=2.5   tol 1e-7
 *   atan/tanh/sigmoid : [-8, +8)      tol 1e-7
 *
 * Build (ubu-2):
 *   gcc tool/probe_transcendental_host.c -o /tmp/xcnd_host \
 *       -I/usr/local/cuda/include -L/lib/x86_64-linux-gnu -lcuda -lm
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

static int eq_fn(const char* fn, const char* name) { return strcmp(fn, name)==0; }

int main(int argc, char** argv){
    if (argc < 3) { fprintf(stderr,"usage: %s <kernel_name> <kernel.ptx>\n", argv[0]); return 2; }
    const char* fn       = argv[1];
    const char* ptx_path = argv[2];
    CUresult cr;

    /* per-fn range + tolerance */
    double lo, hi, tol;
    int    is_pow = eq_fn(fn, "pow_f64_probe");
    double pow_y  = 2.5;
    if (eq_fn(fn, "tan_f64_probe"))         { lo=-1.4; hi=+1.4;   tol=1e-6; }
    else if (eq_fn(fn, "exp_f64_probe"))    { lo=-5.0; hi=+5.0;   tol=1e-9; }
    else if (eq_fn(fn, "log_f64_probe"))    { lo= 0.1; hi=+12.85; tol=1e-9; }
    else if (is_pow)                        { lo= 0.1; hi=+12.85; tol=1e-7; }
    else                                    { lo=-8.0; hi=+8.0;   tol=1e-7; }
    double step = (hi - lo) / (double)N;

    cr=cuInit(0);                              if(cr){fprintf(stderr,"cuInit: %s\n",cu_err(cr));return 3;}
    CUdevice dev; cr=cuDeviceGet(&dev,0);      if(cr){fprintf(stderr,"cuDeviceGet: %s\n",cu_err(cr));return 3;}
    CUcontext ctx; cr=cuCtxCreate(&ctx,0,dev); if(cr){fprintf(stderr,"cuCtxCreate: %s\n",cu_err(cr));return 3;}

    char* ptx = read_ptx(ptx_path);
    if(!ptx){ fprintf(stderr,"FAIL: cannot read %s\n",ptx_path); return 4; }

    CUmodule mod;
    cr = load_ptx_logged(&mod, ptx, fn);
    if(cr){ fprintf(stderr,"FAIL JIT: %s\n", cu_err(cr)); free(ptx); return 5; }

    CUfunction kfn;
    cr = cuModuleGetFunction(&kfn, mod, fn);
    if(cr){ fprintf(stderr,"FAIL cuModuleGetFunction(%s): %s\n", fn, cu_err(cr)); return 6; }

    double a[N], b[N], c[N];
    for(int i=0;i<N;i++){ a[i] = lo + ((double)i)*step; b[i] = pow_y; c[i] = 0.0; }

    CUdeviceptr d_a, d_b, d_c;
    cuMemAlloc(&d_a, N*8);  cuMemcpyHtoD(d_a, a, N*8);
    cuMemAlloc(&d_c, N*8);  cuMemcpyHtoD(d_c, c, N*8);
    if (is_pow) { cuMemAlloc(&d_b, N*8); cuMemcpyHtoD(d_b, b, N*8); }

    int64_t n_param = (int64_t)N;
    void* args_1ary[] = { &d_a, &d_c, &n_param };
    void* args_2ary[] = { &d_a, &d_b, &d_c, &n_param };
    void** args = is_pow ? args_2ary : args_1ary;
    cr = cuLaunchKernel(kfn, GRID,1,1, BLOCK,1,1, 0, NULL, args, NULL);
    if(cr){ fprintf(stderr,"FAIL cuLaunchKernel: %s\n", cu_err(cr)); return 7; }

    cr = cuCtxSynchronize();
    if(cr){ fprintf(stderr,"FAIL cuCtxSynchronize: %s\n", cu_err(cr)); return 8; }

    cuMemcpyDtoH(c, d_c, N*8);

    double max_abs_err = 0.0;
    int max_abs_idx = -1;
    for(int i=0;i<N;i++){
        double expected;
        if      (eq_fn(fn,"sin_f64_probe"))     expected = sin(a[i]);
        else if (eq_fn(fn,"cos_f64_probe"))     expected = cos(a[i]);
        else if (eq_fn(fn,"tan_f64_probe"))     expected = tan(a[i]);
        else if (eq_fn(fn,"exp_f64_probe"))     expected = exp(a[i]);
        else if (eq_fn(fn,"log_f64_probe"))     expected = log(a[i]);
        else if (eq_fn(fn,"atan_f64_probe"))    expected = atan(a[i]);
        else if (eq_fn(fn,"tanh_f64_probe"))    expected = tanh(a[i]);
        else if (eq_fn(fn,"sigmoid_f64_probe")) expected = 1.0/(1.0+exp(-a[i]));
        else if (is_pow)                        expected = pow(a[i], b[i]);
        else { fprintf(stderr,"unknown fn: %s\n", fn); return 9; }
        double got = c[i];
        double abs_err = got - expected; if(abs_err < 0) abs_err = -abs_err;
        if(abs_err > max_abs_err){ max_abs_err = abs_err; max_abs_idx = i; }
    }

    fprintf(stderr, "[%s] max_abs_err = %.17g (at i=%d, x=%.6f)\n",
            fn, max_abs_err, max_abs_idx, a[max_abs_idx]);

    int ok = (max_abs_err < tol);
    printf("%s %s max_abs_err=%.3e tol=%.0e (N=%d, range=[%.2f,%.2f))\n",
           ok?"PASS":"FAIL", fn, max_abs_err, tol, N, lo, hi);

    cuMemFree(d_a); cuMemFree(d_c); if (is_pow) cuMemFree(d_b);
    cuModuleUnload(mod); cuCtxDestroy(ctx); free(ptx);
    return ok ? 0 : 1;
}
