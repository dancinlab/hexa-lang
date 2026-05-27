/* R9 PART C — definitive in-register repack test.
 *
 * HYPOTHESIS (from PART A + PART B ground truth on sm_120):
 *   The m16n16k16 f32 ACCUMULATOR per-lane (elem -> (row,col)) map is
 *   IDENTICAL to the m16n16k16 f16 MATRIX_A per-lane map (matrix_a just
 *   duplicates elems 0..7 into 8..15). Therefore the accumulator->operand
 *   repack is the LOCAL (no cross-lane) move:
 *       a.x[i] = a.x[i+8] = (half)acc.x[i]   for i in 0..7
 *   i.e. each lane already holds exactly the scores it needs as a matrix_a
 *   operand. NO warp shuffle is required.
 *
 * This test computes S = Q.K^T (wmma, f32 acc), then forms P = exp(S - rowmax)
 * with the row reductions done via WARP SHUFFLE on the in-register accumulator
 * (the R9 softmax path), repacks P into a matrix_a fragment via the local move,
 * does P.V (wmma) and compares to a SMEM-ROUNDTRIP reference (store P to smem,
 * load_matrix_sync) for the SAME P. If the two O's match bitwise-ish, the
 * register path is proven equivalent to R8's smem path -> correctness gate PASS.
 *
 * Build: nvcc -O2 -arch=sm_120 -o frag_repack_partc frag_repack_partc.cu
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <mma.h>
#include <stdio.h>
#include <math.h>
using namespace nvcuda;

/* row of an m16n16k16 f32 accumulator element, per the empirical map. */
__device__ __forceinline__ int acc_row(int lane, int e) {
    int g = lane >> 2;
    return (e==0||e==1||e==4||e==5) ? g : g+8;
}

/* Warp-shuffle row max/sum over the accumulator S fragment.
 * Each row r is held by the 4 lanes {L : L/4 == (r&7)} — specifically:
 *   rows 0..7 : lanes 0..31 with L/4==r, elems {0,1,4,5}
 *   rows 8..15: lanes 0..31 with L/4==(r-8), elems {2,3,6,7}
 * A row's 16 columns are spread across 4 lanes x 4 elems. So per row we reduce
 * 4 elems locally then a 4-lane shuffle (stride 1,2 within the group of 4).
 */
extern "C" __global__ void partc(const __half* q, const __half* k, const __half* v,
                                 float* o_reg, float* o_smem, int N, float scale) {
    __shared__ float s_dbg[16*16];
    __shared__ __half p_smem[16*16];
    int lane = threadIdx.x & 31;

    // S = Q.K^T over d=64
    wmma::fragment<wmma::accumulator,16,16,16,float> s_frag;
    wmma::fill_fragment(s_frag, 0.0f);
    #pragma unroll
    for (int kk=0; kk<4; ++kk) {
        wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> a;
        wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> b;
        wmma::load_matrix_sync(a, q + kk*16, 64);
        wmma::load_matrix_sync(b, k + kk*16, 64);
        wmma::mma_sync(s_frag, a, b, s_frag);
    }
    #pragma unroll
    for (int i=0;i<s_frag.num_elements;++i) s_frag.x[i] *= scale;

    /* ---- ROW MAX via warp shuffle (in regs) ---- */
    // local max over this lane's elems for the two rows it touches
    float m_lo = fmaxf(fmaxf(s_frag.x[0],s_frag.x[1]), fmaxf(s_frag.x[4],s_frag.x[5])); // row group_lo
    float m_hi = fmaxf(fmaxf(s_frag.x[2],s_frag.x[3]), fmaxf(s_frag.x[6],s_frag.x[7])); // row group_hi
    // reduce across the 4 lanes that share the row (lanes L, L^1, L^2, L^3 within group of 4)
    for (int off=1; off<4; off<<=1) {
        m_lo = fmaxf(m_lo, __shfl_xor_sync(0xffffffffu, m_lo, off));
        m_hi = fmaxf(m_hi, __shfl_xor_sync(0xffffffffu, m_hi, off));
    }
    // m_lo is now the max of row (lane/4); m_hi of row (lane/4 + 8)

    /* ---- P = exp(S - m), and ROW SUM via warp shuffle ---- */
    float p[8];
    p[0]=__expf(s_frag.x[0]-m_lo); p[1]=__expf(s_frag.x[1]-m_lo);
    p[4]=__expf(s_frag.x[4]-m_lo); p[5]=__expf(s_frag.x[5]-m_lo);
    p[2]=__expf(s_frag.x[2]-m_hi); p[3]=__expf(s_frag.x[3]-m_hi);
    p[6]=__expf(s_frag.x[6]-m_hi); p[7]=__expf(s_frag.x[7]-m_hi);
    float l_lo = p[0]+p[1]+p[4]+p[5];
    float l_hi = p[2]+p[3]+p[6]+p[7];
    for (int off=1; off<4; off<<=1) {
        l_lo += __shfl_xor_sync(0xffffffffu, l_lo, off);
        l_hi += __shfl_xor_sync(0xffffffffu, l_hi, off);
    }
    // normalize P by row sum (so O = P_norm . V directly)
    float il_lo = 1.0f/l_lo, il_hi = 1.0f/l_hi;
    p[0]*=il_lo;p[1]*=il_lo;p[4]*=il_lo;p[5]*=il_lo;
    p[2]*=il_hi;p[3]*=il_hi;p[6]*=il_hi;p[7]*=il_hi;

    /* ===== PATH 1 (R9): repack P into matrix_a regs via the LOCAL move ===== */
    wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa_reg;
    #pragma unroll
    for (int i=0;i<8;++i) { pa_reg.x[i] = __float2half(p[i]); pa_reg.x[i+8] = __float2half(p[i]); }

    wmma::fragment<wmma::accumulator,16,16,16,float> o_r;
    wmma::fill_fragment(o_r, 0.0f);
    {
        wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vb;
        wmma::load_matrix_sync(vb, v, 64);          // first 16 cols of V (d-tile 0)
        wmma::mma_sync(o_r, pa_reg, vb, o_r);
    }
    wmma::store_matrix_sync(o_reg, o_r, 16, wmma::mem_row_major);

    /* ===== PATH 2 (R8 reference): P -> smem -> load_matrix_sync ===== */
    // write P (same values) to smem via the acc store, then reload as matrix_a
    wmma::fragment<wmma::accumulator,16,16,16,float> p_acc;
    p_acc.x[0]=p[0];p_acc.x[1]=p[1];p_acc.x[2]=p[2];p_acc.x[3]=p[3];
    p_acc.x[4]=p[4];p_acc.x[5]=p[5];p_acc.x[6]=p[6];p_acc.x[7]=p[7];
    wmma::store_matrix_sync(s_dbg, p_acc, 16, wmma::mem_row_major);
    __syncwarp();
    for (int idx=lane; idx<256; idx+=32) p_smem[idx] = __float2half(s_dbg[idx]);
    __syncwarp();
    wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa_sm;
    wmma::load_matrix_sync(pa_sm, p_smem, 16);
    wmma::fragment<wmma::accumulator,16,16,16,float> o_s;
    wmma::fill_fragment(o_s, 0.0f);
    {
        wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vb;
        wmma::load_matrix_sync(vb, v, 64);
        wmma::mma_sync(o_s, pa_sm, vb, o_s);
    }
    wmma::store_matrix_sync(o_smem, o_s, 16, wmma::mem_row_major);
}

int main() {
    int N=16, d=64;
    size_t qe=(size_t)N*d;
    __half *hq=(__half*)malloc(qe*2),*hk=(__half*)malloc(qe*2),*hv=(__half*)malloc(qe*2);
    unsigned st=0x12345678u;
    auto rnd=[&](){ st=st*1664525u+1013904223u; return ((float)(st>>8)/(float)(1<<24))-0.5f; };
    for(size_t i=0;i<qe;++i) hq[i]=__float2half(rnd()*4.0f);
    for(size_t i=0;i<qe;++i) hk[i]=__float2half(rnd()*4.0f);
    for(size_t i=0;i<qe;++i) hv[i]=__float2half(rnd());
    float scale=1.0f/sqrtf((float)d);
    __half *dq,*dk,*dv; float *dor,*dos;
    cudaMalloc(&dq,qe*2);cudaMalloc(&dk,qe*2);cudaMalloc(&dv,qe*2);
    cudaMalloc(&dor,16*16*4);cudaMalloc(&dos,16*16*4);
    cudaMemcpy(dq,hq,qe*2,cudaMemcpyHostToDevice);
    cudaMemcpy(dk,hk,qe*2,cudaMemcpyHostToDevice);
    cudaMemcpy(dv,hv,qe*2,cudaMemcpyHostToDevice);
    partc<<<1,32>>>(dq,dk,dv,dor,dos,N,scale);
    cudaError_t e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){printf("CUDA: %s\n",cudaGetErrorString(e));return 1;}
    float hor[256],hos[256];
    cudaMemcpy(hor,dor,256*4,cudaMemcpyDeviceToHost);
    cudaMemcpy(hos,dos,256*4,cudaMemcpyDeviceToHost);
    double maxd=0; for(int i=0;i<256;++i){ double diff=fabs((double)hor[i]-(double)hos[i]); if(diff>maxd)maxd=diff; }
    printf("PART C repack test: max|O_reg - O_smem| = %.6g over the 16x16 first-d-tile O\n", maxd);
    printf("repack_correct = %s  (gate: identical wmma result from reg-repack vs smem-roundtrip)\n",
           (maxd < 1e-3) ? "PASS" : "FAIL");
    // sample
    printf("O_reg[0..4]=%.5f %.5f %.5f %.5f\n", hor[0],hor[1],hor[2],hor[3]);
    printf("O_smem[0..4]=%.5f %.5f %.5f %.5f\n", hos[0],hos[1],hos[2],hos[3]);
    return (maxd<1e-3)?0:1;
}
