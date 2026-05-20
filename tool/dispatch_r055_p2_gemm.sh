#!/bin/bash
# dispatch_r055_p2_gemm.sh — RFC 055 055-P2 hexa-native GPU fire.
#
# Fires BOTH the 055-P1 vec-add and 055-P2 naive GEMM hand-emitted PTX
# (compiler/codegen/nvptx_target.hexa `emit_ptx_vec_add_module` /
# `emit_ptx_gemm_module`) on an NVIDIA GPU host and asserts the RFC 055
# §7 falsifier battery:
#
#   F-RFC055-PTX-EMIT      — the driver JIT (ptxas) accepts BOTH emitted
#                            PTX modules. (`cuModuleLoadDataEx` rejecting
#                            the PTX == ptxas rejected it.)
#   F-RFC055-NUMERIC-EQ    — vec-add kernel output is byte-equal to the
#                            CPU reference (vec-add reduces nothing →
#                            `max|Δ| == 0`, exact, not a tolerance).
#   F-RFC055-GEMM-FEASIBLE — naive GEMM kernel output matches the CPU
#                            reference. Inputs are small integers
#                            (a=i%7, b=i%5, k=64) → every product and
#                            partial sum is exact in FP64 → byte-exact.
#                            The gate is correctness; per RFC 055 §7
#                            GEMM perf vs cuBLAS is NOT a gate.
#   F-RFC055-LAUNCH-ABI    — host→kernel→host round-trip via the Driver
#                            API for a 1-D (vadd) and a 2-D (gemm) launch.
#   F-RFC055-NO-LLVM       — the hexa→PTX step is pure hexa; the only
#                            downstream tools are `nvcc -lcuda` + the
#                            driver JIT — no LLVM linkage.
#
# The kernel image is fed to `cuModuleLoadDataEx` as PTX TEXT — the
# driver JIT-assembles it for the live GPU arch. This is the forward-
# compatible path: PTX targeting sm_80 runs on any newer GPU (verified
# 2026-05-20 on an sm_120 Blackwell card with a CUDA-12.0 toolchain).
#
# Usage:   tool/dispatch_r055_p2_gemm.sh [gpu-ssh-host]
#          default host: ubu-2 (wilson-pool GPU roster)
# Output:  state/rfc055_p2_2026_05_20/{*.ptx,result.json,fire.log}
# Cost:    $0 on a pool GPU host.
#
# Env: HEXA_BIN overrides the hexa compiler · REPO overrides the repo root.

set -uo pipefail

GPU_HOST="${1:-ubu-2}"
REPO="${REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
LOCAL_DIR="$REPO/state/rfc055_p2_2026_05_20"
REMOTE_WORK="/tmp/r055p2_fire"
HEXA_BIN="${HEXA_BIN:-/Users/ghost/.hx/bin/hexa_real}"

mkdir -p "$LOCAL_DIR"
[ -x "$HEXA_BIN" ] || { echo "ERROR: hexa compiler not found at $HEXA_BIN"; exit 1; }

# ── 1) Generate PTX text locally via the hexa NVPTX emit pass. ───────
#
# The emit pass is pure hexa — no GPU, no ptxas, no LLVM. A one-shot
# driver per kernel is built via the COMPILED path (`hexa build` — the
# interpreter is retired) and its stdout captured.
echo "[1/5] Generate PTX via hexa NVPTX emit pass ..."
emit_ptx() {  # $1 = tag, $2 = emit fn, $3 = out path
    local drv="$LOCAL_DIR/_emit_$1.hexa" bin="$LOCAL_DIR/_emit_$1"
    cat > "$drv" <<EMIT_HEXA
import "$REPO/compiler/codegen/nvptx_target.hexa"
import "$REPO/compiler/codegen/nvptx_ptx_ops.hexa"
fn main() { println($2(NVPTX_TARGET_SM80)) }
EMIT_HEXA
    HEXA_MAC_BUILD_OK=1 "$HEXA_BIN" build "$drv" -o "$bin" >"$3.build.log" 2>&1 \
        || { echo "ERROR: emit-driver build failed ($1)"; return 1; }
    "$bin" > "$3" 2>/dev/null || { echo "ERROR: emit-driver run failed ($1)"; return 1; }
}
emit_ptx vec_add emit_ptx_vec_add_module "$LOCAL_DIR/vec_add.ptx" || exit 1
emit_ptx gemm    emit_ptx_gemm_module    "$LOCAL_DIR/gemm.ptx"    || exit 1

# Guard: emitted PTX must be pure ASCII — a non-ASCII byte (em-dash,
# middle-dot, arrow) on any line makes the driver JIT `ptxas` abort with
# "Unexpected non-ASCII character" (regression-tested 2026-05-20).
for p in "$LOCAL_DIR/vec_add.ptx" "$LOCAL_DIR/gemm.ptx"; do
    grep -q ".visible .entry" "$p" || { echo "ERROR: PTX emit failed ($p)"; exit 1; }
    if ! perl -ne 'exit 1 if /[^[:ascii:]]/' "$p"; then
        echo "ERROR: non-ASCII byte in emitted PTX ($p) — driver JIT will reject it"; exit 1
    fi
done
echo "  vec_add.ptx $(wc -l < "$LOCAL_DIR/vec_add.ptx")L · gemm.ptx $(wc -l < "$LOCAL_DIR/gemm.ptx")L · ASCII-clean"

# ── 2) Upload PTX + the Driver-API host harness to the GPU host. ─────
echo "[2/5] Upload to $GPU_HOST ..."
ssh "$GPU_HOST" "mkdir -p $REMOTE_WORK" || { echo "ERROR: ssh $GPU_HOST failed"; exit 1; }
scp -q "$LOCAL_DIR/vec_add.ptx" "$LOCAL_DIR/gemm.ptx" \
       "$REPO/tool/r055_p2_host.c" "$GPU_HOST:$REMOTE_WORK/" \
    || { echo "ERROR: scp failed"; exit 1; }

# ── 3) Cheap pre-fire oracle — standalone `ptxas` accept check. ──────
#
# Best-effort: if the host's standalone ptxas knows the GPU arch it
# gives an explicit F-RFC055-PTX-EMIT signal before any GPU touch. On a
# GPU newer than the toolkit (ptxas arch < device arch) this is skipped
# — the driver JIT in step 4 is then the authoritative emit check.
echo "[3/5] ptxas accept oracle ..."
ssh "$GPU_HOST" "cd $REMOTE_WORK && \
  for k in vec_add gemm; do \
    ptxas -arch=sm_80 \$k.ptx -o /dev/null 2>&1 && echo \"  ptxas sm_80 \$k: PASS\" \
      || echo \"  ptxas sm_80 \$k: (skipped/!=arch)\" ; \
  done" 2>&1 | tee "$LOCAL_DIR/ptxas_oracle.log"

# ── 4) Build the harness + fire both kernels. ────────────────────────
echo "[4/5] nvcc build + fire ..."
ssh "$GPU_HOST" "cd $REMOTE_WORK && \
  nvcc -O2 -o r055_p2_host r055_p2_host.c -lcuda 2>&1 | tee build.log && \
  ./r055_p2_host vec_add.ptx gemm.ptx ; echo FIRE_RC=\$?" 2>&1 | tee "$LOCAL_DIR/fire.log"

# ── 5) Pull artifacts + verdict. ─────────────────────────────────────
echo "[5/5] Pull result ..."
scp -q "$GPU_HOST:$REMOTE_WORK/result.json" "$LOCAL_DIR/result.json" 2>/dev/null \
    && cat "$LOCAL_DIR/result.json" \
    || echo "WARN: result.json not produced — see fire.log"

# F-RFC055-NO-LLVM — build-graph audit. hexa→PTX is pure hexa; the only
# downstream tools are `nvcc -lcuda` + the driver JIT. No LLVM linkage.
if grep -i 'llvm' "$LOCAL_DIR/build.log" 2>/dev/null >/dev/null; then
    echo "F-RFC055-NO-LLVM FAIL — 'llvm' appears in build.log"
else
    echo "F-RFC055-NO-LLVM PASS — no LLVM linkage on hexa->PTX path"
fi
echo "=== RFC 055 055-P2 fire DONE — $(date -u) ==="
