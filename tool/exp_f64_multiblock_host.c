/* tool/exp_f64_multiblock_host.c — F-EXPF64-MULTIBLOCK-NUMERIC host harness
 *
 * Validates PR #1341 (gpu_global_thread_id_x) + PR #1333 (exp polynomial).
 * Re-fires PR #1336's single-block exp at N=1024 across 4 blocks via the
 * new global-thread-index intrinsic.
 *
 * Build (ubu-2 RTX 5070):
 *   gcc tool/exp_f64_multiblock_host.c -o /tmp/exp_mb_host \
 *       -I/usr/local/cuda/include -L/lib/x86_64-linux-gnu -lcuda -lm
 *   /tmp/exp_mb_host /tmp/exp_f64_multiblock_probe.hexa.ptx
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <cuda.h>

#define N      1024
#define BLOCK  256
#define GRID   ((N + BLOCK - 1) / BLOCK)

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
    const char* ptx_path = (argc>1)?argv[1]:"exp_f64_multiblock_probe.hexa.ptx";
    CUresult cr;

    cr=cuInit(0);                              if(cr){fprintf(stderr,"cuInit: %s\n",cu_err(cr));return 3;}
    CUdevice dev; cr=cuDeviceGet(&dev,0);      if(cr){fprintf(stderr,"cuDeviceGet: %s\n",cu_err(cr));return 3;}
    CUcontext ctx; cr=cuCtxCreate(&ctx,0,dev); if(cr){fprintf(stderr,"cuCtxCreate: %s\n",cu_err(cr));return 3;}

    char* ptx = read_ptx(ptx_path);
    if(!ptx){ fprintf(stderr,"FAIL: cannot read %s\n",ptx_path); return 4; }

    CUmodule mod;
    cr = load_ptx_logged(&mod, ptx, "exp_f64_multiblock_probe");
    if(cr){ fprintf(stderr,"FAIL JIT: %s\n", cu_err(cr)); free(ptx); return 5; }

    CUfunction kfn;
    cr = cuModuleGetFunction(&kfn, mod, "exp_f64_multiblock_probe");
    if(cr){ fprintf(stderr,"FAIL cuModuleGetFunction: %s\n", cu_err(cr)); return 6; }

    double a[N], c[N];
    for(int i=0;i<N;i++){
        a[i] = ((double)i / (double)N) * 10.0 - 5.0;  /* [-5, +5) */
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
    double max_rel_err = 0.0;
    int max_rel_idx = -1;
    int zero_count = 0;  /* count slots that stayed 0 — indicates idx coverage gap */
    for(int i=0;i<N;i++){
        double expected = exp(a[i]);
        double got = c[i];
        if(got == 0.0 && expected != 0.0) zero_count++;
        double abs_err = got - expected; if(abs_err < 0) abs_err = -abs_err;
        double denom = (expected < 0) ? -expected : expected;
        double rel_err = (denom > 0) ? (abs_err / denom) : abs_err;
        if(abs_err > max_abs_err) max_abs_err = abs_err;
        if(rel_err > max_rel_err){ max_rel_err = rel_err; max_rel_idx = i; }
    }

    fprintf(stderr, "GRID = %d, BLOCK = %d, N = %d (each i covered exactly once)\n", GRID, BLOCK, N);
    fprintf(stderr, "zero_count = %d (must be 0 — global-thread-id covers all slots)\n", zero_count);
    fprintf(stderr, "max_abs_err = %.17g\n", max_abs_err);
    if(max_rel_idx >= 0){
        fprintf(stderr, "max_rel_err = %.17g (at i=%d, x=%.6f, got=%.17g, expected=%.17g)\n",
                max_rel_err, max_rel_idx, a[max_rel_idx], c[max_rel_idx], exp(a[max_rel_idx]));
    } else {
        fprintf(stderr, "max_rel_err = 0 (no idx with rel_err > 0)\n");
    }

    int ok = (max_rel_err < 1e-9) && (zero_count == 0);
    if(ok){
        printf("PASS max_rel_err=%.3e < 1e-9, zero_count=0 (N=%d across %d blocks)\n", max_rel_err, N, GRID);
    } else {
        printf("FAIL max_rel_err=%.3e zero_count=%d (N=%d, %d blocks)\n", max_rel_err, zero_count, N, GRID);
    }

    cuMemFree(d_a); cuMemFree(d_c);
    cuModuleUnload(mod); cuCtxDestroy(ctx); free(ptx);
    return ok ? 0 : 1;
}
