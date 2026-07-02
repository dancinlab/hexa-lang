#!/usr/bin/env bash
# own_start_nm_clean_gate.sh — GATE-1 invariant guard for the #29 own-start ship.
#
# Builds build/runtime.a with HEXA_ZEROC_OWN_START=1 (the shipped ON-path once
# PR-C flipped the default on linux) and asserts:
#   (a) ZERO glibc startup/atexit U-references: ` U (atexit|__cxa_atexit|__dso_handle)`
#   (b) own `_start` is DEFINED (T _start)
# Rationale: with -nostartfiles the final link drops crt1/crti — if a runtime.c
# edit reintroduces a libc atexit/dso-handle U-ref, the crt-drop link breaks the
# shipped binary. This gate catches that at PR time, on the SAME build path the
# release runs (tool/stage_resolve_runtime_a), NOT a lexical proxy.
set -euo pipefail
ROOT="${ROOT:-$PWD}"
cd "$ROOT"

# Build runtime.a via the release SSOT with own-start ON. EDGE_ASSET is a
# placeholder only to satisfy the ${EDGE_ASSET:?} guard evaluated BEFORE the
# frozen-seed source-build branch (the source path exits 0 before any edge
# tarball fetch — validated on summer, wf wdxedope8 GATE-1).
# HEXA_RT_MULTIOBJ=1 mirrors tool/release_build's default so the gate audits the
# SHIP archive shape ({runtime.o, runtime_core.o, hxlcl_shim.o, seeds}), not the
# single-TU one. The single-TU gate stayed GREEN while the MULTIOBJ ship archive
# carried a glibc `U atexit` in hxlcl_shim.o (compiled without $_zc_own_def) →
# -nostartfiles hexat link died on crtbegin's __dso_handle (measured aiden
# release_build @ main a372449a). Archive-shape drift between gate and ship is
# exactly what this gate exists to prevent — key it to the ship default.
CC="${CC:-clang}" \
HEXA_ZEROC_OWN_START=1 \
HEXA_RT_MULTIOBJ="${HEXA_RT_MULTIOBJ:-1}" \
EDGE_ASSET="${EDGE_ASSET:-hexa-linux-x86_64.tar.gz}" \
  bash tool/stage_resolve_runtime_a

test -f build/runtime.a || { echo "GATE-1: build/runtime.a not produced"; exit 1; }

# (a) offending glibc startup/atexit U-refs — MUST be empty.
OFFENDERS="$(nm build/runtime.a 2>/dev/null \
  | grep -E ' U (atexit|__cxa_atexit|__dso_handle)$' || true)"
if [ -n "$OFFENDERS" ]; then
  echo "GATE-1 FAIL: runtime.a(HEXA_ZEROC_OWN_START=1) has glibc startup/atexit U-refs:"
  echo "$OFFENDERS"
  echo "-> -nostartfiles ship would break the link. Reroute this ref to the own"
  echo "   atexit-LIFO (_hxlcl_atexit_drain) instead of pulling libc atexit."
  exit 1
fi

# (b) own _start MUST be DEFINED (T).
if ! nm build/runtime.a 2>/dev/null | grep -qE '^[0-9a-f]+ T _start$'; then
  echo "GATE-1 FAIL: own '_start' is NOT defined (T) in runtime.a(env=1)."
  echo "-> crt-drop link has no entry point. Restore the own _start scaffold."
  exit 1
fi

echo "GATE-1 PASS: runtime.a(HEXA_ZEROC_OWN_START=1) is nm-clean"
echo "  - no glibc atexit/__cxa_atexit/__dso_handle U-refs"
echo "  - own _start DEFINED (T)"
