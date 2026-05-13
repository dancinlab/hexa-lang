#!/usr/bin/env bash
# ubu_bootstrap.sh — automate the hexa build pipeline for a Linux (ubu) host.
#
# Pre-existing flow was a manual sequence of:
#   (mac)  self/native/hexa_v2 → /tmp/hexa_main.c, /tmp/hexa_full.c
#   (mac)  rsync repo + scp .c → target
#   (ubu)  gcc both .c files into ~/.hx/bin/hexa.real + build/hexa_interp
#   (ubu)  install ~/.hx/bin/hexa wrapper
#
# This script collapses each phase into a subcommand and offers a full
# `install` pipeline. The default ssh_host alias is `ubu2` (matches the
# local ~/.ssh/config entry used in the consolidation session).
#
# Subcommands:
#   transpile                  Mac-side: produce /tmp/hexa_main.c + /tmp/hexa_full.c
#   sync     [<ssh_host>]      Mac-side: rsync repo + scp transpiled .c files
#   build    [<ssh_host>]      Build both binaries (remotely via ssh, or locally
#                              if invoked with `--local` or no host alias resolves)
#   install  [<ssh_host>]      Full pipeline: transpile + sync + build + wrapper
#   verify   [<ssh_host>]      Smoke: run compiler/atlas/static_index_test.hexa
#   help                       Print this banner
#
# Defaults:
#   HOST                = ${UBU_BOOTSTRAP_HOST:-ubu2}
#   REPO_ROOT           = repository root (derived from script location)
#   REMOTE_REPO         = ~/core/hexa-lang  (on the target host)
#   REMOTE_HX_BIN       = ~/.hx/bin         (on the target host)
#
# Environment overrides:
#   UBU_BOOTSTRAP_HOST  default ssh host (alias from ~/.ssh/config)
#   UBU_REMOTE_REPO     remote repo path (default: ~/core/hexa-lang)
#   UBU_REMOTE_HX_BIN   remote hx bin dir (default: ~/.hx/bin)
#
# Notes:
#   * Uses `set -euo pipefail` — any non-zero exit halts the pipeline.
#   * Smoke for `transpile` only verifies /tmp outputs exist; it does NOT
#     touch any remote host.

set -euo pipefail

# ── Resolve paths ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOST="${UBU_BOOTSTRAP_HOST:-ubu2}"
REMOTE_REPO="${UBU_REMOTE_REPO:-\$HOME/core/hexa-lang}"
REMOTE_HX_BIN="${UBU_REMOTE_HX_BIN:-\$HOME/.hx/bin}"

HEXA_V2="$REPO_ROOT/self/native/hexa_v2"
MAIN_SRC="$REPO_ROOT/self/main.hexa"
FULL_SRC="$REPO_ROOT/self/hexa_full.hexa"
MAIN_OUT="/tmp/hexa_main.c"
FULL_OUT="/tmp/hexa_full.c"

# ── Logging ───────────────────────────────────────────────────
log()  { printf '[ubu_bootstrap] %s\n' "$*"; }
warn() { printf '[ubu_bootstrap WARN] %s\n' "$*" >&2; }
die()  { printf '[ubu_bootstrap ERR] %s\n' "$*" >&2; exit 1; }

# ── Subcommands ───────────────────────────────────────────────

cmd_transpile() {
    log "transpile: self/main.hexa → $MAIN_OUT"
    [ -x "$HEXA_V2" ] || die "hexa_v2 binary missing or not executable: $HEXA_V2"
    [ -f "$MAIN_SRC" ] || die "source missing: $MAIN_SRC"
    [ -f "$FULL_SRC" ] || die "source missing: $FULL_SRC"
    "$HEXA_V2" "$MAIN_SRC" "$MAIN_OUT"
    log "transpile: self/hexa_full.hexa → $FULL_OUT"
    "$HEXA_V2" "$FULL_SRC" "$FULL_OUT"
    [ -s "$MAIN_OUT" ] || die "transpile produced empty $MAIN_OUT"
    [ -s "$FULL_OUT" ] || die "transpile produced empty $FULL_OUT"
    log "transpile: OK ($(wc -c <"$MAIN_OUT" | tr -d ' ') B main, $(wc -c <"$FULL_OUT" | tr -d ' ') B full)"
}

cmd_sync() {
    local host="${1:-$HOST}"
    log "sync: → $host:$REMOTE_REPO"
    [ -f "$MAIN_OUT" ] || die "$MAIN_OUT missing — run 'transpile' first"
    [ -f "$FULL_OUT" ] || die "$FULL_OUT missing — run 'transpile' first"

    # Ensure remote dirs exist
    ssh "$host" "mkdir -p $REMOTE_REPO/build $REMOTE_HX_BIN"

    # Rsync source dirs (exclude build artifacts and platform-specific libs)
    rsync -av \
        --exclude='*.dylib' \
        --exclude='*.so' \
        --exclude='build/' \
        --exclude='archive/' \
        --exclude='.git/' \
        "$REPO_ROOT/compiler/" "$host:$REMOTE_REPO/compiler/"
    rsync -av \
        --exclude='*.dylib' \
        --exclude='*.so' \
        --exclude='build/' \
        --exclude='archive/' \
        "$REPO_ROOT/tool/" "$host:$REMOTE_REPO/tool/"
    rsync -av \
        --exclude='*.dylib' \
        --exclude='*.so' \
        --exclude='build/' \
        --exclude='archive/' \
        --exclude='native/hexa_v2*' \
        --exclude='native/hexa_cc.c.bak.*' \
        "$REPO_ROOT/self/" "$host:$REMOTE_REPO/self/"
    rsync -av \
        --exclude='*.dylib' \
        --exclude='*.so' \
        --exclude='build/' \
        --exclude='archive/' \
        "$REPO_ROOT/test/" "$host:$REMOTE_REPO/test/"

    # Ship the transpiled C
    scp "$MAIN_OUT" "$host:$REMOTE_REPO/build/hexa_main.c"
    scp "$FULL_OUT" "$host:$REMOTE_REPO/build/hexa_full.c"
    log "sync: OK"
}

# Build commands (remote): compile both .c files and emit binaries.
# Returns the heredoc body so callers can `ssh` it or `bash` it locally.
_remote_build_script() {
    cat <<'REMOTE_EOF'
set -euo pipefail
cd "$HOME/core/hexa-lang"
mkdir -p "$HOME/.hx/bin" build
echo "[remote] gcc → ~/.hx/bin/hexa.real (from build/hexa_main.c)"
gcc -O2 -D_GNU_SOURCE -Wno-trigraphs -I self -I . \
    build/hexa_main.c -o "$HOME/.hx/bin/hexa.real" -lm
echo "[remote] gcc → build/hexa_interp (from build/hexa_full.c)"
gcc -O2 -D_GNU_SOURCE -std=gnu11 -Wno-trigraphs -I self -I . \
    build/hexa_full.c -o build/hexa_interp -lm -ldl
echo "[remote] writing wrapper ~/.hx/bin/hexa"
cat > "$HOME/.hx/bin/hexa" <<'WRAP_EOF'
#!/bin/bash
exec "$HOME/.hx/bin/hexa.real" "$@"
WRAP_EOF
chmod +x "$HOME/.hx/bin/hexa"
echo "[remote] build OK — $($HOME/.hx/bin/hexa.real --version 2>/dev/null || echo 'hexa.real built')"
REMOTE_EOF
}

cmd_build() {
    local host="${1:-$HOST}"
    if [ "$host" = "--local" ] || [ "$host" = "local" ]; then
        log "build: local"
        _remote_build_script | bash
    else
        log "build: → $host"
        _remote_build_script | ssh "$host" bash -s
    fi
    log "build: OK"
}

cmd_install() {
    local host="${1:-$HOST}"
    log "install: full pipeline → $host"
    cmd_transpile
    cmd_sync "$host"
    cmd_build "$host"
    log "install: pipeline OK"
}

cmd_verify() {
    local host="${1:-$HOST}"
    log "verify: smoke compiler/atlas/static_index_test.hexa on $host"
    local script
    script="cd $REMOTE_REPO && HEXA_LANG=\$PWD HEXA_MEM_UNLIMITED=1 timeout 200 \"\$HOME/.hx/bin/hexa\" run compiler/atlas/static_index_test.hexa"
    if [ "$host" = "--local" ] || [ "$host" = "local" ]; then
        bash -c "$script"
    else
        ssh "$host" "$script"
    fi
    log "verify: OK"
}

cmd_help() {
    sed -n '1,40p' "$0"
}

# ── Dispatch ──────────────────────────────────────────────────
if [ $# -lt 1 ]; then
    cmd_help
    exit 1
fi

sub="$1"; shift || true
case "$sub" in
    transpile) cmd_transpile "$@" ;;
    sync)      cmd_sync      "$@" ;;
    build)     cmd_build     "$@" ;;
    install)   cmd_install   "$@" ;;
    verify)    cmd_verify    "$@" ;;
    help|-h|--help) cmd_help ;;
    *)
        warn "unknown subcommand: $sub"
        cmd_help
        exit 1
        ;;
esac
