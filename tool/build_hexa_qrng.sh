#!/bin/bash
# tool/build_hexa_qrng.sh — build the standalone `hexa qrng` sub-binary.
#
# R7 track B cycle 1 (2026-05-18): first absorbed-verb sub-binary, pattern-
# establishing for the remaining 15 verbs (lsp/test/bench/check/init/verify/
# calc/atlas/sim-universe/qmirror/batch/convergence/...).
#
# Output: bin/hexa-qrng (Mach-O on Darwin, ELF on Linux). The dispatcher at
# self/main.hexa::dispatch_absorbed sub == "qrng" branch prefers this binary
# over the legacy cmd_run() interp path when present.
#
# Usage:
#   bash tool/build_hexa_qrng.sh                   # default output bin/hexa-qrng
#   HEXA_QRNG_OUT=/path/to/out bash tool/build_hexa_qrng.sh
#
# Env:
#   HEXA_MAC_BUILD_OK=1   bypass Darwin /tmp panic guard (auto-set inside)
#   HEXA_QRNG_OUT=<path>  override output path (defaults to repo bin/hexa-qrng)

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${repo}/stdlib/qrng/qrng.hexa"
out="${HEXA_QRNG_OUT:-${repo}/bin/hexa-qrng}"

if [[ ! -f "${src}" ]]; then
    echo "error: qrng source missing: ${src}" >&2
    exit 1
fi

mkdir -p "$(dirname "${out}")"

echo "[build_hexa_qrng] src=${src}"
echo "[build_hexa_qrng] out=${out}"
HEXA_MAC_BUILD_OK=1 hexa build "${src}" -o "${out}"
rc=$?
if [[ ${rc} -ne 0 ]]; then
    echo "error: hexa build failed (rc=${rc})" >&2
    exit ${rc}
fi

# Smoke: aggregate selftest must report ALL PASS for the built binary.
echo "[build_hexa_qrng] smoke: ${out}"
smoke_out="$("${out}" 2>&1)"
if ! echo "${smoke_out}" | grep -q "__QRNG_MAIN__ PASS"; then
    echo "error: qrng aggregate smoke FAIL — expected '__QRNG_MAIN__ PASS'" >&2
    echo "${smoke_out}" >&2
    exit 2
fi
echo "[build_hexa_qrng] OK -> ${out}"
