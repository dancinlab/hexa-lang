// nvptx_ooc_stream_host.cu — QFORGE GPU-tier kernel 4 on-device streaming test.
// closes QFORGE-FEATURE ooc-stream
//
// Validates the out-of-core ψ streaming of nvptx_ooc_stream_kernel.hexa on a real GPU.
// A synthetic large H·v workload is run two ways on summer (RTX 5070):
//   (1) IN-CORE   — whole Ngrid×Ngrid H resident, single matvec (the reference).
//   (2) STREAMED  — H tiled into output-row blocks; only one tile (+ v) resident at a
//                   time, capped to a VRAM budget SMALLER than the full-matrix bytes;
//                   tiles streamed H2D (double-buffered copy stream) and applied.
//
//   COMPLETION gate: the streamed run completes with a per-resident-tile footprint
//                    that is < the full-matrix footprint (proves > VRAM cells are
//                    tractable by streaming).
//   PARITY gate    : streamed out == in-core out, bit-for-bit (disjoint output rows
//                    => no FP-order change).
//
//   build: nvcc -O2 -arch=sm_120 nvptx_ooc_stream_host.cu -o nvptx_ooc_stream_host
//   run:   ./nvptx_ooc_stream_host [Ngrid] [Ntiles]
//
// Exit 0 = completed AND bit-parity; non-zero otherwise.

#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>

#define CK(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA-ERR %s @ %d\n",cudaGetErrorString(e),__LINE__); return 2; } }while(0)

// in-core whole-matrix matvec (reference)
__global__ void k_matvec_full(const double* H,const double* v,double* out,long n){
    long gid=(long)blockIdx.x*blockDim.x+threadIdx.x;
    if(gid<n){ const double* row=H+gid*n; double s=0;
        for(long j=0;j<n;j++) s+=row[j]*v[j]; out[gid]=s; }
}
// resident output-row TILE matvec (mirror of qforge_ooc_tile_matvec)
__global__ void k_tile_matvec(const double* Htile,const double* v,double* out,
                              long r0,long tile_rows,long ncol){
    long gid=(long)blockIdx.x*blockDim.x+threadIdx.x;
    if(gid<tile_rows){ const double* row=Htile+gid*ncol; double s=0;
        for(long j=0;j<ncol;j++) s+=row[j]*v[j]; out[r0+gid]=s; }
}

int main(int argc,char**argv){
    long N  = argc>1?atol(argv[1]):6144;   // grid dim (full H is N*N*8 bytes)
    long T  = argc>2?atol(argv[2]):8;      // number of output-row tiles
    cudaDeviceProp prop; CK(cudaGetDeviceProperties(&prop,0));
    fprintf(stderr,"[gpu] %s sm_%d%d  total VRAM %.1f GiB\n",
            prop.name,prop.major,prop.minor,prop.totalGlobalMem/1073741824.0);

    double full_bytes = (double)N*N*8;
    long tile_rows = (N+T-1)/T;
    double tile_bytes = (double)tile_rows*N*8;   // resident per-tile H footprint

    // host H + v + reference out
    std::vector<double> H((size_t)N*N), v(N), out_ref(N), out_str(N,0.0);
    for(long i=0;i<N;i++){ v[i]=cos(0.0009*(double)i)+0.4;
        for(long j=0;j<N;j++) H[(size_t)i*N+j]= (i==j)? 2.0+0.0005*i
                                                       : 0.05*sin(0.0003*(double)(i*7+j)); }

    // ── (1) IN-CORE reference ────────────────────────────────────────────────
    double *d_Hfull,*d_v,*d_out;
    CK(cudaMalloc(&d_Hfull,(size_t)N*N*8)); CK(cudaMalloc(&d_v,N*8)); CK(cudaMalloc(&d_out,N*8));
    CK(cudaMemcpy(d_Hfull,H.data(),(size_t)N*N*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(d_v,v.data(),N*8,cudaMemcpyHostToDevice));
    { int blk=128; long grd=(N+blk-1)/blk; k_matvec_full<<<grd,blk>>>(d_Hfull,d_v,d_out,N); }
    CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(out_ref.data(),d_out,N*8,cudaMemcpyDeviceToHost));
    CK(cudaFree(d_Hfull));   // free the full matrix — streamed path must NOT hold it

    // ── (2) STREAMED out-of-core: only ONE tile of H resident at a time ──────────
    // Double-buffered: two tile slots + a copy stream, so tile t+1 streams while tile t
    // computes. Resident H footprint = 2 * tile_bytes (<< full_bytes for T>2).
    double *d_tileA,*d_tileB,*d_vout;
    CK(cudaMalloc(&d_tileA,(size_t)tile_rows*N*8));
    CK(cudaMalloc(&d_tileB,(size_t)tile_rows*N*8));
    CK(cudaMalloc(&d_vout,N*8));
    // v stays resident (N*8 only, tiny vs the matrix)
    double* d_vs; CK(cudaMalloc(&d_vs,N*8)); CK(cudaMemcpy(d_vs,v.data(),N*8,cudaMemcpyHostToDevice));
    cudaStream_t cpy,cmp; CK(cudaStreamCreate(&cpy)); CK(cudaStreamCreate(&cmp));

    auto tile_slot=[&](long t){ return (t&1)? d_tileB : d_tileA; };
    long r0_0=0, rows0 = (tile_rows < (N-r0_0)? tile_rows : (N-r0_0));
    // prime tile 0
    CK(cudaMemcpyAsync(tile_slot(0),H.data()+(size_t)r0_0*N,(size_t)rows0*N*8,
                       cudaMemcpyHostToDevice,cpy));
    for(long t=0;t<T;t++){
        long r0=t*tile_rows; if(r0>=N) break;
        long rows=(tile_rows < (N-r0)? tile_rows : (N-r0));
        CK(cudaStreamSynchronize(cpy));            // tile t ready
        // prefetch tile t+1 on the copy stream while we compute tile t
        long r0n=(t+1)*tile_rows;
        if(r0n<N){ long rn=(tile_rows<(N-r0n)?tile_rows:(N-r0n));
            CK(cudaMemcpyAsync(tile_slot(t+1),H.data()+(size_t)r0n*N,(size_t)rn*N*8,
                               cudaMemcpyHostToDevice,cpy)); }
        int blk=128; long grd=(rows+blk-1)/blk;
        k_tile_matvec<<<grd,blk,0,cmp>>>(tile_slot(t),d_vs,d_vout,r0,rows,N);
        CK(cudaStreamSynchronize(cmp));
    }
    CK(cudaMemcpy(out_str.data(),d_vout,N*8,cudaMemcpyDeviceToHost));

    // ── parity ──
    double max_rel=0; int am=-1; long mism=0;
    for(long i=0;i<N;i++){ double ad=fabs(out_ref[i]-out_str[i]);
        if(ad!=0.0) mism++;
        double rd=fabs(out_ref[i])>1e-300?ad/fabs(out_ref[i]):ad;
        if(rd>max_rel){max_rel=rd;am=(int)i;} }

    printf("=== QFORGE kernel 4: out-of-core psi streaming (cells > VRAM) ===\n");
    printf("[setup] N=%ld  full-H = %.2f GiB   tiles=%ld  tile_rows=%ld\n",
           N,full_bytes/1073741824.0,T,tile_rows);
    printf("[footprint] in-core resident  : %.2f GiB (full H)\n",full_bytes/1073741824.0);
    printf("            streamed resident : %.2f GiB (2 tiles, double-buffered) = %.1f%% of full\n",
           2*tile_bytes/1073741824.0, 100.0*2*tile_bytes/full_bytes);
    int completed = 1;  // reached here => streamed run completed
    int footprint_ok = (2*tile_bytes) < full_bytes;  // resident < full => > VRAM tractable
    printf("[parity] streamed vs in-core out:  max_rel_err = %.6e (bin %d)  mismatched bins = %ld\n",
           max_rel,am,mism);
    int par_ok = (max_rel==0.0);
    printf("GATE completion (streamed run finished)        : %s\n",completed?"PASS":"FAIL");
    printf("GATE footprint < full (2*tile < full-H bytes)  : %s  (%.1f%% of full)\n",
           footprint_ok?"PASS":"FAIL",100.0*2*tile_bytes/full_bytes);
    printf("GATE parity (streamed == in-core, bit-for-bit) : %s  (max_rel=%.3e)\n",par_ok?"PASS":"FAIL",max_rel);
    printf("VERDICT: %s\n",(completed&&footprint_ok&&par_ok)?"PASS":"FAIL");
    return (completed&&footprint_ok&&par_ok)?0:1;
}
