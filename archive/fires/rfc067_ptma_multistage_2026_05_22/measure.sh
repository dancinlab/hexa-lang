#!/usr/bin/env bash
# RFC 067 N201 multi-stage TMA SMOKE measure script.
# Run on ubu-1 (RTX 5070 sm_120). Builds host.c + ptxas-checks each PTX +
# fires kernel under cuModuleLoadDataEx driver-JIT.
set -eu

CUDA=/usr/local/cuda-12.9
DIR=${1:-.}
cd "$DIR"

# Build host driver once.
gcc -O2 -o host host.c -I${CUDA}/include -L/usr/lib/x86_64-linux-gnu -lcuda
echo "[build] host OK"

run_one() {
    local stages=$1
    local ptx="sgemm_tma_multistage_s${stages}.ptx"
    echo "=== STAGES=${stages} PTX=${ptx} ==="

    # ptxas info (sm_120a, --verbose)
    ${CUDA}/bin/ptxas --gpu-name=sm_120a -v -o /tmp/multistage_s${stages}.cubin ${ptx} \
        2>&1 | tee ptxas_info_s${stages}.log || {
        echo "[ptxas] FAILED for STAGES=${stages}"; return 1; }

    # Fire kernel.
    ./host ${ptx} ${stages} 2>&1 | tee fire_s${stages}.log
}

run_one 2
run_one 3
echo "[measure] done"
