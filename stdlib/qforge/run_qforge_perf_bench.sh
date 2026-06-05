#!/usr/bin/env bash
# run_qforge_perf_bench.sh — build + run the 4 QFORGE-PERF Lane A GPU kernels
# on a rented CUDA-devel pod, print per-kernel PARITY + speedup verdicts.
#
#   K2  Davidson VᵀHV GPU-GEMM   (cuBLAS)  nvptx_davidson_vthv_host.cu
#   K3  Sternheimer CG resident  (driver PTX) nvptx_sternheimer_host.cu + .ptx
#   K4  cuFFT Poisson V_H        (cuFFT)   nvptx_poisson_cufft_host.cu
#   K1  H_apply GPU-GEMM         (hexa CUDA build → happly_gpu_bench.hexa)
#
# self-contained .cu harnesses (K2/K3/K4) need only nvcc + cublas/cufft/cuda
# driver. K1 needs the hexa runtime CUDA build (attempted; honest SKIP if the
# toolchain isn't buildable on the pod in-budget).
set -u
cd "$(dirname "$0")"
echo "############ nvcc / GPU env ############"
nvcc --version 2>&1 | tail -2
nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv,noheader 2>&1
echo

run_cu () {  # $1=src $2=out $3=lib  $4=label
  echo "############ $4 ############"
  if nvcc -O2 "$1" -o "$2" $3 2>build_$2.log; then
    echo "[build OK] $1"
    ./"$2" "${5:-}"; echo "[exit $?]"
  else
    echo "[BUILD FAILED] $1"; cat build_$2.log
  fi
  echo
}

run_cu nvptx_davidson_vthv_host.cu  nvptx_davidson_vthv  "-lcublas"        "K2 Davidson VᵀHV GPU-GEMM (cuBLAS)"
run_cu nvptx_sternheimer_host.cu    nvptx_sternheimer    "-lcuda"          "K3 Sternheimer CG GPU-resident"   nvptx_sternheimer_kernel.hexa.ptx
run_cu nvptx_poisson_cufft_host.cu  nvptx_poisson_cufft  "-lcufft -lcudart" "K4 cuFFT Poisson V_H"

echo "############ K1 H_apply GPU-GEMM (hexa CUDA build) ############"
echo "[note] K1 routes qforge_h_apply_forge through forge_dispatch_matmul;"
echo "       it needs the hexa runtime CUDA build. Attempt below (honest if SKIP)."
ls happly_gpu_bench.hexa >/dev/null 2>&1 && echo "[bench present] happly_gpu_bench.hexa" || echo "[bench MISSING]"
echo "DONE"
