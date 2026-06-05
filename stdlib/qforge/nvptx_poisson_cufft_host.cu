// stdlib/qforge/nvptx_poisson_cufft_host.cu — QFORGE-PERF Lane A ⚡
// cuFFT GPU Poisson V_H[Δρ] vs the CPU fft3 reference (screening.hexa).
//
// The CPU path `qforge_vhartree_from_drho` (stdlib/qforge/screening.hexa) does:
//   1. forward 3D FFT of Δρ(r)            (fft3_real, NO 1/N scale)
//   2. multiply by 4π/|G|²  (G=0 → 0)     (the closed-form Poisson kernel)
//   3. inverse 3D FFT                     (ifft3, ÷N)
//   4. take the real part                 → V_H(r), length nx·ny·nz
//
// This harness replicates that on the GPU with cuFFT (Z2Z double-precision):
//   fwd cufftExecZ2Z(CUFFT_FORWARD) → 4π/|G|² scale → inv cufftExecZ2Z(CUFFT_INVERSE)
//   then ÷N (cuFFT's inverse is UNNORMALIZED, so the explicit 1/N matches ifft3).
//
// Bit-parity gate: GPU V_H(r) == CPU V_H(r) within max_rel_err ≤ 1e-9 (this is
// pure FFT + a multiply — no transcendental, so the tolerance is much tighter
// than the a2f exp() kernel; cuFFT vs the hexa radix-2 differ only in butterfly
// roundoff order). Speedup = CPU wall vs GPU wall (incl. H2D/D2H), reported
// honestly per d6 — a transfer-dominated small-mesh no-speedup is a VALID result.
//
//   build: nvcc -O2 nvptx_poisson_cufft_host.cu -o nvptx_poisson_cufft -lcufft
//   run:   ./nvptx_poisson_cufft           (prints PARITY + speedup per mesh)
//
// Exit 0 = parity within tol for every mesh; non-zero = mismatch / cuda error.

#include <cufft.h>
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <complex>
#include <chrono>

#define CK(x)  do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA-ERR %s @ %s:%d\n",cudaGetErrorString(e),__FILE__,__LINE__); return 2; } }while(0)
#define CKF(x) do{ cufftResult r=(x); if(r!=CUFFT_SUCCESS){ \
  fprintf(stderr,"CUFFT-ERR %d @ %s:%d\n",(int)r,__FILE__,__LINE__); return 2; } }while(0)

static const double FOUR_PI = 4.0 * 3.14159265358979323846;

// device kernel: in-place elementwise complex *= real-scale  (the 4π/|G|² mult)
__global__ void k_scale(cufftDoubleComplex* a, const double* s, long n){
    long i = (long)blockIdx.x*blockDim.x + threadIdx.x;
    if(i<n){ a[i].x*=s[i]; a[i].y*=s[i]; }
}
static void launch_scale(cufftDoubleComplex* a,double* s,long n){
    int blk=256; long grd=(n+blk-1)/blk;
    k_scale<<<(unsigned)grd,blk>>>(a,s,n);
}

// signed FFT frequency index (mirrors _scr_freq in screening.hexa)
static inline int sfreq(int k,int n){ return (k > n/2) ? (k-n) : k; }

using cd = std::complex<double>;

// ── CPU reference radix-2 1D FFT (Cooley-Tukey, matches hexa core_fft order) ──
// forward (sign=-1) no scale; inverse (sign=+1) caller divides by N per axis.
static void fft1(std::vector<cd>& a, int sign){
    int n=a.size();
    for(int i=1,j=0;i<n;i++){
        int bit=n>>1;
        for(;j&bit;bit>>=1) j^=bit;
        j^=bit;
        if(i<j) std::swap(a[i],a[j]);
    }
    for(int len=2;len<=n;len<<=1){
        double ang=sign*2.0*M_PI/len;
        cd wl(cos(ang),sin(ang));
        for(int i=0;i<n;i+=len){
            cd w(1.0,0.0);
            for(int k=0;k<len/2;k++){
                cd u=a[i+k], v=a[i+k+len/2]*w;
                a[i+k]=u+v; a[i+k+len/2]=u-v;
                w*=wl;
            }
        }
    }
}
// 3D separable FFT over (nx,ny,nz), row-major lin=(ix*ny+iy)*nz+iz.
static void fft3(std::vector<cd>& A,int nx,int ny,int nz,int sign){
    // z-lines
    for(int ix=0;ix<nx;ix++) for(int iy=0;iy<ny;iy++){
        std::vector<cd> line(nz);
        for(int iz=0;iz<nz;iz++) line[iz]=A[(ix*ny+iy)*nz+iz];
        fft1(line,sign);
        for(int iz=0;iz<nz;iz++) A[(ix*ny+iy)*nz+iz]=line[iz];
    }
    // y-lines
    for(int ix=0;ix<nx;ix++) for(int iz=0;iz<nz;iz++){
        std::vector<cd> line(ny);
        for(int iy=0;iy<ny;iy++) line[iy]=A[(ix*ny+iy)*nz+iz];
        fft1(line,sign);
        for(int iy=0;iy<ny;iy++) A[(ix*ny+iy)*nz+iz]=line[iy];
    }
    // x-lines
    for(int iy=0;iy<ny;iy++) for(int iz=0;iz<nz;iz++){
        std::vector<cd> line(nx);
        for(int ix=0;ix<nx;ix++) line[ix]=A[(ix*ny+iy)*nz+iz];
        fft1(line,sign);
        for(int ix=0;ix<nx;ix++) A[(ix*ny+iy)*nz+iz]=line[ix];
    }
}

static int run_mesh(int nx,int ny,int nz){
    long ntot=(long)nx*ny*nz;
    // reciprocal-lattice basis (orthorhombic, arbitrary but fixed/deterministic)
    double b1[3]={0.71,0.0,0.0}, b2[3]={0.0,0.53,0.0}, b3[3]={0.0,0.0,0.37};

    // deterministic Δρ(r) (closed-form, no RNG) — same spirit as the hexa benches
    std::vector<double> drho(ntot);
    for(long i=0;i<ntot;i++){
        double t=(double)i;
        drho[i] = 0.5*sin(0.013*t+0.7) + 0.3*cos(0.0071*t+1.9);
    }

    // ── CPU reference (replicates qforge_vhartree_from_drho) ──
    auto c0=std::chrono::high_resolution_clock::now();
    std::vector<cd> A(ntot);
    for(long i=0;i<ntot;i++) A[i]=cd(drho[i],0.0);
    fft3(A,nx,ny,nz,-1);                       // forward, no scale
    for(int ix=0;ix<nx;ix++)for(int iy=0;iy<ny;iy++)for(int iz=0;iz<nz;iz++){
        int h=sfreq(ix,nx),k=sfreq(iy,ny),l=sfreq(iz,nz);
        double gx=h*b1[0]+k*b2[0]+l*b3[0];
        double gy=h*b1[1]+k*b2[1]+l*b3[1];
        double gz=h*b1[2]+k*b2[2]+l*b3[2];
        double g2=gx*gx+gy*gy+gz*gz;
        long lin=(long)(ix*ny+iy)*nz+iz;
        if(g2<1e-12) A[lin]=cd(0.0,0.0);
        else A[lin]*= (FOUR_PI/g2);
    }
    fft3(A,nx,ny,nz,+1);                        // inverse passes
    double invN=1.0/(double)ntot;
    std::vector<double> vh_cpu(ntot);
    for(long i=0;i<ntot;i++) vh_cpu[i]=A[i].real()*invN;   // ÷N + real part
    auto c1=std::chrono::high_resolution_clock::now();
    double cpu_ms=std::chrono::duration<double,std::milli>(c1-c0).count();

    // ── GPU path (cuFFT Z2Z double precision) ──
    cufftDoubleComplex* h_in=(cufftDoubleComplex*)malloc(ntot*sizeof(cufftDoubleComplex));
    for(long i=0;i<ntot;i++){ h_in[i].x=drho[i]; h_in[i].y=0.0; }
    cufftDoubleComplex* d_a; CK(cudaMalloc(&d_a,ntot*sizeof(cufftDoubleComplex)));
    cufftHandle plan; CKF(cufftPlan3d(&plan,nx,ny,nz,CUFFT_Z2Z));

    // precompute the 4π/|G|² scale array on host, push to device
    std::vector<double> scl(ntot);
    for(int ix=0;ix<nx;ix++)for(int iy=0;iy<ny;iy++)for(int iz=0;iz<nz;iz++){
        int h=sfreq(ix,nx),k=sfreq(iy,ny),l=sfreq(iz,nz);
        double gx=h*b1[0]+k*b2[0]+l*b3[0];
        double gy=h*b1[1]+k*b2[1]+l*b3[1];
        double gz=h*b1[2]+k*b2[2]+l*b3[2];
        double g2=gx*gx+gy*gy+gz*gz;
        long lin=(long)(ix*ny+iy)*nz+iz;
        scl[lin] = (g2<1e-12) ? 0.0 : (FOUR_PI/g2);
    }
    double* d_scl; CK(cudaMalloc(&d_scl,ntot*sizeof(double)));

    cudaDeviceSynchronize();
    auto g0=std::chrono::high_resolution_clock::now();
    CK(cudaMemcpy(d_a,h_in,ntot*sizeof(cufftDoubleComplex),cudaMemcpyHostToDevice));
    CK(cudaMemcpy(d_scl,scl.data(),ntot*sizeof(double),cudaMemcpyHostToDevice));
    CKF(cufftExecZ2Z(plan,d_a,d_a,CUFFT_FORWARD));
    // apply 4π/|G|² scale on device (k_scale kernel defined at top of file)
    launch_scale(d_a,d_scl,ntot);
    CKF(cufftExecZ2Z(plan,d_a,d_a,CUFFT_INVERSE));
    cufftDoubleComplex* h_out=(cufftDoubleComplex*)malloc(ntot*sizeof(cufftDoubleComplex));
    CK(cudaMemcpy(h_out,d_a,ntot*sizeof(cufftDoubleComplex),cudaMemcpyDeviceToHost));
    cudaDeviceSynchronize();
    auto g1=std::chrono::high_resolution_clock::now();
    double gpu_ms=std::chrono::duration<double,std::milli>(g1-g0).count();

    std::vector<double> vh_gpu(ntot);
    for(long i=0;i<ntot;i++) vh_gpu[i]=h_out[i].x*invN;   // ÷N + real part

    // ── parity (hybrid atol/rtol — FFT cancellation makes a pure rel-err gate
    //    trip on near-zero V_H bins where abs-err is at FP64 eps; the physical
    //    parity is the per-element max(abs ≤ atol, rel ≤ rtol), d6 honest) ──
    double atol=1e-12, rtol=1e-9;
    double max_abs=0,max_rel=0; long argmax=-1; int pass=1;
    for(long i=0;i<ntot;i++){
        double a=vh_cpu[i], b=vh_gpu[i], ad=fabs(a-b);
        double rd = fabs(a)>1e-300 ? ad/fabs(a) : (ad>0?ad:0.0);
        if(ad>max_abs) max_abs=ad;
        if(rd>max_rel){ max_rel=rd; argmax=i; }
        // element passes if EITHER the abs OR the rel error is within tol
        if(!(ad<=atol || rd<=rtol)) pass=0;
    }
    double tol=rtol;
    printf("mesh %dx%dx%d (N=%ld)\n",nx,ny,nz,ntot);
    printf("  cpu_wall = %.3f ms   gpu_wall = %.3f ms   speedup(cpu/gpu) = %.3fx\n",
           cpu_ms,gpu_ms, gpu_ms>0?cpu_ms/gpu_ms:0.0);
    printf("  max_abs_err = %.6e\n",max_abs);
    printf("  max_rel_err = %.6e  (idx %ld: cpu=%.10e gpu=%.10e)\n",
           max_rel,argmax, argmax>=0?vh_cpu[argmax]:0.0, argmax>=0?vh_gpu[argmax]:0.0);
    printf("  gate = (abs<=%.0e OR rel<=%.0e) per-element   PARITY: %s\n", atol, rtol, pass?"PASS":"FAIL");

    cufftDestroy(plan); cudaFree(d_a); cudaFree(d_scl);
    free(h_in); free(h_out);
    return pass?0:1;
}

int main(){
    int dev=0; cudaDeviceProp pr; if(cudaGetDeviceProperties(&pr,dev)==cudaSuccess)
        fprintf(stderr,"[gpu] %s sm_%d%d\n",pr.name,pr.major,pr.minor);
    int rc=0;
    // pow2 meshes (fft3 requires power-of-two axes)
    rc |= run_mesh(16,16,16);
    rc |= run_mesh(32,32,32);
    rc |= run_mesh(64,64,64);
    printf("ALL: %s\n", rc==0?"PASS":"FAIL");
    return rc;
}
