#!/bin/bash
# tool/dispatch_phase4d_5_4.sh — flame Phase 4-D-5-4 step 2 A100 fire
#
# Goal: First end-to-end CUDA-enabled flame d768·12L corpus_test fire.
# Step 1 (commit eeb65fc7) wired 11 _gpu dispatchers in self/runtime.c
# to verified Phase 4-D-5-3 CUDA kernel bodies (11/11 byte-eq PASS).
# This script:
#   1. ships the pre-built Phase 4-D-4 trainer .c artifact
#      (state/flame_phase4d_20260517_102511/flame_d768_12L_corpus_test_a2.c,
#      163KB, identical to what Phase 4-D-4 fired CPU-only)
#   2. ships self/runtime.c + self/cuda/runtime_cuda.c
#   3. builds with -DHEXA_CUDA + -lcublas -lcudart on A100/H100/H200 pod
#   4. runs the trainer with nvidia-smi monitor; captures wall + GPU util
#   5. pulls artifacts, destroys pod
#
# Falsifiers:
#   F-RFC046-EAGER-PYTORCH-MATCH  wall ≤ 437.9s (= 1.3× of 336.85s eager-PyTorch)
#   F-RFC046-GPU-UTILIZATION      nvidia-smi >50% util during run (vs Phase 4-D-4 0%)
#   F-RFC047-A2-PATHB-FULL-BYTE-EQ trainer output byte-eq with CPU baseline
#
# Honest scope caveat:
#   Step 1 wired only the `_gpu` variant dispatchers. The flame source
#   (decoder_block_lib.hexa, nn_lib.hexa) currently calls non-_gpu
#   `farr_matmul` etc. which route to CPU `hexa_farr_matmul`. Source-
#   level routing (step 3) is required for the trainer to actually
#   exercise the GPU path. This fire likely shows 0% GPU util and
#   CPU-bound walltime similar to Phase 4-D-4, confirming the source-
#   routing gap. If so, the fire's value = build-tier integration
#   verification (DOES -DHEXA_CUDA build link cleanly with runtime_cuda.c
#   at trainer scale?) + nvidia-smi anchor proof for next-step priority.
#
# Adapted from:
#   tool/dispatch_phase4d_5_3.sh (Phase 4-D-5-3 kernel byte-eq fire)
#   state/flame_phase4d_20260517_102511/DISPATCH.md (Phase 4-D-4 dispatch)
#
# Watchdog (g_fire_dispatch_robust):
#   - SAVE_POD=1 retain on partial pull
#   - scp ≥3 retry per artifact
#   - explicit destroy after all pulls OK
#   - trap cleanup on INT/TERM/EXIT
#
# Budget: $15 max (user-approved). Single fire ~$1-3 expected
# (A100 ~$0.60-1.50/hr × build+run ~30min).

set -uo pipefail

PHASE_ID="flame_phase4d_5_4_2026_05_17"
REPO_ROOT="/Users/ghost/core/hexa-lang/.claude/worktrees/agent-af7b622570209a02f"
LOCAL_DIR="${REPO_ROOT}/state/${PHASE_ID}"

# Pre-built artifacts from Phase 4-D-4 (reproducible — same .c file)
TRAINER_C="${REPO_ROOT}/state/flame_phase4d_20260517_102511/flame_d768_12L_corpus_test_a2.c"
RUNTIME_C="${REPO_ROOT}/self/runtime.c"
RUNTIME_CUDA_C="${REPO_ROOT}/self/cuda/runtime_cuda.c"
# Trainer hardcodes /Users/ghost/core/anima/training/corpus_consciousness_v1.jsonl —
# we symlink the same path on the pod via mkdir+ln to the uploaded blob.
CORPUS="/Users/ghost/core/anima/training/corpus_consciousness_v1.jsonl"
CORPUS_REMOTE_PATH="/Users/ghost/core/anima/training/corpus_consciousness_v1.jsonl"

PHASE_LABEL="flame-phase4d-5-4-cuda-fire"
REMOTE_WORK="/workspace/flame_phase4d_5_4"

VAST_SSH_KEY="/Users/ghost/.vast/ssh/vast-key"
VASTAI="/Users/ghost/Library/Python/3.14/bin/vastai"

# Wall time gate (F-RFC046)
WALL_BUDGET_SEC=600   # 10 min hard cap (1.4× of F-RFC046 437.9s gate)

# Pre-flight
[ -x "$VASTAI" ]         || { echo "ERROR: vastai CLI not found at $VASTAI"; exit 1; }
[ -f "$VAST_SSH_KEY" ]   || { echo "ERROR: vast ssh key missing at $VAST_SSH_KEY"; exit 1; }
[ -f "$TRAINER_C" ]      || { echo "ERROR: trainer .c missing at $TRAINER_C (Phase 4-D-4 artifact)"; exit 1; }
[ -f "$RUNTIME_C" ]      || { echo "ERROR: $RUNTIME_C missing"; exit 1; }
[ -f "$RUNTIME_CUDA_C" ] || { echo "ERROR: $RUNTIME_CUDA_C missing"; exit 1; }
[ -f "$CORPUS" ]         || { echo "ERROR: $CORPUS missing (trainer hard-requires this path)"; exit 1; }

mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR"
echo "=== ${PHASE_ID} vast.ai dispatch (Phase 4-D-5-4 step 2, $(date -u +%Y-%m-%d)) ==="
date -u
echo "REPO_ROOT: $REPO_ROOT"
echo "LOCAL_DIR: $LOCAL_DIR"
echo ""

# ── 1) Search cheapest A100/H100/H200 ─────────────────────────────────
echo "[1/9] Searching A100/H100/H200 offers (≤\$10/hr, cuda≥12.4, disk≥30) ..."
OFFER_JSON=$($VASTAI search offers \
    'gpu_name in [A100,A100_SXM4,A100_PCIE,A100X,H100_SXM,H100_PCIE,H100_NVL,H100,H200] num_gpus=1 rentable=true dph_total<10.0 cuda_max_good>=12.4 disk_space>30 reliability>0.97 inet_down>200' \
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
  mkdir -p $REMOTE_WORK
  mkdir -p $REMOTE_WORK/self
  mkdir -p $REMOTE_WORK/self/cuda
  echo 'TOOLCHAIN_OK'" 2>&1 | tee remote_sanity.log

# Extract compute_cap to drive -arch
DEV_CC=$($SSH_CMD 'nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d "."' 2>/dev/null || echo "80")
[ -z "$DEV_CC" ] && DEV_CC=80
echo "  Device compute cap: sm_${DEV_CC}"
echo "$DEV_CC" > device_cc.txt

# ── 5) Upload sources ─────────────────────────────────────────────────
echo "[5/9] Upload trainer.c + runtime.c + runtime_cuda.c + 18 #include deps ..."
$SCP_CMD "$TRAINER_C"     "root@$SSH_HOST:$REMOTE_WORK/flame_d768_12L_corpus_test_a2.c"
$SCP_CMD "$RUNTIME_C"     "root@$SSH_HOST:$REMOTE_WORK/self/runtime.c"
$SCP_CMD "$RUNTIME_CUDA_C" "root@$SSH_HOST:$REMOTE_WORK/self/cuda/runtime_cuda.c"
# runtime.c #include's runtime_hi_gen.c (generated, committed) + 17 native/*.c
$SCP_CMD "${REPO_ROOT}/self/runtime_hi_gen.c" "root@$SSH_HOST:$REMOTE_WORK/self/runtime_hi_gen.c"
$SSH_CMD "mkdir -p $REMOTE_WORK/self/native"
$SCP_CMD -r "${REPO_ROOT}/self/native/"*.c "root@$SSH_HOST:$REMOTE_WORK/self/native/"
$SCP_CMD -r "${REPO_ROOT}/self/native/"*.h "root@$SSH_HOST:$REMOTE_WORK/self/native/" 2>/dev/null || true

# Trainer hardcodes the Mac-side corpus path; recreate the same path on the pod.
echo "  symlinking corpus to trainer-expected path on pod: $CORPUS_REMOTE_PATH"
CORPUS_REMOTE_DIR=$(dirname "$CORPUS_REMOTE_PATH")
$SSH_CMD "mkdir -p '$CORPUS_REMOTE_DIR'"
$SCP_CMD "$CORPUS" "root@$SSH_HOST:$CORPUS_REMOTE_PATH"
$SSH_CMD "ls -lh '$CORPUS_REMOTE_PATH'"

# ── 6) Build (split compilation: nvcc for CUDA TU, clang for trainer) ─
echo "[6/9] Build + run on sm_${DEV_CC} ..."

$SSH_CMD "cd $REMOTE_WORK && \
    echo '=== BUILD step 1: nvcc compile runtime_cuda.c ===' ; \
    nvcc -O2 -std=c++14 -DHEXA_CUDA -gencode arch=compute_${DEV_CC},code=sm_${DEV_CC} \
        -x cu -c self/cuda/runtime_cuda.c -o runtime_cuda.o 2>&1 | tee build_cuda.log ; \
    BUILD_CUDA_RC=\${PIPESTATUS[0]} ; \
    echo \"BUILD_CUDA_RC=\$BUILD_CUDA_RC\" ; \
    echo '=== BUILD step 2: clang compile trainer (with runtime.c via #include) ===' ; \
    clang -O2 -D_GNU_SOURCE -D_XOPEN_SOURCE=600 -DHEXA_CUDA \
        -I self -I /usr/local/cuda/include \
        -Wno-trigraphs -c flame_d768_12L_corpus_test_a2.c -o trainer.o 2>&1 | tee build_trainer.log ; \
    BUILD_TRAINER_RC=\${PIPESTATUS[0]} ; \
    echo \"BUILD_TRAINER_RC=\$BUILD_TRAINER_RC\" ; \
    echo '=== BUILD step 3: link ===' ; \
    clang trainer.o runtime_cuda.o \
        -L/usr/local/cuda/lib64 -lcublas -lcudart -lcudart_static -ldl -lrt \
        -lm -lpthread -lstdc++ -o trainer 2>&1 | tee build_link.log ; \
    BUILD_LINK_RC=\${PIPESTATUS[0]} ; \
    echo \"BUILD_LINK_RC=\$BUILD_LINK_RC\" ; \
    if [ -f trainer ]; then ls -lh trainer ; file trainer ; fi ; \
    echo '=== PRE-FIRE nvidia-smi ===' ; \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_pre.csv ; \
    cat nvidia_smi_pre.csv ; \
    echo '=== FIRE: launch trainer + nvidia-smi monitor (parallel) ===' ; \
    if [ \"\$BUILD_LINK_RC\" = '0' ]; then \
        (while [ -f trainer.pid ] || [ ! -f trainer.done ]; do \
            nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used --format=csv,noheader >> nvidia_smi_during.csv ; \
            sleep 1 ; \
        done) & \
        SMI_PID=\$! ; \
        START_NS=\$(date +%s%N) ; \
        echo \"trainer_start_utc=\$(date -u +%FT%TZ)\" > trainer_meta.txt ; \
        timeout ${WALL_BUDGET_SEC}s ./trainer > trainer.out 2> trainer.err & \
        TRAINER_PID=\$! ; \
        echo \$TRAINER_PID > trainer.pid ; \
        wait \$TRAINER_PID ; \
        TRAINER_RC=\$? ; \
        END_NS=\$(date +%s%N) ; \
        WALL_NS=\$((END_NS - START_NS)) ; \
        WALL_S=\$(echo \"scale=3; \$WALL_NS / 1000000000\" | bc) ; \
        echo \"trainer_end_utc=\$(date -u +%FT%TZ)\" >> trainer_meta.txt ; \
        echo \"trainer_rc=\$TRAINER_RC\" >> trainer_meta.txt ; \
        echo \"wall_seconds=\$WALL_S\" >> trainer_meta.txt ; \
        rm -f trainer.pid ; \
        touch trainer.done ; \
        wait \$SMI_PID 2>/dev/null || true ; \
        echo \"=== TRAINER DONE: rc=\$TRAINER_RC wall=\${WALL_S}s ===\" ; \
        echo '=== trainer.out HEAD ===' ; head -30 trainer.out ; \
        echo '=== trainer.out TAIL ===' ; tail -30 trainer.out ; \
        if [ -s trainer.err ]; then echo '=== trainer.err ===' ; tail -20 trainer.err ; fi ; \
    else \
        echo 'BUILD FAILED — skipping fire' ; \
        echo 'wall_seconds=0' > trainer_meta.txt ; \
        echo 'trainer_rc=-1' >> trainer_meta.txt ; \
    fi ; \
    echo '=== POST-FIRE nvidia-smi ===' ; \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_post.csv ; \
    cat nvidia_smi_post.csv ; \
    echo \"=== SUMMARY === BUILD_CUDA_RC=\$BUILD_CUDA_RC BUILD_TRAINER_RC=\$BUILD_TRAINER_RC BUILD_LINK_RC=\$BUILD_LINK_RC\"" 2>&1 | tee dispatch.log

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
pull_with_retry "$REMOTE_WORK/build_cuda.log"      "$LOCAL_DIR/build_cuda.log"      || PULL_OK=0
pull_with_retry "$REMOTE_WORK/build_trainer.log"   "$LOCAL_DIR/build_trainer.log"   || PULL_OK=0
pull_with_retry "$REMOTE_WORK/build_link.log"      "$LOCAL_DIR/build_link.log"      || PULL_OK=0
pull_with_retry "$REMOTE_WORK/trainer.out"         "$LOCAL_DIR/trainer.out"         || true
pull_with_retry "$REMOTE_WORK/trainer.err"         "$LOCAL_DIR/trainer.err"         || true
pull_with_retry "$REMOTE_WORK/trainer_meta.txt"    "$LOCAL_DIR/trainer_meta.txt"    || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_pre.csv"  "$LOCAL_DIR/nvidia_smi_pre.csv"  || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_post.csv" "$LOCAL_DIR/nvidia_smi_post.csv" || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_during.csv" "$LOCAL_DIR/nvidia_smi_during.csv" || true

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
if [ -f "$LOCAL_DIR/trainer_meta.txt" ]; then
    echo "--- TRAINER META ---"
    cat "$LOCAL_DIR/trainer_meta.txt"
fi
echo ""
if [ -f "$LOCAL_DIR/trainer.out" ]; then
    LINES=$(wc -l < "$LOCAL_DIR/trainer.out")
    echo "--- trainer.out ($LINES lines) HEAD ---"
    head -20 "$LOCAL_DIR/trainer.out"
    echo "--- trainer.out TAIL ---"
    tail -20 "$LOCAL_DIR/trainer.out"
fi
echo ""
if [ -f "$LOCAL_DIR/nvidia_smi_during.csv" ]; then
    SMI_LINES=$(wc -l < "$LOCAL_DIR/nvidia_smi_during.csv")
    echo "--- nvidia_smi DURING ($SMI_LINES samples) ---"
    echo "Max GPU util:"
    awk -F',' '{gsub(/%/,""); gsub(/ /,""); if($2+0>max) max=$2+0} END{print max"%"}' "$LOCAL_DIR/nvidia_smi_during.csv"
    echo "Sample first/middle/last:"
    head -1 "$LOCAL_DIR/nvidia_smi_during.csv"
    sed -n "$((SMI_LINES / 2))p" "$LOCAL_DIR/nvidia_smi_during.csv"
    tail -1 "$LOCAL_DIR/nvidia_smi_during.csv"
fi
echo ""
echo "DONE — artifacts: $LOCAL_DIR/"
