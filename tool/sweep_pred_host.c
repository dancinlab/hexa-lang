/* tool/sweep_pred_host.c — F-GPU-SWEEP-SHARED-REDUCE-NUMERIC host harness
 *
 * Mirrors tool/r055_p2_host.c (cu_err / read_ptx / load_ptx_logged), but
 * specialised for the single-launch CUDA tree-reduce kernel `sweep_pred`
 * (closes the parent discovery `.discoveries/gpu-kernel-usability-sweep-
 * extension.tape` matrix_7 row · finding_3).
 *
 * Shape: N=256 a[i]=i+1.0 → expected partial[0] = N(N+1)/2 = 32896.0 EXACT.
 * Integer-valued FP64, all partial sums representable, max|Δ| = 0.
 *
 * Build (ubu-2 RTX 5070):
 *   gcc tool/sweep_pred_host.c -o /tmp/sweep_pred_host \
 *       -I/usr/local/cuda/include -L/usr/local/cuda/lib64 -lcuda
 *   /tmp/sweep_pred_host /tmp/sweep_pred.ptx
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
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
    const char* ptx_path = (argc>1)?argv[1]:"sweep_pred.ptx";
    CUresult cr;

    cr=cuInit(0);                              if(cr){fprintf(stderr,"cuInit: %s\n",cu_err(cr));return 3;}
    CUdevice dev; cr=cuDeviceGet(&dev,0);      if(cr){fprintf(stderr,"cuDeviceGet: %s\n",cu_err(cr));return 3;}
    CUcontext ctx; cr=cuCtxCreate(&ctx,0,dev); if(cr){fprintf(stderr,"cuCtxCreate: %s\n",cu_err(cr));return 3;}

    char* ptx = read_ptx(ptx_path);
    if(!ptx){ fprintf(stderr,"FAIL: cannot read %s\n",ptx_path); return 4; }

    CUmodule mod;
    cr = load_ptx_logged(&mod, ptx, "sweep_pred");
    if(cr){ fprintf(stderr,"FAIL JIT: %s\n", cu_err(cr)); free(ptx); return 5; }

    CUfunction kfn;
    cr = cuModuleGetFunction(&kfn, mod, "sweep_pred");
    if(cr){ fprintf(stderr,"FAIL cuModuleGetFunction: %s\n", cu_err(cr)); return 6; }

    double a[N], partial[N];
    for(int i=0;i<N;i++){ a[i]=(double)(i+1); partial[i]=0.0; }

    CUdeviceptr d_a, d_partial;
    cuMemAlloc(&d_a, N*8);
    cuMemAlloc(&d_partial, N*8);
    cuMemcpyHtoD(d_a, a, N*8);
    cuMemcpyHtoD(d_partial, partial, N*8);

    int64_t n_param = (int64_t)N;
    void* args[] = { &d_a, &d_partial, &n_param };
    cr = cuLaunchKernel(kfn, GRID,1,1, BLOCK,1,1, 0, NULL, args, NULL);
    if(cr){ fprintf(stderr,"FAIL cuLaunchKernel: %s\n", cu_err(cr)); return 7; }

    cr = cuCtxSynchronize();
    if(cr){ fprintf(stderr,"FAIL cuCtxSynchronize: %s\n", cu_err(cr)); return 8; }

    cuMemcpyDtoH(partial, d_partial, N*8);

    double expected = (double)N * (double)(N+1) / 2.0;
    double got = partial[0];
    double delta = got - expected; if(delta<0) delta=-delta;

    fprintf(stderr,"got=%.17g expected=%.17g max|delta|=%.17g\n", got, expected, delta);
    if(got == expected){
        printf("PASS partial[0]=%.3f (max|delta|=0)\n", got);
        cuMemFree(d_a); cuMemFree(d_partial);
        cuModuleUnload(mod); cuCtxDestroy(ctx); free(ptx);
        return 0;
    } else {
        printf("FAIL partial[0]=%.6f expected=%.3f delta=%.17g\n", got, expected, delta);
        cuMemFree(d_a); cuMemFree(d_partial);
        cuModuleUnload(mod); cuCtxDestroy(ctx); free(ptx);
        return 1;
    }
}
