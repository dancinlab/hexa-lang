#!/usr/bin/env bash
# pod_validate.sh — HEXA-CUDA D2 silicon validation, run ON the H100 pod.
# Builds a FRESH hexa compiler from this branch's source, emits PTX for the
# cookbook vec-add + saxpy @gpu_kernel, ptxas-assembles for sm_90, then loads
# + launches the PTX on the real H100 via the CUDA driver API and checks the
# output against a CPU reference.  All stdout is captured verbatim for the verdict.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
ROOT="${ROOT:-/root/hexa-lang}"
SM="sm_90"
TGT="nvptx64-nvidia-cuda-sm90"
HERE="$ROOT/tools/hexa-cuda-validate"

line(){ printf '\n========== %s ==========\n' "$1"; }

line "ENV"
uname -a
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
which ptxas gcc || true
ptxas --version 2>&1 | head -3 || true
nvcc --version 2>&1 | head -4 || true

line "FRESH BUILD — bash tool/release_build (Stage 0/1/2 self-host)"
cd "$ROOT" || exit 9
export TARGET=linux-x86_64 CC=gcc LIBS="-lm -ldl"
if bash tool/release_build 2>&1 | tail -40; then
  echo "[build] release_build returned 0"
else
  echo "[build] release_build FAILED"; exit 10
fi
ls -la ./hexa ./hexad ./hxv2 ./hexa.real 2>/dev/null
HEXA="$ROOT/hexa"
[ -x "$HEXA" ] || { echo "[build] no ./hexa driver produced"; exit 11; }
echo "[build] hexa driver: $HEXA"
"$HEXA" --version 2>&1 | head -3 || true

emit_and_check () {
  local src="$1" entry="$2" which="$3"
  line "EMIT PTX — $which ($src)"
  rm -f "$src.ptx"
  "$HEXA" build "$src" --target=$TGT 2>&1 | tail -20
  if [ ! -s "$src.ptx" ]; then echo "[$which] NO PTX EMITTED"; return 1; fi
  echo "--- $src.ptx (first 80 lines) ---"
  sed -n '1,80p' "$src.ptx"
  echo "--- ($(wc -l < "$src.ptx") lines total) ---"

  line "PTXAS — $which (ptxas -arch=$SM, VERBATIM)"
  rm -f "$HERE/$which.cubin"
  set +e
  ptxas -arch=$SM -o "$HERE/$which.cubin" "$src.ptx" 2>"$HERE/$which.ptxas.log"
  local rc=$?
  set -e 2>/dev/null
  echo "ptxas exit=$rc"
  echo "--- ptxas stderr verbatim ---"
  cat "$HERE/$which.ptxas.log"
  echo "--- end ptxas stderr ---"
  if [ $rc -ne 0 ]; then echo "[$which] PTXAS FAILED (exit $rc)"; return 2; fi
  ls -la "$HERE/$which.cubin" && echo "[$which] PTXAS CLEAN -> cubin produced"

  line "DEVICE RUN — $which (CUDA driver API on real H100)"
  "$HERE/device_run" "$src.ptx" "$entry" "$which"
  local drc=$?
  echo "[$which] device_run exit=$drc"
  return $drc
}

line "COMPILE device_run.c"
CUDA="${CUDA_HOME:-/usr/local/cuda}"
gcc "$HERE/device_run.c" -o "$HERE/device_run" \
    -I"$CUDA/include" -L"$CUDA/lib64/stubs" -L"$CUDA/lib64" -lcuda -lm 2>&1 | tail -20
[ -x "$HERE/device_run" ] || { echo "[harness] device_run did not build"; exit 12; }

VA=0; SA=0
emit_and_check "$HERE/vecadd.hexa" "vec_add" "vecadd"; VA=$?
emit_and_check "$HERE/saxpy.hexa"  "saxpy"   "saxpy";  SA=$?

line "SUMMARY"
echo "vecadd_result_exit=$VA  saxpy_result_exit=$SA"
if [ $VA -eq 0 ] && [ $SA -eq 0 ]; then
  echo "OVERALL: BOTH KERNELS ptxas-CLEAN + DEVICE-CORRECT on $SM — D2 SILICON-PROVEN"
  exit 0
elif [ $VA -eq 0 ]; then
  echo "OVERALL: vecadd PROVEN; saxpy exit=$SA"
  exit 0
else
  echo "OVERALL: vecadd exit=$VA saxpy exit=$SA — see logs above"
  exit 1
fi
