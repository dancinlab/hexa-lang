#!/bin/bash
# tool/dispatch_runpod_agtape_d768.sh — d768 mk2-port verify on RunPod
#
# RunPod-adapted port of tool/dispatch_agtape_d768_fire.sh.
# vast.ai create/ssh/destroy replaced with runpodctl equivalents; build +
# run + pull pipeline identical. Falsifiers + gate unchanged
# (F-RFC046-AGTAPE-WALL step-1 wall <= 437.9s ABSOLUTE — gpu/HANDOFF.md
# retracted the PyTorch ratio, gate is absolute per-step wall now).

set -uo pipefail

PHASE_ID="agtape_d768_runpod_$(date -u +%Y%m%d_%H%M%S)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${REPO_ROOT}/state/${PHASE_ID}"

TRAINER_C="${REPO_ROOT}/build/artifacts/flame_d768_agtape.c"
RUNTIME_C="${REPO_ROOT}/self/runtime.c"
RUNTIME_CORE_C="${REPO_ROOT}/self/runtime_core.c"
RUNTIME_HI="${REPO_ROOT}/self/runtime_hi_gen.c"
RUNTIME_CUDA_C="${REPO_ROOT}/self/cuda/runtime_cuda.c"
CORPUS="/Users/ghost/core/anima/training/corpus_consciousness_v1.jsonl"
CORPUS_REMOTE_PATH="/Users/ghost/core/anima/training/corpus_consciousness_v1.jsonl"

PHASE_LABEL="flame-agtape-d768-runpod"
REMOTE_WORK="/workspace/agtape_d768"

RUNPOD_SSH_KEY="${HOME}/.runpod/ssh/RunPod-Key-Go"
RUNPODCTL="/opt/homebrew/Cellar/runpodctl/2.1.9/bin/runpodctl"
export RUNPOD_API_KEY="$(secret get runpod.api_key 2>/dev/null)"

WALL_BUDGET_SEC=${WALL_BUDGET_SEC:-900}
GPU_ID="${GPU_ID:-NVIDIA A100-SXM4-80GB}"
IMAGE="${IMAGE:-nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04}"

[ -x "$RUNPODCTL" ]      || { echo "ERROR: runpodctl not found at $RUNPODCTL"; exit 1; }
[ -f "$RUNPOD_SSH_KEY" ] || { echo "ERROR: runpod ssh key missing at $RUNPOD_SSH_KEY"; exit 1; }
[ -n "$RUNPOD_API_KEY" ] || { echo "ERROR: RUNPOD_API_KEY empty (secret get failed)"; exit 1; }
[ -f "$TRAINER_C" ]      || { echo "ERROR: trainer .c missing at $TRAINER_C"; exit 1; }
[ -f "$RUNTIME_C" ]      || { echo "ERROR: $RUNTIME_C missing"; exit 1; }
[ -f "$RUNTIME_CORE_C" ] || { echo "ERROR: $RUNTIME_CORE_C missing"; exit 1; }
[ -f "$RUNTIME_HI" ]     || { echo "ERROR: $RUNTIME_HI missing"; exit 1; }
[ -f "$RUNTIME_CUDA_C" ] || { echo "ERROR: $RUNTIME_CUDA_C missing"; exit 1; }
[ -f "$CORPUS" ]         || { echo "ERROR: $CORPUS missing"; exit 1; }

mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR"
echo "=== ${PHASE_ID} runpod dispatch ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
echo "REPO_ROOT: $REPO_ROOT"

# ── 1) Create pod ─────────────────────────────────────────────────────
echo "[1/8] Creating runpod pod (gpu=${GPU_ID}, image=${IMAGE})..."
CREATE_OUT=$($RUNPODCTL pod create \
    --gpu-id "$GPU_ID" \
    --image "$IMAGE" \
    --container-disk-in-gb 40 \
    --volume-in-gb 0 \
    --ssh \
    --name "$PHASE_LABEL" 2>&1)
POD_ID=$(echo "$CREATE_OUT" | python3 -c "
import json,sys
try: d=json.load(sys.stdin); print(d.get('id',''))
except: sys.stderr.write('parse_fail: '+sys.stdin.read()[:300]+'\n'); sys.exit(1)
")
[ -z "$POD_ID" ] && { echo "ERROR: pod create failed: $CREATE_OUT"; exit 1; }
echo "  Pod ID: $POD_ID"
echo "$POD_ID" > pod_id.txt

cleanup() {
    local rc=$?
    if [ "${SAVE_POD:-0}" = "1" ]; then
        echo "[cleanup] SAVE_POD=1 — keep $POD_ID (rc=$rc)"
        echo "[cleanup] manual delete: $RUNPODCTL pod delete $POD_ID"
    else
        echo "[cleanup] Deleting $POD_ID (exit=$rc)..."
        $RUNPODCTL pod delete "$POD_ID" 2>&1 | head -3 || true
    fi
}
trap cleanup EXIT INT TERM

# ── 2) Wait for SSH ───────────────────────────────────────────────────
echo "[2/8] Waiting for SSH (max 13 min)..."
SSH_HOST=""; SSH_PORT=""; SSH_USER="root"
for i in $(seq 1 160); do
    INFO=$($RUNPODCTL pod get "$POD_ID" 2>/dev/null || echo "{}")
    STATUS=$(echo "$INFO" | python3 -c "
import json,sys
try: d=json.load(sys.stdin); print(d.get('desiredStatus','') or d.get('status',''))
except: print('parse_err')" 2>/dev/null)
    if [ "$STATUS" = "RUNNING" ] || [ "$STATUS" = "running" ]; then
        SSH_INFO=$($RUNPODCTL ssh info "$POD_ID" 2>/dev/null || echo "")
        # runpodctl ssh info prints a 'ssh user@host -p PORT -i KEY' line
        SSH_HOST=$(echo "$SSH_INFO" | grep -oE '@[^ ]+' | head -1 | sed 's/^@//')
        SSH_PORT=$(echo "$SSH_INFO" | grep -oE -- '-p [0-9]+' | head -1 | awk '{print $2}')
        if [ -n "$SSH_HOST" ] && [ -n "$SSH_PORT" ]; then
            if ssh -i "$RUNPOD_SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                -o ConnectTimeout=10 -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" 'echo READY' 2>&1 | grep -q READY; then
                echo "  SSH ready: ${SSH_USER}@${SSH_HOST}:${SSH_PORT} (after ${i}x5s)"; break
            fi
            SSH_HOST=""
        fi
    fi
    echo "  ... attempt $i/160 status=$STATUS"; sleep 5
done
[ -z "$SSH_HOST" ] && { echo "ERROR: SSH not ready"; SAVE_POD=1; exit 1; }
echo "${SSH_USER}@${SSH_HOST}:${SSH_PORT}" > pod_ssh.txt
SSH_OPTS="-i $RUNPOD_SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60"
SSH_CMD="ssh $SSH_OPTS -p $SSH_PORT ${SSH_USER}@${SSH_HOST}"
SCP_CMD="scp $SSH_OPTS -P $SSH_PORT -o ConnectTimeout=3600"

# ── 3) Toolchain sanity + GPU preflight ──────────────────────────────
echo "[3/8] Remote toolchain sanity + GPU preflight..."
$SSH_CMD "set +e
  nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv,noheader
  nvcc --version | tail -2
  which clang || (apt update >/dev/null 2>&1 && apt install -y clang >/dev/null 2>&1 && which clang)
  ls /usr/local/cuda/include/cublas_v2.h && echo cublas_PRESENT
  mkdir -p $REMOTE_WORK/self/cuda $REMOTE_WORK/self/native $REMOTE_WORK/self/forge
  echo TOOLCHAIN_OK" 2>&1 | tee remote_sanity.log
DEV_CC=$($SSH_CMD 'nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d "."' 2>/dev/null || echo "80")
[ -z "$DEV_CC" ] && DEV_CC=80
echo "  Device compute cap: sm_${DEV_CC}"

GPU_OK=$($SSH_CMD "cat > /tmp/g.cu <<'EOF'
#include <cstdio>
#include <cuda_runtime.h>
int main(){double*p=0;cudaError_t e=cudaMalloc(&p,(size_t)786432*sizeof(double));
if(e!=cudaSuccess){printf(\"GPU_BAD %s\\n\",cudaGetErrorString(e));return 1;}
cudaFree(p);printf(\"GPU_OK\\n\");return 0;}
EOF
nvcc -arch=sm_${DEV_CC} -O0 -o /tmp/g /tmp/g.cu 2>/tmp/g.berr && /tmp/g 2>&1 || cat /tmp/g.berr" 2>&1 | tee gpu_preflight.log | tail -1)
if ! echo "$GPU_OK" | grep -q GPU_OK; then
    echo "  [PREFLIGHT FAIL] GPU unusable ($GPU_OK) — aborting"; SAVE_POD=0; exit 3
fi
echo "  GPU preflight OK"

# ── 4) Upload sources ─────────────────────────────────────────────────
echo "[4/8] Upload trainer.c + runtime files + native + forge + corpus..."
$SCP_CMD "$TRAINER_C"      "${SSH_USER}@${SSH_HOST}:$REMOTE_WORK/trainer.c"
$SCP_CMD "$RUNTIME_C"      "${SSH_USER}@${SSH_HOST}:$REMOTE_WORK/self/runtime.c"
$SCP_CMD "${REPO_ROOT}/self/runtime.h" "${SSH_USER}@${SSH_HOST}:$REMOTE_WORK/self/runtime.h"
$SCP_CMD "$RUNTIME_CORE_C" "${SSH_USER}@${SSH_HOST}:$REMOTE_WORK/self/runtime_core.c"
$SCP_CMD "$RUNTIME_HI"     "${SSH_USER}@${SSH_HOST}:$REMOTE_WORK/self/runtime_hi_gen.c"
$SCP_CMD "$RUNTIME_CUDA_C" "${SSH_USER}@${SSH_HOST}:$REMOTE_WORK/self/cuda/runtime_cuda.c"
$SCP_CMD "${REPO_ROOT}/self/cuda/runtime_bf16.c" "${SSH_USER}@${SSH_HOST}:$REMOTE_WORK/self/cuda/runtime_bf16.c"
$SCP_CMD "${REPO_ROOT}/self/forge/forge_tier_v1.c" "${SSH_USER}@${SSH_HOST}:$REMOTE_WORK/self/forge/forge_tier_v1.c"
$SCP_CMD "${REPO_ROOT}/self/forge/forge_tier_v1.h" "${SSH_USER}@${SSH_HOST}:$REMOTE_WORK/self/forge/forge_tier_v1.h"
$SCP_CMD -r "${REPO_ROOT}/self/native/"*.c "${SSH_USER}@${SSH_HOST}:$REMOTE_WORK/self/native/"
$SCP_CMD -r "${REPO_ROOT}/self/native/"*.h "${SSH_USER}@${SSH_HOST}:$REMOTE_WORK/self/native/" 2>/dev/null || true
CORPUS_REMOTE_DIR=$(dirname "$CORPUS_REMOTE_PATH")
$SSH_CMD "mkdir -p '$CORPUS_REMOTE_DIR'"
$SCP_CMD "$CORPUS" "${SSH_USER}@${SSH_HOST}:$CORPUS_REMOTE_PATH"
$SSH_CMD "ls -lh '$CORPUS_REMOTE_PATH'"

# ── 5) Build + run ────────────────────────────────────────────────────
echo "[5/8] Build + run on sm_${DEV_CC}..."
$SSH_CMD "cd $REMOTE_WORK && \
    echo '=== nvcc compile runtime_cuda.c ===' ; \
    nvcc -O2 -std=c++14 -DHEXA_CUDA -arch=sm_${DEV_CC} \
        -x cu -c self/cuda/runtime_cuda.c -o runtime_cuda.o 2>&1 | tee build_cuda.log ; \
    BCU=\${PIPESTATUS[0]} ; echo BUILD_CUDA_RC=\$BCU ; \
    echo '=== clang link trainer.c + runtime.c (-DHEXA_CUDA) ===' ; \
    clang -O2 -D_GNU_SOURCE -D_XOPEN_SOURCE=600 -DHEXA_CUDA \
        -I self -I /usr/local/cuda/include -Wno-trigraphs -fbracket-depth=4096 \
        trainer.c self/runtime.c runtime_cuda.o \
        -L/usr/local/cuda/lib64 -lcublas -lcudart -lcudart_static -ldl -lrt \
        -lm -lpthread -lstdc++ -o trainer 2>&1 | tee build_link.log ; \
    BLK=\${PIPESTATUS[0]} ; echo BUILD_LINK_RC=\$BLK ; \
    if [ -f trainer ]; then ls -lh trainer ; fi ; \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_pre.csv ; \
    if [ \"\$BLK\" = '0' ]; then \
        rm -f trainer.done trainer.out trainer.err trainer_meta.txt nvidia_smi_during.csv ; \
        nohup bash -c '(while [ ! -f trainer.done ]; do nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used --format=csv,noheader >> nvidia_smi_during.csv; sleep 2; done) & SMI=\$!; S=\$(date +%s); timeout ${WALL_BUDGET_SEC} ./trainer > trainer.out 2> trainer.err; R=\$?; E=\$(date +%s); echo trainer_rc=\$R > trainer_meta.txt; echo wall_seconds=\$((E-S)) >> trainer_meta.txt; touch trainer.done' > nohup.out 2>&1 & \
        sleep 3 ; echo 'trainer launched detached' ; \
    else echo 'BUILD FAILED' ; echo 'trainer_rc=-1' > trainer_meta.txt ; echo 'wall_seconds=0' >> trainer_meta.txt ; touch trainer.done ; fi ; \
    echo \"SUMMARY BUILD_CUDA_RC=\$BCU BUILD_LINK_RC=\$BLK\"" 2>&1 | tee dispatch.log

# ── 6) Poll until done ────────────────────────────────────────────────
echo "[6/8] Poll until done (max $((WALL_BUDGET_SEC + 240))s)..."
POLL_DEADLINE=$(( $(date +%s) + WALL_BUDGET_SEC + 240 ))
POLL_SSH="ssh -i $RUNPOD_SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -p $SSH_PORT ${SSH_USER}@${SSH_HOST}"
while [ "$(date +%s)" -lt "$POLL_DEADLINE" ]; do
    DONE=$($POLL_SSH "cd $REMOTE_WORK && ( [ -f trainer.done ] && echo Y )" 2>/dev/null | tail -1)
    if [ "$DONE" = "Y" ]; then echo "  trainer.done detected"; break; fi
    STEPLINE=$($POLL_SSH "cd $REMOTE_WORK && tail -1 trainer.out 2>/dev/null" 2>/dev/null | tail -1)
    echo "  ... polling ($(( (POLL_DEADLINE - $(date +%s)) ))s left) last: ${STEPLINE:-<no output>}"
    sleep 30
done
$POLL_SSH "cd $REMOTE_WORK && nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_post.csv; echo '=== meta ==='; cat trainer_meta.txt 2>/dev/null; echo '=== out HEAD ==='; head -40 trainer.out 2>/dev/null; echo '=== out TAIL ==='; tail -25 trainer.out 2>/dev/null; echo '=== err TAIL ==='; tail -20 trainer.err 2>/dev/null" 2>&1 | tee -a dispatch.log

# ── 7) Pull artifacts ─────────────────────────────────────────────────
echo "[7/8] Pull artifacts..."
SAVE_POD=1
pull_with_retry() {
    local src="$1" dst="$2" tries=0
    while [ $tries -lt 3 ]; do
        if $SCP_CMD "${SSH_USER}@${SSH_HOST}:$src" "$dst" 2>&1; then echo "  pulled $src"; return 0; fi
        tries=$((tries+1)); echo "  ... retry $tries/3 $src"; [ $tries -lt 3 ] && sleep 15
    done
    echo "  pull FAILED: $src"; return 1
}
PULL_OK=1
pull_with_retry "$REMOTE_WORK/build_cuda.log"        "$LOCAL_DIR/build_cuda.log"        || PULL_OK=0
pull_with_retry "$REMOTE_WORK/build_link.log"        "$LOCAL_DIR/build_link.log"        || PULL_OK=0
pull_with_retry "$REMOTE_WORK/trainer.out"           "$LOCAL_DIR/trainer.out"           || true
pull_with_retry "$REMOTE_WORK/trainer.err"           "$LOCAL_DIR/trainer.err"           || true
pull_with_retry "$REMOTE_WORK/trainer_meta.txt"      "$LOCAL_DIR/trainer_meta.txt"      || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_pre.csv"    "$LOCAL_DIR/nvidia_smi_pre.csv"    || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_post.csv"   "$LOCAL_DIR/nvidia_smi_post.csv"   || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_during.csv" "$LOCAL_DIR/nvidia_smi_during.csv" || true

# ── 8) Delete + summary ───────────────────────────────────────────────
echo "[8/8] Pod lifecycle..."
if [ $PULL_OK -eq 1 ]; then
    $RUNPODCTL pod delete "$POD_ID" 2>&1 | head -3 || true
    SAVE_POD=0
else
    echo "  [WARN] partial pull — pod RETAINED: ssh -i $RUNPOD_SSH_KEY -p $SSH_PORT ${SSH_USER}@${SSH_HOST}"
fi

echo "=== ${PHASE_ID} DONE === gpu=${GPU_ID}"
[ -f "$LOCAL_DIR/trainer_meta.txt" ] && { echo "--- META ---"; cat "$LOCAL_DIR/trainer_meta.txt"; }
if [ -f "$LOCAL_DIR/trainer.out" ]; then
    echo "--- trainer.out TAIL ---"; tail -25 "$LOCAL_DIR/trainer.out"
fi
if [ -f "$LOCAL_DIR/nvidia_smi_during.csv" ]; then
    echo "--- GPU util max ---"
    awk -F',' '{gsub(/%/,"");gsub(/ /,""); if($2+0>m)m=$2+0} END{print m"%"}' "$LOCAL_DIR/nvidia_smi_during.csv"
fi
echo ""
echo "F-RFC046-AGTAPE-WALL gate: step-1 wall vs 437.9s ABSOLUTE (gpu/HANDOFF.md retracted PyTorch ratio)"
echo "DONE — artifacts: $LOCAL_DIR/"
