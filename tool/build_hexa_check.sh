#!/bin/bash
# tool/build_hexa_check.sh — build the standalone `hexa check` sub-binary.
#
# R7 track B cycle 6 (2026-05-18): check (invariant_check) is the 6th
# absorbed-verb sub-binary (3rd shim-cluster member). main_check →
# main rename pattern (same as convergence cycle 4).
#
# Output: bin/hexa-check. Dispatcher at self/main.hexa::dispatch_absorbed
# sub == "check" prefers this binary over the legacy cmd_run() interp
# path when present.

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${repo}/self/invariant_check.hexa"
out="${HEXA_CHECK_OUT:-${repo}/bin/hexa-check}"

if [[ ! -f "${src}" ]]; then
    echo "error: invariant_check source missing: ${src}" >&2
    exit 1
fi

mkdir -p "$(dirname "${out}")"

echo "[build_hexa_check] src=${src}"
echo "[build_hexa_check] out=${out}"
HEXA_MAC_BUILD_OK=1 hexa build "${src}" -o "${out}"
rc=$?
if [[ ${rc} -ne 0 ]]; then
    echo "error: hexa build failed (rc=${rc})" >&2
    exit ${rc}
fi

# Smoke: built binary loads without segfaulting on a trivial input.
echo "[build_hexa_check] smoke: trivial fixture"
fixture="$(mktemp -t hexa-check-fixture.XXXXXX).hexa"
cat > "${fixture}" <<'EOF'
fn nothing() {}
EOF
smoke_out="$("${out}" "${fixture}" 2>&1)"
smoke_rc=$?
rm -f "${fixture}"
if [[ ${smoke_rc} -ne 0 ]] || ! echo "${smoke_out}" | grep -q "OK: all invariants passed\|0 @invariant"; then
    echo "error: check trivial smoke FAIL (rc=${smoke_rc})" >&2
    echo "${smoke_out}" >&2
    exit 3
fi
echo "[build_hexa_check] OK -> ${out}"
