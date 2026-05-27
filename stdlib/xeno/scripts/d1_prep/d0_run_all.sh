#!/usr/bin/env bash
# D+0 run all — fire 8 post-arrival falsifier + 3 anima lanes (N-2/N-3/N-5)
# inside Akida Cloud session. Run AFTER `xeno cycle connect` + manual upload.
#
# Subcommands:
#   bootstrap   verify akida package import + AKD1000 device probe
#   falsifier   fire 8 post-arrival falsifier (F-L1/L1+/L6/M1/M3b/M4/A/B)
#   anima       fire N-2/N-3/N-5 anima lanes
#   all         bootstrap + falsifier + anima (full D+0 cycle)
set -euo pipefail

# This script is meant to run INSIDE Akida Cloud session, after upload.
# Cloud-side paths (after tar -xzf ~/payload.tar.gz -C ~/work/):
WORK="${WORK:-$HOME/work}"
NEXUS_AKIDA="$WORK/nexus/scripts/akida"
ANIMA_AKIDA="$WORK/anima/scripts/akida"
EVIDENCE_DIR="${EVIDENCE_DIR:-$WORK/state/akida_evidence}"

mkdir -p "$EVIDENCE_DIR"
export EVIDENCE_DIR

cmd="${1:-all}"
case "$cmd" in
  bootstrap)
    echo "[D+0 bootstrap] akida package + device probe"
    python3 -c "import akida; print('akida pkg:', akida.__version__)" 2>&1 | head -3 || echo "  ✗ akida package missing — install in cloud env"
    python3 -c "import akida; devs = akida.devices(); print('devices:', devs)" 2>&1 | head -3 || echo "  ✗ device probe failed"
    ;;
  falsifier)
    echo "[D+0 falsifier] fire 8 post-arrival via runner.py --hardware"
    cd "$NEXUS_AKIDA" && python3 runner.py --hardware 2>&1 | tee "$EVIDENCE_DIR/runner_hardware_$(date +%Y%m%dT%H%M%SZ).log"
    ;;
  anima)
    echo "[D+0 anima] fire N-2/N-3/N-5 lanes"
    cd "$ANIMA_AKIDA"
    # N-3: CLM × AKIDA Φ pipeline (last-layer-only, ~$1.60)
    if [[ -f "phi_substrate_invariance.py" ]]; then
      python3 phi_substrate_invariance.py --last-layer-only 2>&1 | tee "$EVIDENCE_DIR/anima_n3_phi_$(date +%Y%m%dT%H%M%SZ).log" || echo "  N-3 soft-fail"
    fi
    # N-5: GWT broadcast AKIDA-SSI
    if [[ -f "trace_equivalence.py" ]]; then
      python3 trace_equivalence.py 2>&1 | tee "$EVIDENCE_DIR/anima_n5_trace_$(date +%Y%m%dT%H%M%SZ).log" || echo "  N-5 soft-fail"
    fi
    # N-2: EEG → AKIDA spike pipeline (skeleton, dry-run only)
    echo "  N-2 spike pipeline: dry-run skeleton (full impl pending Phase 1.5)"
    ;;
  all)
    "$0" bootstrap
    "$0" falsifier
    "$0" anima
    echo "[D+0 all] complete. Exfil before D+1 close: xeno cycle exfil"
    ;;
  *) echo "usage: $0 {bootstrap | falsifier | anima | all}" >&2; exit 2 ;;
esac
