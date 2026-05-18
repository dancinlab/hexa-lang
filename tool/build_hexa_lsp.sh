#!/bin/bash
# tool/build_hexa_lsp.sh — build the standalone `hexa lsp` sub-binary.
#
# R7 track B cycle 10 (2026-05-18): lsp is the 9th absorbed-verb sub-binary.
# Unlike cycles 1-9 (exec()-buffered spawn), the lsp dispatcher uses
# exec_replace() so the editor's stdin/stdout pipes are inherited verbatim
# for unbuffered JSON-RPC streaming. Source change: module-level `run_lsp()`
# wrapped in `fn main()` (interp still auto-invokes main()).
#
# Output: bin/hexa-lsp. Dispatcher at self/main.hexa::dispatch_absorbed
# sub == "lsp" || "--lsp" exec_replace()s into this binary when present.

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${repo}/self/lsp.hexa"
out="${HEXA_LSP_OUT:-${repo}/bin/hexa-lsp}"

if [[ ! -f "${src}" ]]; then
    echo "error: lsp source missing: ${src}" >&2
    exit 1
fi

mkdir -p "$(dirname "${out}")"

echo "[build_hexa_lsp] src=${src}"
echo "[build_hexa_lsp] out=${out}"
HEXA_MAC_BUILD_OK=1 hexa build "${src}" -o "${out}"
rc=$?
if [[ ${rc} -ne 0 ]]; then
    echo "error: hexa build failed (rc=${rc})" >&2
    exit ${rc}
fi

# Smoke: feed a minimal LSP initialize request, expect a JSON-RPC response
# with the server capabilities, then EOF-exit cleanly.
echo "[build_hexa_lsp] smoke: initialize handshake"
req='Content-Length: 58

{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
smoke_out="$(printf '%s' "${req}" | "${out}" 2>&1 | head -c 400)"
if ! echo "${smoke_out}" | grep -q "jsonrpc\|capabilities\|result"; then
    echo "error: lsp initialize smoke FAIL — no JSON-RPC response" >&2
    echo "${smoke_out}" >&2
    exit 2
fi
echo "[build_hexa_lsp] OK -> ${out}"
