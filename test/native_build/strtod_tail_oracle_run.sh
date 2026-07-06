#!/usr/bin/env bash
# strtod_tail_oracle_run.sh — strtod-tail flip gate (zeroc #29). Run on aiden (glibc)
# and ghost (Apple libc) from the repo root at the candidate commit.
set -uo pipefail
CC="${CC:-clang}"
HEXA="${HEXA:-hexa}"
OUT="${OUT:-/tmp/strtod_tail_gate}"
mkdir -p "$OUT"

# 1. OFF baseline runtime.a (default lanes: numf-native + EXACT ON, tail OFF)
rm -f build/float_parse_hexinfnan_native.o
CC="$CC" bash tool/stage_resolve_runtime_a >"$OUT/resolve_off.log" 2>&1 || { echo FATAL:resolve-off; exit 1; }
cp build/runtime.a "$OUT/runtime_off.a"

# 2. ON runtime.a — assembles the FROZEN self/native/float_parse_hexinfnan_*.s seed
rm -f build/float_parse_hexinfnan_native.o
CC="$CC" HEXA_RT_STRTOD_TAIL_NATIVE=1 bash tool/stage_resolve_runtime_a >"$OUT/resolve_on.log" 2>&1 || { echo FATAL:resolve-on; exit 1; }
grep -q "RT-NATIVE STRTOD-TAIL: HEXA_RT_STRTOD_TAIL_NATIVE=1" "$OUT/resolve_on.log" || { echo "FATAL: tail seed did not engage"; exit 1; }
cp build/runtime.a "$OUT/runtime_on.a"
nm "$OUT/runtime_on.a" 2>/dev/null | grep -q "T _\?rt_str_parse_float_hexinfnan" || { echo "FATAL: seed symbol missing from runtime_on.a"; exit 1; }

# 3. build the harness against EACH archive (cache cleared — stale-cache gotcha)
rm -rf ~/.hexa-cache
HEXA_PREBUILT_RUNTIME="$OUT/runtime_on.a"  "$HEXA" build test/native_build/strtod_tail_oracle.hexa -o "$OUT/tail_on"  || exit 1
rm -rf ~/.hexa-cache
HEXA_PREBUILT_RUNTIME="$OUT/runtime_off.a" "$HEXA" build test/native_build/strtod_tail_oracle.hexa -o "$OUT/tail_off" || exit 1

# 4. run (deterministic ~140k-case corpus)
"$OUT/tail_on"  > "$OUT/on.tsv"  || { echo FATAL:on-run;  exit 1; }
"$OUT/tail_off" > "$OUT/off.tsv" || { echo FATAL:off-run; exit 1; }
grep -q "^# ORACLE-OK" "$OUT/on.tsv" || { echo "FATAL: in-process oracle degraded"; head -5 "$OUT/on.tsv"; exit 1; }

# 5. independent re-verify vs real strtod (C driver) — THE GATE
"$CC" -O2 -o "$OUT/ref" test/native_build/strtod_tail_oracle_ref.c || exit 1
echo "== GATE (tail ON vs host strtod) =="
"$OUT/ref" < "$OUT/on.tsv"; GATE=$?
echo "== informational: today's OFF path vs strtod (nonzero T mismatches EXPECTED pre-flip) =="
"$OUT/ref" < "$OUT/off.tsv" || true

# 6. finite regression A/B: F+J lines must be byte-identical ON vs OFF
grep -E '^[FJ] ' "$OUT/on.tsv"  > "$OUT/fj_on"
grep -E '^[FJ] ' "$OUT/off.tsv" > "$OUT/fj_off"
if diff -q "$OUT/fj_on" "$OUT/fj_off" >/dev/null; then
    echo "FINITE-REGRESSION OK (F/J byte-identical ON vs OFF)"
else
    echo "FINITE-REGRESSION FAIL"; diff "$OUT/fj_on" "$OUT/fj_off" | head -20; GATE=1
fi
tail -4 "$OUT/on.tsv"
exit $GATE
