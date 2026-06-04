#!/usr/bin/env bash
# HEXA-FUSION P2 — REAL clm_prod training step util on a right-sized RTX 5070.
# Builds clm_prod_gpu from fusion_l3a_wired.tgz (one binary: eager when
# HEXA_FUSE_GN_GELU unset, fused GN+GELU one-kernel when =1), then samples
# nvidia-smi util over the OCCUPANCY-WALL workload (D=1536 T=512 EPOCHS=4) for
# idle / eager / fused. Reports MEAN/PEAK/MEDIAN/pct>=20 verbatim.
set -uo pipefail
WORK="${WORK:-$HOME/work}"
BUNDLE="${BUNDLE:-$HOME/fusion_l3a_wired.tgz}"
CUDA_ARCH="${CUDA_ARCH:-compute_89}"   # RTX 5070 = sm_120(Blackwell)/sm_89(Ada); PTX JIT-forwards

mkdir -p "$WORK" && tar xzf "$BUNDLE" -C "$WORK" && cd "$WORK"
echo "=== GPU ==="; nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader -i 0
echo "=== env: $(gcc --version | head -1) | $(nvcc --version | grep release) ==="

# [2] device launchers — -DHEXA_CUDA load-bearing (else 40/59 launchers).
nvcc -x cu -DHEXA_CUDA -gencode arch=${CUDA_ARCH},code=${CUDA_ARCH} \
     -I self/cuda -I self -I . -O2 -c runtime_cuda.c -o runtime_cuda.o
echo "[2] runtime_cuda.o: $(stat -c%s runtime_cuda.o 2>/dev/null) bytes | launchers: $(nm runtime_cuda.o 2>/dev/null | grep -c _hx_cuda_farr) (want 59) | gn_gelu syms: $(nm runtime_cuda.o 2>/dev/null | grep -c groupnorm_gelu)"

# [3] link — driver API needs -lcuda on top of -lcudart -lcublas.
CUDA_LIB="$(dirname "$(find /usr/local/cuda* -name libcudart.so 2>/dev/null | head -1)")"
gcc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_CUDA -Wno-trigraphs -I self -I . \
    clm_prod.c self/runtime.c runtime_cuda.o \
    -L"$CUDA_LIB" -L/usr/lib/x86_64-linux-gnu -lcudart -lcublas -lcuda -lm -ldl -lpthread \
    -o clm_prod_gpu
echo "[3] link rc=$? | clm_prod_gpu: $(stat -c%s clm_prod_gpu 2>/dev/null) bytes"

PYUTIL='import sys;u=[int(x) for x in open(sys.argv[1]) if x.strip()];u or sys.exit("no samples");s=sorted(u);print(f"  util MEAN={sum(u)/len(u):.2f}% PEAK={max(u)}% median={s[len(s)//2]}% pct>=20={100*sum(1 for x in u if x>=20)/len(u):.1f}% pct>=70={100*sum(1 for x in u if x>=70)/len(u):.1f}% n={len(u)}")'

echo "=== idle baseline util (~10s) ==="
ub="$WORK/util_idle.csv"; : > "$ub"
for i in $(seq 1 20); do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0 >>"$ub"; sleep 0.5; done
python3 -c "$PYUTIL" "$ub"

fire(){ local f=$1 u="$WORK/util_f$1.csv" t="$WORK/train_f$1.log"; : > "$u"
 ( while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0 >>"$u" 2>/dev/null; sleep 0.5; done ) & local sp=$!
 export CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 HEXA_CUDA_ASYNC=0
 if [ "$f" = "1" ]; then export HEXA_FUSE_GN_GELU=1; else unset HEXA_FUSE_GN_GELU; fi
 export CLM_PROD_D=1536 CLM_PROD_T=512 CLM_PROD_E=2 CLM_PROD_NSAMP=8 CLM_PROD_EPOCHS=4 CLM_PROD_CORPUS="$WORK/corpus.txt"
 timeout 2400 ./clm_prod_gpu >"$t" 2>&1; local rc=$?; kill $sp 2>/dev/null; wait $sp 2>/dev/null
 echo "--- REAL-STEP fuse=$f rc=$rc (HEXA_FUSE_GN_GELU=${HEXA_FUSE_GN_GELU:-unset}) ---"
 python3 -c "$PYUTIL" "$u" 2>/dev/null || echo "  (util parse fail)"
 grep -iE 'mean CE|CE |DESCENT|PASS|FAIL|out of memory' "$t" | tail -10 | sed 's/^/  /'
}
echo "=== FIRE eager (REAL clm_prod step, serial DAG, fuse=0) ==="
fire 0
echo "=== FIRE fused (HEXA_FUSE_GN_GELU=1, fuse=1) ==="
fire 1
echo "=== P2 DONE ==="
