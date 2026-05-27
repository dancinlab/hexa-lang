#!/usr/bin/env bash
# P1 — Pre-stage tarball for Akida Cloud D+0 upload.
#
# Subcommands:
#   stage   build tarball at ~/scratch/akida_cloud_d0_payload.tar.gz
#   upload  rsync tarball to akida-cloud over ssh
#   verify  list tarball contents + size
set -euo pipefail
XENO_ROOT="${XENO_ROOT:-$HOME/core/xeno}"
ANIMA_ROOT="${ANIMA_ROOT:-$HOME/core/anima}"
NEXUS_ROOT="${NEXUS_ROOT:-$HOME/core/nexus}"
SCRATCH="${SCRATCH:-$HOME/scratch}"
TARBALL="$SCRATCH/akida_cloud_d0_payload.tar.gz"

mkdir -p "$SCRATCH"

cmd="${1:-stage}"
case "$cmd" in
  stage)
    echo "[P1] staging tarball: $TARBALL"
    # Build manifest of paths to include (relative to ~/core/)
    local_tmp=$(mktemp -d)
    trap "rm -rf $local_tmp" EXIT
    cd "$HOME/core"
    # Pack: anima scripts/akida + state akida + nexus scripts/akida + xeno (full)
    tar -czf "$TARBALL" \
      --exclude='__pycache__' \
      --exclude='*.pyc' \
      --exclude='.git' \
      --exclude='.venv*' \
      anima/scripts/akida \
      anima/state/akida_evidence \
      anima/state/akida_d0_d1_plan_freeze_2026_05_02 \
      anima/state/strategic_clm_eeg_akida_tension_2026_05_02 \
      anima/docs/akida_cloud_setup_log_2026_05_08.md \
      anima/docs/akida_cloud_d_minus_1_prep_2026_05_08.md \
      anima/docs/n_substrate_consciousness_roadmap_2026_05_01.md \
      anima/.roadmap.akida \
      nexus/scripts/akida \
      nexus/state/akida_evidence \
      nexus/state/akida_synth \
      nexus/design/kick \
      nexus/docs/akida_dev_kit_evaluation_2026-04-29.md \
      nexus/docs/akida_session_friendly_report_2026-04-29.md \
      hexa-brain/eeg/doc/cross_substrate \
      xeno \
      2>/dev/null || echo "  (some paths missing — soft fail OK)"
    ls -lh "$TARBALL"
    echo "[P1] manifest: $(tar -tzf "$TARBALL" | wc -l | tr -d ' ') entries"
    ;;
  verify)
    if [[ ! -f "$TARBALL" ]]; then echo "no tarball at $TARBALL — run: $0 stage" >&2; exit 1; fi
    echo "[P1] $TARBALL"
    ls -lh "$TARBALL"
    echo "  entries: $(tar -tzf "$TARBALL" | wc -l | tr -d ' ')"
    echo "  top dirs:"
    tar -tzf "$TARBALL" | awk -F/ '{print $1"/"$2}' | sort -u | head -10
    ;;
  upload)
    if [[ ! -f "$TARBALL" ]]; then echo "no tarball — run: $0 stage" >&2; exit 1; fi
    alias_n=$(secret get akida_cloud.ssh_alias 2>/dev/null || echo akida-cloud)
    echo "[P1] rsync $TARBALL → $alias_n:~/payload.tar.gz"
    rsync -avh --progress "$TARBALL" "$alias_n":~/payload.tar.gz
    echo "[P1] upload complete. Cloud-side: tar -xzf ~/payload.tar.gz -C ~/work/"
    ;;
  *) echo "usage: $0 {stage | verify | upload}" >&2; exit 2 ;;
esac
