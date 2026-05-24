#!/usr/bin/env bash
# RFC 067 N201 multi-stage TMA perf-proxy sweep (cliff regime).
# Run on ubu-1 (RTX 5070 sm_120).
set -eu

CUDA=/usr/local/cuda-12.9
cd "$(dirname "$0")"

# --- build ---------------------------------------------------------------
gcc -O2 -o host_perf host_perf.c -I${CUDA}/include -L/usr/lib/x86_64-linux-gnu -lcuda
echo "[build] host_perf OK"

gcc -O2 -o host_cublas host_cublas.c \
    -I${CUDA}/include -L${CUDA}/lib64 -L/usr/lib/x86_64-linux-gnu \
    -lcudart -lcublas \
    -Wl,-rpath,${CUDA}/lib64
echo "[build] host_cublas OK"

REPS=${REPS:-64}

# --- ptxas sanity --------------------------------------------------------
for ptx in sgemm_tma_perf_s*.ptx; do
    ${CUDA}/bin/ptxas --gpu-name=sm_120a -v -o /tmp/${ptx%.ptx}.cubin ${ptx} 2>&1 \
        | tee ptxas_info_${ptx%.ptx}.log >/dev/null
done

# --- perf-proxy sweep ----------------------------------------------------
echo "=== perf-proxy sweep (cliff regime M >= 4096) ==="
RESULT=results_raw.txt
: > $RESULT

for M in 1024 4096 6144 8192; do
    for KT in 64 256; do
        for STAGES in 1 2 3; do
            ptx=sgemm_tma_perf_s${STAGES}_k${KT}.ptx
            echo "--- M=$M  KT=$KT  STAGES=$STAGES" | tee -a $RESULT
            ./host_perf $ptx $M $KT $STAGES $REPS 2>&1 | tee -a $RESULT
            echo "" >> $RESULT
        done
    done
done

# --- cuBLAS reference ----------------------------------------------------
echo "=== cuBLAS HGEMM reference ==="
for M in 1024 4096 6144 8192; do
    for KT in 64 256; do
        K=$((KT * 16))
        # N=64 to match our kernel's K x N=64 B-tile shape.
        echo "--- cuBLAS  M=$M  K=$K  N=64" | tee -a $RESULT
        ./host_cublas $M $K 64 $REPS 2>&1 | tee -a $RESULT
        echo "" >> $RESULT
    done
done

echo "[measure_perf] done -> $RESULT"
