#!/usr/bin/env bash
# Lane G re-fire remote driver — clm_prod d768/12L on c4 backbone 5-lang corpus,
# forge=cuBLAS GPU, with HONEST continuous nvidia-smi util sampling during the
# forge GEMM loop (NOT the single end-of-run sample the dojo run.sh does).
#
# Gates:
#   F-CLM-PROD-DESCENT — mean CE strictly descends (from job.hexa output)
#   util-GREEN         — sampled GPU util during forge cuBLAS GEMMs (peak+mean);
#                        re-checks the F-RFC046 "util 1-4% RED" bottleneck.
#                        Reported HONESTLY — util-GREEN only if genuinely high.
#
# Args: $1 = HF_TOKEN  $2 = CORPUS_DATASET  $3 = D  $4 = LAYERS
set -uo pipefail

HF_TOKEN="${1:?need HF token}"
CORPUS_DATASET="${2:-dancinlab/clm-backbone-5lang-sample}"
DVAL="${3:-768}"
LAYERS="${4:-12}"

export PATH="/usr/local/cuda/bin:$HOME/.hx/bin:$PATH"
export HUGGINGFACE_HUB_TOKEN="$HF_TOKEN"
export HF_TOKEN="$HF_TOKEN"
WORK="/workspace/laneg"
mkdir -p "$WORK"; cd "$WORK"

echo "=== [1/6] nvidia-smi + cuda sanity ==="
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
nvcc --version | grep release || echo "WARN no nvcc on PATH"

echo "=== [2/6] install hexa (linux release) + stdlib clone @ branch ==="
if ! command -v hexa >/dev/null 2>&1; then
  HEXA_BRANCH="feat/laneg-clm-refire2" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)" || {
    echo "install.sh failed; retrying default branch"; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)"; }
fi
export PATH="$HOME/.hx/bin:$PATH"
hexa --version || { echo "FATAL: hexa not installed"; exit 10; }
HEXA_SRC="$(ls -d $HOME/.hx/src 2>/dev/null | head -1)"
echo "HEXA_SRC=$HEXA_SRC"

echo "=== [3/6] python deps + pull c4 backbone corpus ==="
python3 -m pip install -q --upgrade huggingface_hub 2>&1 | tail -2 || true
python3 - "$CORPUS_DATASET" "$WORK/corpus.txt" "$HF_TOKEN" <<'PY'
import sys, os, glob
ds_id, out_path, tok = sys.argv[1], sys.argv[2], sys.argv[3]
from huggingface_hub import snapshot_download
root = snapshot_download(repo_id=ds_id, repo_type="dataset", token=tok)
print("snapshot:", root)
lines=[]
for fp in sorted(glob.glob(os.path.join(root,"**","*.limen"),recursive=True)):
    with open(fp,"rb") as fh:
        for raw in fh.read().split(b"\n"):
            t=raw.decode("utf-8","replace").strip()
            if t: lines.append(t)
if not lines:
    for pat in ("*.txt","*.jsonl","*.json"):
        for fp in sorted(glob.glob(os.path.join(root,"**",pat),recursive=True)):
            try:
                with open(fp,"r",encoding="utf-8",errors="replace") as fh:
                    for ln in fh:
                        ln=ln.strip()
                        if ln: lines.append(ln)
            except Exception as e:
                print("skip",fp,e)
if not lines: sys.exit("no payload found under "+root)
with open(out_path,"w",encoding="utf-8") as fh:
    fh.write("\n".join(lines)+"\n")
print("wrote",len(lines),"records ->",out_path, os.path.getsize(out_path),"bytes")
PY
[ -s "$WORK/corpus.txt" ] || { echo "FATAL: empty corpus"; exit 11; }

echo "=== [4/6] scaffold dojo clm job (d=$DVAL layers=$LAYERS) ==="
cd "$HEXA_SRC" 2>/dev/null || cd "$WORK"
SPEC="{\"d\":\"$DVAL\",\"layers\":\"$LAYERS\",\"T\":\"24\",\"experts\":\"2\",\"kosmos_dataset\":\"$CORPUS_DATASET\"}"
JOBDIR="$WORK/job"
mkdir -p "$JOBDIR"
# Try the dojo generator; if unavailable, fall back to running clm_prod.hexa directly.
if hexa dojo clm laneg-refire "$SPEC" --out "$JOBDIR" 2>"$WORK/dojo.err" || \
   hexa dojo clm laneg-refire "$SPEC" 2>>"$WORK/dojo.err"; then
  echo "dojo clm scaffolded"; ls -la "$JOBDIR" 2>/dev/null
fi
# Locate a runnable driver: prefer scaffolded job.hexa, else clm_prod.hexa.
DRIVER=""
if [ -f "$JOBDIR/job.hexa" ]; then DRIVER="$JOBDIR/job.hexa"
elif [ -f "$HEXA_SRC/stdlib/flame/clm_prod.hexa" ]; then DRIVER="$HEXA_SRC/stdlib/flame/clm_prod.hexa"
elif [ -f "$WORK/clm_prod.hexa" ]; then DRIVER="$WORK/clm_prod.hexa"
fi
echo "DRIVER=$DRIVER"
[ -n "$DRIVER" ] || { echo "FATAL: no driver"; cat "$WORK/dojo.err" 2>/dev/null; exit 12; }

echo "=== [5/6] run hexa (forge=cuBLAS) with CONTINUOUS util sampling ==="
export CLM_PROD_CORPUS="$WORK/corpus.txt"
echo "CLM_PROD_CORPUS=$CLM_PROD_CORPUS ($(wc -c < "$CLM_PROD_CORPUS") bytes)"
# continuous util sampler: 0.2s cadence, util + sm clk, while the run is alive
UTIL_CSV="$WORK/util.csv"
: > "$UTIL_CSV"
( while :; do nvidia-smi --query-gpu=utilization.gpu,utilization.memory,power.draw,clocks.sm --format=csv,noheader,nounits >> "$UTIL_CSV" 2>/dev/null; sleep 0.2; done ) &
SAMPLER=$!
RUN_LOG="$WORK/train.log"
cd "$(dirname "$DRIVER")"
( export HEXA_LANG="$HEXA_SRC"; hexa run "$DRIVER" ) 2>&1 | tee "$RUN_LOG"
RUN_RC=${PIPESTATUS[0]}
kill "$SAMPLER" 2>/dev/null; wait "$SAMPLER" 2>/dev/null

echo "=== [6/6] gate eval ==="
echo "--- F-CLM-PROD-DESCENT ---"
grep -E "mean CE|F-CLM-PROD-DESCENT|PASS|FAIL" "$RUN_LOG" || true
echo "--- util samples (n=$(wc -l < "$UTIL_CSV")) ---"
# peak + mean of column 1 (gpu util %), ignore idle-only if run was tiny
awk -F',' 'NF>=1{u=$1+0; n++; s+=u; if(u>mx)mx=u} END{ if(n>0) printf "UTIL_SAMPLES=%d PEAK=%d%% MEAN=%.2f%%\n", n, mx, s/n; else print "UTIL_SAMPLES=0" }' "$UTIL_CSV"
echo "--- top-10 highest util samples ---"
sort -t',' -k1 -n -r "$UTIL_CSV" | head -10
echo "RUN_RC=$RUN_RC"
echo "=== DONE ==="
