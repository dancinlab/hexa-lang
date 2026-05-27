#!/bin/bash
# tool/dispatch_rope_gpu_oracle.sh — gap(d) cheap localized RoPE GPU
# byte-eq oracle (instrument-first, before the heavy generic d768 fire).
#
# WHY
#   gap(d) forge RoPE kernel _hx_cuda_farr_rope_gpu is byte-eq verified
#   on CPU (19/19, FMA pragma c0789e05). The CPU FP_CONTRACT OFF fix does
#   NOT cover the GPU kernel — nvcc contracts host vs device differently.
#   This oracle (tool/cuda_test_farr_rope.cu, self-contained: kernel
#   duplicates mirroring runtime_cuda.c + in-process CPU reference,
#   TOL_EXACT=0.0) answers the GPU-side byte-eq question at a d768-class
#   shape (T=128 nheads=12 hd=64) — sub-second compute, ~$0.20.
#
# Falsifiers (from the .cu): F-RFC041-ROPE-EXACT |Δ|==0,
#                            F-RFC041-ROPE-BWD-EXACT |Δ|==0
#
# Adapted from tool/dispatch_phase4d9_causal_softmax_cuda.sh (same robust
# watchdog: A100-only filter, SAVE_POD on partial pull, scp retry, trap).
# Budget: ~$0.20 (A100 ~$0.20/hr x provision+nvcc ~10min). User
# pre-approved all GPU fires for this campaign (cost no object directive).

set -uo pipefail

PHASE_ID="rope_gpu_oracle_2026_05_18"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${REPO_ROOT}/state/${PHASE_ID}"

ORACLE_CU="${REPO_ROOT}/tool/cuda_test_farr_rope.cu"

PHASE_LABEL="flame-rope-gpu-oracle"
REMOTE_WORK="/workspace/rope_oracle"

VAST_SSH_KEY="/Users/ghost/.vast/ssh/vast-key"
VASTAI="/Users/ghost/Library/Python/3.14/bin/vastai"

RUN_BUDGET_SEC=90

[ -x "$VASTAI" ]       || { echo "ERROR: vastai CLI not found at $VASTAI"; exit 1; }
[ -f "$VAST_SSH_KEY" ] || { echo "ERROR: vast ssh key missing at $VAST_SSH_KEY"; exit 1; }
[ -f "$ORACLE_CU" ]    || { echo "ERROR: $ORACLE_CU missing"; exit 1; }

mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR"
echo "=== ${PHASE_ID} vast.ai dispatch ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
echo "REPO_ROOT: $REPO_ROOT"
echo ""

# ── 1) Search cheapest A100 ───────────────────────────────────────────
echo "[1/8] Searching A100 offers (<=\$3/hr, cuda>=12.4, disk>30) ..."
OFFER_JSON=$($VASTAI search offers \
    'gpu_name in [A100,A100_SXM4,A100_PCIE,A100X] num_gpus=1 rentable=true dph_total<3.0 cuda_max_good>=12.4 disk_space>30 reliability>0.985 inet_down>200' \
    -o 'dph_total' --raw 2>&1)
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
[ -z "$OFFER_ID" ] && { echo "ERROR: no offer parsed: $OFFER_JSON"; exit 1; }
echo "  Selected: id=$OFFER_ID dph=\$$OFFER_DPH gpu=$OFFER_GPU"
echo "$OFFER_ID" > offer_id.txt; echo "$OFFER_DPH" > offer_dph.txt

# ── 2) Rent ───────────────────────────────────────────────────────────
echo "[2/8] Renting instance (cuda:12.4 devel image) ..."
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
echo "[3/8] Waiting for SSH (max 13 min)..."
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

# ── 4) Toolchain sanity + arch ────────────────────────────────────────
echo "[4/8] Remote toolchain sanity ..."
$SSH_CMD "set +e
  nvidia-smi --query-gpu=name,compute_cap,memory.total,driver_version --format=csv,noheader
  nvcc --version | tail -2
  mkdir -p $REMOTE_WORK
  echo 'TOOLCHAIN_OK'" 2>&1 | tee remote_sanity.log
DEV_CC=$($SSH_CMD 'nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d "."' 2>/dev/null || echo "80")
[ -z "$DEV_CC" ] && DEV_CC=80
echo "  Device compute cap: sm_${DEV_CC}"

# ── 5) Upload the self-contained oracle .cu ───────────────────────────
echo "[5/8] Upload cuda_test_farr_rope.cu ..."
$SCP_CMD "$ORACLE_CU" "root@$SSH_HOST:$REMOTE_WORK/cuda_test_farr_rope.cu"

# ── 6) nvcc build + run (default T=128 nheads=12 hd=64 + a d768 shape) ─
echo "[6/8] Build + run oracle on sm_${DEV_CC} ..."
$SSH_CMD "cd $REMOTE_WORK && \
    echo '=== nvcc build ===' ; \
    nvcc -arch=sm_${DEV_CC} -O2 -Xcompiler -ffp-contract=off -o cuda_test_farr_rope cuda_test_farr_rope.cu 2>&1 | tee build.log ; \
    BRC=\${PIPESTATUS[0]} ; echo \"BUILD_RC=\$BRC\" ; \
    if [ \"\$BRC\" = '0' ]; then \
        echo '=== RUN default (T=128 nheads=12 hd=64) ===' ; \
        timeout ${RUN_BUDGET_SEC} ./cuda_test_farr_rope 2>&1 | tee oracle_default.out ; \
        echo \"DEFAULT_RC=\${PIPESTATUS[0]}\" ; \
        echo '=== RUN d768-class (T=1024 nheads=12 hd=64) ===' ; \
        timeout ${RUN_BUDGET_SEC} ./cuda_test_farr_rope 1024 12 64 2>&1 | tee oracle_d768.out ; \
        echo \"D768_RC=\${PIPESTATUS[0]}\" ; \
    else echo 'BUILD FAILED' ; fi" 2>&1 | tee dispatch.log

# ── 7) Pull artifacts ─────────────────────────────────────────────────
echo "[7/8] Pull artifacts ..."
SAVE_POD=1
pull_with_retry() {
    local src="$1" dst="$2" tries=0
    while [ $tries -lt 3 ]; do
        if $SCP_CMD "root@$SSH_HOST:$src" "$dst" 2>&1; then
            echo "  pulled $src"; return 0
        fi
        tries=$((tries+1)); echo "  ... retry $tries/3 $src"; [ $tries -lt 3 ] && sleep 10
    done
    echo "  pull FAILED: $src"; return 1
}
PULL_OK=1
pull_with_retry "$REMOTE_WORK/build.log"          "$LOCAL_DIR/build.log"          || PULL_OK=0
pull_with_retry "$REMOTE_WORK/oracle_default.out" "$LOCAL_DIR/oracle_default.out" || PULL_OK=0
pull_with_retry "$REMOTE_WORK/oracle_d768.out"    "$LOCAL_DIR/oracle_d768.out"    || true

# ── 8) Destroy + verdict ──────────────────────────────────────────────
echo "[8/8] Pod lifecycle + verdict ..."
if [ $PULL_OK -eq 1 ]; then
    $VASTAI destroy instance "$INSTANCE_ID" 2>&1 | head -3 || true
    SAVE_POD=0
else
    echo "  [WARN] partial pull — pod RETAINED: ssh -i $VAST_SSH_KEY -p $SSH_PORT root@$SSH_HOST"
fi
echo ""
echo "=== ${PHASE_ID} DONE === GPU=$OFFER_GPU \$${OFFER_DPH}/hr"
for f in oracle_default.out oracle_d768.out; do
    if [ -f "$LOCAL_DIR/$f" ]; then
        echo "--- $f ---"; cat "$LOCAL_DIR/$f"
        echo "--- verdict ($f) ---"
        grep -E 'F-RFC041-ROPE|ALL-PASS|FAIL' "$LOCAL_DIR/$f" || echo "  (no verdict line)"
    fi
done
echo ""
echo "DONE — artifacts: $LOCAL_DIR/"
