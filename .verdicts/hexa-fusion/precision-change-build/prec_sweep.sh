#!/usr/bin/env bash
# prec_sweep.sh — HEXA-FUSION precision-change axis on a real H100/H200.
# For prec in {fp64, tf32, bf16} and B in the batch sweep, measure:
#   · rel_rms vs FP64 on the FIRST GEMM ([PREC-GATE] line, W14 gate ≤1e-2)
#   · step/s via 2-point timing (subtract the one-time init/corpus-load intercept)
#   · util mean/median/peak (nvidia-smi sustained window over the long leg)
# step/s = (steps_hi-steps_lo)/(wall_hi-wall_lo)  (intercept cancels).
# samples/s = B * step/s.  Reports TF32/BF16-vs-FP64 speedup + util-median move.
set -o pipefail
WORK="${WORK:-$HOME/work}"
D="${D:-1536}"; TW="${TW:-512}"; E="${E:-2}"; K="${K:-3}"
BATCHES="${BATCHES:-1 4 8 16}"
PRECS="${PRECS:-fp64 tf32 bf16}"
cd "$WORK" || exit 1

echo "================ HEXA-FUSION precision-change sweep ================"
echo "host: $(hostname)  $(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader -i 0 | head -1)"
echo "shape: D=$D Tw=$TW E=$E K=$K  | BATCHES=[$BATCHES] | PRECS=[$PRECS]"
echo "nvcc: $(nvcc --version 2>/dev/null | grep release)"
echo

flame_run() {  # $1=B $2=NSAMP $3=EPOCHS $4=PREC -> stdout flame log (stderr merged)
  CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 \
    HEXA_CUDA_ASYNC=0 HEXA_GEMM_PREC=$4 \
    CLM_PROD_D=$D CLM_PROD_T=$TW CLM_PROD_E=$E CLM_PROD_BATCH=$1 \
    CLM_PROD_NSAMP=$2 CLM_PROD_EPOCHS=$3 \
    CLM_PROD_CORPUS="$WORK/corpus.txt" \
    timeout 2400 ./clm_prod_gpu 2>&1
}
steps_of() { grep -oE 'steps=[0-9]+' "$1" | tail -1 | cut -d= -f2; }
ce1_of()  { grep -oE 'epoch-1 mean CE = [0-9.]+' "$1" | tail -1 | grep -oE '[0-9.]+$'; }

printf "%-5s %-4s %-7s %-9s %-9s %-10s %-9s %-9s %s\n" prec B T_eff wall_lo wall_hi step/s xFP64 util_m/md/pk gate_relrms
echo  "-----------------------------------------------------------------------------------------------------"

declare -A FP64_SPS
for B in $BATCHES; do
  S_LO=2; S_HI=8
  if [ "$B" -ge 16 ]; then S_HI=4; fi
  NSAMP_LO=$(( B * S_LO + 2 ))
  NSAMP_HI=$(( B * S_HI + 2 ))
  for PREC in $PRECS; do
    # short leg (intercept anchor)
    T0=$(date +%s.%N); flame_run "$B" "$NSAMP_LO" 1 "$PREC" > "f_${PREC}_${B}_lo.txt"; T1=$(date +%s.%N)
    WALL_LO=$(python3 -c "print(f'{$T1-$T0:.3f}')"); ST_LO=$(steps_of "f_${PREC}_${B}_lo.txt"); ST_LO="${ST_LO:-0}"
    # long leg + util sampling
    UF="util_${PREC}_${B}.csv"; : > "$UF"
    ( while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0 >> "$UF" 2>/dev/null; sleep 0.2; done ) & SP=$!
    T2=$(date +%s.%N); flame_run "$B" "$NSAMP_HI" 1 "$PREC" > "f_${PREC}_${B}_hi.txt"; T3=$(date +%s.%N)
    kill "$SP" 2>/dev/null
    WALL_HI=$(python3 -c "print(f'{$T3-$T2:.3f}')"); ST_HI=$(steps_of "f_${PREC}_${B}_hi.txt"); ST_HI="${ST_HI:-0}"
    # step/s = dsteps/dwall
    SPS=$(python3 -c "lo,hi,wl,wh=$ST_LO,$ST_HI,$WALL_LO,$WALL_HI; print(f'{(hi-lo)/(wh-wl):.5f}' if (wh-wl)>0 and (hi-lo)>0 else '0')")
    if [ "$PREC" = "fp64" ]; then FP64_SPS[$B]=$SPS; fi
    XF=$(python3 -c "b='${FP64_SPS[$B]:-0}'; s='$SPS'; b=float(b); s=float(s); print(f'{s/b:.3f}' if b>0 else 'n/a')")
    UM=$(python3 -c "import statistics as st;v=[int(x) for x in open('$UF') if x.strip().isdigit()];print(f'{(sum(v)/len(v) if v else 0):.1f}/{(st.median(v) if v else 0)}/{(max(v) if v else 0)}')" 2>/dev/null)
    GR=$(grep -oE 'rel_rms_vs_fp64=[0-9.e+-]+ gate\(<=1e-2\)=[A-Z]+' "f_${PREC}_${B}_hi.txt" "f_${PREC}_${B}_lo.txt" 2>/dev/null | head -1 | cut -d: -f2-)
    [ "$PREC" = "fp64" ] && GR="(baseline)"
    CE=$(ce1_of "f_${PREC}_${B}_hi.txt")
    T_EFF=$(( B * TW ))
    printf "%-5s %-4s %-7s %-9s %-9s %-10s %-9s %-9s %s\n" "$PREC" "$B" "$T_EFF" "$WALL_LO" "$WALL_HI" "$SPS" "$XF" "$UM" "$GR"
    echo "   [RAW] prec=$PREC B=$B st_lo=$ST_LO st_hi=$ST_HI wall_lo=$WALL_LO wall_hi=$WALL_HI step/s=$SPS xFP64=$XF util=$UM ce1=$CE gate=$GR"
  done
done
echo "================ sweep complete ================"
