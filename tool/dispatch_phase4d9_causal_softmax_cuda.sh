#!/bin/bash
# tool/dispatch_phase4d7_oracle_cuda.sh — flame d768 GPU-path byte-eq
# ORACLE, cheap A100 dispatch ($-cents gate).
#
# WHY THIS EXISTS
#   The d768 GPU-resident path had no byte-eq oracle — the RFC 058
#   regression was caught only at the 13th paid d768 fire (gn2
#   3.99026 → 3.98438 → -nan), and fires #13/#14 spent two more PAID
#   fires just diagnosing it because gn2 is an integrated end-to-end
#   number that cannot LOCALISE a GPU-path regression. tool/flame_
#   phase4d7_gpu_path_oracle.{c,sh} fixed the localisation gap (config
#   d=96·T16, M·K=9216 > the 8192 GPU dim-gate → byte-for-byte the SAME
#   GPU-path code as d768, but with a CPU reference computable in
#   sub-second). The no-CUDA self-check + the --cuda syntactic check
#   both PASS at $0 on Mac. The ONE pending step was the --cuda NUMERIC
#   run, which genuinely needs a GPU host. This script is that run.
#
#   This is the CHEAP gate that REPLACES a 600 s / ~10 GB d768 fire as
#   the verification mechanism for every GPU-path change. The oracle's
#   compute is sub-second; the cost is purely the (shared) pod-provision
#   + nvcc-compile-runtime_cuda.c overhead — and unlike a d768 fire it
#   returns a clean, LOCALISED max|Δ| verdict vs a verified CPU
#   reference at a config where that reference is computable.
#
# UPLOAD SET (vs the heavy d768 dispatch_phase4d7_gpu_fire.sh)
#   The d9 causal-softmax oracle is a SINGLE translation unit and needs
#   NO splice (unlike the d7 gpu-path oracle): the .c calls the
#   runtime_cuda.c wrapper directly. NO runtime.c, NO 17 native/*.c, NO
#   corpus blob, NO matmul_primitives.c — just 3 files:
#     tool/flame_phase4d9_causal_softmax_oracle.c
#     tool/flame_phase4d9_causal_softmax_oracle.sh
#     self/cuda/runtime_cuda.c        (the verified substrate kernels)
#
# VERDICT
#   PASS  F-RFC058-GPU-PATH-ORACLE  max|Δ| ≤ 3e-11  → GPU-path byte-safe
#   FAIL  ...                       max|Δ| > 3e-11  → GPU-path REGRESSION
#   any NaN/Inf                                     → -nan signature FAIL
#
# Falsifier:
#   F-PHASE4D9-CAUSAL-SOFTMAX-CUDA  the d768 GPU-path projection
#       (cuBLAS Dgemm + transpose-scatter) is max|Δ| ≤ TOL_OP vs the
#       verified CPU reference at the GPU-gated config.
#
# Adapted from tool/dispatch_phase4d7_gpu_fire.sh (same robust watchdog:
# A100-only filter, SAVE_POD on partial pull, scp retry, trap cleanup).
#
# Budget: ~$0.20 expected (A100 ~$0.20/hr × provision+nvcc ~10-15min).
#         User pre-approved all GPU fires for this campaign.

set -uo pipefail

PHASE_ID="flame_phase4d9_causal_softmax_cuda_2026_05_18"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${REPO_ROOT}/state/${PHASE_ID}"

ORACLE_C="${REPO_ROOT}/tool/flame_phase4d9_causal_softmax_oracle.c"
ORACLE_SH="${REPO_ROOT}/tool/flame_phase4d9_causal_softmax_oracle.sh"
RUNTIME_CUDA_C="${REPO_ROOT}/self/cuda/runtime_cuda.c"

PHASE_LABEL="flame-phase4d9-csoftmax-cuda"
REMOTE_WORK="/workspace/flame_csoftmax"

VAST_SSH_KEY="/Users/ghost/.vast/ssh/vast-key"
VASTAI="/Users/ghost/Library/Python/3.14/bin/vastai"

# Oracle compute is sub-second; this cap only guards a hung build/run.
RUN_BUDGET_SEC=120

# Pre-flight
[ -x "$VASTAI" ]          || { echo "ERROR: vastai CLI not found at $VASTAI"; exit 1; }
[ -f "$VAST_SSH_KEY" ]    || { echo "ERROR: vast ssh key missing at $VAST_SSH_KEY"; exit 1; }
[ -f "$ORACLE_C" ]        || { echo "ERROR: $ORACLE_C missing"; exit 1; }
[ -f "$ORACLE_SH" ]       || { echo "ERROR: $ORACLE_SH missing"; exit 1; }
[ -f "$RUNTIME_CUDA_C" ]  || { echo "ERROR: $RUNTIME_CUDA_C missing"; exit 1; }

mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR"
echo "=== ${PHASE_ID} vast.ai dispatch ($(date -u +%Y-%m-%d)) ==="
date -u
echo "REPO_ROOT: $REPO_ROOT"
echo "LOCAL_DIR: $LOCAL_DIR"
echo ""

# ── 1) Search cheapest A100 (same filter as the d768 fire dispatch) ───
echo "[1/9] Searching A100 offers (≤\$3/hr, cuda≥12.4, disk≥30) ..."
OFFER_JSON=$($VASTAI search offers \
    'gpu_name in [A100,A100_SXM4,A100_PCIE,A100X] num_gpus=1 rentable=true dph_total<3.0 cuda_max_good>=12.4 disk_space>30 reliability>0.985 inet_down>200' \
    -o 'reliability-' --raw 2>&1)
OFFER_PARSED=$(echo "$OFFER_JSON" | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except: sys.stderr.write('parse_err\n'); sys.exit(1)
if not d: sys.stderr.write('no_offers\n'); sys.exit(1)
b = d[0]
print('%s %.4f %s %s' % (b['id'], b['dph_total'], b['gpu_name'].replace(' ','_'), b.get('cuda_max_good','?')))
")
OFFER_ID=$(echo "$OFFER_PARSED" | awk '{print $1}')
OFFER_DPH=$(echo "$OFFER_PARSED" | awk '{print $2}')
OFFER_GPU=$(echo "$OFFER_PARSED" | awk '{print $3}')
OFFER_CUDA=$(echo "$OFFER_PARSED" | awk '{print $4}')
[ -z "$OFFER_ID" ] && { echo "ERROR: no offer parsed"; exit 1; }
echo "  Selected: id=$OFFER_ID dph=\$$OFFER_DPH gpu=$OFFER_GPU cuda=$OFFER_CUDA"
echo "$OFFER_ID" > offer_id.txt
echo "$OFFER_GPU" > offer_gpu.txt
echo "$OFFER_DPH" > offer_dph.txt

# ── 2) Rent ──────────────────────────────────────────────────────────
echo "[2/9] Renting instance (cuda:12.4 devel image) ..."
CREATE_OUT=$($VASTAI create instance "$OFFER_ID" \
    --image nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 \
    --disk 30 --ssh --direct --label "$PHASE_LABEL" --raw 2>&1)
INSTANCE_ID=$(echo "$CREATE_OUT" | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except: sys.stderr.write('parse_fail: '+sys.stdin.read()+'\n'); sys.exit(1)
print(d.get('new_contract', d.get('contract_id', d.get('id',''))))
")
[ -z "$INSTANCE_ID" ] && { echo "ERROR: instance id parse failed: $CREATE_OUT"; exit 1; }
echo "  Instance ID: $INSTANCE_ID"
echo "$INSTANCE_ID" > vast_instance_id.txt

cleanup() {
    local rc=$?
    if [ "${SAVE_POD:-0}" = "1" ]; then
        echo "[cleanup] SAVE_POD=1 — keep instance $INSTANCE_ID (rc=$rc)"
        echo "[cleanup] manual destroy: $VASTAI destroy instance $INSTANCE_ID"
    else
        echo "[cleanup] Destroying instance $INSTANCE_ID (exit=$rc)..."
        $VASTAI destroy instance "$INSTANCE_ID" 2>&1 | head -3 || true
    fi
}
trap cleanup EXIT INT TERM

# ── 3) Wait for SSH ───────────────────────────────────────────────────
echo "[3/9] Waiting for SSH (max 13 min)..."
SSH_HOST=""; SSH_PORT=""
for i in $(seq 1 160); do
    INFO=$($VASTAI show instance "$INSTANCE_ID" --raw 2>/dev/null || true)
    [ -z "$INFO" ] && INFO="{}"
    STATUS=$(echo "$INFO" | python3 -c "import json,sys
try: d=json.load(sys.stdin); print(d.get('actual_status',''))
except: print('parse_err')" 2>/dev/null || echo "")
    if [ "$STATUS" = "running" ]; then
        SSH_HOST=$(echo "$INFO" | python3 -c "import json,sys
try: d=json.load(sys.stdin); print(d.get('public_ipaddr','') or d.get('ssh_host',''))
except: pass" 2>/dev/null || echo "")
        SSH_PORT=$(echo "$INFO" | python3 -c "import json,sys
try:
 d=json.load(sys.stdin); ports=d.get('ports',{}) or {}
 m=ports.get('22/tcp')
 print(m[0]['HostPort'] if m else (d.get('direct_port_start','') or d.get('ssh_port','')))
except: pass" 2>/dev/null || echo "")
        if [ -n "$SSH_HOST" ] && [ -n "$SSH_PORT" ]; then
            if ssh -i "$VAST_SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                -o ConnectTimeout=10 -p "$SSH_PORT" "root@$SSH_HOST" 'echo READY' 2>&1 | grep -q READY; then
                echo "  SSH ready: $SSH_HOST:$SSH_PORT (after ${i}x5s)"
                break
            fi
            SSH_HOST=""
        fi
    fi
    echo "  ... attempt $i/160 status=$STATUS"
    sleep 5
done
[ -z "$SSH_HOST" ] && { echo "ERROR: SSH not ready"; SAVE_POD=1; exit 1; }
echo "$SSH_HOST:$SSH_PORT" > vast_ssh.txt
SSH_OPTS="-i $VAST_SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60"
SSH_CMD="ssh $SSH_OPTS -p $SSH_PORT root@$SSH_HOST"
SCP_CMD="scp $SSH_OPTS -P $SSH_PORT -o ConnectTimeout=3600"

# ── 4) Toolchain sanity ───────────────────────────────────────────────
echo "[4/9] Remote toolchain sanity ..."
$SSH_CMD "set +e
  nvidia-smi --query-gpu=name,compute_cap,memory.total,driver_version --format=csv,noheader
  echo '---'
  nvcc --version | head -5
  echo '---'
  which clang || (apt update >/dev/null 2>&1 && apt install -y clang >/dev/null 2>&1 && which clang)
  clang --version | head -2
  echo '---'
  ls /usr/local/cuda/include/cublas_v2.h && echo 'cublas_v2.h PRESENT'
  ls /usr/local/cuda/lib64/libcublas.so* 2>/dev/null | head -3
  mkdir -p $REMOTE_WORK/tool
  mkdir -p $REMOTE_WORK/self/cuda
  mkdir -p $REMOTE_WORK/build/artifacts
  echo 'TOOLCHAIN_OK'" 2>&1 | tee remote_sanity.log

# ── 5) Upload the 4 oracle files (no runtime.c, no native, no corpus) ─
echo "[5/9] Upload oracle.{c,sh} + runtime_cuda.c ..."
$SCP_CMD "$ORACLE_C"       "root@$SSH_HOST:$REMOTE_WORK/tool/flame_phase4d9_causal_softmax_oracle.c"
$SCP_CMD "$ORACLE_SH"      "root@$SSH_HOST:$REMOTE_WORK/tool/flame_phase4d9_causal_softmax_oracle.sh"
$SCP_CMD "$RUNTIME_CUDA_C" "root@$SSH_HOST:$REMOTE_WORK/self/cuda/runtime_cuda.c"

# ── 6) Splice + nvcc-build + run the oracle (--cuda) ─────────────────
echo "[6/9] Build + run oracle --cuda on GPU host ..."
$SSH_CMD "cd $REMOTE_WORK && \
    chmod +x tool/flame_phase4d9_causal_softmax_oracle.sh ; \
    echo '=== nvidia-smi PRE ===' ; \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_pre.csv ; \
    cat nvidia_smi_pre.csv ; \
    echo '=== ORACLE --cuda (splice + nvcc + run) ===' ; \
    rm -f oracle.done oracle.out ; \
    nohup bash -c 'S=\$(date +%s); timeout ${RUN_BUDGET_SEC} bash tool/flame_phase4d9_causal_softmax_oracle.sh --cuda > oracle.out 2>&1; R=\$?; E=\$(date +%s); echo oracle_rc=\$R > oracle_meta.txt; echo wall_seconds=\$((E-S)) >> oracle_meta.txt; touch oracle.done' >/dev/null 2>&1 & disown ; \
    sleep 3 ; \
    echo 'oracle launched detached'" 2>&1 | tee dispatch.log

# ── 6.5) Poll until oracle.done ───────────────────────────────────────
echo "[6.5/9] Poll detached oracle until done (max $((RUN_BUDGET_SEC + 240))s) ..."
POLL_DEADLINE=$(( $(date +%s) + RUN_BUDGET_SEC + 240 ))
POLL_SSH="ssh -i $VAST_SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -p $SSH_PORT root@$SSH_HOST"
while [ "$(date +%s)" -lt "$POLL_DEADLINE" ]; do
    DONE=$($POLL_SSH "cd $REMOTE_WORK && ( [ -f oracle.done ] && echo Y )" 2>/dev/null | tail -1)
    if [ "$DONE" = "Y" ]; then echo "  oracle.done detected"; break; fi
    LAST=$($POLL_SSH "cd $REMOTE_WORK && tail -1 oracle.out 2>/dev/null" 2>/dev/null | tail -1)
    echo "  ... polling ($(( (POLL_DEADLINE - $(date +%s)) ))s left) last: ${LAST:-<no output yet>}"
    sleep 15
done
$POLL_SSH "cd $REMOTE_WORK && nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_post.csv; echo '=== meta ==='; cat oracle_meta.txt 2>/dev/null; echo '=== oracle.out ==='; cat oracle.out 2>/dev/null" 2>&1 | tee -a dispatch.log

# ── 7) Pull artifacts with retry ──────────────────────────────────────
echo "[7/9] Pull artifacts ..."
SAVE_POD=1
pull_with_retry() {
    local src="$1" dst="$2" tries=0
    while [ $tries -lt 3 ]; do
        if $SCP_CMD "root@$SSH_HOST:$src" "$dst" 2>&1; then
            echo "  pulled $src (try $((tries+1)))"; return 0
        fi
        tries=$((tries+1)); echo "  ... pull retry $tries/3 for $src"
        [ $tries -lt 3 ] && sleep 15
    done
    echo "  pull FAILED after 3 tries: $src"; return 1
}
PULL_OK=1
pull_with_retry "$REMOTE_WORK/oracle.out"        "$LOCAL_DIR/oracle.out"        || PULL_OK=0
pull_with_retry "$REMOTE_WORK/oracle_meta.txt"   "$LOCAL_DIR/oracle_meta.txt"   || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_pre.csv"  "$LOCAL_DIR/nvidia_smi_pre.csv"  || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_post.csv" "$LOCAL_DIR/nvidia_smi_post.csv" || true

# ── 8) Destroy on full pull, retain on partial ────────────────────────
echo "[8/9] Pod lifecycle ..."
if [ $PULL_OK -eq 1 ]; then
    echo "  Core artifacts pulled — destroying instance now"
    $VASTAI destroy instance "$INSTANCE_ID" 2>&1 | head -3 || true
    SAVE_POD=0
else
    echo "  [WARN] partial pull — pod RETAINED for manual recovery"
    echo "  manual SSH: ssh -i $VAST_SSH_KEY -p $SSH_PORT root@$SSH_HOST"
    echo "  manual destroy: $VASTAI destroy instance $INSTANCE_ID"
fi

# ── 9) Summary + verdict ──────────────────────────────────────────────
echo "[9/9] === ${PHASE_ID} DONE ==="
date -u
echo "GPU: $OFFER_GPU  Rate: \$${OFFER_DPH}/hr"
echo ""
if [ -f "$LOCAL_DIR/oracle_meta.txt" ]; then
    echo "--- ORACLE META ---"
    cat "$LOCAL_DIR/oracle_meta.txt"
fi
echo ""
if [ -f "$LOCAL_DIR/oracle.out" ]; then
    echo "--- oracle.out ---"
    cat "$LOCAL_DIR/oracle.out"
    echo ""
    echo "--- VERDICT ---"
    grep -E 'max\|.\| = |PASS  F-RFC|FAIL  F-RFC|-nan|SYNTACTIC' "$LOCAL_DIR/oracle.out" | tail -5 \
        || echo "  (no verdict line — inspect oracle.out)"
fi
echo ""
echo "DONE — artifacts: $LOCAL_DIR/"
