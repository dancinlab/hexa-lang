#!/bin/bash
# dispatch_a_compile.sh — forge Phase R / A: torch.compile baseline expansion fire.
#
# Purpose: re-measure PyTorch baselines using `torch.compile` (Inductor JIT) instead
# of eager-mode, on the SAME hardware as the AOT measurements, so we can compare
# AOT vs (PyTorch eager + PyTorch torch.compile + PyTorch torch.compile(reduce-overhead)).
#
# Existing AOT measurements (do NOT re-fire AOT):
#   Stage 1 MLP   : state/forge_phaseR_a_2026_05_17/result.json         (mnist_b32, mnist_b128, mid_b32)
#   Stage 2 MLP   : state/forge_phaseR_a_stage2_2026_05_17/result.json  (large_b128, large_b512, xlarge_b128)
#   Transformer   : state/forge_phaseR_a_transformer_2026_05_17/result.json (small, medium, large)
#
# This fire runs ONLY:
#   1. a_pytorch_compile_baseline.py        (preset=all, mode=default)
#   2. a_pytorch_compile_baseline.py        (preset=all, mode=reduce-overhead)
#   3. a_transformer_pytorch_compile.py     (preset=all, mode=default)
#   4. a_transformer_pytorch_compile.py     (preset=all, mode=reduce-overhead)
#
# Falsifier:
#   F-FORGE-A-TORCHCOMPILE: AOT step ≥ 1.05 × torch.compile (strong baseline; 1.05× still meaningful).
#
# Budget: $1 max (no CUDA build, only Python runs; ~5-10 min wall on A100).

set -uo pipefail

PHASE_ID="forge_phaseR_a_torchcompile_2026_05_17"
WORKTREE="/Users/ghost/core/hexa-lang/.claude/worktrees/agent-addbef8b2c5c1bf6d"
LOCAL_DIR="$WORKTREE/state/$PHASE_ID"
SRC_DIR="$WORKTREE/self/cuda/experiments"
PHASE_LABEL="forge-phaseR-A-torchcompile"
REMOTE_WORK="/workspace/forge_phaseR_a_torchcompile"

VAST_SSH_KEY="/Users/ghost/.vast/ssh/vast-key"
VASTAI="/Users/ghost/Library/Python/3.14/bin/vastai"
[ -x "$VASTAI" ] || { echo "ERROR: vastai CLI not found at $VASTAI"; exit 1; }
[ -f "$VAST_SSH_KEY" ] || { echo "ERROR: vast ssh key missing"; exit 1; }
[ -f "$SRC_DIR/a_pytorch_compile_baseline.py" ]    || { echo "ERROR: a_pytorch_compile_baseline.py missing"; exit 1; }
[ -f "$SRC_DIR/a_transformer_pytorch_compile.py" ] || { echo "ERROR: a_transformer_pytorch_compile.py missing"; exit 1; }

mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR"
echo "=== ${PHASE_ID} vast.ai dispatch (Phase R / A torch.compile baseline, 2026-05-17) ==="
date -u

# ── 1) Search offers ─────────────────────────────────────────────────
echo "[1/9] Searching A100/H100/H200 offers under \$15/hr (cheapest first; A100 OK) ..."
OFFER_JSON=$($VASTAI search offers \
    'gpu_name in [A100_SXM4,A100_PCIE,A100,H100_SXM,H100_PCIE,H100_NVL,H100,H200] num_gpus=1 rentable=true dph_total<15.0 cuda_max_good>=12.4 disk_space>50' \
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

# ── 4) Toolchain sanity (need torch + triton for torch.compile) ─────
echo "[4/9] Remote toolchain sanity ..."
$SSH_CMD "set +e
  nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader | head -2
  echo '---'
  nvcc --version | head -5
  echo '---'
  python -c 'import torch; print(\"torch=\"+torch.__version__+\" dev=\"+torch.cuda.get_device_name(0))'
  python -c 'import triton; print(\"triton=\"+triton.__version__)' 2>&1 | head -1
  python -c 'import torch._dynamo; print(\"dynamo=OK\")' 2>&1 | head -1
  mkdir -p $REMOTE_WORK
  echo 'TOOLCHAIN_OK'" 2>&1 | tee remote_sanity.log

# ── 5) Upload baselines ───────────────────────────────────────────────
echo "[5/9] Upload a_pytorch_compile_baseline.py + a_transformer_pytorch_compile.py ..."
$SCP_CMD "$SRC_DIR/a_pytorch_compile_baseline.py"    "root@$SSH_HOST:$REMOTE_WORK/"
$SCP_CMD "$SRC_DIR/a_transformer_pytorch_compile.py" "root@$SSH_HOST:$REMOTE_WORK/"

# ── 6) Run torch.compile baselines (4 fires, rename JSON between fires) ──
echo "[6/9] Run a_pytorch_compile_baseline (MLP) mode=default ..."
$SSH_CMD "cd $REMOTE_WORK && \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_pre.csv ; \
    rm -f pytorch_compile_default_result.json ; \
    python a_pytorch_compile_baseline.py all default 2>&1 | tee fire_mlp_default.log ; \
    echo \"MLP_DEFAULT_RC=\${PIPESTATUS[0]}\" ; \
    mv -f pytorch_compile_default_result.json pytorch_compile_mlp_default_result.json && echo 'MLP_DEFAULT_RENAMED_OK' || echo 'MLP_DEFAULT_RENAME_FAIL'" \
    2>&1 | tee dispatch_mlp_default.log

echo "[6.2/9] Run a_pytorch_compile_baseline (MLP) mode=reduce-overhead ..."
$SSH_CMD "cd $REMOTE_WORK && \
    rm -f pytorch_compile_reduce_overhead_result.json ; \
    python a_pytorch_compile_baseline.py all reduce-overhead 2>&1 | tee fire_mlp_reduce_overhead.log ; \
    echo \"MLP_REDUCE_RC=\${PIPESTATUS[0]}\" ; \
    mv -f pytorch_compile_reduce_overhead_result.json pytorch_compile_mlp_reduce_overhead_result.json && echo 'MLP_REDUCE_RENAMED_OK' || echo 'MLP_REDUCE_RENAME_FAIL'" \
    2>&1 | tee dispatch_mlp_reduce_overhead.log

echo "[6.4/9] Run a_transformer_pytorch_compile mode=default ..."
$SSH_CMD "cd $REMOTE_WORK && \
    rm -f pytorch_compile_default_result.json ; \
    python a_transformer_pytorch_compile.py all default 2>&1 | tee fire_t_default.log ; \
    echo \"T_DEFAULT_RC=\${PIPESTATUS[0]}\" ; \
    mv -f pytorch_compile_default_result.json pytorch_compile_transformer_default_result.json && echo 'T_DEFAULT_RENAMED_OK' || echo 'T_DEFAULT_RENAME_FAIL'" \
    2>&1 | tee dispatch_t_default.log

echo "[6.6/9] Run a_transformer_pytorch_compile mode=reduce-overhead ..."
$SSH_CMD "cd $REMOTE_WORK && \
    rm -f pytorch_compile_reduce_overhead_result.json ; \
    python a_transformer_pytorch_compile.py all reduce-overhead 2>&1 | tee fire_t_reduce_overhead.log ; \
    echo \"T_REDUCE_RC=\${PIPESTATUS[0]}\" ; \
    mv -f pytorch_compile_reduce_overhead_result.json pytorch_compile_transformer_reduce_overhead_result.json && echo 'T_REDUCE_RENAMED_OK' || echo 'T_REDUCE_RENAME_FAIL' ; \
    nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi_post.csv ; \
    ls *.json" 2>&1 | tee dispatch_t_reduce_overhead.log

# ── 7) Pull artifacts ─────────────────────────────────────────────────
echo "[7/9] Pull artifacts ..."
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
pull_with_retry "$REMOTE_WORK/pytorch_compile_mlp_default_result.json"            "$LOCAL_DIR/pytorch_compile_mlp_default_result.json"            || PULL_OK=0
pull_with_retry "$REMOTE_WORK/pytorch_compile_mlp_reduce_overhead_result.json"    "$LOCAL_DIR/pytorch_compile_mlp_reduce_overhead_result.json"    || PULL_OK=0
pull_with_retry "$REMOTE_WORK/pytorch_compile_transformer_default_result.json"    "$LOCAL_DIR/pytorch_compile_transformer_default_result.json"    || PULL_OK=0
pull_with_retry "$REMOTE_WORK/pytorch_compile_transformer_reduce_overhead_result.json" "$LOCAL_DIR/pytorch_compile_transformer_reduce_overhead_result.json" || PULL_OK=0
pull_with_retry "$REMOTE_WORK/fire_mlp_default.log"            "$LOCAL_DIR/fire_mlp_default.log" || true
pull_with_retry "$REMOTE_WORK/fire_mlp_reduce_overhead.log"    "$LOCAL_DIR/fire_mlp_reduce_overhead.log" || true
pull_with_retry "$REMOTE_WORK/fire_t_default.log"              "$LOCAL_DIR/fire_t_default.log" || true
pull_with_retry "$REMOTE_WORK/fire_t_reduce_overhead.log"      "$LOCAL_DIR/fire_t_reduce_overhead.log" || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_pre.csv"              "$LOCAL_DIR/nvidia_smi_pre.csv" || true
pull_with_retry "$REMOTE_WORK/nvidia_smi_post.csv"             "$LOCAL_DIR/nvidia_smi_post.csv" || true

# ── 8) Pod lifecycle ──────────────────────────────────────────────────
echo "[8/9] Pod lifecycle ..."
if [ $PULL_OK -eq 1 ]; then
    echo "  All 4 result JSONs pulled — destroying instance now"
    $VASTAI destroy instance "$INSTANCE_ID" 2>&1 | head -3 || true
    SAVE_POD=0
else
    echo "  [WARN] partial pull — pod RETAINED for manual recovery"
    echo "  manual SSH: ssh -i $VAST_SSH_KEY -p $SSH_PORT root@$SSH_HOST"
    echo "  manual destroy: $VASTAI destroy instance $INSTANCE_ID"
fi

# ── 9) Summary table (AOT vs eager vs compile) ───────────────────────
echo "[9/9] === ${PHASE_ID} DONE ==="
date -u

# Load AOT and eager from main repo (already measured), compile from this fire.
AOT_MLP_STAGE1="/Users/ghost/core/hexa-lang/state/forge_phaseR_a_2026_05_17/result.json"
AOT_MLP_STAGE2="/Users/ghost/core/hexa-lang/state/forge_phaseR_a_stage2_2026_05_17/result.json"
AOT_T="/Users/ghost/core/hexa-lang/.claude/worktrees/agent-a878ec8720149706b/state/forge_phaseR_a_transformer_2026_05_17/result.json"
PYT_MLP_STAGE1="/Users/ghost/core/hexa-lang/state/forge_phaseR_a_2026_05_17/pytorch_result.json"
PYT_MLP_STAGE2="/Users/ghost/core/hexa-lang/state/forge_phaseR_a_stage2_2026_05_17/pytorch_result.json"
PYT_T="/Users/ghost/core/hexa-lang/.claude/worktrees/agent-a878ec8720149706b/state/forge_phaseR_a_transformer_2026_05_17/pytorch_result.json"
COMP_MLP_DEFAULT="$LOCAL_DIR/pytorch_compile_mlp_default_result.json"
COMP_MLP_REDUCE="$LOCAL_DIR/pytorch_compile_mlp_reduce_overhead_result.json"
COMP_T_DEFAULT="$LOCAL_DIR/pytorch_compile_transformer_default_result.json"
COMP_T_REDUCE="$LOCAL_DIR/pytorch_compile_transformer_reduce_overhead_result.json"

python3 - <<PYEOF
import json, os
def load(p):
    try: return json.load(open(p))
    except Exception as e:
        print(f'WARN: cannot load {p}: {e}'); return {'configs':[]}

aot_mlp = {}
for src in ['$AOT_MLP_STAGE1', '$AOT_MLP_STAGE2']:
    for c in load(src).get('configs', []):
        aot_mlp[c['label']] = c
pyt_mlp = {}
for src in ['$PYT_MLP_STAGE1', '$PYT_MLP_STAGE2']:
    for c in load(src).get('configs', []):
        pyt_mlp[c['label']] = c
comp_mlp_def = {c['label']: c for c in load('$COMP_MLP_DEFAULT').get('configs', [])}
comp_mlp_red = {c['label']: c for c in load('$COMP_MLP_REDUCE').get('configs', [])}

aot_t = {c['label']: c for c in load('$AOT_T').get('configs', [])}
pyt_t = {c['label']: c for c in load('$PYT_T').get('configs', [])}
comp_t_def = {c['label']: c for c in load('$COMP_T_DEFAULT').get('configs', [])}
comp_t_red = {c['label']: c for c in load('$COMP_T_REDUCE').get('configs', [])}

def fmt_row(label, aot, pyt, cd, cr, verdict_thr=1.05):
    if not aot: return None
    a_ms = aot.get('step_ms_median', 0)
    p_ms = pyt.get('step_ms_median', 0) if pyt else 0
    d_ms = cd.get('step_ms_median', 0) if cd else 0
    r_ms = cr.get('step_ms_median', 0) if cr else 0
    sp_eager = p_ms / a_ms if a_ms > 0 and p_ms > 0 else 0
    sp_compile_def = d_ms / a_ms if a_ms > 0 and d_ms > 0 else 0
    sp_compile_red = r_ms / a_ms if a_ms > 0 and r_ms > 0 else 0
    vd = 'PASS' if sp_compile_def >= verdict_thr or sp_compile_red >= verdict_thr else 'FAIL'
    return f'{label:14s}  AOT={a_ms:8.3f}ms  eager={p_ms:8.3f}ms ({sp_eager:5.2f}x)  comp.def={d_ms:8.3f}ms ({sp_compile_def:5.2f}x)  comp.red={r_ms:8.3f}ms ({sp_compile_red:5.2f}x)  {vd}'

print('\n=== MLP Stage 1 + Stage 2 ===')
for lbl in ['mnist_b32','mnist_b128','mid_b32','large_b128','large_b512','xlarge_b128']:
    row = fmt_row(lbl, aot_mlp.get(lbl), pyt_mlp.get(lbl), comp_mlp_def.get(lbl), comp_mlp_red.get(lbl))
    if row: print(row)

print('\n=== Transformer Block (Llama-style) ===')
for lbl in ['small','medium','large']:
    row = fmt_row(lbl, aot_t.get(lbl), pyt_t.get(lbl), comp_t_def.get(lbl), comp_t_red.get(lbl))
    if row: print(row)
PYEOF

echo "DONE"
