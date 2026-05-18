#!/bin/bash
# tool/build_hexa_sim_universe.sh — build the standalone `hexa sim-universe`
# sub-binary.
#
# R7 track B cycle 3 (2026-05-18): sim-universe is the 3rd absorbed-verb
# sub-binary (after qrng cycle 1, qmirror cycle 2). Same pattern.
#
# Output: bin/hexa-sim-universe (Mach-O on Darwin, ELF on Linux). The
# dispatcher at self/main.hexa::dispatch_absorbed sub == "sim-universe" branch
# prefers this binary over the legacy cmd_run() interp path when present.
#
# Usage:
#   bash tool/build_hexa_sim_universe.sh
#   HEXA_SIM_UNIVERSE_OUT=/path/to/out bash tool/build_hexa_sim_universe.sh

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${repo}/stdlib/sim_universe/sim_universe.hexa"
out="${HEXA_SIM_UNIVERSE_OUT:-${repo}/bin/hexa-sim-universe}"

if [[ ! -f "${src}" ]]; then
    echo "error: sim-universe source missing: ${src}" >&2
    exit 1
fi

mkdir -p "$(dirname "${out}")"

echo "[build_hexa_sim_universe] src=${src}"
echo "[build_hexa_sim_universe] out=${out}"
HEXA_MAC_BUILD_OK=1 hexa build "${src}" -o "${out}"
rc=$?
if [[ ${rc} -ne 0 ]]; then
    echo "error: hexa build failed (rc=${rc})" >&2
    exit ${rc}
fi

# Smoke: --version must report 1.1.0 (current SSOT version in source).
echo "[build_hexa_sim_universe] smoke: ${out} --version"
smoke_out="$("${out}" --version 2>&1)"
if ! echo "${smoke_out}" | grep -q "hexa sim-universe 1.1.0"; then
    echo "error: sim-universe --version smoke FAIL — expected 'hexa sim-universe 1.1.0'" >&2
    echo "${smoke_out}" >&2
    exit 2
fi
echo "[build_hexa_sim_universe] OK -> ${out}"
