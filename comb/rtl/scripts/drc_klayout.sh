#!/usr/bin/env bash
# drc_klayout.sh — run KLayout sky130 DRC on an ORFS-produced GDS.
# Used by task #15 (DRC + T3 summary).
#
# Usage:
#   drc_klayout.sh <gds_file>  [<lyrdb_out>]
#
# Default DRC deck: sky130A precheck (bundled in open_pdks). If your
# KLayout has the open_pdks sky130A precheck deck installed, point KDRC
# at that .lydrc file. Otherwise this falls back to a minimal "extent +
# layer-count + density" check that's better-than-nothing.
#
# Inside docker (openroad/orfs image bundles sky130A DRC decks), prefer:
#   docker run --rm -v $PWD:/work openroad/orfs:latest \
#       klayout -b -r /open_pdks/sky130A/libs.tech/klayout/drc/sky130A.lydrc \
#               -rd input=/work/<gds> -rd report=/work/<gds>.drc.lyrdb
#
# Host-side (KLayout installed via brew cask): use the same lydrc path
# from a sky130 install. If lydrc not found, this script reports a
# layer count and bbox extent as a sanity check, no full DRC.

set -uo pipefail

GDS=${1:?usage: drc_klayout.sh <gds_file> [<lyrdb_out>]}
OUT=${2:-${GDS%.gds*}.drc.lyrdb}

[ -f "$GDS" ] || { echo "DRC-FAIL: no such file: $GDS" ; exit 2; }

# Resolve KLayout CLI
KLAYOUT=$(command -v klayout)
[ -z "$KLAYOUT" ] && [ -x /Applications/KLayout/klayout.app/Contents/MacOS/klayout ] && \
    KLAYOUT=/Applications/KLayout/klayout.app/Contents/MacOS/klayout
[ -z "$KLAYOUT" ] && { echo "DRC-FAIL: klayout binary not found"; exit 3; }

# Try common sky130A DRC deck locations
DECK=""
for cand in \
    /open_pdks/sky130A/libs.tech/klayout/drc/sky130A.lydrc \
    /usr/local/share/pdk/sky130A/libs.tech/klayout/drc/sky130A.lydrc \
    "$HOME/.volare/sky130A/libs.tech/klayout/drc/sky130A.lydrc" \
    /opt/homebrew/share/sky130A/libs.tech/klayout/drc/sky130A.lydrc ; do
    [ -f "$cand" ] && DECK="$cand" && break
done

if [ -n "$DECK" ]; then
    echo "DRC-DECK: $DECK"
    "$KLAYOUT" -b -r "$DECK" -rd input="$GDS" -rd report="$OUT" 2>&1 | tail -20
    echo "DRC-REPORT: $OUT"
    # KLayout exits 0 even on violations; count from lyrdb if present
    if [ -f "$OUT" ]; then
        viol=$(grep -c '<item>' "$OUT" 2>/dev/null || echo 0)
        echo "DRC-VIOLATIONS: $viol"
        [ "$viol" = "0" ] && echo "DRC-CLEAN" || echo "DRC-VIOLATIONS-PRESENT"
    fi
else
    echo "DRC-DECK: missing — falling back to sanity check (layer count + bbox)"
    "$KLAYOUT" -b -rm - <<'PY' "$GDS"
import pya, sys
ly = pya.Layout()
ly.read(sys.argv[1])
top = ly.top_cell()
bbox = top.bbox()
print(f"top_cell={top.name}")
print(f"bbox_um=({bbox.left/ly.dbu:.1f},{bbox.bottom/ly.dbu:.1f})..({bbox.right/ly.dbu:.1f},{bbox.top/ly.dbu:.1f})")
print(f"layers={ly.layer_indices().size()}")
print(f"cells={ly.cells()}")
print("DRC-SANITY-ONLY (no real rule deck)")
PY
fi
