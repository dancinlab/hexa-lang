#!/usr/bin/env bash
# own_gemm_perf_gate.sh — HEXA-FUSION E3 CI PERF-REGRESSION gate for the LLM
# (hxqwen14b) own-GEMM (WMMA2-TUNED + split-K) vs the cuBLAS-TF32 oracle.
# ============================================================================
# SIBLING of the CORRECTNESS gate (llm_own_gemm_gate.sh, #2708). That gate
# checks WMMA2-vs-cuBLAS rel-RMS <= tol (does the own-GEMM still compute the
# RIGHT answer). THIS gate checks SPEED: does the own-GEMM still run FAST?
# It catches a future regression where someone edits the WMMA2 / tiled / split-K
# kernel and makes it SLOWER (e.g. a worse tile shape, a lost cp.async stage,
# a bank conflict, a dropped split-K tune) without breaking correctness.
#
# WHY RATIO-BASED (own/cuBLAS), NOT ABSOLUTE steps/s
# --------------------------------------------------
# Absolute steps/s are GPU-class-dependent (Blackwell B200 != H100 != future).
# Hardcoding "fail below 454.9 steps/s" would FALSE-FAIL on a slower runner and
# FALSE-PASS on a faster one. Instead we measure BOTH arms in the SAME process
# pair on the SAME GPU and check the RATIO own/cuBLAS — a property of the KERNEL
# (how close own-GEMM tracks cuBLAS), which is GPU-portable. A regression = the
# own-GEMM arm got RELATIVELY slower vs cuBLAS:
#       measured_ratio < BASELINE_RATIO * (1 - REL_TOL)
# Baseline ratio + tolerance live in own_gemm_perf_baseline.txt (GPU-class noted).
#
# HOW THE ARMS ARE SELECTED
# -------------------------
# The driver's `util` mode runs ONE backend per process; the backend is chosen
# purely by env vars read inside hxqwen14b_cuda.cu's GEMM shim:
#   cuBLAS-TF32 oracle : (no HEXA_OWN_GEMM* env)
#   own-GEMM (gate arm): HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_SPLITK=1
# So we build ONCE and run the SAME binary twice with different env.
#
# REQUIRES: an NVIDIA GPU + nvcc + cuBLAS (CUDA toolkit). NO-OP-SKIP (exit 0 with
# a SKIP message) on a host with no GPU/nvcc so a CPU-only CI lane is not broken;
# a GPU CI lane should treat a SKIP as "gate not run" and ensure a GPU runner.
# Mirrors the correctness gate's no-GPU handling exactly.
#
# CI INVOCATION:
#   bash tool/hexa-fusion/own_gemm_perf_gate.sh                 # M8192 R16, baseline file
#   GATE_SECS=3 bash tool/hexa-fusion/own_gemm_perf_gate.sh     # longer measure window
#   PERF_REL_TOL=0.20 bash .../own_gemm_perf_gate.sh            # override tolerance
#   GATE_M=16384 bash .../own_gemm_perf_gate.sh                 # different shape (note: baseline
#                                                                # ratio is for M8192; override
#                                                                # BASELINE_RATIO env if you change M)
# Exit 0 = PASS, 1 = FAIL (perf regression / build fail), 0+SKIP = no GPU/nvcc.
#
# CI WIRING NOTE: as of this commit the SIBLING correctness gate is NOT yet wired
# into any .github/workflows/*.yml (it is run on a GPU lane manually / out-of-band,
# since GH-hosted runners have no NVIDIA GPU). This perf gate mirrors that: it is
# meant for a self-hosted GPU CI lane. Wiring both gates into a GPU workflow is a
# follow-up (add a job with `runs-on: [self-hosted, gpu]` that runs both scripts;
# the SKIP guard keeps it harmless on a no-GPU runner). STATUS: authored locally,
# validated-on-CI-GPU-lane PENDING (this is authoring; no GPU was rented to test).
# ============================================================================
set -o pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/self/native/hxqwen14b_llmstep_driver.cu"
CU="$ROOT/self/native/hxqwen14b_cuda.cu"
BASELINE_FILE="${PERF_BASELINE_FILE:-$HERE/own_gemm_perf_baseline.txt}"
ARCH="${HEXA_GATE_ARCH:-compute_90}"   # PTX target; sm_90 JITs to Blackwell too

# ---- read baseline (KEY=VALUE, '#' comments) -------------------------------
bget() { grep -E "^$1=" "$BASELINE_FILE" 2>/dev/null | head -1 | sed -E "s/^$1=//"; }
if [ ! -f "$BASELINE_FILE" ]; then
  echo "[perf-gate] FAIL: baseline file not found: $BASELINE_FILE"; exit 1
fi
BASE_M="$(bget GATE_M)";       BASE_M="${BASE_M:-8192}"
BASE_R="$(bget GATE_R)";       BASE_R="${BASE_R:-16}"
BASELINE_RATIO="${BASELINE_RATIO:-$(bget BASELINE_RATIO)}"
REL_TOL="${PERF_REL_TOL:-$(bget REL_TOL)}"; REL_TOL="${REL_TOL:-0.15}"

M="${GATE_M:-$BASE_M}"; R="${GATE_R:-$BASE_R}"
K="${GATE_K:-1024}"; N="${GATE_N:-1024}"   # K/N from the driver's clm-scale default shapes
SECS="${GATE_SECS:-2.0}"                    # util-mode measure window (seconds)

if [ -z "$BASELINE_RATIO" ]; then
  echo "[perf-gate] FAIL: BASELINE_RATIO missing from $BASELINE_FILE (and not in env)"; exit 1
fi

# ---- no-GPU SKIP (mirror the correctness gate) -----------------------------
if ! command -v nvcc >/dev/null 2>&1; then
  echo "[perf-gate] SKIP: nvcc not found (no CUDA toolkit) — gate requires a GPU CI runner."
  exit 0
fi
if ! command -v nvidia-smi >/dev/null 2>&1 || ! nvidia-smi -L >/dev/null 2>&1; then
  echo "[perf-gate] SKIP: no NVIDIA GPU visible — gate requires a GPU CI runner."
  exit 0
fi

# ---- build the driver ONCE (same build line as the correctness gate) -------
BIN="$(mktemp -d)/own_gemm_perf"
echo "[perf-gate] building $SRC (arch=$ARCH) ..."
if ! nvcc -O3 -arch="$ARCH" -DHXQWEN14B_CUDA -Xcompiler -fPIC "$SRC" \
        -lcuda -lcudart -lcublas -lm -o "$BIN" 2>&1 | grep -v "declared but never"; then
  echo "[perf-gate] BUILD FAILED"; rm -rf "$(dirname "$BIN")"; exit 1
fi
[ -x "$BIN" ] || { echo "[perf-gate] BUILD FAILED (no binary)"; rm -rf "$(dirname "$BIN")"; exit 1; }

# ---- run util mode for each arm; parse "(NNN.N steps/s)" --------------------
parse_steps() { sed -nE 's/.*\(([0-9]+(\.[0-9]+)?) steps\/s\).*/\1/p' | tail -1; }

echo "[perf-gate] running cuBLAS-TF32 oracle arm (util, M=$M K=$K N=$N R=$R, ${SECS}s) ..."
CUBLAS_OUT="$(env -u HEXA_OWN_GEMM -u HEXA_OWN_GEMM_WMMA2 -u HEXA_OWN_GEMM_SPLITK \
              "$BIN" util "$M" "$K" "$N" "$R" "$SECS" 2>&1)"
echo "$CUBLAS_OUT"
CUBLAS_SPS="$(printf '%s\n' "$CUBLAS_OUT" | parse_steps)"

echo "[perf-gate] running own-GEMM arm (WMMA2-TUNED+splitK) (util, ${SECS}s) ..."
OWN_OUT="$(HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_SPLITK=1 \
           "$BIN" util "$M" "$K" "$N" "$R" "$SECS" 2>&1)"
echo "$OWN_OUT"
OWN_SPS="$(printf '%s\n' "$OWN_OUT" | parse_steps)"

rm -rf "$(dirname "$BIN")"

if [ -z "$CUBLAS_SPS" ] || [ -z "$OWN_SPS" ]; then
  echo "[perf-gate] FAIL: could not parse steps/s (cuBLAS='$CUBLAS_SPS' own='$OWN_SPS')"; exit 1
fi

# ---- ratio check (awk for float math; no bc dependency) --------------------
awk -v own="$OWN_SPS" -v cub="$CUBLAS_SPS" -v base="$BASELINE_RATIO" -v tol="$REL_TOL" '
BEGIN{
  if (cub<=0) { printf("[perf-gate] FAIL: cuBLAS steps/s non-positive (%s)\n", cub); exit 2 }
  ratio = own/cub;
  floor = base*(1.0-tol);
  printf("[perf-gate] own=%.1f steps/s  cuBLAS=%.1f steps/s\n", own, cub);
  printf("[perf-gate] measured own/cuBLAS ratio = %.4f\n", ratio);
  printf("[perf-gate] baseline ratio = %.4f, REL_TOL = %.2f -> floor = %.4f\n", base, tol, floor);
  if (ratio < floor) {
    printf("[perf-gate] RESULT: FAIL — own-GEMM RELATIVELY slower vs cuBLAS (%.4f < %.4f).\n", ratio, floor);
    printf("[perf-gate]   own-GEMM throughput regressed beyond the %.0f%% band vs baseline.\n", tol*100);
    exit 1;
  }
  if (ratio > base) {
    printf("[perf-gate] RESULT: PASS (own-GEMM IMPROVED vs baseline: %.4f > %.4f).\n", ratio, base);
  } else {
    printf("[perf-gate] RESULT: PASS (ratio %.4f within %.0f%% band of baseline %.4f).\n", ratio, tol*100, base);
  }
  exit 0;
}'
exit $?
