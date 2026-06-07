#!/usr/bin/env bash
# ── HEXA-FUSION FF-XSTREAM fire script ───────────────────────────────────────
# Builds the cross-stream valley-overlap probe + comparator, then for each shape
# in the sweep runs SERIAL (HEXA_MULTISTREAM=0) vs MULTI (=1) with an inline
# nvidia-smi util sampler, computes byte-eq max|Δ| (serial-vs-multi), and prints
# a verbatim per-shape line: wall + util MEAN/MEDIAN single-vs-multi + max|Δ|.
#
# GATE (g5): (1) byte-eq max|Δ|==0 serial-vs-multi; (2) wall + util single-vs-multi.
#
# Usage: ./fire_ff_xstream.sh   (env: ARCH=sm_90  SHAPES="E:d:T:K:dil ...")
set -u
ARCH="${ARCH:-sm_90}"
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HERE/gpu_ff_xstream"
DIFF="$HERE/ff_xstream_maxdiff"
# Sweep: representative MoE-block shapes spanning under-fill → saturated.
# E:d:T:K:dil  (d small = deeper under-fill = more valley to reclaim).
SHAPES="${SHAPES:-30:512:256:3:1 30:1024:256:3:1 30:2048:256:3:1 30:6208:256:3:1}"
ITERS="${ITERS:-50}"; export ITERS
WARMUP="${WARMUP:-5}"; export WARMUP
SUSTAIN_SEC="${SUSTAIN_SEC:-3.0}"

echo "=== FF-XSTREAM build (arch=$ARCH) ==="
nvcc -arch="$ARCH" -O3 -o "$BIN" "$HERE/gpu_ff_xstream.cu" || { echo "BUILD FAIL"; exit 1; }
cc -O2 -o "$DIFF" "$HERE/ff_xstream_maxdiff.c" -lm || { echo "DIFF BUILD FAIL"; exit 1; }
echo "build OK"
echo

# util sampler: background nvidia-smi → compute MEAN + MEDIAN over the window.
util_stats() {  # $1 = csv file of integer util%
  awk -F',' '/^[0-9 ]+/{gsub(/ /,"",$1); if($1!=""){a[n++]=$1; s+=$1}}
    END{ if(n==0){print "MEAN=na MEDIAN=na N=0"; exit}
         # median
         for(i=0;i<n;i++) for(j=i+1;j<n;j++) if(a[j]<a[i]){t=a[i];a[i]=a[j];a[j]=t}
         med = (n%2)? a[int(n/2)] : (a[n/2-1]+a[n/2])/2.0
         printf "MEAN=%.2f MEDIAN=%.2f N=%d\n", s/n, med, n }' "$1"
}

run_mode() {  # $1=label $2=ms_flag  shape args in $E $d $T $K $dil ; sets WALL,UMEAN,UMED
  local lbl="$1" ms="$2" csv; csv="$(mktemp)"
  ( nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader -lms 50 > "$csv" 2>/dev/null ) &
  local sampler=$!
  sleep 0.3
  local out
  out="$(HEXA_MULTISTREAM="$ms" SUSTAIN_SEC="$SUSTAIN_SEC" DUMP_Y="$DUMPF" \
        "$BIN" "$E" "$d" "$T" "$K" "$dil")"
  kill "$sampler" 2>/dev/null; wait "$sampler" 2>/dev/null
  WALL="$(echo "$out" | sed -n 's/^STEP_WALL_MS=\([0-9.]*\).*/\1/p')"
  local st; st="$(util_stats "$csv")"
  UMEAN="$(echo "$st" | sed -n 's/.*MEAN=\([0-9.na]*\).*/\1/p')"
  UMED="$(echo "$st"  | sed -n 's/.*MEDIAN=\([0-9.na]*\).*/\1/p')"
  rm -f "$csv"
  echo "  [$lbl] wall=${WALL}ms util_mean=${UMEAN}% util_median=${UMED}% ($st)"
}

for shape in $SHAPES; do
  IFS=':' read -r E d T K dil <<< "$shape"
  echo "=== shape E=$E d=$d T=$T K=$K dil=$dil ==="
  YS="$(mktemp)"; YM="$(mktemp)"

  DUMPF="$YS"; run_mode "SERIAL" 0
  SW="$WALL"; SUM="$UMEAN"; SUMED="$UMED"
  DUMPF="$YM"; run_mode "MULTI " 1
  MW="$WALL"; MUM="$UMEAN"; MUMED="$UMED"

  GATE="$("$DIFF" "$YS" "$YM")"; GRC=$?
  MAXD="$(echo "$GATE" | sed -n 's/.*MAXDIFF=\([0-9.eE+\-naN]*\).*/\1/p')"
  SPEEDUP="$(awk -v s="$SW" -v m="$MW" 'BEGIN{ if(m>0) printf "%.4f", s/m; else print "na" }')"
  RECLAIM="$(awk -v s="$SUM" -v m="$MUM" 'BEGIN{ printf "%.2f", m-s }')"
  if [ "$GRC" -eq 0 ]; then BE="PASS(max|Δ|=0)"; else BE="FAIL(max|Δ|=$MAXD)"; fi
  echo "  >> BYTE-EQ $BE  serial-vs-multi"
  echo "  >> WALL serial=${SW}ms multi=${MW}ms  speedup=${SPEEDUP}x"
  echo "  >> UTIL mean serial=${SUM}% multi=${MUM}% (Δ=${RECLAIM}pp)  median serial=${SUMED}% multi=${MUMED}%"
  echo "RESULT shape=$shape byteeq=$BE wall_serial=$SW wall_multi=$MW speedup=$SPEEDUP util_serial_mean=$SUM util_multi_mean=$MUM util_reclaim_pp=$RECLAIM util_serial_med=$SUMED util_multi_med=$MUMED"
  rm -f "$YS" "$YM"
  echo
done
echo "=== FF-XSTREAM fire complete ==="
