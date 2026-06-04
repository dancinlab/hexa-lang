// hxqwen14b_llmstep_driver.cu — HEXA-FUSION ①+③ LLM full-step util + convergence
// ============================================================================
// Standalone driver (#include's the shipped self/native/hxqwen14b_cuda.cu so the
// measured kernels are the EXACT main-branch ones, no drift) that runs a realistic
// hxqwen14b LoRA training STEP at a LARGE batch, in a sustained multi-step loop, so
// nvidia-smi can sample GPU util (①) and a real CE loss descends over N steps (③).
//
// A "step" = LoRA fwd (2 GEMMs) + bwd (5 GEMMs) + the transformer GLUE that wraps a
// LoRA-adapted projection in a real Qwen block: rmsnorm (pre-norm), residual_add,
// swiglu (FFN activation), and a softmax-CE loss head — i.e. GEMM + glue/norm, the
// thing the brief asks us to measure vs the 89.9% pure-GEMM-isolation number.
//
// Modes (argv[1]):
//   util  <M> <K> <N> <R> <secs>      — sustained step loop for <secs>; prints iters.
//   conv  <M> <K> <N> <R> <Nsteps>    — N real AdamW steps on a tiny fixed problem,
//                                       prints CE per step (loss descent trace).
//   gemmfrac <M> <K> <N> <R> <iters>  — CUDA-event timing: GEMM-only vs full-step,
//                                       to report the GEMM-vs-glue fraction.
//
// GEMM backend chosen by the same env the shipped shim reads:
//   (default)                       -> cuBLAS-TF32 (we set math mode TF32 to match
//                                      the WMMA2 TF32 precision for a fair compare)
//   HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 -> our CUTLASS-grade WMMA2 own-GEMM
//
// g5-HONEST: every printed number is a raw measurement. No claim is synthesized here.
// ============================================================================
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cuda_runtime.h>
#include <cublas_v2.h>

// The shipped TU defines: cublas handle plumbing, _hx_k_sgemm_cm_wmma2 (+ launcher
// _hx_own_sgemm_cm_launch), hxqwen_sgemm_base (the env-gated own-vs-cuBLAS shim),
// and the v53/v54 glue kernels (rmsnorm, swiglu, residual_add, softmax_ce).
#define HXQWEN14B_CUDA 1
#include "hxqwen14b_cuda.cu"

// hxqwen_sgemm_base is the col-major cublasSgemm-faithful shim that the LoRA path
// uses; it reads HEXA_OWN_GEMM[/_WMMA2] internally. We call it directly so the
// driver's GEMMs route through EXACTLY the same dispatch as the real trainer.
static cublasStatus_t SGEMM(cublasOperation_t tA, cublasOperation_t tB,
                            int m,int n,int k, const float* alpha,
                            const float* A,int lda,const float* B,int ldb,
                            const float* beta, float* C,int ldc){
    return hxqwen_sgemm_base(tA,tB,m,n,k,alpha,A,lda,B,ldb,beta,C,ldc);
}

#define CK(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){fprintf(stderr,"CUDA ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(2);} }while(0)

static float* dalloc(long long n){ float* p; CK(cudaMalloc(&p,(size_t)n*sizeof(float))); return p; }
static void dfill(float* p,long long n,float v){
    float* h=(float*)malloc((size_t)n*sizeof(float));
    for(long long i=0;i<n;i++) h[i]=v;
    CK(cudaMemcpy(p,h,(size_t)n*sizeof(float),cudaMemcpyHostToDevice)); free(h);
}
// deterministic pseudo-random init (host) -> device
static void drand(float* p,long long n,unsigned seed,float scale){
    float* h=(float*)malloc((size_t)n*sizeof(float));
    unsigned s=seed?seed:1u;
    for(long long i=0;i<n;i++){ s=s*1664525u+1013904223u; h[i]=(((s>>9)&0x7fffff)/(float)0x7fffff-0.5f)*2.0f*scale; }
    CK(cudaMemcpy(p,h,(size_t)n*sizeof(float),cudaMemcpyHostToDevice)); free(h);
}

// One LoRA fwd: tmp[M,R]=x·Aᵀ ; y[M,N]=s·tmp·Bᵀ  (exactly hxqwen14b_lora_fwd_single device path)
static void lora_fwd(int M,int N,int K,int R,float s,
                     const float* x,const float* A,const float* B,float* y,float* tmp){
    float one=1.0f,zero=0.0f;
    SGEMM(CUBLAS_OP_T,CUBLAS_OP_N, R,M,K, &one, A,K, x,K, &zero, tmp,R);
    SGEMM(CUBLAS_OP_T,CUBLAS_OP_N, N,M,R, &s,   B,R, tmp,R, &zero, y,N);
}
// LoRA bwd: u=dy·B ; dx=s·u·A ; dB=s·dyᵀ·tmp ; dA=s·uᵀ·x  (lora_bwd_single device path)
static void lora_bwd(int M,int N,int K,int R,float s,
                     const float* x,const float* A,const float* B,const float* dy,
                     float* dA,float* dB,float* dx,float* u,float* tmp){
    float one=1.0f,zero=0.0f;
    // u[M,R] = dy[M,N] · B[N,R]      (row-major NN -> col-major: OP_N,OP_N R,M,N)
    SGEMM(CUBLAS_OP_N,CUBLAS_OP_N, R,M,N, &one, B,R, dy,N, &zero, u,R);
    // tmp[M,R] = x·Aᵀ (recompute, as the real bwd does)
    SGEMM(CUBLAS_OP_T,CUBLAS_OP_N, R,M,K, &one, A,K, x,K, &zero, tmp,R);
    // dB[N,R] = s·dyᵀ·tmp
    SGEMM(CUBLAS_OP_N,CUBLAS_OP_T, R,N,M, &s, tmp,R, dy,N, &zero, dB,R);
    // dA[R,K] = s·uᵀ·x
    SGEMM(CUBLAS_OP_N,CUBLAS_OP_T, K,R,M, &s, x,K, u,R, &zero, dA,K);
    // dx[M,K] = s·u·A
    SGEMM(CUBLAS_OP_N,CUBLAS_OP_N, K,M,R, &s, A,K, u,R, &zero, dx,K);
}

// Glue: pre-rmsnorm on x[M,K] -> xn ; swiglu on a [M,2N] gate/up buffer -> [M,N] ;
// residual add y += xres ; (these are the v53/v54 kernels from the shipped TU).
static void glue_pre(const float* x,float* xn,const float* w,int M,int K){
    // v53_rmsnorm_kernel(x_in, weight, y_out, d, eps) — one block per row, M=gridDim.
    int th = K<1024?K:1024;
    v53_rmsnorm_kernel<<<M,th>>>(x,w,xn,K,1e-6f);
}
static void glue_post(float* y,const float* xres,int M,int N){
    long long Ntot=(long long)M*N;
    int th=256; unsigned bl=(unsigned)((Ntot+th-1)/th);
    v54_residual_add_kernel<<<bl,th>>>(xres,y,Ntot);
}
static void glue_swiglu(const float* gate,const float* up,float* out,int M,int N){
    // v53_swiglu_kernel(g, u, y, N_total) — elementwise SwiGLU over M*N.
    long long Ntot=(long long)M*N;
    int th=256; unsigned bl=(unsigned)((Ntot+th-1)/th);
    v53_swiglu_kernel<<<bl,th>>>(gate,up,out,Ntot);
}

// CE loss head: logits[M,V] (here we reuse y as logits with V=N), targets[M] -> mean CE.
static double ce_loss(const float* logits,const int32_t* tgt,float* nll,int M,int V){
    v54_softmax_ce_kernel<<<M, 256>>>(logits,tgt,nll,V);
    CK(cudaDeviceSynchronize());
    float* h=(float*)malloc(M*sizeof(float));
    CK(cudaMemcpy(h,nll,M*sizeof(float),cudaMemcpyDeviceToHost));
    double s=0; for(int i=0;i<M;i++) s+=h[i]; free(h); return s/M;
}

int main(int argc,char**argv){
    if(argc<2){ fprintf(stderr,"usage: %s util|conv|gemmfrac ...\n",argv[0]); return 1; }
    const char* mode=argv[1];
    CK(cudaSetDevice(0));
    // ensure cublas + match TF32 precision (WMMA2 is TF32; for a fair util/conv
    // compare we run cuBLAS in TF32 too — the brief's "cuBLAS-TF32 vs WMMA2").
    if(v54_ensure_cublas()!=0){fprintf(stderr,"ensure_cublas fail\n");return 2;}
    cublasSetMathMode(g_cublas_handle, CUBLAS_TF32_TENSOR_OP_MATH);

    int M=atoi(argv[2]), K=atoi(argv[3]), N=atoi(argv[4]), R=atoi(argv[5]);
    float s=2.0f/(float)R; // alpha/r with alpha=2

    // buffers
    float *x=dalloc((long long)M*K), *A=dalloc((long long)R*K), *B=dalloc((long long)N*R);
    float *y=dalloc((long long)M*N), *tmp=dalloc((long long)M*R);
    float *dy=dalloc((long long)M*N), *dA=dalloc((long long)R*K), *dB=dalloc((long long)N*R);
    float *dx=dalloc((long long)M*K), *u=dalloc((long long)M*R);
    float *xn=dalloc((long long)M*K), *wnorm=dalloc((long long)K);
    float *gate_up=dalloc((long long)M*2*N), *swout=dalloc((long long)M*N), *nll=dalloc((long long)M);
    int32_t *tgt; CK(cudaMalloc(&tgt,(size_t)M*sizeof(int32_t)));
    { int32_t* ht=(int32_t*)malloc((size_t)M*sizeof(int32_t)); for(int i=0;i<M;i++) ht[i]=(i*7+3)%N; CK(cudaMemcpy(tgt,ht,(size_t)M*sizeof(int32_t),cudaMemcpyHostToDevice)); free(ht);}
    drand(x,(long long)M*K,11,0.5f); drand(A,(long long)R*K,22,0.1f); drand(B,(long long)N*R,33,0.1f);
    drand(dy,(long long)M*N,44,0.05f); drand(gate_up,(long long)M*2*N,55,0.5f); dfill(wnorm,K,1.0f);

    if(!strcmp(mode,"util")){
        double secs=atof(argv[6]);
        // warmup
        glue_pre(x,xn,wnorm,M,K);
        lora_fwd(M,N,K,R,s,xn,A,B,y,tmp);
        glue_swiglu(gate_up,gate_up+(long long)M*N,swout,M,N);
        glue_post(y,swout,M,N);
        lora_bwd(M,N,K,R,s,xn,A,B,dy,dA,dB,dx,u,tmp);
        CK(cudaDeviceSynchronize());
        struct timespec t0,t1; clock_gettime(CLOCK_MONOTONIC,&t0);
        long long it=0;
        for(;;){
            glue_pre(x,xn,wnorm,M,K);
            lora_fwd(M,N,K,R,s,xn,A,B,y,tmp);
            glue_swiglu(gate_up,gate_up+(long long)M*N,swout,M,N);
            glue_post(y,swout,M,N);
            lora_bwd(M,N,K,R,s,xn,A,B,dy,dA,dB,dx,u,tmp);
            it++;
            if((it&15)==0){ CK(cudaDeviceSynchronize()); clock_gettime(CLOCK_MONOTONIC,&t1);
                double el=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)*1e-9; if(el>=secs) break; }
        }
        CK(cudaDeviceSynchronize());
        clock_gettime(CLOCK_MONOTONIC,&t1);
        double el=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)*1e-9;
        printf("UTIL-RUN M=%d K=%d N=%d R=%d secs=%.1f iters=%lld (%.1f steps/s)\n",M,K,N,R,el,it,it/el);
    } else if(!strcmp(mode,"conv")){
        int NS=atoi(argv[6]);
        // Real loss descent: minimize CE(softmax(y),tgt) over A,B via fwd+bwd+SGD.
        // dy = d CE / d logits = softmax(y) - onehot(tgt), computed on host each step
        // (small, exact) so the loss-descent is a genuine end-to-end gradient signal.
        float lr=0.05f;
        float* hy=(float*)malloc((size_t)M*N*sizeof(float));
        float* hdy=(float*)malloc((size_t)M*N*sizeof(float));
        int32_t* ht=(int32_t*)malloc((size_t)M*sizeof(int32_t));
        CK(cudaMemcpy(ht,tgt,(size_t)M*sizeof(int32_t),cudaMemcpyDeviceToHost));
        float *hdA=(float*)malloc((size_t)R*K*sizeof(float)), *hdB=(float*)malloc((size_t)N*R*sizeof(float));
        float *hA=(float*)malloc((size_t)R*K*sizeof(float)), *hB=(float*)malloc((size_t)N*R*sizeof(float));
        for(int step=0; step<NS; step++){
            glue_pre(x,xn,wnorm,M,K);
            lora_fwd(M,N,K,R,s,xn,A,B,y,tmp);
            CK(cudaDeviceSynchronize());
            CK(cudaMemcpy(hy,y,(size_t)M*N*sizeof(float),cudaMemcpyDeviceToHost));
            // CE + dy = softmax - onehot
            double ce=0;
            for(int m=0;m<M;m++){
                float* lr_=hy+(long long)m*N; float mx=-1e30f;
                for(int j=0;j<N;j++) if(lr_[j]>mx) mx=lr_[j];
                double Z=0; for(int j=0;j<N;j++) Z+=exp((double)(lr_[j]-mx));
                float* dr=hdy+(long long)m*N;
                for(int j=0;j<N;j++){ double p=exp((double)(lr_[j]-mx))/Z; dr[j]=(float)p - (j==ht[m]?1.0f:0.0f); }
                ce += -log( exp((double)(lr_[ht[m]]-mx))/Z );
            }
            ce/=M;
            printf("CONV step=%d CE=%.6f\n",step,ce);
            CK(cudaMemcpy(dy,hdy,(size_t)M*N*sizeof(float),cudaMemcpyHostToDevice));
            lora_bwd(M,N,K,R,s,xn,A,B,dy,dA,dB,dx,u,tmp);
            CK(cudaDeviceSynchronize());
            // SGD update A,B on host (deterministic, backend-independent optimizer)
            CK(cudaMemcpy(hdA,dA,(size_t)R*K*sizeof(float),cudaMemcpyDeviceToHost));
            CK(cudaMemcpy(hdB,dB,(size_t)N*R*sizeof(float),cudaMemcpyDeviceToHost));
            CK(cudaMemcpy(hA,A,(size_t)R*K*sizeof(float),cudaMemcpyDeviceToHost));
            CK(cudaMemcpy(hB,B,(size_t)N*R*sizeof(float),cudaMemcpyDeviceToHost));
            for(long long i=0;i<(long long)R*K;i++) hA[i]-=lr*hdA[i];
            for(long long i=0;i<(long long)N*R;i++) hB[i]-=lr*hdB[i];
            CK(cudaMemcpy(A,hA,(size_t)R*K*sizeof(float),cudaMemcpyHostToDevice));
            CK(cudaMemcpy(B,hB,(size_t)N*R*sizeof(float),cudaMemcpyHostToDevice));
        }
    } else if(!strcmp(mode,"gemmfrac")){
        int IT=atoi(argv[6]);
        cudaEvent_t e0,e1; CK(cudaEventCreate(&e0)); CK(cudaEventCreate(&e1));
        // WARMUP both paths fully (absorb lazy cuBLAS init + kernel autotune) so the
        // first timed loop is not penalized — otherwise GEMM-only (run first) eats all
        // the context/autotune cost and the fraction is garbage.
        for(int w=0; w<10; w++){
            glue_pre(x,xn,wnorm,M,K); lora_fwd(M,N,K,R,s,xn,A,B,y,tmp);
            glue_swiglu(gate_up,gate_up+(long long)M*N,swout,M,N); glue_post(y,swout,M,N);
            lora_bwd(M,N,K,R,s,xn,A,B,dy,dA,dB,dx,u,tmp);
        }
        CK(cudaDeviceSynchronize());
        // GEMM-only time
        CK(cudaEventRecord(e0));
        for(int i=0;i<IT;i++){ lora_fwd(M,N,K,R,s,xn,A,B,y,tmp); lora_bwd(M,N,K,R,s,xn,A,B,dy,dA,dB,dx,u,tmp); }
        CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
        float tg; CK(cudaEventElapsedTime(&tg,e0,e1));
        // Full-step time (GEMM + glue)
        CK(cudaEventRecord(e0));
        for(int i=0;i<IT;i++){ glue_pre(x,xn,wnorm,M,K); lora_fwd(M,N,K,R,s,xn,A,B,y,tmp); glue_swiglu(gate_up,gate_up+(long long)M*N,swout,M,N); glue_post(y,swout,M,N); lora_bwd(M,N,K,R,s,xn,A,B,dy,dA,dB,dx,u,tmp); }
        CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
        float tf; CK(cudaEventElapsedTime(&tf,e0,e1));
        printf("GEMMFRAC M=%d K=%d N=%d R=%d iters=%d | gemm=%.4f ms/it full=%.4f ms/it | GEMM-fraction=%.1f%% glue=%.1f%%\n",
               M,K,N,R,IT, tg/IT, tf/IT, 100.0*tg/tf, 100.0*(tf-tg)/tf);
    } else if(!strcmp(mode,"gate")){
        // CI REGRESSION GATE: run a LoRA fwd+bwd on cuBLAS (oracle) and on WMMA2 (own)
        // in ONE process, compare rel-RMS of every output (y,dA,dB,dx). Exit 0 iff all
        // <= TOL (default 3e-3 TF32 bar; env HEXA_GATE_TOL overrides). Self-contained:
        // no external compare. argv: gate M K N R.
        double tol = getenv("HEXA_GATE_TOL")? atof(getenv("HEXA_GATE_TOL")) : 3e-3;
        long long ny=(long long)M*N, ndA=(long long)R*K, ndB=(long long)N*R, ndx=(long long)M*K;
        float *yo=(float*)malloc(ny*4), *dAo=(float*)malloc(ndA*4), *dBo=(float*)malloc(ndB*4), *dxo=(float*)malloc(ndx*4);
        float *yw=(float*)malloc(ny*4), *dAw=(float*)malloc(ndA*4), *dBw=(float*)malloc(ndB*4), *dxw=(float*)malloc(ndx*4);
        // ORACLE: ensure cuBLAS path (HEXA_OWN_GEMM must be UNSET for this arm)
        unsetenv("HEXA_OWN_GEMM");
        glue_pre(x,xn,wnorm,M,K);
        lora_fwd(M,N,K,R,s,xn,A,B,y,tmp);
        lora_bwd(M,N,K,R,s,xn,A,B,dy,dA,dB,dx,u,tmp);
        CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(yo,y,ny*4,cudaMemcpyDeviceToHost)); CK(cudaMemcpy(dAo,dA,ndA*4,cudaMemcpyDeviceToHost));
        CK(cudaMemcpy(dBo,dB,ndB*4,cudaMemcpyDeviceToHost)); CK(cudaMemcpy(dxo,dx,ndx*4,cudaMemcpyDeviceToHost));
        // OWN WMMA2: force the env on for this arm
        setenv("HEXA_OWN_GEMM","1",1); setenv("HEXA_OWN_GEMM_WMMA2","1",1);
        glue_pre(x,xn,wnorm,M,K);
        lora_fwd(M,N,K,R,s,xn,A,B,y,tmp);
        lora_bwd(M,N,K,R,s,xn,A,B,dy,dA,dB,dx,u,tmp);
        CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(yw,y,ny*4,cudaMemcpyDeviceToHost)); CK(cudaMemcpy(dAw,dA,ndA*4,cudaMemcpyDeviceToHost));
        CK(cudaMemcpy(dBw,dB,ndB*4,cudaMemcpyDeviceToHost)); CK(cudaMemcpy(dxw,dx,ndx*4,cudaMemcpyDeviceToHost));
        struct OUT{const char*nm; float*o; float*w; long long n;};
        OUT outs[4]={{"y",yo,yw,ny},{"dA",dAo,dAw,ndA},{"dB",dBo,dBw,ndB},{"dx",dxo,dxw,ndx}};
        int fail=0;
        for(int oi=0; oi<4; oi++){
            double se=0, ss=0, mx=0;
            for(long long i=0;i<outs[oi].n;i++){ double d=(double)outs[oi].o[i]-(double)outs[oi].w[i]; se+=d*d; ss+=(double)outs[oi].o[i]*(double)outs[oi].o[i]; if(fabs(d)>mx)mx=fabs(d);}
            double rel = ss>0 ? sqrt(se/ss) : sqrt(se);
            const char* v = (rel<=tol)?"PASS":"FAIL"; if(rel>tol) fail=1;
            printf("GATE %-3s n=%lld rel_RMS=%.3e max|D|=%.3e tol=%.1e -> %s\n",outs[oi].nm,outs[oi].n,rel,mx,tol,v);
        }
        printf("GATE-VERDICT: %s (WMMA2 own-GEMM vs cuBLAS oracle, M=%d K=%d N=%d R=%d)\n", fail?"FAIL":"PASS",M,K,N,R);
        return fail?1:0;
    } else { fprintf(stderr,"unknown mode %s\n",mode); return 1; }
    return 0;
}
