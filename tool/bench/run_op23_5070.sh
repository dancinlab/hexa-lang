#!/usr/bin/env bash
# run_op23_5070.sh — HEXA-0POD OP-23 driver (aiden RTX 5070 sm_120, FREE pool, NO vast).
# Builds the TF32-vs-FP64 N-step trajectory-drift harness (DEFAULT + PEDANTIC) and runs it
# at a representative config that fits + runs on the 5070, for N>=50 steps.
#
# idle-guard: refuses to start a timed run until the GPU is idle (util<5% & mem<800MiB),
# because a parallel agent may share the card.
set -u
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
SRC=${SRC:-flame_traj_drift_tf32_op23.cu}
ARCH=${ARCH:-sm_120}
N=${N:-100}

echo "=== OP-23 env ==="; nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader; nvcc --version | tail -1

idle_guard(){
  for i in $(seq 1 60); do
    read u m < <(nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits | head -1 | tr ',' ' ')
    if [ "${u:-100}" -lt 5 ] && [ "${m:-99999}" -lt 800 ]; then return 0; fi
    echo "[idle-guard] GPU busy (util=${u}% mem=${m}MiB) — waiting ${i}/60..."; sleep 10
  done
  echo "[idle-guard] gave up waiting; proceeding anyway"; return 0
}

build(){ # $1=extra-def $2=out
  echo "=== build $2 ==="
  nvcc -arch=$ARCH -O3 $INC $1 -o "$2" "$SRC" -lcublas || { echo "BUILD FAIL $2"; exit 1; }
}

build "" flame_traj_op23
build "-DPEDANTIC" flame_traj_op23_ped

run(){ # $1=bin $2=D $3=T $4=B
  idle_guard
  echo "=== run $1  D=$2 T=$3 B=$4 N=$N ==="
  "./$1" "$2" "$3" "$4" "$N"
}

# representative configs that fit + run on the 5070 (12GB). small D/T/E.
# B=1 = the latency-bound regime the ~3x cap is named for; B=8 = compute-bound.
run flame_traj_op23     768 256 1
run flame_traj_op23     768 256 8
run flame_traj_op23     1536 256 1
run flame_traj_op23_ped 768 256 1

echo "=== OP-23 done ==="
nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader
