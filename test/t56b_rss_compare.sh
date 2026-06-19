#!/bin/bash
# t56b_rss_compare.sh — 2-process RSS proof for the .bin unbox (boxing-unbox r2).
#
# Builds a raw f32 .bin ONCE with python3 (NO boxed-hexa intermediates — the
# fixture build must not itself dominate RSS), then loads it two ways in
# SEPARATE COMPILED processes and compares peak RSS (/usr/bin/time -v):
#   • read_f32_array_at  → farr32 (native float[], 4 B/elem)
#   • read_bytes_at      → boxed int[] (one HexaVal per BYTE, ~16 B/byte)
#
# To remove the fixed compiled-binary/runtime baseline (~80 MB at v0.241.10),
# we also measure an EMPTY hexa program and subtract its peak RSS, so the
# reported delta is the LOAD-attributable resident growth. Run N large enough
# that the payload dominates the baseline (default 16 M floats = 64 MB raw).
#
# Usage: bash test/t56b_rss_compare.sh [N_floats]
# NOTE: bytes_to_f32_le crashes the v0.241.10 transpiler (separate bug), so the
# boxed witness uses read_bytes_at's boxed int[] alone — already the boxing
# blowup head. ulimit -v guards the shared pool host from a pathological blowup.
set -u
N="${1:-16000000}"
BIN=/tmp/_t56_raw_f32.bin
HEXA="${HEXA:-hexa}"
TIME=/usr/bin/time
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "=== building .bin (N=$N floats, $((N*4/1048576)) MB raw) via python3 ==="
python3 "$HERE/t56_make_bin.py" "$BIN" "$N" || { echo "GEN FAILED"; exit 1; }

EMPTY=/tmp/_t56_empty.hexa
echo 'println("empty")' > "$EMPTY"

peak() {  # $1 label; $2.. command — prints stdout line + PEAK_RSS_KB to stderr; echoes KB
    local label="$1"; shift
    local out kb
    out=$( ( ulimit -v 16777216; $TIME -v "$@" ) 2>&1 )
    echo "$out" | grep -E "FARR32|BOXED|empty|bad_alloc|out of memory|Killed|cannot allocate" >&2 || true
    kb=$(echo "$out" | grep -i "Maximum resident set size" | grep -oE "[0-9]+" | head -1)
    echo "$label PEAK_RSS_KB=$kb" >&2
    echo "$kb"
}

echo "=== baseline (empty program) ==="
E_KB=$(peak EMPTY "$HEXA" run "$EMPTY")
echo "=== farr32 (unboxed) load ==="
F_KB=$(peak FARR32 "$HEXA" run "$HERE/t56b_rss_farr32.hexa")
echo "=== boxed (read_bytes_at int[]) load ==="
B_KB=$(peak BOXED "$HEXA" run "$HERE/t56b_rss_boxed.hexa")

echo "=== RESULT ==="
RAW_KB=$((N*4/1024))
echo "raw_payload      = $((N*4/1048576)) MB ($RAW_KB KB)"
echo "baseline (empty) = ${E_KB:-?} KB"
echo "farr32 peak RSS  = ${F_KB:-?} KB ($(( ${F_KB:-0}/1024 )) MB)"
echo "boxed  peak RSS  = ${B_KB:-?} KB ($(( ${B_KB:-0}/1024 )) MB)"
if [ -n "${E_KB:-}" ] && [ -n "${F_KB:-}" ] && [ -n "${B_KB:-}" ]; then
    FD=$((F_KB - E_KB)); BD=$((B_KB - E_KB))
    echo "farr32 load-RSS (minus baseline) = $FD KB"
    echo "boxed  load-RSS (minus baseline) = $BD KB"
    [ "$FD" -gt 0 ] && awk "BEGIN{printf \"farr32 load-RSS / raw = %.2fx  (target ~1x: native float[] 4 B/elem)\n\", $FD/$RAW_KB}"
    [ "$FD" -gt 0 ] && awk "BEGIN{printf \"boxed  load-RSS / raw = %.1fx  (read_bytes_at boxed int[] ~16 B/byte)\n\", $BD/$RAW_KB}"
    [ "$FD" -gt 0 ] && awk "BEGIN{printf \"boxed/farr32 load-RSS ratio = %.1fx  (the unbox lever)\n\", $BD/$FD}"
fi
