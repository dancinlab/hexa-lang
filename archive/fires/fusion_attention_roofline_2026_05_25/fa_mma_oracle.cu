/* F-FUSION-ATTN-ROOFLINE oracle -- CUDA-C kernel using the EXACT same
 * mma.sync.m16n8k16 + ldmatrix instruction sequence + smem layout as the
 * hand-emit flash_attn_tma_sw128.ptx, but with ordinary cp.async (not TMA) and
 * an unswizzled smem layout so the fragment-handling correctness is validated
 * independently of the TMA descriptor setup. If THIS matches the f64 ref, the
 * mma fragment math (QK^T trans + P.V non-trans + C-frag scatter) is correct,
 * and the PTX kernel inherits that correctness (it only changes the LOAD path
 * to TMA+swizzle, which is byte-equivalent data delivery).
 *
 * Design mirror (per-CTA BM=64 query rows, 4-warp 2x2, BK=64 key block):
 *   QK^T: S[64x64] = Q[64x64] . K[64x64]^T  (mma .row.col, B=K via ldmatrix.trans)
 *   P.V : O[64x64] += P[64x64] . V[64x64]   (mma .row.col, B=V non-trans)
 * with online softmax over the 64x64 S tile (running m_i, l_i, correction c_i).
 *
 * Build: nvcc -O2 -arch=sm_90a -o fa_mma_oracle fa_mma_oracle.cu
 *   (sm_90a JIT->sm_120 at load; mma.sync.m16n8k16 + ldmatrix are sm_80+).
 * Run:   ./fa_mma_oracle [N]   (d fixed = 64)
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>

#define CK(call) do { cudaError_t e=(call); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA err %s @ %s:%d\n",cudaGetErrorString(e),__FILE__,__LINE__); return 1;}}while(0)

/* Unswizzled 64x64 fp16 tile: row-major, 128 B/row. ldmatrix needs a per-lane
 * shared-memory address; for an m8n8.x4 load each lane supplies the base of an
 * 8x8 sub-tile it participates in. We replicate the PTX lane decomposition:
 *   row_idx = (lane & 7) + ((lane>>4)&1)*8     in [0,16)
 *   atom_off = (lane>>3)&1                       0/1
 * For an UNSWIZZLED tile the byte offset for (full_row, atom_k) is simply
 *   full_row*128 + atom_k*16    (atom_k in [0,4), each atom = 8 fp16 = 16 B)
 * The PTX adds the swizzle XOR; the data delivered to the mma fragment is the
 * same because the TMA writes swizzled and ldmatrix reads swizzled (the XOR is
 * an internal smem permutation invisible to the fragment). So validating the
 * UNSWIZZLED path validates the fragment math identically.
 */

__device__ __forceinline__ uint32_t smem_u32(const void* p){
    return (uint32_t)__cvta_generic_to_shared(p);
}

/* One mma K-step over the warp's 32-row A band and 32-col B band.
 * acc[32] are the 8 mma's f32 accumulators (4 each).
 * a_base/b_base = smem byte addr of the warp's tile (row 0, col 0).
 * s_idx in 0..3 (covers K-cols [s_idx*16 .. s_idx*16+15]).
 * b_trans: 1 -> ldmatrix.trans (K^T) ; 0 -> non-trans (V).
 */
__device__ __forceinline__ void mma_kstep(float acc[32], uint32_t a_base,
        uint32_t b_base, int s_idx, int lane, int b_trans) {
    int row_idx = (lane & 7) + ((lane>>4)&1)*8;
    int atom_off = (lane>>3)&1;
    int atom_k = s_idx*2 + atom_off;       /* 8-fp16 atom index in K direction */
    /* unswizzled: byte = full_row*128 + atom_k*16 ; top half rows 0..15, bot +16 */
    uint32_t a_top = a_base + row_idx*128 + atom_k*16;
    uint32_t a_bot = a_top + 16*128;
    uint32_t b_top = b_base + row_idx*128 + atom_k*16;
    uint32_t b_bot = b_top + 16*128;
    uint32_t ra[8], rbl[4], rbh[4];
    asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3}, [%4];"
        : "=r"(ra[0]),"=r"(ra[1]),"=r"(ra[2]),"=r"(ra[3]) : "r"(a_top));
    asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3}, [%4];"
        : "=r"(ra[4]),"=r"(ra[5]),"=r"(ra[6]),"=r"(ra[7]) : "r"(a_bot));
    if (b_trans) {
        asm volatile("ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16 {%0,%1,%2,%3}, [%4];"
            : "=r"(rbl[0]),"=r"(rbl[1]),"=r"(rbl[2]),"=r"(rbl[3]) : "r"(b_top));
        asm volatile("ldmatrix.sync.aligned.m8n8.x4.trans.shared.b16 {%0,%1,%2,%3}, [%4];"
            : "=r"(rbh[0]),"=r"(rbh[1]),"=r"(rbh[2]),"=r"(rbh[3]) : "r"(b_bot));
    } else {
        asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3}, [%4];"
            : "=r"(rbl[0]),"=r"(rbl[1]),"=r"(rbl[2]),"=r"(rbl[3]) : "r"(b_top));
        asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3}, [%4];"
            : "=r"(rbh[0]),"=r"(rbh[1]),"=r"(rbh[2]),"=r"(rbh[3]) : "r"(b_bot));
    }
    /* 8 mma.m16n8k16: [top16|bot16] rows x [n0 n1 n2 n3] (8-col) -> acc groups 0..7
     * matching the PTX emit order. */
    #define MMA(g, ar0,ar1,ar2,ar3, b0,b1) \
        asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 " \
        "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};" \
        : "+f"(acc[g*4+0]),"+f"(acc[g*4+1]),"+f"(acc[g*4+2]),"+f"(acc[g*4+3]) \
        : "r"(ar0),"r"(ar1),"r"(ar2),"r"(ar3), "r"(b0),"r"(b1))
    MMA(0, ra[0],ra[1],ra[2],ra[3], rbl[0],rbl[2]);
    MMA(1, ra[0],ra[1],ra[2],ra[3], rbl[1],rbl[3]);
    MMA(2, ra[0],ra[1],ra[2],ra[3], rbh[0],rbh[2]);
    MMA(3, ra[0],ra[1],ra[2],ra[3], rbh[1],rbh[3]);
    MMA(4, ra[4],ra[5],ra[6],ra[7], rbl[0],rbl[2]);
    MMA(5, ra[4],ra[5],ra[6],ra[7], rbl[1],rbl[3]);
    MMA(6, ra[4],ra[5],ra[6],ra[7], rbh[0],rbh[2]);
    MMA(7, ra[4],ra[5],ra[6],ra[7], rbh[1],rbh[3]);
    #undef MMA
}

/* Scatter the warp's 32 acc into a row-major f32 smem tile (warp tile base
 * already added to dst). Set add=1 to accumulate (P.V), add=0 to overwrite. */
__device__ __forceinline__ void acc_to_smem(float acc[32], uint32_t dst,
        int lane, int ldm_bytes, int add) {
    int r2 = lane>>2;
    int c2 = (lane&3)*2;
    for (int g=0; g<8; ++g) {
        int row_half = (g>=4)?16:0;
        int n8 = g&3;
        for (int e=0; e<4; ++e) {
            int row = row_half + ((e>=2)?8:0) + r2;
            int col = n8*8 + c2 + (e&1);
            uint32_t addr = dst + row*ldm_bytes + col*4;
            float* fp = (float*)__cvta_shared_to_generic(addr);
            if (add) *fp += acc[g*4+e]; else *fp = acc[g*4+e];
        }
    }
}

__global__ void fa_mma(const __half* q, const __half* k, const __half* v,
                       __half* o, int N, float scale) {
    extern __shared__ char smem[];
    __half* sQ = (__half*)(smem + 0);
    __half* sK = (__half*)(smem + 8192);
    __half* sV = (__half*)(smem + 16384);
    float*  sS = (float*) (smem + 24576);
    __half* sP = (__half*)(smem + 24576 + 16384);
    float*  sO = (float*) (smem + 24576 + 16384 + 8192);
    float*  sm = (float*) (smem + 24576 + 16384 + 8192 + 16384);
    float*  sl = sm + 64;
    float*  sc = sl + 64;

    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int m_tile = warp>>1, n_tile = warp&1;
    uint32_t a_band = m_tile*32*128;   /* warp A row band byte */
    uint32_t b_band = n_tile*32*128;   /* warp B row band byte */
    int qrow_base = blockIdx.x*64;

    uint32_t sQb = smem_u32(sQ), sKb = smem_u32(sK), sVb = smem_u32(sV);
    uint32_t sPb = smem_u32(sP), sSb = smem_u32(sS), sOb = smem_u32(sO);

    /* load Q tile once (row-major [64 x 64] fp16) */
    for (int i = tid; i < 64*64; i += blockDim.x)
        sQ[i] = q[(size_t)qrow_base*64 + i];
    /* init m/l/O */
    if (tid < 64) { sm[tid] = -INFINITY; sl[tid] = 0.0f; }
    for (int i = tid; i < 64*64; i += blockDim.x) sO[i] = 0.0f;
    __syncthreads();

    int n_blocks = N/64;
    for (int kb = 0; kb < n_blocks; ++kb) {
        /* load K,V block (row-major [64 keys x 64 d]) */
        for (int i = tid; i < 64*64; i += blockDim.x) {
            sK[i] = k[(size_t)kb*64*64 + i];
            sV[i] = v[(size_t)kb*64*64 + i];
        }
        __syncthreads();

        /* QK^T -> S */
        float acc[32];
        for (int i=0;i<32;++i) acc[i]=0.0f;
        for (int s=0;s<4;++s) mma_kstep(acc, sQb + a_band, sKb + b_band, s, lane, 1);
        for (int i=0;i<32;++i) acc[i] *= scale;
        uint32_t sS_warp = sSb + m_tile*32*256 + n_tile*32*4;
        acc_to_smem(acc, sS_warp, lane, 256, 0);
        __syncthreads();

        /* online softmax over 64x64 S (lanes 0..63 own a row) */
        if (tid < 64) {
            int i = tid;
            float smax = -INFINITY;
            for (int j=0;j<64;++j) smax = fmaxf(smax, sS[i*64+j]);
            float mprev = sm[i];
            float mnew = fmaxf(mprev, smax);
            float c = __expf(mprev - mnew);
            sc[i] = c;
            float rs = 0.0f;
            for (int j=0;j<64;++j) { float p = __expf(sS[i*64+j]-mnew); rs += p; sP[i*64+j]=__float2half(p); }
            sl[i] = sl[i]*c + rs;
            sm[i] = mnew;
        }
        __syncthreads();
        /* rescale O by c */
        for (int idx = tid; idx < 64*64; idx += blockDim.x) sO[idx] *= sc[idx/64];
        __syncthreads();

        /* P.V -> O (accumulate) */
        for (int i=0;i<32;++i) acc[i]=0.0f;
        for (int s=0;s<4;++s) mma_kstep(acc, sPb + a_band, sVb + b_band, s, lane, 0);
        uint32_t sO_warp = sOb + m_tile*32*256 + n_tile*32*4;
        acc_to_smem(acc, sO_warp, lane, 256, 1);
        __syncthreads();
    }

    /* finalize */
    if (tid < 64) {
        int i = tid; int row = qrow_base + i;
        if (row < N) {
            float inv = 1.0f/sl[i];
            for (int e=0;e<64;++e) o[(size_t)row*64+e] = __float2half(sO[i*64+e]*inv);
        }
    }
}

static uint32_t lcg_state = 0x12345678u;
static float lcg_f32(void){ lcg_state=lcg_state*1664525u+1013904223u;
    return ((float)(lcg_state>>8)/(float)(1u<<24))-0.5f; }

int main(int argc, char** argv){
    int N = (argc>1)?atoi(argv[1]):2048;
    int d = 64;
    size_t elems = (size_t)N*d;
    float *hqf=(float*)malloc(elems*4),*hkf=(float*)malloc(elems*4),*hvf=(float*)malloc(elems*4);
    __half *hq=(__half*)malloc(elems*2),*hk=(__half*)malloc(elems*2),*hv=(__half*)malloc(elems*2);
    __half *ho=(__half*)malloc(elems*2);
    double *ref=(double*)malloc(elems*8);
    for(size_t i=0;i<elems;++i){ hq[i]=__float2half(lcg_f32()*4.0f); hqf[i]=__half2float(hq[i]); }
    for(size_t i=0;i<elems;++i){ hk[i]=__float2half(lcg_f32()*4.0f); hkf[i]=__half2float(hk[i]); }
    for(size_t i=0;i<elems;++i){ hv[i]=__float2half(lcg_f32());      hvf[i]=__half2float(hv[i]); }
    float scale = 1.0f/sqrtf((float)d);

    double *srow=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){
        double m=-1e300;
        for(int j=0;j<N;++j){ double s=0; for(int l=0;l<d;++l) s+=(double)hqf[(size_t)i*d+l]*(double)hkf[(size_t)j*d+l];
            s*=(double)scale; srow[j]=s; if(s>m)m=s; }
        double sum=0; for(int j=0;j<N;++j){ srow[j]=exp(srow[j]-m); sum+=srow[j]; }
        double inv=1.0/sum;
        for(int e=0;e<d;++e){ double acc=0; for(int j=0;j<N;++j) acc+=srow[j]*(double)hvf[(size_t)j*d+e];
            ref[(size_t)i*d+e]=acc*inv; }
    }
    free(srow);

    __half *dq,*dk,*dv,*dO;
    CK(cudaMalloc(&dq,elems*2)); CK(cudaMalloc(&dk,elems*2));
    CK(cudaMalloc(&dv,elems*2)); CK(cudaMalloc(&dO,elems*2));
    CK(cudaMemcpy(dq,hq,elems*2,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dk,hk,elems*2,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dv,hv,elems*2,cudaMemcpyHostToDevice));

    size_t smem_bytes = 24576 + 16384 + 8192 + 16384 + 64*3*4;  /* ~67 KB */
    cudaFuncSetAttribute(fa_mma, cudaFuncAttributeMaxDynamicSharedMemorySize, (int)smem_bytes);
    fa_mma<<<N/64, 128, smem_bytes>>>(dq,dk,dv,dO,N,scale);
    CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(ho,dO,elems*2,cudaMemcpyDeviceToHost));

    double max_rel=0,max_abs=0,max_rel_rowscale=0,sse=0,ssref=0;
    double *rowmax=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){ double mx=0; for(int e=0;e<d;++e){ double w=fabs(ref[(size_t)i*d+e]); if(w>mx)mx=w; } rowmax[i]=mx; }
    for(size_t i=0;i<elems;++i){
        double got=(double)__half2float(ho[i]); double want=ref[i];
        double a=fabs(got-want); double r=a/(fabs(want)+1e-6);
        if(a>max_abs)max_abs=a; if(r>max_rel)max_rel=r;
        int row=(int)(i/d); double rr=a/(rowmax[row]+1e-9);
        if(rr>max_rel_rowscale)max_rel_rowscale=rr;
        sse+=a*a; ssref+=want*want;
    }
    double rms_rel=sqrt(sse/(ssref+1e-30));
    printf("MMA-ORACLE N=%d d=%d max_abs=%.6g max_rel_naive=%.6g max_rel_rowscale=%.6g rms_rel=%.6g numeric=%s\n",
        N,d,max_abs,max_rel,max_rel_rowscale,rms_rel,(max_rel_rowscale<=1e-2)?"PASS":"FAIL");
    return (max_rel_rowscale<=1e-2)?0:1;
}
