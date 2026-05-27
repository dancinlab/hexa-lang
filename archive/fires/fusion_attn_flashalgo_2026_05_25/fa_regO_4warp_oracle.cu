/* Round-8d: FA-2 reg-O, 4 warps/CTA, BM=64 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <mma.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
using namespace nvcuda;
#define CK(call) do { cudaError_t e=(call); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA err %s\n",cudaGetErrorString(e)); return 1;}}while(0)
__device__ __forceinline__ void sf(wmma::fragment<wmma::accumulator,16,16,16,float>& f, const float* s, int lane){
    int g_lo=lane>>2,g_hi=g_lo+8; float a=s[g_lo],b=s[g_hi];
    f.x[0]*=a;f.x[1]*=a;f.x[2]*=b;f.x[3]*=b;f.x[4]*=a;f.x[5]*=a;f.x[6]*=b;f.x[7]*=b; }
extern "C" __global__ void fa_regO_4warp(const __half* q,const __half* k,const __half* v,__half* o,int N,float scale){
    __shared__ float s_tile[4][16*16];
    __shared__ __half p_tile[4][16*16];
    __shared__ float m_vec[64], l_vec[64], c_vec[64];
    int tid=threadIdx.x, wid=tid>>5, lane=tid&31;
    int qrow_base=blockIdx.x*64, my_qrow=qrow_base+wid*16;
    const __half* qb=q+(size_t)my_qrow*64;
    if(lane<16){ m_vec[wid*16+lane]=-INFINITY; l_vec[wid*16+lane]=0.f; }
    __syncthreads();
    wmma::fragment<wmma::accumulator,16,16,16,float> oacc[4];
    #pragma unroll
    for(int t=0;t<4;++t) wmma::fill_fragment(oacc[t],0.f);
    int n=N>>4;
    for(int kt=0;kt<n;++kt){
        int kr=kt*16; const __half* kb=k+(size_t)kr*64; const __half* vb=v+(size_t)kr*64;
        wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> a;
        wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> b;
        wmma::fragment<wmma::accumulator,16,16,16,float> sfr; wmma::fill_fragment(sfr,0.f);
        #pragma unroll
        for(int kk=0;kk<4;++kk){ wmma::load_matrix_sync(a,qb+kk*16,64);
            wmma::load_matrix_sync(b,kb+kk*16,64); wmma::mma_sync(sfr,a,b,sfr); }
        #pragma unroll
        for(int i=0;i<sfr.num_elements;++i) sfr.x[i]*=scale;
        wmma::store_matrix_sync(s_tile[wid],sfr,16,wmma::mem_row_major);
        __syncwarp();
        if(lane<16){ int i=lane; float sm=-INFINITY;
            #pragma unroll
            for(int j=0;j<16;++j) sm=fmaxf(sm,s_tile[wid][i*16+j]);
            float mp=m_vec[wid*16+i], mn=fmaxf(mp,sm); float c=__expf(mp-mn); c_vec[wid*16+i]=c; float rs=0;
            #pragma unroll
            for(int j=0;j<16;++j){ float p=__expf(s_tile[wid][i*16+j]-mn); rs+=p; p_tile[wid][i*16+j]=__float2half(p); }
            l_vec[wid*16+i]=l_vec[wid*16+i]*c+rs; m_vec[wid*16+i]=mn; }
        __syncwarp();
        #pragma unroll
        for(int t=0;t<4;++t) sf(oacc[t],c_vec+wid*16,lane);
        wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa;
        wmma::load_matrix_sync(pa,p_tile[wid],16);
        #pragma unroll
        for(int t=0;t<4;++t){ wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vbf;
            wmma::load_matrix_sync(vbf,vb+t*16,64); wmma::mma_sync(oacc[t],pa,vbf,oacc[t]); }
        __syncwarp(); }
    if(lane<16) c_vec[wid*16+lane]=1.f/l_vec[wid*16+lane]; __syncwarp();
    #pragma unroll
    for(int t=0;t<4;++t){ sf(oacc[t],c_vec+wid*16,lane);
        wmma::store_matrix_sync(s_tile[wid],oacc[t],16,wmma::mem_row_major); __syncwarp();
        if(lane<16){ int i=lane; int r=my_qrow+i; if(r<N){
            #pragma unroll
            for(int e=0;e<16;++e) o[(size_t)r*64+t*16+e]=__float2half(s_tile[wid][i*16+e]); } } __syncwarp(); } }
static uint32_t lcg=0x12345678u;
static float lf(void){ lcg=lcg*1664525u+1013904223u; return ((float)(lcg>>8)/(float)(1u<<24))-0.5f; }
static int cd(const void*a,const void*b){ double x=*(const double*)a,y=*(const double*)b; return (x<y)?-1:(x>y)?1:0; }
int main(int argc,char**argv){
    int N=(argc>1)?atoi(argv[1]):512; int d=64,dt=(argc>2&&atoi(argv[2])==1);
    if(N%64!=0){ fprintf(stderr,"N%%64\n"); return 2; }
    size_t e=(size_t)N*d;
    float *hqf=(float*)malloc(e*4),*hkf=(float*)malloc(e*4),*hvf=(float*)malloc(e*4);
    __half *hq=(__half*)malloc(e*2),*hk=(__half*)malloc(e*2),*hv=(__half*)malloc(e*2),*ho=(__half*)malloc(e*2);
    double *ref=(double*)malloc(e*8);
    for(size_t i=0;i<e;++i){ hq[i]=__float2half(lf()*4.f); hqf[i]=__half2float(hq[i]); }
    for(size_t i=0;i<e;++i){ hk[i]=__float2half(lf()*4.f); hkf[i]=__half2float(hk[i]); }
    for(size_t i=0;i<e;++i){ hv[i]=__float2half(lf()); hvf[i]=__half2float(hv[i]); }
    float s=1.f/sqrtf((float)d);
    double *sr=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){ double m=-1e300;
        for(int j=0;j<N;++j){ double v=0; for(int l=0;l<d;++l) v+=(double)hqf[(size_t)i*d+l]*(double)hkf[(size_t)j*d+l];
            v*=(double)s; sr[j]=v; if(v>m)m=v; }
        double su=0; for(int j=0;j<N;++j){ sr[j]=exp(sr[j]-m); su+=sr[j]; } double iv=1./su;
        for(int x=0;x<d;++x){ double ac=0; for(int j=0;j<N;++j) ac+=sr[j]*(double)hvf[(size_t)j*d+x]; ref[(size_t)i*d+x]=ac*iv; } } free(sr);
    __half *dq,*dk,*dv,*dO;
    CK(cudaMalloc(&dq,e*2)); CK(cudaMalloc(&dk,e*2)); CK(cudaMalloc(&dv,e*2)); CK(cudaMalloc(&dO,e*2));
    CK(cudaMemcpy(dq,hq,e*2,cudaMemcpyHostToDevice)); CK(cudaMemcpy(dk,hk,e*2,cudaMemcpyHostToDevice)); CK(cudaMemcpy(dv,hv,e*2,cudaMemcpyHostToDevice));
    fa_regO_4warp<<<N/64,128>>>(dq,dk,dv,dO,N,s);
    CK(cudaDeviceSynchronize()); CK(cudaMemcpy(ho,dO,e*2,cudaMemcpyDeviceToHost));
    double *rm=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){ double mx=0; for(int x=0;x<d;++x){ double w=fabs(ref[(size_t)i*d+x]); if(w>mx)mx=w; } rm[i]=mx; }
    double ma=0,rs=0,ss=0,sr2=0;
    for(size_t i=0;i<e;++i){ double g=(double)__half2float(ho[i]),w=ref[i],a=fabs(g-w);
        if(a>ma)ma=a; int r=(int)(i/d); double rr=a/(rm[r]+1e-9); if(rr>rs)rs=rr; ss+=a*a; sr2+=w*w; }
    int p=(rs<=1e-2);
    printf("regO_4warp N=%d grid=%d max_abs=%.4g rel_rowscale=%.4g rms_rel=%.4g numeric=%s",N,N/64,ma,rs,sqrt(ss/(sr2+1e-30)),p?"PASS":"FAIL");
    if(dt){ cudaEvent_t st,en; cudaEventCreate(&st); cudaEventCreate(&en);
        for(int w=0;w<20;++w) fa_regO_4warp<<<N/64,128>>>(dq,dk,dv,dO,N,s); cudaDeviceSynchronize();
        int rp=200; double *ms=(double*)malloc(rp*8);
        for(int r=0;r<rp;++r){ cudaEventRecord(st,0); fa_regO_4warp<<<N/64,128>>>(dq,dk,dv,dO,N,s); cudaEventRecord(en,0); cudaEventSynchronize(en); float t; cudaEventElapsedTime(&t,st,en); ms[r]=t; }
        qsort(ms,rp,8,cd); printf(" median_ms=%.6f",ms[rp/2]); }
    printf("\n"); return p?0:1; }
