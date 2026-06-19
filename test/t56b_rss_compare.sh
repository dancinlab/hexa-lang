#!/bin/bash
# t56b_rss_compare.sh — 2-process RSS proof for the .bin unbox (boxing-unbox r2).
#
# Builds a raw f32 .bin ONCE with python3 (NO boxed-hexa intermediates — the
# fixture build must not itself dominate RSS), then loads it two ways in
# SEPARATE COMPILED processes and compares peak RSS (/usr/bin/time -v):
#   • read_f32_array_at  → farr32 (native float[], 4 B/elem)  ≈ 1× raw
#   • read_bytes_at+box  → boxed int[] then boxed [float]      ≫ raw
#
# The ratio (boxed_peak / farr32_peak) is the load-bearing RSS lever proof.
# Usage: bash test/t56b_rss_compare.sh [N_floats]   (default 4_000_000 = 16 MB raw)
#
# NOTE: `hexa run` caches the compiled binary BY SOURCE PATH; the two load
# programs are SEPARATE files so they get distinct cache entries. We also
# `ulimit -v` each load to protect the shared pool host from a pathological
# blowup (the boxed path is bounded well under the cap at the default N).
set -u
N="${1:-4000000}"
BIN=/tmp/_t56_raw_f32.bin
HEXA="${HEXA:-hexa}"
TIME=/usr/bin/time
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "=== building .bin (N=$N floats, $((N*4/1048576)) MB raw) via python3 ==="
python3 "$HERE/t56_make_bin.py" "$BIN" "$N" || { echo "GEN FAILED"; exit 1; }

peak() {  # $1 label; $2.. command — prints program line + PEAK_RSS_KB to stderr; echoes KB
    local label="$1"; shift
    local out kb
    out=$( ( ulimit -v 16777216; $TIME -v "$@" ) 2>&1 )
    echo "$out" | grep -E "FARR32|BOXED|bad_alloc|out of memory|Killed" >&2 || true
    kb=$(echo "$out" | grep -i "Maximum resident set size" | grep -oE "[0-9]+" | head -1)
    echo "$label PEAK_RSS_KB=$kb" >&2
    echo "$kb"
}

echo "=== farr32 (unboxed) load ==="
F_KB=$(peak FARR32 "$HEXA" run "$HERE/t56b_rss_farr32.hexa")
echo "=== boxed (old full-load) load ==="
B_KB=$(peak BOXED "$HEXA" run "$HERE/t56b_rss_boxed.hexa")

echo "=== RESULT ==="
echo "raw_payload_MB = $((N*4/1048576))"
echo "farr32 peak RSS = ${F_KB:-?} KB ($(( ${F_KB:-0}/1024 )) MB)"
echo "boxed  peak RSS = ${B_KB:-?} KB ($(( ${B_KB:-0}/1024 )) MB)"
if [ -n "${F_KB:-}" ] && [ -n "${B_KB:-}" ] && [ "${F_KB:-0}" -gt 0 ]; then
    awk "BEGIN{printf \"boxed/farr32 RSS ratio = %.1fx  (farr32 = the unbox lever)\n\", $B_KB/$F_KB}"
    awk "BEGIN{printf \"farr32 RSS/raw = %.2fx ; boxed RSS/raw = %.1fx\n\", $F_KB*1024/($N*4.0), $B_KB*1024/($N*4.0)}"
fi
