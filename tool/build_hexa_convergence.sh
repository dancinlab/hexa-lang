#!/bin/bash
# tool/build_hexa_convergence.sh — build the standalone `hexa convergence`
# sub-binary.
#
# R7 track B cycle 4 (2026-05-18): convergence is the 4th absorbed-verb
# sub-binary and the first shim-cluster member (cs_main → main rename in
# self/convergence_scan.hexa; module-level call removed).
#
# Output: bin/hexa-convergence. Dispatcher at self/main.hexa::
# dispatch_absorbed sub == "convergence" prefers this binary over
# the legacy cmd_run() interp path when present.
#
# Usage:
#   bash tool/build_hexa_convergence.sh
#   HEXA_CONVERGENCE_OUT=/path/to/out bash tool/build_hexa_convergence.sh

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${repo}/self/convergence_scan.hexa"
out="${HEXA_CONVERGENCE_OUT:-${repo}/bin/hexa-convergence}"

if [[ ! -f "${src}" ]]; then
    echo "error: convergence source missing: ${src}" >&2
    exit 1
fi

mkdir -p "$(dirname "${out}")"

echo "[build_hexa_convergence] src=${src}"
echo "[build_hexa_convergence] out=${out}"
HEXA_MAC_BUILD_OK=1 hexa build "${src}" -o "${out}"
rc=$?
if [[ ${rc} -ne 0 ]]; then
    echo "error: hexa build failed (rc=${rc})" >&2
    exit ${rc}
fi

# Smoke: no-arg invocation must print usage + exit 2 (cs_main contract).
echo "[build_hexa_convergence] smoke: usage on no-arg"
smoke_out="$("${out}" 2>&1)"
smoke_rc=$?
if [[ ${smoke_rc} -ne 2 ]] || ! echo "${smoke_out}" | grep -q "usage: hexa convergence"; then
    echo "error: convergence usage smoke FAIL — expected rc=2 + 'usage: hexa convergence'" >&2
    echo "rc=${smoke_rc}" >&2
    echo "${smoke_out}" >&2
    exit 3
fi
echo "[build_hexa_convergence] OK -> ${out}"
