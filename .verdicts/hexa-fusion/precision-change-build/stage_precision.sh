#!/usr/bin/env bash
# stage_precision.sh — assemble stage.tgz LOCALLY for the precision-change on-pod build.
# Layout inside stage.tgz (extracted into ~/work):
#   self/                  <- fusion_build_sources.tgz self/ tree, runtime.c OVERRIDDEN by l3d
#   corpus.txt             <- from fusion_build_sources.tgz
#   clm_prod.c             <- aprime3 device-eager driver (unchanged from p1b-aprime3)
#   runtime_cuda.c         <- aprime3 FP64-megafwd + the HEXA_GEMM_PREC tf32/bf16 precision path
#   clm_megafwd_dispatch.c <- the one missing host wrapper
#   insert_fusion_protos.py
#   build_on_pod.sh / prec_sweep.sh
set -euo pipefail
KIT=~/hexa-fusion-cuda-kit
HERE="$(cd "$(dirname "$0")" && pwd)"
STAGE=$(mktemp -d); echo "stage dir: $STAGE"
tar xzf "$KIT/fusion_build_sources.tgz" -C "$STAGE"
cp -f "$KIT/l3d-build/runtime.c" "$STAGE/self/runtime.c"
cp -f "$HERE/clm_prod.c"             "$STAGE/clm_prod.c"
cp -f "$HERE/runtime_cuda.c"         "$STAGE/runtime_cuda.c"   # PRECISION-PATCHED
cp -f "$HERE/clm_megafwd_dispatch.c" "$STAGE/clm_megafwd_dispatch.c"
cp -f "$HERE/insert_fusion_protos.py" "$STAGE/insert_fusion_protos.py"
cp -f "$HERE/build_on_pod.sh"        "$STAGE/build_on_pod.sh"
cp -f "$HERE/prec_sweep.sh"          "$STAGE/prec_sweep.sh"
echo "  runtime_cuda.c precision markers: $(grep -c HEXA_GEMM_PREC "$STAGE/runtime_cuda.c") (expect >=3)"
( cd "$STAGE" && tar czf "$HERE/stage.tgz" self corpus.txt clm_prod.c runtime_cuda.c clm_megafwd_dispatch.c insert_fusion_protos.py build_on_pod.sh prec_sweep.sh )
echo "  stage.tgz = $(stat -f%z "$HERE/stage.tgz" 2>/dev/null || stat -c%s "$HERE/stage.tgz") B -> $HERE/stage.tgz"
rm -rf "$STAGE"
