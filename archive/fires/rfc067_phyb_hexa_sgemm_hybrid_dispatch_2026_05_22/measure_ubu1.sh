#!/usr/bin/env bash
# RFC 067 P-HYB measurement script -- UBU-1 variant
# Ships host_hybrid.c + N107 PTX (from pZbig) + N121 PTX (from pZ) to ubu-1,
# builds with nvcc, runs once, pulls back fire.log + result.json + ptxas_info.log.
# Parallel with ubu-2 N130 (spread load).
set -euo pipefail

LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
N107_DIR="$LOCAL_DIR/../rfc067_pZbig_hexa_sgemm_n107_bigshape_2026_05_22"
N121_DIR="$LOCAL_DIR/../rfc067_pZ_hexa_sgemm_4warp_6stage_2026_05_21"

REMOTE_ROOT="/tmp/rfc067_phyb_ubu1_$(date +%s)"
NVCC=/usr/local/cuda-12.9/bin/nvcc
CUDA_LIB=/usr/local/cuda-12.9/lib64
CUDA_INC=/usr/local/cuda-12.9/include

echo "==> staging on ubu-1:$REMOTE_ROOT"
ssh ubu-1 "mkdir -p $REMOTE_ROOT/n107 $REMOTE_ROOT/n121 $REMOTE_ROOT/hyb"

# Ship host file
scp "$LOCAL_DIR/host_hybrid.c" "ubu-1:$REMOTE_ROOT/hyb/"

# Ship N107 PTX (M=256,384,512,768,1024,1536,2048,3072,4096)
for M in 256 384 512 768 1024 1536 2048 3072 4096; do
    scp "$N107_DIR/sgemm_4warp_swizzle_${M}x${M}_grid.ptx" "ubu-1:$REMOTE_ROOT/n107/"
done

# Ship N121 PTX (M=256,384,512,768,1024,1536)
for M in 256 384 512 768 1024 1536; do
    scp "$N121_DIR/sgemm_4warp_6stage_${M}x${M}_grid.ptx" "ubu-1:$REMOTE_ROOT/n121/"
done

# Build + patch relative paths in host_hybrid.c to point to remote layout, then run.
ssh ubu-1 bash -lc "'
    set -euo pipefail
    cd $REMOTE_ROOT/hyb
    # Substitute the relative dispatch paths to the remote staging layout
    sed -i \
        -e \"s|../rfc067_pZbig_hexa_sgemm_n107_bigshape_2026_05_22/|../n107/|g\" \
        -e \"s|../rfc067_pZ_hexa_sgemm_4warp_6stage_2026_05_21/|../n121/|g\" \
        host_hybrid.c
    echo === nvcc build ===
    $NVCC -O2 -arch=sm_90 -I$CUDA_INC -L$CUDA_LIB -o host_hybrid host_hybrid.c -lcuda -lcublas -lm 2>&1 | tee compile_ubu1.log
    echo === fire ===
    LD_LIBRARY_PATH=$CUDA_LIB:\${LD_LIBRARY_PATH:-} ./host_hybrid 2>&1 | tee fire_ubu1.log
    echo === done ===
'"

# Pull artifacts back
scp "ubu-1:$REMOTE_ROOT/hyb/compile_ubu1.log"   "$LOCAL_DIR/"  || true
scp "ubu-1:$REMOTE_ROOT/hyb/fire_ubu1.log"      "$LOCAL_DIR/"  || true
scp "ubu-1:$REMOTE_ROOT/hyb/result.json"        "$LOCAL_DIR/result_ubu1.json"  || true
scp "ubu-1:$REMOTE_ROOT/hyb/ptxas_info.log"     "$LOCAL_DIR/ptxas_info_ubu1.log" || true

echo "==> done. Artifacts in $LOCAL_DIR"
