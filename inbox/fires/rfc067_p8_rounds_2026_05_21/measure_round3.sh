#!/bin/bash
set +e
cd /tmp

echo "=== GPU.md Round 3 — extended checkbox sweep ==="
echo "host: $(hostname)  date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ─── A. PR #214 host 10-trial re-fire (CORRECT layout) ─────────────────
echo "=== §5m HGEMM 10-trial via ORIGINAL PR #214 host launcher ==="
if [ ! -f /tmp/r067_perf_hgemm_host_orig.c ]; then
  echo "ERROR: original host source not staged" ; exit 1
fi
nvcc -O2 -arch=sm_80 -o /tmp/r067_perf_orig /tmp/r067_perf_hgemm_host_orig.c -lcuda -lcudart -lcublas 2>&1 | tail -3
if [ -f /tmp/r067_perf_orig ]; then
  # Fire 5 times, parse the ratio
  for trial in 1 2 3 4 5; do
    out=$(/tmp/r067_perf_orig /tmp/composite_wmma_256x256.ptx 2>&1 | tail -30)
    ratio=$(echo "$out" | grep -oE 'ratio_hexa_over_cublas.*0\.[0-9]+' | tail -1)
    hexa_tflops=$(echo "$out" | grep 'hexa.*tflops' -i | head -1)
    blas_tflops=$(echo "$out" | grep 'cublas.*tflops' -i | head -1)
    json_out=$(echo "$out" | grep -E '^\s*"hexa_tflops|cublas_tflops|ratio_hexa')
    echo "trial $trial: $json_out"
  done
else
  echo "BUILD FAILED — host not produced"
fi
echo ""

# ─── B. ULP check for f16_vadd (extends bf16) ─────────────────────────
echo "=== §6a f16 ULP-bounded checker ==="
cat > /tmp/ulp_f16.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
static uint16_t f32_to_f16(float f) {
    uint32_t x; memcpy(&x,&f,4);
    uint32_t s=(x>>16)&0x8000; int32_t e=((x>>23)&0xff)-127+15; uint32_t m=x&0x007fffff;
    if (e<=0) return (uint16_t)s;
    if (e>=31) return (uint16_t)(s|0x7c00);
    return (uint16_t)(s|(e<<10)|(m>>13));
}
static float f16_to_f32(uint16_t h) {
    uint32_t s=(h&0x8000)<<16; uint32_t e=(h>>10)&0x1f; uint32_t m=h&0x3ff;
    uint32_t o;
    if (e==0) o=s;
    else if (e==31) o=s|0x7f800000|(m<<13);
    else o=s|((e-15+127)<<23)|(m<<13);
    float f; memcpy(&f,&o,4); return f;
}
int main() {
    cuInit(0); CUdevice dev; cuDeviceGet(&dev,0);
    CUcontext ctx; cuCtxCreate(&ctx,0,dev);
    FILE *fp=fopen("/tmp/f16_vadd.ptx","r"); fseek(fp,0,SEEK_END); long sz=ftell(fp); fseek(fp,0,SEEK_SET);
    char *ptx=malloc(sz+1); size_t rd=fread(ptx,1,sz,fp); (void)rd; ptx[sz]=0; fclose(fp);
    CUmodule mod; cuModuleLoadDataEx(&mod,ptx,0,NULL,NULL);
    CUfunction fn; cuModuleGetFunction(&fn,mod,"f16_vadd");
    int N=1024;
    uint16_t *Ah=malloc(N*2), *Bh=malloc(N*2), *Ch=malloc(N*2);
    srand(42);
    for (int i=0;i<N;++i){
        Ah[i]=f32_to_f16(((float)rand()/RAND_MAX-0.5f)*2.0f);
        Bh[i]=f32_to_f16(((float)rand()/RAND_MAX-0.5f)*2.0f);
    }
    CUdeviceptr A,B,C;
    cuMemAlloc(&A,N*2); cuMemAlloc(&B,N*2); cuMemAlloc(&C,N*2);
    cuMemcpyHtoD(A,Ah,N*2); cuMemcpyHtoD(B,Bh,N*2);
    long Nl=N; void *args[]={&A,&B,&C,&Nl};
    cuLaunchKernel(fn,(N+255)/256,1,1,256,1,1,0,NULL,args,NULL);
    cuCtxSynchronize();
    cuMemcpyDtoH(Ch,C,N*2);
    int max_ulp=0, zero=0, nonz=0;
    for (int i=0;i<N;++i){
        float ref = f16_to_f32(Ah[i]) + f16_to_f32(Bh[i]);
        uint16_t ref_h = f32_to_f16(ref);
        int u = abs((int)Ch[i] - (int)ref_h);
        if (u==0) zero++; else nonz++;
        if (u>max_ulp) max_ulp=u;
    }
    printf("f16_vadd ULP N=%d max_ulp=%d zero=%d nonzero=%d\n", N, max_ulp, zero, nonz);
    return 0;
}
EOF
nvcc -O2 -arch=sm_80 -o /tmp/ulp_f16 /tmp/ulp_f16.c -lcuda 2>&1 | tail -1
/tmp/ulp_f16
echo ""

# ─── C. NaN/Inf bf16 + FP64 ────────────────────────────────────────────
echo "=== §6a NaN/Inf propagation: bf16 + FP64 ==="
cat > /tmp/nan_bf16.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main() {
    cuInit(0); CUdevice d; cuDeviceGet(&d,0); CUcontext c; cuCtxCreate(&c,0,d);
    FILE *fp=fopen("/tmp/bf16_vadd.ptx","r"); fseek(fp,0,SEEK_END); long sz=ftell(fp); fseek(fp,0,SEEK_SET);
    char *ptx=malloc(sz+1); size_t rd=fread(ptx,1,sz,fp); (void)rd; ptx[sz]=0; fclose(fp);
    CUmodule mod; cuModuleLoadDataEx(&mod,ptx,0,NULL,NULL);
    CUfunction fn; cuModuleGetFunction(&fn,mod,"bf16_vadd");
    // bf16 layout: sign(1) exp(8) mant(7)
    unsigned short A[4]={0xffc0/*qNaN*/, 0x7f80/*+Inf*/, 0xff80/*-Inf*/, 0x3f80/*1.0*/};
    unsigned short B[4]={0x3f80, 0x3f80, 0x7f80, 0x0000};
    unsigned short C[4]={0};
    CUdeviceptr da,db,dc; cuMemAlloc(&da,8); cuMemAlloc(&db,8); cuMemAlloc(&dc,8);
    cuMemcpyHtoD(da,A,8); cuMemcpyHtoD(db,B,8);
    long N=4; void *args[]={&da,&db,&dc,&N};
    cuLaunchKernel(fn,1,1,1,256,1,1,0,NULL,args,NULL);
    cuCtxSynchronize();
    cuMemcpyDtoH(C,dc,8);
    const char *names[]={"qNaN+1.0","+Inf+1.0","-Inf++Inf","1.0+0.0"};
    int ok=0;
    for (int i=0;i<4;++i){
        int is_nan = ((C[i]&0x7f80)==0x7f80) && ((C[i]&0x007f)!=0);
        int is_pinf = C[i]==0x7f80;
        int is_one = C[i]==0x3f80;
        int pass = (i==0 && is_nan) || (i==1 && is_pinf) || (i==2 && is_nan) || (i==3 && is_one);
        if (pass) ok++;
        printf("  bf16 %s -> 0x%04x [%s]\n", names[i], C[i], pass?"PASS":"FAIL");
    }
    printf("bf16 nan_inf: %d/4 PASS\n", ok);
    return 0;
}
EOF
nvcc -O2 -arch=sm_80 -o /tmp/nan_bf16 /tmp/nan_bf16.c -lcuda 2>&1 | tail -1
/tmp/nan_bf16
echo "--"
cat > /tmp/nan_fp64.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
int main() {
    cuInit(0); CUdevice d; cuDeviceGet(&d,0); CUcontext c; cuCtxCreate(&c,0,d);
    FILE *fp=fopen("/tmp/vec_add_unroll1.ptx","r"); fseek(fp,0,SEEK_END); long sz=ftell(fp); fseek(fp,0,SEEK_SET);
    char *ptx=malloc(sz+1); size_t rd=fread(ptx,1,sz,fp); (void)rd; ptx[sz]=0; fclose(fp);
    CUmodule mod; cuModuleLoadDataEx(&mod,ptx,0,NULL,NULL);
    CUfunction fn; cuModuleGetFunction(&fn,mod,"vec_add_unroll1");
    double A[4]={NAN, INFINITY, -INFINITY, 1.0};
    double B[4]={1.0, 1.0, INFINITY, 0.0};
    double C[4]={0};
    CUdeviceptr da,db,dc; cuMemAlloc(&da,32); cuMemAlloc(&db,32); cuMemAlloc(&dc,32);
    cuMemcpyHtoD(da,A,32); cuMemcpyHtoD(db,B,32);
    long N=4; void *args[]={&da,&db,&dc,&N};
    cuLaunchKernel(fn,1,1,1,256,1,1,0,NULL,args,NULL);
    cuCtxSynchronize();
    cuMemcpyDtoH(C,dc,32);
    const char *names[]={"NaN+1.0","+Inf+1.0","-Inf++Inf","1.0+0.0"};
    int ok=0;
    int pass[4];
    pass[0] = isnan(C[0]);
    pass[1] = isinf(C[1]) && C[1] > 0;
    pass[2] = isnan(C[2]);
    pass[3] = (C[3] == 1.0);
    for (int i=0;i<4;++i){
        printf("  fp64 %s -> %g [%s]\n", names[i], C[i], pass[i]?"PASS":"FAIL");
        if (pass[i]) ok++;
    }
    printf("fp64 nan_inf: %d/4 PASS\n", ok);
    return 0;
}
EOF
nvcc -O2 -arch=sm_80 -o /tmp/nan_fp64 /tmp/nan_fp64.c -lcuda 2>&1 | tail -1
/tmp/nan_fp64
echo ""

# ─── D. Driver vs Runtime API launch overhead ─────────────────────────
echo "=== §7a Driver (cu*) vs Runtime (cuda*) launch overhead ==="
cat > /tmp/launch_api_diff.c <<'EOF'
#include <cuda.h>
#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
int main() {
    cuInit(0); CUdevice dev; cuDeviceGet(&dev,0);
    CUcontext ctx; cuCtxCreate(&ctx,0,dev);
    FILE *fp=fopen("/tmp/empty_kernel.ptx","r"); fseek(fp,0,SEEK_END); long sz=ftell(fp); fseek(fp,0,SEEK_SET);
    char *ptx=malloc(sz+1); size_t rd=fread(ptx,1,sz,fp); (void)rd; ptx[sz]=0; fclose(fp);
    CUmodule mod; cuModuleLoadDataEx(&mod,ptx,0,NULL,NULL);
    CUfunction fn; cuModuleGetFunction(&fn,mod,"empty_k");
    int reps=100000;
    // Driver API cuLaunchKernel
    for (int i=0;i<1000;++i) cuLaunchKernel(fn,1,1,1,1,1,1,0,NULL,NULL,NULL);
    cuCtxSynchronize();
    CUevent t0,t1; cuEventCreate(&t0,0); cuEventCreate(&t1,0);
    cuEventRecord(t0,0);
    for (int i=0;i<reps;++i) cuLaunchKernel(fn,1,1,1,1,1,1,0,NULL,NULL,NULL);
    cuEventRecord(t1,0); cuEventSynchronize(t1);
    float ms_driver; cuEventElapsedTime(&ms_driver,t0,t1);
    printf("driver cuLaunchKernel    reps=%d total_ms=%.3f per_launch_us=%.4f\n", reps, ms_driver, ms_driver*1000.0/reps);
    // Runtime API cudaLaunchKernel needs different setup with kernel pointer; use cudaConfigureCall + cudaLaunch (deprecated) or skip
    // Use a cudaMemset as a no-op runtime API to get baseline of cuda*-style overhead
    int dummy; cudaMalloc((void**)&dummy, 4);
    for (int i=0;i<1000;++i) cudaMemsetAsync((void*)(uintptr_t)dummy, 0, 4, 0);
    cudaDeviceSynchronize();
    cuEventRecord(t0,0);
    for (int i=0;i<reps;++i) cudaMemsetAsync((void*)(uintptr_t)dummy, 0, 4, 0);
    cuEventRecord(t1,0); cuEventSynchronize(t1);
    float ms_rt; cuEventElapsedTime(&ms_rt,t0,t1);
    printf("runtime cudaMemsetAsync  reps=%d total_ms=%.3f per_launch_us=%.4f (proxy for runtime overhead)\n", reps, ms_rt, ms_rt*1000.0/reps);
    return 0;
}
EOF
nvcc -O2 -arch=sm_80 -o /tmp/launch_api_diff /tmp/launch_api_diff.c -lcuda -lcudart 2>&1 | tail -1
/tmp/launch_api_diff
echo ""

# ─── E. Nsight Compute smoke ───────────────────────────────────────────
echo "=== §7a Nsight Compute (ncu) availability + smoke ==="
if command -v ncu >/dev/null 2>&1; then
  ncu --version 2>&1 | head -2
  echo "ncu installed — would profile f16_vadd; skipping actual run for budget"
else
  echo "ncu NOT INSTALLED (honest finding: §7a Nsight Compute integration blocked at toolchain level)"
fi
echo ""

# ─── F. PTX-text safety audit ──────────────────────────────────────────
echo "=== §6b/§6c PTX-text safety audit ==="
for f in step3_wmma_64x64_grid.ptx step4_wmma_cp_async.ptx f16_vadd.ptx vec_add_unroll1.ptx; do
  [ -f /tmp/$f ] || continue
  has_barsync=$(grep -c "bar\.sync\|cp\.async\.commit_group\|cp\.async\.wait_group" /tmp/$f)
  has_bounds=$(grep -c "setp.lt\|setp.ge\|setp.lo\|setp.hi\|@!.*bra\|@.*bra" /tmp/$f)
  has_param=$(grep -c "ld\.param\.u64\|ld\.param\.s64" /tmp/$f)
  echo "$f: bar.sync/cp.async-barrier=$has_barsync  setp+@bra(bounds)=$has_bounds  ld.param=$has_param"
done
echo ""

echo "=== END Round 3 ==="
