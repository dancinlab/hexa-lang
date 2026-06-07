#!/usr/bin/env bash
# HEXA-FUSION INTERP-ELIM — native real-trainer step/s + driver microbench on H100.
# Kit pre-extracted to ~/interp_kit. Self-contained.
set -uo pipefail
cd ~/interp_kit || exit 2
HEXAT=~/interp_kit/hexat
chmod +x "$HEXAT"
echo "=== [0] env ==="; nvidia-smi --query-gpu=name,memory.total --format=csv,noheader -i 0
gcc --version | head -1; nvcc --version | grep release

# ─────────────────────────────────────────────────────────────────────────────
# PART 1 — DRIVER MICROBENCH (native): the per-step glue, AOT-compiled.
#   Establishes the native host-glue cost at the batch sweep (byte-eq carrier).
# ─────────────────────────────────────────────────────────────────────────────
echo "=== [1] build native driver microbench ==="
"$HEXAT" ie_driver_flat.hexa ie_driver.c 2>/tmp/d.err || { echo DRIVER_TRANSPILE_FAIL; tail /tmp/d.err; exit 1; }
gcc -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I p1kit/self -I p1kit \
    ie_driver.c p1kit/self/runtime.c -o ie_driver_native -lm -ldl -lpthread 2>/tmp/dcc.err \
  || { echo DRIVER_GCC_FAIL; tail -20 /tmp/dcc.err; exit 1; }
echo "ie_driver_native: $(stat -c%s ie_driver_native) bytes"
echo "--- native driver glue sweep (D1536 Tw512 REPS20) ---"
for B in 1 4 8 16 32; do
  out=$(IE_D=1536 IE_TW=512 IE_B=$B IE_REPS=20 ./ie_driver_native 2>&1)
  w=$(echo "$out" | grep WALL_MS | tr -dc '0-9')
  cw=$(echo "$out" | grep CHK_W | cut -d= -f2)
  echo "  NATIVE-DRIVER B=$B WALL_MS=$w CHK_W=$cw"
done

# ─────────────────────────────────────────────────────────────────────────────
# PART 2 — REAL TRAINER (native clm_prod_gpu): the interpreter-eliminated step.
#   Uses the proven m5 recipe (flatten + hexat -> C -> nvcc/gcc native binary).
# ─────────────────────────────────────────────────────────────────────────────
echo "=== [2] transpile pre-flattened clm_prod (NATIVE driver) ==="
"$HEXAT" clm_prod_flat.hexa clm_prod_m5.c 2>/tmp/clm.err || { echo CLM_TRANSPILE_FAIL; tail -20 /tmp/clm.err; echo "FALLBACK p1kit clm_prod.c"; cp p1kit/clm_prod.c clm_prod_m5.c; }
echo "clm_prod_m5.c: $(wc -l < clm_prod_m5.c) lines"

echo "=== [3] post-process + nvcc runtime + link native clm_prod_gpu ==="
python3 m5_callN_post2.py clm_prod_m5.c 2>/tmp/pp.err || echo POSTPROC_WARN
cd p1kit
nvcc -x cu -DHEXA_CUDA -rdc=true -gencode arch=compute_90,code=sm_90 \
     -I self/cuda -I self -I . -O2 -c runtime_cuda.c -o runtime_cuda.o 2>/tmp/nv.err \
  || { echo NVCC_FAIL; tail -20 /tmp/nv.err; exit 1; }
nvcc -dlink -gencode arch=compute_90,code=sm_90 runtime_cuda.o -o cuda_dlink.o 2>/dev/null
echo "runtime_cuda.o launchers: $(nm runtime_cuda.o|grep -c _hx_cuda_farr)"
cd ~/interp_kit
CUDA_LIB=$(dirname $(find /usr/local/cuda* -name libcudart.so 2>/dev/null|head -1))
gcc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_CUDA -Wno-trigraphs -I p1kit/self -I p1kit \
    clm_prod_m5.c p1kit/self/runtime.c m5_stub.c m5_glue_stub.c p1kit/runtime_cuda.o p1kit/cuda_dlink.o \
    -L"$CUDA_LIB" -L/usr/lib/x86_64-linux-gnu -lcudadevrt -lcudart -lcublas -lcuda -lm -ldl -lpthread \
    -o clm_prod_gpu 2>/tmp/link.err || { echo LINK_FAIL; grep -iE 'error|undefined' /tmp/link.err|head -20; exit 1; }
echo "clm_prod_gpu (NATIVE): $(stat -c%s clm_prod_gpu) bytes"

cp p1kit/corpus.txt ~/corpus.txt
echo "=== [4] smoke native B=1 ==="
CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 HEXA_CUDA_ASYNC=0 \
  CLM_PROD_D=512 CLM_PROD_T=128 CLM_PROD_E=2 CLM_PROD_NSAMP=4 CLM_PROD_EPOCHS=1 CLM_PROD_BATCH=1 \
  CLM_PROD_CORPUS=~/corpus.txt timeout 120 ./clm_prod_gpu 2>&1 | grep -iE 'M5-BATCH|mean CE|DESCENT|PASS|FAIL' | head

# ─────────────────────────────────────────────────────────────────────────────
# PART 3 — native real-trainer step/s + util at the batch sweep (the #2913
#   batch-fill config: D1536 Tw512 E2 K3). 2-point timed slope, init-subtracted.
# ─────────────────────────────────────────────────────────────────────────────
echo "=== [5] NATIVE real-trainer step/s + util sweep (D1536 Tw512) ==="
D=1536; TW=512; NSAMP=64
pyutil(){ python3 -c "u=[int(x) for x in open('$1') if x.strip()]; u.sort(); n=len(u);
print('MEAN=%.2f%% MEDIAN=%d%% PEAK=%d%% pct>=20=%.1f%% n=%d'%(sum(u)/n if n else 0,(u[n//2] if n else 0),(max(u) if n else 0),100*sum(1 for x in u if x>=20)/n if n else 0,n))"; }
# 2-point step/s: time EPOCHS=A vs EPOCHS=Z at fixed nbatch, slope = per-step.
timed(){ local B=$1 ep=$2; local t=/tmp/tr_B${B}_e${ep}.log
  local s0=$(date +%s.%N)
  CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 HEXA_CUDA_ASYNC=0 \
    CLM_PROD_D=$D CLM_PROD_T=$TW CLM_PROD_E=2 CLM_PROD_NSAMP=$NSAMP CLM_PROD_EPOCHS=$ep CLM_PROD_BATCH=$B \
    CLM_PROD_CORPUS=~/corpus.txt timeout 1800 ./clm_prod_gpu >"$t" 2>&1
  local s1=$(date +%s.%N); echo "$(python3 -c "print(f'{$s1-$s0:.3f}')")"
}
for B in 1 4 8 16 32; do
  # util over a sustained run
  u=/tmp/util_B$B.csv; : > "$u"
  ( while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0 >>"$u" 2>/dev/null; sleep 0.2; done ) & sp=$!
  # 2-point timing: nbatch = nsamp/B steps per epoch; time 2 vs 6 epochs.
  wA=$(timed $B 2); wZ=$(timed $B 6)
  kill $sp 2>/dev/null
  nb=$(( NSAMP / B )); stepsA=$(( nb*2 )); stepsZ=$(( nb*6 ))
  slope=$(python3 -c "print(f'{($wZ-$wA)/($stepsZ-$stepsA):.4f}')")
  sps=$(python3 -c "print(f'{1.0/(($wZ-$wA)/($stepsZ-$stepsA)):.4f}' if ($wZ-$wA)>0 else 'inf')")
  ce=$(grep -iE 'mean CE|DESCENT|PASS|FAIL' /tmp/tr_B${B}_e6.log | tr '\n' '|')
  echo "  NATIVE B=$B wA(2ep)=$wA wZ(6ep)=$wZ steps=$stepsA->$stepsZ slope=${slope}s/step step/s=$sps"
  echo "     util: $(pyutil $u)  CE: $ce"
done
echo "=== INTERP-ELIM FIRE DONE ==="
