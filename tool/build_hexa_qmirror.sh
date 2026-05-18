#!/bin/bash
# tool/build_hexa_qmirror.sh — build the standalone `hexa qmirror` sub-binary.
#
# R7 track B cycle 2 (2026-05-18): qmirror is the 2nd absorbed-verb sub-binary
# (after qrng cycle 1). Same pattern as tool/build_hexa_qrng.sh.
#
# Output: bin/hexa-qmirror (Mach-O on Darwin, ELF on Linux). The dispatcher at
# self/main.hexa::dispatch_absorbed sub == "qmirror" branch prefers this binary
# over the legacy cmd_run() interp path when present.
#
# Note: stdlib/quantum/quantum.hexa is a thin dispatcher — its sub-module
# invocations (chsh, iit, qrng, rqaoa, ...) still call `hexa run <module>`
# internally. Those are separate sunset targets for R7 track B.
#
# Usage:
#   bash tool/build_hexa_qmirror.sh
#   HEXA_QMIRROR_OUT=/path/to/out bash tool/build_hexa_qmirror.sh

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${repo}/stdlib/quantum/quantum.hexa"
out="${HEXA_QMIRROR_OUT:-${repo}/bin/hexa-qmirror}"

if [[ ! -f "${src}" ]]; then
    echo "error: qmirror source missing: ${src}" >&2
    exit 1
fi

mkdir -p "$(dirname "${out}")"

echo "[build_hexa_qmirror] src=${src}"
echo "[build_hexa_qmirror] out=${out}"
HEXA_MAC_BUILD_OK=1 hexa build "${src}" -o "${out}"
rc=$?
if [[ ${rc} -ne 0 ]]; then
    echo "error: hexa build failed (rc=${rc})" >&2
    exit ${rc}
fi

# Smoke: --version must report 2.6.0 (current SSOT version in source).
echo "[build_hexa_qmirror] smoke: ${out} --version"
smoke_out="$("${out}" --version 2>&1)"
if ! echo "${smoke_out}" | grep -q "hexa qmirror 2.6.0"; then
    echo "error: qmirror --version smoke FAIL — expected 'hexa qmirror 2.6.0'" >&2
    echo "${smoke_out}" >&2
    exit 2
fi
echo "[build_hexa_qmirror] OK -> ${out}"
