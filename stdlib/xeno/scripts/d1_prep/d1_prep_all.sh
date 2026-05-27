#!/usr/bin/env bash
# D-1 prep all — orchestrates P0a/P0b/P1 (P6 is post-cycle)
# Invoked by: xeno cycle prep
set -euo pipefail
XENO_ROOT="${XENO_ROOT:-$HOME/core/xeno}"
DPREP="$XENO_ROOT/scripts/d1_prep"

echo "━━━ xeno D-1 prep ━━━"
echo "[P0b] smoke-test 8 post-arrival falsifier scripts (Mac CPU --simulator)"
"$DPREP/p0b_smoke_test.sh" || echo "[P0b] FAIL — investigate before D+0"

echo "[P1]  pre-stage tarball (~/scratch/akida_cloud_d0_payload.tar.gz)"
"$DPREP/p1_tarball.sh" stage

echo "[P0a] generate cloud-mode host_register stub (NOT applied to nexus until D+0)"
"$DPREP/p0a_host_register_cloud.sh" generate

echo "━━━ D-1 prep complete ━━━"
echo "  next: xeno cycle status  → confirm reservation + secrets"
echo "  D+0 09:00 KST: xeno cycle connect → xeno cycle upload → xeno cycle run"
echo "  D+1 08:00 KST: xeno cycle exfil → xeno cycle verdict"
