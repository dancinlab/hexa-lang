#!/bin/bash
# tool/build_hexa_calc.sh — build the standalone `hexa calc` sub-binary.
#
# R7 track B cycle 9 (2026-05-18): calc is the 8th absorbed-verb sub-binary.
# Same shape as cycle 8 (verify) — depends on cycle 7 module_loader patch
# for cross-directory `use compiler/atlas/symbolic/*` flatten.

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${repo}/tool/calc_cli.hexa"
out="${HEXA_CALC_OUT:-${repo}/bin/hexa-calc}"

if [[ ! -f "${src}" ]]; then
    echo "error: calc_cli source missing: ${src}" >&2
    exit 1
fi

mkdir -p "$(dirname "${out}")"

echo "[build_hexa_calc] src=${src}"
echo "[build_hexa_calc] out=${out}"
HEXA_MAC_BUILD_OK=1 HEXA_MEM_CAP_MB="${HEXA_MEM_CAP_MB:-16384}" hexa build "${src}" -o "${out}"
rc=$?
if [[ ${rc} -ne 0 ]]; then
    echo "error: hexa build failed (rc=${rc})" >&2
    exit ${rc}
fi

# Smoke: --help prints calc surface.
echo "[build_hexa_calc] smoke: --help"
smoke_out="$("${out}" --help 2>&1)"
if ! echo "${smoke_out}" | grep -qi "calc\|usage\|TECS"; then
    echo "error: calc --help smoke FAIL — no recognizable banner" >&2
    echo "${smoke_out}" >&2
    exit 2
fi
echo "[build_hexa_calc] OK -> ${out}"
