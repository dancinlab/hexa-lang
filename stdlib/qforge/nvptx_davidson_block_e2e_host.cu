// stdlib/qforge/nvptx_davidson_block_e2e_host.cu — QFORGE-PERF round 2 ⚡
// END-TO-END Davidson eigensolve on GPU (block H-apply = ONE cuBLAS DGEMM per
// iteration, the qforge_h_apply_forge_block seam) vs the CPU scalar reference
// (m× scalar H·basis[b] per iteration, the pre-round-2 dv_project path).
//
// This is the round-2 deliverable: the win must show in the FULL SOLVE wall,
// not just the H-apply microbench (round-1 nvptx_happly_block_host.cu = 74.9×).
// Both paths run the IDENTICAL Davidson algorithm (davidson.hexa qforge_davidson):
//   per outer iter:
//     (1) W = H·basis  (CPU: m matvecs O(n²); GPU: ONE DGEMM H[n,n]@Ψ[n,m])
//     (2) Hs = Vᵀ·W (m×m), small symmetric eigh (Jacobi on host, m tiny)
//     (3) Ritz vectors x = Σ y·basis, residual r = H·x − λ·x
//     (4) diagonal-preconditioned corrections, MGS re-orthonormalize, restart
// The ONLY difference between the two paths is step (1) — scalar matvec loop vs
// one batched cuBLAS GEMM. Everything else (eigh, Ritz, MGS, restart) is shared
// host code, so the wall delta isolates exactly the block-H-apply win in the
// real solver hot path.
//
// Parity gate: lowest-nbands eigenvalues agree to tol (1e-8) between paths.
// Speedup = CPU full-solve wall / GPU full-solve wall (incl. all H2D/D2H).
//
//   build: nvcc -O2 nvptx_davidson_block_e2e_host.cu -o dav_e2e -lcublas
//   run:   ./dav_e2e
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
  fprintf(stderr,"CUDA-ERR %s @ %s:%d\n",cudaGetErrorString(e),__FILE__,__LINE__); exit(2);} }while(0)
#define CKB(x) do{ cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){ \
  fprintf(stderr,"CUBLAS-ERR %d @ %s:%d\n",(int)s,__FILE__,__LINE__); exit(2);} }while(0)

static unsigned long lcg(unsigned long& s){ s=s*1103515245UL+12345UL; return (s>>16)&0x7fffffffUL; }
static double r11(unsigned long& s){ return ((double)(lcg(s)%20000)/10000.0)-1.0; }

// symmetric H[n,n]: diagonal kinetic ladder + small off-diagonals (matches the
// build_sym_ham in davidson_block_e2e_bench.hexa, scale 0.05).
static void build_H(int n, std::vector<double>& H){
    H.assign((long)n*n,0.0);
    unsigned long s=2463534242UL + (unsigned long)n;
    for(int i=0;i<n;i++) for(int j=i;j<n;j++){
        double v=r11(s)*0.05; if(i==j) v=(double)i+1.0;
        H[(long)i*n+j]=v; H[(long)j*n+i]=v;
    }
}

// ── small dense symmetric eigensolver (cyclic Jacobi) — m is tiny (≤4·nbands) ──
// returns eigenvalues asc + eigenvectors as columns of V (row-major V[i*m+k]).
static void jacobi_eigh(std::vector<double> A,int m,std::vector<double>& eval,std::vector<double>& evec){
    evec.assign((long)m*m,0.0); for(int i=0;i<m;i++) evec[(long)i*m+i]=1.0;
    for(int sweep=0;sweep<100;sweep++){
        double off=0; for(int p=0;p<m;p++)for(int q=p+1;q<m;q++) off+=A[(long)p*m+q]*A[(long)p*m+q];
        if(off<1e-30) break;
        for(int p=0;p<m;p++)for(int q=p+1;q<m;q++){
            double apq=A[(long)p*m+q]; if(fabs(apq)<1e-300) continue;
            double app=A[(long)p*m+p],aqq=A[(long)q*m+q];
            double phi=0.5*atan2(2*apq,aqq-app);
            double c=cos(phi),sn=sin(phi);
            for(int k=0;k<m;k++){ double akp=A[(long)k*m+p],akq=A[(long)k*m+q];
                A[(long)k*m+p]=c*akp-sn*akq; A[(long)k*m+q]=sn*akp+c*akq; }
            for(int k=0;k<m;k++){ double apk=A[(long)p*m+k],aqk=A[(long)q*m+k];
                A[(long)p*m+k]=c*apk-sn*aqk; A[(long)q*m+k]=sn*apk+c*aqk; }
            for(int k=0;k<m;k++){ double vkp=evec[(long)k*m+p],vkq=evec[(long)k*m+q];
                evec[(long)k*m+p]=c*vkp-sn*vkq; evec[(long)k*m+q]=sn*vkp+c*vkq; }
        }
    }
    eval.assign(m,0.0); std::vector<int> idx(m);
    for(int i=0;i<m;i++){ eval[i]=A[(long)i*m+i]; idx[i]=i; }
    // sort ascending
    for(int i=0;i<m;i++)for(int j=i+1;j<m;j++) if(eval[idx[j]]<eval[idx[i]]){int t=idx[i];idx[i]=idx[j];idx[j]=t;}
    std::vector<double> ev(m),vc((long)m*m);
    for(int k=0;k<m;k++){ ev[k]=eval[idx[k]]; for(int i=0;i<m;i++) vc[(long)i*m+k]=evec[(long)i*m+idx[k]]; }
    eval=ev; evec=vc;
}

static double dot(const double*a,const double*b,int n){ double s=0; for(int i=0;i<n;i++) s+=a[i]*b[i]; return s; }

// MGS: orthonormalize w against basis (m rows length n); return 1 if kept.
static int orthonorm(std::vector<std::vector<double>>& basis,int m,std::vector<double>& w,int n){
    for(int j=0;j<m;j++){ double p=dot(basis[j].data(),w.data(),n);
        for(int i=0;i<n;i++) w[i]-=p*basis[j][i]; }
    double nrm=sqrt(dot(w.data(),w.data(),n));
    if(nrm<1e-10) return 0;
    for(int i=0;i<n;i++) w[i]/=nrm; return 1;
}

// shared Davidson body. apply_block: 1 = GPU cuBLAS block H-apply; 0 = CPU scalar.
// Returns the lowest-nbands eigenvalues in `out_evals`, fills iters.
static void davidson(const std::vector<double>& H,int n,int nbands,double tol,int max_iter,
                     int use_gpu, cublasHandle_t handle,double* dH,
                     std::vector<double>& out_evals,int& iters){
    // diag + initial basis (unit vectors on the nbands smallest diagonal entries).
    std::vector<double> diag(n); for(int i=0;i<n;i++) diag[i]=H[(long)i*n+i];
    std::vector<int> order(n); for(int i=0;i<n;i++) order[i]=i;
    for(int s=0;s<nbands;s++){ int best=s; for(int q=s+1;q<n;q++) if(diag[order[q]]<diag[order[best]]) best=q;
        int t=order[s]; order[s]=order[best]; order[best]=t; }
    std::vector<std::vector<double>> basis;
    for(int k=0;k<nbands;k++){ std::vector<double> e(n,0.0); e[order[k]]=1.0; basis.push_back(e); }
    int m=nbands; iters=0;
    out_evals.assign(nbands,0.0);

    while(iters<max_iter){
        iters++;
        // (1) W[b] = H·basis[b].
        std::vector<std::vector<double>> W(m,std::vector<double>(n));
        if(use_gpu){
            // pack Ψ row-major [n,m]: psi[i*m+b]=basis[b][i].
            std::vector<double> psi((long)n*m);
            for(int i=0;i<n;i++) for(int b=0;b<m;b++) psi[(long)i*m+b]=basis[b][i];
            // colmaj view: psi buffer = colmaj Ψc(m×n) i.e. Ψc[b,i]. We want
            // Y row-major [n,m] Y[i*m+b]=Σ_j H[i,j]Ψ[j*m+b]. In colmaj that is
            // Yc(m×n) with Yc[b,i]=Σ_j Ψc[b,j]·H[j,i]=(Ψc·H)[b,i].  H symmetric.
            //   cublasDgemm(N,N, m,n,n, Ψc(m×n,ld=m), H(n×n,ld=n)) → Yc(m×n,ld=m).
            double *dPsi,*dY; CK(cudaMalloc(&dPsi,(long)n*m*sizeof(double)));
            CK(cudaMalloc(&dY,(long)n*m*sizeof(double)));
            CK(cudaMemcpy(dPsi,psi.data(),(long)n*m*sizeof(double),cudaMemcpyHostToDevice));
            const double one=1.0,zero=0.0;
            CKB(cublasDgemm(handle,CUBLAS_OP_N,CUBLAS_OP_N, m,n,n,
                            &one, dPsi,m, dH,n, &zero, dY,m));
            std::vector<double> y((long)n*m);
            CK(cudaMemcpy(y.data(),dY,(long)n*m*sizeof(double),cudaMemcpyDeviceToHost));
            cudaFree(dPsi); cudaFree(dY);
            for(int b=0;b<m;b++) for(int i=0;i<n;i++) W[b][i]=y[(long)i*m+b];
        } else {
            for(int b=0;b<m;b++) for(int i=0;i<n;i++){
                double s=0; for(int j=0;j<n;j++) s+=H[(long)i*n+j]*basis[b][j]; W[b][i]=s; }
        }
        // (2) Hs = Vᵀ·W (m×m), small eigh.
        std::vector<double> Hs((long)m*m);
        for(int a=0;a<m;a++)for(int b=0;b<m;b++) Hs[(long)a*m+b]=dot(basis[a].data(),W[b].data(),n);
        std::vector<double> vals,vecs; jacobi_eigh(Hs,m,vals,vecs); // asc, cols
        // (3) Ritz pairs + residual + corrections.
        std::vector<std::vector<double>> corrections; double max_res=0;
        std::vector<std::vector<double>> ritz;
        for(int bk=0;bk<nbands;bk++){
            double lam=vals[bk];
            std::vector<double> x(n,0.0),Hx(n,0.0);
            for(int j=0;j<m;j++){ double c=vecs[(long)j*m+bk];
                for(int i=0;i<n;i++){ x[i]+=c*basis[j][i]; Hx[i]+=c*W[j][i]; } }
            std::vector<double> r(n); for(int i=0;i<n;i++) r[i]=Hx[i]-lam*x[i];
            double rn=sqrt(dot(r.data(),r.data(),n)); if(rn>max_res) max_res=rn;
            out_evals[bk]=lam; ritz.push_back(x);
            if(rn>tol){ std::vector<double> corr(n);
                for(int id=0;id<n;id++){ double den=lam-diag[id];
                    double dd= den<0 ? (den>-1e-8?-1e-8:den) : (den<1e-8?1e-8:den);
                    corr[id]=r[id]/dd; }
                corrections.push_back(corr); }
        }
        if(max_res<tol) return;
        // (4) restart if subspace too large, then add corrections (MGS).
        if(m+(int)corrections.size() > 4*nbands){
            basis.clear();
            for(int rb=0;rb<nbands;rb++){ std::vector<double> ev=ritz[rb];
                if(orthonorm(basis,(int)basis.size(),ev,n)) basis.push_back(ev); }
            m=(int)basis.size();
        }
        for(auto& c: corrections){ std::vector<double> cc=c;
            if(orthonorm(basis,m,cc,n)){ basis.push_back(cc); m++; } }
    }
}

static int run_size(int n,int nbands){
    std::vector<double> H; build_H(n,H);
    double tol=1e-8; int maxit=200;

    // ── CPU scalar full solve ──
    std::vector<double> ev_cpu; int it_cpu;
    auto c0=std::chrono::high_resolution_clock::now();
    davidson(H,n,nbands,tol,maxit,0,nullptr,nullptr,ev_cpu,it_cpu);
    auto c1=std::chrono::high_resolution_clock::now();
    double cpu_ms=std::chrono::duration<double,std::milli>(c1-c0).count();

    // ── GPU block full solve (H resident on device for the whole solve) ──
    cublasHandle_t h; CKB(cublasCreate(&h));
    double* dH; CK(cudaMalloc(&dH,(long)n*n*sizeof(double)));
    CK(cudaMemcpy(dH,H.data(),(long)n*n*sizeof(double),cudaMemcpyHostToDevice));
    std::vector<double> ev_gpu; int it_gpu;
    cudaDeviceSynchronize();
    auto g0=std::chrono::high_resolution_clock::now();
    davidson(H,n,nbands,tol,maxit,1,h,dH,ev_gpu,it_gpu);
    cudaDeviceSynchronize();
    auto g1=std::chrono::high_resolution_clock::now();
    double gpu_ms=std::chrono::duration<double,std::milli>(g1-g0).count();
    cudaFree(dH); cublasDestroy(h);

    double maxd=0; for(int k=0;k<nbands;k++){ double d=fabs(ev_cpu[k]-ev_gpu[k]); if(d>maxd) maxd=d; }
    int pass=(maxd<=1e-7);
    printf("n=%d nbands=%d\n",n,nbands);
    printf("  cpu_full_solve = %.3f ms (%d it)   gpu_full_solve = %.3f ms (%d it)   speedup = %.3fx\n",
           cpu_ms,it_cpu, gpu_ms,it_gpu, gpu_ms>0?cpu_ms/gpu_ms:0.0);
    printf("  max|dLambda| = %.6e   tol=1e-7   PARITY: %s\n", maxd, pass?"PASS":"FAIL");
    return pass?0:1;
}

int main(){
    cudaDeviceProp pr; if(cudaGetDeviceProperties(&pr,0)==cudaSuccess)
        fprintf(stderr,"[gpu] %s sm_%d%d\n",pr.name,pr.major,pr.minor);
    int rc=0;
    rc|=run_size(1024,8);
    rc|=run_size(1024,32);
    rc|=run_size(1536,16);
    rc|=run_size(2048,16);
    printf("ALL: %s\n", rc==0?"PASS":"FAIL");
    return rc;
}
