#!/usr/bin/env bash
# profile_dutycycle.sh — FF-DUTYCYCLE: profile ONE flame CLMConvMoE FP64 train step into time buckets.
#
# Shape = the #2913/#2915 config: D1536 / Tw512 / E2 / K3, FP64, batch=1.
# Buckets (from nsys per-kernel CUDA-GPU-trace, mapped by kernel name):
#   (a) GEMM%        : gemm/dgemm/sgemm/wgmma/matmul/_hx_k_gemm  (high-util cuBLAS/own-GEMM)
#   (b) GLUE%        : groupnorm/gelu/conv/expert/elementwise/im2col/col2im/token/pack/add/bias/softmax/ce
#   (c) OPTIMIZER%   : adam/adamw/optim/moment/update
#   (d) GAP/idle%    : step_wall - sum(kernel_active_on_device)  (device truly idle = dispatch latency)
# valley_fraction = (glue + optim + idle) / step_wall ; Amdahl ceiling = 1/(1-valley).
#
# Also: concurrent nvidia-smi util sampling (mean / median / peak) to confirm the bimodal {100%,0%} shape.
set -uo pipefail
WORK="${WORK:-$HOME/work}"
D="${D:-1536}"; TW="${TW:-512}"; E="${E:-2}"; K="${K:-3}"
B="${B:-1}"
# enough warm steps that a clean middle window of timed kernels dominates the trace
NSAMP="${NSAMP:-12}"; EPOCHS="${EPOCHS:-1}"
PREC="${PREC:-fp64}"
cd "$WORK" || exit 1

echo "================ FF-DUTYCYCLE profile ================"
nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap --format=csv,noheader -i 0
echo "shape: D=$D Tw=$TW E=$E K=$K B=$B PREC=$PREC NSAMP=$NSAMP EPOCHS=$EPOCHS"
nsys --version 2>/dev/null | head -1; ncu --version 2>/dev/null | head -2 | tail -1
echo

run_env() {
  CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 \
    HEXA_CUDA_ASYNC=0 HEXA_GEMM_PREC=$PREC \
    CLM_PROD_D=$D CLM_PROD_T=$TW CLM_PROD_E=$E CLM_PROD_BATCH=$B \
    CLM_PROD_NSAMP=$NSAMP CLM_PROD_EPOCHS=$EPOCHS \
    CLM_PROD_CORPUS="$WORK/corpus.txt"
}

# ---- 0. plain timed run + concurrent util sampling (mean/median/peak, the bimodal shape) ----
echo "=== [0] plain run: step/s + util mean/median/peak (nvidia-smi @5Hz) ==="
UF=util_dutycycle.csv; : > "$UF"
( while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i 0 >> "$UF" 2>/dev/null; sleep 0.2; done ) & SP=$!
T0=$(date +%s.%N)
env $(run_env >/dev/null 2>&1; :) bash -c 'env' >/dev/null 2>&1 || true
# actual run (env applied via subshell)
( eval "$(run_env | sed 's/^/export /')" 2>/dev/null; CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 HEXA_CUDA_ASYNC=0 HEXA_GEMM_PREC=$PREC CLM_PROD_D=$D CLM_PROD_T=$TW CLM_PROD_E=$E CLM_PROD_BATCH=$B CLM_PROD_NSAMP=$NSAMP CLM_PROD_EPOCHS=$EPOCHS CLM_PROD_CORPUS="$WORK/corpus.txt" timeout 1200 ./clm_prod_gpu ) > plain_run.txt 2>&1
T1=$(date +%s.%N)
kill "$SP" 2>/dev/null
WALL=$(python3 -c "print(f'{$T1-$T0:.3f}')")
python3 - "$UF" "$WALL" "$NSAMP" <<'PY'
import sys,statistics as st
uf,wall,nsamp=sys.argv[1],float(sys.argv[2]),int(sys.argv[3])
v=[int(x) for x in open(uf) if x.strip().isdigit()]
if v:
    print(f"  util  mean={sum(v)/len(v):.2f}%  median={st.median(v)}%  peak={max(v)}%  n={len(v)}  pct>=70={100*sum(1 for x in v if x>=70)/len(v):.1f}%")
print(f"  wall(total incl init)={wall:.3f}s  nsamp={nsamp}")
PY
echo "  --- plain_run.txt CE tail ---"; grep -iE 'epoch-|mean CE|step' plain_run.txt | tail -6

# ---- 1. nsys profile: per-kernel CUDA GPU trace ----
echo
echo "=== [1] nsys profile (CUDA trace) ==="
rm -f dutycycle.nsys-rep dutycycle.sqlite
( eval "$(run_env | sed 's/^/export /')" 2>/dev/null; \
  CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 HEXA_CUDA_ASYNC=0 HEXA_GEMM_PREC=$PREC CLM_PROD_D=$D CLM_PROD_T=$TW CLM_PROD_E=$E CLM_PROD_BATCH=$B CLM_PROD_NSAMP=$NSAMP CLM_PROD_EPOCHS=$EPOCHS CLM_PROD_CORPUS="$WORK/corpus.txt" \
  nsys profile --trace=cuda --sample=none --cpuctxsw=none --force-overwrite=true -o dutycycle ./clm_prod_gpu ) > nsys_stdout.txt 2>&1 || { echo "NSYS RUN warn (tail):"; tail -15 nsys_stdout.txt; }

echo "  --- nsys gpukernsum (per-kernel time) ---"
nsys stats --report cuda_gpu_kern_sum --format table dutycycle.nsys-rep 2>/dev/null | tee nsys_kernsum.txt | head -60
echo "  --- nsys gpu trace summary (gaps via cuda_gpu_trace) ---"
nsys stats --report cuda_gpu_trace --format csv dutycycle.nsys-rep 2>/dev/null > nsys_gputrace.csv
wc -l nsys_gputrace.csv

echo
echo "=== [2] bucket the kernels -> valley_fraction + Amdahl ceiling ==="
python3 bucket_nsys.py nsys_gputrace.csv nsys_kernsum.txt | tee bucket_report.txt

# ---- 3. ncu: SM throughput on a single representative step (mean SM util) ----
echo
echo "=== [3] ncu sm__throughput (a slice of kernels) ==="
( eval "$(run_env | sed 's/^/export /')" 2>/dev/null; \
  CUDA_VISIBLE_DEVICES=0 CLM_PROD_DEVRESIDENT=1 CLM_PROD_DEVFEED=1 CLM_PROD_BATCHED=1 HEXA_CUDA_ASYNC=0 HEXA_GEMM_PREC=$PREC CLM_PROD_D=$D CLM_PROD_T=$TW CLM_PROD_E=$E CLM_PROD_BATCH=$B CLM_PROD_NSAMP=4 CLM_PROD_EPOCHS=1 CLM_PROD_CORPUS="$WORK/corpus.txt" \
  ncu --launch-skip 40 --launch-count 60 --metrics sm__throughput.avg.pct_of_peak_sustained_elapsed,gpu__time_duration.sum --csv ./clm_prod_gpu ) > ncu_raw.csv 2>ncu_err.txt || { echo "NCU warn (tail):"; tail -10 ncu_err.txt; }
python3 - <<'PY'
import csv,statistics as st
rows=[]
try:
    with open('ncu_raw.csv') as f:
        rdr=csv.DictReader(line for line in f if line and not line.startswith('==') )
        for r in rdr: rows.append(r)
except Exception as e:
    print("  ncu parse warn:",e)
# find the sm throughput column
sm=[]
for r in rows:
    for k,v in r.items():
        if k and 'sm__throughput' in k:
            try: sm.append(float(v.replace(',','')))
            except: pass
if sm:
    print(f"  ncu sm__throughput.avg %peak  over {len(sm)} kernels: mean={sum(sm)/len(sm):.2f}  median={st.median(sm):.2f}  max={max(sm):.2f}  min={min(sm):.2f}")
    print(f"  kernels with sm%>=70: {sum(1 for x in sm if x>=70)}/{len(sm)}  | sm%<5 (valley kernels): {sum(1 for x in sm if x<5)}/{len(sm)}")
else:
    print("  ncu: no sm__throughput rows parsed (see ncu_err.txt)")
PY
echo "================ FF-DUTYCYCLE profile complete ================"
