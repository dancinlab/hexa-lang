#!/bin/sh
# tool/find_local_hexa.sh — POSIX-sh probe for a local hexa interpreter binary.
#
# Background (M0 smoke report Gap 6, commit b437a77c):
#   The user's shell wrapper at $HOME/.hx/bin/hexa unconditionally routes
#   `hexa run` over TCP to a remote `hexa-r ubu-1` host (resource toolkit).
#   The wrapper IGNORES RESOURCE_LOCAL_HEXA. The remote route drops
#   --target / --emit / -o flags, which makes the M0 harness unrunnable
#   on a fresh dev box without a manual bypass.
#
# This helper prints — to stdout — the absolute path of the FIRST locally
# executable hexa interpreter binary it finds, in priority order. Callers
# (tests, CI scripts) should `exec "$(tool/find_local_hexa.sh)" run ...`.
#
# Probe order:
#   1. $HEXA_INTERP                       (user override; most explicit)
#   2. build/hexa_interp.darwin           (Darwin host vendored binary)
#      build/hexa_interp.linux            (Linux host vendored binary)
#   3. self/native/hexa_v2                (self-hosted compiler binary)
#   4. /usr/local/bin/hexa_real           (system-wide bypass install)
#   5. $HOME/.hx/bin/hexa_real            (per-user bypass install)
#
# A path is accepted only if:
#   - it exists and is executable
#   - it is NOT a shell-script wrapper (we grep for the resource-toolkit
#     routing marker `hexa-r ubu-1`; if found, we skip — it's a remote
#     wrapper masquerading as a local binary).
#
# On failure prints a diagnostic to stderr and exits 1.
#
# Usage:
#   HEXA_BIN="$(tool/find_local_hexa.sh)" || exit 1
#   "$HEXA_BIN" run compiler/main.hexa --target=arm64-apple-darwin ...

set -eu

# Resolve repo root from script location so callers can invoke from anywhere.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

# is_local_binary <path> -> 0 if executable AND not a remote-routing wrapper.
is_local_binary() {
    p=$1
    [ -n "$p" ] || return 1
    [ -x "$p" ] || return 1
    # Reject the resource-toolkit remote-routing wrapper. The marker is
    # stable across the two known wrapper variants (~/.hx/bin/hexa and
    # build/hexa_interp.real both contain `hexa-r ubu`).
    if head -c 4096 "$p" 2>/dev/null | grep -q 'hexa-r ubu' 2>/dev/null; then
        return 1
    fi
    return 0
}

uname_s=$(uname -s 2>/dev/null || echo unknown)

# 1) explicit env override
if [ "${HEXA_INTERP:-}" != "" ]; then
    if is_local_binary "$HEXA_INTERP"; then
        printf '%s\n' "$HEXA_INTERP"
        exit 0
    fi
    printf 'find_local_hexa: HEXA_INTERP=%s is not a usable local binary\n' "$HEXA_INTERP" >&2
fi

# 2) host-specific vendored binary in build/
case "$uname_s" in
    Darwin) host_bin="$REPO_ROOT/build/hexa_interp.darwin" ;;
    Linux)  host_bin="$REPO_ROOT/build/hexa_interp.linux"  ;;
    *)      host_bin="" ;;
esac
if [ -n "$host_bin" ] && is_local_binary "$host_bin"; then
    printf '%s\n' "$host_bin"
    exit 0
fi

# 3) self-hosted compiler binary (Mach-O on macOS dev boxes)
self_bin="$REPO_ROOT/self/native/hexa_v2"
if is_local_binary "$self_bin"; then
    printf '%s\n' "$self_bin"
    exit 0
fi

# 4) system-wide bypass install
if is_local_binary "/usr/local/bin/hexa_real"; then
    printf '%s\n' "/usr/local/bin/hexa_real"
    exit 0
fi

# 5) per-user bypass install
if [ "${HOME:-}" != "" ] && is_local_binary "$HOME/.hx/bin/hexa_real"; then
    printf '%s\n' "$HOME/.hx/bin/hexa_real"
    exit 0
fi

cat >&2 <<EOF
find_local_hexa: no local hexa interpreter found.

Searched (in order):
  HEXA_INTERP                  = ${HEXA_INTERP:-<unset>}
  build/hexa_interp.<host>     = ${host_bin:-<no host match>}
  self/native/hexa_v2          = $self_bin
  /usr/local/bin/hexa_real
  \$HOME/.hx/bin/hexa_real      = ${HOME:-<unset>}/.hx/bin/hexa_real

The shell wrapper at \$HOME/.hx/bin/hexa routes 'hexa run' to a remote
TCP server and drops --target/--emit/-o, so it cannot be used for the
M0 smoke harness. See doc/m0_local_bypass.md.

Fix: set HEXA_INTERP=/abs/path/to/local/hexa_interp, or vendor a host
binary at build/hexa_interp.\$(uname -s | tr A-Z a-z).
EOF
exit 1
