#!/bin/bash
# hexa-lang installer — one-liner for `hexa` (compiler) + `hx` (package manager)
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)"
#
# Env overrides:
#   HX_HOME         install prefix (default: ~/.hx)
#   HEXA_VERSION    release tag to pull hexa binary from (default: latest)
#   HEXA_REPO       upstream repo (default: dancinlab/hexa-lang)
#   HEXA_BRANCH     source branch to clone for stdlib/self/ (default: main)
#   HEXA_SKIP_HX    set to 1 to skip hx package manager install
#   HEXA_SKIP_HEXA  set to 1 to skip hexa compiler install
#   HEXA_SKIP_SRC   set to 1 to skip the stdlib/self/ source clone
#                   (NOTE: `hexa build` of `use "stdlib/..."` programs will
#                    then fail — the source tree provides stdlib/)

set -eu

HX_HOME="${HX_HOME:-$HOME/.hx}"
HX_BIN="$HX_HOME/bin"
HX_SRC="$HX_HOME/src"
HEXA_REPO="${HEXA_REPO:-dancinlab/hexa-lang}"
HEXA_VERSION="${HEXA_VERSION:-latest}"
HEXA_BRANCH="${HEXA_BRANCH:-main}"

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

install_src() {
    # Problem: the release tarball ships only {hexa binary, build/}. It does
    # NOT contain stdlib/ or self/. The compiler has install-relative stdlib/
    # discovery (commit df9e7f6b) — it probes <install_dir>/stdlib and
    # <install_dir>/self/stdlib — but nothing ever PLACES stdlib/ there. So a
    # fresh `hexa build` of any `use "stdlib/..."` program fails.
    #
    # Fix (works TODAY, no new release needed): shallow-clone the hexa-lang
    # source into $HX_SRC, then symlink the support trees next to the hexa.real
    # binary so the compiler's install-relative discovery resolves them:
    #   $HX_BIN/stdlib -> $HX_SRC/stdlib   (ml_stdlib_install_candidates: <inst>/stdlib)
    #   $HX_BIN/self   -> $HX_SRC/self     (<inst>/self/stdlib  AND  hexa cc's
    #                                       <inst>/self/native/hexa_cc.c)
    # install_dir_from_argv0() realpath-resolves hexa.real to $HX_BIN, so these
    # land exactly where the resolver looks.
    bold "▸ installing hexa source (stdlib/ + self/)"
    local repo_url
    repo_url="https://github.com/${HEXA_REPO}.git"

    if ! command -v git >/dev/null 2>&1; then
        red "  ✗ git not found — cannot install stdlib/ source"
        red "    \`hexa build\` of programs using \"stdlib/...\" will fail."
        red "    install git, then re-run, or set HEXA_SKIP_SRC=1 to silence."
        return 1
    fi

    if [ -d "$HX_SRC/.git" ]; then
        dim "  updating existing source at $HX_SRC"
        git -C "$HX_SRC" fetch --depth 1 origin "$HEXA_BRANCH" >/dev/null 2>&1 || true
        git -C "$HX_SRC" checkout -q "$HEXA_BRANCH" >/dev/null 2>&1 || true
        git -C "$HX_SRC" reset --hard "origin/$HEXA_BRANCH" >/dev/null 2>&1 || true
    else
        dim "  cloning $repo_url (branch: $HEXA_BRANCH, shallow)"
        rm -rf "$HX_SRC"
        if ! git clone --depth 1 --branch "$HEXA_BRANCH" "$repo_url" "$HX_SRC" >/dev/null 2>&1; then
            red "  ✗ git clone failed: $repo_url ($HEXA_BRANCH)"
            return 1
        fi
    fi

    if [ ! -d "$HX_SRC/stdlib" ]; then
        red "  ✗ cloned source has no stdlib/ — repo layout changed?"
        return 1
    fi

    # Wire the install-relative discovery anchors. ln -sfn: replace any stale
    # link/dir atomically without descending into it.
    ln -sfn "$HX_SRC/stdlib" "$HX_BIN/stdlib"
    ln -sfn "$HX_SRC/self"   "$HX_BIN/self"
    green "  ✓ $HX_SRC (stdlib/ + self/ linked into $HX_BIN)"

    # The `hexa build` flatten step (resolve_module_loader_compiled in
    # self/main.hexa) needs a COMPILED module_loader binary at
    # <install>/build/hexa_module_loader. It is .gitignored, so the clone
    # above does NOT contain it — but module_loader.hexa has zero `use`
    # statements (self-contained), so it builds with no pre-existing
    # module_loader. Build it now from the fresh source so end-to-end
    # `hexa build` works on this install without a new release.
    bold "▸ building module_loader (hexa build flatten helper)"
    if [ ! -x "$HX_BIN/hexa.real" ]; then
        red "  ✗ hexa.real missing — cannot build module_loader"
        return 1
    fi
    mkdir -p "$HX_BIN/build"
    if HEXA_MAC_BUILD_OK=1 HEXA_LANG="$HX_SRC" \
        "$HX_BIN/hexa" build "$HX_SRC/self/module_loader.hexa" \
        -o "$HX_BIN/build/hexa_module_loader" >/dev/null 2>&1 \
        && [ -x "$HX_BIN/build/hexa_module_loader" ]; then
        green "  ✓ $HX_BIN/build/hexa_module_loader"
    else
        red "  ✗ module_loader build failed — \`hexa build\` of programs using"
        red "    \"stdlib/...\" will fall back to raw-src and fail. Re-run, or"
        red "    build manually: cd $HX_SRC && tool/build_hexa_module_loader.sh"
        return 1
    fi
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

    echo ""
    bold "▸ PATH setup"

    # Pick the rc file that the user's login shell actually sources, per
    # OS + shell combo, and the export line in that shell's own syntax.
    #   - zsh:  ~/.zshrc        (sourced for interactive shells on all OSes)
    #   - bash: ~/.bashrc on Linux; ~/.bash_profile on macOS — a login bash
    #           on macOS (every Terminal.app window IS a login shell) reads
    #           ~/.bash_profile / ~/.profile, NOT ~/.bashrc.
    #   - fish: ~/.config/fish/config.fish — fish has no `export`; use
    #           `fish_add_path` (idempotent, prepends to $PATH).
    local rc="" line="" os
    os="$(uname -s)"
    case "${SHELL:-}" in
        */zsh)
            rc="$HOME/.zshrc"
            line='export PATH="$HOME/.hx/bin:$PATH"'
            ;;
        */bash)
            if [ "$os" = "Darwin" ]; then
                rc="$HOME/.bash_profile"
            else
                rc="$HOME/.bashrc"
            fi
            line='export PATH="$HOME/.hx/bin:$PATH"'
            ;;
        */fish)
            rc="$HOME/.config/fish/config.fish"
            line='fish_add_path "$HOME/.hx/bin"'
            ;;
    esac

    if [ -n "$rc" ]; then
        # Create the rc file (and any parent dir) if missing — a fresh user
        # may have no rc file at all, in which case the old code did nothing.
        mkdir -p "$(dirname "$rc")" 2>/dev/null || true
        [ -f "$rc" ] || : > "$rc" 2>/dev/null || true

        if [ -f "$rc" ] && [ -w "$rc" ]; then
            if ! grep -q '.hx/bin' "$rc" 2>/dev/null; then
                printf '\n# hexa-lang\n%s\n' "$line" >> "$rc"
                green "  ✓ added to $rc"
                echo "  restart your shell, or run:"
                echo "    $line"
            else
                dim "  already present in $rc"
            fi
        else
            red "  ✗ cannot write $rc — add this line manually:"
            echo "    $line"
        fi
    else
        echo "  add this to your shell rc file:"
        echo '    export PATH="$HOME/.hx/bin:$PATH"   # bash/zsh'
        echo '    fish_add_path "$HOME/.hx/bin"        # fish'
    fi
}

main() {
    need_cmd curl
    need_cmd tar
    mkdir -p "$HX_BIN"

    bold "⬡ hexa-lang installer"
    dim "  prefix: $HX_HOME"
    echo ""

    local hexa_ok=1 src_ok=1
    if [ "${HEXA_SKIP_HEXA:-}" != "1" ]; then
        install_hexa || hexa_ok=0
        echo ""
    fi

    # stdlib/ + self/ source — required for `hexa build` of any program that
    # does `use "stdlib/..."`. Skipped only when the compiler itself was
    # skipped or HEXA_SKIP_SRC=1.
    if [ "${HEXA_SKIP_SRC:-}" != "1" ] && [ "$hexa_ok" = "1" ]; then
        install_src || src_ok=0
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
        if [ "$src_ok" != "1" ] && [ "${HEXA_SKIP_SRC:-}" != "1" ]; then
            echo ""
            red "  ⚠ stdlib/ source install failed — \`hexa build\` of programs"
            red "    using \"stdlib/...\" will not work until you re-run with git"
            red "    available, or clone ${HEXA_REPO} and set HEXA_LANG to it."
        fi
    else
        red "✗ hexa compiler install failed (hx installed ok)"
        exit 1
    fi
}

main "$@"
