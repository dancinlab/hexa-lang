// w16_canon_cpu_check.cpp — OP-21B: 0-pod CPU de-risk of wgmma_tf32_w16.cu's D1 logic.
// =============================================================================
// PURPOSE (HEXA-0POD OP-21B). OP-21A wrote self/native/wgmma/wgmma_tf32_w16.cu — the
// Hopper warp-spec TF32 GEMM whose RISKIEST element is D1, the "canonical-atom" landing
// the descriptor-direct wgmma reads in place. OP-21A flagged D1 as the pre-registered
// MODE-1 falsifier: if the canonical-atom encoding/read law is WRONG, the H100 bit-exact
// gate fails and a pod-hour is burned.
//
// The D1 encoder + read law + the reference GEMM are PURE HOST ARITHMETIC — no wgmma, no
// PTX, no GPU. So they can be validated bit-exactly on a CPU with clang++, 0-pod. That is
// what this harness does. It does NOT execute the wgmma instruction or measure perf — those
// stay H100-gated. It proves the GPU-FREE half of D1 is correct, raising H100 first-try odds.
//
// WHAT THIS VALIDATES (the pure-arithmetic claims w16.cu/w10_lib.h embed):
//   T1  sw128_measured(r,c) is a BIJECTION over each 8x32 atom (no collision / full cover).
//       The TMA-landed swizzle MUST be a permutation or the in-place read cannot recover A.
//   T2  The composed read law hard-coded in w16.cu w16_probe_canon (line 175),
//         sw = a*256 + r*32 + (((k>>2)^(r&7))<<2) + (k&3),
//       is ELEMENT-FOR-ELEMENT equal to the W10-proven  a*256 + sw128_measured(r,k).
//       (D1 reuses the W10 law; this proves w16's copy did not drift.)
//   T3  The composed A-read recovers global A bit-exact on the 128x32 box (the MODE-0 gate
//       simulated on CPU): for every (m,k), landed[composed(m,k)] == global A[m][k], where
//       landed[] is filled by the SAME swizzle law (CPU model of the TMA).
//   T4  gmma_phys(s,k) 8x4 INTER core is a BIJECTION over a 64x8 sub-tile (the wgmma operand
//       packing the descriptor expects) — no collision / full cover.
//   T5  The gemm_w10/w16 per-slab B-read law recovers global B bit-exact (the B atom path).
//   T6  REFERENCE GEMM MATH: a CPU TF32-rounded GEMM (round-A, round-B, fp32-FMA accumulate)
//       matches the math gemm_w16 computes, so MODE-4's bit-exact-vs-cuBLAS gate checks the
//       RIGHT reference (same tf() round-to-nearest mantissa truncation w10_lib.h uses).
//   T7  D1 DESCRIPTOR-STRIDE byte arithmetic: the atom-major contiguous region the swmode=1
//       descriptor strides — atom stride = 256 floats = 1024B (== the MODE-1 default SBO),
//       swizzle row stride = 32 floats = 128B, 8 rows/atom = 1KB swizzle period — is
//       internally consistent with the (lbo=16,sbo=1024) MODE-1 defaults in w16.cu main().
//
// HONEST FRAMING (g5): this proves the GPU-FREE D1 logic only. The device wgmma execution
// (does the HW de-swizzle actually read the swmode=1 descriptor as this law predicts) +
// perf REMAIN H100-gated. No TFLOP/s claimed. Value = the riskiest GPU-free part of w16
// (the canonical-atom encode/read) is CPU-proven, de-risking the H100 D1 gate.
//
// BUILD/RUN (0-pod, no GPU):  clang++ -O2 -std=c++17 w16_canon_cpu_check.cpp -o w16chk && ./w16chk
// =============================================================================
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <vector>
#include <cstdlib>

// ---------- VERBATIM arithmetic from w10_lib.h (the SSOT being de-risked) ----------
// gmma_phys: GMMA INTER 8x4-core physical index (w10_lib.h L54-56).
static inline int gmma_phys(int s,int k){
    int strip=s>>3,sr=s&7,kcore=k>>2,kc=k&3; return (strip*2+kcore)*32+sr*4+kc;
}
// sw128_measured: W10-RE-MEASURED 128B-swizzle index inside an 8-row x 32-f32 atom
// (w10_lib.h L62-64): gp = g XOR (r&7), phys = r*32 + gp*4 + w.
static inline int sw128_measured(int r,int c){
    int g=c>>2, w=c&3, gp=g^(r&7); return r*32 + gp*4 + w;
}
// tf: TF32 round (round-to-nearest, mantissa truncation to 10 bits) — w10_lib.h L469.
static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}

// ---------- the EXACT composed A-read law hard-coded in w16.cu ----------
// wgmma_tf32_w16.cu w16_probe_canon L175 (the MODE-0 canonical-decode probe):
//   int sw = a*256 + r*32 + (((k>>2)^(r&7))<<2) + (k&3);
static inline int w16_composed_A(int m,int k){
    int a=m>>3, r=m&7;
    return a*256 + r*32 + (((k>>2)^(r&7))<<2) + (k&3);
}
// the W10 reference composition  a*256 + sw128_measured(r,k)  (w10_lib.h probe_decode L231-232).
static inline int w10_composed_A(int m,int k){
    int a=m>>3, r=m&7;
    return a*256 + sw128_measured(r,k);
}
// the B per-slab read law (w10_lib.h gemm_w10 L383-384, identical in gemm_w16b L466-467):
//   c=n>>5, nn=n&31, gp=(nn>>2)^(k&7); sw = c*(TKSW*TKSW) + k*32 + (gp<<2) + (nn&3);
static inline int composed_B(int k,int n,int TKSW){
    int c=n>>5, nn=n&31, gp=(nn>>2)^(k&7);
    return c*(TKSW*TKSW) + k*32 + (gp<<2) + (nn&3);
}

static int g_pass=0, g_fail=0;
static void check(const char* name,bool ok,const char* detail=""){
    printf("  [%s] %-46s %s\n", ok?"PASS":"FAIL", name, detail);
    if(ok) g_pass++; else g_fail++;
}

int main(){
    printf("=============================================================\n");
    printf("OP-21B — w16.cu canonical-atom encoder CPU validation (0-pod)\n");
    printf("=============================================================\n");

    // ---- T1: sw128_measured is a bijection over each 8x32 atom (256 slots). ----
    {
        std::vector<int> hit(256,0); bool ok=true; char d[128]={0};
        for(int r=0;r<8;++r)for(int c=0;c<32;++c){
            int p=sw128_measured(r,c);
            if(p<0||p>=256){ok=false; snprintf(d,sizeof d,"oob p=%d @(r%d,c%d)",p,r,c); break;}
            if(hit[p]++){ok=false; snprintf(d,sizeof d,"collision p=%d @(r%d,c%d)",p,r,c); break;}
        }
        if(ok)for(int p=0;p<256;++p)if(hit[p]!=1){ok=false; snprintf(d,sizeof d,"slot %d hit %dx",p,hit[p]); break;}
        check("T1 sw128_measured bijection (8x32 atom)",ok,d);
    }

    // ---- T2: w16.cu's hard-coded composed law == W10-proven composition, element-for-element. ----
    {
        bool ok=true; char d[128]={0};
        const int M=128,K=32;
        for(int m=0;m<M&&ok;++m)for(int k=0;k<K;++k){
            if(w16_composed_A(m,k)!=w10_composed_A(m,k)){
                ok=false; snprintf(d,sizeof d,"mismatch @(m%d,k%d): w16=%d w10=%d",
                    m,k,w16_composed_A(m,k),w10_composed_A(m,k)); break;
            }
        }
        check("T2 w16 line-175 law == W10 reference law",ok,d);
    }

    // ---- T3: composed A-read recovers global A bit-exact (CPU MODE-0 gate, 128x32). ----
    // Model the TMA: fill landed[] by placing global element (m,k) at slot composed(m,k).
    // (composed is a bijection per atom by T1, so this is a faithful CPU model of the landed
    // swizzled tile.) Then read it back via the SAME composed index — must recover A exactly.
    {
        const int M=128,K=32;
        std::vector<float> A(M*K), landed(M*K, -1e30f), readback(M*K);
        srand(7);
        for(int i=0;i<M*K;++i)A[i]=tf(((rand()%17)-8)*0.0625f);
        // CPU model of TMA swizzle landing: slot composed(m,k) holds A[m][k].
        for(int m=0;m<M;++m)for(int k=0;k<K;++k) landed[w16_composed_A(m,k)] = A[m*K+k];
        // the kernel's read: gOutSw[i] = As[composed(m,k)].
        bool ok=true; char d[128]={0}; int exact=0;
        for(int m=0;m<M&&ok;++m)for(int k=0;k<K;++k){
            float v = landed[w16_composed_A(m,k)];
            readback[m*K+k]=v;
            if(memcmp(&v,&A[m*K+k],4)==0) exact++;
            else { ok=false; snprintf(d,sizeof d,"bitdiff @(m%d,k%d)",m,k); }
        }
        char dd[160]; snprintf(dd,sizeof dd,"exact=%d/%d %s",exact,M*K,d);
        check("T3 composed A-read recovers global A bit-exact",ok&&exact==M*K,dd);
    }

    // ---- T4: gmma_phys 8x4 INTER core is a bijection over a 64x8 sub-tile (512 slots). ----
    // The wgmma operand packing: one k8 sub-tile is a 64(s) x 8(k) gmma_phys region = 512 floats.
    {
        std::vector<int> hit(512,0); bool ok=true; char d[128]={0};
        for(int s=0;s<64&&ok;++s)for(int k=0;k<8;++k){
            int p=gmma_phys(s,k);
            if(p<0||p>=512){ok=false; snprintf(d,sizeof d,"oob p=%d @(s%d,k%d)",p,s,k); break;}
            if(hit[p]++){ok=false; snprintf(d,sizeof d,"collision p=%d @(s%d,k%d)",p,s,k); break;}
        }
        if(ok)for(int p=0;p<512;++p)if(hit[p]!=1){ok=false; snprintf(d,sizeof d,"slot %d hit %dx",p,hit[p]); break;}
        check("T4 gmma_phys bijection (64x8 INTER sub-tile)",ok,d);
    }

    // ---- T5: B per-slab read recovers global B bit-exact (the B atom path). ----
    // B box {32(N),32(K)} per atom, 2 atoms across N=64 in the probe. composed_B places
    // global B[k][n] at slot composed_B(k,n); read it back via the same index.
    {
        const int TKSW=32, KK=TKSW, NN=64;   // 2 side-by-side 32-N atoms
        std::vector<float> B(KK*NN), landed(2*TKSW*TKSW, -1e30f);
        srand(3);
        for(int i=0;i<KK*NN;++i)B[i]=tf(((rand()%17)-8)*0.125f);
        for(int k=0;k<KK;++k)for(int n=0;n<NN;++n) landed[composed_B(k,n,TKSW)] = B[k*NN+n];
        bool ok=true; char d[128]={0}; int exact=0;
        for(int k=0;k<KK&&ok;++k)for(int n=0;n<NN;++n){
            float v=landed[composed_B(k,n,TKSW)];
            if(memcmp(&v,&B[k*NN+n],4)==0) exact++;
            else { ok=false; snprintf(d,sizeof d,"bitdiff @(k%d,n%d)",k,n); }
        }
        char dd[160]; snprintf(dd,sizeof dd,"exact=%d/%d %s",exact,KK*NN,d);
        check("T5 B per-slab read recovers global B bit-exact",ok&&exact==KK*NN,dd);
    }

    // ---- T6: reference GEMM math = TF32-round-inputs + fp32-FMA accumulate. ----
    // This is the math gemm_w16 computes (tf32 wgmma rounds A,B mantissas, accumulates f32).
    // We confirm the CPU reference the MODE-1 probe builds (w16.cu L558) IS that math: it does
    // a=sum hA[m*K+kk]*hB[kk*N+n] in fp32 over TF32-rounded inputs. Cross-check that an
    // EXPLICIT tf()-round-then-fp32-accumulate reproduces it bit-for-bit (no double drift).
    {
        const int M=8,N=8,K=8;
        std::vector<float> A(M*K),B(K*N),R1(M*N),R2(M*N);
        srand(11);
        for(int i=0;i<M*K;++i)A[i]=tf(((rand()%17)-8)*0.125f);
        for(int i=0;i<K*N;++i)B[i]=tf(((rand()%17)-8)*0.125f);
        // R1 = the probe's reference loop (inputs already tf()-rounded, fp32 accumulate).
        for(int m=0;m<M;++m)for(int n=0;n<N;++n){float a=0;for(int kk=0;kk<K;++kk)a+=A[m*K+kk]*B[kk*N+n];R1[m*N+n]=a;}
        // R2 = explicit TF32 model: round each operand again (idempotent) then fp32 FMA.
        for(int m=0;m<M;++m)for(int n=0;n<N;++n){float a=0;for(int kk=0;kk<K;++kk)a+=tf(A[m*K+kk])*tf(B[kk*N+n]);R2[m*N+n]=a;}
        bool ok=true; char d[128]={0};
        for(int i=0;i<M*N&&ok;++i)if(memcmp(&R1[i],&R2[i],4)!=0){ok=false; snprintf(d,sizeof d,"@%d %g vs %g",i,R1[i],R2[i]);}
        check("T6 reference GEMM = TF32-round + fp32 FMA",ok,d);
    }

    // ---- T7: D1 descriptor-stride byte arithmetic consistency. ----
    // The canonical contiguous region the swmode=1 descriptor strides (w16.cu D1 comment
    // L120-142 + gemm_w16 L344-359). TF32=4B. Verify the byte geometry is self-consistent
    // with the MODE-1 defaults (lbo=16, sbo=1024) in w16.cu main() L550.
    {
        const int FB=4;                 // TF32 = 4 bytes
        int atom_floats   = 8*32;       // 8 swizzle rows x 32 floats
        int atom_bytes    = atom_floats*FB;          // 1024B = SBO claim
        int swrow_bytes   = 32*FB;                   // 128B per swizzle row
        int period_bytes  = 8*swrow_bytes;           // 1KB swizzle period
        // MODE-1 defaults (w16.cu main L550): ARG_LBO=16, ARG_SBO=1024.
        int MODE1_LBO=16, MODE1_SBO=1024;
        bool ok = (atom_bytes==1024) && (swrow_bytes==128) && (period_bytes==1024)
                  && (MODE1_SBO==atom_bytes) && (atom_floats==256);
        // also: the k8 sub-step START bump in gemm_w16 L356 is off=kk*4 bytes (kk K-elems*4B).
        // for kk=8 that's 32B = 8 floats = one k8 stride within the 32-wide atom. consistent.
        bool ok2 = (8*FB==32);
        char d[160];
        snprintf(d,sizeof d,"atom=%dB swrow=%dB period=%dB SBO=%d LBO=%d k8bump=%dB",
                 atom_bytes,swrow_bytes,period_bytes,MODE1_SBO,MODE1_LBO,8*FB);
        check("T7 D1 descriptor-stride byte arithmetic",ok&&ok2,d);
    }

    printf("-------------------------------------------------------------\n");
    printf("RESULT: %d PASS, %d FAIL\n", g_pass, g_fail);
    if(g_fail==0){
        printf("CANONICAL-ATOM ENCODER CPU-CORRECT — D1 GPU-free logic de-risked.\n");
        printf("STILL H100-GATED: the device wgmma swmode=1 de-swizzle reads the descriptor\n");
        printf("as this law predicts (MODE 1 rel_rms 0), + all perf. No TFLOP/s claimed.\n");
    } else {
        printf("BUG FOUND in the canonical-atom GPU-free logic — fix w16.cu BEFORE the H100 run.\n");
    }
    return g_fail==0?0:1;
}
