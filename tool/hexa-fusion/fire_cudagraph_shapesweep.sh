#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
# HEXA-FUSION L2 ④ — per-step CUDA-graph capture/replay WALL sweep.
#
# Realizes the launch-overhead-amortization win the domain proved analytically
# (⑧ F-FUSION-LAUNCH-AMORT: n*<0 ⇒ ≥30% wall win UNCONDITIONAL in the
# launch-bound regime). Prior verdicts (F-FUSION-GRAPH-AB / -WHOLESTEP-AB)
# measured UTIL at ONE large shape (D=1536/T=512 = BW-bound) and found the wall
# unchanged. THIS sweep measures the per-step WALL across a SHAPE SWEEP to find
# the launch-bound regime where the ≥30% holds and the BW-bound crossover.
#
# Per cell: same step budget eager (GRAPH=0) vs replay (GRAPH=1), wall via
# /usr/bin/time, per-step wall = wall / steps (steps = EPOCHS*nwin deterministic).
# byte-eq gate = epoch-1 / epoch-N mean CE bit-identical between GRAPH=0/1.
#
# Two regimes swept:
#   LAUNCH-BOUND  : small D, small T  (per-step kernels tiny → host launch dominates)
#   BW-BOUND      : large D, large T  (per-step kernels big  → roofline dominates)
# ════════════════════════════════════════════════════════════════════════════
set -uo pipefail
WORK="${WORK:-$HOME/work}"
cd "$WORK"
BIN=./clm_prod_gpu
CORPUS="$WORK/corpus.txt"

echo "=== env ==="
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader -i 0
nvcc --version 2>/dev/null | tail -1

# shape sweep: (D, T, EPOCHS, NSAMP, regime-label)
#   launch-bound : kernels small, many cheap steps
#   mid          : crossover band
#   bw-bound     : production shape (prior verdict shape) = roofline
SWEEP=(
  "128   32   8  16  launch-bound"
  "256   64   8  16  launch-bound"
  "512  128   6  12  mid"
  "768  256   5  10  mid"
  "1536 512   4   8  bw-bound"
)

run_cell(){ # $1=graph $2=D $3=T $4=EP $5=NS  -> prints "wall_s steps ce1 ceN"
  local g=$1 D=$2 T=$3 EP=$4 NS=$5
  local log="$WORK/sw_g${g}_D${D}_T${T}.log"
  export CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1
  export HEXA_CUDA_GRAPH=$g HEXA_CUDA_ASYNC=0
  export CLM_PROD_D=$D CLM_PROD_T=$T CLM_PROD_E=2 CLM_PROD_NSAMP=$NS CLM_PROD_EPOCHS=$EP CLM_PROD_CORPUS="$CORPUS"
  local t0 t1
  t0=$(date +%s.%N)
  timeout 1800 $BIN >"$log" 2>&1; local rc=$?
  t1=$(date +%s.%N)
  local wall; wall=$(python3 -c "print(f'{$t1-$t0:.3f}')")
  local nwin; nwin=$(grep -oE 'windows: [0-9]+' "$log" | head -1 | grep -oE '[0-9]+')
  local steps; steps=$(python3 -c "print(${EP}*${nwin:-0})" 2>/dev/null || echo 0)
  local ce1 ceN
  ce1=$(grep 'epoch-1 mean CE' "$log" | grep -oE '[0-9.]+' | tail -1)
  ceN=$(grep -E "epoch-${EP} mean CE" "$log" | grep -oE '[0-9.]+' | tail -1)
  echo "${wall} ${steps} ${ce1:-NA} ${ceN:-NA} ${rc}"
}

printf '%-13s | %-9s | %-9s | %-10s | %-7s | %-8s | byteeq\n' \
  "regime" "D/T" "eager s/st" "replay s/st" "speedup" "Δwall%"
printf '%s\n' "------------------------------------------------------------------------------------"

for row in "${SWEEP[@]}"; do
  read -r D T EP NS REG <<<"$row"
  echo ">>> SWEEP D=$D T=$T EP=$EP NS=$NS ($REG)" >&2
  read -r w0 st0 c10 cN0 rc0 <<<"$(run_cell 0 $D $T $EP $NS)"
  read -r w1 st1 c11 cN1 rc1 <<<"$(run_cell 1 $D $T $EP $NS)"
  python3 - "$D" "$T" "$EP" "$REG" "$w0" "$st0" "$c10" "$cN0" "$rc0" "$w1" "$st1" "$c11" "$cN1" "$rc1" <<'PY'
import sys
D,T,EP,REG=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]
w0,st0,c10,cN0,rc0=sys.argv[5:10]
w1,st1,c11,cN1,rc1=sys.argv[10:15]
def f(x):
    try: return float(x)
    except: return float('nan')
w0,w1=f(w0),f(w1); st0,st1=f(st0),f(st1)
ps0=w0/st0 if st0 else float('nan')
ps1=w1/st1 if st1 else float('nan')
spd=ps0/ps1 if ps1 else float('nan')
dwall=100*(ps0-ps1)/ps0 if ps0 else float('nan')
beq = "Y" if (c10==c11 and cN0==cN1 and c10 not in("NA","") ) else "N"
print(f'{REG:<13} | {D}/{T:<5} | {ps0:>9.4f} | {ps1:>9.4f} | {spd:>6.3f}x | {dwall:>7.2f} | {beq}  (rc {rc0}/{rc1}; ce {c10}/{c11} {cN0}/{cN1})')
PY
done
echo "=== DONE ==="
