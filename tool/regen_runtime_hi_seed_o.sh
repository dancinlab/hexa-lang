#!/usr/bin/env bash
# tool/regen_runtime_hi_seed_o.sh — RFC 061 ∅ campaign zero-c r13 (ING #35).
# Assemble build/runtime_hi_seed.o from the SSOT-emitted seed C
# self/native/runtime_hi_seed.c (the first batch of runtime.c PROPER's HI-tier
# bodies — 12 self-contained leaf rt_* prims). 1-line TU pulls runtime.h.
#
# Regenerates the .c from the emitter SSOT (self/runtime_emit.hexa) first, so
# the seed always tracks the emitter, hexat-free + byte-deterministic.
#
# The DEFAULT / shipping build NEVER compiles this (byte-identical OFF). The
# seed supplies the SAME symbols frozen runtime.c defines — used ONLY under
# the experimental drop path. CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
OUT="${1:-$ROOT/build/runtime_hi_seed.o}"
SEED="$ROOT/self/native/runtime_hi_seed.c"

# (re)generate the seed .c from the committed emitter SSOT
bash "$ROOT/tool/regen_runtime_hi_seed_c.sh" "$ROOT" >/dev/null 2>&1 || true
[ -f "$SEED" ] || { echo "regen_runtime_hi_seed: missing $SEED (emitter regen failed)" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/runtime_hi_seed_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/runtime_hi_seed.c"\n' > "$TU"
EXTRA=""; [ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:' | head -8
[ -f "$OUT" ] || { echo "regen_runtime_hi_seed: compile failed (no $OUT)" >&2; exit 2; }
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(rt_isalnum|rt_isalpha|rt_net_fail|rt_net_zero|rt_posix_ok|rt_pthread_noop|rt_pthread_create_policy|rt_fmod|rt_exp|rt_log|rt_cos|rt_sin)$')"
echo "regen_runtime_hi_seed: $OUT — $N/12 HI-tier leaf rt_* bodies exported"
[ "$N" = "12" ] || { echo "regen_runtime_hi_seed: expected 12, got $N" >&2; exit 3; }
