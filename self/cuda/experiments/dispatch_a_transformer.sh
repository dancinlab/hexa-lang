#!/bin/bash
# dispatch_a_transformer.sh — forge Phase R / A Stage 2 Phase 2 fire.
#
# Source: self/cuda/experiments/{a_transformer_aot.cu, a_transformer_pytorch.py}
# Output: state/forge_phaseR_a_transformer_2026_05_17/{result.json, pytorch_result.json,
#         build_aot.log, fire_aot.log, fire_pytorch.log, nvidia_smi_*.csv}
#
# Hypothesis (F-FORGE-A-STAGE2-TRANSFORMER): single Llama-style transformer block
# AOT trainer >= 1.1× PyTorch eager (large config expected 1.5-3×).
#
# Configs (Llama-style single block):
#   small  : B=1 L=64  D=512  nh=8  hd=64  Df=2048
#   medium : B=1 L=128 D=2048 nh=16 hd=128 Df=5632
#   large  : B=1 L=512 D=4096 nh=32 hd=128 Df=11008  (Llama-7B block)
#
# Budget: ~$2-3 (allow multi-iter on debug)

set -uo pipefail

PHASE_ID="forge_phaseR_a_transformer_2026_05_17"
WORKTREE="/Users/ghost/core/hexa-lang/.claude/worktrees/agent-a878ec8720149706b"
LOCAL_DIR="$WORKTREE/state/forge_phaseR_a_transformer_2026_05_17"
SRC_DIR="$WORKTREE/self/cuda/experiments"
PHASE_LABEL="forge-phaseR-A-stage2-phase2-transformer"
REMOTE_WORK="/workspace/forge_phaseR_a_transformer"
PRESET="${PRESET:-all}"   # caller can override

VAST_SSH_KEY="/Users/ghost/.vast/ssh/vast-key"
VASTAI="/Users/ghost/Library/Python/3.14/bin/vastai"
[ -x "$VASTAI" ] || { echo "ERROR: vastai CLI not found at $VASTAI"; exit 1; }
[ -f "$VAST_SSH_KEY" ] || { echo "ERROR: vast ssh key missing"; exit 1; }
[ -f "$SRC_DIR/a_transformer_aot.cu" ]      || { echo "ERROR: a_transformer_aot.cu missing"; exit 1; }
[ -f "$SRC_DIR/a_transformer_pytorch.py" ]  || { echo "ERROR: a_transformer_pytorch.py missing"; exit 1; }

mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR"
echo "=== ${PHASE_ID} vast.ai dispatch (Phase R / A Stage 2 Phase 2, 2026-05-17) ==="
date -u

# ── 1) Search offers ─────────────────────────────────────────────────
echo "[1/9] Searching H100/H200/A100 offers under \$15/hr ..."
OFFER_JSON=$($VASTAI search offers \
    'gpu_name in [H100_SXM,H100_PCIE,H100_NVL,H100,H200,A100_SXM4,A100_PCIE,A100] num_gpus=1 rentable=true dph_total<15.0 cuda_max_good>=12.4 disk_space>50' \
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

# ── 2) Rent instance with pytorch image ──────────────────────────────
echo "[2/9] Renting instance (pytorch:2.4.0-cuda12.4 image) ..."
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

# ── 4) Toolchain sanity ───────────────────────────────────────────────
echo "[4/9] Remote toolchain sanity ..."
$SSH_CMD "set +e
  nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader | head -2
  echo '---'
  nvcc --version | head -5
  echo '---'
  python -c 'import torch; print(\"torch=\"+torch.__version__+\" dev=\"+torch.cuda.get_device_name(0))'
  ls /usr/local/cuda/include/cublas_v2.h && echo 'cublas_v2.h PRESENT' || echo 'MISSING'
  mkdir -p $REMOTE_WORK
  echo 'TOOLCHAIN_OK'" 2>&1 | tee remote_sanity.log

# ── 5) Upload sources ─────────────────────────────────────────────────
echo "[5/9] Upload a_transformer_aot.cu + a_transformer_pytorch.py ..."
$SCP_CMD "$SRC_DIR/a_transformer_aot.cu"       "root@$SSH_HOST:$REMOTE_WORK/"
$SCP_CMD "$SRC_DIR/a_transformer_pytorch.py"   "root@$SSH_HOST:$REMOTE_WORK/"

# ── 6) Build + run CUDA AOT ──────────────────────────────────────────
echo "[6/9] Build + run a_transformer_aot (preset=$PRESET) ..."
$SSH_CMD "cd $REMOTE_WORK && \
    nvcc -O3 -std=c++14 -arch=native \
        a_transformer_aot.cu -lcublas -lcudart -lm -lrt \
        -o a_transformer_aot 2>&1 | tee build_aot.log ; \
    BUILD_RC=\${PIPESTATUS[0]} ; \
    echo \"BUILD_RC=\$BUILD_RC\" ; \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_pre.csv ; \
    if [ \"\$BUILD_RC\" = '0' ]; then \
      ./a_transformer_aot $PRESET 2>&1 | tee fire_aot.log ; \
      echo \"AOT_RC=\${PIPESTATUS[0]}\" ; \
    else \
      echo 'CUDA BUILD FAILED — skipping AOT fire' ; \
    fi ; \
    test -f result.json && echo 'AOT_RESULT_JSON_OK' || echo 'AOT_RESULT_JSON_MISSING'" 2>&1 | tee dispatch_aot.log

echo "[6.5/9] Run a_transformer_pytorch.py (preset=$PRESET) ..."
$SSH_CMD "cd $REMOTE_WORK && \
    python a_transformer_pytorch.py $PRESET 2>&1 | tee fire_pytorch.log ; \
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
[ "$SAVED_AOT" = "OK" ] && pull_with_retry "$REMOTE_WORK/result.json"         "$LOCAL_DIR/result.json"         || PULL_OK=0
[ "$SAVED_PYT" = "OK" ] && pull_with_retry "$REMOTE_WORK/pytorch_result.json" "$LOCAL_DIR/pytorch_result.json" || PULL_OK=0
pull_with_retry "$REMOTE_WORK/build_aot.log"      "$LOCAL_DIR/build_aot.log" || true
pull_with_retry "$REMOTE_WORK/fire_aot.log"       "$LOCAL_DIR/fire_aot.log" || true
pull_with_retry "$REMOTE_WORK/fire_pytorch.log"   "$LOCAL_DIR/fire_pytorch.log" || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_pre.csv" "$LOCAL_DIR/nvidia_smi_pre.csv" || true
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
print('config   B L     D    nh hd   Df       AOT_ms      PyT_ms     speedup   verdict   AOT loss(init→fin)        PyT loss(init→fin)')
for lbl in ('small','medium','large'):
    a = aot_cfgs.get(lbl); p = pyt_cfgs.get(lbl)
    if not a or not p: continue
    aot_ms = a['step_ms_median']
    pyt_ms = p['step_ms_median']
    speedup = pyt_ms / aot_ms if aot_ms > 0 else 0
    verdict = 'PASS' if speedup >= 1.1 else 'FAIL'
    print('%-7s %d %4d  %5d %3d %3d %5d  %9.3f  %9.3f   %6.3fx   %s   %.4f → %.4f       %.4f → %.4f' % (
        lbl, a['B'], a['L'], a['D'], a['nh'], a['hd'], a['Df'],
        aot_ms, pyt_ms, speedup, verdict,
        a.get('initial_loss',0), a.get('final_loss',0),
        p.get('initial_loss',0), p.get('final_loss',0)))
"
fi
echo "DONE"
