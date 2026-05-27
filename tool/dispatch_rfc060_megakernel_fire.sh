#!/bin/bash
# dispatch_rfc060_megakernel_fire.sh — RFC 060 falsifier F-RFC060-MEGAKERNEL-WALL.
#
# Fires self/cuda/experiments/rfc060_megakernel_fwd.cu on a vast.ai H100/A100:
# transformer-block forward, kernel-stream (cuBLAS) vs single persistent
# mega-kernel (in-kernel tiled GEMM). Cheap test — RFC 060 §7/§12 step 060-C.
#
# Output: state/forge_rfc060_2026_05_19/{result.json, build.log, fire.log,
#         nvidia_smi.csv}
# Budget: ~$0.40-1 (one short fire, 2 configs).
#
# Env: SAVE_POD=1 keeps the instance; VAST_BAD_OFFERS="id,id" blacklists.

set -uo pipefail

REPO="/Users/ghost/core/hexa-lang"
LOCAL_DIR="$REPO/state/forge_rfc060_2026_05_19"
SRC="$REPO/self/cuda/experiments/rfc060_megakernel_fwd.cu"
REMOTE_WORK="/workspace/rfc060_megakernel"
LABEL="forge-rfc060-megakernel-wall"
PRESET="${PRESET:-all}"

VAST_SSH_KEY="/Users/ghost/.vast/ssh/vast-key"
VASTAI="/Users/ghost/Library/Python/3.14/bin/vastai"
[ -x "$VASTAI" ] || { echo "ERROR: vastai CLI not found at $VASTAI"; exit 1; }
[ -f "$VAST_SSH_KEY" ] || { echo "ERROR: vast ssh key missing"; exit 1; }
[ -f "$SRC" ] || { echo "ERROR: $SRC missing"; exit 1; }
mkdir -p "$LOCAL_DIR"; cd "$LOCAL_DIR"
echo "=== RFC 060 megakernel-wall fire — $(date -u) ==="

# ── 1) search offer ───────────────────────────────────────────────────
echo "[1/8] Searching H100/A100 offers ..."
OFFER_JSON=$($VASTAI search offers \
    'gpu_name in [H100_SXM,H100_PCIE,H100_NVL,H100,H200,A100_SXM4,A100_PCIE,A100] num_gpus=1 rentable=true dph_total<15.0 cuda_max_good>=12.4 disk_space>40' \
    -o dph_total --raw 2>&1)
OFFER_ID=$(echo "$OFFER_JSON" | python3 -c "
import json,sys,os
bad=set(x.strip() for x in os.environ.get('VAST_BAD_OFFERS','').split(',') if x.strip())
try: d=json.load(sys.stdin)
except: sys.exit(1)
for b in d:
    if str(b['id']) in bad: continue
    print('%s %.4f %s'%(b['id'],b['dph_total'],b['gpu_name'].replace(' ','_'))); break
")
OID=$(echo "$OFFER_ID" | awk '{print $1}')
[ -z "$OID" ] && { echo "ERROR: no offer"; exit 1; }
echo "  offer: $OFFER_ID"

# ── 2) rent ───────────────────────────────────────────────────────────
echo "[2/8] Renting ..."
CREATE=$($VASTAI create instance "$OID" \
    --image pytorch/pytorch:2.4.0-cuda12.4-cudnn9-devel \
    --disk 40 --ssh --direct --label "$LABEL" --raw 2>&1)
IID=$(echo "$CREATE" | python3 -c "
import json,sys
try: d=json.load(sys.stdin); print(d.get('new_contract',d.get('contract_id',d.get('id',''))))
except: sys.exit(1)")
[ -z "$IID" ] && { echo "ERROR: instance id parse failed: $CREATE"; exit 1; }
echo "  instance: $IID"; echo "$IID" > vast_instance_id.txt

cleanup(){ local rc=$?
  if [ "${SAVE_POD:-0}" = "1" ]; then echo "[cleanup] SAVE_POD=1 keep $IID"
  else echo "[cleanup] destroy $IID"; $VASTAI destroy instance "$IID" 2>&1|head -2||true; fi; }
trap cleanup EXIT INT TERM

# ── 3) wait SSH ───────────────────────────────────────────────────────
echo "[3/8] Waiting SSH ..."
SSH_HOST=""; SSH_PORT=""
for i in $(seq 1 160); do
    INFO=$($VASTAI show instance "$IID" --raw 2>/dev/null||true); [ -z "$INFO" ]&&INFO="{}"
    ST=$(echo "$INFO"|python3 -c "import json,sys
try: print(json.load(sys.stdin).get('actual_status',''))
except: print('')" 2>/dev/null||echo "")
    if [ "$ST" = "running" ]; then
        SSH_HOST=$(echo "$INFO"|python3 -c "import json,sys
try: d=json.load(sys.stdin); print(d.get('public_ipaddr','') or d.get('ssh_host',''))
except: pass" 2>/dev/null||echo "")
        SSH_PORT=$(echo "$INFO"|python3 -c "import json,sys
try:
 d=json.load(sys.stdin); p=d.get('ports',{}) or {}; m=p.get('22/tcp')
 print(m[0]['HostPort'] if m else (d.get('direct_port_start','') or d.get('ssh_port','')))
except: pass" 2>/dev/null||echo "")
        if [ -n "$SSH_HOST" ] && [ -n "$SSH_PORT" ]; then
            if ssh -i "$VAST_SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                -o ConnectTimeout=10 -p "$SSH_PORT" "root@$SSH_HOST" 'echo READY' 2>&1|grep -q READY; then
                echo "  SSH ready: $SSH_HOST:$SSH_PORT"; break
            fi
            SSH_HOST=""
        fi
    fi
    echo "  ... $i/160 status=$ST"; sleep 5
done
[ -z "$SSH_HOST" ] && { echo "ERROR: SSH not ready"; SAVE_POD=1; exit 1; }
SSH_OPTS="-i $VAST_SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60"
SC="ssh $SSH_OPTS -p $SSH_PORT root@$SSH_HOST"
SCP="scp $SSH_OPTS -P $SSH_PORT -o ConnectTimeout=3600"

# ── 4) sanity ─────────────────────────────────────────────────────────
echo "[4/8] Toolchain sanity ..."
$SC "nvidia-smi --query-gpu=name,memory.total --format=csv,noheader|head -1
  nvcc --version|tail -2
  mkdir -p $REMOTE_WORK && echo TOOLCHAIN_OK" 2>&1 | tee remote_sanity.log

# ── 5) upload ─────────────────────────────────────────────────────────
echo "[5/8] Upload source ..."
$SCP "$SRC" "root@$SSH_HOST:$REMOTE_WORK/"

# ── 6) build + run ────────────────────────────────────────────────────
echo "[6/8] Build + fire ..."
$SC "cd $REMOTE_WORK && \
  nvcc -O3 -std=c++14 -arch=native rfc060_megakernel_fwd.cu \
    -lcublas -lcudart -lm -o rfc060_megakernel_fwd 2>&1 | tee build.log ; \
  BRC=\${PIPESTATUS[0]} ; echo \"BUILD_RC=\$BRC\" ; \
  nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader > nvidia_smi.csv ; \
  if [ \"\$BRC\" = '0' ]; then ./rfc060_megakernel_fwd $PRESET 2>&1 | tee fire.log ; \
    echo \"FIRE_RC=\${PIPESTATUS[0]}\" ; \
  else echo 'BUILD FAILED'; fi ; \
  test -f result.json && echo RESULT_JSON_OK || echo RESULT_JSON_MISSING" 2>&1 | tee dispatch.log

# ── 7) pull ───────────────────────────────────────────────────────────
echo "[7/8] Pull artifacts ..."
PULL_OK=1
pull(){ local t=0; while [ $t -lt 3 ]; do
  $SCP "root@$SSH_HOST:$REMOTE_WORK/$1" "$LOCAL_DIR/$1" 2>&1 && { echo "  pulled $1"; return 0; }
  t=$((t+1)); echo "  retry $t/3 $1"; [ $t -lt 3 ] && sleep 10; done; echo "  FAIL $1"; return 1; }
$SC "test -f $REMOTE_WORK/result.json && echo OK" 2>/dev/null | grep -q OK \
  && pull result.json || PULL_OK=0
pull build.log || true
pull fire.log || true
pull nvidia_smi.csv || true

# ── 8) lifecycle + summary ────────────────────────────────────────────
if [ $PULL_OK -eq 1 ]; then
  echo "[8/8] artifacts pulled — destroy $IID"
  $VASTAI destroy instance "$IID" 2>&1|head -2||true; SAVE_POD=0
else
  echo "[8/8] partial pull — pod RETAINED ($IID)"; SAVE_POD=1
fi
echo "=== RFC 060 fire DONE — $(date -u) ==="
[ -f "$LOCAL_DIR/result.json" ] && cat "$LOCAL_DIR/result.json"
echo "DONE"
