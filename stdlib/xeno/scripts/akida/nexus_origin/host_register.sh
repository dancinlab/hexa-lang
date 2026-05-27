#!/usr/bin/env bash
# Register host.rpi5-akida in ~/core/.workspace.
# Event-driven: refuses to register without F-L1 + F-M3a evidence on disk
# (per docs/akida_dev_kit_evaluation_2026-04-29 — "추가 시점: dev kit 도착 +
#  Meta TF 첫 변환 PASS 후 event-driven 등재").
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/core/.workspace}"
EVIDENCE_DIR="${EVIDENCE_DIR:-state/akida_evidence}"
FORCE="${FORCE:-0}"
SIMULATOR="${SIMULATOR:-0}"

LABEL_KIND="low-power-inference"
SUBSTRATE_NOTE=""
if [[ "$SIMULATOR" == "1" ]]; then
  LABEL_KIND="low-power-inference-simulator"
  SUBSTRATE_NOTE=" (cpu_emulator_cnn2snn_stub — NOT promotion-eligible)"
fi

if [[ "$FORCE" != "1" && "$SIMULATOR" != "1" ]]; then
  if ! ls "$EVIDENCE_DIR"/F-L1_*.json >/dev/null 2>&1; then
    echo "ERROR: no F-L1 evidence at $EVIDENCE_DIR/F-L1_*.json — run energy_meter.py first or set FORCE=1 or SIMULATOR=1" >&2
    exit 2
  fi
  if ! grep -q '"verdict": *"PASS"' "$EVIDENCE_DIR"/F-L1_*.json 2>/dev/null; then
    echo "ERROR: F-L1 evidence exists but no PASS verdict found — set FORCE=1 or SIMULATOR=1 to override" >&2
    exit 3
  fi
fi

if [[ ! -f "$WORKSPACE" ]]; then
  echo "ERROR: workspace file not found at $WORKSPACE" >&2
  exit 4
fi

if grep -q '^resource host\.rpi5-akida ' "$WORKSPACE"; then
  echo "host.rpi5-akida already registered in $WORKSPACE — no-op"
  exit 0
fi

ANCHOR='^resource gpu\.h100 '
if ! grep -q "$ANCHOR" "$WORKSPACE"; then
  echo "ERROR: anchor line 'resource gpu.h100' not found — workspace schema unexpected" >&2
  exit 5
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TMP="$(mktemp)"
awk -v ts="$TS" -v label_kind="$LABEL_KIND" -v note="$SUBSTRATE_NOTE" '
  /^resource gpu\.h100 / { in_block=1 }
  in_block && /^$/ {
    print
    print "resource host.rpi5-akida \"RPi5 + Akida AKD1000 — neuromorphic edge-inference (M.2 B+M, ~1W, 16GB, ~1.2M neurons)" note "\""
    print "  owner    nexus"
    print "  kind     descriptor"
    print "  label    " label_kind
    print "  label    neuromorphic"
    print "  registered " ts
    in_block=0
    next
  }
  { print }
' "$WORKSPACE" > "$TMP"

if ! diff -q "$WORKSPACE" "$TMP" >/dev/null; then
  cp "$WORKSPACE" "$WORKSPACE.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  mv "$TMP" "$WORKSPACE"
  echo "registered host.rpi5-akida in $WORKSPACE (backup written)"
else
  rm -f "$TMP"
  echo "ERROR: anchor matched but block insertion produced no change" >&2
  exit 6
fi
