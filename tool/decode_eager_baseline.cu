/* F-FUSION-AUTOREGRESSIVE-COMPLETE -- FAIR eager 17-launch decode baseline.
 *
 * One GPT-2-small transformer layer, single-token autoregressive DECODE
 * (batch=1, one q-vector) at KV-cache length L. This is the 17-per-op-kernel
 * path PyTorch/vLLM eager issues. Each sub-kernel is PROPERLY PARALLELIZED
 * (coalesced HBM, warp-cooperative reductions) -- NOT a strawman.
 *
 * Shape: d=768, n_heads=12, head_dim=64, FFN inner = 4*d = 3072.
 *
 * The 17 launches per layer:
 *   k1  rmsnorm1        x -> xn1            (RMSNorm, d=768)
 *   k2  gemv  Q = Wq . xn1                  (768x768)
 *   k3  gemv  K = Wk . xn1                  (768x768)
 *   k4  gemv  V = Wv . xn1                  (768x768)
 *   k5  kv_append_k     K -> Kcache[L]      (write one row)
 *   k6  kv_append_v     V -> Vcache[L]      (write one row)
 *   k7  qk_scores       s[t]=Q.Kcache[t]/sqrt(hd)  over L+1 keys, 12 heads
 *   k8  softmax_rows    s = softmax(s)      (per head, length L+1)
 *   k9  attn_av         a = sum_t s[t]*Vcache[t]    (12 heads x 64)
 *   k10 gemv  O = Wo . a                    (768x768)
 *   k11 residual1       x = x + O
 *   k12 rmsnorm2        x -> xn2
 *   k13 gemv  G = Wg . xn2                  (3072x768) gate
 *   k14 gemv  U = Wu . xn2                  (3072x768) up
 *   k15 swiglu          h = silu(G) * U     (3072)
 *   k16 gemv  D = Wd . h                    (768x3072) down
 *   k17 residual2       x = x + D
 *
 * FP32. cudaEvent timing: 20 warmup + 200 timed median. Also a per-sub-kernel
 * fairness pass that times each of the 17 kernels individually so we can flag
 * any accidentally-naive sub-kernel (R11 lesson).
 *
 * Build:  nvcc -O2 -o decode_eager_baseline decode_eager_baseline.cu -lcudart
 * Run:    ./decode_eager_baseline [L]
 */
#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define D     768
#define NH    12
#define HD    64
#define FF    3072
#define MAXL  1025

#define CK(call) do { cudaError_t e=(call); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA err %s at %s:%d\n",cudaGetErrorString(e),__FILE__,__LINE__); exit(1);}}while(0)

static int cmp_double(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return (x<y)?-1:(x>y)?1:0;}
static uint32_t lcg=0x12345678u;
static float lcg_f32(void){lcg=lcg*1664525u+1013904223u;return ((float)(lcg>>8)/(float)(1u<<24))-0.5f;}

/* ---- coalesced/parallel sub-kernels ----------------------------------- */

/* RMSNorm: 1 CTA (256 thr), warp-cooperative sum of squares over d=768.
   Coalesced read of x. weight g applied. */
__global__ void k_rmsnorm(const float* x,const float* g,float* out,int n){
  __shared__ float red[256];
  int t=threadIdx.x;
  float acc=0.f;
  for(int i=t;i<n;i+=blockDim.x){float v=x[i]; acc+=v*v;}
  red[t]=acc; __syncthreads();
  for(int s=blockDim.x/2;s>0;s>>=1){ if(t<s) red[t]+=red[t+s]; __syncthreads(); }
  float inv = rsqrtf(red[0]/(float)n + 1e-5f);
  for(int i=t;i<n;i+=blockDim.x) out[i]=x[i]*inv*g[i];
}

/* GEMV  y[r] = sum_c W[r*K + c] * x[c].  One warp per output row (warp-coop
   dot, coalesced over c). gridDim.x* (blockDim.x/32) warps cover R rows. */
__global__ void k_gemv(const float* W,const float* x,float* y,int R,int K){
  int warp = (blockIdx.x*blockDim.x + threadIdx.x)>>5;
  int lane = threadIdx.x & 31;
  if(warp>=R) return;
  const float* w = W + (size_t)warp*K;
  float acc=0.f;
  for(int c=lane;c<K;c+=32) acc += w[c]*x[c];
  for(int o=16;o>0;o>>=1) acc += __shfl_down_sync(0xffffffffu,acc,o);
  if(lane==0) y[warp]=acc;
}

/* GEMV with bias-add of an accumulator vector (residual fold) -- not used in
   the strict 17 but kept generic. */

/* KV append: write src (len HD per head, total d for K/V) into cache row L. */
__global__ void k_kv_append(const float* src,float* cache,int L,int rowlen){
  int i=blockIdx.x*blockDim.x+threadIdx.x;
  if(i<rowlen) cache[(size_t)L*rowlen + i]=src[i];
}

/* QK scores: per head h, per key-position t in [0,L], score = (Q_h . Kcache_h[t])*scale.
   grid = (L+1) blocks-ish; here one warp per (head,key) coop dot over HD=64. */
__global__ void k_qk_scores(const float* Q,const float* Kc,float* S,int Lp1,float scale){
  // total (head,key) pairs = NH*Lp1 ; one warp each
  int pair=(blockIdx.x*blockDim.x+threadIdx.x)>>5;
  int lane=threadIdx.x&31;
  if(pair>=NH*Lp1) return;
  int h=pair/Lp1, t=pair%Lp1;
  const float* q=Q + h*HD;
  const float* k=Kc + (size_t)t*D + h*HD;   // cache rowlen=D, head slice
  float acc=0.f;
  for(int c=lane;c<HD;c+=32) acc += q[c]*k[c];
  for(int o=16;o>0;o>>=1) acc += __shfl_down_sync(0xffffffffu,acc,o);
  if(lane==0) S[h*Lp1 + t]=acc*scale;
}

/* softmax per head over length Lp1: one CTA per head (256 thr), warp-coop. */
__global__ void k_softmax(float* S,int Lp1){
  __shared__ float red[256];
  int h=blockIdx.x, t=threadIdx.x;
  float* s=S + (size_t)h*Lp1;
  float m=-3.4e38f;
  for(int j=t;j<Lp1;j+=blockDim.x) if(s[j]>m) m=s[j];
  red[t]=m; __syncthreads();
  for(int st=blockDim.x/2;st>0;st>>=1){ if(t<st && red[t+st]>red[t]) red[t]=red[t+st]; __syncthreads(); }
  m=red[0]; __syncthreads();
  float l=0.f;
  for(int j=t;j<Lp1;j+=blockDim.x){ float e=__expf(s[j]-m); s[j]=e; l+=e; }
  red[t]=l; __syncthreads();
  for(int st=blockDim.x/2;st>0;st>>=1){ if(t<st) red[t]+=red[t+st]; __syncthreads(); }
  float inv=1.f/red[0];
  for(int j=t;j<Lp1;j+=blockDim.x) s[j]*=inv;
}

/* attn-weighted V: out[h*HD + c] = sum_t S[h,t]*Vcache[t, h*HD + c].
   FAIR PARALLEL version (R11 lesson): split the L keys across KB blocks per
   head so attention is parallelized over the key dimension, NOT one-thread-
   serial-over-L. grid.x = NH*KB. Each block accumulates a partial over its
   key-stripe into a global atomic-add output (out pre-zeroed). HD=64 threads. */
__global__ void k_attn_av(const float* S,const float* Vc,float* out,int Lp1,int KB){
  int blk=blockIdx.x; int h=blk/KB; int kb=blk%KB;
  int c=threadIdx.x; if(c>=HD || h>=NH) return;
  const float* s=S + (size_t)h*Lp1;
  float acc=0.f;
  for(int t=kb;t<Lp1;t+=KB) acc += s[t]*Vc[(size_t)t*D + h*HD + c];
  atomicAdd(&out[h*HD + c], acc);
}
__global__ void k_zero(float* p,int n){ int i=blockIdx.x*blockDim.x+threadIdx.x; if(i<n) p[i]=0.f; }

/* residual add: x += y (len n), coalesced. */
__global__ void k_residual(float* x,const float* y,int n){
  int i=blockIdx.x*blockDim.x+threadIdx.x;
  if(i<n) x[i]+=y[i];
}

/* SwiGLU: h = silu(G)*U over FF, coalesced. silu(z)=z*sigmoid(z). */
__global__ void k_swiglu(const float* G,const float* U,float* h,int n){
  int i=blockIdx.x*blockDim.x+threadIdx.x;
  if(i<n){ float z=G[i]; float sg=1.f/(1.f+__expf(-z)); h[i]=z*sg*U[i]; }
}

/* ---- host -------------------------------------------------------------- */
static double medms(float* a,int n){qsort(a,n,sizeof(float),cmp_double);return a[n/2];}

/* f64 CPU autoregressive reference for ONE layer decode at cache-len L.
   Produces ref_out[D]. weights passed in. Kc/Vc hold L existing rows + we
   append the freshly-computed K,V at row L. */
static void cpu_ref(const float* x,const float* g1,const float* g2,
                    const float* Wq,const float* Wk,const float* Wv,const float* Wo,
                    const float* Wg,const float* Wu,const float* Wd,
                    const float* Kc,const float* Vc,int L,double* out){
  int Lp1=L+1;
  double xn1[D];
  double ss=0; for(int i=0;i<D;i++) ss+=(double)x[i]*x[i];
  double inv=1.0/sqrt(ss/D + 1e-5);
  for(int i=0;i<D;i++) xn1[i]=(double)x[i]*inv*(double)g1[i];
  double Q[D],K[D],V[D];
  for(int r=0;r<D;r++){double a=0,b=0,c=0;for(int k=0;k<D;k++){double xv=xn1[k];a+=(double)Wq[r*D+k]*xv;b+=(double)Wk[r*D+k]*xv;c+=(double)Wv[r*D+k]*xv;}Q[r]=a;K[r]=b;V[r]=c;}
  // build full K/V with appended row at L
  double* Kf=(double*)malloc((size_t)Lp1*D*sizeof(double));
  double* Vf=(double*)malloc((size_t)Lp1*D*sizeof(double));
  for(int t=0;t<L;t++)for(int i=0;i<D;i++){Kf[(size_t)t*D+i]=(double)Kc[(size_t)t*D+i];Vf[(size_t)t*D+i]=(double)Vc[(size_t)t*D+i];}
  for(int i=0;i<D;i++){Kf[(size_t)L*D+i]=K[i];Vf[(size_t)L*D+i]=V[i];}
  double scale=1.0/sqrt((double)HD);
  double attn[D];
  for(int h=0;h<NH;h++){
    double* s=(double*)malloc((size_t)Lp1*sizeof(double));
    double m=-1e300;
    for(int t=0;t<Lp1;t++){double dot=0;for(int c=0;c<HD;c++)dot+=Q[h*HD+c]*Kf[(size_t)t*D+h*HD+c];dot*=scale;s[t]=dot;if(dot>m)m=dot;}
    double l=0;for(int t=0;t<Lp1;t++){s[t]=exp(s[t]-m);l+=s[t];}
    for(int c=0;c<HD;c++){double acc=0;for(int t=0;t<Lp1;t++)acc+=s[t]*Vf[(size_t)t*D+h*HD+c];attn[h*HD+c]=acc/l;}
    free(s);
  }
  free(Kf);free(Vf);
  double O[D];
  for(int r=0;r<D;r++){double a=0;for(int k=0;k<D;k++)a+=(double)Wo[r*D+k]*attn[k];O[r]=a;}
  double xr[D]; for(int i=0;i<D;i++) xr[i]=(double)x[i]+O[i];
  // FFN
  double xn2[D]; ss=0; for(int i=0;i<D;i++) ss+=xr[i]*xr[i];
  inv=1.0/sqrt(ss/D + 1e-5);
  for(int i=0;i<D;i++) xn2[i]=xr[i]*inv*(double)g2[i];
  double* hh=(double*)malloc((size_t)FF*sizeof(double));
  for(int r=0;r<FF;r++){double gg=0,uu=0;for(int k=0;k<D;k++){double xv=xn2[k];gg+=(double)Wg[r*D+k]*xv;uu+=(double)Wu[r*D+k]*xv;}double sg=1.0/(1.0+exp(-gg));hh[r]=gg*sg*uu;}
  for(int r=0;r<D;r++){double a=0;for(int k=0;k<FF;k++)a+=(double)Wd[r*FF+k]*hh[k];out[r]=xr[r]+a;}
  free(hh);
}

int main(int argc,char**argv){
  int L=(argc>1)?atoi(argv[1]):256;
  int Lp1=L+1;
  // host weights
  size_t szD=(size_t)D*sizeof(float);
  float *x=(float*)malloc(szD),*g1=(float*)malloc(szD),*g2=(float*)malloc(szD);
  float *Wq=(float*)malloc((size_t)D*D*sizeof(float)),*Wk=(float*)malloc((size_t)D*D*sizeof(float));
  float *Wv=(float*)malloc((size_t)D*D*sizeof(float)),*Wo=(float*)malloc((size_t)D*D*sizeof(float));
  float *Wg=(float*)malloc((size_t)FF*D*sizeof(float)),*Wu=(float*)malloc((size_t)FF*D*sizeof(float));
  float *Wd=(float*)malloc((size_t)D*FF*sizeof(float));
  float *Kc=(float*)malloc((size_t)L*D*sizeof(float)),*Vc=(float*)malloc((size_t)L*D*sizeof(float));
  // small-magnitude weights ~ 1/sqrt(fanin) so activations stay O(1)
  float wq=0.036f; // ~1/sqrt(768)
  float wf=0.057f; // ~1/sqrt(307? ) keep modest for down-proj fanin 3072 -> 0.018; use per-matrix
  for(int i=0;i<D;i++){x[i]=lcg_f32();g1[i]=1.f+0.1f*lcg_f32();g2[i]=1.f+0.1f*lcg_f32();}
  for(int i=0;i<D*D;i++){Wq[i]=lcg_f32()*wq;Wk[i]=lcg_f32()*wq;Wv[i]=lcg_f32()*wq;Wo[i]=lcg_f32()*wq;}
  for(int i=0;i<FF*D;i++){Wg[i]=lcg_f32()*wq;Wu[i]=lcg_f32()*wq;}
  for(int i=0;i<D*FF;i++) Wd[i]=lcg_f32()*0.018f; // 1/sqrt(3072)
  for(int i=0;i<L*D;i++){Kc[i]=lcg_f32()*wq*0.5f;Vc[i]=lcg_f32();}
  (void)wf;

  double ref[D]; cpu_ref(x,g1,g2,Wq,Wk,Wv,Wo,Wg,Wu,Wd,Kc,Vc,L,ref);

  // device
  float *dx,*dg1,*dg2,*dWq,*dWk,*dWv,*dWo,*dWg,*dWu,*dWd,*dKc,*dVc;
  float *dxn1,*dQ,*dK,*dV,*dS,*dattn,*dO,*dxn2,*dG,*dU,*dh,*dDn;
  CK(cudaMalloc(&dx,szD));CK(cudaMalloc(&dg1,szD));CK(cudaMalloc(&dg2,szD));
  CK(cudaMalloc(&dWq,(size_t)D*D*4));CK(cudaMalloc(&dWk,(size_t)D*D*4));
  CK(cudaMalloc(&dWv,(size_t)D*D*4));CK(cudaMalloc(&dWo,(size_t)D*D*4));
  CK(cudaMalloc(&dWg,(size_t)FF*D*4));CK(cudaMalloc(&dWu,(size_t)FF*D*4));
  CK(cudaMalloc(&dWd,(size_t)D*FF*4));
  CK(cudaMalloc(&dKc,(size_t)Lp1*D*4));CK(cudaMalloc(&dVc,(size_t)Lp1*D*4));
  CK(cudaMalloc(&dxn1,szD));CK(cudaMalloc(&dQ,szD));CK(cudaMalloc(&dK,szD));CK(cudaMalloc(&dV,szD));
  CK(cudaMalloc(&dS,(size_t)NH*Lp1*4));CK(cudaMalloc(&dattn,szD));CK(cudaMalloc(&dO,szD));
  CK(cudaMalloc(&dxn2,szD));CK(cudaMalloc(&dG,(size_t)FF*4));CK(cudaMalloc(&dU,(size_t)FF*4));
  CK(cudaMalloc(&dh,(size_t)FF*4));CK(cudaMalloc(&dDn,szD));
  CK(cudaMemcpy(dg1,g1,szD,cudaMemcpyHostToDevice));CK(cudaMemcpy(dg2,g2,szD,cudaMemcpyHostToDevice));
  CK(cudaMemcpy(dWq,Wq,(size_t)D*D*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dWk,Wk,(size_t)D*D*4,cudaMemcpyHostToDevice));
  CK(cudaMemcpy(dWv,Wv,(size_t)D*D*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dWo,Wo,(size_t)D*D*4,cudaMemcpyHostToDevice));
  CK(cudaMemcpy(dWg,Wg,(size_t)FF*D*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dWu,Wu,(size_t)FF*D*4,cudaMemcpyHostToDevice));
  CK(cudaMemcpy(dWd,Wd,(size_t)D*FF*4,cudaMemcpyHostToDevice));
  CK(cudaMemcpy(dKc,Kc,(size_t)L*D*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dVc,Vc,(size_t)L*D*4,cudaMemcpyHostToDevice));

  float scale=1.f/sqrtf((float)HD);
  // launch config helpers
  int warps_per_blk=8, thr=warps_per_blk*32;          // 256
  int blks_gemvD=(D + warps_per_blk-1)/warps_per_blk; // rows D, one warp/row
  int blks_gemvFF=(FF + warps_per_blk-1)/warps_per_blk;
  int qk_pairs=NH*Lp1; int blks_qk=(qk_pairs + warps_per_blk-1)/warps_per_blk;
  /* KB = key-split blocks per head for FAIR parallel attn_av (cap so total
     blocks subscribe the SMs). aim ~ Lp1/8 keys per block, bounded [1,64]. */
  int KB=(Lp1+7)/8; if(KB<1)KB=1; if(KB>64)KB=64;

  // one full layer pass (used both for warmup, timing, and numeric capture)
  #define LAYER() do{ \
    CK(cudaMemcpy(dx,x,szD,cudaMemcpyHostToDevice)); \
    k_rmsnorm<<<1,256>>>(dx,dg1,dxn1,D); \
    k_gemv<<<blks_gemvD,thr>>>(dWq,dxn1,dQ,D,D); \
    k_gemv<<<blks_gemvD,thr>>>(dWk,dxn1,dK,D,D); \
    k_gemv<<<blks_gemvD,thr>>>(dWv,dxn1,dV,D,D); \
    k_kv_append<<<(D+255)/256,256>>>(dK,dKc,L,D); \
    k_kv_append<<<(D+255)/256,256>>>(dV,dVc,L,D); \
    k_qk_scores<<<blks_qk,thr>>>(dQ,dKc,dS,Lp1,scale); \
    k_softmax<<<NH,256>>>(dS,Lp1); \
    k_zero<<<(D+255)/256,256>>>(dattn,D); \
    k_attn_av<<<NH*KB,HD>>>(dS,dVc,dattn,Lp1,KB); \
    k_gemv<<<blks_gemvD,thr>>>(dWo,dattn,dO,D,D); \
    k_residual<<<(D+255)/256,256>>>(dx,dO,D); \
    k_rmsnorm<<<1,256>>>(dx,dg2,dxn2,D); \
    k_gemv<<<blks_gemvFF,thr>>>(dWg,dxn2,dG,FF,D); \
    k_gemv<<<blks_gemvFF,thr>>>(dWu,dxn2,dU,FF,D); \
    k_swiglu<<<(FF+255)/256,256>>>(dG,dU,dh,FF); \
    k_gemv<<<blks_gemvD,thr>>>(dWd,dh,dDn,D,FF); \
    k_residual<<<(D+255)/256,256>>>(dx,dDn,D); \
  }while(0)

  // numeric capture (single pass, no cache contamination since dKc fresh each LAYER)
  LAYER(); CK(cudaDeviceSynchronize());
  float gpu[D]; CK(cudaMemcpy(gpu,dx,szD,cudaMemcpyDeviceToHost));
  double maxrel=0; int nan_inf=0;
  for(int i=0;i<D;i++){ double r=ref[i],g=gpu[i];
    if(!isfinite(g)){nan_inf++;continue;}
    double den=fabs(r); if(den<1e-6) den=1e-6; double rel=fabs(g-r)/den; if(rel>maxrel)maxrel=rel; }

  // timing: 20 warmup + 200 timed median
  cudaEvent_t a,b; CK(cudaEventCreate(&a));CK(cudaEventCreate(&b));
  for(int i=0;i<20;i++){LAYER();} CK(cudaDeviceSynchronize());
  float* tms=(float*)malloc(200*sizeof(float));
  for(int i=0;i<200;i++){ CK(cudaEventRecord(a)); LAYER(); CK(cudaEventRecord(b)); CK(cudaEventSynchronize(b)); CK(cudaEventElapsedTime(&tms[i],a,b)); }
  double med=medms(tms,200);

  // per-sub-kernel fairness pass: time each kernel individually (median of 200)
  #define TIMEK(NAME,...) do{ for(int i=0;i<20;i++){__VA_ARGS__;} CK(cudaDeviceSynchronize()); \
    for(int i=0;i<200;i++){CK(cudaEventRecord(a));__VA_ARGS__;CK(cudaEventRecord(b));CK(cudaEventSynchronize(b));CK(cudaEventElapsedTime(&tms[i],a,b));} \
    fprintf(stderr,"  subk %-12s %.5f ms\n",NAME,medms(tms,200)); }while(0)
  fprintf(stderr,"PER-SUBKERNEL FAIRNESS (L=%d, median ms each):\n",L);
  TIMEK("rmsnorm",  k_rmsnorm<<<1,256>>>(dx,dg1,dxn1,D));
  TIMEK("gemv_DxD", k_gemv<<<blks_gemvD,thr>>>(dWq,dxn1,dQ,D,D));
  TIMEK("gemv_FFxD",k_gemv<<<blks_gemvFF,thr>>>(dWg,dxn2,dG,FF,D));
  TIMEK("gemv_DxFF",k_gemv<<<blks_gemvD,thr>>>(dWd,dh,dDn,D,FF));
  TIMEK("kv_append",k_kv_append<<<(D+255)/256,256>>>(dK,dKc,L,D));
  TIMEK("qk_scores",k_qk_scores<<<blks_qk,thr>>>(dQ,dKc,dS,Lp1,scale));
  TIMEK("softmax",  k_softmax<<<NH,256>>>(dS,Lp1));
  TIMEK("attn_av",  k_attn_av<<<NH*KB,HD>>>(dS,dVc,dattn,Lp1,KB));
  TIMEK("residual", k_residual<<<(D+255)/256,256>>>(dx,dO,D));
  TIMEK("swiglu",   k_swiglu<<<(FF+255)/256,256>>>(dG,dU,dh,FF));

  printf("{\"variant\":\"eager17\",\"L\":%d,\"layer_ms\":%.6f,\"max_rel\":%.6g,\"nan_inf\":%d}\n",L,med,maxrel,nan_inf);
  fprintf(stderr,"EAGER L=%d layer_ms=%.6f max_rel=%.3g nan_inf=%d\n",L,med,maxrel,nan_inf);
  return 0;
}
