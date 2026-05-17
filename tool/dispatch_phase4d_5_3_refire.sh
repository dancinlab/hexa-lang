#!/bin/bash
# tool/dispatch_phase4d_5_3_refire.sh — REDUCTION-ONLY refire after dup
# `_d2h_out` + unterminated `#ifdef HEXA_CUDA` fixes in runtime_cuda.c.
#
# First fire (dispatch_phase4d_5_3.sh @ 2026-05-17 ~06:33Z) outcome:
#   ELEMENTWISE: 5/5 PASS on A100 PCIE sm_80 (4 bit-exact + 2 SILU under 4e-15)
#   REDUCTION:   BUILD FAILED — unterminated #ifdef HEXA_CUDA (line 944)
#                and dup `_d2h_out` static def (resolved by rename +
#                #endif close).
#
# Second fire = REDUCTION-only, smaller upload, smaller cost (~$0.10).
# Skip elementwise re-run; keep prior fire_elem.log + result.

set -uo pipefail

PHASE_ID="forge_phase4d_5_3_2026_05_17"
LOCAL_DIR="/Users/ghost/core/hexa-lang/state/forge_phase4d_5_3_2026_05_17"
REPO_ROOT="/Users/ghost/core/hexa-lang/.claude/worktrees/agent-a790090e00be4316b"
SRC_CUDA="$REPO_ROOT/self/cuda/runtime_cuda.c"
SRC_RED="$REPO_ROOT/tool/cuda_test_farr_reduction.cu"
PHASE_LABEL="forge-phase4d-5-3-refire-reduction"
REMOTE_WORK="/workspace/forge_phase4d_5_3_red"

VAST_SSH_KEY="/Users/ghost/.vast/ssh/vast-key"
VASTAI="/Users/ghost/Library/Python/3.14/bin/vastai"
[ -x "$VASTAI" ]      || { echo "ERROR: vastai CLI not found"; exit 1; }
[ -f "$VAST_SSH_KEY" ] || { echo "ERROR: vast ssh key missing"; exit 1; }
[ -f "$SRC_CUDA" ]    || { echo "ERROR: $SRC_CUDA missing"; exit 1; }
[ -f "$SRC_RED" ]     || { echo "ERROR: $SRC_RED missing"; exit 1; }

mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR"
echo "=== ${PHASE_ID} REFIRE (reduction only, $(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="

echo "[1/9] Searching A100/H100/H200 offers (≤\$15/hr, cuda≥12.4) ..."
OFFER_JSON=$($VASTAI search offers \
    'gpu_name in [A100,A100_SXM4,A100_PCIE,A100X,H100_SXM,H100_PCIE,H100_NVL,H100,H200] num_gpus=1 rentable=true dph_total<15.0 cuda_max_good>=12.4 disk_space>50' \
    -o dph_total --raw 2>&1)
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
[ -z "$OFFER_ID" ] && { echo "ERROR: no offer parsed"; exit 1; }
echo "  Selected: id=$OFFER_ID dph=\$$OFFER_DPH gpu=$OFFER_GPU"
echo "$OFFER_ID" > offer_id_refire.txt
echo "$OFFER_GPU" > offer_gpu_refire.txt
echo "$OFFER_DPH" > offer_dph_refire.txt

echo "[2/9] Renting instance ..."
CREATE_OUT=$($VASTAI create instance "$OFFER_ID" \
    --image nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 \
    --disk 50 --ssh --direct --label "$PHASE_LABEL" --raw 2>&1)
INSTANCE_ID=$(echo "$CREATE_OUT" | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except: sys.stderr.write('parse_fail\n'); sys.exit(1)
print(d.get('new_contract', d.get('contract_id', d.get('id',''))))
")
[ -z "$INSTANCE_ID" ] && { echo "ERROR: instance id parse failed: $CREATE_OUT"; exit 1; }
echo "  Instance ID: $INSTANCE_ID"
echo "$INSTANCE_ID" > vast_instance_id_refire.txt

cleanup() {
    local rc=$?
    if [ "${SAVE_POD:-0}" = "1" ]; then
        echo "[cleanup] SAVE_POD=1 — keep instance $INSTANCE_ID (rc=$rc)"
    else
        echo "[cleanup] Destroying instance $INSTANCE_ID (exit=$rc)..."
        $VASTAI destroy instance "$INSTANCE_ID" 2>&1 | head -3 || true
    fi
}
trap cleanup EXIT INT TERM

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
SSH_OPTS="-i $VAST_SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60"
SSH_CMD="ssh $SSH_OPTS -p $SSH_PORT root@$SSH_HOST"
SCP_CMD="scp $SSH_OPTS -P $SSH_PORT -o ConnectTimeout=3600"

echo "[4/9] Toolchain sanity ..."
$SSH_CMD "nvidia-smi --query-gpu=name,compute_cap,memory.total,driver_version --format=csv,noheader ;
  nvcc --version | head -5 ;
  mkdir -p $REMOTE_WORK ; echo READY" 2>&1 | tee remote_sanity_refire.log

DEV_CC=$($SSH_CMD 'nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d "."' 2>/dev/null || echo "80")
[ -z "$DEV_CC" ] && DEV_CC=80
echo "  Device compute cap: sm_${DEV_CC}"

echo "[5/9] Upload runtime_cuda.c + reduction harness ..."
$SCP_CMD "$SRC_CUDA" "root@$SSH_HOST:$REMOTE_WORK/runtime_cuda.c"
$SCP_CMD "$SRC_RED"  "root@$SSH_HOST:$REMOTE_WORK/cuda_test_farr_reduction.cu"

echo "[6/9] Build + run reduction harness on sm_${DEV_CC} ..."
$SSH_CMD "cd $REMOTE_WORK && \
    echo '=== BUILD RED ===' ; \
    nvcc -O2 -std=c++14 -DHEXA_CUDA -gencode arch=compute_${DEV_CC},code=sm_${DEV_CC} \
        -x cu runtime_cuda.c \
        cuda_test_farr_reduction.cu \
        -lcublas -lcudart -lm -o test_red 2>&1 | tee build_red_refire.log ; \
    BUILD_RED_RC=\${PIPESTATUS[0]} ; \
    echo \"BUILD_RED_RC=\$BUILD_RED_RC\" ; \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_pre_refire.csv ; \
    echo '=== FIRE RED ===' ; \
    if [ \"\$BUILD_RED_RC\" = '0' ]; then \
      ./test_red 2>&1 | tee fire_red_refire.log ; \
      FIRE_RED_RC=\${PIPESTATUS[0]} ; \
      echo \"FIRE_RED_RC=\$FIRE_RED_RC\" ; \
    else \
      echo 'BUILD RED FAILED' ; FIRE_RED_RC=255 ; \
    fi ; \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_post_refire.csv ; \
    echo \"=== SUMMARY === BUILD_RED_RC=\$BUILD_RED_RC FIRE_RED_RC=\$FIRE_RED_RC\"" 2>&1 | tee dispatch_refire.log

echo "[7/9] Pull artifacts ..."
SAVE_POD=1

pull_with_retry() {
    local src="$1" dst="$2" tries=0
    while [ $tries -lt 3 ]; do
        if $SCP_CMD "root@$SSH_HOST:$src" "$dst" 2>&1; then
            echo "  pulled $src (try $((tries+1)))"; return 0
        fi
        tries=$((tries+1)); [ $tries -lt 3 ] && sleep 15
    done
    echo "  pull FAILED after 3 tries: $src"; return 1
}
PULL_OK=1
pull_with_retry "$REMOTE_WORK/build_red_refire.log" "$LOCAL_DIR/build_red_refire.log" || PULL_OK=0
pull_with_retry "$REMOTE_WORK/fire_red_refire.log"  "$LOCAL_DIR/fire_red_refire.log"  || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_pre_refire.csv"  "$LOCAL_DIR/nvidia_smi_pre_refire.csv"  || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_post_refire.csv" "$LOCAL_DIR/nvidia_smi_post_refire.csv" || true

echo "[8/9] Pod lifecycle ..."
if [ $PULL_OK -eq 1 ]; then
    echo "  All core artifacts pulled — destroying"
    $VASTAI destroy instance "$INSTANCE_ID" 2>&1 | head -3 || true
    SAVE_POD=0
else
    echo "  [WARN] partial pull — pod RETAINED"
    echo "  manual destroy: $VASTAI destroy instance $INSTANCE_ID"
fi

echo "[9/9] === REFIRE DONE ==="
date -u
echo "GPU: $OFFER_GPU sm_${DEV_CC}  Rate: \$${OFFER_DPH}/hr"
if [ -f "$LOCAL_DIR/fire_red_refire.log" ]; then
    echo "--- REDUCTION/B2 REFIRE TAIL ---"
    tail -40 "$LOCAL_DIR/fire_red_refire.log"
fi
echo "DONE"
