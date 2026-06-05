#!/usr/bin/env bash
cd /root/wgmma
nvcc -O3 -arch=sm_90a -o full wgmma_tf32_full.cu 2>&1 || { echo BUILDFAIL; exit 1; }
> /root/wgmma/sweep_results.txt
# Focused: descriptors fixed to the two physically-meaningful candidates.
# A row=32B(8 tf32). B row=256B(64 tf32). Core mtx tf32 = 8x8 (256B) or 8x4(128B).
for AL in 0 1 2; do for BL in 0 1 2 3; do for EPI in 0 1 2; do
for desc in "16 32 16 32" "32 256 256 32" "16 128 128 16" "128 16 16 128" "32 256 16 128"; do
  set -- $desc
  R=$(timeout 8 ./full $AL $BL $1 $2 $3 $4 $EPI 2>&1 | grep rel_rms)
  [ -n "$R" ] && echo "$R" >> /root/wgmma/sweep_results.txt
done; done; done; done
echo "TOTAL=$(wc -l < /root/wgmma/sweep_results.txt)"
echo "=== PASS ==="; grep PASS /root/wgmma/sweep_results.txt || echo NONE
echo "=== lowest 12 ==="; sort -t= -k8 -g /root/wgmma/sweep_results.txt 2>/dev/null | head -12
echo SWEEPDONE
