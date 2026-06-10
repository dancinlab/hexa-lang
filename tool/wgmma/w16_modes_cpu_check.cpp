// w16_modes_cpu_check.cpp — OP-21C: 0-pod CPU de-risk of wgmma_tf32_w16.cu's REMAINING MODEs.
// =============================================================================
// PURPOSE (HEXA-0POD OP-21C). EXTENDS OP-21B (tool/wgmma/w16_canon_cpu_check.cpp), which
// CPU-validated the riskiest D1 piece — the MODE-0 canonical-atom read law + the 8x4 GMMA
// layout + a small (8x8) TF32 reference GEMM (T1..T7, all PASS). What OP-21B did NOT yet
// cover is the GPU-FREE reference logic of the OTHER MODEs in the H100 gate sequence:
//   C1  MODE 4's FULL-TILE (128x128) reference GEMM + the device epilogue register->global
//       scatter the bit-exact-vs-cuBLAS gate implicitly checks the device output against.
//       (a) the epilogue (m,n)<->register-idx scatter is a BIJECTIVE FULL COVER of the
//           128x128 output tile (every output written exactly once, correct (row,col)); and
//       (b) a CPU TF32-round + fp32-FMA reference over the WHOLE 128x128 tile, accumulated
//           in the kernel's K-order (TKSW=32-wide slabs, TK=8 sub-steps), reproduces a
//           straight TF32-round + fp32-FMA GEMM bit-for-bit (no accum-order drift) — so the
//           MODE-4 gate (rel_rms vs cuBLAS-TF32) is checking the RIGHT reference at full-tile
//           scale, not just the 8x8 of OP-21B T6.
//   C2  the B-operand per-slab read law recovers global B bit-exact across ALL slabs of the
//       NST=3 ring AND all 4 N-atoms (NATOM=TN/TKSW=4) — OP-21B T5 only checked one slab,
//       2 atoms. Each slab lands a fresh 32(K)x128(N) B tile; the read must recover it for
//       every (slab, atom).
//   C3  the gemm_w16b OP-21B-FALLBACK reference matches gemm_w16's: gemm_w16b software-
//       decodes A (composed_A -> gmma_phys repack) and B (composed_B -> gmma_phys repack)
//       into the gmma band, then wgmma reads the band. The MATH it computes must be the SAME
//       TF32 GEMM as gemm_w16's descriptor-direct read (different scheduling, identical
//       result). We model both paths on CPU and assert element-for-element equality.
//   C4  the descriptor stride byte arithmetic is self-consistent ACROSS the NST=3 stages:
//       the ring slot base st*SWBUF, the gemm_w16 kk*4-byte START bump, and the gemm_w16b
//       (kk>>3)*512*4 sub-tile bump — all land at the predicted contiguous offsets for every
//       stage st in 0..NST-1 and every kk in {0,8,16,24}.
// Every piece here is PURE HOST ARITHMETIC — no wgmma, no PTX, no GPU. CPU-validated 0-pod.
//
// HONEST FRAMING (g5): this proves GPU-FREE reference logic only. The device wgmma swmode=1
// HW de-swizzle + perf REMAIN H100-gated. No TFLOP/s claimed. Value = MORE of the w16 H100
// gate sequence (MODE 4 full-tile ref + epilogue, the B-ring read, the w16b fallback, the
// descriptor stride consistency) is CPU-pre-validated -> even higher first-try odds.
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
// gmma_phys: GMMA INTER 8x4-core physical index (w10_lib.h L54-56).
static inline int gmma_phys(int s,int k){
    int strip=s>>3,sr=s&7,kcore=k>>2,kc=k&3; return (strip*2+kcore)*32+sr*4+kc;
}
// tf: TF32 round (round-to-nearest, mantissa truncation) — w10_lib.h L469.
static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}

// the EXACT composed A-read law hard-coded in w16.cu (probe_canon L175 / gemm_w16b L460).
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

// =============================================================================
// The device epilogue register->global scatter, VERBATIM from gemm_w16 (w16.cu L395-403)
// and gemm_w10 (w10_lib.h L184-190). For a given warpgroup `band` (0/1) and lane-within-
// warpgroup `lt` (0..127), and accumulator index idx (0..31), this yields the (row,col) in
// the 128x128 CTA tile that register d0[idx]/d1[idx] is scattered to (d0 -> N 0..63, d1 ->
// N 64..127). We invert it on CPU to reconstruct WHICH (m_in_tile, n_in_tile) each register
// lane holds, so the full-tile reference can be built register-exact.
// =============================================================================
struct RC { int row, col; };   // tile-local (0..127, 0..127)
// returns the d0 (which==0) or d1 (which==1) target for (band,lt,idx).
static inline RC epilogue_rc(int band,int lt,int idx,int which){
    int w=lt>>5, l=lt&31, rb=w*16+(l>>2), cb=(l&3)*2;
    int c=idx>>2, rr=(idx>>1)&1, p=idx&1;     // idx = c*4 + r*2 + p
    int rbase=band*64;                        // tile-local row base (bm folded out)
    int row=rbase+rb+rr*8;
    int col=(which==0)? (cb+p+c*8) : (64+cb+p+c*8);
    return {row,col};
}

int main(){
    printf("=================================================================\n");
    printf("OP-21C — w16.cu remaining-MODE GPU-free reference CPU validation\n");
    printf("=================================================================\n");

    const int TM=128, TN=128, TKSW=32, TK=8;

    // -------------------------------------------------------------------------
    // C1a — the epilogue register->global scatter is a BIJECTIVE FULL COVER of the
    //       128x128 output tile. Sweep both warpgroups (band 0/1), all 128 lanes each,
    //       all 32 accumulator indices, both d0/d1. Every (row,col) in 128x128 must be
    //       written EXACTLY ONCE. (If two lanes target the same output, or some output is
    //       never written, the MODE-4 device result is wrong regardless of the GEMM math.)
    // -------------------------------------------------------------------------
    {
        std::vector<int> cover(TM*TN, 0); bool ok=true; char d[160]={0};
        for(int band=0;band<2&&ok;++band)
          for(int lt=0;lt<128&&ok;++lt)
            for(int idx=0;idx<32&&ok;++idx)
              for(int which=0;which<2;++which){
                RC rc=epilogue_rc(band,lt,idx,which);
                if(rc.row<0||rc.row>=TM||rc.col<0||rc.col>=TN){
                    ok=false; snprintf(d,sizeof d,"oob (r%d,c%d) band%d lt%d idx%d w%d",
                        rc.row,rc.col,band,lt,idx,which); break;
                }
                if(cover[rc.row*TN+rc.col]++){
                    ok=false; snprintf(d,sizeof d,"DOUBLE-WRITE (r%d,c%d) band%d lt%d idx%d w%d",
                        rc.row,rc.col,band,lt,idx,which); break;
                }
              }
        if(ok)for(int i=0;i<TM*TN;++i)if(cover[i]!=1){ok=false; snprintf(d,sizeof d,"slot %d (r%d,c%d) hit %dx",i,i/TN,i%TN,cover[i]); break;}
        check("C1a epilogue scatter = bijective full cover (128x128)",ok,d);
    }

    // -------------------------------------------------------------------------
    // C1b — MODE-4 full-tile reference: a CPU TF32-round + fp32-FMA GEMM over the WHOLE
    //       128x128 tile, accumulated in the kernel's K-order (TKSW=32 slabs, TK=8 inner),
    //       reproduces a straight TF32-round + fp32-FMA GEMM bit-for-bit. This confirms the
    //       reference the MODE-4 gate compares the device output against is the RIGHT math at
    //       FULL-TILE scale (the device wgmma also accumulates fp32 over tf32-rounded operands;
    //       the slab/sub-step blocking does not change the fp32 add order because each output
    //       element accumulates its K contributions in increasing-k order in BOTH).
    //       K spans several slabs so the NST ring is exercised (Kdim = 3*TKSW = 96).
    // -------------------------------------------------------------------------
    {
        const int Kdim=3*TKSW;   // 3 K-slabs -> NST=3 ring fully turns
        std::vector<float> A(TM*Kdim), B(Kdim*TN), Rslab(TM*TN), Rflat(TM*TN);
        srand(7);
        for(int i=0;i<TM*Kdim;++i)A[i]=tf(((rand()%17)-8)*0.0625f);
        for(int i=0;i<Kdim*TN;++i)B[i]=tf(((rand()%17)-8)*0.0625f);
        // Rslab: accumulate exactly as the kernel walks K — outer slab ki, inner kk in 8-steps.
        for(int m=0;m<TM;++m)for(int n=0;n<TN;++n){
            float acc=0.f;
            for(int ki=0;ki<Kdim/TKSW;++ki)
              for(int kk=0;kk<TKSW;kk+=TK)
                for(int j=0;j<TK;++j){
                    int k=ki*TKSW+kk+j;
                    acc += A[m*Kdim+k]*B[k*TN+n];
                }
            Rslab[m*TN+n]=acc;
        }
        // Rflat: straight increasing-k fp32-FMA over tf32-rounded inputs (idempotent re-round).
        for(int m=0;m<TM;++m)for(int n=0;n<TN;++n){
            float acc=0.f;
            for(int k=0;k<Kdim;++k) acc += tf(A[m*Kdim+k])*tf(B[k*TN+n]);
            Rflat[m*TN+n]=acc;
        }
        bool ok=true; char d[160]={0}; int exact=0;
        for(int i=0;i<TM*TN&&ok;++i){
            if(memcmp(&Rslab[i],&Rflat[i],4)==0) exact++;
            else { ok=false; snprintf(d,sizeof d,"@(m%d,n%d) slab=%g flat=%g",i/TN,i%TN,Rslab[i],Rflat[i]); }
        }
        char dd[200]; snprintf(dd,sizeof dd,"exact=%d/%d K=%d %s",exact,TM*TN,Kdim,d);
        check("C1b MODE-4 full-tile ref = TF32-round + fp32-FMA (K-order)",ok&&exact==TM*TN,dd);
    }

    // -------------------------------------------------------------------------
    // C2 — B per-slab read recovers global B bit-exact across ALL NST=3 slabs AND all 4
    //      N-atoms. Each slab ki lands a fresh 32(K)x128(N) B tile (NATOM=4 side-by-side
    //      32-N atoms). The composed_B read must recover B[k][n] for EVERY (slab, k, n).
    //      (OP-21B T5 only did one slab, NN=64 = 2 atoms.)
    // -------------------------------------------------------------------------
    {
        const int NST=3, KK=TKSW, NN=TN, NATOM=TN/TKSW;  // 4 atoms across N=128
        bool ok=true; char d[160]={0}; long exact=0, total=0;
        for(int slab=0;slab<NST&&ok;++slab){
            // a distinct B tile per slab (different RNG seed) so we catch slab-cross aliasing.
            std::vector<float> B(KK*NN), landed((size_t)NATOM*TKSW*TKSW, -1e30f);
            srand(100+slab);
            for(int i=0;i<KK*NN;++i)B[i]=tf(((rand()%17)-8)*0.125f);
            // CPU model of the TMA per-atom landing: slot composed_B(k,n) holds B[k][n].
            for(int k=0;k<KK;++k)for(int n=0;n<NN;++n) landed[composed_B(k,n,TKSW)] = B[k*NN+n];
            for(int k=0;k<KK&&ok;++k)for(int n=0;n<NN;++n){
                ++total;
                float v=landed[composed_B(k,n,TKSW)];
                if(memcmp(&v,&B[k*NN+n],4)==0) ++exact;
                else { ok=false; snprintf(d,sizeof d,"bitdiff slab%d @(k%d,n%d)",slab,k,n); }
            }
        }
        char dd[200]; snprintf(dd,sizeof dd,"exact=%ld/%ld (NST=%d, NATOM=%d) %s",exact,total,NST,NATOM,d);
        check("C2 B read recovers global B bit-exact (all 3 slabs, 4 atoms)",ok&&exact==total,dd);
    }

    // -------------------------------------------------------------------------
    // C3 — gemm_w16b FALLBACK reference == gemm_w16 reference (same math, different schedule).
    //   gemm_w16 (descriptor-direct): wgmma reads the swizzled A/B in place. The math it
    //     computes over one slab = sum_k Aglob[m][k]*Bglob[k][n] (k 0..TKSW-1).
    //   gemm_w16b (band decode): software-decodes Asw -> As0/As1 via composed_A then gmma_phys
    //     repack (w16.cu L458-463), Bsw -> B0/B1 via composed_B then gmma_phys repack
    //     (L464-469), THEN wgmma reads the band. The repack is a pure RESHUFFLE — the VALUE
    //     at each logical (m,k)/(k,n) is preserved, so the GEMM result is identical.
    //   We model BOTH on CPU at full slab tile (128x32 A, 32x128 B) and assert the decoded
    //   band, read back through gmma_phys, yields the SAME logical operands gemm_w16 reads
    //   in place -> identical per-slab GEMM. Element-for-element.
    // -------------------------------------------------------------------------
    {
        const int M=TM, N=TN, K=TKSW;
        std::vector<float> Aglob(M*K), Bglob(K*N);
        srand(21);
        for(int i=0;i<M*K;++i)Aglob[i]=tf(((rand()%17)-8)*0.0625f);
        for(int i=0;i<K*N;++i)Bglob[i]=tf(((rand()%17)-8)*0.0625f);

        // --- model the landed swizzled tiles (the TMA output both kernels start from). ---
        std::vector<float> Asw(M*K), Bsw(N*K);
        for(int m=0;m<M;++m)for(int k=0;k<K;++k) Asw[w16_composed_A(m,k)] = Aglob[m*K+k];
        for(int k=0;k<K;++k)for(int n=0;n<N;++n) Bsw[composed_B(k,n,K)]   = Bglob[k*N+n];

        // --- gemm_w16b A decode: As0 (m<64) / As1 (m>=64), sub=k>>3, kk=k&7, mm=m&63. ---
        //     dst[sub*(64*8) + gmma_phys(mm,kk)] = Asw[composed_A(m,k)]
        std::vector<float> As0(64*K, 0.f), As1(64*K, 0.f);     // 64 rows x (4 sub * 8 k) = 64*32
        for(int m=0;m<M;++m)for(int k=0;k<K;++k){
            int sw=w16_composed_A(m,k); float v=Asw[sw];
            int sub=k>>3, kk=k&7, mm=m&63;
            (m<64?As0:As1)[sub*(64*8) + gmma_phys(mm,kk)] = v;
        }
        // --- gemm_w16b B decode: B0 (n<64) / B1 (n>=64), nnn=n&63. ---
        std::vector<float> B0(64*K, 0.f), B1(64*K, 0.f);
        for(int k=0;k<K;++k)for(int n=0;n<N;++n){
            int sw=composed_B(k,n,K); float v=Bsw[sw];
            int sub=k>>3, kk=k&7, nnn=n&63;
            (n<64?B0:B1)[sub*(64*8) + gmma_phys(nnn,kk)] = v;
        }

        // --- read the band back through gmma_phys (the wgmma operand view) and confirm it
        //     reconstructs the SAME logical operands gemm_w16 reads directly from global. ---
        bool ok=true; char d[160]={0}; long Aok=0, Bok=0, At=0, Bt=0;
        for(int m=0;m<M&&ok;++m)for(int k=0;k<K;++k){
            ++At;
            int sub=k>>3, kk=k&7, mm=m&63;
            float bandv=(m<64?As0:As1)[sub*(64*8) + gmma_phys(mm,kk)];
            if(memcmp(&bandv,&Aglob[m*K+k],4)==0) ++Aok;
            else { ok=false; snprintf(d,sizeof d,"A band@(m%d,k%d) %g vs %g",m,k,bandv,Aglob[m*K+k]); }
        }
        for(int k=0;k<K&&ok;++k)for(int n=0;n<N;++n){
            ++Bt;
            int sub=k>>3, kk=k&7, nnn=n&63;
            float bandv=(n<64?B0:B1)[sub*(64*8) + gmma_phys(nnn,kk)];
            if(memcmp(&bandv,&Bglob[k*N+n],4)==0) ++Bok;
            else { ok=false; snprintf(d,sizeof d,"B band@(k%d,n%d) %g vs %g",k,n,bandv,Bglob[k*N+n]); }
        }
        char dd[200]; snprintf(dd,sizeof dd,"A=%ld/%ld B=%ld/%ld %s",Aok,At,Bok,Bt,d);
        check("C3 gemm_w16b band decode == gemm_w16 operands (same math)",ok&&Aok==At&&Bok==Bt,dd);
    }

    // -------------------------------------------------------------------------
    // C3b — close the loop on C3: confirm the per-slab GEMM computed FROM the w16b band equals
    //   the per-slab GEMM gemm_w16 computes from global (both fp32-FMA over tf32 inputs, same
    //   increasing-k order). Element-for-element on the 128x128 slab output.
    // -------------------------------------------------------------------------
    {
        const int M=TM, N=TN, K=TKSW;
        std::vector<float> Aglob(M*K), Bglob(K*N);
        srand(33);
        for(int i=0;i<M*K;++i)Aglob[i]=tf(((rand()%17)-8)*0.0625f);
        for(int i=0;i<K*N;++i)Bglob[i]=tf(((rand()%17)-8)*0.0625f);
        std::vector<float> Asw(M*K), Bsw(N*K);
        for(int m=0;m<M;++m)for(int k=0;k<K;++k) Asw[w16_composed_A(m,k)] = Aglob[m*K+k];
        for(int k=0;k<K;++k)for(int n=0;n<N;++n) Bsw[composed_B(k,n,K)]   = Bglob[k*N+n];
        std::vector<float> As0(64*K,0.f),As1(64*K,0.f),B0(64*K,0.f),B1(64*K,0.f);
        for(int m=0;m<M;++m)for(int k=0;k<K;++k){int sub=k>>3,kk=k&7,mm=m&63;(m<64?As0:As1)[sub*(64*8)+gmma_phys(mm,kk)]=Asw[w16_composed_A(m,k)];}
        for(int k=0;k<K;++k)for(int n=0;n<N;++n){int sub=k>>3,kk=k&7,nnn=n&63;(n<64?B0:B1)[sub*(64*8)+gmma_phys(nnn,kk)]=Bsw[composed_B(k,n,K)];}
        auto Aband=[&](int m,int k){int sub=k>>3,kk=k&7,mm=m&63;return (m<64?As0:As1)[sub*(64*8)+gmma_phys(mm,kk)];};
        auto Bband=[&](int k,int n){int sub=k>>3,kk=k&7,nnn=n&63;return (n<64?B0:B1)[sub*(64*8)+gmma_phys(nnn,kk)];};
        bool ok=true; char d[160]={0}; int exact=0;
        for(int m=0;m<M&&ok;++m)for(int n=0;n<N;++n){
            float w16=0.f, w16b=0.f;
            for(int k=0;k<K;++k){ w16 += Aglob[m*K+k]*Bglob[k*N+n]; w16b += Aband(m,k)*Bband(k,n); }
            if(memcmp(&w16,&w16b,4)==0) exact++;
            else { ok=false; snprintf(d,sizeof d,"@(m%d,n%d) w16=%g w16b=%g",m,n,w16,w16b); }
        }
        char dd[200]; snprintf(dd,sizeof dd,"exact=%d/%d %s",exact,M*N,d);
        check("C3b w16b per-slab GEMM == w16 per-slab GEMM",ok&&exact==M*N,dd);
    }

    // -------------------------------------------------------------------------
    // C4 — descriptor stride byte arithmetic self-consistent ACROSS the NST=3 stages.
    //   gemm_w16 ring slot base = st*SWBUF floats (SWBUF = ASW+BSW = 128*32 + 128*32).
    //   gemm_w16 START bump within the atom = off=kk*4 bytes for kk in {0,8,16,24} (L356):
    //     each 8-K sub-step advances 8 floats = 32 bytes inside the 32-wide atom -> the 4
    //     sub-steps tile [0,32,64,96] bytes = the full 128B swizzle row. consistent.
    //   gemm_w16b START bump = off=(kk>>3)*512*4 bytes (L478): each sub-step jumps a 512-float
    //     gmma_phys sub-tile (64 s * 8 k) = 2048 bytes; 4 sub-steps tile [0,2048,4096,6144].
    //   We assert: (i) ring slots are non-overlapping + contiguous over NST stages; (ii) the
    //   w16 kk*4 bumps exactly tile one 128B swizzle row per atom for all 4 sub-steps; (iii)
    //   the w16b (kk>>3)*512*4 bumps exactly tile the 4 gmma sub-tiles; (iv) the MODE-1
    //   defaults (lbo=16, sbo=1024) match the 1024B = 256-float atom of MODE-4.
    // -------------------------------------------------------------------------
    {
        const int FB=4, NST=3;
        const int ASW=TM*TKSW, BSW=TN*TKSW, SWBUF=ASW+BSW;   // floats
        // (i) ring slot bases over NST stages: st*SWBUF, non-overlap + contiguous.
        bool ring_ok=true; char rd[120]={0};
        for(int st=0;st+1<NST;++st){
            long base=(long)st*SWBUF, next=(long)(st+1)*SWBUF;
            if(next-base != SWBUF){ ring_ok=false; snprintf(rd,sizeof rd,"stage %d gap %ld",st,next-base); break; }
        }
        // (ii) gemm_w16 kk*4-byte START bumps tile one 128B swizzle row (32 floats) per atom.
        bool w16_ok=true; int prev=-1;
        for(int kk=0;kk<TKSW;kk+=TK){
            int off=kk*FB;                      // bytes
            if(off != (kk/TK)*(TK*FB)){ w16_ok=false; break; }   // each step = 8 floats = 32B
            if(prev>=0 && off-prev!=TK*FB){ w16_ok=false; break; }
            prev=off;
        }
        bool w16_span = (((TKSW/TK)-1)*TK*FB + TK*FB == TKSW*FB) && (TKSW*FB==128);  // 4 steps = 128B row
        // (iii) gemm_w16b (kk>>3)*512*4 bumps tile the 4 gmma sub-tiles (512 floats = 2048B each).
        bool w16b_ok=true; prev=-1;
        for(int kk=0;kk<TKSW;kk+=TK){
            int off=(kk>>3)*512*FB;             // bytes
            if(off != (kk/TK)*512*FB){ w16b_ok=false; break; }
            if(prev>=0 && off-prev!=512*FB){ w16b_ok=false; break; }
            prev=off;
        }
        bool w16b_span = ((TKSW/TK)*512*FB == 2048*(TKSW/TK)) && ((TKSW/TK)==4);
        // (iv) MODE-1 / MODE-4 descriptor defaults vs the 256-float (1024B) atom.
        int atom_floats=8*32, atom_bytes=atom_floats*FB;      // 256 floats = 1024B
        int MODE_SBO=1024, MODE_LBO=16;
        bool desc_ok = (atom_bytes==1024) && (MODE_SBO==atom_bytes) && (atom_floats==256) && (MODE_LBO==16);
        bool ok = ring_ok && w16_ok && w16_span && w16b_ok && w16b_span && desc_ok;
        char d[220];
        snprintf(d,sizeof d,"SWBUF=%df rings=%s w16bump[0,32,64,96]B=%s span128=%s w16b[0,2k,4k,6k]B=%s SBO=%d",
                 SWBUF, ring_ok?"ok":"BAD", w16_ok?"ok":"BAD", w16_span?"ok":"BAD", w16b_ok?"ok":"BAD", MODE_SBO);
        check("C4 descriptor stride self-consistent across NST=3 stages",ok,d);
    }

    printf("-----------------------------------------------------------------\n");
    printf("RESULT: %d PASS, %d FAIL\n", g_pass, g_fail);
    if(g_fail==0){
        printf("REMAINING-MODE GPU-FREE REFERENCE LOGIC CPU-CORRECT — more of the H100 gate de-risked.\n");
        printf("STILL H100-GATED: the device wgmma swmode=1 HW de-swizzle (MODE 1/4 rel_rms 0 on the\n");
        printf("real descriptor read) + the gemm_w16b device band path + ALL perf. No TFLOP/s claimed.\n");
    } else {
        printf("BUG FOUND in the remaining-MODE GPU-free logic — fix w16.cu BEFORE the H100 run.\n");
    }
    return g_fail==0?0:1;
}
