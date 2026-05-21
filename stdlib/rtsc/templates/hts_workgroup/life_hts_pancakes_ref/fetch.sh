#!/usr/bin/env bash
# Fetch upstream life-hts repo into _external/ for local-only inspection.
# absorbed=false — no files from this clone are copied into our tracked tree.
# License: unclear (no LICENSE file upstream as of 2026-05-21). Use locally only;
# do not redistribute. Pinned commit reflects observed master HEAD at access time.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PINNED_SHA="d935381b79598be11caa91961e023ebeb67727b1"

mkdir -p "${SCRIPT_DIR}/_external"
cd "${SCRIPT_DIR}/_external"

if [ ! -d life-hts ]; then
    git clone --depth 1 https://gitlab.onelab.info/life-hts/life-hts.git
fi

cd life-hts
echo "upstream HEAD: $(git rev-parse HEAD)"
echo "pinned SHA  : ${PINNED_SHA}"
if [ "$(git rev-parse HEAD)" != "${PINNED_SHA}" ]; then
    echo "[warn] upstream HEAD drifted from pinned SHA — verify provenance README." >&2
fi
echo "pancakes_ref model at: $(pwd)/pancakesHPhi/pancakes_ref/"
ls -la pancakesHPhi/pancakes_ref/
