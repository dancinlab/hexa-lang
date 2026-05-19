/* RFC 055 055-P2 host harness — load the hand-emitted vec-add + naive
 * GEMM PTX via the CUDA Driver API, fire each, compare to the CPU
 * reference. Mirrors the `_hx_cuda_launch_kernel` call sequence.
 *
 * The kernel image is fed to cuModuleLoadData as PTX TEXT (NUL-
 * terminated) — the driver JIT-assembles it for the live GPU arch.
 * This is the forward-compatible path: PTX targeting sm_80 runs on any
 * newer GPU. cuModuleLoadData rejecting the PTX == ptxas rejected it,
 * so this still exercises F-RFC055-PTX-EMIT (a standalone `ptxas`
 * accept check is run separately as the cheap pre-fire oracle). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <cuda.h>

#define VN  1024
#define VBLOCK 256
#define GM 64
#define GN 64
#define GK 64
#define GBLOCK 16

static const char* cu_err(CUresult cr){ const char* s=NULL; cuGetErrorString(cr,&s); return s?s:"(no message)"; }

/* Read a PTX text file into a NUL-terminated heap buffer. */
static char* read_ptx(const char* path){
    FILE* f=fopen(path,"rb");
    if(!f){ fprintf(stderr,"cannot open %s\n",path); return NULL; }
    fseek(f,0,SEEK_END); long sz=ftell(f); fseek(f,0,SEEK_SET);
    char* buf=malloc(sz+1);
    if(fread(buf,1,sz,f)!=(size_t)sz){ fclose(f); free(buf); return NULL; }
    fclose(f); buf[sz]=0; return buf;
}

/* JIT-load PTX with the driver, capturing the ptxas error/info log so a
 * JIT failure prints the real diagnostic instead of a generic message. */
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
    const char* vec_ptx  = (argc>1)?argv[1]:"vec_add.ptx";
    const char* gemm_ptx = (argc>2)?argv[2]:"gemm.ptx";
    CUresult cr;

    cr=cuInit(0);                          if(cr){fprintf(stderr,"cuInit: %s\n",cu_err(cr));return 3;}
    CUdevice dev; cr=cuDeviceGet(&dev,0);  if(cr){fprintf(stderr,"cuDeviceGet: %s\n",cu_err(cr));return 3;}
    CUcontext ctx; cr=cuCtxCreate(&ctx,0,dev); if(cr){fprintf(stderr,"cuCtxCreate: %s\n",cu_err(cr));return 3;}

    int ptx_emit_pass=1, launch_abi_pass=1;

    /* ── vec-add (F-RFC055-NUMERIC-EQ) ───────────────────────────── */
    double vmax_delta=0.0; int vmismatch=0; int vec_ran=0;
    {
        char* ptx=read_ptx(vec_ptx);
        if(!ptx){ ptx_emit_pass=0; }
        else{
            CUmodule mod;
            cr=load_ptx_logged(&mod,ptx,"vadd");
            if(cr){ fprintf(stderr,"F-RFC055-PTX-EMIT FAIL (vadd JIT): %s\n",cu_err(cr)); ptx_emit_pass=0; }
            else{
                CUfunction kfn;
                cr=cuModuleGetFunction(&kfn,mod,"vadd");
                if(cr){ fprintf(stderr,"cuModuleGetFunction(vadd): %s\n",cu_err(cr)); launch_abi_pass=0; }
                else{
                    double *a=malloc(VN*8),*b=malloc(VN*8),*c=calloc(VN,8),*cref=malloc(VN*8);
                    for(int i=0;i<VN;i++){a[i]=(double)i;b[i]=(double)(VN-i);cref[i]=a[i]+b[i];}
                    CUdeviceptr ad,bd,cd;
                    cuMemAlloc(&ad,VN*8);cuMemAlloc(&bd,VN*8);cuMemAlloc(&cd,VN*8);
                    cuMemcpyHtoD(ad,a,VN*8);cuMemcpyHtoD(bd,b,VN*8);cuMemcpyHtoD(cd,c,VN*8);
                    int64_t n=VN; void* args[]={&ad,&bd,&cd,&n};
                    cr=cuLaunchKernel(kfn,(VN+VBLOCK-1)/VBLOCK,1,1,VBLOCK,1,1,0,NULL,args,NULL);
                    if(cr){fprintf(stderr,"F-RFC055-LAUNCH-ABI FAIL (vadd): %s\n",cu_err(cr));launch_abi_pass=0;}
                    else{
                        cr=cuCtxSynchronize();
                        if(cr){fprintf(stderr,"cuCtxSynchronize(vadd): %s\n",cu_err(cr));launch_abi_pass=0;}
                        else{
                            cuMemcpyDtoH(c,cd,VN*8);
                            for(int i=0;i<VN;i++){double d=c[i]-cref[i];if(d!=0.0){vmismatch++;if(d<0)d=-d;if(d>vmax_delta)vmax_delta=d;}}
                            vec_ran=1;
                        }
                    }
                    cuMemFree(ad);cuMemFree(bd);cuMemFree(cd);free(a);free(b);free(c);free(cref);
                }
                cuModuleUnload(mod);
            }
            free(ptx);
        }
    }
    int numeq_pass=(vec_ran && vmax_delta==0.0 && vmismatch==0)?1:0;
    fprintf(stderr,"F-RFC055-NUMERIC-EQ %s — max|Δ|=%.17g mismatches=%d/%d\n",
            numeq_pass?"PASS":"FAIL",vmax_delta,vmismatch,VN);

    /* ── naive GEMM (F-RFC055-GEMM-FEASIBLE) ─────────────────────── */
    double gmax_delta=0.0; int gmismatch=0; int gemm_ran=0;
    {
        char* ptx=read_ptx(gemm_ptx);
        if(!ptx){ ptx_emit_pass=0; }
        else{
            CUmodule mod;
            cr=load_ptx_logged(&mod,ptx,"gemm");
            if(cr){ fprintf(stderr,"F-RFC055-PTX-EMIT FAIL (gemm JIT): %s\n",cu_err(cr)); ptx_emit_pass=0; }
            else{
                CUfunction kfn;
                cr=cuModuleGetFunction(&kfn,mod,"gemm");
                if(cr){ fprintf(stderr,"cuModuleGetFunction(gemm): %s\n",cu_err(cr)); launch_abi_pass=0; }
                else{
                    int MA=GM*GK,MB=GK*GN,MC=GM*GN;
                    double *a=malloc(MA*8),*b=malloc(MB*8),*c=calloc(MC,8),*cref=malloc(MC*8);
                    for(int i=0;i<MA;i++)a[i]=(double)(i%7);
                    for(int i=0;i<MB;i++)b[i]=(double)(i%5);
                    for(int row=0;row<GM;row++)for(int col=0;col<GN;col++){
                        double acc=0.0;
                        for(int kk=0;kk<GK;kk++)acc+=a[row*GK+kk]*b[kk*GN+col];
                        cref[row*GN+col]=acc;
                    }
                    CUdeviceptr ad,bd,cd;
                    cuMemAlloc(&ad,MA*8);cuMemAlloc(&bd,MB*8);cuMemAlloc(&cd,MC*8);
                    cuMemcpyHtoD(ad,a,MA*8);cuMemcpyHtoD(bd,b,MB*8);cuMemcpyHtoD(cd,c,MC*8);
                    int64_t m=GM,n=GN,k=GK; void* args[]={&ad,&bd,&cd,&m,&n,&k};
                    unsigned gx=(GN+GBLOCK-1)/GBLOCK, gy=(GM+GBLOCK-1)/GBLOCK;
                    cr=cuLaunchKernel(kfn,gx,gy,1,GBLOCK,GBLOCK,1,0,NULL,args,NULL);
                    if(cr){fprintf(stderr,"F-RFC055-LAUNCH-ABI FAIL (gemm): %s\n",cu_err(cr));launch_abi_pass=0;}
                    else{
                        cr=cuCtxSynchronize();
                        if(cr){fprintf(stderr,"cuCtxSynchronize(gemm): %s\n",cu_err(cr));launch_abi_pass=0;}
                        else{
                            cuMemcpyDtoH(c,cd,MC*8);
                            for(int i=0;i<MC;i++){double d=c[i]-cref[i];if(d!=0.0){gmismatch++;if(d<0)d=-d;if(d>gmax_delta)gmax_delta=d;}}
                            gemm_ran=1;
                        }
                    }
                    cuMemFree(ad);cuMemFree(bd);cuMemFree(cd);free(a);free(b);free(c);free(cref);
                }
                cuModuleUnload(mod);
            }
            free(ptx);
        }
    }
    /* Integer inputs (a=i%7,b=i%5,k=64) → all products + partial sums
     * exact in FP64 → this run is byte-exact. The gate is correctness. */
    int gemm_pass=(gemm_ran && gmax_delta==0.0 && gmismatch==0)?1:0;
    fprintf(stderr,"F-RFC055-GEMM-FEASIBLE %s — max|Δ|=%.17g mismatches=%d/%d\n",
            gemm_pass?"PASS":"FAIL",gmax_delta,gmismatch,GM*GN);

    if(ptx_emit_pass)  fprintf(stderr,"F-RFC055-PTX-EMIT PASS — both PTX modules JIT-loaded\n");
    if(launch_abi_pass)fprintf(stderr,"F-RFC055-LAUNCH-ABI PASS — host->kernel->host (1-D + 2-D)\n");

    FILE* rf=fopen("result.json","w");
    fprintf(rf,"{\n  \"rfc\": \"055-P2\",\n");
    fprintf(rf,"  \"kernels\": [\"vadd\", \"gemm\"],\n");
    fprintf(rf,"  \"falsifiers\": {\n");
    fprintf(rf,"    \"F-RFC055-PTX-EMIT\":      \"%s\",\n",ptx_emit_pass?"PASS":"FAIL");
    fprintf(rf,"    \"F-RFC055-LAUNCH-ABI\":    \"%s\",\n",launch_abi_pass?"PASS":"FAIL");
    fprintf(rf,"    \"F-RFC055-NUMERIC-EQ\":    \"%s\",\n",numeq_pass?"PASS":"FAIL");
    fprintf(rf,"    \"F-RFC055-NUMERIC-EQ.max_delta\": %.17g,\n",vmax_delta);
    fprintf(rf,"    \"F-RFC055-GEMM-FEASIBLE\": \"%s\",\n",gemm_pass?"PASS":"FAIL");
    fprintf(rf,"    \"F-RFC055-GEMM-FEASIBLE.max_delta\": %.17g\n",gmax_delta);
    fprintf(rf,"  }\n}\n");
    fclose(rf);

    cuCtxDestroy(ctx);
    return (ptx_emit_pass && launch_abi_pass && numeq_pass && gemm_pass)?0:6;
}
