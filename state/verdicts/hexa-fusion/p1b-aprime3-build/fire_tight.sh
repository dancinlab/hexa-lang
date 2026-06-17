#!/usr/bin/env bash
# fire_tight.sh — TIGHT ASYNC-OFF capstone (EPOCHS=2 for speed, beats vast host-loss).
# eager x2 + mega x2, each a FRESH process. Gate1 = within-arm Δ0. Gate2 = max|Δ| eager-vs-mega.
set -uo pipefail
cd ~/work
DCFG=${DCFG:-1536}; TCFG=${TCFG:-512}; EPO=${EPO:-2}; NS=${NS:-8}
run_one(){ local lbl=$1; shift
 local u=~/work/u_$lbl.csv t=~/work/t_$lbl.log; : > "$u"
 ( while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0 >>"$u" 2>/dev/null; sleep 0.5; done ) & local sp=$!
 env CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 \
     HEXA_OWN_GEMM=1 HEXA_CUDA_ASYNC=0 \
     CLM_PROD_D=$DCFG CLM_PROD_T=$TCFG CLM_PROD_E=2 CLM_PROD_NSAMP=$NS CLM_PROD_EPOCHS=$EPO \
     CLM_PROD_CORPUS=~/work/corpus.txt "$@" timeout 900 ./clm_prod_gpu >"$t" 2>&1
 local rc=$?; kill $sp 2>/dev/null
 echo "--- $lbl rc=$rc ---"
 python3 -c "u=[int(x) for x in open('$u') if x.strip()];print(f'  util MEAN={sum(u)/len(u):.2f}% PEAK={max(u)}% pct>=20={100*sum(1 for x in u if x>=20)/len(u):.1f}% n={len(u)}')" 2>/dev/null || echo "  (util parse fail)"
 echo "  [EAGER-DEVGLUE-FIRED]=$(grep -c 'EAGER-DEVGLUE-FIRED' "$t")  [MEGAFWD-FIRED]=$(grep -c 'MEGAFWD-FIRED' "$t")  [OWN-GEMM-FIRED]=$(grep -c 'OWN-GEMM-FIRED' "$t")"
 echo "  $(grep 'B6-CE-HIPREC' "$t" | tail -1)"
 echo "  DESCENT=$(grep -E 'F-CLM-PROD-DESCENT' "$t" | tail -1)"
}
echo "############ TIGHT ASYNC=0 capstone (EPOCHS=$EPO; eager x2, mega x2) ############"
echo "=== A1 device-EAGER ===";        run_one eager1 HEXA_EAGER_DEVRESIDENT=1
echo "=== B1 device-MEGA ===";         run_one mega1  HEXA_CLM_MEGASTEP=1 HEXA_CLM_MEGASTEP_FP64=1
echo "=== A2 device-EAGER (repro) ==="; run_one eager2 HEXA_EAGER_DEVRESIDENT=1
echo "=== B2 device-MEGA (repro) ===";  run_one mega2  HEXA_CLM_MEGASTEP=1 HEXA_CLM_MEGASTEP_FP64=1
echo ""
echo "############ BYTE-EQ DIFF (verbatim 17-digit CE) ############"
python3 - <<'PY'
import re
def ce(f):
    try: s=open(f).read()
    except FileNotFoundError: return (None,None)
    seg=s.split('B6-CE-HIPREC')[-1]
    m=re.search(r'first_ce=([0-9.eE+-]+)\s+last_ce=([0-9.eE+-]+)', seg)
    return (m.group(1),m.group(2)) if m else (None,None)
e1=ce('/root/work/t_eager1.log'); e2=ce('/root/work/t_eager2.log')
m1=ce('/root/work/t_mega1.log');  m2=ce('/root/work/t_mega2.log')
print("eager1:",e1); print("eager2:",e2); print("mega1: ",m1); print("mega2: ",m2)
print("[LADDER eager] run-to-run Δ0:", e1==e2 and None not in e1)
print("[LADDER mega ] run-to-run Δ0:", m1==m2 and None not in m1)
if None not in e1+m1:
    print(f"max|Δ first_ce| eager-vs-mega = {abs(float(e1[0])-float(m1[0])):.6e}")
    print(f"max|Δ last_ce|  eager-vs-mega = {abs(float(e1[1])-float(m1[1])):.6e}")
    print("BYTE-EQ MEGAKERNEL CAPSTONE ACHIEVED (string-identical CE)" if (e1[0]==m1[0] and e1[1]==m1[1])
          else "RESIDUAL != 0 (report which op)")
PY
echo "=== DONE ==="
