#!/bin/bash
# ddp_rent_lib.sh — HEXA-DDP M2 multi-GPU rent helpers (sourceable).
#
# Canonical, sourceable shim that parametrizes the vast/runpod rent path
# so a DDP dispatch can request num_gpus >= 2 ON ONE NODE. DDP needs 2+
# GPUs sharing a NUMA/NVLink fabric on a single node (so a ring-all-reduce
# can use cudaMemcpyPeer/NVLink P2P, see DDP-M3) — NOT two separate
# single-GPU pods (those can't peer-copy). That is why this is a node-level
# num_gpus knob, not a "rent N pods" loop.
#
# Background: every existing dispatch_*.sh hardcodes `num_gpus=1` in its
# `vastai search offers '...'` filter. This lib factors the GPU count into
# one place so a DDP dispatch can opt into multi-GPU WITHOUT touching the
# single-GPU campaigns. Default is 1, so a script that sources this lib but
# never sets DDP_NUM_GPUS behaves byte-identically to the old hardcoded
# `num_gpus=1`.
#
# ── usage ────────────────────────────────────────────────────────────────
#   source "$(dirname "$0")/ddp_rent_lib.sh"
#
#   # build the search-offers GPU-count predicate (env-driven, default 1):
#   GPU_PRED="$(ddp_gpu_pred)"            # -> "num_gpus=1"  (default)
#   DDP_NUM_GPUS=2 GPU_PRED="$(ddp_gpu_pred)"  # -> "num_gpus>=2"
#
#   OFFER_JSON=$($VASTAI search offers \
#       "gpu_name in [H100_SXM,H100,H200] $(ddp_gpu_pred) rentable=true ..." \
#       -o dph_total --raw)
#
# ── env ──────────────────────────────────────────────────────────────────
#   DDP_NUM_GPUS   integer >= 1  (default 1). When 1 the predicate is the
#                  exact literal "num_gpus=1" — byte-identical to the legacy
#                  hardcoded token, so the 1-GPU path is provably unchanged.
#                  When >= 2 the predicate becomes "num_gpus>=N" (a single
#                  node carrying at least N GPUs — required for DDP P2P).
#
# This file is pure shell helpers (no side effects on source); the topology
# probe lives in the companion tool/ddp_topo_probe.sh.

# ddp_num_gpus — echo the requested per-node GPU count (default 1).
# Validates: must be a positive integer; anything else falls back to 1 and
# warns on stderr (never silently changes behavior to a bad value).
ddp_num_gpus() {
    local n="${DDP_NUM_GPUS:-1}"
    case "$n" in
        ''|*[!0-9]*)
            echo "ddp_rent_lib: WARN bad DDP_NUM_GPUS='$n' (not a positive int) -> 1" >&2
            echo 1; return 0 ;;
    esac
    if [ "$n" -lt 1 ]; then
        echo "ddp_rent_lib: WARN DDP_NUM_GPUS='$n' < 1 -> 1" >&2
        echo 1; return 0
    fi
    echo "$n"
}

# ddp_gpu_pred — echo the vastai search-offers GPU-count predicate token.
#   DDP_NUM_GPUS unset / =1  ->  "num_gpus=1"   (legacy literal, unchanged)
#   DDP_NUM_GPUS >= 2        ->  "num_gpus>=N"   (single node, >= N GPUs)
#
# The `>=` (not `=`) for the multi-GPU case is deliberate: it widens the
# offer pool to any node with at least N GPUs (8x boxes are common and
# cheaper per-GPU), and DDP-M3 just uses the first N of them.
ddp_gpu_pred() {
    local n; n="$(ddp_num_gpus)"
    if [ "$n" -eq 1 ]; then
        printf 'num_gpus=1'
    else
        printf 'num_gpus>=%d' "$n"
    fi
}

# ddp_rent_note — one-line human summary of what will be requested, for the
# dispatch log header. No side effects.
ddp_rent_note() {
    local n; n="$(ddp_num_gpus)"
    if [ "$n" -eq 1 ]; then
        echo "[ddp-rent] single-GPU (num_gpus=1) — legacy path, DDP disabled"
    else
        echo "[ddp-rent] MULTI-GPU node requested: $(ddp_gpu_pred) (DDP-capable, $n ranks)"
    fi
}
