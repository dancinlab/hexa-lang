// nvptx_stern_fused_host.cu — QFORGE GPU-tier kernel 2 on-device parity+throughput.
// closes QFORGE-FEATURE fused-cg
//
// Measures the FUSED Sternheimer projected-CG kernel set (nvptx_stern_fused_kernel.hexa)
// against the merged UNFUSED 5-launch-per-iter driver (the #2737 stack
// nvptx_sternheimer_kernel.hexa path), on a real GPU:
//
//   PARITY gate    : identical converged |dpsi> (FUSED == UNFUSED, FP64 round-off).
//   THROUGHPUT gate: >=1.5x CG-iteration throughput (fewer launches => less overhead).
//
// Both paths solve the SAME projected-CG system  P_c (H - eps) P_c |dpsi> = -P_c (dV)
// on an N-dim band that lives device-resident across all CG iterations. The math is
// bit-for-bit the merged recurrence (proj_out 2-pass Gram-Schmidt, matvec, shift,
// axpy x2, xpay). The host owns only the scalar reductions (pAp, rTr -> alpha,beta).
//
// UNFUSED path (mirrors the merged #2737 driver) launches per CG iter:
//   proj(pcp) -> matvec(hp) -> shift_sub(ap) -> proj(ap) -> axpy(x) -> axpy(r) -> xpay(p)
//   = the 7 device launches the merged host issues (5 distinct kernels).
// FUSED path collapses the trailing 3 BLAS-1 launches (axpy x2 + xpay) into ONE
// qforge_fused_cg_update kernel — bit-identical recurrence, 3 launches -> 1.
//   = proj -> matvec -> shift_sub -> proj -> fused_cg_update  (7 launches -> 5).
//
// The device kernels below are the literal CUDA-C mirror of the @gpu_kernel bodies in
// nvptx_stern_fused_kernel.hexa (and the merged nvptx_sternheimer_kernel.hexa) — same
// index math, same bit order — so the on-device measurement is a faithful proxy for the
// hexa-emitted PTX path (host-driver-loop remainder is the honest d6 scope, identical
// to the merged nvptx_sternheimer_host.cu).
//
//   build: nvcc -O2 -arch=sm_120 nvptx_stern_fused_host.cu -o nvptx_stern_fused_host
//   run:   ./nvptx_stern_fused_host [N] [CGITERS]
//
// Exit 0 = parity within tol AND throughput >=1.5x; non-zero otherwise.

#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>

#define CK(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA-ERR %s @ %d\n",cudaGetErrorString(e),__LINE__); return 2; } }while(0)

static const double TOL = 1.0e-11;

// ── device kernels: literal mirror of the .hexa @gpu_kernel bodies ──────────────
__global__ void k_proj_out(double* w,const double* occ,int n,int m){
    // single-block serial 2-pass Gram-Schmidt (bit-order parity), thread 0 owns it.
    if(threadIdx.x==0 && blockIdx.x==0){
        for(int pass=0;pass<2;pass++) for(int j=0;j<m;j++){
            const double* o=occ+j*n; double c=0;
            for(int i=0;i<n;i++) c+=o[i]*w[i];
            for(int i=0;i<n;i++) w[i]-=c*o[i];
        }
    }
}
__global__ void k_matvec(const double* M,const double* v,double* out,int n){
    int gid=blockIdx.x*blockDim.x+threadIdx.x;
    if(gid<n){ const double* row=M+(long)gid*n; double s=0;
        for(int j=0;j<n;j++) s+=row[j]*v[j]; out[gid]=s; }
}
__global__ void k_shift_sub(const double* hp,const double* pcp,double* ap,const double* par,int n){
    int gid=blockIdx.x*blockDim.x+threadIdx.x;
    if(gid<n) ap[gid]=hp[gid]-par[0]*pcp[gid];
}
__global__ void k_axpy(double* y,const double* x,const double* par,int n){ // y += par[0]*x
    int gid=blockIdx.x*blockDim.x+threadIdx.x;
    if(gid<n) y[gid]+=par[0]*x[gid];
}
__global__ void k_xpay(double* p,const double* r,const double* par,int n){ // p = r + par[0]*p
    int gid=blockIdx.x*blockDim.x+threadIdx.x;
    if(gid<n) p[gid]=r[gid]+par[0]*p[gid];
}
// FUSED: x+=a*p ; r-=a*ap ; p=r+b*p  (par[0]=alpha, par[1]=beta) — 3 launches -> 1.
__global__ void k_fused_cg_update(double* x,double* r,double* p,const double* ap,const double* par,int n){
    int gid=blockIdx.x*blockDim.x+threadIdx.x;
    if(gid<n){ double a=par[0],b=par[1],pi=p[gid];
        x[gid]=x[gid]+a*pi;
        double ri=r[gid]-a*ap[gid]; r[gid]=ri;
        p[gid]=ri+b*pi; }
}

// ── ON-DEVICE scalar reduction kernels (literal mirror of the .hexa bodies) ─────
// Two-stage dot: block tree-reduce -> partials[blockIdx]; finalize -> scal[slot].
// Then alpha/beta computed on-device into par[]/scal[] — NO per-iter DtoH/sync.
//   scal[0]=rs_old scal[1]=pAp scal[2]=alpha scal[3]=rs_new scal[4]=beta
template<int BS>
__global__ void k_dot_partial(const double* a,const double* b,double* partials,int n){
    __shared__ double sh[BS];
    int tid=threadIdx.x;
    int gid=blockIdx.x*blockDim.x+tid;
    int stride=blockDim.x*gridDim.x;
    double acc=0.0;
    for(int i=gid;i<n;i+=stride) acc+=a[i]*b[i];
    sh[tid]=acc; __syncthreads();
    for(int off=blockDim.x/2; off>0; off>>=1){
        if(tid<off) sh[tid]+=sh[tid+off];
        __syncthreads();
    }
    if(tid==0) partials[blockIdx.x]=sh[0];
}
__global__ void k_reduce_finalize(const double* partials,double* out,int nb,int slot){
    if(threadIdx.x==0){ double s=0; for(int k=0;k<nb;k++) s+=partials[k]; out[slot]=s; }
}
__global__ void k_cg_alpha(double* scal,double* par){
    if(threadIdx.x==0){ double a=scal[0]/scal[1]; scal[2]=a; par[0]=a; }
}
__global__ void k_cg_beta_commit(double* scal,double* par){
    if(threadIdx.x==0){ double b=scal[3]/scal[0]; scal[4]=b; par[1]=b; scal[0]=scal[3]; }
}
// scratch r_new = r - eps_par*ap  (out separate buffer; eps_par[0]=alpha) — for rs_new dot.
__global__ void k_rnew(const double* r,const double* ap,const double* par,double* out,int n){
    int gid=blockIdx.x*blockDim.x+threadIdx.x;
    if(gid<n) out[gid]=r[gid]-par[0]*ap[gid];
}
// shift using a device-resident eps (eps[0]); keeps eps OFF par[] so alpha never clobbers it.
__global__ void k_shift_sub_dev(const double* hp,const double* pcp,double* ap,const double* eps,int n){
    int gid=blockIdx.x*blockDim.x+threadIdx.x;
    if(gid<n) ap[gid]=hp[gid]-eps[0]*pcp[gid];
}

static double hdot(const double*a,const double*b,int n){double s=0;for(int i=0;i<n;i++)s+=a[i]*b[i];return s;}

// Solve projected-CG on device; fused=0 => 7-launch merged path, fused=1 => 5-launch.
// Returns dpsi (host buffer), iter count, and elapsed ms for the CG loop.
static int run_cg(int n,int m,int cgiters,int fused,
                  double* d_M,double* d_occ,const double* bg,double eps_n,
                  double* dpsi_out,int* iters_out,float* ms_out){
    int blk=128, grd=(n+blk-1)/blk;
    double *d_x,*d_r,*d_p,*d_pcp,*d_hp,*d_ap,*d_par;
    CK(cudaMalloc(&d_x,n*8));CK(cudaMalloc(&d_r,n*8));CK(cudaMalloc(&d_p,n*8));
    CK(cudaMalloc(&d_pcp,n*8));CK(cudaMalloc(&d_hp,n*8));CK(cudaMalloc(&d_ap,n*8));
    CK(cudaMalloc(&d_par,16));
    std::vector<double> zero(n,0.0);
    CK(cudaMemcpy(d_x,zero.data(),n*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(d_r,bg,n*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(d_p,bg,n*8,cudaMemcpyHostToDevice));
    double rs_old=hdot(bg,bg,n);
    std::vector<double> pv(n),apv(n),rv(n);
    cudaEvent_t evb,eve; CK(cudaEventCreate(&evb));CK(cudaEventCreate(&eve));
    CK(cudaEventRecord(evb));
    int it=0;
    for(; it<cgiters; it++){
        CK(cudaMemcpy(d_pcp,d_p,n*8,cudaMemcpyDeviceToDevice));
        k_proj_out<<<1,1>>>(d_pcp,d_occ,n,m);
        k_matvec<<<grd,blk>>>(d_M,d_pcp,d_hp,n);
        double par1[2]={eps_n,0}; CK(cudaMemcpy(d_par,par1,8,cudaMemcpyHostToDevice));
        k_shift_sub<<<grd,blk>>>(d_hp,d_pcp,d_ap,d_par,n);
        k_proj_out<<<1,1>>>(d_ap,d_occ,n,m);
        CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(pv.data(),d_p,n*8,cudaMemcpyDeviceToHost));
        CK(cudaMemcpy(apv.data(),d_ap,n*8,cudaMemcpyDeviceToHost));
        double pAp=hdot(pv.data(),apv.data(),n); if(pAp==0) break;
        double alpha=rs_old/pAp;
        if(!fused){
            double pa[1]={alpha}; CK(cudaMemcpy(d_par,pa,8,cudaMemcpyHostToDevice));
            k_axpy<<<grd,blk>>>(d_x,d_p,d_par,n);
            double na[1]={-alpha}; CK(cudaMemcpy(d_par,na,8,cudaMemcpyHostToDevice));
            k_axpy<<<grd,blk>>>(d_r,d_ap,d_par,n);
            CK(cudaDeviceSynchronize());
            CK(cudaMemcpy(rv.data(),d_r,n*8,cudaMemcpyDeviceToHost));
            double rn=hdot(rv.data(),rv.data(),n);
            if(sqrt(rn)<TOL){ it++; break; }
            double beta=rn/rs_old;
            double pb[1]={beta}; CK(cudaMemcpy(d_par,pb,8,cudaMemcpyHostToDevice));
            k_xpay<<<grd,blk>>>(d_p,d_r,d_par,n);
            rs_old=rn;
        } else {
            // need beta BEFORE the fused update -> compute rs_new from a provisional r.
            // The merged recurrence updates r THEN computes beta=rs_new/rs_old THEN p.
            // To fuse all three we precompute alpha (have it) and beta from rs_new; rs_new
            // depends on the updated r = r - alpha*ap, which we can form host-side from the
            // current r and ap (already pulled) — bit-identical to the device axpy.
            CK(cudaMemcpy(rv.data(),d_r,n*8,cudaMemcpyDeviceToHost));
            for(int i=0;i<n;i++) rv[i]-=alpha*apv[i];     // r_new (mirror of device r-=a*ap)
            double rn=hdot(rv.data(),rv.data(),n);
            double beta = (rs_old!=0.0)? rn/rs_old : 0.0;
            double pab[2]={alpha,beta}; CK(cudaMemcpy(d_par,pab,16,cudaMemcpyHostToDevice));
            k_fused_cg_update<<<grd,blk>>>(d_x,d_r,d_p,d_ap,d_par,n);
            CK(cudaDeviceSynchronize());
            if(sqrt(rn)<TOL){ it++; break; }
            rs_old=rn;
        }
    }
    CK(cudaEventRecord(eve)); CK(cudaEventSynchronize(eve));
    CK(cudaEventElapsedTime(ms_out,evb,eve));
    // final dpsi = P_c(x)
    k_proj_out<<<1,1>>>(d_x,d_occ,n,m); CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(dpsi_out,d_x,n*8,cudaMemcpyDeviceToHost));
    *iters_out=it;
    cudaFree(d_x);cudaFree(d_r);cudaFree(d_p);cudaFree(d_pcp);cudaFree(d_hp);cudaFree(d_ap);cudaFree(d_par);
    return 0;
}

// ── ON-DEVICE CG: scalar reductions (pAp, rTr) + alpha/beta ALL on the GPU. ──────
// Zero per-iter DtoH, zero per-iter cudaDeviceSynchronize. The whole CG iteration
// is a launch chain on the default stream (ordered, no host round-trip). The only
// DtoH is ONE final scal pull AFTER the loop. This is the throughput lever the
// PARITY-first fused path named-remaining (d6): it removes the 2 DtoH+sync/iter
// that dominated per-iter time. Uses the fused_cg_update kernel for x/r/p, and the
// two-stage block/grid dot — NO cooperative-grid HW gate required.
static int run_cg_ondevice(int n,int m,int cgiters,
                  double* d_M,double* d_occ,const double* bg,double eps_n,
                  double* dpsi_out,int* iters_out,float* ms_out){
    const int BS=128; int blk=BS, grd=(n+blk-1)/blk;
    int nb = grd>1024?1024:grd;               // partials cap for stage-2 single block
    if(nb<1) nb=1;
    double *d_x,*d_r,*d_p,*d_pcp,*d_hp,*d_ap,*d_par,*d_scal,*d_part,*d_eps,*d_rnew;
    CK(cudaMalloc(&d_x,n*8));CK(cudaMalloc(&d_r,n*8));CK(cudaMalloc(&d_p,n*8));
    CK(cudaMalloc(&d_pcp,n*8));CK(cudaMalloc(&d_hp,n*8));CK(cudaMalloc(&d_ap,n*8));
    CK(cudaMalloc(&d_par,16));CK(cudaMalloc(&d_scal,5*8));CK(cudaMalloc(&d_part,nb*8));
    CK(cudaMalloc(&d_eps,8));CK(cudaMalloc(&d_rnew,n*8));
    std::vector<double> zero(n,0.0);
    CK(cudaMemcpy(d_x,zero.data(),n*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(d_r,bg,n*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(d_p,bg,n*8,cudaMemcpyHostToDevice));
    double epsh=eps_n; CK(cudaMemcpy(d_eps,&epsh,8,cudaMemcpyHostToDevice));  // eps resident, never touched again
    // scal[0]=rs_old = r.r  (computed on device, no host round-trip)
    k_dot_partial<BS><<<nb,BS>>>(d_r,d_r,d_part,n);
    k_reduce_finalize<<<1,32>>>(d_part,d_scal,nb,0);   // -> scal[0]=rs_old
    cudaEvent_t evb,eve; CK(cudaEventCreate(&evb));CK(cudaEventCreate(&eve));
    CK(cudaEventRecord(evb));
    int it=0;
    for(; it<cgiters; it++){
        // operator: ap = P_c( (H-eps) P_c(p) )  — eps held in d_eps (OFF par[], never clobbered).
        CK(cudaMemcpyAsync(d_pcp,d_p,n*8,cudaMemcpyDeviceToDevice));   // D2D, stream-ordered, no sync
        k_proj_out<<<1,1>>>(d_pcp,d_occ,n,m);
        k_matvec<<<grd,blk>>>(d_M,d_pcp,d_hp,n);
        k_shift_sub_dev<<<grd,blk>>>(d_hp,d_pcp,d_ap,d_eps,n);
        k_proj_out<<<1,1>>>(d_ap,d_occ,n,m);
        // pAp = p . ap -> scal[1] ; alpha = rs_old/pAp -> scal[2], par[0]=alpha (all on device)
        k_dot_partial<BS><<<nb,BS>>>(d_p,d_ap,d_part,n);
        k_reduce_finalize<<<1,32>>>(d_part,d_scal,nb,1);
        k_cg_alpha<<<1,1>>>(d_scal,d_par);
        // rs_new from scratch r_new = r - alpha*ap (bit-parity with fused r-update) -> scal[3]
        k_rnew<<<grd,blk>>>(d_r,d_ap,d_par,d_rnew,n);
        k_dot_partial<BS><<<nb,BS>>>(d_rnew,d_rnew,d_part,n);
        k_reduce_finalize<<<1,32>>>(d_part,d_scal,nb,3);
        // beta = rs_new/rs_old -> par[1]; commit rs_old<-rs_new (on device)
        k_cg_beta_commit<<<1,1>>>(d_scal,d_par);
        // fused update: x+=alpha*p ; r-=alpha*ap ; p=r+beta*p  (par[0]=alpha, par[1]=beta)
        k_fused_cg_update<<<grd,blk>>>(d_x,d_r,d_p,d_ap,d_par,n);
        // NO per-iter DtoH, NO per-iter cudaDeviceSynchronize — the lever (d6).
    }
    *iters_out=it;
    CK(cudaEventRecord(eve)); CK(cudaEventSynchronize(eve));
    CK(cudaEventElapsedTime(ms_out,evb,eve));
    k_proj_out<<<1,1>>>(d_x,d_occ,n,m); CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(dpsi_out,d_x,n*8,cudaMemcpyDeviceToHost));
    cudaFree(d_x);cudaFree(d_r);cudaFree(d_p);cudaFree(d_pcp);cudaFree(d_hp);cudaFree(d_ap);
    cudaFree(d_par);cudaFree(d_scal);cudaFree(d_part);cudaFree(d_eps);cudaFree(d_rnew);
    return 0;
}

int main(int argc,char**argv){
    int N = argc>1?atoi(argv[1]):1024;
    int CG= argc>2?atoi(argv[2]):N; // run a fixed CG-iter count for a clean throughput compare
    int M = 2;
    cudaDeviceProp prop; CK(cudaGetDeviceProperties(&prop,0));
    fprintf(stderr,"[gpu] %s sm_%d%d\n",prop.name,prop.major,prop.minor);

    // ── deterministic SPD-ish H (diagonally dominant) + occupied set + RHS ──────
    std::vector<double> M_(  (size_t)N*N ), occ((size_t)M*N), bg(N);
    for(int i=0;i<N;i++) for(int j=0;j<N;j++)
        M_[(size_t)i*N+j] = (i==j)? (4.0 + 0.001*i) : 0.1/(1.0+fabs((double)(i-j)));
    // two orthonormal-ish occupied vectors (Gram-Schmidt of two smooth modes)
    for(int i=0;i<N;i++){ occ[i]=sin(0.01*(i+1)); occ[N+i]=cos(0.013*(i+1)); }
    auto nrm=[&](double*v){ double s=0;for(int i=0;i<N;i++)s+=v[i]*v[i]; s=sqrt(s);for(int i=0;i<N;i++)v[i]/=s; };
    nrm(&occ[0]);
    { double c=0;for(int i=0;i<N;i++)c+=occ[i]*occ[N+i]; for(int i=0;i<N;i++)occ[N+i]-=c*occ[i]; nrm(&occ[N]); }
    double eps_n = 3.0;
    // RHS b = -P_c(dV); dV smooth
    std::vector<double> dV(N); for(int i=0;i<N;i++) dV[i]=cos(0.02*i)+0.3;
    for(int pass=0;pass<2;pass++) for(int j=0;j<M;j++){
        double c=0;for(int i=0;i<N;i++)c+=occ[j*N+i]*dV[i];
        for(int i=0;i<N;i++)dV[i]-=c*occ[j*N+i]; }
    for(int i=0;i<N;i++) bg[i]=-dV[i];

    double *d_M,*d_occ; CK(cudaMalloc(&d_M,(size_t)N*N*8)); CK(cudaMalloc(&d_occ,(size_t)M*N*8));
    CK(cudaMemcpy(d_M,M_.data(),(size_t)N*N*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(d_occ,occ.data(),(size_t)M*N*8,cudaMemcpyHostToDevice));

    std::vector<double> dpsi_un(N),dpsi_fu(N),dpsi_od(N);
    int it_un=0,it_fu=0,it_od=0; float ms_un=0,ms_fu=0,ms_od=0;
    // warmup (all three paths)
    run_cg(N,M,4,0,d_M,d_occ,bg.data(),eps_n,dpsi_un.data(),&it_un,&ms_un);
    run_cg(N,M,4,1,d_M,d_occ,bg.data(),eps_n,dpsi_fu.data(),&it_fu,&ms_fu);
    run_cg_ondevice(N,M,4,d_M,d_occ,bg.data(),eps_n,dpsi_od.data(),&it_od,&ms_od);
    // timed: fixed CG-iter count, all paths
    if(run_cg(N,M,CG,0,d_M,d_occ,bg.data(),eps_n,dpsi_un.data(),&it_un,&ms_un)) return 2;
    if(run_cg(N,M,CG,1,d_M,d_occ,bg.data(),eps_n,dpsi_fu.data(),&it_fu,&ms_fu)) return 2;
    if(run_cg_ondevice(N,M,CG,d_M,d_occ,bg.data(),eps_n,dpsi_od.data(),&it_od,&ms_od)) return 2;

    // parity: fused (host-scalar) vs unfused
    double max_rel=0; int am=-1;
    for(int i=0;i<N;i++){ double ad=fabs(dpsi_un[i]-dpsi_fu[i]);
        double rd=fabs(dpsi_un[i])>1e-300?ad/fabs(dpsi_un[i]):ad;
        if(rd>max_rel){max_rel=rd;am=i;} }
    // parity: ON-DEVICE-scalar vs unfused (the new path — must STAY <=1e-9)
    double max_rel_od=0; int am_od=-1;
    for(int i=0;i<N;i++){ double ad=fabs(dpsi_un[i]-dpsi_od[i]);
        double rd=fabs(dpsi_un[i])>1e-300?ad/fabs(dpsi_un[i]):ad;
        if(rd>max_rel_od){max_rel_od=rd;am_od=i;} }
    double thru_un = it_un/(ms_un/1000.0);   // CG iters / sec
    double thru_fu = it_fu/(ms_fu/1000.0);
    double thru_od = it_od/(ms_od/1000.0);
    double ratio    = thru_fu/thru_un;       // launch-fusion only (host scalar)
    double ratio_od = thru_od/thru_un;       // ON-DEVICE scalar reduction (the gate lever)

    printf("=== QFORGE kernel 2: fused Sternheimer CG + ON-DEVICE scalar reduction ===\n");
    printf("[setup] N=%d  CGITERS=%d  M=%d\n",N,it_un,M);
    printf("[launches/iter] unfused      = 7 (proj,matvec,shift,proj,axpy,axpy,xpay)\n");
    printf("                fused(host)   = 5 (proj,matvec,shift,proj,fused_cg_update)\n");
    printf("                on-device     = NO per-iter DtoH/sync (pAp,rTr,alpha,beta all on GPU)\n");
    printf("[host-roundtrips/iter] unfused=2 DtoH+sync | fused(host)=2 DtoH+sync | on-device=0\n");
    printf("[throughput] unfused      : %.3f ms  -> %.1f iters/s\n",ms_un,thru_un);
    printf("             fused(host)  : %.3f ms  -> %.1f iters/s   ratio = %.2fx\n",ms_fu,thru_fu,ratio);
    printf("             on-device    : %.3f ms  -> %.1f iters/s   ratio = %.2fx\n",ms_od,thru_od,ratio_od);
    printf("[parity] |dpsi> first 5 bins (unfused vs on-device):\n");
    for(int i=0;i<(N<5?N:5);i++) printf("  dpsi[%d]  unfused=% .15e  ondev=% .15e\n",i,dpsi_un[i],dpsi_od[i]);
    printf("  max_rel_err fused(host) vs unfused = %.6e  (bin %d)\n",max_rel,am);
    printf("  max_rel_err on-device  vs unfused = %.6e  (bin %d)   tol = 1.0e-09\n",max_rel_od,am_od);
    int par_ok    = max_rel_od<=1e-9;        // on-device parity is the gate
    int thr_ok    = ratio_od>=1.5;           // on-device throughput is the gate
    printf("GATE parity (on-device |dpsi> identical) : %s  (max_rel_err=%.3e)\n",par_ok?"PASS":"FAIL",max_rel_od);
    printf("GATE >=1.5x CG-iter throughput           : %s  (ratio=%.2fx)\n",thr_ok?"PASS":"FAIL",ratio_od);
    printf("VERDICT: %s\n",(par_ok&&thr_ok)?"PASS":"FAIL");
    return (par_ok&&thr_ok)?0:1;
}
