#!/bin/bash
# build_hexa_cli.sh — compile the hexa CLI driver as a NATIVE BINARY.
#
# interp-retirement R7 gates #2 + #4. Today `hexa build` / `hexa parse` /
# `hexa cc` run ON the interpreter (the interpreter executes self/main.hexa,
# the CLI dispatch driver). The interpreter cannot be deleted until the
# driver runs compiled. This recipe produces that compiled driver.
#
# Two binaries are built:
#   build/hexa_cli_driver     — compiled self/main.hexa  (the CLI dispatcher)
#   build/hexa_module_loader  — compiled self/module_loader.hexa (import flattener)
#
# Gate #4: self/main.hexa has NO import/use directives — it is fully
# self-contained, so its compiled closure is just main.hexa + runtime.c.
# module_loader.hexa is NOT in that closure; the driver invokes it as a
# separate CHILD PROCESS at runtime (cmd_build flatten step). So the loader
# needs its own compiled binary. resolve_module_loader_compiled() in
# main.hexa probes build/hexa_module_loader and, when present, runs the
# flatten step interp-free.
#
# Pipeline (mirrors tool/build_interp.hexa single-TU model):
#   1. hexa_v2  self/main.hexa          build/stage1/main_native.c
#   2. hexa_v2  self/module_loader.hexa build/stage1/module_loader.c
#   3. clang  <stageN.c>  self/runtime.c  -o <out>     (runtime.c as 2nd TU)
#   4. codesign (Darwin)
#   5. smoke: --version / parse / build round-trip
#
# Note: hexa_v2 emits `#include "runtime.h"` (decl-only header, PHASE 1.6).
# runtime.c is appended as a separate translation unit so the rt_*/hexa_*
# definitions link. `-I self` resolves the runtime.h include path.
#
# Env:
#   CLANG         compiler override (default: clang)
#   SKIP_TRANSPILE=1   reuse existing build/stage1/*.c
#   NO_SMOKE=1    skip the smoke test
#
# Usage:
#   tool/build_hexa_cli.sh
#   # install (optional):
#   #   cp build/hexa_cli_driver    ~/.hx/bin/hexa.real
#   #   cp build/hexa_module_loader ~/core/hexa-lang/build/hexa_module_loader

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HEXA_V2="$REPO_ROOT/self/native/hexa_v2"
MAIN_HEXA="$REPO_ROOT/self/main.hexa"
ML_HEXA="$REPO_ROOT/self/module_loader.hexa"
STAGE1="$REPO_ROOT/build/stage1"
MAIN_C="$STAGE1/main_native.c"
ML_C="$STAGE1/module_loader.c"
DRIVER_OUT="$REPO_ROOT/build/hexa_cli_driver"
ML_OUT="$REPO_ROOT/build/hexa_module_loader"
RUNTIME_C="$REPO_ROOT/self/runtime.c"
INC="$REPO_ROOT/self"

CLANG="${CLANG:-clang}"
UNAME="$(uname 2>/dev/null | tr -d ' \n\t')"

[ -x "$HEXA_V2" ] || { echo "error: hexa_v2 missing: $HEXA_V2 (run \`hexa cc\` first)" >&2; exit 1; }
[ -f "$MAIN_HEXA" ] || { echo "error: source missing: $MAIN_HEXA" >&2; exit 1; }
[ -f "$ML_HEXA" ]   || { echo "error: source missing: $ML_HEXA" >&2; exit 1; }

mkdir -p "$STAGE1" "$REPO_ROOT/build"

# Linux needs _GNU_SOURCE + -lm -ldl; Darwin sizes the stack for deep recursion.
if [ "$UNAME" = "Linux" ]; then
    CFLAGS="-O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -fbracket-depth=4096 -I $INC"
    LDFLAGS="-lpthread -lm -ldl"
else
    CFLAGS="-O2 -std=c11 -D_GNU_SOURCE -Wno-trigraphs -fbracket-depth=4096 -I $INC"
    LDFLAGS="-lpthread -lm -Wl,-stack_size,0x4000000"
fi

# ── Step 1+2: transpile ───────────────────────────────────────────────
if [ "${SKIP_TRANSPILE:-}" = "" ]; then
    echo "[1/5] transpile main.hexa          → $MAIN_C"
    "$HEXA_V2" "$MAIN_HEXA" "$MAIN_C"
    echo "[2/5] transpile module_loader.hexa → $ML_C"
    "$HEXA_V2" "$ML_HEXA" "$ML_C"
fi
[ -f "$MAIN_C" ] || { echo "error: transpiled C missing: $MAIN_C" >&2; exit 1; }
[ -f "$ML_C" ]   || { echo "error: transpiled C missing: $ML_C" >&2; exit 1; }

# ── Step 3: compile (runtime.c appended as 2nd TU) ─────────────────────
echo "[3/5] compile hexa_cli_driver"
$CLANG $CFLAGS "$MAIN_C" "$RUNTIME_C" -o "$DRIVER_OUT" $LDFLAGS
echo "[3/5] compile hexa_module_loader"
$CLANG $CFLAGS "$ML_C" "$RUNTIME_C" -o "$ML_OUT" $LDFLAGS

# ── Step 4: Darwin codesign ────────────────────────────────────────────
if [ "$UNAME" = "Darwin" ]; then
    echo "[4/5] codesign (Darwin)"
    codesign --force --sign - "$DRIVER_OUT" 2>/dev/null || true
    codesign --force --sign - "$ML_OUT" 2>/dev/null || true
fi

# ── Step 5: smoke ──────────────────────────────────────────────────────
if [ "${NO_SMOKE:-}" = "" ]; then
    echo "[5/5] smoke"
    SMOKE_SRC="$(mktemp -t hexa_cli_smoke.XXXXXX).hexa"
    SMOKE_BIN="$(mktemp -t hexa_cli_smoke_bin.XXXXXX)"
    printf 'fn main() {\n    println("hexa-cli-smoke-ok")\n}\n' > "$SMOKE_SRC"

    "$DRIVER_OUT" --version >/dev/null || { echo "  FAIL --version" >&2; exit 1; }
    echo "  OK   --version"
    "$DRIVER_OUT" parse "$SMOKE_SRC" >/dev/null || { echo "  FAIL parse" >&2; exit 1; }
    echo "  OK   parse"
    HEXA_LANG="$REPO_ROOT" HEXA_MAC_BUILD_OK=1 \
        "$DRIVER_OUT" build "$SMOKE_SRC" -o "$SMOKE_BIN" >/dev/null \
        || { echo "  FAIL build" >&2; exit 1; }
    OUT="$("$SMOKE_BIN" 2>&1 || true)"
    [ "$OUT" = "hexa-cli-smoke-ok" ] || { echo "  FAIL build-run: got '$OUT'" >&2; exit 1; }
    echo "  OK   build (round-trip)"
    rm -f "$SMOKE_SRC" "$SMOKE_BIN"
fi

echo ""
echo "=== BUILD OK ==="
echo "  driver        : $DRIVER_OUT ($(wc -c < "$DRIVER_OUT" | tr -d ' ') bytes)"
echo "  module_loader : $ML_OUT ($(wc -c < "$ML_OUT" | tr -d ' ') bytes)"
echo ""
echo "install (optional):"
echo "  cp $DRIVER_OUT ~/.hx/bin/hexa.real"
echo "  # build/hexa_module_loader is auto-discovered by resolve_module_loader_compiled()"
