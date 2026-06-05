// stdlib/qforge/nvptx_davidson_vthv_host.cu — QFORGE-PERF Lane A ⚡
// Davidson subspace projection  Hs = Vᵀ H V  as a GPU GEMM (cuBLAS) vs the
// CPU reference (dv_project, davidson.hexa:67).
//
// The CPU path (qforge_davidson's dv_project) does, for an m-vector basis of
// length-n vectors over a dense symmetric H[n,n]:
//      W[b] = H · basis[b]                  (m matvecs, each O(n²))
//      Hs[a*m+b] = Σ_i basis[a][i]·W[b][i]  (the m×m subspace projection)
// i.e. W = H·Vᵀ  (n×m) and  Hs = V·W  (m×m), V being the m×n basis (rows=vecs).
//
// This harness computes the SAME Hs two ways on the SAME deterministic fixture:
//   CPU: the scalar dv_project loops above (the engine reference).
//   GPU: two cuBLAS DGEMMs  —  W = H·Vᵀ ,  Hs = V·W  (FP64).
// cuBLAS is column-major; we feed row-major arrays and request the transposed
// op so the math is identical (documented in the GEMM calls below).
//
// Bit-parity gate: Hs_gpu == Hs_cpu, max_rel_err ≤ 1e-9 (pure +/* GEMM, no
// transcendental — tolerance tighter than the a2f exp() kernel). Speedup =
// CPU wall vs GPU wall (incl. H2D/D2H). d6 honesty: a transfer-dominated
// small-(n,m) no-speedup is a VALID result and is reported as measured.
//
//   build: nvcc -O2 nvptx_davidson_vthv_host.cu -o nvptx_davidson_vthv -lcublas
//   run:   ./nvptx_davidson_vthv         (prints PARITY + speedup per size)
//
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

// deterministic fill in [-1,1) — same LCG spirit as happly_gpu_bench.hexa.
static unsigned long lcg(unsigned long& s){ s = s*1103515245UL + 12345UL; return (s>>16)&0x7fffffffUL; }
static double r11(unsigned long& s){ return ((double)(lcg(s)%20000)/10000.0)-1.0; }

static int run_size(int n,int m){
    // ── fixture: symmetric H[n,n], basis V[m][n] (rows = basis vectors) ──
    unsigned long seed=2463534242UL + n*131UL + m;
    std::vector<double> H((long)n*n), V((long)m*n);
    for(int i=0;i<n;i++) for(int j=i;j<n;j++){ double v=r11(seed); H[(long)i*n+j]=v; H[(long)j*n+i]=v; }
    for(long k=0;k<(long)m*n;k++) V[k]=r11(seed);

    // ── CPU reference dv_project (W=H·basis[b]; Hs[a,b]=Σ_i basis[a][i]·W[b][i]) ──
    auto c0=std::chrono::high_resolution_clock::now();
    std::vector<double> W((long)m*n);   // W[b*n + i] = (H·basis[b])[i]
    for(int b=0;b<m;b++) for(int i=0;i<n;i++){
        double s=0; for(int j=0;j<n;j++) s+=H[(long)i*n+j]*V[(long)b*n+j];
        W[(long)b*n+i]=s;
    }
    std::vector<double> Hs_cpu((long)m*m);
    for(int a=0;a<m;a++) for(int b=0;b<m;b++){
        double s=0; for(int i=0;i<n;i++) s+=V[(long)a*n+i]*W[(long)b*n+i];
        Hs_cpu[(long)a*m+b]=s;
    }
    auto c1=std::chrono::high_resolution_clock::now();
    double cpu_ms=std::chrono::duration<double,std::milli>(c1-c0).count();

    // ── GPU: two DGEMMs (cuBLAS, column-major) ──
    // Row-major X[r,c] held in memory == column-major Xᵀ. So feeding our
    // row-major H,V to cuBLAS, the device "sees" Hᵀ(=H, symmetric) and Vᵀ.
    // We want, in row-major:  W = H·Vᵀ  (n×m) and  Hs = V·W (m×m).
    // Compute Hs directly as the column-major product that yields our row-major
    // Hs: cublasDgemm(op,op,...) with leading dims chosen so the returned buffer
    // is row-major Hs[a*m+b]. We do it in two clear steps with explicit transposes.
    cublasHandle_t h; CKB(cublasCreate(&h));
    double *dH,*dV,*dW,*dHs;
    CK(cudaMalloc(&dH,(long)n*n*sizeof(double)));
    CK(cudaMalloc(&dV,(long)m*n*sizeof(double)));
    CK(cudaMalloc(&dW,(long)m*n*sizeof(double)));
    CK(cudaMalloc(&dHs,(long)m*m*sizeof(double)));
    const double one=1.0, zero=0.0;

    cudaDeviceSynchronize();
    auto g0=std::chrono::high_resolution_clock::now();
    CK(cudaMemcpy(dH,H.data(),(long)n*n*sizeof(double),cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dV,V.data(),(long)m*n*sizeof(double),cudaMemcpyHostToDevice));

    // Step 1: W[b*n+i] = Σ_j H[i,j] V[b,j].  In column-major terms, our buffers
    // are colmaj Hc (n×n, =Hᵀ=H) and Vc (n×m, =Vᵀ). We want colmaj Wc (n×m) with
    // Wc[i,b]=W[b*n+i]=Σ_j H[i,j]Vc[j,b] = (H·Vc)[i,b]. So Wc = H * Vc, plain NN.
    //   cublasDgemm(N,N, n,m,n, H(n×n,ld=n), Vc(n×m,ld=n)) → Wc(n×m,ld=n).
    CKB(cublasDgemm(h,CUBLAS_OP_N,CUBLAS_OP_N, n,m,n,
                    &one, dH,n, dV,n, &zero, dW,n));
    // Step 2: Hs[a*m+b]=Σ_i V[a,i] W[b*n+i]=Σ_i Vc[i,a] Wc[i,b]=(Vcᵀ·Wc)[a,b].
    // We want row-major Hs[a*m+b], i.e. colmaj Hsc[b,a]=Hs[a*m+b]=(Wcᵀ·Vc)[b,a].
    //   colmaj Hsc(m×m) = Wcᵀ(m×n) * Vc(n×m):  cublasDgemm(T,N, m,m,n, Wc,ld=n, Vc,ld=n).
    CKB(cublasDgemm(h,CUBLAS_OP_T,CUBLAS_OP_N, m,m,n,
                    &one, dW,n, dV,n, &zero, dHs,m));
    std::vector<double> Hs_gpu((long)m*m);
    CK(cudaMemcpy(Hs_gpu.data(),dHs,(long)m*m*sizeof(double),cudaMemcpyDeviceToHost));
    cudaDeviceSynchronize();
    auto g1=std::chrono::high_resolution_clock::now();
    double gpu_ms=std::chrono::duration<double,std::milli>(g1-g0).count();

    // ── parity (Hs_gpu colmaj Hsc[b,a] vs row-major Hs_cpu[a*m+b]) ──
    double max_abs=0,max_rel=0; int am=-1,bm=-1;
    for(int a=0;a<m;a++) for(int b=0;b<m;b++){
        double cpu=Hs_cpu[(long)a*m+b];
        double gpu=Hs_gpu[(long)b*m+a];   // colmaj Hsc[b,a]
        double ad=fabs(cpu-gpu);
        double rd= fabs(cpu)>1e-300 ? ad/fabs(cpu) : (ad>0?ad:0.0);
        if(ad>max_abs) max_abs=ad;
        if(rd>max_rel){ max_rel=rd; am=a; bm=b; }
    }
    double tol=1e-9;
    int pass=(max_rel<=tol);
    printf("n=%d m=%d\n",n,m);
    printf("  cpu_wall = %.4f ms   gpu_wall = %.4f ms   speedup(cpu/gpu) = %.3fx\n",
           cpu_ms,gpu_ms, gpu_ms>0?cpu_ms/gpu_ms:0.0);
    printf("  max_abs_err = %.6e\n",max_abs);
    printf("  max_rel_err = %.6e  (a=%d b=%d: cpu=%.10e gpu=%.10e)\n",
           max_rel,am,bm, (am>=0)?Hs_cpu[(long)am*m+bm]:0.0, (am>=0)?Hs_gpu[(long)bm*m+am]:0.0);
    printf("  tol = %.1e   PARITY: %s\n", tol, pass?"PASS":"FAIL");

    cublasDestroy(h); cudaFree(dH);cudaFree(dV);cudaFree(dW);cudaFree(dHs);
    return pass?0:1;
}

int main(){
    int dev=0; cudaDeviceProp pr; if(cudaGetDeviceProperties(&pr,dev)==cudaSuccess)
        fprintf(stderr,"[gpu] %s sm_%d%d\n",pr.name,pr.major,pr.minor);
    int rc=0;
    // (n,m): n = PW basis dim, m = block width (= nbands/nocc, small).
    rc |= run_size(256, 16);
    rc |= run_size(512, 32);
    rc |= run_size(1024,64);
    rc |= run_size(2048,64);   // larger n: where GEMM should win
    printf("ALL: %s\n", rc==0?"PASS":"FAIL");
    return rc;
}
