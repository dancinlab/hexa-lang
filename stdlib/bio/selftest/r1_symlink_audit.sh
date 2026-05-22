#!/usr/bin/env bash
# selftest/r1_symlink_audit.sh
#
# R1 SSOT symlink audit (per .roadmap.hexa_bio §A new subsection R1-AUDIT,
# closing §F UNDEFINED "R1 symlink SSOT 자동 감사").
#
# POST-CANON-RETIREMENT (2026-05-11) UPDATE: canon@mk1 was retired; the
# `docs/n6/` SSOT symlinks no longer point at `$HOME/core/canon/` (that path
# is gone). The n=6 axis content is now SELF-CONTAINED in this repo under
# `hexa-{weave,virocapsid,ribozyme,nanobot}/hexa-*.md`. So:
#   - the canonical-root check is now "$REPO_ROOT/" (in-repo, self-contained)
#     OR "$HOME/core/nexus/canon-infra/legacy-canon/" (the frozen legacy snapshot)
#   - the symlinks under docs/n6/ point at `../../hexa-*/hexa-*.md` (in-repo)
#
# For each entry under docs/n6/ verify:
#   (a) the symlink resolves (target exists)
#   (b) target mtime within 90 days OR companion `<entry>.STALE_OK` annotation
#       file is present in the same directory
#   (c) target absolute path begins with one of the accepted canonical roots
#       (in-repo $REPO_ROOT/ or legacy-canon)
#
# Exit codes:
#   0  all PASS (or docs/n6/ empty — nothing to audit is a valid post-retirement state)
#   1  any link broken / target missing / outside accepted roots
#   2  warnings only (stale without STALE_OK annotation)
#
# Pure POSIX-ish bash; `stat -f` (BSD) / `stat -c` (GNU) compat handled.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_N6="${REPO_ROOT}/docs/n6"
# Accepted canonical roots (post-canon-retirement): in-repo self-contained content,
# or the frozen legacy-canon snapshot. (The retired canon@mk1 path is no longer valid.)
ACCEPTED_ROOTS=( "${REPO_ROOT}" "${HOME}/core/nexus/canon-infra/legacy-canon" )
STALE_DAYS=90

if [[ ! -d "${DOCS_N6}" ]]; then
  echo "FAIL: docs/n6/ directory not found at ${DOCS_N6}" >&2
  exit 1
fi

# Portable mtime-in-epoch (BSD vs GNU stat).
mtime_epoch() {
  local target="$1"
  if stat -f %m "${target}" >/dev/null 2>&1; then
    stat -f %m "${target}"
  else
    stat -c %Y "${target}"
  fi
}

# Portable canonical-path resolver (BSD readlink lacks -e/-f).
# Resolves a symlink target to an absolute existing path or empty string.
resolve_link() {
  local link="$1"
  # Try GNU readlink -e first (resolves all symlinks, fails if missing).
  local r
  r="$(readlink -e "${link}" 2>/dev/null || true)"
  if [[ -n "${r}" ]]; then
    printf '%s' "${r}"
    return 0
  fi
  # Try `realpath` (present on most macOS via coreutils or system).
  r="$(realpath "${link}" 2>/dev/null || true)"
  if [[ -n "${r}" && -e "${r}" ]]; then
    printf '%s' "${r}"
    return 0
  fi
  # BSD fallback: read raw target, resolve relative to link's dir, normalize.
  local raw target_dir abs
  raw="$(readlink "${link}" 2>/dev/null || true)"
  [[ -z "${raw}" ]] && return 1
  if [[ "${raw}" = /* ]]; then
    abs="${raw}"
  else
    target_dir="$(cd "$(dirname "${link}")" && pwd)"
    abs="${target_dir}/${raw}"
  fi
  # Normalize via cd into target's directory.
  if [[ -e "${abs}" ]]; then
    local norm_dir norm_base
    norm_dir="$(cd "$(dirname "${abs}")" 2>/dev/null && pwd)" || return 1
    norm_base="$(basename "${abs}")"
    printf '%s/%s' "${norm_dir}" "${norm_base}"
    return 0
  fi
  return 1
}

now_epoch="$(date +%s)"
stale_threshold=$(( STALE_DAYS * 86400 ))

fail=0
warn=0
checked=0

for entry in "${DOCS_N6}"/*; do
  [[ -e "${entry}" || -L "${entry}" ]] || continue
  base="$(basename "${entry}")"

  # Skip annotation sidecar files themselves.
  case "${base}" in
    *.STALE_OK) continue ;;
  esac

  checked=$(( checked + 1 ))

  # (a) resolve symlink portably
  resolved="$(resolve_link "${entry}" || true)"
  if [[ -z "${resolved}" ]]; then
    echo "FAIL [broken]    ${base} -> $(readlink "${entry}" 2>/dev/null || echo '?')"
    fail=$(( fail + 1 ))
    continue
  fi

  # (c) target inside one of the accepted canonical roots
  in_root=0
  for root in "${ACCEPTED_ROOTS[@]}"; do
    case "${resolved}" in
      "${root}"/*) in_root=1; break ;;
    esac
  done
  if (( in_root == 0 )); then
    echo "FAIL [off-root]  ${base} -> ${resolved}  (not under any of: ${ACCEPTED_ROOTS[*]})"
    fail=$(( fail + 1 ))
    continue
  fi

  # (b) staleness
  tgt_mtime="$(mtime_epoch "${resolved}")"
  age=$(( now_epoch - tgt_mtime ))
  if (( age > stale_threshold )); then
    if [[ -f "${entry}.STALE_OK" ]]; then
      echo "OK   [stale-ok]  ${base} (age $(( age / 86400 ))d, STALE_OK annotation present)"
    else
      echo "WARN [stale]    ${base} (age $(( age / 86400 ))d > ${STALE_DAYS}d, no STALE_OK annotation)"
      warn=$(( warn + 1 ))
    fi
  else
    echo "OK              ${base} (age $(( age / 86400 ))d)"
  fi
done

echo "---"
echo "checked=${checked}  fail=${fail}  warn=${warn}"

if (( fail > 0 )); then
  exit 1
fi
if (( warn > 0 )); then
  exit 2
fi
exit 0
