#!/bin/bash
# Wrap N5 funnel with BETE-NET activation
ELEM_POOL="${1:-Nb}"; MAX_ATOMS="${2:-4}"; TOP_K="${3:-5}"
OUT_DIR="${4:-/tmp/n5_real_$(date +%Y%m%dT%H%M%SZ)}"
source ~/core/hexa-lang/stdlib/material/_setup/activate_bete_net.sh || {
  echo "[ERROR] BETE-NET not activated · run setup_bete_net_venv.sh first"
  exit 1
}
python3 ~/core/hexa-lang/stdlib/material/novel_material_funnel.py "$OUT_DIR" "$ELEM_POOL" --max-atoms "$MAX_ATOMS" --top-k "$TOP_K"
echo "[N5] output: $OUT_DIR"
