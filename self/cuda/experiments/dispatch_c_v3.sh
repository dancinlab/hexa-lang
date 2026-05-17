#!/bin/bash
# dispatch_c_v3.sh — forge Phase R / C Stage 2 Phase 3 (production tiling kernel)
#
# Source: self/cuda/experiments/c_fused_linear_v3_production.cu
#   3-kernel chain (Y/dW/dX), production register tiling 4×4, double-buffered SMEM,
#   NO atomic_add — fully deterministic. Targets wall PASS (≤ 0.75× cuBLAS chain).
#
# Output: state/forge_phaseR_c_v3_2026_05_17/{result.json, fire.log, build.log}
#
# Falsifier (RFC 044 §"Falsifier battery — C' tier"):
#   ✅ F-FORGE-C-STAGE2-FUSED-CEILING — HBM traffic ≤ 0.75 × separate (analytic: 0.667 from Phase 1/2)
#   ✅ F-FORGE-C-STAGE2-DET-PRESERVE  — Y/dW/dX equivalence at TOL_OP ≤ 1e-9 (no atomic noise)
#   🎯 F-FORGE-C-STAGE2-WALL-LARGE   — production wall ≤ 0.75 × cuBLAS chain (THIS FIRE)
#
# Hardware: prefer H100/H200 (sm_90), accept A100 (sm_80). FP64 needed (no TC for FP64).

set -uo pipefail

PHASE_ID="forge_phaseR_c_v3_2026_05_17"
LOCAL_DIR="/Users/ghost/core/hexa-lang/state/forge_phaseR_c_v3_2026_05_17"
SRC_DIR="/Users/ghost/core/hexa-lang/self/cuda/experiments"
PHASE_LABEL="forge-phaseR-C-v3-production-tiling"
REMOTE_WORK="/workspace/forge_phaseR_c_v3"

VAST_SSH_KEY="/Users/ghost/.vast/ssh/vast-key"
VASTAI="/Users/ghost/Library/Python/3.14/bin/vastai"
[ -x "$VASTAI" ] || { echo "ERROR: vastai CLI not found"; exit 1; }
[ -f "$VAST_SSH_KEY" ] || { echo "ERROR: vast ssh key missing"; exit 1; }
[ -f "$SRC_DIR/c_fused_linear_v3_production.cu" ] || { echo "ERROR: c_fused_linear_v3_production.cu missing"; exit 1; }

mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR"
echo "=== ${PHASE_ID} vast.ai dispatch (Phase R / C Stage 2 Phase 3, 2026-05-17) ==="
date -u

# ── 1) Search offers (H100/H200/A100, ≤$15/hr) ─────────────────────────
echo "[1/9] Searching offers (H100/H200/A100 ≤\$15/hr) ..."
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

# ── 2) Rent ──────────────────────────────────────────────────────────
echo "[2/9] Renting instance (cuda:12.4 devel image) ..."
CREATE_OUT=$($VASTAI create instance "$OFFER_ID" \
    --image nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 \
    --disk 50 --ssh --direct --label "$PHASE_LABEL" --raw 2>&1)
INSTANCE_ID=$(echo "$CREATE_OUT" | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except: sys.stderr.write('parse_fail\n'); sys.exit(1)
print(d.get('new_contract', d.get('contract_id', d.get('id',''))))
")
[ -z "$INSTANCE_ID" ] && { echo "ERROR: instance id parse failed"; exit 1; }
echo "  Instance ID: $INSTANCE_ID"
echo "$INSTANCE_ID" > vast_instance_id.txt

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

# ── 3) Wait for SSH ───────────────────────────────────────────────────
echo "[3/9] Waiting for SSH ..."
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

# ── 4) Toolchain sanity ───────────────────────────────────────────────
echo "[4/9] Remote toolchain sanity ..."
$SSH_CMD "set +e
  nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | head -2
  nvcc --version | head -5
  ls /usr/local/cuda/include/cublas_v2.h && echo 'cublas_v2.h PRESENT' || echo 'MISSING'
  mkdir -p $REMOTE_WORK
  echo 'TOOLCHAIN_OK'" 2>&1 | tee remote_sanity.log

# ── 5) Upload ─────────────────────────────────────────────────────────
echo "[5/9] Upload c_fused_linear_v3_production.cu ..."
$SCP_CMD "$SRC_DIR/c_fused_linear_v3_production.cu" "root@$SSH_HOST:$REMOTE_WORK/"

# ── 6) Build + run ────────────────────────────────────────────────────
# nvcc -O3 -std=c++17 -arch=native — production flags; lambdas need c++17
echo "[6/9] Build + run c_fused_linear_v3_production ..."
$SSH_CMD "cd $REMOTE_WORK && \
    nvcc -O3 -std=c++17 -arch=native --expt-extended-lambda \
        c_fused_linear_v3_production.cu -lcublas -lcudart -lm -lrt \
        -o c_fused_linear_v3_production 2>&1 | tee build.log ; \
    BUILD_RC=\${PIPESTATUS[0]} ; \
    echo \"BUILD_RC=\$BUILD_RC\" ; \
    nvidia-smi --query-gpu=name,memory.used --format=csv,noheader > nvidia_smi_pre.csv ; \
    if [ \"\$BUILD_RC\" = '0' ]; then \
      ./c_fused_linear_v3_production 2>&1 | tee fire.log ; \
      echo \"FIRE_RC=\${PIPESTATUS[0]}\" ; \
    else \
      echo 'BUILD FAILED — skipping fire' ; \
    fi ; \
    test -f result.json && echo 'RESULT_JSON_OK' || echo 'RESULT_JSON_MISSING'" 2>&1 | tee dispatch.log

# ── 7) Pull ───────────────────────────────────────────────────────────
echo "[7/9] Pull artifacts ..."
SAVED=$($SSH_CMD "test -f $REMOTE_WORK/result.json && echo OK" 2>/dev/null || true)
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
[ "$SAVED" = "OK" ] && pull_with_retry "$REMOTE_WORK/result.json" "$LOCAL_DIR/result.json" || PULL_OK=0
pull_with_retry "$REMOTE_WORK/build.log" "$LOCAL_DIR/build.log" || PULL_OK=0
pull_with_retry "$REMOTE_WORK/fire.log"  "$LOCAL_DIR/fire.log" || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_pre.csv" "$LOCAL_DIR/nvidia_smi_pre.csv" || true

# ── 8) Lifecycle ──────────────────────────────────────────────────────
if [ $PULL_OK -eq 1 ]; then
    echo "[8/9] All core artifacts pulled — destroying"
    $VASTAI destroy instance "$INSTANCE_ID" 2>&1 | head -3 || true
    SAVE_POD=0
else
    echo "[8/9] [WARN] partial pull — pod RETAINED"
    echo "  manual destroy: $VASTAI destroy instance $INSTANCE_ID"
fi

# ── 9) Summary ────────────────────────────────────────────────────────
echo "[9/9] === ${PHASE_ID} DONE ==="
date -u
if [ -f "$LOCAL_DIR/result.json" ]; then
    python3 -c "
import json
d = json.load(open('$LOCAL_DIR/result.json'))
print('Device: cc=%s sm=%d L2=%.1fMB cublas=%s' % (d.get('device_cc','?'), d.get('sm_count',0), d.get('l2_mb',0), d.get('cublas_version','?')))
s = d.get('summary',{})
print('Verdicts: traffic=%d det=%d wall_all=%d wall_any=%d' % (s.get('all_traffic_pass',0), s.get('all_det_pass',0), s.get('all_wall_pass',0), s.get('any_wall_pass',0)))
print('Per-shape:')
for sh in d.get('shapes', []):
    print('  M=%d K=%d N=%d  sep=%.4f ms (%.2f TFLOPS)  fused=%.4f ms (%.2f TFLOPS)  ratio=%.3f  traffic=%d det=%d wall=%d' % (
        sh['M'], sh['K'], sh['N'],
        sh['t_separate_ms'], sh['cublas_tflops'],
        sh['t_fused_ms'], sh['fused_tflops'],
        sh['fused_over_separate'],
        sh['falsifier_traffic_pass'], sh['falsifier_det_pass'], sh['falsifier_wall_pass']))
"
fi
echo "DONE"
