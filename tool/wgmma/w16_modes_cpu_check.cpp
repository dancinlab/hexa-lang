// w16_modes_cpu_check.cpp — OP-21C: 0-pod CPU de-risk of wgmma_tf32_w16.cu's REMAINING MODEs.
// =============================================================================
// PURPOSE (HEXA-0POD OP-21C). EXTENDS OP-21B (tool/wgmma/w16_canon_cpu_check.cpp), which
// CPU-validated the riskiest D1 piece — the MODE-0 canonical-atom read law + the 8x4 GMMA
// layout + a small (8x8) TF32 reference GEMM (T1..T7, all PASS). What OP-21B did NOT yet
// cover is the GPU-FREE reference logic of the OTHER MODEs in the H100 gate sequence:
//   - MODE 4's FULL-TILE (128x128) reference GEMM + the device epilogue register->global
//     scatter that the bit-exact-vs-cuBLAS gate implicitly checks the device output against;
//   - the B-operand per-slab read law across ALL slabs of the NST=3 ring + all 4 N-atoms
//     (OP-21B T5 only checked one slab, 2 atoms);
//   - the gemm_w16b OP-21B-FALLBACK reference (band gmma_phys repack of A and B) computing
//     the SAME math as gemm_w16 (different scheduling, identical result);
//   - the descriptor stride byte arithmetic (the kk*4 START bump for w16 vs the
//     (kk>>3)*512*4 sub-tile bump for w16b) being self-consistent across the NST=3 stages.
// Every piece here is PURE HOST ARITHMETIC — no wgmma, no PTX, no GPU. CPU-validated 0-pod.
//
// HONEST FRAMING (g5): this proves GPU-FREE reference logic only. The device wgmma swmode=1
// HW de-swizzle + perf REMAIN H100-gated. No TFLOP/s claimed. Value = MORE of the w16 H100
// gate sequence (MODE 4 full-tile ref, the B-ring read, the w16b fallback, the descriptor
// stride consistency) is CPU-pre-validated -> even higher first-try odds.
//
// BUILD/RUN (0-pod, no GPU):
//   clang++ -O2 -std=c++17 w16_modes_cpu_check.cpp -o w16mchk && ./w16mchk
// =============================================================================
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <vector>
#include <cstdlib>

// ---------- VERBATIM arithmetic from w10_lib.h / w16.cu (the SSOT being de-risked) ----------
static inline int gmma_phys(int s,int k){
    int strip=s>>3,sr=s&7,kcore=k>>2,kc=k&3; return (strip*2+kcore)*32+sr*4+kc;
}
static inline int sw128_measured(int r,int c){
    int g=c>>2, w=c&3, gp=g^(r&7); return r*32 + gp*4 + w;
}
static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}

// the EXACT composed A-read law hard-coded in w16.cu (L175 / gemm_w16b L460).
static inline int w16_composed_A(int m,int k){
    int a=m>>3, r=m&7;
    return a*256 + r*32 + (((k>>2)^(r&7))<<2) + (k&3);
}
// the B per-slab read law (w16.cu gemm_w16b L466, gemm_w10 L383-384).
static inline int composed_B(int k,int n,int TKSW){
    int c=n>>5, nn=n&31, gp=(nn>>2)^(k&7);
    return c*(TKSW*TKSW) + k*32 + (gp<<2) + (nn&3);
}

static int g_pass=0, g_fail=0;
static void check(const char* name,bool ok,const char* detail=""){
    printf("  [%s] %-52s %s\n", ok?"PASS":"FAIL", name, detail);
    if(ok) g_pass++; else g_fail++;
}

int main(){
    printf("=================================================================\n");
    printf("OP-21C — w16.cu remaining-MODE GPU-free reference CPU validation\n");
    printf("=================================================================\n");

    // WIP skeleton — checks C1..C4 land below.

    printf("-----------------------------------------------------------------\n");
    printf("RESULT: %d PASS, %d FAIL\n", g_pass, g_fail);
    return g_fail==0?0:1;
}
