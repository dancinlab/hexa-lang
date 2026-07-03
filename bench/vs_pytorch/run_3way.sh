#!/usr/bin/env bash
# run_3way.sh — HEXA-FUSION vs-PyTorch+CUDA wall bench, 3-way on a real H100/H200.
# Runs the SAME CLMConvMoE shape under (1) flame hexa device-resident trainer,
# (2) torch eager, (3) torch.compile, sampling nvidia-smi util for each, and
# prints a verbatim step/s + util table.
#
# Prereqs on pod:
#   - flame binary built via fusion_build_sources.tgz recipe -> $WORK/clm_prod_gpu
#   - python3 + torch (CUDA) installed
#   - bench/vs_pytorch/clmconvmoe_torch.py copied to $WORK
#
# Env (model shape — kept identical across all 3 runners):
#   D=1536 T=512 E=2 K=3 V=256  (production-proxy shape)
#   STEPS=40 WARMUP=8 BATCH=1
set -o pipefail
WORK="${WORK:-$HOME/work}"
D="${D:-1536}"; T="${T:-512}"; E="${E:-2}"; K="${K:-3}"; V="${V:-256}"
STEPS="${STEPS:-40}"; WARMUP="${WARMUP:-8}"; BATCH="${BATCH:-1}"
TORCH_DTYPE="${TORCH_DTYPE:-tf32}"   # torch matmul precision (honest: flame=FP32/TF32 own-GEMM)
cd "$WORK" || exit 1

echo "================ HEXA-FUSION vs-PyTorch 3-way wall bench ================"
echo "host: $(hostname)  $(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader | head -1)"
echo "shape: D=$D T=$T E=$E K=$K V=$V  | STEPS=$STEPS WARMUP=$WARMUP BATCH=$BATCH  torch_dtype=$TORCH_DTYPE"
echo "nvcc: $(nvcc --version 2>/dev/null | grep release)"
echo

# util sampler: background nvidia-smi @100ms -> file; summarized in python afterwards
sample_util() {  # $1 = tag, $2 = command... runs cmd while sampling util
  local tag="$1"; shift
  local uf="util_${tag}.csv"
  : > "$uf"
  ( while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits >> "$uf" 2>/dev/null; sleep 0.1; done ) &
  local sp=$!
  echo "---- [$tag] running ----"
  "$@"
  local rc=$?
  kill "$sp" 2>/dev/null; wait "$sp" 2>/dev/null
  # summarize util
  python3 - "$uf" "$tag" <<'PY'
import sys
vals=[]
try:
  for ln in open(sys.argv[1]):
    ln=ln.strip()
    if ln.isdigit(): vals.append(int(ln))
except Exception: pass
tag=sys.argv[2]
if not vals:
  print(f"[UTIL-{tag}] n=0 (no samples)"); sys.exit()
vals.sort(); n=len(vals)
mean=sum(vals)/n; med=vals[n//2]; pk=vals[-1]; ge20=100.0*sum(1 for v in vals if v>=20)/n
print(f"[UTIL-{tag}] n={n} mean={mean:.2f}% median={med}% peak={pk}% pct>=20={ge20:.1f}%")
PY
  return $rc
}

# ---------------- (1) FLAME hexa device-resident trainer ----------------
# step/s measured externally: time a run with known step count.
# steps = nbatch * epochs; we set NSAMP/EPOCHS so steps ~= STEPS and time the wall.
# Flame's clm_prod prints "[M5-BATCH] ... steps=N" — we parse it for exact count.
flame_run() {
  # async follows CLM_PROD_DEVRESIDENT=1 (production fast path, +9% win r5: 159->143ms).
  # HEXA_CUDA_ASYNC=0 was a historical race-cure (#3932, now fixed) that masked the measured win.
  # async-ON is also MORE deterministic (F-OP15 max|dW|=0 vs async-OFF 1-ULP hole 2.78e-17).
  CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 \
    CLM_PROD_D=$D CLM_PROD_T=$T CLM_PROD_E=$E CLM_PROD_BATCH=$BATCH \
    CLM_PROD_NSAMP=$FLAME_NSAMP CLM_PROD_EPOCHS=$FLAME_EPOCHS \
    CLM_PROD_CORPUS="$WORK/corpus.txt" \
    ./clm_prod_gpu 2>&1 | tee flame_out.txt
}
# pick NSAMP/EPOCHS so that the timed window holds ~STEPS steps. nbatch = floor(nwin/B);
# nwin grows with NSAMP. Use NSAMP so nbatch*EPOCHS ~= STEPS+WARMUP, then derive
# step/s from the M5-BATCH steps count and the measured wall.
FLAME_NSAMP="${FLAME_NSAMP:-$(( (STEPS+WARMUP) * BATCH + 4 ))}"
FLAME_EPOCHS="${FLAME_EPOCHS:-1}"
echo "[flame] NSAMP=$FLAME_NSAMP EPOCHS=$FLAME_EPOCHS (targeting ~$((STEPS+WARMUP)) steps)"
FLAME_T0=$(date +%s.%N)
sample_util flame flame_run
FLAME_T1=$(date +%s.%N)
FLAME_WALL=$(python3 -c "print(f'{$FLAME_T1-$FLAME_T0:.3f}')")
FLAME_STEPS=$(grep -oE 'steps=[0-9]+' flame_out.txt | tail -1 | cut -d= -f2)
FLAME_STEPS="${FLAME_STEPS:-0}"
FLAME_SPS=$(python3 -c "w=$FLAME_WALL; s=$FLAME_STEPS; print(f'{(s/w) if w>0 and s>0 else 0:.3f}')")
echo "[FLAME] wall=${FLAME_WALL}s steps=${FLAME_STEPS} step/s=${FLAME_SPS} (incl. corpus load + warmup — see note)"
echo

# ---------------- (2) torch eager ----------------
sample_util torch_eager python3 clmconvmoe_torch.py --d $D --t $T --e $E --k $K --v $V \
  --batch $BATCH --steps $STEPS --warmup $WARMUP --dtype $TORCH_DTYPE --mode eager | tee torch_eager_out.txt
echo

# ---------------- (3) torch.compile ----------------
sample_util torch_compile python3 clmconvmoe_torch.py --d $D --t $T --e $E --k $K --v $V \
  --batch $BATCH --steps $STEPS --warmup $WARMUP --dtype $TORCH_DTYPE --mode compile | tee torch_compile_out.txt
echo
echo "================ 3-way summary (grep the [FLAME]/[TORCH-*]/[UTIL-*] lines above) ================"
grep -hE '^\[FLAME\]|^\[TORCH-|^\[UTIL-' flame_out.txt torch_eager_out.txt torch_compile_out.txt 2>/dev/null
echo "(step/s + util printed inline per runner above)"
