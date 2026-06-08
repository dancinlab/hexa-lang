// wgmma_tf32_bench11.cu — BENCH-11: warp-specialized TMA producer/consumer pipeline on
// top of the W10 composed-swizzle-decode TF32 wgmma own-GEMM (no-library, no-LLVM,
// bit-exact). The LAST unbeaten axis: W10 own-GEMM is ~70.7 TFLOP/s @2048, 6.09x off
// cuBLAS-TF32. The W-ladder (W1-15) plateaued at 6.09x. The known UNEXHAUSTED residual
// lever (per project_hexa_fusion_sm90_wgmma_bitcorrect) = a FULLER warp-specialized TMA
// producer/consumer pipeline: a DEDICATED TMA-load + decode warpgroup feeding wgmma
// CONSUMER warpgroup(s) through DEEP smem multi-buffering with mbarrier sync — the
// canonical CUTLASS/cuBLAS Hopper GEMM structure that W10's simpler K-loop lacks.
//
// W10 (MODE4 gemm_w10) baseline structure (the thing we improve on):
//   - tid==0 issues TMA (cp.async.bulk.tensor) into an NST-deep SWIZZLED ring.
//   - ALL 256 threads then, per K-slab: mbar_wait(full) -> swizzle->gmma DECODE into a
//     SINGLE (non-ring) gmma scratch -> __syncthreads -> wgmma -> __syncthreads.
//   The decode and the wgmma are SERIAL per slab (one shared gmma band, full barrier
//   between decode and next slab's decode). The TMA ring overlaps GLOBAL load, but the
//   DECODE (smem->smem permute) and the wgmma do NOT overlap each other, and the consumer
//   warpgroups stall on the producer's decode each slab.
//
// BENCH-11 kernel gemm_b11 (MODE 6) — TRUE warp specialization:
//   256 threads = 2 warpgroups. WG0 = PRODUCER, WG1 = CONSUMER.
//   * PRODUCER (WG0, tid 0..127): runs the K-loop AHEAD. For slab ki it (a) ensures the
//     swizzled TMA tile for ki is landed (issues TMA SWST ahead via tid0 into the swizzle
//     ring), (b) does the COMPOSED swizzle->gmma DECODE (VERBATIM from W10, bit-exact)
//     into a RING of NGM gmma-band buffers, (c) fence.proxy.async + arrive(gready[gst]) to
//     release the consumer. Before reusing a gmma slot it waits gdone[gst].
//   * CONSUMER (WG1, tid 128..255): for slab ki, wait gready[gst]; run the 4 wgmma k8
//     sub-steps (VERBATIM from W10) over the ring gmma band; arrive(gdone[gst]).
//   Overlap: producer DECODES slab ki+1 (smem permute, no tensor cores) WHILE consumer
//   WGMMAs slab ki (tensor cores, no smem permute). The decode latency the W10 single
//   shared band serialized is now HIDDEN behind the consumer's wgmma. Deeper NGM = slack.
//
//   This is the W7 (dual-consumer-WG, CLOSED-NEG #2838) geometry's sibling but with the
//   correct decoupling axis: W7 split the CONSUMER and found no lift because the wall was
//   the DECODE serialization, not consumer count. gemm_b11 dedicates a WG to
//   producer+decode and ring-stages the DECODED band so decode overlaps wgmma. HONEST: if
//   this ALSO plateaus, that pins own-GEMM>cuBLAS as the irreducible no-LLVM-purity
//   frontier (a legitimate terminal closed-neg, NOT fake).
//
// GATE (g5): bit-exact rel_rms vs cuBLAS-TF32 ref (<=3e-3, ideally 0 vs the proven W10
// numerics) FIRST, perf (TFLOP/s + cuBLAS-multiple) only after. cuBLAS = ROOFLINE.
// argv: S MODE[=6] [NSW=4] [NGM=3]
//
// We #include the W10 lib VERBATIM (W10_NO_MAIN) to reuse gmma_phys / mk / WG / tf /
// the TMA+mbar helpers / get_enc — the bit-exact primitives are NOT re-derived here.
#define W10_NO_MAIN
#include "wgmma_tf32_w10_lib.h"

// plain mbarrier arrive (the W10 lib has init_tx/expect_tx/wait; the producer/consumer
// handshake on the DECODED gmma ring needs a count-1 arrive on both sides).
__device__ __forceinline__ void mbar_arrive_b11(uint64_t* b){
    uint32_t s=(uint32_t)__cvta_generic_to_shared(b);
    asm volatile("mbarrier.arrive.shared::cta.b64 _, [%0];\n"::"r"(s));
}

// ======================================================================
// MODE 6 — gemm_b11: warp-specialized TMA-producer + ring-staged-decode pipeline.
//   Tiling identical to W10 (TM=128,TN=128,TKSW=32): bit-exactness inherited.
//   TODO(WIP skeleton): full warp-specialized body lands in the GPU build session.
//   Skeleton compiles + wires the harness so the storm can push WIP first.
// ======================================================================
extern "C" __global__ void gemm_b11(const __grid_constant__ CUtensorMap tmapA,
                                     const __grid_constant__ CUtensorMap tmapB,
                                     float* __restrict__ gD,int M,int N,int K,
                                     int NSW,int NGM){
    const int TM=128,TN=128,TKSW=32;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN; (void)bm;(void)bn;(void)NSW;(void)NGM;
    (void)tmapA;(void)tmapB;(void)gD;(void)M;(void)N;(void)K;(void)TM;(void)TN;(void)TKSW;
    // placeholder body (no-op) — real warp-specialized impl in build session.
}

#ifndef BENCH11_NO_MAIN
int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):2048; int MODE=argc>2?atoi(argv[2]):6;
    int NSW=argc>3?atoi(argv[3]):4; int NGM=argc>4?atoi(argv[4]):3;
    Enc_t enc=get_enc();
    if(!enc){printf("cuTensorMapEncodeTiled unavailable (CUDA<12?)\n");return 4;}
    if(MODE!=6){printf("BENCH-11 driver only implements MODE 6 (gemm_b11). got %d\n",MODE);return 1;}
    // TODO(WIP): MODE 6 host harness lands in the build session.
    printf("BENCH-11 WIP skeleton: S=%d MODE=%d NSW=%d NGM=%d (host harness pending)\n",
           S,MODE,NSW,NGM);
    return 0;
}
#endif
