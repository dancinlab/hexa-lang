#!/usr/bin/env bash
# runner_load_toggle.sh — self-reported load-gating for the `hexa-ready` CI routing label.
#
# A self-hosted runner's GitHub `busy` flag reflects only GitHub jobs, NOT real machine
# load: a box saturated by non-GitHub work (e.g. the anima experiments on `aiden`, sustained
# loadavg 17 on 12 cores) still reports `busy=false` and the picker (tool/ci_pick_runner.sh)
# routes heavy byteeq/stdlib jobs onto it, where native-emit crawls and the queue starves.
#
# This toggler adds/removes the custom `hexa-ready` label on THIS runner from machine load,
# so an overloaded box takes itself out of the picker's label match (the picker already reads
# the runners API every dispatch — zero extra calls). Run it as a systemd timer (30-60 s).
#
# FAIL-OPEN: on ANY error the label is left UNCHANGED — a runner that already carries
# hexa-ready stays eligible, and the picker's terminal cloud (ubuntu-latest) fallback still
# guarantees the gate runs. The toggler can never wedge CI.
#
# Env:
#   RUNNER_LABEL_TOKEN  GitHub PAT with administration:write on $REPO   (required)
#   RUNNER_NAME         this runner's registered name (default: hostname -s, substring match)
#   REPO                owner/repo                                       (default dancinlab/hexa-lang)
#   FREE_LOW            drop the label when (cores - loadavg5) <  FREE_LOW   (default 3)
#   FREE_HIGH           add  the label when (cores - loadavg5) >= FREE_HIGH  (default 6)
# Hysteresis (FREE_LOW < FREE_HIGH) damps flapping; loadavg5 (5-min) ignores self-build spikes.
set -uo pipefail

LABEL="hexa-ready"
REPO="${REPO:-dancinlab/hexa-lang}"
FREE_LOW="${FREE_LOW:-3}"
FREE_HIGH="${FREE_HIGH:-6}"
TOK="${RUNNER_LABEL_TOKEN:-}"
[ -z "$TOK" ] && { echo "runner_load_toggle: no RUNNER_LABEL_TOKEN — fail-open (unchanged)" >&2; exit 0; }

api() { curl -fsS -H "Authorization: Bearer $TOK" -H "Accept: application/vnd.github+json" "$@"; }

cores="$(nproc 2>/dev/null || echo 1)"
load5="$(awk '{print $2}' /proc/loadavg 2>/dev/null || echo 0)"
free="$(awk -v c="$cores" -v l="$load5" 'BEGIN{printf "%d", c - l}')"

name="${RUNNER_NAME:-$(hostname -s 2>/dev/null || hostname)}"
json="$(api "https://api.github.com/repos/$REPO/actions/runners?per_page=100" 2>/dev/null)" \
  || { echo "runner_load_toggle: runners API read failed — fail-open" >&2; exit 0; }

read -r rid has < <(printf '%s' "$json" | LABEL="$LABEL" NAME="$name" python3 -c '
import json, os, sys
name = os.environ["NAME"].lower()
label = os.environ["LABEL"]
for r in json.load(sys.stdin).get("runners", []):
    if name in r["name"].lower():
        has = 1 if any(l["name"] == label for l in r.get("labels", [])) else 0
        print(r["id"], has)
        break
' 2>/dev/null)

[ -z "${rid:-}" ] && { echo "runner_load_toggle: runner '$name' not found — fail-open" >&2; exit 0; }

if [ "$free" -lt "$FREE_LOW" ] && [ "${has:-0}" = "1" ]; then
  api -X DELETE "https://api.github.com/repos/$REPO/actions/runners/$rid/labels/$LABEL" >/dev/null 2>&1 \
    && echo "runner_load_toggle: $name free=$free < $FREE_LOW → DROP $LABEL" >&2 \
    || echo "runner_load_toggle: DELETE failed — fail-open" >&2
elif [ "$free" -ge "$FREE_HIGH" ] && [ "${has:-0}" = "0" ]; then
  api -X POST "https://api.github.com/repos/$REPO/actions/runners/$rid/labels" \
      -d "{\"labels\":[\"$LABEL\"]}" >/dev/null 2>&1 \
    && echo "runner_load_toggle: $name free=$free >= $FREE_HIGH → ADD $LABEL" >&2 \
    || echo "runner_load_toggle: POST failed — fail-open" >&2
else
  echo "runner_load_toggle: $name free=$free has=${has:-0} → no change" >&2
fi
exit 0
