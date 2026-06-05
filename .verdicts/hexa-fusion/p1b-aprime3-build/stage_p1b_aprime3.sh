#!/usr/bin/env bash
# stage_p1b_aprime3.sh — assemble stage.tgz LOCALLY for the P1B-a''' on-pod build.
# Layout inside stage.tgz (extracted into ~/work):
#   self/                    <- fusion_build_sources.tgz self/ tree, runtime.c OVERRIDDEN by l3d
#   corpus.txt               <- from fusion_build_sources.tgz
#   clm_prod.c               <- aprime3 (P1B-a' device-eager driver)
#   runtime_cuda.c           <- aprime3 (FP64-megafwd + EAGER-DEVGLUE + HEXA_CUDA_ASYNC gate)
#   clm_megafwd_dispatch.c   <- the ONE missing host wrapper
#   insert_fusion_protos.py  <- 5 fused protos into self/runtime.h
set -euo pipefail
KIT=~/hexa-fusion-cuda-kit
HERE="$(cd "$(dirname "$0")" && pwd)"
STAGE=$(mktemp -d)
echo "stage dir: $STAGE"
tar xzf "$KIT/fusion_build_sources.tgz" -C "$STAGE"      # -> $STAGE/self, $STAGE/corpus.txt, $STAGE/clm_prod.c (base, discarded)
# OVERRIDE self/runtime.c with the l3d base (has 4/5 fused + every per-op dispatcher)
cp -f "$KIT/l3d-build/runtime.c" "$STAGE/self/runtime.c"
# aprime3 overrides + the missing megafwd wrapper + proto inserter
cp -f "$HERE/clm_prod.c"             "$STAGE/clm_prod.c"
cp -f "$HERE/runtime_cuda.c"         "$STAGE/runtime_cuda.c"
cp -f "$HERE/clm_megafwd_dispatch.c" "$STAGE/clm_megafwd_dispatch.c"
cp -f "$HERE/insert_fusion_protos.py" "$STAGE/insert_fusion_protos.py"
echo "  self/runtime.c    = l3d ($(grep -c 'forge_dispatch_gelu2' "$STAGE/self/runtime.c") gelu2 def, $(grep -c 'forge_dispatch_clm_megafwd' "$STAGE/self/runtime.c") clm_megafwd def [expect 0])"
echo "  self/ file count  = $(find "$STAGE/self" -type f | wc -l)"
echo "  corpus.txt        = $(stat -f%z "$STAGE/corpus.txt" 2>/dev/null || stat -c%s "$STAGE/corpus.txt") B"
( cd "$STAGE" && tar czf "$HERE/stage.tgz" self corpus.txt clm_prod.c runtime_cuda.c clm_megafwd_dispatch.c insert_fusion_protos.py )
echo "  stage.tgz         = $(stat -f%z "$HERE/stage.tgz" 2>/dev/null || stat -c%s "$HERE/stage.tgz") B -> $HERE/stage.tgz"
rm -rf "$STAGE"
