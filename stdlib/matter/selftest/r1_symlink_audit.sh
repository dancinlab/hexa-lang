#!/usr/bin/env bash
# selftest/r1_symlink_audit.sh
#
# R1 symlink audit (hexa-matter Phase B, 2026-05-13).
#
# Fail if any verb subdirectory contains a symlink whose target points OUTSIDE
# the hexa-matter repo. (In-repo symlinks are fine; out-of-repo symlinks are
# the kind of latent dependency that breaks `hx install hexa-matter` and the
# raw#15 read-only discipline.)
#
# Scope: every verb subdir listed in hexa.toml [verbs] (36 verbs as of
#   2026-05-13 Phase D'' close).
#
# Mirrors hexa-bio/selftest/r1_symlink_audit.sh shape; we have no docs/n6/
# legacy SSOT symlink path, so the audit just walks per-verb dirs.
#
# Exit:
#   0  PASS (no out-of-repo symlinks)
#   1  FAIL (≥1 out-of-repo symlink found, or unresolved link)

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${HEXA_MATTER_ROOT:-$(cd "$HERE/.." && pwd)}"

if [[ ! -f "$REPO_ROOT/hexa.toml" ]]; then
  echo "FAIL: not a hexa-matter repo root ($REPO_ROOT — no hexa.toml)" >&2
  exit 1
fi

# 36 verb directories (mirrors verify/spec_presence.hexa).
VERB_DIRS=(
  ceramics concrete concrete_tech glass silicon
  compound-semi perovskite 2d-materials mof carbon
  glass-ceramic geopolymer aerogel-foam
  refractory electrode-material
  aramid epoxy nylon pet_film tire_cord
  elastomer adhesive liquid-crystal biodegradable-plastics ionic-liquid
  photoresist
  fabric paper wood-cellulose
  gemology
  metallurgy superalloy magnetic-materials
  synthesis
  recycle_n6 recycling
)

resolve_link() {
  local link="$1"
  local r
  r="$(readlink -e "$link" 2>/dev/null || true)"
  [[ -n "$r" ]] && { printf '%s' "$r"; return 0; }
  r="$(realpath "$link" 2>/dev/null || true)"
  [[ -n "$r" && -e "$r" ]] && { printf '%s' "$r"; return 0; }
  local raw target_dir abs
  raw="$(readlink "$link" 2>/dev/null || true)"
  [[ -z "$raw" ]] && return 1
  if [[ "$raw" = /* ]]; then
    abs="$raw"
  else
    target_dir="$(cd "$(dirname "$link")" && pwd)"
    abs="${target_dir}/${raw}"
  fi
  if [[ -e "$abs" ]]; then
    local norm_dir norm_base
    norm_dir="$(cd "$(dirname "$abs")" 2>/dev/null && pwd)" || return 1
    norm_base="$(basename "$abs")"
    printf '%s/%s' "$norm_dir" "$norm_base"
    return 0
  fi
  return 1
}

fail=0
checked=0
links_found=0

echo "hexa-matter/selftest/r1_symlink_audit — out-of-repo symlink scan"
echo "  root: $REPO_ROOT"
echo ""

for v in "${VERB_DIRS[@]}"; do
  vdir="$REPO_ROOT/$v"
  if [[ ! -d "$vdir" ]]; then
    echo "  [WARN] verb dir missing: $v (skipping)"
    continue
  fi
  checked=$((checked + 1))
  # find symlinks INSIDE this verb dir
  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    links_found=$((links_found + 1))
    resolved="$(resolve_link "$link" || true)"
    base="${link#$REPO_ROOT/}"
    if [[ -z "$resolved" ]]; then
      echo "  [FAIL] broken symlink: $base"
      fail=$((fail + 1))
      continue
    fi
    case "$resolved" in
      "$REPO_ROOT"/*)
        echo "  [OK]   in-repo:  $base -> ${resolved#$REPO_ROOT/}"
        ;;
      *)
        echo "  [FAIL] out-of-repo:  $base -> $resolved"
        fail=$((fail + 1))
        ;;
    esac
  done < <(find "$vdir" -type l 2>/dev/null)
done

echo ""
echo "  checked=$checked verb_dirs  links_found=$links_found  fail=$fail"

if (( fail > 0 )); then
  echo "__HEXA_MATTER_R1_SYMLINK__ FAIL"
  exit 1
fi
echo "__HEXA_MATTER_R1_SYMLINK__ PASS"
exit 0
