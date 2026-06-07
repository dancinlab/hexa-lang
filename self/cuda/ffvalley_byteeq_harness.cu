/* HEXA-FUSION FF-VALLEY — standalone byte-eq + timing harness.
 *
 * Self-contained CUDA test: on the SAME random device inputs, runs
 *   (A) the FF-VALLEY persistent fused glue kernels (valley1, valley2), and
 *   (B) the EAGER SEPARATE-kernel reference (the exact same ops, but each glue
 *       op launched as its own kernel — the closed-form byte-eq oracle).
 * Compares max|delta| bit-for-bit (FP64), then times both for a valley-Δ.
 *
 * The device math in this harness is COPY-IDENTICAL to the de-escaped device
 * code in self/cuda/runtime_cuda_emit.hexa (_hx_dev_groupnorm, _hx_gelu_dev,
 * _hx_moe_exp_dev, _hx_gn_sqrt_dev and the valley1/valley2 kernels). The eager
 * reference reproduces clm_prod's separate-kernel glue path (groupnorm G=1 +
 * gelu + residual; gelu2 + expert-pack + moe-router + groupnorm#2 G=1).
 *
 * Build: nvcc -O2 -arch=sm_90 ffvalley_byteeq_harness.cu -lcuda -o ffval_harness
 * Run:   ./ffval_harness [T] [D] [E] [iters]
 */
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cmath>
#include <cuda_runtime.h>
#include <cooperative_groups.h>
namespace cg = cooperative_groups;

#define CK(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA err %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e)); exit(1);} }while(0)

/* ── de-escaped device fns (byte-identical to runtime_cuda_emit.hexa) ── */
__device__ static double _hx_gn_sqrt_dev(double x){
  if(x<=0.0) return 0.0; double g=x;
  for(int i=0;i<40;i++){ g=0.5*(g+x/g);} return g;
}
__device__ static double _hx_gelu_dev(double x){
  const double inv_sqrt2=0.70710678118654752440;
  double cdf=0.5*(1.0+erf(x*inv_sqrt2)); return x*cdf;
}
/* scaled-Taylor exp byte-identical to moe_lib (_hx_moe_exp_dev). */
__device__ static double _hx_moe_exp_dev(double x){
  /* exp via range-reduction: x = k*ln2 + r, exp = 2^k * exp(r), exp(r) Taylor. */
  const double ln2=0.69314718055994530942;
  const double inv_ln2=1.44269504088896340736;
  double kf=floor(x*inv_ln2+0.5);
  double r=x-kf*ln2;
  double term=1.0,sum=1.0;
  for(int i=1;i<18;i++){ term*=r/(double)i; sum+=term; }
  int k=(int)kf;
  double p=1.0; double base=(k>=0)?2.0:0.5; int ak=(k>=0)?k:-k;
  for(int i=0;i<ak;i++) p*=base;
  return sum*p;
}
__device__ void _hx_dev_groupnorm(cg::grid_group& g,
    const double* __restrict__ Xr,const double* __restrict__ G,
    const double* __restrict__ Bn,double* __restrict__ HN,
    double* __restrict__ MEAN,double* __restrict__ INV,
    double* __restrict__ XHAT,int64_t T,int64_t D){
  double eps=1e-5; int64_t N=T*D; double m=(double)N;
  if(blockIdx.x==0&&threadIdx.x==0){
    double sum=0.0;
    for(int64_t t=0;t<T;t++)for(int64_t c=0;c<D;c++) sum+=Xr[t*D+c];
    double mu=sum/m; double vs=0.0;
    for(int64_t t=0;t<T;t++)for(int64_t c=0;c<D;c++){ double d=Xr[t*D+c]-mu; vs+=d*d; }
    double var=vs/m; double inv=1.0/_hx_gn_sqrt_dev(var+eps);
    MEAN[0]=mu; INV[0]=inv;
  }
  g.sync();
  double mu=MEAN[0],inv=INV[0];
  int64_t stride=(int64_t)gridDim.x*blockDim.x;
  for(int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;i<N;i+=stride){
    int64_t c=i%D; double xh=(Xr[i]-mu)*inv; XHAT[i]=xh; HN[i]=G[c]*xh+Bn[c];
  }
}

/* ── FF-VALLEY fused kernels (copy of emit) ── */
struct VABufs{ const double *XEC,*tgG,*tgB; double *H0,*HN0,*MEAN0,*INV0,*XHAT0,*HG0,*XT; };
__global__ void valley1(VABufs b,int64_t T,int64_t D){
  cg::grid_group grid=cg::this_grid(); int64_t n=T*D;
  _hx_dev_groupnorm(grid,b.H0,b.tgG,b.tgB,b.HN0,b.MEAN0,b.INV0,b.XHAT0,T,D);
  grid.sync();
  { int64_t st=(int64_t)gridDim.x*blockDim.x;
    for(int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;i<n;i+=st){
      double hg=_hx_gelu_dev(b.HN0[i]); b.HG0[i]=hg; b.XT[i]=b.XEC[i]+hg; } }
}
struct VBBufs{ const double *EO0,*EO1,*LOGR,*noG,*noB;
  double *EX0,*EX1,*EXOUT,*PROBS,*Y,*YN,*MEANN,*INVN,*XHATN; };
__global__ void valley2(VBBufs b,int64_t T,int64_t D,int64_t E){
  cg::grid_group grid=cg::this_grid(); int64_t n=T*D;
  { int64_t st=(int64_t)gridDim.x*blockDim.x;
    for(int64_t t=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;t<T;t+=st){
      for(int64_t c=0;c<D;c++){ int64_t j=t*D+c;
        double g0=_hx_gelu_dev(b.EO0[j]); b.EX0[j]=g0; b.EXOUT[j]=g0;
        double g1=_hx_gelu_dev(b.EO1[j]); b.EX1[j]=g1; b.EXOUT[n+j]=g1; }
      int64_t base=t*E; double mx=b.LOGR[base];
      for(int64_t e=1;e<E;e++){ double vv=b.LOGR[base+e]; if(vv>mx)mx=vv; }
      double s=0.0;
      for(int64_t e=0;e<E;e++){ double ev=_hx_moe_exp_dev(b.LOGR[base+e]-mx); b.PROBS[base+e]=ev; s+=ev; }
      for(int64_t e=0;e<E;e++) b.PROBS[base+e]/=s;
      for(int64_t c=0;c<D;c++){ double acc=0.0;
        for(int64_t e=0;e<E;e++) acc+=b.PROBS[base+e]*b.EXOUT[e*n+t*D+c];
        b.Y[t*D+c]=acc; } } }
  grid.sync();
  _hx_dev_groupnorm(grid,b.Y,b.noG,b.noB,b.YN,b.MEANN,b.INVN,b.XHATN,T,D);
}

/* ── EAGER SEPARATE-kernel reference (each glue op = its own launch) ── */
/* groupnorm G=1, single-thread whole-tensor reduce (= _hx_k_groupnorm with G=1). */
__global__ void ref_groupnorm_g1(const double* __restrict__ X,const double* __restrict__ GA,
    const double* __restrict__ BE,double* __restrict__ Y,double* __restrict__ MEAN,
    double* __restrict__ INV,double* __restrict__ XHAT,int64_t T,int64_t D){
  const double eps=0.00001; int64_t C=D; int64_t cg=C; double m=(double)(cg*T);
  /* G=1 -> exactly one group, thread 0 does the host-order reduction. */
  if(blockIdx.x==0&&threadIdx.x==0){
    double sum=0.0;
    for(int64_t t=0;t<T;t++)for(int64_t c=0;c<cg;c++) sum+=X[t*C+c];
    double mu=sum/m; double vs=0.0;
    for(int64_t t=0;t<T;t++)for(int64_t c=0;c<cg;c++){ double d=X[t*C+c]-mu; vs+=d*d; }
    double var=vs/m; double inv=1.0/_hx_gn_sqrt_dev(var+eps);
    MEAN[0]=mu; INV[0]=inv;
    for(int64_t t=0;t<T;t++)for(int64_t c=0;c<cg;c++){
      int64_t ch=c; double xh=(X[t*C+ch]-mu)*inv; XHAT[t*C+ch]=xh; Y[t*C+ch]=GA[ch]*xh+BE[ch]; }
  }
}
__global__ void ref_gelu(const double* __restrict__ IN,double* __restrict__ OUT,int64_t n){
  for(int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;i<n;i+=(int64_t)gridDim.x*blockDim.x)
    OUT[i]=_hx_gelu_dev(IN[i]);
}
__global__ void ref_residual(const double* __restrict__ A,const double* __restrict__ B,
    double* __restrict__ O,int64_t n){
  for(int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;i<n;i+=(int64_t)gridDim.x*blockDim.x)
    O[i]=A[i]+B[i];
}
/* moe block-2: gelu2 (2 experts) + pack + softmax-router + combine. */
__global__ void ref_moe_block2(const double* __restrict__ EO0,const double* __restrict__ EO1,
    const double* __restrict__ LOGR,double* __restrict__ EX0,double* __restrict__ EX1,
    double* __restrict__ EXOUT,double* __restrict__ PROBS,double* __restrict__ Y,
    int64_t T,int64_t D,int64_t E){
  int64_t n=T*D; int64_t st=(int64_t)gridDim.x*blockDim.x;
  for(int64_t t=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;t<T;t+=st){
    for(int64_t c=0;c<D;c++){ int64_t j=t*D+c;
      double g0=_hx_gelu_dev(EO0[j]); EX0[j]=g0; EXOUT[j]=g0;
      double g1=_hx_gelu_dev(EO1[j]); EX1[j]=g1; EXOUT[n+j]=g1; }
    int64_t base=t*E; double mx=LOGR[base];
    for(int64_t e=1;e<E;e++){ double vv=LOGR[base+e]; if(vv>mx)mx=vv; }
    double s=0.0;
    for(int64_t e=0;e<E;e++){ double ev=_hx_moe_exp_dev(LOGR[base+e]-mx); PROBS[base+e]=ev; s+=ev; }
    for(int64_t e=0;e<E;e++) PROBS[base+e]/=s;
    for(int64_t c=0;c<D;c++){ double acc=0.0;
      for(int64_t e=0;e<E;e++) acc+=PROBS[base+e]*EXOUT[e*n+t*D+c];
      Y[t*D+c]=acc; } }
}

static double* dalloc(int64_t n){ double* p=nullptr; CK(cudaMalloc(&p,(size_t)n*sizeof(double))); return p; }
static void fill_rand(double* d,int64_t n,unsigned seed){
  double* h=(double*)malloc((size_t)n*sizeof(double)); srand(seed);
  for(int64_t i=0;i<n;i++) h[i]=((double)rand()/RAND_MAX-0.5)*2.0;
  CK(cudaMemcpy(d,h,(size_t)n*sizeof(double),cudaMemcpyHostToDevice)); free(h);
}
static double maxabsdiff(const double* a,const double* b,int64_t n){
  double* ha=(double*)malloc((size_t)n*sizeof(double));
  double* hb=(double*)malloc((size_t)n*sizeof(double));
  CK(cudaMemcpy(ha,a,(size_t)n*sizeof(double),cudaMemcpyDeviceToHost));
  CK(cudaMemcpy(hb,b,(size_t)n*sizeof(double),cudaMemcpyDeviceToHost));
  double mx=0.0; for(int64_t i=0;i<n;i++){ double d=fabs(ha[i]-hb[i]); if(d>mx)mx=d; }
  free(ha); free(hb); return mx;
}

int main(int argc,char**argv){
  int64_t T=(argc>1)?atoll(argv[1]):128;
  int64_t D=(argc>2)?atoll(argv[2]):512;
  int64_t E=(argc>3)?atoll(argv[3]):2;
  int iters=(argc>4)?atoi(argv[4]):200;
  int64_t n=T*D;
  int dev=0; CK(cudaGetDevice(&dev));
  int coop=0; CK(cudaDeviceGetAttribute(&coop,cudaDevAttrCooperativeLaunch,dev));
  int numSm=0; CK(cudaDeviceGetAttribute(&numSm,cudaDevAttrMultiProcessorCount,dev));
  cudaDeviceProp prop; CK(cudaGetDeviceProperties(&prop,dev));
  printf("# FF-VALLEY harness  dev=%s SMs=%d coop=%d  T=%ld D=%ld E=%ld iters=%d\n",
         prop.name,numSm,coop,(long)T,(long)D,(long)E,iters);
  if(!coop){ printf("RESULT no-coop -> kernels fall back; cannot run coop gate here\n"); return 2; }

  /* shared inputs */
  double *H0=dalloc(n),*XEC=dalloc(n),*tgG=dalloc(D),*tgB=dalloc(D);
  double *EO0=dalloc(n),*EO1=dalloc(n),*LOGR=dalloc(T*E),*noG=dalloc(D),*noB=dalloc(D);
  fill_rand(H0,n,1); fill_rand(XEC,n,2); fill_rand(tgG,D,3); fill_rand(tgB,D,4);
  fill_rand(EO0,n,5); fill_rand(EO1,n,6); fill_rand(LOGR,T*E,7); fill_rand(noG,D,8); fill_rand(noB,D,9);

  /* fused outputs */
  double *fHN0=dalloc(n),*fMEAN0=dalloc(1),*fINV0=dalloc(1),*fXHAT0=dalloc(n),*fHG0=dalloc(n),*fXT=dalloc(n);
  double *fEX0=dalloc(n),*fEX1=dalloc(n),*fEXOUT=dalloc(2*n),*fPROBS=dalloc(T*E),*fY=dalloc(n);
  double *fYN=dalloc(n),*fMEANN=dalloc(T),*fINVN=dalloc(T),*fXHATN=dalloc(n);
  /* reference outputs */
  double *rHN0=dalloc(n),*rMEAN0=dalloc(1),*rINV0=dalloc(1),*rXHAT0=dalloc(n),*rHG0=dalloc(n),*rXT=dalloc(n);
  double *rEX0=dalloc(n),*rEX1=dalloc(n),*rEXOUT=dalloc(2*n),*rPROBS=dalloc(T*E),*rY=dalloc(n);
  double *rYN=dalloc(n),*rMEANN=dalloc(T),*rINVN=dalloc(T),*rXHATN=dalloc(n);

  int blk=128;
  int bpsm1=0; CK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(&bpsm1,(void*)valley1,blk,0)); if(bpsm1<1)bpsm1=1;
  int bpsm2=0; CK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(&bpsm2,(void*)valley2,blk,0)); if(bpsm2<1)bpsm2=1;
  int g1=numSm*bpsm1, g2=numSm*bpsm2;

  /* ── A: fused valley1+valley2 ── */
  VABufs va{XEC,tgG,tgB,H0,fHN0,fMEAN0,fINV0,fXHAT0,fHG0,fXT};
  { void* args[]={(void*)&va,(void*)&T,(void*)&D}; dim3 gd(g1),bd(blk);
    CK(cudaLaunchCooperativeKernel((void*)valley1,gd,bd,args,0,0)); }
  VBBufs vb{EO0,EO1,LOGR,noG,noB,fEX0,fEX1,fEXOUT,fPROBS,fY,fYN,fMEANN,fINVN,fXHATN};
  { void* args[]={(void*)&vb,(void*)&T,(void*)&D,(void*)&E}; dim3 gd(g2),bd(blk);
    CK(cudaLaunchCooperativeKernel((void*)valley2,gd,bd,args,0,0)); }
  CK(cudaDeviceSynchronize());

  /* ── B: eager separate-kernel reference ── */
  int eb=(int)((n+blk-1)/blk); if(eb<1)eb=1; if(eb>65535)eb=65535;
  int tb=(int)((T+blk-1)/blk); if(tb<1)tb=1;
  ref_groupnorm_g1<<<1,1>>>(H0,tgG,tgB,rHN0,rMEAN0,rINV0,rXHAT0,T,D);
  /* gelu(hn0) -> rHG0 ; residual xt = xec + rHG0 */
  ref_gelu<<<eb,blk>>>(rHN0,rHG0,n);
  ref_residual<<<eb,blk>>>(XEC,rHG0,rXT,n);
  ref_moe_block2<<<tb,blk>>>(EO0,EO1,LOGR,rEX0,rEX1,rEXOUT,rPROBS,rY,T,D,E);
  ref_groupnorm_g1<<<1,1>>>(rY,noG,noB,rYN,rMEANN,rINVN,rXHATN,T,D);
  CK(cudaDeviceSynchronize());

  /* ── byte-eq compare (all valley outputs) ── */
  double dmax=0.0, dd;
  dd=maxabsdiff(fHN0,rHN0,n);  if(dd>dmax)dmax=dd; printf("  hn0   max|d|=%.3e\n",dd);
  dd=maxabsdiff(fHG0,rHG0,n);  if(dd>dmax)dmax=dd; printf("  hg0   max|d|=%.3e\n",dd);
  dd=maxabsdiff(fXT,rXT,n);    if(dd>dmax)dmax=dd; printf("  xt    max|d|=%.3e\n",dd);
  dd=maxabsdiff(fXHAT0,rXHAT0,n);if(dd>dmax)dmax=dd;printf("  xhat0 max|d|=%.3e\n",dd);
  dd=maxabsdiff(fEXOUT,rEXOUT,2*n);if(dd>dmax)dmax=dd;printf("  exout max|d|=%.3e\n",dd);
  dd=maxabsdiff(fPROBS,rPROBS,T*E);if(dd>dmax)dmax=dd;printf("  probs max|d|=%.3e\n",dd);
  dd=maxabsdiff(fY,rY,n);      if(dd>dmax)dmax=dd; printf("  y     max|d|=%.3e\n",dd);
  dd=maxabsdiff(fYN,rYN,n);    if(dd>dmax)dmax=dd; printf("  yn    max|d|=%.3e\n",dd);
  dd=maxabsdiff(fXHATN,rXHATN,n);if(dd>dmax)dmax=dd;printf("  xhatN max|d|=%.3e\n",dd);
  printf("BYTEEQ max|delta|=%.6e  %s\n",dmax,(dmax==0.0)?"PASS(max|d|=0)":"FAIL");

  /* ── timing: valley fused (A) vs eager separate (B) — the valley-time ── */
  cudaEvent_t s,e; CK(cudaEventCreate(&s)); CK(cudaEventCreate(&e));
  /* warmup */
  for(int w=0;w<10;w++){
    void* a1[]={(void*)&va,(void*)&T,(void*)&D}; dim3 gd1(g1),bd(blk);
    CK(cudaLaunchCooperativeKernel((void*)valley1,gd1,bd,a1,0,0));
    void* a2[]={(void*)&vb,(void*)&T,(void*)&D,(void*)&E}; dim3 gd2(g2);
    CK(cudaLaunchCooperativeKernel((void*)valley2,gd2,bd,a2,0,0));
  } CK(cudaDeviceSynchronize());
  CK(cudaEventRecord(s));
  for(int it=0;it<iters;it++){
    void* a1[]={(void*)&va,(void*)&T,(void*)&D}; dim3 gd1(g1),bd(blk);
    CK(cudaLaunchCooperativeKernel((void*)valley1,gd1,bd,a1,0,0));
    void* a2[]={(void*)&vb,(void*)&T,(void*)&D,(void*)&E}; dim3 gd2(g2);
    CK(cudaLaunchCooperativeKernel((void*)valley2,gd2,bd,a2,0,0));
  }
  CK(cudaEventRecord(e)); CK(cudaEventSynchronize(e));
  float ms_fused=0; CK(cudaEventElapsedTime(&ms_fused,s,e));

  for(int w=0;w<10;w++){
    ref_groupnorm_g1<<<1,1>>>(H0,tgG,tgB,rHN0,rMEAN0,rINV0,rXHAT0,T,D);
    ref_gelu<<<eb,blk>>>(rHN0,rHG0,n); ref_residual<<<eb,blk>>>(XEC,rHG0,rXT,n);
    ref_moe_block2<<<tb,blk>>>(EO0,EO1,LOGR,rEX0,rEX1,rEXOUT,rPROBS,rY,T,D,E);
    ref_groupnorm_g1<<<1,1>>>(rY,noG,noB,rYN,rMEANN,rINVN,rXHATN,T,D);
  } CK(cudaDeviceSynchronize());
  CK(cudaEventRecord(s));
  for(int it=0;it<iters;it++){
    ref_groupnorm_g1<<<1,1>>>(H0,tgG,tgB,rHN0,rMEAN0,rINV0,rXHAT0,T,D);
    ref_gelu<<<eb,blk>>>(rHN0,rHG0,n); ref_residual<<<eb,blk>>>(XEC,rHG0,rXT,n);
    ref_moe_block2<<<tb,blk>>>(EO0,EO1,LOGR,rEX0,rEX1,rEXOUT,rPROBS,rY,T,D,E);
    ref_groupnorm_g1<<<1,1>>>(rY,noG,noB,rYN,rMEANN,rINVN,rXHATN,T,D);
  }
  CK(cudaEventRecord(e)); CK(cudaEventSynchronize(e));
  float ms_ref=0; CK(cudaEventElapsedTime(&ms_ref,s,e));

  printf("VALLEY-TIME  fused=%.4f ms/iter  separate=%.4f ms/iter  speedup=%.3fx\n",
         ms_fused/iters, ms_ref/iters, ms_ref/ms_fused);
  printf("# NOTE: this is the VALLEY-GLUE time only (GEMMs excluded by design — they\n");
  printf("#       stay separate saturated launches). The step-level lever is bounded\n");
  printf("#       by the valley fraction (FF-DUTYCYCLE Amdahl ceiling).\n");
  return (dmax==0.0)?0:1;
}
