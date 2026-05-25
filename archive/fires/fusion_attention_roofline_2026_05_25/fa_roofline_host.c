/* F-FUSION-ATTN-ROOFLINE host -- fires the TMA SWIZZLE_128B + double-buffer fused
 * flash-attention PTX (flash_attn_tma_sw128), validates numeric vs f64 CPU ref
 * (honest per-row-scaled metric), times it vs the cuBLAS-TC 3-launch baseline,
 * and reports ratio + % of the sm_120 FP16 tensor-core roofline.
 *
 * Build (ubu, CUDA 12.x):
 *   nvcc -O2 -arch=sm_120a -o fa_roofline_host fa_roofline_host.c -lcuda -lcublas -lm
 * Run:
 *   ./fa_roofline_host flash_attn_tma_sw128_2048.ptx 2048
 *   ./fa_roofline_host flash_attn_tma_sw128_4096.ptx 4096
 *
 * d fixed = 64. N must be a multiple of 64.
 *
 * ROOFLINE (stated assumptions, sm_120 RTX 5070 from GPU.md sec1f caps):
 *   48 SM, 2.542 GHz, 192-bit bus.
 *   FP16 tensor-core peak: the cuBLAS HGEMM saturation ceiling = ~70.2 TFLOPS
 *     (GPU.md sec1g N204 @ M=8192) is the achievable-peak we measure against.
 *     We ALSO report the theoretical TC peak (see TC_PEAK_THEO below) and the
 *     measured-cuBLAS-here ceiling.
 *   Attention FLOPs = 4*N*N*d (QK^T 2N^2 d + P.V 2N^2 d MACs; softmax negligible).
 */
#include <cuda.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cuda_fp16.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define CU(call) do { CUresult e=(call); if(e!=CUDA_SUCCESS){ const char*s=NULL; \
  cuGetErrorString(e,&s); fprintf(stderr,"CU err %d @ %s:%d: %s\n",e,__FILE__,__LINE__,s?s:"?"); return 1;}}while(0)
#define RT(call) do { cudaError_t e=(call); if(e!=cudaSuccess){ \
  fprintf(stderr,"RT err %s @ %s:%d\n",cudaGetErrorString(e),__FILE__,__LINE__); return 1;}}while(0)
#define BL(call) do { cublasStatus_t s=(call); if(s!=CUBLAS_STATUS_SUCCESS){ \
  fprintf(stderr,"cuBLAS err %d @ %s:%d\n",(int)s,__FILE__,__LINE__); return 1;}}while(0)

static int cmpd(const void*a,const void*b){ double x=*(const double*)a,y=*(const double*)b; return x<y?-1:x>y?1:0; }
static uint32_t lcg_state=0x12345678u;
static float lcg_f32(void){ lcg_state=lcg_state*1664525u+1013904223u; return ((float)(lcg_state>>8)/(float)(1u<<24))-0.5f; }
static uint16_t f32_to_f16(float f){ uint32_t x; memcpy(&x,&f,4); uint32_t sign=(x>>16)&0x8000u; int32_t exp=(int32_t)((x>>23)&0xff)-112; uint32_t man=x&0x7fffffu;
  if(exp<=0){ if(exp<-10) return (uint16_t)sign; man|=0x800000u; uint32_t sh=(uint32_t)(14-exp); uint32_t h=man>>sh; uint32_t rem=man&((1u<<sh)-1); if(rem>(1u<<(sh-1))||(rem==(1u<<(sh-1))&&(h&1)))h++; return (uint16_t)(sign|h);}
  else if(exp>=31) return (uint16_t)(sign|0x7c00u);
  else { uint32_t h=((uint32_t)exp<<10)|(man>>13); uint32_t rem=man&0x1fffu; if(rem>0x1000u||(rem==0x1000u&&(h&1)))h++; return (uint16_t)(sign|h);} }
static float f16_to_f32(uint16_t h){ uint32_t sign=(uint32_t)(h&0x8000u)<<16; uint32_t exp=(h>>10)&0x1f; uint32_t man=h&0x3ff; uint32_t out;
  if(exp==0){ if(man==0)out=sign; else { exp=113; while((man&0x400)==0){man<<=1;exp--;} man&=0x3ff; out=sign|(exp<<23)|(man<<13);} }
  else if(exp==31) out=sign|0x7f800000u|(man<<13);
  else out=sign|((exp-15+127)<<23)|(man<<13);
  float f; memcpy(&f,&out,4); return f; }

/* TMA 2D descriptor for a row-major [outer x inner] fp16 tile, box [box_inner, box_outer]. */
static int build_tma(CUtensorMap* out, CUdeviceptr base, unsigned inner, unsigned outer,
                     unsigned bi, unsigned bo, CUtensorMapSwizzle sw){
    cuuint64_t gdim[2]={ (cuuint64_t)inner,(cuuint64_t)outer };
    cuuint64_t gstride[1]={ (cuuint64_t)inner*2 };
    cuuint32_t bdim[2]={ (cuuint32_t)bi,(cuuint32_t)bo };
    cuuint32_t estride[2]={1,1};
    CU(cuTensorMapEncodeTiled(out, CU_TENSOR_MAP_DATA_TYPE_FLOAT16, 2, (void*)base,
        gdim, gstride, bdim, estride, CU_TENSOR_MAP_INTERLEAVE_NONE, sw,
        CU_TENSOR_MAP_L2_PROMOTION_NONE, CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE));
    return 0;
}

__global__ void softmax_rows(__half* S, int N){
    int row=blockIdx.x; if(row>=N) return;
    extern __shared__ float buf[]; int t=threadIdx.x, nt=blockDim.x;
    float m=-1e30f; for(int j=t;j<N;j+=nt){ float v=__half2float(S[(size_t)row*N+j]); if(v>m)m=v; }
    buf[t]=m; __syncthreads();
    for(int s=nt/2;s>0;s>>=1){ if(t<s&&buf[t+s]>buf[t])buf[t]=buf[t+s]; __syncthreads(); }
    float rmax=buf[0]; __syncthreads();
    float sum=0.0f; for(int j=t;j<N;j+=nt){ float e=expf(__half2float(S[(size_t)row*N+j])-rmax); S[(size_t)row*N+j]=__float2half(e); sum+=e; }
    buf[t]=sum; __syncthreads();
    for(int s=nt/2;s>0;s>>=1){ if(t<s)buf[t]+=buf[t+s]; __syncthreads(); }
    float rsum=buf[0]; float inv=1.0f/rsum; __syncthreads();
    for(int j=t;j<N;j+=nt) S[(size_t)row*N+j]=__float2half(__half2float(S[(size_t)row*N+j])*inv);
}

int main(int argc, char** argv){
    if(argc<3){ fprintf(stderr,"usage: %s flash_attn_tma_sw128_N.ptx N\n",argv[0]); return 2; }
    const char* ptx_path=argv[1]; int N=atoi(argv[2]); int d=64;
    if(N%64){ fprintf(stderr,"N must be multiple of 64\n"); return 2; }
    const char* kname="flash_attn_tma_sw128";

    FILE* fp=fopen(ptx_path,"rb"); if(!fp){perror("ptx");return 1;}
    fseek(fp,0,SEEK_END); long np=ftell(fp); fseek(fp,0,SEEK_SET);
    char* ptx=(char*)malloc(np+1); if(fread(ptx,1,np,fp)!=(size_t)np){perror("read");return 1;} ptx[np]=0; fclose(fp);

    CU(cuInit(0)); CUdevice dev; CU(cuDeviceGet(&dev,0)); CUcontext ctx; CU(cuCtxCreate(&ctx,0,dev));
    char dn[256]; CU(cuDeviceGetName(dn,sizeof(dn),dev));
    int smaj=0,smin=0; CU(cuDeviceGetAttribute(&smaj,CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR,dev));
    CU(cuDeviceGetAttribute(&smin,CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR,dev));
    int drv=0; CU(cuDriverGetVersion(&drv));
    printf("Device: %s sm_%d%d driver=%d\n", dn, smaj, smin, drv);

    char logerr[8192]; logerr[0]=0; char loginfo[8192]; loginfo[0]=0;
    CUjit_option jo[5]={CU_JIT_TARGET_FROM_CUCONTEXT,CU_JIT_ERROR_LOG_BUFFER,CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,CU_JIT_INFO_LOG_BUFFER,CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES};
    void* jv[5]={(void*)0,(void*)logerr,(void*)(uintptr_t)sizeof(logerr),(void*)loginfo,(void*)(uintptr_t)sizeof(loginfo)};
    CUmodule mod; CUresult le=cuModuleLoadDataEx(&mod,ptx,5,jo,jv);
    if(le!=CUDA_SUCCESS){ const char*s=NULL; cuGetErrorString(le,&s); fprintf(stderr,"load fail: %s\n  ptxas: %s\n",s?s:"?",logerr); return 1; }
    if(loginfo[0]) printf("ptxas info: %s\n", loginfo);
    CUfunction f; CU(cuModuleGetFunction(&f,mod,kname));
    int regs=0, smem_static=0;
    cuFuncGetAttribute(&regs, CU_FUNC_ATTRIBUTE_NUM_REGS, f);
    cuFuncGetAttribute(&smem_static, CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES, f);
    printf("kernel: regs/thd=%d static_smem=%d B\n", regs, smem_static);

    /* dynamic smem opt-in (the kernel uses ~82.7 KB dynamic) */
    int dyn_smem = 82752;
    CUresult sa = cuFuncSetAttribute(f, CU_FUNC_ATTRIBUTE_MAX_DYNAMIC_SHARED_SIZE_BYTES, dyn_smem);
    if(sa!=CUDA_SUCCESS){ const char*s=NULL; cuGetErrorString(sa,&s); fprintf(stderr,"smem opt-in fail (%d B): %s\n", dyn_smem, s?s:"?"); }

    size_t elems=(size_t)N*d;
    float *hqf=(float*)malloc(elems*4),*hkf=(float*)malloc(elems*4),*hvf=(float*)malloc(elems*4);
    uint16_t *hq=(uint16_t*)malloc(elems*2),*hk=(uint16_t*)malloc(elems*2),*hv=(uint16_t*)malloc(elems*2),*ho=(uint16_t*)malloc(elems*2);
    double* ref=(double*)malloc(elems*8);
    for(size_t i=0;i<elems;++i){ hqf[i]=f16_to_f32(f32_to_f16(lcg_f32()*4.0f)); hq[i]=f32_to_f16(hqf[i]); }
    for(size_t i=0;i<elems;++i){ hkf[i]=f16_to_f32(f32_to_f16(lcg_f32()*4.0f)); hk[i]=f32_to_f16(hkf[i]); }
    for(size_t i=0;i<elems;++i){ hvf[i]=f16_to_f32(f32_to_f16(lcg_f32()));      hv[i]=f32_to_f16(hvf[i]); }
    float scale=1.0f/sqrtf((float)d);

    /* f64 CPU ref on the f16-rounded inputs */
    double* srow=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){ double m=-1e300;
        for(int j=0;j<N;++j){ double s=0; for(int l=0;l<d;++l) s+=(double)hqf[(size_t)i*d+l]*(double)hkf[(size_t)j*d+l]; s*=(double)scale; srow[j]=s; if(s>m)m=s; }
        double sum=0; for(int j=0;j<N;++j){ srow[j]=exp(srow[j]-m); sum+=srow[j]; } double inv=1.0/sum;
        for(int e=0;e<d;++e){ double acc=0; for(int j=0;j<N;++j) acc+=srow[j]*(double)hvf[(size_t)j*d+e]; ref[(size_t)i*d+e]=acc*inv; } }
    free(srow);

    CUdeviceptr dq,dk,dv,dO; size_t b16=elems*2;
    CU(cuMemAlloc(&dq,b16)); CU(cuMemAlloc(&dk,b16)); CU(cuMemAlloc(&dv,b16)); CU(cuMemAlloc(&dO,b16));
    CU(cuMemcpyHtoD(dq,hq,b16)); CU(cuMemcpyHtoD(dk,hk,b16)); CU(cuMemcpyHtoD(dv,hv,b16));

    /* TMA descriptors: Q/K/V are row-major [N x 64] fp16. Box [64 inner fp16=128B, 64 rows]. */
    CUtensorMap tq,tk,tv;
    if(build_tma(&tq,dq,(unsigned)d,(unsigned)N,64,64,CU_TENSOR_MAP_SWIZZLE_128B)) return 1;
    if(build_tma(&tk,dk,(unsigned)d,(unsigned)N,64,64,CU_TENSOR_MAP_SWIZZLE_128B)) return 1;
    if(build_tma(&tv,dv,(unsigned)d,(unsigned)N,64,64,CU_TENSOR_MAP_SWIZZLE_128B)) return 1;

    unsigned grid=(unsigned)(N/64), block=128;
    void* args[]={ &tq,&tk,&tv,&dO,&N,&scale };
    printf("[geom] grid=%u CTAs (vs 48 SMs) block=%u dyn_smem=%d\n", grid, block, dyn_smem);

    /* correctness */
    CUresult lr=cuLaunchKernel(f,grid,1,1,block,1,1,dyn_smem,0,args,0);
    if(lr!=CUDA_SUCCESS){ const char*s=NULL; cuGetErrorString(lr,&s); fprintf(stderr,"launch fail: %s\n",s?s:"?"); return 1; }
    CUresult sr=cuCtxSynchronize();
    if(sr!=CUDA_SUCCESS){ const char*s=NULL; cuGetErrorString(sr,&s); fprintf(stderr,"sync fail: %s\n",s?s:"?"); return 1; }
    CU(cuMemcpyDtoH(ho,dO,b16));

    double max_rel=0,max_abs=0,max_rel_rowscale=0,sse=0,ssref=0;
    double* rowmax=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){ double mx=0; for(int e=0;e<d;++e){ double w=fabs(ref[(size_t)i*d+e]); if(w>mx)mx=w; } rowmax[i]=mx; }
    for(size_t i=0;i<elems;++i){ double got=(double)f16_to_f32(ho[i]); double want=ref[i]; double a=fabs(got-want); double r=a/(fabs(want)+1e-6);
        if(a>max_abs)max_abs=a; if(r>max_rel)max_rel=r; int row=(int)(i/d); double rr=a/(rowmax[row]+1e-9); if(rr>max_rel_rowscale)max_rel_rowscale=rr; sse+=a*a; ssref+=want*want; }
    double rms_rel=sqrt(sse/(ssref+1e-30));
    int numeric_pass=(max_rel_rowscale<=1e-2);
    printf("NUMERIC N=%d max_abs=%.6g max_rel_naive=%.6g max_rel_rowscale=%.6g rms_rel=%.6g => %s\n",
        N, max_abs, max_rel, max_rel_rowscale, rms_rel, numeric_pass?"PASS":"FAIL");

    /* timed fused wall: 20 warmup + 200 timed median */
    int reps=200; double* ms=(double*)malloc(reps*8);
    CUevent st,en; CU(cuEventCreate(&st,0)); CU(cuEventCreate(&en,0));
    for(int w=0;w<20;++w) CU(cuLaunchKernel(f,grid,1,1,block,1,1,dyn_smem,0,args,0));
    CU(cuCtxSynchronize());
    for(int r=0;r<reps;++r){ CU(cuEventRecord(st,0)); CU(cuLaunchKernel(f,grid,1,1,block,1,1,dyn_smem,0,args,0)); CU(cuEventRecord(en,0)); CU(cuEventSynchronize(en)); float t; CU(cuEventElapsedTime(&t,st,en)); ms[r]=t; }
    qsort(ms,reps,8,cmpd); double fused_ms=ms[reps/2];
    printf("fused_tma_sw128 median_ms=%.6f\n", fused_ms);

    /* cuBLAS-TC 3-launch baseline (same as round-4) */
    cublasHandle_t h; BL(cublasCreate(&h)); BL(cublasSetMathMode(h,CUBLAS_TENSOR_OP_MATH));
    __half *bq=(__half*)malloc(elems*2),*bk=(__half*)malloc(elems*2),*bv=(__half*)malloc(elems*2);
    for(size_t i=0;i<elems;++i){ bq[i]=__float2half(hqf[i]); bk[i]=__float2half(hkf[i]); bv[i]=__float2half(hvf[i]); }
    __half *cq,*ck,*cv,*cS,*cO;
    RT(cudaMalloc(&cq,elems*2)); RT(cudaMalloc(&ck,elems*2)); RT(cudaMalloc(&cv,elems*2));
    RT(cudaMalloc(&cS,(size_t)N*N*2)); RT(cudaMalloc(&cO,elems*2));
    RT(cudaMemcpy(cq,bq,elems*2,cudaMemcpyHostToDevice)); RT(cudaMemcpy(ck,bk,elems*2,cudaMemcpyHostToDevice)); RT(cudaMemcpy(cv,bv,elems*2,cudaMemcpyHostToDevice));
    float alpha=scale, beta=0.0f, one=1.0f; int smblk=256; size_t smb=smblk*4;
    #define SEQ() do { \
        BL(cublasGemmEx(h,CUBLAS_OP_T,CUBLAS_OP_N,N,N,d,&alpha, ck,CUDA_R_16F,d, cq,CUDA_R_16F,d,&beta, cS,CUDA_R_16F,N,CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP)); \
        softmax_rows<<<N,smblk,smb>>>(cS,N); \
        BL(cublasGemmEx(h,CUBLAS_OP_N,CUBLAS_OP_N,d,N,N,&one, cv,CUDA_R_16F,d, cS,CUDA_R_16F,N,&beta, cO,CUDA_R_16F,d,CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP)); \
    } while(0)
    for(int w=0;w<20;++w) SEQ();
    RT(cudaDeviceSynchronize());
    cudaEvent_t cst,cen; RT(cudaEventCreate(&cst)); RT(cudaEventCreate(&cen));
    for(int r=0;r<reps;++r){ RT(cudaEventRecord(cst,0)); SEQ(); RT(cudaEventRecord(cen,0)); RT(cudaEventSynchronize(cen)); float t; RT(cudaEventElapsedTime(&t,cst,cen)); ms[r]=t; }
    qsort(ms,reps,8,cmpd); double cublas_ms=ms[reps/2];
    printf("cublas_tc_3launch median_ms=%.6f\n", cublas_ms);

    /* roofline */
    double attn_flops = 4.0*(double)N*(double)N*(double)d;
    double fused_tflops = attn_flops/(fused_ms/1000.0)/1e12;
    double cublas_tflops = attn_flops/(cublas_ms/1000.0)/1e12;
    double ratio = fused_ms/cublas_ms;
    /* theoretical FP16-TC peak sm_120: 48 SM * 4 tensor cores/SM * 256 FMA/cycle * 2 (FMA=2 FLOP) * 2.542e9
       = a stated assumption; we report it but the achievable ceiling is the cuBLAS HGEMM sat ~70.2 TFLOPS. */
    double clk = 2.542e9; int SM=48;
    double tc_peak_theo = (double)SM * 4.0 * 256.0 * 2.0 * clk / 1e12;   /* assumption */
    double cublas_hgemm_ceiling = 70.2;  /* GPU.md sec1g N204 @M=8192 measured */
    printf("ROOFLINE attn_flops=%.4g fused_TFLOPS=%.4f cublas_TFLOPS=%.4f ratio=%.4f\n", attn_flops, fused_tflops, cublas_tflops, ratio);
    printf("ROOFLINE pct_of_cublas_hgemm_ceiling(%.1f)=%.2f%% pct_of_theo_TC_peak(%.1f)=%.2f%%\n",
        cublas_hgemm_ceiling, 100.0*fused_tflops/cublas_hgemm_ceiling, tc_peak_theo, 100.0*fused_tflops/tc_peak_theo);

    /* result.json (single shape; the run-script concatenates shapes) */
    FILE* rj=fopen("result_partial.json","a");
    fprintf(rj,"{\"N\":%d,\"d\":%d,\"regs\":%d,\"dyn_smem\":%d,\"grid_ctas\":%u,"
        "\"numeric\":{\"max_abs\":%.6g,\"max_rel_rowscale\":%.6g,\"rms_rel\":%.6g,\"pass\":%s},"
        "\"fused_ms\":%.6f,\"cublas_tc_ms\":%.6f,\"ratio\":%.4f,"
        "\"fused_tflops\":%.4f,\"cublas_tflops\":%.4f,"
        "\"pct_cublas_hgemm_ceiling\":%.2f,\"pct_theo_tc_peak\":%.2f}\n",
        N,d,regs,dyn_smem,grid, max_abs,max_rel_rowscale,rms_rel,numeric_pass?"true":"false",
        fused_ms,cublas_ms,ratio,fused_tflops,cublas_tflops,
        100.0*fused_tflops/cublas_hgemm_ceiling, 100.0*fused_tflops/tc_peak_theo);
    fclose(rj);

    cublasDestroy(h); cuModuleUnload(mod); cuCtxDestroy(ctx);
    return numeric_pass?0:1;
}
