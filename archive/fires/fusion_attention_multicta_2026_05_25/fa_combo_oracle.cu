/* Combined: WARPS warps/CTA (each warp owns an independent 16-query-row tile)
 * AND wide KV tiles (BK = BKT*16 keys per softmax round). This raises per-SM
 * occupancy (more warps resident) while amortizing the softmax/rescale over
 * BK keys. grid = ceil(N/(WARPS*16)). Validate numeric, then time.
 *
 * Build: nvcc -O2 -arch=sm_90a -DWARPS=4 -DBKT=8 -o fa_combo fa_combo_oracle.cu
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <mma.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
using namespace nvcuda;
#ifndef WARPS
#define WARPS 4
#endif
#ifndef BKT
#define BKT 8
#endif
#define BK (BKT*16)
#define BQ (WARPS*16)
#define CK(call) do{cudaError_t e=(call);if(e!=cudaSuccess){fprintf(stderr,"CUDA err %s @ %d\n",cudaGetErrorString(e),__LINE__);return 1;}}while(0)

__global__ void fa_combo(const __half* q,const __half* k,const __half* v,__half* o,int N,float scale){
    __shared__ float s_tile[WARPS][16*BK];
    __shared__ __half p_tile[WARPS][16*BK];
    __shared__ float o_tile[WARPS][16*64];
    __shared__ float m_vec[WARPS][16],l_vec[WARPS][16],c_vec[WARPS][16];
    int warp=threadIdx.x>>5, lane=threadIdx.x&31;
    int qrow_base=blockIdx.x*BQ + warp*16;
    const __half* qb=q+(size_t)qrow_base*64;
    float *S=s_tile[warp]; __half *P=p_tile[warp]; float *O=o_tile[warp];
    float *mV=m_vec[warp],*lV=l_vec[warp],*cV=c_vec[warp];
    int valid=(qrow_base<N);
    if(lane<16){mV[lane]=-INFINITY;lV[lane]=0.0f;}
    for(int idx=lane;idx<16*64;idx+=32) O[idx]=0.0f;
    __syncwarp();
    int n_blocks=N/BK;
    for(int kb_i=0;kb_i<n_blocks;++kb_i){
        int krow_base=kb_i*BK;
        const __half* kb=k+(size_t)krow_base*64;
        const __half* vb=v+(size_t)krow_base*64;
        #pragma unroll
        for(int sub=0;sub<BKT;++sub){
            const __half* kbs=kb+(size_t)sub*16*64;
            wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> a;
            wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> b;
            wmma::fragment<wmma::accumulator,16,16,16,float> sf;
            wmma::fill_fragment(sf,0.0f);
            #pragma unroll
            for(int kk=0;kk<4;++kk){ wmma::load_matrix_sync(a,qb+kk*16,64); wmma::load_matrix_sync(b,kbs+kk*16,64); wmma::mma_sync(sf,a,b,sf); }
            #pragma unroll
            for(int i=0;i<sf.num_elements;++i) sf.x[i]*=scale;
            wmma::store_matrix_sync(S+sub*16,sf,BK,wmma::mem_row_major);
        }
        __syncwarp();
        if(lane<16){
            int i=lane; float smx=-INFINITY;
            #pragma unroll
            for(int j=0;j<BK;++j) smx=fmaxf(smx,S[i*BK+j]);
            float mp=mV[i],mn=fmaxf(mp,smx),c=__expf(mp-mn); cV[i]=c;
            float rs=0.0f;
            #pragma unroll
            for(int j=0;j<BK;++j){ float p=__expf(S[i*BK+j]-mn); rs+=p; P[i*BK+j]=__float2half(p); }
            lV[i]=lV[i]*c+rs; mV[i]=mn;
        }
        __syncwarp();
        for(int idx=lane;idx<16*64;idx+=32){ int row=idx>>6; O[idx]*=cV[row]; }
        __syncwarp();
        #pragma unroll
        for(int t=0;t<4;++t){
            wmma::fragment<wmma::accumulator,16,16,16,float> op; wmma::fill_fragment(op,0.0f);
            #pragma unroll
            for(int sub=0;sub<BKT;++sub){
                wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa;
                wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vbf;
                wmma::load_matrix_sync(pa,P+sub*16,BK);
                wmma::load_matrix_sync(vbf,vb+(size_t)sub*16*64+t*16,64);
                wmma::mma_sync(op,pa,vbf,op);
            }
            wmma::store_matrix_sync(S,op,BK,wmma::mem_row_major);
            __syncwarp();
            for(int idx=lane;idx<16*16;idx+=32){ int r=idx>>4,cc=idx&15; O[r*64+t*16+cc]+=S[r*BK+cc]; }
            __syncwarp();
        }
    }
    if(valid&&lane<16){ int i=lane,row=qrow_base+i; if(row<N){ float inv=1.0f/lV[i];
        #pragma unroll
        for(int e=0;e<64;++e) o[(size_t)row*64+e]=__float2half(O[i*64+e]*inv); } }
}

static uint32_t lcg=0x12345678u;
static float rf(){lcg=lcg*1664525u+1013904223u;return ((float)(lcg>>8)/(float)(1u<<24))-0.5f;}
static int cmpd(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return(x<y)?-1:(x>y)?1:0;}
int main(int argc,char**argv){
    int N=(argc>1)?atoi(argv[1]):512,d=64,do_time=(argc>2&&atoi(argv[2])==1);
    if(N%BK){fprintf(stderr,"N must be mult of BK=%d\n",BK);return 2;}
    size_t E=(size_t)N*d;
    float *qf=(float*)malloc(E*4),*kf=(float*)malloc(E*4),*vf=(float*)malloc(E*4);
    __half *hq=(__half*)malloc(E*2),*hk=(__half*)malloc(E*2),*hv=(__half*)malloc(E*2),*ho=(__half*)malloc(E*2);
    double *ref=(double*)malloc(E*8);
    for(size_t i=0;i<E;++i){hq[i]=__float2half(rf()*4.0f);qf[i]=__half2float(hq[i]);}
    for(size_t i=0;i<E;++i){hk[i]=__float2half(rf()*4.0f);kf[i]=__half2float(hk[i]);}
    for(size_t i=0;i<E;++i){hv[i]=__float2half(rf());     vf[i]=__half2float(hv[i]);}
    float scale=1.0f/sqrtf((float)d);
    double *sr=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){double m=-1e300;for(int j=0;j<N;++j){double s=0;for(int l=0;l<d;++l)s+=(double)qf[(size_t)i*d+l]*(double)kf[(size_t)j*d+l];s*=scale;sr[j]=s;if(s>m)m=s;}
        double su=0;for(int j=0;j<N;++j){sr[j]=exp(sr[j]-m);su+=sr[j];}double iv=1.0/su;
        for(int e=0;e<d;++e){double ac=0;for(int j=0;j<N;++j)ac+=sr[j]*(double)vf[(size_t)j*d+e];ref[(size_t)i*d+e]=ac*iv;}}
    __half *dq,*dk,*dv,*dO; CK(cudaMalloc(&dq,E*2));CK(cudaMalloc(&dk,E*2));CK(cudaMalloc(&dv,E*2));CK(cudaMalloc(&dO,E*2));
    CK(cudaMemcpy(dq,hq,E*2,cudaMemcpyHostToDevice));CK(cudaMemcpy(dk,hk,E*2,cudaMemcpyHostToDevice));CK(cudaMemcpy(dv,hv,E*2,cudaMemcpyHostToDevice));
    int grid=(N+BQ-1)/BQ,block=WARPS*32;
    fa_combo<<<grid,block>>>(dq,dk,dv,dO,N,scale); cudaError_t le=cudaGetLastError();
    if(le!=cudaSuccess){fprintf(stderr,"launch err %s (smem may overflow)\n",cudaGetErrorString(le));return 3;}
    CK(cudaDeviceSynchronize()); CK(cudaMemcpy(ho,dO,E*2,cudaMemcpyDeviceToHost));
    double *rm=(double*)malloc((size_t)N*8); for(int i=0;i<N;++i){double mx=0;for(int e=0;e<d;++e){double w=fabs(ref[(size_t)i*d+e]);if(w>mx)mx=w;}rm[i]=mx;}
    double ma=0,rr=0,sse=0,ssrf=0;
    for(size_t i=0;i<E;++i){double g=(double)__half2float(ho[i]),w=ref[i],a=fabs(g-w);if(a>ma)ma=a;int r=(int)(i/d);double q=a/(rm[r]+1e-9);if(q>rr)rr=q;sse+=a*a;ssrf+=w*w;}
    double rms=sqrt(sse/(ssrf+1e-30));int pass=(rr<=1e-2);
    printf("combo W=%d BKT=%d N=%d grid=%d(vs48SM) smem=%zuB/cta max_abs=%.4g rel_rs=%.4g rms=%.4g numeric=%s",
        WARPS,BKT,N,grid,(size_t)WARPS*(16*BK*4+16*BK*2+16*64*4+48*4),ma,rr,rms,pass?"PASS":"FAIL");
    if(do_time){cudaEvent_t st,en;cudaEventCreate(&st);cudaEventCreate(&en);
        for(int w=0;w<20;++w)fa_combo<<<grid,block>>>(dq,dk,dv,dO,N,scale);cudaDeviceSynchronize();
        int reps=200;double *ms=(double*)malloc(reps*8);
        for(int r=0;r<reps;++r){cudaEventRecord(st,0);fa_combo<<<grid,block>>>(dq,dk,dv,dO,N,scale);cudaEventRecord(en,0);cudaEventSynchronize(en);float t;cudaEventElapsedTime(&t,st,en);ms[r]=t;}
        qsort(ms,reps,8,cmpd);printf(" median_ms=%.6f",ms[reps/2]);}
    printf("\n");return pass?0:1;
}
