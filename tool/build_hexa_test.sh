#!/bin/bash
# tool/build_hexa_test.sh — build the standalone `hexa test` sub-binary.
#
# R7 track B cycle 5 (2026-05-18): test_runner is the 5th absorbed-verb
# sub-binary (2nd shim-cluster member after convergence). The legacy
# module-level entry block at the bottom of self/test_runner.hexa was
# wrapped in `fn main()` for compiled-binary entry semantics.
#
# Output: bin/hexa-test. Dispatcher at self/main.hexa::dispatch_absorbed
# sub == "test" prefers this binary over the legacy cmd_run() interp
# path when present.

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${repo}/self/test_runner.hexa"
out="${HEXA_TEST_OUT:-${repo}/bin/hexa-test}"

if [[ ! -f "${src}" ]]; then
    echo "error: test_runner source missing: ${src}" >&2
    exit 1
fi

mkdir -p "$(dirname "${out}")"

echo "[build_hexa_test] src=${src}"
echo "[build_hexa_test] out=${out}"
HEXA_MAC_BUILD_OK=1 hexa build "${src}" -o "${out}"
rc=$?
if [[ ${rc} -ne 0 ]]; then
    echo "error: hexa build failed (rc=${rc})" >&2
    exit ${rc}
fi

# Smoke: no-arg invocation prints usage + rc=2.
echo "[build_hexa_test] smoke: usage on no-arg"
smoke_out="$("${out}" 2>&1)"
smoke_rc=$?
if [[ ${smoke_rc} -ne 2 ]] || ! echo "${smoke_out}" | grep -q -i "usage\|test"; then
    echo "error: test --help smoke FAIL — expected rc=2 + usage" >&2
    echo "rc=${smoke_rc}" >&2
    echo "${smoke_out}" >&2
    exit 3
fi
echo "[build_hexa_test] OK -> ${out}"
