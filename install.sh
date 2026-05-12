#!/bin/bash
# hexa-lang installer — one-liner for `hexa` (compiler) + `hx` (package manager)
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)"
#
# Env overrides:
#   HX_HOME        install prefix (default: ~/.hx)
#   HEXA_VERSION   release tag to pull hexa binary from (default: latest)
#   HEXA_REPO      upstream repo (default: dancinlab/hexa-lang)
#   HEXA_SKIP_HX   set to 1 to skip hx package manager install
#   HEXA_SKIP_HEXA set to 1 to skip hexa compiler install

set -eu

HX_HOME="${HX_HOME:-$HOME/.hx}"
HX_BIN="$HX_HOME/bin"
HEXA_REPO="${HEXA_REPO:-dancinlab/hexa-lang}"
HEXA_VERSION="${HEXA_VERSION:-latest}"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
red()   { printf '\033[31m%s\033[0m\n' "$*" >&2; }
dim()   { printf '\033[2m%s\033[0m\n' "$*"; }

detect_target() {
    local os arch
    case "$(uname -s)" in
        Darwin)  os="darwin"  ;;
        Linux)   os="linux"   ;;
        *) red "unsupported OS: $(uname -s)"; exit 1 ;;
    esac
    case "$(uname -m)" in
        arm64|aarch64) arch="arm64" ;;
        x86_64|amd64)  arch="x86_64" ;;
        *) red "unsupported arch: $(uname -m)"; exit 1 ;;
    esac
    echo "${os}-${arch}"
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || { red "missing: $1"; exit 1; }
}

install_hexa() {
    bold "▸ installing hexa (compiler)"
    local target tag base url tmp src
    target="$(detect_target)"
    tag="$HEXA_VERSION"
    base="https://github.com/${HEXA_REPO}/releases"

    if [ "$tag" = "latest" ]; then
        url="${base}/latest/download/hexa-${target}.tar.gz"
    else
        url="${base}/download/${tag}/hexa-${target}.tar.gz"
    fi

    tmp="$(mktemp -d)"

    dim "  fetching $url"
    if ! curl -fsSL "$url" -o "$tmp/hexa.tar.gz"; then
        red "  ✗ release asset not found: hexa-${target}.tar.gz"
        red "    (tag: ${tag}, repo: ${HEXA_REPO})"
        echo ""
        echo "  Fallback: build from source"
        echo "    git clone https://github.com/${HEXA_REPO}.git"
        echo "    cd hexa-lang && ./hexa install.hexa"
        rm -rf "$tmp"
        return 1
    fi

    tar -xzf "$tmp/hexa.tar.gz" -C "$tmp"

    # Archive layout: hexa-{target}/{hexa, build/hexa_interp}
    # Dispatcher resolves interp relative to argv[0] (<dir>/build/hexa_interp),
    # so preserve the build/ directory alongside the hexa binary.
    src="$tmp/hexa-${target}"
    [ -d "$src" ] || src="$tmp"

    # Dispatcher resolves its sidecar interpreter via dirname(argv[0]).
    # When invoked through PATH, argv[0]="hexa" has no slash and resolution
    # falls back to cwd — wrong. Install the native binary under a private
    # name and place a thin shim at $HX_BIN/hexa that exec's it with an
    # absolute argv[0]. Mirrors the source-tree `hexa` → `hexa.real` shim.
    install -m 0755 "$src/hexa" "$HX_BIN/hexa.real"
    cat > "$HX_BIN/hexa" <<EOF
#!/bin/bash
exec "$HX_BIN/hexa.real" "\$@"
EOF
    chmod 0755 "$HX_BIN/hexa"
    # Copy build/ verbatim so any sidecar name the release ships
    # (hexa_stage0 / hexa_interp / future) just works.
    if [ -d "$src/build" ]; then
        mkdir -p "$HX_BIN/build"
        cp -R "$src/build/." "$HX_BIN/build/"
        chmod -R u+rwX,go+rX "$HX_BIN/build"
    fi
    green "  ✓ $HX_BIN/hexa"
    rm -rf "$tmp"
}

install_hx() {
    bold "▸ installing hx (package manager)"
    local url="https://raw.githubusercontent.com/${HEXA_REPO}/main/tool/pkg/hx"
    curl -fsSL "$url" -o "$HX_BIN/hx"
    chmod +x "$HX_BIN/hx"
    green "  ✓ $HX_BIN/hx"
}

install_darwin_marker() {
    # Stamp darwin-bypass eligibility marker so the resolver shim
    # (~/.hx/bin/hexa) can route safe argv (--version, --help, lsp)
    # directly to native hexa instead of docker hard-landing.
    [ "$(uname -s)" = "Darwin" ] || return 0
    bold "▸ stamping darwin-bypass eligibility marker"
    local marker="$HX_HOME/.darwin-bypass-eligible"
    mkdir -p "$HX_HOME" 2>/dev/null || true
    if : > "$marker" 2>/dev/null; then
        green "  ✓ $marker"
    else
        red "  ✗ failed to stamp $marker (read-only HOME?) — resolver will self-heal"
    fi
}

update_path_hint() {
    case ":$PATH:" in
        *":$HX_BIN:"*) return 0 ;;
    esac

    local rc=""
    case "${SHELL:-}" in
        */zsh)  rc="$HOME/.zshrc"  ;;
        */bash) rc="$HOME/.bashrc" ;;
    esac

    echo ""
    bold "▸ PATH setup"
    if [ -n "$rc" ] && [ -f "$rc" ]; then
        if ! grep -q '.hx/bin' "$rc" 2>/dev/null; then
            printf '\n# hexa-lang\nexport PATH="$HOME/.hx/bin:$PATH"\n' >> "$rc"
            green "  ✓ added to $rc"
            echo "  restart your shell, or run:"
            echo '    export PATH="$HOME/.hx/bin:$PATH"'
        else
            dim "  already present in $rc"
        fi
    else
        echo "  add this to your shell rc file:"
        echo '    export PATH="$HOME/.hx/bin:$PATH"'
    fi
}

main() {
    need_cmd curl
    need_cmd tar
    mkdir -p "$HX_BIN"

    bold "⬡ hexa-lang installer"
    dim "  prefix: $HX_HOME"
    echo ""

    local hexa_ok=1
    if [ "${HEXA_SKIP_HEXA:-}" != "1" ]; then
        install_hexa || hexa_ok=0
        echo ""
    fi

    if [ "${HEXA_SKIP_HX:-}" != "1" ]; then
        install_hx
    fi

    install_darwin_marker
    update_path_hint

    echo ""
    if [ "$hexa_ok" = "1" ]; then
        green "✓ done. try:"
        echo "    hexa version"
        echo "    hx search"
    else
        red "✗ hexa compiler install failed (hx installed ok)"
        exit 1
    fi
}

main "$@"
