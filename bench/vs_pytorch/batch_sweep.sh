#!/usr/bin/env bash
# batch_sweep.sh — HEXA-FUSION batch-fill THROUGHPUT (samples/s) sweep on a real H100/H200.
# For each B in the sweep, measures samples/s via 2-POINT linear timing (subtracts the
# one-time init/corpus-load intercept — fair to flame, same method as F-FUSION-VS-PYTORCH),
# plus nvidia-smi util over a sustained window. samples/s = (B·nbatch·epochs)/per-step-wall.
#
# Prereqs on pod (built by rebuild.sh from the CURRENT clm_prod.hexa M5-batch bundle):
#   $WORK/clm_prod_gpu  +  $WORK/corpus.txt
#
# Env: D=1536 T=512 E=2 K=3 (production-proxy). BATCHES="1 2 4 8 16 32 64".
set -o pipefail
WORK="${WORK:-$HOME/work}"
D="${D:-1536}"; TW="${TW:-512}"; E="${E:-2}"; K="${K:-3}"
BATCHES="${BATCHES:-1 2 4 8 16 32 64}"
cd "$WORK" || exit 1

echo "================ HEXA-FUSION batch-fill THROUGHPUT sweep ================"
echo "host: $(hostname)  $(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader | head -1)"
echo "shape: D=$D Tw=$TW E=$E K=$K  | BATCHES=[$BATCHES]"
echo "nvcc: $(nvcc --version 2>/dev/null | grep release)"
echo

# Run the trainer for a given (B, NSAMP, EPOCHS); echoes the M5-BATCH steps line.
# CLM_PROD_BATCH=B concatenates B distinct windows into M=B*Tw per step.
flame_run() {  # $1=B $2=NSAMP $3=EPOCHS  -> stdout flame log
  # async follows CLM_PROD_DEVRESIDENT=1 (production fast path, +9% win r5).
  # HEXA_CUDA_ASYNC=0 was removed (masked the real throughput, see run_3way.sh).
  CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 \
    CLM_PROD_D=$D CLM_PROD_T=$TW CLM_PROD_E=$E CLM_PROD_BATCH=$1 \
    CLM_PROD_NSAMP=$2 CLM_PROD_EPOCHS=$3 \
    CLM_PROD_CORPUS="$WORK/corpus.txt" \
    timeout 3600 ./clm_prod_gpu 2>&1
}

steps_of() { grep -oE 'steps=[0-9]+' "$1" | tail -1 | cut -d= -f2; }

printf "%-4s %-7s %-9s %-9s %-9s %-9s %-7s %s\n" B T_eff wall_lo wall_hi sps_2pt xB util_m_p notes
echo  "---------------------------------------------------------------------------------------"

B1_SPS=""
for B in $BATCHES; do
  # Need nwin >= B so nbatch>=1. Use NSAMP windows; for a 2-point timing pick a SHORT
  # leg (S_LO batches) and a LONG leg (S_HI batches). nbatch = floor(nwin/B); steps = nbatch*epochs.
  # Choose NSAMP large enough that nwin >= B * S_HI so the long leg has S_HI steps in 1 epoch.
  S_LO=2; S_HI=8
  # taller batches => slower per step; cap S_HI for very large B to bound wall.
  if [ "$B" -ge 32 ]; then S_HI=4; fi
  NSAMP_LO=$(( B * S_LO + 2 ))
  NSAMP_HI=$(( B * S_HI + 2 ))

  # --- short leg (intercept anchor) ---
  T0=$(date +%s.%N)
  flame_run "$B" "$NSAMP_LO" 1 > "flame_${B}_lo.txt"
  T1=$(date +%s.%N)
  WALL_LO=$(python3 -c "print(f'{$T1-$T0:.3f}')")
  ST_LO=$(steps_of "flame_${B}_lo.txt"); ST_LO="${ST_LO:-0}"

  # --- long leg, with util sampling over the sustained window ---
  UF="util_b${B}.csv"; : > "$UF"
  ( while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0 >> "$UF" 2>/dev/null; sleep 0.2; done ) &
  SP=$!
  T2=$(date +%s.%N)
  flame_run "$B" "$NSAMP_HI" 1 > "flame_${B}_hi.txt"
  T3=$(date +%s.%N)
  kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
  WALL_HI=$(python3 -c "print(f'{$T3-$T2:.3f}')")
  ST_HI=$(steps_of "flame_${B}_hi.txt"); ST_HI="${ST_HI:-0}"

  # per-step slope = (wall_hi - wall_lo) / (steps_hi - steps_lo); samples/s = B / slope
  read SPS UTILM <<EOF
$(python3 - "$WALL_LO" "$ST_LO" "$WALL_HI" "$ST_HI" "$B" "$UF" <<'PY'
import sys
wlo,slo,whi,shi,B,uf=float(sys.argv[1]),int(sys.argv[2]),float(sys.argv[3]),int(sys.argv[4]),int(sys.argv[5]),sys.argv[6]
slope = (whi-wlo)/(shi-slo) if (shi-slo)>0 else (whi/shi if shi>0 else 0)
sps = (B/slope) if slope>0 else 0.0
vals=[int(x) for x in open(uf) if x.strip().isdigit()] if __import__('os').path.exists(uf) else []
vals.sort()
if vals:
  n=len(vals); m=sum(vals)/n; med=vals[n//2]; pk=vals[-1]
  utilm=f"{m:.1f}/{med}/{pk}"
else:
  utilm="0/0/0"
print(f"{sps:.4f} {utilm}")
PY
)
EOF

  if [ -z "$B1_SPS" ]; then B1_SPS="$SPS"; fi
  XB=$(python3 -c "b=$SPS; r=$B1_SPS; print(f'{(b/r) if r>0 else 0:.3f}x')")
  TEFF=$(( B * TW ))
  CE=$(grep -iE 'mean CE|DESCENT' "flame_${B}_hi.txt" | tail -2 | tr '\n' ' ' | cut -c1-40)
  printf "%-4s %-7s %-9s %-9s %-9s %-9s %-7s %s\n" "$B" "$TEFF" "$WALL_LO" "$WALL_HI" "$SPS" "$XB" "$UTILM" "$CE"
done

echo
echo "================ done — samples/s = (steps_hi-steps_lo)-slope-derived, B=1 = ref ================"
echo "(verbatim flame logs: flame_<B>_{lo,hi}.txt ; util: util_b<B>.csv)"
