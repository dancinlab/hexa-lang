#!/bin/bash
# tool/promote_selfhost.sh — GATED promotion of the self-hosted compiler.
#
# Makes the self-hosted native compiler (gen3) selectable as the default
# toolchain WITHOUT a blind replace of the shipped binary. Promotion is a
# two-tier opt-in, each tier strictly gated on tool/selfhost_parity_gate.sh:
#
#   tier 1  install   — install gen3 + hexa_ld + rt.o into a SIDE-BY-SIDE slot
#                       ($HX_HOME/self/native/selfhost/) and drop an `hx-selfhost`
#                       launcher on PATH. The default `hx`/`hexa` is UNTOUCHED.
#                       Users opt in per-invocation: `hx-selfhost build ...` or
#                       `HX_SELFHOST=1 hx ...` (the launcher honours the env).
#   tier 2  --default — flip the default: back up the current hexad to
#                       hexad.pre-selfhost.<ts> and symlink hexad ->
#                       the selfhost launcher. REVERSIBLE via --revert. This
#                       tier is REFUSED unless --i-have-reviewed-parity is also
#                       passed AND the parity gate re-runs green here.
#
# The parity gate is a HARD precondition for BOTH tiers: if it fails, nothing
# is installed/flipped and the script exits non-zero.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   tool/promote_selfhost.sh install [-w BUILD] [--hx-home DIR]
#   tool/promote_selfhost.sh install --default --i-have-reviewed-parity [...]
#   tool/promote_selfhost.sh --revert [--hx-home DIR]
#   tool/promote_selfhost.sh --status [--hx-home DIR]
#
#     -w BUILD     selfhost build dir holding gen3/hexa_ld/rt.o
#                  (default: ./build/selfhost)
#     --hx-home    install root (default: $HX_HOME or $HOME/.hx)
#
# ── Exit codes ───────────────────────────────────────────────────────────────
#   0  promotion step done (or status/revert ok)
#   1  parity gate FAILED — promotion blocked
#   2  default-flip refused (missing --i-have-reviewed-parity) or revert n/a
#   3  bad invocation / missing inputs
set -u

MODE=""; BUILD=""; HX_HOME="${HX_HOME:-$HOME/.hx}"
DO_DEFAULT=0; REVIEWED=0
case "${1:-}" in
    install) MODE=install; shift ;;
    --revert) MODE=revert; shift ;;
    --status) MODE=status; shift ;;
    *) echo "promote_selfhost: first arg must be install|--revert|--status" >&2; exit 3 ;;
esac
while [ $# -gt 0 ]; do
    case "$1" in
        -w) BUILD="$2"; shift 2 ;;
        --hx-home) HX_HOME="$2"; shift 2 ;;
        --default) DO_DEFAULT=1; shift ;;
        --i-have-reviewed-parity) REVIEWED=1; shift ;;
        *) echo "promote_selfhost: unknown arg '$1'" >&2; exit 3 ;;
    esac
done
[ -z "$BUILD" ] && BUILD="$(pwd)/build/selfhost"
SLOT="$HX_HOME/self/native/selfhost"
LAUNCHER="$HX_HOME/bin/hx-selfhost"          # bare: exec gen3 (compile surface only)
CLI_LAUNCHER="$HX_HOME/bin/hx-selfhost-cli"  # safe: compile->gen3, everything else->delegate
# Flip sentinel = the canonical `hexad` (the name the shim execs + AMFI sees).
# An unflipped install has hexad a plain REAL FILE; a tier2 flip backs it up to
# hexad.pre-selfhost.<ts> and symlinks hexad -> hx-selfhost-cli (the unique
# `[ -L hexad ]` state). hexa.real/hxv2 are compat symlinks -> hexad and follow.
REAL="$HX_HOME/bin/hexad"

status() {
    echo "=== selfhost promotion status (HX_HOME=$HX_HOME) ==="
    echo "slot      : $([ -d "$SLOT" ] && echo "installed ($SLOT)" || echo absent)"
    echo "launcher  : $([ -x "$LAUNCHER" ] && echo "present ($LAUNCHER)" || echo absent)"
    echo "cli-shim  : $([ -x "$CLI_LAUNCHER" ] && echo "present ($CLI_LAUNCHER)" || echo absent)"
    if [ -L "$REAL" ]; then
        echo "default   : hexad -> $(readlink "$REAL") (FLIPPED to selfhost)"
    else
        echo "default   : hexad = shipped binary (NOT flipped)"
    fi
    ls -1 "$HX_HOME/bin/"hexad.pre-selfhost.* 2>/dev/null | sed 's/^/backup    : /'
}

if [ "$MODE" = status ]; then status; exit 0; fi

if [ "$MODE" = revert ]; then
    BK="$(ls -1t "$HX_HOME/bin/"hexad.pre-selfhost.* 2>/dev/null | head -1)"
    if [ -L "$REAL" ] && [ -n "$BK" ]; then
        rm -f "$REAL"; mv "$BK" "$REAL"; rm -f "$HX_HOME/.selfhost-default"
        echo "reverted: hexad restored from $BK (cleared persistence marker)"; status; exit 0
    fi
    echo "revert: nothing to revert (hexad is not a selfhost symlink, or no backup)" >&2
    exit 2
fi

# ── install ──────────────────────────────────────────────────────────────────
for f in gen3 hexa_ld rt.o; do
    [ -e "$BUILD/$f" ] || { echo "promote_selfhost: missing $BUILD/$f — run tool/build_selfhost.sh first" >&2; exit 3; }
done

# HARD GATE: parity must pass before anything is installed.
echo "=== running parity gate (hard precondition) ==="
HERE="$(cd "$(dirname "$0")" && pwd)"
if ! bash "$HERE/selfhost_parity_gate.sh" -g "$BUILD/gen3" -l "$BUILD/hexa_ld" -t "$BUILD/rt.o" -w "$BUILD/parity"; then
    echo "promote_selfhost: PARITY GATE FAILED — promotion blocked, nothing installed." >&2
    exit 1
fi

# tier 1: side-by-side install
mkdir -p "$SLOT" "$HX_HOME/bin"
cp "$BUILD/gen3" "$SLOT/gen3"; cp "$BUILD/hexa_ld" "$SLOT/hexa_ld"; cp "$BUILD/rt.o" "$SLOT/rt.o"
chmod +x "$SLOT/gen3" "$SLOT/hexa_ld"
cat > "$LAUNCHER" <<EOF
#!/bin/bash
# hx-selfhost — launcher for the self-hosted native hexa compiler (gen3).
# Installed by tool/promote_selfhost.sh after a green parity gate.
exec "$SLOT/gen3" "\$@"
EOF
chmod +x "$LAUNCHER"
echo "tier1: installed self-host slot at $SLOT + launcher $LAUNCHER"
echo "       opt-in: 'hx-selfhost <args>' (default hx/hexa is untouched)"

# install the SAFE delegating CLI shim (tier2 flips to THIS, not the bare launcher)
if [ -f "$HERE/hx-selfhost-cli" ]; then
    cp "$HERE/hx-selfhost-cli" "$CLI_LAUNCHER"; chmod +x "$CLI_LAUNCHER"
    echo "tier1: installed CLI shim $CLI_LAUNCHER (compile->gen3, subcommands->delegate)"
else
    echo "promote_selfhost: WARNING — tool/hx-selfhost-cli not found next to script;" >&2
    echo "                  tier2 default-flip will be UNSAFE (bare gen3). Aborting flip." >&2
fi

# tier 2: default flip (guarded)
if [ "$DO_DEFAULT" = 1 ]; then
    if [ "$REVIEWED" != 1 ]; then
        echo "promote_selfhost: --default REFUSED — pass --i-have-reviewed-parity to flip." >&2
        echo "                  tier1 side-by-side install succeeded; default unchanged." >&2
        exit 2
    fi
    # The SAFE delegating shim is REQUIRED for tier2 — it is what keeps the full
    # CLI + every hook working after the flip. Refuse to flip to bare gen3.
    if [ ! -x "$CLI_LAUNCHER" ]; then
        echo "promote_selfhost: --default REFUSED — CLI shim $CLI_LAUNCHER absent." >&2
        echo "                  flipping to bare gen3 would brick the full CLI. tier1 ok." >&2
        exit 2
    fi
    if [ -e "$REAL" ] && [ ! -L "$REAL" ]; then
        TS="$(date +%Y%m%d-%H%M%S)"
        mv "$REAL" "$HX_HOME/bin/hexad.pre-selfhost.$TS"
        echo "tier2: backed up shipped hexad -> hexad.pre-selfhost.$TS"
    fi
    ln -sf "$CLI_LAUNCHER" "$REAL"
    : > "$HX_HOME/.selfhost-default"   # persistence marker — install.sh re-applies this flip after a reinstall
    echo "tier2: DEFAULT FLIPPED — hexad -> $CLI_LAUNCHER (revert: tool/promote_selfhost.sh --revert)"
    echo "tier2: wrote persistence marker $HX_HOME/.selfhost-default (install.sh re-applies the flip on reinstall)"
fi
status
exit 0
