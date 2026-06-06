#!/bin/bash
# ddp_topo_probe.sh — HEXA-DDP M2 GPU interconnect topology probe.
#
# Runs `nvidia-smi topo -m` and records the GPU<->GPU link matrix so
# DDP-M3 (single-node P2P all-reduce) can pick the right transport per
# GPU pair WITHOUT guessing:
#
#   NV# / NVLINK  -> NVLink     (peer cudaMemcpyPeer, fastest)
#   PIX/PXB/PHB   -> PCIe       (peer copy over PCIe switch/host bridge)
#   NODE/SYS      -> cross-NUMA / cross-socket (slowest; may need staging)
#   X             -> self
#
# This is the M2 falsifier artifact: "2-GPU one node rent + nvidia-smi
# topo -m capture". Run it ON the rented pod (it needs the GPUs present);
# from the dispatch host invoke it over SSH, e.g.
#
#   ssh pod 'bash -s' < tool/ddp_topo_probe.sh > state/ddp_m2/topo.txt
#
# Output (stdout):
#   * the raw `nvidia-smi topo -m` matrix (verbatim — the SSOT)
#   * a parsed per-pair transport summary (NVLink / PCIe / SYS)
#   * a one-line DDP-transport verdict for the first N GPUs
#
# Exit codes: 0 ok · 2 nvidia-smi missing · 3 fewer than 2 GPUs visible.
#
# Env: DDP_NUM_GPUS (default 2) — how many GPUs the DDP job will use; the
#      verdict reasons over the first N x N sub-matrix.

set -uo pipefail
N="${DDP_NUM_GPUS:-2}"

if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "ddp_topo_probe: ERROR nvidia-smi not found (run this ON the GPU pod)" >&2
    exit 2
fi

NGPU=$(nvidia-smi --query-gpu=count --format=csv,noheader 2>/dev/null | head -1 | tr -d ' ')
[ -z "$NGPU" ] && NGPU=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
echo "=== ddp_topo_probe :: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "visible GPUs: ${NGPU:-unknown} ; DDP wants: $N"
echo

echo "--- nvidia-smi -L ---"
nvidia-smi -L 2>&1 || true
echo

echo "--- nvidia-smi topo -m (VERBATIM — SSOT) ---"
TOPO="$(nvidia-smi topo -m 2>&1)"
echo "$TOPO"
echo

if [ -z "${NGPU:-}" ] || [ "${NGPU:-0}" -lt 2 ] 2>/dev/null; then
    echo "ddp_topo_probe: ERROR fewer than 2 GPUs visible — DDP needs 2+ on one node" >&2
    exit 3
fi

# ── parse the matrix into a per-pair transport summary ───────────────────
# The matrix rows look like:  GPU0  X  NV12  SYS ...   (cells GPUi vs GPUj)
echo "--- parsed GPU-GPU transport (first ${N}x${N}) ---"
echo "$TOPO" | awk -v want="$N" '
function classify(c,   u) {
    u = toupper(c)
    if (u == "X")                         return "self"
    if (u ~ /^NV[0-9]*$/ || u ~ /NVLINK/) return "NVLink"
    if (u ~ /^(PIX|PXB|PHB|PCI)/)         return "PCIe"
    if (u ~ /^(NODE|SYS)/)                return "SYS(cross-NUMA)"
    return c
}
/^GPU[0-9]+/ {
    row = $1
    sub(/[^0-9]*/, "", row); ri = row + 0
    if (ri >= want) next
    for (j = 2; j <= NF; j++) {
        ci = j - 2
        if (ci >= want) break
        if (ci <= ri) continue   # upper triangle only (symmetric)
        t = classify($j)
        printf "  GPU%d <-> GPU%d : %s\n", ri, ci, t
        kinds[t]++
        total++
    }
}
END {
    print ""
    if (total == 0) { print "  (no GPU-GPU pairs parsed — inspect matrix above)"; exit }
    nvlink = kinds["NVLink"]+0; pcie = kinds["PCIe"]+0; sys = kinds["SYS(cross-NUMA)"]+0
    if (nvlink == total)      verdict = "NVLink — all pairs peer over NVLink (use cudaMemcpyPeer P2P)"
    else if (sys == total)    verdict = "SYS — all pairs cross-NUMA (P2P may be disabled; stage via host)"
    else if (nvlink > 0)      verdict = "MIXED — NVLink for " nvlink "/" total " pairs, fall back to PCIe/host for the rest"
    else                      verdict = "PCIe — peer over PCIe (slower than NVLink, P2P usually still works)"
    print "DDP-transport verdict: " verdict
}'
