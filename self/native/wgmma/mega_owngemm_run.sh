#!/usr/bin/env bash
# MEGA-OWNGEMM-INTEGRATE on-pod runner. Native sm_90a H100.
# Builds the co-residence probe (OG17 wgmma GEMM vs the megakernel coop one-wave
# constraint) + the OG17 byte-eq sanity, prints a structured PROBE-* report.
set -uo pipefail
cd "$(dirname "$0")"
ARCH=sm_90a
S=${1:-2048}
NST=${2:-3}
echo "### nvcc build mega_owngemm_integrate.cu (arch=$ARCH) ###"
nvcc -O3 -arch=$ARCH -lcuda -lcublas mega_owngemm_integrate.cu -o /tmp/mega_probe 2>&1 | tail -40
if [ ! -x /tmp/mega_probe ]; then echo "BUILD-FAIL"; exit 1; fi
echo "### run probe S=$S NST=$NST ###"
/tmp/mega_probe "$S" "$NST"
echo "### run probe NST=2 (occupancy sweep) ###"
/tmp/mega_probe "$S" 2
