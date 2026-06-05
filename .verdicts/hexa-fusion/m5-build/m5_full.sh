#!/usr/bin/env bash
# M5 full rebuild + util-vs-batch sweep on a fresh H100. Self-contained.
set -uo pipefail
cd /root
HEXAT=/root/hexa-lang/dist/linux-x86_64/hexat
chmod +x "$HEXAT" 2>/dev/null
echo "=== env ==="; nvidia-smi --query-gpu=name --format=csv,noheader -i 0; nvcc --version|grep release

echo "=== [A] flatten + transpile M5 clm_prod.hexa ==="
cd /root/hexa-lang
"$HEXAT" tool/flatten_imports.hexa /root/flatten.gen.c 2>/root/fl.err || { echo FLATTEN_TRANSPILE_FAIL; tail /root/fl.err; exit 1; }
gcc -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I /root/p1kit/self -I /root/p1kit \
    /root/flatten.gen.c /root/p1kit/self/runtime.c -o /root/flatten.bin -lm -ldl -lpthread 2>/root/flcc.err \
    || { echo FLATTEN_GCC_FAIL; tail -20 /root/flcc.err; exit 1; }
( cd /root/hexa-lang && /root/flatten.bin _ stdlib/flame/clm_prod.hexa /root/clm_flat.hexa ) || { echo FLATTEN_RUN_FAIL; exit 1; }
echo "flat: $(wc -l < /root/clm_flat.hexa) lines, residual-use=$(grep -c '^use ' /root/clm_flat.hexa), M5-markers=$(grep -c CLM_PROD_BATCH /root/clm_flat.hexa)"
"$HEXAT" /root/clm_flat.hexa /root/p1kit/clm_prod_m5.c 2>/root/clm.err || { echo CLM_TRANSPILE_FAIL; tail -20 /root/clm.err; exit 1; }
echo "clm_prod_m5.c: $(wc -l < /root/p1kit/clm_prod_m5.c) lines"

echo "=== [B] post-process (hexa_callN->direct, adamw proto) ==="
python3 /root/m5_callN_post2.py /root/p1kit/clm_prod_m5.c

echo "=== [C] nvcc runtime_cuda.o (rdc cooperative) ==="
cd /root/p1kit
nvcc -x cu -DHEXA_CUDA -rdc=true -gencode arch=compute_90,code=sm_90 \
     -I self/cuda -I self -I . -O2 -c runtime_cuda.c -o runtime_cuda.o 2>/root/nv.err \
  || { echo NVCC_FAIL; tail -20 /root/nv.err; exit 1; }
nvcc -dlink -gencode arch=compute_90,code=sm_90 runtime_cuda.o -o cuda_dlink.o 2>/dev/null
echo "runtime_cuda.o: $(stat -c%s runtime_cuda.o) bytes, launchers=$(nm runtime_cuda.o|grep -c _hx_cuda_farr)"

echo "=== [D] link clm_prod_gpu (+ stubs) ==="
CUDA_LIB=$(dirname $(find /usr/local/cuda* -name libcudart.so 2>/dev/null|head -1))
gcc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_CUDA -Wno-trigraphs -I self -I . \
    clm_prod_m5.c self/runtime.c m5_stub.c m5_glue_stub.c runtime_cuda.o cuda_dlink.o \
    -L"$CUDA_LIB" -L/usr/lib/x86_64-linux-gnu -lcudadevrt -lcudart -lcublas -lcuda -lm -ldl -lpthread \
    -o clm_prod_gpu 2>/root/link.err || { echo LINK_FAIL; grep -iE 'error|undefined' /root/link.err|head -20; exit 1; }
echo "clm_prod_gpu: $(stat -c%s clm_prod_gpu) bytes"

echo "=== [E] smoke B=1 ==="
CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 HEXA_CUDA_ASYNC=0 \
  CLM_PROD_D=512 CLM_PROD_T=128 CLM_PROD_E=2 CLM_PROD_NSAMP=8 CLM_PROD_EPOCHS=2 CLM_PROD_BATCH=1 \
  CLM_PROD_CORPUS=/root/corpus.txt timeout 120 ./clm_prod_gpu 2>&1 | grep -iE 'M5-BATCH|mean CE|DESCENT|PASS|FAIL' | head

echo "=== [F] util-vs-batch sweep (D=1536 Tw=512 eager FP64) ==="
D=1536; TW=512; NSAMP=64; EPOCHS=3
py(){ python3 -c "u=[int(x) for x in open('$1') if x.strip()]; u.sort(); n=len(u);
print('MEAN=%.2f%% MEDIAN=%d%% PEAK=%d%% pct>=20=%.1f%% n=%d'%(sum(u)/n if n else 0,(u[n//2] if n else 0),(max(u) if n else 0),100*sum(1 for x in u if x>=20)/n if n else 0,n))"; }
fire(){ local B=$1 u=/root/p1kit/util_B$1.csv t=/root/p1kit/train_B$1.log; : > "$u"
  ( while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0 >>"$u" 2>/dev/null; sleep 0.2; done ) & local sp=$!
  CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 HEXA_CUDA_ASYNC=0 \
    CLM_PROD_D=$D CLM_PROD_T=$TW CLM_PROD_E=2 CLM_PROD_NSAMP=$NSAMP CLM_PROD_EPOCHS=$EPOCHS CLM_PROD_BATCH=$B \
    CLM_PROD_CORPUS=/root/corpus.txt timeout 1600 ./clm_prod_gpu >"$t" 2>&1; local rc=$?
  kill $sp 2>/dev/null
  printf "B=%-3d rc=%-3d %s\n" "$B" "$rc" "$(py "$u")"
  echo "   $(grep -E 'M5-BATCH|mean CE|out of memory|windows' "$t" | tr '\n' ' ')"
}
( for i in $(seq 1 15); do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0; sleep 0.2; done ) > /root/p1kit/util_idle.csv
echo "IDLE $(py /root/p1kit/util_idle.csv)"
for B in 1 4 8 16 32; do fire $B; done
echo "=== M5 SWEEP DONE ==="
