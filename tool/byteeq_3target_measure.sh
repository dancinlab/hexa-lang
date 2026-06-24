#!/usr/bin/env bash
# 3-target source-config byteeq for the M3-include-drop default-flip readiness.
# For each target triple, prove:
#   (1) DEFAULT_BYTE_IDENTICAL  : flag-OFF preprocessed -E -P SHA of the
#        drop-guard-patched runtime.c == the pristine frozen runtime.c SHA
#        (the RELEASE GATE — proves the opt-in guard is transparent when OFF)
#   (2) DROP_ON_COMPILES        : runtime.c compiles -c with the drop-include
#        guard + all M5 cluster externs (the include-drop config is buildable)
# Run AT REPO ROOT of the M5-stack worktree. MEASURE-ONLY (no default flip).
set -uo pipefail
cd "$(dirname "$0")/.." 2>/dev/null || true
ROOT="${ROOT:-$PWD}"; cd "$ROOT"
CC=clang

CLUSTER_DEFS="-DHEXA_RT_CORE_LEAF_NATIVE=1 -DHEXA_RT_CORE_ARITH_NATIVE=1 \
-DHEXA_RT_CORE_MATH_NATIVE=1 -DHEXA_RT_CORE_MATH2_NATIVE=1 \
-DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE=1 -DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE=1 \
-DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE=1 -DHEXA_RT_CORE_FS_READ_WRITE_NATIVE=1 \
-DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE=1 -DHEXA_RT_CORE_RUNTIME_MISC_NATIVE=1 \
-DHEXA_RT_CORE_VALOP_DISPATCH_NATIVE=1 -DHEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE=1 \
-DHEXA_RT_CORE_STRARR_READ_NATIVE=1 -DHEXA_ZEROC_RT_CORE_STRBUF_ARENA=1"

probe_target() {
  local label="$1" triple="$2" osdef="$3"
  echo "──── target: $label ($triple) ────"
  # fresh frozen restore + regen for a clean baseline each target
  bash tool/restore_frozen_seeds      >/dev/null 2>&1
  bash tool/regen_runtime_core_c.sh   >/dev/null 2>&1
  local EP="-E -P -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self -I . $osdef --target=$triple"
  local sha_frozen sha_patched
  sha_frozen=$($CC $EP self/runtime.c 2>/dev/null | sha256sum | cut -c1-16)
  bash tool/zeroc_drop_rtcore_include.sh >/dev/null 2>&1   # apply opt-in guard (default OFF)
  sha_patched=$($CC $EP self/runtime.c 2>/dev/null | sha256sum | cut -c1-16)
  echo "  DEFAULT(OFF) -E -P SHA frozen  : $sha_frozen"
  echo "  DEFAULT(OFF) -E -P SHA patched : $sha_patched"
  if [ -n "$sha_frozen" ] && [ "$sha_frozen" = "$sha_patched" ]; then
    echo "  ${label}_DEFAULT_BYTE_IDENTICAL=YES"
  else
    echo "  ${label}_DEFAULT_BYTE_IDENTICAL=NO"
  fi
  # drop-ON compile
  local CF="-c -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self -I . $osdef --target=$triple"
  if $CC $CF -DHEXA_ZEROC_DROP_RTCORE_INCLUDE -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS \
       self/runtime.c -o /tmp/rt_${label}.o 2>/tmp/rt_${label}.err; then
    echo "  ${label}_DROP_ON_COMPILES=YES (runtime.o $(wc -c </tmp/rt_${label}.o) B)"
  else
    echo "  ${label}_DROP_ON_COMPILES=NO"
    grep -i 'error:' /tmp/rt_${label}.err | head -4 | sed 's/^/      /'
  fi
}

echo "════════ 3-TARGET M3-DROP byteeq (source-config) ════════"
probe_target "linux_x86_64"  "x86_64-pc-linux-gnu"     ""
probe_target "linux_arm64"   "aarch64-linux-gnu"       ""
probe_target "darwin_arm64"  "arm64-apple-darwin"      "-D_DARWIN_C_SOURCE"
echo "════════ DONE ════════"
