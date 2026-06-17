#!/usr/bin/env bash
# fire_p1b_aprime3.sh — HEXA-FUSION P1B-a''' byte-eq megakernel CAPSTONE (ASYNC-OFF), run ON POD in ~/work.
# THE CURE (N1N2 #2789): the ~1e-1 device-glue non-determinism that blocked the byte-eq
# capstone is an ASYNC CROSS-STREAM RACE — HEXA_CUDA_ASYNC=0 makes the device forward
# BIT-REPRODUCIBLE (CE 4.4662394504526679 x5 identical). With the race off, both arms share
# CUDA erf + identical own-GEMM + deterministic glue → PREDICTION max|Δ| device-eager vs
# device-mega = 0 (or the clean ~1 ULP erf floor; between two DEVICE runs both CUDA-erf = 0).
#
# Both arms = own-GEMM (HEXA_OWN_GEMM=1) + DEVRESIDENT chain + **HEXA_CUDA_ASYNC=0** (hard kill switch).
#   A = device-EAGER reference: HEXA_EAGER_DEVRESIDENT=1, megastep OFF
#       → fwd glue (gelu/groupnorm/softmax) on-device as SEPARATE launches, CUDA erf.
#       expect [EAGER-DEVGLUE-FIRED] ; [MEGAFWD-FIRED]=0
#   B = device-MEGA: HEXA_CLM_MEGASTEP=1 HEXA_CLM_MEGASTEP_FP64=1
#       → cooperative full-fwd megakernel, CUDA erf. expect [MEGAFWD-FIRED]>=1
# Gate 1 (reproducibility ladder): each arm x3 under ASYNC=0 → run-to-run Δ=0.
# Gate 2 (CAPSTONE byte-eq):       max|Δ|=0 on 17-digit [B6-CE-HIPREC] first_ce/last_ce,
#                                  device-eager vs device-mega, both ASYNC=0. VERBATIM.
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

# run ONE training, tag $1=label, $2..=extra env. ALWAYS HEXA_CUDA_ASYNC=0.
run_one(){
 local lbl=$1; shift
 local u=~/work/util_$lbl.csv t=~/work/train_$lbl.log; : > "$u"
 ( while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0 >>"$u" 2>/dev/null; sleep 0.5; done ) & local sp=$!
 env CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 \
     HEXA_OWN_GEMM=1 HEXA_CUDA_ASYNC=0 \
     CLM_PROD_D=$DCFG CLM_PROD_T=$TCFG CLM_PROD_E=2 CLM_PROD_NSAMP=$NS CLM_PROD_EPOCHS=$EPO \
     CLM_PROD_CORPUS=~/work/corpus.txt "$@" \
     timeout 2400 ./clm_prod_gpu >"$t" 2>&1; local rc=$?; kill $sp 2>/dev/null
 echo "--- $lbl rc=$rc ---"
 python3 -c "u=[int(x) for x in open('$u') if x.strip()];print(f'  util MEAN={sum(u)/len(u):.2f}% PEAK={max(u)}% pct>=20={100*sum(1 for x in u if x>=20)/len(u):.1f}% n={len(u)}')" 2>/dev/null || echo "  (util parse fail)"
 echo "  [EAGER-DEVGLUE-FIRED]=$(grep -c 'EAGER-DEVGLUE-FIRED' "$t")  [MEGAFWD-FIRED]=$(grep -c 'MEGAFWD-FIRED' "$t")  [OWN-GEMM-FIRED]=$(grep -c 'OWN-GEMM-FIRED' "$t")"
 echo "  $(grep 'B6-CE-HIPREC' "$t" | tail -1)"
 echo "  DESCENT=$(grep -E 'F-CLM-PROD-DESCENT' "$t" | tail -1)"
}

echo ""
echo "############################################################"
echo "# GATE 1 — run-to-run REPRODUCIBILITY ladder (ASYNC=0, x3 each arm)"
echo "############################################################"
echo "=== A = device-EAGER (HEXA_EAGER_DEVRESIDENT=1, megastep OFF), ASYNC=0, x3 ==="
run_one eager_r1 HEXA_EAGER_DEVRESIDENT=1
run_one eager_r2 HEXA_EAGER_DEVRESIDENT=1
run_one eager_r3 HEXA_EAGER_DEVRESIDENT=1
echo "=== B = device-MEGA (HEXA_CLM_MEGASTEP=1 FP64), ASYNC=0, x3 ==="
run_one mega_r1 HEXA_CLM_MEGASTEP=1 HEXA_CLM_MEGASTEP_FP64=1
run_one mega_r2 HEXA_CLM_MEGASTEP=1 HEXA_CLM_MEGASTEP_FP64=1
run_one mega_r3 HEXA_CLM_MEGASTEP=1 HEXA_CLM_MEGASTEP_FP64=1

# canonical arms for the cross-diff = r1 of each
cp ~/work/train_eager_r1.log ~/work/train_eager.log
cp ~/work/train_mega_r1.log  ~/work/train_mega.log

echo ""
echo "############################################################"
echo "# GATE 2 — CAPSTONE byte-eq diff (device-eager vs device-mega, ASYNC=0)"
echo "############################################################"
grep 'B6-CE-HIPREC' train_eager.log | tail -1
grep 'B6-CE-HIPREC' train_mega.log  | tail -1
python3 - <<'PY'
import re
def ce(f):
    s=open(f).read(); seg=s.split('B6-CE-HIPREC')[-1]
    m=re.search(r'first_ce=([0-9.eE+-]+)\s+last_ce=([0-9.eE+-]+)', seg)
    return (m.group(1),m.group(2)) if m else (None,None)
def cefs(label,n):
    import glob
    out=[]
    for i in (1,2,3):
        f=f'/root/work/train_{label}_r{i}.log'
        try: out.append(ce(f))
        except FileNotFoundError: out.append((None,None))
    return out
# reproducibility ladder
for lbl in ('eager','mega'):
    rs=cefs(lbl,3)
    firsts=[r[0] for r in rs]; lasts=[r[1] for r in rs]
    fok = len(set(firsts))==1 and firsts[0] is not None
    lok = len(set(lasts))==1  and lasts[0]  is not None
    print(f"[LADDER {lbl}] first_ce x3 = {firsts}  -> run-to-run Δ0(first)={fok}")
    print(f"[LADDER {lbl}] last_ce  x3 = {lasts}   -> run-to-run Δ0(last) ={lok}")
# cross-arm byte-eq (r1 canonical)
a=ce('/root/work/train_eager.log'); b=ce('/root/work/train_mega.log')
print("A device-eager first/last:", a); print("B device-mega first/last:", b)
if None not in a+b:
    fa=float(a[0]); fb=float(b[0]); la=float(a[1]); lb=float(b[1])
    print(f"max|Δ first_ce| = {abs(fa-fb):.6e}")
    print(f"max|Δ last_ce|  = {abs(la-lb):.6e}")
    # byte-eq on the verbatim 17-digit string is the hard gate
    streq = (a[0]==b[0] and a[1]==b[1])
    print("BYTE-EQ MEGAKERNEL CAPSTONE ACHIEVED (string-identical CE)" if streq
          else f"RESIDUAL ≠ 0 — report which op (erf ULP vs other)")
PY
echo "=== DONE ==="
