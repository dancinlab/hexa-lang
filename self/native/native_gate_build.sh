#!/usr/bin/env bash
# self/native/native_gate_build.sh — self-contained build + smoke harness for
# the native_gate LD_PRELOAD / DYLD_INSERT_LIBRARIES sandbox shim.
#
# native_gate.c is NO LONGER committed — native_gate_emit.hexa is the SSOT.
# This script REGENERATES native_gate.c from the emitter (byte-identical to the
# historic hand-written source — sha256 b340553c…, proven in PR #2218), then
# compiles native_gate.so.
#
# BUILD (Ubuntu / Linux):
#   ./self/native/native_gate_build.sh
#     1. hexa run self/native/native_gate_emit.hexa self/native/native_gate.c
#     2. cc -shared -fPIC -O2 -D_GNU_SOURCE -o self/native/native_gate.so \
#            self/native/native_gate.c -ldl
#
# SMOKE (Linux only — full LD_PRELOAD runtime refuse test, @L2):
#   ./self/native/native_gate_build.sh --smoke
#     builds, then under LD_PRELOAD=native_gate.so:
#       - a `.py` (or `.sh`) write MUST be REFUSED (EPERM)
#       - a control write to /tmp (allowlisted) MUST succeed
#     prints `NATIVE_GATE_SMOKE PASS` (exit 0) or `NATIVE_GATE_SMOKE FAIL` (exit 1).
#
# INSTALL (per-user, no root) — in ~/.bashrc or ~/.zshrc:
#   export LD_PRELOAD="$WS/hexa-lang/self/native/native_gate.so${LD_PRELOAD:+:$LD_PRELOAD}"
#
# OPT-OUT (emergency):
#   CLAUDX_NO_SANDBOX=1 <cmd>   — env gate (checked per-call, zero-cost when set).
#
# SSOT: self/native/native_gate_emit.hexa (emitter) +
#       airgenome/rules/airgenome.json#AG10 + self/sbpl/native.sb.

set -euo pipefail

# -- resolve repo root (script lives at <root>/self/native/) ------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

EMIT="self/native/native_gate_emit.hexa"
SRC="self/native/native_gate.c"
SO="self/native/native_gate.so"

# hexa CLI is `hexa run <file> <args>`; `hexa-run` is NOT on PATH. If anything
# in the chain expects `hexa-run`, prepend a shim dir.
if ! command -v hexa-run >/dev/null 2>&1; then
  SHIMDIR="$(mktemp -d)"
  trap 'rm -rf "$SHIMDIR"' EXIT
  cat >"$SHIMDIR/hexa-run" <<'SHIM'
#!/usr/bin/env bash
exec hexa run "$@"
SHIM
  chmod +x "$SHIMDIR/hexa-run"
  export PATH="$SHIMDIR:$PATH"
fi

# -- 1. regenerate native_gate.c from the emitter SSOT ------------------------
echo "[native_gate_build] regen $SRC from $EMIT"
hexa run "$EMIT" "$SRC"

# -- 2. compile the shared object ---------------------------------------------
echo "[native_gate_build] cc -shared -> $SO"
cc -shared -fPIC -O2 -D_GNU_SOURCE -o "$SO" "$SRC" -ldl

echo "[native_gate_build] built $SO"

# -- 3. optional --smoke: full LD_PRELOAD runtime refuse test (Linux) ---------
if [ "${1:-}" = "--smoke" ]; then
  echo "[native_gate_build] --smoke: LD_PRELOAD refuse test"

  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"; rm -rf "${SHIMDIR:-}"' EXIT

  SO_ABS="$ROOT/$SO"

  # (a) banned write: a .py under LD_PRELOAD must be REFUSED (non-zero / EPERM).
  banned="$WORK/refuse_me.py"
  if LD_PRELOAD="$SO_ABS" /bin/sh -c "echo blocked > '$banned'" 2>/dev/null; then
    refuse_ok=0   # write SUCCEEDED -- gate did NOT refuse -> FAIL
  else
    # confirm nothing hit disk
    [ -s "$banned" ] && refuse_ok=0 || refuse_ok=1
  fi

  # (b) control write: an allowlisted /tmp path must SUCCEED.
  control="$(mktemp)"
  if LD_PRELOAD="$SO_ABS" /bin/sh -c "echo ok > '$control'" 2>/dev/null && [ -s "$control" ]; then
    control_ok=1
  else
    control_ok=0
  fi
  rm -f "$control"

  echo "[native_gate_build]   banned .py write refused : $([ "$refuse_ok" = 1 ] && echo yes || echo NO)"
  echo "[native_gate_build]   /tmp control write ok    : $([ "$control_ok" = 1 ] && echo yes || echo NO)"

  if [ "$refuse_ok" = 1 ] && [ "$control_ok" = 1 ]; then
    echo "NATIVE_GATE_SMOKE PASS"
    exit 0
  else
    echo "NATIVE_GATE_SMOKE FAIL"
    exit 1
  fi
fi
