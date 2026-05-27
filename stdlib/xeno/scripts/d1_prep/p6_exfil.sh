#!/usr/bin/env bash
# P6 — Exfil from Akida Cloud session to Mac side BEFORE D+1 09:00 KST close.
# Fires own 30 mandate-1 pattern (scp_get equivalent) for cloud session.
#
# Subcommands:
#   pull          rsync cloud:~/work/state/* → local destinations
#   verify        check pulled files exist + non-empty
#   archive       compress pulled state to dated archive
set -euo pipefail
XENO_ROOT="${XENO_ROOT:-$HOME/core/xeno}"
ANIMA_ROOT="${ANIMA_ROOT:-$HOME/core/anima}"
NEXUS_ROOT="${NEXUS_ROOT:-$HOME/core/nexus}"

DATE="${EXFIL_DATE:-$(date +%Y_%m_%d)}"
ANIMA_DEST="$ANIMA_ROOT/state/akida_cloud_d0_${DATE}"
ANIMA_EVIDENCE_DEST="$ANIMA_ROOT/state/akida_evidence"
NEXUS_DEST="$NEXUS_ROOT/state/akida_evidence"
XENO_DEST="$XENO_ROOT/state/akida_cloud_d0_${DATE}"

cmd="${1:-pull}"
case "$cmd" in
  pull)
    alias_n=$(secret get akida_cloud.ssh_alias 2>/dev/null || echo akida-cloud)
    mkdir -p "$ANIMA_DEST" "$ANIMA_EVIDENCE_DEST" "$XENO_DEST"
    echo "[P6] exfil from $alias_n"
    echo "  → $ANIMA_DEST           (anima cloud session state)"
    echo "  → $ANIMA_EVIDENCE_DEST  (anima akida_evidence — append, F-M3b/M4 등)"
    echo "  → $NEXUS_DEST           (nexus akida_evidence — append)"
    echo "  → $XENO_DEST            (xeno cloud session state — SSOT)"
    # Cloud-side dir created by `xeno cycle remote measure --out-dir` is
    #   ~/work/state/akida_cloud_d0_${DATE}/   (flat, JSON files inside)
    # We rsync that dir's *contents* (trailing slash) into the local dest,
    # keeping a flat layout. Earlier versions pulled `~/work/state/` itself
    # which produced a nested akida_cloud_d0_${DATE}/akida_cloud_d0_${DATE}/.
    rsync -avh --progress "$alias_n":"~/work/state/akida_cloud_d0_${DATE}/" "$ANIMA_DEST/" 2>&1 || echo "  (anima rsync soft-fail)"
    rsync -avh --progress "$alias_n":'~/work/anima/state/akida_evidence/' "$ANIMA_EVIDENCE_DEST/" 2>&1 || echo "  (anima_evidence rsync soft-fail)"
    rsync -avh --progress "$alias_n":'~/work/nexus/state/akida_evidence/' "$NEXUS_DEST/" 2>&1 || echo "  (nexus rsync soft-fail)"
    rsync -avh --progress "$alias_n":"~/work/state/akida_cloud_d0_${DATE}/" "$XENO_DEST/" 2>&1 || echo "  (xeno rsync soft-fail)"
    echo "[P6] exfil complete. Verify: $0 verify"
    ;;
  verify)
    fail=0
    for d in "$ANIMA_DEST" "$ANIMA_EVIDENCE_DEST" "$NEXUS_DEST" "$XENO_DEST"; do
      if [[ ! -d "$d" ]]; then echo "  ✗ $d — missing"; fail=$((fail + 1)); continue; fi
      n=$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')
      if [[ $n -eq 0 ]]; then echo "  △ $d — empty"; else echo "  ✓ $d — $n files"; fi
    done
    [[ $fail -eq 0 ]]
    ;;
  archive)
    archive="$XENO_ROOT/state/akida_cloud_archive_${DATE}.tar.zst"
    if ! command -v zstd >/dev/null 2>&1; then
      archive="$XENO_ROOT/state/akida_cloud_archive_${DATE}.tar.gz"
      tar -czf "$archive" -C "$XENO_ROOT/state" "akida_cloud_d0_${DATE}"
    else
      tar --use-compress-program="zstd -19" -cf "$archive" -C "$XENO_ROOT/state" "akida_cloud_d0_${DATE}"
    fi
    echo "[P6] archive: $archive ($(ls -lh "$archive" | awk '{print $5}'))"
    ;;
  *) echo "usage: $0 {pull | verify | archive}" >&2; exit 2 ;;
esac
