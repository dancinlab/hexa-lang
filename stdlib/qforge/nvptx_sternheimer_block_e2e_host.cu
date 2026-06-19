// stdlib/qforge/nvptx_sternheimer_block_e2e_host.cu — QFORGE-PERF round 2 ⚡
// END-TO-END Sternheimer DFPT solve on GPU: BLOCK projected-CG (the block
// H-apply over all nb perturbation search directions = ONE cuBLAS DGEMM
// H[n,n]@P[n,nb] per CG iter, the qforge_sternheimer_block seam) vs the CPU
// scalar per-state loop (the current caller pattern in screened_dv/elph_scf/
// dfpt_response: `while s<nb { qforge_sternheimer(...) }`, nb× scalar CG, each
// CG iter = one scalar H·v).
//
// Both paths run the IDENTICAL projected-CG math (sternheimer.hexa). The ONLY
// difference is the H-apply: nb× scalar matvec/iter (CPU) vs ONE batched DGEMM
// over the block of nb directions/iter (GPU). The wall delta isolates the
// block-H-apply win in the real DFPT hot path.
//
// ε_s is set BELOW the spectrum so (H−ε) is SPD → projected CG converges and
// both paths reach the SAME Δψ (parity gate). occ_states = synthetic orthonormal
// set (the projector only needs an orthonormal basis); BOTH paths get the same.
//
//   build: nvcc -O2 nvptx_sternheimer_block_e2e_host.cu -o stern_e2e -lcublas
//   run:   ./stern_e2e
// Exit 0 = parity within tol for every size.

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
static double dot(const double*a,const double*b,int n){ double s=0; for(int i=0;i<n;i++) s+=a[i]*b[i]; return s; }

static void build_H(int n, std::vector<double>& H){
    H.assign((long)n*n,0.0);
    unsigned long s=11357UL + (unsigned long)n;
    for(int i=0;i<n;i++) for(int j=i;j<n;j++){
        double v=r11(s)*0.05; if(i==j) v=(double)i+1.0;
        H[(long)i*n+j]=v; H[(long)j*n+i]=v;
    }
}
// scalar H·v
static void Hv(const std::vector<double>& H,int n,const double* v,double* o){
    for(int i=0;i<n;i++){ double s=0; for(int j=0;j<n;j++) s+=H[(long)i*n+j]*v[j]; o[i]=s; }
}
// P_c projection: w -= Σ_m <occ_m|w> occ_m  (2x classical GS), in place.
static void project_out(double* w,const std::vector<std::vector<double>>& occ,int m,int n){
    for(int pass=0;pass<2;pass++) for(int j=0;j<m;j++){ double c=dot(occ[j].data(),w,n);
        for(int i=0;i<n;i++) w[i]-=c*occ[j][i]; }
}

// ── CPU scalar per-state Sternheimer (qforge_sternheimer) ──
static int stern_scalar(const std::vector<double>& H,int n,double eps,
        const std::vector<std::vector<double>>& occ,int m,const double* dVpsi,
        double tol,int maxit,double* dpsi_out){
    std::vector<double> b(dVpsi,dVpsi+n); project_out(b.data(),occ,m,n);
    for(int i=0;i<n;i++) b[i]=-b[i];
    std::vector<double> x(n,0.0),r(b),p(b),hp(n),ap(n);
    double bn=sqrt(dot(b.data(),b.data(),n));
    if(bn<tol){ for(int i=0;i<n;i++) dpsi_out[i]=0; return 1; }
    double rs_old=dot(r.data(),r.data(),n); int it=0; int conv=0;
    while(it<maxit){
        std::vector<double> pcp(p); project_out(pcp.data(),occ,m,n);
        Hv(H,n,pcp.data(),hp.data());
        for(int i=0;i<n;i++) ap[i]=hp[i]-eps*pcp[i];
        project_out(ap.data(),occ,m,n);
        double pAp=dot(p.data(),ap.data(),n); if(pAp==0) break;
        double alpha=rs_old/pAp;
        for(int i=0;i<n;i++){ x[i]+=alpha*p[i]; r[i]-=alpha*ap[i]; }
        it++;
        double rn=sqrt(dot(r.data(),r.data(),n)); if(rn<tol){ conv=1; break; }
        double rs_new=dot(r.data(),r.data(),n); double beta=rs_new/rs_old;
        for(int i=0;i<n;i++) p[i]=r[i]+beta*p[i]; rs_old=rs_new;
    }
    for(int i=0;i<n;i++) dpsi_out[i]=x[i]; project_out(dpsi_out,occ,m,n);
    return conv;
}

// ── GPU block Sternheimer (qforge_sternheimer_block) ──
// dH resident; block H-apply via cuBLAS DGEMM over nb directions per iter.
static int stern_block_gpu(const std::vector<double>& H,int n,const std::vector<double>& eps,
        const std::vector<std::vector<double>>& occ,int m,const std::vector<double>& dVpsi_flat,
        int nb,double tol,int maxit,cublasHandle_t handle,double* dH,
        std::vector<double>& dpsi_out,int& iters){
    std::vector<double> x((long)nb*n,0.0),r((long)nb*n,0.0),p((long)nb*n,0.0);
    std::vector<double> rs_old(nb),bnorm(nb); std::vector<int> done(nb,0);
    for(int s=0;s<nb;s++){
        std::vector<double> bs(dVpsi_flat.begin()+(long)s*n, dVpsi_flat.begin()+(long)(s+1)*n);
        project_out(bs.data(),occ,m,n); for(int i=0;i<n;i++) bs[i]=-bs[i];
        double bn=sqrt(dot(bs.data(),bs.data(),n)); bnorm[s]=bn; done[s]=(bn<tol);
        for(int i=0;i<n;i++){ r[(long)s*n+i]=bs[i]; p[(long)s*n+i]=bs[i]; }
        rs_old[s]=dot(bs.data(),bs.data(),n);
    }
    double *dP,*dY; CK(cudaMalloc(&dP,(long)n*nb*sizeof(double))); CK(cudaMalloc(&dY,(long)n*nb*sizeof(double)));
    iters=0;
    while(iters<maxit){
        int active=0; for(int s=0;s<nb;s++) if(!done[s]) active=1;
        if(!active) break;
        // pack P[n,nb] row-major with P_c p_s columns (0 for done states).
        std::vector<std::vector<double>> pcp(nb,std::vector<double>(n,0.0));
        std::vector<double> pflat((long)n*nb,0.0);
        for(int s=0;s<nb;s++) if(!done[s]){
            std::vector<double> ps(p.begin()+(long)s*n,p.begin()+(long)(s+1)*n);
            project_out(ps.data(),occ,m,n);
            for(int i=0;i<n;i++){ pcp[s][i]=ps[i]; pflat[(long)i*nb+s]=ps[i]; }
        }
        // ONE block DGEMM: Y[n,nb]=H·P[n,nb]. colmaj: pflat=colmaj Pc(nb×n);
        // Yc(nb×n)=Pc·H (H sym) → cublasDgemm(N,N, nb,n,n, Pc(ld=nb), H(ld=n)).
        CK(cudaMemcpy(dP,pflat.data(),(long)n*nb*sizeof(double),cudaMemcpyHostToDevice));
        const double one=1.0,zero=0.0;
        CKB(cublasDgemm(handle,CUBLAS_OP_N,CUBLAS_OP_N, nb,n,n, &one, dP,nb, dH,n, &zero, dY,nb));
        std::vector<double> y((long)n*nb);
        CK(cudaMemcpy(y.data(),dY,(long)n*nb*sizeof(double),cudaMemcpyDeviceToHost));
        for(int s=0;s<nb;s++) if(!done[s]){
            std::vector<double> hp(n); for(int i=0;i<n;i++) hp[i]=y[(long)i*nb+s];
            std::vector<double> ap(n); for(int i=0;i<n;i++) ap[i]=hp[i]-eps[s]*pcp[s][i];
            project_out(ap.data(),occ,m,n);
            double pAp=dot(pcp[s].data(),ap.data(),n);
            if(pAp==0){ done[s]=1; continue; }
            double alpha=rs_old[s]/pAp;
            for(int i=0;i<n;i++){ x[(long)s*n+i]+=alpha*p[(long)s*n+i]; r[(long)s*n+i]-=alpha*ap[i]; }
            double rsq=0; for(int i=0;i<n;i++) rsq+=r[(long)s*n+i]*r[(long)s*n+i];
            double rn=sqrt(rsq);
            if(rn<tol){ done[s]=1; }
            else { double beta=rsq/rs_old[s];
                for(int i=0;i<n;i++) p[(long)s*n+i]=r[(long)s*n+i]+beta*p[(long)s*n+i];
                rs_old[s]=rsq; }
        }
        iters++;
    }
    cudaFree(dP); cudaFree(dY);
    dpsi_out.assign((long)nb*n,0.0);
    for(int s=0;s<nb;s++){ std::vector<double> xs(x.begin()+(long)s*n,x.begin()+(long)(s+1)*n);
        project_out(xs.data(),occ,m,n); for(int i=0;i<n;i++) dpsi_out[(long)s*n+i]=xs[i]; }
    return 1;
}

static int run_size(int n,int nb){
    std::vector<double> H; build_H(n,H);
    double tol=1e-8; int maxit=400;
    // synthetic orthonormal occ_states + ε below spectrum.
    std::vector<std::vector<double>> occ; std::vector<double> eps;
    unsigned long sd=424242UL+(unsigned long)n;
    for(int s=0;s<nb;s++){ std::vector<double> w(n); for(int i=0;i<n;i++) w[i]=r11(sd);
        for(int p=0;p<s;p++){ double pr=dot(occ[p].data(),w.data(),n); for(int i=0;i<n;i++) w[i]-=pr*occ[p][i]; }
        double nr=sqrt(dot(w.data(),w.data(),n)); for(int i=0;i<n;i++) w[i]/=nr;
        occ.push_back(w); eps.push_back(-10.0); }
    std::vector<double> dVf((long)nb*n); unsigned long s2=99173UL+(unsigned long)n;
    for(long q=0;q<(long)nb*n;q++) dVf[q]=r11(s2);

    // CPU scalar per-state loop.
    std::vector<double> dsc((long)nb*n);
    auto c0=std::chrono::high_resolution_clock::now();
    int scConv=1;
    for(int s=0;s<nb;s++){ int cv=stern_scalar(H,n,eps[s],occ,nb,dVf.data()+(long)s*n,tol,maxit,dsc.data()+(long)s*n); if(!cv) scConv=0; }
    auto c1=std::chrono::high_resolution_clock::now();
    double cpu_ms=std::chrono::duration<double,std::milli>(c1-c0).count();

    // GPU block.
    cublasHandle_t h; CKB(cublasCreate(&h));
    double* dH; CK(cudaMalloc(&dH,(long)n*n*sizeof(double)));
    CK(cudaMemcpy(dH,H.data(),(long)n*n*sizeof(double),cudaMemcpyHostToDevice));
    std::vector<double> dgp; int it_g;
    cudaDeviceSynchronize();
    auto g0=std::chrono::high_resolution_clock::now();
    stern_block_gpu(H,n,eps,occ,nb,dVf,nb,tol,maxit,h,dH,dgp,it_g);
    cudaDeviceSynchronize();
    auto g1=std::chrono::high_resolution_clock::now();
    double gpu_ms=std::chrono::duration<double,std::milli>(g1-g0).count();
    cudaFree(dH); cublasDestroy(h);

    double maxd=0; for(long z=0;z<(long)nb*n;z++){ double d=fabs(dsc[z]-dgp[z]); if(d>maxd) maxd=d; }
    int pass=(maxd<=1e-6);
    printf("n=%d nb=%d\n",n,nb);
    printf("  cpu_full_solve = %.3f ms   gpu_full_solve = %.3f ms (%d blkit)   speedup = %.3fx\n",
           cpu_ms, gpu_ms,it_g, gpu_ms>0?cpu_ms/gpu_ms:0.0);
    printf("  max|dDpsi| = %.6e   scalarConv=%d   tol=1e-6   PARITY: %s\n", maxd, scConv, pass?"PASS":"FAIL");
    return pass?0:1;
}

int main(){
    cudaDeviceProp pr; if(cudaGetDeviceProperties(&pr,0)==cudaSuccess)
        fprintf(stderr,"[gpu] %s sm_%d%d\n",pr.name,pr.major,pr.minor);
    int rc=0;
    rc|=run_size(1024,4);
    rc|=run_size(1024,8);
    rc|=run_size(1536,6);
    rc|=run_size(2048,8);
    printf("ALL: %s\n", rc==0?"PASS":"FAIL");
    return rc;
}
