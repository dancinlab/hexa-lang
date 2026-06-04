// stdlib/qforge/nvptx_a2f_host.cu — M27 GPU-parity harness for qforge_a2f_bzsum.
//
// Loads the hexa-emitted PTX (stdlib/qforge/nvptx_a2f_kernel.hexa.ptx) via the
// CUDA driver API with cuModuleLoadDataEx(CU_JIT_TARGET_FROM_CUCONTEXT) so the
// driver JIT-compiles PTX(sm_90) → the live GPU's ISA (sm_120 on Blackwell).
// Feeds a deterministic synthetic (q,ν) el-ph dataset, runs the GPU kernel,
// and compares α²F bins against a CPU reference that replicates the hexa CPU
// path `qforge_a2f_from_elph_impl` (stdlib/qforge/elph.hexa) bit-for-bit in
// algorithm (FP64, same Gaussian, same accumulation order).
//
//   build:  nvcc -O2 nvptx_a2f_host.cu -o nvptx_a2f_host -lcuda
//   run:    ./nvptx_a2f_host kernel.ptx            (prints PARITY verdict)
//
// Exit 0 = parity within tol; non-zero = mismatch / driver error (honest).

#include <cuda.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>

#define DR(x) do{ CUresult r=(x); if(r!=CUDA_SUCCESS){ const char*s; cuGetErrorString(r,&s); \
  fprintf(stderr,"CUDA-ERR %s @ %s:%d\n",s,__FILE__,__LINE__); return 2; } }while(0)

static const double SQRT2PI = 2.5066282746310002; // √(2π)

// δ_σ(x) = exp(−x²/2σ²)/(σ√(2π)) — the exact CPU-ref normalized Gaussian.
static inline double gdelta(double x, double sigma){
    if (sigma <= 0.0) return 0.0;
    double z = x / sigma;
    return exp(-0.5*z*z) / (sigma*SQRT2PI);
}

int main(int argc, char** argv){
    const char* ptxpath = argc>1 ? argv[1] : "nvptx_a2f_kernel.hexa.ptx";

    // ── deterministic synthetic (q,ν) dataset (no RNG dep — reproducible) ──
    // ns samples spread around E_F, a few phonon branches; ng ω-bins.
    const int ns = 4096;
    const int ng = 256;
    double e_fermi = 0.30, n_ef = 2.5, weight = 1.0/(double)ns;
    double sigma_el = 0.05, sigma_ph = 0.02;

    double *eps_k=(double*)malloc(ns*8), *eps_kq=(double*)malloc(ns*8);
    double *g2=(double*)malloc(ns*8),   *omq=(double*)malloc(ns*8);
    double *wgrid=(double*)malloc(ng*8);
    for(int i=0;i<ns;i++){
        // deterministic spread (LCG-free closed form): sin/cos hashes
        double t = (double)i;
        eps_k[i]  = e_fermi + 0.12*sin(0.013*t + 0.7);
        eps_kq[i] = e_fermi + 0.12*sin(0.017*t + 1.9);
        g2[i]     = 0.5 + 0.4*(0.5+0.5*sin(0.011*t));      // |g|² ≥ 0
        omq[i]    = 0.10 + 0.80*(0.5+0.5*sin(0.007*t+2.1)); // ω ∈ (0.1,0.9)
    }
    for(int j=0;j<ng;j++) wgrid[j] = 0.0 + (1.0-0.0)*((double)j/(double)(ng-1));

    double par[8] = { e_fermi, n_ef, weight, sigma_el, sigma_ph,
                      1.0/SQRT2PI, (double)ns, (double)ng };

    // ── CPU reference (replicates qforge_a2f_from_elph_impl) ──
    double* a2f_cpu=(double*)calloc(ng,8);
    double inv_nef = 1.0/n_ef;
    for(int i=0;i<ns;i++){
        double dk  = gdelta(eps_k[i]-e_fermi, sigma_el);
        double dkq = gdelta(eps_kq[i]-e_fermi, sigma_el);
        double wgt = weight*g2[i]*dk*dkq*inv_nef;
        if(wgt!=0.0){
            double wq=omq[i];
            for(int j=0;j<ng;j++)
                a2f_cpu[j] += wgt*gdelta(wgrid[j]-wq, sigma_ph);
        }
    }

    // ── GPU path: driver init + JIT PTX → sm_120 ──
    DR(cuInit(0));
    CUdevice dev; DR(cuDeviceGet(&dev,0));
    char dname[256]; DR(cuDeviceGetName(dname,sizeof dname,dev));
    int cc_major=0,cc_minor=0;
    DR(cuDeviceGetAttribute(&cc_major,CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR,dev));
    DR(cuDeviceGetAttribute(&cc_minor,CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR,dev));
    fprintf(stderr,"[gpu] %s sm_%d%d\n",dname,cc_major,cc_minor);
    CUcontext ctx; DR(cuCtxCreate(&ctx,0,dev));

    FILE* fp=fopen(ptxpath,"rb"); if(!fp){perror("ptx open");return 2;}
    fseek(fp,0,SEEK_END); long np=ftell(fp); fseek(fp,0,SEEK_SET);
    char* ptx=(char*)malloc(np+1); fread(ptx,1,np,fp); ptx[np]=0; fclose(fp);

    // JIT log capture so a PTX→SASS failure is reported honestly (not silent).
    char jitlog[8192]={0};
    CUjit_option jo[3]={CU_JIT_TARGET_FROM_CUCONTEXT,
                        CU_JIT_ERROR_LOG_BUFFER,
                        CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES};
    void* jv[3]={0,(void*)jitlog,(void*)(size_t)sizeof jitlog};
    CUmodule mod;
    CUresult lr=cuModuleLoadDataEx(&mod,ptx,3,jo,jv);
    if(lr!=CUDA_SUCCESS){
        const char* s; cuGetErrorString(lr,&s);
        fprintf(stderr,"PTX-JIT FAILED: %s\njitlog: %s\n",s,jitlog);
        return 3;
    }
    CUfunction fn; DR(cuModuleGetFunction(&fn,mod,"qforge_a2f_bzsum"));

    CUdeviceptr d_ek,d_ekq,d_g2,d_omq,d_wg,d_par,d_a2f;
    DR(cuMemAlloc(&d_ek,ns*8)); DR(cuMemAlloc(&d_ekq,ns*8));
    DR(cuMemAlloc(&d_g2,ns*8)); DR(cuMemAlloc(&d_omq,ns*8));
    DR(cuMemAlloc(&d_wg,ng*8)); DR(cuMemAlloc(&d_par,8*8));
    DR(cuMemAlloc(&d_a2f,ng*8));
    DR(cuMemcpyHtoD(d_ek,eps_k,ns*8));  DR(cuMemcpyHtoD(d_ekq,eps_kq,ns*8));
    DR(cuMemcpyHtoD(d_g2,g2,ns*8));     DR(cuMemcpyHtoD(d_omq,omq,ns*8));
    DR(cuMemcpyHtoD(d_wg,wgrid,ng*8));  DR(cuMemcpyHtoD(d_par,par,8*8));

    long long nsL=ns, ngL=ng;
    void* kargs[]={&d_ek,&d_ekq,&d_g2,&d_omq,&d_wg,&d_par,&d_a2f,&nsL,&ngL};
    int block=128, grid=(ng+block-1)/block;
    DR(cuLaunchKernel(fn,grid,1,1, block,1,1, 0,0, kargs,0));
    DR(cuCtxSynchronize());

    double* a2f_gpu=(double*)malloc(ng*8);
    DR(cuMemcpyDtoH(a2f_gpu,d_a2f,ng*8));

    // ── parity ──
    double max_abs=0, max_rel=0, sum_cpu=0; int argmax=-1;
    for(int j=0;j<ng;j++){
        double a=a2f_cpu[j], b=a2f_gpu[j];
        double ad=fabs(a-b);
        double rd= fabs(a)>1e-300 ? ad/fabs(a) : (ad>0?ad:0.0);
        sum_cpu+=a;
        if(ad>max_abs) max_abs=ad;
        if(rd>max_rel){ max_rel=rd; argmax=j; }
    }
    printf("ns=%d ng=%d  sum_cpu=%.10e\n", ns, ng, sum_cpu);
    printf("max_abs_err = %.6e\n", max_abs);
    printf("max_rel_err = %.6e  (bin %d: cpu=%.10e gpu=%.10e)\n",
           max_rel, argmax, argmax>=0?a2f_cpu[argmax]:0.0, argmax>=0?a2f_gpu[argmax]:0.0);

    // tol: FP64 exp() is the hexa #1215 polynomial (degree-10 Taylor + 2^k),
    // NOT libm exp — so GPU vs CPU-libm differs at the polynomial's accuracy
    // (~1e-13 rel per exp, compounded over ns Horner sums). 1e-5 is the gate.
    double tol = 1e-5;
    int pass = (max_rel <= tol);
    printf("tol = %.1e\n", tol);
    printf("PARITY: %s  (CPU == GPU within tol)\n", pass?"PASS":"FAIL");
    return pass?0:1;
}
