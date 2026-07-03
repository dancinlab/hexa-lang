// stdlib/qforge/nvptx_happly_block_host.cu — QFORGE-PERF Lane A ⚡
// H_apply GPU-GEMM root-cause + fix harness.
//
// The OPEN item (QFORGE-PERF.md): qforge_h_apply_forge routes a SINGLE matvec
// H[n,n]·v[n,1] through forge_dispatch_matmul → cuBLAS. Measured 🔴 NOT FASTER
// at production size: a single GEMV is memory-bound (AI≈2/8≈0.25) AND every call
// re-marshals + H2D-transfers the entire O(n²) H matrix to do O(n²) flops once —
// transfer never amortizes. (assembler.hexa:299 qforge_h_apply_forge.)
//
// ROOT CAUSE (this harness MEASURES it): the Davidson/Sternheimer inner loop
// applies H to a BLOCK of m bands (basis vectors / occupied states). The current
// seam does that as m INDEPENDENT GEMV calls — m H2D copies of H. Batching the m
// applies into ONE GEMM H[n,n]@Ψ[n,m] transfers H ONCE and runs at GEMM (tensor)
// intensity (AI≈2nm/(n²+nm+nm)→m as m grows), opening the roof K2 already proved.
//
// Three paths, SAME deterministic fixture, per (n,m):
//   CPU   : m scalar matvecs (the engine reference, qforge_h_apply loop ×m).
//   GEMV  : m cublasDgemv, each with its OWN H2D of H[n,n]  (= current per-band
//           qforge_h_apply_forge seam, the 🔴 path).
//   GEMM  : ONE cublasDgemm H@Ψ, H transferred ONCE (the FIX — batched apply).
//
// Parity gate: GEMM result == CPU, max_rel_err ≤ 1e-9 (pure +/* GEMM, FP64).
// d6 honesty: prints REAL walls incl. all H2D/D2H. A no-win at our small (n,m)
// is a VALID result; a win above some (n,m) is reported with the crossover.
//
//   build: nvcc -O2 nvptx_happly_block_host.cu -o nvptx_happly_block -lcublas
//   run:   ./nvptx_happly_block
// Exit 0 = parity within tol for every size; non-zero = mismatch / cuda error.

#include <cublas_v2.h>
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <chrono>

#define CK(x)  do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA-ERR %s @ %s:%d\n",cudaGetErrorString(e),__FILE__,__LINE__); return 2; } }while(0)
#define CKB(x) do{ cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){ \
  fprintf(stderr,"CUBLAS-ERR %d @ %s:%d\n",(int)s,__FILE__,__LINE__); return 2; } }while(0)

static unsigned long lcg(unsigned long& s){ s = s*1103515245UL + 12345UL; return (s>>16)&0x7fffffffUL; }
static double r11(unsigned long& s){ return ((double)(lcg(s)%20000)/10000.0)-1.0; }

static double now_ms(){
    static auto t0=std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double,std::milli>(
        std::chrono::high_resolution_clock::now()-t0).count();
}

// returns 0 = parity pass for this size, 1 = mismatch, 2 = cuda err
static int run_size(int n,int m){
    // ── fixture: symmetric H[n,n], block Psi[n][m] stored row-major Psi[i*m+b] ──
    unsigned long seed=2463534242UL + (unsigned long)n*131UL + (unsigned long)m;
    std::vector<double> H((long)n*n), Psi((long)n*m);
    for(int i=0;i<n;i++) for(int j=i;j<n;j++){ double v=r11(seed); H[(long)i*n+j]=v; H[(long)j*n+i]=v; }
    for(long k=0;k<(long)n*m;k++) Psi[k]=r11(seed);

    // ── CPU reference: m scalar matvecs  (Y[i*m+b] = Σ_j H[i,j]·Psi[j,b]) ──
    auto c0=std::chrono::high_resolution_clock::now();
    std::vector<double> Y_cpu((long)n*m);
    for(int b=0;b<m;b++) for(int i=0;i<n;i++){
        double s=0; for(int j=0;j<n;j++) s+=H[(long)i*n+j]*Psi[(long)j*m+b];
        Y_cpu[(long)i*m+b]=s;
    }
    auto c1=std::chrono::high_resolution_clock::now();
    double cpu_ms=std::chrono::duration<double,std::milli>(c1-c0).count();

    cublasHandle_t h; CKB(cublasCreate(&h));
    const double one=1.0, zero=0.0;

    // Column-major view: a row-major buffer X[r,c] is read by cuBLAS as col-major
    // Xᵀ. H is symmetric so col-major Hc == H. We store Psi col-major directly:
    // Pc[j + b*n] = Psi(j,b) so cuBLAS sees an honest n×m matrix (ld=n).
    std::vector<double> Pc((long)n*m);
    for(int b=0;b<m;b++) for(int j=0;j<n;j++) Pc[(long)b*n+j]=Psi[(long)j*m+b];

    // ── GEMV path: m separate dgemv, each re-uploading H (= per-band seam) ──
    std::vector<double> Yv((long)n*m); // col-major Yc[i + b*n]
    double *dH=nullptr,*dv=nullptr,*dy=nullptr;
    CK(cudaMalloc(&dH,(long)n*n*sizeof(double)));
    CK(cudaMalloc(&dv,(long)n*sizeof(double)));
    CK(cudaMalloc(&dy,(long)n*sizeof(double)));
    cudaDeviceSynchronize();
    auto v0=std::chrono::high_resolution_clock::now();
    for(int b=0;b<m;b++){
        // per matvec: H2D of H (n²) + v (n), dgemv, D2H of y (n).  This is what
        // calling qforge_h_apply_forge once per band costs.
        CK(cudaMemcpy(dH,H.data(),(long)n*n*sizeof(double),cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dv,&Pc[(long)b*n],(long)n*sizeof(double),cudaMemcpyHostToDevice));
        // col-major Hc==H (symmetric), y = H·v : cublasDgemv(N, n,n, H, v) → y.
        CKB(cublasDgemv(h,CUBLAS_OP_N,n,n,&one,dH,n,dv,1,&zero,dy,1));
        CK(cudaMemcpy(&Yv[(long)b*n],dy,(long)n*sizeof(double),cudaMemcpyDeviceToHost));
    }
    cudaDeviceSynchronize();
    auto v1=std::chrono::high_resolution_clock::now();
    double gemv_ms=std::chrono::duration<double,std::milli>(v1-v0).count();
    cudaFree(dv); cudaFree(dy);

    // ── GEMM path: ONE dgemm H@Ψ, H transferred ONCE (the FIX) ──
    double *dP=nullptr,*dYg=nullptr;
    CK(cudaMalloc(&dP,(long)n*m*sizeof(double)));
    CK(cudaMalloc(&dYg,(long)n*m*sizeof(double)));
    std::vector<double> Yg((long)n*m); // col-major Ygc[i + b*n]
    cudaDeviceSynchronize();
    auto g0=std::chrono::high_resolution_clock::now();
    CK(cudaMemcpy(dH,H.data(),(long)n*n*sizeof(double),cudaMemcpyHostToDevice)); // H ONCE
    CK(cudaMemcpy(dP,Pc.data(),(long)n*m*sizeof(double),cudaMemcpyHostToDevice));
    // col-major: Yc(n×m) = Hc(n×n)·Pc(n×m), plain NN.
    CKB(cublasDgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,n,m,n,&one,dH,n,dP,n,&zero,dYg,n));
    CK(cudaMemcpy(Yg.data(),dYg,(long)n*m*sizeof(double),cudaMemcpyDeviceToHost));
    cudaDeviceSynchronize();
    auto g1=std::chrono::high_resolution_clock::now();
    double gemm_ms=std::chrono::duration<double,std::milli>(g1-g0).count();

    // ── parity: GEMM (col-major Ygc[i+b*n]) vs CPU (row-major Y_cpu[i*m+b]) ──
    double max_abs=0,max_rel=0;
    for(int i=0;i<n;i++) for(int b=0;b<m;b++){
        double cpu=Y_cpu[(long)i*m+b];
        double gpu=Yg[(long)b*n+i];
        double ad=fabs(cpu-gpu);
        double rd= fabs(cpu)>1e-300 ? ad/fabs(cpu) : (ad>0?ad:0.0);
        if(ad>max_abs) max_abs=ad;
        if(rd>max_rel) max_rel=rd;
    }
    // also verify GEMV path matches (sanity of the per-band path)
    double gemv_max_rel=0;
    for(int i=0;i<n;i++) for(int b=0;b<m;b++){
        double cpu=Y_cpu[(long)i*m+b], gpu=Yv[(long)b*n+i];
        double ad=fabs(cpu-gpu); double rd=fabs(cpu)>1e-300?ad/fabs(cpu):(ad>0?ad:0.0);
        if(rd>gemv_max_rel) gemv_max_rel=rd;
    }
    double tol=1e-9;
    int pass=(max_rel<=tol);
    printf("n=%d m=%d\n",n,m);
    printf("  CPU(m matvec)   = %10.4f ms\n", cpu_ms);
    printf("  GPU GEMV(m H2D) = %10.4f ms   speedup(cpu/gemv) = %7.3fx   [per-band seam=current]\n",
           gemv_ms, gemv_ms>0?cpu_ms/gemv_ms:0.0);
    printf("  GPU GEMM(1 H2D) = %10.4f ms   speedup(cpu/gemm) = %7.3fx   [batched=FIX]\n",
           gemm_ms, gemm_ms>0?cpu_ms/gemm_ms:0.0);
    printf("  gemm vs gemv    = %7.3fx faster   max_rel(gemm)=%.3e gemv=%.3e tol=%.0e  PARITY:%s\n",
           gemm_ms>0?gemv_ms/gemm_ms:0.0, max_rel, gemv_max_rel, tol, pass?"PASS":"FAIL");

    cublasDestroy(h); cudaFree(dH); cudaFree(dP); cudaFree(dYg);
    (void)now_ms;
    return pass?0:1;
}

int main(){
    int dev=0; cudaDeviceProp pr; if(cudaGetDeviceProperties(&pr,dev)==cudaSuccess)
        fprintf(stderr,"[gpu] %s sm_%d%d\n",pr.name,pr.major,pr.minor);
    int rc=0;
    // (n,m): n = PW basis dim; m = block width = nbands / nocc (the bands H is
    // applied to PER Davidson/Sternheimer iteration). Production cells: n up to
    // ~1-2k PW, m = nocc (tens). Sweep m so the GEMV→GEMM crossover is visible.
    int ns[] = {256, 512, 1024, 2048};
    int ms[] = {8, 32, 64};
    for(int ni=0; ni<4; ni++)
        for(int mi=0; mi<3; mi++)
            rc |= run_size(ns[ni], ms[mi]);
    printf("ALL: %s\n", rc==0?"PASS":"FAIL");
    return rc;
}
