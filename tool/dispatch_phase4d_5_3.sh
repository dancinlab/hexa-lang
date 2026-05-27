#!/bin/bash
# tool/dispatch_phase4d_5_3.sh — forge Phase 4-D-5-3 CUDA host nvcc build + byte-eq fire.
#
# Adapted from self/cuda/experiments/dispatch_d.sh (anima→forge pattern,
# watchdog SAVE_POD + scp retry + explicit destroy).
#
# Sources:
#   self/cuda/runtime_cuda.c            (1255 LOC — 11 kernels + cuBLAS Dgemm wiring)
#   tool/cuda_test_farr_elementwise.cu  (5 falsifiers — bit-exact + tol elem)
#   tool/cuda_test_farr_reduction.cu    (6 falsifiers — reduction + B2 + cuBLAS reshape)
#
# Output:  state/forge_phase4d_5_3_2026_05_17/
#   {result_elem.json, result_reduction.json, fire_elem.log, fire_reduction.log,
#    build_elem.log, build_reduction.log, nvidia_smi_pre.csv, nvidia_smi_post.csv}
#
# Falsifier coverage (RFC 041 §"Falsifier battery"):
#   Elementwise (5): F-RFC041-{ADD,SCALE,MUL}-EXACT, F-RFC041-SILU-EQ,
#                    F-RFC041-SILU-GRAD-EQ, F-RFC041-DETERMINISM
#   Reduction+B2 (6): F-RFC041-{SOFTMAX,RMSNORM}-ROWS-EQ,
#                     F-RFC041-RMSNORM-BWD-ROWS-EQ, F-RFC041-ADAMW-EQ,
#                     F-RFC041-MATMUL-T-EQ (cuBLAS Dgemm reshape),
#                     F-RFC041-OUTER-EXACT (K=1 no-reduction), F-RFC041-DETERMINISM
#
# Hardware: A100/H100/H200 (sm_80+ adequate; -arch=sm_80 portable).
# Budget: $1 max — single fire ~$0.30 expected (5 min compile + run).
#
# Watchdog (g_fire_dispatch_robust):
#   - SAVE_POD=1 retain on partial pull
#   - scp ≥3 retry per artifact
#   - explicit destroy after all pulls OK
#   - trap cleanup for INT/TERM/EXIT

set -uo pipefail

PHASE_ID="forge_phase4d_5_3_2026_05_17"
LOCAL_DIR="/Users/ghost/core/hexa-lang/state/forge_phase4d_5_3_2026_05_17"
REPO_ROOT="/Users/ghost/core/hexa-lang/.claude/worktrees/agent-a790090e00be4316b"
SRC_CUDA="$REPO_ROOT/self/cuda/runtime_cuda.c"
SRC_ELEM="$REPO_ROOT/tool/cuda_test_farr_elementwise.cu"
SRC_RED="$REPO_ROOT/tool/cuda_test_farr_reduction.cu"
PHASE_LABEL="forge-phase4d-5-3-cuda-host-byteeq"
REMOTE_WORK="/workspace/forge_phase4d_5_3"

VAST_SSH_KEY="/Users/ghost/.vast/ssh/vast-key"
VASTAI="/Users/ghost/Library/Python/3.14/bin/vastai"
[ -x "$VASTAI" ]      || { echo "ERROR: vastai CLI not found at $VASTAI"; exit 1; }
[ -f "$VAST_SSH_KEY" ] || { echo "ERROR: vast ssh key missing"; exit 1; }
[ -f "$SRC_CUDA" ]    || { echo "ERROR: $SRC_CUDA missing"; exit 1; }
[ -f "$SRC_ELEM" ]    || { echo "ERROR: $SRC_ELEM missing"; exit 1; }
[ -f "$SRC_RED" ]     || { echo "ERROR: $SRC_RED missing"; exit 1; }

mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR"
echo "=== ${PHASE_ID} vast.ai dispatch (Phase 4-D-5-3 CUDA byte-eq fire, $(date -u +%Y-%m-%d)) ==="
date -u

# ── 1) Search cheapest A100/H100/H200 ─────────────────────────────────
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
  nvidia-smi --query-gpu=name,compute_cap,memory.total,driver_version --format=csv,noheader
  echo '---'
  nvcc --version | head -5
  echo '---'
  ls /usr/local/cuda/include/cublas_v2.h && echo 'cublas_v2.h PRESENT'
  ls /usr/local/cuda/lib64/libcublas.so* 2>/dev/null | head -3
  mkdir -p $REMOTE_WORK
  echo 'TOOLCHAIN_OK'" 2>&1 | tee remote_sanity.log

# Extract compute_cap to drive -arch
DEV_CC=$($SSH_CMD 'nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d "."' 2>/dev/null || echo "80")
[ -z "$DEV_CC" ] && DEV_CC=80
echo "  Device compute cap: sm_${DEV_CC}"
echo "$DEV_CC" > device_cc.txt

# ── 5) Upload sources ─────────────────────────────────────────────────
echo "[5/9] Upload runtime_cuda.c + both harness .cu files ..."
$SCP_CMD "$SRC_CUDA" "root@$SSH_HOST:$REMOTE_WORK/runtime_cuda.c"
$SCP_CMD "$SRC_ELEM" "root@$SSH_HOST:$REMOTE_WORK/cuda_test_farr_elementwise.cu"
$SCP_CMD "$SRC_RED"  "root@$SSH_HOST:$REMOTE_WORK/cuda_test_farr_reduction.cu"

# ── 6) Build + run both harnesses ─────────────────────────────────────
echo "[6/9] Build + run both harnesses on sm_${DEV_CC} ..."

# Build 1: elementwise (self-contained, no runtime_cuda.c link)
# Build 2: reduction (links runtime_cuda.c via -x cu C++ compile)
$SSH_CMD "cd $REMOTE_WORK && \
    echo '=== BUILD ELEM ===' ; \
    nvcc -O2 -std=c++14 -gencode arch=compute_${DEV_CC},code=sm_${DEV_CC} \
        cuda_test_farr_elementwise.cu \
        -lcudart -lm -o test_elem 2>&1 | tee build_elem.log ; \
    BUILD_ELEM_RC=\${PIPESTATUS[0]} ; \
    echo \"BUILD_ELEM_RC=\$BUILD_ELEM_RC\" ; \
    echo '=== BUILD RED ===' ; \
    nvcc -O2 -std=c++14 -DHEXA_CUDA -gencode arch=compute_${DEV_CC},code=sm_${DEV_CC} \
        -x cu runtime_cuda.c \
        cuda_test_farr_reduction.cu \
        -lcublas -lcudart -lm -o test_red 2>&1 | tee build_red.log ; \
    BUILD_RED_RC=\${PIPESTATUS[0]} ; \
    echo \"BUILD_RED_RC=\$BUILD_RED_RC\" ; \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_pre.csv ; \
    echo '=== FIRE ELEM ===' ; \
    if [ \"\$BUILD_ELEM_RC\" = '0' ]; then \
      ./test_elem 2>&1 | tee fire_elem.log ; \
      FIRE_ELEM_RC=\${PIPESTATUS[0]} ; \
      echo \"FIRE_ELEM_RC=\$FIRE_ELEM_RC\" ; \
    else \
      echo 'BUILD ELEM FAILED — skipping fire' ; FIRE_ELEM_RC=255 ; \
    fi ; \
    echo '=== FIRE RED ===' ; \
    if [ \"\$BUILD_RED_RC\" = '0' ]; then \
      ./test_red 2>&1 | tee fire_red.log ; \
      FIRE_RED_RC=\${PIPESTATUS[0]} ; \
      echo \"FIRE_RED_RC=\$FIRE_RED_RC\" ; \
    else \
      echo 'BUILD RED FAILED — skipping fire' ; FIRE_RED_RC=255 ; \
    fi ; \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_post.csv ; \
    nvidia-smi --query-gpu=name,compute_cap,memory.total,driver_version --format=csv,noheader > nvidia_smi_device.csv ; \
    echo \"=== SUMMARY === BUILD_ELEM_RC=\$BUILD_ELEM_RC BUILD_RED_RC=\$BUILD_RED_RC FIRE_ELEM_RC=\$FIRE_ELEM_RC FIRE_RED_RC=\$FIRE_RED_RC\"" 2>&1 | tee dispatch.log

# ── 7) Pull artifacts with retry ──────────────────────────────────────
echo "[7/9] Pull artifacts ..."
SAVE_POD=1  # retain by default until all pulls succeed

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
pull_with_retry "$REMOTE_WORK/build_elem.log"     "$LOCAL_DIR/build_elem.log"     || PULL_OK=0
pull_with_retry "$REMOTE_WORK/build_red.log"      "$LOCAL_DIR/build_red.log"      || PULL_OK=0
pull_with_retry "$REMOTE_WORK/fire_elem.log"      "$LOCAL_DIR/fire_elem.log"      || true
pull_with_retry "$REMOTE_WORK/fire_red.log"       "$LOCAL_DIR/fire_red.log"       || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_pre.csv" "$LOCAL_DIR/nvidia_smi_pre.csv" || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_post.csv" "$LOCAL_DIR/nvidia_smi_post.csv" || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_device.csv" "$LOCAL_DIR/nvidia_smi_device.csv" || true

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

# ── 9) Summary ────────────────────────────────────────────────────────
echo "[9/9] === ${PHASE_ID} DONE ==="
date -u
echo "GPU: $OFFER_GPU sm_${DEV_CC}  Rate: \$${OFFER_DPH}/hr"
echo ""
if [ -f "$LOCAL_DIR/fire_elem.log" ]; then
    echo "--- ELEMENTWISE FIRE TAIL ---"
    tail -20 "$LOCAL_DIR/fire_elem.log"
fi
echo ""
if [ -f "$LOCAL_DIR/fire_red.log" ]; then
    echo "--- REDUCTION/B2 FIRE TAIL ---"
    tail -25 "$LOCAL_DIR/fire_red.log"
fi
echo ""
echo "DONE — artifacts: $LOCAL_DIR/"
