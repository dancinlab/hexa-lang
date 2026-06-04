#!/usr/bin/env bash
# util_megastep.sh — external nvidia-smi util sampler for the H1b megakernel
# sub-chain A/B. Samples GPU util MEAN while ONE path runs in a sustained loop,
# for BOTH the eager (3-launch) and megakernel (1-coop-launch) realizations of
# the SAME GEMM→gelu→GEMM sub-chain. Answers: does collapsing the launch-gaps
# raise util on the SAME sub-chain?
set -uo pipefail
cd "$(dirname "$0")"
[ -x ./megakernel_driver ] || { echo "build first: ./build_megastep.sh"; exit 1; }
echo "=== env ==="; nvidia-smi --query-gpu=name --format=csv,noheader | head -1
sample(){  # $1=label $2=MEGASTEP_LOOP value
  MEGASTEP_LOOP="$2" HEXA_CLM_MEGASTEP=1 ./megakernel_driver >/dev/null 2>&1 &
  P=$!; S=""
  while kill -0 $P 2>/dev/null; do
    u=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits|head -1)
    S="$S $u"; sleep 0.2
  done
  wait $P
  echo "$S" | tr ' ' '\n' | grep -E '^[0-9]+$' | \
    awk '{s+=$1;n++; if($1>mx)mx=$1} END{printf "  %-22s util: MEAN %.1f%%  PEAK %d%%  (n=%d)\n","'"$1"'",s/n,mx,n}'
}
echo "=== util sustained-loop on the SAME GEMM->gelu->GEMM sub-chain (15s each) ==="
sample "eager (3 launches)"   eager
sample "megakernel (1 coop)"  mega
echo "=== DONE ==="
