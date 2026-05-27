/* tool/argmax_f64_host.c — §5j top-k wedge (top-1 = argmax) host harness
 *
 * Validates the hand-emitted argmax @gpu_kernel (tool/probe_argmax_f64.hexa).
 * Returns (max_value, max_index). Builds the minimal "fused (value, index)
 * reduction" wedge — cuBLAS has SUM/MAX value but no fused (value, index).
 *
 * Mirrors tool/logsumexp_f64_host.c (cuModuleLoadDataEx · cuLaunchKernel · libm compare).
 *
 * Build (ubu-2 RTX 5070, /lib/x86_64-linux-gnu has libcuda.so):
 *   gcc tool/argmax_f64_host.c -o /tmp/argmax_host \
 *       -I/usr/local/cuda/include -L/lib/x86_64-linux-gnu -lcuda -lm
 *   /tmp/argmax_host /tmp/probe_argmax_f64.hexa.ptx
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
    const char* ptx_path = (argc>1)?argv[1]:"probe_argmax_f64.hexa.ptx";
    CUresult cr;

    cr=cuInit(0);                              if(cr){fprintf(stderr,"cuInit: %s\n",cu_err(cr));return 3;}
    CUdevice dev; cr=cuDeviceGet(&dev,0);      if(cr){fprintf(stderr,"cuDeviceGet: %s\n",cu_err(cr));return 3;}
    CUcontext ctx; cr=cuCtxCreate(&ctx,0,dev); if(cr){fprintf(stderr,"cuCtxCreate: %s\n",cu_err(cr));return 3;}

    char* ptx = read_ptx(ptx_path);
    if(!ptx){ fprintf(stderr,"FAIL: cannot read %s\n",ptx_path); return 4; }

    CUmodule mod;
    cr = load_ptx_logged(&mod, ptx, "probe_argmax_f64");
    if(cr){ fprintf(stderr,"FAIL JIT: %s\n", cu_err(cr)); free(ptx); return 5; }

    CUfunction kfn;
    cr = cuModuleGetFunction(&kfn, mod, "probe_argmax_f64");
    if(cr){ fprintf(stderr,"FAIL cuModuleGetFunction: %s\n", cu_err(cr)); return 6; }

    /* Deterministic pattern: a[i] = sin(0.13 * i) * cos(0.07 * (i+1)) + (i==137 ? 5.0 : 0.0)
     * Single distinct peak at i=137 (well above other entries' [-1,+1] range). */
    double a[N], out_val[N], out_idx[N];
    for(int i=0;i<N;i++){
        a[i] = sin(0.13 * i) * cos(0.07 * (i+1)) + (i==137 ? 5.0 : 0.0);
        out_val[i] = 0.0;
        out_idx[i] = 0.0;
    }

    CUdeviceptr d_a, d_v, d_i;
    cuMemAlloc(&d_a, N*8);
    cuMemAlloc(&d_v, N*8);
    cuMemAlloc(&d_i, N*8);
    cuMemcpyHtoD(d_a, a,       N*8);
    cuMemcpyHtoD(d_v, out_val, N*8);
    cuMemcpyHtoD(d_i, out_idx, N*8);

    int64_t n_param = (int64_t)N;
    void* args[] = { &d_a, &d_v, &d_i, &n_param };
    cr = cuLaunchKernel(kfn, GRID,1,1, BLOCK,1,1, 0, NULL, args, NULL);
    if(cr){ fprintf(stderr,"FAIL cuLaunchKernel: %s\n", cu_err(cr)); return 7; }

    cr = cuCtxSynchronize();
    if(cr){ fprintf(stderr,"FAIL cuCtxSynchronize: %s\n", cu_err(cr)); return 8; }

    cuMemcpyDtoH(out_val, d_v, N*8);
    cuMemcpyDtoH(out_idx, d_i, N*8);

    /* CPU argmax reference */
    double ref_v = a[0]; int64_t ref_i = 0;
    for(int i=1;i<N;i++){
        if(a[i] > ref_v){ ref_v = a[i]; ref_i = i; }
    }

    double got_v = out_val[0];
    int64_t got_i = (int64_t) out_idx[0];

    double v_err = got_v - ref_v; if(v_err < 0) v_err = -v_err;
    int idx_match = (got_i == ref_i);

    fprintf(stderr, "got = (val=%.17g, idx=%lld)\n", got_v, (long long)got_i);
    fprintf(stderr, "ref = (val=%.17g, idx=%lld)\n", ref_v, (long long)ref_i);
    fprintf(stderr, "val_err = %.3e · idx_match = %d\n", v_err, idx_match);

    int ok = (v_err < 1e-12) && idx_match;
    if(ok){
        printf("PASS argmax: val byte-eq · idx exact (N=%d, peak@137) — §5j top-1 wedge silicon\n", N);
    } else {
        printf("FAIL argmax: val_err=%.3e idx_match=%d (got=%lld ref=%lld)\n",
               v_err, idx_match, (long long)got_i, (long long)ref_i);
    }

    cuMemFree(d_a); cuMemFree(d_v); cuMemFree(d_i);
    cuModuleUnload(mod); cuCtxDestroy(ctx); free(ptx);
    return ok ? 0 : 1;
}
