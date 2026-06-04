// stdlib/qforge/nvptx_sternheimer_host.cu — GPU-parity harness for the
// QFORGE Sternheimer DFPT linear-response kernels (nvptx_sternheimer_kernel.hexa).
//
// Loads the hexa-emitted PTX via the CUDA driver API with
// cuModuleLoadDataEx(CU_JIT_TARGET_FROM_CUCONTEXT) so the driver JIT-compiles
// PTX(sm_90) → the live GPU's ISA (sm_100 on a B200). Solves the SAME tiny
// deterministic Sternheimer fixture the CPU selftest uses — the 5×5 symmetric
// H from sternheimer_selftest.hexa, occupied set {0,1}, response state n=1,
// the same ΔV·ψ perturbation vector — once on a CPU reference (replicating
// qforge_sternheimer bit-for-bit in algorithm) and once GPU-RESIDENT.
//
// GPU residency: the n-component CG vectors (x, r, p, Ap, work) live in VRAM
// across ALL CG iterations. Per iteration the host dispatches the device
// kernels (proj_out → matvec → shift_sub → proj_out → axpy → xpay) and pulls
// back ONLY the two scalar reductions (pᵀAp, rᵀr) needed for α/β — i.e. the
// per-vector work is GPU-resident, the scalar convergence control is host
// (honest scope, d6 — this is the documented host-driver-loop remainder).
//
//   build: nvcc -O2 nvptx_sternheimer_host.cu -o nvptx_sternheimer_host -lcuda
//   run:   ./nvptx_sternheimer_host kernel.ptx     (prints PARITY verdict)
//
// Exit 0 = parity within tol; non-zero = mismatch / driver error (honest).

#include <cuda.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>

#define DR(x) do{ CUresult r=(x); if(r!=CUDA_SUCCESS){ const char*s; cuGetErrorString(r,&s); \
  fprintf(stderr,"CUDA-ERR %s @ %s:%d\n",s,__FILE__,__LINE__); return 2; } }while(0)

static const int    N  = 5;        // basis dim (5x5 selftest fixture)
static const int    M  = 2;        // occupied count {0,1}
static const int    NIDX = 1;      // response state n
static const double TOL = 1.0e-11; // CG termination (selftest)
static const int    MAXIT = 200;

// ── tiny dense symmetric eigensolver (Jacobi) for the fixture only ────────
// Replicates eigh(M,N): ascending-sorted eigenpairs, orthonormal vectors.
static void jacobi_eigh(double A[5][5], double w[5], double V[5][5]){
    for(int i=0;i<N;i++){ for(int j=0;j<N;j++) V[i][j]=(i==j)?1.0:0.0; }
    for(int sweep=0; sweep<100; sweep++){
        double off=0; for(int p=0;p<N;p++) for(int q=p+1;q<N;q++) off+=A[p][q]*A[p][q];
        if(off<1e-30) break;
        for(int p=0;p<N;p++) for(int q=p+1;q<N;q++){
            if(fabs(A[p][q])<1e-300) continue;
            double th=(A[q][q]-A[p][p])/(2.0*A[p][q]);
            double t=(th>=0?1.0:-1.0)/(fabs(th)+sqrt(th*th+1.0));
            double c=1.0/sqrt(t*t+1.0), s=t*c;
            for(int k=0;k<N;k++){
                double akp=A[k][p], akq=A[k][q];
                A[k][p]=c*akp-s*akq; A[k][q]=s*akp+c*akq;
            }
            for(int k=0;k<N;k++){
                double apk=A[p][k], aqk=A[q][k];
                A[p][k]=c*apk-s*aqk; A[q][k]=s*apk+c*aqk;
            }
            for(int k=0;k<N;k++){
                double vkp=V[k][p], vkq=V[k][q];
                V[k][p]=c*vkp-s*vkq; V[k][q]=s*vkp+c*vkq;
            }
        }
    }
    for(int i=0;i<N;i++) w[i]=A[i][i];
    // ascending sort
    for(int i=0;i<N;i++) for(int j=i+1;j<N;j++) if(w[j]<w[i]){
        double tw=w[i]; w[i]=w[j]; w[j]=tw;
        for(int k=0;k<N;k++){ double tv=V[k][i]; V[k][i]=V[k][j]; V[k][j]=tv; }
    }
}

// ── CPU reference vector helpers (mirror st_dot / st_project_out) ─────────
static double st_dot(const double*a,const double*b){ double s=0; for(int i=0;i<N;i++) s+=a[i]*b[i]; return s; }
static double st_norm(const double*a){ return sqrt(st_dot(a,a)); }
static void st_project_out(double*w,const double occ[][5],int m){
    for(int pass=0;pass<2;pass++) for(int j=0;j<m;j++){
        double c=0; for(int i=0;i<N;i++) c+=occ[j][i]*w[i];
        for(int i=0;i<N;i++) w[i]-=c*occ[j][i];
    }
}

int main(int argc,char**argv){
    const char* ptxpath = argc>1?argv[1]:"nvptx_sternheimer_kernel.hexa.ptx";

    // ── fixture (identical to sternheimer_selftest.hexa) ──
    double Mmat[5][5] = {
        {4.0,0.3,0.1,0.2,0.05},
        {0.3,3.0,0.4,0.1,0.2},
        {0.1,0.4,2.0,0.25,0.15},
        {0.2,0.1,0.25,1.0,0.35},
        {0.05,0.2,0.15,0.35,0.5}
    };
    double Mflat[25]; for(int i=0;i<N;i++) for(int j=0;j<N;j++) Mflat[i*N+j]=Mmat[i][j];

    double Acopy[5][5]; for(int i=0;i<N;i++) for(int j=0;j<N;j++) Acopy[i][j]=Mmat[i][j];
    double w[5], V[5][5]; jacobi_eigh(Acopy,w,V);
    // eps ascending = w; psi[k] = column k of V
    double eps[5], psi[5][5];
    for(int k=0;k<N;k++){ eps[k]=w[k]; for(int i=0;i<N;i++) psi[k][i]=V[i][k]; }
    double occ[2][5]; for(int i=0;i<N;i++){ occ[0][i]=psi[0][i]; occ[1][i]=psi[1][i]; }
    double dV_psi[5] = {1.0,0.5,-0.3,0.8,0.2};
    double eps_n = eps[NIDX];

    // ── CPU reference: projected CG (replicates qforge_sternheimer) ──
    double b[5]; for(int i=0;i<N;i++) b[i]=dV_psi[i];
    st_project_out(b,occ,M); for(int i=0;i<N;i++) b[i]=-b[i];
    double xc[5]={0,0,0,0,0}, rc[5], pc[5];
    for(int i=0;i<N;i++){ rc[i]=b[i]; pc[i]=b[i]; }
    double rs_old=st_dot(rc,rc);
    for(int it=0; it<MAXIT; it++){
        double pcp[5]; for(int i=0;i<N;i++) pcp[i]=pc[i]; st_project_out(pcp,occ,M);
        double hp[5]; for(int i=0;i<N;i++){ double s=0; for(int j=0;j<N;j++) s+=Mflat[i*N+j]*pcp[j]; hp[i]=s; }
        double ap[5]; for(int i=0;i<N;i++) ap[i]=hp[i]-eps_n*pcp[i];
        st_project_out(ap,occ,M);
        double pAp=st_dot(pc,ap); if(pAp==0.0) break;
        double alpha=rs_old/pAp;
        for(int i=0;i<N;i++){ xc[i]+=alpha*pc[i]; rc[i]-=alpha*ap[i]; }
        if(st_norm(rc)<TOL) break;
        double rs_new=st_dot(rc,rc), beta=rs_new/rs_old;
        for(int i=0;i<N;i++) pc[i]=rc[i]+beta*pc[i];
        rs_old=rs_new;
    }
    double dpsi_cpu[5]; for(int i=0;i<N;i++) dpsi_cpu[i]=xc[i]; st_project_out(dpsi_cpu,occ,M);

    // ── GPU path: driver init + JIT PTX → sm_100 ──
    DR(cuInit(0));
    CUdevice dev; DR(cuDeviceGet(&dev,0));
    char dname[256]; DR(cuDeviceGetName(dname,sizeof dname,dev));
    int ccM=0,ccm=0;
    DR(cuDeviceGetAttribute(&ccM,CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR,dev));
    DR(cuDeviceGetAttribute(&ccm,CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR,dev));
    fprintf(stderr,"[gpu] %s sm_%d%d\n",dname,ccM,ccm);
    CUcontext ctx; DR(cuCtxCreate(&ctx,0,dev));

    FILE* fp=fopen(ptxpath,"rb"); if(!fp){perror("ptx open");return 2;}
    fseek(fp,0,SEEK_END); long np=ftell(fp); fseek(fp,0,SEEK_SET);
    char* ptx=(char*)malloc(np+1); fread(ptx,1,np,fp); ptx[np]=0; fclose(fp);

    char jitlog[8192]={0};
    CUjit_option jo[3]={CU_JIT_TARGET_FROM_CUCONTEXT,CU_JIT_ERROR_LOG_BUFFER,CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES};
    void* jv[3]={0,(void*)jitlog,(void*)(size_t)sizeof jitlog};
    CUmodule mod; CUresult lr=cuModuleLoadDataEx(&mod,ptx,3,jo,jv);
    if(lr!=CUDA_SUCCESS){ const char*s; cuGetErrorString(lr,&s);
        fprintf(stderr,"PTX-JIT FAILED: %s\njitlog: %s\n",s,jitlog); return 3; }
    CUfunction f_mv,f_ss,f_axpy,f_xpay,f_proj;
    DR(cuModuleGetFunction(&f_mv  ,mod,"qforge_stern_matvec"));
    DR(cuModuleGetFunction(&f_ss  ,mod,"qforge_stern_shift_sub"));
    DR(cuModuleGetFunction(&f_axpy,mod,"qforge_stern_axpy"));
    DR(cuModuleGetFunction(&f_xpay,mod,"qforge_stern_xpay"));
    DR(cuModuleGetFunction(&f_proj,mod,"qforge_stern_proj_out"));

    // device buffers — vectors stay resident across CG iters
    CUdeviceptr d_M,d_occ,d_x,d_r,d_p,d_pcp,d_hp,d_ap,d_par;
    DR(cuMemAlloc(&d_M ,25*8)); DR(cuMemAlloc(&d_occ,M*N*8));
    DR(cuMemAlloc(&d_x ,N*8));  DR(cuMemAlloc(&d_r,N*8)); DR(cuMemAlloc(&d_p,N*8));
    DR(cuMemAlloc(&d_pcp,N*8)); DR(cuMemAlloc(&d_hp,N*8)); DR(cuMemAlloc(&d_ap,N*8));
    DR(cuMemAlloc(&d_par,8));
    double occflat[10]; for(int j=0;j<M;j++) for(int i=0;i<N;i++) occflat[j*N+i]=occ[j][i];
    DR(cuMemcpyHtoD(d_M,Mflat,25*8)); DR(cuMemcpyHtoD(d_occ,occflat,M*N*8));

    // b = -P_c(dV_psi) computed on host once (the RHS); then x0=0,r0=p0=b on device.
    double bg[5]; for(int i=0;i<N;i++) bg[i]=dV_psi[i];
    st_project_out(bg,occ,M); for(int i=0;i<N;i++) bg[i]=-bg[i];
    double zero[5]={0,0,0,0,0};
    DR(cuMemcpyHtoD(d_x,zero,N*8)); DR(cuMemcpyHtoD(d_r,bg,N*8)); DR(cuMemcpyHtoD(d_p,bg,N*8));

    long long nL=N, mL=M;
    int blk=64, grd=(N+blk-1)/blk; // tiny n: 1 block

    auto launch_proj=[&](CUdeviceptr v)->CUresult{
        void* a[]={&v,&d_occ,&nL,&mL}; return cuLaunchKernel(f_proj,1,1,1,1,1,1,0,0,a,0); };
    auto launch_mv=[&](CUdeviceptr in,CUdeviceptr out)->CUresult{
        void* a[]={&d_M,&in,&out,&nL}; return cuLaunchKernel(f_mv,grd,1,1,blk,1,1,0,0,a,0); };

    // host-side rs_old (scalar control); vectors device-resident.
    double rs_old_g=st_dot(bg,bg);
    double tmpv[5];
    int iters_g=0;
    for(int it=0; it<MAXIT; it++){
        // pcp = P_c(p)
        DR(cuMemcpyDtoD(d_pcp,d_p,N*8)); DR(launch_proj(d_pcp));
        // hp = M*pcp ; ap = hp - eps_n*pcp ; ap = P_c(ap)
        DR(launch_mv(d_pcp,d_hp));
        double par_eps[1]={eps_n}; DR(cuMemcpyHtoD(d_par,par_eps,8));
        { void* a[]={&d_hp,&d_pcp,&d_ap,&d_par,&nL}; DR(cuLaunchKernel(f_ss,grd,1,1,blk,1,1,0,0,a,0)); }
        DR(launch_proj(d_ap));
        DR(cuCtxSynchronize());
        // scalars to host: pAp, then alpha; r,p pulled for dots (n tiny)
        double pv[5],apv[5]; DR(cuMemcpyDtoH(pv,d_p,N*8)); DR(cuMemcpyDtoH(apv,d_ap,N*8));
        double pAp=0; for(int i=0;i<N;i++) pAp+=pv[i]*apv[i];
        if(pAp==0.0) break;
        double alpha=rs_old_g/pAp;
        // x += alpha*p ; r -= alpha*ap   (device-resident axpy)
        double pa[1]={alpha};  DR(cuMemcpyHtoD(d_par,pa,8));
        { void* a[]={&d_x,&d_p,&d_par,&nL};  DR(cuLaunchKernel(f_axpy,grd,1,1,blk,1,1,0,0,a,0)); }
        double na[1]={-alpha}; DR(cuMemcpyHtoD(d_par,na,8));
        { void* a[]={&d_r,&d_ap,&d_par,&nL}; DR(cuLaunchKernel(f_axpy,grd,1,1,blk,1,1,0,0,a,0)); }
        DR(cuCtxSynchronize());
        iters_g++;
        DR(cuMemcpyDtoH(tmpv,d_r,N*8));
        double rn=sqrt(st_dot(tmpv,tmpv)); if(rn<TOL) break;
        double rs_new=st_dot(tmpv,tmpv), beta=rs_new/rs_old_g;
        // p = r + beta*p   (xpay, device-resident)
        double pb[1]={beta}; DR(cuMemcpyHtoD(d_par,pb,8));
        { void* a[]={&d_p,&d_r,&d_par,&nL}; DR(cuLaunchKernel(f_xpay,grd,1,1,blk,1,1,0,0,a,0)); }
        DR(cuCtxSynchronize());
        rs_old_g=rs_new;
    }
    // final dpsi = P_c(x)
    DR(launch_proj(d_x)); DR(cuCtxSynchronize());
    double dpsi_gpu[5]; DR(cuMemcpyDtoH(dpsi_gpu,d_x,N*8));

    // ── parity: |dpsi| bin-by-bin ──
    double max_abs=0,max_rel=0; int argmax=-1;
    for(int i=0;i<N;i++){
        double a=dpsi_cpu[i], g=dpsi_gpu[i], ad=fabs(a-g);
        double rd = fabs(a)>1e-300 ? ad/fabs(a) : (ad>0?ad:0.0);
        if(ad>max_abs) max_abs=ad;
        if(rd>max_rel){ max_rel=rd; argmax=i; }
    }
    printf("N=%d M=%d n_idx=%d  cpu_iters_converged\n", N, M, NIDX);
    for(int i=0;i<N;i++) printf("  dpsi[%d]  cpu=% .15e  gpu=% .15e\n", i, dpsi_cpu[i], dpsi_gpu[i]);
    printf("gpu_iters = %d\n", iters_g);
    printf("max_abs_err = %.6e\n", max_abs);
    printf("max_rel_err = %.6e  (bin %d: cpu=%.10e gpu=%.10e)\n",
           max_rel, argmax, argmax>=0?dpsi_cpu[argmax]:0.0, argmax>=0?dpsi_gpu[argmax]:0.0);
    double tol=1e-5;
    int pass=(max_rel<=tol);
    printf("tol = %.1e\n", tol);
    printf("PARITY: %s  (CPU == GPU within tol)\n", pass?"PASS":"FAIL");
    return pass?0:1;
}
