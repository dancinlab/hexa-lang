#!/bin/bash
# tool/build_absorbed_binaries.sh — batch-build R7 track B Phase 3/4
# absorbed-verb sub-binaries.
#
# R7 track B (2026-05-18): the ~38 non-ANNOT absorbed verbs
# (honesty/absolute/drill/chain/.../bridges/lattice) each route through
# self/main.hexa::dispatch_absorbed → cmd_run(script) interp. This script
# compiles each to bin/hexa-absorbed-<verb> so the dispatcher prefers the
# binary (cmd_run fallback retained for any that don't compile cleanly).
#
# The verb→script map is self-derived from self/main.hexa::_absorbed_script
# (no duplicated table — drift-safe). ANNOT: bash tools are skipped (already
# standalone). Build failures are tolerated and reported, not fatal.
#
# Usage:
#   bash tool/build_absorbed_binaries.sh              # build all
#   bash tool/build_absorbed_binaries.sh honesty drill  # subset by verb
#
# Env: HEXA_MEM_UNLIMITED=1 set (large compiler/atlas trees).

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
main_hexa="${repo}/self/main.hexa"
mkdir -p "${repo}/bin"

# R7 stale-transpiler trap: PATH `hexa` resolves install_dir to the
# production tree (its hexa_v2), NOT this worktree's rebuilt hexa_v2.
# Use the repo-local shim so install_dir_from_argv0 → ${repo} → the
# freshly-bootstrapped self/native/hexa_v2 (free-mangle, readline, …).
hexa_bin="${repo}/hexa"
[ -x "${hexa_bin}" ] || hexa_bin="$(command -v hexa)"

# Self-derive verb→script pairs: lines of form
#   if verb == "NAME"  { return "compiler/.../x.hexa" }
# (skip ANNOT: bash tools — they're already standalone).
map="$(grep -oE 'verb == "[a-z0-9_-]+"[[:space:]]*\{[[:space:]]*return "(compiler|self|stdlib)/[^"]+\.hexa"' "${main_hexa}" \
  | sed -E 's/verb == "([^"]+)".*return "([^"]+)"/\1 \2/')"

want=("$@")
in_want() {
  [ ${#want[@]} -eq 0 ] && return 0
  for w in "${want[@]}"; do [ "$w" = "$1" ] && return 0; done
  return 1
}

pass=0; fail=0; skip=0
failed_list=""
while read -r verb rel; do
  [ -z "${verb}" ] && continue
  in_want "${verb}" || { skip=$((skip+1)); continue; }
  src="${repo}/${rel}"
  out="${repo}/bin/hexa-absorbed-${verb}"
  if [ ! -f "${src}" ]; then
    echo "[absorbed] SKIP ${verb} — source missing: ${rel}"
    skip=$((skip+1)); continue
  fi
  echo "[absorbed] build ${verb} ← ${rel}"
  if HEXA_MAC_BUILD_OK=1 HEXA_MEM_UNLIMITED=1 "${hexa_bin}" build "${src}" -o "${out}" >/tmp/absorbed_${verb}.log 2>&1; then
    echo "[absorbed]   OK  → bin/hexa-absorbed-${verb}"
    pass=$((pass+1))
  else
    echo "[absorbed]   FAIL (see /tmp/absorbed_${verb}.log: $(tail -1 /tmp/absorbed_${verb}.log 2>/dev/null))"
    fail=$((fail+1))
    failed_list="${failed_list} ${verb}"
  fi
done <<< "${map}"

echo ""
echo "[absorbed] summary: pass=${pass} fail=${fail} skip=${skip}"
[ -n "${failed_list}" ] && echo "[absorbed] failed:${failed_list}"
echo "[absorbed] (failures fall back to cmd_run interp — non-fatal for R7 track B)"
exit 0
