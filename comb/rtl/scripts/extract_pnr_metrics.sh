#!/usr/bin/env bash
# extract_pnr_metrics.sh — parse ORFS reports/logs and emit a compact
# metrics summary for one design. Used by task #14 (d6 vs d4 compare).
#
# Usage:
#   extract_pnr_metrics.sh <orfs_design_dir>
#
# where <orfs_design_dir> contains the standard ORFS subtree:
#   <dir>/reports/sky130hd/<design>/base/*.rpt
#   <dir>/logs/sky130hd/<design>/base/*.log
#   <dir>/results/sky130hd/<design>/base/*.{odb,def,gds.gz,v}
#
# Emits a single table to stdout. Fields with NA = report file missing
# or the metric not produced at the run stage reached.

set -uo pipefail

DIR=${1:-.}
DESIGN=$(basename $(ls -d $DIR/reports/sky130hd/*/ 2>/dev/null | head -1) 2>/dev/null)
[ -z "$DESIGN" ] && DESIGN="<unknown>"

REPORTS=$DIR/reports/sky130hd/$DESIGN/base
LOGS=$DIR/logs/sky130hd/$DESIGN/base
RESULTS=$DIR/results/sky130hd/$DESIGN/base

get() {
    # get FIELD-REGEX FILE-GLOB → first capture group, or NA
    local re="$1"
    shift
    for f in "$@"; do
        [ -f "$f" ] || continue
        local v=$(grep -oE "$re" "$f" 2>/dev/null | head -1)
        if [ -n "$v" ]; then echo "$v"; return; fi
    done
    echo "NA"
}

# --- area (post-route 6_finish.rpt or 5_route.rpt; pre-route 3_*.rpt fallback) ---
DIE_AREA=$(get "Die area: ([0-9.]+)" $REPORTS/6_finish.rpt $REPORTS/5_route.rpt $REPORTS/3_global_place.rpt)
CORE_AREA=$(get "Core area: ([0-9.]+)" $REPORTS/6_finish.rpt $REPORTS/5_route.rpt $REPORTS/3_global_place.rpt)
CELL_AREA=$(get "Total cell area: ([0-9.]+)" $REPORTS/6_finish.rpt $REPORTS/5_route.rpt $REPORTS/3_resizer.rpt)
UTIL=$(get "utilization[^0-9]*([0-9.]+)" $REPORTS/3_global_place.rpt $REPORTS/3_detailed_place.rpt)

# --- timing (from sta_final or finish report) ---
WNS_SETUP=$(get "wns[^-0-9]*(-?[0-9.]+)" $REPORTS/6_finish.rpt $LOGS/6_report.log)
TNS_SETUP=$(get "tns[^-0-9]*(-?[0-9.]+)" $REPORTS/6_finish.rpt $LOGS/6_report.log)
WNS_HOLD=$(get "hold wns[^-0-9]*(-?[0-9.]+)" $REPORTS/6_finish.rpt)
TNS_HOLD=$(get "hold tns[^-0-9]*(-?[0-9.]+)" $REPORTS/6_finish.rpt)

# --- power (from 6_finish.rpt or sta power report) ---
TOTAL_POWER=$(get "Total[[:space:]]+([0-9.]+e?[-+]?[0-9]*)" $REPORTS/6_finish.rpt)

# --- wire length (routed) ---
WIRE_LEN=$(get "Total wire length: ([0-9.]+)" $REPORTS/5_route.rpt $LOGS/5_2_route.log)

# --- DRC violations from detailed route ---
DRC=$(get "Number of violations:[[:space:]]+([0-9]+)" $REPORTS/5_route.rpt $LOGS/5_2_route.log)

# --- routed stage reached ---
STAGE_REACHED="unknown"
[ -f $RESULTS/1_synth.v ]      && STAGE_REACHED="synth"
[ -f $RESULTS/2_floorplan.odb ] && STAGE_REACHED="floorplan"
[ -f $RESULTS/3_place.odb ]    && STAGE_REACHED="place"
[ -f $RESULTS/4_cts.odb ]      && STAGE_REACHED="cts"
[ -f $RESULTS/5_route.odb ]    && STAGE_REACHED="route"
[ -f $RESULTS/6_final.gds.gz ] && STAGE_REACHED="finish-GDS"

printf "design                  %s\n" "$DESIGN"
printf "stage_reached           %s\n" "$STAGE_REACHED"
printf "die_area_um2            %s\n" "$DIE_AREA"
printf "core_area_um2           %s\n" "$CORE_AREA"
printf "std_cell_area_um2       %s\n" "$CELL_AREA"
printf "placement_util_pct      %s\n" "$UTIL"
printf "wns_setup_ns            %s\n" "$WNS_SETUP"
printf "tns_setup_ns            %s\n" "$TNS_SETUP"
printf "wns_hold_ns             %s\n" "$WNS_HOLD"
printf "tns_hold_ns             %s\n" "$TNS_HOLD"
printf "total_power             %s\n" "$TOTAL_POWER"
printf "wire_length_um          %s\n" "$WIRE_LEN"
printf "drc_violations          %s\n" "$DRC"
