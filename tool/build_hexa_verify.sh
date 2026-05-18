#!/bin/bash
# tool/build_hexa_verify.sh — build the standalone `hexa verify` sub-binary.
#
# R7 track B cycle 8 (2026-05-18): verify is the 7th absorbed-verb sub-binary
# and the first to exercise the cycle-7 module_loader patch for cross-directory
# `use compiler/atlas/*` flatten.
#
# Output: bin/hexa-verify. Dispatcher at self/main.hexa::dispatch_absorbed
# sub == "verify" prefers this binary over the legacy cmd_run() interp path.
#
# Note: requires HEXA_MEM_CAP_MB raise (e.g. 16384) — the build pipeline's
# default 4096 MB cap on module_loader is too tight for typical
# compiler/atlas/symbolic/* trees.

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${repo}/tool/verify_cli.hexa"
out="${HEXA_VERIFY_OUT:-${repo}/bin/hexa-verify}"

if [[ ! -f "${src}" ]]; then
    echo "error: verify_cli source missing: ${src}" >&2
    exit 1
fi

mkdir -p "$(dirname "${out}")"

echo "[build_hexa_verify] src=${src}"
echo "[build_hexa_verify] out=${out}"
HEXA_MAC_BUILD_OK=1 HEXA_MEM_CAP_MB="${HEXA_MEM_CAP_MB:-16384}" hexa build "${src}" -o "${out}"
rc=$?
if [[ ${rc} -ne 0 ]]; then
    echo "error: hexa build failed (rc=${rc})" >&2
    exit ${rc}
fi

# Smoke: no-arg invocation prints help banner with rc=0.
echo "[build_hexa_verify] smoke: no-arg banner"
smoke_out="$("${out}" 2>&1)"
if ! echo "${smoke_out}" | grep -q "hexa verify"; then
    echo "error: verify no-arg smoke FAIL — expected 'hexa verify' header" >&2
    echo "${smoke_out}" >&2
    exit 2
fi
echo "[build_hexa_verify] OK -> ${out}"
