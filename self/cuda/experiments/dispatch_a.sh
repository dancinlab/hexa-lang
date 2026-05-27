#!/bin/bash
# dispatch_a.sh — forge Phase R / A fire dispatch (vast.ai H100/H200).
#
# Runs BOTH:
#   1. a_aot_trainer.cu — single-binary CUDA AOT trainer (FP64, 3 configs)
#   2. a_pytorch_baseline.py — PyTorch eager equivalent (same model, same shapes)
# Then comparison summary: AOT_speedup_vs_pytorch per config.
#
# Source: self/cuda/experiments/{a_aot_trainer.cu, a_pytorch_baseline.py}
# Output: state/forge_phaseR_a_2026_05_17/{result.json (CUDA), pytorch_result.json}

set -uo pipefail

PHASE_ID="forge_phaseR_a_2026_05_17"
LOCAL_DIR="/Users/ghost/core/hexa-lang/state/forge_phaseR_a_2026_05_17"
SRC_DIR="/Users/ghost/core/hexa-lang/self/cuda/experiments"
PHASE_LABEL="forge-phaseR-A-aot-vs-pytorch"
REMOTE_WORK="/workspace/forge_phaseR_a"

VAST_SSH_KEY="/Users/ghost/.vast/ssh/vast-key"
VASTAI="/Users/ghost/Library/Python/3.14/bin/vastai"
[ -x "$VASTAI" ] || { echo "ERROR: vastai CLI not found at $VASTAI"; exit 1; }
[ -f "$VAST_SSH_KEY" ] || { echo "ERROR: vast ssh key missing"; exit 1; }
[ -f "$SRC_DIR/a_aot_trainer.cu" ] || { echo "ERROR: a_aot_trainer.cu missing"; exit 1; }
[ -f "$SRC_DIR/a_pytorch_baseline.py" ] || { echo "ERROR: a_pytorch_baseline.py missing"; exit 1; }

mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR"
echo "=== ${PHASE_ID} vast.ai dispatch (Phase R / A AOT-vs-PyTorch, 2026-05-17) ==="
date -u

# ── 1) Search offers ─────────────────────────────────────────────────
echo "[1/9] Searching H100/H200 offers under \$10/hr ..."
OFFER_JSON=$($VASTAI search offers \
    'gpu_name in [H100_SXM,H100_PCIE,H100_NVL,H100,H200] num_gpus=1 rentable=true dph_total<10.0 cuda_max_good>=12.4 disk_space>50' \
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
OFFER_CUDA=$(echo "$OFFER_PARSED" | awk '{print $4}')
[ -z "$OFFER_ID" ] && { echo "ERROR: no offer parsed"; exit 1; }
echo "  Selected: id=$OFFER_ID dph=\$$OFFER_DPH gpu=$OFFER_GPU cuda=$OFFER_CUDA"
echo "$OFFER_ID" > offer_id.txt

# ── 2) Rent instance — pytorch image saves pip install time ──────────
echo "[2/9] Renting instance with pytorch image (preinstalled torch + CUDA) ..."
CREATE_OUT=$($VASTAI create instance "$OFFER_ID" \
    --image pytorch/pytorch:2.4.0-cuda12.4-cudnn9-devel \
    --disk 50 --ssh --direct --label "$PHASE_LABEL" --raw 2>&1)
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

# ── 4) Toolchain sanity (torch + nvcc + cublas headers) ───────────────
echo "[4/9] Remote toolchain sanity ..."
$SSH_CMD "set +e
  nvidia-smi | head -8
  echo '---'
  nvcc --version | head -5
  echo '---'
  python -c 'import torch; print(\"torch=\"+torch.__version__+\" cuda=\"+str(torch.cuda.is_available())+\" dev=\"+torch.cuda.get_device_name(0))'
  echo '---'
  ls /usr/local/cuda/include/cublas_v2.h && echo 'cublas_v2.h PRESENT' || echo 'cublas_v2.h MISSING'
  ls /usr/local/cuda/lib64/libcublas.so* 2>/dev/null | head -3
  mkdir -p $REMOTE_WORK
  echo 'TOOLCHAIN_OK'" 2>&1 | tee remote_sanity.log

# ── 5) Upload sources ─────────────────────────────────────────────────
echo "[5/9] Upload a_aot_trainer.cu + a_pytorch_baseline.py ..."
$SCP_CMD "$SRC_DIR/a_aot_trainer.cu"        "root@$SSH_HOST:$REMOTE_WORK/"
$SCP_CMD "$SRC_DIR/a_pytorch_baseline.py"   "root@$SSH_HOST:$REMOTE_WORK/"

# ── 6) Build CUDA AOT trainer + run BOTH (CUDA then PyTorch) ─────────
echo "[6/9] Build + run a_aot_trainer (CUDA) ..."
$SSH_CMD "cd $REMOTE_WORK && \
    nvcc -O3 -std=c++14 -gencode arch=compute_90,code=sm_90 \
        a_aot_trainer.cu -lcublas -lcudart -lm -lrt \
        -o a_aot_trainer 2>&1 | tee build_aot.log ; \
    BUILD_RC=\${PIPESTATUS[0]} ; \
    echo \"BUILD_RC=\$BUILD_RC\" ; \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_pre.csv ; \
    if [ \"\$BUILD_RC\" = '0' ]; then \
      ./a_aot_trainer 2>&1 | tee fire_aot.log ; \
      echo \"AOT_RC=\${PIPESTATUS[0]}\" ; \
    else \
      echo 'CUDA BUILD FAILED — skipping AOT fire' ; \
    fi ; \
    test -f result.json && echo 'AOT_RESULT_JSON_OK' || echo 'AOT_RESULT_JSON_MISSING'" 2>&1 | tee dispatch_aot.log

echo "[6.5/9] Run a_pytorch_baseline.py (PyTorch eager) ..."
$SSH_CMD "cd $REMOTE_WORK && \
    python a_pytorch_baseline.py 2>&1 | tee fire_pytorch.log ; \
    echo \"PYTORCH_RC=\${PIPESTATUS[0]}\" ; \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_post.csv ; \
    test -f pytorch_result.json && echo 'PYT_RESULT_JSON_OK' || echo 'PYT_RESULT_JSON_MISSING'" 2>&1 | tee dispatch_pytorch.log

# ── 7) Pull artifacts ─────────────────────────────────────────────────
echo "[7/9] Pull artifacts ..."
SAVED_AOT=$($SSH_CMD "test -f $REMOTE_WORK/result.json && echo OK" 2>/dev/null || true)
SAVED_PYT=$($SSH_CMD "test -f $REMOTE_WORK/pytorch_result.json && echo OK" 2>/dev/null || true)
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
[ "$SAVED_AOT" = "OK" ] && pull_with_retry "$REMOTE_WORK/result.json"         "$LOCAL_DIR/result.json"         || { [ "$SAVED_AOT" != "OK" ] && echo "  AOT result missing on remote — SAVE_POD=1"; PULL_OK=0; }
[ "$SAVED_PYT" = "OK" ] && pull_with_retry "$REMOTE_WORK/pytorch_result.json" "$LOCAL_DIR/pytorch_result.json" || { [ "$SAVED_PYT" != "OK" ] && echo "  PyT result missing on remote — SAVE_POD=1"; PULL_OK=0; }
pull_with_retry "$REMOTE_WORK/build_aot.log"     "$LOCAL_DIR/build_aot.log" || true
pull_with_retry "$REMOTE_WORK/fire_aot.log"      "$LOCAL_DIR/fire_aot.log" || true
pull_with_retry "$REMOTE_WORK/fire_pytorch.log"  "$LOCAL_DIR/fire_pytorch.log" || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_pre.csv"  "$LOCAL_DIR/nvidia_smi_pre.csv" || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_post.csv" "$LOCAL_DIR/nvidia_smi_post.csv" || true

# ── 8) Pod lifecycle ──────────────────────────────────────────────────
echo "[8/9] Pod lifecycle ..."
if [ $PULL_OK -eq 1 ]; then
    echo "  All core artifacts pulled — destroying instance now"
    $VASTAI destroy instance "$INSTANCE_ID" 2>&1 | head -3 || true
    SAVE_POD=0
else
    echo "  [WARN] partial pull — pod RETAINED for manual recovery"
    echo "  manual SSH: ssh -i $VAST_SSH_KEY -p $SSH_PORT root@$SSH_HOST"
    echo "  manual destroy: $VASTAI destroy instance $INSTANCE_ID"
fi

# ── 9) Summary ────────────────────────────────────────────────────────
echo "[9/9] === ${PHASE_ID} DONE ==="
date -u
if [ -f "$LOCAL_DIR/result.json" ] && [ -f "$LOCAL_DIR/pytorch_result.json" ]; then
    python3 -c "
import json
aot = json.load(open('$LOCAL_DIR/result.json'))
pyt = json.load(open('$LOCAL_DIR/pytorch_result.json'))
aot_cfgs = {c['label']:c for c in aot.get('configs',[])}
pyt_cfgs = {c['label']:c for c in pyt.get('configs',[])}
print('Device: cc=%s mem=%dMB cublas=%s · torch=%s' % (
    aot.get('device_cc','?'), aot.get('device_mem_mb',0),
    aot.get('cublas_version','?'), pyt.get('pytorch_version','?')))
print('')
print('config              B   D_in×D_hid×D_out    AOT_ms   PyT_ms   AOT_speedup   verdict')
for lbl in sorted(aot_cfgs.keys()):
    a = aot_cfgs.get(lbl,{}); p = pyt_cfgs.get(lbl,{})
    if not a or not p: continue
    aot_ms = a['step_ms_median']
    pyt_ms = p['step_ms_median']
    speedup = pyt_ms / aot_ms if aot_ms > 0 else 0
    verdict = 'PASS' if speedup >= 1.2 else 'FAIL'
    print('%-18s  %3d  %4d×%4d×%4d      %6.3f   %6.3f   %5.3f×        %s' % (
        lbl, a['B'], a['D_in'], a['D_hid'], a['D_out'],
        aot_ms, pyt_ms, speedup, verdict))
"
fi
echo "DONE"
