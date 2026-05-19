#!/bin/bash
# tool/dispatch_agtape_d768_fire.sh — gap(d) MEASURED generic-path
# d768·12L GPU wall fire (the heavy fire the Stop hook demands).
#
# Ships the codegenned GENERIC ag_tape trainer
# (build/artifacts/flame_d768_agtape.c — _agt_decoder_step path, RoPE
# forge-wired) + self/runtime.c + self/cuda/runtime_cuda.c (RoPE kernel
# fixed __dmul_rn/__dadd_rn, non-FMA, byte-eq to reference) + native deps
# + corpus. Builds -DHEXA_CUDA on A100, runs with nvidia-smi monitor,
# captures per-step wall + GPU util, pulls, destroys pod.
#
# Falsifiers:
#   F-RFC046-AGTAPE-WALL    step-1 wall <= 437.9s (= 1.3x of 336.85s
#                           eager-PyTorch; hand-fused cleared at 191-268s)
#   F-RFC046-AGTAPE-GPU-UTIL  nvidia-smi >50% util (forge kernels engaged
#                           on the GENERIC path, not CPU-bound)
#
# Adapted verbatim (provisioning + robust watchdog) from
# tool/dispatch_phase4d7_gpu_fire.sh; only TRAINER_C + build cmds +
# falsifier labels changed (standard hexa build + CUDA, not the d7
# #include-runtime.c surgical artifact). User pre-approved all GPU fires
# (cost-no-object directive 2026-05-18).

set -uo pipefail

PHASE_ID="agtape_d768_fire_2026_05_18"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${REPO_ROOT}/state/${PHASE_ID}"

TRAINER_C="${REPO_ROOT}/build/artifacts/flame_d768_agtape.c"
RUNTIME_C="${REPO_ROOT}/self/runtime.c"
RUNTIME_HI="${REPO_ROOT}/self/runtime_hi_gen.c"
RUNTIME_CUDA_C="${REPO_ROOT}/self/cuda/runtime_cuda.c"
CORPUS="/Users/ghost/core/anima/training/corpus_consciousness_v1.jsonl"
CORPUS_REMOTE_PATH="/Users/ghost/core/anima/training/corpus_consciousness_v1.jsonl"

PHASE_LABEL="flame-agtape-d768-fire"
REMOTE_WORK="/workspace/agtape_d768"

VAST_SSH_KEY="/Users/ghost/.vast/ssh/vast-key"
VASTAI="/Users/ghost/Library/Python/3.14/bin/vastai"

WALL_BUDGET_SEC=${WALL_BUDGET_SEC:-900}   # generic tape > hand-fused; generous

[ -x "$VASTAI" ]         || { echo "ERROR: vastai not found at $VASTAI"; exit 1; }
[ -f "$VAST_SSH_KEY" ]   || { echo "ERROR: vast ssh key missing"; exit 1; }
[ -f "$TRAINER_C" ]      || { echo "ERROR: trainer .c missing at $TRAINER_C"; exit 1; }
[ -f "$RUNTIME_C" ]      || { echo "ERROR: $RUNTIME_C missing"; exit 1; }
[ -f "$RUNTIME_HI" ]     || { echo "ERROR: $RUNTIME_HI missing"; exit 1; }
[ -f "$RUNTIME_CUDA_C" ] || { echo "ERROR: $RUNTIME_CUDA_C missing"; exit 1; }
[ -f "$CORPUS" ]         || { echo "ERROR: $CORPUS missing"; exit 1; }

mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR"
echo "=== ${PHASE_ID} vast.ai dispatch ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
echo "REPO_ROOT: $REPO_ROOT"
echo ""

# ── 1) Search cheapest A100 ───────────────────────────────────────────
echo "[1/9] Searching A100 offers ..."
OFFER_JSON=$($VASTAI search offers \
    'gpu_name in [A100,A100_SXM4,A100_PCIE,A100X] num_gpus=1 rentable=true dph_total<3.0 cuda_max_good>=12.4 disk_space>40 reliability>0.985 inet_down>200' \
    -o 'dph_total' --raw 2>&1)
OFFER_PARSED=$(echo "$OFFER_JSON" | python3 -c "
import json,sys,os
try: d=json.load(sys.stdin)
except: sys.stderr.write('parse_err\n'); sys.exit(1)
# Allow blacklisting bad hosts that pass the search filter but fail
# the GPU preflight (env-var, comma-separated id list).
bad = set(s.strip() for s in os.environ.get('VAST_BAD_OFFERS','').split(',') if s.strip())
d = [x for x in d if str(x['id']) not in bad]
if not d: sys.stderr.write('no_offers\n'); sys.exit(1)
b=d[0]
print('%s %.4f %s' % (b['id'], b['dph_total'], b['gpu_name'].replace(' ','_')))
")
OFFER_ID=$(echo "$OFFER_PARSED" | awk '{print $1}')
OFFER_DPH=$(echo "$OFFER_PARSED" | awk '{print $2}')
OFFER_GPU=$(echo "$OFFER_PARSED" | awk '{print $3}')
[ -z "$OFFER_ID" ] && { echo "ERROR: no offer: $OFFER_JSON"; exit 1; }
echo "  Selected: id=$OFFER_ID dph=\$$OFFER_DPH gpu=$OFFER_GPU"
echo "$OFFER_ID" > offer_id.txt; echo "$OFFER_DPH" > offer_dph.txt

# ── 2) Rent ───────────────────────────────────────────────────────────
echo "[2/9] Renting instance ..."
CREATE_OUT=$($VASTAI create instance "$OFFER_ID" \
    --image nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 \
    --disk 40 --ssh --direct --label "$PHASE_LABEL" --raw 2>&1)
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
        echo "[cleanup] SAVE_POD=1 — keep $INSTANCE_ID (rc=$rc)"
        echo "[cleanup] manual destroy: $VASTAI destroy instance $INSTANCE_ID"
    else
        echo "[cleanup] Destroying $INSTANCE_ID (exit=$rc)..."
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
                echo "  SSH ready: $SSH_HOST:$SSH_PORT (after ${i}x5s)"; break
            fi
            SSH_HOST=""
        fi
    fi
    echo "  ... attempt $i/160 status=$STATUS"; sleep 5
done
[ -z "$SSH_HOST" ] && { echo "ERROR: SSH not ready"; SAVE_POD=1; exit 1; }
echo "$SSH_HOST:$SSH_PORT" > vast_ssh.txt
SSH_OPTS="-i $VAST_SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60"
SSH_CMD="ssh $SSH_OPTS -p $SSH_PORT root@$SSH_HOST"
SCP_CMD="scp $SSH_OPTS -P $SSH_PORT -o ConnectTimeout=3600"

# ── 4) Toolchain sanity ───────────────────────────────────────────────
echo "[4/9] Remote toolchain sanity ..."
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

# ── 4.5) GPU-HEALTH PREFLIGHT (cudaMalloc smoke) ─────────────────────
# Fire #1 (2026-05-18) wasted a full build+900s cycle on an A100_PCIE
# pod whose GPU returned "cudaMalloc ... device busy or unavailable"
# for every alloc (util 0-1%, 0 steps). Catch a dud GPU in ~5s here
# (compile+run a trivial cudaMalloc/cudaFree) BEFORE the heavy build;
# abort on failure so the EXIT trap destroys the pod and a re-launch
# picks a fresh offer.
echo "[4.5/9] GPU-health preflight (cudaMalloc smoke) ..."
GPU_OK=$($SSH_CMD "cat > /tmp/g.cu <<'EOF'
#include <cstdio>
#include <cuda_runtime.h>
int main(){double*p=0;cudaError_t e=cudaMalloc(&p,(size_t)786432*sizeof(double));
if(e!=cudaSuccess){printf(\"GPU_BAD %s\\n\",cudaGetErrorString(e));return 1;}
cudaFree(p);printf(\"GPU_OK\\n\");return 0;}
EOF
nvcc -arch=sm_${DEV_CC} -O0 -o /tmp/g /tmp/g.cu 2>/tmp/g.berr && /tmp/g 2>&1 || cat /tmp/g.berr" 2>&1 | tee gpu_preflight.log | tail -1)
if ! echo "$GPU_OK" | grep -q GPU_OK; then
    echo "  [PREFLIGHT FAIL] GPU unusable on this pod ($GPU_OK) — aborting; re-launch picks a fresh offer"
    SAVE_POD=0
    exit 3
fi
echo "  GPU preflight OK"

# ── 5) Upload sources ─────────────────────────────────────────────────
echo "[5/9] Upload trainer.c + runtime.c + runtime_hi_gen.c + runtime_cuda.c + native + corpus ..."
$SCP_CMD "$TRAINER_C"      "root@$SSH_HOST:$REMOTE_WORK/trainer.c"
$SCP_CMD "$RUNTIME_C"      "root@$SSH_HOST:$REMOTE_WORK/self/runtime.c"
$SCP_CMD "$RUNTIME_HI"     "root@$SSH_HOST:$REMOTE_WORK/self/runtime_hi_gen.c"
$SCP_CMD "$RUNTIME_CUDA_C" "root@$SSH_HOST:$REMOTE_WORK/self/cuda/runtime_cuda.c"
$SCP_CMD "${REPO_ROOT}/self/runtime.h" "root@$SSH_HOST:$REMOTE_WORK/self/runtime.h"
# RFC 050: runtime.c #includes forge/forge_tier_v1.c (the dispatcher) —
# ship it + its header so the unconditional include resolves on the pod.
$SCP_CMD "${REPO_ROOT}/self/forge/forge_tier_v1.c" "root@$SSH_HOST:$REMOTE_WORK/self/forge/forge_tier_v1.c"
$SCP_CMD "${REPO_ROOT}/self/forge/forge_tier_v1.h" "root@$SSH_HOST:$REMOTE_WORK/self/forge/forge_tier_v1.h"
$SCP_CMD -r "${REPO_ROOT}/self/native/"*.c "root@$SSH_HOST:$REMOTE_WORK/self/native/"
$SCP_CMD -r "${REPO_ROOT}/self/native/"*.h "root@$SSH_HOST:$REMOTE_WORK/self/native/" 2>/dev/null || true
CORPUS_REMOTE_DIR=$(dirname "$CORPUS_REMOTE_PATH")
$SSH_CMD "mkdir -p '$CORPUS_REMOTE_DIR'"
$SCP_CMD "$CORPUS" "root@$SSH_HOST:$CORPUS_REMOTE_PATH"
$SSH_CMD "ls -lh '$CORPUS_REMOTE_PATH'"

# ── 6) Build (nvcc CUDA TU + clang trainer.c+runtime.c) + run ─────────
echo "[6/9] Build + run on sm_${DEV_CC} ..."
$SSH_CMD "cd $REMOTE_WORK && \
    echo '=== nvcc compile runtime_cuda.c ===' ; \
    nvcc -O2 -std=c++14 -DHEXA_CUDA -arch=sm_${DEV_CC} \
        -x cu -c self/cuda/runtime_cuda.c -o runtime_cuda.o 2>&1 | tee build_cuda.log ; \
    BCU=\${PIPESTATUS[0]} ; echo BUILD_CUDA_RC=\$BCU ; \
    echo '=== clang compile+link trainer.c + runtime.c (-DHEXA_CUDA) ===' ; \
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
        nohup bash -c '(while [ ! -f trainer.done ]; do nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used --format=csv,noheader >> nvidia_smi_during.csv; sleep 2; done) & SMI=\$!; S=\$(date +%s); timeout ${WALL_BUDGET_SEC} ./trainer > trainer.out 2> trainer.err; R=\$?; E=\$(date +%s); echo trainer_rc=\$R > trainer_meta.txt; echo wall_seconds=\$((E-S)) >> trainer_meta.txt; touch trainer.done; kill \$SMI 2>/dev/null' >/dev/null 2>&1 & disown ; \
        sleep 3 ; echo 'trainer launched detached' ; \
    else echo 'BUILD FAILED — skipping fire' ; echo 'trainer_rc=-1' > trainer_meta.txt ; echo 'wall_seconds=0' >> trainer_meta.txt ; touch trainer.done ; fi ; \
    echo \"SUMMARY BUILD_CUDA_RC=\$BCU BUILD_LINK_RC=\$BLK\"" 2>&1 | tee dispatch.log

# ── 6.5) Poll until trainer.done ──────────────────────────────────────
echo "[6.5/9] Poll until done (max $((WALL_BUDGET_SEC + 240))s) ..."
POLL_DEADLINE=$(( $(date +%s) + WALL_BUDGET_SEC + 240 ))
POLL_SSH="ssh -i $VAST_SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -p $SSH_PORT root@$SSH_HOST"
while [ "$(date +%s)" -lt "$POLL_DEADLINE" ]; do
    DONE=$($POLL_SSH "cd $REMOTE_WORK && ( [ -f trainer.done ] && echo Y )" 2>/dev/null | tail -1)
    if [ "$DONE" = "Y" ]; then echo "  trainer.done detected"; break; fi
    STEPLINE=$($POLL_SSH "cd $REMOTE_WORK && tail -1 trainer.out 2>/dev/null" 2>/dev/null | tail -1)
    echo "  ... polling ($(( (POLL_DEADLINE - $(date +%s)) ))s left) last: ${STEPLINE:-<no output>}"
    sleep 30
done
$POLL_SSH "cd $REMOTE_WORK && nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_post.csv; echo '=== meta ==='; cat trainer_meta.txt 2>/dev/null; echo '=== out HEAD ==='; head -40 trainer.out 2>/dev/null; echo '=== out TAIL ==='; tail -25 trainer.out 2>/dev/null; echo '=== err TAIL ==='; tail -20 trainer.err 2>/dev/null" 2>&1 | tee -a dispatch.log

# ── 7) Pull artifacts ─────────────────────────────────────────────────
echo "[7/9] Pull artifacts ..."
SAVE_POD=1
pull_with_retry() {
    local src="$1" dst="$2" tries=0
    while [ $tries -lt 3 ]; do
        if $SCP_CMD "root@$SSH_HOST:$src" "$dst" 2>&1; then echo "  pulled $src"; return 0; fi
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

# ── 8) Destroy ────────────────────────────────────────────────────────
echo "[8/9] Pod lifecycle ..."
if [ $PULL_OK -eq 1 ]; then
    $VASTAI destroy instance "$INSTANCE_ID" 2>&1 | head -3 || true
    SAVE_POD=0
else
    echo "  [WARN] partial pull — pod RETAINED: ssh -i $VAST_SSH_KEY -p $SSH_PORT root@$SSH_HOST"
fi

# ── 9) Summary + verdict ──────────────────────────────────────────────
echo "[9/9] === ${PHASE_ID} DONE === GPU=$OFFER_GPU \$${OFFER_DPH}/hr"
[ -f "$LOCAL_DIR/trainer_meta.txt" ] && { echo "--- META ---"; cat "$LOCAL_DIR/trainer_meta.txt"; }
if [ -f "$LOCAL_DIR/trainer.out" ]; then
    echo "--- trainer.out TAIL ---"; tail -25 "$LOCAL_DIR/trainer.out"
fi
if [ -f "$LOCAL_DIR/nvidia_smi_during.csv" ]; then
    echo "--- GPU util max ---"
    awk -F',' '{gsub(/%/,"");gsub(/ /,""); if($2+0>m)m=$2+0} END{print m"%"}' "$LOCAL_DIR/nvidia_smi_during.csv"
fi
echo ""
echo "F-RFC046-AGTAPE-WALL gate: step-1 wall vs 437.9s (PyTorch 336.85s; hand-fused 191-268s)"
echo "DONE — artifacts: $LOCAL_DIR/"
