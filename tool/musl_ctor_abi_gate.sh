#!/usr/bin/env sh
# =============================================================================
# HEXA-0POD OP-19f — musl env-capture ctor-ABI regression gate (LOCAL, 0-GPU)
# =============================================================================
# Purpose
#   Lock in the OP-19e (#3029) fix so the musl-unsafe constructor-args ABI it
#   removed cannot silently re-land. OP-19e rewrote the priority-101 env-capture
#   constructor in tool/restore_frozen_seeds — the patch the script injects into
#   the freshly-restored self/runtime.c — to read the POSIX global
#       extern char **environ;   ...   hxlcl_environ = environ;
#   instead of the glibc/Darwin-only constructor-args ABI
#       hxlcl_capture_environ(int argc, char**argv, char**envp){ hxlcl_environ = envp; }
#   musl runs constructors with NO arguments, so the args form reads a garbage
#   register -> hxlcl_environ = garbage -> SIGSEGV in _hexa_init_mem_cap ->
#   hxlcl_getenv before main(). (See restore_frozen_seeds "OP-19e" block.)
#
#   Regression risk this gate catches: a future runtime/seed edit (or a manual
#   revert) re-introduces the args-ABI capture form into the patch that
#   restore_frozen_seeds emits, silently bringing the musl SIGSEGV back. CI does
#   NOT run under musl, so this is a STATIC source-pattern guard (the cheapest
#   effective check) — it asserts, on the OP-19e patch source itself, that:
#     (1) the musl-safe POSIX-`environ` capture form is PRESENT, and
#     (2) no args-ABI capture form (`hxlcl_capture_environ(int ...)` /
#         `hxlcl_environ = envp`) is EMITTED into the runtime.
#   It does not run anything under musl; it locks the source pattern that the
#   musl SIGSEGV depends on.
#
# LOW BLAST RADIUS — guards ONLY the env-capture constructor:
#   * It inspects a single file (tool/restore_frozen_seeds) and, within it, ONLY
#     the awk-EMITTED C code lines of the env-capture patch — the `print "..."`
#     directives whose payload is real C (NOT a `//` comment and NOT shell `#`
#     prose). The explanatory comments that legitimately spell out the OLD bad
#     `(argc,argv,envp)` signature are therefore structurally exempt and can
#     never trip the gate.
#   * It cannot false-fail on any other code in the tree — it never compiles or
#     scans the runtime, only this one patch block's emitted lines.
#   * The check is purely lexical (grep over emitted lines) — no compiler, no
#     CUDA, no musl toolchain needed; runs anywhere.
#
# Exit: 0 = OP-19e musl-safe form intact; 1 = args-ABI regression / form missing.
# =============================================================================
set -eu

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

SRC="tool/restore_frozen_seeds"

echo "OP-19f musl ctor-ABI regression gate — static POSIX-environ guard"
echo "guarded patch source: $SRC (env-capture constructor only)"

if [ ! -f "$SRC" ]; then
  echo "GATE ERROR: $SRC not found — cannot verify the OP-19e env-capture patch." >&2
  exit 2
fi

# --- Extract ONLY the awk-emitted C code of the env-capture patch -------------
# The OP-19e patch emits the constructor via awk `print "<C source>"` lines.
# We pull the payload of each `print "..."` directive, then DROP:
#   * payloads that are `//` C comments (explanatory text in the emitted block)
# What remains is exactly the real C the patch injects into runtime.c. This is
# the surface a regression would have to touch to bring back the musl SIGSEGV,
# and it excludes every comment that merely *describes* the old bad form.
EMITTED="$(
  sed -n 's/^[[:space:]]*print[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$SRC" \
    | grep -v '^//'
)"

if [ -z "$EMITTED" ]; then
  echo "GATE ERROR: found no awk-emitted C lines in $SRC — patch shape changed?" >&2
  echo "  (Expected the OP-19e env-capture block to emit C via print \"...\".)" >&2
  exit 2
fi

fail=0

# --- (1) MUST be present: the musl-safe POSIX-`environ` capture form -----------
# The fixed constructor reads the libc `environ` global (every libc, incl. musl)
# rather than a ctor arg. Anchor on the exact emitted definition line.
if printf '%s\n' "$EMITTED" \
     | grep -q 'hxlcl_capture_environ(void)[[:space:]]*{.*hxlcl_environ[[:space:]]*=[[:space:]]*environ;'
then
  echo "  PASS  musl-safe POSIX-environ capture form present"
  echo "        (hxlcl_capture_environ(void) { hxlcl_environ = environ; })"
else
  echo "  FAIL  musl-safe POSIX-environ capture form MISSING from emitted patch"
  echo "        OP-19e fix appears reverted/dropped — restore the POSIX-environ ctor."
  fail=1
fi

# --- (2) MUST be absent: the musl-unsafe constructor-args ABI form -------------
# Two independent smoking guns of the old args-ABI capture, scoped to emitted C:
#   a) a capture-function signature taking args:  hxlcl_capture_environ(int ...
#   b) the capture assigning from the ctor-arg envp:  hxlcl_environ = envp
# Either, if EMITTED into the runtime, re-introduces the musl SIGSEGV.
if printf '%s\n' "$EMITTED" \
     | grep -Eq 'hxlcl_capture_environ\(int|hxlcl_environ[[:space:]]*=[[:space:]]*envp'
then
  echo "  FAIL  musl-UNSAFE constructor-args ABI form re-introduced into the patch:"
  printf '%s\n' "$EMITTED" \
    | grep -En 'hxlcl_capture_environ\(int|hxlcl_environ[[:space:]]*=[[:space:]]*envp' \
    | sed 's/^/          /'
  echo "        This is the (argc,argv,envp) ABI musl does NOT pass -> SIGSEGV."
  fail=1
else
  echo "  PASS  no constructor-args ABI capture form emitted (musl-safe)"
fi

echo ""
if [ "$fail" -ne 0 ]; then
  echo "GATE FAILED: OP-19e musl-safe env-capture regressed in $SRC."
  echo "Emit  hxlcl_capture_environ(void) { hxlcl_environ = environ; }  (POSIX environ),"
  echo "NOT   hxlcl_capture_environ(int argc,char**argv,char**envp){ hxlcl_environ = envp; }"
  exit 1
fi

echo "GATE PASSED: OP-19e musl-safe POSIX-environ env capture intact (args-ABI absent)."
exit 0
