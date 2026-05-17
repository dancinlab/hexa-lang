#!/bin/bash
# dispatch_b_dsm_v2.sh — forge Phase R / B Stage 2 Phase 2 fire
# Real DSM-fused FFN kernel measurement on H200 (Hopper sm_90).
#
# Source: self/cuda/experiments/b_dsm_fused_ffn_v2.cu
# Output: state/forge_phaseR_b_dsm_v2_2026_05_17/{result.json, fire.log, build.log}
#
# Provider strategy: vast.ai first (cheaper if available), fallback runpodctl
# (H200 secure cloud $3.99/hr on-demand).
#
# Budget: $2-3 max. Single fire. SAVE_POD on partial pull; scp retry x3.
# Hardware: H100/H200 only (sm_90+ required for cluster DSM API).

set -uo pipefail

PHASE_ID="forge_phaseR_b_dsm_v2_2026_05_17"
WORKTREE="/Users/ghost/core/hexa-lang"
LOCAL_DIR="/Users/ghost/core/hexa-lang/state/$PHASE_ID"
SRC_DIR="/Users/ghost/core/hexa-lang/self/cuda/experiments"
PHASE_LABEL="forge-phaseR-B-stage2-phase2-dsm-fused"
REMOTE_WORK="/workspace/b_dsm_v2"

VAST_SSH_KEY="/Users/ghost/.vast/ssh/vast-key"
VASTAI="/Users/ghost/Library/Python/3.14/bin/vastai"
RUNPODCTL="/opt/homebrew/Cellar/runpodctl/2.1.9/bin/runpodctl"
[ -x "$VASTAI" ] || { echo "ERROR: vastai CLI not found"; exit 1; }
[ -f "$VAST_SSH_KEY" ] || { echo "ERROR: vast ssh key missing"; exit 1; }
[ -x "$RUNPODCTL" ] || { echo "ERROR: runpodctl not found"; exit 1; }
[ -f "$SRC_DIR/b_dsm_fused_ffn_v2.cu" ] || { echo "ERROR: kernel src missing"; exit 1; }

mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR"
echo "=== ${PHASE_ID} dispatch (Phase R / B Stage 2 Phase 2 DSM-fused FFN) ==="
date -u

# ════════════════════════════════════════════════════════════════════════
# 1) Try vast.ai first (cheap if rentable Hopper exists)
# ════════════════════════════════════════════════════════════════════════
echo "[1/9] Probe vast.ai for rentable Hopper offers ..."
VAST_OFFER_JSON=$($VASTAI search offers \
    'gpu_name in [H100_SXM,H100_PCIE,H100_NVL,H100,H200] num_gpus=1 rentable=true cuda_max_good>=12.4 disk_space>40' \
    -o dph_total --raw 2>&1)
VAST_OFFER_PARSED=$(echo "$VAST_OFFER_JSON" | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except: print('ERR'); sys.exit(0)
if not d: print('NONE'); sys.exit(0)
b = d[0]
print('%s|%.4f|%s|%s' % (b['id'], b['dph_total'], b['gpu_name'].replace(' ','_'), b.get('cuda_max_good','?')))
")

USE_VAST=0
if [[ "$VAST_OFFER_PARSED" =~ ^[0-9] ]]; then
    USE_VAST=1
    OFFER_ID=$(echo "$VAST_OFFER_PARSED" | cut -d'|' -f1)
    OFFER_DPH=$(echo "$VAST_OFFER_PARSED" | cut -d'|' -f2)
    OFFER_GPU=$(echo "$VAST_OFFER_PARSED" | cut -d'|' -f3)
    echo "  vast.ai Hopper offer found: id=$OFFER_ID dph=\$$OFFER_DPH gpu=$OFFER_GPU"
else
    echo "  vast.ai: $VAST_OFFER_PARSED (no rentable Hopper) — falling back to RunPod"
fi

# ════════════════════════════════════════════════════════════════════════
# 2) Provision instance
# ════════════════════════════════════════════════════════════════════════
INSTANCE_ID=""
SSH_HOST=""
SSH_PORT=""
PROVIDER=""

if [ $USE_VAST -eq 1 ]; then
    PROVIDER="vast"
    echo "[2/9] vast.ai: rent instance $OFFER_ID ..."
    CREATE_OUT=$($VASTAI create instance "$OFFER_ID" \
        --image nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 \
        --disk 50 --ssh --direct --label "$PHASE_LABEL" --raw 2>&1)
    INSTANCE_ID=$(echo "$CREATE_OUT" | python3 -c "
import json,sys
try: d=json.load(sys.stdin); print(d.get('new_contract', d.get('contract_id', d.get('id',''))))
except: sys.exit(1)
")
    [ -z "$INSTANCE_ID" ] && { echo "ERROR: vast instance create failed"; exit 1; }
    echo "  vast instance ID: $INSTANCE_ID"
    echo "$INSTANCE_ID" > vast_instance_id.txt
else
    PROVIDER="runpod"
    echo "[2/9] RunPod: create H200 secure cloud pod ..."
    POD_OUT=$($RUNPODCTL create pod \
        --name "$PHASE_LABEL" \
        --gpuType "NVIDIA H200" \
        --gpuCount 1 \
        --imageName "nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04" \
        --containerDiskSize 50 \
        --volumeSize 0 \
        --secureCloud \
        --startSSH \
        --cost 4.5 \
        --ports "22/tcp" 2>&1)
    echo "$POD_OUT" > runpod_create.json
    INSTANCE_ID=$(echo "$POD_OUT" | python3 -c "
import json, sys, re
raw = sys.stdin.read()
try:
    d = json.loads(raw)
    print(d.get('id', d.get('podId', '')))
except:
    m = re.search(r'pod\\s+\"?([a-z0-9]+)\"?\\s+created', raw, re.IGNORECASE)
    if m: print(m.group(1))
    else:
        m2 = re.search(r'\"id\":\\s*\"([^\"]+)\"', raw)
        if m2: print(m2.group(1))
")
    [ -z "$INSTANCE_ID" ] && { echo "ERROR: runpod pod id parse failed"; cat runpod_create.json; exit 1; }
    echo "  runpod pod ID: $INSTANCE_ID"
    echo "$INSTANCE_ID" > runpod_pod_id.txt
fi

cleanup() {
    local rc=$?
    if [ "${SAVE_POD:-0}" = "1" ]; then
        echo "[cleanup] SAVE_POD=1 — keep instance $INSTANCE_ID (rc=$rc)"
        if [ "$PROVIDER" = "vast" ]; then
            echo "  manual destroy: $VASTAI destroy instance $INSTANCE_ID"
        else
            echo "  manual destroy: $RUNPODCTL remove pod $INSTANCE_ID"
        fi
    else
        echo "[cleanup] Destroying $PROVIDER instance $INSTANCE_ID (exit=$rc)..."
        if [ "$PROVIDER" = "vast" ]; then
            $VASTAI destroy instance "$INSTANCE_ID" 2>&1 | head -3 || true
        else
            $RUNPODCTL remove pod "$INSTANCE_ID" 2>&1 | head -3 || true
        fi
    fi
}
trap cleanup EXIT INT TERM

# ════════════════════════════════════════════════════════════════════════
# 3) Wait for SSH
# ════════════════════════════════════════════════════════════════════════
echo "[3/9] Waiting for SSH ..."
SSH_OPTS_BASE="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60"

if [ "$PROVIDER" = "vast" ]; then
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
                if ssh -i "$VAST_SSH_KEY" $SSH_OPTS_BASE -o ConnectTimeout=10 -p "$SSH_PORT" "root@$SSH_HOST" 'echo READY' 2>&1 | grep -q READY; then
                    echo "  vast SSH ready: $SSH_HOST:$SSH_PORT (after ${i}x5s)"
                    break
                fi
                SSH_HOST=""
            fi
        fi
        echo "  ... attempt $i/160 status=$STATUS"
        sleep 5
    done
    SSH_KEY="$VAST_SSH_KEY"
    SSH_USER="root"
else
    # RunPod — query pod via runpodctl
    for i in $(seq 1 160); do
        POD_INFO=$($RUNPODCTL get pod "$INSTANCE_ID" 2>&1 || true)
        STATUS=$(echo "$POD_INFO" | python3 -c "
import json, sys, re
raw = sys.stdin.read()
try:
    d = json.loads(raw)
    print(d.get('desiredStatus','') or d.get('status', '') or d.get('lastStatusChange',''))
except:
    m = re.search(r'\"desiredStatus\":\\s*\"([^\"]+)\"', raw)
    print(m.group(1) if m else 'unknown')
")
        # Try to extract SSH addr
        SSH_HOST=$(echo "$POD_INFO" | python3 -c "
import json, sys, re
raw = sys.stdin.read()
try:
    d = json.loads(raw)
    # Look at runtime/ports
    rt = d.get('runtime', {}) or {}
    ports = rt.get('ports', []) or []
    for p in ports:
        if p.get('privatePort') == 22 or p.get('type') == 'tcp':
            print(p.get('ip', ''))
            break
except:
    m = re.search(r'\"ip\":\\s*\"([^\"]+)\"', raw)
    if m: print(m.group(1))
" 2>/dev/null || echo "")
        SSH_PORT=$(echo "$POD_INFO" | python3 -c "
import json, sys, re
raw = sys.stdin.read()
try:
    d = json.loads(raw)
    rt = d.get('runtime', {}) or {}
    ports = rt.get('ports', []) or []
    for p in ports:
        if p.get('privatePort') == 22:
            print(p.get('publicPort', ''))
            break
except:
    pass
" 2>/dev/null || echo "")
        if [ "$STATUS" = "RUNNING" ] && [ -n "$SSH_HOST" ] && [ -n "$SSH_PORT" ]; then
            echo "  runpod attempting SSH to $SSH_HOST:$SSH_PORT (status=$STATUS) ..."
            if ssh -i ~/.ssh/id_ed25519 $SSH_OPTS_BASE -o ConnectTimeout=10 -p "$SSH_PORT" "root@$SSH_HOST" 'echo READY' 2>&1 | grep -q READY; then
                echo "  runpod SSH ready: $SSH_HOST:$SSH_PORT (after ${i}x5s)"
                break
            fi
        fi
        echo "  ... attempt $i/160 status=$STATUS host=$SSH_HOST port=$SSH_PORT"
        sleep 5
    done
    SSH_KEY="$HOME/.ssh/id_ed25519"
    SSH_USER="root"
fi

[ -z "$SSH_HOST" ] && { echo "ERROR: SSH not ready"; SAVE_POD=1; exit 1; }
SSH_OPTS="-i $SSH_KEY $SSH_OPTS_BASE"
SSH_CMD="ssh $SSH_OPTS -p $SSH_PORT ${SSH_USER}@$SSH_HOST"
SCP_CMD="scp $SSH_OPTS -P $SSH_PORT -o ConnectTimeout=3600"

# ════════════════════════════════════════════════════════════════════════
# 4) Toolchain sanity
# ════════════════════════════════════════════════════════════════════════
echo "[4/9] Remote toolchain sanity ..."
$SSH_CMD "set +e
  nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv,noheader | head -2
  nvcc --version | head -5
  ls /usr/local/cuda/include/cooperative_groups.h && echo 'coop_groups.h PRESENT' || echo 'MISSING'
  ls /usr/local/cuda/include/cublas_v2.h && echo 'cublas_v2.h PRESENT' || echo 'MISSING'
  mkdir -p $REMOTE_WORK
  echo 'TOOLCHAIN_OK'" 2>&1 | tee remote_sanity.log

# ════════════════════════════════════════════════════════════════════════
# 5) Upload kernel
# ════════════════════════════════════════════════════════════════════════
echo "[5/9] Upload b_dsm_fused_ffn_v2.cu ..."
$SCP_CMD "$SRC_DIR/b_dsm_fused_ffn_v2.cu" "${SSH_USER}@$SSH_HOST:$REMOTE_WORK/"

# ════════════════════════════════════════════════════════════════════════
# 6) Build + run (sm_90, opt-in large SMEM)
# ════════════════════════════════════════════════════════════════════════
echo "[6/9] Build + run b_dsm_fused_ffn_v2 (sm_90 cluster DSM, FP64) ..."
$SSH_CMD "cd $REMOTE_WORK && \
    nvcc -O3 -std=c++17 -gencode arch=compute_90,code=sm_90 \
        b_dsm_fused_ffn_v2.cu -lcublas -lcudart -lm -lrt \
        -o b_dsm_fused_ffn_v2 2>&1 | tee build.log ; \
    BUILD_RC=\${PIPESTATUS[0]} ; \
    echo \"BUILD_RC=\$BUILD_RC\" ; \
    nvidia-smi --query-gpu=name,memory.used --format=csv,noheader > nvidia_smi_pre.csv ; \
    if [ \"\$BUILD_RC\" = '0' ]; then \
      ./b_dsm_fused_ffn_v2 2>&1 | tee fire.log ; \
      echo \"FIRE_RC=\${PIPESTATUS[0]}\" ; \
    else \
      echo 'BUILD FAILED — skipping fire' ; \
    fi ; \
    test -f result.json && echo 'RESULT_JSON_OK' || echo 'RESULT_JSON_MISSING'" 2>&1 | tee dispatch.log

# ════════════════════════════════════════════════════════════════════════
# 7) Pull artifacts (≥3 retries)
# ════════════════════════════════════════════════════════════════════════
echo "[7/9] Pull artifacts ..."
SAVED=$($SSH_CMD "test -f $REMOTE_WORK/result.json && echo OK" 2>/dev/null || true)
SAVE_POD=1

pull_with_retry() {
    local src="$1" dst="$2" tries=0
    while [ $tries -lt 3 ]; do
        if $SCP_CMD "${SSH_USER}@$SSH_HOST:$src" "$dst" 2>&1; then
            echo "  pulled $src (try $((tries+1)))"; return 0
        fi
        tries=$((tries+1)); echo "  ... pull retry $tries/3 for $src"
        [ $tries -lt 3 ] && sleep 15
    done
    echo "  pull FAILED after 3 tries: $src"; return 1
}
PULL_OK=1
if [ "$SAVED" = "OK" ]; then
    pull_with_retry "$REMOTE_WORK/result.json" "$LOCAL_DIR/result.json" || PULL_OK=0
else
    PULL_OK=0
fi
pull_with_retry "$REMOTE_WORK/build.log" "$LOCAL_DIR/build.log" || PULL_OK=0
pull_with_retry "$REMOTE_WORK/fire.log"  "$LOCAL_DIR/fire.log" || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_pre.csv" "$LOCAL_DIR/nvidia_smi_pre.csv" || true

# ════════════════════════════════════════════════════════════════════════
# 8) Lifecycle
# ════════════════════════════════════════════════════════════════════════
if [ $PULL_OK -eq 1 ]; then
    echo "[8/9] All core artifacts pulled — destroying $PROVIDER instance $INSTANCE_ID"
    if [ "$PROVIDER" = "vast" ]; then
        $VASTAI destroy instance "$INSTANCE_ID" 2>&1 | head -3 || true
    else
        $RUNPODCTL remove pod "$INSTANCE_ID" 2>&1 | head -3 || true
    fi
    SAVE_POD=0
else
    echo "[8/9] [WARN] partial pull — pod RETAINED ($INSTANCE_ID)"
fi

# ════════════════════════════════════════════════════════════════════════
# 9) Summary
# ════════════════════════════════════════════════════════════════════════
echo "[9/9] === ${PHASE_ID} DONE ==="
date -u
if [ -f "$LOCAL_DIR/result.json" ]; then
    python3 -c "
import json
d = json.load(open('$LOCAL_DIR/result.json'))
print('Device: %s · cc=%s · smem_optin=%s KB' % (d.get('device_name','?'), d.get('device_cc','?'), d.get('smem_per_block_optin_kb','?')))
print()
print('Shapes:')
for s in d.get('shapes', []):
    print('  %-7s M=%3d D=%4d FD=%5d · tile=%d half=%d smem=%dB · cublas=%.4f dsm=%.4f ratio=%.4f · corr=%d %s' % (
        s.get('tier','?'), s['M'], s['D'], s['FD'], s['M_TILE'], s['FD_HALF'], s['smem_bytes'],
        s['t_cublas_ms'], s['t_dsm_ms'], s['speedup_ratio'], s['correctness_pass'], s.get('status','')))
print()
print('Falsifier verdicts:')
for fid, fd in d.get('falsifier_verdicts', {}).items():
    print('  %-30s threshold=%s ratio_or_delta=%s verdict=%s' % (fid, fd.get('threshold','?'), fd.get('ratio') or fd.get('worst_delta'), fd.get('verdict','?')))
"
fi
echo "DONE"
