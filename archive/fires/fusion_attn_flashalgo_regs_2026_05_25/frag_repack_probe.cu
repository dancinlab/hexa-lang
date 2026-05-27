/* R9 frag_repack_probe.cu — empirically verify the accumulator-layout ->
 * matrix_a-operand-layout repack via WARP SHUFFLES (no smem round-trip).
 *
 * Background (R8 #1117 finding, m16n16k16 f32 ACCUMULATOR fragment row map):
 *   elems {0,1,4,5} -> row = lane/4         (group_lo, rows 0..7)
 *   elems {2,3,6,7} -> row = lane/4 + 8      (group_hi, rows 8..15)
 *
 * R9 needs the S=QK^T accumulator (16x16, in regs per lane) to be consumed as
 * a matrix_a (row_major, f16) operand for the P.V mma WITHOUT going through
 * smem. The matrix_a fragment lane->(row,col) distribution is DIFFERENT from
 * the accumulator distribution, so a cross-lane permutation (warp shuffle) is
 * required.
 *
 * STRATEGY (ground-truth both maps, then verify the shuffle):
 *   PART A: tag-store the ACCUMULATOR fragment to smem (row_major) -> read the
 *           per-lane,per-elem (row,col) ground truth (re-confirm R8).
 *   PART B: tag the matrix_a fragment by loading a known row_major matrix
 *           M[r][c] = r*16+c into an A fragment, then each lane prints its
 *           a_frag.x[i] -> tells us (lane,i) -> (row,col) for matrix_a.
 *   PART C: THE REPACK TEST. Build S in accumulator regs holding M[r][c],
 *           repack via shuffle into a_repacked.x[i], load M into a real A
 *           fragment the normal way (load_matrix_sync from smem), and compare
 *           a_repacked.x[i] == a_frag.x[i] for every lane,i. If they match for
 *           all lanes, the shuffle permutation is CORRECT and we can feed the
 *           in-register S directly to mma without smem.
 *
 * The repack derives, per (lane,i) of the matrix_a target, which (row,col) it
 * needs, looks up which (src_lane, src_elem) of the accumulator holds that
 * (row,col), and __shfl_sync's it across.
 *
 * Build: /usr/local/cuda/bin/nvcc -O2 -arch=sm_90a -o frag_repack_probe frag_repack_probe.cu
 * Run on ubu-2 (sm_120 driver runs sm_90a-compiled binary via forward compat,
 *   but for a probe we compile -arch=sm_120 to match the silicon natively).
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <mma.h>
#include <stdio.h>
using namespace nvcuda;

/* --- ground-truth the ACCUMULATOR map: smem store, inspect --- */
__global__ void probe_acc() {
    __shared__ float s[16*16];
    int lane = threadIdx.x & 31;
    wmma::fragment<wmma::accumulator,16,16,16,float> f;
    for (int i = 0; i < f.num_elements; ++i) f.x[i] = (float)(lane*16 + i);
    wmma::store_matrix_sync(s, f, 16, wmma::mem_row_major);
    __syncwarp();
    if (lane == 0) {
        printf("=== ACC map: smem[row*16+col] = lane*16+elem ===\n");
        for (int r = 0; r < 16; ++r) {
            for (int c = 0; c < 16; ++c) {
                int tag=(int)s[r*16+c]; printf("%d.%d ", tag/16, tag%16);
            }
            printf("\n");
        }
    }
}

/* --- ground-truth the MATRIX_A map: load known M, dump per-lane regs --- */
__global__ void probe_a() {
    __shared__ __half m[16*16];
    int lane = threadIdx.x & 31;
    for (int idx = lane; idx < 256; idx += 32) m[idx] = __float2half((float)idx); // M[r][c]=r*16+c
    __syncwarp();
    wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> a;
    wmma::load_matrix_sync(a, m, 16);
    // print, lane-serialized, each lane's a.x[i] (= the (row,col) tag r*16+c)
    for (int L = 0; L < 32; ++L) {
        if (lane == L) {
            printf("A lane %2d:", L);
            for (int i = 0; i < a.num_elements; ++i) {
                int tag=(int)__half2float(a.x[i]); printf(" e%d=(%d,%d)", i, tag/16, tag%16);
            }
            printf("  (num_elements=%d)\n", a.num_elements);
        }
        __syncwarp();
    }
}

/* ============================================================
 * PART C: the repack test, parameterized by the two maps we
 * determined in A and B. We encode the maps as device functions.
 * ============================================================ */

/* ACC: given (lane,elem) -> (row,col).  (R8 finding + col from store.)
 * From R8: row(elem in {0,1,4,5}) = lane/4 ; row(elem in {2,3,6,7}) = lane/4+8.
 * Column for the m16n16k16 acc row_major store: standard map is
 *   col = (lane%4)*2 + (elem & 1) + ((elem/4)? ... )  -- we will READ the truth
 * from PART A's printout and hard-code below after first run. For the initial
 * authoring we encode the textbook map and let PART A confirm/correct it.
 */
__device__ void acc_rc(int lane, int elem, int* row, int* col) {
    int g = lane >> 2;                 // 0..7
    *row = (elem==0||elem==1||elem==4||elem==5) ? g : g+8;
    // textbook col: pairs (0,1)/(2,3) low cols, (4,5)/(6,7) high cols
    int lo = (lane & 3) * 2;           // 0,2,4,6
    int col_in_pair = elem & 1;        // 0/1
    int high = (elem >= 4) ? 8 : 0;    // elems 4..7 -> +8 cols
    *col = lo + col_in_pair + high;
}

/* MATRIX_A row_major map: given (lane,elem) -> (row,col).
 * Standard m16n16k16 f16 matrix_a (16 elems/lane on sm_70..sm_90 the frag has
 * 16 elements; on these GPUs num_elements may be 16). We READ truth from PART
 * B and hard-code; the textbook 16-element layout is two 8x16 halves. We fill
 * this in after PART B printout. For authoring, leave a placeholder that PART
 * C cross-checks against the real load_matrix_sync.
 */

int main(int argc, char** argv) {
    int part = (argc>1)?atoi(argv[1]):0;
    if (part==0 || part==1) { probe_acc<<<1,32>>>(); cudaDeviceSynchronize(); }
    if (part==0 || part==2) { probe_a<<<1,32>>>(); cudaDeviceSynchronize(); }
    cudaError_t e=cudaGetLastError();
    if(e!=cudaSuccess){printf("CUDA err: %s\n",cudaGetErrorString(e));return 1;}
    return 0;
}
