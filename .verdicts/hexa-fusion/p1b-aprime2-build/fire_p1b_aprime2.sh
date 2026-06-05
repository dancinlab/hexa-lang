#!/usr/bin/env bash
# fire_p1b_aprime2.sh — HEXA-FUSION P1B-a'' RACEFIX capstone (run ON POD in ~/work).
#
# P1B-a' (#2779) proved the device-resident GLUE path is RUN-TO-RUN
# NON-DETERMINISTIC (~7.1e-6 first_ce jitter on a single forward, fixed weight
# seeds) — host forward Δ=0, +own-GEMM Δ=0, +device glue ≈7e-6. Static analysis
# of the glue kernels (groupnorm/gelu/moe_router/residual/embedding) shows they
# are ALL single-thread-per-output sequential reductions with NO atomicAdd, NO
# tree re-assoc, and a full cudaDeviceSynchronize per launch — so there is no
# kernel-vs-kernel race. The ONLY run-to-run-varying input left on a fully
# synchronized single stream is UNINITIALIZED cudaMalloc memory: a glue kernel
# writes the live `need_len` region, but a downstream op / D2H copies the full
# host `e->len` (≥ need_len) and the GARBAGE TAIL (driver memory, varies
# process-to-process) leaks into a reduction.
#
# FIX (runtime_cuda.c): zero every freshly cudaMalloc'd OUTPUT buffer
# (_ensure_dev_alloc_out + GEMM-C + batched-C), gated HEXA_DEVGLUE_DETERMINIZE
# (default ON). The live region is fully overwritten -> CE byte-unchanged for a
# correct kernel; the tail is a deterministic 0.0 -> run-to-run reproducible.
#
# This script (1) PINS the race: full-forward determinism ladder x3 with the fix
# OFF (HEXA_DEVGLUE_DETERMINIZE=0 -> reproduce ~7e-6 jitter) vs ON (-> Δ=0);
# (2) re-runs the CAPSTONE A/B device-eager vs device-mega with the fix ON.
set -uo pipefail
cd ~/work
CUDA_LIB=$(dirname "$(find /usr/local/cuda* -name libcudart.so 2>/dev/null | head -1)")
DCFG=${DCFG:-1536}; TCFG=${TCFG:-512}; EPO=${EPO:-4}; NS=${NS:-8}

echo "=== GPU ==="; nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv,noheader -i 0
echo "=== inject 5 fusion dispatcher protos into self/runtime.h (idempotent) ==="
# clm_prod.c calls bare forge_dispatch_{gelu2,groupnorm_gelu,groupnorm_gelu_residual,
# moe_block2,clm_megafwd} but the l3d runtime.h lacks their protos -> implicit-int
# -> "invalid initializer". This adds them; bodies are in fusion_dispatch.c.
python3 insert_fusion_protos.py self/runtime.h \
  && echo "  fusion protos in runtime.h: $(grep -cE '^HexaVal forge_dispatch_(gelu2|groupnorm_gelu|groupnorm_gelu_residual|moe_block2|clm_megafwd)\(' self/runtime.h)" \
  || { echo "PROTO INSERT FAIL (anchor missing)"; exit 1; }
echo "=== nvcc compile runtime_cuda.c (racefix) ==="
# -rdc=true + compute_90 (grid.sync in the megafwd needs rdc); -DHEXA_CUDA mandatory.
nvcc -x cu -DHEXA_CUDA -rdc=true -gencode arch=compute_90,code=sm_90 -O2 -w \
     -I self/cuda -I self -I . -c runtime_cuda.c -o runtime_cuda.o 2>/tmp/nvcc.err \
  && echo "  runtime_cuda.o: $(stat -c%s runtime_cuda.o) bytes" \
  || { echo "NVCC FAIL"; tail -30 /tmp/nvcc.err; exit 1; }
nvcc -dlink -arch=sm_90 runtime_cuda.o -o runtime_cuda_dlink.o 2>/tmp/dlink.err \
  && echo "  dlink ok" || { echo "DLINK FAIL"; tail -20 /tmp/dlink.err; exit 1; }
echo "  MEGAFWD launchers: $(grep -c '_hx_k_clm_megafwd_fp64' runtime_cuda.c)  EAGER-DEVGLUE marker: $(grep -c 'EAGER-DEVGLUE-FIRED' runtime_cuda.c)  RACEFIX memset: $(grep -c 'P1B-a.. RACEFIX' runtime_cuda.c)"

echo "=== relink clm_prod_gpu (l3d self/runtime.c base + reconstructed L3-fusion dispatchers) ==="
# self/runtime.c is the L3D tree (has every PER-OP dispatcher this clm_prod.c
# needs) but NOT the 5 FUSED ops (gelu2/groupnorm_gelu/groupnorm_gelu_residual/
# moe_block2/clm_megafwd) — fusion_dispatch.c supplies those bare wrappers (the
# matching _hx_cuda_farr_<op>_gpu launchers are in the racefix runtime_cuda.o).
echo "  fusion_dispatch.c dispatchers: $(grep -cE '^HexaVal forge_dispatch_' fusion_dispatch.c)"
gcc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_CUDA -w -I self/cuda -I self -I . \
    clm_prod.c fusion_dispatch.c self/runtime.c runtime_cuda.o runtime_cuda_dlink.o \
    -L"$CUDA_LIB" -lcudart -lcublas -lcuda -lcudadevrt -lm -ldl -lpthread -o clm_prod_gpu 2>/tmp/relink.err \
  && echo "  clm_prod_gpu: $(stat -c%s clm_prod_gpu) bytes" || { echo "RELINK FAIL"; grep -iE 'error|undefined' /tmp/relink.err|head -20; exit 1; }

ce1(){ # single-forward first_ce (EPOCHS=1), echo verbatim 17-digit value
  env CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 \
      HEXA_OWN_GEMM=1 CLM_PROD_D=$DCFG CLM_PROD_T=$TCFG CLM_PROD_E=2 CLM_PROD_NSAMP=$NS \
      CLM_PROD_EPOCHS=1 CLM_PROD_CORPUS=~/work/corpus.txt "$@" \
      timeout 1200 ./clm_prod_gpu 2>&1 | grep 'B6-CE-HIPREC' | tail -1 | grep -oE 'first_ce=[0-9.eE+-]+' | cut -d= -f2
}

echo
echo "############################################################"
echo "### STAGE A — PIN THE RACE: full-fwd determinism ladder  ###"
echo "###   device-EAGER glue, own-GEMM, EPOCHS=1, x3 per knob  ###"
echo "############################################################"
echo "--- FIX OFF (HEXA_DEVGLUE_DETERMINIZE=0) = legacy garbage-tail (reproduce P1B-a' ~7e-6) ---"
for i in 1 2 3; do echo "  off run$i: $(ce1 HEXA_EAGER_DEVRESIDENT=1 HEXA_DEVGLUE_DETERMINIZE=0)"; done
echo "--- FIX ON  (HEXA_DEVGLUE_DETERMINIZE=1, default) = zero-on-alloc racefix ---"
for i in 1 2 3; do echo "  on  run$i: $(ce1 HEXA_EAGER_DEVRESIDENT=1 HEXA_DEVGLUE_DETERMINIZE=1)"; done
echo "--- device-MEGA fp64, FIX ON, x3 (must also be reproducible) ---"
for i in 1 2 3; do echo "  mega run$i: $(ce1 HEXA_CLM_MEGASTEP=1 HEXA_CLM_MEGASTEP_FP64=1 HEXA_DEVGLUE_DETERMINIZE=1)"; done

echo
echo "############################################################"
echo "### STAGE B — CAPSTONE A/B (RACEFIX ON, EPOCHS=$EPO)      ###"
echo "############################################################"
fire(){ # $1=label $2..=extra env
 local lbl=$1; shift
 local u=~/work/util_$lbl.csv t=~/work/train_$lbl.log; : > "$u"
 ( while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0 >>"$u" 2>/dev/null; sleep 0.5; done ) & local sp=$!
 env CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 \
     HEXA_OWN_GEMM=1 HEXA_DEVGLUE_DETERMINIZE=1 \
     CLM_PROD_D=$DCFG CLM_PROD_T=$TCFG CLM_PROD_E=2 CLM_PROD_NSAMP=$NS CLM_PROD_EPOCHS=$EPO \
     CLM_PROD_CORPUS=~/work/corpus.txt "$@" \
     timeout 2400 ./clm_prod_gpu >"$t" 2>&1; local rc=$?; kill $sp 2>/dev/null
 echo "--- $lbl rc=$rc ---"
 python3 -c "u=[int(x) for x in open('$u') if x.strip()];print(f'  util MEAN={sum(u)/len(u):.2f}% PEAK={max(u)}% pct>=20={100*sum(1 for x in u if x>=20)/len(u):.1f}% n={len(u)}')" 2>/dev/null || echo "  (util parse fail)"
 echo "  [EAGER-DEVGLUE-FIRED]=$(grep -c 'EAGER-DEVGLUE-FIRED' "$t")  [MEGAFWD-FIRED]=$(grep -c 'MEGAFWD-FIRED' "$t")  [OWN-GEMM-FIRED]=$(grep -c 'OWN-GEMM-FIRED' "$t")"
 echo "  $(grep 'B6-CE-HIPREC' "$t" | tail -1)"
 echo "  DESCENT=$(grep -E 'F-CLM-PROD-DESCENT' "$t" | tail -1)"
}
echo "=== A = device-EAGER (HEXA_EAGER_DEVRESIDENT=1, racefix ON) ==="
fire eager HEXA_EAGER_DEVRESIDENT=1
echo "=== B = device-MEGA (HEXA_CLM_MEGASTEP=1 FP64, racefix ON) ==="
fire mega HEXA_CLM_MEGASTEP=1 HEXA_CLM_MEGASTEP_FP64=1

echo "=== byte-eq diff (verbatim 17-digit CE) ==="
grep 'B6-CE-HIPREC' train_eager.log | tail -1
grep 'B6-CE-HIPREC' train_mega.log  | tail -1
python3 - <<'PY'
import re
def ce(f):
    s=open(f).read(); m=re.search(r'first_ce=([0-9.eE+-]+).*?last_ce=([0-9.eE+-]+)', s.split('B6-CE-HIPREC')[-1])
    return (float(m.group(1)),float(m.group(2))) if m else (None,None)
a=ce('train_eager.log'); b=ce('train_mega.log')
print("A device-eager first/last:", a); print("B device-mega first/last:", b)
if None not in a+b:
    print(f"max|Δ first_ce| = {abs(a[0]-b[0]):.6e}")
    print(f"max|Δ last_ce|  = {abs(a[1]-b[1]):.6e}")
    print("BYTE-EQ MEGAKERNEL ACHIEVED (max|Δ|=0)" if abs(a[0]-b[0])==0.0 else f"RESIDUAL = {abs(a[0]-b[0]):.6e} (report which op / erf floor)")
PY
echo "=== DONE ==="
