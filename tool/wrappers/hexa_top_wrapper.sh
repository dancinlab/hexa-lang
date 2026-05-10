#!/bin/sh
# hexa_top_wrapper.sh — reference $HOME/.hx/bin/hexa wrapper (Phase B; warn-only Mach-O gate)
#
# Phase A (this file, in repo): reference text + lint + SPEC entry + doc.
# Phase B (separate user session): copy this file into place and chmod +x.
# Phase C (deferred): convert warn -> hard block once hook layer is migrated.
#
# Decision (2026-05-09): macOS hexa invocations should explicitly opt into
# native Mach-O codegen via either the `--Mach-O` CLI flag or the
# HEXA_TARGET_MACHO=1 environment variable. Today the gate is warn-only
# (block 0) so that claude-bind hooks, probes, lints, and other non-AOT
# call sites continue to work unmodified. Empirically only ~6% of macOS
# hexa_interp.real.real invocations actually need native codegen.
#
# Install (Phase B; user runs in a separate session):
#   cp $HOME/.hx/bin/hexa $HOME/.hx/bin/hexa.bak.YYYY-MM-DD   # rollback snapshot
#   cp tool/wrappers/hexa_top_wrapper.sh $HOME/.hx/bin/hexa
#   chmod +x $HOME/.hx/bin/hexa
#
# Rollback (Phase B):
#   cp $HOME/.hx/bin/hexa.bak.YYYY-MM-DD $HOME/.hx/bin/hexa
#
# Constraint: POSIX sh only (no bashisms). ENGLISH ONLY messages.

case "$1" in
  run|batch)
    if [ "$HEXA_TARGET_MACHO" != "1" ] \
       && ! printf '%s\n' "$@" | grep -q -- '--Mach-O'; then
      cat >&2 <<'EOF'
ai-native: hexa invocation without --Mach-O on macOS.
  This call uses the stage0 interpreter; no native Mach-O codegen
  is produced. Use --Mach-O ONLY when you genuinely need a native
  arm64 binary (e.g. `hexa build --emit=exec` for a release).
  For hooks, probes, lints, and most dev work this warning is
  informational — no action required.
  Set HEXA_TARGET_MACHO=1 in your shell to silence per-session.
EOF
    fi
    exec /Users/ghost/core/resource/bin/hexa-r ubu-1 "$@"
    ;;
  *)
    exec "$HOME/.hx/packages/hexa/hexa.real" "$@"
    ;;
esac
