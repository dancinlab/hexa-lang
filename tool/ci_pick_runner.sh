#!/usr/bin/env bash
# ci_pick_runner.sh — fallback-dispatch runner picker (self-hosted-if-online,
# else GitHub-hosted). Canonical GitHub Actions reliability pattern: a cheap
# always-available probe job (ubuntu-latest) decides the heavy job's `runs-on`
# at runtime, so the pool being OFFLINE never deadlocks a (potentially required)
# gate — it just falls back to the free GitHub-hosted runner.
#
# WHY: CLAUDE.md › CI — heavy faithful/byteeq builds run far faster on the
# self-hosted pool (aiden/summer 12c/30G · ghost gen2_fix darwin), but the pool
# also serves r5 measurement + anima training (1-SSH discipline) and can be
# offline. Static `runs-on: [self-hosted,…]` would leave a required gate pending
# forever when the pool is down. This picker keeps both runners free (public
# repo = $0 on either) and deadlock-proof.
#
# USAGE (inside a ubuntu-latest dispatch job, GH_TOKEN exported):
#   bash tool/ci_pick_runner.sh <kind> [primary_only]
#            primary_only=1 → skip the alt/insurance legs entirely (slot-bound
#            jobs: byteeq-real needs ghost's provisioned gen3 slot — an idle
#            insurance runner without the slot only manufactures exit-2 REDs)
#     kind = linux  → emits linux_label  (self-hosted hexa-build, else fallback)
#            darwin → emits darwin_label (ghost selfhost-gen2fix, else macos-15)
#
# Writes a single `<kind>_label=<json>` line to $GITHUB_OUTPUT. The value is a
# JSON STRING consumed downstream via `runs-on: ${{ fromJSON(needs.dispatch.outputs.<kind>_label) }}`:
#   - self-hosted → a JSON ARRAY of labels  e.g.  ["self-hosted","Linux","X64","hexa-build"]
#   - fallback    → a JSON STRING            e.g.  "ubuntu-latest" / "macos-15"
# fromJSON parses both an array and a bare string, and `runs-on` accepts either.
#
# SAFETY / FORK-PR (RCE): self-hosted is only ever a CANDIDATE when the env var
# SELF_HOSTED_ELIGIBLE=1 (the caller sets this to the result of the
# same-repo guard `github.event.pull_request.head.repo.full_name == github.repository`,
# OR a push/dispatch event). For fork PRs the caller passes 0 → we force the
# GitHub-hosted fallback regardless of pool state (no untrusted code on the pool).
#
# FAIL-SAFE: any probe error (missing token, gh/api failure, jq absent) falls
# back to the GitHub-hosted runner — the dispatch job itself runs on
# ubuntu-latest (always available), and we never let a probe hiccup wedge CI.
set -uo pipefail

kind="${1:-}"
primary_only="${2:-0}"
case "$kind" in
  linux)
    fallback='"ubuntu-latest"'
    want_labels='self-hosted Linux X64 hexa-build'
    sh_label='["self-hosted","Linux","X64","hexa-build"]'
    ;;
  darwin)
    fallback='"macos-15"'
    want_labels='self-hosted macOS ARM64 selfhost-gen2fix'
    sh_label='["self-hosted","macOS","ARM64","selfhost-gen2fix"]'
    # ordered insurance chain: ghost (primary) → mini (fallback-only, distinct
    # label so it never load-balances with ghost in normal operation) → macos-15.
    # mini is a daily-driver Mac: it must receive jobs ONLY when ghost is offline.
    alt_want_labels='self-hosted macOS ARM64 hexa-darwin-mini'
    alt_sh_label='["self-hosted","macOS","ARM64","hexa-darwin-mini"]'
    ;;
  *)
    echo "::error::ci_pick_runner: unknown kind '$kind' (want linux|darwin)" >&2
    exit 2
    ;;
esac

emit() {  # emit <json-label> ; also echoes a human notice
  local val="$1"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s_label=%s\n' "$kind" "$val" >> "$GITHUB_OUTPUT"
  fi
  echo "ci_pick_runner: kind=$kind → runs-on=$val"
}

# ── fork-PR / eligibility guard ─────────────────────────────────────────────
# Caller sets SELF_HOSTED_ELIGIBLE=1 only for same-repo events. Anything else
# (fork PR, or unset) forces the GitHub-hosted fallback — no self-hosted RCE.
if [ "${SELF_HOSTED_ELIGIBLE:-0}" != "1" ]; then
  echo "::notice::self-hosted not eligible (fork-PR or guarded) → GitHub-hosted fallback"
  emit "$fallback"
  exit 0
fi

# ── probe: is a matching self-hosted runner ONLINE and (preferably) idle? ────
# BUSY-AWARE selection (measured 2026-07-03: ghost busy=true queued 10 runs while
# mini sat online+idle — online-only matching converged every darwin job on ghost).
# Priority: ① primary online+idle → ② alt online+idle → ③ primary online (busy —
# queueing on the primary is still preferred over cloud) → ④ alt online (busy)
# → ⑤ GitHub-hosted fallback. linux has no alt, so it naturally degrades to
# primary-idle → primary-busy → cloud.
api_json=""
if [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
  api_json="$(gh api repos/"${GITHUB_REPOSITORY:-dancinlab/hexa-lang}"/actions/runners --paginate 2>/dev/null || true)"
fi

if [ -z "$api_json" ]; then
  echo "::notice::runner probe unavailable (no token / api error) → GitHub-hosted fallback"
  emit "$fallback"
  exit 0
fi

# ── BLINDNESS CANARY (LOUD) ─────────────────────────────────────────────────
# We are past the eligibility guard (eligible=1) AND the API returned a body.
# If it reports ZERO runners, the overwhelmingly likely cause is a token that
# lacks `administration:read`: the default GITHUB_TOKEN can NEVER carry that
# scope (it is not even a grantable `permissions:` key), so the runners endpoint
# returns `{"total_count":0,"runners":[]}` and this picker would silently fall
# back FOREVER — indistinguishable from "pool offline". Emit a ::warning so a
# misconfigured RUNNER_PROBE_TOKEN is diagnosable in the dispatch log instead of
# masquerading as a dead pool. (Does not change control flow — still falls back.)
total_count="$(printf '%s' "$api_json" | jq -r '.total_count // (.runners | length) // 0' 2>/dev/null || echo 0)"
if [ "${total_count:-0}" = "0" ]; then
  echo "::warning::runner probe returned 0 runners on an authenticated API call — the probe token almost certainly lacks administration:read (the default github.token can NEVER carry it). Set the RUNNER_PROBE_TOKEN secret (fine-grained PAT · this repo · Administration: read-only) to enable self-hosted routing. Falling back to GitHub-hosted for now."
fi

# jq filter: a runner is a match if status==online AND it carries EVERY wanted
# label. Labels are passed via `jq --args …` (positional $ARGS.positional) so no
# string-splitting/quoting fragility. `wanted - present == []` ⇔ present ⊇ wanted.
# shellcheck disable=SC2016  # jq program — must NOT be shell-expanded
jq_filter='[ .runners[]
  | select(.status=="online")
  | select( ($ARGS.positional - [ .labels[].name ]) == [] )
] | length'
# same filter, but additionally require the runner to be IDLE (busy==false).
# shellcheck disable=SC2016  # jq program — must NOT be shell-expanded
jq_filter_idle='[ .runners[]
  | select(.status=="online")
  | select(.busy==false)
  | select( ($ARGS.positional - [ .labels[].name ]) == [] )
] | length'

# shellcheck disable=SC2086  # intentional word-split of the wanted-label list
idle_matches="$(printf '%s' "$api_json" | jq "$jq_filter_idle" --args $want_labels 2>/dev/null || echo 0)"
# shellcheck disable=SC2086  # intentional word-split of the wanted-label list
online_matches="$(printf '%s' "$api_json" | jq "$jq_filter" --args $want_labels 2>/dev/null || echo 0)"
alt_idle_matches=0
alt_matches=0
if [ -n "${alt_want_labels:-}" ]; then
  # shellcheck disable=SC2086  # intentional word-split of the wanted-label list
  alt_idle_matches="$(printf '%s' "$api_json" | jq "$jq_filter_idle" --args $alt_want_labels 2>/dev/null || echo 0)"
  # shellcheck disable=SC2086  # intentional word-split of the wanted-label list
  alt_matches="$(printf '%s' "$api_json" | jq "$jq_filter" --args $alt_want_labels 2>/dev/null || echo 0)"
fi

# ① primary online + idle
if [ "${idle_matches:-0}" -ge 1 ] 2>/dev/null; then
  echo "::notice::$idle_matches online+idle self-hosted runner(s) match [$want_labels] → self-hosted"
  emit "$sh_label"
  exit 0
fi

# ② alt online + idle (darwin insurance runner: mini) — busy-aware spillover so
# an idle mini takes the job instead of queueing behind a busy ghost.
# primary_only=1 (slot-bound jobs) skips both alt legs: the insurance runner
# has no gen3 slot, so routing there converts "queue behind ghost" into a
# false RED (measured: #4469 byteeq-real exit-2 ×2 on mini-selfhost, 2026-07-03).
if [ "$primary_only" != "1" ] && [ "${alt_idle_matches:-0}" -ge 1 ] 2>/dev/null; then
  echo "::notice::primary busy/offline; $alt_idle_matches online+idle insurance runner(s) match [$alt_want_labels] → self-hosted (mini)"
  emit "$alt_sh_label"
  exit 0
fi

# ③ primary online (busy) — queue on the primary (today's behavior preserved)
if [ "${online_matches:-0}" -ge 1 ] 2>/dev/null; then
  echo "::notice::$online_matches online (busy) self-hosted runner(s) match [$want_labels] → self-hosted (will queue)"
  emit "$sh_label"
  exit 0
fi

# ④ alt online (busy)
if [ "$primary_only" != "1" ] && [ "${alt_matches:-0}" -ge 1 ] 2>/dev/null; then
  echo "::notice::primary offline; $alt_matches online (busy) insurance runner(s) match [$alt_want_labels] → self-hosted (mini, will queue)"
  emit "$alt_sh_label"
  exit 0
fi

echo "::notice::no online self-hosted runner matches [$want_labels] → GitHub-hosted fallback"
emit "$fallback"
exit 0
