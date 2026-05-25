/* F-FUSION-AUTOREGRESSIVE-COMPLETE -- fused 2-mega-kernel decode launcher.
 *
 * Loads decode_fused.ptx (decode_attn_fused + decode_ffn_fused) via the CUDA
 * driver API, runs ONE GPT-2-small layer decode at cache-len L in exactly 2
 * launches, checks numeric vs an f64 CPU autoregressive reference (identical
 * LCG-seeded inputs as decode_eager_baseline.cu), and times 20 warmup + 200
 * median with cudaEvent.
 *
 * Build: nvcc -O2 -o decode_fused_host decode_fused_kernels_HOSTONLY ...  -- no:
 *   we compile this with nvcc (uses cuda runtime + driver API):
 *   nvcc -O2 -o decode_fused_host decode_fused_host.cu -lcuda -lcudart
 * Run:   ./decode_fused_host decode_fused.ptx [L]
 */
#include <cuda.h>
#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define D    768
#define NH   12
#define HD   64
#define FF   3072

#define DR(call) do{ CUresult r=(call); if(r!=CUDA_SUCCESS){ const char*s; cuGetErrorString(r,&s); \
  fprintf(stderr,"CU err %s at %s:%d\n",s,__FILE__,__LINE__); exit(1);}}while(0)
#define CK(call) do{ cudaError_t e=(call); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA err %s at %s:%d\n",cudaGetErrorString(e),__FILE__,__LINE__); exit(1);}}while(0)

static int cmp_double(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return (x<y)?-1:(x>y)?1:0;}
static double medms(float*a,int n){qsort(a,n,sizeof(float),cmp_double);return a[n/2];}
static uint32_t lcg=0x12345678u;
static float lcg_f32(void){lcg=lcg*1664525u+1013904223u;return ((float)(lcg>>8)/(float)(1u<<24))-0.5f;}

/* f64 CPU autoregressive reference -- byte-identical math to eager baseline. */
static void cpu_ref(const float* x,const float* g1,const float* g2,
    const float* Wq,const float* Wk,const float* Wv,const float* Wo,
    const float* Wg,const float* Wu,const float* Wd,
    const float* Kc,const float* Vc,int L,double* out){
  int Lp1=L+1; double xn1[D];
  double ss=0; for(int i=0;i<D;i++) ss+=(double)x[i]*x[i];
  double inv=1.0/sqrt(ss/D+1e-5);
  for(int i=0;i<D;i++) xn1[i]=(double)x[i]*inv*(double)g1[i];
  double Q[D],K[D],V[D];
  for(int r=0;r<D;r++){double a=0,b=0,c=0;for(int k=0;k<D;k++){double xv=xn1[k];a+=(double)Wq[r*D+k]*xv;b+=(double)Wk[r*D+k]*xv;c+=(double)Wv[r*D+k]*xv;}Q[r]=a;K[r]=b;V[r]=c;}
  double* Kf=(double*)malloc((size_t)Lp1*D*sizeof(double));
  double* Vf=(double*)malloc((size_t)Lp1*D*sizeof(double));
  for(int t=0;t<L;t++)for(int i=0;i<D;i++){Kf[(size_t)t*D+i]=(double)Kc[(size_t)t*D+i];Vf[(size_t)t*D+i]=(double)Vc[(size_t)t*D+i];}
  for(int i=0;i<D;i++){Kf[(size_t)L*D+i]=K[i];Vf[(size_t)L*D+i]=V[i];}
  double scale=1.0/sqrt((double)HD); double attn[D];
  for(int h=0;h<NH;h++){
    double* s=(double*)malloc((size_t)Lp1*sizeof(double)); double m=-1e300;
    for(int t=0;t<Lp1;t++){double dot=0;for(int c=0;c<HD;c++)dot+=Q[h*HD+c]*Kf[(size_t)t*D+h*HD+c];dot*=scale;s[t]=dot;if(dot>m)m=dot;}
    double l=0;for(int t=0;t<Lp1;t++){s[t]=exp(s[t]-m);l+=s[t];}
    for(int c=0;c<HD;c++){double acc=0;for(int t=0;t<Lp1;t++)acc+=s[t]*Vf[(size_t)t*D+h*HD+c];attn[h*HD+c]=acc/l;}
    free(s);
  }
  free(Kf);free(Vf);
  double O[D]; for(int r=0;r<D;r++){double a=0;for(int k=0;k<D;k++)a+=(double)Wo[r*D+k]*attn[k];O[r]=a;}
  double xr[D]; for(int i=0;i<D;i++) xr[i]=(double)x[i]+O[i];
  double xn2[D]; ss=0; for(int i=0;i<D;i++) ss+=xr[i]*xr[i];
  inv=1.0/sqrt(ss/D+1e-5);
  for(int i=0;i<D;i++) xn2[i]=xr[i]*inv*(double)g2[i];
  double* hh=(double*)malloc((size_t)FF*sizeof(double));
  for(int r=0;r<FF;r++){double gg=0,uu=0;for(int k=0;k<D;k++){double xv=xn2[k];gg+=(double)Wg[r*D+k]*xv;uu+=(double)Wu[r*D+k]*xv;}double sg=1.0/(1.0+exp(-gg));hh[r]=gg*sg*uu;}
  for(int r=0;r<D;r++){double a=0;for(int k=0;k<FF;k++)a+=(double)Wd[r*FF+k]*hh[k];out[r]=xr[r]+a;}
  free(hh);
}

int main(int argc,char**argv){
  if(argc<2){fprintf(stderr,"usage: %s decode_fused.ptx [L]\n",argv[0]);return 2;}
  const char* ptxpath=argv[1];
  int L=(argc>2)?atoi(argv[2]):256; int Lp1=L+1;
  size_t szD=(size_t)D*sizeof(float);

  /* identical LCG-seeded inputs as eager baseline */
  float *x=(float*)malloc(szD),*g1=(float*)malloc(szD),*g2=(float*)malloc(szD);
  float *Wq=(float*)malloc((size_t)D*D*4),*Wk=(float*)malloc((size_t)D*D*4);
  float *Wv=(float*)malloc((size_t)D*D*4),*Wo=(float*)malloc((size_t)D*D*4);
  float *Wg=(float*)malloc((size_t)FF*D*4),*Wu=(float*)malloc((size_t)FF*D*4);
  float *Wd=(float*)malloc((size_t)D*FF*4);
  float *Kc=(float*)malloc((size_t)L*D*4),*Vc=(float*)malloc((size_t)L*D*4);
  float wq=0.036f;
  for(int i=0;i<D;i++){x[i]=lcg_f32();g1[i]=1.f+0.1f*lcg_f32();g2[i]=1.f+0.1f*lcg_f32();}
  for(int i=0;i<D*D;i++){Wq[i]=lcg_f32()*wq;Wk[i]=lcg_f32()*wq;Wv[i]=lcg_f32()*wq;Wo[i]=lcg_f32()*wq;}
  for(int i=0;i<FF*D;i++){Wg[i]=lcg_f32()*wq;Wu[i]=lcg_f32()*wq;}
  for(int i=0;i<D*FF;i++) Wd[i]=lcg_f32()*0.018f;
  for(int i=0;i<L*D;i++){Kc[i]=lcg_f32()*wq*0.5f;Vc[i]=lcg_f32();}

  double ref[D]; cpu_ref(x,g1,g2,Wq,Wk,Wv,Wo,Wg,Wu,Wd,Kc,Vc,L,ref);

  /* driver init + module */
  DR(cuInit(0)); CUdevice dev; DR(cuDeviceGet(&dev,0));
  CUcontext ctx; DR(cuCtxCreate(&ctx,0,dev));
  FILE* fp=fopen(ptxpath,"rb"); if(!fp){perror("ptx");return 1;}
  fseek(fp,0,SEEK_END); long np=ftell(fp); fseek(fp,0,SEEK_SET);
  char* ptx=(char*)malloc(np+1); fread(ptx,1,np,fp); ptx[np]=0; fclose(fp);
  CUmodule mod; CUjit_option jo[1]={CU_JIT_TARGET_FROM_CUCONTEXT}; void* jv[1]={0};
  DR(cuModuleLoadDataEx(&mod,ptx,1,jo,jv));
  CUfunction fattn,fffn; DR(cuModuleGetFunction(&fattn,mod,"decode_attn_fused"));
  DR(cuModuleGetFunction(&fffn,mod,"decode_ffn_fused"));

  /* device buffers + HBM scratch for cross-CTA shared data */
  CUdeviceptr dx,dg1,dg2,dWq,dWk,dWv,dWo,dWg,dWu,dWd,dKc,dVc,dxa,dhscr,dout;
  CUdeviceptr dxn1,dQg,dKg,dVg,dattn,dxn2,dssscr,dpscr;
  DR(cuMemAlloc(&dx,szD));DR(cuMemAlloc(&dg1,szD));DR(cuMemAlloc(&dg2,szD));
  DR(cuMemAlloc(&dWq,(size_t)D*D*4));DR(cuMemAlloc(&dWk,(size_t)D*D*4));
  DR(cuMemAlloc(&dWv,(size_t)D*D*4));DR(cuMemAlloc(&dWo,(size_t)D*D*4));
  DR(cuMemAlloc(&dWg,(size_t)FF*D*4));DR(cuMemAlloc(&dWu,(size_t)FF*D*4));
  DR(cuMemAlloc(&dWd,(size_t)D*FF*4));
  DR(cuMemAlloc(&dKc,(size_t)Lp1*D*4));DR(cuMemAlloc(&dVc,(size_t)Lp1*D*4));
  DR(cuMemAlloc(&dxa,szD));DR(cuMemAlloc(&dhscr,(size_t)FF*4));DR(cuMemAlloc(&dout,szD));
  DR(cuMemAlloc(&dxn1,szD));DR(cuMemAlloc(&dQg,szD));DR(cuMemAlloc(&dKg,szD));
  DR(cuMemAlloc(&dVg,szD));DR(cuMemAlloc(&dattn,szD));DR(cuMemAlloc(&dxn2,szD));
  DR(cuMemcpyHtoD(dg1,g1,szD));DR(cuMemcpyHtoD(dg2,g2,szD));
  DR(cuMemcpyHtoD(dWq,Wq,(size_t)D*D*4));DR(cuMemcpyHtoD(dWk,Wk,(size_t)D*D*4));
  DR(cuMemcpyHtoD(dWv,Wv,(size_t)D*D*4));DR(cuMemcpyHtoD(dWo,Wo,(size_t)D*D*4));
  DR(cuMemcpyHtoD(dWg,Wg,(size_t)FF*D*4));DR(cuMemcpyHtoD(dWu,Wu,(size_t)FF*D*4));
  DR(cuMemcpyHtoD(dWd,Wd,(size_t)D*FF*4));
  DR(cuMemcpyHtoD(dKc,Kc,(size_t)L*D*4));DR(cuMemcpyHtoD(dVc,Vc,(size_t)L*D*4));

  float scale=1.f/sqrtf((float)HD);
  int BLK=256;
  /* query max cooperative grid = occupancy * SM count */
  int numSM=0; CK(cudaDeviceGetAttribute(&numSM,cudaDevAttrMultiProcessorCount,0));
  int occ1=0,occ2=0;
  /* occupancy via driver: blocks per SM for each kernel at BLK threads, 0 smem */
  DR(cuOccupancyMaxActiveBlocksPerMultiprocessor(&occ1,fattn,BLK,0));
  DR(cuOccupancyMaxActiveBlocksPerMultiprocessor(&occ2,fffn,BLK,0));
  int occ=(occ1<occ2)?occ1:occ2; if(occ<1)occ=1;
  int GRID=numSM*occ;
  const char* genv=getenv("FUSED_GRID"); if(genv){int g=atoi(genv); if(g>=1&&g<=numSM*occ) GRID=g;}
  DR(cuMemAlloc(&dssscr,(size_t)GRID*4));
  /* pscr: NH * KW * (2+HD), KW = (GRID*BLK/32)/NH. alloc for the actual GRID. */
  int gnw=(GRID*BLK)/32; int KW=gnw/NH; if(KW<1)KW=1;
  DR(cuMemAlloc(&dpscr,(size_t)NH*KW*(2+HD)*4));
  fprintf(stderr,"coop grid: numSM=%d occ=%d GRID=%d blk=%d gnw=%d KW=%d\n",numSM,occ,GRID,BLK,gnw,KW);

  /* one fused layer = 2 cooperative launches. reset dx each pass. */
  #define FLAYER() do{ \
    DR(cuMemcpyHtoD(dx,x,szD)); \
    void* a1[]={&dx,&dg1,&dWq,&dWk,&dWv,&dWo,&dKc,&dVc,&dxa,&dxn1,&dQg,&dKg,&dVg,&dattn,&dssscr,&dpscr,&L,&scale}; \
    DR(cuLaunchCooperativeKernel(fattn,GRID,1,1, BLK,1,1, 0,0,a1)); \
    int z=0; void* a2[]={&dxa,&dg2,&dWg,&dWu,&dWd,&dxn2,&dhscr,&dout,&dssscr,&z}; \
    DR(cuLaunchCooperativeKernel(fffn,GRID,1,1, BLK,1,1, 0,0,a2)); \
  }while(0)

  /* numeric capture */
  FLAYER(); DR(cuCtxSynchronize());
  float gpu[D]; DR(cuMemcpyDtoH(gpu,dout,szD));
  double maxrel=0; int nan_inf=0;
  for(int i=0;i<D;i++){ double r=ref[i],g=gpu[i];
    if(!isfinite(g)){nan_inf++;continue;}
    double den=fabs(r); if(den<1e-6)den=1e-6; double rel=fabs(g-r)/den; if(rel>maxrel)maxrel=rel; }

  /* timing 20 warmup + 200 median (cudaEvent) */
  cudaEvent_t ea,eb; CK(cudaEventCreate(&ea));CK(cudaEventCreate(&eb));
  for(int i=0;i<20;i++){FLAYER();} DR(cuCtxSynchronize());
  float* tms=(float*)malloc(200*sizeof(float));
  for(int i=0;i<200;i++){ CK(cudaEventRecord(ea)); FLAYER(); CK(cudaEventRecord(eb)); CK(cudaEventSynchronize(eb)); CK(cudaEventElapsedTime(&tms[i],ea,eb)); }
  double med=medms(tms,200);

  printf("{\"variant\":\"fused2\",\"L\":%d,\"layer_ms\":%.6f,\"max_rel\":%.6g,\"nan_inf\":%d}\n",L,med,maxrel,nan_inf);
  fprintf(stderr,"FUSED L=%d layer_ms=%.6f max_rel=%.3g nan_inf=%d\n",L,med,maxrel,nan_inf);
  return 0;
}
