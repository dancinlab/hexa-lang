#!/bin/bash
# tool/build_hexa_atlas.sh — build the standalone `hexa atlas` sub-binary.
#
# R7 track B (2026-05-18): the FINAL verb. atlas_cli was the lone residual
# — module_loader DFS ping-ponged the compiler/atlas/static_index ↔
# prefix_index 2-import-cycle ~60,000× (instrumented), unbounded
# read_file+collect into the monotonic no-GC arena → 24 GB SIGKILL.
# Fixed by: (a) module_loader cycle-safe gray-set DFS (g_discovered_hs),
# (b) severing static_index→embedded.gen `use` (dist/atlas.hxc is the
# canonical runtime SSOT; embedded.gen stays the text SSOT for
# tool/atlas_build_hxc.hexa), (c) `list_dir` compiled codegen mapping +
# hexa_list_dir runtime.c/.h.
#
# Output: bin/hexa-atlas. Dispatcher at self/main.hexa sub == "atlas"
# prefers this binary; cmd_run fallback when absent.
#
# MUST use the repo-local hexa shim (stale-transpiler trap) + raised
# memcap (still text-SSOT-free but the flat is non-trivial).

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${repo}/tool/atlas_cli.hexa"
out="${HEXA_ATLAS_OUT:-${repo}/bin/hexa-atlas}"
hexa_bin="${repo}/hexa"
[ -x "${hexa_bin}" ] || hexa_bin="$(command -v hexa)"

if [[ ! -f "${src}" ]]; then
    echo "error: atlas_cli source missing: ${src}" >&2
    exit 1
fi

mkdir -p "$(dirname "${out}")"
echo "[build_hexa_atlas] src=${src}"
echo "[build_hexa_atlas] out=${out}"
HEXA_MAC_BUILD_OK=1 HEXA_MEM_UNLIMITED=1 "${hexa_bin}" build "${src}" -o "${out}"
rc=$?
if [[ ${rc} -ne 0 ]]; then
    echo "error: hexa build failed (rc=${rc})" >&2
    exit ${rc}
fi

# Smoke: help banner.
echo "[build_hexa_atlas] smoke"
smoke_out="$("${out}" 2>&1 | head -c 200)"
if ! echo "${smoke_out}" | grep -q "hexa atlas"; then
    echo "error: atlas smoke FAIL — no 'hexa atlas' banner" >&2
    echo "${smoke_out}" >&2
    exit 2
fi
echo "[build_hexa_atlas] OK -> ${out}"
