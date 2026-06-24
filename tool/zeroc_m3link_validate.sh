#!/usr/bin/env bash
# tool/zeroc_m3link_validate.sh — RFC061 zero-c #29 M3-LINK + M4 validation.
#
# PURPOSE
# ───────
# PROBE-A (tool/zeroc_flip_measure.sh) measures only the RELOCATABLE-object
# undefined set of the drop-ON runtime.c (nm -u of a single .o). That count
# (115: svc 0 / libm 23 / crt 14 / wrapper_missing 15 / libc-posix 63) is NOT
# the link wall — most of those are standard libc/libm symbols a normal
# executable link resolves via `-lm -lc -ldl`.
#
# This script performs the ACTUAL M3-LINK: it assembles the same link the
# release path assembles (stage_build_hexa:165 → `$CC ... $RT_ARG -o exe $LIBS`,
# LIBS="-lm -ldl" on Linux), but with the DROP-ON runtime:
#
#     runtime_dropON.o  (runtime.c, HEXA_ZEROC_DROP_RTCORE_INCLUDE — body dropped)
#   + runtime_core.o    (runtime_core.c compiled STANDALONE — external linkage)
#   + build/*.o         (all landed native seed objects)
#   + -lm -lc -ldl      (M4: the libm + libc/CRT externs a normal link resolves)
#
# and reports the TRUE residual undefined set after a real `-lm -lc` link —
# proving the drop-ON config links to a working object graph with only the
# genuinely-irreducible externals remaining (the M5 HexaVal-ABI wrapper bodies
# + the irreducible-J floor).
#
# It does NOT touch the 15 wrapper ABI bodies (M5) and does NOT flip any default.
# MEASURE-ONLY: writes to /tmp + build/*.o (gitignored). Never stages/commits.
#
# Usage:  bash tool/zeroc_m3link_validate.sh
#         OUT_DIR=/tmp/m3link bash tool/zeroc_m3link_validate.sh
set -uo pipefail

ROOT="${ROOT:-$PWD}"
OUT_DIR="${OUT_DIR:-/tmp/zeroc_m3link}"
CC="${CC:-clang}"
mkdir -p "$OUT_DIR"
cd "$ROOT" || { echo "m3link: bad ROOT '$ROOT'" >&2; exit 1; }
[ -f self/runtime_core_emit.hexa ] || { echo "m3link: run at repo root" >&2; exit 1; }

case "$(uname -m)" in
  x86_64)        ARCH=x86_64 ;;
  aarch64|arm64) ARCH=arm64  ;;
  *)             ARCH="$(uname -m)" ;;
esac
OS="$(uname -s)"
# the real release LIBS on Linux; macOS links libSystem implicitly (no -lm/-ldl)
if [ "$OS" = "Darwin" ]; then LIBS="-lm"; else LIBS="-lm -lc -ldl -lpthread"; fi

echo "════════════════════════════════════════════════════════════════"
echo " zeroc_m3link_validate — RFC061 M3-LINK + M4 (-lm -lc) real link"
echo "   host $(uname -srm)   commit $(git rev-parse --short HEAD 2>/dev/null)"
echo "   LIBS=\"$LIBS\""
echo "════════════════════════════════════════════════════════════════"

# ── stage 1: restore frozen seeds + regen runtime_core.c + apply drop guard ──
echo "[1] restore_frozen_seeds + regen runtime_core.c + apply drop-include guard…"
bash tool/restore_frozen_seeds       >/dev/null 2>&1 || { echo "restore failed" >&2; exit 1; }
bash tool/regen_runtime_core_c.sh    >/dev/null 2>&1 || { echo "regen failed" >&2; exit 1; }
bash tool/zeroc_drop_rtcore_include.sh >/dev/null 2>&1 || true
GUARD_N=$(grep -c 'ZEROC_DROP_RTCORE_INCLUDE_GUARD' self/runtime.c 2>/dev/null || echo 0)
echo "    drop-include guard sites: $GUARD_N"
# frozen-blob immutability check (must be empty diff)
FROZEN_DIFF=$(git diff 151c52c8 -- self/runtime.c 2>/dev/null | wc -l | tr -d ' ')
echo "    git diff 151c52c8 -- self/runtime.c lines: $FROZEN_DIFF (must be 0)"

CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self -I ."
[ "$OS" = "Darwin" ] && CFLAGS="$CFLAGS -D_DARWIN_C_SOURCE"

CLUSTER_DEFS="\
-DHEXA_RT_CORE_LEAF_NATIVE=1 -DHEXA_RT_CORE_ARITH_NATIVE=1 \
-DHEXA_RT_CORE_MATH_NATIVE=1 -DHEXA_RT_CORE_MATH2_NATIVE=1 \
-DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE=1 -DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE=1 \
-DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE=1 -DHEXA_RT_CORE_FS_READ_WRITE_NATIVE=1 \
-DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE=1 -DHEXA_RT_CORE_RUNTIME_MISC_NATIVE=1"

# ── stage 2: build every landed native seed object ──────────────────────────
echo "[2] build native seed objects (build/*.o)…"
for s in leaf arith math math2 map-query-fold collection-mutate \
         array-typed-leaf fs-read-write arith-coerce-format runtime-misc; do
  out="build/rtcore_${s//-/_}_native.o"; scr="tool/regen_rtcore_${s}_native_o.sh"
  [ -f "$scr" ] && { bash "$scr" "$out" >/dev/null 2>&1 && echo "    ok $out" || echo "    FAIL $out"; }
done
for n in array_core map_core alloc_syscall valop_core num_core num_float_core \
         intern_core fs_core str_core runtime_hi; do
  out="build/${n}_native.o"; seed="self/native/${n}_${ARCH}.s"
  [ -f "$out" ] && { echo "    have $out"; continue; }
  [ -f "$seed" ] && { $CC -c "$seed" -o "$out" 2>/dev/null && echo "    asm $out" || echo "    FAIL-asm $out"; }
done
SEED_OBJS=$(ls build/*.o 2>/dev/null | tr '\n' ' ')
echo "    seed object set: $(ls build/*.o 2>/dev/null | wc -l | tr -d ' ') objects"

# ── stage 3: compile the DROP-ON runtime.c (body externed via include-drop) ──
echo "[3] compile DROP-ON runtime.c (HEXA_ZEROC_DROP_RTCORE_INCLUDE)…"
RT_ON="$OUT_DIR/runtime_dropON.o"
$CC $CFLAGS -DHEXA_ZEROC_DROP_RTCORE_INCLUDE -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS \
    self/runtime.c -o "$RT_ON" 2>"$OUT_DIR/rt_on.err"
RC_ON=$?
if [ "$RC_ON" -ne 0 ] || [ ! -f "$RT_ON" ]; then
  echo "    DROP-ON runtime.c FAILED TO COMPILE:"; grep -i error: "$OUT_DIR/rt_on.err" | head -8 | sed 's/^/      /'
  echo "DROP_ON_COMPILES=NO"; exit 1
fi
echo "    DROP-ON runtime.o = $(wc -c < "$RT_ON") bytes"
echo "DROP_ON_COMPILES=YES"
nm -u "$RT_ON" 2>/dev/null | awk '{print $NF}' | sort -u > "$OUT_DIR/undef_rt_on.txt"
echo "    PROBE-A (relocatable runtime.o) undefined: $(wc -l < "$OUT_DIR/undef_rt_on.txt" | tr -d ' ')"

# classify PROBE-A undefined (the 115 split)
classify() {
  local U="$1"
  local LIBM_RE='^_?(sin|cos|tan|tanh|sinh|cosh|exp|expf|log|logf|log2|log10|sqrt|sqrtf|pow|floor|ceil|round|llround|lround|atan|atan2|asin|acos|erf|erfc|lgamma|tgamma|fabs|fmod|cbrt|hypot|trunc|frexp|ldexp|modf|nan|copysign|fmax|fmin)$'
  local SVC_RE='(^_?__hx_syscall|^_?__raw_sys|^_?raw_svc|@syscall|^_?hexa_syscall|^_?__svc_)'
  local CRT_RE='^_?(memcpy|memset|memmove|memcmp|qsort|rand|srand|_exit|exit|environ|longjmp|setjmp|_setjmp|__libc_calloc|__libc_free|__libc_start_main|mallopt|sysconf|strtod|strtol|strtoll|__isoc23_sscanf|sscanf|snprintf|vsnprintf|fprintf|fgets|fputs|fwrite|fread|fopen|fclose|getenv|abort|__stack_chk_fail|__stack_chk_guard|__assert_fail|malloc|calloc|realloc|free|write|read|open|close|strlen|strcmp|strncmp|strcpy|strncpy|memchr|strchr|strstr|atoi|atol|puts|putchar|printf|isatty|access|stat|lstat|mmap|munmap|brk|sbrk|getpid|time|clock_gettime|nanosleep|usleep|signal|sigaction|dlopen|dlsym|dlclose|pthread_create|pthread_join|pthread_mutex_lock|pthread_mutex_unlock|__errno_location|fflush|stdout|stderr|stdin|ferror|fileno|mkdir|unlink|rename|opendir|readdir|closedir|realpath|getcwd|chdir|execvp|fork|waitpid|pipe|dup2|kill|perror|strerror|tolower|toupper|isspace|isdigit|isalpha|isalnum|qsort_r|bsearch|__ctype_b_loc|__ctype_tolower_loc|getline|ungetc|fseek|ftell|rewind|fdopen|setvbuf)$'
  local FROZEN_RE='^_?hxlcl_'
  local WRAP_RE='^_?(hexa_|rt_|__hx_|__map_|hxqwen|__hexa_)'
  cnt() { grep -cE "$1" "$U" 2>/dev/null | tr -d ' '; }
  local SVC LIBM CRT FROZEN WRAP TOTAL OTHER
  SVC=$(cnt "$SVC_RE"); LIBM=$(cnt "$LIBM_RE"); CRT=$(cnt "$CRT_RE")
  FROZEN=$(cnt "$FROZEN_RE"); WRAP=$(cnt "$WRAP_RE")
  TOTAL=$(wc -l < "$U" | tr -d ' ')
  OTHER=$(( TOTAL - SVC - LIBM - CRT - FROZEN - WRAP )); [ "$OTHER" -lt 0 ] && OTHER=0
  echo "    total=$TOTAL  svc=$SVC  libm=$LIBM  crt/libc=$CRT  frozen_static(hxlcl)=$FROZEN  wrapper(hexa/rt)=$WRAP  other=$OTHER"
}
echo "  PROBE-A classification:"
classify "$OUT_DIR/undef_rt_on.txt"

# ── stage 4: compile runtime_core.c STANDALONE (external-linkage body) ───────
# When the #include is dropped, the runtime_core.c body must be supplied as its
# own TU. Compile it standalone — with the SAME cluster externs so its own
# seeded leaves are externed too (they come from build/*.o), and the DROP flag
# so its carriers take external (not static) linkage.
echo "[4] compile runtime_core.c STANDALONE (external-linkage body)…"
RT_CORE="$OUT_DIR/runtime_core.o"
$CC $CFLAGS -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS \
    self/runtime_core.c -o "$RT_CORE" 2>"$OUT_DIR/rt_core.err"
RC_CORE=$?
if [ "$RC_CORE" -ne 0 ] || [ ! -f "$RT_CORE" ]; then
  echo "    runtime_core.c STANDALONE compile FAILED (may need decls header):"
  grep -i error: "$OUT_DIR/rt_core.err" | head -10 | sed 's/^/      /'
  echo "RT_CORE_STANDALONE_COMPILES=NO"
  # try WITH the decls header forced-included (M2 header)
  if [ -f self/runtime_core_decls.h ]; then
    echo "    retry with -include self/runtime_core_decls.h …"
    $CC $CFLAGS -include self/runtime_core_decls.h -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS \
        self/runtime_core.c -o "$RT_CORE" 2>"$OUT_DIR/rt_core2.err"
    if [ -f "$RT_CORE" ]; then echo "    OK with decls header"; echo "RT_CORE_STANDALONE_COMPILES=YES(with-decls-header)";
    else grep -i error: "$OUT_DIR/rt_core2.err" | head -10 | sed 's/^/      /'; fi
  fi
else
  echo "    runtime_core.o = $(wc -c < "$RT_CORE") bytes"
  echo "RT_CORE_STANDALONE_COMPILES=YES"
fi

# ── stage 5: THE REAL M3-LINK — link executable with -lm -lc -ldl ───────────
echo "[5] M3-LINK: link runtime_dropON.o + runtime_core.o + seeds + $LIBS → exe"
# provide a trivial main so the link is an EXECUTABLE (the runtime has no main).
cat > "$OUT_DIR/_m3main.c" <<'EOF'
int main(void){ return 0; }
EOF
$CC -O2 -c "$OUT_DIR/_m3main.c" -o "$OUT_DIR/_m3main.o" 2>/dev/null

LINK_INPUTS="$RT_ON"
[ -f "$RT_CORE" ] && LINK_INPUTS="$LINK_INPUTS $RT_CORE"
LINK_INPUTS="$LINK_INPUTS $SEED_OBJS $OUT_DIR/_m3main.o"

# (a) FULL executable link attempt (will fail if true-undefined remain, that's data)
EXE="$OUT_DIR/m3_exe"
$CC -O2 $LINK_INPUTS -o "$EXE" $LIBS 2>"$OUT_DIR/link.err"
LINK_RC=$?
if [ "$LINK_RC" -eq 0 ] && [ -f "$EXE" ]; then
  echo "    M3-LINK EXECUTABLE: LINKS CLEAN (exit 0)"
  echo "M3_LINK_EXECUTABLE_LINKS=YES"
  echo "M3_LINK_EXIT=0"
  "$EXE"; echo "    exe ran, exit=$?"
else
  echo "    M3-LINK EXECUTABLE: did NOT link clean (exit $LINK_RC) — residual undefined below"
  echo "M3_LINK_EXECUTABLE_LINKS=NO"
  echo "M3_LINK_EXIT=$LINK_RC"
fi

# (b) capture the TRUE residual undefined after -lm -lc via a relocatable
#     partial link (-r) + nm -u, OR by parsing the linker's undefined-ref errors.
#     The partial link merges all our .o (NOT the libs) so nm -u shows what is
#     STILL undefined after seeds+core supply their bodies — then we subtract
#     what -lc/-lm would resolve by re-linking as executable and reading errors.
echo "[5b] TRUE residual undefined (linker undefined-reference errors w/ -lm -lc)…"
# the executable link's undefined-reference errors ARE the true residual: every
# symbol that -lm -lc -ldl could NOT resolve. Parse them.
grep -oE "undefined reference to \`[A-Za-z0-9_.]+'" "$OUT_DIR/link.err" 2>/dev/null \
  | sed -E "s/.*\`([A-Za-z0-9_.]+)'/\1/" | sort -u > "$OUT_DIR/residual_after_lm_lc.txt"
# macOS ld phrasing differs:
grep -oE '"_?[A-Za-z0-9_.]+", referenced from' "$OUT_DIR/link.err" 2>/dev/null \
  | sed -E 's/"(_?[A-Za-z0-9_.]+)".*/\1/' | sort -u >> "$OUT_DIR/residual_after_lm_lc.txt"
grep -oE "Undefined symbols.*|^  _?[A-Za-z0-9_.]+$" "$OUT_DIR/link.err" 2>/dev/null \
  | grep -oE '_?[A-Za-z0-9_.]+' | sort -u >> "$OUT_DIR/residual_after_lm_lc.txt" 2>/dev/null || true
sort -u "$OUT_DIR/residual_after_lm_lc.txt" -o "$OUT_DIR/residual_after_lm_lc.txt"
RESID_N=$(grep -cvE '^$' "$OUT_DIR/residual_after_lm_lc.txt" 2>/dev/null | tr -d ' ')
echo "    TRUE residual undefined after -lm -lc -ldl: $RESID_N"
echo "UNDEF_AFTER_M4=$RESID_N"
echo "  residual classification:"
classify "$OUT_DIR/residual_after_lm_lc.txt"
echo "  --- residual dump (the M5/irreducible target) ---"
sed 's/^/    /' "$OUT_DIR/residual_after_lm_lc.txt"

echo "════════════════════════════════════════════════════════════════"
echo "DONE. PROBE-A undef=$OUT_DIR/undef_rt_on.txt  residual=$OUT_DIR/residual_after_lm_lc.txt"
echo "════════════════════════════════════════════════════════════════"
exit 0
