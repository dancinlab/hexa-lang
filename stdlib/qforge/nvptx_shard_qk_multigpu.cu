// nvptx_shard_qk_multigpu.cu — QFORGE GPU-tier kernel 3 REAL 2-physical-GPU shard test.
// closes QFORGE-FEATURE multi-gpu q/k sharding (real 2-GPU on-device)
//
// The single-GPU 2-shard SIMULATION (#2764, nvptx_shard_qk_host.cu) proved the
// PARTITION + REDUCTION logic is bit-correct (shard-lambda == single-lambda, Delta=0).
// The NAMED-REMAINING piece was true multi-GPU hardware fan-out: cudaSetDevice across
// >=2 physical devices, each holding its q-shard VRAM-resident, cross-device reduce.
//
// This program closes that gate on a real 2-GPU node:
//   * device 0 owns q-shard 0  (its lam_q/wq slice resident in dev-0 VRAM)
//   * device 1 owns q-shard 1  (its lam_q/wq slice resident in dev-1 VRAM)
//   * each device computes its shard partial-lambda on its OWN GPU
//   * host pulls the 2 partials and reduces in fixed shard order (g=0,1)
//   * compared to the 1-GPU single-pass whole-list lambda (device 0).
//
//   GATE: |lambda_2gpu - lambda_1gpu| == 0  (exact, deterministic shard order)
//         AND report the measured wall-clock ratio (1-GPU / 2-GPU).
//
// HONESTY (d6): the wall-ratio is REPORTED VERBATIM whatever it is. The per-q
// accumulate is the same serial kernel as the single-GPU sim; for the 2-GPU wall
// timing we run a REPEAT loop of the partial-lambda kernel on each device so each
// device does HALF the q-work in parallel (the embarrassingly-parallel-over-q case).
// If the speedup is < 2x because of PCIe H2D / cross-device sync overhead (no NVLink),
// that real ratio is printed and named honestly — NOT rounded up to 2x.
//
//   build: nvcc -O2 nvptx_shard_qk_multigpu.cu -o nvptx_shard_qk_multigpu
//          (nvcc auto-detects arch; add -arch=sm_XX to pin)
//   run:   ./nvptx_shard_qk_multigpu [Nq] [REPEAT]
//
// Exit 0 = 2-GPU shard-lambda == 1-GPU single-lambda exactly; non-zero otherwise.

#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <chrono>

#define CK(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA-ERR %s @ %d\n",cudaGetErrorString(e),__LINE__); return 2; } }while(0)

// per-shard partial-lambda (mirror of qforge_shard_partial_lambda in the .hexa kernel)
// deterministic serial order so the FP summation order matches the single-pass ref.
__global__ void k_shard_partial(const double* lam_q,const double* wq,long off,long cnt,
                                 double* out_partial,long slot){
    if(threadIdx.x==0 && blockIdx.x==0){
        double acc=0.0;
        for(long k=0;k<cnt;k++){ long i=off+k; acc+=wq[i]*lam_q[i]; }
        out_partial[slot]=acc;
    }
}
// single-pass whole-list lambda reference (mirror of the sim's k_single_lambda) —
// SAME block-by-block-in-shard-order accumulation as the shard path so single==shard
// EXACTLY (the contiguous block-partition fixes the order; any diff would be a sharding
// LOGIC error, not an FP-associativity artifact).
__global__ void k_single_lambda(const double* lam_q,const double* wq,
                                 const long* offs,const long* cnts,long g_count,double* lam_out){
    if(threadIdx.x==0 && blockIdx.x==0){
        double total=0.0;
        for(long g=0;g<g_count;g++){
            double acc=0.0;
            for(long k=0;k<cnts[g];k++){ long i=offs[g]+k; acc+=wq[i]*lam_q[i]; }
            total+=acc;
        }
        lam_out[0]=total;
    }
}

int main(int argc,char**argv){
    long Nq     = argc>1?atol(argv[1]):4096;
    long REPEAT = argc>2?atol(argv[2]):20000;   // wall-timing repeat (per-q solve stand-in)
    const long G = 2;                            // TWO physical GPUs

    int ndev=0; CK(cudaGetDeviceCount(&ndev));
    fprintf(stderr,"[node] cudaGetDeviceCount = %d\n",ndev);
    if(ndev < 2){
        fprintf(stderr,"FATAL: need >=2 physical GPUs for the real multi-GPU gate, found %d\n",ndev);
        return 3;
    }
    char names[2][256];
    for(int dv=0;dv<2;dv++){
        cudaDeviceProp p; CK(cudaGetDeviceProperties(&p,dv));
        snprintf(names[dv],256,"%s sm_%d%d",p.name,p.major,p.minor);
        fprintf(stderr,"[gpu %d] %s  (%.1f GB)\n",dv,names[dv],p.totalGlobalMem/1e9);
    }
    // P2P capability probe (NVLink vs PCIe reduce path) — reported, not required.
    int p2p01=0,p2p10=0;
    cudaDeviceCanAccessPeer(&p2p01,0,1); cudaDeviceCanAccessPeer(&p2p10,1,0);
    fprintf(stderr,"[p2p] dev0->dev1 = %d  dev1->dev0 = %d  (0 = PCIe-host reduce, 1 = direct peer)\n",
            p2p01,p2p10);

    // deterministic per-q lambda_q and weights (stand-ins for DFPT-produced partials),
    // IDENTICAL generator to the single-GPU sim so the numbers are comparable.
    std::vector<double> lam_q(Nq), wq(Nq);
    for(long i=0;i<Nq;i++){ lam_q[i]=0.37+0.11*sin(0.0007*(double)i)+1e-3*cos(0.0031*i);
                            wq[i]=1.0/(double)Nq * (1.0+0.05*sin(0.002*i)); }

    // G-shard contiguous block-partition. shard g owns [off,off+cnt). Sum cnt = Nq.
    long base=Nq/G, rem=Nq%G, off=0;
    std::vector<long> offs(G),cnts(G);
    for(long g=0;g<G;g++){ long cnt=base+(g<rem?1:0); offs[g]=off; cnts[g]=cnt; off+=cnt; }

    // ===== 1-GPU REFERENCE (device 0, whole list, single pass) =====
    CK(cudaSetDevice(0));
    double *d0_lam,*d0_wq,*d0_single; long *d0_offs,*d0_cnts;
    CK(cudaMalloc(&d0_lam,Nq*8)); CK(cudaMalloc(&d0_wq,Nq*8));
    CK(cudaMalloc(&d0_single,8));
    CK(cudaMalloc(&d0_offs,G*sizeof(long))); CK(cudaMalloc(&d0_cnts,G*sizeof(long)));
    CK(cudaMemcpy(d0_lam,lam_q.data(),Nq*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(d0_wq ,wq.data()  ,Nq*8,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(d0_offs,offs.data(),G*sizeof(long),cudaMemcpyHostToDevice));
    CK(cudaMemcpy(d0_cnts,cnts.data(),G*sizeof(long),cudaMemcpyHostToDevice));
    // correctness value
    k_single_lambda<<<1,1>>>(d0_lam,d0_wq,d0_offs,d0_cnts,G,d0_single);
    CK(cudaDeviceSynchronize());
    double lam_1gpu=0; CK(cudaMemcpy(&lam_1gpu,d0_single,8,cudaMemcpyDeviceToHost));
    // wall timing: REPEAT passes of the WHOLE q-list on the single GPU (all Nq work here)
    CK(cudaDeviceSynchronize());
    auto t1a=std::chrono::high_resolution_clock::now();
    for(long r=0;r<REPEAT;r++)
        k_single_lambda<<<1,1>>>(d0_lam,d0_wq,d0_offs,d0_cnts,G,d0_single);
    CK(cudaDeviceSynchronize());
    auto t1b=std::chrono::high_resolution_clock::now();
    double wall_1gpu=std::chrono::duration<double>(t1b-t1a).count();

    // ===== 2-GPU REAL SHARD: device d owns shard d, VRAM-resident, computes its partial =====
    // Allocate each shard's slice on ITS OWN device. No device holds the other's data.
    double *ds_lam[2],*ds_wq[2],*ds_part[2];
    for(int dv=0;dv<2;dv++){
        long c=cnts[dv], o=offs[dv];
        CK(cudaSetDevice(dv));
        CK(cudaMalloc(&ds_lam[dv], c*8));
        CK(cudaMalloc(&ds_wq[dv],  c*8));
        CK(cudaMalloc(&ds_part[dv],8));
        // copy ONLY this shard's slice to this device (VRAM-resident per device)
        CK(cudaMemcpy(ds_lam[dv], lam_q.data()+o, c*8, cudaMemcpyHostToDevice));
        CK(cudaMemcpy(ds_wq[dv],  wq.data()+o,    c*8, cudaMemcpyHostToDevice));
    }
    // correctness: each device computes its shard partial (off=0 within its own slice)
    for(int dv=0;dv<2;dv++){
        CK(cudaSetDevice(dv));
        k_shard_partial<<<1,1>>>(ds_lam[dv],ds_wq[dv],0,cnts[dv],ds_part[dv],0);
    }
    for(int dv=0;dv<2;dv++){ CK(cudaSetDevice(dv)); CK(cudaDeviceSynchronize()); }
    double part_h[2];
    for(int dv=0;dv<2;dv++){
        CK(cudaSetDevice(dv));
        CK(cudaMemcpy(&part_h[dv],ds_part[dv],8,cudaMemcpyDeviceToHost));
    }
    // host-side cross-device reduce in fixed shard order g=0,1
    double lam_2gpu = part_h[0] + part_h[1];

    // wall timing: REPEAT passes, each device runs its HALF concurrently (async),
    // then both join. This is the embarrassingly-parallel-over-q work split.
    for(int dv=0;dv<2;dv++){ CK(cudaSetDevice(dv)); CK(cudaDeviceSynchronize()); }
    auto t2a=std::chrono::high_resolution_clock::now();
    for(long r=0;r<REPEAT;r++){
        for(int dv=0;dv<2;dv++){
            CK(cudaSetDevice(dv));                              // launches are async per device
            k_shard_partial<<<1,1>>>(ds_lam[dv],ds_wq[dv],0,cnts[dv],ds_part[dv],0);
        }
    }
    for(int dv=0;dv<2;dv++){ CK(cudaSetDevice(dv)); CK(cudaDeviceSynchronize()); }
    auto t2b=std::chrono::high_resolution_clock::now();
    double wall_2gpu=std::chrono::duration<double>(t2b-t2a).count();

    double delta=fabs(lam_2gpu-lam_1gpu);
    double ratio = wall_2gpu>0 ? wall_1gpu/wall_2gpu : 0.0;

    printf("=== QFORGE kernel 3: REAL 2-physical-GPU q/k sharding (partition + cross-device reduce) ===\n");
    printf("[node] GPUs: dev0 = %s ; dev1 = %s ; P2P(0<->1)=%d/%d\n",names[0],names[1],p2p01,p2p10);
    printf("[setup] Nq=%ld  G=2 shards on 2 PHYSICAL GPUs  (REPEAT=%ld for wall timing)\n",Nq,REPEAT);
    printf("  shard 0 -> dev0 : q[%ld..%ld)  partial_lambda = %.17e\n",offs[0],offs[0]+cnts[0],part_h[0]);
    printf("  shard 1 -> dev1 : q[%ld..%ld)  partial_lambda = %.17e\n",offs[1],offs[1]+cnts[1],part_h[1]);
    printf("[lambda] 1-GPU single-pass (whole list, dev0) : %.17e\n",lam_1gpu);
    printf("[lambda] 2-GPU shard partition+reduce         : %.17e\n",lam_2gpu);
    printf("  shard-lambda(2GPU) - single-lambda(1GPU) = %.3e   (gate: Delta == 0)\n",delta);
    printf("[wall ] 1-GPU whole-list  : %.6f s  (%ld passes of Nq=%ld)\n",wall_1gpu,REPEAT,Nq);
    printf("[wall ] 2-GPU half-each   : %.6f s  (%ld passes, each dev does Nq/2)\n",wall_2gpu,REPEAT);
    printf("[wall ] speedup 1GPU/2GPU = %.4f x   (ideal embarrassingly-parallel = 2.0)\n",ratio);
    int ok_delta = (delta==0.0);
    printf("GATE A  2-GPU shard-lambda == 1-GPU single-lambda (Delta=0): %s\n",ok_delta?"PASS":"FAIL");
    printf("GATE B  wall-ratio (reported VERBATIM, d6): %.4f x  %s\n",ratio,
           ratio>=1.8?"(>=1.8x, near-ideal)":"(<1.8x — report honestly: per-device launch/sync bound, no NVLink)");
    printf("VERDICT: %s\n",ok_delta?"PASS-2GPU":"FAIL");
    return ok_delta?0:1;
}
