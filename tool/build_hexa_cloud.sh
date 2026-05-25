#!/bin/bash
# tool/build_hexa_cloud.sh — build the standalone `hexa cloud` sub-binary.
#
# Resolves archive/patches/subcommand-help-scoping-and-cloud-binary-promote.md
# Part (A) cloud binary promote: stdlib/cloud/cloud_cli.hexa is the SSOT for
# the `hexa cloud {run|nohup|poll|copy-to|copy-from}` dispatcher (cycle A,
# PRs #81/#84/#86/#88). self/main.hexa:4599 already routes `sub == "cloud"`
# to bin/hexa-cloud when present (falls back to cmd_run on the script when
# absent). This builder produces the bin so the spawn fast-path engages.
#
# Output: bin/hexa-cloud (Mach-O on Darwin, ELF on Linux).
#
# Usage:
#   bash tool/build_hexa_cloud.sh                  # default output bin/hexa-cloud
#   HEXA_CLOUD_OUT=/path/to/out bash tool/build_hexa_cloud.sh
#
# Env:
#   HEXA_MAC_BUILD_OK=1    bypass Darwin /tmp panic guard (auto-set inside)
#   HEXA_CLOUD_OUT=<path>  override output path (defaults to repo bin/hexa-cloud)

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${repo}/stdlib/cloud/cloud_cli.hexa"
out="${HEXA_CLOUD_OUT:-${repo}/bin/hexa-cloud}"

if [[ ! -f "${src}" ]]; then
    echo "error: cloud source missing: ${src}" >&2
    exit 1
fi

mkdir -p "$(dirname "${out}")"

echo "[build_hexa_cloud] src=${src}"
echo "[build_hexa_cloud] out=${out}"

# Build via the manual module_loader → hexat → clang pipeline. The
# `hexa build` wrapper (driver) has an unrelated hexac-environment
# quirk where the smoke check captures empty stdout from successfully-
# built binaries (intermittent file-descriptor interaction). Until
# that's debugged separately, this builder uses the manual pipeline
# directly — same artifact, no driver quirk surface.
flat="$(mktemp -t hexa_cloud_flat.XXXXXX).hexa"
cgen="$(mktemp -t hexa_cloud_cgen.XXXXXX).c"
HEXA_MEM_CAP_MB="${HEXA_MEM_CAP_MB:-4096}" "${repo}/build/hexa_module_loader" "${src}" "${flat}" >/dev/null 2>&1
if [[ ! -s "${flat}" ]]; then
    echo "error: module_loader produced empty flatten" >&2
    exit 2
fi
"${repo}/self/native/hexat" "${flat}" "${cgen}" >/dev/null 2>&1
if [[ ! -s "${cgen}" ]]; then
    echo "error: hexat transpile produced empty C" >&2
    exit 3
fi
libsodium_inc="$(ls -d /opt/homebrew/Cellar/libsodium/*/include 2>/dev/null | tail -n1)"
libsodium_lib="$(ls -d /opt/homebrew/Cellar/libsodium/*/lib 2>/dev/null | tail -n1)"
openssl_inc="$(ls -d /opt/homebrew/Cellar/openssl@3/*/include 2>/dev/null | tail -n1)"
openssl_lib="$(ls -d /opt/homebrew/Cellar/openssl@3/*/lib 2>/dev/null | tail -n1)"
extra_cflags=""
extra_ldflags=""
if [[ -n "${libsodium_inc}" ]]; then extra_cflags+=" -DHEXA_HAS_LIBSODIUM -I${libsodium_inc}"; fi
if [[ -n "${libsodium_lib}" ]]; then extra_ldflags+=" -L${libsodium_lib} -lsodium"; fi
if [[ -n "${openssl_inc}" ]]; then extra_cflags+=" -DHEXA_HAS_OPENSSL -I${openssl_inc}"; fi
if [[ -n "${openssl_lib}" ]]; then extra_ldflags+=" -L${openssl_lib} -lssl -lcrypto"; fi
clang -O2 ${extra_cflags} -Wno-trigraphs -fbracket-depth=4096 \
      -I "${repo}/self" "${cgen}" "${repo}/self/runtime.c" \
      -o "${out}" -lpthread ${extra_ldflags} 2>&1 | grep -iE "error|undefined" | head -5
if [[ ! -x "${out}" ]]; then
    echo "error: clang produced no binary" >&2
    exit 4
fi
rm -f "${flat}" "${cgen}"
rc=0

# Smoke: --help renders the canonical cloud manual (Part B early-catch
# acceptance — the dispatcher main() handles --help internally so any
# spawn must surface it). File-based capture avoids a `set -uo pipefail`
# quirk on the `echo "$smoke_out" | grep -q` pattern where grep sees an
# empty stdin under certain darwin shell configurations.
smoke_log="$(mktemp -t hexa_cloud_smoke.XXXXXX)"
echo "[build_hexa_cloud] smoke: ${out} --help"
"${out}" --help > "${smoke_log}" 2>&1
smoke_rc=$?
if [[ ${smoke_rc} -ne 0 ]]; then
    echo "error: hexa-cloud --help exited non-zero (rc=${smoke_rc})" >&2
    cat "${smoke_log}" >&2
    rm -f "${smoke_log}"
    exit 2
fi
if ! grep -q "hexa cloud" "${smoke_log}"; then
    echo "error: hexa-cloud --help missing canonical header 'hexa cloud'" >&2
    cat "${smoke_log}" >&2
    rm -f "${smoke_log}"
    exit 3
fi
if ! grep -q "cloud run" "${smoke_log}"; then
    echo "error: hexa-cloud --help missing 'cloud run' verb line" >&2
    cat "${smoke_log}" >&2
    rm -f "${smoke_log}"
    exit 4
fi
rm -f "${smoke_log}"
echo "[build_hexa_cloud] OK -> ${out}"
