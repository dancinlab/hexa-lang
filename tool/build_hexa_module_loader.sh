#!/bin/bash
# tool/build_hexa_module_loader.sh — build the compiled module_loader binary.
#
# R7 track B cycle 7 (2026-05-18): module_loader is the build-pipeline
# helper that flattens `use` statements before hexa_v2 transpilation.
# Production hexa.real invokes it via interp+module_loader.hexa, which is
# slow + macOS-OOM-prone for large trees (atlas/verify/calc tools).
#
# Compiling module_loader.hexa into build/hexa_module_loader gives the
# build pipeline (resolve_module_loader_compiled in self/main.hexa) a
# faster interp-free path. Same source serves both modes (module-level
# CLI wrapped in `fn main()` — interp auto-invokes main()).
#
# Output: build/hexa_module_loader. Used by `hexa build <file>` when
# install_dir contains this binary at $inst/build/hexa_module_loader.
#
# Note: module_loader.hexa has 0 `use` statements (self-contained), so the
# flatten step is a no-op for itself. Build proceeds via raw-src fallback
# even without an existing compiled module_loader. Bootstrap-safe.

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${repo}/self/module_loader.hexa"
out="${HEXA_MODULE_LOADER_OUT:-${repo}/build/hexa_module_loader}"

if [[ ! -f "${src}" ]]; then
    echo "error: module_loader source missing: ${src}" >&2
    exit 1
fi

mkdir -p "$(dirname "${out}")"

echo "[build_hexa_module_loader] src=${src}"
echo "[build_hexa_module_loader] out=${out}"
HEXA_MAC_BUILD_OK=1 hexa build "${src}" -o "${out}"
rc=$?
if [[ ${rc} -ne 0 ]]; then
    echo "error: hexa build failed (rc=${rc})" >&2
    exit ${rc}
fi

# Smoke: self-test mode (no args) must report PASS.
echo "[build_hexa_module_loader] smoke: self-test"
smoke_out="$("${out}" 2>&1)"
if ! echo "${smoke_out}" | grep -q "self-test PASS"; then
    echo "error: module_loader self-test FAIL — expected 'self-test PASS'" >&2
    echo "${smoke_out}" >&2
    exit 2
fi
echo "[build_hexa_module_loader] OK -> ${out}"
