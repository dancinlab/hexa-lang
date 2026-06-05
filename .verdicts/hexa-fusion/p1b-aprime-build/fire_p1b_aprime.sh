#!/usr/bin/env bash
# fire_p1b_aprime.sh — HEXA-FUSION P1B-a' byte-eq CAPSTONE A/B (run ON POD in ~/work).
# Both arms = own-GEMM (HEXA_OWN_GEMM=1) + DEVRESIDENT chain.
#   A = device-EAGER reference: HEXA_EAGER_DEVRESIDENT=1, megastep OFF
#       → fwd glue (gelu/groupnorm/softmax) on-device as SEPARATE launches, CUDA erf.
#       expect [EAGER-DEVGLUE-FIRED] ; [MEGAFWD-FIRED]=0
#   B = device-MEGA: HEXA_CLM_MEGASTEP=1 HEXA_CLM_MEGASTEP_FP64=1
#       → cooperative full-fwd megakernel, CUDA erf. expect [MEGAFWD-FIRED]>=1
# Byte-eq gate = max|Δ|=0 on the 17-digit [B6-CE-HIPREC] first_ce/last_ce, verbatim.
set -uo pipefail
cd ~/work
CUDA_LIB=$(dirname "$(find /usr/local/cuda* -name libcudart.so 2>/dev/null | head -1)")
DCFG=${DCFG:-1536}; TCFG=${TCFG:-512}; EPO=${EPO:-4}; NS=${NS:-8}

echo "=== GPU ==="; nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv,noheader -i 0
echo "=== relink (clean runtime.c) ==="
gcc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_CUDA -w -I self -I . \
    clm_prod.c self/runtime.c runtime_cuda.o runtime_cuda_dlink.o \
    -L"$CUDA_LIB" -lcudart -lcublas -lcuda -lcudadevrt -lm -ldl -lpthread -o clm_prod_gpu 2>/tmp/relink.err \
  && echo "  clm_prod_gpu: $(stat -c%s clm_prod_gpu) bytes" || { echo "RELINK FAIL"; grep -i error /tmp/relink.err|head; exit 1; }

fire(){ # $1=label $2..=extra env
 local lbl=$1; shift
 local u=~/work/util_$lbl.csv t=~/work/train_$lbl.log; : > "$u"
 ( while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0 >>"$u" 2>/dev/null; sleep 0.5; done ) & local sp=$!
 env CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 \
     HEXA_OWN_GEMM=1 \
     CLM_PROD_D=$DCFG CLM_PROD_T=$TCFG CLM_PROD_E=2 CLM_PROD_NSAMP=$NS CLM_PROD_EPOCHS=$EPO \
     CLM_PROD_CORPUS=~/work/corpus.txt "$@" \
     timeout 2400 ./clm_prod_gpu >"$t" 2>&1; local rc=$?; kill $sp 2>/dev/null
 echo "--- $lbl rc=$rc ---"
 python3 -c "u=[int(x) for x in open('$u') if x.strip()];print(f'  util MEAN={sum(u)/len(u):.2f}% PEAK={max(u)}% pct>=20={100*sum(1 for x in u if x>=20)/len(u):.1f}% n={len(u)}')" 2>/dev/null || echo "  (util parse fail)"
 echo "  [EAGER-DEVGLUE-FIRED]=$(grep -c 'EAGER-DEVGLUE-FIRED' "$t")  [MEGAFWD-FIRED]=$(grep -c 'MEGAFWD-FIRED' "$t")  [OWN-GEMM-FIRED]=$(grep -c 'OWN-GEMM-FIRED' "$t")"
 echo "  $(grep 'B6-CE-HIPREC' "$t" | tail -1)"
 echo "  DESCENT=$(grep -E 'F-CLM-PROD-DESCENT' "$t" | tail -1)"
}

echo "=== A = device-EAGER (HEXA_EAGER_DEVRESIDENT=1, megastep OFF) ==="
fire eager HEXA_EAGER_DEVRESIDENT=1
echo "=== B = device-MEGA (HEXA_CLM_MEGASTEP=1 FP64) ==="
fire mega HEXA_CLM_MEGASTEP=1 HEXA_CLM_MEGASTEP_FP64=1

echo "=== byte-eq diff (verbatim 17-digit CE) ==="
grep 'B6-CE-HIPREC' train_eager.log | tail -1
grep 'B6-CE-HIPREC' train_mega.log  | tail -1
python3 - <<'PY'
import re
def ce(f):
    s=open(f).read(); m=re.search(r'first_ce=([0-9.eE+-]+).*?last_ce=([0-9.eE+-]+)', s.split('B6-CE-HIPREC')[-1]);
    return (float(m.group(1)),float(m.group(2))) if m else (None,None)
a=ce('train_eager.log'); b=ce('train_mega.log')
print("A device-eager first/last:", a); print("B device-mega first/last:", b)
if None not in a+b:
    print(f"max|Δ first_ce| = {abs(a[0]-b[0]):.6e}")
    print(f"max|Δ last_ce|  = {abs(a[1]-b[1]):.6e}")
    print("BYTE-EQ MEGAKERNEL ACHIEVED" if abs(a[0]-b[0])==0.0 else "RESIDUAL ≠ 0 (report which op)")
PY
echo "=== DONE ==="
