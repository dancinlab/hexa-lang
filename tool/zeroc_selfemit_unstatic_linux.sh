#!/usr/bin/env bash
# tool/zeroc_selfemit_unstatic_linux.sh — RFC061 ∅ campaign, PROBE-B unblock.
#
# WHY THIS EXISTS (the SELFEMIT static-conflict wall)
# ───────────────────────────────────────────────────
# The naive whole-runtime SELFEMIT flip (-DHEXA_RT_SELFEMIT) does NOT compile
# from a clean tree because the FROZEN runtime.c blob (151c52c8) has an
# INCONSISTENT SELFEMIT port across its two syscall-wrapper branches:
#
#     #if (defined(__arm64__)||defined(__aarch64__)) && defined(__APPLE__)
#        ... each hxlcl_* DEFINITION is `#ifndef HEXA_RT_SELFEMIT`-guarded,
#            so under SELFEMIT it drops and the extern forward-decl + seed .o
#            supplies the body (CORRECT).
#     #elif defined(__linux__)
#        ... the SAME hxlcl_* DEFINITIONS are UNCONDITIONALLY `static`
#            (NO #ifndef HEXA_RT_SELFEMIT guard) — the SELFEMIT port was never
#            applied to the linux branch. (THE WALL.)
#     #endif
#
# Under SELFEMIT the forward decls at runtime.c:~132+ flip to `extern`
# (non-static); the linux-branch static DEFINITIONS at runtime.c:~1996+ then
# trip clang `error: static declaration of 'hxlcl_read' follows non-static
# declaration` — 17 of them (read write close getpid dup2 kill fcntl ioctl
# lseek select poll waitpid fstat stat exit mmap getuid).
#
# We CANNOT edit the frozen blob (restore_frozen_seeds re-injects 151c52c8).
# THE NON-FROZEN FIX (this script): run AFTER restore_frozen_seeds, before the
# C compile, and wrap each conflicting linux-branch static DEFINITION in
# `#ifndef HEXA_RT_SELFEMIT ... #endif` — mirroring exactly what the darwin
# branch already does for the same symbols. This is a deterministic, idempotent
# post-restore patch of the GENERATED working tree (self/runtime.c is restored
# from the frozen blob each build; we patch the restored copy, never the blob).
#
# BYTE-NEUTRALITY: the guard is `#ifndef HEXA_RT_SELFEMIT`, so on the DEFAULT
# build (SELFEMIT undefined) the definitions stay exactly as-is (the guard is
# transparent — same tokens reach the compiler). Only the SELFEMIT build (an
# opt-in measurement flip, never the shipping default) sees the drop. Therefore
# default-build output is byte-identical.
#
# Usage:  bash tool/zeroc_selfemit_unstatic_linux.sh [REPO_ROOT]
#   REPO_ROOT defaults to $PWD; must contain self/runtime.c (restored).
# Idempotent: re-running is a no-op (marker present). Exit 0 on success.
set -u

ROOT="${1:-$PWD}"
RT="$ROOT/self/runtime.c"
[ -f "$RT" ] || { echo "[unstatic_linux] SKIP — self/runtime.c absent ($RT)"; exit 0; }

if grep -q 'ZEROC_SELFEMIT_LINUX_UNSTATIC' "$RT" 2>/dev/null; then
    echo "[unstatic_linux] already patched (marker present) — no-op"
    exit 0
fi

tmp="$(mktemp -t unstatic_linux.XXXXXX)" || { echo "[unstatic_linux] mktemp failed" >&2; exit 1; }

awk '
  function nbrace(str,    c, i, ch, d) {
    d = 0
    for (i = 1; i <= length(str); i++) {
      ch = substr(str, i, 1)
      if (ch == "{") d++
      else if (ch == "}") d--
    }
    return d
  }
  BEGIN {
    split("hxlcl_read hxlcl_write hxlcl_close hxlcl_getpid hxlcl_dup2 hxlcl_kill hxlcl_fcntl hxlcl_ioctl hxlcl_lseek hxlcl_select hxlcl_poll hxlcl_waitpid hxlcl_fstat hxlcl_stat hxlcl_exit hxlcl_mmap hxlcl_getuid", a, " ")
    for (i in a) target[a[i]] = 1
    in_linux = 0; wrapping = 0; brace = 0; inserted = 0
  }
  {
    # currently emitting a wrapped multi-line body?
    if (wrapping) {
      print $0
      brace += nbrace($0)
      if (brace <= 0) { print "#endif"; wrapping = 0 }
      next
    }
  }
  /^#elif defined\(__linux__\)/ { in_linux = 1; print $0; next }
  {
    if (in_linux && $0 ~ /^#endif/) { in_linux = 0; print $0; next }
    if (in_linux && $0 ~ /^static /) {
      sym = ""
      # match the hxlcl_* identifier that immediately precedes "(" (the function
      # name). NOT the first ident-before-paren, which is __attribute__((...)).
      if (match($0, /hxlcl_[A-Za-z0-9_]*[ \t]*\(/)) {
        tok = substr($0, RSTART, RLENGTH)
        sub(/[ \t]*\($/, "", tok)
        sym = tok
      }
      if (sym in target) {
        print "#ifndef HEXA_RT_SELFEMIT  /* ZEROC_SELFEMIT_LINUX_UNSTATIC */"
        print $0
        b = nbrace($0)
        if (index($0, "{") == 0) {
          # decl-only (ends with ;) — no body
          print "#endif"
        } else if (b <= 0) {
          # single-line def: braces balance on one line
          print "#endif"
        } else {
          wrapping = 1; brace = b
        }
        inserted++
        next
      }
    }
    print $0
  }
  END {
    if (inserted == 0)
      print "[unstatic_linux] WARN: 0 definitions wrapped (branch not found?)" > "/dev/stderr"
    else
      print "[unstatic_linux] wrapped " inserted " linux-branch static defs" > "/dev/stderr"
  }
' "$RT" > "$tmp" || { echo "[unstatic_linux] awk failed" >&2; rm -f "$tmp"; exit 1; }

if [ -s "$tmp" ] && grep -q 'ZEROC_SELFEMIT_LINUX_UNSTATIC' "$tmp"; then
    cp -f "$tmp" "$RT"
    echo "[unstatic_linux] self/runtime.c patched (linux-branch SELFEMIT static-drop, non-frozen)"
    rm -f "$tmp"
    exit 0
fi
rm -f "$tmp"
echo "[unstatic_linux] SKIP — no linux-branch targets found" >&2
exit 0
