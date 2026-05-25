/* Flash-attention with WIDER KV tile (Bk = BKT*16 keys per softmax round) to
 * amortize the online-softmax + O-rescale overhead over more keys. 1 warp/CTA,
 * BQ=16, d=64, grid=N/16. S tile is 16 x Bk in shared (still never to HBM for
 * the materialized N x N S -- only the running 16xBk tile lives in smem).
 * Sweeps BKT in {1,2,4}.  Validated numeric before any PTX commit.
 *
 * Build: nvcc -O2 -arch=sm_90a -DBKT=4 -o fa_bk fa_bk_oracle.cu
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <mma.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
using namespace nvcuda;
#ifndef BKT
#define BKT 4
#endif
#define BK (BKT*16)
#define CK(call) do{cudaError_t e=(call);if(e!=cudaSuccess){fprintf(stderr,"CUDA err %s @ %d\n",cudaGetErrorString(e),__LINE__);return 1;}}while(0)

__global__ void fa_bk(const __half* q,const __half* k,const __half* v,__half* o,int N,float scale){
    __shared__ float s_tile[16*BK];     // 16 x Bk running score tile
    __shared__ __half p_tile[16*BK];    // probs
    __shared__ float o_tile[16*64];     // running O
    __shared__ float m_vec[16],l_vec[16],c_vec[16];
    int lane=threadIdx.x&31;
    int qrow_base=blockIdx.x*16;
    const __half* qb=q+(size_t)qrow_base*64;
    if(lane<16){m_vec[lane]=-INFINITY;l_vec[lane]=0.0f;}
    for(int idx=lane;idx<16*64;idx+=32) o_tile[idx]=0.0f;
    __syncwarp();

    int n_blocks = N / BK;
    for(int kb_i=0;kb_i<n_blocks;++kb_i){
        int krow_base=kb_i*BK;
        const __half* kb=k+(size_t)krow_base*64;
        const __half* vb=v+(size_t)krow_base*64;

        // QK^T for each of BKT key-subtiles -> s_tile[:, sub*16 ..]
        #pragma unroll
        for(int sub=0;sub<BKT;++sub){
            const __half* kbs=kb+(size_t)sub*16*64;
            wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> a_frag;
            wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> b_frag;
            wmma::fragment<wmma::accumulator,16,16,16,float> s_frag;
            wmma::fill_fragment(s_frag,0.0f);
            #pragma unroll
            for(int kk=0;kk<4;++kk){
                wmma::load_matrix_sync(a_frag,qb+kk*16,64);
                wmma::load_matrix_sync(b_frag,kbs+kk*16,64);
                wmma::mma_sync(s_frag,a_frag,b_frag,s_frag);
            }
            #pragma unroll
            for(int i=0;i<s_frag.num_elements;++i) s_frag.x[i]*=scale;
            // store into the sub-th 16-col slab of s_tile (ldm = BK)
            wmma::store_matrix_sync(s_tile+sub*16, s_frag, BK, wmma::mem_row_major);
        }
        __syncwarp();

        // online softmax over the full Bk-wide row
        if(lane<16){
            int i=lane;
            float s_max=-INFINITY;
            #pragma unroll
            for(int j=0;j<BK;++j) s_max=fmaxf(s_max,s_tile[i*BK+j]);
            float m_prev=m_vec[i],m_new=fmaxf(m_prev,s_max),c=__expf(m_prev-m_new);
            c_vec[i]=c;
            float row_sum=0.0f;
            #pragma unroll
            for(int j=0;j<BK;++j){ float p=__expf(s_tile[i*BK+j]-m_new); row_sum+=p; p_tile[i*BK+j]=__float2half(p); }
            l_vec[i]=l_vec[i]*c+row_sum; m_vec[i]=m_new;
        }
        __syncwarp();
        // rescale O by c
        for(int idx=lane;idx<16*64;idx+=32){ int row=idx>>6; o_tile[idx]*=c_vec[row]; }
        __syncwarp();

        // P.V : P is 16 x Bk, V is Bk x 64. Sum over BKT key-subtiles, 4 N-tiles.
        #pragma unroll
        for(int t=0;t<4;++t){
            wmma::fragment<wmma::accumulator,16,16,16,float> op_frag;
            wmma::fill_fragment(op_frag,0.0f);
            #pragma unroll
            for(int sub=0;sub<BKT;++sub){
                wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa_frag;
                wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vb_frag;
                wmma::load_matrix_sync(pa_frag, p_tile+sub*16, BK);   // P sub-block 16x16
                wmma::load_matrix_sync(vb_frag, vb+(size_t)sub*16*64 + t*16, 64);
                wmma::mma_sync(op_frag,pa_frag,vb_frag,op_frag);
            }
            wmma::store_matrix_sync(s_tile, op_frag, BK, wmma::mem_row_major); // reuse s_tile slab 0
            __syncwarp();
            for(int idx=lane;idx<16*16;idx+=32){ int r=idx>>4,cc=idx&15; o_tile[r*64+t*16+cc]+=s_tile[r*BK+cc]; }
            __syncwarp();
        }
    }
    if(lane<16){ int i=lane,row=qrow_base+i; if(row<N){ float inv=1.0f/l_vec[i];
        #pragma unroll
        for(int e=0;e<64;++e) o[(size_t)row*64+e]=__float2half(o_tile[i*64+e]*inv); } }
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
    int grid=N/16,block=32;
    fa_bk<<<grid,block>>>(dq,dk,dv,dO,N,scale); CK(cudaDeviceSynchronize()); CK(cudaMemcpy(ho,dO,E*2,cudaMemcpyDeviceToHost));
    double *rm=(double*)malloc((size_t)N*8); for(int i=0;i<N;++i){double mx=0;for(int e=0;e<d;++e){double w=fabs(ref[(size_t)i*d+e]);if(w>mx)mx=w;}rm[i]=mx;}
    double ma=0,rr=0,sse=0,ssr=0;
    for(size_t i=0;i<E;++i){double g=(double)__half2float(ho[i]),w=ref[i],a=fabs(g-w);if(a>ma)ma=a;int r=(int)(i/d);double q=a/(rm[r]+1e-9);if(q>rr)rr=q;sse+=a*a;ssr+=w*w;}
    double rms=sqrt(sse/(ssr+1e-30));int pass=(rr<=1e-2);
    printf("bk BKT=%d BK=%d N=%d grid=%d(vs48SM) max_abs=%.4g rel_rowscale=%.4g rms_rel=%.4g numeric=%s",BKT,BK,N,grid,ma,rr,rms,pass?"PASS":"FAIL");
    if(do_time){cudaEvent_t st,en;cudaEventCreate(&st);cudaEventCreate(&en);
        for(int w=0;w<20;++w)fa_bk<<<grid,block>>>(dq,dk,dv,dO,N,scale);cudaDeviceSynchronize();
        int reps=200;double *ms=(double*)malloc(reps*8);
        for(int r=0;r<reps;++r){cudaEventRecord(st,0);fa_bk<<<grid,block>>>(dq,dk,dv,dO,N,scale);cudaEventRecord(en,0);cudaEventSynchronize(en);float t;cudaEventElapsedTime(&t,st,en);ms[r]=t;}
        qsort(ms,reps,8,cmpd);printf(" median_ms=%.6f",ms[reps/2]);}
    printf("\n");return pass?0:1;
}
