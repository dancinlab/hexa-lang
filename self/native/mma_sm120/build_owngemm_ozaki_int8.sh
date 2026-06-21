#!/usr/bin/env bash
# build_owngemm_ozaki_int8.sh — build + run the sm_120 Ozaki-INT8 GEMM
# gate/perf/det on aiden (RTX 5070 sm_120). r-ozaki-int8: LAST cited TF32
# speed-overturn lever (INT8 tensor cores ~4x TF32 rate on GeForce, large-n).
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"
SRC="$D/owngemm_sm120_ozaki_int8.cu"

echo "=== ISA probe: mma.sync.aligned.m16n8k32.s32.s8.s8.s32 on sm_120 ==="
cat > /tmp/imma_probe.cu <<'PCU'
#include <cstdint>
__global__ void p(const int* A,const int* B,int* D){
  int a[4]={A[0],A[1],A[2],A[3]}, b[2]={B[0],B[1]}, d[4]={0,0,0,0};
  asm volatile("mma.sync.aligned.m16n8k32.row.col.s32.s8.s8.s32 "
    "{%0,%1,%2,%3},{%4,%5,%6,%7},{%8,%9},{%0,%1,%2,%3};\n"
    :"+r"(d[0]),"+r"(d[1]),"+r"(d[2]),"+r"(d[3])
    :"r"(a[0]),"r"(a[1]),"r"(a[2]),"r"(a[3]),"r"(b[0]),"r"(b[1]));
  D[threadIdx.x]=d[0]+d[1]+d[2]+d[3];
}
int main(){return 0;}
PCU
if nvcc -arch=sm_120 $INC /tmp/imma_probe.cu -o /tmp/imma_probe 2>/tmp/imma_err; then
  echo "[IMMA m16n8k32 s8] ACCEPTED (ptxas emitted SASS for sm_120)"
else
  echo "[IMMA m16n8k32 s8] REJECTED"; cat /tmp/imma_err | head -6; exit 1
fi

echo
echo "=== build Ozaki-INT8 GEMM ==="
nvcc -arch=sm_120 $INC -O3 -DOZAKI_MAIN "$SRC" -lcublas -o /tmp/owngemm_ozaki_int8

echo
echo "=== GATE: rel-RMS vs FP64 + vs cuBLAS-TF32 (small-n, NSPL sweep) ==="
for NS in 4 5 6 7; do /tmp/owngemm_ozaki_int8 2048 0 $NS; done

echo
echo "=== GATE @ larger n (rel-RMS vs cuBLAS-TF32, FP64 skipped >4096) ==="
/tmp/owngemm_ozaki_int8 4096 0 6
/tmp/owngemm_ozaki_int8 8192 0 6

echo
echo "=== DETERMINISM (byte-eq run-to-run, must be 0) ==="
/tmp/owngemm_ozaki_int8 4096 2 6

echo
echo "=== PERF small-n (honest regime-split: expect Ozaki LOSES here) ==="
for S in 512 1024 2048 3072; do /tmp/owngemm_ozaki_int8 $S 1 6; done

echo
echo "=== PERF large-n (the crossover regime — does Ozaki-INT8 reach >=1.0x?) ==="
for S in 4096 8192 12288 16384; do /tmp/owngemm_ozaki_int8 $S 1 6; done

echo
echo "=== PERF large-n at minimal NSPL=4 (fewest splits for TF32-level acc) ==="
for S in 8192 12288 16384; do /tmp/owngemm_ozaki_int8 $S 1 4; done
